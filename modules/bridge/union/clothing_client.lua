-- modules/bridge/union/clothing_client.lua
-- Gestion vêtements côté client
-- Corrections :
--   [FIX-1] Application de la tenue chargée depuis serveur au spawn
--   [FIX-2] Callbacks NUI validés avant application native
--   [FIX-3] Sync tenue aux autres joueurs via statebag
--   [FIX-4] Gestion DLC : SetPedDlcClothes / SetPedDlcProp

if not lib then return end

-- ─────────────────────────────────────────────────────────────
-- CONSTANTES
-- ─────────────────────────────────────────────────────────────

-- Map clothingSlot → { type, gta_slot }
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

---Applique un slot vêtement sur un ped GTA.
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
            -- [FIX-4] Support DLC
            SetPedDlcClothes(ped, data.dlc, slotDef.slot, drawable, texture, palette)
        else
            SetPedComponentVariation(ped, slotDef.slot, drawable, texture, palette)
        end
    elseif slotDef.type == 'prop' then
        if drawable < 0 then
            -- Retrait du prop
            ClearPedProp(ped, slotDef.slot)
        else
            if data.dlc then
                -- [FIX-4] Support DLC props
                SetPedDlcProp(ped, data.dlc, slotDef.slot, drawable, texture)
            else
                SetPedPropIndex(ped, slotDef.slot, drawable, texture, true)
            end
        end
    end

    return true
end

---Applique une tenue complète sur un ped.
---@param ped number
---@param outfit table  { slotName = { drawable, texture, palette? }, ... }
local function applyOutfit(ped, outfit)
    if not ped or not outfit then return end

    for slotName, slotData in pairs(outfit) do
        applyClothingSlot(ped, slotName, slotData)
    end
end

-- ─────────────────────────────────────────────────────────────
-- CHARGEMENT INITIAL (spawn joueur)
-- ─────────────────────────────────────────────────────────────

-- [FIX-1] Charge et applique la tenue persistée dès que le joueur spawn
RegisterNetEvent('kt_inventory:setPlayerInventory', function(_, _, _, _)
    -- Chargement différé pour éviter conflit avec le spawn du ped
    SetTimeout(500, function()
        lib.callback('kt_inventory:getOutfit', false, function(outfit)
            if not outfit then return end

            local ped = cache.ped
            if not ped or not DoesEntityExist(ped) then return end

            applyOutfit(ped, outfit)

            lib.print.info('[kt_inventory:clothing] Tenue chargée depuis serveur')
        end)
    end)
end)

-- [FIX-3] Resync tenue si le modèle ped change (ex: changement de skin)
lib.onCache('ped', function(ped)
    SetTimeout(200, function()
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

-- Reçoit la tenue mise à jour depuis le serveur après équipement
RegisterNetEvent('kt_inventory:outfitUpdated', function(outfit)
    if not outfit then return end
    local ped = cache.ped
    if not ped or not DoesEntityExist(ped) then return end

    applyOutfit(ped, outfit)

    -- Refresh preview si actif
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
-- CALLBACKS NUI — Équipement vêtements
-- ─────────────────────────────────────────────────────────────

-- [FIX-2] Équipement validé par le serveur avant application locale
RegisterNUICallback('equipClothing', function(data, cb)
    if type(data.slot) ~= 'number' or type(data.metadata) ~= 'table' then
        return cb({ ok = false, reason = 'invalid_data' })
    end

    lib.callback('kt_inventory:equipClothing', false, function(success, outfit)
        if not success then
            return cb({ ok = false, reason = outfit })
        end

        -- Application locale immédiate (feedback visuel rapide)
        local ped = cache.ped
        if outfit and ped and DoesEntityExist(ped) then
            applyOutfit(ped, outfit)
        end

        -- Refresh preview
        if Preview and Preview.active then
            SetTimeout(120, function()
                if Preview.active then Preview.Refresh() end
            end)
        end

        -- Son d'équipement
        PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true)

        -- Zoom anatomique
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

    lib.callback('kt_inventory:equipOutfit', false, function(success, outfit)
        if not success then
            return cb({ ok = false, reason = outfit })
        end

        local ped = cache.ped
        if outfit and ped and DoesEntityExist(ped) then
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
            if slotDef and slotDef.type == 'prop' then
                ClearPedProp(cache.ped, slotDef.slot)
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

    -- Vérifie si un item clothing a changé
    for _, slotData in pairs(changes) do
        if type(slotData) == 'table' and slotData.name then
            local itemDef = exports.kt_inventory:Items(slotData.name)
            if itemDef and (itemDef.category == 'clothing' or itemDef.category == 'clothing_tenu') then
                SetTimeout(150, function()
                    if Preview.active then Preview.Refresh() end
                end)
                return
            end
        end
    end
end)

-- Fermeture inventaire → destroy preview
AddEventHandler('kt_inventory:closeInventory', function()
    if Preview and Preview.active then
        Preview.Destroy()
    end
end)

-- ─────────────────────────────────────────────────────────────
-- EXPORT PUBLIC
-- ─────────────────────────────────────────────────────────────

-- Permet à d'autres ressources d'appliquer une tenue directement
exports('ApplyOutfit', function(outfitData)
    local ped = cache.ped
    if not ped or not outfitData then return false end
    applyOutfit(ped, outfitData)
    return true
end)

exports('ApplyClothingSlot', function(slotName, slotData)
    local ped = cache.ped
    if not ped or not slotName or not slotData then return false end
    return applyClothingSlot(ped, slotName, slotData)
end)

lib.print.info('^2[kt_inventory] Clothing client v2 chargé^0')
