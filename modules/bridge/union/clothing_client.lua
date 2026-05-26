-- modules/bridge/union/clothing_client.lua
-- Gestion de la preview du personnage (caméra scaleform) et du système clothing

if not lib then return end

-- ─────────────────────────────────────────────────────────────────────────────
-- ÉTAT LOCAL
-- ─────────────────────────────────────────────────────────────────────────────

local pedCamera    = nil
local pedCamActive = false
local pedRotation  = 0.0
local previewPed   = nil

-- ─────────────────────────────────────────────────────────────────────────────
-- HELPERS CAMERA
-- ─────────────────────────────────────────────────────────────────────────────

local function destroyPedPreview()
    if pedCamera then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(pedCamera, false)
        pedCamera    = nil
        pedCamActive = false
    end

    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
        previewPed = nil
    end
end

local function createPedPreview()
    if pedCamActive then return end

    local playerPed = PlayerPedId()
    local model     = GetEntityModel(playerPed)

    -- Créer un ped clone pour la preview (facultatif, on peut pointer sur le vrai ped)
    -- Ici on pointe simplement la caméra sur le joueur réel
    local pedCoords = GetEntityCoords(playerPed)
    local pedHeading = GetEntityHeading(playerPed)

    -- Calculer position caméra (devant le ped, légèrement en hauteur)
    local camOffset  = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 1.8, 0.6)

    pedCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(pedCamera, camOffset.x, camOffset.y, camOffset.z)
    SetCamPointAtCoord(pedCamera,
        pedCoords.x,
        pedCoords.y,
        pedCoords.z + 0.5  -- pointer vers la tête/torse
    )
    SetCamFov(pedCamera, 35.0)
    SetCamActiveWithInterp(pedCamera, GetRenderingCam(), 300, 1, 1)
    RenderScriptCams(true, true, 300, true, true)

    pedCamActive = true
    pedRotation  = pedHeading

    -- Signaler au NUI que la caméra est prête
    SendNUIMessage({ action = 'pedPreviewReady' })
end

-- ─────────────────────────────────────────────────────────────────────────────
-- NUI CALLBACKS — Preview ped
-- ─────────────────────────────────────────────────────────────────────────────

RegisterNUICallback('pedPreviewInit', function(data, cb)
    cb(1)
    createPedPreview()
end)

RegisterNUICallback('pedPreviewDestroy', function(_, cb)
    cb(1)
    destroyPedPreview()
end)

