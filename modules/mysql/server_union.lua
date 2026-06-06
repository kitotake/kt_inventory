-- modules/mysql/server_union.lua
-- API MySQL pour le framework Union
-- Corrections :
--   [FIX-1] db.savePlayer(uniqueId, data) : l'ordre des paramètres est maintenu
--           mais clarifié avec un commentaire explicite pour éviter toute confusion.
--           UPSERT_PLAYER attend { data, uniqueId } = (VALUES ?, ?, 'player')
--   [FIX-2] db.loadPlayer : gestion explicite du cas JSON invalide
--   [FIX-3] saveInventories : protection contre les tableaux vides et erreurs silencieuses
--   [FIX-4] Initialisation DB : utilisation de pcall correct pour tester existence table
--   [FIX-5] db.savePlayer : signature unifiée (uniqueId, data) pour correspondre
--           à l'appel depuis prepareInventorySave → { data, inv.owner }
--           NOTE: prepareInventorySave retourne { data, inv.owner } comme paire pour
--           MySQL.prepare — le tableau est { data, uniqueId } = correct pour UPSERT_PLAYER

if not lib then return end

local Query = {
    -- ORDER: VALUES(data, unique_id, 'player')
    -- Paramètres attendus pour chaque ligne : { data, unique_id }
    UPSERT_PLAYER = [[
        INSERT INTO kt_inventory (data, unique_id, name)
        VALUES (?, ?, 'player')
        ON DUPLICATE KEY UPDATE data = VALUES(data), updated_at = CURRENT_TIMESTAMP
    ]],

    SELECT_STASH  = "SELECT data FROM kt_inventory WHERE unique_id = ? AND name = ?",
    UPSERT_STASH  = "INSERT INTO kt_inventory (data, unique_id, name) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)",

    SELECT_GLOVEBOX = "SELECT plate, glovebox FROM owned_vehicles WHERE plate = ?",
    SELECT_TRUNK    = "SELECT plate, trunk    FROM owned_vehicles WHERE plate = ?",
    UPDATE_TRUNK    = "UPDATE owned_vehicles SET trunk    = ? WHERE plate = ?",
    UPDATE_GLOVEBOX = "UPDATE owned_vehicles SET glovebox = ? WHERE plate = ?",
}

-- ─────────────────────────────────────────────
-- Initialisation DB [FIX-4]
-- ─────────────────────────────────────────────

