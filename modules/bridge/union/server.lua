-- modules/bridge/union/server.lua
-- Bridge kt_inventory ↔ Union Framework (côté serveur)
-- Version production-ready :
--   • _loadingPlayers nettoyé même en cas d'erreur (pcall + finally pattern)
--   • GetPlayerFromId en thread séparé → non bloquant
--   • Sécurités nil/type sur toutes les données critiques
--   • Groupes : fusion job + group sans collision de clés
--   • SQL : MySQL.single au lieu de MySQL.fetchOne (moins de colonnes inutiles)
--   • Scalabilité : aucun Wait() dans le chemin principal

if not lib then return end

local Inventory = require 'modules.inventory.server'
local Items     = require 'modules.items.server'

-- ─────────────────────────────────────────────────────────────
-- Helpers internes
-- ─────────────────────────────────────────────────────────────

---Retourne le PlayerObject Union ou nil (sans bloquer).
---@param src number
---@return table|nil
local function getUnionPlayer(src)
    local ok, player = pcall(function()
        return exports['union']:GetPlayerFromId(src)
    end)
    return ok and player or nil
end

---Construit la table `groups` sans collision entre job et group admin.
---Règle : le job occupe sa propre clé ; le groupe système (admin, founder…)
---utilise le préfixe "sys:" pour ne jamais écraser un job portant le même nom.
---@param char table  données du personnage courant
---@param player table  objet Union complet
---@return table
local function buildGroups(char, player)
    local groups = {}

    -- Job du personnage (grade explicite ou 0)
    local job   = type(char.job) == 'string' and char.job ~= '' and char.job or nil
    local grade = type(char.job_grade) == 'number' and char.job_grade or 0
    if job then
        groups[job] = grade
    end

    -- Groupe système (admin / founder / moderator…) → préfixe "sys:"
    -- Évite l'écrasement si un job s'appelle "admin" par exemple.
    local sysGroup = type(player.group) == 'string' and player.group or nil
    if sysGroup and sysGroup ~= 'user' then
        groups['sys:' .. sysGroup] = 0
    end

    return groups
end

---Valide qu'un characterData minimal est exploitable.
---@param characterData table|nil
---@return boolean, string|nil  ok, raison
local function validateCharacterData(characterData)
    if type(characterData) ~= 'table' then
        return false, 'characterData n\'est pas une table'
    end
    if type(characterData.unique_id) ~= 'string' or characterData.unique_id == '' then
        return false, 'unique_id manquant ou invalide'
    end
    return true, nil
end

-- ─────────────────────────────────────────────────────────────
-- Guard contre les double-appels
-- Clé = src, valeur = true pendant le chargement.
-- TOUJOURS libéré dans un bloc finally (after pcall).
-- ─────────────────────────────────────────────────────────────

local _loadingPlayers = {}

---Libère le verrou de chargement pour une source.
---Idempotent (appelable plusieurs fois sans risque).
---@param src number
local function releaseLock(src)
    _loadingPlayers[src] = nil
end

-- ─────────────────────────────────────────────────────────────
-- Déconnexion — libère toujours le verrou
-- ─────────────────────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    local src = source
    releaseLock(src)           -- sécurité si le joueur drop pendant le chargement
    server.playerDropped(src)
end)

-- ─────────────────────────────────────────────────────────────
-- POINT D'ENTRÉE UNIQUE : chargement inventaire au spawn
--
-- Le retry GetPlayerFromId est exécuté dans un thread Citizen dédié
-- pour ne jamais bloquer le thread principal du serveur.
-- ─────────────────────────────────────────────────────────────

