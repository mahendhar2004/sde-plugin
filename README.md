# SDE Plugin — Software Development Engine

A complete Claude Code plugin that gives you a full AI engineering team for solo developers. 18 skills covering the entire software development lifecycle — from raw idea to production deployment in 13 structured phases.

## What Is SDE Plugin?

SDE Plugin turns Claude Code into a **Staff-level AI engineering team** that autonomously:

- Understands your product idea and writes a complete PRD
- Designs system architecture with ASCII diagrams and ADRs
- Selects and justifies the entire tech stack
- Designs the data model with TypeORM entities and SQL DDL
- Designs the REST API with a full OpenAPI 3.0 spec
- Scaffolds the entire project with working boilerplate code
- Implements every feature: NestJS backend, React frontend, Expo mobile
- Generates comprehensive tests targeting 80% coverage
- Audits OWASP Top 10 and fixes every security issue
- Optimizes performance: N+1 queries, Redis caching, frontend bundle
- Generates Dockerfiles, GitHub Actions CI/CD, k3s manifests
- Creates a production readiness checklist and rollback runbook
- Runs iterative improvement cycles

**Target user**: Solo TypeScript developer building SaaS products.

---

## All 18 Skills

| Skill | Phase | Purpose |
|-------|-------|---------|
| `/sde` | Master | Orchestrator, project dashboard, quickstart guide |
| `/sde-config` | Setup | One-time env setup — verifies GitHub, Notion, Docker |
| `/sde-idea` | Phase 0 | Idea analysis, project type detection, GitHub repo creation |
| `/sde-prd` | Phase 1 | Full PRD: personas, features, user stories, acceptance criteria |
| `/sde-architect` | Phase 2 | System architecture, component diagrams, auth flow, ADRs |
| `/sde-stack` | Phase 3 | Tech stack decisions, deviation handling, npm package lists |
| `/sde-datamodel` | Phase 4 | ER diagrams, TypeORM entities, SQL DDL schema |
| `/sde-api` | Phase 5 | REST endpoint design, OpenAPI 3.0 spec generation |
| `/sde-scaffold` | Phase 6 | Project scaffolding with working boilerplate code |
| `/sde-implement` | Phase 7 | Full implementation — all modules, pages, screens |
| `/sde-test` | Phase 8 | Tests generating 80%+ coverage, CI-verified |
| `/sde-secure` | Phase 9 | OWASP Top 10 audit + autonomous fixes |
| `/sde-optimize` | Phase 10 | DB indexes, Redis caching, frontend perf, bundle analysis |
| `/sde-devops` | Phase 11 | Dockerfiles, GitHub Actions, k3s, AWS free tier setup |
| `/sde-prod` | Phase 12 | Production readiness checklist, README, rollback runbook |
| `/sde-iterate` | Phase 13 | Continuous refactoring and improvement cycles |
| `/sde-vc` | Utility | Smart git: commits, branches, PRs, releases |
| `/sde-analyze` | Utility | Existing codebase analysis + phased improvement plan |

---

## Installation

### Prerequisites

- Claude Code installed (`npm install -g @anthropic-ai/claude-code` or via Homebrew)
- Git installed
- Docker Desktop installed (for local dev)

### Install Steps

```bash
# 1. Clone the plugin
git clone https://github.com/your-username/sde-plugin ~/Documents/sde-plugin

# 2. Run the installer
cd ~/Documents/sde-plugin
bash install.sh

# 3. Verify symlinks were created
ls ~/.claude/skills/ | grep sde
```

The installer symlinks all 18 skill `.md` files into `~/.claude/skills/`. Claude Code automatically discovers and loads skills from that directory.

### Uninstall

```bash
bash ~/Documents/sde-plugin/uninstall.sh
```

---

## Required Environment Variables

Set these in your `~/.bashrc` or `~/.zshrc` before using the plugin:

```bash
# Notion — project docs and sprint boards
export NOTION_TOKEN="secret_..."            # notion.so/my-integrations → New integration
export NOTION_DATABASE_ID="..."             # 32-char ID from Notion database URL

# GitHub — repo creation, branches, PRs
export GITHUB_TOKEN="ghp_..."              # github.com/settings/tokens (scopes: repo, workflow)

# Sentry — error tracking
export SENTRY_DSN="https://...@sentry.io/..." # sentry.io → Project → Settings → SDK Setup

# Grafana Cloud — metrics + logs (free tier)
export GRAFANA_CLOUD_PUSH_URL="https://prometheus-prod-..."  # Grafana Cloud → Stack → Details
export GRAFANA_CLOUD_API_KEY="glc_..."     # Grafana Cloud → API Keys (role: MetricsPublisher)
```

