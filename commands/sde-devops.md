---
description: Phase 11 — DevOps & Deployment. Generates production-ready Dockerfiles, GitHub Actions CI/CD workflows, k3s manifests, AWS setup guide, Grafana Cloud config, and Sentry integration.
---

# SDE DevOps — Phase 11: DevOps & Deployment

## Pre-Flight

1. Read `.sde/context.json` — project type, slug, stack deviations
2. Read `.sde/phases/3-stack.md` — exact packages used
3. Templates are in `~/.claude/skills/../templates/` (from SDE Plugin install dir)

---

## Docker Configuration

### backend/Dockerfile
```dockerfile
# ================================================
# Stage 1: Builder
# ================================================
FROM node:20-alpine AS builder

WORKDIR /app

# Install dumb-init for proper PID 1 signal handling
RUN apk add --no-cache dumb-init

# Install dependencies first (better layer caching)
COPY package*.json ./
RUN npm ci --only=production && cp -R node_modules /tmp/node_modules
RUN npm ci

# Copy source and build
COPY . .
RUN npm run build

# ================================================
# Stage 2: Production
# ================================================
FROM node:20-alpine-slim AS production

WORKDIR /app

# Security: run as non-root user
RUN apk add --no-cache dumb-init && \
    addgroup -g 1001 -S nodejs && \
    adduser -S nestjs -u 1001

ENV NODE_ENV=production
ENV PORT=3000

# Copy only what we need from builder
COPY --from=builder --chown=nestjs:nodejs /tmp/node_modules ./node_modules
COPY --from=builder --chown=nestjs:nodejs /app/dist ./dist
COPY --from=builder --chown=nestjs:nodejs /usr/bin/dumb-init /usr/bin/dumb-init

USER nestjs

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/main"]
```

### frontend/Dockerfile
```dockerfile
# ================================================
# Stage 1: Builder
# ================================================
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
ARG VITE_API_URL
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build

# ================================================
# Stage 2: Nginx Production Server
# ================================================
FROM nginx:1.25-alpine AS production

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy built assets
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:80/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
```

### frontend/nginx.conf
```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    gzip_min_length 256;
    gzip_vary on;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "strict-origin-when-cross-origin";

    # Static assets — long cache
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # API proxy
    location /api {
        proxy_pass http://backend:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_cache_bypass $http_upgrade;
    }

    # Health check endpoint for load balancer
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    # SPA routing — all other routes go to index.html
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

### docker-compose.yml (local development)
```yaml
version: '3.9'

services:
  postgres:
    image: postgres:16-alpine
    container_name: ${PROJECT_NAME:-app}-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${DB_USER:-postgres}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-postgres}
      POSTGRES_DB: ${DB_NAME:-appdb}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backend/src/database/migrations:/docker-entrypoint-initdb.d:ro
    ports:
      - '5432:5432'
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U ${DB_USER:-postgres}']
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - app-network

  redis:
    image: redis:7-alpine
    container_name: ${PROJECT_NAME:-app}-redis
    restart: unless-stopped
    command: redis-server --appendonly yes --maxmemory 128mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    ports:
      - '6379:6379'
    healthcheck:
      test: ['CMD', 'redis-cli', 'ping']
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - app-network

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
      target: builder
    container_name: ${PROJECT_NAME:-app}-backend
    restart: unless-stopped
    env_file: .env
    volumes:
      - ./backend/src:/app/src:delegated
    ports:
      - '3000:3000'
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    command: npm run start:dev
    networks:
      - app-network

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
      target: builder
    container_name: ${PROJECT_NAME:-app}-frontend
    restart: unless-stopped
    env_file: .env
    volumes:
      - ./frontend/src:/app/src:delegated
    ports:
      - '5173:5173'
    depends_on:
      - backend
    command: npm run dev -- --host 0.0.0.0
    networks:
      - app-network

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local

networks:
  app-network:
    driver: bridge
```

### docker-compose.prod.yml
```yaml
version: '3.9'

services:
  backend:
    image: ${ECR_REGISTRY}/backend:${IMAGE_TAG:-latest}
    container_name: app-backend-prod
    restart: unless-stopped
    env_file: .env.prod
    ports:
      - '3000:3000'
    depends_on:
      redis:
        condition: service_healthy
    healthcheck:
      test: ['CMD', 'wget', '-qO-', 'http://localhost:3000/health']
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
    networks:
      - app-network

  frontend:
    image: ${ECR_REGISTRY}/frontend:${IMAGE_TAG:-latest}
    container_name: app-frontend-prod
    restart: unless-stopped
    ports:
      - '80:80'
      - '443:443'
    depends_on:
      - backend
    deploy:
      resources:
        limits:
          memory: 128M
          cpus: '0.25'
    networks:
      - app-network

  redis:
    image: redis:7-alpine
    container_name: app-redis-prod
    restart: unless-stopped
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    healthcheck:
      test: ['CMD', 'redis-cli', '-a', '${REDIS_PASSWORD}', 'ping']
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 256M
    networks:
      - app-network

