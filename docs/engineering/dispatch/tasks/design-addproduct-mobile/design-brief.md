# Design Brief — Add Product mobile state boards + layout/copy corrections

Per `docs/engineering/DESIGN_GOVERNANCE.md` § *Artifacts → Design Brief Required Fields*.

```yaml
brief_id: 52CB4098-FF87-4B78-81DA-1104269551A1
version: 1.0.0
status: UNDER_REVIEW          # Gate D1 pending; not yet human-approved
requirements_refs:
  - R1   # author the four mobile state boards
  - R2   # human point 2e — button label + helper below
  - R3   # human point 2f — footer
  - R4   # required-field convention, re-grounded on production
  - R5   # accessibility contrast token correction
  - R6   # visual consequence of human points 2a/2b/2c
  - R7   # traceability and risk
architecture_refs:
  - HUMAN-73097d48           # PRODUCT / RESOLVED / OPTION_A — real deploy-key generation; folded the parked register-button round into this item
  - HUMAN-b869ec24           # ARCHITECTURE / RESOLVED / OPTION_A — server-side keypair generation + storage; API returns only the public half
  - HUMAN-048f3367           # security posture — read to avoid asserting a guarantee the product does not make
  - HUMAN-570bb640           # security posture — read to avoid asserting a guarantee the product does not make
created_by: design-agent
created_at: 2026-10-06T09:29:47Z
approved_by: null             # Gate D2 not reached
approved_at: null
```

## Problem statement

The Add Product page exists in production (`apps/control_plane/lib/features/products/add_product_page.dart`,
1117 lines) but its mobile design does not. Penpot page `d8ac01df-6646-81d2-8008-a366c09aa9d3` carries
`BPM · Add Product · Light` and `… · Dark` (the 390x844 page) and four 1280x900 desktop boards
(`BP · Add Product · Light/Dark`, `S · Add Product · Unknown host · Light/Dark`,
`S · Add Product · Verified · Light/Dark`). **No `SM -` mobile board exists at any state or theme** —
verified against the live page: `boards.filter(name => /^SM -/.test(name))` returned `[]` before this lane,
against 156 boards.

Three defects make the built page disagree with its own design:

1. **The primary action's reason is inside the button on desktop and below it on mobile.** Human point 2e
   settles it: only `Register product` in the button, the helper below.
2. **The footer does not match the design.** The design carries one `Show technical details ▸` row;
   the build renders an additional `ContentRule` + copy line on desktop and a `note` line on mobile.
3. **The key copy is false by resolved architecture.** Every board and the code assert the private half
   "stays in the keychain" / "stays in this device's keychain"; decision `b869ec24` settled that
   generation **and** private-half storage are server-side behind an API that returns only the public half.

## Scope of this brief

Owned: four new mobile state boards, and the layout/copy specifications for human points 2e, 2f and the
*visual* consequence of 2a–2d. **Not owned:** the normative backend design, the `hostUnrecognised` state
machine and the meaning of "Check access" — those belong to sibling lane `design-addproduct-keyservice`.

## User flows

### Flow 1 — Register with an unrecognised host (entry: user taps Add a product)

| Step | User does | System shows |
|------|-----------|--------------|
| 1 | Enters product name, SSH repository URL, revision | 3 fields under the `(OPTIONAL)` convention (R4) |
| 2 | — | A deploy key exists for this product; only the **public** half is ever returned to the client |
| 3 | Taps `Copy key`, installs it on the host | `Check access` available |
| 4 | First contact with a host SHIP IT has never seen | `CONFIRM THIS HOST BEFORE CONNECTING` panel: the host fingerprint, and `Trust this host`. **No Cancel** (human 2d + addendum 2) |
| 5 | Taps `Trust this host` | Exit: host trusted; `Check access` re-runnable |
| 6 | Taps `Check access` | Exit: access verified → `Register product` enabled |

**Entry criteria:** `productName` and `repository` non-empty.
**Exit criteria:** either the host is trusted, or the user leaves via the back link `‹ Products`.
**Dead-end analysis (human addendum 2):** there is no Cancel on the trust panel, and none is needed —
`‹ Products` is always present at the top of the board, the product is not registered, and the key
persists server-side so the same product can be registered later and re-verified.

