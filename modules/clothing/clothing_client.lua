-- ============================================================
-- modules/clothing/clothing_client.lua
-- v6 — Équipement réel avec retrait/ajout d'inventaire.
--
-- CHANGEMENTS vs v5 :
--   ✓ NUI callback 'equipClothingItem'  → NOUVEAU
--       Appelle kt_inventory:equipClothing côté serveur (RemoveItem réel,
--       swap si nécessaire), puis applique sur le ped si succès.
--   ✓ NUI callback 'removeClothing'     → RÉÉCRIT
--       Appelle kt_inventory:removeClothing côté serveur (AddItem réel).
--       Si l'inventaire est plein, rien n'est modifié et une notif d'erreur
--       est affichée. Le retrait visuel n'a lieu qu'après confirmation.
--   ✗ NUI callback 'applyClothingFromSlot' → SUPPRIMÉ
--       Remplacé par 'equipClothingItem' qui gère désormais la totalité
--       du flux (retrait inventaire + application ped).
--   ✓ applyClothingToPed / resolveClothingMeta / removeClothingVisual
--       → CONSERVÉS (logique ped inchangée)
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
-- Appelé uniquement APRÈS confirmation serveur dans le NUI callback 'removeClothing'.

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

-- ─── NUI: equipClothingItem ──────────────────────────────────────────────────
-- Appelé depuis React quand un item est drag & drop vers un ClothingSlot.
-- Flux complet :
--   1. Récupère l'item depuis l'inventaire local (slot.name, slot.metadata)
--   2. Résout la metadata clothing (drawable/texture/slotNum)
--   3. Vérifie la compatibilité clothingSlot ↔ category
--   4. Appelle kt_inventory:equipClothing côté serveur :
--        - RemoveItem(invSlot) réel — anti-duplication
--        - si swap=true et qu'un item est déjà équipé dans ce slot,
--          AddItem de l'ancien item dans l'inventaire
--   5. Si le serveur confirme (ok=true) : applique sur le ped + notifie React
--   6. Si échec : rien n'est modifié, cb({ ok = false, reason = ... })

RegisterNUICallback('equipClothingItem', function(data, cb)
    local ped     = cache.ped
    local invSlot = tonumber(data.invSlot)
    local category = data.category

    if not invSlot or type(category) ~= 'string' then
        return cb({ ok = false, reason = 'invalid_payload' })
    end

    -- Récupère l'item depuis l'inventaire local (ox_inventory / kt_inventory)
    local kt_inventory = exports[shared.resource]
    local slotData     = kt_inventory:GetClientSlot(invSlot)

    if not slotData or not slotData.name then
        -- Fallback : construit un slot minimal depuis les données NUI
        slotData = { name = data.name, metadata = {} }
    end

    if not slotData.name then
        return cb({ ok = false, reason = 'item_not_found' })
    end

    local resolved = resolveClothingMeta(slotData)
    if not resolved then
        lib.print.warn(('[clothing] equipClothingItem: impossible de résoudre metadata pour %s'):format(slotData.name))
        return cb({ ok = false, reason = 'resolve_failed' })
    end

    -- Vérification de compatibilité côté client (UX rapide) —
    -- le serveur revérifie via sa propre table de metadata (source de vérité)
    local meta = ClothingMeta[slotData.name]
    local itemClothingSlot = meta and meta.clothingSlot or resolved.clothingSlot

    if itemClothingSlot and itemClothingSlot ~= category then
        lib.print.warn(('[clothing] equipClothingItem: slot incompatible | item=%s attendu=%s reçu=%s'):format(
            slotData.name, tostring(itemClothingSlot), tostring(category)))
        return cb({ ok = false, reason = 'incompatible_slot' })
    end

    lib.print.info(('[clothing] >>> EQUIP demandé | invSlot=%d item=%s category=%s swap=%s'):format(
        invSlot, slotData.name, category, tostring(data.swap)))

    -- ── Appel serveur : retrait réel de l'item + swap éventuel ───────────────
    local success, err = lib.callback.await('kt_inventory:equipClothing', false, {
        invSlot      = invSlot,
        name         = slotData.name,
        clothingSlot = category,
        metadata     = slotData.metadata,
        swap         = data.swap == true,
    })

    if not success then
        lib.print.warn(('[clothing] <<< EQUIP refusé | item=%s raison=%s'):format(slotData.name, tostring(err)))

        if err == 'inventory_full' then
            lib.notify({ type = 'error', description = 'Inventaire plein, impossible d\'échanger ce vêtement' })
        elseif err == 'incompatible_slot' then
            lib.notify({ type = 'error', description = 'Cet emplacement n\'accepte pas ce vêtement' })
        elseif err == 'item_mismatch' or err == 'remove_failed' then
            lib.notify({ type = 'error', description = 'Cet objet n\'est plus disponible' })
        end

        return cb({ ok = false, reason = err })
    end

    -- ── Application visuelle sur le ped ───────────────────────────────────────
    local result = applyClothingToPed(ped, resolved)
    lib.print.info(('[clothing] EQUIP appliqué sur ped | item=%s result=%s'):format(slotData.name, result))

    -- ── Notification React : ce slot clothing est maintenant occupé ──────────
    SendNUIMessage({
        action = 'clothingEquipped',
        data   = {
            category = category,
            item     = {
                name     = slotData.name,
                label    = slotData.label or slotData.name,
                itemType = 'clothing',
                metadata = { drawable = resolved.drawable, texture = resolved.texture },
            },
            -- Slot inventaire qui doit être vidé côté React (anticipation
            -- avant le refreshSlots complet envoyé par le serveur)
            consumedInvSlot = invSlot,
        },
    })

    lib.notify({ description = 'Vêtement porté' })

    if Preview and Preview.active and previewRefresh then
        previewRefresh(120)
    end

    cb({ ok = true })
end)