volumes:
  redis_data:

networks:
  app-network:
    driver: bridge
```

---

## GitHub Actions Workflows

### .github/workflows/ci.yml
```yaml
name: CI

on:
  push:
    branches: ['**']
  pull_request:
    branches: [main, develop]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  backend:
    name: Backend CI
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: testdb
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
      redis:
        image: redis:7-alpine
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: backend/package-lock.json

      - name: Install dependencies
        run: cd backend && npm ci

      - name: Lint
        run: cd backend && npm run lint

      - name: Type check
        run: cd backend && npx tsc --noEmit

      - name: Run tests with coverage
        run: cd backend && npm test -- --coverage --forceExit --detectOpenHandles
        env:
          NODE_ENV: test
          DATABASE_URL: postgresql://test:test@localhost:5432/testdb
          REDIS_HOST: localhost
          REDIS_PORT: 6379
          JWT_SECRET: test-secret-minimum-32-characters-here
          JWT_REFRESH_SECRET: test-refresh-minimum-32-characters-ok

      - name: Build
        run: cd backend && npm run build

      - name: Upload coverage
        uses: actions/upload-artifact@v4
        with:
          name: backend-coverage
          path: backend/coverage/
          retention-days: 7

  frontend:
    name: Frontend CI
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json

      - name: Install dependencies
        run: cd frontend && npm ci

      - name: Lint
        run: cd frontend && npm run lint

      - name: Type check
        run: cd frontend && npx tsc --noEmit

      - name: Run tests with coverage
        run: cd frontend && npm test -- --coverage

      - name: Build
        run: cd frontend && npm run build
        env:
          VITE_API_URL: https://api.example.com/api/v1

      - name: Upload coverage
        uses: actions/upload-artifact@v4
        with:
          name: frontend-coverage
          path: frontend/coverage/
          retention-days: 7
```

### .github/workflows/cd-prod.yml
```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

env:
  AWS_REGION: us-east-1

jobs:
  build-and-push:
    name: Build & Push to ECR
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.version }}

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Set image tag
        id: meta
        run: echo "version=$(echo $GITHUB_SHA | head -c7)" >> $GITHUB_OUTPUT

      - name: Build and push backend
        run: |
          IMAGE_TAG="${{ steps.meta.outputs.version }}"
          REGISTRY="${{ secrets.ECR_REGISTRY }}"

          docker build \
            -t "$REGISTRY/backend:$IMAGE_TAG" \
            -t "$REGISTRY/backend:latest" \
            -f backend/Dockerfile \
            backend/

          docker push "$REGISTRY/backend:$IMAGE_TAG"
          docker push "$REGISTRY/backend:latest"

      - name: Build and push frontend
        run: |
          IMAGE_TAG="${{ steps.meta.outputs.version }}"
          REGISTRY="${{ secrets.ECR_REGISTRY }}"

          docker build \
            --build-arg VITE_API_URL="${{ secrets.VITE_API_URL }}" \
            -t "$REGISTRY/frontend:$IMAGE_TAG" \
            -t "$REGISTRY/frontend:latest" \
            -f frontend/Dockerfile \
            frontend/

          docker push "$REGISTRY/frontend:$IMAGE_TAG"
          docker push "$REGISTRY/frontend:latest"

  deploy:
    name: Deploy to EC2
    runs-on: ubuntu-latest
    needs: build-and-push
    environment: production

    steps:
      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ${{ secrets.EC2_USER }}
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            set -e
            cd /opt/app

            # Pull latest images
            export ECR_REGISTRY="${{ secrets.ECR_REGISTRY }}"
            export IMAGE_TAG="${{ needs.build-and-push.outputs.image-tag }}"

            $(aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY)

            docker-compose -f docker-compose.prod.yml pull

            # Zero-downtime deploy
            docker-compose -f docker-compose.prod.yml up -d --remove-orphans

            # Cleanup old images
            docker system prune -f

            # Wait for health check
            sleep 20
            curl -f http://localhost:3000/health || (echo "Health check failed" && exit 1)

            echo "✅ Deployment successful: $IMAGE_TAG"

      - name: Notify on failure
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '❌ Production deployment failed for commit ${{ github.sha }}'
            })
```

### .github/workflows/security-audit.yml
```yaml
name: Security Audit

