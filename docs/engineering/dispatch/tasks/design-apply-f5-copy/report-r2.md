# Report r2 — design-apply-f5-copy (BLOCKED on Penpot dormancy, round 2; **zero mutations issued**)

```
RESULT: DESIGN_REVISION_BLOCKED
TASK_ID: design-apply-f5-copy
TASK_TYPE: design-apply
REVISION: r2 (supersedes report.md / r1; r1 is preserved unmodified at report.md)
FEATURE: Add Product rebuild — apply the 24 approved A3-correct copy proposals + delete the page-wide footer copy
WORKTREE: /Users/alkebut/air/shipit-platform  (canonical checkout; Penpot is a live shared file)
BRANCH: main
BASE_SHA: 7b7efbf7629459676a2781a6871eed472be695af
HEAD_SHA: 7b7efbf7629459676a2781a6871eed472be695af
COMMITTED: NO
```

> ## The one line that matters
> **I issued ZERO Penpot mutations. 0 of 24 copy proposals applied. 0 of 52 footer layers deleted.
> 0 of 76 queued mutations touched the file.** Penpot went dormant again on my *very first* plugin
> call, and again on the single sanctioned recovery read. I stopped at exactly the point r1 stopped.

**The human's premise is falsified by measurement.** This dispatch was issued on the basis that *"the
human has focused the Penpot tab and it is confirmed responsive."* Two consecutive plugin-context
calls returned no-heartbeat errors at **32s** and **39s**. `penpot_high_level_overview` succeeded — but
see §1.2: **that tool does not exercise the plugin heartbeat and is not evidence of plugin health.**
The tab was focused and is nonetheless dormant for `penpot_execute_code`.

---

## 1. BLOCKER — Penpot dormancy, round 2, exact text

### 1.1 The two failures

| # | call | outcome | exact error text |
|---|---|---|---|
| 1 | page-state verification (`getPages` + root-children census) | **dormancy (32s)** | `The Penpot plugin tab appears to be suspended by the browser (no heartbeat for 32s). Please click/focus the Penpot tab to wake it, then retry.` |
| 2 | **one** minimal recovery read (`getPages()` only) | **dormancy (39s)** | `The Penpot plugin tab appears to be suspended by the browser (no heartbeat for 39s). Please click/focus the Penpot tab to wake it, then retry.` |

Sequence, complete and verbatim:

1. `penpot_high_level_overview` read **before any other Penpot tool** — **pass** (required precondition).
2. Page-state verification call → **dormancy #1 (32s)**. No mutation in flight.
3. **One** minimal recovery read → **dormancy #2 (39s)**.
4. **STOPPED.** No third attempt. Per `If a heartbeat error appears, treat it as a HARD STOP`, and per
   r1's own precedent (`One recovery read → dormancy #3. STOPPED.`), which this dispatch explicitly
   endorsed: *"That is exactly what the prior attempt did correctly and you should do the same if it
   recurs."*

**Nothing was left half-applied, and nothing could have been.** Both failures hit **reads**. I never
reached a write path. Zero `characters` assignments, zero `resize()`, zero `setParentXY`, zero
`remove()`, zero board renames or re-parents.

### 1.2 🟥 NEW DISCOVERY — `penpot_high_level_overview` is NOT a plugin-health check

This dispatch's premise — and, I suspect, the human's confidence that the tab was "confirmed
responsive" — rests on the overview tool having answered. **It is not evidence.**

`penpot_high_level_overview` returned its full document in this lane while **both** subsequent
`penpot_execute_code` calls failed on a 32s and a 39s no-heartbeat. The overview is served as static
tool documentation; `execute_code` requires a live plugin heartbeat. **They have different liveness
preconditions, so a green overview can coexist with a dead plugin context.** Anyone treating a
successful overview as "Penpot is awake" will read a dormant tab as healthy — which is the most
likely reason this work item has now failed twice while apparently being healthy.

**Actionable:** probe health with a minimal `execute_code` call returning one scalar, never with the
overview. Recording this so the next dispatch does not re-report "responsive" from the wrong signal.

### 1.3 What this round could not measure

Every item below was **NOT RUN**. None of it is estimated, inferred from r1, or presented as current:

