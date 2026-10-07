# Correction Report — Design Revision 6 (record-only pass on revision 5)

Persisted per `aef-orchestrator` §14. Lane: `design-agent`. Report persists to
`docs/engineering/dispatch/tasks/design-correct-addproduct-mobile-6/report.md`.

```yaml
RESULT: DESIGN_REVISION_COMPLETE
TASK_ID: design-correct-addproduct-mobile-6
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — mobile Design Revision 6
WORKTREE: /private/tmp/shipit-correct-addproduct-mobile
BRANCH: design-correct-addproduct-mobile
BASE_SHA: 16cd497
HEAD_SHA: 16cd497
COMMITTED: NO            # forbidden by the dispatch
REVISION_ID: CB4BEECA-CA9D-4F26-9464-E1B6F7C9BDCB
REVISION_NUMBER: 6
BRIEF_ID: 52CB4098-FF87-4B78-81DA-1104269551A1
```

## Headline

**All seven findings are closed, and no design changed.** The finding set was 0 BLOCKERS, 0 HIGH, 3 MEDIUM,
4 LOW, and the reviewer's own summary was *"three record corrections, not a redesign."* This pass accepts that
characterisation: **zero board writes, zero decision re-openings, zero production edits.** Ten record
corrections were applied in place to revision 5's artifact set and every one was re-read from the live file
after the edit.

**Which published suffix count was right:** `penpot-board-evidence.md:182-187` — *"All sixteen suffixes
retired"*, enumerating the eight layers. **16 is correct**, measured as 8 unsuffixed `Trust *` layers on each
of the two Unknown boards. The other two published forms (`7 ×` in two files, `17` / `Seventeen` in two more)
were wrong and are corrected. The `design-revision-5.md:169` sentence used *sixteen* correctly for the
`PROVISIONAL` population but named it as if it covered both markers; it is now split into **4** `· PENDING D4`
+ **16** `· PROVISIONAL` = **20**.

**F6 remains open and is not mine.** It is reported as an ownership gap in three artifacts and in
`design-revision-metadata-6.yaml`'s `requirements_gaps`. It needs an **ownership grant**, not a re-decision.

---

## 1. Isolation pre-flight — the fast-forward was safe, and here is the proof

The dispatch's `git merge --ff-only 16cd497` initially **failed**: revision 5 lived as uncommitted
working-tree files, and 8 modified + 6 untracked files would have been overwritten. **I did not force it.**

Before touching anything I compared all 14 artifacts against the copies committed at `16cd497` with
`git show … | diff -q` — **14 of 14 byte-identical**. I then took a full copy of the directory to a temp path
before the stash, fast-forwarded cleanly, and re-compared the post-fast-forward working tree against that
backup: **21 of 21 files identical**. So the fast-forward lost nothing and changed no byte of the artifact
set. The stash (`stash@{0}`) is retained, not dropped, and its message records what it is.

```
git merge --ff-only 16cd497   →  Fast-forward  (289f1d3 → 16cd497)
git rev-parse HEAD            →  16cd49721646521d13ff6d962dcf82ef4719237e
git branch --show-current     →  design-correct-addproduct-mobile
```

**One thing the dispatch did not state, found while verifying:** revision 5's own metadata records
`committed: NO`, and that was true. It is now committed at `16cd497`, which removes the reviewer's
compounding concern that the reviewed artifact existed only as working-tree files.

---

## 2. Item-by-item disposition

### MR5-1 (MEDIUM) — the retired-suffix count, wrong in two of three published forms — **CLOSED**

| # | Site | Was | Now | Verified anchor |
|---|---|---|---|---|
| 1 | `design-revision-5.md` | `7 ×` | `8 ×` + *"16 suffixes across the pair"*, old value named in-cell | **`:361`** ✓ |
| 2 | `penpot-board-evidence.md` | `7 ×` | `8 ×`, old value named in-cell | **`:262`** ✓ |
| 3 | `design-revision-metadata-5.yaml` | `Seventeen` | `Sixteen` + the 4 `PENDING D4` suffixes | **`:101`** ✓ |
| 4 | `traceability-matrix-5.md` | `17 suffixes retired` | `16` | **`:77`** ✓ |
| 5 | `design-revision-5.md` | one conflated sentence | split: **4 + 16 = 20** | **`:169-172`** ✓ |

