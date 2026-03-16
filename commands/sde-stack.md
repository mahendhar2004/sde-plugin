---
description: Phase 3 — Tech Stack Decision. Finalizes tech stack based on PRD requirements, generates complete package lists with versions, and creates ADRs for any deviations from defaults.
---

# SDE Stack — Phase 3: Tech Stack Decision

## Pre-Flight

1. Read `.sde/context.json` — project type, clarifications (realtime, payments, fileUploads, etc.)
2. Read `.sde/phases/2-architecture.md` — architecture decisions
3. Read `.sde/phases/1-prd.md` — features that drive stack decisions

---

## Deviation Analysis

Check the clarifications from context.json and PRD features to determine if any deviations from the default stack are needed:

| Trigger | Deviation | Packages to Add |
|---------|-----------|----------------|
| `clarifications.realtime: true` OR real-time features in PRD | Add Socket.io | `@nestjs/websockets @nestjs/platform-socket.io socket.io socket.io-client` |
| `clarifications.payments: true` OR payments mentioned in PRD | Add Stripe | `stripe @stripe/stripe-js` |
| Email sending needed (auth reset, notifications) | Add Nodemailer + Resend | `nodemailer @nestjs-modules/mailer resend` |
| `clarifications.fileUploads: true` (already default YES) | Confirm S3 setup | `@aws-sdk/client-s3 @aws-sdk/s3-request-presigner multer @nestjs/platform-express` |
| Mobile in project type | Add Expo packages | `expo-router @react-navigation/native expo-secure-store expo-notifications` |
| Admin in project type | Confirm admin stack (React, same as frontend) | Recharts for charts: `recharts` |
| Background jobs needed (email queue, async processing) | Add Bull + Redis queue | `@nestjs/bull bull ioredis` |
| Social login mentioned | Add Passport strategies | `passport-google-oauth20 @types/passport-google-oauth20` |

For each deviation, create an ADR.

---

## Final Stack Table

Output the complete finalized stack:

### Backend Stack

| Layer | Technology | Version | Reasoning |
|-------|-----------|---------|-----------|
| Framework | NestJS | 10.x | Opinionated, modular, TypeScript-first |
| Language | TypeScript | 5.x | Type safety, better DX |
| ORM | TypeORM | 0.3.x | Works with NestJS, supports migrations |
| Database driver | pg | 8.x | PostgreSQL for Node.js |
| Auth | @nestjs/passport + passport-jwt | latest | Standard, extensible |
| Auth tokens | jsonwebtoken | 9.x | JWT generation/validation |
| Password hashing | bcrypt | 5.x | Industry standard, 12 rounds |
| Validation | class-validator + class-transformer | 0.14.x | DTO validation with decorators |
| Config | @nestjs/config | 3.x | Environment variable management |
| Rate limiting | @nestjs/throttler | 5.x | Request throttling per endpoint |
| Security headers | helmet | 7.x | OWASP security headers |
| HTTP compression | compression | 1.x | Gzip response compression |
| Caching | @nestjs/cache-manager + cache-manager-redis-yet | latest | Redis caching |
| Redis client | ioredis | 5.x | Redis connection |
| Metrics | prom-client | 15.x | Prometheus metrics |
| Logging | nestjs-pino | 4.x | Structured JSON logging |
| Error tracking | @sentry/node | 8.x | Error monitoring |
| Health checks | @nestjs/terminus | 10.x | Health endpoints |
| API docs | @nestjs/swagger | 7.x | OpenAPI auto-generation |
| Testing | jest + supertest + @nestjs/testing | latest | Unit + integration |

### Frontend Stack

| Layer | Technology | Version | Reasoning |
|-------|-----------|---------|-----------|
| Framework | React | 18.x | Mature ecosystem, concurrent features |
| Language | TypeScript | 5.x | Type safety |
| Build tool | Vite | 5.x | Fast HMR, optimized builds |
| Styling | Tailwind CSS | 3.x | Utility-first, design system ready |
| HTTP client | axios | 1.x | Interceptors for JWT refresh |
| Data fetching | @tanstack/react-query | 5.x | Server state management |
| State management | zustand | 4.x | Simple, TypeScript-friendly |
| Forms | react-hook-form + zod | latest | Performant, typesafe validation |
| Routing | react-router-dom | 6.x | Standard SPA routing |
| Error tracking | @sentry/react | 8.x | Frontend error monitoring |
| Testing | vitest + @testing-library/react | latest | Fast, Vite-native test runner |

