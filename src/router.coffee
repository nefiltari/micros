# Closure Register Folder
register = {}

# Router key generator
generate_router_key = (req) ->
  "#{req.socket.remoteAddress}:#{req.socket.remotePort}:#{(Math.floor((do Math.random) * 10**8))}"

Micros.router = new MicroService 'router'
Micros.router.$register = (req, cb) ->
  key = generate_router_key req
  register[key] = cb

Micros.router.$set 'api', 'ws'

runtime = (req, res, next) ->

runtime.finish = (req, res, next) ->
  if register[req.key]?
    register[req.key] res
    delete register[req.key]

Micros.router.$install runtime
