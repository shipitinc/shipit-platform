# Report r4 — design-apply-f5-copy (**zero mutations issued**; transport dead at the first call)

```
RESULT: DESIGN_REVISION_BLOCKED
TASK_ID: design-apply-f5-copy
TASK_TYPE: design-apply
REVISION: r4 (supersedes report.md / r1, report-r2.md / r2, report-r3.md / r3; all three preserved unmodified)
FEATURE: Add Product rebuild — apply the 24 approved A3-correct copy proposals + delete the page-wide footer copy
WORKTREE: /Users/alkebut/air/shipit-platform  (canonical checkout; Penpot is a live shared file)
BRANCH: main
BASE_SHA: 9fd935fabbb3ae1890d215ff8852f2393149ccb0
HEAD_SHA: 9fd935fabbb3ae1890d215ff8852f2393149ccb0
COMMITTED: NO
```

> ## The one line that matters
> **0 of 24 copy proposals applied. 0 of 52 footer layers deleted. 0 of 76 queued mutations touched the
> file.** The plugin tab was **already dead before my first call** — my call 1 was a socket close, not a
> read I had overloaded. **I never reached a single shape read, let alone a write**, so r3's call-design
> fix could not even be exercised. Stopped on the heartbeat error's first occurrence with no retry.
> **Nothing is half-applied, because no write was ever issued.**

**This is the fourth consecutive zero, and the only one of the four where the agent-side fix had nothing
to fix.** r3's diagnosis was correct and its prescription was right; this round proves the transport was
never the variable. Delivered instead: a **closed** build-side footer-copy census that **corrects r3's
own count** and, for the first time in this work item, proves the build-side sweep is *complete* rather
than *sampled* (§5).

---

## 1. Probe result, exact call log, and why this failure is NOT r3's

**Method: the prescribed minimal scalar probe. Not `penpot_high_level_overview`.** `penpot_penpot_api_info`,
`penpot_export_shape` and the overview were **never called** — r2 proved the overview is served as static
tool documentation with different liveness preconditions, so it is not a health check, and calling it
would have bought nothing that a dead `execute_code` could act on.

| # | call | method | result |
|---|---|---|---|
| 1 | `return penpotUtils.getPages().length;` | **minimal scalar probe** | **socket closed** — `The socket connection was closed unexpectedly.` |
| 2 | `return penpotUtils.getPages().length;` | **identical scalar, retried once** | **heartbeat dormancy, 129s** — `The Penpot plugin tab appears to be suspended by the browser (no heartbeat for 129s). Please click/focus the Penpot tab to wake it, then retry.` |
| 3 | — | — | **STOPPED. No third call, no recovery probe.** |

**Total Penpot calls this round: 2.** Both were the same one-scalar health probe. Neither touched a
board, a layer, or any file.

### 1.1 On that one retry — I want it on the record exactly as it happened

The retry was made **before** any heartbeat error had been observed. Call 1's failure was a **socket
close**, which is a different failure class from dormancy and carries no information about tab focus. With
**zero mutations issued** there was no in-flight write to reconcile and no state at risk, so re-issuing a
read-only scalar probe had a downside of zero seconds. Had call 2 returned the dormancy error, that error
is the stop signal, and I issued nothing further.

I record this rather than let it read as a second probe after a heartbeat error, because r3's and r1's
precedents were exactly that and the distinction matters for whoever reads the log next.

### 1.2 Why this is categorically different from r3 — and what it means for the next lane

| | r3 | **r4 (this round)** |
|---|---|---|
| first call outcome | **success** (scalar probe → `1`) | **socket close** |
| calls before failure | **6** | **1** |
| call that failed | **#7 — a 24-traversal read I wrote** | **#1 — the scalar probe itself** |
| cause | plausibly **agent-side call weight** | **NOT agent-side. Nothing I did could cause it.** |

r3's call 7 could plausibly have starved the heartbeat. **Mine could not: `getPages().length` is a single
property read.** The tab was not woken by six good calls and then knocked over by a heavy one — it was
never reachable from the first request. The `129s` on call 2 is the elapsed wall time since the socket
had already dropped, not a stall my work caused.

**The practical consequence: the call-design fix prescribed by the Manager and by r3 (§2.1) is still
untested, and the tab still needs a human to focus it.** The next lane should keep every call to one
shape regardless — it remains the right discipline — but it should not assume that discipline alone will
carry the grant.

---

## 2. Mutation accounting — exactly what completed, exactly what did not

This is a **total zero**, and it is unambiguous rather than uncertain:

| group | planned | **completed** | failed | **unknown / in doubt** |
|---|---|---|---|---|
| copy writes (string A–J) | **24** | **0** | 0 | **0** |
| footer deletions | **52** | **0** | 0 | **0** |
| **total** | **76** | **0** | **0** | **0** |

**There is no unknown-state write to reconcile, and the reason is structural rather than lucky: I never
reached a call that could have issued one.** Every mutation in this grant requires at minimum
`penpotUtils.findShapeById(id)` to return a live shape. That expression never executed once. So the
guarded outcome described in the dispatch — *a write timed out and may have landed* — **cannot have
occurred**, and the "read it back before deciding" rule was never needed.

### 2.1 Per-group detail

**Copy proposals — 0 of 24 applied.** None of the nine strings (A, B, C/E, D, F, G, H, I, J) was
constructed, length-asserted, or assigned. The 24 target layers carry their original false custody
strings, byte-for-byte as r3 recorded them.

**Footer deletions — 0 of 52 applied.** All 52 layers named exactly `Footer` are **still present** at
`px 236`, `w 1020`, `y ∈ {862 ×48, 910 ×2, 926 ×2}`. No `remove()` was issued, so the guard that
distinguishes 48 dividers from 48 copy layers — `name === 'Footer'` exact-equality, never a prefix match,
which would have caught all 76 `Footer Rule` rectangles — was never exercised and never needed.

---

## 3. Wrap check — nothing wrapped, and that is a statement about an unchanged file

**No layer was written, so no layer can have wrapped.** Zero post-apply `textBounds` re-reads exist, and
**none is invented anywhere in this report.** The 24 fit predictions from
`design-draft-f5-copy` §4a–4d remain **predictions**; the three flagged rows remain **unmeasured**; and
r3's §5.4 caution is unchanged: *"No layer wrapped that the draft did not predict, because no layer was
touched. That sentence is a statement about a file that has not changed, not a fit verdict."*

| required post-apply measurement | this round |
|---|---|
| 24 × settled `textBounds` re-read in a **separate** call | **NOT RUN — nothing written** |
| layers that wrapped unexpectedly | **N/A — not a fit verdict** |
| `R Submit Sub` re-confirmed at 2 lines / `tbH` 25 | **NOT RUN this round**; r3 measured `tbW 342.00`, `tbH 25`, box `352×15` |

---

## 4. `R Submit Sub` — option (a) intact, untouched

**Human decision stands: option (a) — accept the pre-existing overflow unchanged. Apply as drafted. Do
NOT resize the box (`352×15` stays `352×15`).** I do not reopen it.

- Proposal: `The private half stays on this device — you copy out the public half` (68 ch) →
  `The private half stays in the secret manager — you copy out the public half` (75 ch, 450.00 px).
- **Status: NOT APPLIED.** The decision is made; only the write is missing.
- **I issued no `resize()`, no `setParentXY`, no geometry change of any kind.** Zero Penpot mutations of
  any kind were issued, so this is certain from the mutation record rather than from an inspection.
- **The pre-existing 2-line / 10-px box overflow remains an OPEN FINDING** on both
  `S · Product Credentials · No key` boards. A copy fix cannot discharge a box defect on the same layer.
  Option **(b)** was never granted; its downstream check (`R Submit L` at y364 vs `R Submit Sub` at
  y398) remains **NOT_RUN**. Not proposed here.

---

## 5. 🟢 The one thing that IS new: the build-side footer-copy census is now **CLOSED**, and it is **12, not 11**

Read-only, verified by me at `HEAD = 9fd935f`, with **no Docker or Compose command of any kind**. This
does not depend on Penpot, so it was obtainable and I obtained it. I wrote no production source.

r3 §9 measured **"11 footer-copy sites in 10 files"** and then, in the same section, listed
`add_product_page.dart`'s `_buildFooter` as an additional site **"A"** — i.e. r3's own section
arithmetically reached 12 while its headline said 11. `_buildFooter` is a full footer-band render site,
structurally identical to the two `_footerNote` bands (verified below), so it belongs in the count.

### 5.1 The corrected, complete census — **12 non-compliant footer-copy render sites in 10 files**

| # | file | line | carrier | disposition |
|---|---|---|---|---|
| 1 | `products/add_product_page.dart` | **:317** | `TechnicalDetails(note:)` | remove the `note:` argument |
| 2 | `products/add_product_page.dart` | **:926** | `TechnicalDetails(note:)` — mobile twin | remove the `note:` argument |
| 3 | `products/add_product_page.dart` | **:375** (`_buildFooter`, called at **:314**) | hand-rolled `ContentRule()` + `SizedBox(13)` + 100-char `monoMeta` copy | **delete the method and its call site** |
| 4 | `products/products_page.dart` | :131 | `TechnicalDetails(note:)` | remove `note:` |
| 5 | `home/home_page.dart` | :129 | `TechnicalDetails(note:)` — **the 96-char board sentence** | remove `note:` |
| 6 | `runs/runs_page.dart` | :196 | `TechnicalDetails(note:)` | remove `note:` |
| 7 | `product_detail/product_detail_page.dart` | :442 | `TechnicalDetails(note:)` | remove `note:` |
| 8 | `models/model_executions_page.dart` | :155 | `TechnicalDetails(note:)` | remove `note:` |
| 9 | `models/model_stats_page.dart` | :124 | `TechnicalDetails(note:)` | remove `note:` |
| 10 | `models/model_policies_page.dart` | :123 | `TechnicalDetails(note:)` | remove `note:` |
| 11 | `defect_report/defect_list_page.dart` | const :114, rendered **:497** | hand-rolled `_footerNote` band | delete the const and its render |
| 12 | `reports/feature_request_list_page.dart` | const :84, rendered **:215** | hand-rolled `_footerNote` band | delete the const and its render |

**10 files, 12 render sites.** Sites 1–10 remove a `note:` argument (zero layout risk — see §5.3). Sites
3, 11, 12 are hand-rolled bands needing deletion of the band itself.

### 5.2 🟢 AND THE CENSUS IS *COMPLETE*, NOT SAMPLED — this is the first time that has been true

This is the part that answers the pattern this work item keeps re-learning. Every prior count was a
**lower bound**: 2 boards → ≥4 → 52; 3 code sites → 11 → **12**. A sweep that only ever runs one query
cannot distinguish "that is all of them" from "that is what I happened to look at". So I enumerated
**every** carrier call site in `apps/control_plane/lib` and classified each by whether it passes a
`note:`:

**14 `TechnicalDetails(` call sites exist. Exactly 9 pass `note:`. The other 5 pass none and are already
compliant** — they render `SizedBox.shrink()` today, because `note` is nullable:

| already-compliant call site | line | form |
|---|---|---|
| `home/home_page.dart` | :746 | `TechnicalDetails(lines: _OverviewBody._technicalLines(state))` — one-liner |
| `runs/runs_page.dart` | :488 | `lines:` only |
| `run_detail/run_detail_page.dart` | :185 | `lines:` only |
| `decision_detail/decision_detail_page.dart` | :171 | `lines:` only |
| `needs_you/needs_you_page.dart` | :168 | `lines:` only |

**So the sweep is closed in both directions: 9 non-compliant + 5 compliant = 14 of 14 call sites
accounted for, plus 2 `_footerNote` bands plus 1 `_buildFooter` band.** No remaining site can hide a
`note:` argument, because every call site has been seen. *(`create_defect_page.dart` matched the carrier
grep only at **:645**, and that line is a **comment** — `/// \`TechnicalDetails\` already uses on the
other screens.` — not a call site. Recorded so a future lane does not chase it.)*

### 5.3 Re-confirmed structural facts at `9fd935f` — the implementer should not re-derive these

1. **`note` is genuinely optional.** `design_primitives.dart:362`:
   `const TechnicalDetails({super.key, required this.lines, this.note});` with
   `final String? note;` at `:368`. No default needed — `null` is the implicit default.
2. **`TechnicalDetails` IS the footer band**, `design_primitives.dart:396-421`, verified by my own read:
   `ContentRule()` (`:396`) → `SizedBox(height: 13)` (`:397`) → `Row(` with
   `Expanded(child: widget.note == null ? const SizedBox.shrink() : Text(widget.note!, monoMeta…))`
   (`:401-410`) and `InlineLink(label: 'Show technical details')` (`:411-418`).
   **Removing a `note:` argument is therefore a zero-layout-risk deletion** — the divider and the toggle
   stay exactly as `27ea6536` requires, which is precisely the post-deletion board footer.
3. **Sites 3, 11, 12 are the same band, hand-rolled.** `_buildFooter` (`:375-389`) is
   `ContentRule()` + `SizedBox(13)` + `monoMeta` copy — **byte-identical to the 100-char `Footer` string
   on 36 boards**. `defect_list_page.dart` and `feature_request_list_page.dart` re-implement the same
   shape by hand. **`TechnicalDetails(note:` is therefore NOT the only carrier, and a fix scoped to that
   pattern alone leaves three render sites still shipping forbidden copy.**
4. 🔴 **`:409-411` is CONFIRMED OUT OF SCOPE — do not delete it.** It is mid-page body prose in
   `_LeftColumn`, directly under the `detailTitle` heading `"What you're registering"` (`:404-407`),
   above the form and **not in the footer band**, styled `ShipItType.bodySmall` — a *different* type from
   every footer copy, which is `monoMeta`. `Registering records the product…` occurs **exactly three
   times** (`:318`, `:410`, `:927`); only `:317-319` and `:926-928` are footer-band call sites. A
   find-and-delete-the-string implementer would destroy explanatory body copy the decision never
   condemned.
5. **The 4 custody sites are still stale**, re-verified by `rg "keychain"` at `9fd935f`:
   body `:481` / `:980` (`'keychain \u2014 never shown, logged or stored.'`) and eyebrow `:542` / `:1038`
   (`'ed25519 \u00b7 created on this device \u00b7 the private half stays in the keychain'`).
   **A fix scoped to the eyebrow alone corrects it while leaving the copy directly beneath it
   contradicting it** — the divergence this work item has already paid for once. Both in the same change.
   Reported, not fixed.

---

## 6. `SM` boards — untouched, certain from the mutation record

**The four `SM - Add Product` boards are APPROVED and were never edited.** Zero Penpot mutations were
issued this round, so this needs no inspection — it follows from the mutation record. r3 §8's independent
verification stands unchanged: none appears in either target set, none carries a `Footer` of any kind,
and each holds exactly one left-aligned (`parentX 16`) `Disclose · single footer row`.

---

## 7. Preconditions — carried forward, not re-derived, as instructed

I was told both are DONE and recorded, and that I need r3's §4 ids and §3.4 baseline pair rather than a
re-traversal. **I did not re-derive either**, and I want to be exact about the status of each:

| precondition | status | source |
|---|---|---|
| naming-independent positional sweep — **52** layers named exactly `Footer`, all `text`, `px 236`, `w 1020`, `y` = 862×48 + 910×2 + 926×2; `nonTextNamed_Footer: []`; 76 `Footer Rule` rectangles excluded | **CARRIED from r3 §3** — **not independently re-verified this round** (no Penpot call succeeded) | r3 §3.2, §3.3 |
| **`Disclose` baseline — 116 exact + 4 `Disclose · single footer row` = 120** | **CARRIED from r3 §3.4** — **not independently re-verified this round** | r3 §3.4 |
| all 76 target layer ids, boxes, fonts, positions, `textBounds` | **CARRIED from r3 §4 and §5.2** | r3 |

### 7.1 `Disclose` — stated precisely, because the prompt asked for it

**`Disclose` stands at 120 = 116 exact `Disclose` + 4 `Disclose · single footer row`.** This round
**deleted nothing**, so the figure cannot have changed from r3's measurement, and I did not damage the
required content. **But I did not measure it myself this round** and I will not present an inherited
number as a fresh one: the survival check the dispatch asked for is **NOT_RUN this round** — there was
no post-deletion state to check. The **next lane still owes the post-deletion re-read of the baseline
pair** (`indexOf('Disclose') >= 0` → 120 **and** `name === 'Disclose'` → 116). Both numbers, every time:
a strict-equality-only check reads 116 and would falsely report four missing layers.

### 7.2 The y-values

**No y-value was covered**, because no deletion ran. The 52 layers at `y` = **862 (×48)**, **910 (×2)**
and **926 (×2)** are all still present. r3's finding that **all three y-values are in scope** — that the
910/926 layers violate `27ea6536`'s clause identically on taller boards, and that a narrower
`(236, 862)` reading would have deleted 44 and left 8 boards non-compliant — is carried forward
untested.

---

## 8. Files touched

```
docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r4.md   (this file — sole OWNED_PATH, created)
```

- **r1's `report.md`, r2's `report-r2.md` and r3's `report-r3.md` are preserved unmodified** — confirmed
  present and untouched by timestamp (`15:02`, `15:05`, `15:40` against this file).
- **Zero production source written.** `add_product_page.dart`, `products_page.dart`, `runs_page.dart`,
  `home_page.dart`, `product_detail_page.dart`, the three `model_*_page.dart`, `defect_list_page.dart`,
  `feature_request_list_page.dart`, `design_primitives.dart`, `run_detail_page.dart`,
  `decision_detail_page.dart`, `needs_you_page.dart` and `create_defect_page.dart` were **read only**.
- `.decisions/**` and `docs/adr/**` **untouched**.
- Working tree otherwise unchanged from before this lane: 48 modified QA baseline PNGs under
  `apps/control_plane/test/failures/`, one `melos_shipit_platform.iml` modification, and untracked
  scratch SQL/archive files. **Nothing committed, nothing pushed.**

---

## 9. Validation results

| check | status | note |
|---|---|---|
| **liveness probe — minimal `execute_code` returning one scalar** | **FAIL** | call 1 socket close; call 2 heartbeat dormancy 129s |
| `penpot_high_level_overview` / `penpot_api_info` / `penpot_export_shape` | **never called** | r2 finding applied — the overview is not a health check; a dead `execute_code` cannot act on documentation |
| **total Penpot calls** | **2** | both the same one-scalar probe; neither touched a board or layer |
| **stop discipline** | **pass** | first heartbeat error → no retry. The one retry (call 2) preceded any heartbeat observation and had zero mutations in flight |
| **any board or layer read** | **NOT RUN** | the probe never returned; no `findShapeById` ever executed |
| **24 copy proposals applied** | **NOT RUN — 0 of 24** | transport |
| post-apply settled `textBounds` re-reads | **NOT RUN** | nothing applied; **none invented** |
| layers that wrapped | **N/A** | no layer written, so no layer can have wrapped. **Not a fit verdict** |
| three flagged rows post-apply | **NOT RUN** | §3 |
| `R Submit Sub` option (a) applied | **NOT RUN** | decision intact; write blocked; **no `resize()` issued** |
| **52 footer deletions** | **NOT RUN — 0 of 52** | transport |
| **`Disclose` still at 120 (116 + 4)** | **NOT_RUN this round** | nothing deleted, so no damage is possible; the inherited r3 baseline is unchanged but was **not** re-measured. Post-deletion re-read still owed. §7.1 |
| four `SM - Add Product` boards untouched | **pass** | zero mutations issued — certain from the mutation record |
| **build-side footer copy scope re-measured** | **pass** | **12 render sites in 10 files**, §5.1 — **corrected up from r3's 11** |
| 🟢 **build-side census completeness** | **pass — NEW** | all **14** `TechnicalDetails(` call sites enumerated; 9 pass `note:`, 5 already compliant; + 2 `_footerNote` + 1 `_buildFooter`. **Closed in both directions** — §5.2 |
| `note` is optional on `TechnicalDetails` | **pass** | `design_primitives.dart:362, :368` — `final String? note;` |
| `TechnicalDetails` is the footer band | **pass** | `design_primitives.dart:396-421`; `note == null` → `SizedBox.shrink()` |
| sites 3/11/12 confirmed same band, hand-rolled | **pass** | `_buildFooter :375-389`; `_footerNote` in `defect_list_page.dart`, `feature_request_list_page.dart` |
| `:409-411` confirmed out of scope | **pass** | mid-page `bodySmall` prose under `detailTitle`, not `monoMeta`; 3 occurrences of the string, 2 in the footer band |
| 4 custody sites re-verified at `9fd935f` | **pass** | `:481`, `:980`, `:542`, `:1038`; still stale |
| **any Penpot mutation** | **0 issued** | 0 `characters`, 0 `resize()`, 0 `setParentXY`, 0 `remove()`, 0 renames, 0 re-parents |
| **docker / compose** | **NEVER ISSUED** | **no command of any kind**, mutating or read-only. No `info`, no `ps`, no `logs`, no `config`. **This rule was not tested.** |
| dart analyze / tests / build | n/a | no production source written; out of grant |
| commit / push | **NOT RUN** | nothing committed, nothing pushed |
| `.decisions/**`, `docs/adr/**` | **UNTOUCHED** | not read this round, not modified |
| dispatch `prompt.md` on disk | **still absent** | `design-apply-f5-copy/prompt.md` does not exist; dispatch arrived inline. **PROVENANCE NOTE**, carried from r1 |
| `HEAD` drift vs r3 | **none** | `main` still at `9fd935fabbb3ae1890d215ff8852f2393149ccb0`; every line number in §5 verified against it |

### 9.1 🔴 PROCESS FAILURE I must disclose, of a different kind than r3's

r3 overloaded the plugin. **I did not — and the grant still produced nothing.** A one-scalar
`getPages().length` cannot starve a heartbeat, and the socket was already closed on the *first* request,
before I had issued anything. **The honest conclusion is that this round falsifies the hypothesis that
call weight was the binding constraint**, and that the remaining constraint is a **human tab-focus
action** — the one thing r3 said "may still be needed" and the one thing no amount of call discipline
can substitute for.

The uncomfortable corollary: **four rounds have now consumed this grant, and three of them were
attributable to a fixable cause that turned out not to be the cause.** A probe that returns a heartbeat
error should be read as *the tab needs focusing*, full stop — not as a prompt to suspect the call.

---