### Mobile Stack (if applicable)

| Layer | Technology | Version | Reasoning |
|-------|-----------|---------|-----------|
| Framework | React Native + Expo | SDK 51.x | Managed workflow, easy deploys |
| Navigation | expo-router | 3.x | File-based routing |
| HTTP client | axios | 1.x | Same as frontend |
| Data fetching | @tanstack/react-query | 5.x | Shared patterns with frontend |
| State | zustand | 4.x | Lightweight, TypeScript |
| Secure storage | expo-secure-store | 13.x | Store tokens securely |
| Notifications | expo-notifications | 0.28.x | Push notifications |
| Testing | jest + @testing-library/react-native | latest | Unit + component tests |

### Infrastructure Stack

| Layer | Technology | Version | Notes |
|-------|-----------|---------|-------|
| Containerization | Docker + Docker Compose | 26.x / v2 | Dev and prod |
| CI/CD | GitHub Actions | — | Free for public repos |
| Database hosting | AWS RDS PostgreSQL | 16 | Free tier: db.t3.micro |
| App hosting | AWS EC2 | t2.micro | Free tier: 750 hrs/month |
| Storage | AWS S3 | — | Free tier: 5GB |
| CDN | AWS CloudFront | — | Free tier: 1TB/month |
| Image registry | AWS ECR | — | Free tier: 500MB/month |
| Monitoring | Grafana Cloud | Free | 10k metrics, 50GB logs |
| Error tracking | Sentry | Free | 5k errors/month |

---

## Complete Package Lists

### backend/package.json dependencies
```json
{
  "dependencies": {
    "@nestjs/common": "^10.3.0",
    "@nestjs/core": "^10.3.0",
    "@nestjs/platform-express": "^10.3.0",
    "@nestjs/typeorm": "^10.0.2",
    "@nestjs/config": "^3.2.0",
    "@nestjs/passport": "^10.0.3",
    "@nestjs/jwt": "^10.2.0",
    "@nestjs/throttler": "^5.1.2",
    "@nestjs/cache-manager": "^2.2.2",
    "@nestjs/terminus": "^10.2.3",
    "@nestjs/swagger": "^7.3.0",
    "@nestjs/bull": "^10.1.1",
    "typeorm": "^0.3.20",
    "pg": "^8.11.5",
    "passport": "^0.7.0",
    "passport-jwt": "^4.0.1",
    "passport-local": "^1.0.0",
    "jsonwebtoken": "^9.0.2",
    "bcrypt": "^5.1.1",
    "class-validator": "^0.14.1",
    "class-transformer": "^0.5.1",
    "helmet": "^7.1.0",
    "compression": "^1.7.4",
    "ioredis": "^5.3.2",
    "cache-manager-redis-yet": "^5.1.3",
    "cache-manager": "^5.4.0",
    "prom-client": "^15.1.2",
    "nestjs-pino": "^4.1.0",
    "pino-http": "^10.1.0",
    "@sentry/node": "^8.0.0",
    "reflect-metadata": "^0.2.0",
    "rxjs": "^7.8.1",
    "dumb-init": "^1.2.5"
  },
  "devDependencies": {
    "@nestjs/cli": "^10.3.2",
    "@nestjs/testing": "^10.3.0",
    "@types/bcrypt": "^5.0.2",
    "@types/compression": "^1.7.5",
    "@types/express": "^4.17.21",
    "@types/jest": "^29.5.12",
    "@types/node": "^20.12.0",
    "@types/passport-jwt": "^4.0.1",
    "@types/supertest": "^6.0.2",
    "jest": "^29.7.0",
    "supertest": "^7.0.0",
    "ts-jest": "^29.1.2",
    "ts-node": "^10.9.2",
    "typescript": "^5.4.5"
  }
}
```

