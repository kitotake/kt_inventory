-- modules/playerstatus/server.lua
-- Migré depuis le module status du framework union (manager.lua + status_tick.lua).
-- union ne gère plus rien lui-même : faim/soif/stress, persistance, décroissance
-- et anti-cheat sont désormais entièrement gérés ici.

if not lib then return end

local StatusConfig = lib.load('data.status')
local Inventory -- résolu au premier appel (évite un require circulaire, cf. modules/items/server.lua)

local PlayerStatus = {}

---@type table<number, { uniqueId: string, hunger: number, thirst: number, stress: number, dirty: boolean, pendingSend: boolean }>
local cache = {}
local loading = {}

local function clamp(v)
    v = tonumber(v) or 0
    return math.max(StatusConfig.min or 0, math.min(StatusConfig.max or 100, math.floor(v + 0.5)))
end

local function defaultStatus()
    return {
        hunger = StatusConfig.defaults.hunger or 100,
        thirst = StatusConfig.defaults.thirst or 100,
        stress = StatusConfig.defaults.stress or 0,
        dirty = false,
        pendingSend = false,
    }
end

---Proxy fiable pour "joueur spawné avec un perso chargé" — évite la dépendance
---à PlayerManager (interne à union, qui disparaît avec cette migration).
---@param src number
---@return boolean
local function isPlayerReady(src)
    Inventory = Inventory or require 'modules.inventory.server'
    local inv = Inventory(src)
    return inv ~= nil and inv.player ~= nil
end

