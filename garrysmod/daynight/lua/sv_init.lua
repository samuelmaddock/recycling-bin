/*---------------------------------------------------------------------------
	Convars
---------------------------------------------------------------------------*/

local CVAR_INTERVAL = CreateConVar( "daynight_interval", 10, { FCVAR_ARCHIVE, FCVAR_DONTRECORD }, "Interval of daynight think." )
local CVAR_TIMESCALE = CreateConVar( "daynight_timescale", 1, { FCVAR_ARCHIVE, FCVAR_DONTRECORD }, "Timescale for daynight cycle." )

cvars.AddChangeCallback( "daynight_interval", function( cmd, old, new )
	new = tonumber(new)
	if !new then return end
	daynight.SetInterval( new )
end )

cvars.AddChangeCallback( "daynight_timescale", function( cmd, old, new )

	new = tonumber(new)

	if !new then return end

	if new <= 0 then
		RunConsoleCommand( "daynight_timescale", 0.1 )
	else
		daynight.UpdateEntities( new )
	end

end )

concommand.Add( "daynight_int", function( ply, cmd, args )
	local num = tonumber(args[1])
	if !num then return end
	RunConsoleCommand( "daynight_interval", num )
	daynight.SetInterval( num )
end)

concommand.Add( "daynight_sun", function( ply, cmd, args )
	local azimuth, elevation = SolarCalc.GetSunPosition()
	MsgSam(azimuth)
	MsgSam(elevation)
end)

concommand.Add( "daynight_info", function( ply, cmd, args )

	local latitude, longitude = geolocation.Info()
	local azimuth, elevation = SolarCalc.GetSunPosition()

	print( "Latitude: ", latitude )
	print( "Longitude: ", longitude )
	print( "Elevation: ", elevation, " degrees" )
	print( "Azimuth: ", azimuth, " degrees" )

end)

/*---------------------------------------------------------------------------
	daynight module
---------------------------------------------------------------------------*/
module( 'daynight', package.seeall )

local EnvSky, EnvSun, EnvMoon, EnvFog

