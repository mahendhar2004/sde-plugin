# SDE Plugin — Observability Standards

Concrete standards for logging, metrics, tracing, and alerting. Every agent generating backend code must follow these exactly. "Observability" means you can answer any question about your system's behavior from your tooling alone — without adding new instrumentation.

---

## The Three Pillars

| Pillar | Tool | Purpose |
|--------|------|---------|
| Logs | Grafana Loki (via NestJS Logger) | What happened? When? What was the context? |
| Metrics | Grafana Cloud (Prometheus) | How is the system performing over time? |
| Errors | Sentry free tier | What's broken? Who's affected? What's the stack trace? |

---

## Logging Standards

### Log Format (always structured JSON in production)
```typescript
// Every log entry must have these fields:
{
  "timestamp": "2024-01-15T10:30:00.000Z",  // ISO 8601
  "level": "log" | "warn" | "error" | "debug",
  "context": "ServiceName",                  // NestJS Logger context
  "event": "user.created",                   // dot-notation event name
  "correlationId": "req_abc123",             // from request header/middleware
  // + event-specific fields
}
```

### Event Naming Convention (dot-notation)
```
[resource].[action].[result?]

Examples:
  user.created
  user.login.success
  user.login.failed
  order.placed
  order.cancelled
  payment.processed
  payment.failed
  auth.token.refreshed
  auth.token.invalid
  cache.hit
  cache.miss
  db.query.slow           // only log if > 100ms
  http.request            // logged by interceptor
  http.request.error
```

### What MUST be logged
```typescript
// Auth events (always log these)
this.logger.log({ event: 'user.login.success', userId: user.id, ip: req.ip });
this.logger.warn({ event: 'user.login.failed', email, ip: req.ip, reason: 'invalid_password' });
this.logger.warn({ event: 'user.login.failed', email, ip: req.ip, reason: 'account_not_found' });
this.logger.log({ event: 'auth.token.refreshed', userId });
this.logger.warn({ event: 'auth.token.invalid', reason: 'expired', ip: req.ip });

// Resource mutations
this.logger.log({ event: '[resource].created', [resource]Id: id, actorId: userId });
this.logger.log({ event: '[resource].updated', [resource]Id: id, actorId: userId, fields: Object.keys(dto) });
this.logger.log({ event: '[resource].deleted', [resource]Id: id, actorId: userId });

// Errors with full context
this.logger.error({
  event: 'payment.failed',
  orderId: order.id,
  userId: order.userId,
  errorCode: error.code,
  errorMessage: error.message,
  // NEVER log: full card number, CVV, passwords, tokens
});

// Performance
this.logger.warn({ event: 'db.query.slow', query: 'findAllOrders', durationMs: 450 }); // > 100ms
```

### What NEVER gets logged
```
❌ Passwords (plaintext or hashed)
❌ JWT tokens or refresh tokens
❌ Full credit card numbers
❌ CVV/security codes
❌ Social security numbers
❌ Full API keys or secrets
❌ Private keys
```

### NestJS Logger Setup
```typescript
// main.ts
const app = await NestFactory.create(AppModule, {
  logger: process.env.NODE_ENV === 'production'
    ? new JsonLogger()     // custom JSON logger for Loki
    : new Logger(),         // standard pretty logger for dev
});
```

---

## Metrics Standards

### Metric Naming Convention
```
app_[resource]_[metric]_[unit]

Examples:
  app_http_requests_total              counter
  app_http_request_duration_seconds    histogram
  app_db_connections_active            gauge
  app_cache_hits_total                 counter
  app_cache_misses_total               counter
  app_auth_login_attempts_total        counter
  app_auth_login_failures_total        counter
  app_queue_jobs_pending               gauge
  app_queue_jobs_processed_total       counter
  app_queue_jobs_failed_total          counter
```

### Required Metrics (add to every NestJS app)
```typescript
// @willsoto/nestjs-prometheus provides these automatically:
// - http_request_duration_seconds (histogram with route, method, status labels)
// - http_requests_total (counter)
// - process_cpu_seconds_total
// - process_resident_memory_bytes
// - nodejs_heap_size_used_bytes

// Custom metrics to add:
const authFailuresCounter = new Counter({
  name: 'app_auth_login_failures_total',
  help: 'Total failed login attempts',
  labelNames: ['reason'],
});

const cacheHitCounter = new Counter({
  name: 'app_cache_hits_total',
  help: 'Total cache hits',
  labelNames: ['key_prefix'],
});

const dbQueryDuration = new Histogram({
  name: 'app_db_query_duration_seconds',
  help: 'Database query duration',
  labelNames: ['operation', 'entity'],
  buckets: [0.01, 0.05, 0.1, 0.3, 0.5, 1, 2],
});
```

---

## Alert Thresholds

| Metric | Warning | Critical | Action |
|--------|---------|---------|--------|
| HTTP p95 latency | > 500ms | > 1000ms | Investigate slow queries/external calls |
| HTTP error rate | > 1% | > 5% | Check logs, possibly roll back |
| CPU usage | > 70% | > 90% | Scale up or optimize |
| Memory usage | > 80% | > 95% | Memory leak investigation |
| DB connections | > 8/10 | 10/10 | Connection pool exhaustion |
| Auth failures | > 20/min | > 100/min | Possible brute force attack |
| Queue depth | > 100 | > 500 | Queue processing stuck |
| Disk usage | > 70% | > 90% | Clean logs, archive data |

---

## Health Check Endpoint Standard

Every app exposes `/health` that returns actual health:
```typescript
// Returns 200 if healthy, 503 if degraded
GET /health

// Response:
{
  "status": "ok" | "error",
  "info": {
    "database": { "status": "up" },
    "redis": { "status": "up" }
  },
  "error": {},
  "details": {
    "database": { "status": "up", "responseTimeMs": 5 },
    "redis": { "status": "up", "responseTimeMs": 1 }
  }
}
```

---

## Sentry Configuration

```typescript
// main.ts — before NestFactory
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  release: process.env.APP_VERSION,
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  beforeSend(event) {
    // Scrub sensitive data before sending to Sentry
    if (event.request?.data) {
      delete event.request.data.password;
      delete event.request.data.token;
    }
    return event;
  },
});

// Capture with context:
Sentry.captureException(error, {
  user: { id: userId },
  tags: { module: 'payments', operation: 'charge' },
  extra: { orderId, amount },
});
```

---

## Grafana Dashboard Requirements

Every project must have a Grafana dashboard with these panels:
1. **Request Rate** — requests/sec over time, by endpoint
2. **Error Rate** — error % over time, with 1% and 5% threshold lines
3. **P50/P95/P99 Latency** — response time percentiles
4. **Active Users** — concurrent active sessions
5. **Auth Events** — login success/failure rate
6. **DB Query Performance** — slow query rate
7. **Cache Performance** — hit/miss ratio
8. **System Resources** — CPU, memory, disk
