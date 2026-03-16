# SDE Plugin — Database Design Standards

Single source of truth for PostgreSQL + TypeORM design patterns. Every agent working on data models must follow these.

---

## Entity Base Class (use for ALL entities)

```typescript
// src/common/entities/base.entity.ts
import { PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn, DeleteDateColumn } from 'typeorm';

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

Every entity extends BaseEntity. This gives every table: uuid PK, createdAt, updatedAt, deletedAt (soft delete).

---

## Naming Conventions

| Thing | Convention | Example |
|-------|-----------|---------|
| Table name | snake_case, plural | `users`, `blog_posts`, `refresh_tokens` |
| Column name | camelCase in entity, snake_case in DB | `firstName` → `first_name` |
| Index name | `idx_[table]_[column]` | `idx_users_email` |
| FK name | `fk_[table]_[ref_table]` | `fk_posts_users` |
| Junction table | `[table1]_[table2]` alphabetical | `post_tags` |

---

## TypeORM Entity Standards

```typescript
@Entity('blog_posts')  // always specify table name
@Index('idx_blog_posts_author_status', ['authorId', 'status'])  // composite index
export class BlogPost extends BaseEntity {
  @Column({ type: 'varchar', length: 255 })
  title: string;

  @Column({ type: 'text' })
  content: string;

  @Column({
    type: 'enum',
    enum: PostStatus,
    default: PostStatus.DRAFT,
  })
  status: PostStatus;

  @Index()  // single column index
  @Column({ type: 'uuid' })
  authorId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'author_id' })
  author: User;

  @ManyToMany(() => Tag)
  @JoinTable({
    name: 'post_tags',
    joinColumn: { name: 'post_id' },
    inverseJoinColumn: { name: 'tag_id' },
  })
  tags: Tag[];
}
```

---

## Indexing Strategy (mandatory)

Always index:
- Every foreign key column
- Every column used in WHERE filters frequently
- Every column used in ORDER BY on large tables
- Unique constraint columns (`@Index({ unique: true })`)
- Composite indexes for common filter combinations

```typescript
// Frequently filtered: status + createdAt
@Index('idx_orders_status_created', ['status', 'createdAt'])

// Unique email
@Index({ unique: true })
@Column()
email: string;

// Full-text search (PostgreSQL GIN index)
// Add in migration:
// CREATE INDEX idx_posts_search ON blog_posts USING GIN(to_tsvector('english', title || ' ' || content));
```

---

## Soft Delete Pattern

Never hard-delete user-facing data. Always use soft delete:

```typescript
// Soft delete (sets deletedAt timestamp)
await this.userRepo.softDelete(id);

// Find including deleted
await this.userRepo.find({ withDeleted: true });

// Find only deleted
await this.userRepo.find({ where: { deletedAt: Not(IsNull()) }, withDeleted: true });

// Restore soft-deleted
await this.userRepo.restore(id);
```

Hard delete only for: logs, temp data, or when legally required (GDPR "right to erasure" → replace data with tombstone, don't delete rows).

---

## Repository Pattern

```typescript
// src/modules/users/users.repository.ts
@Injectable()
export class UsersRepository {
  constructor(
    @InjectRepository(User)
    private readonly repo: Repository<User>,
  ) {}

  async findById(id: string): Promise<User | null> {
    return this.repo.findOne({ where: { id } });
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.repo.findOne({ where: { email: email.toLowerCase() } });
  }

  async findPaginated(query: PaginationQueryDto): Promise<[User[], number]> {
    const qb = this.repo.createQueryBuilder('user');

    if (query.search) {
      qb.andWhere('(user.name ILIKE :search OR user.email ILIKE :search)', {
        search: `%${query.search}%`,
      });
    }

    return qb
      .orderBy(`user.${query.sortBy ?? 'createdAt'}`, query.sortOrder ?? 'DESC')
      .skip((query.page - 1) * query.pageSize)
      .take(query.pageSize)
      .getManyAndCount();
  }

  async create(data: Partial<User>): Promise<User> {
    const user = this.repo.create(data);
    return this.repo.save(user);
  }

  async update(id: string, data: Partial<User>): Promise<User> {
    await this.repo.update(id, data);
    return this.findById(id) as Promise<User>;
  }

  async softDelete(id: string): Promise<void> {
    await this.repo.softDelete(id);
  }
}
```

---

## Migrations (TypeORM)

Never use `synchronize: true` in production. Always use migrations.

```bash
# Generate migration after entity changes
npm run migration:generate -- src/migrations/AddUserProfileFields

# Run migrations
npm run migration:run

# Revert last migration
npm run migration:revert
```

package.json scripts:
```json
{
  "migration:generate": "typeorm migration:generate -d src/config/typeorm.config.ts",
  "migration:run": "typeorm migration:run -d src/config/typeorm.config.ts",
  "migration:revert": "typeorm migration:revert -d src/config/typeorm.config.ts",
  "migration:create": "typeorm migration:create"
}
```

---

## N+1 Query Prevention

```typescript
// ❌ N+1 problem — 1 query to get posts, N queries for each author
const posts = await this.postRepo.find();
for (const post of posts) {
  post.author = await this.userRepo.findById(post.authorId); // N extra queries!
}

// ✅ Single query with JOIN
const posts = await this.postRepo.find({
  relations: { author: true },
});

// ✅ Or with query builder for complex cases
const posts = await this.postRepo
  .createQueryBuilder('post')
  .leftJoinAndSelect('post.author', 'author')
  .leftJoinAndSelect('post.tags', 'tags')
  .where('post.status = :status', { status: 'published' })
  .orderBy('post.createdAt', 'DESC')
  .take(20)
  .skip(0)
  .getMany();
```

---

## Connection Pool Config (AWS RDS t2.micro)

```typescript
// typeorm config
extra: {
  max: 10,          // max connections (t2.micro has max 87 for PostgreSQL)
  min: 2,           // always keep 2 alive
  acquire: 30000,   // max time to get connection (30s)
  idle: 10000,      // connection idle timeout (10s)
},
```

---

## PostgreSQL-Specific Features to Use

```sql
-- UUID generation (use gen_random_uuid() not uuid_generate_v4())
id UUID DEFAULT gen_random_uuid() PRIMARY KEY

-- Timestamps always with timezone
created_at TIMESTAMPTZ DEFAULT NOW()

-- JSON for flexible schemas
metadata JSONB  -- use JSONB not JSON (indexed, faster)

-- Enum types
CREATE TYPE post_status AS ENUM ('draft', 'published', 'archived');

-- Case-insensitive text search
SELECT * FROM users WHERE email ILIKE '%@gmail.com';

-- Full-text search
SELECT * FROM posts WHERE to_tsvector('english', title) @@ plainto_tsquery('search term');
```
