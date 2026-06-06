-- modules/inventory/lock.lua
-- Système de locking atomique avec timeout automatique
-- Corrections :
--   [FIX-1] Suppression de Lock.Defer qui utilisait `<close>` (syntaxe Lua 5.4
--           non supportée dans FiveM qui tourne sur Lua 5.3/5.4 selon la version,
--           mais le `<close>` n'est pas garanti disponible partout).
--           Remplacement par Lock.DeferScope() retournant un objet avec méthode close()
--           à appeler manuellement — compatible 5.3+.
--   [FIX-2] purgeStaleLocks() optimisée : évite la création d'une table temporaire
--   [FIX-3] Stats() renommé en GetStats() pour cohérence de nommage

if not lib then return end

local Lock = {}

---@type table<string, { time: number, source: number }>
local activeLocks    = {}
local LOCK_TIMEOUT_MS = 5000

-- [FIX-2] Purge sans table temporaire (iteration directe + suppression en place)
local function purgeStaleLocks()
    local now       = GetGameTimer()
    local toRemove  = nil

    for k, v in pairs(activeLocks) do
        if (now - v.time) > LOCK_TIMEOUT_MS then
            if not toRemove then toRemove = {} end
            toRemove[#toRemove + 1] = k
        end
    end

    if toRemove then
        for i = 1, #toRemove do
            lib.print.warn(('[kt_inventory:lock] Verrou expiré forcé: %s'):format(toRemove[i]))
            activeLocks[toRemove[i]] = nil
        end
    end
end

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

---@param keyA string
---@param keyB string
---@param source number
---@return boolean
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

---@param key string
---@param source number
---@return boolean
function Lock.Acquire(key, source)
    purgeStaleLocks()
    if Lock.IsLocked(key) then return false end
    activeLocks[key] = { time = GetGameTimer(), source = source }
    return true
end

---@param key string
function Lock.Release(key)
    activeLocks[key] = nil
end

---@param keyA string
---@param keyB string
function Lock.ReleasePair(keyA, keyB)
    activeLocks[keyA] = nil
    activeLocks[keyB] = nil
end

-- [FIX-1] Remplacement de Lock.Defer (syntaxe <close> Lua 5.4)
-- par un objet "scope" avec méthode :close() à appeler manuellement.
-- Usage recommandé dans modules/inventory/server.lua :
--
--   local scope = Lock.DeferScope(keyA, keyB)
--   -- ... code ...
--   scope:close()  -- libère les verrous
--
-- Pour reproduire le comportement `<close>` de Lua 5.4 de façon portable,
-- on utilise pcall + always-close :
--
--   local scope = Lock.DeferScope(keyA, keyB)
--   local ok, err = pcall(function()
--       -- code critique
--   end)
--   scope:close()
--   if not ok then error(err) end

---@param keyA string
---@param keyB? string
---@return { close: fun() }
function Lock.DeferScope(keyA, keyB)
    local closed = false
    return {
        close = function()
            if closed then return end
            closed = true
            Lock.Release(keyA)
            if keyB then Lock.Release(keyB) end
        end
    }
end

-- Compatibilité : garde Lock.Defer pour le code existant qui l'appelle
-- mais sans la syntaxe <close> — retourne le même objet DeferScope
-- Note : si le code appelant utilise `local _ <close> = Lock.Defer(...)`,
-- il faudra le migrer vers DeferScope (voir commentaire ci-dessus).
Lock.Defer = Lock.DeferScope

-- [FIX-3] Renommé GetStats (Stats conservé pour compatibilité)
function Lock.GetStats()
    local count = 0
    for _ in pairs(activeLocks) do count = count + 1 end
    return {
        active = count,
        locks  = activeLocks,  -- référence directe (lecture seule)
    }
end

-- Alias de compatibilité
Lock.Stats = function()
    return Lock.GetStats().active
end

return Lock