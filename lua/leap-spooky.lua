local api = vim.api

local default_affixes = { 
  window       = 'r',
  cross_window = 'R',
}

local default_textobjects = {
  'iw', 'iW', 'is', 'ip', 'i[', 'i]', 'i(', 'i)', 'ib',
  'i>', 'i<', 'it', 'i{', 'i}', 'iB', 'i"', 'i\'', 'i`',
  'aw', 'aW', 'as', 'ap', 'a[', 'a]', 'a(', 'a)', 'ab',
  'a>', 'a<', 'at', 'a{', 'a}', 'aB', 'a"', 'a\'', 'a`',
}


local function spooky_action(textobj, yank_paste)
  return function (target)
    local keeppos = vim.v.operator ~= 'c'
    local yank_paste = yank_paste and vim.v.operator == 'y' and vim.v.register == "\""
    local saved_view = vim.fn.winsaveview()

    -- Get forcing modifier.
    local force = ""
    local mode = vim.fn.mode(1)
    if mode:sub(2) == 'oV' then force = "V"
    elseif mode:sub(2) == 'o' then force = ""
    end

    -- Handle cross-window operations.
    local source_win = vim.fn.win_getid()
    local cross_window = target.wininfo and target.wininfo.winid ~= source_win

    -- Set an extmark as an anchor, so that we can execute remote delete
    -- commands in the backward direction, and move together with the text.
    local ns = api.nvim_create_namespace("leap-spooky")
    local anchor = api.nvim_buf_set_extmark(0, ns, saved_view.lnum-1, saved_view.col, {})

    -- Jump.
    if cross_window then
      api.nvim_set_current_win(target.wininfo.winid)
    end
    api.nvim_win_set_cursor(0, { target.pos[1], target.pos[2]-1 })
    -- Execute.
    vim.cmd("normal! v" .. vim.v.count1 .. textobj .. (textobj == "V" and "" or force))

    -- Things to do if staying in place.
    if keeppos then
      api.nvim_create_autocmd('ModeChanged', {
        pattern = '*:n',  -- on returning to Normal
        once = true,
        callback = function ()
          if cross_window then
            api.nvim_set_current_win(source_win)
          end
          vim.fn.winrestview(saved_view)
          local anchorpos = api.nvim_buf_get_extmark_by_id(0, ns, anchor, {})
          api.nvim_win_set_cursor(0, { anchorpos[1]+1, anchorpos[2] })
          api.nvim_buf_clear_namespace(0, ns, 0, -1)  -- remove the anchor
          if yank_paste then
            vim.cmd("normal! p")
          end
        end,
      })
    end
  end
end


local function setup(kwargs)
  local kwargs = kwargs or {}
  local yank_paste = kwargs.yank_paste
  local affixes = kwargs.affixes
  local opts = kwargs.opts
  local mappings = {}
  for scope, key in pairs(affixes or default_affixes) do
    for _, textobj in ipairs(default_textobjects) do
      local ia = textobj:sub(1,1)
      table.insert(mappings, {
        lhs = ia .. key .. textobj:sub(2),
        textobj = textobj,
        scope = scope,
      })
    end
    -- Special remote line object.
    table.insert(mappings, {
      lhs = key .. key,
      textobj = "V",
      scope = scope,
    })
  end

  for _, mapping in ipairs(mappings) do
    vim.keymap.set('o', mapping.lhs, function ()
      local target_windows = nil
      if mapping.scope == 'window' then
        target_windows = { vim.fn.win_getid() }
      elseif mapping.scope == 'cross_window' then
        target_windows = require'leap.util'.get_enterable_windows()
      end
      require'leap'.leap {
        action = spooky_action(mapping.textobj, yank_paste),
        target_windows = target_windows,
        opts = opts,
      }
    end)
  end
end


return { 
  spookify = setup,
  setup = setup
}
