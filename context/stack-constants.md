# SDE Plugin — Stack Constants & Package Versions

This file is the single source of truth for all package versions, configuration defaults, and environment variable schemas used across all skills and agents. Read this at the start of every phase.

---

## Package Versions (Pinned — update periodically)

### Backend (NestJS)
```json
{
  "@nestjs/common": "^10.3.0",
  "@nestjs/core": "^10.3.0",
  "@nestjs/platform-express": "^10.3.0",
  "@nestjs/config": "^3.2.0",
  "@nestjs/jwt": "^10.2.0",
  "@nestjs/passport": "^10.0.3",
  "@nestjs/typeorm": "^10.0.2",
  "@nestjs/cache-manager": "^2.2.0",
  "@nestjs/throttler": "^5.1.1",
  "@nestjs/swagger": "^7.3.0",
  "@nestjs/terminus": "^10.2.3",
  "typeorm": "^0.3.20",
  "pg": "^8.11.5",
  "passport": "^0.7.0",
  "passport-jwt": "^4.0.1",
  "bcrypt": "^5.1.1",
  "helmet": "^7.1.0",
  "compression": "^1.7.4",
  "cache-manager": "^5.4.0",
  "cache-manager-redis-yet": "^5.1.3",
  "class-validator": "^0.14.1",
  "class-transformer": "^0.5.1",
  "@sentry/nestjs": "^7.109.0",
  "@willsoto/nestjs-prometheus": "^6.0.0",
  "prom-client": "^15.1.0"
}
```

### Backend (Dev)
```json
{
  "@nestjs/cli": "^10.3.2",
  "@nestjs/testing": "^10.3.0",
  "@types/bcrypt": "^5.0.2",
  "@types/compression": "^1.7.5",
  "@types/passport-jwt": "^4.0.1",
  "jest": "^29.7.0",
  "supertest": "^7.0.0",
  "@types/supertest": "^6.0.2",
  "ts-jest": "^29.1.2"
}
```

### Frontend (React)
```json
{
  "react": "^18.3.1",
  "react-dom": "^18.3.1",
  "react-router-dom": "^6.23.1",
  "@tanstack/react-query": "^5.40.0",
  "axios": "^1.7.2",
  "zustand": "^4.5.2",
  "react-hook-form": "^7.51.5",
  "@hookform/resolvers": "^3.6.0",
  "zod": "^3.23.8",
  "lucide-react": "^0.395.0",
  "clsx": "^2.1.1",
  "tailwind-merge": "^2.3.0",
  "@sentry/react": "^7.109.0"
}
```

### Frontend (Dev)
```json
{
  "vite": "^5.3.1",
  "@vitejs/plugin-react": "^4.3.1",
  "vitest": "^1.6.0",
  "@testing-library/react": "^16.0.0",
  "@testing-library/jest-dom": "^6.4.6",
  "@testing-library/user-event": "^14.5.2",
  "tailwindcss": "^3.4.4",
  "autoprefixer": "^10.4.19",
  "postcss": "^8.4.38",
  "typescript": "^5.4.5"
}
```

### Mobile (Expo)
```json
{
  "expo": "~51.0.0",
  "expo-router": "~3.5.0",
  "expo-secure-store": "~13.0.0",
  "expo-notifications": "~0.28.0",
  "nativewind": "^4.0.1",
  "react-native": "0.74.0",
  "@tanstack/react-query": "^5.40.0",
  "zustand": "^4.5.2",
  "react-hook-form": "^7.51.5",
  "zod": "^3.23.8",
  "@react-native-community/netinfo": "^11.3.1",
  "axios": "^1.7.2"
}
```

---

## Environment Variable Schema

### Backend (.env)
```bash
# App
NODE_ENV=development
PORT=3000
APP_VERSION=1.0.0

# Database
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/appdb
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=appdb

# Redis
REDIS_URL=redis://localhost:6379

# JWT (MUST be >= 32 random characters)
JWT_SECRET=REPLACE_WITH_32_CHAR_SECRET_AT_LEAST
JWT_REFRESH_SECRET=REPLACE_WITH_DIFFERENT_32_CHAR_SECRET

# JWT Expiry
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

# CORS (comma-separated)
CORS_ORIGINS=http://localhost:5173,http://localhost:3001

# Monitoring
SENTRY_DSN=
GRAFANA_CLOUD_PUSH_URL=
GRAFANA_CLOUD_API_KEY=

# Storage (AWS)
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
S3_BUCKET_NAME=

# Email (optional)
RESEND_API_KEY=
FROM_EMAIL=noreply@yourdomain.com
```

### Frontend (.env)
```bash
VITE_API_URL=http://localhost:3000/api/v1
VITE_APP_NAME=MyApp
VITE_SENTRY_DSN=
```

### Mobile (.env / app.config.ts)
```bash
EXPO_PUBLIC_API_URL=http://localhost:3000/api/v1
EXPO_PUBLIC_APP_NAME=MyApp
```

---

## TypeScript Configuration

### Backend tsconfig.json
```json
{
  "compilerOptions": {
    "module": "commonjs",
    "declaration": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "allowSyntheticDefaultImports": true,
    "target": "ES2021",
    "sourceMap": true,
    "outDir": "./dist",
    "baseUrl": "./",
    "incremental": true,
    "skipLibCheck": true,
    "strictNullChecks": true,
    "noImplicitAny": true,
    "strictBindCallApply": true,
    "forceConsistentCasingInFileNames": true,
    "noFallthroughCasesInSwitch": true,
    "paths": {
      "@/*": ["src/*"]
    }
  }
}
```

### Frontend tsconfig.json
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": { "@/*": ["src/*"] }
  }
}
```

---

## Tailwind Design Tokens

```javascript
// tailwind.config.ts — extend with these defaults
theme: {
  extend: {
    colors: {
      primary: {
        50: '#eef2ff',
        500: '#6366f1',  // indigo-500
        600: '#4f46e5',  // indigo-600
        700: '#4338ca',  // indigo-700
      },
    },
    fontFamily: {
      sans: ['Inter', 'system-ui', 'sans-serif'],
      mono: ['JetBrains Mono', 'monospace'],
    },
    borderRadius: {
      DEFAULT: '0.5rem',
      lg: '0.75rem',
      xl: '1rem',
    },
  },
}
```

---

## Default Configuration Values

| Setting | Default | Reason |
|---------|---------|--------|
| JWT access expiry | 15 min | Short window limits damage from stolen tokens |
| JWT refresh expiry | 7 days | Balance between UX and security |
| bcrypt rounds | 12 | ~250ms hash time, good tradeoff |
| Rate limit (auth) | 5 req/min | Prevents brute force |
| Rate limit (API) | 60 req/min | Normal usage headroom |
| Pagination default | 20 items | Small enough to be fast |
| Pagination max | 100 items | Prevents huge response payloads |
| Cache TTL (user) | 5 min | Fresh enough, saves DB roundtrips |
| Cache TTL (static) | 1 hour | Config, categories, etc. |
| DB pool size | 10 | t2.micro has limited connections |
| Request timeout | 10 sec | Fail fast vs hanging requests |
| File upload max | 10 MB | S3 free tier considerations |
