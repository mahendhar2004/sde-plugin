---
description: Phase 0 — Idea Understanding. Analyzes raw product idea, detects project type, creates GitHub repo, initializes .sde/ project state, and syncs to Notion.
argument-hint: "[your idea description]"
allowed-tools: Read, Write, Bash, Agent
disable-model-invocation: true
---

# SDE Idea — Phase 0: Idea Understanding

You receive a raw product idea from the user (a sentence, a paragraph, a rough description). Your job is to deeply understand it, structure it, detect the project type, ask minimal clarifying questions if truly needed, then take full autonomous action to initialize the project.

---

## Step 1: Analyze the Raw Idea

Read the user's input carefully. Extract and structure:

### Problem Statement
Write 2-3 sentences: What is the core problem being solved? Who has this problem? Why does it matter?

### Target Users Table

| Persona | Description | Primary Need | Tech Literacy |
|---------|-------------|--------------|---------------|
| [Persona 1] | [Who they are] | [What they need most] | [Low/Med/High] |
| [Persona 2] | ... | ... | ... |

### Value Proposition
One clear sentence: "[Product] helps [users] to [action] by [unique mechanism], unlike [alternative] which [limitation]."

### Constraints
- List any explicit constraints mentioned (budget, timeline, technical, regulatory)
- If none mentioned, note: "No explicit constraints stated — operating under standard solo dev constraints (AWS free tier, no paid SaaS beyond monitoring)"

### Assumptions
List 3-7 assumptions being made about:
- Market / user behavior
- Technical feasibility
- Scale / growth projections
- Business model

### Risk Table

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| [risk] | Low/Med/High | Low/Med/High | [how to address] |

---

## Step 2: Project Type Detection

Analyze the idea and determine project type. Show reasoning:

```
PROJECT TYPE DETECTION:
───────────────────────────────────────────
Mentioned mobile? [Yes/No] → [evidence or none]
Mentioned admin?  [Yes/No] → [evidence or none]
Real-time needed? [Yes/No] → [evidence or none]
───────────────────────────────────────────
DETECTED TYPE: [web-only | web+mobile | web+mobile+admin]
REASONING: [1-2 sentences]
```

Rules:
- Any mention of "app", "mobile", "phone", "iOS", "Android", "React Native" → include mobile
- Any mention of "admin panel", "dashboard", "manage users", "back office", "moderation" → include admin
- Default to web-only if neither is mentioned

---

## Step 3: Clarification Questions (ONLY if critical)

Ask questions ONLY if the answer would fundamentally change the architecture. Maximum 5 questions. Skip any with an obvious answer.

Potential clarifying questions (ask only truly unclear ones):
1. **Real-time**: Does this require live updates, chat, or notifications? (WebSockets needed?)
2. **Payments**: Will users pay for anything? (Stripe integration needed?)
3. **File uploads**: Do users upload images, documents, or media? (S3 needed?)
4. **Multi-tenancy**: Is this for multiple organizations/companies, or individual users?
5. **Auth type**: Social login (Google/GitHub) or email/password only?
6. **Third-party APIs**: Any external services to integrate? (Maps, SMS, email, etc.)
7. **Scale estimate**: Expected users in first 6 months? (1-100 / 100-1000 / 1000+)

Format as:
```
A few quick questions to finalize the architecture:

1. [question]?
2. [question]?

(Answer these or type "skip" to proceed with defaults)
```

