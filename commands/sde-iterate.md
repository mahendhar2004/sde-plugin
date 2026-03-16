---
description: Phase 13 — Iterative Improvement. Systematically analyzes the entire codebase for architecture issues, code quality, test coverage gaps, performance bottlenecks, and security weaknesses. Fixes all Critical and High findings autonomously.
---

# SDE Iterate — Phase 13: Iterative Improvement

## Overview

This phase runs a full codebase analysis and improvement cycle. It can be run repeatedly — each iteration improves quality. After every run, you get the option to run another iteration.

---

## Analysis Categories

### 1. Architecture Review

**Check for circular dependencies:**
```bash
# Install madge if not present
npx madge --circular --extensions ts backend/src/
npx madge --circular --extensions ts,tsx frontend/src/
```

For each circular dependency found:
- Map the dependency chain: A → B → C → A
- Break the cycle by:
  - Extracting shared interface/type to a common module
  - Using dependency injection instead of direct imports
  - Moving the shared logic to a lower-level module

**Check for SRP violations (services doing too much):**
- Count methods per service. If > 10 methods: likely violates SRP
- Check if service mixes: data access + business logic + external API calls
- Fix: Extract focused service classes (e.g., split `UserService` into `UserService + UserAuthService + UserProfileService`)

**Check for direct DB calls in controllers:**
```bash
grep -r "Repository\|EntityManager\|createQueryBuilder" src/ --include="*.controller.ts"
```
Fix: Move all DB operations to service layer.

**Check module boundaries:**
- Ensure modules don't import from other modules' internal files
- Only import from a module's exported barrel (`index.ts`)
- If cross-module access needed: export through the module, not direct file imports

---

### 2. Code Quality

**Functions longer than 30 lines:**
```bash
# Find large functions (rough heuristic)
awk '/\bfunction\b|\) \{|\) =>/{start=NR; count=0} /\{/{count++} /\}/{count--; if(count==0 && NR-start>30) print FILENAME ":" start " (" NR-start " lines)"}' src/**/*.ts
```

For each function > 30 lines:
- Extract sub-functions with descriptive names
- Each sub-function should have ONE clear responsibility
- The parent function should read like a summary

**Duplicate code blocks:**
```bash
# Look for copied code patterns
npx jscpd src/ --min-lines 10 --min-tokens 50
```

For each duplicate:
- Extract to a utility function in `src/common/utils/`
- Create a shared helper module
- Use inheritance or composition patterns

**Hardcoded magic numbers/strings:**
```bash
grep -r "[0-9]\{3,\}\|'\w\{10,\}'" src/ --include="*.ts" --include="*.tsx" | grep -v "spec\|test\|migration\|enum\|const\|type"
```

Extract to constants:
```typescript
// BEFORE: if (attempts > 5) lockUntil = Date.now() + 900000;
// AFTER:
const MAX_LOGIN_ATTEMPTS = 5;
const LOCK_DURATION_MS = 15 * 60 * 1000; // 15 minutes
if (attempts > MAX_LOGIN_ATTEMPTS) lockUntil = Date.now() + LOCK_DURATION_MS;
```

**Missing return types on functions:**
```bash
grep -n "): void\|): Promise\|function\s" src/ --include="*.ts" -r | grep -v "spec\|test"
# Look for functions without explicit return types
```

Fix: Add explicit return types to all exported functions and class methods.

---

### 3. Test Coverage Analysis

Run coverage report:
```bash
cd backend && npm test -- --coverage --forceExit 2>&1 | tail -40
cd frontend && npm test -- --coverage 2>&1 | tail -40
```

Parse coverage output. Find files below 80% threshold.

For each file below threshold:
1. Open the coverage HTML report: `backend/coverage/lcov-report/index.html`
2. Identify uncovered lines (red) and branches (yellow)
3. Generate specific tests for uncovered code paths

**Common coverage gaps to check:**
- Error paths in services (catch blocks, not-found cases)
- Edge cases in validation (boundary values)
- Middleware/interceptor error handling
- Loading and error states in React components

---

### 4. Performance Analysis

**Synchronous operations that should be async:**
```bash
grep -r "readFileSync\|writeFileSync\|execSync" src/ --include="*.ts"
```
Replace with async versions (readFile, writeFile, exec with promisify).

**Missing await keywords:**
```bash
# Find potentially missing awaits (common in TypeScript)
grep -n "this\.\w\+Service\.\w\+\b[^(]" src/ --include="*.ts" -r | grep -v "await"
```
Review each result. If the method returns a Promise and result is used, add `await`.

**React render optimization:**

Find components that re-render unnecessarily:
- Components passed new object/array literals as props on each parent render
- Event handlers created without useCallback
- Computed values without useMemo

Pattern to check and fix:
```typescript
// BEFORE — new object on every parent render:
<ChildComponent config={{ theme: 'dark', size: 'lg' }} />

// AFTER — stable reference:
const childConfig = useMemo(() => ({ theme: 'dark', size: 'lg' }), []);
<ChildComponent config={childConfig} />
```

**Missing database indexes based on query patterns:**

Review all `.createQueryBuilder()` calls and `.find()` calls with WHERE conditions.
For each condition column, verify an index exists:
```typescript
// If you have: .where('entity.userId = :userId AND entity.status = :status')
// You need: @Index(['userId', 'status']) on the entity
```

---

### 5. Security Re-Audit

