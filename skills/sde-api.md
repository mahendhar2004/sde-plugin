---
name: sde-api
description: Phase 5 — API Design. Designs all REST endpoints organized by resource, defines request/response schemas, auth requirements, rate limits, pagination strategy, and generates a complete OpenAPI 3.0 YAML spec.
---

# SDE API — Phase 5: API Design

## Pre-Flight

1. Read `.sde/phases/1-prd.md` — features that need API endpoints
2. Read `.sde/phases/4-data-model.md` — entities and their fields
3. Read `.sde/phases/2-architecture.md` — auth flow, rate limiting strategy
4. Read `.sde/context.json` — project type

---

## API Design Principles

- **Base path**: `/api/v1/`
- **Format**: JSON (Content-Type: application/json)
- **Auth**: Bearer JWT in `Authorization` header
- **Errors**: Consistent error format across ALL endpoints
- **Pagination**: Cursor-based for feeds/large lists; offset for simple queries
- **Naming**: Plural nouns for resources (`/users`, `/posts`, NOT `/getUser`)
- **HTTP Methods**: GET (read), POST (create), PUT (full replace), PATCH (partial update), DELETE (soft delete)
- **Status Codes**: 200 (ok), 201 (created), 204 (no content), 400 (validation), 401 (unauth), 403 (forbidden), 404 (not found), 409 (conflict), 429 (rate limited), 500 (server error)

---

## Standard Response Envelopes

### Success Response
```json
{
  "data": { ... },
  "meta": {
    "timestamp": "2024-01-01T00:00:00Z",
    "requestId": "uuid"
  }
}
```

### Paginated List Response
```json
{
  "data": [ ... ],
  "pagination": {
    "total": 100,
    "page": 1,
    "limit": 20,
    "hasNext": true,
    "hasPrev": false,
    "nextCursor": "cursor-string"
  },
  "meta": {
    "timestamp": "...",
    "requestId": "..."
  }
}
```

### Error Response
```json
{
  "statusCode": 400,
  "message": "Validation failed",
  "error": "Bad Request",
  "details": [
    { "field": "email", "message": "must be a valid email" }
  ],
  "timestamp": "2024-01-01T00:00:00Z",
  "path": "/api/v1/users",
  "requestId": "uuid"
}
```

---

## Authentication Endpoints

### POST /api/v1/auth/register
- **Auth**: None
- **Rate limit**: 3 per hour per IP (strict)
- **Request body**:
  ```json
  {
    "firstName": "string, required, 1-100 chars",
    "lastName": "string, required, 1-100 chars",
    "email": "string, required, valid email",
    "password": "string, required, min 8 chars, 1 uppercase, 1 number"
  }
  ```
- **Response 201**:
  ```json
  {
    "data": {
      "user": { "id": "uuid", "email": "...", "firstName": "...", "lastName": "..." },
      "accessToken": "JWT",
      "refreshToken": "JWT"
    }
  }
  ```
- **Errors**: 400 (validation), 409 (email exists)

### POST /api/v1/auth/login
- **Auth**: None
- **Rate limit**: 5 per 15 min per IP (very strict)
- **Request body**: `{ "email": "string", "password": "string" }`
- **Response 200**: Same as register response
- **Errors**: 400 (validation), 401 (invalid credentials), 423 (account locked)

### POST /api/v1/auth/refresh
- **Auth**: None (refresh token in body)
- **Rate limit**: 10 per 15 min per IP
- **Request body**: `{ "refreshToken": "string" }`
- **Response 200**: `{ "data": { "accessToken": "JWT", "refreshToken": "JWT" } }`
- **Errors**: 401 (invalid/expired refresh token)

### POST /api/v1/auth/logout
- **Auth**: Bearer JWT required
- **Request body**: `{ "refreshToken": "string" }` (to revoke specific token)
- **Response 200**: `{ "data": { "message": "Logged out successfully" } }`

