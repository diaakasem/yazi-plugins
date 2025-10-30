# AI Command (Yazi plugin)

A small Yazi plugin that prompts for text and runs an AI CLI command in the current directory.

- Defaults to Codex CLI: `codex exec -m gpt-5 --dangerously-bypass-approvals-and-sandbox -C <current_dir> <input>`
- You can override the full command via the `AI_RUN_CMD` environment variable.

The command runs in the background using `nohup` and logs to
`$XDG_STATE_HOME/yazi/ai-command-<timestamp>.log` or `~/.local/state/yazi/...`.
Notifications show when it starts and where the log is saved.

## Requirements

- Yazi installed and running from a terminal
- An AI CLI on `PATH`:
  - If you don’t set `AI_RUN_CMD`, Codex CLI is required (`codex --version`).
  - If you set `AI_RUN_CMD`, ensure your chosen tool is installed.

## Install

1) Copy this folder (`ai-command.yazi`) into your Yazi plugins directory, e.g. `~/.config/yazi/plugins/`.

2) Add a key binding in your `keymap.toml` (for example binds `a` then `i`):

```toml
[[manager.prepend_keymap]]
on   = ["a", "i"]
run  = "plugin ai-command"
desc = "AI command"
```

Reload Yazi or restart it to pick up the plugin and keymap.

## Usage

1) Press your keymap (e.g. `a` then `i`).
2) Enter the prompt to send to the AI tool and press Enter.
3) A notification displays when the command starts and shows the log path.

Notes
- The working directory used is Yazi’s current directory of the active pane.
- Output is written to a timestamped log file in `~/.local/state/yazi/` (or `$XDG_STATE_HOME/yazi/`).

## Customization

You can tweak behavior in two ways:

- Environment variable: set `AI_RUN_CMD` to replace everything after `nohup` and before redirection.
  - It may reference `$TARGET_DIR` and `$USER_COMMAND` (the prompt you type).
  - Example (Gemini CLI):
    - `export AI_RUN_CMD='gemini-cli --cwd "$TARGET_DIR" run "$USER_COMMAND"'`
  - Example (Codex default, for reference):
    - `codex exec -m gpt-5 --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox -C "$TARGET_DIR" "$USER_COMMAND"`
- Edit `main.lua`: adjust prompt title/position or change the default command string if desired.

## Troubleshooting

- "Failed to launch AI helper": ensure your AI tool is installed and on `PATH`.
- No log file: check write permissions under `~/.local/state/yazi/` (or set `XDG_STATE_HOME`).
- Command exits with non‑zero code: open the referenced log file for details.

## Security

By default the plugin runs Codex with `--dangerously-bypass-approvals-and-sandbox` in the current directory.
If you override `AI_RUN_CMD`, review your chosen tool’s flags and behavior for safety.
