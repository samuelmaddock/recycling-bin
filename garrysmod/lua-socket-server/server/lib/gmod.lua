TYPE_ANGLE = 11
TYPE_BLUE = 1
TYPE_BOOL = 1
TYPE_COLOR = 255
TYPE_CONVAR = 27
TYPE_COUNT = 39
TYPE_DAMAGEINFO = 15
TYPE_DLIGHT = 30
TYPE_EFFECTDATA = 16
TYPE_ENTITY = 9
TYPE_FILE = 34
TYPE_FUNCTION = 6
TYPE_IMESH = 28
TYPE_INVALID = 1
TYPE_LIGHTUSERDATA = 30
TYPE_MATERIAL = 21
TYPE_MATRIX = 29
TYPE_MOVEDATA = 17
TYPE_NIL = 0
TYPE_NUMBER = 3
TYPE_ORANGE = 2
TYPE_PANEL = 22
TYPE_PARTICLE = 23
TYPE_PARTICLEEMITTER = 24
TYPE_PHYSOBJ = 12
TYPE_PIXELVISHANDLE = 30
TYPE_RECIPIENTFILTER = 18
TYPE_RESTORE = 14
TYPE_SAVE = 13
TYPE_SCRIPTEDVEHICLE = 20
TYPE_SOUND = 30
TYPE_STRING = 4
TYPE_TABLE = 5
TYPE_TEXTURE = 24
TYPE_THREAD = 8
TYPE_USERCMD = 19
TYPE_USERMSG = 26
TYPE_VECTOR = 10
TYPE_VIDEO = 33

local conversion = {
	["nil"] = TYPE_NIL,
	["string"] = TYPE_STRING,
	["number"] = TYPE_NUMBER,
	["table"] = TYPE_TABLE,
	["boolean"] = TYPE_BOOL,
}

function TypeID( obj )
	return obj and conversion[ type( obj ) ] or TYPE_NIL
end

function Entity( i )
	return i
end

function Msg( ... )
	local tbl = {}

	for _, v in pairs({...}) do
		table.insert(tbl, tostring(v))
	end

	local str = table.concat(tbl)
	io.write(str)
end


dofile "lib/gmod/util.lua"
dofile "lib/gmod/table.lua"
dofile "lib/gmod/buffer.lua"
dofile "lib/gmod/color.lua"
dofile "lib/gmod/hook.lua"
dofile "lib/gmod/net.lua"
dofile "lib/gmod/string.lua"
