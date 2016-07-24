---
-- GMT Lua Master Server
--
-- @author Samuel Maddock <samuel.maddock@gmail.com>
--

include "lib/socket.lua"
require "copas"
if not bit then require "bit" end

local bit = bit
local copas = copas
local hook = hook

server = {}

local ServerList = {}
local CurrentServer = nil

local AUTH_TIMEOUT = 30

function server.GetServer()
	return CurrentServer
end

---
-- Get a server type; based on gamemode.Get
--
function server.Get( name )
	return ServerList[ name ]
end

---
-- Register a server type; based on gamemode.Register
--
function server.Register( t, name, derived )
	if not derived then derived = "base" end

	-- This gives the illusion of inheritence
	if ( name ~= "base" ) then

		local basetable = server.Get( derived )
		if ( basetable ) then
			t = table.Inherit( t, basetable )
		else
			Msg( "Warning: Couldn't find derived server (", derived, ")\n" )
		end

	end

	ServerList[ name ] = t

	if _G.SERVER then
		SERVER = nil
	end
end


--[[------------------------------------------------------
	CLIENT BASE
--------------------------------------------------------]]

local CLIENT = {}
CLIENT.__index = CLIENT

local function NewClient( srv, id, sock )
	sock:settimeout( 0 )

	local ip, port = sock:getpeername()
	local addr = ("%s:%i"):format( ip, port )

	sock = copas.wrap( sock )

	return setmetatable( {
		id = id,
		ip = ip,
		port = port,
		addr = addr,
		server = srv,
		connected = true,
		timeConnected = os.time(),
		authed = false,
		socket = sock
	}, CLIENT )
end

function CLIENT:__tostring()
	local ip, port = self.ip, self.port
	return ("Client [%i][%s][%s:%i]"):format( self:GetID(), self:GetName(), ip, port )
end

function CLIENT:IsValid()
	return self.connected
end

function CLIENT:GetID()
	return self.id
end

function CLIENT:GetSocket()
	return self.socket
end

function CLIENT:SetName( name )
	self.name = name
end

function CLIENT:GetName()
	return self.name or "Connecting"
end

function CLIENT:IsAuthenticated()
	return self.authed
end

function CLIENT:GetTimeConnected()
	return os.time() - self.timeConnected
end

---
-- Reads in data stream
--
function CLIENT:Read()
	local packetLen, err = self.socket:receive( 2 )
	if not packetLen then return false, err end

	local upper, lower = packetLen:byte( 1, 2 )
	local size = bit.lshift( upper, 8 ) + lower

	-- client sent test packet
	if size == 0 then return false end

	local data, err = self.socket:receive( size )
	if not data then return false, err end

	return data, nil
end

---
-- Send a buffer to the client.
--
function CLIENT:Send( buf )
	local len = buf:Length()
	local lenstr = string.char( bit.rshift( len, 8 ), bit.band( len, 0xFF ) )
	self.socket:send( lenstr .. buf:GetRaw() )
end

---
-- Disconnect the client.
--
function CLIENT:Drop( reason )
	reason = reason or "No reason given"

	local sock = self:GetSocket()

	net.Start( "disconnect" )
		net.WriteString( reason )
	net.Send( self )

	print( ("%s dropped: %s"):format( tostring(self), reason ) )
	
	sock.socket:close()
end


--[[------------------------------------------------------
	SERVER BASE
--------------------------------------------------------]]


local SERVER = {}
SERVER.__index = SERVER

local function NewServer( ip, port, tbl )
	local sock = assert( socket.bind( ip, port ) )
	sock:settimeout( 0 )

	local ip, port = sock:getsockname()
	local addr = ("%s:%i"):format( ip, port )

	local srv = setmetatable( {
		addr = addr,
		clients = {},
		totalClients = 0,
		clientCount = 0
	}, tbl )

	copas.addserver( sock, function( cskt )
		local cl = srv:HandleSocket( cskt )

		if cl then
			hook.Call( "ClientConnected", srv, cl )
			while cl:IsValid() do
				srv:HandleClient( cl )
			end
		end
	end, 0 )

	srv:Initialize()

	return srv
