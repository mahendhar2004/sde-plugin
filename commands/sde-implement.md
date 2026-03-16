---
description: Phase 7 — Implementation. Generates all NestJS modules, React components and pages, Expo mobile screens, and admin dashboard — one complete working feature at a time, following SOLID and Clean Architecture principles.
---

## ⛔ Phase Guard — Read This First

Before doing ANYTHING else, check:
1. Does `.sde/context.json` exist in the current directory?
2. Does the `.sde/phases/` directory exist and contain at least `0-idea.md`?

If `.sde/context.json` is missing OR the `.sde/phases/` directory does not exist or is empty → STOP immediately and output:
```
⛔ Run /sde-scaffold before running /sde-implement.

Make sure you're in the correct project directory and have run the prior phases.
```
Do NOT proceed past this point.

If both conditions are met → read ALL phase files in `.sde/phases/` and continue.

---

# SDE Implement — Phase 7: Full Implementation

## Pre-Flight

1. Read ALL prior phase documents from `.sde/phases/`
2. Read `.sde/context.json` — project type determines which agents spawn
3. Confirm scaffold exists (phase 6 complete)

---

## Implementation Strategy

Work module by module. For each feature identified in the PRD:
1. Implement backend module completely (entity, repository, service, controller, DTOs)
2. Implement frontend feature completely (page, components, hooks, types)
3. Implement mobile screen if applicable
4. Commit after each complete feature

---

## Backend Implementation Pattern

For EACH resource from the data model and API design:

### Module Structure
```
src/modules/[feature]/
├── [feature].module.ts
├── [feature].controller.ts
├── [feature].service.ts
├── [feature].repository.ts         # TypeORM custom repository
├── entities/
│   └── [feature].entity.ts
├── dto/
│   ├── create-[feature].dto.ts
│   ├── update-[feature].dto.ts
│   ├── [feature]-response.dto.ts
│   └── [feature]-query.dto.ts
└── tests/
    ├── [feature].service.spec.ts
    └── [feature].controller.spec.ts
```

### Auth Module (Complete Implementation)

#### auth.module.ts
```typescript
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './strategies/jwt.strategy';
import { JwtRefreshStrategy } from './strategies/jwt-refresh.strategy';
import { RefreshToken } from './entities/refresh-token.entity';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([RefreshToken]),
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_SECRET'),
        signOptions: { expiresIn: '15m' },
      }),
      inject: [ConfigService],
    }),
    UsersModule,
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy, JwtRefreshStrategy],
  exports: [AuthService, JwtModule],
})
export class AuthModule {}
```

#### auth.service.ts
```typescript
import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { UsersService } from '../users/users.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshToken } from './entities/refresh-token.entity';
import { User } from '../users/entities/user.entity';

const BCRYPT_ROUNDS = 12;

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    @InjectRepository(RefreshToken)
    private readonly refreshTokenRepository: Repository<RefreshToken>,
  ) {}

  async register(dto: RegisterDto): Promise<{ user: User; accessToken: string; refreshToken: string }> {
    const existing = await this.usersService.findByEmail(dto.email);
    if (existing) throw new ConflictException('Email already registered');

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_ROUNDS);
    const user = await this.usersService.create({ ...dto, passwordHash });

    const tokens = await this.generateTokenPair(user);
    await this.storeRefreshToken(user.id, tokens.refreshToken);

    return { user, ...tokens };
  }

  async login(dto: LoginDto, ip?: string): Promise<{ user: User; accessToken: string; refreshToken: string }> {
    const user = await this.usersService.findByEmail(dto.email);

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    // Check if account is locked
    if (user.lockedUntil && user.lockedUntil > new Date()) {
      throw new ForbiddenException('Account temporarily locked. Try again later.');
    }

    const isPasswordValid = await bcrypt.compare(dto.password, user.passwordHash);

    if (!isPasswordValid) {
      await this.usersService.incrementFailedAttempts(user.id);
      throw new UnauthorizedException('Invalid credentials');
    }

    // Reset failed attempts on success
    await this.usersService.resetFailedAttempts(user.id);
    await this.usersService.updateLastLogin(user.id);

    const tokens = await this.generateTokenPair(user);
    await this.storeRefreshToken(user.id, tokens.refreshToken, ip);

    return { user, ...tokens };
  }

  async refresh(userId: string, rawRefreshToken: string): Promise<{ accessToken: string; refreshToken: string }> {
    const stored = await this.refreshTokenRepository.findOne({
      where: { userId, isRevoked: false },
      relations: ['user'],
    });

    if (!stored || stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const isValid = await bcrypt.compare(rawRefreshToken, stored.tokenHash);
    if (!isValid) throw new UnauthorizedException('Invalid refresh token');

    // Rotate — revoke old, issue new
    await this.refreshTokenRepository.update(stored.id, { isRevoked: true });

    const tokens = await this.generateTokenPair(stored.user);
    await this.storeRefreshToken(userId, tokens.refreshToken);

    return tokens;
  }

  async logout(userId: string, rawRefreshToken: string): Promise<void> {
    const tokens = await this.refreshTokenRepository.find({ where: { userId, isRevoked: false } });
    for (const token of tokens) {
      const match = await bcrypt.compare(rawRefreshToken, token.tokenHash);
      if (match) {
        await this.refreshTokenRepository.update(token.id, { isRevoked: true });
        return;
      }
    }
  }

  private async generateTokenPair(user: User): Promise<{ accessToken: string; refreshToken: string }> {
    const payload = { sub: user.id, email: user.email, role: user.role };

    const [accessToken, refreshToken] = await Promise.all([
      this.jwtService.signAsync(payload),
      this.jwtService.signAsync(payload, {
        secret: this.configService.get<string>('JWT_REFRESH_SECRET'),
        expiresIn: '7d',
      }),
    ]);

    return { accessToken, refreshToken };
  }

  private async storeRefreshToken(userId: string, rawToken: string, ip?: string): Promise<void> {
    const tokenHash = await bcrypt.hash(rawToken, BCRYPT_ROUNDS);
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    const refreshToken = this.refreshTokenRepository.create({
      userId,
      tokenHash,
      expiresAt,
      createdByIp: ip || null,
    });

    await this.refreshTokenRepository.save(refreshToken);

    // Cleanup old expired tokens for this user
    await this.refreshTokenRepository
      .createQueryBuilder()
      .delete()
      .where('userId = :userId AND (expiresAt < :now OR isRevoked = true)', {
        userId,
        now: new Date(),
      })
      .execute();
  }
}
```

