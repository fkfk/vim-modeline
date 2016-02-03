_ = require 'underscore-plus'
iconv = require 'iconv-lite'

{Emitter, CompositeDisposable} = require 'atom'

module.exports = VimModeline =
  subscriptions: null
  emitter: null
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
    _this = @

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-text-editor', 'vim-modeline:detect': => @detectVimModeLine(null, true)
    @subscriptions.add atom.commands.add 'atom-text-editor', 'vim-modeline:insert-modeline': => @insertModeLine()

    @subscriptions.add atom.workspace.observeTextEditors (editor) => @detectVimModeLine(editor, false)

    @subscriptions.add @onDidSetEncoding ({encoding}) ->
      pkg = atom.packages.getActivePackage 'auto-encoding'
      if pkg?.mainModule.subscriptions? and not _this.commandDispatched
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

  detectVimModeLine: (editor = null, @commandDispatched = false) ->
    editor = atom.workspace.getActiveTextEditor() if editor is null
    return unless editor
    options = false
    max = atom.config.get "vim-modeline.readLineNum"

    try
      if editor.getLastBufferRow() > max
        lineNum = _.uniq([0..max].concat [(editor.getLastBufferRow() - max)..editor.getLastBufferRow()])
      else
        lineNum = [0..editor.getLastBufferRow()]
      for i in lineNum
        opts = @parseVimModeLine editor.lineTextForBufferRow(i)
        options = opts if opts
      @emitter.emit 'did-parse', {editor, options}
      return false unless options
    catch error
      console.error error
      return false

    @setLineEnding editor, @lineEnding[options.fileformat]
    @setFileType editor, options.filetype
    @setEncoding editor, options.fileencoding
    @setIndent editor, options

  parseVimModeLine: (line) ->
    prefix = atom.config.get('vim-modeline.prefix').join "|"
    re = new RegExp "(#{prefix})([<=>]?\\d+)*:\\s*(set*)*\\s+([^:]+)*\\s*:"
    matches = line.match re
    options = null
    if matches
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
    scopeName = editor.getGrammar()?.scopeName.split(".")
    options =
      fileencoding: editor.getEncoding()
      fileformat: @detectLineEnding()
      filetype: scopeName[scopeName.length - 1]
      tabstop: editor.getTabLength()
      expandtab: editor.getSoftTabs()

    scope = editor.scopeDescriptorForBufferPosition [0, 0]
    comment = atom.config.get("editor.commentStart", {scope})

    if comment
      prefix = atom.config.get "vim-modeline.insertPrefix"
      settings = _.map(options, (v, k) ->
        if typeof v is "boolean"
          return "#{if v then "" else "no"}#{k}"
        else
          return "#{k}=#{v}"
      ).join(" ")
      modeline = "#{comment}#{prefix}:set #{settings}:"
      currentPosition = editor.getCursorBufferPosition()
      editor.setCursorBufferPosition [editor.getLastBufferRow(), 0]
      editor.insertNewlineBelow()
      editor.insertText modeline
      editor.setCursorBufferPosition currentPosition
    else
      console.error "'editor.commentStart' is undefined in this scope."

  detectLineEnding: (editor)->
    editor = atom.workspace.getActiveTextEditor() unless editor
    buffer = editor?.getBuffer()
    return unless editor

    lineEnding = buffer.lineEndingForRow(buffer.getLastRow() - 1)
    for key, val of @lineEnding
      if val is lineEnding
        return key
    return undefined
