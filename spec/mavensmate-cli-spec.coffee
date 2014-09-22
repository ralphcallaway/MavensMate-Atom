{mm}    = require('../lib/mavensmate-cli')

describe 'MavensMate Client', ->
  beforeEach ->

    #activate the mavesmate package
    waitsForPromise ->
      atom.packages.activatePackage 'MavensMate-Atom'

  # RC-TODO: add some new tests in here
  it "should eventually have a test suite", ->
    expect("but not yet").toBeDefined()