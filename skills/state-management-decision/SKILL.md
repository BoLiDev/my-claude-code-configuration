---
name: state-management-decision
description: Use when deciding between React custom hooks and MobX stores, or when unsure whether state is truly local to a component
---

# State Management Decision

## Decision Criteria

**Use Custom Hooks when ALL of the following are true:**

- State is local to a single component tree
- Total state logic is < 150 lines
- Prop drilling is shallow (< 3 levels, < 4 props)

**Use MobX Store when ANY of the following is true:**

- State is shared across multiple components or render functions
- State logic exceeds 150 lines
- Prop drilling is present or growing

## Critical: "Local" Requires Investigation — Don't Assume

Before deciding state is local, explore the codebase:

1. Read the parent component — understand how this component fits in
2. Check siblings and related components — do they need similar state?
3. Trace dependencies — what else might depend on this state?
4. Consider the domain — is this state a core business concept?
5. Check prop drilling depth:
   - Read child component/function signatures
   - Count how many props/parameters originate from parent state
   - Check if state needs to travel multiple levels deep
   - Look for functions receiving state-like parameters

State is truly local only when:

- It lives in a single component tree
- It won't be shared as the feature grows
- No other part of the app cares about it
- No significant prop drilling is required

> When in doubt, it's probably not local. Investigate first, decide second.

## Requirements

- Always use `makeAutoObservable` for MobX (never decorators)
- Document store responsibilities to the user when writing or changing a store
- Show your thinking process when making this decision
