if not bit then require "bit" end

local net = {}
net.Receivers = {}

local buf

function net.SetData( data )
	assert( buf == nil, "net: attempted to set data with an existing buffer" )
	buf = Buffer( data )
end

function net.ClearData()
	buf = nil
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
function net.Incoming( len )

	-- local i = net.ReadHeader()
	-- local strName = util.NetworkIDToString( i )
	local strName = net.ReadHeader()
	
	if not strName then return end
	
	local func = net.Receivers[ strName:lower() ]
	if not func then return end

	--
	-- len includes the 16 byte int which told us the message name
	--
	len = len - 16
	
	func( len )

	-- func should be finished reading buf
	buf = nil

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

--
-- Write a whole table to the stream
-- This is less optimal than writing each
-- item indivdually and in a specific order
-- because it adds type information before each var
--
function net.WriteTable( tab )

	for k, v in pairs( tab ) do
	
		net.WriteType( k )
		net.WriteType( v )
	
	end
	
	-- End of table
	net.WriteUInt( 0, 8 )

end

function net.ReadTable()

	local tab = {}
	
	while true do
	
		local t = net.ReadUInt( 8 )
		if ( t == 0 ) then return tab end
		local k = net.ReadType( t )
	
		local t = net.ReadUInt( 8 )
		if ( t == 0 ) then return tab end
		local v = net.ReadType( t )
		
		tab[ k ] = v
		
	end

end

net.WriteVars = 
{
	[TYPE_NIL]			= function ( t, v )	net.WriteUInt( t, 8 )								end,
	[TYPE_STRING]		= function ( t, v )	net.WriteUInt( t, 8 )	net.WriteString( v )		end,
	[TYPE_NUMBER]		= function ( t, v )	net.WriteUInt( t, 8 )	net.WriteDouble( v )		end,
	[TYPE_TABLE]		= function ( t, v )	net.WriteUInt( t, 8 )	net.WriteTable( v )			end,
	[TYPE_BOOL]			= function ( t, v )	net.WriteUInt( t, 8 )	net.WriteBit( v )			end,
	[TYPE_ENTITY]		= function ( t, v )	net.WriteUInt( t, 8 )	net.WriteEntity( v )		end,
	[TYPE_VECTOR]		= function ( t, v )	net.WriteUInt( t, 8 )	net.WriteVector( v )		end,
	[TYPE_ANGLE]		= function ( t, v )	net.WriteUInt( t, 8 )	net.WriteAngle( v )			end,
	[TYPE_COLOR]		= function ( t, v ) net.WriteUInt( t, 8 )	net.WriteColor( v )			end,
		
}

function net.WriteType( v )
	local typeid = nil

	if IsColor( v ) then
		typeid = TYPE_COLOR
	else
		typeid = TypeID( v )
	end

	local wv = net.WriteVars[ typeid ]
	if ( wv ) then return wv( typeid, v ) end
	
	error( "net.WriteType: Couldn't write " .. type( v ) .. " (type " .. typeid .. ")" )

end

net.ReadVars = 
{
	[TYPE_NIL]		= function ()	return end,
	[TYPE_STRING]	= function ()	return net.ReadString() end,
	[TYPE_NUMBER]	= function ()	return net.ReadDouble() end,
	[TYPE_TABLE]	= function ()	return net.ReadTable() end,
	[TYPE_BOOL]		= function ()	return net.ReadBit() == 1 end,
	[TYPE_ENTITY]	= function ()	return net.ReadEntity() end,
	[TYPE_VECTOR]	= function ()	return net.ReadVector() end,
	[TYPE_ANGLE]	= function ()	return net.ReadAngle() end,
	[TYPE_COLOR]	= function ()	return net.ReadColor() end,
}

function net.ReadType( typeid )

	local rv = net.ReadVars[ typeid ]
	if ( rv ) then return rv( v ) end

	error( "net.ReadType: Couldn't read type " .. typeid )
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

net.Start = function( message )
	buf = Buffer()

	-- write header
	-- TODO: eventually use network cache like gmod?
	buf:WriteString( message )
end

net.ReadHeader = function()
	assert( buf, "net: buf == nil during a read/write operation." )
	return buf:ReadString()
end

net.BytesWritten = function()
	assert( buf, "net: buf == nil during a read/write operation." )
	return buf:Length()
end

net.WriteString = function( str )
	assert( buf, "net: buf == nil during a read/write operation." )
	buf:WriteString( str )
end

net.ReadString = function( str )
	assert( buf, "net: buf == nil during a read/write operation." )
	return buf:ReadString( str )
end

net.WriteInt = function( int )
	assert( buf, "net: buf == nil during a read/write operation." )
	buf:WriteInt( int )
end

net.ReadInt = function( int )
	assert( buf, "net: buf == nil during a read/write operation." )
	return buf:ReadInt( int )
end

net.WriteFloat = function( float )
	assert( buf, "net: buf == nil during a read/write operation." )
	buf:WriteFloat( float )
end

net.ReadFloat = function( float )
	assert( buf, "net: buf == nil during a read/write operation." )
	return buf:ReadFloat( float )
end

net.SendToServer = function()
	local b = buf
	net.ClearData()

	assert( b, "net: buf == nil" )

	global.Send( b )
end

_G.snet = net
