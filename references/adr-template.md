# Architecture Decision Record Template

Copy this template for every significant technical decision. Store in `.sde/adr/ADR-NNN-short-title.md`.

---

# ADR-[NNN]: [Decision Title]

**Date:** [YYYY-MM-DD]
**Status:** Draft | Proposed | Accepted | Deprecated | Superseded by ADR-[NNN]
**Deciders:** [Mahendhar / team members]
**Phase:** [Phase N — Phase Name]

---

## Context

[Describe the situation. What problem are we solving? What constraints exist? What are the forces at play?]

Example:
> We need to choose a state management solution for the React frontend. The app has complex user interactions, multiple data sources, and we need optimistic updates for a smooth UX. We are a solo developer and want to minimize boilerplate.

---

## Decision

[State the decision clearly and concisely in one or two sentences.]

Example:
> We will use **Zustand** for global state management, combined with **TanStack Query** for server state (cached API responses).

---

## Reasoning

[Explain why this decision was made. Include the key factors that drove it.]

Example:
> 1. Zustand has minimal boilerplate compared to Redux (no actions, reducers, providers)
> 2. TanStack Query handles server state (caching, refetching, background sync) better than Zustand can
> 3. Combined, they cover all state needs without overlap
> 4. Both have excellent TypeScript support

---

## Alternatives Considered

| Option | Pros | Cons | Rejected Because |
|--------|------|------|-----------------|
| Redux Toolkit | Mature, DevTools | Boilerplate, overkill for solo dev | Too much ceremony for current scale |
| Jotai | Atomic model, minimal | Less documentation | Team unfamiliarity |
| Context API only | Built-in, no deps | Re-render performance issues | Doesn't scale well |
| Zustand + React Query | ✅ Chosen | - | - |

---

## Consequences

### Positive
- [benefit 1]
- [benefit 2]

### Negative / Trade-offs
- [trade-off 1: what we're giving up or accepting]
- [trade-off 2]

### Neutral
- [things that don't clearly benefit or hurt]

---

## Revisit When

[Specify the condition that should trigger re-evaluation of this decision]

Example:
> Revisit when: team grows beyond 5 engineers (Redux Toolkit's structure benefits teams) OR when state complexity requires time-travel debugging.

---

## Implementation Notes

[Any specific details about how to implement this decision correctly]

Example:
> - Create stores in `src/store/` — one file per domain
> - Never put server state in Zustand — use React Query for that
> - Document store shape in types/store.types.ts

---

## References

- [Link to relevant documentation, RFC, blog post, etc.]
- [Link to related ADRs]

---

*ADR format adapted from Michael Nygard's ADR template.*
