function exists(name)
	if type(name)~="string" then return false end
	return os.rename(name,name) and true or false
end

function isFile(name)
	if type(name)~="string" then return false end
	if not exist(name) then return false end
	local f = io.open(name)
	if f then
		f:close()
		return true
	end
	return false
end

function isDir(name)
	return (exist(name) and not isFile(name))
end

function readFile(path)
	local f = io.open(path, "r")
	if f == nil then return end

	local t = f:read("*all")
	f:close()

	return t
end

function getFilesInDir( path )
	if not path then return end
	local tbl = {}

	path = string.Replace( path, "/", "\\" )

	-- find all files in directory and only return the name
	local process = "dir /b /A-D " .. path
	local f = io.popen(process)

	for filepath in f:lines() do
		table.insert( tbl, filepath )
	end

	return tbl
end

---
-- Gets the current file name from where this function is called.
--
function curFile()
	local info = debug.getinfo(2, 'S')
	local filepath = info.short_src
	return string.GetFileFromFilename( filepath )
end

---
-- Gets the current file path from where this function is called.
--
function curFilePath()
	local info = debug.getinfo(2, 'S')
	return info.short_src
end

---
-- Gets the current path from where this function is called.
--
function curPath()
	local info = debug.getinfo(2, 'S')
	local filepath = info.short_src
	return string.GetPathFromFilename( filepath )
end

---
-- Include a file in the similar behavior of Garry's Mod.
--
function include( includepath )
	local info = debug.getinfo(2, 'S')
	local filepath = info.short_src
	local path = string.GetPathFromFilename( filepath )
	dofile( path .. includepath )
end

---
-- Include all Lua files in a directory
--
function includeDir( includepath )
	if not string.EndsWith( includepath, "/" ) then
		includepath = includepath .. "/"
	end

	local info = debug.getinfo(2, 'S')
	local filepath = info.short_src
	local path = string.GetPathFromFilename( filepath )

	local files = getFilesInDir( path .. includepath )
	for _, v in pairs( files ) do
		local p = path .. includepath .. v
		dofile( p )
	end
end

---
-- Using this to avoid finding a luajit JSON lib for windows...
-- https://gist.github.com/evandro92/11067237
--
function jsonDecode(json) 
	json = string.gsub(json, [[["']%s*(%w+)%s*["']:]], "%1=")
	json = string.gsub(json, "%[", "{")
	json = string.gsub(json, "%]", "}")
 
	assert (loadstring("result = " .. json) or error("invalid json syntax")) ()
 
	return result
end