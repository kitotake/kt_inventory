-- ============================================================
-- modules/bridge/union/clothing_server.lua
-- FIX : deux callbacks distincts :
--   • kt_inventory:removeClothingSlot  → déséquiper depuis le ClothingSlot (NUI removeClothing)
--   • kt_inventory:removeClothingItem  → retirer l'item après drag-and-drop  (NUI equipClothing)
-- ============================================================

-- ─── Callback : déséquiper un vêtement depuis le ClothingSlot ───────────────
-- Utilisé par removeClothing NUI (clic « déséquiper » dans l'interface)
lib.callback.register('kt_inventory:removeClothingSlot', function(source, clothingSlot)
    if type(clothingSlot) ~= 'string' or clothingSlot == '' then
        lib.print.warn(('[clothing] removeClothingSlot: slot invalide reçu depuis src=%d'):format(source))
        return false
    end

    local inv = Inventory(source)
    if not inv then
        lib.print.warn(('[clothing] removeClothingSlot: inventaire introuvable pour src=%d'):format(source))
        return false
    end

    -- Cherche dans l'inventaire un item portant la catégorie clothing correspondante
    for slotIndex, slotData in pairs(inv.items) do
        if slotData and slotData.name then
            local itemDef = Items(slotData.name)
            if itemDef and itemDef.category == 'clothing' and itemDef.clothingSlot == clothingSlot then
                local removed = Inventory.RemoveItem(inv, slotData.name, 1, nil, slotIndex)
                if removed then
                    lib.print.info(('[clothing] removeClothingSlot: %s (slot %d) retiré de src=%d'):format(
                        slotData.name, slotIndex, source))
                    return true
                end
            end
        end
    end

    -- Aucun item trouvé pour ce clothingSlot : on considère ça OK (il était déjà absent)
    lib.print.info(('[clothing] removeClothingSlot: aucun item trouvé pour clothingSlot=%s src=%d'):format(clothingSlot, source))
    return true
end)

-- ─── Callback : retirer l'item par numéro de slot après drag-and-drop ────────
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
    local itemDef  = Items(itemName)

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