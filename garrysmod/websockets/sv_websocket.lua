if FileReport.HasFile( "lua/bin/gmsv_socket/core_win32.dll" ) then
	require('socket')
else
	return
end

local urlparse = url.parse

module( 'websocket', package.seeall )

CVAR_CONNECT = CreateConVar( "websocket_connect", 0, {FCVAR_ARCHIVE,FCVAR_DONTRECORD}, "Whether or not to connect to WebSockets." )

local numclients, totalclients = 0, 0
local clients = {}

local function NewConfig( uri )

	local config = {}

	local status, url = pcall( urlparse, uri )

	if !status then
		error( "Error parsing url" )
	elseif !url.scheme then
		error( "No websocket protocol specified" )
	elseif url.scheme != 'ws' then
		error( "Unsupported protocol '" .. tostring(url.scheme) .. "'" )
	end

	config.uri = uri
	config.host = url.host
	config.port = tonumber(url.port) or 80
	config.path = url.path or '/'
	config.origin = url.authority
	config.protocol = url.scheme or 'ws'

	return config

end

local function NewClient( config )

	/*local sock = socket.tcp()
	sock:settimeout(1)

	sock:connect( config.host, config.port )*/

	local sock = socket.connect( config.host, config.port )
	if !sock then return end

	sock:settimeout(0)

	if !sock then return end

	local client = {}
	setmetatable( client, CLIENT )

	client._id 	   = totalclients
	client._socket = sock
	client._config = config
	client._bytesReceived = 0
	client._bytesSent = 0
	client._overflow = BitBuff()
	client._hookPrefix = "WebSocketClient" .. client._id
	client._hooks = {}

	ClientHandshake( client, config )

	clients[ config.uri ] = client
	numclients = numclients + 1
	totalclients = totalclients + 1

	return client

end

/*---------------------------------------------------------------------------
	Name:	Create
	Desc:	Establishes a new WebSocket connection and returns the 
			client object.
	Ex:		websocket.Create( "ws://192.168.1.2:8080" )
			websocket.Create( "192.168.1.2", 8080 )
---------------------------------------------------------------------------*/
function Create( ... )

	local uri

	local args = {...}
	if #args == 2 then
		uri = string.format( "ws://%s:%s", args[1], args[2] )
	else
		uri = args[1]
	end

	local status, config = pcall( NewConfig, uri )
	if !status then
		ErrorNoHalt( config .. "\n" )
		return
	end

	return NewClient( config )

end

/*---------------------------------------------------------------------------
	Name:	GetClientByHost
	Desc:	Attempt to get a WebSocket client by host
	Ex:		local ws = websocket.GetClientByHost( "192.168.1.2" )
			local ws = websocket.GetClientByHost( "echo.websocket.org" )
---------------------------------------------------------------------------*/
function GetClientByHost( host )

	for _, cl in pairs( clients ) do
		if cl:GetHost() == host then
			return cl
		end
	end

end

/*---------------------------------------------------------------------------
	Name:	Close
	Desc:	Close specific connection.
---------------------------------------------------------------------------*/
function Close( ... )

	local uri

	local args = {...}
	if #args == 2 then
		uri = string.format( "ws://%s:%s", args[1], args[2] )
	else
		uri = args[1]
	end

	local cl = clients[ uri ]
	if cl then
		v:Close()
		cl = v
	end

	numclients = math.max( 0, numclients - 1 )
	clients[ uri ] = nil

end

/*---------------------------------------------------------------------------
	Name:	CloseAll
	Desc:	Close all open connections.
---------------------------------------------------------------------------*/
function CloseAll()

	for _, cl in pairs(clients) do
		cl:Close()
	end

	numclients = 1
	clients = {}

end

/*---------------------------------------------------------------------------
	Name:	AttemptConnection
	Desc:	Attempt to connect to websocket and call a function on success.
	Ex:		websocket.AttemptConnection( "ws://192.168.1.2:8080", callback )
			websocket.AttemptConnection( "ws://192.168.1.2:8080", callback, true )
			websocket.AttemptConnection( "192.168.1.2", 8080, callback )
---------------------------------------------------------------------------*/
function AttemptConnection( ... )

	local uri, callback, TryUntilConnection

	local args = {...}
	if isnumber(args[2]) then
		uri = string.format( "ws://%s:%s", args[1], args[2] )
		callback = args[3]
		TryUntilConnection = args[4]
	else
		uri = args[1]
		callback = args[2]
		TryUntilConnection = args[3]
	end

	local status, url = pcall( urlparse, uri )
	if !status then
		ErrorNoHalt( "websocket.AttemptConnection: " .. tostring(url) .. "\n" )
		return
	end

	if !isfunction(callback) then
		ErrorNoHalt( "websocket.AttemptConnection: Argument #3 wasn't a function!\n" )
		return
	end

	local function Connect( address, onsuccess, onfailure )
		http.Fetch( "http://" .. address .. "/",
			function( body, length, headers, code )
				if code == 200 then onsuccess() end
			end,
			function()
				if TryUntilConnection then
					onfailure()
				else
					print( "Connection to '" .. uri .. "' failed." )
				end
			end )
	end

	local delay = 0
	local timername = uri .. "Connect"
	local origin = url.authority

	local function RetryOnFailure()

		delay = math.max( delay * 2, 1 )

		print( "Connection to '" .. uri .. "' failed, retrying in " .. delay .. " second(s)." )

		if timer.Exists( timername ) then
			timer.Destroy( timername )
			timer.Adjust( timername, delay, 1, function()
				Connect( origin, callback, RetryOnFailure )
			end )
		else
			timer.Create( timername, delay, 1, function()
				Connect( origin, callback, RetryOnFailure )
			end )
			timer.Start( timername )
		end

	end

	Connect( origin, callback, RetryOnFailure )

end

local StatusClosed = "closed"
local data, b, status, len
local function TickReceive()

	if numclients < 1 then return end

	for _, cl in pairs(clients) do
		
		if cl._state == STATE_CLOSED then continue end
		if !cl._socket then continue end

		data = ""

		while true do

			b, status = cl._socket:receive( 1 )
			if !b then break end

			data = data .. b

		end

		len = #data

		if len > 0 then
			cl:Receive( data, len )
		elseif status == StatusClosed then
			cl._state = STATE_CLOSED
			cl:Close()
			cl:OnDisconnected()
		end

	end

end
hook.Add( "Tick", "WebSocketClientPolling", TickReceive )