-- Idempotent : ne recrée rien si la table existe déjà
Citizen.CreateThreadNow(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `player_status` (
            `id`          INT UNSIGNED      NOT NULL AUTO_INCREMENT,
            `unique_id`   VARCHAR(36)       NOT NULL,
            `hunger`      TINYINT UNSIGNED  NOT NULL DEFAULT 100,
            `thirst`      TINYINT UNSIGNED  NOT NULL DEFAULT 100,
            `stress`      TINYINT UNSIGNED  NOT NULL DEFAULT 0,
            `last_update` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uniq_unique_id` (`unique_id`),
            CONSTRAINT `fk_status_char` FOREIGN KEY (`unique_id`) REFERENCES `characters` (`unique_id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end)

---@param src number
---@param uniqueId string
---@param cb fun(status: table)?
function PlayerStatus.Load(src, uniqueId, cb)
    if loading[src] then
        lib.print.warn(('[kt_inventory:status] Double load ignoré src=%d uid=%s'):format(src, uniqueId))
        CreateThread(function()
            local waited = 0
            while loading[src] and waited < 3000 do Wait(100); waited += 100 end
            if cb then cb(cache[src]) end
        end)
        return
    end

    loading[src] = true
    local row = MySQL.single.await('SELECT hunger, thirst, stress FROM player_status WHERE unique_id = ?', { uniqueId })
    loading[src] = nil

    -- Race possible si reco rapide pendant la requête : on garde le cache existant
    if cache[src] and cache[src].uniqueId == uniqueId then
        if cb then cb(cache[src]) end
        return
    end

    local status = defaultStatus()
    status.uniqueId = uniqueId

    if row then
        status.hunger = clamp(row.hunger)
        status.thirst = clamp(row.thirst)
        status.stress = clamp(row.stress)
    else
        MySQL.insert('INSERT INTO player_status (unique_id) VALUES (?)', { uniqueId })
    end

    cache[src] = status

    TriggerClientEvent('kt_inventory:playerStatus:init', src, {
        hunger = status.hunger, thirst = status.thirst, stress = status.stress
    })

    if cb then cb(status) end
end

---@param src number
function PlayerStatus.Save(src)
    local status = cache[src]
    if not status or not status.dirty or not status.uniqueId then return end

    MySQL.prepare([[
        INSERT INTO player_status (unique_id, hunger, thirst, stress, last_update)
        VALUES (?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE hunger = VALUES(hunger), thirst = VALUES(thirst), stress = VALUES(stress), last_update = NOW()
    ]], { status.uniqueId, status.hunger, status.thirst, status.stress })

    status.dirty = false
end

---@param src number
---@return table?
function PlayerStatus.Get(src)
    return cache[src]
end

---@param src number
---@param stat 'hunger'|'thirst'|'stress'
---@param value number
function PlayerStatus.Set(src, stat, value)
    local status = cache[src]
    if not status or status[stat] == nil then return end

    status[stat] = clamp(value)
    status.dirty = true
    status.pendingSend = true
end

---@param src number
---@param stat 'hunger'|'thirst'|'stress'
---@param delta number
function PlayerStatus.Add(src, stat, delta)
    local status = cache[src]
    if not status then return end

    PlayerStatus.Set(src, stat, (status[stat] or 0) + (delta or 0))
end

---@param src number
function PlayerStatus.Sync(src)
    local status = cache[src]
    if not status then return end

    TriggerClientEvent('kt_inventory:playerStatus:updateAll', src, {
        hunger = status.hunger, thirst = status.thirst, stress = status.stress
    })
    status.pendingSend = false
end

function PlayerStatus.SetAndSync(src, stat, value)
    PlayerStatus.Set(src, stat, value)
    PlayerStatus.Sync(src)
end

---Utilisé par les items (kt_inventory:setPlayerStatus côté client → union:status:actionFromItem).
function PlayerStatus.AddAndSync(src, stat, delta)
    PlayerStatus.Add(src, stat, delta)
    PlayerStatus.Sync(src)
    PlayerStatus.Save(src)
end

function PlayerStatus.FlushPendingSends()
    for src, status in pairs(cache) do
        if status.pendingSend then
            PlayerStatus.Sync(src)
        end
    end
end

-- ─────────────────────────────────────────────
-- Anti-cheat : le client ne peut que PROPOSER une baisse de stat.
-- Le serveur n'accepte jamais une valeur > son cache + tolérance.
-- ─────────────────────────────────────────────
RegisterNetEvent('kt_inventory:playerStatus:sync', function(clientStatus)
    local src = source
    if type(clientStatus) ~= 'table' then return end
    if not isPlayerReady(src) then return end

    local status = cache[src]
    if not status then return end

    local tolerance = StatusConfig.syncTolerance or 5

    for _, stat in ipairs({ 'hunger', 'thirst', 'stress' }) do
        local clientVal = clientStatus[stat]

        if clientVal ~= nil then
            clientVal = clamp(clientVal)
            local serverVal = status[stat] or 0

            if clientVal <= serverVal + tolerance then
                status[stat] = clientVal
                status.dirty = true
            else
                lib.print.warn(('[kt_inventory:status] Sync suspect src=%d stat=%s client=%d server=%d'):format(
                    src, stat, clientVal, serverVal))
            end
        end
    end
end)

AddEventHandler('union:player:spawned', function(src, characterData)
    if type(characterData) ~= 'table' or type(characterData.unique_id) ~= 'string' or characterData.unique_id == '' then
        return
    end

    PlayerStatus.Load(src, characterData.unique_id)
end)

AddEventHandler('playerDropped', function()
    local src = source
    PlayerStatus.Save(src)
    cache[src] = nil
    loading[src] = nil
end)

-- ─────────────────────────────────────────────
-- Tick : décroissance + effets
-- ─────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(StatusConfig.tickInterval or 10000)

        for src, status in pairs(cache) do
            if isPlayerReady(src) then
                PlayerStatus.Add(src, 'hunger', -(StatusConfig.decay.hunger or 0.15))
                PlayerStatus.Add(src, 'thirst', -(StatusConfig.decay.thirst or 0.25))

                if status.stress > 0 then
                    PlayerStatus.Add(src, 'stress', -(StatusConfig.decay.stress or 0.5))
                end

                local threshold = StatusConfig.min or 0

                if StatusConfig.effects.damageOnEmpty and (status.hunger <= threshold or status.thirst <= threshold) then
                    TriggerClientEvent('kt_inventory:playerStatus:applyDamage', src, StatusConfig.effects.damageAmount or 4)
                end

                if StatusConfig.effects.stressVisual then
                    if status.stress >= 90 then
                        TriggerClientEvent('kt_inventory:playerStatus:stressEffect', src, 'max')
                    elseif status.stress >= 75 then
                        TriggerClientEvent('kt_inventory:playerStatus:stressEffect', src, 'high')
                    elseif status.stress >= 50 then
                        TriggerClientEvent('kt_inventory:playerStatus:stressEffect', src, 'low')
                    end
                end
            end
        end

        PlayerStatus.FlushPendingSends()
    end
end)

-- Sauvegarde périodique, étalée pour ne pas spike la DB
CreateThread(function()
    while true do
        Wait(StatusConfig.saveInterval or 30000)

        for src, status in pairs(cache) do
            if status.dirty then
                PlayerStatus.Save(src)
                Wait(25)
            end
        end
    end
end)

exports('GetPlayerStatus', PlayerStatus.Get)
exports('SetStat', PlayerStatus.SetAndSync)
exports('AddStat', PlayerStatus.AddAndSync)
exports('AddPlayerStat', PlayerStatus.Add) -- silencieux, remonté au prochain tick (utile en haute fréquence)

lib.print.info('^2[kt_inventory] modules/playerstatus/server module loaded^0')

return PlayerStatus