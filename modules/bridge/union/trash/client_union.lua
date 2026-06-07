-- modules/bridge/union/trash/client_union.lua  v2
-- Corrections v2 :
--   [FIX-CMD]    RegisterCommand supprimé côté client — la commande est enregistrée
--                UNIQUEMENT côté serveur. Le client utilise un keybind ou un menu.
--                Raison : si les deux côtés enregistrent 'poubelle', FiveM garde
--                le dernier enregistré (serveur) et le client ne se déclenche jamais.
--   [FIX-LOOP]   closeTrash() ne déclenche plus kt_inventory:closeInventory
--                pour éviter le re-trigger du handler de fermeture (double cleanup).
--   [FIX-STATE]  currentTrashId mis à nil AVANT TriggerEvent pour éviter les
--                boucles dans le handler kt_inventory:closeInventory.

if not lib then return end

-- ─────────────────────────────────────────────────────────────
-- ÉTAT LOCAL
-- ─────────────────────────────────────────────────────────────

local currentTrashId = nil
local _closing       = false   -- guard anti-boucle fermeture

-- ─────────────────────────────────────────────────────────────
-- NOTIFICATION
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('kt_inventory:trash:notify', function(msg, nType)
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
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('kt_inventory:trash:cleared', function(stashId)
    currentTrashId = stashId

    -- Fermeture automatique avec délai pour laisser l'animation se jouer
    SetTimeout(800, function()
        closeTrash()
    end)
end)

-- ─────────────────────────────────────────────────────────────
-- FERMETURE DE LA POUBELLE
-- [FIX-LOOP] Ne déclenche PAS kt_inventory:closeInventory ici —
--            c'est kt_inventory lui-même qui l'émet quand il ferme.
--            On prévient juste le serveur de nettoyer.
-- ─────────────────────────────────────────────────────────────

function closeTrash()
    if not currentTrashId or _closing then return end
    _closing = true

    local id       = currentTrashId
    currentTrashId = nil  -- [FIX-STATE] nil avant tout TriggerEvent

    TriggerServerEvent('kt_inventory:trash:close')

    lib.print.info(('[kt_inventory:trash] Poubelle fermée: %s'):format(id))

    SetTimeout(100, function() _closing = false end)
end

-- ─────────────────────────────────────────────────────────────
-- DÉTECTION FERMETURE MANUELLE
-- kt_inventory émet cet event quand le joueur ferme l'inventaire.
-- On prévient le serveur de nettoyer le stash.
-- ─────────────────────────────────────────────────────────────

AddEventHandler('kt_inventory:closeInventory', function()
    -- [FIX-LOOP] Guard : si closeTrash() est en cours, ne pas re-enter
    if _closing or not currentTrashId then return end
    closeTrash()
end)

-- ─────────────────────────────────────────────────────────────
-- OUVERTURE — déclenchée par le serveur après RegisterStash réussi
-- Le serveur envoie cet event pour confirmer que le stash est prêt.
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('kt_inventory:trash:opened', function(stashId)
    currentTrashId = stashId
    lib.print.info(('[kt_inventory:trash] Poubelle ouverte: %s'):format(stashId))
end)

-- ─────────────────────────────────────────────────────────────
-- [FIX-CMD] PAS de RegisterCommand ici.
-- La commande /poubelle est enregistrée uniquement côté SERVEUR.
-- Le serveur appelle OpenInventory directement → kt_inventory ouvre l'UI.
--
-- Si tu veux un raccourci clavier côté client, utilise :
--   RegisterKeyMapping('poubelle', 'Ouvrir la poubelle', 'keyboard', 'F7')
--   RegisterCommand('poubelle', function() TriggerServerEvent('kt_inventory:trash:open') end, false)
-- Mais dans ce cas, RETIRE RegisterCommand du serveur pour ce nom.
-- ─────────────────────────────────────────────────────────────

lib.print.info('^2[kt_inventory] Système poubelle client v2 chargé^0')