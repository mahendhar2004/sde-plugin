---
description: Phase 13 — Iterative Improvement. Systematically analyzes the entire codebase for architecture issues, code quality, test coverage gaps, performance bottlenecks, and security weaknesses. Fixes all Critical and High findings autonomously.
allowed-tools: Agent, Read, Write
disable-model-invocation: true
---

## Live Project Context
!`cat .sde/context.json 2>/dev/null || echo '{"status": "no-project"}'`

## Agent Invocation

Use the **Agent tool** to spawn these agents **in parallel**:

### Backend Agent — Architecture & Quality
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/backend-agent.md for your full identity and standards.
Also read:
- ~/.sde-plugin/context/database-standards.md
- ~/.sde-plugin/context/security-rules.md

Your task: Run a full backend quality iteration.

Analyze and fix:
1. Circular dependencies (use madge --circular)
2. SRP violations — services with > 10 methods, split if needed
3. Direct DB calls in controllers — move to service layer
4. Module boundary violations — cross-module internal imports
5. Missing await on async calls
6. New endpoints without auth guards
7. New DTOs missing class-validator decorators
8. New env vars missing from .env.example

Fix all Critical and High findings. Create Notion tasks for Medium/Low.
Run full test suite after fixes. Save results to .sde/phases/13-iterations.md (append).
```

### Frontend Agent — Coverage & Performance
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/frontend-agent.md for your full identity and standards.
Also read ~/.sde-plugin/context/performance-standards.md

Your task: Run a full frontend quality iteration.

Analyze and fix:
1. Components below 80% test coverage — add missing tests
2. Synchronous operations that should be async
3. Components passing object/array literals as props without useMemo (unnecessary re-renders)
4. Event handlers created without useCallback where needed
5. Functions > 30 lines — extract sub-functions
6. Duplicate code blocks — extract to shared utilities
7. Magic numbers/strings — extract to named constants

Fix all Critical and High findings. Run coverage after fixes.
```

---

## What This Phase Produces

- Circular dependencies detected and broken (extracted shared interfaces/types)
- Services respecting SRP — split if > 10 methods or mixing concerns
- All DB operations confirmed in service layer, not controllers
- Missing await keywords identified and added
- All new endpoints verified for auth guards
- Backend coverage re-run; files below 80% threshold given targeted new tests
- Frontend coverage re-run; components below 80% given targeted new tests
- TypeScript errors confirmed zero (`tsc --noEmit` clean)
- Medium/Low findings as Notion backlog tasks
- Iteration log appended to `.sde/phases/13-iterations.md`
- All changes committed to `feature/13-iteration-[N]`

---

## Phase Gate (with repeat option)

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 13 COMPLETE — Iteration [N]            ║
╠══════════════════════════════════════════════════╣
║  FINDINGS:                                       ║
║  🔴 Critical: [N] (all fixed)                   ║
║  🟠 High:     [N] (all fixed)                   ║
║  🟡 Medium:   [N] (Notion tasks created)         ║
║  🔵 Low:      [N] (Notion backlog)               ║
╠══════════════════════════════════════════════════╣
║  COVERAGE:                                       ║
║  • Backend:  [N]%                                ║
║  • Frontend: [N]%                                ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • .sde/phases/13-iterations.md (appended)       ║
║  • Git committed: feature/13-iteration-[N]       ║
╠══════════════════════════════════════════════════╣
║  OPTIONS:                                        ║
╠══════════════════════════════════════════════════╣
║  [proceed]   → run another iteration             ║
║  [done]      → finish (project is production)    ║
║  [custom]    → focus on specific area            ║
╚══════════════════════════════════════════════════╝
```
