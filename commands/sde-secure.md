---
description: Phase 9 — Security Hardening. Audits against all OWASP Top 10 categories, fixes every issue found autonomously, and generates a comprehensive security report.
allowed-tools: Agent, Read, Grep, Glob
disable-model-invocation: true
---

## Live Project Context
!`cat .sde/context.json 2>/dev/null || echo '{"status": "no-project"}'`

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

## What This Phase Produces

- A01: All controllers verified for JWT guards; ownership checks on every data-access method
- A02: bcrypt rounds ≥ 12; JWT secrets min 32 chars enforced at startup; no secrets in logs
- A03: All DTOs have class-validator; ValidationPipe has whitelist + forbidNonWhitelisted; no raw SQL concatenation
- A04: Throttle decorators on auth endpoints; account lockout after 5 failed attempts; refresh token rotation
- A05: Helmet with strict CSP; CORS scoped to env-configured origins; no stack traces in production responses
- A06: npm audit run; HIGH/CRITICAL vulnerabilities fixed or documented
- A07: Access token 15m, refresh token 7d; refresh tokens stored hashed; logout revokes token
- A08: File uploads validated by mimetype + size; ClassSerializerInterceptor excludes sensitive fields
- A09: Auth events logged (login, logout, failed_login); no passwords/tokens in log output
- A10: URL inputs validated with @IsUrl(https-only); no unvalidated user-controlled HTTP requests
- Security audit report saved to `.sde/phases/9-security.md`

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
