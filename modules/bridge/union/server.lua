-- modules/bridge/union/server.lua
-- Bridge entre kt_inventory et Union Framework
-- Remplace le bridge ESX/QBX pour le framework "union"

if not lib.checkDependency then
    return warn("kt_lib manquant ou incompatible")
end

local Inventory = require 'modules.inventory.server'
local Items     = require 'modules.items.server'

-- ──────────────────────────────────────────────
-- Connexion aux events Union
-- ──────────────────────────────────────────────

-- Joueur déconnecté
AddEventHandler("playerDropped", server.playerDropped)

-- Mise à jour du job en live
AddEventHandler("union:job:updated", function(source, job, grade)
    local inventory = Inventory(source)
    if not inventory then return end
    inventory.player.groups[job] = grade
end)

-- ──────────────────────────────────────────────
-- Chargement de l'inventaire quand un personnage
-- est sélectionné côté Union
-- ──────────────────────────────────────────────
AddEventHandler("union:player:spawned", function(source, characterData)
    if not characterData or not characterData.unique_id then
        warn(("[kt_inventory] union:player:spawned — unique_id manquant pour source %s"):format(source))
        return
    end

    -- Récupère l'objet Player Union depuis PlayerManager
    local player = exports["union"]:GetPlayerFromId(source)
    if not player then
        warn(("[kt_inventory] PlayerManager.get(%s) retourne nil"):format(source))
        return
    end

    server.setPlayerInventory(player)
end)

-- ──────────────────────────────────────────────
-- server.setPlayerData : transforme le joueur Union
-- en structure attendue par kt_inventory
-- ──────────────────────────────────────────────
---@diagnostic disable-next-line: duplicate-set-field
function server.setPlayerData(player)
    -- Groupes : job actuel + admin group
    local groups = {}

    if player.currentCharacter then
        local job   = player.currentCharacter.job       or "unemployed"
        local grade = player.currentCharacter.job_grade or 0
        groups[job] = grade
    end

    -- Permission group (user / moderator / admin / founder)
    if player.group and player.group ~= "user" then
        groups[player.group] = 0
    end

    return {
        source      = player.source,
        name        = player.name,
        groups      = groups,
        sex         = player.currentCharacter and player.currentCharacter.gender or nil,
        dateofbirth = player.currentCharacter and player.currentCharacter.dateofbirth or nil,
    }
end

-- ──────────────────────────────────────────────
-- Sync inventaire → Union (compte money en item)
-- ──────────────────────────────────────────────
---@diagnostic disable-next-line: duplicate-set-field
function server.syncInventory(inv)
    local accounts = Inventory.GetAccountItemCounts(inv)
    if not accounts then return end
    -- Union ne gère pas les comptes via kt_inventory (bank séparée)
    -- On ne sync rien vers le framework pour éviter les doublons
end

-- ──────────────────────────────────────────────
-- Licences via la table user_licenses de Union
-- ──────────────────────────────────────────────
---@diagnostic disable-next-line: duplicate-set-field
function server.hasLicense(inv, name)
    return MySQL.scalar.await(
        'SELECT 1 FROM `user_licenses` WHERE `type` = ? AND `unique_id` = ?',
        { name, inv.owner }
    )
end

---@diagnostic disable-next-line: duplicate-set-field
function server.buyLicense(inv, license)
    if server.hasLicense(inv, license.name) then
        return false, 'already_have'
    elseif Inventory.GetItemCount(inv, 'money') < license.price then
        return false, 'can_not_afford'
    end

    Inventory.RemoveItem(inv, 'money', license.price)

    MySQL.insert(
        'INSERT IGNORE INTO `user_licenses` (identifier, unique_id, type) VALUES (?, ?, ?)',
        { inv.player and inv.player.license or inv.owner, inv.owner, license.name }
    )

    return true, 'have_purchased'
end

-- ──────────────────────────────────────────────
-- Boss check (via PermissionGroups si dispo)
-- ──────────────────────────────────────────────
---@diagnostic disable-next-line: duplicate-set-field
function server.isPlayerBoss(playerId, group, grade)
    -- Union n'a pas de notion de boss par job-grade, on utilise les permissions
    local player = exports["union"]:GetPlayerFromId(playerId)
    if not player then return false end
    return player.group == "admin" or player.group == "founder"
end

-- ──────────────────────────────────────────────
-- Véhicules : owned_vehicles utilise `plate` comme ID
-- ──────────────────────────────────────────────
---@diagnostic disable-next-line: duplicate-set-field
function server.getOwnedVehicleId(entityId)
    -- Union stocke les véhicules par plaque
    local plate = GetVehicleNumberPlateText(entityId)
    if not plate or plate == "" then return nil end
    return string.strtrim and string.strtrim(plate) or plate:match("^%s*(.-)%s*$")
end

-- ──────────────────────────────────────────────
-- Hook : quand le serveur Union charge le joueur,
-- on initialise l'inventaire kt_inventory
-- ──────────────────────────────────────────────
AddEventHandler("union:server:ready", function()
    lib.print.info("[kt_inventory] Bridge Union prêt")
end)