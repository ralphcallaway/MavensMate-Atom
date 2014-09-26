{$}     = require 'atom'
util    = require './mavensmate-util'
emitter = require('./mavensmate-emitter').pubsub
fs      = require 'fs'
path    = require 'path'
moment  = require 'moment'

window.jQuery = $

module.exports =
  class MavensMateCheckpointHandler

    constructor: (@editorView, @mm, @responseHandler) ->
      { @editor, @gutter } = @editorView
      # @mm = mm
      # @responseHandler = rh
      # console.log @responseHandler
      @initialize()
      @refreshMarkers()
      @handleGutterClickEvents()

    initialize: ->
      # when save/fetch starts clear markers out
      emitter.on 'mavensmate:panel-notify-start', (params, promiseId) =>
        @clearMarkers() if params.args? and (params.args.operation is 'compile' or params.args.operation is 'index_apex_overlays')

      # when save/fetch finishes refresh checkpoints to ensure they are in sync with the server
      emitter.on 'mavensmate:panel-notify-finish', (params, result) =>
        @refreshCheckpoints() if params.args.operation is 'compile'
        @refreshMarkers()     if params.args.operation is 'index_apex_overlays'

    clearMarkers: ->
      return unless @markers?
      marker.destroy() for marker in @markers
      @markers = null

    refreshMarkers: ->
      return unless @gutter.isVisible()
      @currentFile ?= util.activeFileBaseName()
      @clearMarkers()

      if atom.project.path and @currentFile?
        fs.readFile path.join(atom.project.path, 'config', '.overlays'), (error, data) =>
          if error
            console.log error
          else
            overlays = JSON.parse data
            atom.project.checkpointCount = overlays.length
            for overlay in overlays
              if overlay.API_Name is @currentFile.split('.')[0]
                line = parseInt overlay.Line
                marked = @markRange line-1, line-1, 'mm-checkpoint-gutter', 'gutter'
                marked.marker.mm_checkpointId = overlay.Id

    markRange: (startRow, endRow, klass, type) ->
      marker = @editor.markBufferRange([[startRow, 0], [endRow, Infinity]], invalidate: 'inside')
      decoration = @editor.decorateMarker(marker, type: type, class: klass)
      @markers ?= []
      @markers.push(marker)
      return { marker: marker, decoration: decoration }

    handleGutterClickEvents: ->
      @editorView.find('.line-numbers').on 'click', '.line-number', (event) =>
        target = $(event.target)

        # ignore clicks on icons in the right of the gutter so that collapsing and other events can still occur
        # ignore clicks on gutter lines that are processing
        return if target.hasClass 'icon-right' or target.hasClass 'mm-checkpoint-gutter-processing'

        @currentFile ?= util.activeFileBaseName()
        return unless util.isClassOrTrigger(@currentFile)

        line = parseInt target.text()
        if target.hasClass 'mm-checkpoint-gutter'
          # iterate over the markers in reverse and destroy the marker and remove from @markers if matches on row
          for marker, index in @markers by -1
            if (marker.oldHeadBufferPosition.row + 1) is line
              @toggleCheckpoint marker, null if marker.mm_checkpointId?
              @markers.splice index, 1
              marker.destroy()
              atom.project.checkpointCount--
        else
          if atom.project.checkpointCount >= util.sfdcSettings.maxCheckpoints
            atom.confirm
              message: 'Too many checkpoints'
              detailedMessage: "Cannot set more than #{util.sfdcSettings.maxCheckpoints} checkpoint locations"
              buttons:
                Ok: null
                'Refresh Checkpoints': @refreshCheckpoints
            return
          atom.project.checkpointCount++
          marked = @markRange line-1, line-1, 'mm-checkpoint-gutter-processing', 'gutter'
          @toggleCheckpoint marked.marker, marked.decoration

    refreshCheckpoints: =>
      now = moment()
      
      secondsSinceLastSync = now.diff(atom.mavensmate.lastCheckpointSync, 'seconds')
      
      console.debug 'last checkpoint sync: '
      console.debug atom.mavensmate.lastCheckpointSync
      console.debug 'seconds since last sync'
      console.debug secondsSinceLastSync

      if atom.mavensmate.lastCheckpointSync == undefined or secondsSinceLastSync >= 90
        console.debug 'SYNCING CHECKPOINTS =====>'
        atom.mavensmate.lastCheckpointSync = moment()
        params =
          args:
            operation: 'index_apex_overlays'
            pane: atom.workspace.getActivePane()
        @mm.run(params).then (result) =>
          @refreshMarkers()
          @responseHandler params, result

    toggleCheckpoint: (marker, decoration) ->
      payload = {}
      op = ''
      fileName = @currentFile.split('.')[0]

      if marker.mm_checkpointId?
        op = 'delete_apex_overlay'
        payload = id: marker.mm_checkpointId
      else
        op = 'new_apex_overlay'
        payload =
          Iteration: 1
          IsDumpingHeap: true
          Line: marker.oldHeadBufferPosition.row + 1
          Object_Type: if @currentFile.indexOf('.cls') >= 0 then 'ApexClass' else 'ApexTrigger'
          API_Name: fileName
          ActionScriptType: 'None'

      thiz = @
      params =
        args:
          operation: op
          pane: atom.workspace.getActivePane()
        payload: payload
      @mm.run(params).then (result) =>
        marker.mm_checkpointId = result.id
        if params.args.operation is 'new_apex_overlay'
          decoration.update {type: 'gutter', class: 'mm-checkpoint-gutter'}
        thiz.responseHandler(params, result)
