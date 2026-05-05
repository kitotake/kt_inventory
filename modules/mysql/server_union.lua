-- modules/mysql/server_union.lua
-- FIX #1 : UPSERT_PLAYER — ordre des paramètres corrigé.
--           La requête VALUES(?, ?, 'player') attend (data, unique_id).
--           db.savePlayer(uniqueId, data) passe { data, uniqueId } → correct.
-- FIX #2 : db.loadPlayer loggue clairement les cas d'erreur.
-- FIX #3 : saveInventories — cohérence avec les paramètres de prepareInventorySave.

if not lib then return end

local Query = {
    SELECT_STASH  = "SELECT data FROM kt_inventory WHERE unique_id = ? AND name = ?",
    UPSERT_STASH  = "INSERT INTO kt_inventory (data, unique_id, name) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)",

    SELECT_GLOVEBOX = "SELECT plate, glovebox FROM owned_vehicles WHERE plate = ?",
    SELECT_TRUNK    = "SELECT plate, trunk    FROM owned_vehicles WHERE plate = ?",
    UPDATE_TRUNK    = "UPDATE owned_vehicles SET trunk    = ? WHERE plate = ?",
    UPDATE_GLOVEBOX = "UPDATE owned_vehicles SET glovebox = ? WHERE plate = ?",

    -- FIX #1 : (data, unique_id) → VALUES(?, ?, 'player')
    -- Paramètres attendus : { data, unique_id }
    UPSERT_PLAYER = "INSERT INTO kt_inventory (data, unique_id, name) VALUES (?, ?, 'player') ON DUPLICATE KEY UPDATE data = VALUES(data)",
}

-- ─────────────────────────────────────────────
-- Initialisation DB
-- ─────────────────────────────────────────────
Citizen.CreateThreadNow(function()
    Wait(0)

    local ok = pcall(MySQL.scalar.await, "SELECT 1 FROM kt_inventory LIMIT 1")
    if not ok then
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `kt_inventory` (
                `id`         INT AUTO_INCREMENT PRIMARY KEY,
                `unique_id`  VARCHAR(32)  NOT NULL,
                `name`       VARCHAR(100) NOT NULL DEFAULT 'player',
                `data`       LONGTEXT     DEFAULT NULL,
                `created_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
                `updated_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY `uniq_inventory` (`unique_id`, `name`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
        lib.print.info("[kt_inventory:union] Table kt_inventory créée.")
    end

    local cols = MySQL.query.await("SHOW COLUMNS FROM owned_vehicles") or {}
    local hasTrunk, hasGlovebox = false, false
    for _, col in ipairs(cols) do
        if col.Field == "trunk"    then hasTrunk    = true end
        if col.Field == "glovebox" then hasGlovebox = true end
    end
    if not hasTrunk    then MySQL.query("ALTER TABLE owned_vehicles ADD COLUMN trunk    LONGTEXT NULL") end
    if not hasGlovebox then MySQL.query("ALTER TABLE owned_vehicles ADD COLUMN glovebox LONGTEXT NULL") end

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

-- FIX #2 : logs clairs
function db.loadPlayer(uniqueId)
    if not uniqueId then
        lib.print.warn("[kt_inventory:union] loadPlayer: uniqueId nil")
        return nil
    end

    lib.print.info(("[kt_inventory:union] Chargement inventaire unique_id=%s"):format(tostring(uniqueId)))

    local result = MySQL.scalar.await(
        "SELECT data FROM kt_inventory WHERE unique_id = ? AND name = 'player'",
        { uniqueId }
    )

    if result then
        local decoded = json.decode(result)
        local count   = decoded and #decoded or 0
        lib.print.info(("[kt_inventory:union] Inventaire trouvé uid=%s (%d slots)"):format(tostring(uniqueId), count))
        return decoded
    end

    lib.print.info(("[kt_inventory:union] Pas d'inventaire pour uid=%s → vide"):format(tostring(uniqueId)))
    return nil
end

-- FIX #1 : paramètres dans l'ordre (data, uniqueId) pour UPSERT_PLAYER (?, ?, 'player')
function db.savePlayer(uniqueId, data)
    if not uniqueId then
        lib.print.warn("[kt_inventory:union] savePlayer: uniqueId nil, annulé")
        return
    end
    lib.print.info(("[kt_inventory:union] Sauvegarde inventaire uid=%s"):format(tostring(uniqueId)))
    -- FIX #1 : { data, uniqueId } correspond à VALUES(?, ?, 'player')
    return MySQL.query(Query.UPSERT_PLAYER, { data, uniqueId })
end

function db.loadStash(owner, name)
    return MySQL.scalar.await(Query.SELECT_STASH, { owner or "", name })
end

function db.saveStash(owner, name, data)
    return MySQL.query(Query.UPSERT_STASH, { data, owner or "", name })
end

function db.loadGlovebox(plate)
    if not plate then return nil end
    return MySQL.prepare.await(Query.SELECT_GLOVEBOX, { plate })
end

function db.saveGlovebox(plate, data)
    if not plate then return end
    return MySQL.prepare(Query.UPDATE_GLOVEBOX, { data, plate })
end

function db.loadTrunk(plate)
    if not plate then return nil end
    return MySQL.prepare.await(Query.SELECT_TRUNK, { plate })
end

function db.saveTrunk(plate, data)
    if not plate then return end
    return MySQL.prepare(Query.UPDATE_TRUNK, { data, plate })
end

local function safeQuery(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then
        print("[kt_inventory:union] Erreur sauvegarde : " .. tostring(res))
        return nil
    end
    return res
end

-- FIX #3 : saveInventories — players contient { data, owner } (index 1 de prepareInventorySave)
-- UPSERT_PLAYER attend { data, unique_id } → order correct
function db.saveInventories(players, trunks, gloveboxes, stashes, total)
    local pending = 0
    local start   = os.nanotime()

    local function done(label, count)
        lib.print.info(("[kt_inventory:union] Sauvegardé %d %s (%.2fms)"):format(
            count, label, (os.nanotime() - start) / 1e6))
    end

    if total[1] > 0 then
        pending += 1
        Citizen.CreateThreadNow(function()
            -- players = tableau de { data, owner } construit par prepareInventorySave
            -- UPSERT_PLAYER attend { data, unique_id } → déjà dans le bon ordre
            safeQuery(MySQL.prepare.await, Query.UPSERT_PLAYER, players)
            pending -= 1
            done("players", total[1])
        end)
    end

    if total[2] > 0 then
        pending += 1
        Citizen.CreateThreadNow(function()
            safeQuery(MySQL.prepare.await, Query.UPDATE_TRUNK, trunks)
            pending -= 1
            done("trunks", total[2])
        end)
    end

    if total[3] > 0 then
        pending += 1
        Citizen.CreateThreadNow(function()
            safeQuery(MySQL.prepare.await, Query.UPDATE_GLOVEBOX, gloveboxes)
            pending -= 1
            done("gloveboxes", total[3])
        end)
    end

    if total[4] > 0 then
        pending += 1
        Citizen.CreateThreadNow(function()
            if server.bulkstashsave then
                local n     = total[4] / 3
                local query = Query.UPSERT_STASH:gsub("%(%?, %?, %?%)",
                    string.rep("(?, ?, ?)", n, ", "))
                safeQuery(MySQL.query.await, query, stashes)
            else
                safeQuery(MySQL.prepare.await, Query.UPSERT_STASH, stashes)
            end
            pending -= 1
            done("stashes", total[4])
        end)
    end

    repeat Wait(0) until pending == 0
end

return db
