-- NumRow: A number-row symbol locator training game for Neovim
-- lua/numrow/init.lua

local M = {}

M.config = {
  rounds = 10,
  feedback = "offset", -- "offset" | "warm"
  show_hint_on_miss = false, -- shows "Correct: Shift+<digit>"
  symbols = { "!", "@", "#", "$", "%", "^", "&", "*", "(", ")" }, -- US layout default
  digits = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }, -- aligned with symbols
  score = {
    base = 10,
    penalty = 2,
    min = 1,
  },
  win = {
    width = 54,
    height = 8,
    border = "rounded",
  },
}

-- Used to map a pressed key to its position in the symbols list.
--@param tbl table The table to search
--@param val any The value to find
--@return number|nil The index of the value in the table, or nil if not
local function tbl_index_of(tbl, val)
  for ind, x in ipairs(tbl) do
    if x == val then
      return ind
    end
  end
  return nil
end

-- Used for positioning the game window in the middle of the screen.
local function center_win_opts(width, height, border, title)
  local cols = vim.o.columns
  local lines = vim.o.lines
  return {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((cols - width) / 2),
    -- TODO: Should we make this deal with cmdheight=0?
    -- Subtract 1 to keep the window off the cmdline (assumes cmdheight=1)
    row = math.floor((lines - height) / 2) - 1,
    style = "minimal",
    border = border,
    title = title,
    title_pos = "center",
  }
end

-- Opens a floating window and returns its buffer and window handles
--@param cfg table Configuration table
--@return number, number Buffer and window handles
local function open_ui(cfg)
  -- first false - not listed, second true - scratch buffer (bufhidden controls wipe)
  local buf = vim.api.nvim_create_buf(false, true)
  -- not associated with a file
  vim.bo[buf].buftype = "nofile"
  -- do not save when closed
  vim.bo[buf].bufhidden = "wipe"
  -- no swapfile
  vim.bo[buf].swapfile = false
  -- initially modifiable (to set lines later)
  vim.bo[buf].modifiable = true

  -- open floating window
  -- true - enter the window after opening
  local window_cfg = center_win_opts(cfg.win.width, cfg.win.height, cfg.win.border, " NumRow ")
  local win = vim.api.nvim_open_win(buf, true, window_cfg)
  -- set window options
  -- no number column, no cursorline, no wrap, no signcolumn
  vim.wo[win].cursorline = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].wrap = false

  return buf, win
end

-- Wipes existing lines and sets new ones (temporarily toggles modifiable)
--@param buf number Buffer handle
--@param lines table Table of strings to set as lines
local function set_lines(buf, lines)
  vim.bo[buf].modifiable = true
  -- 0 - start from first line
  -- -1 - until last line
  -- false - allow out-of-range indices (strict_indexing = false)
  -- lines - table of strings to set
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

-- Feedback label generators for warm mode
--@param distance number Distance from correct key
--@return string Feedback label
local function warm_label(distance)
  if distance == 0 then
    return "Correct!"
  elseif distance == 1 then
    return "Warm."
  elseif distance == 2 then
    return "Cool."
  else
    return "Cold."
  end
end

-- Feedback label generators for offset mode
--@param delta number Signed distance from correct key
--@return string feedback label
local function offset_label(delta)
  local n = math.abs(delta)
  if n == 0 then
    return "Correct!"
  end
  local dir = (delta < 0) and "left" or "right"
  local key_word = (n == 1) and "key" or "keys"
  return ("You were %d %s to the %s."):format(n, key_word, dir)
end

-- Calculates score for a round
--@param score_cfg table Scoring configuration
--@param attempts number Number of attempts taken
--@return number Points awarded for the round
local function score_for_attempts(score_cfg, attempts)
  local cfg = score_cfg or {}
  local base = cfg.base or 10
  local penalty = cfg.penalty or 2
  local min_points = cfg.min or 1
  local points = base - penalty * (attempts - 1)
  return math.max(min_points, points)
end

-- Calculates accuracy
--@param correct number Number of correct attempts
--@param misses number Number of missed attempts
--@return number, number Accuracy percentage and total attempts
local function accuracy_stats(correct, misses)
  local attempts = correct + misses
  if attempts == 0 then
    return 0, attempts
  end
  -- NOTE: There is no built-in round function in Lua
  local accuracy = math.floor((correct / attempts) * 100 + 0.5)
  return accuracy, attempts
end

-- Renders the main menu
--@param buf number Buffer handle
local function render_menu(buf)
  set_lines(buf, {
    "Pick a mode:",
    "  1) Symbol Locator (offset feedback)",
    "  2) Symbol Locator (warm feedback)",
    "",
  })
  footer_line = "Press 1 or 2 to start. Press <Esc> to quit."
  local window_id = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_config(window_id, { title = " NumRow - Main Menu ", footer = footer_line })
end

