# Uninstall Flow

## Overview

Allows the user to selectively remove previously-installed items from the target claude directory. The target is user-provided (defaults to `~/.claude`) to support multiple environments on the same machine. Only items tracked in that target's sync manifest are offered for removal — locally-created items are never touched.

## Requirements

- Entry point is `./install.sh uninstall` (or `./install.sh uninstall /path/to/.claude`)
- Read the sync manifest to determine which items are managed by this tool
- Present managed items grouped by category (Agents → Commands → Skills), each as a multi-select stage
- CLAUDE.md is excluded from uninstall — it is always managed as a whole and not individually removable `[Assumption: users won't want to uninstall their global instructions — revisit if needed]`
- For each selected item, delete the corresponding file(s) from the target directory
- Show a confirmation summary before deleting anything
- Update the sync manifest to remove uninstalled entries
- If the manifest is empty or missing, inform the user that nothing is managed and exit gracefully

## Acceptance Criteria

- Running `./install.sh uninstall` shows only items that were previously installed by this tool
- Locally-created items on the machine (not in manifest) are never shown or affected
- No files are deleted until the user confirms
- The manifest is updated after successful removal
- Uninstalling a skill removes the entire skill directory, not just SKILL.md
