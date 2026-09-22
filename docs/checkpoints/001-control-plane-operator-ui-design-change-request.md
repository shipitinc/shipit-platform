# Design Change Request — DCR-001

| Field | Value |
|---|---|
| **DCR ID** | `DCR-001` |
| **Feature ID** | `CONTROL_PLANE_OPERATOR_UI_001` |
| **Date raised** | 2026-09-15 |
| **Raised by** | Human operator (design authority / QA approver) |
| **Against** | `docs/checkpoints/001-control-plane-operator-ui-design-approval.md` (revision frozen IMPLEMENTATION_AUTHORITATIVE 2026-09-14) |
| **Status** | **RESOLVED — `SELECT_B`** (human, 2026-09-15) |
| **Gate** | `VISUAL_DIRECTION_APPROVAL_REQUIRED` — **resolved** |

> ## HUMAN DECISION RECORDED: `SELECT_B`
>
> **Direction B — Precision Engineering — is the authoritative visual direction.**
> Recorded 2026-09-15 by the human design authority.
>
> **`DCR-AC-4` caveat, stated plainly:** the post-correction independent
> re-review was **not** performed before this selection. The original independent
> review (study §8) did cover B and scored it 56/80 (second, 1 point behind C),
> and B's corrections were data/semantic/contrast fixes rather than
> restructuring — so that review substantially still applies to B. But the
> selection was made without the re-review, and this record says so rather than
> implying a review that did not happen.
>
> Directions C and D are **not** adopted. They remain in the file as historical
> exploration artifacts (§8 lineage), are not deleted, and carry no authority.

---

## 1. HUMAN QA OUTCOME

The Human QA package (`001-control-plane-operator-ui-human-qa.md`) offered
exactly three allowed human outcomes: `APPROVE`, `REJECT`,
`REQUEST_DESIGN_CHANGE`.

**FORMAL OUTCOME RECORDED: `REQUEST_DESIGN_CHANGE`.**

This is the human's decision on the Human QA gate `HUMAN_QA_REQUIRED`. It is
neither `APPROVE` (the slice is not complete) nor `REJECT` (nothing built is
being discarded). The feature remains in flight; the *design input* to the
feature is what is being re-opened.

---

## 2. CLASSIFICATION

| Classification | Applies |
|---|---|
| `DESIGN_DEFECT` / `DESIGN_DIRECTION_CHANGE` | **YES** |
| `IMPLEMENTATION_DEFECT` | **NO** |

This DCR is classified as a **design defect / design direction change**, and
explicitly **NOT** an implementation defect.

The implementation **faithfully represents the previously approved design**.
The Flutter control-plane app renders the palette, layout, information
density and component composition that were approved in the 2026-09-14
design-approval record. Visual fidelity to the approved boards is not in
dispute and is not the complaint.

The complaint is about **the approved design itself**: it is no longer
considered sufficient. The design was approved, was built correctly, and the
human — on seeing it running — judges the *design direction* to be below the
bar for ShipIt. That judgement is a legitimate outcome of a human QA gate:
approval of a design is a point-in-time decision, and a later human may find
the approved direction inadequate without that implying anyone implemented it
wrongly.

**One implementation defect was found during this feature's QA cycle and is
already fixed:** status wire-value mapping used `'running'` / `'success'` /
`'failed'` instead of the `platform_contracts` snake_case wire values
`'agent_executing'` / `'completed'` / `'agent_failed'`. That defect is
**FIXED** and is recorded here only to make clear it is *not* the subject of
this DCR. No open implementation defect motivates this DCR.

---

## 3. RATIONALE

The current control-plane visual language **lacks the distinctive product
identity, refinement, and visual quality desired for ShipIt.**

Concretely, as a design judgement (not an implementation finding):

- **Product identity:** the surfaces read as a generic dark operations
  dashboard rather than as *ShipIt*. Nothing about the visual language is
  recognisably the product.
- **Refinement:** the composition — spacing rhythm, type hierarchy, card
  treatment, chip/badge treatment — is serviceable but unremarkable. The
  earlier revision history (centering fixes, contrast fixes, palette
  substitutions) shows the direction was arrived at by successive local
  corrections rather than from a coherent visual system.
- **Visual quality:** the result does not carry the level of craft expected
  of the first operator-facing ShipIt surface, which sets the visual
  precedent for every subsequent product surface.

This is a direction-level concern. It cannot be resolved by further
incremental fixes to the existing boards, which is why a new exploration is
requested rather than another revision of the frozen design.

---

## 4. WHAT IS PRESERVED

Nothing is deleted. All artifacts below are retained as **historical
artifacts** with their historical status intact.

