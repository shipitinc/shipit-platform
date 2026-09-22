-- Seed data for human QA of the Overview screen.
--
-- Mirrors the sample content on the Penpot board `BP · Home` so the running
-- app can be compared against the design directly. Every row lands in the
-- durable tables the read endpoints actually query — nothing is stubbed in the
-- UI layer.
--
-- Usage (test database on :9090):
--   PGPASSWORD=control_plane_test_pw /opt/homebrew/opt/libpq/bin/psql \
--     -h localhost -p 9090 -U postgres -d control_plane_test \
--     -f tool/seed_overview_qa.sql

BEGIN;

DELETE FROM "human_decision";
DELETE FROM "work_item_transition";
DELETE FROM "job_claim";
DELETE FROM "job";
DELETE FROM "worker_registration";
DELETE FROM "work_item";

-- ---------------------------------------------------------------------------
-- Work items. Ages are relative to now so "RUNNING FOR" shows real elapsed
-- times; the design's board shows 42m / 3h 12m / 1h 08m / 2h 02m.
-- ---------------------------------------------------------------------------
INSERT INTO "work_item" (
  "workItemId", "productId", "category", "title", "description", "state",
  "blockingHumanDecisionId", "blockingReason",
  "createdAt", "updatedAt", "completedAt", "version"
) VALUES
  ('WI-4f2a', 'shipit', 'feature', 'Sign-up journey E2E harness',
   'Test the full sign-up journey', 'agent_executing',
   NULL, NULL, NOW() - INTERVAL '42 minutes', NOW() - INTERVAL '2 minutes',
   NULL, 3),

  ('WI-9c11', 'shipit', 'feature', 'Scheduler claim-CAS dedupe patch',
   'Stop duplicate jobs running twice', 'waiting_for_human_decision',
   'GD-5b1e', 'Design approval required before implementation',
   NOW() - INTERVAL '3 hours 12 minutes', NOW() - INTERVAL '1 minute',
   NULL, 4),

  ('WI-7e0b', 'shipit', 'feature', 'Postgres migration contract test',
   'Check the database upgrade is safe', 'agent_executing',
   NULL, NULL, NOW() - INTERVAL '1 hour 8 minutes', NOW(), NULL, 2),

  -- Escalated after a failure. The engine's invariant is that a blocking
  -- decision always parks the item at the gate, so the durable state is
  -- `waiting_for_human_decision`; the failure it halted in is carried by the
  -- decision's context and is what makes this read "Needs you - it failed".
  ('WI-3d8c', 'shipit', 'feature', 'Penpot design authority probe',
   'Check we can reach the design tool', 'waiting_for_human_decision',
   'GD-8a32', 'Retry limit reached; needs a human call',
   NOW() - INTERVAL '2 hours 2 minutes', NOW(), NULL, 5),

  -- Four passed + one failed in the last day, matching the FINISHED column.
  ('WI-1aa5', 'shipit', 'feature', 'Job active dedupe index',
   'Check for duplicate safety rules', 'completed', NULL, NULL,
   NOW() - INTERVAL '6 hours', NOW() - INTERVAL '5 hours',
   NOW() - INTERVAL '5 hours', 7),
  ('WI-6cf0', 'shipit', 'feature', 'Agent runtime smoke test',
   'Check the AI connection works', 'completed', NULL, NULL,
   NOW() - INTERVAL '7 hours', NOW() - INTERVAL '6 hours',
   NOW() - INTERVAL '6 hours', 6),
  ('WI-b74d', 'shipit', 'feature', 'Human decision durability',
   'Make approvals survive a restart', 'completed', NULL, NULL,
   NOW() - INTERVAL '9 hours', NOW() - INTERVAL '8 hours',
   NOW() - INTERVAL '8 hours', 8),
  ('WI-2ef9', 'shipit', 'feature', 'Capacity-aware dispatch',
   'Check how much work fits at once', 'completed', NULL, NULL,
   NOW() - INTERVAL '11 hours', NOW() - INTERVAL '10 hours',
   NOW() - INTERVAL '10 hours', 5),
  ('WI-5b90', 'shipit', 'feature', 'Legacy deploy path removal',
   'Retire the old deploy path', 'cancelled', NULL, NULL,
   NOW() - INTERVAL '13 hours', NOW() - INTERVAL '12 hours',
   NOW() - INTERVAL '12 hours', 4);

