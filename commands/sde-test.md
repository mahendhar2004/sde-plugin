---
description: Phase 8 — Testing. Generates comprehensive unit tests, integration tests, and frontend component tests targeting 80% coverage. Runs coverage reports and generates additional tests for uncovered code.
---

## ⛔ Phase Guard — Read This First

Before doing ANYTHING else, check:
1. Does `.sde/context.json` exist in the current directory?

If it is missing → STOP immediately and output:
```
⛔ No .sde/context.json found. Run /sde-idea first or run /sde-analyze on an existing codebase.

Make sure you're in the correct project directory.
```
Do NOT proceed past this point.

If it exists → read it and continue.

---

# SDE Test — Phase 8: Testing

## Pre-Flight

1. Read `.sde/phases/7-implementation.md` — list of implemented modules
2. Read `.sde/phases/5-api-design.md` — endpoints to integration test
3. Read `.sde/context.json` — project type

---

## Testing Strategy

| Type | Tool | Target | Location |
|------|------|--------|----------|
| Backend unit | Jest + @nestjs/testing | Every service method | `*.service.spec.ts` |
| Backend integration | Jest + Supertest | Every API endpoint | `test/*.e2e-spec.ts` |
| Frontend component | Vitest + RTL | Every component | `*.test.tsx` |
| Frontend hooks | Vitest | Custom hooks | `*.test.ts` |
| Mobile unit | Jest | Utility functions | `*.test.ts` |

Coverage requirement: **≥ 80%** on ALL metrics (lines, branches, functions, statements)

---

## Backend Unit Tests

### Service Test Pattern

