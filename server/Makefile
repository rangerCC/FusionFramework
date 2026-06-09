.PHONY: help tidy build run test docker-build up down logs migrate fmt vet

help:
	@echo "Targets: tidy build run test up down logs migrate fmt vet"

tidy:
	go mod tidy

fmt:
	go fmt ./...

vet:
	go vet ./...

build:
	CGO_ENABLED=0 go build -o bin/server ./cmd/server

# Run locally. Requires Postgres + Redis reachable (see .env / config.example.env).
run:
	MIGRATIONS_DIR=./migrations go run ./cmd/server

test:
	go test ./...

docker-build:
	docker build -t socialstory-server:latest .

up:
	docker compose up --build -d

down:
	docker compose down

logs:
	docker compose logs -f server

# Apply migrations against $DATABASE_URL using psql (alternative to in-app runner).
migrate:
	@for f in migrations/*.sql; do echo "applying $$f"; psql "$$DATABASE_URL" -f "$$f"; done
