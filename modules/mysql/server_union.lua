-- ============================================
-- kt_inventory - MySQL (Union Framework READY)
-- Utilise unique_id (personnage)
-- ============================================

if not lib then return end

-- ─────────────────────────────────────────────
-- QUERIES
-- ─────────────────────────────────────────────

local Query = {
    -- ── Stashes ─────────────────────────────
    SELECT_STASH = 'SELECT data FROM kt_inventory WHERE unique_id = ? AND name = ?',
    UPSERT_STASH = 'INSERT INTO kt_inventory (data, unique_id, name) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',

    -- ── Véhicules (Union) ───────────────────
    SELECT_GLOVEBOX = 'SELECT plate, glovebox FROM owned_vehicles WHERE plate = ?',
    SELECT_TRUNK    = 'SELECT plate, trunk FROM owned_vehicles WHERE plate = ?',
    UPDATE_TRUNK    = 'UPDATE owned_vehicles SET trunk = ? WHERE plate = ?',
    UPDATE_GLOVEBOX = 'UPDATE owned_vehicles SET glovebox = ? WHERE plate = ?',

    -- ── Joueur ──────────────────────────────
    SELECT_PLAYER = 'SELECT data FROM kt_inventory WHERE unique_id = ? AND name = ?',
    UPSERT_PLAYER = 'INSERT INTO kt_inventory (data, unique_id, name) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
}

-- ─────────────────────────────────────────────
-- INITIALISATION
-- ─────────────────────────────────────────────

Citizen.CreateThreadNow(function()
    Wait(0)

    -- Vérifie table kt_inventory
    local ok = pcall(MySQL.scalar.await, 'SELECT 1 FROM kt_inventory LIMIT 1')
    if not ok then
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `kt_inventory` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `unique_id` VARCHAR(32) NOT NULL,
                `name` VARCHAR(100) NOT NULL DEFAULT 'player',
                `data` LONGTEXT DEFAULT NULL,
                `max_weight` INT DEFAULT 10000,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY `uniq_inventory` (`unique_id`, `name`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])

        lib.print.info('[kt_inventory] Table kt_inventory créée')
    end

    -- Vérifie colonnes véhicules
    local cols = MySQL.query.await('SHOW COLUMNS FROM owned_vehicles')
    if cols then
        local hasTrunk, hasGlovebox = false, false

        for _, col in ipairs(cols) do
            if col.Field == 'trunk' then hasTrunk = true end
            if col.Field == 'glovebox' then hasGlovebox = true end
        end

        if not hasTrunk then
            MySQL.query('ALTER TABLE owned_vehicles ADD COLUMN trunk LONGTEXT NULL')
        end

        if not hasGlovebox then
            MySQL.query('ALTER TABLE owned_vehicles ADD COLUMN glovebox LONGTEXT NULL')
        end
    end

    -- Nettoyage vieux stashes
    local clear = GetConvar('inventory:clearstashes', '6 MONTH')
    if clear ~= '' then
        pcall(MySQL.query.await,
            ('DELETE FROM kt_inventory WHERE updated_at < (NOW() - INTERVAL %s)'):format(clear)
        )
    end
end)

-- ─────────────────────────────────────────────
-- API DB
-- ─────────────────────────────────────────────

db = {}

-- ── JOUEUR ──────────────────────────────────

function db.loadPlayer(uniqueId)
    local result = MySQL.prepare.await(Query.SELECT_PLAYER, { uniqueId, 'player' })
    return result and json.decode(result) or nil
end

function db.savePlayer(uniqueId, inventory)
    return MySQL.prepare(Query.UPSERT_PLAYER, { inventory, uniqueId, 'player' })
end

-- ── STASH ───────────────────────────────────

function db.loadStash(uniqueId, name)
    local result = MySQL.prepare.await(Query.SELECT_STASH, { uniqueId or '', name })
    return result and json.decode(result) or nil
end

function db.saveStash(uniqueId, name, inventory)
    return MySQL.prepare(Query.UPSERT_STASH, { inventory, uniqueId or '', name })
end

-- ── VEHICULE ────────────────────────────────

function db.loadGlovebox(plate)
    return MySQL.prepare.await(Query.SELECT_GLOVEBOX, { plate })
end

function db.saveGlovebox(plate, inventory)
    return MySQL.prepare(Query.UPDATE_GLOVEBOX, { inventory, plate })
end

function db.loadTrunk(plate)
    return MySQL.prepare.await(Query.SELECT_TRUNK, { plate })
end

function db.saveTrunk(plate, inventory)
    return MySQL.prepare(Query.UPDATE_TRUNK, { inventory, plate })
end

-- ─────────────────────────────────────────────
-- SAVE GROUPÉ
-- ─────────────────────────────────────────────

local function safeQuery(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then
        print('[kt_inventory] ERROR:', res)
        return nil
    end
    return res
end

function db.saveInventories(players, trunks, gloveboxes, stashes, total)
    local pending = 0
    local start = os.nanotime()

    local function done(label, count)
        print(('[kt_inventory] Saved %d %s (%.2f ms)')
            :format(count, label, (os.nanotime() - start) / 1e6))
    end

    -- Players
    if total[1] > 0 then
        pending += 1
        Citizen.CreateThreadNow(function()
            safeQuery(MySQL.prepare.await, Query.UPSERT_PLAYER, players)
            pending -= 1
            done('players', total[1])
        end)
    end

    -- Trunks
    if total[2] > 0 then
        pending += 1
        Citizen.CreateThreadNow(function()
            safeQuery(MySQL.prepare.await, Query.UPDATE_TRUNK, trunks)
            pending -= 1
            done('trunks', total[2])
        end)
    end

    -- Gloveboxes
    if total[3] > 0 then
        pending += 1
        Citizen.CreateThreadNow(function()
            safeQuery(MySQL.prepare.await, Query.UPDATE_GLOVEBOX, gloveboxes)
            pending -= 1
            done('gloveboxes', total[3])
        end)
    end

    -- Stashes
    if total[4] > 0 then
        pending += 1
        Citizen.CreateThreadNow(function()
            safeQuery(MySQL.prepare.await, Query.UPSERT_STASH, stashes)
            pending -= 1
            done('stashes', total[4])
        end)
    end

    repeat Wait(0) until pending == 0
end

return db