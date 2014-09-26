{View} = require 'atom'
FirepadUserList = require '../../scripts/firepad-userlist'

module.exports =
class ShareStatusView extends View
  hash: null

  @content: ->
    @div class: 'mavensmate-share firepad overlay from-bottom native-key-bindings', =>
      @i class: 'fa fa-refresh fa-spin', style: 'margin-right: 7px'
      @span outlet: 'shareMessage', class: 'message'
      @button class: 'btn btn-success btn-sm', outlet: 'btnCopySessionId', =>
        @i class: 'fa fa-copy', style: 'margin-right:5px'
        @span 'Copy Session Identifier'
      @button class: 'btn btn-error btn-sm', outlet: 'btnStopSharing', =>
        @i class: 'fa fa-times', style: 'margin-right:5px'
        @span 'Stop Sharing'

  constructor: (hash, ref, editor, options) ->
    super
    console.log hash
    console.log ref
    console.log editor
    console.log options
    @hash = hash

    @shareMessage.html 'This file is being shared'

    thiz = @
    @btnCopySessionId.click ->
      atom.clipboard.write thiz.hash

    @btnStopSharing.click ->
      atom.workspaceView.trigger 'mavensmate:unshare-session'

    userList = FirepadUserList.fromDiv(ref.child('users'),
              document.body, 'userId', 'displayName');

  show: ->
    atom.workspaceView.getActivePane().activeView.append(this)