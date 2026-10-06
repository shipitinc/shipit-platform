# Subtask Prompt — design-addproduct-mobile

Persisted per `aef-orchestrator` §14 **before** launch. Rendered from
`.agents/skills/aef-orchestrator/templates/subtask-prompt.md`, every key filled.

## Mandatory header

```yaml
MANAGER: orchestrator-main
TASK_ID: design-addproduct-mobile
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — four missing SM mobile boards + layout/copy corrections (points 2e-2f, 2a UI cues)
AREA: Penpot mobile boards for Add Product; form layout, button and footer copy
WORKTREE: /private/tmp/shipit-design-addproduct-mobile
BRANCH: design/addproduct-mobile
BASE_SHA: 77c19f1
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**
  - Penpot page d8ac01df-6646-81d2-8008-a366c09aa9d3 — boards you create:
      - SM - Add Product - Unknown host - Light
      - SM - Add Product - Unknown host - Dark
      - SM - Add Product - Verified - Light
      - SM - Add Product - Verified - Dark
READ_ONLY_PATHS:
  - apps/control_plane/lib/features/products/add_product_page.dart
  - apps/control_plane/lib/features/**
  - apps/control_plane/lib/shared/**
  - docs/engineering/**
  - AGENTS.md
  - .decisions/**
PROHIBITED_PATHS:
  - apps/control_plane/lib/**          (production source — you design it, you do not write it)
  - apps/server/**                     (production source; the sibling lane owns the server design)
  - packages/**
  - docker/**                          (see hard rule: no Docker command may be executed)
  - .github/workflows/**
  - .decisions/**                      (Manager-owned)
  - docs/engineering/WORK_STATE.md     (Manager-owned)
  - docs/engineering/dispatch/LANES.md (Manager-owned)
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**  (the other lane's artifacts)
  - ANY Penpot board that is not one of the four named above — including every existing
    `BPM -`/`DESKTOP -`/`SM -` board. You READ them; you never edit or delete them.
ACCEPTANCE_CRITERIA: |
  A Design Brief (Gate D1-ready) plus a Design Revision (Gate D3-ready) covering exactly:
  (1) four authored mobile boards at 390x844 — Unknown host and Verified, Light and Dark;
  (2) layout and copy corrections implementing human points 2a-2f, re-grounded on the
      conventions that already exist in production.
  Artifacts must trace to the resolved Human Decisions, every board element must map to a named
  existing production primitive or design token, and the revision must carry an honest
  `RISK_LEVEL` assessment.
VALIDATION_COMMANDS:
  - cd /private/tmp/shipit-design-addproduct-mobile && git branch --show-current   # must print design/addproduct-mobile
  - cd /private/tmp/shipit-design-addproduct-mobile && git rev-parse --short HEAD  # must print 77c19f1
  - grep -rn "OPTIONAL" apps/control_plane/lib/features/defects/create_defect_page.dart   # the required-field convention that already exists
  - grep -rn "inkTertiary\|inkSecondary\|inkPrimary" apps/control_plane/lib/shared/design_tokens.dart   # the a11y token correction
  - grep -rn "Show technical details\|_registerButtonSubtext\|FormFieldSlot" apps/control_plane/lib   # primitives and the missing footer widget
ROUTING_CLASS: STANDARD
```

## Isolation pre-flight (run this first)

```bash
cd /private/tmp/shipit-design-addproduct-mobile
git branch --show-current    # must equal design/addproduct-mobile
git rev-parse HEAD           # must equal 77c19f1
```

If either check fails, STOP and report `RESULT: DESIGN_REVISION_BLOCKED` with the observed
values. Do not write anything.

## Original request (verbatim)

The human's work item, verbatim:

> 1. It looks like we're missing mobile designs for these screens
> 2. It looks like our implementation agent failed in it's implementation of these designs in that:
>    a. The UI seems to indicate the Add a product page should generate a key on Repository SSH URL input
>    b. And that Register product is dependent on upon this key generation and trust of this host before product creation
>    c. It's not documented what Check access is supposed to do
>    d. Design allows for cancelling the trust this host operation, but I don't think we want to allow that b/c it causes us to get stuck and unable to register
>    e. Only "Registers product" is supposed to be in the button. The helper text goes below and according to the design seems to indicate starting with the top what the user must do to enable the Register product button.
>    f. Furthermore there's no copy at the bottom and only one footer line according to the design for Add a product. There's only a Show technical details widget down there.
>
> Using the penpot design add mobile light and dark counterparts to penpot for the add product page and implement the Add Product page correctly in SHIP IT.

Human addenda, verbatim:

> 1. We should have an API for private-key creation and storage. B/c we won't be git pushing in SHIP IT from the web browser from it's backend correct. This should settle your issue there.
> 2. Even if we remove cancel from the key flow we can always just go back to teh products page. We're not blocked, and if when down the road we want to create that product we'll find the key on the machine ready to be verified again.

