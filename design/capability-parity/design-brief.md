# Design Brief — Capability parity (`design-CAPABILITY-PARITY`)

**Answering:** `docs/engineering/FOLLOW_UPS.md` §6 "Capability parity — the mechanism, not the
instance", and §5 **F-27** (the Dart test harness fails silently, so "green" may mean "truncated").

**Status:** `UNDER_REVIEW` · **Risk level:** `2` (`HUMAN_DECISION_REQUIRED` at Gate D4 — see §9)

---

## 1. Problem statement

Nothing in this repository compares **what a product component needs in order to be built,
validated and run** against **what an environment actually provides**. The two facts are held in
two unrelated places — `pubspec.yaml`/`.fvmrc` on one side, a shell script's `command -v` and a
workflow's `uses:` line on the other — and nothing compares them.

The consequence is not a missing binary. It is that a **capability requirement which was never
measured is indistinguishable from one which was measured and satisfied**, so:

- a validation claim can be recorded as *clean* when the tool that would have produced the evidence
  was absent, and
- the discovery arrives only when an agent happens to try, fails, and reports it somewhere nobody
  asked.

This exact gap produced every false validation line in the current ledger. §6 states it plainly:
*"Every validation line reported for `apps/control_plane` in this ledger's history — 'control plane
gates green', 'analyze clean' — was never substantiated."*

The second, independent instance of the same defect is CI (`.github/workflows/ci.yaml`), and the
ledger names it: **F-15(1)** (`melos bootstrap` crashes because `ci.yaml:15` installs Dart only and
melos's `cli_launcher` re-execs via `flutter`) and **F-15(5)** (a golden test asserts an
`FLUTTER_ROOT` path *shape* that is true under one installer and false under another). Both have
been failing since before the ledger existed. **The defect is at two locations; the mechanism must
be at neither of them — it must be a shared declaration both consume.**

---

## 2. Evidence — measured, cited, not re-derived

Facts established for this lane (per the dispatch brief) and corroborated here:

| # | Fact | Source |
|---|---|---|
| E1 | Host has Flutter 3.44.7 (`/Users/alkebut/fvm/default/bin/flutter`), Dart 3.12.2 | dispatch |
| E2 | **`.fvmrc` pins `3.44.0`. ~~The pin is enforced nowhere.~~ CORRECTED IN REVIEW: it IS enforced, at `pubspec.yaml:112` (`cd apps/control_plane && fvm flutter test`), which resolves through it. The original evidence here was wrong.** | `.fvmrc` (2 lines); `pubspec.yaml:112`; dispatch |
| E3 | `apps/control_plane/pubspec.yaml` declares `sdk: '>=3.12.0 <4.0.0'`, which 3.44.7 satisfies | `apps/control_plane/pubspec.yaml:8` |
| E4 | The QA **client** container needs no Flutter: `docker/Dockerfile.client` is `FROM nginx:alpine` and COPYs pre-built `build/web` | `docker/Dockerfile.client:12,18` |
| E5 | The Flutter **build** stays on the host by deliberate design | `docker/build-client.sh:19-23` (header) |
| E6 | The server container is Dart-only by design and `sed`-deletes `apps/control_plane` from the workspace `pubspec.yaml` | `docker/Dockerfile.server:18` |
| E7 | CI installs **Dart only**; `melos bootstrap` re-execs via `flutter` and crashes | `.github/workflows/ci.yaml:9,15`; `FOLLOW_UPS.md` F-15(1) |
| E8 | `.fvmrc`'s version is **not** the golden-pixel contract; `apps/control_plane/test/tools/golden_render_environment.json` pins `flutterVersion: 3.44.7` and the divergence is deliberate | that file's `_runner_note`; `ci.yaml:118-126` |
| E9 | A declared-environment precondition with a **refusing exit code already exists and works**: `exit 3 = "refused to grade"`, enforced at two points, with **no flag to skip it** | `apps/control_plane/test/tools/golden_render_environment.dart`, `check_render_environment.dart` |
| E10 | A `make qa-up` client-build path **already fails closed** when Flutter is absent | `docker/build-client.sh:229-233` |
| E11 | `melos run test` deliberately **excludes** `control_plane` and `control_plane_server` | root `pubspec.yaml`, `test:` script filters |
| E12 | `apps/control_plane/build/` is **gitignored** (`build/` in `.gitignore`) | `.gitignore:3` |

**What this evidence rules out.** E4, E5, E6 together mean *the stack is not missing a binary*. Any
design whose answer is "install Flutter into the QA image" is answering a question nobody asked and
would break E5's documented reason (Cloudflare WARP / corporate VPN block
`storage.googleapis.com`).

**What it establishes.** E7 is the load-bearing fact for the *implementation* of the check, not
just for the problem: **because the root `pubspec.yaml` `workspace:` list includes
`apps/control_plane`, resolving the Dart workspace requires the Flutter SDK.** A checker written
as `dart run …` inside this workspace could not run on exactly the machine it exists to inspect.

---

## 3. Proposed mechanism

One committed declaration, one dependency-free checker, three consumers.

```
        tool/capabilities.json          ← the declaration (DATA, committed, reviewed)
                    │
                    ▼
        tool/capability-check            ← POSIX sh. No SDK. No network. No Docker.
                    │
     ┌──────────────┼───────────────────────┬──────────────────────────┐
     ▼              ▼                       ▼                          ▼
 make qa-up     ci.yaml (slice 3)   lane gate (slice 1)      --json report
 (slice 1)                          ← requirement 4
```

### 3.1 The declaration — `tool/capabilities.conf`

**Format is FLAT `key=value` lines, not nested JSON. Corrected in review — the earlier draft could
not be read by the tool that is supposed to read it.** In that draft the token `flutter.sdk`
appeared as a *value* inside `requires[]` **and** as an *object key* under `capabilities`. A POSIX
`sh` reader greps both and cannot tell which scope it is in; telling them apart needs brace and
indent tracking across arrays of objects, i.e. a real parser. Getting it wrong in the **expensive**
direction — a false `SATISFIED` — is precisely the failure this entire mechanism exists to
prevent, so the format is chosen so that the expensive mistake is not expressible.

