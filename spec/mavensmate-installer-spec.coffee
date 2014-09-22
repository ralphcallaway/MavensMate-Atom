MMInstaller   = require '../lib/mavensmate-installer'
util          = require '../lib/mavensmate-util'
path          = require 'path'

# scroll to bottom for helper methods

describe 'MavensMate Installer', ->

  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage 'MavensMate-Atom'

  describe 'fresh pre-release install', ->
    it 'should install the latest pre-release version', ->
      util.setMMVersion null
      promise = runInstaller { targetVersion: MMInstaller.V_PRE_RELEASE }
      promise.then(
        (result) ->
          expect(result.finalVersion).toEqual(['0','2','4'])
          expect(result.initialVersion).toEqual(null)
          expect(result.newVersionInstalled).toBeTruthy()
          expect(util.isMMInstalled()).toBeTruthy()
          expect(util.getMMVersion()).toEqual(['0','2','4'])
        (error) ->
          expect(error).toBeUndefined()
      )

  describe 'fresh latest release install', ->
    it 'should install the latest non-pre-release version', ->
      util.setMMVersion null
      promise = runInstaller { targetVersion: MMInstaller.V_LATEST }
      promise.then(
        (result) ->
          expect(result.finalVersion).toEqual(['0','2','3'])
          expect(result.initialVersion).toEqual(null)
          expect(result.newVersionInstalled).toBeTruthy()
          expect(util.isMMInstalled()).toBeTruthy()
          expect(util.getMMVersion()).toEqual(['0','2','3'])
        (error) ->
          expect(error).toBeUndefined()
      )

  describe 'fresh existing named release install', ->

    it 'should pick the matching version', ->
      util.setMMVersion null
      promise = runInstaller { targetVersion: 'v0.2.0' }
      promise.then(
        (result) ->
          expect(result.finalVersion).toEqual(['0','2','0'])
          expect(result.initialVersion).toEqual(null)
          expect(result.newVersionInstalled).toBeTruthy()
          expect(util.isMMInstalled()).toBeTruthy()
          expect(util.getMMVersion()).toEqual(['0','2','0'])
        (error) ->
          expect(error).toBeUndefined()
      )

  describe 'fresh invalid named release install', ->

    it "should error", ->
      util.setMMVersion null
      promise = runInstaller { targetVersion: 'v0.1.99' }
      promise.then(
        (result) ->
          expect(result).toBeUndefined()
        (error) ->
          expect(error).toBeDefined()
          expect(util.isMMInstalled()).not.toBeTruthy()
          expect(util.getMMVersion()).toBeUndefined()
      )

  describe 'non-forced install', ->
    it "shouldn't do anything if the current version is the same", ->
      util.setMMVersion ['0','2','3']
      promise = runInstaller { targetVersion: MMInstaller.V_LATEST, force: false }
      promise.then(
        (result) ->
          expect(result.finalVersion).toEqual(['0','2','3'])
          expect(result.initialVersion).toEqual(['0','2','3'])
          expect(result.newVersionInstalled).not.toBeTruthy()
          expect(util.getMMVersion()).toEqual(['0','2','3'])
        (error) ->
          expect(error).toBeUndefined()
      )

    it "should install if the requested version is newer", ->
      util.setMMVersion ['0','2','3']
      promise = runInstaller { targetVersion: MMInstaller.V_PRE_RELEASE, force: false }
      promise.then(
        (result) ->
          expect(result.finalVersion).toEqual(['0','2','4'])
          expect(result.initialVersion).toEqual(['0','2','3'])
          expect(result.newVersionInstalled).toBeTruthy()
          expect(util.getMMVersion()).toEqual(['0','2','4'])
        (error) ->
          expect(error).toBeUndefined()
      )

    it "shouldn't do anything if the current version is newer", ->
      util.setMMVersion ['0','2','4']
      promise = runInstaller { targetVersion: MMInstaller.V_LATEST, force: false }
      promise.then(
        (result) ->
          expect(result.finalVersion).toEqual(['0','2','4'])
          expect(result.initialVersion).toEqual(['0','2','4'])
          expect(result.newVersionInstalled).not.toBeTruthy()
          expect(util.getMMVersion()).toEqual(['0','2','4'])
        (error) ->
          expect(error).toBeUndefined()
      )

  describe 'forced install', ->
    it "should install even if the current version is the same", ->
      util.setMMVersion ['0','2','3']
      promise = runInstaller { targetVersion: MMInstaller.V_LATEST, force: true }
      promise.then(
        (result) ->
          expect(result.finalVersion).toEqual(['0','2','3'])
          expect(result.initialVersion).toEqual(['0','2','3'])
          expect(result.newVersionInstalled).toBeTruthy()
          expect(util.getMMVersion()).toEqual(['0','2','3'])
        (error) ->
          expect(error).toBeUndefined()
      )

    it "should install even if the current version is newer", ->
      util.setMMVersion ['0','2','4']
      promise = runInstaller { targetVersion: MMInstaller.V_LATEST, force: true }
      promise.then(
        (result) ->
          expect(result.finalVersion).toEqual(['0','2','3'])
          expect(result.initialVersion).toEqual(['0','2','4'])
          expect(result.newVersionInstalled).toBeTruthy()
          expect(util.getMMVersion()).toEqual(['0','2','3'])
        (error) ->
          expect(error).toBeUndefined()
      )

# helper methods 

# instantiate installer with specified options
# opts.targetVersion: desired version to install
# opts.force: whether or not to force the install
runInstaller = (opts = {}) ->

  # copy down installer options
  installerOpts = {}
  installerOpts.targetVersion = opts.targetVersion if opts.targetVersion
  installerOpts.force = opts.force if opts.force

  # init installer
  installer = new MMInstaller(installerOpts)
  
  # spy on nextwork requests
  spyOn installer, '_getReleases'
  spyOn installer, '_download'
  
  # run installer
  promise = installer.install()

  # mock through github release data, if we got there
  if installer._getReleases.wasCalled
    releasesData = require './fixtures/mavensmate-installer/releases.json'
    installer._getReleases.mostRecentCall.args[1] null, releasesData

  # mock through download, if we got there
  if installer._download.wasCalled
    downloadPath = path.join util.mmPackageHome(), 
      'spec/fixtures/mavensmate-installer/mm-osx-v0.2.3.zip'
    installer._download.mostRecentCall.args[1] null, downloadPath  

  return promise