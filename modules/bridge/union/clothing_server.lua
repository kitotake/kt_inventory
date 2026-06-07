-- ============================================================
-- modules/bridge/union/clothing_server.lua
-- Callback pour retirer un vêtement + remettre l'item dans l'inventaire
-- ============================================================

-- VALID_CLOTHING_SLOTS
local VALID_CLOTHING_SLOTS = {
    hat = true, glasses = true, ears = true, watch = true, bracelet = true,
    mask = true, gloves = true, pants = true, bag = true, shoes = true,
    chain = true, undershirt = true, armor = true, top = true,
}

-- Attendre que les fonctions principales soient chargées
local getInventory = getInventory or function() return nil end
local loadOutfit   = loadOutfit or function() return {} end
local saveOutfit   = saveOutfit or function() end

lib.callback.register('kt_inventory:removeClothingSlot', function(source, clothingSlot)
    if type(clothingSlot) ~= 'string' then 
        lib.print.warn(('[kt_inventory:clothing] Slot invalide reçu par %s'):format(source))
        return false 
    end

    lib.print.info(('[kt_inventory:clothing] Demande de retrait du slot %s par le joueur %s'):format(
        clothingSlot, source))

    if not VALID_CLOTHING_SLOTS[clothingSlot] then
        lib.print.warn(('[kt_inventory:clothing] Slot %s non valide'):format(clothingSlot))
        return false
    end

    local inv = getInventory(source)
    if not inv then 
        lib.print.warn(('[kt_inventory:clothing] Inventaire introuvable pour %s'):format(source))
        return false 
    end

    local uniqueId = inv.owner
    local outfit = loadOutfit(uniqueId) or {}

    -- Récupérer l'item avant suppression
    local slotData = outfit[clothingSlot]
    local itemName = slotData and slotData.name

    -- Supprimer du outfit
    outfit[clothingSlot] = nil
    saveOutfit(uniqueId, outfit)

    TriggerClientEvent('kt_inventory:outfitUpdated', source, outfit)

    -- Remettre l'item dans l'inventaire
    if itemName then
        local Items = getItems and getItems() or {}
        local itemDef = Items[itemName] or Items(string.lower(itemName))

        if itemDef then
            local success = Inventory and Inventory.AddItem and Inventory.AddItem(inv, itemDef, 1, {}) 

            if success then
                lib.print.info(('[kt_inventory:clothing] %s remis dans l\'inventaire de %s'):format(itemName, source))
            else
                lib.print.warn(('[kt_inventory:clothing] Impossible de remettre %s pour %s (inventaire plein ?)'):format(itemName, source))
            end
        else
            lib.print.warn(('[kt_inventory:clothing] Item %s non trouvé dans la liste des items'):format(itemName))
        end
    end

    return true
end)

lib.print.info('^2[kt_inventory] module/union/clothing_server pour vêtements chargé^0')