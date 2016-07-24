require "copas"

local url = require "socket.url"
local copas = copas

errorurl = {}

local LENGTH_PATTERN = "Content%-Length: (%d+)"

-- decode 'application/x-www-form-urlencoded'
local function decodeForm( form )
	local keyvalues = string.Explode( "&", form )
	local tbl = {}

	for _, v in ipairs( keyvalues ) do
		local kv = string.Explode( "=", v )
		local key = kv[1]
		local value = kv[2]

		value = string.Replace( value, "+", " " )
		value = url.unescape( value )

		tbl[ key ] = value
	end

	return tbl
end

local function connection( skt )
	skt:setoption("tcp-nodelay", true)

	local data, err, len, contentLength

	-- read request
	while true do
		data, err = skt:receive() -- read line

		if err then
			break
		end

		len = data:len()
		if len == 0 then
			-- last line
			break
		end

		-- attempt to grab content length
		contentLength = string.match( data, LENGTH_PATTERN )
	end
	
	local body

	if contentLength then
		body, err = skt:receive( contentLength )
	end

	if body then
		local form = decodeForm( body )

		local ip, port = skt:getsockname()
		form.ip = ip
		form.port = port

		hook.Run( "OnLuaError", form )
	end
end

function errorurl.serve( host, port )
	if not host then host = "127.0.0.1" end
	if not port then port = 8080 end

	local sock = assert( socket.bind( host, port ) )
	sock:settimeout( 0 )

	local ip, port = sock:getsockname()
	local addr = ("%s:%i"):format( ip, port )

	print( ("[ERROR-URL] Web server started on %s"):format( addr ) )

	copas.addserver( sock, connection )
end
