---
-- List all available commands.
--
hubot.RegisterCommand( "help", {
	desc = "Displays all available commands.",
	run = function(args)

		local lines = {}

		for name, cmd in SortedPairs( hubot.commands ) do
			local str = name

			if cmd.desc then
				str = str .. " - " .. cmd.desc
			end

			table.insert( lines, str )
		end

		return table.concat( lines, "\n" )

	end
} )
