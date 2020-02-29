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

    let g:terman_per_tab = get(g:, 'terman_per_tab', 1)

" --- Variables

    " A list of terminal buffer entries managed by terman,
    " optionally split by tab
    let g:_terman_terminal_set = {}

    " The generic key to be used if not using terman_per_tab
    let g:_terman_key = 'base'

    " The buffer that is currently fullscreened within the set
    let g:_terman_fullscreen_buf = {}

    " Whether or not the terminal set is visible
    let g:_terman_visible_state = {}

    " Track what buffer was focused when toggling
    let g:_terman_focused_buf = {}

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
