local api = vim.api

local default_vim_text_objects = {
  'iw', 'iW', 'is', 'ip', 'i[', 'i]', 'i(', 'i)', 'ib',
  'i>', 'i<', 'it', 'i{', 'i}', 'iB', 'i"', 'i\'', 'i`',
  'aw', 'aW', 'as', 'ap', 'a[', 'a]', 'a(', 'a)', 'ab',
  'a>', 'a<', 'at', 'a{', 'a}', 'aB', 'a"', 'a\'', 'a`',
}

local default_affixes = {
  remote   = { window = 'r', cross_window = 'R' },
  magnetic = { window = 'm', cross_window = 'M' },
}


-- `select_cmd` is a callback returning a command string for :normal, assumed
-- to be achieving a visual selection. (Being a callback allows creating the
-- string dynamically, based on the actual mode or even the target context.)
local function spooky_action(select_cmd, kwargs)
  -- A function to be used by `leap` as its `action` parameter.
  return function (target)
    local on_exit = kwargs.on_exit
    local keeppos = kwargs.keeppos
    local op_mode = vim.fn.mode(1):match('o')
    local saved_view = vim.fn.winsaveview()
    -- Handle cross-window operations.
    local source_win = vim.fn.win_getid()
    local cross_window = target.wininfo and target.wininfo.winid ~= source_win
    -- Set an extmark as an anchor, so that we can execute remote delete
    -- commands in the backward direction, and move together with the text.
    local anc_ns = api.nvim_create_namespace("leap-spooky-anchor")
    local anchor = api.nvim_buf_set_extmark(0, anc_ns, saved_view.lnum-1, saved_view.col, {})

    if cross_window then api.nvim_set_current_win(target.wininfo.winid) end
    api.nvim_win_set_cursor(0, { target.pos[1], target.pos[2]-1 })

    vim.cmd.normal(select_cmd())  -- don't use bang - custom text objects should work too

    -- In O-P mode, the operation itself will be executed after exiting this
    -- function. We can set up an autocommand for follow-up stuff, triggering
    -- on mode change:
    if (keeppos or on_exit) and op_mode then  -- op_mode as a sanity check
      api.nvim_create_autocmd('ModeChanged', {
        -- We might return to Insert mode if doing an i_CTRL-O stunt,
        -- but make sure we never trigger on it when doing _change_
        -- operations (then we enter Insert mode for doing the change
        -- itself, and should wait for returning to Normal).
        pattern = vim.v.operator == 'c' and '*:n' or '*:*',
        once = true,
        callback = function ()
          if keeppos then
            -- Go back to source window (if necessary), restore view.
            if cross_window then api.nvim_set_current_win(source_win) end
            vim.fn.winrestview(saved_view)
            -- Move to the anchor position.
            local anchorpos = api.nvim_buf_get_extmark_by_id(0, anc_ns, anchor, {})
            api.nvim_win_set_cursor(0, { anchorpos[1]+1, anchorpos[2] })
            api.nvim_buf_clear_namespace(0, anc_ns, 0, -1)
          end
          -- Execute follow-up action, if there is one.
          if on_exit then vim.cmd.normal(on_exit) end
        end,
      })
    end
  end
end


local function setup(kwargs)
  local kwargs = kwargs or {}
  local affixes = kwargs.affixes
  local extra_text_objects = kwargs.extra_text_objects or {}
  local text_objects = vim.list_extend(
    vim.deepcopy(default_vim_text_objects), extra_text_objects
  )
  local yank_paste = kwargs.paste_on_remote_yank or kwargs.yank_paste
  local default_register = (vim.o.clipboard == 'unnamed' and "*" or
                            vim.o.clipboard:match('unnamedplus') and "+" or
                            "\"")

  local v_exit = function()
    local mode = vim.fn.mode(1)
    if mode:match('o') then return "" end
    -- v/V/<C-v> exits the corresponding Visual mode if already in it.
    return mode:sub(1,1)
  end

  local function get_motion_force()
    local mode = vim.fn.mode(1)
    return (mode:sub(2) == 'oV' and "V" or mode:sub(2) == 'o' and "" or "")
  end

  local mappings = {}
  for kind, scopes in pairs(affixes or default_affixes) do
    local keeppos = kind == 'remote'
    for scope, key in pairs(scopes) do
      for _, textobj in ipairs(text_objects) do
        table.insert(mappings, {
          scope = scope,
          keeppos = keeppos,
          -- Force prefix if a custom textobject does not follow the a/i pattern.
          lhs = (
            (kwargs.prefix or not textobj:sub(1,1):match('[aiAI]'))
            and key .. textobj
            or textobj:sub(1,1) .. key .. textobj:sub(2)
          ),
          select_cmd = function ()
            return v_exit() .. "v" .. vim.v.count1 .. textobj .. get_motion_force()
          end,
        })
      end
      -- Special case: remote lines.
      table.insert(mappings, {
        scope = scope,
        keeppos = keeppos,
        lhs = key .. key,
        select_cmd = function ()
          -- Note: a simple [count]V would not work, its behaviour
          -- depends on the previous Visual operation, see `:h V`.
          local n_js = vim.v.count1 - 1
          return v_exit() .. "V" .. (n_js > 0 and (tostring(n_js) .. "j") or "")
        end,
      })
    end
  end

  for _, mapping in ipairs(mappings) do
    for _, mode in ipairs({'x', 'o'}) do
      -- Don't map "remote" keys in Visual.
      if mode == 'o' or (not mapping.keeppos) then
        vim.keymap.set(mode, mapping.lhs, function ()
          local target_windows = (
            mapping.scope == 'window' and { vim.fn.win_getid() } or
            mapping.scope == 'cross_window' and require'leap.util'.get_enterable_windows()
          )
          local yank_paste = (yank_paste and
                              mapping.keeppos and
                              vim.v.operator == 'y' and
                              vim.v.register == default_register)
          require'leap'.leap {
            target_windows = target_windows,
            action = spooky_action(mapping.select_cmd, {
              keeppos = mapping.keeppos,
              on_exit = yank_paste and "p",
            }),
          }
        end)
      end
    end
  end
end


return {
  spooky_action = spooky_action,
  spookify = setup,
  setup = setup,
}
