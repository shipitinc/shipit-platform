# Report r3 — design-apply-f5-copy (**zero mutations issued**; transport failed on the 6th call)

```
RESULT: DESIGN_REVISION_BLOCKED
TASK_ID: design-apply-f5-copy
TASK_TYPE: design-apply
REVISION: r3 (supersedes report.md / r1 and report-r2.md / r2; both are preserved unmodified)
FEATURE: Add Product rebuild — apply the 24 approved A3-correct copy proposals + delete the page-wide footer copy
WORKTREE: /Users/alkebut/air/shipit-platform  (canonical checkout; Penpot is a live shared file)
BRANCH: main
BASE_SHA: 9fd935fabbb3ae1890d215ff8852f2393149ccb0
HEAD_SHA: 9fd935fabbb3ae1890d215ff8852f2393149ccb0
COMMITTED: NO
```

> ## The one line that matters
> **0 of 24 copy proposals applied. 0 of 52 footer layers deleted. 0 of 76 queued mutations touched the
> file.** The tab WAS alive this time — five consecutive plugin calls succeeded, including the two reads
> r1 and r2 both lost — and then a read I wrote **too heavily** timed out and the plugin went silent. I
> stopped on the first heartbeat error's sanctioned single recovery probe, which also failed.
> **Nothing is half-applied, because no write was ever issued.**

**This round is not a repeat of r1 and r2.** Those died on their *first* plugin call. This one got the
full census, the full `Disclose` enumeration, the full 24-layer pre-write inventory — and, as a
side-effect of verifying the build-side sites, **materially expanded the recorded build-side scope from
"3 sites in 1 file" to 11 sites in 10 files.** See §9. That finding is worth more than the 76 mutations
it did not land.

---

## 1. Liveness-probe method and result

**Method: a minimal `penpot_execute_code` call returning one scalar. Not `penpot_high_level_overview`.**

r2 established (§1.2) that the overview is served as static tool documentation and has different liveness
preconditions from `execute_code`, so a green overview can coexist with a dead plugin context. I followed
that finding exactly.

| # | call | method | result |
|---|---|---|---|
| 1 | `return penpotUtils.getPages().length;` | **minimal scalar probe — the health check** | **`1`** — plugin context **ALIVE** |
| 2 | page id + board enumeration | read | **pass** |
| 3 | footer / `Disclose` census | read | **pass** |
| 4 | `Disclose` name histogram | read | **pass** |
| 5 | `Disclose · single footer row` detail + baseline | read | **pass** |
| 6 | 24-layer pre-write inventory (12 boards) | read | **pass** |
| 7 | 24-entry dry-run string plan | read | **MCP timeout** — see §2 |
| 8 | `return penpotUtils.getPages()[0].id;` | **the one sanctioned recovery probe** | **heartbeat failure, 97s** |
| 9 | `findShapeById(...) ? 'AWAKE' : 'GONE'` | — | **heartbeat failure, 168s** |
| 10 | — | — | **STOPPED. No third recovery attempt.** |

`penpot_high_level_overview` was read once, **after** the successful scalar probe, purely as the
documented API precondition. It is **not** used as health evidence anywhere in this report.

**Verdict on the human's premise: CONFIRMED, and then falsified.** The tab was genuinely responsive at
call 1 and stayed responsive for six calls. It was not "focused and dormant". What killed it is §2.

---

## 2. The failure, exact text, and my own contribution to it

| # | call | outcome | exact error text |
|---|---|---|---|
| 1 | call 7 — 24-entry dry-run string plan | **MCP request timeout** | `MCP error -32001: Request timed out` |
| 2 | call 8 — the one recovery probe | **dormancy (97s)** | `The Penpot plugin tab appears to be suspended by the browser (no heartbeat for 97s). Please click/focus the Penpot tab to wake it, then retry.` |
| 3 | call 9 — second probe | **dormancy (168s)** | `The Penpot plugin tab appears to be suspended by the browser (no heartbeat for 168s). Please click/focus the Penpot tab to wake it, then retry.` |

### 2.1 ⚠️ I overloaded the plugin. That is my error, not a tab that was never focused.

Call 7 walked **24 `findShapes(…, board)` traversals** over board subtrees inside one invocation. Each
traversal re-walks a subtree; on a page with 300 boards and 164 root children that is the kind of
synchronous work that starves the plugin's heartbeat. The timeout at call 7 was almost certainly
**self-inflicted**, and the "no heartbeat for 97s" reported by call 8 is plausibly just the elapsed wall
time since call 7 finished or stalled — which is why it grew to 168s at call 9 while nothing else was
happening.

**I record this rather than blame the transport**, because the next lane's fix is in its own call
design, not in the human's tab focus:

- **Do not re-derive what you already measured.** Call 6 already returned the exact **layer id** of every
  one of the 24 targets. The next lane should address them with `penpotUtils.findShapeById(id)` — an
  O(1) lookup — and never repeat a subtree traversal it has already paid for.
- **One board per call is the right rule for writes; it is also the right rule for reads.** I batched
  12 boards into one read at call 6 and it survived; I batched 24 lookups at call 7 and it did not.
- **The heaviest remaining work is 52 deletions and 24 writes — 76 single-shape calls.** At the observed
  rate (six calls before trouble, all of them heavier than a single-shape write), that is comfortably
  inside one tab-focus window if each call stays small.

### 2.2 Stop discipline

Per `If a heartbeat error appears, treat it as a HARD STOP`, and per r1's precedent (*one recovery read
→ dormancy → STOPPED*): **one recovery probe after the first heartbeat error, then stop.** Call 8 was
that probe and it failed; call 9 confirmed it. I did not issue a third.

**The guarded outcome cannot have occurred.** There was no mutation in flight — every one of calls 1–7
was a read — so there is no unknown-state write and nothing to reconcile. A timeout on a read costs time;
a timeout on a write, with a file that has no version history, costs recoverability. Only the first
happened.

---

## 3. Preconditions — both verified by me, from my own calls

### 3.1 Page and board structure

| # | measurement | value | note |
|---|---|---|---|
| 1 | pages | **1** — `Page 1`, `d8ac01df-6646-81d2-8008-a366c09aa9d3` | matches the draft and both prior reports |
| 2 | `page.root.children.length` | **164** | matches |
| 3 | **top-level boards** | **160** | `page.root.children.filter(type === 'board')` |
| 4 | **all boards including nested** | **300** | ⚠️ **140 are nested.** See §11 discovery 1 |

**r1's census is CONFIRMED, not understated.** 52 `Footer` layers, 76 `Footer Rule` rectangles, zero
non-text layers named `Footer`.

### 3.2 Naming-independent positional sweep — the Manager's figure reproduced

Every layer named exactly `Footer` is at `parentX = 236`, `width = 1020`, `parentY ∈ {862, 910, 926}`,
`height ∈ {15, 16}`, `type = text`, `characters.length ∈ {88, 96, 100, 101}`.

| y | count | boards |
|---|---|---|
| **862** | **48** | all `BP` except the 8 below, plus the 8 `S` boards |
| **910** | **2** | `BP · Reports List · Populated · Dark` / `· Light` |
| **926** | **2** | `BP · Create Report · Dark` / `· Light` |

**All three y-values are in scope.** `27ea6536`'s rationale — *"the copy goes everywhere"* — is broader
than the `(236, 862)` coordinate the earlier dispatch used. **52 are in scope, not 44.** The y=910 and
y=926 layers are on taller boards and violate the same clause identically.

### 3.3 Type check — the reason a name-based sweep was safe

`nonTextNamed_Footer: []` — **zero** non-text layers named exactly `Footer`. **76** layers named
`Footer Rule`, **all `rectangle`**. `indexOf('Footer') === 0` matches both and would put **76 dividers**
in a delete set. **Exact-name matching plus `type === 'text'` re-asserted immediately before every
`remove()` is mandatory.**

### 3.4 `Disclose` enumeration — **the survival baseline, now recorded**

| name | count | type | placement |
|---|---|---|---|
| `Disclose` (exact) | **116** | text | desktop / tablet, right-aligned beside the divider |
| `Disclose · single footer row` | **4** | text | **the four `SM - Add Product` boards**, mobile, **left-aligned at `parentX = 16`** |
| **total layers whose name contains `Disclose`** | **120** | | across **120 distinct boards**, exactly one each |

- **`120` is the survival baseline.** After the 52 deletions, `name.indexOf('Disclose') >= 0` must still
  read **120**, and `name === 'Disclose'` must still read **116**.
- ⚠️ **The two numbers are not interchangeable.** A lane that counts `name === 'Disclose'` reads **116**,
  not 120, and would conclude four required layers had vanished when nothing was wrong. The Manager's
  "120" corresponds to a **contains**-match. **Track both.**
