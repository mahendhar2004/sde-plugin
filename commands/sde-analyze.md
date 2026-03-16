---
description: Existing Codebase Analysis — detects tech stack, maps architecture, identifies all issues (Critical to Low), and generates a phased improvement plan. Use this when joining an existing project.
argument-hint: "[optional: focus area]"
---

# SDE Analyze — Existing Codebase Analysis

Run this when you have an existing codebase you want to improve. It will fully understand what you have, find all problems, and create a roadmap.

---

## Step 1: Auto-Detect Tech Stack

Read existing files to determine what's being used:

### Detect Backend
```bash
cat backend/package.json 2>/dev/null || cat package.json 2>/dev/null | head -100
```

Parse dependencies for:
- **Framework**: express/koa/fastify/nestjs/hapi
- **ORM**: prisma/typeorm/sequelize/mongoose/raw
- **Database**: pg/mysql2/mongodb/sqlite3
- **Auth**: passport/jwt/session/firebase-admin
- **Validation**: joi/zod/class-validator/yup
- **Testing**: jest/mocha/vitest/tap
- **Language**: TypeScript (.tsconfig.json exists?) or JavaScript

### Detect Frontend
```bash
cat frontend/package.json 2>/dev/null || find . -name "package.json" -not -path "*/node_modules/*"
```

Parse for:
- **Framework**: react/vue/angular/svelte/nextjs/nuxt
- **Build**: vite/webpack/parcel/create-react-app
- **Styling**: tailwind/scss/styled-components/emotion/css-modules
- **State**: redux/zustand/jotai/context-only/mobx
- **Router**: react-router/tanstack-router/nextjs/vue-router

### Detect Mobile
```bash
ls mobile/ 2>/dev/null || ls app/ 2>/dev/null
cat mobile/package.json 2>/dev/null
```

### Detect CI/CD
```bash
ls .github/workflows/ 2>/dev/null
ls .gitlab-ci.yml 2>/dev/null
ls Jenkinsfile 2>/dev/null
```

### Detect Infrastructure
```bash
ls docker-compose*.yml 2>/dev/null
ls Dockerfile 2>/dev/null
ls k8s/ kubernetes/ 2>/dev/null
ls terraform/ 2>/dev/null
```

---

## Step 2: Map Directory Structure

```bash
find . -type f -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/dist/*" -not -path "*/coverage/*" | head -200
```

