# AI Command (Yazi plugin) — Future Improvements

This is a living plan for enhancements to the `ai-command.yazi` plugin. Items are grouped and roughly prioritized.

## Now (short term)
- [ ] Foreground mode: option to run the AI command in the foreground and stream output to a Yazi preview/terminal pane.
- [ ] Cancel running job: capture PID and add a command to terminate it; show status (running/finished).
- [ ] Safer defaults: make the default command less permissive or prompt the user the first time before using `--dangerously-bypass-approvals-and-sandbox`.
- [ ] Selection-aware prompts: expose `$SELECTION` and `$CWD` to the command so prompts can reference currently selected files.
- [ ] Robust quoting: harden shell-escaping for `$USER_COMMAND`, paths with spaces, and special characters.
- [ ] Log UX: add a quick action to open the latest log, copy its path, and set retention (rotate/prune old logs).

## Next (medium term)
- [ ] Presets and templates: configurable named prompts (e.g., "summarize", "refactor"), with variables and interpolation.
- [ ] Config file: support `~/.config/yazi/ai-command.toml` (or local `.ai-command.toml`) for defaults (model, flags, templates, log retention).
- [ ] History: save recent prompts to `$XDG_STATE_HOME/yazi/ai-history.json`; provide fuzzy recall in the input UI.
- [ ] Multiple backends: simple adapter layer for Codex, OpenAI, Gemini, Llama, etc., with per-backend flags and env vars.
- [ ] Notifications: richer toasts (elapsed time, exit code, bytes written) and a follow-up toast when a background job completes.
- [ ] Error handling: better surfacing of non‑zero exits, truncated logs, missing binaries, and permission issues.

## Later (long term)
- [ ] Live preview: tail the log in a Yazi pane with colorized output, and a toggle to detach/reattach.
- [ ] Pipeline actions: chain multiple prompts or post-process a selection (e.g., format, rename, apply patch) after AI output.
- [ ] Concurrency controls: queue or limit simultaneous jobs; per‑directory locks to avoid conflicts.
- [ ] Cross‑platform: ensure Windows compatibility (PowerShell quoting, `%LOCALAPPDATA%` for state, path handling).
- [ ] Internationalization: localize prompt titles and notifications.
- [ ] Telemetry (opt‑in): minimal anonymous metrics for usage patterns to guide roadmap.

## Integrations
- [ ] Yazi keymaps: optional key bindings for "Run preset", "Open last log", "Cancel job".
- [ ] Selection piping: pass list of selected files via temp file or env var for tools that accept `@filelist` inputs.
- [ ] Open-in-editor: quick action to open the log or generated file(s) in `$EDITOR`.

## Security
- [ ] Command allowlist: optional allowlist for executables when overriding `AI_RUN_CMD`.
- [ ] Env controls: whitelist which env vars are forwarded; redact secrets in logs.
- [ ] Safe mode: a toggle that forbids destructive operations unless explicitly confirmed per run.

## Quality & Release
- [ ] Lint/format: add `stylua` and a lint check to CI.
- [ ] Minimal tests: e2e smoke scripts that spawn Yazi headlessly to exercise the plugin entry.
- [ ] Versioning: semantic versioning, changelog, and release notes.
- [ ] README improvements: examples for presets, config, and log management.

## Implementation Notes
- Prefer `$XDG_STATE_HOME/yazi/` with fallback to `~/.local/state/yazi/` for state (logs, history).
- Keep the `AI_RUN_CMD` contract stable; add new placeholders like `$SELECTION`, `$CWD`, and `$PROMPT` without breaking existing usage.
- Ensure background launch never blocks Yazi; capture PID and write alongside the log (e.g., `.../ai-command-<ts>.pid`).
- Quote defensively and test with spaces, quotes, and non‑ASCII paths.

---

Have other ideas? Open a PR or add to this document.
