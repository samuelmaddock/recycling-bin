local host, port = "localhost", 4321

local function InitSamWebSocket()

	local ws = SAMWEBSOCKET

	if IsValid(ws) then
		websocket.Close( host, port )
	end

	local gameip = game.GetIP()

	if websocket.CVAR_CONNECT:GetBool() or not gameip then
		ws = websocket.Create( host, port )		-- Sam's node.js server
	end

	if !ws then
		print("Failed to create WebSocket (Sam's Server)")
		return
	end

	function ws:OnConnected()

		hook.Call( "SamWebSocketConnected", GAMEMODE, self )

		for _, ply in pairs(player.GetAll()) do
			if ply:IsAdmin() then
				ply:SendLua( 'GAMEMODE:AddNotify( "Connected to Sam\'s WebSocket Server", NOTIFY_HINT, 5 )' )	
			end
		end

	end

	function ws:OnDisconnected()

		for _, ply in pairs(player.GetAll()) do
			if ply:IsAdmin() then
				ply:SendLua( 'GAMEMODE:AddNotify( "Disconnected to Sam\'s WebSocket Server", NOTIFY_HINT, 5 )' )	
			end
		end

	end

	function ws:OnReceive( buf )

		local hookname = buf:ReadString()

		self:CallHook( hookname, buf:Remaining() )

	end

	SAMWEBSOCKET = ws -- global var

end

websocket.AttemptConnection( host, port, InitSamWebSocket, true )
hook.Add( "OnGamemodeLoaded", "InitSamWebSocket", InitSamWebSocket )