RegisterNUICallback('pedPreviewRotate', function(data, cb)
    cb(1)

    if not pedCamActive then return end

    local delta   = (data.delta or 0) * 0.5
    pedRotation   = pedRotation + delta

    local playerPed = PlayerPedId()
    SetEntityHeading(playerPed, pedRotation)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- NUI CALLBACKS — Clothing
-- ─────────────────────────────────────────────────────────────────────────────

-- Table de correspondance catégorie → composant GTA
local COMPONENT_MAP = {
    hat        = { prop = 0 },   -- prop chapeau
    glasses    = { prop = 1 },   -- prop lunettes
    ears       = { prop = 2 },   -- prop oreilles
    watch      = { prop = 6 },   -- prop montre
    bracelet   = { prop = 7 },   -- prop bracelet
    mask       = { comp = 1 },   -- composant masque
    hair       = { comp = 2 },   -- composant cheveux
    top        = { comp = 11 },  -- composant haut / veste
    undershirt = { comp = 8 },   -- composant sous-vêtement
    chain      = { comp = 7 },   -- composant bijou de cou
    pants      = { comp = 4 },   -- composant pantalon
    gloves     = { comp = 3 },   -- composant gants
    shoes      = { comp = 6 },   -- composant chaussures
    bag        = { comp = 5 },   -- composant sac à dos
    armor      = { comp = 9 },   -- composant gilet
    cap        = { prop = 0 },   -- alias chapeau
}

RegisterNUICallback('equipClothing', function(data, cb)
    cb(1)

    local slot     = data.slot
    local category = data.category
    local itemType = data.itemType or 'clothing'

    -- Récupérer les métadonnées de l'item depuis l'inventaire du joueur
    local slotData = PlayerData.inventory and PlayerData.inventory[slot]

    if not slotData or not slotData.metadata then
        lib.print.warn(('[clothing] pas de metadata pour slot %s'):format(slot))
        return
    end

    local meta     = slotData.metadata
    local ped      = PlayerPedId()

    if itemType == 'clothing_tenu' then
        -- Tenue complète : appliquer tous les composants stockés dans metadata.outfit
        local outfit = meta.outfit
        if type(outfit) ~= 'table' then
            lib.print.warn('[clothing] metadata.outfit manquant pour clothing_tenu')
            return
        end

        for cat, compData in pairs(outfit) do
            local mapping = COMPONENT_MAP[cat]
            if mapping then
                if mapping.comp then
                    SetPedComponentVariation(ped, mapping.comp,
                        compData.drawable or 0,
                        compData.texture  or 0,
                        compData.palette  or 0)
                elseif mapping.prop then
                    if compData.drawable and compData.drawable >= 0 then
                        SetPedPropIndex(ped, mapping.prop,
                            compData.drawable,
                            compData.texture or 0, true)
                    else
                        ClearPedProp(ped, mapping.prop)
                    end
                end
            end
        end

        TriggerEvent('kt_inventory:clothingEquipped', slot, category, itemType, meta)

    else
        -- Pièce individuelle
        local mapping = COMPONENT_MAP[category]

        if not mapping then
            lib.print.warn(('[clothing] catégorie inconnue : %s'):format(category))
            return
        end

        local drawable = meta.drawable or 0
        local texture  = meta.texture  or 0
        local palette  = meta.palette  or 0

        if mapping.comp then
            SetPedComponentVariation(ped, mapping.comp, drawable, texture, palette)
        elseif mapping.prop then
            if drawable >= 0 then
                SetPedPropIndex(ped, mapping.prop, drawable, texture, true)
            else
                ClearPedProp(ped, mapping.prop)
            end
        end

        TriggerEvent('kt_inventory:clothingEquipped', slot, category, itemType, meta)
    end
end)

RegisterNUICallback('removeClothing', function(data, cb)
    cb(1)

    local category = data.category
    local itemType = data.itemType or 'clothing'
    local ped      = PlayerPedId()

    if itemType == 'clothing_tenu' then
        -- Retirer tous les composants de la tenue (reset aux valeurs par défaut)
        for cat, mapping in pairs(COMPONENT_MAP) do
            if mapping.comp then
                SetPedComponentVariation(ped, mapping.comp, 0, 0, 0)
            elseif mapping.prop then
                ClearPedProp(ped, mapping.prop)
            end
        end
    else
        local mapping = COMPONENT_MAP[category]
        if not mapping then return end

        if mapping.comp then
            SetPedComponentVariation(ped, mapping.comp, 0, 0, 0)
        elseif mapping.prop then
            ClearPedProp(ped, mapping.prop)
        end
    end

    TriggerEvent('kt_inventory:clothingRemoved', category, itemType)
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- SYNC INITIALE : envoyer les vêtements actuels au NUI à l'ouverture
-- ─────────────────────────────────────────────────────────────────────────────

-- Appelé depuis client.lua lors de l'ouverture de l'inventaire
function client.syncClothingToNUI()
    -- Lire les vêtements depuis les métadonnées de l'inventaire
    -- et construire un objet EquippedClothing pour le NUI
    if not PlayerData or not PlayerData.inventory then return end

    local equipped = {}

    for slot, slotData in pairs(PlayerData.inventory) do
        if slotData and slotData.name then
            local isClothing = slotData.name:find('^clothing') ~= nil
            local isTenu     = slotData.name:find('_tenu')    ~= nil

            if isClothing and slotData.metadata then
                local category = slotData.metadata.category

                if category then
                    equipped[category] = {
                        name     = slotData.name,
                        label    = slotData.metadata.label or slotData.label,
                        itemType = isTenu and 'clothing_tenu' or 'clothing',
                    }
                end
            end
        end
    end

    if next(equipped) then
        SendNUIMessage({
            action = 'setupClothing',
            data   = equipped
        })
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- NETTOYAGE à la fermeture de l'inventaire
-- ─────────────────────────────────────────────────────────────────────────────

AddEventHandler('kt_inventory:closedInventory', function()
    destroyPedPreview()
end)

-- Détruire aussi si le joueur se déconnecte ou si la ressource s'arrête
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        destroyPedPreview()
    end
end)

lib.print.info('^2[kt_inventory] Clothing + PedPreview client chargé^0')