- 100 of the 120 are text layers whose `characters` include `Show technical details`.
- **The 4 `Disclose · single footer row` layers are on the four `SM - Add Product` boards and on NO
  footer-copy board** (`onFooterBoard: false` for all four). That is `27ea6536`'s mobile clause —
  *"mobile = left-aligned button, no divider"* — rendered literally: left-aligned at x=16, and the mobile
  board carries **no footer copy at all**. **This is positive confirmation of the decision's outcome on
  the mobile family**, and it is the strongest available evidence that the 52 desktop deletions will
  leave the footer band in the intended shape.

---

## 4. The 52 deletions — complete, verified, **0 executed**

All 52 from my own `findShapes` call, with the board name resolved by walking to the nearest board
ancestor. Every row is `type: text`, `px: 236`, `w: 1020`.

| # | board | boardId | y | len | layerId |
|---|---|---|---|---|---|
| 1 | `BP · Home · Dark` | `f01f5bc4-7105-8034-8008-a4b4d475d6e2` | 862 | 96 | `f01f5bc4-7105-8034-8008-a4b4d476bcfb` |
| 2 | `BP · Home · Light` | `f01f5bc4-7105-8034-8008-a4e25500c0a8` | 862 | 96 | `f01f5bc4-7105-8034-8008-a4e2550167bb` |
| 3 | `BP · All work · Dark` | `f01f5bc4-7105-8034-8008-a4e0d836d595` | 862 | 96 | `f01f5bc4-7105-8034-8008-a4e0d837d52f` |
| 4 | `BP · All work · Light` | `f01f5bc4-7105-8034-8008-a4e257aec05e` | 862 | 96 | `f01f5bc4-7105-8034-8008-a4e257af3aa9` |
| 5 | `BP · Needs You · Dark` | `f01f5bc4-7105-8034-8008-a4b60f32994c` | 862 | **101** | `f01f5bc4-7105-8034-8008-a4b60f3303a3` |
| 6 | `BP · Needs You · Light` | `f01f5bc4-7105-8034-8008-a4e25ec749df` | 862 | **101** | `f01f5bc4-7105-8034-8008-a4e25ec796a0` |
| 7 | `BP · Decision Detail · Dark` | `f01f5bc4-7105-8034-8008-a4b5a50b4d3d` | 862 | 100 | `f01f5bc4-7105-8034-8008-a4b5a50bb88a` |
| 8 | `BP · Decision Detail · Light` | `f01f5bc4-7105-8034-8008-a4e2619f9333` | 862 | 100 | `f01f5bc4-7105-8034-8008-a4e2619f9387` |
| 9 | `BP · Run Detail · Dark` | `f01f5bc4-7105-8034-8008-a4e1a934b185` | 862 | 100 | `f01f5bc4-7105-8034-8008-a4e1a934c61f` |
| 10 | `BP · Report Detail · Dark` | `64fd9cf4-923e-803f-8008-b4919c7e51c5` | 862 | 100 | `64fd9cf4-923e-803f-8008-b4919c7f224d` |
| 11 | `BP · Report Detail · Light` | `64fd9cf4-923e-803f-8008-b4919d0c7a50` | 862 | 100 | `64fd9cf4-923e-803f-8008-b4919d0ca57f` |
| 12 | `BP · Run Detail · Light` | `f01f5bc4-7105-8034-8008-a4e25b5b7146` | 862 | 100 | `f01f5bc4-7105-8034-8008-a4e25b5b719a` |
| 13 | `S · Empty Overview · Light` | `f01f5bc4-7105-8034-8008-a6617216a456` | 862 | 96 | `f01f5bc4-7105-8034-8008-a66178f4af44` |
| 14 | `S · Empty Overview · Dark` | `f01f5bc4-7105-8034-8008-a669348fce30` | 862 | 96 | `f01f5bc4-7105-8034-8008-a66934903bd2` |
| 15 | `BP · Products · Dark` | `b5b63334-c22a-80a6-8008-a922c6ae509b` | 862 | **88** | `b5b63334-c22a-80a6-8008-a922caf693da` |
| 16 | `BP · Products · Light` | `b5b63334-c22a-80a6-8008-a922d0a97a17` | 862 | **88** | `b5b63334-c22a-80a6-8008-a922d5546859` |
| 17 | `BP · Product Detail · Dark` | `b5b63334-c22a-80a6-8008-a92380ad55ee` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9238459f910` |
| 18 | `BP · Product Detail · Light` | `b5b63334-c22a-80a6-8008-a92389f32670` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9238dccf078` |
| 19 | `BP · Add Product · Dark` | `b5b63334-c22a-80a6-8008-a998ffed44a5` | 862 | 100 | `b5b63334-c22a-80a6-8008-a999041263f1` |
| 20 | `BP · Baseline Decision · Dark` | `b5b63334-c22a-80a6-8008-a999572b1904` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9995bcc9bac` |
| 21 | `BP · Pause Product · Dark` | `b5b63334-c22a-80a6-8008-a999d525d6d9` | 862 | 100 | `b5b63334-c22a-80a6-8008-a999da0a0569` |
| 22 | `BP · Offboard Product · Dark` | `b5b63334-c22a-80a6-8008-a999deec4294` | 862 | 100 | `b5b63334-c22a-80a6-8008-a999e444de27` |
| 23 | `BP · Product Detail Paused · Dark` | `b5b63334-c22a-80a6-8008-a99a25e2040a` | 862 | 100 | `b5b63334-c22a-80a6-8008-a99a2a4cc402` |
| 24 | `BP · Product Credentials · Dark` | `b5b63334-c22a-80a6-8008-a9a52a0cf862` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9a52f2f20cf` |
| 25 | `BP · Batch Approval · Dark` | `b5b63334-c22a-80a6-8008-a9a5920263a4` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9a597a4fd8e` |
| 26 | `S · Needs You · Batch · Dark` | `b5b63334-c22a-80a6-8008-a9a5d0f088c6` | 862 | **101** | `b5b63334-c22a-80a6-8008-a9a5d7289249` |
| 27 | `BP · Policy Decision · Dark` | `b5b63334-c22a-80a6-8008-a9a7e93cc183` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9a7eeedcee4` |
| 28 | `BP · Add Product · Light` | `b5b63334-c22a-80a6-8008-a9a8f06e3586` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9a8f2ec0dff` |
| 29 | `BP · Baseline Decision · Light` | `b5b63334-c22a-80a6-8008-a9a90fdd9b7b` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9a9155f7b8c` |
| 30 | `BP · Pause Product · Light` | `b5b63334-c22a-80a6-8008-a9a91afc8af7` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9a92050780d` |
| 31 | `BP · Offboard Product · Light` | `b5b63334-c22a-80a6-8008-a9a925b07c9e` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9a92b93abc2` |
| 32 | `BP · Product Detail Paused · Light` | `b5b63334-c22a-80a6-8008-a9a93141dc85` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9a937999c73` |
| 33 | `BP · Product Credentials · Light` | `b5b63334-c22a-80a6-8008-a9a940ec8db0` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9a947c1f8a6` |
| 34 | `BP · Batch Approval · Light` | `b5b63334-c22a-80a6-8008-a9a951d55179` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9a95a171e96` |
| 35 | `BP · Policy Decision · Light` | `b5b63334-c22a-80a6-8008-a9a96178ae95` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9a968d4e416` |
| 36 | `S · Needs You · Batch · Light` | `b5b63334-c22a-80a6-8008-a9ab2618517a` | 862 | **101** | `b5b63334-c22a-80a6-8008-a9ab2be325fd` |
| 37 | `BP · Promotion Decision · Dark` | `b5b63334-c22a-80a6-8008-a9afaaef7a4b` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9afb36b4502` |
| 38 | `BP · Promotion Decision · Light` | `b5b63334-c22a-80a6-8008-a9afdf94ff1d` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9afeb2b2896` |
| 39 | `BP · Product Detail Onboarding · Dark` | `b5b63334-c22a-80a6-8008-a9b121da8126` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9b12babac56` |
| 40 | `BP · Product Detail Onboarding · Light` | `b5b63334-c22a-80a6-8008-a9b16a0cf863` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9b1722b4795` |
| 41 | `S · Products · Archived · Dark` | `b5b63334-c22a-80a6-8008-a9b76f700313` | 862 | **88** | `b5b63334-c22a-80a6-8008-a9b77ac763a5` |
| 42 | `S · Products · Archived · Light` | `b5b63334-c22a-80a6-8008-a9b788cec89c` | 862 | **88** | `b5b63334-c22a-80a6-8008-a9b794f1be68` |
| 43 | `BP · Rotate Key · Dark` | `b5b63334-c22a-80a6-8008-a9b7dda85056` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9b7e688c3bf` |
| 44 | `BP · Rotate Key · Light` | `b5b63334-c22a-80a6-8008-a9b816eea081` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9b81f3fcce9` |
| 45 | `S · Product Credentials · No key · Dark` | `b5b63334-c22a-80a6-8008-a9b83b3e426c` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9b8442efa9b` |
| 46 | `S · Product Credentials · No key · Light` | `b5b63334-c22a-80a6-8008-a9b851ba5618` | 862 | 100 | `b5b63334-c22a-80a6-8008-a9b85c0c4385` |
| 47 | `BP · Reports List · Populated · Dark` | `23fdf1cf-c3e2-80e6-8008-b0fdbedd5d50` | **910** | 96 | `23fdf1cf-c3e2-80e6-8008-b0fdbedd5dba` |
| 48 | `BP · Reports List · Populated · Light` | `64fd9cf4-923e-803f-8008-b48bd908c3ba` | **910** | 96 | `64fd9cf4-923e-803f-8008-b48bd908c3dc` |
| 49 | `BP · Create Report · Dark` | `9dc7f164-3a3f-805f-8008-b1025ba2fb84` | **926** | 100 | `9dc7f164-3a3f-805f-8008-b1025ba2fbab` |
| 50 | `BP · Create Report · Light` | `64fd9cf4-923e-803f-8008-b48c44a1f8c9` | **926** | 100 | `64fd9cf4-923e-803f-8008-b48c44a1f8e6` |
| 51 | `BP · Request Feature · Dark` | `64fd9cf4-923e-803f-8008-b7df55b54eae` | 862 | 100 | `64fd9cf4-923e-803f-8008-b7df55b54ecb` |
| 52 | `BP · Request Feature · Light` | `64fd9cf4-923e-803f-8008-b7df5ab84477` | 862 | 100 | `64fd9cf4-923e-803f-8008-b7df5ab84494` |

**Family breakdown: `BP · …` ×44, `S · …` ×8, `BPM` ×0, `SM` ×0.** The four-string split reproduces r1
exactly: **100 ch ×36, 101 ch ×4, 96 ch ×8, 88 ch ×4 = 52.**

**One prior contradiction is now CLOSED.** r1 §2 could not complete the per-board positional breakdown and
therefore could not confirm the draft's §8 claim that the 100-char `Footer` sits at `(236, 862)` on both
`S · Product Credentials · No key` boards, and flagged it as an unresolved detail. **My own census settles
it: rows 45 and 46 are `px 236`, `py 862`, `w 1020`, `h 15`, `len 100`. The draft was right; r1's caveat is
resolved, not repeated.**

---

## 5. The 24 copy proposals — pre-write verification complete, **0 applied**

### 5.1 Every precondition for a safe write is now established

| # | check | result |
|---|---|---|
| 1 | all 12 board **ids** verified against their **names** from **my own** enumeration | **`idMatch: true` for 12/12** — the id-substring trap (`S · Add Product · Unknown host · Dark` `…a9a03d9da341` is a substring of `BPM · Add Product · Dark` `…a9ac5f5ad2dc`) is present and avoided |
| 2 | ⚠️ **layout systems on the 12 target boards** | **`flex: false`, `grid: false` on all 12** — ⚠️ **prior lanes never established this.** A `characters` write cannot be overridden or repositioned by a layout system on any of these boards |
| 3 | layer match by **prefix** (`name.split(' · ')[0] === prefix`) | **`matchCount: 1` for all 24** — exactly one candidate per prefix; `Art L1 · Copy key` cannot be missed |
| 4 | `growType` on all 24 targets | **`fixed`** on all 24 — a write cannot silently change the box |
| 5 | **current `characters` byte-identical to the draft's "current" column** | **24/24 match exactly.** No board had drifted since the draft was written |
| 6 | draft's **"now" widths reproduced on my own instrument** | **11/11 identical to the reported rounding** — see §5.2 |

### 5.2 The 24 targets, with every figure measured by me

All values from call 6. `tbW`/`tbH` are `textBounds` **before** any write.

**`BP · Rotate Key` — the coherent three-layer set (6 layers)**

| layer | current string (len) | id | box | px,py | font | `tbW` now | `tbH` | draft's "now" |
|---|---|---|---|---|---|---|---|---|
| `Art Sub` | `Generated here · the private half never leaves the keychain` (59) | `b5b63334-c22a-80a6-8008-a9b7ea0b85de` | 380×18 | 410,496 | Plex Sans 11 | **289.34375** | 14 | 289.34 ✓ |
| `Tech 0` | `GIT_PRODUCT_PR_SHIP_SSH  ·  ed25519  ·  private half written to the keychain, never shown` (89) | `b5b63334-c22a-80a6-8008-a9b7e8f80ed1` | 596×15 | 236,778 | Plex Sans 10 | **418.28125** | 13 | 418.28 ✓ |
| `L Sub` | `A new keypair is generated here. You install the public half, then work resumes.` (80) | `b5b63334-c22a-80a6-8008-a9b7e08c7860` | 596×30 | 236,154 | Plex Sans 11 | **389.40625** | 14 | 389.41 ✓ |

Dark `b5b63334-…-a9b7dda85056` · Light `b5b63334-…-a9b816eea081`, ids `…a9b8223c615c` / `…a9b82130fa17` /
`…a9b819bbdb21` — **identical box, position, font and width on both boards.**

**Body prose (10 layers)**

| boards | layer | current (len) | id | box | font | `tbW` now | `tbH` | draft ✓ |
|---|---|---|---|---|---|---|---|---|
| `BP · Product Credentials` D/L | `L Sub` | `One key, for this product only. The private half never leaves this device.` (74) | `…a9a52baee193` / `…a9a94327b6c6` | 596×30 | Sans 11 | **347.9296875** | 14.5 | 347.93 ✓ |
| `BP · Add Product` D/L, `S · Add Product · Verified` D/L | `Ev Body` | `It clones over SSH. The private half stays in this device's keychain — never shown, logged or stored.` (101) | `…a9990ab5b120`, `…a9a8f38c7ab5`, `…a9a04d7d9092`, `…a9a97eeafae0` | 560×30 | Sans 11 | **487.125** | 14.5 | 487.13 ✓ |
| `S · Product Credentials · No key` D/L | `R Sub` | `Generate a keypair here, then install the public half on the repository.` (72) | `…a9b84131eb01` / `…a9b858a7ecfd` | 352×30 @884,174 | Sans 11 | **340.00** | **14** | 340.00 ✓ |
| `S · Product Credentials · No key` D/L | `R Submit Sub` | `The private half stays on this device — you copy out the public half` (68) | `…a9b843bdd84b` / `…a9b85b8691fb` | **352×15** @884,398 | Mono 10 | **342.00** | **25** | 342.00, tbH 25 ✓ |

