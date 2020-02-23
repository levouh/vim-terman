" Toggle the visibility of the terminal set
function! terman#toggle()
    if exists('g:_terman_visible_state')
       \ && g:_terman_visible_state == -1
        " Create the root node
        call terman#create('')

        " The terminal set is now visible
        let g:_terman_visible_state = 1
    else
        if g:_terman_visible_state
            " The terminal set is visible, hide it
            call s:hide_all()

            let g:_terman_visible_state = 0
        else
            " The terminal set is not visible, show it
            call s:open_all()

            let g:_terman_visible_state = 1
        endif
    endif
endfunction

" Create a new terminal, and store metadata pertaining to it
function! terman#create(mode)
    if !exists('b:_terman_buffer')
       \ && exists('g:_terman_terminal_set')
       \ && !empty(g:_terman_terminal_set)
        echoerr 'ERROR: Can only open a new Terman buffer from an existing one'
        return
    endif

    " Base arguments used to create the buffer
    let l:term_args = ' term ++close ++kill=term ' . g:terman_shell

    " The root node has no parent, an empty 'a:mode' denotes creation of the root node
    let l:parent = empty(a:mode) ? '' : bufnr('%')

    if empty(a:mode)
        " When starting fresh, open on the bottom
        " TODO: Make position configurable
        let l:term_args = 'bot' . l:term_args
    elseif a:mode == 'v'
        " Open a new vertical split terminal, the arguments are already setup for
        " horizontally splitting a new terminal buffer
        let l:term_args = 'vert' . l:term_args
    endif

    exe l:term_args

    " Mark it as one of the set
    let b:_terman_buffer = 1
    let l:bufnr = bufnr('%')

    call s:add_buffer_to_terminal_set(a:mode, l:bufnr, l:parent)
endfunction

" Add a buffer to the tracked set
function! s:add_buffer_to_terminal_set(mode, bufnr, parent)
    let l:entry = {
                  \'mode': a:mode,
                  \'bufnr': a:bufnr,
                  \'parent': a:parent
                  \}

    call add(g:_terman_terminal_set, l:entry)
endfunction

" Hide all currently visible buffers of the terminal set
function! s:hide_all()
    for l:entry in g:_terman_terminal_set
        let l:winids = win_findbuf(l:entry.bufnr)

        for l:winid in l:winids
            " Now hide it
            call win_gotoid(l:winid)
            hide
        endfor
    endfor

    wincmd =
endfunction

" Restore the layout of the terminal set and make them all visible
function! s:open_all()
    " Open the root
    exe 'bot sb ' . g:_terman_terminal_set[0].bufnr

    " Start at index 1, and open everything else
    let l:i = 1

    while l:i < len(g:_terman_terminal_set)
        let l:entry = g:_terman_terminal_set[l:i]
        let l:winnr = bufwinnr(l:entry.parent)

        if l:entry.mode == 'v'
            let l:modifier = 'vert '
        else
            let l:modifier = ''
        endif

        " Go to the parent and open a new window accordingly
        exe l:winnr . 'wincmd w'
        exe l:modifier . 'sb ' . l:entry.bufnr

        let l:i += 1
    endwhile
endfunction

" Remove a buffer from the terminal set
function! terman#close()
    if !exists('b:_terman_buffer')
        " Buffer not in the terminal set
        return
    endif

    if !len(g:_terman_terminal_set)
        return
    else
        let l:root = g:_terman_terminal_set[0].bufnr
    endif

    " The buffer being deleted
    let l:bufnr = string(bufnr(''))

    " Find the buffer we need to remove
    let l:i = 0
    let l:del_idx = -1
    let l:del_entry = {}
    let l:last_child_idx = -1
    let l:last_child = {}

    for l:entry in g:_terman_terminal_set
        if l:entry.bufnr == l:bufnr
            let l:del_entry = l:entry
            let l:del_idx = l:i
        endif

        if l:entry.parent == l:bufnr
            let l:last_child = l:entry
            let l:last_child_idx = l:i
        endif

        let l:i += 1
    endfor

    " Update all children of this node to have a new
    " parent of the last child
    if !empty(l:last_child)
        for l:entry in g:_terman_terminal_set
            if l:entry.bufnr == l:last_child.bufnr
                " Only update those that aren't the new parent
                let l:last_child.parent = l:del_entry.parent
                continue
            endif

            if l:entry.parent == l:bufnr
                let l:entry.parent = l:last_child.bufnr
            endif
        endfor
    endif

    if !empty(l:last_child)
        let l:insert_idx = -1

        if l:bufnr == l:root
            " The root has no parent
            let l:last_child.parent = ''

            " Put its last child as the new root
            let l:insert_idx = 0
        else
            " Put it where its parent used to be
            let l:insert_idx = l:del_idx

            " Inherit creation mode from parent
            let l:last_child.mode = l:del_entry.mode
        endif
    endif

    " Remove the closed entry
    unlet g:_terman_terminal_set[l:del_idx]

    if !empty(l:last_child)
        " Place its last child in its place
        call insert(g:_terman_terminal_set, l:last_child, l:insert_idx)

        " Remove its last child
        unlet g:_terman_terminal_set[l:last_child_idx]
    endif

    if empty(g:_terman_terminal_set)
        let g:_terman_visible_state = -1
    endif
