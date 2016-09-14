_ = require 'underscore-plus'
iconv = require 'iconv-lite'

{Emitter, CompositeDisposable} = require 'atom'

module.exports = VimModeline =
  subscriptions: null
  emitter: null
  modelinePattern: null
  shortOptions: {
    fenc: "fileencoding"
    ff:   "fileformat"
    ft:   "filetype"
    et:   "expandtab"
    ts:   "tabstop"
    sts:  "softtabstop"
    sw:   "shiftwidth"
    noet: "noexpandtab"
  }
  alternativeOptions: {
    useSoftTabs: "expandtab"
    tabLength: "tabstop"
    encoding: "fileencoding"
    lineEnding: "fileformat"
    grammar: "filetype"
  }
  pairOptions: [
    {on: "expandtab", off: "noexpandtab"}
  ]
  lineEnding: {
    unix: "\n"
    dos:  "\r\n"
    mac:  "\r"
  }
  alternativeValue: {
    lf: "unix"
    crlf: "dos"
    cr: "mac"
  }

  activate: (state) ->
    @emitter = new Emitter

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.config.onDidChange 'vim-modeline.prefix', => @updateModelinePattern()
    @updateModelinePattern()

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-text-editor', 'vim-modeline:detect': => @detectAndApplyModelineSetting(null, true)
    @subscriptions.add atom.commands.add 'atom-text-editor', 'vim-modeline:insert-modeline': => @insertModeLine()

    @subscriptions.add atom.workspace.observeTextEditors (editor) => @detectAndApplyModelineSetting(editor, false)

    @subscriptions.add @onDidSetEncoding ({encoding}) =>
      pkg = atom.packages.getActivePackage 'auto-encoding'
      if pkg?.mainModule.subscriptions? and not @commandDispatched
        atom.notifications.addWarning "WARNING: auto-encoding package is enabled. In this case, file encoding doesn't match the modeline. If you want use vim-modeline parse result, please invoke 'vim-modeline:detect' command or select encoding '#{encoding}'.", dismissable: true


  deactivate: ->
    @subscriptions.dispose()

  onDidParse: (callback) ->
    @emitter.on 'did-parse', callback

  onDidSetLineEnding: (callback) ->
    @emitter.on 'did-set-line-ending', callback

  onDidSetFileType: (callback) ->
    @emitter.on 'did-set-file-type', callback

  onDidSetEncoding: (callback) ->
    @emitter.on 'did-set-encoding', callback

  onDidSetSoftTabs: (callback) ->
    @emitter.on 'did-set-softtabs', callback

  onDidSetTabLength: (callback) ->
    @emitter.on 'did-set-tab-length', callback

  provideVimModelineEventHandlerV1: ->
    onDidParse: @onDidParse.bind(@)
    onDidSetLineEnding: @onDidSetLineEnding.bind(@)
    onDidSetFileType: @onDidSetFileType.bind(@)
    onDidSetEncoding: @onDidSetEncoding.bind(@)
    onDidSetSoftTabs: @onDidSetSoftTabs.bind(@)
    onDidSetTabLength: @onDidSetTabLength.bind(@)

  detectAndApplyModelineSetting: (editor = null, @commandDispatched = false) ->
    editor = atom.workspace.getActiveTextEditor() if editor is null
    return unless editor

    options = @detectVimModeLine editor
    @emitter.emit 'did-parse', {editor, options}

    if options
      @setLineEnding editor, @lineEnding[options.fileformat]
      @setFileType editor, options.filetype
      @setEncoding editor, options.fileencoding
      @setIndent editor, options

  detectVimModeLine: (editor) ->
    options = false
    max = atom.config.get("vim-modeline.readLineNum") - 1
    try
      if editor.getLastBufferRow() > max
        lineNum = _.uniq([0..max].concat [(editor.getLastBufferRow() - max)..editor.getLastBufferRow()])
      else
        lineNum = [0..editor.getLastBufferRow()]
      for i in lineNum
        opts = @parseVimModeLine editor.lineTextForBufferRow(i)
        options = _.extend {}, options || {}, opts if opts
    catch error
      console.error error
    options

  updateModelinePattern: ->
    prefix = atom.config.get('vim-modeline.prefix').join "|"
    @modelinePattern = new RegExp "(#{prefix})([<=>]?\\d+)*:\\s*(set*)*\\s+([^:]+)*\\s*:?"

  parseVimModeLine: (line) ->
    matches = line.match @modelinePattern
    options = null
    if matches?[4]?
      options = {}
      for option in matches[4].split " "
        [key, value] = option.split "="
        key = @shortOptions[key] if @shortOptions[key] isnt undefined
        key = @alternativeOptions[key] if @alternativeOptions[key] isnt undefined
        value = @alternativeValue[value] if @alternativeValue[value] isnt undefined
        for pair in @pairOptions
          delete options[pair.on] if key is pair.off and options[pair.on]
        options[key] = value ? true if key isnt ""
    options

  setEncoding: (editor, encoding) ->
    return false unless iconv.encodingExists encoding
    encoding = encoding.toLowerCase().replace /[^0-9a-z]|:\d{4}$/g, ''
    editor?.setEncoding encoding
    @emitter.emit 'did-set-encoding', {editor, encoding}, @

  setLineEnding: (editor, lineEnding) ->
    return unless lineEnding
    buffer = editor?.getBuffer()
    return unless buffer
    buffer.setPreferredLineEnding lineEnding
    buffer.setText buffer.getText().replace(/\r\n|\r|\n/g, lineEnding)
    @emitter.emit 'did-set-line-ending', {editor, lineEnding}, @

  setFileType: (editor, type) ->
    grammar = atom.grammars.selectGrammar(type)
    if grammar isnt atom.grammars.nullGrammar
      atom.grammars.setGrammarOverrideForPath editor.getPath(), grammar.scopeName
      editor?.setGrammar grammar
      @emitter.emit 'did-set-file-type', {editor, grammar}, @

  setIndent: (editor, options) ->
    softtab = undefined
    softtab = true if options.expandtab
    softtab = false if options.noexpandtab
    if softtab isnt undefined
      editor?.setSoftTabs softtab
      @emitter.emit 'did-set-softtabs', {editor, softtab}, @

    # TODO: softtabstop and shiftwidth support
    #indent = options.softtabstop
    #if indent <= 0
    #  indent = options.shiftwidth
    #  if indent is undefined or indent is "0"
    #    indent = options.tabstop
    #return unless indent
    #editor?.setTabLength indent

    if options.tabstop
      tabstop = parseInt options.tabstop, 10
      editor?.setTabLength tabstop
      @emitter.emit 'did-set-tab-length', {editor, tabstop}, @

  insertModeLine: ->
    editor = atom.workspace.getActiveTextEditor()
    return unless editor
    options = @getCurrentOptions editor

    modelineRange = [@getInsertModelineRow(editor), 0]
    scope = editor.scopeDescriptorForBufferPosition modelineRange
    comment = atom.config.get("editor.commentStart", {scope})

    if comment
      modeline = "#{comment}#{@makeModeline(options)}"
      currentPosition = editor.getCursorBufferPosition()
      editor.setCursorBufferPosition modelineRange
      if atom.config.get("vim-modeline.insertModelinePosition") is "first row" or atom.config.get("vim-modeline.insertModelinePosition") is "above cursor row"
        editor.insertNewlineAbove()
      else
        editor.insertNewlineBelow()
      editor.insertText modeline
      editor.setCursorBufferPosition currentPosition
    else
      console.error "'editor.commentStart' is undefined in this scope."

  getCurrentOptions: (editor) ->
    editor = atom.workspace.getActiveTextEditor() unless editor
    scopeName = editor.getGrammar()?.scopeName.split(".")

    keys = switch atom.config.get("vim-modeline.insertModelineType")
      when "short"    then ["fenc", "ff", "ft", "ts", "et"]
      when "long"     then ["fileencoding", "fileformat", "filetype", "tabstop", "expandtab"]
      when "original" then ["encoding", "lineEnding", "grammar", "tabLength", "useSoftTabs"]

    options = {}
    for key in keys
      property = key
      key = @shortOptions[key] if @shortOptions[key] isnt undefined
      key = @alternativeOptions[key] if @alternativeOptions[key] isnt undefined
      options[property] = switch key
        when "fileencoding" then editor.getEncoding()
        when "fileformat"   then @detectLineEnding(editor)
        when "filetype"     then scopeName[scopeName.length - 1]
        when "tabstop"      then editor.getTabLength()
        when "expandtab"    then editor.getSoftTabs()
    options

  makeModeline: (options) ->
    prefix =
    settings = _.map(options, (v, k) ->
      if typeof v is "boolean"
        return "#{if v then "" else "no"}#{k}"
      else
        return "#{k}=#{v}"
    ).join(" ")
    "#{atom.config.get("vim-modeline.insertPrefix")}:set #{settings}:"

  getInsertModelineRow: (editor) ->
    editor = atom.workspace.getActiveTextEditor() unless editor
    switch atom.config.get "vim-modeline.insertModelinePosition"
      when "first row"        then 0
      when "last row"         then editor.getLastBufferRow()
      when "above cursor row" then editor.getCursorBufferPosition().row
      when "below cursor row" then editor.getCursorBufferPosition().row

  detectLineEnding: (editor)->
    editor = atom.workspace.getActiveTextEditor() unless editor
    buffer = editor?.getBuffer()
    return unless editor

    lineEnding = buffer.lineEndingForRow(buffer.getLastRow() - 1)
    for key, val of @lineEnding
      if val is lineEnding
        return key
    return undefined
