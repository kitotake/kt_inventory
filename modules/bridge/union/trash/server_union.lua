-- modules/bridge/union/trash/server_union.lua
-- Système de poubelle pour kt_inventory
--
-- Flux :
--   1. Joueur tape /poubelle
--   2. Serveur crée un stash temporaire "trash_<source>" (1 slot, poids illimité)
--   3. kt_inventory ouvre ce stash côté client
--   4. Le hook 'swapItems' intercepte tout move vers un stash "trash_*"
--   5. L'item est supprimé définitivement (RemoveItem) et le slot vidé
--   6. Notification au joueur + fermeture automatique de l'inventaire
--   7. À la fermeture, le stash est nettoyé de la mémoire

if not lib then return end

local Inventory = require 'modules.inventory.server'
local Items     = require 'modules.items.server'

-- ─────────────────────────────────────────────────────────────
-- ÉTAT
-- Stashes poubelle actifs : { [stashId] = source }
-- Permet de vérifier qu'un stash est bien une poubelle légitime
-- et d'identifier à quel joueur il appartient.
-- ─────────────────────────────────────────────────────────────

---@type table<string, number>
local trashStashes = {}

-- Cooldown anti-spam (un seul stash par joueur à la fois)
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

---@param stashId string
---@return boolean
local function isTrashStash(stashId)
    return trashStashes[stashId] ~= nil
end

---@param src number
---@param msg string
---@param nType? string
local function notify(src, msg, nType)
    TriggerClientEvent('kt_inventory:trash:notify', src, msg, nType or 'inform')
end

-- ─────────────────────────────────────────────────────────────
-- CRÉATION ET OUVERTURE DU STASH
-- ─────────────────────────────────────────────────────────────

---@param src number
local function openTrashStash(src)
    -- Un seul stash par joueur à la fois
    if openingPlayers[src] then
        notify(src, 'Votre poubelle est déjà ouverte.', 'error')
        return
    end

    openingPlayers[src] = true

    local stashId = getStashId(src)

    -- Enregistrement du stash dans kt_inventory
    -- slots  = 1   : un seul emplacement
    -- weight = 0   : 0 = illimité dans kt_inventory (vérifier selon ta version)
    --                Si 0 n'est pas illimité, utiliser 1000000
    exports.kt_inventory:RegisterStash({
        id     = stashId,
        label  = '🗑️ Poubelle',
        slots  = 1,
        weight = 1000000,   -- ~1 tonne, illimité en pratique
        owner  = false,     -- pas de persistance, pas de propriétaire DB
    })

    -- Mémoriser ce stash comme poubelle légitime
    trashStashes[stashId] = src

    -- Ouvrir l'inventaire côté client
    -- kt_inventory gère lui-même l'ouverture de l'UI
    exports.kt_inventory:OpenInventory(src, 'stash', { id = stashId })

    lib.print.info(('[kt_inventory:trash] Poubelle ouverte src=%d stash=%s'):format(src, stashId))
end

-- ─────────────────────────────────────────────────────────────
-- NETTOYAGE DU STASH
-- Appelé à la fermeture ou à la déconnexion
-- ─────────────────────────────────────────────────────────────

---@param src number
local function cleanupTrashStash(src)
    local stashId = getStashId(src)

    if not trashStashes[stashId] then return end

    -- Vider le stash en mémoire (sécurité : au cas où un item y serait resté)
    local inv = Inventory(stashId)
    if inv then
        -- Vider tous les slots restants
        for slotIndex, slotData in pairs(inv.items or {}) do
            if slotData and slotData.name then
                local itemLabel = (Items(slotData.name) or {}).label or slotData.name
                lib.print.warn(('[kt_inventory:trash] Item orphelin supprimé à cleanup: %s x%d (stash=%s)'):format(
                    slotData.name, slotData.count or 1, stashId))
                -- Suppression directe du slot
                inv.items[slotIndex] = nil
            end
        end
    end

    -- Retirer du registre
    trashStashes[stashId] = nil
    openingPlayers[src]   = nil

    lib.print.info(('[kt_inventory:trash] Stash nettoyé: %s'):format(stashId))
end

-- ─────────────────────────────────────────────────────────────
-- HOOK SWAP ITEMS
-- C'est ici que la destruction se produit.
-- kt_inventory appelle ce hook APRÈS avoir effectué le déplacement.
-- On détecte si la destination est un stash poubelle,
-- on supprime l'item du stash et on notifie le joueur.
-- ─────────────────────────────────────────────────────────────

-- Le hook reçoit le payload du move.
-- Structure payload (kt_inventory) :
--   payload.source          : serverId du joueur qui a bougé l'item
--   payload.fromInventory   : { type = 'player'|'stash'|..., id = string|number }
--   payload.toInventory     : { type = 'stash', id = string }
--   payload.fromSlot        : { name, count, weight, metadata, ... }
--   payload.toSlot          : { name, count, weight, metadata, ... } | nil
--   payload.count           : nombre d'items déplacés
--
-- Retourner false depuis le hook ANNULE le déplacement.
-- On ne veut PAS annuler — on laisse kt_inventory faire le move,
-- puis on supprime immédiatement le contenu du slot destination.

