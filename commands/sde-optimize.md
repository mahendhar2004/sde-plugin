---
description: Phase 10 — Performance Optimization. Fixes N+1 queries, adds Redis caching, optimizes frontend bundle, adds database indexes, and applies all performance best practices.
---

## ⚠️ Phase Guard — Read This First

Before doing ANYTHING else, check:
1. Does `.sde/context.json` exist in the current directory?

If it is missing → output this warning and continue in standalone mode:
```
⚠️ No .sde/context.json found. Running in standalone mode — will analyze current directory without project context.
```
Do NOT stop — proceed with the performance audit against the current directory.

If it exists → read it and use it to inform the optimization work.

---

# SDE Optimize — Phase 10: Performance Optimization

## Pre-Flight

1. Read `.sde/phases/4-data-model.md` — existing indexes
2. Read `.sde/phases/7-implementation.md` — implemented modules
3. Read `.sde/context.json` — project type

---

## Database Optimizations

### 1. Find and Fix N+1 Query Problems

Scan all service files for patterns that load relations in loops:

```bash
# Look for loops that call repository methods
grep -r "for\|forEach\|map\|reduce" src/ --include="*.service.ts"
```

**N+1 Pattern to Fix:**
```typescript
// BAD — N+1 query (1 query for list + N queries for relations)
const posts = await this.postRepository.find();
for (const post of posts) {
  post.author = await this.userRepository.findOne({ where: { id: post.userId } });
}

// GOOD — Single JOIN query
const posts = await this.postRepository.createQueryBuilder('post')
  .leftJoinAndSelect('post.author', 'author')
  .getMany();
```

Fix all N+1 patterns found.

### 2. Verify and Add Missing Indexes

Review all entities and ensure:
- Every `@ManyToOne` FK column has `@Index()`
- Every column used in `WHERE` clauses has an index
- Every column used in `ORDER BY` has an index

Common missed indexes to check:
```typescript
// In every entity that has these patterns:
@Index()  // ADD if missing
@Column({ name: 'user_id' })
userId: string;

@Index()  // ADD for status filters
@Column({ type: 'enum', enum: Status })
status: Status;

// Composite index for common combined filters:
@Index(['userId', 'status'])  // list by user filtered by status
@Index(['userId', 'createdAt'])  // list by user sorted by date
```

Generate and run a migration if schema changes are needed:
```bash
cd backend && npm run migration:generate -- -n AddMissingIndexes
```

### 3. Paginate ALL List Endpoints

Audit every `find()` call that returns an array. If no pagination is applied, fix:

```typescript
// BAD — loads entire table
async findAll(): Promise<Entity[]> {
  return this.repository.find();
}

// GOOD — paginated
async findAll(query: PaginationDto): Promise<{ data: Entity[]; total: number }> {
  const [data, total] = await this.repository.findAndCount({
    where: { deletedAt: null },
    skip: (query.page - 1) * query.limit,
    take: query.limit,
    order: { [query.sortBy || 'createdAt']: query.sortOrder || 'DESC' },
  });
  return { data, total };
}
```

### 4. Database Connection Pool

Verify in `database.config.ts`:
```typescript
extra: {
  max: 10,              // max pool size
  min: 2,               // min pool size
  acquire: 30000,       // max ms to wait for connection
  idle: 10000,          // ms before idle connection is released
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
},
```

---

## Redis Caching Implementation

### 1. Cache Service

Create a centralized cache service:

```typescript
// src/common/cache/cache.service.ts
import { Injectable } from '@nestjs/common';
import { Cache } from 'cache-manager';
import { InjectCache } from '@nestjs/cache-manager';

@Injectable()
export class CacheService {
  constructor(@InjectCache() private cacheManager: Cache) {}

  async get<T>(key: string): Promise<T | undefined> {
    return this.cacheManager.get<T>(key);
  }

  async set(key: string, value: unknown, ttl?: number): Promise<void> {
    await this.cacheManager.set(key, value, ttl);
  }

  async del(key: string): Promise<void> {
    await this.cacheManager.del(key);
  }

  async delByPattern(pattern: string): Promise<void> {
    // Requires Redis client for SCAN
    const keys = await this.scanKeys(pattern);
    await Promise.all(keys.map((key) => this.cacheManager.del(key)));
  }

  private async scanKeys(pattern: string): Promise<string[]> {
    // Implementation depends on redis client access
    return [];
  }
}
```

