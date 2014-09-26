_       = require 'underscore-plus'
_.str   = require 'underscore.string'
fs      = require 'fs'
os      = require 'os'
path    = require 'path'
config  = require('./mavensmate-config').config

module.exports =

  class MMUtil

    # returns the active file path
    @activeFile: ->
      editor = atom.workspace.getActivePaneItem()
      file = editor?.buffer.file
      file?.path

    # returns base name for active file
    @activeFileBaseName: ->
      editor = atom.workspace.getActivePaneItem()
      file = editor?.buffer?.file
      file?.getBaseName()

    # returns base name for file path
    # e.g. /workspace/MyApexClass.cls -> MyApexClass.cls
    @baseName: (filePath) ->
      filePath.split(/[\\/]/).pop()

    # takes a url and attempts to return the base salesforce url
    @baseSalesforceUrl: (url) ->
      # e.g., https://na14.salesforce.com/services/Soap/u/30.0/00Dd0000000cRQK
      return _.str.strLeftBack(url, '/services/')

    @extension: (filePath) ->
      '.' + filePath.split(/[.]/).pop()

    # takes a file path and returns it as a string or object (synchronously)
    @fileBodyAsString: (path, parseAsJson = false) ->
      fileBody = fs.readFileSync path
      if parseAsJson
        return JSON.parse fileBody
      else
        return fileBody

    # returns the fully resolved file path given a path relative to the root of the project
    @filePathFromTreePath: (treePath) ->
      atom.project.resolve('./' + treePath)

    # returns the name of the command
    # useful because the command can reside in args or payload
    @getCommandName: (params) ->
      if params.args? and params.args.operation?
        params.args.operation
      else
        params.payload.command

    # get the currently installed mm version
    @getMMVersion: ->
      config.get 'mm_installed_version'

    # filters the selected items against metadata extensions
    @getSelectedFiles: ->
      selectedFilePaths = []
      apex_file_extensions = atom.config.getSettings()['MavensMate-Atom'].mm_apex_file_extensions
      treeView = this.treeView()
      if treeView.hasFocus() # clicked in sidebar
        filePaths = treeView.selectedPaths()
      else # command palette or right click in editor
        filePaths = [this.activeFile()]
      for filePath in filePaths
        if this.extension(filePath) in apex_file_extensions
          selectedFilePaths.push(filePath)
      return selectedFilePaths

    @openUrlInAtom: (params, split = 'right') ->
      params.split = split
      params.editorView = atom.workspace.getActiveEditor()
      params.buffer = params.editorView.getBuffer()
      atom.workspaceView.open('mavensmate://serverView', params)

    # returns true if autocomplete-plus is installed
    @isAutocompletePlusInstalled: ->
      atom.packages.getAvailablePackageNames().indexOf('autocomplete-plus') > -1

    # whether the given file is a trigger or apex class
    @isClassOrTrigger: (currentFile) ->
      return currentFile? and (currentFile.indexOf('.trigger') >= 0 or currentFile.indexOf('.cls') >= 0)

    # returns true if on linux
    @isLinux: ->
      @platform() == 'linux'

    # returns true if on mac
    @isMac: ->
      @platform() == 'osx'

    @isMavensMateProject: ->
      settingsPath = atom.project.path + '/config/.settings'
      oldSettingsPath = atom.project.path + '/config/settings.yaml'
      return fs.existsSync(settingsPath) or fs.existsSync(oldSettingsPath)

    @isMetadata: (filePath) ->    
      apex_file_extensions = atom.config.getSettings()['MavensMate-Atom'].mm_apex_file_extensions
      return this.extension(filePath) in apex_file_extensions

    # returns true if mm is installed
    @isMMInstalled: ->
      (@getMMVersion()?)

    # returns true if user is mac and is on 10.8 + system
    # see http://en.wikipedia.org/wiki/Darwin_%28operating_system%29#Release_history
    # for mapping of os.version() return values, i.e. 12.0 => OS X 10.8
    @isOSX108Plus: ->
      @isMac() and parseInt os.release() >= 12

    # whether the given command is a request for a ui
    @isUiCommand: (params) ->
      if params.args? and params.args.ui?
        params.args.ui
      else
        false

    # returns true if on windows
    @isWindows: ->
      @platform() == 'windows'

    # returns full path for mm core api
    @mmHome: ->
      if atom.config.get('MavensMate-Atom.mm_path') == 'default'
        path.join(@mmPackageHome(),'mm')
      else
        atom.config.get('MavensMate-Atom.mm_path')

    # returns full path for atom package home
    @mmPackageHome: ->
      atom.packages.resolvePackagePath('MavensMate-Atom')

    # ui commands that use a modal (others use an atom pane)
    @modalCommands: ->
      [
        'new_project',
        'edit_project',
        'upgrade_project',
        'unit_test',
        'deploy',
        'execute_apex',
        'new_project_from_existing_directory',
        'debug_log',
        'github',
        'project_health_check',
        'new_metadata'
      ]

    # ui commands that use a modal (others use an atom pane)
    @compileCommands: ->
      [
        'compile',
        'compile_project',
        'clean_project',
        'refresh'
      ]

    @numberOfCompileErrors: (fileName) ->
      numberOfErrors = 0;
      if fileName?
        numberOfErrors = atom.project.errors[fileName].length
      else
        for fileName, errors of atom.project.errors
          numberOfErrors += errors.length
      return numberOfErrors

    # returns the command message to be displayed in the panel
    @panelCommandMessage: (params, command, isUi=false) ->
      console.log params

      # todo: move objects to global?
      uiMessages =
        new_project : 'Opening new project panel'
        edit_project : 'Opening edit project panel'

      messages =
        new_project : 'Creating new project'
        compile_project: 'Compiling project'
        index_metadata: 'Indexing metadata'
        compile: ->
          if params.payload.files? and params.payload.files.length is 1
            'Compiling '+params.payload.files[0]
          else
            'Compiling selected metadata'
        delete: ->
          if params.payload.files? and params.payload.files.length is 1
            'Deleting ' + params.payload.files[0].split(/[\\/]/).pop() # extract base name
          else
            'Deleting selected metadata'
        refresh: ->
          if params.payload.files? and params.payload.files.length is 1
            'Refreshing ' + params.payload.files[0]
          else
            'Refreshing selected metadata'

      if isUi
        msg = uiMessages[command]
      else
        msg = messages[command]

      console.log 'msgggggg'
      console.log msg
      console.log Object.prototype.toString.call msg

      if msg?
        if Object.prototype.toString.call(msg) is '[object Function]'
          return msg() + '...'
        else
          return msg + '...'
      else
        return 'Running operation...'

    # list of commands that do not have status displayed in the panel
    @panelExemptCommands: ->
      [
        'get_indexed_metadata',
        'deploy',
        'get_active_session',
        'new_apex_overlay',
        'delete_apex_overlay',
        'index_apex_overlays',
        'new_metadata',
        'unit_test'
      ]

    # returns platform flag (windows|osx|linux[default])
    @platform: ->
      return 'windows' if process.platform == 'win32'
      return 'osx' if process.platform == 'darwin'
      return 'linux'

    # set the currently installed version mm version
    @setMMVersion: (version) ->
      config.set 'mm_installed_version', version

    # setting object to configure MavensMate for future SFDC updates
    @sfdcSettings:
      maxCheckpoints: 5

    # returns tree view
    @treeView: ->
      atom.workspaceView.find('.tree-view').view()

    @typeIsArray: (value) ->
      Array.isArray or (value) ->
        {}.toString.call(value) is "[object Array]"

    @withoutExtension: (filePath) ->
      filePath.split(/[.]/).shift()

    @uris:
      errorsView: 'mavensmate://errorsView'

    # returns true if user is in dev mode
    # and has a valid python setup
    @useMMPython: ->
      # RC-TODO: add checks to validate mm_python_path and mm_mm_py_location are good
      atom.config.get('MavensMate-Atom.mm_developer_mode') == true