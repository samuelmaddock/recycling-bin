---
-- Global server
--
-- Inspiration from
-- https://bitbucket.org/blackops7799/breakpoint/src/bb3393586a30b99e399feca8e0d6d9e5a6fda2fc/lua/breakpoint/server/modules/global.lua?at=default
--

include "buffer.lua"
include "snet.lua"
include "detour.lua"

require "luasocket"

local oldsock = nil
if global and global.Disconnect then
	global.Disconnect()
	oldsock = global.sock
end

local gs_enabled = tobool( GetConVarNumber( "gs_enabled" ) ) and true or false

local gs_servername = GetConVarString( "gs_servername" )
if not gs_servername or #gs_servername == 0 then
	gs_servername = "test"
end

_G.global = {
	connected = false,
	sock = oldsock or socket.tcp(),
	settings = {
		enabled = gs_enabled,
		serverName = gs_servername,
		ip = "127.0.0.1",
		port = 27064,
		password = "j2hmF7(}Nfes#8e"
	}
}

local RETRY_DELAY = 30
local nextReconnect = 0

local cfgFilePath = "globalserver.json"

if file.Exists( cfgFilePath, "DATA" ) then
	local settings = util.JSONToTable( file.Read( cfgFilePath ) )
	table.Merge( global.settings, settings )
end

function global.Connect()
	local ip, port = global.settings.ip, global.settings.port
	if not ( ip or port ) then return end

	if not global.sock then
		print "[GLOBAL] Socket not available."
		global.Disconnect()
		return
	end

	local sock = global.sock
	sock:settimeout( 0.2 )

	local succ, err = sock:connect( ip, port )

	if succ then
		print( ("[GLOBAL] Connected to server [%s:%i]"):format( ip, port ) )
		global.connected = true
		sock:settimeout( nil )
	else
		global.connected = false
		print( ("[GLOBAL] Failed to connect: %s"):format( err ) )
		return false, err
	end

	sock:settimeout( 0 )
	global.sock = sock

	snet.Start( "auth" )
		snet.WriteString( global.settings.serverName )
		snet.WriteString( global.settings.password )
	snet.SendToServer()

	nextData = SysTime() + RETRY_DELAY
end

function global.Disconnect()
	local sock = global.sock
	if not sock then return end

	if global.IsConnected() then
		sock:close()
	end

	global.connected = false
end

function global.Reconnect()
	global.Disconnect()
	global.sock = socket.tcp()
	global.Connect()
end

function global.IsConnected()
	return global.connected
end

function global.Send( buf )
	if not global.IsConnected() then
		return false, "not connected"
	end

	local len = buf:Length()
	local lenstr = string.char( bit.rshift( len, 8 ), bit.band( len, 0xFF ) )
	return global.sock:send( lenstr .. buf:GetRaw() )
end

function global.Read()
	if not global.IsConnected() then
		return false, "not connected"
	end

	local sock = global.sock

	local packetLen, err = sock:receive( 2 )
	if not packetLen then return false, err end

	local upper, lower = packetLen:byte( 1, 2 )
	local size = bit.lshift( upper, 8 ) + lower

	local data, err = sock:receive( size )
	if not data then return false, err end

	return data, nil
end

local nextData = 0

local function tick()
	if not global.settings.enabled then return end

	if not global.IsConnected() then
		if nextReconnect >= SysTime() then return end

		MsgN "[GLOBAL] Attempting to reconnect...\n"
		global.Reconnect()
		nextReconnect = SysTime() + RETRY_DELAY
	end

	local data, err = global.Read()

	if not data then
		if err == "closed" then
			print "[GLOBAL] Lost connection..."
			global.Disconnect()
		elseif global.IsConnected() and nextData <= SysTime() then
			// check that we're still connected by sending a zero-length packet
			local succ, err = global.sock:send("\0\0")

			if not succ then
				print "[GLOBAL] Lost connection..."
				global.Disconnect()
			end

			nextData = SysTime() + RETRY_DELAY
		end
		return
	end

	local len = #data

	-- print( "received", data, len )
	nextData = SysTime() + RETRY_DELAY

	snet.SetData( data )
	snet.Incoming( len )
	snet.ClearData()
end
hook.Add( "Tick", "Global Server Tick", tick )


--[[------------------------------------------------------
	HOOKS
--------------------------------------------------------]]

