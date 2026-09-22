# Design Change Request — DCR-002

| Field | Value |
|---|---|
| **DCR ID** | `DCR-002` |
| **Feature ID** | `CONTROL_PLANE_OPERATOR_UI_001` (same feature, new change) |
| **Date raised** | 2026-09-15 |
| **Raised by** | Human operator (design authority / requirement owner) |
| **Against** | Direction B, adopted under `DCR-001` = `SELECT_B` |
| **Status** | **RESOLVED — `ADOPT_PLAIN`** (human, 2026-09-15; reconciled 2026-09-16, see DESIGN-HANDOFF §14) |
| **Gate** | `PLAIN_LANGUAGE_DIRECTION_APPROVAL_REQUIRED` |

---

## 1. WHY THIS IS A NEW DCR AND NOT PART OF DCR-001

`DCR-001` was explicitly scoped to **visual direction only** (§6: palette, type,
surface treatment, spacing, iconography, "overall character"). It explicitly put
out of scope (§7.1) *"changing the information architecture — the five surfaces
and their navigation relationships stay as approved"*, and required that any
proposal touching it be *"raised as a separate change, with its own gate."*

This request changes **terminology, copy, disclosure structure, and navigation
labelling**, and introduces a **user persona that was never in the original
requirement**. That is not visual direction. It needs its own gate, which is this
document.

**`DCR-001` is not re-opened.** Direction B stands as the adopted visual
direction. This DCR builds *on* B's design system; it does not replace it.

---

## 2. THE COMPLAINT

Stated by the requirement owner:

> "This product will be very hard for a non-technical QA to understand and
> navigate. It's even hard for a technical dev like myself that set the
> requirements to understand the language — such as using words like *Control
> Plane*."

Two distinct problems are being reported:

1. **Language.** The interface speaks the platform's internal vocabulary.
2. **Navigability.** Even a reader who understands the words cannot quickly tell
   what the system wants from them.

The second is the more serious. A person can look up a word; they cannot easily
recover from a screen that does not tell them what to do.

---

## 3. MEASURED EVIDENCE — this is not a matter of taste

Measured mechanically across Direction B's six boards (`docs/design/qa/`):

**153 distinct strings. 83 of them — 54% — are not plain English.**

| Class | Count | Examples |
|---|--:|---|
| Jargon | 43 | `CONTROL PLANE`, `DURABLE STATE`, `GUARD`, `QUEUE IMPACT`, `CONTRACT RECOMMENDATION`, `leases 1 / 2`, `worker pool · local`, `device-local operator`, `ed25519` |
| Opaque identifiers | 20 | `WI-9c11`, `GD-5b1e`, `JOB-31`, `EXEC-9c11-01`, `DES-R2` |
| snake_case enum values | 10 | `waiting_for_human_decision  (WorkItem.state)`, `agent_executing`, `design_approval`, `qa_rework` |
| Code fragments | 10 | `resolveDecision(gate, choice, rationale, signature) → DurableWorkflowEngine…`, `Reads: HomeEndpoints.overview · listWorkItems · pendingDecisions…`, `Resolution appends a WorkflowTransitionRecord…` |
| Plain-ish | 70 | `Home`, `Approve`, `expires in 21h`, `Your call` |

Even part of the "plain-ish" 70 fails the test in context: `PENDING · BLOCKING`,
`workflow engine`, `6 / 6 executed`, `2 captured at review time`.

**Three footers are literal source code** rendered as UI text. They exist to
prove the screen is honest about where its data comes from — a real and valuable
intent — but they communicate that intent only to someone who reads Dart.

---

## 4. THE HARD PART — and why "just simplify it" is not the answer

The product's *subject matter* is software engineering. Its sample work items are
`Scheduler claim-CAS dedupe patch`, `Postgres migration contract test`,
`Penpot design authority probe`. **No amount of interface copy makes those titles
meaningful to a non-technical reader**, because they describe engineering work.

So the goal is **not** "make the content non-technical" — that is impossible and
would be dishonest. The goal is:

> **Make the *task* legible even when the *subject* is technical.**

A non-technical QA reviewer does not need to understand a claim-CAS dedupe patch.
They need to understand, without help:

1. Is anything waiting for me?
2. What exactly am I being asked to decide?
3. What evidence supports each option?
4. What happens after I choose?
5. Can I undo it?

Today the interface answers all five, but in the platform's own vocabulary.

---

## 5. THE GOVERNING CONSTRAINT — plain language must be a LAYER, not a REPLACEMENT

> **Plain language is a presentation mapping over exact durable values. It MUST
> NOT replace them.**

This is the one rule that cannot bend, and it comes directly from the finding that
produced the previous correction round. The independent reviewer's most serious
finding against C was that a surface contracted to *"every value is a read from
durable state"* contained a visible internal contradiction, and that this
*"destroys trust"*. The same logic applies here:

- If `waiting_for_human_decision` is silently replaced by "Waiting for you" with
  no way to see the underlying value, the screen stops being verifiable.
- An engineer debugging a stuck work item **needs** the exact enum value and the
  exact id.
- `HumanDecision` semantics, the single-write-path rule, and the durable-state
  model remain authoritative (`DCR-001` §5). **This DCR changes what the screen
  SAYS, never what the system DOES.**

**Therefore: progressive disclosure.** Plain language on the surface; exact
values, identifiers and provenance one deliberate action away. Nothing is
deleted — it is demoted.

This also resolves the apparent conflict between the two audiences without a
mode switch: the plain layer serves the QA reviewer, the disclosed layer serves
the engineer, and both read the same durable truth.

---

## 6. IN SCOPE

- Terminology and microcopy across all surfaces
- Disclosure structure (what is visible by default vs. revealed)
- Navigation labelling and the top-level question each screen answers
- Ordering and grouping *within* a surface, where it improves task legibility
- Empty/quiet states ("nothing needs you") — currently undesigned

## 7. OUT OF SCOPE

1. **B's visual system.** Palette, type scale, hairline treatment, density,
   3px radii, `#1F2120` background, IBM Plex Sans/Mono all stand.
2. **The five surfaces.** Home, Runs, Run Detail, Needs You, Decision Detail
   remain the surface set. Their *labels* may change; the set does not.
3. **Durable semantics.** `WorkItemState`, `HumanDecision` lifecycle,
   same-`WorkItem` resume, `resolveDecision` as the single write path.
4. **API contracts.** No endpoint additions, removals, or signature changes.
5. **Accessibility and responsive requirements.** The 840px breakpoint and all
   accessibility requirements from planning §14 continue to apply.

---

## 8. ACCEPTANCE CRITERIA

| ID | Criterion |
|---|---|
| **DCR2-AC-1** | **Zero unexplained jargon in the default view.** Every string visible without interaction is either plain English or an identifier explicitly labelled as a reference. Measured mechanically, not asserted. |
| **DCR2-AC-2** | **Every durable value remains reachable.** For each plain-language label shown, the exact underlying value is available via disclosure. Verified per surface. |
| **DCR2-AC-3** | **Each screen answers one stated question in one line**, at the top, before any table or panel. |
| **DCR2-AC-4** | **A non-technical reader can complete the core task** — find what needs them, understand the choice, see the consequence, decide — without encountering an unexplained term. Walked through explicitly per surface. |
| **DCR2-AC-5** | **Dark + light for every new surface.** Neither asserted as derivable. |
| **DCR2-AC-6** | **Independent review** by an execution other than the one that produced the boards. Designer self-approval does not satisfy this. |
| **DCR2-AC-7** | **Human selects.** No agent may self-approve the outcome. |

---

## 9. GATE

**`PLAIN_LANGUAGE_DIRECTION_APPROVAL_REQUIRED`**

| Outcome | Meaning |
|---|---|
| `KEEP_B_AS_IS` | The technical language stays; close DCR-002 |
| `ADOPT_PLAIN` | Adopt the plain-language layer as authoritative |
| `ADOPT_PLAIN_WITH_CHANGES` | Adopt with named amendments |
| `REQUEST_NEW_ROUND` | Not acceptable; brief again |

Until a human records one of the above, **Direction B as adopted under `DCR-001`
remains the implementation-authoritative design.**

The independent-review record for `DCR2-AC-6` is in `DESIGN-HANDOFF.md` §13
(verdict: `APPROVED_WITH_FINDINGS`; MAJOR = model-coverage gap — a data matter,
not a board redesign).

---

## 10. OPEN QUESTIONS FOR THE HUMAN

| ID | Question |
|---|---|
| **PL-1** | Primary audience: is the non-technical reviewer now the *primary* user (plain by default, technical hidden), or are both audiences equal (layered but technical still prominent)? |
| **PL-2** | What replaces "Control Plane" as the product/page label? |
| **PL-3** | Do identifiers (`WI-9c11`) stay visible as small labelled references, or move entirely behind disclosure? |
| **PL-4** | Is "QA reviewer" the right persona name, and do they have *different permissions* from an engineer? If so, this stops being only a copy change and acquires a permissions dimension — which would need its own scope. |

**PL-1 … PL-3 answered 2026-09-15:**

