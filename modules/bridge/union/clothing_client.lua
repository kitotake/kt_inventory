-- modules/bridge/union/clothing_client.lua  v4
-- Corrections v4 :
--   [FIX-NUI-1] loadAndApplyOutfit() envoie maintenant setupClothing au NUI React
--               → les slots clothing dans l'UI sont remplis dès l'ouverture
--   [FIX-NUI-2] equipClothing : envoie clothingEquipped au NUI après succès
--   [FIX-NUI-3] removeClothing : envoie clothingRemoved au NUI après succès
--   [FIX-NUI-4] outfitUpdated NetEvent : envoie setupClothing au NUI pour resync
--   [FIX-NUI-5] equipOutfit : envoie outfitEquipped au NUI après succès
--   [FIX-B1]    require 'modules.items.client' remplacé par exports.kt_inventory:Items()
--               → require() dans un NUI callback peut retourner nil si module non prêt

if not lib then return end

-- ─────────────────────────────────────────────────────────────
-- CONSTANTES
-- ─────────────────────────────────────────────────────────────

local SLOT_MAP = {
    hat        = { type = 'prop',      slot = 0  },
    mask       = { type = 'component', slot = 1  },
    glasses    = { type = 'prop',      slot = 1  },
    top        = { type = 'component', slot = 11 },
    undershirt = { type = 'component', slot = 8  },
    pants      = { type = 'component', slot = 4  },
    shoes      = { type = 'component', slot = 6  },
    bag        = { type = 'component', slot = 5  },
    armor      = { type = 'component', slot = 9  },
    watch      = { type = 'prop',      slot = 6  },
    bracelet   = { type = 'prop',      slot = 7  },
    chain      = { type = 'component', slot = 7  },
    gloves     = { type = 'component', slot = 3  },
}

-- ─────────────────────────────────────────────────────────────
-- APPLICATION NATIVE GTA
-- ─────────────────────────────────────────────────────────────

---@param ped number
---@param clothingSlot string
---@param data { drawable: number, texture: number, palette?: number, dlc?: number }
---@return boolean
local function applyClothingSlot(ped, clothingSlot, data)
    if not ped or not DoesEntityExist(ped) then return false end
    local slotDef = SLOT_MAP[clothingSlot]
    if not slotDef then return false end

    local drawable = data.drawable or 0
    local texture  = data.texture  or 0
    local palette  = data.palette  or 0

    if slotDef.type == 'component' then
        if data.dlc then
            SetPedDlcClothes(ped, data.dlc, slotDef.slot, drawable, texture, palette)
        else
            SetPedComponentVariation(ped, slotDef.slot, drawable, texture, palette)
        end
    elseif slotDef.type == 'prop' then
        if drawable < 0 then
            ClearPedProp(ped, slotDef.slot)
        else
            if data.dlc then
                SetPedDlcProp(ped, data.dlc, slotDef.slot, drawable, texture)
            else
                SetPedPropIndex(ped, slotDef.slot, drawable, texture, true)
            end
        end
    end
    return true
end

---@param ped number
---@param outfit table
local function applyOutfit(ped, outfit)
    if not ped or not DoesEntityExist(ped) or not outfit then return end
    for slotName, slotData in pairs(outfit) do
        applyClothingSlot(ped, slotName, slotData)
    end
end

-- ─────────────────────────────────────────────────────────────
-- [FIX-NUI-1] SYNC NUI REACT — SETUP CLOTHING
--
-- Convertit l'état EquippedClothing reçu du serveur en message NUI
-- pour mettre à jour le state Redux clothing dans React.
-- equipped = { [slotName] = { name, label, itemType } }
-- ─────────────────────────────────────────────────────────────

---@param equipped table|nil  EquippedClothing du serveur
local function sendSetupClothingNUI(equipped)
    if not equipped then return end
    SendNUIMessage({
        action = 'setupClothing',
        data   = equipped,
    })
end

-- ─────────────────────────────────────────────────────────────
-- CHARGEMENT INITIAL AU SPAWN
-- ─────────────────────────────────────────────────────────────

local function loadAndApplyOutfit(delay)
    SetTimeout(delay or 500, function()
        -- [FIX-NUI-1] getOutfit retourne maintenant (outfit, equipped)
        lib.callback('kt_inventory:getOutfit', false, function(outfit, equipped)
            local ped = cache.ped
            if not ped or not DoesEntityExist(ped) then return end

            if outfit then
                applyOutfit(ped, outfit)
                lib.print.info('[kt_inventory:clothing] Tenue appliquée au ped')
            end

            -- [FIX-NUI-1] Sync le state Redux clothing dans React
            if equipped then
                sendSetupClothingNUI(equipped)
                lib.print.info('[kt_inventory:clothing] State clothing envoyé au NUI')
            end
        end)
    end)
