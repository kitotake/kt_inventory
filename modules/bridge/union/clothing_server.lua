-- ============================================================
-- modules/bridge/union/clothing_server.lua
-- FIX : lib.callback.register('kt_inventory:removeClothingItem')
--       Retire l'item du slot inventaire après équipement via drag-and-drop
-- ============================================================

-- ─── Callback : retirer un slot clothing de l'inventaire (déséquiper) ───────
-- Utilisé par removeClothing NUI (déséquiper depuis le ClothingSlot)
lib.callback.register('kt_inventory:removeClothingItem', function(source, invSlot)
    invSlot = tonumber(invSlot)

    if not invSlot then
        return false
    end

    local inv = Inventory(source)

    if not inv then
        return false
    end

    local slotData = inv.items[invSlot]

    if not slotData then
        return false
    end

    local itemName = slotData.name
    local itemDef = Items(itemName)

    if itemDef and itemDef.category and itemDef.category ~= 'clothing' then
        return false
    end

    return Inventory.RemoveItem(inv, itemName, 1, nil, invSlot)
end)

-- ─── Callback : retirer l'item par numéro de slot après drag-and-drop ────────
-- ✅ FIX PRINCIPAL
-- Appelé par clothing_client.lua → RegisterNUICallback('equipClothing') quand
-- le joueur fait glisser un item depuis l'inventaire vers un ClothingSlot.
-- On retire l'item du slot source pour que le déplacement soit réel (pas une copie).
lib.callback.register('kt_inventory:removeClothingItem', function(source, invSlot)
    invSlot = tonumber(invSlot)
    if not invSlot or invSlot < 1 then
        lib.print.warn(('[clothing] removeClothingItem: slot invalide reçu depuis src=%d'):format(source))
        return false
    end

    local inv = Inventory(source)
    if not inv then
        lib.print.warn(('[clothing] removeClothingItem: inventaire introuvable pour src=%d'):format(source))
        return false
    end

    local slotData = inv.items[invSlot]

    -- Vérification de sécurité : le slot doit contenir un item clothing
    if not slotData or not slotData.name then
        lib.print.warn(('[clothing] removeClothingItem: slot %d vide pour src=%d'):format(invSlot, source))
        return false
    end

    -- Sécurité supplémentaire : vérifier que c'est bien un item de type clothing
    -- (évite qu'un exploit retire n'importe quel item)
    local itemName = slotData.name
    local Items    = getItems()
    local itemDef  = Items and Items(itemName)

    if itemDef and itemDef.category and itemDef.category ~= 'clothing' then
        lib.print.warn(('[clothing] removeClothingItem: %s n\'est pas un clothing (category=%s) src=%d'):format(
            itemName, tostring(itemDef.category), source))
        return false
    end

    local removed = Inventory.RemoveItem(inv, itemName, 1, nil, invSlot)

    if removed then
        lib.print.info(('[clothing] removeClothingItem: %s (slot %d) retiré de src=%d'):format(itemName, invSlot, source))
        return true
    else
        lib.print.warn(('[clothing] removeClothingItem: échec suppression %s slot %d src=%d'):format(itemName, invSlot, source))
        return false
    end
end)

lib.print.info('^2[kt_inventory] module/union/clothing_server pour vêtements chargé^0')