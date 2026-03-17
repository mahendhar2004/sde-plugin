---
description: Phase 6 — Project Scaffold. Creates the complete directory structure and writes all boilerplate files with working code — NestJS backend, React frontend, Expo mobile (if needed), and root config files.
allowed-tools: Agent, Read, Write, Bash
disable-model-invocation: true
---

## Live Project Context
!`cat .sde/context.json 2>/dev/null || echo '{"status": "no-project"}'`

## ⛔ Phase Guard — Read This First

Before doing ANYTHING else, check:
1. Does `.sde/context.json` exist in the current directory?
2. Does `.sde/phases/3-stack.md` exist?

If EITHER is missing → STOP immediately and output:
```
⛔ Run /sde-stack before running /sde-scaffold.

Make sure you're in the correct project directory.
```
Do NOT proceed past this point.

If both exist → read them and continue.

---

## Agent Invocation

Check .sde/context.json for projectType to determine which agents to spawn.

Use the **Agent tool** to spawn the applicable agents **in parallel**:

### Backend Agent — Scaffold Backend
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/backend-agent.md for your full identity and standards.
Also read:
- ~/.sde-plugin/context/database-standards.md
- ~/.sde-plugin/context/api-standards.md
- ~/.sde-plugin/references/nestjs-patterns.md

Your task: Create the complete NestJS backend scaffold.

Project context: Read .sde/context.json and .sde/phases/3-stack.md.

Create the full directory structure and all boilerplate files:
- main.ts with bootstrap (from nestjs-patterns.md reference)
- AppModule with all imports
- AuthModule with JWT + Passport
- HealthModule with /health endpoint
- Shared filters, interceptors, decorators
- All feature module skeletons from the architecture
- .env.example with all required variables
- package.json with correct versions from stack-constants.md
```

### Frontend Agent — Scaffold Frontend
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/frontend-agent.md for your full identity and standards.
Also read:
- ~/.sde-plugin/references/react-patterns.md
- ~/.sde-plugin/context/stack-constants.md

Your task: Create the complete React frontend scaffold.

Project context: Read .sde/context.json and .sde/phases/3-stack.md.

Create:
- Vite + React 18 + TypeScript + Tailwind setup
- Router setup with protected routes
- TanStack Query provider + Zustand store
- Axios instance with interceptors (auth token + refresh)
- All page skeletons from the PRD features
- Component structure
- .env.example
```

### Mobile Agent — Scaffold Mobile (only if projectType includes 'mobile')
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/mobile-agent.md for your full identity and standards.
Also read:
- ~/.sde-plugin/references/expo-patterns.md
- ~/.sde-plugin/references/mobile-patterns.md

Your task: Create the complete Expo React Native scaffold.

Project context: Read .sde/context.json and .sde/phases/3-stack.md.

Create:
- Expo Router v3 file-based routing structure
- Root layout with auth redirect logic
- Supabase client with SecureStore adapter
- All screen skeletons from the PRD features
- NativeWind setup
- app.json with correct bundle identifier
- eas.json for builds
```

---

## Autonomous Actions

1. Create ALL directories
2. Write ALL boilerplate files using patterns from nestjs-patterns.md and react-patterns.md
3. ```bash
   git checkout develop
   git checkout -b feature/6-scaffold
   git add .
   git commit -m "chore: project scaffold with boilerplate — Phase 6"
   git push origin feature/6-scaffold
   ```
4. Save scaffold log to `.sde/phases/6-scaffold.md`
5. Update context.json: `currentPhase: 6`, add 6 to `completedPhases`

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 6 COMPLETE — Project Scaffold          ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • Backend NestJS scaffold with auth, health     ║
║  • Frontend React + Vite + Tailwind scaffold     ║
║  • [Mobile scaffold if applicable]               ║
║  • All boilerplate files with working code       ║
║  • Root docker-compose, .gitignore               ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • All source files created                      ║
║  • .sde/phases/6-scaffold.md                     ║
║  • Git committed: feature/6-scaffold             ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 7 — Implementation                  ║
╠══════════════════════════════════════════════════╣
║  [proceed] → start full implementation           ║
║  [refine]  → adjust scaffold structure           ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
