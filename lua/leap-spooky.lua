local api = vim.api


local function get_motion_force()
  local force = ""
  local mode = vim.fn.mode(1)
  if mode:sub(2) == 'oV' then force = "V"
  elseif mode:sub(2) == 'o' then force = ""
  end
  return force
end


local function spooky_action(action, kwargs)
  return function (target)
    local op_mode = vim.fn.mode(1):match('o')
    local operator = vim.v.operator
    local on_return = kwargs.on_return
    local keeppos = kwargs.keeppos
    local saved_view = vim.fn.winsaveview()
    -- Handle cross-window operations.
    local source_win = vim.fn.win_getid()
    local cross_window = target.wininfo and target.wininfo.winid ~= source_win
    -- Set an extmark as an anchor, so that we can execute remote delete
    -- commands in the backward direction, and move together with the text.
    local ns = api.nvim_create_namespace("leap-spooky")
    local anchor = api.nvim_buf_set_extmark(0, ns, saved_view.lnum-1, saved_view.col, {})

    -- Jump.
    if cross_window then api.nvim_set_current_win(target.wininfo.winid) end
    api.nvim_win_set_cursor(0, { target.pos[1], target.pos[2]-1 })
    -- Execute :normal action. (Intended usage: select some text object.)
    vim.cmd("normal " .. action())  -- don't use bang - custom text objects should work too
    -- (The operation itself will be executed after exiting.)

    -- Follow-up:
    if (keeppos or on_return) and op_mode then  -- sanity check
      api.nvim_create_autocmd('ModeChanged', {
        -- Trigger on any mode change, including returning to Insert
        -- (possible i_CTRL-O), except for change operations (then
        -- we first enter Insert mode for doing the change itself, and
        -- should wait for returning to Normal).
        pattern = operator == 'c' and '*:n' or '*:*',
        once = true,
        callback = function ()
          if keeppos then
            if cross_window then api.nvim_set_current_win(source_win) end
            vim.fn.winrestview(saved_view)
            local anchorpos = api.nvim_buf_get_extmark_by_id(0, ns, anchor, {})
            api.nvim_win_set_cursor(0, { anchorpos[1]+1, anchorpos[2] })
            api.nvim_buf_clear_namespace(0, ns, 0, -1)  -- remove the anchor
          end
          if on_return then
            vim.cmd("normal " .. on_return)
          end
        end,
      })
    end
  end
end


local default_affixes = {
  remote   = { window = 'r', cross_window = 'R' },
  magnetic = { window = 'm', cross_window = 'M' },
}

local default_text_objects_raw = {
  'w', 'W', 's', 'p', '[', ']', '(', ')', 'b',
  '>', '<', 't', '{', '}', 'B', '"', '\'', '`',
}

local function assign_inner_around(raw_text_objects)
  local inner_around_mappings = {}
  for _, raw_text_object in ipairs(raw_text_objects) do
    table.insert(inner_around_mappings, "i"..raw_text_object)
    table.insert(inner_around_mappings, "a"..raw_text_object)
  end
  return inner_around_mappings
end

local default_text_objects = assign_inner_around(default_text_objects_raw)

local function setup(kwargs)
  local kwargs = kwargs or {}
  local affixes = kwargs.affixes
  local custom_textobjects = assign_inner_around(kwargs.custom_textobjects or {})
  local text_objects = vim.list_extend(default_text_objects, custom_textobjects)
  local yank_paste = kwargs.paste_on_remote_yank or kwargs.yank_paste

  local v_exit = function()
    local mode = vim.fn.mode(1)
    if mode:match('o') then return "" end
    -- v/V/<C-v> exits the corresponding Visual mode if already in it.
    return mode:sub(1,1)
  end

  local mappings = {}
  for kind, scopes in pairs(affixes or default_affixes) do
    local keeppos = kind == 'remote'
    for scope, key in pairs(scopes) do
      for _, textobj in ipairs(default_text_objects) do
        table.insert(mappings, {
          scope = scope,
          keeppos = keeppos,
          lhs = key .. textobj,
          action = function ()
            return v_exit() .. "v" .. vim.v.count1 .. textobj .. get_motion_force()
          end,
        })
      end
      -- Special case: remote lines.
      table.insert(mappings, {
        scope = scope,
        keeppos = keeppos,
        lhs = key .. key,
        action = function ()
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
          local target_windows = nil
          if mapping.scope == 'window' then
            target_windows = { vim.fn.win_getid() }
          elseif mapping.scope == 'cross_window' then
            target_windows = require'leap.util'.get_enterable_windows()
          end
          local yank_paste = (yank_paste and mapping.keeppos and
                              vim.v.operator == 'y' and vim.v.register == "\"")

          local leap_params = {
            action = spooky_action(mapping.action, {
              keeppos = mapping.keeppos,
              on_return = yank_paste and "p",
            }),
            target_windows = target_windows
          }
          if kwargs.auto_targets then
            local ok, MiniAi = pcall(require, "mini.ai")
            if ok then 
              local is_ai = mapping.lhs:sub(-2, -2)
              local obj_type = mapping.lhs:sub(-1, -1)
              local first_visible = vim.fn.line("w0")
              local search_opts = {
                n_lines = 50,
                n_times = 1,
                reference_region = {
                  from = { line = first_visible, col = 1 },
                }
              }
              local search_count = 1
              local textobj_targets = {}
              while search_count > 0 and search_count < (kwargs.auto_targets_max_targets or 100) do
                search_opts.n_times = search_count
                local target = MiniAi.find_textobject(is_ai, obj_type, search_opts)
                if target ~= nil then
                  table.insert(textobj_targets, { pos = { target.from.line, target.from.col } })
                  search_count = search_count + 1
                else
                  search_count = 0
                end
              end

              if #textobj_targets > 0 then
                leap_params.targets = textobj_targets
              end
            end
          end
          require'leap'.leap(leap_params)
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
