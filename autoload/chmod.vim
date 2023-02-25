let s:save_cpo = &cpo
set cpo&vim

" TODO: Accept octal formats.
function! chmod#call(...) abort
  let l:idx = index(a:000, '--')
  let l:flags =
    \   l:idx > 0 ? a:000[: l:idx - 1]
    \ : l:idx == 0 ? []
    \ : a:000
  let l:args = l:idx >= 0 ? a:000[l:idx + 1 :] : []

  let l:modes = []
  let l:files = []
  let l:verbose = 0
  let l:maybefiles = []

  let l:modefmtreg = '[ugoa]*[-+=][rwx]*'

  for l:flag in l:flags
    if l:flag =~# '^\%(-c\|--changes\)$'
      let l:verbose = 1
    elseif l:flag =~# '^\%(-v\|--verbose\)$'
      let l:verbose = 2
    elseif l:flag =~# printf('^%s\%(,%s\)*$', l:modefmtreg, l:modefmtreg)
      let l:modes = [l:flag]
      let l:files += l:maybefiles
      let l:maybefiles = [l:flag]
    else
      let l:files += [l:flag]
    endif
  endfor

  let l:files += l:args

  if empty(l:files)
    throw 'chmod#call: Missing filename.'
  endif

  let l:fields = repeat([0], 9)

  for l:mode in split(l:modes[0], ',')
    let l:opidx = match(l:mode, '[+-=]')

    let l:operator = l:mode[l:opidx]

    let l:subjects = l:opidx == 0 ? 'a' : l:mode[: l:opidx - 1]
    let l:perms = l:mode[l:opidx + 1 :]

    let l:offsets = uniq(sort(
      \   (l:subjects =~# 'u' ? [0] : [])
      \ + (l:subjects =~# 'g' ? [3] : [])
      \ + (l:subjects =~# 'o' ? [6] : [])
      \ + (l:subjects =~# 'a' ? [0, 3, 6] : [])
      \ ))

    let l:indices = (l:perms =~# 'r' ? [0] : []) + (l:perms =~# 'w' ? [1] : []) + (l:perms =~# 'x' ? [2] : [])

    if l:operator ==# '-'
      for l:i in l:indices
        for l:offset in l:offsets
          let l:fields[l:i + l:offset] = -1
        endfor
      endfor
    elseif l:operator ==# '+'
      for l:i in l:indices
        for l:offset in l:offsets
          let l:fields[l:i + l:offset] = 1
        endfor
      endfor
    elseif l:operator ==# '='
      let l:indices = l:indices

      for l:i in range(3)
        for l:offset in l:offsets
          let l:fields[l:i + l:offset] = index(l:indices, l:i) >= 0 ? 1 : -1
        endfor
      endfor
    else
      " NOTE: Unreachable.
      throw printf("chmod#call(): An unknown operator '%s'", l:operator)
    endif
  endfor

  for l:file in l:files
    let l:mode_old = getfperm(l:file)
    let l:mode_new =
      \   (l:fields[0] > 0 ? 'r' : l:fields[0] < 0 ? '-' : l:mode_old[0])
      \ . (l:fields[1] > 0 ? 'w' : l:fields[1] < 0 ? '-' : l:mode_old[1])
      \ . (l:fields[2] > 0 ? 'x' : l:fields[2] < 0 ? '-' : l:mode_old[2])
      \ . (l:fields[3] > 0 ? 'r' : l:fields[3] < 0 ? '-' : l:mode_old[3])
      \ . (l:fields[4] > 0 ? 'w' : l:fields[4] < 0 ? '-' : l:mode_old[4])
      \ . (l:fields[5] > 0 ? 'x' : l:fields[5] < 0 ? '-' : l:mode_old[5])
      \ . (l:fields[6] > 0 ? 'r' : l:fields[6] < 0 ? '-' : l:mode_old[6])
      \ . (l:fields[7] > 0 ? 'w' : l:fields[7] < 0 ? '-' : l:mode_old[7])
      \ . (l:fields[8] > 0 ? 'x' : l:fields[8] < 0 ? '-' : l:mode_old[8])
    call setfperm(l:file, l:mode_new)

    let l:octal_mode_old =
      \   (l:mode_old[0] ==# 'r' ? 400 : 0) + (l:mode_old[1] ==# 'w' ? 200 : 0) + (l:mode_old[2] ==# 'x' ? 100 : 0)
      \ + (l:mode_old[3] ==# 'r' ?  40 : 0) + (l:mode_old[4] ==# 'w' ?  20 : 0) + (l:mode_old[5] ==# 'x' ?  10 : 0)
      \ + (l:mode_old[6] ==# 'r' ?   4 : 0) + (l:mode_old[7] ==# 'w' ?   2 : 0) + (l:mode_old[8] ==# 'x' ?   1 : 0)
    let l:octal_mode_new =
      \   (l:mode_new[0] ==# 'r' ? 400 : 0) + (l:mode_new[1] ==# 'w' ? 200 : 0) + (l:mode_new[2] ==# 'x' ? 100 : 0)
      \ + (l:mode_new[3] ==# 'r' ?  40 : 0) + (l:mode_new[4] ==# 'w' ?  20 : 0) + (l:mode_new[5] ==# 'x' ?  10 : 0)
      \ + (l:mode_new[6] ==# 'r' ?   4 : 0) + (l:mode_new[7] ==# 'w' ?   2 : 0) + (l:mode_new[8] ==# 'x' ?   1 : 0)

    if l:verbose >= 2 && l:mode_old ==# l:mode_new
      echo printf("mode of '%s' retained as %d (%s)", l:file, l:octal_mode_new, l:mode_new)
    elseif l:verbose >= 1 && l:mode_old !=# l:mode_new
      echo printf("mode of '%s' changed from %d (%s) to %d (%s)", l:file, l:octal_mode_old, l:mode_old, l:octal_mode_new, l:mode_new)
    endif
  endfor
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set expandtab tabstop=2 shiftwidth=2:
