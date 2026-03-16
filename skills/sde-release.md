---
name: sde-release
description: Release management — semantic versioning, CHANGELOG generation, GitHub release creation, version bumps across all package.json files, and production deployment trigger
---

# SDE Plugin — Release Management

You handle the complete release lifecycle: version determination → CHANGELOG → version bumps → GitHub release → production deploy trigger.

## Load Context
Read `.sde/context.json` for project name. Read git log since last tag for what's changed.

---

## Step 1 — Determine Release Type

Get all commits since last release:
```bash
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -z "$LAST_TAG" ]; then
  git log --pretty=format:"%s" | head -50
else
  git log ${LAST_TAG}..HEAD --pretty=format:"%s"
fi
```

Apply semantic versioning rules:
| Commit Type | Version Bump | Example |
|------------|-------------|---------|
| `BREAKING CHANGE` in any commit footer | **Major** (X.0.0) | API contract changed |
| `feat:` (new feature) | **Minor** (x.Y.0) | New endpoint, new screen |
| `fix:`, `perf:`, `security:`, `refactor:` | **Patch** (x.y.Z) | Bug fix, optimization |
| `docs:`, `chore:`, `ci:`, `style:`, `test:` | No bump (internal) | — |

Get current version:
```bash
node -p "require('./backend/package.json').version" 2>/dev/null || \
node -p "require('./package.json').version" 2>/dev/null || echo "0.0.0"
```

Calculate new version and show:
```
Current version: v1.3.2
Commits since last release: 12
  2 feat: → minor bump
  4 fix:  → patch bump
  1 perf: → patch bump
New version: v1.4.0 (minor bump — new features present)
```

---

## Step 2 — Generate CHANGELOG

Parse conventional commits into categorized CHANGELOG entry:

```markdown
## [1.4.0] — 2024-01-15

### 🚀 New Features
- feat(auth): add Google OAuth login support (#45)
- feat(users): add user profile picture upload (#47)

### 🐛 Bug Fixes
- fix(auth): fix refresh token not rotating on concurrent requests (#50)
- fix(orders): fix order total calculation for discounted items (#52)

### ⚡ Performance
- perf(db): add composite index on orders(user_id, status) (#49)

### 🔒 Security
- security(auth): enforce bcrypt rounds to 12 (#51)

### 🔧 Maintenance
- chore(deps): update NestJS to 10.3.2
- ci: add nightly security audit workflow
```

Prepend this to `CHANGELOG.md` (create if doesn't exist).

```bash
git add CHANGELOG.md
git commit -m "docs: update CHANGELOG for v[X.Y.Z]"
```

---

## Step 3 — Bump Version in All package.json Files

```bash
# Update all package.json files with new version
for pkg in package.json backend/package.json frontend/package.json mobile/package.json admin/package.json; do
  [ -f "$pkg" ] && node -e "
    const fs = require('fs');
    const pkg = JSON.parse(fs.readFileSync('$pkg', 'utf8'));
    pkg.version = '[NEW_VERSION]';
    fs.writeFileSync('$pkg', JSON.stringify(pkg, null, 2) + '\n');
    console.log('Updated $pkg to [NEW_VERSION]');
  "
done
```

```bash
git add */package.json package.json 2>/dev/null
git commit -m "chore: bump version to v[X.Y.Z]"
```

---

## Step 4 — Create Release Branch and Merge to Main

```bash
# Ensure develop is up to date
git checkout develop && git pull origin develop

# Create release branch
git checkout -b release/v[X.Y.Z]
git push origin release/v[X.Y.Z]
```

Create PR: release/v[X.Y.Z] → main via GitHub API:
```bash
curl -X POST https://api.github.com/repos/$OWNER/$REPO/pulls \
  -H "Authorization: token $GITHUB_TOKEN" \
  -d "{
    \"title\": \"Release v[X.Y.Z]\",
    \"body\": \"## Release v[X.Y.Z]\n\n$(cat CHANGELOG.md | head -40)\n\n## Pre-release Checklist\n- [ ] All CI checks passing\n- [ ] CHANGELOG updated\n- [ ] Version bumped in all package.json files\n- [ ] Production deploy tested on staging\",
    \"head\": \"release/v[X.Y.Z]\",
    \"base\": \"main\"
  }"
```

After CI passes and PR merges to main:

---

## Step 5 — Tag and Create GitHub Release

```bash
git checkout main && git pull origin main
git tag -a v[X.Y.Z] -m "Release v[X.Y.Z]"
git push origin v[X.Y.Z]
```

Create GitHub Release:
```bash
CHANGELOG_BODY=$(awk '/^## \[/{if(p)exit; p=1} p' CHANGELOG.md | tail -n +2)

curl -X POST https://api.github.com/repos/$OWNER/$REPO/releases \
  -H "Authorization: token $GITHUB_TOKEN" \
  -d "{
    \"tag_name\": \"v[X.Y.Z]\",
    \"target_commitish\": \"main\",
    \"name\": \"v[X.Y.Z]\",
    \"body\": \"$CHANGELOG_BODY\",
    \"draft\": false,
    \"prerelease\": false
  }"
```

---

## Step 6 — Merge Back to Develop

```bash
git checkout develop
git merge main --no-ff -m "chore: merge release v[X.Y.Z] back to develop"
git push origin develop
```

---

## Step 7 — Update Notion

Update the project page in Notion:
- Set `Phase` property to `Released`
- Set `Version` to `v[X.Y.Z]`
- Add a release entry to the Sprint Board database

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ RELEASE v[X.Y.Z] COMPLETE                   ║
╠══════════════════════════════════════════════════╣
║  • Version: [X.Y.Z] ([major|minor|patch])        ║
║  • CHANGELOG.md updated                          ║
║  • All package.json files bumped                 ║
║  • GitHub Release created                        ║
║  • Tag v[X.Y.Z] pushed                           ║
║  • CD pipeline triggered                         ║
║  • Merged back to develop                        ║
║  • Notion project updated                        ║
╠══════════════════════════════════════════════════╣
║  [proceed] → close release                       ║
║  [custom]  → describe what to change             ║
╚══════════════════════════════════════════════════╝
```
