MANAGER: orchestrator-main
TASK_ID: correct-analysis-comments
TASK_TYPE: correct
FEATURE: Correct two false technical claims written into code comments
AREA: apps/server/onboard_shipit_serverpod.dart, apps/control_plane/lib/data/control_plane_repository.dart
WORKTREE: /private/tmp/shipit-analysis-cleanup
BRANCH: correct/analysis-cleanup
BASE_SHA: 6f5a693
OWNED_PATHS:
  - apps/server/onboard_shipit_serverpod.dart
  - apps/control_plane/lib/data/control_plane_repository.dart
READ_ONLY_PATHS:
  - apps/server/bin/test_pod.dart
  - apps/server/pubspec.yaml
  - packages/product_registry/lib/src/engine/product_registry_engine.dart
  - apps/server/lib/src/services/control_plane_service.dart
  - apps/server/lib/src/endpoints/product_registry_endpoints.dart
  - docs/engineering/dispatch/tasks/correct-analysis-cleanup/report.md
PROHIBITED_PATHS:
  - (everything else — this is a two-file, comment-only change)
ACCEPTANCE_CRITERIA: >
  Two false technical claims removed or corrected. Comment text only. No executable
  line may change.
VALIDATION_COMMANDS:
  - cd /private/tmp/shipit-analysis-cleanup && dart analyze packages apps/server
  - cd /private/tmp/shipit-analysis-cleanup && melos run analyze
  - cd /private/tmp/shipit-analysis-cleanup/apps/control_plane && flutter analyze --no-pub
  - cd /private/tmp/shipit-analysis-cleanup/apps/control_plane && flutter test --no-pub
ROUTING_CLASS: CHEAP_READ

## Isolation pre-flight

```bash
cd /private/tmp/shipit-analysis-cleanup
git branch --show-current    # must equal correct/analysis-cleanup
git rev-parse --short HEAD   # must equal 6f5a693
```

## Original request (verbatim)

Focused re-review of `correct-analysis-cleanup` returned `RESULT: DO_NOT_APPROVE_CORRECTIONS`
with `CORRECTION_REQUIRED: YES`, on exactly two findings, both comment-text only. Its verdict:

> The central claim holds in substance but fails on two of its own rationales. 337/339
> diagnostics genuinely cleared in code with no gate weakened, no test weakened, and operator
> output provably preserved — I verified all of that independently. But the correction wrote
> two demonstrably false technical claims into production-code comments, and one of them was the
> sole stated justification for a code choice the report presents as verified. Everything else is
> verified clean and should be preserved verbatim; the correction is ~6 lines of comment text away
> from approval.

## Findings to correct

**B1 — `apps/server/onboard_shipit_serverpod.dart:51-53`.** The comment claims
`Serverpod.start()` completes on shutdown and that `await` would hang. That is FALSE for
`serverpod: 3.4.13`. Reviewer's evidence: `serverpod.dart:665` `start()` is
`await runZonedGuarded(() async { await _unguardedStart(); })`, and `_unguardedStart()` returns
after `_internalLogVerbose('Server start complete.')` — nothing awaits shutdown.
`server.dart`'s `Future<bool> start(...)` returns `_running` immediately after binding the
socket. In-repo counter-proof: `apps/server/bin/test_pod.dart:30-32` is
`await pod.start();` → writeln → `await pod.shutdown(exitProcess: true);` and is unchanged by
this work — so awaiting `start()` clearly does not deadlock.
Note the BASE comment carried the same error, so this is amplification, not origination — but the
correction elevated it into a report as *verified evidence* and into code as a durable invariant.
**Delete or rewrite those three comment lines.**
The three `unawaited(...)` calls must stay EXACTLY as they are — they are correct and
behaviour-identical (`unawaited` is `void unawaited(Future<void>? f) {}`, an empty no-op).

**B2 — `apps/control_plane/lib/data/control_plane_repository.dart:957-964`.** The comment says
`pendingBaselineDecisionId` is "the id of the fresh approval gate the engine opens after it
cancels the superseded one". FALSE on both counts. Reviewer's evidence:
`product_registry_engine.dart:588-612` **cancels** unresolved approval decisions and returns the
updated baseline — it never opens a fresh gate.
`control_plane_service.dart:543-572` doc: the service "merely delegates to the engine and logs
the action". No gate.
`product_registry_endpoints.dart:563-565` doc: "Amending a baseline cancels any unresolved
approval decision (new hash binding), so the client must request approval again against the new
revision."
Consequently `pendingBaselineDecisionId`, computed at `control_plane_service.dart:382-399` from
**unresolved** decisions only, is normally **`null`**.
The code 20 lines below the comment already contradicts it: `:982`
`question: 'Operator claim added — request approval for new revision'`.
**Rewrite the comment to state the real, narrower defect:** the method fabricates a
`pending` `DecisionView` whose `decisionId: 'baseline-claim:<microsecondsSinceEpoch>'`
(`:977`) exists nowhere server-side, with hardcoded `status: 'pending'` (`:981`) and
`options: []` (`:984`). Do NOT assert that a real decision is being discarded.
The Manager has been separately notified of that product defect.

## What must NOT change

- All 337 diagnostic fixes from `69b63d8` and `6f5a693` — verified correct, preserve verbatim.
- Any executable line in either file. This is a comment-only change.
- The three `unawaited(...)` calls in `onboard_shipit_serverpod.dart`.
- The two `deprecated_member_use` STOPs in `packages/workflow_engine` — correct to leave, and
  out of scope here.

## Acceptance criteria

- [ ] Both false claims deleted or corrected in code comments
- [ ] `git diff 6f5a693..HEAD --stat` shows exactly 2 files changed, comment lines only
- [ ] `dart analyze packages apps/server` still exits 0
- [ ] `melos run analyze` still SUCCESS
- [ ] `flutter analyze --no-pub` still "No issues found!"
- [ ] `flutter test --no-pub` still 190/190
- [ ] Commit is NEW on top of `6f5a693`; never amend, rebase or squash

## Required validation commands

- [ ] `git diff 6f5a693..HEAD` — confirm the diff is comments only, no code
- [ ] `cd /private/tmp/shipit-analysis-cleanup && dart analyze packages apps/server` → exit 0
- [ ] `melos run analyze` → SUCCESS
- [ ] `cd apps/control_plane && flutter analyze --no-pub` → "No issues found!"
- [ ] `cd apps/control_plane && flutter test --no-pub` → 190/190

## Hard rules for the child

- Comment text only. If you believe a code change is required, STOP and report instead.
- Write only inside `OWNED_PATHS`.
- Do not push, merge, or touch `main`. Commit on `correct/analysis-cleanup`.
- Do not touch any Docker container or database.
- Every result carries exact repository/worktree/HEAD provenance.

## Report format

Return a report conforming to `subtask-report.md`. Your `RESULT:` must be verbatim one of your
own agent file's tokens from `.agents/agents/correction-implementer.md`. Retain the worktree.
