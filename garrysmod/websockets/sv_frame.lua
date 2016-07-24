module( 'websocket', package.seeall )

OPCODE_CONTFRAME = 0x0 -- Continuation frame
OPCODE_TEXT		= 0x1
OPCODE_BINARY	= 0x2
OPCODE_CLOSE	= 0x8
OPCODE_PING		= 0x9
OPCODE_PONG		= 0xA

CLOSE_NORMAL 			= 1000
CLOSE_GOINGAWAY 		= 1001
CLOSE_PROTOCOLERROR 	= 1002
CLOSE_UNSUPPORTEDDATA 	= 1003
CLOSE_FRAMETOOLARGE 	= 1004
CLOSE_NOSTATUSRCVD	 	= 1005
CLOSE_ABNORMALCLOSURE	= 1006
CLOSE_BADMESSAGEDATA	= 1007
CLOSE_POLICYVIOLATION	= 1008
CLOSE_TOOBIGDATA		= 1009
CLOSE_EXTENSIONMISMATCH	= 1010

MAX_PAYLOADLENGTH = 125

FRAME = {}
FRAME.__index = FRAME

FRAME.SetLength = function( self, len )
	if self.data:Length() >= 2 then
		self.data.buffer[2] = len
	else
		self.data:WriteByte( len )
	end
end

FRAME.GetLength = function( self, len )
	if self.data:Length() >= 2 then
		return self.data.buffer[2]
	end
end

FRAME.PayloadType = function( self )
	return self.header.opcode
end

local function NewFrame( opcode, fin, maskingkey )

	local frame = {}
	setmetatable( frame, FRAME )

	frame.header = {}
	frame.header.fin = fin or true
	frame.header.rsv = {}
	frame.header.opcode = opcode or OPCODE_TEXT
	frame.header.length = 0
	frame.header.maskingkey = maskingkey or BitBuff()

	frame.data = BitBuff()

	return frame

end

-- http://tools.ietf.org/html/rfc6455#section-5
-- https://code.google.com/p/go/source/browse/websocket/hybi.go?repo=net

function WriteFrame( buf, opcode, fin, maskingkey )

	local frame = NewFrame( opcode, fin, maskingkey )
	local header = BitBuff()
	local b = 0x0

	if fin then
		b = bit.bor( b, 0x80 )
	end

	/*for i = 0, 3 do
		if frame.header.rsv
	end*/

	b = bit.bor( b, frame.header.opcode )
	header:WriteByte(b)

	if frame.header.maskingkey:Length() != 0 then
		b = 0x80
	else
		b = 0
	end

	local lengthFields = 0
	local length = buf:Length()

	if length <= 125 then
		b = bit.bor( b, length % 255 ) -- TODO: is this correct?
	elseif length < 65536 then
		b = bit.bor( b, 126 )
		lengthFields = 2
	else
		b = bit.bor( b, 127 )
		lengthFields = 8
	end

	header:WriteByte(b)

	if lengthFields > 0 then
		local j
		for i = 0, lengthFields do
			j = (lengthFields - i - 1) * 8
			b = bit.band( bit.rshift( length, j ), 0xff )
			header:WriteByte(b)
		end
	end

	if frame.header.maskingkey:Length() != 0 then

		if frame.header.maskingkey:Length() != 4 then
			error( "Invalid masking key" )
		end

		header:Append( frame.header.maskingkey )

		for i = 1, length do
			frame.data:WriteByte( bit.bxor( buf:ReadPosition( i ), frame.header.maskingkey:ReadPosition( ((i-1)%4)+1 ) ) )
		end

	else

		frame.data:Append( buf )

	end

	frame.data = header:Append( frame.data )

	return frame

end

function ReadFrame( data )

	local buf = istable(data) and data or BitBuff(data)
	buf:Seek(0)

	local frame = NewFrame()
	local header = BitBuff()
	local b

	-- First byte. FIN/RSV1/RSV2/RSV3/OpCode(4bits)
	b = buf:ReadByte()
	header:WriteByte(b)

	frame.header.fin = bit.band( bit.rshift( b, 7 ), 1 ) != 0

	for i = 1, 4 do
		frame.header.rsv[i] = bit.band( bit.rshift( b, math.abs(7-i) ), 1 ) != 0
	end

	frame.header.opcode = bit.band( b, 0x0f )

	-- Second byte. Mask/Payload len(7bits)
	b = buf:ReadByte()
	header:WriteByte(b)
	local mask = bit.band( b, 0x80 ) != 0

	b = bit.band( b, 0x7f )

	local lengthFields = 0

	if b <= 125 then
		frame.header.length = b
	elseif b == 126 then
		lengthFields = 2
	elseif b == 127 then
		lengthFields = 8
	end

	if frame.header.opcode >= OPCODE_CLOSE and b > 125 then
		error( "Received control frame with excess of 125 bytes" )
	end

	if lengthFields > 0 then

		if lengthFields == 2 then
			b = buf:ReadShort()
			header:WriteShort(b)
			frame.header.length = frame.header.length + b
		elseif lengthFields == 8 then
			b = buf:ReadLong()
			header:WriteLong(b)
			frame.header.length = frame.header.length + b
		end

	end

	-- TODO: Test mask
	if mask then
		for i = 0, 3 do
			b = buf:ReadByte()
			header:WriteByte(b)
			frame.header.maskingkey:WriteByte(b)
		end
	end

	frame.length = header:Length() + frame.header.length
	frame.data = buf:Sub( header:Length() + 1 - lengthFields, frame.length )

	if buf:Length() > frame.length then
		frame.overflow = buf:Sub( frame.length + 1 )
	end

	return frame

end

function WriteClose( status, reason )

	local frame = NewFrame( OPCODE_CLOSE )

	-- Write opcode
	frame.data:WriteByte( bit.bor( bit.bor( 0x0, 0x80 ), frame.header.opcode ) )

	-- Write length
	frame:SetLength( 0 )

	-- Write status (optional)
	if status then

		local buf = BitBuff()
		buf:WriteShort( status )

		frame.data:Append( buf )
		frame:SetLength( 0x02 ) -- change length

	end
	
	-- Write reason (optional)
	if reason then
		local buf = BitBuff( reason )
		frame.data:Append( buf )
		frame:SetLength( frame:GetLength() + #reason )
	end

	return frame.data

end

/*function WritePing()

	local frame = NewFrame( OPCODE_PING )

	

	return frame.data

end

function WritePong()

	local frame = NewFrame( OPCODE_PONG )

	

	return frame.data

end*/