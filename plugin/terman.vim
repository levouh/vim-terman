" --- Verification

    if exists('g:_loaded_terman') || v:version < 802 || has('gui_running')
        finish
    endif

    let g:_loaded_terman = 1

" --- Options

    let g:terman_shell = get(g:, 'terman_shell', 'bash')

    if !executable(g:terman_shell)
        finish
    endif

" --- Variables

    " A list of terminal buffer entries managed by terman
    let g:_terman_terminal_set = []

    " The buffer that is currently fullscreened within the set
    let g:_terman_fs_buffer = -1

    " Whether or not the terminal set is visible
    let g:_terman_visible_state = -1

" --- Commands

    " Open a terminal buffer in a new split
    command TermanVert call terman#create('v')
    command TermanSplit call terman#create('s')

    " Fullscreen a particular terminal buffer within the set
    command TermanFullscreen call terman#fullscreen()

    " Toggle the terminal set
    command TermanToggle call terman#toggle()

    " Swap the position of two terminal buffer windows
    command TermanMark call terman#mark()
    command TermanPaste call terman#paste()

" --- Autocommands

    augroup terman
        au!

        " Handle removing buffers from the terminal set when they are closed
        au BufDelete * call terman#close()
    augroup END