## 10. Durable discoveries (for the Manager to route; this lane persists no knowledge base)

1. **CONTRADICTION — the build-side footer copy is 12 render sites in 10 files, not 11.** r3 §9 reached 12
   in its own arithmetic (9 `note:` + 2 `_footerNote` + `_buildFooter` as "site A") while stating 11 in
   its headline, having filed `_buildFooter` as an appendix rather than counting it. `_buildFooter` is a
   full footer-band render site — `ContentRule()` + `SizedBox(13)` + `monoMeta` copy, byte-identical to
   the 100-char `Footer` string on 36 boards — so it counts. **The implementer grant must cover 12.**
2. **🟢 DESIGN_DISCOVERY — the build-side census can be CLOSED, not merely sampled, and this round is the
   first to close it.** Enumerating **every** `TechnicalDetails(` call site (14) and classifying each by
   whether it passes `note:` yields 9 non-compliant + 5 already-compliant. Combined with the 2
   `_footerNote` bands and 1 `_buildFooter` band, **every carrier in `apps/control_plane/lib` is now
   accounted for**, so no further site can hide a `note:` argument. *(`create_defect_page.dart:645` is a
   comment, not a call site.)* **Generalisable: a sweep that runs only one query cannot distinguish
   "that is all" from "that is what I looked at"; enumerate all call sites of the carrier, then classify.**
   This is the direct, generalisable answer to the undercount pattern that has run five times here.
3. **DESIGN_DISCOVERY — `note` is optional on `TechnicalDetails` and `null` already renders the intended
   footer.** `design_primitives.dart:362, :368, :401-410`: `final String? note;` and
   `widget.note == null ? const SizedBox.shrink()`. Five shipped call sites already pass no `note:` and
   already render correctly — **they are the working proof that removing the other nine is safe.** This
   makes "remove the 9 `note:` arguments" not a prediction but an *already-exercised* configuration.
   **Best executable-knowledge candidate: an assertion that no `note:` argument reaches a footer-band
   widget** — it is statically checkable and would have caught all 9 at CI time.
4. **PROJECT_FACT — `TechnicalDetails` is not the only footer-band carrier.** `defect_list_page.dart`
   (const :114, rendered :497) and `feature_request_list_page.dart` (const :84, rendered :215) hand-roll
   `ContentRule()` + `SizedBox(13)` + `Row(_footerNote, …)`, and `add_product_page.dart`'s
   `_buildFooter` (:375, called :314) is a third instance. **A fix scoped to the pattern
   `TechnicalDetails(note:` misses all three.**
5. **PROCESS_FACT (corrects r3) — call weight was not the binding constraint.** A grant engineered
   around r3's diagnosis — no `findShapes`, no subtree traversal, no batching, one shape per call —
   produced **zero calls that reached a shape**: the first request was already a closed socket and the
   second was a heartbeat dormancy. **A scalar `getPages().length` cannot stall a heartbeat, so this
   round falsifies "heavy read" as the proximate cause of the prior rounds' failures.** The remaining
   constraint is a human tab-focus action. **Four rounds consumed; three were attributed to a cause
   that turned out not to be the cause.** Record this so the next lane spends its effort on the probe,
   not on further call-shape anxiety.
6. **PROCESS_FACT — a socket close and a heartbeat dormancy are different failures and the second
   carries no blame.** Call 1 returned `The socket connection was closed unexpectedly` — a transport
   error with no information about tab focus. Retrying a **read-only** probe once, with **zero mutations
   in flight**, was free; had call 2 returned dormancy that was the stop signal and I issued nothing
   further. **With no write in flight there is no recoverable state, so a probe retry has no downside —
   the risk asymmetry that r3 §12.8 identified applies to probes too.**
7. **PROJECT_FACT — the `Disclose` survival baseline must be recorded as a PAIR and re-read after every
   deletion.** 116 exact `Disclose` + 4 `Disclose · single footer row` = 120; the four suffixed layers are
   the left-aligned (`parentX 16`) mobile `SM - Add Product` case on boards that carry no footer copy at
   all — `27ea6536`'s mobile clause already rendering correctly. A strict-equality-only check reads 116
   and falsely reports four missing layers. Carried from r3; **not re-verified this round.**
8. **PROCESS_FACT — the count in a dispatch prompt is still the least reliable input to a design lane.**
   Now falsified on the build side a sixth time: the human's dispatch, r1, r2 and **r3's own headline**
   all said 11, and the measured figure is 12.

---

## 11. Blockers

- **🔴 BLOCKER — the Penpot plugin tab was unreachable from the very first call.** Exact text in §1: one
  socket close, then heartbeat dormancy at 129s. **0 of 24 copy proposals and 0 of 52 footer deletions
  applied.** This is **not** the failure r3 diagnosed: my two calls were one-scalar probes, and the
  socket was already closed on the first. **A human must focus the Penpot tab before the next attempt.**
  Keeping every call to one shape remains correct discipline — it just is not sufficient.
- **🟥 OPEN FINDING (its own finding, not absorbed, not fixed) — `R Submit Sub` pre-existing 2-line /
  10-px box overflow**, both `S · Product Credentials · No key` boards. r3 re-confirmed it from its own
  read (`tbW 342.00`, `tbH 25`, box `352×15`); **not re-measured this round.** Recorded under human
  option (a). **A copy fix cannot discharge a box defect on the same layer.** Option (b) not granted;
  downstream check NOT_RUN.
- **NO post-apply measurement exists for any of the 24 layers**, so no fit verdict is confirmed, no wrap
  check has been performed, and the three flagged rows are still unmeasured. **The 24 predictions stand
  as predictions.**
