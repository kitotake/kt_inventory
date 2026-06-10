-- modules/bridge/union/preview.lua
-- Version v5 — fix chargement infini

if not lib then return end

Preview = {}
Preview.active  = false
Preview.ped     = nil
Preview.heading = 180.0

local screenOffset = { distance = 3.2, z = 0.0, x = 0.0 }
local faceZoom     = false

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- INTERNAL HELPERS
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        timeout += 10
        if timeout > 3000 then
            lib.print.warn('[kt_inventory:preview] Timeout anim dict: ' .. dict)
            return false
        end
    end
    return true
end

local function deletePed()
    if Preview.ped and DoesEntityExist(Preview.ped) then
        DeleteEntity(Preview.ped)
    end
    Preview.ped = nil
end

local function calcPedPosition(offset)
    local camCoords = GetGameplayCamCoord()
    local camRot    = GetGameplayCamRot(2)

    local forward = vector3(
        -math.sin(math.rad(camRot.z)) * math.cos(math.rad(camRot.x)),
         math.cos(math.rad(camRot.z)) * math.cos(math.rad(camRot.x)),
         math.sin(math.rad(camRot.x))
    )
    local right = vector3(
        math.cos(math.rad(camRot.z)),
        math.sin(math.rad(camRot.z)),
        0.0
    )
    local up = vector3(0.0, 0.0, 1.0)

    local target = camCoords
        + forward * offset.distance
        + right   * offset.x
        + up      * offset.z

    local dir   = camCoords - target
    local pitch = math.deg(math.atan(dir.z, math.sqrt(dir.x^2 + dir.y^2)))
    local yaw   = math.deg(math.atan(dir.y, dir.x)) - 90.0

    if dir.x < 0 then yaw += 180.0 end

    return target, pitch, yaw
end

local function applyHeadFlags(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    DisablePedPainAudio(ped, true)
end

local function startUpdateLoop()
    CreateThread(function()
        while Preview.active and Preview.ped and DoesEntityExist(Preview.ped) do
            local offset = faceZoom
                and { distance = 0.8, z = 0.6, x = screenOffset.x }
                or  screenOffset

            local target, pitch, yaw = calcPedPosition(offset)

            SetEntityCoordsNoOffset(Preview.ped, target.x, target.y, target.z, false, false, false)
            SetEntityRotation(Preview.ped, 0.0, 0.0, yaw + Preview.heading, 2, true)

            Wait(0)
        end
    end)
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- PUBLIC API
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

---Cree le preview ped clone devant la camera.
---@param first boolean  true = animation d'intro, false = pose statique
function Preview.Create(first)
    if Preview.active then return end
    Preview.active = true
    faceZoom       = false

    CreateThread(function()
        local playerPed = PlayerPedId()

        -- ── Chargement du modèle ────────────────────────────────
        local model = GetEntityModel(playerPed)
        RequestModel(model)
        local timeout = 0
        while not HasModelLoaded(model) do
            Wait(10)
            timeout += 10
            if timeout > 5000 then
                lib.print.warn('[kt_inventory:preview] Timeout model')
                Preview.active = false
                -- FIX : notifier le NUI même en cas d'échec pour sortir du chargement
                SendNUIMessage({ action = 'pedPreviewReady' })
                return
            end
        end
        lib.print.info('[kt_inventory:preview] Modele charge')

        -- ── Création du ped ─────────────────────────────────────
        local ped = CreatePed(4, model, 0.0, 0.0, 0.0, 0.0, false, false)

        -- Attendre que le ped soit valide (FIX : CreatePed peut retourner 0 sur certaines versions)
        local pedTimeout = 0
        while not DoesEntityExist(ped) or ped == 0 do
            Wait(10)
            pedTimeout += 10
            if pedTimeout > 3000 then
                lib.print.warn('[kt_inventory:preview] Timeout creation ped')
                Preview.active = false
                SendNUIMessage({ action = 'pedPreviewReady' })
                return
            end
        end

        Preview.ped = ped
        lib.print.info('[kt_inventory:preview] Ped cree: ' .. tostring(ped))

        -- Cacher pendant le setup pour eviter l'apparition a 0,0,0
        SetEntityVisible(ped, false, false)

        ClonePedToTarget(playerPed, ped)
        lib.print.info('[kt_inventory:preview] Clone effectue')

        SetEntityCollision(ped, false, false)
        SetEntityInvincible(ped, true)
        SetEntityCanBeDamaged(ped, false)
        FreezeEntityPosition(ped, true)
        SetEntityAlpha(ped, 255, false)

        -- Masquer aux autres joueurs
        NetworkSetEntityInvisibleToNetwork(ped, true)

        local netId = NetworkGetNetworkIdFromEntity(ped)
        if netId and netId ~= 0 then
            SetNetworkIdExistsOnAllMachines(netId, false)
        end

        SetModelAsNoLongerNeeded(model)
        DisableIdleCamera(true)
        SetEntityLodDist(ped, 0)
        applyHeadFlags(ped)

        -- ── Animation idle ──────────────────────────────────────
        -- FIX : dict fiable, fonctionne sur toutes les versions FiveM
        local idleDict = 'anim@amb@business@bgen@bgen_no_work@'
        local idleClip = 'stand_phone_phoneputdown_idle_01'

        if not loadAnimDict(idleDict) then
            -- Fallback si le dict ne charge pas
            idleDict = 'move_m@casual@e'
            idleClip = 'idle'
            loadAnimDict(idleDict)
        end

        TaskPlayAnim(ped, idleDict, idleClip, 8.0, -8.0, -1, 1, 0.0, false, false, false)

        startUpdateLoop()

        -- Rendre visible uniquement en local après setup complet
        SetEntityVisible(ped, true, false)

        Wait(100)
        lib.print.info('[kt_inventory:preview] Envoi pedPreviewReady')
        SendNUIMessage({ action = 'pedPreviewReady' })
    end)
end

---Detruit le preview ped.
function Preview.Destroy()
    if not Preview.active then return end
    Preview.active = false
    faceZoom       = false

    DisableIdleCamera(false)
    deletePed()
end

---Resynchronise l'apparence du ped apres changement de tenue.
function Preview.Refresh()
    if not Preview.active then return end
    if not Preview.ped or not DoesEntityExist(Preview.ped) then return end

    ClonePedToTarget(PlayerPedId(), Preview.ped)
    applyHeadFlags(Preview.ped)
end

---Rotation du ped par delta souris.
---@param delta number
function Preview.Rotate(delta)
    if not Preview.ped or not DoesEntityExist(Preview.ped) then return end
    Preview.heading = Preview.heading + ((delta or 0) * 1.5)
end

---Bascule entre vue corps et vue visage.
---@param face boolean
function Preview.SetZoom(face)
    faceZoom = face
end

---Joue une animation sur le ped de preview.
---@param dict string
---@param clip string
function Preview.PlayAnim(dict, clip)
    if not Preview.ped or not DoesEntityExist(Preview.ped) then return end

    if loadAnimDict(dict) then
        TaskPlayAnim(Preview.ped, dict, clip, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end
end

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CLEANUP
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Preview.Destroy()
end)

lib.print.info('^2[kt_inventory] Frontend preview v5 charge^0')