fs = null
path = null
cp = null
readline = null

$ = null

SparkDfuUtilStatusBarView = null
SparkDfuUtilLogView = null
SparkDfuUtilDfuDialog = null

module.exports =
  sparkDfuUtilStatusBarView: null
  sparkDfuUtilLogView: null
  sparkDfuUtilDfuDialog: null
  packagePath: null
  platform: null
  dfuDialogInterval: null
  tempDirPath: null
  buildRunning: false
  flashRunning: false
  buildAndFlash: false

  activate: (state) ->
    # Speeds up package loading
    path ?= require 'path'
    cp ?= require 'child_process'
    readline ?= require 'readline'
    fs ?= require 'fs-plus'
    $ ?= require('atom').$

    SparkDfuUtilStatusBarView ?= require './spark-dfu-util-status-bar-view'
    SparkDfuUtilLogView ?= require './spark-dfu-util-log-view'
    SparkDfuUtilDfuDialog ?= require './spark-dfu-util-dfu-dialog'

    # Views initialization
    @sparkDfuUtilStatusBarView = new SparkDfuUtilStatusBarView()
    @sparkDfuUtilLogView = new SparkDfuUtilLogView(state.sparkDfuUtilLogViewState)
    @sparkDfuUtilDfuDialog = new SparkDfuUtilDfuDialog()

    # Hooking up commands
    atom.workspaceView.command 'spark-dfu-util:toggle', =>
      @toggle()
    atom.workspaceView.command 'spark-dfu-util:flash', =>
      @prepareForFlash()
    atom.workspaceView.command 'core:cancel', =>
      @cancelFlash()

    # Add dfu-util to path
    # TODO: Test platform
    @platform = 'darwin'
    @packagePath = path.resolve(__dirname, '..')
    process.env.PATH += ':' + @packagePath + '/platforms/' + @platform + '/bin'


  deactivate: ->
    @sparkDfuUtilStatusBarView?.destroy()
    @sparkDfuUtilLogView?.destroy()
    @sparkDfuUtilDfuDialog?.destroy()

  serialize: ->
    sparkDfuUtilLogViewState: @sparkDfuUtilLogView?.serialize()

  configDefaults:
    # Delete .bin file after flash
    deleteFirmwareAfterFlash: true

  #
  # Remove paths from files array
  #
  stripPaths: (paths) ->
    (path.basename(item) for item in paths)

  #
  # Clear status after interval
  #
  clearStatusBar: ->
    setTimeout =>
      @sparkDfuUtilStatusBarView.clear()
    , 5000

  #
  # Show/hide the build log
  #
  toggle: ->
    @sparkDfuUtilLogView.toggle()

  flash: ->
    if @flashRunning
      console.debug 'Flash was running. Canceling...'
      return

    rootPath = atom.project.getPath()
    files = fs.listSync(rootPath)
    files = files.filter (file) ->
      return file.split('.').pop().toLowerCase() == 'bin'
    files.reverse()

    if files.length == 0
      @sparkDfuUtilStatusBarView.setStatus 'No firmware found', 'error'
      return

    file = files.pop()

    @sparkDfuUtilStatusBarView.setStatus 'Flashing...'
    @sparkDfuUtilLogView.print '[34mInvoking dfu-util...[0m'
    @sparkDfuUtilLogView.print 'dfu-util -d 1d50:607f -a 0 -s 0x08005000:leave -D ' + file

    args = [
      '-d', '1d50:607f',
      '-a', '0',
      '-s', '0x08005000:leave',
      '-D', file
    ]
    dfuUtil = cp.spawn 'dfu-util', args, {
      env: process.env
    }
    @flashRunning = true

    self = @
    progress = 1
    totalSize = 0
    # Use readline to generate line input from raw data
    stdout = readline.createInterface { input: dfuUtil.stdout, terminal: false }
    stderr = readline.createInterface { input: dfuUtil.stderr, terminal: false }

    dfuUtil.stdout.on 'data',  (data) =>
      if (data.length == 1) && (data[0] == 46)
        # This is a dot symbolising 1kb of upload. Update progress bar
        progress++
        self.sparkDfuUtilStatusBarView.setProgress Math.round((progress / totalSize) * 100)
        self.sparkDfuUtilStatusBarView.setStatus 'Uploading:'
        if progress == totalSize
          self.sparkDfuUtilStatusBarView.hideProgress()

    stdout.on 'line',  (line) =>
      self.sparkDfuUtilLogView.print line, false, true
      if line.indexOf('Downloading to address') != -1
        # Line with upload size
        result = line.match /size = (\d+)/
        totalSize = Math.ceil(parseInt(result[1]) / 1024)

    stderr.on 'line',  (line) =>
      self.sparkDfuUtilLogView.print line, true

    dfuUtil.on 'close',  (code) =>
      if code == 0
        @sparkDfuUtilStatusBarView.setStatus 'Flash succeeded'

        if atom.config.get 'spark-dfu-util.deleteFirmwareAfterFlash'
          fs.unlink file
      else
        @sparkDfuUtilStatusBarView.setStatus 'Flash failed', 'error'

      self.flashRunning = false
      self.clearStatusBar()

  #
  # Flash core using dfu-util
  #
  prepareForFlash: ->
    @sparkDfuUtilStatusBarView.setStatus 'Waiting for core...'
    self = @
    dfuUtil = cp.exec 'dfu-util -l', (error, stdout, stderr) ->
      if stdout.indexOf('[1d50:607f]') > -1
        # Device found! Flash it!
        self.flash()
      else
        # No device found
        self.sparkDfuUtilDfuDialog.show()
        # Wait until device shows up
        self.dfuDialogInterval = setInterval ->
          dfuUtil = cp.exec 'dfu-util -l', (error, stdout, stderr) ->
            if stdout.indexOf('[1d50:607f]') > -1
              clearInterval self.dfuDialogInterval
              self.sparkDfuUtilDfuDialog.hide()
              self.flash()
        , 500

  cancelFlash: ->
    clearInterval @dfuDialogInterval
    @sparkDfuUtilStatusBarView.setStatus 'Flashing canceled'
    @clearStatusBar()