```typescript
// src/modules/auth/tests/auth.service.spec.ts
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { AuthService } from '../auth.service';
import { UsersService } from '../../users/users.service';
import { RefreshToken } from '../entities/refresh-token.entity';
import * as bcrypt from 'bcrypt';

jest.mock('bcrypt');

const mockUsersService = {
  findByEmail: jest.fn(),
  findById: jest.fn(),
  create: jest.fn(),
  incrementFailedAttempts: jest.fn(),
  resetFailedAttempts: jest.fn(),
  updateLastLogin: jest.fn(),
};

const mockRefreshTokenRepository = {
  create: jest.fn(),
  save: jest.fn(),
  findOne: jest.fn(),
  find: jest.fn(),
  update: jest.fn(),
  createQueryBuilder: jest.fn(() => ({
    delete: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    execute: jest.fn().mockResolvedValue(undefined),
  })),
};

const mockJwtService = {
  signAsync: jest.fn(),
};

const mockConfigService = {
  get: jest.fn((key: string) => {
    const config: Record<string, string> = {
      JWT_SECRET: 'test-secret-32-chars-minimum-here',
      JWT_REFRESH_SECRET: 'test-refresh-secret-32-chars-here',
    };
    return config[key];
  }),
};

describe('AuthService', () => {
  let service: AuthService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: UsersService, useValue: mockUsersService },
        { provide: JwtService, useValue: mockJwtService },
        { provide: ConfigService, useValue: mockConfigService },
        { provide: getRepositoryToken(RefreshToken), useValue: mockRefreshTokenRepository },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
    jest.clearAllMocks();
  });

  describe('register', () => {
    const registerDto = {
      firstName: 'John',
      lastName: 'Doe',
      email: 'john@example.com',
      password: 'Password123',
    };

    it('should register a new user successfully', async () => {
      const mockUser = { id: 'uuid-1', ...registerDto, passwordHash: 'hashed' };
      mockUsersService.findByEmail.mockResolvedValue(null);
      mockUsersService.create.mockResolvedValue(mockUser);
      (bcrypt.hash as jest.Mock).mockResolvedValue('hashed-password');
      mockJwtService.signAsync.mockResolvedValueOnce('access-token').mockResolvedValueOnce('refresh-token');
      mockRefreshTokenRepository.create.mockReturnValue({});
      mockRefreshTokenRepository.save.mockResolvedValue({});

      const result = await service.register(registerDto);

      expect(result.user).toEqual(mockUser);
      expect(result.accessToken).toBe('access-token');
      expect(result.refreshToken).toBe('refresh-token');
      expect(mockUsersService.findByEmail).toHaveBeenCalledWith(registerDto.email);
      expect(bcrypt.hash).toHaveBeenCalledWith(registerDto.password, 12);
    });

    it('should throw ConflictException if email already exists', async () => {
      mockUsersService.findByEmail.mockResolvedValue({ id: 'existing', email: registerDto.email });

      await expect(service.register(registerDto)).rejects.toThrow(ConflictException);
      expect(mockUsersService.create).not.toHaveBeenCalled();
    });
  });

  describe('login', () => {
    const loginDto = { email: 'john@example.com', password: 'Password123' };

    it('should login successfully with valid credentials', async () => {
      const mockUser = {
        id: 'uuid-1',
        email: loginDto.email,
        passwordHash: 'hashed',
        status: 'active',
        lockedUntil: null,
      };
      mockUsersService.findByEmail.mockResolvedValue(mockUser);
      (bcrypt.compare as jest.Mock).mockResolvedValue(true);
      mockJwtService.signAsync.mockResolvedValueOnce('access').mockResolvedValueOnce('refresh');
      mockRefreshTokenRepository.create.mockReturnValue({});
      mockRefreshTokenRepository.save.mockResolvedValue({});

      const result = await service.login(loginDto);

      expect(result.user).toEqual(mockUser);
      expect(mockUsersService.resetFailedAttempts).toHaveBeenCalledWith(mockUser.id);
      expect(mockUsersService.updateLastLogin).toHaveBeenCalledWith(mockUser.id);
    });

    it('should throw UnauthorizedException for invalid password', async () => {
      const mockUser = { id: 'uuid-1', email: loginDto.email, passwordHash: 'hashed', status: 'active', lockedUntil: null };
      mockUsersService.findByEmail.mockResolvedValue(mockUser);
      (bcrypt.compare as jest.Mock).mockResolvedValue(false);

      await expect(service.login(loginDto)).rejects.toThrow(UnauthorizedException);
      expect(mockUsersService.incrementFailedAttempts).toHaveBeenCalledWith(mockUser.id);
    });

    it('should throw UnauthorizedException for non-existent user', async () => {
      mockUsersService.findByEmail.mockResolvedValue(null);
      await expect(service.login(loginDto)).rejects.toThrow(UnauthorizedException);
    });

    it('should throw ForbiddenException for locked account', async () => {
      const lockedUser = {
        id: 'uuid-1',
        email: loginDto.email,
        passwordHash: 'hashed',
        status: 'active',
        lockedUntil: new Date(Date.now() + 60000), // locked for 1 more minute
      };
      mockUsersService.findByEmail.mockResolvedValue(lockedUser);
      await expect(service.login(loginDto)).rejects.toThrow('Account temporarily locked');
    });
  });

  describe('refresh', () => {
    it('should issue new token pair on valid refresh', async () => {
      const mockToken = {
        id: 'token-id',
        userId: 'user-id',
        tokenHash: 'hashed-token',
        isRevoked: false,
        expiresAt: new Date(Date.now() + 86400000),
        user: { id: 'user-id', email: 'test@test.com', role: 'user' },
      };
      mockRefreshTokenRepository.findOne.mockResolvedValue(mockToken);
      (bcrypt.compare as jest.Mock).mockResolvedValue(true);
      mockJwtService.signAsync.mockResolvedValueOnce('new-access').mockResolvedValueOnce('new-refresh');
      mockRefreshTokenRepository.update.mockResolvedValue(undefined);
      mockRefreshTokenRepository.create.mockReturnValue({});
      mockRefreshTokenRepository.save.mockResolvedValue({});

      const result = await service.refresh('user-id', 'raw-token');

      expect(result.accessToken).toBe('new-access');
      expect(result.refreshToken).toBe('new-refresh');
      expect(mockRefreshTokenRepository.update).toHaveBeenCalledWith(mockToken.id, { isRevoked: true });
    });

    it('should throw if refresh token not found or revoked', async () => {
      mockRefreshTokenRepository.findOne.mockResolvedValue(null);
      await expect(service.refresh('user-id', 'bad-token')).rejects.toThrow(UnauthorizedException);
    });
  });
});
```

---

## Backend Integration Tests

