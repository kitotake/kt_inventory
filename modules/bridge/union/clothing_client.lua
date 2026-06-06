-- modules/bridge/union/clothing_client.lua  v5
-- Corrections v5 (sur base v4) :
--   [FIX-GUARD-1] PlayerData.inventory accédé avec guard nil → plus de crash si inventaire pas prêt
--   [FIX-GUARD-2] Preview.Create/Destroy/Rotate... tous protégés par guard → plus d'erreur si Preview nil
--   [FIX-GUARD-3] Preview callbacks : cb() toujours appelé même si Preview nil → NUI jamais freezé

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
-- [FIX-GUARD-2] HELPER PREVIEW SÉCURISÉ
-- Toutes les interactions Preview passent par ces wrappers.
-- Si Preview est nil ou non actif, rien n'explose.
-- ─────────────────────────────────────────────────────────────

local function previewRefresh(delay)
    SetTimeout(delay or 120, function()
        if Preview and Preview.active then Preview.Refresh() end
    end)
end

-- ─────────────────────────────────────────────────────────────
-- SYNC NUI REACT — SETUP CLOTHING
-- equipped = { [slotName] = { name, label, itemType } }
-- ─────────────────────────────────────────────────────────────

---@param equipped table|nil
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
        lib.callback('kt_inventory:getOutfit', false, function(outfit, equipped)
            local ped = cache.ped
            if not ped or not DoesEntityExist(ped) then return end

            if outfit then
                applyOutfit(ped, outfit)
                lib.print.info('[kt_inventory:clothing] Tenue appliquée au ped')
            end

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
        previewRefresh(100)
    end
end)

-- ─────────────────────────────────────────────────────────────
-- CALLBACKS NUI — Preview ped
-- [FIX-GUARD-2] Preview.X() protégé : cb() toujours appelé
-- [FIX-GUARD-3] cb() avant l'action → NUI jamais bloqué si Preview nil
-- ─────────────────────────────────────────────────────────────

RegisterNUICallback('pedPreviewInit', function(_, cb)
    cb({ ok = true })
    -- [FIX-GUARD-2] Preview peut être nil si preview.lua n'est pas chargé
    if Preview and Preview.Create then
        Preview.Create()
    else
        lib.print.warn('[kt_inventory:clothing] pedPreviewInit : Preview non disponible')
    end
end)

RegisterNUICallback('pedPreviewDestroy', function(_, cb)
    cb({ ok = true })
    if Preview and Preview.Destroy then
        Preview.Destroy()
    end
end)

RegisterNUICallback('pedPreviewRotate', function(data, cb)
    cb({ ok = true })
    if Preview and Preview.Rotate and type(data.delta) == 'number' then
        Preview.Rotate(data.delta)
    end
end)

RegisterNUICallback('pedPreviewRotateVertical', function(data, cb)
    cb({ ok = true })
    if Preview and Preview.RotateVertical and type(data.deltaY) == 'number' then
        Preview.RotateVertical(data.deltaY)
    end
end)

RegisterNUICallback('pedPreviewZoom', function(data, cb)
    cb({ ok = true })
    if not Preview then return end
    if type(data.delta) == 'number' and Preview.Zoom then
        Preview.Zoom(data.delta)
    elseif type(data.face) == 'boolean' and Preview.SetZoom then
        Preview.SetZoom(data.face)
    end
end)

RegisterNUICallback('pedPreviewResetCam', function(_, cb)
    cb({ ok = true })
    if Preview and Preview.ResetCam then
        Preview.ResetCam()
    end
end)

RegisterNUICallback('pedPreviewAnim', function(data, cb)
    cb({ ok = true })
    if Preview and Preview.PlayAnim
        and type(data.dict) == 'string'
        and type(data.clip) == 'string' then
        Preview.PlayAnim(data.dict, data.clip)
    end
end)

RegisterNUICallback('pedPreviewZoomCategory', function(data, cb)
    cb({ ok = true })
    if Preview and Preview.ZoomToCategory and type(data.category) == 'string' then
        Preview.ZoomToCategory(data.category)
    end
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

    -- [FIX-GUARD-1] Guard nil sur PlayerData.inventory
    if not PlayerData or not PlayerData.inventory then
        return cb({ ok = false, reason = 'inventory_not_ready' })
    end

    local slotData = PlayerData.inventory[data.slot]
    if not slotData then
        return cb({ ok = false, reason = 'slot_empty' })
    end

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

    lib.callback('kt_inventory:equipClothing', false, function(success, outfit, nuiPayload)
        if not success then
            return cb({ ok = false, reason = tostring(outfit) })
        end

        local ped = cache.ped
        if outfit and type(outfit) == 'table' and ped and DoesEntityExist(ped) then
            applyOutfit(ped, outfit)
        end

        if nuiPayload then
            SendNUIMessage({
                action = 'clothingEquipped',
                data   = nuiPayload,
            })
        end

        if Preview and Preview.active then
            previewRefresh(120)
        end

        PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true)

        if data.category and Preview and Preview.active and Preview.ZoomToCategory then
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

    lib.callback('kt_inventory:equipOutfit', false, function(success, outfitData, nuiPayload)
        if not success then
            return cb({ ok = false, reason = tostring(outfitData) })
        end

        local ped = cache.ped
        if outfitData and type(outfitData) == 'table' and ped and DoesEntityExist(ped) then
            applyOutfit(ped, outfitData)
        end

        if nuiPayload then
            SendNUIMessage({
                action = 'outfitEquipped',
                data   = nuiPayload,
            })
        end

        if Preview and Preview.active then
            previewRefresh(120)
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

            SendNUIMessage({
                action = 'clothingRemoved',
                data   = { category = data.clothingSlot },
            })

            if Preview and Preview.active then
                previewRefresh(120)
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
                previewRefresh(150)
                return
            end
        end
    end
end)

AddEventHandler('kt_inventory:closeInventory', function()
    if Preview and Preview.Destroy and Preview.active then
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

lib.print.info('^2[kt_inventory] Clothing client v5 chargé^0')