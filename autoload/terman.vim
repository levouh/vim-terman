" --- Public Functions

    " Toggle a popup terminal window
    function! terman#float()
        " Check if it exists already
        let l:bufnr = bufnr(g:_terman_float_name)

        if l:bufnr == -1 || !bufloaded(l:bufnr)
            " It doesn't exist, create it
            let g:_terman_float_winid = s:create_popup(g:terman_popup_opts)
        else
            if exists('g:_terman_float_winid')
                " Created, visible
                try
                    call popup_close(g:_terman_float_winid)
                catch
                    hide
                endtry

                unlet g:_terman_float_winid
            else
                " Created, not visible
                let l:opts = g:terman_popup_opts
                let l:opts.bufnr = l:bufnr

                let g:_terman_float_winid = s:create_popup(g:terman_popup_opts)
            endif
        endif
    endfunction

    " Toggle the visibility of the terminal set
    function! terman#toggle()
        if !exists('g:_terman_visible_state')
            return
        endif

        let l:key = s:get_key()
        let l:winid = win_getid()

        if empty(s:get_entries(l:key))
            " Create the root node
            call terman#create('')
            call s:toggle_visible(l:key)
        else
            let l:is_visible = s:is_visible(l:key)

            if g:terman_per_tab
                if l:is_visible
                    " The terminal set is visible, hide it for this tab
                    call s:hide_all()
                    call s:toggle_visible(l:key)

                    " Keep focus on the window that the closing happens from
                    call s:focus_win(l:key, l:winid)
                else
                    " The terminal set is not visible, show it for this tab
                    call s:open_all()
                    call s:toggle_visible(l:key)

                    " Focus the buffer that was focused during the last session
                    call s:focus_buf(l:key)
                endif
            else
                if l:is_visible
                    let l:visible_tabnr = s:get_set_tabnr()

                    if l:visible_tabnr == tabpagenr()
                        " The terminal set is visible on this tab, hide it
                        call s:hide_all()

                        " Keep focus on the window that the closing happens from
                        call s:focus_win(l:key, l:winid)

                        call s:toggle_visible(l:key)

                        " Keep focus on the window that the closing happens from
                        call s:focus_win(l:key, l:winid)
                    else
                        " The terminal set is visible on another tab, bring it to this one
                        call s:hide_all()

                        " Keep focus on the window that the closing happens from
                        call s:focus_win(l:key, l:winid)

                        " Still open, so don't toggle visibility
                        call s:open_all()

                        " Focus the buffer that was focused during the last session
                        call s:focus_buf(l:key)
                    endif
                else
                    " Not visible, for current window
                    call s:open_all()
                    call s:toggle_visible(l:key)
                endif
            endif
        endif

        wincmd =
    endfunction

    " Create a new terminal, and store metadata pertaining to it
    function! terman#create(mode)
        let l:key = s:get_key()
        let l:entries = s:get_entries(l:key)

        if !exists('b:_terman_buffer') && exists('g:_terman_terminal_set') && !empty(l:entries)
            echoerr 'ERROR: Can only open a new Terman buffer from an existing one'
            return
        endif

        " Base arguments used to create the buffer
        let l:term_args = ' term ++close ++kill=kill ' . g:terman_shell

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

        let l:entry = {
                \ 'mode': a:mode,
                \ 'bufnr': l:bufnr,
                \ 'parent': l:parent
        \ }

        " As intuitive as it is, an index of '-1' means append to the list
        call s:add_entry(l:key, -1, l:entry)
    endfunction

    " Remove a buffer from the terminal set
    function! terman#close()
        if !exists('b:_terman_buffer')
            " Buffer not in the terminal set
            return
        endif

        if !exists('g:_terman_terminal_set') || empty(g:_terman_terminal_set)
            return
        endif

        let l:key = s:get_key()
        let l:entries = s:get_entries(l:key)

        if empty(l:entries)
            return
        endif

        let l:root = l:entries[0].bufnr

        " The buffer being deleted
        let l:bufnr = string(bufnr(''))

        " Find the buffer we need to remove
        let l:i = 0
        let l:del_idx = -1
        let l:del_entry = {}
        let l:last_child_idx = -1
        let l:last_child = {}

        for l:entry in l:entries
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
            for l:entry in l:entries
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
        call s:remove_list_entry(l:key, l:del_idx)

        if !empty(l:last_child)
            " Place its last child in its place
            call s:add_entry(l:key, l:insert_idx, l:last_child)

            " Remove its last child
            call s:remove_list_entry(l:key, l:last_child_idx)
        endif

        let l:cur_entries = s:get_entries(l:key)

        " See if this was the last buffer
        if empty(l:cur_entries)
            let g:_terman_visible_state[l:key] = 0
        endif

        " See if this buffer was marked as fullscreen
        let l:fs_buf = s:get_fullscreen_buf(l:key)

        if l:fs_buf != -1
            call s:set_fullscreen_buf(l:key, -1)
        endif
    endfunction

    " Make a single terminal window within the set fullscreen
    function! terman#fullscreen()
        let l:key = s:get_key()

        if !s:has_fullscreen_buf(l:key)
            " No window is currently full-screened
            call s:hide_all(win_getid())

            call s:set_fullscreen_buf(l:key, bufnr('%'))
        else
            " Some window is already full-screened
            let l:fs_buf = s:get_fullscreen_buf(l:key)

            if l:fs_buf == -1
                return
            endif

            call s:hide_all()

            " A value of '-1' denotes that nothing is full-screened
            call s:set_fullscreen_buf(l:key, -1)

            call s:open_all()
        endif
    endfunction

    " Mark a buffer in the terminal set
    " TODO: Handle marking per tab
    " TODO: Allow moving buffers between tabs
    function! terman#mark()
        if exists('b:_terman_buffer')
            let g:_terman_marked = bufnr()

            redraw | echo 'Yanked buffer ' . g:_terman_marked
        endif
    endfunction

    " Paste the marked buffer
    function! terman#paste()
        if exists('g:_terman_marked') && exists('b:_terman_buffer')
            let l:target_bufnr = bufnr('%')
            let l:target_index = -1
            let l:target_winnr = -1
            let l:target_parent = -1

            let l:marked_index = -1
            let l:marked_winnr = -1
            let l:marked_parent = -1

            let l:index = 0
            let l:key = s:get_key()
            let l:entries = s:get_entries(l:key)
            let l:found = 0

            for l:entry in l:entries
                if l:entry.bufnr == l:target_bufnr
                    let l:found = 1
                    let l:target_index = l:index
                    let l:target_parent = l:entry.parent
                    let l:target_winnr = bufwinnr(l:entry.bufnr)
                endif

                if l:entry.bufnr == g:_terman_marked
                    let l:found = 1
                    let l:marked_index = l:index
                    let l:marked_parent = l:entry.parent
                    let l:marked_winnr = bufwinnr(l:entry.bufnr)
                endif

                let l:index = l:index + 1
            endfor

            if !l:found
                unlet g:_terman_marked
                return
            endif

            if l:marked_index != -1 && l:target_index != -1 && l:target_parent != -1 && l:marked_winnr != -1 && l:marked_winnr != -1 && l:marked_parent != -1
                " Update global state
                call s:set_entry(l:key, l:marked_index, l:target_bufnr, 'bufnr')
                call s:set_entry(l:key, l:target_index, g:_terman_marked, 'bufnr')

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
                    call s:set_entry(l:key, l:target_index, l:mp, 'parent')
                endif

                if !empty(l:tp)
                    call s:set_entry(l:key, l:marked, l:tp, 'parent')
                endif

                let l:mpl = []
                let l:tpl = []

                " Swap parents of all other buffers as well
                for l:entry in l:entries
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

    " Get rid of a tab and it's terminal set when the tab is closed.
    function! terman#tab_closed()
        let l:known_tabs = {}
        for l:tabnr in range(1, tabpagenr('$'))
            let l:known_tabs[l:tabnr] = 1
        endfor

        for [l:tabnr, l:bufs] in items(g:_terman_terminal_set)
            if !has_key(l:known_tabs, l:tabnr)
                " Wipeout the terman buffers as they are attached to the closed tab
                if g:terman_per_tab
                    for l:bufinfo in l:bufs
                        let l:bufnr = l:bufinfo.bufnr

                        try
                            exe 'bwipeout' . bufnr(l:bufnr)
                        catch | | endtry
                    endfor

                    unlet g:_terman_terminal_set[l:tabnr]
                endif
            endif
        endfor
    endfunction

