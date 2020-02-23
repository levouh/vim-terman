## vim-terman

_A simple terminal buffer manager and multiplexer._

### Warning

This plugin was thrown together quickly and does a lot of unnecessary list iterations, etc.
It also doesn't do some useful things like support tabs, but I have plans to add features as development continues.
If you end up using it and find any bugs, please report them or make a PR to fix them.

### Support

_Vim_: 8.2.227

### Installation

```
Plug 'u0931220/vim-terman'
```

### Setup

`vim-terman` provides the following commands:

| **Command** | **Description** |
|---|---|
| `:TermanToggle` | Toggle all of the visible terminal buffers, or create one if it doesn't exist. |
| `:TermanVert` | Open a new terminal buffer in a vertical split relative to the current one. |
| `:TermanSplit` | Open a new terminal buffer in a horizontal split relative to the current one. |
| `:TermanFullscreen` | Fullscreen one of the terminal buffers within the set. |
| `:TermanMark` | Mark a terminal buffer in the set, see `TermanPaste`. |
| `:TermanPaste` | Paste the marked buffer in the currently selected window, effectively swapping the two. |

No mappings are provided by default, but some example mappings might include:

```
nnoremap <silent> <Leader>t :TermanToggle<CR>
tnoremap <silent> <C-w>t <C-\><C-n>:TermanToggle<CR>
```

### Configuration

```
g:terman_shell
```

Determines the type of shell to use within the terminal buffer, defaults to `bash`.

### TODO

- Clean up implementation to be more standardized/performant.
- Track the focus of the buffer when toggling the terminal set.
- Deal with closing all ther terminal buffers when no non-terminal buffers are present.
- Add tab support.
