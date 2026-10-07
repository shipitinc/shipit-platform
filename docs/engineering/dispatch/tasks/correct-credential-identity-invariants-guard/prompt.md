# Subtask Prompt — correct-credential-identity-invariants-guard (focused correction)

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only. Rendered from
`.agents/skills/aef-orchestrator/templates/subtask-prompt.md`.

```yaml
MANAGER: orchestrator-main
TASK_ID: correct-credential-identity-invariants-guard
TASK_TYPE: correct
FEATURE: Add Product rebuild — credential identity invariants, pre-merge correction
AREA: the schema-bootstrap guard's DDL parity check; the store contract's durable-evidence column list
WORKTREE: /private/tmp/shipit-credential-identity
BRANCH: fix/credential-identity-invariants
BASE_SHA: 0bf2fa0     (branch tip == base; ALL reviewed work is UNCOMMITTED — see §Provenance)
OWNED_PATHS:
  - apps/server/tool/verify_schema_bootstrap.sh
  - apps/server/tool/**/verify_schema_bootstrap*.{sh,bats}    # negative-control self-test, see §Scope
  - packages/product_registry/lib/src/store/product_registry_store.dart   (comment block only, :82-84)
READ_ONLY_PATHS:
  - apps/server/lib/src/persistence/postgres_product_registry_store.dart
  - apps/server/lib/src/database/**, apps/server/migrations/**
  - packages/platform_contracts/**, packages/product_registry/lib/src/engine/**
  - packages/product_registry/lib/src/store/in_memory_product_registry_store.dart
  - packages/product_registry/test/**
  - apps/server/test/**
  - docs/**, .decisions/**
PROHIBITED_PATHS:
  - .github/workflows/**          (see §Scope — do NOT wire the self-test into CI)
  - docker/**, docker-compose*.yaml
  - .decisions/**
  - docs/engineering/WORK_STATE.md, docs/engineering/dispatch/LANES.md
  - docs/engineering/dispatch/tasks/**
  - ANY change to postgres_product_registry_store.dart, in_memory_product_registry_store.dart,
    product_registry_engine.dart, or any *.dart behaviour  (you are correcting a GUARD and a COMMENT)
ACCEPTANCE_CRITERIA: |
  The one open MEDIUM closed per the reviewer's §2.5 design (one list, fails closed, four negative
  controls), LOW-1's comment corrected to name all seven enforced columns, and the tree committed so
  it has a pinnable SHA.
VALIDATION_COMMANDS:
  - cd /private/tmp/shipit-credential-identity && dart format --output=none --set-exit-if-changed .
  - cd /private/tmp/shipit-credential-identity && dart analyze
  - cd /private/tmp/shipit-credential-identity/packages/product_registry && dart test
  - /private/tmp/shipit-credential-identity/apps/server/tool/verify_schema_bootstrap.sh
  - <negative-control self-test>   # all four controls must exit 1
ROUTING_CLASS: PRECISION
```

## Isolation pre-flight — RUN THIS FIRST

```bash
cd /private/tmp/shipit-credential-identity
git branch --show-current    # must equal fix/credential-identity-invariants
git rev-parse HEAD           # must equal 0bf2fa0
git status --porcelain       # must show the 8 modified files, nothing else
git stash list               # must be empty or contain only unrelated entries
```

**⚠ PROVENANCE — this is the whole reason for the correction.** The reviewed change has **NO COMMIT**.
Branch tip == base == `0bf2fa0`, and all 8 modified files (+1271/-90) are uncommitted working-tree
modifications. A prior integrator **refused** to merge a sibling change for precisely this reason
(`INTEGRATION_BLOCKED` — "the tree the review approved had no pinnable SHA"), costing a full extra
cycle. **Your commit is part of the deliverable.**

**Preserve the reviewed work exactly.** Do not `reset`, do not `stash` it away, do not rewrite it. You
are adding a guard fix and a comment on top of a reviewed tree, then committing the result as a
pinnable revision. **Make your commit(s) additive and clearly separated** so a reviewer can see the
reviewed work unchanged underneath. `aef-correction-loop` requires corrections to **preserve reviewed
provenance**.

## Your reading

1. `docs/engineering/dispatch/tasks/review-credential-identity-invariants/report.md` — the baseline review
   (returned `APPROVE_WITH_NON_BLOCKING_FOLLOWUP`)
2. `docs/engineering/dispatch/tasks/review-credential-identity-invariants-rereview/report.md` — **your
   finding set.** §§ 2.1–2.5, 4, 6, 10 are the parts you must act on.

The re-review is unusually rigorous. Read § 2.4 and § 2.5 in full before writing anything.

## Finding 1 — the MEDIUM (`verify_schema_bootstrap.sh`)

**The gap.** The new full-DDL parity check normalises away `IF NOT EXISTS`, which **forgives the one
divergence that breaks the chain path.** Proven: deleting `IF NOT EXISTS` from `20261006150645000`'s
credential index leaves the guard at exit 0; deleting it from the bootstrap asset also leaves exit 0.
Both files carry it today, so **nothing is broken now — this is a gap in the guard, not a live defect.**
And no test anywhere replays the migration chain onto a bootstrapped database, so **the guard is the
only possible detector.**

**⚠ The naive fix is a trap, and the reviewer proved it fails OPEN.** The obvious fix adds a
per-object expectation table. Two defects:

1. **It violates the principle this script was written to encode.** At lines 306-312 the script says
   *"The object NAMES are taken from `required_objects` above, not written out again here… nothing has
   to be remembered in two places."* A second list reintroduces exactly that failure.
2. **Done naively it creates a NEW fail-open hole in check 4.** Check 4 derives names with
   `sed 's/^[^:]*://'` — one field stripped. If the expectation is added as a third colon-delimited
   field and that sed is not updated in lockstep, the name becomes
   `product_credential_active_repository_unique:both`, the regex stops matching, `offenders` is empty,
   and **check 4 silently passes.** The reviewer proved it: planting the index into a `definition.sql`
   exits 1 unmodified, and **exit 0 after the ripple**.

**Required fix — the reviewer's §2.5 design:**

1. Carry the expectation **in the same `required_objects` entry**, no second list:
   ```
   "index:design_revision_approved_unique_per_work_item:asset-only"
   "index:product_credential_active_repository_unique:both"
   ```
2. **A third field that is absent or unrecognised must `exit 2`** ("the guard itself could not run") —
   never fall back to the forgiving behaviour. The script already uses `exit 2` for exactly this class
   of "cannot judge" condition at `:221-228`.
3. Perform **two** comparisons per index object: clause-stripped DDL (whitespace-collapse only, current
   behaviour, which is correct) **and** clause presence compared against the declared expectation.
4. Fix check 4's name derivation **in the same commit** — `cut -d: -f2` is better than updating the sed,
   because the entry's arity then cannot leak into the regex.

**Four negative controls, all required** (the proposal asked for one; one is not enough):
- drop the clause from `20261006150645000` → `exit 1`
- drop it from the bootstrap asset → `exit 1`
- add it to `20260920232118956` where `asset-only` is expected → `exit 1`
- plant an index name in a `definition.sql` → `exit 1` (**proves check 4 survived the arity change**)

**⚠ Record, do not silently bless, this:** codifying `asset-only` for
`design_revision_approved_unique_per_work_item` **enshrines an asymmetry whose correctness was never
established.** `20260920232118956` is older and its comment gives no idempotence rationale, while
`20261006150645000` explicitly reasons about this hazard. If the credential index's clause is mandatory
for chain-replay-onto-bootstrapped safety, the design-revision one is **plausibly missing it too** — a
pre-existing latent defect at `0bf2fa0`, not this change's regression, and **out of scope to fix here.**
The value of making the expectation explicit is that it forces a human to look. **Record it as a
finding in your report; do not quietly resolve it.**

## Finding 2 — LOW-1 (one-line comment, `product_registry_store.dart:82-84`)

The durable-evidence contract names **six** columns; **both tiers enforce seven**. The reviewer escalated
this to a **three-way ladder**:

| Layer | Columns | Missing |
|---|---|---|
| Store contract prose (`:82-84`) | **6** | `hostKeyFingerprint`, `lastFailureReason` |
| Both tiers actually enforce | **7** | `lastFailureReason` |
| Committed spec rev5 requires | **8** | — |

**Fix the comment to name all seven enforced columns**, so the prose does not need editing again when
`D-6` lands. **Comment only — no behaviour change.**

## Finding 3 — NEW MEDIUM: do NOT fix it here, but record it

`lastFailureReason` is unguarded on **both** tiers while the committed spec requires eight columns.
Severity: **a guard gap, NOT a live defect** — `copyWith` uses `lastFailureReason ?? this.lastFailureReason`
(`packages/platform_contracts/lib/src/types/repository_credential.dart:162`), so a null argument
preserves the value, and the only engine writer `recordCredentialCheck`
(`product_registry_engine.dart:1074`) sets it and never clears it. **No engine path can erase it today.**

