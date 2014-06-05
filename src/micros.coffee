## Export Hack
Micros = exports? and exports or @Micros = {}

## Libs

coffee = require 'coffee-script'
require 'coffee-script/register'
_ = require 'underscore'
async = require 'async'

## Intern Module Functions

# Decompress Array like [[...]] to [...] when needed
decompress = (arr) ->
  if arr instanceof Array and arr.length is 1 and arr[0] instanceof Array
    arr = arr[0]
  arr

# Generate a key for gather
generate_key = ->
  (new Date).valueOf() + '' +  Math.floor((do Math.random) * 10**8)

# go forward in chain and persist allways a Micros.Chain object as return value
process_inner_chain = (fn) ->
  # Call inner Chain
  chain = do fn
  # If chain is a MicroService then the chain ends
  if chain?._type is Micros.MicroService
    chain = chain -> new Micros.Chain
  # If chain is a Broadcast then wrap this in a chain
  if chain?._type is Micros.Broadcast
    chain = new Micros.Chain chain
  # For a inner chain object: do nothing
  chain

## Exports

# Config
Micros.Config =
  ms_folder: 'node_modules'
  log_folder: 'logs'
  start_port: 4500
  prefix: 'micros'

# Config setter
Micros.set = (key, value) ->
  Micros.Config[key] = value

# Config getter
Micros.get = (key) ->
  Micros.Config[key]

# Spawn all known processes
# Calls cb for each found service and pass the MicroService as parameter
Micros.spawn = (cb) ->
  fs = require 'fs'
  cwd = do process.cwd
  port = Micros.Config['start_port']
  services = fs.readdirSync "#{cwd}/#{Micros.Config['ms_folder']}"
  services = _.filter services, (ele) -> ele.match "^#{Micros.Config['prefix']}-(.*)"
  async.each services, (name) ->
    try
      service = require "#{cwd}/#{Micros.Config['ms_folder']}/#{name}"
      service.$spawn name, port
      cb service
      port = port + 1

