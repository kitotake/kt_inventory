-- modules/bridge/union/client.lua
-- Bridge client Union Framework ↔ kt_inventory

-- Logout quand Union décharge le personnage
RegisterNetEvent("union:character:deselected", client.onLogout)

-- Si le joueur change de personnage (reconnexion / sélection)
RegisterNetEvent("union:character:selected", function(success, character)
    if not success then
        client.onLogout()
    end
end)

-- Mise à jour des groupes en live (job change, etc.)
RegisterNetEvent("union:job:updated", function(job, grade)
    if not PlayerData.groups then PlayerData.groups = {} end
    PlayerData.groups[job] = grade
    OnPlayerData("groups", PlayerData.groups)
end)

-- ──────────────────────────────────────────────
-- setPlayerData : stocke les données dans PlayerData
-- ──────────────────────────────────────────────
---@diagnostic disable-next-line: duplicate-set-field
function client.setPlayerData(key, value)
    PlayerData[key] = value
    OnPlayerData(key, value)
end

-- ──────────────────────────────────────────────
-- Status players (hunger / thirst)
-- Union utilise LocalPlayer.state comme QBX
-- ──────────────────────────────────────────────
---@diagnostic disable-next-line: duplicate-set-field
function client.setPlayerStatus(values)
    local playerState = LocalPlayer.state
    for name, value in pairs(values) do
        -- Compatibilité ESX (valeurs en millionièmes)
        if value > 100 or value < -100 then
            value = value * 0.0001
        end
        -- Union utilise des statebags
        local current = playerState[name] or 0
        playerState:set(name, current + value, true)
    end
end