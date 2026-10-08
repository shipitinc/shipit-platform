# Independent Engineering Review — fix-qa-server-port-conflict

```
RESULT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP

REVIEWED_HEAD: 7d3a21ee52e1795ed29f10dfa94d04a9edb9e210
BRANCH:       fix/qa-server-port-conflict
WORKTREE:     /private/tmp/shipit-fix-qa-port
BASE_SHA:     dbb1d75e71c9ba4142d511eeaa5d7ca694cdb8e5
REVIEWER:     engineering-reviewer (independent, read-only)
```

---

## 0. Verdict in one paragraph

The change is correct, minimal, and safe. It is one line in one file, the container port is
provably untouched, `8180` is genuinely free of every published host port in the repository,
and every prohibited path is byte-identical. The implementer rejected the Manager's suggested
`8082` on **correct** grounds, and I verified that rejection independently rather than accepting
it. Two HIGH findings (a wrong port printed by `make qa-up`, and a QA health check that is now
doubly wrong) are real and are *created or worsened* by this change, but they live in files the
implementer provably did not own, and neither prevents QA from starting — which is the entire
purpose of the change. Nothing I found invalidates a required gate, because no gate applies to a
one-token host-side port remap. They must be tracked and two of them should be folded into the
same merge.

---

## 1. Provenance — VERIFIED

| Claim | Verified | Evidence |
|---|---|---|
| HEAD == `7d3a21e` | YES | `git rev-parse HEAD` → `7d3a21ee52e1795ed29f10dfa94d04a9edb9e210` |
| branch | YES | `git rev-parse --abbrev-ref HEAD` → `fix/qa-server-port-conflict` |
| worktree | YES | `git worktree list` → `/private/tmp/shipit-fix-qa-port  7d3a21e [fix/qa-server-port-conflict]` |
| exactly one commit on `dbb1d75` | YES | `git log --oneline dbb1d75..HEAD` → one line only |
| diff is ONE line in ONE file | YES | `git diff --numstat dbb1d75..HEAD` → `1	1	docker/compose.qa.yaml` |

- Working tree clean: `git status --porcelain` → empty (no untracked residue in the worktree).
- `main` == `dbb1d75`, and `git merge-base --is-ancestor main HEAD` succeeds → **fast-forwardable**,
  no rebase or history rewrite implied.
- The complete diff, which is the entire change:

```diff
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

- `git diff --check dbb1d75..HEAD` → no whitespace errors.
- Line count base → head: 91 → 91. No reordering, no tidying, no collateral edit.

---

## 2. Container port unchanged; the four (actually five) references are all container-scoped — VERIFIED

I re-derived every value with my own parse of the file as text (see §6 on why I also ran no
`docker compose config`):

```
YAML PARSE: OK
server.ports                      = ["8180:8080"]
server.SERVERPOD_API_SERVER_PORT  = "8080"          <- compose.qa.yaml:52
client.ports                      = ["8081:8081"]   <- :74 unchanged
client.CONTROL_PLANE_API          = "http://localhost:8081/api/"   <- :71 unchanged
client.API_UPSTREAM               = "server:8080"   <- :72
worker.SERVERPOD_API_URL          = "http://server:8080"          <- :85
network_mode present?             = false
effective proxy_pass (envsubst)   = http://server:8080/
```

Byte-level confirmation of line 56 (`od -c`): `        -   "   8   1   8   0   :   8   0   8   0   "`
— six spaces indent, `- `, quotes, colon, container side `8080`, all intact. Only the `0`→`1` at
host-side index 1 differs.

### Why a host-side remap *cannot* affect any of them

The decisive structural fact is not in any single line — it is that **no compose file in this
repository uses `network_mode: host`** (verified across all six). Therefore every container port is
a *container-network* port, and the `host:container` publish is pure DNAT applied to the host side
only. None of the following can observe it:

| Reference | Value | Why unaffected |
|---|---|---|
| `compose.qa.yaml:52` | `SERVERPOD_API_SERVER_PORT: "8080"` | The process's listen port *inside* the container namespace. Publish mapping does not move the listener. `Dockerfile.server:45,48` also set/`EXPOSE` 8080 — consistent. |
| `compose.qa.yaml:72` | `API_UPSTREAM: "server:8080"` | `server` = Compose-embedded DNS on the compose network; `8080` = the container port. |
| `compose.qa.yaml:85` | `SERVERPOD_API_URL: http://server:8080` | Same. |
| `nginx.conf.template:21` | `proxy_pass http://${API_UPSTREAM}/;` | `envsubst`'d at container start from `API_UPSTREAM` → resolves to `http://server:8080/`. Same. |
| `nginx.conf:21` | `proxy_pass http://server:8080/;` | Container-scoped — **but see finding F-6: this file is not in any image.** |

**Browser path is genuinely untouched:** `CONTROL_PLANE_API` (`:71`) points at `localhost:8081`, the
client's own published port; nginx then proxies `/api/` over the compose network to `server:8080`.
The browser never touches 8080 or 8180. The UI and API entry points a human is told to open are
unchanged.

`8180` appears in the host position exactly once in the whole file — the line that changed.

---

## 3. PORT COLLISION — the crux. 8180 is genuinely free; the rejection of 8082 is correct

### 3a. Complete inventory of published host ports in every compose file in the repository

| Compose file | Published host ports | Project |
|---|---|---|
| `docker/compose.yaml` | 5432, **8080**, 8081 | `docker` |
| `docker/compose.qa.yaml` | 5432, **8180**, 8081 | `docker` |
| `docker/compose.test.yaml` | 5433, **8082**, **8083** (+9199 under `integration` profile only, via `${SHIPIT_TEST_DB_PORT:-9199}`) | `shipit_test` / `docker` |
| `docker/compose.e2e.yaml` | none | `shipit_e2e` / `docker` |
| `docker/compose.override.yaml.example` | none | — |
| `apps/server/docker-compose.yaml` | 8090, 9099 | `control_plane` |

**`git grep -n '8180' HEAD` → exactly one hit, the changed line.** At base `dbb1d75`, `8180`
appears nowhere in the tracked tree. 8180 collides with no published port in any compose file in
this repository. Verified independently of the report.

### 3b. The implementer's rejection of 8082 — CORRECT, and I verified the mechanism

`docker/compose.test.yaml:101-103` is the *same service with the same container port*:

```yaml
101:    ports:
102:      - "8082:8080"
```

I verified the coexistence claim rather than trusting the summary:

- `Makefile:150,172` — `make test-env-test` runs
  `docker compose -p shipit_test -f "$(COMPOSE_TEST)" up …`. Its own project, by design.
- The Makefile section header at line 103 reads: `# Test Environment (Automated Testing - Isolated from QA)`.
- `AGENTS.md` § Test resource hygiene names `test-env-test` (`shipit_test`) and `e2e-test` (`shipit_e2e`)
  as the safe, project-scoped runners.

So `shipit_test` exists *precisely so it can coexist with QA under project `docker`*. Had QA's
server taken `8082`, two stacks in two different projects would publish the same host port, and
`make test-env-test` would fail with `listen tcp 0.0.0.0:8082: bind: address already in use` the
first time anyone ran it against a live QA stack — **the identical failure mode this task exists to
fix, deferred to a later run.** The implementer's reasoning is sound and I endorse it. Same for 8083
(`compose.test.yaml:121`, client).

### 3c. The premise, verified by me

```
port 8080 → java  77185  alkebut  TCP *:8080 (LISTEN)      <- Penpot. IPv6 wildcard, dual-stack:
                                                                  also occupies 0.0.0.0:8080
port 8180 → (no listener)
port 8082 → (no listener)   port 8083 → (no listener)
port 8081 → com.docke 5184  TCP *:8081 (LISTEN)
```

The failure premise holds: `java` (Penpot's Java backend) holds 8080 on the dual-stack wildcard,
which is why a `0.0.0.0:8080` bind by the QA server fails. I identified the listener **by process
identity**, not by asking whether something answers 200 — the correct method, and the one the
dispatch asked for.

### 3d. A case the report did not make, which strengthens the choice

The *manual* targets `test-env-up` / `test-env-down` (Makefile:103,122) do **not** pass `-p`, so
they resolve to project `docker`, not `shipit_test`. Under that path the test stack shares a project
with QA — but its ports are still 5433/8082/8083 versus QA's 5432/8180/8081, so there is no
collision. **8180 is safe under both project resolutions.** The report's argument holds either way.

---

## 4. Prohibited / read-only paths untouched — VERIFIED by SHA-256, base vs head

Computed by me from `git show <rev>:<path>` (not copied from the report). My digests match the
implementer's for the four named files.

| Path | SHA-256 (first 16) | base→head |
|---|---|---|
| `docker/nginx.conf` | `896d3e27590c7eac…` | IDENTICAL |
| `docker/compose.test.yaml` | `e3ff12bfc77b0f2d…` | IDENTICAL |
| `docker/compose.e2e.yaml` | `6501cbadd63bbfaa…` | IDENTICAL |
| `docs/deployment/local-qa.md` | `76a668bf2bf1ab7f…` | IDENTICAL |
| `docker/Dockerfile.server` | `533ac60d2bd1136e…` | IDENTICAL |
| `docker/Dockerfile.client` | `b3a1f5ae0540e358…` | IDENTICAL |
| `docker/nginx.conf.template` | `1439acee928c0923…` | IDENTICAL |
| `docker/compose.yaml` | `07211851742f9c1a…` | IDENTICAL |
| `AGENTS.md` | `6079116851c483fc…` | IDENTICAL |
| `Makefile` | `7a61deb5e50a4b2a…` | IDENTICAL |
| `apps/control_plane/lib/data/client_provider.dart` | `130ee2452eb6be03…` | IDENTICAL |

**Nothing under `apps/**` was touched.** Combined with the clean `git status --porcelain` and the
single-file numstat, the change is exactly what it claims.

---

## 5. No mutating Docker command was needed, and none was used — VERIFIED

- The change is **text-only**: one token in one YAML file. No build artifact, no image, no container
  state is implied by editing a publish mapping.
- Nothing in the repository's tooling depends on QA's host port: `git grep -nE '8080|8180|qa-up|compose.qa' -- .github/`
  → **zero matches**. No CI job reads this file. So this change cannot break CI, and CI needs no update.
- No Dart test or validation script parses compose files (`cli/**`, `scripts/**`, `tool/**`, `*/test/**`,
  `*.sh` → only `docker/build-client.sh`, which mentions `compose.qa.yaml` in an echo string and no port).
  I therefore verified that `format` / `analyze` / `tests` / `build` are **genuinely n/a** rather than
  accepting the claim: no Dart file changed, so no Dart gate has a subject.
- Self-consistency re-checked: the file still parses; container-side wiring intact; the compose project
  is unchanged (`docker`, from the directory name); volumes, healthcheck and `depends_on` untouched.
- The container is **not** recreated by this change. Recreating it to pick up `8180:8080` is
  deployment authority and is correctly left to the Manager. A subtlety worth stating: recreating
  before this lands would still publish 8080 and still fail to bind, so the ordering matters.

**No gate applies, and no gate was skipped.** The report's `NOT_RUN` marking is honest rather than
a gap.

---

## 6. The refused `docker compose config` — the refusal was CORRECT, and the substitute is ADEQUATE

`AGENTS.md:118`, verbatim:

> A lane without explicit deployment or infrastructure authority runs **no** Docker or Compose command
> that can change state: … Not even a read-only-looking one. `docker compose ps`, `logs`, **`config`**
> and `docker info` are **not granted either** — they are unnecessary, because compose files are
> readable as text, and **every exception is a precedent for the next exception**.

Reinforced by `AGENTS.md:112` ("binds every agent and every lane — implementers, reviewers, designers,
QA and research alike") and `AGENTS.md:127` ("Reading a compose file or the Dockerfile as **text** is
the supported way to establish what a stack does").

**Judgment: refusing was correct.** The dispatch's `VALIDATION_COMMANDS` granted a command that a
human-mandated rule names explicitly as not granted; that is a self-contradiction in the dispatch, not
a permission. A Manager dispatch is not a human waiver — `AGENTS.md` reserves that to the human gate —
and the rule was written in blood (`AGENTS.md:106-110`: a review lane destroyed the QA database
irrecoverably). Taking the first "it's only read-only" exception in that rule would have been the
wrong call regardless of the command's actual harmlessness. **The contradiction is the Manager's to fix.**

Two further points in the implementer's favour:

- It logged `config=NOT_RUN` rather than claiming a pass. That is exactly the discipline this framework
  demands: a non-run gate is reported as a non-run, never dressed up as a green.
- The substitute produces **the same two facts the gate existed to confirm**, which are static
  properties of the text: the published host port (`8180`) and the container port (still `8080`).
  `--no-interpolate` would in fact yield *less*, since it deliberately skips interpolation, and it
  cannot observe a runtime bind either. The residual gap — Compose schema acceptance and
  `env_file: ../.env` resolution — is negligible for a one-token edit in a file that was already
  starting successfully. **Acceptable substitute for this specific evidence.**

**My own use, for consistency:** I did not run `docker compose … config` either. I read every compose
file as text and parsed the YAML, which is the method `AGENTS.md:127` sanctions. I used only `git`,
`sed`, `grep`, `od`, `shasum`, `ruby` and `lsof`. `lsof` reads the host socket table and does not
contact the Docker daemon, so it is not a Docker command. **No stack was started; nothing to disclose.**

---

## 7. BLOCKERS

**NONE.**

---

## 8. HIGH

**H-1 — `Makefile:83` prints a now-wrong server URL as a live instruction. (introduced/worsened by
this change; NOT a merge blocker; fold into the same merge.)**

```make
83:	@echo "  Server:  http://localhost:8080"
```

`make qa-up` **prints** this after the stack comes up. After this change a human or agent is handed a
URL that points at Penpot, not ShipIt. It is live output, not prose, which makes it the single most
likely thing to mislead. `Makefile` was outside `OWNED_PATHS`, so the implementer was right not to
touch it — but this is a one-line edit in the same conceptual unit as the fix and should not be left
to rot. Severity is HIGH because of consequence and immediacy, not because it blocks QA from starting:
the UI (`8081`) and API (`8081/api/`) lines it prints are still correct, so the workflow completes.

**H-2 — `docs/deployment/local-qa.md:281` QA health check is doubly wrong. (introduced by this change;
NOT a merge blocker; high-priority follow-up.)**

```
281: 3. Verify server is healthy: `curl http://localhost:8080/health`
```

Wrong on two axes. (a) The port is now `8180`. (b) More seriously, the **method** is wrong: a bare
status-only `curl` against a published host port cannot distinguish "the ShipIt server answered" from
"something else on this machine answered." That is exactly the failure that wasted hours here —
Penpot returned `200` on 8080 while `docker-server-1` had already exited cleanly, and the check
reported success. The replacement must assert **identity** (a ShipIt/Servepod-specific response header
or body marker), not HTTP 200. The implementer diagnosed this precisely. The file was `READ_ONLY` for
this lane, so flagging was the correct action.

**H-3 — `docker/compose.yaml:71` — the local dev stack publishes `8080:8080` and is therefore
likewise unstartable while Penpot holds 8080. (PRE-EXISTING sibling defect; correctly out of scope.)**

Same class of bug, different file, different stack. Not in the implementer's `OWNED_PATHS` and not in
the dispatch's scope; flagging rather than touching was correct. But it means the underlying problem —
host 8080 is occupied by a long-lived Penpot process on this machine — is **not solved** by this
change; only the QA stack is rescued. Deserves its own task. Note that `make client-dev`
(Makefile:277) starts the QA stack and prints `CONTROL_PLANE_API=http://localhost:8081/api/`, so it is
**not** broken by this change.

---

## 9. MEDIUM

**M-1 — `PORT_OFFSET` is documented across four places and implemented nowhere.** `.env.example:9-11`
("Set to 0 for defaults (5432, 8080, 8081)", "PORT_OFFSET=1000 maps to 15432, 10880, 10881"),
`docs/deployment/local-qa.md:81,256-257`, `docs/deployment/test-environment.md:71`, and the design
brief's risk mitigation ("Port conflicts on developer machines → Document `PORT_OFFSET` env var").
Verified: `docker/compose.yaml` and `docker/compose.qa.yaml` contain **no `${…}` interpolation at
all**; only `compose.test.yaml` interpolates (`${SERVERPOD_DATABASE_PASSWORD:-}`,
`${SHIPIT_TEST_DB_PORT:-9199}`). So `PORT_OFFSET=1000 docker compose -f docker/compose.qa.yaml up`
silently does nothing, and a documented escape hatch from exactly this bug does not exist. This change
is a hardcoded point fix, which is the right call for a one-line hotfix, but the divergence should be
recorded. Whether to implement `PORT_OFFSET` or keep hardcoding is an **architecture decision** and
should be routed to a human, not silently resolved in a correction lane.

**M-2 — Documentation sweep incompleteness: two stale "Local QA" port tables the implementer missed.**
- `docs/deployment/e2e-integration.md:77` — `| Ports | Published to host (5432, 8080, 8081) | Internal only |`
  under a **"Local QA"** column. Now stale.
- `docs/engineering/learning/local-deployment-systematization.md:57` — the same row, under a
  `compose.qa.yaml` column in a `DEPLOYMENT_DISCOVERY` table. Now stale.

The report's sweep was otherwise thorough and correctly classified several traps (I checked two of its
judgement calls and both hold: `local-qa.md:54`'s `:8080` genuinely does sit inside the "Host Machine"
box in the diagram, so it is a host port; and `test-environment.md:49,51` genuinely is a **"Local QA"**
column, so those are stale too). But a learning artifact now carrying a wrong port table is
particularly likely to mislead a future agent, and learning artifacts are what other agents read first.

**M-3 — No durable knowledge was persisted.** Per `docs/engineering/LEARNING_POLICY.md`, `PROJECT_FACT`
and `RUNTIME_DISCOVERY` are *automatic*-authority and "may be persisted … when supported by evidence."
The implementer persisted nothing, citing lack of `OWNED_PATHS` write access to
`docs/engineering/learning/**`. **That judgment was correct** — writing outside declared ownership
violates the AGENTS.md invariant that concurrent writers must not overlap — so this is **not an
implementer failure**. It is a routing obligation the Manager now owns. Worth persisting: the complete
published-port landscape (§3a), the fact that Penpot holds 8080 on this host, and M-1. The report's own
`AUTOMATION_OPPORTUNITY` instinct is right and worth keeping: a CI check that fails on published
host-port collisions across compose files would have caught this class of bug at review time rather
than at `docker compose up`.

**M-4 — Verification-gap: `docker/nginx.conf` is not in any image; the live config is the template.**
`Dockerfile.client:22` copies `docker/nginx.conf.template` → `/etc/nginx/conf.d/default.conf.template`,
and `entrypoint.client.sh:11` envsubsts it from `${API_UPSTREAM}`. `git grep 'nginx.conf'` shows
**nothing** ever copies `docker/nginx.conf` into an image. So the authoritative reference the dispatch
named (`nginx.conf:21`) is a dead file, and the running proxy target is
`nginx.conf.template:21` → `http://server:8080/` via `API_UPSTREAM` (`compose.qa.yaml:72`). Both are
container-scoped, so **the verdict is unaffected** — but the report's "all four references are
container-scoped" enumeration is incomplete: there are **five**, and the load-bearing one was not
identified. The commit message compounds this by asserting "`docker/nginx.conf` needs no change" as
though it were live. No action required for correctness; the reference list should be corrected wherever
it is reused.

---

## 10. LOW

- **L-1 — Report inaccuracy: "`File still ends with a newline`" (report §1) is false.** `git show HEAD:docker/compose.qa.yaml | tail -c 3 | od -c`
  → `q a :` — no trailing newline. **Identical at base `dbb1d75`**, so nothing was lost and the diff is
  unaffected. Harmless, pre-existing, but it is an unverified claim in an otherwise careful report.
- **L-2 — `docs/deployment/local-qa.md` stale host-port references** beyond :281: lines `45`, `54`,
  `70`, `112`, `113`, `150`, `253`, `258`, `262`. All confirmed stale; the report's per-line
  classification (host vs container) is accurate on every one I checked.
- **L-3 — Unqualified publish mappings bind `0.0.0.0`.** `- "8180:8080"` exposes the QA API on all
  interfaces. This is **pre-existing** — a known design finding (`D-7 loopback unenforced`,
  `design-review-addproduct-keyservice/report.md:30`), not introduced here, and correcting it changes
  network-exposure semantics, so it is a deliberate decision rather than a drive-by fix. Route to
  `design/port-and-cleanup`.
- **L-4 — Historical records that should probably stay as-is:** `docs/adr/0008-docker-compose-local.md:38,72`;
  `.decisions/570bb640-….yaml:28,29,71` (a decision snapshot — a port map quoted in a decision record
  is evidence of what was decided, and rewriting it destroys that).
- **L-5 — `apps/control_plane/lib/data/client_provider.dart:19`** hardcodes
  `defaultValue: 'http://localhost:8080/'`. Under `PROHIBITED_PATHS`, correctly untouched. Overridden at
  runtime by `CONTROL_PLANE_API`, so it does not affect QA, and it is already recorded as advisory in
  `docs/checkpoints/001-control-plane-operator-ui-human-qa.md:89`. No action.

---

## 11. Learning completeness

Handled **correctly** for this lane, with one obligation transferred to the Manager (M-3). The
implementer applied exactly one category per finding, refused to write outside `OWNED_PATHS`, and
escalated the governance contradiction as `CONTRADICTION`/human decision rather than reconciling it —
which is what `LEARNING_POLICY.md` demands of a `CONTRADICTION` ("must be surfaced and reconciled;
never silently overwrite"). The refusal to self-persist was the right call under the ownership
invariant. The Manager must now persist or route M-1/M-2/M-3's facts.

---

## 12. Docker discipline (both lanes)

| Lane | Docker/Compose commands issued | Disclosure needed |
|---|---|---|
| implementer | **zero** (including read-only `config`/`ps`/`logs`/`info`) | none |
| reviewer (me) | **zero** (including `config`, which I declined for the same reason as the implementer) | none |

Neither lane started a stack, so there was nothing to tear down and no test resource was created.
`AGENTS.md` § Shared Docker state was honoured in full by both.

---

## 13. SAFE_PARALLEL_WORK

**Safe.** Any lane that reads `docker/**`, `docs/**`, `apps/**`, `packages/**`, or runs non-Docker
gates. The change is a single committed line on a clean tree; no container or database state is
touched, so nothing is unsafe to read.

**Prohibited.**
- Any second writer of `docker/compose.qa.yaml` until this merges — it would break the one-line diff guarantee.
- **Any Docker or Compose command whatsoever**, including read-only ones, from a lane without deployment
  authority. Note in particular that `qa-down` (`down -v`) destroys the QA database **on purpose**, and
  `make clean` / `test-env-down` / `e2e-down` resolve to project `docker` and are **never safe**.
- Recreation of the QA stack **before** this change is in effect — it would still publish 8080 and still
  fail to bind. Order matters.

**Integration hazards worth recording (checked):**
- `main` == `dbb1d75` and the branch is a clean fast-forward.
- Three concurrent branches still carry the old mapping at `compose.qa.yaml:56` — `design/port-and-cleanup`
  (eab3a5b), `qa-contract/port-cleanup` (14608dc), `design/qa-startup-restructure` (a8a990b). None modified
  that line, so no textual conflict, but **any lane that regenerates or re-derives `compose.qa.yaml` from a
  stale copy can silently revert 8180.** The mapping must not be "fixed" back to 8080 or 8082.
- `qa-contract/port-cleanup` modifies `docker/compose.test.yaml` — the file the whole 8082-rejection argument
  depends on. I confirmed it does **not** touch the 8082/8083 publications, so the argument survives, but the
  coupling is live and worth tracking. (That branch's own change is outside this review's scope and is not
  assessed here.)

---

## 14. Required follow-ups, ranked

1. **H-1** — `Makefile:83` → `http://localhost:8180`. One line; fold into this merge.
2. **H-2** — `docs/deployment/local-qa.md:281` → `http://localhost:8180/health` **and** change the assertion to
   verify identity rather than a bare `200`.
3. **M-2** — `e2e-integration.md:77` and `learning/local-deployment-systematization.md:57` "Local QA" port rows.
4. **L-2** — the remaining `local-qa.md` host-port references (45, 54, 70, 112, 113, 150, 253, 258, 262).
5. **H-3** — separate task for `docker/compose.yaml:71`; the local dev stack is still unstartable.
6. **M-1** — decide `PORT_OFFSET`: implement it, or delete the four places that document it as if it works.
   **Architecture decision → human.**
7. **M-3** — persist the port landscape / Penpot / `PORT_OFFSET` findings per `LEARNING_POLICY.md`.
8. **M-4** — correct the reference list wherever `docker/nginx.conf` is cited as live; the real file is
   `nginx.conf.template`.
9. **Governance (deferred, human-owned)** — reconcile the `config` contradiction: either amend the dispatch's
   `VALIDATION_COMMANDS`, or amend `AGENTS.md:118` to carve out `config --no-interpolate` explicitly so the
   permission has a written home. **Deliberately not blocking this merge** — nothing about this change depends on
   it, and the substitute evidence was independently reproduced above. Recorded here so it is not lost.

---

```
RESULT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP

REVIEWED_HEAD: 7d3a21ee52e1795ed29f10dfa94d04a9edb9e210

BLOCKERS: none

HIGH:
  H-1 Makefile:83 prints `Server: http://localhost:8080` as live `make qa-up` output; now points at
     Penpot. One-line fix, fold into this merge. Not a merge blocker (UI/API lines at 8081 still
     correct, so the QA workflow still completes).
  H-2 docs/deployment/local-qa.md:281 QA health check wrong on port AND on method — a bare `curl` for
     200 cannot tell ShipIt from Penpot, which is what masked the dead server. Needs an
     identity-based assertion.
  H-3 docker/compose.yaml:71 publishes 8080:8080; the local dev stack is equally unstartable while
     Penpot holds 8080. Pre-existing sibling defect, correctly out of scope, needs its own task.

MEDIUM:
  M-1 PORT_OFFSET is documented in .env.example:9-11, local-qa.md:81,256-257, test-environment.md:71 and
     implemented in no compose file (no ${} interpolation in compose.yaml/compose.qa.yaml) — the
     documented escape hatch from this exact bug is inert. Implement-or-delete is an architecture
     decision for a human.
  M-2 Stale "Local QA" port tables missed by the sweep: docs/deployment/e2e-integration.md:77 and
     docs/engineering/learning/local-deployment-systematization.md:57.
  M-3 No durable knowledge persisted. Correct for the implementer (no write ownership); routing
     obligation now belongs to the Manager.
  M-4 Verification gap: docker/nginx.conf is in no image (Dockerfile.client:22 copies
     nginx.conf.template; entrypoint.client.sh:11 envsubsts it). There are five container-scoped
     references, not four, and the load-bearing one is nginx.conf.template:21. Verdict unaffected.

LOW:
  L-1 Report claims the file ends with a newline; it does not — at base or head. Pre-existing,
     harmless, but an unverified claim.
  L-2 local-qa.md stale host-port lines: 45, 54, 70, 112, 113, 150, 253, 258, 262.
  L-3 Unqualified mappings bind 0.0.0.0 (pre-existing D-7 design finding) → design/port-and-cleanup.
  L-4 Historical records to leave alone: ADR 0008:38,72; .decisions/570bb640…yaml:28,29,71.
  L-5 client_provider.dart:19 default localhost:8080 — prohibited path, overridden at runtime, already
     advisory in checkpoint 001:89. No action.

CORRECTION_REQUIRED: NO

HUMAN_DECISION_REQUIRED: NO

SAFE_PARALLEL_WORK: All read-only work over docker/**, docs/**, apps/**, packages/** and any non-Docker
  gates. Prohibited: any second writer of docker/compose.qa.yaml; any Docker or Compose command at all
  (read-only included) from a lane without deployment authority — `qa-down` destroys the QA database on
  purpose and `make clean` / `test-env-down` / `e2e-down` resolve to project `docker` and are never safe;
  recreation of the QA stack before this change is in effect. Integration note: main == dbb1d75 and this
  is a clean fast-forward, but `design/port-and-cleanup`, `qa-contract/port-cleanup` and
  `design/qa-startup-restructure` all still carry 8080 at compose.qa.yaml:56, so any lane that regenerates
  that file from a stale copy can silently revert 8180. Two items are deliberately deferred to the human
  rather than routed into a correction loop: the AGENTS.md:118 vs dispatch `config` contradiction (M/governance
  item 9 above) and the PORT_OFFSET implement-or-delete decision (M-1). Neither blocks this merge.
```