The contract this design imports is greppable **precisely because it is flat**:
`golden_render_environment.json:13-21` is top-level scalars with `_`-prefixed doc keys, no nesting,
no arrays. The draft abandoned exactly the property that made the precedent cheap. Flattening costs
nothing and is strictly more robust; a real JSON parser in `sh` is neither.

Conventions carried over wholesale from that contract:

- keys beginning with `_` are **documentation, never enforcement**;
- a value that cannot be read is an **error**, not a default;
- every entry records its own provenance;
- the tool takes **no argument that can select a more permissive contract**.

Grammar, deliberately trivial to parse without a real parser:

- one record per line, `<key>=<value>`; `#` starts a comment;
- `surface` **opens a scope**, and every capability line after it belongs to that scope *by
  position* — so no capability key ever has to name a scope it could be misread inside;
- `require.<capability>` declares a requirement, `probe.<capability>` defines its **one** probe;
- a capability referenced by `require.` but not defined by `probe.`/`import.`/`assert.` is
  `UNUSABLE` (exit 2), never implicitly satisfied.

```
# ---------------------------------------------------------------- component
component      apps/control_plane
kind           flutter_app
derived_from   apps/control_plane/pubspec.yaml (dependencies.flutter.sdk = flutter)
environments   host, ci, render
# `ci` added in review: without it --env ci never selected flutter.sdk, so slice 3 could not
# surface F-15(1) -- the Dart-without-Flutter CI job -- which is the defect this mechanism
# exists to catch.

# ---------------------------------------------------------------- surface: validation
surface        apps/control_plane.validation
_description   what a review lane is permitted to report as "gates clean". REQUIREMENT 4 LIVES HERE.
require.flutter.sdk     derived   satisfies=pubspec:sdk
require.host.build_web  declared  _why=docker/Dockerfile.client:18 COPYs apps/control_plane/build/web;
                                    docker/build-client.sh:235 runs `flutter build web` on the host
                                    because egress to storage.googleapis.com is blocked. Probed at
                                    runtime, never derived: build/ is gitignored (.gitignore:3), so
                                    the artifact's existence is not a repository fact.
require.fvm             derived   _why=.fvmrc exists and root pubspec.yaml `test:flutter` invokes
                                    `fvm flutter test` (pubspec.yaml:112)

# ---------------------------------------------------------------- surface: golden
surface        apps/control_plane.golden
_description   a SEPARATE surface with a SEPARATE, stricter, already-authorised contract.
                                    Imported whole, not re-described.
import         apps/control_plane/test/tools/golden_render_environment.json
enforce        exactly

# ---------------------------------------------------------------- component
component      apps/server
kind           dart_workspace_member
environments   host, ci

surface        apps/server.integration
require.dart.sdk              derived
require.service.postgres_test declared  requires_env=SERVERPOD_DATABASE_PASSWORD
  _why=no pubspec or Dockerfile records that the server suite needs a live Postgres; only
       Makefile:241 and integration.yaml:36-45,93 do, and neither is machine-readable to a lane.
  _corrected=was SERVERPOD_TEST_DATABASE_PASSWORD. That is a GitHub SECRET NAME, consumed only as
       ${{ secrets.… }} (integration.yaml:35,42,93  (the secret->env mapping is at :35)) and never as an environment variable, so the
       probe could not match on ANY host -- including a correctly configured one -- manufacturing a
       permanently red gate with no owner. Serverpod reads SERVERPOD_DATABASE_PASSWORD
       (Makefile:241, apps/server/config/test.yaml:47).

# ---------------------------------------------------------------- capabilities
# flutter.sdk probes the SDK that RUNS the work, not the one on PATH. Corrected in review.
probe.flutter.sdk            fvm flutter --version --machine
  _why=NOT `command -v flutter`. `melos run test:flutter` is `fvm flutter test`
       (pubspec.yaml:112), which resolves through .fvmrc to 3.44.0. A PATH probe measures 3.44.7
       -- the binary that will NOT run the validation -- and reports drift about the wrong thing
       while the binary that actually runs is never probed.
  _per_surface_version=validation pins .fvmrc 3.44.0 EXACTLY; golden pins 3.44.7 EXACTLY (HD-2)
  _unmeasurable_is=UNKNOWN (exit 4)
probe.dart.sdk               dart --version
probe.fvm                    command -v fvm
probe.host.build_web         test -d apps/control_plane/build/web
  _weaker=satisfied when flutter.sdk is satisfied -- the artifacts are then buildable, not merely
         present
probe.service.postgres_test  printenv SERVERPOD_DATABASE_PASSWORD

# egress.googleapis is a THIRD capability kind, beside probe and import. Declared explicitly in
# review -- leaving the kind set implicit is how a future author adds a fourth kind silently.
assert.egress.googleapis     unreachable
  _why=docker/build-client.sh:19-23 records that Cloudflare WARP and some corporate VPNs block
       storage.googleapis.com, which is WHY `flutter build web` stays on the host. That reasoning
       exists today only as a comment. A comment is not a requirement, and this is the requirement
       most likely to be forgotten by the next person who tries to move the build into a container.
```

**Three capability kinds, declared:** `probe` (run a command, compare its output),
`import` (delegate to an existing contract, see §3.5), `assert` (a property that must hold, with
no command to run). A `require.` naming a fourth kind is `UNUSABLE`, not silently ignored.

### 3.2 The checker — `tool/capability-check`

**Not a Dart script. A POSIX `sh` script with no dependencies beyond `command -v`, `grep` and
`awk`.** This is forced by E7 and it is the single most important implementation constraint in
this brief:

> The tool that detects "Flutter is missing" **cannot itself require Flutter to run.** A
> `dart run` entrypoint inside this workspace cannot start on a Dart-only machine, because the
> root `pubspec.yaml` `workspace:` list includes a Flutter member.

This is the same technique, and the same justification, already used in this repository:
`build-client.sh`'s image-ownership guard states *"Pure text: no Docker, no Compose, no network, no
daemon contact. That is deliberate — it runs before every client build, so it must be free, and it
must be runnable by anyone (CI included) without Docker authority."*

Parsing: the script reads `pubspec.yaml`, `.fvmrc` and `capabilities.json` with `awk`/`grep` for a
**fixed, named set of keys**, exactly as `melos run verify:schema-deviations` greps SQL for
`grep -qF -- "$pattern"`. **If a required key is not found, the check reports `UNKNOWN`, never a
default.** This is the property that matters; the parsing strategy is replaceable and is called out
in §8 as a known cost.