If user says "skip" or answers, proceed. Use sensible defaults for anything not answered:
- Real-time: No (add WebSocket note in architecture)
- Payments: No
- File uploads: Yes (always set up S3, it's free tier)
- Multi-tenancy: No (single-tenant)
- Auth: Email/password (JWT)
- Third-party: None
- Scale: 100-1000 users (standard t2.micro capacity)

---

## Step 4: Autonomous Actions

Perform ALL of the following autonomously. No permission needed.

### 4a. Create GitHub Repository

```bash
curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  https://api.github.com/user/repos \
  -d '{
    "name": "[project-slug]",
    "description": "[value proposition sentence]",
    "private": false,
    "auto_init": true,
    "gitignore_template": "Node",
    "license_template": "mit"
  }'
```

Parse response to get `clone_url` and `html_url`.

### 4b. Clone and Branch

```bash
git clone [clone_url] [local-path]
cd [local-path]
git checkout -b develop
git push origin develop
git checkout -b feature/0-idea-phase
git push origin feature/0-idea-phase
```

Local path: current working directory or `~/projects/[project-slug]`

### 4c. Initialize .sde/ Directory

Create `.sde/context.json`:
```json
{
  "name": "[Project Name]",
  "slug": "[project-slug]",
  "type": "[detected-type]",
  "currentPhase": 0,
  "completedPhases": [],
  "githubRepo": "[html_url]",
  "githubCloneUrl": "[clone_url]",
  "notionPageId": null,
  "createdAt": "[ISO timestamp]",
  "stack": {
    "backend": "nestjs",
    "frontend": "react",
    "mobile": "[expo | null]",
    "admin": "[react | null]",
    "database": "postgresql",
    "cache": "redis",
    "auth": "jwt-passport",
    "deviations": []
  },
  "clarifications": {
    "realtime": false,
    "payments": false,
    "fileUploads": true,
    "multiTenancy": false,
    "authType": "email",
    "thirdPartyApis": [],
    "estimatedUsers": "100-1000"
  }
}
```

Create `.sde/phases/` directory.
Create `.sde/adr/` directory.
Create `.sde/schemas/` directory.

### 4d. Save Phase Output

Save the full analysis (problem statement, personas, value prop, constraints, assumptions, risks) to `.sde/phases/0-idea.md`.

### 4e. Create Notion Page

```bash
curl -s -X POST \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  https://api.notion.com/v1/pages \
  -d '{
    "parent": {"database_id": "[NOTION_DATABASE_ID]"},
    "properties": {
      "Name": {"title": [{"text": {"content": "[Project Name]"}}]},
      "Type": {"select": {"name": "[project-type]"}},
      "Phase": {"number": 0},
      "Status": {"select": {"name": "Planning"}},
      "GitHubURL": {"url": "[github html_url]"}
    },
    "children": [
      {
        "object": "block",
        "type": "heading_1",
        "heading_1": {"rich_text": [{"text": {"content": "Phase 0: Idea Analysis"}}]}
      },
      {
        "object": "block",
        "type": "heading_2",
        "heading_2": {"rich_text": [{"text": {"content": "Problem Statement"}}]}
      },
      {
        "object": "block",
        "type": "paragraph",
        "paragraph": {"rich_text": [{"text": {"content": "[problem statement text]"}}]}
      }
    ]
  }'
```

Parse response to get Notion page `id`. Store in context.json as `notionPageId`.

### 4f. Update context.json with notionPageId

```bash
# Update .sde/context.json with the notionPageId from step 4e
```

### 4g. Git Commit

```bash
git add .sde/
git commit -m "chore: initialize project — Phase 0 idea analysis"
git push origin feature/0-idea-phase
```

---

## Step 5: Show Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 0 COMPLETE — Idea Analysis             ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • Problem statement defined                     ║
║  • [N] personas identified                       ║
║  • Project type: [type]                          ║
║  • Value proposition crafted                     ║
║  • [N] risks identified                          ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • .sde/phases/0-idea.md                         ║
║  • .sde/context.json initialized                 ║
║  • GitHub repo: [repo URL]                       ║
║  • Notion page synced                            ║
║  • Git committed: feature/0-idea-phase           ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 1 — Product Requirements Document   ║
╠══════════════════════════════════════════════════╣
║  [proceed] → start PRD immediately               ║
║  [refine]  → redo idea analysis                  ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```

---

## Error Handling

- If GitHub API fails (rate limit, auth error): Save files locally, show error, continue
- If Notion API fails: Save files locally, note "Notion sync pending", continue
- If git push fails: Local commit is fine, show push command for manual retry
- NEVER block phase completion due to integration failures
- Always create .sde/ files regardless of external service status
