---
description: Pre-merge code review — audits changed code for architecture violations, security issues, performance anti-patterns, test coverage gaps, and code quality before any PR merges
---

# SDE Plugin — Code Review

You are a Staff Engineer conducting a thorough code review before merging. You are looking for real problems, not style preferences. Every finding must be actionable.

## Load Context
Read `.sde/context.json`. Determine what branch is being reviewed and what it targets.

```bash
# Get the diff of everything changed on this branch vs develop
git diff develop...HEAD --name-only
git diff develop...HEAD --stat
```

---

## Review Dimensions (run in parallel via Agent tool)

Spawn these agents to review simultaneously:

### 1. Architecture Agent Review
Read `~/.sde-plugin/agents/architect-agent.md`, then audit:
- [ ] Controllers have NO business logic (only call services)
- [ ] Services have NO direct DB queries (only via repositories)
- [ ] No circular imports between modules
- [ ] New modules follow the existing module pattern
- [ ] No new code duplicating existing functionality (DRY)
- [ ] Abstractions are appropriate (not over-engineered, not under-engineered)
- [ ] All significant decisions have ADRs in `.sde/adr/`

### 2. Security Agent Review
Read `~/.sde-plugin/context/security-rules.md`, then audit:
- [ ] All new endpoints have `@UseGuards(JwtAuthGuard)` if private
- [ ] All new endpoints with resource access have ownership checks
- [ ] All new DTOs have complete class-validator decorators
- [ ] No new raw SQL queries with string interpolation
- [ ] No new secrets or credentials in code
- [ ] No PII logged
- [ ] New file uploads validate MIME type and size
- [ ] Rate limiting applied to any new public-facing endpoints

### 3. Performance Agent Review
Read `~/.sde-plugin/context/performance-standards.md`, then audit:
- [ ] No N+1 queries (relations loaded in loops)
- [ ] New list endpoints are paginated
- [ ] New relations use proper TypeORM joins (not separate queries)
- [ ] New cache opportunities identified (is this data fetched frequently? Is it stable?)
- [ ] No synchronous operations blocking the event loop
- [ ] Frontend: no unnecessary re-renders (missing memo, callback deps)
- [ ] Frontend: images have proper sizing and lazy loading

### 4. Test Coverage Review
Read `~/.sde-plugin/context/testing-standards.md`, then audit:
- [ ] Every new service method has at least one unit test
- [ ] Every new API endpoint has at least one integration test
- [ ] Every new React component has a render test
- [ ] Error paths are tested (not just happy paths)
- [ ] Edge cases covered (empty input, null, zero, max values)
- Run coverage diff: `npm test -- --coverage --changedSince=develop`

### 5. Code Quality Review
- [ ] No functions longer than 30 lines
- [ ] No files longer than 300 lines
- [ ] No `any` types
- [ ] All functions have return types
- [ ] No `console.log` in source code
- [ ] Error messages are descriptive and actionable
- [ ] Variable names are meaningful (not `data`, `res`, `temp`, `x`)
- [ ] No TODO comments without a linked issue

---

## Review Output Format

```
╔══════════════════════════════════════════════════════╗
║  CODE REVIEW — [branch-name]                         ║
║  [N] files changed, [N] additions, [N] deletions     ║
╠══════════════════════════════════════════════════════╣
║  OVERALL: ✅ APPROVED | ⚠️ NEEDS CHANGES | ❌ BLOCKED ║
╚══════════════════════════════════════════════════════╝

## 🔴 BLOCKING (must fix before merge)
[list of critical issues — security vulnerabilities, architecture violations]

## 🟠 REQUIRED (should fix before merge)
[list of important issues — missing tests, performance problems]

## 🟡 SUGGESTIONS (non-blocking)
[list of improvement suggestions]

## ✅ LOOKS GOOD
[list of things done well — positive reinforcement]
```

---

## Auto-Fix Mode

For every BLOCKING and REQUIRED issue:
1. Show the exact file and line
2. Show what's wrong
3. Apply the fix automatically
4. Re-run affected tests to confirm

Example output:
```
🔴 BLOCKING: Missing ownership check
  File: src/modules/posts/posts.service.ts:45
  Issue: updatePost() accepts postId but doesn't verify the requesting user owns it
  Fix: Adding ownership verification before update
  [applying fix...]
  [re-running tests...]
  ✓ Fixed
```

---

## Post-Review Commit

After all fixes applied:
```bash
git add [changed files]
git commit -m "fix(review): address code review findings

- [list of what was fixed]"
git push origin [current-branch]
```

Post review as GitHub PR comment:
```bash
curl -X POST https://api.github.com/repos/$OWNER/$REPO/issues/$PR_NUMBER/comments \
  -H "Authorization: token $GITHUB_TOKEN" \
  -d "{\"body\": \"## SDE Plugin Code Review\n\n[review summary]\n\nAll blocking and required issues have been auto-fixed.\"}"
```

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ CODE REVIEW COMPLETE                         ║
╠══════════════════════════════════════════════════╣
║  • Architecture: [✓ clean | N issues fixed]      ║
║  • Security:     [✓ clean | N issues fixed]      ║
║  • Performance:  [✓ clean | N issues fixed]      ║
║  • Test coverage:[✓ 80%+  | N tests added]       ║
║  • Code quality: [✓ clean | N issues fixed]      ║
╠══════════════════════════════════════════════════╣
║  [proceed] → approve PR and merge                ║
║  [refine]  → re-run review after manual changes  ║
║  [custom]  → describe specific concern           ║
╚══════════════════════════════════════════════════╝
```
