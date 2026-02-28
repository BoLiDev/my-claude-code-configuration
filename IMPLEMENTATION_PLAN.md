# Implementation Plan

> Generated from specs in `specs/`. Regenerate with `/ralph_plan` if stale.

## Tasks

- [x] **Scaffold CLI foundation with subcommand routing and gum helpers**

  - Purpose: Establishes the shell that all other features plug into — without this, nothing else can be built
  - Scope: `install.sh` (rewrite)
  - Acceptance considerations:
    - `./install.sh` with no args routes to install flow
    - `./install.sh uninstall` routes to uninstall flow
    - `./install.sh /custom/path` passes the path through
    - `./install.sh uninstall /custom/path` handles both subcommand + path
    - Missing `gum` prints `brew install gum` and exits non-zero
    - Ctrl+C at any point during later flows leaves no partial state (trap cleanup)
    - Styled output functions (section headers, status badges, success/error) are defined and reusable

- [x] **Implement sync manifest read/write operations**

  - Purpose: The manifest is the foundation for diff detection, orphan detection, and uninstall — both major flows depend on it
  - Scope: New manifest functions in `install.sh` or a sourced lib, JSON format at `<claude-dir>/.claude-sync-manifest.json`
  - Acceptance considerations:
    - First run with no manifest creates it cleanly
    - Each entry records: asset type, item name, content hash, install timestamp
    - Manifest is valid JSON and human-readable
    - Manifest entries referencing manually-deleted files are cleaned up on next read
    - Writes are atomic (write to temp, then `mv`) — interrupted writes don't corrupt
    - Manifest survives multiple install/uninstall cycles without corruption

- [x] **Implement diff detection engine**

  - Purpose: Classifies every syncable item by status, which drives the UI pre-selection and orphan surfacing
  - Scope: New diff functions, covers all 4 asset types (CLAUDE.md, agents, commands, skills)
  - Acceptance considerations:
    - Each item classified as exactly one of: new, modified, unchanged, orphaned
    - Modified items include a unified diff string
    - Items on the machine that were NOT installed by this tool (not in manifest) are ignored
    - CLAUDE.md case difference (`CLAUDE.md` → `claude.md`) handled transparently
    - Orphaned items (in manifest but no longer in repo) correctly detected
    - Skills use directory structure (`skills/<name>/SKILL.md`), not flat files

- [ ] **Build interactive install flow with 4-stage wizard**

  - Purpose: The primary user-facing feature — replaces the current batch copy with a diff-aware, selective install
  - Scope: `install.sh` install flow, depends on tasks 1-3
  - Acceptance considerations:
    - 4 stages in order: CLAUDE.md → Agents → Commands → Skills
    - CLAUDE.md stage shows diff if modified, auto-proceeds (no selection)
    - Other stages show multi-select with status badges via `gum choose --no-limit`
    - New + modified items pre-selected; unchanged items unchecked by default
    - Orphaned items shown with "will be removed" label, pre-selected for removal
    - Final summary shows all planned actions; `gum confirm` before any file changes
    - No files modified until confirmation
    - Manifest updated after successful apply
    - Completion message shows counts (installed/updated/removed)

- [ ] **Build uninstall flow**

  - Purpose: Allows selective removal of previously-installed items without touching locally-created ones
  - Scope: `install.sh uninstall` subcommand, depends on tasks 1-2
  - Acceptance considerations:
    - Only manifest-tracked items shown — locally-created items never shown or affected
    - Items grouped by category: Agents → Commands → Skills
    - CLAUDE.md excluded from uninstall
    - Confirmation summary before any deletion
    - Skill uninstall removes the entire skill directory, not just SKILL.md
    - Manifest updated after removal
    - Empty/missing manifest prints "nothing is managed" and exits gracefully