| ID | Decision |
|---|---|
| **PL-1** | **Non-technical reviewer is primary.** Plain by default; technical detail behind disclosure. |
| **PL-2** | **"ShipIt" in the rail** (the wordmark alone; the `CONTROL PLANE` line is removed). **Home H1 = "Overview".** |
| **PL-3** | **Identifiers stay, small and labelled** — rendered `ref WI-9c11` in muted mono. |

`PL-4` remains open and is deliberately not assumed.

---

## 11. BUILT — plain-language variant of B, dark set, 2026-09-15

Built by **cloning Direction B and rewriting it**, so B's adopted design system
(IBM Plex Sans/Mono, hairline rules, 3px radii, `#1F2120`, brand palette,
density) carries over unchanged rather than being re-authored.

**COMPLETE SET — all 5 surfaces × dark + light, built 2026-09-15.**

| Surface | Dark | Light | x |
|---|---|---|--:|
| Home | `f01f5bc4-…-a4b4d475d6e2` | `f01f5bc4-…-a4e25500c0a8` | 0 |
| All work | `f01f5bc4-…-a4e0d836d595` | `f01f5bc4-…-a4e257aec05e` | 1300 |
| Run Detail | `f01f5bc4-…-a4e1a934b185` | `f01f5bc4-…-a4e25b5b7146` | 2600 |
| Needs You | `f01f5bc4-…-a4b60f32994c` | `f01f5bc4-…-a4e25ec749df` | 3900 |
| Decision Detail | `f01f5bc4-…-a4b5a50b4d3d` | `f01f5bc4-…-a4e2619f9333` | 5200 |

Rows: dark y=7900, light y=8850. **`DCR2-AC-5` satisfied.**

**10 boards · 0 major mechanical findings · 9 brand-palette advisories**
(the standing brand-owner item, `brand-tokens.md` §6).

### 11.0a The two new surfaces

`B` only ever had 3 surfaces — `Runs` and `Run Detail` existed solely in the
original 2026-09-14 lineage, in the pre-B visual system. Both were rebuilt in B's
system with plain language, with their **information architecture taken from the
original boards** (authoritative per `DCR-001` §5), not invented:

| Surface | Source IA | Plain-language treatment |
|---|---|---|
| **All work** | `Runs`: filter chips, count, table (RUN/WORK ITEM, STATE, PRODUCT, DURATION, LAST EVENT) | Chips became `All work / Working on it / Needs you / Finished / Failed`; columns became `REF / WHAT IT IS / STATUS / RUNNING FOR` |
| **Run Detail** | `Run Detail`: breadcrumb, state chip, Activity timeline, Execution & evidence panels | Timeline became `What's happened so far` in plain events ("Work created", "Sent to you for approval"); the decision console became a single `Review and decide` CTA, since deciding belongs on Decision Detail |

**One count was corrected during the build:** `All work` initially claimed
"12 items" while rendering 8 rows. Rather than invent 4 more rows, the count was
set to the truth — 8.

### 11.0b Light variants derived, not invented

The dark→light palette was derived by pairing B's own dark and light boards by
shape name: **11 text mappings, 10 surface mappings, zero ambiguities, zero
unmapped colours.** Two values needed explicit resolution because name-pairing
cannot match `· Dark` to `· Light` for the board itself — the board background
`#1F2120` → `#F7F7F5` was read directly off `B · Home · Light`.

Notable derived pairs, which a hand-written map would likely have got wrong:

| Role | Dark | Light |
|---|---|---|
| brand orange as **text** | `#F7A42C` | `#A35F00` (darkened for paper) |
| brand orange as **fill** | `#F7A42C` | `#F7A42C` (unchanged) |
| brand mint | `#6FFFCE` | `#0E7A56` |
| primary CTA label | `#06121F` | `#FFFFFF` |

### 11.1 `DCR2-AC-1` measured — 0 violations

| | Direction B (before) | BP (after) |
|---|--:|--:|
| Strings that are **not** plain English | **83 of 153 (54%)** | **0** |
| Plain English | 70 | **127** |
| Identifiers, labelled `ref …` (allowed by PL-3) | — | 18 |
| In the disclosed technical layer | — | 3 |
| Work-item titles (engineering content, §4) | — | 6 |

### 11.2 A third design finding, fixed here

B's **MAJOR** review finding — brand blue overloaded across state, links and CTA —
turns out to be a *usability* defect, not only an aesthetic one: a non-technical
user cannot tell what is clickable when `Working on it` is blue and inert while
`See details` is grey and interactive.

**Rule adopted: blue means you can click it; status colour means state.**
Blue was removed from all status text and applied to every affordance. Verified
mechanically — every blue text node on the set is now an affordance.

### 11.3 The disclosure layer, shown in both states

