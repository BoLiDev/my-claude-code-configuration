# Technical Decisions Checkpoint in ralph_impl

## Problem

The Ralph implementation phase (`ralph_impl`) jumps from codebase investigation directly into writing code. Technical decisions about external dependencies — which libraries to use, which APIs to integrate — are never explicitly confirmed with the user. If the system makes a wrong choice, the implementation work is wasted, and the mistake is only caught at the commit checkpoint (Step 6) when all code is already written.

Specs and planning phases intentionally don't address these decisions (they define WHAT, not HOW), so there's no earlier phase where they'd be resolved.

## Solution

Add a new **Step 3: Technical Decisions** to `ralph_impl.md`, placed between the current Step 2 (Investigate) and the former Step 3 (Implement). The former Steps 3-6 are renumbered to Steps 4-7.

### Placement rationale

After Step 2, the system has maximum context:
- Full codebase understanding (from Step 0: Orient)
- Selected task and relevant specs (from Steps 1-2)
- Existing patterns and dependencies (from codebase-pattern-finder)

This is the ideal moment to surface dependency decisions — deep enough to know what's needed, early enough to avoid wasted implementation.

### Behavior

The system synthesizes its investigation findings and identifies **novel technical decisions** — anything the project has never done before. Two categories:

**External dependencies** — new libraries, frameworks, APIs, or CLI tools:
- Any new external dependency is inherently novel and always requires confirmation
- Multiple viable libraries for a needed capability should be presented as options

**New internal mechanisms** — patterns or approaches not yet used in the codebase:
- The key signal comes from `codebase-pattern-finder` (Step 2): if it found no similar patterns, the mechanism is new
- Examples: first use of event sourcing, first WebSocket implementation, first background worker
- If the codebase already uses a similar pattern, follow it — no decision needed

### Output format

**When decisions exist** — present and wait for confirmation:

```
## Technical Decisions

Based on my investigation, this task requires the following technical decisions:

1. **[Capability or mechanism]**: [Why it's needed]
   - Option A: [approach] — [brief rationale]
   - Option B: [approach] — [brief rationale]
   - Recommendation: Option A — [why]

Please confirm or adjust before I proceed with implementation.
```

**When no decisions are needed** — state and continue automatically:

```
No novel dependencies or mechanisms for this task — proceeding with implementation.
```

### Scope

Focused on **novelty**: anything the project has never done before, whether external (new packages, API integrations) or internal (new patterns, mechanisms). If `codebase-pattern-finder` found existing patterns to follow and no new external dependencies are needed, proceed automatically. If either search came up empty, pause and confirm.

## Changes required

- Modify `commands/ralph_impl.md`: insert new Step 2.5, renumber Steps 3-6 to 4-7, update example interaction flow
