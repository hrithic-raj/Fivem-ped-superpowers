local currentPower = nil
local activePower = nil
local heldEntity = nil
local cooldown = 1000
local lastUse = 0

-- 🔍 Detect ped power type
local function getPedPower()
    local model = GetEntityModel(PlayerPedId())
    for _, data in ipairs(Config.SuperPeds) do
        if model == GetHashKey(data.model) then
            return data.power
        end
    end
    return nil
end

-- 🦵 Improved Super Kick (with animation)
local function superKickPower()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end -- disable while driving

    -- local radius = 3.0
    local pCoords = GetEntityCoords(ped)
    local entities = {}

    for _, v in ipairs(GetGamePool('CVehicle')) do table.insert(entities, v) end
    for _, np in ipairs(GetGamePool('CPed')) do if np ~= ped then table.insert(entities, np) end end

    local target, minDist = nil, Config.kickRadius
    for _, e in ipairs(entities) do
        local eCoords = GetEntityCoords(e)
        local dist = #(pCoords - eCoords)
        if dist < minDist then
            target = e
            minDist = dist
        end
    end

    if target then
        -- ✅ Use known working anim
        local dict = "melee@unarmed@streamed_core"
        local anim = "kick_close_a"

        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do Wait(0) end

        -- 👊 Play full-body kick animation
        ClearPedTasksImmediately(ped)
        TaskPlayAnim(ped, dict, anim, 8.0, -8.0, 1750, 0, 0, false, false, false)

        -- Wait until the kick visually lands (~350–450ms timing window)
        Wait(400)

        -- 💥 Apply powerful kick force
        local targetCoords = GetEntityCoords(target)
        local dir = targetCoords - pCoords
        local norm = dir / #(dir)

        ApplyForceToEntity(
            target,
            1,
            norm.x * Config.KickForce,
            norm.y * Config.KickForce,
            norm.z * (Config.KickForce / 3),
            0.0, 0.0, 0.0,
            0, false, true, true, false, true
        )
    else
        SetNotificationTextEntry("STRING")
        AddTextComponentString("~r~No target nearby to kick!")
        DrawNotification(false, false)
    end
end



-- ⚡ Shockwave / Energy Punch
-- ⚡ Shockwave / Energy Punch
local function shockwavePower()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end

    -- 🔹 Use "Wot The Fuck" emote animation
    local dict = "mini@triathlon"
    local anim = "wot_the_fuck"

    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end

    ClearPedTasksImmediately(ped)
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, 2500, 48, 0, false, false, false)
    Wait(500) -- small delay before applying force for better timing

    -- 🔹 Shockwave logic
    local pCoords = GetEntityCoords(ped)
    local radius = Config.ShockwaveRadius or 12.0  -- fallback in case not set

    -- Affect nearby peds
    for _, entity in ipairs(GetGamePool('CPed')) do
        if entity ~= ped and not IsPedDeadOrDying(entity) then
            local eCoords = GetEntityCoords(entity)
            local dist = #(pCoords - eCoords)
            if dist < radius then
                local dir = (eCoords - pCoords) / dist
                ApplyForceToEntity(entity, 1, dir.x * Config.ShockwaveForce, dir.y * Config.ShockwaveForce, 10.0, 0, 0, 0, 0, false, true, true, false, true)
            end
        end
    end

    -- Affect nearby vehicles
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        local eCoords = GetEntityCoords(vehicle)
        local dist = #(pCoords - eCoords)
        if dist < radius then
            local dir = (eCoords - pCoords) / dist
            ApplyForceToEntity(vehicle, 1, dir.x * Config.ShockwaveForce, dir.y * Config.ShockwaveForce, 15.0, 0, 0, 0, 0, false, true, true, false, true)
        end
    end
end


-- 🌀 Teleport / Blink
-- local function teleportPower()
--     local ped = PlayerPedId()
--     if IsPedInAnyVehicle(ped, false) then return end

--     local coords = GetEntityCoords(ped)
--     local forward = GetEntityForwardVector(ped)
--     local dest = coords + forward * Config.TeleportDistance
--     DoScreenFadeOut(200)
--     Wait(150)
--     SetEntityCoords(ped, dest.x, dest.y, dest.z, false, false, false, true)
--     DoScreenFadeIn(200)
-- end




-- 🌀 Omen-Style Teleport
local teleportActive = false
local teleportMarker = nil
local teleportCoords = nil

