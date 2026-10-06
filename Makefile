# SHIP IT Local Deployment Makefile
# Usage: make <target>
# Run 'make help' to see all targets

# TEST RESOURCE HYGIENE. Every target below that CREATES test infrastructure
# must REMOVE it before it returns, on success, failure and interrupt alike.
# There is no target here that leaves a container, volume or compose project
# running on purpose; `test-env-up`/`e2e-up` are paired with their `-down`
# counterparts and are not used by CI or by `test-integration`.
#
# The one-shot test targets (`test-integration`, `test-env-test`, `e2e-test`)
# clean up inside the target itself, via a `trap`, so a failure or a Ctrl-C
# cannot leak them. Do not add a `docker compose up` to a recipe without adding
# the matching teardown — see AGENTS.md § Product-specific policy.
#
# Those traps run AFTER the recipe has `cd`-ed somewhere, so they must not
# resolve the compose file against the current directory: a relative path there
# fails, and a `|| true` teardown then leaks the container it was written to
# remove. Hence the absolute paths below, derived from this Makefile's own
# location.

REPO_ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
COMPOSE_TEST := $(REPO_ROOT)/docker/compose.test.yaml
COMPOSE_E2E := $(REPO_ROOT)/docker/compose.e2e.yaml

.PHONY: help qa-up qa-down qa-logs qa-restart qa-build qa-build-client test-env-up test-env-down test-env-test test-env-logs test-env-ps test-integration e2e-up e2e-down e2e-test clean

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
	@echo "  make test-env-test        Run E2E tests, then remove everything it created"
	@echo "  make test-env-logs        View test stack logs"
	@echo "  make test-env-ps          Show test stack status"
	@echo ""
	@echo "Integration Tests (apps/server, disposable database):"
	@echo "  make test-integration     Run the server integration suite against a"
	@echo "                            throwaway Postgres, then destroy it. Requires"
	@echo "                            SERVERPOD_DATABASE_PASSWORD and a passwords.yaml."
	@echo ""
	@echo "E2E Environment (Legacy):"
	@echo "  make e2e-up          Start E2E stack"
	@echo "  make e2e-down        Stop and remove E2E stack"
	@echo "  make e2e-test        Run E2E tests, then remove everything it created"
	@echo ""
	@echo "Client Development (Hot Reload):"
	@echo "  make client-dev      Start backend only, run Flutter dev server"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean           SAFETY STUB - removes nothing. Use qa-down /"
	@echo "                        test-env-down / e2e-down for real teardown."
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

# `docker compose up` leaves the containers and the named volumes it created
# running: `--abort-on-container-exit` stops the other services, and neither
# flag removes anything. That leak happened on every run, pass or fail. The
# project is therefore given a name of its own (so the teardown cannot resolve
# to someone else's stack) and destroyed with `down -v` from a trap, which fires
# on success, failure and interrupt.
#
# The trap distinguishes "the teardown failed and something leaked" from "the
# teardown failed because there was nothing to tear down". `down` also fails when
# the compose file itself cannot be parsed, which is the case for every command
# in this file when the config is broken — so a run that never created a project
# used to announce CLEANUP FAILED for a project that had never existed, and that
# is the same false signal in the opposite direction. Resource existence is
# therefore probed with plain `docker ps/volume ls/network ls` by project label,
# which does not need the compose file and so cannot fail for the reason being
# diagnosed.
test-env-test:
	@echo "Running E2E tests against test environment..."
	@bash -c 'set -euo pipefail; \
	  project=shipit_test; \
	  cleanup() { \
	    status=$$?; trap - EXIT INT TERM; \
	    leaked=$$(docker ps -aq --filter label=com.docker.compose.project=$$project 2>/dev/null; \
	               docker volume ls -q --filter label=com.docker.compose.project=$$project 2>/dev/null; \
	               docker network ls -q --filter label=com.docker.compose.project=$$project 2>/dev/null); \
	    echo ""; \
	    echo "test-env-test: removing project $$project (containers + volumes)"; \
	    if out=$$(docker compose -p $$project -f "$(COMPOSE_TEST)" down -v --remove-orphans 2>&1); then \
	      echo "$$out"; \
	    elif [ -n "$$leaked" ]; then \
	      echo "test-env-test: CLEANUP FAILED - the $$project project still exists:"; echo "$$out"; \
	      echo "  docker compose -p $$project -f $(COMPOSE_TEST) down -v --remove-orphans"; \
	    else \
	      echo "$$out"; \
	      echo "test-env-test: nothing to remove - no $$project containers, volumes or network existed."; \
	    fi; \
	    exit $$status; \
	  }; \
	  trap cleanup EXIT INT TERM; \
	  docker compose -p $$project -f "$(COMPOSE_TEST)" up --build --abort-on-container-exit --exit-code-from test-runner'