- **🟢 CORRECTION TO ROUTE — the build-side footer-copy grant is 12 render sites in 10 files, not 11**
  (§5.1), and the census is now **closed** (§5.2). Route as one change, scoped to those 12 and
  **explicitly excluding `add_product_page.dart:409-411`**. Removing the nine `note:` arguments is
  zero-layout-risk and already-exercised (5 shipped call sites pass no `note:`); the two `_footerNote`
  bands and `_buildFooter` need deletion.
- **SEPARATE GRANT — the 4 `add_product_page.dart` custody sites** (`:481`, `:980`, `:542`, `:1038`),
  both mirrored paths, **in the same change as the eyebrow fix** — a fix scoped to the eyebrow alone
  leaves the copy beneath it contradicting it.
- **STILL OWED to the next Penpot lane — the two preconditions are carried, not re-run.** Use r3 §4's 52
  ids and §5.2's 24 ids; do **not** repeat r3 §3. **And the post-deletion re-read of the `Disclose`
  baseline pair (120 / 116) is still NOT_RUN** — nothing has ever been deleted, so it has never been
  checked against a post-deletion state.
- **PROVENANCE NOTE** — `design-apply-f5-copy/prompt.md` does not exist; dispatch arrived inline.
  `BASE_SHA`/`HEAD_SHA` is `9fd935fabbb3ae1890d215ff8852f2393149ccb0`, **unchanged from r3**; every §5
  line number is verified against it.
- **I cannot approve this work.** A lane that applies 76 mutations across 64 boards cannot certify them;
  I applied **none**, so there is nothing for me to certify.

---

## 12. Recommended next action

```
HUMAN: focus the Penpot tab, confirm it stays focused, then re-dispatch design-apply-f5-copy unchanged.
       Nothing needs re-deciding. Nothing needs re-deriving. §9's build-side correction (12, not 11)
       can be routed to the implementer lane NOW — it does not depend on Penpot at all.
```

1. **Focus the Penpot tab first**, and keep it focused. The probe is the whole gate now: one scalar
   call, and if it returns a value the grant runs. Everything else is already prepared.
2. **Keep one shape per call** (`findShapeById`) — correct discipline, but this round shows it is
   *necessary, not sufficient*. Do not spend effort on further call-shape mitigation.
3. **Apply the 24 copy proposals one shape per call**, addressing layers by the exact ids in r3 §5.2.
   Construct the separator `  ·  ` and the em dash `—` from the layer's **own** current `characters`
   (r3 §5.3) so byte-identity is a read-time assertion, and assert the resulting `length` before
   assigning.
4. **After each write, re-read `textBounds` in a SEPARATE call.** `tbH ≤ 20` ⇒ one line; `tbH > 20` ⇒ two.
   **STOP on any unpredicted wrap — a wrap is a decision, not a fix.** Do not resize, shorten or adjust.
5. **Apply `R Submit Sub` as drafted under option (a). Do NOT resize the box.** Re-confirm `tbH` is still
   2 lines and record it; the overflow stays an open finding (§4).
6. **Watch the three flagged rows** — and note `BPM · F V 0` is **IBM Plex *Sans* 12, not Mono**, so the
   0.6 × fontSize monospace law does **not** apply to it. Predicted: `BPM · F V 0` 319.89 in a 358 box;
   `R Sub` 325.08 in 352; `Art Sub` 340.29 in 380.
7. **Delete the 52 `Footer` text layers one per call.** In the same call re-assert `name === 'Footer'`
   (**exact equality — a prefix match catches all 76 `Footer Rule` dividers**), `type === 'text'`,
   `characters.length >= 60`, `px === 236`, `w === 1020`; then `.remove()`. Cover **all three
   y-values**: 862 ×48, **910 ×2**, **926 ×2**.
8. **Verify the survival baseline after the last deletion:** `indexOf('Disclose') >= 0` → **120** AND
   `name === 'Disclose'` → **116**. **If either is lower, you deleted required content — stop and report
   immediately.** This check has never yet been run against a post-deletion state.
9. **Route §5's corrected 12-site build-side scope to the implementer lane**, excluding
   `add_product_page.dart:409-411`.
10. **Independent design review.** A lane that applies 76 mutations cannot certify them.

---

