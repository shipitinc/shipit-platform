MANAGER: orchestrator-main
TASK_ID: correct-IMPL-TRANSITION-ROW-500
TASK_TYPE: correct
FEATURE: Withdraw the repair migration that reintroduces the 500; keep the reader fix
WORKTREE: /Users/alkebut/.aef-lanes/transition-row-correction
BRANCH: fix/transition-row-malformed-guard-corrected
BASE_SHA: d8e0b0d   (the reviewed HEAD — correction stacks ON it, never rewrites it)
OWNED_PATHS:
  - apps/server/lib/src/persistence/util/db_row_util.dart
  - apps/server/lib/src/persistence/postgres_workflow_store.dart
  - apps/server/migrations/migration_registry.txt          (REVERT the added line only)
  - apps/server/test/transition_row_malformed_guard_test.dart
  - apps/server/lib/src/review/**                            (NO — not yours; see PROHIBITED)
PROHIBITED_PATHS:
  - apps/server/lib/src/review/**  apps/control_plane/**  packages/scheduler/**
  - packages/worker_runtime/**  apps/server/lib/server.dart
  - apps/server/migrations/20261015120000000/**               (you DELETE it; nothing else touches it)
VALIDATION_COMMANDS:
  - dart format --output=none --set-exit-if-changed apps/server/lib apps/server/test
  - dart analyze apps/server
  - dart test test/transition_row_malformed_guard_test.dart
ROUTING_CLASS: PRECISION

Independent review returned RESULT: DO_NOT_MERGE at d8e0b0d. Five blockers. The decisive one:

B1 — the migration reintroduces the HTTP 500 it exists to fix, on exactly the five rows it targets.
The implementer's OWN test proves it (transition_row_malformed_guard_test.dart:375-398): the array wrap
makes the container cast succeed (so no defect is reported) while
`TransitionGuardEvaluation.fromJson` then throws `_TypeError` on `guardName: json['guardName'] as String`,
because the repair payload has no guardName. The two halves of this commit are mutually exclusive. The
READER change is a complete, correct fix on its own: a malformed column degrades to absent, is REPORTED,
and the row returns. Shipping both is strictly worse than shipping either half.

REQUIRED CORRECTION — this is the whole job:
  1. DELETE the migration directory apps/server/migrations/20261015120000000/ entirely.
  2. REVERT its line in apps/server/migrations/migration_registry.txt.
  3. DELETE apps/server/test/malformed_guard_evaluation_repair_migration_test.dart.
  4. KEEP the reader change (db_row_util.dart `readJsonArrayColumn` + the single call site moved in
     postgres_workflow_store.dart) and KEEP transition_row_malformed_guard_test.dart.
  5. Adjust any surviving comment or constant in the reader change that references the migration.

ALSO FIX (from the same review):
  H1 — transition_row_malformed_guard_test.dart contains a RAW 0x00 BYTE at line ~105, inside a string
       literal where the four-character escape \x00 was intended. This makes `git diff --stat` report
       `Bin 0 -> 18745 bytes` and makes the primary regression gate for this change UNREVIEWABLE through
       git. Replace the raw byte with the escape. (apps/server/test/secret_provider_test.dart:268 has the
       same pre-existing slip — report it, do NOT fix it; it is not yours.)
  M1 — postgres_workflow_store.dart uses stderr.writeln for the defect report; the convention it claims
       to match is stdout (server.dart:1762). Align, or state in the comment why stderr is required.
  M2 — the 'repairMigration': '20261015120000000' report field is dead once the migration is dropped.
       Remove it.
  M3 — DISCOVERY 2 (the repair-metadata object is not readable as a guard evaluation; the container wrap
       relocates the failure rather than fixing it; the reader change is a complete fix on its own) is
       proven by an executed test but currently lives ONLY in code comments that this correction reverts.
       docs/engineering/LEARNING_POLICY.md requires it be classified and persisted. Persist it to
       docs/engineering/learning/ as a RUNTIME_DISCOVERY / PROJECT_FACT. Note: docs/ is normally outside
       an implementation lane's ownership; for THIS correction it is explicitly granted for this one file
       only.

CONSTRAINTS: no docker or docker compose command. No psql — do NOT connect to or modify the live QA
database, and do NOT apply any migration anywhere. Commit your work as a NEW commit on top of d8e0b0d;
never amend or rebase. You may not approve your own work — a fresh focused-reviewer gates this.
Report per the subtask-report template with exact git rev-parse HEAD.
