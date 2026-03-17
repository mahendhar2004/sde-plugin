---
description: Phase 1 — Product Requirements Document. Generates a complete PRD with user personas, feature prioritization, NFRs, user stories, acceptance criteria, and success metrics. Syncs to Notion.
allowed-tools: Agent, Read
disable-model-invocation: true
---

## Live Project Context
!`cat .sde/context.json 2>/dev/null || echo '{"status": "no-project"}'`

## ⛔ Phase Guard — Read This First

Before doing ANYTHING else, check:
1. Does `.sde/context.json` exist in the current directory?
2. Does `.sde/phases/0-idea.md` exist?

If EITHER is missing → STOP immediately and output:
```
⛔ Phase 0 not complete.

Run /sde-idea first to initialize the project.
If you already ran it, make sure you're in the correct project directory.
```
Do NOT proceed past this point.

If both exist → read them and continue.

---

## Agent Invocation

Use the **Agent tool** to spawn one agent:

### PM Agent
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/pm-agent.md for your full identity and standards.

Your task: Write a complete Product Requirements Document for this project.

Project context: Read .sde/context.json and .sde/phases/0-idea.md for project details.

Follow the full PRD structure defined in your identity file. Cover:
- Problem statement and personas
- User stories with BDD acceptance criteria (Given/When/Then)
- MVP vs future features (MoSCoW)
- Non-functional requirements (performance, security, scale)
- Success metrics (SMART)

Save the PRD to .sde/phases/1-prd.md when complete.
```

---

# SDE PRD — Phase 1: Product Requirements Document

## Pre-Flight

1. Read `.sde/context.json` — get project name, type, clarifications
2. Read `.sde/phases/0-idea.md` — get problem statement, personas, value prop, risks
3. Verify currentPhase is 0 or that phase 0 is in completedPhases

---

## Generate Complete PRD

### Section 1: Product Overview

**What It Is:**
Write 1-2 paragraphs describing the product from a user perspective. Avoid technical jargon. Focus on what value it delivers.

**What Problem It Solves:**
Expand on the problem statement from Phase 0. Include quantification where possible (e.g., "users currently spend X minutes doing Y manually").

**Why Now:**
1-2 sentences on timing/market context.

---

### Section 2: User Personas (Detailed)

For each persona identified in Phase 0, expand into full detail:

```
## Persona: [Name] — [Role]

**Demographics:** [age range, profession, context]

**Goals:**
- Primary: [what they most want to achieve]
- Secondary: [additional goals]

**Frustrations:**
- [specific pain point with current alternatives]
- [another frustration]

**Tech Literacy:** [Low / Medium / High]
**Device Usage:** [primarily mobile / desktop / both]
**Session Pattern:** [daily / weekly, how long per session]

**Quote:** "[A realistic quote this person might say about their problem]"
```

---

### Section 3: Core Features

Organize all features into three tiers:

**MVP (Must Have for Launch):**
| # | Feature | Description | User Benefit |
|---|---------|-------------|--------------|
| 1 | [feature] | [what it does] | [why users need it] |

**V2 (Important but not blocking):**
| # | Feature | Description | User Benefit |
|---|---------|-------------|--------------|

**Future (Nice to have, post-traction):**
| # | Feature | Description | User Benefit |
|---|---------|-------------|--------------|

Rules for MVP classification:
- Include only what makes the product usable for its core purpose
- Authentication is ALWAYS MVP
- Payments are MVP only if the business model requires it at launch
- Analytics/reporting can usually be V2
- Social features (sharing, following) are usually V2+

---

### Section 4: Non-Functional Requirements

| Category | Requirement | Target | Notes |
|----------|-------------|--------|-------|
| Performance | API p95 response time | < 200ms | Under normal load |
| Performance | Page load time (FCP) | < 2s | On 4G mobile |
| Scalability | Concurrent users | 100 initial, 1000 target | EC2 t2.micro baseline |
| Availability | Uptime SLA | 99.5% | Acceptable for v1 |
| Security | Auth | JWT 15min/7day | Refresh token rotation |
| Security | OWASP | Top 10 compliance | All critical items |
| Data | Retention | [X months] | Per privacy needs |
| Compliance | [GDPR/CCPA] | [if applicable] | User data deletion |
| Accessibility | WCAG | 2.1 AA | Core user flows |

---

### Section 5: Edge Cases

List all important edge cases organized by feature area:

**Authentication:**
- User attempts to log in with wrong password 5 times
- User's access token expires mid-session
- User logs out on one device while logged in on another
- Password reset link is used twice
- Account registered with email that already exists

**Data Management:**
- User submits form with network offline
- User uploads file exceeding size limit
- User enters special characters, XSS attempts in text fields
- Two users edit the same record simultaneously
- User deletes resource that other resources depend on

**User Experience:**
- User navigates back/forward in browser mid-flow
- User opens app on low-bandwidth connection
- User's session expires while filling a long form

**Add feature-specific edge cases based on the product idea.**

---

### Section 6: User Stories

Format: "As a [persona], I want to [action], so that [outcome]."

Group by feature area. Write at least 2 stories per core feature.

Example structure:
```
## Authentication
- As a new user, I want to register with my email and password, so that I have a personal account
- As a returning user, I want to log in and stay logged in for 7 days, so that I don't re-authenticate constantly
- As a user, I want to reset my password via email, so that I can regain access if I forget it

