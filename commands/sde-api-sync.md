---
description: API contract sync checker — works for both REST backends (NestJS/Express) and Supabase backends. Detects table name typos, missing columns, wrong insert shapes, missing auth sessions, Edge Function mismatches, and RLS-blocked operations. Produces a scored sync report with exact file:line fixes.
argument-hint: "[optional: backend=path/to/backend frontend=path/to/frontend mobile=path/to/mobile]"
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
Check all 14 contract dimensions defined in this command.
Produce the sync report with exact file:line locations for every issue.
```

**If REST backend detected:**

### Backend Agent — Contract Audit
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/backend-agent.md for your full identity and standards.
Also read ~/.sde-plugin/context/api-standards.md

Your task: Extract the complete REST API contract from the backend and cross-reference with all clients.
Check all 10 mismatch dimensions defined in this command.
Produce the sync report with exact file:line locations for every issue.
```

---

# ═══════════════════════════════════════════════
# SUPABASE MODE
# (runs when backend is Supabase)
# ═══════════════════════════════════════════════

## S1 — Build Supabase Contract from Schema

The "backend contract" for Supabase is the **database schema + RLS policies + Edge Functions**.
There are no routes — the contract is the schema itself.

### Step 1: Read the schema

Look for schema definition in this order:
1. `supabase/migrations/*.sql` — read ALL migration files in order (they build up the schema)
2. `supabase/schema.sql` — if exists, use as authoritative schema
3. `src/types/supabase.ts` or `types/supabase.ts` — generated TypeScript types (most reliable)

From the schema, extract for every table:
```
TABLE: profiles
  Columns:
    id          uuid        NOT NULL  DEFAULT gen_random_uuid()
    user_id     uuid        NOT NULL  FK → auth.users(id)
    username    text        NOT NULL
    avatar_url  text        NULLABLE
    bio         text        NULLABLE
    created_at  timestamptz NOT NULL  DEFAULT now()
    updated_at  timestamptz NOT NULL  DEFAULT now()
  RLS: ENABLED
  Policies:
    SELECT: auth.uid() = user_id  ← requires authenticated session
    INSERT: auth.uid() = user_id  ← requires authenticated session
    UPDATE: auth.uid() = user_id  ← requires authenticated session
    DELETE: auth.uid() = user_id  ← requires authenticated session
```

Build this for EVERY table. This is the ground truth.

### Step 2: Read Edge Functions

For each file in `supabase/functions/`:
```
EDGE FUNCTION: send-notification
  Invoke URL:   /functions/v1/send-notification
  Method:       POST
  Input shape:  { userId: string, message: string, type: 'push' | 'email' }
  Output shape: { success: boolean, notificationId: string }
  Auth:         Requires JWT (reads Authorization header)
```

Extract input/output TypeScript types from each function file.

---

## S2 — Extract Client Supabase Usage

Scan ALL client code (frontend, admin, mobile) for every Supabase call.

### Table access patterns to find:

```typescript
// SELECT — extract: table name, columns selected, filters
supabase.from('profiles').select('*')
supabase.from('profiles').select('id, username, avatar_url')
supabase.from('posts').select('*, profiles(username, avatar_url)')  ← join
supabase.from('orders').select().eq('user_id', userId).order('created_at')

// INSERT — extract: table name, columns being inserted
supabase.from('profiles').insert({ username, avatar_url })
supabase.from('orders').insert({ user_id: user.id, total, items })

// UPDATE — extract: table name, columns being updated, filter
supabase.from('profiles').update({ bio }).eq('id', profileId)

// DELETE — extract: table name, filter
supabase.from('posts').delete().eq('id', postId)

// UPSERT — extract: table name, columns, conflict column
supabase.from('profiles').upsert({ id, username })

// RPC — extract: function name, args
supabase.rpc('get_user_stats', { user_id: userId })

// STORAGE — extract: bucket name, operation, path
supabase.storage.from('avatars').upload(`${userId}/avatar.jpg`, file)
supabase.storage.from('avatars').getPublicUrl(`${userId}/avatar.jpg`)

// EDGE FUNCTIONS — extract: function name, body shape
supabase.functions.invoke('send-notification', { body: { userId, message } })

// AUTH — extract: method used
supabase.auth.signInWithPassword({ email, password })
supabase.auth.signInWithOAuth({ provider: 'google' })
supabase.auth.getUser()
supabase.auth.getSession()  ← flag this: should use getUser() for security
```

For each call, record:
- File path + line number
- Table/function name
- Operation (select/insert/update/delete/upsert/rpc/storage/edge)
- Columns/fields used
- Whether `await` is used (missing await = silent failure)
- Whether auth session is available in context (is this inside an authenticated route/screen?)

