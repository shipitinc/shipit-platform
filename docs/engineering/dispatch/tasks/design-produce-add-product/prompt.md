MANAGER: orchestrator-main
TASK_ID: design-produce-add-product
TASK_TYPE: design-produce
FEATURE: Add Product page UI implementation
AREA: control-plane/products
WORKTREE: /tmp/shipit-design-add-product
BRANCH: design/add-product
BASE_SHA: 693cfbc29e75
OWNED_PATHS:
  - apps/control_plane/lib/features/products/add_product_page.dart
READ_ONLY_PATHS:
  - apps/control_plane/lib/shared/design_primitives.dart
  - apps/control_plane/lib/shared/form_primitives.dart
  - apps/control_plane/lib/shared/mobile_chrome.dart
  - apps/control_plane/lib/shared/state_views.dart
  - apps/control_plane/lib/core/design_tokens.dart
  - apps/control_plane/lib/core/theme.dart
  - apps/control_plane/lib/features/products/products_page.dart
  - apps/control_plane/lib/router.dart
PROHIBITED_PATHS:
  - apps/server/*
  - packages/*/test/*
  - apps/control_plane/test/*
  - apps/control_plane/lib/features/*/test/*
  - .dart_tool/*
  - build/*
ACCEPTANCE_CRITERIA:
  - Design Brief created covering all Penpot "BP · Add Product · Dark/Light" and "BPM · Add Product · Dark/Light" boards
  - Design Revision produced for desktop and mobile breakpoints
  - Design Contract frozen after Independent Design Review approval
  - QA Contract defined in parallel
VALIDATION_COMMANDS:
  - cd /tmp/shipit-design-add-product && dart analyze apps/control_plane/lib/features/products/add_product_page.dart
  - cd /tmp/shipit-design-add-product && dart format --set-exit-if-changed apps/control_plane/lib/features/products/add_product_page.dart
ROUTING_CLASS: STANDARD

## Original request (verbatim)

+ Add a Product doesn't work on /products page. If the page isn't implemented yet use the penpot MCP to implement the necessary UI in high fidelity.

## Context and authoritative sources

- Product/requirement artifact: Penpot boards "BP · Add Product · Dark" (b5b63334-c22a-80a6-8008-a998ffed44a5), "BP · Add Product · Light" (b5b63334-c22a-80a6-8008-a9a8f06e3586), "BPM · Add Product · Dark" (b5b63334-c22a-80a6-8008-a9ac5f5ad2dc), "BPM · Add Product · Light" (b5b63334-c22a-80a6-8008-a9ad42be419b)
- Architecture / repository rules: AGENTS.md, AGENTS.md §3 Package Boundaries, AGENTS.md §8 Forbidden Patterns
- Design Contract / approved design revision ref: n/a (this is the initial design production)
- QA Contract ref: n/a (to be created in parallel by qa-architect)
- ADRs / recorded decisions that apply: ADR 0018 (git credentials per repository), AGENTS.md §13 Penpot credentials
- Dependencies that must already be merged: none (base is main at 693cfbc)
- Other lanes currently running: none
- Work this lane blocks: implement-add-product, review-add-product
- Open Human Decision ids this lane depends on: none

## Acceptance criteria

- [ ] Design Brief produced describing the Add Product page structure, form fields, deploy key display, step panel, and mobile layout
- [ ] Design Revision produced for desktop (1280px) and mobile (390px) matching Penpot exactly
- [ ] Independent Design Review completed with RESULT: DESIGN_REVIEW_APPROVED
- [ ] Design Contract frozen and ready for implementation
- [ ] QA Contract defined in parallel

## Required validation commands

- [ ] cd /tmp/shipit-design-add-product && dart analyze apps/control_plane/lib/features/products/add_product_page.dart — must pass with no errors
- [ ] cd /tmp/shipit-design-add-product && dart format --set-exit-if-changed apps/control_plane/lib/features/products/add_product_page.dart — must pass
- [ ] Runtime/browser check — evidence must correspond to exact HEAD_SHA

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

Return a report conforming to subtask-report.md (this directory). It must be parseable without reading conversational prose, and must include the mandatory header, files touched, validation results, documentation updated, unresolved issues, the model/reasoning effort actually used, and a recommended next action.

The report's RESULT: is your own agent file's token, copied verbatim — not an envelope status, and not a value you choose. You never emit an envelope status; the Manager normalizes your token into one using the table in subtask-report.md § Result normalization. For review lanes, CORRECTION_REQUIRED and HUMAN_DECISION_REQUIRED are likewise your agent's fields, not new tokens. Do not invent tokens, and do not add a VERDICT field — the report template defines none.