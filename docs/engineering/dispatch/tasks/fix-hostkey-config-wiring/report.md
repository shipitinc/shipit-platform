# Report — fix-hostkey-config-wiring

```
RESULT: IMPLEMENTED

FEATURE:   Deliver the host-key attestation values to the Flutter web client in the docker path
TASK_ID:   fix-hostkey-config-wiring
TASK_TYPE: correct
BRANCH:    fix/hostkey-config-wiring
BASE_SHA:  c110aa243f41d0bedf7dcc6de72b7462173461f6
HEAD_SHA:  437cdb67a9b82ca1e6352745d1614df188f3eb46
WORKTREE:  /private/tmp/shipit-fix-hostkey
COMMIT:    437cdb6  fix(docker): deliver the host-key attestation values to the client
PUSHED:    no   MERGED: no   MAIN TOUCHED: no (main still at c110aa2)
```

Provenance verified **before** writing, exactly as instructed:

| Check | Expected | Actual | Result |
|---|---|---|---|
| `git branch --show-current` | `fix/hostkey-config-wiring` | `fix/hostkey-config-wiring` | match |
| `git rev-parse HEAD` | `c110aa2` | `c110aa243f41d0bedf7dcc6de72b7462173461f6` | match |

Working tree was clean at `c110aa2`; `main` is still at `c110aa2` and was never checked out or written.

## OWNED_PATHS — all three written, nothing outside them

| Path | Change |
|---|---|
| `docker/entrypoint.client.sh` | both names added to the envsubst allowlist |
| `docker/compose.qa.yaml` | `${VAR:-}` passthrough to the `client` service |
| `docker/config.js.template` | both keys published on `window.SHIPIT_CONFIG` |

`git diff --name-only c110aa2` returns **exactly** those three paths and nothing else — asserted mechanically as a gate.

## READ_ONLY_PATHS — read, never written

