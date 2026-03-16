---
name: sde-config
description: One-time setup skill — verifies all environment variables, configures GitHub and Notion integrations, creates plugin config file, and validates the full toolchain.
---

# SDE Config — One-Time Setup

Run this skill ONCE before starting your first project. It validates all integrations, creates config files, and ensures the environment is ready.

---

## Step 1: Check All Environment Variables

Check for the presence of each required variable and display status:

```
╔══════════════════════════════════════════════════════════════╗
║  SDE PLUGIN — Environment Check                              ║
╠══════════════════════════════════════════════════════════════╣
║  NOTION_TOKEN            [SET ✅ / MISSING ❌]               ║
║  NOTION_DATABASE_ID      [SET ✅ / MISSING ❌]               ║
║  GITHUB_TOKEN            [SET ✅ / MISSING ❌]               ║
║  SENTRY_DSN              [SET ✅ / MISSING ❌]               ║
║  GRAFANA_CLOUD_PUSH_URL  [SET ✅ / MISSING ❌]               ║
║  GRAFANA_CLOUD_API_KEY   [SET ✅ / MISSING ❌]               ║
╚══════════════════════════════════════════════════════════════╝
```

For EACH missing variable, show exactly where to get it:

**NOTION_TOKEN missing:**
```
To get NOTION_TOKEN:
1. Go to https://www.notion.so/my-integrations
2. Click "+ New integration"
3. Name: "SDE Plugin", Type: Internal
4. Copy the "Internal Integration Token"
5. export NOTION_TOKEN="secret_..."
```

**NOTION_DATABASE_ID missing:**
```
To get NOTION_DATABASE_ID:
1. Create a Notion database (full page, not inline)
2. Share it with your integration (click Share → Invite → your integration)
3. Copy the database ID from the URL:
   https://www.notion.so/[workspace]/[DATABASE_ID]?v=...
4. export NOTION_DATABASE_ID="[32-character ID]"
```

**GITHUB_TOKEN missing:**
```
To get GITHUB_TOKEN:
1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Name: "SDE Plugin"
4. Scopes needed: repo (full), workflow, read:user
5. Copy the token
6. export GITHUB_TOKEN="ghp_..."
```

**SENTRY_DSN missing:**
```
To get SENTRY_DSN:
1. Go to https://sentry.io and sign up (free tier)
2. Create a new project → Node.js (for backend)
3. Go to Settings → Projects → [project] → SDK Setup
4. Copy the DSN URL
5. export SENTRY_DSN="https://...@....ingest.sentry.io/..."
```

**GRAFANA_CLOUD_PUSH_URL missing:**
```
To get GRAFANA_CLOUD_PUSH_URL:
1. Go to https://grafana.com/auth/sign-up (free tier: 10k metrics, 50GB logs)
2. After login → go to your stack → "Details"
3. Prometheus section → copy the Remote Write Endpoint
4. export GRAFANA_CLOUD_PUSH_URL="https://prometheus-prod-...grafana.net/api/prom/push"
```

**GRAFANA_CLOUD_API_KEY missing:**
```
To get GRAFANA_CLOUD_API_KEY:
1. In Grafana Cloud portal → go to your org
2. Click your username → API Keys
3. Create key with "MetricsPublisher" role
4. export GRAFANA_CLOUD_API_KEY="glc_..."
```

If ALL variables are missing, output all instructions above and stop. Ask user to set them and re-run `/sde-config`.

---

## Step 2: Verify GitHub Token

Run API verification:
```bash
curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user
```

Parse the response:
- If `login` field present → show: `GitHub: ✅ Authenticated as @[login]`
- If error/401 → show: `GitHub: ❌ Token invalid or expired. Regenerate at https://github.com/settings/tokens`

Also verify required scopes:
```bash
curl -sI -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | grep x-oauth-scopes
```
Required scopes: `repo`, `workflow`. If missing, show which scopes to add.

---

## Step 3: Verify Notion Integration

Test Notion API access:
```bash
curl -s -H "Authorization: Bearer $NOTION_TOKEN" \
     -H "Notion-Version: 2022-06-28" \
     https://api.notion.com/v1/users/me
```

- If successful → show: `Notion: ✅ Connected as [name]`
- If failed → show error details and fix instructions

Test database access:
```bash
curl -s -H "Authorization: Bearer $NOTION_TOKEN" \
     -H "Notion-Version: 2022-06-28" \
     "https://api.notion.com/v1/databases/$NOTION_DATABASE_ID"
```

- If 200 → show: `Notion DB: ✅ Database accessible`
- If 404 → `Notion DB: ❌ Database not found. Check NOTION_DATABASE_ID`
- If 403 → `Notion DB: ❌ No access. Share database with your integration first`

---

