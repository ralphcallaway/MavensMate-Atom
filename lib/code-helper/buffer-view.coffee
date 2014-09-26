{View} = require 'atom'
Tooltip = require './tooltip'
BufferItemView = require './buffer-item-view'

module.exports =
class BufferView extends View
  
  @content: ->
    @div class: 'mavensmate-code-helper'

  subscriptions: []
  itemViews: []
  itemViewsDict: {}

  constructor: (@editorView) ->
    super
  #   @editorView.append(this)
  #   # @subscriptions.push atom.workspaceView.on 'pane:active-item-changed', =>
  #   #   if @editor.id is atom.workspace.getActiveEditor()?.id
  #   #     @showMarkers()
  #   #   else
  #   #     @hideMarkers()

    @handleBufferEvents()

  initialize: (@editorView) ->
    @editorView.overlayer.append this
    @editor = @editorView.getEditor()
    # @toggleButtons =
    #   line: @lineToggle
    #   gutter: @gutterToggle
    #   highlight: @highlightToggle

    # @lineToggle.on 'click', => @toggleDecorationForCurrentSelection('line')
    # @gutterToggle.on 'click', => @toggleDecorationForCurrentSelection('gutter')
    # @highlightToggle.on 'click', => @toggleDecorationForCurrentSelection('highlight')

    # @lineColorCycle.on 'click', => @cycleDecorationColor('line')
    # @gutterColorCycle.on 'click', => @cycleDecorationColor('gutter')
    # @highlightColorCycle.on 'click', => @cycleDecorationColor('highlight')

    # atom.workspaceView.on 'pane-container:active-pane-item-changed', => @handleDisplay()
    # editor = atom.workspace.getActiveEditor()
    # range = editor.getBuffer().rangeForRow 2

    @run()

    # # Get the user's selection from the editor
    # range = editor.getSelectedBufferRange()

    # # create a marker that never invalidates that folows the user's selection range
    # marker = editor.markBufferRange(range, invalidate: 'never')

    # # create a decoration that follows the marker. A Decoration object is returned which can be updated
    # decoration = editor.decorateMarker(marker, type: type, class: "#{type}-#{@getRandomColor()}")
    # decoration

  # should show all markers on the buffer
  showMarkers: ->
    # console.log 'showing markers!'
    # console.log @itemViews
  
  # should hide all markers on the buffer
  hideMarkers: ->
    # console.log 'hiding markers!'
    # console.log @itemViews

  # Internal: register handlers for editor buffer events
  handleBufferEvents: =>
    buffer = @editor.getBuffer()

    # @subscriptions.push buffer.on 'reloaded saved', (buffer) =>
    #   @throttledLint() if @lintOnSave

    # @subscriptions.push buffer.on 'destroyed', ->
    #   buffer.off 'reloaded saved'
    #   buffer.off 'destroyed'

    @subscriptions.push @editor.on 'contents-modified', =>
      @run()

    # atom.workspaceView.command "linter:lint", => @lint()

  run: ->

    res = []
    res.push /@future/gi
    res.push /implements Database.Batchable/gi
    res.push /SeeAllData=true/gi
    res.push /without sharing/gi
    res.push /[A-Z0-9][A-Z0-9][A-Z0-9]\.visual\.force\.com/gi

    thiz = @

    # iterate regex, determine whether to add markers
    for metadata in atom.mavensmate.codeHelperMetadata

      regexString = metadata.regex.replace(/\//, '')
      regexString = regexString.replace(/\/.{0,3}$/, '')
      re = new RegExp(regexString, "gi")
      
      # console.log 'SCANNING FOR: '+re
      
      thiz.editor.getBuffer().scan re, (bufferMatch) ->
        # console.log 'found match: '
        # console.log bufferMatch
        # console.log bufferMatch.range
        if not thiz.itemViewsDict[bufferMatch.range]?
          # console.log 'MATCH DOES NOT EXIST CURRENTLY ---------------->'
          bufferMatch.metadata = metadata
          # console.log bufferMatch

          itemView = new BufferItemView thiz, bufferMatch
          # console.log 'created item view ~~~~~~~~~>'
          # console.log itemView
          # editor.decorateMarker marker, type: 'line', class: 'line-stackframe'
          # editor.decorateMarker marker, type: 'gutter', class: 'gutter-stackframe'
          thiz.itemViews.push itemView
          thiz.itemViewsDict[itemView.bufferMatch.range] = itemView

  removeBufferItem: (range) ->
    delete @itemViewsDict[range]

  # Tear down any state and detach
  destroy: ->
    @detach()

  toggleTooltipWithCursorPosition: ->
    @violationTooltip = @createViolationTooltip()
    # console.log @violationTooltip
    @violationTooltip.show()
    # cursorPosition = @editor.getCursor().getScreenPosition()

    # if cursorPosition.row is @screenStartPosition.row &&
    #    cursorPosition.column is @screenStartPosition.column
    #   # @tooltip conflicts with View's @tooltip function.
    #   @violationTooltip ?= @createViolationTooltip()
    #   @violationTooltip.show()
    # else
    #   @violationTooltip?.hide()

  createViolationTooltip: ->
    # console.log 'creating tooltip bitch!'
    options =
      violation: @violation
      container: @lintView
      selector: @find('.code-helper-item-area')
      editorView: @editorView

    new Tooltip(this, options)