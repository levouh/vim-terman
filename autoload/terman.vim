" Variables {{{1

const s:KEY = "terman_key"
const s:ROOT = "bot"
const s:VERTICAL = "vert"
const s:HORIZONTAL = ""

" TerminalSet {{{1
    " Global {{{2
    "
    " This is necessary so that the 'type' is defined
    let s:TerminalSetObject = {}

    fu! s:TerminalSetObject.new(key) " {{{2
        " Create a new "TermanalSet" object and initialize
        " it's instance variables.
        let new = copy(self)
        let new.info = []
        let new.info_dict = {}
        let new.maximized = v:none

        " The "key" for any terminal set is the tab that it is associated
        " with. Based on settings, it could be associated with a single
        " tab or multiple.
        "
        " Because we are keying into a dictionary, in the case that the
        " "g:terman_per_tab" setting is off, the key returned will always
        " be the static "s:KEY".
        let new.key = a:key

        return new
    endfu

    fu! s:TerminalSetObject.get_tabnr() " {{{2
        if get(g:, 'terman_per_tab', 1)
            " In the case that this option is set, the value of "self.key"
            " will be a terman-defined tab 'ID', so we need to get the
            " Vim-defined tab number from it
            return s:get_tabnr(self.key)
        endif

        " In the opposite case the setting is off, so we just want the
        " current tab number.
        return tabpagenr()
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

    fu! s:TerminalSetObject.close_terminal(bufnr)dict " {{{2
        " This function is called from a callback setup when a terminal
        " buffer is created.
        "
        " See the "TerminalSetObject.create_terminal" for more details.
        "
        " A local alias.
        let bufnr = a:bufnr

        " Get the information about the buffer being closed
        if !has_key(self.info_dict, bufnr)
            " The buffer isn't tracked but somehow this callback was
            " called, not sure why this would happen but we need to quit early
            return
        endif

        " It exists, grab the information
        "
        " NOTE: This is a dictionary.
        let deleting = self.info_dict[bufnr]

        " The last child will replace the buffer being deleted, so get the
        " last child entry if it exists, else assign it "v:none".
        "
        " NOTE: This is a dictionary.
        let last_child = len(deleting.children) ? deleting.children[-1] : v:none

        " When a buffer is to be deleted from the list, all buffers
        " who have this buffer as a parent will need to have their
        " parent updated.
        "
        " In order to find the new parent, we need to find the "last child"
        " of the buffer being closed. When going through a few examples,
        " it becomes apparent that this is the case.
        "
        " Keep track of the index as we iterate the list, this makes
        " removing items later easier
        let idx = 0

        "        ┌ the buffer being removed
        "        │
        let [deleting_idx, replacement_idx] = [v:none, v:none]
        "                   │
        "                   └ the buffer replaceing the one being removed

        " Update the parents of the replacement buffer, and any buffer that
        " had the buffer being deleted as a parent.
        "
        " Additionally, track the index of the buffer being deleted and it's
        " replacement to avoid extra loop iterations later.
        for buf_info in self.info
            if buf_info.bufnr == deleting.bufnr
                " This is the index of the buffer that is being deleted
                let deleting_idx = idx
            endif

            "  ┌ the buffer may have no children, so there is nothing
            "  │ to replace
            "  │
            "  ├──────────────────────┐
            if last_child isnot# v:none
                if buf_info.bufnr == last_child.bufnr
                    " Inherit the parent of the buffer being deleted, as this
                    " buffer is effectively replacing it
                    let self.info_dict[last_child.bufnr].parent = deleting.parent

                    let replacement_idx = idx
                elseif buf_info.parent == deleting.bufnr
                    " Update any buffer that had a parent of the buffer being deleted
                    " to now have a parent of the buffer replacing it
                    let buf_info.parent = last_child.bufnr
                endif
            endif

            let idx += 1
        endfor

        " TODO: Are all of these done?
        "   - Looping over "deleting.children" does not provide
        "     an easy way to determine the index of the entry that
        "     is being deleted.
        "   - Grab the 'last child' by looking at the length of
        "     "deleting.children", otherwise set it to "v:none".
        "   - Loop over "self.info" instead, and look for the number
        "     of the buffer being deleted.
        return

        "  ┌ This case is important beceause we could be deleting a buffer
        "  │ that has no children, so there is nothing to update
        "  │
        "  ├───────────────────────────────────────────────────────────┐
        if replacement_bufnr isnot# v:none && bufexists(replacement_bufnr)
            if replacement_bufnr == root.bufnr
                " This is the new root buffer, as the root is being replaced
                let self.info_dict[replacement_bufnr].orientation = s:ROOT
            else
                " Otherwise inherit the orientation from the buffer being
                " deleted
                let self.info_dict[replacement_bufnr].orientation = deleting.orientation
            endif

            " Replace the buffer being deleted with the one replacing it
            "
            "                                      ┌ key into dictionary
            "                                      │
            let self.info[deleting_idx] = self.info_dict[replacement_bufnr]
            "         │
            "         └ index into a list

            " Remove from the dictionary as well
            unlet self.info_dict[deleting.bufnr]

            " At this point, the replacement has already been moved to where
            " the deleted buffer was, so there are two copies of it in the list.
            "
            " The one that should be deleted is the 'older' one at the replacement
            " index
            unlet self.info[replacement_idx]
        endif

        " TODO: Need a timer here maybe to remove this "TerminalSetObject"?
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
        if orientation == s:ROOT
            " In the case that a fresh buffer is created, the parent doesn't
            " matter, so we will just make it a distinguishable value.
            "
            " See "self.close_terminal" for the use case of this.
            let parent = v:none
        else
            let parent = bufnr()
        endif

        " The "vertical" arguments to ":h term_start()" mention that they can provide
        " other orientations, but they don't seem to work. Instead, just create the
        " split ourselves and then pass "curwin" to the function call.
        exe orientation .. " new"

        " Notice that the callback is not part of this "TerminalSet" object,
        " because Vim will not handle these "dict" function calls correctly.
        "
        " To get around this, we will call a generic script-local function
        " as part of the callback, and then we will access the "b:_terman_buf"
        " variable to determine the "self.id" field to get the correct
        " "TerminalSet" object and call it accordingly.
        let bufnr = term_start(
            \ &shell,
            \ #{
                \ exit_cb: function('s:terminal_closed_callback'),
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
            \ orientation: a:orientation,
            \ children: []
        \ }

        if a:parent isnot# v:none
            " Keep track of the parent/child relationship in the parent as well.
            "
            " This is important information to track for when buffers are being
            " deleted via the callback setup in the call to ":h term_start()"
            call self.add_child(a:parent, a:bufnr)
        endif

        " Store it in a list for easy iteration, this also helps when
        " recreating the order in which the terminal set was opened
        " in the first place
        call add(self.info, term_info)

        " Also store this information in a dictionary, this will help
        " with quick access and help get rid of some list iterations
        let self.info_dict[a:bufnr] = term_info

        " Mark the buffer as being a "terman buffer", as a lot of the
        " operations performed should not be performed on non-terman
        " buffers
        let b:_terman_buf = self.key

        echom 'DEBUG TermanObject.add_terminal: added terminal'
        echom self.info
    endfu

    fu! s:TerminalSetObject.add_child(parent, child) " {{{2
        " Track the child of a buffer.
        "
        " Children are tracked in order, and each buffer will
        " use this information to keep track of its own children.
        call add(self.info_dict[a:parent].children, a:child)

        echom 'DEBUG TermanObject.add_child: added child, parent=' .. a:parent .. ', child=' .. a:child
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
        return s:KEY
    else
        if !exists('t:_terman_tab_id')
            " Vim assigns each tab it's own tab number, but this
            " is more-so an index than an identifier for a tab.
            " For instance, if two tabs are open:
            "   a, b
            " tab 'a' will have number 1, and tab 'b' will have number
            " 2, as expected. But if we are focused on tab 'a' and open
            " a new tab:
            "   a, c, b
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

fu! s:terminal_closed_callback(...) " {{{1
    " This function is called as a callback whenever
    " a terman buffer is closed. For more details on why
    " this is used, meaning not part of the "TerminalSet"
    " object, see the "TerminalSetObject.create_terminal"
    " function.
    let bufnr = bufnr()

    " The set "key" is stored in a buffer-local variable.
    let key = getbufvar(bufnr, '_terman_buf')

    " If we can't get the value of this variable, there
    " is nothing we can do.
    if !empty(key)
        call s:terman.get_set(key).close_terminal(bufnr)
    endif
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

" Test {{{1
    " 1. Test closing the root buffer
    " 2. Open and close a bunch of stuff