- `BP · Home` and `BP · Needs You` show it **collapsed** — `Show technical details ▸`
- `BP · Decision Detail` shows it **expanded**, printing the exact durable values:
  - `WorkItem.state = waiting_for_human_decision · halted in: design_in_review`
  - `HumanDecision GD-5b1e · design_approval · pending · JOB-31 queued · EXEC-9c11-01`

This is what satisfies §5: nothing was deleted, only demoted, so the screen stays
verifiable against durable state.

### 11.4 Mechanical state

**3 boards, 0 major findings.** 3 brand-palette contrast advisories (the known
brand-owner item, `brand-tokens.md` §6). Zero overflow, overlap, containment or
legibility findings.

---

## 12. REVIEW ROUND 2 — human feedback 2026-09-15, and what it uncovered

### 12.1 Time limits were showing a deadline the system mostly does not have

**Human question:** *"Why do we have time limits on the UI? Do we actually
require humans to intervene before that time?"*

**Verified in the contracts, not assumed:**

- `HumanDecision.expiration` is **`DateTime?` — nullable.** Most decisions have
  no deadline at all, so the UI was inventing one.
- It is referenced in exactly **one** place in logic:
  `workflow_engine/lib/src/validation/guard_conditions.dart:401`, in the
  `blocking_human_decision_resolved` guard.
- That guard treats a decision as `expired` when
  `!decision.timestamp!.isBefore(decision.expiration!)` and then **refuses the
  transition**.

**So the real behaviour is:** nothing auto-approves, auto-rejects, escalates or
notifies at the deadline. But **if you decide after it, your decision is rejected
by the guard and the work item stays blocked.**

A countdown that implies urgency while concealing *that* consequence is worse
than no countdown. **Removed.** Replaced with how long the decision has been
waiting (`waiting 3h 12m`), which is derived from `requestedAt` and is always true.

> **OPEN PRODUCT QUESTION (`PL-5`):** is a deadline that silently invalidates a
> late human decision the intended behaviour? It currently produces a work item
> that is permanently stuck with no UI signal. This is a workflow-semantics
> question, not a design one, and needs its own decision.

### 12.2 You cannot approve what you cannot see — and the contract already allowed it

**Human finding:** no link or image of the design under review.

**No architectural change was required.** `WorkItem.artifactRefs` is
`List<ArtifactReference>?`, and `ArtifactReference` carries `uri`,
`artifactType`, `description` and `contentHash`. `ArtifactType` already includes
`design_revision` and `qa_evidence`. **The capability existed; the UI never
surfaced it.**

Added:

| Surface | Treatment |
|---|---|
| `BP · Decision Detail` | The evidence panel became **"WHAT YOU'RE APPROVING"**: a design preview thumbnail, `Design version 3`, `Open the design ↗`, `See 2 screenshots ↗`, with the automated checks beneath it |
| `BP · Needs You` | Each card surfaces the artifact inline — `DESIGN · Version 3 · open ↗`. The failed item correctly shows `LAST RUN · Log · open ↗` instead, because a failed run's artifact is a log, not a design |

The thumbnail is a **representation**, not a fabricated screenshot. Production
must bind it to `ArtifactReference.uri`.

### 12.3 Plain job titles — I was wrong, and this is a policy change

I previously wrote that making the content non-technical was *"impossible"* and
that the goal was only to make the task legible. **That under-reached, and the
human was right to push back.** `WorkItem` already carries **`description`**
alongside `title`.

| Technical `title` | Plain description now shown |
|---|---|
| `Ship bootstrap E2E journey` | Test the full sign-up journey |
| `Scheduler claim-CAS dedupe patch` | Stop duplicate jobs running twice |
| `Postgres migration contract test` | Check the database upgrade is safe |
| `Penpot design authority probe` | Check we can reach the design tool |

Gate questions followed: *"Approve the design for the claim-CAS dedupe patch?"* →
**"Approve the design for stopping duplicate jobs?"**

The technical title is **not lost** — it appears in the disclosed layer as
`title: Scheduler claim-CAS dedupe patch`.

> **REQUIRED POLICY CHANGE (`PL-6`):** `WorkItem.description` is currently
> nullable and unconstrained. For the UI to lead with plain language, any work
> item that can reach a human gate **must** carry a plain-language
> `description`. That is a validation rule plus authoring guidance — **not** a
> new field, and not a schema break. It does need its own decision and an
> owner, because nothing today prevents a technical string being written there.

### 12.4 Copy discipline — the UI must stop justifying itself

**Human finding:** *"You put 'Every number on this page comes straight from the
system's own records. Nothing here is guessed.' There's no need for 'Nothing here
is guessed'… you probably kept the copy from the previous agent's work."*

