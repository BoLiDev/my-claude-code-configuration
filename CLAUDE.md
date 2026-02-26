## Coding Principles

### Readability and Maintainability First

- Readability > performance. Code must be clear at first glance.

### Encapsulation is Mandatory

- Related logic fully contained; only minimal external state exposed.
- If someone needs internals to use a module, the design is not ready.

### Clarity Over Cleverness

- No clever tricks, hidden coupling, or implicit behavior.
- Code communicates intent. If it needs explanation, it needs refactoring.

### Naming is a Design Tool

- Names eliminate the need for comments.
- Function names: describe intent, not mechanics.
- Variable names: represent meaning, not data shape.

### Single Responsibility

- File: one concern. Module: one purpose. Function: one thing.

### File Responsibility (Frontend)

Each file belongs to one category: `components` | `hooks` | `stores` | `services` | `utils` | `constants` | `types` | `styles` | `context`

When a file outgrows its category, promote it to a folder.

### React State Management

- **Custom Hooks:** state is local, < 150 lines, < 3 levels prop drilling
- **MobX Store:** shared state, 150+ lines, or prop drilling present
- Always use `makeAutoObservable` (never decorators)
- Document store responsibilities when writing or changing a store

### TypeScript Type Safety

- Never use `any` and `as unknown as` without first trying 3+ alternatives (generics, narrowing, discriminated unions, overloads). Prefer `unknown`.
- Type names describe domain concepts: `OrderSummary` not `OrderData`.
- Prefer narrowing over `as` casts — narrowing proves correctness, `as` silences the compiler.
- Annotate return types for exported functions; infer the rest.
- Use discriminated unions for mutually exclusive states instead of optional fields.
- For `JSON.parse`, `axios.get`, `fetch`, etc. — use **zod** to validate and infer types.

## Coding Preference

### Avoid Inline Render Functions

Extract UI into separate components. Inline only when logic is tightly bound to parent or extraction causes unnecessary prop passing.
