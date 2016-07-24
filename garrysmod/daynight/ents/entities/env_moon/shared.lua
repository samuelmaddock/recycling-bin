AddCSLuaFile('shared.lua')

ENT.Type = "point"
ENT.Base = "base_point"

ENT.PrintName		= "Moon"
ENT.Author			= ""
ENT.Contact			= ""
ENT.Purpose			= ""
ENT.Instructions	= ""

ENT.Spawnable			= false
ENT.AdminOnly			= false
ENT.Editable			= false

--
--
--
function ENT:Initialize()

	if CLIENT then

		self.CModel = ClientsideModel( "models/sky/moon.mdl", RENDERGROUP_GROUP_OTHER )
		self.CModel:SetNoDraw( true )

		hook.Add( "PostDraw2DSkyBox", self, self.DrawMoon )

	end

end

--
--
--
function ENT:SetupDataTables()

	self:NetworkVar( "Vector",	0, "MoonNormal" )
	self:NetworkVar( "Float",	0, "MoonBrightness" )

	if ( SERVER ) then

		-- defaults
		self:SetMoonNormal( vector_origin )
		self:SetMoonBrightness( 1.0 )

	end

end

--
-- Always transmit since the entity renders in the sky
--
function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

if CLIENT then

	local brightness = 1.0

	--
	-- Draw the moon!
	--
	function ENT:DrawMoon()

		-- Light scale maximum is 0.5
		-- Brighter if it's darker
		brightness = 1 - ( self:GetMoonBrightness() / 0.5 )
		brightness = 1 + brightness * 20

		render.OverrideDepthEnable( true, false )
		render.SuppressEngineLighting( true )
		render.SetColorModulation( brightness, brightness, brightness )

		cam.Start3D( vector_origin, EyeAngles() )
			self.CModel:SetRenderOrigin( self:GetMoonNormal() * 5000 )
			self.CModel:SetRenderAngles( self:GetMoonNormal():Angle() )
			self.CModel:DrawModel()
		cam.End3D()

		render.SetColorModulation( 1, 1, 1 )
		render.SuppressEngineLighting( false )
		render.OverrideDepthEnable( false, false )

	end

end