# MicroService Module
Micros.MicroService = (name) ->
  # Process the inner chain to extend it
  ms = (params..., fn) ->
    params = decompress params
    # Detect inner method call
    method = do @.toString if @ instanceof String
    # Detect the end of the Chain
    if typeof fn isnt 'function'
      params.push fn
      fn = -> new Micros.Chain
    # Construct Service Parameter
    service = name: ms.$name
    service.params = params if params.length > 0
    service.method = method if method?
    service.api = ms.$config.api
    service.port = ms.$config.port
    # Call inner Chain
    chain = process_inner_chain fn
    # Normal Backtracking
    chain.value.push service
    chain

  # Set name
  ms.$name = name
  # Caches
  ms.$cache = {} # MicroService Cache
  ms.$gathers = {} # Gather Cache
  ms.$timeouts = [] # Timeout Cache

  # Configure the MicroService with standard values or local package config
  ms.$config = {}
  ms.$config.timeout = 10*1000 unless ms.$config['timeout']?

  # Add all MicroService sub methods as fake methods
  ms.$install = (runtime) ->
    ms.$runtime = runtime
    for key, value of ms.$runtime
      ms[key] = do (method = key) ->
        (params..., fn) ->
          params = decompress params
          ms.call (new String method), params, fn
      ms[key]._type = Micros.MicroService
      ms[key]._this = @
  ms.$map = ms.$install

  # Set config with Key and Value
  ms.$set = (key, value) ->
    ms.$config[key] = value

  # Get a config key
  ms.$get = (key) ->
    ms.$config[key]

  # Pop the next MicroService from Chain-Stack and call the API
  ms.$next = (req..., res, chain) ->
    req = decompress req
    return if chain.length is 0
    util = require 'util'
    next = do chain.pop
    if util.isArray next
      # Generate gather key if neccessary
      if (_.last chain)?
        # Modifie chain while the flow is active for request foreign gathers
        chain[chain.length - 1].gather =
          key: do generate_key
          services: next.length
    else next = [next]
    # Iterate over all broadcast chain links
    for link, i in next
      path = chain
      # Process broadcast inner chain
      if util.isArray link
        # Construct the Gather
        path = path.concat link
        link = do path.pop
      # Construct the message (ICM) (alternate use Protobuf?)
      message =
        request: req[i]
        response: res
        sender: ms.$name
        chain: path
      message.request = _.last req unless message.request?
      # Multiple Message between two MircoServices
      if (i+1) is next.length and req[i+1]?
        message.request = _.rest req, i
      message.params = link.params if link.params?
      message.gather = link.gather if link.gather?
      message.method = link.method if link.method?
      # Switch between different API types
      switch link.api
        when 'http'
          http = require 'http'
          options = port: link.port
          options.method = 'POST'
          options.path = "/#{message.method}" if message.method?
          options.headers = 'Content-Type': 'application/json'
          request = http.request options
          # Write and send the request
          request.write JSON.stringify(message)
          #console.log request
          do request.end
        when 'ws'
          unless ms.$cache[link.name]
            ms.$cache[link.name] = require('socket.io-client').connect "http://localhost:#{link.port}"
          ms.$cache[link.name].emit 'icm', message

  # Spawn new child processes with service invoker (deamon)
  ms.$spawn = (name, port, cb = ->) ->
    exec = require('child_process').exec
    try
      ms.$config['port'] = port
      ms.$process = exec "#{__dirname}/bin/wrapper.js #{Micros.Config['ms_folder']}/#{name} #{port} > #{Micros.Config['log_folder']}/#{name}.log 2>&1"
    catch error
      return setTimeout cb, 0, error
    setTimeout cb, 0

  # Call the MicroService API asynchronly with a ICM
  ms.$call = (message) ->
    # Process a Gather when needed
    if message.gather?
      key = message.gather.key
      # Initialisation
      unless ms.$gathers[key]?
        ms.$gathers[key] =
          requests: []
          responses: []
          previous: []
          services: message.gather.services
          next: (req..., res) -> ms.$next.call ms, req, res, message.chain
        ms.$gathers[key].next.chain = message.chain
        ms.$gathers[key].next.previous = []
        setTimeout (-> delete ms.$gathers[key] if ms.$gathers[key]?), ms.$config.timeout
      # Add Informations to Cache
      ms.$gathers[key].requests.push message.request
      ms.$gathers[key].responses.push message.response
      ms.$gathers[key].next.previous.push message.sender
      ms.$gathers[key].services -= 1
      # All MicroServices done ? Fire service to accumulate the requests/responses
      if ms.$gathers[key].services is 0
        stack = []
        stack.push ms.$gathers[key].requests
        stack.push ms.$gathers[key].responses
        stack.push ms.$gathers[key].next
        stack = stack.concat message.params if message.params?
        # call the method asynchron
        if message.method?
          process.nextTick (-> ms.$runtime[message.method].apply ms, stack)
        else process.nextTick (-> ms.$runtime.apply ms, stack)
        # Free the Cache
        delete ms.$gathers[key]
    else # Process a normal flow
      next = (req..., res) -> ms.$next.call ms, req, res, message.chain
      next.chain = message.chain
      next.previous = message.sender
      # Fill param list
      stack = []
      stack.push message.request
      stack.push message.response
      stack.push next
      stack = stack.concat message.params if message.params?
      # call the method asynchron
      if message.method?
        process.nextTick (-> ms.$runtime[message.method].apply ms, stack)
      else process.nextTick (-> ms.$runtime.apply ms, stack)

  # Set process behaviour for deamons and optionaly start a cluster (with load-balancer)
  ms.$deamon = (port) ->
    ms.$config['port'] = parseInt port
    # Clusterized start if config is set
    if ms.$config.clusters? and ms.$config.clusters > 1
      cluster = require 'cluster'
      if do cluster.isMaster
        process.title = "MicroService: #{ms.$name} (#{ms.$version}) [master]"
        # Start the workers
        _.times ms.$config.clusters, cluster.fork
        # Event handlers
        cluster.on 'exit', (worker, code, signal) ->
          console.log "Worker[#{worker.id}]: '#{ms.$name}' stopped!"
        cluster.on 'online', (worker) ->
          console.log "Worker[#{worker.id}]: '#{ms.$name}' started!"
      else
        process.title = "MicroService: #{ms.$name} (#{ms.$version}) [slave]"
        # Finalization
        process.on 'SIGTERM', ->
          ms.$shutdown (error) ->
            console.log error if error
        # Shared listen
        ms.$listen (error) ->
          console.log error if error
    else # Normal start
      process.title = "MicroService: #{ms.$name} on port #{ms.$config.port}"
      # Finalization
      process.on 'SIGTERM', ->
        ms.$shutdown (error) ->
          unless error
            console.log "MicroService: '#{ms.$name}' stopped!"
          else console.log error
      # Start the Listener
      ms.$listen (error) ->
        unless error
          console.log "MicroService: '#{ms.$name}' started on port: #{ms.$config.port}"
        else console.log error

  # Listen for incomming requests
  ms.$listen = (cb = ->) ->
    # Switch between different api's
    switch ms.$config.api
      when 'http'
        express = require 'express'
        app = express()
        app.use express.json()
        # Routing
        app.post '/', (req, res, next) ->
          res.json req.body
          #res.send 200
          console.log "[#{new Date}] New Request from #{req.body.sender}!"
          #console.log req.body
          ms.$call req.body
        app.post '/:method', (req, res, next) ->
          #res.send 200
          req.body.method = req.params['method']
          console.log "[#{new Date}] New Request from #{req.body.sender}!"
          #console.log req.body
          ms.$call req.body
        # Start the Server
        http = require 'http'
        ms.$service = http.createServer app
        ms.$service.listen ms.$config.port
      when 'ws'
        io = require 'socket.io'
        app = io.listen ms.$config.port
        app.set 'log level', 0
        app.sockets.on 'connection', (ws) ->
          console.log "[#{new Date}] New WebSocket connection from MicroService!"
          ws.on 'icm', (message) ->
            #console.log message
            ms.$call message
        app.sockets.on 'disconnect', (ws) ->
          console.log "[#{new Date}] MicroService disconnected!"
        ms.$service = app

    setTimeout cb, 0, null, ms.$service

  # Shutdown the Service (only valid in the same process as #listen)
  ms.$shutdown = (cb = ->) ->
    # Clear the interval
    clearInterval(ms.$interval) if ms.$interval?
    # Switch between different api's
    switch ms.$config.api
      when 'http', 'ws'
        try
          do ms.$service.close
        catch error
          return setTimeout cb, 0, error
    setTimeout cb, 0

  ms._this = @
  ms._type = Micros.MicroService
  ms