-- ─── NUI: removeClothing ────────────────────────────────────────────────────
-- v6 : Appelle le serveur pour réintégrer l'item dans l'inventaire
--      (AddItem réel). Le retrait visuel et la notification React
--      n'ont lieu QUE si le serveur confirme (place disponible).
--      Si l'inventaire est plein → rien ne change, notif d'erreur.

RegisterNUICallback('removeClothing', function(data, cb)
    local clothingSlot = data.category or data.clothingSlot
    local itemName     = data.name

    lib.print.info(('[clothing] >>> RETRAIT demandé | clothingSlot=%s item=%s'):format(
        tostring(clothingSlot), tostring(itemName)))

    if type(clothingSlot) ~= 'string' then
        lib.print.warn('[clothing] removeClothing: clothingSlot invalide — annulé')
        return cb({ ok = false, reason = 'invalid_slot' })
    end

    -- ── Appel serveur : réintégration réelle dans l'inventaire ────────────────
    local success, err = lib.callback.await('kt_inventory:removeClothing', false, {
        clothingSlot = clothingSlot,
        name         = itemName,
    })

    if not success then
        lib.print.warn(('[clothing] <<< RETRAIT refusé | clothingSlot=%s raison=%s'):format(
            tostring(clothingSlot), tostring(err)))

        if err == 'inventory_full' then
            lib.notify({ type = 'error', description = 'Inventaire plein, impossible de retirer ce vêtement' })
        elseif err == 'nothing_equipped' then
            -- État désynchronisé — on resynchronise silencieusement
            lib.print.warn('[clothing] removeClothing: aucun item équipé côté serveur pour ce slot')
        end

        return cb({ ok = false, reason = err })
    end

    -- ── Retrait visuel uniquement après confirmation serveur ──────────────────
    local ok = removeClothingVisual(clothingSlot)

    if ok then
        SendNUIMessage({ action = 'clothingRemoved', data = { category = clothingSlot } })

        if Preview and Preview.active and previewRefresh then
            previewRefresh(120)
        end

        PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        lib.print.info(('[clothing] <<< RETRAIT terminé | clothingSlot=%s ✓'):format(clothingSlot))
    else
        lib.print.warn(('[clothing] <<< RETRAIT échoué (visuel) | clothingSlot=%s — item déjà réintégré côté serveur !'):format(clothingSlot))
        -- Note : même si le retrait visuel échoue (slotDef introuvable),
        -- l'item est déjà dans l'inventaire côté serveur. On notifie React
        -- pour rester cohérent — le pire cas est un vêtement encore visible
        -- sur le ped alors qu'il est aussi dans l'inventaire (à corriger
        -- par un refresh manuel), mais PAS de duplication d'item.
        SendNUIMessage({ action = 'clothingRemoved', data = { category = clothingSlot } })
    end

    cb({ ok = true })
end)

-- ─── Handler Principal (clic droit → utiliser) ──────────────────────────────
-- v6 : INCHANGÉ dans son principe (toggle visuel sur le ped via clic droit),
--      mais ce chemin n'effectue PAS de RemoveItem/AddItem inventaire.
--      Il sert uniquement pour un "essayage" visuel temporaire qui NE PASSE
--      PAS par un ClothingSlot. Si tu veux supprimer totalement ce chemin
--      (pour éviter toute confusion avec le flux ClothingSlot ci-dessus),
--      retire l'appel à handleClothingItem dans ton point d'entrée useItem.

local function handleClothingItem(data, slot)
    local ped = cache.ped
    local resolved = resolveClothingMeta(slot)

    lib.print.info(('[clothing] >>> USE ITEM (essai visuel) | item=%s invSlot=%s'):format(
        tostring(slot.name), tostring(data.slot or data.invSlot)))

    if not resolved then
        lib.print.warn(('[clothing] handleClothingItem: impossible de résoudre metadata pour %s'):format(slot.name or '?'))
        lib.notify({ type = 'error', description = 'Vêtement invalide' })
        return
    end

    -- Application directe sur le ped — aucun appel serveur, aucun
    -- changement d'inventaire. Usage : prévisualisation rapide.
    local result = applyClothingToPed(ped, resolved)

    if result == 'removed' then
        lib.notify({ description = 'Aperçu retiré' })
    elseif result == 'applied' then
        lib.notify({ description = 'Aperçu : vêtement porté (non équipé dans vos slots)' })
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