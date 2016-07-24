--[[------------------------------------------------------
	RELAY EVENTS
--------------------------------------------------------]]

hook.Add( "OnPlayerChat", "Hubot - Relay Chat", function( cl, steamID, name, text )

	if not hubot.IsOnline() then return end

	local msg = ("*%s - %s:* %s"):format( steamID, name, text )
	hubot.SendServerMessage( cl, msg )

end )

hook.Add( "PlayerConnect", "Hubot - Relay Connect", function( cl, name, ip )

	if not hubot.IsOnline() then return end

	local msg = ("_Player %s has joined the game (%s)._"):format( name, ip )
	hubot.SendServerMessage( cl, msg )

end )

hook.Add( "PlayerDisconnected", "Hubot - Relay Disconnect", function( cl, name )

	if not hubot.IsOnline() then return end

	local msg = "_Player " .. name .. " left the game._"
	hubot.SendServerMessage( cl, msg )

end )

local LUA_ERROR_TEMPLATE = [[
realm    : %s
addon    : %s
gamemode : %s
version  : %s
os       : %s

%s
%s]]

hook.Add( "OnLuaError", "Hubot - Relay Errors", function( form )

	if not hubot.IsOnline() then return end

	local msg = LUA_ERROR_TEMPLATE:format( form.realm, form.addon,
		form.gamemode, form.gmv, form.os, form.error, form.stack )

	hubot.Msg( msg, "errors" )

end )