**Interface (no override flags — deliberately).**

```
sh tool/capability-check --component apps/control_plane --surface validation
sh tool/capability-check --env ci
sh tool/capability-check --verify          # re-derive every `derived` entry and compare
```

There is **no `--force`, `--allow-missing`, `--skip` or `--contract` flag.** Copying E9's rule
verbatim: *"there is no argument to this tool that can make a mismatch look like a match."* A
bypass flag on a fail-closed gate is a flag that will be used.

### 3.3 Exit codes — three-valued logic, and the code that stops the false claims

Extends, and does **not** re-use, `golden_render_environment.dart`'s convention. That contract
already defines `exitRefusedToGrade = 3` = *refused because the environment **MISMATCHED***, and
§3.1 sets `"enforce": "exactly"` for the golden surface, so both contracts emit codes in one
report. **An earlier revision of this brief defined its own `3 = could not be measured`, which is
the exact opposite fact, and would have collapsed "I could not measure this" with "I measured this
and it is wrong" — the collision this section exists to prevent.** Corrected in review: the
imported code is left alone and the new codes are numbered clear of it.

| Code | Name | Meaning | Permitted claim |
|---:|---|---|---|
| `0` | `SATISFIED` | every declared requirement of the selected components was **probed and matched** | *"clean"* |
| `1` | `VIOLATED` | at least one requirement is known-absent or mismatched | *"failed: \<names the capability\>"* |
| `2` | `UNUSABLE` | the manifest or a probe could not be read; **nothing was checked** | *"not checked"* |
| `3` | `REFUSED_MISMATCH` | **not emitted by this tool.** Reserved: the value `golden_render_environment.dart` uses for "refused because it mismatched". Held vacant so a reader seeing a `3` in a combined report knows which contract spoke. | — |
| `4` | `UNKNOWN` | at least one requirement exists but **could not be measured** | *"unverified"* |
| `5` | `UNDECLARED` | a component exists in the workspace that the manifest does not cover | *"undeclared: \<path\>"* |

Three properties, each closing a distinct hole:

- **`0` is never returned when nothing was probed.** A checker that measured nothing must not report
  success. This is F-27 applied to capability checking: *"A missing 'All tests passed!' line must be
  treated as inconclusive, never as green."*
  **A selection matching ZERO requirements has no defined answer in this table, and that gap is a
  defect, not a convenience** — it is reachable today via `--env ci`, whose selection is empty under
  §3.1's scoping. **Rule: a zero-requirement selection returns `2` `UNUSABLE`.** Nothing was
  checked, so the tool must not report success, and it must not invent a mismatch either. Reporting
  `0` would be the F-27 defect in new clothing; reporting `1` would name a failure that was never
  observed.
- **`4` is distinct from `1`.** "I could not measure this" and "I measured this and it is absent"
  are different facts and must never collapse into the same log line. E9's rationale, applied.
- **`5` closes requirement 1's own loophole.** A lane that adds a package and reports its gates
  clean cannot simply omit it from the manifest: the workspace scan finds an uncovered component and
  the claim is refused. Per **HD-3** (`.decisions/e07c4a93-1f28-4d6b-8a35-9d20c6e1b7f4.yaml`) this
  is **fatal in CI from the first day of slice 2**, with no advisory phase. Slice 1 does not emit
  `5` at all, because it declares only 1 of 16 workspace members (§4 Q2).

**This is the code that would have stopped the incident.** On the review machine in §6,
`which flutter` → not found ⇒ `flutter.sdk` is `UNKNOWN` ⇒ **exit 4** ⇒ the word "clean" is not
available to that lane.

**Version mismatch is `1`, not a warning.** Per **HD-2**
(`.decisions/b58d0e17-9c46-4f8a-a2d5-3e91b7c40a58.yaml`) both surfaces pin **exactly** —
`validation` at `.fvmrc`'s 3.44.0, `render` at the golden contract's 3.44.7 — so a version that
does not match is a known-mismatch and exits `1`. It is **never** downgraded to a warning. The
earlier `range-satisfies` proposal, and its "absence fatal, drift warned" split, are **withdrawn**.

### 3.4 How a lane consumes it — the requirement-4 gate

Three surfaces, in increasing order of authority:

1. **A file an agent can read.** `--json` on stdout, human table on stderr, so an agent parses
   structure rather than prose:

   ```json
   {"component":"apps/control_plane","surface":"validation","environment":"host",
    "exit":4,"verdict":"UNKNOWN","head":"abc1234",
    "unresolved":[{"capability":"flutter.sdk","reason":"`flutter --version` exited 127",
                   "means":"`flutter analyze` and `flutter test` cannot be run; this revision is UNVERIFIED"}]}
   ```

   `head` is `git rev-parse HEAD` when git is available and `"unknown"` otherwise — an
   *informational* field, never a failure, because the tool must also run outside a checkout.

2. **A gate the lane calls.** A lane reporting a component's validation must record

   ```
   CAPABILITY_PRECHECK: <component> <surface> <exit> <HEAD_SHA>
   ```

   **for every component it names** in its structured result. **Only `0` permits the word
   "clean."** Codes 1/2/4/5 force the corresponding word from the table above *and* force the lane
   to name the unresolved capability.

   **The surface is not optional, and this is a correction from review.** An earlier revision
   recorded a bare `CAPABILITY_PRECHECK: <exit>` — one integer per component. That defeats the
   `--surface` split entirely: a lane could evaluate `--surface validation`, record `0`, and write
   "clean" while the strict golden surface was never evaluated at all, which is precisely the
   "loose check hiding behind a strict one" risk §4 Q2 exists to prevent. On a typical
   developer host `validation` **is** `0` while `render` is not. Recording the surface makes the
   two claims separable in the report; recording the `HEAD_SHA` makes the claim pinned to the
   revision under review rather than to whenever the check happened to run.

   **Per HD-1** (`.decisions/6c1f8a42-7d30-4b15-9e77-2a4f60c1d9b3.yaml`), a lane **may proceed**
   on a non-zero code but must report `UNVERIFIED` and **may never emit `APPROVE_FOR_MERGE`**. A
   hard stop was considered and rejected: it would block all work on the component with no in-lane
   remedy, converting the stall into a deadlock.

