{ScrollView}  = require 'atom'
path          = require 'path'
util          = require './mavensmate-util'
emitter       = require('./mavensmate-emitter').pubsub

module.exports =
  class MavensMateServerView extends ScrollView

    constructor: (@params) ->
      super
     
      @url = @params.urls[0]
      @page = @params.pages[0]
      @promiseId = @params.promiseId
      
      @iframe.attr 'src', @url
      @iframe.attr 'id', 'iframe-'+@promiseId

      @iframe.focus()

      me = @
      emitter.on 'mavensmate:compile-finished', (params, promiseId) ->
        buffer = me.params.buffer
        files = params.payload.files
        if buffer.file? and util.isMetadata(buffer.file.getBaseName())
          for f in files
            if util.baseName(f) == me.page
              me.iframe.attr 'src', me.url
              break

    @deserialize: (state) ->
      new MavensMateServerView(state)

    # Internal: Initialize mavensmate output view DOM contents.
    @content: ->
      @div class: 'mavensmate', =>
        @iframe outlet: 'iframe', width: '100%', height: '100%', class: 'native-key-bindings', sandbox: 'allow-same-origin allow-top-navigation allow-forms allow-scripts', style: 'border:none;'

    serialize: ->
        deserializer: 'MavensMateServerView'
        version: 1
        uri: @uri

    getTitle: ->
      @page

    getIconName: ->
      'browser'

    getUri: ->
      @uri

    # Tear down any state and detach
    destroy: ->
      console.log 'destroying'
      console.log @
      @detach()



