-- modules/bridge/union/server.lua
-- Corrections :
--   [FIX-1] server.setPlayerInventory appelé via pcall avec vérification du retour
--   [FIX-2] AddStat : vérification que la fonction export existe avant l'appel
--   [FIX-3] hasLicense / buyLicense : MySQL.single remplacé par MySQL.scalar (plus portable)
--   [FIX-4] onResourceStart : gestion du cas où GetPlayers() retourne des strings
--   [FIX-5] union:status:actionFromItem : validation des valeurs (nombres entiers, bornes)

if not lib then return end

local Inventory = require "modules.inventory.server"
local Items     = require "modules.items.server"

-- ─────────────────────────────────────────────
-- STATE
-- ─────────────────────────────────────────────

local _loadingPlayers = {}

-- ─────────────────────────────────────────────
-- PLAYER INVENTORY SETUP
-- ─────────────────────────────────────────────

function server.setPlayerInventory(ktPlayer)
    if type(ktPlayer) ~= "table" then return end
    
    local src = ktPlayer.source
    if not src then return end
    
    -- Créer l'inventaire du joueur
    local inv = Inventory(src, true)
    if not inv then
        print(("^1[kt_inventory] Impossible de créer l'inventaire pour src=%d^0"):format(src))
        return
    end
    
    -- Ajouter les données du joueur
    inv.owner = ktPlayer.identifier
    inv.player = {
        source = src,
        name = ktPlayer.name,
        identifier = ktPlayer.identifier,
        groups = ktPlayer.groups or {},
        sex = ktPlayer.sex,
        dob = ktPlayer.dob,
    }
    
    -- Envoyer l'événement au client pour initialiser PlayerData
    TriggerClientEvent('kt_inventory:setPlayerInventory', src, {}, inv.items or {}, inv.weight or 0, {
        source = src,
        name = ktPlayer.name,
        identifier = ktPlayer.identifier,
        groups = ktPlayer.groups or {},
        sex = ktPlayer.sex,
        dob = ktPlayer.dob,
        loaded = true,
        inventory = inv.items or {},
        weight = inv.weight or 0,
    })
    
    print(("^2[kt_inventory] Inventaire chargé pour %s (src=%d)^0"):format(ktPlayer.name, src))
end

-- ─────────────────────────────────────────────

local function debug(msg)
    if Config and Config.debug then
        print("^3[kt_inventory:union]^0 " .. tostring(msg))
    end
end

local function getUnionPlayer(src)
    local ok, player = pcall(function()
        return exports["union"]:GetPlayerFromId(src)
    end)
    return ok and player or nil
end

local function release(src)
    _loadingPlayers[src] = nil
end

local function isValidChar(char)
    return type(char) == "table" and type(char.unique_id) == "string" and char.unique_id ~= ""
end

-- ─────────────────────────────────────────────
-- GROUP BUILDER
-- ─────────────────────────────────────────────

local function buildGroups(char, player)
    local groups = {}

    local job   = char.job
    local grade = char.job_grade or 0

    if type(job) == "string" and job ~= "" then
        groups[job] = grade
    end

    -- Groupe système (admin, moderator, etc.)
    local sys = player and player.group
    if type(sys) == "string" and sys ~= "user" and sys ~= "" then
        groups["sys:" .. sys] = 0
    end

    return groups
end

-- ─────────────────────────────────────────────
-- SPAWN HANDLER [FIX-1]
-- ─────────────────────────────────────────────

AddEventHandler("union:player:spawned", function(src, characterData)
    if _loadingPlayers[src] then
        debug("skip spawn (déjà en cours) src=" .. tostring(src))
        return
    end

    if not isValidChar(characterData) then
        debug("données personnage invalides src=" .. tostring(src))
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
            debug("impossible d'obtenir le joueur src=" .. tostring(src))
            release(src)
            return
        end

        local char = player.currentCharacter or characterData
        -- Garantir unique_id
        char.unique_id = char.unique_id or characterData.unique_id

        if not isValidChar(char) then
            debug("char.unique_id invalide après merge src=" .. tostring(src))
            release(src)
            return
        end

        local groups = buildGroups(char, player)

        local ktPlayer = {
            source     = src,
            name       = player.name or GetPlayerName(src),
            identifier = char.unique_id,
            groups     = groups,
            sex        = char.gender or char.sex,
            dob        = char.dateofbirth or char.dob,
        }

        debug(("chargement inventaire uid=%s"):format(char.unique_id))

        -- [FIX-1] Vérification du retour de setPlayerInventory
        local ok, err = pcall(server.setPlayerInventory, ktPlayer)

        release(src)

        if not ok then
            print(("^1[kt_inventory] ERREUR setPlayerInventory src=%d: %s^0"):format(src, tostring(err)))
        end
    end)
end)

