/*---------------------------------------------------------------------------
	Concommands
---------------------------------------------------------------------------*/

concommand.Add( "geolocation_update", function( ply, cmd, args )
	geolocation.Update( nil, true )
end, nil, "Force geolocation to be queried and updated.", FCVAR_SERVER_CAN_EXECUTE )

concommand.Add( "geolocation_set", function( ply, cmd, args )
	geolocation.SetInfo( args[1], args[2] )
end, nil, "Set the geolocation latitude and longitude to the given values.", FCVAR_SERVER_CAN_EXECUTE )

concommand.Add( "geolocation_info", function( ply, cmd, args )
	print( "GEOLOCATION INFO:" )
	print( "Latitude", geolocation.Latitude() )
	print( "Longitude", geolocation.Longitude() )
	print( "Modified", geolocation.LastModified() )
end, nil, "Print the current geolocation info to the console.", FCVAR_SERVER_CAN_EXECUTE )


/*---------------------------------------------------------------------------
	Module
---------------------------------------------------------------------------*/

local file = file
local http = http
local os = os
local string = string
local util = util
local isfunction = isfunction
local pcall = pcall
local print = print
local tonumber = tonumber

module( "geolocation" )

local fname = "geolocation.txt"
local latitude, longitude

function Latitude()
	return latitude and latitude or 38
end

function Longitude()
	return longitude and longitude or -80
end

function Info()
	return Latitude(), Longitude()
end

function SetInfo( lat, lng, ReadFromFile )

	latitude = tonumber(lat)
	longitude = tonumber(lng)

	if !ReadFromFile then
		file.Write( fname, lat .. "," .. lng )
	end

end

local GeolocationURL = "http://freegeoip.net/json/"
function Update( callback, force )

	if !force then

		-- Don't need to call the API more than once
		-- Read from saved file
		local fcontent = file.Read( "geolocation.txt", "DATA" )
		if fcontent and string.len( fcontent ) != 0 then
			
			local tbl = string.Explode( ',', fcontent )
			if #tbl == 2 then

				SetInfo( tbl[1], tbl[2], true )

				if isfunction(callback) then
					pcall( callback, Info() )
				end

				return

			end

		end

	end

	local function ParseResponse( response )

		response = util.JSONToTable( response )

		if response.city != "" then
			
			local lat, lng = tonumber(response.latitude), tonumber(response.longitude)
			SetInfo( lat, lng )

			if isfunction(callback) then
				pcall( callback, lat, lng )
			end

			if force then
				print( "Geolocation acquired: ", lat, ", ", lng )
			end

		end

	end

	http.Fetch(
		GeolocationURL,
		function(body, length, headers, code)
			if code == 200 then
				pcall( ParseResponse, body )
			end
		end,
		function()
			if isfunction(callback) then
				pcall( callback, Info() )
			end
		end
	)

end

function LastModified()
	return os.date( "%m.%d.%Y %H:%M:%S", file.Time( fname, "DATA" ) )
end