| Variable | Where to Get |
|----------|-------------|
| `NOTION_TOKEN` | [notion.so/my-integrations](https://notion.so/my-integrations) → New integration → Internal Integration Token |
| `NOTION_DATABASE_ID` | Create a full-page Notion database, share it with your integration, copy ID from URL |
| `GITHUB_TOKEN` | [github.com/settings/tokens](https://github.com/settings/tokens) → Generate new token (classic) → scopes: `repo`, `workflow`, `read:user` |
| `SENTRY_DSN` | [sentry.io](https://sentry.io) → New project → Node.js → Settings → SDK Setup → DSN |
| `GRAFANA_CLOUD_PUSH_URL` | [grafana.com](https://grafana.com/auth/sign-up) → free tier → Stack Details → Prometheus → Remote Write URL |
| `GRAFANA_CLOUD_API_KEY` | Grafana Cloud portal → your org → API Keys → Create → MetricsPublisher role |

---

## Quick Start Guide

### New Project (5 steps)

```
1. Set environment variables (see above) and re-source your shell

2. Open Claude Code in any empty directory:
   mkdir ~/projects/my-app && cd ~/projects/my-app
   claude

3. Run setup (one time only):
   /sde-config

4. Describe your idea:
   /sde-idea

5. Follow the phases:
   After each phase, you'll see a Phase Gate box.
   Type [proceed] to advance, [refine] to redo, or [custom: change something].
```

### Existing Project

```
1. Navigate to your project root:
   cd ~/projects/existing-app
   claude

2. Run analysis:
   /sde-analyze

   This detects your stack, maps architecture, finds all issues,
   and generates a phased improvement plan.
```

---

## Full Usage Example

```
You: /sde-idea

I want to build a habit tracking app. Users log daily habits,
see streaks, and get weekly summaries. Mobile-first but also
needs a web version.

--- SDE Plugin responds ---
PROJECT TYPE DETECTION:
  Mentioned mobile? Yes → "mobile-first"
  Mentioned admin? No
  DETECTED TYPE: web+mobile

[Asks 3 clarifying questions about real-time, social features, scale]

You: No real-time needed. No social. Expect ~500 users in first 6 months.

--- SDE Plugin autonomously ---
✓ Creates GitHub repo: habit-tracker
✓ Clones locally, creates develop + feature/0-idea-phase branches
✓ Initializes .sde/context.json
✓ Saves .sde/phases/0-idea.md
✓ Creates Notion page with problem statement and personas
✓ Commits and pushes

╔══════════════════════════════════════════════════╗
║  ✅ PHASE 0 COMPLETE — Idea Analysis             ║
╠══════════════════════════════════════════════════╣
║  • Problem: Manual habit tracking is tedious     ║
║  • 2 personas: Casual User, Goal-Oriented User   ║
║  • Type: web+mobile                              ║
║  • 5 risks identified with mitigations           ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 1 — Product Requirements Document   ║
╠══════════════════════════════════════════════════╣
║  [proceed] / [refine] / [custom]                 ║
╚══════════════════════════════════════════════════╝

You: proceed
[... 12 more phases continue autonomously ...]
```

---

## Default Tech Stack

Every project starts with this stack. The plugin detects deviations needed based on PRD features.

| Layer | Default | Deviation Trigger |
|-------|---------|------------------|
| Backend | NestJS 10 + TypeScript | — |
| ORM | TypeORM 0.3 | — |
| Database | PostgreSQL 16 (AWS RDS) | — |
| Cache | Redis 7 | — |
| Frontend | React 18 + Vite + Tailwind CSS v3 | — |
| Mobile | React Native + Expo SDK 51 | Only if project type includes mobile |
| Auth | JWT (15min/7day) + Passport.js | — |
| Testing (BE) | Jest + Supertest | — |
| Testing (FE) | Vitest + React Testing Library | — |
| Testing (Mobile) | Jest + Detox | Only if mobile |
| Real-time | — | Add Socket.io if real-time in PRD |
| Payments | — | Add Stripe if payments in PRD |
| Email | — | Add Nodemailer + Resend if email needed |
| Background jobs | — | Add Bull + Redis queue if async processing needed |

---

## AWS Free Tier Resources Used

| Service | Usage | Free Tier Limit |
|---------|-------|----------------|
| EC2 t2.micro | Runs Docker Compose (backend + redis + nginx) | 750 hrs/month |
| RDS PostgreSQL | Database (db.t3.micro) | 750 hrs/month, 20GB storage |
| S3 | Frontend static files | 5GB storage, 20k GET requests |
| CloudFront | CDN for frontend | 1TB transfer/month |
| ECR | Docker image registry | 500MB/month |
| GitHub Actions | CI/CD | 2000 min/month (public repos: unlimited) |
| Grafana Cloud | Metrics + logs monitoring | 10k metrics, 50GB logs/month |
| Sentry | Error tracking | 5k errors/month |

Estimated monthly AWS cost for a solo project: **$0–$5** (staying within free tier).

---

## How Project Memory Works (.sde/ Directory)

Every project gets a `.sde/` directory committed to git. This is how the plugin maintains context across sessions:

```
.sde/
├── context.json              ← Project metadata: name, type, currentPhase, githubRepo, notionPageId
├── phases/
│   ├── 0-idea.md             ← Phase outputs — each skill reads prior phases before acting
│   ├── 1-prd.md
│   ├── 2-architecture.md
│   └── ...
├── adr/
│   ├── ADR-001-architecture-pattern.md   ← Architecture Decision Records
│   ├── ADR-002-auth-strategy.md
│   └── ADR-003-caching-strategy.md
└── schemas/
    ├── database.sql           ← Generated DDL schema
    └── openapi.yaml           ← Generated OpenAPI 3.0 spec
```

**Starting a new session on an existing project:**
Run `/sde` in the project root → the plugin reads `context.json` and shows you the dashboard with all phases and their completion status.

---

## Branch Strategy

| Branch | Purpose | Protected? |
|--------|---------|------------|
| `main` | Production | Yes (no direct push) |
| `develop` | Integration branch | No |
| `feature/N-*` | Phase work (e.g., `feature/4-auth-module`) | No |
| `hotfix/*` | Urgent production fixes | No |

---

## Commit Format

All commits follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat:     New feature
fix:      Bug fix
docs:     Documentation changes
refactor: Code refactoring (no behavior change)
test:     Adding or updating tests
chore:    Build, tooling, or config changes
ci:       CI/CD pipeline changes
perf:     Performance improvements
security: Security fixes
```

---

## Phase Gate Protocol

Every phase ends with an interactive gate:

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE N COMPLETE — Phase Name                ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY: [what was produced]             ║
╠══════════════════════════════════════════════════╣
║  SAVED: [files, Notion, Git]                     ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase N+1 — Next Phase Name               ║
╠══════════════════════════════════════════════════╣
║  [proceed] → start next phase immediately        ║
║  [refine]  → redo this phase with improvements   ║
║  [custom]  → type what you want to change        ║
╚══════════════════════════════════════════════════╝
```

- **proceed** — immediately starts the next phase
- **refine** — re-runs the current phase with improvements
- **custom: [text]** — applies a specific change and re-runs

---

## Templates Directory

The `templates/` directory contains reference files that skills use when generating project files:

```
templates/
├── github-actions/
│   ├── ci.yml             ← CI pipeline: lint, typecheck, test, build (parallel jobs)
│   ├── cd-prod.yml        ← CD pipeline: ECR push + EC2 SSH deploy on main push
│   └── security-audit.yml ← Daily dependency audit + secrets scan
├── docker/
│   ├── Dockerfile.backend  ← Multi-stage: Alpine builder + slim production image
│   ├── Dockerfile.frontend ← Multi-stage: Vite builder + Nginx Alpine server
│   └── docker-compose.yml  ← Local dev: postgres + redis + backend + frontend
└── k3s/
    ├── deployment.yaml    ← K3s Deployment with rolling updates and resource limits
    └── service.yaml       ← K3s Services (ClusterIP + LoadBalancer)
```

---

## Plugin Architecture

This plugin uses **Option A** (standalone repo with install script):

1. Skills live in `~/Documents/sde-plugin/skills/*.md`
2. `install.sh` creates symlinks: `~/.claude/skills/sde*.md → skills/*.md`
3. Claude Code loads all `.md` files from `~/.claude/skills/` at startup
4. Each skill file has YAML frontmatter (`name:`, `description:`) that Claude Code uses for skill discovery
5. When you type `/sde-idea`, Claude Code loads the skill file and follows its instructions

---

## Contributing

This plugin is designed for a specific solo developer workflow. To adapt it:

1. Edit skill files in `skills/` — they are plain Markdown with instructions
2. Update `templates/` for different infrastructure preferences
3. Run `bash install.sh` after changes — it updates the symlinks automatically

To add a new skill:
1. Create `skills/sde-[name].md` with frontmatter and instructions
2. Run `bash install.sh`
3. Use it as `/sde-[name]` in Claude Code

---

## Troubleshooting

**Skills not found in Claude Code:**
```bash
ls ~/.claude/skills/ | grep sde   # Should show 18 files
bash ~/Documents/sde-plugin/install.sh  # Re-run installer
```

**GitHub API errors:**
```bash
# Verify token works
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user
# Should return your GitHub user JSON
```

**Notion API errors:**
```bash
# Verify integration token
curl -H "Authorization: Bearer $NOTION_TOKEN" \
     -H "Notion-Version: 2022-06-28" \
     https://api.notion.com/v1/users/me
# Check database is shared with your integration
```

**Re-run setup:**
```bash
/sde-config   # Re-verifies all environment variables and integrations
```
