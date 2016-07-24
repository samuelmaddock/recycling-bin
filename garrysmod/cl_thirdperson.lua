hook.Add( "PopulateMenuBar", "ThirdpersonOptions_MenuBar", function( menubar )
	local m = menubar:AddOrGetMenu( "Thirdperson" )
	m:AddCVar( "Enabled", "cl_thirdperson_enable", "1", "0" )
	m:AddCVar( "Real View", "cl_thirdperson_real", "1", "0" )
	m:AddCVar( "Speed Adjust", "cl_thirdperson_speed", "1", "0" )
end )

module( "ThirdPerson", package.seeall )

CVarEnabled 	= CreateClientConVar( "cl_thirdperson_enable", 0, true, false )
CVarDist 		= CreateClientConVar( "cl_thirdperson_dist", 100, true, false )
CVarOffset 		= CreateClientConVar( "cl_thirdperson_offset", "0 0 0", true, false )
CVarReal 		= CreateClientConVar( "cl_thirdperson_real", 0, true, false )
CVarSpeed 		= CreateClientConVar( "cl_thirdperson_speed", 0, true, false )

MinDist = 35
MaxDist = 300
DefaultOffset = Vector( 0, 0, 75 )

// entities that the camera should go through, should be edited with ExcludeEnt
IgnoreEnts = {
	"player", // always exclude the player
}

function IsEnabled()
	return CVarEnabled and CVarEnabled:GetBool() or false
end

function IsRealViewEnabled()
	return CVarReal and CVarReal:GetBool() or false
end

function IsSpeedEnabled()
	return CVarSpeed and CVarSpeed:GetBool() or false
end

function GetDistance()
	return CVarDist:GetInt()
end

function GetOffset()

	local offset = Vector( CVarOffset:GetString() )
	if isvector( offset ) then
		return offset
	else
		return DefaultOffset
	end

end

function CalcBlurAmount( x, y, fwd, spin )



	return 10, 10, 10, 10
end

function CalcViewFirstPerson( ply, origin, angles, fov )

	ShouldDraw = false

	return {
		origin = origin,
		angles = angles,
		fov = fov,
		vm_origin = ply:GetShootPos(),
		vm_angles = ply:EyeAngles(),
	}

end

function CalcViewFirstPersonReal( ply, origin, angles, fov )

	ShouldDraw = true

	local ent = ply

	if !ply:Alive() then
		if IsValid( ply:GetRagdollEntity() ) then
			ent = ply:GetRagdollEntity()
		end
	end

	local attach = ent:LookupAttachment( "eyes" )
	if !attach then
		return CalcViewFirstPerson( ply, origin, angles, fov )
	end

	local bone = ent:GetAttachment( attach )
	local pos = bone.Pos

	local angles = angles

	if ply:GetActiveWeapon() then
		//angles = bone.Ang
	end
	//if !LastAng then LastAng = angles end
	//if !LastPerc then LastPerc = 0 end

	//LastAng = math.ApproachAngle( LastAng, angles, FrameTime() * 100 )
	//LastAng = math.ApproachAngle( LastAng, angles, FrameTime() * 100 )
	//LastPerc = math.Approach( LastPerc, 1, FrameTime() / 10 )
	//LastAng = LerpAngle( LastPerc, LastAng, angles )

	return {
		origin = pos,
		angles = angles,
		fov = fov,
		vm_origin = ply:GetShootPos(),
		vm_angles = ply:EyeAngles(),
	}

end

