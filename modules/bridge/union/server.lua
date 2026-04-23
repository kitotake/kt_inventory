-- modules/bridge/union/server.lua
-- Bridge entre kt_inventory et Union Framework (côté serveur)

if not lib then return end

local Inventory = require 'modules.inventory.server'
local Items     = require 'modules.items.server'

-- ────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ────────────────────────────────────────────────────────────────────────────

--- Récupère le joueur Union depuis l'export Union
local function getUnionPlayer(source)
    return exports['union']:GetPlayerFromId(source)
end

-- ────────────────────────────────────────────────────────────────────────────
-- Déconnexion → fermeture + suppression de l'inventaire en mémoire
-- ────────────────────────────────────────────────────────────────────────────
AddEventHandler('playerDropped', server.playerDropped)

-- ────────────────────────────────────────────────────────────────────────────
-- Mise à jour du job en live (ex : /setjob)
-- ────────────────────────────────────────────────────────────────────────────
AddEventHandler('union:job:updated', function(source, job, grade)
    local inventory = Inventory(source)
    if not inventory then return end
    inventory.player.groups[job] = grade
end)

-- ────────────────────────────────────────────────────────────────────────────
-- Chargement de l'inventaire quand le personnage est spawné
-- Déclenché par union:spawn:confirm → union:player:spawned
-- ────────────────────────────────────────────────────────────────────────────
AddEventHandler('union:player:spawned', function(source, characterData)
    if not characterData or not characterData.unique_id then
        warn(('[kt_inventory:union] union:player:spawned — unique_id manquant pour source %s'):format(source))
        return
    end

    local player = getUnionPlayer(source)
    if not player then
        warn(('[kt_inventory:union] GetPlayerFromId(%s) = nil'):format(source))
        return
    end

    local char = player.currentCharacter or characterData

    -- Groupes : job actuel + groupe admin si applicable
    local groups = {}
    if char.job and char.job ~= '' then
        groups[char.job] = char.job_grade or 0
    end
    if player.group and player.group ~= 'user' then
        groups[player.group] = 0
    end

    -- Objet compatible avec server.setPlayerInventory
    -- IMPORTANT : identifier = unique_id → inventaire par personnage
    local ktPlayer = {
        source     = source,
        name       = player.name or GetPlayerName(source),
        identifier = char.unique_id,
        groups     = groups,
    }

    server.setPlayerInventory(ktPlayer)
end)

-- ────────────────────────────────────────────────────────────────────────────
-- server.setPlayerData : transforme l'objet kt_player en données kt_inventory
-- ────────────────────────────────────────────────────────────────────────────
---@diagnostic disable-next-line: duplicate-set-field
function server.setPlayerData(player)
    return {
        source      = player.source,
        name        = player.name,
        groups      = player.groups or {},
        sex         = nil,
        dateofbirth = nil,
    }
end

-- ────────────────────────────────────────────────────────────────────────────
-- server.syncInventory : Union gère sa banque séparément, pas de sync cash
-- ────────────────────────────────────────────────────────────────────────────
---@diagnostic disable-next-line: duplicate-set-field
function server.syncInventory(inv)
    -- Rien à synchroniser vers Union Framework
    -- (la banque Union est dans bank_accounts, pas dans les items)
end

-- ────────────────────────────────────────────────────────────────────────────
-- Licences via user_licenses de Union
-- ────────────────────────────────────────────────────────────────────────────
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

    -- Chercher l'identifier (license) depuis l'inventaire owner
    local charRow = MySQL.fetchOne and
        MySQL.fetchOne.await('SELECT identifier FROM characters WHERE unique_id = ?', { inv.owner }) or
        MySQL.row and MySQL.row.await and MySQL.row.await('SELECT identifier FROM characters WHERE unique_id = ?', { inv.owner })

    local identifier = charRow and charRow.identifier or inv.owner

    MySQL.query(
        'INSERT IGNORE INTO `user_licenses` (identifier, unique_id, type) VALUES (?, ?, ?)',
        { identifier, inv.owner, license.name }
    )

    return true, 'have_purchased'
end

-- ────────────────────────────────────────────────────────────────────────────
-- Boss check (basé sur le groupe Union)
-- ────────────────────────────────────────────────────────────────────────────
---@diagnostic disable-next-line: duplicate-set-field
function server.isPlayerBoss(playerId, group, grade)
    local player = getUnionPlayer(playerId)
    if not player then return false end
    return player.group == 'admin' or player.group == 'founder'
end

-- ────────────────────────────────────────────────────────────────────────────
-- Véhicules : Union identifie les véhicules par plaque
-- ────────────────────────────────────────────────────────────────────────────
---@diagnostic disable-next-line: duplicate-set-field
function server.getOwnedVehicleId(entityId)
    local plate = GetVehicleNumberPlateText(entityId)
    if not plate or plate == '' then return nil end
    return plate:match('^%s*(.-)%s*$')  -- trim whitespace
end

lib.print.info('[kt_inventory] Bridge Union Framework chargé.')