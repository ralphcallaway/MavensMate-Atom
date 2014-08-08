{Subscriber,Emitter}  = require 'emissary'
util                  = require './mavensmate-util'
emitter               = require('./mavensmate-emitter').pubsub

module.exports =
class MavensMateErrorView
  Subscriber.includeInto(this)

  constructor: (@editorView) ->
    { @editor, @gutter } = @editorView

    @initialize()
    @refreshMarkers()

  initialize: ->
    thisView = @
    emitter.on 'mavensmateCompileErrorBufferNotify', (command, params, result) ->
      thisView.refreshMarkers()
    emitter.on 'mavensmateCompileSuccessBufferNotify', (params) ->
      thisView.refreshMarkers()

  clearMarkers: ->
    return unless @markers?
    marker.destroy() for marker in @markers
    @markers = null

  refreshMarkers: ->
    return unless @gutter.isVisible()
    if @editor.getPath() then currentFileName = util.baseName(@editor.getPath())
    @clearMarkers()

    errors = atom.project.errors[currentFileName] ? []
    lines_to_highlight = (error['lineNumber'] for error in errors when error['lineNumber']?)
    for line in lines_to_highlight
        @markRange(line-1, line-1, 'mm-compile-error-gutter', 'gutter')
        @markRange(line-1, line-1, 'mm-compile-error-line', 'line')

  markRange: (startRow, endRow, klass, type) ->
    marker = @editor.markBufferRange([[startRow, 0], [endRow, Infinity]], invalidate: 'never')
    @editor.decorateMarker(marker, type: type, class: klass)
    @markers ?= []
    @markers.push(marker)
