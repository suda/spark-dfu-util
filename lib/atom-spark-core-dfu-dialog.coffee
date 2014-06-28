{View} = require 'atom'

module.exports =
class AtomSparkCoreDfuDialog extends View
  @content: ->
    @div class: 'atom-spark-core-dfu-dialog overlay from-top', =>
      @h1 'No cores found'
      @p =>
        @img src: 'atom://atom-spark-core/images/dfu.gif'
      @p 'Check if your core is connected via USB and it\'s in DFU mode (LED blinking yellow).'
      @div class: 'block', =>
        @button class: 'btn', 'Cancel', outlet: @cancelButton

  initialize: (serializeState) ->
    @cancelButton

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  attach: =>

  destroy: ->

  show: ->
    if !@hasParent()
      atom.workspaceView.append(this)
