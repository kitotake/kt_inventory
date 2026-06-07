-- modules/bridge/union/trash/server_union.lua  v3
-- Corrections v3 :
--   [FIX-HOOK]    Pas de AddHook dans kt_inventory → détection par poll (GetInventoryItems)
--                 toutes les 500ms pendant que la poubelle est ouverte.
--   [FIX-STASH]   RegisterStash signature correcte : (id, label, slots, maxWeight, owner, groups, coords)
--   [FIX-OPEN]    forceOpenInventory(src, 'stash', { id = stashId }) → API réelle côté serveur
--   [FIX-CLEAR]   ClearInventory(stashId) → API réelle pour vider le stash

if not lib then return end

-- ─────────────────────────────────────────────────────────────
-- ÉTAT
-- ─────────────────────────────────────────────────────────────

---@type table<string, number>   stashId → playerId
local trashStashes = {}

---@type table<number, boolean>  playerId → ouvert ?
local openingPlayers = {}

-- ─────────────────────────────────────────────────────────────
-- HELPERS
-- ─────────────────────────────────────────────────────────────

---@param src number
---@return string
local function getStashId(src)
    return ('trash_%d'):format(src)
end

---@param src number
---@param msg string
---@param nType? string
local function notify(src, msg, nType)
    TriggerClientEvent('kt_inventory:trash:notify', src, msg, nType or 'inform')
end

-- ─────────────────────────────────────────────────────────────
-- POLL DE DESTRUCTION
-- Toutes les 500ms, si la poubelle est ouverte, on regarde
-- si des items ont été déposés et on les détruit avec ClearInventory.
-- ─────────────────────────────────────────────────────────────

---@param src number
local function startTrashPoll(src)
    local stashId = getStashId(src)

    SetTimeout(500, function()
        -- Arrêt du poll si la poubelle a été fermée
        if not openingPlayers[src] then return end

        local items = exports.kt_inventory:GetInventoryItems(stashId)

        if items and next(items) then
            -- Construire la liste des noms pour la notif
            local destroyed = {}
            for _, item in pairs(items) do
                if item and item.name then
                    local label = item.label or item.name
                    table.insert(destroyed, ('%s x%d'):format(label, item.count or 1))
                end
            end

            -- Vider le stash via l'API officielle
            exports.kt_inventory:ClearInventory(stashId)

            if #destroyed > 0 then
                notify(src, ('Détruit : %s'):format(table.concat(destroyed, ', ')), 'success')
                lib.print.info(('[kt_inventory:trash] Items détruits src=%d : %s'):format(
                    src, table.concat(destroyed, ', ')))
            end

            -- Signaler au client pour fermer l'UI
            TriggerClientEvent('kt_inventory:trash:cleared', src, stashId)
            return  -- on arrête le poll, le client va fermer
        end

        -- Rien encore → on repoll
        startTrashPoll(src)
    end)
end

-- ─────────────────────────────────────────────────────────────
-- OUVERTURE DU STASH
-- ─────────────────────────────────────────────────────────────

---@param src number
local function openTrashStash(src)
    if openingPlayers[src] then
        notify(src, 'Votre poubelle est déjà ouverte.', 'error')
        return
    end

    -- Marquer occupé AVANT toute opération (anti double-clic réseau)
    openingPlayers[src] = true

    local stashId = getStashId(src)

    -- RegisterStash une seule fois par stash
    if not trashStashes[stashId] then
        local ok, err = pcall(function()
            -- Signature réelle : (id, label, slots, maxWeight, owner, groups, coords)
            exports.kt_inventory:RegisterStash(stashId, '🗑️ Poubelle', 5, 1000000, false)
        end)

        if not ok then
            openingPlayers[src] = nil
            notify(src, "Erreur lors de la création de la poubelle.", 'error')
            lib.print.error(('[kt_inventory:trash] RegisterStash échoué src=%d: %s'):format(src, tostring(err)))
            return
        end

        lib.print.info(('[kt_inventory:trash] Stash créé: %s pour src=%d'):format(stashId, src))
    end

    trashStashes[stashId] = src

    -- Vider le stash avant ouverture (items résiduels d'une session précédente)
    exports.kt_inventory:ClearInventory(stashId)

    -- Ouvrir l'inventaire via l'API serveur réelle
    local ok, err = pcall(function()
        exports.kt_inventory:forceOpenInventory(src, 'stash', { id = stashId })
    end)

    if not ok then
        openingPlayers[src]   = nil
        trashStashes[stashId] = nil
        notify(src, "Impossible d'ouvrir la poubelle.", 'error')
        lib.print.error(('[kt_inventory:trash] forceOpenInventory échoué src=%d: %s'):format(src, tostring(err)))
        return
    end

    -- Confirmer au client
    TriggerClientEvent('kt_inventory:trash:opened', src, stashId)

    -- Démarrer le poll de destruction
    startTrashPoll(src)

    lib.print.info(('[kt_inventory:trash] Poubelle ouverte src=%d stash=%s'):format(src, stashId))
end

-- ─────────────────────────────────────────────────────────────
-- NETTOYAGE DU STASH
-- ─────────────────────────────────────────────────────────────

---@param src number
local function cleanupTrashStash(src)
    local stashId = getStashId(src)

    -- Vider les éventuels items résiduels
    if trashStashes[stashId] then
        exports.kt_inventory:ClearInventory(stashId)
        trashStashes[stashId] = nil
    end

    openingPlayers[src] = nil

    lib.print.info(('[kt_inventory:trash] Stash nettoyé: %s'):format(stashId))
end

-- ─────────────────────────────────────────────────────────────
-- COMMANDE /poubelle — UNIQUEMENT CÔTÉ SERVEUR
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('kt_inventory:trash:open', function()
    local src = source
    if src == 0 then return end
    openTrashStash(src)
end)

RegisterCommand('poubelle', function(src)
    if src == 0 then
        print('[kt_inventory:trash] Commande réservée aux joueurs.')
        return
    end
    openTrashStash(src)
end, false)

-- ─────────────────────────────────────────────────────────────
-- FERMETURE DEPUIS CLIENT
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('kt_inventory:trash:close', function()
    cleanupTrashStash(source)
end)

-- ─────────────────────────────────────────────────────────────
-- NETTOYAGE À LA DÉCONNEXION
-- ─────────────────────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    cleanupTrashStash(source)
end)

lib.print.info('^2[kt_inventory] Système poubelle server v3 chargé (/poubelle)^0')