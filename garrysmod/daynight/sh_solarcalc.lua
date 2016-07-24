/*---------------------------------------------------------------------------
	Solar Calculator

	References:
	https://github.com/mourner/suncalc
	http://www.suncalc.net/scripts/suncalc.js
	http://stackoverflow.com/a/8764866
---------------------------------------------------------------------------*/

/*
 (c) 2011-2015, Vladimir Agafonkin
 SunCalc is a JavaScript library for calculating sun/moon position and light phases.
 https://github.com/mourner/suncalc
*/

local math, os = math, os
local istable, isnumber = istable, isnumber
local print = print

module( "SolarCalc" )

-- shortcuts for easier to read formulas
local PI = math.pi
local rad = PI / 180
local sin, cos, tan = math.sin, math.cos, math.tan
local asin, acos, atan = math.asin, math.acos, math.atan2

-- sun calculations are based on http://aa.quae.nl/en/reken/zonpositie.html formulas

-- date/time constants and conversions
local daySec = 60 * 60 * 24
local dayMs = 1000 * daySec
local J1970 = 2440588
local J2000 = 2451545

local function GetEpochDate( date )

	local unix
	if istable(date) then
		unix = os.time(date)
	elseif isnumber(date) then
		unix = date
	else
		unix = os.time()
	end

	return unix

end

function ToJulian( date )
	return ( GetEpochDate( date ) * 1000 ) / dayMs - 0.5 + J1970
end

function FromJulian( jdate )
	return os.date( "*t", (jdate + 0.5 - J1970) * daySec )
end

function FromJulianToEpoch( jdate )
	return (jdate + 0.5 - J1970) * daySec
end

function ToDays( date )
	return ToJulian(date) - J2000
end

-- general calculations for position
local e = rad * 23.4397 -- obliquity of the Earth

local function GetRightAscension( l, b )
	return atan(sin(l) * cos(e) - tan(b) * sin(e), cos(l))
end
local function GetDeclination( l, b )
	return asin(sin(b) * cos(e) + cos(b) * sin(e) * sin(l))
end
local function GetAzimuth( H, phi, dec )
	return atan(sin(H), cos(H) * sin(phi) - tan(dec) * cos(phi))
end
local function GetAltitude( H, phi, dec )
	return asin(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(H))
end
local function GetSiderealTime( d, lw )
	return rad * (280.16 + 360.9856235 * d) - lw
end


-- general sun calculations

local function GetSolarMeanAnomoly( d )
	return rad * (357.5291 + 0.98560028 * d)
end
local function GetEquationOfCenter( M )
	return rad * (1.9148 * sin(M) + 0.02 * sin(2 * M) + 0.0003 * sin(3 * M))
end
local function GetEclipticLongitude( M, C )
	local P = rad * 102.9372 -- perihelion of the Earth
	return M + C + P + PI
end
local function GetSunCoords( d )

	local M = GetSolarMeanAnomoly(d)
	local C = GetEquationOfCenter(M)
	local L = GetEclipticLongitude(M, C)

	return {
		dec = GetDeclination(L, 0),
		ra  = GetRightAscension(L, 0)
	}

end


/*---------------------------------------------------------------------------
	Sun
---------------------------------------------------------------------------*/

function GetSunPosition( date, lat, lng )

	if !lat then lat = 37.423225 end
	if !lng then lng = -77.676280 end

	local lw = rad * -lng
	local phi = rad * lat
	local d = ToDays(date)
	local c = GetSunCoords(d)
	local H = GetSiderealTime(d, lw) - c.ra

	return {
		azimuth = GetAzimuth(H, phi, c.dec),
		altitude = GetAltitude(H, phi, c.dec)
	}

end

function GetSunPositionDeg( date, lat, lng )

	local info = GetSunPosition( date, lat, lng )
	info.azimuth = math.deg( info.azimuth )
	info.altitude = math.deg( info.altitude )

	return info
	
end


