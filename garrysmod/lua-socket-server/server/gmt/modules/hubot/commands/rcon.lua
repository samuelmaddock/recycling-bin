local RCON_USAGE = [[
usage: rcon <client-name>
Use `status` to find the client name.]]

---
-- Request server info from connected clients.
--
hubot.RegisterCommand( "rcon", {
	desc = "Remotely execute console commands on connected servers.",
	run = function(args)

		if #args < 1 then
			return RCON_USAGE
		end

		local clientName = args[1]

		local cl = SRV:GetClientByName( clientName )

		if not cl then
			return ("Client '%s' not found."):format( clientName )
		end

		table.remove( args, 1 )
		local cmd = table.concat( args, " " )

		net.Start( "RCON" )
			net.WriteString( cmd )
		net.Send( cl )

	end
} )
