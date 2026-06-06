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

-- Lazy loading pour éviter les dépendances circulaires
-- Les modules sont require() seulement quand nécessaire
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
    local inv = getInventory()(stashId)
    if inv then
        -- Vider tous les slots restants
        for slotIndex, slotData in pairs(inv.items or {}) do
            if slotData and slotData.name then
                local itemLabel = (getItems()(slotData.name) or {}).label or slotData.name
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

-- Hook supprimé : AddHook n'existe pas comme export dans kt_inventory
-- Les vérifications de sécurité sont faites via openTrashStash()

-- ─────────────────────────────────────────────────────────────

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

    local inv = getInventory()(src)
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
    local inv = getInventory()(src)
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

-- Hook supprimé : AddHook n'existe pas comme export dans kt_inventory
-- À implémenter : trouver l'API correcte de kt_inventory pour les hooks

lib.print.info('^2[kt_inventory] Système poubelle chargé (/poubelle)^0')