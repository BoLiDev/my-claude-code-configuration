# Sync Manifest

## Overview

A persistent record of what the tool has installed into a specific target claude directory. Each target directory gets its own independent manifest — this is critical for supporting multiple environments (e.g., `~/.claude` vs a sandbox `.claude`) on the same machine. Enables uninstall capability and orphan detection.

## Requirements

- Stored at `<claude-dir>/.claude-sync-manifest.json` (e.g., `~/.claude/.claude-sync-manifest.json`)
- Records each installed item with: asset type (agent/command/skill/claude-md), item name, content hash (for change detection), and install timestamp
- Updated atomically after each successful install or uninstall operation — never left in a partial state
- If the manifest file does not exist, treat it as "nothing has been installed" — first run creates it
- If a manifest entry references a file that no longer exists on the machine (user manually deleted it), the entry is silently cleaned up on next run
- The manifest belongs to the machine, not the repo — it should not be committed to git `[Assumption: .gitignore is not managed by this tool — user adds it if the manifest somehow ends up in a repo path]`

## Acceptance Criteria

- After a fresh install, the manifest accurately lists every item that was installed
- After an uninstall, removed items are no longer in the manifest
- Orphaned items (in manifest but repo file deleted) are detectable by comparing manifest entries against repo contents
- The manifest survives across multiple install/uninstall cycles without corruption
- The manifest is valid JSON and human-readable for debugging
