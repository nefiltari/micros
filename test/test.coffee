## Libs
coffee = require '../node_modules/coffee-script'
require '../node_modules/coffee-script/register'
_ = require '../node_modules/underscore'
async = require '../node_modules/async'

## FLD

Micros = require '../micros.js'
MicroService = Micros.MicroService
Chain = Micros.Chain
Splitter = Micros.Splitter

## Code
Micros.set 'ms_folder', 'services'

# Spawm services
Micros.spawn (service) -> eval "#{service.$name} = service"

cb = ->
  # Define Chain 1
  inner_chain = new Chain inc -> inc -> inc
  chain = new Chain add(3) -> inner_chain -> add(10) -> print
  chain.exec 2

  # Define Chain 2
  splitter = new Splitter inner_chain, inner_chain, add(2)
  chain = add(3) -> splitter -> add.sum -> print
  chain.exec 5
  #console.log chain.value

setTimeout cb, 2000

###
http = require 'http'
server = http.createServer (req,res) -> do res.end
server.listen 4000


###
