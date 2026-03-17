---
description: Phase 7 — Implementation. Generates all NestJS modules, React components and pages, Expo mobile screens, and admin dashboard — one complete working feature at a time, following SOLID and Clean Architecture principles.
allowed-tools: Agent, Read, Write, Bash
disable-model-invocation: true
---

## Live Project Context
!`cat .sde/context.json 2>/dev/null || echo '{"status": "no-project"}'`

## ⛔ Phase Guard — Read This First

Before doing ANYTHING else, check:
1. Does `.sde/context.json` exist in the current directory?
2. Does the `.sde/phases/` directory exist and contain at least `0-idea.md`?

If `.sde/context.json` is missing OR the `.sde/phases/` directory does not exist or is empty → STOP immediately and output:
```
⛔ Run /sde-scaffold before running /sde-implement.

Make sure you're in the correct project directory and have run the prior phases.
```
Do NOT proceed past this point.

If both conditions are met → read ALL phase files in `.sde/phases/` and continue.

---

## Agent Invocation

Check .sde/context.json for projectType to determine which agents to spawn.

Use the **Agent tool** to spawn all applicable agents **in parallel**:

### Backend Agent — Implement Features
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/backend-agent.md for your full identity and standards.
Also read:
- ~/.sde-plugin/context/database-standards.md
- ~/.sde-plugin/context/api-standards.md
- ~/.sde-plugin/context/security-rules.md
- ~/.sde-plugin/context/observability-standards.md
- ~/.sde-plugin/references/nestjs-patterns.md

Your task: Implement all backend features.

Project context: Read .sde/context.json, .sde/phases/1-prd.md, .sde/phases/4-datamodel.md, .sde/phases/5-api.md.

For each feature in the PRD:
1. Implement the complete module (controller, service, repository, entity, DTOs)
2. Add structured logging to every service method
3. Add input validation with class-validator on all DTOs
4. Add ownership checks — users can only access their own data
5. Follow the security rules from security-rules.md exactly
6. No console.log — use NestJS Logger only
```

### Frontend Agent — Implement UI
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/frontend-agent.md for your full identity and standards.
Also read:
- ~/.sde-plugin/references/react-patterns.md
- ~/.sde-plugin/context/performance-standards.md

Your task: Implement all frontend features.

Project context: Read .sde/context.json, .sde/phases/1-prd.md, .sde/phases/5-api.md.

For each feature in the PRD:
1. Implement all pages and components
2. Use TanStack Query for all data fetching — never fetch in useEffect
3. Handle all states: loading, error, empty, success
4. Use Zustand for global state
5. Forms use react-hook-form + zod
6. Follow performance standards (lazy loading, code splitting)
```

### Mobile Agent — Implement Mobile (only if projectType includes 'mobile')
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/mobile-agent.md for your full identity and standards.
Also read:
- ~/.sde-plugin/references/expo-patterns.md
- ~/.sde-plugin/references/mobile-patterns.md
- ~/.sde-plugin/context/performance-standards.md

Your task: Implement all mobile screens and features.

Project context: Read .sde/context.json, .sde/phases/1-prd.md, .sde/phases/5-api.md.

For each screen in the PRD:
1. Implement complete screen with all states
2. Use FlatList for all lists (never ScrollView + map)
3. Use expo-image for all images
4. Handle offline state gracefully
5. All animations via react-native-reanimated
```

### Admin Agent — Implement Admin Dashboard (only if projectType includes 'admin')
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/admin-agent.md for your full identity and standards.
Also read ~/.sde-plugin/references/react-patterns.md

Your task: Implement the admin dashboard.

Project context: Read .sde/context.json, .sde/phases/1-prd.md.

Implement:
1. Data tables with TanStack Table (sorting, filtering, pagination)
2. Charts with Recharts
3. Admin-only routes protected by role check
4. Bulk actions on tables
5. Export functionality (CSV)
```

---

## Autonomous Actions

1. Generate ALL modules listed in the data model and API design
2. Commit after each feature module is complete:
   ```bash
   git add src/modules/[feature]/
   git commit -m "feat: implement [feature] module — CRUD + tests"
   ```
3. Save implementation log to `.sde/phases/7-implementation.md` tracking what was built
4. Update context.json: `currentPhase: 7`, add 7 to `completedPhases`
5. Final commit:
   ```bash
   git add .
   git commit -m "feat: complete Phase 7 implementation"
   git push origin feature/7-implementation
   ```

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 7 COMPLETE — Implementation            ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • [N] backend modules implemented               ║
║  • [N] frontend pages + components               ║
║  • [N] custom hooks                              ║
║  • [N] mobile screens (if applicable)            ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • All source files created                      ║
║  • .sde/phases/7-implementation.md               ║
║  • Git committed: feature/7-implementation       ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 8 — Testing                         ║
╠══════════════════════════════════════════════════╣
║  [proceed] → generate tests (80% coverage)       ║
║  [refine]  → improve implementation              ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
