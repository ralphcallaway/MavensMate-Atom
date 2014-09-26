Color = require 'color'
{$} = require 'atom'
AnnotationTooltip = require './annotation-tooltip'
open = require 'open'

module.exports =
class ViolationTooltip extends AnnotationTooltip
  @DEFAULTS = $.extend({}, AnnotationTooltip.DEFAULTS, {
    violation: null
    template: '<div class="tooltip">' +
                '<div class="tooltip-arrow"></div>' +
                '<div class="tooltip-inner">' +
                  '<div class="modal" style="display:block;position:relative;">' +
                    '<div class="modal-dialog" style="margin:0px;width:auto;">' +
                      '<div class="modal-content">' +
                        '<div class="modal-header" style="border:none;">' +
                          '<h4 class="modal-title">Modal title</h4>' +
                        '</div>' +
                        '<div class="modal-body" style="border:none;">' +
                          '<div class="message"></div>' +
                        '</div>' +
                        '<div class="modal-footer">' +
                          '<button type="button" class="btn btn-default" data-dismiss="modal">Close</button>' +
                          '<button type="button" class="btn btn-primary">More Information</button>' +
                        '</div>' +
                      '</div>' +
                    '</div>' +
                  '</div>' +
                '</div>' +
              '</div>'
  })

  # <ul class="nav nav-tabs" role="tablist">
  #   <li class="active"><a href="#home" role="tab" data-toggle="tab">Home</a></li>
  #   <li><a href="#profile" role="tab" data-toggle="tab">Profile</a></li>
  # </ul>

  init: (type, element, options) ->
    super(type, element, options)
    # console.log 'got some options!'
    # console.log options
    @violation = options.violation
    @metadata = options.violation.metadata

    # @configSubscription = Config.observe 'showViolationMetadata', (newValue) =>
    @switchMetadataDisplay()

  getDefaults: ->
    ViolationTooltip.DEFAULTS

  setContent: ->
    @setMessageContent()
    @setMetadataContent()
    @setAttachmentContent()
    @setHeaderContent()
    @tip().removeClass('fade in top bottom left right')

  setHeaderContent: ->
    @content().find('h4').html(@metadata.name || '')

  setMessageContent: ->
    @content().find('.message').html(@metadata.helpText || '')

  setMetadataContent: ->
    @content().find('button.btn-primary').unbind('click');
    thiz = @
    @content().find('button.btn-primary').click ->
      thiz.openUrl thiz.metadata.url
    
  openUrl: (url) ->
    open url

  setAttachmentContent: ->
    # $attachment = @content().find('.attachment')
    # # HTML = @violation.getAttachmentHTML()
    # HTML = '<div>foooo</div>'
    # if HTML?
    #   $attachment.html(HTML)
    # else
    #   $attachment.hide()
    return

  hasContent: ->
    @violation?

  applyAdditionalStyle: ->
    super()

    $code = @content().find('code, pre')

    if $code.length > 0
      frontColor = Color(@content().css('color'))
      $code.css('color', frontColor.clone().rgbaString())
      $code.css('background-color', frontColor.clone().clearer(0.96).rgbaString())
      $code.css('border-color', frontColor.clone().clearer(0.86).rgbaString())

    @switchMetadataDisplay()

  switchMetadataDisplay: ->
    # unless @metadataFitInLastLineOfMessage()
    #  @content().find('.metadata').addClass('block-metadata')

    # if @shouldShowMetadata()
    #   # It looks good when metadata fit in the last line of message:
    #   #                                                                          | Max width
    #   # | Prefer single-quoted strings when you don't need string interpolation  | Actual width
    #   # | or special symbols. [ Style/StringLiterals ]
    #   #                       ~~~ inline .metadata ~~~

    #   # However there's an ugly padding when metadata don't fit in the last line:
    #   #                                                                          | Max width
    #   # | Missing top-level module documentation comment.                        | Actual width
    #   # | [ Style/Documentation ]                         ~~~~~ugly padding~~~~~~
    #   #   ~~~ inline metadata ~~~

    #   # Clear the padding by making the metadata block element:
    #   #                                                                          | Max width
    #   # | Missing top-level module documentation comment. | Actual width
    #   # | [ Style/Documentation ]
    #   #   ~~~ block metadata ~~~~
    #   unless @metadataFitInLastLineOfMessage()
    #     @content().find('.metadata').addClass('block-metadata')
    # else
    #   @content().find('.metadata').hide()

  shouldShowMetadata: ->
    true

  metadataFitInLastLineOfMessage: ->
    # Make .metadata inline element to check if it fits in the last line of message
    $metadata = @content().find('.metadata')
    $metadata.css('display', 'inline')

    $message = @content().find('.message')
    messageBottom = $message.position().top + $message.height()

    $metadata = @content().find('.metadata')
    metadataBottom = $metadata.position().top + $metadata.height()

    $metadata.css('display', '')

    messageBottom == metadataBottom

  content: ->
    @contentElement ?= @tip().find('.tooltip-inner')

  destroy: ->
    super()
