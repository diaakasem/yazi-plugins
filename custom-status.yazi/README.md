# custom-status.yazi

Append a custom, right-aligned segment to Yazi's status bar.

Runs a shell script with the current working directory as the only argument and
renders its stdout at the far right of the status bar.

## Install

The plugin is already placed under `plugins/custom-status.yazi`.
Enable it in `init.lua`:

```lua
require("custom-status"):setup {
  -- Optional: override the script path
  -- script = os.getenv("HOME") .. "/.loc/bin/echos.sh",
}
```

## Behavior

- Calls your script whenever the CWD changes.
- Passes the current working directory as the only argument.
- Uses only the first line of stdout.
- Non‑zero exit or missing script results in no extra segment.

## Notes

- Right alignment is handled via `ui.Text(...):align(ui.Align.RIGHT)`.
- Styling inherits the status bar style; customize via `theme.toml` if needed.