---

## S3 — Supabase Contract Cross-Reference

Now compare what clients call vs what the schema defines.

### Supabase Check 1: Table name exists?
```
Client calls:    supabase.from('user_profiles')
Schema has:      profiles  (no 'user_profiles' table)
→ CRITICAL: Table does not exist — will return empty data silently
  File: mobile/src/screens/ProfileScreen.tsx:45
  Fix:  Change to supabase.from('profiles')
```

### Supabase Check 2: Column name exists?
```
Client selects:  supabase.from('profiles').select('id, username, profilePicture')
Schema columns:  id, username, avatar_url  (no 'profilePicture' — camelCase vs snake_case)
→ CRITICAL: Column does not exist — Supabase returns null for unknown columns silently
  File: admin/src/components/UserTable.tsx:23
  Fix:  Change 'profilePicture' to 'avatar_url'
```

### Supabase Check 3: Insert includes NOT NULL columns without defaults?
```
Schema:  posts { title text NOT NULL, body text NOT NULL, user_id uuid NOT NULL, category_id uuid NOT NULL }
Client:  supabase.from('posts').insert({ title, body })   ← missing user_id, category_id
→ CRITICAL: Insert will fail with 'null value in column "user_id" violates not-null constraint'
  File: frontend/src/components/CreatePost.tsx:67
  Fix:  Add user_id: session.user.id and category_id to insert
```

### Supabase Check 4: Client tries to set server-managed columns?
```
Client:  supabase.from('profiles').insert({ id: customId, created_at: new Date(), user_id })
Schema:  id has DEFAULT gen_random_uuid(), created_at has DEFAULT now()
→ WARNING: Setting id/created_at client-side overrides server defaults
  File: mobile/src/screens/OnboardingScreen.tsx:34
  Fix:  Remove id and created_at from insert — let Supabase generate them
```

### Supabase Check 5: RLS will block this operation?
```
Schema RLS:  profiles.SELECT policy — USING (auth.uid() = user_id)
Client:      supabase.from('profiles').select() called BEFORE auth.getUser() resolves
             (called in component that renders before auth state is ready)
→ HIGH: RLS will return empty array when called unauthenticated — no error, just silent empty
  File: frontend/src/pages/Dashboard.tsx:12
  Fix:  Wait for auth session before querying, or add .eq('user_id', session.user.id) explicitly
```

### Supabase Check 6: Auth session not passed to client?
```
supabase client initialized WITHOUT session from storage
All authenticated queries will fail silently (RLS blocks them)
→ CRITICAL: Supabase client not initialized with persisted session
  File: mobile/src/lib/supabase.ts
  Fix:  Use ExpoSecureStoreAdapter for storage in React Native client init
```

### Supabase Check 7: Using getSession() instead of getUser()?
```
Client:  const { data: { session } } = await supabase.auth.getSession()
         const user = session?.user
→ HIGH SECURITY: getSession() reads from local storage — can be spoofed
  Fix:  Use supabase.auth.getUser() which validates with Supabase server
  Files: [list all occurrences]
```

### Supabase Check 8: Edge Function name exists?
```
Client calls:  supabase.functions.invoke('send-push-notification', { body })
Functions dir: supabase/functions/send-notification/  (different name)
→ CRITICAL: Edge function does not exist — will return 404
  File: mobile/src/hooks/useNotifications.ts:78
  Fix:  Change to 'send-notification'
```

### Supabase Check 9: Edge Function input shape mismatch?
```
Function expects: { userId: string, message: string, type: 'push' | 'email' }
Client sends:     { user_id: string, msg: string }   ← wrong field names
→ HIGH: Edge function will receive undefined for required fields
  File: frontend/src/services/notifications.ts:23
  Fix:  Change to { userId, message, type: 'push' }
```

### Supabase Check 10: Storage bucket exists and path is correct?
```
Client uploads to:  supabase.storage.from('profile-images').upload(path, file)
Buckets in schema:  avatars  (no 'profile-images' bucket)
→ CRITICAL: Storage bucket does not exist
  Fix:  Create bucket 'profile-images' in Supabase dashboard OR change client to use 'avatars'
```

### Supabase Check 11: Missing await on async operations?
```
Client:  supabase.from('posts').insert({ title, body })   ← no await
→ HIGH: Insert fires but result is never checked — errors silently discarded
  File: frontend/src/components/CreatePost.tsx:89
  Fix:  const { error } = await supabase.from('posts').insert(...)
```

