fs        = require 'fs'
path      = require 'path'

class MavensMateConfig
  
  @settings: null

  constructor: () ->
    @filePath = path.join(atom.getConfigDirPath(), 'mavensmate.json')
    if not fs.existsSync @filePath
      @_write(@_defaults())
    else
      @settings = @_parse()
      
  _parse: ->
    fileBody = fs.readFileSync @filePath
    JSON.parse fileBody

  _defaults: ->
    return {}

  # writes obj to mavensmate.json
  _write: (obj) ->
    fileBody = JSON.stringify(obj, undefined, 2)
    me = @
    fs.writeFileSync @filePath, fileBody  
    me.settings = obj

  set: (key, value) ->
    @settings[key] = value
    @_write(@settings)

  get: (key) ->
    @settings[key]

config = new MavensMateConfig()
exports.config = config