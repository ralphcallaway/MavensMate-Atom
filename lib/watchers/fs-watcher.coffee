watchr  = require 'watchr'
emitter = require('../mavensmate-emitter').pubsub
util    = require '../mavensmate-util'
path    = require 'path'

module.exports =
class FileSystemWatcher
  
  constructor: (@projectPath) ->
    console.log 'setting up FileSystemWatcher for: '+@projectPath
    @initialize()

  initialize: ->
    @configPath = path.join(atom.project.path,'config')
    @sessionPath = path.join(atom.project.path,'config','.session')
    thiz = @
    watchr.watch
      paths: [
        @configPath
      ]
      listeners:
        # log: (logLevel) ->
        #   console.log "a log message occured:", arguments
        #   return

        # error: (err) ->
        #   console.log "an error occured:", err
        #   return

        watching: (err, watcherInstance, isWatching) ->
          if err
            console.log "watching the path " + watcherInstance.path + " failed with error", err
          else
            console.log "watching the path " + watcherInstance.path + " completed"

          return

        change: (changeType, filePath, fileCurrentStat, filePreviousStat) ->
          
          if changeType == 'update' or changeType == 'create'
            # updates atom.project.session with most recent session information
            if filePath == thiz.sessionPath
              console.log '.session CREATED!'
              newSession = util.fileBodyAsString(filePath, true)
              atom.project.session = newSession
              emitter.emit 'mavensmate:session-updated', newSession
          if changeType == 'delete'
            # clears atom.project.session
            if filePath == thiz.sessionPath
              console.log '.session deleted!'
              delete atom.project.session
              emitter.emit 'mavensmate:session-updated', undefined

          return
