-- setup/convert_union.lua
-- Script de conversion des donnees vehicules pour Union Framework

local started = false

local function Print(msg)
    print(('^3================================\n^0%s\n^3=====================================^0'):format(msg))
end

-- FIX: La table owned_vehicles dans Union utilise 'plate' comme cle primaire,
-- pas 'unique_id'. La version precedente faisait:
--   WHERE plate = ? AND unique_id = ?
-- ce qui echouait si owned_vehicles n'a pas de colonne unique_id.
-- On utilise uniquement 'plate' comme cle, qui est l'identifiant vehicule
-- standard dans les frameworks FiveM.

local function ConvertUnionVehicles()
    if started then
        return warn('Conversion deja en cours...')
    end

    started = true

    Print('Recuperation des trunks et glovebox depuis kt_inventory...')

    local trunk = MySQL.query.await(
        'SELECT owner, name, data FROM kt_inventory WHERE name LIKE ?',
        {'trunk-%'}
    )

    local glovebox = MySQL.query.await(
        'SELECT owner, name, data FROM kt_inventory WHERE name LIKE ?',
        {'glovebox-%'}
    )

    if (not trunk or #trunk == 0) and (not glovebox or #glovebox == 0) then
        Print('Aucune donnee a convertir')
        started = false
        return
    end

    local vehicles = {}

    -- TRUNK: name = 'trunk-PLATE'
    for _, v in pairs(trunk or {}) do
        local plate = v.name:sub(7) -- retire 'trunk-'

        vehicles[plate] = vehicles[plate] or {
            trunk    = '[]',
            glovebox = '[]'
        }

        if v.data and v.data ~= '' then
            vehicles[plate].trunk = v.data
        end
    end

    -- GLOVEBOX: name = 'glovebox-PLATE'  (ou 'glove-PLATE' selon la version)
    for _, v in pairs(glovebox or {}) do
        -- Compatibilite: certaines versions utilisent 'glove' (5 chars), d'autres 'glovebox' (8 chars)
        -- Le prefix exact est determine par le debut du nom
        local plate
        if v.name:sub(1, 8) == 'glovebox' then
            plate = v.name:sub(10) -- 'glovebox-'
        elseif v.name:sub(1, 5) == 'glove' then
            plate = v.name:sub(7)  -- 'glove-' (format interne kt_inventory)
        else
            -- Fallback
            plate = v.name:match('^[^-]+-(.+)$')
        end

        if plate then
            vehicles[plate] = vehicles[plate] or {
                trunk    = '[]',
                glovebox = '[]'
            }

            if v.data and v.data ~= '' then
                vehicles[plate].glovebox = v.data
            end
        end
    end

    Print('Preparation des donnees...')

    local params = {}
    local count  = 0

    for plate, data in pairs(vehicles) do
        count += 1
        -- FIX: UPDATE uniquement par 'plate' (pas unique_id)
        params[count] = {
            data.trunk    or '[]',
            data.glovebox or '[]',
            plate
        }
    end

    if count == 0 then
        Print('Aucune correspondance vehicule trouvee')
        started = false
        return
    end

    Print(('Migration de ^3%s^0 vehicules...'):format(count))

    -- FIX: Requete sans colonne unique_id
    local ok, err = pcall(
        MySQL.prepare.await,
        'UPDATE owned_vehicles SET trunk = ?, glovebox = ? WHERE plate = ?',
        params
    )

    if not ok then
        Print(('ERREUR lors de la mise a jour: %s'):format(tostring(err)))
        started = false
        return
    end

    Print('Nettoyage de kt_inventory (suppression des anciennes entrees)...')

    MySQL.prepare.await(
        'DELETE FROM kt_inventory WHERE name LIKE ? OR name LIKE ?',
        {'trunk-%', 'glove%-%'}
    )

    Print('Conversion terminee avec succes !')

    started = false
end

-- Conversion des inventaires joueurs depuis un ancien format (si necessaire)
-- Cette fonction reindexe les inventaires stockes avec un identifier classique
-- vers le format unique_id utilise par Union.
local function ConvertUnionPlayerInventories()
    if started then
        return warn('Conversion deja en cours...')
    end

    started = true

    Print("Recherche des inventaires joueurs au format 'player'...")

    -- Recupere tous les inventaires joueurs existants
    local inventories = MySQL.query.await(
        "SELECT unique_id, data FROM kt_inventory WHERE name = 'player'"
    )

    if not inventories or #inventories == 0 then
        Print('Aucun inventaire joueur a convertir')
        started = false
        return
    end

    Print(('Trouve %d inventaires joueurs'):format(#inventories))

    -- Ici on peut ajouter une logique de re-mapping si les unique_id
    -- ont change de format entre deux versions du framework Union.
    -- Par defaut cette fonction se contente de valider les donnees.

    local valid, invalid = 0, 0
    for _, row in ipairs(inventories) do
        if row.unique_id and row.unique_id ~= '' then
            valid += 1
        else
            invalid += 1
            print(('[kt_inventory:union] Inventaire orphelin detecte (unique_id vide): %s'):format(tostring(row.data):sub(1, 50)))
        end
    end

    Print(('Validation: %d valides, %d invalides'):format(valid, invalid))

    if invalid > 0 then
        Print("Suppression des entrees invalides (unique_id vide)...")
        MySQL.query.await("DELETE FROM kt_inventory WHERE name = 'player' AND (unique_id IS NULL OR unique_id = '')")
    end

    Print('Operation terminee.')
    started = false
end

return {
    vehicles = ConvertUnionVehicles,
    players  = ConvertUnionPlayerInventories,
}
