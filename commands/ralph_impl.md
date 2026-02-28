---
description: Implement the next task from IMPLEMENTATION_PLAN.md with autonomous execution and human-gated commits
model: opus
---

# Implement from Plan

You are tasked with picking and implementing the next task from `IMPLEMENTATION_PLAN.md`. You work autonomously within a task — investigating, implementing, testing, and validating — then pause for human approval before committing.

Tests are part of the implementation, not optional. Every task must include tests that verify its acceptance criteria.

## Initial Response

When this command is invoked:

1. **Verify prerequisites exist**:

   - `IMPLEMENTATION_PLAN.md` must exist with unchecked tasks
   - `specs/` directory must exist with spec files
   - If either is missing, inform the user and suggest running `/ralph_plan` first

2. **If a parameter was provided** (e.g., a specific task name or focus area):

   - Use it as guidance for task selection
   - Still verify it against the plan

3. **Begin the Orient phase immediately**

## Process Steps

### Step 0: Orient

1. **Read `IMPLEMENTATION_PLAN.md` FULLY** to understand current state, unchecked tasks, dependencies, and prior discoveries

2. **Scan `specs/` directory** — list file names only (do NOT read spec contents yet; they will be loaded after task selection to conserve context)

3. **Spawn focused research agents** to understand the codebase around candidate tasks:

   - Use **codebase-locator** to find files relevant to the top candidate tasks
   - Use **codebase-analyzer** if deeper understanding of a specific area is needed
   - Prefer few, focused agents over many scattered ones

4. **Read all agent results into main context**

### Step 1: Select Task & Brief

Based on your orientation, determine which unchecked task to tackle next. Consider:

- Dependencies (what must exist first)
- Risk (what's most likely to surface issues)
- Value (what delivers the most impact)
- You are not strictly bound by the plan's ordering — use your judgment

**Present a brief analysis** (2-3 sentences):

- What task you selected and why
- Your high-level implementation approach

Then **immediately begin implementation** — do not wait for user confirmation.

### Step 2: Investigate

Now that a task is selected:

1. **Read the relevant spec files FULLY** — only the specs that relate to this task, not all specs. Extract:

   - Acceptance criteria (what success looks like)
   - Test requirements (what must be verified)
   - Edge cases and constraints

2. **Search the codebase thoroughly** using subagents:

   - Use **codebase-pattern-finder** to find similar implementations to follow
   - Use **codebase-analyzer** to understand code you'll be modifying
   - **CRITICAL**: Do NOT assume functionality is missing. Search first, confirm absence, then implement.

3. **Understand existing patterns and conventions** — your implementation should be consistent with the codebase

### Step 3: Implement

1. **Write implementation code** following existing patterns and conventions

2. **Write tests derived from acceptance criteria**:

   - **Prefer end-to-end (E2E) tests** — they verify real user outcomes
   - **Fall back to unit tests only** when E2E testing is genuinely impractical for the specific behavior
   - Tests must directly trace back to acceptance criteria and test requirements from the specs
   - Tests are part of the task scope, not a separate step

3. **Implement completely** — no placeholders, stubs, or TODO comments. If functionality is missing that's needed for your task, add it per the specs.

### Step 4: Validate

1. **Run the tests you just wrote** — they must all pass

2. **Run ALL project validation commands** discovered from CLAUDE.md and project configuration (package.json scripts, tsconfig, etc.):

   - Build, typecheck, lint, unit tests, e2e — whatever the project defines
   - **All existing tests must pass. No skipping, no exceptions.**
   - **For E2E tests only**: run the subset relevant to the current task, not the entire E2E suite

3. **If any validation fails**: fix the issue and re-validate. Repeat until everything passes.

4. If you cannot resolve a failure after reasonable effort, document the issue clearly and present it to the user — do NOT silently skip it.

### Step 5: Update Plan

1. **Check off completed task(s)** in `IMPLEMENTATION_PLAN.md`

2. **Note any discoveries**: new bugs found, unexpected issues, or dependencies uncovered during implementation

3. If you discover issues outside current task scope, add them as new unchecked items to the plan

### Step 6: Commit Checkpoint

Present to the user:

```
Validation: No lint errors. No typecheck errors. All unit tests passed. Relevant E2E tests passed (N).

## Changes Summary

**Task**: [task name from plan]
**What changed**: [brief list of files/modules modified]
**Tests added**: [what tests were written and what they verify]
**Key decisions**: [any notable implementation choices made]
**Discoveries**: [new issues or learnings, if any]

Ready to commit. Shall I proceed?
```

The validation line must reflect actual results. If any category was not applicable (e.g., no E2E tests for this task), state that explicitly instead of omitting it.

**Wait for user approval before committing.**

When approved:

- Stage relevant files (prefer specific files over `git add -A`)
- Commit with a descriptive message
- Do NOT push unless the user explicitly asks

After committing, inform the user:

```
To continue implementing, run `/ralph_impl` again.
```

## Important Guidelines

1. **Don't Assume Not Implemented**:

   The single most important rule. Before claiming anything is missing, search the codebase with subagents. False assumptions waste effort and create duplicate code.

2. **Tests Are Non-Negotiable**:

   Every task must include tests that verify acceptance criteria. Prefer E2E tests. All existing project tests must pass before committing. This is backpressure — it's what keeps quality high across iterations.

3. **Implement Completely**:

   No placeholders, stubs, or "TODO: implement later". Each task should be fully functional when done. Incomplete work wastes future iterations redoing the same thing.

4. **One Task Per Invocation (Preferred)**:

   Prefer completing one task per invocation for context clarity. However, if closely related tasks naturally group together, you may address them in one pass.

5. **Respect Existing Patterns**:

   Your code should look like it belongs in the codebase. Follow naming conventions, file organization, and architectural patterns already established.

6. **Keep the Plan Current**:

   `IMPLEMENTATION_PLAN.md` is the shared state between iterations. Every invocation must leave it accurate and up-to-date.

## Sub-task Spawning Best Practices

1. **Prefer few, focused agents** over many scattered ones
2. **Each agent should have a clear, singular objective** and return a structured summary
3. **Use the right agent type**:
   - **codebase-analyzer** — Understand HOW existing code works
   - **codebase-locator** — Find WHERE relevant code lives
   - **codebase-pattern-finder** — Find WHAT patterns to follow
4. **Wait for agents to complete** before synthesizing findings
5. **Verify agent results** — if something seems off, investigate further

## Example Interaction Flow

```
User: /ralph_impl
Assistant: [Reads IMPLEMENTATION_PLAN.md, scans specs/ directory, spawns research agents]

Selecting **"Add retry logic for STT API calls"** — highest-impact unchecked task,
no unresolved dependencies. Will add exponential backoff in src/main/stt.ts with
E2E test covering transient failures.

[Reads specs/stt-integration.md for acceptance criteria]
[Spawns codebase-pattern-finder for error handling patterns]
[Spawns codebase-analyzer on src/main/stt.ts]
[Implements retry logic + E2E test]
[Runs new test — passes]
[Runs full project validation — all pass]
[Updates IMPLEMENTATION_PLAN.md — checks off task]

Validation: No lint errors. No typecheck errors. All unit tests passed. Relevant E2E tests passed (2).

## Changes Summary

**Task**: Add retry logic for STT API calls
**What changed**:
- `src/main/stt.ts` — Added retry with exponential backoff
- `e2e/stt-retry.test.ts` — E2E test for retry on 429 and timeout

**Tests added**: E2E test verifying retry on transient API failures (429, ETIMEDOUT)
**Key decisions**: 3 retries with 1s/2s/4s backoff; only transient errors trigger retry
**Discoveries**: None

Ready to commit. Shall I proceed?

User: Looks good, commit it.
Assistant: [Stages files, commits]

Committed: "feat: add retry logic with exponential backoff for STT API calls"

IMPLEMENTATION_PLAN.md updated — task checked off.
To continue implementing, run `/ralph_impl` again.
```
