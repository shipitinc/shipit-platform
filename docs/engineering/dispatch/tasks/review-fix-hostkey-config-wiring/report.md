# Report — review-fix-hostkey-config-wiring

```
RESULT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP

REVIEWED_HEAD: 437cdb67a9b82ca1e6352745d1614df188f3eb46
```

Independent engineering review. Read-only: I issued **zero** `docker` / `docker compose` commands of
any kind — not `up`/`down`/`build`/`stop`/`restart`/`pull`, and not `ps`/`config`/`logs` either. Compose
files, Dockerfiles and scripts were read as text. envsubst simulation ran in the session temp dir
(`/var/folders/.../T/opencode/hostkey-review`), never in the repository. Worktree left pristine
(`git status --porcelain` empty before and after).

The lane's report disclosed two bugs in its own gate harness. I did not reuse its harness output; I
re-derived every claim from the repository state.

---

## 1. Provenance — verified

| Check | Expected | Actual | Result |
|---|---|---|---|
| worktree | `/private/tmp/shipit-fix-hostkey` | present, registered in `git worktree list` | match |
| branch | `fix/hostkey-config-wiring` | `fix/hostkey-config-wiring` | match |
| `git rev-parse HEAD` | `437cdb67a9b82ca1e6352745d1614df188f3eb46` | identical | match |
| commit count | ONE | `437cdb6` over `c110aa2` | match |
| `git status --porcelain` | clean | empty | match |
| BASE_SHA on branch history | `c110aa2` | `git log -n 3` shows `c110aa2` as parent | match |

No runtime/browser evidence was claimed or accepted — the lane correctly claimed none, and I produced
none (it would require mutating Docker).

**Prompt/reality discrepancy (documentation only, not a defect in the change):** `prompt.md` declares
`WORKTREE: /private/tmp/shipit-fix-hostkey-config`. The real registered worktree is
`/private/tmp/shipit-fix-hostkey`. The lane disclosed this and proceeded in the real one. Agreed — the
prompt string is stale. Worth fixing in the dispatch record so a future reviewer does not go looking
for a nonexistent path.

---

## 2. Complete diff inspected — scope is exactly three files

`git diff --name-only c110aa2 437cdb6`:

```
docker/compose.qa.yaml
docker/config.js.template
docker/entrypoint.client.sh
```

`git diff --stat`: 3 files, 36 insertions, 2 deletions. Matches `OWNED_PATHS` exactly. No file outside
`OWNED_PATHS` was written. Confirmed absent from the diff: `apps/**`, `packages/**`, `.github/**`,
`docs/adr/**`, `.decisions/**`, and the out-of-scope `docker/compose.test.yaml` / `docker/compose.e2e.yaml`.

`PROHIBITED_PATHS` untouched — verified, not taken on trust. I also confirmed nothing **deleted** a test,
golden, fixture or workflow.

Merge-readiness note: `main` has advanced to `9621b3d` (two **docs-only** commits). `git merge-tree
--write-tree main 437cdb6` → **clean, no conflict**. `c110aa2` is an ancestor of `main`, so this branch
is a fast-forwardable sibling, not a divergent history.

---

## 3. Both directions, reproduced empirically (not accepted from the lane)

Using the **committed** `docker/config.js.template` from `437cdb6` and the exact allowlist string from
committed `entrypoint.client.sh:18`, run with `envsubst` (GNU gettext, `/opt/homebrew/bin/envsubst`):

**Direction 1 — both values SET** → real values reach the served config:

```js
window.SHIPIT_CONFIG = {
  CONTROL_PLANE_API: "http://localhost:8081/api/",
  HOST_KEY_FINGERPRINT: "SHA256:REVIEWPROBEfp0000000000000000000000000000000000000000000=",
  OPERATOR_NAME: "Review Probe"
};
```

**Direction 2 — both values UNSET** (`env -u` for all three) → **empty strings, zero literals**:

```js
window.SHIPIT_CONFIG = {
  CONTROL_PLANE_API: "http://localhost:8081/api/",
  HOST_KEY_FINGERPRINT: "",
  OPERATOR_NAME: ""
};
```

**The trap, independently reproduced.** I re-ran the new template with the **old** (base) allowlist
`'${CONTROL_PLANE_API}'` and both values genuinely set in the environment:

