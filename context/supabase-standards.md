# Supabase Standards

Authoritative rules for all Supabase work in this codebase. Every agent and engineer working on the database, auth, storage, edge functions, or realtime must follow these without exception.

---

## RLS Standards

Row Level Security is the primary access control mechanism. It is not optional.

**RLS must be enabled on every table that contains user data.** Enable it in the same migration that creates the table — never after the fact.

```sql
-- Do this in the same migration that creates the table
ALTER TABLE public.table_name ENABLE ROW LEVEL SECURITY;
```

**Every table needs explicit policies for all 4 operations: SELECT, INSERT, UPDATE, DELETE.**
An absent policy with RLS enabled is a deny. Explicit policies are required so that the intent is clear, reviewable, and auditable. "Deny by default" is not a substitute for documented policies.

**Always use `auth.uid()` — never trust a client-supplied `user_id`.**
A client can send any UUID they want in a request body or query param. `auth.uid()` is derived from the verified JWT by Supabase's PostgREST layer. It cannot be forged by a client. All RLS policies must derive the user identity from `auth.uid()`.

```sql
-- Correct
USING (auth.uid() = user_id)

-- Wrong — client can supply any uuid
USING (user_id = current_setting('request.jwt.claims', true)::json->>'sub')
```

**`WITH CHECK` is required on every INSERT and UPDATE policy.**
`USING` filters which rows an operation applies to. `WITH CHECK` validates the data being written. Without `WITH CHECK`, a user could insert or update a row with a `user_id` they don't own — this is a privilege escalation vulnerability.

```sql
-- Correct
CREATE POLICY "table: users can update own"
  ON public.table_name
  FOR UPDATE
  USING (auth.uid() = user_id)       -- controls which rows can be targeted
  WITH CHECK (auth.uid() = user_id); -- controls what can be written

-- Wrong — missing WITH CHECK
CREATE POLICY "table: users can update own"
  ON public.table_name
  FOR UPDATE
  USING (auth.uid() = user_id);
```

**The service role key is server-only. It must never appear in client-side code.**
The service role key bypasses all RLS. If it is in a browser bundle or a client-accessible environment variable, every RLS policy in the database is effectively disabled for anyone who extracts it. It belongs only in Edge Functions and trusted server environments, set via secure secrets management — never in `.env` files that get committed.

---

## Schema Naming Standards

Consistent naming makes queries, migrations, and generated types predictable across the codebase.

| Object | Convention | Examples |
|---|---|---|
| Table names | plural `snake_case` | `users`, `posts`, `workspace_members`, `audit_logs` |
| Column names | `snake_case` | `first_name`, `created_at`, `is_active` |
| FK columns | `{singular_table}_id` | `user_id`, `post_id`, `workspace_id`, `order_id` |
| Boolean columns | `is_` prefix | `is_active`, `is_verified`, `is_deleted`, `is_public` |
| Timestamp columns | `_at` suffix | `created_at`, `updated_at`, `deleted_at`, `published_at` |
| Enum type names | singular `snake_case` | `order_status`, `user_role`, `post_status`, `payment_method` |
| Index names | `idx_{table}_{column(s)}` | `idx_posts_user_id`, `idx_orders_user_status` |
| Policy names | `"{table}: description"` | `"posts: owners can update"` |
| Function names | `snake_case` verbs | `handle_new_user`, `is_workspace_member`, `handle_updated_at` |

**Required columns on every table:**

```sql
id          uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
created_at  timestamptz DEFAULT now() NOT NULL,
updated_at  timestamptz DEFAULT now() NOT NULL
```

**Required column on every user-owned table:**

```sql
user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
```

`ON DELETE CASCADE` is mandatory on `auth.users` references. When Supabase deletes a user, all their data must be removed. Orphaned rows are a data integrity bug and a potential GDPR violation.

---

## Required Indexes

Indexes are not optional. Missing indexes on FK columns cause full table scans on every join and RLS policy evaluation.

**Every FK column must have an index.**

```sql
-- If a column is a foreign key, it needs an index
CREATE INDEX idx_posts_user_id ON public.posts (user_id);
CREATE INDEX idx_comments_post_id ON public.comments (post_id);
CREATE INDEX idx_workspace_members_workspace_id ON public.workspace_members (workspace_id);
CREATE INDEX idx_workspace_members_user_id ON public.workspace_members (user_id);
```

**`created_at` must be indexed on tables that are queried or sorted by time.**

```sql
CREATE INDEX idx_posts_created_at ON public.posts (created_at DESC);
CREATE INDEX idx_audit_logs_created_at ON public.audit_logs (created_at DESC);
```

**`user_id` must be indexed on all user-owned tables** (in addition to satisfying the FK index rule above).

**Add composite indexes for the most common filter + sort combinations.**

