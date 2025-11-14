# custom-status.yazi

Append a custom, right‑aligned segment to Yazi’s status bar.

This plugin executes your script asynchronously whenever the CWD changes and
renders the first line of its stdout at the far right of the status bar. It
does not block the UI.

## Install

The plugin is already placed under `plugins/custom-status.yazi`.
Enable it in `init.lua`:

```lua
require("custom-status"):setup {
  -- Optional: override the script path
  -- script = os.getenv("HOME") .. "/.loc/bin/echos.sh",
  -- Optional: debug logging (default: false)
  -- debug = true,
  -- Optional: per‑CWD cache; show 0/0 until first value, then reuse last value while recomputing (default: false)
  -- use_cache = true,
  -- Optional: render order among status children (default: 20)
  -- order = 20,
  -- Optional: async read timeout in ms (default: 2000)
  -- timeout_ms = 2000,
  -- Optional: synchronous fallback (blocks briefly on cd)
  -- sync = false,
}
```

## Behavior

- Triggers an async job on startup and on every CWD change.
- Passes the current working directory as the only argument.
- Uses only the first line of stdout.
- Non‑zero exit, empty output, or missing script hides the segment.
- Stale results are dropped if a newer CWD change occurs.
 - Uses `ui.render()` when available.

## Notes

- The `script` must be an executable path, not a shell pipeline.
- Styling inherits the status bar style; customize via `theme.toml`.
- Logs go to Yazi’s log file when `debug = true`.
