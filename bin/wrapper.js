#!/usr/bin/env node
require('../node_modules/coffee-script/register')
var module = process.argv[2]
var port = process.argv[3]
var cwd = process.cwd()
var service = {}
try {
  service = require(cwd + '/' + module)
} catch(e) {}
service.$deamon(port)