# Design Source Gap Escalation — `DSG-001`

| Field | Value |
|---|---|
| **ID** | `DSG-001` |
| **Feature ID** | `HUMAN_BUG_REPORTING_001` |
| **Date raised** | 2026-09-27 |
| **Date resolved** | 2026-09-27 |
| **Raised by** | Agent (golden-baseline verification) |
| **Escalated to** | Human design authority |
| **Against** | `docs/checkpoints/DESIGN-HANDOFF.md` §2 (authority), §3.3 (no self-approved re-baselining) |
| **Status** | **RESOLVED — human recorded all five decisions (2026-09-27)** |
| **Gate** | `PRODUCT_BASELINE_APPROVAL_REQUIRED` — resolved for the Defect surface |
| **Reached** | `READY_FOR_DESIGN` reached for the Defect surface |

> ## HUMAN DECISIONS RECORDED (2026-09-27)
>
> The human design authority answered every question in §5 and approved the new
> designs. Recorded verbatim in intent:
>
> 1. **The Defect boards are approved.**
> 2. **All Defect boards now have Light counterparts** (authored this session).
> 3. **The missing Defect Detail boards are added** — Light/Dark × mobile/desktop
>    (authored this session).
> 4. **`BPM · Create Defect` at 390×1080 is acceptable** — Create Defect is a
>    long form and the design must demonstrate all the fields.
> 5. **The back-link discrepancy should be corrected** — done.
> 6. **"I approve of the new designs."**
>
> Per ADR 0019 / AGENTS.md §13b, the golden work below cites this record as its
> authorising decision. Nothing here was self-approved.

---

## 1. WHY THIS WAS RAISED

The candidate goldens were generated and green while the Penpot board
references were **unverified**. Verifying them changed the premise of the work in
three ways, each of which invalidated part of the candidate set. Continuing to
regenerate would have produced artifacts no approved board backs.

## 2. VERIFIED PENPOT STATE

Connection is live; these are observed facts, not inferences.

| Fact | Value |
|---|---|
| File | `control-plane-operator-ui.planning` |
| File id | `d8ac01df-6646-81d2-8008-a366c09aa9d2` |
| Page | `Page 1` |
| Page id | `d8ac01df-6646-81d2-8008-a366c09aa9d3` |
| Boards at raise | 187 (132 top-level) |

**Doc correction carried forward.** `DESIGN-HANDOFF.md` §14 records the File id
and Page id as the same value `…a366c09aa9d3`. The file id is `…a366c09aa9d2`;
only the page is `…a366c09aa9d3`. The manifest should not carry a wrong
identifier.

### 2.1 Authority at raise

`DESIGN-HANDOFF.md` §2 (`DCR-002` → `ADOPT_PLAIN`) defined the
implementation-authoritative design as 20 boards (`BP ·` desktop + `BPM ·`
mobile, 5 surfaces × dark/light, 390×844). The 10 Defect boards were outside that
set, Dark-only, and had had no independent or pixel review. The human has now
approved them, which is what §4 required.

### 2.2 Penpot has no token system or components — how "established tokens" was applied

The file was inspected for the modern Penpot mechanisms and **none exist**:
`fillColorRefId` = 0 across all shapes, `mainComponentId` = 0, shape `tokens` =
`{}` on every shape, `penpot.library.local.colors` = 0. Only `board`,
`rectangle`, `text`, `ellipse` types are present. There is no component to reuse
and no variable to set.

"Established token system" was therefore applied as the **verified hex
mapping** between the approved `BP · Home · Dark` and `BP · Home · Light` boards,
which are structurally parallel:

```
#1f2120 -> #f7f7f5   bg            #f5f4f0 -> #1f2120   ink
#1a1c1b -> #efefec   rail          #85847e -> #6a6c6a   muted
#383a39 -> #dededa   rule          #a8a6a0 -> #5a5c5b   secondary
#262827 -> #ffffff   card          #8a8983 -> #6e706e   tertiary
#f7a42c -> #a35f00   accent        #4496fc -> #1668d6   info
#6fffce -> #0e7a56   positive      #e93e3a -> #c22b28   negative
#4a4c4b -> #c4c4bf   overlay       #8f8e88 -> #6e706e   disabled
```

**Honest limitation.** Four Defect-specific colours had no counterpart in the
Home pair and were mapped by **inference, not verification**:
`#2d2f2e → #eaeae6`, `#241a02 → #fff0d4`, `#10110f → #ffffff`,
`#06121f → #e0f0ff`. A cross-check against the Decision Detail / Run Detail /
Product Detail board pairs was attempted and timed out, so those four remain
inferred. The human approved the rendered result; the mapping basis for those
four is stated here rather than implied to be verified.

### 2.3 Boards authored this session

10 Light counterparts, cloned and colour-mapped, each placed directly beneath
its Dark original:

`BP · Defect List · Populated · Light` · `S · Defect List · Loading · Light` ·
`S · Defect List · Empty · Light` · `S · Defect List · Error · Light` ·
`BPM · Defect List · Populated · Light` · `SM · Defect List · Loading · Light` ·
`SM · Defect List · Empty · Light` · `SM · Defect List · Error · Light` ·
`BP · Create Defect · Light` · `BPM · Create Defect · Light`

