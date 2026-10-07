# Subtask Prompt — design-correct-addproduct-mobile-5b (Design Revision 5, mobile)

Persisted per `aef-orchestrator` §14 **before** launch, §2 bookkeeping only.
Rendered from `.agents/skills/aef-orchestrator/templates/subtask-prompt.md`.

**This is the THIRD attempt.** Attempts 1 and 2 both returned `RESULT: DESIGN_REVISION_BLOCKED`
on Penpot unavailability. **Penpot is now reachable** — verified by the Manager this session:
`penpot_execute_code` → `penpotUtils.getPages()` returned `["Page 1"]`, and all four boards you own
were located on that page. **The blocker that stopped both prior attempts is cleared. Produce
revision 5.**

## Mandatory header

```yaml
MANAGER: orchestrator-main
TASK_ID: design-correct-addproduct-mobile-5b
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — mobile Design Revision 5 (cycle 5b)
AREA: Penpot SM mobile boards for Add Product; footer spec; identity/registration split; at-rest copy
WORKTREE: /private/tmp/shipit-correct-addproduct-mobile
BRANCH: design-correct-addproduct-mobile
BASE_SHA: 289f1d3
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**
  - Penpot page "Page 1" (d8ac01df-6646-81d2-8008-a366c09aa9d3) — the four boards you own:
      - SM - Add Product - Unknown host - Light   (6d055762-a70b-804c-8008-bf65ff750422)
      - SM - Add Product - Unknown host - Dark    (6d055762-a70b-804c-8008-bf65e644269b)
      - SM - Add Product - Verified - Light       (6d055762-a70b-804c-8008-bf660e124738)
      - SM - Add Product - Verified - Dark        (6d055762-a70b-804c-8008-bf65f36b1c9a)
READ_ONLY_PATHS:
  - apps/control_plane/lib/**          (production source — you design it, you do not write it)
  - packages/**
  - apps/server/**
  - docs/adr/**
  - docs/engineering/**
  - AGENTS.md
  - .decisions/**
  - Every Penpot board that is NOT one of the four named in OWNED_PATHS — including every
    `BPM -`, `S -`/`DESKTOP -` and `SM -` board. You READ them; you never edit or delete them.
PROHIBITED_PATHS:
  - apps/control_plane/lib/**          (production source — you design it, you do not write it)
  - apps/server/**, packages/**        (production source; sibling keys lane + implementer own these)
  - docker/**                          (see hard rule: no Docker command may be executed, not even read-only)
  - .github/workflows/**
  - .decisions/**                      (Manager-owned)
  - docs/engineering/WORK_STATE.md     (Manager-owned)
  - docs/engineering/dispatch/LANES.md (Manager-owned)
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**   (the other lane's artifacts)
  - docs/adr/**                        (ADR owner; the ADR 0018 A2 amendment is a separate lane)
ACCEPTANCE_CRITERIA: |
  Design Revision 5 (Gate D3-ready) carrying:
  (1) H-1(a) — the at-rest/custody string corrected on all four SM boards and across ~30 record
      sites, against `9417f8bf` (A3 external secret manager: SHIP IT holds only a reference);
  (2) H-1(b) — the human's normative footer alignment specified for BOTH platforms;
  (3) H-1(c) — the Unknown-host boards re-grounded on `898b07d0` (split identity from
      registration) with a genuine user-facing element conveying "a product exists but is not
      yet usable", and `ae1c1f79`'s refusal-creates-nothing consequence;
  (4) M-1 — cross-reference line numbers corrected by re-reading the live file after each edit;
  (5) L-1 — the missing pointers added, including `design-revision-3.md:445`'s G2 "PENDING D4" claim.
VALIDATION_COMMANDS:
  - cd /private/tmp/shipit-correct-addproduct-mobile && git branch --show-current   # design-correct-addproduct-mobile
  - cd /private/tmp/shipit-correct-addproduct-mobile && git rev-parse --short HEAD  # 289f1d3
  - penpot: penpotUtils.getPages() must return Page 1
  - penpot: board list on Page 1 before and after your edits
ROUTING_CLASS: STANDARD
```

## Isolation pre-flight — RUN THIS FIRST

```bash
cd /private/tmp/shipit-correct-addproduct-mobile
git branch --show-current    # must equal design-correct-addproduct-mobile
git rev-parse HEAD           # must equal 289f1d3
git status --porcelain       # must show ONLY the two untracked prior-attempt reports
```