| Artifact | Disposition |
|---|---|
| Penpot dark boards (approved 2026-09-14) | **PRESERVED** — see IDs below |
| Penpot light boards (approved 2026-09-14) | **PRESERVED** — see IDs below |
| `001-control-plane-operator-ui-design-approval.md` | **PRESERVED** — remains a true record of a real approval |
| `001-control-plane-operator-ui-planning.md` | **PRESERVED** — requirement + QA contract still stand |
| `001-control-plane-operator-ui-human-qa.md` | **PRESERVED** — QA evidence record |
| Flutter implementation (`apps/control_plane/`) | **PRESERVED** — running, tested, not reverted |
| Server endpoints (`home_endpoints.dart`, `workflow_endpoints.dart`) | **PRESERVED** |
| Screenshots / golden baselines (8 golden tests) | **PRESERVED** as the baseline of the current direction |
| QA evidence (E2E, BLoC, widget, responsive, accessibility results) | **PRESERVED** |
| Independent design review (2026-09-14, verdict APPROVED) | **PRESERVED** |

**Penpot surface (unchanged):**

- Team `c828d3cf-7d4e-8145-8008-98dfd6576a0c`
- File `d8ac01df-6646-81d2-8008-a366c09aa9d3`
- Page `d8ac01df-6646-81d2-8008-a366c09aa9d3`

**Existing approved boards (preserved, not deleted, not overwritten):**

| Board | Dark (approved) | Light (approved) |
|---|---|---|
| Home | `26213ee5-8af7-8000-8008-a369e295bbc4` | `d5d957b2-7438-8011-8008-a3e736c5bde0` |
| Runs | `26213ee5-8af7-8000-8008-a36b4fe4e7dc` | `d5d957b2-7438-8011-8008-a3e88141e31a` |
| Run Detail | `26213ee5-8af7-8000-8008-a36b7d04d351` | `d5d957b2-7438-8011-8008-a3e881ce68b5` |
| Needs You | `26213ee5-8af7-8000-8008-a36b90375a7b` | `d5d957b2-7438-8011-8008-a3e8826ef4cc` |
| Decision Detail | `26213ee5-8af7-8000-8008-a36bafa46126` | `d5d957b2-7438-8011-8008-a3e8830f0d1e` |

**History is not rewritten.** The 2026-09-14 approval remains a real
historical fact: a human did approve that revision, an independent review did
pass it, and the implementation did honour it. This DCR does not retroactively
invalidate that approval, does not mark it as fabricated, and does not
recharacterise it as a mistake by the implementer. It supersedes it *going
forward only*, and only if and when a new direction is human-selected under
§12.

**Implementation state.** The implementation is functionally complete and
stays that way while this DCR is open: 7/7 E2E tests against real PostgreSQL
pass, 19 BLoC tests, 4 widget tests, 3 responsive tests, 5 accessibility
tests, 8 golden tests, and `format` + `analyze` are clean. No code is reverted
by this DCR.

---

## 5. WHAT REMAINS AUTHORITATIVE

The following remain **unchanged and authoritative** unless the design
exercise under this DCR positively proves otherwise (and any such proof would
itself require its own human gate, not designer discretion):

| Authoritative item | Source of truth |
|---|---|
| **Information architecture** — Home, Runs, Run Detail, Needs You, Decision Detail | planning §10–§12 |
| **`HumanDecision` semantics** — durable row, `options`/`recommendation`/`context`, pending+blocking definition, signature-bearing resolution | `platform_contracts`; AGENTS §11 |
| **Same-`WorkItem` resume semantics** — resolving a decision resumes the SAME `WorkItem` (no clone, no new id) | planning AC-5; E2E test 7 |
| **API contracts** — read-only reads + the single sanctioned write `workflowEndpoints.resolveDecision`; no endpoint sets `WorkItem.state` | planning §8; AGENTS §3 |
| **Accessibility requirements** — semantic labels on status/decision/summary surfaces, keyboard-reachable decision options, colour never the only signal | planning §14; 5 accessibility tests |
| **Responsive requirements** — desktop ≥ 840px NavigationRail, < 840px bottom NavigationBar, mutual exclusion; **840px breakpoint** | human-qa "RESPONSIVE EVIDENCE"; 3 responsive tests |
| **AEF authority model** — design authority is Penpot, approval is human, review is independent of the author, no self-approval | AGENTS §13; planning §19 |

A new visual direction must land *inside* these constraints. A direction that
requires changing any row above is out of scope for this DCR.

---

## 6. SCOPE OF REQUESTED CHANGE

**IN SCOPE: VISUAL DIRECTION / PRODUCT IDENTITY ONLY.**

- Palette and colour system (including how dark and light relate)
- Typographic hierarchy and scale
- Surface/elevation/card and chip/badge treatment
- Spacing rhythm and density
- Iconography and status expression
- The overall character that makes the surface identifiably ShipIt

This is **not** a wholesale product replanning. The feature requirement, the
acceptance criteria (AC-1…AC-8), the QA contract and the durable-state model
are not re-opened. The screens stay the same screens; what changes is how
they look and what they say about the product.

---

## 7. OUT OF SCOPE

Explicitly **not** changed by this DCR:

1. **Changing the information architecture** — the five surfaces and their
   navigation relationships stay as approved.
