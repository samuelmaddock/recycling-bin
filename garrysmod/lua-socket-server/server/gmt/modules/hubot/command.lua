--[[------------------------------------------------------
	COMMANDS
--------------------------------------------------------]]

hubot.commands = {}

function hubot.RegisterCommand( name, obj )
	hubot.commands[name] = obj
end

function hubot.RunCommand( name, args, envelope )
	name = string.lower( name or "" )

	if type( hubot.commands[name] ) == "table" then
		local func = hubot.commands[name].run
		return func( args, envelope )
	else
		return "Unknown command: " .. tostring(name)
	end
end

---
-- Receive commands sent from Hubot.
--
net.Receive( "hubotcmd", function(_, cl)

	local hcl = hubot.GetClient()
	if not hcl or cl ~= hcl then
		-- we gotta hacker here
		return
	end

	local args = net.ReadString()
	local envelope = {
		room = net.ReadString(),
		user = net.ReadString()
	}

	args = string.Explode( "%s", args, true )

	if not (#args > 0) then return end

	local cmd = args[1]
	table.remove( args, 1 )

	local output = hubot.RunCommand( cmd, args, envelope )
	if not output then return end

	-- BUG?: Anything above 2^13 chars seems to die
	local output = string.sub( output, 0, 8192 )
	hubot.Msg( output, envelope.room )

end )

includeDir( "commands" )
