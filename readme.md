# tile.nvim

Utility to resize and move windows in neovim.

## Setup

On [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "danielefongo/tile.nvim",
  opts = {
    horizontal = 4,
    vertical = 2,
  },
  keys = {
    { "<c-h>", ":lua require('tile').resize_left()<cr>", desc = "resize left" },
    { "<c-j>", ":lua require('tile').resize_down()<cr>", desc = "resize down" },
    { "<c-k>", ":lua require('tile').resize_up()<cr>", desc = "resize up" },
    { "<c-l>", ":lua require('tile').resize_right()<cr>", desc = "resize right" },
    { "<c-s><c-h>", ":lua require('tile').shift_left()<cr>", desc = "shift left" },
    { "<c-s><c-j>", ":lua require('tile').shift_down()<cr>", desc = "shift down" },
    { "<c-s><c-k>", ":lua require('tile').shift_up()<cr>", desc = "shift up" },
    { "<c-s><c-l>", ":lua require('tile').shift_right()<cr>", desc = "shift right" },
  },
}
```
