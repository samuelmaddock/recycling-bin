if not SERVER then return end

local function LoadGlobalServer()
	print( "Loading 'global-server' addon..." )

	include "globalserver/init.lua"
end

-- First time load
LoadGlobalServer()
