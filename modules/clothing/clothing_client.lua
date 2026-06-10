-- ============================================================
-- modules/clothing/clothing_client.lua
-- v5 — Les vêtements restent dans l'inventaire.
--
-- CHANGEMENTS vs v4 :
--   ✗ NUI callback 'removeClothing'  → SUPPRIMÉ (appel serveur inutile)
--   ✗ NUI callback 'equipClothing'   → SUPPRIMÉ (RemoveItem inutile)
--   ✗ _equipPending (verrou)         → SUPPRIMÉ
--   ✗ validateClothingItem           → SUPPRIMÉ (plus bloquant, juste logué)
--   ✓ applyClothingToPed             → CONSERVÉ (logique ped inchangée)
--   ✓ resolveClothingMeta            → CONSERVÉ
--   ✓ handleClothingItem             → SIMPLIFIÉ (plus de useItem)
--   + removeClothingVisual           → NOUVEAU (retire visuellement du ped)
-- ============================================================

local SLOT_MAP = {
    hat        = { type = 'prop',      slot = 0  },
    glasses    = { type = 'prop',      slot = 1  },
    ears       = { type = 'prop',      slot = 2  },
    watch      = { type = 'prop',      slot = 6  },
    bracelet   = { type = 'prop',      slot = 7  },
    mask       = { type = 'component', slot = 1  },
    gloves     = { type = 'component', slot = 3  },
    pants      = { type = 'component', slot = 4  },
    bag        = { type = 'component', slot = 5  },
    shoes      = { type = 'component', slot = 6  },
    chain      = { type = 'component', slot = 7  },
    undershirt = { type = 'component', slot = 8  },
    armor      = { type = 'component', slot = 9  },
    top        = { type = 'component', slot = 11 },
}

local ClothingMeta = require 'data.clothing_metadata'

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

local function applyClothingToPed(ped, resolved)
    if resolved.type == 'prop' then
        local curDraw = GetPedPropIndex(ped, resolved.slotNum)
        local curTex  = GetPedPropTextureIndex(ped, resolved.slotNum)

        if curDraw == resolved.drawable and curTex == resolved.texture then
            -- Même item déjà porté → on le retire (toggle)
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

-- ─── removeClothingVisual ────────────────────────────────────────────────────
-- Retire visuellement un vêtement du ped, sans toucher à l'inventaire.
-- Appelé depuis le NUI callback 'removeClothing'.

local function removeClothingVisual(clothingSlot)
    local slotDef = SLOT_MAP[clothingSlot]
    local ped = cache.ped

    if not slotDef or not ped or not DoesEntityExist(ped) then
        lib.print.warn(('[clothing] removeClothingVisual: slotDef introuvable pour clothingSlot=%s'):format(tostring(clothingSlot)))
        return false
    end

    if slotDef.type == 'prop' then
        lib.print.info(('[clothing] Retrait prop | pedSlot=%d'):format(slotDef.slot))
        ClearPedProp(ped, slotDef.slot)
    elseif slotDef.type == 'component' then
        lib.print.info(('[clothing] Retrait component | pedSlot=%d → reset (0,0,0)'):format(slotDef.slot))
        SetPedComponentVariation(ped, slotDef.slot, 0, 0, 0)
    end

    return true
end

-- ─── NUI: removeClothing ────────────────────────────────────────────────────
-- v5 : NE fait plus d'appel serveur.
--      Retire uniquement visuellement du ped et notifie le NUI.

RegisterNUICallback('removeClothing', function(data, cb)
    local clothingSlot = data.category or data.clothingSlot

    lib.print.info(('[clothing] >>> RETRAIT demandé | clothingSlot=%s'):format(tostring(clothingSlot)))

    if type(clothingSlot) ~= 'string' then
        lib.print.warn('[clothing] removeClothing: clothingSlot invalide — annulé')
        return cb({ ok = false, reason = 'invalid_slot' })
    end

    -- Retrait visuel uniquement — aucun appel serveur, aucun RemoveItem
    local ok = removeClothingVisual(clothingSlot)

    if ok then
        SendNUIMessage({ action = 'clothingRemoved', data = { category = clothingSlot } })

        if Preview and Preview.active and previewRefresh then
            previewRefresh(120)
        end

        PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        lib.print.info(('[clothing] <<< RETRAIT terminé (visuel uniquement) | clothingSlot=%s ✓'):format(clothingSlot))
    else
        lib.print.warn(('[clothing] <<< RETRAIT échoué | clothingSlot=%s'):format(clothingSlot))
    end

    cb({ ok = ok })
end)

