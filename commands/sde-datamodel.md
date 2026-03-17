---
description: Phase 4 — Data Model Design. Analyzes PRD features to design normalized ER schema, generates TypeORM entities with full decorators, produces SQL DDL, and defines all indexes and relationships.
allowed-tools: Agent, Read, Write
disable-model-invocation: true
---

## Live Project Context
!`cat .sde/context.json 2>/dev/null || echo '{"status": "no-project"}'`

## ⛔ Phase Guard — Read This First

Before doing ANYTHING else, check:
1. Does `.sde/context.json` exist in the current directory?
2. Does `.sde/phases/2-architecture.md` exist?
3. Does `.sde/phases/3-stack.md` exist? (recommended, but 2-architecture.md is the minimum)

If `.sde/context.json` OR `.sde/phases/2-architecture.md` are missing → STOP immediately and output:
```
⛔ Run /sde-architect and /sde-stack before running /sde-datamodel.

Make sure you're in the correct project directory.
```
Do NOT proceed past this point.

If both required files exist → read context.json, 2-architecture.md, and 3-stack.md (if present) and continue.

---

## Agent Invocation

First check .sde/context.json to determine the backend type.

**If backend is Supabase:** Use the **Agent tool** to spawn:

### Supabase Agent
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/supabase-agent.md for your full identity and standards.
Also read:
- ~/.sde-plugin/context/supabase-standards.md
- ~/.sde-plugin/references/supabase-patterns.md

Your task: Design the complete Supabase database schema for this project.

Project context: Read .sde/context.json, .sde/phases/0-idea.md, .sde/phases/2-architecture.md.

Produce:
1. Complete SQL schema with all tables, columns, types, constraints
2. RLS policies for every table (all 4 operations)
3. Indexes for all FK columns and common query patterns
4. updated_at trigger for all tables
5. handle_new_user trigger if profiles table exists
6. Save as supabase/migrations/[timestamp]_initial_schema.sql
7. Update .sde/schemas/database.sql with final schema
```

**If backend is NestJS/Express:** Use the **Agent tool** to spawn:

### Backend Agent
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/backend-agent.md for your full identity and standards.
Also read:
- ~/.sde-plugin/context/database-standards.md
- ~/.sde-plugin/references/nestjs-patterns.md

Your task: Design the complete TypeORM data model for this project.

Project context: Read .sde/context.json, .sde/phases/0-idea.md, .sde/phases/2-architecture.md.

Produce:
1. TypeORM entities for all domain objects (extending BaseEntity)
2. Proper relationships (@ManyToOne, @OneToMany, @ManyToMany)
3. Indexes on all FK columns and query columns
4. Migration file for the initial schema
5. Update .sde/schemas/database.sql with final SQL DDL
```

---

## What This Phase Produces

- All domain entities extracted from PRD user stories (every "manage [noun]" = entity)
- Universal entities: User (with failedLoginAttempts, lockedUntil), RefreshToken (tokenHash, isRevoked)
- Text ER diagram showing all 1:1, 1:N, N:M relationships
- TypeORM entities extending BaseEntity (uuid PK, createdAt, updatedAt, deletedAt)
- Indexes on all FK columns, WHERE-clause columns, and composite query patterns
- SQL DDL saved to `.sde/schemas/database.sql`
- TypeORM migration config (data-source.ts, migration scripts in package.json)
- Data model document saved to `.sde/phases/4-data-model.md`

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 4 COMPLETE — Data Model                ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • [N] entities identified and designed          ║
║  • ER diagram created                            ║
║  • TypeORM entities with full decorators         ║
║  • SQL DDL schema with indexes                   ║
║  • Migration configuration set up               ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • .sde/phases/4-data-model.md                   ║
║  • .sde/schemas/database.sql                     ║
║  • Notion sub-page: "Data Model — Phase 4"       ║
║  • Git committed: feature/4-data-model           ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 5 — API Design                      ║
╠══════════════════════════════════════════════════╣
║  [proceed] → start API design                    ║
║  [refine]  → revise data model                   ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
