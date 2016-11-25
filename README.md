# vim-modeline package

Enable Vim-style modeline in Atom.

## Supported options

- `expandtab` / `noexpandtab`
- `fileencoding`
- `fileformat`
- `filetype`
- `tabstop`

## Example

### Valid Vim-style modeline

```coffeescript
# vim:set expandtab tabstop=2 fenc=utf-8 ff=unix ft=coffee:
```

### Atom-specific modeline

```coffeescript
# atom:set useSoftTabs tabLength=2 encoding=utf-8 lineEnding=lf grammar=coffee:
```

## Atom-specific modeline

- `useSoftTabs` -> `expandtab`
- `encoding` -> `fileencoding`
- `lineEnding` -> `fileformat`
- `grammar` -> `filetype`
- `tabLength` -> `tabstop`
-
## Configuring extension

You can add more filetype for a given language scope.
To do this, add the settings to the `~/.atom/config.cson` in the format below.

```coffeescript
'vim-modeline-filetypes':
  # append scopeName
  'as': [
    'source.actionscript.3'
  ]
  # override scopeName
  'markdown': 'text.md'
```

## vim-modeline Event Handler

This package can use the event handler using "Service API".

- onDidParse
- onDidSetLineEnding
- onDidSetFileType
- onDidSetEncoding
- onDidSetSoftTabs
- onDidSetTabLength

eg: get parse result in `init.coffee`.

```coffeescript
atom.packages.serviceHub.consume "vim-modeline-event-handler", "^1.0.0", (handler) ->
  handler.onDidParse ({editor, options}) ->
    console.log editor
    console.log options
    someFunction(options)
```

## Conflict issue

If you use [auto-encoding](https://atom.io/packages/auto-encoding) package, file encoding doesn't match the modeline.
If you want use vim-modeline parse result, please invoke 'vim-modeline:detect' command after open TextEditor.

## TODO

- [ ] `softtabstop` support
- [ ] `shiftwidth` support