hook.Add( "PlayerSay", "Global Chat Relay", function( ply, text )
	if not IsValid( ply ) then return end

	if not global.IsConnected() then
		return
	end

	snet.Start( "chat" )
		snet.WriteString( ply:SteamID() )
		snet.WriteString( ply:Name() )
		snet.WriteString( text )
	snet.SendToServer()
end )

hook.Add( "PlayerConnect", "Global Connect Relay", function( name, ip )
	if not global.IsConnected() then return end

	snet.Start( "PlayerConnect" )
		snet.WriteString( name )
		snet.WriteString( ip )
	snet.SendToServer()
end )

hook.Add( "PlayerDisconnected", "Global Disconnect Relay", function( ply )
	if not global.IsConnected() then return end
	if not IsValid( ply ) then return end

	local name = ply:Name()

	snet.Start( "PlayerDisconnected" )
		snet.WriteString( name )
	snet.SendToServer()
end )


--[[------------------------------------------------------
	REQUESTS
--------------------------------------------------------]]

local function GetHostIP( includeport )
	local hostip = GetConVarString( "hostip" ) -- GetConVarNumber is inaccurate
	hostip = tonumber( hostip )

	local ip = {}
	ip[ 1 ] = bit.rshift( bit.band( hostip, 0xFF000000 ), 24 )
	ip[ 2 ] = bit.rshift( bit.band( hostip, 0x00FF0000 ), 16 )
	ip[ 3 ] = bit.rshift( bit.band( hostip, 0x0000FF00 ), 8 )
	ip[ 4 ] = bit.band( hostip, 0x000000FF )

	local str = table.concat( ip, "." )

	if includeport then
		local port = GetConVarString( "hostport" )
		str = str .. ":" .. port
	end

	return str
end

snet.Receive( "RequestServerInfo", function()

	local reqid = snet.ReadString()

	local hostname = GetHostName()
	local ip = GetHostIP( true )
	local map = game.GetMap()

	local players = player.GetAll()
	local numply = #players
	local maxply = game.MaxPlayers()

	snet.Start( "ServerInfoResponse" )
		snet.WriteString( hostname )
		snet.WriteString( tostring(VERSION) )
		snet.WriteString( ip )
		snet.WriteString( map )
		snet.WriteInt( numply )
		snet.WriteInt( maxply )

		for _, ply in ipairs( players ) do
			snet.WriteInt( ply:UserID() )
			snet.WriteString( ply:Name() )
			snet.WriteString( ply:SteamID() )
			snet.WriteInt( math.floor( ply:TimeConnected() ) )
			snet.WriteInt( ply:Ping() )
			snet.WriteInt( ply:PacketLoss() )
			snet.WriteString( ply:IPAddress() )
		end

		snet.WriteString( reqid )
	snet.SendToServer()

end )

snet.Receive( "RCON", function()

	local cmd = snet.ReadString()
	cmd = cmd .. "\n"

	game.ConsoleCommand( cmd )

end )

snet.Receive( "RemoteChat", function()

	local name = snet.ReadString()
	local text = snet.ReadString()

	hook.Run( "RemotePlayerSay", name, text )

	-- send back message as an acknowledgement that it was received.
	snet.Start( "chat" )
		snet.WriteString( "WEB" ) -- steam id
		snet.WriteString( name )
		snet.WriteString( text )
	snet.SendToServer()

end )


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

snet.Receive( "RunLua", function()

	local code = snet.ReadString()
	local reqid = snet.ReadString()

	local function sendResponse( resp )
		snet.Start( "RunLuaResponse" )
			snet.WriteString( resp )
			snet.WriteString( reqid )
		snet.SendToServer()
	end

	local str

	-- attempt to parse code
	local func = CompileString( code, "RemoteLuaCode", false )
	if not type(func) == "function" then
		str = tostring(func)
		sendResponse( str )
		return
	end

	local output = {}

	detour.AddDetour( _G, "print", captureOutput( output, true ) )
	detour.AddDetour( _G, "Msg", captureOutput( output ) )

	-- run the code and send back results
	local succ, err = pcall( func )

	detour.RemoveDetour( _G, "Msg" )
	detour.RemoveDetour( _G, "print" )

	if err then
		table.insert( output, "\n\n" .. tostring(err) )
	end

	str = table.concat( output, "" )
	sendResponse( str )

end )
