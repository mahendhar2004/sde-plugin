---
name: sde-architect
description: Phase 2 — System Architecture. Designs complete system architecture with component diagrams, data flow, auth flow, caching strategy, observability plan, and creates Architecture Decision Records.
---

# SDE Architect — Phase 2: System Architecture

## Pre-Flight

1. Read `.sde/context.json` — project type, stack, clarifications
2. Read `.sde/phases/0-idea.md` — problem, constraints
3. Read `.sde/phases/1-prd.md` — features, NFRs, scale requirements
4. Note project type: determines which services appear in architecture

---

## Architecture Design

### Architecture Pattern Decision

**Recommend: Modular Monolith** for solo developer.

Reasoning to include in the document:
- Microservices add operational complexity (service discovery, distributed tracing, network latency, multiple deployments) that negates productivity gains for a solo developer
- Modular monolith gives clean module boundaries (same discipline as microservices) without the infra overhead
- On AWS EC2 t2.micro free tier, a single well-structured NestJS app with modules is ideal
- Easy to extract to microservices later if traffic demands it
- NestJS's module system enforces the same separation as microservices at the code level

---

### Component Diagram (ASCII)

For web-only:
```
┌─────────────────────────────────────────────────────────────────┐
│                         CLIENT LAYER                            │
│  ┌─────────────────────────┐  ┌───────────────────────────────┐ │
│  │   React Frontend         │  │      Admin Panel (if any)    │ │
│  │   (Vite + Tailwind)      │  │      (React + Tailwind)      │ │
│  └────────────┬─────────────┘  └──────────────┬───────────────┘ │
└───────────────┼──────────────────────────────┼─────────────────┘
                │ HTTPS                         │ HTTPS
                ▼                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      GATEWAY LAYER (AWS)                        │
│         CloudFront CDN ──── S3 (Static Assets)                  │
│         Application Load Balancer / Nginx                       │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                     APPLICATION LAYER                           │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              NestJS Modular Monolith                     │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────┐  │   │
│  │  │   Auth   │ │  Users   │ │[Feature] │ │  Health   │  │   │
│  │  │  Module  │ │  Module  │ │  Module  │ │  Module   │  │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └───────────┘  │   │
│  │  ┌──────────────────────────────────────────────────┐   │   │
│  │  │           Common: Guards, Filters, Pipes         │   │   │
│  │  └──────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────┘   │
└──────────┬──────────────────────────────────┬───────────────────┘
           │                                  │
           ▼                                  ▼
┌──────────────────────┐          ┌───────────────────────────────┐
│    DATA LAYER        │          │       CACHE LAYER             │
│  PostgreSQL 16       │          │       Redis 7                 │
│  (AWS RDS free tier) │          │       (Docker)                │
│  - Users table       │          │  - Sessions                   │
│  - [entities]        │          │  - Frequent reads             │
│  - Migrations        │          │  - Rate limit counters        │
└──────────────────────┘          └───────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────────┐
│                    OBSERVABILITY LAYER                           │
│  Sentry (errors) ── Grafana Cloud (metrics+logs) ── CloudWatch  │
└──────────────────────────────────────────────────────────────────┘
```

Adjust diagram based on project type — add Mobile Client box for web+mobile.

---

### Service Responsibilities Table

| Service | Responsibility | Tech | Runs On |
|---------|---------------|------|---------|
| NestJS API | Business logic, data access, auth | NestJS + TypeORM | EC2 Docker |
| React Frontend | User interface, client routing | React + Vite | S3 + CloudFront |
| React Native (if mobile) | Mobile UI, push notifs, offline | Expo managed | User device |
| PostgreSQL | Persistent relational data | PostgreSQL 16 | AWS RDS |
| Redis | Caching, sessions, queues | Redis 7 | EC2 Docker |
| Nginx | Reverse proxy, SSL termination | Nginx Alpine | EC2 Docker |

---

### API Architecture

- Base URL: `/api/v1/`
- Auth: Bearer JWT in Authorization header
- Versioning: URI versioning (`/api/v1/`, `/api/v2/` when needed)
- Format: JSON request/response
- Pagination: Cursor-based for large datasets, offset for simple
- Error format: `{ statusCode, message, error, timestamp, path }`

---

### Data Flow Diagram

