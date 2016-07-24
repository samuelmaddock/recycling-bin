if SERVER then

	util.AddNetworkString( "WSChat" )

else

	net.Receive( "WSChat", function()

		local msg = net.ReadTable()

		chat.AddText( unpack( msg ) )

	end )

end