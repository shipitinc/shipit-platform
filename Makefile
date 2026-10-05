# SHIP IT Local Deployment Makefile
# Usage: make <target>
# Run 'make help' to see all targets

.PHONY: help qa-up qa-down qa-logs qa-restart qa-build qa-build-client test-env-up test-env-down test-env-test test-env-logs test-env-ps e2e-up e2e-down e2e-test clean

# Default target
help:
	@echo "SHIP IT Local Deployment Commands"
	@echo ""
	@echo "QA Environment (Local Manual Testing):"
	@echo "  make qa-up           Start full QA stack (build + up)"
	@echo "  make qa-down         Stop and remove QA stack (with volumes)"
	@echo "  make qa-logs         View QA stack logs"
	@echo "  make qa-restart      Restart QA services"
	@echo "  make qa-build        Build all QA images"
	@echo "  make qa-build-client Build client image (includes Flutter build)"
	@echo ""
	@echo "Test Environment (Automated Testing - Isolated from QA):"
	@echo "  make test-env-up          Start test stack (ephemeral DB, different ports)"
	@echo "  make test-env-down        Stop and remove test stack"
	@echo "  make test-env-test        Run E2E tests against test environment"
	@echo "  make test-env-logs        View test stack logs"
	@echo "  make test-env-ps          Show test stack status"
	@echo ""
	@echo "E2E Environment (Legacy):"
	@echo "  make e2e-up          Start E2E stack"
	@echo "  make e2e-down        Stop and remove E2E stack"
	@echo "  make e2e-test        Run E2E tests (full cycle)"
	@echo ""
	@echo "Client Development (Hot Reload):"
	@echo "  make client-dev      Start backend only, run Flutter dev server"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean           Remove all containers, volumes, images"
	@echo "  make ps              Show running containers"
	@echo ""

# QA Environment
qa-up: qa-build
	@echo "Starting QA environment..."
	docker compose -f docker/compose.qa.yaml up -d
	@echo "Waiting for services to be healthy..."
	@sleep 5
	@docker compose -f docker/compose.qa.yaml ps
	@echo ""
	@echo "QA Environment ready:"
	@echo "  UI:      http://localhost:8081"
	@echo "  API:     http://localhost:8081/api/"
	@echo "  Server:  http://localhost:8080"
	@echo "  DB:      localhost:5432"

qa-down:
	@echo "Stopping QA environment..."
	docker compose -f docker/compose.qa.yaml down -v

qa-logs:
	docker compose -f docker/compose.qa.yaml logs -f

qa-ps:
	docker compose -f docker/compose.qa.yaml ps

qa-restart:
	docker compose -f docker/compose.qa.yaml restart

qa-build: qa-build-client
	@echo "Building server image..."
	docker compose -f docker/compose.qa.yaml build server

qa-build-client:
	@echo "Building client image (with Flutter web build)..."
	@./docker/build-client.sh

# Test Environment (Automated Testing - Isolated from QA)
test-env-up:
	@echo "Building test images..."
	docker compose -f docker/compose.test.yaml build
	@echo "Starting test environment..."
	docker compose -f docker/compose.test.yaml up -d
	@echo "Waiting for services to be healthy..."
	@sleep 5
	@docker compose -f docker/compose.test.yaml ps
	@echo ""
	@echo "Test Environment ready:"
	@echo "  UI:      http://localhost:8083"
	@echo "  API:     http://localhost:8083/api/"
	@echo "  Server:  http://localhost:8082"
	@echo "  DB:      localhost:5433"

test-env-down:
	@echo "Stopping test environment..."
	docker compose -f docker/compose.test.yaml down -v

test-env-logs:
	docker compose -f docker/compose.test.yaml logs -f

test-env-ps:
	docker compose -f docker/compose.test.yaml ps

test-env-test:
	@echo "Running E2E tests against test environment..."
	docker compose -f docker/compose.test.yaml up --build --abort-on-container-exit --exit-code-from test-runner

# E2E Environment (Legacy)
e2e-up:
	@echo "Building E2E images..."
	docker compose -f docker/compose.e2e.yaml build
	@echo "Starting E2E environment..."
	docker compose -f docker/compose.e2e.yaml up -d

e2e-down:
	@echo "Stopping E2E environment..."
	docker compose -f docker/compose.e2e.yaml down -v

e2e-test:
	@echo "Running E2E tests..."
	docker compose -f docker/compose.e2e.yaml up --build --abort-on-container-exit --exit-code-from test-runner

e2e-logs:
	docker compose -f docker/compose.e2e.yaml logs -f

# Client Development (Hot Reload)
client-dev:
	@echo "Starting backend services for client development..."
	docker compose -f docker/compose.qa.yaml up -d postgres triage-seed server
	@echo ""
	@echo "Backend started. Now run Flutter dev server in another terminal:"
	@echo "  cd apps/control_plane && flutter run -d web-server --web-port 8081 --dart-define=CONTROL_PLANE_API=http://localhost:8081/api/"
	@echo ""
	@echo "Or use the VS Code launch configuration 'Flutter Web (Local QA)'"

# Cleanup
clean:
	@echo "Cleaning up all SHIP IT containers, volumes, and images..."
	docker compose -f docker/compose.qa.yaml down -v --rmi local 2>/dev/null || true
	docker compose -f docker/compose.e2e.yaml down -v --rmi local 2>/dev/null || true
	docker compose -f docker/compose.test.yaml down -v --rmi local 2>/dev/null || true
	docker image rm shipit-client:local 2>/dev/null || true
	docker image rm docker-client 2>/dev/null || true
	docker image rm docker-server 2>/dev/null || true
	docker volume prune -f

# Status
ps:
	@echo "=== QA Stack ==="
	@docker compose -f docker/compose.qa.yaml ps 2>/dev/null || echo "Not running"
	@echo ""
	@echo "=== Test Stack ==="
	@docker compose -f docker/compose.test.yaml ps 2>/dev/null || echo "Not running"
	@echo ""
	@echo "=== E2E Stack ==="
	@docker compose -f docker/compose.e2e.yaml ps 2>/dev/null || echo "Not running"