**Metadata rows (6 layers) — note the two DIFFERENT fonts**

| boards | layer | current (len) | id | box | font | `tbW` now | draft ✓ |
|---|---|---|---|---|---|---|---|
| `BP · Product Credentials` D/L | `F V 0` | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in this device's keychain` (58) | `…a9a52bce1546` / `…a9a943529817` | 596×18 | **Mono 12** | **417.6015625** | 417.60 ✓ |
| `BPM · Product Credentials` D/L | `F V 0` | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in the keychain` (48) | `…a9ac6c754e7c` / `…a9ad566a30a7` | **358×32** | **Sans 12** | **283.671875** | 283.67 ✓ |
| `BP · Rotate Key` D/L | `Tech 0` | (see above) | | 596×15 | Sans 10 | 418.28125 | ✓ |

⚠️ **`BPM · Product Credentials · F V 0` is IBM Plex SANS 12, not Mono.** Its twin
(`BP · Product Credentials · F V 0`) is Mono 12. **The `0.6 × fontSize` monospace law does not apply to
the BPM row** — the flagged 38.11 px margin is a Sans measurement and must be verified by re-read, not by
arithmetic.

**Step labels (4 layers)**

| boards | layer | current (len) | id | box | font | `tbW` now | draft ✓ |
|---|---|---|---|---|---|---|---|
| `BP · Product Credentials` D/L | `Act What 0` | `Key created on this device` (26) | `…a9a5318317bd` / `…a9a94ae1a7cf` | 420×16 | **Mono 11** | **171.6015625** | 171.60 ✓ |
| `BPM · Product Credentials` D/L | `Ev What 0` | `Key created on this device` (26) | `…a9ac6e09b986` / `…a9ad599b6b9a` | 270×16 | **Sans 11** | **128.84375** | 128.84 ✓ |

### 5.3 The approved strings, verbatim from the draft

| key | string | goes to |
|---|---|---|
| **A** | `It clones over SSH. The private half stays in the secret manager — never shown, logged or stored.` | `Ev Body` ×4 |
| **B** | `One key, for this product only. The private half stays in the secret manager.` | `L Sub` ×2 |
| **C** / **E** | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in the secret manager` | `F V 0` ×2 (`BP`) + ×2 (`BPM`) |
| **D** | `Key generated on the server` | `Act What 0` ×2 + `Ev What 0` ×2 |
| **F** | `A new keypair is generated on the server. You install the public half, then work resumes.` | `L Sub` ×2 |
| **G** | `GIT_PRODUCT_PR_SHIP_SSH  ·  ed25519  ·  private half in the secret manager, never shown` | `Tech 0` ×2 |
| **H** | `Generated on the server · the private half stays in the secret manager` | `Art Sub` ×2 |
| **I** | `The private half stays in the secret manager — you copy out the public half` | `R Submit Sub` ×2 |
| **J** | `Generated on the server — install the public half on the repository.` | `R Sub` ×2 |