| # | item | status |
|---|---|---|
| 1 | naming-independent positional sweep (x≈236, w≈1020, footer band) | **NOT RUN** — died in failure #1 |
| 2 | `Disclose` / `Show technical details` enumeration on all 52 boards | **NOT RUN** — died in failure #1 |
| 3 | Manager's independent confirmation (52 `Footer` / 76 `Footer Rule` / 164 root children) | **ACCEPTED AS GIVEN, not independently re-verified** |
| 4 | type check `anyNonTextNamed_Footer: []` | **NOT RUN this round** (r1 §3.5 records it as `[]`) |
| 5 | the 24 copy proposals | **NOT RUN — 0 of 24** |
| 6 | post-apply settled `textBounds` re-reads | **NOT RUN** — nothing applied; none invented |
| 7 | the three flagged rows post-apply | **NOT RUN** |
| 8 | `R Submit Sub` under option (a) | **NOT RUN** |
| 9 | the 52 deletions | **NOT RUN — 0 of 52** |
| 10 | positive `SM` board enumeration | **NOT RUN** — see §7 |

**Items 1 and 2 are the two reads that had to precede the first `remove()`. They are exactly the two
that did not complete. Their absence is the reason the deletions must not be inferred to be safe.**
The guard that `27ea6536` requires — "the disclosure survived" — remains **unevidenced**.

---

## 2. `27ea6536` — scope, as inherited and not re-litigated

The grant's scope basis is unchanged from r1 and I do not reopen it: `27ea6536` is `RESOLVED`, its
`rationale` reads *"the copy goes everywhere"*, and its appended G-18/G-19 `SCOPE NOTE` states the
boards violate it and that *"Removing the layer needs a design-system-owner board edit, which no
current lane owns."* That is an **ownership gap, not a re-decision**, and this grant closes it. The
four-string, 52-board scope is correct and remains the right target set. **No human decision is
required on the footer.**

---

## 3. The 52-footer deletion plan (NOT executed — 0 of 52)

Unchanged and ready to execute: one board per call; in the same call, re-assert `type === 'text'`,
exact `name === 'Footer'`, `parentX === 236`, `width === 1020`, `characters.length >= 60`; then
`.remove()`.

**Preconditions that remain UNMET and must be satisfied before the first `remove()`:**

1. The naming-independent positional sweep (§1.3 item 1) — r1's census is **name-bound on `Footer`**
   and may be understated. A delete sweep driven by a possibly-understated census is a delete sweep
   with an unverified denominator.
2. The `Disclose` / `Show technical details` enumeration (§1.3 item 2) — `27ea6536` requires those to
   survive. **A footer sweep that deletes without this recorded is the one outcome that destroys
   required content**, and it is exactly the outcome the previous dispatch was written to prevent.
3. The `anyNonTextNamed_Footer: []` type check, re-run this round.

**Guards that hold, unchanged:** a `Footer Rule` is a `rectangle` and is never a target; prefix
matching (`indexOf('Footer') === 0`) would match both `Footer` and `Footer Rule` and is therefore
forbidden; `type === 'text'` is re-asserted immediately before every `remove()`.

---

## 4. The 24 copy proposals (NOT applied — 0 of 24)

Layer names matched by **PREFIX** (`name.split(' · ')[0]`), so `Art L1 · Copy key` is not missed by
`=== 'Art L1'`. Board ids verified from my **own** `findShapes` call — which I could not make, so the
ids below are r1's, re-transcribed, and are **unverified by me this round**.

### 4.1 `BP · Rotate Key · Dark/Light` — the coherent three-layer set

| layer | proposed | box | r1 predicted | verdict |
|---|---|---|---|---|
| `Art Sub` | `Generated on the server · the private half stays in the secret manager` | 380×18 Sans 11 | 340.29 px, 1 line, clearance **39.71** | FITS |
| `Tech 0` | `GIT_PRODUCT_PR_SHIP_SSH  ·  ed25519  ·  private half in the secret manager, never shown` | 596×15 Sans 10 | 413.47 px, 1 line, clearance 182.53 | FITS |
| `L Sub` | `A new keypair is generated on the server. You install the public half, then work resumes.` | 596×30 Sans 11 | 431.87 px, 1 line, clearance 164.13 | FITS |

### 4.2 Body prose

| boards | layer | proposed | box | clearance |
|---|---|---|---|---|
| `BP · Add Product` D/L, `S · Add Product · Verified` D/L | `Ev Body` | `It clones over SSH. The private half stays in the secret manager — never shown, logged or stored.` | 560×30 | 84.76 (11.89 px narrower than now) |
| `BP · Product Credentials` D/L | `L Sub` | `One key, for this product only. The private half stays in the secret manager.` | 596×30 | 228.81 |
| `BP · Rotate Key` D/L | `L Sub` | `A new keypair is generated on the server. You install the public half, then work resumes.` | 596×30 | 164.13 |
| `S · Product Credentials · No key` D/L | `R Sub` | `Generated on the server — install the public half on the repository.` | 352×30 | **26.92** ⚠️ |
| `S · Product Credentials · No key` D/L | `R Submit Sub` | `The private half stays in the secret manager — you copy out the public half` | 352×15 | **−97.88** ⚠️ §5 |

