-- plugin/numrow.lua

if vim.g.loaded_numrow == 1 then
	return
end
vim.g.loaded_numrow = 1

vim.api.nvim_create_user_command("NumRow", function()
	require("numrow").start()
end, { desc = "Start NumRow keyboard training game" })