end

RegisterNetEvent('union:player:spawned', function()
    loadAndApplyOutfit(600)
end)

lib.onCache('ped', function(ped)
    if not ped or not DoesEntityExist(ped) then return end
    SetTimeout(200, function()
        if not DoesEntityExist(ped) then return end
        lib.callback('kt_inventory:getOutfit', false, function(outfit, equipped)
            if outfit and DoesEntityExist(ped) then
                applyOutfit(ped, outfit)
            end
            if equipped then
                sendSetupClothingNUI(equipped)
            end
        end)
    end)
end)

-- ─────────────────────────────────────────────────────────────
-- MISE À JOUR TENUE DEPUIS SERVEUR
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('kt_inventory:outfitUpdated', function(outfit)
    if not outfit then return end
    local ped = cache.ped
    if not ped or not DoesEntityExist(ped) then return end

    applyOutfit(ped, outfit)

    -- [FIX-NUI-4] Reconstruire et envoyer l'état Redux depuis l'outfit mis à jour
    -- L'outfit v4 contient name+label par slot → on peut reconstruire EquippedClothing
    local equipped = {}
    local hasAny   = false
    for slotName, slotData in pairs(outfit) do
        if slotData.name then
            equipped[slotName] = {
                name     = slotData.name,
                label    = slotData.label or slotName,
                itemType = 'clothing',
            }
            hasAny = true
        end
    end

    if hasAny then
        sendSetupClothingNUI(equipped)
    end

    if Preview and Preview.active then
        SetTimeout(100, function()
            if Preview.active then Preview.Refresh() end
        end)
    end
end)

-- ─────────────────────────────────────────────────────────────
-- CALLBACKS NUI — Preview ped
-- ─────────────────────────────────────────────────────────────

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
    if type(data.delta) == 'number' then Preview.Rotate(data.delta) end
end)

RegisterNUICallback('pedPreviewRotateVertical', function(data, cb)
    cb({ ok = true })
    if type(data.deltaY) == 'number' then Preview.RotateVertical(data.deltaY) end
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
    if type(data.dict) == 'string' and type(data.clip) == 'string' then
        Preview.PlayAnim(data.dict, data.clip)
    end
end)

RegisterNUICallback('pedPreviewZoomCategory', function(data, cb)
    cb({ ok = true })
    if type(data.category) == 'string' then Preview.ZoomToCategory(data.category) end
end)

-- ─────────────────────────────────────────────────────────────
-- CALLBACKS NUI — Équipement vêtements
-- ─────────────────────────────────────────────────────────────

RegisterNUICallback('equipClothing', function(data, cb)
    if type(data.slot) ~= 'number' then
        return cb({ ok = false, reason = 'invalid_slot' })
    end

    local playerPed = cache.ped
    if not playerPed or not DoesEntityExist(playerPed) then
        return cb({ ok = false, reason = 'ped_unavailable' })
    end

    local slotData = PlayerData.inventory[data.slot]
    if not slotData then
        return cb({ ok = false, reason = 'slot_empty' })
    end

    -- [FIX-B1] Remplace require 'modules.items.client' (peut retourner nil en NUI callback)
    -- par l'export public de kt_inventory, toujours disponible
    local itemDef = exports.kt_inventory:Items(slotData.name)
    if not itemDef or (itemDef.category ~= 'clothing' and itemDef.category ~= 'clothing_tenu') then
        return cb({ ok = false, reason = 'not_clothing' })
    end

    local clothingSlot = itemDef.clothingSlot
    if not clothingSlot and itemDef.category ~= 'clothing_tenu' then
        return cb({ ok = false, reason = 'no_clothing_slot' })
    end

    local slotDef  = SLOT_MAP[clothingSlot or 'top']
    local metadata = slotData.metadata or {}

    if not metadata.drawable then
        if slotDef then
            if slotDef.type == 'component' then
                metadata.drawable = GetPedDrawableVariation(playerPed, slotDef.slot)
                metadata.texture  = GetPedTextureVariation(playerPed, slotDef.slot)
                metadata.palette  = GetPedPaletteVariation(playerPed, slotDef.slot)
            elseif slotDef.type == 'prop' then
                metadata.drawable = GetPedPropIndex(playerPed, slotDef.slot)
                metadata.texture  = GetPedPropTextureIndex(playerPed, slotDef.slot)
            end
        else
            metadata.drawable = 0
            metadata.texture  = 0
            metadata.palette  = 0
        end
    end

    -- [FIX-NUI-2] Le serveur v4 retourne (success, outfit, clothingEquippedPayload)
    lib.callback('kt_inventory:equipClothing', false, function(success, outfit, nuiPayload)
        if not success then
            return cb({ ok = false, reason = tostring(outfit) })
        end

        local ped = cache.ped
        if outfit and type(outfit) == 'table' and ped and DoesEntityExist(ped) then
            applyOutfit(ped, outfit)
        end

        -- [FIX-NUI-2] Informer React qu'un slot clothing est maintenant équipé
        -- → dispatch(equipClothing({ category, item: { name, label, itemType } }))
        if nuiPayload then
            SendNUIMessage({
                action = 'clothingEquipped',
                data   = nuiPayload,
            })
        end

        if Preview and Preview.active then
            SetTimeout(120, function()
                if Preview.active then Preview.Refresh() end
            end)
        end

        PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true)

        if data.category and Preview and Preview.active then
            SetTimeout(200, function()
                if Preview.active then Preview.ZoomToCategory(data.category) end
            end)
        end

        cb({ ok = true })
    end, data.slot, metadata)
