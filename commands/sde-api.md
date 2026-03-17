---
description: Phase 5 — API Design. Designs all REST endpoints organized by resource, defines request/response schemas, auth requirements, rate limits, pagination strategy, and generates a complete OpenAPI 3.0 YAML spec.
allowed-tools: Agent, Read, Write
disable-model-invocation: true
---

## Live Project Context
!`cat .sde/context.json 2>/dev/null || echo '{"status": "no-project"}'`

## ⛔ Phase Guard — Read This First

Before doing ANYTHING else, check:
1. Does `.sde/context.json` exist in the current directory?
2. Does `.sde/phases/2-architecture.md` exist?

If EITHER is missing → STOP immediately and output:
```
⛔ Run /sde-architect before running /sde-api.

Make sure you're in the correct project directory.
```
Do NOT proceed past this point.

If both exist → read them and continue.

---

## Agent Invocation

Use the **Agent tool** to spawn these two agents **in parallel** (single message, two Agent tool calls):

### Backend Agent — API Design
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/backend-agent.md for your full identity and standards.
Also read:
- ~/.sde-plugin/context/api-standards.md
- ~/.sde-plugin/context/database-standards.md
- ~/.sde-plugin/references/nestjs-patterns.md

Your task: Design and document all REST API endpoints for this project.

Project context: Read .sde/context.json, .sde/phases/1-prd.md, .sde/phases/2-architecture.md.

Produce:
1. Complete OpenAPI 3.0 YAML specification
2. All endpoints with: method, path, auth requirement, request body schema, response schema, error responses
3. DTOs for every request/response
4. Follow the response envelope from api-standards.md: { data, message, statusCode, meta }
5. Save to .sde/schemas/openapi.yaml
```

### Architect Agent — API Review
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/architect-agent.md for your full identity and standards.
Also read ~/.sde-plugin/context/api-standards.md

Your task: Review the API design for architectural consistency.

Wait for the Backend Agent to save .sde/schemas/openapi.yaml, then review it for:
1. REST convention violations
2. Inconsistent naming
3. Missing endpoints based on the PRD requirements
4. Security gaps (unprotected endpoints)
5. Versioning correctness

Report findings to be merged into the final API spec.
```

---

## What This Phase Produces

- Auth endpoints: register, login, refresh, logout, forgot-password, reset-password
- Users endpoints: GET/PATCH me, PATCH password, DELETE me, admin list/status
- Feature resource endpoints following CRUD pattern per entity from data model
- Health endpoints: /health, /health/db, /health/redis
- Rate limit definitions per endpoint type (see api-standards.md for values)
- Complete OpenAPI 3.0 YAML saved to `.sde/schemas/openapi.yaml`
- API design document saved to `.sde/phases/5-api-design.md`

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 5 COMPLETE — API Design                ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • [N] endpoints designed across [N] resources   ║
║  • Auth endpoints: 6 (register, login, refresh,  ║
║    logout, forgot-password, reset-password)      ║
║  • Rate limiting defined per endpoint type       ║
║  • OpenAPI 3.0 spec generated                    ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • .sde/phases/5-api-design.md                   ║
║  • .sde/schemas/openapi.yaml                     ║
║  • Notion sub-page: "API Design — Phase 5"       ║
║  • Git committed: feature/5-api-design           ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 6 — Project Scaffold                ║
╠══════════════════════════════════════════════════╣
║  [proceed] → scaffold project structure          ║
║  [refine]  → revise API design                   ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