**This lane owns points 2e and 2f, the four missing boards, and the *visual* consequences of
2a/2b/2c/2d.** The normative backend and state-machine design for 2a–2d belongs to the sibling
lane `design-addproduct-keyservice`. Read § "Sibling lane coupling" below before designing copy.

## Manager correction to a previously recorded VERIFIED FACT — affects your copy, not your boards

The Penpot boards assert the deploy key is *"ed25519 · created on this device · the private half
stays in the keychain"*. **That claim is now false by resolved Human Decision.** Decision
`b869ec24` (ARCHITECTURE, OPTION_A) settled that keypair generation and private-half storage are
**server-side**, behind an API that returns only the public half, because SHIP IT pushes from its
own backend and never from the browser. Decision `73097d48` recorded exactly this concern:
*"the boards assert 'the private half stays in the keychain', which a Flutter web build cannot
literally honour — the design must state what actually happens rather than reuse the claim."*

Your boards must not say "this device" or "the keychain" about the private half. Correcting this
copy is an explicit follow-up action of `b869ec24`. See § "Sibling lane coupling" for the one
string you must leave parameterized.

## Context and authoritative sources

- Human Decisions (all RESOLVED — read them, do not re-open):
  - `.decisions/73097d48-3e8b-48d7-b3d8-8834168c5113.yaml` — PRODUCT, OPTION_A: real deploy-key
    generation; folded the parked register-button round into this work item. Its follow-up
    actions include authoring these very four boards.
  - `.decisions/b869ec24-236e-4e9c-8703-70656fa368c4.yaml` — ARCHITECTURE, OPTION_A: server-side
    generation and storage; correct the board copy that implies browser storage.
  - `.decisions/048f3367-5836-43c8-af05-747dbc9d3afd.yaml`, `.decisions/570bb640-76e1-485d-9a80-309b07585ccd.yaml`
    — security posture. Not directly yours; they matter only so you do not assert a guarantee the
    product does not yet make.