# Runs the apps/server integration suite against a database that exists only for
# this run.
#
# Why this target exists rather than `cd apps/server && dart test`: the suite
# connects to whatever answers on the port in `apps/server/config/test.yaml`, so
# the committed way to run it locally is a long-lived Postgres on 9099 that
# outlives the run, carries state between runs, and collides with any other
# project's test database on the machine. This target creates its own Postgres
# under its own compose project, points Serverpod at it by environment variable
# (config/test.yaml documents those overrides), runs the suite, and destroys the
# container and its data in a `trap` that fires on success, failure and Ctrl-C.
#
# The schema step is `dart run tool/schema_bootstrap.dart`, not bare migrations:
# Serverpod applies only the latest `definition.sql` to a database with no
# recorded migration version, so without this the database under test is missing
# the hand-maintained design-revision triggers. See AGENTS.md § Product-specific
# policy and apps/server/tool/schema_bootstrap.sql.
test-integration:
	@bash -c 'set -euo pipefail; \
	  project="shipit_integration_$$$$"; \
	  compose="docker compose -p $$project -f $(COMPOSE_TEST) --profile integration"; \
	  cleanup() { \
	    status=$$?; trap - EXIT INT TERM; \
	    leaked=$$(docker ps -aq --filter label=com.docker.compose.project=$$project 2>/dev/null; \
	               docker volume ls -q --filter label=com.docker.compose.project=$$project 2>/dev/null; \
	               docker network ls -q --filter label=com.docker.compose.project=$$project 2>/dev/null); \
	    echo ""; \
	    echo "test-integration: removing $$project (container + data)"; \
	    if out=$$($$compose down -v --remove-orphans 2>&1); then \
	      echo "$$out"; \
	    elif [ -n "$$leaked" ]; then \
	      echo "test-integration: CLEANUP FAILED - the $$project project still exists. Remove it with:"; \
	      echo "  docker compose -p $$project -f $(COMPOSE_TEST) --profile integration down -v --remove-orphans"; \
	      echo "$$out"; \
	    else \
	      echo "$$out"; \
	      echo "test-integration: nothing to remove - the $$project project never existed."; \
	    fi; \
	    exit $$status; \
	  }; \
	  trap cleanup EXIT INT TERM; \
	  if [ -z "$${SERVERPOD_DATABASE_PASSWORD:-}" ]; then \
	    echo "SERVERPOD_DATABASE_PASSWORD is not set. It must equal test.database"; \
	    echo "in apps/server/config/passwords.yaml (see apps/server/config/test.yaml)."; \
	    exit 2; \
	  fi; \
	  echo "test-integration: creating disposable Postgres (project $$project)"; \
	  $$compose up -d --wait postgres_integration; \
	  cd "$(REPO_ROOT)/apps/server"; \
	  export SERVERPOD_DATABASE_HOST=127.0.0.1; \
	  export SERVERPOD_DATABASE_PORT="$${SHIPIT_TEST_DB_PORT:-9199}"; \
	  export SERVERPOD_DATABASE_NAME=control_plane_test; \
	  export SERVERPOD_DATABASE_USER=postgres; \
	  echo "test-integration: applying migrations and the schema bootstrap"; \
	  dart run tool/schema_bootstrap.dart; \
	  echo "test-integration: running the integration suite"; \
	  dart test test/integration/'

# E2E Environment (Legacy)
e2e-up:
	@echo "Building E2E images..."
	docker compose -f docker/compose.e2e.yaml build
	@echo "Starting E2E environment..."
	docker compose -f docker/compose.e2e.yaml up -d

e2e-down:
	@echo "Stopping E2E environment..."
	docker compose -f docker/compose.e2e.yaml down -v

# Same leak and same fix as test-env-test; `docker compose up` does not remove
# what it created, so the project is destroyed with `down -v` from a trap. The
# trap also separates a real leak from a compose file that could not be parsed —
# see the note above `test-env-test`.
e2e-test:
	@echo "Running E2E tests..."
	@bash -c 'set -euo pipefail; \
	  project=shipit_e2e; \
	  cleanup() { \
	    status=$$?; trap - EXIT INT TERM; \
	    leaked=$$(docker ps -aq --filter label=com.docker.compose.project=$$project 2>/dev/null; \
	               docker volume ls -q --filter label=com.docker.compose.project=$$project 2>/dev/null; \
	               docker network ls -q --filter label=com.docker.compose.project=$$project 2>/dev/null); \
	    echo ""; \
	    echo "e2e-test: removing project $$project (containers + volumes)"; \
	    if out=$$(docker compose -p $$project -f "$(COMPOSE_E2E)" down -v --remove-orphans 2>&1); then \
	      echo "$$out"; \
	    elif [ -n "$$leaked" ]; then \
	      echo "e2e-test: CLEANUP FAILED - the $$project project still exists:"; echo "$$out"; \
	      echo "  docker compose -p $$project -f $(COMPOSE_E2E) down -v --remove-orphans"; \
	    else \
	      echo "$$out"; \
	      echo "e2e-test: nothing to remove - no $$project containers, volumes or network existed."; \
	    fi; \
	    exit $$status; \
	  }; \
	  trap cleanup EXIT INT TERM; \
	  docker compose -p $$project -f "$(COMPOSE_E2E)" up --build --abort-on-container-exit --exit-code-from test-runner'

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

