fs      = require 'fs'
moment  = require 'moment'
path    = require 'path'
Q       = require 'q'
request = require 'request'
semver  = require 'semver'
tar     = require 'tar'
temp    = require 'temp'
util    = require './mavensmate-util'
semver  = require 'semver'
config  = require('./mavensmate-config').config
moment  = require 'moment'
{allowUnsafeEval, allowUnsafeNewFunction} = require 'loophole'
unzip = allowUnsafeNewFunction -> allowUnsafeEval -> require 'unzip'

module.exports = 

  class MMInstaller

    # version constants
    @V_LATEST: 'latest'
    @V_PRE_RELEASE: 'pre-release'

    # github releases url
    @_RELEASES_URL: 'https://api.github.com/repos/joeferraro/mm/releases'
    
    # install params
    _targetVersion: null
    _force: null

    _betaUser: false

    # promise
    _deferred: null

    # result:
    _result: {} 

    # @param
    # - opts: array of installer options
    # - opts.targetVersion: latest, pre-release, specific version (see @V_* constants)
    # - opts.force: overwrite current installation even if it matches target version
    # @returns
    # - promise: deferred promise
    # - result: when resolved to map of installation details
    # - result.opts: map of installation options (after defaulting)
    # - result.initialVersion: installed version prior to installer running
    # - result.finalVersion: version after running installer
    # - result.newVersionInstalled: boolean if installation was required (true if forced)
    constructor: (opts = {}) ->
      
      # set defaults
      if atom.config.get('MavensMate-Atom.mm_beta_user')
        opts.targetVersion ||= @constructor.V_PRE_RELEASE
      else
        opts.targetVersion ||= @constructor.V_LATEST
      opts.force ||= false

      @_targetVersion = opts.targetVersion
      @_force = opts.force
      console.debug "constructor launched, targetVersion: #{@_targetVersion}, force: #{@_force}"

      # initialize return
      @_result.initialVersion = util.getMMVersion() or null # todo: move to mavensmate.json
      @_result.opts = opts
      @_result.finalVersion = util.getMMVersion() or null
      @_result.newVersionInstalled = false
      
    # starts install process, returns promise
    install: () ->
      @_deferred = Q.defer()

      if not util.isStandardMmConfiguration()
        if fs.existsSync(util.mmHome())
          @_deferred.resolve true
        else
          @_errorHandler "Error: invalid custom mm configuration"
      else
        @_getReleases @constructor._RELEASES_URL, @_getReleasesHandler

      @_deferred.promise

    # continues installation after retrieving releases data from github
    # (RC) there are probably better ways to organize this, but still getting
    # a hang of async programming and coffeescript
    _getReleasesHandler: (error, releasesData) =>
      console.debug "github releases call returned, error: #{error}, relasesData.length: #{releasesData?.length}"

      # bail if we got an error
      if error
        @_errorHandler "Error getting releases data, error: #{error}"
        return
       
      releaseData = @_findRelease releasesData, @_targetVersion

      # bail if we couldn't find the desired release
      if releaseData == null        
        console.log "Full releasesData: #{JSON.stringify releasesData}" if releasesData
        @_errorHandler "Unable to retrieve #{@_targetVersion} release data"
        return

      # install if
      # - force install requested
      # - mm isn't installed yet
      # - version to install is newer than currently installed version
      @_versionToInstall = @_parseVersion releaseData.tag_name 
      console.debug 'version to install is: '
      console.debug @_versionToInstall
      console.debug 'current version is: '
      console.debug util.getMMVersion()
      if @_force or not util.isMMInstalled() or @_versionCompare(@_versionToInstall, util.getMMVersion()) == 1
        downloadURL = @_findDownloadURL releaseData, util.platform()
        
        # bail if we couldn't find the download url
        if downloadURL == null
          console.log "Full releaseData: #{JSON.stringify releaseData}"
          @_errorHandler "Unable to locate download url for #{util.platform()} platform"
          return

        # download it and continue in download handler
        @_download downloadURL, @_downloadHandler
      else
        @_successHandler false

    # continues on with install logic after completing download of asset
    _downloadHandler: (error, downloadPath) =>
      console.debug "download completed, error: #{error}, downloadPath: #{downloadPath}"

      # bail if there was an error downloading
      if error
        @_errorHandler "Unable to download mm asset. Error: #{error}"
        return

      # RC-TODO: figure out what happens if package upgrades, need to figure 
      # out whether this install folder works ...
      extractPath = util.mmHome()

      if util.extension(downloadPath) == '.tar.gz'
        fs.createReadStream(downloadPath)
          .pipe(tar.Extract({ path: @_extractPath }))
          .on "error", (error) =>
            @_extractHandler er, downloadPath
          .on "end", () =>
            @_extractHandler null, downloadPath

      # assuming if it's not a tar ball it's a zip
      else
        # zip = new AdmZip downloadPath
        # zip.extractAllTo extractPath, true # overwrite
        # @_extractHandler null, downloadPath
        thiz = @

        fs.createReadStream(downloadPath)
          .pipe(unzip.Extract({ path: extractPath }))
          .on "error", (error) =>
            thiz._extractHandler error, downloadPath
          .on "close", () =>
            thiz._extractHandler null, downloadPath

        # thiz = @
        # unzipper = new DecompressZip(downloadPath)
        # unzipper.on "error", (err) ->
        #   console.log "Caught an error"
        #   console.log err
        #   thiz._extractHandler err, downloadPath

        # unzipper.on "extract", (log) ->
        #   console.log "Finished extracting"
        #   thiz._extractHandler null, downloadPath

        # unzipper.extract
        #   path: extractPath
        #   filter: (file) ->
        #     file.type isnt "SymbolicLink"


    # clean up download, and report errors and success
    _extractHandler: (error, downloadPath) =>
      console.debug 'extract handler -->'
      console.log error
      console.log downloadPath

      # clean up download as long as we're not using the spec version
      if downloadPath and downloadPath.indexOf('spec') == -1
        fs.unlinkSync downloadPath 

      # bail if we have an error
      if error
        @_errorHandler "Error extracting mm. Error: #{error}"
        return

      # todo: need to handle the different ways users set mm_path
      # mark as executable on *nix
      p = path.join(util.mmHome(),'mm', 'mm')
      pathStat = fs.lstatSync(p)
      if pathStat.isFile()
        fs.chmodSync(p, '755') unless util.isWindows()

      # update current version and report success 
      util.setMMVersion @_versionToInstall
      @_successHandler true

    # resolves promise and any other success actions
    _successHandler: (newVersionInstalled) =>
      @_result.finalVersion = util.getMMVersion()
      @_result.newVersionInstalled = newVersionInstalled
      console.debug "Installation completed successfully. Result: #{JSON.stringify @_result}"
      @_deferred.resolve @_result

    # logs error to console and rejects the promise
    _errorHandler: (errorMessage) =>
      console.error errorMessage
      @_deferred.reject new Error(errorMessage)

    # downloads the target url then hands off to callback
    _download: (url, callback) =>
      # RC-TODO: change to use temp directory
      downloadPath = path.join temp.mkdirSync(), 'mm.zip'
      downloadStream = fs.createWriteStream downloadPath
      r = request(url).pipe(downloadStream)
      r.on 'error', (err) ->
        callback(err)
      r.on 'close', () ->
        callback(null, downloadPath)

    # get the latest release data from github and pass on to the callback
    _getReleases: (url, callback) ->
      cachedReleases = config.get('mm_releases')

      # if we have cached releases, check the last time we cached them
      # if the last time we cached releases is less than 60 minutes, use the cached releases
      # otherwise, go to the github server
      # we do this to prevent rate limiting from github
      if cachedReleases? and cachedReleases.date? and cachedReleases.releases?
        now = moment()
        cacheDate = moment(cachedReleases.date)
        minutesSinceCached = now.diff(cacheDate, 'minutes')
          
        console.debug 'minutes since last releases cache: '+minutesSinceCached

        if minutesSinceCached < 60
          callback null, cachedReleases.releases 
          return

      request { 
        url: url, 
        json: true,
        headers: {
          'User-Agent': 'request'
        }
      }, (err, resp, body) ->
        settingValue =
          date: moment()
          releases: body
        config.set('mm_releases', settingValue)
        callback err, body      

    # locates asset in release data for specified platform
    _findDownloadURL: (releaseData, platform) ->
      downloadURL = null
      for asset in releaseData.assets
        if asset.name.indexOf(util.platform()) > -1
          downloadURL = asset.browser_download_url
          break
      downloadURL

    # finds target release in releases data
    # release = V_LATEST -> return release data for latest version excluding pre-releases
    # release = V_PRE_RELEASE -> return release data for latest version including pre-releases
    # release = vX.Y.Z -> return release with vX.Y.Z
    _findRelease: (releasesData, targetRelease) ->
      targetData = null
      latestVersion = null
      # could probably do this a bit cleaner with a map/filter/sort combo
      for releaseData in releasesData
        version = @_parseVersion releaseData.tag_name
        # loop for the highest version for latest or pre-release
        if targetRelease == @constructor.V_LATEST or targetRelease == @constructor.V_PRE_RELEASE
          if targetRelease == @constructor.V_PRE_RELEASE or releaseData.prerelease == false
            if not targetData?
              latestVersion = version
              targetData = releaseData
            else
              if @_versionCompare(version, latestVersion) == 1
                latestVersion = version
                targetData = releaseData
        # try and find the specific version for named version
        else 
          targetVersion = @_parseVersion targetRelease
          if @_versionCompare(targetVersion, version) == 0
            targetData = releaseData
            break
      targetData 

    # returns 1 if left version is greater than right version, 0 if equal
    # -1 if the left version is less than the right version
    _versionCompare: (leftVersion, rightVersion) ->
      semver.compare(leftVersion, rightVersion)

    # parse a release version from the github data
    _parseVersion: (rawVersion) ->
      return semver.valid(rawVersion) 
