---
description: Phase 9 — Security Hardening. Audits against all OWASP Top 10 categories, fixes every issue found autonomously, and generates a comprehensive security report.
---

## ⚠️ Phase Guard — Read This First

Before doing ANYTHING else, check:
1. Does `.sde/context.json` exist in the current directory?

If it is missing → output this warning and continue in standalone mode:
```
⚠️ No .sde/context.json found. Running in standalone mode — will analyze current directory without project context.
```
Do NOT stop — proceed with the security audit against the current directory.

If it exists → read it and use it to inform the audit.

---

## Agent Invocation

Use the **Agent tool** to spawn one agent:

### Security Agent
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/security-agent.md for your full identity and standards.
Also read:
- ~/.sde-plugin/context/security-rules.md

Your task: Perform a complete OWASP Top 10 security audit and fix all issues.

Project context: Read .sde/context.json. Scan the entire codebase.

Audit and fix:
1. A01 Broken Access Control — ownership checks, role enforcement
2. A02 Cryptographic Failures — secrets in code, weak hashing
3. A03 Injection — SQL injection, XSS, command injection
4. A04 Insecure Design — missing rate limiting, no input validation
5. A05 Security Misconfiguration — CORS, Helmet, exposed endpoints
6. A06 Vulnerable Components — outdated packages with CVEs
7. A07 Auth Failures — JWT handling, refresh token rotation
8. A08 Data Integrity — unsigned data, unsafe deserialization
9. A09 Logging Failures — sensitive data in logs
10. A10 SSRF — unvalidated external URLs

For Supabase projects also check:
- RLS enabled on all user-data tables
- No service role key in client code
- getUser() used instead of getSession() for identity

