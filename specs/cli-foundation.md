# CLI Foundation

## Overview

The shared infrastructure that all flows depend on: dependency checking, argument parsing, subcommand routing, styled output helpers, and error handling.

## Requirements

- Single entry point: `./install.sh [subcommand] [target-path]`
  - No subcommand (default) → interactive install flow
  - `uninstall` → uninstall flow
  - Target path defaults to `~/.claude` if omitted
- Check for `gum` availability on startup. If not found, print a clear installation instruction (`brew install gum`) and exit with a non-zero code
- Validate that the target claude directory exists before proceeding
- Display the resolved target path prominently at startup so the user always knows which environment they're operating on — critical when multiple environments exist
- Provide reusable styled output functions: section headers, status badges (new/modified/unchanged/orphaned), success/error messages — all using `gum style`
- Use `set -euo pipefail` for safe script execution
- Exit cleanly on Ctrl+C without leaving partial state (no files copied, manifest unchanged)

## Acceptance Criteria

- `./install.sh` with no args launches the interactive install targeting `~/.claude`
- `./install.sh uninstall` launches the uninstall flow
- `./install.sh /custom/path` installs to a custom target
- Missing `gum` produces a helpful error message, not a cryptic failure
- Invalid target directory produces a clear error
- Ctrl+C at any point leaves the machine in its pre-run state
