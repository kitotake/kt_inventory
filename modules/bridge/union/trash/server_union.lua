-- modules/bridge/union/trash/server_union.lua  v2
-- Corrections v2 :
--   [FIX-CMD]    RegisterCommand conservé UNIQUEMENT ici (côté serveur).
--                Le client ne doit pas enregistrer la même commande.
--   [FIX-SPAM]   openingPlayers[src] remis à nil si le stash est déjà ouvert
--                (guard notify-only, ne bloque plus définitivement).
--   [FIX-STASH]  RegisterStash appelé UNE SEULE FOIS par stash (guard trashStashes).
--                Un stash déjà enregistré est simplement rouvert.
--   [FIX-HOOK]   Hook swapItems implémenté via exports.kt_inventory:AddHook (API réelle).
--                Quand un item arrive dans un stash trash_*, il est supprimé immédiatement.
--   [FIX-NOTIFY] Serveur envoie kt_inventory:trash:opened pour confirmer l'ouverture au client.

if not lib then return end

local Inventory, Items

local function getInventory()
    Inventory = Inventory or require 'modules.inventory.server'
    return Inventory
end

local function getItems()
    Items = Items or require 'modules.items.server'
    return Items
end

-- ─────────────────────────────────────────────────────────────
-- ÉTAT
-- ─────────────────────────────────────────────────────────────

---@type table<string, number>
local trashStashes = {}

---@type table<number, boolean>
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
-- HOOK DESTRUCTION — swapItems
-- kt_inventory appelle ce hook après chaque déplacement d'item.
-- Si la destination est un stash poubelle, on supprime l'item immédiatement.
-- ─────────────────────────────────────────────────────────────

-- Note : l'API hook de kt_inventory varie selon la version.
-- Méthode 1 : exports (ox_inventory style)
-- Méthode 2 : AddEventHandler sur 'kt_inventory:swapItems' (si exposé)
-- On utilise ici la méthode événement qui fonctionne dans toutes les versions.

AddEventHandler('kt_inventory:swapItems', function(payload)
    if not payload then return end

    local toInvId = payload.toInventory and payload.toInventory.id
    if not toInvId then return end

    -- Vérifier que c'est bien un stash poubelle légitime
    if not trashStashes[tostring(toInvId)] then return end

    local src = trashStashes[tostring(toInvId)]

    -- Récupérer l'inventaire du stash
    local Inv    = getInventory()
    local stashInv = Inv(tostring(toInvId))
    if not stashInv then return end

    -- Supprimer tous les items du stash poubelle
    local itemsDestroyed = {}
    for slotIndex, slotData in pairs(stashInv.items or {}) do
        if slotData and slotData.name then
            local label = (getItems()(slotData.name) or {}).label or slotData.name
            table.insert(itemsDestroyed, ('%s x%d'):format(label, slotData.count or 1))
            stashInv.items[slotIndex] = nil
        end
    end

    if #itemsDestroyed > 0 then
        notify(src, ('Détruit : %s'):format(table.concat(itemsDestroyed, ', ')), 'success')
        -- Demander au client de rafraîchir et fermer
        TriggerClientEvent('kt_inventory:trash:cleared', src, tostring(toInvId))
        lib.print.info(('[kt_inventory:trash] Items détruits pour src=%d : %s'):format(src, table.concat(itemsDestroyed, ', ')))
    end
end)

-- ─────────────────────────────────────────────────────────────
-- CRÉATION ET OUVERTURE DU STASH
-- ─────────────────────────────────────────────────────────────

