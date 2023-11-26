# leap-spooky.nvim 👻

Spooky is a [Leap](https://github.com/ggandor/leap.nvim) extension that allows
for remote operations on Vim's native text objects: that is, it exposes atomic
bundles of (virtual or actual) leaping motions and text object selections.

![showcase](../media/showcase.gif?raw=true)

AFAIK, the basic idea first appeared in
[vim-seek](https://github.com/goldfeld/vim-seek), one of
[vim-sneak](https://github.com/justinmk/vim-sneak)'s predecessors. (The feature
is coincidentally called "leaping motions" there, no kidding.)

It's not just the number of keystrokes that matter here, but the potentially
more intuitive workflow achieved through these higher abstractions, that are
nevertheless obvious extensions of Vim's grammar. As usual, the aim is to
sharpen the saw; there are no big list of new commands to learn, except for two
affixes that can be added to all existing text objects. `carb[leap]` ("change
around remote block [marked by leap motion]") in no time will be just as
natural as [targets.vim](https://github.com/wellle/targets.vim)'s `canb`
("change around next block").

## Usage

Leap is automatically invoked once the text object is specified; after e.g.
`yarw`, start typing the 2-character search pattern, and select the target as
you would usually do. The difference is that instead of jumping there, the word
will be yanked.

## What are some fun things you can do with this?

- Delete/fold/comment/etc. paragraphs without leaving your position
  (`zfarp[leap]`).
- Clone text objects in the blink of an eye, even from another window, by
  turning on `paste_on_remote_yank` (`yaRp[leap]`).
- Do the above stunt in Insert mode (`...<C-o>yaRW[leap]...`).
- Fix a typo with a short, atomic command sequence (`cimw[leap][correction]`).
- Operate on distant lines: `drr[leap]`.
- Use `count`: e.g. `y3rr[leap]` yanks 3 lines, just as `3yy` would do.

## Status

WIP - everything is experimental at the moment.

## Requirements

* [leap.nvim](https://github.com/ggandor/leap.nvim)

## Setup

`setup` creates all the necessary mappings - you can call it without arguments,
if the defaults are okay:

```lua
require('leap-spooky').setup {
  -- Additional text objects, to be merged with the default ones.
  -- E.g.: {'iq', 'aq'}
  extra_text_objects = nil
  -- Mappings will be generated corresponding to all native text objects,
  -- like: (ir|ar|iR|aR|im|am|iM|aM){obj}.
  -- Special line objects will also be added, by repeating the affixes.
  -- E.g. `yrr<leap>` and `ymm<leap>` will yank a line in the current
  -- window.
  affixes = {
    -- The cursor moves to the targeted object, and stays there.
    magnetic = { window = 'm', cross_window = 'M' },
    -- The operation is executed seemingly remotely (the cursor boomerangs
    -- back afterwards).
    remote = { window = 'r', cross_window = 'R' },
  },
  -- Defines text objects like `riw`, `raw`, etc., instead of
  -- targets.vim-style `irw`, `arw`. (Note: prefix is forced if a custom
  -- text object does not start with "a" or "i".)
  prefix = false,
  -- The yanked text will automatically be pasted at the cursor position
  -- if the unnamed register is in use.
  paste_on_remote_yank = false,
}
```

## Customisation

Note: This is absolutely not stable API, just a current snapshot for people who
would like to experiment.

`spooky_action` returns a one-argument function that can be used as `leap`'s
`action` parameter. That is, you have to call it when used in a mapping.

The signature looks like: `spooky_action(select_cmd, {opts})`

- `select_cmd`: a function returning a string to be passed to `:normal` (by
  default, the expected action is a text object selection, like `viw`)
- `opts.on_exit`: like `select_cmd`, but the command is be executed after the
  operation has been finished
- `opts.keeppos`: if true, execute the action remotely (jump back afterwards)

Example:

```lua
require('leap').leap {
  target_windows = { vim.fn.win_getid() }
  action = require('leap-spooky').spooky_action(
    function () return "viw" end,
    { keeppos = true, on_exit = (vim.v.operator == 'y') and 'p', },
  ),
}
```

You can also check the source code for ideas, or if something is unclear.

## Planned features

- It would be awesome to restrict the search area to the given text objects.
  E.g. `cr]` would only give matches inside square brackets. This could often
  add a huge speed boost and reduce the visual noise a lot. We could even
  highlight the active areas.

- Label the text objects themselves (at least blocks, paragraphs, etc.), so that
  you can immediately choose one, instead of having to specify the reference
  point with a default 2-char Leap motion.
