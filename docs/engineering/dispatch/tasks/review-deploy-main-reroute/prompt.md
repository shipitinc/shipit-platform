# Dispatch — review-deploy-main-reroute (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-deploy-main-reroute
TASK_TYPE: review
FEATURE: deploy land targets default branch + deployed->implementation_ready reroute
AREA: deploy_landing + work_item_transitions + guard_conditions + work_item_action_endpoints
WORKTREE: /private/tmp/shipit-feat-deploy-main
BRANCH: feat/deploy-main-reland-reroute
BASE_SHA: aa83787
HEAD_SHA_UNDER_REVIEW: a3a6bc575ab0a59bf84cde31a974563145dab5d8
ROUTING_CLASS: PRECISION
```

Independent read-only review of `a3a6bc5` — (A) deploy land resolves the product's default
branch (ladder: `symbolic-ref refs/remotes/origin/HEAD` -> verified `main`/`origin/main` ->
refusal; checks out the target before `merge --no-ff`); (B) new `deployed ->
implementation_ready` edge (orchestrator + `operatorRerouteRequested()` context guard) +
`rerouteToImplementation` operator action (wire 'reroute').

Verify rigorously:
1. Default-branch resolution — the ladder is honest (origin/HEAD wins over hardcoded `main`;
   a `trunk` remote lands on `trunk`); the checkout step happens BEFORE the merge and its
   failure refuses cleanly (nothing merged, decision still pending); never falls back to the
   checkout's current branch silently.
2. The reroute edge — `deployed -> implementationReady` only fires with `operatorReroute` in
   context (not a free transition); the actor is orchestrator; the edge is mirrored in
   workflow_state.dart consistently.
3. The reroute action — replay by requestId prefix 'operator-reroute:', blank reason/
   requester -> invalidRequest, non-deployed -> notApplicable, live job -> alreadyRunning;
   `nextTriageAttempt` floors on the item's own consumed `implement_feature` dedupe keys
   (the `:a3 -> :a4` freshness claim — a reroute without the bump would be silently inert);
   the transition + record + audit + metadataMerge are one transaction; every refusal writes
   nothing.
4. `implementationReady` re-entry — verify the rerouted item actually re-dispatches
   `implement_feature` on the ordinary tick (entry-state + fresh dedupe key, per the test).
5. actionContext omission honest (reland precedent — no dead button; invocable via generated
   client only).
6. Tests — deploy_landing_test (3 new: default-branch land while HEAD on lane branch, trunk
   via origin/HEAD, unresolved refuses) + deploy_reroute_test (8) — non-vacuous; run them.
7. Gates re-run: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart
   analyze` (apps/server + workflow_engine + control_plane_client), `dart run
   tool/run_unit_tests.dart` (apps/server), `dart test` (packages/workflow_engine) — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:`.
