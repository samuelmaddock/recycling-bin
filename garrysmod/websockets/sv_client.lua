module( 'websocket', package.seeall )

STATE_CLOSED 	= 1
STATE_OPEN 		= 2

CLIENT = {}
CLIENT.__index = CLIENT
CLIENT._state = STATE_CLOSED

function CLIENT:IsValid()
	return self:IsConnected()
end

function CLIENT:GetID()
	return self._id or -1
end

function CLIENT:GetState()
	return self._state or STATE_CLOSED
end

function CLIENT:GetSocket()
	return self._socket
end

function CLIENT:IsConnected()
	return self._state == STATE_OPEN
end

function CLIENT:GetURI()
	return self._config.uri
end

function CLIENT:GetHost()
	return self._config.host
end

function CLIENT:GetPort()
	return self._config.port
end

function CLIENT:Receive( data, len, overflow )

	if !overflow then
		self._bytesReceived = self._bytesReceived + len
		print( "Client #" .. self:GetID() .. " received data["..len.."]" )
	end

	local status, frame = pcall( ReadFrame, data )
	if !status then
		ErrorNoHalt( "Client Receive Error: " .. tostring(frame) .. "\n" )
		return
	end

	-- PrintTable(frame)
	-- print( "DATA: " .. frame.data:ToString() )

	local payloadType = frame:PayloadType()

	if payloadType == OPCODE_CONTFRAME then

		print("Received continuation frame")

	elseif payloadType == OPCODE_TEXT or payloadType == OPCODE_BINARY then

		print( "Received " .. (payloadType == OPCODE_TEXT and "text" or "binary") .. " frame" )

		if !frame.header.fin then
			-- TODO: Finish/test this
			print("TEXT FRAME NOT FIN : Not implemented yet! (Yell at Sam)")
			self._overflow = self._overflow:Append( frame.data )
			self._overflow.opcode = payloadType
		else
			self:OnReceive( frame.data )
		end

	elseif payloadType == OPCODE_CLOSE then

		print("Received close frame")

		self:Close( CLOSE_NORMAL )

	elseif payloadType == OPCODE_PING then

		print("Received ping frame: " .. frame.data:ToString() )

		local pong = BitBuff()
		pong:WriteByte( bit.bor( OPCODE_PONG, 0x80 ) )
		pong:WriteByte( frame.data:Length() )

		if len > 2 then
			pong:Append( frame.data )
		end

		self:Send( pong )

	elseif payloadType == OPCODE_PONG then

		print("Received pong frame")

	else
		ErrorNoHalt("Client #"..self:GetID().." : Unhandled data["..len.."], Opcode: "..payloadType.."\n")
	end

	if frame.overflow then
		-- print( "OVERFLOW: " .. frame.overflow:ToString() )
		self:Receive( frame.overflow, frame.overflow:Length(), true )
	end

end

function CLIENT:Send( buf )

	if !istable(buf) then
		ErrorNoHalt("Attempted to send non-buffer data.\n")
		return
	end

	buf:SendTo( self._socket )

	print( "Client #" .. self:GetID() .. " sent data["..buf:Length().."]" )

	self._bytesSent = self._bytesSent + buf:Length()

end

function CLIENT:SendFrame( buf, opcode )

	if !istable(buf) then
		ErrorNoHalt("Attempted to send non-buffer data.\n")
		return
	end

	buf:Seek(0)

	-- only supports one frame fragment at the moment :(
	local frame, err = WriteFrame( buf, opcode, true )
	if err then
		ErrorNoHalt( err .. "\n" )
		return
	end

	frame.data:SendTo( self._socket )

	print( "Client #" .. self:GetID() .. " sent data["..frame.data:Length().."]" )

	self._bytesSent = self._bytesSent + frame.data:Length()

end

function CLIENT:SendString( str )
	local buf = BitBuff()
	buf:WriteString( str )
	self:SendFrame( buf, OPCODE_TEXT )
end

function CLIENT:SendBinary( buf )
	self:SendFrame( buf, OPCODE_BINARY )
end

function CLIENT:Close( status, reason )
	
	if self._state == STATE_OPEN then

		local frame = WriteClose( status or CLOSE_NORMAL, reason )
		self:Send( frame )

		self._state = STATE_CLOSED
		
	end

	self._socket:shutdown()
	self._socket:close()

end

function CLIENT:OnConnected()
	print( "Client:OnConnected" )
end

function CLIENT:OnDisconnected()
	print( "Client:OnDisconnected" )
end

function CLIENT:OnReceive( buf )

	/*

		TODO: Implement hook structure

		local hookname = data:ReadString()
		local args = data:Remaining()

		CallHook( hookname, args )

		-- CallHook will handle calls for parsing buffer data 
		-- before actually calling the hook. Otherwise it will
		-- just pass the buffer with the hook.

	*/
	-- print( "received: " .. ( istable(buf) and buf:ToString() or tostring(buf) ) )

	if buf then
		print( "received: " .. buf:ReadString() )
	else
		print( "received: nil" )
	end

end

function CLIENT:OnTimeout()
	self:OnFailure( "Connection to client #" .. self:GetID() .. " has timed out." )
end

function CLIENT:OnFailure( str )
	ErrorNoHalt( str .. "\n" )
	self:Close()
end


/*---------------------------------------------------------------------------
	Client Hooks
---------------------------------------------------------------------------*/

function CLIENT:AddHook( name, unique, callback )
	hook.Add( self._hookPrefix .. name, unique, callback )
	self._hooks[ name ] = true
end

function CLIENT:CallHook( name, ... )
	hook.Call( self._hookPrefix .. name, GAMEMODE or GM, ... )
end

function CLIENT:GetHookTable()
	local hooktbl, tbl = hook.GetTable(), {}
	for k, _ in pairs( hooks ) do
		table.insert( tbl, hooktbl[ self._hookPrefix .. k ] )
	end
	return tbl
end

function CLIENT:RemoveHook( name, unique )
	hook.Remove( self._hookPrefix .. name, unique )
	self._hooks[ name ] = nil
end

function CLIENT:RunHook( name, ... )
	return hook.Run( self._hookPrefix .. name, ... )
end