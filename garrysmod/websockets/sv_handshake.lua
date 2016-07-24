module( 'websocket', package.seeall )

local TIMEOUT = 5
local GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11" -- RFC4122

local function generateNonce()

	local key = BitBuff()

	for i = 1, 16 do
		key:WriteByte( math.random(127) )
	end

	return base64.enc( key:ToString() )

end

local TimerPrefix = "HandshakeAsync"

/*---------------------------------------------------------------------------
	Name:	ClientHandshake
	Desc:	Perform the client handshake with the server.
	Ref: 	http://tools.ietf.org/html/rfc6455#section-1.3
			http://tools.ietf.org/html/rfc6455#section-4.1
---------------------------------------------------------------------------*/
function ClientHandshake( client, config )

	local sock = client:GetSocket()
	local nonce = generateNonce()

	local function HandshakeResponse( resp )

		-- TODO: Handle overflow data

		local headers = http.ParseHeader( resp )

		-- Validate Protocol Switch
		-- TODO: Have http.ParseHeader parse the status code (101)
		if !headers._Head or !string.find( headers._Head, '101 Switching Protocols' ) then
			client:OnFailure( "Handshake Response: Failed to switch protocols." )
			return
		end

		-- Validate upgrade
		if !headers.Upgrade or string.lower( headers.Upgrade ) != "websocket" then
			client:OnFailure( "Handshake Response: Invalid Upgrade, " .. tostring(headers.Upgrade) )
			return
		end

		-- Validate connection
		if !headers.Connection or string.lower( headers.Connection ) != "upgrade" then
			client:OnFailure( "Handshake Response: Invalid Connection, " .. tostring(headers.Connection) )
			return
		end

		-- TODO: Validate Sec-WebSocket-Accept hash
		/*local accept = headers["Sec-WebSocket-Accept"]
		local hash = base64.enc( util.SHA1( nonce .. GUID ) )

		if accept == hash then
			print( "Success" )
		else
			print( "Handshake response: Hash mismatch" )
			print( accept )
			print( hash )
			print('')
			print(resp)
			print('')
		end*/

		-- TODO: Check extension(s) match (if supplied)
		-- TODO: Check protocol(s) match (if supplied)

		client._state = STATE_OPEN
		client:OnConnected()

	end

	local TimerName = TimerPrefix .. client:GetID()
	local response = ""
	local start = CurTime()
	local line

	-- Async handshake response
	timer.Create( TimerName, engine.TickInterval(), 0, function()

		line = sock:receive('*l')

		if line then
			response = response .. line .. "\n"
		elseif string.len( response ) > 0 then
			timer.Destroy( TimerName )
			HandshakeResponse( response )
		elseif ( CurTime() - start ) > TIMEOUT then
			timer.Destroy( TimerName )
			client:OnTimeout()
		end

	end )

	timer.Start( TimerName )

	-- sock:send("GET " .. config.uri .. "?encoding=text HTTP/1.1\r\n")
	sock:send("GET " .. config.path .. " HTTP/1.1\r\n")
	sock:send("Origin: " .. config.host .. "\r\n")
	sock:send("Host: " .. config.origin .. "\r\n")
	sock:send("Sec-WebSocket-Key: " .. nonce .. "\r\n")
	sock:send("Upgrade: websocket\r\n")
	sock:send("Sec-WebSocket-Extensions: garrysmod\r\n")
	sock:send("Connection: Upgrade\r\n")
	sock:send("Sec-WebSocket-Version: 13\r\n")
	-- sock:send("Sec-WebSocket-Protocol: chat\r\n")
	sock:send("\r\n")

end