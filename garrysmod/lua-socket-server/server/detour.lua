detour = detour or {}

local detours = detour.detours or {}
detour.detours = detours

function detour.AddDetour(tbl, key, func)
	detours[tbl] = detours[tbl] or {}

	local original = tbl[key]

	detours[tbl][key] = detours[tbl][key] or {
		original = original,
		func = func
	}

	tbl[key] = function(...)
		return func(original, ...)
	end
end

function detour.GetDetour(tbl, key)
	return detours[tbl] and detours[tbl][key]
end

function detour.IsDetoured(tbl, key)
	return detour.GetDetour(tbl,key) and true or false
end

function detour.RemoveDetour(tbl, key)
	if (detours[tbl]) then
		local detour = detours[tbl][key]
		tbl[key] = detour.original
		detours[tbl][key] = nil
	end
end
