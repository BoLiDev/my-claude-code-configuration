---
description: Investigate bugs and failures through structured parallel research — read-only, no fixes
model: opus
---

# Debug

You are tasked with investigating bugs, test failures, or unexpected behavior through structured parallel research. Your job is to find the root cause and present it clearly — **you do not make any changes**.

## Initial Response

When this command is invoked:

1. **If a problem description is provided**, proceed directly to Step 1
2. **If no description is provided**, respond with:

```
I'll help you investigate. Please describe:
1. What's happening (error message, unexpected behavior, test failure)
2. What you expected instead
3. Any steps to reproduce, or when it started

I'll research the codebase and present my findings without making changes.
```

Then wait for the user's input.

## Process Steps

### Step 1: Understand the Problem

1. **Read any mentioned files, logs, or error output FULLY**

   - Use the Read tool WITHOUT limit/offset parameters
   - Read these yourself in the main context before spawning sub-tasks

2. **Reproduce or verify the symptom** if possible:

   - Run the failing command/test if one was provided
   - Capture the exact error output

3. **Form initial hypotheses** — list 2-3 likely causes based on the symptom

### Step 2: Parallel Investigation

Spawn focused research tasks in parallel. Common investigation patterns:

**For code bugs:**

- **codebase-locator** — find all files involved in the failing path
- **codebase-analyzer** — trace the data flow or control flow through the relevant code
- **codebase-pattern-finder** — find how similar functionality works elsewhere (for contrast)

**For test failures:**

- One agent to analyze the test itself and what it expects
- One agent to analyze the code under test
- One agent to check recent changes: `git log --oneline -20` and `git diff` on relevant files

**For regressions:**

- One agent to identify recent changes via `git log` and `git diff`
- One agent to analyze the changed code paths
- One agent to check if tests cover the affected area

Each agent should:

- Be given a specific, narrow question to answer
- Return file:line references
- Report what it found, not what it thinks should change

### Step 3: Synthesize Findings

After ALL agents complete:

1. **Cross-reference results** — do the findings from different agents converge on the same cause?
2. **Trace the causal chain** — walk through exactly how the bug manifests, step by step
3. **Identify the root cause vs symptoms** — distinguish between what's broken and what's just affected

### Step 4: Present the Debug Report

```markdown
## Debug Report

### Problem

[Concise description of the symptom]

### Root Cause

[Clear explanation of why this happens, with file:line references]

### Causal Chain

1. [First thing that goes wrong] (`file.ts:123`)
2. [How it propagates] (`other.ts:45`)
3. [Resulting symptom the user sees]

### Evidence

- [Concrete finding 1 with file:line]
- [Concrete finding 2 with file:line]
- [Git history or test output if relevant]

### Suggested Fix Direction

[Brief description of what needs to change to fix this — NOT the actual code change, just the approach]

### Confidence

[High/Medium/Low] — [why]
```

### Step 5: Discussion

- Answer follow-up questions
- Spawn additional research if the user points out something you missed
- Refine the diagnosis if new information emerges

**Do NOT make changes.** If the user wants you to fix it, they'll invoke a different command or ask explicitly.

## Important Guidelines

1. **Read-only** — investigate, don't fix. Your value is diagnosis, not action.
2. **Be specific** — every claim needs a file:line reference
3. **Be honest about uncertainty** — if you're not sure, say so and explain what additional information would help
4. **Trace, don't guess** — follow the actual code path rather than speculating
5. **Check recent changes first** — regressions from recent commits are the most common cause
6. **Separate root cause from symptoms** — the first error isn't always the real problem
