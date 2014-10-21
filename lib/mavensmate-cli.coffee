path    = require 'path'
{exec, spawn}  = require 'child_process'
daemon  = require 'daemon'
glob    = require 'glob'
Q       = require 'q'
tracker = require('./mavensmate-promise-tracker').tracker
emitter = require('./mavensmate-emitter').pubsub
util    = require './mavensmate-util'

class MavensMateCommandLineInterface

  #promiseTracker: null

  constructor: () ->
    @promiseTracker = tracker

  getCommand:(params) ->
    args = params.args or {}
    payload = params.payload
    promiseId = params.promiseId

    operation = if args.operation then args.operation else payload.command

    if not promiseId?
      promiseId = tracker.enqueuePromise(operation)

    # return unless atom.project.path? TODO: ensure mavensmate project

    cfg = atom.config.getSettings()['MavensMate-Atom']

    opts = [] # any command line options
    cmd = null # command to run

    if util.useMMPython()
      if cfg.mm_mm_py_location == 'mm/mm.py'
        mm_location = path.join(atom.packages.resolvePackagePath('MavensMate-Atom'),cfg.mm_mm_py_location)
      else
        mm_location = cfg.mm_mm_py_location
      cmd = cfg.mm_python_location
      opts.push mm_location
    else
      if util.isStandardMmConfiguration()
        mm_path = path.join(util.mmHome(),'mm','mm')
      else
        mm_path = util.mmHome()

      # mm_path = path.join "#{util.mmHome()}","mm"
      mm_path += ".exe" if util.isWindows()
      console.debug mm_path
      cmd = mm_path

    opts.push operation

    # ui operations
    if 'ui' of args && args['ui']
      opts.push '--ui'

      if operation in util.modalCommands()
        opts.push '-uid='+promiseId
      else
        opts.push '-uid='+args.pane.id

    # offline operations
    if 'offline' of args && args['offline']
      opts.push '--offline'

    opts.push '-c=ATOM'

    if payload?
      payload.settings = cfg
    else
      payload = { settings : cfg }

    # payload may include ajax_args from UI ajax requests
    if payload.ajax_args?
      for arg in payload.ajax_args
        opts.push arg

    stdin = JSON.stringify payload

    [cmd, opts, stdin, promiseId]

  # Run the specified mm command
  #
  # params =
  #   args:
  #     foo: 'bar'
  #     bat: 'boom'
  #   payload:
  #     something: reallycool
  #   promiseId: 'some promise id'
  #
  # Returns promise.
  run: (params) ->
    deferred = Q.defer()

    [cmd, opts, stdin, promiseId] = @getCommand(params)

    @executeAsync cmd, opts, stdin, deferred, promiseId

    # add to promise tracker, emit an event so the panel knows when to do its thing
    tracker.start promiseId, deferred.promise
    emitter.emit 'mavensmate:panel-notify-start', params, promiseId

    deferred.promise

  # Execute the command, resolve the promise
  executeAsync: (cmd, opts, stdin, deferred, promiseId) ->
    try
      console.log cmd
      console.log opts
      console.log stdin

      project = atom.project

      cwd = if atom.project? and project.path? then project.path else null
      options = { cwd : cwd }

      childMmProcess = spawn(cmd, opts, cwd: cwd)

      childMmProcess.stdin.write(stdin)
      childMmProcess.stdin.end()

      stdout = ''
      stderr = ''

      childMmProcess.stdout.on "data", (data) ->
        # data.setEncoding 'utf8' ?
        # console.log "spawnSTDOUT:", data
        stdout += data

      childMmProcess.stderr.on "data", (data) ->
        # console.log "spawnSTDERR:", data
        stderr += data

      childMmProcess.on "close", (code) ->
        # console.log "Child process closed"
        return

      childMmProcess.on "disconnect", (code) ->
        # console.log "Child process disconnected"
        return

      childMmProcess.on "exit", (code) ->
        console.debug "mm exiting..."
        console.debug "command args: #{opts}"
        console.debug "exit code: #{code}"
        console.debug "stderr: #{stderr}"
        console.debug "stdout: #{stdout}"

        mmOutput = if stdout == '' then stderr else stdout
        # return if jsonToParse == ''
        # console.debug 'mm output: '
        # console.debug mmOutput
        jsonOutput = JSON.parse mmOutput
        if promiseId?
          jsonOutput.promiseId = promiseId
          deferred.resolve jsonOutput
        else
          deferred.resolve jsonOutput
        return

    catch err
      console.error 'MavensMate: ',err
      deferred.reject new Error(err)

mm = new MavensMateCommandLineInterface()
exports.mm = mm
