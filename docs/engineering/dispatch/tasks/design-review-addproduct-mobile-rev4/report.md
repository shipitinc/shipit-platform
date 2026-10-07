# Report — Independent Focused Re-Review, mobile Design Revision 4 (Gate D3, cycle 4)

Persisted per `aef-orchestrator` §14. Reviewer: `focused-reviewer`, read-only.
REVIEWED_HEAD `77c19f1`; REVISION_ID `A69AB98C-A672-4D98-9DCE-0F089D55A9B5`. `main` at review time `361256c`.

```
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
BLOCKERS: NONE
HIGH: H-1
MEDIUM: M-1
LOW: L-1
CORRECTION_REQUIRED: YES
HUMAN_DECISION_REQUIRED: NO
INDEPENDENT_RISK_LEVEL: 2
RISK_LEVEL_AGREEMENT: YES
```

## Four of the six dispatched items are genuinely closed, verified at the property

- **M-R1 CLOSED** — the false annotation is gone from § 3.2; the row now names `Art K`, its surface and the
  FAIL. Reason (c) present in `ux_accessibility_score_reason` with the surface named. **N10** filed, Level 1,
  routed to the design-system owner exactly as N2 routes `negative`. **G13** added; N7's withdrawal narrowed
  to "for the `TechnicalDetails` lines only" with an explicit M-R1 counter-example. Source verified exactly:
  `design_primitives.dart:320` = `color: palette.card,`; `add_product_page.dart:533`/`:1029` =
  `color: palette.inkTertiary,` inside `MicroLabel('DEPLOY KEY  ·  THIS PRODUCT ONLY',` at `:531`/`:1027`.
  Contrast recomputed independently (sanity black-on-white 21.00, white-on-white 1.00):
  `inkTertiary`/`card` = 4.99 / **4.23 → AA FAIL in dark**.
- **M-R2 CLOSED** — the cell now names the build's `palette.inkTertiary` (`add_product_page.dart:918`
  verified exact), carries the **identical surface note** the `Submit` row carries, gives **both** surfaces'
  ratios, and states explicitly **which the board keeps**. All figures reproduce independently.
- **M-R3 CLOSED as of the pass** — the cell now reads `9417f8bf (PENDING D4)` with `b869ec24` scoped to
  server-side storage. Confirmed `9417f8bf` was cited **0** times in rev 3 and now appears twice, both inside
  the new header/pointer block, so **no body text gained it**. The lane made **zero board writes**, so it
  cannot have written an answer into a layer. **But see H-1(a): the decision has since been resolved, which
  makes this cell stale.**
- **L-R1 CLOSED** — now names `design-revision-3.md` §0/§12 and `correction-report-3.md:261-281`; confirmed
  rev 3's `§ 13. Assumptions carried forward` contains no learning and carries an in-place pointer saying so.
- **L-R2 CLOSED** — § 11's G11 row struck with the closing citation; `non_requirement_gaps` omits it.
- **L-R3 NOT CLOSED** — see M-1.

