local STATUS_TEMPLATE = [[
Lua Server Status
Address  :  %s
Clients  :  %i
]]

---
-- Request Lua Socket Server status
--
hubot.RegisterCommand( "status", {
	desc = "Request status info about the Lua Socket Server.",
	run = function(args)

		local clients = SRV:GetClients()
		local status = STATUS_TEMPLATE:format( SRV.addr, #clients )

		for _, cl in pairs(clients) do
			local id = cl:GetID()
			local addr = cl.addr
			local name = cl:GetName()
			local age = string.NiceTime( cl:GetTimeConnected() )
			local str = ("\t%3s %-10s %-16s %s\n"):format( id, name, addr, age )
			status = status .. str
		end

		return status

	end
} )
