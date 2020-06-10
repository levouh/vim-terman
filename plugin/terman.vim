" Verification {{{1

    if exists('g:_loaded_terman') || v:version < 802
        finish
    endif

    let g:_loaded_terman = 1

" Options {{{1

    " TODO: Remove
    let g:terman_per_tab = 0

    " The border for the popup terminal window
    hi default link Ignore TermanBorder

    if !exists('g:terman_popup_opts')
        " Used when configuring the popup window
        let g:terman_popup_opts = {
                \ 'width': 0.9,
                \ 'height': 0.6,
                \ 'highlight': 'TermanBorder'
        \ }
    endif

" Variables {{{1

    " A sequence that is incremented each time a new tab is created, so
    " that each tab has a unique identifier.
    let g:_terman_tab_id = 0

    " A list of terminal buffer entries managed by terman,
    " optionally split by tab.
    "
    " Because ":h tabpagenr()" will just return an 'index'
    " of a tab rather than a unique identifier like ":h bufnr()",
    " each key will be a tab 'ID' which is managed/tracked by
    " this plugin
    "
    " The dictionary will look like:
    "   { '<tabid': [ {'<term_indo>'}, ...] }
    " let g:_terman_terminal_set = {}


    " " The buffer that is currently maximized within the set, which
    " " means that the other buffers are hidden. The user can change
    " " this through non-terman commands, but the next time the set is
    " " updated/toggled, terman will just use the information knows
    " " about
    " let g:_terman_maximized_state = {}

    " " Whether or not non-terman windows are hidden, so that when
    " " something is 'fullscreen', no non-terman buffers are visible
    " let g:_terman_fullscreen_state = {}

    " " Track what buffer was focused when toggling, this only serves
    " " to provide a more fluid experience so that when toggling the set
    " " if a specific buffer was focused when it was hidden, it will be
    " " focused again when it is toggled into view
    " "
    " " This is tracked through autocommands, which are enabled/disabled
    " " at certain timed. The group for this is "terman".
    " let g:_terman_focused_buf = {}

    " " Name of the floating term buffer. Note that only a single popup
    " " terminal can exist at any given time, so the name here can just stay
    " " consistent.
    " let g:_terman_float_name = '_terman_float_buf'

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

    " " Hide non-terman buffers
    " command TermanFullscreen call terman#fullscreen()

    " " Swap the position of two terminal buffer windows
    " command TermanMark call terman#mark()
    " command TermanPaste call terman#paste()

    " " Toggle a popup terminal buffer
    " command TermanFloatToggle call terman#float()
