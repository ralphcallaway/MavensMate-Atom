{$, $$, $$$, EditorView, View} = require 'atom'
fs    = require 'fs'
path  = require 'path'
{Subscriber,Emitter}                = require 'emissary'
MavensMateEventEmitter              = require('./mavensmate-emitter').pubsub
MavensMateLocalServer               = require './mavensmate-local-server'
MavensMateProjectListView           = require './mavensmate-project-list-view'
MavensMateErrorView                 = require './mavensmate-error-view'
MavensMateCheckpointHandler         = require './mavensmate-checkpoint-handler'
MavensMatePanelView                 = require('./mavensmate-panel-view').panel
MavensMateStatusBarView             = require './mavensmate-status-bar-view'
MavensMateAppView                   = require './mavensmate-app-view'
MavensMateModalView                 = require './mavensmate-modal-view'
MavensMateCommandLineInterface      = require('./mavensmate-cli').mm
tracker                             = require('./mavensmate-promise-tracker').tracker
util                                = require './mavensmate-util'
MavensMateEventHandler              = require('./mavensmate-event-handler').handler
emitter                             = require('./mavensmate-emitter').pubsub
MavensMateCodeAssistProviders       = require './mavensmate-code-assist-providers'
{exec}                              = require 'child_process'

window.jQuery = $
require '../scripts/bootstrap'

