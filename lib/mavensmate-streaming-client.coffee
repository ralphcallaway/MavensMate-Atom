emitter     = require('./mavensmate-emitter').pubsub
util        = require './mavensmate-util'
logFetcher  = require('./mavensmate-log-fetcher').fetcher
faye        = require 'faye'

module.exports =
class StreamingClient
  
  client: null

  constructor: () ->
    # console.log 'setting up streaming client ...'
    @api_version = atom.config.getSettings()['MavensMate-Atom'].mm_api_version
    @subscribeToMavensMateEvents()
    @setup()

  # file system watcher emits session-updated when .session changes
  # change could include endpoint and/or sid, so we need to reconfigure our client
  subscribeToMavensMateEvents: ->
    thiz = @
    emitter.on 'mavensmate:session-updated', (session) =>
      thiz.setup()

  setup: ->
    # todo: set _endpoint & headers instead of instantiating new client if already exists?
    if atom.project.session? 
      baseUrl = util.baseSalesforceUrl(atom.project.session.server_url)
      @client = new Faye.Client(baseUrl+'/cometd/'+@api_version);
      @client.setHeader('Authorization', 'Bearer '+atom.project.session.sid);
      
      @client.subscribe "/systemTopic/Logging", (message) ->
        # console.log "\n\n\n\n\nGot a LOG!!!!! "
        # console.log message
        logFetcher.goFetch(message.sobject.Id)
        return

      # todo: future testresult handling
      # @client.subscribe "/systemTopic/TestResult", (message) ->
      #   console.log "\n\n\n\n\nGot a TEST RESULT!!!!! "
      #   console.log message
      #   return  