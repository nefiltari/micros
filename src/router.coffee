Micros.Router = ->
  router = {}

  # Closure Register Folder
  register = {}

  # Router key generator
  generate_router_key = (req) ->
    "#{req.socket.remoteAddress}:#{req.socket.remotePort}:#{(Math.floor((do Math.random) * 10**8))}"

  router = new Micros.MicroService 'router'
  router.$register = (req, cb) ->
    key = generate_router_key req
    register[key] = cb
    { key: key }

  router.$exec = (chain, init...) ->
    init = decompress init
    reqres = init
    reqres.push {}                      # Blank res object
    reqres.push _.clone chain.value     # The process chain
    router.$next.apply router, reqres

  router.$set 'api', 'ws'

  runtime = (req, res, next) ->

  runtime.finish = (req, res, next) ->
    if register[req.key]?
      register[req.key] res
      delete register[req.key]

  router.$install runtime

  router._this = @
  router._type = Micros.Router
  router