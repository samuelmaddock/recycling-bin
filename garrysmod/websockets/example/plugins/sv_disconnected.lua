local ServerMsgCol = Color(155,232,149)

local function SendDisconnectedFrame( name )

	if !IsValid(SAMWEBSOCKET) then return end

	local buf = BitBuff()
	buf:WriteString( "disconnected" )
	buf:WriteString( name )

	SAMWEBSOCKET:SendFrame( buf )

end

hook.Add( "SamWebSocketConnected", "SetupDisconnectedHook", function( ws )

	ws:AddHook( "disconnected", "RelayConnect", function( buf )

		local name = buf:ReadString()

		local tbl = {
			ServerMsgCol,
			"Player " .. name .. " has disconnected via WebSockets"
		}

		net.Start( "WSChat" )
			net.WriteTable( tbl )
		net.Broadcast()

	end )

end )

hook.Add( "PlayerDisconnected", "WSPlayerDisconnect", function( ply )
	if !IsValid(SAMWEBSOCKET) then return end
	SendDisconnectedFrame( ply:Nick() )
end )

hook.Add( "ShutDown", "WSShutdown", function()

	if !IsValid(SAMWEBSOCKET) then return end

	for _, ply in pairs( player.GetAll() ) do
		SendDisconnectedFrame( ply:Nick() )
	end

end )