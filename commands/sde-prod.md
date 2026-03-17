---
description: Phase 12 — Production Readiness. Runs a comprehensive production checklist, fixes all issues automatically, generates a rollback runbook, and creates the project README.
allowed-tools: Agent, Read
disable-model-invocation: true
---

## Live Project Context
!`cat .sde/context.json 2>/dev/null || echo '{"status": "no-project"}'`

# SDE Prod — Phase 12: Production Readiness

## Agent Invocation

Use the **Agent tool** to spawn one agent:

### DevOps Agent — Production Readiness
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/devops-agent.md for your full identity and standards.

Your task: Run a complete production readiness check and fix all issues.

Project context: Read .sde/context.json and ALL files in .sde/phases/.

Work through each category below. Fix issues autonomously. Mark each ✅ or ❌.

**Code Quality**
- TypeScript strict mode — no errors (run tsc --noEmit on backend and frontend)
- No console.log in production code (use NestJS Logger)
- All TODO/FIXME comments resolved
- React Error Boundaries in frontend

**Security**
- All env vars documented in .env.example
- No secrets hardcoded in source
- npm audit — no critical vulnerabilities
- Rate limiting active on auth endpoints

**Infrastructure**
- Health check endpoints respond correctly
- Graceful shutdown (app.enableShutdownHooks())
- Database connection pool configured
- Docker images build successfully
- CI pipeline passes

**Observability**
- Structured JSON logging in production (nestjs-pino)
- Sentry configured and test error verified
- Prometheus metrics endpoint at /metrics

**Data**
- Database migrations run clean on fresh DB
- Admin seed user script works

**Documentation**
- README.md comprehensive (see format below)
- Swagger UI accessible at /api/docs in dev

After completing all checks:
1. Generate project README.md at project root using the standard SDE template
2. Generate rollback runbook at .sde/phases/12-rollback-runbook.md
3. Save production readiness report to .sde/phases/12-prod-readiness.md
```

---

## Autonomous Actions

1. Fix ALL checklist items
2. Generate project README.md
3. Generate rollback runbook at `.sde/phases/12-rollback-runbook.md`
4. Save production readiness report to `.sde/phases/12-prod-readiness.md`
5. ```bash
   git checkout develop
   git checkout -b feature/12-prod-readiness
   git add .
   git commit -m "chore: production readiness — README, rollback runbook, final fixes — Phase 12"
   git push origin feature/12-prod-readiness
   ```
6. Update context.json: `currentPhase: 12`, add 12 to `completedPhases`

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 12 COMPLETE — Production Ready!        ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • All checklist items resolved                  ║
║  • README.md comprehensive                       ║
║  • Rollback runbook created                      ║
║  • All TypeScript errors resolved                ║
║  • Sentry + Grafana configured                   ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • README.md                                     ║
║  • .sde/phases/12-prod-readiness.md              ║
║  • .sde/phases/12-rollback-runbook.md            ║
║  • Git committed: feature/12-prod-readiness      ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 13 — Iterative Improvement          ║
╠══════════════════════════════════════════════════╣
║  [proceed] → run continuous improvement          ║
║  [refine]  → revisit prod readiness              ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