Produce: security audit report + fix all issues found.
```

---

# SDE Secure — Phase 9: Security Hardening

## Pre-Flight

1. Read `.sde/phases/7-implementation.md` — all modules to audit
2. Read `.sde/phases/5-api-design.md` — all endpoints to check
3. Read `.sde/context.json` — project type

---

## OWASP Top 10 Audit Checklist

Work through each category systematically. For each issue found: FIX IT autonomously, then mark as resolved.

---

### A01: Broken Access Control

**Checks to perform:**

1. **JWT guard on all protected routes**
   - Scan ALL controllers for `@Get()`, `@Post()`, `@Put()`, `@Patch()`, `@Delete()` decorators
   - Verify each has either: class-level `@UseGuards(JwtAuthGuard)`, or `@Public()` decorator
   - Fix: Add `@UseGuards(JwtAuthGuard)` to any controller missing it

2. **Users can only access their own data**
   - In every service method that takes `id` as parameter, verify it checks `userId` ownership
   - Example fix in service:
   ```typescript
   // WRONG — no ownership check
   async findOne(id: string): Promise<Entity> {
     return this.repo.findOneOrFail({ where: { id } });
   }

   // CORRECT — ownership enforced
   async findOne(id: string, userId: string): Promise<Entity> {
     const entity = await this.repo.findOne({ where: { id, userId } });
     if (!entity) throw new NotFoundException('Not found');
     return entity;
   }
   ```

3. **Admin role protection**
   - Any endpoint accessing admin-only data must have `@Roles('admin')` guard
   - Verify `RolesGuard` is properly checking `user.role`

4. **IDOR prevention**
   - In all update/delete operations, ensure the WHERE clause includes both `id` AND `userId`

**Fix template if needed:**
```typescript
// src/common/guards/roles.guard.ts
import { Injectable, CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>('roles', [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!requiredRoles) return true;
    const { user } = context.switchToHttp().getRequest();
    return requiredRoles.includes(user?.role);
  }
}
```

---

### A02: Cryptographic Failures

**Checks:**

1. **bcrypt rounds ≥ 12**
   ```bash
   grep -r "bcrypt.hash" src/ | grep -v "spec"
   ```
   Fix: Change any rounds < 12 to 12.

2. **JWT secrets minimum length**
   - Check `.env.example` — JWT_SECRET and JWT_REFRESH_SECRET must be described as "min 32 characters"
   - Check strategy files — secrets come from `configService.get()`, NOT hardcoded
   - Add runtime check in main.ts:
   ```typescript
   const jwtSecret = configService.get<string>('JWT_SECRET');
   if (!jwtSecret || jwtSecret.length < 32) {
     throw new Error('JWT_SECRET must be at least 32 characters');
   }
   ```

3. **No sensitive data in logs**
   - Search for any logger calls that might include passwords or tokens:
   ```bash
   grep -r "password\|token\|secret\|hash" src/ --include="*.ts" | grep -i "log\|console"
   ```
   Fix: Remove or mask any such log statements.

4. **HTTPS in production**
   - Add note in deployment config: SSL/TLS termination at nginx/CloudFront level

---

### A03: Injection

**Checks:**

1. **TypeORM parameterized queries**
   - Search for any raw SQL with string concatenation:
   ```bash
   grep -r "query\|createQueryBuilder" src/ --include="*.ts" | grep -v "spec"
   ```
   - Fix any patterns like: `` `SELECT * FROM users WHERE id = '${userId}'` ``
   - Correct: use TypeORM's parameter syntax: `` .where('id = :id', { id: userId }) ``

2. **class-validator on ALL DTOs**
   - Check every DTO file has decorators on all properties
   - GlobalValidationPipe must have `whitelist: true, forbidNonWhitelisted: true`
   - Verify in main.ts:
   ```typescript
   app.useGlobalPipes(new ValidationPipe({
     whitelist: true,           // strip unknown fields
     forbidNonWhitelisted: true, // throw on unknown fields
     transform: true,
   }));
   ```

3. **XSS prevention**
   - Validate string fields have `@MaxLength()` constraints
   - Consider `@Transform(({ value }) => sanitizeHtml(value))` for HTML content fields

---

### A04: Insecure Design

**Checks:**

1. **Rate limiting on auth endpoints**
   - Verify `@Throttle()` decorator with strict settings on: register, login, forgot-password
   - If not present, add:
   ```typescript
   @Throttle({ default: { limit: 5, ttl: 900000 } }) // 5 per 15 min
   @Post('login')
   async login() { ... }
   ```

2. **Account lockout after failed attempts**
   - Verify failed attempts counter exists in User entity
   - Verify lock logic in auth service:
   ```typescript
   // After incrementing failed attempts:
   if (user.failedLoginAttempts >= 5) {
     const lockUntil = new Date(Date.now() + 15 * 60 * 1000); // 15 min
     await this.usersService.lockAccount(user.id, lockUntil);
   }
   ```

3. **Refresh token rotation**
   - Verify old refresh token is revoked when issuing new one
   - Verify tokens older than 7 days are cleaned up

4. **Password reset token expiry**
   - Verify reset tokens expire in ≤ 1 hour
   - Verify reset tokens are single-use (mark as used after consumption)

---

### A05: Security Misconfiguration

**Checks:**

1. **Helmet with strict CSP**
   ```typescript
   // Verify in main.ts:
   app.use(helmet.default({
     contentSecurityPolicy: {
       directives: {
         defaultSrc: ["'self'"],
         scriptSrc: ["'self'"],
         styleSrc: ["'self'", "'unsafe-inline'"],
         imgSrc: ["'self'", 'data:', 'https:'],
         connectSrc: ["'self'"],
         fontSrc: ["'self'"],
         objectSrc: ["'none'"],
         upgradeInsecureRequests: [],
       },
     },
   }));
   ```

2. **CORS allows only known origins**
   - Fix any `origin: '*'` to specific allowed origins from env:
   ```typescript
   app.enableCors({
     origin: configService.get<string>('CORS_ORIGINS').split(','),
     credentials: true,
   });
   ```

3. **No stack traces in production**
   - Verify HttpExceptionFilter does NOT include `exception.stack` in response body
   - Check: logger uses stack trace but response doesn't expose it

4. **.env.example has placeholders only**
   - Scan `.env.example` for real secrets:
   ```bash
   grep -E "[0-9a-zA-Z]{32,}" .env.example | grep -v "change-me\|your-"
   ```
   - Replace any real values with placeholder text

---

### A06: Vulnerable Components

**Run:**
```bash
cd backend && npm audit --audit-level=high 2>&1
cd frontend && npm audit --audit-level=high 2>&1
```

Parse output. For each HIGH or CRITICAL vulnerability:
- Run `npm audit fix` for auto-fixable issues
- For breaking changes, manually update the package and run tests
- Document any that cannot be fixed (transitive deps) as known issues

---

### A07: Auth and Session Failures

**Checks:**

1. **JWT expiry times**
   - Access token: `15m` or less
   - Refresh token: `7d` or less
   - Verify in JWT strategy and service:
   ```typescript
   // In auth service:
   signOptions: { expiresIn: '15m' }  // access
   signOptions: { expiresIn: '7d' }   // refresh
   ```

2. **Refresh tokens stored hashed**
   - Verify `tokenHash = await bcrypt.hash(rawToken, 12)` before storage
   - Verify raw token is NEVER stored in database

3. **Logout invalidates token**
   - Verify logout endpoint marks refresh token as `isRevoked: true`
   - Verify query for valid tokens includes `isRevoked: false`

4. **Old sessions cleanup**
   - Verify periodic cleanup of expired tokens (via query builder or cron)

---

### A08: Software and Data Integrity Failures

**Checks:**

1. **File upload validation**
   - If file uploads present, verify:
   ```typescript
   // In upload controller:
   @UseInterceptors(FileInterceptor('file', {
     limits: { fileSize: 5 * 1024 * 1024 }, // 5MB max
     fileFilter: (req, file, cb) => {
       const allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];
       if (!allowedTypes.includes(file.mimetype)) {
         return cb(new BadRequestException('Invalid file type'), false);
       }
       cb(null, true);
     },
   }))
   ```

2. **DTO serialization (no raw entities)**
   - Verify controllers return response DTOs, not raw TypeORM entities
   - Use `@Exclude()` on sensitive fields + `ClassSerializerInterceptor`
   - Add to app.module.ts providers:
   ```typescript
   { provide: APP_INTERCEPTOR, useClass: ClassSerializerInterceptor }
   ```

---

### A09: Security Logging and Monitoring Failures

**Checks:**

1. **Auth events are logged**
   - Verify LoggingInterceptor or auth service logs: login, logout, failed_login, register
   - Template:
   ```typescript
   this.logger.log({
     event: 'login_success',
     userId: user.id,
     ip: request.ip,
     timestamp: new Date().toISOString(),
   });
   ```

2. **Sensitive data NOT logged**
   - Audit all logger.log/debug/warn/error calls in auth module
   - Ensure no `password`, `token`, `hash` values appear in log output

3. **Sentry configured**
   - Verify `@sentry/node` is initialized in main.ts before app creation
   - Test with intentional error (remove after test)

---

### A10: Server-Side Request Forgery (SSRF)

**Checks:**

1. **URL input validation**
   - If any endpoint accepts URLs (avatarUrl, webhookUrl, etc.):
   ```typescript
   // In DTO:
   @IsUrl({
     protocols: ['https'],
     require_tld: true,
     allow_underscores: false,
   })
   avatarUrl?: string;
   ```

2. **No user-controlled HTTP requests**
   - Search for `axios.get($variable)` or `fetch($variable)` patterns
   - Any URL fetching must validate against an allowlist first

---

## Security Audit Report

After completing all checks, generate report:

```markdown
# Security Audit Report — Phase 9

