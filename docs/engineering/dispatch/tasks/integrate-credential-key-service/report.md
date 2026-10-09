# Integration — credential-key-service

```
RESULT: MERGE_APPROVED

APPROVED_HEAD:
  7d1b1b8abdf5cbfbb7b48dc9682baf3bfb99090c
  (approved by review-correct-key-service-residue — APPROVE_CORRECTIONS,
   READY_FOR_MERGE: YES, BLOCKERS: none, REGRESSIONS: none)

CURRENT_MAIN:
  c110aa243f41d0bedf7dcc6de72b7462173461f6   (merge commit)
  parents: 99123b1aa3971c3a21b32ea82032a8beb7ca973a  7d1b1b8abdf5cbfbb7b48dc9682baf3bfb99090c
  origin/main = c110aa243f41d0bedf7dcc6de72b7462173461f6  (verified via git ls-remote)
  main...origin/main = 0 0
  merge commit SHA: c110aa243f41d0bedf7dcc6de72b7462173461f6
  resulting main SHA: c110aa243f41d0bedf7dcc6de72b7462173461f6

GATES:
  format=   PASS — "Formatted 655 files (0 changed) in 10.59 seconds." exit 0
            (655 files (0 changed) — matches the reviewer's measurement at 7d1b1b8 exactly)
  analyze=  PASS — "No issues found!" exit 0
            (see "GATE 2 required a re-resolution" below; first run was RED on a
             stale local package resolution, NOT on merged content)
  tests=    RED (known, approved, pre-existing) — "+191 -1", exit 2
            Sole failure: test/integration/dogfood_shipit_postgres_test.dart
            "S-1 DOGFOOD — Product: ShipIt (Postgres, read-only) register ShipIt,
             discover pinned HEAD read-only, propose baseline, survive restart"
            Cause, verbatim from the run:
              TimeoutException after 0:00:30.000000: Test timed out after 30 seconds.
              PathNotFoundException: Directory listing failed, path =
                '.../shipit-head-ngJ8KY/apps/server/lib/src/triage/'
              package:product_registry/src/discovery/read_only_repository_reader.dart 90:25  _walk
              ... :81:5  ReadOnlyRepositoryReader.inspect
              test/integration/dogfood_shipit_postgres_test.dart 145:32
            This is exactly N-1 as characterized by the reviewer: the `git archive`
            snapshot walk does not finish inside the 30 s `dart test` default, and
            teardown removes the snapshot directory while the walk is still running.
            Pre-existing, lives in packages/** which this change does not touch.
            NOT a worktree quirk (the reviewer disproved that) and NOT a regression.
  build=    N/A — no build gate defined for this repository.

PROVENANCE:
  branch merged ............ impl/credential-key-service
  branch tip ............... 7d1b1b8abdf5cbfbb7b48dc9682baf3bfb99090c (unchanged, intact)
  base (merge-base) ........ 8725b65deaab565f7c3b93d644e73f1ec07a6f39
  main before merge ....... 99123b1aa3971c3a21b32ea82032a8beb7ca973a
  approved HEAD ........... 7d1b1b8abdf5cbfbb7b48dc9682baf3bfb99090c
  merge commit ............. c110aa243f41d0bedf7dcc6de72b7462173461f6
  resulting main ........... c110aa243f41d0bedf7dcc6de72b7462173461f6
  origin/main .............. c110aa243f41d0bedf7dcc6de72b7462173461f6
  main...origin/main ....... 0 0
  push ..................... 99123b1..c110aa2  main -> main  (fast-forward push of a
                             merge commit; no force, no history rewrite)
  lane worktree ............ /private/tmp/shipit-impl-keys PRESERVED, branch PRESERVED
```

READY_FOR_INTEGRATION: YES — merged and pushed. Strategy used was the authorized
`git merge --no-ff`, which was the correct call and is now proven, not just argued:
all five reviewed SHAs survive byte-for-byte as the second-parent ancestry, so both
the independent review and the focused re-review keep their cited evidence with no
re-review. No human authority is required to complete integration — it is done.
Deployment authority remains human-reserved and is NOT claimed by this lane.

---

## 1. Preconditions — all four verified before the merge

**1. main is 99123b1 and 0 0.** PASS.
`main` = `99123b1aa3971c3a21b32ea82032a8beb7ca973a`, `git rev-list --left-right --count
main...origin/main` = `0 0`. main had not advanced again. Proceeding was correct.