end

function SERVER:__tostring()
	return ("Server [%s]"):format(self.addr)
end

function SERVER:GetSocket()
	return self.socket
end

function SERVER:GetNumClients()
	return self.clientCount
end

---
-- This is probably pretty inefficient, but oh well.
--
function SERVER:GetClients()
	local tbl = {}

	for _, cl in pairs( self.clients ) do
		table.insert( tbl, cl )
	end
	
	return tbl
end

function SERVER:GetClientByName( name )
	for _, cl in pairs( self.clients ) do
		if cl:GetName() == name then
			return cl
		end
	end
	return nil	
end

---
-- Essentially a think function called for each client.
-- DO NOT OVERWRITE THIS FUNCTION!
--
function SERVER:HandleClient( cl )
	local authed = cl:IsAuthenticated()

	if not authed and cl:GetTimeConnected() > AUTH_TIMEOUT then
		cl:Drop( "Authentication timeout..." )
	end

	local data, err = cl:Read()
	local len = data and #data or 0

	if err then
		self:HandleDisconnect( cl, err )
		return
	end

	if len == 0 then return end
	-- print( "received", data, len )

	net.SetData( data )
	net.Incoming( len, cl )
	net.ClearData()
end

---
-- New socket connection, setup client.
-- DO NOT OVERWRITE THIS FUNCTION!
--
function SERVER:HandleSocket( sock )
	local id = self.totalClients
	local cl = NewClient( self, id, sock )

	self.clients[id] = cl

	self.totalClients = self.totalClients + 1
	self.clientCount = self.clientCount + 1

	return cl
end

---
-- Connection closed, handle disconnecting client.
-- DO NOT OVERWRITE THIS FUNCTION!
--
function SERVER:HandleDisconnect( cl, reason )
	self.clients[ cl:GetID() ] = nil
	self.clientCount = self.clientCount - 1

	cl.connected = false

	hook.Call( "ClientDisconnected", self, cl, reason )
end


--[[------------------------------------------------------
	CLIENT AUTHENTICATION
--------------------------------------------------------]]

net.Receive( "auth", function( _, cl )
	if not CurrentServer then return end

	local authed = CurrentServer:AuthenticateClient( cl )
	if not authed then
		CurrentServer:HandleDisconnect( cl )
	end
end )

function SERVER:AuthenticateClient( cl )
	local name = net.ReadString()
	local pass = net.ReadString()

	print( ("AuthenticateClient: %s %s"):format( tostring(name), tostring(pass) ) )

	if pass ~= CONFIG.password then
		cl:Drop( "Invalid password!" )
		return false
	end

	cl:SetName( name )
	cl.authed = true

	hook.Call( "ClientAuthed", self, cl )

	return true
end


--[[------------------------------------------------------
	HOOKS
--------------------------------------------------------]]

function SERVER:Initialize()
	print(("Server started on %s"):format(self.addr))
end

---
-- Client has connected.
--
function SERVER:ClientConnected( cl )
	print( ("Client [%i][%s] connected"):format( cl:GetID(), cl.addr ) )
end

---
-- Client has disconnected.
--
function SERVER:ClientDisconnected( cl, reason )
	if not reason then reason = "none" end
	print( ("Client disconnected with reason: \"%s\""):format( reason ) )
end

---
-- Called when the client has been authenticated.
--
function SERVER:ClientAuthed( cl )
	print( ("Client authenticated: %s"):format( tostring(cl) ) )
end

server.Register( SERVER, "base" )


---
-- Create the main application server.
--
function server.CreateServer( ip, port, serverType )
	if not port then port = 8080 end
	if not serverType then serverType = "base" end

	local serverTbl = server.Get( serverType )
	if not serverTbl then return end
	
	local srv = NewServer( ip, port, serverTbl )

	CurrentServer = srv
	_G.SRV = srv

	return srv
end

---
-- Start looping.
--
function server.loop()
	copas.loop()
	hook.Run( "Tick" )
end