```typescript
// test/auth.e2e-spec.ts
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { HttpExceptionFilter } from '../src/common/filters/http-exception.filter';
import { getRepositoryToken } from '@nestjs/typeorm';
import { User } from '../src/modules/users/entities/user.entity';
import { DataSource } from 'typeorm';

describe('Auth (e2e)', () => {
  let app: INestApplication;
  let dataSource: DataSource;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    app.useGlobalFilters(new HttpExceptionFilter());
    app.setGlobalPrefix('api');
    app.enableVersioning({ type: 1 }); // URI versioning

    await app.init();
    dataSource = app.get(DataSource);
  });

  afterAll(async () => {
    await dataSource.destroy();
    await app.close();
  });

  afterEach(async () => {
    // Clean up test data
    await dataSource.query('DELETE FROM refresh_tokens');
    await dataSource.query('DELETE FROM users WHERE email LIKE \'%@test.com\'');
  });

  const testUser = {
    firstName: 'Test',
    lastName: 'User',
    email: 'test@test.com',
    password: 'Password123!',
  };

  describe('POST /api/v1/auth/register', () => {
    it('should register a new user and return tokens', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send(testUser)
        .expect(201);

      expect(res.body.data).toHaveProperty('accessToken');
      expect(res.body.data).toHaveProperty('refreshToken');
      expect(res.body.data.user.email).toBe(testUser.email);
      expect(res.body.data.user).not.toHaveProperty('passwordHash');
    });

    it('should return 400 for invalid email', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({ ...testUser, email: 'not-an-email' })
        .expect(400);

      expect(res.body.statusCode).toBe(400);
    });

    it('should return 400 for weak password', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send({ ...testUser, password: 'weak' })
        .expect(400);
    });

    it('should return 409 if email already registered', async () => {
      await request(app.getHttpServer()).post('/api/v1/auth/register').send(testUser);
      await request(app.getHttpServer())
        .post('/api/v1/auth/register')
        .send(testUser)
        .expect(409);
    });
  });

  describe('POST /api/v1/auth/login', () => {
    beforeEach(async () => {
      await request(app.getHttpServer()).post('/api/v1/auth/register').send(testUser);
    });

    it('should login with valid credentials', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: testUser.email, password: testUser.password })
        .expect(200);

      expect(res.body.data.accessToken).toBeDefined();
      expect(res.body.data.refreshToken).toBeDefined();
    });

    it('should return 401 for wrong password', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: testUser.email, password: 'WrongPass123' })
        .expect(401);
    });
  });

  describe('Protected route access', () => {
    let accessToken: string;

    beforeEach(async () => {
      await request(app.getHttpServer()).post('/api/v1/auth/register').send(testUser);
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: testUser.email, password: testUser.password });
      accessToken = res.body.data.accessToken;
    });

    it('should access protected route with valid token', async () => {
      await request(app.getHttpServer())
        .get('/api/v1/users/me')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);
    });

    it('should return 401 for protected route without token', async () => {
      await request(app.getHttpServer()).get('/api/v1/users/me').expect(401);
    });

    it('should return 401 for expired/invalid token', async () => {
      await request(app.getHttpServer())
        .get('/api/v1/users/me')
        .set('Authorization', 'Bearer invalid.token.here')
        .expect(401);
    });
  });
});
```

---

## Frontend Component Tests