## [Feature Area]
- [stories...]
```

Write stories for ALL MVP features. Write at least the first 2 stories for V2 features.

---

### Section 7: Acceptance Criteria

For each user story, write Given/When/Then criteria:

```
### Story: Register with email and password

**AC-001:** Successful registration
- GIVEN I am on the registration page
- WHEN I enter a valid email and a password ≥ 8 chars with 1 uppercase, 1 number
- AND I submit the form
- THEN my account is created
- AND I receive a welcome email
- AND I am redirected to the dashboard

**AC-002:** Duplicate email
- GIVEN a user with email@example.com already exists
- WHEN I try to register with the same email
- THEN I see: "An account with this email already exists"
- AND no new account is created

**AC-003:** Weak password
- GIVEN I am on the registration page
- WHEN I submit a password shorter than 8 characters
- THEN I see inline validation: "Password must be at least 8 characters"
- AND the form is NOT submitted
```

Write ACs for all MVP stories. Be specific about UI states, error messages, and redirects.

---

### Section 8: Success Metrics (KPIs)

| Metric | Target (30 days) | Target (90 days) | How to Measure |
|--------|-----------------|-----------------|----------------|
| Registered users | [N] | [N] | Database count |
| Daily Active Users | [N] | [N] | Analytics event |
| [Core feature] usage | [N/day] | [N/day] | Analytics event |
| User retention (7-day) | > 30% | > 40% | Cohort analysis |
| Error rate | < 1% | < 0.5% | Sentry |
| API uptime | > 99% | > 99.5% | Health checks |

---

## Autonomous Actions

### Action 1: Save PRD
```bash
# Write full PRD to .sde/phases/1-prd.md
```

### Action 2: Create Notion Sub-Page

```bash
curl -s -X POST \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  https://api.notion.com/v1/pages \
  -d '{
    "parent": {"page_id": "[notionPageId from context.json]"},
    "properties": {
      "title": {"title": [{"text": {"content": "PRD — Phase 1"}}]}
    },
    "children": [
      ... (full PRD content as Notion blocks)
    ]
  }'
```

Add all PRD sections as proper Notion blocks (heading_1, heading_2, paragraph, bulleted_list_item, table).

### Action 3: Update Notion Project Page

Update the project's main Notion database entry:
- Phase → 1
- Status → "In Progress"

### Action 4: Git Operations

```bash
git checkout develop
git checkout -b feature/1-prd
git add .sde/phases/1-prd.md
git commit -m "docs: add PRD — Phase 1"
git push origin feature/1-prd
```

### Action 5: Update context.json

```json
{
  "currentPhase": 1,
  "completedPhases": [0, 1]
}
```

(Merge with existing content — add 1 to completedPhases, update currentPhase)

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 1 COMPLETE — PRD                       ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • [N] personas defined in detail                ║
║  • [N] MVP features, [N] V2, [N] future          ║
║  • [N] user stories with ACs                     ║
║  • NFR table complete                            ║
║  • Success metrics defined                       ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • .sde/phases/1-prd.md                          ║
║  • Notion sub-page: "PRD — Phase 1"              ║
║  • Git committed: feature/1-prd                  ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 2 — System Architecture             ║
╠══════════════════════════════════════════════════╣
║  [proceed] → start architecture design           ║
║  [refine]  → improve PRD                         ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
