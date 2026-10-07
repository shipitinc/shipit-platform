# Design Revision 5 — Add Product mobile state boards, correction pass 4: the three resolved decisions, applied

Per `docs/engineering/DESIGN_GOVERNANCE.md` § *Artifacts → Design Revision*. Metadata in
`design-revision-metadata-5.yaml`. Traceability in `traceability-matrix-5.md`. Board evidence in
`penpot-board-evidence.md` §6.2 / §6.3 / §6.4.

```yaml
revision_id: CB4BEECA-CA9D-4F26-9464-E1B6F7C9BDCB
brief_id:    52CB4098-FF87-4B78-81DA-1104269551A1
revision_number: 5
supersedes:  A69AB98C-A672-4D98-9DCE-0F089D55A9B5   # revision 4, retained; its body is unedited
status: UNDER_REVIEW          # the Design Agent never approves its own work
risk_level: 3
```

**Provenance.** Worktree `/private/tmp/shipit-correct-addproduct-mobile`, branch
`design-correct-addproduct-mobile` (`git branch --show-current`), `BASE_SHA` = `HEAD_SHA` =
`289f1d33dcf1a2f24ead765c9e573b2f1ba1f107`. Nothing committed, nothing pushed. **No Docker or Compose
command was run at any point in this pass**, including read-only ones. `flutter analyze` **NOT_RUN**; no
Flutter widget rendered.

---

## 0. What this pass is, and the one thing it is not

Revision 4 was returned `DESIGN_REVIEW_CHANGES_REQUIRED` with findings **H-1**, **M-1** and **L-1**. This
revision closes all three. It is the pass the rev-4 reviewer predicted: **not record-only, and carrying
board edits.** Four live Penpot boards were edited; §3 and §5 carry the measured before/after.

**What this pass is not.** It is not a new design. Every normative outcome it implements was already decided
by the human in three RESOLVED decisions. This revision's job was to make four boards, a design contract and
~30 record sites agree with decisions that were resolved **after** revision 4 was written, and to hand
implementation and QA an acceptance baseline that is true.

### 0.1 Reconciliation of the in-place edits to revisions 1–4 — the decision and the reasoning

A prior invocation of this dispatch was cancelled mid-flight. It applied the board edits and edited
revisions 1, 3, 4, `report.md`, `design-brief.md` and `penpot-board-evidence.md` **in place**, and was
killed before writing any revision-5 artifact. Those edits were uncommitted and unattributed. Reconciling
them was this pass's first job, and the answer is **not** "revert them all".

**The rule that decides it** is this lane's own, already persisted and already reviewed as correct:
`design-revision-3.md` §0 / §12 and `design-revision-metadata-4.yaml`'s § 0.2 — *byte-identical retention is
legitimate for diffability, but **retention without a marker is not neutral**, because whichever file a reader
opens first is the only file they read.* The Gate-D3 review of revision 4 held revision 3 against exactly this
standard and recorded **"Regression check: rev 3 is intact. Zero body lines changed, verified"** as the
*positive* result.

So the operative convention is **not** "earlier revisions are frozen files". It is: **bodies retained intact,
headers and in-place pointers corrected.** Reverting the cancelled lane's edits would have reinstated the
defect M-1 exists to close — a reader opening `design-revision.md` first would again see stale line numbers
with nothing pointing anywhere.

| Site | Cancelled-lane edit | Decision | Why |
|---|---|---|---|
| `design-revision.md:3` header | pointed at `design-revision-4.md` | **CORRECTED** to `design-revision-5.md` | a supersession header that names the wrong current revision is worse than none |
| `design-revision.md:9-13` | M-1 numbers → `:83`, `:85`, `:435`, markers `:89-95`, `:437-444` | **KEPT** | re-read by me at `289f1d3`; all five numbers **exact** (§8) |
| `report.md:9-13` header | M-1 numbers → `:68`, `:126`, `:230`, markers `:70-74`, `:128-133`, `:237-243` | **KEPT** | re-read by me; all six **exact** (§8) |
| `report.md:3-4` header | still pointed at rev 4 / `correction-report-4.md` | **CORRECTED** | as above |
| `design-revision-4.md:3-10` | supersession preamble | **CORRECTED** — now states it is superseded and that rev 5 changed four boards | rev 4's "this pass changed no board" was true of rev 4 and would have read as true of the current revision |
| `design-revision-4.md` § 0.1 | 3-column re-measured M-1 table | **KEPT, with the Δ table it introduced** | verified; and the `+6`-is-a-trap table is the load-bearing part |
| `design-revision-4.md` L-R1 row | corrected `:558`→`:633`, `:37-39`→`:60-62`, `:535-554`→`:610-629` | **KEPT, then RE-MEASURED to `:646` / `:623-644`** | verified by me; `:633` went stale under this pass's own edit to rev 3 — see §9 |
| `design-revision-3.md:377-386` | re-published M-1 pointer block | **KEPT** | verified (§8); `:377-386` re-read after this pass's own edit to rev 3, which sits **below** this block |
| `design-revision-3.md:452-486` | L-1 pointer for B3 + G2 | **KEPT BUT SUBSTANTIALLY CORRECTED** | it asserted the desktop boards carry **no footer copy**. They do. See §4.4 and finding **F6** |
| `design-revision-3.md:583` (G2), `:592` (G11) | struck in the gap table | **KEPT** | both gaps genuinely closed; verified, **and re-measured after this pass grew rev 3 by 13 lines** |
| `design-revision-metadata-4.yaml:42-45` | two escalation triggers struck as fired | **KEPT** | `27ea6536` and `898b07d0` are RESOLVED and both fired. Verified |
| `design-revision-metadata-4.yaml:149-153` | L-R1 citation numbers corrected | **KEPT** | verified |
| `design-brief.md` | SC-2 widened; SC-6…SC-9 added; open question closed | **KEPT** | SC-6/7/8 are met and verified; **SC-9 is recorded NOT MET** — see §6.2 |
| `penpot-board-evidence.md` §5/§6/§6.2/§6.3 | regenerated; new §6.2, §6.3 | **KEPT BUT §6.2, §6.3 CORRECTED** | §6.3 published two stale numbers as measured; §6.2's width arithmetic was internally inconsistent. See §3.2, §7.2 |

**Nothing the cancelled lane did was deleted, and nothing false was left standing.** Two false claims were
found in its work and corrected in place, with the correction visible rather than silent: the desktop
"no copy" claim (§4.4) and §6.3's `Key State` / `Art S` rows (§7.2).

**One lesson from this that belongs with M-1.** The cancelled lane verified the board *edits* by re-reading
them, and then published a *comparison table* in §6.3 without re-reading the values it was comparing —
carrying `Key State = 138,436`, the value **before** its own edit moved it to 446. A verified edit followed
by an unverified claim about the edit is the same defect M-1 charges, one layer up. § 12.1 rule 6 of
revision 3 already said it; revision 5 now has an instance of it.