### 4.3 Metadata rows

| boards | layer | proposed | box | clearance |
|---|---|---|---|---|
| `BP · Product Credentials` D/L | `F V 0` | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in the secret manager` | 596×18 | 207.20 |
| `BPM · Product Credentials` D/L | `F V 0` | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in the secret manager` | **358×32** | **38.11** ⚠️ |
| `BP · Rotate Key` D/L | `Tech 0` | `GIT_PRODUCT_PR_SHIP_SSH  ·  ed25519  ·  private half in the secret manager, never shown` | 596×15 | 182.53 |

### 4.4 Step labels

| boards | layer | proposed | box | clearance |
|---|---|---|---|---|
| `BP · Product Credentials` D/L | `Act What 0` | `Key generated on the server` | 420×16 | 241.80 |
| `BPM · Product Credentials` D/L | `Ev What 0` | `Key generated on the server` | 270×16 | 131.89 |

**Every predicted width in §4 came from r1's models at each layer's own font signature.** I reused
none of r1's numbers to make a new claim; the measurement traps hold unchanged: `textBounds.width`
on a wrapped layer is the widest **line**, not the string width; **cross-size scaling does not work**
(8.922 px worst case); IBM Plex Mono advance is exactly `0.6 × fontSize`; match names by **prefix**.

### 4.5 The three flagged rows — post-apply measurement NOT OBTAINED

| row | predicted | this round |
|---|---|---|
| `BPM · Product Credentials · F V 0` | 38.11 px in a 358 px box, string grows 6 ch | **not measured — nothing applied** |
| `S · Product Credentials · No key · R Sub` | 26.92 px in 352 | **not measured — nothing applied** |
| `Art Sub` | 39.71 px in 380 — the row where the obvious choice fails | **not measured — nothing applied** |

The discipline required — write, then **a separate settled `textBounds` re-read**, then stop on any
unpredicted wrap — is a 24-write / 24-read sequence that never started. **I will not manufacture a
post-apply measurement for a layer I did not write.**

---

## 5. `R Submit Sub` — option (a), NOT applied

**Human decision stands: option (a) — accept the pre-existing overflow. Apply as drafted. Do NOT
resize the box (`352×15` stays `352×15`).** I do not reopen it.

- Proposal, unchanged: `The private half stays on this device — you copy out the public half`
  (68 ch, 408.00 px) → **`The private half stays in the secret manager — you copy out the public
  half`** (75 ch, 450.00 px).
- **Status: NOT APPLIED.** The decision is made; only the write is missing.

### 🟥 OPEN FINDING — still open, still its own finding, neither absorbed nor fixed

> **`S · Product Credentials · No key · Dark/Light` · `R Submit Sub` · IBM Plex Mono 10 ·
> parentXY (884, 398) · box `352×15`.** Renders **2 lines** against a **15 px** box: rendered height
> **25–26 px**, box overflow **10–11 px**. Effective one-line capacity **57 characters** (nominal
> `352 / 6.000 = 58.67`; the ~6 px gap is an unmeasured wrap inset). **Pre-existing on both boards**,
> **independent of the custody fix**, and **no A3-correct string fits this slot while preserving the
> layer's content** — the approved custody clause alone is 43 ch, the second clause is 28 ch, and the
> shortest honest join is **71 ch**, 14 over capacity.
>
> **Measurement caveat, restated because it governs any future verdict:** `textBounds.width` on this
> layer reads **342.00** — the widest rendered **line** (57 × 6.000), **not** the string width of
> 408.00. Taking 342 at face value turns a 450 px proposal into a false "FITS".
> Option **(b)** (`352×15` → `352×30`, matching the `R Sub` slot above it) was **never granted**; its
> downstream check (`R Submit L` y364 vs `R Submit Sub` y398) is still **NOT_RUN**. **Not proposed here.**

**A copy fix cannot discharge a box defect on the same layer.** Do not report "no box change needed"
without re-checking the current line count.

---

## 6. 🟥 Build-side footer copy — verified by me at `7b7efbf`, and it is FOUR strings, not three

**Read-only. This is a separate implementer lane. I wrote no production source.**

`27ea6536`'s outcome is *"no footer copy on **either platform**."* Verified by `rg` against
`7b7efbf7629459676a2781a6871eed472be695af`, file
`apps/control_plane/lib/features/products/add_product_page.dart` (1117 lines):

### 6.1 The THREE footer-band sites — confirmed, and these are what `27ea6536` forbids

| # | site | lines | what it renders | status |
|---|---|---|---|---|
| 1 | `_buildFooter` — own divider + copy | **:380** `const ContentRule()` · **:383-384** copy, inside `_buildFooter` **:375-389**, **called from :314** | `'Your decision is recorded permanently. The same piece of work then continues — nothing is restarted.'` — **byte-identical to the 100-char string on 36 of the 52 boards** | **OUTSTANDING** |
| 2 | desktop `TechnicalDetails(note:)` | **:317-319** | `'Registering records the product. Nothing is governed until you approve a baseline.'` | **OUTSTANDING** |
| 3 | mobile `TechnicalDetails(note:)` | **:926-928** | same string as #2 | **OUTSTANDING** |

`:383-384` being the **same literal as the board string** is what ties build and boards together: they
render one footer copy, and `27ea6536` forbids it in both places.

### 6.2 🟥 A FOURTH occurrence of the #2/#3 string — NOT footer copy, and must NOT be deleted with them

| site | lines | slot | disposition |
|---|---|---|---|
| `_LeftColumn` body prose | **:409-411** | mid-page under the `'What you're registering'` heading (**:404-407**) — **above** the form, **not** in the footer band | **OUT OF SCOPE for `27ea6536`. Do not delete it.** |

`rg -n "Registering records the product"` returns exactly three lines — `:318`, `:410`, `:927`. The
first two prior reports each reported only the two `TechnicalDetails` sites. **`:410` is a third
occurrence of that string in a different slot.** I record it because the failure mode here is
concrete and destructive: an implementer given "delete the `Registering records…` footer note" and
holding a copy-paste-the-string approach would plausibly remove **all three**, deleting **mid-page
explanatory body copy that `27ea6536` never forbade**. The correct scope is **`:317-319` and
`:926-928` only** — the two `TechnicalDetails(note:)` call sites.

### 6.3 The four `add_product_page.dart` custody sites — re-verified by me at `7b7efbf`

`rg -n "keychain|this device|created on"` returns **6 lines in 4 logical sites**, across two
byte-identical duplicated code paths (`_buildKeyPanel` desktop :468-493 / mobile :967-992;
`_buildKeyBox` desktop :495-… / mobile :994-…).

| site | lines | current code | required |
|---|---|---|---|
| body prose ×2 | **:480-481** desktop · **:979-980** mobile | `"It clones over SSH. The private half stays in this device's "` + `'keychain — never shown, logged or stored.'` | `…" in the secret manager — never shown, logged or stored.'` |
| eyebrow ×2 | **:542** desktop · **:1038** mobile | `'ed25519 · created on this device · the private half stays in the keychain'` | `'ed25519 · generated on the server · the private half stays in the secret manager'` |

**A fix scoped to `:542`/`:1038` alone would correct the eyebrow while leaving the copy directly beneath
it contradicting it** — the divergence failure mode this work item has already paid for once. Both are
in the same change. Reported, not fixed.

---

## 7. `SM - Add Product` boards — untouched, but the exclusion is **inherited, not re-verified**

**I edited nothing at all, so no `SM` board was touched — that much is certain.**

The stronger claim (that no `SM` board appears in either target set) rests on r1's evidence, because
**I could not enumerate boards this round**. Stating the limitation rather than borrowing confidence:

- **Copy proposals (24):** all 12 target boards are `BP · …`, `S · …` or `BPM · …`. **No target name
  begins with `SM`.** Exclusion holds by inspection of the target list, which I transcribed in §4.
- **Footer deletions (52):** r1 §3.3 enumerates all 52 as `BP · …` ×44 and `S · …` ×8, with **zero `SM`
  and zero `BPM · Add Product`** — the mobile board carries no footer copy, consistent with
  `27ea6536`. **This enumeration is r1's, unverified by me.**
- The dispatch required me to *"verify none appears in either target set."* **Verifying it from a
  census I could not take is not verification.** I mark it **INHERITED**, not confirmed.

---

## 8. Files touched

```
docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r2.md   (this file — sole OWNED_PATH, created)
```

