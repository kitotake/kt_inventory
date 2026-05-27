-- modules/bridge/union/preview.lua

if not lib then return end

Preview = {}

Preview.ped = nil
Preview.active = false
Preview.heading = 0.0

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- DELETE PED
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Preview.DeletePed()
    if Preview.ped and DoesEntityExist(Preview.ped) then
        DeleteEntity(Preview.ped)
    end

    Preview.ped = nil
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- DESTROY
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Preview.Destroy()
    Preview.active = false

    SetFrontendActive(false)

    Preview.DeletePed()
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SYNC APPAREARANCE
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Preview.SyncAppearance(sourcePed, targetPed)
    for comp = 0, 11 do
        SetPedComponentVariation(
            targetPed,
            comp,
            GetPedDrawableVariation(sourcePed, comp),
            GetPedTextureVariation(sourcePed, comp),
            GetPedPaletteVariation(sourcePed, comp)
        )
    end

    for prop = 0, 9 do
        local drawable = GetPedPropIndex(sourcePed, prop)
        local texture = GetPedPropTextureIndex(sourcePed, prop)

        if drawable >= 0 then
            SetPedPropIndex(
                targetPed,
                prop,
                drawable,
                texture,
                true
            )
        else
            ClearPedProp(targetPed, prop)
        end
    end

    ClonePedToTarget(sourcePed, targetPed)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ANIMATION
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Preview.PlayIdleAnim(ped)
    local dict = 'amb@world_human_hang_out_street@female_arms_crossed@base'

    RequestAnimDict(dict)

    while not HasAnimDictLoaded(dict) do
        Wait(0)
    end

    TaskPlayAnim(
        ped,
        dict,
        clip,
        4.0,
        -4.0,
        -1,
        1,
        0.0,
        false,
        false,
        false
    )

    RemoveAnimDict(dict)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CREATE
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Preview.Create()
    if Preview.active then
        return
    end

    Preview.active = true

    local playerPed = PlayerPedId()

    Preview.heading = GetEntityHeading(playerPed)

    -- ALIGNEMENT GTA
    SetScriptGfxAlign(76, 84)
    SetScriptGfxAlignParams(
    -0.08, -- gauche/droite
    0.03,  -- haut/bas
    1.0,
    1.0
)

    -- FRONTEND
  SetFrontendActive(true)

Citizen.InvokeNative(0xEC9264727EEC0F28)

ActivateFrontendMenu(
    GetHashKey('FE_MENU_VERSION_EMPTY_NO_BACKGROUND'),
    false,
    -1
)
    Wait(100)

    N_0x98215325a695e78a(false)

    -- CLONE
    local ped = ClonePed(
        playerPed,
        Preview.heading,
        true,
        false
    )

    Preview.ped = ped

    local coords = GetEntityCoords(ped)

    -- CACHE SOUS MAP
    SetEntityCoords(
        ped,
        coords.x,
        coords.y,
        coords.z - 100.0
    )

    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityCollision(ped, false, false)

    -- IMPORTANT
    SetEntityVisible(ped, false, false)
    NetworkSetEntityInvisibleToNetwork(ped, false)

    Wait(200)

    SetPedAsNoLongerNeeded(ped)

    -- ROCKSTAR PREVIEW
    GivePedToPauseMenu(ped, 2)

    SetPauseMenuPedLighting(true)
    SetPauseMenuPedSleepState(false)

    -- HUD CLEAN
    ReplaceHudColourWithRgba(
        117,
        0,
        0,
        0,
        0
    )

    Preview.SyncAppearance(playerPed, ped)
    Preview.PlayIdleAnim(ped)

    -- LIVE UPDATE
    CreateThread(function()
        while Preview.active do
            if DoesEntityExist(ped) then
                Preview.SyncAppearance(PlayerPedId(), ped)
            end

            Wait(250)
        end
    end)

    Wait(500)

    SendNUIMessage({
        action = 'pedPreviewReady'
    })
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ROTATION
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function Preview.Rotate(delta)
    if not Preview.ped then
        return
    end

    Preview.heading += ((delta or 0) * 1.5)

    SetEntityHeading(
        Preview.ped,
        Preview.heading
    )
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- RESOURCE STOP
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    Preview.Destroy()
end)

lib.print.info('^2[kt_inventory] Frontend preview chargé^0')