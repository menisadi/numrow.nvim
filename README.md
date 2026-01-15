# numrow.nvim

A tiny floating-window game to train number-row symbol muscle memory.

## Install (lazy.nvim)

```lua
{
  "menisadi/numrow.nvim",
  cmd = "NumRow", -- lazy-load when you run :NumRow
}
```

No setup required. Run `:NumRow`.

## Usage

* `:NumRow` — open menu and start

## Configuration

```lua
require("numrow").setup({
  rounds = 40,
  feedback = "warm",
  show_hint_on_miss = true,
  symbols = { "!", "@", "#", "$", "%", "^", "&", "*", "(", ")" },
  digits  = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" },
  win = { width = 54, height = 8, border = "rounded" },
})
```

### Notes

* Defaults assume a US keyboard layout for number-row symbols.
