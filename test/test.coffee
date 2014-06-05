## Libs
coffee = require 'coffee-script'
require 'coffee-script/register'
_ = require 'underscore'
async = require 'async'

## FLD

Micros = require 'micros'
MicroService = Micros.MicroService
Chain = Micros.Chain
Broadcast = Micros.Broadcast

## Code
Micros.set 'ms_folder', 'services'

# Spawm services
Micros.spawn (service) -> eval "#{service.$name} = service"

cb = ->
  # Define Chain 1
  inner_chain = new Chain inc -> inc -> inc
  #chain = new Chain add(3) -> inner_chain -> add.sub(10) -> print
  #chain.exec 2

  # Define Chain 2
  broadcast = new Broadcast inner_chain, inner_chain, add(2)
  chain = add(3) -> broadcast -> add.min -> print
  chain.exec 5

setTimeout cb, 2000

###
http = require 'http'
server = http.createServer (req,res) -> do res.end
server.listen 4000


###