**Construction discipline for the next lane.** The separators are `  ·  ` (two ASCII spaces, U+00B7, two
ASCII spaces) and the dash is U+2014 EM DASH. **Derive both at runtime from a string already on the page**
rather than typing them into a source literal — e.g. read the separator out of the layer's own current
`characters`, and the em dash out of `R Submit Sub`'s current `characters` on the same board. That makes
byte-identity a read-time assertion instead of a hope. Assert `result.length` against the draft's count
before assigning.

### 5.4 Post-apply `textBounds` re-reads — **NOT OBTAINED, and I will not manufacture them**

**Zero layers were written. There is no post-apply measurement for any of the 24, and none is invented
anywhere in this report.** The required sequence — write, then a **separate settled** `textBounds`
re-read, then stop on any wrap the draft predicted would not happen — never began.

**No layer wrapped that the draft did not predict, because no layer was touched.** That sentence is a
statement about a file that has not changed, not a fit verdict. The 24 fit predictions remain
**predictions** and r1's models remain the only evidence behind them. The three flagged rows below are
unchanged from r1's §5.5 and r2's §4.5: **not measured.**

---

## 6. The three flagged rows — **NOT measured post-apply; nothing was applied**

| row | draft prediction | this round |
|---|---|---|
| `BPM · Product Credentials · F V 0` | 38.11 px in a **358 px** box; string grows 6 ch; **Sans 12**, not Mono | **not measured — nothing applied** |
| `S · Product Credentials · No key · R Sub` | 26.92 px in 352; 4 ch shorter, so low risk | **not measured — nothing applied** |
| `Art Sub` | 39.71 px in 380 — the row where the OBVIOUS choice (the approved 80-char string, 392.78 px) fails | **not measured — nothing applied** |

**New contributing fact for the third row:** `Art Sub`'s box is **380×18** with `growType: fixed`. If the
70-char `H` variant wraps, it overflows an **18 px** box by ~10 px. Confirmed on my own read: the box is
380 wide, the layer sits at `(410, 496)`, and the current 59-char string renders **289.34 px on one line
(`tbH` 14)**. The slot has room; the decision has already been made; only the measurement is outstanding.

---

## 7. `R Submit Sub` — option (a): decision intact, **NOT applied**, box untouched

**Human decision stands: option (a) — accept the pre-existing overflow unchanged. Apply as drafted. Do
NOT resize the box (`352×15` stays `352×15`).** I do not reopen it.

- Proposal: `The private half stays on this device — you copy out the public half` (68 ch, 408.00 px) →
  **`The private half stays in the secret manager — you copy out the public half`** (75 ch, 450.00 px).
- **Status: NOT APPLIED.** The decision is made; only the write is missing.
- **I issued no `resize()`, no `setParentXY`, no geometry change of any kind.**

### 7.1 🟥 OPEN FINDING — pre-existing, independent of the custody fix, neither absorbed nor fixed

> **`S · Product Credentials · No key · Dark/Light` · `R Submit Sub` · IBM Plex Mono 10 ·
> parentXY (884, 398) · box `352×15`.**
>
> **Re-confirmed from my own read, both boards:** `w 352`, `h 15`, `tbW 342.00`, **`tbH 25`**, `len 68`,
> `growType fixed`. **The layer already renders 2 lines against a 15 px box and already overflows by
> 10 px.** Pre-existing, on both boards, nothing to do with the copy change.
>
> Effective one-line capacity **57 characters** (nominal `352 / 6.000 = 58.67`; the ~6 px gap is an
> unmeasured wrap inset). No A3-correct string fits this slot while preserving the layer's content: the
> approved custody clause alone is 43 ch, the second clause is 28 ch, and the shortest honest join is
> **71 ch**, 14 over capacity. Any fitting string must delete content.
>
> **Measurement caveat, restated because it governs any future verdict:** `tbW 342.00` is the widest
> rendered **LINE** (57 × 6.000), **not** the string width of 408.00. Taking 342 at face value turns a
> 450 px proposal into a false "FITS". **A copy fix cannot discharge a box defect on the same layer.**
> Do not report "no box change needed" without re-checking the current line count.
>
> Option **(b)** (`352×15 → 352×30`, matching the `R Sub` slot directly above it at 352×30) was **never
> granted**. Its downstream check — `R Submit L` at y364 vs `R Submit Sub` at y398 — is still
> **NOT_RUN**. **Not proposed here.** Level 2 DCR outstanding only if the human wants (b).

---

## 8. `SM` boards — untouched, and now **positively** verified

**The four `SM - Add Product` boards are APPROVED and were never edited. Zero Penpot mutations were issued
at all, so this is certain from the mutation record.**

Stronger, and **verified from my own enumeration** — not inherited, which was r2's stated limitation:

| board | id |
|---|---|
| `SM - Add Product - Unknown host - Dark` | `6d055762-a70b-804c-8008-bf65e644269b` |
| `SM - Add Product - Verified - Dark` | `6d055762-a70b-804c-8008-bf65f36b1c9a` |
| `SM - Add Product - Unknown host - Light` | `6d055762-a70b-804c-8008-bf65ff750422` |
| `SM - Add Product - Verified - Light` | `6d055762-a70b-804c-8008-bf660e124738` |

- **Neither of the four appears in the 24-copy target set.** All 12 copy-target boards are `BP · …`,
  `S · …` or `BPM · …` (names verified from my own call, §5.1).
- **None of the four appears in the 52-delete set** — and this is not only an absence: **none of the four
  has a `Footer` layer of any kind.** They carry no footer copy at all, which is `27ea6536`'s mobile
  clause rendering correctly.
- **Each of the four carries exactly one `Disclose · single footer row`** at `parentX = 16` (left-aligned),
  and **none of the four is on a footer-copy board** (§3.4). **They are the protected mobile case the
  decision already got right.**
- 24 other `SM · …` boards also exist. **Zero `SM` boards of any name appear in either target set** — the
  52-delete set is `BP ×44` + `S ×8`, with zero `SM` and zero `BPM`.

---

## 9. 🟥 The build-side footer copy is **11 sites in 10 files**, not 3 in 1

Read-only, verified by me at `HEAD = 9fd935f` on
`apps/control_plane/lib/features/products/add_product_page.dart` (1117 lines) and, for this section,
across the whole of `apps/control_plane/lib`. **A separate implementer lane owns the build. I wrote no
production source.**

### 9.1 What r1 and r2 reported, and what is actually there

r1 reported *"a FIFTH and SIXTH build site"*: `TechnicalDetails(note:)` at `:317-319` and `:926-928`.
r2 confirmed three footer-band sites in one file. **That is true and it is a fraction.** The dispatch
repeated the "THREE places" framing, and it is too narrow — the same failure mode that produced the
"4 vs 52" board undercount, one level down.

`rg -n "note:" apps/control_plane/lib` returns **9 sites in 8 files**, and `rg -n "_footerNote"` returns a
**further 2**, each rendered as its own footer-band band. **Total: 11 footer-copy sites in 10 files.**

| # | file | lines | note / text |
|---|---|---|---|
| 1 | `products/add_product_page.dart` | `:317-319` (call at `:316`) | `Registering records the product. Nothing is governed until you approve a baseline.` |
| 2 | `products/add_product_page.dart` | `:926-928` (call at `:925`) | same string — **mobile twin** |
| 3 | `products/products_page.dart` | `:131-134` | `Every row comes straight from the registry. FACTS counts recorded baseline claims, not files — the registry does not track file counts.` |
| 4 | `home/home_page.dart` | `:129-131` | `Every number on this page comes straight from the system's own records. Nothing here is guessed.` — **the 96-char board sentence** |
| 5 | `runs/runs_page.dart` | `:196-197` | `Every row comes straight from the system's own records.` |
| 6 | `product_detail/product_detail_page.dart` | `:442-444` | `Read from the registry. FACTS counts recorded baseline claims, not files.` |
| 7 | `models/model_executions_page.dart` | `:155-156` | `Executions are read from durable records. Costs are in USD.` |
| 8 | `models/model_stats_page.dart` | `:124-125` | `Stats are aggregated from durable execution records. Costs in USD.` |
| 9 | `models/model_policies_page.dart` | `:123-124` | `Model policies are durable records. Changes require a human decision citation.` |
| 10 | `defect_report/defect_list_page.dart` | const `:114-116`, rendered `:490-501` | `_footerNote` = `Every number on this page comes straight from the system's own records. Nothing here is guessed.` — **byte-for-byte the 96-char board string** |
| 11 | `reports/feature_request_list_page.dart` | const `:84-86`, rendered `:209-219` | `_footerNote` = `Every request here is a draft work item. Nothing on this page has started work on its own.` |

