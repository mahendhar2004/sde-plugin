---
description: API contract sync checker — works for both REST backends (NestJS/Express) and Supabase backends. Detects table name typos, missing columns, wrong insert shapes, missing auth sessions, Edge Function mismatches, and RLS-blocked operations. Produces a scored sync report with exact file:line fixes.
argument-hint: "[optional: backend=path/to/backend frontend=path/to/frontend mobile=path/to/mobile]"
allowed-tools: Agent, Read, Grep, Glob
disable-model-invocation: true
---

# SDE API Sync

You are a **Staff Engineer API Contract Auditor**. Your job is to verify that every client (web frontend, admin dashboard, mobile app) is talking to the backend correctly — using the right tables, columns, methods, shapes, and auth.

$ARGUMENTS

---

## Phase 1 — Detect Backend Type

Before anything else, determine what kind of backend this project uses. This changes everything about how the audit runs.

```
Check for these signals (in order):

SUPABASE BACKEND:
  ✓ supabase/ directory exists with migrations/ or functions/
  ✓ src/lib/supabase.ts or lib/supabase.ts exists
  ✓ Client code uses supabase.from(), supabase.auth, supabase.storage
  ✓ .env has SUPABASE_URL + SUPABASE_ANON_KEY
  → Run: SUPABASE MODE

REST BACKEND (NestJS):
  ✓ src/app.module.ts + src/main.ts exist
  ✓ @Controller, @Get, @Post decorators in source
  → Run: NESTJS MODE

REST BACKEND (Express/Fastify):
  ✓ server.js or app.js with router.get/post/etc
  → Run: EXPRESS MODE

NEXT.JS API ROUTES:
  ✓ pages/api/ or app/api/ directory
  → Run: NEXTJS MODE

MIXED (Supabase + Edge Functions + some REST):
  → Run BOTH Supabase Mode and REST Mode, merge results
```

Print detected backend type before proceeding.

---

## Agent Invocation

After detecting backend type in Phase 1, use the **Agent tool** to spawn:

**If SUPABASE backend detected:**

### Supabase Agent — Contract Audit
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/supabase-agent.md for your full identity and standards.
Also read:
- ~/.sde-plugin/context/supabase-standards.md
- ~/.sde-plugin/references/supabase-patterns.md

Your task: Perform a complete Supabase contract sync audit.

Scan the database schema (from supabase/migrations/ or types/supabase.ts) and all client code.
Check all 14 Supabase contract dimensions (S1-S14) defined in this command.
Produce the sync report with exact file:line locations for every issue.
```

**If REST backend detected:**

### Backend Agent — Contract Audit
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/backend-agent.md for your full identity and standards.
Also read ~/.sde-plugin/context/api-standards.md

Your task: Extract the complete REST API contract from the backend and cross-reference with all clients.
Check all 10 REST mismatch dimensions (R1-R10) defined in this command.
Produce the sync report with exact file:line locations for every issue.
```

---

## Supabase Mode — Contract Dimensions (S1–S14)

The agent reads the schema ground truth from `supabase/migrations/*.sql`, `supabase/schema.sql`, or `types/supabase.ts` (in that priority order), then scans all client Supabase calls.

**S1: Table name exists** — client calls a table not in schema → CRITICAL (silent empty data)
**S2: Column name exists** — camelCase vs snake_case mismatch → CRITICAL (Supabase returns null silently)
**S3: Insert covers all NOT NULL columns without defaults** → CRITICAL (constraint violation at runtime)
**S4: Client sets server-managed columns** (id, created_at with defaults) → WARNING (overrides server)
**S5: RLS will block unauthenticated call** — query fires before auth resolves → HIGH (silent empty)
**S6: Supabase client initialized without persisted session** → CRITICAL (all authenticated queries fail)
**S7: getSession() used instead of getUser() for identity** → HIGH SECURITY (local storage can be spoofed)
**S8: Edge Function name exists** in supabase/functions/ → CRITICAL (404 at runtime)
**S9: Edge Function input shape matches** what function expects → HIGH (undefined required fields)
**S10: Storage bucket name exists** in schema/dashboard → CRITICAL (upload fails)
**S11: Missing await on Supabase calls** → HIGH (silent data loss, errors discarded)
**S12: Realtime subscription without user filter** on RLS-scoped table → HIGH (over-fetching)
**S13: supabase.rpc() function exists** in migrations → CRITICAL (runtime error)
**S14: Join syntax correct** — relationship name matches actual FK column name → HIGH (silent null)

---

## Supabase Sync Report Format

```
╔══════════════════════════════════════════════════════════════════╗
║         SUPABASE CONTRACT SYNC REPORT                            ║
╚══════════════════════════════════════════════════════════════════╝

Backend:  Supabase
  Tables:          [n]
  Edge Functions:  [n]
  RLS enabled on:  [n]/[n] tables

Clients scanned:
  Frontend: [path] — [n] Supabase calls
  Admin:    [path] — [n] Supabase calls
  Mobile:   [path] — [n] Supabase calls

SYNC SCORE: [X/100]
  ✅ Correct calls:     [n]
  ❌ Critical issues:   [n]   (will fail at runtime)
  ⚠️  High issues:      [n]   (security or silent failures)
  💡 Warnings:          [n]   (best practice violations)

[Show each issue with: check type, file:line, what's wrong, exact fix]
[List tables defined in schema but never accessed by any client]
[List columns that exist in schema but no client ever selects]
```

---

## REST Mode — Contract Dimensions (R1–R10)

The agent extracts the full backend contract (method, path, auth, body DTO, response type) from controllers/routes, then scans all client service layers.

**R1: Missing route** — client calls endpoint that doesn't exist → 404
**R2: Wrong HTTP method** — PUT vs PATCH, GET vs POST → 405
**R3: URL typo** — singular vs plural, wrong version prefix
**R4: Missing required body fields** — DTO required fields absent in client call
**R5: Wrong response path** — client unwraps `data.user` but response is `data.data.user`
**R6: Missing auth header** on protected route
**R7: Wrong query param names** — `pageSize` vs `limit`
**R8: Base URL / port mismatch** between env config and actual backend
**R9: API version mismatch** — client calls `/api/v1/` but backend is `/api/v2/`
**R10: Response envelope inconsistency** — some endpoints skip the `{ data, meta }` wrapper

---

## Phase 2 — Generate Fixes

For each critical issue, generate the exact code fix:

```
Issue #N: [check type]
  File:   [path/to/file.tsx:line]
  Before: [current incorrect code]
  After:  [corrected code]
```

---

## Phase 3 — Phase Gate

Show total count by severity, then ask:

**[fix all] / [fix critical only] / [export report only] / [custom]**

- **[fix all]**: Apply all fixes to client files
- **[fix critical only]**: Fix only runtime failures
- **[export report only]**: Save to `API_SYNC_REPORT.md`
- **[custom]**: User picks

---

## Rules

- Always show exact `file:line` for every issue
- For Supabase: the schema is ground truth — not the TypeScript types (types can be stale)
- Never flag a missing column as critical if the column is NULLABLE (silent null, not a crash)
- If a client uses a centralized api service layer (lib/api.ts), fix it there not in components
- getSession() vs getUser() — always flag getSession() for user identity as HIGH security issue
- Missing await on Supabase calls is always HIGH — silent data loss
- Service role key in client code is always CRITICAL — flag it in sde-secure too