### frontend/package.json dependencies
```json
{
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-router-dom": "^6.23.0",
    "@tanstack/react-query": "^5.36.1",
    "axios": "^1.7.2",
    "zustand": "^4.5.2",
    "react-hook-form": "^7.51.4",
    "zod": "^3.23.6",
    "@hookform/resolvers": "^3.4.2",
    "@sentry/react": "^8.0.0",
    "clsx": "^2.1.1",
    "tailwind-merge": "^2.3.0"
  },
  "devDependencies": {
    "@types/react": "^18.3.1",
    "@types/react-dom": "^18.3.0",
    "@vitejs/plugin-react": "^4.3.0",
    "autoprefixer": "^10.4.19",
    "postcss": "^8.4.38",
    "tailwindcss": "^3.4.3",
    "typescript": "^5.4.5",
    "vite": "^5.2.11",
    "@testing-library/react": "^16.0.0",
    "@testing-library/jest-dom": "^6.4.5",
    "@testing-library/user-event": "^14.5.2",
    "vitest": "^1.6.0",
    "@vitest/coverage-v8": "^1.6.0",
    "jsdom": "^24.0.0"
  }
}
```

### mobile/package.json (if applicable)
```json
{
  "dependencies": {
    "expo": "~51.0.0",
    "expo-router": "~3.5.0",
    "expo-status-bar": "~1.12.1",
    "expo-secure-store": "~13.0.2",
    "expo-notifications": "~0.28.0",
    "react": "18.2.0",
    "react-native": "0.74.1",
    "axios": "^1.7.2",
    "@tanstack/react-query": "^5.36.1",
    "zustand": "^4.5.2",
    "@sentry/react-native": "^5.22.0"
  },
  "devDependencies": {
    "@babel/core": "^7.24.5",
    "@types/react": "~18.2.79",
    "typescript": "^5.4.5",
    "jest": "^29.7.0",
    "@testing-library/react-native": "^12.5.0",
    "detox": "^20.18.0"
  }
}
```

---

## Deviation ADRs

For each deviation detected, create an ADR in `.sde/adr/`:

**Example — ADR-004-realtime.md (if realtime detected):**
```markdown
# ADR-004: Socket.io for Real-Time Features

**Date:** [date]
**Status:** Accepted

## Context
PRD requires real-time updates for [feature].

## Decision
Add Socket.io via @nestjs/websockets gateway alongside the REST API.

## Rationale
- Socket.io is the most mature real-time library in the Node ecosystem
- NestJS has first-class WebSocket gateway support
- Fallback to long-polling handled automatically
- Client libraries exist for React and React Native

## Consequences
- Positive: Real-time capability with minimal code
- Negative: Additional connection overhead; handle disconnect/reconnect gracefully
```

---

## Autonomous Actions

1. Save to `.sde/phases/3-stack.md`
2. Save any deviation ADRs to `.sde/adr/ADR-00N-*.md`
3. Update `.sde/context.json` stack object with deviations list:
   ```json
   "stack": {
     "deviations": ["realtime:socket.io", "payments:stripe"]
   }
   ```
4. ```bash
   curl -s -X POST ... # Sync to Notion sub-page "Tech Stack — Phase 3"
   ```
5. ```bash
   git checkout develop
   git checkout -b feature/3-stack
   git add .sde/
   git commit -m "docs: tech stack decisions — Phase 3"
   git push origin feature/3-stack
   ```
6. Update context.json: `currentPhase: 3`, add 3 to `completedPhases`

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 3 COMPLETE — Tech Stack                ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • Full stack table finalized                    ║
║  • [N] deviations from default (with ADRs)       ║
║  • Complete package.json lists generated         ║
║  • Infrastructure stack confirmed                ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • .sde/phases/3-stack.md                        ║
║  • Notion sub-page: "Tech Stack — Phase 3"       ║
║  • Git committed: feature/3-stack                ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 4 — Data Model Design               ║
╠══════════════════════════════════════════════════╣
║  [proceed] → start data model design             ║
║  [refine]  → revise stack decisions              ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
