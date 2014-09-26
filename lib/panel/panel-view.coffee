{$, $$$, ScrollView, View} = require 'atom'
Convert = null
{Subscriber,Emitter} = require 'emissary'
emitter             = require('../mavensmate-emitter').pubsub
util                = require '../mavensmate-util'
moment              = require 'moment'
pluralize           = require 'pluralize'

MavensMatePanelViewItem = require './panel-view-item'


# The status panel that shows the result of command execution, etc.
class MavensMatePanelView extends View
  Subscriber.includeInto this

  fetchingLogs: false
  panelItems: []
  collapsed: true
  panelViewHeight: null

  constructor: () ->
    super

  resizeStarted: =>
    $(document).on('mousemove', @resizePanelHandler)
    $(document).on('mouseup', @resizeStopped)

  resizeStopped: =>
    $(document).off('mousemove', @resizePanelHandler)
    $(document).off('mouseup', @resizeStopped)

  resizePanelHandler: (evt) =>
    return @resizeStopped() unless evt.which is 1
    height = jQuery("body").height() - evt.pageY - 10
    @setPanelViewHeight(height, animate = false)
    @panelViewHeight = height
    atom.config.set('MavensMate-Atom.mm_panel_height', height)

  setPanelViewHeight: (height, animate = true, setPanelHeight = true) =>
    if animate
      jQuery(@).animate({height:height}, 'fast')  
    else
      @height(height)
    jQuery('.mavensmate-output .message').css('max-height',height-54+'px')

  handleEvents: ->
    @on 'mousedown', '.entry', (e) =>
      @onMouseDown(e)

    @on 'mousedown', '.mavensmate-panel-view-resize-handle', (e) => @resizeStarted(e)

  # Internal: Initialize mavensmate output view DOM contents.
  @content: ->
    @div tabIndex: -1, class: 'mavensmate mavensmate-output tool-panel panel-bottom native-key-bindings resize', =>
      @div class: 'mavensmate-panel-view-resize-handle', outlet: 'resizeHandle'
      @div class: 'panel-header', =>
        @div class: 'container-fluid', =>
          @div class: 'row', style: 'padding:10px 0px', =>
            @div class: 'col-md-6', =>
              @h3 'MavensMate Salesforce1 IDE for Atom.io', outlet: 'myHeader', class: 'clearfix', =>
            @div class: 'col-md-6', =>
              @span class: 'config', style: 'float:right', =>
                @button class: 'btn btn-sm btn-default btn-view-errors', outlet: 'btnViewErrors', =>
                  @i class: 'fa fa-bug', outlet: 'viewErrorsIcon'
                  @span '0 errors', outlet: 'viewErrorsLabel', style: 'display:inline-block;padding-left:5px;'
                @button class: 'btn btn-sm btn-default', outlet: 'btnClearPanel', style: 'margin-left:3px', =>
                  @i class: 'fa fa-ban', outlet: ''
                @button class: 'btn btn-sm btn-default btn-toggle-panel', outlet: 'btnTogglePanel', style: 'margin-left:3px', =>
                  @i class: 'fa fa-toggle-down', outlet: 'btnToggleIcon'
      @div class: 'block padded mavensmate-panel', =>
        @div class: 'message', outlet: 'myOutput'

  # Internal: Initialize the mavensmate output view and event handlers.
  initialize: ->
    me = @ # this

    @btnViewErrors.click ->
      atom.workspaceView.open(util.uris.errorsView)

    # toggle log fetcher
    @btnTogglePanel.click ->
      if me.collapsed
        me.expand()
      else
        me.collapse() 

    @btnClearPanel.click ->
      me.clear()

    # updates panel view font size(s) based on editor font-size updates (see mavensmate-atom-watcher.coffee)
    emitter.on 'mavensmate:font-size-changed', (newFontSize) ->
      jQuery('div.mavensmate pre.terminal').css('font-size', newFontSize)

    # event handler which creates a panelViewItem corresponding to the command promise requested
    emitter.on 'mavensmate:panel-notify-start', (params, promiseId) ->
      command = util.getCommandName params
      if command not in util.panelExemptCommands() and not params.skipPanel # some commands are not piped to the panel
        params.promiseId = promiseId
        me.update command, params
      if command in util.compileCommands()
        me.updateErrorsBtn()
      return

    # handler for finished operations
    # writes status to panel item
    # displays colored indicator based on outcome
    emitter.on 'mavensmate:panel-notify-finish', (params, result, promiseId) ->
      # we do a double check here to ensure we're not doing anything with panel exempt commands
      # todo: ensure exempt or skippanel commands are not handled here
      if params.args.operation? and params.args.operation not in util.panelExemptCommands() and not params.skipPanel # some commands are not piped to the panel
        console.log 'panel view picked up an event!'
        console.log params
        console.log result

        promisePanelViewItem = me.panelItems[promiseId]
        promisePanelViewItem.update me, params, result
        
        if promisePanelViewItem.command in util.compileCommands()
          emitter.emit 'mavensmate:compile-finished', params, promiseId

        console.log '~~~~~~~~~~~~~'
        console.log promisePanelViewItem
        # console.log 'running panels!'
        # console.log me.countPanels()
        # console.log result
        # todo: in order to hide panel when the command completes, we need a way of knowing whether
        #       the command was ultimately successful (collapse panel) or a failure (keep panel open)
        #       bc the responses do not always contain a success property, for example, this is current difficult to do
        console.log me
        closePanelOnSuccess = atom.config.get('MavensMate-Atom.mm_close_panel_on_successful_operation')
        if closePanelOnSuccess and promisePanelViewItem.closePanelOnFinish          
          closePanelDelay = atom.config.get('MavensMate-Atom.mm_close_panel_delay')
          setTimeout(
            -> me.collapseIfNoRunning(),
          closePanelDelay)

    emitter.on 'mavensmate:compile-finished', (params, promiseId) ->
      me.updateErrorsBtn()

    @handleEvents()
  
  collapseIfNoRunning: () ->
    if @countPanels() == 0
      @collapse()

  collapse: () ->
    if not @collapsed
      @setPanelViewHeight(40, true, false)
      @btnToggleIcon.removeClass 'fa-toggle-down'
      @btnToggleIcon.addClass 'fa-toggle-up'
      @collapsed = true

  expand: () ->
    @setPanelViewHeight(@panelViewHeight)  
    @btnToggleIcon.removeClass 'fa-toggle-up'
    @btnToggleIcon.addClass 'fa-toggle-down'
    @collapsed = false

  clear: () ->
    $('.panel-item').remove()
    @panelItems = []

  afterAttach: (onDom) ->
    # when attached to dom, set height based on user setting
    me = @
    atom.workspaceView.command 'mavensmate:toggle-panel', ->
      if me.collapsed
        me.expand()
      else
        me.collapse() 
    @panelViewHeight = atom.config.get('MavensMate-Atom.mm_panel_height')
    @expand()


  # Update the mavensmate output view contents.
  #
  # output - A string of the test runner results.
  #
  # Returns nothing.
  update: (command, params) ->
    if @collapsed
      @expand()

    panelItem = new MavensMatePanelViewItem(command, params) # initiate new panel item
    @panelItems[params.promiseId] = panelItem # add panel to dictionary
    @myOutput.prepend panelItem # add panel item to panel

  # Detach and destroy the mavensmate output view.
  #           clear the existing panel items.
  # Returns nothing.
  destroy: ->
    $('.panel-item').remove()
    @unsubscribe()
    @detach()

  # Counts the number of panels running an (optional) list of commands
  #
  countPanels: (commands = []) ->
    panelCount = 0
    console.log @panelItems
    console.log commands
    if commands.length == 0
      for promiseId, panelViewItem of @panelItems    
        if panelViewItem.running
          panelCount++
    else
      for promiseId, panelViewItem of @panelItems    
        if panelViewItem.command in commands and panelViewItem.running
          panelCount++
    return panelCount

  # Update the error button based off of the number
  #           of errors and if a compile is occurring
  # Returns nothing, but that shouldn't be held against it.
  updateErrorsBtn: ->
    console.log '-----> updateErrorsBtn'
    panelsCompiling = @countPanels(util.compileCommands())

    numberOfErrors = util.numberOfCompileErrors()
    console.log("We have #{numberOfErrors} errors")
    console.log("And #{panelsCompiling} panels compiling")
    @viewErrorsLabel.html(numberOfErrors + ' ' + pluralize('error', numberOfErrors))

    if panelsCompiling == 0
      @viewErrorsIcon.removeClass 'fa-spin'
      if numberOfErrors == 0
        @btnViewErrors.addClass 'btn-default'
        @btnViewErrors.removeClass 'btn-error'
        @btnViewErrors.removeClass 'btn-warning'
      else
        @btnViewErrors.removeClass 'btn-default'
        @btnViewErrors.addClass 'btn-error'
        @btnViewErrors.removeClass 'btn-warning'        
    else
      @viewErrorsIcon.addClass 'fa-spin'
      @btnViewErrors.removeClass 'btn-default'
      @btnViewErrors.removeClass 'btn-error'
      @btnViewErrors.addClass 'btn-warning'

  # Toggle the visibilty of the mavensmate output view.
  #
  # Returns nothing.
  toggle: ->
    if @hasParent()
      @detach()
    else
      atom.workspaceView.prependToBottom(this) unless @hasParent() #todo: attach to specific workspace view



panel = new MavensMatePanelView()
exports.panel = panel