### 2. Cache Keys Constants

```typescript
// src/common/cache/cache-keys.ts
export const CACHE_KEYS = {
  USER_PROFILE: (id: string) => `user:${id}:profile`,
  USER_LIST: (filters: string) => `users:list:${filters}`,
  FEATURE_LIST: (userId: string, filters: string) => `feature:${userId}:list:${filters}`,
  FEATURE_ITEM: (id: string) => `feature:${id}`,
  APP_CONFIG: 'config:app',
} as const;

export const CACHE_TTL = {
  USER_PROFILE: 5 * 60,       // 5 minutes
  LIST: 2 * 60,                // 2 minutes
  APP_CONFIG: 30 * 60,         // 30 minutes
  SHORT: 60,                   // 1 minute
} as const;
```

### 3. Apply Caching to Services

For each service that reads frequently-queried data:

```typescript
// In service methods:
async findUserProfile(id: string): Promise<User> {
  const cacheKey = CACHE_KEYS.USER_PROFILE(id);
  const cached = await this.cacheService.get<User>(cacheKey);
  if (cached) return cached;

  const user = await this.userRepository.findOne({ where: { id } });
  if (!user) throw new NotFoundException('User not found');

  await this.cacheService.set(cacheKey, user, CACHE_TTL.USER_PROFILE);
  return user;
}

// In mutation methods — invalidate cache:
async updateUser(id: string, dto: UpdateUserDto): Promise<User> {
  const user = await this.findOne(id);
  Object.assign(user, dto);
  const saved = await this.userRepository.save(user);

  // Invalidate cache
  await this.cacheService.del(CACHE_KEYS.USER_PROFILE(id));

  return saved;
}
```

### 4. Rate Limit Counter in Redis

Verify `nestjs-throttler` uses Redis storage (not in-memory):
```typescript
// In app.module.ts ThrottlerModule:
ThrottlerModule.forRootAsync({
  imports: [ConfigModule],
  inject: [ConfigService],
  useFactory: (configService: ConfigService) => ({
    throttlers: [
      { name: 'short', ttl: 1000, limit: 10 },
      { name: 'long', ttl: 60000, limit: 300 },
    ],
    storage: new ThrottlerStorageRedisService({
      host: configService.get('REDIS_HOST'),
      port: configService.get('REDIS_PORT'),
    }),
  }),
}),
```

---

## API Performance

### 1. Response Time Header

Add to LoggingInterceptor:
```typescript
// After processing:
response.setHeader('X-Response-Time', `${Date.now() - startTime}ms`);
```

### 2. Compression Middleware

Verify `compression` is registered in main.ts before routes:
```typescript
import * as compression from 'compression';
app.use(compression());
```

### 3. ETag Headers for Static Data

For rarely-changing list endpoints:
```typescript
@Get('categories')
@Header('Cache-Control', 'public, max-age=300') // 5 min browser cache
async getCategories(@Res() res: Response, @Req() req: Request) {
  const data = await this.categoriesService.findAll();
  const etag = createHash('md5').update(JSON.stringify(data)).digest('hex');

  if (req.headers['if-none-match'] === etag) {
    return res.status(304).send();
  }

  res.setHeader('ETag', etag);
  return res.json({ data });
}
```

---

## Frontend Performance

### 1. Route-Level Code Splitting

Replace direct imports with lazy loading:
```typescript
// src/App.tsx — BEFORE:
import { DashboardPage } from './pages/DashboardPage';
import { FeaturePage } from './pages/FeaturePage';

// AFTER:
import { lazy, Suspense } from 'react';
const DashboardPage = lazy(() => import('./pages/DashboardPage').then(m => ({ default: m.DashboardPage })));
const FeaturePage = lazy(() => import('./pages/FeaturePage').then(m => ({ default: m.FeaturePage })));

// Wrap routes with Suspense:
<Suspense fallback={<PageLoader />}>
  <Routes>
    <Route path="/dashboard" element={<DashboardPage />} />
  </Routes>
</Suspense>
```

### 2. React Query Stale Time

