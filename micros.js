// Generated by CoffeeScript 1.7.1
(function() {
  var Micros, async, coffee, decompress, generate_key, process_inner_chain, _,
    __slice = [].slice;

  Micros = (typeof exports !== "undefined" && exports !== null) && exports || (this.Micros = {});

  coffee = require('coffee-script');

  require('coffee-script/register');

  _ = require('underscore');

  async = require('async');

  decompress = function(arr) {
    if (arr instanceof Array && arr.length === 1 && arr[0] instanceof Array) {
      arr = arr[0];
    }
    return arr;
  };

  generate_key = function() {
    return (new Date).valueOf() + '' + Math.floor((Math.random()) * Math.pow(10, 8));
  };

  process_inner_chain = function(fn) {
    var chain;
    chain = fn();
    if ((chain != null ? chain._type : void 0) === Micros.MicroService) {
      chain = chain(function() {
        return new Micros.Chain;
      });
    }
    if ((chain != null ? chain._type : void 0) === Micros.Broadcast) {
      chain = new Micros.Chain(chain);
    }
    return chain;
  };

  Micros.Config = {
    ms_folder: 'node_modules',
    log_folder: 'logs',
    start_port: 4500,
    prefix: 'micros'
  };

  Micros.set = function(key, value) {
    return Micros.Config[key] = value;
  };

  Micros.get = function(key) {
    return Micros.Config[key];
  };

  Micros.spawn = function(cb) {
    var cwd, fs, port, services;
    fs = require('fs');
    cwd = process.cwd();
    port = Micros.Config['start_port'];
    services = fs.readdirSync("" + cwd + "/" + Micros.Config['ms_folder']);
    services = _.filter(services, function(ele) {
      return ele.match("^" + Micros.Config['prefix'] + "-(.*)");
    });
    return async.each(services, function(name) {
      var service;
      try {
        service = require("" + cwd + "/" + Micros.Config['ms_folder'] + "/" + name);
        service.$spawn(name, port);
        cb(service);
        return port = port + 1;
      } catch (_error) {}
    });
  };

  Micros.MicroService = function(name) {
    var ms;
    ms = function() {
      var chain, fn, method, params, service, _i;
      params = 2 <= arguments.length ? __slice.call(arguments, 0, _i = arguments.length - 1) : (_i = 0, []), fn = arguments[_i++];
      params = decompress(params);
      if (this instanceof String) {
        method = this.toString();
      }
      if (typeof fn !== 'function') {
        params.push(fn);
        fn = function() {
          return new Micros.Chain;
        };
      }
      service = {
        name: ms.$name
      };
      if (params.length > 0) {
        service.params = params;
      }
      if (method != null) {
        service.method = method;
      }
      service.api = ms.$config.api;
      service.port = ms.$config.port;
      chain = process_inner_chain(fn);
      chain.value.push(service);
      return chain;
    };
    ms.$name = name;
    ms.$cache = {};
    ms.$gathers = {};
    ms.$timeouts = [];
    ms.$config = {};
    if (ms.$config['timeout'] == null) {
      ms.$config.timeout = 10 * 1000;
    }
    ms.$install = function(runtime) {
      var key, value, _ref, _results;
      ms.$runtime = runtime;
      _ref = ms.$runtime;
      _results = [];
      for (key in _ref) {
        value = _ref[key];
        ms[key] = (function(method) {
          return function() {
            var fn, params, _i;
            params = 2 <= arguments.length ? __slice.call(arguments, 0, _i = arguments.length - 1) : (_i = 0, []), fn = arguments[_i++];
            params = decompress(params);
            return ms.call(new String(method), params, fn);
          };
        })(key);
        ms[key]._type = Micros.MicroService;
        _results.push(ms[key]._this = this);
      }
      return _results;
    };
    ms.$map = ms.$install;
    ms.$set = function(key, value) {
      return ms.$config[key] = value;
    };
    ms.$get = function(key) {
      return ms.$config[key];
    };
    ms.$next = function() {
      var chain, http, i, link, message, next, options, path, req, request, res, util, _i, _j, _len, _results;
      req = 3 <= arguments.length ? __slice.call(arguments, 0, _i = arguments.length - 2) : (_i = 0, []), res = arguments[_i++], chain = arguments[_i++];
      req = decompress(req);
      if (chain.length === 0) {
        return;
      }
      util = require('util');
      next = chain.pop();
      if (util.isArray(next)) {
        if ((_.last(chain)) != null) {
          chain[chain.length - 1].gather = {
            key: generate_key(),
            services: next.length
          };
        }
      } else {
        next = [next];
      }
      _results = [];
      for (i = _j = 0, _len = next.length; _j < _len; i = ++_j) {
        link = next[i];
        path = chain;
        if (util.isArray(link)) {
          path = path.concat(link);
          link = path.pop();
        }
        message = {
          request: req[i],
          response: res,
          sender: ms.$name,
          chain: path
        };
        if (message.request == null) {
          message.request = _.last(req);
        }
        if ((i + 1) === next.length && (req[i + 1] != null)) {
          message.request = _.rest(req, i);
        }
        if (link.params != null) {
          message.params = link.params;
        }
        if (link.gather != null) {
          message.gather = link.gather;
        }
        if (link.method != null) {
          message.method = link.method;
        }
        switch (link.api) {
          case 'http':
            http = require('http');
            options = {
              port: link.port
            };
            options.method = 'POST';
            if (message.method != null) {
              options.path = "/" + message.method;
            }
            options.headers = {
              'Content-Type': 'application/json'
            };
            request = http.request(options);
            request.write(JSON.stringify(message));
            _results.push(request.end());
            break;
          case 'ws':
            if (!ms.$cache[link.name]) {
              ms.$cache[link.name] = require('socket.io-client').connect("http://localhost:" + link.port);
            }
            _results.push(ms.$cache[link.name].emit('icm', message));
            break;
          default:
            _results.push(void 0);
        }
      }
      return _results;
    };
    ms.$spawn = function(name, port, cb) {
      var error, exec;
      if (cb == null) {
        cb = function() {};
      }
      exec = require('child_process').exec;
      try {
        ms.$config['port'] = port;
        ms.$process = exec("" + __dirname + "/bin/wrapper.js " + Micros.Config['ms_folder'] + "/" + name + " " + port + " > " + Micros.Config['log_folder'] + "/" + name + ".log 2>&1");
      } catch (_error) {
        error = _error;
        return setTimeout(cb, 0, error);
      }
      return setTimeout(cb, 0);
    };
    ms.$call = function(message) {
      var key, next, stack;
      if (message.gather != null) {
        key = message.gather.key;
        if (ms.$gathers[key] == null) {
          ms.$gathers[key] = {
            requests: [],
            responses: [],
            previous: [],
            services: message.gather.services,
            next: function() {
              var req, res, _i;
              req = 2 <= arguments.length ? __slice.call(arguments, 0, _i = arguments.length - 1) : (_i = 0, []), res = arguments[_i++];
              return ms.$next.call(ms, req, res, message.chain);
            }
          };
          ms.$gathers[key].next.chain = message.chain;
          ms.$gathers[key].next.previous = [];
          setTimeout((function() {
            if (ms.$gathers[key] != null) {
              return delete ms.$gathers[key];
            }
          }), ms.$config.timeout);
        }
        ms.$gathers[key].requests.push(message.request);
        ms.$gathers[key].responses.push(message.response);
        ms.$gathers[key].next.previous.push(message.sender);
        ms.$gathers[key].services -= 1;
        if (ms.$gathers[key].services === 0) {
          stack = [];
          stack.push(ms.$gathers[key].requests);
          stack.push(ms.$gathers[key].responses);
          stack.push(ms.$gathers[key].next);
          if (message.params != null) {
            stack = stack.concat(message.params);
          }
          if (message.method != null) {
            process.nextTick((function() {
              return ms.$runtime[message.method].apply(ms, stack);
            }));
          } else {
            process.nextTick((function() {
              return ms.$runtime.apply(ms, stack);
            }));
          }
          return delete ms.$gathers[key];
        }
      } else {
        next = function() {
          var req, res, _i;
          req = 2 <= arguments.length ? __slice.call(arguments, 0, _i = arguments.length - 1) : (_i = 0, []), res = arguments[_i++];
          return ms.$next.call(ms, req, res, message.chain);
        };
        next.chain = message.chain;
        next.previous = message.sender;
        stack = [];
        stack.push(message.request);
        stack.push(message.response);
        stack.push(next);
        if (message.params != null) {
          stack = stack.concat(message.params);
        }
        if (message.method != null) {
          return process.nextTick((function() {
            return ms.$runtime[message.method].apply(ms, stack);
          }));
        } else {
          return process.nextTick((function() {
            return ms.$runtime.apply(ms, stack);
          }));
        }
      }
    };
    ms.$deamon = function(port) {
      var cluster;
      ms.$config['port'] = parseInt(port);
      if ((ms.$config.clusters != null) && ms.$config.clusters > 1) {
        cluster = require('cluster');
        if (cluster.isMaster()) {
          process.title = "MicroService: " + ms.$name + " (" + ms.$version + ") [master]";
          _.times(ms.$config.clusters, cluster.fork);
          cluster.on('exit', function(worker, code, signal) {
            return console.log("Worker[" + worker.id + "]: '" + ms.$name + "' stopped!");
          });
          return cluster.on('online', function(worker) {
            return console.log("Worker[" + worker.id + "]: '" + ms.$name + "' started!");
          });
        } else {
          process.title = "MicroService: " + ms.$name + " (" + ms.$version + ") [slave]";
          process.on('SIGTERM', function() {
            return ms.$shutdown(function(error) {
              if (error) {
                return console.log(error);
              }
            });
          });
          return ms.$listen(function(error) {
            if (error) {
              return console.log(error);
            }
          });
        }
      } else {
        process.title = "MicroService: " + ms.$name + " on port " + ms.$config.port;
        process.on('SIGTERM', function() {
          return ms.$shutdown(function(error) {
            if (!error) {
              return console.log("MicroService: '" + ms.$name + "' stopped!");
            } else {
              return console.log(error);
            }
          });
        });
        return ms.$listen(function(error) {
          if (!error) {
            return console.log("MicroService: '" + ms.$name + "' started on port: " + ms.$config.port);
          } else {
            return console.log(error);
          }
        });
      }
    };
    ms.$listen = function(cb) {
      var app, express, http, io;
      if (cb == null) {
        cb = function() {};
      }
      switch (ms.$config.api) {
        case 'http':
          express = require('express');
          app = express();
          app.use(express.json());
          app.post('/', function(req, res, next) {
            res.json(req.body);
            console.log("[" + (new Date) + "] New Request from " + req.body.sender + "!");
            return ms.$call(req.body);
          });
          app.post('/:method', function(req, res, next) {
            req.body.method = req.params['method'];
            console.log("[" + (new Date) + "] New Request from " + req.body.sender + "!");
            return ms.$call(req.body);
          });
          http = require('http');
          ms.$service = http.createServer(app);
          ms.$service.listen(ms.$config.port);
          break;
        case 'ws':
          io = require('socket.io');
          app = io.listen(ms.$config.port);
          app.set('log level', 0);
          app.sockets.on('connection', function(ws) {
            console.log("[" + (new Date) + "] New WebSocket connection from MicroService!");
            return ws.on('icm', function(message) {
              return ms.$call(message);
            });
          });
          app.sockets.on('disconnect', function(ws) {
            return console.log("[" + (new Date) + "] MicroService disconnected!");
          });
          ms.$service = app;
      }
      return setTimeout(cb, 0, null, ms.$service);
    };
    ms.$shutdown = function(cb) {
      var error;
      if (cb == null) {
        cb = function() {};
      }
      if (ms.$interval != null) {
        clearInterval(ms.$interval);
      }
      switch (ms.$config.api) {
        case 'http':
        case 'ws':
          try {
            ms.$service.close();
          } catch (_error) {
            error = _error;
            return setTimeout(cb, 0, error);
          }
      }
      return setTimeout(cb, 0);
    };
    ms._this = this;
    ms._type = Micros.MicroService;
    return ms;
  };

  Micros.Chain = function(chain) {
    var ch;
    ch = function(fn) {
      chain = process_inner_chain(fn);
      chain.value = chain.value.concat(ch.value);
      return chain;
    };
    ch.exec = function() {
      var init, reqres, service;
      init = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      init = decompress(init);
      reqres = init;
      reqres.push({});
      reqres.push(ch.value);
      service = new Micros.MicroService('router');
      return service.$next.apply(service, reqres);
    };
    ch.value = (chain != null ? chain._type : void 0) === Micros.MicroService ? process_inner_chain(function() {
      return chain;
    }).value : (chain != null ? chain._type : void 0) === Micros.Broadcast ? [chain.value] : (chain != null ? chain._type : void 0) === Micros.Chain || typeof chain === 'object' ? chain.value : typeof chain === 'function' ? process_inner_chain(chain).value : [];
    ch._this = this;
    ch._type = Micros.Chain;
    return ch;
  };

  Micros.Broadcast = function() {
    var bc, chains, chn;
    chains = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    bc = function(fn) {
      var chain;
      chain = new Micros.Chain(fn);
      chain.value = chain.value.concat([bc.value]);
      return chain;
    };
    bc.exec = function() {
      var init;
      init = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return (new Micros.Chain(bc)).exec.apply(bc, init);
    };
    bc.value = (function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = chains.length; _i < _len; _i++) {
        chn = chains[_i];
        _results.push((new Micros.Chain(chn)).value);
      }
      return _results;
    })();
    bc._this = this;
    bc._type = Micros.Broadcast;
    return bc;
  };


  /*
    Chains:
       * Begin the chain at your desire
      new Chain -> f1 -> f2 -> f3 -> f4 -> f5
      new Chain f1 -> f2 -> f3 -> f4 -> f5
  
       * Defining Broadcasts and Akkumulators (Gathers)
      new Chain f1 -> f2 -> Broadcast(f3 -> f4, f3) -> f5
  
       * Include Chains in Chains
      inner_chain = new Chain -> f2 -> f3 -> f4
      new Chain f1 -> inner_chain -> f5
  
       * Use MicroService Methods to costimize your service and API
      new Chain -> f1 -> f2.method -> f3 -> f4
  
       * Use Parameters for better variation (works also with service methods)
      new Chain f1 3, -> f2.method -> f3.method 'msg', -> f4 -> f5
         * => is the first Parameter a String the value will be interpreted as Micro Service method
  
       * Alternative Parameter Syntax
      new Chain f1(3) -> f2.method -> f3.method('msg') -> f4 -> f5
   */


  /*
      Service Handler: req, res, params..., next
       * ´next´ stand for a function with additional informations
      next.chain      # further chain
      next.previous   # previous service
  
       * Call ´next´ with multiple request for different messages to send on each broadcast link
       * If there exist only one request object then all broadcast links will receive the same message
      next req1, req2, re3, ..., res      # Multiple Requests for Broadcast
      next req, res                       # Only one request for all Broadcast links
  
       * For a gather service (with gather key)
      (req[], res[], params..., next)     # `req` and `res` are arrays with all gathered requests and responses
      next.chain                          # The further chain (unchanged)
      next.previous                       # Previous services from broadcast (Array)
   */


  /*
     * A parsed chain in array notation
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
   */


  /*
     * Inter Communication Message (ICM)
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
   */


  /*
    Todo:
      - Abort, Timeout the chain after a broadcast (gather)
   */

}).call(this);