**2. Changed-file containment.** PASS — 22 files, all inside the corrected allow-list.
Full list from `git diff --name-only 8725b65 7d1b1b8` (22 files):

  apps/server/lib/src/credentials/credential_key_service.dart
  apps/server/lib/src/credentials/gcp_secret_manager_secret_provider.dart
  apps/server/lib/src/credentials/local_file_secret_provider.dart
  apps/server/lib/src/credentials/posix_file_permissions.dart
  apps/server/lib/src/credentials/repository_access_verifier.dart
  apps/server/lib/src/credentials/secret_material.dart
  apps/server/lib/src/credentials/secret_provider.dart
  apps/server/lib/src/credentials/secret_provider_resolver.dart
  apps/server/lib/src/credentials/secretless_error.dart
  apps/server/lib/src/credentials/ssh_keypair.dart
  apps/server/lib/src/credentials/ssh_remote.dart
  apps/server/lib/src/endpoints/credential_endpoints.dart
  apps/server/lib/src/generated/endpoints.dart
  apps/server/lib/src/generated/protocol.yaml
  apps/server/pubspec.yaml
  apps/server/test/credential_keypair_test.dart
  apps/server/test/integration/credential_key_service_postgres_test.dart
  apps/server/test/integration/test_tools/serverpod_test_tools.dart
  apps/server/test/repository_access_verifier_test.dart
  apps/server/test/secret_provider_test.dart
  apps/server/test/secretless_error_test.dart
  pubspec.lock

- 22/22 match an allowed glob. Forbidden-path grep over
  `apps/server/migrations/`, `apps/server/tool/`, `apps/control_plane/`,
  `packages/`, `docker/`, `.github/`, `docs/adr/` returned **0 matches**.
- Both corrections confirmed: `apps/server/lib/src/generated/endpoints.dart` and
  `protocol.yaml` ARE present in the diff and are required, reviewed artifacts — good,
  they were wrongly on the must-not list before. `apps/server/pubspec.lock` does not
  exist on disk and the **root** `pubspec.lock` is what changed, as stated (L-5).

**3. Five commits, strictly linear, single-parent, no amends.** PASS (re-confirmed).
`git rev-list --count 8725b65..7d1b1b8` = 5; `git rev-list --merges --count` = 0;
no row in `git rev-list --parents` had other than 2 fields; `8725b65` is an ancestor:

  7d1b1b8  parent da68b5f  fix(server): bound the host-key fingerprint and make the docs match the code
  da68b5f  parent 315e9ca  fix(server): close the custody-leak class the independent review found
  315e9ca  parent 4ac16a3  test(server): prove the private half never leaves the process
  4ac16a3  parent 428f4fa  feat(server): CredentialEndpoints to generate a deploy key and verify access
  428f4fa  parent 8725b65  feat(server): real ed25519 deploy-key generation with external custody

**4. `apps/server/migrations/**` byte-identical to base.** PASS (the load-bearing half).

  base 8725b65 : apps/server/migrations = 3fcbd960147a28ff6eac4d839d227fbe72542fb4
  head 7d1b1b8 : apps/server/migrations = 3fcbd960147a28ff6eac4d839d227fbe72542fb4
  main 99123b1 : apps/server/migrations = 3fcbd960147a28ff6eac4d839d227fbe72542fb4
  merged main  : apps/server/migrations = 3fcbd960147a28ff6eac4d839d227fbe72542fb4

Identical on all four revisions. And `lib/src/generated/**` does differ
(`fa2abeea…` -> `acd44503…`) — required, reviewed, and **not** a defect.

## 2. The 99123b1 question — main's advance affirms the approval

`99123b1` is docs-only (`git diff --name-only 8725b65 99123b1` = 10 files, all under
`docs/engineering/dispatch/`). I read `LANES.md:1159-1173` at that revision: it carries
**N-1 HIGH — do NOT persist the false claim about `dogfood`** and records that "the
implementation lane reported `dogfood_shipit_postgres_test.dart` as a
linked-worktree artifact … **The reviewer disproved it**", that the measured cause is the
43 098 ms `ReadOnlyRepositoryReader.inspect()` walk against the 30 s default, and that
"`make test-integration` is therefore genuinely red: `+191 -1`, and base is `+170 -2`".
So the commit that advanced main records the refutation and **forbids** the false
PROJECT_FACT. It affirms the approval rather than undermining it. The docs blobs of the
two review reports are carried through the merge unchanged
(`review-correct-key-service-residue/report.md` = `f77dc10d…`).