The branch has already been **re-based onto `main` @ `289f1d3`** (fast-forward from `43d328b`; `43d328b`
is an ancestor of `289f1d3`, so no merge commit and no conflict resolution were needed). Note this
means `main` now also carries the keys revision-5 artifacts and the ADR 0018 A2 revision-2 artifacts —
they are **read-only references for you**, not your scope.

If any check fails, STOP and report `RESULT: DESIGN_REVISION_BLOCKED` with the observed values.

## The state you are resuming from — read these first, in this order

1. `docs/engineering/dispatch/tasks/design-addproduct-mobile/prompt.md` — the original cycle-1 dispatch
   and requirements R1–R7. Still authoritative for anything this prompt does not override.
2. `docs/engineering/dispatch/tasks/design-correct-addproduct-mobile-5/attempt1-report-full.md` — attempt 1's
   **full** 423-line report (`RESULT: DESIGN_REVISION_BLOCKED`, D-1…D-7).
3. `docs/engineering/dispatch/tasks/design-correct-addproduct-mobile-5/correction-report-5-retry.md` —
   attempt 2's report (`RESULT: DESIGN_REVISION_BLOCKED`, D-1…D-8 + verified ground-work). **Attempt 2
   verified all 15 tracked artifacts byte-identical to its base, so its measurements carry forward.**
4. `docs/engineering/dispatch/tasks/design-review-addproduct-mobile-rev4/report.md` — the review that
   created the findings you must close.
5. `.decisions/**` — **all nine are RESOLVED. Do not re-open any of them.**

Attempt 2's `§2` is verified ground-work, not partial delivery. It measured the source, not the prompt.
Re-use it. You do **not** need to re-derive D-1…D-7 from scratch; re-verify only what your edits move.

## THE HEADLINE FINDING — four boards carry copy that is FALSE

`9417f8bf` = **OPTION_C / A3, an external secret manager: SHIP IT never holds key bytes, only a
reference, and asks the manager for the material at push time.**

The four SM boards read **`ed25519 · private half stays server-side`**. Under A3 the private half is
**not server-side — it is not SHIP IT's at all.** The design lane had correctly designated that layer
"the single string parameterized on the at-rest protection model", so the one element it properly held
open is now the one element that is wrong, **on four boards, in user-facing security copy.**

- **Adopt `N-9`'s string**, the only normative one of the three divergent variants:
  `ed25519 · generated on the server · the private half stays in the secret manager`
- The board's current string and the build's at `apps/control_plane/lib/features/products/add_product_page.dart:542`
  are both non-normative. **The build's `:542` is a separate production correction — report it, do not edit it.**
- **D-7 applies: this is security copy, not a Level-0 detail.**
- **H-1(a) spans ~30 sites, not four.** Attempt 2 found the claim at `design-brief.md:135`,
  `penpot-board-evidence.md:152`, six rev-4 sites, both metadata files, and revs 1–3. **A four-cell fix
  would be returned for the same defect class.** Sweep the whole owned set.
- `penpot-board-evidence.md:151`'s `ed25519 · private half stays server-side` is a **rev-2-era record,
  not a live read.** Now that Penpot is up, re-read the boards and correct the record to what is live.

## Two REQUIRED follow-up actions owned by `design-agent` in `9417f8bf`

Quote from the decision file, not paraphrased. Both are currently unaddressed across the whole artifact set
and both belong to this pass:

> "Remove `referenceName` from `RepositoryCredentialView`, or replace it with a non-identifying handle.
> Under A3 the reference IS the sensitive artifact; G-7 was optional while the substrate was undecided and
> is now required." — **REQUIRED**, a generated-contract change in two packages.

> "Design the A3 unavailability path with concrete remediation copy, per the fail-closed answer in
> `7b1bc8b7`. Under A3 the substrate is a runtime dependency that can be down, so this is a common case,
> not an edge case."

The second needs **real remediation copy on the boards** — which is why attempt 2 could not do it and
why you can.

## H-1(b) — the human's footer alignment, quoted verbatim from `27ea6536`

> - **Desktop** (`S - Add Product · Unknown host · Light/Dark`, `S - Add Product · Verified · Light/Dark`):
>   a divider, and a **right-aligned** `Show technical details` text button. **No footer copy.**
> - **Mobile** (`BPM - Add Product · Light/Dark`): a `Show technical details` button **left-aligned, with
>   no divider**. **No footer copy.**
> - "Stay true to both designs in Penpot and in code" — the boards are authoritative; the build must
>   not invent a third footer, and the two platforms are genuinely different rather than one being a
>   mistake.