---

## 1. The three resolved decisions, recorded

Re-verified directly this pass, not inherited. All are RESOLVED, all are `decided_by: repository owner
(interactive structured question UI, session orchestrator-main)`, and all name `design-agent` as a follow-up
owner. **The Level-3 human gate is discharged and is not re-opened.**

| Decision | Type | Selected | `decided_at` | `design-agent` follow-ups |
|---|---|---|---|---|
| `9417f8bf` | SECURITY | **OPTION_C — A3, an external secret manager** | `2026-10-06T13:05:00Z` | **2** |
| `27ea6536` | DESIGN | **OPTION_A as nearest equivalent** — copy removed on both platforms, per-platform alignment **new** | `2026-10-06T13:05:00Z` | **3** |
| `898b07d0` | ARCHITECTURE | **OPTION_A — split identity from registration** | `2026-10-06T13:05:00Z` | **2** |
| `ae1c1f79` | ARCHITECTURE | **OPTION_A — refusal creates nothing** | `2026-10-06T13:50:00Z` | **2**, one naming this lane |
| `7b1bc8b7` | SECURITY | **OPTION_A — fail closed, with remediation** | `2026-10-06T13:05:00Z` | **1** (copy) |

**`9417f8bf`, verbatim from `resolution.rationale`:** *"The human chose to SUPERSEDE ADR 0018 :85-88's
local-secret-store clause and adopt **A3, an external secret manager** - SHIP IT never holds key bytes, only a
reference, and asks the manager for the material at push time."* And consequence (3): *"**A3 makes the
reference the most sensitive artifact SHIP IT holds**, because an ARN or secret path discloses vault
topology. That is gap G-7: RepositoryCredentialView currently exposes referenceName to clients. Removing it
is now REQUIRED rather than optional, and is a generated-contract change in two packages."*

**`898b07d0`, verbatim:** *"**Split identity from registration.** The key flow creates the Product row (state
registered) plus the RepositoryReference as an explicit first step; 'Register product' then commits
credential verification."* And the accepted trade: *"The known trade, accepted: leaving the page early leaves
a visible product with no usable credential."*

**`ae1c1f79`, verbatim:** *"**Refusal creates nothing.** The substrate precondition is evaluated before any
write."* And its follow-up naming this lane: *"State the consequence for the mobile boards: after a refused
mint the Products list is unchanged, so the Unknown-host state must not imply that a product was created."*

---

## 2. Scope, and the risk level

**Risk level 3**, re-derived from `DESIGN_GOVERNANCE.md` against what this pass actually did — not inherited,
and not asserted on an artifact that does not exist. Three independent clauses of the Level-3 definition are
met, each reached by my own reading:

1. **Core workflow / user mental model.** `898b07d0` splits identity from registration, so the Add Product
   primary action changes meaning from *creates the product* to *commits verification of a product that
   already exists*. Two of the four boards' headline eyebrow strings were rewritten for this reason.
2. **Information architecture.** The accepted consequence (a visible product with no usable credential) required
   a **new user-facing element** on the Unknown-host pair — `Trust Created` — which did not exist in any
   previous revision of this design.
3. **Navigation structure.** R.11g item 3 requires the flow be re-enterable **from the product**, which is a
   resume route on `ProductDetailPage` that the Products list does not have. This revision specifies that
   affordance (§ 4.5) even though the board that would render it is not in this lane's ownership.

**The gate is discharged, and the decisions moved the risk into this lane as a mandate rather than out of
it.** The rev-4 reviewer was right that revision 4's *marginal* risk was Level 0; that is inapplicable here,
because this pass carries board writes and Level-3 content.

**One residual component is NOT human-decided, and it is not a gate.** The human's mobile footer spec — no
divider, left-aligned — is not expressible with `TechnicalDetails` as built (§ 4.3, finding **D-2**). Choosing
between a new primitive parameter and a mobile-local footer widget belongs to the design-system owner: a
**Level 1** notification, AUTO per Gate D4. The human has already decided the *outcome*, so this is a
component choice, not a gate. **It does not raise this revision's risk, and it does not require the human.**

---

## 3. H-1(a) — the custody string, on four boards and ~30 record sites

### 3.1 The correction

`9417f8bf` settles that SHIP IT holds **no key bytes at all**. The string the boards carried —
`ed25519 · private half stays server-side` — is therefore false in the strongest available way: it asserts
SHIP IT holds the private half on its own server, when the private half is not SHIP IT's.

**Adopted string, all four boards** — this is `N-9`'s, binding on this lane via the sibling's R.11g item 4, and
verified verbatim against § R.10.2 of the sibling's revision 5:

```
ed25519 · generated on the server · the private half stays in the secret manager
```

### 3.2 Measured before / after, all four boards, re-read from the file

| | Before | After |
|---|---|---|
| `Art S` characters | `ed25519 · private half stays server-side` (40 ch) | the `N-9` string (80 ch) |
| `Art S` layer **name** | `Art S · PENDING D4 (at-rest model)` | **`Art S`** |
| `Art S` box | `138,418 220×15`, one line | `138,418 220×24`, **two lines** |
| `Key State` `parentY` | 436 | **446** |
| `Art L1` / `Art L2` `parentY` | 456 | **466** (card bottom 486 → 4px slack) |
| `Art S` fill | `#5a5c5b` / `#a8a6a0` | **unchanged** — `inkSecondary` |

The `PENDING D4` and `PROVISIONAL` marker suffixes were retired from **all sixteen** layer names. Independent
re-read this pass: **zero** shapes on any of the four boards carry a layer name matching `PENDING D4` or
`PROVISIONAL`, and **zero** text layers match any of the ten forbidden strings. Counts and positions are in
`penpot-board-evidence.md` §3 and §6.

**Because the wrap grew the line, the two rows below it moved and the card did not.** `Art Bg`
(`16,370 358×116`) was deliberately not grown, so the card stays geometrically identical to `BPM`'s. This is
the geometry the §6.2 width correction in the evidence file describes; **the exact rendered pixel width is
NOT claimed**, because Penpot's `textBounds` scale could not be reconciled against `parentX` (§ 14).

### 3.3 The ~30 record sites, not four

**D-1 stands: a four-cell fix would be returned for the same defect class a fifth time.** Swept: `design-brief.md`
(the open question, now closed, retained verbatim as the record of the question as it stood),
`penpot-board-evidence.md` §5/§6, `design-revision.md`'s retained header, `report.md`'s retained header, and
revisions 2, 3 and 4 — each with **in-place pointers**, never a rewritten body. Rev 4's § 6 `Art S` cell,
§ 8, § 11's G2 and assumption **A8** are all superseded; **A8 was stale twice over** (status *and*
provenance: rev 4 asserted the decision objects were absent at `77c19f1`, and all of them are present at
`289f1d3`).