## 3. Merge mechanics

`git merge-tree --write-tree --name-only 99123b1 7d1b1b8` exited 0 with a single tree
record and no conflict entries — the merge is provably clean before touching the
worktree. The two change sets are disjoint:

  files changed on main since base (8725b65..99123b1)  = 10   (all docs)
  files changed on impl since base (8725b65..7d1b1b8)  = 22  (all code/tests/lock)
  intersection ....................................... = 0    (empty)

  8725b65 -> merged main = 32 files = the disjoint union of the two sets, and exactly
  22 of those 32 are non-docs.

Result: `c110aa2`, parents `99123b1 7d1b1b8`, "Merge made by the 'ort' strategy".
I then verified, per path, that the merged tree is byte-identical to the reviewed tree
for all 22 impl paths — `identical=22 diverged=0`. **The merge introduced zero new code
content**; it is a pure union of two disjoint sets, which is why no re-review is needed.

Push: `99123b1..c110aa2  main -> main`. Post-push `main...origin/main` = `0 0`, and
`git ls-remote origin refs/heads/main` = `c110aa243f41d0bedf7dcc6de72b7462173461f6`.
No force-push; no history rewritten; all five reviewed SHAs remain ancestors of main.

## 4. Gate 2 required a re-resolution — and it was NOT a merge defect

The first `dart analyze apps/server` on merged main was **RED**, exit 3:

    error - lib/src/credentials/ssh_keypair.dart:6:8 - Target of URI doesn't exist:
      'package:ed25519_edwards/ed25519_edwards.dart' … uri_does_not_exist
    error - test/credential_keypair_test.dart:7:8 - (same)
    2 issues found.

Before reporting anything I established whether this was a defect in the merged content
or in my local resolution. It was the latter:

- merged `apps/server/pubspec.yaml` **does** declare `ed25519_edwards: ^0.3.2` (line 23,
  with the ADR 0018 A3 rationale comment);
- merged root `pubspec.lock` **does** pin `ed25519_edwards 0.3.2` — the merge's
  `pubspec.lock` hunk adds exactly `adaptive_number` and `ed25519_edwards` (16 lines);
- local `.dart_tool/package_config.json` was dated **Oct 4**, predating the merge, and
  contained 0 occurrences of `ed25519` while containing `crypto`. The checkout had simply
  never been re-resolved against the new dependency.

`dart pub get` at the workspace root resolved it. I then confirmed the **committed**
`pubspec.lock` was **not** modified by the resolution (`git status --porcelain pubspec.lock`
empty; blob still `9d31a59ff69ac42e9990405edbbd051456750abb`), so the reviewed lock is
untouched. Gate 2 re-run: **"No issues found!", exit 0** — matching the reviewer exactly.

This is worth persisting: **a fresh checkout of `main` will need `dart pub get` before
`dart analyze` will pass.** It is a resolution-state fact, not a code defect, and it is
the same class of thing that makes people report phantom analyzer failures.

## 5. Reconciling the test-gate figure — and a load-sensitivity finding

I ran `make test-integration` three times. The figures do **not** agree with each other,
and the reason matters more than the number:

| run | result | exit |
|---|---|---|
| 1 | `+192` — **All tests passed!** | 0 |
| 2 | `+191 -1` — Some tests failed. | 2 |
| 3 | `+191 -1` — Some tests failed. | 2 |

- **The figure I measured for the red state is `+191 -1`**, which matches the reviewer
  and the ledger exactly. I did **not** measure `+171 -1`; that earlier figure remains
  unreconciled by me and I have no evidence for it. Base is `+170 -2` per the reviewer.
- **Run 1 passing is new information.** The gate is not deterministically red: it is
  **load-sensitive**. The failure is a 30 s timeout on a walk the reviewer measured at
  43 098 ms, so when the machine is quiet the walk completes inside budget and the suite
  is fully green; under load it overruns and fails. That is consistent with the
  orchestrator's warning about load, in the opposite direction: no run I made was
  cascade-polluted (`+11 -21` pool-lock style never appeared — the rest of the suite sits
  at a solid `+191`/`+192`), so none of these runs is cascade evidence.
