---
description: Existing Codebase Analysis — detects tech stack, maps architecture, identifies all issues (Critical to Low), and generates a phased improvement plan. Use this when joining an existing project.
argument-hint: "[optional: focus area]"
allowed-tools: Agent, Read, Grep, Glob
disable-model-invocation: true
---

# SDE Analyze — Existing Codebase Analysis

Run this when you have an existing codebase you want to improve. It will fully understand what you have, find all problems, and create a roadmap.

$ARGUMENTS

---

## Agent Invocation

Use the **Agent tool** to spawn one agent:

### Architect Agent — Codebase Analysis
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/architect-agent.md for your full identity and standards.
Also read:
- ~/.sde-plugin/context/security-rules.md
- ~/.sde-plugin/context/database-standards.md
- ~/.sde-plugin/context/api-standards.md

Your task: Perform a complete analysis of this existing codebase.

Focus area (if provided): $ARGUMENTS

Steps:
1. Auto-detect tech stack — read package.json files, tsconfig, .env.example, docker-compose
2. Map directory structure and identify architecture pattern
3. Run comprehensive issue analysis across 4 severity levels
4. Generate a 5-phase improvement plan with time estimates
5. Initialize .sde/context.json with findings
6. Save full analysis to .sde/phases/0-analysis.md
7. Show the analysis dashboard
```

---

## What This Phase Produces

- **Tech stack detection**: backend framework, ORM, database, auth library, testing framework, frontend framework, build tool, styling, state management, CI/CD, infrastructure
- **Architecture assessment**: pattern identified (Clean Architecture / MVC / Fat Controllers / Spaghetti / Monolith), deviations from Clean Architecture mapped with file locations
- **Critical issues** (security vulnerabilities): SQL injection risks, hardcoded secrets, unprotected routes, broken auth, plaintext passwords
- **High issues**: missing tests per service/component, N+1 query patterns, missing error handling, unhandled promise rejections, no request logging
- **Medium issues**: code duplication, outdated dependencies, TypeScript `any` usage, missing input validation on DTOs
- **Low issues**: console.log statements, unused imports, missing JSDoc on public APIs
- **5-phase improvement plan**: Phase A Security, Phase B Tests, Phase C Architecture, Phase D Performance, Phase E DevOps — with time estimates
- `.sde/context.json` initialized with detected stack and issue counts
- Analysis dashboard showing issue counts and recommended next command

---

## Analysis Dashboard Output

```
╔═══════════════════════════════════════════════════════════════╗
║  SDE PLUGIN — Codebase Analysis Complete                      ║
╠═══════════════════════════════════════════════════════════════╣
║  DETECTED TECH STACK:                                         ║
║  Backend:  [NestJS/Express/...]                               ║
║  Frontend: [React/Vue/...]                                    ║
║  Database: [PostgreSQL/MySQL/...]                             ║
║  Auth:     [JWT/Session/...]                                  ║
║  Tests:    [Jest/Mocha/...] — Coverage: ~[N]%                 ║
║  ARCHITECTURE: [Modular Monolith/MVC/...]                     ║
╠═══════════════════════════════════════════════════════════════╣
║  ISSUES FOUND:                                                ║
║  🔴 Critical: [N]  ← Fix before anything else               ║
║  🟠 High:     [N]  ← Fix this week                          ║
║  🟡 Medium:   [N]  ← This sprint                            ║
║  🔵 Low:      [N]  ← Backlog                                ║
╠═══════════════════════════════════════════════════════════════╣
║  IMPROVEMENT PLAN: 5 phases                                   ║
║  Phase A: Security fixes  →  /sde-secure                     ║
║  Phase B: Test coverage   →  /sde-test                       ║
║  Phase C: Architecture    →  /sde-iterate                    ║
║  Phase D: Performance     →  /sde-optimize                   ║
║  Phase E: DevOps setup    →  /sde-devops                     ║
╠═══════════════════════════════════════════════════════════════╣
║  RECOMMENDED NEXT STEP:                                       ║
║  Run /sde-secure to fix all critical security issues          ║
╚═══════════════════════════════════════════════════════════════╝
```