#### DTOs

```typescript
// create-[feature].dto.ts pattern
import { IsString, IsEmail, MinLength, MaxLength, IsOptional, IsEnum } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class RegisterDto {
  @ApiProperty({ example: 'John' })
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  firstName: string;

  @ApiProperty({ example: 'Doe' })
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  lastName: string;

  @ApiProperty({ example: 'john@example.com' })
  @IsEmail()
  email: string;

  @ApiProperty({ minLength: 8 })
  @IsString()
  @MinLength(8)
  @MaxLength(72) // bcrypt max
  password: string;
}

export class LoginDto {
  @ApiProperty()
  @IsEmail()
  email: string;

  @ApiProperty()
  @IsString()
  password: string;
}
```

#### JWT Strategies

```typescript
// strategies/jwt.strategy.ts
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { UsersService } from '../../users/users.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    configService: ConfigService,
    private usersService: UsersService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('JWT_SECRET'),
    });
  }

  async validate(payload: { sub: string; email: string; role: string }) {
    const user = await this.usersService.findById(payload.sub);
    if (!user || user.status !== 'active') {
      throw new UnauthorizedException();
    }
    return user;
  }
}
```

---

## Feature Module Pattern

For each feature entity, generate the complete module following this pattern:

### [Feature].service.ts pattern
```typescript
@Injectable()
export class [Feature]Service {
  constructor(
    @InjectRepository([Feature])
    private readonly [feature]Repository: Repository<[Feature]>,
  ) {}

  async create(userId: string, dto: Create[Feature]Dto): Promise<[Feature]> {
    try {
      const entity = this.[feature]Repository.create({ ...dto, userId });
      return await this.[feature]Repository.save(entity);
    } catch (error) {
      if (error.code === '23505') { // Unique violation
        throw new ConflictException('[Feature] already exists');
      }
      throw error;
    }
  }

  async findAll(userId: string, query: [Feature]QueryDto): Promise<{ data: [Feature][]; total: number }> {
    const qb = this.[feature]Repository.createQueryBuilder('[feature]')
      .where('[feature].userId = :userId', { userId })
      .andWhere('[feature].deletedAt IS NULL');

    if (query.search) {
      qb.andWhere('[feature].name ILIKE :search', { search: `%${query.search}%` });
    }

    const [data, total] = await qb
      .skip((query.page - 1) * query.limit)
      .take(query.limit)
      .orderBy(`[feature].${query.sortBy || 'createdAt'}`, query.sortOrder || 'DESC')
      .getManyAndCount();

    return { data, total };
  }

  async findOne(id: string, userId: string): Promise<[Feature]> {
    const entity = await this.[feature]Repository.findOne({
      where: { id, userId, deletedAt: null },
    });
    if (!entity) throw new NotFoundException('[Feature] not found');
    return entity;
  }

  async update(id: string, userId: string, dto: Update[Feature]Dto): Promise<[Feature]> {
    const entity = await this.findOne(id, userId);
    Object.assign(entity, dto);
    return this.[feature]Repository.save(entity);
  }

  async remove(id: string, userId: string): Promise<void> {
    const entity = await this.findOne(id, userId);
    await this.[feature]Repository.softDelete(entity.id);
  }
}
```

