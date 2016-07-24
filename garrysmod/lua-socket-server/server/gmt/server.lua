SERVER = {}
SERVER.__index = SERVER

function SERVER:Initialize()
	self.BaseClass.Initialize(self)

	print "GMT server is running"

	errorurl.serve( "127.0.0.1", 27080 )
end

function SERVER:ClientAuthed( cl )
	self.BaseClass.ClientAuthed( self, cl )
end

function SERVER:ClientDisconnected( cl, reason )
	self.BaseClass.ClientDisconnected( self, cl, reason )
end

--
-- Load extra modules.
--
includeDir "modules/"

server.Register( SERVER, "GMT" )
