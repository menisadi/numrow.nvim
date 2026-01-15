-- NumRow: A number-row symbol locator training game for Neovim
-- lua/numrow/init.lua

local M = {}

M.config = {
	rounds = 30,
	feedback = "offset", -- "offset" | "warm"
	show_hint_on_miss = true, -- shows "Correct: Shift+<digit>"
	symbols = { "!", "@", "#", "$", "%", "^", "&", "*", "(", ")" }, -- US layout default
	digits = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }, -- aligned with symbols
	win = {
		width = 54,
		height = 8,
		border = "rounded",
	},
}

local function tbl_index_of(t, v)
	for i, x in ipairs(t) do
		if x == v then
			return i
		end
	end
	return nil
end

local function center_win_opts(width, height, border)
	local cols = vim.o.columns
	local lines = vim.o.lines
	return {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((cols - width) / 2),
		row = math.floor((lines - height) / 2) - 1,
		style = "minimal",
		border = border,
	}
end

local function open_ui(cfg)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = true

	local win = vim.api.nvim_open_win(buf, true, center_win_opts(cfg.win.width, cfg.win.height, cfg.win.border))
	vim.wo[win].cursorline = false
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].wrap = false

	return buf, win
end

local function set_lines(buf, lines)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
end

local function warm_label(distance)
	-- simple buckets; tweak however you like
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

local function offset_label(delta)
	local n = math.abs(delta)
	if n == 0 then
		return "Correct!"
	end
	local dir = (delta < 0) and "left" or "right"
	local key_word = (n == 1) and "key" or "keys"
	return ("You were %d %s to the %s."):format(n, key_word, dir)
end

local function render_menu(buf)
	set_lines(buf, {
		"NumRow",
		"",
		"Pick a mode:",
		"  1) Symbol Locator (offset feedback)",
		"  2) Symbol Locator (warm feedback)",
		"",
		"Press 1 or 2 to start. Press <Esc> to quit.",
	})
end

local function getchar_str()
	vim.cmd("redraw")
	local ok, ch = pcall(vim.fn.getcharstr)
	if not ok then
		vim.notify(("NumRow: getcharstr failed: %s"):format(tostring(ch)), vim.log.levels.WARN)
		return nil
	end
	return ch
end

local function is_esc(ch)
	return ch == "\027" -- ESC
end

local function run_symbol_locator(cfg)
	math.randomseed(os.time())

	local buf, win = open_ui(cfg)

	local score, misses = 0, 0

	for round = 1, cfg.rounds do
		local target_idx = math.random(1, #cfg.symbols)
		local target = cfg.symbols[target_idx]

		local feedback = ""
		while true do
			local header = ("NumRow — Symbol Locator   Round %d/%d   Score %d   Misses %d"):format(
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
				pcall(vim.api.nvim_win_close, win, true)
				return
			end

			if ch == target then
				score = score + 1
				feedback = "✓ Correct!"
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
	end

	set_lines(buf, {
		"NumRow — Session Complete",
		"",
		("Final score: %d/%d"):format(score, cfg.rounds),
		("Misses: %d"):format(misses),
		"",
		"Press any key to close.",
	})

	getchar_str()
	pcall(vim.api.nvim_win_close, win, true)
end

function M.start()
	local cfg = M.config
	local buf, win = open_ui(cfg)
	render_menu(buf)

	while true do
		local ch = getchar_str()
		if not ch or is_esc(ch) then
			pcall(vim.api.nvim_win_close, win, true)
			return
		end

		if ch == "1" then
			pcall(vim.api.nvim_win_close, win, true)
			run_symbol_locator(vim.tbl_deep_extend("force", cfg, { feedback = "offset" }))
			return
		elseif ch == "2" then
			pcall(vim.api.nvim_win_close, win, true)
			run_symbol_locator(vim.tbl_deep_extend("force", cfg, { feedback = "warm" }))
			return
		end
	end
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

return M