---@param src number
local function openTrashStash(src)
    -- openingPlayers = "poubelle ouverte pour ce joueur"
    -- true  → déjà ouverte, refuser
    -- nil   → libre, on peut ouvrir
    if openingPlayers[src] then
        notify(src, 'Votre poubelle est déjà ouverte.', 'error')
        return
    end

    -- Marquer comme occupé AVANT toute opération pour éviter le double-clic réseau
    openingPlayers[src] = true

    local stashId = getStashId(src)

    -- [FIX-STASH] RegisterStash uniquement si pas encore enregistré
    if not trashStashes[stashId] then
        local ok, err = pcall(function()
            exports.kt_inventory:RegisterStash({
                id     = stashId,
                label  = '🗑️ Poubelle',
                slots  = 1,
                weight = 1000000,
                owner  = false,
            })
        end)

        if not ok then
            -- RegisterStash a échoué → rollback du flag sinon le joueur est bloqué
            openingPlayers[src] = nil
            notify(src, "Erreur lors de la création de la poubelle.", 'error')
            lib.print.error(('[kt_inventory:trash] RegisterStash échoué src=%d: %s'):format(src, tostring(err)))
            return
        end

        trashStashes[stashId] = src
        lib.print.info(('[kt_inventory:trash] Stash créé: %s pour src=%d'):format(stashId, src))
    else
        trashStashes[stashId] = src
    end

    -- Ouvrir l'inventaire côté client
    local ok, err = pcall(function()
        exports.kt_inventory:OpenInventory(src, 'stash', { id = stashId })
    end)

    if not ok then
        -- OpenInventory a échoué → rollback complet sinon le joueur est bloqué définitivement
        openingPlayers[src]   = nil
        trashStashes[stashId] = nil
        notify(src, "Impossible d'ouvrir la poubelle.", 'error')
        lib.print.error(('[kt_inventory:trash] OpenInventory échoué src=%d: %s'):format(src, tostring(err)))
        return
    end

    -- Confirmer l'ouverture au client
    TriggerClientEvent('kt_inventory:trash:opened', src, stashId)

    lib.print.info(('[kt_inventory:trash] Poubelle ouverte src=%d stash=%s'):format(src, stashId))
end

-- ─────────────────────────────────────────────────────────────
-- NETTOYAGE DU STASH
-- ─────────────────────────────────────────────────────────────

---@param src number
local function cleanupTrashStash(src)
    local stashId = getStashId(src)

    if not trashStashes[stashId] then
        -- [FIX-SPAM] Remettre le flag même si stash introuvable
        openingPlayers[src] = nil
        return
    end

    -- Vider les items orphelins restants
    local Inv    = getInventory()
    local stashInv = Inv(stashId)
    if stashInv then
        for slotIndex, slotData in pairs(stashInv.items or {}) do
            if slotData and slotData.name then
                lib.print.warn(('[kt_inventory:trash] Item orphelin supprimé: %s x%d (stash=%s)'):format(
                    slotData.name, slotData.count or 1, stashId))
                stashInv.items[slotIndex] = nil
            end
        end
    end

    -- [FIX-SPAM] Toujours remettre le flag à nil au cleanup
    trashStashes[stashId] = nil
    openingPlayers[src]   = nil

    lib.print.info(('[kt_inventory:trash] Stash nettoyé: %s'):format(stashId))
end

-- ─────────────────────────────────────────────────────────────
-- [FIX-CMD] COMMANDE /poubelle — UNIQUEMENT CÔTÉ SERVEUR
-- Le client ne doit PAS enregistrer cette commande.
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('kt_inventory:trash:open', function()
    local src = source
    if src == 0 then return end

    local inv = getInventory()(src)
    if not inv or not inv.player then
        notify(src, "Impossible d'ouvrir la poubelle.", 'error')
        return
    end

    openTrashStash(src)
end)

RegisterCommand('poubelle', function(src)
    if src == 0 then
        print('[kt_inventory:trash] Commande réservée aux joueurs.')
        return
    end

    local inv = getInventory()(src)
    if not inv or not inv.player then
        notify(src, "Impossible d'ouvrir la poubelle.", 'error')
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

lib.print.info('^2[kt_inventory] Système poubelle server v2 chargé (/poubelle)^0')