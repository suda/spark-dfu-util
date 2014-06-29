# Based on MakeRunnerView from https://github.com/fiveisprime/atom-make-runner

{View} = require 'atom'
$ = require('atom').$

module.exports =
class AtomSparkCoreLogView extends View
  lastHeader = null
  textBuffer = null
  lastMessageType = null

  @content: ->
      @div tabIndex: -1, class: 'atom-spark-core-log-view tool-panel panel-bottom', =>
        @ul outlet: 'canvas', class: 'list-tree'

  initialize: (serializeState) ->
    @textBuffer = $("<pre class=\"stderr\">")

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @detach()

  toggle: ->
    if @hasParent()
      @detach()
    else
      atom.workspaceView.prependToBottom(this)

  show: ->
    if not @hasParent()
      atom.workspaceView.prependToBottom(this)

  removeTerminalColors: (text) ->
    text.replace(/\[[0-9]+m/g, '')

  removeLastEmptyLogLine: ->
    lastPre = @canvas.find('li.list-item:last-child pre.output:last-child')
    if lastPre.text() == ''
      lastPre.remove()

  print: (line, stderr = false, append = false) ->
    # If we are scrolled all the way down we follow the output
    panel = @canvas.parent()
    at_bottom = (panel.scrollTop() + panel.innerHeight() + 10 > panel[0].scrollHeight)

    if stderr
      @printError line
    else
      @printOutput line, append

    if at_bottom
      panel.scrollTop(panel[0].scrollHeight)

  printOutput: (line, append = false) ->
    # Header
    if line.indexOf('[34m') != -1
      line = @removeTerminalColors line

      # Remove last newline from previous <pre>
      @removeLastEmptyLogLine()

      icon = 'file-code'
      if line.indexOf('Linker') != -1
        icon = 'link'
      else if line.indexOf('Flash Image') != -1
        icon = 'package'
      else if line.indexOf('Print Size') != -1
        icon = 'dashboard'
      else if line.indexOf('dfu-util') != -1
        icon = 'zap'

      lastHeader = icon

      @canvas.append $("<li class=\"list-item\">
                          <div class=\"list-item\">
                            <span class=\"icon icon-#{icon}\">#{line}</span>
                          </div>
                        </li")

    else
      line = @removeTerminalColors line

      if append
        @canvas.find('li.list-item:last-child pre.output:last').append line + "\n"
      else
        @canvas.find('li.list-item:last-child').append $("<pre class=\"output\">#{line}</pre>")

  printError: (line) ->
    # Search for file:line:col: references
    html_line = null
    self = @
    line.replace /^([^:]+):(\d+):(\d+):(.*)$/, (match, file, row, col, errormessage) =>
      if errormessage.indexOf(' warning:') == 0
        self.lastMessageType = 'warning'
      else if errormessage.indexOf(' error:') == 0
        self.lastMessageType = 'error'

      html_line = [
        $('<a>')
          .text "#{file}:#{row}:#{col}"
          .attr 'href', '#'
          .on 'click', (e) =>
            e.preventDefault()

            # load file, but check if it is already open in any of the panes
            loading = atom.workspaceView.open file, { searchAllPanes: true }
            loading.done (editor) =>
              editor.setCursorBufferPosition [row-1, col-1],
        $('<span>').text errormessage
      ]


    if html_line
      @textBuffer.append html_line[0]
      @textBuffer.append html_line[1]
    else
      @textBuffer.append line

    @textBuffer.append "\n"

    if line.indexOf('^') != -1
      if @lastMessageType
        @textBuffer.addClass 'text-' + @lastMessageType
      @canvas.find('li.list-item:last-child').append @textBuffer
      @textBuffer = $("<pre class=\"stderr\">")
      @lastMessageType = null

  clear: ->
    @canvas.empty()
