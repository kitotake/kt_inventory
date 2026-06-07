-- ============================================================
-- modules/bridge/union/clothing_client.lua
-- Version unifiée v2 - Chargé depuis items/client.lua
-- ============================================================

-- ─── SLOT_MAP ───────────────────────────────────────────────────────────────
---@type table<string, { type: 'component'|'prop', slot: number }>
local SLOT_MAP = {
    hat         = { type = 'prop',      slot = 0  },
    glasses     = { type = 'prop',      slot = 1  },
    ears        = { type = 'prop',      slot = 2  },
    watch       = { type = 'prop',      slot = 6  },
    bracelet    = { type = 'prop',      slot = 7  },
    mask        = { type = 'component', slot = 1  },
    gloves      = { type = 'component', slot = 3  },
    pants       = { type = 'component', slot = 4  },
    bag         = { type = 'component', slot = 5  },
    shoes       = { type = 'component', slot = 6  },
    chain       = { type = 'component', slot = 7  },
    undershirt  = { type = 'component', slot = 8  },
    armor       = { type = 'component', slot = 9  },
    top         = { type = 'component', slot = 11 },
}

-- ─── Clothing Metadata ──────────────────────────────────────────────────────
local ClothingMeta = require 'data.clothing_metadata'

-- ─── Helpers ────────────────────────────────────────────────────────────────
local function resolveClothingMeta(slot)
    local m = slot.metadata or {}

    -- Cas 1 : Ancien système avec metadata explicites
    if (m.component or m.prop) and m.drawable and m.texture ~= nil then
        local slotNum = m.component or m.prop
        local t = m.component and 'component' or 'prop'
        return { type = t, slotNum = slotNum, drawable = m.drawable, texture = m.texture }
    end

    -- Cas 2 : Items auto-générés
    local itemDef = ClothingMeta[slot.name]
    if itemDef then
        return {
            type     = itemDef.type,
            slotNum  = itemDef.slot,
            drawable = itemDef.drawable,
            texture  = m.texture or 0,
        }
    end

    return nil
end

local function validateClothingItem(ped, resolved)
    if resolved.type == 'prop' then return true end
    if resolved.type == 'component' then
        return IsPedComponentVariationValid(ped, resolved.slotNum, resolved.drawable, resolved.texture)
    end
    return false
end

local function applyClothingToPed(ped, resolved)
    if resolved.type == 'prop' then
        local curDraw = GetPedPropIndex(ped, resolved.slotNum)
        local curTex  = GetPedPropTextureIndex(ped, resolved.slotNum)

        if curDraw == resolved.drawable and curTex == resolved.texture then
            ClearPedProp(ped, resolved.slotNum)
            return 'removed'
        end
        SetPedPropIndex(ped, resolved.slotNum, resolved.drawable, resolved.texture, false)
        return 'applied'
    elseif resolved.type == 'component' then
        local curDraw = GetPedDrawableVariation(ped, resolved.slotNum)
        local curTex  = GetPedTextureVariation(ped, resolved.slotNum)

        if curDraw == resolved.drawable and curTex == resolved.texture then
            return 'already_worn'
        end
        SetPedComponentVariation(ped, resolved.slotNum, resolved.drawable, resolved.texture, 0)
        return 'applied'
    end
    return 'error'
end

-- ─── Remove Clothing Callback (FIX) ─────────────────────────────────────────
RegisterNUICallback('removeClothing', function(data, cb)
    local clothingSlot = data.category or data.clothingSlot

    if type(clothingSlot) ~= 'string' then
        return cb({ ok = false, reason = 'invalid_slot' })
    end

    lib.callback('kt_inventory:removeClothingSlot', false, function(success)
        if success then
            local slotDef = SLOT_MAP[clothingSlot]
            local ped = cache.ped

            if slotDef and ped and DoesEntityExist(ped) then
                if slotDef.type == 'prop' then
                    ClearPedProp(ped, slotDef.slot)
                elseif slotDef.type == 'component' then
                    SetPedComponentVariation(ped, slotDef.slot, 0, 0, 0)
                end
            end

            SendNUIMessage({
                action = 'clothingRemoved',
                data   = { category = clothingSlot },
            })

            if Preview and Preview.active and previewRefresh then
                previewRefresh(120)
            end

            PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        end

        cb({ ok = success })
    end, clothingSlot)
end)

-- ─── Handler Principal ──────────────────────────────────────────────────────
local kt_inventory = exports[shared.resource]

local function handleClothingItem(data, slot)
    local ped = cache.ped
    local resolved = resolveClothingMeta(slot)

    if not resolved then
        lib.print.warn(('[clothing] Impossible de résoudre metadata pour %s'):format(slot.name or '?'))
        lib.notify({ type = 'error', description = 'Vêtement invalide' })
        return
    end

    if not validateClothingItem(ped, resolved) then
        lib.notify({ type = 'error', description = 'Vêtement incompatible avec ce personnage' })
        return
    end

    kt_inventory:useItem(data, function(response)
        if not response then return end

        local finalMeta = response.metadata or slot.metadata or {}
        local finalResolved = {
            type     = resolved.type,
            slotNum  = resolved.slotNum,
            drawable = finalMeta.drawable or resolved.drawable,
            texture  = finalMeta.texture or resolved.texture,
        }

        local result = applyClothingToPed(ped, finalResolved)

        if result == 'removed' then
            lib.notify({ description = 'Vêtement retiré' })
        elseif result == 'applied' then
            lib.notify({ description = 'Vêtement porté' })
        end

        if Preview and Preview.active and previewRefresh then
            previewRefresh(120)
        end
    end)
end

-- Export du handler pour que items/client.lua puisse l'enregistrer
return handleClothingItem