---

## Frontend Implementation Pattern

For each feature, generate:

### Page Component
```typescript
// src/pages/[Feature]sPage.tsx
import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { [Feature]List } from '../components/[feature]/[Feature]List';
import { Create[Feature]Modal } from '../components/[feature]/Create[Feature]Modal';
import { use[Feature]s } from '../hooks/use[Feature]s';
import { PageHeader } from '../components/layout/PageHeader';

export function [Feature]sPage() {
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const { [feature]s, isLoading, error } = use[Feature]s();

  if (isLoading) return <div className="flex items-center justify-center h-64">
    <div className="animate-spin h-8 w-8 border-2 border-primary-500 rounded-full border-t-transparent" />
  </div>;

  if (error) return <div className="text-red-500 p-4">Failed to load. Please try again.</div>;

  return (
    <div className="container mx-auto px-4 py-8">
      <PageHeader
        title="[Feature]s"
        action={{ label: 'Create [Feature]', onClick: () => setIsCreateOpen(true) }}
      />
      <[Feature]List items={[feature]s} />
      <Create[Feature]Modal
        open={isCreateOpen}
        onClose={() => setIsCreateOpen(false)}
      />
    </div>
  );
}
```

### Custom Hook
```typescript
// src/hooks/use[Feature]s.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../services/api';
import type { [Feature], Create[Feature]Dto } from '../types/[feature]';

export function use[Feature]s() {
  const queryClient = useQueryClient();

  const { data, isLoading, error } = useQuery({
    queryKey: ['[feature]s'],
    queryFn: async () => {
      const response = await api.get('/[feature]s');
      return response.data.data as [Feature][];
    },
  });

  const createMutation = useMutation({
    mutationFn: async (dto: Create[Feature]Dto) => {
      const response = await api.post('/[feature]s', dto);
      return response.data.data as [Feature];
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['[feature]s'] });
    },
  });

  return {
    [feature]s: data ?? [],
    isLoading,
    error,
    create: createMutation.mutate,
    isCreating: createMutation.isPending,
  };
}
```

---

## Mobile Screen Pattern (if applicable)

```typescript
// src/screens/[Feature]Screen.tsx
import React from 'react';
import { View, Text, FlatList, Pressable, StyleSheet, ActivityIndicator } from 'react-native';
import { useQuery } from '@tanstack/react-query';
import { api } from '../services/api';

export function [Feature]Screen() {
  const { data, isLoading } = useQuery({
    queryKey: ['[feature]s'],
    queryFn: () => api.get('/[feature]s').then(r => r.data.data),
  });

  if (isLoading) return (
    <View style={styles.center}>
      <ActivityIndicator size="large" color="#3b82f6" />
    </View>
  );

  return (
    <View style={styles.container}>
      <FlatList
        data={data}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <View style={styles.card}>
            <Text style={styles.title}>{item.name}</Text>
          </View>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#f9fafb' },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  card: { backgroundColor: 'white', margin: 8, padding: 16, borderRadius: 8, elevation: 2 },
  title: { fontSize: 16, fontWeight: '600', color: '#111827' },
});
```

---

## Autonomous Actions

1. Generate ALL modules listed in the data model and API design
2. Commit after each feature module is complete:
   ```bash
   git add src/modules/[feature]/
   git commit -m "feat: implement [feature] module — CRUD + tests"
   ```
3. Save implementation log to `.sde/phases/7-implementation.md` tracking what was built
4. Update context.json: `currentPhase: 7`, add 7 to `completedPhases`
5. Final commit:
   ```bash
   git add .
   git commit -m "feat: complete Phase 7 implementation"
   git push origin feature/7-implementation
   ```

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 7 COMPLETE — Implementation            ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • [N] backend modules implemented               ║
║  • [N] frontend pages + components               ║
║  • [N] custom hooks                              ║
║  • [N] mobile screens (if applicable)            ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • All source files created                      ║
║  • .sde/phases/7-implementation.md               ║
║  • Git committed: feature/7-implementation       ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 8 — Testing                         ║
╠══════════════════════════════════════════════════╣
║  [proceed] → generate tests (80% coverage)       ║
║  [refine]  → improve implementation              ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
