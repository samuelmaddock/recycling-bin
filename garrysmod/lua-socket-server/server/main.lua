-- fix paths for modules
package.path = ";lib\\?.lua;lib\\gmod\\?.lua" .. package.path
package.cpath = ";lib\\?.dll" .. package.cpath

-- dependencies
dofile "util.lua"
dofile "lib/gmod.lua"

-- global config
CONFIG = {
	host = "127.0.0.1",
	port = 27064,
	password = "default"
}

local f = readFile( "config.json" )
if f then
	table.Merge( CONFIG, jsonDecode(f) )
end

-- base server
include "detour.lua"
include "server.lua"

-- GMT
include "gmt/server.lua"

server.CreateServer( CONFIG.host, CONFIG.port, CONFIG.serverType )
server.loop()
