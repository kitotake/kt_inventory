-- modules/bridge/union/preview.lua
-- Système de preview ped avec caméra custom + environnement hors-map

if not lib then return end

Preview = {}
Preview.active  = false
Preview.ped     = nil
Preview.cam     = nil
Preview.heading = 0.0

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CONFIG
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local CONFIG = {
    -- Zone hors-map (vide, sans collision, sans PNJ)
    spawnCoords  = vec3(402.0, -996.0, -100.0),

    -- Caméra : position relative au ped (offset)
    camOffset    = vec3(0.0, -2.2, 0.6),   -- derrière / hauteur torse
    camFov       = 45.0,

    -- Zoom visage
    camFaceOffset = vec3(0.0, -0.8, 0.6),
    camFaceFov    = 25.0,

  -- Animation idle par défaut
idleDict = 'amb@world_human_hang_out_street@female_arms_crossed@idle_a',
idleClip = 'idle_b',

    -- Vitesse de rotation (drag souris)
    rotSpeed = 1.5,

    -- DOF
    dofEnable    = true,
    dofStrength  = 0.05,
    dofNearBlur  = 0.0,
    dofFarBlur   = 5.0,
    dofNearPlane = 0.5,
    dofFarPlane  = 5.0,
}

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- INTERNAL HELPERS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function deletePed()
    if Preview.ped and DoesEntityExist(Preview.ped) then
        DeleteEntity(Preview.ped)
    end
    Preview.ped = nil
end

local function deleteCamera()
    if Preview.cam and DoesCamExist(Preview.cam) then
        SetCamActive(Preview.cam, false)
        DestroyCam(Preview.cam, false)
    end
    Preview.cam = nil
    RenderScriptCams(false, false, 0, true, true)
end

---Sync components + props from player ped to preview ped.
---@param src number
---@param dst number
local function syncAppearance(src, dst)
    for comp = 0, 11 do
        SetPedComponentVariation(
            dst, comp,
            GetPedDrawableVariation(src, comp),
            GetPedTextureVariation(src, comp),
            GetPedPaletteVariation(src, comp)
        )
    end

    for prop = 0, 9 do
        local drawable = GetPedPropIndex(src, prop)
        local texture  = GetPedPropTextureIndex(src, prop)

        if drawable >= 0 then
            SetPedPropIndex(dst, prop, drawable, texture, true)
        else
            ClearPedProp(dst, prop)
        end
    end
end

---Load an anim dict with timeout safety then play it on ped.
---@param ped number
---@param dict string
---@param clip string
local function playAnim(ped, dict, clip)
    RequestAnimDict(dict)

    local timeout = 0
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        timeout += 10
        if timeout > 3000 then
            lib.print.warn('[kt_inventory:preview] Timeout anim dict: ' .. dict)
            return
        end
    end

    TaskPlayAnim(ped, dict, clip, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    RemoveAnimDict(dict)
end

---Build and activate the script camera pointed at the ped.
---@param ped number
---@param offset vector3
---@param fov number
---@param fade boolean
local function buildCamera(ped, offset, fov, fade)
    -- Destroy previous cam if any
    deleteCamera()

    local pedCoords = GetEntityCoords(ped)
    local camPos    = pedCoords + offset

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    Preview.cam = cam

    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    SetCamFov(cam, fov)
    PointCamAtEntity(cam, ped, 0.0, 0.0, 0.0, true)

    if CONFIG.dofEnable then
        SetCamDofStrength(cam, CONFIG.dofStrength)
        SetCamNearDof(cam, CONFIG.dofNearBlur)
        SetCamFarDof(cam, CONFIG.dofFarBlur)
        SetCamNearClip(cam, CONFIG.dofNearPlane)
        SetCamFarClip(cam, CONFIG.dofFarPlane)
    end

    SetCamActive(cam, true)
    RenderScriptCams(true, fade, fade and 500 or 0, true, true)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- PUBLIC API
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

---Destroy the preview, camera, and ped.
function Preview.Destroy()
    if not Preview.active then return end

    Preview.active = false

    deleteCamera()
    deletePed()

    -- Restore game camera
    DisplayHud(true)
    DisplayRadar(true)
end

---Create the preview environment: spawn ped, build camera, start update loop.
function Preview.Create()
    if Preview.active then return end

    Preview.active = true

    CreateThread(function()
        local playerPed = PlayerPedId()
        Preview.heading = GetEntityHeading(playerPed)

        -- ── Spawn clone in empty zone ─────────────────────────
        local ped = ClonePed(playerPed, Preview.heading, true, false)
        Preview.ped = ped

        SetEntityCoords(ped,
            CONFIG.spawnCoords.x,
            CONFIG.spawnCoords.y,
            CONFIG.spawnCoords.z
        )
        SetEntityHeading(ped, Preview.heading)

        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetEntityCollision(ped, false, false)
        NetworkSetEntityInvisibleToNetwork(ped, true)

        -- ── Sync appearance ───────────────────────────────────
        syncAppearance(playerPed, ped)

        Wait(100)

        -- ── Idle animation ────────────────────────────────────
        playAnim(ped, CONFIG.idleDict, CONFIG.idleClip)

        -- ── Camera ───────────────────────────────────────────
        DisplayHud(false)
        DisplayRadar(false)

        buildCamera(ped, CONFIG.camOffset, CONFIG.camFov, true)

        -- ── Live appearance update loop ───────────────────────
        CreateThread(function()
            while Preview.active do
                if DoesEntityExist(ped) then
                    syncAppearance(PlayerPedId(), ped)
                end
                Wait(250)
            end
        end)

        -- Notify NUI
        SendNUIMessage({ action = 'pedPreviewReady' })
    end)
end

---Rotate the preview ped by mouse delta (called from NUI pedPreviewRotate).
---@param delta number
function Preview.Rotate(delta)
    if not Preview.ped or not DoesEntityExist(Preview.ped) then return end

    Preview.heading = Preview.heading + ((delta or 0) * CONFIG.rotSpeed)
    SetEntityHeading(Preview.ped, Preview.heading)

    -- Keep camera behind the ped
    if Preview.cam and DoesCamExist(Preview.cam) then
        local pedCoords = GetEntityCoords(Preview.ped)
        local rad       = math.rad(Preview.heading)
        local offset    = CONFIG.camOffset

        local camPos = vec3(
            pedCoords.x - math.sin(rad) * math.abs(offset.y),
            pedCoords.y + math.cos(rad) * math.abs(offset.y),
            pedCoords.z + offset.z
        )

        SetCamCoord(Preview.cam, camPos.x, camPos.y, camPos.z)
        PointCamAtEntity(Preview.cam, Preview.ped, 0.0, 0.0, 0.0, true)
    end
end

---Switch between body view and face zoom.
---@param faceZoom boolean
function Preview.SetZoom(faceZoom)
    if not Preview.ped or not DoesEntityExist(Preview.ped) then return end

    if faceZoom then
        buildCamera(Preview.ped, CONFIG.camFaceOffset, CONFIG.camFaceFov, true)
    else
        buildCamera(Preview.ped, CONFIG.camOffset, CONFIG.camFov, true)
    end
end

---Play a custom animation on the preview ped.
---@param dict string
---@param clip string
function Preview.PlayAnim(dict, clip)
    if not Preview.ped or not DoesEntityExist(Preview.ped) then return end
    playAnim(Preview.ped, dict, clip)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CLEANUP
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Preview.Destroy()
end)

lib.print.info('^2[kt_inventory] Frontend preview chargé^0')