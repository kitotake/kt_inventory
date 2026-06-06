-- modules/bridge/union/clothing_client.lua
-- Gestion vêtements côté client
-- Corrections :
--   [FIX-1] RegisterNetEvent('kt_inventory:setPlayerInventory') n'existe pas.
--           Le chargement de tenue est maintenant déclenché par
--           RegisterNetEvent('union:player:spawned') — event réel du framework.
--   [FIX-2] lib.onCache('ped') : ajout d'un guard DoesEntityExist avant ClonePedToTarget
--   [FIX-3] equipClothing callback : signature corrigée (success, outfit) vs (ok, reason)
--   [FIX-4] Callbacks NUI : cb() appelé avant les opérations longues pour débloquer le NUI

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
-- APPLICATION NATIVE
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
-- CHARGEMENT INITIAL AU SPAWN [FIX-1]
-- Utilise union:player:spawned (event réel) au lieu de
-- kt_inventory:setPlayerInventory (n'existe pas comme NetEvent)
-- ─────────────────────────────────────────────────────────────

local function loadAndApplyOutfit(delay)
    SetTimeout(delay or 500, function()
        lib.callback('kt_inventory:getOutfit', false, function(outfit)
            if not outfit then return end

            local ped = cache.ped
            if not ped or not DoesEntityExist(ped) then return end

            applyOutfit(ped, outfit)
            lib.print.info('[kt_inventory:clothing] Tenue chargée depuis serveur')
        end)
    end)
end

-- [FIX-1] Écouter l'event de spawn réel du framework Union
RegisterNetEvent('union:player:spawned', function()
    loadAndApplyOutfit(600)
end)

-- [FIX-2] Resync si le ped change (changement de skin), avec guard DoesEntityExist
lib.onCache('ped', function(ped)
    if not ped or not DoesEntityExist(ped) then return end

    SetTimeout(200, function()
        -- Vérification supplémentaire car le ped peut avoir été supprimé entretemps
        if not DoesEntityExist(ped) then return end

        lib.callback('kt_inventory:getOutfit', false, function(outfit)
            if outfit and DoesEntityExist(ped) then
                applyOutfit(ped, outfit)
            end
        end)
    end)
end)

-- ─────────────────────────────────────────────────────────────
-- MISE À JOUR TENUE (depuis serveur)
-- ─────────────────────────────────────────────────────────────

RegisterNetEvent('kt_inventory:outfitUpdated', function(outfit)
    if not outfit then return end
    local ped = cache.ped
    if not ped or not DoesEntityExist(ped) then return end

    applyOutfit(ped, outfit)

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
    if type(data.delta) == 'number' then
        Preview.Rotate(data.delta)
    end
end)

RegisterNUICallback('pedPreviewRotateVertical', function(data, cb)
    cb({ ok = true })
    if type(data.deltaY) == 'number' then
        Preview.RotateVertical(data.deltaY)
    end
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
    if type(data.category) == 'string' then
        Preview.ZoomToCategory(data.category)
    end
end)

-- ─────────────────────────────────────────────────────────────
-- CALLBACKS NUI — Équipement vêtements [FIX-3] [FIX-4]
-- ─────────────────────────────────────────────────────────────

-- [FIX-3] Équipement validé par le serveur avant application locale
-- Signature du callback : (success, outfitOrReason)
RegisterNUICallback('equipClothing', function(data, cb)
    if type(data.slot) ~= 'number' or type(data.metadata) ~= 'table' then
        return cb({ ok = false, reason = 'invalid_data' })
    end

    -- [FIX-4] cb() appelé après la réponse serveur, pas avant
    lib.callback('kt_inventory:equipClothing', false, function(success, outfitOrReason)
        if not success then
            return cb({ ok = false, reason = tostring(outfitOrReason) })
        end

        -- outfitOrReason est ici la tenue complète (table)
        local outfit = outfitOrReason
        local ped    = cache.ped

        if outfit and type(outfit) == 'table' and ped and DoesEntityExist(ped) then
            applyOutfit(ped, outfit)
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
    end, data.slot, data.metadata)
end)

-- Équipement tenue complète
RegisterNUICallback('equipOutfit', function(data, cb)
    if type(data.slot) ~= 'number' then
        return cb({ ok = false, reason = 'invalid_slot' })
    end

    lib.callback('kt_inventory:equipOutfit', false, function(success, outfitOrReason)
        if not success then
            return cb({ ok = false, reason = tostring(outfitOrReason) })
        end

        local outfit = outfitOrReason
        local ped    = cache.ped

        if outfit and type(outfit) == 'table' and ped and DoesEntityExist(ped) then
            applyOutfit(ped, outfit)
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

lib.print.info('^2[kt_inventory] Clothing client v3 chargé^0')