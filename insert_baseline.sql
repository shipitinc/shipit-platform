-- Insert baseline
INSERT INTO product_baseline (
  "baselineId", "productId", revision, status, "contentHash", 
  "contentHashVersion", "supersedesBaselineId", "proposedAt", 
  "reviewedAt", "acceptedAt", "acceptedBy", "acceptedDecisionId",
  "createdAt", "updatedAt", version, "verifiedAt", "verifiedBy", 
  "verificationKind", "factsJson"
) VALUES (
  'bl-shipit-platform-1',
  'shipit-platform',
  1,
  'proposed',
  'a0c6eee7881a52ab05e04c6c7a26b862877e804763ff35bcf7da51555c1c442d',
  3,
  NULL,
  now(),
  NULL,
  NULL,
  NULL,
  NULL,
  now(),
  now(),
  1,
  now(),
  'worker:baseline-verifier/onboard_shipit_dev',
  'platform_verified_evidence',
  '[
    {"factId": "tech-1", "section": "tech_stack", "claim": "Dart package manifest", "provenance": "derived", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "tech-2", "section": "tech_stack", "claim": "Dart pub workspace (multi-package)", "provenance": "derived", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "tech-3", "section": "tech_stack", "claim": "json_serializable codegen", "provenance": "derived", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "tech-4", "section": "tech_stack", "claim": "pinned SDK resolution", "provenance": "derived", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "tech-5", "section": "tech_stack", "claim": "Serverpod backend framework in use", "provenance": "derived", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "qa-1", "section": "qa", "claim": "static analysis configuration", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "env-1", "section": "environments", "claim": "container topology declares 2 services (postgres, postgres_test)", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "env-2", "section": "environments", "claim": "container topology declares 5 services (postgres, triage-seed, server, client, worker-linux)", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "env-3", "section": "environments", "claim": "docker compose infrastructure declared", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "dep-1", "section": "deployment", "claim": "Dockerfile present (containerizable)", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "arch-1", "section": "architecture", "claim": "workspace is composed of 14 Dart packages under packages/, each declaring its own responsibility", "provenance": "derived", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "arch-2", "section": "architecture", "claim": "agent_runtime — Provider-neutral agent runtime interface and adapters", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "arch-3", "section": "architecture", "claim": "control_plane_client — Generated Serverpod client protocol for the ShipIt control plane. Pure Dart; no Flutter dependency.", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "arch-4", "section": "architecture", "claim": "deployment_protocol — Artifact promotion and deployment", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "arch-5", "section": "architecture", "claim": "design_governance — Design governance store interfaces and implementations for ShipIt Platform", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "arch-6", "section": "architecture", "claim": "execution_coordinator — Coordinates durable single agent executions for ShipIt Platform work items", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "arch-7", "section": "architecture", "claim": "platform_contracts — Core domain types, enums, and JSON schemas for ShipIt Platform", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "arch-8", "section": "architecture", "claim": "product self-describes in packages/execution_coordinator/README.md — source material for operator-authored domain claims, not yet a domain claim itself", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "arch-9", "section": "architecture", "claim": "product self-describes in README.md — source material for operator-authored domain claims, not yet a domain claim itself", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "arch-10", "section": "architecture", "claim": "product_registry — Product registry, onboarding, baseline, discovery boundary, clarification, and ProductContext for ShipIt S-1.", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "arch-11", "section": "architecture", "claim": "qa_orchestration — QA gates, evidence collection, and validation", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "arch-11", "section": "architecture", "claim": "scheduler — Durable persistent scheduler and job queue for ShipIt Platform", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "arch-12", "section": "architecture", "claim": "store_contract_tests — Reusable store contract test suites, parameterized by store factory. Run against file/in-memory stores and PostgreSQL.", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "arch-13", "section": "architecture", "claim": "worker_protocol — Worker capability model and task dispatch", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "arch-14", "section": "architecture", "claim": "worker_runtime — Worker execution layer - environment ownership, workspace isolation, cleanup", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "arch-15", "section": "architecture", "claim": "workflow_engine — State machine, transitions, and validation for ShipIt Platform workflows", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "arch-16", "section": "architecture", "claim": "workflow_store — Durable persistence and replay for ShipIt Platform work items and human decisions", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-1", "section": "governance", "claim": "21 architecture decision records document how and why this platform is built the way it is", "provenance": "derived", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-2", "section": "governance", "claim": "ADR: ADR 0001: Dart as Primary Platform Implementation Language", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-3", "section": "governance", "claim": "ADR: ADR 0002: Serverpod for Control Plane Backend", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-3", "section": "governance", "claim": "ADR: ADR 0003: Flutter Web for Control Plane Frontend", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-4", "section": "governance", "claim": "ADR: ADR 0004: PostgreSQL as State Store", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-4", "section": "governance", "claim": "ADR: ADR 0005: Provider-Neutral AgentRuntime", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-5", "section": "governance", "claim": "ADR: ADR 0006: OpenCode ACP as First Agent Adapter", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-5", "section": "governance", "claim": "ADR: ADR 0007: MCP for External Agent Tooling", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-6", "section": "governance", "claim": "ADR: ADR 0008: Docker Compose for Local Environments", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-6", "section": "governance", "claim": "ADR: ADR 0009: OpenTofu for Infrastructure as Code", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-7", "section": "governance", "claim": "ADR: ADR 0010: GitHub Actions as CI/CD Execution Engine", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-7", "section": "governance", "claim": "ADR: ADR 0011: Linux + macOS Worker Capability Model", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-8", "section": "governance", "claim": "ADR: ADR 0012: Immutable Artifact Promotion", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-8", "section": "governance", "claim": "ADR: ADR 0013: Human Gates Are Durable Workflow States", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-9", "section": "governance", "claim": "ADR: ADR 0014: Durable Execution Coordinator Glues One Provider to the Workflow", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-9", "section": "governance", "claim": "ADR: ADR 0015: One Worker Execution = One Pinned, Isolated, Verified Workspace", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-10", "section": "governance", "claim": "ADR: ADR 0016: Durable Persistent Scheduler with Claim-CAS Job Queue", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-10", "section": "governance", "claim": "ADR: ADR 0017: PostgreSQL-Backed Stores and Read-Only Control-Plane Endpoints", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-11", "section": "governance", "claim": "ADR: ADR 0018: Per-Product Git Credentials", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-11", "section": "governance", "claim": "ADR: ADR 0019: Standing Policy Authorisations", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-12", "section": "governance", "claim": "ADR: ADR 0020: Defect Domain Model + Triage Lifecycle", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false},
    {"factId": "gov-12", "section": "governance", "claim": "ADR: ADR 0021: Design Defect Routing", "provenance": "observed", "maturity": "unknown", "evidenceRefs": [], "assumptionNote": null, "redacted": false}
  ]'
) ON CONFLICT DO NOTHING;