```js
    HOST_KEY_FINGERPRINT: "${SHIPIT_HOST_KEY_FINGERPRINT}",
    OPERATOR_NAME: "${SHIPIT_OPERATOR_NAME}"
```

The prior lane's finding is **real and confirmed by my own run**: the literal survives *even though the
correct value is present in the environment*. The value was available and ignored. This is the exact
security-relevant lie the dispatch warned about — the client renders `attestation.hostKeyFingerprint`
directly into the operator's trust-on-first-use slot
(`add_product_page.dart:1062`: `fingerprint  ${attestation.hostKeyFingerprint ?? 'not configured'}`),
and `_configured` (`operator_attestation.dart:76-85`) trims and accepts **any** non-blank string, so a
literal flips `isComplete` to `true` and is displayed as a fingerprint. The earlier lane's refusal to
finish was correct, and the three-file approach this lane took is the right one.

**No residual literal risk.** Every `${...}` in the template is one of exactly three names
(`${CONTROL_PLANE_API}`, `${SHIPIT_HOST_KEY_FINGERPRINT}`, `${SHIPIT_OPERATOR_NAME}`) and all three are
in the allowlist. There is no fourth placeholder that could escape as literal text today.

---

## 4. The key-name asymmetry — RESOLVED CORRECTLY (the highest-risk item)

This was the failure mode with the most severe symptom: a populated config the client ignores is
indistinguishable from doing nothing. I verified the contract at the source rather than inferring it.

**What the client actually reads** (`/private/tmp/shipit-client-keyflow`, `3f28059`,
`operator_attestation.dart:51-60`):

```dart
hostKeyFingerprint: _configured('HOST_KEY_FINGERPRINT', const String.fromEnvironment('SHIPIT_HOST_KEY_FINGERPRINT')),
confirmedBy:        _configured('OPERATOR_NAME',        const String.fromEnvironment('SHIPIT_OPERATOR_NAME')),
```

`readRuntimeConfigValue(key)` (`runtime_config_web.dart:25-29`) indexes `window.SHIPIT_CONFIG[key]` with
that **bare** key. So:

| Layer | Must be |
|---|---|
| Published JS key on `window.SHIPIT_CONFIG` | **bare** — `HOST_KEY_FINGERPRINT`, `OPERATOR_NAME` |
| Placeholder *inside* that value | **full env var name** — `${SHIPIT_HOST_KEY_FINGERPRINT}` |

The change publishes exactly that:

```js
HOST_KEY_FINGERPRINT: "${SHIPIT_HOST_KEY_FINGERPRINT}",
OPERATOR_NAME: "${SHIPIT_OPERATOR_NAME}"
```

**VERIFIED CORRECT.** Had the lane published `SHIPIT_HOST_KEY_FINGERPRINT:` as the key, the client would
still have read `null` and the whole change would have been inert while looking correct. It did not make
that mistake. `CONTROL_PLANE_API` (the pre-existing key) is preserved under the same bare-name
convention, so the file is internally consistent.

A corroborating detail: `operator_attestation.dart:21-26` carries a note addressed to the owner of
`docker/config.js.template` saying that file "enumerates the keys it publishes" and is outside the
client lane's ownership. This change is the other half of that contract.

---

## 5. No hardcoded values — verified mechanically

Scanned all three files for `SHA256:<base64>`, and for any literal assignment to either key:

- No fingerprint literal anywhere.
- No operator name literal anywhere.
- Every non-comment occurrence of either variable name is a `${...}` substitution
  (`compose.qa.yaml:81-82`, `config.js.template:18-19`, `entrypoint.client.sh:18`).

Both values remain substitutable from the environment. **Nothing hardcoded — pass.**

---

## 6. `${VAR:-}`, not `${VAR:?...}` — and no top-level `name:`

**Mandatory-variable form.** The only `${VAR:?...}` occurrences anywhere in `docker/` are inside
**comments** (`compose.test.yaml:34`, and this change's own explanatory comment at
`compose.qa.yaml:76-77`). No live mandatory interpolation was introduced. Both new lines use
`"${VAR:-}"`.

The reasoning recorded in-file matches `AGENTS.md` § Shared Docker state exactly: Compose interpolates
the whole file before filtering services, and interpolates for read-only commands too, so one
mandatory variable in `docker/compose.qa.yaml` — a file shared by the **live QA stack** — would break
every command that reads it. `${VAR:-}` keeps the file always interpolable. Correct call.

**Top-level `name:`** — confirmed still absent from `docker/compose.qa.yaml`. Also confirmed absent
from `docker/compose.test.yaml` and `docker/compose.e2e.yaml` (both untouched). **No stack re-homing was
introduced.** The live QA stack remains on compose project `docker`.

**No default for the fingerprint.** Confirmed: there is no fallback value on this path anywhere. Unset
yields empty → client normalises to `null` → `isComplete == false` → the flow is blocked and the UI
renders `not configured` plus the "Access cannot be proven until this deployment supplies both"
message. An unset host key cannot look configured.

---

## 7. Semantics not misrepresented (open finding M-5) — pass

Both comments state plainly that the values are **operator-asserted, not server-verified**, that
provenance is this deployment's configuration and never the server, and that nothing defaults them
(`compose.qa.yaml:73-80`, `config.js.template:5-11`). Neither the key names, nor the placeholders, nor
the prose implies verification, proof of host identity, or attestation by the server. The template
comment goes further and explicitly warns against ever hardcoding a fingerprint "as one they are meant
to have read off the provider's published list". This aligns with `operator_attestation.dart:13-17`,
which is equally careful about the same M-5 finding. No drift between the two lanes' language.

---

## 8. Shell gates

```
bash -n docker/entrypoint.client.sh   -> clean
sh   -n docker/entrypoint.client.sh   -> clean
git diff --check c110aa2 437cdb6      -> clean
```

**SC2016 confirmed as a pre-existing false positive, count unchanged.** I ran shellcheck against both
revisions:

- BASE `c110aa2` → **2** SC2016 notes (`line 8` `${CONTROL_PLANE_API}`, `line 11` `${API_UPSTREAM}`)
- HEAD `437cdb6` → **2** SC2016 notes (`line 18`, `line 22`)

Count unchanged at 2 → 2, so the change introduces **no new** shellcheck finding. And the finding is a
false positive: single quotes are precisely what prevents the shell from expanding the allowlist, which
is the entire mechanism. **I empirically confirmed double quotes break the substitution** — running
`envsubst "${CONTROL_PLANE_API} ${SHIPIT_HOST_KEY_FINGERPRINT} ${SHIPIT_OPERATOR_NAME}"` with all three
variables set emits the three **literals** back:

```js
    CONTROL_PLANE_API: "${CONTROL_PLANE_API}",
    HOST_KEY_FINGERPRINT: "${SHIPIT_HOST_KEY_FINGERPRINT}",
    OPERATOR_NAME: "${SHIPIT_OPERATOR_NAME}"
```

Same literal-placeholder trap, reintroduced by "fixing" the lint. Do **not** act on SC2016 here. Also
note shellcheck is not a CI gate in this repository (no reference in `.github/**` or `Makefile`), so it
carries no merge weight regardless.

---

## 9. Integration order — dependency VERIFIED, and it is real

I checked this against `/private/tmp/shipit-client-keyflow` (`3f28059`) rather than taking the lane's word.

**`readRuntimeConfigValue` does not exist at base `c110aa2`.** Base `runtime_config_web.dart` (23 lines)
exposes only `readControlPlaneApi()`, which hardcodes `config['CONTROL_PLANE_API']` — there is no
generic keyed reader, and no `runtime_config_stub.dart` counterpart. `operator_attestation.dart` is
**absent from both `c110aa2` and `main`**, and present only on the client branch. The client branch
contains base (`git merge-base --is-ancestor c110aa2 3f28059` → yes), and it adds
`operator_attestation.dart` (+86) and the generic reader (+21).

**Conclusion: the lane's dependency claim is correct.** `operator_attestation.dart:22-26` says so in the
source itself — the runtime lookup "returns null and the build-time value below is used instead" on a
deployment whose template has not been updated. Inverting that: integrating **this** change alone
without the client branch yields a correctly-populated `config.js` that **nothing reads** — values
visible in DevTools, still `null` in the UI. Harmless but pointless, and it would look like it worked.

**Required integration order: `impl/client-addproduct-keyflow` (`3f28059`) first, or in the same merge.**
This is a sequencing constraint, not a defect in the reviewed diff, and it does not block the change.

---

## 10. Judgement on the Dart/Flutter gates reported as `n/a`

I judge the lane's `n/a` **acceptable and, in fact, the more honest answer.** The reasoning is sound:

1. `git diff --name-only c110aa2 437cdb6 -- '*.dart'` → **empty**. Zero Dart files changed.
2. The change's surface is three text files: a `#!/bin/sh` script, a YAML compose block, and a JS
   template consumed by `envsubst`. None is an input to `melos run analyze`, `melos run format`, or
   `melos run test`.
3. I searched for any test, golden, fixture, or CI workflow referencing `docker/config.js.template` or
   `docker/entrypoint.client.sh` outside the files themselves. The only hit is a **doc comment** in
   `runtime_config_web.dart:7`, which this change leaves accurate (it still names
   `docker/config.js.template` as the source of `config.js`).

The gates *could* have been run for completeness, and a stricter reading of `aef-implementation-workflow`
would ask for that. But running them could only ever have returned green (nothing Dart-dependent moved),
and reporting `n/a` with the mechanical zero-`.dart`-diff evidence avoids claiming an unobserved pass.
That is the behaviour the framework asks for, not a shortcut. **No finding.**

---

## Findings

### BLOCKERS

None.

### HIGH

None.

### MEDIUM

**M-1 — The template↔allowlist coupling is unguarded by any tooling, and this change is the concrete
proof of why that matters.**
`docker/config.js.template` placeholders and the `docker/entrypoint.client.sh` allowlist must be edited
in lockstep, and **nothing mechanically enforces it**. The failure is silent: `envsubst` exits 0 and
emits valid-looking JS containing a literal `${SHIPIT_HOST_KEY_FINGERPRINT}`, which the client accepts
as a configured fingerprint (I reproduced exactly this in §3). I re-ran the lane's search and confirm no
test or CI check covers it. The lane classified this `AUTOMATION_OPPORTUNITY` and correctly did not fix
it — no test path is in `OWNED_PATHS`. **Not a merge blocker** for this change, which is internally
consistent. Recommend a follow-up lane adding a test asserting every `${VAR}` in the template appears
in the entrypoint allowlist. Until it exists, the two files must be treated as one atomic unit by any
future writer.

### LOW

**L-1 — `docs/deployment/local-qa.md:96-99` is now stale.** Its "Client Runtime Configuration" table
lists only `CONTROL_PLANE_API` and `API_UPSTREAM`. Both new variables are also accepted and substituted
into `/usr/share/nginx/html/config.js` (I read the file and confirmed). Same applies to
`docs/deployment/test-environment.md`, `e2e-integration.md`, and
`docs/engineering/learning/local-deployment-systematization.md:41`. `docs/deployment/**` is outside
`OWNED_PATHS` and the lane correctly reported rather than edited. Doc-only follow-up lane.

**L-2 — Operator ergonomics: the values must come from `docker/.env`, not the repo-root `.env`.**
`compose.qa.yaml` auto-loads `.env` from its own directory (`docker/.env`), while the `server` service
pulls `../.env` via explicit `env_file`. An operator following the existing docs will set the variables
in the root `.env` and see them silently ignored. The in-file comment records both routes. The lane
deliberately declined to add `env_file: ../.env` to the client, which would inject the server's entire
environment into the client container and break the stack when `../.env` is absent — correct
judgement, wrong blast radius for this lane. Follow-up: document `docker/.env` in `L-1`'s doc lane.

**L-3 — No trailing newline at end of `docker/config.js.template`.** Pre-existing (verified identical
at base and HEAD: trailing bytes `0a 7d 3b`, i.e. `\n};` with no final newline). `git diff --check`
reports nothing, and this file is not subject to any formatter gate. Cosmetic, not introduced here.

### Learning completeness