Plus the two already reported:

| # | file | lines | note / text |
|---|---|---|---|
| **A** | `products/add_product_page.dart` | `:380` `const ContentRule()`, `:383-384` copy, inside `_buildFooter` `:375-389`, **called from `:314`** | `Your decision is recorded permanently. The same piece of work then continues — nothing is restarted.` — **byte-identical to the 100-char string on 36 boards** |

**And the one that must NOT be deleted:**

| site | lines | slot | disposition |
|---|---|---|---|
| `products/add_product_page.dart` `:409-411` | 3 | mid-page `_LeftColumn` body prose, directly under the `What you're registering` heading at `:404-407`, **above the form, not in the footer band**, styled `ShipItType.bodySmall` — a *different type* from every footer copy, which is `ShipItType.monoMeta` | **OUT OF SCOPE. DO NOT DELETE.** |

`Registering records the product…` occurs **exactly three times** (`:318`, `:410`, `:927`), confirmed by
`rg`. An implementer handed *"delete the Registering records… note"* and holding a
find-and-delete-the-string approach would plausibly remove **all three**, destroying mid-page explanatory
body copy that `27ea6536` never condemned. **Correct scope: `:317-319` and `:926-928` only** — the two
`TechnicalDetails(note:)` call sites.

### 9.2 Why the fix is mechanical — `TechnicalDetails` IS the footer band

`apps/control_plane/lib/shared/design_primitives.dart:374-421`. The widget builds:

```
Column(
  if (_expanded) … MicroLabel('TECHNICAL DETAILS') … mono lines … ,
  const ContentRule(),                    // :396
  const SizedBox(height: 13),              // :397
  Row(
    Expanded(child: widget.note == null
      ? const SizedBox.shrink()           // :403
      : Text(widget.note!, monoMeta / inkTertiary)),   // :404-409
    InlineLink(label: 'Show technical details' …),      // :411-418
  ),
)
```

**Divider, then copy on the left, then the right-aligned `Show technical details` toggle — which is
precisely the board footer the 52 deletions produce.** Two consequences for the implementer:

1. **`note` is optional and already handles absence.** Passing `note: null` renders
   `SizedBox.shrink()` and leaves the divider and the toggle exactly as `27ea6536` requires. Removing the
   nine `note:` arguments is the whole fix for sites 1–9 — no layout change, no new geometry.
2. **`27ea6536`'s follow-up action said it verbatim:** *"Ensure `_buildFooter` is deleted on desktop … and
   that `TechnicalDetails` renders with no note."* The decision **already prescribed the correct fix**;
   no lane had found the concrete lines. Sites 10 and 11 are a **third structural variant** of the same
   band — a hand-rolled `ContentRule()` + `SizedBox(13)` + `Row(_footerNote, …)` instead of the shared
   widget — so **the implementer must not assume `TechnicalDetails` is the only carrier.** A
   search scoped to `TechnicalDetails(note:` would miss both, and a board-only fix would leave the shipped
   build still rendering forbidden copy on at least two more pages.

### 9.3 The four custody sites (unchanged from r1/r2, re-verified)

| site | lines | current | required |
|---|---|---|---|
| body ×2 | `:480-481` desktop · `:979-980` mobile | `"It clones over SSH. The private half stays in this device's "` + `'keychain — never shown, logged or stored.'` | `…"in the secret manager "` + `'— never shown, logged or stored.'` |
| eyebrow ×2 | `:542` desktop · `:1038` mobile | `'ed25519 · created on this device · the private half stays in the keychain'` | `'ed25519 · generated on the server · the private half stays in the secret manager'` |

Still stale. **A fix scoped to `:542`/`:1038` alone corrects the eyebrow while leaving the copy directly
beneath it contradicting it** — the divergence this work item has already paid for once. Both in the same
change. Reported, not fixed.

---

## 10. Files touched

```
docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r3.md   (this file — sole OWNED_PATH, created)
```

- **r1's `report.md` and r2's `report-r2.md` are preserved unmodified.**
- No production source written. `add_product_page.dart`, `products_page.dart`, `design_primitives.dart`,
  `home_page.dart`, `runs_page.dart`, `product_detail_page.dart`, the three `model_*_page.dart`,
  `defect_list_page.dart` and `feature_request_list_page.dart` were **read only**.
- `.decisions/**` and `docs/adr/**` untouched.
- Working tree otherwise unchanged: 48 modified QA baseline PNGs under
  `apps/control_plane/test/failures/` (binary, pre-existing), one `melos_shipit_platform.iml`
  modification, and untracked scratch SQL/archive files — all present before this lane. Nothing committed,
  nothing pushed.

---

## 11. Validation results

| check | status | note |
|---|---|---|
| **liveness probe — minimal `execute_code` returning one scalar** | **pass** | `getPages().length` → `1`. **Not** `penpot_high_level_overview` — r2 §1.2 finding applied |
| `penpot_high_level_overview` (API precondition) | pass | read **after** the probe; **never** used as health evidence |
| page id | **pass** | `Page 1`, `d8ac01df-6646-81d2-8008-a366c09aa9d3` |
| `page.root.children.length` | **pass** | **164** |
| **top-level boards** | **pass** | **160** |
| all boards incl. nested | **pass** | **300** (140 nested) — ⚠️ §11.1 |
| `Footer`-prefixed layers | **pass** | **128** → 76 `Footer Rule` + 52 `Footer` |
| `Footer` exact-name, by type | **pass** | **52, all `text`**; `nonTextNamed_Footer: []` |
| `Footer Rule` types | **pass** | **76, all `rectangle`** |
| footer x / width uniformity | **pass** | `px 236` and `w 1020` on **all 52**, zero exceptions |
| **y distribution** | **pass** | **862 ×48, 910 ×2, 926 ×2 = 52** |
| distinct string lengths | **pass** | 100×36, 101×4, 96×8, 88×4 = 52 |
| board families | **pass** | `BP ×44`, `S ×8`, **`BPM ×0`**, **`SM ×0`** |
| **`Disclose` enumeration (precondition 2)** | **pass** | **116 exact `Disclose` + 4 `Disclose · single footer row` = 120**, across 120 boards, one each |
| mobile `Disclose · single footer row` placement | **pass** | all 4 on the four `SM - Add Product` boards, `parentX 16`, **none on a footer-copy board** |
| **12 target board ids verified from my own call** | **pass** | `idMatch: true` 12/12; id-substring trap present and avoided |
| **no flex/grid layout on any target board** | **pass** | `flex: false`, `grid: false` 12/12 — **new** |
| prefix matching → exactly one candidate | **pass** | `matchCount: 1` for **all 24** |
| `growType` on all 24 targets | **pass** | `fixed` 24/24 |
| **current strings byte-identical to the draft** | **pass** | **24/24** — no drift since the draft was written |
| **draft's 11 "now" widths reproduced** | **pass** | identical to the reported rounding on all 11 distinct signatures |
| `BPM · F V 0` font | **pass** | **IBM Plex Sans 12**, not Mono — the mono law does not apply to the flagged 38.11 px row |
| r1 §2 "S · No key footer coordinate" contradiction | **pass — CLOSED** | rows 45/46: `px 236`, `py 862`, `w 1020`, `h 15`, `len 100` |
| **24 copy proposals applied** | **NOT RUN — 0 of 24** | blocked on transport |
| post-apply settled `textBounds` re-reads | **NOT RUN** | nothing applied; **none invented** |
| **layers that wrapped or deviated** | **N/A** | **no layer was written, so no layer can have wrapped.** This is not a fit verdict |
| three flagged rows post-apply | **NOT RUN** | §6 |
| `R Submit Sub` option (a) applied | **NOT RUN** | decision intact; write blocked; **no `resize()` issued** |
| `R Submit Sub` pre-existing overflow re-confirmed | **pass** | `tbW 342.00`, **`tbH 25`**, box 352×15 — §7.1 |
| **52 footer deletions** | **NOT RUN — 0 of 52** | blocked on transport |
| **`Disclose` still at 120** | **N/A — nothing deleted** | baseline recorded: 116 exact + 4 `· single footer row` = 120 (§3.4) |
| **four `SM - Add Product` boards untouched** | **pass** | zero mutations issued; ids enumerated; absent from both target sets; carry no `Footer`; each holds one left-aligned `Disclose · single footer row` |
| **build-side footer copy — scope re-measured** | **pass** | **11 sites in 10 files**, §9 — *expanded* from the recorded 3 |
| `TechnicalDetails` footer-band structure confirmed | **pass** | `design_primitives.dart:396-418`; `note: null` → `SizedBox.shrink()` |
| `:409-411` identified as out of scope | **pass** | mid-page `bodySmall` prose, not `monoMeta` footer copy |
| 4 custody sites re-verified at `9fd935f` | **pass** | `:480-481`, `:979-980`, `:542`, `:1038`; still stale |
| **any Penpot mutation** | **NOT RUN BY TRANSPORT** | **0** `characters`, 0 `resize()`, 0 `setParentXY`, 0 `remove()`, 0 renames, 0 re-parents |
| **docker / compose** | **NEVER ISSUED** | **no command of any kind**, mutating or read-only. No `info`, no `ps`, no `logs`, no `config`. This rule was not tested. |
| dart analyze / tests / build | n/a | no production source written; out of grant |
| commit / push | **NOT RUN** | nothing committed, nothing pushed |
| `.decisions/**`, `docs/adr/**` | **UNTOUCHED** | not read this round, not modified |
| dispatch `prompt.md` on disk | **still absent** | `design-apply-f5-copy/prompt.md` does not exist; dispatch arrived inline. **PROVENANCE NOTE**, carried from r1 |

