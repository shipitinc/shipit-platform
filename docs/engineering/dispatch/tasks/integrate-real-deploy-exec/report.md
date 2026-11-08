# Integrator report — integrate-real-deploy-exec

RESULT: MERGE_APPROVED

APPROVED_HEAD: 7e83f4e51d228959209eba5e3e42f56418c8241e
  - exact HEAD of feat/real-deploy-exec (worktree /private/tmp/shipit-feat-real-deploy, clean)
  - review provenance: APPROVE_WITH_NON_BLOCKING_FOLLOWUP on 7e83f4e, gates all green

CURRENT_MAIN: dffb0b9b69960ad36ba7917049913e0e64e89fbc (local canonical; origin/main f58d6fb is 662 behind)

BASE/MERGE-BASE: 3fd55e0aee7869b543d444eff3923cf3e8e5cd2e == declared BASE_SHA.
  main advanced 7 commits since base — dispatch/ledger docs only (4 files,
  all docs/engineering/dispatch/**). The auto-deploy sweep landed BEFORE
  base (e77ffd0/86d069e are ancestors of 3fd55e0), so deploy_advance.dart /
  deploy_gate_sweep.dart already existed at base; neither file changed on
  main since base, and control_plane_service.dart is untouched on main
  since base.

MERGE VERIFICATION (no write to main):
  - git merge-tree --write-tree main 7e83f4e -> tree 3d7e3b8, exit 0, zero conflicted paths.
  - Real dry-run: temp detached worktree at main + `git merge --no-commit --no-ff 7e83f4e`
    -> "Automatic merge went well"; staged adds only (deploy_landing.dart,
    deploy_landing_test.dart, control_plane_service.dart hunk). Worktree removed after gates.

SEMANTIC OVERLAP CHECK (apps/server/lib/src/deploy/**):
  - deploy_gate_sweep.dart / deploy_advance.dart = upstream side: advance
    qaPassed -> deploying -> waiting_for_human_decision, mint DeploymentArtifact,
    raise deploymentApproval.
  - deploy_landing.dart = downstream side: on an APPROVED deploymentApproval,
    merge the produced commit into the product's recorded checkout and prove
    reachability BEFORE `deployed` is written (F-257).
  - Complementary stages of the same gate, not duplicates: the sweep parks the
    item at the decision; the landing executes the approve. Shared read helpers
    (resolveProducerExecution, producedCommitFor) only — no divergent logic.

GATES on the merged tree (scratch worktree of the real merge):
  format  = PASS  `dart format --output=none --set-exit-if-changed .` (repo root) — 1108 files, 0 changed
  analyze = PASS  `dart analyze` (apps/server) — exit 0; 5 pre-existing info lints in
                  test/integration/ files, none in touched files
  tests   = PASS  `dart run tool/run_unit_tests.dart` (apps/server) —
                  "75 files, all passed" (includes new deploy_landing_test.dart;
                  test/integration/ excluded by construction)
  build   = n/a   — no build gate declared in repo policy (per-execution tier is
                  format/analyze/tests; integration tier is merge/release and
                  not claimed here)

PROVENANCE: reviewed HEAD is what would be merged (merge input pinned by SHA
7e83f4e, not by branch name); branch is exactly 1 commit ahead of merge-base.

READY_FOR_INTEGRATION: YES — safe strategy is a true merge of 7e83f4e into
main (tree 3d7e3b8 already computed clean; FF impossible since main advanced).
Per framework policy, actual push/merge remains a human/orchestrator action —
this lane stops at merge-readiness.
