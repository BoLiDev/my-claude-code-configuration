---
description: Generate JTBD-aligned specifications through interactive discovery
model: opus
---

# Generate Specifications

You are tasked with creating a set of JTBD-aligned specification files through an interactive, iterative process. Your goal is to deeply understand what we're building, break it into well-scoped topics of concern, and produce one `specs/*.md` file per topic.

You should be skeptical, thorough, and work collaboratively with the user to clarify the jobs-to-be-done before writing any specs.

## Initial Response

When this command is invoked:

1. **Check if parameters were provided**:

   - If a file path, URL, or description was provided as a parameter, skip the default message
   - Immediately read any provided files FULLY
   - Begin the discovery process

2. **If no parameters provided**, respond with:

```
I'll help you define specifications for what we're building. Let me start by understanding the jobs-to-be-done.

Please provide any of the following:
1. A description of what you want to build (or a PRD/brief file path)
2. URLs to reference materials, APIs, or inspiration
3. Any constraints, target audience, or specific requirements

I'll research everything you provide, then work with you to break this into well-scoped specifications.
```

Then wait for the user's input.

## Process Steps

### Step 1: Context Gathering

1. **Read all mentioned files immediately and FULLY**:

   - PRDs, briefs, requirement docs
   - Existing specs or design documents
   - Any referenced data files or configs
   - **IMPORTANT**: Use the Read tool WITHOUT limit/offset parameters to read entire files
   - **CRITICAL**: DO NOT spawn sub-tasks before reading these files yourself in the main context
   - **NEVER** read files partially - if a file is mentioned, read it completely

2. **Spawn parallel research tasks to gather external context**:

   Before asking the user any questions, use specialized agents to research in parallel:

   - For each URL the user provides, spawn a Task with `subagent_type="url-reader"` (1 task per URL, max ~10 concurrent). Do NOT use `general-purpose` for URL fetching.
   - If an existing codebase is referenced, use the **codebase-analyzer** agent to understand current state (scope by relevant directories, not the whole repo)
   - If existing `specs/*` files exist, read them ALL to understand what's already defined

   Prefer few, focused agents over many scattered ones. Each agent should have a clear, singular research objective and return a structured summary.

3. **Read all results from research tasks fully into main context**

4. **Synthesize your understanding**:

   - What is the high-level goal?
   - Who is the target user/audience?
   - What outcomes do they want (Jobs to Be Done)?
   - What constraints or requirements exist?
   - What did the external research reveal?

### Step 2: JTBD Discovery & Clarification

1. **Present your understanding and ask focused questions**:

   ```
   Based on what you've shared and my research, here's my understanding:

   **What we're building**: [concise summary]
   **For whom**: [target audience/user]
   **Key JTBDs I see**:
   1. [Job to be done - outcome-oriented, not feature-oriented]
   2. [Job to be done]
   3. [Job to be done]

   **From my research**:
   - [Key insight from URL/doc research]
   - [Constraint or pattern discovered]
   - [Relevant prior art or API detail]

   **Questions I need answered**:
   - [Specific question that research couldn't answer]
   - [Ambiguity that requires human judgment]
   - [Scope decision that affects breakdown]
   ```

   Only ask questions you genuinely cannot answer through research. Prefer presenting your best understanding and letting the user correct you.

2. **If the user corrects any misunderstanding**:

   - DO NOT just accept the correction
   - Spawn new research tasks to verify if needed
   - Read any newly mentioned files or URLs
   - Only proceed once you've verified the facts yourself

3. **Iterate until JTBDs are clear and agreed upon**

### Step 3: Topic Decomposition

Once JTBDs are understood:

1. **Break each JTBD into topics of concern**:

   A topic of concern is a distinct aspect or component within a JTBD. Each topic will become one spec file.

   **Apply the Scope Test** — Can you describe the topic in one sentence without "and" conjoining unrelated capabilities?

   - ✓ "The color extraction system analyzes images to identify dominant colors"
   - ✗ "The user system handles authentication, profiles, and billing" → 3 topics