### 11.1 ⚠️ "160 boards" is the **top-level** count. The page has **300**.

`penpotUtils.findShapes(s => s.type === 'board', page.root)` returns **300**, of which **140 are nested**
inside other shapes. `page.root.children.filter(c => c.type === 'board')` returns **160**. r1's "160
boards" and the Manager's precondition both mean top-level. **A lane that asserts "160 boards" from a
recursive `findShapes` will read 300 and may conclude the page changed.** Recorded so the next lane
compares like with like.

### 11.2 🔴 MY OWN PROCESS FAILURE — a heavy read call is what killed the tab

Call 7 performed **24 `findShapes(…, board)` subtree traversals in one invocation** and timed out. That is
a self-inflicted stall, and it is the most likely proximate cause of the two subsequent heartbeat errors.
**The next lane must not repeat it** — call 6 already yielded the exact layer id of every one of the 24
targets, so every subsequent operation is an O(1) `findShapeById(id)`. See §2.1.

---

## 12. Durable discoveries (for the Manager to route; this lane persists no knowledge base)

1. **🔴 CONTRADICTION — the build-side footer copy is 11 sites in 10 files, not 3 in 1.**
   `27ea6536` says *"no footer copy on either platform"* and *"the copy goes everywhere."* Three
   reports, including this dispatch's own prompt, recorded it as three `TechnicalDetails` sites in
   `add_product_page.dart`. `rg -n "note:"` finds **9** `TechnicalDetails(note:)` sites across **8**
   files, plus **2** hand-rolled `_footerNote` footer bands in two more files. **This is the boards-vs-build
   undercount repeating one level down** — r1's own discovery #1 generalised to a component applies to
   *pages*, not just boards: a census on a shared component must sweep by component identity across the
   whole codebase, and `TechnicalDetails(note:` is not the only carrier — `defect_list_page.dart` and
   `feature_request_list_page.dart` re-implement the band by hand. **A fix scoped to the three recorded
   sites leaves the shipped build rendering forbidden footer copy on at least 8 more page instances.**
2. **DESIGN_DISCOVERY — `TechnicalDetails` IS the footer band, and `note` is already optional.**
   `design_primitives.dart:396-418`: `ContentRule` + `SizedBox(13)` + `Row(note, InlineLink('Show
   technical details'))`, and `note == null` renders `SizedBox.shrink()`. So the decision's own follow-up
   (*"`TechnicalDetails` renders with no note"*) is a **parameter removal with zero layout risk**, and the
   post-deletion board footer and the post-fix build footer are the **same structure by construction** —
   boards and build converge without either needing a geometry decision. **Preferable as executable
   knowledge: an assertion that no `note:` argument reaches a footer-band widget.**
3. **PROJECT_FACT — the `Disclose` layer name is not uniform, so its count depends on the matcher.**
   116 layers named `Disclose`; **4** named `Disclose · single footer row`; **120** total containing
   `Disclose`. **A strict-equality count reads 116 and would falsely report four missing layers.** Both
   numbers must be recorded as a baseline pair. The four suffixed ones are exactly the mobile
   `SM - Add Product` boards, left-aligned at `parentX 16` — `27ea6536`'s mobile clause rendering
   correctly, on boards that carry no footer copy at all.
4. **PROJECT_FACT — the page has 160 top-level boards and 300 boards in total** (140 nested).
   `findShapes(type === 'board')` returns 300. "160 boards" is always the top-level count.
5. **CONTRADICTION (resolved) — r1 §2's open question about the `S · Product Credentials · No key` footer
   coordinate is settled.** Both boards carry the 100-char `Footer` **text** layer at `px 236`, `py 862`,
   `w 1020`, `h 15`. The draft §8 claim was correct; r1's "immaterial to the action" caveat is now
   evidence rather than a hedge.
6. **DESIGN_DISCOVERY — the two `F V 0` metadata slots are different fonts.** `BP · Product
   Credentials · F V 0` is **IBM Plex Mono 12** (measured 417.6015625 = 58 × 7.200 exactly, confirming the
   0.6 × fontSize law); `BPM · Product Credentials · F V 0` is **IBM Plex Sans 12** (283.671875). They
   carry different current strings and land on the **same** proposed string. **The monospace law that makes
   a width prediction exact on one is silently inapplicable to the other** — and the inapplicable one is
   the row with the narrowest margin in the whole set (38.11 px in a 358 px box). **Same layer name, same
   slot, different font family: verify font per layer, never per layer-name.**
7. **PROCESS_FACT — a heavy `execute_code` read can stall the plugin heartbeat and be misread as tab
   dormancy.** 24 subtree traversals in one call timed out; the two calls after it reported 97s and 168s
   no-heartbeat, with nothing else running. **The fix is in call design, not in tab focus: address
   shapes by id (`findShapeById`) once their ids are known, and never re-derive a measurement you have
   already paid for.** A heartbeat error after an expensive call is not by itself evidence the human
   failed to focus the tab. **This is the fifth consecutive failure of this grant, and the first one whose
   proximate cause is identifiable and fixable by the agent.**
8. **PROCESS_FACT — confirm that a batched read is safe before batching a write.** One read batching 12
   boards succeeded; one read batching 24 lookups failed; **no write was attempted at all.** The
   risk-asymmetry is the lesson: the cheap way to learn the batch limit is on reads, and this lane learned
   it on a read only because no write had been reached yet. A lane that batches writes to save round-trips
   before it has established its safe read size is optimising in the direction that hurts most.
9. **PROCESS_FACT — pre-write layout and growth checks that no prior lane made.** All 12 target boards
   are `flex: false, grid: false`, so a `characters` write cannot be overridden or repositioned by a
   layout system; all 24 targets are `growType: fixed`, so a write cannot silently change the box; and all
   24 prefixes resolve to **exactly one** candidate each. **These three facts cost one cheap read and
   remove three whole classes of write failure.** They belong in the standard pre-write checklist.
10. **PROCESS_FACT — the count in a dispatch prompt is still the least reliable input to a design lane**,
    now falsified five times (22 vs 24 layers; 8/8/4/4 vs 2/12/6/4; 2 boards vs ≥4 footer boards;
    "at or near (236,862)" deleting 44 of 52; **"the build carries footer copy in THREE places"** vs 11
    in 10 files). The last one is a case where the *human* re-asserted the prior reports' narrower figure
    in the dispatch. **Inherited counts harden into apparent facts the longer they are repeated.**

---

## 13. Blockers

- **🔴 BLOCKER — Penpot plugin heartbeat lost after 6 successful calls.** Exact text in §2. **0 of 24 copy
  proposals and 0 of 52 footer deletions applied.** Root cause this time is plausibly **agent-side call
  weight** (§2.1, §11.2), not a tab that was never focused — the human's premise was **confirmed alive**
  at call 1 and held for six calls. **A human may still need to focus the tab before the next attempt**,
  but the fix that matters most is that the next lane must not repeat the batched-traversal call.
- **🟥 OPEN FINDING (its own finding, not absorbed, not fixed) — `R Submit Sub` pre-existing 2-line /
  10-px box overflow**, both `S · Product Credentials · No key` boards. **Re-confirmed from my own read**
  (`tbW 342.00`, `tbH 25`, box `352×15`). Recorded under the human's option (a). **A copy fix cannot
  discharge a box defect on the same layer.** Option (b) not granted; downstream check NOT_RUN.