/*---------------------------------------------------------------------------
	Sun Times
---------------------------------------------------------------------------*/
local times = {
	{ -0.83, 'sunrise',       'sunset' },
	{  -0.3, 'sunriseEnd',    'sunsetStart' },
	{    -6, 'dawn',          'dusk' },
	{   -12, 'nauticalDawn',  'nauticalDusk' },
	{   -18, 'nightEnd',      'night' },
	{     6, 'goldenHourEnd', 'goldenHour' },
}

function AddTimeEvent( angle, risename, setname )
	table.insert( times, { angle, risename, setName } )
end

local J0 = 0.0009

local function GetJulianCycle( d, lw )
	return math.Round(d - J0 - lw / (2 * PI))
end
local function GetApproxTransit( Ht, lw, n )
	return J0 + (Ht + lw) / (2 * PI) + n
end
local function GetSolarTransitJ( ds, M, L )
	return J2000 + ds + 0.0053 * sin(M) - 0.0069 * sin(2 * L)
end
local function GetHourAngle( h, phi, d )
	return acos((sin(h) - sin(phi) * sin(d)) / (cos(phi) * cos(d)))
end

local function FromJulianToDetailed( jdate )

	local result = FromJulian(jdate)
	result.epoch = FromJulianToEpoch(jdate)

	return result

end

function GetSunTimes( date, lat, lng )

	if !lat then lat = 37.423225 end
	if !lng then lng = -77.676280 end

	local lw = rad * -lng
	local phi = rad * lat
	local d = ToDays(date)

	local n = GetJulianCycle(d, lw)
	local ds = GetApproxTransit(0, lw, n)

	local M = GetSolarMeanAnomoly(ds)
	local C = GetEquationOfCenter(M)
	local L = GetEclipticLongitude(M, C)

	local dec = GetDeclination(L, 0)

	local Jnoon = GetSolarTransitJ(ds, M, L)

	local result = {
		solarNoon = FromJulianToDetailed(Jnoon),
		nadir = FromJulianToDetailed(Jnoon - 0.5)
	}

	local time, ang, morningName, eveningName, Jset, Jrise, h, w, a

	for i = 1, #times do
		
		time = times[i]

		h = time[1] * rad
		w = GetHourAngle(h, phi, dec)
		a = GetApproxTransit(w, lw, n)

		Jset = GetSolarTransitJ(a, M, L)
		Jrise = Jnoon - (Jset - Jnoon)

		result[ time[2] ] = FromJulianToDetailed(Jrise)
		result[ time[3] ] = FromJulianToDetailed(Jset)

	end

	return result

end


/*---------------------------------------------------------------------------
	Moon
---------------------------------------------------------------------------*/

local function GetMoonCoords( d ) -- geocentric ecliptic coordinates of the moon

	local L = rad * (218.316 + 13.176396 * d)
	local M = rad * (134.963 + 13.064993 * d)
	local F = rad * (93.272 + 13.229350 * d)

	local l = L + rad * 6.289 * sin(M) -- longitude
	local b = rad * 5.128 * sin(F) -- latitude
	local dt = 385001 - 20905 * cos(M) -- distance to the moon in km

	return {
		ra = GetRightAscension(l, b),
		dec = GetDeclination(l, b),
		dist = dt
	}

end

function GetMoonPosition( date, lat, lng )

	if !lat then lat = 37.423225 end
	if !lng then lng = -77.676280 end

	local lw = rad * -lng
	local phi = rad * lat
	local d = ToDays(date)

	local c = GetMoonCoords(d)
	local H = GetSiderealTime(d, lw) - c.ra
	local h = GetAltitude(H, phi, c.dec)

	-- altitude correction for refraction
	h = h + rad * 0.017 / tan(h + rad * 10.26 / (h + rad * 5.10))

	return {
		azimuth = GetAzimuth(H, phi, c.dec),
		altitude = h,
		distance = c.dist
	}

end

function GetMoonPositionDeg( date, lat, lng )

	local info = GetMoonPosition( date, lat, lng )
	info.azimuth = math.deg( info.azimuth )
	info.altitude = math.deg( info.altitude )

	return info

end