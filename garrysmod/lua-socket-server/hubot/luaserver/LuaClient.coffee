# Description:
#   Manages communication to and from the GMT lua server.
#

{EventEmitter} = require 'events'
net = require 'net'

BitBuff = require './bitbuff.js'

DEV = false

class LuaClient extends EventEmitter

  constructor: (params) ->
    @socket = new net.Socket
    @connected = false
    @host = params.host || '127.0.0.1'
    @port = params.port || 27064
    @name = params.name || 'hello'
    @pass = params.pass || ''
    @retryDelay = params.retryDelay || 30000

    @retrying = false
    @errored = false

  connect: ->
    @socket = net.createConnection @port, @host

    @socket.on 'error', @_handleError.bind(@)
    @socket.on 'connect', @_handleConnect.bind(@)
    @socket.on 'close', @_handleClose.bind(@)
    @socket.on 'data', @_handleData.bind(@)

  reconnect: ->
    if @retrying
      return

    @_log '[LuaClient] Reconnecting..' if DEV
    @connected = false

    if @socket
      @socket.setTimeout 0
      @socket.destroy()
      @socket = null

    @retrying = true

    callback = ->
      @retrying = false
      @connect()

    setTimeout callback.bind(@), @retryDelay

  _handleError: (e) ->
    @_log e
    if !@errored
      @errored = true
      @_log '[LuaClient] Connection closed.'
      @reconnect()

  _handleConnect: ->
    @_log '[LuaClient] Connected.' if DEV
    @connected = true
    @_authenticate()

  _handleClose: ->
    if @errored
      @reconnect()


  _handleData: (data) ->
    size = data.readInt16LE 0
    @_log '[LuaClient] Received: ' + data + '['+size+']' if DEV
    buf = BitBuff.fromNodeBuffer data, 2

    hook = 'hook-' + buf.ReadString()
    @_log '[LuaClient] Hook received: ' + hook if DEV
    @emit hook, buf

  _log: (msg...) ->
    # console.log msg... if DEV
    @emit 'log', msg...

  _authenticate: ->
    buf = new BitBuff
    buf.WriteString 'auth'
    buf.WriteString @name
    buf.WriteString @pass
    @send buf

  send: (buf) ->
    len = buf.Length()
    upper = (len >> 8) & 0xFF
    lower = len & 0xFF

    lenbuf = Buffer([upper, lower])
    payload = buf.ToNodeBuffer()

    @_log "[LuaClient] Sending: [#{len}] #{payload}" if DEV

    @socket.write lenbuf
    @socket.write payload

  sendHook: (name, text, envelope) ->
    buf = new BitBuff
    buf.WriteString name
    buf.WriteString text
    buf.WriteString envelope.room
    buf.WriteString envelope.user.name
    @send buf

  hook: (name, func) ->
    @on 'hook-' + name, func

module.exports = LuaClient
