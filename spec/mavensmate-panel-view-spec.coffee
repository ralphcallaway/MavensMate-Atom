# helper packages for test
temp    = require 'temp' # npm install temp
path    = require 'path' # npm install path

# Automatically track and cleanup files at exit
temp.track();

{WorkspaceView} = require 'atom'
emitter = require('../lib/mavensmate-emitter').pubsub
{panel} = require '../lib/mavensmate-panel-view'
{mm}    = require('../lib/mavensmate-cli')

describe 'MavensMate Panel View', ->
  beforeEach ->
    atom.project.setPath(path.join(__dirname, 'fixtures', 'testProject'))
    # set up the workspace
    atom.workspaceView = new WorkspaceView()
    atom.workspace = atom.workspaceView.model

    # activate the mavensmate package
    waitsForPromise ->
      atom.packages.activatePackage 'MavensMate-Atom'

  it 'should be defined', ->
    expect(panel).toBeDefined()
    expect(panel).toBeDefined()
    expect(panel[0].outerText).toBe('MavensMate for Atom.io')
    expect(panel.myHeader).toBeDefined()
    expect(panel.myOutput).toBeDefined()



  describe 'Run All Tests (Async)', ->
    beforeEach ->
      # set up spy and ensure that calls are delegated
      spyOn(panel, 'getRunAsyncTestsCommandOutput').andCallThrough()
      spyOn(mm, 'run').andCallThrough()

    it 'should invoke mavensmate:run-all-tests-async', ->
      atom.workspaceView.trigger 'mavensmate:run-all-tests-async'
      expect(mm.run).toHaveBeenCalled()
      expect(mm.run.mostRecentCall.args[0].args.operation).toBe('run_all_tests')

    it 'should indicate when all tests passed', ->
      # create fake params object
      myParams =  {args: {operation: 'run_all_tests'}, promiseId: 'my-fake-promiseId'}
      successResponse = require('./fixtures/mavensmate-panel-view/test_success.json')

      # simulate the emitter firing due to a panel start then finish with a success response from tooling api
      emitter.emit 'mavensmatePanelNotifyStart', myParams, 'my-fake-promiseId'
      emitter.emit 'mavensmatePanelNotifyFinish', myParams, successResponse, 'my-fake-promiseId'

      # ensure that getRunAsyncTestsCommandOutput has been called with expected params
      expect(panel.getRunAsyncTestsCommandOutput).toHaveBeenCalled()
      expect(panel.getRunAsyncTestsCommandOutput).toHaveBeenCalledWith('run_all_tests', myParams, successResponse)

      # ensure the correct message was set
      expect(panel.myOutput.find('div#message-my-fake-promiseId').html()).toBe('Run all tests complete. 3 tests passed.')
      expect(panel.myOutput.find('div#stackTrace-my-fake-promiseId div pre').html()).toBe('')

    it 'should indicate when some tests have failed', ->
      # create fake params object
      myParams =  {args: {operation: 'run_all_tests'}, promiseId: 'my-fake-promiseId'}
      failureResponse = require('./fixtures/mavensmate-panel-view/test_failure.json')

      # simulate the emitter firing due to a panel start then finish with a success response from tooling api
      emitter.emit 'mavensmatePanelNotifyStart', myParams, 'my-fake-promiseId'
      emitter.emit 'mavensmatePanelNotifyFinish', myParams, failureResponse, 'my-fake-promiseId'

      # ensure that getRunAsyncTestsCommandOutput has been called with expected params
      expect(panel.getRunAsyncTestsCommandOutput).toHaveBeenCalled()
      expect(panel.getRunAsyncTestsCommandOutput).toHaveBeenCalledWith('run_all_tests', myParams, failureResponse)

      # ensure the correct message was set
      expect(panel.myOutput.find('div#message-my-fake-promiseId').html()).toBe('1 failed test method')
      expect(panel.myOutput.find('div#stackTrace-my-fake-promiseId div pre').html()).toBe('SGToolKit_Batch_SendMessage_Test.shouldFail:\nClass.SGToolKit_Batch_SendMessage_Test.shouldFail: line 135, column 1\n\n')

  # Delete the metadata in the active pane from the server
  describe 'Delete File from Server', ->
    filePath = ''
    filePaths = []

    beforeEach ->
      # set up the workspace with a fake apex class
      directory = temp.mkdirSync()
      atom.project.setPath(directory)
      filePath = path.join(directory, 'MyApexClass.cls')
      filePaths = [filePath, path.join(directory,'AnotherClass.cls')]
      spyOn(mm, 'run').andCallThrough()

      waitsForPromise ->
        atom.packages.activatePackage 'tree-view'

      waitsForPromise ->
        atom.workspace.open(filePath)

    describe 'confirmations', ->

      it 'should prompt the user', ->
        spyOn(atom, 'confirm')
        atom.workspaceView.trigger 'mavensmate:delete-file-from-server'
        expect(atom.confirm).toHaveBeenCalled()

      it 'should not invoke mavensmate:delete-file-from-server if cancelled', ->
        spyOn(atom, 'confirm').andReturn(0)
        atom.workspaceView.trigger 'mavensmate:delete-file-from-server'
        expect(mm.run).not.toHaveBeenCalled()

      it 'should invoke mavensmate:delete-file-from-server and send a delete call if confirmed', ->
        spyOn(atom, 'confirm').andReturn(1)
        atom.workspaceView.trigger 'mavensmate:delete-file-from-server'
        expect(mm.run).toHaveBeenCalled()
        expect(mm.run.mostRecentCall.args[0].args.operation).toBe('delete')

    describe 'file selections', ->

      it 'should delete the active file if the sidebar isn\'t focused', ->
        spyOn(atom, 'confirm').andReturn(1)
        atom.workspaceView.trigger 'mavensmate:delete-file-from-server'
        expect(mm.run.mostRecentCall.args[0].payload.files).toEqual([filePath])

      it 'should delete the selected files if the sidebar is focused', ->
        util = require '../lib/mavensmate-util'
        treeView = util.treeView()
        spyOn(treeView, 'hasFocus').andReturn(true)
        spyOn(treeView, 'selectedPaths').andReturn(filePaths)
        spyOn(atom, 'confirm').andReturn(1)
        atom.workspaceView.trigger 'mavensmate:delete-file-from-server'
        expect(mm.run.mostRecentCall.args[0].payload.files).toBe(filePaths)

    describe 'panel messaging', ->

      it 'should tell the user what file is being deleted and if it was successful', ->
        myParams =  {args: {operation: 'delete', }, promiseId: 'my-fake-promiseId', payload: {files: [filePath]}}
        successResponse = require './fixtures/mavensmate-panel-view/delete_success.json'
        emitter.emit 'mavensmatePanelNotifyStart', myParams, 'my-fake-promiseId'
        emitter.emit 'mavensmatePanelNotifyFinish', myParams, successResponse, 'my-fake-promiseId'
        console.log panel.myOutput.find('div#command-my-fake-promiseId div').html()
        expect(panel.myOutput.find('div#command-my-fake-promiseId div').html()).toBe('Deleting MyApexClass.cls...')
        expect(panel.myOutput.find('div#message-my-fake-promiseId').html()).toBe('Deleted MyApexClass.cls')
        expect(panel.myOutput.find('div#stackTrace-my-fake-promiseId div pre').html()).toBe('')

  # Run unit tests for current class
  describe 'Run Async Unit Tests For This Class', ->
    beforeEach ->
      # set up the workspace with a fake test class
      directory = temp.mkdirSync()
      atom.project.setPath(directory)
      filePath = path.join(directory, 'MyTest.cls')
      spyOn(panel, 'getRunAsyncTestsCommandOutput').andCallThrough()
      spyOn(mm, 'run').andCallThrough()

      waitsForPromise ->
        atom.workspace.open(filePath)

    it 'should invoke mavensmate:run-async-unit-tests', ->
      atom.workspaceView.trigger 'mavensmate:run-async-unit-tests'
      expect(mm.run).toHaveBeenCalled()
      expect(mm.run.mostRecentCall.args[0].args.operation).toBe('test_async')
      expect(mm.run.mostRecentCall.args[0].payload.classes[0]).toBe('MyTest')

    it 'should indicate when all tests passed', ->
      myParams = {args: {operation: 'test_async'}, promiseId: 'my-fake-promiseId'}
      successResponse = require('./fixtures/mavensmate-panel-view/test_success.json')

      # simulate the emitter firing due to a panel start then finish with a success response from tooling api
      emitter.emit 'mavensmatePanelNotifyStart', myParams, 'my-fake-promiseId'
      emitter.emit 'mavensmatePanelNotifyFinish', myParams, successResponse, 'my-fake-promiseId'

      # ensure that getRunAsyncTestsCommandOutput has been called with expected params
      expect(panel.getRunAsyncTestsCommandOutput).toHaveBeenCalled()
      expect(panel.getRunAsyncTestsCommandOutput).toHaveBeenCalledWith('test_async', myParams, successResponse)

      # ensure the correct message was set
      expect(panel.myOutput.find('div#message-my-fake-promiseId').html()).toBe('Run all tests complete. 3 tests passed.')
      expect(panel.myOutput.find('div#stackTrace-my-fake-promiseId div pre').html()).toBe('')

    it 'should indicate when some tests have failed', ->
      myParams = {args: {operation: 'test_async'}, promiseId: 'my-fake-promiseId'}
      failureResponse = require('./fixtures/mavensmate-panel-view/test_failure.json')

      # simulate the emitter firing due to a panel start then finish with a success response from tooling api
      emitter.emit 'mavensmatePanelNotifyStart', myParams, 'my-fake-promiseId'
      emitter.emit 'mavensmatePanelNotifyFinish', myParams, failureResponse, 'my-fake-promiseId'

      # ensure that getRunAsyncTestsCommandOutput has been called with expected params
      expect(panel.getRunAsyncTestsCommandOutput).toHaveBeenCalled()
      expect(panel.getRunAsyncTestsCommandOutput).toHaveBeenCalledWith('test_async', myParams, failureResponse)

      # ensure the correct message was set
      expect(panel.myOutput.find('div#message-my-fake-promiseId').html()).toBe('1 failed test method')
      expect(panel.myOutput.find('div#stackTrace-my-fake-promiseId div pre').html()).toBe('SGToolKit_Batch_SendMessage_Test.shouldFail:\nClass.SGToolKit_Batch_SendMessage_Test.shouldFail: line 135, column 1\n\n')

  # Fetch Logs
  describe 'Fetch Logs', ->
    it 'should indicate how many logs were fetched', ->
      myParams = {args: {operation: 'fetch_logs'}, promiseId: 'my-fake-promiseId'}
      response = require('./fixtures/mavensmate-panel-view/fetch_logs_4.json')

      # simulate the emitter firing due to a panel start then finish with a success response from tooling api
      emitter.emit 'mavensmatePanelNotifyStart', myParams, 'my-fake-promiseId'
      emitter.emit 'mavensmatePanelNotifyFinish', myParams, response, 'my-fake-promiseId'

      # ensure the correct message was set
      expect(panel.myOutput.find('div#message-my-fake-promiseId').html()).toBe('4 Logs successfully downloaded')
      expect(panel.myOutput.find('div#stackTrace-my-fake-promiseId div pre').html()).toBe('')

  describe 'Compile Project', ->
    beforeEach ->
      spyOn(panel, 'getCompileProjectCommandOutput').andCallThrough()
      spyOn(mm, 'run').andCallThrough()

    it 'should invoke mavensmate:compile-project', ->
      spyOn(atom, 'confirm').andReturn(1)
      atom.workspaceView.trigger 'mavensmate:compile-project'

      expect(atom.confirm).toHaveBeenCalled()

    it 'should indicate when it is done compiling', ->
      myParams = {args: {operation: 'compile_project'}, promiseId: 'my-fake-promiseId'}
      successResponse = require('./fixtures/mavensmate-panel-view/compile_project_success.json')

  # New Quick Log
  describe 'New Quick Log', ->
    it 'should indicate that new log was created', ->
      myParams = {args: {operation: 'new_quick_trace_flag'}, promiseId: 'my-fake-promiseId'}
      response = require('./fixtures/mavensmate-panel-view/new_quick_log.json')

      # simulate the emitter firing due to a panel start then finish with a success response from tooling api
      emitter.emit 'mavensmatePanelNotifyStart', myParams, 'my-fake-promiseId'
      emitter.emit 'mavensmatePanelNotifyFinish', myParams, response, 'my-fake-promiseId'

      # ensure the correct message was set
      expect(panel.myOutput.find('div#message-my-fake-promiseId').html()).toBe('1 Log(s) created successfully')
      expect(panel.myOutput.find('div#stackTrace-my-fake-promiseId div pre').html()).toBe('')
      expect(panel.myOutput.find('div.progress-bar').hasClass('progress-bar-success')).toBe(true)

    it 'should indicate when an error occurred creating new log', ->
      myParams = {args: {operation: 'new_quick_trace_flag'}, promiseId: 'my-fake-promiseId'}
      response = require('./fixtures/mavensmate-panel-view/new_quick_log_error.json')

      # simulate the emitter firing due to a panel start then finish with a success response from tooling api
      emitter.emit 'mavensmatePanelNotifyStart', myParams, 'my-fake-promiseId'
      emitter.emit 'mavensmatePanelNotifyFinish', myParams, response, 'my-fake-promiseId'

      # ensure the correct message was set
      expect(panel.myOutput.find('div#message-my-fake-promiseId').html()).toBe('Malformed request...')
      expect(panel.myOutput.find('div#stackTrace-my-fake-promiseId div pre').html()).not.toBe('')
      expect(panel.myOutput.find('div.progress-bar').hasClass('progress-bar-danger')).toBe(true)

  describe 'Reset Metadata Container', ->
    beforeEach ->
      spyOn(mm, 'run').andCallThrough()
      spyOn(atom, 'confirm').andReturn(0)

    it 'should invoke mavensmate:reset-metadata-container', ->
      atom.workspaceView.trigger 'mavensmate:reset-metadata-container'

      expect(mm.run).toHaveBeenCalled()
      expect(mm.run.mostRecentCall.args[0].args.operation).toBe('reset_metadata_container')


  describe 'Clean Project', ->
    beforeEach ->
      spyOn(mm, 'run').andCallThrough()
      spyOn(atom, 'confirm').andReturn(0)

    it 'should invoke mavensmate:clean-project', ->
      atom.workspaceView.trigger 'mavensmate:clean-project'

      expect(mm.run).toHaveBeenCalled()
      expect(mm.run.mostRecentCall.args[0].args.operation).toBe('clean_project')

  describe 'Compile Project', ->
    beforeEach ->
      spyOn(mm, 'run').andCallThrough()
      spyOn(atom, 'confirm').andReturn(0)

    it 'should invoke mavensmate:compile-project', ->
      atom.workspaceView.trigger 'mavensmate:compile-project'

      expect(mm.run).toHaveBeenCalled()
      expect(mm.run.mostRecentCall.args[0].args.operation).toBe('compile_project')

  describe 'Generic Operations', ->
    beforeEach ->
      spyOn(panel, 'getGenericOutput').andCallThrough()
      spyOn(mm, 'run').andCallThrough()

    it 'should indicate when it is done compiling', ->
      myParams = {args: {operation: 'generic_command'}, promiseId: 'my-fake-promiseId'}
      successResponse = require('./fixtures/mavensmate-panel-view/generic_success.json')

      # simulate the emitter firing due to a panel start then finish with a success response from tooling api
      emitter.emit 'mavensmatePanelNotifyStart', myParams, 'my-fake-promiseId'
      emitter.emit 'mavensmatePanelNotifyFinish', myParams, successResponse, 'my-fake-promiseId'

      # ensure the correct message was set
      expect(panel.getGenericOutput).toHaveBeenCalled()
      expect(panel.getGenericOutput).toHaveBeenCalledWith('generic_command', myParams, successResponse)

      # ensure the correct message was set
      expect(panel.myOutput.find('div#message-my-fake-promiseId').html()).toBe('Operation completed successfully')
      expect(panel.myOutput.find('div#stackTrace-my-fake-promiseId div pre').html()).toBe('')
