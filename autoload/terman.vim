" Variables {{{1

const s:ROOT = "bot"
const s:VERTICAL = "vert"
const s:HORIZONTAL = ""

" TerminalSet {{{1
    " Global {{{2
    "
    " This is necessary so that the 'type' is defined
    let s:TerminalSetObject = {}

    fu! s:TerminalSetObject.new(id) " {{{2
        " Create a new "TermanalSet" object and initialize
        " it's instance variables.
        let new = copy(self)
        let new.info = []
        let new.maximized = v:none

        " The "ID" for any terminal set is the tab that it is associated
        " with. Based on settings, it could be associated with a single
        " tab or multiple, so access to this variable should always be
        " done through the function "get_id()".
        let new.id = a:id

        return new
    endfu

    fu! s:TerminalSetObject.get_id() " {{{2
        " Determine whether or not this terminal set has a buffer that
        " has been explicitly maximized by the user.
        if get(g:, 'terman_per_tab', 1)
            return self.id
        else
            return tabpagenr()
        endif
    endfu

    fu! s:TerminalSetObject.get_tabnr() " {{{2
        if get(g:, 'terman_per_tab', 1)
            " In the case that this option is set, the value of "self.get_id()"
            " will be a terman-defined tab 'ID', so we need to get the
            " Vim-defined tab number from it
            return s:get_tabnr(self.get_id())
        endif

        " In the opposite case, the value of "self.get_id()" is already
        " a Vim-defined tab number
        return self.get_id()
    endfu

    fu! s:TerminalSetObject.is_empty() " {{{2
        " Determine if this "TerminalSetObject" object is currently
        " tracking any buffers or not. Will return "v:true"
        " in the case that it _is_ empty, and "v:false"
        " otherwise.
        if empty(self.info)
            return v:true
        endif

        return v:false
    endfu

    fu! s:TerminalSetObject.is_visible() " {{{2
        " Determine whether or not a this terminal set is visible.
        "
        " This has to be done programatically by checking what is visible,
        " because the user could do something like "wincmd o" on a non-terminal
        " buffer.
        if self.is_empty()
            return v:false
        endif

        if self.maximized isnot# v:none
            " There is a maximized buffer, so the visibility check
            " should only involve this buffer as it is the only
            " one that _could_ be visible
            return bufwinid(self.maximized) == -1
        endif

        " In the other case, if nothing has been maximized we have
        " to look at each buffer as the user could hide buffers manually,
        " otherwise something like:
        "   bufwinid(self.info[0].bufnr) == -1
        " would work just fine.
        for buf_info in self.info
            if bufwinid(buf_info.bufnr) != -1
                return v:true
            endif
        endfor

        return v:false
    endfu

    fu! s:TerminalSetObject.is_maximized() " {{{2
        " Determine whether or not this terminal set has a buffer that
        " has been explicitly maximized by the user.
        if self.is_empty()
            return v:false
        endif
    endfu

    fu! s:TerminalSetObject.create_terminal(...) " {{{2
        " Create a new terminal buffer based on the passed arguments.
        "
        " There are a few caveats, the first being that a new Terman-managed
        " terminal buffer can only be created from an existing one. Next,
        " if none exist, one will be created in the globally configured
        " position.
        "
        " This case happens when the terminal set is empty, but that check
        " must be determined by the caller before calling this function.
        " The function "self.is_empty" is provided for that check.
        let orientation = s:ROOT

        if a:0
            " Only need to perform this check in the case that we are not
            " starting a completely new terminal set.
            if empty(getbufvar(bufnr(), '_terman_buf'))
                " It isn't a terman buffer or the root, so we shouldn't
                " allow a new split to be opened.
                echoerr "ERROR: Can only open a new terman-terminal buffer from an existing one"

                return
            endif

            " When an argument is passed, this will not create a _new_
            " terminal window, but instead use the argument as the orientation
            " to create a new one.
            let orientation = a:1
        endif

        echom 'DEBUG TermanObject.create_terminal: orientation=' .. orientation

        " Before we open a new split, we need to know what buffer we are starting
        " from as this denotes the "parent" of the buffer being created
        let parent = bufnr()

        " The "vertical" arguments to ":h term_start()" mention that they can provide
        " other orientations, but they don't seem to work. Instead, just create the
        " split ourselves and then pass "curwin" to the function call.
        exe orientation .. " new"

        let bufnr = term_start(
            \ &shell,
            \ #{
                \ term_finish: 'close',
                \ term_name: 'terman',
                \ curwin: v:true,
                \ hidden: 0
            \ }
        \ )

        if bufnr != 0
            " 0 will be returned if opening the "terminal" buffer failed,
            " see ":h term_start()" for more informatio.
            call self.add_terminal(bufnr, orientation, parent)
        endif
    endfu

    fu! s:TerminalSetObject.add_terminal(bufnr, orientation, parent) " {{{2
        " Track a newly created terminal buffer.

        " When a completely new terminal buffer is created, it
        " will be created at the "s:ROOT" position in the current
        " window. This means that it is the root of a new set.
        "
        " Otherwise, just store the passed orientation. This will
        " be one of:
        "   "s:VERTICAL" or "s:HORIZONTAL"
        " which each denote a 'child' window rather than a root.
        let term_info = #{
            \ bufnr: a:bufnr,
            \ parent: a:parent,
            \ orientation: a:orientation
        \ }

        call add(self.info, term_info)
        let b:_terman_buf = v:true

        echom 'DEBUG TermanObject.add_terminal: added terminal'
        echom self.info
    endfu

    fu! s:TerminalSetObject.safe_to_hide() " {{{2
        " Determine whether or not it is safe to hide all
        " the buffers in the set.
        "
        " This function is necessary due to the fact that Vim
        " won't allow the last buffer in a tab to be hidden.

        " Count how many of the buffers are terman buffers
        let terman_count = 0

        "                               ┌ this is a Vim-defined tab number
        "                               │
        for buf in tabpagebuflist(self.get_tabnr())
            if !empty(getbufvar(buf, '_terman_buf'))
                let terman_count += 1
            endif
        endfor

        echom 'DEBUG TermanObject.safe_to_hide: count=' .. terman_count

        return terman_count != 0
    endfu

    fu! s:TerminalSetObject.hide(...) " {{{2
        " Hide this terminal set.
        "
        " If arguments are passed, window IDs in that list
        " will be skipped.
        "
        " NOTE: This function will assume that checks have already
        "       been made to it is visible or not.
        let skip = a:0 ? a:1 : []

        echom 'DEBUG TermanObject.hide: called'

        call self.hide_helper(skip)
    endfu

    fu! s:TerminalSetObject.hide_helper(winids_to_skip) " {{{2
        " Iterate over and hide all buffers within this terminal set,
        " those residing in a window passed in the list argument will
        " not be hidden.
        let safe = self.safe_to_hide()

        echom 'DEBUG TermanObject.hide_helper: safe=' .. safe

        " Whether or not the new split was already created to handle
        " errors when trying to hide the last buffer in a tab
        let created = v:false

        for buf_info in self.info
            let winids = win_findbuf(buf_info.bufnr)
            "            ├─────────────────────────┘
            "            │
            "            │ will be a list of all windows where the buffer is found,
            "            └ which in most cases should just be a single entry

            for winid in winids
                " Used when fullscreening a buffer, hide all except the 'fullscreened' one
                if len(a:winids_to_skip) && index(a:winids_to_skip, l:winid) >= 0
                    continue
                endif

                " Go to the window before checking
                call win_gotoid(winid)

                " When trying to hide buffers, errors will be thrown
                " if hiding to hide the last visible buffer in a particular
                " tab. In the case that there are only "terman" buffers left
                " in a particular tab, we will need to make a new split so
                " that they can all be hidden.
                if !safe && !created
                    " Create a new split to prevent errors
                    top new

                    " When we run the above command, the focus will change to
                    " the newly created split, so at this point the focus needs
                    " to go back the buffer that is being hidden
                    call win_gotoid(winid)

                    " Only do this once
                    let created = v:true
                endif

                hide
            endfor
        endfor
    endfu

    fu! s:TerminalSetObject.show() " {{{2
        " Show this terminal set.
        "
        " This method can be a bit tricky because of the way we need
        " to re-open the splits in the same order that they were
        " originally opened.

        " If there is a maximized buffer, that is the only
        " one that we need to show.
        if self.maximized isnot# v:none
            let root = self.maximized
        else
            " Indexing without checking would normally be bad, but at
            " this point "self.is_empty()" has already been called by
            " the using "Terman" instance
            let root = self.info[0].bufnr
        endif

        echom 'DEBUG TermanObject.show: root=' .. root

        " Open the root buffer in the configured position
        silent exe s:ROOT .. ' sbuffer ' .. root

        " The buffer that has already been opened needs to be skipped,
        " the other option is to use a while loop but then that leaves
        " us having to keep track of additional variables as we iterate
        let skipped = v:false

        for buf_info in self.info
            if !skipped
                " Need to skip the "root" that has already been opened
                let skipped = v:true

                continue
            endif

            " Go to the parent and open the child in the right
            " orientation according to how it was setup
            silent exe bufwinnr(buf_info.parent) .. 'wincmd w'
            silent exe buf_info.orientation .. ' sbuffer ' .. buf_info.bufnr
        endfor
    endfu