" --- Private Functions

    " Get the accessor key to use based on global settings
    function! s:get_key()
        return g:terman_per_tab ? tabpagenr() : g:_terman_key
    endfunction

    " Hide all currently visible buffers of the terminal set
    function! s:hide_all(...)
        let g:_terman_skip_au = 1

        if a:0
            let l:winids_to_skip = a:000
        else
            let l:winids_to_skip = []
        endif

        " if s:only_terman_windows_left()
        "     top new
        " endif

        call s:hide_all_helper(l:winids_to_skip)

        unlet g:_terman_skip_au
    endfunction

    " Functionality for hiding buffers
    function! s:hide_all_helper(winids_to_skip)
        let l:key = s:get_key()
        let l:made_new_already = 0
        let l:entries = s:get_entries(l:key)

        for l:entry in l:entries
            let l:winids = win_findbuf(l:entry.bufnr)

            for l:winid in l:winids
                " Used when fullscreening a buffer, hide all except the 'fullscreened' one
                if len(a:winids_to_skip) && index(a:winids_to_skip, l:winid) >= 0
                    continue
                endif

                " Go to the window before checking
                call win_gotoid(l:winid)

                if s:only_terman_windows_left() && !l:made_new_already
                    " Create a new split to prevent errors
                    top new

                    " Focus changes due to above, now go back
                    call win_gotoid(l:winid)

                    " Only do this once
                    let l:made_new_already = 1
                endif

                hide
            endfor
        endfor
    endfunction

    " Restore the layout of the terminal set and make them all visible
    function! s:open_all()
        let l:key = s:get_key()
        let l:entries = s:get_entries(l:key)
        let g:_terman_skip_au = 1

        let l:fs_buf = s:get_fullscreen_buf(l:key)

        if l:fs_buf != -1
            let l:open_buf = l:fs_buf
        else
            let l:open_buf = l:entries[0].bufnr
        endif

        " Open the proper buffer
        exe 'bot sb ' . l:open_buf

        " Only open the fullscreened buffer
        if l:fs_buf != -1
            return
        endif

        " Start at index 1, and open everything else
        let l:i = 1

        while l:i < len(l:entries)
            let l:entry = l:entries[l:i]
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

        unlet g:_terman_skip_au
    endfunction

    " Get all of the entries for a particular tab
    function! s:get_entries(key)
        return get(g:_terman_terminal_set, a:key, [])
    endfunction

    " Add an entry to th eterminal buffer set list
    function! s:add_entry(key, index, value)
        let l:entries = get(g:_terman_terminal_set, a:key, [])

        if a:index == -1
            call add(l:entries, a:value)
        else
            call insert(l:entries, a:value, a:index)
        endif

        let g:_terman_terminal_set[a:key] = l:entries
    endfunction

    " Set the value of an entry in the terminal buffer set list
    function! s:set_entry(key, index, value, attribute)
        let l:entries = get(g:_terman_terminal_set, a:key, [])

        if empty(a:attribute)
            let l:entries[a:index] = a:value
        else
            exe 'let l:entries[a:index].' . a:attribute . ' = a:value'
        endif

        let g:_terman_terminal_set[a:key] = l:entries
    endfunction

    " Remove an entry from a terminal set buffer list
    function! s:remove_list_entry(key, index)
        if has_key(g:_terman_terminal_set, a:key) && !empty(g:_terman_terminal_set[a:key])
            unlet g:_terman_terminal_set[a:key][a:index]
        endif

        if empty(g:_terman_terminal_set[a:key])
            unlet g:_terman_terminal_set[a:key]
        endif
    endfunction

    " Determine if the terminal set is visible
    function! s:is_visible(key)
        if exists('g:_terman_visible_state') && has_key(g:_terman_visible_state, a:key) && g:_terman_visible_state[a:key] == 1
            return 1
        endif

        return 0
    endfunction

    " Toggle the visibility state of the terminal buffer set
    function! s:toggle_visible(key)
        if s:is_visible(a:key)
            let g:_terman_visible_state[a:key] = 0
        else
            let g:_terman_visible_state[a:key] = 1
        endif
    endfunction

    " Determine if any buffer is currently fullscreened
    function! s:has_fullscreen_buf(key)
        if !has_key(g:_terman_fullscreen_buf, a:key)
            let g:_terman_fullscreen_buf[a:key] = -1
        endif

        if g:_terman_fullscreen_buf[a:key] == -1
            return 0
        endif

        return 1
    endfunction

    " Get the buffer which is set as fullscreen
    function! s:get_fullscreen_buf(key)
        if exists('g:_terman_fullscreen_buf') && has_key(g:_terman_fullscreen_buf, a:key) && g:_terman_fullscreen_buf[a:key] != -1
            return g:_terman_fullscreen_buf[a:key]
        endif

        return -1
    endfunction

    " Set a single buffer within the terminal set as fullscreen
    function! s:set_fullscreen_buf(key, bufnr)
        let g:_terman_fullscreen_buf[a:key] = a:bufnr
    endfunction

    " Try to focus the passed window
    function! s:focus_win(key, winid)
        try
            call win_gotoid(a:winid)
        catch | | endtry
    endfunction

    " Focus the window containing the passed buffer
    function! s:focus_buf(key)
        if s:is_visible(a:key) && has_key(g:_terman_focused_buf, a:key)
            try
                exe bufwinnr(g:_terman_focused_buf[a:key]) . 'wincmd w'
            catch | | endtry
        endif
    endfunction

    " Track the focus of buffers within the terminal set for use when toggling
    function! s:set_focused(key, bufnr)
        " Skip changing focus when we are opening all terminal windows as the result of a toggle
        if !exists('g:_terman_skip_au') && exists('b:_terman_buffer')
            let g:_terman_focused_buf[a:key] = a:bufnr
        endif
    endfunction

    function! s:get_set_tabnr()
        let l:tabnr = tabpagenr()
        let l:key = s:get_key()

        if exists('g:_terman_key')
            let l:entries = s:get_entries(l:key)
            let l:winid = win_getid()

            try
                if len(l:entries)
                    let l:bufnr = l:entries[0].bufnr
                    let l:winids = win_findbuf(l:bufnr)

                    if len(l:winids)
                        call win_gotoid(l:winids[0])
                        let l:tabnr = tabpagenr()
                    endif
                endif
            finally
                call win_gotoid(l:winid)
            endtry
        endif

        return l:tabnr
    endfunction

    function! s:visible_on_current_tab()
        " Only used when hiding, so if there is only one set it
        " has to be visible
        if g:terman_per_tab
            return 1
        endif

        let l:key = s:get_key()
        let l:term_bufs = s:get_entries(l:key)
        let l:tab_bufs = tabpagebuflist()

        for l:term_buf in l:term_bufs
            if index(l:tab_bufs, l:term_buf) >= 0
                return 1
            endif
        endfor

        return 0
    endfunction

    " Determine if there are only terminal buffers left in the current tab
    function! s:only_terman_windows_left()
        let l:key = s:get_key()

        let l:fs_buf = s:get_fullscreen_buf(l:key)
        let l:windows_in_tab = tabpagewinnr(v:lnum, '$')

        " There is a fullscreened buffer, so we only expect a single terman window
        let l:num_entries = l:fs_buf != -1 ? 1 : len(s:get_entries(l:key))

        if l:num_entries == l:windows_in_tab
            return 1
        endif

        return 0
    endfunction

    " Helper for s:popup, based on fzf.vim
    function! s:create_popup(opts) abort
        let width = min([max([0, float2nr(&columns * a:opts.width)]), &columns])
        let height = min([max([0, float2nr(&lines * a:opts.height)]), &lines - has('nvim')])
        let row = float2nr(get(a:opts, 'yoffset', 0.5) * (&lines - height))
        let col = float2nr(get(a:opts, 'xoffset', 0.5) * (&columns - width))

        " Managing the differences
        let row = min([max([0, row]), &lines - has('nvim') - height])
        let col = min([max([0, col]), &columns - width])
        let row += !has('nvim')
        let col += !has('nvim')

        if !has_key(a:opts, 'bufnr')
            let l:bufnr = term_start(
                \ g:terman_shell,
                \ #{
                    \ term_name: g:_terman_float_name,
                    \ hidden: 1,
                    \ term_finish: 'close'
            \ })
        else
            let l:bufnr = a:opts.bufnr
        endif

        return popup_create(l:bufnr, #{
            \ line: row,
            \ col: col,
            \ minwidth: width,
            \ minheight: height,
            \ zindex: 50,
            \ border: [],
            \ borderhighlight: [a:opts.highlight],
        \ })
    endfunction


" --- Autocommands

    augroup terman
        au!

        " Track which buffer is focused for a more natural experience when toggling
        au BufEnter * call s:set_focused(s:get_key(), bufnr('%'))
        au BufDelete * call terman#close()
        au TabClosed * call terman#tab_closed()
    augroup END
