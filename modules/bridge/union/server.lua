-- kt_inventory/modules/bridge/union/server.lua
-- Bridge kt_inventory ↔ Union Framework (SERVER CLEAN FIXED)

if not lib then return end

local Inventory = require 'modules.inventory.server'
local Items     = require 'modules.items.server'

-- ─────────────────────────────────────────────
-- STATE
-- ─────────────────────────────────────────────

local _loadingPlayers = {}

-- ─────────────────────────────────────────────
-- HELPERS
-- ─────────────────────────────────────────────

local function debug(msg)
    if Config and Config.debug then
        print("^3[kt_inventory:union]^0 " .. msg)
    end
end

local function getUnionPlayer(src)
    local ok, player = pcall(function()
        return exports['union']:GetPlayerFromId(src)
    end)
    return ok and player or nil
end

local function release(src)
    _loadingPlayers[src] = nil
end

local function isValidChar(char)
    return type(char) == "table" and type(char.unique_id) == "string"
end

-- ─────────────────────────────────────────────
-- GROUP BUILDER SAFE
-- ─────────────────────────────────────────────

local function buildGroups(char, player)
    local groups = {}

    local job = char.job
    local grade = char.job_grade or 0

    if type(job) == "string" and job ~= "" then
        groups[job] = grade
    end

    local sys = player.group
    if type(sys) == "string" and sys ~= "user" then
        groups["sys:" .. sys] = 0
    end

    return groups
end

-- ─────────────────────────────────────────────
-- SPAWN HANDLER
-- ─────────────────────────────────────────────

AddEventHandler('union:player:spawned', function(src, characterData)

    if _loadingPlayers[src] then
        debug("skip spawn (already loading) src=" .. src)
        return
    end

    if not isValidChar(characterData) then
        debug("invalid character data src=" .. src)
        return
    end

    _loadingPlayers[src] = true

    CreateThread(function()

        local player = nil

        for i = 1, 10 do
            player = getUnionPlayer(src)
            if player then break end
            Wait(200)
        end

        if not player then
            debug("failed to get player src=" .. src)
            release(src)
            return
        end

        local char = player.currentCharacter or characterData
        char.unique_id = char.unique_id or characterData.unique_id

        local groups = buildGroups(char, player)

        local ktPlayer = {
            source     = src,
            name       = player.name or GetPlayerName(src),
            identifier = char.unique_id,
            groups     = groups,
            sex        = char.gender,
            dob        = char.dateofbirth
        }

        debug(("loading inventory uid=%s"):format(char.unique_id))

        local ok, err = pcall(server.setPlayerInventory, ktPlayer)

        release(src)

        if not ok then
            print("^1[kt_inventory] ERROR setPlayerInventory: " .. tostring(err) .. "^0")
        end
    end)
end)

-- ─────────────────────────────────────────────
-- JOB UPDATE LIVE
-- ─────────────────────────────────────────────

AddEventHandler('union:job:updated', function(src, job, grade)
    if type(src) ~= "number" then return end

    local inv = Inventory(src)
    if not inv or not inv.player then return end

    inv.player.groups = inv.player.groups or {}
    inv.player.groups[job] = grade or 0

    debug(("job update %s => %s"):format(src, job))
end)

-- ─────────────────────────────────────────────
-- STATUS HOOK (IMPORTANT POUR FOOD SYSTEM)
-- ─────────────────────────────────────────────

RegisterNetEvent("union:status:actionFromItem", function(values)
    local src = source
    local status = StatusManager and StatusManager.cache and StatusManager.cache[src]

    if not status then return end

    if values.hunger then
        StatusManager.add(src, "hunger", values.hunger / 10000)
    end

    if values.thirst then
        StatusManager.add(src, "thirst", values.thirst / 10000)
    end

    if values.stress then
        StatusManager.add(src, "stress", values.stress / 10000)
    end
end)

-- ─────────────────────────────────────────────
-- LICENSE SYSTEM
-- ─────────────────────────────────────────────

function server.hasLicense(inv, name)
    if type(inv) ~= "table" or type(inv.owner) ~= "string" then return false end

    local result = MySQL.single.await(
        'SELECT 1 FROM user_licenses WHERE type = ? AND unique_id = ? LIMIT 1',
        { name, inv.owner }
    )

    return result ~= nil
end

function server.buyLicense(inv, license)
    if type(inv) ~= "table" then return false end

    if server.hasLicense(inv, license.name) then
        return false, "already_have"
    end

    local price = license.price or 0

    if Inventory.GetItemCount(inv, "money") < price then
        return false, "no_money"
    end

    Inventory.RemoveItem(inv, "money", price)

    MySQL.query(
        'INSERT IGNORE INTO user_licenses (identifier, unique_id, type) VALUES (?, ?, ?)',
        { inv.owner, inv.owner, license.name }
    )

    return true
end

-- ─────────────────────────────────────────────
-- CLEANUP
-- ─────────────────────────────────────────────

AddEventHandler("playerDropped", function()
    local src = source
    release(src)
end)

print("^2[kt_inventory] Union bridge loaded^0")