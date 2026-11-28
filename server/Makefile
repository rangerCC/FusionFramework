.PHONY: help tidy build run dev infra infra-down test test-infra test-infra-down docker-build fmt vet migrate

help:
	@echo ""
	@echo "── 本地开发 ──────────────────────────────────────"
	@echo "  make dev          一键启动：infra + server (推荐)"
	@echo "  make infra        仅启动 Postgres + Redis"
	@echo "  make run          仅运行 server（需先 make infra）"
	@echo "  make infra-down   停止并保留数据"
	@echo ""
	@echo "── 测试 ───────────────────────────────────────────"
	@echo "  make test         运行所有单元/集成测试"
	@echo "  make test-infra   启动测试用 Postgres + Redis"
	@echo "  make test-infra-down"
	@echo ""
	@echo "── 构建 / 部署 ────────────────────────────────────"
	@echo "  make build        编译二进制到 bin/server"
	@echo "  make docker-build 构建生产镜像"
	@echo "  make fmt / vet / tidy"
	@echo ""

# ── 代码质量 ──────────────────────────────────────────────

tidy:
	go mod tidy

fmt:
	go fmt ./...

vet:
	go vet ./...

# ── 构建 ──────────────────────────────────────────────────

build:
	CGO_ENABLED=0 go build -o bin/server ./cmd/server

# 生产镜像（使用国内镜像源）
docker-build:
	docker build -t socialstory-server:latest .

# ── 本地开发 ──────────────────────────────────────────────

# 仅启动基础设施（Postgres + Redis），server 进程在宿主机运行
infra:
	docker compose up -d
	@echo "Waiting for postgres..."
	@until docker compose exec postgres pg_isready -U postgres -q 2>/dev/null; do sleep 1; done
	@echo "Postgres ready. Run: make run"

infra-down:
	docker compose down

# 在宿主机直接运行 server（需先 make infra）
# 读取 .env 文件（如存在），否则使用 config.example.env 中的默认值
run:
	@if [ -f .env ]; then \
		set -a && . ./.env && set +a && MIGRATIONS_DIR=./migrations go run ./cmd/server; \
	else \
		echo "提示：未找到 .env，使用内置默认值。可执行 cp config.example.env .env 创建本地配置。" && \
		APP_ENV=dev PORT=8080 \
		DATABASE_URL=postgres://postgres:postgres@localhost:5432/socialstory?sslmode=disable \
		REDIS_ADDR=localhost:6379 REDIS_PASSWORD= REDIS_DB=0 \
		JWT_SECRET=dev-insecure-change-me \
		ACCESS_TTL_SEC=7200 REFRESH_TTL_SEC=2592000 \
		SMS_DEV_MODE=true SMS_DEV_CODE=1234 \
		MONTHLY_FREE_QUOTA=3 ALLOWED_ORIGINS='*' \
		MIGRATIONS_DIR=./migrations \
		go run ./cmd/server; \
	fi

# 一键：起 infra，然后运行 server
dev: infra run

# ── 测试 ──────────────────────────────────────────────────

test-infra:
	docker compose -f docker-compose.test.yml up -d postgres-test redis-test
	@echo "Waiting for postgres-test..."
	@until docker compose -f docker-compose.test.yml exec postgres-test pg_isready -U ss_test -q 2>/dev/null; do sleep 1; done
	@echo "Test infra ready."

test-infra-down:
	docker compose -f docker-compose.test.yml down

test:
	go test ./...

# ── 手动迁移（备用，server 启动时会自动执行）─────────────

migrate:
	@for f in migrations/*.sql; do echo "applying $$f"; psql "$$DATABASE_URL" -f "$$f"; done