`docker/build-client.sh`, `docker/Dockerfile.client`, `apps/control_plane/lib/**` (in the *other* lane's worktree, read to learn the contract), `docs/engineering/dispatch/tasks/fix-generate-and-hostkey-config/report.md`.

## PROHIBITED_PATHS — untouched

`apps/**`, `packages/**`, `.github/**`, `.github/workflows/**`, `docs/adr/**`, `.decisions/**`, and out-of-scope `docker/compose.test.yaml` / `docker/compose.e2e.yaml` — each asserted clean by a gate.

---

## 1. The envsubst allowlist change, and proof the literal-placeholder failure was real

### The change

`docker/entrypoint.client.sh:18-19`, preserving the script's existing single-line `envsubst '<allowlist>' < in > out` style (wrapped only to stay inside line length):

```sh
envsubst '${CONTROL_PLANE_API} ${SHIPIT_HOST_KEY_FINGERPRINT} ${SHIPIT_OPERATOR_NAME}' \
  < /usr/share/nginx/html/config.js.template > /usr/share/nginx/html/config.js
```

The `${API_UPSTREAM}` nginx substitution on line 22 is untouched — verified by gate.

### I verified the prior lane's finding rather than inheriting it. It is real, and worse than stated.

Run against the **new** template with **both values genuinely set** in the environment, using the **old** allowlist:

```
$ SHIPIT_HOST_KEY_FINGERPRINT="SHA256:lN8pWeZ0mLYH1QqxLBFqLbHzXQ1kM7v6cYt3pJKnR2s" \
  SHIPIT_OPERATOR_NAME="Ada Lovelace" \
  CONTROL_PLANE_API="http://localhost:8081/api/" \
  envsubst '${CONTROL_PLANE_API}' < config.js.template

    CONTROL_PLANE_API: "http://localhost:8081/api/",
    HOST_KEY_FINGERPRINT: "${SHIPIT_HOST_KEY_FINGERPRINT}",
    OPERATOR_NAME: "${SHIPIT_OPERATOR_NAME}"
```

The literal survives **even though the values are set**. The prior lane described it as "a template-only edit would ship a literal"; the stronger and more alarming fact is that the correct value was *available and ignored*.

### And the client would have accepted that literal as a real fingerprint

I replicated `OperatorAttestation._configured` from `impl/client-addproduct-keyflow` (`2f6b78d`, read-only) rather than reasoning about it:

```
  unset (empty string)                          -> null  (UNSET — flow blocked, honest)
  unset (whitespace)                            -> null  (UNSET — flow blocked, honest)
  the LITERAL the old allowlist emits          -> "${SHIPIT_HOST_KEY_FINGERPRINT}"  (CONFIGURED)
  real value                                    -> "SHA256:lN8pWeZ0mLYH1QqxLBFqLbHzXQ2s"  (CONFIGURED)
```

`_configured` trims and accepts **any** non-blank string. The literal is non-blank, so `isComplete` is `true` and `add_product_page.dart:946` would render the placeholder text in the operator's trust-on-first-use slot. Confirmed: a template-only edit is a security-relevant lie, worse than the `null` it replaces. The refusal was correct.

### The key-name contract (why the template keys are bare)

`operator_attestation.dart:53,57` calls `readRuntimeConfigValue('HOST_KEY_FINGERPRINT')` and `('OPERATOR_NAME')` against `window.SHIPIT_CONFIG`. So the **published keys** are bare (`HOST_KEY_FINGERPRINT`, `OPERATOR_NAME`) while the **placeholders** are full env var names (`${SHIPIT_HOST_KEY_FINGERPRINT}`). The client source also carries a note addressed to the owner of `config.js.template` saying that file enumerates the keys it publishes — that contract is what I implemented. Had I published `SHIPIT_HOST_KEY_FINGERPRINT` as the key, the client would still have read `null`.

---

## 2. The compose passthrough form, and why `${VAR:-}` rather than a required variable

```yaml
    environment:
      CONTROL_PLANE_API: "http://localhost:8081/api/"
      API_UPSTREAM: "server:8080"
      SHIPIT_HOST_KEY_FINGERPRINT: "${SHIPIT_HOST_KEY_FINGERPRINT:-}"
      SHIPIT_OPERATOR_NAME: "${SHIPIT_OPERATOR_NAME:-}"
```

**Why `${VAR:-}`:** `AGENTS.md` § Shared Docker state records that a mandatory Compose variable (`${VAR:?...}`) in a shared compose file breaks **every** command that reads that file, not just the service needing it — Compose interpolates the whole file before it filters profiles/services, and interpolates even for read-only commands. `docker/compose.qa.yaml` is shared by the live QA stack. A required variable would therefore turn "an operator forgot to export a fingerprint" into "nobody can read the QA compose file at all, including `config`". `${VAR:-}` is optional with an empty default, so the file always interpolates.

**Why not `${VAR}` (bare):** it would also yield empty, but `${VAR:-}` states the intent explicitly and guarantees the key is *defined* in the container environment as an empty string. Both compose and envsubst treat "defined-but-empty" as the honest "unset" signal; spelling it out documents that and leaves no room for a future reader to add a default.

**No default is given for the fingerprint.** There is no fallback value anywhere on this path — a deployment that supplies nothing gets nothing, which is the behaviour ADR 0018 requires (an unset host key must not look configured).

### Why empty is the correct "unset" encoding, proven at the consumer

An unset value must be *observably* unset. Proof that it is, end to end at `HEAD 437cdb6`, with the allowlist extracted from the **committed** entrypoint and run against the **committed** template:

**Direction 1 — values SET:**
```
    CONTROL_PLANE_API: "http://localhost:8081/api/",
    HOST_KEY_FINGERPRINT: "SHA256:lN8pWeZ0mLYH1QqxLBFqLbHzXQ1kM7v6cKt3pJKnR2s",
    OPERATOR_NAME: "Ada Lovelace"

  SET    client reads -> fp="SHA256:lN8pWeZ0mLYH1QqxLBFqLbHzXQ1kM7v6cKt3pJKnR2s"
                         op="Ada Lovelace"   isComplete=true
```

**Direction 2 — values UNSET** (`env -u` for all three):
```
    CONTROL_PLANE_API: "",
    HOST_KEY_FINGERPRINT: "",
    OPERATOR_NAME: ""

  literal '${' occurrences in UNSET output: 0
  literal '${' occurrences in SET   output: 0

  UNSET  client reads -> fp=null   op=null   isComplete=false
```

Both `SHIPIT_CONFIG` objects were parsed out of the generated `config.js` in a JS context and pushed through the client's own `_configured` logic. Set → real values, flow enabled. Unset → empty strings → `null`, flow blocked honestly, **zero** literal `${...}` anywhere in the output.

**Nothing hardcoded** — asserted mechanically, not by eye: no `SHA256:<base64>` literal in any of the three files, and every non-comment occurrence of either variable name resolves to a `${...}` substitution:

```
  docker/entrypoint.client.sh:18  substitution=True  envsubst '${...} ${SHIPIT_HOST_KEY_FINGERPRINT} ${SHIPIT_OPERATOR_NAME}' \
  docker/compose.qa.yaml:81       substitution=True  SHIPIT_HOST_KEY_FINGERPRINT: "${SHIPIT_HOST_KEY_FINGERPRINT:-}"
  docker/compose.qa.yaml:82       substitution=True  SHIPIT_OPERATOR_NAME: "${SHIPIT_OPERATOR_NAME:-}"
  docker/config.js.template:18    substitution=True  HOST_KEY_FINGERPRINT: "${SHIPIT_HOST_KEY_FINGERPRINT}",
  docker/config.js.template:19    substitution=True  OPERATOR_NAME: "${SHIPIT_OPERATOR_NAME}"

HARDCODED ASSIGNMENTS: NONE
```

Both values remain substitutable from the environment: `SHIPIT_HOST_KEY_FINGERPRINT=… docker compose -f docker/compose.qa.yaml up`, or a `docker/.env` next to the compose file.

## Semantics preserved (M-5)

Both comments I added — in the template and in compose — state plainly that the values are **operator-asserted, not server-verified**, that their provenance is the deployment's configuration and never the server, and that nothing defaults them. Neither the key names, the placeholders, nor the comments imply verification, and no comment describes the fingerprint as proof of host identity. `isComplete` remains the only thing that gates the flow, and it stays false when unset.

---

## 3. Gates (all re-run at HEAD `437cdb6`, after the commit)

```
  PASS  bash -n docker/entrypoint.client.sh
  PASS  sh -n docker/entrypoint.client.sh (#!/bin/sh)
  PASS  compose.qa.yaml parses as YAML
  PASS  no top-level name: added
  PASS  client env passes both as ${VAR:-}
  PASS  nginx allowlist ${API_UPSTREAM} preserved
  PASS  config.js allowlist has both new names
  PASS  config.js.template publishes both keys
  PASS  no fingerprint literal in the three files
  PASS  compose.test/e2e untouched
  PASS  only OWNED_PATHS changed

  passed=11 failed=0
```

Exact commands:

- `bash -n docker/entrypoint.client.sh` — **pass** (the dispatch's `VALIDATION_COMMANDS` entry)
- `sh -n docker/entrypoint.client.sh` — **pass** (extra: the shebang is `#!/bin/sh`, and the file is line-wrapped, so I checked the interpreter that actually runs it)
- `ruby -ryaml -e 'YAML.safe_load(...)'` — **pass** (structural validation of the compose edit)
- envsubst simulation, both directions — **pass** (outside the repository)

**Two harness bugs I hit and corrected, disclosed rather than hidden.** My first gate runner reported two FAILs. Both were bugs in my *test harness's* nested shell quoting (`$(...)` and `${...}` inside `eval` inside a double-quoted argument), not defects in the change: the `${VAR:-}` check failed with a Ruby `syntax error, unexpected ')'`, and the nginx-allowlist check failed because `grep` lost the `'${API_UPSTREAM}'` quoting. I rewrote the runner as a script file with `grep -F`/heredoc literals and both pass. A third FAIL was my own over-broad regex flagging `"${VAR:-}"` as a hardcode; a precise per-line classifier replaced it and reports `HARDCODED ASSIGNMENTS: NONE`. Also, an earlier `rg -rn` invocation silently mangled its own output (`-r` is *replace*, not recursive) — that search was redone correctly and found no test or CI file pinning any of these three files.

`shellcheck` (not a CI gate in this repo, run for extra rigor) reports one `SC2016` info on my line: *"Expressions don't expand in single quotes"*. That is a **false positive and is required behaviour** — the single quotes are what stop the shell expanding the allowlist, which is the entire mechanism. I confirmed it is not a new finding: **SC2016 count is 2 at `BASE_SHA` and 2 at `HEAD_SHA`**, the other being the pre-existing `${API_UPSTREAM}` line. Nothing to fix; changing to double quotes would break the substitution.

```
format=   n/a  — no Dart/Flutter source touched; `git diff --name-only c110aa2` contains zero .dart files.
analyze=  n/a  — same evidence; CI's `melos run analyze` cannot be affected by three docker/ text files.
tests=    n/a  — same evidence; no test, golden, fixture, or workflow references these three files
                  (searched; the only hit outside docs is a doc comment in runtime_config_web.dart,
                  which my change leaves accurate).
build=    n/a  — the client image build is `flutter build web` + `COPY` of the template; the template
                  compiles as JS, proven by parsing the generated config.js in node. Building the image
                  would require a mutating `docker build`, which this lane is forbidden to run.
runtime=  n/a  — not applicable: the change's observable surface is the generated config.js, and it is
                  fully determined by the envsubst substitution, which I executed against the committed
                  HEAD both ways. No browser or live stack validation was performed or claimed.
```

I report the Dart/Flutter gates as `n/a` on explicit mechanical evidence rather than as `pass`: I did not run them, and I will not claim a green I did not observe. The reviewer can require them if they disagree that the surface is disjoint — a zero-`.dart`-file diff is the argument.

## Zero mutating Docker — compliance and disclosure

**I issued no `docker` or `docker compose` command of any kind this session** — not even the read-only ones. Every command was `git`, `bash -n`, `sh -n`, `envsubst`, `ruby`, `python3`, `node`, `grep`/`rg`/`sed`, `xxd`, `ls`/`cat`. The QA stack is therefore untouched: no `up`, `down`, `build`, `stop`, `restart`, `pull`, no `compose ps`/`config`, nothing. No breach to disclose. Compose files and scripts were read as text only; `Dockerfile.client` and `build-client.sh` were read to establish that the template is baked in and substituted at container startup.

## Findings reported, not acted on

1. **`docs/deployment/local-qa.md:96-99` is now stale** — its "Client Runtime Configuration" table lists only `CONTROL_PLANE_API` and `API_UPSTREAM`, and line 101 says "These are substituted into `/usr/share/nginx/html/config.js`". Both new variables are now also accepted and substituted into that file. `docs/deployment/**` is outside my `OWNED_PATHS` (and not in `PROHIBITED_PATHS`), so I did not edit it. **Recommend a small doc-only follow-up lane.** Same applies to `docs/deployment/test-environment.md`, `e2e-integration.md`, and `docs/engineering/learning/local-deployment-systematization.md:41`.
2. **Compose project rename — NOT done, as instructed.** I agree the defect AGENTS.md records is real: `docker/compose.test.yaml` and `docker/compose.e2e.yaml` declare no top-level `name:` and resolve to project `docker`, the live QA stack's project, so `test-env-down` / `e2e-down` would destroy QA volumes. I did not add `name:` anywhere — not to `compose.qa.yaml` (would silently re-home the live stack), nor to the out-of-scope test/e2e files. This needs its own lane with deployment authority; it is already tracked in `design/port-and-cleanup`.
3. **Deployment ergonomics.** `compose.qa.yaml` auto-loads `.env` from its own directory, i.e. `docker/.env`, whereas the `server` service pulls `../.env` via explicit `env_file`. So an operator setting these two values via a `.env` file must use `docker/.env`, not the repo-root one. My in-file comment records the two supported routes. I deliberately did **not** add `env_file: ../.env` to the client: it would inject the server's whole environment into the client container and would break the stack when `../.env` is absent — a scope and blast-radius increase well beyond wiring two values.
4. **Worktree path discrepancy.** `prompt.md` names `WORKTREE: /private/tmp/shipit-fix-hostkey-config`; the actual worktree, and the directory the dispatch instructs, is `/private/tmp/shipit-fix-hostkey`. `git worktree list` confirms `/private/tmp/shipit-fix-hostkey` is the registered worktree for `fix/hostkey-config-wiring`. I proceeded in the real one. The prompt's `WORKTREE` value looks like a stale string.
5. **The allowlist/template coupling is now three-way and unguarded by tooling.** Nothing mechanically enforces that every placeholder in `config.js.template` appears in the allowlist — the exact omission that made this trap real. A cheap executable guard (a test asserting every `${VAR}` in the template is in the entrypoint allowlist) would convert a silent security-relevant regression into a test failure. Classified `AUTOMATION_OPPORTUNITY`; I did not add it, as no test path is in my ownership.

## DISCOVERIES (classified per `docs/engineering/LEARNING_POLICY.md`)

- **`RUNTIME_DISCOVERY`** — `envsubst`'s allowlist form silently emits non-listed `${...}` as **literal text even when the variable is correctly set in the environment**. The failure is silent: exit 0, valid-looking output. Persisted as executable proof in this report and encoded as a comment at `entrypoint.client.sh:8-17`. Verified on `envsubst (GNU gettext-runtime) 1.0`.
- **`PROJECT_FACT`** — The client's runtime-config contract is `window.SHIPIT_CONFIG` keyed by **bare** names (`HOST_KEY_FINGERPRINT`, `OPERATOR_NAME`), read via `readRuntimeConfigValue(key)` in `apps/control_plane/lib/data/runtime_config_web.dart`, while the template placeholders are **full** env var names. An empty string is the correct encoding for "unset": `OperatorAttestation._configured` trims and maps blank to `null`, which flips `isComplete` to `false`. Verified by executing the client's own logic.
- **`PROJECT_FACT`** — No test, golden, fixture, or CI workflow references `docker/config.js.template`, `docker/entrypoint.client.sh`, or the client environment table. Changes to the docker client wiring are validated by shell/YAML syntax plus manual substitution simulation, not by the test suite; that is why gates here are necessarily `n/a` for Dart/Flutter.
- **`AUTOMATION_OPPORTUNITY`** (reported, not persisted) — a test asserting every placeholder in `config.js.template` appears in the `entrypoint.client.sh` allowlist.
- **`EPHEMERAL`** — `SC2016` on envsubst allowlist lines is a permanent false positive; count was already 2 before my change.

**KNOWLEDGE_PERSISTED:** none written outside my three owned files. The durable findings above are recorded in this report; the executable form of the envsubst trap is preserved as a comment in the owned script itself (in-repo, versioned, self-documenting). Nothing was written to knowledge stores, ADRs, or decisions, as that exceeds this lane's authority.

## BLOCKERS

None.

## Anything I could not do

1. **Run the Dart/Flutter gates** (`melos run analyze` / `format` / `flutter test`). Reported as `n/a` with a zero-`.dart`-file diff rather than as an unobserved pass. See reasoning above.
2. **Validate against a live container or browser.** Producing real evidence would require `docker compose up` / `docker build` / `build-client.sh`, all mutating and forbidden by `AGENTS.md` § Shared Docker state. The QA stack's live `config.js` was deliberately **not** regenerated, so the running QA client still reads `null` for both values until someone restarts it with this branch's template. Flagging that explicitly so the reviewer does not read "values reach the client" as "already reaching the running QA client".
3. **Edit `docs/deployment/**`.** Outside `OWNED_PATHS`; reported as finding 1 instead of fixed unilaterally.
4. **Add a placeholder/allowlist consistency test.** No test path is in my ownership; reported as finding 5.
5. **Fix the `compose.test`/`compose.e2e` project-scoping defect.** Out of scope and needs deployment authority; reported as finding 2.
6. **`docker compose config` verification of the interpolated client environment.** `AGENTS.md` explicitly withholds even read-only compose commands from this lane, so the `${VAR:-}` form is validated by YAML structure + the `${VAR:-}` semantics, not by observing Compose's expansion. I consider the interpolation form unambiguous and its failure mode (empty string) independently proven at the envsubst step, but a reviewer with compose authority can close this in one command.

---

```
SAFE_PARALLEL_WORK:
  - Focused review of this lane (2f6b78d client keyflow + this lane) and of
    apps/server/test/endpoint_surface_shape_test.dart — read-only, no overlap.
  - Docs-only lane updating docs/deployment/** and
    docs/engineering/learning/local-deployment-systematization.md for the new client env table
    (finding 1). No source overlap with docker/**.
  - A test/CI lane adding the placeholder-vs-allowlist consistency guard (finding 5),
    provided it writes only to a test path and does not modify the three docker files.
  - Any lane re-scoping compose.test.yaml / compose.e2e.yaml with deployment authority
    (finding 2) — it must NOT add a top-level name: to compose.qa.yaml.
  - Read-only analysis anywhere, including apps/** and packages/**.

PROHIBITED_PARALLEL_WORK:
  - Any WRITE to docker/entrypoint.client.sh, docker/compose.qa.yaml or
    docker/config.js.template until this lane is independently reviewed and integrated.
    These three files are the unit of change; the allowlist and the template must be
    changed together or the literal-placeholder trap returns.
  - Any write to apps/** or packages/** while impl/client-addproduct-keyflow (2f6b78d)
    is unintegrated. NOTE: this lane's client-side contract depends on that lane's
    readRuntimeConfigValue('HOST_KEY_FINGERPRINT'|'OPERATOR_NAME') key names. Integrating
    this lane without 2f6b78d yields a correctly-populated config.js that the client
    never reads — the values would appear in DevTools and still be null in the UI.
    Integration order matters: 2f6b78d first, or together.
  - Any write to docker/compose.test.yaml, docker/compose.e2e.yaml, or any other
    docker/compose.*.yaml while this lane is under review (shared-project hazard).
  - Any mutating Docker or Compose command from any lane without explicit deployment
    authority — including `make clean`, `test-env-down`, `e2e-down`, and bare
    `docker compose … down -v`, all of which resolve to project `docker`, the live
    QA stack. The QA stack is currently up and healthy on a stopgap run-mode override;
    it must not be disturbed.
  - Adding a top-level `name:` to ANY compose file (silently re-homes a live stack).
  - Touching main, pushing, or merging until independent review passes.

READY_FOR_INDEPENDENT_REVIEW: YES
```

I have not approved this work. It requires independent review.