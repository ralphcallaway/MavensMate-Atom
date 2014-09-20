path  = require 'path' # npm install path

emitter = require('../lib/mavensmate-emitter').pubsub
MavensMateCheckpointHandler = require '../lib/mavensmate-checkpoint-handler'
{Editor, EditorView, WorkspaceView, $} = require 'atom'

describe 'MavensMate Checkpoint Handler', ->

  beforeEach ->
    atom.project.setPath(path.join(__dirname, 'fixtures', 'testProject'))
    # set up the workspace
    atom.workspaceView = new WorkspaceView
    atom.workspaceView.attachToDom()

    waitsForPromise ->
      atom.workspace.open('src/classes/MatchController.cls')

    waitsForPromise ->
      atom.packages.activatePackage('MavensMate-Atom')

  it 'should intialize with handlers', ->
    @editor = atom.workspace.getActiveEditor()
    spyOn(@editor.checkpointHandler, 'clearMarkers').andCallThrough()
    spyOn(@editor.checkpointHandler, 'refreshMarkers').andCallThrough()
    spyOn(@editor.checkpointHandler, 'refreshCheckpoints').andCallThrough()

    myParams =  {args: {operation: 'index_apex_overlays'}, promiseId: 'my-fake-promiseId', payload: {files: null}}
    emitter.emit 'mavensmatePanelNotifyStart', myParams, 'my-fake-promiseId'
    emitter.emit 'mavensmatePanelNotifyFinish', myParams, null

    myParams.args.operation = 'compile'
    emitter.emit 'mavensmatePanelNotifyStart', myParams, 'my-fake-promiseId'
    emitter.emit 'mavensmatePanelNotifyFinish', myParams, { result: null }

    expect(@editor.checkpointHandler.clearMarkers).toHaveBeenCalled()
    expect(@editor.checkpointHandler.refreshMarkers).toHaveBeenCalled()
    expect(@editor.checkpointHandler.refreshCheckpoints).toHaveBeenCalled()
    # clearMarkers will be called for each 'start' emitted as well as when refreshMarkers and refreshCheckpoints is called
    expect(@editor.checkpointHandler.clearMarkers.calls.length).toEqual(4)

  describe 'should detect gutter click events', ->
    beforeEach ->
      @editor = atom.workspace.getActiveEditor()
      @editorView = atom.workspaceView.getActiveView()

    describe 'when line not marked', ->
      it 'should mark with mm-checkpoint-gutter-processing', ->
        @editorView.find('.line-numbers .line-number-0').click()
        expect(@editorView.find('.line-numbers .line-number-0').hasClass('mm-checkpoint-gutter-processing')).toBe(true)