module.exports =

  class MavensMate
    Subscriber.includeInto this

    editorSubscription: null
    autocomplete: null
    providers: []

    panel: null #mavensmate status panel
    localHttpServer: null #express.js server that handles UI interaction
    mm: null

    constructor: ->
      console.log 'NEW MAVENSMATE!!!'
      # @editorView = atom.workspaceView.getActiveView()
      # if @editorView?
      #   {@editor, @gutter} = @editorView

      @init()

    # constructor: (editorView) ->
    #   console.log 'NEW MAVENSMATE!!!'

    #   @editor = editorView.editor
    #   @editorView = editorView

    #   # {@editor, @gutter} = editorView
    #   @handleBufferEvents editorView

    #   # atom.workspaceView.eachEditorView (editorView) =>
    #   #   @handleBufferEvents editorView

    #   @init()

    # Activates the package, starts the local server, instantiates the views, etc.
    #
    # Returns nothing.
    init: ->
      #@promiseTracker = new MavensMatePromiseTracker()

      # instantiate mm tool
      @mm = MavensMateCommandLineInterface

      # start the local express.js server, returns a promise, set the server port that was randomly selected
      @localHttpServer = new MavensMateLocalServer().start().then (result) =>
        atom.config.set('MavensMate-Atom.mm_server_port', result)

      # instantiate mavensmate panel, show it
      @panel = MavensMatePanelView
      @panel.toggle()

      # @subscribe atom.workspace.eachEditor (editor) =>
      #   @handleEvents(editor)

      atom.project.errors = {}
      atom.project.checkpointCount = 0
      if atom.project.path
        try
          data = fs.readFileSync atom.project.path + '/config/.overlays'
          overlays = JSON.parse data
          atom.project.checkpointCount = overlays.length
        catch error
          console.log error

      atom.workspaceView.eachEditorView (editorView) =>
        @handleBufferEvents editorView
        new MavensMateErrorView(editorView)
        new MavensMateCheckpointHandler(editorView, @mm, @mmResponseHandler)

      ##COMMANDS TODO: move

      # presents a list of projects in a select list
      atom.workspaceView.command "mavensmate:open-project", =>
        # instantiate a mavensmate project list view instance
        @selectList = new MavensMateProjectListView()
        @selectList.toggle()

      atom.workspaceView.command "mavensmate:toggle-output", =>
        @panel.toggle()        

      # deletes file(s) from server
      atom.workspaceView.command "mavensmate:delete-file-from-server", =>
        treeView = util.treeView()
        if treeView.hasFocus() # clicked in sidebar
          filePaths = treeView.selectedPaths()
        else # command palette or right click in editor
          filePaths = [util.activeFile()]
        params =
          args:
            operation: 'delete'
            pane: atom.workspace.getActivePane()
          payload:
            files: filePaths
        fileString = (filePaths.map (path) -> util.baseName(path)).join(', ')
        answer = atom.confirm
          message: "Are you sure you want to delete #{fileString} from Salesforce?"
          # NB: specs expects the following buton indices, 0: Cancel, 1: Delete
          #     so that we can simulate button clicks properly in the spec
          buttons: ["Cancel", "Delete"]
        if answer == 1 # 1 => Delete
          @mm.run(params).then (result) =>
            @mmResponseHandler(params, result)

      atom.workspaceView.command "mavensmate:compile", =>
        params =
          args:
            operation: 'compile'
            pane: atom.workspace.getActivePane()
          payload:
            files: [util.activeFile()]
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      # compiles entire project
      atom.workspaceView.command "mavensmate:compile-project", =>
        params =
          args:
            operation: 'compile_project'
            pane: atom.workspace.getActivePane()
        answer = atom.confirm
          message: 'Confirm Compile Project'
          detailedMessage: 'Would you like to compile the project?'
          buttons: ['Yes', 'No']
        if answer == 0 # Yes
          @mm.run(params).then (result) =>
            @mmResponseHandler(params, result)

      # cleans entire project
      atom.workspaceView.command "mavensmate:clean-project", =>
        params =
          args:
            operation: 'clean_project'
            pane: atom.workspace.getActivePane()
        answer = atom.confirm
          message: 'Confirm Clean Project'
          detailedMessage: 'Are you sure you want to clean this project? All local (non-server) files will be deleted and your project will be refreshed from the server.'
          buttons: ['Yes', 'No']
        if answer == 0 # Yes
          @mm.run(params).then (result) =>
            @mmResponseHandler(params, result)

      # reset metadata container
      atom.workspaceView.command "mavensmate:reset-metadata-container", =>
        params =
          args:
            operation: 'reset_metadata_container'
            pane: atom.workspace.getActivePane()
        answer = atom.confirm
          message: 'Reset Metadata Container'
          detailedMessage: 'Are you sure you want to reset the metadata container?'
          buttons: ['Yes', 'No']
        if answer == 0 # Yes
          @mm.run(params).then (result) =>
            @mmResponseHandler(params, result)

      # index metadata
      atom.workspaceView.command "mavensmate:index-metadata", (event)=>
        params =
          args:
            operation: 'index_metadata'
            pane: atom.workspace.getActivePane()
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      # refresh metadata
      atom.workspaceView.command "mavensmate:refresh-selected-metadata", (event)=>
        filesToRefresh = []
        fileNamesToRefresh = []
        atom.workspaceView.find('.selected .icon-file-text').each (index, element) =>
          filesToRefresh.push(util.filePathFromTreePath($(element).data('path')))

        if filesToRefresh.length > 0
          params =
            args:
              operation: 'refresh'
              pane: atom.workspace.getActivePane()
            payload:
              files: filesToRefresh
          answer = atom.confirm
            message: 'Refresh Selected Metadata'
            detailedMessage: "Are you sure you want to overwrite the selected files' contents from Salesforce?"
            buttons: ['Yes', 'No']
          if answer == 0 # Yes
            @mm.run(params).then (result) =>
              @mmResponseHandler(params, result)

      # runs all tests
      atom.workspaceView.command "mavensmate:run-all-tests-async", =>
        params =
          args:
            operation: 'run_all_tests'
            pane: atom.workspace.getActivePane()
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      # runs selected unit test
      atom.workspaceView.command "mavensmate:run-async-unit-tests", =>
        classArray = []
        currentFile = util.activeFile()

        if currentFile.indexOf '.cls' >= 0
          classArray.push currentFile.substring (currentFile.lastIndexOf('/')+1), currentFile.indexOf('.cls')

        params =
          args:
            operation: 'test_async'
            pane: atom.workspace.getActivePane()
          payload:
            classes: classArray
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      # UI commands

      atom.workspaceView.command "mavensmate:new-project", =>
        params =
          args:
            operation: 'new_project'
            ui: true
            #pane: atom.workspace.getActivePane().splitLeft()
            pane: atom.workspace.getActivePane()
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      atom.workspaceView.command "mavensmate:edit-project", =>
        params =
          args:
            operation: 'edit_project'
            ui: true
            pane: atom.workspace.getActivePane()
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      atom.workspaceView.command "mavensmate:upgrade-project", =>
        params =
          args:
            operation: 'upgrade_project'
            ui: true
            pane: atom.workspace.getActivePane()
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      atom.workspaceView.command "mavensmate:new-apex-class", =>
        params =
          args:
            operation: 'new_metadata'
            ui: true
            pane: atom.workspace.getActivePane()
          payload:
            metadata_type: 'ApexClass'
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      atom.workspaceView.command "mavensmate:new-apex-trigger", =>
        params =
          args:
            operation: 'new_metadata'
            ui: true
            pane: atom.workspace.getActivePane()
          payload:
            metadata_type: 'ApexTrigger'
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      atom.workspaceView.command "mavensmate:new-visualforce-page", =>
        params =
          args:
            operation: 'new_metadata'
            ui: true
            pane: atom.workspace.getActivePane()
          payload:
            metadata_type: 'Visualforce Page'
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      atom.workspaceView.command "mavensmate:new-visualforce-component", =>
        params =
          args:
            operation: 'new_metadata'
            ui: true
            pane: atom.workspace.getActivePane()
          payload:
            metadata_type: 'Visualforce Component'
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      atom.workspaceView.command "mavensmate:run-apex-unit-tests", =>
        params =
          args:
            operation: 'unit_test'
            ui: true
            pane: atom.workspace.getActivePane()
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      atom.workspaceView.command "mavensmate:deploy-to-server", =>
        params =
          args:
            operation: 'deploy'
            ui: true
            pane: atom.workspace.getActivePane()
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      atom.workspaceView.command "mavensmate:execute-apex", =>
        params =
          args:
            operation: 'execute_apex'
            ui: true
            pane: atom.workspace.getActivePane()
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      atom.workspaceView.command "mavensmate:new-project-from-existing-directory", =>
        params =
          args:
            operation: 'new_project_from_existing_directory'
            ui: true
            pane: atom.workspace.getActivePane()
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      atom.workspaceView.command "mavensmate:new-trace-flag", =>
        params =
          args:
            operation: 'debug_log'
            ui: true
            pane: atom.workspace.getActivePane()
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      atom.workspaceView.command "mavensmate:connect-to-github", =>
        params =
          args:
            operation: 'github'
            ui: true
            pane: atom.workspace.getActivePane()
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      atom.workspaceView.command "mavensmate:project-health-check", =>
        params =
          args:
            operation: 'project_health_check'
            ui: true
            pane: atom.workspace.getActivePane()
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      # New quick log
      atom.workspaceView.command "mavensmate:new-quick-log", =>
        params =
          args:
            operation: 'new_quick_trace_flag'
            pane: atom.workspace.getActivePane()
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      # fetch logs
      atom.workspaceView.command 'mavensmate:fetch-logs', =>
        params =
          args:
            operation: 'fetch_logs'
            pane: atom.workspace.getActivePane()
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      atom.workspaceView.command 'mavensmate:refresh-checkpoints', =>
          params =
            args:
              operation: 'index_apex_overlays'
              pane: atom.workspace.getActivePane()
          @mm.run(params).then (result) =>
            @mmResponseHandler params, result

      # places mavensmate 3 dot icon in the status bar
      createStatusEntry = =>
        @mavensmateStatusBar = new MavensMateStatusBarView(@panel)

      if atom.workspaceView.statusBar
        createStatusEntry()
      else
        atom.packages.once 'activated', ->
          createStatusEntry()

      if !util.isAutocompletePlusInstalled()
        @installAutocompletePlus()
      else 
        @enableAutocomplete()

    installAutocompletePlus: ->
      cmd = "#{atom.packages.getApmPath()} install autocomplete-plus"
      exec cmd, @enableAutocomplete 

    enableAutocomplete: ->
      atom.packages.activatePackage("autocomplete-plus")
        .then (pkg) =>
          @autocomplete = pkg.mainModule
          @registerProviders()

    registerProviders: ->
      @editorSubscription = atom.workspaceView.eachEditorView (editorView) =>
        if editorView.attached and not editorView.mini
          apexProvider = new MavensMateCodeAssistProviders.ApexProvider(editorView)
          @autocomplete.registerProviderForEditorView apexProvider, editorView
          @providers.push apexProvider

          apexContextProvider = new MavensMateCodeAssistProviders.ApexContextProvider(editorView)
          @autocomplete.registerProviderForEditorView apexContextProvider, editorView
          @providers.push apexContextProvider

          # sobjectProvider = new MavensMateCodeAssistProviders.SobjectProvider(editorView)
          # @autocomplete.registerProviderForEditorView sobjectProvider, editorView
          # @providers.push sobjectProvider

    # Public: Deactivate the package and destroy the mavensmate views.
    #
    # Returns nothing.
    deactivate: ->
      @mavensMateAppView.destroy()
      @mavensmateStatusBar?.destroy()
      @mavensmateStatusBar = null
      @localHttpServer.destroy()

    mmResponseHandler: (params, result) ->
      tracker.pop(result.promiseId).result
      if params.args.ui
        #params.args.pane.addItem new MavensMateAppView result.body, params.args.operation #attach app view pane
        modalView = new MavensMateModalView result.promiseId, result.body, params.args.operation #attach app view pane
        modalView.appendTo document.body
      MavensMateEventEmitter.emit 'mavensmatePromiseCompleted', result.promiseId
      MavensMateEventEmitter.emit 'mavensmatePanelNotifyFinish', params, result, result.promiseId

    handleBufferEvents: (editorView) ->
      buffer = editorView.editor.getBuffer()

      @subscribe buffer.on 'saved', =>
        params =
          args:
            operation: 'compile'
            pane: atom.workspace.getActivePane()
            editor: atom.workspace.getActiveEditor()
            editorView: atom.workspaceView.getActiveView()
            buffer: buffer
          payload:
            files: [buffer.file.path]
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)