```typescript
// src/components/auth/__tests__/LoginForm.test.tsx
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { BrowserRouter } from 'react-router-dom';
import { LoginForm } from '../LoginForm';

// Mock the API module
vi.mock('../../../services/api', () => ({
  api: {
    post: vi.fn(),
  },
}));

const renderWithProviders = (component: React.ReactElement) => {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });

  return render(
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        {component}
      </BrowserRouter>
    </QueryClientProvider>,
  );
};

describe('LoginForm', () => {
  beforeEach(() => vi.clearAllMocks());

  it('renders login form with email and password fields', () => {
    renderWithProviders(<LoginForm />);
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /sign in/i })).toBeInTheDocument();
  });

  it('shows validation errors for empty submission', async () => {
    renderWithProviders(<LoginForm />);
    fireEvent.click(screen.getByRole('button', { name: /sign in/i }));

    await waitFor(() => {
      expect(screen.getByText(/email is required/i)).toBeInTheDocument();
    });
  });

  it('shows error for invalid email format', async () => {
    renderWithProviders(<LoginForm />);
    await userEvent.type(screen.getByLabelText(/email/i), 'notanemail');
    fireEvent.click(screen.getByRole('button', { name: /sign in/i }));

    await waitFor(() => {
      expect(screen.getByText(/invalid email/i)).toBeInTheDocument();
    });
  });

  it('submits form with valid credentials', async () => {
    const { api } = await import('../../../services/api');
    (api.post as ReturnType<typeof vi.fn>).mockResolvedValue({
      data: {
        data: {
          accessToken: 'token',
          refreshToken: 'refresh',
          user: { id: '1', email: 'test@test.com' },
        },
      },
    });

    renderWithProviders(<LoginForm />);
    await userEvent.type(screen.getByLabelText(/email/i), 'test@test.com');
    await userEvent.type(screen.getByLabelText(/password/i), 'Password123');
    fireEvent.click(screen.getByRole('button', { name: /sign in/i }));

    await waitFor(() => {
      expect(api.post).toHaveBeenCalledWith('/auth/login', {
        email: 'test@test.com',
        password: 'Password123',
      });
    });
  });

  it('displays error message on failed login', async () => {
    const { api } = await import('../../../services/api');
    (api.post as ReturnType<typeof vi.fn>).mockRejectedValue({
      response: { data: { message: 'Invalid credentials' } },
    });

    renderWithProviders(<LoginForm />);
    await userEvent.type(screen.getByLabelText(/email/i), 'test@test.com');
    await userEvent.type(screen.getByLabelText(/password/i), 'wrongpass');
    fireEvent.click(screen.getByRole('button', { name: /sign in/i }));

    await waitFor(() => {
      expect(screen.getByText(/invalid credentials/i)).toBeInTheDocument();
    });
  });

  it('disables submit button while loading', async () => {
    renderWithProviders(<LoginForm />);
    // Verify button state during submission
    const button = screen.getByRole('button', { name: /sign in/i });
    expect(button).not.toBeDisabled();
  });
});
```

---

## Jest Configuration

### backend/jest.config.ts
```typescript
import type { Config } from 'jest';

const config: Config = {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: 'src',
  testRegex: '.*\\.spec\\.ts$',
  transform: { '^.+\\.(t|j)s$': 'ts-jest' },
  collectCoverageFrom: ['**/*.(t|j)s', '!**/*.module.ts', '!**/main.ts', '!**/*.dto.ts'],
  coverageDirectory: '../coverage',
  testEnvironment: 'node',
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80,
    },
  },
};

export default config;
```

### frontend/vitest.config.ts
```typescript
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      thresholds: {
        global: {
          branches: 80,
          functions: 80,
          lines: 80,
          statements: 80,
        },
      },
      exclude: ['src/main.tsx', 'src/vite-env.d.ts', '**/*.d.ts'],
    },
  },
});
```

---

## Run Tests and Check Coverage

After generating all test files, run:

```bash
# Backend
cd backend && npm test -- --coverage --forceExit 2>&1 | tee /tmp/backend-coverage.txt

# Frontend
cd ../frontend && npm test -- --coverage 2>&1 | tee /tmp/frontend-coverage.txt
```

Parse coverage output. If any metric is below 80%:
1. Identify uncovered files/functions
2. Generate additional tests targeting the uncovered code
3. Re-run until all metrics ≥ 80%

---

## Autonomous Actions

1. Generate ALL test files for every module, service, controller, component, hook
2. Add jest config to backend and vitest config to frontend
3. Run coverage checks
4. Generate additional tests if coverage < 80%
5. Save coverage report summary to `.sde/phases/8-tests.md`
6. ```bash
   git checkout develop
   git checkout -b feature/8-testing
   git add .
   git commit -m "test: comprehensive test suite, 80%+ coverage — Phase 8"
   git push origin feature/8-testing
   ```
7. Update context.json: `currentPhase: 8`, add 8 to `completedPhases`

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 8 COMPLETE — Testing                   ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • Backend coverage:  [N]% (≥80% ✅)            ║
║  • Frontend coverage: [N]% (≥80% ✅)            ║
║  • [N] unit tests                                ║
║  • [N] integration tests                         ║
║  • [N] component tests                           ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • All test files created                        ║
║  • .sde/phases/8-tests.md (coverage report)      ║
║  • Git committed: feature/8-testing              ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 9 — Security Hardening              ║
╠══════════════════════════════════════════════════╣
║  [proceed] → run OWASP security audit            ║
║  [refine]  → improve test coverage               ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