Correct on both counts. That register was inherited from the pre-existing boards,
where it existed to prove the screen was honest about its data source. It is
confirmation-dialog language, and it does not belong on a dashboard.

Removed throughout:

| Removed | Surface |
|---|---|
| "Every number on this page comes straight from the system's own records. Nothing here is guessed." | Home footer |
| "Nothing moves forward until you decide. There is no time pressure beyond the limits shown." | Home |
| "A permanent record of past decisions. These cannot be changed or deleted." | Needs you |
| "Everything below is a fact the system recorded — not a guess." | Decision detail |
| "These outcomes are fixed by the system. An AI cannot change where your decision sends this work." | Decision detail |
| "All of this was checked against the test plan that was agreed up front." | Decision detail |
| "Your decision is recorded permanently. The same piece of work then carries on — nothing is restarted." | Needs you + Decision detail |
| "Pick one. Your choice is saved with your name and cannot be changed afterwards." | Decision detail |

Shortened: `"2 things need your approval. Everything else is running normally."`
→ **`"2 things need your approval."`**

**One reassurance was deliberately kept:** `This cannot be undone.` directly
under the commit button. Irreversibility is a consequence the user needs at the
moment of acting — that is not self-justification.

**Standing rule adopted:** the UI states facts and consequences. It does not
argue for its own trustworthiness. Provenance belongs in the technical layer.

### 12.5 Measured after round 2

**3 boards · 0 major findings · 0 jargon violations · 147 distinct strings**
(126 plain, 18 labelled `ref …`, 3 in the disclosed layer).
Superseded by §11's full 10-board set.

---

## 13. FILE CLEANUP — 2026-09-15

Human instruction: *"remove the old unused pages."*

### 13.1 Removed (17 shapes)

| What | Count | Why safe |
|---|--:|---|
| `C · …` boards | 6 | Direction not selected under `DCR-001` = `SELECT_B`; carried no authority |
| `D · …` boards | 6 | Same |
| Orphan shapes at page root | 5 | `Nav · Home Bg`, `Card Stroke · RUNNING NOW`, `Gate Blocking Tag · GD-5b1e`, `Timeline Time · 0`, `Dc Ctx Val · WORK ITEM` — debris that escaped their boards during the original build and is duplicated inside them |

The study's board inventory (§6 of the visual direction study) now carries a
deletion notice so it does not cite IDs that no longer resolve.

### 13.2 NOT removed — and why

Two sets were deliberately left in place. Both are one instruction away from
deletion, but deleting them now would destroy something load-bearing:

| What | Count | Why held |
|---|--:|---|
| `B · …` boards | 6 | **B is still the implementation-authoritative design.** `DCR-002`'s gate is unresolved and `DCR2-AC-6`/`AC-7` are unmet, so BP has no authority yet. `DCR-001` §8 is explicit: *"There is no interim state where the product has no authoritative design."* Deleting B before BP is approved creates exactly that state |
| Original 2026-09-14 lineage | 10 | These are the **only visual record of what the running Flutter app actually implements** (7/7 E2E, 8 golden tests baselined against them). `DCR-001` §4 preserves them by explicit decision and states *"History is not rewritten"* |

Both dependencies that previously required these boards are now discharged: B's
dark/light pairs were needed to derive the BP light palette (§11.0b, done and
recorded), and the original `Runs`/`Run Detail` were needed for their IA
(§11.0a, done).

**Recommended order:** delete `B · …` when `DCR-002` is approved; delete the
original lineage when BP is implemented and its goldens are re-baselined.

---

## 14. MOBILE — 2026-09-15

### 14.1 Constraints were read from the code, not chosen

Mobile was **not** a blank slate. The responsive behaviour is already implemented
and test-enforced, and `DCR-001` §5 holds it authoritative:

| Fact | Source |
|---|---|
| Breakpoint is `maxWidth < 840` | `apps/control_plane/lib/shared/app_shell.dart:14` |
| Mobile uses `Scaffold` + `bottomNavigationBar: NavigationBar` | `app_shell.dart:39` |
| **Exactly 3 destinations** — Home, Runs, Needs You | `app_shell.dart` destinations list |
| Rail and bottom bar are **never** both visible | `test/responsive/` — *"sidebar and bottom bar are never visible simultaneously"* |

Two consequences the design had to honour:

1. **No left rail on mobile.** The desktop rail is replaced, not shrunk.
2. **Run Detail and Decision Detail are pushed routes, not destinations** — there
   are only 3 tabs for 5 surfaces. They therefore get a **back affordance**
   (`‹ Needs you`) in place of the wordmark, and keep the bottom bar because
   `AppShell` wraps every route.