### 3.4 Two sites this lane does **not** own, reported not fixed

| Site | Carries | Why it is not mine |
|---|---|---|
| `BPM · Add Product · Light/Dark` `Art S` | `ed25519 · private half stays in the keychain` — false under A3 for the same reason, and identical to the build's | `BPM` is read-only to this lane. Finding **F5** |
| the four `S · Add Product · …` boards | the now-false `NOT REGISTERED YET` eyebrow | read-only. Same class as F5 |
| `add_product_page.dart:542` **and** `:1038` | `ed25519 · created on this device · the private half stays in the keychain` — **two** false halves | production source. Finding **D-4** |

**D-4's precision matters: the build's `:542` is a separate production correction and is NOT the same edit as
the board's.** `:542` is false in two ways (the "on this device" half from `b869ec24`, the "keychain" half
from `9417f8bf`); the board was false in one. Re-read and confirmed at `289f1d3`.

**D-5 — `N-9` contradicts itself, and this revision did not silently pick a side.** `N-9`'s normative *rule*
says copy must *"name no substrate"*; its own prescribed string says *"the private half stays in the secret
manager"*, which names one. Its prohibition list bars `the keychain`, `the vault`, and any manager name or
address. The consistent reading is **generic category permitted, identity prohibited**. **This lane adopts
the prescribed string verbatim** — it is a binding consumption-contract item and not this lane's to
reinterpret — **and flags the tension for the keys lane.** No rewrite was performed to satisfy the rule
instead.

### 3.5 Why this is D-7, not a Level-0 detail

This is **security copy shown to a user**. It asserts where a private half lives. N10's routing already teaches
the lesson this lane learned the hard way: *a false AA annotation is worse than a reported one, and a false
custody claim shown to a user is the same defect in a worse field.* It was treated as a finding requiring
board writes, not a copy tweak.

---

## 4. H-1(b) — the footer, specified per platform, and D-2/D-3

### 4.1 The governing specification, quoted from `27ea6536`'s `resolution.rationale`

> - **Desktop** (`S - Add Product · Unknown host · Light/Dark`, `S - Add Product · Verified · Light/Dark`):
>   a divider, and a **right-aligned** `Show technical details` text button. **No footer copy.**
> - **Mobile** (`BPM - Add Product · Light/Dark`): a `Show technical details` button **left-aligned, with
>   no divider**. **No footer copy.**
> - *"Stay true to both designs in Penpot and in code"* — the boards are authoritative; the build must
>   not invent a third footer, and the two platforms are genuinely different rather than one being a
>   mistake.

The human's `"righ aligned"` / `"now divider"` are typos; the decision's own `rationale` renders both
correctly and unambiguously. **No human gate is needed and `27ea6536` is not re-raised.**

### 4.2 The build change, specified to the line

| What | Where — **re-read at `289f1d3`**, `git diff --name-only 43d328b 289f1d3 -- apps/control_plane packages` returns **empty** | Change |
|---|---|---|
| `_buildFooter` — **definition** | `add_product_page.dart:375` (`Widget _buildFooter(BuildContext context) {`) | **delete** |
| `_buildFooter` — **call site** | `:314` (`_buildFooter(context),`) | **delete** |
| the footer copy it renders | `:383` — *"Your decision is recorded permanently…"* | **delete with it** |
| desktop `TechnicalDetails` `note:` | `:317-319` | **`note: null`** |
| mobile `TechnicalDetails` `note:` | `:926-928` | **`note: null`** |
| desktop `TechnicalDetails` site | `:316` | unchanged; renders with no `note` |
| mobile `TechnicalDetails` site | `:925` | unchanged; renders with no `note` |

**D-3 — "no footer copy" is TWO `note:` sites plus a `_buildFooter`, not one.** Both platforms pass
`TechnicalDetails(note:)` with the **same string**. Verified: desktop `:318` and mobile `:927` both read
`'Registering records the product. Nothing is governed until you approve a baseline.'` This is why the
implementation is **three** edits, not the "one line" earlier estimates carried. **This lane's own artifact
set repeated the false claim that mobile has no `note:`** before revision 5, on the authority of
`27ea6536`'s context; the sibling has since corrected it itself (its § R.11g item 7, finding L8). Reported
here because the correction belongs in this lane's records too.

### 4.3 D-2 — the load-bearing engineering consequence, and why it is Level 1 not a gate

**Measured at `apps/control_plane/lib/shared/design_primitives.dart` — note the true path is
`lib/shared/`, not `lib/core/`.** No artifact in this set asserted the wrong path; verified by `find`.

```dart
362:  const TechnicalDetails({super.key, required this.lines, this.note});
...
396:          const ContentRule(),          // ← painted UNCONDITIONALLY
397:          const SizedBox(height: 13),
398:          Row(
399:            crossAxisAlignment: CrossAxisAlignment.start,
400:            children: [
401:              Expanded(
402:                child: widget.note == null
403:                    ? const SizedBox.shrink()
404:                    : Text(widget.note!, …),
410:              ),
411:              InlineLink(micro: true, label: 'Show technical details', …),
```

Two consequences, and they are opposite:

- **`note: null` ⇒ `Expanded(SizedBox.shrink())` consumes the width ⇒ the `InlineLink` is pushed to the
  end.** With `:396` always painting the rule, `note: null` yields **divider + right-aligned button** —
  **which is exactly the human's desktop spec, produced for free, with no new parameter.**
- **Mobile's spec is the opposite on both axes and is NOT expressible today.** `:396` always paints the rule,
  and the `Expanded` always pushes right.

**Therefore F4 escalates from an observation to a specified shared-primitive requirement:
`TechnicalDetails` must be able to (a) suppress its `ContentRule` and (b) align its disclosure
start-aligned.** It is a primitive used by defect list/detail, feature-request list and `plain_language.dart`,
so the choice is **Level 1, design-system owner** — routed in § 6, not to the human. The human decided the
outcome in `27ea6536`; only the mechanism is open, and this revision specifies the requirement rather than
the mechanism.

### 4.4 F6 — the desktop boards do not conform to the desktop spec. NEW, and it is a blocker.

**Measured on all four `S · Add Product · …` boards, read-only. `penpot-board-evidence.md` §6.4.**

| `27ea6536` desktop clause | Measured | Verdict |
|---|---|---|
| a divider | `Footer Rule`, rel 236,848, 1020×1 | **SATISFIED** |
| a **right-aligned** disclosure | `Disclose` rel 1036,862, 220w → right edge 1256 = `236+1020` | **SATISFIED** |
| **no footer copy** | a `Footer` **text** layer at rel 236,862, 1020×15, `align: left`, on **all four** boards | **NOT SATISFIED** |

The **mobile** half of the same spec **is** satisfied on all four `SM` boards (§ 7.1).