**r1's `report.md` is preserved unmodified** (40672 bytes), so both attempts' records — including r1's
§1 heartbeat table — survive, as instructed.

Working tree otherwise unchanged: 48 modified QA baseline PNGs under
`apps/control_plane/test/failures/` (binary, pre-existing), one `melos_shipit_platform.iml`
modification, and untracked scratch SQL/archive files — all present before this lane.

---

## 9. Validation results

| check | status | note |
|---|---|---|
| `penpot_high_level_overview` before any other Penpot tool | **pass** | as required — but **not** a health check, §1.2 |
| dispatch prompt read from disk | **FAIL — file absent** | `design-apply-f5-copy/prompt.md` does **not** exist; dispatch arrived inline. **PROVENANCE NOTE**, carried from r1 |
| Penpot plugin health probe (`execute_code`) | **FAIL** | 2 no-heartbeat errors, 32s and 39s |
| page id / board count / 164 root children | **NOT RUN** | accepted as given by the Manager; not independently re-verified |
| **naming-independent positional sweep** | **NOT RUN** | died in failure #1 — must precede the first `remove()` |
| **`Disclose` enumeration** | **NOT RUN** | died in failure #1 — must precede the first `remove()` |
| `anyNonTextNamed_Footer: []` type check | **NOT RUN** | r1 §3.5 records `[]`; not re-run |
| **24 copy proposals applied** | **NOT RUN — 0 of 24** | blocked on transport |
| post-apply settled `textBounds` re-reads | **NOT RUN** | nothing applied; none invented |
| three flagged rows measured post-apply | **NOT RUN** | §4.5 |
| `R Submit Sub` option (a) applied | **NOT RUN** | decision made; write blocked |
| **52 footer deletions** | **NOT RUN — 0 of 52** | blocked on transport |
| `SM` boards touched | **pass** | none edited; exclusion **INHERITED** from r1, §7 |
| 4 custody sites verified at `7b7efbf` | **pass** | §6.3; still stale |
| 3 build-side footer sites verified at `7b7efbf` | **pass** | §6.1 |
| **4th `Registering records…` occurrence identified** | **pass** | §6.2, `:409-411`, **out of scope, do not delete** |
| **any Penpot mutation** | **NOT RUN BY DESIGN** | **0** `characters`, 0 `resize()`, 0 `setParentXY`, 0 `remove()` |
| **docker / compose** | **NEVER ISSUED** | **no command of any kind**, mutating or read-only. No `ps`, no `logs`, no `config`, no `info`. This rule was not tested. |
| dart analyze / tests / build | n/a | no production source written; out of grant |
| commit / push | **NOT RUN** | nothing committed, nothing pushed |
| `.decisions/**`, `docs/adr/**` | **READ ONLY** | not read this round, not modified |

---

## 10. Durable discoveries (for the Manager to route; this lane persists no knowledge base)

1. **RUNTIME_DISCOVERY — `penpot_high_level_overview` succeeding does NOT mean the Penpot plugin
   context is alive.** In this lane the overview returned its full document while two consecutive
   `execute_code` calls failed on 32s and 39s no-heartbeat errors. **The two have different liveness
   preconditions.** Anyone — human or agent — using the overview as evidence that the tab is
   responsive will read a dormant tab as healthy. **This is the most probable reason this work item
   has now failed twice while apparently being "confirmed responsive".** Probe health with a minimal
   `execute_code` call; the overview is not a probe.
2. **PROCESS_FACT — round 2 of a blocked lane must re-run the preconditions, not inherit them, even
   under an explicit instruction not to repeat blockers.** I was told *"do NOT repeat its blockers."*
   Read literally — as a licence to skip the two lost reads and delete from r1's name-bound census —
   that instruction would have removed the `Disclose` guard that exists precisely to protect content
   `27ea6536` requires. **Re-running the guard was not repeating a blocker; it was the grant.**
   The correct reading is *"do not re-litigate the dormancy,"* which is what I did: one probe, one
   recovery, stop.
3. **CONTRADICTION — the build carries `Registering records the product…` in a slot `27ea6536` does
   not forbid.** `:409-411` (desktop `_LeftColumn` body prose, mid-page) is a **third** occurrence of
   the string that the two `TechnicalDetails(note:)` sites carry, and neither prior report listed it.
   Scope for the footer fix is the **two `TechnicalDetails` sites only**; deleting all three removes
   mid-page explanatory copy the decision never condemned.
