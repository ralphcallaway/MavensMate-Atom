path = require 'path'
{$, $$$, ScrollView} = require 'atom'

module.exports =
  class MavensMateModalView extends ScrollView

    # Internal: Initialize mavensmate output view DOM contents.
    @content: ->
      @div class: 'mavensmate modal-wrapper', =>
        @div class: 'modal fade in', outlet: 'modal',  =>
          @div class: 'modal-dialog modal-lg', =>
            @div class: 'modal-content', =>
              @div class: 'modal-body', style: 'min-height:600px;padding:0px;', =>
                @div outlet: 'loading', class: 'modal-loading', style: 'width:100px;margin:0 auto;padding-top:100px;', outlet: 'loading', =>
                  @i class: 'fa fa-spinner fa-spin', style: 'font-size:110px;color:#ccc;'
                @iframe outlet: 'iframe', width: '100%', class: 'native-key-bindings', sandbox: 'allow-same-origin allow-top-navigation allow-forms allow-scripts', style: 'border:none;display:none;'

    constructor: (@promiseId, @filePath, @command) ->
      super
      modalId = 'modal-'+@promiseId
      @modal.attr 'id', modalId
      
      # when modal is shown resize iframe
      @modal.on 'shown.bs.modal', (e) ->
        $(e.target).find('iframe').attr 'height', $(e.target).find('div.modal-body').height()+'px'
        return

      # remove wrapper when modal is hidden
      @modal.on 'hidden.bs.modal', (e) ->
        $(e.target).parent().remove()
        return

      # add listeners...
      @addIframeCloseListener()
      @addIframeLoadListener()

      @iframe.attr 'src', @filePath
      @iframe.attr 'id', 'iframe-'+@promiseId

      # show modal
      @modal.modal()

      @iframe.focus()

    addIframeLoadListener: ->
      document.addEventListener 'mavensmateIframeLoaded', (evt) -> 
        # console.log 'iframe loaded!!!!'
        modalId = 'modal-'+evt.detail
        # console.log evt.detail
        $('#'+modalId).find('div.modal-loading').hide()
        $('#'+modalId).find('iframe').fadeIn()

    # hide modal when close button is clicked in iframe
    addIframeCloseListener: ->
      document.addEventListener 'mavensmateCloseIframe', (evt) -> 
        modalId = 'modal-'+evt.detail
        $('#'+modalId).modal('hide')

