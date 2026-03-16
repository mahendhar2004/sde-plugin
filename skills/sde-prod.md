---
name: sde-prod
description: Phase 12 — Production Readiness. Runs a comprehensive production checklist, fixes all issues automatically, generates a rollback runbook, and creates the project README.
---

# SDE Prod — Phase 12: Production Readiness

## Pre-Flight

1. Read ALL `.sde/phases/` documents — full project context
2. Read `.sde/context.json` — project details
3. This phase verifies EVERYTHING is production-ready

---

## Production Readiness Checklist

Work through each item. Fix issues found autonomously. Mark each as ✅ or ❌.

---

### Code Quality

**[ ] TypeScript strict mode — no errors**
```bash
cd backend && npx tsc --noEmit
cd frontend && npx tsc --noEmit
```
Fix any type errors found. Common fixes:
- Add missing return types: `function foo(): string {`
- Replace `any` with proper types or `unknown`
- Fix null-safety issues with optional chaining `?.` and nullish coalescing `??`

**[ ] No console.log in production code**
```bash
grep -r "console\.log\|console\.debug" src/ --include="*.ts" --include="*.tsx" | grep -v "spec\|test"
```
Replace all occurrences with NestJS Logger or remove:
```typescript
// BEFORE: console.log('user created', user);
// AFTER:
private readonly logger = new Logger(UsersService.name);
this.logger.log(`User created: ${user.id}`);
```

**[ ] All TODO comments resolved**
```bash
grep -r "TODO\|FIXME\|HACK\|XXX" src/ --include="*.ts" --include="*.tsx"
```
For each TODO: either implement it, create a Notion task for it, or remove the comment if no longer relevant.

**[ ] React Error Boundaries in frontend**
Verify Error Boundary wraps the app in main.tsx (Sentry's is fine):
```typescript
<Sentry.ErrorBoundary fallback={<ErrorFallback />} showDialog>
  <App />
</Sentry.ErrorBoundary>
```
Create a proper ErrorFallback component:
```typescript
// src/components/ErrorFallback.tsx
interface Props { error?: Error; resetErrorBoundary?: () => void; }
export function ErrorFallback({ error, resetErrorBoundary }: Props) {
  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="text-center">
        <h1 className="text-2xl font-bold text-gray-900">Something went wrong</h1>
        <p className="mt-2 text-gray-600">We've been notified. Please try again.</p>
        <button onClick={resetErrorBoundary} className="mt-4 btn btn-primary">
          Try again
        </button>
      </div>
    </div>
  );
}
```

---

### Security

**[ ] All env vars in .env.example**
```bash
# Backend: check if all process.env references have corresponding .env.example entries
grep -h "process\.env\." backend/src/**/*.ts | grep -oP "process\.env\.\K[A-Z_]+" | sort -u
```
Compare against backend/.env.example keys. Add any missing ones with placeholder values.

**[ ] No secrets in code or git history**
```bash
# Check for common secret patterns
grep -r "password\|secret\|token\|key\|api_key" src/ --include="*.ts" --include="*.tsx" | grep -v "process.env\|configService\|spec\|test\|example\|@Column\|@IsString\|dto\|type\|interface"
```
Remove any hardcoded secrets found.

**[ ] npm audit — no critical vulnerabilities**
```bash
cd backend && npm audit --audit-level=critical
cd frontend && npm audit --audit-level=critical
```
Fix any CRITICAL issues. Document HIGH issues with remediation plan.

**[ ] Rate limiting active**
Verify throttler is configured in app.module.ts and applied to auth endpoints.

---

### Infrastructure

**[ ] Health check endpoints working**
Start the app locally and verify:
```bash
curl http://localhost:3000/health
curl http://localhost:3000/health/db
# Expected: { "status": "ok" }
```
If health endpoint fails, debug TypeORM or Redis connection.

**[ ] Graceful shutdown handling**
Verify in main.ts:
```typescript
app.enableShutdownHooks();
```

Add graceful shutdown to main.ts:
```typescript
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully...');
  await app.close();
  process.exit(0);
});
```

**[ ] Database connection pool configured**
Verify in database.config.ts: `extra: { max: 10, min: 2 }`

**[ ] Redis connection error handling**
In app.module.ts CacheModule config, add error handling:
```typescript
// The cache module handles Redis reconnection automatically
// But log Redis errors:
onClientReady: (client) => {
  client.on('error', (err) => logger.error('Redis error', err));
},
```

**[ ] Docker images build successfully**
```bash
docker build -t test-backend -f backend/Dockerfile backend/
docker build -t test-frontend -f frontend/Dockerfile frontend/
echo "Build status: $?"
```

**[ ] CI pipeline passes**
Push a test commit and verify GitHub Actions CI passes all jobs.

---

### Observability

**[ ] Structured JSON logging in production**
Verify `nestjs-pino` is configured:
```typescript
// In app.module.ts:
LoggerModule.forRootAsync({
  useFactory: (configService: ConfigService) => ({
    pinoHttp: {
      level: configService.get('NODE_ENV') === 'production' ? 'info' : 'debug',
      transport: configService.get('NODE_ENV') !== 'production'
        ? { target: 'pino-pretty', options: { colorize: true } }
        : undefined,
      formatters: {
        level: (label) => ({ level: label }),
      },
      redact: ['req.headers.authorization', 'req.body.password'],
    },
  }),
  inject: [ConfigService],
}),
```

**[ ] Sentry configured and test error verified**
```typescript
// In a test endpoint (REMOVE AFTER TEST):
@Get('test-sentry')
@Public()
testSentry() {
  throw new Error('Test Sentry error — remove this endpoint');
}
```
Verify error appears in Sentry dashboard. Then remove test endpoint.

**[ ] Custom Prometheus metrics**
Add to a metrics module:
```typescript
// src/metrics/metrics.service.ts
import { Injectable } from '@nestjs/common';
import { Counter, Histogram, Gauge, register } from 'prom-client';

@Injectable()
export class MetricsService {
  readonly httpRequestsTotal = new Counter({
    name: 'http_requests_total',
    help: 'Total HTTP requests',
    labelNames: ['method', 'route', 'status_code'],
  });

  readonly httpDuration = new Histogram({
    name: 'http_request_duration_ms',
    help: 'HTTP request duration in ms',
    labelNames: ['method', 'route'],
    buckets: [5, 10, 25, 50, 100, 200, 500, 1000],
  });

  readonly activeConnections = new Gauge({
    name: 'active_connections',
    help: 'Active database connections',
  });
}
```

Add metrics endpoint:
```typescript
@Get('metrics')
@Public()
async getMetrics(@Res() res: Response) {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
}
```

---

### Data

**[ ] Database migrations work on clean DB**
```bash
cd backend
# Create a fresh test DB
createdb testdb_migration
DATABASE_URL=postgresql://localhost/testdb_migration npm run migration:run
# If it runs without error, migrations are clean
dropdb testdb_migration
```

**[ ] Seed data script**
Create `backend/src/database/seeds/seed.ts`:
```typescript
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../../app.module';
import { UsersService } from '../../modules/users/users.service';

async function seed() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const usersService = app.get(UsersService);

  // Create admin user if not exists
  const adminEmail = process.env.SEED_ADMIN_EMAIL || 'admin@example.com';
  const existing = await usersService.findByEmail(adminEmail);
  if (!existing) {
    await usersService.create({
      firstName: 'Admin',
      lastName: 'User',
      email: adminEmail,
      password: process.env.SEED_ADMIN_PASSWORD || 'ChangeMe123!',
      role: 'admin',
    });
    console.log(`Admin user created: ${adminEmail}`);
  } else {
    console.log('Admin user already exists');
  }

  await app.close();
}

seed().catch(console.error);
```

---

### Documentation

**[ ] README.md comprehensive**
Generate complete project README (see below).

**[ ] API docs accessible**
Swagger UI accessible at `/api/docs` in non-production environments.
For production: export OpenAPI spec to Notion.

---

## Generate Project README.md

Write to project root `README.md`:

```markdown
# [Project Name]

> [Value proposition sentence from Phase 0]

## Overview

[2-3 paragraph description of what the product is and does]

## Features

### MVP
- [Feature 1]
- [Feature 2]

### Coming in V2
- [Feature 1]

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | NestJS + TypeORM + PostgreSQL |
| Frontend | React 18 + Vite + Tailwind CSS v3 |
| Mobile | React Native + Expo (if applicable) |
| Auth | JWT (access 15min + refresh 7d) |
| Cache | Redis 7 |
| CI/CD | GitHub Actions |
| Hosting | AWS EC2 t2.micro (free tier) |

## Local Development

### Prerequisites
- Node.js 20+
- Docker and Docker Compose
- Git

### Setup
```bash
git clone [repo-url]
cd [project-slug]

# Copy environment files
cp .env.example .env
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env

# Fill in your .env values (see Environment Variables section)

# Start all services
docker-compose up -d

# Install backend dependencies and run migrations
cd backend && npm install && npm run migration:run

# Install frontend dependencies
cd ../frontend && npm install

# Start development servers
# Terminal 1: Backend
cd backend && npm run start:dev

# Terminal 2: Frontend
cd frontend && npm run dev
```

Open http://localhost:5173

### Environment Variables

| Variable | Required | Description | How to Get |
|----------|----------|-------------|------------|
| DATABASE_URL | Yes | PostgreSQL connection string | Local Docker |
| REDIS_HOST | Yes | Redis host | Local Docker: localhost |
| JWT_SECRET | Yes | Min 32-char secret | Generate: openssl rand -hex 32 |
| JWT_REFRESH_SECRET | Yes | Min 32-char secret | Generate: openssl rand -hex 32 |
| SENTRY_DSN | No | Error tracking | sentry.io |
| AWS_* | No | File uploads/CDN | AWS Console |

## API Documentation

- **Swagger UI**: http://localhost:3000/api/docs (development only)
- **OpenAPI Spec**: [.sde/schemas/openapi.yaml](.sde/schemas/openapi.yaml)

## Testing

```bash
# Backend tests
cd backend && npm test
cd backend && npm test -- --coverage

# Frontend tests
cd frontend && npm test
cd frontend && npm test -- --coverage
```

Coverage requirement: ≥ 80% on all metrics.

## Deployment

Deployment is fully automated via GitHub Actions:

- **Push to `feature/*` or `develop`** → CI runs (tests + build)
- **Push to `main`** → CI + CD (builds Docker images, pushes to ECR, deploys to EC2)

### Required GitHub Secrets

Configure these in your repository settings → Secrets and variables → Actions:

```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
ECR_REGISTRY
EC2_HOST
EC2_USER
EC2_SSH_KEY
VITE_API_URL
```

## Architecture

See [System Architecture](.sde/phases/2-architecture.md) for full architectural diagrams and decision records.

### Key Design Decisions
- **Modular Monolith**: NestJS modules for clean separation without microservices overhead
- **JWT Auth**: Short-lived access tokens (15min) + refresh token rotation (7 days)
- **Redis Caching**: Cache-aside pattern with explicit TTL and invalidation

## Branch Strategy

```
main         → production (protected, CI/CD deploys here)
develop      → integration branch
feature/N-*  → phase branches (e.g., feature/4-auth-module)
hotfix/*     → urgent production fixes
```

## Project Structure

```
.
├── backend/           # NestJS API
├── frontend/          # React + Vite SPA
├── mobile/            # React Native + Expo (if applicable)
├── .github/workflows/ # CI/CD pipelines
├── .sde/              # SDE Plugin project state
│   ├── context.json
│   ├── phases/        # Phase outputs
│   ├── adr/           # Architecture Decision Records
│   └── schemas/       # database.sql, openapi.yaml
└── docker-compose.yml
```
```

---

## Generate Rollback Runbook

Save to `.sde/phases/12-rollback-runbook.md`:

```markdown
# Rollback Runbook

**Objective**: Roll back a bad production deployment in < 5 minutes.

## Quick Rollback (Docker Compose on EC2)

### Step 1: SSH to EC2 (30 seconds)
```bash
ssh -i ~/.ssh/ec2-key.pem ubuntu@[EC2_HOST]
cd /opt/app
```

### Step 2: Identify Previous Working Image Tag (30 seconds)
```bash
# Check deploy history
git log --oneline -10  # Find previous commit SHA
# Previous tag = first 7 chars of previous SHA
```

### Step 3: Rollback (2 minutes)
```bash
export ECR_REGISTRY=[your-ecr-registry]
export IMAGE_TAG=[previous-7-char-sha]  # e.g., abc1234

# Update compose to use previous images
sed -i "s|backend:latest|backend:$IMAGE_TAG|g" docker-compose.prod.yml
sed -i "s|frontend:latest|frontend:$IMAGE_TAG|g" docker-compose.prod.yml

docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d
```

### Step 4: Verify (1 minute)
```bash
sleep 15
curl -f http://localhost:3000/health
echo "Rollback successful"
```

**Total estimated time: ~4 minutes**

## Database Migration Rollback

If a bad migration was deployed:
```bash
cd /opt/app/backend
npm run migration:revert
# Verify application still works after revert
curl http://localhost:3000/health/db
```

## Emergency Contacts
- Monitor Sentry for error spike
- Check Grafana dashboard for latency/error rate anomalies
- Trigger rollback if error rate > 5% or health check fails
```

---

## Autonomous Actions

1. Fix ALL items in checklist
2. Generate project README.md
3. Generate rollback runbook
4. Save production readiness report to `.sde/phases/12-prod-readiness.md`
5. ```bash
   git checkout develop
   git checkout -b feature/12-prod-readiness
   git add .
   git commit -m "chore: production readiness — README, rollback runbook, final fixes — Phase 12"
   git push origin feature/12-prod-readiness
   ```
6. Update context.json: `currentPhase: 12`, add 12 to `completedPhases`

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 12 COMPLETE — Production Ready!        ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • All checklist items resolved                  ║
║  • README.md comprehensive                       ║
║  • Rollback runbook created                      ║
║  • All TypeScript errors resolved                ║
║  • Sentry + Grafana configured                   ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • README.md                                     ║
║  • .sde/phases/12-prod-readiness.md              ║
║  • .sde/phases/12-rollback-runbook.md            ║
║  • Git committed: feature/12-prod-readiness      ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 13 — Iterative Improvement          ║
╠══════════════════════════════════════════════════╣
║  [proceed] → run continuous improvement          ║
║  [refine]  → revisit prod readiness              ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
