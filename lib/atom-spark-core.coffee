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

  activate: (state) ->
    if @isArduinoProject()
      @atomSparkCoreStatusBarView = new AtomSparkCoreStatusBarView()
      @atomSparkCoreLogView = new AtomSparkCoreLogView(state.atomSparkCoreLogViewState)
      @atomSparkCoreDfuDialog = new AtomSparkCoreDfuDialog()

      atom.workspaceView.command 'atom-spark-core:build', '.editor', => @build()
      atom.workspaceView.command 'atom-spark-core:toggle', '.editor', => @toggle()
      atom.workspaceView.command 'atom-spark-core:flash', '.editor', => @flash()

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
      self = @

      # Create temp directory
      temp.track()
      temp.mkdir 'atom-spark-core', (error, tempDirPath) ->
        console.log tempDirPath + ' created'

        # Collect .c/.cpp/.ino/.S files
        projectPath = atom.project.getRootDirectory().getPath()
        data = {
          core_firmware_path: self.packagePath + '/src/core-firmware',
          arduino_path: self.packagePath + '/src/arduino',
          project_path: projectPath,
          c_files: self.stripPaths(fs.listSync(projectPath, ['c'])),
          ino_files: self.stripPaths(fs.listSync(projectPath, ['ino'])),
          cpp_files: self.stripPaths(fs.listSync(projectPath, ['cpp'])),
          asm_files: self.stripPaths(fs.listSync(projectPath, ['S']))
        }

        # Create makefile
        makefileSource = fs.readFileSync self.packagePath + '/templates/makefile'

        # Allow using new Function(...)
        allowUnsafeNewFunction ->
          makefileTemplate = handlebars.compile makefileSource.toString()
          makefile = makefileTemplate data
          fs.writeFileSync tempDirPath + '/makefile', makefile

          # Run build

          self.atomSparkCoreLogView.show()
          self.atomSparkCoreLogView.clear()
          self.buildRunning = true

          args = []
          make = cp.spawn 'make', args, {
            cwd: tempDirPath,
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

            setTimeout (=>
              self.atomSparkCoreStatusBarView.setStatus ''
            ), 5000

  #
  # Flash core using dfutil
  #
  flash: ->
    self = @
    dfuUtil = cp.exec 'dfu-util -l', (error, stdout, stderr) ->
      if stdout.indexOf('[1d50:607f]') > -1
        # Device found! Flash it
        console.log 'Found!'
      else
        # No device found
        self.atomSparkCoreDfuDialog.show()
