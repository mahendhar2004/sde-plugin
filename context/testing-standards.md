# SDE Plugin — Testing Standards

Single source of truth for testing patterns, configuration, and coverage requirements across all projects.

---

## Coverage Requirements

| Layer | Minimum | Target |
|-------|---------|--------|
| Services (business logic) | 90% | 100% |
| Controllers | 80% | 90% |
| Repositories | 70% | 80% |
| React components | 80% | 90% |
| React hooks | 85% | 95% |
| Utilities/helpers | 95% | 100% |
| **Overall** | **80%** | **85%** |

Auth flows, payment flows, data mutations → 100% required.

---

## Jest Configuration (Backend)

```typescript
// jest.config.ts
export default {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: 'src',
  testRegex: '.*\\.spec\\.ts$',
  transform: { '^.+\\.(t|j)s$': 'ts-jest' },
  collectCoverageFrom: ['**/*.(t|j)s', '!**/node_modules/**', '!**/*.module.ts', '!**/main.ts'],
  coverageDirectory: '../coverage',
  testEnvironment: 'node',
  coverageThreshold: {
    global: { branches: 80, functions: 80, lines: 80, statements: 80 },
    './src/modules/auth/**': { branches: 100, functions: 100, lines: 100, statements: 100 },
  },
};
```

## Vitest Configuration (Frontend)

```typescript
// vite.config.ts (add test section)
test: {
  globals: true,
  environment: 'jsdom',
  setupFiles: './src/test/setup.ts',
  coverage: {
    provider: 'v8',
    reporter: ['text', 'lcov', 'html'],
    thresholds: { lines: 80, functions: 80, branches: 80, statements: 80 },
    exclude: ['src/test/**', 'src/types/**', 'src/main.tsx'],
  },
}
```

---

## Test File Location Convention

```
# Backend: colocated with source
src/modules/users/users.service.ts
src/modules/users/users.service.spec.ts       ← unit test
src/modules/users/users.controller.spec.ts    ← unit test

# Backend: integration tests
test/auth.e2e-spec.ts
test/users.e2e-spec.ts

# Frontend: colocated with component
src/components/UserCard.tsx
src/components/UserCard.test.tsx

# Shared test utilities
src/test/setup.ts
src/test/factories/
src/test/helpers/
```

---

## Test Setup Files

### Backend (test/setup.ts)
```typescript
import { DataSource } from 'typeorm';

let dataSource: DataSource;

export async function createTestDatabase() {
  dataSource = new DataSource({
    type: 'postgres',
    url: process.env.DATABASE_URL || 'postgresql://test:test@localhost:5432/testdb',
    entities: ['src/**/*.entity.ts'],
    synchronize: true,  // OK for tests only
  });
  await dataSource.initialize();
  return dataSource;
}

export async function clearDatabase() {
  const entities = dataSource.entityMetadatas;
  for (const entity of entities.reverse()) {
    await dataSource.query(`TRUNCATE TABLE "${entity.tableName}" CASCADE`);
  }
}

export function getDataSource() { return dataSource; }
```

### Frontend (src/test/setup.ts)
```typescript
import '@testing-library/jest-dom';
import { cleanup } from '@testing-library/react';
import { afterEach, vi } from 'vitest';
import { QueryClient } from '@tanstack/react-query';

afterEach(() => {
  cleanup();
});

// Mock window.matchMedia
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation((query) => ({
    matches: false, media: query, onchange: null,
    addListener: vi.fn(), removeListener: vi.fn(),
    addEventListener: vi.fn(), removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
});

// TestProviders wrapper
export function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0 },
      mutations: { retry: false },
    },
  });
}
```

---

## Test Patterns to Always Follow

### 1. AAA Pattern (Arrange, Act, Assert)
```typescript
it('should do X when Y', async () => {
  // Arrange
  const user = createMockUser({ email: 'test@example.com' });
  mockRepo.findByEmail.mockResolvedValue(null);
  mockRepo.create.mockResolvedValue(user);

  // Act
  const result = await service.create({ email: 'test@example.com', password: 'Pass123!' });

  // Assert
  expect(result.email).toBe('test@example.com');
  expect(mockRepo.create).toHaveBeenCalledTimes(1);
});
```

### 2. Test description format
```typescript
describe('[ClassName]', () => {
  describe('[methodName]', () => {
    it('[expected behavior] when [condition]', () => { ... });
    it('throws [ErrorType] when [condition]', () => { ... });
    it('returns [result] for [input scenario]', () => { ... });
  });
});
```

### 3. Always test these scenarios
For every service method:
- ✅ Happy path (normal success case)
- ✅ Resource not found (throws NotFoundException)
- ✅ Unauthorized/forbidden (throws ForbiddenException)
- ✅ Duplicate/conflict (throws ConflictException)
- ✅ Invalid input (validation error)
- ✅ Database error handling

For every API endpoint:
- ✅ 200/201 success with correct response shape
- ✅ 400 invalid input (missing required fields, wrong types)
- ✅ 401 missing/invalid token
- ✅ 403 wrong role or ownership
- ✅ 404 resource not found
- ✅ 409 conflict (if applicable)
- ✅ 429 rate limit (for auth endpoints)

---

## Factory Pattern (mandatory — never hardcode test data)

```typescript
// test/factories/user.factory.ts
import { User } from '../../src/modules/users/entities/user.entity';

let seq = 0;
const next = () => ++seq;

export function createMockUser(overrides: Partial<User> = {}): User {
  const n = next();
  return Object.assign(new User(), {
    id: `user-uuid-${n}`,
    email: `user${n}@example.com`,
    passwordHash: '$2b$12$validHashedPasswordForTesting',
    isActive: true,
    createdAt: new Date('2024-01-01'),
    updatedAt: new Date('2024-01-01'),
    deletedAt: null,
    ...overrides,
  });
}

// Reset sequence between test suites
export function resetFactorySequence() { seq = 0; }
```

---

## Mock Patterns

```typescript
// Mock NestJS service in unit test
const mockUsersService = {
  findById: jest.fn(),
  create: jest.fn(),
  update: jest.fn(),
  delete: jest.fn(),
};

// Mock API in React tests (vitest)
vi.mock('../services/api', () => ({
  usersApi: {
    list: vi.fn().mockResolvedValue({ data: [createMockUser()], meta: { total: 1 } }),
    getById: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
  },
}));

// Mock React Query hook
vi.mock('../hooks/useUsers', () => ({
  useUsers: vi.fn().mockReturnValue({
    data: { items: [createMockUser()], total: 1 },
    isLoading: false,
    error: null,
  }),
}));
```
