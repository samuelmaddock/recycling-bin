---
-- Send a message to a server.
--
hubot.RegisterCommand( "say", {
	desc = "Chat with remote servers in 'chat_*' channels.",
	run = function(args, envelope)

		if #args < 1 then
			return "usage: say <message>"
		end

		local room = envelope.room or ""
		local clientName = string.match( room, "chat_(%w+)" )

		if not clientName then
			return "The say command is only supported in rooms using the 'chat_*' format."
		end

		local cl = SRV:GetClientByName( clientName )

		if not cl then
			return ("Client '%s' not found."):format( clientName )
		end

		-- TODO: preserve whitespace
		local msg = table.concat( args, " " )

		net.Start( "RemoteChat" )
			net.WriteString( envelope.user or "Console" )
			net.WriteString( msg )
		net.Send( cl )

	end
} )