Identify:
- Where routes/controllers are defined
- Where business logic lives
- Where data access happens
- Where types/interfaces are defined
- Where tests are (or aren't)
- Config file locations

---

## Step 3: Architecture Assessment

Determine current architecture pattern:
- **Clean Architecture** (controllers → services → repositories): organized layers
- **MVC**: models, views, controllers separated
- **Spaghetti**: logic mixed everywhere, no clear layers
- **Fat Controllers**: business logic in route handlers
- **Anemic Services**: DTOs passed everywhere, logic in controllers
- **Monolith**: everything in one app
- **Microservices**: multiple services
- **BFF**: backend-for-frontend pattern

Map deviations from Clean Architecture:
- "Found DB queries in [controller file]" → violation
- "Business logic in [route file]" → violation
- "API calls in [component file]" → frontend violation

---

## Step 4: Comprehensive Issue Analysis

### A. Critical Issues 🔴

**Security vulnerabilities:**
```bash
# Check for common critical issues:

# SQL injection risks
grep -r "query\|execute\|raw" backend/src/ --include="*.ts" --include="*.js" | grep "\$\{" | grep -v "spec\|test"

# Hardcoded secrets
grep -r "password\|secret\|api_key\|token" . --include="*.ts" --include="*.js" --include="*.env" | grep -v "process.env\|example\|spec\|test\|type\|interface" | grep -E "=\s*['\"][^'\"]{8,}"

# No auth on routes
grep -rA10 "@Controller\|router\." . --include="*.ts" --include="*.js" | grep -v "guard\|middleware\|auth\|@Public"

# Missing HTTPS enforcement
grep -r "http://" . --include="*.ts" --include="*.js" | grep -v "localhost\|test\|spec\|comment"
```

**Broken authentication:**
- Check if JWT is validated properly
- Check if refresh tokens exist
- Check if passwords are hashed (bcrypt/argon2)

**Direct SQL string concatenation:**
- Any parameterized queries? Or raw strings with user input?

### B. High Issues 🟠

**Missing tests:**
```bash
# Find source files without corresponding test files
find backend/src -name "*.service.ts" | while read f; do
  test_file="${f/.service.ts/.service.spec.ts}"
  [ ! -f "$test_file" ] && echo "MISSING TEST: $f"
done

find frontend/src -name "*.tsx" | while read f; do
  test_file="${f/.tsx/.test.tsx}"
  [ ! -f "$test_file" ] && echo "MISSING TEST: $f"
done
```

**N+1 query patterns:**
```bash
grep -rn "for\|forEach" backend/src/ --include="*.ts" -A5 | grep "findOne\|findBy\|find("
```

**Missing error handling:**
```bash
# Service methods without try/catch
grep -c "try {" backend/src/**/*.service.ts
# Compare to total async methods
grep -c "async " backend/src/**/*.service.ts
```

**No request logging:**
- Check if LoggingInterceptor or morgan/pino-http is configured

**Unhandled promise rejections:**
```bash
grep -r "\.catch\|try {" backend/src/ --include="*.ts" | wc -l
# Should be significant — low count means unhandled promises
```

### C. Medium Issues 🟡

**Code duplication:**
```bash
npx jscpd . --ignore "node_modules,dist,coverage" --min-lines 10 2>/dev/null | head -40
```

**Outdated dependencies:**
```bash
cd backend && npx npm-check-updates --packageFile package.json 2>/dev/null | head -30
```

**TypeScript `any` usage:**
```bash
grep -rn ": any\|as any\|<any>" src/ --include="*.ts" --include="*.tsx" | grep -v "spec\|test\|\.d\.ts"
```

**Long functions:**
```bash
# Rough heuristic for large functions
grep -n "async\|function\|\) =>" backend/src/ -r --include="*.ts" | head -50
```

**Missing input validation:**
```bash
# DTOs without class-validator
find . -name "*.dto.ts" | xargs grep -L "@IsString\|@IsEmail\|@IsNumber\|@IsEnum" 2>/dev/null
```

### D. Low Issues 🔵

**Console.log statements:**
```bash
grep -rn "console\.log\|console\.debug" src/ --include="*.ts" --include="*.tsx" | grep -v "spec\|test"
```

**Unused imports:**
```bash
# TypeScript compiler will catch these with noUnusedLocals
npx tsc --noEmit --noUnusedLocals 2>&1 | grep "declared but"
```

**Missing JSDoc on public APIs:**
```bash
grep -B1 "export.*function\|export.*class" src/ --include="*.ts" -r | grep -v "/\*\*"
```

---

## Step 5: Generate Improvement Plan

Based on findings, create a 5-phase improvement plan:

### Phase A: Critical Security Fixes (Do Today)
- [ ] Fix all SQL injection risks
- [ ] Remove hardcoded secrets
- [ ] Add missing auth middleware
- [ ] Hash any plaintext passwords
- Estimated time: [N hours]

### Phase B: Test Coverage (This Week)
- [ ] Write tests for all services
- [ ] Write integration tests for all API endpoints
- [ ] Write component tests for React components
- Target: ≥ 80% coverage
- Estimated time: [N days]

### Phase C: Architecture Improvements (This Sprint)
- [ ] Move DB calls from controllers to services
- [ ] Create repository layer if missing
- [ ] Add proper DTOs and validation
- [ ] Add error handling to all async operations
- Estimated time: [N days]

### Phase D: Performance (Next Sprint)
- [ ] Fix N+1 queries
- [ ] Add caching layer (Redis)
- [ ] Add database indexes
- [ ] Add pagination to list endpoints
- Estimated time: [N days]

### Phase E: DevOps Setup (This Month)
- [ ] Add Dockerfiles
- [ ] Set up GitHub Actions CI
- [ ] Add monitoring (Grafana + Sentry)
- [ ] Document deployment process
- Estimated time: [N days]

---

## Step 6: Initialize .sde/ for Existing Project

Create `.sde/context.json`:
```json
{
  "name": "[detected project name]",
  "slug": "[slug]",
  "type": "existing",
  "currentPhase": 0,
  "completedPhases": [],
  "githubRepo": "[detected from git remote]",
  "notionPageId": null,
  "createdAt": "[ISO timestamp]",
  "analysis": {
    "techStack": {
      "backend": "[detected]",
      "frontend": "[detected]",
      "database": "[detected]",
      "hasTests": "[yes/no]",
      "coverageEstimate": "[low/medium/high]"
    },
    "issuesFound": {
      "critical": [N],
      "high": [N],
      "medium": [N],
      "low": [N]
    },
    "architecturePattern": "[detected pattern]",
    "deviations": ["[deviation 1]", "[deviation 2]"]
  },
  "stack": {
    "backend": "[detected]",
    "frontend": "[detected]",
    "mobile": "[detected or null]",
    "database": "[detected]",
    "cache": "[detected or null]",
    "auth": "[detected]",
    "deviations": []
  }
}
```

Save full analysis to `.sde/phases/0-analysis.md`.

---

## Step 7: Show Analysis Dashboard

```
╔═══════════════════════════════════════════════════════════════╗
║  SDE PLUGIN — Codebase Analysis Complete                      ║
╠═══════════════════════════════════════════════════════════════╣
║  Project: [name]                                              ║
║  Files Analyzed: [N]                                          ║
║                                                               ║
║  DETECTED TECH STACK:                                         ║
║  Backend:  [NestJS/Express/...]                               ║
║  Frontend: [React/Vue/...]                                    ║
║  Database: [PostgreSQL/MySQL/...]                             ║
║  Auth:     [JWT/Session/...]                                  ║
║  Tests:    [Jest/Mocha/...] — Coverage: ~[N]%                 ║
║                                                               ║
║  ARCHITECTURE: [Modular Monolith/MVC/...]                     ║
╠═══════════════════════════════════════════════════════════════╣
║  ISSUES FOUND:                                                ║
║  🔴 Critical: [N]  ← Fix before anything else               ║
║  🟠 High:     [N]  ← Fix this week                          ║
║  🟡 Medium:   [N]  ← This sprint                            ║
║  🔵 Low:      [N]  ← Backlog                                ║
╠═══════════════════════════════════════════════════════════════╣
║  IMPROVEMENT PLAN: 5 phases                                   ║
║                                                               ║
║  Phase A: Security fixes  →  /sde-secure                     ║
║  Phase B: Test coverage   →  /sde-test                       ║
║  Phase C: Architecture    →  /sde-iterate                    ║
║  Phase D: Performance     →  /sde-optimize                   ║
║  Phase E: DevOps setup    →  /sde-devops                     ║
╠═══════════════════════════════════════════════════════════════╣
║  CRITICAL ISSUES REQUIRING IMMEDIATE ATTENTION:              ║
║  • [Critical issue 1]                                         ║
║  • [Critical issue 2]                                         ║
╠═══════════════════════════════════════════════════════════════╣
║  RECOMMENDED NEXT STEP:                                       ║
║  Run /sde-secure to fix all critical security issues          ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## Autonomous Actions

1. Run all detection and analysis commands above
2. Initialize `.sde/context.json` with findings
3. Save full analysis to `.sde/phases/0-analysis.md`
4. Create Notion page for the existing project (via API)
5. ```bash
   git add .sde/
   git commit -m "chore: SDE Plugin analysis initialized"
   ```
6. Show the analysis dashboard

---

## Follow-Up

After showing the dashboard, prompt:
```
Which phase should we address first?
1. /sde-secure  → fix critical security issues (RECOMMENDED)
2. /sde-test    → add test coverage first
3. /sde-iterate → broad code quality improvement

Or describe what area to focus on.
```