- The sole failing test was `dogfood_shipit_postgres_test.dart` in **all three** runs. It
  is pre-existing, lives in `packages/**`, and this change does not touch it —
  `migrations/**` is byte-identical and `packages/**` has zero changed files. Recorded as
  **N-1, open**. Not a worktree quirk; not a regression.

A benign, pre-existing schema-guard **WARNING** also appears on several tests ("Missing
Index `design_revision_approved_unique_per_work_item`", "Missing Index
`product_credential_active_repository_unique`"). It is non-fatal and unrelated to this
merge — `migrations/**` is untouched — but it belongs with `fix/credential-identity-invariants`
(`a4c211c`), which is where the index `IF NOT EXISTS` expectations are declared. Flagged,
not fixed.

## 6. Test resource hygiene

`make test-integration` was the **only** source of a real database, exactly as sanctioned.
Before running it I read the target to confirm it could not touch the QA stack: it creates
its own project `shipit_integration_<pid>`, brings up only `postgres_integration`, and
traps cleanup on `EXIT INT TERM` with label-scoped leak detection
(`Makefile:191-230`). It cannot resolve to compose project `docker`.

Cleanup confirmed on every run — the target printed the removal and **never** printed
`CLEANUP FAILED` (grep count 0):

    test-integration: removing shipit_integration_91665 (container + data)
     Container shipit_integration_91665-postgres_integration-1 Removed
     Network  shipit_integration_91665_default             Removed

Zero mutating Docker/Compose commands were issued by me. No `make clean`, no `qa-down`,
no `test-env-down`, no `e2e-down`, no bare `down -v`, and — per AGENTS.md — I did not even
issue a read-only `docker ps`/`compose ps`; the target's own cleanup report is the
sanctioned evidence, which is why it is quoted in full above. The QA stack and its
stopgap run-mode override were not touched.

## 7. Working-tree hygiene

Pre-existing dirty state, captured before the merge and re-checked after the push and
after every gate. It is **byte-identical** throughout — `diff` against the pre-merge
baseline reported no change at each checkpoint:

- `apps/control_plane/test/failures/` — 48 modified
- `melos_shipit_platform.iml` — modified
- `.decisions/6bd29306-efe0-4335-9c31-d14bb4957523.yaml` — modified
- untracked — 19 entries

`git diff --cached --name-only` = **0 files staged**, before and after. No `git add -A`,
no `git commit -a`; the merge commit was created with an explicit `git merge --no-ff` on
two commits and staged nothing extra. Not one pre-existing dirty file entered any commit.

One small correction for the ledger: the dispatch brief said "17 untracked root files";
there are **18** root-level untracked files (`check_baselines.sql`, `check_facts*.sql`,
`cloudbuild.release.yaml.archive`, `export_human_claims.sql`, `human_claims_export.txt`,
`insert_*.sql`, eight `qa-*.png`, `wipe_database.sql`). The 19th is this report's own
directory. All root files remain untracked and uncommitted.

## 8. Constraints honored

- No `serverpod generate` was run — `packages/control_plane_client` remains untouched and
  reserved for the next client lane, so there was no regeneration race.
- Lane worktree `/private/tmp/shipit-impl-keys` and branch `impl/credential-key-service`
  both preserved; branch still at `7d1b1b8`.
- dogfood / G-7 / M-5 / N-2 not touched — all remain open.
- No production code was modified. The only write outside the merge was `dart pub get`,
  which refreshed gitignored `.dart_tool/` state and left the committed `pubspec.lock`
  unchanged.
- This report is **not committed**. The brief authorized the merge and the push and
  nothing else; committing the report is left to the orchestrator, who may want it in the
  same ledger update as N-1's status.

## 9. Residual risk

Integration risk is now low: merged main's code is byte-identical to the independently
approved `7d1b1b8` on every one of the 22 paths, so nothing about the reviewed evidence
changed. The two things a reader should carry forward:

1. **`main` is red on `make test-integration`** — legitimately, via N-1, and it is
   intermittent. Anyone who runs it on a quiet machine may see a green result and conclude
   the gate is fixed. It is not. Fix belongs in `packages/product_registry`.
2. **A fresh clone needs `dart pub get`** before `dart analyze apps/server` will pass,
   because the merged `pubspec.lock`/`pubspec.yaml` introduce `ed25519_edwards`.
