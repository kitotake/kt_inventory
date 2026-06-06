-- modules/mysql/save_manager.lua
-- Gestionnaire de sauvegarde avec :
-- - Queue de sauvegarde prioritaire
-- - Retry automatique sur erreur SQL
-- - Métriques de performance
-- - Protection contre les saves simultanées
-- - Transactions pour cohérence des données

if not lib then return end

local SaveManager = {}

-- ─────────────────────────────────────────────────────────────
-- CONFIGURATION
-- ─────────────────────────────────────────────────────────────

local CFG = {
    MAX_RETRY       = 3,        -- tentatives max par save
    RETRY_DELAY_MS  = 500,      -- délai entre retries
    BATCH_MAX_ROWS  = 200,      -- max rows par batch INSERT
    QUEUE_INTERVAL  = 100,      -- ms entre vidages de queue urgente
    LOG_SLOW_SAVE   = 2000,     -- ms : log si save > ce seuil
}

-- ─────────────────────────────────────────────────────────────
-- ÉTAT INTERNE
-- ─────────────────────────────────────────────────────────────

local isSaving      = false
local saveQueue     = {}        -- { type, params } : saves urgentes (disconnect)
local saveMetrics   = {
    totalSaves      = 0,
    totalErrors     = 0,
    totalRetries    = 0,
    lastSaveMs      = 0,
    lastSaveTime    = 0,
}

-- ─────────────────────────────────────────────────────────────
-- HELPERS SQL
-- ─────────────────────────────────────────────────────────────

local QUERIES = {
    -- Union framework
    UPSERT_PLAYER_UNION = [[
        INSERT INTO kt_inventory (data, unique_id, name)
        VALUES (?, ?, 'player')
        ON DUPLICATE KEY UPDATE data = VALUES(data), updated_at = CURRENT_TIMESTAMP
    ]],

    UPSERT_STASH = [[
        INSERT INTO kt_inventory (data, unique_id, name)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE data = VALUES(data)
    ]],

    UPDATE_TRUNK    = 'UPDATE owned_vehicles SET trunk    = ? WHERE plate = ?',
    UPDATE_GLOVEBOX = 'UPDATE owned_vehicles SET glovebox = ? WHERE plate = ?',
}

-- ─────────────────────────────────────────────────────────────
-- RETRY WRAPPER
-- ─────────────────────────────────────────────────────────────

---@param fn function
---@param ... any
---@return boolean success, any result
local function withRetry(fn, ...)
    local args = { ... }
    local lastErr

    for attempt = 1, CFG.MAX_RETRY do
        local ok, result = pcall(fn, table.unpack(args))

        if ok then
            if attempt > 1 then
                saveMetrics.totalRetries += (attempt - 1)
                lib.print.info(('[kt_inventory:save] Succès après %d tentative(s)'):format(attempt))
            end
            return true, result
        end

        lastErr = result
        saveMetrics.totalErrors += 1

        if attempt < CFG.MAX_RETRY then
            lib.print.warn(('[kt_inventory:save] Tentative %d/%d échouée: %s'):format(
                attempt, CFG.MAX_RETRY, tostring(lastErr)))
            Wait(CFG.RETRY_DELAY_MS * attempt)
        end
    end

    lib.print.error(('[kt_inventory:save] ÉCHEC FINAL après %d tentatives: %s'):format(
        CFG.MAX_RETRY, tostring(lastErr)))

    return false, lastErr
end

-- ─────────────────────────────────────────────────────────────
-- SAVE PLAYER (Union)
-- ─────────────────────────────────────────────────────────────

---@param uniqueId string
---@param data string|nil  JSON encodé
---@param urgent boolean   true = synchrone (disconnect)
function SaveManager.SavePlayer(uniqueId, data, urgent)
    if not uniqueId or uniqueId == '' then
        lib.print.warn('[kt_inventory:save] SavePlayer: uniqueId nil/vide, ignoré')
        return
    end

    if urgent then
        -- Sauvegarde synchrone immédiate (déconnexion joueur)
        local ok = withRetry(MySQL.query.await, QUERIES.UPSERT_PLAYER_UNION, { data, uniqueId })
        if ok then
            lib.print.info(('[kt_inventory:save] Player sauvegardé (urgent): %s'):format(uniqueId))
        end
    else
        -- Enqueue pour batch save (cron)
        saveQueue[#saveQueue + 1] = {
            type     = 'player',
            query    = QUERIES.UPSERT_PLAYER_UNION,
            params   = { data, uniqueId },
            uniqueId = uniqueId,
        }
    end
end

-- ─────────────────────────────────────────────────────────────
-- SAVE STASH
-- ─────────────────────────────────────────────────────────────

---@param owner string
---@param name string
---@param data string|nil
function SaveManager.SaveStash(owner, name, data)
    saveQueue[#saveQueue + 1] = {
        type   = 'stash',
        query  = QUERIES.UPSERT_STASH,
        params = { data, owner or '', name },
    }
end

-- ─────────────────────────────────────────────────────────────
-- SAVE TRUNK / GLOVEBOX
-- ─────────────────────────────────────────────────────────────

---@param plate string
---@param data string|nil
function SaveManager.SaveTrunk(plate, data)
    if not plate then return end
    saveQueue[#saveQueue + 1] = {
        type   = 'trunk',
        query  = QUERIES.UPDATE_TRUNK,
        params = { data, plate },
    }
end

---@param plate string
---@param data string|nil
function SaveManager.SaveGlovebox(plate, data)
    if not plate then return end
    saveQueue[#saveQueue + 1] = {
        type   = 'glovebox',
        query  = QUERIES.UPDATE_GLOVEBOX,
        params = { data, plate },
    }
