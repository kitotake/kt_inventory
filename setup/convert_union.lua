local started = false

local function Print(msg)
    print(('^3================================\n^0%s\n^3=====================================^0'):format(msg))
end

local function ConvertUnionVehicles()
    if started then
        return warn('Conversion déjà en cours...')
    end

    started = true

    Print('Récupération des trunks et glovebox...')

    local trunk = MySQL.query.await(
        'SELECT owner, name, data FROM kt_inventory WHERE name LIKE ?',
        {'trunk-%'}
    )

    local glovebox = MySQL.query.await(
        'SELECT owner, name, data FROM kt_inventory WHERE name LIKE ?',
        {'glovebox-%'}
    )

    if not trunk and not glovebox then
        Print('Aucune donnée à convertir')
        started = false
        return
    end

    local vehicles = {}

    -- 📦 TRUNK
    for _, v in pairs(trunk or {}) do
        local owner = v.owner -- = unique_id
        local plate = v.name:sub(7)

        vehicles[owner] = vehicles[owner] or {}
        vehicles[owner][plate] = vehicles[owner][plate] or {
            trunk = '[]',
            glovebox = '[]'
        }

        vehicles[owner][plate].trunk = v.data or '[]'
    end

    -- 🧤 GLOVEBOX
    for _, v in pairs(glovebox or {}) do
        local owner = v.owner -- = unique_id
        local plate = v.name:sub(10)

        vehicles[owner] = vehicles[owner] or {}
        vehicles[owner][plate] = vehicles[owner][plate] or {
            trunk = '[]',
            glovebox = '[]'
        }

        vehicles[owner][plate].glovebox = v.data or '[]'
    end

    Print('Préparation des données...')

    local params = {}
    local count = 0

    for owner, vehs in pairs(vehicles) do
        for plate, data in pairs(vehs) do
            count += 1

            params[count] = {
                data.trunk or '[]',
                data.glovebox or '[]',
                plate,
                owner -- ⚠️ correspond à unique_id
            }
        end
    end

    if count == 0 then
        Print('Aucune correspondance trouvée')
        started = false
        return
    end

    Print(('Migration de ^3%s^0 véhicules...'):format(count))

    MySQL.prepare.await(
        'UPDATE owned_vehicles SET trunk = ?, glovebox = ? WHERE plate = ? AND unique_id = ?',
        params
    )

    Print('Nettoyage de kt_inventory...')

    MySQL.prepare.await(
        'DELETE FROM kt_inventory WHERE name LIKE ? OR name LIKE ?',
        {'trunk-%', 'glovebox-%'}
    )

    Print('✅ Conversion terminée avec succès !')

    started = false
end

return {
    vehicles = ConvertUnionVehicles
}