on:
  schedule:
    - cron: '0 0 * * *'  # Daily at midnight
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  dependency-audit:
    name: Dependency Vulnerability Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Audit backend dependencies
        run: |
          cd backend && npm ci
          npm audit --audit-level=high || echo "::warning::Backend vulnerabilities found"

      - name: Audit frontend dependencies
        run: |
          cd frontend && npm ci
          npm audit --audit-level=high || echo "::warning::Frontend vulnerabilities found"

  secret-scan:
    name: Secret Detection
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: TruffleHog scan
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          head: HEAD
          extra_args: --debug --only-verified
```

---

## k3s Kubernetes Manifests

### k3s/namespace.yaml
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: app
  labels:
    name: app
```

### k3s/deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: app
  labels:
    app: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: REPLACE_WITH_ECR_URI/backend:latest
          ports:
            - containerPort: 3000
          resources:
            requests:
              memory: '128Mi'
              cpu: '100m'
            limits:
              memory: '256Mi'
              cpu: '500m'
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 30
            periodSeconds: 10
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 5
          envFrom:
            - secretRef:
                name: app-secrets
            - configMapRef:
                name: app-config
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend
          image: REPLACE_WITH_ECR_URI/frontend:latest
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: '64Mi'
              cpu: '50m'
            limits:
              memory: '128Mi'
              cpu: '200m'
          livenessProbe:
            httpGet:
              path: /health
              port: 80
            initialDelaySeconds: 10
            periodSeconds: 10
```

### k3s/service.yaml
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: app
spec:
  selector:
    app: backend
  ports:
    - protocol: TCP
      port: 3000
      targetPort: 3000
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: app
spec:
  selector:
    app: frontend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: LoadBalancer
```

---

## AWS Setup Guide

Create `.sde/phases/11-aws-setup.md`:

```markdown
# AWS Free Tier Setup Guide

## EC2 t2.micro Setup
```bash
# After launching t2.micro Ubuntu 22.04 instance:
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker ubuntu
newgrp docker

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Create app directory
sudo mkdir -p /opt/app && sudo chown ubuntu:ubuntu /opt/app
```

## Required GitHub Secrets
```
AWS_ACCESS_KEY_ID        → IAM user access key
AWS_SECRET_ACCESS_KEY    → IAM user secret key
ECR_REGISTRY             → [account-id].dkr.ecr.us-east-1.amazonaws.com
EC2_HOST                 → EC2 public IP or domain
EC2_USER                 → ubuntu (for Ubuntu AMI)
EC2_SSH_KEY              → Private key content for EC2 access
VITE_API_URL             → https://api.yourdomain.com/api/v1
```
```

---

## Grafana + Sentry Integration

### Sentry Setup (NestJS)

```typescript
// In main.ts, BEFORE NestFactory:
import * as Sentry from '@sentry/node';

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  enabled: !!process.env.SENTRY_DSN,
});
```

Update `HttpExceptionFilter` to capture errors:
```typescript
} else if (exception instanceof Error) {
  Sentry.captureException(exception, { extra: { requestId, path: request.url } });
  this.logger.error(exception.message, exception.stack, { requestId });
}
```

---

## Autonomous Actions

1. Create ALL files: Dockerfiles, nginx.conf, docker-compose files, workflows, k3s manifests
2. Save deployment guide to `.sde/phases/11-devops.md`
3. Add Sentry integration to main.ts and exception filter
4. ```bash
   git checkout develop
   git checkout -b feature/11-devops
   git add .
   git commit -m "ci: Docker, GitHub Actions CI/CD, k3s manifests — Phase 11"
   git push origin feature/11-devops
   ```
5. Update context.json: `currentPhase: 11`, add 11 to `completedPhases`

---

## Phase Gate

```
╔══════════════════════════════════════════════════╗
║  ✅ PHASE 11 COMPLETE — DevOps                   ║
╠══════════════════════════════════════════════════╣
║  OUTPUT SUMMARY:                                 ║
║  • Dockerfiles (backend multi-stage, frontend)   ║
║  • docker-compose.yml (dev) + prod               ║
║  • CI workflow (backend + frontend)              ║
║  • CD workflow (ECR + EC2 deploy)                ║
║  • Security audit workflow (daily)               ║
║  • k3s manifests (future scaling)                ║
╠══════════════════════════════════════════════════╣
║  SAVED:                                          ║
║  • .sde/phases/11-devops.md                      ║
║  • Git committed: feature/11-devops              ║
╠══════════════════════════════════════════════════╣
║  NEXT: Phase 12 — Production Readiness           ║
╠══════════════════════════════════════════════════╣
║  [proceed] → run production checklist            ║
║  [refine]  → adjust deployment config            ║
║  [custom]  → type what to change                 ║
╚══════════════════════════════════════════════════╝
```