# Composer / Dirigent
Micros.Chain = (chain) ->
  # Function Constructor to include Chains in Chains
  ch = (fn) ->
    chain = process_inner_chain fn
    chain.value = chain.value.concat ch.value
    chain

  # Chain Execution to start the Flow
  # Multiple Parameters: for beginning Broadcast with different messages
  ch.exec =  (init...) ->
    init = decompress init
    reqres = init
    reqres.push {}        # Blank res object
    reqres.push ch.value  # The process chain
    service = new Micros.MicroService 'router' # Dummy Router
    service.$next.apply service, reqres

  # Assimilate chaintypes to own chain
  ch.value =
    if chain?._type is Micros.MicroService
      process_inner_chain(-> chain).value
    else if chain?._type is Micros.Broadcast
      [chain.value]
    else if chain?._type is Micros.Chain or typeof chain is 'object'
      chain.value
    else if typeof chain is 'function'
      process_inner_chain(chain).value
    else []

  ch._this = @
  ch._type = Micros.Chain
  ch

Micros.Broadcast = (chains...) ->
  # Combine Broadcast with after Chain
  bc = (fn) ->
    chain = new Micros.Chain fn
    chain.value = chain.value.concat [bc.value]
    chain

  bc.exec = (init...) ->
    (new Micros.Chain bc).exec.apply bc, init

  bc.value =
    (new Micros.Chain chn).value for chn in chains

  # if chain?
  #  chain = bc chain
  #  return chain

  bc._this = @
  bc._type = Micros.Broadcast
  bc

###
  Chains:
    # Begin the chain at your desire
    new Chain -> f1 -> f2 -> f3 -> f4 -> f5
    new Chain f1 -> f2 -> f3 -> f4 -> f5

    # Defining Broadcasts and Akkumulators (Gathers)
    new Chain f1 -> f2 -> Broadcast(f3 -> f4, f3) -> f5

    # Include Chains in Chains
    inner_chain = new Chain -> f2 -> f3 -> f4
    new Chain f1 -> inner_chain -> f5

    # Use MicroService Methods to costimize your service and API
    new Chain -> f1 -> f2.method -> f3 -> f4

    # Use Parameters for better variation (works also with service methods)
    new Chain f1 3, -> f2.method -> f3.method 'msg', -> f4 -> f5
      # => is the first Parameter a String the value will be interpreted as Micro Service method

    # Alternative Parameter Syntax
    new Chain f1(3) -> f2.method -> f3.method('msg') -> f4 -> f5
###

###
    Service Handler: req, res, params..., next
    # ´next´ stand for a function with additional informations
    next.chain      # further chain
    next.previous   # previous service

    # Call ´next´ with multiple request for different messages to send on each broadcast link
    # If there exist only one request object then all broadcast links will receive the same message
    next req1, req2, re3, ..., res      # Multiple Requests for Broadcast
    next req, res                       # Only one request for all Broadcast links

    # For a gather service (with gather key)
    (req[], res[], params..., next)     # `req` and `res` are arrays with all gathered requests and responses
    next.chain                          # The further chain (unchanged)
    next.previous                       # Previous services from broadcast (Array)
###

###
  # A parsed chain in array notation
  chain = [
    {                               # Object that saves MicroService information
      name: ms.$name
    },
    [                               # Broadcast
      [                             # First broadcast link as inner Chain
        {                           # First MicroService from an inner Chain
          name: ms.$name,
          params: ['first', 'second', 'third']
        }
      ],
      [                             # Second broadcast link as inner Chain
        {                           # First MicroService from the second inner Chain
          name: ms.$name,
          method: 'action_handler'
        },
        {                           # Second MicroService from the second inner Chain
          name: ms.$name,
        }
      ]
    ],
    {                               # A Gather MicroService after a Broadcast
      name: ms.$name,
      api: 'http'
      port: 3030
    }
  ]
###

###
  # Inter Communication Message (ICM)
  message = {
    request: {...}    # The Request Object with processing parameters
    response: {...}   # The Response Object with processing results
    chain: [...]      # The further chain
    sender: 'sender'  # The senders $module_name
    params: [...]     # As Array (optional)
    method: 'method'  # The MicroService method (optional)
    gather: {         # Used for Gather the same chain over multiple requests (optional)
      key: 'd6sd436'
      services: 5     # Service counter
    }
  }
###

###
  Todo:
    - Abort, Timeout the chain after a broadcast (gather)
###