## Libs

coffee = require 'coffee-script'
_ = require 'underscore'
async = require 'async'

## Exports

MicroService = require('micros').MicroService
Add = new MicroService 'add'
Add.$set 'api', 'ws'

runtime = (req, res, next, params...) ->
  next req + params[0], req + params[0]

runtime.sub = (req, res, next, params...) ->
  next req - params[0], req - params[0]

runtime.akk = (req, res, next) ->
  res = req.reduce ((akk, val) -> val + akk), 0
  next res, res

runtime.min = (req, res, next) ->
  res = req.reduce ((akk, val) -> if val < akk then val else akk), req[0]
  next res, res

Add.$install runtime

## Module Export

module.exports = Add