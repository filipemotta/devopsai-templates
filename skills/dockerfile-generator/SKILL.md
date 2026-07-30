---
name: dockerfile-generator
description: >
  Generates optimized, production-ready Dockerfiles. Use whenever the user asks
  to create a Dockerfile, containerize an application, dockerize an app or
  build a Docker image, even without mentioning "dockerfile-generator"
  explicitly. Takes the application folder path as argument, detects the
  language automatically and generates a Dockerfile + .dockerignore with
  security and size best practices, then tests the result automatically.
---

## What this skill does

Analyzes an application, detects the language/framework, and generates a
production-ready Dockerfile following best practices:

- **Multi-stage build** — separates build from runtime for a minimal final image
- **Alpine / distroless** — smallest possible base images
- **Rootless container** — runs as a non-root user (UID 1001)
- **HEALTHCHECK** — native Docker instruction for monitoring
- **Automatic test** — builds, runs, validates the health check and removes the container

## Arguments

- **Required**: application folder path (e.g. `apps/frontend/my-app`)
- **Optional**: port (if not given, detect automatically or use the language default)
- **Optional**: health check path (default: `/health`)

## Workflow

### Step 1 — Detect the language

Analyze the folder contents and identify the language/framework:

| File | Language/Framework |
|------|--------------------|
| `package.json` + `next.config.*` | Next.js |
| `package.json` (without next) | Node.js |
| `*.csproj` | .NET |
| `requirements.txt` or `pyproject.toml` or `Pipfile` | Python |
| `go.mod` | Go |
| `Cargo.toml` | Rust |

Report the detected language to the user before proceeding.

### Step 2 — Generate the Dockerfile

Create the Dockerfile at the root of the application folder following the
template for the detected language. All Dockerfiles must follow these
principles:

#### Mandatory principles

1. **Multi-stage build**: minimum 2 stages (builder + runtime)
2. **Version pinning**: specific tags on base images (e.g. `node:20-alpine`, never `node:latest`)
3. **Alpine or distroless**: prefer alpine images at runtime; for .NET use `mcr.microsoft.com/dotnet/aspnet` with an alpine tag
4. **Non-root user**: create a dedicated user with UID 1001 and use the `USER` instruction
5. **HEALTHCHECK**: include a `HEALTHCHECK` instruction pointing to the configured path
6. **Optimized layer order**: copy dependency files first, then the code (layer cache)
7. **.dockerignore**: generate one if it doesn't exist (node_modules, .git, bin, obj, __pycache__, .env*, etc.)
8. **No secrets in the image**: never copy .env, credentials or private keys

#### Template: Next.js

```dockerfile
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json* yarn.lock* pnpm-lock.yaml* ./
RUN \
  if [ -f package-lock.json ]; then npm ci --only=production; \
  elif [ -f yarn.lock ]; then yarn install --frozen-lockfile --production; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm install --frozen-lockfile --prod; \
  else npm install --only=production; fi

FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 appuser
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
USER appuser
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1
CMD ["node", "server.js"]
```

**Note**: Next.js requires `output: "standalone"` in `next.config.js`. Check
if it is configured; if not, tell the user it needs to be added.

#### Template: Node.js (Express/Fastify/etc)

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci
COPY . .
RUN npm run build 2>/dev/null || true

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 appuser
COPY --from=builder /app/package.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/src ./src
USER appuser
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1
CMD ["node", "dist/index.js"]
```

#### Template: .NET

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS builder
WORKDIR /src
COPY *.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runner
WORKDIR /app
ENV ASPNETCORE_URLS=http://+:8080
ENV DOTNET_RUNNING_IN_CONTAINER=true
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 appuser
COPY --from=builder /app/publish .
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1
ENTRYPOINT ["dotnet", "<AppName>.dll"]
```

**Note**: replace `<AppName>` with the real `.csproj` name (without the
extension), and detect the SDK version from the `TargetFramework` to pick the
matching image tag.

#### Template: Python (FastAPI/Flask/Django)

```dockerfile
FROM python:3.12-alpine AS builder
WORKDIR /app
RUN apk add --no-cache gcc musl-dev
COPY requirements.txt* pyproject.toml* ./
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt 2>/dev/null || \
    pip install --no-cache-dir --prefix=/install .

FROM python:3.12-alpine AS runner
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 appuser
COPY --from=builder /install /usr/local
COPY . .
USER appuser
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8000/health || exit 1
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Note**: adjust the CMD for the detected framework (gunicorn for
Flask/Django, uvicorn for FastAPI).

#### Template: Go

```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/server .

FROM alpine:3.20 AS runner
WORKDIR /app
RUN apk add --no-cache ca-certificates wget && \
    addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 appuser
COPY --from=builder /app/server .
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1
CMD ["./server"]
```

### Step 3 — Generate .dockerignore

If there is no `.dockerignore` in the folder, create one with exclusions
appropriate for the language:

- **Node.js/Next.js**: `node_modules`, `.next`, `.git`, `.env*`, `*.md`, `.DS_Store`, `coverage`
- **.NET**: `bin`, `obj`, `.git`, `.env*`, `*.md`, `.DS_Store`, `*.user`, `*.suo`
- **Python**: `__pycache__`, `*.pyc`, `.git`, `.env*`, `*.md`, `.venv`, `venv`, `.pytest_cache`
- **Go**: `.git`, `.env*`, `*.md`, `vendor`

### Step 4 — Build and automatic test

After generating the Dockerfile, run the automatic test:

```bash
APP_DIR="<app-path>"
CONTAINER_NAME="dockerfile-test-$(date +%s)"
IMAGE_NAME="dockerfile-test:latest"
PORT=<detected-port>
HEALTH_PATH="<health-path>"

cd "$APP_DIR"
docker build -t "$IMAGE_NAME" .
docker run -d --name "$CONTAINER_NAME" -p "$PORT:$PORT" "$IMAGE_NAME"

echo "Waiting for the container to start..."
for i in $(seq 1 30); do
  if curl -sf "http://localhost:$PORT$HEALTH_PATH" > /dev/null 2>&1; then
    echo "Health check OK after ${i}s"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "FAILURE: health check did not respond in 30s"
    docker logs "$CONTAINER_NAME"
    docker rm -f "$CONTAINER_NAME"
    docker rmi "$IMAGE_NAME" 2>/dev/null
    exit 1
  fi
  sleep 1
done

docker images "$IMAGE_NAME" --format "Image size: {{.Size}}"

docker rm -f "$CONTAINER_NAME"
docker rmi "$IMAGE_NAME" 2>/dev/null
```

### Step 5 — Report the result

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Dockerfile Generator — Result
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
App:       <app-name>
Language:  <detected-language>
Port:      <port>
Health:    <health-path>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Dockerfile generated
✓ .dockerignore generated
✓ Build OK
✓ Container started
✓ Health check responded
✓ Container removed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Image size: <size>
```

If any step fails, mark it with `✗`, show the container logs and suggest fixes.

## Important notes

- If the application has no `/health` endpoint, suggest creating one before
  containerizing, or use an alternative path if the user provides one
- Adapt the templates as needed: they are starting points, not rigid rules
- If Docker is not installed or not running, skip Step 4 and tell the user
