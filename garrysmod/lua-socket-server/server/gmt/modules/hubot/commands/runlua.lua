-- used to detour `print` and `Msg` output.
local function captureOutput( out, newline )
	return function(_, ...)
		local tbl = {}

		for _, v in pairs( {...} ) do
			table.insert( tbl, tostring(v) )
		end

		local str = table.concat( tbl, "\t" )

		if newline then
			str = str .. "\n"
		end

		table.insert( out, str )
	end
end

---
-- Run Lua on the Lua Socket Server.
--
hubot.RegisterCommand( "runlua", {
	desc = "Run Lua on the Lua Socket Server.",
	run = function( args, envelope )

		if #args < 2 then
			return "usage: runlua <client-name> <lua-code>"
		end

		local clientName = args[1]

		table.remove( args, 1 )
		local code = table.concat( args, " " )

		if clientName == "self" then

			local str

			-- attempt to parse code
			local f, err = loadstring( code )
			if not f then
				str = ("runlua: %s"):format( tostring(err) )
				hubot.Msg( str )
				return
			end

			local output = {}

			detour.AddDetour( _G, "print", captureOutput( output, true ) )
			detour.AddDetour( _G, "Msg", captureOutput( output ) )

			-- run the code and send back results
			local succ, err = pcall( f )

			detour.RemoveDetour( _G, "Msg" )
			detour.RemoveDetour( _G, "print" )

			if err then
				table.insert( output, "\n\n" .. tostring(err) )
			end

			str = table.concat( output, "" )

			return str

		else -- remote lua

			local cl = SRV:GetClientByName( clientName )

			if not cl then
				return ("Client '%s' not found."):format( clientName )
			end

			local uid = envelope.room

			net.Start( "RunLua" )
				net.WriteString( code )
				net.WriteString( uid )
			net.Send( cl )

		end

	end
} )

net.Receive( "RunLuaResponse", function(_, cl)

	local output = net.ReadString()
	local uid = net.ReadString()

	hubot.Msg( output, uid )

end )
