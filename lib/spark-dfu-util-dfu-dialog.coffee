{View} = require 'atom'

Subscriber = null

module.exports =
class SparkDfuUtilDfuDialog extends View
  @content: ->
    @div class: 'spark-dfu-util-dfu-dialog overlay from-top', =>
      @h1 'Waiting for core...'
      @p =>
        @img src: 'atom://spark-dfu-util/images/dfu.gif'
      @p 'Check if your core is connected via USB and it\'s in DFU mode (LED blinking yellow).'
      @div class: 'block', =>
        @button click: 'cancel', class: 'btn', 'Cancel'

  initialize: (serializeState) ->
    {Subscriber} = require 'emissary'
    @subscriber = new Subscriber()
    @subscriber.subscribeToCommand atom.workspaceView, 'core:cancel core:close', ({target}) =>
      @hide()

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  destroy: ->
    @detach()

  show: =>
    if !@hasParent()
      atom.workspaceView.append(this)

  hide: ->
    if @hasParent()
      @detach()

  cancel: (event, element) ->
    atom.workspaceView.trigger 'core:cancel'
