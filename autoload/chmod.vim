let s:save_cpo = &cpo
set cpo&vim

" A backward compatible function version of the "<<" operator. The operator is
" introduced by "patch-8.2.5003".
function! s:lshift(bits, n) abort
  return a:n > 0 ? a:bits * float2nr(pow(2, a:n)) : a:bits
endfunction

" Return all bitwise OR of elements.
function! s:or(list) abort
  return s:auxor(a:list, 0)
endfunction

" An auxiliary function for "s:or()".
function! s:auxor(list, acc) abort
  return empty(a:list) ? a:acc : s:auxor(a:list[1:], or(a:acc, a:list[0]))
endfunction

function! s:mode2bits(mode) abort
  return
    \   (a:mode[0] ==# '-' ? 0 : 0400)
    \ + (a:mode[1] ==# '-' ? 0 : 0200)
    \ + (a:mode[2] ==# '-' ? 0 : 0100)
    \ + (a:mode[3] ==# '-' ? 0 : 0040)
    \ + (a:mode[4] ==# '-' ? 0 : 0020)
    \ + (a:mode[5] ==# '-' ? 0 : 0010)
    \ + (a:mode[6] ==# '-' ? 0 : 0004)
    \ + (a:mode[7] ==# '-' ? 0 : 0002)
    \ + (a:mode[8] ==# '-' ? 0 : 0001)
endfunction

function! s:bits2mode(bits) abort
  return
    \   (and(a:bits, 0400) ? 'r' : '-')
    \ . (and(a:bits, 0200) ? 'w' : '-')
    \ . (and(a:bits, 0100) ? 'x' : '-')
    \ . (and(a:bits, 0040) ? 'r' : '-')
    \ . (and(a:bits, 0020) ? 'w' : '-')
    \ . (and(a:bits, 0010) ? 'x' : '-')
    \ . (and(a:bits, 0004) ? 'r' : '-')
    \ . (and(a:bits, 0002) ? 'w' : '-')
    \ . (and(a:bits, 0001) ? 'x' : '-')
endfunction

" TODO: Accept octal formats.
" TODO: Add "ugo" as valid letters to refer the permissions of classes.
" TODO: Apply dereferenced files instead of symbolic links themselve.
" TODO: Return objects to indicate the invocation results.
" TODO: Add some extra options impletemnted by GNU coreutils chmod.
" TODO: Improve compatibility with GNU coreutils chmod's argument parsing.
function! chmod#call(...) abort
  let l:end_of_options_idx = index(a:000, '--')
  let l:flags =
    \   l:end_of_options_idx > 0 ? a:000[: l:end_of_options_idx - 1]
    \ : l:end_of_options_idx == 0 ? []
    \ : a:000
  let l:operands = l:end_of_options_idx >= 0 ? a:000[l:end_of_options_idx + 1 :] : []

  let l:modes = []
  let l:files = []
  let l:verbose = 0
  let l:maybefiles = []

  let l:modefmtreg = '[ugoa]*[-+=][rwxX]*'

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

  let l:files += l:operands

  if empty(l:modes)
    throw 'chmod#call: Missing modespec.'
  endif

  if empty(l:files)
    throw 'chmod#call: Missing filename.'
  endif

  let l:results = []

  for l:file in l:files
    let l:perms = s:mode2bits(getfperm(l:file))
    let l:results += [{
      \ 'filename': l:file,
      \ 'oldperms': l:perms,
      \ 'newperms': l:perms,
      \ 'success': 0,
      \ 'isdirectory': isdirectory(l:file)
      \ }]
  endfor

  for l:mode in split(l:modes[0], ',')
    let l:opidx = match(l:mode, '[+-=]')

    if l:opidx < 0
      throw 'chmod#call(): Missing valid operator.'
    endif

    let l:operator = l:mode[l:opidx]

    let l:subjects = l:opidx == 0 ? 'a' : l:mode[: l:opidx - 1]
    let l:perms = l:mode[l:opidx + 1 :]

    let l:offsets = uniq(sort(
      \   (l:subjects =~# 'u' ? [6] : [])
      \ + (l:subjects =~# 'g' ? [3] : [])
      \ + (l:subjects =~# 'o' ? [0] : [])
      \ + (l:subjects =~# 'a' ? [0, 3, 6] : [])
      \ ))

    let l:basebits = (l:perms =~# 'r') * 4 + (l:perms =~# 'w') * 2 + (l:perms =~# 'x') * 1

    for l:result in l:results
      let l:bits = or(l:basebits, (l:perms =~# 'X' && (l:result['isdirectory'] || and(l:result['newperms'], 0111))) * 1)
      let l:b = s:or(map(deepcopy(l:offsets), 's:lshift(l:bits, v:val)'))

      let l:result['newperms'] =
        \   l:operator ==# '-' ? and(l:result['newperms'], invert(and(l:result['newperms'], l:b)))
        \ : l:operator ==# '+' ? or(l:result['newperms'], l:b)
        \ : l:b
    endfor
  endfor

  for l:result in l:results
    if l:result['oldperms'] ==# l:result['newperms']
      if l:verbose >= 2
        echo printf("mode of '%s' retained as %04o (%s)", l:result['filename'], l:result['oldperms'], s:bits2mode(l:result['newperms']))
      endif
    else
      " A function "setfperm()" was introduced by "patch-7.4.1516".
      call setfperm(l:result['filename'], s:bits2mode(l:result['newperms']))

      if l:verbose >= 1
        echo printf("mode of '%s' changed from %04o (%s) to %04o (%s)", l:result['filename'], l:result['oldperms'], s:bits2mode(l:result['oldperms']), l:result['newperms'], s:bits2mode(l:result['newperms']))
      endif
    endif
  endfor
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set expandtab tabstop=2 shiftwidth=2:
