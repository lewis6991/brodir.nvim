brodir.vim
===========

Path navigator designed to work with Vim's built-in mechanisms and
[complementary](https://github.com/tpope/vim-eunuch)
[plugins](https://github.com/tpope/vim-unimpaired).

![image](https://user-images.githubusercontent.com/7904185/174033682-84ec8f72-76f8-4c49-b307-3e781755837d.png)

Premise
-------

I've been using [vim-dirvish](https://github.com/justinmk/vim-dirvish)
for many years now and have been slowly customising it as Neovim has
evolved and gained new features: floating windows, advanced decorations, etc.

It is now customised so much that it is no longer the same plugin and the
feature set is quite different.
The main difference being that it has been completely ported to Lua and relies
on heavy use of the Neovim API with minimal use of `vim.cmd`.
Any feature that heavily relied on Ex commands has been removed, which is
mostly Sudo and Arglist related features.

**Note**: I use this plugin personally and don't currently aim to support it
for wider public use.
Issues probably won't be actioned but PR's are always welcome.


Features
--------

- Each line is just a filepath
- Never modifies the filesystem
- Uses floating windows
- Highlight open buffers in directory listing
- Git status decorations
- Icons

Concepts
--------

### Lines are filepaths

Each Brodir buffer contains only filepaths, hidden by [conceal](https://neovim.io/doc/user/syntax.html#conceal).

- Use plain old `y` to yank a path, then feed it to `:r` or `:e` or whatever.
- Sort with `:sort`, filter with `:global`. ~Hit `R` to reload.~
- `:set ft=brodir` on any buffer to enable Brodir features:
  ```
  git ls-files | vim +'setf brodir' -
  ```

Credits
-------

Fork of [vim-dirvish](https://github.com/justinmk/vim-dirvish) by Justin M. Keyes
which in turn was originally forked (and completely rewritten) from
[filebeagle](https://github.com/jeetsukumaran/vim-filebeagle) by Jeet Sukumaran.
