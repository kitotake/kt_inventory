-- ============================================================
-- modules/clothing/clothing_server.lua
-- v5 — Les vêtements restent dans l'inventaire.
--      Aucun RemoveItem / AddItem / Search lors de l'équipement
--      ou du déséquipement. Seul applyClothing est conservé
--      pour permettre au serveur de déclencher l'application
--      visuelle sur le ped si nécessaire (optionnel).
-- ============================================================

-- ─── SUPPRIMÉS ───────────────────────────────────────────────────────────────
--
--  ✗  lib.callback.register('kt_inventory:removeClothingSlot', ...)
--     Raison : l'item n'est plus retiré lors de l'équipement,
--              donc il n'y a rien à remettre lors du déséquipement.
--
--  ✗  lib.callback.register('kt_inventory:removeClothingItem', ...)
--     Raison : l'item reste dans l'inventaire lors du drag & drop
--              vers un ClothingSlot. Aucune suppression côté serveur.
--
-- ─────────────────────────────────────────────────────────────────────────────

-- ─── applyClothing (optionnel — déclenché par le client si besoin) ────────────
-- Ce callback permet au serveur de notifier d'autres systèmes
-- qu'un vêtement a été équipé (logs, anti-cheat, etc.)
-- Il ne modifie PAS l'inventaire.

lib.callback.register('kt_inventory:applyClothing', function(source, data)
    -- data = { name, clothingSlot, drawable, texture, slotType }
    -- Ici on peut logger, notifier un anti-cheat, etc.
    -- On ne touche PAS à l'inventaire.

    if type(data) ~= 'table' or not data.name or not data.clothingSlot then
        return false
    end

    lib.print.info(('[clothing] [SERVER] applyClothing | src=%d item=%s slot=%s draw=%s tex=%s'):format(
        source,
        tostring(data.name),
        tostring(data.clothingSlot),
        tostring(data.drawable),
        tostring(data.texture)
    ))

    -- Exemple : event pour d'autres ressources
    -- TriggerEvent('clothing:onEquip', source, data)

    return true
end)

-- ─── removeClothing (optionnel — log serveur uniquement) ─────────────────────
lib.callback.register('kt_inventory:logClothingRemoved', function(source, clothingSlot)
    if type(clothingSlot) ~= 'string' then return false end

    lib.print.info(('[clothing] [SERVER] logClothingRemoved | src=%d slot=%s'):format(
        source, clothingSlot
    ))

    return true
end)

lib.print.info('^2[kt_inventory] clothing_server v5 chargé (items toujours en inventaire)^0')