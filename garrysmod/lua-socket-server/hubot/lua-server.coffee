# Description:
#   Manages communication to and from the GMT lua server.
#

LuaClient = require './luaserver/LuaClient.coffee'

LOG_ROOM = 'status'

roomMap = {
  default: 'status',
  ballrace1: 'chat_ballrace1',
  ballrace2: 'chat_ballrace2',
  lobby1: 'chat_lobby1',
  lobby2: 'chat_lobby2',
  minigolf1: 'chat_minigolf1',
  minigolf2: 'chat_minigolf2',
  pvp1: 'chat_pvp1',
  pvp2: 'chat_pvp2',
  sourcekarts1: 'chat_sourcekarts1',
  sourcekarts2: 'chat_sourcekarts2',
  uch1: 'chat_uch1',
  uch2: 'chat_uch2',
  virus1: 'chat_virus1',
  virus2: 'chat_virus2',
  zm1: 'chat_zm1',
  zm2: 'chat_zm2',
  test: 'status'
}

module.exports = (robot) ->

  client = new LuaClient {
    host: '127.0.0.1',
    port: 27064,
    name: 'hubot',
    pass: 'redacted'
  }

  client.on 'log', (msg...) ->
    sendToRoom LOG_ROOM, msg...

  client.hook 'servermsg', (buf) ->
    serverName = buf.ReadString()
    msg = buf.ReadString()

    room = roomMap[serverName] or roomMap.default

    sendToRoom room, msg

  client.hook 'output', (buf) ->
    text = buf.ReadString()
    hasUid = (buf.ReadByte() == 1)

    if hasUid
      room = buf.ReadString()
    else
      room = LOG_ROOM

    text = "```#{text}```"
    sendToRoom room, text

  sendToRoom = (room, msg...) ->
    envelope = {
      room: room
    }
    text = msg.join()
    robot.send envelope, text

  client.connect()

  robot.hear /^!((\w+.*\s*)+)/i, (msg) ->
    cmd = msg.match[1]
    client.sendHook 'hubotcmd', cmd, msg.envelope

  robot.respond /serverinfo(.*)/i, (msg) ->
    target = if msg.match.length then msg.match[1] else null

    if target and target.length
      cmd = 'serverinfo ' + target.trim()
    else
      cmd = 'serverinfo'

    client.sendHook 'hubotcmd', cmd, msg.envelope
