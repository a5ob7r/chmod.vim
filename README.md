# chmod.vim

This plugin provides the `:Chmod` command and the `Chmod()` function.
The two of them are interfaces of `setfperm()` and allow to specify filemodes using formats of `chmod(1)`, especially `chmod` of GNU Coreutils.

```vim
:Chmod +x %
```

## Requirements

- Vim 7.4.1516+

## Why?

Vim has a function, `setfperm()`, to modify file permissions, but we've to specify the new file permissions by a string with 9 characters such as `'rwxrwxrwx'` or `'rwx-w---x'`.
Such a format is human-raedable, but this is bothering us when we want to specify file permissions.

Please imagine such a situation that you're writing a script and want to make it executable.
So you need to set executable bits for some classes (owner, group, others, or all?).
What will you do to do that?
Do you use `setfperm()`?
That function can set specific file permissions, but can't set bits based on the current file permission.
This means that you've to get the current file permissions, set executable bits to them, and call `setfperm()` with the new file permission.

However, a UNIX command `chmod(1)` can do it easily using such a format `a+x`.
Of course I know we can call external commands such as it from Vim using `:!{cmd}`, but I want such an UX and interface on Vim's cmdline.

This is a very very personal request, maybe anyone doesn't want it, but just I want it.

In conclusion, this is juat my hobby!

## Test

This plugin is tested using [themis.vim](https://github.com/thinca/vim-themis).

```sh
git clone https://github.com/thinca/vim-themis.git

./vim-themis/bin/themis test/chmod.vimspec
```