Designed at **390×844** — the most constrained real phone, well under the
breakpoint — rather than the 600×1024 the tests happen to use.

### 14.2 Built

| Board | ID |
|---|---|
| BPM · Overview · Dark | `f01f5bc4-…-a4e45ef58078` |
| BPM · Needs you · Dark | `f01f5bc4-…-a4e4d2067979` |
| BPM · Decision Detail · Dark | `f01f5bc4-…-a4e5019c8320` |

Row y=9800; x = 0 / 440 / 880. **0 major mechanical findings.**

Built from scratch rather than cloned — the layout is a different paradigm — but
using B's exact tokens read off `BP · Home · Dark`: Orbitron 13/700 wordmark,
IBM Plex Sans 24/600 → 10/400, IBM Plex Mono for identifiers, states and
eyebrows, and the full B palette.

### 14.3 Three structural decisions mobile forced

**1. Priority inverts.** Desktop Overview leads with metrics, then the table,
then approvals. Mobile leads with **approvals immediately after the counts** —
on a phone the only question that matters is "is anything waiting on me".

**2. Tables become cards.** A 5-column table cannot survive 390px. The activity
list became title / status / elapsed stacked per row with a status tick.

**3. The decision fits one screen — because the copy work made it fit.**
`390 − 56` (top bar) `− 80` (nav) leaves **708px**. The full decision — question,
status, 3 facts, the design preview with links, 3 options with their durable
routing, reason field, commit button — fits in 688px. **Only because the verbose
copy was already cut.** Had the earlier register survived, this screen would have
required scrolling past the options to reach the button.

To make it fit, **2 of the desktop's 5 facts were demoted** (`WHAT'S NEEDED`,
`WHAT'S HELD UP`) to the technical disclosure. That is a deliberate trade, not an
omission: the three that remain are what the decision turns on.

### 14.4 What was NOT compromised

- **No quick-approve shortcut.** It was tempting to add "Approve" directly on the
  Needs you cards. It was rejected: it would let someone approve a design without
  opening it, which contradicts §12.2 — you cannot approve what you cannot see.
  Both cards route through `Review and decide`.
- **Durable routing still disclosed.** Each option still prints where it sends
  the work (`→ design_approved · the build can start`), per §12.2.
- **Blue still means interactive only** (§11.2), including the bottom bar's
  active state, which uses a raised pill rather than colour alone.

### 14.5 Contrast correction

9 neutral-text failures appeared and were corrected: neutrals tuned for the board
background (`#1F2120`) measured 3.84–4.32:1 once placed on card surfaces
(`#262827`, `#2D2F2E`). Corrected to `#8F8E88` / `#989792` / `#8A8983` at
4.52–4.62:1 using the same corrector every other board received.

### 14.6 Mobile review round — human feedback, 2026-09-15

All four items applied. One turned out to be a real containment bug, not a
spacing preference.

| # | Feedback | Applied |
|---|---|---|
| 1 | Logomark left of the SHIP IT wordmark | Cloned the **real image fill** from `BP · Home · Dark`'s `Brand Logomark` (media `c514c1fb-…-a48a2b732164`) rather than re-uploading — 22×22 at x=16, wordmark shifted 16→46. Not added to Decision Detail, which has a back affordance instead of the wordmark |
| 2 | LIVE dot not aligned with its text | Dot is now **measured** against the text's rendered bounds and centred on it, rather than positioned by eye: `dot.y = textRect.y + (textRect.height − dot.height)/2` |
| 3 | Button needs the same padding beneath it as the rest of the card | **This was a bug, not a margin tweak.** On `Needs you` the button ended 2px *below* the card it sits in — it was spilling out. Both boards now use a uniform 12px: `Needs you` card 280→286px, `Overview` card 124→132px, with the vertical rhythm below each reflowed |
| 4 | Badge sits slightly outside the pill and should be bigger | Replaced the 9px number with a proper **18px filled badge** — orange circle, dark `#241A02` numeral at 11/700 — anchored to the **icon's** top-right, not the pill's. It now overlaps the pill corner deliberately and reads as a notification badge in both the active (pill) and inactive states |

