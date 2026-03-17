---
description: Phase 8 — Testing. Generates comprehensive unit tests, integration tests, and frontend component tests targeting 80% coverage. Runs coverage reports and generates additional tests for uncovered code.
allowed-tools: Agent, Read, Write, Bash
disable-model-invocation: true
---

## Live Project Context
!`cat .sde/context.json 2>/dev/null || echo '{"status": "no-project"}'`

## ⛔ Phase Guard — Read This First

Before doing ANYTHING else, check:
1. Does `.sde/context.json` exist in the current directory?

If it is missing → STOP immediately and output:
```
⛔ No .sde/context.json found. Run /sde-idea first or run /sde-analyze on an existing codebase.

Make sure you're in the correct project directory.
```
Do NOT proceed past this point.

If it exists → read it and continue.

---

## Agent Invocation

Use the **Agent tool** to spawn one agent:

### QA Agent
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/qa-agent.md for your full identity and standards.
Also read:
- ~/.sde-plugin/context/testing-standards.md

Your task: Write comprehensive tests achieving 80%+ coverage.

Project context: Read .sde/context.json. Scan the src/ directory to understand what exists.

Write:
1. Unit tests for all services (Jest, AAA pattern, factory pattern)
2. Integration tests for all API endpoints (Supertest with real DB)
3. Component tests for React components (RTL)
4. E2E test stubs (Detox for mobile if applicable)
5. Test factories for all entities
6. Ensure coverage thresholds from testing-standards.md are met
7. Run tests and fix any failures before finishing
```

---

## Autonomous Actions

1. Generate ALL test files for every module, service, controller, component, hook
2. Add jest config to backend and vitest config to frontend
3. Run coverage checks:
   ```bash
   cd backend && npm test -- --coverage --forceExit 2>&1 | tee /tmp/backend-coverage.txt
   cd ../frontend && npm test -- --coverage 2>&1 | tee /tmp/frontend-coverage.txt
   ```
4. Generate additional tests if any metric is below 80%
5. Save coverage report summary to `.sde/phases/8-tests.md`
6. ```bash
   git checkout develop
   git checkout -b feature/8-testing
   git add .
   git commit -m "test: comprehensive test suite, 80%+ coverage — Phase 8"
   git push origin feature/8-testing
   ```
7. Update context.json: `currentPhase: 8`, add 8 to `completedPhases`

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 8 COMPLETE — Testing                   ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • Backend coverage:  [N]% (≥80% ✅)            ║
║  • Frontend coverage: [N]% (≥80% ✅)            ║
║  • [N] unit tests                                ║
║  • [N] integration tests                         ║
║  • [N] component tests                           ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • All test files created                        ║
║  • .sde/phases/8-tests.md (coverage report)      ║
║  • Git committed: feature/8-testing              ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 9 — Security Hardening              ║
╠══════════════════════════════════════════════════╣
║  [proceed] → run OWASP security audit            ║
║  [refine]  → improve test coverage               ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
