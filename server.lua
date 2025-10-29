RegisterNetEvent('telekinesis:requestControl', function(netId)
    local src = source
    -- The server just forwards the event back to the requesting player
    -- because only the client can actually control and manipulate entities
    TriggerClientEvent('telekinesis:grantControl', src, netId)
end)
