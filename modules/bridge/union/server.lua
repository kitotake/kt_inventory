-- modules/bridge/union/server.lua

if not lib then return end

local Inventory = require 'modules.inventory.server'
local Items     = require 'modules.items.server'

-- ─────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────

local function getUnionPlayer(src)
    return exports['union']:GetPlayerFromId(src)
end

-- ─────────────────────────────────────────────────────────────
-- Déconnexion
-- ─────────────────────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    server.playerDropped(source)
    _loadingPlayers[source] = nil
end)

-- ─────────────────────────────────────────────────────────────
-- Guard contre les double-appels
-- ─────────────────────────────────────────────────────────────

local _loadingPlayers = {}

-- ─────────────────────────────────────────────────────────────
-- POINT D'ENTRÉE UNIQUE : chargement inventaire au spawn
--
-- C'est LE SEUL endroit où setPlayerInventory est appelé.
-- inventory/main.lua n'écoute PAS union:player:spawned.
-- ─────────────────────────────────────────────────────────────

AddEventHandler('union:player:spawned', function(src, characterData)
    if _loadingPlayers[src] then
        lib.print.warn(('[kt_inventory:union] union:player:spawned ignoré — chargement déjà en cours pour source %s'):format(src))
        return
    end

    _loadingPlayers[src] = true

    if not characterData or not characterData.unique_id then
        lib.print.warn(
            ('[kt_inventory:union] union:player:spawned — unique_id manquant pour source %s'):format(src)
        )
        _loadingPlayers[src] = nil
        return
    end

    local uniqueId = characterData.unique_id

    -- Retry : PlayerManager peut ne pas être encore prêt
    local player = nil
    for i = 1, 10 do
        player = getUnionPlayer(src)
        if player then break end
        lib.print.warn(
            ('[kt_inventory:union] GetPlayerFromId(%s) = nil, tentative %d/10'):format(src, i)
        )
        Wait(200)
    end

    if not player then
        lib.print.error(
            ('[kt_inventory:union] Impossible de charger l\'inventaire pour %s (unique_id=%s)'):format(src, uniqueId)
        )
        _loadingPlayers[src] = nil
        return
    end

    local char = player.currentCharacter or characterData

    -- Groupes
    local groups = {}
    if char.job and char.job ~= '' then
        groups[char.job] = char.job_grade or 0
    end
    if player.group and player.group ~= 'user' then
        groups[player.group] = 0
    end

    -- Objet ktPlayer compatible server.setPlayerInventory
    local ktPlayer = {
        source      = src,
        name        = player.name or GetPlayerName(src),
        identifier  = uniqueId,
        groups      = groups,
        sex         = char.gender,
        dateofbirth = char.dateofbirth,
    }

    lib.print.info(
        ('[kt_inventory:union] Chargement inventaire → unique_id=%s (%s)'):format(uniqueId, ktPlayer.name)
    )

    local ok, err = pcall(server.setPlayerInventory, ktPlayer)

    if not ok then
        lib.print.error(('[kt_inventory:union] setPlayerInventory échoué pour %s : %s'):format(ktPlayer.name, tostring(err)))
    end

    _loadingPlayers[src] = nil
end)

-- ─────────────────────────────────────────────────────────────
-- Mise à jour job en live
-- ─────────────────────────────────────────────────────────────

AddEventHandler('union:job:updated', function(src, job, grade)
    local inv = Inventory(src)
    if not inv then return end
    inv.player.groups[job] = grade
    lib.print.info(
        ('[kt_inventory:union] Job mis à jour source=%s : %s (grade %s)'):format(src, job, grade)
    )
end)

-- ─────────────────────────────────────────────────────────────
-- server.setPlayerData
-- ─────────────────────────────────────────────────────────────

---@diagnostic disable-next-line: duplicate-set-field
function server.setPlayerData(player)
    return {
        source      = player.source,
        name        = player.name,
        groups      = player.groups or {},
        sex         = player.sex,
        dateofbirth = player.dateofbirth,
    }
end

-- ─────────────────────────────────────────────────────────────
-- server.syncInventory — Union gère sa banque séparément
-- ─────────────────────────────────────────────────────────────

---@diagnostic disable-next-line: duplicate-set-field
function server.syncInventory(_inv)
    -- rien à synchroniser vers Union
end

-- ─────────────────────────────────────────────────────────────
-- Licences
-- ─────────────────────────────────────────────────────────────

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
    end
    if Inventory.GetItemCount(inv, 'money') < license.price then
        return false, 'can_not_afford'
    end

    Inventory.RemoveItem(inv, 'money', license.price)

    local row = MySQL.fetchOne and
        MySQL.fetchOne.await('SELECT identifier FROM characters WHERE unique_id = ?', { inv.owner })

    MySQL.query(
        'INSERT IGNORE INTO `user_licenses` (identifier, unique_id, type) VALUES (?, ?, ?)',
        { row and row.identifier or inv.owner, inv.owner, license.name }
    )

    return true, 'have_purchased'
end

-- ─────────────────────────────────────────────────────────────
-- Boss check
-- ─────────────────────────────────────────────────────────────

---@diagnostic disable-next-line: duplicate-set-field
function server.isPlayerBoss(playerId, _group, _grade)
    local player = getUnionPlayer(playerId)
    if not player then return false end
    return player.group == 'admin' or player.group == 'founder'
end

-- ─────────────────────────────────────────────────────────────
-- Véhicules
-- ─────────────────────────────────────────────────────────────

---@diagnostic disable-next-line: duplicate-set-field
function server.getOwnedVehicleId(entityId)
    local plate = GetVehicleNumberPlateText(entityId)
    if not plate or plate == '' then return nil end
    return plate:match('^%s*(.-)%s*$')
end

lib.print.info('[kt_inventory] Bridge Union Framework chargé.')