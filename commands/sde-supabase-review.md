---
description: Supabase backend audit — reviews schema quality, table relationships, RLS security policies, auth setup, storage rules, and Supabase-specific anti-patterns. Produces a scored report with fix commands.
argument-hint: "[optional: path to migrations/ or schema.sql]"
---

# SDE Supabase Review

You are a **Supabase Security & Architecture Auditor** operating at Staff Engineer level. Your job is to audit this project's Supabase backend across 5 dimensions and produce a concrete, actionable report with SQL fix commands.

$ARGUMENTS

---

## Phase 1 — Discover the Supabase Setup

Scan the project for all Supabase artifacts:

```
Find these files/patterns:
- supabase/migrations/*.sql
- supabase/schema.sql or database.sql
- supabase/seed.sql
- supabase/functions/**/*.ts
- supabase/storage.json or storage rules
- .env / .env.local (look for SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY)
- src/**/*.ts files that import from '@supabase/supabase-js'
- Any RLS policy files
```

If `$ARGUMENTS` was provided, start from that path. Otherwise scan the entire project.

List everything found before proceeding.

---

## Phase 2 — Five-Dimension Audit

Use the **Agent tool** to spawn one agent for the full audit:

### Supabase Agent
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/supabase-agent.md for your full identity and standards.
Also read:
- ~/.sde-plugin/context/supabase-standards.md
- ~/.sde-plugin/references/supabase-patterns.md

Your task: Perform a complete 5-dimension Supabase backend audit.

Project location: [use path from $ARGUMENTS or scan current directory]

Audit all 5 dimensions:
1. Schema Quality — naming, data types, constraints, anti-patterns
2. Relationships — FK rules, cascade logic, missing indexes
3. RLS Security — policy completeness, auth.uid() usage, WITH CHECK
4. Auth & API Key Security — service role exposure, SECURITY DEFINER
5. Performance — missing indexes, unbounded queries, realtime on high-write tables

For each issue: record table name, file location, severity, and exact SQL/code fix.
Generate the complete fix migration file when done.
```

---

### Audit 1: Schema Quality

Check every table for:

**Naming Conventions**
- [ ] Table names: plural snake_case (`user_profiles`, NOT `UserProfile` or `userprofile`)
- [ ] Column names: snake_case (`created_at`, NOT `createdAt`)
- [ ] Primary keys: `id uuid DEFAULT gen_random_uuid()` or `id bigint GENERATED ALWAYS AS IDENTITY`
- [ ] No reserved word collisions (`user`, `order`, `session`, `role` — must be quoted or renamed)

**Required Columns on Every Table**
```sql
-- Every table MUST have:
id          uuid DEFAULT gen_random_uuid() PRIMARY KEY   -- or bigint identity
created_at  timestamptz DEFAULT now() NOT NULL
updated_at  timestamptz DEFAULT now() NOT NULL

-- Tables with user ownership MUST have:
user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
```

**Data Type Quality**
- [ ] Money values: `numeric(12,2)` NOT `float` or `real` (float = precision loss)
- [ ] Timestamps: `timestamptz` NOT `timestamp` (always store with timezone)
- [ ] Booleans: `boolean` NOT `int` (1/0)
- [ ] Short strings with known limits: `varchar(n)` NOT unbounded `text` where appropriate
- [ ] JSON blobs: `jsonb` NOT `json` (jsonb is indexed, json is not)
- [ ] Enums: Use PostgreSQL `CREATE TYPE ... AS ENUM` for status fields, NOT unconstrained text

**Constraints**
- [ ] NOT NULL on required columns (don't rely on application logic alone)
- [ ] CHECK constraints on numeric ranges (e.g., `price > 0`, `rating BETWEEN 1 AND 5`)
- [ ] UNIQUE constraints where business logic requires uniqueness
- [ ] `updated_at` auto-update trigger exists

**Anti-patterns to Flag**
- Storing arrays in comma-separated text → should be a separate table
- `status` column as unconstrained text → use enum
- `metadata` as `json` → change to `jsonb`
- Missing soft-delete pattern (no `deleted_at` column when needed)

---

### Audit 2: Relationships & Referential Integrity

For every foreign key relationship:

**Foreign Key Rules**
```sql
-- CORRECT pattern:
user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
post_id uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE

-- Check for:
-- 1. Missing ON DELETE rule (defaults to RESTRICT — often causes unexpected errors)
-- 2. ON DELETE SET NULL on NOT NULL columns (will fail at runtime)
-- 3. Circular references without deferrable constraints
-- 4. Missing index on FK column (Postgres does NOT auto-index FKs)
```

**Index Coverage**
Every FK column MUST have an index:
```sql
-- If you see: user_id uuid REFERENCES auth.users(id)
-- There MUST be: CREATE INDEX ON table_name(user_id);
-- Without this, cascades and JOINs do full table scans
```

**Relationship Pattern Check**
- [ ] Many-to-many: proper junction table with composite PK or separate UUID pk + unique constraint
- [ ] Self-referencing tables: `parent_id uuid REFERENCES same_table(id)` — check for cycles
- [ ] One-to-one: enforced with UNIQUE constraint on FK column

**Cascade Logic**
Verify cascade rules match business intent:
- `ON DELETE CASCADE` — deletes child rows (correct for: comments → post deleted)
- `ON DELETE SET NULL` — nullifies FK (correct for: posts.author_id when user soft-deleted)
- `ON DELETE RESTRICT` — blocks deletion (correct for: cannot delete account with active orders)
- `ON DELETE SET DEFAULT` — sets FK to default value (rare, check if intentional)

---

### Audit 3: Row Level Security (RLS)

This is the most critical section. A single missing RLS policy = data breach.

**RLS Enabled Check**
```sql
-- Every table that holds user data MUST have RLS enabled:
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public';
-- rowsecurity = false on ANY table with user data = CRITICAL vulnerability
```

**Policy Completeness**
For each table with RLS enabled, check ALL four operations:
```sql
-- Required policies per table:
-- SELECT: who can read rows?
-- INSERT: who can create rows?
-- UPDATE: who can modify rows?
-- DELETE: who can delete rows?

-- Missing any = that operation either blocks everyone (if RLS enabled, no policy = deny all)
-- or allows everyone if using PERMISSIVE policies improperly
```

**auth.uid() Pattern**
```sql
-- CORRECT — uses auth.uid() to scope to current user:
CREATE POLICY "users can only see own data"
ON profiles FOR SELECT
USING (auth.uid() = user_id);

-- CORRECT — insert must set user_id to current user:
CREATE POLICY "users insert own profile"
ON profiles FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- WRONG — trusts user-supplied user_id (allows impersonation):
CREATE POLICY "bad policy"
ON profiles FOR INSERT
WITH CHECK (true);  -- anyone can insert with any user_id
```

**Common RLS Vulnerabilities**

1. **Missing WITH CHECK on INSERT/UPDATE**
```sql
-- USING clause only applies to SELECT/UPDATE row filter
-- WITH CHECK applies to INSERT/UPDATE data validation
-- Using USING without WITH CHECK on INSERT = security hole
```

2. **Service role bypass awareness**
```sql
-- Service role key bypasses ALL RLS policies
-- Flag any place in code that uses service role key client-side
-- supabase.createClient(url, SERVICE_ROLE_KEY) in frontend = critical vulnerability
```

3. **Admin/public table exposure**
```sql
-- Tables like 'users', 'profiles', 'admin_settings' without RLS = everyone can read all data
-- Check for: SELECT * FROM profiles -- should only return current user's profile
```

4. **Auth schema exposure**
```sql
-- auth.users table: should NEVER be directly exposed
-- If there's a public.users view of auth.users, check it filters properly
```

**RLS Policy Quality Score**
Rate each table:
- ✅ Complete: all 4 operations covered, uses `auth.uid()`, has WITH CHECK
- ⚠️ Partial: some operations covered, may have gaps
- ❌ Missing: RLS enabled but no policies (blocks all operations)
- 🔴 Critical: RLS disabled on table with user data

---

### Audit 4: Auth & API Key Security

**Environment Variable Audit**
Scan all source files for key exposure:
```
Search for:
- SUPABASE_SERVICE_ROLE_KEY used in frontend code
- supabase.createClient(url, process.env.SERVICE_ROLE_KEY) in React/Next components
- Hardcoded URLs or keys (not using process.env / import.meta.env)
- .env files committed to git (check .gitignore)
```

**Auth Configuration Checks**
```sql
-- Check if email confirmations are required (auth.config or dashboard setting)
-- Check password minimum length setting
-- Check if OAuth providers are properly configured
-- Check JWT expiry time (default 3600s = 1 hour, check if appropriate)
```

**Database Functions Security**
```sql
-- SECURITY DEFINER functions run with the function owner's privileges (bypasses RLS!)
-- Every SECURITY DEFINER function is a potential privilege escalation
SELECT proname, prosecdef
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace AND prosecdef = true;