# `make clean` is DISARMED. It removes nothing at all.
#
# The recipe it used to run, kept here so that the removal is visibly
# quarantined rather than quietly deleted and then re-added by the next person
# who goes looking for a "cleanup" target:
#
#   docker compose -f docker/compose.qa.yaml  down -v --rmi local 2>/dev/null || true
#   docker compose -f docker/compose.e2e.yaml  down -v --rmi local 2>/dev/null || true
#   docker compose -f docker/compose.test.yaml down -v --rmi local 2>/dev/null || true
#   docker image rm shipit-client:local 2>/dev/null || true
#   docker image rm docker-client 2>/dev/null || true
#   docker image rm docker-server 2>/dev/null || true
#   docker volume prune -f
#
# Three independent reasons each of those lines had to go:
#
# 1. THE QA DATABASE. `docker compose down -v` is PROJECT-scoped, not
#    file-scoped. None of docker/compose.qa.yaml, compose.e2e.yaml or
#    compose.test.yaml declares a top-level `name:`, so all three resolve to the
#    same project, named after the directory they live in: `docker`. That is
#    the live QA stack's project - docker-postgres-1, docker-server-1,
#    docker-client-1 - and its volume docker_postgres_data_qa. So the first
#    `down -v` deleted the human's QA database, and the second and third lines
#    were then no-ops against the project it had already emptied: three lines
#    that looked like three scopes, all aimed at one live database. This was not
#    hypothetical - a design-reviewer lane ran this recipe as a probe and
#    destroyed that database irrecoverably.
# 2. THE MACHINE-WIDE PRUNE. `docker volume prune -f` does not care which
#    repository you are standing in; it deletes every unused volume on the
#    host. At the time of writing this host had 45 dangling volumes, 11 of them
#    belonging to unrelated projects (3 devops_*, 8 partnerhub*/teamhub*).
#    A repository Makefile has no authority over any of them.
# 3. THE SILENCED EXIT. Every one of those commands ended in
#    `2>/dev/null || true`, so a teardown that failed halfway reported success
#    and its error text was discarded. That is the same pattern AGENTS.md
#    section "Test resource hygiene" already names as the cause of a container
#    leak that shipped here once; here it ran in the other direction, hiding a
#    partial removal rather than a failed one.
#
# There is no capability gap here, which is why no replacement target was added.
# Everything `clean` used to remove is removed by a target that already exists
# under a name nobody types by accident: `qa-down` for the QA stack (where
# destroying the database IS the documented job), `test-env-down` and
# `e2e-down` for the other two. A consolidated label-scoped sweep is being
# designed (design/port-and-cleanup); adding a second, differently-named
# destructive path today would give the machine one more way to reach those
# volumes, not one fewer. Until that sweep lands, the safe behaviour for a
# target with this name is to do nothing and say so.
#
# If you are restoring a teardown here, do not restore the quoted recipe above.
# Use the per-stack targets, and give any new one its own compose project name so
# `down -v` cannot resolve to someone else's stack.
clean:
	@echo "make clean removes NOTHING. It is a disarmed safety stub."
	@echo ""
	@echo "NOT TOUCHED - none of the following was stopped, removed, created or"
	@echo "pruned by running this command:"
	@echo "  * no container, volume or network, of this repository or any other"
	@echo "  * the QA stack (compose project 'docker') is untouched, and so is its"
	@echo "    database volume docker_postgres_data_qa"
	@echo "  * no Docker image, including shipit-client:local"
	@echo "  * no other project's Docker volumes (a prune of every unused volume on"
	@echo "    the host used to sit in this recipe; that is not a repository scope)"
	@echo ""
	@echo "WHAT REALLY DOES TEARDOWN - each one scoped to its own compose project:"
	@echo "  make qa-down          Stop the QA stack and delete its database."
	@echo "                        Destructive on purpose: the QA database holds"
	@echo "                        real data. Run it when you mean it."
	@echo "  make test-env-down    Stop the test stack and delete its ephemeral database."
	@echo "  make e2e-down         Stop the legacy E2E stack and delete its volumes."
	@echo ""
	@echo "WHAT LEAVES NOTHING BEHIND - each creates its own project and removes it"
	@echo "from a trap on EXIT INT TERM, so a failure or a Ctrl-C cannot leak it:"
	@echo "  make test-integration Run the server integration suite against a"
	@echo "                        throwaway Postgres, then destroy it."
	@echo "  make test-env-test    Run the E2E suite, then destroy what it created."
	@echo "  make e2e-test         Same, against the legacy E2E compose file."
	@echo ""
	@echo "TO SEE WHAT IS RUNNING:  make ps"
	@echo "A label-scoped replacement sweep is being designed in design/port-and-cleanup."
	@echo "Until it lands, nothing named 'clean' will delete your database."

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