3. **A prose obligation**, because requirement 4 is partly a governance change and no executable
   can enforce what an agent writes in a report. The lane instruction gains one line: *a validation
   claim for a component is `UNVERIFIED` unless `CAPABILITY_PRECHECK: <component> <surface> 0
   <HEAD_SHA>` is recorded for that component and surface at the reviewed revision — and a component
   with **no manifest entry at all** is `UNDECLARED` and reported as such.* That last clause closes
   slice 1's R6 window (see §4 Q2) with one sentence: without it, "record it for every component
   you validate" reads as "unlisted components are exempt", which is the exemption the workspace
   scan in slice 2 exists to remove. Until `5` ships, the prose carries it alone.

### 3.5 Where it runs — and specifically, where it does **not** run

**`make qa-up` is the natural gate, and it is also the weakest one.** The honest failure happened at
*review* time, long after any stack was up. Ordering the mechanism around `qa-up` would fix the
symptom's home and leave the cause.

So: `make qa-up` gets the check as a **prerequisite, evaluated before any Docker line**, and the
lane gate plus CI get the weight.

```make
qa-build: | capability-check
qa-up: qa-build
```

**Corrected in review — this is not a cosmetic fix.** The earlier form was `qa-up: capability-check
qa-build`, justified by "Make evaluates prerequisites left to right". That is true **serially and
false under `make -j`**, which `qa-up` supports: with no `.NOTPARALLEL`, `.MAKEFLAGS` or `MAKEFLAGS`
in `Makefile` (verified), the two prerequisites run **concurrently**, so the refusal need not precede
`build-client.sh:235`. An order-only prerequisite (`|`) is the correct construct — it sequences the
check ahead of `qa-build`'s recipe without changing what `qa-up` depends on. This matches the shape
of the existing `check-client-build` guard at `Makefile:129`, so it is also repo-consistent.

`capability-check` is `.PHONY`, runs `./tool/capability-check --env host --surface validation`, and
touches nothing. `build-client.sh:235` **already** fails closed on absent Flutter (E10), so the gate
adds no new failure mode to the client build. The *existing* `qa-up` recipe is unchanged.

**The mechanism never starts the stack and then judges it.** `capability-check` runs no Docker, no
Compose and no daemon call; `qa-up`'s own recipe is not edited.

### 3.6 The delegation boundary — what `sh` may and may not decide

**Corrected in review.** An earlier revision said importing the golden contract required "nothing to
author". That is false, and the design was circular: `golden_render_environment.json` is enforced by
**Dart** — `check_render_environment.dart` imports `golden_render_environment.dart`, and
`ci.yaml:148-155` reaches it via `flutter pub get` + `dart run`. Evaluating it "exactly" therefore
requires the very SDK the contract is about, while AC#4 requires the checker to run **with no Dart and
no Flutter**. The boundary:

| Fact | Who decides it | Why |
|---|---|---|
| `osFamily`, `osMajor`, `architecture` | **`sh`**, from `uname` | machine facts, no SDK needed |
| `flutterVersion` | **`sh`**, from the per-surface probe (§3.1) | `flutter --version --machine` |
| **`maxNoiseFloorRatio`** | **delegated to Dart** — `check_golden_domination.dart` | this is a property of the **goldens**: two renders of the same source must agree. It cannot be computed without rendering. |
| the *verdict* | **delegated to Dart** | `refusedToGrade` / `exitRefusedToGrade` stay Dart's |

**Consequence, stated rather than hidden:** `sh` can decide whether the golden surface's *machine*
facts match, and **must** exit `1` on a mismatch. It **cannot** decide whether the baselines still
reproduce, and must not pretend to. Slice 1 therefore reports the golden surface's machine axes and
**delegates the noise-floor verdict to the existing Dart check** — which is the entire point of
importing that contract instead of re-implementing it. A slice that re-implements `maxNoiseFloorRatio`
in `sh` is rejected on sight.

---

## 4. Design questions answered

### Q1 — Where does the declaration live, and in what format?

`tool/capabilities.json`, at the repository root, outside the Dart workspace, committed and
reviewed like any other source. JSON, adopting E9's conventions (`_`-prefixed documentation keys,
unreadable values are errors, provenance recorded).

The three options weighed:

| Option | Verdict | Reason |
|---|---|---|
| **Derive only**, from `pubspec.yaml` + `.fvmrc` + Dockerfiles | **Rejected** | Cannot express the two requirements that actually broke. No pubspec records that the server suite needs a live Postgres; no pubspec records that goldens need macOS 26 / arm64 / Flutter 3.44.7. Both are hand-recorded today — one in `Makefile:241`, one in `golden_render_environment.json` — and neither is machine-readable to a lane. Derivation-only would report `SATISFIED` for a component whose real requirements were never in scope. |
| **Declare only**, hand-written | **Rejected** | Duplicates `pubspec.yaml` and rots on the first dependency change. The whole defect class here is *declaration drifting from reality*; a second hand-maintained copy of the same facts adds a third place to forget. |
| **Hybrid: derive what is derivable, declare what is not — and make derivation checkable** | **Recommended** | One file; every entry carries `source: derived \| declared \| imported`; `--verify` re-derives the `derived` ones and **fails** when the source no longer says what it said. The hybrid's teeth are the re-derivation, not the hybrid itself. |

**Rejected sub-variant — "derive on the fly, no manifest at all."** It is simpler and it was tried:
`golden_render_environment.json` exists *because* the rendering environment cannot be derived from
anything. Nothing in the tree encodes which machine rasterised 3.44.7's pixels.

### Q2 — What is a "component"?

**A component is a repository path that owns at least one validation surface** — that is, something
that can produce a pass/fail claim about the code under review.

`kind` is derived from `pubspec.yaml`: a member with `dependencies.flutter.sdk = flutter` is a
`flutter_app`; a member with `resolution: workspace` and no Flutter SDK dependency is a
`dart_workspace_member`.

**Component identity is the path, deliberately.** A reviewer's subject is already a path — the
ledger's own vocabulary is "against `apps/control_plane`", "`control_plane` gates". Using the same
string as the manifest key means the lane gate compares two things it already holds, with no
mapping table and no alias table to drift.

`apps/control_plane` is **one component with two surfaces**, and the split matters:

- **`validation`** — "may a lane say the gates are clean?" Binds `flutter.sdk`, `fvm`, `host.build_web`.
- **`golden`** — "may golden verdicts be graded?" Imports `golden_render_environment.json` and
  enforces it **exactly**.

These are different claims with different evidence. Folding them into one "capability check" would
either weaken the golden contract to the loose one, or make the loose gate unpassable. A lane may
legitimately say "analyze clean, goldens unverified"; it may not say "gates clean" when neither was
measured. The surface model is what makes that expressible.

**Mapping to "the revision under review":** `sh tool/capability-check --component <path> --surface
<surface>` produces a report carrying `HEAD_SHA`. A lane's claim names the same component, the same
surface and the same `HEAD_SHA`. Checkability reduces to string comparison of three fields a lane
already has.

### Q3 — Derive vs. declare — what genuinely cannot be derived

| Capability | Verdict | Why |
|---|---|---|
| `flutter.sdk` (presence) | **derived** | `apps/control_plane/pubspec.yaml` `dependencies.flutter.sdk: flutter` |
| `dart.sdk` (range) | **derived** | root `pubspec.yaml` `environment.sdk: '>=3.12.0 <4.0.0'` |
| `fvm` | **derived** | `.fvmrc` exists **and** `pubspec.yaml`'s `test:flutter` invokes `fvm flutter test` |
| `melos` | **derived** | root `pubspec.yaml` `dev_dependencies` |
| `host.build_web` | **probed, never derived** | `build/` is gitignored (E12). The artifact's existence is a **runtime** fact, not a repository fact; deriving it from the tree would be wrong by construction. |
| `host.render_environment` | **imported** | It already exists, is already Human-Decision-authorised (`3e9dfb75`), and already refuses with exit 3. Duplicating it would create two contracts for one fact. |
| `service.postgres_test` | **declared** | Needs a live Postgres **and** a secret. No pubspec, no Dockerfile records it; `Makefile:241` does, in prose inside a shell recipe. |
| `egress.googleapis` | **declared** | It exists today **only as a comment** (`build-client.sh:19-23`). A comment is not a requirement. This is the requirement most likely to be violated, because the violating act — "let's move the Flutter build into the container, it's cleaner" — feels like an improvement. |

**The cost of each error, which sets the whole design's asymmetry:**

- **A false `SATISFIED`** produces a false validation claim. Proven cost: every line in §6 of the
  ledger. It is the expensive error.
- **A false `UNKNOWN`** produces a refusal to validate. Cost: a blocked lane with an actionable
  message naming the capability, and a human who installs one SDK. It is *recoverable*.
- **A false `VIOLATED`** produces a red gate for a satisfied requirement. Cost: the "permanently
  red required gate with no owner" failure E9's own header explicitly refuses to build.

So: **UNKNOWN is a failure, and the tool's job is to avoid manufacturing UNKNOWNs** (hence
`--verify`, hence importing the existing contract rather than re-deriving it). The asymmetry is
deliberate and should be stated in the implementation's own header, because a future editor
optimising for "fewer false failures" will otherwise "fix" it into a false-satisfied gate — which is
how this defect started.

### Q4 — Fail-closed semantics: what happens when a requirement is UNKNOWN?

**This is the crux, and the answer is: UNKNOWN fails.** It gets its own verdict and its own exit
code (`3`), because today's failure is precisely that an unknown was silently treated as satisfied.

An `UNKNOWN` arises when — and only when — one of these is true:

1. the probe command cannot be run (`flutter` absent ⇒ exit 127; `command -v` empty);
2. the probe runs but produces nothing parseable (`flutter --version` without `--machine`);
3. the manifest is missing the key the probe needs;
4. a requirement has no `probe` at all (declared but not yet measurable) — **this must be `UNKNOWN`,
   not `SATISFIED`, on day one**;
5. the selected component has no manifest entry ⇒ `UNDECLARED` (4).

Case 4 is the one that will be argued about, so it is stated as a rule rather than left to
judgment: **a requirement that cannot be measured is `UNKNOWN`.** There is no "assume the best"
branch, and no severity flag that downgrades it to a warning. If a capability is declared, it must
be probeable before the declaration is merged.

### Q5 — The pin-drift question: `.fvmrc` says 3.44.0, the host has 3.44.7

**Recommendation: **SUPERSEDED BY HD-2** — both surfaces now pin EXACTLY and version drift is
FATAL. (The original `range-satisfies` recommendation rested on E2, which review found false.)

Original, withdrawn: `range-satisfies` for build and validation; exact-match only where a contract
already demands it. Specifically: `.fvmrc`'s exact version is a `preferredVersion`, reported and
warned but never fatal. `golden_render_environment.json`'s exact version stays fatal, because it is
a different fact about a different thing.**

Justification:

1. **Nothing in the repository makes `3.44.0` semantically special.** The declared constraint is
   `sdk: '>=3.12.0 <4.0.0'` (E3). 3.44.7 satisfies it. A gate that fails on 3.44.7 would be
   enforcing a distinction the codebase does not make.
2. **An exact-pin gate here would be *permanently* red for most developers.** FVM's `default` is a
   shared, mutable pointer; every machine that runs `fvm use default` moves off the pin the moment
   anyone upgrades. E9's own header names this exact failure and refuses to build it:
   *"Enforcing a value that drifts every few days would make this gate refuse to grade on every
   image rollout — a permanently red required gate with no owner, which is the same failure in the
   other direction."*
3. **The thing that genuinely requires an exact pin already has one, and it is a different axis.**
   Golden pixel data requires macOS 26 / arm64 / **3.44.7** (E8), it is already enforced at two
   points with exit 3, and it already **deliberately diverges from `.fvmrc`** under Human Decision
   `3e9dfb75`. Making `.fvmrc` exact would create a second, contradictory exact pin over the same
   toolchain and a contradiction between two contracts in one repository.
4. **The asymmetry that decides it.** Absence of Flutter **breaks a gate**. A different patch
   version of Flutter **does not break anything the repo declares**. Failing on absence and warning
   on version matches the actual consequence of each error.

**Drift is reported, never silent:** `flutter.sdk: SATISFIED (observed 3.44.7; .fvmrc prefers
3.44.0 — DRIFT, not fatal)`. A drift that is only ever a warning is invisible within a week, so it
is printed on **every** run to stderr and included in the `--json` payload as a `drift` array.

