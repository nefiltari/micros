# The Micros-Framework
The programming approach to create software that is lightwight in development and has less cross dependencies to build anit-monolitic software. Each programming feature stands with his own dependencies alone (as a module) and redirects to other modules to complete the main process. The concept follows a simple pipe that is optionally splitted in multiple sub-pipes to process parallel working tasks and combine all sub results for further processing. You can switch between different communication models like http or websockets. This Framework is inspired by [Express](http://expressjs.com) ([Connect](http://www.senchalabs.org/connect/)), the [MicroService growth](http://martinfowler.com/articles/microservices.html) and [message passing interfaces](http://de.wikipedia.org/wiki/Message_Passing_Interface) (like scatter, gather, accumlators and broadcasts). Each process is a predefined chain that describe the data flow throught the modules. The last module must output the result in different ways. This framework is a product from the Bachelor Thesis [Social Media Recommendations](http://vsr.informatik.tu-chemnitz.de/edu/studentprojects/2013/024) from Francesco Möller, Josua Koschwitz and Maximilian Stroh.

## Create a MicroService
TL;DR: Here is a short example for a MicroService that add two numbers or accumulate over multiple numbers (sum):
```coffeescript
# Create a new MicroService
MicroService = require('micros').MicroService
add = new MicroService 'add'                    # Create a new MicroService with a given name
add.$set 'api', 'ws'                            # Set the API on websockets

# Define the Runtime
# Standard Addition
runtime = (req, res, next, params...) ->        # The method definition follows an Express middleware with optional params
  next req + params[0], req + params[0]

# An accumulator or sum
runtime.sum = (req, res, next) ->
  res = req.reduce ((akk, val) -> val + akk), 0
  next res, res

# A minimum function over all incomming numbers
runtime.min = (req, res, next) ->
  res = req.reduce ((akk, val) -> if val < akk then val else akk), req[0]
  next res, res

# Install the runtime
add.$install runtime

## Module Export
module.exports = add
```
All MicroServices will be included with `require` and can be used in chains and other features. The method `next` calls the next MicroService of the underlying chain. For better functional support you can get the chain context in which the MicroService was called from `next` with `next.chain` for all further comming services and `next.previous` for the previous MicroService. You can call `next` with multiple request objects to differ data for next broadcast or an accumulate.
If there exist only one request object for a upcomming broadcast, all MicroServices from the broadcast gets the same request:
```coffeescript
next req1, req2, req3, reqn, res                  # Multiple requests for Broadcast
# or
next req, res                                     # Only one request for all Broadcast links
```
Their always exist one response object with excepttion for an previous accumulate from a broadcast.

## Chains:
The chains are valid CoffeeScript but can read as a flowing pipe.
Begin the chain at your desire:
```coffeescript
chain1 = new Chain m1 -> m2 -> m3 -> m4 -> m5
chain2 = new Chain -> m1 -> m2 -> m3 -> m4 -> m5
chain3 = Chain -> m1 -> m2 -> m3 -> m4 -> m5
chain4 = m1 -> m2 -> m3 -> m4 -> m5
```
Defining broadcasts and accumulators (Gathers):
```coffeescript
chain = new Chain f1 -> f2 -> Broadcast(f3 -> f4, f3) -> f5
```
You can include Chains in Chains:
```coffeescript
inner_chain = new Chain -> f2 -> f3 -> f4
chain = new Chain f1 -> inner_chain -> f5
```
Use custom MicroService methods to better control your level of abstraction:
```coffeescript
chain = new Chain -> f1 -> f2.method -> f3 -> f4
```
Use parameters for better variation (works also with service methods).
This parameters cames from the described chains and can be found in `params` from MicroService method definitions:
```coffeescript
chain = new Chain f1 3, -> f2.method -> f3.method 'msg', -> f4 -> f5
```
An alternative parameter syntax:
chain = new Chain f1(3) -> f2.method -> f3.method('msg') -> f4 -> f5

## Messages
The Inter Communication Message (ICM) from MPI's are use to send information between MicroServices. The messages are described in JSON and are planned with other formats in the future (like ProtoBuf).
```coffeescript
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
```