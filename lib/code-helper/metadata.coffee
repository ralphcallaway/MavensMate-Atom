https     = require 'https'
Q         = require 'q'

class CodeHelperMetadata

  retrieve: ->
    deferred = Q.defer()
    
    codeHelpers = []
    thiz = @
    https.get("https://mavensmate.herokuapp.com/api/codeHelpers", (res) ->
      # console.log "Got response: " + res.statusCode
      # console.log res
      data = ''

      res.on 'data', (d) ->
        data += d
        
      res.on 'end', (d) ->
        # console.log data
        deferred.resolve JSON.parse data

    ).on "error", (e) ->
      console.log "Got error: " + e.message
      deferred.reject e
      
    deferred.promise

module.exports = CodeHelperMetadata;