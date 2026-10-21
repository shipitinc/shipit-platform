MANAGER: orchestrator-main
TASK_ID: IMPL-HOME-MACHINE-LABEL
TASK_TYPE: implement
FEATURE: The Overview fabricates a machine shortage for every queued job
WORKTREE: /Users/alkebut/.aef-lanes/home-machine-label
BRANCH: fix/home-machine-label
BASE_SHA: e8cd0ce
OWNED_PATHS:
  - apps/control_plane/lib/features/home/home_bloc.dart
  - apps/control_plane/lib/features/home/            (only files you name in your report as changed)
  - apps/control_plane/test/**                        (new home_* tests you name)
READ_ONLY_PATHS:
  - apps/control_plane/lib/core/plain_language.dart
  - apps/server/lib/src/endpoints/home_endpoints.dart
  - apps/server/lib/src/models/job_summary_view.yaml
  - packages/worker_runtime/**
PROHIBITED_PATHS:
  - apps/server/lib/**                (every server path; other lanes are live)
  - apps/server/migrations/**
  - packages/scheduler/**
  - packages/worker_runtime/**
  - apps/server/test/**
ACCEPTANCE_CRITERIA:
  - A queued job is never described with a machine-shortage claim the system cannot substantiate.
  - PREFERRED: no wire-contract change. The Runs list already labels these "Waiting to start"; reuse an
    honest existing vocabulary. Adding fields to JobSummaryView requires regenerating the client and is
    a cross-cutting change - if you conclude a wire change is unavoidable, STOP and report
    IMPLEMENTATION_BLOCKED naming every file it would touch.
  - If real capacity is knowable without a wire change, use it; if not, say "queued" rather than invent.
VALIDATION_COMMANDS:
  - dart format --output=none --set-exit-if-changed apps/control_plane/lib apps/control_plane/test
  - flutter analyze --no-pub
  - flutter test --no-pub
ROUTING_CLASS: STANDARD

EVIDENCE: home_bloc.dart:249 returns 'waiting for a free machine' unconditionally for any job that is
not blockedOnDecision, not retryWaiting and not running. Neither the client JobSummary nor the server
JobSummaryView carries a capacity field, so the client CANNOT know whether a machine is free. QA
demonstrably had three free workers on 2026-10-15 (jobs claimed, dispatched and completed) while the UI
claimed a shortage. One open QA defect, defect-DEF-1791686704991884 "Machine UI says 1 of 0", reports it.

OTHER LANES LIVE: review-IMPL-TRANSITION-ROW-500 (read-only), review-IMPL-WORKER-REGISTRATION
(read-only). Neither writes, so you cannot conflict - but do NOT edit apps/server/lib/server.dart, which
a sibling lane's commit touches.

CONSTRAINTS: no docker/compose. No psql. Do not edit outside OWNED_PATHS. Commit your work. You may not
approve your own work.
