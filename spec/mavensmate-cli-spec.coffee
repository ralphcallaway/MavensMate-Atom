{mm}    = require('../lib/mavensmate-cli')

describe 'MavensMate Client', ->
  beforeEach ->

    #activate the mavesmate package
    waitsForPromise ->
      atom.packages.activatePackage 'MavensMate-Atom'

  it 'Uses the package path for default mm_location', ->
    # This assertion from "MavensMate Panel View" -> "should be defined" 
    #   expect(panel[0].outerText).toBe('MavensMate for Atom.io')
    # was failing with
    #   Expected 'MavensMate for Atom.ioCommandResultStack TraceRunning operation...some stuff in messages' 
    #   to be 'MavensMate for Atom.io'.
    # Seems like we need to alter the test so that it takes into account
    # there may be panel events emitted prior to it's test running, but for 
    # now, short circuiting the event emitter works
    emitter = require('../lib/mavensmate-emitter').pubsub
    spyOn(emitter, 'emit')

    # set config to default location
    default_location = 'mm/mm.py'
    atom.config.set('MavensMate-Atom.mm_location','mm/mm.py')
    spyOn(mm, 'execute')
    params = args: operation: 'fake'
    mm.run params

    # pull out mm location, first arg should be 
    # <python location> <mm location> ...
    mm_location = mm.execute.mostRecentCall.args[0].split(' ')[1]
    expect(mm_location).not.toEqual(default_location)