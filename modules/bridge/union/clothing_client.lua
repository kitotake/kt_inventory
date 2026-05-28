-- modules/bridge/union/clothing_client.lua

if not lib then return end

-- Cache local pour éviter d'appeler l'export à chaque slot changé
-- (l'export était appelé N fois en cas de swap multi-items)
local ItemsCache = nil
local function getItems()
    if not ItemsCache then
        -- On tente de récupérer la table Items exposée par kt_inventory
        local ok, result = pcall(function()
            return exports.kt_inventory:getItemsTable()
        end)
        if ok and result then
            ItemsCache = result
        end
    end
    return ItemsCache
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CALLBACKS NUI — Preview ped
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

RegisterNUICallback('pedPreviewRotateVertical', function(data, cb)
    cb({ ok = true })
    if data.deltaY then Preview.RotateVertical(data.deltaY) end
end)

RegisterNUICallback('pedPreviewZoom', function(data, cb)
    cb({ ok = true })
    if type(data.delta) == 'number' then
        Preview.Zoom(data.delta)
    elseif type(data.face) == 'boolean' then
        Preview.SetZoom(data.face)
    end
end)

RegisterNUICallback('pedPreviewResetCam', function(_, cb)
    cb({ ok = true })
    Preview.ResetCam()
end)

RegisterNUICallback('pedPreviewAnim', function(data, cb)
    cb({ ok = true })
    if data.dict and data.clip then
        Preview.PlayAnim(data.dict, data.clip)
    end
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EVENTS — Sync tenue & inventaire
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Refresh automatique dès qu'un vêtement change dans l'inventaire.
-- On utilise le cache local pour éviter N appels exports par slot.
AddEventHandler('kt_inventory:updateInventory', function(changes)
    if not Preview or not Preview.active then return end

    local items = getItems()

    for _, slotData in pairs(changes) do
        if type(slotData) == 'table' and slotData.name then
            local itemDef = items and items[slotData.name]
                or exports.kt_inventory:Items(slotData.name)

            if itemDef and (itemDef.category or itemDef.clothingSlot) then
                SetTimeout(150, function()
                    if Preview.active then Preview.Refresh() end
                end)
                -- Un seul refresh suffit même si plusieurs clothing slots changent
                return
            end
        end
    end
end)

-- FIX : l'event émis dans client.lua est 'kt_inventory:closeInventory' (via NUI callback 'exit')
-- et non 'kt_inventory:closedInventory'. On écoute les deux pour la rétrocompatibilité.
AddEventHandler('kt_inventory:closeInventory', function()
    if Preview and Preview.active then
        Preview.Destroy()
    end
end)

-- Sécurité : si le NUI envoie l'ancien event (au cas où d'autres scripts l'émettent)
AddEventHandler('kt_inventory:closedInventory', function()
    if Preview and Preview.active then
        Preview.Destroy()
    end
end)

lib.print.info('^2[kt_inventory] Clothing client chargé^0')