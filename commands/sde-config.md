---
description: One-time setup skill — verifies all environment variables, configures GitHub and Notion integrations, creates plugin config file, and validates the full toolchain.
allowed-tools: Read, Write, Bash, Agent
disable-model-invocation: true
---

# SDE Config — One-Time Setup

Run this skill ONCE before starting your first project. It validates all integrations, creates config files, and ensures the environment is ready.

---

## Step 1: Check All Environment Variables

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

For each missing variable, show where to get it:

- **NOTION_TOKEN** → https://www.notion.so/my-integrations → New integration (Internal) → copy token → `export NOTION_TOKEN="secret_..."`
- **NOTION_DATABASE_ID** → Create a full-page Notion database → share with your integration → copy 32-char ID from URL → `export NOTION_DATABASE_ID="..."`
- **GITHUB_TOKEN** → https://github.com/settings/tokens → classic token → scopes: `repo`, `workflow`, `read:user` → `export GITHUB_TOKEN="ghp_..."`
- **SENTRY_DSN** → https://sentry.io (free) → New project (Node.js) → Settings → SDK Setup → copy DSN → `export SENTRY_DSN="https://..."`
- **GRAFANA_CLOUD_PUSH_URL** → https://grafana.com (free) → stack Details → Prometheus Remote Write Endpoint → `export GRAFANA_CLOUD_PUSH_URL="https://prometheus-prod-....grafana.net/api/prom/push"`
- **GRAFANA_CLOUD_API_KEY** → Grafana Cloud portal → API Keys → create with "MetricsPublisher" role → `export GRAFANA_CLOUD_API_KEY="glc_..."`

If ALL variables are missing, output all instructions and stop. Ask user to set them and re-run `/sde-config`.

---

## Step 2: Verify GitHub Token

```bash
curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user
```

- `login` present → `GitHub: ✅ Authenticated as @[login]`
- 401/error → `GitHub: ❌ Token invalid. Regenerate at https://github.com/settings/tokens`

Verify scopes:
```bash
curl -sI -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user | grep x-oauth-scopes
```
Required: `repo`, `workflow`. Show which are missing if any.

---

## Step 3: Verify Notion Integration

```bash
curl -s -H "Authorization: Bearer $NOTION_TOKEN" \
     -H "Notion-Version: 2022-06-28" \
     https://api.notion.com/v1/users/me
```

- Success → `Notion: ✅ Connected as [name]`
- Fail → show error and fix instructions

```bash
curl -s -H "Authorization: Bearer $NOTION_TOKEN" \
     -H "Notion-Version: 2022-06-28" \
     "https://api.notion.com/v1/databases/$NOTION_DATABASE_ID"
```

- 200 → `Notion DB: ✅ Database accessible`
- 404 → `Notion DB: ❌ Not found. Check NOTION_DATABASE_ID`
- 403 → `Notion DB: ❌ No access. Share database with your integration first`

---

## Step 4: Configure Notion Database Properties

Ensure the Projects database has these properties (add via API if missing):
`Name` (title), `Type` (select: web-only/web+mobile/web+mobile+admin/existing), `Phase` (number), `Status` (select: Planning/In Progress/Testing/Production/Archived), `GitHubURL` (url), `Created` (created_time)

```bash
curl -s -X PATCH \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  "https://api.notion.com/v1/databases/$NOTION_DATABASE_ID" \
  -d '{
    "properties": {
      "Type": {"select": {"options": [{"name": "web-only", "color": "blue"}, {"name": "web+mobile", "color": "green"}, {"name": "web+mobile+admin", "color": "purple"}, {"name": "existing", "color": "orange"}]}},
      "Phase": {"number": {"format": "number"}},
      "Status": {"select": {"options": [{"name": "Planning", "color": "yellow"}, {"name": "In Progress", "color": "blue"}, {"name": "Testing", "color": "orange"}, {"name": "Production", "color": "green"}, {"name": "Archived", "color": "gray"}]}},
      "GitHubURL": {"url": {}},
      "Created": {"created_time": {}}
    }
  }'
```

Show: `Notion DB: ✅ Properties configured`

---

## Step 5: Check Docker

```bash
docker info --format '{{.ServerVersion}}' 2>/dev/null
docker compose version 2>/dev/null || docker-compose version 2>/dev/null
```

- Present → `Docker: ✅ Running (version [X.X.X])`
- Missing → `Docker: ❌ Not running. Start Docker Desktop or install Docker`

---

## Step 6: Create Plugin Config File

```bash
mkdir -p ~/.sde-plugin
cat > ~/.sde-plugin/config.json << 'EOF'
{
  "version": "1.0.0",
  "installedAt": "[ISO timestamp]",
  "defaultStack": {
    "backend": "nestjs", "frontend": "react", "database": "postgresql",
    "cache": "redis", "mobile": "expo", "auth": "jwt-passport"
  },
  "integrations": {
    "github": "[authenticated / missing]", "notion": "[connected / missing]",
    "sentry": "[configured / missing]", "grafana": "[configured / missing]",
    "docker": "[running / not-running]"
  },
  "aws": {"region": "us-east-1", "ec2Type": "t2.micro", "rdsEngine": "postgres", "rdsVersion": "16"},
  "coverage": {"minimum": 80},
  "autonomy": "full"
}
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
║  SETUP COMPLETE — Ready to build!                            ║
║                                                              ║
║  Next Steps:                                                 ║
║  1. Navigate to your project directory (or empty folder)     ║
║  2. Run /sde-idea and describe your product idea             ║
║  3. The SDE team will handle the rest                        ║
╚══════════════════════════════════════════════════════════════╝
```

If any integration is ❌: `⚠️ SETUP INCOMPLETE — Fix the issues above and re-run /sde-config`

---

## Notes

- Idempotent — safe to re-run after adding new environment variables
- `~/.sde-plugin/config.json` is global; each project's `.sde/context.json` is local
