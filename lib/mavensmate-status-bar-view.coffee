{spawn}         = require 'child_process'
{View}          = require 'atom'
$               = require 'jquery'
emitter         = require('./mavensmate-emitter').pubsub
tracker         = require('./mavensmate-promise-tracker').tracker

module.exports =
  # Internal: A status bar view for the test status icon.
  class MavensMateStatusBarView extends View

    panel: null

    constructor: (panel) ->
      super
      @panel = panel

    # Internal: Initialize mavensmate status bar view DOM contents.
    @content: ->
      @div class: 'inline-block', =>
        @span class: 'icon', outlet: 'mavensMateIconWrapper', tabindex: -1, ''

    # Internal: Initialize the status bar view and event handlers.
    initialize: ->
      # add svg icon via markup explicitly so we can style it with css
      @mavensMateIconWrapper.append('<svg version="1.1" id="mavensmateSvgIcon" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" width="24px" height="24px" viewBox="0 0 24 24" enable-background="new 0 0 24 24" xml:space="preserve"> <g> <g> <g> <circle class="circle1" fill="#C3C3C2" cx="7.771" cy="6.747" r="4.12"/> </g> <circle class="circle2" fill="#C3C3C2" cx="7.771" cy="16.982" r="3.981"/> <circle class="circle3" fill="#C3C3C2" cx="16.292" cy="12.011" r="4.058"/> </g> </g> </svg> ')

      # attach to atom worksapce
      @attach()

      # event handlers
      me = @

      # when a promise is enqueued, set busy flag to true
      emitter.on 'mavensmate:promise-enqueued', ->
        me.setBusy true
        return

      # when a promise is completed, check the tracker to see whether there are pending promises
      # if there are not, set busy flag to false
      emitter.on 'mavensmate:promise-completed', ->
        # console.log 'mavensmate:promise-completed FROM STATUS BAR ====>'
        if Object.keys(tracker.tracked).length is 0
          me.setBusy false
        return

      # toggle panel view when icon is clickd
      @subscribe this, 'click', =>
        @panel.toggle()

    # Internal: Attach the status bar view to the status bar.
    #
    # Returns nothing.
    attach: ->
      atom.workspaceView.statusBar.appendLeft(this)

    # Internal: Detach and destroy the mavensmate status barview.
    #
    # Returns nothing.
    destroy: ->
      @detach()
      @unsubscribe()

    setBusy: (busy) ->
      if busy
        $('#mavensmateSvgIcon').attr('class', 'busy')
      else
        $('#mavensmateSvgIcon').attr('class', '')
