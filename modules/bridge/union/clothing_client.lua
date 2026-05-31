-- modules/bridge/union/clothing_client.lua
-- Gestion des callbacks NUI vêtements + zoom anatomique sur sélection slot

if not lib then return end

-- Cache local pour éviter N appels exports par slot
local ItemsCache = nil
local function getItems()
    if not ItemsCache then
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

-- Zoom vers une zone anatomique quand l'utilisateur clique un slot clothing
RegisterNUICallback('pedPreviewZoomCategory', function(data, cb)
    cb({ ok = true })
    if data.category then
        Preview.ZoomToCategory(data.category)
    end
end)

-- Équiper un vêtement : refresh + zoom + son
RegisterNUICallback('equipClothing', function(data, cb)
    cb({ ok = true })
    -- Rafraîchir le ped après équipement
    SetTimeout(120, function()
        if Preview.active then Preview.Refresh() end
    end)
    -- Zoom vers la zone concernée
    if data.category then
        SetTimeout(200, function()
            if Preview.active then Preview.ZoomToCategory(data.category) end
        end)
    end
    -- Son d'équipement
    PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true)
end)

-- Retirer un vêtement
RegisterNUICallback('removeClothing', function(data, cb)
    cb({ ok = true })
    SetTimeout(120, function()
        if Preview.active then Preview.Refresh() end
    end)
    PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- EVENTS — Sync tenue & inventaire
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Refresh automatique dès qu'un vêtement change dans l'inventaire
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
                return
            end
        end
    end
end)

-- Fermeture inventaire → détruire preview
AddEventHandler('kt_inventory:closeInventory', function()
    if Preview and Preview.active then
        Preview.Destroy()
    end
end)

AddEventHandler('kt_inventory:closedInventory', function()
    if Preview and Preview.active then
        Preview.Destroy()
    end
end)

lib.print.info('^2[kt_inventory] Clothing client chargé^0')
