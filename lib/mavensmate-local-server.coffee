Q           = require 'q'
# import loophole to get around unsafe eval error on bodyParser
# similar to https://discuss.atom.io/t/--template-causes-unsafe-eval-error/9310
{allowUnsafeEval} = require 'loophole'
bodyParser  = allowUnsafeEval -> require 'body-parser'
tracker     = require('./mavensmate-promise-tracker').tracker
mm          = require('./mavensmate-cli').mm
emitter     = require('./mavensmate-emitter').pubsub

module.exports =

  class LocalServer

    promiseTracker: null
    mm: null
    httpServer: null

    constructor: () ->
      @promiseTracker = tracker
      @mm = mm

    stop: ->
      if @httpServer?
        @httpServer.close()

    # # Tear down any state and detach
    destroy: ->
      if @httpServer?
        @httpServer.close()
    # returns promise
    #
    # promise resolves with port number
    start: ->
      deferred = Q.defer()
      @getPort deferred
      deferred.promise

    getPort: (deferred) ->
      portfinder = require 'portfinder'

      portfinder.getPort (err, port) =>
        @startServer port
        deferred.resolve port

    # extremely important middleware; without it, webkit refuses ajax requests from MavensMate UIs
    enableCors: (req, res, next) ->
      res.header 'Access-Control-Allow-Origin', '*'
      res.header 'Access-Control-Allow-Methods', 'GET,POST,OPTIONS'
      res.header 'Access-Control-Allow-Headers', ['Content-Type', 'X-Requested-With', 'mm_plugin_client']
      next()



    # Route handlers

    statusRequest: (req, res) ->
      tracker = req.app.get('tracker');
      promiseId = req.query.id
      if tracker.isPromiseComplete(promiseId)
        res.send tracker.pop(promiseId).result # pops promise from tracker and returns result
        emitter.emit 'mavensmate:promise-completed', promiseId
      else
        res.send { 'status' : 'pending', 'id' : promiseId }

    synchronousPostRequestHandler: (req, res) ->
      mm = req.app.get('mm')
      params =
        payload:req.body
      mm.run(params).then (result) ->
        res.send result
        tracker.pop(result.promiseId).result # pops promise from tracker and returns result
        emitter.emit 'mavensmate:promise-completed', result.promiseId
        emitter.emit 'mavensmate:panel-notify-finish', params, result, result.promiseId

    synchronousGetRequestHandler: (req, res) ->
      mm = req.app.get('mm')
      params =
        payload:req.query
      mm.run(params).then (result) ->
        res.send result
        tracker.pop(result.promiseId).result # pops promise from tracker and returns result
        emitter.emit 'mavensmate:promise-completed', result.promiseId
        emitter.emit 'mavensmate:panel-notify-finish', params, result, result.promiseId

    asynchronousPostRequestHandler: (req, res) ->
      tracker = req.app.get('tracker')
      mm = req.app.get('mm')
      promiseId = tracker.enqueuePromise()
      params =
        payload:req.body
        promiseId:promiseId
      mm.run(params).then (result) ->
        emitter.emit 'mavensmate:promise-completed', result.promiseId
        emitter.emit 'mavensmate:panel-notify-finish', params, result, result.promiseId
      res.send { 'status' : 'pending', 'id' : promiseId }

    asynchronousGetRequestHandler: (req, res) ->
      tracker = req.app.get('tracker')
      mm = req.app.get('mm')
      promiseId = tracker.enqueuePromise()
      params =
        payload:req.query
        promiseId:promiseId
      mm.run(params).then (result) ->
        emitter.emit 'mavensmate:promise-completed', result.promiseId
        emitter.emit 'mavensmate:panel-notify-finish', params, result, result.promiseId
      res.send { 'status' : 'pending', 'id' : promiseId }

    options: (req, res) ->
      res.send 200

    # /Route handlers



    startServer: (port) ->
      express = allowUnsafeEval -> require 'express'
      app = express()

      app.use(bodyParser.json())
      app.use(@enableCors)

      app.set('tracker', @promiseTracker); #todo: should server have its own instance?
      app.set('mm', @mm);

      app.get('/status', @statusRequest)

      app.options('/generic', @options)
      app.options('/generic/async', @options)

      app.post('/generic/async', @asynchronousPostRequestHandler)
      app.get('/generic/async', @asynchronousGetRequestHandler)

      app.post('/generic', @synchronousPostRequestHandler)
      app.get('/generic', @synchronousGetRequestHandler)

      # workaround to enable stopping of express.js server: https://github.com/strongloop/express/issues/1101#issuecomment-13668964
      @httpServer = require('http').createServer(app);
      @httpServer.listen port

      console.log 'express.js listening on port: '+port
