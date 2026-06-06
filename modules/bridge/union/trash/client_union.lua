-- modules/bridge/union/trash/client_union.lua
-- Côté client du système de poubelle
--
-- Responsabilités :
--   - Recevoir la confirmation de destruction → notification visuelle
--   - Recevoir le signal de slot vidé → forcer le refresh de l'UI kt_inventory
--   - Détecter la fermeture de l'inventaire → prévenir le serveur de nettoyer

if not lib then return end

-- ─────────────────────────────────────────────────────────────
-- ÉTAT LOCAL
-- ─────────────────────────────────────────────────────────────

-- Identifiant du stash poubelle actuellement ouvert pour ce joueur
-- Format : "trash_<source>" ou nil si aucun
local currentTrashId = nil

-- ─────────────────────────────────────────────────────────────
-- NOTIFICATION
-- Utilise lib.notify (ox_lib) — adapter si tu utilises autre chose
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('kt_inventory:trash:notify', function(msg, nType)
    -- ox_lib notify
    lib.notify({
        title       = '🗑️ Poubelle',
        description = msg,
        type        = nType or 'inform',
        duration    = 4000,
        position    = 'top-right',
    })
end)

-- ─────────────────────────────────────────────────────────────
-- SLOT VIDÉ → REFRESH UI
-- Quand le serveur a détruit l'item, il envoie cet event pour
-- forcer kt_inventory à rafraîchir l'affichage du stash (slot → vide).
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('kt_inventory:trash:cleared', function(stashId)
    -- Mémoriser quel stash est ouvert
    currentTrashId = stashId

    -- Demander à kt_inventory de rafraîchir l'UI
    -- kt_inventory expose un event client pour ça
    TriggerEvent('kt_inventory:refreshInventory')

    -- Fermeture automatique après un court délai
    -- (laisser le temps à l'animation de fin pour se jouer)
    SetTimeout(800, function()
        closeTrash()
    end)
end)

-- ─────────────────────────────────────────────────────────────
-- FERMETURE DE LA POUBELLE
-- ─────────────────────────────────────────────────────────────

function closeTrash()
    if not currentTrashId then return end

    -- Fermer l'inventaire kt_inventory
    TriggerEvent('kt_inventory:closeInventory')

    -- Prévenir le serveur de nettoyer le stash
    TriggerServerEvent('kt_inventory:trash:close')

    currentTrashId = nil
end

-- ─────────────────────────────────────────────────────────────
-- DÉTECTION FERMETURE MANUELLE
-- Si le joueur ferme l'inventaire lui-même (touche E ou Échap),
-- on prévient le serveur de nettoyer le stash.
-- ─────────────────────────────────────────────────────────────

AddEventHandler('kt_inventory:closeInventory', function()
    if not currentTrashId then return end

    -- Nettoyer l'état local
    local id       = currentTrashId
    currentTrashId = nil

    -- Prévenir le serveur
    TriggerServerEvent('kt_inventory:trash:close')

    lib.print.info(('[kt_inventory:trash] Poubelle fermée: %s'):format(id))
end)

-- ─────────────────────────────────────────────────────────────
-- COMMANDE CLIENT /poubelle
-- Relaie vers le serveur qui crée le stash et l'ouvre
-- ─────────────────────────────────────────────────────────────

RegisterCommand('poubelle', function()
    -- Vérification légère côté client : inventaire déjà ouvert ?
    if currentTrashId then
        lib.notify({
            title       = '🗑️ Poubelle',
            description = 'Votre poubelle est déjà ouverte.',
            type        = 'error',
            duration    = 3000,
        })
        return
    end

    -- Mémoriser immédiatement pour éviter le double-clic
    -- (le vrai stashId sera confirmé par le serveur via kt_inventory:trash:cleared)
    -- On utilise un placeholder le temps que le serveur réponde
    currentTrashId = ('trash_%d'):format(GetPlayerServerId(PlayerId()))

    -- Le serveur fait RegisterStash + OpenInventory
    -- kt_inventory gère l'ouverture de l'UI automatiquement
    TriggerServerEvent('kt_inventory:trash:open')
end, false)

lib.print.info('^2[kt_inventory] Système poubelle client chargé^0')