4. **PROJECT_FACT — confirmed at `7b7efbf`: the build-side footer copy is three sites**
   (`_buildFooter` `:380` + `:383-384`, called from `:314`; desktop `TechnicalDetails(note:)` `:317-319`;
   mobile `:926-928`). Re-confirms r1 §8.1 — a board-only fix leaves the shipped build still rendering
   the forbidden copy.
5. **WORKFLOW_IMPROVEMENT — "confirmed responsive" is not a health assertion that survives contact.**
   A dispatch premise asserted by a human and unverifiable by the agent was falsified on first
   measurement. Dispatch health preconditions for a live external editor should be stated as a
   *probe command and its expected output*, so the next lane can distinguish "I checked" from "I was
   told".

---

## 11. Blockers

- **🔴 BLOCKER — Penpot dormancy, 2 heartbeat failures (32s, 39s). Human action required: focus the
  Penpot tab, then verify with a minimal `execute_code` probe — not the overview (§1.2).**
  **0 of 24 copy proposals and 0 of 52 footer deletions applied.**
- **MUST PRECEDE THE FIRST `remove()` — the two lost reads did not run this round either:** (a) the
  naming-independent positional sweep; (b) the `Disclose` / `Show technical details` enumeration.
  Their survival is a `27ea6536` requirement and **remains unevidenced**. **A footer sweep that
  deletes without (b) recorded is the one outcome that destroys required content.**
- **🟥 OPEN FINDING (its own finding, not absorbed, not fixed) — `R Submit Sub` pre-existing 2-line /
  10-px box overflow**, both `S · Product Credentials · No key` boards, §5, under the human's
  option (a). Option (b) not granted; its downstream check NOT_RUN.
- **SEPARATE GRANT — 3 build-side footer-copy sites** (§6.1) plus **1 out-of-scope occurrence that
  must not be deleted** (§6.2, `:409-411`).
- **SEPARATE GRANT — the 4 `add_product_page.dart` custody sites** (§6.3), both mirrored paths.
- **Level 2 DCR on `R Submit Sub` option (b) remains NOT granted**, downstream check still NOT_RUN.
- **No human decision is outstanding on the copy or the footer.** All 24 proposals are approved and
  option (a) is settled; `27ea6536` is `RESOLVED` and its G-18 gap was an *ownership* gap this grant
  was meant to close. **The grant is unblocked on content and blocked only on transport.**
- **PROVENANCE NOTE** — `design-apply-f5-copy/prompt.md` does not exist; dispatch arrived inline.
- **I cannot approve this work.** A lane that applies 76 mutations across 64 boards cannot certify
  them; I applied **none**, so there is nothing to certify.

---

## 12. Recommended next action

```
HUMAN: focus the Penpot tab, then confirm with a MINIMAL execute_code PROBE
       (e.g. return pages.length) — NOT with penpot_high_level_overview (§1.2).
       Then re-dispatch design-apply-f5-copy unchanged.
```

**No re-decision is needed. The content is fully settled and this round confirmed it is settled:**

1. Probe plugin health with a minimal `execute_code` call before anything else. **Stop on a heartbeat
   error, after one recovery read.**
2. Run the two preconditions: the naming-independent positional sweep, **then** the `Disclose`
   enumeration. **Record both before the first `remove()`.**
3. Re-run `anyNonTextNamed_Footer: []`.
4. Apply the 24 copy proposals, **one board per call**, names matched by **prefix**, with a
   **separate settled `textBounds` re-read** after each write. **STOP on any wrap the draft predicted
   would not happen** — a wrap is a decision, not a fix.
5. Apply `R Submit Sub` as drafted under option (a). **Do not resize the box.**
6. Delete the 52 `Footer` **text** layers, one board per call, re-asserting `type === 'text'` and the
   exact name immediately before each `remove()`. **Touch nothing else** — `Footer Rule`, `Disclose`,
   `Show technical details`, and every `SM` board layer stay.
7. Route the build-side findings (§6) to an implementer lane as one change, scoped to the three
   footer-band sites and **excluding `:409-411`**.
8. Independent design review. `27ea6536`'s G-18 closes when step 6 lands and is verified.

---

