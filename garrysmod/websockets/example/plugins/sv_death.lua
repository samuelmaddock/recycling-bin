local ServerMsgCol = Color(155,232,149)

hook.Add( "SamWebSocketConnected", "SetupPlayerDeathHook", function( ws )

	ws:AddHook( "PlayerDeath", "RelayPlayerDeath", function( buf )

		local victim = buf:ReadString()
		local DeathType = buf:ReadByte()

		if DeathType == 1 then
			umsg.Start( "WSPlayerKilledSelf" )
				umsg.String( victim )
			umsg.End()
		elseif DeathType >= 2 then
			local inflictor = buf:ReadString()
			local attacker = buf:ReadString()
			umsg.Start( "WSPlayerKilledByOther" )
				umsg.String( victim )
				umsg.String( inflictor )
				umsg.String( attacker )
			umsg.End()
		else
			print("Unhandled death type: " .. tostring(DeathType))
		end

	end )

end )

hook.Add( "PlayerDeath", "WSPlayerDeath", function( Victim, Inflictor, Attacker )

	if !IsValid(SAMWEBSOCKET) then return end

	if ( !IsValid( Inflictor ) && IsValid( Attacker ) ) then
		Inflictor = Attacker
	end

	-- Convert the inflictor to the weapon that they're holding if we can.
	-- This can be right or wrong with NPCs since combine can be holding a 
	-- pistol but kill you by hitting you with their arm.
	if ( Inflictor && Inflictor == Attacker && (Inflictor:IsPlayer() || Inflictor:IsNPC()) ) then

		Inflictor = Inflictor:GetActiveWeapon()
		if ( !IsValid( Inflictor ) ) then Inflictor = Attacker end

	end

	local buf = BitBuff()

	buf:WriteString( "PlayerDeath" )
	buf:WriteString( Victim:Nick() )

	if Attacker == Victim then
		buf:WriteByte( 1 )
	elseif Attacker:IsPlayer() then
		buf:WriteByte( 2 )
		buf:WriteString( Inflictor:GetClass() )
		buf:WriteString( Attacker:Nick() )
	else
		buf:WriteByte( 3 )
		buf:WriteString( Inflictor:GetClass() )
		buf:WriteString( Attacker:GetClass() )
	end

	SAMWEBSOCKET:SendFrame( buf )

end )

hook.Add( "OnNPCKilled", "WSNPCDeath", function( ent, attacker, inflictor )

	if !IsValid(SAMWEBSOCKET) then return end

	local buf = BitBuff()
	buf:WriteString( "PlayerDeath" )

	-- Convert the inflictor to the weapon that they're holding if we can.
	if ( inflictor && inflictor != NULL && attacker == inflictor && (inflictor:IsPlayer() || inflictor:IsNPC()) ) then
		inflictor = inflictor:GetActiveWeapon()
		if ( attacker == NULL ) then inflictor = attacker end
	end

	local InflictorClass = "World"
	local AttackerClass = "World"

	if ( IsValid( inflictor ) ) then InflictorClass = inflictor:GetClass() end
	if ( IsValid( attacker ) ) then 

		AttackerClass = attacker:GetClass() 

		if ( attacker:IsPlayer() ) then

			buf:WriteString( ent:GetClass() )
			buf:WriteByte( 3 )
			buf:WriteString( InflictorClass )
			buf:WriteString( attacker:IsPlayer() and attacker:Nick() or attacker:GetClass() )

			SAMWEBSOCKET:SendFrame( buf )

			return
		end

	end

	buf:WriteString( ent:GetClass() )
	buf:WriteByte( 3 )
	buf:WriteString( InflictorClass )
	buf:WriteString( AttackerClass )

	SAMWEBSOCKET:SendFrame( buf )

end )