local LastSpeedFOV
function CalcViewThirdPerson( ply, origin, angles, fov )

	ShouldDraw = true

	local pos = ply:GetShootPos() + GetOffset():TranslateOffset( ply )

	// Get ragdoll
	if !ply:Alive() then
		if IsValid( ply:GetRagdollEntity() ) then
			pos = ply:GetRagdollEntity():GetPos()
		end
	end

	local dist = math.Clamp( GetDistance(), MinDist, MaxDist )

	-- Increase FOV based on speed
	if IsSpeedEnabled() then
		
		local vel = ply:GetVelocity()
		local len = math.min( vel:Length() / 15, 40 )
		local desired = fov + len

		if !LastSpeedFOV then LastSpeedFOV = fov end

		fov = math.Approach( LastSpeedFOV, desired, 0.06 * math.abs( LastSpeedFOV - desired ) )
		LastSpeedFOV = fov

	end

	// filter out ents that should not collide with where the camera is located
	local filters = {}
	for _, ent in ipairs( IgnoreEnts ) do
		table.Add( filters, ents.FindByClass( ent ) )
	end
	
	// calculate the view now
	local center = pos
	local offset = center + angles:Forward()

	// Check for intersections
	local tr = util.TraceLine( { start = center, 
								 endpos = center + ( angles:Forward() * -dist * 0.95 ),
								 filter = filters } )
	if tr.Fraction < 1 then
		dist = dist * ( tr.Fraction * 0.95 )
	end

	// Check for closed spaces
	local trClosed = util.TraceLine( { start = ply:GetPos() + Vector( 0, 0, 10 ), 
								 endpos = ply:GetPos() + Vector( 0, 0, 70 ),
								 filter = filters } )
	if trClosed.HitWorld then // We hit the world, revert to first person
		return CalcViewFirstPerson( ply, origin, angles, fov )
	end

	// Check for walls
	local trWall = util.TraceHull( { start = center,
								 endpos = center + ( angles:Forward() * -dist * 0.95 ),
								 mins= Vector( -8, -8, -8 ), maxs = Vector( 8, 8, 8 ),
								 filter = filters } )
	if trWall.Fraction < 1 then
		dist = dist * ( trWall.Fraction * 0.95 )
	end

	// Too close, revert to first person
	if dist <= 10 then
		return CalcViewFirstPerson( ply, origin, angles, fov )
	end

	// Final position
	local Pos = center + ( angles:Forward() * -dist * 0.95 )

	// Ease
	if !LastPos then LastPos = Pos end
	local ease = 600

	LastPos.x = ApproachSupport( LastPos.x, Pos.x, ease )
	LastPos.y = ApproachSupport( LastPos.y, Pos.y, ease )
	LastPos.z = ApproachSupport( LastPos.z, Pos.z, ease )

	// View it up
	return {
		origin = LastPos,
		angles = Angle( angles.p + 2, angles.y, angles.r ),
		fov = fov,
		vm_origin = ply:GetShootPos(),
		vm_angles = ply:EyeAngles(),
	}

end

// accepts a string or table of strings
// this adds an entity to an exclusion list for camera collision

local function ExEnt( ent )

	if !ent || table.HasValue( ThirdPerson.IgnoreEnts, ent ) then return end
	table.insert( ThirdPerson.IgnoreEnts, ent )

end

function ExcludeEnt( ent )

	if !ent then return end
	
	if type( ent ) == "table" then

		for _, v in pairs( ent ) do
			ExEnt( v )
		end

	elseif type( ent ) == "string" then
	
		ExEnt( ent )
		
	end

end

hook.Add( "GetMotionBlurValues", "Portal.GetMotionBlurValues", function( ... )
	if LocalPlayer():Alive() and ThirdPerson.IsEnabled() and ThirdPerson.IsSpeedEnabled() then
		-- return ThirdPerson.CalcBlurAmount(...)
	end
end )

hook.Add( "ShouldDrawLocalPlayer", "ThirdDrawLocal", function( ply )
	if LocalPlayer():Alive() and ThirdPerson.IsEnabled() then
		return true
	end
end )

hook.Remove( "CalcView", "ThirdPersonCalcView" )
hook.Add( "CalcView", "ThirdPersonCalcView", function( ply, origin, angles, fov )

	if !ply:Alive() then return end

	if ThirdPerson.IsEnabled() then

		if ThirdPerson.IsRealViewEnabled() then
			return ThirdPerson.CalcViewFirstPersonReal( ply, origin, angles, fov )
		else
			return ThirdPerson.CalcViewThirdPerson( ply, origin, angles, fov )
		end

	end

end )

/*hook.Add( "PlayerBindPress", "ThirdPersonKeyBind", function( ply, bind, pressed )

	// No physgun
	if LocalPlayer().GetActiveWeapon then
		local weapon = LocalPlayer():GetActiveWeapon()
		if IsValid( weapon ) && weapon:GetClass() == "weapon_physgun" then
			return false
		end
	end

	// Toggle third person with mouse wheel
	if bind == "invprev" && pressed then

		local dist = ThirdPerson.Dist:GetInt() - 10

		if dist <= 35 then
			ThirdPerson.Toggle( ply, false )
		end

		RunConsoleCommand( "thirdperson_dist", math.Clamp( dist, 35, 150 ) )

		return true

	elseif bind == "invnext" && pressed then

		local dist = ThirdPerson.Dist:GetInt() + 10

		ThirdPerson.Toggle( ply, true )
		RunConsoleCommand( "thirdperson_dist", math.Clamp( dist, 35, 150 ) )

		return true

	end

end )*/