# Design Revision 6 — record-only correction pass closing MR5-1 … MR5-7

Per `docs/engineering/DESIGN_GOVERNANCE.md` § *Artifacts → Design Revision*. Metadata in
`design-revision-metadata-6.yaml`. Lane report in `correction-report-6.md`. Corrections were applied **in
place** to revision 5's artifact set; § 4 publishes every one with its verified anchor.

```yaml
revision_id: CB4BEECA-CA9D-4F26-9464-E1B6F7C9BDCB   # carried: same design, corrected record
brief_id:    52CB4098-FF87-4B78-81DA-1104269551A1
revision_number: 6
supersedes:  CB4BEECA-CA9D-4F26-9464-E1B6F7C9BDCB   # revision 5, retained; its body is unedited except the 10 corrections in § 4
status: UNDER_REVIEW          # the Design Agent never approves its own work
risk_level: 3                # carried — see § 2. The marginal risk of THIS pass is Level 0.
```

**Provenance.** Worktree `/private/tmp/shipit-correct-addproduct-mobile`, branch
`design-correct-addproduct-mobile`, `BASE_SHA` = `HEAD_SHA` = `16cd49721646521d13ff6d962dcf82ef4719237e`.
The producing worktree held revision 5 as **uncommitted working-tree files** at `289f1d3`; before this pass
began, all 14 of them were verified **byte-identical** to the copies committed at `16cd497` (§ 6), stashed
under a named stash, and the branch fast-forwarded. Nothing committed, nothing pushed. **No Docker or Compose
command was run at any point in this pass**, including read-only ones. `flutter analyze` **NOT_RUN**; no
Flutter widget rendered; **no Penpot board was written, renamed, moved or deleted** — this pass needed no board
write and made none.

---

## 0. What this pass is, and what it deliberately is not

Revision 5's first independent review returned **`DESIGN_REVIEW_CHANGES_REQUIRED` with 0 BLOCKERS, 0 HIGH,
3 MEDIUM (MR5-1 … MR5-3) and 4 LOW (MR5-4 … MR5-7)**, and the reviewer's own summary was *"three record
corrections, not a redesign"* — *"None of these changes a board, a string, a geometry, a token or a
requirement."* This revision accepts that characterisation exactly.

**Every finding in the finding set is a correction to a published record.** Not one of them asks for a
different design, a different board, a different string or a different requirement. Accordingly:

- **No board was edited.** All four `SM` boards, all `BPM` boards and all `S` boards are byte-for-byte as the
  reviewer measured them.
- **No decision was re-opened.** All nine decisions named by the dispatch are `status: RESOLVED` and were
  read, not re-argued (§ 6).
- **No production source was written.** G-7's missing site is *recorded and routed*, not implemented — under
  A3 the two `product_detail_page.dart` sites render vault topology to the user, and they are production
  render sites this lane does not own.
- **No ownership gap was absorbed.** F6 is reported as an open ownership gap and needs an ownership grant
  (§ 3), exactly as instructed.

**What was NOT re-verified, and why that is the right call.** The reviewer verified live, on Penpot, that
every board claim reproduces: the custody string and its 80 characters, the layer renames, the 436→446 and
456→466 moves with 4px of preserved slack, the two-line wrap inferred from the layer's own height,
`Trust Created`'s exact box/font/fill/containment, `Disclose` left-aligned at 16 with zero dividers and zero
footer copy, the D-8 coordinate table row for row, inventory 160/164, layer counts 44/44/36/36 and 29/29/24/24,
and F6 itself on all four desktop boards. It also re-read and confirmed all 13 M-1 numbers, all three L-1
pointers, every source citation, all ten contrast figures to 0.00, the arithmetic of the `214.53px`
withdrawal, and the Level-3 gate discharge. **Re-spending that budget would be waste, not diligence.** This
pass re-verified only what the reviewer's findings made load-bearing (§ 6) and what the base advance made
load-bearing (MR5-5).

---

## 1. Which published suffix count was right

The dispatch and the review both ask for this explicitly: the artifact set published **three different
counts** for the same set of retirements, and **the correct value is 16**.

