{SelectListView} = require 'atom'
fs = require 'fs'

module.exports =
class MavensMateProjectListView extends SelectListView

  initialize: () ->
    super
    @addClass 'overlay from-top'
    @setItems(@getDirs())

  viewForItem: (item) ->
    "<li>#{item.name}<br/>#{item.path}</li>"

  # opens new atom window for selected project
  confirmed: (item) ->
    atom.open options =
      pathsToOpen: [item.path]

  # returns list of project directories based on workspace setting
  getDirs: ->
    dirs = []
    cfg = atom.config.getSettings()['MavensMate-Atom']
    workspaces = cfg.mm_workspace
    
    for workspace in workspaces
      if fs.existsSync workspace
        files = fs.readdirSync workspace
        for file in files
          # console.log file
          if file[0] != '.'
            filePath = "#{workspace}/#{file}"
            stat = fs.statSync filePath

            if stat.isDirectory()
                dirs.push { name : file, path: filePath }

    return dirs

  # when user types, list is filtered based on name property
  getFilterKey: ()->
    'name'

  # shows list view
  open: ->
    atom.workspaceView.append(this)
    @focusFilterEditor()

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @detach()

  isOpen: ->
    @hasParent()

  toggle: ->
    if @isOpen()
      @close()
    else
      @open()
