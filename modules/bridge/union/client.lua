-- modules/bridge/union/client.lua
-- Bridge entre kt_inventory et Union Framework (côté client)

-- ────────────────────────────────────────────────────────────────────────────
-- Logout : réinitialise kt_inventory quand le personnage est déselectionné
-- ────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('union:character:deselected', client.onLogout)

-- Sécurité : si la sélection échoue, on reset aussi
RegisterNetEvent('union:character:selected', function(success, character)
    if not success then
        client.onLogout()
    end
end)

-- ────────────────────────────────────────────────────────────────────────────
-- Mise à jour des groupes en live (changement de job, grade, etc.)
-- ────────────────────────────────────────────────────────────────────────────
RegisterNetEvent('union:job:updated', function(job, grade)
    if not PlayerData.groups then PlayerData.groups = {} end
    PlayerData.groups[job] = grade
    OnPlayerData('groups', PlayerData.groups)
end)

-- ────────────────────────────────────────────────────────────────────────────
-- setPlayerData : stocke les données dans PlayerData (standard kt_inventory)
-- ────────────────────────────────────────────────────────────────────────────
---@diagnostic disable-next-line: duplicate-set-field
function client.setPlayerData(key, value)
    PlayerData[key] = value
    OnPlayerData(key, value)
end

-- ────────────────────────────────────────────────────────────────────────────
-- setPlayerStatus : hunger/thirst via LocalPlayer.state (même que QBX)
-- ────────────────────────────────────────────────────────────────────────────
---@diagnostic disable-next-line: duplicate-set-field
function client.setPlayerStatus(values)
    local playerState = LocalPlayer.state
    for name, value in pairs(values) do
        -- Compatibilité ESX (valeurs en millionièmes → ramenées à 0-100)
        if value > 100 or value < -100 then
            value = value * 0.0001
        end
        local current = playerState[name] or 0
        playerState:set(name, current + value, true)
    end
end

-- ────────────────────────────────────────────────────────────────────────────
-- hasGroup : vérifie si le joueur appartient à un groupe/job requis
-- ────────────────────────────────────────────────────────────────────────────
---@diagnostic disable-next-line: duplicate-set-field
function client.hasGroup(group)
    if not PlayerData.loaded then return end

    if type(group) == 'table' then
        for name, rank in pairs(group) do
            local groupRank = PlayerData.groups and PlayerData.groups[name]
            if groupRank and groupRank >= (rank or 0) then
                return name, groupRank
            end
        end
    else
        local groupRank = PlayerData.groups and PlayerData.groups[group]
        if groupRank then
            return group, groupRank
        end
    end
end