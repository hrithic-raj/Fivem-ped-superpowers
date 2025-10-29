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
local function teleportPower()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end

    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local dest = coords + forward * Config.TeleportDistance
    DoScreenFadeOut(200)
    Wait(150)
    SetEntityCoords(ped, dest.x, dest.y, dest.z, false, false, false, true)
    DoScreenFadeIn(200)
end

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



-- 🔥 Main Power Handler
CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()

        if IsControlJustPressed(0, Config.PowerKey) then
            if GetGameTimer() - lastUse < cooldown then goto continue end
            lastUse = GetGameTimer()

            local power = getPedPower()
            if not power then goto continue end

            if power == "superkick" then
                superKickPower()
            elseif power == "shockwave" then
                shockwavePower()
            elseif power == "telekinesis" then
                telekinesisPower()
            elseif power == "teleport" then
                teleportPower()
            end
        end
        ::continue::
    end
end)


-- RegisterCommand("testkick", function()
--     local ped = PlayerPedId()
--     local dict = "melee@unarmed@streamed_core"
--     local anim = "kick_close_a"

--     RequestAnimDict(dict)
--     while not HasAnimDictLoaded(dict) do
--         Wait(10)
--     end

--     ClearPedTasksImmediately(ped)
--     TaskPlayAnim(ped, dict, anim, 8.0, -8.0, 1750, 1, 0, false, false, false)

--     print("^2[testanim]^7 Playing animation:", dict, anim)
-- end)


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