**Why the checkers missed #3:** `checkContainment` validates descendants against
the **board**, not against the card they belong to. The button was inside the
board, so it passed. A one-off check was written for this pass (does any shape
horizontally inside a card cross that card's top or bottom edge) and it now
returns clean — **this belongs in the durable suite as `card-spill`.**

**Re-verified after all four: 0 major findings on all 3 mobile boards.**

### 14.7 MOBILE COMPLETE — all 5 surfaces × dark + light, 2026-09-15

| Surface | Dark | Light | x |
|---|---|---|--:|
| Overview | `…a4e45ef58078` | `…a501409e8dd6` | 0 |
| All work | `…a50039e4f788` | `…a50141ecb46d` | 440 |
| Run Detail | `…a5005f8d88dd` | `…a501436f46ea` | 880 |
| Needs you | `…a4e4d2067979` | `…a50144986d11` | 1320 |
| Decision Detail | `…a4e5019c8320` | `…a50145a6e4e8` | 1760 |

Rows: dark y=9800, light y=10750. Column order now **mirrors the desktop row**.
**10 boards · 0 major findings · 5 brand-palette advisories.**

Light variants used the same B-derived map (§11.0b) plus four values the mobile
build introduced, each resolved explicitly: `#241A02`→`#241A02` (badge numeral
stays dark because the badge stays orange), `#989792`→`#6E706E`,
`#8F8E88`→`#6E706E` (thumbnail bar), `#F5F4F0`→`#1F2120`. 11 further neutrals
were then corrected to ≥4.5:1 by the standard corrector.

#### Two mobile-specific design decisions

**Filter chips became a single control.** Five chips
(`All work / Working on it / Needs you / Finished / Failed`) measure ~379px
against 358px of usable width. Rather than fake a horizontal scroll, `All work`
uses one `Showing: All work ▾` control. The filter set is unchanged; only the
means of reaching it is.

**List rows are 52px.** That clears the 44px touch-target guideline, which the
desktop's 46px table rows do not need to.

#### A verification that changed a design decision

The mobile radios were built as filled `#F5F4F0` circles with no stroke. Before
cloning to light I checked how the **desktop** handles them, rather than assuming
mine were right: desktop uses a `#FFFFFF` fill **plus a coloured stroke**, so the
stroke defines the circle and the fill deliberately matches the card. Mine would
have been invisible on a white card. Corrected to the desktop pattern, after
which the derived map handled them with no special case.

### 14.8 Bottom-nav review round — 2026-09-15

Human feedback: *"All Work and Needs you icons aren't vertically centered when
selected. And Overview looks a little offcenter too, but not as much as the
other. Also I'm seeing a lot of inconsistency between the Needs you badge count.
Some have backgrounds others don't, and most if not all are not vertically
aligned in the circle."*

**Both observations were correct, and the second was worse than it looked.**
Measured against the pill centre of 791:

| Glyph | Centre was | Off by |
|---|--:|--:|
| Overview (grid) | 789.5 | **1.5px** |
| All work (bars) | 788 | **3px** |
| Needs you (!) | 787 | **4px** |

The human's ranking — Overview least wrong, the other two worse — matches the
measurement exactly.

The badge was worse: **4 of 10 boards had no background circle at all**, and on
those same 4 the numeral was rendering at **9px/600 instead of 11px/700**.

#### Root cause: a helper that changed mid-build

`bottomNav` originally drew a bare 9px numeral with no background. It was fixed
during the first review round — but only the three boards that existed *then*
were retro-fitted. `All work` and `Run Detail` were built afterwards from the
still-unfixed helper, and their light clones inherited the defect. A later
normalisation pass set the badge's position and box but **not its font
properties**, because the node already existed — so the size stayed at 9px.

Fixed: all three glyphs centred on 791, every board given a background circle,
and the numeral forced to 11px/700 with the font variant resolved explicitly
(`IBM Plex Mono` does have a 700 variant — verified rather than assumed, per the
per-family weight lesson).

The numeral is now aligned by its **ink**, not its line box: `verticalAlign:
center` centres the line box, which left a sub-pixel offset that differed between
boards. Each numeral is now shifted by the measured delta between circle centre
and ink centre.

#### Why no existing check caught any of this

**Every board was internally valid.** Containment, overlap, overflow, legibility
and contrast all passed on all ten, because each board was individually fine.
The defect existed only *between* boards. Two checks were added:

| Check | What it asserts |
|---|---|
| `chrome-missing` / `chrome-drift` / `chrome-typography-drift` | A named shared component must be present on every board in a family, with the same layout box and the same font size and family |
| `optical-centring` | A glyph group that should read as centred in a container actually is |

**One false positive was found and corrected while writing the check.** The first
version compared the *rendered ink* (`textBounds`) and flagged every inactive nav
label, because an active label is weight 600 and an inactive one 400 — identical
chrome, legitimately different ink. It now compares the **layout box** plus font
size and family, and deliberately **excludes font weight**, which varies by state
by design. Both behaviours are regression-tested.

**Verified after the fix: all 10 mobile boards — chrome identical, glyphs
centred, 0 major findings.** Suite at **50 passing assertions**.

### 14.9 Mobile open items

- **Icon mismatch to flag:** the implementation uses `Icons.play_circle` for the
  Runs destination. Now that the surface is called **"All work"**, a list glyph is
  more apt — the mobile boards draw three bars. This is a small implementation
  change, recorded rather than assumed.
- **Touch targets:** option rows are 44px and the commit button 34px. 34px is
  below the 44px guideline; raising it is trivial but changes the vertical budget,
  so it is raised here rather than silently absorbed.

### 12.6 Still open

- **`PL-5`** — the expiry-invalidation semantics (§12.1).
- **`PL-6`** — the `description` policy (§12.3). **RESOLVED** (2026-09-15): enforced at
  `DurableWorkflowEngine.createWorkItem` — description required, ≥ 12 chars, distinct
  from `title` after trim. Legacy persisted null/blank descriptions MAY display
  `title` as fallback (no mutation / bulk migration). Recorded in `DESIGN-HANDOFF.md` §15.
  Rule: `packages/workflow_store/lib/src/human_facing_description.dart`.
- **"Machines and next steps"** on Home (`1 of 2 machines busy`,
  `running on this computer`) is infrastructure detail. Under `PL-1` it arguably
  belongs behind the technical disclosure. **Not moved unilaterally** — it is
  existing B content with real value to an engineer, so it is raised rather than
  deleted.

### 12.7 Implementation correction — 2026-09-15

The gate record (`DCR2-AC-7 = ADOPT_PLAIN`) is binding: this section is no
longer the current state of the code. Full record: `DESIGN-HANDOFF.md` §15.
Summary of what the Flutter surface now does:

- Nav = `Overview` / `All work` / `Needs you`; `play_circle` retired for a list
  glyph (§14.9 icon flag).
- Home H1 `Overview`; All work lanes + table headers + `Showing: All work ▾`
  mobile control; Needs you H1 copy; Run Detail plain timeline + `Review and
  decide` CTA bound to `blockingHumanDecisionId`; decision choices are wire
  values with human labels.
- `Description` gained presentation only (parse + display, fallback to `title`);
  **`PL-6` RESOLVED** — validation rule now enforced at domain boundary
  (`createWorkItem` required description ≥ 12 chars, distinct from title).
- Test-only dependency seam added to the five pages so real pages (not stubs)
  feed the goldens and accessibility suite; goldens re-baselined with decision
  detail states (pending, submitted) green.
- `flutter test` 62/62, `dart test -j 1` (server) 62/62, real generated-client
  E2E 3/3. The `StatusChip` semantics advisory (DCR2-AC-6 MINOR) is fixed
  under test.
- Transition timeline: plain by default, raw pair always shown as technical
  detail line; snake_case wire values; unknown pairs → neutral fallback.
  Full coverage: `transition_copy_test.dart` (16+ tests).
- Decision Detail `?wi=` wiring carries workItemId through deep links; real UI
  Playwright E2E proves the full resolve flow end-to-end.
- Independent review: no P0; P1 items addressed (security doc, regression
  canary for generated client patch).

### 11.5 Honest note on the jargon checker

The first automated jargon audit reported 10 violations. **7 were false
positives in the checker, not defects**: a keyword blocklist flagged the ordinary
English word "record**ed**" as jargon, and matched the brand name `ShipIt` as
CamelCase code. Only 3 were real (identifiers printed without the `ref` prefix).
The checker was corrected before any number above was recorded.

---

## 15. ADJACENT SURFACES — DEPENDENT WORK, NOT THIS DCR'S SCOPE

Folded 2026-09-15. Full analysis and grounding: `DESIGN-HANDOFF.md` §12. Four
**post-gate** surfaces build on top of whichever direction the gate adopts; none
of them is a DCR-002 acceptance criterion or gate-blocker.

| Surface | Status | Blocks on |
|---|---|---|
| Report bugs | Spec complete, parked — `HUMAN_BUG_REPORTING_001` (`002`), **R4** parked on visual-language selection | Gate outcome → build against adopted direction; R3: `designDefect` remediation needs the 003 lifecycle |
| Queue new work | No mechanism — write endpoint + project/feature registry needed | Candidate checkpoint `005` |
| Ask / direct the agent | No mechanism — `HumanDirection` contract + UI Inbox needed (ADR) | Candidate checkpoint `005` |
| Launch / onboard a project | No mechanism — persist `ProductManifest`, registry, onboarding flow | Candidate checkpoint `005` |

Note: adopting plain language **unparks 002** (the bug-reporting design builds on
the adopted visual language). The other three are new scope.
