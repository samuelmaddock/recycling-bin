Lua socket server for communicating cross-servers and to external chat clients.

This was used for GMod Tower as a way to chat and send commands to the server 
from our private Slack channels. The Hubot chat bot was used to interface with 
our Lua socket server.

The Lua server was designed to be idiomatic to Garry's Mod Lua developers.
Included are common gmod utility functions (such as `include`), a hook system,
a `net` api, and more.

Directory structure:
```
/addon 		# Garry's Mod Lua addon for connecting to the Lua socket server
/hubot 		# Hubot plugin to connect to the Lua socket server
/server 	# Lua socket server 
```

Dependencies:
Lua 5.1
gmsv_socket
