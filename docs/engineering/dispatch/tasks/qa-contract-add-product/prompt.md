MANAGER: orchestrator-main
TASK_ID: qa-contract-add-product
TASK_TYPE: qa-contract
FEATURE: Add Product page UI implementation
AREA: control-plane/products
WORKTREE: /tmp/shipit-qa-contract-add-product
BRANCH: qa-contract/add-product
BASE_SHA: 693cfbc29e75
OWNED_PATHS:
  - (QA Contract output only)
READ_ONLY_PATHS:
  - /tmp/shipit-qa-contract-add-product/DESIGN_BRIEF_add_product.md
  - /tmp/shipit-qa-contract-add-product/DESIGN_REVISION_add_product.md
  - /tmp/shipit-qa-contract-add-product/DESIGN_DISCOVERY_add_product.md
  - apps/control_plane/lib/features/products/add_product_page.dart
  - apps/control_plane/lib/features/products/products_page.dart
  - apps/control_plane/lib/router.dart
  - AGENTS.md
PROHIBITED_PATHS:
  - apps/server/*
  - packages/*/test/*
  - apps/control_plane/test/*
  - apps/control_plane/lib/features/*/test/*
  - .dart_tool/*
  - build/*
ACCEPTANCE_CRITERIA:
  - QA Contract created covering the Add Product page
  - Defines acceptance criteria for desktop and mobile layouts
  - Specifies test strategy (unit, widget, golden tests)
  - Defines evidence standards and golden baselines
  - Specifies regression requirements
  - QA Contract frozen (RESULT: QA_CONTRACT_FROZEN)
VALIDATION_COMMANDS:
  - QA Contract review against Design Contract
ROUTING_CLASS: STANDARD

## Original request (verbatim)

+ Add a Product doesn't work on /products page. If the page isn't implemented yet use the penpot MCP to implement the necessary UI in high fidelity.

## Context and authoritative sources

- Product/requirement artifact: Penpot boards "BP · Add Product · Dark" (b5b63334-c22a-80a6-8008-a998ffed44a5), "BP · Add Product · Light" (b5b63334-c22a-80a6-8008-a9a8f06e3586), "BPM · Add Product · Dark" (b5b63334-c22a-80a6-8008-a9ac5f5ad2dc), "BPM · Add Product · Light" (b5b63334-c22a-80a6-8008-a9ad42be419b)
- Architecture / repository rules: AGENTS.md, AGENTS.md §4 Testing Requirements, AGENTS.md §8 Forbidden Patterns
- Design Contract / approved design revision ref: DESIGN_REVISION_add_product (Revision 1, corrected round 2, APPROVED)
- QA Contract ref: n/a (this task creates it)
- ADRs / recorded decisions that apply: AGENTS.md §13 Penpot credentials, ADR 0018 (git credentials)
- Dependencies that must already be merged: design-produce-add-product (COMPLETED), design-review-add-product (COMPLETED), design-correct-add-product (COMPLETED), design-re-review-add-product (COMPLETED), design-correct-2-add-product (COMPLETED), design-re-review-2-add-product (COMPLETED with DESIGN_REVIEW_APPROVED)
- Other lanes currently running: none
- Work this lane blocks: implement-add-product
- Open Human Decision ids this lane depends on: none

## Acceptance criteria

- [ ] QA Contract created with all required sections
- [ ] Acceptance criteria traceable to Design Contract elements
- [ ] Test strategy defined (unit, widget, golden)
- [ ] Evidence standards specified
- [ ] Golden baselines identified
- [ ] Regression requirements specified

## Required validation commands

- [ ] QA Contract review against Design Contract

## Hard rules for the child

- Write only inside OWNED_PATHS; never touch PROHIBITED_PATHS.
- Do not commit or push unless the prompt explicitly instructs it and repository policy authorizes it.
- Do not approve your own work. Reviewer lanes never modify production code.
- Stop and report rather than resolving a product, architecture, security, infrastructure, destructive-operation, or deployment-authority question yourself; it is a HUMAN_DECISION_REQUIRED blocker.
- Every result carries exact repository/worktree/HEAD provenance.

## Cleanup before returning

- [ ] Stop every server, watcher, or stub process you started; report any port/PID left running.
- [ ] Remove temporary build/download artifacts outside the project's declared evidence directory.
- [ ] Leave the worktree's tracked files clean and committed, matching the reported HEAD_SHA.

## Report format

Return a report conforming to subtask-report.md. It must be parseable without reading conversational prose, and must include the mandatory header, files touched, validation results, documentation updated, unresolved issues, the model/reasoning effort actually used, and a recommended next action.

The report's RESULT: is your own agent file's token, copied verbatim — not an envelope status, and not a value you choose. You never emit an envelope status; the Manager normalizes your token into one using the table in subtask-report.md § Result normalization. For review lanes, CORRECTION_REQUIRED and HUMAN_DECISION_REQUIRED are likewise your agent's fields, not new tokens. Do not invent tokens, and do not add a VERDICT field — the report template defines none.