exports.kt_inventory:AddHook('swapItems', function(payload)
    local toInv = payload.toInventory

    -- Pas un stash poubelle → ne rien faire, laisser passer normalement
    if not toInv or toInv.type ~= 'stash' then return end
    if not isTrashStash(toInv.id) then return end

    -- Récupérer le joueur propriétaire de cette poubelle
    local src = trashStashes[toInv.id]
    if not src then return end

    -- Vérification sécurité : seul le propriétaire peut déposer
    -- (évite qu'un autre joueur proche jette dans la poubelle d'autrui)
    if payload.source ~= src then
        lib.print.warn(('[kt_inventory:trash] Tentative de dépôt non autorisé: src=%d owner=%d stash=%s'):format(
            payload.source or -1, src, toInv.id))
        return false -- Annule le move
    end

    -- Récupérer les infos de l'item déplacé
    local fromSlot = payload.fromSlot
    if not fromSlot or not fromSlot.name then return end

    local itemName  = fromSlot.name
    local itemCount = payload.count or fromSlot.count or 1
    local itemDef   = Items(itemName)
    local itemLabel = itemDef and itemDef.label or itemName

    -- Planifier la suppression APRÈS que kt_inventory ait fini son move
    -- (SetTimeout 0 = frame suivante, le move est déjà committed)
    SetTimeout(0, function()
        local trashInv = Inventory(toInv.id)
        if not trashInv then return end

        -- Vider tous les slots du stash poubelle
        -- (il n'y a qu'1 slot, mais on itère pour robustesse)
        local destroyed = false
        for slotIndex, slotData in pairs(trashInv.items or {}) do
            if slotData and slotData.name then
                trashInv.items[slotIndex] = nil
                destroyed = true
            end
        end

        if not destroyed then
            lib.print.warn(('[kt_inventory:trash] Aucun item trouvé à détruire dans %s'):format(toInv.id))
            return
        end

        -- Forcer la synchronisation du stash côté client
        -- pour que le slot apparaisse vide immédiatement
        TriggerClientEvent('kt_inventory:trash:cleared', src, toInv.id)

        -- Notification de confirmation
        local msg = ('Vous avez détruit %dx %s'):format(itemCount, itemLabel)
        notify(src, msg, 'inform')

        lib.print.info(('[kt_inventory:trash] Détruit: %s x%d par src=%d'):format(
            itemName, itemCount, src))
    end)
end)

-- ─────────────────────────────────────────────────────────────
-- COMMANDE /poubelle
-- ET NetEvent pour le trigger client (les deux arrivent ici)
-- ─────────────────────────────────────────────────────────────

-- NetEvent déclenché par le client via TriggerServerEvent('kt_inventory:trash:open')
-- Le client envoie cet event pour que le serveur crée et ouvre le stash.
-- La commande /poubelle côté serveur est un alias pour la console ou les admins.
RegisterNetEvent('kt_inventory:trash:open', function()
    local src = source
    if src == 0 then return end

    local inv = Inventory(src)
    if not inv or not inv.player then
        notify(src, "Impossible d'ouvrir la poubelle.", 'error')
        return
    end

    openTrashStash(src)
end)

RegisterCommand('poubelle', function(source)
    local src = source

    -- Commande serveur uniquement (source = 0 = console)
    if src == 0 then
        print('[kt_inventory:trash] Commande réservée aux joueurs.')
        return
    end

    -- Vérifier que le joueur a un personnage actif
    local inv = Inventory(src)
    if not inv or not inv.player then
        notify(src, "Impossible d'ouvrir la poubelle.", 'error')
        return
    end

    openTrashStash(src)
end, false) -- false = accessible à tous les joueurs

-- ─────────────────────────────────────────────────────────────
-- EVENT : FERMETURE DE LA POUBELLE (depuis client)
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('kt_inventory:trash:close', function()
    local src = source
    cleanupTrashStash(src)
end)

-- ─────────────────────────────────────────────────────────────
-- NETTOYAGE À LA DÉCONNEXION
-- Évite les stashes fantômes en mémoire
-- ─────────────────────────────────────────────────────────────

AddEventHandler('playerDropped', function()
    cleanupTrashStash(source)
end)

-- ─────────────────────────────────────────────────────────────
-- SÉCURITÉ : BLOQUER LES MOVES DEPUIS UNE POUBELLE
-- Un joueur ne doit jamais pouvoir récupérer un item de la poubelle.
-- On intercepte aussi les moves DEPUIS un stash poubelle.
-- ─────────────────────────────────────────────────────────────

exports.kt_inventory:AddHook('swapItems', function(payload)
    local fromInv = payload.fromInventory
    if not fromInv or fromInv.type ~= 'stash' then return end
    if not isTrashStash(fromInv.id) then return end

    -- Bloquer tout mouvement depuis une poubelle vers n'importe où
    lib.print.warn(('[kt_inventory:trash] Tentative de récupération depuis poubelle bloquée: src=%d stash=%s'):format(
        payload.source or -1, fromInv.id))
    return false
end)

lib.print.info('^2[kt_inventory] Système poubelle chargé (/poubelle)^0')