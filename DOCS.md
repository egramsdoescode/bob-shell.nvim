# bob-shell.nvim — Documentation

Neovim integration for [Bob Shell](https://bob.ibm.com). It runs `bob chat` in a
terminal split, resumes past conversations from Bob's local SQLite database, and
pipes context (files, yanks, visual selections) from your editor into the running
session.

- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Commands](#commands)
- [Lua API](#lua-api)
- [Window behavior](#window-behavior)
- [Sending context to Bob](#sending-context-to-bob)
- [Task history](#task-history)
- [Pickers](#pickers)
- [Highlight groups](#highlight-groups)
- [How the `bob` command is built](#how-the-bob-command-is-built)
- [Module map](#module-map)
- [Troubleshooting](#troubleshooting)
- [Known limitations](#known-limitations)

---

## Requirements

| Requirement | Why |
|---|---|
| Neovim >= 0.8.0 | `vim.keymap.set`, `vim.wo`/`vim.bo` scoped options, floating-window titles |
| LuaJIT | Task history reads SQLite through the LuaJIT FFI (standard Neovim builds ship LuaJIT) |
| `bob` on `$PATH` | Every command checks `executable("bob")` and aborts with an error if missing |
| `libsqlite3` | Only for `:BobTaskHistory` / `:BobResumeLatest` previews — loaded at runtime via `ffi.load("sqlite3")` |

Optional: [snacks.nvim](https://github.com/folke/snacks.nvim) or
[telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for a nicer
task-history picker. Neither is required — the plugin ships its own float.

---

## Installation

### lazy.nvim

```lua
return {
  "egramsdoescode/bob-shell.nvim",
  config = function()
    require("bob").setup({
      -- see Configuration below; all keys are optional
    })
  end,
}
```

### packer.nvim

```lua
use({
  "egramsdoescode/bob-shell.nvim",
  config = function()
    require("bob").setup({})
  end,
})
```

### vim-plug

```vim
Plug 'egramsdoescode/bob-shell.nvim'
" then, in a lua block or after/plugin file:
lua require('bob').setup({})
```

> **`setup()` is optional for the commands.** User commands are registered when
> `lua/bob.lua` is first required. Calling `setup()` is what applies your options
> and defines the preview highlight groups, so call it anyway.

### Suggested keymaps

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

---

## Configuration

`require("bob").setup(opts)` deep-merges `opts` over the defaults, so you only
need to pass what you want to change.

```lua
require("bob").setup({
  split_direction       = "right",
  split_size            = 50,
  chat_mode             = "agent",
  auto_focus            = true,
  start_in_insert       = true,
  task_history_limit    = 50,
  db_path               = nil,
  task_preview          = true,
  task_preview_messages = 20,
  picker                = "auto",
  team_id               = nil,
})
```

| Option | Type | Default | Description |
|---|---|---|---|
| `split_direction` | `"left"` \| `"right"` \| `"above"` \| `"below"` | `"right"` | Where the terminal split opens. Any unrecognized value falls back to a bottom horizontal split. |
| `split_size` | `number` \| `nil` | `50` | Columns (`left`/`right`) or rows (`above`/`below`). **Clamped to a minimum of 50** — Bob's TUI misrenders below that. `nil` leaves Neovim's default sizing. |
| `chat_mode` | `string` | `"agent"` | Passed as `--mode <mode>` to `bob chat`. |
| `auto_focus` | `boolean` | `true` | Keep the cursor in the Bob window after opening. When `false`, focus returns to the window you came from. |
| `start_in_insert` | `boolean` | `true` | Enter terminal-insert mode on open. Only applies when `auto_focus = true`; also applies after every send. |
| `task_history_limit` | `number` | `50` | `LIMIT` on the task-history query. |
| `db_path` | `string` \| `nil` | `nil` | Absolute path to `bob.db`. `nil` resolves to `$HOME/.bob/db/bob.db`. |
| `task_preview` | `boolean` | `true` | When `false`, the builtin picker path uses plain `vim.ui.select` instead of the two-panel float. Does not affect snacks/Telescope. |
| `task_preview_messages` | `number` | `20` | Max chat turns loaded into the preview panel per task. |
| `picker` | `"auto"` \| `"snacks"` \| `"telescope"` \| `"builtin"` | `"auto"` | Task-history picker backend. See [Pickers](#pickers). |
| `team_id` | `string` \| `nil` | `nil` | Passed as `--team-id <id>`. Required when your Bob API key is of type **general** rather than **Inference**. |

---

## Commands

| Command | Range | Description |
|---|---|---|
| `:BobShell [text]` | — | Open a Bob session. With an argument, `text` is passed to `bob chat` as the opening prompt. |
| `:BobToggle` | — | Close the Bob window if open, otherwise open a fresh session. |
| `:BobClose` | — | Close the Bob window (the terminal buffer stays alive until the next open). |
| `:BobResumeLatest` | — | Resume the most recent conversation via `bob chat --resume latest`. |
| `:BobTaskHistory` | — | Open the picker over past conversations for the current working directory and resume the chosen one. |
| `:BobSendFile` | — | Send `@<relative-path>` of the current buffer to the running session. |
| `:BobSendYank` | — | Send the contents of the unnamed register (`"`). |
| `:BobSendVisual` | yes | Send the visual selection, prefixed with `file:line` / `file:start-end`. |

`:BobShell some text` quotes `text` safely, so shell metacharacters and quotes in
your prompt are not interpreted.

---

## Lua API

```lua
local bob = require("bob")

bob.setup(opts)                      -- apply config, define highlight groups
bob.bobSearch(text, resume_id)       -- open a session; both args optional
bob.bobToggle()                      -- toggle the window
bob.bobClose()                       -- close the window
bob.bobResumeLatest()                -- == bobSearch(nil, "latest")
bob.bobTaskHistory()                 -- open the history picker
bob.sendToBob(text)                  -- send raw text + <CR>; returns boolean
bob.bobSendFile()                    -- send "@" .. relative path
bob.bobSendYank()                    -- send the unnamed register
bob.bobSendVisual()                  -- send the visual selection with location
```

`sendToBob` returns `false` (and notifies) when `text` is empty or no Bob
terminal is running; `true` when the text was written to the terminal job.

Submodules are also directly requirable if you want to build on top of them:
`bob.config`, `bob.terminal`, `bob.send`, `bob.db`, `bob.preview`,
`bob.picker.builtin`, `bob.picker.snacks`, `bob.picker.telescope`.

Example — a custom "explain this function" mapping:

```lua
vim.keymap.set("n", "<leader>te", function()
  local fn = vim.fn.expand("<cword>")
  require("bob").sendToBob("Explain the function " .. fn .. " in @" .. vim.fn.expand("%:."))
end, { desc = "Bob: explain function under cursor" })
```

---

## Window behavior

- **One session at a time.** Opening a session closes the previous Bob window and
  force-deletes its terminal buffer, so `:BobShell` always starts clean. Use
  `:BobClose`/`:BobToggle` to hide a session you want to come back to.
- The split is created with `topleft`/`botright` (`vnew` for left/right, `new`
  for above/below) and pinned with `winfixwidth` or `winfixheight` so other
  window operations don't squeeze it.
- The terminal buffer is set `buflisted = false`, so it stays out of `:ls` and
  buffer-cycling.
- The cursor jumps to the bottom of the terminal on open (`normal! G`).
- **Terminal-mode navigation keymaps** are set buffer-locally so you can leave
  the terminal without pressing `<C-\><C-n>` first:

  | Key (terminal mode) | Action |
  |---|---|
  | `<C-h>` / `<C-j>` / `<C-k>` / `<C-l>` | Move to the window left / below / above / right |
  | `<C-w>` | Cycle to the next window |

  Each of these runs `stopinsert` and then feeds the equivalent `<C-w>` motion.

---

## Sending context to Bob

All three send commands require a live Bob terminal — they look up the
`terminal_job_id` of the tracked buffer and warn if there isn't one. After a
successful send, focus moves to the Bob window and (when `start_in_insert` is
true) enters insert mode, so you can keep typing.

| Command | Payload |
|---|---|
| `:BobSendFile` | `@path/relative/to/cwd.lua` — Bob's file-reference syntax |
| `:BobSendYank` | The raw contents of register `"` |
| `:BobSendVisual` | `path.lua:12-40` on the first line, then the selected text |

`:BobSendVisual` handles all three visual modes: charwise (`v`) trims the first
and last line to the selection columns, linewise (`V`) sends whole lines, and
blockwise (`<C-v>`) slices every line to the selected virtual columns. If called
outside visual mode it re-selects the last selection with `gv`.

A trailing `\r` is appended to every payload, which submits the prompt in Bob's
TUI.

---

## Task history

`:BobTaskHistory` reads Bob's SQLite database directly through the LuaJIT FFI —
no `sqlite.lua` or CLI shelling required, just `libsqlite3` on the system.

**Database:** `db_path`, or `$HOME/.bob/db/bob.db`.

**Which tasks appear.** A task is listed when all of the following hold:

1. It isn't archived (`time_archived IS NULL`).
2. Its workspace equals Neovim's current working directory. The workspace is
   resolved as the first non-empty of `tasks.directory`, `env.workspace`, or
   `env.staticEnvInfo.primaryWorkspace`.
3. It has at least one `user` or `assistant` message (empty tasks are hidden).

Results are ordered by `updated_at DESC` and capped at `task_history_limit`.

**Row label.** `status` padded to 9 columns, then the title, which is the first
non-empty of `tasks.title`, `tasks.first_message`, or the task id, with newlines
flattened to spaces.

**Preview.** Selecting a row loads up to `task_preview_messages` `user`/
`assistant` turns (oldest first, empty content skipped) and renders them as
labeled boxes:

```
╭─ You ─────────────────────────────
│ refactor the picker dispatch so au…
│ to falls back cleanly

╭─ Bob ─────────────────────────────
│ Sure — I'll extract each backend i…
```

Each message is flattened to a single line and clipped to two display lines with
an ellipsis. Header and gutter are highlighted per role (see
[Highlight groups](#highlight-groups)).

Confirming a row runs `bob chat --resume <task-id>` in a fresh split.

---

## Pickers

`picker = "auto"` resolves in this order:

```
snacks.nvim  →  telescope.nvim  →  builtin float  →  vim.ui.select
```

| Value | Behavior |
|---|---|
| `"auto"` | First available of snacks → Telescope → builtin. |
| `"snacks"` | Force snacks.nvim. If it errors, warns and falls back to builtin. |
| `"telescope"` | Force Telescope. If Telescope isn't installed, this is a **hard error** (no fallback); other Telescope errors warn and fall back to builtin. |
| `"builtin"` | Always the plugin's own float — or `vim.ui.select` when `task_preview = false`, or the terminal is smaller than 100 columns × 30 lines. |

### Builtin float keymaps

The float is two rounded panels — task list on the left (38% width), preview on
the right (52%), 80% of the editor height, centered.

| Key | Action |
|---|---|
| `<CR>` | Resume the task under the cursor |
| `<Esc>` / `q` / `<C-c>` | Dismiss |

The preview refreshes on `CursorMoved` with a 50 ms debounce, so holding `j`
through a long list doesn't hammer SQLite. Closing the list window (however it
happens) tears down both panels, both scratch buffers, and the autocmd group,
then restores focus to the window you started from.

---

## Highlight groups

Defined by `setup()` with `default = true`, linked to semantic groups so they
follow any colorscheme:

| Group | Links to | Used for |
|---|---|---|
| `BobPreviewUserBorder` | `Title` | `╭─ You ─` header and `│` gutter |
| `BobPreviewBobBorder` | `@function` | `╭─ Bob ─` header and `│` gutter |

Override them after `setup()`:

```lua
require("bob").setup({})
vim.api.nvim_set_hl(0, "BobPreviewUserBorder", { fg = "#89b4fa", bold = true })
vim.api.nvim_set_hl(0, "BobPreviewBobBorder",  { fg = "#a6e3a1" })
```

---

## How the `bob` command is built

Every argument is single-quoted and internal quotes escaped before reaching the
shell.

| Invocation | Command |
|---|---|
| `:BobShell` | `bob chat --mode 'agent'` |
| `:BobShell fix the tests` | `bob chat 'fix the tests' --mode 'agent'` |
| With `team_id = "abc"` | `bob chat --mode 'agent' --team-id 'abc'` |
| `:BobResumeLatest` | `bob chat --resume 'latest' --mode 'agent'` |
| Resuming task `t_123` | `bob chat --resume 't_123' --mode 'agent'` |

`chat_mode` and `team_id` are appended to resume invocations too — `--team-id`
is session-level authentication that a resumed task still needs, and `--mode` is
applied from the session config on resume just as on a fresh chat.

`--resume latest` is handled by Bob itself: it selects the most recent task in
the current workspace.

---

## Module map

| File | Responsibility |
|---|---|
| `lua/bob.lua` | Public API, `setup()`, user commands, picker dispatch |
| `lua/bob/config.lua` | Defaults and the `BobConfig` type annotations |
| `lua/bob/terminal.lua` | Command construction, split creation, session state, toggle/close |
| `lua/bob/send.lua` | Job-id lookup, visual-selection extraction, prompt building |
| `lua/bob/db.lua` | FFI `libsqlite3` bindings; task and message queries |
| `lua/bob/preview.lua` | Box-drawing preview formatting + highlight application |
| `lua/bob/picker/builtin.lua` | Two-panel floating picker |
| `lua/bob/picker/snacks.lua` | snacks.nvim picker adapter |
| `lua/bob/picker/telescope.lua` | Telescope picker adapter |

Session state lives in `require("bob.terminal").bob_state` (`win`, `buf`,
`prev_win`); picker state in `require("bob.picker.builtin").picker_state`.

---

## Troubleshooting

**`Bob Shell not found. Please install it first.`**
`bob` isn't on the `$PATH` Neovim sees. Check with `:!which bob` (not just your
shell — GUI Neovim may inherit a different environment).

**`could not load libsqlite3: ...`**
Install the SQLite runtime library: `brew install sqlite` (macOS),
`apt install libsqlite3-0` (Debian/Ubuntu), `dnf install sqlite-libs` (Fedora),
`pacman -S sqlite` (Arch).

**`could not open bob.db at <path>`**
Bob hasn't created its database yet (run `bob chat` once), or it lives somewhere
else — point `db_path` at it.

**`Bob: no task history found.`**
The query is scoped to Neovim's `getcwd()`. Open Neovim from the same directory
Bob ran in, or `:cd` there first. Archived and message-less tasks are also
hidden.

**Picker opens as a plain list instead of the float**
The builtin float requires at least 100 columns and 30 lines and
`task_preview = true`; below that it degrades to `vim.ui.select`.

**Bob's TUI looks broken or crashes**
Increase `split_size` — anything under 50 is clamped, but a wider split helps.

**Sends do nothing / `Bob: no active terminal session.`**
There's no live Bob buffer. Open one with `:BobShell` first; note that
`:BobClose` keeps the session, but opening a new one discards the old buffer.

---

## Known limitations

- A single Bob session at a time; opening a new one replaces the old.
- Task history is scoped to the exact `getcwd()` string — no subdirectory or
  symlink-resolved matching.
- The preview flattens each message to one line and shows at most two lines of it.
- SQLite is opened and closed per query (once for the task list, once per
  preview refresh).

---

## License

MIT — see [LICENSE](LICENSE).