-- ─────────────────────────────────────────────
-- RE-INIT ON RESOURCE RESTART [FIX-4]
-- ─────────────────────────────────────────────

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    Wait(500)
	print('^3[kt_inventory] Réinitialisation après ensure...^0')

    for _, rawId in ipairs(GetPlayers()) do
        -- [FIX-4] GetPlayers() peut retourner strings ou numbers selon la version
        local playerId = tonumber(rawId)
        if not playerId then goto continueLoop end

        local player = getUnionPlayer(playerId)

        if player and player.currentCharacter then
            local char = player.currentCharacter

            if char and isValidChar(char) then
                debug(("re-init après ensure src=%d uid=%s"):format(playerId, char.unique_id))
				print(("^2[kt_inventory] Re-chargement inventaire pour joueur %s (src=%d)^0"):format(GetPlayerName(playerId), playerId))

                local pid = playerId  -- capture locale

                CreateThread(function()
                    Wait(200)

                    local groups = buildGroups(char, player)

                    local ktPlayer = {
                        source     = pid,
                        name       = player.name or GetPlayerName(pid),
                        identifier = char.unique_id,
                        groups     = groups,
                        sex        = char.gender or char.sex,
                        dob        = char.dateofbirth or char.dob,
                    }

                    local ok, err = pcall(server.setPlayerInventory, ktPlayer)

                    if not ok then
                        print(("^1[kt_inventory] ERREUR re-init src=%d: %s^0"):format(pid, tostring(err)))
					else
						print(("^2[kt_inventory] Inventaire rechargé avec succès pour src=%d^0"):format(pid))
                    end
                end)
            end
        end

        ::continueLoop::
    end
end)

-- ─────────────────────────────────────────────
-- JOB UPDATE LIVE
-- ─────────────────────────────────────────────

AddEventHandler("union:job:updated", function(src, job, grade)
    if type(src) ~= "number" then return end
    if type(job) ~= "string"  then return end

    local inv = Inventory(src)
    if not inv or not inv.player then return end

    inv.player.groups         = inv.player.groups or {}
    inv.player.groups[job]    = grade or 0

    debug(("job update src=%d %s=%d"):format(src, job, grade or 0))
end)

-- ─────────────────────────────────────────────
-- STATUS FROM ITEM [FIX-5]
-- ─────────────────────────────────────────────

-- [FIX-2] Vérification que l'export AddStat existe
local function safeAddStat(src, stat, value)
    local ok, err = pcall(function()
        return exports["union"].AddStat(nil, src, stat, value)
    end)
    if not ok then
        lib.print.warn(("[kt_inventory:union] Erreur %s: %s"):format(stat, tostring(err)))
    end
end

RegisterNetEvent("union:status:actionFromItem", function(values)
    local src = source

    if type(values) ~= "table" then return end

    -- [FIX-5] Validation + bornes pour éviter les exploits
    if values.hunger and type(values.hunger) == "number" then
        local v = math.floor(math.max(-100, math.min(500, values.hunger)))
        safeAddStat(src, "hunger", v)
    end

    if values.thirst and type(values.thirst) == "number" then
        local v = math.floor(math.max(-100, math.min(500, values.thirst)))
        safeAddStat(src, "thirst", v)
    end

    if values.stress and type(values.stress) == "number" then
        local v = math.floor(math.max(-100, math.min(100, values.stress)))
        safeAddStat(src, "stress", v)
    end
end)

-- ─────────────────────────────────────────────
-- LICENSE SYSTEM [FIX-3]
-- ─────────────────────────────────────────────

function server.hasLicense(inv, name)
    if type(inv) ~= "table" or type(inv.owner) ~= "string" then return false end

    -- [FIX-3] MySQL.scalar plus portable que MySQL.single
    local ok, result = pcall(function()
        return MySQL.scalar.await(
            "SELECT COUNT(*) FROM user_licenses WHERE type = ? AND unique_id = ? LIMIT 1",
            { name, inv.owner }
        )
    end)

    return ok and result and result > 0
end

function server.buyLicense(inv, license)
    if type(inv) ~= "table" then return false end

    if server.hasLicense(inv, license.name) then
        return false, "already_have"
    end

    local price = license.price or 0

    if Inventory.GetItemCount(inv, "money") < price then
        return false, "can_not_afford"
    end

    Inventory.RemoveItem(inv, "money", price)

    local ok, err = pcall(function()
        MySQL.query(
            "INSERT IGNORE INTO user_licenses (identifier, unique_id, type) VALUES (?, ?, ?)",
            { inv.owner, inv.owner, license.name }
        )
    end)

    if not ok then
        lib.print.warn(("[kt_inventory:union] buyLicense erreur: %s"):format(tostring(err)))
        return false, "db_error"
    end

    return true, "have_purchased"
end

-- ─────────────────────────────────────────────
-- CLEANUP À LA DÉCONNEXION
-- ─────────────────────────────────────────────

AddEventHandler("playerDropped", function()
    local src = source
    release(src)
end)

print("^2[kt_inventory] Union bridge server v3 chargé^0")