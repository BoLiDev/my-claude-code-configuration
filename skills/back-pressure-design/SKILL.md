---
name: back-pressure-design
description: Use when designing or delivering a module with business logic, to determine the right automated feedback mechanism
---

# Back Pressure Design

Back pressure is an **automated feedback loop** — when a module's output is wrong, the loop catches the error and pushes it back automatically, without relying on human inspection.

It is not synonymous with "testing." Type systems are back pressure. Compile errors are back pressure. E2E verification against a real data source is back pressure. The form doesn't matter — what matters is: **automated, fast, and genuinely capable of catching problems**.

## Non-Negotiable

Every module with business logic must actively consider back pressure. Never skip this step.

Skipping is not justified by "it's simple" or "it's obvious." Only after deliberate, documented thinking can you conclude that conventional unit tests are sufficient.

## Two Questions at Design Time

Before writing code, answer:

1. What is this module's back pressure?
2. If its output is wrong, how quickly will the feedback loop catch it?

At delivery time: back pressure must ship alongside the module. **A module without back pressure is not done.**

## Feedback Speed Tiers

| Tier             | Form                                           | Speed   |
| ---------------- | ---------------------------------------------- | ------- |
| Compile-time     | Type system, discriminated unions, zod schemas | Instant |
| Commit-time      | Unit tests + pre-commit hooks                  | Seconds |
| Integration-time | E2E verification, real data comparison         | Minutes |

Prefer faster tiers. Only fall back to slower tiers when faster ones can't provide coverage.

**Speed principle:** Back pressure must be fast enough to actually get used. Validation that's too slow gets skipped — skipped validation equals zero back pressure.

## Anti-patterns: These Do NOT Count

- Tests that only assert "got a return value" or "didn't throw" — they verify execution, not correctness
- Tests using mock data never validated against a real source — they prove the code runs, not that results are right
- Verification that requires reading console.log output by eye — it's not automated
- Validation so slow it gets commented out or skipped
