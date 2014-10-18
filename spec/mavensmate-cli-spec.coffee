{mm}    = require '../lib/mavensmate-cli'
util    = require '../lib/mavensmate-util'

xdescribe 'MavensMate Client', ->
  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage 'MavensMate-Atom'

  describe "executable choice", ->

    describe "with default mm path", ->

      it "should use the pre-installed mm.exe on windows", ->
        [cmd] = runExecutableTest 'windows', 'default'
        expect(cmd).toEqual("#{atom.packages.resolvePackagePath('MavensMate-Atom')}/mm/mm.exe")

      it "should use the pre-installed mm on non-windows", ->
        [cmd] = runExecutableTest 'linux', 'default'
        expect(cmd).toEqual("#{atom.packages.resolvePackagePath('MavensMate-Atom')}/mm/mm")

      xit "should complain if mm file doesn't exist at mm path", ->
        expect("incomplete test").not.toBeDefined()

      xit "should complain if mm isn't executable on non-windows", ->
        expect("incomplete test").not.toBeDefined()

    describe "with custom mm path", ->

      xit "should use mm.exe at mm path on windows", ->
        expect("incomplete test").not.toBeDefined()

      xit "should use mm at mm path on non-windows", ->
        expect("incomplete test").not.toBeDefined()

      xit "should complain if mm field doesn't exist mm path", ->
        expect("incomplete test").not.toBeDefined()

    describe "with developer mode", ->

      xit "should use the user defined python and mm.py path", ->
        expect("incomplete test").not.toBeDefined()

      xit "should complain if python doesn't exist", ->
        expect("incomplete test").not.toBeDefined()

      xit "should complain if python isn't executable", ->
        expect("incomplete test").not.toBeDefined()

      xit "should work with standard python if mm_py_path not defined", ->
        expect("incomplete test").not.toBeDefined()

      xit "should complain if mm_py_path not defined and python not on path", ->
        expect("incomplete test").not.toBeDefined()


runExecutableTest = (platform, mmPath) ->
  spyOn(util, 'platform').andReturn(platform)
  atom.config.set('MavensMate-Atom.mm_path', mmPath)