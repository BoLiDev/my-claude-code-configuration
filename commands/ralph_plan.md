---
description: Generate an implementation plan from specs through interactive gap analysis
model: opus
---

# Generate Implementation Plan

You are tasked with creating an `IMPLEMENTATION_PLAN.md` through interactive gap analysis. Your goal is to compare specs against existing code, identify what's missing or incomplete, break gaps into prioritized tasks with acceptance considerations, and produce a plan that guides the building phase.

You should verify before assuming, and work collaboratively with the user to confirm findings before writing the plan.

## Initial Response

When this command is invoked:

1. **Check if a specs path was provided**:

   - If a path was provided as a parameter, verify it exists and contains spec files
   - Immediately read all spec files FULLY
   - Begin the context gathering process

2. **If no parameter provided**, respond with:

```
I'll help you create an implementation plan. First, I need to locate the specs.

Please provide the path to your specs directory or files (e.g., `specs/`, `docs/specs/topic.md`).

I'll analyze the specs against existing code, identify gaps, and work with you to build a prioritized plan.
```

Then wait for the user's input.

## Process Steps

### Step 1: Context Gathering (Orient)

1. **Read all spec files immediately and FULLY**:

   - **IMPORTANT**: Use the Read tool WITHOUT limit/offset parameters to read entire files
   - **CRITICAL**: DO NOT spawn sub-tasks before reading these files yourself in the main context
   - **NEVER** read files partially

2. **Read existing `IMPLEMENTATION_PLAN.md`** (if present):

   - Understand what's already been planned or completed
   - Note items marked done vs pending

3. **Spawn parallel research tasks to study the codebase**:

   Before presenting any analysis, use specialized agents to research in parallel:

   - Use **codebase-analyzer** agents to understand existing implementations (scope by relevant directories, not the whole repo)
   - Use **codebase-locator** agents to find files related to each spec topic
   - **CRITICAL**: For each spec topic, search the codebase to verify what's already implemented. DO NOT assume anything is missing without code search confirmation.

   Prefer few, focused agents over many scattered ones. Each agent should have a clear, singular research objective and return a structured summary.

4. **Read all results from research tasks fully into main context**

### Step 2: Gap Analysis (Interactive Checkpoint)

1. **Compare specs against code**:

   - For each spec, identify what's implemented, partially implemented, or missing
   - Search for TODOs, placeholders, minimal implementations, and incomplete features
   - Check for inconsistencies between specs and existing code

2. **Present your gap analysis**:

   ```
   Here's what I found comparing specs against the current codebase:

   **Spec: [topic-name]**
   - ✅ Implemented: [what exists and works]
   - ⚠️ Partial: [what exists but is incomplete — with evidence]
   - ❌ Missing: [what doesn't exist — verified by code search]

   **Spec: [topic-name]**
   - ...

   **Key Observations**:
   - [Cross-cutting concern or dependency discovered]
   - [Pattern or inconsistency noticed]

   Does this match your understanding? Anything I've missed or misidentified?
   ```

3. **Wait for user confirmation** before proceeding. If the user corrects any finding:

   - DO NOT just accept the correction
   - Spawn new research tasks to verify if needed
   - Only proceed once you've confirmed the facts yourself

### Step 3: Task Breakdown & Prioritization (Interactive Checkpoint)

1. **Break gaps into discrete tasks**:

   Each task should be one unit of work — implementable in a single focused session. Apply the scope test: can you describe the task in one sentence without "and" conjoining unrelated work?

2. **For each task, determine acceptance considerations**:

   Think carefully about what scenarios must work when this task is done. These are NOT test code — they describe conditions the implementation must satisfy.

   - What edge cases must be handled?
   - What user stories must work end-to-end?
   - What failure modes need graceful handling?

3. **Present the prioritized task list**:

   ```
   Here's the proposed task breakdown, sorted by priority:

   1. **[Task name]**
      - Purpose: [why this matters]
      - Scope: [what files/modules are involved]
      - Acceptance considerations:
        - Edge case: [specific scenario]
        - User story: [how the user interacts with this]

   2. **[Task name]**
      - ...

   Priorities are based on: dependencies (what must exist first),
   risk (what's most likely to surface issues), and value (what
   delivers the most user-facing impact).

   Would you like to adjust priorities, split/merge tasks, or add missing ones?
   ```

4. **Iterate** until the user is satisfied with task breakdown and priorities.

### Step 4: Write Plan (Final Review)