### POST /api/v1/auth/forgot-password
- **Auth**: None
- **Rate limit**: 3 per hour per IP
- **Request body**: `{ "email": "string" }`
- **Response 200**: `{ "data": { "message": "If email exists, reset link sent" } }` (always same response — no email enumeration)

### POST /api/v1/auth/reset-password
- **Auth**: None (reset token in body)
- **Request body**: `{ "token": "string", "password": "string" }`
- **Response 200**: `{ "data": { "message": "Password reset successful" } }`
- **Errors**: 400 (weak password), 401 (invalid/expired token)

---

## Users Endpoints

### GET /api/v1/users/me
- **Auth**: Bearer JWT required
- **Response 200**: Current user profile (exclude passwordHash)

### PATCH /api/v1/users/me
- **Auth**: Bearer JWT required
- **Request body**: `{ "firstName"?: "string", "lastName"?: "string", "avatarUrl"?: "string" }`
- **Response 200**: Updated user profile

### PATCH /api/v1/users/me/password
- **Auth**: Bearer JWT required
- **Request body**: `{ "currentPassword": "string", "newPassword": "string" }`
- **Response 200**: `{ "data": { "message": "Password changed" } }`

### DELETE /api/v1/users/me
- **Auth**: Bearer JWT required
- **Request body**: `{ "password": "string" }` (confirm deletion)
- **Response 204**: No content (soft delete)

### GET /api/v1/users (Admin only)
- **Auth**: Bearer JWT + Admin role
- **Query params**: `page=1`, `limit=20`, `search=string`, `status=active|inactive|banned`
- **Response 200**: Paginated user list

### PATCH /api/v1/users/:id/status (Admin only)
- **Auth**: Bearer JWT + Admin role
- **Request body**: `{ "status": "active|inactive|banned" }`
- **Response 200**: Updated user

---

## Feature-Specific Endpoints

Design endpoints for each entity identified in the data model. For each resource follow this pattern:

```
GET    /api/v1/[resources]           → List (paginated, filterable)
POST   /api/v1/[resources]           → Create
GET    /api/v1/[resources]/:id       → Get single
PUT    /api/v1/[resources]/:id       → Full update
PATCH  /api/v1/[resources]/:id       → Partial update
DELETE /api/v1/[resources]/:id       → Soft delete
```

For each endpoint document:
- Auth requirement
- Rate limit
- Request body / query params / path params
- Response structure
- Possible error codes

---

## Health Endpoints

### GET /health
- **Auth**: None
- **Response**: `{ "status": "ok", "uptime": 3600, "timestamp": "..." }`

### GET /health/db
- **Auth**: None
- **Response**: `{ "status": "ok|error", "database": "ok|error", "latency": 5 }`

### GET /health/redis
- **Auth**: None
- **Response**: `{ "status": "ok|error", "redis": "ok|error", "latency": 1 }`

---

## Rate Limits Summary Table

