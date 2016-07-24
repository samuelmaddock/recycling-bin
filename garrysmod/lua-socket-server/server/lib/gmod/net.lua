if not bit then require "bit" end

local net = {}
net.Receivers = {}

local netbuf = nil

function net.SetData( data )
	-- print("netbuf:", netbuf, netbuf and netbuf:Length() or 0)
	assert( netbuf == nil, "net: attempted to set data with an existing buffer" )
	netbuf = Buffer( data )
end

function net.ClearData()
	netbuf = nil
end

--
-- Set up a function to receive network messages
--
function net.Receive( name, func )
		
	net.Receivers[ name:lower() ] = func

end

--
-- A message has been received from the network..
--
function net.Incoming( len, client )

	-- local i = net.ReadHeader()
	-- local strName = util.NetworkIDToString( i )
	local strName = net.ReadHeader()
	if not strName then return end
	
	if not client:IsAuthenticated() and strName ~= "auth" then
		-- TODO: drop?
		return
	end

	local func = net.Receivers[ strName:lower() ]
	if not func then return end

	--
	-- len includes the 16 byte int which told us the message name
	--
	len = len - 16
	
	func( len, client )

end

--
-- Read/Write an entity to the stream
--
function net.WriteEntity( ent )

	if not IsValid( ent ) then 
		net.WriteUInt( 0, 16 )
	else
		net.WriteUInt( ent:EntIndex(), 16 )
	end

end

function net.ReadEntity()

	local i = net.ReadUInt( 16 )
	if not i then return end
	
	return Entity( i )
	
end

--
-- Read/Write a color to/from the stream
--
function net.WriteColor( col )

	assert( IsColor( col ), "net.WriteColor: color expected, got ".. type( col ) )

	net.WriteUInt( col.r, 8 )
	net.WriteUInt( col.g, 8 )
	net.WriteUInt( col.b, 8 )
	net.WriteUInt( col.a, 8 )

end

function net.ReadColor()

	local r, g, b, a = 
		net.ReadUInt( 8 ),
		net.ReadUInt( 8 ),
		net.ReadUInt( 8 ),
		net.ReadUInt( 8 )

	return Color( r, g, b, a )

end


--[[
	INTERNAL GMOD NET FUNCTIONS:

	net.Broadcast
	net.Send
	net.SendOmit
	net.SendPAS
	net.SendPVS
	net.BytesWritten
	net.ReadAngle
	net.ReadBit
	net.ReadData
	net.ReadDouble
	net.ReadFloat
	net.ReadHeader
	net.ReadInt
	net.ReadString
	net.ReadUInt
	net.ReadVector
	net.Start
	net.WriteAngle
	net.WriteBit
	net.WriteData
	net.WriteDouble
	net.WriteFloat
	net.WriteHeader
	net.WriteInt
	net.WriteString
	net.WriteUInt
	net.WriteVector
]]

function net.Start( message )
	-- print("netbuf:", netbuf, netbuf and netbuf:Length() or 0)
	-- assert( netbuf == nil, "net: attempt to start message with an existing buffer" )

	netbuf = Buffer()

	-- write header
	-- TODO: eventually use network cache like gmod?
	netbuf:WriteString( message )
end

function net.ReadHeader()
	assert( netbuf, "net: netbuf == nil during a read/write operation." )
	return netbuf:ReadString()
end

function net.BytesWritten()
	assert( netbuf, "net: netbuf == nil during a read/write operation." )
	return netbuf:Length()
end

function net.WriteByte( str )
	assert( netbuf, "net: netbuf == nil during a read/write operation." )
	netbuf:WriteByte( str )
end

function net.ReadByte()
	assert( netbuf, "net: netbuf == nil during a read/write operation." )
	return netbuf:ReadByte()
end

function net.WriteString( str )
	assert( netbuf, "net: netbuf == nil during a read/write operation." )
	netbuf:WriteString( str )
end

function net.ReadString()
	assert( netbuf, "net: netbuf == nil during a read/write operation." )
	return netbuf:ReadString()
end

function net.WriteInt( int )
	assert( netbuf, "net: netbuf == nil during a read/write operation." )
	netbuf:WriteInt( int )
end

function net.ReadInt()
	assert( netbuf, "net: netbuf == nil during a read/write operation." )
	return netbuf:ReadInt()
end

function net.WriteFloat( float )
	assert( netbuf, "net: netbuf == nil during a read/write operation." )
	netbuf:WriteFloat( float )
end

function net.ReadFloat()
	assert( netbuf, "net: netbuf == nil during a read/write operation." )
	return netbuf:ReadFloat()
end

function net.WriteTable( tab )
	netbuf:WriteTable( tab )
end

function net.ReadTable()
	return netbuf:ReadTable()
end

function net.WriteType( v )
	netbuf:WriteType( v )
end

function net.ReadType( typeid )
	return netbuf:ReadType( typeid )
end

function net.Send( obj )
	local buf = netbuf
	net.ClearData()

	assert( buf, "net: buf == nil" )

	local tbl

	if type(obj) == "table" and (#obj > 0) then
		tbl = obj
	else
		tbl = { obj }
	end
	
	for _, cl in pairs( tbl ) do
		cl:Send( buf )
	end
end

function net.SendSock( sock )
	local buf = netbuf
	net.ClearData()

	assert( buf, "net.SendSock: buf == nil" )

	local len = buf:Length()
	local lenstr = string.char( bit.rshift( len, 8 ), bit.band( n, 0xFF ) )
	sock:send( lenstr .. buf:GetRaw() )
end

_G.net = net
