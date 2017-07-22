concommand.Add( "solarcalc_test", function(ply,cmd,args)

	local date = os.date("*t", 1362441600) --(new Date('2013-03-05UTC')).valueOf()
	local lat = 50.5
	local lng = 30.5

	local SunPos = SolarCalc.GetSunPosition(date, lat, lng)

	print("Sun")
	print("azimuth:", SunPos.azimuth)
	print("altitude:", SunPos.altitude)

	local MoonPos = SolarCalc.GetMoonPosition(date, lat, lng)

	print("\nMoon")
	print("azimuth:", MoonPos.azimuth)
	print("altitude:", MoonPos.altitude)
	print("distance:", MoonPos.distance)

end)

if CLIENT then

	concommand.Add( "solarcalc_analemma", function(ply,cmd,args)

		local samples = {}

		local time = os.time() + (60 * 60 * 6)
		local secDay = 60 * 60 * 24 -- seconds in a day

		for i = 1, 100 do

			local sunpos = SolarCalc.GetSunPosition( os.date( "*t", time ) )
			local ang = Angle( -math.abs(sunpos.altitude), sunpos.azimuth, 0 )
			
			local pos = ang:Forward():GetNormal() * 1000

			-- offset for flatgrass
			table.insert( samples, Vector(-5.687523,-31.318478,-12287.968750) + pos )

			time = time + secDay * i

		end

		hook.Remove( "PostDrawOpaqueRenderables", "DrawAnelemmaTest" )
		hook.Add( "PostDrawOpaqueRenderables", "DrawAnelemmaTest", function()

			render.StartBeam( #samples - 1 )

				for i = 1, #samples do
					
					render.AddBeam( samples[i], 0.05, 0, color_white )

				end

			render.EndBeam()

		end )

	end )

end