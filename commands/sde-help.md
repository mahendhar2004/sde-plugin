---
description: Command reference — shows all 30 SDE Plugin commands organized by category with descriptions and usage examples
allowed-tools: Read
disable-model-invocation: true
---

# SDE Plugin — Command Reference

Display this complete reference card immediately when invoked. No input needed.

---

Output exactly this:

```
╔══════════════════════════════════════════════════════════════════╗
║            SDE PLUGIN — COMPLETE COMMAND REFERENCE               ║
║         Staff Engineer Quality · From Idea to Production         ║
╚══════════════════════════════════════════════════════════════════╝

── SETUP & NAVIGATION ───────────────────────────────────────────────
  /sde            Project dashboard — resume any project, see phase status
  /sde-help       This reference card
  /sde-config     One-time setup (env vars, Notion, GitHub) — run first!

── 13-PHASE LIFECYCLE ───────────────────────────────────────────────
  /sde-idea       Phase 0  → Describe your product idea → project created
  /sde-prd        Phase 1  → Full PRD with user stories & acceptance criteria
  /sde-architect  Phase 2  → System architecture, diagrams, ADRs
  /sde-stack      Phase 3  → Tech stack decisions, package list
  /sde-datamodel  Phase 4  → Database schema, TypeORM entities, SQL DDL
  /sde-api        Phase 5  → REST API design + OpenAPI 3.0 spec
  /sde-scaffold   Phase 6  → Complete project structure + boilerplate
  /sde-implement  Phase 7  → Full code: backend + frontend + mobile + admin
  /sde-test       Phase 8  → Test suite: 80% coverage minimum
  /sde-secure     Phase 9  → OWASP Top 10 audit + auto-fix all issues
  /sde-optimize   Phase 10 → DB indexes, Redis caching, frontend perf
  /sde-devops     Phase 11 → Docker + GitHub Actions + AWS free tier
  /sde-prod       Phase 12 → Production checklist + rollback runbook
  /sde-iterate    Phase 13 → Continuous improvement loop

── QUICK ACTIONS (use anytime) ──────────────────────────────────────
  /sde-ship       → Implement → test → review → commit → PR in one command
  /sde-review     → Full code review before any PR merges
  /sde-debug      → Systematic debugging: error → root cause → fix → test
  /sde-hotfix     → Emergency production fix with regression test
  /sde-release    → Semantic versioning + CHANGELOG + GitHub release

── DOCUMENTATION ────────────────────────────────────────────────────
  /sde-docs       → JSDoc, README, docs/ folder, Notion sync
  /sde-seed       → Realistic seed data: dev / test / demo environments

── VERSION CONTROL ──────────────────────────────────────────────────
  /sde-vc         → Smart commits, branches, PRs, releases

── EXISTING CODEBASES ───────────────────────────────────────────────
  /sde-analyze          → Full audit: stack detection, issues, improvement plan
  /sde-supabase-review  → Audit Supabase schema, RLS policies, and security
  /sde-api-sync         → Check backend/frontend API contract sync

── LEARNING & STANDARDS ─────────────────────────────────────────────
  /sde-learn      → Your personalized learning profile (gets smarter over time)
  /sde-sde5       → Staff Engineer quality standards reference

── TYPICAL WORKFLOWS ────────────────────────────────────────────────

  NEW PROJECT (full lifecycle):
  /sde-config → /sde-idea → /sde-prd → /sde-architect → /sde-stack →
  /sde-datamodel → /sde-api → /sde-scaffold → /sde-implement →
  /sde-test → /sde-secure → /sde-optimize → /sde-devops →
  /sde-prod → /sde-iterate → /sde-release

  EXISTING PROJECT:
  /sde-analyze → /sde-secure → /sde-test → /sde-optimize → /sde-docs

  DAILY DEVELOPMENT:
  /sde-implement → /sde-test → /sde-review → /sde-ship

  EMERGENCY:
  /sde-debug → /sde-hotfix → /sde-release

  BEFORE CODE REVIEW:
  /sde-review

  RELEASE DAY:
  /sde-review → /sde-docs → /sde-release

── ENVIRONMENT VARIABLES NEEDED ─────────────────────────────────────
  NOTION_TOKEN            Notion integration token
  NOTION_DATABASE_ID      Notion projects database ID
  GITHUB_TOKEN            GitHub PAT (repo + workflow + packages)
  SENTRY_DSN              Sentry DSN (free tier)
  GRAFANA_CLOUD_PUSH_URL  Grafana Cloud remote write URL
  GRAFANA_CLOUD_API_KEY   Grafana Cloud API key

── PLUGIN FILES ──────────────────────────────────────────────────────
  Commands:   ~/.claude/commands/         (29 command files)
  Agents:     ~/.sde-plugin/agents/      (10 specialized agents)
  Context:    ~/.sde-plugin/context/     (7 standards files)
  References: ~/.sde-plugin/references/  (4 pattern files)
  Learnings:  ~/.sde-plugin-data/        (adaptive personalization)
  Repo:       ~/Documents/sde-plugin/    (git, update with git pull)

── UPDATE PLUGIN ─────────────────────────────────────────────────────
  cd ~/Documents/sde-plugin && git pull && bash install.sh

╚══════════════════════════════════════════════════════════════════╝
```