-- Helper: Convert rotation to direction
function RotationToDirection(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

-- Helper: Raycast from camera
local function RayCastGamePlayCamera(distance)
    local camRot = GetGameplayCamRot()
    local camCoord = GetGameplayCamCoord()
    local direction = RotationToDirection(camRot)
    local dest = camCoord + (direction * distance)
    local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(
        camCoord.x, camCoord.y, camCoord.z,
        dest.x, dest.y, dest.z,
        -1, PlayerPedId(), 0
    )
    local _, hit, endCoords = GetShapeTestResult(rayHandle)
    return hit, endCoords
end

-- 🔴 Red marker with larger radius
local function drawTeleportMarker(coords)
    DrawMarker(
        1, 
        coords.x, coords.y, coords.z + 1.0, 
        0.0, 0.0, 0.0, 
        0.0, 0.0, 0.0, 
        1.0, 1.0, 1.0,   -- Increased size
        255, 0, 0, 200,  -- Red color
        false, false, 2, nil, nil, false
    )
end

-- 🌫️ Teleport animation (Omen-style)
local function playTeleportFX(ped, coords)
    -- Small fade and smoke effect
    RequestNamedPtfxAsset("core")
    while not HasNamedPtfxAssetLoaded("core") do
        Wait(10)
    end

    UseParticleFxAssetNextCall("core")
    StartParticleFxNonLoopedAtCoord(
        "exp_grd_bzgas_smoke",
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        2.0,  -- scale
        false, false, false
    )
end

-- 🌀 Omen Teleport
local function omenTeleport()
    local ped = PlayerPedId()

    if not teleportActive then
        teleportActive = true
        CreateThread(function()
            while teleportActive do
                Wait(0)
                local tpLimit = Config.TeleportLimit or 50.0
                local hit, endCoords = RayCastGamePlayCamera(tpLimit)
                if hit then
                    teleportCoords = endCoords
                    drawTeleportMarker(endCoords)
                end

                -- Cancel targeting (Backspace / ESC)
                if IsControlJustPressed(0, 177) then
                    teleportActive = false
                    teleportCoords = nil
                    break
                end
            end
        end)
        SetNotificationTextEntry("STRING")
        AddTextComponentString("~b~Teleport targeting active. Press again to teleport.")
        DrawNotification(false, false)

    else
        teleportActive = false

        if teleportCoords then
            local pedCoords = GetEntityCoords(ped)
            local distance = #(teleportCoords - pedCoords)

            -- Limit teleport range
            if distance > (Config.TeleportLimit or 50.0) then
                SetNotificationTextEntry("STRING")
                AddTextComponentString("~r~Target too far! (Max " .. (Config.TeleportLimit or 50.0) .. "m)")
                DrawNotification(false, false)
                return
            end

            -- Detect safe ground
            local foundGround, groundZ = GetGroundZFor_3dCoord(
                teleportCoords.x, teleportCoords.y, teleportCoords.z + 5.0, 0
            )
            local safeZ

            if foundGround then
                safeZ = groundZ + 1.0
            else
                for z = teleportCoords.z + 50.0, 0.0, -2.0 do
                    local hitGround, gZ = GetGroundZFor_3dCoord(
                        teleportCoords.x, teleportCoords.y, z, 0
                    )
                    if hitGround then
                        safeZ = gZ + 1.0
                        break
                    end
                end
            end

            if not safeZ then
                SetNotificationTextEntry("STRING")
                AddTextComponentString("~r~No safe ground detected at target point!")
                DrawNotification(false, false)
                return
            end

            -- 🌫️ Disappear animation
            playTeleportFX(ped, pedCoords)
            DoScreenFadeOut(500)
            Wait(600)

            -- Teleport
            SetEntityCoordsNoOffset(ped, teleportCoords.x, teleportCoords.y, safeZ, false, false, false)
            SetEntityHeading(ped, GetGameplayCamRot(0).z)

            -- 🌫️ Appear animation
            playTeleportFX(ped, teleportCoords)
            Wait(200)
            DoScreenFadeIn(600)
        else
            SetNotificationTextEntry("STRING")
            AddTextComponentString("~r~No valid target to teleport!")
            DrawNotification(false, false)
        end
    end
end

-- RegisterCommand("omen", omenTeleport)
-- RegisterKeyMapping("omen", "Omen Teleport", "keyboard", "E")


-- telekinesis/ lift vehicles
local telekinesisActive = false
local liftedVehicles = {}

-- 🧩 Request server control
local function requestServerControl(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if netId == 0 then
        NetworkRegisterEntityAsNetworked(vehicle)
        netId = NetworkGetNetworkIdFromEntity(vehicle)
    end
    TriggerServerEvent('telekinesis:requestControl', netId)
end

-- 🔄 Grant control
RegisterNetEvent('telekinesis:grantControl', function(netId)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(vehicle) then
        NetworkRequestControlOfEntity(vehicle)
        SetEntityDynamic(vehicle, true)
        ActivatePhysics(vehicle)
    end
end)

-- 🎬 Play animation helper
local function playAnim(dict, anim, duration)
    local ped = PlayerPedId()
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration, 0, 0, false, false, false)
end

-- 🚗 Lift all vehicles
local function liftAllVehicles()
    local ped = PlayerPedId()
    -- playAnim("switch@franklin@bed", "stretch_long", 2500) -- 🔹 Animation when lifting
    -- playAnim("random@shop_robbery_reactions@", "is_this_it", 2500)
    playAnim("random@shop_robbery_reactions@", "anger_a", 2500)
    -- playAnim("friends@fra@ig_1", "over_here_idle_a", 2500)

    local pCoords = GetEntityCoords(ped)
    liftedVehicles = {}

    for _, vehicle in ipairs(GetGamePool("CVehicle")) do
        if DoesEntityExist(vehicle) then
            local vCoords = GetEntityCoords(vehicle)
            local dist = #(pCoords - vCoords)
            if dist <= Config.TelekinesisRange then
                table.insert(liftedVehicles, vehicle)
                requestServerControl(vehicle)
            end
        end
    end

    Wait(300)

    for _, veh in ipairs(liftedVehicles) do
        if DoesEntityExist(veh) then
            local startZ = GetEntityCoords(veh).z
            local targetZ = startZ + Config.LiftHeight

            CreateThread(function()
                while DoesEntityExist(veh) do
                    local x, y, z = table.unpack(GetEntityCoords(veh))
                    if z >= targetZ then
                        FreezeEntityPosition(veh, true)
                        break
                    end

                    SetEntityVelocity(veh, 0.0, 0.0, 2.0)
                    ApplyForceToEntity(
                        veh, 1,
                        0.0, 0.0, Config.LiftForce,
                        0.0, 0.0, 0.0,
                        0, false, true, true, false, true
                    )
                    Wait(50)
                end
            end)
        end
    end
end

-- 💥 Drop all vehicles
local function dropAllVehicles()
    local ped = PlayerPedId()
    -- playAnim("random@shop_robbery_reactions@", "is_this_it", 2500) -- 🔹 Animation when dropping
    -- playAnim("missheist_jewel", "despair", 2500) -- 🔹 Animation when dropping
    playAnim("gestures@f@standing@casual", "gesture_bye_hard", 2500) -- 🔹 Animation when dropping

    for _, veh in ipairs(liftedVehicles) do
        if DoesEntityExist(veh) then
            FreezeEntityPosition(veh, false)
            ActivatePhysics(veh)
            ApplyForceToEntity(
                veh, 1,
                0.0, 0.0, Config.DropForce,
                0.0, 0.0, 0.0,
                0, false, true, true, false, true
            )
        end
    end
    liftedVehicles = {}
end

-- ⚡ Toggle power
local function telekinesisPower()
    if not telekinesisActive then
        telekinesisActive = true
        liftAllVehicles()
    else
        telekinesisActive = false
        dropAllVehicles()
    end
end



-- ⚡ Thor Lightning Power (Visible Bolts)
function thorLightningPower()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end

    -- ⚡ Animation (optional)
    local dict = "friends@fra@ig_1"
    local anim = "over_here_idle_a"
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, 1500, 0, 0, false, false, false)

    local radius = Config.ThorRadius or 20.0
    local force = Config.ThorForce or 60.0
    local pCoords = GetEntityCoords(ped)

    print("⚡ Thor power activated!")

    -- Flash + rumble around player
    ForceLightningFlash()
    -- ShakeGameplayCam("LARGE_EXPLOSION_SHAKE", 0.8)
    ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", 0.2)
    StartScreenEffect("LightningFlash", 0, false)
    PlaySoundFromCoord(-1, "Thunder", pCoords.x, pCoords.y, pCoords.z, 0, 0, 0, 0)

    -- Electric buildup at player
    RequestNamedPtfxAsset("core")
    while not HasNamedPtfxAssetLoaded("core") do Wait(10) end
    UseParticleFxAssetNextCall("core")
    StartParticleFxNonLoopedAtCoord("ent_amb_elec_crackle_sp",
        pCoords.x, pCoords.y, pCoords.z + 1.0, 0.0, 0.0, 0.0,
        2.5, false, false, false)

    Wait(600)

    -- 🔥 Strike vehicles
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        local vCoords = GetEntityCoords(vehicle)
        local dist = #(pCoords - vCoords)

        if dist <= radius then
            -- Sky strike start and end positions
            local strikeStart = vector3(vCoords.x, vCoords.y, vCoords.z + 40.0)
            local strikeEnd = vector3(vCoords.x, vCoords.y, vCoords.z + 1.0)

            -- Draw the lightning bolt (line from sky to vehicle)
            DrawLine(strikeStart.x, strikeStart.y, strikeStart.z,
                     strikeEnd.x, strikeEnd.y, strikeEnd.z,
                     0, 150, 255, 255) -- blue-white bolt

            -- Sky flash and thunder
            StartScreenEffect("LightningFlash", 0, false)
            ForceLightningFlash()
            PlaySoundFromCoord(-1, "Thunder", vCoords.x, vCoords.y, vCoords.z, 0, 0, 0, 0)
            -- Ground electric impact
            UseParticleFxAssetNextCall("core")
            StartParticleFxNonLoopedAtCoord("ent_amb_elec_crackle_sp",
                vCoords.x, vCoords.y, vCoords.z + 1.0, 0.0, 0.0, 0.0,
                2.5, false, false, false)

            -- Explosion for power impact
            AddExplosion(vCoords.x, vCoords.y, vCoords.z + 1.0, 29, 1.5, true, false, 0.8)

            -- Push vehicle
            local dir = (vCoords - pCoords)
            local norm = dir / #(dir)
            ApplyForceToEntity(vehicle, 1, norm.x * force, norm.y * force, 30.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)

            SetVehicleEngineHealth(vehicle, GetVehicleEngineHealth(vehicle) - 400.0)
        end
    end

    -- ⚡ Strike nearby peds too
    for _, entity in ipairs(GetGamePool('CPed')) do
        if entity ~= ped then
            local eCoords = GetEntityCoords(entity)
            local dist = #(pCoords - eCoords)
            if dist <= radius then
                local strikeStart = vector3(eCoords.x, eCoords.y, eCoords.z + 35.0)
                local strikeEnd = vector3(eCoords.x, eCoords.y, eCoords.z + 1.0)
                StartScreenEffect("LightningFlash", 0, false)
                ForceLightningFlash()
                -- Draw bolt
                DrawLine(strikeStart.x, strikeStart.y, strikeStart.z,
                         strikeEnd.x, strikeEnd.y, strikeEnd.z,
                         255, 255, 255, 255)

                -- Electric impact
                UseParticleFxAssetNextCall("core")
                StartParticleFxNonLoopedAtCoord("ent_amb_elec_crackle_sp",
                    eCoords.x, eCoords.y, eCoords.z + 1.0, 0.0, 0.0, 0.0,
                    2.0, false, false, false)

                ForceLightningFlash()
                AddExplosion(eCoords.x, eCoords.y, eCoords.z + 1.0, 29, 1.2, true, false, 0.5)
                ApplyForceToEntity(entity, 1, 0.0, 0.0, 40.0, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                SetEntityHealth(entity, GetEntityHealth(entity) - 60)
            end
        end
    end
end



-- clone power

local clonePeds = {}
local clonesActive = false

------------------------------------------------
-- ⚙️ Relationship setup
------------------------------------------------
local RELATIONSHIP_CLONES = `CLONES`
AddRelationshipGroup("CLONES")

SetRelationshipBetweenGroups(0, RELATIONSHIP_CLONES, `PLAYER`)
SetRelationshipBetweenGroups(0, `PLAYER`, RELATIONSHIP_CLONES)
SetRelationshipBetweenGroups(1, RELATIONSHIP_CLONES, RELATIONSHIP_CLONES)
SetRelationshipBetweenGroups(5, RELATIONSHIP_CLONES, `CIVMALE`)
SetRelationshipBetweenGroups(5, RELATIONSHIP_CLONES, `CIVFEMALE`)
SetRelationshipBetweenGroups(5, RELATIONSHIP_CLONES, `COP`)
SetRelationshipBetweenGroups(5, RELATIONSHIP_CLONES, `SECURITY_GUARD`)

------------------------------------------------
-- 🔍 Find nearby NPCs and players
------------------------------------------------
local function GetNearbyTargets(playerPed, radius)
    local targets = {}
    local playerCoords = GetEntityCoords(playerPed)
    local playerId = PlayerId()

    for _, ped in ipairs(GetGamePool('CPed')) do
        if DoesEntityExist(ped)
        and ped ~= playerPed
        and not IsPedAPlayer(ped)
        and not IsPedDeadOrDying(ped, true)
        and GetPedRelationshipGroupHash(ped) ~= RELATIONSHIP_CLONES then
            local dist = #(GetEntityCoords(ped) - playerCoords)
            if dist <= radius then
                table.insert(targets, ped)
            end
        end
    end

    for _, player in ipairs(GetActivePlayers()) do
        if player ~= playerId then
            local targetPed = GetPlayerPed(player)
            if DoesEntityExist(targetPed) and not IsPedDeadOrDying(targetPed, true) then
                local dist = #(GetEntityCoords(targetPed) - playerCoords)
                if dist <= radius then
                    table.insert(targets, targetPed)
                end
            end
        end
    end

    return targets
end

------------------------------------------------
-- 🧹 Dismiss all clones
------------------------------------------------
local function ClearClones()
    for _, ped in ipairs(clonePeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    clonePeds = {}
    clonesActive = false
    print("[SuperPower] Clones dismissed.")
end

------------------------------------------------
-- 🧬 Create Clones (with proper weapon setup)
------------------------------------------------
local function CreateClones()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local model = GetEntityModel(playerPed)

    clonesActive = true
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    local weaponHash = GetHashKey(Config.CloneWeapon or "WEAPON_CARBINERIFLE")
    local ammoCount = Config.CloneAmmo or 9999
    local infiniteClip = Config.CloneInfiniteAmmo == true

    -- spawn clones
    for i = 1, Config.CloneCount do
        local offset = vector3(math.random(-3,3), math.random(-3,3), 0.0)
        local spawnPos = playerCoords + offset

        local clone = CreatePed(4, model, spawnPos.x, spawnPos.y, spawnPos.z, GetEntityHeading(playerPed), true, true)
        SetEntityAsMissionEntity(clone, true, true)
        SetPedRelationshipGroupHash(clone, RELATIONSHIP_CLONES)
        SetBlockingOfNonTemporaryEvents(clone, true)
        SetPedCanRagdoll(clone, false)
        SetPedFleeAttributes(clone, 0, false)
        SetPedCombatAttributes(clone, 46, true)
        SetPedCombatRange(clone, 2)
        SetPedCombatAbility(clone, 2)
        SetPedCombatMovement(clone, 3)
        SetPedAccuracy(clone, 95)
        SetPedArmour(clone, 200)
        SetEntityHealth(clone, 300)
        SetPedSeeingRange(clone, 150.0)
        SetPedHearingRange(clone, 150.0)
        SetPedAlertness(clone, 3)
        SetPedMoveRateOverride(clone, 1.35)

        -- give weapon, equip, ensure ammo & clip
        GiveWeaponToPed(clone, weaponHash, ammoCount, false, true) -- give weapon and some ammo
        SetCurrentPedWeapon(clone, weaponHash, true)
        SetPedInfiniteAmmoClip(clone, true)    -- keep clip full
        SetPedInfiniteAmmo(clone, true, weaponHash) -- keep ammo (redundant but safe)

        -- ensure they will shoot instantly
        SetPedKeepTask(clone, true)
        SetPedShootRate(clone, 1000) -- shooting frequency (higher = more bullets)
        SetPedShootRate = SetPedShootRate or SetPedShootRate -- prevent nil if unavailable

        TaskFollowToOffsetOfEntity(clone, playerPed, math.random(-2,2), math.random(-2,2), 0.0, 3.0, -1, 2.0, true)
        table.insert(clonePeds, clone)
    end

    print("[SuperPower] Clones created:", #clonePeds)

    -- Aggressive shooting loop: every tick assign targets and force aim+shoot
    CreateThread(function()
        local startTime = GetGameTimer()
        while clonesActive do
            local targets = GetNearbyTargets(playerPed, Config.DetectRadius)

            -- if there are targets, give each clone a primary target to shoot at
            if #targets > 0 then
                for _, clone in ipairs(clonePeds) do
                    if DoesEntityExist(clone) and not IsPedDeadOrDying(clone, true) then
                        -- pick the closest target to the clone for better distribution
                        local bestTarget = nil
                        local bestDist = 99999
                        for _, t in ipairs(targets) do
                            if DoesEntityExist(t) and not IsPedDeadOrDying(t, true) then
                                local d = #(GetEntityCoords(t) - GetEntityCoords(clone))
                                if d < bestDist then
                                    bestDist = d
                                    bestTarget = t
                                end
                            end
                        end

                        if bestTarget and DoesEntityExist(bestTarget) then
                            -- clear tasks then force aim + shoot
                            ClearPedTasks(clone)
                            -- aim at entity (keep aiming for a short duration)
                            TaskAimGunAtEntity(clone, bestTarget, 4000, true)
                            Wait(50) -- tiny wait to let them aim
                            -- shoot at entity for a duration
                            TaskShootAtEntity(clone, bestTarget, 4000, GetPedRelationshipGroupHash(bestTarget) == RELATIONSHIP_CLONES and 0 or 0)
                            SetPedKeepTask(clone, true)
                        end
                    end
                end
            else
                -- no targets: have them stay close and ready
                for _, clone in ipairs(clonePeds) do
                    if DoesEntityExist(clone) and not IsPedDeadOrDying(clone, true) then
                        TaskFollowToOffsetOfEntity(clone, playerPed, math.random(-2,2), math.random(-2,2), 0.0, 3.0, -1, 2.0, true)
                    end
                end
            end

            -- auto-dismiss after duration
          if Config.CloneDurationFlag and GetGameTimer() - startTime > (Config.CloneDuration * 1000) then
                ClearClones()
                break
          end

            Wait(700) -- how often they retarget / re-fire (adjust down for more aggressive)
        end
    end)
end

-- Clear clones
CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustPressed(0, Config.DismissKey) then
            if clonesActive then
                ClearClones()
            end
        end
    end
end)

-- 🔥 Main Power Handler
CreateThread(function()
    local lastModel = nil
    while true do
        Wait(500)

        local ped = PlayerPedId()
        local model = GetEntityModel(ped)

        -- Detect ped model change
        if model ~= lastModel then
            lastModel = model
            currentPower = getPedPower()

            if currentPower then
                print("[SuperPower] Power activated for model:", model, "→", currentPower)
            else
                print("[SuperPower] No power assigned for this ped.")
            end
        end
    end
end)

-- 🔑 Listen for keypress to activate power
CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustPressed(0, Config.PowerKey) then
            if GetGameTimer() - lastUse < cooldown then goto continue end
            lastUse = GetGameTimer()

            if not currentPower then goto continue end

            if currentPower == "superkick" then
                superKickPower()
            elseif currentPower == "shockwave" then
                shockwavePower()
            elseif currentPower == "telekinesis" then
                telekinesisPower()
            elseif currentPower == "thor" then
                print("Triggering Thor Power!")
                thorLightningPower()
            elseif currentPower == "clone" then
                if not clonesActive then
                    CreateClones()
                else
                    print("Clones already out")
                end
            elseif currentPower == "teleport" then
                omenTeleport()
            end
        end
        ::continue::
    end
end)


-- 💪 Always keep super peds in god mode
CreateThread(function()
    while true do
        Wait(1000) -- check every second (adjust if needed)
        local ped = PlayerPedId()
        local model = GetEntityModel(ped)

        -- Check if current ped is a SuperPed
        for _, data in ipairs(Config.SuperPeds) do
            if model == GetHashKey(data.model) then
                -- Enable god mode for this ped
                SetEntityInvincible(ped, true)
                SetPedCanRagdoll(ped, false)
                SetEntityProofs(ped, true, true, true, true, true, true, true, true)
                SetPedSuffersCriticalHits(ped, false)
                ClearPedBloodDamage(ped)
                break
            else
                -- Disable god mode if not a super ped
                SetEntityInvincible(ped, false)
                SetPedCanRagdoll(ped, true)
                SetEntityProofs(ped, false, false, false, false, false, false, false, false)
            end
        end
    end
end)