### Supabase Check 12: Realtime subscription without filter?
```
Client:  supabase.channel('orders').on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, callback)
RLS:     orders table is user-scoped
→ HIGH: Unfiltered realtime subscription — RLS applies but client receives events for ALL orders then filters
         Better to add: filter: `user_id=eq.${userId}`
  File: mobile/src/screens/OrdersScreen.tsx:45
```

### Supabase Check 13: supabase.rpc() function exists?
```
Client calls:  supabase.rpc('calculate_user_stats', { user_id })
Migrations:    No CREATE FUNCTION calculate_user_stats found
→ CRITICAL: RPC function does not exist in database
  File: admin/src/hooks/useStats.ts:34
```

### Supabase Check 14: Join syntax correct?
```
Client:  supabase.from('posts').select('*, author(username)')
Schema:  posts has user_id FK to auth.users — no 'author' relationship defined
         Need: posts has author_id FK to profiles, and profiles table has username
→ HIGH: Join will fail silently — returns null for author
  Fix:  Either rename FK column to 'author_id', or use: select('*, profiles!user_id(username)')
```

---

## S4 — Supabase Sync Report

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

═══════════════════════════════════════════════════════════════════
 CRITICAL — Will fail or return wrong data at runtime
═══════════════════════════════════════════════════════════════════
[show each issue with: check type, file:line, what's wrong, exact fix]

═══════════════════════════════════════════════════════════════════
 HIGH — Security issues or silent failures
═══════════════════════════════════════════════════════════════════
[show each issue]

═══════════════════════════════════════════════════════════════════
 TABLES NEVER ACCESSED BY ANY CLIENT (dead schema?)
═══════════════════════════════════════════════════════════════════
[list tables defined in schema but never called by any client]
(May be intentional — used only server-side or via Edge Functions)

═══════════════════════════════════════════════════════════════════
 COLUMNS NEVER READ BY ANY CLIENT
═══════════════════════════════════════════════════════════════════
[list columns that exist in schema but no client selects them]
```

---

# ═══════════════════════════════════════════════
# REST MODE
# (runs when backend is NestJS / Express / Next.js)
# ═══════════════════════════════════════════════

## R1 — Extract Backend Contract

### For NestJS:
Scan all `@Controller`, `@Get`, `@Post`, `@Put`, `@Patch`, `@Delete`, `@UseGuards` decorators.
For each endpoint extract:
- Full URL path (combine `@Controller` prefix + method decorator path)
- HTTP method
- Auth required? (`@UseGuards(JwtAuthGuard)` or similar)
- Request body DTO (find `@Body()` parameter type, read the DTO class fields)
- Response type (return type annotation or `@ApiResponse` decorator)
- URL params (`@Param`) and query params (`@Query`)

### For Express/Fastify:
Scan router files for `app.get/post/put/patch/delete` and `router.get/post/etc`.

### For Next.js API routes:
Each file in `pages/api/` or `app/api/` is an endpoint. Method from handler switch or HTTP method exports.

Build contract table:
```
BACKEND CONTRACT
────────────────────────────────────────────────────────────────────
Method  │ URL                     │ Auth │ Body DTO       │ Response
────────┼─────────────────────────┼──────┼────────────────┼──────────
GET     │ /api/v1/users           │ JWT  │ —              │ User[]
POST    │ /api/v1/users           │ JWT  │ CreateUserDto  │ User
...
```

## R2 — Extract Client REST Usage

Scan all clients for axios/fetch calls, follow service layer abstractions.

## R3 — REST Cross-Reference Checks

1. Missing routes (client calls endpoint that doesn't exist → 404)
2. Wrong HTTP method (PUT vs PATCH → 405)
3. URL typos (singular vs plural, wrong version)
4. Missing required body fields
5. Wrong response path (incorrect data unwrapping)
6. Missing auth header on protected routes
7. Wrong query param names
8. Base URL / port mismatch
9. API version mismatch (v1 vs v2)
10. Response envelope inconsistency

## R4 — REST Sync Report

Same format as Supabase report but for REST endpoints.

---

# ═══════════════════════════════════════════════
# PHASE 2 — GENERATE FIXES
# ═══════════════════════════════════════════════

For each critical issue, generate the exact code fix with file path and line number.

Show:
```
Issue #3: Column name mismatch
  File:   mobile/src/screens/ProfileScreen.tsx:45
  Before: supabase.from('profiles').select('id, username, profilePicture')
  After:  supabase.from('profiles').select('id, username, avatar_url')
```

---

# ═══════════════════════════════════════════════
# PHASE 3 — PHASE GATE
# ═══════════════════════════════════════════════

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