**State the falsifiable test, so this recommendation can be checked rather than believed:** if a
future change makes `.fvmrc` exact, the change must first demonstrate that some artifact produced by
`3.44.7` differs from `3.44.0` in a way the repository cares about. The golden corpus is the one
candidate, and it is already pinned separately.

**What actually happens on this host, stated plainly so nobody has to run it to find out:** for
`apps/control_plane` / surface `validation` on the `host` environment, `flutter.sdk` is
`SATISFIED (3.44.7, drift from `.fvmrc` 3.44.0)`, `fvm` and `host.build_web` are probeable, so the
result is **exit 0**. For surface `golden` the imported contract is evaluated exactly and its own
rules decide. **Two different checks; a green `validation` is not a licence to grade goldens**, and
that sentence belongs in the tool's own `--help`.

**Escalated, not decided** — see §9, HD-2.

### Q6 — Migration: the smallest correct first version

The smallest version that is *correct* rather than merely *small* must already demonstrate: the
declaration exists, derivation works, UNKNOWN fails closed, the lane gate exists, and the tool runs
on a machine that has no Flutter (because that is the machine it is for).

**Slice 1 — MUST. The mechanism, on one component.**
- `tool/capabilities.json` covering `apps/control_plane` / `validation` / `host` **only**
  (`flutter.sdk`, `fvm`, `host.build_web`).
- `tool/capability-check` — the `sh` script, codes 0/1/2/3, `--json`, `--verify`.
  **Codes 0–3 only. Code 4 (`UNDECLARED`) is slice 2**, because with one component declared, an
  `UNDECLARED` guard would fire on every other workspace member immediately and the first run would
  be a wall of red nobody reads.
- `make capability-check` + the `qa-up: capability-check qa-build` prerequisite.
- The lane obligation, and it must be added to **BOTH** paths for each of the three skills
  (`aef-design-workflow`, `aef-independent-review`, `aef-implementation-workflow`):
  `.agents/skills/<skill>/SKILL.md` **and** `.opencode/skill/<skill>/SKILL.md`.
  **Corrected in review — this correction is load-bearing, not cosmetic.** `.agents/` is canonical
  and the rest are generated adapters, but `AGENTS.md:47-52` records that the generator
  (`cli/tool/generate_platform_adapters.dart`) and its `--check` drift test are **framework-repository
  tooling and are NOT instantiated in this product repo**. Editing only the canonical paths would
  therefore change nothing and, more dangerously, **fail nothing** — requirement 4 would be inert in
  the exact runtime where the false claims happened, with no signal. opencode resolves
  `.opencode/skill/`, so that mirror is the one actually loaded here.
  *"record `CAPABILITY_PRECHECK: <exit>` for every component whose validation you report."*
- **Acceptance proof:** on a host with Flutter removed from `PATH`, the check for
  `apps/control_plane` exits **3**, the JSON names `flutter.sdk`, and a lane holding that exit code
  cannot emit the word "clean".

**Slice 2 — the rest of the workspace, and `UNDECLARED`.**
- Extend the manifest to `apps/server` (adding `service.postgres_test`) and all `packages/*`.
- Add exit code **4**, with the workspace scan that produces it.
- Only *then* add a derivation **drift** check (`--verify`) as a separate CI job — because `--verify`
  firing on a manifest that is not yet complete produces more noise than signal.

**Slice 3 — CI consumption, and the two F-15 instances.**
- New `capability-precheck` job in `ci.yaml`: checkout + `sh tool/capability-check --env ci`, **with
  no SDK installed** — so it fails honestly and visibly, which is already better than today's
  `melos bootstrap` crash at `:15` arriving as an unexplained CI failure.
- **Install Flutter in the CI jobs whose declared capabilities need it** (fixes F-15(1)), reading
  the version from the manifest rather than from a hand-copied `uses:` line.
- Import `golden_render_environment.json` (already written; nothing to author).
- Replace the `FLUTTER_ROOT` path-shape assertion at
  `apps/control_plane/test/tools/golden_render_environment_test.dart:394` with a check of the
  **probed version**, so the assertion holds under FVM *and* under `subosito/flutter-action`
  (**F-15(5)**). Note: this assertion today asserts `observed.flutterVersion ==
  flutterRoot.split('/').last`, which is false on an FVM host where `FLUTTER_ROOT` ends in
  `/default`.

**Slice 4 — DEFERRED, must not be built yet.** See §7.

---

## 7. Non-goals — what must NOT be built

1. **No provisioning.** The mechanism **detects**; it never installs, downloads, or mutates an
   environment. A checker that fixes its own problem reports `SATISFIED` for a machine it
   silently changed, and the next lane finds the drift with no evidence. "Ensure the environment
   has the right tools" is an installer, and it is a different artifact with a different owner.
2. **No `tool/`-vs-`tooling/` collision.** CI already references `../tooling/workers`, which has
   never existed (F-15(4)). This design creates `tool/`, which matches the existing
   `apps/server/tool/` convention, and must **not** create `tooling/`.
3. **No changes to `docker/Dockerfile.client` or `docker/Dockerfile.server`.** They are correct for
   their jobs (E4, E6). Moving the Flutter build into a container is forbidden by a declared
   capability, not by this brief's opinion.
4. **No rewriting of `golden_render_environment.json`.** It is imported whole. Its exit codes and
   its two enforcement points are precedent, not a starting point.
5. **No network at check time.** It must run behind WARP/VPN — the same constraint that put the
   Flutter build on the host. Every capability is probed **locally**.
6. **Not a code checker.** This validates the *environment*, never the *diff*. It must not grow a
   linter, a test runner or an analyzer; those are `melos` and `flutter`'s jobs.
7. **No production/staging environments in slice 1.** Not because they are unwanted, but because
   their requirement set is not yet known, and declaring a guess would manufacture `SATISFIED`.
8. **No auto-generation of manifest entries.** `--suggest` is deferred: an entry nobody reviewed is
   an entry nobody is responsible for, and this mechanism's entire value is that a human committed
   to the requirement.
9. **No change to `docs/engineering/FOLLOW_UPS.md`.** §6 stays open until this ships **and** is
   demonstrated to have refused a false claim.

---

## 8. Risks — what could go wrong

