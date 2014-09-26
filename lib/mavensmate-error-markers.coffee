{Subscriber,Emitter}  = require 'emissary'
util                  = require './mavensmate-util'
emitter               = require('./mavensmate-emitter').pubsub

module.exports =
class MavensMateErrorMarkers
  Subscriber.includeInto(this)

  constructor: (@editorView) ->
    { @editor, @gutter } = @editorView

    @initialize()
    @refreshMarkers()

  initialize: ->
    thisView = @
    emitter.on 'mavensmate:compile-finished', (params) ->
      thisView.refreshMarkers()

  clearMarkers: ->
    return unless @markers?
    marker.destroy() for marker in @markers
    @markers = null

  refreshMarkers: ->
    return unless @gutter.isVisible()
    if @editor.getPath() 
      if atom.project.errors[@editor.getPath()]?
        errors = atom.project.errors[@editor.getPath()]
      else
        currentFileNameWithoutExtension = util.withoutExtension(util.baseName(@editor.getPath()))
        errors = atom.project.errors[currentFileNameWithoutExtension] ? []
      
    @clearMarkers()

    if errors?
      lines_to_highlight = (error['lineNumber'] for error in errors when error['lineNumber']?)
      for line in lines_to_highlight
          @markRange(line-1, line-1, 'mm-compile-error-gutter', 'gutter')
          @markRange(line-1, line-1, 'mm-compile-error-line', 'highlight')

  markRange: (startRow, endRow, klass, type) ->
    # todo: range = editor.getBuffer().rangeForRow(34)?
    marker = @editor.markBufferRange([[startRow, 0], [endRow, Infinity]], invalidate: 'never')
    @editor.decorateMarker(marker, type: type, class: klass)
    @markers ?= []
    @markers.push(marker)