" Terman {{{1
    " Global {{{2
    "
    " This is necessary so that the 'type' is defined
    let s:TermanObject = {}

    fu! s:TermanObject.new() " {{{2
        " Create a new "Terman" object and initialize
        " it's instance variables.
        let new = copy(self)
        let new.set = {}

        return new
    endfu

    fu! s:TermanObject.get_set(key) " {{{2
        " Get the terminal set for the passed key.
        "
        " When a function is decorated with the 'dict'
        " keyword, it essentially acts as part of a class
        " in that an object can have an first-class function
        " object that can be called like:
        "   s:object.function()
        "
        " Use ":h get()" to allow a default to be returned
        if has_key(self.set, a:key)
            return self.set[a:key]
        else
            " Pass the key as the tabid so that the terminal set is
            " aware of what tab it is associated with.
            let self.set[a:key] = s:TerminalSetObject.new(a:key)

            return self.set[a:key]
        endif
    endfu

    fu! s:TermanObject.toggle(key) " {{{2
        " Toggle the visibility of the terminal set defined
        " by the passed key.
        "
        " Hide it if it is visble (or visible in another tab
        " based on settings), or show it by the same metric.
        let term_set = self.get_set(a:key)

        if term_set.is_empty()
            " Passing no arguments will result in the "terminal"
            " buffer to be created at the bottom of the screen
            call term_set.create_terminal()
        else
            if term_set.is_visible()
                echom 'DEBUG TermanObject.toggle: visible, hiding'
                call term_set.hide()
            else
                echom 'DEBUG TermanObject.toggle: not visible, showing'
                call term_set.show()
            endif
        endif
    endfu

    fu! s:TermanObject.create_terminal_in_set(key, orientation) " {{{2
        " Direct to the correcet "TerminalSet" and have it create a new
        " "terminal" buffer in the correct orientation
        let term_set = self.get_set(a:key)

        if term_set.is_empty()
            echom 'DEBUG TermanObject.create_terminal_in_set: empty'

            " Nothing exists yet, so call the following function without
            " arguments to ensure that a new buffer is created.
            call term_set.create_terminal()
        else
            echom 'DEBUG TermanObject.create_terminal_in_set: not empty, orientation=' .. a:orientation

            " If we pass arguments, the orientation will be used. At this
            " point we know the terminal set is _not_ empty so it is safe
            " to add the orientation here.
            call term_set.create_terminal(a:orientation)
        endif
    endfu

    " Instance {{{2
    let s:terman = s:TermanObject.new()