-- Insert human claims as baseline_fact rows
INSERT INTO baseline_fact (
  "factId", "baselineId", "section", claim, provenance, maturity, "evidenceRefsJson", "assumptionNote", redacted, "createdAt"
) VALUES 
  ('human-arch-1', 'bl-shipit-platform-1', 'architecture', 'ShipIt Platform is a self-hosted developer automation platform that lets one operator run many products by orchestrating agents, workers, and durable workflows.', 'human_provided', 'unknown', '["authored by operator on 2026-10-04"]', 'Authored by operator on 2026-10-04. Not machine-verified.', false, now()),
  ('human-gov-1', 'bl-shipit-platform-1', 'governance', 'All agent executions are durable, auditable, and require human gates for production promotion — no autonomous production changes.', 'human_provided', 'unknown', '["authored by operator on 2026-10-04"]', 'Authored by operator on 2026-10-04. Not machine-verified.', false, now()),
  ('human-env-1', 'bl-shipit-platform-1', 'environments', 'Local development uses Docker Compose with a seeded triage repository; production targets Kubernetes via OpenTofu.', 'human_provided', 'unknown', '["authored by operator on 2026-10-04"]', 'Authored by operator on 2026-10-04. Not machine-verified.', false, now()),
  ('human-tech-1', 'bl-shipit-platform-1', 'tech_stack', 'Core platform is Dart/Flutter; workers run on Linux/macOS with OpenCode ACP; scheduler uses PostgreSQL CAS job queue.', 'human_provided', 'unknown', '["authored by operator on 2026-10-04"]', 'Authored by operator on 2026-10-04. Not machine-verified.', false, now()),
  ('human-gap-1', 'bl-shipit-platform-1', 'known_gaps', 'Real OpenCode execution requires Google auth which is not yet configured; Anthropic fallback has insufficient credit.', 'human_provided', 'unknown', '["authored by operator on 2026-10-04"]', 'Authored by operator on 2026-10-04. Not machine-verified.', false, now()),
  ('human-dep-1', 'bl-shipit-platform-1', 'deployment', 'Artifacts are promoted via immutable artifact references bound to a verified baseline; no direct container push bypass.', 'human_provided', 'unknown', '["authored by operator on 2026-10-04"]', 'Authored by operator on 2026-10-04. Not machine-verified.', false, now());

-- Create the approval decision
INSERT INTO human_decision (
  "decisionId", "workItemId", "decisionType", status, question, "contextJson", "optionsJson", recommendation, blocking, "requestedAt", "updatedAt", "metadataJson"
) VALUES (
  'blappr-bl-shipit-platform-1',
  'product-baseline:shipit-platform',
  'product_decision',
  'pending',
  'Approve Product baseline bl-shipit-platform-1 (revision 1) for shipit-platform?',
  '{"workflowState": "baseline_review", "availableOptions": ["approve_baseline", "request_baseline_correction", "reject_baseline"]}',
  '[{"optionId": "approve_baseline", "label": "Approve baseline", "description": "Accept this exact baseline revision as the authoritative Product understanding.", "recommended": true}, {"optionId": "request_baseline_correction", "label": "Request correction", "description": "Send the baseline back for a new proposed revision; does not accept.", "recommended": false}, {"optionId": "reject_baseline", "label": "Reject baseline", "description": "Reject this proposed baseline; does not accept.", "recommended": false}]',
  'approve_baseline',
  true,
  now(),
  now(),
  '{"routing": "product_baseline_approval", "productId": "shipit-platform", "baselineId": "bl-shipit-platform-1", "baselineRevision": 1, "contentHash": "a0c6eee7881a52ab05e04c6c7a26b862877e804763ff35bcf7da51555c1c442d", "contentHashVersion": 3}'
);