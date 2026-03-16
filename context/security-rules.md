# SDE Plugin — Security Rules

Non-negotiable security rules applied by every agent on every project. These are not guidelines — they are hard requirements.

---

## Rule 1: Never Trust Input

Every piece of data from outside the system is untrusted until validated:
- HTTP request body → validate with class-validator DTO
- HTTP query params → validate with query DTO
- Path params → use NestJS pipes (ParseUUIDPipe, ParseIntPipe)
- File uploads → validate MIME type, size, extension
- JWT claims → never trust without verification
- Environment variables → validate at startup (fail fast if missing)

```typescript
// Validate env at startup — crash if critical vars missing
function validateConfig(config: Record<string, unknown>) {
  if (!config.JWT_SECRET || String(config.JWT_SECRET).length < 32) {
    throw new Error('JWT_SECRET must be at least 32 characters');
  }
  if (!config.DATABASE_URL) throw new Error('DATABASE_URL is required');
  return config;
}
```

---

## Rule 2: Secrets Management

```
✅ Load from environment variables only
✅ .env.example has placeholder values (not real secrets)
✅ .gitignore includes: .env, .env.*, *.pem, *.key, *.pfx
✅ Never log secrets (even partially)
✅ JWT secrets minimum 32 random characters
✅ Rotate secrets by changing env var + redeploying (no code change needed)

❌ NEVER hardcode secrets in source code
❌ NEVER commit .env files
❌ NEVER put secrets in Docker ENV instructions
❌ NEVER put secrets in GitHub Actions env (use secrets context)
❌ NEVER include secrets in error messages or API responses
```

---

## Rule 3: Authentication Rules

```
Access token:  15 min TTL, contains { sub, email, roles }
Refresh token: 7 day TTL, stored as bcrypt(12) hash in DB
Logout:        DELETE refresh token from DB (not just client-side)
Password change: DELETE all refresh tokens for user
Refresh:       Rotation (invalidate old, issue new pair)
JWT algorithm: HS256 minimum, RS256 preferred for future
```

Never:
- Return `passwordHash` in any API response
- Store access tokens in DB (they're stateless by design)
- Use symmetric secrets shorter than 32 chars
- Skip token expiry validation

---

## Rule 4: Authorization — Always Check Ownership

After authentication, always verify the user owns the resource:

```typescript
// Wrong: assumes authenticated = authorized
async updatePost(id: string, dto: UpdatePostDto, req: Request) {
  return this.postsService.update(id, dto); // ❌ no ownership check
}

// Right: verify ownership in service layer
async updatePost(postId: string, dto: UpdatePostDto, userId: string) {
  const post = await this.postsRepo.findById(postId);
  if (!post) throw new NotFoundException();
  if (post.authorId !== userId) throw new ForbiddenException(); // ✅
  return this.postsRepo.update(postId, dto);
}
```

---

## Rule 5: Rate Limiting Tiers (apply to every project)

```typescript
// Apply globally in app.module.ts
ThrottlerModule.forRoot([
  { name: 'global', ttl: 60_000, limit: 60 },     // 60 req/min global
]),

// Override on auth endpoints
@Throttle({ default: { ttl: 60_000, limit: 5 } })  // 5 req/min
@Post('login')

@Throttle({ default: { ttl: 3_600_000, limit: 3 } })  // 3 req/hour
@Post('forgot-password')
```

---

## Rule 6: Response Safety

Never return:
- `passwordHash`, `passwordSalt`
- Raw database error messages (TypeORM errors)
- Stack traces in production
- Internal IDs or UUIDs that expose system structure when not necessary
- Other users' data

Always use Response DTOs with `@Expose()` and `excludeExtraneousValues: true`:
```typescript
export class UserResponseDto {
  @Expose() id: string;
  @Expose() email: string;
  @Expose() name: string;
  @Expose() createdAt: Date;
  // passwordHash is NOT @Expose() — automatically excluded
}
```

---

## Rule 7: SQL Injection Prevention

TypeORM parameterized queries are safe. String interpolation is dangerous:

```typescript
// ✅ Safe
repo.findOne({ where: { email: userInput } })
repo.createQueryBuilder('u').where('u.email = :email', { email: userInput })

// ❌ DANGEROUS — never do this
repo.query(`SELECT * FROM users WHERE email = '${userInput}'`)
```

---

## Rule 8: CORS Configuration

```typescript
app.enableCors({
  origin: process.env.CORS_ORIGINS?.split(',') ?? ['http://localhost:5173'],
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-correlation-id'],
  credentials: true,
  maxAge: 86400,
});
// NEVER: origin: '*' in production
```

---

## Rule 9: Security Headers (Helmet)

```typescript
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", 'data:', 'https:'],
      connectSrc: ["'self'", process.env.API_URL ?? ''],
      fontSrc: ["'self'", 'https://fonts.gstatic.com'],
      frameSrc: ["'none'"],
      objectSrc: ["'none'"],
    },
  },
  crossOriginEmbedderPolicy: false, // may break if needed
  hsts: { maxAge: 31536000, includeSubDomains: true, preload: true },
  noSniff: true,
  xssFilter: true,
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
}));
```

---

## Rule 10: File Upload Safety

```typescript
// multer config for file uploads
const upload = multer({
  storage: multer.memoryStorage(), // never write to disk on server
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB max
  fileFilter: (req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
    if (allowed.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new BadRequestException(`File type '${file.mimetype}' not allowed`));
    }
  },
});

// After upload: re-validate magic bytes (MIME sniffing)
// Then: upload to S3 with random UUID filename (never use original filename)
const s3Key = `uploads/${uuidv4()}/${Date.now()}-${sanitizeFilename(file.originalname)}`;
```

---

## Security Checklist (run before every production deploy)

```
Authentication & Authorization:
□ All private routes have @UseGuards(JwtAuthGuard)
□ All resources have ownership checks in service layer
□ Admin routes have @Roles('admin') guard
□ JWT secrets are >= 32 chars and from environment

Input & Output:
□ Every POST/PUT/PATCH endpoint has a DTO with class-validator
□ All query params validated
□ No raw entity returned (all via response DTOs)
□ No PII or secrets in logs

Infrastructure:
□ Helmet enabled
□ CORS restricted to known origins
□ Rate limiting on auth endpoints
□ npm audit returns no high/critical findings
□ .env.example has no real secrets
□ .gitignore covers all secret file patterns
```
