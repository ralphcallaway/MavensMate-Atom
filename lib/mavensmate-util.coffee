module.exports =

  # returns the active file path 
	activeFile: ->
    editor = atom.workspace.getActivePaneItem()
    file = editor?.buffer.file
    file?.path


  stripPath: (filePath) ->
    return filePath.replace(/^.*[\\\/]/, '')

  # returns base name for active file
  activeFileBaseName: ->
    editor = atom.workspace.getActivePaneItem()
    file = editor?.buffer.file
    file?.getBaseName()

  # returns base name for file path
  # e.g. /workspace/MyApexClass.cls -> MyApexClass.cls
  baseName: (filePath) ->
    filePath.split(/[\\/]/).pop()


  # whether the given command is a request for a ui
  isUiCommand: (params) ->
    if params.args? and params.args.ui?
      params.args.ui
    else
      false  

  # ui commands that use a modal (others use an atom pane)
  modalCommands: ->
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

  # list of commands that do not have status displayed in the panel
  panelExemptCommands: ->
    [
      'get_indexed_metadata',
      'deploy',
      'get_active_session'
    ]

  # returns the command message to be displayed in the panel
  panelCommandMessage: (params, command, isUi=false) ->
    console.log params

    # todo: move objects to global?
    uiMessages = 
      new_project : 'Opening new project panel'
      edit_project : 'Opening edit project panel'

    messages =
      new_project : 'Creating new project'
      compile_project: 'Compiling project'
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


  # returns the name of the command
  # useful because the command can reside in args or payload
  getCommandName: (params) ->
    if params.args? and params.args.operation?
      params.args.operation
    else
      params.payload.command