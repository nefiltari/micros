## Libs

coffee = require 'coffee-script'
_ = require 'underscore'
async = require 'async'

## Exports

MicroService = require('micros').MicroService
Print = new MicroService 'print'
Print.$set 'api', 'ws'

runtime = (req, res, next) ->
  console.log res
  next req, res

Print.$install runtime

## Export

module.exports = Print