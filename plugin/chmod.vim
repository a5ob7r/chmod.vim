if exists('g:loaded_chmod')
  finish
endif

let g:loaded_chmod = 1

let s:save_cpo = &cpo
set cpo&vim

" "Chmod()" is a function similar to "chmod(1)" for "setfperm()".
function! Chmod(...) abort
  call call('chmod#call', a:000)
endfunction

" ":Chmod" is a command-line interface similar to "chmod(1)" for "setfperm()".
" :Chmod +x %
" :Chmod +x, -x %
" :Chmod +x % -- +x
" :Chmod u+x %
" :Chmod -v +x %
" :Chmod --verbose +x %
command! -bar -nargs=+ -complete=file Chmod call chmod#call(<f-args>)

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set expandtab tabstop=2 shiftwidth=2:
