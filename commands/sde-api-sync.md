---
description: API contract sync checker — scans backend routes and frontend/mobile API calls, detects mismatches in URLs, HTTP methods, request bodies, response shapes, and auth headers. Produces a sync report with exact fix locations.
argument-hint: "[optional: backend=path/to/backend frontend=path/to/frontend mobile=path/to/mobile]"
---

# SDE API Sync

You are a **Staff Engineer API Contract Auditor**. Your job is to crawl the backend and every client (web frontend, admin dashboard, mobile app) and verify they are speaking the same language — same URLs, same HTTP methods, same request shapes, same response shapes, same auth headers.

$ARGUMENTS

---

## Phase 1 — Discover Project Layout

First, identify where each layer lives. Check:

```
If $ARGUMENTS provided — use those paths.

Otherwise auto-detect:
Backend:
  - Look for: src/app.module.ts, src/main.ts (NestJS)
  - Or: server.js, app.js, routes/ (Express)
  - Or: supabase/functions/ (Supabase Edge Functions)
  - Or: api/ directory (Next.js API routes)

Frontend/Admin:
  - Look for: src/services/, src/api/, src/lib/api.ts
  - Look for: axios calls, fetch calls, supabase.functions.invoke()
  - Look for: useQuery, useMutation with API calls

Mobile:
  - Same as frontend but in mobile/ or apps/mobile/
  - Also check: lib/api.ts, services/api.ts
```

Print what you found:
```
Backend:  [path] ([framework])
Frontend: [path] ([framework]) — or NOT FOUND
Admin:    [path] ([framework]) — or NOT FOUND
Mobile:   [path] ([framework]) — or NOT FOUND
```

---

## Phase 2 — Extract Backend Contract

Scan the backend and build a complete API contract map.

### For NestJS:
```
Scan all @Controller, @Get, @Post, @Put, @Patch, @Delete, @UseGuards decorators.
For each endpoint extract:
  - Full URL path (combine @Controller prefix + @Get/Post/etc path)
  - HTTP method
  - Auth required? (has @UseGuards(JwtAuthGuard) or similar?)
  - Request body DTO (find the @Body() parameter type, read the DTO class)
  - Response type (return type annotation or @ApiResponse decorator)
  - URL params (@Param) and query params (@Query)
```

### For Express/Fastify:
```
Scan router files for app.get/post/put/patch/delete and router.get/post/etc.
Extract same fields as above.
```

### For Supabase Edge Functions:
```
Each file in supabase/functions/ is an endpoint.
URL: /functions/v1/[function-name]
Method: POST (almost always)
Extract input/output types from TypeScript.
```

### For Next.js API routes:
```
Each file in pages/api/ or app/api/ is an endpoint.
URL: /api/[file-path]
Method: from handler switch or HTTP method exports.
```

Build this table:
```
BACKEND CONTRACT
────────────────────────────────────────────────────────────────────
Method  │ URL                          │ Auth │ Body DTO    │ Response
────────┼──────────────────────────────┼──────┼─────────────┼──────────
GET     │ /api/v1/users                │ JWT  │ —           │ User[]
POST    │ /api/v1/users                │ JWT  │ CreateUserDto│ User
GET     │ /api/v1/users/:id            │ JWT  │ —           │ User
PUT     │ /api/v1/users/:id            │ JWT  │ UpdateUserDto│ User
DELETE  │ /api/v1/users/:id            │ JWT  │ —           │ { success }
POST    │ /api/v1/auth/login           │ —    │ LoginDto    │ { token }
...
────────────────────────────────────────────────────────────────────
Total: [n] endpoints
```

---

## Phase 3 — Extract Client Contract

Scan every client (frontend, admin, mobile) and build what they THINK the API looks like.

### What to scan for:

**axios calls:**
```typescript
axios.get('/api/v1/users')           → GET /api/v1/users
axios.post('/api/v1/users', body)    → POST /api/v1/users, body shape from variable
axios.put(`/api/v1/users/${id}`)     → PUT /api/v1/users/:id
```

**fetch calls:**
```typescript
fetch('/api/v1/users', { method: 'POST', body: JSON.stringify(data) })
```

**Supabase client calls:**
```typescript
supabase.from('users').select()      → implicit GET (RLS-based)
supabase.functions.invoke('fn-name') → POST /functions/v1/fn-name
```

**React Query / TanStack Query:**
```typescript
useQuery({ queryKey: ['users'], queryFn: () => api.getUsers() })
→ follow the api.getUsers() function to find the actual HTTP call
```

**Service/API layer files** (most important — usually centralised):
```typescript
// src/services/api.ts or src/lib/api.ts
export const getUsers = () => api.get<User[]>('/api/v1/users')
export const createUser = (dto: CreateUserDto) => api.post<User>('/api/v1/users', dto)
```

Build same table per client:
```
FRONTEND CONTRACT (what frontend thinks the API looks like)
────────────────────────────────────────────────────────────────────
Method  │ URL                          │ Auth header │ Body shape  │ Expected response
...
```

---

## Phase 4 — Cross-Reference and Find Mismatches

Compare backend contract vs each client contract. Check every dimension:

### Check 1: Missing routes (404 waiting to happen)
```
Frontend calls:  POST /api/v1/auth/google-login
Backend has:     (nothing matching)
→ MISMATCH: Frontend calls endpoint that doesn't exist
```

### Check 2: Wrong HTTP method
```
Frontend calls:  POST /api/v1/users/:id  (should be PUT or PATCH)
Backend expects: PUT  /api/v1/users/:id
→ MISMATCH: Method mismatch — will get 404 or 405
```

### Check 3: URL parameter mismatch
```
Frontend calls:  /api/v1/user/:id   (singular 'user')
Backend route:   /api/v1/users/:id  (plural 'users')
→ MISMATCH: Typo in URL
```

### Check 4: Request body mismatch
```
Backend DTO:     CreateUserDto { email: string, password: string, role: string }
Frontend sends:  { email, password }   ← missing 'role'
→ MISMATCH: Frontend missing required field 'role'
```

### Check 5: Response shape mismatch
```
Backend returns: { data: { user: User }, message: string }
Frontend expects: response.data.id   ← wrong path (should be response.data.user.id)
→ MISMATCH: Frontend accessing wrong response path
```

### Check 6: Auth header mismatch
```
Backend:  @UseGuards(JwtAuthGuard)   ← expects Authorization: Bearer <token>
Frontend: axios.get(url)             ← no auth header being sent
→ MISMATCH: Will get 401 Unauthorized
```

### Check 7: Query parameter mismatch
```
Backend:  GET /api/v1/posts?page=1&limit=10&sortBy=createdAt
Frontend: GET /api/v1/posts?pageNumber=1&pageSize=10
→ MISMATCH: Different query param names
```

### Check 8: Base URL mismatch
```
Backend runs on:  http://localhost:3000
Frontend calls:   http://localhost:3001/api/v1/...   ← wrong port
→ MISMATCH: Wrong base URL in dev config
```

### Check 9: Version mismatch
```
Backend:   /api/v2/users  (upgraded to v2)
Frontend:  /api/v1/users  (still on v1)
→ MISMATCH: Client using deprecated version
```

### Check 10: Response envelope inconsistency
```
Backend endpoint A returns: { data: [...], total: n }
Backend endpoint B returns: [...] directly (no envelope)
Frontend expects envelope on B: response.data  ← undefined
→ INCONSISTENCY: Backend not using consistent response format
```

---

## Phase 5 — Generate Sync Report

```
╔══════════════════════════════════════════════════════════════════╗
║              API CONTRACT SYNC REPORT                            ║
╚══════════════════════════════════════════════════════════════════╝

Backend:  [path] — [n] endpoints
Frontend: [path] — [n] API calls
Admin:    [path] — [n] API calls
Mobile:   [path] — [n] API calls

SYNC SCORE: [X/100]

Summary:
  ✅ Perfectly synced:     [n] endpoints
  ❌ Mismatches:           [n] issues
  ⚠️  Warnings:            [n] issues

═══════════════════════════════════════════════════════════════════
 CRITICAL MISMATCHES (will cause runtime errors)
═══════════════════════════════════════════════════════════════════

[1] MISSING ENDPOINT
    Client:   POST /api/v1/auth/google-login  (frontend/src/services/auth.ts:34)
    Backend:  ❌ Not found
    Fix:      Add @Post('auth/google-login') to AuthController OR
              Change frontend to use existing /api/v1/auth/oauth

[2] WRONG HTTP METHOD
    Backend:  PATCH /api/v1/profile/:id  (src/profile/profile.controller.ts:45)
    Frontend: PUT   /api/v1/profile/:id  (frontend/src/services/profile.ts:12)
    Fix:      Change frontend to use PATCH, or change backend to accept PUT

[3] MISSING AUTH HEADER
    Backend:  GET /api/v1/orders  requires JWT  (orders.controller.ts:23)
    Mobile:   fetch('/api/v1/orders')  — no Authorization header
              (mobile/src/screens/OrdersScreen.tsx:67)
    Fix:      Add Authorization: Bearer ${token} to mobile fetch call

═══════════════════════════════════════════════════════════════════
 HIGH — Request/Response Shape Mismatches
═══════════════════════════════════════════════════════════════════

[4] MISSING REQUIRED FIELD IN REQUEST
    Backend DTO: CreatePostDto.categoryId (required)
    Frontend:    { title, body, userId }  — missing categoryId
                 (frontend/src/components/CreatePost.tsx:89)
    Fix:         Add categoryId to form and request body

[5] WRONG RESPONSE PATH
    Backend returns:  { data: { user: {...} } }
    Frontend reads:   response.data.email  (should be response.data.user.email)
                      (frontend/src/hooks/useProfile.ts:23)
    Fix:              Change to response.data.user.email

═══════════════════════════════════════════════════════════════════
 MEDIUM — Inconsistencies
═══════════════════════════════════════════════════════════════════

[6] QUERY PARAM NAME MISMATCH
    ...

═══════════════════════════════════════════════════════════════════
 BACKEND-ONLY ENDPOINTS (no client uses them — dead code?)
═══════════════════════════════════════════════════════════════════
  DELETE /api/v1/admin/purge-cache  — no client calls this
  GET    /api/v1/debug/health-verbose — no client calls this
  (These may be intentional — verify before deleting)

═══════════════════════════════════════════════════════════════════
 CLIENT CALLS NOT IN BACKEND (will 404 in production)
═══════════════════════════════════════════════════════════════════
  POST /api/v1/notifications/mark-all-read  (mobile — 3 files)
  GET  /api/v1/users/me/preferences         (frontend — 1 file)
```

---

## Phase 6 — Generate Fix Files

For each critical mismatch, generate the exact fix:

**Option A — Fix the backend** (add missing endpoint):
```typescript
// [exact file to edit]:[line to add after]
@Post('notifications/mark-all-read')
@UseGuards(JwtAuthGuard)
async markAllNotificationsRead(@CurrentUser() user: User) {
  return this.notificationsService.markAllRead(user.id);
}
```

**Option B — Fix the client** (correct the URL/method/body):
```typescript
// [exact file]:[exact line]
// BEFORE:
await api.put(`/api/v1/profile/${id}`, data)
// AFTER:
await api.patch(`/api/v1/profile/${id}`, data)
```

---

## Phase 7 — Phase Gate

Show total mismatch count and ask:

**[fix all] / [fix critical only] / [export report only] / [custom]**

- **[fix all]**: Apply all fixes automatically to both backend and client files
- **[fix critical only]**: Fix only the items that will cause 4xx/5xx errors
- **[export report only]**: Save report to `API_SYNC_REPORT.md` in project root
- **[custom]**: User picks which issues to fix

---

## Rules

- Always show the exact file path and line number for every mismatch
- Never guess — if you can't find the endpoint definition, say so
- If backend uses a response envelope (`{ data, message, statusCode }`), flag any client that doesn't unwrap it correctly
- If frontend uses an API service layer (centralized api.ts), fix it there — not in every component that calls it
- Treat Supabase direct client calls (`.from().select()`) as separate from REST API calls — don't mix them
