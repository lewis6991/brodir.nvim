brodir.vim
===========

Path navigator designed to work with Vim's built-in mechanisms and
[complementary](https://github.com/tpope/vim-eunuch)
[plugins](https://github.com/tpope/vim-unimpaired).

![image](https://user-images.githubusercontent.com/7904185/174033682-84ec8f72-76f8-4c49-b307-3e781755837d.png)


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