The human's `"righ aligned"` / `"now divider"` are typos; the decision's `rationale` renders both
correctly. **No human gate is needed and `27ea6536` must not be re-raised.**
`supersedes_design_lane_reading` states the lane's `Footer`-at-(236,862) reading *"should be treated as
a misidentification"* — **withdraw it in place, do not delete it.**

### D-2 — the load-bearing engineering consequence, confirmed by attempt 2

`apps/control_plane/lib/core/design_primitives.dart:396` paints the `ContentRule` **unconditionally**,
and `:398-410` is `Row[Expanded(note ?? SizedBox.shrink()), InlineLink]`. Therefore:

- The human's **desktop** spec (divider + right-aligned, no copy) is produced **for free** by passing
  `note: null`. **No new parameter needed.**
- **Mobile's spec is the opposite on both axes and is NOT expressible today.**

F4 escalates from an observation to a **specified shared-primitive requirement**: `TechnicalDetails` must
be able to suppress its `ContentRule` and align its disclosure start-aligned. Specify it. Route it to the
design-system owner as a **Level 1** notification in your report — the human has already decided the
outcome, so this is a component choice, not a gate. Do not ask the human.

### D-3 — "no footer copy" is TWO `note:` sites, not one

Both platforms pass `TechnicalDetails(note:)` with the same string: `add_product_page.dart:317-319`
(desktop) and `:926-928` (mobile). Both `27ea6536`'s context and the keys lane's binding R.11g item 7
claim mobile "has no `note:`" — **false against source.** Record the correction in your own artifacts;
**report it to the keys lane, do not edit its artifacts.** It also means removing the footer copy means
deleting `_buildFooter` (`:375`, which carries the `:383` copy).

## H-1(c) — `898b07d0`, and `ae1c1f79`'s correction to it

`898b07d0` = **OPTION_A, split identity from registration.** Quote: *"The key flow creates the Product row
(state registered) plus the RepositoryReference as an explicit first step; 'Register product' then commits
credential verification."* The known trade was **accepted**: *"leaving the page early leaves a visible
product with no usable credential."*

`ae1c1f79` = **OPTION_A, refusal creates nothing.** Quote: *"the substrate precondition is evaluated
before any write"*, and its design-agent follow-up: *"after a refused mint the Products list is unchanged,
so the Unknown-host state must not imply that a product was created."*

`898b07d0`, "split identity", "half-registered" and `RegistrationCommitState` are **0 hits each** across
the whole artifact set today. **R.11g item 3 is a hard requirement on you** — re-enterable from the
product, or the accepted visible-half-registered consequence becomes the dead end human point 2d rejected.

The Unknown-host boards need a **step-order and copy re-grounding plus a genuine user-facing element**.
`· PROVISIONAL (G1 hostUnrecognised)` is an internal layer-name annotation and **does not satisfy it.**
The element must tell a user *"a product now exists but is not yet usable."*

## D-8 — ANSWER THIS FIRST (attempt 2 named it as the first question)

`27ea6536`'s mobile ruling cites **`BPM - Add Product · Light/Dark`**. You own the
**`SM - Add Product - *`** family. Are they two scales of one mobile design, or two different mobile
designs?

**Answer it by reading `BPM · Add Product · Light/Dark` (read-only) against your four `SM` boards, before
applying the alignment spec to either.** Attempt 2 could not resolve this without Penpot and it is
material: if `SM` ≠ `BPM`, the mobile footer spec must be reconciled across two board families rather than
applied once, and **that difference is a finding for the human** — report it as a blocker with evidence,
do not guess.

## Risk level — the Level-3 gate is ALREADY DISCHARGED

Attempt 2 re-derived risk level 3 **and re-verified the gate itself** (not inherited): `9417f8bf`,
`27ea6536` and `898b07d0` are all RESOLVED by the repository owner and all name `design-agent` as a
follow-up owner. Verify this yourself — your risk claim rests on it — then carry it forward.

**The gate must not be re-opened.** The decisions moved the risk into this lane as a **mandate**, not out
of it. **One residual component is NOT human-decided: D-2**, the `TechnicalDetails` primitive change, and
that is a shared-component choice at **Level 1**, not a gate.

## M-1 — why "+6" is not a safe rule

