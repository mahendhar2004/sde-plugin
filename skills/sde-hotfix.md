---
name: sde-hotfix
description: Emergency production fix — fast-track workflow from bug detection to hotfix deployed, tagged, and merged back to all branches in under 30 minutes
---

# SDE Plugin — Hotfix: Emergency Production Fix

You are executing an emergency production hotfix. Speed matters but correctness matters more. A bad hotfix is worse than a delayed one.

## Hotfix vs Normal Fix
- **Hotfix:** Critical production bug, security vulnerability, or data integrity issue. Ships directly from `main`, bypasses develop. Use this skill.
- **Normal fix:** Non-critical issue. Use the normal phase workflow. Do NOT use this skill.

## Pre-Flight (Run First)
```bash
# Verify current state
git status
git log --oneline -5
git branch -a | grep hotfix
```

Load `.sde/context.json` for project metadata.

---

## Step 1 — Understand the Emergency

Ask user (if not already described):
1. What is the exact bug/error? (error message, stack trace, screenshots)
2. What is the impact? (all users affected? data loss? security breach?)
3. When did it start? (after last deploy? always? specific trigger?)
4. Is there a workaround? (can we disable a feature vs fix the code?)

Classify severity:
| Level | Criteria | Target Fix Time |
|-------|---------|----------------|
| SEV-1 | Data loss, security breach, full outage | 15 min |
| SEV-2 | Major feature broken for all users | 30 min |
| SEV-3 | Feature broken for some users | 1 hour |

---

## Step 2 — Create Hotfix Branch from Main

```bash
git checkout main
git pull origin main
git checkout -b hotfix/[short-description]   # e.g., hotfix/fix-auth-token-expiry
```

**CRITICAL:** Always branch from `main`, never from `develop`. Hotfix goes directly to production.

---

## Step 3 — Diagnose Root Cause

Before writing any code, confirm the root cause:
1. Read the relevant source files
2. Reproduce the issue locally (write a failing test first)
3. Identify the exact line(s) causing the problem
4. Confirm the fix will not break anything else

Failing test first:
```typescript
it('reproduces production bug: [description]', async () => {
  // This test should FAIL before the fix and PASS after
  const result = await service.buggyMethod(problematicInput);
  expect(result).toBe(expectedValue); // currently returns wrong value
});
```

---

## Step 4 — Apply the Minimal Fix

Apply the smallest possible change that fixes the problem:
- Fix only what is broken
- Do not refactor surrounding code
- Do not add new features
- Do not change unrelated behavior

Commit:
```bash
git add [specific files only — never git add .]
git commit -m "fix([scope]): [description of what was wrong and what was fixed]

HOTFIX: [one sentence explaining the production impact]
Root cause: [one sentence explaining why this happened]
Closes: #[issue number if applicable]"
```

---

## Step 5 — Run Tests

```bash
cd backend && npm test -- --forceExit
cd frontend && npm test
```

**If any test fails:** Do NOT proceed. Fix the test failure first. A hotfix that breaks tests cannot ship.

Run the specific regression test:
```bash
npm test -- --testNamePattern="reproduces production bug"
```

It must now PASS.

---

## Step 6 — Push and Deploy

```bash
git push origin hotfix/[description]
```

Create PR via GitHub API: hotfix branch → main (NOT develop):
```bash
curl -X POST https://api.github.com/repos/$OWNER/$REPO/pulls \
  -H "Authorization: token $GITHUB_TOKEN" \
  -d "{
    \"title\": \"🚨 HOTFIX: [description]\",
    \"body\": \"## Emergency Hotfix\\n\\n**Severity:** SEV-[N]\\n**Impact:** [description]\\n**Root Cause:** [description]\\n**Fix:** [description]\\n\\n## Test Evidence\\n- [ ] Regression test added and passing\\n- [ ] All existing tests passing\\n- [ ] Manually verified fix in local environment\",
    \"head\": \"hotfix/[description]\",
    \"base\": \"main\",
    \"labels\": [\"hotfix\", \"urgent\"]
  }"
```

If CI passes, merge immediately. Trigger production deployment.

Post-deploy verification:
```bash
# Check health endpoint
curl -f https://[your-domain]/health

# Check error rate in Sentry — should drop within 2 minutes
# Check Grafana — error rate metric should normalize
```

---

## Step 7 — Create Patch Release

After merging to main:
```bash
# Determine patch version (e.g., v1.2.3 → v1.2.4)
git tag -a v[X.Y.Z+1] -m "Hotfix v[X.Y.Z+1]: [description]"
git push origin v[X.Y.Z+1]
```

Create GitHub release:
```bash
curl -X POST https://api.github.com/repos/$OWNER/$REPO/releases \
  -H "Authorization: token $GITHUB_TOKEN" \
  -d "{
    \"tag_name\": \"v[X.Y.Z+1]\",
    \"name\": \"v[X.Y.Z+1] — Hotfix\",
    \"body\": \"## Hotfix Release\\n\\n**Problem:** [description]\\n**Fix:** [description]\\n**Impact:** [who was affected]\",
    \"prerelease\": false
  }"
```

---

## Step 8 — Merge Back to Develop

```bash
git checkout develop
git pull origin develop
git merge main --no-ff -m "chore: merge hotfix v[X.Y.Z+1] back to develop"
git push origin develop
```

**Do not skip this step.** If hotfix is not merged back to develop, the bug will reappear in the next release.

---

## Step 9 — Post-Mortem (Notion)

Create a Notion page under the project: "Incident Report — [date]"

Template:
```
## Incident Report
Date: [ISO date]
Severity: SEV-[N]
Duration: [how long the bug was in production]

## Timeline
- [time]: Bug introduced (which deploy/commit)
- [time]: Bug detected (how — user report, alert, error spike)
- [time]: Investigation started
- [time]: Root cause identified
- [time]: Fix deployed
- [time]: Incident resolved

## Root Cause
[Technical explanation]

## Impact
[Number of users affected, data impact, revenue impact if known]

## Fix Applied
[What changed and why]

## Prevention
[What process/test/monitoring change prevents this class of bug in future]
```

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ HOTFIX COMPLETE                              ║
╠══════════════════════════════════════════════════╣
║  • Fix applied and verified                      ║
║  • Regression test added                         ║
║  • Deployed to production                        ║
║  • Patch release tagged                          ║
║  • Merged back to develop                        ║
║  • Incident report created in Notion             ║
╠══════════════════════════════════════════════════╣
║  [proceed] → close incident                      ║
║  [custom]  → describe what's still needed        ║
╚══════════════════════════════════════════════════╝
```
