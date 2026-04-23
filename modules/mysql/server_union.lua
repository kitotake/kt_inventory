-- modules/mysql/server_union.lua
-- Module MySQL kt_inventory adapté pour Union Framework
-- Utilise unique_id (personnage) comme owner au lieu de identifier (joueur)

if not lib then return end

local Query = {
    -- ── Stash ────────────────────────────────────────────────────────────────
    SELECT_STASH  = 'SELECT data FROM kt_inventory WHERE unique_id = ? AND name = ?',
    UPSERT_STASH  = 'INSERT INTO kt_inventory (data, unique_id, name) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',

    -- ── Véhicules (owned_vehicles de Union, clé = plate) ────────────────────
    SELECT_GLOVEBOX = 'SELECT plate, glovebox FROM owned_vehicles WHERE plate = ?',
    SELECT_TRUNK    = 'SELECT plate, trunk    FROM owned_vehicles WHERE plate = ?',
    UPDATE_TRUNK    = 'UPDATE owned_vehicles SET trunk    = ? WHERE plate = ?',
    UPDATE_GLOVEBOX = 'UPDATE owned_vehicles SET glovebox = ? WHERE plate = ?',

    -- ── Inventaire joueur (2 params : data + unique_id, name hardcodé) ───────
    -- On embed 'player' directement pour rester compatible avec le batch
    -- prepareInventorySave retourne { data, inv.owner } → 2 params
    UPSERT_PLAYER = "INSERT INTO kt_inventory (data, unique_id, name) VALUES (?, ?, 'player') ON DUPLICATE KEY UPDATE data = VALUES(data)",
}

-- ────────────────────────────────────────────────────────────────────────────
-- Initialisation DB
-- ────────────────────────────────────────────────────────────────────────────
Citizen.CreateThreadNow(function()
    Wait(0)

    -- Vérifier / créer la table kt_inventory
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
        lib.print.info('[kt_inventory:union] Table kt_inventory créée.')
    end

    -- Vérifier colonnes trunk / glovebox sur owned_vehicles
    local cols = MySQL.query.await('SHOW COLUMNS FROM owned_vehicles') or {}
    local hasTrunk, hasGlovebox = false, false
    for _, col in ipairs(cols) do
        if col.Field == 'trunk'    then hasTrunk    = true end
        if col.Field == 'glovebox' then hasGlovebox = true end
    end
    if not hasTrunk    then MySQL.query('ALTER TABLE owned_vehicles ADD COLUMN trunk    LONGTEXT NULL') end
    if not hasGlovebox then MySQL.query('ALTER TABLE owned_vehicles ADD COLUMN glovebox LONGTEXT NULL') end

    -- Nettoyage anciens stashes
    local clearStashes = GetConvar('inventory:clearstashes', '6 MONTH')
    if clearStashes ~= '' then
        pcall(MySQL.query.await,
            ('DELETE FROM kt_inventory WHERE updated_at < (NOW() - INTERVAL %s)'):format(clearStashes))
    end

    lib.print.info('[kt_inventory:union] MySQL initialisé.')
end)

-- ────────────────────────────────────────────────────────────────────────────
-- API db (globale, utilisée par modules/inventory/server.lua)
-- ────────────────────────────────────────────────────────────────────────────
db = {}

-- ── Joueur (inventaire par personnage via unique_id) ─────────────────────────

--- Chargement : retourne une table décodée (ou nil si nouveau perso)
function db.loadPlayer(uniqueId)
    local result = MySQL.scalar.await(
        "SELECT data FROM kt_inventory WHERE unique_id = ? AND name = 'player'",
        { uniqueId }
    )
    -- Inventory.Load attend type='table', on decode ici
    return result and json.decode(result) or nil
end

--- Sauvegarde individuelle (appelée par Inventory.Save)
function db.savePlayer(uniqueId, inventory)
    return MySQL.query(Query.UPSERT_PLAYER, { inventory, uniqueId })
end

-- ── Stash ─────────────────────────────────────────────────────────────────────

--- Retourne la chaîne JSON brute (Inventory.Load la decode lui-même)
function db.loadStash(owner, name)
    return MySQL.scalar.await(Query.SELECT_STASH, { owner or '', name })
end

function db.saveStash(owner, name, inventory)
    return MySQL.query(Query.UPSERT_STASH, { inventory, owner or '', name })
end

-- ── Véhicules ─────────────────────────────────────────────────────────────────

--- Retourne la ligne complète { plate, glovebox } — Inventory.Load extrait [invType]
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

-- ── Sauvegarde groupée (appelée par Inventory.SaveInventories) ────────────────
--
-- Format reçu depuis prepareInventorySave :
--   players   → { {data, uid}, {data, uid}, … }       (2 params — compatible UPSERT_PLAYER)
--   trunks    → { {data, plate}, … }                   (2 params — compatible UPDATE_TRUNK)
--   gloveboxes→ { {data, plate}, … }                   (2 params — compatible UPDATE_GLOVEBOX)
--   stashes   → { {data, owner, name}, … }             (3 params — compatible UPSERT_STASH)
--              ou flat si bulkstashsave=true
--
local function safeQuery(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then
        print('[kt_inventory:union] Erreur sauvegarde : ' .. tostring(res))
        return nil
    end
    return res
end

function db.saveInventories(players, trunks, gloveboxes, stashes, total)
    local pending = 0
    local start   = os.nanotime()

    local function done(label, count)
        lib.print.info(('[kt_inventory:union] Sauvegardé %d %s (%.2f ms)'):format(
            count, label, (os.nanotime() - start) / 1e6))
    end

    -- Players  (2 params : data, unique_id)
    if total[1] > 0 then
        pending += 1
        Citizen.CreateThreadNow(function()
            safeQuery(MySQL.prepare.await, Query.UPSERT_PLAYER, players)
            pending -= 1
            done('players', total[1])
        end)
    end

    -- Trunks   (2 params : data, plate)
    if total[2] > 0 then
        pending += 1
        Citizen.CreateThreadNow(function()
            safeQuery(MySQL.prepare.await, Query.UPDATE_TRUNK, trunks)
            pending -= 1
            done('trunks', total[2])
        end)
    end

    -- Gloveboxes (2 params : data, plate)
    if total[3] > 0 then
        pending += 1
        Citizen.CreateThreadNow(function()
            safeQuery(MySQL.prepare.await, Query.UPDATE_GLOVEBOX, gloveboxes)
            pending -= 1
            done('gloveboxes', total[3])
        end)
    end

    -- Stashes  (3 params : data, owner, name)
    if total[4] > 0 then
        pending += 1
        Citizen.CreateThreadNow(function()
            if server.bulkstashsave then
                -- flat array : {data1, owner1, name1, data2, owner2, name2, …}
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