**Which form was right:** `penpot-board-evidence.md:182-187`. It is the only one of the three consistent with
the live file, and it is now the reference form; § 1 of `design-revision-6.md` publishes the comparison table.

**On the reviewer's `NOT_VERIFIABLE` alternative — declined, deliberately.** Penpot exposes no version
history, so the *before* state is unverifiable and the reviewer was right about that. But the *end* state is
live-verifiable, and 8 unsuffixed layers × 2 boards is the direct measurement of the retirement. Publishing
the correct number is better than publishing none; a `NOT_VERIFIABLE` stamp on a figure that is measurable
would trade a wrong number for a false absence of knowledge.

### MR5-2 (MEDIUM) — the brief recorded this lane's only blocker as met — **CLOSED**

Three defects in one row of `design-brief.md`, all three fixed on a **single line**, so the brief stays 169
lines and its other anchors do not move.

| Defect | Fix | Anchor |
|---|---|---|
| no `NOT MET` disposition, one row above SC-9's explicit one | `**MET on mobile · NOT MET on desktop (F6).**` | `:98` ✓ |
| cited **§6.3** (D-8) instead of **§6.4** | cites §6.4 for desktop, §6.3 for mobile | `:98` ✓ |
| **F6 appeared nowhere in the brief** — the reviewer's `grep -n "F6\|footer copy\|N6b"` returned no hits | the cell now names **F6**, the `Footer` text layer at rel 236,862, and **N6b**, and states F6 needs an **ownership grant, not a re-decision** | `:98` ✓ |

`grep -n "F6" design-brief.md` now returns a hit. Verified.

### MR5-3 (MEDIUM) — G-7's site table omitted the file that constructs the view — **CLOSED**

**I verified the missing site exists before writing it into a record.** `apps/server/lib/src/services/
ui_view_mappers.dart:176` reads exactly `referenceName: c.referenceName,`, inside
`static RepositoryCredentialView repositoryCredentialView(RepositoryCredential c)`, under the comment
*"Reference name only — the private half is never in this payload."*

| Change | Where | Anchor |
|---|---|---|
| **site 7 added**, with the compile consequence stated | `design-revision-5.md` § 6.1 table | **`:424`** ✓ |
| *"6 sites"* → *"7 sites, not 6"* | § 6.1 | **`:426`** ✓ |
| the deliberate **retentions** under `9417f8bf:167` now stated, so a future lane does not strip them too | § 6.1 | **`:426-435`** ✓ |
| the same file named in **N6a** — the row route N6a sends the implementer | § 12 | **`:655`** ✓ |
| `MEASURED 6 sites` → `7 as of revision 6` | `metadata-5.yaml` N6a | **`:230`** ✓ |
| matrix evidence row → **7** sites | `traceability-matrix-5.md` | **`:85`** ✓ |

**The 6-site *scope* is unchanged.** The reviewer's classification of the ~30 repo-wide `referenceName`
occurrences as domain/storage — plus `generated/protocol.dart:3841` being the `product_credential` **DB
table** (named at `:3810`), not the client view — was correct, and it is now **recorded** rather than left
implicit.

### MR5-4 (LOW) — two files written in the same pass disagreed by one — **CLOSED**

Measured at `16cd497` on `design-revision-3.md`: heading **`623`**, last content **`642`**, blank **`643`**,
`---` **`644`**. **`:623-644` is the right form** — it starts at the heading — and three of the four sites
already published it, so `design-revision-4.md:160` was corrected to it and the re-measurement named.
Verified: rev-4 `:160`, metadata-4 `:154`, rev-5 `:62` and `:600` all now read `:623-644`.

### MR5-5 (LOW) — the provenance basis was stale at the reviewed head — **CLOSED**

**Confirmed, and the advance has gone further.** At this pass's base:

```
git diff --name-only 43d328b 16cd497 -- apps/control_plane packages
  packages/product_registry/lib/src/engine/product_registry_engine.dart
  packages/product_registry/lib/src/store/in_memory_product_registry_store.dart
  packages/product_registry/lib/src/store/product_registry_store.dart
  packages/product_registry/test/credential_test.dart
```

**4 files — unchanged from the reviewer's count.** Every one is in `packages/product_registry/**`, which this
revision cites **nothing** in.

**Fixed by the reviewer's second option: state the basis in a form that still holds.** Every `:NNN` cited
into `apps/control_plane/**` and `apps/server/**` was **re-read individually at `16cd497`** and all hold —
14 source citations plus the 13 M-1 numbers plus the 3 L-1 pointers, tabulated in `design-revision-6.md` § 6
Table 2. The empty-diff claim was **not deleted** (it was true at `289f1d3`); it was qualified in all four
places it appeared: rev-5 `:18` (provenance block), `:235` (§ 4.2 header), `:672` (§ 13 feasibility), `:683`
(§ 14 validation), and metadata-5 `:18`.

**I did not take the review's `08c7590` at face value.** The dispatch told me to fast-forward to `16cd497`,
which is *two* commits past the head the reviewer read. Every citation was therefore re-read at `16cd497`,
not inherited from the review.

### MR5-6 (LOW) — SC-8 cited the wrong section — **CLOSED**

`design-brief.md:99` verified `Trust Created` against *"§4 of `design-revision-5.md`"*; §4 is H-1(b), the
footer. `Trust Created` is in **§ 5.1 / § 5.2**. Re-cited, with the error named in-cell. One line, so the
brief's anchors do not move.

### MR5-7 (LOW) — *"zero intra-panel overlaps"* was not literally true — **CLOSED**

`Trust Btn` (`30,618 180×30`) geometrically encloses `Trust Btn L` (`30,624 180×18`), and
`Submit (label only — no nested subtext)` encloses `Submit L`. That is the **button-rect-plus-label idiom,
not a defect** — and the same evidence file already draws exactly this distinction for the 1px `Art T`/`Art S`
box overlap, so the lane was applying an inconsistent standard. Wording precision only.

| Site | Anchor |
|---|---|
| `design-revision-5.md` § 5.2 | **`:376-377`** ✓ |
| `penpot-board-evidence.md` § 6.2 | **`:266-267`** ✓ |

**The substantive claims are unchanged and were not weakened:** `Trust Created` is contained, the chain
geometry is unchanged, zero nav collisions. The correction *names the exception* rather than dropping the
claim.

---

## 3. F6 — open, owned by nobody, reported not fixed

