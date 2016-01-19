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
# atom:set expandtab tabstop=2 fenc=utf-8 ff=unix ft=coffee:
```

## TODO

- [ ] `softtabstop` support
- [ ] `shiftwidth` support
