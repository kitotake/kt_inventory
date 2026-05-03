-- modules/mysql/server_union.lua
-- Module MySQL kt_inventory adapte pour Union Framework
-- Utilise unique_id (personnage) comme owner au lieu de identifier (joueur)

if not lib then return end

-- ─────────────────────────────────────────────────────────────────────────────
-- QUERIES
-- FIX: UPSERT_PLAYER accepte (data, unique_id) et hardcode name='player'
--      savePlayer passe { inventory, uniqueId } -> correspond correctement
-- ─────────────────────────────────────────────────────────────────────────────
local Query = {
    SELECT_STASH  = 'SELECT data FROM kt_inventory WHERE unique_id = ? AND name = ?',
    UPSERT_STASH  = 'INSERT INTO kt_inventory (data, unique_id, name) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',

    -- Vehicules (owned_vehicles de Union, cle = plate)
    SELECT_GLOVEBOX = 'SELECT plate, glovebox FROM owned_vehicles WHERE plate = ?',
    SELECT_TRUNK    = 'SELECT plate, trunk    FROM owned_vehicles WHERE plate = ?',
    UPDATE_TRUNK    = 'UPDATE owned_vehicles SET trunk    = ? WHERE plate = ?',
    UPDATE_GLOVEBOX = 'UPDATE owned_vehicles SET glovebox = ? WHERE plate = ?',

    -- FIX: UPSERT_PLAYER avec exactement 2 parametres (data, unique_id)
    -- Le name 'player' est hardcode dans la requete
    UPSERT_PLAYER = "INSERT INTO kt_inventory (data, unique_id, name) VALUES (?, ?, 'player') ON DUPLICATE KEY UPDATE data = VALUES(data)",
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Initialisation DB
-- ─────────────────────────────────────────────────────────────────────────────
Citizen.CreateThreadNow(function()
    Wait(0)

    local ok = pcall(MySQL.scalar.await, 'SELECT 1 FROM kt_inventory LIMIT 1')
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
        lib.print.info('[kt_inventory:union] Table kt_inventory creee.')
    end

    local cols = MySQL.query.await('SHOW COLUMNS FROM owned_vehicles') or {}
    local hasTrunk, hasGlovebox = false, false
    for _, col in ipairs(cols) do
        if col.Field == 'trunk'    then hasTrunk    = true end
        if col.Field == 'glovebox' then hasGlovebox = true end
    end
    if not hasTrunk    then MySQL.query('ALTER TABLE owned_vehicles ADD COLUMN trunk    LONGTEXT NULL') end
    if not hasGlovebox then MySQL.query('ALTER TABLE owned_vehicles ADD COLUMN glovebox LONGTEXT NULL') end

    local clearStashes = GetConvar('inventory:clearstashes', '6 MONTH')
    if clearStashes ~= '' then
        pcall(MySQL.query.await,
            ('DELETE FROM kt_inventory WHERE updated_at < (NOW() - INTERVAL %s)'):format(clearStashes))
    end

    lib.print.info('[kt_inventory:union] MySQL initialise.')
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- API db (globale, utilisee par modules/inventory/server.lua)
-- ─────────────────────────────────────────────────────────────────────────────
db = {}

-- Joueur (inventaire par personnage via unique_id)

function db.loadPlayer(uniqueId)
    if not uniqueId then
        lib.print.warn('[kt_inventory:union] loadPlayer: uniqueId nil, retour nil')
        return nil
    end

    lib.print.info(('[kt_inventory:union] Chargement inventaire -> unique_id=%s'):format(tostring(uniqueId)))

    local result = MySQL.scalar.await(
        "SELECT data FROM kt_inventory WHERE unique_id = ? AND name = 'player'",
        { uniqueId }
    )

    if result then
        local decoded = json.decode(result)
        local count = decoded and #decoded or 0
        lib.print.info(('[kt_inventory:union] Inventaire trouve pour unique_id=%s (%d slots)'):format(tostring(uniqueId), count))
        return decoded
    else
        lib.print.info(('[kt_inventory:union] Aucun inventaire pour unique_id=%s -> vide'):format(tostring(uniqueId)))
        return nil
    end
end

-- FIX: savePlayer passe { inventory, uniqueId } = 2 params pour UPSERT_PLAYER (?, ?)
-- C'est correct : VALUES(?, ?, 'player') => data=?, unique_id=?
function db.savePlayer(uniqueId, inventory)
    if not uniqueId then
        lib.print.warn('[kt_inventory:union] savePlayer: uniqueId nil, annule')
        return
    end
    lib.print.info(('[kt_inventory:union] Sauvegarde inventaire -> unique_id=%s'):format(tostring(uniqueId)))
    return MySQL.query(Query.UPSERT_PLAYER, { inventory, uniqueId })
end

-- Stash

function db.loadStash(owner, name)
    lib.print.info(('[kt_inventory:union] Chargement stash -> owner=%s name=%s'):format(tostring(owner), tostring(name)))
    return MySQL.scalar.await(Query.SELECT_STASH, { owner or '', name })
end

function db.saveStash(owner, name, inventory)
    lib.print.info(('[kt_inventory:union] Sauvegarde stash -> owner=%s name=%s'):format(tostring(owner), tostring(name)))
    return MySQL.query(Query.UPSERT_STASH, { inventory, owner or '', name })
end

-- Vehicules

function db.loadGlovebox(plate)
    if not plate then return nil end
    lib.print.info(('[kt_inventory:union] Chargement glovebox -> plate=%s'):format(tostring(plate)))
    return MySQL.prepare.await(Query.SELECT_GLOVEBOX, { plate })
end

function db.saveGlovebox(plate, inventory)
    if not plate then return end
    lib.print.info(('[kt_inventory:union] Sauvegarde glovebox -> plate=%s'):format(tostring(plate)))
    return MySQL.prepare(Query.UPDATE_GLOVEBOX, { inventory, plate })
end

function db.loadTrunk(plate)
    if not plate then return nil end
    lib.print.info(('[kt_inventory:union] Chargement trunk -> plate=%s'):format(tostring(plate)))
    return MySQL.prepare.await(Query.SELECT_TRUNK, { plate })
end

function db.saveTrunk(plate, inventory)
    if not plate then return end
    lib.print.info(('[kt_inventory:union] Sauvegarde trunk -> plate=%s'):format(tostring(plate)))
    return MySQL.prepare(Query.UPDATE_TRUNK, { inventory, plate })
end

-- Sauvegarde groupee

local function safeQuery(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then
        print('[kt_inventory:union] Erreur sauvegarde : ' .. tostring(res))
        return nil
    end
    return res
end

-- FIX: saveInventories
-- players est un tableau de { data, owner } construit par prepareInventorySave (index 1)
-- Chaque element est { data, inv.owner } -> passe a UPSERT_PLAYER (data=?, unique_id=?)
function db.saveInventories(players, trunks, gloveboxes, stashes, total)
    local pending = 0
    local start   = os.nanotime()

    local function done(label, count)
        lib.print.info(('[kt_inventory:union] Sauvegarde %d %s (%.2f ms)'):format(
            count, label, (os.nanotime() - start) / 1e6))
    end

    if total[1] > 0 then
        lib.print.info(('[kt_inventory:union] Sauvegarde groupee %d inventaires joueurs...'):format(total[1]))
        pending += 1
        Citizen.CreateThreadNow(function()
            -- players contient des { data, unique_id } - format correct pour UPSERT_PLAYER
            safeQuery(MySQL.prepare.await, Query.UPSERT_PLAYER, players)
            pending -= 1
            done('players', total[1])
        end)
    end

    if total[2] > 0 then
        pending += 1
        Citizen.CreateThreadNow(function()
            safeQuery(MySQL.prepare.await, Query.UPDATE_TRUNK, trunks)
            pending -= 1
            done('trunks', total[2])
        end)
    end

    if total[3] > 0 then
        pending += 1
        Citizen.CreateThreadNow(function()
            safeQuery(MySQL.prepare.await, Query.UPDATE_GLOVEBOX, gloveboxes)
            pending -= 1
            done('gloveboxes', total[3])
        end)
    end

    if total[4] > 0 then
        pending += 1
        Citizen.CreateThreadNow(function()
            if server.bulkstashsave then
                local n     = total[4] / 3
                local query = Query.UPSERT_STASH:gsub('%(%?, %?, %?%)',
                    string.rep('(?, ?, ?)', n, ', '))
                safeQuery(MySQL.query.await, query, stashes)
            else
                safeQuery(MySQL.prepare.await, Query.UPSERT_STASH, stashes)
            end
            pending -= 1
            done('stashes', total[4])
        end)
    end

    repeat Wait(0) until pending == 0
end

return db