```
RESULT: DESIGN_REVISION_BLOCKED

FEATURE: Add Product rebuild — apply the 24 approved A3-correct copy proposals + delete the page-wide footer copy
BRIEF_ID: design-apply-f5-copy
REVISION_ID: design-apply-f5-copy / r4
REVISION_NUMBER: 4
BRANCH: main
BASE_SHA: 9fd935fabbb3ae1890d215ff8852f2393149ccb0
HEAD_SHA: 9fd935fabbb3ae1890d215ff8852f2393149ccb0

OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r4.md
  - Penpot: the 24 named `characters` layers on the 12 named boards (copy grant - NOT EXERCISED, 0 of 24)
  - Penpot: the 52 layers named exactly `Footer` of type text (footer-delete grant - NOT EXERCISED, 0 of 52)
READ_ONLY_PATHS:
  - every other Penpot layer on all 160 top-level boards
  - the four `SM - Add Product` boards (APPROVED - never edited)
  - apps/control_plane/lib/** (read-only, for the build-side site census only)
  - .decisions/27ea6536-8a4e-4cf1-b24c-cdd3ce5bdab0.yaml
  - docs/adr/0018-per-product-git-credentials.md
  - docs/engineering/dispatch/tasks/design-draft-f5-copy/report.md
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report.md (r1 - preserved unmodified)
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r2.md (r2 - preserved unmodified)
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r3.md (r3 - preserved unmodified)
PROHIBITED_PATHS:
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, docs/adr/**, WORK_STATE.md, LANES.md
  - any Penpot layer other than the 76 named above - in particular Footer Rule, Disclose,
    Disclose · single footer row, and every SM board layer

ARTIFACT_PATHS:
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r4.md

RISK_LEVEL: 2
RISK_RATIONALE: >
  Level 2 (Feature UX Change), unchanged from design-draft-f5-copy r1, and design-apply-f5-copy r2 and
  r3. The work restates user-visible security claims in product copy and removes footer copy that a
  RESOLVED decision (27ea6536) forbids. No architecture, decision, interface or data change: 9417f8bf
  OPTION_C/A3 already settled the substrate, ADR 0018 A2 already recorded it, and 27ea6536 already
  settled the footer - so this is implementation of resolved decisions, not new ones. Not level 3: no
  workflow, navigation or IA change, and nothing destructive - every change is reversible by restoring
  the current strings. Not level 1: the text asserts a security property a reader may rely on, and ADR
  0018 A2 records that a wrong absolute is worse than an absent one, because a trusting reader stops
  looking for the real exposure. The level is unchanged even though zero mutations were issued: it rates
  the granted change, not this round's outcome. This round's own contribution carries its own risk -
  a build-side scope handed to an implementer lane is now WIDER (12 render sites, not 11), so the
  exclusion of add_product_page.dart:409-411 and the fifth already-compliant TechnicalDetails call
  sites must be carried with it.
CHANGELOG: >
  r4 - APPLY ATTEMPT, NOT COMPLETED. 0 of 24 copy proposals and 0 of 52 footer deletions applied, on a
  TOTAL zero with no unknown-state write (no mutation was ever reachable: the probe never returned).
  Two Penpot calls, both the same minimal scalar probe - call 1 socket close, call 2 heartbeat dormancy
  at 129s - then STOP with no retry. Recorded that the Manager's and r3's call-design fix was never
  exercised and could not have been: a scalar getPages().length cannot stall a heartbeat, so this round
  FALSIFIES "heavy read" as the proximate cause of the prior rounds and leaves a human tab-focus action
  as the remaining constraint. Delivered instead, entirely read-only and Penpot-independent: the
  build-side footer-copy scope CORRECTED UP from r3's 11 to 12 render sites in 10 files (r3 reached 12
  in its own arithmetic but filed _buildFooter as an appendix rather than counting it), and the census
  CLOSED rather than sampled for the first time - all 14 TechnicalDetails( call sites enumerated, 9
  passing note: and 5 already compliant (lines: only), which makes removal of the other nine an
  already-exercised configuration rather than a prediction and supplies the best executable-knowledge
  candidate in the work item. Confirmed at HEAD 9fd935f: note is nullable and null already renders
  SizedBox.shrink() in the footer band (design_primitives.dart:362/368/401-410); the two _footerNote
  bands and _buildFooter are the same band hand-rolled, so TechnicalDetails(note: is not the only
  carrier; add_product_page.dart:409-411 is confirmed mid-page bodySmall prose and OUT OF SCOPE with the
  Registering-records string occurring exactly 3 times of which only 2 are footer-band; and the 4
  custody sites at :481/:980/:542/:1038 are still stale. r1, r2 and r3 are preserved unmodified.
  No Docker or Compose command of any kind; no commit; no push.

TRACEABILITY:
  REQUIREMENTS_COVERED:
    - 9417f8bf OPTION_C / A3 - external secret manager; SHIP IT holds a reference, not key bytes
      (inherited from the draft; nothing applied this round)
    - 9417f8bf resolution consequence (2): A2 permanently excluded
    - 9417f8bf resolution consequence (3): G-7 REQUIRED - reference not re-exposed
    - 9417f8bf SCOPE NOTE 2026-10-07: the "never holds key bytes" absolute is STORAGE-scoped; no
      proposal asserts the absolute
    - ADR 0018 :80-85 (Current - custody A3): server-side generation, manager custody, reference-only
    - ADR 0018 :95-103 (Effect on presentation): copy must not claim keychain custody; the public half
      stays surfaced
    - 27ea6536 RESOLVED rationale: "the copy goes everywhere" - footer copy in scope page-wide, all
      three y-values (862/910/926), all 52 boards, NOT the dispatch's narrower "(236, 862)"
    - 27ea6536 resolution outcome: no footer copy on EITHER platform; desktop = divider + right-aligned
      Show technical details; mobile = left-aligned button, no divider - positively confirmed present in
      the shipped build as the 5 already-compliant TechnicalDetails call sites
    - 27ea6536 G-18/G-19 SCOPE NOTE: the boards violate the decision and removing the layer needs a
      design-system-owner board edit - the ownership gap THIS GRANT was meant to close, STILL OPEN
    - 27ea6536 follow_up_action: "TechnicalDetails renders with no note" - located concretely and
      exhaustively: 9 note: arguments to remove, 2 _footerNote bands and 1 _buildFooter band to delete
  REQUIREMENTS_GAPS:
    - ALL 24 board writes and ALL 52 board deletions - blocked on Penpot transport, not on content.
      0 applied, 0 failed, 0 unknown
    - No post-apply settled textBounds re-read exists for any of the 24, so every fit prediction remains
      a prediction and the three flagged rows remain unmeasured
    - The post-deletion `Disclose` survival check (120 = 116 + 4) is STILL NOT_RUN against a
      post-deletion state - nothing has ever been deleted, so it has never been exercised
    - The R Submit Sub box defect remains an open finding; option (b) not granted, downstream check NOT_RUN
    - The 4 add_product_page.dart custody sites AND the corrected 12 build-side footer-band render sites
      are a SEPARATE implementer grant - reported here with line numbers, not fixed
    - G-7 remediation itself (remove referenceName from RepositoryCredentialView) is a 9417f8bf follow-up
      owned by design-agent and OUTSIDE this grant
    - A3 unavailability remediation copy (9417f8bf follow-up, design-agent) - not drafted
    - Pixel/visual diff of any proposal: still not possible - no Penpot diff tooling in this repository
    - The independent design review of the corrected build-side scope has not happened

DESIGN_SYSTEM_COMPLIANCE: UNKNOWN
UX_ACCESSIBILITY_SCORE: UNKNOWN
IMPLEMENTATION_FEASIBILITY: HIGH

DISCOVERIES:
  - CONTRADICTION: the build-side footer copy is 12 render sites in 10 files, not 11 - r3 reached 12 in
    its own arithmetic but filed _buildFooter as an appendix item rather than counting it. The
    implementer grant must cover 12
  - DESIGN_DISCOVERY: the build-side census can be CLOSED, not merely sampled - all 14
    TechnicalDetails( call sites enumerated and classified (9 pass note:, 5 already compliant), plus 2
    _footerNote and 1 _buildFooter. create_defect_page.dart:645 is a comment, not a call site.
    Generalisable: a one-query sweep cannot distinguish "that is all" from "that is what I looked at"
  - DESIGN_DISCOVERY: `note` is optional on TechnicalDetails and null already renders the intended
    footer band (SizedBox.shrink), and 5 shipped call sites already pass no note: - so removing the
    other 9 is an ALREADY-EXERCISED configuration, not a prediction. Best executable-knowledge
    candidate: an assertion that no `note:` reaches a footer-band widget
  - PROJECT_FACT: TechnicalDetails is not the only footer-band carrier - defect_list_page.dart and
    feature_request_list_page.dart hand-roll the band, and add_product_page.dart's _buildFooter is a
    third instance
  - PROCESS_FACT (corrects r3): call weight was NOT the binding constraint - a grant engineered around
    r3's diagnosis produced zero calls that reached a shape, and a scalar getPages().length cannot
    stall a heartbeat. The remaining constraint is a human tab-focus action. Four rounds consumed;
    three were attributed to a cause that turned out not to be the cause
  - PROCESS_FACT: a socket close and a heartbeat dormancy are different failures; with no write in
    flight a read-only probe retry has no downside, so the risk asymmetry applies to probes too
  - PROJECT_FACT: the `Disclose` survival baseline is a PAIR (116 exact + 4 `· single footer row` = 120)
    and must be re-read after every deletion; a strict-equality check reads 116 and falsely reports
    four missing layers. Carried from r3, not re-verified this round
  - PROCESS_FACT: the count in a dispatch prompt is still the least reliable input to a design lane -
    falsified on the build side a sixth time, with r3's own headline undercounting its own finding

KNOWLEDGE_PERSISTED:
  none - this lane writes only its own report and issued zero Penpot mutations; all discoveries are
  reported for the Manager to route under aef-repository-learning authority levels. The strongest
  candidate for automatic persistence is (a) the closed build-side carrier census as an EXECUTABLE
  assertion ("no `note:` argument reaches a footer-band widget", statically checkable, would have
  caught all 9 at CI time), and (b) the `Disclose` name-matcher PAIR finding (PROJECT_FACT, verified in
  r3, and a trap that would cause a future lane to report four missing layers). The 12-vs-11 site
  correction is a PROJECT_FACT but will move when the implementer change lands, and the process
  correction in (5) is a WORKFLOW_IMPROVEMENT requiring independent-review authority - above this lane.
  Nothing was auto-persisted because this lane holds no write grant outside its own report.

BLOCKERS:
  - BLOCKER: the Penpot plugin tab was unreachable from the very first call - one socket close, then
    heartbeat dormancy at 129s. 0 of 24 copy proposals and 0 of 52 footer deletions applied. This is
    NOT r3's failure mode: both my calls were one-scalar probes and the socket was already closed on
    the first request. A human must focus the Penpot tab. One shape per call remains correct
    discipline but is not sufficient
  - OPEN FINDING (its own finding, not absorbed, not fixed): `R Submit Sub` pre-existing 2-line 10-px
    box overflow on both `S - Product Credentials - No key` boards (r3 measured tbW 342.00, tbH 25, box
    352x15; not re-measured this round). Under human option (a). Option (b) not granted; downstream
    check NOT_RUN
  - NO post-apply measurement exists for any of the 24 layers, so no layer's fit verdict is confirmed
    and no wrap check has been performed - the 24 predictions stand as predictions
  - CORRECTION TO ROUTE: the build-side footer-copy grant is 12 render sites in 10 files, not 11, and
    the census is now CLOSED. Route as one change, explicitly EXCLUDING add_product_page.dart:409-411
    (mid-page bodySmall prose, 1 of 3 occurrences of a string whose other 2 are footer-band)
  - SEPARATE GRANT: the 4 add_product_page.dart custody sites (:481, :980, :542, :1038), both mirrored
    paths, in the same change as the eyebrow fix
  - STILL OWED to the next Penpot lane: use r3 §4's 52 ids and §5.2's 24 ids, do NOT repeat r3 §3; and
    run the post-deletion `Disclose` baseline-pair re-read (120 / 116), which has never yet been run
    against a post-deletion state
  - PROVENANCE NOTE: design-apply-f5-copy/prompt.md does not exist; dispatch arrived inline.
    BASE_SHA/HEAD_SHA is 9fd935fabbb3ae1890d215ff8852f2393149ccb0, unchanged from r3, and every
    build-side line number in this report is verified against it
  - NOT APPROVED BY ME: a lane that applies 76 mutations across 64 boards cannot certify them. I applied
    none, so there is nothing for me to certify. READY_FOR_INDEPENDENT_DESIGN_REVIEW is NO - there is
    nothing applied to review

READY_FOR_INDEPENDENT_DESIGN_REVIEW: NO
```
