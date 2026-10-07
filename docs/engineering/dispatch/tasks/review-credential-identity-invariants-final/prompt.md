# Subtask Prompt — review-credential-identity-invariants-final (focused re-review, now pinnable)

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: review-credential-identity-invariants-final
TASK_TYPE: review            # focused re-review, read-only
FEATURE: Add Product rebuild — credential identity invariants, final pre-merge review
WORKTREE: /private/tmp/shipit-credential-identity
BRANCH: fix/credential-identity-invariants
BASE_SHA: 3f3f4f4      # the reviewed tree, now committed — see §Provenance, this is NEW
HEAD_SHA: a4c211c      # the correction on top
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/review-credential-identity-invariants-final/**   (your report)
READ_ONLY_PATHS: everything else — you read, you never edit
PROHIBITED_PATHS:
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, docs/**   (all of it, except your own report directory)
ACCEPTANCE_CRITERIA: |
  A focused re-review of the correction commit a4c211c against your own prior findings, plus a
  decision on T4 (the non-deterministic concurrency test), plus a merge verdict.
VALIDATION_COMMANDS:
  - cd /private/tmp/shipit-credential-identity && git rev-parse --short HEAD    # a4c211c
  - cd /private/tmp/shipit-credential-identity && git show --stat 3f3f4f4
  - cd /private/tmp/shipit-credential-identity && git show --stat a4c211c
ROUTING_CLASS: PRECISION
```

## §Provenance — the tree finally has a SHA, and that is itself something to verify

The tree you previously reviewed (`0bf2fa0` + a working-tree diff, **no commit**) has been committed:

```
a4c211c  fix(schema-guard): declare each index's IF NOT EXISTS expectation; fail closed
3f3f4f4  fix(credential-registry): refuse credential re-pointing and re-mint, both tiers
0bf2fa0  (base)
```

**⚠ VERIFY `3f3f4f4` ACTUALLY REPRODUCES THE TREE YOU REVIEWED.** The correction lane reports it could
**not find the reviewed state on disk** — it says the reviewed 361-line guard "survives nowhere" across
all 25 `/private/tmp/shipit-*` worktrees, and that it therefore **reconstructed** the reviewed state by
**exact inverse edits** before committing it as `3f3f4f4`.

That is an unusual and consequential operation. **Do not take it on trust.** Check `3f3f4f4` against the
oracles the prior review recorded:

- `git show --stat 3f3f4f4` must be **8 files, 1271 insertions, 90 deletions**
- the reviewed `verify_schema_bootstrap.sh` must be **361 lines**, with the pre-correction
  `sed 's/^[^:]*://'` at `:267`, the `exit 2` idiom at `:221-228`, and the two policy comments at
  `:306-312` and `:313-315` saying the thing you quoted in your §2.4
- guard **18 `OK:` / 0 `FAIL:`**

**If any oracle misses, say so immediately and treat `3f3f4f4` as unverified provenance.** A
"reviewed work, unchanged" commit that is not byte-identical is precisely the failure mode this work
item has been fighting for sessions. Check it yourself rather than relying on the oracles alone.

Then review `a4c211c` — **3 files, +515/−16**: `verify_schema_bootstrap.sh` (+209),
`verify_schema_bootstrap_negative_controls.sh` (new, +300), `product_registry_store.dart` (+22, comment).

## START WITH T4 — it is the open question and it is a determinism defect

The correction lane reported, and did **not** absorb:

> Integration is not deterministically green. Four runs: `+171 −1`, `+170 −2`, `+170 −2`, `+171 −1`.
> The extra failure is **the reviewed work's own D-4 concurrency test** — `_GatedStore` releases the
> barrier *after* both `SELECT`s complete, so which refusal wins is timing-dependent.

Its claim that this is **not** its own regression: its diff touches no `lib/`, `test/`, `migrations/`
or `schema_bootstrap.sql`, has **0 non-comment Dart lines**, and it did not reproduce at the same SHA.

**Judge this claim on the evidence, not the reassurance.** Three things to determine:

1. **Is the flakiness real and pre-existing?** Run the integration gate several times yourself. **A
   flaky test in a suite that gates a security fix is not a cosmetic issue** — decide whether it blocks.
2. **Is the diagnosis right?** Read `_GatedStore` in the test file and the two `SELECT`s it gates. Is the
   barrier genuinely released after both reads, making the winner timing-dependent? Or is there a real
   ordering bug being masked?
3. **What is the correct disposition?** Options are not mutually exclusive: accept as a known flake
   with a tracked issue, fix the test's determinism in a separate change, or fix the underlying
   behaviour. **Recommend one and say why.** If it blocks the merge, say that plainly — the Manager needs
   a real answer, not a comfortable one.

## Your prior findings — all three must be dispositioned

Read your own prior report first:
`docs/engineering/dispatch/tasks/review-credential-identity-invariants-rereview/report.md`

1. **The MEDIUM** (§2.5 design). Verify independently, do not take the lane's word:
   - the expectation is carried **inside the same `required_objects` entry** — no second list
   - **absent/unrecognised expectation exits 2**, never falling back to forgiving behaviour
   - **two** comparisons per index object (clause-stripped parity **and** clause presence)
   - check 4's name derivation fixed **in the same commit** (`cut -d: -f2`, not a stale sed)
   - **all four** negative controls present, and each genuinely exits 1 when its condition is induced

   The lane reports proving it can fail open: reverting only check 4's sed in a throwaway copy makes
   `plant-index-in-definition` **exit 0 silently**; deleting only the expectation comparison makes all
   three clause controls exit 0 and drops the baseline to 18 `OK:`. **Reproduce these two if you can.**

2. **LOW-1** — `product_registry_store.dart:82-84` must name **all seven** enforced columns. The lane
   states it deliberately did **not** name `lastFailureReason`, on the reasoning that naming it would
   overstate what the tiers do. **Judge that judgement** — you said "name all seven"; the eighth column
   is a tracked `D-6` item. Is this comment now correct about what the code does?

3. **The new MEDIUM** (`lastFailureReason` unguarded on both tiers, latent) — correctly recorded as a
   tracked follow-up and **not** folded in. Confirm it is genuinely absent from the diff.

Also verify the **new self-test** is safe: it must checksum every file it reads before and after and
**fail the run** if any differs, so it can never mutate the real SQL assets. The lane reports 12 checks.
**Verify the containment claim yourself** — a self-test that writes to the repository would destroy the
evidence it verifies.

## Gates — run them yourself

The lane reports: format 631 files / 0 changed ✅ · analyze exit 0 (2 pre-existing infos in the untouched
`workflow_engine`) ✅ · `product_registry` **+148** ✅ · schema guard **20 OK** (baseline was 18; the +2
is exactly one new assertion per index object, nothing removed) ✅ · self-test **12/0** ✅ ·
`make test-integration` **+171 −1 / +170 −2** (flaky, see T4).

**Verify the guard went 18 → 20 by ADDITION, never by removing coverage.** A "fix" that lowers the OK
count while raising the assertion count would be a regression wearing a pass.

## HARD RULES — the Docker rule is not negotiable

- **Run no Docker or Compose command that can change state.** No `down`, `stop`, `rm`, `prune`,
  `volume rm`, `compose up`, `pull`, `build`, `--rmi`. **And not read-only-looking ones** —
  `docker compose ps`, `logs`, `config`, `docker info` are **NOT granted.** Every exception becomes the
  next precedent.
- **NEVER** run `make clean`, `make test-env-down`, `make e2e-down`, or any bare
  `docker compose … down -v` without `-p <project>`. **These resolve to compose project `docker` = the
  LIVE QA STACK.** `make clean` is a disarmed stub that removes nothing. **This repository has already
  lost its QA database irrecoverably** (volumes `docker_postgres_data_qa`, `docker_triage_repo_qa`,
  `docker_triage_workspaces_qa`; no dump existed) to a review lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`. **Do not test this rule.**
- **`make test-integration` is the ONLY sanctioned way to get a real database** — disposable, project
  `shipit_integration_<pid>`, self-cleaning on success, failure and interrupt alike.
- Your own scratch work must use **temporary fixtures**, never the repository's real SQL assets.
- If you need a mutating Docker operation `make test-integration` does not provide, **that is a blocker
  to report, not a command to run.**
- If you have already breached this, **disclose it immediately, naming the exact commands.** The
  disclosure is what bounds the damage and is never held back to improve a report.

## Other hard rules

- **READ-ONLY.** Edit nothing except your own report directory — including `verify_schema_bootstrap.sh`
  and the self-test. You are reviewing; the lanes are done writing.
- **You are independent.** The producer never approves its own work and neither do you. The prior
  correction lane explicitly declined to approve itself.
- **PERSIST YOUR FULL REPORT TO DISK** at
  `docs/engineering/dispatch/tasks/review-credential-identity-invariants-final/report.md` before
  returning. **Two reports were lost to a relay in this work item** and receiving lanes had to work from
  paraphrase. Do not be the third.
- **Search the domain's own vocabulary, not the requester's phrasing** — `deployKey` vs `credential` and
  `docs/engineering/adr/` vs `docs/adr/` both produced false "artifact absent" conclusions here. Verify
  a path exists before trusting an UNCHANGED result.
- **State explicitly what you did NOT review.**

## Carried forward, not yours to resolve

- **`design-revision-5.md` is `DESIGN_REVIEW_CHANGES_REQUIRED`** (B-R5-1 + 4 MEDIUM + 3 LOW), and **no
  finding touches § R.9**; that review lists `G-11` ("D-4 / D-5 / D-6, both tiers, eight columns") as
  `SAFE_PARALLEL_WORK` at the exact `main` tip. Your prior §5 concluded the design lane authorises this
  merge — the one-line gap was "eight columns cleared" vs "seven in the tree", which is finding 3.
- **The keys rev-5 review report is itself uncommitted.** A design verdict with no provenance is this
  work item's lost-evidence problem recurring in a third place. Manager-owned; note it, do not fix it.
- **Nine Human Decisions are RESOLVED** (`9417f8bf`, `898b07d0`, `ae1c1f79`, `27ea6536`, `7b1bc8b7`,
  `79e860e2`, `4d2c6b81`, `b869ec24`, `876c6b97`). **Do not re-open any of them.**
- The negative controls are **not in CI** — `.github/workflows/**` was out of the correction lane's
  scope. Twelve green controls locally is **not a gate.** Say so in your verdict if it matters.

## Report format

Report per `.agents/skills/aef-orchestrator/templates/subtask-report.md` with the `RESULT:` block
verbatim from `.agents/agents/focused-reviewer.md`:

```
RESULT: APPROVE_CORRECTIONS | DO_NOT_APPROVE_CORRECTIONS
```

Also state `READY_FOR_MERGE: YES | NO` and the minimum remaining steps.