```
User Action
    │
    ▼
React Component
    │ API call (axios)
    ▼
axios interceptor (attach JWT)
    │
    ▼
NestJS Controller
    │
    ▼
JWT Auth Guard ──── FAIL → 401 Unauthorized
    │ PASS
    ▼
Validation Pipe (class-validator DTOs)
    │ FAIL → 400 Bad Request
    ▼
Service Layer (business logic)
    │
    ├──── Redis Cache? → Cache Hit → Return
    │
    ▼
Repository (TypeORM)
    │
    ▼
PostgreSQL Database
    │
    ▼
Response DTO (transformed via class-transformer)
    │
    ▼
Back to client
```

---

### Authentication Flow

```
LOGIN FLOW:
──────────────────────────────────────────────────────
Client          Backend              Database   Redis
  │                                                │
  ├─── POST /api/v1/auth/login ──────────────────►│
  │    { email, password }                        │
  │                ├── Find user by email ────────►│
  │                ├── bcrypt.compare(password)    │
  │                ├── Generate access_token (15m) │
  │                ├── Generate refresh_token (7d) │
  │                ├── Hash refresh_token          │
  │                ├── Store hashed refresh ──────►│
  │◄── { access_token, refresh_token } ───────────┤
  │                                                │

REFRESH FLOW:
──────────────────────────────────────────────────────
  ├─── POST /api/v1/auth/refresh ────────────────►│
  │    { refresh_token }                           │
  │                ├── Validate refresh JWT        │
  │                ├── Get userId from payload     │
  │                ├── Load stored hash ───────────►│
  │                ├── bcrypt.compare(token, hash) │
  │                ├── Issue NEW access_token      │
  │                ├── Issue NEW refresh_token     │
  │                ├── Invalidate old refresh ─────►│
  │◄── { access_token, refresh_token } ───────────┤
  │                                                │

LOGOUT FLOW:
──────────────────────────────────────────────────────
  ├─── POST /api/v1/auth/logout ─────────────────►│
  │    Authorization: Bearer [access_token]        │
  │                ├── Validate JWT                │
  │                ├── Delete refresh_token hash ──►│
  │◄── { message: "Logged out" } ─────────────────┤
```

---

### Caching Strategy

| Data Type | Cache Key Pattern | TTL | Invalidation Trigger |
|-----------|------------------|-----|---------------------|
| User profile | `user:[id]:profile` | 5 min | Profile update |
| [Feature] list | `[feature]:list:[filters-hash]` | 2 min | Any create/update/delete |
| Config/settings | `config:app` | 30 min | Config update |
| Rate limit counters | `ratelimit:[ip]:[endpoint]` | 1 min | Auto-expiry |
| Refresh token | `refresh:[userId]` | 7 days | Logout, rotation |

Cache implementation: `@nestjs/cache-manager` with Redis adapter.

---

### Rate Limiting Strategy