2. **Present the decomposition for review**:

   ```
   Here's how I'd break this down into specs:

   **JTBD: [Job to be done]**
   Topics:
   - `[topic-a]` — [one-sentence description]
   - `[topic-b]` — [one-sentence description]

   **JTBD: [Job to be done]**
   Topics:
   - `[topic-c]` — [one-sentence description]
   - `[topic-d]` — [one-sentence description]

   Each topic becomes one spec file in `specs/`.
   Does this decomposition feel right? Too granular? Too broad? Any missing topics?
   ```

3. **Iterate on decomposition** until the user is satisfied:

   - Merge topics if they're too granular
   - Split topics that fail the scope test
   - Add missing topics the user identifies
   - Reorder or re-parent topics across JTBDs if needed

### Step 4: Spec Writing

After decomposition is approved:

1. **For each topic, spawn a parallel subagent** to draft the spec file:

   - Provide the subagent with: full context from Steps 1-3, the specific topic scope, and all relevant research findings
   - Each subagent writes one `specs/[topic-name].md` file
   - One subagent per topic, running in parallel

2. **Spec file structure** (required sections only, keep concise):

   ```markdown
   # [Topic Name]

   ## Overview

   [What this topic covers and why it matters. Keep brief — a short paragraph, not an essay.]

   ## Requirements

   [What must be true when this is fully implemented. Behavioral, observable outcomes — not implementation details.]

   - [Requirement]
   - [Requirement]
   - [Requirement with assumption] `[Assumption: we assume X because Y — revisit if Z]`

   ## Acceptance Criteria

   [How we know this is done. Observable, verifiable outcomes that can inform test requirements during planning.]

   - [Criterion — behavioral, not implementation-specific]
   - [Criterion — behavioral, not implementation-specific]
   ```

   **Optional sections** — include only when genuinely needed:

   ```markdown
   ## Edge Cases & Constraints

   - [Edge case or constraint worth calling out explicitly]

   ## Dependencies

   - [Other topics this depends on, or external APIs/systems involved]

   ## References

   - [URLs, docs, or files that informed this spec]
   ```

3. **Spec writing principles**:

   - **Behavioral, not prescriptive**: Describe WHAT success looks like, not HOW to implement it
   - **One topic per file**: If a spec needs "and" to describe its scope, split it
   - **Acceptance criteria matter**: These become the foundation for test requirements during planning
   - **Brevity is a feature**: Specs are loaded into context every loop iteration — every extra line costs tokens and degrades performance. Aim for 30-60 lines per spec.
   - **Capture the why**: Not just what to build, but why it matters for the JTBD
   - **Mark assumptions inline**: Where a non-blocking open question was resolved with a default assumption, mark it with `[Assumption: ...]` inside the relevant requirement so it's visible but not a separate section

### Step 5: Review & Refinement

1. **Present the written specs**:

   ```
   I've created the following spec files:

   - `specs/[topic-a].md` — [one-line summary]
   - `specs/[topic-b].md` — [one-line summary]
   - `specs/[topic-c].md` — [one-line summary]

   Please review each spec. Key things to check:
   - Are the requirements complete and correct?
   - Are acceptance criteria specific enough to test against?
   - Any missing edge cases or constraints?
   - Anything out of scope that crept in?
   ```

2. **Iterate based on feedback** — be ready to:

   - Adjust requirements or acceptance criteria
   - Split or merge specs
   - Add missing topics discovered during review
   - Remove scope that doesn't belong
   - Spawn additional research tasks if new questions arise

3. **Before finalizing, verify**:

   - **Blocking open questions**: Any question that would prevent implementation or testing must be resolved. If one exists, STOP and resolve it before proceeding.
   - **Non-blocking open questions**: May proceed with a default assumption marked inline as `[Assumption: ...]`. These will surface naturally during planning/building if the assumption is wrong — the loop self-corrects.

4. **Continue refining** until the user is satisfied with all specs

## Important Guidelines

