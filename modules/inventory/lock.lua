-- modules/inventory/lock.lua
-- Système de locking atomique avec timeout automatique
-- Remplace activeSlots (string-based, sans timeout)
-- Objectif : zéro deadlock, zéro race condition, zéro duplication

if not lib then return end

local Lock = {}

-- Table des verrous actifs : clé → { time, source }
local activeLocks = {}

-- Timeout en ms avant qu'un verrou soit considéré mort
local LOCK_TIMEOUT_MS = 5000

-- Nettoie les verrous expirés
local function purgeStaleLocks()
    local now = GetGameTimer()
    for k, v in pairs(activeLocks) do
        if (now - v.time) > LOCK_TIMEOUT_MS then
            lib.print.warn(('[kt_inventory:lock] Verrou expiré forcé: %s (source=%s, age=%dms)'):format(
                k, tostring(v.source), now - v.time))
            activeLocks[k] = nil
        end
    end
end

-- Vérifie si un verrou est actif (en ignorant les verrous expirés)
---@param key string
---@return boolean
function Lock.IsLocked(key)
    local lock = activeLocks[key]
    if not lock then return false end

    if (GetGameTimer() - lock.time) > LOCK_TIMEOUT_MS then
        activeLocks[key] = nil
        lib.print.warn(('[kt_inventory:lock] Verrou expiré auto-supprimé: %s'):format(key))
        return false
    end

    return true
end

-- Tente d'acquérir deux verrous atomiquement (fromRef + toRef)
-- Retourne false si l'un des deux est déjà verrouillé
---@param keyA string
---@param keyB string
---@param source number
---@return boolean acquired
function Lock.AcquirePair(keyA, keyB, source)
    purgeStaleLocks()

    if Lock.IsLocked(keyA) or Lock.IsLocked(keyB) then
        return false
    end

    local now = GetGameTimer()
    activeLocks[keyA] = { time = now, source = source }
    activeLocks[keyB] = { time = now, source = source }
    return true
end

-- Acquiert un seul verrou
---@param key string
---@param source number
---@return boolean
function Lock.Acquire(key, source)
    purgeStaleLocks()
    if Lock.IsLocked(key) then return false end
    activeLocks[key] = { time = GetGameTimer(), source = source }
    return true
end

-- Libère un verrou
---@param key string
function Lock.Release(key)
    activeLocks[key] = nil
end

-- Libère une paire de verrous
---@param keyA string
---@param keyB string
function Lock.ReleasePair(keyA, keyB)
    activeLocks[keyA] = nil
    activeLocks[keyB] = nil
end

-- Objet defer-compatible pour usage avec <close>
---@param keyA string
---@param keyB? string
---@return table
function Lock.Defer(keyA, keyB)
    return setmetatable({}, {
        __close = function()
            Lock.Release(keyA)
            if keyB then Lock.Release(keyB) end
        end
    })
end

-- Statistiques de debug
function Lock.Stats()
    local count = 0
    for _ in pairs(activeLocks) do count += 1 end
    return count
end

return Lock