| Endpoint Pattern | Limit | Window | Per |
|-----------------|-------|--------|-----|
| POST /auth/register | 3 | 1 hour | IP |
| POST /auth/login | 5 | 15 min | IP |
| POST /auth/refresh | 10 | 15 min | IP |
| POST /auth/forgot-password | 3 | 1 hour | IP |
| GET /api/v1/* (public) | 100 | 1 min | IP |
| GET /api/v1/* (authenticated) | 300 | 1 min | User |
| POST/PUT/PATCH (authenticated) | 60 | 1 min | User |
| DELETE (authenticated) | 30 | 1 min | User |
| Admin endpoints | 200 | 1 min | User |

---

## OpenAPI 3.0 Specification

Save complete spec to `.sde/schemas/openapi.yaml`:

```yaml
openapi: 3.0.3
info:
  title: [Project Name] API
  description: REST API for [Project Name]
  version: 1.0.0
  contact:
    name: API Support
    email: admin@example.com

servers:
  - url: http://localhost:3000/api/v1
    description: Local development
  - url: https://api.[domain].com/api/v1
    description: Production

tags:
  - name: auth
    description: Authentication endpoints
  - name: users
    description: User management
  - name: [feature]
    description: [Feature] management

components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT

  schemas:
    ErrorResponse:
      type: object
      required: [statusCode, message, error, timestamp, path]
      properties:
        statusCode:
          type: integer
          example: 400
        message:
          type: string
          example: "Validation failed"
        error:
          type: string
          example: "Bad Request"
        details:
          type: array
          items:
            type: object
            properties:
              field:
                type: string
              message:
                type: string
        timestamp:
          type: string
          format: date-time
        path:
          type: string
        requestId:
          type: string
          format: uuid

    UserResponse:
      type: object
      properties:
        id:
          type: string
          format: uuid
        firstName:
          type: string
        lastName:
          type: string
        email:
          type: string
          format: email
        role:
          type: string
          enum: [user, admin]
        status:
          type: string
          enum: [active, inactive, banned]
        avatarUrl:
          type: string
          nullable: true
        createdAt:
          type: string
          format: date-time
        updatedAt:
          type: string
          format: date-time

    PaginationMeta:
      type: object
      properties:
        total:
          type: integer
        page:
          type: integer
        limit:
          type: integer
        hasNext:
          type: boolean
        hasPrev:
          type: boolean
        nextCursor:
          type: string
          nullable: true

  responses:
    Unauthorized:
      description: Unauthorized
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ErrorResponse'
    Forbidden:
      description: Forbidden
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ErrorResponse'
    NotFound:
      description: Not Found
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ErrorResponse'
    TooManyRequests:
      description: Too Many Requests
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ErrorResponse'

paths:
  /auth/register:
    post:
      tags: [auth]
      summary: Register new user
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [firstName, lastName, email, password]
              properties:
                firstName:
                  type: string
                  minLength: 1
                  maxLength: 100
                lastName:
                  type: string
                  minLength: 1
                  maxLength: 100
                email:
                  type: string
                  format: email
                password:
                  type: string
                  minLength: 8
                  description: Must contain uppercase, number
      responses:
        '201':
          description: User registered
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: object
                    properties:
                      user:
                        $ref: '#/components/schemas/UserResponse'
                      accessToken:
                        type: string
                      refreshToken:
                        type: string
        '400':
          $ref: '#/components/responses/BadRequest'
        '409':
          description: Email already registered
        '429':
          $ref: '#/components/responses/TooManyRequests'

  # [Add all other paths following same pattern]
```

Generate the FULL OpenAPI spec with all paths from the designed endpoints.

---

## Autonomous Actions

1. Save API design document to `.sde/phases/5-api-design.md`
2. Save OpenAPI YAML to `.sde/schemas/openapi.yaml`
3. Create Notion sub-page "API Design — Phase 5"
4. ```bash
   git checkout develop
   git checkout -b feature/5-api-design
   git add .sde/
   git commit -m "docs: REST API design and OpenAPI spec — Phase 5"
   git push origin feature/5-api-design
   ```
5. Update context.json: `currentPhase: 5`, add 5 to `completedPhases`

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 5 COMPLETE — API Design                ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • [N] endpoints designed across [N] resources   ║
║  • Auth endpoints: 6 (register, login, refresh,  ║
║    logout, forgot-password, reset-password)      ║
║  • Rate limiting defined per endpoint type       ║
║  • OpenAPI 3.0 spec generated                    ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • .sde/phases/5-api-design.md                   ║
║  • .sde/schemas/openapi.yaml                     ║
║  • Notion sub-page: "API Design — Phase 5"       ║
║  • Git committed: feature/5-api-design           ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 6 — Project Scaffold                ║
╠══════════════════════════════════════════════════╣
║  [proceed] → scaffold project structure          ║
║  [refine]  → revise API design                   ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
