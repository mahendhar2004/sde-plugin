---
description: Phase 10 — Performance Optimization. Fixes N+1 queries, adds Redis caching, optimizes frontend bundle, adds database indexes, and applies all performance best practices.
allowed-tools: Agent, Read, Write
disable-model-invocation: true
---

## Live Project Context
!`cat .sde/context.json 2>/dev/null || echo '{"status": "no-project"}'`

## ⚠️ Phase Guard — Read This First

Before doing ANYTHING else, check:
1. Does `.sde/context.json` exist in the current directory?

If it is missing → output this warning and continue in standalone mode:
```
⚠️ No .sde/context.json found. Running in standalone mode — will analyze current directory without project context.
```
Do NOT stop — proceed with the performance audit against the current directory.

If it exists → read it and use it to inform the optimization work.

---

## Agent Invocation

Use the **Agent tool** to spawn these agents **in parallel**:

### Backend Agent — Performance Optimization
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/backend-agent.md for your full identity and standards.
Also read:
- ~/.sde-plugin/context/performance-standards.md
- ~/.sde-plugin/context/database-standards.md

Your task: Find and fix all backend performance issues.

Scan the codebase for:
1. N+1 queries — add eager loading or query optimization
2. Missing Redis caching — add cache for expensive queries (use TTLs from performance-standards.md)
3. Missing database indexes — add for all query patterns
4. Unoptimized queries — run EXPLAIN ANALYZE mentally, add composite indexes
5. Paginated endpoints missing LIMIT — add default limit of 20, max 100
```

### Frontend Agent — Bundle & Render Optimization
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/frontend-agent.md for your full identity and standards.
Also read ~/.sde-plugin/context/performance-standards.md

Your task: Optimize frontend performance to meet Core Web Vitals targets.

Fix:
1. Add React.lazy + Suspense at every route (code splitting)
2. All images: lazy loading + correct dimensions + WebP
3. Lists > 50 items: add @tanstack/react-virtual
4. Any useEffect data fetching: convert to React Query with staleTime
5. Check bundle size — target < 200KB gzipped initial JS
```

---

## What This Phase Produces

- N+1 queries identified and fixed with proper JOIN/eager loading
- Redis caching added to high-frequency read operations with TTL per data type
- Database indexes added for all FK columns, WHERE, and ORDER BY patterns
- All list endpoints paginated (default 20, max 100)
- Database connection pool verified (max 10, min 2)
- Frontend routes code-split with React.lazy + Suspense
- Bundle manual chunks configured (vendor-react, vendor-router, vendor-query)
- Docker images verified as multi-stage with .dockerignore files
- Performance report saved to `.sde/phases/10-performance.md`

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 10 COMPLETE — Performance              ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • [N] N+1 queries fixed                         ║
║  • [N] new database indexes added                ║
║  • Redis caching for [N] data types              ║
║  • [N] frontend routes lazy-loaded               ║
║  • Docker images multi-stage optimized           ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • .sde/phases/10-performance.md                 ║
║  • Git committed: feature/10-performance         ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 11 — DevOps & Deployment            ║
╠══════════════════════════════════════════════════╣
║  [proceed] → set up CI/CD and Docker             ║
║  [refine]  → more optimizations                  ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
