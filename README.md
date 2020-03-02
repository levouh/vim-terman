## vim-terman

_A simple togglable terminal buffer manager/splitter._

### Warning

This plugin was thrown together pretty quickly, so if you find any problems with it please report them.

### Support

_I have only tested this plugin with the following:_  
- _Vim_: 8.2.227  
- _OS_: Linux

### Installation

```
Plug 'levouh/vim-terman'
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

By default, `vim-terman` assumes you like to use `bash` as your shell, but this can be changed:

```
let g:terman_shell = 'ksh'
```

Also by default, the terminal set will be different for each tab. If you'd like there to just be a single terminal set for all tabs:

```
let g:terman_per_tab = 0
```

### TODO

- Deal with closing all ther terminal buffers when no non-terminal buffers are present.
- Finish testing for mark/paste.
