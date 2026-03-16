---
name: sde-datamodel
description: Phase 4 — Data Model Design. Analyzes PRD features to design normalized ER schema, generates TypeORM entities with full decorators, produces SQL DDL, and defines all indexes and relationships.
---

# SDE Data Model — Phase 4: Data Model Design

## Pre-Flight

1. Read `.sde/phases/1-prd.md` — extract all entities from user stories and features
2. Read `.sde/phases/2-architecture.md` — understand data flow requirements
3. Read `.sde/context.json` — project type, clarifications

---

## Entity Identification

From the PRD features, identify ALL entities. Always include these base entities:

**Universal entities (every project):**
- `User` — the core user account
- `RefreshToken` — stored refresh tokens (hashed)

**Conditional entities:**
- Based on the product's features: extract nouns from user stories
- Every "I want to [create/manage/view] [NOUN]" is likely an entity

Document each entity with:
- Purpose
- Key attributes (brief)
- Relationships

---

## Entity-Relationship Diagram (Text)

```
[User] ─────1────── has many ──── [RefreshToken]
         │
         └──── 1 ── has many ──── [FEATURE_ENTITY]
                         │
                         └──── relationships with other entities

Legend:
──── 1:1 relationship
════ 1:N relationship
╌╌╌╌ N:M relationship (via junction table)
```

Generate the full ER diagram for the specific project based on identified entities.

---

## TypeORM Entities

Generate a complete TypeScript TypeORM entity for EACH identified entity.

### Base Entity (abstract)

Every entity extends this:

```typescript
// src/common/entities/base.entity.ts
import {
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  Column,
} from 'typeorm';

export abstract class BaseEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updatedAt: Date;

  @DeleteDateColumn({ type: 'timestamptz', nullable: true })
  deletedAt: Date | null;
}
```

### User Entity

```typescript
// src/modules/users/entities/user.entity.ts
import { Entity, Column, OneToMany, Index, BeforeInsert, BeforeUpdate } from 'typeorm';
import { Exclude } from 'class-transformer';
import { BaseEntity } from '../../../common/entities/base.entity';
import { RefreshToken } from '../../auth/entities/refresh-token.entity';

export enum UserRole {
  USER = 'user',
  ADMIN = 'admin',
}

export enum UserStatus {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
  BANNED = 'banned',
}

@Entity('users')
export class User extends BaseEntity {
  @Column({ type: 'varchar', length: 100 })
  firstName: string;

  @Column({ type: 'varchar', length: 100 })
  lastName: string;

  @Index({ unique: true })
  @Column({ type: 'varchar', length: 255 })
  email: string;

  @Exclude()
  @Column({ type: 'varchar', length: 255 })
  passwordHash: string;

  @Column({
    type: 'enum',
    enum: UserRole,
    default: UserRole.USER,
  })
  role: UserRole;

  @Column({
    type: 'enum',
    enum: UserStatus,
    default: UserStatus.ACTIVE,
  })
  status: UserStatus;

  @Column({ type: 'varchar', length: 500, nullable: true })
  avatarUrl: string | null;

  @Column({ type: 'timestamptz', nullable: true })
  lastLoginAt: Date | null;

  @Column({ type: 'int', default: 0 })
  failedLoginAttempts: number;

  @Column({ type: 'timestamptz', nullable: true })
  lockedUntil: Date | null;

  @OneToMany(() => RefreshToken, (token) => token.user, { cascade: true })
  refreshTokens: RefreshToken[];

  // Add @OneToMany for feature entities here
}
```

### RefreshToken Entity

```typescript
// src/modules/auth/entities/refresh-token.entity.ts
import { Entity, Column, ManyToOne, JoinColumn, Index } from 'typeorm';
import { BaseEntity } from '../../../common/entities/base.entity';
import { User } from '../../users/entities/user.entity';

@Entity('refresh_tokens')
export class RefreshToken extends BaseEntity {
  @Index()
  @ManyToOne(() => User, (user) => user.refreshTokens, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'user_id' })
  userId: string;

  @Column({ type: 'varchar', length: 500 })
  tokenHash: string;

  @Column({ type: 'timestamptz' })
  expiresAt: Date;

  @Column({ type: 'boolean', default: false })
  isRevoked: boolean;

  @Column({ type: 'varchar', length: 45, nullable: true })
  createdByIp: string | null;

  @Index()
  @Column({ type: 'timestamptz' })
  expiresAtIndex: Date; // denormalized for fast cleanup queries
}
```

### Feature-Specific Entities

Generate entities for ALL entities identified from the PRD. Follow this pattern for each:

```typescript
@Entity('[plural_snake_case_name]')
export class [EntityName] extends BaseEntity {
  // All columns with proper TypeORM decorators
  // All relationships with @ManyToOne, @OneToMany, @ManyToMany
  // All indexes with @Index
  // Enums for status/type fields
  // Nullable fields properly typed as T | null
  // No business logic in entities (use services)
}
```

Rules for all entities:
- Use `uuid` primary keys (not auto-increment integers)
- Add `deletedAt` via BaseEntity for soft deletes on user-facing entities
- Index ALL foreign key columns
- Index columns that appear in WHERE clauses (status, type, userId + dateRange)
- Use `timestamptz` for all timestamps (timezone-aware)
- Use enums for status/type fields
- Set appropriate column lengths (don't default to TEXT for everything)
- Add `@Exclude()` to sensitive columns (passwordHash, tokenHash)

---

## SQL DDL Schema

Generate the complete `CREATE TABLE` statements:

```sql
-- .sde/schemas/database.sql
-- Generated by SDE Plugin — Phase 4: Data Model
-- Project: [name]
-- Date: [date]

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  email VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(20) NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'banned')),
  avatar_url VARCHAR(500),
  last_login_at TIMESTAMPTZ,
  failed_login_attempts INT NOT NULL DEFAULT 0,
  locked_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_role ON users(role);

-- Refresh Tokens
CREATE TABLE refresh_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(500) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  is_revoked BOOLEAN NOT NULL DEFAULT FALSE,
  created_by_ip VARCHAR(45),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);

-- [Feature entity tables go here, following the same pattern]

-- Cleanup function for expired refresh tokens
CREATE OR REPLACE FUNCTION cleanup_expired_tokens() RETURNS void AS $$
BEGIN
  DELETE FROM refresh_tokens WHERE expires_at < NOW() - INTERVAL '1 day';
END;
$$ LANGUAGE plpgsql;
```

---

## Indexes Strategy Summary

| Table | Index | Type | Reason |
|-------|-------|------|--------|
| users | email | UNIQUE (partial: deleted_at IS NULL) | Login lookup |
| users | status | BTR | Filter by active users |
| refresh_tokens | user_id | BTR | FK + frequent join |
| refresh_tokens | expires_at | BTR | Cleanup queries |
| [feature] | user_id | BTR | Filter by owner |
| [feature] | status + created_at | COMPOSITE | List queries with sorting |
| [feature] | [searchable column] | GIN (if full-text) | Search |

---

## TypeORM Migration Setup

Generate migration config in `backend/src/database/`:

```typescript
// backend/src/database/data-source.ts
import { DataSource } from 'typeorm';
import { config } from 'dotenv';

config();

export const AppDataSource = new DataSource({
  type: 'postgres',
  url: process.env.DATABASE_URL,
  entities: ['src/**/*.entity.ts'],
  migrations: ['src/database/migrations/*.ts'],
  synchronize: false, // NEVER true in production
  logging: process.env.NODE_ENV === 'development',
});
```

Add to package.json scripts:
```json
{
  "scripts": {
    "migration:generate": "typeorm-ts-node-commonjs migration:generate -d src/database/data-source.ts",
    "migration:run": "typeorm-ts-node-commonjs migration:run -d src/database/data-source.ts",
    "migration:revert": "typeorm-ts-node-commonjs migration:revert -d src/database/data-source.ts"
  }
}
```

---

## Autonomous Actions

1. Save TypeORM entities and data model to `.sde/phases/4-data-model.md`
2. Save SQL DDL to `.sde/schemas/database.sql`
3. Create entity files in actual project directory (if scaffold already done) OR save to .sde/ for use in scaffold phase
4. Sync to Notion sub-page "Data Model — Phase 4"
5. ```bash
   git checkout develop
   git checkout -b feature/4-data-model
   git add .sde/
   git commit -m "docs: data model design and SQL schema — Phase 4"
   git push origin feature/4-data-model
   ```
6. Update context.json: `currentPhase: 4`, add 4 to `completedPhases`

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 4 COMPLETE — Data Model                ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • [N] entities identified and designed          ║
║  • ER diagram created                            ║
║  • TypeORM entities with full decorators         ║
║  • SQL DDL schema with indexes                   ║
║  • Migration configuration set up               ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • .sde/phases/4-data-model.md                   ║
║  • .sde/schemas/database.sql                     ║
║  • Notion sub-page: "Data Model — Phase 4"       ║
║  • Git committed: feature/4-data-model           ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 5 — API Design                      ║
╠══════════════════════════════════════════════════╣
║  [proceed] → start API design                    ║
║  [refine]  → revise data model                   ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