**This is not a re-opening of `27ea6536`.** Its normative outcome stands without question and this revision
implements it: the build carries no footer copy on either platform. What this is: a **CONTRADICTION between
the resolved decision's outcome and the boards that decision itself declares authoritative** (*"Stay true to
both designs in Penpot and in code"*). The four desktop boards cannot be the authority for a spec they do
not satisfy. `27ea6536`'s OPTION_B named this exact cost in advance: *"Requires `note: null` … **and editing
the four existing desktop boards, which no current lane owns** — so it needs a design-system-owner board
edit."*

**Two corrections to the record, both mine to make:**

1. `27ea6536`'s `supersedes_design_lane_reading` calls this lane's coordinate reading of a `Footer` layer at
   (236,862) *"a misidentification"*. **It is not** — the layer exists, at those coordinates, on all four
   boards; the divider is at (236,**848**). What the decision overrules is the lane's **conclusion**, not its
   **observation**. The observation is reinstated as measured. **The decision's outcome is untouched.**
2. The cancelled invocation of this dispatch asserted *"the desktop spec matches the four `S` boards … no
   copy"* and that (236,862) was *"the `Footer Rule` divider, not a text layer"*. **Both wrong.** Corrected
   in place in `design-revision-3.md` and in the evidence file.

**Escalated as an ownership blocker** — see § 12, N6b. Closing the gap needs a board edit on four boards this
lane does not own. **No board was edited and no decision is re-raised.**

### 4.5 R.11g item 3 — the resume affordance, specified here, renderable elsewhere

Binding from the sibling's § R.11g item 3: *"the Add Product flow must be re-enterable from the product, not
only from the Products page's 'Add product' control. Without this, the accepted consequence becomes a **dead
end** — the exact failure human point 2d objected to, arriving by a different route. This is a **requirement
on the sibling lane's design**, not an observation: `ProductDetailPage` needs a resume affordance into the
credential flow."*

**Specified, per R.11g item 3 and human point 2d / addendum 2** (the key persists; the way out is navigation,
not a Cancel affordance):

- On `ProductDetailPage`, for a product whose `canReachRepository` is false because the host is
  `HostKeyStatus.unknown`, one primary text button: **`Finish registering`**. It enters the credential flow at
  the trust step with the existing `RepositoryReference` and the existing keypair — **no re-entry of the
  SSH-URL field, no second key generated.**
- Its helper, below, in the existing per-platform convention: *"This product is not registered yet. Confirm
  its host to finish registering."*
- **No `Cancel` on that step** (`N-1`, settled human input, unchanged).
- **If the substrate precondition fails, this button does not appear and nothing is created** — `ae1c1f79`.

**Honest scope statement.** `ProductDetailPage` is production source and its board is **not** in this lane's
`OWNED_PATHS`. This is the Level-3 navigation component of the pass, and it is specified but **not rendered**.
Reported as gap **G13**.

---

## 5. H-1(c) — split identity, and `ae1c1f79`'s consequence

### 5.1 What changed on the Unknown-host pair, and why each change is required

`898b07d0` makes the `Product` row (state `registered`) and the `RepositoryReference` exist **before** the
trust decision. Every element below was required by that, not chosen.

| Layer | Before | After | Required by |
|---|---|---|---|
| `Status` eyebrow | `NOT REGISTERED YET` | **`REGISTERED · NOT YET USABLE`** | a product row **already exists**, so "not registered yet" is false |
| `Trust K` | `CONFIRM THIS HOST BEFORE CONNECTING` | **`CONFIRM THIS HOST TO FINISH REGISTERING`** | the product exists; trust **completes** a registration, it does not precede creation |
| `Trust Body 2` | *"It pushes and merges on its own. Only promotion to production waits for you."* | **REMOVED** | **false** under `898b07d0`: a product with no committed credential **cannot push or merge** |
| **`Trust Created`** | — | **NEW**, `30,566 330×24`, 10/400, `inkSecondary`: *"This product is already in your list. It cannot push or merge until you finish registering."* | `898b07d0`: **the user must be able to tell a product exists but is not yet usable** |
| 7 × `Trust *` names | `… · PROVISIONAL (G1 hostUnrecognised)` | suffix stripped | `hostUnrecognised` is no longer provisional; both decisions are RESOLVED |

**On the Verified pair**, `Status` was also re-grounded: `NOT REGISTERED YET` → **`REGISTERED · READY TO
REGISTER`**. `898b07d0` makes the old eyebrow false there too — on *every* one of these boards a product row
already exists as the flow's first step.

### 5.2 The element that discharges the requirement, and why the layer-name marker did not

`· PROVISIONAL (G1 hostUnrecognised)` is an **internal layer-name annotation**, invisible to any user. It
never satisfied "a product exists but is not yet usable", and the cancelled lane was right to retire it rather
than count it. **`Trust Created` is the element that satisfies it**: it is on-canvas text, it states both facts
(a product exists; it is not usable yet), and it gives the reason. It occupies exactly the slot `Trust Body 2`
held, so the trust panel's height (160px at y=502), its contents' order and the whole submit/helper/disclose
chain (678 / 720 / 748) are **unchanged**.

**Verified after the edit, all four boards:** zero intra-panel overlaps; `Trust Created` **contained** in
`Trust Bg`; zero shapes colliding with the bottom nav.

### 5.3 `ae1c1f79` — refusal creates nothing, and the boards must not imply otherwise

`ae1c1f79`'s follow-up naming this lane, verbatim: *"State the consequence for the mobile boards: after a
refused mint the Products list is unchanged, so the Unknown-host state must not imply that a product was
created."*

**Reading that instruction carefully, because it cuts against H-1(c).** H-1(c) requires the Unknown-host state
to say *a product was created*. `ae1c1f79` requires it not to imply a product was created *by a refused mint*.
These are consistent only because **they are different states** — and the sibling's R.11g item 5 makes that
binding:

> *"The Unknown-host board must **not** double as the refused-mint board**, even though both are 'the user is
> stuck'. They differ in what exists afterwards: Unknown-host leaves a **visible product**; refused-mint
> leaves **nothing**. Rendering them the same would tell the user to look for a product that does not exist,
> and would quietly re-open the dead end `ae1c1f79` closed."*

**Compliance, stated precisely.** `Trust Created`'s copy is conditioned on the host step — *"already in your
list"*, *"**until you finish registering**"* — and the board is reachable only after the `RepositoryReference`
and `Product` rows exist. It makes **no** claim about a refused mint. The refused-mint surface is specified
separately in § 6.2 and is **not** these boards. Finding **SC-9 / G14** records that rendering it needs a
board this lane does not own.

---

## 6. The two REQUIRED `9417f8bf` follow-ups owned by `design-agent`

Both quoted from the decision file, not paraphrased. Both were unaddressed across the whole artifact set
before this revision.

### 6.1 G-7 — remove `referenceName`, or replace it with a non-identifying handle. **REQUIRED.**

