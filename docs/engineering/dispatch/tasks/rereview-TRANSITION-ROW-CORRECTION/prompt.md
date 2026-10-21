MANAGER: orchestrator-main
TASK_ID: rereview-TRANSITION-ROW-CORRECTION
TASK_TYPE: re-review
FEATURE: Focused re-review of the corrected transition-row fix
WORKTREE: /Users/alkebut/.aef-lanes/transition-row-correction (READ-ONLY)
BRANCH: fix/transition-row-malformed-guard-corrected
BASE_SHA: e8cd0ce
HEAD UNDER REVIEW: 994073d  (correction stacked on the reviewed d8e0b0d)
OWNED_PATHS: (none - read-only)
VALIDATION_COMMANDS:
  - dart format --output=none --set-exit-if-changed apps/server/lib apps/server/test
  - dart analyze apps/server
  - dart test test/transition_row_malformed_guard_test.dart
ROUTING_CLASS: PRECISION

Do NOT repeat the full review at d8e0b0d. Re-review ONLY the corrections plus regression risk they
introduced. Follow aef-independent-review's focused path.

The original review returned DO_NOT_MERGE with five blockers. Verify each is genuinely closed:

B1 — migration 20261015120000000 reintroduced the HTTP 500 on the five rows it targeted (array wrap
     satisfied the container cast, then TransitionGuardEvaluation.fromJson threw on `guardName`).
     Claimed fix: the migration directory, its registry line and its test were DELETED; the reader
     change alone is kept. VERIFY the migration is genuinely gone from the tree AND that the reader
     change still degrades-and-reports rather than throwing.
B2 — the DOWN's selector matched legitimate single-guard-evaluation rows (work_item_transitions.dart:796
     writes one guard result for every rejected transition) and would have corrupted them.
     Claimed: moot by removal. VERIFY no surviving code path can still mis-select rows.
B3 — 20261014210000000's down half-runs then deletes the restore payload; the documented order was
     prose plus a documentation-shaped test. Claimed: moot by removal. VERIFY the cross-migration hazard
     is genuinely gone rather than merely undocumented now.
B4 — `::jsonb` re-asserted in the UPDATE's WHERE could abort the whole migration outside the EXCEPTION
     handler. Claimed: moot by removal. VERIFY.
B5 — migration SQL never parsed by PostgreSQL. Claimed: moot — nothing is applied. VERIFY no executable
     SQL remains in the diff.

ALSO VERIFY THE NEW WORK:
H1 — a RAW 0x00 byte in transition_row_malformed_guard_test.dart made the primary regression gate
     UNREVIEWABLE through git. Claimed: replaced with the escape; committed blob has 0 NUL bytes and
     `git diff e8cd0ce HEAD` renders all 475 lines as text. VERIFY — and note the correction lane disclosed
     that `git diff d8e0b0d HEAD` still reports Bin because the REMOVED line contains the NUL. Confirm
     that is one-directional and that the file AT HEAD is clean.
M1 — stderr -> stdout for the defect report. VERIFY the stdout claim against server.dart:1762's actual
     convention and that nothing else depended on stderr.
M2 — the dead `'repairMigration': '20261015120000000'` field was replaced by `'sourcePayload'`. VERIFY no
     test depended on the old field and that the new one is truthful.
M3 — DISCOVERY 2 persisted to docs/engineering/learning/a-container-that-conforms-is-not-a-payload-that-does.md.
     VERIFY it is classified per LEARNING_POLICY.md and states the finding accurately.
L1 — deliberately left: the hard-coded "fourteen call sites" figure. VERIFY the count is still 14 across
     6 files, so leaving it was correct rather than lazy.

REGRESSION RISK FROM THE DELETIONS — the part only you can catch:
- The five malformed rows are STILL IN THE QA DATABASE, still carrying 20261014210000000's restore
  payload, and are now read ONLY by the in-code reader. Confirm nothing else depended on the migration
  existing. Confirm no test, script, doc or comment now references a migration that is gone
  (the correction claims `rg -a 20261015120000000` returns nothing repo-wide — verify with `rg -a`,
  since a plain `rg` is BLIND to NUL-containing files, which is how the original review missed a reference).
- The correction lane disclosed that apps/server/test/secret_provider_test.dart carries the SAME raw NUL
  byte (offset 9570) and that ripgrep silently skips such files. Confirm. That file is NOT in this lane's
  ownership — report, do not fix.
- Verify the correction did not weaken any assertion that was passing before. The remaining test file
  should still be 21 tests and still discriminate.

Return APPROVE_CORRECTIONS or DO_NOT_APPROVE_CORRECTIONS with concrete findings. No docker, no compose, no
psql, no file edits. Report per the subtask-report template.
