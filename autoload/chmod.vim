let s:save_cpo = &cpoptions
set cpoptions&vim

" A backward compatible function version of the ">>" operator. The operator is
" introduced by "patch-8.2.5003".
function! s:rshift(bits, n) abort
  return a:n > 0 ? a:bits / float2nr(pow(2, a:n)) : a:bits
endfunction

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
" TODO: Apply dereferenced files instead of symbolic links themselve.
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

  let l:modefmtreg = '[ugoa]*[-+=]\%([rwxX]*\|[ugo]\)'

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
  let l:exitcode = 0

  for l:file in l:files
    let l:fperm = getfperm(l:file)
    let l:perms = empty(l:fperm) ? -1 : s:mode2bits(l:fperm)
    let l:results += [{
      \ 'filename': l:file,
      \ 'original': l:perms,
      \ 'expected': l:perms,
      \ 'actual': '',
      \ 'success': 0,
      \ 'isdirectory': isdirectory(l:file)
      \ }]

    if !empty(l:fperm)
      continue
    endif

    if empty(glob(l:file))
      echo printf("chmod#call(): Cannot access '%s': No such file or directory", l:file)
      let l:exitcode = l:exitcode || 1
    else
      echo printf("chmod#call(): Changing permissions of '%s': Operation not permitted", l:file)
      let l:exitcode = l:exitcode || 1
    endif
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
      if l:result['original'] < 0
        continue
      endif

      let l:bits = s:or([
        \ l:basebits,
        \ (l:perms =~# 'X' && (l:result['isdirectory'] || and(l:result['expected'], 0111))) * 1,
        \ l:perms ==# 'u' ? s:rshift(and(l:result['expected'], 0700), 6) : 0,
        \ l:perms ==# 'g' ? s:rshift(and(l:result['expected'], 0070), 3) : 0,
        \ l:perms ==# 'o' ? s:rshift(and(l:result['expected'], 0007), 0) : 0,
        \ ])
      let l:b = s:or(map(deepcopy(l:offsets), 's:lshift(l:bits, v:val)'))

      let l:result['expected'] =
        \   l:operator ==# '-' ? and(l:result['expected'], invert(and(l:result['expected'], l:b)))
        \ : l:operator ==# '+' ? or(l:result['expected'], l:b)
        \ : l:b
    endfor
  endfor

  for l:result in l:results
    if l:result['original'] < 0
      if l:verbose >= 2
        echo printf("'%s' could not be accessed", l:result['filename'])
      endif
    elseif l:result['original'] ==# l:result['expected']
      let l:result['actual'] = l:result['original']
      let l:result['success'] = 1

      if l:verbose >= 2
        echo printf("mode of '%s' retained as %04o (%s)", l:result['filename'], l:result['original'], s:bits2mode(l:result['expected']))
      endif
    else
      " A function "setfperm()" was introduced by "patch-7.4.1516".
      call setfperm(l:result['filename'], s:bits2mode(l:result['expected']))

      let l:result['actual'] = getfperm(l:result['filename'])
      let l:result['success'] = l:result['expected'] == s:mode2bits(l:result['actual'])

      if l:verbose >= 1
        echo printf("mode of '%s' changed from %04o (%s) to %04o (%s)", l:result['filename'], l:result['original'], s:bits2mode(l:result['original']), l:result['actual'], s:bits2mode(l:result['actual']))
      endif
    endif

    let l:result['original'] = l:result['original'] < 0 ? '' : s:bits2mode(l:result['original'])
    let l:result['expected'] = l:result['expected'] < 0 ? '' : s:bits2mode(l:result['expected'])

    let l:exitcode = l:exitcode || !l:result['success']
  endfor

  return { 'exitcode': l:exitcode, 'results': l:results }
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: set expandtab tabstop=2 shiftwidth=2:
