MANAGER: orchestrator-main
TASK_ID: design-correct-add-product
TASK_TYPE: design-produce
FEATURE: Add Product page UI corrections
AREA: control-plane/products
WORKTREE: /tmp/shipit-design-correct-add-product
BRANCH: design-correct/add-product
BASE_SHA: 693cfbc29e75
OWNED_PATHS:
  - apps/control_plane/lib/features/products/add_product_page.dart
  - apps/control_plane/lib/core/design_tokens.dart
READ_ONLY_PATHS:
  - apps/control_plane/lib/shared/design_primitives.dart
  - apps/control_plane/lib/shared/form_primitives.dart
  - apps/control_plane/lib/shared/mobile_chrome.dart
  - apps/control_plane/lib/shared/state_views.dart
  - apps/control_plane/lib/core/design_tokens.dart
  - apps/control_plane/lib/core/theme.dart
  - /tmp/shipit-design-correct-add-product/DESIGN_BRIEF_add_product.md
  - /tmp/shipit-design-correct-add-product/DESIGN_REVISION_add_product.md
  - /tmp/shipit-design-correct-add-product/DESIGN_DISCOVERY_add_product.md
PROHIBITED_PATHS:
  - apps/server/*
  - packages/*/test/*
  - apps/control_plane/test/*
  - apps/control_plane/lib/features/*/test/*
  - .dart_tool/*
  - build/*
ACCEPTANCE_CRITERIA:
  - Fix all BLOCKERS from Independent Design Review (B1-B5, H1-H2)
  - B1: Desktop register button main label — remove explicit color, let FilledButton theme provide onPrimary
  - B2: Desktop register button sub-label — change inkPrimary to inkTertiary
  - B3: Key box tick — use palette.attentionTick (theme-aware) instead of hardcoded dark
  - B4: Key box visual — create KeyBoxPanel variant or custom decoration for "no fill, stroke controlBorder, radius 3"
  - B5: Right panel border — create RightPanel variant or custom decoration for theme-aware border (cardBorder dark / controlBorder light)
  - H1: Crumb typography — add crumb style to ShipItType (Mono 11/400) or use monoMeta.copyWith(fontSize: 11)
  - H2: InlineLink disabled state — unify desktop/mobile approach; add disabled visual state or guard consistently
  - All validation commands pass
VALIDATION_COMMANDS:
  - cd /tmp/shipit-design-correct-add-product && dart analyze apps/control_plane/lib/features/products/add_product_page.dart
  - cd /tmp/shipit-design-correct-add-product && dart format --set-exit-if-changed apps/control_plane/lib/features/products/add_product_page.dart
  - cd /tmp/shipit-design-correct-add-project && dart analyze apps/control_plane/lib/core/design_tokens.dart
ROUTING_CLASS: STANDARD

## Original request (verbatim)

+ Add a Product doesn't work on /products page. If the page isn't implemented yet use the penpot MCP to implement the necessary UI in high fidelity.

## Context and authoritative sources

- Product/requirement artifact: Penpot boards "BP · Add Product · Dark" (b5b63334-c22a-80a6-8008-a998ffed44a5), "BP · Add Product · Light" (b5b63334-c22a-80a6-8008-a9a8f06e3586), "BPM · Add Product · Dark" (b5b63334-c22a-80a6-8008-a9ac5f5ad2dc), "BPM · Add Product · Light" (b5b63334-c22a-80a6-8008-a9ad42be419b)
- Architecture / repository rules: AGENTS.md, AGENTS.md §2 Dart Conventions, AGENTS.md §8 Forbidden Patterns
- Design Contract / approved design revision ref: DESIGN_REVISION_add_product (Revision 1, needs corrections)
- QA Contract ref: n/a (to be created in parallel by qa-architect)
- ADRs / recorded decisions that apply: ADR 0018 (git credentials per repository), AGENTS.md §13 Penpot credentials
- Dependencies that must already be merged: design-produce-add-product (COMPLETED), design-review-add-product (COMPLETED with CHANGES_REQUIRED)
- Other lanes currently running: none
- Work this lane blocks: design-re-review-add-product, implement-add-product
- Open Human Decision ids this lane depends on: none

## Acceptance criteria

- [ ] All 7 blockers (B1-B5, H1-H2) fixed in add_product_page.dart and design_tokens.dart
- [ ] Design system compliance maintained (only design tokens/primitives used)
- [ ] Dart analysis passes with zero errors
- [ ] Code formatting passes

## Required validation commands

- [ ] cd /tmp/shipit-design-correct-add-product && dart analyze apps/control_plane/lib/features/products/add_product_page.dart — must pass with no errors
- [ ] cd /tmp/shipit-design-correct-add-product && dart format --set-exit-if-changed apps/control_plane/lib/features/products/add_product_page.dart — must pass
- [ ] cd /tmp/shipit-design-correct-add-product && dart analyze apps/control_plane/lib/core/design_tokens.dart — must pass
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

Return a report conforming to subtask-report.md. It must be parseable without reading conversational prose, and must include the mandatory header, files touched, validation results, documentation updated, unresolved issues, the model/reasoning effort actually used, and a recommended next action.

The report's RESULT: is your own agent file's token, copied verbatim — not an envelope status, and not a value you choose. You never emit an envelope status; the Manager normalizes your token into one using the table in subtask-report.md § Result normalization. For review lanes, CORRECTION_REQUIRED and HUMAN_DECISION_REQUIRED are likewise your agent's fields, not new tokens. Do not invent tokens, and do not add a VERDICT field — the report template defines none.