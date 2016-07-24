local function readIdlescreen()
	local filepath = CONFIG.idlescreenFile
	if not filepath then
		return ("'idlescreenFile' not set in config."):format( filepath )
	end

	local f = io.open( filepath, "r" )
	if not f then
		return ("Failed to open '%s'."):format( filepath )
	end

	local text = f:read( "*all" )
	f:close()

	return text
end

local function writeIdlescreen( text )
	local filepath = CONFIG.idlescreenFile
	if not filepath then
		return ("'idlescreenFile' not set in config."):format( filepath )
	end

	local f = io.open( filepath, "w" )
	if not f then
		return ("Failed to open '%s'."):format( filepath )
	end

	f:write( text )
	f:close()
	
	return ("Updated idlescreen to '%s'"):format( text )
end

hubot.RegisterCommand( "idlescreen", {
	desc = "Get and set the GMTower idlescreen URL.",
	run = function(args)

		local msg

		if #args < 1 then
			msg = readIdlescreen()
		else
			local text = table.concat( args, " " )
			msg = writeIdlescreen( text )
		end

		return msg

	end
} )