**Date:** [date]
**Audited By:** SDE Security Agent

## Summary
| Category | Status | Issues Found | Issues Fixed |
|----------|--------|--------------|--------------|
| A01: Access Control | ✅ PASS | 0 | 0 |
| A02: Cryptographic | ✅ PASS | 0 | 0 |
| A03: Injection | ✅ PASS | 0 | 0 |
| A04: Insecure Design | ✅ PASS | 0 | 0 |
| A05: Misconfiguration | ✅ PASS | 0 | 0 |
| A06: Vulnerable Components | [STATUS] | [N] | [N] |
| A07: Auth Failures | ✅ PASS | 0 | 0 |
| A08: Data Integrity | ✅ PASS | 0 | 0 |
| A09: Logging | ✅ PASS | 0 | 0 |
| A10: SSRF | ✅ PASS | 0 | 0 |

## Issues Found and Fixed
[List each issue with: description, severity, fix applied]

## Remaining Known Issues
[Any issues that could not be auto-fixed, with manual remediation steps]

## npm audit results
- Backend: [N] vulnerabilities (HIGH: N, CRITICAL: N)
- Frontend: [N] vulnerabilities (HIGH: N, CRITICAL: N)
```

---

## Autonomous Actions

1. Fix ALL issues found during audit (directly edit source files)
2. Run `npm audit fix` in backend and frontend
3. Save security audit report to `.sde/phases/9-security.md`
4. ```bash
   git checkout develop
   git checkout -b feature/9-security
   git add .
   git commit -m "security: OWASP Top 10 audit and hardening — Phase 9"
   git push origin feature/9-security
   ```
5. Update context.json: `currentPhase: 9`, add 9 to `completedPhases`

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 9 COMPLETE — Security Hardening        ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • OWASP A01-A10 audited                         ║
║  • [N] issues found and fixed                    ║
║  • npm audit: [status]                           ║
║  • Security audit report generated               ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • .sde/phases/9-security.md                     ║
║  • All security fixes applied                    ║
║  • Git committed: feature/9-security             ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 10 — Performance Optimization       ║
╠══════════════════════════════════════════════════╣
║  [proceed] → optimize performance                ║
║  [refine]  → deeper security review              ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
