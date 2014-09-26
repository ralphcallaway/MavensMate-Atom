{View, EditorView}  = require 'atom'

module.exports =
class MavensMateJoinShareView extends View
  
  hash: null

  constructor: (@mm, @responseHandler) ->
    super

  @activate: -> new MavensMateJoinShareView

  @content: ->
    @div class: 'firepad overlay from-top mini', =>
      @subview 'miniEditor', new EditorView(mini: true)
      @div class: 'message', outlet: 'message'

  detaching: false

  initialize: ->
    atom.workspaceView.command 'mavensmate:join-session', => @share()

    @miniEditor.hiddenInput.on 'focusout', => @detach() unless @detaching
    @on 'core:confirm', => @confirm()
    @on 'core:cancel', => @detach()

    @miniEditor.preempt 'textInput', (e) =>
      false unless e.originalEvent.data.match(/[a-zA-Z0-9\-]/)

  share: ->
    if editor = atom.workspace.getActiveEditor()
      atom.workspaceView.append(this)
      @message.text('Enter a string to identify this share session')
      @miniEditor.focus()

  detach: ->
    return unless @hasParent()
    @detaching = true
    @miniEditor.setText('')
    super
    @detaching = false

  confirm: ->
    shareId = @miniEditor.getText()
    thiz = @
    params =
      args:
        operation: 'share'
        ui: true
        pane: atom.workspace.getActivePane()
        view: 'tab'
      payload:
        hash: shareId
    @mm.run(params).then (result) =>
      thiz.responseHandler(params, result)
    
  destroy: ->
    if @pad?
      @pad.dispose()
    @unsubscribe()
    @detach()

  unshare: ->
    @pad.dispose()
    @view.detach()