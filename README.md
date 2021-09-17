Fork of justinmk/vim-dirvish

Changes:
- Ported to Lua
- Vim compat removed
- Windows compat removed
- Defaults to using Neovim floating windows
- Icon handlers removed
- Shdo removed

WIP

dirvish.vim :zap:
=================

Path navigator designed to work with Vim's built-in mechanisms and
[complementary](https://github.com/tpope/vim-eunuch)
[plugins](https://github.com/tpope/vim-unimpaired).

Features
--------

- _Simple:_ Each line is just a filepath
- _Flexible:_ Mash up the buffer with `:g`, automate it with `g:dirvish_mode`
- _Safe:_ Never modifies the filesystem
- _Intuitive:_ Visual selection opens multiple files
- _Reliable:_ Less code, fewer bugs (96% smaller than netrw).

Concepts
--------

### Lines are filepaths

Each Dirvish buffer contains only filepaths, hidden by [conceal](https://neovim.io/doc/user/syntax.html#conceal).

- Use plain old `y` to yank a path, then feed it to `:r` or `:e` or whatever.
- Sort with `:sort`, filter with `:global`. Hit `R` to reload.
- `:set ft=dirvish` on any buffer to enable Dirvish features:
  ```
  git ls-files | vim +'setf dirvish' -
  ```

### Buffer name is the directory name

So commands and plugins that work with `@%` and `@#` do the Right Thing.

- Create directories:
  ```
  :!mkdir %foo
  ```
- Create files:
  ```
  :e %foo.txt
  ```

### Edit Dirvish buffers

For any purpose. It's safe and reversible.

- Use `:sort` or `:global` to re-arrange the view, delete lines with `d`, etc.
- Pipe to `:!` to see inline results:
  ```
  :'<,'>!xargs du -hs
  ```


Credits
-------

Dirvish was originally forked (and completely rewritten) from
[filebeagle](https://github.com/jeetsukumaran/vim-filebeagle) by Jeet Sukumaran.

Copyright 2015 Justin M. Keyes.
