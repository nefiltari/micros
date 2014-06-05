## Libs

coffee = require 'coffee-script'
_ = require 'underscore'
async = require 'async'

## Exports

MicroService = require('micros').MicroService
Inc = new MicroService 'inc'
Inc.$set 'api', 'ws'

runtime = (req, res, next) ->
    next req+1, req+1

Inc.$install runtime

## Export

module.exports = Inc