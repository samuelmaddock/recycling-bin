local ServerMsgCol = Color(155,232,149)

local function SendConnectFrame( name )

	if !IsValid(SAMWEBSOCKET) then return end

	local buf = BitBuff()
	buf:WriteString( "connect" )
	buf:WriteString( name )

	SAMWEBSOCKET:SendFrame( buf )

end

hook.Add( "SamWebSocketConnected", "SetupConnectHook", function( ws )

	ws:AddHook( "connect", "RelayConnect", function( buf )

		local name = buf:ReadString()

		local tbl = {
			ServerMsgCol,
			"Player " .. name .. " has connected via WebSockets"
		}

		net.Start( "WSChat" )
			net.WriteTable( tbl )
		net.Broadcast()

	end )

	for _, ply in pairs( player.GetAll() ) do
		SendConnectFrame( ply:Nick() )
	end

end )

hook.Add( "PlayerConnect", "WSPlayerSay", function( name, ip )
	if !IsValid(SAMWEBSOCKET) then return end
	SendConnectFrame( name )
end )