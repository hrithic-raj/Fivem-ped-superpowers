RegisterNetEvent('telekinesis:requestControl', function(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(entity) then
        local src = source
        -- ensure proper ownership transfer
        if not NetworkHasControlOfEntity(entity) then
            NetworkRequestControlOfEntity(entity)
            SetEntityAsMissionEntity(entity, true, true)
            NetworkRegisterEntityAsNetworked(entity)
            SetNetworkIdCanMigrate(netId, true)
            SetNetworkIdExistsOnAllMachines(netId, true)
            SetEntityAsNoLongerNeeded(entity)
        end
        TriggerClientEvent('telekinesis:grantControl', src, netId)
    end
end)