-- ---------------------------------------------------------------------------
-- Artifacts under review. These are what the evidence panel renders on Run
-- detail and Decision detail: the thing the operator is being asked to
-- approve, with a link out to it.
--
-- `artifactType` values come from the durable ArtifactType vocabulary
-- (design_revision | qa_evidence | code_diff | ...).
-- ---------------------------------------------------------------------------
UPDATE "work_item"
SET "artifactRefsJson" = json_build_array(
  json_build_object(
    'artifactId', 'DR-9c11-v3',
    'artifactType', 'design_revision',
    'uri', 'https://design.penpot.app/#/view/control-plane-operator-ui',
    'provider', 'penpot',
    'contentHash', 'sha256:7c1f9a2b4e6d8c0a',
    'description', 'Design version 3',
    'createdAt', to_char(NOW() - INTERVAL '3 hours',
                         'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
  ),
  json_build_object(
    'artifactId', 'QA-9c11-run7',
    'artifactType', 'qa_evidence',
    'uri', 'https://ci.shipit.local/runs/9c11/checks',
    'provider', 'shipit-qa',
    'contentHash', 'sha256:2b8e4f1d6a3c5079',
    'description', 'Checked by an independent reviewer and passed',
    'createdAt', to_char(NOW() - INTERVAL '2 hours 55 minutes',
                         'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
  )
)::text
WHERE "workItemId" = 'WI-9c11';

UPDATE "work_item"
SET "artifactRefsJson" = json_build_array(
  json_build_object(
    'artifactId', 'LOG-3d8c-attempt3',
    'artifactType', 'qa_evidence',
    'uri', 'https://ci.shipit.local/runs/3d8c/log',
    'provider', 'shipit-qa',
    'description', 'Last run log',
    'createdAt', to_char(NOW() - INTERVAL '2 hours 5 minutes',
                         'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
  )
)::text
WHERE "workItemId" = 'WI-3d8c';

-- ---------------------------------------------------------------------------
-- Blocking decisions, with the recommendations the design renders as
-- "We suggest: ...".
-- ---------------------------------------------------------------------------
INSERT INTO "human_decision" (
  "decisionId", "workItemId", "decisionType", "status", "question",
  "contextJson", "optionsJson", "recommendation", "blocking",
  "requestedAt", "updatedAt"
) VALUES
  ('GD-5b1e', 'WI-9c11', 'design_approval', 'pending',
   'Approve the design for stopping duplicate jobs?',
   '{"workflowState":"design_in_review","availableOptions":["approve","rework","reject"]}',
   '[{"optionId":"approve","label":"approve","description":"Design is approved","recommended":true},{"optionId":"rework","label":"rework","description":"Design goes back for changes","recommended":false},{"optionId":"reject","label":"reject","description":"Design is turned down","recommended":false}]',
   'Approve — the plan matches the test plan, and no design risks were found.',
   true, NOW() - INTERVAL '3 hours 12 minutes',
   NOW() - INTERVAL '3 hours 12 minutes'),

  ('GD-8a32', 'WI-3d8c', 'escalation', 'pending',
   'Try the design tool check again?',
   '{"workflowState":"agent_failed","availableOptions":["approve","cancel"]}',
   '[{"optionId":"approve","label":"approve","description":"The run starts again from the failed step","recommended":true},{"optionId":"cancel","label":"cancel","description":"This work stops for good","recommended":false}]',
   'Resume — the retry limit was hit by a setup check, not by the work itself.',
   true, NOW() - INTERVAL '2 hours 2 minutes',
   NOW() - INTERVAL '2 hours 2 minutes');

-- ---------------------------------------------------------------------------
-- Transition history for the run that is blocked (feeds Run detail later).
-- ---------------------------------------------------------------------------
-- Triggers, actors and outcomes use the durable enum vocabularies:
-- TransitionTrigger (system_event | agent_result | human_decision | timer |
-- manual), WorkflowActor (orchestrator | implementation_agent | human | ...)
-- and TransitionOutcome (accepted | rejected).
INSERT INTO "work_item_transition" (
  "transitionId", "workItemId", "fromState", "toState", "trigger",
  "actorType", "outcome", "reason", "occurredAt"
) VALUES
  ('T-9c11-1', 'WI-9c11', 'draft', 'planning', 'system_event', 'orchestrator',
   'accepted', NULL, NOW() - INTERVAL '3 hours 10 minutes'),
  ('T-9c11-2', 'WI-9c11', 'planning', 'planned', 'agent_result',
   'implementation_agent', 'accepted', 'Plan written',
   NOW() - INTERVAL '3 hours 5 minutes'),
  ('T-9c11-3', 'WI-9c11', 'planned', 'design_in_review', 'system_event',
   'orchestrator', 'accepted', 'Design needed before building',
   NOW() - INTERVAL '3 hours'),
  ('T-9c11-4', 'WI-9c11', 'design_in_review', 'waiting_for_human_decision',
   'system_event', 'orchestrator', 'accepted', 'Sent to you for approval',
   NOW() - INTERVAL '2 hours 50 minutes');

-- ---------------------------------------------------------------------------
-- Queue: the "Machines and next steps" strip. JOB-31 is held up by the
-- pending decision on WI-9c11; JOB-28 is actively running.
-- ---------------------------------------------------------------------------
INSERT INTO "job" (
  "jobId", "workItemId", "jobType", "requiredRole",
  "requiredCapabilitiesJson", "priority", "state", "dedupeKey",
  "createdAt", "availableAt", "instruction", "attempt", "maxAttempts",
  "startedAt", "version"
) VALUES
  ('JOB-31', 'WI-9c11', 'implement_feature', 'IMPLEMENTER',
   '["macos"]', 'normal', 'queued', 'WI-9c11:implement_feature:1',
   NOW() - INTERVAL '50 minutes', NULL,
   'Implement claim-CAS dedupe once the design is approved.', 1, 3, NULL, 1),

  ('JOB-28', 'WI-4f2a', 'implement_feature', 'IMPLEMENTER',
   '["macos"]', 'normal', 'running', 'WI-4f2a:implement_feature:1',
   NOW() - INTERVAL '42 minutes', NULL,
   'Write the sign-up journey coverage.', 1, 3,
   NOW() - INTERVAL '40 minutes', 2);

-- ---------------------------------------------------------------------------
-- Registered workers, for the capacity readout. `capabilities` is a map of
-- capability name to spec; an empty map is valid.
-- ---------------------------------------------------------------------------
INSERT INTO "worker_registration" (
  "workerId", "poolId", "capabilitiesJson", "status", "currentLoad",
  "maxConcurrency", "lastHeartbeat", "platform"
) VALUES
  ('worker-local-1', 'local', '{}', 'busy', 1, 1, NOW(), 'macos'),
  ('worker-local-2', 'local', '{}', 'idle', 0, 1, NOW(), 'macos');

-- One live execution, so capacity reads "1 of 2 machines busy". A worker
-- counts as busy while it holds a non-terminal execution.
DELETE FROM "worker_execution";
INSERT INTO "worker_execution" (
  "workerExecutionId", "workItemId", "repositoryPath",
  "requestedStartingRevision", "requiredCapabilitiesJson", "status",
  "cleanupPolicy", "workerId", "createdAt", "startedAt", "version"
) VALUES
  ('WX-4f2a-1', 'WI-4f2a', '/Users/shipit/workspaces/WI-4f2a',
   'a1b2c3d4', '["macos"]', 'agentExecuting', 'preserveOnFailure',
   'worker-local-1', NOW() - INTERVAL '41 minutes',
   NOW() - INTERVAL '40 minutes', 1);

-- ---------------------------------------------------------------------------
-- Decision history, so the "Already decided" ledger has more than one page
-- and the lazy-scroll paging can be exercised (page size is 10).
-- ---------------------------------------------------------------------------
INSERT INTO "human_decision" (
  "decisionId", "workItemId", "decisionType", "status", "question",
  "contextJson", "optionsJson", "blocking", "requestedAt",
  "decider", "choice", "rationale", "timestamp", "updatedAt")
SELECT
  'GD-H' || i, 'WI-1aa5', 'design_approval', 'resolved',
  'Historic decision ' || i,
  '{"workflowState":"design_in_review","availableOptions":["approve","reject"]}',
  '[{"optionId":"approve","label":"approve","recommended":true}]',
  false, NOW() - (i || ' hours')::interval,
  'operator',
  CASE WHEN i % 3 = 0 THEN 'reject' ELSE 'approve' END,
  'Recorded for paging QA.',
  NOW() - (i || ' hours')::interval,
  NOW() - (i || ' hours')::interval
FROM generate_series(1, 14) AS i;

COMMIT;