**New endpoints without auth guard:**
```bash
grep -B5 "@Get\|@Post\|@Put\|@Patch\|@Delete" src/ --include="*.controller.ts" -r | grep -v "JwtAuthGuard\|@Public\|UseGuards"
```
For each unprotected endpoint: either add `@Public()` intentionally or add `@UseGuards(JwtAuthGuard)`.

**New DTOs missing validation:**
```bash
# Find DTO files without class-validator decorators
find src/ -name "*.dto.ts" | xargs grep -L "@Is\|@Min\|@Max\|@Length\|@Matches"
```
Add appropriate validators to each property.

**New env vars missing from .env.example:**
```bash
grep -rh "process\.env\." src/ backend/src/ --include="*.ts" | grep -oP "process\.env\.\K[A-Z_]+" | sort -u > /tmp/env-used.txt
grep -oP "^[A-Z_]+" backend/.env.example | sort > /tmp/env-defined.txt
diff /tmp/env-used.txt /tmp/env-defined.txt
```
Add any missing variables to `.env.example` with placeholder values.

---

## Priority Classification

After running all checks, classify findings:

### 🔴 Critical (fix immediately, same session)
- Circular dependencies that break functionality
- Missing auth on sensitive endpoints
- Real secrets found in code
- Syntax/compilation errors
- Any test failure introduced by this analysis

### 🟠 High (fix in this session)
- Direct DB calls in controllers
- Functions > 50 lines (refactor)
- Missing await causing silent Promise drops
- Files below 50% test coverage
- N+1 queries not caught in Phase 10

### 🟡 Medium (create Notion task)
- Functions 30-50 lines
- Coverage between 50-80%
- Duplicate code blocks
- Missing return types on internal functions

### 🔵 Low (backlog)
- Magic numbers in non-critical code
- Minor naming inconsistencies
- Missing comments on complex logic
- Micro-optimizations

---

## Fix Protocol

For each **Critical** and **High** finding:
1. Open the file
2. Make the change
3. Run affected tests to ensure nothing broke:
   ```bash
   cd backend && npm test -- --testPathPattern=[module] --forceExit
   ```
4. If tests pass: continue to next issue
5. If tests fail: fix the test or revert and document why

---

## Notion Backlog

For each **Medium** and **Low** finding, create a Notion task:

```bash
curl -s -X POST \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  https://api.notion.com/v1/pages \
  -d '{
    "parent": {"page_id": "[notionPageId]"},
    "properties": {
      "title": {"title": [{"text": {"content": "[Finding title]"}}]}
    },
    "children": [{
      "type": "paragraph",
      "paragraph": {"rich_text": [{"text": {"content": "[Description + file + line number]"}}]}
    }]
  }'
```

---

## Post-Fix Verification

After applying all Critical + High fixes:
```bash
# Re-run all tests
cd backend && npm test -- --coverage --forceExit
cd frontend && npm test -- --coverage

# Re-check TypeScript
cd backend && npx tsc --noEmit
cd frontend && npx tsc --noEmit

# Re-check for circular deps
npx madge --circular --extensions ts backend/src/
```

If new failures appeared: investigate and fix.

---

## Iteration Log

Save to `.sde/phases/13-iterations.md`:
```markdown
# Iteration Log

## Iteration [N] — [date]

### Architecture
- [issue found + fix applied]

### Code Quality
- [issue + fix]

### Test Coverage
- Before: Backend [N]%, Frontend [N]%
- After:  Backend [N]%, Frontend [N]%
- [specific files improved]

### Performance
- [optimization applied]

### Security
- [issue + fix]

### Backlog Created
- [N] Notion tasks created for Medium/Low findings

### Result
- All tests passing: ✅
- Coverage ≥ 80%: ✅
- No TypeScript errors: ✅
- No circular dependencies: ✅
```

---

## Autonomous Actions

1. Run all analysis checks
2. Fix all Critical and High findings
3. Create Notion tasks for Medium and Low
4. Run full test suite to verify nothing broke
5. Save iteration log to `.sde/phases/13-iterations.md`
6. ```bash
   git checkout develop
   git checkout -b feature/13-iteration-[N]
   git add .
   git commit -m "refactor: iteration [N] improvements — architecture, coverage, quality"
   git push origin feature/13-iteration-[N]
   ```
7. Update context.json: `currentPhase: 13`, add 13 to `completedPhases`

---

## Phase Gate (with repeat option)

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 13 COMPLETE — Iteration [N]            ║
╠══════════════════════════════════════════════════╣
║  FINDINGS:                                       ║
║  🔴 Critical: [N] (all fixed)                   ║
║  🟠 High:     [N] (all fixed)                   ║
║  🟡 Medium:   [N] (Notion tasks created)         ║
║  🔵 Low:      [N] (Notion backlog)               ║
╠══════════════════════════════════════════════════╣
║  COVERAGE:                                       ║
║  • Backend:  [N]%                                ║
║  • Frontend: [N]%                                ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • .sde/phases/13-iterations.md (appended)       ║
║  • Git committed: feature/13-iteration-[N]       ║
╠══════════════════════════════════════════════════╣
║  OPTIONS:                                        ║
╠══════════════════════════════════════════════════╣
║  [proceed]   → run another iteration             ║
║  [done]      → finish (project is production)    ║
║  [custom]    → focus on specific area            ║
╚══════════════════════════════════════════════════╝
```
