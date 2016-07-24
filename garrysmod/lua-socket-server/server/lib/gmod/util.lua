
--
-- Seed the rand!
--
math.randomseed( os.time() );

--
-- Alias string.Format to global Format
--
Format = string.format

--[[---------------------------------------------------------
	Prints a table to the console
-----------------------------------------------------------]]
function PrintTable ( t, indent, done )

	done = done or {}
	indent = indent or 0

	for key, value in pairs (t) do

		Msg( string.rep ("\t", indent) )

		if  ( istable(value) and not done[value] ) then

			done [value] = true
			Msg( tostring(key) .. ":" .. "\n" );
			PrintTable (value, indent + 2, done)

		else

			Msg( tostring (key) .. "\t=\t" )
			Msg( tostring(value) .. "\n" )

		end

	end

end

--[[---------------------------------------------------------
	Returns true if object is valid (is not nil and IsValid)
-----------------------------------------------------------]]
function IsValid( object )

	if ( not object ) then return false end
	if ( not object.IsValid ) then return false end

	return object:IsValid()

end

--[[---------------------------------------------------------
	Simple lerp
-----------------------------------------------------------]]
function Lerp( delta, from, to )

	if ( delta > 1 ) then return to end
	if ( delta < 0 ) then return from end
	
	return from + (to - from) * delta;

end

--[[---------------------------------------------------------
	Convert Var to Bool
-----------------------------------------------------------]]
function tobool( val )
	if ( val == nil or val == false or val == 0 or val == "0" or val == "false" ) then return false end
	return true
end

function isbool( obj )
	return type( obj ) == "boolean"
end

function isfunction( obj )
	return type( obj ) == "function"
end

function isnumber( obj )
	return type( obj ) == "number"
end

function isstring( obj )
	return type( obj ) == "string"
end

function istable( obj )
	return type( obj ) == "table"
end