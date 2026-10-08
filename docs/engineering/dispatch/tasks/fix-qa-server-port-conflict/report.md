# Report — fix-qa-server-port-conflict

```
RESULT: IMPLEMENTED

FEATURE:    Remap the QA server's published HOST port so QA can start while Penpot holds 8080
BRANCH:     fix/qa-server-port-conflict
BASE_SHA:   dbb1d75e71c9ba4142d511eeaa5d7ca694cdb8e5
HEAD_SHA:   7d3a21ee52e1795ed29f10dfa94d04a9edb9e210
WORKTREE:   /private/tmp/shipit-fix-qa-port

OWNED_PATHS:
  - docker/compose.qa.yaml

READ_ONLY_PATHS:
  - docker/nginx.conf
  - docker/Dockerfile.server
  - docker/Dockerfile.client
  - docs/deployment/local-qa.md
  - AGENTS.md

PROHIBITED_PATHS:
  - apps/**            packages/**         docker/nginx.conf
  - docker/Dockerfile.server                 docker/Dockerfile.client
  - docker/compose.test.yaml                 docker/compose.e2e.yaml
  - .github/**          docs/adr/**         .decisions/**

FILES_CHANGED:
  - docker/compose.qa.yaml   (1 insertion, 1 deletion — line 56 only)

GATES:
  format=    n/a   (no Dart/formatting touched; YAML byte formatting preserved — see §1)
  analyze=   n/a   (no source touched)
  tests=     n/a   (no code; no test target applies to a compose published-port mapping)
  build=     n/a   (build is deployment authority; Manager recreates the container)
  runtime=   n/a   (no stack was started — see "DOCKER DISCIPLINE" below)
  config=    NOT_RUN — deliberate. `docker compose … config` is named in AGENTS.md:118 as
                  NOT granted to a lane without deployment authority, which contradicts
                  VALIDATION_COMMANDS in this dispatch. See §7 CONTRADICTION-1. Substituted
                  with a non-Docker YAML parse that yields the identical evidence (§3).

DISCOVERIES:
  - CONTRADICTION  — dispatch grants `docker compose … config`; AGENTS.md:118 forbids it for
                     this lane. Not reconciled by me. Needs Manager/human ruling.
  - RUNTIME_DISCOVERY — docker/compose.test.yaml already publishes host 8082 (server) and
                     8083 (client) under compose project shipit_test. 8082/8083 were offered
                     as "free"; they are free *now* but already claimed by a sibling stack.
                     Chose 8180. See §2.
  - PROJECT_FACT   — Penpot's java process (PID 77185) holds host 8080. Verified by process
                     identity (`lsof`), not by status code — the failure mode named in the
                     dispatch context.
  - CONTRADICTION  — `make qa-up` (Makefile:83) prints `http://localhost:8080` as a live
                     instruction and is now wrong. Makefile is outside OWNED_PATHS. See §6.

KNOWLEDGE_PERSISTED:
  NONE written by me. All findings above are reported for the Manager to route. Writing to
  docs/engineering/learning/** or .decisions/** would be outside OWNED_PATHS and touches
  PROHIBITED/Manager-held paths, so I flagged rather than persisted (§9).

BLOCKERS:
  NONE blocking the change itself. One open item needs a Manager/human ruling: the
  `config` gate contradiction (§7).

READY_FOR_INDEPENDENT_REVIEW: YES
```

---

## 1. Exact before/after bytes — `docker/compose.qa.yaml:56`

**Before** (verified with `od -c` at `dbb1d75`):

```
0000000                    p   o   r   t   s   :  \n
0000020        -   "   8   0   8   0   :   8   0   8   0   "  \n
```

**After:**

```
0000000                    p   o   r   t   s   :  \n
0000020        -   "   8   1   8   0   :   8   0   8   0   "  \n
```

As text:

```diff
-      - "8080:8080"
+      - "8180:8080"
```

Exactly **one character** differs — the `0` at index 1 of the host side. Leading indentation
(6 spaces), the `- ` sequence, the quotes, the colon, the container side, and the trailing
newline are all byte-identical. No reformatting, reordering, renaming or tidying. File still
ends with a newline.

## 2. Port choice: 8180, not 8082 — deviation from the suggested example, with evidence

The dispatch authorized **8082, 8083 or 8180** ("e.g. `"8082:8080"`"). I initially applied 8082,
then checked what the repo already publishes and changed to **8180**.

All published host ports across the repository's compose files, read as text:

| Stack | postgres | server | client | compose project |
|---|---|---|---|---|
| `docker/compose.yaml` (local dev) | 5432 | 8080 | 8081 | `docker` |
| `docker/compose.qa.yaml` (QA) | 5432 | **8180** (was 8080) | 8081 | `docker` |
| `docker/compose.test.yaml` | 5433, 9199 | **8082** | **8083** | `shipit_test` |
| `docker/compose.e2e.yaml` | none published | — | — | `docker` |

`docker/compose.test.yaml:103` is `- "8082:8080"` and `:121` is `- "8083:8081"`. Per `AGENTS.md`
§ Test resource hygiene, `make test-env-test` runs that stack under compose project
**`shipit_test`** — a project that exists *precisely so it can coexist with the QA stack* under
project `docker`. (QA postgres is 5432 vs test 5433; that separation is deliberate. So is
server 8080 vs test 8082.)

Claiming 8082 or 8083 for QA would mean the test environment cannot bind whenever it runs
against a live QA stack — reintroducing **the exact failure this task exists to fix**
(`listen tcp 0.0.0.0:8082: bind: address already in use`), just on a different port and later.

8180 is within the authorized set, is free, and collides with no published port in any compose
file in this repository.

Availability at the time of the change, verified with `lsof -nP -iTCP:<port> -sTCP:LISTEN`
(read-only; no Docker):

```
port 8080 listeners=1      port 8082 listeners=0
port 8081 listeners=1      port 8083 listeners=0
port 8090 listeners=1      port 8180 listeners=0
port 8091 listeners=1
```

This also confirms the Manager's dispatch note that 8090/8091 are busy.

**Identity, not status** — who actually holds 8080:

```
java 77185 *:8080
```

A `java` process, consistent with Penpot serving `TaggerWeb`. This is the check the dispatch
asked for: I identified the listener rather than asking "is something answering 200 on 8080?"
That distinction is the whole lesson from the hours of `curl` checks that were reporting
Penpot's 200 while `docker-server-1` was down.

## 3. `git diff` — one line, one file

```
$ git diff
diff --git a/docker/compose.qa.yaml b/docker/compose.qa.yaml
index e99a4ac..1ffe4b2 100644
--- a/docker/compose.qa.yaml
+++ b/docker/compose.qa.yaml
@@ -53,7 +53,7 @@ services:
       SHIPIT_TRIAGE_REPOSITORY_PATH: /triage-repo
       SHIPIT_TRIAGE_WORKSPACE_ROOT: /triage-workspaces
     ports:
-      - "8080:8080"
+      - "8180:8080"
     depends_on:
       postgres:
         condition: service_healthy
```

```
$ git diff --numstat
1	1	docker/compose.qa.yaml

$ git diff --stat
 docker/compose.qa.yaml | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

$ git show --stat --oneline HEAD
7d3a21e fix(qa): publish server on host 8180 to avoid Penpot's 8080
 docker/compose.qa.yaml | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
```

`git diff` context lines confirm the 3 preceding and 4 following lines are untouched.

## 4. Published port vs container port

**The dispatch's `VALIDATION_COMMANDS` gate was NOT RUN** — see §7. The substitute is a plain
YAML parse of the file **as text**, which `AGENTS.md:127` names as "the supported way to
establish what a stack does". No Docker daemon contact, no Compose invocation:

```
$ ruby -ryaml -e '...' docker/compose.qa.yaml
YAML PARSE: OK
server.ports = ["8180:8080"]   (host 8180 -> container 8080)
client.ports = ["8081:8081"]
server SERVERPOD_API_SERVER_PORT = "8080"
client API_UPSTREAM = "server:8080"
worker SERVERPOD_API_URL = "http://server:8080"
```

This is the evidence the gate was meant to produce:

| Fact | Value | Meaning |
|---|---|---|
| `server.ports` | `8180:8080` | New **published host** port; **container** side still 8080 |
| `server.SERVERPOD_API_SERVER_PORT` | `8080` | The server still **listens** on container 8080 |
| `client.ports` | `8081:8081` | Browser entry point unchanged |
| `client.CONTROL_PLANE_API` | `http://localhost:8081/api/` | Browser reaches the API through the **client**, never through 8080/8180 |

The file remains valid YAML.

## 5. Independent verification — all three references are container-scoped

I read each rather than trusting the dispatch's summary.

**(a) `docker/nginx.conf:21`** — inside `location /api/`, in the **client** container:

```nginx
20:    location /api/ {
21:        proxy_pass http://server:8080/;
```

`server` is resolved by Docker's internal DNS **inside the compose network**, and 8080 is the
**container** port. A host-side publish remap does not alter container-to-container traffic.
Unchanged.

**(b) `docker/compose.qa.yaml:72`** — in the `client` service:

```yaml
71:      CONTROL_PLANE_API: "http://localhost:8081/api/"
72:      API_UPSTREAM: "server:8080"
```

**(c) `docker/compose.qa.yaml:85`** — in the `worker-linux` service:

```yaml
85:      SERVERPOD_API_URL: http://server:8080
```

**(d) A fourth reference the dispatch did not mention** — `docker/compose.qa.yaml:52`, which
independently confirms the container port must stay 8080:

```yaml
52:      SERVERPOD_API_SERVER_PORT: "8080"
```

All four are container-scoped or container-listen-port. None reference a host-published port.
The host side appears exactly once in the file — line 56, the line I changed.

**Browser path is unaffected:** `CONTROL_PLANE_API` (line 71) points at `localhost:8081`, the
client's published port, and nginx then proxies `/api/` over the compose network to
`server:8080`. The browser never touches 8080 or 8180.

## 6. Untouchable files — confirmed by SHA-256, before and after

Identical hashes across the whole change:

```
896d3e27590c7eac5b50b901b5f75d38a8e3697bd2fa2c5f115ef177d0490355  docker/nginx.conf
e3ff12bfc77b0f2d69966675acfc56cd99c6bad22f00a67401d08f17917c5a44  docker/compose.test.yaml
6501cbadd63bbfaa9a9e345395e85d9d8e4806be7bdd30ba822c62577688bbb9  docker/compose.e2e.yaml
76a668bf2bf1ab7f3035992f1e43a61e819755459f27ca3c0cee2588194a73a5  docs/deployment/local-qa.md
```

`git status --porcelain` after commit: empty (clean tree). The only path ever modified was
`docker/compose.qa.yaml`.

## 7. CONTRADICTION-1 — `docker compose … config` is forbidden here, so I did not run it

**The dispatch says** (line 96, and `VALIDATION_COMMANDS` at line 36): *"docker compose … config
is read-only interpolation and IS permitted… use `--no-interpolate`, which exits 0."*

**`AGENTS.md` § Shared Docker state says** (`AGENTS.md:116-120`):

> - A lane without explicit deployment or infrastructure authority runs **no** Docker or Compose
>   command that can change state: … Not even a read-only-looking one. `docker compose ps`,
>   `logs`, **`config`** and `docker info` are **not granted either** — they are unnecessary,
>   because compose files are readable as text, and **every exception is a precedent for the next
>   exception**.
> - Reading a compose file or the Dockerfile as **text** is the supported way to establish what a
>   stack does. Do not start it to find out.

`AGENTS.md` names `config` **by name**. It is a human-mandated rule, and a Manager dispatch is not
a human waiver of one — the framework reserves that for the human gate. The rule's stated reason
against exceptions ("every exception is a precedent for the next exception") is precisely the
argument for not taking this one. Established practice in this repository agrees: prior lanes
recorded `docker_or_compose_any_including_read_only: NOT_RUN` as the honoured outcome.

**So I ran no Docker or Compose command at all, including read-only ones.** Full list of commands
I executed: `git`, `sed`/`od`, `grep`, `lsof`, `shasum`, `ruby`. No `docker`. No breach to
disclose.

This matters beyond bookkeeping. `AGENTS.md:106-110` records that a review lane destroyed the QA
database irrecoverably with `down -v --rmi local`. A rule written in that blood is not the place
for an implementer to introduce the first "it's only read-only" exception.

**Substitute evidence (§4)** is a plain YAML parse, which is `AGENTS.md:127`'s endorsed method and
produces the same published/container port facts the gate existed to confirm.

**Needed from the Manager / human:** either (i) accept the text-based substitute and amend
`VALIDATION_COMMANDS`, or (ii) amend `AGENTS.md:118` to carve out `config --no-interpolate`
explicitly, so the permission has a written home. Until then this gate stays `NOT_RUN`, and the
independent reviewer should treat §4 as its evidence.

## 8. FLAG — owed documentation updates (I did not edit; file is READ_ONLY)

Every place that reaches the QA server on host port 8080 is now **wrong**. Classified by whether
the `8080` in it is a *host* port (stale) or a *container* port (still correct):

### `docs/deployment/local-qa.md` — STALE (host-port references)

| Line | Current text | Should become |
|---|---|---|
| 45 | `- Ports 5432, 8080, 8081 available` | `- Ports 5432, 8180, 8081 available` |
| 54 | `│  │  :8081       │    │  (nginx)     │    │   :8080      │   │` | Server box sits in the **Host Machine** box, so this is the host port → `:8180` |
| 70 | `| server | 8080 | Serverpod backend API |` | `| server | 8180 | …` (the Services table lists published host ports) |
| 112 | `-e CONTROL_PLANE_API=http://host.docker.internal:8080/api/ \` | `:8180` |
| 113 | `-e API_UPSTREAM=host.docker.internal:8080 \` | `:8180` |
| 150 | `The Flutter dev server proxies /api/ to http://localhost:8080 via its proxy configuration.` | `:8180` |
| 253 | `If ports 5432, 8080, or 8081 are in use:` | `5432, 8180, or 8081` |
| 258 | `# Maps to 15432, 10880, 10881` | Recompute for base 8180 (`10880` → 18180) |
| 262 | `lsof -i :5432 -i :8080 -i :8081` | `-i :8180` |
| 281 | `3. Verify server is healthy: curl http://localhost:8080/health` | `curl http://localhost:8180/health` |

**Line 281 deserves specific attention.** It is the QA health check, and a status-only `curl`
against a host port is exactly what masked the dead server for hours: Penpot answered `200` on
8080 while `docker-server-1` had already exited cleanly. It is doubly wrong now — wrong port, and
wrong *method*. A health check on a published host port cannot distinguish "the ShipIt server
answered" from "something else on this machine answered". The robust replacement verifies
**identity**, e.g. assert a ShipIt/Servepod-specific response header or body marker, not merely
HTTP 200. I am flagging this, not fixing it — `local-qa.md` is READ_ONLY.

### `docs/deployment/local-qa.md` — still CORRECT, do not "fix"

| Line | Text | Why it stays |
|---|---|---|
| 54 | container-network `Server :8080` inside the diagram | Already covered above; the *host* box is the stale half |
| 89 | `SERVERPOD_API_SERVER_PORT=8080` | Container listen port, unchanged |
| 99 | `| API_UPSTREAM | server:8080 | … |` | Container-network DNS, unchanged |

### `Makefile:83` — STALE, and it is *live*, not prose  ⚠️

```make
80:	@echo "QA Environment ready:"
81:	@echo "  UI:      http://localhost:8081"
82:	@echo "  API:     http://localhost:8081/api/"
83:	@echo "  Server:  http://localhost:8080"      ← now wrong
84:	@echo "  DB:      localhost:5432"
```

This is more consequential than the documentation: `make qa-up` **prints** it as the server URL a
human or agent will then use. `Makefile` is not in my `OWNED_PATHS`, so I did not touch it.
**Recommend the Manager prioritise this over `local-qa.md`.**

### Other stale references found in the sweep (outside my ownership, not fixed)

- `docker/compose.yaml:71` — `- "8080:8080"`. The **local dev** stack publishes 8080 and is
  therefore *also* unstartable while Penpot holds it. Same class of bug, different file. It is
  **not** in my `PROHIBITED_PATHS`, but it is also not in my `OWNED_PATHS`, and it was out of the
  dispatch's scope — flagged, not touched. It may deserve its own task.
- `docs/adr/0008-docker-compose-local.md:38,72` — documents the 8080 mapping (historical record).
- `docs/deployment/test-environment.md:49,51` — `:8080` / `http://localhost:8080` in the
  dev-vs-test port table; the QA column is now wrong.
- `.decisions/570bb640-…yaml:28,71` — a recorded decision snapshot of the old mapping; likely
  should stay as a historical record. Manager-held.
- `apps/control_plane/lib/data/client_provider.dart:19` — `defaultValue: 'http://localhost:8080/'`.
  Under `PROHIBITED_PATHS`. Noted as advisory in
  `docs/checkpoints/001-control-plane-operator-ui-human-qa.md:89` already ("acceptable for local
  dev"), and it is overridden at runtime by `CONTROL_PLANE_API`, so it does not affect QA. Flagged
  only.

## 9. Learning classification (`aef-repository-learning`)

| Finding | Category | Authority |
|---|---|---|
| Penpot's `java` PID 77185 holds host 8080 | `RUNTIME_DISCOVERY` | Automatic — but I lack write ownership, so reported, not persisted |
| `compose.test.yaml` already publishes 8082/8083 under `shipit_test` | `PROJECT_FACT` | Automatic — same; reported |
| Dispatch's `config` grant contradicts `AGENTS.md:118` | `CONTRADICTION` (governance) | **Human decision** — escalated in §7, not reconciled by me |
| `Makefile:83` prints a now-wrong host port | `PROJECT_FACT` + owed fix | Manager |
| Host-port references in docs are stale | `PROJECT_FACT` | Manager |

I persisted nothing. Writing to `docs/engineering/learning/**` or `.decisions/**` would fall
outside `OWNED_PATHS` (the latter is Manager-held), so every item above is handed up for routing.
Per the skill: *"a production-writing lane should report classified discoveries in its structured
result and only persist within its authority."*

Worth noting for whoever does persist it: the reusable lesson is
`AUTOMATION_OPPORTUNITY` — a CI check that greps the compose files for published host-port
collisions would have caught this at review time instead of at `docker compose up`. Two stacks
quietly sharing host ports is exactly what such a check exists to prevent.

## 10. Docker discipline

**Zero Docker or Compose commands issued.** No `up`, `down`, `stop`, `restart`, `build`, `pull`,
`prune`, `--rmi`, and also no `ps`, `logs`, `config` or `info`. Never ran `make clean`,
`make test-env-down`, `make e2e-down`, or a bare `down -v`. Compose files and the Dockerfile were
read **as text** only.

Nothing was started, so there is nothing to tear down. I created no test database, container,
volume or compose project. `AGENTS.md` § Shared Docker state honoured in full; **no breach to
disclose.**

The container is not recreated by me — the Manager holds deployment authority and will recreate
it to pick up the new published port.

## 11. Parallel work

**SAFE_PARALLEL_WORK** — lanes that read `docker/**`, `docs/deployment/**`, `apps/**`,
`packages/**`, or run non-Docker gates. Also safe: read-only documentation, ADRs, specs, and any
Dart work in `apps/**`/`packages/**`, since no source or container state was touched.

**PROHIBITED_PARALLEL_WORK**
- Anything that writes `docker/compose.qa.yaml` — I own it exclusively; a second writer would
  break the one-line diff guarantee.
- **Any Docker or Compose command whatsoever**, including read-only (`config`, `ps`, `logs`,
  `info`), and `make qa-up`/`qa-down`/`test-env-*`/`e2e-*`. A concurrent lane running Compose
  while I edit the file risks a container recreation that re-derives the old mapping mid-change,
  and `qa-down` destroys the QA database on purpose.
- The Manager should recreate the stack **only after** this branch is merged or the change is
  otherwise in effect — recreating before then would still publish 8080 and fail to bind.
- Doc lanes editing `docs/deployment/local-qa.md` or `Makefile`: not prohibited by me, but they
  must use **8180**, and the mapping must not be "fixed" back toward 8080 or 8082.

---

## Summary for the reviewer

One line in one file, `docker/compose.qa.yaml:56`, host side `8080` → `8180`, container side `8080`
untouched. No other file modified (SHA-256 verified). Two judgement calls need your attention:

1. **8180, not 8082** — 8082 and 8083 are already published by `docker/compose.test.yaml` under
   compose project `shipit_test`, which exists to coexist with QA. 8082 would have recreated this
   bug. (§2)
2. **The `config` gate was NOT RUN** — `AGENTS.md:118` names `config` as not granted to this lane,
   contradicting the dispatch. I did not take the exception and substituted a text parse. This
   needs a Manager or human ruling. (§7)

And the one thing most likely to bite next: `make qa-up` still prints
`Server: http://localhost:8080` (`Makefile:83`), outside my ownership. (§8)