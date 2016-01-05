_ = require 'underscore-plus'
iconv = require 'iconv-lite'

{CompositeDisposable} = require 'atom'

module.exports = VimModeline =
  config:
    readLineNum:
      type: 'integer'
      default: 5
      minimum: 1

  subscriptions: null
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
  pairOptions: [
    {on: "expandtab", off: "noexpandtab"}
  ]
  lineEnding: {
    unix: "\n"
    dos:  "\r\n"
    mac:  "\r"
  }

  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-text-editor', 'vim-modeline:detect': => @detectVimModeLine()

    @subscriptions.add atom.workspace.observeTextEditors (editor) => @detectVimModeLine(editor)

  deactivate: ->
    @subscriptions.dispose()

  detectVimModeLine: (editor = null) ->
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
      return false unless options
    catch error
      console.error error
      return false

    @setLineEnding editor, @lineEnding[options.fileformat]
    @setFileType editor, options.filetype
    @setEncoding editor, options.fileencoding
    @setIndent editor, options

  parseVimModeLine: (line) ->
    matches = line.match /(vi|vim|ex)([<=>]?\d+)*:\s*(se(t)*)*\s+([^:]+)*\s*:/
    options = null
    if matches
      options = {}
      for option in matches[5].split " "
        [key, value] = option.split "="
        key = @shortOptions[key] if @shortOptions[key] isnt undefined
        for pair in @pairOptions
          delete options[pair.on] if key is pair.off and options[pair.on]
        options[key] = value ? true if key isnt ""
    options

  setEncoding: (editor, encoding) ->
    return false unless iconv.encodingExists encoding
    encoding = encoding.toLowerCase().replace /[^0-9a-z]|:\d{4}$/g, ''
    editor?.setEncoding encoding

  setLineEnding: (editor, lineEnding) ->
    return unless lineEnding
    buffer = editor?.getBuffer()
    return unless buffer
    buffer.setPreferredLineEnding lineEnding
    buffer.setText buffer.getText().replace(/\r\n|\r|\n/g, lineEnding)

  setFileType: (editor, type) ->
    grammar = atom.grammars.selectGrammar(type)
    if grammar isnt atom.grammars.nullGrammar
      atom.grammars.setGrammarOverrideForPath editor.getPath(), grammar
      editor?.setGrammar grammar

  setIndent: (editor, options) ->
    softtab = undefined
    softtab = true if options.expandtab
    softtab = false if options.noexpandtab
    editor?.setSoftTabs softtab if softtab isnt undefined

    # TODO: softtabstop and shiftwidth support
    #indent = options.softtabstop
    #if indent <= 0
    #  indent = options.shiftwidth
    #  if indent is undefined or indent is "0"
    #    indent = options.tabstop
    #return unless indent
    #editor?.setTabLength indent

    editor?.setTabLength options.tabstop if options.tabstop
