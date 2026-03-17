---
description: Phase 11 — DevOps & Deployment. Generates production-ready Dockerfiles, GitHub Actions CI/CD workflows, k3s manifests, AWS setup guide, Grafana Cloud config, and Sentry integration.
allowed-tools: Agent, Read, Write, Bash
disable-model-invocation: true
---

## Live Project Context
!`cat .sde/context.json 2>/dev/null || echo '{"status": "no-project"}'`

## ⛔ Phase Guard — Read This First

Before doing ANYTHING else, check:
1. Does `.sde/context.json` exist in the current directory?
2. Does EITHER `.sde/phases/6-scaffold.md` exist OR does a `src/` directory exist in the current directory?

If `.sde/context.json` is missing → STOP immediately and output:
```
⛔ Run /sde-scaffold before running /sde-devops.

Make sure you're in the correct project directory.
```
Do NOT proceed past this point.

If `.sde/context.json` exists but NEITHER `.sde/phases/6-scaffold.md` NOR `src/` is present → STOP and output:
```
⛔ Run /sde-scaffold before running /sde-devops.

No scaffold output detected. Make sure you're in the correct project directory.
```
Do NOT proceed past this point.

If `.sde/context.json` exists AND either `.sde/phases/6-scaffold.md` or `src/` is present → read context.json and continue.

---

## Agent Invocation

Use the **Agent tool** to spawn one agent:

### DevOps Agent
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/devops-agent.md for your full identity and standards.
Also read:
- ~/.sde-plugin/context/observability-standards.md
- ~/.sde-plugin/context/performance-standards.md

Your task: Set up complete CI/CD, Docker, and AWS infrastructure.

Project context: Read .sde/context.json and .sde/phases/3-stack.md.

Create:
1. Dockerfile for each service (multi-stage, non-root user, dumb-init)
   - Use templates from ~/.sde-plugin/templates/docker/
2. docker-compose.yml for local dev
3. GitHub Actions CI workflow (lint + typecheck + test + build)
   - Use template from ~/.sde-plugin/templates/github-actions/ci.yml
4. GitHub Actions CD workflow (build → ECR push → EC2 SSH deploy)
   - Use template from ~/.sde-plugin/templates/github-actions/cd-prod.yml
5. Security audit workflow (daily npm audit + secret scanning)
6. Grafana Cloud free tier setup instructions
7. Sentry free tier setup in application code
8. All GitHub Actions secrets list with instructions
```

---

## Autonomous Actions

1. Create ALL files: Dockerfiles, nginx.conf, docker-compose files, workflows, k3s manifests
2. Save deployment guide to `.sde/phases/11-devops.md`
3. Add Sentry integration to main.ts and exception filter
4. ```bash
   git checkout develop
   git checkout -b feature/11-devops
   git add .
   git commit -m "ci: Docker, GitHub Actions CI/CD, k3s manifests — Phase 11"
   git push origin feature/11-devops
   ```
5. Update context.json: `currentPhase: 11`, add 11 to `completedPhases`

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 11 COMPLETE — DevOps                   ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • Dockerfiles (backend multi-stage, frontend)   ║
║  • docker-compose.yml (dev) + prod               ║
║  • CI workflow (backend + frontend)              ║
║  • CD workflow (ECR + EC2 deploy)                ║
║  • Security audit workflow (daily)               ║
║  • k3s manifests (future scaling)                ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • .sde/phases/11-devops.md                      ║
║  • Git committed: feature/11-devops              ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 12 — Production Readiness           ║
╠══════════════════════════════════════════════════╣
║  [proceed] → run production checklist            ║
║  [refine]  → adjust deployment config            ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