1. **Be Skeptical**:

   - Question vague requirements — "what does 'fast' mean here?"
   - Identify hidden complexity — "this sounds simple but implies X, Y, Z"
   - Challenge scope — "do we need this for the first release?"
   - Don't assume — research and verify

2. **Be Interactive**:

   - Don't write all specs in one shot
   - Get buy-in on JTBD understanding first
   - Get buy-in on topic decomposition second
   - Only then write the actual specs
   - Allow course corrections at every step

3. **Be Thorough**:

   - Read all context files COMPLETELY before analyzing
   - Research URLs and external references using parallel sub-tasks
   - Cross-reference requirements against each other for consistency
   - Ensure acceptance criteria are specific and testable

4. **Be Concise**:

   - Specs are loaded into LLM context every loop iteration
   - Verbose specs waste tokens and degrade quality
   - Say what's needed, nothing more
   - Omit optional sections unless they carry real information
   - Aim for ~30-60 lines per spec file

5. **Respect the Boundaries**:

   - Specs define WHAT, not HOW
   - Implementation details belong in the planning phase
   - Keep each spec focused on one topic of concern
   - Acceptance criteria should be behavioral outcomes, not technical checks

## Sub-task Spawning Best Practices

When spawning research sub-tasks:

1. **Prefer few, focused agents** over many scattered ones
2. **Each agent should have a clear, singular objective** and return a structured summary
3. **Provide detailed instructions** including:
   - Exactly what to research or fetch
   - What information to extract and summarize
   - Expected output format
4. **Use the right agent for each type of research**:
   - **url-reader** (`subagent_type="url-reader"`) — Fetch and summarize external URLs, docs, APIs (1 per URL)
   - **codebase-analyzer** — Understand existing implementation (scope to relevant directories)
   - **codebase-locator** — Find specific files related to a topic
5. **Wait for all tasks to complete** before synthesizing
6. **Verify sub-task results**:
   - If a sub-task returns unexpected results, spawn follow-up tasks
   - Cross-check findings against provided context
   - Don't accept results that seem incorrect

## Example Interaction Flow

```
User: /generate-specs
Assistant: I'll help you define specifications for what we're building...

User: I want to build a mood board tool for designers. Here's a rough PRD: docs/prd.md
       Also check out these for inspiration: https://moodboard.io, https://coolors.co
Assistant: Let me read that PRD and research those URLs first...

[Reads PRD fully, spawns url-reader agents for both URLs]

Based on the PRD and my research, I understand we're building a mood board creation tool
for professional designers. The key JTBDs I see are:

1. Quickly capture visual inspiration from multiple sources
2. Extract and organize color palettes from collected images
3. Arrange and present mood boards to clients

Questions I need answered:
- Is real-time collaboration a requirement or future scope?
- Should export support print-ready formats?

User: Collaboration is future scope. Yes to print export.
Assistant: Got it. Here's how I'd break this into specs:

**JTBD: Capture visual inspiration**
- `image-collection` — Importing images from files, URLs, and clipboard
- `image-organization` — Tagging, searching, and filtering collected images

**JTBD: Extract and organize colors**
- `color-extraction` — Analyzing images to identify dominant color palettes

**JTBD: Arrange and present**
- `layout-system` — Arranging images and colors on a canvas
- `sharing` — Generating shareable links and embeds
- `print-export` — Producing print-ready PDF and high-res outputs

Does this decomposition feel right?

User: Looks good. Write the specs.
Assistant: Writing specs now...

[Spawns one subagent per topic to write spec files in parallel]

I've created 6 spec files:
- `specs/image-collection.md` — Importing images from files, URLs, and clipboard
- `specs/image-organization.md` — Tagging, searching, and filtering collected images
- `specs/color-extraction.md` — Analyzing images to identify dominant color palettes
- `specs/layout-system.md` — Arranging images and colors on a canvas
- `specs/sharing.md` — Generating shareable links and embeds
- `specs/print-export.md` — Producing print-ready PDF and high-res outputs

Please review each spec...
```
