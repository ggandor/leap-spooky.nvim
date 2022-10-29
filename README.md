# leap-spooky.nvim 👻

Spooky is a [Leap](https://github.com/ggandor/leap.nvim) extension that allows
for remote operations on Vim's native text objects: that is, it exposes atomic
bundles of (virtual or actual) leaping motions and text object selections.

![showcase](../media/showcase.gif?raw=true)

AFAIK, the basic idea first appeared in
[vim-seek](https://github.com/goldfeld/vim-seek), one of
[vim-sneak](https://github.com/justinmk/vim-sneak)'s predecessors. (The feature
is coincidentally called "leaping motions" there, no kidding.)

It's not just number of keystrokes that matter here, but the potentially more
intuitive workflow achieved through these higher abstractions, that are
nevertheless obvious extensions of Vim's grammar. As usual, the aim is to
sharpen the saw; there are no big list of new commands to learn, except for an
affix that can be added to all existing text objects. `carb<leap>` ("change
around remote block [marked by leap motion]") in no time will be just as natural
as targets.vim's `canb` ("change around next block").

## What are some fun things you can do with this?

- Comment/delete/indent paragraphs without leaving your position (`darp<leap>`).
- Fix a typo, even in another window, with a short, atomic command sequence
  (`cRw<leap><correction>`).
- Operate on distant lines by targeting any text object in forced linewise mode:
  `<op>Vrw<leap>`.
- Clone text objects with a few keystrokes by turning on auto-paste after
  yanking (`yarp<leap>`).
- Use `count`: e.g. `y3arw<leap>` yanks 3 words from the anchor point.

## Status

WIP - everything is experimental at the moment. Especially the suggested
mappings.

## Requirements

* [leap.nvim](https://github.com/ggandor/leap.nvim)

## Setup

Spooky exposes only one convenience function. You can call it without arguments,
if the defaults are okay:

```lua
require('leap-spooky').add_spooky_mappings {
  -- The yanked text will automatically be pasted at the cursor position
  -- if the unnamed register is in use. (Experimental feature - I'm thinking
  -- about the proper API for this.)
  yank_paste = false,
  keys = { 
    -- For each search scope, define a table like below, with separate affixes
    -- corresponding to "inner" and "around" objects.
    -- These will generate mappings for all given text objects, like:
    -- r{obj}, ar{obj}, R{obj}, aR{obj}, etc.
    -- Mnemonics: "remote object", "around remote object".
    window       = { i = 'r', a = 'ar' },
    cross_window = { i = 'R', a = 'aR' },
    forward      = nil,
    backward     = nil,
  },
  textobjects = {
    'iw', 'iW', 'is', 'ip', 'i[', 'i]', 'i(', 'i)', 'ib',
    'i>', 'i<', 'it', 'i{', 'i}', 'iB', 'i"', 'i\'', 'i`',
    'aw', 'aW', 'as', 'ap', 'a[', 'a]', 'a(', 'a)', 'ab',
    'a>', 'a<', 'at', 'a{', 'a}', 'aB', 'a"', 'a\'', 'a`',
  },
  -- Call-specific overrides for the Leap motion itself.
  -- E.g.: opts = { equivalence_classes = {} }
  opts = nil,
}
```

## Planned features

- It would be awesome to restrict the search area to the given text objects.
  E.g. `cr]` would only give matches inside square brackets. This could often
  add a huge speed boost and reduce the visual noise a lot. We could even
  highlight the active areas.

- Label the text objects themselves (at least blocks, paragraphs, etc.), so that
  you can immediately choose one, instead of having to specify the anchor point
  with a default 2-char Leap motion.
