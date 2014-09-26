_ = require 'lodash'
{$, View, Range, Point} = require 'atom'
ViolationTooltip        = require './tooltip'

module.exports =
class BufferItemView extends View
  @content: ->
    @div class: 'mavensmate-code-helper-item violation', =>
      @div class: 'code-helper-item-arrow'
      @div class: 'code-helper-item-area', outlet: 'area'

  initialize: (@bufferView, @bufferMatch) ->
    @bufferView.append(this)

    @editorView = @bufferView.editorView
    @editor = @editorView.getEditor()

    @initializeSubviews()
    @initializeStates()

    @trackEdit()
    @trackCursor()
    @showHighlight()
    @toggleTooltipWithCursorPosition()

    # console.log '============'
    # console.log @area
    
    # toggle tooltip visibility when area is clicked
    that = @
    @area.click ->
      # console.log 'ive been clicked!'
      that.myTooltip.toggle()

  initializeSubviews: ->
    @arrow = @find('.code-helper-item-arrow')
    # @arrow.addClass("violation-#{@violation.severity}")
    @arrow.addClass("violation-warning")

    @area = @find('.code-helper-item-area')
    @arrow.addClass("violation-warning")

  initializeStates: ->
    # screenRange = @editor.screenRangeForBufferRange(@violation.bufferRange)
    # console.log 'initing states ---->'
    # console.log @bufferMatch.range
    screenRange = @editor.screenRangeForBufferRange(@bufferMatch.range)

    @screenStartPosition = screenRange.start
    @screenEndPosition = screenRange.end

    # console.log @screenStartPosition
    # console.log @screenEndPosition

    @isValid = true

  trackEdit: ->
    # range = [[2, 5], [2, 10]]
    @marker = @editor.markBufferRange @bufferMatch.range, invalidate: 'inside'
    @decoration = @editor.decorateMarker @marker, type: 'highlight', class: 'mavensmate-health-check-item'
    # console.log decoration
    # console.log decoration.getId()

    # marker.on 'changed', (event) =>
    #   console.log 'marker changed!!!!'
    
    @toggleTooltipWithCursorPosition()
    # return null

    # :persistent -
    # Whether to include this marker when serializing the buffer. Defaults to true.
    #
    # :invalidate -
    # Determines the rules by which changes to the buffer *invalidate* the
    # marker. Defaults to 'overlap', but can be any of the following:
    # * 'never':
    #     The marker is never marked as invalid. This is a good choice for
    #     markers representing selections in an editor.
    # * 'surround':
    #     The marker is invalidated by changes that completely surround it.
    # * 'overlap':
    #     The marker is invalidated by changes that surround the start or
    #     end of the marker. This is the default.
    # * 'inside':
    #     The marker is invalidated by a change that touches the marked
    #     region in any way. This is the most fragile strategy.
    # options = { invalidate: 'inside', persistent: false }
    # @marker = @editor.markScreenRange(@getCurrentScreenRange(), options)

    # @editor.decorateMarker(@marker, { type: 'gutter', class: "lint-#{@violation.severity}" })

    thiz = @
    @marker.on 'changed', (event) =>
      console.log 'marker changed!!!'
      console.log event
      
      @screenStartPosition = event.newTailScreenPosition
      @screenEndPosition = event.newHeadScreenPosition
      @isValid = event.isValid

      if not @isValid
        thiz.destroy()

      # if @isValid
      #   if @isVisibleMarkerChange(event)
      #     # TODO: EditorView::pixelPositionForScreenPosition lies when a line above the marker was
      #     #   removed and it was invoked from this marker's "changed" event.
      #     setImmediate =>
      #       @showHighlight()
      #       @toggleTooltipWithCursorPosition()
      #   else
      #     # Defer repositioning views that are currently outside of visibile area of scroll view.
      #     # This is important to avoid UI freeze when so many markers are changed by a single
      #     # modification (e.g. inserting/deleting the first line in the file).

      #     # Hide the views for now, so that the repositioning-pending views won't be shown in the
      #     # visible area of the scroll view.
      #     @hide()

      #     # This should be held by each ViolationView instance. Otherwise it will be called only
      #     # once for all instance events.
      #     @scheduleDeferredShowHighlight ?= _.debounce(@showHighlight, 500)
      #     @scheduleDeferredShowHighlight()
      # else
      #   @hideHighlight()
      #   @violationTooltip?.hide()

  destroy: ->
    @bufferView.removeBufferItem(@bufferMatch.range)
    @unsubscribe()
    @detach()

  isVisibleMarkerChange: (event) ->
    editorFirstVisibleRow = @editorView.getFirstVisibleScreenRow()
    editorLastVisibleRow = @editorView.getLastVisibleScreenRow()
    [event.oldTailScreenPosition, event.newTailScreenPosition].some (position) ->
      editorFirstVisibleRow <= position.row <= editorLastVisibleRow

  # if the cursor moves outside this items boundaries, hide the tooltip
  trackCursor: ->
    @subscribe @editor.getCursor(), 'moved', (moveEvent) =>
      if moveEvent.newScreenPosition.row != @screenStartPosition.row
        @myTooltip?.hide()
        return
      if moveEvent.newScreenPosition.column < @screenStartPosition.column or moveEvent.newScreenPosition.column > @screenEndPosition.column
        @myTooltip?.hide()
        return

  showHighlight: ->
    @updateHighlight()
    @show()

  hideHighlight: ->
    @hide()

  updateHighlight: ->
    startPixelPosition = @editorView.pixelPositionForScreenPosition(@screenStartPosition)
    endPixelPosition = @editorView.pixelPositionForScreenPosition(@screenEndPosition)
    arrowSize = @editorView.charWidth / 2
    verticalOffset = @editorView.lineHeight + Math.floor(arrowSize / 4)

    @css
      'top': startPixelPosition.top
      'left': startPixelPosition.left
      'width': @editorView.charWidth - (@editorView.charWidth % 2) # Adjust toolbar tip center
      'height': verticalOffset

    @arrow.css
      'border-right-width': arrowSize
      'border-bottom-width': arrowSize
      'border-left-width': arrowSize

    borderThickness = 1
    borderOffset = arrowSize / 2
    @area.css
      'left': borderOffset # Avoid protruding left edge of the border from the arrow
      'width': endPixelPosition.left - startPixelPosition.left - borderOffset
      'height': verticalOffset
    if @screenEndPosition.column - @screenStartPosition.column > 1
      @area.addClass("violation-border")
    else
      @area.removeClass("violation-border")

  toggleTooltipWithCursorPosition: ->
    @violationTooltip ?= @createViolationTooltip()
    # @violationTooltip.show()
    # console.log @violationTooltip
    return null

    cursorPosition = @editor.getCursor().getScreenPosition()

    if cursorPosition.row is @screenStartPosition.row &&
       cursorPosition.column is @screenStartPosition.column
      # @tooltip conflicts with View's @tooltip function.
      @violationTooltip ?= @createViolationTooltip()
      @violationTooltip.show()
    else
      @violationTooltip?.hide()

  getCurrentBufferStartPosition: ->
    @editor.bufferPositionForScreenPosition(@screenStartPosition)

  getCurrentScreenRange: ->
    new Range(@screenStartPosition, @screenEndPosition)

  beforeRemove: ->
    @marker?.destroy()
    @violationTooltip?.destroy()

  createViolationTooltip: ->
    options =
      violation: @bufferMatch
      container: @bufferView
      selector: @find('.code-helper-item-area')
      editorView: @editorView

    @myTooltip = new ViolationTooltip(this, options)
