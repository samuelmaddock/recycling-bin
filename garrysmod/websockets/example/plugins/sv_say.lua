local NameCol = Color(30,179,53)
local MsgCol = color_white
local ServerMsgCol = Color(155,232,149)

hook.Add( "SamWebSocketConnected", "SetupWebSocketHooks", function( ws )

	ws:AddHook( "say", "RelayChat", function( buf )

		local steamid = buf:ReadString()
		local name = buf:ReadString()
		local msg = buf:ReadString()

		local tbl = {
			NameCol,
			name,
			MsgCol,
			": " .. msg
		}

		net.Start( "WSChat" )
			net.WriteTable( tbl )
		net.Broadcast()

	end )

end )

hook.Add( "PlayerSay", "WSPlayerSay", function( ply, message, bIsTeam )

	if !IsValid(SAMWEBSOCKET) then return end

	local buf = BitBuff()
	buf:WriteString( "say" )
	buf:WriteString( ply:SteamID() )
	buf:WriteString( ply:Nick() )
	buf:WriteString( message )

	SAMWEBSOCKET:SendFrame( buf )

end )