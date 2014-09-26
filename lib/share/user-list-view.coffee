{View} = require 'atom'
Firepad = require '../../scripts/firepad-lib'
FirepadUserList = require '../../scripts/firepad-userlist'

module.exports =
class ShareUserListView extends View

  ref: null
  hash: null

  @content: ->
    @div class: 'mavensmate-share-user-list overlay native-key-bindings', =>
      @i class: 'fa fa-share-alt-square', style: 'padding-right: 7px'
      @span outlet: 'shareMessage', class: 'message'
      @input outlet: 'shareUrl', style: 'width:65%'
      # @div id: 'userlist'

  constructor: (hash, ref) ->
    super
    @ref = ref
    @hash = hash
    
  show: ->
    userList = FirepadUserList.fromDiv(@ref.child('users'), document.body, 'userId', 'displayName');
    atom.workspaceView.getActivePane().activeView.append(this)

  hide: ->
    console.log 'need to hide!'