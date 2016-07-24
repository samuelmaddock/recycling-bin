---
-- Request server info from connected clients.
--
hubot.RegisterCommand( "serverinfo", {
	desc = "Get info about connected servers.",
	run = function( args, envelope )

		local recipient

		if #args > 0 then
			local clientName = args[1]
			local client = SRV:GetClientByName( clientName )

			if not client then
				return ("Client '%s' not found."):format( clientName )
			end

			recipient = client
		else
			recipient = SRV:GetClients()
		end

		local uid = envelope.room

		net.Start( "RequestServerInfo" )
			net.WriteString( uid )
		net.Send( recipient )

	end
} )

local SERVER_STATUS_TEMPLATE = [[
hostname: %s
version : %s
udp/ip  : %s
map     : %s
players : %d (%d max)

# userid name                uniqueid            connected ping loss  adr
]]

net.Receive( "ServerInfoResponse", function(_, cl)

	local hostname = net.ReadString()
	local VERSION = net.ReadString()
	local ip = net.ReadString()
	local map = net.ReadString()
	local numply = net.ReadInt()
	local maxply = net.ReadInt()

	local players = {}

	for i = 1, numply do
		table.insert( players, {
			userid = net.ReadInt(),
			name = net.ReadString(),
			steamID = net.ReadString(),
			timeConnected = net.ReadInt(),
			ping = net.ReadInt(),
			packetLoss = net.ReadInt(),
			ip = net.ReadString()
		} )
	end

	local msg = SERVER_STATUS_TEMPLATE:format(
			hostname, VERSION, ip, map, numply, maxply )
	
	for _, ply in ipairs( players ) do
		local plyinfo = ("# %6d %-19s %-19s %-9s %4d %5d %s\n"):format(
				ply.userid, ply.name, ply.steamID,
				string.FormattedTime( ply.timeConnected, "%02i:%02i:%02i" ),
				ply.ping, ply.packetLoss, ply.ip )
		msg = msg .. plyinfo
	end

	local uid = net.ReadString()

	hubot.Msg( msg, uid )

end )
