# SDE Plugin — API Design Standards

Single source of truth for REST API design across all projects. Every agent generating API code or documentation must follow these standards exactly.

---

## URL Structure
```
/api/v1/[resource]           → collection
/api/v1/[resource]/:id       → single item
/api/v1/[resource]/:id/[sub] → sub-resource
/api/v1/admin/[resource]     → admin-only endpoints
```

Rules:
- Always `/api/v1/` prefix (versioning from day one)
- Plural nouns for resources: `/users`, `/orders`, `/products`
- Kebab-case for multi-word: `/blog-posts`, `/refresh-tokens`
- Never verbs in URLs (that's what HTTP methods are for)

---

## HTTP Method Semantics

| Method | Use | Idempotent | Body |
|--------|-----|-----------|------|
| GET | Retrieve | Yes | No |
| POST | Create | No | Yes |
| PUT | Full replace | Yes | Yes |
| PATCH | Partial update | Yes | Yes |
| DELETE | Delete | Yes | No |

---

## Standard Response Envelope

### Success (200/201)
```json
{
  "data": { ... } | [ ... ],
  "meta": { "total": 100, "page": 1, "pageSize": 20, "totalPages": 5 }
}
```
Note: `meta` only included on paginated list responses.

### Error (4xx/5xx)
```json
{
  "statusCode": 400,
  "error": "Bad Request",
  "message": "Validation failed",
  "details": [
    { "field": "email", "message": "Please provide a valid email address" }
  ],
  "timestamp": "2024-01-15T10:30:00.000Z",
  "path": "/api/v1/users",
  "correlationId": "req_abc123"
}
```

---

## HTTP Status Codes

| Status | When to Use |
|--------|-------------|
| 200 | Success (GET, PATCH, PUT, DELETE) |
| 201 | Created (POST that creates a resource) |
| 204 | No Content (DELETE, or action with no response body) |
| 400 | Bad Request (validation failure, malformed JSON) |
| 401 | Unauthorized (missing or invalid token) |
| 403 | Forbidden (authenticated but no permission) |
| 404 | Not Found (resource doesn't exist) |
| 409 | Conflict (duplicate email, business rule violation) |
| 422 | Unprocessable Entity (valid format but semantic error) |
| 429 | Too Many Requests (rate limit hit) |
| 500 | Internal Server Error (unexpected failures) |
| 503 | Service Unavailable (DB down, maintenance) |

---

## Pagination

### Request
```
GET /api/v1/posts?page=1&pageSize=20&sortBy=createdAt&sortOrder=DESC
GET /api/v1/posts?search=keyword&filter[status]=published
```

### Response
```json
{
  "data": [...],
  "meta": {
    "total": 156,
    "page": 1,
    "pageSize": 20,
    "totalPages": 8,
    "hasNext": true,
    "hasPrev": false
  }
}
```

### Query DTO (NestJS)
```typescript
export class PaginationQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1)
  page: number = 1;

  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100)
  pageSize: number = 20;

  @IsOptional() @IsString()
  sortBy?: string;

  @IsOptional() @IsIn(['ASC', 'DESC'])
  sortOrder: 'ASC' | 'DESC' = 'DESC';

  @IsOptional() @IsString() @MaxLength(100)
  search?: string;
}
```

---

## Authentication

```
Public endpoints (no auth):     POST /auth/register, POST /auth/login, POST /auth/refresh
Private endpoints (JWT):        All other endpoints — @UseGuards(JwtAuthGuard)
Admin endpoints (JWT + role):   /admin/* — @UseGuards(JwtAuthGuard, RolesGuard) @Roles('admin')
```

Headers:
```
Authorization: Bearer <access_token>
```

Refresh token endpoint:
```
POST /auth/refresh
Body: { "refreshToken": "..." }
Response: { "accessToken": "...", "refreshToken": "..." }
```

---

## Rate Limiting Tiers

| Endpoint Type | Limit | Window |
|--------------|-------|--------|
| POST /auth/login | 5 | 1 min |
| POST /auth/register | 10 | 1 hour |
| POST /auth/refresh | 20 | 1 min |
| POST /auth/forgot-password | 3 | 1 hour |
| All other endpoints | 60 | 1 min |

---

## File Upload Endpoints

```
POST /api/v1/[resource]/upload
Content-Type: multipart/form-data

Validation:
- Max size: 10MB
- Allowed types: image/jpeg, image/png, image/webp, application/pdf
- Store: AWS S3, return: { url: "https://cdn.yourapp.com/..." }
```

---

## Naming Conventions in API

```
✅ GET /users/:userId/posts        (sub-resource)
✅ POST /orders/:orderId/cancel    (action on resource)
✅ GET /posts?status=published     (filter via query param)

❌ GET /getUserPosts               (verb in URL)
❌ POST /cancel-order              (action as URL segment)
❌ GET /posts/published            (status as path segment)
```

---

## OpenAPI Documentation Standards

Every endpoint must have:
```typescript
@ApiOperation({ summary: 'Brief description', description: 'Full description' })
@ApiResponse({ status: 200, description: 'Success', type: ResponseDto })
@ApiResponse({ status: 401, description: 'Unauthorized' })
@ApiResponse({ status: 404, description: 'Not found' })
@ApiBearerAuth() // on authenticated endpoints
```

Swagger UI available at: `/api/docs` (dev only, disabled in production)

---

## Correlation IDs

Every request gets a unique ID for tracing:
```typescript
// middleware/correlation-id.middleware.ts
app.use((req, res, next) => {
  req.correlationId = req.headers['x-correlation-id'] ?? `req_${nanoid(10)}`;
  res.setHeader('x-correlation-id', req.correlationId);
  next();
});
```

All log entries include `correlationId` to trace a request through all log lines.