> *"Remove `referenceName` from `RepositoryCredentialView`, or replace it with a non-identifying handle.
> Under A3 the reference IS the sensitive artifact; G-7 was optional while the substrate was undecided and
> is now required."*

**Specified, with the blast radius measured at `289f1d3`:**

| # | Site | Nature |
|---|---|---|
| 1 | `apps/server/lib/src/models/repository_credential_view.yaml:10-11` | **the source of truth** — `### Name under which the private half is held locally. Never the value.` + `referenceName: String` |
| 2 | `apps/server/lib/src/generated/repository_credential_view.dart` | generated, 12 occurrences |
| 3 | `packages/control_plane_client/lib/src/protocol/repository_credential_view.dart` | generated, 11 occurrences |
| 4 | **`apps/control_plane/lib/features/product_detail/product_detail_page.dart:471`** | **rendered**: `'${c.referenceName} · ${c.algorithm} ${c.fingerprint} · '` |
| 5 | **`…product_detail_page.dart:676`** | **rendered**: `'${c.referenceName} · ${c.algorithm} '` |
| 6 | `apps/control_plane/lib/data/control_plane_repository.dart:108, :1098, :1691, :1709` | client-side hand-rolled projection |

**The finding that raises this from a contract tidy-up to a security defect: sites 4 and 5 render the field
in the user interface.** Under A3 the reference is *"a secret path or ARN"*, and the decision states an ARN
*"discloses vault topology"*. So SHIP IT currently shows vault topology to the user in two places. **This is
the concrete reason G-7 is now REQUIRED rather than optional.**

**Specified change.** Drop `referenceName` from `RepositoryCredentialView` (the decision's first option; the
simpler and safer one). Sites 4 and 5 render `'${c.algorithm} ${c.fingerprint}'` instead — `algorithm` and
`fingerprint` are already on the same lines and are explicitly safe: the YAML header states *"the public
half and fingerprint are safe to display"*, and `N-9`'s prohibition list bars the keychain, the vault and
manager identities, not the fingerprint.

**A second false claim found in the same contract, reported not fixed.** The YAML's own header comment reads
*"The private half lives in the operator's **local secret store**"* and the field comment says *"held
**locally**"*. Both are false under `9417f8bf` — twice false, since `b869ec24` had already moved custody
server-side. Correcting the comments is part of the same change.

**Not mine:** `packages/**` and `apps/server/**` are the sibling keys lane's and the implementer's. Specified
and routed (§ 12, N6a) — **no file outside `OWNED_PATHS` was written.**

### 6.2 The A3 unavailability path, with remediation copy. **REQUIRED. Specified; NOT rendered — ownership gap.**

> *"Design the A3 unavailability path with concrete remediation copy, per the fail-closed answer in
> `7b1bc8b7`. Under A3 the substrate is a runtime dependency that can be down, so this is a common case,
> not an edge case."*

`7b1bc8b7`'s follow-up: *"Write the remediation copy as a required part of the design, naming the concrete
operator action for an unreachable secret manager. Blocking a user with an unnamed remedy is the failure mode
human point 2d rejected."*

**The copy exists and is binding: the sibling's § R.5.4 specifies it verbatim for four named causes** —
`secretManagerUnconfigured`, `secretManagerUnreachable`, `secretManagerProtectionUnverifiable`,
`secretManagerWriteRefused` — each as Title / Body / Action, each `inkSecondary`, each naming a concrete
operator action and each stating that **nothing was created**. This revision consumes it as normative and
adds the **board specification** the sibling does not own:

**Surface.** Per R.11g item 5, the refused-mint state is a **separate surface**, not these boards: the Add
Product sheet stays open, **no product exists**, and the remediation replaces the deploy-key panel's content
in place. Two boards per theme would be required — `SM - Add Product · Substrate unavailable · {Light,Dark}` —
carrying, top to bottom: the eyebrow unchanged at `REGISTERED · NOT YET USABLE` is **wrong** here and must
read `NOT CREATED`; the cause-specific **Title**; the cause-specific **Body**; the cause-specific **Action**;
and the `Show technical details ▸` disclosure left-aligned at `parentX 16` with no divider, per § 4.1.
Contrast: all four strings are `inkSecondary`, measured at **6.28:1 light / 6.65:1 dark on `canvas`** and
**6.74 / 6.10 on `card`** — **PASS AA in both themes**.

**Why this is NOT rendered here, stated plainly rather than glossed.** This dispatch's `OWNED_PATHS` names
**four specific boards by id** and no more. Authoring two new boards on a shared design page would (a) exceed
the declared scope and (b) repeat the exact failure this lane already has on record — `penpot-board-evidence.md`
§7 records scratch boards created by failed API calls at revision 1 that had to be detected by inventory diff
and removed. A scope decision is the Manager's, not a substitute this lane makes on its own. **The copy is
fully specified; only a board owner is missing.** Recorded as **SC-9 NOT MET** and gap **G14**; routed in
§ 12, N6c.

---

## 7. D-8 — `SM` and `BPM` are two **states** of one mobile design, answered

Attempt 2 named this the first question of the retry and could not answer it without Penpot. **Answered by
reading both families live, read-only.** Full measurement in `penpot-board-evidence.md` §6.3.

**`27ea6536`'s mobile ruling is stated against `BPM · Add Product · Light/Dark`; this lane owns
`SM - Add Product - …`.** They are the same grammar at the same scale, differing in **state**:

| | `BPM` | `SM` |
|---|---|---|
| `Key State` | `Not installed yet` | `Host not recognised` / `Verified · just now` |
| fields | placeholders (`e.g. TeamHub`) | filled values (`TeamHub`) |
| trust panel | absent | present on the Unknown pair |
| `Art S` | `…stays in the keychain` | the `N-9` string |
| eyebrow | `NOT REGISTERED YET` | `REGISTERED · NOT YET USABLE` / `REGISTERED · READY TO REGISTER` |

### 7.1 The consequence that made this worth answering

**The human's mobile footer spec — left-aligned, no divider, no copy — is already satisfied on all four `SM`
boards, and `BPM` agrees with it.** Measured: `Disclose` at `parentX` 16 = the content left edge; **zero**
divider rectangles in the band between the button helper and `Disclose`; **zero** footer-copy text layers.
**H-1(b) therefore required no mobile board edit at all** — the boards were already conformant, which is the
outcome the human's *"Stay true to both designs in Penpot and in code"* predicts.

### 7.2 What the measurement corrected, and what it did not change

The cancelled invocation published this table with two stale values and the claim *"Every structural coordinate
matches."* Re-read at `289f1d3`:

| Row | First pass published | Corrected | Why |
|---|---|---|---|
| `Key State` | `138,436` for **all three** columns | `BPM` **436**, `SM` **446** | revision 5 moved `SM`'s to 446; the `SM` cells carried the **pre-move** value — a stale number published as measured |
| `Art S` | `138,418 220w`, height omitted | `BPM` `220×15`, `SM` `220×24` | the `SM` string now wraps to two lines; the omitted height is a real difference |