- **SEPARATE GRANT — the build-side footer copy, now measured at 11 sites in 10 files** (§9), **excluding**
  `add_product_page.dart:409-411`, which is mid-page body prose that `27ea6536` does not forbid.
- **SEPARATE GRANT — the 4 `add_product_page.dart` custody sites** (§9.3), both mirrored paths, in the
  same change as the eyebrow fix.
- **MUST PRECEDE THE FIRST `remove()` — both preconditions are now DONE and recorded** (§3): the
  naming-independent positional sweep (52, all `Footer`, all text, uniform `px 236`/`w 1020`, y ∈
  {862, 910, 926}) and the `Disclose` enumeration (**116 exact + 4 `Disclose · single footer row` = 120**).
  **The next lane does not need to re-run either**; it needs the §4 ids and the §3.4 baseline pair.
- **NO human decision is outstanding on the copy or the footer.** All 24 proposals are approved and
  option (a) is settled; `27ea6536` is `RESOLVED` and its G-18 gap was an *ownership* gap this grant was
  meant to close. **The grant is unblocked on content and blocked only on transport.**
- **PROVENANCE NOTE** — `design-apply-f5-copy/prompt.md` does not exist; dispatch arrived inline.
  **Also: `BASE_SHA`/`HEAD_SHA` has moved from `7b7efbf` (cited in the draft and both prior reports) to
  `9fd935fabbb3ae1890d215ff8852f2393149ccb0`.** `main` advanced. All §9 line numbers are verified against
  **`9fd935f`** and may shift again.
- **I cannot approve this work.** A lane that applies 76 mutations across 64 boards cannot certify them;
  I applied **none**, so there is nothing for me to certify.

---

## 14. Recommended next action

```
HUMAN: focus the Penpot tab, then re-dispatch design-apply-f5-copy unchanged.
       Nothing needs re-deciding and nothing needs re-measuring.
```

The next lane has everything this one measured. Do **not** repeat §3; use §4's ids and §3.4's baseline pair.

1. **Probe health with a minimal `execute_code` call** (one scalar). **Stop on a heartbeat error after one
   recovery probe**, as r1 established. But: **keep every call small.** No batched subtree traversals —
   every target is addressable by the id recorded in §4 and §5.2.
2. **Apply the 24 copy proposals, one board per call**, addressing layers by the **exact id** in §5.2
   (this subsumes prefix matching — the ambiguity is already resolved). Construct the replacement string by
   reading the separator `  ·  ` and the em dash `—` out of the layer's own current `characters`, and
   assert the resulting `length` against the draft's count **before** assigning. **`findShapeById` beats
   `findShapes`** — it is O(1) and it cannot match the wrong layer.
3. **After each write, re-read `textBounds` in a SEPARATE call** and confirm it did not wrap where the
   draft predicted one line. **STOP on any unpredicted wrap — a wrap is a decision, not a fix.** Do not
   resize, shorten or adjust.
4. **Apply `R Submit Sub` as drafted under option (a). Do NOT resize the box.** Re-confirm `tbH` is still
   2 lines and record it; the overflow stays an open finding (§7.1).
5. **Watch the three flagged rows** (§6) and note that `BPM · F V 0` is **Sans 12**, not Mono — the
   monospace law does not apply there (§12.6).
6. **Delete the 52 `Footer` text layers, one board per call**, using the ids in §4. In the same call,
   re-assert `name === 'Footer'` (never a prefix match — that catches all 76 dividers), `type === 'text'`,
   `characters.length >= 60`, `px === 236`, `w === 1020`; then `.remove()`. **Touch nothing else** —
   `Footer Rule`, `Disclose`, `Disclose · single footer row`, and every `SM` board layer stay.
7. **Verify the survival baseline after the last deletion:** `name.indexOf('Disclose') >= 0` must read
   **120** and `name === 'Disclose'` must read **116**. **If either is lower, you deleted required content
   — stop and report immediately.**
8. **Route §9 to the implementer lane as one change, scoped to the 11 footer-band sites and explicitly
   EXCLUDING `add_product_page.dart:409-411`.** Removing the nine `note:` arguments is zero-layout-risk
   (`note == null` already renders `SizedBox.shrink()`); the two `_footerNote` bands and `_buildFooter`
   need deletion.
9. **Independent design review.** `27ea6536`'s G-18 closes when step 6 lands and is verified.

---

