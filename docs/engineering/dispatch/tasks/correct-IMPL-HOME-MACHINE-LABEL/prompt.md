MANAGER: orchestrator-main
TASK_ID: correct-IMPL-HOME-MACHINE-LABEL
TASK_TYPE: correct
FEATURE: claimed jobs are still told the fleet is exhausted
WORKTREE: /Users/alkebut/.aef-lanes/home-machine-label-correction
BRANCH: fix/home-machine-label-corrected
BASE_SHA: 75598ae   (the reviewed HEAD — correction stacks ON it)
OWNED_PATHS:
  - apps/control_plane/lib/features/home/home_bloc.dart
  - apps/control_plane/test/blocs/home_job_label_test.dart
  - docs/engineering/learning/<one new file>   (granted, for M1)
  - docs/engineering/dispatch/tasks/IMPL-HOME-MACHINE-LABEL/report.md  (granted, for L2)
PROHIBITED_PATHS:
  - apps/server/**  packages/**  docker/**  .github/**
VALIDATION_COMMANDS:
  - dart format --output=none --set-exit-if-changed lib test
  - flutter analyze --no-pub
  - flutter test --no-pub
ROUTING_CLASS: STANDARD

Independent review returned RESULT: DO_NOT_MERGE at 75598ae. No BLOCKERS, one HIGH, one MEDIUM, two LOW.

H1 (HIGH) — home_bloc.dart:311. `return capacity.isExhausted ? 'every machine is busy' : 'queued';`
is reached by `queued` AND `claimed`. A `claimed` job ALREADY HOLDS A MACHINE — `JobCapacityAdmitted.claim`
is documented at `job_capacity_guard.dart:34-36` as the proof the slot was taken, and `claimed` is only
written after `CapacityAdmitted`; `home_endpoints.dart:88-95` puts claimed jobs on the strip. So with 2
machines, one running and one claimed, the operator reads a job that holds a machine being told it is
waiting for one, with "2 of 2 machines busy" printed immediately to its right. The change's own doc
comment on MachineCapacity claims it never asserts that any particular job waits because of the shortage —
the code does exactly that in the one case with decisive contrary evidence.

REQUIRED FIX — the reviewer suggested this shape:
  if (stateWire == 'claimed') return 'on a machine';
  return capacity.isExhausted ? 'every machine is busy' : 'queued';
Also decide the UNKNOWN-state arm explicitly: an unrecognised stateWire currently inherits the fleet
sentence. `stateLabel` (home_bloc.dart:236-241) already models the right answer with `_ => 'Waiting'` —
mirror that neutrality rather than letting an unknown state make a fleet-level claim.

REQUIRED TESTS — the existing sweep only forbids the substring "free machine" and CANNOT catch H1.
Add `claimed` x {0/0, 1/3, 3/3} x {blocked, unblocked} cases asserting `every machine is busy` is NEVER
produced for a non-`queued` state, and an explicit unknown-state case.

M1 (MEDIUM) — no durable learning persisted, against LEARNING_POLICY.md. Persist the reusable finding:
*a fleet-wide fact is not evidence about a single row; a label rendered per-item must be substantiated by
evidence about that item.* Classify it (WORKFLOW_IMPROVEMENT or DESIGN_IMCOVERY category per the policy).

L1 (LOW) — the doc comment at home_bloc.dart:302-306 claims the Overview "agrees with the rest of the
product" by citing `PlainStatus.waitingToStart`, whose value is 'Waiting to start' — a string the code
never emits. Either emit it or drop the claim.

L2 (LOW) — write your report to docs/engineering/dispatch/tasks/IMPL-HOME-MACHINE-LABEL/report.md.

DO NOT fix `operator_action_copy.dart` — the reviewer assessed it as a weaker class (real resolved
capacity gate, forward-tense consequence statement emitted on the operator's own click) but found
acceptedOutcomeSentence emits even when capacity is UNKNOWN. That is design-mandated copy under AC-16 /
§5.4 and belongs to design, not to a correction lane. Leave it.

CONSTRAINTS: no docker/compose. No psql. Do not edit outside OWNED_PATHS. Commit as a NEW commit on top of
75598ae — never amend or rebase. You may not approve your own work; a fresh focused-reviewer gates this.
Report CORRECTION_COMPLETE (or CORRECTION_BLOCKED) with READY_FOR_FOCUSED_REVIEW and exact git rev-parse HEAD.
