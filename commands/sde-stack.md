---
description: Phase 3 — Tech Stack Decision. Finalizes tech stack based on PRD requirements, generates complete package lists with versions, and creates ADRs for any deviations from defaults.
allowed-tools: Agent, Read, Write
disable-model-invocation: true
---

## Live Project Context
!`cat .sde/context.json 2>/dev/null || echo '{"status": "no-project"}'`

## ⛔ Phase Guard — Read This First

Before doing ANYTHING else, check:
1. Does `.sde/context.json` exist in the current directory?
2. Does `.sde/phases/1-prd.md` exist?
3. Does `.sde/phases/2-architecture.md` exist?

If ANY of these are missing → STOP immediately and output:
```
⛔ Run /sde-idea → /sde-prd → /sde-architect before running /sde-stack.

Make sure you're in the correct project directory.
```
Do NOT proceed past this point.

If all three exist → read them and continue.

---

# SDE Stack — Phase 3: Tech Stack Decision

## Pre-Flight

1. Read `.sde/context.json` — project type, clarifications (realtime, payments, fileUploads, etc.)
2. Read `.sde/phases/2-architecture.md` — architecture decisions
3. Read `.sde/phases/1-prd.md` — features that drive stack decisions

---

## Deviation Analysis

Check `context.json` clarifications and PRD features against the default stack. For each deviation detected, create an ADR in `.sde/adr/`.

| Trigger | Deviation | Packages to Add |
|---------|-----------|----------------|
| `realtime: true` OR real-time features | Add Socket.io | `@nestjs/websockets @nestjs/platform-socket.io socket.io socket.io-client` |
| `payments: true` OR payments in PRD | Add Stripe | `stripe @stripe/stripe-js` |
| Email sending needed | Add Nodemailer + Resend | `nodemailer @nestjs-modules/mailer resend` |
| `fileUploads: true` | Confirm S3 setup | `@aws-sdk/client-s3 @aws-sdk/s3-request-presigner multer @nestjs/platform-express` |
| Mobile in project type | Add Expo packages | `expo-router @react-navigation/native expo-secure-store expo-notifications` |
| Admin in project type | Confirm admin stack | `recharts` |
| Background jobs needed | Add Bull + Redis queue | `@nestjs/bull bull ioredis` |
| Social login mentioned | Add Passport strategies | `passport-google-oauth20 @types/passport-google-oauth20` |

---

## Final Stack Output

Output the finalized stack across all applicable layers (backend, frontend, mobile if applicable, infrastructure). Use the canonical versions from `~/.sde-plugin/context/stack-constants.md`.

For each deviation from the default stack, write an ADR to `.sde/adr/ADR-00N-[name].md` covering: Context, Decision, Rationale, Consequences (positive and negative).

---

## Autonomous Actions

1. Save to `.sde/phases/3-stack.md`
2. Save deviation ADRs to `.sde/adr/ADR-00N-*.md`
3. Update `.sde/context.json` stack object:
   ```json
   "stack": {
     "deviations": ["realtime:socket.io", "payments:stripe"]
   }
   ```
4. Sync to Notion sub-page "Tech Stack — Phase 3"
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
