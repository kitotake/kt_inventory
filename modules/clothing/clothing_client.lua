-- ============================================================
-- modules/bridge/union/clothing_client.lua
-- Version v4 — prints détaillés équipement / retrait
-- ============================================================

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

local ClothingMeta = require 'data.clothing_metadata'

-- Verrou anti double-appel NUI
local _equipPending = {}

-- ─── Helpers ────────────────────────────────────────────────────────────────
local function resolveClothingMeta(slot)
    local m = slot.metadata or {}

    if (m.component or m.prop) and m.drawable and m.texture ~= nil then
        local slotNum = m.component or m.prop
        local t = m.component and 'component' or 'prop'
        return { type = t, slotNum = slotNum, drawable = m.drawable, texture = m.texture }
    end

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

-- ─── removeClothing NUI ──────────────────────────────────────────────────────
RegisterNUICallback('removeClothing', function(data, cb)
    local clothingSlot = data.category or data.clothingSlot

    lib.print.info(('[clothing] >>> RETRAIT demandé | clothingSlot=%s'):format(tostring(clothingSlot)))

    if type(clothingSlot) ~= 'string' then
        lib.print.warn('[clothing] removeClothing: clothingSlot invalide — annulé')
        return cb({ ok = false, reason = 'invalid_slot' })
    end

    lib.callback('kt_inventory:removeClothingSlot', false, function(success)
        lib.print.info(('[clothing] removeClothing: réponse serveur success=%s pour clothingSlot=%s'):format(
            tostring(success), clothingSlot))

        if success then
            local slotDef = SLOT_MAP[clothingSlot]
            local ped = cache.ped

            if slotDef and ped and DoesEntityExist(ped) then
                if slotDef.type == 'prop' then
                    lib.print.info(('[clothing] Retrait prop | pedSlot=%d'):format(slotDef.slot))
                    ClearPedProp(ped, slotDef.slot)
                elseif slotDef.type == 'component' then
                    lib.print.info(('[clothing] Retrait component | pedSlot=%d → reset (0,0,0)'):format(slotDef.slot))
                    SetPedComponentVariation(ped, slotDef.slot, 0, 0, 0)
                end
            else
                lib.print.warn(('[clothing] removeClothing: slotDef introuvable pour clothingSlot=%s'):format(clothingSlot))
            end

            SendNUIMessage({ action = 'clothingRemoved', data = { category = clothingSlot } })

            if Preview and Preview.active and previewRefresh then
                previewRefresh(120)
            end

            PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            lib.print.info(('[clothing] <<< RETRAIT terminé | clothingSlot=%s ✓'):format(clothingSlot))
        else
            lib.print.warn(('[clothing] <<< RETRAIT échoué | clothingSlot=%s'):format(clothingSlot))
        end

        cb({ ok = success })
    end, clothingSlot)
end)

-- ─── equipClothing NUI ──────────────────────────────────────────────────────
RegisterNUICallback('equipClothing', function(data, cb)
    local invSlot = tonumber(data.slot)

    lib.print.info(('[clothing] >>> ÉQUIPEMENT demandé | invSlot=%s category=%s'):format(
        tostring(data.slot), tostring(data.category)))

    if not invSlot or invSlot < 1 then
        lib.print.warn('[clothing] equipClothing: slot invalide reçu')
        return cb({ ok = false, reason = 'invalid_slot' })
    end

    local key = tostring(invSlot)
    if _equipPending[key] then
        lib.print.warn(('[clothing] equipClothing: doublon NUI ignoré pour invSlot=%d'):format(invSlot))
        return cb({ ok = false, reason = 'already_pending' })
    end
    _equipPending[key] = true

    lib.print.info(('[clothing] equipClothing: envoi removeClothingItem au serveur pour invSlot=%d'):format(invSlot))

    lib.callback('kt_inventory:removeClothingItem', false, function(success)
        _equipPending[key] = nil

        if not success then
            lib.print.warn(('[clothing] <<< ÉQUIPEMENT échoué | invSlot=%d — item non retiré'):format(invSlot))
            return cb({ ok = false, reason = 'remove_failed' })
        end

        lib.print.info(('[clothing] <<< ÉQUIPEMENT terminé | invSlot=%d item retiré de l\'inventaire ✓'):format(invSlot))
        cb({ ok = true })
    end, invSlot)
end)

-- ─── Handler Principal (clic droit → utiliser) ──────────────────────────────
local kt_inventory = exports[shared.resource]

local function handleClothingItem(data, slot)
    local ped = cache.ped
    local resolved = resolveClothingMeta(slot)

    lib.print.info(('[clothing] >>> USE ITEM | item=%s invSlot=%s'):format(
        tostring(slot.name), tostring(data.slot or data.invSlot)))

    if not resolved then
        lib.print.warn(('[clothing] handleClothingItem: impossible de résoudre metadata pour %s'):format(slot.name or '?'))
        lib.notify({ type = 'error', description = 'Vêtement invalide' })
        return
    end

    lib.print.info(('[clothing] handleClothingItem: résolu → type=%s pedSlot=%d draw=%d tex=%d'):format(
        resolved.type, resolved.slotNum, resolved.drawable, resolved.texture))

    if not validateClothingItem(ped, resolved) then
        lib.print.warn(('[clothing] handleClothingItem: variation invalide pour %s'):format(slot.name))
        lib.notify({ type = 'error', description = 'Vêtement incompatible avec ce personnage' })
        return
    end

    kt_inventory:useItem(data, function(response)
        if not response then
            lib.print.warn('[clothing] handleClothingItem: useItem response nil — annulé')
            return
        end

        local finalMeta = response.metadata or slot.metadata or {}
        local finalResolved = {
            type     = resolved.type,
            slotNum  = resolved.slotNum,
            drawable = finalMeta.drawable or resolved.drawable,
            texture  = finalMeta.texture or resolved.texture,
        }

        lib.print.info(('[clothing] handleClothingItem: application ped | type=%s pedSlot=%d draw=%d tex=%d'):format(
            finalResolved.type, finalResolved.slotNum, finalResolved.drawable, finalResolved.texture))

        local result = applyClothingToPed(ped, finalResolved)

        if result == 'removed' then
            lib.print.info('[clothing] <<< USE ITEM résultat: vêtement retiré du ped')
            lib.notify({ description = 'Vêtement retiré' })
        elseif result == 'applied' then
            lib.print.info('[clothing] <<< USE ITEM résultat: vêtement appliqué sur le ped ✓')
            lib.notify({ description = 'Vêtement porté' })
        elseif result == 'already_worn' then
            lib.print.info('[clothing] <<< USE ITEM résultat: déjà porté (aucun changement)')
        else
            lib.print.warn(('[clothing] <<< USE ITEM résultat inattendu: %s'):format(result))
        end

        if Preview and Preview.active and previewRefresh then
            previewRefresh(120)
        end
    end)
end

return handleClothingItem