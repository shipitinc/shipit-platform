MANAGER: orchestrator-main
TASK_ID: design-review-add-product
TASK_TYPE: design-review
FEATURE: Add Product page UI implementation
AREA: control-plane/products
WORKTREE: /tmp/shipit-design-review-add-product
BRANCH: design-review/add-product
BASE_SHA: 693cfbc29e75
OWNED_PATHS:
  - (read-only review)
READ_ONLY_PATHS:
  - /tmp/shipit-design-review-add-product/DESIGN_BRIEF_add_product.md
  - /tmp/shipit-design-review-add-product/DESIGN_REVISION_add_product.md
  - /tmp/shipit-design-review-add-product/DESIGN_DISCOVERY_add_product.md
  - apps/control_plane/lib/features/products/add_product_page.dart
  - apps/control_plane/lib/shared/design_primitives.dart
  - apps/control_plane/lib/shared/form_primitives.dart
  - apps/control_plane/lib/shared/mobile_chrome.dart
  - apps/control_plane/lib/shared/state_views.dart
  - apps/control_plane/lib/core/design_tokens.dart
  - apps/control_plane/lib/core/theme.dart
PROHIBITED_PATHS:
  - apps/server/*
  - packages/*/test/*
  - apps/control_plane/test/*
  - apps/control_plane/lib/features/*/test/*
  - .dart_tool/*
  - build/*
ACCEPTANCE_CRITERIA:
  - Independent Design Review completed per aef-design-review skill
  - Verify design system compliance (tokens, primitives, metrics)
  - Verify UX/accessibility (contrast, focus, keyboard, screen readers)
  - Verify implementation feasibility
  - Verify traceability to Penpot boards
  - Determine risk level and DCR requirement
VALIDATION_COMMANDS:
  - cd /tmp/shipit-design-review-add-product && cat DESIGN_REVISION_add_product.md
  - cd /Users/alkebut/air/shipit-platform && dart analyze apps/control_plane/lib/features/products/add_product_page.dart
ROUTING_CLASS: STANDARD

## Original request (verbatim)

+ Add a Product doesn't work on /products page. If the page isn't implemented yet use the penpot MCP to implement the necessary UI in high fidelity.

## Context and authoritative sources

- Product/requirement artifact: Penpot boards "BP · Add Product · Dark" (b5b63334-c22a-80a6-8008-a998ffed44a5), "BP · Add Product · Light" (b5b63334-c22a-80a6-8008-a9a8f06e3586), "BPM · Add Product · Dark" (b5b63334-c22a-80a6-8008-a9ac5f5ad2dc), "BPM · Add Product · Light" (b5b63334-c22a-80a6-8008-a9ad42be419b)
- Architecture / repository rules: AGENTS.md, AGENTS.md §2 Dart Conventions, AGENTS.md §8 Forbidden Patterns
- Design Contract / approved design revision ref: DESIGN_REVISION_add_product (Revision 1)
- QA Contract ref: n/a (to be created in parallel by qa-architect)
- ADRs / recorded decisions that apply: ADR 0018 (git credentials per repository), AGENTS.md §13 Penpot credentials
- Dependencies that must already be merged: design-produce-add-product (COMPLETED)
- Other lanes currently running: none
- Work this lane blocks: implement-add-product, review-add-product
- Open Human Decision ids this lane depends on: none

## Acceptance criteria

- [ ] Design Review completed with verdict: APPROVED / CHANGES_REQUIRED / HUMAN_DECISION_REQUIRED
- [ ] Risk level assessed (0-3) with rationale
- [ ] DCR requirement determined
- [ ] Design system compliance verified
- [ ] UX/accessibility verified
- [ ] Implementation feasibility assessed

## Required validation commands

- [ ] cd /Users/alkebut/air/shipit-platform && dart analyze apps/control_plane/lib/features/products/add_product_page.dart — must pass
- [ ] Design review checklist per aef-design-review skill

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