# SDE Plugin — Performance Standards

Concrete, measurable performance targets. Every agent must design and code to these numbers. "Fast" is not a standard — these numbers are.

---

## API Performance Targets

| Metric | Target | Acceptable | Unacceptable |
|--------|--------|-----------|-------------|
| p50 response time | < 50ms | < 100ms | > 200ms |
| p95 response time | < 200ms | < 500ms | > 1000ms |
| p99 response time | < 500ms | < 1000ms | > 2000ms |
| Error rate | < 0.1% | < 1% | > 1% |
| Throughput (free tier EC2) | > 100 req/s | > 50 req/s | < 20 req/s |

Endpoint-specific targets:
```
Auth endpoints (login/register):  p95 < 300ms  (bcrypt adds ~200ms)
List endpoints (paginated):        p95 < 150ms
Single resource fetch:             p95 < 50ms   (should be cache hit)
File upload:                       p95 < 3s     (S3 latency included)
Webhook processing:                async via queue, no direct response time target
```

---

## Database Performance Targets

| Operation | Target | Acceptable | Action if Exceeded |
|-----------|--------|-----------|-------------------|
| Simple SELECT by PK | < 5ms | < 20ms | Check connection pool |
| SELECT with 1 JOIN | < 20ms | < 50ms | Add index |
| SELECT with 2-3 JOINs | < 50ms | < 100ms | Add composite index |
| Paginated list query | < 30ms | < 100ms | Add covering index |
| INSERT/UPDATE | < 10ms | < 30ms | Check for triggers |
| Full-text search | < 100ms | < 300ms | Add GIN index |

**Slow query threshold:** Any query > 100ms gets logged as `db.query.slow` and investigated.

### Index Performance Rules
- Every foreign key column MUST have an index
- Every column used in WHERE clause on large tables MUST have an index
- ORDER BY columns on large datasets MUST be indexed
- Composite index column order: most selective first, then sort column

### Query Plan Rule
Any new query joining > 2 tables must be validated with `EXPLAIN ANALYZE`:
```sql
EXPLAIN ANALYZE SELECT ...;
-- Reject if: Sequential Scan on large table (> 10k rows)
-- Accept if: Index Scan or Index Only Scan
```

---

## Frontend Performance Targets (Core Web Vitals)

| Metric | Good | Needs Improvement | Poor |
|--------|------|-----------------|------|
| LCP (Largest Contentful Paint) | < 2.5s | 2.5s – 4s | > 4s |
| FID (First Input Delay) | < 100ms | 100 – 300ms | > 300ms |
| CLS (Cumulative Layout Shift) | < 0.1 | 0.1 – 0.25 | > 0.25 |
| FCP (First Contentful Paint) | < 1.8s | 1.8s – 3s | > 3s |
| TTFB (Time to First Byte) | < 800ms | 800ms – 1.8s | > 1.8s |

**Target:** All Core Web Vitals in "Good" range.

### Bundle Size Targets
```
Initial JS bundle:     < 200KB gzipped
Initial CSS bundle:    < 30KB gzipped
Total page weight:     < 500KB (excluding images)
Route-level chunks:    < 100KB each
Image (hero):          < 200KB (WebP)
Image (thumbnail):     < 20KB (WebP)
```

### Frontend Performance Rules
```
Code splitting:      Required at route level (React.lazy + Suspense)
Images:              Always: lazy loading + correct dimensions + WebP
Fonts:               Preload critical fonts, font-display: swap
Lists > 50 items:    Virtualize with @tanstack/react-virtual
API calls:           React Query with staleTime (never fetch on every render)
Re-renders:          Profile before shipping any list/dashboard component
Animation:           CSS transforms only (not layout-triggering properties)
```

---

## Mobile Performance Targets (React Native)

| Metric | Target | Unacceptable |
|--------|--------|-------------|
| Cold start (time to interactive) | < 2s | > 4s |
| JS bundle parse time | < 500ms | > 1s |
| Screen transition | < 300ms | > 500ms |
| Frame rate | 60fps (16ms/frame) | Drops below 50fps |
| Memory usage | < 150MB | > 300MB |
| API calls to display content | < 1.5s | > 3s |

Rules:
- No heavy computation on the main thread — use InteractionManager.runAfterInteractions
- FlatList for all lists (never ScrollView with .map())
- Images: use expo-image (faster than Image component)
- Animations: use react-native-reanimated (runs on UI thread)

---

## Caching Strategy and TTL Standards

| Data Type | Cache? | TTL | Invalidation |
|-----------|--------|-----|-------------|
| Current user profile | Yes | 5 min | On profile update |
| User list (admin) | Yes | 2 min | On any user mutation |
| Static config/settings | Yes | 1 hour | On config change |
| Product/category list | Yes | 30 min | On product mutation |
| Individual resource | Yes | 5 min | On that resource update |
| Real-time data | No | — | Never cache |
| Auth tokens | Never | — | Use DB, not cache |
| Session data | No | — | Use DB with TTL |

Redis cache key naming:
```
[resource]:[id]          user:abc123
[resource]:list:[hash]   user:list:a1b2c3  (hash of query params)
[resource]:count         user:count
config:[key]             config:features
```

---

## Load Testing Requirements

Before any production release, run a load test:

**Tool:** k6 (free, open source)

```javascript
// k6 load test script: tests/load/basic.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 100 },  // ramp up to 100 users
    { duration: '5m', target: 100 },  // stay at 100
    { duration: '2m', target: 0 },    // ramp down
  ],
  thresholds: {
    http_req_duration: ['p95<200'],    // 95% of requests < 200ms
    http_req_failed: ['rate<0.01'],    // < 1% error rate
  },
};

export default function () {
  const res = http.get('http://localhost:3000/api/v1/health');
  check(res, { 'status 200': (r) => r.status === 200 });
  sleep(1);
}
```

**Pass criteria for production:**
- p95 latency < 200ms under 100 concurrent users
- Error rate < 1% under 100 concurrent users
- No memory leaks (memory stable over 5-minute test)
