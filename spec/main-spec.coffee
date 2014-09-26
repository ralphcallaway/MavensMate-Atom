describe 'Main Loader', ->

  describe 'settings before activation', ->
    it "aren't defined", ->
      expect(atom.config.getSettings()['MavensMate-Atom']).toBeUndefined()

  describe 'settings after activation', ->

    beforeEach ->
      waitsForPromise ->
        atom.packages.activatePackage 'MavensMate-Atom'

    it 'are defined', ->
      expect(atom.config.getSettings()['MavensMate-Atom']).toBeDefined()
      config = atom.config.getSettings()['MavensMate-Atom']
      expect(config.mm_compile_on_save).toBeDefined()
      expect(config.mm_api_version).toBeDefined()
      expect(config.mm_log_location).toBeDefined()
      expect(config.mm_workspace).toBeDefined()
      expect(config.mm_open_project_on_create).toBeDefined()
      expect(config.mm_log_level).toBeDefined()
      expect(config.mm_python_location).toBeDefined()
      expect(config.mm_mm_py_location).toBeDefined()
      expect(config.mm_path).toBeDefined()
      expect(config.mm_developer_mode).toBeDefined()