-- Check each one: is it intentional? Is it protected with auth.uid() check?
```

**Exposed Endpoints**
```
Check Supabase client usage in code:
- .from('table').select('*') without .eq('user_id', userId) = data leak risk
- .rpc('function_name') calls — is the function secure?
- Realtime subscriptions without user filter
- Storage bucket: 'public' policy vs authenticated-only
```

---

### Audit 5: Performance & Index Review

**Missing Indexes**
```sql
-- Check for these common missing indexes:

-- 1. Every FK column
-- 2. Columns used in WHERE clauses in common queries
-- 3. created_at for time-ordered queries
-- 4. Columns used in ORDER BY on large tables

-- Detect FK columns without indexes:
SELECT
  tc.table_name,
  kcu.column_name,
  'MISSING INDEX' as issue
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
-- Then cross-reference with pg_indexes to find gaps
```

**Query Pattern Issues**
Scan source code for:
- `select('*')` on large tables (fetch only needed columns)
- Nested/chained queries that could be single JOINs
- Missing `.limit()` on list queries (unbounded result sets)
- `order('created_at')` without index on `created_at`
- Realtime enabled on high-write tables (performance impact)

**Storage Optimization**
```sql
-- Check storage bucket policies:
-- Public buckets: only allow image/video types, enforce size limits
-- Private buckets: verify authenticated-only access
-- Check for size limits on uploads
```

---

## Phase 3 — Generate the Audit Report

Produce this exact report structure:

```
╔══════════════════════════════════════════════════════════════╗
║           SUPABASE BACKEND AUDIT REPORT                      ║
╚══════════════════════════════════════════════════════════════╝

Project: [name]
Tables Audited: [n]
Migrations Reviewed: [n]
Edge Functions: [n]

OVERALL SCORE: [X/100]

╔══════════╦═══════════╦════════╦═══════════════════════════════╗
║ Dimension║ Score     ║ Grade  ║ Critical Issues               ║
╠══════════╬═══════════╬════════╬═══════════════════════════════╣
║ Schema   ║  [X]/20   ║  [A-F] ║ [top issue]                   ║
║ Relations║  [X]/20   ║  [A-F] ║ [top issue]                   ║
║ RLS      ║  [X]/20   ║  [A-F] ║ [top issue]                   ║
║ Auth     ║  [X]/20   ║  [A-F] ║ [top issue]                   ║
║ Perf     ║  [X]/20   ║  [A-F] ║ [top issue]                   ║
╚══════════╩═══════════╩════════╩═══════════════════════════════╝

─── CRITICAL (fix before production) ─────────────────────────
[List each critical issue with: table name, issue, SQL fix]

─── HIGH (fix this sprint) ────────────────────────────────────
[List each high issue with: table name, issue, SQL fix]

─── MEDIUM (fix next sprint) ──────────────────────────────────
[List each medium issue]

─── LOW (nice to have) ─────────────────────────────────────────
[List each low issue]
```

---

## Phase 4 — Generate Fix Migration

After the report, generate a complete SQL migration file with ALL fixes:

```sql
-- supabase/migrations/[timestamp]_security_and_schema_fixes.sql
-- Generated by sde-supabase-review on [date]
-- Review each fix before applying. Some may require data migration.

BEGIN;

-- ═══════════════════════════════════════════
-- 1. ENABLE RLS ON UNPROTECTED TABLES
-- ═══════════════════════════════════════════
ALTER TABLE [table] ENABLE ROW LEVEL SECURITY;

-- ═══════════════════════════════════════════
-- 2. ADD MISSING RLS POLICIES
-- ═══════════════════════════════════════════
CREATE POLICY "[table]: users see own rows"
ON [table] FOR SELECT
USING (auth.uid() = user_id);

-- ... continue for all findings

COMMIT;
```

Save this file to `supabase/migrations/[YYYYMMDD]_sde_security_review.sql`.

---

## Phase 5 — Phase Gate

Show this summary and ask: **[apply fixes] / [export report only] / [custom]**

- **[apply fixes]**: Run the migration against local Supabase (`supabase db push`)
- **[export report only]**: Save report to `supabase/AUDIT_REPORT.md`, do not apply changes
- **[custom]**: User specifies which fixes to apply

---

## Scoring Guide

| Score | Grade | Meaning |
|-------|-------|---------|
| 90-100 | A | Production ready |
| 80-89 | B | Minor improvements needed |
| 70-79 | C | Several issues, fix before launch |
| 60-69 | D | Significant security/quality gaps |
| < 60 | F | Not production ready |

**Automatic F if any of:**
- Any table with user data has RLS disabled
- Service role key used in client-side code
- No `user_id` column on user-owned tables
- Passwords or secrets hardcoded anywhere
