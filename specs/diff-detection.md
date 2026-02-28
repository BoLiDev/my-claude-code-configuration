# Diff Detection

## Overview

Compares repo state against the target claude directory for each syncable item. The target is user-provided (defaults to `~/.claude`) to support multiple environments (e.g., external vs sandbox) on the same machine. Produces a status classification that drives the UI display and pre-selection logic.

## Requirements

- Compare each item in the repo against its counterpart on the machine, producing one of: `new`, `modified`, `unchanged`, `orphaned`
  - `new` — exists in repo, not on machine
  - `modified` — exists in both, content differs
  - `unchanged` — exists in both, content identical
  - `orphaned` — exists in manifest (was previously installed) but no longer exists in repo
- For `modified` items, generate a human-readable diff (unified format) that can be displayed in the install flow
- Handle the path/naming conventions for each asset type:
  - CLAUDE.md: repo `CLAUDE.md` ↔ machine `claude.md` (case difference)
  - Agents: repo `agents/*.md` ↔ machine `agents/*.md`
  - Commands: repo `commands/*.md` ↔ machine `commands/*.md`
  - Skills: repo `skills/<name>/SKILL.md` ↔ machine `skills/<name>/SKILL.md`
- Orphan detection requires reading the sync manifest to know what was previously installed

## Acceptance Criteria

- Each item is classified into exactly one of the four statuses
- Modified items include a unified diff string for display
- Items that exist on the machine but were NOT installed by this tool (not in manifest) are ignored — not shown, not touched
- The CLAUDE.md case-difference (`CLAUDE.md` → `claude.md`) is handled transparently
