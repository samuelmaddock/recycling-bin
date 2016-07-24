module( 'websockets', package.seeall )

local hooks = {}
local HookPrefix = "WebSockets"

function AddHook( name, unique, callback )
	hook.Add( HookPrefix .. name, unique, callback )
	hooks[ name ] = true
end

function CallHook( name, ... )
	hook.Add( HookPrefix .. name, GAMEMODE, ... )
end

function GetHookTable()
	local hooktbl, tbl = hook.GetTable(), {}
	for k, _ in pairs( hooks ) do
		table.insert( tbl, hooktbl[ HookPrefix .. k ] )
	end
	return tbl
end

function RemoveHook( name, unique )
	hook.Remove( HookPrefix .. name, unique )
	hooks[ name ] = nil
end

function RunHook( name, ... )
	hook.Add( HookPrefix .. name, ... )
end