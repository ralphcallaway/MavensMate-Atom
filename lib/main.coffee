{$} = require 'atom'
MavensMate = require './mavensmate'

module.exports =

  configDefaults:
    mm_path: 'default'
    mm_developer_mode: false
    mm_mm_py_location: '/path/to/mm.py'
    mm_python_location : '/usr/bin/python'
    mm_community_api_token: ''
    mm_use_keyring: true
    mm_beta_user: false
    mm_auto_install_mm_updates: true
    # mm_location: 'mm/mm.py' => deprecated
    mm_compile_on_save : true
    mm_api_version : '31.0'
    mm_log_location : ''
    mm_log_level : 'DEBUG'
    mm_workspace : ['/one/cool/workspace', '/one/not-so-cool/workspace']
    mm_open_project_on_create : true
    mm_http_proxy : '',
    mm_https_proxy : '',
    mm_play_sounds: true,
    mm_panel_height: 200,
    mm_close_panel_on_successful_operation: true,
    mm_close_panel_delay: 1000,
    mm_template_location: 'remote',
    mm_compile_check_conflicts: true,
    mm_template_source: 'joeferraro/MavensMate-Templates/master',
    mm_default_subscription: [
      'ApexClass',
      'ApexComponent',
      'ApexPage',
      'ApexTrigger',
      'StaticResource',
      'CustomObject',
      'Profile'
    ],
    mm_ignore_managed_metadata: true,
    mm_archive_deployments: true,
    mm_use_org_metadata_for_completions: true,
    mm_compare_before_deployment: true,
    mm_apex_file_extensions: [".page", ".component", ".cls", ".object", ".trigger", ".layout", ".resource", ".remoteSite", ".labels", ".app", ".dashboard", ".permissionset", ".workflow", ".email", ".profile", ".scf", ".queue", ".reportType", ".report", ".weblink", ".tab", ".letter", ".role", ".homePageComponent", ".homePageLayout", ".objectTranslation", ".flow", ".datacategorygroup", ".snapshot", ".site", ".sharingRules", ".settings", ".callCenter", ".community", ".authProvider", ".customApplicationComponent", ".quickAction", ".approvalProcess", ".html" ]

  # todo: should we initiate the app per editorview?
  # right now, this activates MavensMate once per Atom window
  # i think we want to keep each MavensMate() instance tied to a project, but not 100% sure how to approach that
  activate: =>
    console.log 'activating mavensmate'
    @mavensmate = new MavensMate

  deactivate: =>
    console.log 'deactivating mavensmate'
    @mavensmate.destroy()
    delete @mavensmate

