---
description: Database seed data generation — creates realistic seed scripts for development, testing, and demo environments using TypeScript with NestJS CommandRunner
allowed-tools: Agent, Read, Write, Bash
disable-model-invocation: true
---

# SDE Plugin — Database Seed Generator

You generate realistic, consistent seed data for development and testing environments. Seed data must be realistic enough to test edge cases, diverse enough to catch UI layout issues, and deterministic so tests are reproducible.

## Load Context
Read `.sde/schemas/database.sql` and `.sde/phases/4-data-model.md` to understand all entities and relationships.

---

## Seed Architecture

```
backend/src/database/seeds/
├── seed.command.ts          # NestJS CommandRunner — entry point
├── seed.module.ts           # module wiring
├── factories/               # data factories (use @faker-js/faker)
│   ├── user.factory.ts
│   ├── [entity].factory.ts
│   └── index.ts
└── seeders/
    ├── development.seeder.ts  # full dataset for dev
    ├── test.seeder.ts         # minimal, deterministic for tests
    └── demo.seeder.ts         # polished data for demos/screenshots
```

---

## Factory Pattern (Faker-based)

```typescript
// src/database/seeds/factories/user.factory.ts
import { faker } from '@faker-js/faker';
import { User } from '../../modules/users/entities/user.entity';
import * as bcrypt from 'bcrypt';

export class UserFactory {
  static async build(overrides: Partial<User> = {}): Promise<Partial<User>> {
    return {
      email: faker.internet.email().toLowerCase(),
      name: faker.person.fullName(),
      passwordHash: await bcrypt.hash('Password123!', 12), // consistent dev password
      isActive: true,
      avatarUrl: faker.image.avatar(),
      createdAt: faker.date.past({ years: 2 }),
      ...overrides,
    };
  }

  static async buildMany(count: number, overrides: Partial<User> = {}): Promise<Partial<User>[]> {
    return Promise.all(Array.from({ length: count }, () => this.build(overrides)));
  }

  // Named presets for specific scenarios
  static async buildAdmin(): Promise<Partial<User>> {
    return this.build({ email: 'admin@example.com', role: 'admin' });
  }

  static async buildInactive(): Promise<Partial<User>> {
    return this.build({ isActive: false });
  }
}
```

---

## Seed Command (NestJS CLI)

```typescript
// src/database/seeds/seed.command.ts
import { Command, CommandRunner, Option } from 'nest-commander';
import { Injectable } from '@nestjs/common';
import { DevelopmentSeeder } from './seeders/development.seeder';
import { TestSeeder } from './seeders/test.seeder';
import { DemoSeeder } from './seeders/demo.seeder';

@Injectable()
@Command({
  name: 'seed',
  description: 'Seed the database with data',
})
export class SeedCommand extends CommandRunner {
  constructor(
    private readonly devSeeder: DevelopmentSeeder,
    private readonly testSeeder: TestSeeder,
    private readonly demoSeeder: DemoSeeder,
  ) { super(); }

  @Option({ flags: '-e, --env [env]', description: 'Environment: dev|test|demo', defaultValue: 'dev' })
  parseEnv(val: string) { return val; }

  @Option({ flags: '-c, --clean', description: 'Clean database before seeding', defaultValue: false })
  parseClean(val: boolean) { return val; }

  async run(_: string[], options: { env: string; clean: boolean }): Promise<void> {
    const { env, clean } = options;
    const seeder = { dev: this.devSeeder, test: this.testSeeder, demo: this.demoSeeder }[env];

    if (!seeder) throw new Error(`Unknown environment: ${env}`);

    if (clean) {
      console.log('🗑️  Cleaning database...');
      await seeder.clean();
    }

    console.log(`🌱 Seeding for ${env}...`);
    await seeder.seed();
    console.log('✅ Seeding complete!');
  }
}
```

---

## Development Seeder (Realistic Volume)

```typescript
// seeders/development.seeder.ts
@Injectable()
export class DevelopmentSeeder {
  constructor(private dataSource: DataSource) {}

  async seed(): Promise<void> {
    // 1. Admin user (always the same — easy to log in with)
    await this.createUser({ email: 'admin@example.com', role: 'admin', name: 'Admin User' });

    // 2. Your personal dev account
    await this.createUser({ email: 'dev@example.com', role: 'user', name: 'Dev User' });

    // 3. Realistic user pool
    const users = await UserFactory.buildMany(50);
    const createdUsers = await this.dataSource.getRepository(User).save(users);

    // 4. Seed all other entities with realistic relationships
    // [generated based on actual data model]
    // Each entity seeded in dependency order (parents before children)

    console.log(`  ✓ ${createdUsers.length + 2} users`);
    // ... log counts for all entities
  }

  async clean(): Promise<void> {
    // Truncate in reverse dependency order
    const entities = this.dataSource.entityMetadatas.reverse();
    for (const entity of entities) {
      await this.dataSource.query(`TRUNCATE TABLE "${entity.tableName}" RESTART IDENTITY CASCADE`);
    }
  }
}
```

---

## Test Seeder (Deterministic)

```typescript
// seeders/test.seeder.ts
// Uses faker.seed(123) — always produces the same data
// Minimal data — just enough for every test scenario

@Injectable()
export class TestSeeder {
  async seed(): Promise<void> {
    faker.seed(123); // deterministic

    // One of each user type
    await this.createUser({ id: 'test-admin-id', email: 'admin@test.com', role: 'admin' });
    await this.createUser({ id: 'test-user-id', email: 'user@test.com', role: 'user' });
    await this.createUser({ id: 'test-inactive-id', email: 'inactive@test.com', isActive: false });

    // Edge case data: empty strings handled, max length values, special chars
    // [generated based on entities with edge cases for each field]
  }
}
```

---

## Demo Seeder (Polished for Screenshots)

```typescript
// seeders/demo.seeder.ts
// Curated data: realistic names, no "foo/bar/test", good for demos

@Injectable()
export class DemoSeeder {
  async seed(): Promise<void> {
    // Named personas (not random) — tell a coherent story
    const personas = [
      { email: 'sarah.chen@company.com', name: 'Sarah Chen', role: 'admin' },
      { email: 'alex.kumar@company.com', name: 'Alex Kumar', role: 'user' },
      { email: 'jamie.rivera@company.com', name: 'Jamie Rivera', role: 'user' },
    ];
    // Curated data that looks good in screenshots
    // Recent activity (last 30 days)
    // Mix of statuses (active, pending, completed)
  }
}
```

---

## package.json Scripts

```json
{
  "scripts": {
    "seed": "ts-node -r tsconfig-paths/register src/database/seeds/seed.command.ts seed",
    "seed:dev": "npm run seed -- --env dev",
    "seed:dev:clean": "npm run seed -- --env dev --clean",
    "seed:test": "npm run seed -- --env test --clean",
    "seed:demo": "npm run seed -- --env demo --clean"
  }
}
```

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ SEED SCRIPTS COMPLETE                        ║
╠══════════════════════════════════════════════════╣
║  • Factories: [N] entity factories created       ║
║  • Dev seeder: [N] users, [N] [entities]         ║
║  • Test seeder: deterministic, faker.seed(123)   ║
║  • Demo seeder: polished persona-based data      ║
║  • package.json scripts added                    ║
╠══════════════════════════════════════════════════╣
║  Run: npm run seed:dev:clean                     ║
╠══════════════════════════════════════════════════╣
║  [proceed] → run seeds now                       ║
║  [refine]  → adjust data volumes or personas     ║
║  [custom]  → describe specific seed requirements ║
╚══════════════════════════════════════════════════╝
```