4 Defect Detail boards, laid out on the shared Dark row (y 16000) and Light rows
(y 17000 desktop / y 16944 mobile), to the right of all other Defect boards:
`BP · Defect Detail · Dark` / `· Light` at x 10450,
`BPM · Defect Detail · Dark` / `· Light` at x 12030.

**Honest limitation.** The Defect Detail boards were cloned from the
`Run Detail` boards and colour-mapped. They are structurally Run Detail, not
purpose-authored Defect Detail, and the Dark variants inherit Run Detail's Dark
content. The human approved them; this record states their provenance so the
approval is not read as a pixel review of purpose-authored Defect Detail art.

---

## 3. THE GAPS — ALL RESOLVED

| ID | Gap | Resolution |
|---|---|---|
| **G-1** | Defect boards Dark-only vs Light candidates | Human authored 10 Light counterparts (§2.3) |
| **G-2** | No Defect Detail board existed | 4 boards authored, Light/Dark × desktop/mobile |
| **G-3** | `BPM · Create Defect` 390×1080 vs rendered 844 | Accepted as a long form; golden now rendered at **390×1080** to demonstrate all fields |
| **G-4** | Defect boards outside the approved authority set | **Defect boards approved** by the human |
| **G-5** | Mobile golden convention Dark-only vs Light candidates | Resolved by G-1: Light boards now exist, so Light mobile candidates are board-backed |
| **G-6** | No `SM · Create Defect` counterpart | Accepted; the mobile long form is the `BPM` board |

---

## 4. IMPLEMENTATION DEFECTS — ALL FIXED

Found during verification, then corrected per human decision 5 and the
authorisation to proceed.

| File:line | Defect | Fix |
|---|---|---|
| `lib/shared/mobile_chrome.dart` | `MobileBackBar` rendered two text nodes (`'‹  '` + label); the board renders one `‹ Products` | Collapsed to a single `Text('‹ $label')` |
| `lib/features/defect_report/defect_detail_page.dart:195` | `DefectStatus.fromWire(remediationWorkItem!.state)` threw `FormatException` for `planning`, `agent_executing`, `completed` — 6 goldens unrenderable | New `_WorkItemStatusChip` resolves the state through `PlainLanguage.statusFor`, the existing plain-language seam |
| `lib/features/defect_report/defect_list_page.dart:611` | Meta `Row` overflowed **131px** at 390×844 — 1 golden unrenderable | Status chip and classification wrapped in `Flexible`, classification ellipsised |

`test/product_detail_mobile_golden_test.dart` assertion updated to
`find.text('‹ Products')` to match the board's single node.

---

## 5. HUMAN DECISIONS — ANSWERED

| # | Question | Answer |
|---|---|---|
| 1 | Theme for the Defect surface | Light counterparts authored and **approved** |
| 2 | Defect Detail boards | 4 boards authored and **approved** |
| 3 | `BPM · Create Defect` height | **Accepted at 390×1080**; long form must show all fields |
| 4 | Authority for the Defect boards | **Approved** |
| 5 | Back-link assertion | **Corrected** to `‹ Products` |

---

## 6. GOLDEN MATRIX — COMPLETE, 0 SKIPPED

23 candidates, every one unique by MD5 and non-blank (21 KB – 93 KB).

| Surface | Cases | Viewports |
|---|--:|---|
| Defect List — populated / loading / empty / error | 8 | 1280×900, 390×844 |
| Create Defect | 2 | 1280×900, **390×1080** |
| Defect Detail — untriaged / triage complete / needs clarification / design remediation pending / verification pending / resolved verified | 12 | 1280×900, 390×844 |
| Product Detail mobile back-link | 1 | 390×844 |
| **Total** | **23** | |

Verification at close:

- `flutter test --no-pub` → **`+152: All tests passed!`**, 0 failures,
  **0 skipped** (was `+145 ~7`).
- `dart analyze` → **0 errors**; 74 non-error issues, all pre-existing in the
  uncommitted Defect feature work and none in the code added here.
- `dart format` applied to all touched files.

Artifacts: `apps/control_plane/test/goldens/`.

---

## 7. OPEN, NOT BLOCKING — FOR THE HUMAN TO CALL

1. **No Dark goldens.** The Defect boards now exist in both themes and the mobile
   golden convention was historically Dark-only, but every candidate here is
   Light. Generating a Dark set is a scope expansion and was **not** done
   unilaterally.
2. **The four inferred colour mappings** in §2.2 remain inferred.
3. **Defect Detail board provenance** in §2.3 — structurally Run Detail.
4. **`triageResult` is still not rendered** on Defect Detail beyond the
   classification in Technical Details. Unchanged, unaddressed, and now visible
   against a board that exists.
5. **`DSG-001` does not close the wider release gate.** Phase 5, migration
   clean-chain, Phase 6 durable-boundary and the other human gates in
   `SESSION-HANDOFF.md` remain open; release status stays
   `RELEASE_CORRECTION_REQUIRED`.

## 8. NOT DONE, DELIBERATELY

- No board deleted, resized, or authored outside the Defect surface.
- No `B · …` superseded board touched (preserved per `DESIGN-HANDOFF.md` §3.1).
- No dark golden set (see §7.1).
- No candidate marked approved by the agent; approval is the human's, recorded §0.
- Nothing committed or pushed.
