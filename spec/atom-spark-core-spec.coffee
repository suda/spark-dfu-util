{WorkspaceView} = require 'atom'
AtomSparkCore = require '../lib/atom-spark-core'

# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.

describe "AtomSparkCore", ->
  activationPromise = null

  beforeEach ->
    atom.workspaceView = new WorkspaceView
    activationPromise = atom.packages.activatePackage('atom-spark-core')

  describe "when the atom-spark-core:toggle event is triggered", ->
    it "attaches and then detaches the view", ->
      expect(atom.workspaceView.find('.atom-spark-core')).not.toExist()

      # This is an activation event, triggering it will cause the package to be
      # activated.
      atom.workspaceView.trigger 'atom-spark-core:toggle'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(atom.workspaceView.find('.atom-spark-core')).toExist()
        atom.workspaceView.trigger 'atom-spark-core:toggle'
        expect(atom.workspaceView.find('.atom-spark-core')).not.toExist()
