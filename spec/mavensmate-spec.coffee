MMInstaller   = require '../lib/mavensmate-installer'
MavensMate    = require '../lib/mavensmate'

describe "Mavens Mate Atom", ->
    
  describe "Automatic Updates", ->

    describe "Beta Users", ->

      it "should install the pre-release if automatic updates enabled", ->
        atom.config.set 'MavensMate-Atom.mm_auto_install_mm_updates', true
        atom.config.set 'MavensMate-Atom.mm_beta_user', true
        mmAtom = new MavensMate()
        expect(mmAtom.mmInstaller._targetVersion).toEqual(MMInstaller.V_PRE_RELEASE)
        
    describe "Non Beta User", ->

      it 'should install latest if automatic updates enabled', ->
        atom.config.set 'MavensMate-Atom.mm_auto_install_mm_updates', true
        atom.config.set 'MavensMate-Atom.mm_beta_user', false
        mmAtom = new MavensMate()
        expect(mmAtom.mmInstaller._targetVersion).toEqual(MMInstaller.V_LATEST)

    describe "Updates Disabled", ->

      it 'shoud not do anyting if automatic updates disabled', ->
        atom.config.set 'MavensMate-Atom.mm_auto_install_mm_updates', false
        mmAtom = new MavensMate()
        expect(mmAtom.mmInstaller).not.toBeDefined()