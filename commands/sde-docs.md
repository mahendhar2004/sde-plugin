---
description: Documentation generation — writes JSDoc for all public methods, updates README, generates docs/ architecture guide, syncs API docs to Notion, and produces a developer onboarding guide
---

# SDE Plugin — Documentation Generator

You generate comprehensive, accurate documentation from the actual source code. Documentation is generated from code — not invented. Everything written must be verifiable in the codebase.

## Load Context
Read `.sde/context.json`, `.sde/phases/5-api-design.md`, `.sde/schemas/openapi.yaml`.

Use the **Agent tool** to spawn one agent:

### Docs Agent
Spawn an agent with this prompt:
```
Read ~/.sde-plugin/agents/docs-agent.md for your full identity and standards.

Your task: Generate complete project documentation.

Project context: Read .sde/context.json and all .sde/phases/ files.

Generate:
1. README.md (from scratch — follow your identity file's README structure)
2. docs/architecture.md — from .sde/phases/2-architecture.md
3. docs/api.md — from .sde/schemas/openapi.yaml
4. docs/development.md — local setup guide
5. docs/deployment.md — deployment runbook
6. JSDoc comments on all public service methods and DTOs
7. Sync key docs to Notion if NOTION_TOKEN is set
```

---

## What Gets Generated

### 1. JSDoc on All Public Methods

For every `public` method in every NestJS service:
```typescript
/**
 * Creates a new user account.
 *
 * Validates that the email is not already registered, hashes the password
 * with bcrypt (12 rounds), and persists the user to the database.
 *
 * @param dto - The registration data (email + password)
 * @returns The created user (without passwordHash)
 * @throws ConflictException if email is already registered
 * @throws BadRequestException if input validation fails
 *
 * @example
 * const user = await usersService.create({ email: 'jan@example.com', password: 'SecurePass123!' });
 */
async create(dto: CreateUserDto): Promise<User> { ... }
```

For React hooks:
```typescript
/**
 * Fetches paginated users list with optional search and sort.
 *
 * Uses TanStack Query with 5 min stale time. Automatically refetches
 * when params change. Invalidated when any user mutation succeeds.
 *
 * @param params - Pagination, search, and sort parameters
 * @returns Query result with users array and pagination meta
 *
 * @example
 * const { data, isLoading } = useUsers({ page: 1, pageSize: 20, search: 'john' });
 */
export function useUsers(params: UserQueryParams) { ... }
```

### 2. Project README.md (Complete Rewrite)

Generate a professional README at the project root:

```markdown
# [Project Name]

> [One-sentence description of what this project does and who it's for]

## Features
- [Feature 1]
- [Feature 2]

## Tech Stack
| Layer | Technology |
|-------|-----------|
| Backend | NestJS + TypeScript + TypeORM + PostgreSQL |
...

## Getting Started

### Prerequisites
- Node.js 20+
- Docker + Docker Compose
- [Any other requirements]

### Local Development
\`\`\`bash
git clone https://github.com/[user]/[repo]
cd [repo]
cp .env.example .env      # fill in your values
docker-compose up -d      # start PostgreSQL + Redis
cd backend && npm install && npm run start:dev
cd frontend && npm install && npm run dev
\`\`\`

App running at: http://localhost:5173
API running at: http://localhost:3000/api/v1
API docs at:   http://localhost:3000/api/docs

### Environment Variables
| Variable | Required | Description |
|----------|---------|-------------|
| DATABASE_URL | Yes | PostgreSQL connection string |
...

## Project Structure
[generated from actual directory structure]

## API Reference
See [OpenAPI spec](./backend/openapi.yaml) or run locally and visit /api/docs.

## Testing
\`\`\`bash
cd backend && npm test           # unit + integration tests
cd frontend && npm test          # component tests
npm test -- --coverage          # with coverage report
\`\`\`

## Deployment
[generated from sde-devops outputs — docker-compose, GitHub Actions]

## Architecture
See [docs/architecture.md](./docs/architecture.md) for the full architecture guide.
```

### 3. docs/ Folder

Create `docs/` directory with:

**docs/architecture.md:**
- System overview
- Component diagram (from `.sde/phases/2-architecture.md`)
- Data flow description
- Auth flow
- Key architectural decisions (summarized from `.sde/adr/`)

**docs/api.md:**
- Human-readable API reference (generated from OpenAPI spec)
- Auth instructions
- Common request/response examples
- Error code reference

**docs/development.md:**
- Development environment setup (detailed)
- Code style guide (conventions used in this project)
- Adding a new feature (step-by-step guide with examples)
- Testing guide
- Common gotchas and how to avoid them

**docs/deployment.md:**
- Environment setup (AWS free tier)
- First deploy walkthrough
- Subsequent deploys (CI/CD)
- Rollback procedure
- Monitoring and alerting

**docs/decisions.md:**
- All ADRs in one document (generated from `.sde/adr/`)

### 4. Notion Sync

Update Notion project page with:
- Link to GitHub docs/ folder
- Updated API Design page (from current OpenAPI spec)
- Updated Architecture page

---

## Output Structure

```
[project-root]/
├── README.md                    ← complete rewrite
├── docs/
│   ├── architecture.md
│   ├── api.md
│   ├── development.md
│   ├── deployment.md
│   └── decisions.md
└── backend/src/
    └── [all public methods now have JSDoc]
```

---

## Commit

```bash
git add README.md docs/ backend/src/ frontend/src/
git commit -m "docs: generate comprehensive documentation

- Complete README with setup, architecture, and deployment guide
- docs/ folder with architecture, API, development, and deployment guides
- JSDoc on all public service methods
- Synced to Notion"
```

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ DOCUMENTATION COMPLETE                       ║
╠══════════════════════════════════════════════════╣
║  • README.md updated                             ║
║  • docs/architecture.md generated               ║
║  • docs/api.md generated                        ║
║  • docs/development.md generated                ║
║  • docs/deployment.md generated                 ║
║  • JSDoc on all public methods                   ║
║  • Notion synced                                 ║
╠══════════════════════════════════════════════════╣
║  [proceed] → commit documentation                ║
║  [refine]  → regenerate with different focus     ║
║  [custom]  → describe what to add/change         ║
╚══════════════════════════════════════════════════╝
```