| # | Risk | Likelihood | Consequence | Mitigation |
|---|---|---|---|---|
| R1 | **The gate becomes a checkbox.** A lane learns to run `capability-check`, record `0`, and move on — or worse, learns which surfaces nobody checks. | **High** | The mechanism reports its own success while the class of defect recurs. | The lane obligation names the *component* and *HEAD*, not a pass. E9's precedent: the tool must have no skip flag. Countermeasures in slice 2 (`UNDECLARED` forces new components in) and slice 3 (CI consumes it, so it is exercised without a human asking). |
| R2 | **`grep`/`awk` parsing of YAML is brittle.** A key moves, a `pubspec.yaml` reformats, a nested `sdk:` key is mistaken for `environment.sdk`. | Medium | A `derived` capability silently derives the wrong value — a **false `SATISFIED`**, the expensive error. | Parsing is restricted to a named key list; a key that cannot be located yields `UNKNOWN`, never a default. `--verify` re-derives. Stated in §9 as the main migration trigger to a real parser. |
| R3 | **Scope explosion.** "Capabilities" invites `postgres_version`, `chrome`, `xcode`, `node`, … | **High** | Unreviewable manifest, slow check, and the mechanism loses the one property that makes it trustworthy: that a human committed to every line. | Slice 1 caps the manifest at **three** capabilities for **one** component. Every added capability must come with a *named* consumer. `capabilities.json` is reviewed like code. |
| R4 | **The `UNDECLARED` guard (code 4) blocks all work** until every workspace member is declared. | Medium | A wall of red on day one of slice 2. | Deliberately deferred to slice 2, after the manifest is complete. Introduced as its own reviewable slice, never folded into slice 1. |
| R5 | ~~**`.fvmrc` range-satisfies is read as "pins are now decorative."**~~ **CLOSED BY HD-2** — no asymmetry remains to be misread. Both surfaces are exact and drift is fatal, so there is no longer a weaker axis to mistake for a licence. | — | — | — |
| R6 | **The check is bypassed by not declaring the component** — a lane reviews `apps/control_plane` while the manifest covers `apps/server`. | Medium | Requirement 4 silently does not apply. | This is R1/R4's real form and it is exactly why exit code **4** exists. Slice 1's honest limitation is recorded here rather than hidden. |
| R7 | **The tool cannot run in some lane's context** (no `sh`, no `awk`, unusual sandbox). | Low | The check is skipped and the lane reports unverified — the safe outcome. | Acceptable by design: UNKNOWN is the failure mode, and R7 degrades to `UNKNOWN`, not to a false clean. |
| R8 | **`.gitignore`d artifacts.** `build/` is ignored, so `host.build_web` cannot be derived (E12). | Certain | A derivation bug if implemented naively. | Designed around: `host.build_web` is a runtime probe with an explicit `_weaker` rule (satisfied when `flutter.sdk` is, because the artifacts are then *buildable*). |
| R9 | **Governance risk of "unverified" becoming normal.** Once a lane can say `UNKNOWN` and proceed, the honest answer may become the cheap answer. | Medium | Review throughput recovers, but coverage does not. | `UNKNOWN` is recorded in the structured result, so it is **visible and countable** — which is the thing §6 says has been missing. Slice 3's CI job makes the durable fix independent of lane discipline. |

---

## 9. Human decisions — RESOLVED, and what they changed

All three were escalated at Gate D1 and have since been **answered by the operator**. They are no
longer open. This section records the ruling and what it forced to change in the artifact, because a
decision that does not visibly alter the design was not really made.

| id | file | ruling | what it changed here |
|---|---|---|---|
| **HD-1** | `.decisions/6c1f8a42-7d30-4b15-9e77-2a4f60c1d9b3.yaml` | A capability that cannot be verified is reported **`UNVERIFIED`**; the lane **may proceed** but **may never emit `APPROVE_FOR_MERGE`**. Hard-stop rejected — it converts the stall into a deadlock. | §3.4.2 and §3.4.3 now state the proceed-but-never-approve rule explicitly. |
| **HD-2** | `.decisions/b58d0e17-9c46-4f8a-a2d5-3e91b7c40a58.yaml` | **Both surfaces pin EXACTLY.** `validation` at `.fvmrc`'s **3.44.0**, `render` at the golden contract's **3.44.7**. **Version drift is FATAL, not warned.** | **Supersedes this brief's own HD-2 recommendation outright.** §3.3 now makes mismatch exit `1`; §4 Q5's recommendation is withdrawn; R5 is closed because no asymmetry remains to misread. §3.1 records the per-surface versions. |
| **HD-3** | `.decisions/e07c4a93-1f28-4d6b-8a35-9d20c6e1b7f4.yaml` | Exit code `UNDECLARED` is **fatal in CI from the first day of slice 2**. No advisory phase. | §3.3's `UNDECLARED` row states the ruling and notes slice 1 does not emit it (it declares 1 of 16 members). |

**HD-2's premise correction, recorded because it nearly cost an irreversible change.** This brief's
range-satisfies recommendation argued that "nothing makes 3.44.0 special". That premise was false:
`.fvmrc` **is** the repository-wide developer pin and `pubspec.yaml:112` resolves through it. Worse,
`FOLLOW_UPS.md` F-33 had recorded the FVM/golden divergence as a "latent conflict" — it is not a
conflict at all. `golden_render_environment.json._authority` cites Human Decision
`3e9dfb75-7bdf-4a8c-89dd-c76779a65371` (RESOLVED/OPTION_C) and its `_runner_note` states the
divergence is **deliberate and policed by the precondition**; running goldens under 3.44.0 makes
`check_golden_domination.dart` exit `refusedToGrade`, which **is the design working**.

An operator was asked which version was authoritative, on F-33's framing, and selected "re-render the
goldens to 3.44.0". Executing that would have **overturned a resolved human decision** and changed
every golden baseline for no gain. It was caught only because the answer prompted a check of the
contract itself before execution. F-33 is now retracted, and the one real defect underneath it — a
stale comment at `pubspec.yaml` claiming the FVM pin protects golden pixels — is fixed at `1c97cee`.

**Lesson, recorded rather than absorbed:** a design artifact, a review finding, and a ledger entry all
repeated the same false claim before anyone read the artifact it described. Each hop looked
reasonable. **Read the artifact.**

---

## 10. Alternatives considered and rejected

