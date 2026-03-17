---
description: Supabase backend audit — reviews schema quality, table relationships, RLS security policies, auth setup, storage rules, and Supabase-specific anti-patterns. Produces a scored report with fix commands.
argument-hint: "[optional: path to migrations/ or schema.sql]"
allowed-tools: Agent, Read, Grep, Glob
disable-model-invocation: true
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

## What This Phase Produces

Detailed check criteria for each dimension are in `supabase-agent.md` and `supabase-standards.md`. Summary of what the audit covers:

- **Dimension 1 — Schema Quality**: plural snake_case naming, required columns (id, created_at, updated_at, user_id), correct data types (timestamptz not timestamp, numeric not float for money, jsonb not json), NOT NULL constraints, updated_at triggers, enum types for status fields
- **Dimension 2 — Relationships**: ON DELETE rules on all FKs, indexes on all FK columns (Postgres does NOT auto-index FKs), junction table patterns for M:N, cascade logic matches business intent
- **Dimension 3 — RLS Security**: RLS enabled on every user-data table, all 4 operations covered (SELECT/INSERT/UPDATE/DELETE), auth.uid() pattern correct, WITH CHECK on INSERT/UPDATE, no service role key in client code
- **Dimension 4 — Auth & API Key Security**: SUPABASE_SERVICE_ROLE_KEY absent from frontend code, no hardcoded keys, SECURITY DEFINER functions audited for privilege escalation risk
- **Dimension 5 — Performance**: indexes on FK columns + ORDER BY columns, select('*') flagged on large tables, missing .limit() on list queries, realtime avoided on high-write tables

---

## Phase 3 — Audit Report Format

```
╔══════════════════════════════════════════════════════════════╗
║           SUPABASE BACKEND AUDIT REPORT                      ║
╚══════════════════════════════════════════════════════════════╝

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

[Critical issues with table name, issue, SQL fix]
[High issues]
[Medium issues]
[Low issues]
```

Automatic F if: any user-data table has RLS disabled, service role key in client code, no user_id on user-owned tables, or secrets hardcoded.

---

## Phase 4 — Generate Fix Migration

Generate `supabase/migrations/[YYYYMMDD]_sde_security_review.sql` with all fixes wrapped in BEGIN/COMMIT.

---

## Phase 5 — Phase Gate

Show this summary and ask: **[apply fixes] / [export report only] / [custom]**

- **[apply fixes]**: Run the migration against local Supabase (`supabase db push`)
- **[export report only]**: Save report to `supabase/AUDIT_REPORT.md`, do not apply changes
- **[custom]**: User specifies which fixes to apply
