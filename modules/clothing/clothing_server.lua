-- ============================================================
-- modules/bridge/union/clothing_server.lua
-- Version v4 — prints détaillés + diagnostic metadata removeClothingSlot
-- ============================================================

local kt_inventory = exports[shared.resource]

-- ─── removeClothingSlot ─────────────────────────────────────────────────────
-- Appelé quand le joueur clique « déséquiper » dans l'interface ClothingSlot.
-- Cherche l'item portant la metadata clothingSlot et le supprime de l'inventaire.
--
-- ⚠️  DIAGNOSTIC : si ce callback affiche toujours "aucun item trouvé",
--     c'est que tes items n'ont PAS de metadata.clothingSlot mais peut-être
--     metadata.category ou autre chose. Active les prints DEBUG ci-dessous
--     pour voir la structure réelle des metadata.
lib.callback.register('kt_inventory:removeClothingSlot', function(source, clothingSlot)
    lib.print.info(('[clothing] [SERVER] >>> removeClothingSlot | src=%d clothingSlot=%s'):format(source, tostring(clothingSlot)))

    if type(clothingSlot) ~= 'string' or clothingSlot == '' then
        lib.print.warn(('[clothing] [SERVER] removeClothingSlot: clothingSlot invalide src=%d'):format(source))
        return false
    end

    -- Recherche par metadata.clothingSlot
    local results = kt_inventory:Search(source, 'slots', nil, { clothingSlot = clothingSlot })

    if not results or next(results) == nil then
        lib.print.info(('[clothing] [SERVER] removeClothingSlot: aucun item avec metadata.clothingSlot=%s pour src=%d'):format(clothingSlot, source))
        lib.print.info(('[clothing] [SERVER] ⚠️  Si ce log apparaît toujours, tes items n\'ont peut-être pas de metadata.clothingSlot — voir DEBUG ci-dessous'):format())

        -- ── DEBUG : dump du contenu de l'inventaire pour diagnostic ──────────
        -- Décommente ce bloc pour voir les metadata réelles de tes items clothing
        
        local allSlots = kt_inventory:GetInventory(source)
        if allSlots and allSlots.items then
            for i, item in pairs(allSlots.items) do
                if item and item.name and item.name:find('clothing') then
                    lib.print.info(('[clothing] [DEBUG] slot=%d name=%s metadata=%s'):format(
                        i, item.name, json.encode(item.metadata or {})))
                end
            end
        end
        

        return true  -- On retourne true : visuellement ok, mais l'item reste en inventaire
    end

    for slotIndex, slotData in pairs(results) do
        lib.print.info(('[clothing] [SERVER] removeClothingSlot: trouvé %s en slot %d — suppression...'):format(slotData.name, slotIndex))
        local removed = kt_inventory:RemoveItem(source, slotData.name, 1, nil, slotIndex)
        if removed then
            lib.print.info(('[clothing] [SERVER] <<< removeClothingSlot: %s (slot %d) supprimé ✓ src=%d'):format(
                slotData.name, slotIndex, source))
            return true
        else
            lib.print.warn(('[clothing] [SERVER] <<< removeClothingSlot: échec suppression %s slot %d src=%d'):format(
                slotData.name, slotIndex, source))
            return false
        end
    end

    return false
end)

-- ─── removeClothingItem ──────────────────────────────────────────────────────
-- Appelé après drag-and-drop d'un item vers un ClothingSlot.
-- Retire l'item du slot source pour que le déplacement soit réel.
lib.callback.register('kt_inventory:removeClothingItem', function(source, invSlot)
    invSlot = tonumber(invSlot)
    lib.print.info(('[clothing] [SERVER] >>> removeClothingItem | src=%d invSlot=%s'):format(source, tostring(invSlot)))

    if not invSlot or invSlot < 1 then
        lib.print.warn(('[clothing] [SERVER] removeClothingItem: invSlot invalide src=%d'):format(source))
        return false
    end

    local slotData = kt_inventory:GetSlot(source, invSlot)

    if not slotData or not slotData.name then
        lib.print.info(('[clothing] [SERVER] removeClothingItem: slot %d déjà vide src=%d — doublon ignoré'):format(invSlot, source))
        return true
    end

    local itemName = slotData.name
    local meta     = slotData.metadata or {}

    lib.print.info(('[clothing] [SERVER] removeClothingItem: slot %d contient "%s" | metadata=%s'):format(
        invSlot, itemName, json.encode(meta)))

    -- Sécurité : vérifier que c'est bien un item clothing
    if meta.category and meta.category ~= 'clothing' then
        lib.print.warn(('[clothing] [SERVER] removeClothingItem: "%s" refusé — category=%s src=%d'):format(
            itemName, tostring(meta.category), source))
        return false
    end

    local removed = kt_inventory:RemoveItem(source, itemName, 1, nil, invSlot)

    if removed then
        lib.print.info(('[clothing] [SERVER] <<< removeClothingItem: "%s" (slot %d) supprimé ✓ src=%d'):format(itemName, invSlot, source))
        return true
    else
        lib.print.warn(('[clothing] [SERVER] <<< removeClothingItem: échec suppression "%s" slot %d src=%d'):format(itemName, invSlot, source))
        return false
    end
end)

lib.print.info('^2[kt_inventory] clothing_server v4 chargé^0')