```sql
-- If the app frequently runs: WHERE user_id = $1 AND status = $2
CREATE INDEX idx_orders_user_status ON public.orders (user_id, status);

-- If the app frequently runs: WHERE workspace_id = $1 ORDER BY created_at DESC
CREATE INDEX idx_posts_workspace_created ON public.posts (workspace_id, created_at DESC);
```

---

## Migration Standards

### File Naming

```
supabase/migrations/YYYYMMDDHHMMSS_description.sql
```

- Timestamp is UTC. Generate with: `date -u +"%Y%m%d%H%M%S"`
- Description is lowercase `snake_case` and describes the change
- One logical change per file (don't bundle unrelated changes)

### Structure

Every migration must be wrapped in a `BEGIN/COMMIT` transaction block. If any statement fails, the entire migration rolls back — no partial state.

```sql
-- Migration: 20240103150000_add_orders.sql
-- Description: Add orders table with enum, RLS, indexes, and trigger
-- Rollback:
--   DROP TRIGGER IF EXISTS set_updated_at ON public.orders;
--   DROP TABLE IF EXISTS public.orders;
--   DROP TYPE IF EXISTS public.order_status;

BEGIN;

-- schema changes here

COMMIT;
```

Every migration must include a `-- Rollback:` comment at the top describing how to undo it. This is documentation — it does not execute automatically.

### Immutability

**Migrations are immutable once applied to production.** Never edit a migration file that has been run against any non-local environment. The Supabase CLI tracks migration checksums — editing an applied migration causes divergence and breaks `supabase db push`. If a change is needed, write a new migration.

### Safety Checklist Before Running Destructive Migrations

Before any migration that drops a column, table, or type:
- Confirm no active code references the object being dropped
- Confirm no FK constraints reference the object
- Test the rollback comment on a local instance
- Deploy the code change that removes the reference first, then deploy the migration

---

## Auth Standards

### Token Configuration

| Setting | Value | Reason |
|---|---|---|
| Access token expiry | `3600s` (1 hour) | Short-lived to limit blast radius of a leaked token |
| Refresh token expiry | `604800s` (7 days) | Persistent sessions without requiring constant re-login |
| Email confirmation | Required in production | Prevents account enumeration and verifies ownership |
| Minimum password length | 8 characters | Absolute floor — consider enforcing complexity too |

### Client Configuration

The Supabase client must be initialized as a singleton. One instance per application. Never create multiple clients in the same browser context.

```typescript
// src/lib/supabase.ts — initialize once, import everywhere
import { createClient } from '@supabase/supabase-js'
import type { Database } from '@/types/supabase'

export const supabase = createClient<Database>(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY,
  {
    auth: {
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: true,
    },
  }
)
```

### Server-Side Auth Verification

When verifying a user's identity in an Edge Function or server context, always use `getUser()` — not `getSession()`.

`getSession()` reads from local storage and does not make a network call to verify the JWT with Supabase's auth server. A tampered token will pass `getSession()`. `getUser()` always verifies against the server.

```typescript
// Correct — verifies with Supabase auth server
const { data: { user }, error } = await supabase.auth.getUser()

// Wrong for server-side — reads local storage only, does not verify
const { data: { session } } = await supabase.auth.getSession()
```

---

## Edge Function Standards

### JWT Verification

Every Edge Function that processes user data must verify the JWT as its first action. Business logic never runs before authentication is confirmed.

```typescript
// First action in every Edge Function:
const { data: { user }, error: authError } = await supabase.auth.getUser()
if (authError || !user) {
  return new Response(
    JSON.stringify({ data: null, error: 'Unauthorized' }),
    { status: 401, headers: { 'Content-Type': 'application/json' } }
  )
}
// Only proceed past this point with a verified user
```

### Service Role Key Usage

Never use the service role key in an Edge Function unless it is absolutely necessary and the reason is explicitly documented in a comment directly above the client creation.

```typescript
// JUSTIFICATION: This webhook handler is triggered by Stripe, not a user.
// It updates order status across all users — RLS cannot be used.
// The endpoint is authenticated via Stripe webhook signature verification above.
const adminClient = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)
```

If you cannot write a clear justification, you probably don't need the service role key.

### Input Validation

Every parameter received from a client request must be validated before use. Never assume the request body matches the expected shape.

```typescript
const body = await req.json()
const { orderId, quantity } = body

if (!orderId || typeof orderId !== 'string') {
  return errorResponse('orderId is required', 400)
}
if (!quantity || typeof quantity !== 'number' || quantity < 1) {
  return errorResponse('quantity must be a positive integer', 400)
}
```

### Response Shape

All Edge Functions return the same JSON envelope. This makes error handling consistent on the client.

```typescript
// Success
{ "data": { ... }, "error": null }

// Error
{ "data": null, "error": "Human-readable error message" }
```

Never return raw error objects, stack traces, or database error messages to the client.

### Performance

Edge Functions run with a default 2-second wall clock limit. Keep functions fast:
- Do not perform N+1 database queries
- Do not make multiple sequential external API calls when they can be parallelized
- Do not do image processing, PDF generation, or heavy CPU work synchronously — use a queue or background job

---

## Storage Standards

### Bucket Privacy

**Never use a `public` bucket for user-uploaded content.** Public buckets serve files without authentication — any URL is accessible by anyone. Use private buckets and serve files via signed URLs.

Acceptable uses of public buckets: marketing assets, public product images, static content that is intentionally world-readable and not tied to a specific user.

### File Path Structure

**File paths must always follow `{userId}/{uuid}.{ext}`.** Never use the original filename supplied by the client. Client-supplied filenames can contain path traversal sequences, Unicode tricks, or collide with other users' files.

```typescript
const ext = file.name.split('.').pop()?.toLowerCase() ?? 'bin'
const filePath = `${userId}/${crypto.randomUUID()}.${ext}`
```

### MIME Type Validation

**Every bucket must have an explicit MIME type allowlist.** Never configure a bucket that accepts all MIME types.

```sql
INSERT INTO storage.buckets (id, name, public, allowed_mime_types)
VALUES (
  'avatars', 'avatars', false,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
  -- not 'image/*' — enumerate exactly what is allowed
);
```

Validate MIME type on the client before upload. Do not rely solely on server-side validation — fail fast.

### File Size Limits

Every bucket must define a `file_size_limit` in bytes. Define it at bucket creation time. Common defaults:

| Bucket type | Recommended limit |
|---|---|
| User avatars | `2097152` (2MB) |
| Document attachments | `10485760` (10MB) |
| Video uploads | `104857600` (100MB) |

### Signed URL Expiry

| URL type | Expiry | Reason |
|---|---|---|
| Download (read) signed URL | `3600s` (1 hour) | Long enough for normal use, short enough to limit leak window |
| Upload signed URL | `300s` (5 minutes) | Upload should be immediate — short window limits misuse |

Never generate signed URLs with expiry longer than 24 hours for user content.

---

## Realtime Standards

### Subscription Filtering

**Never subscribe to an entire table without a filter.** An unfiltered `postgres_changes` subscription sends every row change for the entire table to the client. This is a data leak — the client receives data for rows they have no business seeing.

```typescript
// Wrong — receives ALL changes across ALL users
supabase.channel('all-messages')
  .on('postgres_changes', {
    event: '*', schema: 'public', table: 'messages'
  }, handler)

// Correct — receives only changes for this user's messages
supabase.channel(`messages:${userId}`)
  .on('postgres_changes', {
    event: '*', schema: 'public', table: 'messages',
    filter: `user_id=eq.${userId}` // required
  }, handler)
```

For workspace or team-scoped data, filter by the relevant FK:

```typescript
filter: `workspace_id=eq.${workspaceId}`
```

### Cleanup on Unmount

Every realtime subscription must be cleaned up when the component or hook that created it is destroyed. Leaked subscriptions consume server-side resources and can cause stale state bugs.

```typescript
useEffect(() => {
  const channel = supabase.channel(...)
    .on('postgres_changes', { ... }, handler)
    .subscribe()

  // This cleanup function is mandatory
  return () => {
    supabase.removeChannel(channel)
  }
}, [userId])
```

---

## TypeScript Integration Standards

### Type Generation

TypeScript types for all Supabase tables, views, and enums must be generated from the actual schema — not hand-written. Generated types are the source of truth.

```bash
# Generate types from local dev instance
supabase gen types typescript --local > src/types/supabase.ts

# Add to package.json for easy regeneration
# "types:gen": "supabase gen types typescript --local > src/types/supabase.ts"
```

**Generated types must be committed to the repository.** They are part of the codebase contract. Regenerate them whenever a migration changes the schema, and commit the updated types in the same PR as the migration.

### No `any` for Query Results

Never use `any` as the type for Supabase query results. The generated `Database` type provides complete type coverage.

```typescript
import type { Database } from '@/types/supabase'

// Correct — fully typed
type Profile = Database['public']['Tables']['profiles']['Row']
type NewProfile = Database['public']['Tables']['profiles']['Insert']
type ProfileUpdate = Database['public']['Tables']['profiles']['Update']
type OrderStatus = Database['public']['Enums']['order_status']

// Wrong — loses all type safety
const { data } = await supabase.from('profiles').select('*')
const profile = data as any // never
```

### Typed Client

The Supabase client must be instantiated with the `Database` generic. This enables full autocomplete on `.from()` table names, column selectors, and return types.

```typescript
import { createClient } from '@supabase/supabase-js'
import type { Database } from '@/types/supabase'

// The Database generic makes all queries type-safe
export const supabase = createClient<Database>(url, key)

// Now .from() autocompletes table names, and results are typed automatically
const { data } = await supabase.from('profiles').select('id, display_name')
// data: Array<{ id: string; display_name: string }> | null
```