-- ─── NUI: equipClothing ─────────────────────────────────────────────────────
-- v5 : SUPPRIMÉ — le drag & drop ne retire plus l'item de l'inventaire.
--      L'équipement est géré directement en Lua via handleClothingItem
--      ou côté React via applyClothingToPed.
--
-- L'ancien callback faisait :
--   lib.callback('kt_inventory:removeClothingItem', ...)  ← SUPPRIMÉ
--
-- Si tu as besoin de notifier le serveur (logs, anti-cheat),
-- utilise le callback optionnel 'kt_inventory:applyClothing' défini
-- dans clothing_server.lua — il ne modifie pas l'inventaire.

-- ─── NUI: applyClothingFromSlot ──────────────────────────────────────────────
-- Appelé depuis React quand un item est drag & drop vers un ClothingSlot.
-- Applique visuellement le vêtement sur le ped.
-- N'appelle AUCUNE fonction serveur modifiant l'inventaire.

RegisterNUICallback('applyClothingFromSlot', function(data, cb)
    local ped    = cache.ped
    local invSlot = tonumber(data.invSlot)

    -- Récupère l'item depuis l'inventaire local (ox_inventory / kt_inventory)
    -- pour avoir accès à slot.name et slot.metadata
    local kt_inventory = exports[shared.resource]
    local slotData     = kt_inventory:GetClientSlot(invSlot)  -- ou GetSlot selon ton API

    if not slotData or not slotData.name then
        -- Fallback : construit un slot minimal depuis les données NUI
        slotData = { name = data.name, metadata = {} }
    end

    local resolved = resolveClothingMeta(slotData)
    if not resolved then
        return cb({ ok = false, reason = 'resolve_failed' })
    end

    local result = applyClothingToPed(ped, resolved)

    if Preview and Preview.active and previewRefresh then
        previewRefresh(120)
    end

    cb({ ok = true, result = result })
end)

-- ─── Handler Principal (clic droit → utiliser) ──────────────────────────────
-- v5 : N'appelle plus useItem() qui retirait l'item.
--      Résout simplement la metadata et applique sur le ped.

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

    -- Application directe sur le ped — aucun appel serveur
    local result = applyClothingToPed(ped, resolved)

    if result == 'removed' then
        lib.print.info('[clothing] <<< USE ITEM résultat: vêtement retiré du ped')
        lib.notify({ description = 'Vêtement retiré' })

        -- Notifier React que le slot clothing est maintenant vide
        -- Le store clothing sera mis à jour depuis le NUI via clothingRemoved
        local clothingSlot = resolved.clothingSlot or (ClothingMeta[slot.name] and ClothingMeta[slot.name].clothingSlot)
        if clothingSlot then
            SendNUIMessage({ action = 'clothingRemoved', data = { category = clothingSlot } })
        end

    elseif result == 'applied' then
        lib.print.info('[clothing] <<< USE ITEM résultat: vêtement appliqué sur le ped ✓')
        lib.notify({ description = 'Vêtement porté' })

        -- Notifier React que ce slot clothing est maintenant occupé
        local meta    = ClothingMeta[slot.name]
        local catSlot = meta and meta.clothingSlot
        if catSlot then
            SendNUIMessage({
                action = 'clothingEquipped',
                data   = {
                    category = catSlot,
                    item     = {
                        name     = slot.name,
                        label    = slot.label or slot.name,
                        itemType = 'clothing',
                        metadata = { drawable = resolved.drawable, texture = resolved.texture },
                    },
                },
            })
        end

    elseif result == 'already_worn' then
        lib.print.info('[clothing] <<< USE ITEM résultat: déjà porté (aucun changement)')

    else
        lib.print.warn(('[clothing] <<< USE ITEM résultat inattendu: %s'):format(result))
    end

    if Preview and Preview.active and previewRefresh then
        previewRefresh(120)
    end
end

return handleClothingItem