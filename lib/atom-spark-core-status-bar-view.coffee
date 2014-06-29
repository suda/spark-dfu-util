{View} = require 'atom'
$ = require('atom').$

module.exports =
class AtomSparkCoreStatusBarView extends View
  @content: ->
    @div class: 'inline-block atom-spark-core-status-bar-view', =>
      @a title: 'Spark Core', class: 'build-status', =>
        @img src: 'atom://atom-spark-core/images/spark.png', class: 'spark'
        @span ' '
      @progress class: 'inline-block', max: '100', value: '0', outlet: 'progress'

  initialize: (serializeState) ->
    @on 'click', => @toggleLog()

    if atom.workspaceView.statusBar
      @attach()
    else
      @subscribe atom.packages.once 'activated', @attach

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  attach: =>
    atom.workspaceView.statusBar.appendLeft(this)

  # Tear down any state and detach
  destroy: ->
    @remove()

  toggleLog: ->
      atom.workspaceView.trigger 'atom-spark-core:toggle'

  setStatus: (text, type = null) ->
      el = this.find('.build-status span')
      el.text(text)
        .removeClass()

      if type
        el.addClass('text-' + type)

  clear: ->
    el = this.find('.build-status span')
    self = @
    el.fadeOut ->
      self.setStatus ''
      el.show()

  setProgress: (progress) ->
    @progress.fadeIn()
    @progress.val(progress)

  hideProgress: ->
    @progress.fadeOut()
