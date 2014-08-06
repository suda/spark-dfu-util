{allowUnsafeEval, allowUnsafeNewFunction} = require 'loophole'

fs = null
path = null
cp = null
readline = null
temp = null
handlebars = null

$ = null

AtomSparkCoreStatusBarView = null
AtomSparkCoreLogView = null
AtomSparkCoreDfuDialog = null

module.exports =
  atomSparkCoreStatusBarView: null
  atomSparkCoreLogView: null
  atomSparkCoreDfuDialog: null
  packagePath: null
  platform: null
  dfuDialogInterval: null
  tempDirPath: null
  buildRunning: false
  flashRunning: false
  buildAndFlash: false

  activate: (state) ->

    if @isArduinoProject()
      # Speeds up package loading
      path ?= require 'path'
      cp ?= require 'child_process'
      readline ?= require 'readline'
      temp ?= require 'temp'
      handlebars ?= require 'handlebars'

      $ ?= require('atom').$

      AtomSparkCoreStatusBarView ?= require './atom-spark-core-status-bar-view'
      AtomSparkCoreLogView ?= require './atom-spark-core-log-view'
      AtomSparkCoreDfuDialog ?= require './atom-spark-core-dfu-dialog'

      # Views initialization
      @atomSparkCoreStatusBarView = new AtomSparkCoreStatusBarView()
      @atomSparkCoreLogView = new AtomSparkCoreLogView(state.atomSparkCoreLogViewState)
      @atomSparkCoreDfuDialog = new AtomSparkCoreDfuDialog()

      # Hooking up commands
      atom.workspaceView.command 'atom-spark-core:build', '.editor', => @build()
      atom.workspaceView.command 'atom-spark-core:toggle', '.editor', => @toggle()
      atom.workspaceView.command 'atom-spark-core:flash', '.editor', => @prepareForFlash()
      atom.workspaceView.command 'atom-spark-core:cancel-flash', => @cancelFlash()

      # Create temp directory
      temp.track()
      self = @
      temp.mkdir 'atom-spark-core', (error, tempDirPath) ->
        console.log tempDirPath + ' created'
        self.tempDirPath = tempDirPath

      # Add gcc to path
      # TODO: Test platform
      @platform = 'darwin'
      @packagePath = path.resolve(__dirname, '..')
      process.env.PATH += ':' + @packagePath + '/platforms/' + @platform + '/gcc-arm-none-eabi/bin' +
                          ':' + @packagePath + '/platforms/' + @platform + '/bin'

      # @atomSparkCoreLogView.foo()

  deactivate: ->
    @atomSparkCoreStatusBarView?.destroy()
    @atomSparkCoreLogView?.destroy()
    @atomSparkCoreDfuDialog?.destroy()

    temp.cleanupSync()


  serialize: ->
    atomSparkCoreLogViewState: @atomSparkCoreLogView?.serialize()

  #
  # Check if project contains a .ino file
  #
  isArduinoProject: ->
    fs ?= require 'fs-plus'

    if atom.project.getRootDirectory() != null
      inoFiles = fs.listSync(atom.project.getRootDirectory().getPath(), ['ino'])
      inoFiles.length > 0
    else
      false

  #
  # Check for .ino file and alert if not found
  #
  testForArduinoProject: ->
    if @isArduinoProject()
      true
    else
      window.alert("This is not an Arduino compatibile project\n(It doesn't contain any *.ino files)\n")

  #
  # Remove paths from files array
  #
  stripPaths: (paths) ->
    (path.basename(item) for item in paths)

  #
  # Clear status after interval
  #
  clearStatusBar: ->
    setTimeout (=>
      # @atomSparkCoreStatusBarView.setStatus ''
      @atomSparkCoreStatusBarView.clear()
    ), 5000

  #
  # Show/hide the build log
  #
  toggle: ->
    @atomSparkCoreLogView.toggle()

  #
  # Create makefile and build code
  #
  build: ->
    if @buildRunning
      return

    if @testForArduinoProject()
      @atomSparkCoreStatusBarView.setStatus 'Building...'

      # Collect .c/.cpp/.ino/.S files
      projectPath = atom.project.getRootDirectory().getPath()
      data = {
        core_firmware_path: @packagePath + '/src/core-firmware',
        arduino_path: @packagePath + '/src/arduino',
        project_path: projectPath,
        c_files: @stripPaths(fs.listSync(projectPath, ['c'])),
        ino_files: @stripPaths(fs.listSync(projectPath, ['ino'])),
        cpp_files: @stripPaths(fs.listSync(projectPath, ['cpp'])),
        asm_files: @stripPaths(fs.listSync(projectPath, ['S']))
      }

      # Create makefile
      makefileSource = fs.readFileSync @packagePath + '/templates/makefile'

      self = @
      # Allow using new Function(...)
      allowUnsafeNewFunction ->
        makefileTemplate = handlebars.compile makefileSource.toString()
        makefile = makefileTemplate data
        fs.writeFileSync self.tempDirPath + '/makefile', makefile

        # Run build
        self.atomSparkCoreLogView.show()
        self.atomSparkCoreLogView.clear()
        self.buildRunning = true

        args = []
        make = cp.spawn 'make', args, {
          cwd: self.tempDirPath,
          env: process.env
        }

        # Use readline to generate line input from raw data
        stdout = readline.createInterface { input: make.stdout, terminal: false }
        stderr = readline.createInterface { input: make.stderr, terminal: false }

        stdout.on 'line',  (line) =>
          self.atomSparkCoreLogView.print line

        stderr.on 'line',  (line) =>
          self.atomSparkCoreLogView.print line, true

        make.on 'close',  (code) =>
          self.atomSparkCoreLogView.removeLastEmptyLogLine()

          if code is 0
            self.atomSparkCoreStatusBarView.setStatus 'Build succeeded'
          else
            self.atomSparkCoreStatusBarView.setStatus 'Build failed', 'error'

          self.buildRunning = false

          if (code is 0) && self.buildAndFlash
            self.buildAndFlash = false
            self.flash()
          else
            self.clearStatusBar()

  flash: ->
    if @flashRunning
      return

    @atomSparkCoreStatusBarView.setStatus 'Flashing...'
    @atomSparkCoreLogView.print '[34mInvoking dfu-util...[0m'
    @atomSparkCoreLogView.print 'dfu-util -d 1d50:607f -a 0 -s 0x08005000:leave -D core-firmware.bin'

    args = [
      '-d', '1d50:607f',
      '-a', '0',
      '-s', '0x08005000:leave',
      '-D', 'core-firmware.bin'
    ]
    dfuUtil = cp.spawn 'dfu-util', args, {
      cwd: @tempDirPath,
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
        self.atomSparkCoreStatusBarView.setProgress Math.round((progress / totalSize) * 100)
        self.atomSparkCoreStatusBarView.setStatus 'Uploading:'
        if progress == totalSize
          self.atomSparkCoreStatusBarView.hideProgress()

    stdout.on 'line',  (line) =>
      self.atomSparkCoreLogView.print line, false, true
      if line.indexOf('Downloading to address') != -1
        # Line with upload size
        result = line.match /size = (\d+)/
        totalSize = Math.ceil(parseInt(result[1]) / 1024)

    stderr.on 'line',  (line) =>
      self.atomSparkCoreLogView.print line, true

    dfuUtil.on 'close',  (code) =>
      if code == 0
        @atomSparkCoreStatusBarView.setStatus 'Flash succeeded'
      else
        @atomSparkCoreStatusBarView.setStatus 'Flash failed', 'error'

      self.flashRunning = false
      self.clearStatusBar()

  #
  # Flash core using dfu-util
  #
  prepareForFlash: ->
    if @testForArduinoProject()
      @atomSparkCoreStatusBarView.setStatus 'Waiting for core...'
      self = @
      dfuUtil = cp.exec 'dfu-util -l', (error, stdout, stderr) ->
        if stdout.indexOf('[1d50:607f]') > -1
          # Device found! Build project and flash it
          self.buildAndFlash = true
          self.build()
        else
          # No device found
          self.atomSparkCoreDfuDialog.show()
          # Wait until device shows up
          self.dfuDialogInterval = setInterval ->
            dfuUtil = cp.exec 'dfu-util -l', (error, stdout, stderr) ->
              if stdout.indexOf('[1d50:607f]') > -1
                clearInterval self.dfuDialogInterval
                self.atomSparkCoreDfuDialog.hide()
                self.buildAndFlash = true
                self.build()
          , 500

  cancelFlash: ->
    clearInterval @dfuDialogInterval
    @atomSparkCoreStatusBarView.setStatus 'Flashing canceled'
    @clearStatusBar()
