-- LIGHT OVERRIDE --
-- Because the daynight uses fog, lights are dimmed --
-- this overrides the brightness values of those lights to counteract this during nighttime --

hook.Add("DaynightThink", "DaynightLightsOverride", function()

	for _, v in pairs( player.GetAll() ) do
		if IsValid( v ) && IsValid( v.FlashlightEnt ) then
			local b = 1 / daynight.GetLightingLevel()
			local c = flashlight.UsePlayerColor and v:GetPlayerColor() * 255 or Color( 255, 255, 255 )
			v.FlashlightEnt:SetKeyValue( "lightcolor", Format( "%i %i %i 255", c.r * b, c.g * b, c.b * b ) )
		end
	end
end )