# Dispatch — fix-qa-server-port-conflict

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: fix-qa-server-port-conflict
TASK_TYPE: implement
FEATURE: Remap the QA server's published host port so QA can start while Penpot holds 8080
AREA: docker/compose.qa.yaml — one published host port
WORKTREE: /private/tmp/shipit-fix-qa-port
BRANCH: fix/qa-server-port-conflict
BASE_SHA: dbb1d75
OWNED_PATHS:
  - docker/compose.qa.yaml
READ_ONLY_PATHS:
  - docker/nginx.conf
  - docker/Dockerfile.server
  - docker/Dockerfile.client
  - docs/deployment/local-qa.md
  - AGENTS.md
PROHIBITED_PATHS:
  - apps/**
  - packages/**
  - docker/nginx.conf
  - docker/Dockerfile.server
  - docker/Dockerfile.client
  - docker/compose.test.yaml
  - docker/compose.e2e.yaml
  - .github/**
  - docs/adr/**
  - .decisions/**
ACCEPTANCE_CRITERIA: >
  The QA server publishes a free host port instead of 8080. Its CONTAINER port stays 8080, so
  nginx and the compose network are untouched and docker/nginx.conf needs no change. The
  client keeps serving the API at 8081. Nothing else in the file changes.
VALIDATION_COMMANDS:
  - docker compose -f docker/compose.qa.yaml config --no-interpolate
ROUTING_CLASS: STANDARD
```

---

## Context

QA cannot start. `docker-server-1` is down, and it cannot come up:

```
Error response from daemon: ports are not available: exposing port TCP 0.0.0.0:8080 -> 127.0.0.1:0:
listen tcp 0.0.0.0:8080: bind: address already in use
```

A **Penpot** process (java, serving `TaggerWeb`) on the host holds port 8080. Penpot is the design tool
and is not ours to stop.

**This exposed a real error in the Manager's own verification, which you should know about because it
shapes this task.** For hours the Manager ran `curl http://localhost:8080/` as a QA health check and
reported `200`. That 200 was **Penpot answering**, not the ShipIt server. The server had already exited
(SIGTERM, clean, exit 0) and a status-only check could not tell the difference. The check was meaningless
and it masked a down server. Hence: verify by *identity*, not by status code.

## The change you are making — exactly one line

`docker/compose.qa.yaml:56` currently reads:

```yaml
    ports:
      - "8080:8080"
```

Change **only the host side** so the server publishes a free host port instead. Verified free at dispatch:
**8082**, **8083**, **8180** (8090 and 8091 are busy).

So the line becomes `"<free-host-port>:8080"` — for example `"8082:8080"`.

**The container port MUST stay 8080.** This is why the change is safe and needs no companion edit:

- `docker/nginx.conf:21` is `proxy_pass http://server:8080/` — the client resolves `server` on the
  compose network and calls **container** port 8080. A host-side remap does not affect it.
- `docker/compose.qa.yaml:72` `API_UPSTREAM: "server:8080"` and `:85`
  `SERVERPOD_API_URL: http://server:8080` are both container-network references. Unchanged.
- The browser only ever needs the **client** at 8081.

So changing the host side alone restores QA with no other edit anywhere. **Verify this yourself** by
reading those three lines rather than trusting this paragraph.

## Hard constraints

- **ONE line changes.** Do not reformat, reorder, rename, or "tidy" anything else. The file's byte
  formatting is load-bearing for diff review.
- **Do not touch `docker/nginx.conf`** — it must not change, and saying so is the point of keeping the
  container port at 8080.
- **Do not touch `docker/compose.test.yaml` or `docker/compose.e2e.yaml`.** They have their own scoping
  problems, tracked separately, and are out of scope here.
- **ZERO mutating Docker/Compose commands.** You are editing a file, not starting a stack. The Manager
  holds deployment authority and will perform the container recreation after you finish. **Do not run
  `up`, `down`, `stop`, `restart`, `build`, `pull`, or `prune`.**
- `docker compose … config` is read-only interpolation and IS permitted. Note that plain `config` exits 1
  on the gitignored `.env`; use `--no-interpolate`, which exits 0. **Report that, do not "fix" it.**
- Never run `make clean`, `make test-env-down`, `make e2e-down`, or a bare `down -v`. This repository has
  already lost its QA database irrecoverably to a `down -v`.
- Read `AGENTS.md` § Shared Docker state before you touch this file.

## Report requirements

1. The exact before/after bytes of the changed line.
2. `git diff` — prove it is one line in one file.
3. `docker compose -f docker/compose.qa.yaml config --no-interpolate` output, confirming the new
   published port and that the container port is unchanged.
4. Your independent verification that `nginx.conf:21`, `API_UPSTREAM` and `SERVERPOD_API_URL` are all
   container-scoped and therefore unaffected — quote the lines you checked.
5. Confirm `docker/nginx.conf`, `compose.test.yaml` and `compose.e2e.yaml` are untouched.

## Follow-up you must flag, not fix

Because the host port changes, **anything documented that reaches the QA server on
`http://localhost:8080` becomes wrong.** `docs/deployment/local-qa.md` is READ_ONLY to you. Identify the
exact lines that reference 8080 and report them as owed documentation updates for the Manager — do not edit
the file.

## Other lanes

None are writing `docker/`. Manager holds `LANES.md` / `WORK_STATE.md` / `.decisions/**`.

Report `SAFE_PARALLEL_WORK` and `PROHIBITED_PARALLEL_WORK`.

## Cleanup

Commit on your branch with a conventional commit message. **Do not push, do not merge, do not touch
`main`.** Start nothing, so there is nothing to tear down.

## You cannot approve this

Report `READY_FOR_INDEPENDENT_REVIEW: YES`. A compose change in this repository has caused real damage
before, so it gets an independent review before integration.