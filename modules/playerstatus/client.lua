-- modules/playerstatus/client.lua
-- Migré depuis client/modules/player/status/status_client.lua (union).

if not lib then return end

StatusClient = {}
StatusClient.status = { hunger = 100, thirst = 100, stress = 0 }
StatusClient.ready  = false

local plyState = LocalPlayer.state

local function pushToNui()
    if not client.uiLoaded then return end
    SendNUIMessage({ action = 'setPlayerStatus', data = StatusClient.status })
end

local function applyState()
    plyState:set('hunger', StatusClient.status.hunger, false)
    plyState:set('thirst', StatusClient.status.thirst, false)
    plyState:set('stress', StatusClient.status.stress, false)
    pushToNui()
end

RegisterNetEvent('kt_inventory:playerStatus:init', function(status)
    if not status then return end

    StatusClient.status = {
        hunger = status.hunger or 100,
        thirst = status.thirst or 100,
        stress = status.stress or 0,
    }
    StatusClient.ready = true

    if client.uiLoaded then
        applyState()
    else
        CreateThread(function()
            repeat Wait(100) until client.uiLoaded
            applyState()
        end)
    end

    TriggerEvent('kt_inventory:playerStatus:ready', StatusClient.status)
end)

RegisterNetEvent('kt_inventory:playerStatus:updateAll', function(status)
    if not status then return end

    if status.hunger ~= nil then StatusClient.status.hunger = status.hunger end
    if status.thirst ~= nil then StatusClient.status.thirst = status.thirst end
    if status.stress ~= nil then StatusClient.status.stress = status.stress end

    applyState()
end)

RegisterNetEvent('kt_inventory:playerStatus:applyDamage', function(amount)
    local ped = cache.ped
    local hp  = GetEntityHealth(ped)

    if hp > 101 then
        SetEntityHealth(ped, hp - amount)
    end
end)

-- Consolidation des anciens événements stress:max/high/low + blur:*/heartbeat
-- en un seul event paramétré — branche tes effets ici si besoin.
RegisterNetEvent('kt_inventory:playerStatus:stressEffect', function(level)
    if level == 'high' then
        TriggerScreenblurFadeIn(300)
        SetTimeout(2000, function() TriggerScreenblurFadeOut(300) end)
    elseif level == 'max' then
        TriggerScreenblurFadeIn(200)
        ShakeGameplayCam('HAND_SHAKE', 0.4)
        SetTimeout(2500, function() TriggerScreenblurFadeOut(400) end)
    end
end)

-- Reset à la déconnexion / changement de perso (events déjà émis par union)
RegisterNetEvent('union:character:deselected', function()
    StatusClient.ready  = false
    StatusClient.status = { hunger = 100, thirst = 100, stress = 0 }
end)

exports('GetStatus', function()
    return StatusClient.status
end)

local function syncToServer()
    TriggerServerEvent('kt_inventory:playerStatus:sync', StatusClient.status)
end

-- Prédiction optimiste locale (ex: futur système "sprint augmente le stress").
-- Le serveur reste autoritaire : voir la tolérance anti-cheat côté server.lua.
exports('SetStat', function(stat, value)
    if not StatusClient.ready or StatusClient.status[stat] == nil then return end

    StatusClient.status[stat] = math.max(0, math.min(100, math.floor(value + 0.5)))
    applyState()
    syncToServer()
end)

exports('AddStat', function(stat, value)
    if not StatusClient.ready or StatusClient.status[stat] == nil then return end

    StatusClient.status[stat] = math.max(0, math.min(100, math.floor(StatusClient.status[stat] + (value or 0) + 0.5)))
    applyState()
    syncToServer()
end)

lib.print.info('^2[kt_inventory] modules/playerstatus/client module loaded^0')

return StatusClient