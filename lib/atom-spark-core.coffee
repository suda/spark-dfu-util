path = require 'path'
fs = require 'fs-plus'
cp = require 'child_process'
readline = require 'readline'
temp = require 'temp'
handlebars = require 'handlebars'

$ = require('atom').$
{allowUnsafeEval, allowUnsafeNewFunction} = require 'loophole'

AtomSparkCoreStatusBarView = require './atom-spark-core-status-bar-view'
AtomSparkCoreLogView = require './atom-spark-core-log-view'
AtomSparkCoreDfuDialog = require './atom-spark-core-dfu-dialog'

module.exports =
  atomSparkCoreStatusBarView: null
  atomSparkCoreLogView: null
  atomSparkCoreDfuDialog: null
  buildRunning: false
  flashRunning: false
  packagePath: null
  platform: null
  dfuDialogInterval: null
  tempDirPath: null

  activate: (state) ->
    if @isArduinoProject()
      @atomSparkCoreStatusBarView = new AtomSparkCoreStatusBarView()
      @atomSparkCoreLogView = new AtomSparkCoreLogView(state.atomSparkCoreLogViewState)
      @atomSparkCoreDfuDialog = new AtomSparkCoreDfuDialog()

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
      process.env.PATH += ':' + @packagePath + '/bin/' + @platform + '/gcc-arm-none-eabi/bin/' +
                          ':' + @packagePath + '/bin/' + @platform

      # @atomSparkCoreLogView.foo()

  deactivate: ->
    @atomSparkCoreStatusBarView = new AtomSparkCoreStatusBarView() unless @atomSparkCoreStatusBarView
    @atomSparkCoreStatusBarView.destroy()
    temp.cleanupSync();

  serialize: ->
    atomSparkCoreLogViewState: @atomSparkCoreLogView.serialize()

  #
  # Check if project contains a .ino file
  #
  isArduinoProject: ->
    inoFiles = fs.listSync(atom.project.getRootDirectory().getPath(), ['ino'])
    inoFiles.length > 0

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

          self.clearStatusBar()

  flash: ->
    @atomSparkCoreStatusBarView.setStatus 'Flashing...'
  #
  # Flash core using dfutil
  #
  prepareForFlash: ->
    # @build
    @atomSparkCoreStatusBarView.setStatus 'Waiting for core...'
    self = @
    dfuUtil = cp.exec 'dfu-util -l', (error, stdout, stderr) ->
      if stdout.indexOf('[1d50:607f]') > -1
        # Device found! Flash it
        self.flash()
      else
        # No device found
        self.atomSparkCoreDfuDialog.show()
        # Wait until device shows up
        self.dfuDialogInterval = setInterval ->
          dfuUtil = cp.exec 'dfu-util -l', (error, stdout, stderr) ->
            if stdout.indexOf('[1d50:607f]') > -1
              clearInterval self.dfuDialogInterval
              self.atomSparkCoreDfuDialog.hide()
              self.flash()
        , 500

  cancelFlash: ->
    clearInterval @dfuDialogInterval
    @atomSparkCoreStatusBarView.setStatus 'Flashing canceled'
    @clearStatusBar()
