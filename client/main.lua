-- Death detection. Uses the game's damage event instead of a loop,
-- so it costs nothing while the player is alive.

local reported = false

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' or reported then return end

    local ped = PlayerPedId()
    if args[1] ~= ped then return end
    local fatal = args[6]
    if not (fatal == 1 or fatal == true) then return end

    reported = true

    local attacker, weapon = args[2], args[7]
    local kind, killer = 'unknown', nil

    if attacker and attacker ~= 0 and DoesEntityExist(attacker) then
        local attackerPed = attacker
        if IsEntityAVehicle(attacker) then
            attackerPed = GetPedInVehicleSeat(attacker, -1)
        end

        if attackerPed == ped then
            kind = 'self'
        elseif attackerPed and attackerPed ~= 0 and IsEntityAPed(attackerPed) then
            if IsPedAPlayer(attackerPed) then
                kind = 'player'
                killer = GetPlayerServerId(NetworkGetPlayerIndexFromPed(attackerPed))
            else
                kind = 'npc'
            end
        end
    end

    local c = GetEntityCoords(ped)
    TriggerServerEvent('anti_logger:died', {
        kind = kind,
        killer = killer,
        weapon = weapon,
        inVehicle = IsPedInAnyVehicle(ped, false),
        x = c.x, y = c.y, z = c.z,
    })

    -- wait until the player is alive again (respawn or revive) before reporting another death
    CreateThread(function()
        Wait(2000)
        while IsEntityDead(PlayerPedId()) do
            Wait(1000)
        end
        reported = false
    end)
end)