## Step 4: Set Up Notion Database Structure

If database exists but properties are missing, add them via API:

The Projects database needs these properties:
```
Name        → title (default, already exists)
Type        → select (options: web-only, web+mobile, web+mobile+admin, existing)
Phase       → number (format: number)
Status      → select (options: Planning, In Progress, Testing, Production, Archived)
GitHubURL   → url
Created     → created_time
```

Update database properties:
```bash
curl -s -X PATCH \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  "https://api.notion.com/v1/databases/$NOTION_DATABASE_ID" \
  -d '{
    "properties": {
      "Type": {
        "select": {
          "options": [
            {"name": "web-only", "color": "blue"},
            {"name": "web+mobile", "color": "green"},
            {"name": "web+mobile+admin", "color": "purple"},
            {"name": "existing", "color": "orange"}
          ]
        }
      },
      "Phase": {"number": {"format": "number"}},
      "Status": {
        "select": {
          "options": [
            {"name": "Planning", "color": "yellow"},
            {"name": "In Progress", "color": "blue"},
            {"name": "Testing", "color": "orange"},
            {"name": "Production", "color": "green"},
            {"name": "Archived", "color": "gray"}
          ]
        }
      },
      "GitHubURL": {"url": {}},
      "Created": {"created_time": {}}
    }
  }'
```

Show: `Notion DB: ✅ Properties configured`

---

## Step 5: Check Docker

Run:
```bash
docker info --format '{{.ServerVersion}}' 2>/dev/null
```

- If output present → `Docker: ✅ Running (version [X.X.X])`
- If not found → `Docker: ❌ Not running. Start Docker Desktop or install Docker`

Also check docker-compose:
```bash
docker compose version 2>/dev/null || docker-compose version 2>/dev/null
```

---

## Step 6: Create Plugin Config File

Create `~/.sde-plugin/config.json`:
```json
{
  "version": "1.0.0",
  "installedAt": "[ISO timestamp]",
  "defaultStack": {
    "backend": "nestjs",
    "frontend": "react",
    "database": "postgresql",
    "cache": "redis",
    "mobile": "expo",
    "auth": "jwt-passport"
  },
  "integrations": {
    "github": "[authenticated / missing]",
    "notion": "[connected / missing]",
    "sentry": "[configured / missing]",
    "grafana": "[configured / missing]",
    "docker": "[running / not-running]"
  },
  "aws": {
    "region": "us-east-1",
    "ec2Type": "t2.micro",
    "rdsEngine": "postgres",
    "rdsVersion": "16"
  },
  "coverage": {
    "minimum": 80
  },
  "autonomy": "full"
}
```

```bash
mkdir -p ~/.sde-plugin
cat > ~/.sde-plugin/config.json << 'EOF'
{ ... }
EOF
```

Show: `Config: ✅ Created at ~/.sde-plugin/config.json`

---

## Step 7: Show Setup Summary

```
╔══════════════════════════════════════════════════════════════╗
║  SDE PLUGIN — Setup Summary                                  ║
╠══════════════════════════════════════════════════════════════╣
║  Environment Variables:                                      ║
║    NOTION_TOKEN            ✅                                ║
║    NOTION_DATABASE_ID      ✅                                ║
║    GITHUB_TOKEN            ✅                                ║
║    SENTRY_DSN              ✅                                ║
║    GRAFANA_CLOUD_PUSH_URL  ✅                                ║
║    GRAFANA_CLOUD_API_KEY   ✅                                ║
╠══════════════════════════════════════════════════════════════╣
║  Integrations:                                               ║
║    GitHub     ✅  @username                                  ║
║    Notion     ✅  Connected                                  ║
║    Notion DB  ✅  Properties configured                      ║
║    Docker     ✅  Running                                    ║
║    Sentry     ✅  DSN set                                    ║
║    Grafana    ✅  Credentials set                            ║
╠══════════════════════════════════════════════════════════════╣
║  Config: ~/.sde-plugin/config.json ✅                        ║
╠══════════════════════════════════════════════════════════════╣
║  🎉 SETUP COMPLETE — Ready to build!                        ║
║                                                              ║
║  Next Steps:                                                 ║
║  1. Navigate to your project directory (or empty folder)     ║
║  2. Run /sde-idea and describe your product idea             ║
║  3. The SDE team will handle the rest                        ║
╚══════════════════════════════════════════════════════════════╝
```

If any integration is ❌, do NOT show "SETUP COMPLETE". Instead show:
```
⚠️  SETUP INCOMPLETE — Fix the issues above and re-run /sde-config
```

---

## Notes

- This skill is idempotent — safe to run multiple times
- Re-run after adding new environment variables
- Config file at `~/.sde-plugin/config.json` is global (not per-project)
- Each project's `.sde/context.json` is project-local
