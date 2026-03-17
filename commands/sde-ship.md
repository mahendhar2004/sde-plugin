---
description: Quick ship — runs tests → security check → code review → commit → push → create PR in a single command. Use after finishing a feature to ship it properly.
allowed-tools: Agent, Bash, Read
disable-model-invocation: true
---

# SDE Plugin — Ship It

One command to go from written code to a proper PR. Runs all quality gates automatically.

## When to Use
- You've finished writing a feature or fix
- You want to commit and create a PR without running each step manually
- You want all quality checks to run before your code gets reviewed

## What It Does (in order)

### 1. Understand What Changed
```bash
git status
git diff --stat HEAD
git diff HEAD
```
Show a summary: "You've changed N files in [module]. Here's what I see..."

### 2. Run Tests
```bash
cd backend && npm test -- --forceExit --passWithNoTests
cd frontend && npm test -- --passWithNoTests
```
If tests fail → show the failures and offer to fix them before proceeding. Do not continue with failing tests.

### 3. Check Coverage (quick)
```bash
cd backend && npm test -- --coverage --coverageReporters=text-summary --forceExit
```
If coverage dropped below 80% → identify uncovered new code and write tests for it.

### 4. Security Quick-Scan
Read `~/.sde-plugin/context/security-rules.md` and scan only the changed files for:
- Any new endpoints without `@UseGuards`
- Any new DTOs missing class-validator decorators
- Any new user-controlled inputs without validation
- Any hardcoded secrets or credentials

If issues found → fix them automatically.

### 5. Code Quality Quick-Scan
Scan changed files for:
- `console.log` statements → remove
- `any` types → fix with proper types
- Functions > 30 lines → flag (don't auto-fix, too risky)
- Missing return types → add

### 6. Smart Commit

Analyze the changes and generate the conventional commit message:

```
Type detection:
  - New files + new functionality  → feat
  - Modified existing, bug fixed   → fix
  - Tests only                     → test
  - Config/deps                    → chore
  - Only docs                      → docs
  - Performance improvement        → perf

Scope: infer from which module/directory changed

Message: describe WHAT changed and WHY (not HOW)
```

Show the commit message before committing:
```
Proposed commit:
  feat(auth): add email verification on registration

  Users now receive a verification email after registering.
  Unverified accounts cannot log in until email is confirmed.

Confirm? [y] or describe changes needed:
```

Wait for confirmation, then:
```bash
git add [specific changed files — never -A unless confirmed]
git commit -m "[generated message]"
git push origin [current-branch]
```

### 7. Create Pull Request

Determine target branch:
- If on `feature/*` → target `develop`
- If on `hotfix/*` → target `main`
- Otherwise → target `develop`

Generate PR description from commits:
```bash
curl -X POST https://api.github.com/repos/$OWNER/$REPO/pulls \
  -H "Authorization: token $GITHUB_TOKEN" \
  -d "{
    \"title\": \"[commit message]\",
    \"body\": \"## Summary\n[bullet points of what changed]\n\n## Test Plan\n- [ ] Unit tests passing\n- [ ] Integration tests passing\n- [ ] Manually verified: [describe]\n\n## Checklist\n- [ ] Tests pass\n- [ ] Coverage maintained at 80%+\n- [ ] No console.log in code\n- [ ] .env.example updated (if new env vars)\",
    \"head\": \"[current-branch]\",
    \"base\": \"[target-branch]\"
  }"
```

---

## Output Format

```
╔══════════════════════════════════════════════════╗
║  🚢 SHIPPING — [branch-name]                     ║
╠══════════════════════════════════════════════════╣
║  QUALITY GATES:                                  ║
║  ✅ Tests passing (backend: X/X, frontend: X/X) ║
║  ✅ Coverage: XX% (min 80%)                      ║
║  ✅ Security: clean                              ║
║  ✅ Code quality: clean                          ║
╠══════════════════════════════════════════════════╣
║  COMMITTED:                                      ║
║  feat(auth): add email verification              ║
╠══════════════════════════════════════════════════╣
║  PR CREATED:                                     ║
║  → github.com/user/repo/pull/[N]                ║
╠══════════════════════════════════════════════════╣
║  [proceed] → done, close                         ║
║  [review]  → run /sde-review on this PR          ║
║  [custom]  → describe what to change             ║
╚══════════════════════════════════════════════════╝
```

---

## If Any Gate Fails

Tests fail → show failures, ask: fix automatically or fix manually?
Coverage drops → write the missing tests, then continue
Security issues → fix and continue
Quality issues → fix and continue

Never skip a failing gate. The whole point of /sde-ship is that what gets shipped is clean.
