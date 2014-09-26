{$, View} = require 'atom'
typeChecker = require 'typechecker'

module.exports =

class PanelViewItemResponse extends View

  @content: (params) ->
    @div style: 'position:relative', =>
      @span outlet: 'message', id: params.id
      @button class: 'btn btn-sm btn-default', style: 'margin-left:9px;height:1.0em;', outlet: 'btnMore', =>
        @i class: 'fa fa-ellipsis-h'
      @div style: 'display:none', outlet: 'moreDiv', =>
        @span JSON.stringify(params.result, undefined, 2)

  initialize: (params) ->
    console.log 'what? params??'
    console.log params

    if typeChecker.isObject params.message
      @message.append params.message
    else
      @message.html '> '+params.message
    me = @
    @btnMore.click ->
      me.moreDiv.toggle()

     