```
RESULT: DESIGN_REVISION_BLOCKED

FEATURE: Add Product rebuild — apply the 24 approved A3-correct copy proposals + delete the page-wide footer copy
BRIEF_ID: design-apply-f5-copy
REVISION_ID: design-apply-f5-copy / r2
REVISION_NUMBER: 2
BRANCH: main
BASE_SHA: 7b7efbf7629459676a2781a6871eed472be695af
HEAD_SHA: 7b7efbf7629459676a2781a6871eed472be695af

OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r2.md
  - Penpot: the 24 named `characters` layers on the 12 named boards (copy grant - NOT EXERCISED)
  - Penpot: the 52 layers named exactly `Footer` of type text (footer-delete grant - NOT EXERCISED)
READ_ONLY_PATHS:
  - every other Penpot layer on all 160 boards
  - the four SM - Add Product boards (APPROVED - never edited)
  - apps/control_plane/lib/features/products/add_product_page.dart
  - .decisions/27ea6536-8a4e-4cf1-b24c-cdd3ce5bdab0.yaml
  - docs/adr/0018-per-product-git-credentials.md
  - docs/engineering/dispatch/tasks/design-draft-f5-copy/report.md
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report.md (r1 - preserved unmodified)
PROHIBITED_PATHS:
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, docs/adr/**, WORK_STATE.md, LANES.md
  - any Penpot layer other than the 76 named above - in particular Footer Rule, Disclose,
    Show technical details, and every SM board layer

ARTIFACT_PATHS:
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r2.md

RISK_LEVEL: 2
RISK_RATIONALE: >
  Level 2 (Feature UX Change), unchanged from design-draft-f5-copy and r1. The work restates
  user-visible security claims in product copy and removes footer copy that a RESOLVED decision
  (27ea6536) forbids. No architecture, decision, interface or data change: 9417f8bf OPTION_C/A3
  already settled the substrate and ADR 0018 A2 already recorded it, and 27ea6536 already settled
  the footer, so this is implementation of resolved decisions, not new ones. Not level 3: no
  workflow, navigation or IA change, and nothing destructive - every change is reversible by
  restoring the current strings. Not level 1: the text asserts a security property a reader may rely
  on, and ADR 0018 A2 records that a wrong absolute is worse than an absent one because a trusting
  reader stops looking for the real exposure. The risk level is unchanged even though zero mutations
  were issued: it rates the granted change, not this round's outcome.
CHANGELOG: >
  r2 - APPLY ATTEMPT, NOT COMPLETED. 0 of 24 copy proposals and 0 of 52 footer deletions applied; Penpot
  dormancy blocked the very first plugin call (32s) and the single recovery read (39s). No mutation of
  any kind was issued and none could have been - both failures hit reads. Delivered instead: the
  dismissal of the dispatch's "confirmed responsive" premise, with the new finding that
  penpot_high_level_overview is NOT a plugin-health check (it succeeded while execute_code was
  dead); a full re-verification of the build-side footer copy at 7b7efbf confirming THREE
  footer-band sites; and the discovery of a FOURTH occurrence of the `Registering records the
  product...` string at :409-411 which is mid-page body prose and NOT footer copy, recorded so an
  implementer does not delete it with the other two. The two reads that had to precede the first
  remove() - the naming-independent positional sweep and the Disclose enumeration - did not complete
  again and remain unevidenced. R1's report.md is preserved unmodified.

TRACEABILITY:
  REQUIREMENTS_COVERED:
    - 9417f8bf OPTION_C / A3 - external secret manager; SHIP IT holds a reference, not key bytes
      (inherited; no proposal restated this round)
    - 9417f8bf resolution consequence (2): A2 permanently excluded
    - 9417f8bf resolution consequence (3): G-7 REQUIRED - reference not re-exposed
    - 9417f8bf SCOPE NOTE 2026-10-07: the "never holds key bytes" absolute is STORAGE-scoped; no
      proposal asserts the absolute
    - ADR 0018 :80-85 (Current - custody A3): server-side generation, manager custody, reference-only
    - ADR 0018 :95-103 (Effect on presentation): copy must not claim keychain custody; the public
      half stays surfaced
    - 27ea6536 RESOLVED rationale: "the copy goes everywhere" - footer copy removed page-wide
    - 27ea6536 resolution outcome: no footer copy on EITHER platform; desktop = divider +
      right-aligned Show technical details; mobile = left-aligned button, no divider
    - 27ea6536 G-18/G-19 SCOPE NOTE: the boards violate the decision; removing the layer needs a
      design-system-owner board edit - the ownership gap THIS GRANT was meant to close, still open
    - 27ea6536 follow_up_action: TechnicalDetails renders with no note - reported to the implementer
      lane with concrete lines, not fixed here
  REQUIREMENTS_GAPS:
    - ALL 24 board writes and ALL 52 board deletions - blocked on Penpot transport, not on content
    - BOTH preconditions to the first remove() - naming-independent positional sweep and Disclose
      enumeration - NOT RUN this round; the Disclose survival required by 27ea6536 remains unevidenced
    - The type check anyNonTextNamed_Footer: [] was not re-run this round
    - The SM exclusion is INHERITED from r1's census, not re-verified by me - Penpot unavailable
    - G-7 remediation itself (remove referenceName from RepositoryCredentialView) is a 9417f8bf
      follow-up owned by design-agent and OUTSIDE this grant
    - A3 unavailability remediation copy (9417f8bf follow-up, design-agent) - not drafted
    - The 4 add_product_page.dart custody sites and the 3 build-side footer sites are a SEPARATE
      implementer grant - reported here, not fixed
    - The R Submit Sub box defect remains an open finding; option (b) not granted, downstream check
      NOT_RUN

DESIGN_SYSTEM_COMPLIANCE: UNKNOWN
UX_ACCESSIBILITY_SCORE: UNKNOWN
IMPLEMENTATION_FEASIBILITY: HIGH

DISCOVERIES:
  - RUNTIME_DISCOVERY: penpot_high_level_overview succeeding does NOT mean the plugin context is
    alive - it returned its full document here while two consecutive execute_code calls failed on
    32s and 39s no-heartbeat; the two have different liveness preconditions, so a green overview
    reads a dormant tab as healthy
  - PROCESS_FACT: "do not repeat the prior blockers" must not be read as "skip the prior blockers'
    preconditions" - re-running the Disclose guard was the grant, not a repeat; the instruction meant
    do not re-litigate the dormancy
  - CONTRADICTION: `Registering records the product...` occurs THREE times in the build, not twice -
    :409-411 is mid-page body prose that 27ea6536 does not forbid and must not be deleted with the
    two TechnicalDetails sites
  - PROJECT_FACT: confirmed at 7b7efbf, the build-side footer copy is exactly three sites - _buildFooter
    :380 (ContentRule) + :383-384 (copy) called from :314, and TechnicalDetails(note:) at both
    :317-319 and :926-928
  - WORKFLOW_IMPROVEMENT: an unverifiable "confirmed responsive" premise was falsified on first
    measurement; dispatch preconditions for a live external editor should name a probe command and
    its expected output so "I checked" is distinguishable from "I was told"

KNOWLEDGE_PERSISTED:
  none - this lane writes only its own report and issued zero Penpot mutations; all discoveries are
  reported for the Manager to route under aef-repository-learning authority levels. The strongest
  candidate for automatic persistence is the penpot_high_level_overview liveness finding
  (RUNTIME_DISCOVERY, verified in this lane, product-repository runtime knowledge). The build-side
  string occurrences are PROJECT_FACT and verifiable but were not auto-persisted here because the
  pending implementer change will move them, and this lane persists no knowledge base.

BLOCKERS:
  - BLOCKER: Penpot dormancy, 2 heartbeat failures (32s, 39s), on the first plugin call and the single
    recovery read. 0 of 24 copy proposals and 0 of 52 footer deletions applied. Human action required:
    focus the tab, then verify with a MINIMAL execute_code probe - not with
    penpot_high_level_overview, which is not a health check. All content is settled; no re-decision
    needed.
  - MUST PRECEDE THE FIRST remove(): the naming-independent positional sweep AND the Disclose /
    Show technical details enumeration. Neither ran this round. The Disclose survival 27ea6536
    requires remains unevidenced; a footer sweep that deletes without it recorded is the one outcome
    that destroys required content.
  - OPEN FINDING (its own finding, not absorbed, not fixed): R Submit Sub pre-existing 2-line 10-px
    box overflow on both S - Product Credentials - No key boards, under human option (a).
  - NOT RE-RUN: the anyNonTextNamed_Footer: [] type check; the SM exclusion is INHERITED from r1,
    not independently verified.
  - SEPARATE GRANT: 3 build-side footer-copy sites (:380, :383-384 called from :314; :317-319;
    :926-928), plus :409-411 which is OUT OF SCOPE and must not be deleted; and the 4
    add_product_page.dart custody sites (2 mirrored).
  - PROVENANCE NOTE: design-apply-f5-copy/prompt.md does not exist; dispatch arrived inline.
  - NOT APPROVED BY ME: a lane that applies 76 mutations across 64 boards cannot certify them. I
    applied none, so there is nothing for me to certify.

READY_FOR_INDEPENDENT_DESIGN_REVIEW: NO
```