2. **Changing workflow semantics** — `WorkItemState` machine, transition
   rules, `HumanDecision` lifecycle, same-`WorkItem` resume.
3. **Changing the single-write-path rule** — `resolveDecision` remains the
   only mutation the UI can trigger; the UI never writes `WorkItem.state`.
4. **Changing API contracts** — no endpoint additions, removals or signature
   changes are authorised by this DCR.

Any proposal touching the above must be raised as a separate change, with its
own gate.

---

## 8. NEW REVISION LINEAGE

A **new design exploration lineage** is created under `DCR-001`. It is
additive and parallel:

- New exploration boards are created as **new boards**; they do **not**
  overwrite, edit, or delete the approved boards listed in §4.
- The approved revision stays labelled as the historical
  IMPLEMENTATION_AUTHORITATIVE revision until — and only until — a human
  selects a replacement direction under §12.
- Until that selection happens, the **currently implemented design remains
  the one in the product**. There is no interim state where the product has
  no authoritative design.
- The exploration lineage is explicitly labelled as *exploration*, not as
  approved design, for as long as this DCR is `OPEN`.

---

## 9. ACCEPTANCE CRITERIA FOR THIS DCR

| ID | Criterion |
|---|---|
| **DCR-AC-1** | **Three materially different directions produced.** At least three candidate visual directions (beyond keeping the current one) that differ in substance — palette system, type system, surface/density character — not three recolourings of the same layout. |
| **DCR-AC-2** | **Same representative screens across all directions.** Every direction is shown on the same representative screen set so they are comparable like-for-like. No direction may be shown only on its most flattering screen. |
| **DCR-AC-3** | **Light + dark proven for every direction.** Each direction demonstrates both a light and a dark treatment; neither is asserted as "derivable later". |
| **DCR-AC-4** | **Independent design review performed.** The directions are reviewed by a reviewer acting independently of the design-production step, per AGENTS §13 / planning §19. **Designer self-approval is not acceptable** and does not satisfy this criterion. |
| **DCR-AC-5** | **Human selects the direction.** A human records one of the allowed outcomes in §12. No direction becomes authoritative without that human selection. |

This DCR cannot be closed until DCR-AC-1 … DCR-AC-5 are all satisfied.

---

## 10. LINKED ARTIFACTS

| Artifact | Role | Note |
|---|---|---|
| Visual direction study | Produces the candidate directions required by DCR-AC-1 … DCR-AC-3 | Produced **separately in the same session**; referenced by this DCR, not contained in it |
| Independent design review of the directions | Satisfies DCR-AC-4 | Produced **separately in the same session**, by a reviewer independent of the direction author |
| `001-control-plane-operator-ui-design-approval.md` | Historical approved revision being superseded-if-replaced | Preserved (§4) |
| `001-control-plane-operator-ui-human-qa.md` | Origin of the `REQUEST_DESIGN_CHANGE` outcome | Preserved (§4) |
| `001-control-plane-operator-ui-planning.md` | Requirement, AC-1…AC-8, QA contract, IA | Still authoritative (§5) |

**This DCR makes no claim that the visual direction study is complete.** The
study and its independent review are separate artifacts; their completion is
evidenced in those documents, not asserted here.

---

## 11. RISKS AND CONSTRAINTS

- The implementation is already complete against the current direction.
  Selecting a new direction implies a re-skin scoped to presentation only;
  BLoC, repository, endpoint and durable-state code must not need to change.
  If a candidate direction would force such changes, that is a signal the
  direction has strayed outside §6.
- Golden baselines are tied to the current direction. A direction change
  invalidates golden *images*, not golden *coverage*; re-baselining requires
  human approval and must not be self-approved.
- Penpot must be genuinely connected to the named team/file before any board
  is created. Per AGENTS §13, a fabricated workspace, board, or shape count
  is prohibited; if Penpot is not connected, the study stops at the gate
  rather than inventing artifacts.

---

## 12. GATE

**`VISUAL_DIRECTION_APPROVAL_REQUIRED`**

Allowed human outcomes:

| Outcome | Meaning |
|---|---|
| `KEEP_CURRENT` | The existing approved direction stands; DCR-001 closes with no design change; implementation unchanged. |
| `SELECT_B` | Adopt candidate direction B as the new authoritative visual direction. |
| `SELECT_C` | Adopt candidate direction C as the new authoritative visual direction. |
| `SELECT_D` | Adopt candidate direction D as the new authoritative visual direction. |
| `REQUEST_HYBRID` | Adopt a named combination of candidate elements; requires a consolidated revision plus a new independent review before it becomes authoritative. |
| `REQUEST_NEW_DIRECTIONS` | None of the candidates is acceptable; a further exploration round is required under this same DCR. |

No outcome may be self-selected by the design author or by an agent. Until a
human records one of the above, `DCR-001` remains **OPEN** and the
2026-09-14 revision remains the implementation-authoritative design.
