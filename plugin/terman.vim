" Verification {{{1

    if exists('g:_loaded_terman') || v:version < 802
        finish
    endif

    let g:_loaded_terman = 1

" Variables {{{1

    " A sequence that is incremented each time a new tab is created, so
    " that each tab has a unique identifier.
    let g:_terman_tab_id = 0

" Commands {{{1

    " Toggle the terminal set
    command TermanToggle call terman#toggle()

    " Open a terminal buffer in a new split
    command TermanVertical call terman#new(1)
    command TermanHorizontal call terman#new(0)
    "                                        │
    "                                        └ argument specifies if vertical or not

    " Maximize a particular terminal buffer within the set
    command TermanMaximize call terman#maximize()

    " Hide non-terman buffers
    command TermanFullscreen call terman#fullscreen()

    " Mark a buffer to be pasted elsewhere
    command TermanYank call terman#yank()

    " Paste the marked buffer
    command TermanPaste call terman#paste()
