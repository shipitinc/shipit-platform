# Dispatch — review-deploy-push-remote

```yaml
MANAGER: orchestrator-main
TASK_ID: review-deploy-push-remote
TASK_TYPE: review
FEATURE: deploy landing pushes the merged default branch to the product remote via the verified deploy key (F-258)
AREA: apps/server deploy landing + SSH push transport
WORKTREE: /private/tmp/shipit-feat-deploy-push
BRANCH: feat/deploy-push-remote
BASE_SHA: d027477
HEAD_SHA_UNDER_REVIEW: c9fc77e7453de00d1a7220823cc0a14531c58a00
ROUTING_CLASS: PRECISION
```

Independent read-only review of `c9fc77e` — the push-remote step on deploy landing. 7 files:
new `deploy_push.dart` + `deploy_push_test.dart`; `deploy_landing.dart` (push on both arms,
`DeployLanding.push`, `deployedRemote` stamp, `deployPush` required param);
`control_plane_service.dart` (lazy `deployPusher`); `work_item_action_endpoints.dart`
(reland passes `service.deployPusher`); `deploy_landing_test.dart` + `deploy_reland_test.dart`.

Verify rigorously:
1. Push fires on BOTH land arms (merge + already-landed) and on approve + reland paths —
   trace every call site of `landApprovedDeployment`/`relandDeployedItem` for the required
   `deployPush` param (an unwired caller = the feature silently no-ops).
2. Push failure → `DeployLandingException` → nothing durable written → decision stays
   pending (the approve is NOT consumed); verify the merge-stays-local claim is honest and
   the item does NOT reach deployed-without-push.
3. Credential resolution is honest — `git remote get-url origin` → normalized SshRemote →
   `readActiveCredential` → provenance checks; the secret is read once by name and wiped;
   a missing/revoked credential refuses honestly (never falls back to ambient SSH).
4. Transport safety — `SshDeployPushTransport`: scan-then-match host key, GIT_SSH wrapper,
   ls-remote→fetch→ancestry→push→re-read→verify; remote-already-contains → `alreadyCurrent`
   (idempotent); diverged/non-ff → refusal, NEVER force-push. No `push --force`, no
   ambient credential leak, no secret material in logs/exceptions.
5. The `deployedRemote` stamp is honest — set only after verified push, absent on
   refusal/interruption; idempotent retry completes an interrupted push.
6. Tests genuinely exercise it — the local-path-remote push + refusal + idempotent cases
   are real assertions, not tautologies; no test weakened/removed.
7. Gates re-run: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart
   analyze` (apps/server), `dart run tool/run_unit_tests.dart` (apps/server) — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:`.