Set appropriate stale times to reduce unnecessary refetches:
```typescript
// In main.tsx QueryClient config:
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,   // 5 minutes default
      gcTime: 10 * 60 * 1000,     // 10 minutes garbage collection
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});
```

### 3. Component Memoization

Audit list components and apply memoization where re-renders are expensive:

```typescript
// For list items that receive props but don't change often:
export const FeatureCard = React.memo(function FeatureCard({ item, onAction }: Props) {
  return <div>...</div>;
});

// For expensive computations:
const sortedItems = useMemo(() =>
  items.sort((a, b) => b.createdAt.localeCompare(a.createdAt)),
  [items]
);

// For callbacks passed to child components:
const handleAction = useCallback((id: string) => {
  // action logic
}, [dependency]);
```

### 4. Image Optimization

For any `<img>` tags:
```typescript
// BEFORE:
<img src={url} />

// AFTER:
<img
  src={url}
  loading="lazy"
  decoding="async"
  width={300}
  height={200}
  alt="description"
/>
```

### 5. Bundle Analysis

Add to frontend package.json scripts:
```json
{
  "scripts": {
    "analyze": "vite build --mode analyze && npx vite-bundle-analyzer dist/stats.html"
  }
}
```

Add to vite.config.ts:
```typescript
build: {
  rollupOptions: {
    output: {
      manualChunks: {
        'vendor-react': ['react', 'react-dom'],
        'vendor-router': ['react-router-dom'],
        'vendor-query': ['@tanstack/react-query'],
        'vendor-forms': ['react-hook-form', 'zod'],
      },
    },
  },
},
```

---

## Docker Image Optimization

### Verify Multi-Stage Builds

Check both Dockerfiles use multi-stage:
- Stage 1: install ALL deps, build
- Stage 2: copy only `dist/` and `node_modules` (production only)
- Use `node:20-alpine-slim` (not full alpine) for production stage

### .dockerignore Files

Create `backend/.dockerignore`:
```
node_modules
dist
coverage
.git
*.md
.env
.env.*
!.env.example
```

Create `frontend/.dockerignore`:
```
node_modules
dist
coverage
.git
*.md
.env
.env.*
!.env.example
```

---

## Performance Report

Generate a summary documenting all optimizations applied:

```markdown
# Performance Optimization Report — Phase 10

## Database
- Fixed N+1 queries: [list each fix]
- Added indexes: [list each new index]
- Paginated endpoints: [list each endpoint]
- Connection pool: max=10, min=2

## Caching (Redis)
- Cached entities: [list each + TTL]
- Cache invalidation: [list each mutation that invalidates]
- Rate limit storage: Redis

## API
- Compression: enabled (gzip)
- X-Response-Time header: enabled
- ETag headers: added to static endpoints

## Frontend
- Code splitting: [N] routes lazy-loaded
- Memoization: [N] components memoized
- Bundle chunks: vendor split into [N] chunks
- React Query stale time: 5min default

## Estimated Improvements
- API response time: [estimate]% faster (caching)
- DB query count: [estimate]% reduction (N+1 fixes, caching)
- Frontend bundle: [estimate]% smaller (code splitting)
```

---

## Autonomous Actions

1. Apply ALL database fixes (N+1, indexes, pagination)
2. Implement caching in services
3. Apply frontend optimizations
4. Update Dockerfiles and .dockerignore
5. Save performance report to `.sde/phases/10-performance.md`
6. ```bash
   git checkout develop
   git checkout -b feature/10-performance
   git add .
   git commit -m "perf: database, caching, and frontend optimizations — Phase 10"
   git push origin feature/10-performance
   ```
7. Update context.json: `currentPhase: 10`, add 10 to `completedPhases`

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 10 COMPLETE — Performance              ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • [N] N+1 queries fixed                         ║
║  • [N] new database indexes added                ║
║  • Redis caching for [N] data types              ║
║  • [N] frontend routes lazy-loaded               ║
║  • Docker images multi-stage optimized           ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • .sde/phases/10-performance.md                 ║
║  • Git committed: feature/10-performance         ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 11 — DevOps & Deployment            ║
╠══════════════════════════════════════════════════╣
║  [proceed] → set up CI/CD and Docker             ║
║  [refine]  → more optimizations                  ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
