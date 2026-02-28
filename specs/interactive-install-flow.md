# Interactive Install Flow

## Overview

The step-by-step wizard that walks the user through installing config from the repo to a target claude directory. The target is user-provided (defaults to `~/.claude`) to support multiple environments on the same machine. Each category is presented as a stage with diff-aware item selection. Replaces the current `install.sh`.

## Requirements

- Entry point is `./install.sh` (or `./install.sh /path/to/.claude`) — same interface as today, but now interactive
- Walk through 4 stages in order: CLAUDE.md → Agents → Commands → Skills
- **CLAUDE.md stage**: Show a diff if modified, then auto-install (no selection needed — just display and proceed)
- **Agents / Commands / Skills stages**: For each stage, display all items with their sync status (new / modified / unchanged / orphaned), then present a multi-select list using `gum choose --no-limit`
- Pre-select items that have actual changes (new + modified). Unchanged items appear but are unchecked by default
- Orphaned items (in manifest but no longer in repo) are surfaced with a "will be removed" label — pre-selected for removal
- After all stages, show a summary of planned actions and ask for final confirmation via `gum confirm`
- Apply all changes (copy/delete) only after final confirmation
- Update the sync manifest after successful apply
- Display the resolved target path at the top of the flow so the user always knows which environment they're modifying
- Display a styled completion message with counts of items installed/updated/removed

## Acceptance Criteria

- Running `./install.sh` launches an interactive multi-step flow powered by gum
- User can toggle individual items on/off within each category before applying
- No files are modified until the user confirms the final summary
- Orphaned items are detected and offered for removal
- The manifest is updated to reflect the final installed state
- Running with a custom path (`./install.sh /other/.claude`) works identically