Classified per `docs/engineering/LEARNING_POLICY.md`, correctly, and with the right judgement about what
*not* to persist. `RUNTIME_DISCOVERY` (the envsubst allowlist trap) was persisted in its most durable
available form — an executable proof in the report plus an 8-line comment at `entrypoint.client.sh:8-17`
that explains the mechanism to the next person who touches the file, in-repo and versioned.
`PROJECT_FACT` for the bare-key/full-placeholder contract is recorded, and I independently confirm it
from source. `AUTOMATION_OPPORTUNITY` (M-1) was reported rather than unilaterally actioned, which is
the right call given ownership. `KNOWLEDGE_PERSISTED: none` outside owned files is accurate — I verified
no knowledge store, ADR or decision file was written. The `SC2016` finding is correctly classified
`EPHEMERAL`, and my §8 run confirms that judgement.

The two disclosed harness bugs (nested-shell quoting; `rg -r` mangling output) do not reflect on the
change. I did not reuse the harness and re-derived every claim; I found no defect attributable to the
lane's honesty — in both cases the lane disclosed a problem with its own tooling rather than quietly
patching the result, which is what made independent verification possible.

---

```
CORRECTION_REQUIRED: NO

HUMAN_DECISION_REQUIRED: NO

SAFE_PARALLEL_WORK:
  - Docs-only lane updating docs/deployment/local-qa.md (and test-environment.md,
    e2e-integration.md, docs/engineering/learning/local-deployment-systematization.md:41) to list
    SHIPIT_HOST_KEY_FINGERPRINT / SHIPIT_OPERATOR_NAME in the client env table, and to document that
    these come from docker/.env rather than the repo-root .env (findings L-1, L-2).
    No source overlap with docker/**.
  - A test/CI lane adding the template-placeholder vs entrypoint-allowlist consistency guard
    (finding M-1), writing ONLY to a test path. It must not modify the three docker files.
  - Integration of impl/client-addproduct-keyflow (3f28059), subject to its own review. Read-only
    w.r.t. this branch; no file overlap with docker/**.
  - Read-only analysis anywhere, including apps/** and packages/**.
  - Any lane re-scoping docker/compose.test.yaml / docker/compose.e2e.yaml with deployment authority
    (already tracked in design/port-and-cleanup) — it must NOT add a top-level name: to
    docker/compose.qa.yaml.

PROHIBITED_PARALLEL_WORK:
  - Any WRITE to docker/entrypoint.client.sh, docker/config.js.template or docker/compose.qa.yaml
    without a fresh independent review. These three files are a single atomic unit: editing the
    template without the allowlist reintroduces the literal-placeholder trap (M-1).
  - Integrating this branch BEFORE impl/client-addproduct-keyflow (3f28059). Integrating alone yields a
    correctly-populated config.js that the client never reads — readRuntimeConfigValue and
    operator_attestation.dart are absent from c110aa2 and from main. Client branch first, or together.
  - "Fixing" SC2016 in docker/entrypoint.client.sh by switching the envsubst allowlist to double quotes.
    Verified empirically to emit literal ${...} placeholders even with all variables set (§8).
  - Adding a top-level name: to ANY compose file — it would silently re-home the live QA stack
    (compose project docker).
  - Any mutating Docker or Compose command from any lane without explicit deployment authority:
    make clean, test-env-down, e2e-down, and bare `docker compose … down -v` all resolve to project
    `docker`, the live QA stack, which is up and healthy on a stopgap run-mode override.
    Read-only compose commands are likewise withheld from lanes without that authority.
  - Touching main, pushing, or merging outside the integrator lane until integration order (§9) is
    respected.
```

**Rationale for the verdict.** Every claim in the dispatch's Proof-required list reproduces under my
own execution. Both directions verified, the literal-placeholder trap independently confirmed real and
worse than described, the bare-key contract verified against client source, nothing hardcoded, no
mandatory compose variable, no `name:` added, semantics honestly labelled per M-5, `bash -n` clean,
SC2016 count unchanged and proven to be a false positive whose "fix" would break the change, and scope
exactly the three owned files on a branch that merges cleanly into the advanced `main`. The one real
risk this change leaves behind (M-1, the unguarded template↔allowlist coupling) is a pre-existing
structural hazard that this change correctly documents rather than introduces, and the lane lacked
ownership to fix it. The two documentation staleness items are follow-ups, not gates. I have not
approved the integration **order** — that is a sequencing obligation the integrator must honour, and it
is recorded above under PROHIBITED_PARALLEL_WORK.
