# Subtask Prompt — review-credential-identity-invariants-rereview (focused re-review before merge)

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: review-credential-identity-invariants-rereview
TASK_TYPE: review            # focused re-review, read-only
FEATURE: Add Product rebuild — credential identity invariants, merge candidate
AREA: fix/credential-identity-invariants, currently UNCOMMITTED at base 0bf2fa0
WORKTREE: read-only inspection of /private/tmp/shipit-credential-identity
BASE_SHA: 0bf2fa0   (branch tip == base; ALL work is uncommitted in the working tree)
HEAD_SHA: 0bf2fa0   (no commit exists for this change — see "the provenance problem" below)
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/review-credential-identity-invariants-rereview/**   (your report)
READ_ONLY_PATHS: everything else — you read, you never edit
PROHIBITED_PATHS:
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, docs/**  (all of it, except your own report directory)
ACCEPTANCE_CRITERIA: |
  A focused re-review covering ONLY (a) the one open MEDIUM — the full-DDL parity check's IF NOT EXISTS
  normalisation — and (b) regression risk introduced since the original review, on a tree now 5 commits
  behind main. Plus a verdict on merge-readiness.
VALIDATION_COMMANDS:
  - cd /private/tmp/shipit-credential-identity && git rev-parse --short HEAD   # 0bf2fa0
  - cd /private/tmp/shipit-credential-identity && git diff --stat
ROUTING_CLASS: PRECISION
```

## Why this review exists — the merge is the cheapest real improvement available

`fix/credential-identity-invariants` **closed D-4, D-18 and D-5** and was returned
**`APPROVE_WITH_NON_BLOCKING_FOLLOWUP`** — no blockers, no HIGH, 1 MEDIUM, 4 LOW.

**Until it lands, a revoked credential can be resurrected on `main`.** That resurrection path is
**live in production-shaped code right now**, and it is independent of every other item in this work
item — no design revision, no decision, no other lane gates it. **That is why it goes first in the
queue behind the unblocked design work.** D-18 is the gap: a credential whose status is `revoked` can be
driven back to `verified` and put back into service.

## THE PROVENANCE PROBLEM — read this before forming a view

**There is no commit.** Branch `fix/credential-identity-invariants` is at `0bf2fa0` and **all 8 changed
files are uncommitted working-tree modifications**:

```
 M apps/server/lib/src/persistence/postgres_product_registry_store.dart     (+213)
 M apps/server/test/integration/product_credential_immutability_postgres_test.dart  (+483)
 M apps/server/tool/schema_bootstrap.sql                                     (+32)
 M apps/server/tool/verify_schema_bootstrap.sh                               (+85)
 M packages/product_registry/lib/src/engine/product_registry_engine.dart      (+35)
 M packages/product_registry/lib/src/store/in_memory_product_registry_store.dart (+93)
 M packages/product_registry/lib/src/store/product_registry_store.dart        (+60)
 M packages/product_registry/test/credential_test.dart                        (+360)
 8 files changed, 1271 insertions(+), 90 deletions(-)
```

**The reviewed tree has no pinnable SHA.** This exact situation already bit this work item once: an
integrator **refused** to merge `fix/credential-store-integrity` for precisely this reason (`INTEGRATION_BLOCKED`
— "a second implementer pass had mutated the tree the review approved and it had no pinnable SHA"), after
which a commit was created and a fresh review obtained. **Do not repeat that cycle. If you approve, say
plainly that a commit must exist before integration, and name the exact HEAD you reviewed.**

**The branch is 5 commits behind `main` (`289f1d3`).** Establish whether any of those five touch your
eight files or anything they depend on. Report the answer either way — a re-review that ignores drift
is not a re-review.

## Scope — this is FOCUSED, not a full review

The original review at `docs/engineering/dispatch/tasks/review-credential-identity-invariants/report.md`
already passed the implementation. **Read it first; it is your baseline.** Do not re-review what it
already approved. Cover:

1. **The one open MEDIUM — `verify_schema_bootstrap.sh:267`.** The reviewer's words:

   > The `IF NOT EXISTS` normalisation in the new full-DDL comparison **forgives the one divergence
   > in that clause that breaks the chain path.** **Proven:** deleting `IF NOT EXISTS` from
   > `20261006150645000`'s credential index leaves the guard at exit 0; deleting it from the bootstrap
   > asset also leaves exit 0.
   >
   > That clause is **not free to differ for this object**: `20261006150645000`'s own comment states both
   > copies carry `IF NOT EXISTS` *"because a database that was created fresh and has since had the
   > bootstrap applied already carries this index, and replaying this migration onto it must be a no-op
   > rather than an error."* Dropping it makes that migration fail on exactly the bootstrapped database it
   > was written to survive. Both files carry it today, so **nothing is broken now — this is a gap in the
   > guard, not a live defect.**
   >
   > **Fix:** keep whitespace collapse as the only blanket normalisation and make the idempotence clause an
   > explicit per-object expectation — assert **both** homes carry it for
   > `product_credential_active_repository_unique`, and the **asset-only** clause for
   > `design_revision_approved_unique_per_work_item`. Add a negative control that drops the clause from
   > `20261006150645000` and asserts exit 1.

   **Re-verify the finding, then judge whether the proposed fix is correct** — do not rubber-stamp it.
   If you find a better or additional fix, give it.

2. **Regression risk** introduced by the five commits of drift, scoped to these eight files and their
   dependencies.

3. **The four LOWs.** Comment/doc only per the original review. Confirm that is still true, and say
   whether any has become material in the meantime. The most substantive of them: the
   durable-evidence contract at `product_registry_store.dart:82-84` names **six** columns while **both
   tiers enforce seven** (`hostKeyFingerprint` is guarded but undocumented).

4. **Merge-readiness verdict** given items 1–3, and the minimum steps required before integration.

## Gate evidence you must weigh

The original review recorded: `make test-integration` → `+171 -1`, sole failure the **pre-existing**
`dogfood_shipit_postgres_test.dart` assertion, re-proven on pristine `0bf2fa0` at `+164 -1` — so the
delta is exactly the new tests. The original reviewer also **independently overrode the implementer's
self-assessment in the implementer's favour**: "6 of 6 red", not the 5 of 6 reported. That is the
pattern to keep.

**Verify the gates yourself to the extent a lane may.** `make test-integration` is the **only sanctioned
way** to obtain a real database: it creates a disposable Postgres under compose project
`shipit_integration_<pid>` and removes it on success, failure and interrupt alike. **It is the sole
exemption to the Docker rule below.**

## HARD RULES — the Docker rule is not negotiable

- **Run no Docker or Compose command that can change state.** No `down`, `stop`, `rm`, `prune`,
  `volume rm`, `compose up`, `pull`, `build`, `--rmi`. **Not even a read-only-looking one** —
  `docker compose ps`, `logs`, `config` and `docker info` are **NOT granted either**, because every
  exception is a precedent for the next exception.
- **NEVER** run `make clean`, `make test-env-down`, `make e2e-down`, or any bare
  `docker compose … down -v` without an explicit `-p <project>`. **These resolve to compose project
  `docker`, which is the live QA stack.** `make clean` is a disarmed stub that removes nothing; treat it
  as harmless but do not lean on it. **This repository has already lost its QA database irrecoverably**
  (volumes `docker_postgres_data_qa`, `docker_triage_repo_qa`, `docker_triage_workspaces_qa`; no dump
  existed) to a review lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`. **Do not test this rule.**
- Reading a compose file as **text** is the supported way to learn what a stack does. Do not start it.
- If you need a mutating Docker operation and `make test-integration` does not cover it, **that is a
  blocker to report, not a command to run.**
- If you have already breached this, **disclose it immediately in your report, naming the exact
  commands.** The disclosure is what bounds the damage and is never held back to improve a report.

## Other hard rules

- **READ-ONLY.** Edit nothing except your own report directory. This includes
  `apps/server/tool/verify_schema_bootstrap.sh` — you are reviewing the MEDIUM, **not** fixing it.
- **You are independent.** The producer never approves its own work and neither do you.
- **PERSIST YOUR FULL REPORT TO DISK** at
  `docs/engineering/dispatch/tasks/review-credential-identity-invariants-rereview/report.md` before
  returning. **Two reports were lost to a relay in this work item and receiving lanes had to work from
  paraphrase.** Do not be the third.
- **Search the domain's own vocabulary, not the requester's phrasing.** Three times in this work item a
  lane grepped one identifier and concluded an artifact was absent: `deployKey` vs **`credential`** (the
  domain's word is `credential` — `RepositoryCredential`, `CredentialStatus`, `HostKeyStatus`, the
  `product_credential` table, 4 store methods, 6 engine methods and a 16-test suite all exist and were
  wrongly declared non-existent); `docs/engineering/adr/` vs **`docs/adr/`** (ADR 0018 exists, 21
  product ADRs); a centralised label vs a literal grep. Follow citations; enumerate with `glob`, not
  `ls` on a guessed path. **Verify a path exists before trusting an UNCHANGED result** — one lane's
  `git diff --quiet` passed because the path did not exist.
- **State explicitly what you did NOT review.**

## Provenance context

Nine Human Decisions are **RESOLVED** and none gates this review: `9417f8bf` (A3 external secret
manager), `898b07d0` (split identity), `ae1c1f79` (refusal creates nothing), `27ea6536`, `7b1bc8b7`,
`79e860e2`, `4d2c6b81`, `b869ec24`, `876c6b97`. **Do not re-open any of them.**

`design-revision-3.md` — the specification D-4/D-18/D-5 implement — **is uncommitted and unapproved.**
Both the original engineering reviewer and the implementer flagged this, and **no code lane can
discharge it.** That is a Manager/ADR-lane dependency, not yours to fix, but **you must state plainly
whether it blocks the merge of the resurrection fix**, given that fix is independently security-relevant
and the resurrection path is live today. Take a position.

## Report format

Report per `.agents/skills/aef-orchestrator/templates/subtask-report.md` with the `RESULT:` block
verbatim from `.agents/agents/focused-reviewer.md`:

```
RESULT: APPROVE_CORRECTIONS | DO_NOT_APPROVE_CORRECTIONS
```

Also state `READY_FOR_MERGE: YES | NO` and the minimum steps integration requires. Carry exact
provenance: the tree you reviewed, and the fact that no commit exists for it.