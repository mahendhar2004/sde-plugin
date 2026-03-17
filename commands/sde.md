---
description: Master SDE orchestrator — Staff-level AI engineering team for solo developers. Manages full software lifecycle from idea to production across 13 phases.
allowed-tools: Read
disable-model-invocation: true
---

# SDE — Master Orchestrator

## Live Project Context
!`cat .sde/context.json 2>/dev/null || echo '{"status": "no-project"}'`

---

## Startup Behavior

### If .sde/context.json exists (resuming a project):

Read context.json. Show the project dashboard:

```
╔══════════════════════════════════════════════════════════════╗
║  SDE PLUGIN — Project Dashboard                              ║
╠══════════════════════════════════════════════════════════════╣
║  Project:  [name]                                            ║
║  Type:     [web-only / web+mobile / web+mobile+admin]        ║
║  GitHub:   [repo URL]                                        ║
║  Notion:   [page URL]                                        ║
╠══════════════════════════════════════════════════════════════╣
║  PHASE PROGRESS:                                             ║
║  ✅ Phase 0  — Idea Analysis                                 ║
║  ✅ Phase 1  — PRD                                           ║
║  🔄 Phase 2  — Architecture (IN PROGRESS)                   ║
║  ⬜ Phase 3  — Tech Stack                                   ║
║  ⬜ Phase 4  — Data Model                                   ║
║  ⬜ Phase 5  — API Design                                   ║
║  ⬜ Phase 6  — Scaffold                                     ║
║  ⬜ Phase 7  — Implementation                               ║
║  ⬜ Phase 8  — Testing                                      ║
║  ⬜ Phase 9  — Security                                     ║
║  ⬜ Phase 10 — Performance                                  ║
║  ⬜ Phase 11 — DevOps                                       ║
║  ⬜ Phase 12 — Production Readiness                         ║
║  ⬜ Phase 13 — Iterations                                   ║
╠══════════════════════════════════════════════════════════════╣
║  CURRENT PHASE: [N] — [Name]                                 ║
║  Run /sde-[command] to continue                              ║
╚══════════════════════════════════════════════════════════════╝
```

Show phases with: ✅ (in completedPhases), 🔄 (currentPhase), ⬜ (not started).

### If no .sde/context.json (new project):

```
╔══════════════════════════════════════════════════════════════╗
║  SDE PLUGIN — Full-Stack AI Engineering Team                 ║
╠══════════════════════════════════════════════════════════════╣
║  NEW PROJECT DETECTED                                        ║
╠══════════════════════════════════════════════════════════════╣
║  QUICK START:                                                ║
║  1. Run /sde-config  → verify env & integrations            ║
║  2. Run /sde-idea    → describe your idea                   ║
║  3. Follow the phases (13 total → production)               ║
╠══════════════════════════════════════════════════════════════╣
║  OR for existing codebases:                                  ║
║  Run /sde-analyze → full codebase audit                     ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Skills Reference

| Skill | Phase | Purpose |
|-------|-------|---------|
| `/sde` | — | Dashboard; resume or start |
| `/sde-config` | Setup | One-time env setup, GitHub/Notion verification |
| `/sde-idea` | 0 | Idea analysis, project type detection, GitHub repo creation |
| `/sde-prd` | 1 | Full PRD with user stories, acceptance criteria |
| `/sde-architect` | 2 | System architecture, ADRs, component diagrams |
| `/sde-stack` | 3 | Tech stack decisions, deviation handling, npm packages |
| `/sde-datamodel` | 4 | ER diagrams, TypeORM entities, SQL DDL |
| `/sde-api` | 5 | REST endpoint design, OpenAPI 3.0 spec |
| `/sde-scaffold` | 6 | Project structure + working boilerplate code |
| `/sde-implement` | 7 | Full implementation — all modules, components, screens |
| `/sde-test` | 8 | Unit + integration + component + e2e tests, 80% coverage |
| `/sde-secure` | 9 | OWASP Top 10 audit + fixes |
| `/sde-optimize` | 10 | DB indexes, Redis caching, frontend perf, bundle |
| `/sde-devops` | 11 | Dockerfiles, GitHub Actions, AWS setup, Grafana |
| `/sde-prod` | 12 | Production readiness checklist, README, rollback runbook |
| `/sde-iterate` | 13 | Continuous improvement: refactor, coverage, perf |
| `/sde-vc` | — | Smart git: commits, branches, PRs, releases |
| `/sde-analyze` | — | Existing codebase analysis + improvement plan |
| `/sde-api-sync` | — | API contract sync checker (REST + Supabase) |
| `/sde-supabase-review` | — | Supabase schema + RLS + performance audit |
| `/sde-learn` | — | Adaptive learning: capture project learnings, personalization |
| `/sde-sde5` | — | SDE-5 protocol reference: quality checklists, ADR templates |

---

## Phase Gate Protocol

At the end of EVERY phase, display:

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE [N] COMPLETE — [Phase Name]            ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • [key output 1]                                ║
║  • [key output 2]                                ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • .sde/phases/[N]-[name].md                     ║
║  • Git committed: feature/[N]-[name]             ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase [N+1] — [Next Phase Name]           ║
╠══════════════════════════════════════════════════╣
║  [proceed] → start next phase immediately        ║
║  [refine]  → redo this phase with improvements   ║
║  [custom]  → type what you want to change        ║
╚══════════════════════════════════════════════════╝
```

---

## Inter-Skill Rules

- Always read context.json before acting; read relevant prior phase files
- Never duplicate work already completed
- Always update context.json at phase end
- Always sync to Notion after phase completion
- Always git commit at phase end
- If any autonomous action fails: log it, continue, report failure in Phase Gate box

---

## SDE-5 Operating Standard (Non-Negotiable)

All code operates at Staff Engineer level. See `/sde-sde5` for the full protocol. In brief:
- Every service explicitly handles failure modes (DB down, Redis down, timeout, invalid input at scale)
- Structured JSON logs with correlation IDs; errors have full context
- Every significant decision has an ADR with a "revisit when" trigger
- `git clone → docker-compose up` works in < 5 minutes
- 80% test coverage enforced on all services and API endpoints
