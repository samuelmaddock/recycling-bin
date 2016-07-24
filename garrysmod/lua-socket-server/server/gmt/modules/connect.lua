--[[------------------------------------------------------
	PlayerConnect
--------------------------------------------------------]]

function SERVER:PlayerConnect( cl, name, ip )
	print( ("PlayerConnect: %s %s"):format( name, ip ) )
end

net.Receive( "PlayerConnect", function( _, cl )
	local name = net.ReadString()
	local ip = net.ReadString()

	hook.Run( "PlayerConnect", cl, name, ip )
end )


--[[------------------------------------------------------
	PlayerDisconnected
--------------------------------------------------------]]

function SERVER:PlayerDisconnected( cl, name )
	print( ("PlayerDisconnected: %s"):format( name ) )
end

net.Receive( "PlayerDisconnected", function( _, cl )
	local name = net.ReadString()

	hook.Run( "PlayerDisconnected", cl, name )
end )
