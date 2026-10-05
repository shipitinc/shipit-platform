# Design Brief: Add Product Page Fixes

**Brief ID**: DESIGN_BRIEF_add_product_fixes  
**Version**: 1.0.0  
**Status**: DRAFT  
**Created**: 2026-10-05  
**Author**: Engineering Manager / Orchestrator

---

## Problem Statement

The Add Product page has several issues affecting usability and correctness:

1. **Duplicate "Show technical details"**: The `_DesktopAddProduct._buildFooter()` renders an `InlineLink` with "Show technical details" that does nothing (`onTap: () {}`), while the `TechnicalDetails` widget already has its own toggle button. This creates a confusing duplicate UI element.

2. **Register product button stays disabled**: The Register button remains disabled even when all fields appear populated. The `canRegister` getter requires `accessStatus == AccessStatus.verified`, which means users must complete the deploy key flow (generate key → install in repo → check access). There's no clear validation feedback explaining why the button is disabled.

3. **Missing favicon**: The web app lacks a favicon. The shipit logomark (26x26 PNG) exists at `apps/control_plane/assets/brand/logomark.png` but isn't referenced in `web/index.html`.

4. **Test products in local instance**: Test products created during development persist in the local QA environment, polluting the product registry. Need a separate test environment with documentation.

---

## User Flows

### Flow 1: Add Product - Technical Details Toggle
**Current**: User sees two "Show technical details" links - one in footer (non-functional) and one in TechnicalDetails widget (functional).
**Desired**: Only the TechnicalDetails widget's toggle should be visible.

### Flow 2: Add Product - Register Button Validation
**Current**: User fills fields, but Register button stays disabled without explanation. User must complete deploy key flow (generate → install → verify) before button enables.
**Desired**: Clear validation feedback showing what's missing (product name, repository, deploy key verification).

### Flow 3: Favicon
**Current**: No favicon in browser tab.
**Desired**: ShipIt logomark (26x26) as favicon.

### Flow 4: Test Environment Isolation
**Current**: Test products from development/testing persist in local QA database.
**Desired**: Separate test environment with dedicated script and documentation.

---

## Success Criteria

| ID | Criterion | Measurement |
|----|-----------|-------------|
| SC-01 | No duplicate "Show technical details" in Add Product page | Only one toggle visible (from TechnicalDetails widget) |
| SC-02 | Register button shows clear validation feedback | Button tooltip or inline text explains what's missing |
| SC-03 | Favicon appears in browser tab | ShipIt logomark visible in browser tab |
| SC-04 | Test environment script exists and documented | `make test-env-up` / `make test-env-down` with docs |

---

## Constraints

| ID | Constraint | Type | Notes |
|----|------------|------|-------|
| C-01 | Must use existing shipit logomark (26x26 PNG) | Technical | Already at `apps/control_plane/assets/brand/logomark.png` |
| C-02 | TechnicalDetails widget must remain unchanged | Technical | Used across multiple screens |
| C-03 | Register button validation must follow existing design patterns | Design | Use existing `InlineLink`, `MicroLabel`, `DesignPanel` patterns |
| C-04 | Test environment must use separate Docker Compose | Infrastructure | Separate volumes/network from QA |

---

## Acceptance Criteria

| ID | Acceptance Criterion | Traceability |
|----|---------------------|--------------|
| AC-01 | `_DesktopAddProduct._buildFooter()` removes duplicate InlineLink | SC-01 |
| AC-02 | Register button shows validation message when disabled | SC-02 |
| AC-03 | Favicon added to `web/index.html` using existing logomark | SC-03 |
| AC-04 | Test environment script `make test-env-up` / `make test-env-down` exists | SC-04 |
| AC-05 | Test environment documentation in `docs/deployment/test-environment.md` | SC-04 |

---

## Risk Assessment

| Risk | Level (0-3) | Rationale | Mitigation |
|------|-------------|-----------|------------|
| TechnicalDetails widget change affects other screens | 1 | We're NOT changing TechnicalDetails, only removing duplicate in Add Product | No change to shared widget |
| Favicon not loading due to path issues | 1 | Use absolute path `/assets/brand/logomark.png` | Test in browser |
| Test environment conflicts with QA | 2 | Use different ports/volumes | Separate compose file with different ports |

---

## Design System Compliance

**Status**: PASS

All changes use existing design tokens, components, and patterns:
- `InlineLink`, `MicroLabel`, `DesignPanel` for validation feedback
- Existing `ShipItType` typography tokens
- Existing `ShipItMetrics` spacing tokens
- Existing `ShipItPalette` color tokens

---

## UX / Accessibility Score

**Status**: PASS

- Validation feedback uses existing accessible patterns
- Favicon improves accessibility (identifiable tab)
- No new keyboard interactions introduced
- Color contrast maintained via existing palette

---

## Implementation Feasibility

**Status**: HIGH

- All changes are localized to specific files
- No new dependencies required
- Existing patterns can be followed
- Estimated effort: 2-3 implementation days

---

## Deviations from Penpot (Intentional)

| Deviation | Reason |
|-----------|--------|
| Adding validation feedback to Register button | Original design didn't specify disabled state feedback; this improves UX |
| Using logomark as favicon | Penpot didn't specify favicon; logomark is the brand identity |

---

## Testing Requirements

### Unit Tests
- AddProductBloc: validation logic for `canRegister` with various states
- AddProductBloc: error message generation

### Widget Tests
- AddProductPage: verify no duplicate "Show technical details"
- AddProductPage: verify Register button shows validation feedback
- TechnicalDetails: unchanged behavior

### Golden Tests
- Add Product page (desktop/mobile, light/dark) - verify no duplicate toggle
- Register button states (enabled/disabled with validation)

---

## Traceability Matrix

| Requirement | Design Spec Element | Implementation Location | Status |
|-------------|---------------------|------------------------|--------|
| Remove duplicate toggle | TechnicalDetails has own toggle | `_DesktopAddProduct._buildFooter()` | Planned |
| Register button validation | Form validation patterns | `AddProductState.canRegister` + UI | Planned |
| Favicon | Brand identity | `web/index.html` | Planned |
| Test environment | Infrastructure | `docker/compose.test.yaml`, `Makefile`, docs | Planned |

---

## Ready for Independent Design Review

**Yes** — All issues identified, solutions proposed, constraints documented, acceptance criteria defined.