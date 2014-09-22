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
commands                            = require './commands.json'
MMInstaller                         = require './mavensmate-installer'
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
      atom.workspaceView.mavensMateProjectInitialized ?= false
      console.log 'initing mavensmate.coffee'
      #@promiseTracker = new MavensMatePromiseTracker()

      # download latest version of release if needed
      @mm_installer = new MMInstaller()
      @mm_installer.install()

      # instantiate mm tool
      @mm = MavensMateCommandLineInterface

      @projectCommands = commands.projectCommands

      # start the local express.js server, returns a promise, set the server port that was randomly selected
      console.log 'initing express.js'
      @localHttpServer = new MavensMateLocalServer()
      @localHttpServer.start().then (result) =>
        atom.config.set('MavensMate-Atom.mm_server_port', result)

      # instantiate mavensmate panel, show it
      @panel = MavensMatePanelView    

      atom.workspaceView.command "mavensmate:new-project", =>
        params =
          args:
            operation: 'new_project'
            ui: true
            #pane: atom.workspace.getActivePane().splitLeft()
            pane: atom.workspace.getActivePane()
        @mm.run(params).then (result) =>
          @mmResponseHandler(params, result)

      # presents a list of projects in a select list
      atom.workspaceView.command "mavensmate:open-project", =>
        # instantiate a mavensmate project list view instance
        @selectList = new MavensMateProjectListView()
        @selectList.toggle()

      atom.project.on 'path-changed', => @onProjectPathChanged()

      @onProjectPathChanged()

    onProjectPathChanged: ->
      if util.isMavensMateProject() and not atom.workspaceView.mavensMateProjectInitialized
        atom.workspaceView.mavensMateProjectInitialized = true
        @initializeProject()
      else
        console.log('not a mavensmate project or already initialized')


    initializeProject: ->
      @panel.toggle()

      # @subscribe atom.workspace.eachEditor (editor) =>
      #   @handleEvents(editor)

      atom.project.errors = {}
      atom.project.checkpointCount = 0
      if atom.project.path
        try
          data = fs.readFileSync path.join(atom.project.path, 'config','.overlays')
          overlays = JSON.parse data
          atom.project.checkpointCount = overlays.length
        catch error
          console.log error

      ##COMMANDS TODO: move


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


      for commandName, command of @projectCommands
        resolvedName = 'mavensmate:' + commandName

        atom.workspaceView.command resolvedName, (options) =>          
          commandName = options.type.split(':').pop()
          command = @projectCommands[commandName]
          if command?
            params =
              args:
                operation: command.operation
                pane: atom.workspace.getActivePane()

            if 'ui' of command
              params.args.ui = command.ui

            payload = {}
            if 'payloadFiles' of command
              switch command['payloadFiles']
                when 'active'
                  payload.files = [util.activeFile()]
                when 'selected'
                  payload.files = util.getSelectedFiles()
            if 'payloadClasses' of command
              switch command['payloadClasses']
                when 'activeBaseName'
                  if util.activeFile().indexOf('.cls') >= 0
                    payload.classes = [util.activeFileBaseName().split('.')[0]]
            if 'payloadMetadata' of command
              payload.metadata_type = command.payloadMetadata
            console.log(payload)
            if Object.keys(payload).length != 0
              params.payload = payload
            console.log(params.payload)

            answer = 0
            if command.confirm?
              answer = atom.confirm
                message: command.confirm.message
                detailedMessage: command.confirm.message
                buttons: command.confirm.buttons
            if answer == 0 # Yes
              @mm.run(params).then (result) =>
                @mmResponseHandler(params, result)


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

      atom.workspaceView.eachEditorView (editorView) =>        
        @handleBufferEvents editorView
        editorView.errorView = new MavensMateErrorView(editorView)
        editorView.checkpointHandler = new MavensMateCheckpointHandler(editorView, @mm, @mmResponseHandler)

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
    destroy: ->
      if @localHttpServer?
        # console.log '========================> SHUTTING DOWN LOCAL SERVER'
        # console.log @localHttpServer
        @localHttpServer.destroy()
        delete @localHttpServer
    
      # remove MavensMate items from the status bar
      @mavensmateStatusBar?.destroy()
      @mavensmateStatusBar = null

      # remove the MavensMate panel
      @panel.destroy()
      @panel = null

      #unsubscribe from all listeners
      @unsubscribe()

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

      if buffer.file? and util.isMetadata(buffer.file.getBaseName())
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