end)

-- Équipement tenue complète
RegisterNUICallback('equipOutfit', function(data, cb)
    if type(data.slot) ~= 'number' then
        return cb({ ok = false, reason = 'invalid_slot' })
    end

    -- [FIX-NUI-5] Le serveur v4 retourne (success, outfitData, outfitEquippedPayload)
    lib.callback('kt_inventory:equipOutfit', false, function(success, outfitData, nuiPayload)
        if not success then
            return cb({ ok = false, reason = tostring(outfitData) })
        end

        local ped = cache.ped
        if outfitData and type(outfitData) == 'table' and ped and DoesEntityExist(ped) then
            applyOutfit(ped, outfitData)
        end

        -- [FIX-NUI-5] Informer React de la tenue complète équipée
        -- → dispatch(equipOutfit({ name, label, slots }))
        if nuiPayload then
            SendNUIMessage({
                action = 'outfitEquipped',
                data   = nuiPayload,
            })
        end

        if Preview and Preview.active then
            SetTimeout(120, function()
                if Preview.active then Preview.Refresh() end
            end)
        end

        PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true)
        cb({ ok = true })
    end, data.slot)
end)

-- Retrait d'un slot vêtement
RegisterNUICallback('removeClothing', function(data, cb)
    if type(data.clothingSlot) ~= 'string' then
        return cb({ ok = false, reason = 'invalid_slot' })
    end

    lib.callback('kt_inventory:removeClothingSlot', false, function(success)
        if success then
            local slotDef = SLOT_MAP[data.clothingSlot]
            local ped     = cache.ped
            if slotDef and slotDef.type == 'prop' and ped and DoesEntityExist(ped) then
                ClearPedProp(ped, slotDef.slot)
            end

            -- [FIX-NUI-3] Informer React que le slot est retiré
            -- → dispatch(removeClothing({ category }))
            SendNUIMessage({
                action = 'clothingRemoved',
                data   = { category = data.clothingSlot },
            })

            if Preview and Preview.active then
                SetTimeout(120, function()
                    if Preview.active then Preview.Refresh() end
                end)
            end

            PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        end

        cb({ ok = success })
    end, data.clothingSlot)
end)

-- ─────────────────────────────────────────────────────────────
-- SYNC INVENTAIRE → REFRESH PREVIEW
-- ─────────────────────────────────────────────────────────────

AddEventHandler('kt_inventory:updateInventory', function(changes)
    if not Preview or not Preview.active then return end
    for _, slotData in pairs(changes) do
        if type(slotData) == 'table' and slotData.name then
            local itemDef = exports.kt_inventory:Items(slotData.name)
            if itemDef and (itemDef.category == 'clothing' or itemDef.category == 'clothing_tenu') then
                SetTimeout(150, function()
                    if Preview and Preview.active then Preview.Refresh() end
                end)
                return
            end
        end
    end
end)

AddEventHandler('kt_inventory:closeInventory', function()
    if Preview and Preview.active then
        Preview.Destroy()
    end
end)

-- ─────────────────────────────────────────────────────────────
-- EXPORTS PUBLICS
-- ─────────────────────────────────────────────────────────────

exports('ApplyOutfit', function(outfitData)
    local ped = cache.ped
    if not ped or not DoesEntityExist(ped) or not outfitData then return false end
    applyOutfit(ped, outfitData)
    return true
end)

exports('ApplyClothingSlot', function(slotName, slotData)
    local ped = cache.ped
    if not ped or not DoesEntityExist(ped) or not slotName or not slotData then return false end
    return applyClothingSlot(ped, slotName, slotData)
end)

lib.print.info('^2[kt_inventory] Clothing client v4 chargé^0')