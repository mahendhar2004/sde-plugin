---
description: Phase 2 — System Architecture. Designs complete system architecture with component diagrams, data flow, auth flow, caching strategy, observability plan, and creates Architecture Decision Records.
allowed-tools: Agent, Read
disable-model-invocation: true
---

## Live Project Context
!`cat .sde/context.json 2>/dev/null || echo '{"status": "no-project"}'`

## ⛔ Phase Guard — Read This First

Before doing ANYTHING else, check:
1. Does `.sde/context.json` exist in the current directory?
2. Does `.sde/phases/0-idea.md` exist?
3. Does `.sde/phases/1-prd.md` exist?

If ANY of these are missing → STOP immediately and output:
```
⛔ Run /sde-idea then /sde-prd before running /sde-architect.

Make sure you're in the correct project directory.
```
Do NOT proceed past this point.

If all three exist → read them and continue.

---

## Agent Invocation

Use the **Agent tool** to spawn one agent:

### Architect Agent
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/architect-agent.md for your full identity and standards.
Also read:
- ~/.sde-plugin/context/api-standards.md
- ~/.sde-plugin/references/adr-template.md

Your task: Design the complete system architecture for this project.

Project context: Read .sde/context.json, .sde/phases/0-idea.md, and .sde/phases/1-prd.md.

Produce:
1. Architecture overview with ASCII diagram
2. Component breakdown with responsibilities
3. ADR (Architecture Decision Record) for key decisions — use the adr-template
4. Data flow diagrams for critical paths
5. Failure mode analysis for each component
6. Technology decisions with justifications

Save architecture to .sde/phases/2-architecture.md and ADRs to .sde/adr/.
```

---

## What This Phase Produces

- Modular monolith architecture decision with rationale (see architect-agent.md for pattern details)
- ASCII component diagram: client layer → gateway → application → data/cache → observability
- Service responsibilities table with tech and deployment targets
- Data flow diagram: request → guard → validation → service → cache → DB → response
- Auth flow diagrams: login, refresh, logout sequences
- Caching strategy table: key patterns, TTLs, invalidation triggers per data type
- Rate limiting strategy table: limits per endpoint type
- Observability plan: Prometheus metrics, Loki logs, Sentry errors, health checks
- CI/CD pipeline overview (push → CI → PR → CD → health check)
- Three ADRs: ADR-001 architecture pattern, ADR-002 auth strategy, ADR-003 caching strategy

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 2 COMPLETE — System Architecture       ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • Modular monolith architecture designed        ║
║  • Component + data flow diagrams created        ║
║  • Auth flow (JWT + refresh rotation)            ║
║  • Caching strategy (Redis, TTL per type)        ║
║  • 3 ADRs created                                ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • .sde/phases/2-architecture.md                 ║
║  • .sde/adr/ADR-001, ADR-002, ADR-003            ║
║  • Notion sub-page: "Architecture — Phase 2"     ║
║  • Git committed: feature/2-architecture         ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 3 — Tech Stack Decision             ║
╠══════════════════════════════════════════════════╣
║  [proceed] → start tech stack selection          ║
║  [refine]  → improve architecture                ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