fu! s:get_key() " {{{1
    " Get the accessor key to use based on global settings
    "
    " This is the key that will be used within the global
    " "s:terman" object's "set" variable to find the set of buffers
    " that are being dealt with. This changes based on the
    " current tab, and if terminal buffer sets are distinct
    " between tabs or not, etc.
    if get(g:, 'terman_per_tab', 1)
        return g:_terman_key
    else
        if !exists('t:_terman_tab_id')
            " Vim assigns each tab it's own tab number, but this
            " is more-so an index than an identifier for a tab.
            " For instance, if two tabs are open:
            "   a, b
            " tab 'a' will have number 1, and tab 'b' will have number
            " 2, as expected. But if we are focused on tab 'a' and open
            " a new tab:
            " a, c, b
            " then tab 'a' will be number 1, and tab 'c' will be number 2.
            " Because of this we can't index based on ":h tabpagenr()", so
            " just use/update our own sequence.
            let t:_terman_tab_id = g:_terman_tab_id
            let g:_terman_tab_id += 1
        endif

        return t:_terman_tab_id
    endif
endfu

fu! s:get_tabnr(tabid) " {{{1
    " Get the Vim-defined tab number from a given
    " terman-defined tab 'ID'
    for tabnr in range(1, tabpagenr('$'))
        let tabid = gettabvar(tabnr, '_terman_tab_id', v:none)

        if tabid isnot# v:none && tabid == a:tabid
            return l:tabnr
        endif
    endfor

    return v:none
endfunction

fu! terman#toggle() " {{{1
    " Public interface to create a new terminal buffer for
    " the current terminal set
    let key = s:get_key()

    call s:terman.toggle(key)
endfu

fu! terman#new(vertical) " {{{1
    " Public interface to toggle a terminal set, simple
    " call the Terman object and let it do the work
    let key = s:get_key()
    let orientation = a:vertical ? s:VERTICAL : s:HORIZONTAL
    echom "DEBUG terman#new: orientation=" .. orientation

    call s:terman.create_terminal_in_set(key, orientation)
endfu