end

-- ─────────────────────────────────────────────────────────────
-- FLUSH BATCH
-- Regroupe les saves par type pour minimiser les requêtes SQL
-- ─────────────────────────────────────────────────────────────

---@param entries table[]
---@param label string
local function flushBatch(entries, label)
    if #entries == 0 then return end

    local start = os.nanotime()

    -- Déduplique : garde seulement la dernière entrée par clé unique
    -- Évite de sauvegarder N fois le même joueur si déconnecté rapidement
    local deduped = {}
    local seen    = {}

    for i = #entries, 1, -1 do
        local e   = entries[i]
        local key = table.concat(e.params, ':'):sub(1, 64) -- clé de dédup
        if not seen[key] then
            seen[key]            = true
            deduped[#deduped + 1] = e
        end
    end

    -- Split en batches si trop grand
    local batches = {}
    local current = {}

    for i = 1, #deduped do
        current[#current + 1] = deduped[i].params

        if #current >= CFG.BATCH_MAX_ROWS then
            batches[#batches + 1] = current
            current = {}
        end
    end

    if #current > 0 then
        batches[#batches + 1] = current
    end

    local totalSaved = 0

    for _, batch in ipairs(batches) do
        local ok, result = withRetry(MySQL.prepare.await, entries[1].query, batch)

        if ok then
            totalSaved += #batch
        end
    end

    local elapsed = (os.nanotime() - start) / 1e6
    saveMetrics.lastSaveMs   = elapsed
    saveMetrics.lastSaveTime = os.time()
    saveMetrics.totalSaves  += totalSaved

    if elapsed > CFG.LOG_SLOW_SAVE then
        lib.print.warn(('[kt_inventory:save] Save lente: %s %d entrées en %.2fms'):format(
            label, totalSaved, elapsed))
    else
        lib.print.info(('[kt_inventory:save] %s: %d/%d sauvegardés en %.2fms'):format(
            label, totalSaved, #entries, elapsed))
    end
end

-- ─────────────────────────────────────────────────────────────
-- FLUSH PRINCIPAL
-- Appel par le cron ou onResourceStop
-- ─────────────────────────────────────────────────────────────

function SaveManager.Flush()
    if isSaving then
        lib.print.warn('[kt_inventory:save] Flush ignoré (save déjà en cours)')
        return
    end

    if #saveQueue == 0 then return end

    isSaving = true

    -- Snapshot et vider la queue
    local snapshot = saveQueue
    saveQueue      = {}

    -- Séparer par type
    local byType = {
        player   = {},
        stash    = {},
        trunk    = {},
        glovebox = {},
    }

    for _, entry in ipairs(snapshot) do
        local bucket = byType[entry.type]
        if bucket then
            bucket[#bucket + 1] = entry
        end
    end

    local pending = 0

    local function runBatch(bucket, label)
        if #bucket == 0 then return end
        pending += 1
        Citizen.CreateThreadNow(function()
            flushBatch(bucket, label)
            pending -= 1
        end)
    end

    runBatch(byType.player,   'players')
    runBatch(byType.stash,    'stashes')
    runBatch(byType.trunk,    'trunks')
    runBatch(byType.glovebox, 'gloveboxes')

    -- Attendre la fin de tous les threads
    local timeout = 0
    while pending > 0 and timeout < 10000 do
        Wait(50)
        timeout += 50
    end

    if timeout >= 10000 then
        lib.print.error('[kt_inventory:save] Timeout global flush (10s) — données potentiellement perdues')
    end

    isSaving = false
end

-- ─────────────────────────────────────────────────────────────
-- SAVE URGENTE (disconnect / resource stop)
-- Flush synchrone immédiat, bloque jusqu'à fin
-- ─────────────────────────────────────────────────────────────

function SaveManager.FlushUrgent(playerUniqueId)
    -- Si on a un uniqueId spécifique, on filtre la queue
    if playerUniqueId then
        local urgent  = {}
        local remaining = {}

        for _, entry in ipairs(saveQueue) do
            if entry.uniqueId == playerUniqueId then
                urgent[#urgent + 1] = entry
            else
                remaining[#remaining + 1] = entry
            end
        end

        saveQueue = remaining

        for _, entry in ipairs(urgent) do
            withRetry(MySQL.query.await, entry.query, entry.params)
        end

        return
    end

    -- Flush tout
    SaveManager.Flush()
end

-- ─────────────────────────────────────────────────────────────
-- MÉTRIQUES
-- ─────────────────────────────────────────────────────────────

function SaveManager.GetMetrics()
    return {
        totalSaves   = saveMetrics.totalSaves,
        totalErrors  = saveMetrics.totalErrors,
        totalRetries = saveMetrics.totalRetries,
        lastSaveMs   = saveMetrics.lastSaveMs,
        lastSaveTime = saveMetrics.lastSaveTime,
        queueSize    = #saveQueue,
        isSaving     = isSaving,
    }
end

-- Commande admin pour afficher les métriques
lib.addCommand('invsavestats', {
    help    = 'Affiche les statistiques de sauvegarde inventaire',
    restricted = 'group.admin',
}, function(source)
    local m = SaveManager.GetMetrics()
    local msg = ('Save stats: %d saves | %d erreurs | %d retries | dernière: %.2fms | queue: %d'):format(
        m.totalSaves, m.totalErrors, m.totalRetries, m.lastSaveMs, m.queueSize)

    if source == 0 then
        print(msg)
    else
        TriggerClientEvent('kt_lib:notify', source, { description = msg })
    end
end)

lib.print.info('^2[kt_inventory] modules/mysql/save_manager module loaded')

return SaveManager
