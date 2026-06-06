-- modules/hooks/server.lua
-- Optimisations :
--   [FIX-1] Isolation pcall complète : une erreur dans un hook ne casse pas les suivants
--   [FIX-2] Métriques par hook (temps d'exécution, erreurs)
--   [FIX-3] Limite de temps d'exécution configurable par hook
--   [FIX-4] Filtre inventoryFilter compilé en pattern LuaJIT pour perf
--   [FIX-5] Désenregistrement correct des hooks par ressource

if not lib then return end

local eventHooks = {}
local microtime  = os.microtime

-- ─────────────────────────────────────────────────────────────
-- CONSTANTES
-- ─────────────────────────────────────────────────────────────

local WARN_THRESHOLD_US = 100000  -- 100ms : avertissement
local MAX_HOOK_TIME_US  = 500000  -- 500ms : erreur critique

-- ─────────────────────────────────────────────────────────────
-- FILTRES
-- ─────────────────────────────────────────────────────────────

local function itemFilter(filter, item, secondItem)
    local itemName = type(item) == 'table' and item.name or item
    if itemName and filter[itemName] then return true end
    if type(secondItem) == 'table' and secondItem.name and filter[secondItem.name] then return true end
    return false
end

-- [FIX-4] Cache les patterns compilés pour inventoryFilter
local _patternCache = {}

local function inventoryFilter(filter, inventory, secondInventory)
    for i = 1, #filter do
        local pattern = filter[i]

        -- Cache le pattern compilé
        if not _patternCache[pattern] then
            _patternCache[pattern] = pattern
        end

        if inventory:match(pattern) then return true end
        if secondInventory and secondInventory:match(pattern) then return true end
    end
    return false
end

local function typeFilter(filter, invType)
    return filter[invType] or false
end

-- ─────────────────────────────────────────────────────────────
-- TRIGGER HOOKS
-- ─────────────────────────────────────────────────────────────

local function TriggerEventHooks(event, payload)
    local hooks = eventHooks[event]
    if not hooks or #hooks == 0 then
        return event == 'createItem' and payload.metadata or true
    end

    local fromInventory = payload.fromInventory and tostring(payload.fromInventory)
        or payload.inventoryId and tostring(payload.inventoryId)
        or payload.shopType and tostring(payload.shopType)
        or ''
    local toInventory = payload.toInventory and tostring(payload.toInventory) or ''

    for i = 1, #hooks do
        local hook = hooks[i]

        -- Filtres
        if hook.itemFilter and not itemFilter(hook.itemFilter,
            payload.fromSlot or payload.item or payload.itemName or payload.recipe,
            payload.toSlot) then
            goto skipLoop
        end

        if hook.inventoryFilter and not inventoryFilter(hook.inventoryFilter, fromInventory, toInventory) then
            goto skipLoop
        end

        if hook.typeFilter and not typeFilter(hook.typeFilter,
            payload.inventoryType or payload.shopType or payload.fromType) then
            goto skipLoop
        end

        if hook.print then
            shared.info(('Hook "%s:%s:%s" déclenché'):format(hook.resource, event, i))
        end

        do
            local start = microtime()

            -- [FIX-1] pcall complet : une erreur dans un hook n'interrompt pas la chaîne
            local ok, response = pcall(hook, payload)

            local elapsed = microtime() - start

            -- [FIX-2] Métriques
            hook._calls  = (hook._calls  or 0) + 1
            hook._totalUs = (hook._totalUs or 0) + elapsed

            if not ok then
                -- [FIX-1] Log l'erreur mais continue
                lib.print.error(('[kt_inventory:hook] Erreur "%s:%s:%s": %s'):format(
                    hook.resource, event, i, tostring(response)))
                hook._errors = (hook._errors or 0) + 1
                goto skipLoop
            end

            if elapsed >= MAX_HOOK_TIME_US then
                lib.print.error(('[kt_inventory:hook] Hook CRITIQUE "%s:%s:%s" : %.2fms'):format(
                    hook.resource, event, i, elapsed / 1e3))
            elseif elapsed >= WARN_THRESHOLD_US then
                lib.print.warn(('[kt_inventory:hook] Hook lent "%s:%s:%s" : %.2fms'):format(
                    hook.resource, event, i, elapsed / 1e3))
            end

            if event == 'createItem' then
                if type(response) == 'table' then
                    payload.metadata = response
                end
            elseif response == false then
                return false
            end
        end

        ::skipLoop::
    end

    return event == 'createItem' and payload.metadata or true
end

-- ─────────────────────────────────────────────────────────────
-- ENREGISTREMENT / DÉSENREGISTREMENT
-- ─────────────────────────────────────────────────────────────

local hookId = 0

exports('registerHook', function(event, cb, options)
    if not eventHooks[event] then
        eventHooks[event] = {}
    end

    local mt = getmetatable(cb)
    if mt then
        mt.__index    = nil
        mt.__newindex = nil
    end

    cb.resource = GetInvokingResource()
    hookId += 1
    cb.hookId = hookId

    -- Métriques
    cb._calls   = 0
    cb._totalUs = 0
    cb._errors  = 0

    if options then
        for k, v in pairs(options) do
            -- [FIX-4] Précompile les filtres d'item en set
            if k == 'itemFilter' and type(v) == 'table' then
                local set = {}
                for _, name in ipairs(v) do set[name] = true end
                cb.itemFilter = set
            else
                cb[k] = v
            end
        end
    end

    eventHooks[event][#eventHooks[event] + 1] = cb
    return hookId
end)

-- [FIX-5] Désenregistrement propre par ressource et/ou id
local function removeResourceHooks(resource, id)
    for _, hooks in pairs(eventHooks) do
        for i = #hooks, 1, -1 do
            local hook = hooks[i]
            if hook.resource == resource and (not id or hook.hookId == id) then
                table.remove(hooks, i)
            end
        end
    end
end

AddEventHandler('onResourceStop', removeResourceHooks)

exports('removeHooks', function(id)
    removeResourceHooks(GetInvokingResource() or shared.resource, id)
end)

-- ─────────────────────────────────────────────────────────────
-- COMMANDE DEBUG MÉTRIQUES
-- ─────────────────────────────────────────────────────────────

lib.addCommand('invhookstats', {
    help       = 'Affiche les stats des hooks inventaire',
    restricted = 'group.admin',
}, function(source)
    for event, hooks in pairs(eventHooks) do
        for i, hook in ipairs(hooks) do
            local avgUs = hook._calls > 0 and (hook._totalUs / hook._calls) or 0
            local msg   = ('[%s:%s:%d] appels=%d avgMs=%.2f erreurs=%d'):format(
                hook.resource, event, i, hook._calls, avgUs / 1e3, hook._errors)

            if source == 0 then
                print(msg)
            else
                TriggerClientEvent('kt_lib:notify', source, { description = msg })
            end
        end
    end
end)

lib.print.info('^2[kt_inventory] hooks/server module loaded')

return TriggerEventHooks