**The reviewer is explicit: do NOT fold `D-6` into this change.** It carries its own eight-column
requirement, its own `SC-17`, and two of its own tests — `T-J` (the legitimate setters must still
succeed: `revokeCredential`, `confirmHostKey`, `recordCredentialCheck`'s success and failure paths) and
`T-K`. **`T-J` is the trap** — the obvious implementation ("forbid the columns") turns `T-J` red.
Folding it in would expand scope past what was reviewed and **invalidate the review.**

**Required disposition:** record it as a tracked follow-up — *the `D-6` eighth column is latent,
unreachable via any engine path, and must land before migration `20261006150645000` reaches a deployed
database* — and leave it out of your diff. **Do not touch it. Do not expand scope.**

## Scope note — the self-test harness

**No negative-control harness exists today** — the script is referenced only by CI as a step, by a
decision file, and by `schema_bootstrap.dart`. Adding four negative controls means **introducing a
fixture-based self-test for a bash script.** That is the honest cost of this fix.

`.github/workflows/**` is **PROHIBITED for you** — wiring the self-test into CI is outside this change's
scope and needs its own review. **Create the self-test and run it locally. Leave CI wiring as a named
follow-up in your report.** Say plainly in your report that the controls exist but are not yet enforced
on every CI run, so nobody mistakes "I added four controls" for "CI now enforces them."

## Gates you must run and report exactly

Run each. `NOT_RUN` is acceptable; a fabricated pass is not.

- `dart format --output=none --set-exit-if-changed .` — baseline: 631 files, 0 changed
- `dart analyze` — baseline: exit 0, 2 pre-existing infos in `packages/workflow_engine` (untouched by
  this change)
- `cd packages/product_registry && dart test` — baseline: **+148**
- `apps/server/tool/verify_schema_bootstrap.sh` — baseline: **18 OK, 0 FAIL**, exit 0
- `SERVERPOD_DATABASE_PASSWORD=… make test-integration` — baseline: **+171 -1**, sole failure the
  **pre-existing** `dogfood_shipit_postgres_test.dart` assertion in a file this change does not touch
- your negative-control self-test — all four controls must exit 1

**Baseline means the change introduced no regression.** A count differing from baseline is a finding to
investigate and report, not something to absorb quietly.

**Integration flakiness was disclosed by the reviewer:** one run returned `+125 -3` with two extra
`setUpAll` failures that did not reproduce. If you see it, **disclose it.** Do not report a clean run
that hides an unexplained failure.

## HARD RULES — the Docker rule is not negotiable

- **Run no Docker or Compose command that can change state.** No `down`, `stop`, `rm`, `prune`,
  `volume rm`, `compose up`, `pull`, `build`, `--rmi`. **And not read-only-looking ones** —
  `docker compose ps`, `logs`, `config`, `docker info` are **NOT granted.** Every exception becomes the
  next precedent.
- **NEVER** run `make clean`, `make test-env-down`, `make e2e-down`, or any bare
  `docker compose … down -v` without `-p <project>`. **These resolve to compose project `docker`, the
  LIVE QA STACK.** `make clean` is a disarmed stub that removes nothing. **This repository has already
  lost its QA database irrecoverably** (volumes `docker_postgres_data_qa`, `docker_triage_repo_qa`,
  `docker_triage_workspaces_qa`; no dump existed) to a review lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`. **Do not test this rule.**
- **`make test-integration` is the ONLY sanctioned way to get a real database.** It creates a disposable
  Postgres under compose project `shipit_integration_<pid>` and removes it on success, failure and
  interrupt alike. Use it for the integration gate.
- Your self-test must use **temporary fixtures**, never the repository's real SQL assets — a self-test
  that mutates `schema_bootstrap.sql` or a migration would destroy the very evidence it verifies.
  **Prove this**: your test must leave the repository byte-identical apart from your intended diff.
- If you need a mutating Docker operation `make test-integration` does not provide, **that is a blocker
  to report, not a command to run.**
- If you have already breached any of the above, **disclose it immediately, naming the exact commands.**

## Other hard rules

- Write only inside `OWNED_PATHS`. Your only *behavioural-adjacent* edit is a **comment** in
  `product_registry_store.dart`.
- **Do not approve your own work.** You cannot self-certify this merge.
- **PERSIST YOUR FULL REPORT TO DISK** before returning, conforming to
  `.agents/skills/aef-orchestrator/templates/subtask-report.md`, with the `RESULT:` block verbatim from
  `.agents/agents/correction-implementer.md`. **Two reports were lost to a relay in this work item**;
  do not be the third.
- **Commit is REQUIRED and is part of your deliverable.** One commit for the reviewed tree if it is
  uncommitted, then your correction commits on top — or a single clean commit if the Manager's
  bookkeeping prefers it. **State exactly what you committed and why, and give the resulting SHA.**
  No history rewrite, no force-push, no amend of anything reachable from a ref.
- Every result carries exact provenance: worktree, branch, `HEAD` before and after.

## Report format

```
RESULT: CORRECTION_COMPLETE | CORRECTION_BLOCKED
```

Include `READY_FOR_FOCUSED_REVIEW: YES | NO`, the committed SHA(s), every gate's exact result, and the
three tracked items you were told to record rather than absorb:
1. rev5 is `DESIGN_REVIEW_CHANGES_REQUIRED` (B-R5-1 + 4 MEDIUM + 3 LOW) — its review report is itself
   **uncommitted**; a design verdict with no provenance is this work item's lost-evidence problem
   recurring in a third place.
2. `D-6`'s eighth column (`lastFailureReason`), latent and unreachable, required before migration
   `20261006150645000` reaches a deployed database.
3. The `asset-only` asymmetry caveat from Finding 1.