endfunction

" Make a single terminal window within the set fullscreen
function! terman#fullscreen()
    if g:_terman_fs_buffer == -1
        " No window is currently full-screened
        let l:cur_win = win_getid()
        let g:_tt_fs = l:cur_win

        for l:entry in g:_terman_terminal_set
            let l:winids = win_findbuf(l:entry.bufnr)

            " Hide all but the focused window
            for l:winid in l:winids
                if l:winid == l:cur_win
                    continue
                endif

                call win_gotoid(l:winid)
                hide
            endfor
        endfor
    else
        " Some window is already full-screened
        call win_gotoid(g:_tt_fs)
        hide

        call s:open_all()

        let g:_terman_fs_buffer = -1
    endif
endfunction

" Mark a buffer in the terminal set
function! terman#mark()
    if exists('b:_terman_buffer')
        let g:_terman_marked = bufnr()

        redraw | echo 'Yanked buffer ' . g:_terman_marked
    endif
endfunction

" Paste the marked buffer
function! terman#paste()
    if exists('g:_terman_marked')
       \ && exists('b:_terman_buffer')
        let l:target_bufnr = bufnr('%')
        let l:target_index = -1
        let l:target_winnr = -1
        let l:target_parent = -1

        let l:marked_index = -1
        let l:marked_winnr = -1
        let l:marked_parent = -1

        let l:index = 0

        for l:entry in g:_terman_terminal_set
            if l:entry.bufnr == l:target_bufnr
                let l:target_index = l:index
                let l:target_parent = l:entry.parent
                let l:target_winnr = bufwinnr(l:entry.bufnr)
            endif

            if l:entry.bufnr == g:_terman_marked
                let l:marked_index = l:index
                let l:marked_parent = l:entry.parent
                let l:marked_winnr = bufwinnr(l:entry.bufnr)
            endif

            let l:index = l:index + 1
        endfor

        if l:marked_index != -1
           \ && l:target_index != -1
           \ && l:target_parent != -1
           \ && l:marked_winnr != -1
           \ && l:marked_winnr != -1
           \ && l:marked_parent != -1
            " Update global state
            let g:_terman_terminal_set[marked_index].bufnr = l:target_bufnr
            let g:_terman_terminal_set[target_index].bufnr = g:_terman_marked

            let l:mp = l:marked_parent
            let l:tp = l:target_parent

            if l:marked_parent == l:target_bufnr
                let l:mp = l:target_parent
                let l:tp = g:_terman_marked
            elseif l:target_parent == g:_terman_marked
                let l:mp = l:target_bufnr
                let l:tp = l:marked_parent
            endif

            " If swapping with root, don't want to change parent
            if !empty(l:mp)
                let g:_terman_terminal_set[target_index].parent = l:mp
            endif

            if !empty(l:tp)
                let g:_terman_terminal_set[marked_index].parent = l:tp
            endif

            let l:mpl = []
            let l:tpl = []

            " Swap parents of all other buffers as well
            for l:entry in g:_terman_terminal_set
                if l:entry.parent == l:target_bufnr
                    call add(l:mpl, l:entry)
                endif

                if l:entry.parent == g:_terman_marked
                    call add(l:tpl, l:entry)
                endif
            endfor

            for l:entry in l:mpl
                let l:entry.parent = g:_terman_marked
            endfor

            for l:entry in l:tpl
                let l:entry.parent = l:target_bufnr
            endfor

            " Perform visual swap
            exe l:marked_winnr . 'wincmd w'
            exe 'hide buf' . l:target_bufnr

            exe l:target_winnr . 'wincmd w'
            exe 'hide buf' . g:_terman_marked

        endif

        unlet g:_terman_marked
    else
        echoerr 'ERROR: No marked window'
    endif
endfunction
