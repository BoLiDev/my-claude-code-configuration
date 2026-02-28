# Technical Decisions Checkpoint Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an interactive technical decisions checkpoint to `ralph_impl` that surfaces external dependency choices for user confirmation before code is written.

**Architecture:** Insert a new Step 3 between the current Step 2 (Investigate) and Step 3 (Implement) in `commands/ralph_impl.md`. The step synthesizes investigation findings, identifies external dependency decisions, and either pauses for confirmation or states "no decisions needed" and continues.

**Tech Stack:** Markdown only — this is a prompt engineering change to `ralph_impl.md`.

---

## Tasks

### Task 1: Insert Step 3 — Technical Decisions

**Files:**
- Modify: `commands/ralph_impl.md:78` (insert new section before current `### Step 3: Implement`)

**Step 1: Insert the new Step 3 section**

Add the following between current Step 2 (ends at line 77) and current Step 3 (starts at line 79):

```markdown
### Step 3: Technical Decisions

Based on your investigation, assess whether this task introduces **external dependencies** — new libraries, frameworks, APIs, or CLI tools not already in the project.

Consider:
- Does the task require capabilities not covered by existing dependencies?
- Are there multiple viable libraries for a needed capability?
- Does the spec reference external services or APIs not yet integrated?

**If decisions exist** — present them and wait for user confirmation:

\```
## Technical Decisions

Based on my investigation, this task requires the following technical decisions:

1. **[Capability needed]**: [Why it's needed]
   - Option A: `library-a` — [brief rationale]
   - Option B: `library-b` — [brief rationale]
   - Recommendation: Option A — [why]

Please confirm or adjust before I proceed with implementation.
\```

**If no decisions are needed** — state and proceed:

\```
No new external dependencies needed for this task — proceeding with implementation.
\```

This step focuses on external dependencies only. Internal patterns (file structure, design patterns) are already handled by `codebase-pattern-finder` in Step 2.
```

**Step 2: Verify the new section reads correctly**

Read `commands/ralph_impl.md` and verify the new Step 3 is properly placed between Step 2 (Investigate) and the step that was previously Step 3 (Implement).

**Step 3: Commit**

```bash
git add commands/ralph_impl.md
git commit -m "feat: add Technical Decisions checkpoint (Step 3) to ralph_impl"
```

---

### Task 2: Renumber Steps 3-6 to 4-7

**Files:**
- Modify: `commands/ralph_impl.md` (4 heading changes + body references)

**Step 1: Rename all existing step headings after the new Step 3**

Change these headings in order:
- `### Step 3: Implement` → `### Step 4: Implement`
- `### Step 4: Validate` → `### Step 5: Validate`
- `### Step 5: Update Plan` → `### Step 6: Update Plan`
- `### Step 6: Commit Checkpoint` → `### Step 7: Commit Checkpoint`

**Step 2: Update body text references to old step numbers**

In Step 4 (Implement), the text references "test requirements (gathered in Step 2)". This is still correct — Step 2 is Investigate, unchanged.

Scan the entire file for any other step-number references and update if needed.

**Step 3: Verify renumbering is consistent**

Read the full file. Verify steps go 0, 1, 2, 3, 4, 5, 6, 7 with no gaps or duplicates.

**Step 4: Commit**

```bash
git add commands/ralph_impl.md
git commit -m "refactor: renumber ralph_impl steps 3-6 to 4-7 after new checkpoint"
```

---

### Task 3: Update the example interaction flow

**Files:**
- Modify: `commands/ralph_impl.md` (Example Interaction Flow section, ~line 185-225)

**Step 1: Insert the technical decisions checkpoint into the example**

The current example flow goes:
```
[Spawns codebase-pattern-finder for error handling patterns]
[Spawns codebase-analyzer on src/main/stt.ts]
[Implements retry logic + E2E test]
```

Insert between the codebase analysis and implementation:
```
No new external dependencies needed for this task — proceeding with implementation.
```

This demonstrates the "no decisions" path (the common case).

**Step 2: Verify example flow is coherent**

Read the example section. Verify the narrative flows naturally with the new checkpoint line.

**Step 3: Commit**

```bash
git add commands/ralph_impl.md
git commit -m "docs: update ralph_impl example flow with technical decisions checkpoint"
```