**What still holds, and is what D-8 rests on:** every *structural* coordinate of the footer chain matches
exactly — `Submit L`, the button helper, `Disclose`, its width, the absence of a divider, the three thin
rules, and `Disclose`'s left edge against the content edge. The two rows that now differ are **content- and
wrap-dependent** — the state line's y follows the custody string's line count, which is a consequence of
revision 5's own re-wrap, not a grammar difference. **The conclusion of D-8 is unchanged and does not depend
on the two corrected rows.**

### 7.3 `BPM`'s own defects, reported not fixed

`BPM` carries **the same false custody claim** (`ed25519 · private half stays in the keychain`, false under
A3, identical to the build's `:542`) **and** the now-false `NOT REGISTERED YET` eyebrow. `BPM` is read-only to
this lane — finding **F5**, routed in § 12.

---

## 8. M-1 — the cross-references, corrected by re-reading, not by arithmetic

**The "+6" rule is a trap, and applying it mechanically fixes six numbers and breaks three.** Attempt 2
measured it and it still holds:

| Item | Δ from the cited number | Why not +6 |
|---|---|---|
| the six single-line claim citations | **+6** | — |
| the provenance note (`26-31` → `31-37`) | **+5** on **both** endpoints | a note, not a table row |
| the three marker **ranges** | **+8**, **+8**, **+13** | a range has two endpoints, and the block was *lengthened* by the marker, not merely shifted |

**Every number below was re-read from the live files by me this pass, after the edits.** They are exact:

| Claim site | Published | **Verified at `289f1d3`** | What is actually there |
|---|---|---|---|
| `design-revision.md` 36px total | `:83` | **`:83`** | `\| total \| **50.4px**, content-driven …` |
| `design-revision.md` 36px sentence | `:85` | **`:85`** | *"So the desktop button collapses from ≈50px to exactly 36px"* |
| its marker block | `:89-95` | **`:89-95`** | `> **WITHDRAWN — revision 2 §6a; marker added at revision 3.**` … `:95` |
| `design-revision.md` F8 row | `:435` | **`:435`** | `\| F8 \| Penpot's IBM Plex Sans has no 500 weight …` |
| its marker block | `:437-444` | **`:437-444`** | `:437` `> **WITHDRAWN — revision 2 §2; marker added at revision 3.` … `:444` |
| `report.md` 36px bullet | `:68` | **`:68`** | `- **One button/helper structure** for both platforms …` |
| its marker | `:70-74` | **`:70-74`** | `> **WITHDRAWN — revision 2 §6a; marker added at revision 3.**` … `:74` |
| `report.md` F8 bullet | `:126` | **`:126`** | `- **TRIVIAL** — Penpot's IBM Plex Sans has no 500 weight …` |
| its marker | `:128-133` | **`:128-133`** | `:128` `> **WITHDRAWN — revision 2 §2; marker added at revision 3.` … `:133` |
| `report.md` `risk_rationale` | `:230` | **`:230`** | `…desktop button ~50.4px -> 36px; new 8px desktop gap…` |
| its marker | `:237-243` | **`:237-243`** | `:237` `> **WITHDRAWN IN PART — revision 2 §6a…` … `:243` |
| `report.md` provenance note | `31-37` | **`:31-37`** | `:31` `> **Provenance note (added at revision 3; extended at revision 4).**` … `:37` |
| `design-revision-metadata.yaml:15-16` | "still correct" | **CONFIRMED correct** | `:15-16` hold the 36px claim text |

**Revision 4's self-contradiction is resolved in favour of `31-37`.** Verified against the **committed blob**,
not memory: `git show HEAD:…report.md` line 12 already read *"provenance note at **lines 31-37**"* while § 0.1's
table published `26-31`. The three descriptions of rev-4-era content the Gate-D3 review gave (`:62` = *"Plus
four Penpot boards (not git)…"*, `:120` = a `What you're registering` bullet, `:224` = a `penpot:` board-id
line) are also confirmed against that blob — they are accurate descriptions of why those lines were wrong.

**The claim that is dropped.** The prior pass's *"CONFIRMED, every number"* is **not** carried forward as a
blanket statement. What is claimed is exactly the table above, each row re-read. And **§7.2 is the
counter-example that keeps this honest**: this revision corrected M-1's nine numbers correctly and then
published two *new* stale numbers of precisely this class in the same pass. Re-reading the thing you edited is
necessary; it is not sufficient — you must also re-read anything you then write *about* it.

---

## 9. L-1 — the three missing pointers, all three present

| Site | Pointer | Verified |
|---|---|---|
| `design-revision-3.md:583` — gap **G2** still listed as open | struck: *"RESOLVED at revision 5 by `9417f8bf` (OPTION_C / A3); layer renamed `Art S`, string corrected on all four boards"* | **yes** |
| `design-revision-3.md:592` — gap **G11** still open | struck: *"CLOSED in revision 4 (L-R2); re-confirmed at revision 5 (L-1)"* | **yes** |
| `design-revision-3.md:449-450` — B3 *"remains filed as Human Decision `27ea6536`"* **and**, **on the same line pair**, G2 *"stays `PENDING D4` and unresolved"* | one in-place block at **`:452-486`** covering **both**, retained unedited above | **yes — and corrected, see § 4.4** |

The third site is the one the rev-4 review did not name: the review cites `design-revision-3.md:445`, which
at that revision held the **G2 `PENDING D4`** claim as well as the B3 claim — both on the same paragraph.
Re-read live, that paragraph is at **`:449-450`**; the review's `:445` is its own older line number. **Retention without a marker
is not neutral**, and both are now marked without the retained text being touched.

Also re-verified at the new base: rev 4's L-R1 citation, **twice**. `grep -n '^## '` gives
`design-revision-3.md:646 ## 13. Assumptions carried forward` — rev 4's original `:558` was wrong, and
revision 4 corrected it to `:633`. **That correction has itself gone stale**, because this pass's own §4.4
correction to rev 3 added **13 lines** above it. The lesson text is at `:60-62` (§0, unchanged) and
**`:623-644`** (§12, heading at `:623`). **`design-revision-metadata-4.yaml:153-155` is corrected to match.**

**This is M-1 happening to the corrector, and it is the reason the numbers above are re-measured rather than
adjusted.** Correcting a cited site moves it; the correction is not complete until the citations *into the
correction* are re-measured too.

---

## 10. Findings this pass adds or confirms

| Id | Finding | Class | Disposition |
|---|---|---|---|
| **D-1** | `Art S` staleness spans **~30 sites**, not four | `DESIGN_DISCOVERY` | swept, § 3.3 |
| **D-2** | the human's two footer specs are produced by **different** calls; mobile's is not expressible today | `DESIGN_DISCOVERY` | specified as a Level-1 primitive requirement, § 4.3 |
| **D-3** | "no footer copy" is **two** `note:` sites plus a `_buildFooter`; this lane's own records repeated the false claim | `CONTRADICTION` | corrected here, § 4.2 |
| **D-4** | three divergent custody strings; only `N-9`'s is normative; the build's `:542`/`:1038` is a **separate** correction | `DESIGN_DISCOVERY` | reported, § 3.4 |
| **D-5** | `N-9`'s rule ("name no substrate") contradicts its own prescribed string | `CONTRADICTION` | **flagged, not silently resolved** — adopted verbatim as a binding item, § 3.4 |
| **D-6** | rev 4's A8 is stale twice over (status **and** provenance) | `DESIGN_DISCOVERY` | corrected, § 3.3 |
| **D-7** | custody copy is **security copy**, so not a Level-0 detail | `DESIGN_DISCOVERY` | treated as board-write work, § 3.5 |
| **D-8** | the mobile spec is stated against `BPM`; the lane owns `SM` | `DESIGN_DISCOVERY` | **answered**, § 7 |
| **D-9** *(new)* | G-7 is not a contract tidy-up: **`referenceName` is rendered in the UI** at `product_detail_page.dart:471` and `:676`, so under A3 SHIP IT shows vault topology to the user | `DESIGN_DISCOVERY` / security-relevant | specified, § 6.1 |
| **D-10** *(new)* | the contract's own YAML comments claim the private half is *"held locally"* — false twice over | `DESIGN_DISCOVERY` | reported with D-9's change, § 6.1 |
| **F5** | `BPM` carries the same false custody string and the now-false eyebrow | `DESIGN_DISCOVERY` | reported, not mine, § 7.3 |
| **F6** | the four **desktop** `S` boards carry footer copy, so they do not satisfy `27ea6536`'s desktop clause; and (236,862) is a **text layer**, not the divider | **`CONTRADICTION`** | **BLOCKER**, ownership, § 4.4 |
| **F7** *(new)* | a verified board edit followed by an unverified *table* about it — §6.3's two stale rows, published as measured | `WORKFLOW_IMPROVEMENT` | corrected, § 7.2 |
| **F8** *(new)* | **`design-revision-metadata-4.yaml`'s first fenced YAML block does not parse** — a `-` list item whose continuation line contains `": "` (`changelog:` → `- revision 4 — … (DESIGN_REVIEW_CHANGES_REQUIRED, CORRECTION_REQUIRED: YES, …`). Confirmed **pre-existing** by parsing the committed blob at `289f1d3`, which fails identically | `PROJECT_FACT` | **reported, not fixed** — it is unrelated to this revision's three findings and repairing it silently inside a revision that claims to be about them would be scope creep. Rev 5's own metadata was checked the same way and all 7 of its fenced blocks parse |

---

## 11. Gap register

| Id | Gap | Why it is not mine / disposition |
|---|---|---|
| **G2** | ~~at-rest wording for `Art S`~~ | **CLOSED** — `9417f8bf`; string corrected on all four boards |
| **G11** | ~~the mobile design review report was never persisted~~ | **CLOSED** in revision 4 (L-R2), re-confirmed |
| **G3** | `negative` on dark fails AA; no compliant token exists | `ShipItPalette` is design-system-owned (N2) |
| **G4** | `TechnicalDetails`' unconditional `ContentRule` | **ESCALATED to a specified requirement** — § 4.3, D-2, N6 |
| **G12** | the primary action's surface differs between code (`card` in `DesignPanel`) and the boards (bare page background) | consequence of G5; recorded with the surface named (N9) |
| **G8** | `flutter analyze` not run → feasibility cannot be HIGH | § 13 |
| **G9** | no `ShipItPalette` disabled-primary token | design-system owner (N4) |
| **G13** *(new)* | **R.11g item 3's resume affordance on `ProductDetailPage` is specified but not rendered** — that board is not in this lane's `OWNED_PATHS` | § 4.5 |
| **G14** *(new)* | **the A3 refused-mint surface needs two boards this lane does not own** | § 6.2, SC-9 |

`requirements_covered`: **R1–R7** (cycle 1), **H-1(a), H-1(b), H-1(c), M-1, L-1** (rev-4 review), and the two
`9417f8bf` follow-ups **as specified**. `requirements_gaps`: **G13, G14, and SC-9** — all three are
**ownership** gaps, not design gaps, and none is silently narrowed.

---

## 12. Notifications routed

| Id | To | Level | What |
|---|---|---|---|
| **N4** | design-system owner | 1 | no disabled-primary token (G9) |
| **N6** | design-system owner | **1** | **`TechnicalDetails` must be able to suppress its `ContentRule` and align its disclosure start-aligned** (D-2, G4). The human has decided the outcome; only the mechanism is open. **NOT a human gate** |
| **N6a** | keys lane / implementer | — | **G-7 is REQUIRED**: remove `referenceName` from `RepositoryCredentialView` (2 generated packages + YAML) and fix the two UI render sites (`product_detail_page.dart:471`, `:676`). The decision's own blast-radius statement ("nine/twelve… two will not compile") is the sibling's; **this lane measured 6 sites incl. 2 render sites** |
| **N6b** | **Manager — ownership** | **blocker** | **F6**: the four `S` desktop boards carry footer copy and do not satisfy `27ea6536`. Closing it is a board edit on four read-only boards. **Needs an owner**; the decision itself anticipated this cost |
| **N6c** | **Manager — ownership** | **blocker** | **G14**: two boards needed for the A3 refused-mint surface (§ 6.2), which R.11g item 5 forbids folding onto the Unknown-host board |
| **N6d** | keys lane | — | **D-3**: "no footer copy" is two `note:` sites (`:317-319`, `:926-928`) plus `_buildFooter` (`:375`). The sibling's own revision 5 has since corrected this (its L8); recorded so the two lanes agree |
| **N6e** | keys lane | — | **D-5**: `N-9`'s "name no substrate" rule vs its prescribed string. Read as *generic category permitted, identity prohibited*; this lane adopted the string verbatim as a binding item and did not rewrite it |
| **F5** | Manager | — | `BPM` carries the false custody string and the false eyebrow; read-only to this lane |
| **N9** | design-system owner | 1 | G12, the primary action's surface |
| **N10** | design-system owner | 1 | `inkTertiary` on `card` = 4.23:1 in dark (unchanged; see § 13) |

---

## 13. Assessment, honestly filled

| Field | Value | Reason |
|---|---|---|
| `design_system_compliance` | **PARTIAL** | Every board element maps to a named token or production primitive, re-read and token-matched live: board fill `#f7f7f5`/`#1f2120` = `canvas`, `Trust Bg`/`Art Bg` `#ffffff`/`#262827` = `card`, `Art S` `#5a5c5b`/`#a8a6a0` = `inkSecondary`, `Status` `#6e706e`/`#8a8983` = `inkTertiary`. **Not PASS** because D-2 is an unsatisfied compliance requirement: the mobile footer cannot be expressed by the primitive it uses, and F6 is an unsatisfied conformance requirement on four boards. Both are named, not rounded. |
| `ux_accessibility_score` | **PASS, measured on the surfaces this pass touched** | Contrast recomputed from `design_tokens.dart` at `289f1d3`, sanity-checked (black/white 21.00, white/white 1.00). The layers this pass added or moved: `Art S` `inkSecondary` on `card` **6.74 light / 6.10 dark**; `Trust Created` `inkSecondary` on `card` **6.74 / 6.10**; `Status` `inkTertiary` on `canvas` **4.65 / 4.62**; `Trust Btn L` `#ffffff` on `#1668d6` **5.27** and `#06121f` on `#4496fc` **6.30**. All ≥ 4.5:1, both themes. **The known `inkTertiary`-on-`card` FAIL at 4.99/4.23 is real and unchanged** — it is N10, design-system-owned, and is **not** on any layer this pass touched. |
| `implementation_feasibility` | **MEDIUM** | Not HIGH, and the reason is stated rather than hedged: **`flutter analyze` was NOT_RUN** — it requires `flutter pub get`, which writes outside this lane's read-only scope, and `apps/control_plane/.dart_tool/` does not exist at this HEAD. A prior revision of this lane claimed HIGH without the analyzer ever resolving packages; that is not repeated. **But** every line number this revision cites was re-read at `289f1d3`, and `git diff --name-only 43d328b 289f1d3 -- apps/control_plane packages` returns **empty**, so all of them hold. MEDIUM, not LOW, because the change is small and local: three edits in one file plus one shared-primitive change. |

---

## 14. Validation

| Check | Result |
|---|---|
| `git branch --show-current` | `design-correct-addproduct-mobile` ✓ |
| `git rev-parse HEAD` | `289f1d33dcf1a2f24ead765c9e573b2f1ba1f107` ✓ |
| `git rev-parse main` | identical to HEAD ✓ |
| `git diff --name-only 43d328b 289f1d3 -- apps/control_plane packages` | **empty** — every `:NNN` cited into `apps/control_plane/**` holds at the new base ✓ |
| `penpotUtils.getPages()` | `["Page 1"]`, id `d8ac01df-6646-81d2-8008-a366c09aa9d3` ✓ |
| Board list before edits (160 boards, 164 root children) and after | **identical** — 160 / 164, verified after the last write ✓ |
| All four `SM` boards: custody string | the `N-9` string, **80 chars, all four**, re-read ✓ |
| All four `SM` boards: forbidden layer names | **0** for `PENDING D4` and `PROVISIONAL`, all four ✓ |
| All four `SM` boards: forbidden text | **0** for all ten strings, all four ✓ |
| Board identity: name / id / size | all four exact names, all four ids, **390×844** ✓ |
| Read-only board integrity | `BPM` ×2 (36 children each, 5280,9800 / 5280,10750) and `S` ×4 (69/69/65/65, positions as in evidence §7) — **unchanged** ✓ |
| `Trust Created` containment + nav collision | contained in `Trust Bg`; zero shapes in the nav band beyond the badge ✓ |
| M-1 numbers (13 values) | **all re-read and exact** — § 8 ✓ |
| L-1 pointers (3 sites) | **all present** — § 9 ✓ |
| Contrast recomputation | § 13 ✓ |
| `flutter analyze` | **NOT_RUN** — § 13 |
| Any Docker or Compose command, incl. `info`/`ps`/`logs`/`config` | **NOT_RUN — none issued. No breach.** `AGENTS.md` § *Shared Docker state* honoured |
| Pre-edit board state | **NOT_REVERIFIABLE** — Penpot exposes no version history. Every "before" in § 3.2/§ 5.1 is a **rev-2-era recorded value**, not a live pre-edit read. Stated rather than implied |
| Penpot `textBounds` pixel units | **NOT_RECONCILABLE** — `textBounds.x` tracked `2 × parentX` on every sample; the 214.53px figure is **withdrawn** as evidence (§ 3.2) |
| Commit / push | **NOT_RUN** — forbidden by the dispatch |
| Boards created | **NONE.** No scratch board; root children unchanged at 164 |

---

## 15. What this file does **not** evidence

- **`flutter analyze` NOT_RUN**, so no claim rests on the analyzer (§ 13).
- **No Flutter widget was rendered.** Nothing here is a screenshot of a running app.
- **No automated pixel diff.** All geometry comparison used layer name, `parentX`/`parentY`, `width`, `height`
  and containment — **not pixels**, and not `textBounds` (§ 3.2).
- **Pre-edit board state is not recoverable** (no version history). "Before" values are recorded values.
- **Full content inspection of the four desktop `S` boards: PARTIAL.** The footer band was read in full
  (§ 4.4, evidence §6.4) and the `Host Btn`/`R Submit L` layers at revision 1; not every layer was walked.
- **The A3 refused-mint surface and R.11g item 3's resume affordance are specified, not rendered** (G13, G14).
- **I do not approve this work.** It goes to independent design review.

---

## 16. Safe parallelism

```yaml
SAFE_PARALLEL_WORK:
  - The keys lane's independent review — disjoint paths. Its revision 5 is on this base and its § R.11g
    line numbers were independently re-verified at 289f1d3 by this lane (all six hold)
  - Non-UI implementation prep on add_product_page.dart: the custody string at :542 AND :1038 (D-4),
    note: null at :317 and :926, deletion of _buildFooter (:375/:314) (D-3) — every number re-read here
  - G-7's contract change (N6a) — disjoint from this lane's paths
  - ADR 0018's A2 amendment recording the 9417f8bf supersession (owner: human / ADR owner)
PROHIBITED_PARALLEL_WORK:
  - Design Contract freeze of revision 4 — four boards changed, one design-system requirement is unsatisfied
    (D-2), and four desktop boards do not conform to the resolved footer spec (F6)
  - Any lane editing this lane's task directory, or the four SM boards, or any BPM/S board
  - Any lane editing .decisions/**
  - Implementation of the footer or the custody copy against revision 4's spec — superseded
  - Authoring the refused-mint board on the Unknown-host board — forbidden by R.11g item 5
```

---

## 17. Recommended next action

**`DESIGN_REVIEW` (Gate D3) — and it needs no further design pass.** Two **ownership** questions are for the
Manager, not for a reviewer and not for the human: **N6b** (who edits the four desktop `S` boards, F6) and
**N6c** (who authors the two refused-mint boards, G14). Neither blocks review of this revision; both block
*implementation* of the parts they cover.

**I do not approve this work, and I am not asking for it to be reviewed as a Design Contract freeze.**