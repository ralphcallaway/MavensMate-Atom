{Provider, Suggestion} = require 'autocomplete-plus'
fuzzaldrin = require 'fuzzaldrin'
apex = require './apex.json'
# console.log apex
_ = require 'underscore-plus'
mm = require('./mavensmate-cli').mm
util = require './mavensmate-util'

module.exports =
  
  # provides code assist for standard Apex Classes
  # 
  # e.g. when user types "S", String, StringException, Site, Set, System, Sobject, etc. are showing in suggestions
  ApexProvider: class ApexProvider extends Provider
    wordRegex: /[A-Z].*/g
    apexClasses: []
    
    initialize: ->
      apexClasses = []
      apexNamespaces = apex.publicDeclarations
      _.each _.keys(apexNamespaces), (ns) ->
        # console.log ns
        _.each _.keys(apexNamespaces[ns]), (cls) ->
          apexClasses.push cls
      @apexClasses = apexClasses

    buildSuggestions: ->
      selection = @editor.getSelection()
      prefix = @prefixOfSelection selection
      return unless prefix.length

      suggestions = @findSuggestionsForPrefix prefix
      return unless suggestions.length
      return suggestions

    findSuggestionsForPrefix: (prefix) ->
        # Filter the words using fuzzaldrin
        words = fuzzaldrin.filter @apexClasses, prefix

        # Builds suggestions for the words
        suggestions = for word in words
          new Suggestion this, word: word, prefix: prefix, label: "@#{word} (Apex)"

        return suggestions

  # provides code assist for standard/custom Apex Class methods
  # 
  # e.g. when user types "s.", if s represents a String, user is shown a list of String instance methods 
  ApexContextProvider: class ApexContextProvider extends Provider
    wordRegex: /\b\w*[a-zA-Z_]\w*\b./g
    buildSuggestions: ->
      selection = @editor.getSelection()
      # console.log selection
      prefix = @prefixOfSelection selection
      prefix = prefix.replace /./, ''
      # console.log 'prefix!'
      # console.log prefix
      #@editor.
      
      cursorPosition = @editor.getCursorBufferPosition() #=> returns a point
      cachedBufferText = @editor.getBuffer().cachedText #=> returns the CURRENT buffer
      # console.log cachedBufferText
      if prefix == '.'
        params =
          args:
            operation: 'get_apex_class_completions'
            pane: atom.workspace.getActivePane()
            offline: true
          payload:
            point: [cursorPosition.row, cursorPosition.column]
            buffer: cachedBufferText
            #file_name: util.activeFile()
        mm.run(params).then (result) =>
          # console.log result
          # TODO: waiting on: https://github.com/saschagehlich/autocomplete-plus/pull/99
          suggestions = []
          for s in result.body
            suggestions.push new Suggestion(this, word: s.name, label: "@"+s.name, prefix: prefix) 
          console.log suggestions
          return suggestions

      
      return []

  # provides list of Sobjects available in the source org
  #
  # e.g. when user types "O" list of options may include Opportunity, OpportunityLineItem, OpportunityContactRole, etc.
  SobjectProvider: class SobjectProvider extends Provider
    wordRegex: /[A-Z].*/g
    sobjects: ["Account", "Contact", "Opportunity"] #todo: populate sobjects

    buildSuggestions: ->
      selection = @editor.getSelection()
      prefix = @prefixOfSelection selection
      return unless prefix.length

      suggestions = @findSuggestionsForPrefix prefix
      return unless suggestions.length
      return suggestions

    findSuggestionsForPrefix: (prefix) ->
        # Filter the words using fuzzaldrin
        words = fuzzaldrin.filter @sobjects, prefix

        # console.log words

        # Builds suggestions for the words
        suggestions = for word in words
          new Suggestion this, word: word, prefix: prefix, label: "@#{word} (Sobject)"

        return suggestions