Attempt 2 measured: six single-line citations at **+6**, the provenance note at **+5** (`26-31`→`31-37`),
and the three marker **ranges** at **+8 / +8 / +13**. `report.md:12` does say "31-37", so revision 4
contradicts itself. **Applying +6 mechanically fixes six numbers and breaks three.**

Required method: **read the live file after each edit and re-read again afterwards** — a marker written at
a cited line moves that line. **Drop the "CONFIRMED, every number" claim unless it is true after re-reading.**

L-1 — three missing pointers, not two: `design-revision-3.md:551` (G11 still open), `:444-445`
(B3 still filed as `27ea6536`), and **`:445` also carries the G2 "PENDING D4" claim** — a third site the
review did not name.

## Escalation triggers to remove from rev 4's metadata

`design-revision-metadata-4.yaml:42-43` (the `27ea6536` footer trigger, now confirmed) and `:44-45`
(the host-trust navigation/IA trigger, now fired by `898b07d0` + R.11g item 3). Both are fired; remove
them so the next reviewer is not sent to a discharged gate.

## Do NOT re-derive — these are proven and re-deriving them wastes the pass

- Attempt 2 proved all 15 tracked artifacts byte-identical to its base. **D-1…D-7 carry forward.**
- `git diff --name-only 77c19f1 43d328b -- apps/control_plane packages` returned four files, all in
  `packages/product_registry/**`, so every Flutter file you cite is unchanged and every `:NNN` citation
  into `apps/control_plane/**` holds. **Caveat: you are now on `289f1d3`, two commits past `43d328b` —
  re-run that diff and confirm the `add_product_page.dart` and `design_primitives.dart` line numbers you
  cite before using them.**
- **The keys lane's line numbers are NOT trustworthy.** Its own review found its item-7 `_buildFooter`
  definition and call site inverted, and its `TechnicalDetails` citation pointing at the desktop one.
  Re-read any number taken from the sibling against source.
- Attempt 2 caught one of its **own vacuous checks**: `git diff --quiet` on
  `apps/control_plane/lib/pages/add_product_page.dart` returned UNCHANGED — **because that path does not
  exist.** The true path is `apps/control_plane/lib/features/products/add_product_page.dart`.
  Run your path-existence checks before trusting an UNCHANGED.
- **Three times in this work item, a lane grepped one identifier and concluded an artifact was absent**
  (`deployKey` vs `credential`; `docs/engineering/adr/` vs `docs/adr/`; the literal
  "Show technical details" against a centralised label). **Search the domain's own vocabulary, not the
  requester's phrasing.** If an identifier is cited, follow the citations.

## Hard rules for the child

- Write only inside `OWNED_PATHS`. Never touch `PROHIBITED_PATHS`.
- **Never edit or delete an existing Penpot board** other than your four `SM` boards. `BPM - Add Product -
  Light/Dark` and every `S -`/`DESKTOP -` board are read-only references. Do not rename them.
- **Do not run any Docker or Compose command — not even a read-only one** (`info`, `ps`, `logs`,
  `config` included). `AGENTS.md` § *Shared Docker state* binds every lane without deployment authority:
  read-only is satisfied by **not issuing a mutating command at all**, and the read-only-looking ones are
  explicitly **not** granted either. **This repository has already lost a QA database to a lane doing this.**
- Do not commit or push. Leave your artifacts in the worktree; the Manager persists them.
  **Penpot board editing is not a git operation — performing it is yours.**
- Do not approve your own work.
- **Persist EVERY returned report to disk in your worktree before you return.** Two prior Manager
  dispatches in this work item lost review reports to the relay, and the receiving lanes had to work from
  a paraphrase.
- Stop and report rather than settling a product, architecture, design, security, infrastructure,
  destructive-operation or deployment-authority question yourself. `898b07d0`, `9417f8bf`, `27ea6536` and
  `ae1c1f79` are RESOLVED — do not re-open them, and do not re-raise B2/N1, B4/N2, N4/G9, N6, N10.
- Every result carries exact repository/worktree/HEAD provenance.

## Cleanup before returning

- Stop every process you started; report any port/PID left running.
- No scratch boards left on the Penpot page.
- `git status --short` in your worktree shows only your `OWNED_PATHS` additions.

## Report format

Return a report conforming to
`.agents/skills/aef-orchestrator/templates/subtask-report.md`, with the `RESULT:` block emitted
verbatim from `.agents/agents/design-agent.md`:

```
RESULT: DESIGN_REVISION_COMPLETE | DESIGN_REVISION_BLOCKED
```

## Original request (verbatim — unchanged from cycle 1)

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