function SetupEntities()

	if !IsValid(EnvSky) then
		local list = ents.FindByClass( "env_skypaint" )
		if ( #list > 0 ) then
			EnvSky = list[1]
		end
	end

	if !IsValid(EnvSun) then
		local list = ents.FindByClass( "env_sun" )
		if ( #list > 0 ) then
			EnvSun = list[1]
		end
	end

	if !IsValid(EnvMoon) then
		local list = ents.FindByClass( "env_moon" )
		if ( #list > 0 ) then
			EnvMoon = list[1]
		else
			EnvMoon = ents.Create( "env_moon" )
			EnvMoon:SetPos( Vector(63,-61,-12306) ) -- debug
			EnvMoon:Spawn()
		end
	end

	if !IsValid(EnvFog) then
		local list = ents.FindByClass( "env_fog" )
		if ( #list > 0 ) then
			EnvFog = list[1]
		else
			EnvFog = ents.Create( "env_fog" )
			EnvFog:SetPos( Vector(63,-61,-12306) ) -- debug
			EnvFog:Spawn()
			EnvFog:SetFogStart( 0 )
			EnvFog:SetFogEnd( 0 )
			EnvFog:SetDensity( 0 )
			EnvFog:SetFogColor( Vector(0,0,0) )
		end
	end

	return IsValid( EnvSky ) and IsValid( EnvSun ) and IsValid( EnvMoon ) and IsValid( EnvFog )

end

function UpdateEntities( timescale )

	if !timescale then
		timescale = CVAR_TIMESCALE:GetFloat()
	end

	-- Set speed of stars
	if IsValid(EnvSky) then
		EnvSky:SetStarSpeed( 0.0001 * timescale )
	end

	-- Set hdr rate
	/* Doesn't actually do much
	local tonemap = ents.FindByClass("env_tonemap_controller")[1]
	if IsValid(tonemap) then
		local value = 0.1 -- default
		local scale = timescale / 10
		RunConsoleCommand( "mat_hdr_manual_tonemap_rate", scale )
	end*/

end

/*---------------------------------------------------------------------------
	Timer
---------------------------------------------------------------------------*/

local TimerName = "DaynightTimer"

function Start()

	MsgSam( "Starting daynight..." )

	Stop()

	local success = SetupEntities()
	if !success then
		ErrorNoHalt( "Daynight system can't start!\n" )
		return
	end

	UpdateEntities()

	geolocation.Update( function()

		if !daynight then
			ErrorNoHalt( "ERROR: daynight module not found in daynight timer!" )
			return
		end

		timer.Create( TimerName, GetInterval(), 0, Think )

	end )

end
hook.Add( "OnGamemodeLoaded", "DaynightReload", daynight.Start )
-- hook.Add( "OnReloaded", "DaynightReload2", daynight.Start )

function Pause()

	if !timer.Exists( TimerName ) then return end
	
	timer.Pause( TimerName )

end

function Stop()

	if timer.Exists( TimerName ) then
		timer.Destroy( TimerName )
	end

end


/*---------------------------------------------------------------------------
	Interval
---------------------------------------------------------------------------*/
function GetInterval()
	return GetConVar( "daynight_interval" ):GetFloat()
end

function SetInterval( seconds )

	if !timer.Exists( TimerName ) then return end

	-- Don't set the interval too short
	seconds = math.max( 0.01, seconds )

	-- Adjust the timer
	timer.Adjust( TimerName, seconds, 0, function()

		if !daynight then
			ErrorNoHalt( "ERROR: daynight module not found in daynight timer!" )
			timer.Destroy( TimerName )
			return
		end

		Think()

	end )

end

/*---------------------------------------------------------------------------
	Think
---------------------------------------------------------------------------*/

local lat, lng

local hourSec = 60 * 60
local daySec = hourSec * 24

--local ostime = 1503273600 --solar eclipse: August 21st, 2017
local ostime = os.time() -- (60 * 60 * 12) 

local SunPos
local SunTimes, NextDay

local arg
local function TimeToEvent( ... )
	arg = {...}
	if #arg == 1 then
		return SunTimes[ arg[1] ].epoch - ostime -- from current time to event
	elseif #arg == 2 then
		return math.abs( SunTimes[ arg[2] ].epoch - SunTimes[ arg[1] ].epoch ) -- from past event to event
	end
end

/*---------------------------------------------------------------------------
	Sky Think
	Changes colors of the sky
---------------------------------------------------------------------------*/

local SkyConfig = {}
SkyConfig.Properties = {}

function SetSkyEvent( key, value, time )

	-- Convert color to vector
	if istable(value) and value.r and value.g and value.b then
		value = Vector( value.r, value.g, value.b ) / 255
	end

	SkyConfig.Properties[ key ] = SkyConfig.Properties[ key ] or {}
	SkyConfig.Properties[ key ].target 	= value
	SkyConfig.Properties[ key ].time 	= math.max( time, 0.01 ) / CVAR_TIMESCALE:GetFloat()
	SkyConfig.Properties[ key ].start 	= CurTime()
	SkyConfig.Properties[ key ].init = nil

end

local function SetupSkyColors( event, date )

	print( "SunEvent", event )

	if event == "nightEnd" then

		-- SetSkyEvent( 'TopColor', 	Color(38,62,102), 	TimeToEvent('nauticalDawn') )
		-- SetSkyEvent( 'BottomColor', Color(38,62,102), 	TimeToEvent('nauticalDawn') )

		SetSkyEvent( 'TopColor', 	Color(28,44,106), 	TimeToEvent('nauticalDawn') )
		SetSkyEvent( 'BottomColor', Color(28,44,106), 	TimeToEvent('nauticalDawn') )

		SetSkyEvent( 'StarFade', 		0, 				TimeToEvent('dawn') )

	elseif event == "nauticalDawn" then

		SetSkyEvent( 'TopColor', 	Color(38,85,141), 	TimeToEvent('dawn') )
		SetSkyEvent( 'BottomColor', Color(38,85,141), 	TimeToEvent('dawn') )

		-- SetSkyEvent( 'TopColor', 	Color(71,115,187), 	TimeToEvent('dawn') )
		-- SetSkyEvent( 'BottomColor', Color(71,115,187), 	TimeToEvent('dawn') )

	elseif event == "dawn" then

		SetSkyEvent( 'TopColor', 	Color(135,164,211), TimeToEvent('sunrise') )

		SetSkyEvent( 'DuskColor', 		Color(222,155,11), 		TimeToEvent('sunrise') )
		SetSkyEvent( 'DuskIntensity', 	1.2, 					TimeToEvent('sunrise') )
		SetSkyEvent( 'DuskScale', 		1.5, 					TimeToEvent('sunrise') )

		SetSkyEvent( 'StarFade', 		1.5, 					TimeToEvent('sunrise') )
		SetSkyEvent( 'HDRScale', 		0.66, 					TimeToEvent('sunrise') )
		EnvSky:SetStarTexture( "skybox/clouds" )

	elseif event == "sunrise" then

		SetSkyEvent( 'TopColor', 	Color(32,73,178), 		TimeToEvent('goldenHourEnd') )

	elseif event == "sunriseEnd" then

		SetSkyEvent( 'DuskIntensity', 	1, 					TimeToEvent('goldenHourEnd') * 6 )
		SetSkyEvent( 'DuskColor', 		Color(170,201,255), TimeToEvent('goldenHourEnd') * 12 )
		SetSkyEvent( 'DuskScale', 		1, 					TimeToEvent('goldenHourEnd') * 3 )

	elseif event == "goldenHourEnd" then

		SetSkyEvent( 'TopColor', 	Color(32,73,178), 	TimeToEvent('solarNoon') )
		SetSkyEvent( 'BottomColor', Color(84,132,217), 	TimeToEvent('solarNoon') )

		SetSkyEvent( 'SunColor', 	color_white, 		TimeToEvent('solarNoon') )
		SetSkyEvent( 'SunSize', 	0.7, 				TimeToEvent('solarNoon') )

	elseif event == "solarNoon" then

		-- SetSkyEvent( 'SunSize', 	0, 					TimeToEvent('goldenHour') )
		SetSkyEvent( 'SunColor', 	Color(0,0,0), 		TimeToEvent('goldenHour') )

	elseif event == "goldenHour" then

		SetSkyEvent( 'TopColor', 		Color(73,104,158), 	TimeToEvent('sunsetStart') )	-- Darker blue
		SetSkyEvent( 'BottomColor', 	Color(203,255,253), TimeToEvent('sunsetStart') )	-- Turquoise

		SetSkyEvent( 'DuskColor', 		Color(187,39,25), 	TimeToEvent('sunsetStart') )
		SetSkyEvent( 'DuskIntensity', 	1.2, 					TimeToEvent('sunsetStart') )
		SetSkyEvent( 'DuskScale', 		1.5, 					TimeToEvent('sunsetStart') )

		-- SetSkyEvent( 'SunSize', 	0.5, 					TimeToEvent('sunsetStart') )
		SetSkyEvent( 'SunColor', 	Color(255,85,32), 		TimeToEvent('sunsetStart') )

	elseif event == "sunsetStart" then

		SetSkyEvent( 'StarFade', 		0.1, 				TimeToEvent('dusk') )

	elseif event == "sunset" or event == "nadir" then

		SetSkyEvent( 'TopColor', 	Color(0,0,0), 	TimeToEvent('dusk') )
		SetSkyEvent( 'BottomColor', 	Color(3,5,8), TimeToEvent('dusk') )
		SetSkyEvent( 'HDRScale', 		0.66, 			TimeToEvent('dusk') )

		-- SetSkyEvent( 'TopColor', 	Color(71,115,187), 	TimeToEvent('dusk') )
		-- SetSkyEvent( 'BottomColor', Color(71,115,187), 	TimeToEvent('dusk') )

		SetSkyEvent( 'DuskIntensity', 	0, 				TimeToEvent('dusk') )
		SetSkyEvent( 'DuskScale', 		1, 				TimeToEvent('dusk') )

		-- SetSkyEvent( 'SunSize', 	0, 					TimeToEvent('nauticalDusk') )
		SetSkyEvent( 'SunColor', 	Color(0,0,0), 		TimeToEvent('dusk') )

	elseif event == "dusk" or event == "nadir" then

		-- SetSkyEvent( 'TopColor', 	Color(38,62,102), 	TimeToEvent('nauticalDusk') )
		-- SetSkyEvent( 'BottomColor', Color(38,62,102), 	TimeToEvent('nauticalDusk') )

		EnvSky:SetStarTexture( "skybox/starfield" )
		SetSkyEvent( 'StarFade', 		1.5, 			TimeToEvent('night') )

	/*elseif event == "nauticalDusk" then

		-- SetSkyEvent( 'TopColor', 	Color(16,28,46), 	TimeToEvent('night') )
		-- SetSkyEvent( 'TopColor', 	Color(7,11,18), 	TimeToEvent('night') )
		SetSkyEvent( 'TopColor', 	Color(0,0,0), 	TimeToEvent('night') )
		-- SetSkyEvent( 'BottomColor', Color(16,25,41), 	TimeToEvent('night') )
		SetSkyEvent( 'BottomColor', Color(3,5,8), 	TimeToEvent('night') )*/

	end

end
hook.Add( "SunEvent", "SetupSkyColors", SetupSkyColors )


local function SkyThink()

	local value, percent, target
	for k, cfg in pairs( SkyConfig.Properties ) do
		
		value = EnvSky[ 'Get' .. k ]( EnvSky )

		-- Make sure property exists
		if !value then
			print( "ERROR: '" .. k .. "' didn't exist on Skypaint entity!" )
			SkyConfig.Properties[k] = nil
			continue
		end

		if !cfg.init then
			cfg.init = value
		end

		percent = math.Clamp( ( CurTime() - cfg.start ) / cfg.time, 0.01, 1 )

		if isvector(value) then
			target = LerpVector( percent, cfg.init, cfg.target )
		elseif isnumber(value) then
			target = Lerp( percent, cfg.init, cfg.target )
		else
			print("Daynight, SkyThink: UNKNOWN", k, value)
		end

		EnvSky[ 'Set' .. k ]( EnvSky, target )

		-- Completed event
		if percent > 0.999 then
			SkyConfig.Properties[k] = nil
		end

	end

end


/*---------------------------------------------------------------------------
	Fog Think
	Hacky way to limit the effects of HDR during night time, etc.
---------------------------------------------------------------------------*/

local FogConfig = {}
FogConfig.Properties = {}

function SetFogEvent( key, value, time, delay )

	-- Delay firing event
	if delay then

		timer.Simple( delay / CVAR_TIMESCALE:GetFloat(), function()
			SetFogEvent( key, value, time )
		end )

		return

	end

	-- Convert color to vector
	if istable(value) and value.r and value.g and value.b then
		value = Vector( value.r, value.g, value.b ) / 255
	end

	FogConfig.Properties[ key ] = FogConfig.Properties[ key ] or {}
	FogConfig.Properties[ key ].target 	= value
	FogConfig.Properties[ key ].time 	= math.max( time, 0.01 ) / CVAR_TIMESCALE:GetFloat()
	FogConfig.Properties[ key ].start 	= CurTime()
	FogConfig.Properties[ key ].init = nil
	

end

local function SetupFog( event, date )

	if event == "nightEnd" then

		SetFogEvent( 'Density', 	0, 		TimeToEvent('goldenHourEnd') * 2 )

	elseif event == "goldenHourEnd" then

		timer.Simple( TimeToEvent('nightEnd','goldenHourEnd') / CVAR_TIMESCALE:GetFloat(), function() EnvFog:SetFogEnd( 222000 ) end )
		SetFogEvent( 'Density', 	0.22, 					TimeToEvent('solarNoon') * 1/5, TimeToEvent('nightEnd','goldenHourEnd') )
		SetFogEvent( 'FogColor', 	Vector(0.6,0.6,0.6), 	TimeToEvent('solarNoon') * 1/5, TimeToEvent('nightEnd','goldenHourEnd') )

	elseif event == "goldenHour" then

		SetFogEvent( 'FogColor', 	Vector(0,0,0), 	TimeToEvent('sunsetStart') )
		SetFogEvent( 'FogEnd', 		1000000, 		TimeToEvent('sunsetStart') ) -- receed fog

	elseif event == "sunsetStart" then

		-- switch fog to entire canvas for darkening (night time)
		SetFogEvent( 'FogEnd', 	0, 	TimeToEvent('sunsetStart') )

		SetFogEvent( 'Density', 	0.98, 	TimeToEvent('dusk') )

	end

end
hook.Add( "SunEvent", "SetupFog", SetupFog )

local function FogThink()

	local value, percent, target, timepassed
	for k, cfg in pairs( FogConfig.Properties ) do
		
		value = EnvFog[ 'Get' .. k ]( EnvFog )

		-- Make sure property exists
		if !value then
			print( "ERROR: '" .. k .. "' didn't exist on env_fog entity!" )
			FogConfig.Properties[k] = nil
			continue
		end

		timepassed = CurTime() - cfg.start

		if !cfg.init then
			cfg.init = value
		end

		percent = math.Clamp( ( CurTime() - cfg.start ) / cfg.time, 0.01, 1 )

		if isvector(value) then
			target = LerpVector( percent, cfg.init, cfg.target )
		elseif isnumber(value) then
			target = Lerp( percent, cfg.init, cfg.target )
		else
			print("Daynight, FogThink: UNKNOWN", k, value)
		end

		EnvFog[ 'Set' .. k ]( EnvFog, target )

		-- Completed event
		if percent > 0.999 then
			FogConfig.Properties[k] = nil
		end

	end

end

/*---------------------------------------------------------------------------
	Lighting Think
	Adjusts engine lighting
---------------------------------------------------------------------------*/

util.AddNetworkString( "DaynightLighting" )

local LightFinished = true
local CurrentBrightness = 0.5 -- default value
local TargetBrightness = CurrentBrightness

local StartBrightness, LightStart, LightTime

local function FloatToLightChar( n )
	return string.char( math.Round( n * 26 ) + 97 )
end

local function SetLightStyle( style, brightness )

	brightness = FloatToLightChar( brightness )

	engine.LightStyle( style, brightness )

	timer.Simple( 0.1, function()
		net.Start( "DaynightLighting" )
		net.Broadcast()
	end )

end

local function SetLightEvent( brightness, time )

	LightStart = CurTime()
	LightTime = math.max( time, 0.01 ) / CVAR_TIMESCALE:GetFloat()
	LightFinished = false

	StartBrightness = CurrentBrightness
	TargetBrightness = brightness

end

local function SetupLighting( event, date )

	if event == "nightEnd" then

		SetLightEvent( 0.5, TimeToEvent('goldenHourEnd') ) 	-- default brightness

	elseif event == "goldenHour" then

		SetLightEvent( 0.02, TimeToEvent('dusk') ) 		-- dark

	end

end
hook.Add( "SunEvent", "SetupLighting", SetupLighting )

local function LightingThink()

	if LightFinished then return end

	local percent = math.Clamp( ( CurTime() - LightStart ) / LightTime, 0.01, 1 )
	local value = Lerp( percent, StartBrightness, TargetBrightness )

	-- Only adjust lighting if it's precision allows it
	if FloatToLightChar(CurrentBrightness) != FloatToLightChar(value) then
		SetLightStyle( 0, value )
	end

	CurrentBrightness = value

	if percent > 0.99 then
		LightFinished = true
	end

end

function GetLightingLevel()
	return CurrentBrightness
end


/*---------------------------------------------------------------------------
	Sun Think
	Sets accurate sun position
---------------------------------------------------------------------------*/

function GetSunAngle()
	return Angle( -SunPos.altitude, SunPos.azimuth, 0 )
end

local function SunThink()

	local ang = GetSunAngle()
	local dir = ang:Forward()

	-- Debug testing
	if !IsValid(DirEnt) then
		DirEnt = ents.Create( "prop_physics" )
		DirEnt:SetModel( "models/maxofs2d/cube_tool.mdl" )
		DirEnt:SetPos(Vector(62.85,-61.66,-12246.66))
		-- DirEnt:SetSolid(false)
		DirEnt:SetMoveType(MOVETYPE_NONE)
		DirEnt:Spawn()
		DirEnt:Activate()

		DirEnt.phys = DirEnt:GetPhysicsObject()
		if IsValid(DirEnt.phys) then
			DirEnt.phys:EnableGravity(false)
			DirEnt.phys:Sleep()
		end
	end
	DirEnt:SetAngles( ang )

	EnvSky:SetSunNormal( dir )
	EnvSun:SetKeyValue( "sun_dir", tostring( dir ) )

end

local function SunTimeThink()

	ostime = ostime or os.time()

	-- First frame
	if !NextDay then
		SunTimes = SolarCalc.GetSunTimes( ostime, lat, lng )
		NextDay = SolarCalc.GetSunTimes( ostime + daySec, lat, lng )
	end

	-- Day has changed
	if NextDay.nadir.epoch < ostime then
		SunTimes = NextDay
		NextDay = SolarCalc.GetSunTimes( ostime + daySec, lat, lng )
	end

	-- TODO: Sort the table beforehand...
	for k, time in SortedPairsByMemberValue( SunTimes, "epoch" ) do

		if !time.fired and time.epoch < ostime then
			
			hook.Call( "SunEvent", GAMEMODE, k, time )

			time.fired = true
			-- SunTimes[k] = nil

		end

	end

end

MoonPos = nil

function GetMoonAngle()
	return Angle( -MoonPos.altitude, MoonPos.azimuth, 0 )
end

local function MoonThink()

	local ang = GetMoonAngle()
	local dir = ang:Forward()

	-- Debug testing
	if !IsValid(DirEnt2) then
		DirEnt2 = ents.Create( "prop_physics" )
		DirEnt2:SetModel( "models/maxofs2d/cube_tool.mdl" )
		DirEnt2:SetPos(Vector(62.85,-61.66,-12186.66))
		-- DirEnt2:SetSolid(false)
		DirEnt2:SetMoveType(MOVETYPE_NONE)
		DirEnt2:Spawn()
		DirEnt2:Activate()

		DirEnt2.phys = DirEnt2:GetPhysicsObject()
		if IsValid(DirEnt2.phys) then
			DirEnt2.phys:EnableGravity(false)
			DirEnt2.phys:Sleep()
		end
	end
	DirEnt2:SetAngles( ang )

	EnvMoon:SetMoonNormal( dir )
	EnvMoon:SetMoonBrightness( GetLightingLevel() )

end

local osdate

local function CelestialThink()

	lat, lng = geolocation.Info()
	osdate = os.date( "*t", ostime )

	SunPos = SolarCalc.GetSunPositionDeg( osdate, lat, lng )
	MoonPos = SolarCalc.GetMoonPositionDeg( osdate, lat, lng )

end

function Think()

	if !SetupEntities() then
		Stop()
		return
	end

	ostime = ostime + GetInterval() * CVAR_TIMESCALE:GetFloat()

	CelestialThink() -- MUST BE FIRST
	SunTimeThink()
	SunThink()
	MoonThink()

	SkyThink()
	FogThink()
	LightingThink()

	-- Change shadow direction
	local shadow = ents.FindByClass("shadow_control")[1]
	if IsValid(shadow) then
		local shadowDir = GetSunAngle()
		shadowDir.p = -math.abs( shadowDir.p ) -- always have shadows, even when the sun isn't visible
		shadow:Fire( "direction", tostring( -shadowDir:Forward() ), 0.01 )
	end

	hook.Call( "DaynightThink", GAMEMODE or GM )

end