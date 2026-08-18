# bob-shell.nvim

<p align="center">
  <img src="assets/bob.svg" height="120" alt="Bob" />&nbsp;&nbsp;&nbsp;&nbsp;<img src="assets/1920px-Neovim-mark.svg.png" height="90" align="absmiddle" alt="Neovim" />
</p>

Neovim integration for [Bob Shell](https://bob.ibm.com), heavily inspired by [bob-nvim](https://github.com/enricobguedes/bob-nvim/) — open Bob shell in a split, resume past conversations, and send context from your editor.

<img width="1732" height="1080" alt="Image" src="https://github.com/user-attachments/assets/61650c33-1e10-42fc-b5dc-1a706ed4ce25" />

## Requirements

- Neovim >= 0.8.0
- `bob` in your PATH ([install](https://bob.ibm.com))
- `libsqlite3` — optional, required for `:BobTaskHistory`

## Installation

```lua
-- lazy.nvim
{
  "egramsdoescode/bob-shell.nvim",
  config = function()
    require("bob").setup()
  end,
}
```

## Usage

| Command | Description |
|---------|-------------|
| `:BobShell` | Open Bob shell |
| `:BobToggle` | Toggle the Bob window |
| `:BobClose` | Close the Bob window |
| `:BobResumeLatest` | Resume the most recent conversation |
| `:BobTaskHistory` | Pick and resume a past conversation |
| `:BobSendFile` | Send `@current-file` to active session |
| `:BobSendYank` | Send unnamed register to active session |
| `:BobSendVisual` | Send visual selection to active session |

### Keybindings

```lua
vim.keymap.set("n", "<leader>tb", ":BobShell<CR>",        { desc = "Bob: open" })
vim.keymap.set("n", "<leader>tt", ":BobToggle<CR>",       { desc = "Bob: toggle" })
vim.keymap.set("n", "<leader>tc", ":BobClose<CR>",        { desc = "Bob: close" })
vim.keymap.set("n", "<leader>tr", ":BobResumeLatest<CR>", { desc = "Bob: resume latest" })
vim.keymap.set("n", "<leader>th", ":BobTaskHistory<CR>",  { desc = "Bob: task history" })
vim.keymap.set("n", "<leader>ts", ":BobSendFile<CR>",     { desc = "Bob: send file" })
vim.keymap.set("n", "<leader>ty", ":BobSendYank<CR>",     { desc = "Bob: send yank" })
vim.keymap.set("x", "<leader>tv", ":BobSendVisual<CR>",   { desc = "Bob: send selection" })
```

## Configuration

```lua
require("bob").setup({
  split_direction = "right",   -- "left" | "right" | "above" | "below"
  split_size = 50,             -- columns (left/right) or rows (above/below), min 50
  chat_mode = "agent",         -- default Bob chat mode
  auto_focus = true,           -- focus Bob window on open
  start_in_insert = true,      -- enter insert mode when auto_focus = true
  task_history_limit = 50,     -- max entries in history picker
  db_path = nil,               -- override path to bob.db (default: ~/.bob/db/bob.db)
  task_preview = true,         -- two-panel floating picker for :BobTaskHistory
  task_preview_messages = 20,  -- max chat turns shown in preview
  picker = "auto",             -- "auto" | "snacks" | "telescope" | "builtin"
  team_id = nil,               -- required when using a general API key (see note below)
})
```

> [!NOTE]
> If your Bob API key is of type **general** (rather than **Inference**), you must set
> `team_id` to your team's ID. This passes `--team-id <team-id>` to every `bob chat`
> invocation automatically.

`picker = "auto"` resolves: snacks.nvim → Telescope → builtin float → `vim.ui.select`.

## Troubleshooting

**Bob not found** — run `which bob` to confirm it's in your PATH.

**Task history errors** — install `libsqlite3` for your OS (`brew install sqlite` / `apt install libsqlite3-0` / `dnf install sqlite-libs`).

**Cramped window** — increase `split_size` (minimum 50).

## License
MIT