### Flow 2 — Register with a verified host (entry: user returns to Add a product with a verified host)

Steps 1–3 as above, then `Check access` reports verified. `Register product` is enabled; the helper
below it reads `Access verified — this product can be registered`.
**Exit criteria:** product created; navigation proceeds to the product detail route.

### Flow 3 — Register is blocked (entry: host not yet trusted)

The helper below the button states the action that enables it, read from the top of the design:
`Confirm the host above to enable Register product.`

## Success criteria

| Id | Measurable outcome | How verified |
|----|--------------------|--------------|
| SC-1 | Four boards exist at 390x844, named exactly as dispatched, each legible in both themes | Penpot board inventory + PNG export of each (see `penpot-board-evidence.md`) |
| SC-2 | No board asserts the private half lives on the device or in a browser keychain | Executable content audit over all four boards' text layers — 0 hits |
| SC-3 | Exactly one `Show technical details` row and exactly one `Register product` label per board | Same audit: count == 1 each |
| SC-4 | Every body/secondary text layer is ≥ 4.5:1 against its own surface in both themes | Ratios measured from `apps/control_plane/lib/core/design_tokens.dart` and cited per layer |
| SC-5 | Every board element maps to a named existing token or production primitive | Traceability matrix in `design-revision.md` |

## Constraints

**Technical.** Reuse `FormFieldSlot`, `formBoxDecoration`, `SingleLineInput`, `FormSelect`, `FieldPair`,
`FormSectionTitle`, `DesignPanel`, `ContentRule`, `InlineLink`, `MicroLabel`, `AccentTick`,
`MobileBackBar`, `MobilePrimaryButton`, `TechnicalDetails`, and the `liveRegion` precedent at
`state_views.dart:88-89`. No new production primitive is introduced by this design.

**Brand / design system.** Every colour is a `ShipItPalette` token at `design_tokens.dart:99-101` (light)
and `:120-122` (dark). Board geometry mirrors `BPM · Add Product · Light` exactly (field pitch 64px,
34px field boxes, 116px key panel, 358px content width, 16px gutter, 34px submit, 8px helper gap).

**Accessibility.** WCAG 2.1 AA (4.5:1 normal text, 3:1 large text/UI). Contrast figures are **measured**,
never estimated — see `design-revision.md` § Contrast ledger.

**Legal / security copy.** The boards must not claim an at-rest protection property the product has not
yet settled. One string is therefore explicitly parameterized (§ *Open design question*).

## Acceptance criteria

1. Four boards authored at 390x844 on page `d8ac01df-6646-81d2-8008-a366c09aa9d3`, named exactly
   `SM - Add Product - Unknown host - Light`, `… - Dark`, `SM - Add Product - Verified - Light`, `… - Dark`,
   each exported as evidence.
2. No existing board edited, renamed, moved or deleted — verified by before/after inventory and by
   position+name+child-count assertion on the four boards used as references.
3. Exactly one button/helper structure specified for desktop **and** mobile, with the button-height and
   desktop-gap consequences of moving the helper out stated.
4. Footer specified as exactly one `Show technical details` row, with expanded/collapsed behaviour.
5. All 15 `FormFieldSlot(` call sites classified under the **existing** `(OPTIONAL)` convention; no second
   convention introduced; the `DesignTextField` compile impact addressed explicitly.
6. `inkSecondary` specified with cited, measured ratios; no unmeasured contrast claim anywhere.
7. Traceability matrix present, gaps named.
8. `RISK_LEVEL` assigned with rationale; self-assessment fields filled or reported `UNKNOWN` with a reason.

## Risk assessment (initial)

`2` — Feature UX Change. See `design-revision-metadata.yaml` `risk_rationale` for the argument.

## Open design question (not defaulted by this lane)

The at-rest protection model for the server-held private half is an open human decision the human
explicitly told the Manager not to default. One board string depends on it and is marked
`PENDING D4 — parameterized on the at-rest protection model` in Penpot (layer `Art S · PENDING D4 (at-rest model)`).
The boards are otherwise drawn against the settled architecture and are complete; only that one string's
final wording is deferred to a single DCR after Gate D4.