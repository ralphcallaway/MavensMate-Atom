{View, EditorView}  = require 'atom'
Crypto              = require 'crypto'
Firebase            = require 'firebase'
Firepad             = require '../../scripts/firepad-lib'
ShareStatusView     = require './share-status-view'
uuid                = require 'node-uuid'
util                = require '../mavensmate-util'

module.exports =
class MavensMateShareView extends View
  
  hash: null

  @activate: -> new MavensMateShareView

  @content: ->
    @div class: 'firepad overlay from-top mini', =>
      @subview 'miniEditor', new EditorView(mini: true)
      @div class: 'message', outlet: 'message'

  detaching: false

  initialize: ->
    atom.workspaceView.command 'mavensmate:share-session', => @share()
    atom.workspaceView.command 'mavensmate:unshare-session', => @unshare()

    @miniEditor.hiddenInput.on 'focusout', => @detach() unless @detaching
    @on 'core:confirm', => @confirm()
    @on 'core:cancel', => @detach()

    @miniEditor.preempt 'textInput', (e) =>
      false unless e.originalEvent.data.match(/[a-zA-Z0-9\-]/)

  detach: ->
    return unless @hasParent()
    @detaching = true
    @miniEditor.setText('')
    super
    @detaching = false

  # share: ->
  #   if editor = atom.workspace.getActiveEditor()
  #     atom.workspaceView.append(this)
  #     @message.text('Enter a string to identify this share session')
  #     @miniEditor.focus()

  share: ->
    # shareId = @miniEditor.getText()
    
    # @hash = Crypto.createHash('sha256').update(shareId).digest('base64');
    extension = util.extension(util.activeFile())
    @hash = uuid.v1()
    @hash = @hash+'-'+extension.replace('.','')
    console.log 'hash is -->'
    console.log @hash
    @detach()
    @ref = new Firebase('https://mavensmate.firebaseio.com').child(@hash) # todo: do we need to namespace this based on user's name/id?

    editor = atom.workspace.getActiveEditor()
    @ref.once 'value', (snapshot) =>
      console.log 'got Firebase ref -->'
      console.log snapshot
      options = {sv_: Firebase.ServerValue.TIMESTAMP}
      if !snapshot.val() && editor.getText() != ''
        options.overwrite = true
      else
        editor.setText ''
      @pad = Firepad.fromAtom @ref, editor, options

      @view = new ShareStatusView(@hash, @ref, editor, options)
      @view.show()

      # @userList = new ShareUserListView(@hash, @ref)
      # @userlist.show()

      pane = atom.workspaceView.getActivePane()
      pane.on 'pane:active-item-changed', (something) ->
        console.log 'changed active'
        console.log something
        return

  destroy: ->
    if @ref?
      @ref.remove()
    if @pad?
      @pad.dispose()
    @unsubscribe()
    @detach()

  unshare: ->
    @ref.remove()
    @pad.dispose()
    @view.detach()