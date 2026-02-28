# Technical Decisions Checkpoint in ralph_impl

## Problem

The Ralph implementation phase (`ralph_impl`) jumps from codebase investigation directly into writing code. Technical decisions about external dependencies — which libraries to use, which APIs to integrate — are never explicitly confirmed with the user. If the system makes a wrong choice, the implementation work is wasted, and the mistake is only caught at the commit checkpoint (Step 6) when all code is already written.

Specs and planning phases intentionally don't address these decisions (they define WHAT, not HOW), so there's no earlier phase where they'd be resolved.

## Solution

Add a new **Step 2.5: Technical Decisions** to `ralph_impl.md`, placed between the current Step 2 (Investigate) and Step 3 (Implement). This step renumbers current Steps 3-6 to Steps 4-7.

### Placement rationale

After Step 2, the system has maximum context:
- Full codebase understanding (from Step 0: Orient)
- Selected task and relevant specs (from Steps 1-2)
- Existing patterns and dependencies (from codebase-pattern-finder)

This is the ideal moment to surface dependency decisions — deep enough to know what's needed, early enough to avoid wasted implementation.

### Behavior

The system synthesizes its investigation findings and identifies **external dependency decisions**: situations where the task requires introducing a new library, framework, API, or tool not already in the project.

It considers:
- Does the task require functionality not covered by existing dependencies?
- Are there multiple viable libraries for a needed capability?
- Does the spec reference external services or APIs not yet integrated?

### Output format

**When decisions exist** — present and wait for confirmation:

```
## Technical Decisions

Based on my investigation, this task requires the following technical decisions:

1. **[Capability needed]**: [Why it's needed]
   - Option A: `library-a` — [brief rationale]
   - Option B: `library-b` — [brief rationale]
   - Recommendation: Option A — [why]

2. **[Another decision]**: ...

Please confirm or adjust before I proceed with implementation.
```

**When no decisions are needed** — state and continue automatically:

```
No new external dependencies needed for this task — proceeding with implementation.
```

### Scope

Focused on **external dependencies** only: new packages, new API integrations, new CLI tools. Internal architectural patterns (file structure, design patterns, state management) are already handled by the existing `codebase-pattern-finder` investigation step and don't require a human gate.

## Changes required

- Modify `commands/ralph_impl.md`: insert new Step 2.5, renumber Steps 3-6 to 4-7, update example interaction flow
