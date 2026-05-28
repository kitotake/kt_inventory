-- modules/bridge/union/clothing_client.lua

if not lib then return end

RegisterNUICallback('pedPreviewInit', function(_, cb)
    cb({ ok = true })
    Preview.Create(true)
end)

RegisterNUICallback('pedPreviewDestroy', function(_, cb)
    cb({ ok = true })
    Preview.Destroy()
end)

RegisterNUICallback('pedPreviewRotate', function(data, cb)
    cb({ ok = true })
    Preview.Rotate(data.delta)
end)

RegisterNUICallback('pedPreviewZoom', function(data, cb)
    cb({ ok = true })
    Preview.SetZoom(data.face)
end)

RegisterNUICallback('pedPreviewAnim', function(data, cb)
    cb({ ok = true })
    if data.dict and data.clip then
        Preview.PlayAnim(data.dict, data.clip)
    end
end)

-- Refresh automatique dès qu'un vêtement change dans l'inventaire
AddEventHandler('kt_inventory:updateInventory', function(changes)
    if not Preview or not Preview.active then return end

    for _, slotData in pairs(changes) do
        if type(slotData) == 'table' and slotData.name then
            local itemDef = exports.kt_inventory:Items(slotData.name)
            if itemDef and (itemDef.category or itemDef.clothingSlot) then
                -- ClonePedToTarget est quasi instantané, pas besoin de délai long
                SetTimeout(150, function()
                    if Preview.active then Preview.Refresh() end
                end)
                return
            end
        end
    end
end)

AddEventHandler('kt_inventory:closedInventory', function()
    Preview.Destroy()
end)

lib.print.info('^2[kt_inventory] Clothing client chargé^0')