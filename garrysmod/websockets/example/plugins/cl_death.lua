local function RecvPlayerKilledByPlayer( message )

    local victim     = message:ReadString()
    local inflictor    = message:ReadString()
    local attacker     = message:ReadString()
            
    -- GAMEMODE:AddDeathNotice( attacker, attacker:Team(), inflictor, victim, victim:Team() )
    GAMEMODE:AddDeathNotice( attacker, 1, inflictor, victim, 1 )

end

usermessage.Hook( "WSPlayerKilledByOther", RecvPlayerKilledByPlayer )

local function RecvPlayerKilledSelf( message )

    local victim     = message:ReadString()
            
    -- GAMEMODE:AddDeathNotice( nil, 0, "suicide", victim, victim:Team() )
    GAMEMODE:AddDeathNotice( nil, 0, "suicide", victim, 1 )

end

usermessage.Hook( "WSPlayerKilledSelf", RecvPlayerKilledSelf )