**The form that was right is `penpot-board-evidence.md` § 6 — *"All sixteen suffixes retired"*, enumerating
the eight layers** (`:182-187`). It is the only one of the three consistent with the live file, and the
reviewer's measurement settles it: each Unknown board carries **exactly 8** `Trust *` layers and **none**
suffixed; the Verified pair carries **0**. 8 × 2 = **16**.

| Where | Published | Verdict | Now |
|---|---|---|---|
| `penpot-board-evidence.md:182-187` | *"All sixteen suffixes retired"*, eight layers enumerated | **RIGHT** — the only live-consistent form | unchanged; now the reference form |
| `design-revision-5.md:169` | *"retired from **all sixteen** layer names"* | **RIGHT for the `PROVISIONAL` population, WRONG as a combined total** — `PENDING D4` was retired on **4** more names (one `Art S` per board, per § 3.2's own before/after table), so the combined set is **20** | split into two populations: **4 + 16 = 20** |
| `design-revision-5.md:361` · `penpot-board-evidence.md:262` | **`7 ×`** `Trust *` names | **WRONG** — the per-board count is **8** | `8 ×`, with *"16 suffixes across the pair"* stated in-cell |
| `design-revision-metadata-5.yaml:99` · `traceability-matrix-5.md:77` | **17** / **Seventeen** | **WRONG** — off by one from the measured 16 | **16** / **Sixteen** |

**Why the reviewer's alternative was not taken.** MR5-1's option of retiring the count as `NOT_VERIFIABLE`
was declined, with the reviewer's own reasoning: Penpot exposes no version history, so the *before* state is
unverifiable — but the *end* state **is** live-verifiable, and 8 unsuffixed layers × 2 boards is the direct
measurement of the retirement. **Publishing the correct number is better than publishing none**, and a
`NOT_VERIFIABLE` stamp on a figure that is measurable would trade a wrong number for a false absence of
knowledge.

---

## 2. Risk level — 3, carried, with the marginal level stated separately

**`risk_level: 3`, and the independent reviewer agreed (`RISK_LEVEL_AGREEMENT: YES`).** Revision 6 changes no
design, so it neither raises nor lowers the level; re-deriving it from scratch would produce an artifact that
describes a revision nobody is reviewing. All three Level-3 clauses remain met on the same evidence the
reviewer accepted: **core workflow / user mental model** (`898b07d0` splits identity from registration, so
*"Register product"* changes meaning), **information architecture** (a new user-facing element, `Trust
Created`, in no prior revision), and **navigation structure** (R.11g item 3's resume route on
`ProductDetailPage`).

**The Level-3 human gate remains discharged and is not re-opened.** All five load-bearing decisions —
`9417f8bf`, `27ea6536`, `898b07d0`, `ae1c1f79`, `7b1bc8b7` — are RESOLVED with `decided_by` the repository
owner and `owner: design-agent` follow-ups **2 / 3 / 2 / 2 / 1**. The **marginal** risk of *this pass* is
**Level 0** — a correction to published records, in the same sense the rev-4 reviewer applied Level 0 to
revision 4's marginal risk: Level 0 describes the change, not the artifact.

**Why it is not below 3 and why it does not exceed 3.** The ceiling was considered, not assumed: it would
exceed 3 only if a Human Decision were opened on the four desktop boards' footer copy in a way that changes
the normative outcome — it does not, the outcome is settled and only the board edit is unowned — or if the
resume affordance were built as a new top-level navigation destination rather than a resume route into the
existing credential flow. Neither is fired. **No human gate, and none requested.**

---

## 3. F6 — open, owned by nobody, and needing an ownership grant rather than a re-decision

**This is not mine and it was not fixed.** It is the only BLOCKER in the keys rev-5 review, and it is
reported here as an open ownership gap, per instruction.

| Fact | Measured |
|---|---|
| the four desktop `S - Add Product - …` boards carry a `Footer` **text** layer at rel **236,862**, 1020×15 | byte-identical copy to `add_product_page.dart:383-384` |
| the divider is `Footer Rule` at rel **236,848**, 1020×1 | so `27ea6536`'s "a divider" clause is **satisfied** |
| `Disclose` at rel 1036 → right edge **1256** = `236+1020` | so *"right-aligned"* is **satisfied** |
| **"No footer copy"** | **NOT SATISFIED** — on all four boards |
| `BPM` | carries the same false custody string (`ed25519 · private half stays in the keychain`) and the now-false `NOT REGISTERED YET` eyebrow (F5) |

**Why it needs a grant and not a re-decision.** `27ea6536` is RESOLVED, its normative outcome is settled and
unquestioned, and its own OPTION_B named this cost in advance: *"Requires `note: null` … **and editing the
four existing desktop boards, which no current lane owns** — so it needs a design-system-owner board edit."*
What is missing is a **lane with write access to those four boards**. They are `PROHIBITED` to this lane and
to the keys lane; **no lane currently owns them**. The decision is therefore not reopened here, no board is
edited, and no board this lane does not own is touched.

**Carried in three places so it cannot quietly die:** `design-revision-5.md` § 4.4 and § 12 (N6b);
`traceability-matrix-5.md` § 4; `design-brief.md` **SC-7**, which now reads `MET on mobile · NOT MET on
desktop (F6)` and points at N6b. **SC-9 / G14 (N6c) is carried the same way** — a correct scoping call, not
an unfunded requirement: rendering the A3 remediation copy needs two boards outside `OWNED_PATHS`, and R.11g
item 5 forbids folding it onto the Unknown-host board. The copy and the full layout are specified; only a
board owner is missing.

---

## 4. Every correction applied, with its verified anchor

Each row was applied, then **re-read from the live file after the edit**, and the anchor below is the line as
it now reads. Nothing is reported from memory.

### MR5-1 (MEDIUM) — the retired-suffix count, wrong in two of its three published forms

| # | File | Was | Now | Anchor, re-read |
|---|---|---|---|---|
| 1 | `design-revision-5.md` | `7 × \`Trust *\` names` | `8 ×`, plus *"16 suffixes across the pair"*, with the old value named in-cell | **`:361`** ✓ |
| 2 | `penpot-board-evidence.md` | `7 × \`Trust *\` layer names` | `8 ×`, with the old value named in-cell | **`:262`** ✓ |
| 3 | `design-revision-metadata-5.yaml` | `Seventeen` | `Sixteen`, + the 4 `PENDING D4` suffixes, with the old value named | **`:101`** (was `:99`; +2 from the provenance comment) ✓ |
| 4 | `traceability-matrix-5.md` | `17 suffixes retired` | `16`, with the old value named | **`:77`** ✓ |
| 5 | `design-revision-5.md` | one sentence conflating both markers | split: **4** `· PENDING D4` + **16** `· PROVISIONAL` = **20** | **`:169-172`** ✓ |

Item 5 keeps the paragraph at **exactly four lines**, so every published anchor below it in that file is
unmoved. The full statement of which form was right is § 1.

### MR5-2 (MEDIUM) — the design brief recorded the lane's own BLOCKER as met

| Defect | Fix | Anchor, re-read |
|---|---|---|
| SC-7 had **no `NOT MET` disposition**, one row above SC-9's explicit one | now `**MET on mobile · NOT MET on desktop (F6).**` | **`design-brief.md:98`** ✓ |
| SC-7 cited **§6.3** (which is D-8) instead of **§6.4** (the desktop conformance read-back and F6) | cites **§6.4** for desktop, §6.3 for mobile | same ✓ |
| **F6 appeared nowhere in the brief** — `grep -n "F6\|footer copy\|N6b"` returned no hits | SC-7's verification cell now names **F6**, the `Footer` text layer at rel 236,862, and **N6b**, and states that F6 needs an **ownership grant, not a re-decision** | same ✓ |

The row is one line, so `design-brief.md` is still 169 lines and its other published anchors do not move.

### MR5-3 (MEDIUM) — G-7's site table omitted the file that constructs the view

| Change | Where | Anchor, re-read |
|---|---|---|
| **site 7 added: `apps/server/lib/src/services/ui_view_mappers.dart:176`** — `static RepositoryCredentialView repositoryCredentialView(RepositoryCredential c)`, `referenceName: c.referenceName,` | `design-revision-5.md` § 6.1 table | **`:424`** ✓ |
| *"6 sites"* → *"7 sites, not 6"*, with the consequence stated: **dropping the field from the YAML regenerates both client packages without it and this call site will not compile** | § 6.1, new paragraph | **`:426-435`** ✓ |
| the same file named in **N6a**, which is the row route **N6a** sends the implementer | § 12 | **`:655`** (was `:643`) ✓ |
| `MEASURED 6 sites` → `MEASURED 6 sites (**7 as of revision 6, MR5-3**)` | `design-revision-metadata-5.yaml` N6a | **`:230`** ✓ |
| matrix evidence row **6 sites → 7 sites**, naming the constructor | `traceability-matrix-5.md` § 2 | **`:85`** ✓ |
| **the deliberate retentions are now stated**, so a future lane does not "helpfully" strip them: `platform_contracts` / `product_credential` / `postgres_product_registry_store.dart` / `schema_bootstrap.dart` are kept per `9417f8bf:167` (*"`referenceName` becomes an opaque row reference"*), and `generated/protocol.dart:3841` is the **`product_credential` DB table** (named at `:3810`), not the client view | § 6.1, new paragraph | `:430-435` ✓ |

**The 6-site *scope* was right and is unchanged.** MR5-3 is about one missing file, not about a wrong
boundary — the reviewer's own classification of the ~30 repo-wide `referenceName` occurrences was correct and
is now recorded rather than left implicit.

### MR5-4 (LOW) — two files written in the same pass disagreed by one

`design-revision-4.md:160` said the rev-3 §12 block is **`:624-644`**; `design-revision-metadata-4.yaml:154`
and `design-revision-5.md:62` said **`:623-644`**. Measured at `16cd497`: heading **`623`**, last content
**`642`**, blank **`643`**, `---` **`644`**. **`:623-644` is the right form** — it starts at the heading — and
three of the four sites already said so, so rev 4 is corrected to it, with the re-measurement named.

| File | Anchor, re-read |
|---|---|
| `design-revision-4.md:160` | ✓ now `:623-644` |
| `design-revision-5.md:62` · `:600` · `design-revision-metadata-4.yaml:154` | ✓ all `:623-644`, unchanged |

### MR5-5 (LOW) — the provenance basis was stale at the reviewed head

**What the reviewer found:** `43d328b → 289f1d3` was empty, but `289f1d3 → 08c7590` touches **4** files, so
the *stated basis* was stale at the head being reviewed even though no cited line was wrong.

**Confirmed, and the advance has gone further.** At this pass's base:

```
git diff --name-only 43d328b 16cd497 -- apps/control_plane packages
  packages/product_registry/lib/src/engine/product_registry_engine.dart
  packages/product_registry/lib/src/store/in_memory_product_registry_store.dart
  packages/product_registry/lib/src/store/product_registry_store.dart
  packages/product_registry/test/credential_test.dart
```

**4 files, unchanged from the reviewer's count.** **Every one is in `packages/product_registry/**`, which
this revision cites nothing in.**

**The fix is the second of the reviewer's two options — state the basis in a form that still holds.** Every
`:NNN` cited into `apps/control_plane/**` and `apps/server/**` was **re-read individually at `16cd497`**, and
all hold (§ 6, table 2). The empty-diff claim is not deleted — it was true at `289f1d3` — it is **qualified
with the advance**, in all three places it appeared:

| Site | Anchor, re-read |
|---|---|
| `design-revision-5.md` provenance block — branch head now stated as `16cd497` | **`:18`** (block `:16-20`) ✓ |
| `design-revision-5.md` § 4.2 table header — range-diff stated, then superseded | `:235` ✓ |
| `design-revision-5.md` § 13 `implementation_feasibility` — basis restated per-citation | `:672` ✓ |
| `design-revision-5.md` § 14 validation row — the correction is the row's own text | `:683` ✓ |
| `design-revision-metadata-5.yaml` `head_sha` — commented, **not deleted** | `:18-20` ✓ |

**Rev 5 is also no longer wholly untracked.** It was reviewed as working-tree files only; `16cd497` commits
it. That removes the reviewer's compounding concern, and it is why the fast-forward was safe to perform.

### MR5-6 (LOW) — SC-8 cited the wrong section

`design-brief.md:99` verified `Trust Created` against *"§4 of `design-revision-5.md`"*; §4 is H-1(b), the
footer. **`Trust Created` is in § 5.1 / § 5.2.** Re-cited, with the error named in-cell. Same wrong-section
class as MR5-2; the reviewer's classification is adopted without re-derivation.

### MR5-7 (LOW) — *"zero intra-panel overlaps"* was not literally true

Measured: `Trust Btn` (`30,618 180×30`) geometrically encloses `Trust Btn L` (`30,624 180×18`), and
`Submit (label only — no nested subtext)` (`16,510` / `16,678`, 358×34) encloses `Submit L`. That is the
button-rect-plus-label idiom, **not a defect**, and the same file already draws exactly this distinction for
the 1px `Art T`/`Art S` box overlap. Wording precision only; **the substantive claims are unchanged** —
`Trust Created` is contained, the chain geometry is unchanged, zero nav collisions. Both sites corrected to
name the exception rather than drop the claim.

| Site | Anchor, re-read |
|---|---|
| `design-revision-5.md` § 5.2 | **`:376-377`** ✓ |
| `penpot-board-evidence.md` § 6.2 | **`:266-267`** ✓ |

---

## 5. Anchor migration — published, because the corrections themselves moved lines

MR5-1's lesson is that a correction moves the line it cites. **These corrections moved lines, so the migration
is published rather than left for a reader to discover.** Every anchor the review cites into this lane's
artifacts is listed.

| Cited by the review as | Now reads at | Which correction moved it |
|---|---|---|
| `design-revision-5.md:361` | **`:361`** ✓ unchanged | MR5-1 item 1 — in-place value fix |
| `design-revision-5.md:169` | **`:169-172`** ✓ unchanged (4 lines before and after) | MR5-1 item 5 — split in place, line count held |
| `design-revision-5.md:376` | **`:376-377`** ✓ unchanged (2 lines before and after) | MR5-7 — in-place wording fix |
| `design-revision-5.md:62` | **`:62`** ✓ unchanged | — |
| `design-revision-5.md:588` | **`:600`** (+12) | **MR5-3** — the § 6.1 site-7 block adds 12 lines *above* it. The sentence at `:600` is the same `:623-644` line MR5-4 is about; `:643` → `:655` (N6a), `:660` → `:672`, `:671` → `:683` |
| `design-revision-metadata-5.yaml:99` | **`:101`** (+2) | MR5-1 item 3, after the provenance comment added 2 lines at `:18` |
| `traceability-matrix-5.md:77` · `:85` · `:76` | **`:77`** · **`:85`** · **`:76`** ✓ unchanged | in-place value fixes; the file is still 132 lines |
| `penpot-board-evidence.md:262` · `:266` · `:181-188` · `:346` | **all unchanged** ✓ | in-place fixes; the file is still 455 lines |
| `design-brief.md:98` · `:99` · `:135` | **all unchanged** ✓ | in-place fixes; the file is still 169 lines |
| `design-revision-4.md:160` | **`:160`** ✓ unchanged | MR5-4 — in-place value fix |

**Verified against the review's citations, this is the complete set.** A repo-wide grep found no other
artifact citing a line number inside `design-revision-5.md`, `design-revision-metadata-5.yaml`,
`traceability-matrix-5.md`, `penpot-board-evidence.md` or `design-brief.md` other than
`design-review-addproduct-mobile-rev5/report.md`. (`design-review-addproduct-keys-rev5/report.md` cites
`design-revision-5.md:2414` and `design-revision-metadata-5.yaml:739-742` — out of range for these files,
which have 746 and 318 lines. Those are the **keys lane's own** artifacts of the same name, in
`design-addproduct-keyservice/`. Not ours, and not corrected here.)

---

## 6. Validation

| Check | Result |
|---|---|
| `git branch --show-current` | `design-correct-addproduct-mobile` ✓ |
| `git rev-parse HEAD` | `16cd49721646521d13ff6d962dcf82ef4719237e` ✓ |
| Pre-flight: rev-5 artifacts identical to the copies at `16cd497` | **14 of 14 byte-identical** (`diff -q`), verified before the fast-forward; a backup was taken first and re-compared after ✓ |
| `git merge --ff-only 16cd497` | **fast-forward**, `289f1d3 → 16cd497`, clean tree ✓ |
| `penpotUtils.getPages()` | **`["Page 1"]`**, id `d8ac01df-6646-81d2-8008-a366c09aa9d3` ✓ (`penpot_high_level_overview` read first) |
| Penpot boards written / created / renamed / deleted | **0 / 0 / 0 / 0.** No board write was needed or made ✓ |
| Nine named decisions | all `status: RESOLVED` (14 of 14 decision files in `.decisions/**` are RESOLVED) — **read, not re-opened** ✓ |
| `design-revision-metadata-5.yaml` fenced-YAML parse | **7 of 7 blocks parse.** F8's claim re-confirmed and my edits preserved it ✓ |
| F6, unchanged | the four `S` boards were **not** touched. Still an open ownership gap (§ 3) |
| SC-9 / G14, unchanged | still `NOT MET — reported, not claimed`; the copy and layout remain fully specified |
| Commit / push | **NOT_RUN** — forbidden by the dispatch |
| Any Docker or Compose command, incl. `info`/`ps`/`logs`/`config` | **NOT_RUN — none issued. No breach.** `AGENTS.md` § *Shared Docker state* honoured |
| `flutter analyze` / widget render / pixel diff | **NOT_RUN** — no claim in this revision rests on any of them |

### Table 1 — anchors of the corrections themselves, re-read after each edit

| Correction | File | Anchor | Verified content |
|---|---|---|---|
| MR5-1.1 | `design-revision-5.md` | `:361` | `8 × \`Trust *\` names` |
| MR5-1.5 | `design-revision-5.md` | `:169-172` | *"…two populations… **4** … plus **16** … **20 in all**"* |
| MR5-1.2 | `penpot-board-evidence.md` | `:262` | `8 × \`Trust *\` layer names` |
| MR5-1.3 | `design-revision-metadata-5.yaml` | `:101` | `**Sixteen** \`· PROVISIONAL\` suffixes retired` |
| MR5-1.4 | `traceability-matrix-5.md` | `:77` | `**16** \`· PROVISIONAL\` suffixes retired` |
| MR5-2 · MR5-6 | `design-brief.md` | `:98` · `:99` | SC-7 `MET on mobile · NOT MET on desktop (F6)`, § 6.4 · SC-8 § 5.1 / § 5.2 |
| MR5-3 | `design-revision-5.md` | `:424`, `:426-435`, `:655` | site 7 · *"7 sites, not 6"* · N6a |
| MR5-3 | `design-revision-metadata-5.yaml` | `:230`, `:237` | `7 as of revision 6` · `ui_view_mappers.dart:176` |
| MR5-3 | `traceability-matrix-5.md` | `:85` | `**7** sites measured` |
| MR5-4 | `design-revision-4.md` | `:160` | `:623-644` |
| MR5-5 | `design-revision-5.md` | `:18` (block `:16-20`), `:235`, `:672`, `:683` | head `16cd497` stated; range-diff qualified; per-citation basis |
| MR5-5 | `design-revision-metadata-5.yaml` | `:18-20` | `head_sha` commented, not deleted |
| MR5-7 | `design-revision-5.md` | `:376-377` | *"…other than the button-rect-plus-label idiom"* |
| MR5-7 | `penpot-board-evidence.md` | `:266-267` | same |

### Table 2 — every source citation re-read individually at `16cd497` (MR5-5)

| Citation | Line reads |
|---|---|
| `add_product_page.dart:314` · `:316` · `:317-319` | `_buildFooter(context),` · `TechnicalDetails(` · `note:` + the shared string |
| `…:375` · `:383-384` | `Widget _buildFooter(BuildContext context) {` · *"Your decision is recorded permanently. The same piece of work then continues — nothing is restarted."* |
| `…:542` **and** `:1038` | `ed25519 · created on this device · the private half stays in the keychain` — **both**, so D-4's "two false halves, two sites" holds |
| `…:925` · `:926-928` | `TechnicalDetails(` · `note:` + the same string as `:317-319`, so D-3 holds |
| `shared/design_primitives.dart:362` · `:396` · `:402-403` | `const TechnicalDetails({… this.note});` · `const ContentRule(),` painted unconditionally · `Expanded(child: widget.note == null ? const SizedBox.shrink() …)` — so D-2's derivation holds |
| `product_detail_page.dart:471` · `:676` | `'${c.referenceName} · ${c.algorithm} ${c.fingerprint} · '` · `: '${c.referenceName} · ${c.algorithm} '` — both render sites hold |
| `control_plane_repository.dart:108` · `:1098` · `:1691` · `:1709` | the four client projections hold |
| **`ui_view_mappers.dart:176`** *(MR5-3)* | `referenceName: c.referenceName,` — **the seventh site, confirmed to exist** |
| `design_tokens.dart:92` · `:99-101` · `:120-123` | `canvas: 0xFFF7F7F5` · `inkPrimary/inkSecondary/inkTertiary` light · dark — the token set is unchanged |
| `design-revision-3.md:60-62` · `:449-450` · `:452-486` · `:583` · `:592` · `:623-644` · `:646` | all three L-1 pointers present; `grep -n '^## '` → `:646 ## 13. Assumptions carried forward` |
| `design-revision.md:83` · `:85` · `:89-95` · `:435` · `:437-444` | **all five M-1 numbers exact** |
| `report.md:31-37` · `:68` · `:70-74` · `:126` · `:128-133` · `:230` · `:237-243` | **all seven M-1 numbers exact** |
| `design-revision-metadata.yaml:15-16` | **CONFIRMED still correct** |

**All 13 M-1 numbers remain exact, as the reviewer found them.** None of this pass's edits touched
`design-revision.md` or `report.md`, and none touched a cited line in `design-revision-3.md`.

---

## 7. What this revision does **not** evidence

- **No board evidence of its own.** Every board claim here is the reviewer's live measurement, adopted. This
  pass opened Penpot once, to satisfy the dispatch's `VALIDATION_COMMANDS` with `getPages()`. **The boards
  are exactly as reviewed** — this pass wrote nothing to Penpot, which is a stronger statement than a
  re-measurement and is also the honest one.
- **No Flutter widget was rendered**, no screenshot, no build, no analyzer run.
- **No automated pixel diff.** Nothing in this revision rests on pixels.
- **Pre-edit board state** remains `NOT_REVERIFIABLE` — Penpot exposes no version history. Unchanged.
- **F6 is not closed, and this revision does not close it.** It is reported, and it needs an owner.
- **SC-9 is still NOT MET.** Carried as a scoped gap, not worked around.
- **No trace of the ~30 `referenceName` occurrences was re-classified beyond MR5-3's site 7.** The reviewer's
  6-site scope was correct and is recorded rather than re-derived.
- **I do not approve this work.** It goes to independent design review, and a Design Contract freeze remains
  prohibited while F6 is unowned.

---

## 8. Safe parallelism

```yaml
SAFE_PARALLEL_WORK:
  - The keys lane — disjoint paths. NOTE: N6a now names SEVEN sites, including the server-side view
    constructor apps/server/lib/src/services/ui_view_mappers.dart:176, which will not compile without the
    change. Work the seven, and leave platform_contracts / product_credential / the persistence layer alone
    (9417f8bf:167 keeps them deliberately).
  - Non-UI implementation prep on add_product_page.dart — the custody string at :542 AND :1038 (D-4),
    note: null at :317 and :926, deletion of _buildFooter (:375/:314) (D-3). Every number re-read at 16cd497.
  - ADR 0018's A2 amendment recording the 9417f8bf supersession (owner: human / ADR owner).
PROHIBITED_PARALLEL_WORK:
  - Design Contract freeze of revision 6 — two ownership blockers (N6b F6, N6c G14/SC-9) are open, and this
    correction does not close either
  - Implementation of the desktop FOOTER against the four S boards — they do not conform, and no lane owns
    them. The BUILD change (note: null, _buildFooter deletion) may proceed; the BOARDS may not be edited by
    any lane without a grant.
  - Any lane editing the four SM boards, or any BPM / S - Add Product board, or .decisions/**, or this lane's
    task directory
  - Authoring the refused-mint surface on the Unknown-host board — forbidden by R.11g item 5
  - "Helping" with G-7 by also stripping referenceName from platform_contracts / product_credential / the
    persistence layer — 9417f8bf:167 keeps them deliberately
```

---

## 9. Recommended next action

**`INDEPENDENT_DESIGN_REVIEW` (Gate D3).** This revision needs no further design pass and no human gate. The
reviewer also recommended — and this pass endorses — that the **Manager assign the two board owners in this
cycle rather than carrying N6b and N6c forward**, since both block implementation and **neither needs a
human**: N6b needs a grant over the four `S` boards, N6c needs a grant over two new ones.

**I do not approve this work, and I am not asking for it to be reviewed as a Design Contract freeze.**