| Endpoint Type | Limit | Window | Implementation |
|---------------|-------|--------|----------------|
| POST /auth/login | 5 | per 15 min per IP | nestjs-throttler |
| POST /auth/register | 3 | per hour per IP | nestjs-throttler |
| POST /auth/refresh | 10 | per 15 min per IP | nestjs-throttler |
| GET /api/* (public) | 100 | per min per IP | nestjs-throttler |
| GET /api/* (authenticated) | 300 | per min per user | nestjs-throttler |
| POST/PUT/DELETE (authenticated) | 60 | per min per user | nestjs-throttler |

---

### Logging Strategy

- Format: Structured JSON (all environments)
- Library: NestJS built-in Logger + custom LoggingInterceptor
- Log levels: ERROR (production), WARN + ERROR (staging), all levels (dev)

What to log:
```
REQUEST LOG: { timestamp, requestId, method, path, userId, ip, userAgent, duration }
ERROR LOG:   { timestamp, requestId, error.message, error.stack, userId, path }
AUTH LOG:    { timestamp, event: "login|logout|failed_login", userId, ip }
DB SLOW:     { timestamp, query: "[sanitized]", duration, threshold: "100ms" }
```

What NOT to log:
- Passwords (never)
- JWT tokens (never)
- Credit card numbers (never)
- PII in debug level (mask email as u***@domain.com)

---

### Observability Plan

**Prometheus Metrics (via prom-client):**
- `http_requests_total` (counter: method, route, status_code)
- `http_request_duration_ms` (histogram: method, route)
- `active_connections` (gauge)
- `db_query_duration_ms` (histogram: operation)
- `cache_hits_total` / `cache_misses_total` (counter)

**Loki Logs:** Ship structured JSON logs via Grafana Cloud Agent

**Sentry Errors:**
- Backend: `@sentry/node` in NestJS exception filter
- Frontend: `@sentry/react` ErrorBoundary
- Source maps uploaded on every deployment

**Health Checks:**
- `GET /health` → `{ status: "ok", uptime: N }`
- `GET /health/db` → PostgreSQL ping
- `GET /health/redis` → Redis ping
- Used by Docker healthcheck, k3s probes, CD pipeline verification

---

### CI/CD Overview

```
Push to feature/* branch
    │
    ▼
GitHub Actions CI:
  ├── Backend: lint → typecheck → test (coverage) → build
  └── Frontend: lint → typecheck → test (coverage) → build
    │
    ▼ (PR to develop)
Code Review (self) → Merge
    │
    ▼ (PR to main)
CD Pipeline:
  ├── Build Docker images
  ├── Push to AWS ECR
  ├── SSH to EC2
  ├── docker-compose pull + up
  └── Health check verification
```

---

## Create Architecture Decision Records

### ADR-001: Architecture Pattern

Save to `.sde/adr/ADR-001-architecture-pattern.md`:
```markdown
# ADR-001: Modular Monolith Architecture

**Date:** [date]
**Status:** Accepted

## Context
Solo developer building a [project type] application. Need clean code boundaries without operational overhead.

## Decision
Use a NestJS Modular Monolith instead of microservices.

## Rationale
- Single deployment unit reduces ops complexity
- NestJS modules enforce separation of concerns
- AWS t2.micro free tier fits a single optimized process
- Can extract to microservices if needed (modules are already isolated)

## Consequences
- Positive: Simple deployment, single debugging context, shared DB transactions
- Negative: Cannot scale individual features independently (acceptable for current scale)
```

### ADR-002: Auth Strategy

Save to `.sde/adr/ADR-002-auth-strategy.md`:
```markdown
# ADR-002: JWT with Refresh Token Rotation

**Date:** [date]
**Status:** Accepted

## Context
Need stateless, scalable auth that works for both web and mobile clients.

## Decision
JWT access tokens (15 min) + refresh tokens (7 days) with rotation on use.

## Rationale
- Stateless: no session store needed for access token validation
- Short-lived access tokens limit breach window
- Refresh rotation means stolen refresh tokens are quickly invalidated
- Works identically for web and mobile

## Consequences
- Positive: Stateless, scalable, mobile-compatible
- Negative: Cannot revoke access tokens before expiry (acceptable for 15min window)
```

### ADR-003: Caching Strategy

Save to `.sde/adr/ADR-003-caching-strategy.md`:
```markdown
# ADR-003: Redis Caching via @nestjs/cache-manager

**Date:** [date]
**Status:** Accepted

## Context
Need to reduce database load for frequently accessed data.

## Decision
Use Redis via @nestjs/cache-manager with explicit cache keys and TTL per data type.

## Rationale
- Redis already in stack for rate limiting and sessions
- cache-manager provides decorators and programmatic API
- TTL per data type allows fine-grained control
- Explicit invalidation on mutations prevents stale data issues

## Consequences
- Positive: Reduced DB load, faster response times
- Negative: Cache invalidation complexity; must remember to invalidate on mutations
```

---

## Autonomous Actions

1. Save full architecture doc to `.sde/phases/2-architecture.md`
2. Create `.sde/adr/` with three ADR files above
3. Create Notion sub-page "Architecture — Phase 2" with all diagrams and decisions
4. ```bash
   git checkout develop
   git checkout -b feature/2-architecture
   git add .sde/
   git commit -m "docs: system architecture design — Phase 2"
   git push origin feature/2-architecture
   ```
5. Update `.sde/context.json`: `currentPhase: 2`, add 2 to `completedPhases`

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 2 COMPLETE — System Architecture       ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • Modular monolith architecture designed        ║
║  • Component + data flow diagrams created        ║
║  • Auth flow (JWT + refresh rotation)            ║
║  • Caching strategy (Redis, TTL per type)        ║
║  • 3 ADRs created                                ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • .sde/phases/2-architecture.md                 ║
║  • .sde/adr/ADR-001, ADR-002, ADR-003            ║
║  • Notion sub-page: "Architecture — Phase 2"     ║
║  • Git committed: feature/2-architecture         ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 3 — Tech Stack Decision             ║
╠══════════════════════════════════════════════════╣
║  [proceed] → start tech stack selection          ║
║  [refine]  → improve architecture                ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