```
RESULT: DESIGN_REVISION_BLOCKED

FEATURE: Add Product rebuild — apply the 24 approved A3-correct copy proposals + delete the page-wide footer copy
BRIEF_ID: design-apply-f5-copy
REVISION_ID: design-apply-f5-copy / r3
REVISION_NUMBER: 3
BRANCH: main
BASE_SHA: 9fd935fabbb3ae1890d215ff8852f2393149ccb0
HEAD_SHA: 9fd935fabbb3ae1890d215ff8852f2393149ccb0

OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r3.md
  - Penpot: the 24 named `characters` layers on the 12 named boards (copy grant - NOT EXERCISED)
  - Penpot: the 52 layers named exactly `Footer` of type text (footer-delete grant - NOT EXERCISED)
READ_ONLY_PATHS:
  - every other Penpot layer on all 160 top-level boards
  - the four `SM - Add Product` boards (APPROVED - never edited)
  - apps/control_plane/lib/** (read-only, for the build-side site census only)
  - .decisions/27ea6536-8a4e-4cf1-b24c-cdd3ce5bdab0.yaml
  - docs/adr/0018-per-product-git-credentials.md
  - docs/engineering/dispatch/tasks/design-draft-f5-copy/report.md
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report.md (r1 - preserved unmodified)
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r2.md (r2 - preserved unmodified)
PROHIBITED_PATHS:
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, docs/adr/**, WORK_STATE.md, LANES.md
  - any Penpot layer other than the 76 named above - in particular Footer Rule, Disclose,
    Disclose · single footer row, and every SM board layer

ARTIFACT_PATHS:
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r3.md

RISK_LEVEL: 2
RISK_RATIONALE: >
  Level 2 (Feature UX Change), unchanged from design-draft-f5-copy, r1 and r2. The work restates
  user-visible security claims in product copy and removes footer copy that a RESOLVED decision
  (27ea6536) forbids. No architecture, decision, interface or data change: 9417f8bf OPTION_C/A3 already
  settled the substrate and ADR 0018 A2 already recorded it, and 27ea6536 already settled the footer, so
  this is implementation of resolved decisions, not new ones. Not level 3: no workflow, navigation or IA
  change, and nothing destructive - every change is reversible by restoring the current strings. Not
  level 1: the text asserts a security property a reader may rely on, and ADR 0018 A2 records that a wrong
  absolute is worse than an absent one because a trusting reader stops looking for the real exposure. The
  risk level is unchanged even though zero mutations were issued: it rates the granted change, not this
  round's outcome. This round's own contribution carries its own risk: an expanded build-side scope
  (11 sites in 10 files) handed to an implementer lane is a wider blast radius than the three sites the
  earlier reports recorded, and the exclusion of add_product_page.dart:409-411 must be carried with it.
CHANGELOG: >
  r3 - APPLY ATTEMPT, NOT COMPLETED. 0 of 24 copy proposals and 0 of 52 footer deletions applied. The tab
  was ALIVE this round: six consecutive plugin calls succeeded, including the two reads r1 and r2 both
  lost, verified by the minimal `execute_code` scalar probe r2 prescribed (not the overview). A read I
  wrote too heavily (24 subtree traversals in one call) then timed out and the heartbeat was lost - so the
  proximate cause is recorded as agent-side call weight rather than unfocused tab. Stopped after the one
  sanctioned recovery probe. Delivered instead, all from my own calls: the full footer census re-verified
  (52 text layers, 52 boards, 4 strings, uniform px 236 / w 1020, y = 862x48 + 910x2 + 926x2, zero
  non-text `Footer`, 76 `Footer Rule` rectangles); the Disclose precondition COMPLETED and recorded as a
  baseline PAIR (116 exact + 4 `Disclose · single footer row` = 120) with the four suffixed ones
  positively identified as the left-aligned mobile `SM - Add Product` case that already renders
  27ea6536 correctly; the full 24-layer pre-write inventory with every layer id, box, font, position and
  textBounds, showing all 24 current strings byte-identical to the draft and all 11 of the draft's
  measured widths reproduced; three new pre-write safety facts (no flex/grid on any target board, all
  targets growType fixed, every prefix resolving to exactly one candidate); r1's open question about the
  `S · No key` footer coordinate CLOSED; and a material EXPANSION of the build-side footer-copy scope from
  the recorded 3 sites in 1 file to 11 sites in 10 files, with `TechnicalDetails` identified as the footer
  band itself and `note: null` shown to be a zero-layout-risk removal - while re-confirming that
  add_product_page.dart:409-411 is mid-page body prose and must not be deleted. r1's report.md and r2's
  report-r2.md are preserved unmodified.

TRACEABILITY:
  REQUIREMENTS_COVERED:
    - 9417f8bf OPTION_C / A3 - external secret manager; SHIP IT holds a reference, not key bytes
      (inherited from the draft; nothing applied this round)
    - 9417f8bf resolution consequence (2): A2 permanently excluded
    - 9417f8bf resolution consequence (3): G-7 REQUIRED - reference not re-exposed
    - 9417f8bf SCOPE NOTE 2026-10-07: the "never holds key bytes" absolute is STORAGE-scoped; no
      proposal asserts the absolute
    - ADR 0018 :80-85 (Current - custody A3): server-side generation, manager custody, reference-only
    - ADR 0018 :95-103 (Effect on presentation): copy must not claim keychain custody; the public
      half stays surfaced
    - 27ea6536 RESOLVED rationale: "the copy goes everywhere" - footer copy in scope page-wide,
      all three y-values (862/910/926), all 52 boards, NOT the dispatch's narrower "(236, 862)"
    - 27ea6536 resolution outcome: no footer copy on EITHER platform; desktop = divider +
      right-aligned Show technical details; mobile = left-aligned button, no divider
    - 27ea6536 G-18/G-19 SCOPE NOTE: the boards violate the decision and removing the layer needs a
      design-system-owner board edit - the ownership gap THIS GRANT was meant to close, STILL OPEN
    - 27ea6536 follow_up_action: "TechnicalDetails renders with no note" - now located concretely:
      9 `note:` arguments across 8 files, plus 2 hand-rolled `_footerNote` bands and `_buildFooter`
  REQUIREMENTS_GAPS:
    - ALL 24 board writes and ALL 52 board deletions - blocked on Penpot transport, not on content
    - No post-apply settled textBounds re-read exists for any of the 24, so every fit prediction remains
      a prediction; the three flagged rows remain unmeasured post-apply
    - The R Submit Sub box defect remains an open finding; option (b) not granted, downstream check NOT_RUN
    - The 4 add_product_page.dart custody sites AND the 11 build-side footer-band sites are a SEPARATE
      implementer grant - reported here with line numbers, not fixed
    - G-7 remediation itself (remove referenceName from RepositoryCredentialView) is a 9417f8bf
      follow-up owned by design-agent and OUTSIDE this grant
    - A3 unavailability remediation copy (9417f8bf follow-up, design-agent) - not drafted
    - Pixel/visual diff of any proposal: still not possible - no Penpot diff tooling in this repository
    - The independent design review of the expanded build-side scope (11 sites) has not happened

DESIGN_SYSTEM_COMPLIANCE: UNKNOWN
UX_ACCESSIBILITY_SCORE: UNKNOWN
IMPLEMENTATION_FEASIBILITY: HIGH

DISCOVERIES:
  - CONTRADICTION: the build-side footer copy is 11 sites in 10 files, not 3 in 1 - `rg -n "note:"` finds
    9 `TechnicalDetails(note:)` sites across 8 files plus 2 hand-rolled `_footerNote` bands in 2 more;
    a fix scoped to the 3 recorded sites leaves the shipped build rendering forbidden copy on >=8 more
    page instances. The boards-vs-build undercount (4 vs 52) repeating one level down
  - DESIGN_DISCOVERY: `TechnicalDetails` IS the footer band (design_primitives.dart:396-418) and `note`
    is already optional - `note == null` renders `SizedBox.shrink()`, so removing the 9 `note:` arguments
    is zero-layout-risk and the post-fix build footer is structurally identical to the post-deletion board
    footer. Best executable-knowledge candidate: an assertion that no `note:` reaches a footer-band widget
  - PROJECT_FACT: the `Disclose` layer name is not uniform - 116 exact `Disclose` + 4
    `Disclose · single footer row` = 120; a strict-equality count reads 116 and would falsely report four
    missing layers. The 4 are the left-aligned (parentX 16) mobile `SM - Add Product` case, on boards
    carrying no footer copy at all - 27ea6536's mobile clause already rendering correctly
  - PROJECT_FACT: the page has 160 TOP-LEVEL boards and 300 boards in total (140 nested);
    findShapes(type==='board') returns 300, so "160 boards" is always the top-level count
  - CONTRADICTION (RESOLVED): r1's open question about the `S - Product Credentials - No key` footer
    coordinate is settled - both boards carry the 100-char Footer text layer at px 236, py 862, w 1020,
    h 15. The draft was right; r1's hedge is now evidence
  - DESIGN_DISCOVERY: the two `F V 0` metadata slots are DIFFERENT FONTS - `BP · Product Credentials`
    is IBM Plex Mono 12 (417.6015625 = 58 x 7.200, confirming the 0.6x fontSize law) while
    `BPM · Product Credentials` is IBM Plex Sans 12 (283.671875). Same layer name, same slot, different
    family, and the inapplicable one is the narrowest-margin row in the set (38.11px in 358px)
  - PROCESS_FACT: a heavy execute_code read can stall the plugin heartbeat and be misread as tab dormancy
    - 24 subtree traversals in one call timed out and the two calls after reported 97s/168s with nothing
    else running. The fix is call design (findShapeById on already-known ids), not tab focus. The FIRST
    failure of this grant whose proximate cause is identifiable and agent-fixable
  - PROCESS_FACT: confirm a batched read is safe before batching a write - 12 boards batched fine, 24
    lookups did not, and no write was reached. The risk-asymmetric lesson
  - PROCESS_FACT: three cheap pre-write checks no prior lane made - no flex/grid on any of the 12 target
    boards (so a write cannot be overridden by a layout system), all 24 targets growType fixed (so a
    write cannot silently change the box), and every prefix resolving to exactly one candidate
  - PROCESS_FACT: the count in a dispatch prompt is the least reliable input to a design lane - falsified
    five times now, the last time with the HUMAN re-asserting the prior reports' narrower "three places"

KNOWLEDGE_PERSISTED:
  none - this lane writes only its own report and issued zero Penpot mutations; all discoveries are
  reported for the Manager to route under aef-repository-learning authority levels. The strongest
  candidates for automatic persistence are (a) the `Disclose` name-matcher finding (PROJECT_FACT, verified
  here, and a trap that would cause a future lane to report four missing layers), and (b) the
  `TechnicalDetails`-is-the-footer-band finding (DESIGN_DISCOVERY, verifiable statically - the assertion
  "no `note:` argument reaches a footer-band widget" is executable knowledge). The 11 build-side sites are
  PROJECT_FACT but will move when the implementer change lands, and the `F V 0` font split is
  DESIGN_DISCOVERY pending the post-apply re-reads. Nothing here was auto-persisted because this lane
  holds no write grant outside its own report.

BLOCKERS:
  - BLOCKER: Penpot plugin heartbeat lost after 6 successful calls - 1 MCP timeout then 97s and 168s
    no-heartbeat. Exact text in section 2. 0 of 24 copy proposals and 0 of 52 footer deletions applied.
    Root cause this round is plausibly AGENT-SIDE (a batched-traversal read that stalled the heartbeat),
    not an unfocused tab - the human's premise was confirmed alive and held for six calls. A human may
    still need to focus the tab, but the next lane must also keep every call small.
  - OPEN FINDING (its own finding, not absorbed, not fixed): `R Submit Sub` pre-existing 2-line 10-px box
    overflow on both `S - Product Credentials - No key` boards, re-confirmed from my own read
    (tbW 342.00, tbH 25, box 352x15). Under human option (a). Option (b) not granted; downstream check
    NOT_RUN.
  - NO post-apply measurement exists for any of the 24 layers, so no layer's fit verdict is confirmed and
    no wrap check has been performed - the 24 predictions stand as predictions.
  - SEPARATE GRANT: 11 build-side footer-band sites in 10 files (9 `TechnicalDetails(note:)` + 2
    `_footerNote` + `_buildFooter`), EXCLUDING add_product_page.dart:409-411 which is mid-page body prose
    and must not be deleted with the other two occurrences of that string.
  - SEPARATE GRANT: the 4 add_product_page.dart custody sites (:480-481, :979-980, :542, :1038), both
    mirrored paths, in the same change as the eyebrow fix.
  - PROVENANCE NOTE: design-apply-f5-copy/prompt.md does not exist; dispatch arrived inline. Also
    BASE_SHA/HEAD_SHA has moved from 7b7efbf (draft, r1, r2) to 9fd935f - main advanced, and all
    add_product_page.dart line numbers here are verified against 9fd935f.
  - NOT APPROVED BY ME: a lane that applies 76 mutations across 64 boards cannot certify them. I applied
    none, so there is nothing for me to certify. READY_FOR_INDEPENDENT_DESIGN_REVIEW is NO - there is
    nothing applied to review.

READY_FOR_INDEPENDENT_DESIGN_REVIEW: NO
```