1. **Generate `IMPLEMENTATION_PLAN.md`** at project root:

   One `[ ]` checkbox per task. Sub-items are descriptive context, not separate checkable items.

   ```markdown
   # Implementation Plan

   > Generated from specs in `[specs-path]`. Regenerate with `/ralph_plan` if stale.

   ## Tasks

   - [ ] **Task name**

     - Purpose: ...
     - Scope: ...
     - Acceptance considerations:
       - Edge case: ...
       - User story: ...

   - [ ] **Task name**
     - ...
   ```

2. **Present the written plan** for final review:

   ```
   I've written IMPLEMENTATION_PLAN.md with [N] tasks.

   Key things to check:
   - Are tasks correctly prioritized?
   - Are acceptance considerations specific enough to guide testing later?
   - Is anything out of scope that crept in?
   - Is anything missing?
   ```

3. **Iterate based on feedback** — adjust tasks, priorities, or acceptance considerations as needed.

## Important Guidelines

1. **Don't Assume Not Implemented**:

   This is the most critical rule. Before claiming anything is missing, search the codebase with subagents. False "missing" items waste building iterations and erode trust in the plan.

2. **Be Interactive**:

   - Don't write the plan in one shot
   - Get confirmation on gap analysis first
   - Get confirmation on task breakdown second
   - Only then write the plan file
   - Allow course corrections at every step

3. **Be Thorough**:

   - Read all spec files COMPLETELY before analyzing
   - Cross-reference requirements for consistency
   - Consider dependencies between tasks
   - Look for TODOs, placeholders, and partial implementations

4. **Keep Plans Actionable**:

   - Each task = one checkbox = one unit of work for a building session
   - Sub-items are descriptive context, not separate tasks
   - Plan is disposable — if it's wrong, user runs `/ralph_plan` again

5. **Acceptance Considerations Are Behavioral**:

   - Describe WHAT must work, not HOW to implement or test it
   - Focus on edge cases and user stories that are critical to the task
   - These guide the implementation phase in choosing what tests to write
   - Keep them specific and observable: "user can X when Y" not "handle errors"

## Sub-task Spawning Best Practices

When spawning research sub-tasks:

1. **Prefer few, focused agents** over many scattered ones
2. **Each agent should have a clear, singular objective** and return a structured summary
3. **Provide detailed instructions** including:
   - Exactly what to research
   - Which spec or topic to compare against
   - Expected output format
4. **Use the right agent for each type of research**:
   - **codebase-analyzer** — Understand existing implementation details (scope to relevant directories)
   - **codebase-locator** — Find files related to a specific spec topic
   - **codebase-pattern-finder** — Find existing patterns that inform task design
5. **Wait for all tasks to complete** before synthesizing
6. **Verify sub-task results**:
   - If a sub-task returns unexpected results, spawn follow-up tasks
   - Cross-check findings against provided context
   - Don't accept results that seem incorrect

## Example Interaction Flow

```
User: /ralph_plan specs/
Assistant: Let me read your specs and analyze the codebase...

[Reads all specs fully, spawns codebase-analyzer and codebase-locator agents]

Here's what I found comparing specs against the current codebase:

**Spec: voice-recording**
- ✅ Implemented: Basic recording with MediaRecorder in src/renderer/recorder.ts
- ⚠️ Partial: Silence detection exists but threshold is hardcoded (src/main/audio.ts:42)
- ❌ Missing: Recording quality auto-adjustment (verified: no relevant code in src/)

**Spec: stt-integration**
- ✅ Implemented: Groq Whisper API call in src/main/stt.ts
- ❌ Missing: Retry logic on API failure (verified: no retry in src/main/stt.ts)

Does this match your understanding?

User: Silence detection is actually complete — the threshold is configurable via .env
Assistant: Let me verify that...

[Spawns codebase-analyzer to check .env configuration for silence threshold]

Confirmed — SILENCE_THRESHOLD in .env feeds into src/main/audio.ts. Removing from gaps.

Here's the proposed task breakdown:

1. **Add recording quality auto-adjustment**
   - Purpose: Optimize audio quality for STT accuracy across different environments
   - Scope: src/main/recorder.ts
   - Acceptance considerations:
     - Edge case: Very noisy environment should still produce usable audio
     - Edge case: Bluetooth mic with variable quality
     - User story: User speaks normally and gets accurate transcription regardless of mic

2. **Add STT retry logic**
   - Purpose: Handle transient API failures without user-visible disruption
   - Scope: src/main/stt.ts
   - Acceptance considerations:
     - Edge case: API returns 429 rate limit
     - Edge case: Network timeout mid-request
     - User story: Brief API hiccup doesn't interrupt the user's flow

Would you like to adjust priorities or scope?

User: Looks good. Write the plan.
Assistant: Writing IMPLEMENTATION_PLAN.md...

[Writes file at project root]

I've written IMPLEMENTATION_PLAN.md with 2 tasks. Please review...
```
