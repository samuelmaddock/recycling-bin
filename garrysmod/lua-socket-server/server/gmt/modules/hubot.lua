_G.hubot = {}

function hubot.GetClient()
	return hubot.client
end

function hubot.IsOnline()
	return hubot.client ~= nil
end

function hubot.Msg( msg, uid )

	local hcl = hubot.GetClient()
	if not hubot then return end

	net.Start( "output" )
		net.WriteString( msg )
		net.WriteByte( (uid ~= nil) and 1 or 0 )
		if uid then
			net.WriteString( uid )
		end
	net.Send( hcl )

end

function hubot.SendServerMessage( cl, msg )

	local hcl = hubot.GetClient()
	if not hcl then return end

	net.Start( "servermsg" )
		net.WriteString( cl:GetName() )
		net.WriteString( msg )
	net.Send( hcl )

end

hook.Add( "ClientAuthed", "Authenticate Hubot", function( cl )

	if cl:GetName() == "hubot" then
		hubot.client = cl
	end

end )

hook.Add( "ClientDisconnected", "Remove Hubot", function( cl )

	local hcl = hubot.GetClient()
	if not hcl then return end

	if cl == hcl then
		hubot.client = nil
	end

end )

include "hubot/relay.lua"
include "hubot/command.lua"