- Parked prior review whose blockers are folded into this scope:
  `docs/engineering/dispatch/tasks/design-register-button/report.md` — **B1** and **B2**
  (the required-field convention already exists and its coverage is 15 call sites, not 8),
  **H1** (the a11y contrast justification is numerically false), **H2/H3** (desktop gap
  unspecified; SC-05's verification is vacuous), and traceability gaps 5 and 6.
- Penpot: page `d8ac01df-6646-81d2-8008-a366c09aa9d3` (page name `Page 1`). Read
  `penpot_high_level_overview` before using Penpot tools. The grammar to follow is the existing
  board `BPM - Add Product - Light` at 390x844.
- Client code under design: `apps/control_plane/lib/features/products/add_product_page.dart`
  (1117 lines; desktop and mobile variants).
- Design primitives that already exist and must be reused — verified present by the prior review,
  with no name collisions: `FormFieldSlot`, `formBoxDecoration`, `SingleLineInput`, `FormSelect`,
  `FieldPair`, `FormSectionTitle`, and the `liveRegion` precedent at `state_views.dart:88-89`.
- Design Contract ref: `n/a`. QA Contract ref: `n/a`.
- Dependencies already merged: everything on `main` @ `77c19f1`.
- Other lane currently running, and its OWNED_PATHS: **`design-addproduct-keyservice`**, branch
  `design/addproduct-keyservice`, worktree `/private/tmp/shipit-design-addproduct-keys`, owning
  `docs/engineering/dispatch/tasks/design-addproduct-keyservice/**`. Its `OWNED_PATHS` do not
  intersect yours. It owns the normative backend design, the `hostUnrecognised` state machine and
  the meaning of "Check access"; you own no backend artifact.
- Work this lane blocks: `design-review-addproduct-mobile`, then Gate D4, then
  `implement-addproduct` and the visual-QA golden baseline.
- Open Human Decision ids this lane depends on: none.

## Sibling lane coupling — read carefully

The `Unknown host` boards you must draw depict a trust state whose normative definition the
sibling lane owns. To keep the two lanes non-overlapping and parallel:

1. Draw the **Unknown host** boards to the human's explicit specification in point 2d and
   addendum 2: the trust step has **no Cancel affordance**, and the way out is navigation back to
   the Products page (the key persists, so the product can be registered later). This is settled
   human input — you may draw it.
2. Do **not** invent backend behaviour, API shapes, field names or verification semantics. If a
   board implies them, mark the implication explicitly as an assumption pending
   `design-addproduct-keyservice`.
3. **Exactly one copy string is coupled**: any board text describing where the private half
   lives. Specify it against the settled architecture — server-side, never reaching the browser —
   and mark that one string `PENDING D4 — parameterized on the at-rest protection model`. The
   sibling lane will produce the at-rest options; the final wording is reconciled in one DCR
   after Gate D4. Do not stall waiting for it.
4. In your report's `SAFE_PARALLEL_WORK` / `PROHIBITED_PARALLEL_WORK`, state explicitly whether
   your boards would need redrawing if the sibling's state machine diverges from your assumption.

## Design requirements you MUST satisfy

### R1 — author the four boards

`SM - Add Product - Unknown host - Light`, `… - Dark`, `SM - Add Product - Verified - Light`,
`… - Dark`, at **390x844**, on page `d8ac01df-6646-81d2-8008-a366c09aa9d3`.

Verified convention you must follow, from the existing `BPM - Add Product - Light`: back link,
title, `NOT REGISTERED YET` eyebrow, 3 fields, deploy-key panel (`Copy key`, `Check access`),
`Register product`, helper text **below** the button, `Show technical details`, bottom nav. There
is **no** "What you're registering" panel and **no** "What happens next" panel — do not add them.

Naming convention: `SM -` for mobile **states**, `BPM -` for mobile **pages**. Do not rename any
existing board.

### R2 — point 2e: the button label and the helper

Only **"Register product"** goes in the button. The helper text goes **below** it and, reading the
design from the top, tells the user what they must do to enable the button.

The prior review recorded that desktop nests the reason **inside** `FilledButton.child`
(`add_product_page.dart:692-717`) while mobile renders a sibling (`:912-920`) — two different
structures for the same intent. Your design must specify **one** structure, applied consistently,
and state what happens to the button's height and the desktop gap when the helper is no longer
inside it (prior finding **H2**: the desktop gap was left unspecified while the button height
changes).

### R3 — point 2f: the footer

The design has copy at the bottom plus **one** footer line, and a `Show technical details` widget.
Verified current state of the build: the footer copy line **is** present at
`add_product_page.dart:383`, and `Show technical details` appears **nowhere** in the current code —
it was **removed**, not de-duplicated (the original review report said there were two rows; that
was wrong). So this is a restoration, not a de-duplication. Design the exact footer
specification: the copy line, the single `Show technical details` row, its placement, and its
expanded/collapsed behaviour.

### R4 — re-ground the required-field convention; do NOT invent a second one

Prior finding **B1**: the prior round's premise was "the convention does not exist". **False.**
`create_defect_page.dart:458,477,495,504` already marks optional fields with an in-label
`(OPTIONAL)` suffix, and absence of the suffix marks required, matching the submit gate at
`create_defect_bloc.dart:201,207,216,229,238`. This convention is **already in production use**.

Your design must re-ground on it and specify the Add Product page's three fields under it. If a
field is required, it carries no suffix; if optional, it carries `(OPTIONAL)`.

Prior finding **B2**: coverage is **15** `FormFieldSlot(` invocations, not the ~8 previously
claimed (add_product ×2, create_defect ×10, create_feature_request ×3, form_primitives:304), and
five required defect-form fields are unclassified. `DesignTextField`
(`form_primitives.dart:287`), used by `model_executions_page.dart:851,857,863`, carries no marker
and **breaks at compile** if `requirement` is non-defaulted. Specify the full classification or
explicitly scope this lane to the Add Product page and name the rest as a follow-up — do not
silently narrow coverage while claiming it is complete.

### R5 — fix the accessibility contrast with the correct token

Prior finding **H1**: the prior round specified `inkTertiary` on `palette.card` claiming ≈6.0:1 in
dark, "above the 4.5:1 AA threshold". Measured from `design_tokens.dart:96,101,117,122` it is
**4.99:1 light / 4.23:1 dark — it FAILS AA** in dark. The 6.0 figure belongs to `inkSecondary`; the
tokens were confused.

Specify **`inkSecondary`** (**6.74:1 light / 6.10:1 dark**). The current build's nested subtext is
`inkPrimary` on the button fill at **2.72:1**, which also fails.

Do not repeat a contrast claim you have not measured. Either measure it from
`design_tokens.dart` and cite the ratio, or report the claim as unverified.

### R6 — the visual consequence of 2a/2b, and what "Check access" shows

2a: the page generates a key **on Repository SSH URL input**. 2b: `Register product` depends on
that key generation **and** trust of the host. Design what the boards show for each step and its
state — but the *normative* meaning of "Check access" belongs to the sibling lane. Point 2c
records that "Check access" is currently **undocumented**; on the boards it must at minimum be
labelled unambiguously.

### R7 — traceability and risk

- Trace every element to a requirement id and to the decisions that settle it.
  `DESIGN_GOVERNANCE.md` requires `traceability.requirements_covered` and `requirements_gaps`.
- Assign `RISK_LEVEL` 0–3 with rationale. Authoring four new boards and changing a documented
  form convention is at least Level 1; correcting a required-field convention that other forms
  already use may reach Level 2. Argue it; do not understate to dodge the human gate.
- Fill `design_system_compliance`, `ux_accessibility_score`, `implementation_feasibility`.
  Report `UNKNOWN` where you cannot substantiate a claim, and say why. **The prior review recorded
  a lane asserting `implementation_feasibility: HIGH` whose `flutter analyze` had never actually
  resolved packages** (8090 `undefined_identifier` issues from a missing
  `.dart_tool/package_config.json`). Do not repeat that.

## Acceptance criteria

- [ ] All four boards exist on page `d8ac01df-6646-81d2-8008-a366c09aa9d3`, at 390x844, named
      exactly as specified, and each is readable/correct in **both** themes. Screenshot or export
      each as evidence.
- [ ] Design Brief persisted with every field `DESIGN_GOVERNANCE.md` § Design Brief requires.
- [ ] Design Revision persisted with a `design-revision-metadata.yaml` carrying every required
      metadata field.
- [ ] R2 satisfied: one button/helper structure specified for desktop and mobile, with the
      button-height and desktop-gap consequence of moving the helper out stated.
- [ ] R3 satisfied: footer copy line + exactly one `Show technical details` row specified,
      framed as a restoration.
- [ ] R4 satisfied: Add Product's three fields classified under the **existing** `(OPTIONAL)`
      convention; either full 15-site coverage is specified, or the remainder is named as an
      explicit follow-up with `model_executions_page.dart`'s compile impact called out.
- [ ] R5 satisfied: `inkSecondary` specified with cited ratios; no unmeasured contrast claim.
- [ ] No board copy claims the private half lives on the device or in a browser keychain.
- [ ] Traceability matrix present with gaps reported.
- [ ] `RISK_LEVEL` assigned with rationale; self-assessment fields honestly filled.
- [ ] Report conforms to `subtask-report.md` and the `design-agent` result block verbatim.
- [ ] Durable discoveries classified per `docs/engineering/LEARNING_POLICY.md`.

## Required validation commands

Run each and report its exact result. `NOT_RUN` is acceptable; a fabricated `pass` is not.

- [ ] `cd /private/tmp/shipit-design-addproduct-mobile && git branch --show-current` — isolation proof.
- [ ] `cd /private/tmp/shipit-design-addproduct-mobile && git rev-parse --short HEAD` — must be `77c19f1`.
- [ ] `grep -rn "OPTIONAL" apps/control_plane/lib/features/defects/create_defect_page.dart` — confirm R4's premise yourself.
- [ ] `grep -rn "inkTertiary\|inkSecondary\|inkPrimary" apps/control_plane/lib/shared/design_tokens.dart` — confirm R5's premise yourself.
- [ ] `grep -rn "Show technical details\|_registerButtonSubtext\|FormFieldSlot" apps/control_plane/lib` — confirm R3's premise (footer copy present, "Show technical details" absent).
- [ ] Penpot: list the boards on page `d8ac01df-6646-81d2-8008-a366c09aa9d3` before and after authoring, so the before/after is on record.

Do not weaken, skip, delete or ignore anything to reach a clean result.

## Hard rules for the child

- Write only inside `OWNED_PATHS`. Never touch `PROHIBITED_PATHS`. **Never edit or delete an
  existing Penpot board** — including `BPM - Add Product - Light`, which you are reading as your
  grammar reference.
- **Do not run any Docker or Compose command — not even a read-only one.** This repository has
  already lost a QA database to a review lane running
  `docker compose -f docker/compose.qa.yaml down -v`, and `AGENTS.md` still has no read-only rule
  over Docker state. Run none.
- Do not commit or push unless this prompt explicitly instructs it. It does not. Leave your
  artifacts in the worktree; the Manager persists them. (Penpot board creation is not a git
  operation — it is yours to perform.)
- Do not approve your own work.
- Stop and report rather than settling a product, architecture, design, security, infrastructure,
  destructive-operation or deployment-authority question yourself. If a board needs a decision
  only the human can make, surface it as a blocker; do not pick.
- Every result carries exact repository/worktree/HEAD provenance.

## Cleanup before returning

- [ ] Stop every process you started; report any port/PID left running.
- [ ] Temporary artifacts removed; no scratch boards left on the Penpot page.
- [ ] `git status --short` in your worktree shows only your `OWNED_PATHS` additions.

## Report format

Return a report conforming to
`.agents/skills/aef-orchestrator/templates/subtask-report.md`, with the `RESULT:` block emitted
verbatim from `.agents/agents/design-agent.md`:

```
RESULT: DESIGN_REVISION_COMPLETE | DESIGN_REVISION_BLOCKED
```
