-- modules/bridge/union/preview.lua
    -- Preview ped via ClonePedToTarget positionné devant la caméra gameplay

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
                    and { 
                    distance = 0.8, 
                    z = 0.6, 
                    x = screenOffset.x }
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

            local model = GetEntityModel(playerPed)
            RequestModel(model)
            local timeout = 0
            while not HasModelLoaded(model) do
                Wait(10)
                timeout += 10
                if timeout > 5000 then
                    lib.print.warn('[kt_inventory:preview] Timeout model')
                    Preview.active = false
                    return
                end
            end

            local ped = CreatePed(4, model, 0.0, 0.0, 0.0, 0.0, false, false)
            Preview.ped = ped

            -- [FIX 1] Cacher le ped pendant le setup complet
            -- evite qu'il apparaisse a 0,0,0 visible par les autres joueurs
            SetEntityVisible(ped, false, false)

            ClonePedToTarget(playerPed, ped)

            SetEntityCollision(ped, false, false)
            SetEntityInvincible(ped, true)
            SetEntityCanBeDamaged(ped, false)
            FreezeEntityPosition(ped, true)
            SetEntityAlpha(ped, 255, false)

            -- [FIX 2] Masquer aux autres joueurs cote reseau
            NetworkSetEntityInvisibleToNetwork(ped, true)

            -- [FIX 3] Securite supplementaire : desactiver la synchro reseau de l'entite
            local netId = NetworkGetNetworkIdFromEntity(ped)
            if netId and netId ~= 0 then
                SetNetworkIdExistsOnAllMachines(netId, false)
            end

            SetModelAsNoLongerNeeded(model)
            DisableIdleCamera(true)

            -- FIX: SetEntityLodDist déplacé ici — inutile de l'appeler à chaque frame
            SetEntityLodDist(ped, 0)

            applyHeadFlags(ped)

            local idleDict = 'oddjobs@assassinate@construction@'
            -- FIX: 'idle_b' or 'unarmed_fold_arms' évaluait toujours 'idle_b' (string truthy)
            -- 'unarmed_fold_arms' n'était jamais atteint
            local idleClip = first and 'idle_a' or 'unarmed_fold_arms'

            if loadAnimDict(idleDict) then
                TaskPlayAnim(ped, idleDict, idleClip, 8.0, -8.0, -1, 1, 0.0, false, false, false)
            end

            startUpdateLoop()

            -- [FIX 1 suite] Rendre visible uniquement en local, apres setup complet
            SetEntityVisible(ped, true, false)

            Wait(100)
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

    lib.print.info('^2[kt_inventory] Frontend preview (VirtualPed) charge^0')