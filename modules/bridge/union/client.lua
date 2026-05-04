-- modules/bridge/union/client.lua
-- Bridge kt_inventory <-> Union Framework (CLIENT)

-- ────────────────────────────────────────────────────────────
-- LOGOUT / RESET
-- ────────────────────────────────────────────────────────────

RegisterNetEvent('union:character:deselected', client.onLogout)

RegisterNetEvent('union:character:selected', function(success)
    if not success then
        client.onLogout()
    end
end)

-- ────────────────────────────────────────────────────────────
-- GROUPES
-- ────────────────────────────────────────────────────────────

RegisterNetEvent('union:job:updated', function(job, grade)
    if not PlayerData.groups then PlayerData.groups = {} end
    PlayerData.groups[job] = grade
    OnPlayerData('groups', PlayerData.groups)
end)

-- ────────────────────────────────────────────────────────────
-- PLAYER DATA
-- FIX: Suppression de la redefinition de client.setPlayerData
-- La version dans modules/bridge/client.lua est identique et suffit.
-- Redefinir ici causait une double ecriture sans valeur ajoutee.
-- ────────────────────────────────────────────────────────────

-- ────────────────────────────────────────────────────────────
-- STATUS
-- ────────────────────────────────────────────────────────────

---@diagnostic disable-next-line: duplicate-set-field
function client.setPlayerStatus(values)
    local state = LocalPlayer.state

    for k, v in pairs(values) do
        if type(v) == "number" then
            state:set(k, v, true)
        end
    end
end

RegisterNetEvent("union:status:init", function(s)
    client.setPlayerStatus(s)
end)

RegisterNetEvent("union:status:updateAll", function(s)
    client.setPlayerStatus(s)
end)


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