**I did not fix it and I did not touch a board I do not own.** Reported as an open ownership gap in
`design-revision-6.md` § 3, in `design-revision-metadata-6.yaml`'s `requirements_gaps` (with `status: OPEN —
NOT MINE, NOT FIXED, NOT ABSORBED`), in `traceability-matrix-5.md` § 4 (row re-affirmed **still open**), in
`design-revision-5.md` § 12 (N6b), and now in `design-brief.md`'s SC-7 acceptance row.

The measured facts are the reviewer's and are unchanged: a `Footer` **text** layer at rel **236,862**,
1020×15, byte-identical to `add_product_page.dart:383-384`, on **all four** `S` boards; the divider
`Footer Rule` at rel **236,848**, 1020×1; `Disclose` at rel 1036 → right edge **1256** = `236+1020`. So
`27ea6536`'s *"a divider"* and *"right-aligned"* clauses are **satisfied** and *"no footer copy"* is **NOT**.

**It needs an ownership grant, not a re-decision.** `27ea6536` is RESOLVED, its normative outcome is settled
and unquestioned, and its own OPTION_B named this cost in advance: *"Requires `note: null` … **and editing
the four existing desktop boards, which no current lane owns** — so it needs a design-system-owner board
edit."* The four boards are `PROHIBITED` to this lane **and** to the keys lane; **no lane owns them.** The
decision is not reopened, no board is edited, and `BPM`'s identical false custody string and now-false
`NOT REGISTERED YET` eyebrow (F5) are reported, not touched.

**SC-9 / G14 (N6c) carried the same way** — a correct scoping call, not an unfunded requirement. The copy and
full layout are specified; two boards outside `OWNED_PATHS` are needed and R.11g item 5 forbids folding the
surface onto the Unknown-host board. **Carried as a scoped gap, not worked around.**

---

## 4. The corrections moved lines — so the migration is published

MR5-1's own lesson is that a correction moves the line it cites. **These corrections moved lines**, and
leaving that for a reader to discover would repeat the defect. `design-revision-6.md` § 5 tabulates every
anchor the review cites into this lane's artifacts.

| Cited by the review as | Now | Why |
|---|---|---|
| `design-revision-5.md:361` · `:169` · `:376` · `:62` | **all unchanged** ✓ | in-place fixes; line counts deliberately held |
| `design-revision-5.md:588` | **`:600`** (+12) | MR5-3's § 6.1 block adds 12 lines above it. `:643`→`:655`, `:660`→`:672`, `:671`→`:683` |
| `design-revision-metadata-5.yaml:99` | **`:101`** (+2) | the provenance comment added 2 lines at `:18` |
| `traceability-matrix-5.md:76` · `:77` · `:85` · `:107` | **all unchanged** ✓ | in-place; file still 132 lines |
| `penpot-board-evidence.md:182-187` · `:262` · `:266` · `:346` | **all unchanged** ✓ | in-place; file still 455 lines |
| `design-brief.md:98` · `:99` · `:135` | **all unchanged** ✓ | in-place; file still 169 lines |
| `design-revision-4.md:160` | **unchanged** ✓ | in-place value fix |

**I deliberately held line counts constant wherever I could.** Three edits were re-shaped after a
first attempt changed a paragraph's line count and silently moved `:361`; the fix was to rewrite the text to
the same number of lines rather than republish the moved anchors. The only shifts that remain are the two
above, and both are published.

**A repo-wide grep found no other artifact citing a line number inside this lane's files** except
`design-review-addproduct-mobile-rev5/report.md` itself. (`design-review-addproduct-keys-rev5/report.md`
cites `design-revision-5.md:2414` and `design-revision-metadata-5.yaml:739-742` — out of range for files of
746 and 318 lines; those are the **keys lane's own** artifacts of the same name in
`design-addproduct-keyservice/`. Not ours, not corrected here.)

---

## 5. A near-miss worth recording: I nearly shipped the defect this revision exists to fix

Writing `design-revision-metadata-6.yaml`, I used the same list style revision 4's metadata uses — and my
first draft produced **2 of 7 fenced YAML blocks that do not parse**, from the identical cause as this
artifact set's own **F8**: an unquoted list item whose continuation contains `": "`. Caught by parsing the
blocks rather than eyeballing them, fixed with `- >` block scalars and a quoted scalar.

**If I had not parsed the file I wrote, revision 6 would have shipped a new F8 — in the revision created to
record corrections.** This is the same failure class as MR5-1 and it is worth persisting as an executable
rule rather than a note: **parse every fenced YAML block in the file you write, before you report.** The
`design-revision-metadata-5.yaml` blocks still parse 7/7 after my edits, which is F8's claim re-confirmed.

---

## 6. Validation

| Check | Status | Evidence |
|---|---|---|
| `git branch --show-current` | pass | `design-correct-addproduct-mobile` |
| `git rev-parse HEAD` | pass | `16cd49721646521d13ff6d962dcf82ef4719237e` |
| Pre-flight: rev-5 artifacts vs the copies at `16cd497` | pass | **14/14 byte-identical** (`diff -q`), before the fast-forward; **21/21** re-compared after |
| `git merge --ff-only 16cd497` | pass | **Fast-forward**, `289f1d3 → 16cd497`, clean tree. Initially refused — the artifacts were uncommitted; verified identical before proceeding |
| `penpotUtils.getPages()` | pass | **`["Page 1"]`**, id `d8ac01df-6646-81d2-8008-a366c09aa9d3` (`penpot_high_level_overview` read first) |
| Penpot boards edited / created / renamed / deleted | **0 / 0 / 0 / 0** | no board write was needed or made. No live re-measurement was re-spent: the reviewer's measurement is adopted |
| Nine named decisions | pass | all RESOLVED — in fact **14/14** files in `.decisions/**` are RESOLVED. **Read, not re-opened** |
| Source citations re-read at `16cd497` (MR5-5) | pass | 14 source citations + 13 M-1 numbers + 3 L-1 pointers, `design-revision-6.md` § 6 Table 2 |
| `ui_view_mappers.dart:176` exists as described | pass | reads exactly `referenceName: c.referenceName,` |
| `design-revision-metadata-6.yaml` fenced-YAML parse | pass | **7/7 blocks parse** |
| `design-revision-metadata-5.yaml` fenced-YAML parse | pass | **7/7 blocks parse** — F8's claim re-confirmed, unbroken by my edits |
| Every anchor published in rev 6 § 4/§ 5/§ 6 | pass | **30 anchors re-read from the live files after the edits**, all exact |
| Residual wrong values in the owned set | pass | `grep` for `7 ×` / `Seventeen` / `17 suffixes` / `all sixteen layer names` / `:624-644` → only the **intentional** in-cell correction markers that quote the old value |
| Any Docker or Compose command, incl. `info`/`ps`/`logs`/`config` | **NOT_RUN** | **none issued. No breach.** `AGENTS.md` § *Shared Docker state* honoured |
| `flutter analyze` / widget render / pixel diff | **NOT_RUN** | no claim rests on any of them |
| Contrast recomputation | **NOT_REPRISE** | no colour changed; the reviewer's independent recomputation of all ten figures (reproducing to 0.00) is inherited, not re-claimed |
| Commit / push | **NOT_RUN** | forbidden by the dispatch |
| Files touched outside `OWNED_PATHS` | **none** | see § 8 |

---

## 7. Learning — classified per `docs/engineering/LEARNING_POLICY.md`

| # | Discovery | Category | Authority | Disposition |
|---|---|---|---|---|
| L-1 | **MR5-1 is the fourth hand-caught stale-number defect in this work item** (rev 4's M-1, the cancelled lane's §6.3, this set's own §4.4 correction, MR5-1). It is **mechanically checkable**: grep every `:NNN` in an owned set and confirm the target line, and diff the owned set's line count after each correction. | `WORKFLOW_IMPROVEMENT` | independent review | **Routed as N11.** Reported, not built — this lane has no tooling ownership. The reviewer's §12 makes the same argument; this pass does the two checks **by hand** and publishes the anchor migration, which is the manual version of the tool |
| L-2 | **The corrections themselves move the lines they cite**, so any in-place correction pass must publish an anchor migration. Holding line counts constant where possible prevents the problem rather than documenting it. | `WORKFLOW_IMPROVEMENT` | independent review | **Applied and published** — `design-revision-6.md` § 5. Generalized into L-1's checker |
| L-3 | **A non-parsing fenced YAML block is trivially detectable and trivially introduced.** Revision 4's metadata has one (F8); a near-identical mistake in a *new* file was caught only by parsing it. | `AUTOMATION_OPPORTUNITY` | independent review | **Performed by hand this pass** — every fenced YAML block in both metadata files parsed. Persisted as a rule: *parse what you write before you report it* |
| L-4 | The retired-`· PROVISIONAL`-suffix count is **16**, live-verifiable as 8 unsuffixed `Trust *` layers on each of the two Unknown boards, while the *before* state is not. | `PROJECT_FACT` | automatic | **Persisted** in all four published forms, with the end-state measurement and the `NOT_VERIFIABLE` boundary both stated |
| L-5 | **G-7's in-scope blast radius is 7 sites, not 6**; the seventh is the server-side view constructor, which will not compile without the change. The `platform_contracts` / `product_credential` / persistence-layer occurrences are **deliberately retained** under `9417f8bf:167`. | `PROJECT_FACT` (security-relevant) | automatic for the record; the **change itself** is keys-lane/implementer | **Persisted in three artifacts and routed in N6a.** No production file was written |
| L-6 | **F6 needs an ownership grant, not a re-decision**, and it is now recorded in five places — `27ea6536` is RESOLVED and settled; only write access to four `S` boards is missing. | `CONTRADICTION` → Manager (ownership) | **human/governance for the grant** | **Reported in five places and deliberately NOT fixed.** `BPM`'s identical defects reported too (F5) |
| L-7 | A `git merge --ff-only` onto a commit that contains an artifact set the producing worktree held **uncommitted** fails; the safe procedure is *compare against the committed copy first*, back up, then fast-forward — not force. | `WORKFLOW_IMPROVEMENT` | independent review | **Performed and recorded** in § 1 with the 14/14 and 21/21 evidence |
| L-8 | `packages/product_registry/**` is touched by merges this lane does not own, which invalidates a range-diff used as a provenance basis. | `PROJECT_FACT` | automatic | **Persisted** — the basis is restated per-citation; the 4-file advance is named |

**Nothing durable was left unclassified.** No category was assigned twice; the two items above this lane's
authority (L-6's grant, L-1's tooling) are routed out rather than taken.

---

## 8. Ownership compliance

**Written — inside `OWNED_PATHS` only:**

```text
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-6.md                    (NEW)
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-metadata-6.yaml         (NEW)
docs/engineering/dispatch/tasks/design-addproduct-mobile/correction-report-6.md                 (NEW)
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-5.md                   (modified — in place)
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-metadata-5.yaml        (modified — in place)
docs/engineering/dispatch/tasks/design-addproduct-mobile/penpot-board-evidence.md               (modified — in place)
docs/engineering/dispatch/tasks/design-addproduct-mobile/traceability-matrix-5.md               (modified — in place)
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-brief.md                        (modified — in place)
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-4.md                   (modified — in place)
```

**NOT written, verified:**

| Prohibited | Status |
|---|---|
| `apps/**`, `packages/**` — production source | **untouched.** G-7's seventh site was **recorded and routed**, not implemented: `product_detail_page.dart:471`/`:676` are production render sites and `ui_view_mappers.dart:176` is production |
| `docker/**`, `.github/**` | **untouched.** No Docker or Compose command was issued at all |
| `.decisions/**` | **untouched.** Read only; all nine named decisions RESOLVED, not re-opened |
| `WORK_STATE.md`, `LANES.md` | **untouched** |
| `design-addproduct-keyservice/**`, `design-adr-0018-amendment/**`, `design-review-*/**` | **untouched** |
| **every `BPM -` and `S -` / `DESKTOP -` Penpot board** | **untouched.** Zero board writes of any kind this pass; F6's boards read-only, never edited, renamed or deleted |
| the four `SM` boards | **also untouched** — no finding required a board write |

**No board was written this pass, including my own.** That is stronger than "I stayed in my lane" and it is
the accurate statement.

**`git status --short` in the worktree** shows exactly the nine paths above and nothing else.

---

## 9. Verdict and next action

`RESULT: DESIGN_REVISION_COMPLETE`.

**This revision is ready for independent design review and I am not approving it.** Two ownership blockers
(N6b F6, N6c G14/SC-9) remain open and **this correction closes neither** — both need a **grant** from the
Manager, and the reviewer noted that neither needs a human decision. The Manager should assign both owners in
this cycle rather than carrying them forward, since both block implementation.

I did not build the `WORKFLOW_IMPROVEMENT` tooling (N11/L-1), I did not fix F6, I did not implement G-7, and
I did not re-open any decision. Those are other lanes' or the Manager's, and saying so is the report, not a
gap in it.