**Provenance gap § 15 discharged.** `report-revision-3.md` did not exist when the producer wrote (mtime
09:51, after rev 4's 09:50) — the producer's claim was accurate and reporting rather than authoring it was
correct. It is now committed. Its six findings plus L-R4 are **exactly** rev 4's four header items plus § 14's
seven rows; nothing was omitted from the dispatch.

**Regression check: rev 3 is intact.** Zero body lines changed, verified. Supersession header at `:3-25` and
exactly four in-place pointer blocks; every rev-3 defect survives verbatim in the body and no pointer
contradicts it.

## H-1 (NEW) — three Gate D4 decisions were resolved 63 minutes after this revision was written

Rev-4 artifacts written **09:49–09:50 EDT**; commit `674b871` at **10:52:53 EDT** is an ancestor of `main` and
**not** of `77c19f1`. **The producer could not have known — this is staleness, not misstatement.** But the
revision's load-bearing status cells name resolved decisions as open, and one board string is now false.

**(a) `9417f8bf` is RESOLVED (OPTION_C, A3 external secret manager) — and `Art S`'s string is now FALSE.**
The board reads `ed25519 · private half stays server-side` on all four boards. **Under A3 that is false: the
private half is not held by SHIP IT at all.** The lane itself designated that layer "the single string
parameterized on the at-rest protection model" — so the one element correctly held open is now the one
element that is wrong, on four boards, in user-facing security copy. The `PENDING D4 (at-rest model)` marker is
stale. § 6's cell, § 8, § 11's G2 and assumption A8 all still state it is open. Two `owner: design-agent`
follow-ups are unaddressed: **remove `referenceName` from `RepositoryCredentialView`** (the resolution states
this is now **REQUIRED**, not optional) and **design the A3 unavailability path with remediation copy** (the
substrate "can be down, so this is a common case, not an edge case").

**(b) `27ea6536` is RESOLVED with a normative footer spec, and the revision still calls it open.** The
metadata lists as a **future** 3-escalation trigger the very thing the human has now confirmed. The decision's
`supersedes_design_lane_reading` states the lane's coordinate-based reading of a `Footer` layer at (236,862)
"should be treated as a misidentification" — and `design-revision.md:168-171` still asserts it. The inherited
R3 spec still specifies desktop as `Row[copy note, Show technical details ▸]`, **directly overruled**, and says
"keep `:316-328`", which is where the copy `note:` lives. **Alignment, which the human made normative, is
specified nowhere in any artifact.** § 6's `Disclose` row names only "human 2f" as its authority — under M-R3's
own rule that is the same defect one row away. § 10 still files `TechnicalDetails`' unconditional
`ContentRule` — the divider the human ruled must **not** be on mobile — as AMBIGUOUS rather than settled.

**(c) `898b07d0` is RESOLVED and appears ZERO times in the artifact set** (also no hits for "split identity",
"already exists", "half-registered"). Its follow-ups are unaddressed: carry the "visible half-registered
product" consequence into the UI so **the user can tell a product exists but is not yet usable**, and
**re-ground the Unknown-host boards' step order and copy** because the product row now exists before trust.
The Unknown-host boards carry the product fields but **no element conveying that state**; the
`· PROVISIONAL (G1 hostUnrecognised)` marker is an internal annotation, not user-facing.

**Required:** record the three resolutions; correct § 6's `Art S` and `Disclose` cells, § 8, § 11's G2 and A8;
state the governing footer spec (desktop = divider + **right-aligned** `Show technical details**, no copy;
mobile = **left-aligned**, **no divider**, no copy) and mark the `Footer`-at-(236,862) reading withdrawn in
place; re-ground the Unknown-host pair per `898b07d0`; route the two `9417f8bf` design-agent follow-ups.
**This pass cannot be record-only** — `Art S` needs a string and marker edit on four boards, and `898b07d0`
may need an Unknown-host redraw.

## M-1 (NEW) — L-R3 not closed, and revision 4 committed the exact error it was correcting

Every published line number is **low by exactly 6**, in both files, and points at unrelated text:

| § 0.1 / § 7.1 publishes | What is actually there |
|---|---|
| `design-revision.md:77`, `:79` | `ShipItType._lh = 1.2`; the table header. The quoted strings are at **`:83`** and **`:85`** |
| marker at `:83-89` | `:83` **is** the disproven row; the marker starts at **`:89`** |
| F8 row at `:429`, marker `:431-438` | F8 row is at **`:435`**, marker **`:437`** |
| `report.md:62`, `:120`, `:224` | "Plus four Penpot boards (not git)…", a `What you're registering` bullet, a `penpot:` board-id line. The claims are at **`:68`**, **`:126`**, **`:230`** (markers `:70`, `:128`, `:237`) |
| provenance note at `report.md:26-31` | it starts at **`:31`** and ends at **`:37`** — and rev 4's own `report.md:12` says "lines 31-37", so **revision 4 contradicts itself** |

Propagated into four further places: `design-revision.md:6-7`, `report.md:7` and `:12`,
`design-revision-3.md:377`. One claim in § 1.2's table **does** hold: `design-revision-metadata.yaml:15-16`.

**This matters beyond bookkeeping:** revision 4 wrote § 12.1 rule 6 in the same pass — *"A cross-reference is a
claim about a file; re-read it like one — including after you edit the file it points into. A marker written
at a cited line moves that line."* Six citations plus two self-describing headers now name unrelated lines,
and the fix intended to make them resolvable made them unresolvable in a new way.

## L-1 (NEW)

Two missing in-place pointers in rev 3, against the lane's own rule that retention without a marker is not
neutral: `design-revision-3.md:551` still lists **G11** as an open gap although rev 4 closed it, and `:444-445`
still says B3 "remains filed as Human Decision `27ea6536`", now resolved.

## Confirmations

**`RISK_LEVEL: 2` independently agreed.** This pass's *marginal* risk is **Level 0**: zero boards, layers,
shapes, tokens, interactions, navigation, IA surfaces or primary-action structure touched. The revision's
cumulative risk argument is unchanged and concurred at 2. **Risk must be re-assessed next pass**, which cannot
be record-only and whose `898b07d0` work interacts with G1 — already flagged as a 3-escalation condition.

**Self-assessment accepted with a caveat.** Every score carries a stated reason rather than being rounded,
reason (c) is present and names its surface, and feasibility stays MEDIUM precisely because `flutter analyze`
was not run. **No gate the producer did not run was accepted.**

**Decisions absent at `77c19f1` — confirmed, nothing depends on it.** `git grep -c` at `77c19f1` returns **0** for
`9417f8bf`, `27ea6536` and `898b07d0`, against 4/3/4 at `064703d` and 19/15/… at `main`. Every
decision-dependent conclusion was re-derived from the files at `main`. **Critically the source citations hold**:
`git diff --name-only 77c19f1 361256c` shows **all five Flutter files revision 4 cites are UNCHANGED**, so every
`:NNN` citation into `apps/control_plane/**` is still valid at `main`.

## NOT_RUN — and a material limitation

**Penpot board verification — NOT_RUN.** Two `penpot_execute_code` calls returned *"No Penpot instance connected
for user token."* `penpot_high_level_overview` was read first as required. The reviewer could **not**
independently verify against the live file: `Art K`/`Art Bg` fills and containment, `Submit Sub` fills and its
y-bounds against `Trust Bg`, the layer counts, `Trust Btn L align: center`, `Nav Label 3` w600, and — the one
M-R3 explicitly demanded — **`Art S`'s live string and its `PENDING D4` marker**. Those are verified only by
proxy: rev 3's retained read-back table, `penpot-board-evidence.md`, rev 4's own § 9.1, and the zero-write
evidence. **Every board-read claim the revision makes should be treated as unconfirmed by this reviewer.**

`flutter analyze` NOT_RUN · any Docker or Compose command including `docker info`/`compose ps|logs|config`
NOT_RUN, none issued, **no breach** · Flutter widget render, visual diff, export comparison NOT_RUN · rev 3's
pre-edit board state not re-verifiable (the Penpot API exposes no version history) · nothing persisted.

## SAFE_PARALLEL_WORK

**SAFE** — independent review of the sibling keys revision (disjoint paths; **its revision 2 also predates
`674b871`** and needs the same staleness treatment for `898b07d0`/`9417f8bf`) · NON-UI implementation
preparation on `add_product_page.dart`: mock-key removal, the missing `AccessStatus.verified` producer,
first-ever test coverage, and the copy corrections still false at `:383`, `:385`, `:539`, `:1035`,
`product_detail_page.dart:614` — **all five files are unchanged between `77c19f1` and `main`, so those line
numbers hold** · implementation of H-N1's centring and M-N4's active-nav weight.

**PROHIBITED** — **Design Contract freeze of revision 4**: three decisions are stale, one of four board strings
is false under A3, the footer spec is contradicted by a resolution, the Unknown-host state has an unapplied
human requirement, and six cross-references name unrelated lines · any lane editing this lane's task directory
or the four `SM - Add Product` boards, or `BPM · Add Product · Light/Dark`, or the `S · Add Product · …` boards ·
any lane editing `.decisions/**` · implementation of the footer or the `Art S` copy against rev 4's spec, which
is superseded.

## Judgement

**This is not the revision the four findings make it look like, and it is not freezable.** Four of six items are
genuinely closed and verified at the property — M-R2 in particular is now the honest acceptance baseline its own
review demanded. But revision 4 was written at 09:50 EDT and the human resolved three Gate D4 decisions at
10:52 EDT, so its status cells, one of four board strings, its footer specification and its Unknown-host state
are all overtaken — and M-R1, the item this pass exists to enforce, is the discipline it failed: an annotation's
*removal* was verified, but the numbers written in its place were not. **The next pass is not record-only and
carries board edits.** `9417f8bf` and `27ea6536` need nothing from the human — both are resolved and name this
lane as owner — so nothing here is a `HUMAN_DECISION_REQUIRED`.