-- Wrapper for getcharstr with error handling
-- Used to get a single keypress from the user
--@return string|nil Pressed key as string, or nil on error
local function getchar_str()
  -- Force redraw to ensure prompt is visible
  -- Without this, sometimes the prompt doesn't show up before getcharstr
  vim.cmd("redraw")
  local ok, ch = pcall(vim.fn.getcharstr)
  if not ok then
    -- Converting 'ch' to string just in case it's nil or another type
    vim.notify(("NumRow: getcharstr failed: %s"):format(tostring(ch)), vim.log.levels.WARN)
    return nil
  end
  return ch
end

--@param ch string Pressed key
--@return boolean True if the key is Escape, false otherwise
local function is_esc(ch)
  return ch == "\027" -- ESC
end

local function render_summary(buf, title, score, correct, misses)
  local accuracy, attempts = accuracy_stats(correct, misses)
  set_lines(buf, {
    title,
    "",
    ("Final score: %d"):format(score),
    ("Accuracy: %d%% (%d/%d)"):format(accuracy, correct, attempts),
    ("Misses: %d"):format(misses),
    "",
    "(1) New game (2) Back to main menu (3) Close",
  })

  while true do
    local ch = getchar_str()
    if not ch or is_esc(ch) or ch == "3" then
      return "quit"
    elseif ch == "1" then
      return "restart"
    elseif ch == "2" then
      return "menu"
    end
  end
end

-- Main game loop for symbol locator mode
--@param cfg table Configuration table
--@return nil
local function run_symbol_locator(cfg)
  math.randomseed(os.time())

  local buf, win = open_ui(cfg)

  while true do
    local score, misses, correct = 0, 0, 0
    local ended_early = false

    for round = 1, cfg.rounds do
      local target_idx = math.random(1, #cfg.symbols)
      local target = cfg.symbols[target_idx]

      local feedback = ""
      local round_attempts = 0
      while true do
        local header = ("Round %d/%d   Score %d   Misses %d"):format(
          round,
          cfg.rounds,
          score,
          misses
        )
        local lines = {
          header,
          "",
          ("Press: %s"):format(target),
          "",
          ("Feedback: %s"):format(feedback),
          "",
          "Tip: press <Esc> to quit",
        }
        set_lines(buf, lines)

        local ch = getchar_str()
        if not ch or is_esc(ch) then
          ended_early = true
          break
        end

        round_attempts = round_attempts + 1

        if ch == target then
          correct = correct + 1
          local round_points = score_for_attempts(cfg.score, round_attempts)
          score = score + round_points
          feedback = ("✓ Correct! +%d"):format(round_points)
          header = ("Round %d/%d   Score %d   Misses %d"):format(round, cfg.rounds, score, misses)
          -- small “ack” redraw before next round (optional)
          set_lines(buf, {
            header,
            "",
            ("Press: %s"):format(target),
            "",
            ("Feedback: %s"):format(feedback),
            "",
            "Tip: press <Esc> to quit",
          })
          vim.defer_fn(function() end, 60)
          break
        end

        local pressed_idx = tbl_index_of(cfg.symbols, ch)
        if pressed_idx then
          misses = misses + 1
          local delta = pressed_idx - target_idx
          local dist = math.abs(delta)

          if cfg.feedback == "warm" then
            feedback = warm_label(dist)
          else
            feedback = offset_label(delta)
          end

          if cfg.show_hint_on_miss then
            local correct_digit = cfg.digits[target_idx] or "?"
            feedback = feedback .. ("  (Correct: Shift+%s)"):format(correct_digit)
          end
        else
          misses = misses + 1
          feedback = ("That's not a number-row symbol (%s). Try again."):format(ch)
        end
      end

      if ended_early then
        break
      end
    end

    local title = ended_early and "Session Ended" or "Session Complete"
    local action = render_summary(buf, title, score, correct, misses)
    if action == "restart" then
      -- loop to start a new session in the same mode
    elseif action == "menu" then
      pcall(vim.api.nvim_win_close, win, true)
      return "menu"
    else
      pcall(vim.api.nvim_win_close, win, true)
      return "quit"
    end
  end
end

function M.start()
  local cfg = M.config
  while true do
    local buf, win = open_ui(cfg)
    render_menu(buf)

    local ch
    while true do
      ch = getchar_str()
      -- Handle quit
      if not ch or is_esc(ch) then
        pcall(vim.api.nvim_win_close, win, true)
        return
      end

      if ch == "1" or ch == "2" then
        break
      end
    end

    -- Close menu window
    pcall(vim.api.nvim_win_close, win, true)

    local feedback = (ch == "1") and "offset" or "warm"
    local action = run_symbol_locator(vim.tbl_deep_extend("force", cfg, { feedback = feedback }))
    if action ~= "menu" then
      return
    end
  end
end

-- Setup function to override default configuration
-- User can call this from their config
--@param opts table User-provided configuration table
--@return nil
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

return M