| # | Alternative | Rejected because |
|---|---|---|
| A1 | **Install Flutter into the QA image.** | Answers a question nobody asked. E4/E5/E6: the client is `nginx:alpine`, the server is Dart-only **by design**, and `build-client.sh:19-23` documents that `storage.googleapis.com` is blocked by WARP/corporate VPN — the reason the build is on the host. This would break a documented, deliberate design to fix a problem that is not a missing binary. |
| A2 | **A CI-only fix** — install Flutter in `ci.yaml`, done. | Fixes F-15(1) and leaves requirement 4 untouched. The incident was on a *review host*, not in CI. A CI-only fix addresses one of the two locations §6 names and none of the four requirements. |
| A3 | **A lane instruction only** — "verify the toolchain before claiming clean." | Requirements 1–3 are unmet and nothing detects drift. This is §6's own complaint about prose, reproduced as a fix. It also cannot distinguish "I checked" from "I believed." |
| A4 | **Reuse `golden_render_environment.json` alone**, widening it to all components. | It is **pixel-rendering** evidence, scoped to one component and one machine, with axes (osMajor, architecture) that are meaningless for a Postgres-backed server suite. Widening it conflates two facts and would force the loose build requirements through an exact-rendering contract — the failure E9's header warns about in the other direction. **Import it; do not widen it.** |
| A5 | **Derive capabilities fully automatically, no committed file.** | Cannot express `service.postgres_test` or the render environment (§4 Q1). Also unreviewable — a requirement nobody committed to is a requirement nobody owns, which is the defect being fixed. |
| A6 | **A `dart run` tool inside the workspace.** | Cannot run on a Dart-only machine, because the root `pubspec.yaml` `workspace:` includes `apps/control_plane` (E7/F-15(1)). **The tool that detects a missing Flutter must not need Flutter.** |
| A7 | **A `--force` / `--allow-missing` escape hatch.** | A bypass flag on a fail-closed gate is a flag that will be used, and its use is indistinguishable in the log from the gate passing. Explicitly forbidden, on E9's precedent. |
| A8 | **Make `make qa-up` the primary gate.** | `qa-up` runs after the stack is up and long after review; §6's false claims were made by lanes that never ran it. It is a convenience surface, and treating it as the primary would optimise the wrong moment. |
| A9 | **Exact-pin `.fvmrc` at 3.44.0.** | Enforces a distinction the codebase does not make (E3), contradicts the already-authorised golden pin (E8), and produces a permanently red gate for most developers — the failure E9's header names and refuses. |
| A10 | **A file an agent reads, with no executable.** | Satisfies requirement 1 and nothing else. Two agents reading the same declaration can still disagree about whether a probe succeeded; that disagreement is precisely the defect. |
| A11 | **Provision-and-verify** (`fvm install` if missing, then verify). | Turns `SATISFIED` into a statement about a machine the tool silently mutated, with no evidence and no way to detect the next drift. Detection and provisioning must be separate artifacts with separate owners. |

---

## 11. Traceability

| Ledger requirement | Where designed | Covered by | Gaps |
|---|---|---|---|
| **REQ-1** declared capability set per component, as data, derived from the codebase | §3.1 `tool/capabilities.json`; §4 Q1–Q3 | Slice 1 | `UNDECLARED` enforcement (code 4) is slice 2; production/staging environments deferred (NG-7) |
| **REQ-2** check that the environment satisfies it, failing closed, naming the missing capability; `make qa-up` the gate; must not start-then-judge | §3.2 checker; §3.3 codes 1/2/3; §3.5 `qa-up: capability-check qa-build` (prerequisite, before any Docker line) | Slice 1 | Deliberately *not* the primary gate — see §3.5 |
| **REQ-3** the same set consumed by CI | §3 diagram; §6 slice 3 | **Slice 3, not slice 1** | F-15(1) (install Flutter in CI) lands with it; until then CI's mismatch becomes *visible* rather than silent |
| **REQ-4** a lane gate that refuses "clean" when a capability it needs is absent | §3.3 code 3; §3.4 the three lane surfaces | Slice 1 (surfaces 1–2), full closure in slice 2 with code 4 | The executable half is enforced; the prose half (what an agent writes in a report) is an instruction, not a guarantee — stated, not glossed |
| **F-27** harness fails silently ⇒ "green" may mean "truncated" | §3.3 "`0` is never returned when nothing was probed"; §4 Q4 | Slice 1 | F-27's *own* instance (the `dart test` truncation) is a separate defect; this design imports the lesson, it does not fix that harness |

**Deliberately out of scope** (so a reviewer does not read them as oversights): F-15(2)–(8), the
`control_plane` create-defect correctness defect, F-01/F-02 (RESOLVED), and the missing-binary
framing itself.

---

## 12. Acceptance criteria for this design

1. `sh tool/capability-check --component apps/control_plane --surface validation --json` exits
   **0** on this host and prints the `.fvmrc` drift as a non-fatal `drift` entry.
2. With `flutter` removed from `PATH`, the same command exits **3**, names `flutter.sdk`, and the
   JSON `verdict` is `UNKNOWN`.
3. A lane holding exit 3 cannot emit the string `clean` in a validation claim without the report
   naming the unresolved capability — verified by reading the lane instruction text, not by running
   a lane.
4. The tool runs with no Dart, no Flutter, no Docker, no Compose, no network.
5. `make qa-up` is unchanged except for its prerequisite line, and the check runs **before** any
   `docker` command in that target.
6. `--verify` detects a deliberately corrupted `derived` entry and fails closed.
7. No `pubspec.yaml`, `Dockerfile`, `.github/workflows/*.yaml` or `docs/**` file is modified by this
   design.

---

## 13. Provenance

- **Repository:** `/Users/alkebut/air/shipit-platform`
- **Branch:** `main`
- **BASE_SHA / HEAD_SHA:** `64e92a0cfc86f9c0bf3b77294dce7c77f077bda4`
- **Working tree:** modified only by this design artifact (`design/capability-parity/`) and
  pre-existing untracked files not created by this lane. **No commit was made** — none was requested.
- **Commands run:** read-only (`git`, `ls`, `cat`, `sed`, `grep`, `uuidgen`, `mkdir`). **No Docker,
  no Compose, no `psql`.** No `git stash`, `git checkout .` or `git add -A`.
