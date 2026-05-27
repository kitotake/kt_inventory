-- modules/bridge/union/clothing_client.lua

if not lib then return end

RegisterNUICallback('pedPreviewInit', function(_, cb)
    cb({ ok = true })

    Preview.Create()
end)

RegisterNUICallback('pedPreviewDestroy', function(_, cb)
    cb({ ok = true })

    Preview.Destroy()
end)

RegisterNUICallback('pedPreviewRotate', function(data, cb)
    cb({ ok = true })

    Preview.Rotate(data.delta)
end)

AddEventHandler('kt_inventory:closedInventory', function()
    Preview.Destroy()
end)

lib.print.info('^2[kt_inventory] Clothing client chargé^0')