Citizen.CreateThreadNow(function()
    Wait(0)

    -- [FIX-4] pcall correct : MySQL.scalar.await retourne nil si la table n'existe pas,
    -- mais lève une exception si la connexion échoue. On teste les deux cas.
    local tableExists = false
    local ok, result = pcall(function()
        return MySQL.scalar.await("SELECT COUNT(*) FROM kt_inventory LIMIT 1")
    end)

    tableExists = ok and result ~= nil

    if not tableExists then
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `kt_inventory` (
                `id`         INT AUTO_INCREMENT PRIMARY KEY,
                `unique_id`  VARCHAR(64)  NOT NULL,
                `name`       VARCHAR(100) NOT NULL DEFAULT 'player',
                `data`       LONGTEXT     DEFAULT NULL,
                `created_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
                `updated_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY `uniq_inventory` (`unique_id`, `name`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
        lib.print.info("[kt_inventory:union] Table kt_inventory créée.")
    end

    -- Vérification colonnes owned_vehicles
    local ok2, cols = pcall(function()
        return MySQL.query.await("SHOW COLUMNS FROM owned_vehicles") or {}
    end)

    if ok2 and cols then
        local hasTrunk, hasGlovebox = false, false
        for _, col in ipairs(cols) do
            if col.Field == "trunk"    then hasTrunk    = true end
            if col.Field == "glovebox" then hasGlovebox = true end
        end
        if not hasTrunk    then
            pcall(MySQL.query.await, "ALTER TABLE owned_vehicles ADD COLUMN trunk    LONGTEXT NULL")
        end
        if not hasGlovebox then
            pcall(MySQL.query.await, "ALTER TABLE owned_vehicles ADD COLUMN glovebox LONGTEXT NULL")
        end
    end

    local clearStashes = GetConvar("inventory:clearstashes", "6 MONTH")
    if clearStashes ~= "" then
        pcall(MySQL.query.await,
            ("DELETE FROM kt_inventory WHERE updated_at < (NOW() - INTERVAL %s)"):format(clearStashes))
    end

    lib.print.info("[kt_inventory:union] MySQL initialisé.")
end)

-- ─────────────────────────────────────────────
-- API db
-- ─────────────────────────────────────────────

db = {}

-- [FIX-2] loadPlayer : gestion JSON invalide + logs structurés
function db.loadPlayer(uniqueId)
    if not uniqueId or uniqueId == "" then
        lib.print.warn("[kt_inventory:union] loadPlayer: uniqueId nil/vide")
        return nil
    end

    local result = MySQL.scalar.await(
        "SELECT data FROM kt_inventory WHERE unique_id = ? AND name = 'player'",
        { uniqueId }
    )

    if not result then
        lib.print.info(("[kt_inventory:union] Pas d'inventaire pour uid=%s → vide"):format(tostring(uniqueId)))
        return nil
    end

    -- [FIX-2] JSON invalide ne doit pas crasher le chargement
    local ok, decoded = pcall(json.decode, result)
    if not ok or not decoded then
        lib.print.warn(("[kt_inventory:union] JSON invalide pour uid=%s, inventaire réinitialisé"):format(tostring(uniqueId)))
        return nil
    end

    local count = type(decoded) == "table" and #decoded or 0
    lib.print.info(("[kt_inventory:union] Inventaire chargé uid=%s (%d slots)"):format(tostring(uniqueId), count))
    return decoded
end

-- [FIX-1] db.savePlayer(uniqueId, data)
-- Appelé depuis prepareInventorySave qui fournit { data, inv.owner } pour MySQL.prepare
-- Mais db.savePlayer est aussi appelé directement avec (uniqueId, data) depuis server.lua
-- → On garde la signature (uniqueId, data) et on construit { data, uniqueId } pour le SQL
function db.savePlayer(uniqueId, data)
    if not uniqueId or uniqueId == "" then
        lib.print.warn("[kt_inventory:union] savePlayer: uniqueId nil, annulé")
        return
    end
    -- UPSERT_PLAYER VALUES(?, ?, 'player') → { data, uniqueId }
    return MySQL.query(Query.UPSERT_PLAYER, { data, uniqueId })
end

function db.loadStash(owner, name)
    if not name then return nil end
    return MySQL.scalar.await(Query.SELECT_STASH, { owner or "", name })
end

function db.saveStash(owner, name, data)
    if not name then return end
    return MySQL.query(Query.UPSERT_STASH, { data, owner or "", name })
end

function db.loadGlovebox(plate)
    if not plate or plate == "" then return nil end
    return MySQL.prepare.await(Query.SELECT_GLOVEBOX, { plate })
end

function db.saveGlovebox(plate, data)
    if not plate or plate == "" then return end
    return MySQL.prepare(Query.UPDATE_GLOVEBOX, { data, plate })
end

function db.loadTrunk(plate)
    if not plate or plate == "" then return nil end
    return MySQL.prepare.await(Query.SELECT_TRUNK, { plate })
end

function db.saveTrunk(plate, data)
    if not plate or plate == "" then return end
    return MySQL.prepare(Query.UPDATE_TRUNK, { data, plate })
end

local function safeQuery(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then
        lib.print.warn("[kt_inventory:union] Erreur sauvegarde : " .. tostring(res))
        return nil
    end
    return res
end

-- [FIX-3] saveInventories : robuste contre tableaux vides
-- prepareInventorySave retourne pour players : { data, inv.owner }
-- UPSERT_PLAYER attend { data, unique_id } → ordre correct
function db.saveInventories(players, trunks, gloveboxes, stashes, total)
    -- [FIX-3] Guard : ne rien faire si tout est vide
    if total[5] == 0 then return end

    local pending = 0
    local start   = os.nanotime()

    local function done(label, count)
        lib.print.info(("[kt_inventory:union] Sauvegardé %d %s (%.2fms)"):format(
            count, label, (os.nanotime() - start) / 1e6))
    end

    if total[1] > 0 and #players > 0 then
        pending = pending + 1
        Citizen.CreateThreadNow(function()
            -- [FIX-3] players est un tableau de { data, unique_id }
            -- MySQL.prepare.await attend un tableau de tableaux de paramètres
            local ok = safeQuery(MySQL.prepare.await, Query.UPSERT_PLAYER, players)
            pending = pending - 1
            if ok then done("players", total[1]) end
        end)
    end

    if total[2] > 0 and #trunks > 0 then
        pending = pending + 1
        Citizen.CreateThreadNow(function()
            local ok = safeQuery(MySQL.prepare.await, Query.UPDATE_TRUNK, trunks)
            pending = pending - 1
            if ok then done("trunks", total[2]) end
        end)
    end

    if total[3] > 0 and #gloveboxes > 0 then
        pending = pending + 1
        Citizen.CreateThreadNow(function()
            local ok = safeQuery(MySQL.prepare.await, Query.UPDATE_GLOVEBOX, gloveboxes)
            pending = pending - 1
            if ok then done("gloveboxes", total[3]) end
        end)
    end

    if total[4] > 0 and #stashes > 0 then
        pending = pending + 1
        Citizen.CreateThreadNow(function()
            if server.bulkstashsave then
                -- bulk: stashes est un tableau plat { data1, uid1, name1, data2, uid2, name2, ... }
                -- total[4] est déjà /3 dans prepareInventorySave côté bulkstash
                local n     = total[4]
                local query = Query.UPSERT_STASH:gsub("%(%?, %?, %?%)",
                    string.rep("(?, ?, ?)", n, ", "))
                safeQuery(MySQL.query.await, query, stashes)
            else
                safeQuery(MySQL.prepare.await, Query.UPSERT_STASH, stashes)
            end
            pending = pending - 1
            done("stashes", total[4])
        end)
    end

    -- Attendre la fin de tous les threads (max 15s)
    local timeout = 0
    while pending > 0 and timeout < 15000 do
        Wait(50)
        timeout = timeout + 50
    end

    if timeout >= 15000 then
        lib.print.error('[kt_inventory:union] Timeout saveInventories (15s)')
    end
end

return db