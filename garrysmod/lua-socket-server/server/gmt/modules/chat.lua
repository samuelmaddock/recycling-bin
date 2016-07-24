function SERVER:OnPlayerChat( cl, steamID, name, text )
	print( ("OnPlayerChat: %s %s %s"):format( steamID, name, text ) )
end

net.Receive( "chat", function( _, cl )
	local steamID = net.ReadString()
	local name = net.ReadString()
	local text = net.ReadString()

	hook.Run( "OnPlayerChat", cl, steamID, name, text )
end )