AddEventHandler('union:player:spawned', function(src, characterData)
    -- ── 1. Guard double-appel ────────────────────────────────
    if _loadingPlayers[src] then
        lib.print.warn(('[union:bridge] union:player:spawned ignoré — chargement déjà en cours (src=%s)'):format(src))
        return
    end

    -- ── 2. Validation précoce ────────────────────────────────
    local ok, reason = validateCharacterData(characterData)
    if not ok then
        lib.print.warn(('[union:bridge] union:player:spawned — données invalides (src=%s) : %s'):format(src, reason))
        return
    end

    _loadingPlayers[src] = true
    local uniqueId = characterData.unique_id

    -- ── 3. Tout le travail bloquant dans un thread séparé ────
    Citizen.CreateThread(function()

        -- ── 3a. Retry non bloquant sur GetPlayerFromId ───────
        -- Jusqu'à 10 tentatives × 200 ms = max 2 s d'attente.
        -- On utilise un thread dédié donc le serveur n'est pas freezé.
        local player = nil
        for attempt = 1, 10 do
            player = getUnionPlayer(src)
            if player then break end

            lib.print.warn(('[union:bridge] GetPlayerFromId(%s) = nil, tentative %d/10'):format(src, attempt))

            -- Vérifie si le joueur s'est déconnecté entre deux tentatives
            if not GetPlayerName(src) then
                lib.print.info(('[union:bridge] src=%s déconnecté pendant le retry, abandon'):format(src))
                releaseLock(src)
                return
            end

            Wait(200)
        end

        if not player then
            lib.print.error(('[union:bridge] Impossible de résoudre le joueur (src=%s, uid=%s) après 10 tentatives'):format(src, uniqueId))
            releaseLock(src)
            return
        end

        -- ── 3b. Données du personnage ────────────────────────
        -- On fusionne characterData (envoyé par l'event) avec
        -- currentCharacter si disponible, en préférant les données fraîches.
        local char = (type(player.currentCharacter) == 'table' and player.currentCharacter)
                  or characterData

        -- Sécurité : s'assurer que unique_id est cohérent
        if type(char.unique_id) ~= 'string' or char.unique_id == '' then
            char.unique_id = uniqueId
        end

        -- ── 3c. Construction des groupes sans collision ──────
        local groups = buildGroups(char, player)

        -- ── 3d. Objet ktPlayer ───────────────────────────────
        local playerName = type(player.name) == 'string' and player.name ~= '' and player.name
                        or GetPlayerName(src)
                        or ('Player_%s'):format(src)

        local ktPlayer = {
            source      = src,
            name        = playerName,
            identifier  = uniqueId,
            groups      = groups,
            sex         = char.gender,
            dateofbirth = char.dateofbirth,
        }

        lib.print.info(('[union:bridge] Chargement inventaire → uid=%s (%s)'):format(uniqueId, ktPlayer.name))

        -- ── 3e. Appel setPlayerInventory avec finally ────────
        local invOk, invErr = pcall(server.setPlayerInventory, ktPlayer)

        -- Toujours libérer le verrou, succès ou échec
        releaseLock(src)

        if not invOk then
            lib.print.error(('[union:bridge] setPlayerInventory échoué (uid=%s, name=%s) : %s'):format(
                uniqueId, ktPlayer.name, tostring(invErr)
            ))
        end
    end)
end)

-- ─────────────────────────────────────────────────────────────
-- Mise à jour job en live
-- ─────────────────────────────────────────────────────────────

AddEventHandler('union:job:updated', function(src, job, grade)
    -- Validation des types avant toute opération
    if type(src) ~= 'number' then return end
    if type(job) ~= 'string' or job == '' then
        lib.print.warn(('[union:bridge] union:job:updated — job invalide pour src=%s'):format(src))
        return
    end
    grade = type(grade) == 'number' and grade or 0

    local inv = Inventory(src)
    if not inv then
        lib.print.warn(('[union:bridge] union:job:updated — inventaire introuvable pour src=%s'):format(src))
        return
    end

    -- Mise à jour sûre : player peut ne pas encore avoir de table groups
    if type(inv.player) ~= 'table' then
        lib.print.warn(('[union:bridge] union:job:updated — inv.player absent pour src=%s'):format(src))
        return
    end
    if type(inv.player.groups) ~= 'table' then
        inv.player.groups = {}
    end

    inv.player.groups[job] = grade

    lib.print.info(('[union:bridge] Job mis à jour src=%s : %s (grade %s)'):format(src, job, grade))
end)

-- ─────────────────────────────────────────────────────────────
-- server.setPlayerData
-- ─────────────────────────────────────────────────────────────

---@diagnostic disable-next-line: duplicate-set-field
function server.setPlayerData(player)
    if type(player) ~= 'table' then return {} end
    return {
        source      = player.source,
        name        = player.name,
        groups      = type(player.groups) == 'table' and player.groups or {},
        sex         = player.sex,
        dateofbirth = player.dateofbirth,
    }
end

-- ─────────────────────────────────────────────────────────────
-- server.syncInventory — Union gère sa banque séparément
-- ─────────────────────────────────────────────────────────────

---@diagnostic disable-next-line: duplicate-set-field
function server.syncInventory(_inv)
    -- Intentionnellement vide : Union gère la persistance côté bank
end

-- ─────────────────────────────────────────────────────────────
-- Licences
-- Utilise MySQL.single (retourne directement la valeur scalaire)
-- au lieu de MySQL.fetchOne (retourne une ligne complète).
-- ─────────────────────────────────────────────────────────────

---@diagnostic disable-next-line: duplicate-set-field
function server.hasLicense(inv, name)
    -- Validation des entrées
    if type(inv) ~= 'table' or type(inv.owner) ~= 'string' then return false end
    if type(name) ~= 'string' or name == '' then return false end

    -- MySQL.single retourne directement la valeur (1 ou nil) → plus léger
    local result = MySQL.single.await(
        'SELECT 1 FROM `user_licenses` WHERE `type` = ? AND `unique_id` = ? LIMIT 1',
        { name, inv.owner }
    )
    return result ~= nil
end

---@diagnostic disable-next-line: duplicate-set-field
function server.buyLicense(inv, license)
    -- Validation
    if type(inv) ~= 'table' or type(inv.owner) ~= 'string' then
        return false, 'invalid_inventory'
    end
    if type(license) ~= 'table' or type(license.name) ~= 'string' then
        return false, 'invalid_license'
    end

    if server.hasLicense(inv, license.name) then
        return false, 'already_have'
    end

    local price = type(license.price) == 'number' and license.price or 0
    if Inventory.GetItemCount(inv, 'money') < price then
        return false, 'can_not_afford'
    end

    Inventory.RemoveItem(inv, 'money', price)

    -- Récupère l'identifier via MySQL.single (colonne unique, pas de fetch complet)
    local identifier = MySQL.single.await(
        'SELECT identifier FROM characters WHERE unique_id = ? LIMIT 1',
        { inv.owner }
    )

    MySQL.query(
        'INSERT IGNORE INTO `user_licenses` (identifier, unique_id, type) VALUES (?, ?, ?)',
        { identifier or inv.owner, inv.owner, license.name }
    )

    return true, 'have_purchased'
end

-- ─────────────────────────────────────────────────────────────
-- Boss check
-- ─────────────────────────────────────────────────────────────

---@diagnostic disable-next-line: duplicate-set-field
function server.isPlayerBoss(playerId, _group, _grade)
    if type(playerId) ~= 'number' then return false end

    local player = getUnionPlayer(playerId)
    if not player then return false end

    local grp = type(player.group) == 'string' and player.group or ''
    return grp == 'admin' or grp == 'founder'
end

-- ─────────────────────────────────────────────────────────────
-- Véhicules
-- ─────────────────────────────────────────────────────────────

---@diagnostic disable-next-line: duplicate-set-field
function server.getOwnedVehicleId(entityId)
    if type(entityId) ~= 'number' then return nil end

    local plate = GetVehicleNumberPlateText(entityId)
    if type(plate) ~= 'string' or plate == '' then return nil end

    -- Trim whitespace (les plaques GTA sont souvent paddées)
    local trimmed = plate:match('^%s*(.-)%s*$')
    return (trimmed ~= '') and trimmed or nil
end

-- ─────────────────────────────────────────────────────────────
-- Diagnostic : état du bridge (utile en debug)
-- ─────────────────────────────────────────────────────────────

if Config and Config.debug then
    RegisterCommand('union:bridge:status', function(src)
        if src ~= 0 then return end  -- console uniquement
        local pending = 0
        for _ in pairs(_loadingPlayers) do pending = pending + 1 end
        lib.print.info(('[union:bridge] Joueurs en cours de chargement : %d'):format(pending))
        for s, _ in pairs(_loadingPlayers) do
            lib.print.info(('  → src=%s (%s)'):format(s, GetPlayerName(s) or '?'))
        end
    end, true)
end

lib.print.info('[kt_inventory] Bridge Union Framework chargé (production-ready).')