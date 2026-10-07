# Report — design-draft-f5-copy (24 A3-correct proposals, fit-verified; DRAFT ONLY — nothing written)

```
RESULT: DESIGN_REVISION_COMPLETE
TASK_ID: design-draft-f5-copy
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — draft A3-correct replacement copy for the false custody layers
WORKTREE: /Users/alkebut/air/shipit-platform  (canonical checkout; Penpot is a live shared file)
BRANCH: main
BASE_SHA: 7b7efbf7629459676a2781a6871eed472be695af
HEAD_SHA: 7b7efbf7629459676a2781a6871eed472be695af
COMMITTED: NO
```

**I wrote no board and no source. Zero `characters` assignments, zero `resize()`, zero
`setParentXY`, zero `remove()`.** The only file created is this report. My grant was to draft; this
document is the deliverable.

**Headline for the human, in one line: the approved 80-char string is not a substitute for any of
these 24 layers — it does not even fit the one layer whose slot it was written for.** Each layer
needs copy authored for its own slot type. **23 of 24 proposals fit their box; 1 does not** and is
flagged with its measured overflow in §4. Nothing needs a resize.

---

## 1. My own verified census

| measurement | value | how |
|---|---|---|
| pages | **1** — `Page 1` `d8ac01df-6646-81d2-8008-a366c09aa9d3` | `penpotUtils.getPages()` |
| page root children | **164** (160 boards + 2 rectangles + 2 groups) | my own `findShapes` on `page.root.children` |
| boards | **160**, verified by exact **name** and exact full id from my own read | §1a |
| **false custody layers** | **24** | two needle passes, 160/160 boards |
| boards carrying them | **12** | §1b |
| **distinct false strings** | **10** | §1b |
| distinct **proposed** strings | **9** (C and E converge on one) + 1 already-approved eyebrow for the build | §2 |
| layers matched by needle pass 1 | 202 → **28 distinct strings** | §1c |
| novel strings found by needle pass 2 | 182 → **0** custody claims | §1c |

**Pass 2's taxonomy is wrong.** It is not 8/8/4/4. Measured against the live page:

| slot type | pass 2 said | **measured** | what the slot carries |
|---|---|---|---|
| eyebrow | 8 | **2** | key type + custody, ` · `-delimited |
| body prose | 8 | **12** | a full sentence |
| metadata row | 4 | **6** | keyed on `GIT_PRODUCT_PR_SHIP_SSH` |
| step label | 4 | **4** | short label in a sequence |

And pass 2's layer total is **22, not 24** — see J below.

### 1a. The 12 boards, ids from my own enumeration (never reconstructed)

`BP · Rotate Key · Dark` `b5b63334-c22a-80a6-8008-a9b7dda85056` · `…a9b816eea081` Light ·
`BP · Product Credentials · Dark` `…a9a52a0cf862` · Light `…a9a940ec8db0` ·
`BPM · Product Credentials · Dark` `…a9ac6b9b3962` · Light `…a9ad544bb878` ·
`BP · Add Product · Dark` `…a998ffed44a5` · Light `…a9a8f06e3586` ·
`S · Add Product · Verified · Dark` `…a9a04943d6ae` · Light `…a9a979cd8fbc` ·
`S · Product Credentials · No key · Dark` `…a9b83b3e426c` · Light `…a9b851ba5618`

The id-substring trap is real and present: `…a9a03d9da341` (`S · Add Product · Unknown host · Dark`)
is a substring of `…a9ac5f5ad2dc` (`BPM · Add Product · Dark`). I matched by **exact name** in every
read, never by substring. I prefix-matched layer names throughout (`s.name.split(' · ')[0]`), so
suffixed names such as `Art L1 · Copy key` would not be missed — that fault cost a prior lane its
reference measurement.

### 1b. The 24 — 10 distinct false strings

| # | current string | len | layers | slot |
|---|---|---|---|---|
| A | `It clones over SSH. The private half stays in this device's keychain — never shown, logged or stored.` | 101 | 4 | body |
| B | `One key, for this product only. The private half never leaves this device.` | 74 | 2 | body |
| C | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in this device's keychain` | 58 | 2 | metadata |
| D | `Key created on this device` | 26 | 4 | step |
| E | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in the keychain` | 48 | 2 | metadata |
| F | `A new keypair is generated here. You install the public half, then work resumes.` | 80 | 2 | body |
| G | `GIT_PRODUCT_PR_SHIP_SSH  ·  ed25519  ·  private half written to the keychain, never shown` | 89 | 2 | metadata |
| H | `Generated here · the private half never leaves the keychain` | 59 | 2 | **eyebrow** |
| I | `The private half stays on this device — you copy out the public half` | 68 | 2 | body |
| **J** | `Generate a keypair here, then install the public half on the repository.` | 72 | 2 | body |

**J is the 24th layer and pass 2 missed it.** It asserts device-side generation ("Generate a
keypair **here**") on `S · Product Credentials · No key · Dark/Light`, layer `R Sub`. Pass 2's needle
set had no term for it — `here` alone is not a needle, and `keypair` was not in its list. **Its board
is a two-layer set (J + I) and pass 2 only found half of it.** Same failure mode as its earlier
counts: a needle list that inherits the prior census's blind spots.

### 1c. Needle discipline

Pass 1 (202 hits, 28 distinct strings) used the **semantic** family: `keychain`, `key chain`,
`this device`, `on device`, `local device`, `generated here`, `created here`, `generated on`,
`created on`, `created locally`, `generated locally`, `never leaves`, `held in`, `local secret`,
`secret store`, `stays on`, `private half`, `private key`, `secret manager`, `vault`, `keypair`,
`key pair`, `deploy key`, `kept in`, `stored in`, `written to`. This is what caught **J**.

Pass 2 was a deliberately broader, independent net (`paste`, `pem`, `ssh-add`, `authorize`, `cloud`,
`locally`, `encrypt`, `at rest`, `material`, `nowhere`, `only ever`, `everywhere`, `minted`, `fetched`,
`retrieved`, `asked for`, …): **182 novel strings across 160/160 boards, and not one asserts
device-side key custody or device-side key generation.** The census is closed, not merely sampled.

Every one of the 28 pass-1 strings was classified **individually**, not by pattern. Classified noise
includes three needle false positives worth recording: `Rollback to v2.13.2 stays one action away`
matched only because `stays on` is a substring of `stays one`. Also confirmed **true and
unaffected**: `Signed in on this device` (×76), `Saved as you, on this device` (×34),
`you · on this device` (×4) — session/identity, not custody; `A deploy key is generated for this
product` (×6) and `Generated for this product` (×8) — no location claimed; and the 12 already-correct
80-char eyebrows.

### 1d. G-7 check — the reference is not exposed anywhere

Page-wide scan for `arn:aws|arn:gcp|projects/*/secrets|vault/|secretsmanager|/secrets/*|secret_path|
secret_arn|reference_name|GIT_PRODUCT_PR_*`: **6 hits, all 6 the metadata rows already in this
proposal set (C×2, E×2, G×2).** No ARN, vault path or secret path appears on any board. So the
proposals below preserve the only identifier present — `GIT_PRODUCT_PR_SHIP_SSH`, the product's
credential **variable name** — and **introduce nothing that re-exposes the reference.** G-7 stays
satisfied.

---

## 2. The measurement method, and its error bars

I cannot write `characters`, and Penpot exposes no non-mutating text-measure API (`TextRange` has no
bounds; `Font` exposes no glyph widths). So widths are **predicted** — and every prediction is
reported with the evidence that licenses it.

**A. Single-line baseline first**, per board, per font signature, before any verdict — so a wrap is
never confused with a plausible height. Established baselines: Plex Sans 11 → 14 · Sans 12 → 15 ·
Sans 10 → 13 · Mono 10 → 13 · Mono 11 → 14 · Mono 12 → 16.

**B. Additive per-character width models**, solved by Gauss-Seidel on the ridge-regularised normal
equations, fitted at the **native font size**, pooled page-wide (glyph metrics are a font property,
not a board property):

| model | single-line samples | max abs error | mean abs error |
|---|---|---|---|
| Plex Sans 11 w400 | 868 | **0.672 px** | 0.071 px |
| Plex Sans 12 w400 | 214 | **0.398 px** | 0.117 px |
| Mono 11 w400 | 392 | 0.217 px | 0.044 px |
| Mono 10 w400 | 534 | 0.306 px | 0.027 px |

**C. I tested cross-size scaling and it FAILED.** Predicting fs-13 strings from the fs-11 model
scaled by 13/11 gave **max error 8.922 px** (worst: `Approval flow UX is confusing`, measured 172.19
vs scaled 163.27) — size-dependent kerning is not captured. **So no prediction in this report uses a
scaled model.** Every number is native-size. Had I scaled, I would have understated widths by up to
9px and reported a wrap as a fit.

**D. The monospace slots have an exact law**, derived from three independent layers on three boards:
**advance = 0.6 × fontSize, exactly.** Mono 10 → 6.000 (`Footer` 600.00/100, `Asked` 180.00/30,
`R Sig` 168.00/28, wrapped line 342.00/57); Mono 11 → 6.600 (`Act What 0` 171.60/26,
`Cons To 0` 118.81/18); Mono 12 → 7.200 (`F V 0` 417.60/58). This law independently reproduces the
pooled mono models to **0.02 px** (mono 11: 178.18 vs 178.20) and **0.12 px** (mono 10: 449.88 vs
450.00), which is what lets me resolve the one place they disagreed (§2a).

**E. `textBounds.width` on a WRAPPED layer is the widest rendered LINE, not the string's width.**
This bit me and is the single most important caveat in this report. `R Submit Sub` measures 342.00
wide but its model width is 408. **Taking 342 as the string's width would have turned a 450px
proposal into a false "FITS".** Confirmed exactly: 342.00 = 57 chars × 6.000, and the 57-char prefix
`The private half stays on this device — you copy out the ` models at 341.69 (0.31 px, inside the
model's own 0.306 px error). **No verdict in this report uses a wrapped layer's measured width.**
This also means pass 1's `Art S` figure of 214.53 px is a wrapped-**line** width (its `tbH` 25 is two
lines), not a single-line width — its vertical overlap arithmetic is unaffected, only the horizontal
figure is misread by anyone who takes it as a string width.

### 2a. Where two independent methods disagreed — and the resolution

`BP · Product Credentials · F V 0` (Mono 12, 58 chars, measured **417.60 = 7.200/char exactly**).
Pooled model 369.16 · board-local model 408.57 · **exact law 54 × 7.200 = 388.80**. The exact law
wins, because it is derived from the layer's own measurement and the pooled mono models agree with
the law elsewhere to 0.02/0.12 px. All three **FITS** a 596px box. Verdict insensitive to the choice;
reported as 388.80.

---

## 3. `BP · Rotate Key` — THE PRIORITY, one coherent three-layer set

The board asserts the lie **three times**. Fixing one layer would leave the screen contradicting
itself, so the unit is the board. All three, measured on both boards (Dark and Light **identical on
every figure** — verified independently on each).

| layer | current | proposed |
|---|---|---|
| `Art Sub` (eyebrow, 380×18, Sans 11, @410,496) | `Generated here · the private half never leaves the keychain` | `Generated on the server · the private half stays in the secret manager` |
| `Tech 0` (metadata row, 596×15, Sans 10, @236,778) | `GIT_PRODUCT_PR_SHIP_SSH  ·  ed25519  ·  private half written to the keychain, never shown` | `GIT_PRODUCT_PR_SHIP_SSH  ·  ed25519  ·  private half in the secret manager, never shown` |
| `L Sub` (body prose, 596×30, Sans 11, @236,154) | `A new keypair is generated here. You install the public half, then work resumes.` | `A new keypair is generated on the server. You install the public half, then work resumes.` |

| layer | measured now | proposed | lines | clearance | verdict |
|---|---|---|---|---|---|
| `Art Sub` | 59 ch → 289.34 px, 1 line | 70 ch → **340.29 px** | 1 | **39.71 px** | **FITS** |
| `Tech 0` | 89 ch → 418.28 px, 1 line | 87 ch → **413.47 px** | 1 | 182.53 px | **FITS** |
| `L Sub` | 80 ch → 389.41 px, 1 line | 89 ch → **431.87 px** | 1 | 164.13 px | **FITS** |

After this set the board reads: generated on the server · the private half stays in the secret
manager · `GIT_PRODUCT_PR_SHIP_SSH · ed25519 · private half in the secret manager, never shown` ·
A new keypair is generated on the server. **One story, no contradiction, no device custody, no
device generation.**

⚠️ **The trap, measured rather than asserted.** `Art Sub` is the only eyebrow among the 24, so it is
the one layer the approved 80-char string might plausibly be pasted into. **It does not fit.** The
80-char string measures **392.78 px** at exactly `Art Sub`'s font signature (measured on `Key Meta`,
Sans 11 w400 ls0) — **12.78 px wider than `Art Sub`'s 380 px box, so it would wrap and overflow the
18 px box vertically.** Pass 2's caution was right, and it is stronger than pass 2 stated: the
approved string is not a substitute even for the eyebrow. The 70-char variant above is the fit.

---

## 4. Tables per slot type

Bold = the value that decides the verdict. All boxes are `growType: fixed`. Every row is measured on
its own board; Light/Dark twins were measured separately and are identical on box, position, font and
measured width.

### 4a. EYEBROW — 2 layers, 2 boards

| board | layer | current | proposed | now → proposed | box | lines | clearance | verdict |
|---|---|---|---|---|---|---|---|---|
| `BP · Rotate Key · Dark/Light` | `Art Sub` | `Generated here · the private half never leaves the keychain` | `Generated on the server · the private half stays in the secret manager` | 289.34 → **340.29** | 380×18 | 1 | **39.71** | **FITS** |

Flag: the 80-char approved string would **not** fit here (392.78 px > 380). See §3.

### 4b. BODY PROSE — 12 layers, 8 boards

| board | layer | current | proposed | now → proposed | box | lines | clearance | verdict |
|---|---|---|---|---|---|---|---|---|
| `BP · Add Product · Dark/Light`, `S · Add Product · Verified · Dark/Light` | `Ev Body` | `It clones over SSH. The private half stays in this device's keychain — never shown, logged or stored.` | `It clones over SSH. The private half stays in the secret manager — never shown, logged or stored.` | 487.13 → **475.24** | 560×30 | 1 | 84.76 | **FITS** (11.89 px *narrower* than now) |
| `BP · Product Credentials · Dark/Light` | `L Sub` | `One key, for this product only. The private half never leaves this device.` | `One key, for this product only. The private half stays in the secret manager.` | 347.93 → **367.19** | 596×30 | 1 | 228.81 | **FITS** |
| `BP · Rotate Key · Dark/Light` | `L Sub` | `A new keypair is generated here. You install the public half, then work resumes.` | `A new keypair is generated on the server. You install the public half, then work resumes.` | 389.41 → **431.87** | 596×30 | 1 | 164.13 | **FITS** |
| `S · Product Credentials · No key · Dark/Light` | `R Sub` **(J — new)** | `Generate a keypair here, then install the public half on the repository.` | `Generated on the server — install the public half on the repository.` | 340.00 → **325.08** | 352×30 | 1 | **26.92** | **FITS** (4 ch shorter, 14.92 px narrower) |
| `S · Product Credentials · No key · Dark/Light` | `R Submit Sub` **(I)** | `The private half stays on this device — you copy out the public half` | `The private half stays in the secret manager — you copy out the public half` | 2 lines already → 2 lines | 352×15 | 2 | **−97.88** | **DOES NOT FIT — §5** |

### 4c. METADATA ROW — 6 layers, 6 boards

| board | layer | current | proposed | now → proposed | box | lines | clearance | verdict |
|---|---|---|---|---|---|---|---|---|
| `BP · Product Credentials · Dark/Light` | `F V 0` (C) | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in this device's keychain` | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in the secret manager` | 417.60 → **388.80** | 596×18 | 1 | 207.20 | **FITS** |
| `BPM · Product Credentials · Dark/Light` | `F V 0` (E) | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in the keychain` | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in the secret manager` | 283.67 → **319.89** | **358×32** | 1 | **38.11** | **FITS — narrowest in the set, §6** |
| `BP · Rotate Key · Dark/Light` | `Tech 0` (G) | `GIT_PRODUCT_PR_SHIP_SSH  ·  ed25519  ·  private half written to the keychain, never shown` | `GIT_PRODUCT_PR_SHIP_SSH  ·  ed25519  ·  private half in the secret manager, never shown` | 418.28 → **413.47** | 596×15 | 1 | 182.53 | **FITS** |

### 4d. STEP LABEL — 4 layers, 4 boards

| board | layer | current | proposed | now → proposed | box | lines | clearance | verdict |
|---|---|---|---|---|---|---|---|---|
| `BP · Product Credentials · Dark/Light` | `Act What 0` (D) | `Key created on this device` | `Key generated on the server` | 171.60 → **178.20** | 420×16 | 1 | 241.80 | **FITS** |
| `BPM · Product Credentials · Dark/Light` | `Ev What 0` (D) | `Key created on this device` | `Key generated on the server` | 128.84 → **138.11** | 270×16 | 1 | 131.89 | **FITS** |

---

## 5. The one proposal that does not fit — measured overflow

### `R Submit Sub` on `S · Product Credentials · No key · Dark/Light` (2 layers)

- box **352×15**, IBM Plex **Mono 10**, parentXY **(884, 398)**
- current string 68 chars, full width **408.00 px**, measured `tbW` **342.00** with `tbH` **25**
- **The current layer ALREADY renders two lines and already overflows its 15 px box by 10 px.** This
  is pre-existing, on both boards, and has nothing to do with my change.
- effective one-line capacity of this box: **57 characters / ~342 px** (nominal 352/6.000 = 58.67; the
  ~6 px difference is a wrap inset I did not measure)
- proposed string 75 chars, full width **450.00 px** → **still 2 lines**, rendered height **26**
  against a **15** px box → **box overflow 11 px, versus 10 px today. The change is 1 px worse and
  does not alter the wrap.**

**No A3-correct string fits this slot while preserving the layer's content.** The arithmetic:
the approved custody clause alone is 43 characters, the layer's second clause is 28, and the
shortest honest join is **71 characters** — 14 over a 57-character capacity. Any string that fits
must **delete the layer's content**, which is precisely the trap this lane exists to avoid. I did not
shorten it silently and I am not proposing a resize.

Three options for the human — a design decision, not mine:

| option | what it costs |
|---|---|
| **(a) Accept the pre-existing overflow unchanged** | Zero. Applies the proposal as drafted; wrap count and overflow stay as they are today. Recommended default — it fixes the false claim at no layout risk. |
| **(b) Raise the box 352×15 → 352×30** | One geometry value per board (2 total). Matches the `R Sub` slot directly above it, which is already 352×30. Would also repair the pre-existing defect. Not measured against downstream elements — `R Submit L` is at y364 and `R Submit Sub` at y398, so the space below needs checking before this is granted. |
| **(c) Rewrite to fit one line** | Requires dropping either the custody clause or the "you copy out the public half" instruction — i.e. deleting content. **I do not recommend this** and have not drafted a variant. |

---

## 6. Flags on proposals that DO fit

- **`BPM · Product Credentials · F V 0` (E) — narrowest margin at 38.11 px** in a 358 px box. It
  fits, and by 10.6%. It is the one row I would eyeball after applying, because the string grows by
  6 characters in the narrowest box in the whole set.
- **`S · Product Credentials · No key · R Sub` (J) — narrowest prose margin at 26.92 px** in 352 px.
  It fits, and is *narrower* than the string it replaces, so it is low-risk.
- **`Art Sub` — 39.71 px.** Fits, but it is the row where the *obvious* choice (the approved string)
  fails, so it deserves an explicit human "yes" rather than a mechanical apply.
- **No proposal needs a resize.** 23 of 24 fit as drafted.

---

## 7. The four `add_product_page.dart` sites — and the boards/build divergence

`apps/control_plane/lib/features/products/add_product_page.dart` — **read-only, not edited.** I
verified all four myself; `grep` returns **6 lines in 4 logical sites**, in two byte-identical
duplicated code paths (`_buildKeyPanel` desktop :468-493 / mobile :967-992, `_buildKeyBox` desktop
:495-… / mobile :994-…).

| site | current code | proposed code | board counterpart |
|---|---|---|---|
| **:479-481** desktop<br>**:978-980** mobile | `"It clones over SSH. The private half stays in this device's "` + `'keychain \u2014 never shown, logged or stored.'` | `"It clones over SSH. The private half stays in the secret manager "` + `'\u2014 never shown, logged or stored.'` | `Ev Body` — string **A**, 4 boards |
| **:541-544** desktop<br>**:1037-1040** mobile | `'ed25519 \u00b7 created on this device \u00b7 the private half stays in the keychain'` | `'ed25519 \u00b7 generated on the server \u00b7 the private half stays in the secret manager'` | `Key Meta` / `Art S` — **already correct on all 12 boards** |

Confirmed by the paired `MicroLabel`s: `'WHAT SHIPIT DOES WITH THIS KEY'` at **:475** and **:974**
sits directly above the `Ev Body` pair; `'DEPLOY KEY  \u00b7  THIS PRODUCT ONLY'` at **:532**/**:1028**
and `'Generated for this product'` at **:537**/**:1033** sit directly above the eyebrow. **A fix
scoped to `:542`/`:1038` would correct the eyebrow while leaving the copy directly beneath it
contradicting it** — the failure mode this work item has already paid for once.

### The divergence, stated precisely

| axis | boards | build | consequence |
|---|---|---|---|
| **eyebrow** | **CURRENT** — all 12 `Add Product` boards carry the 80-char A3 string | **STALE** — `:542`/`:1038` ship `created on this device … keychain` | build lags the boards; no new copy needed, this is a **sync** |
| **body** | **STALE** — string A on 4 boards | **STALE** — `:479-481`/`:978-980` ship `this device's keychain` | both sides need the one new string from §4b |

So the human is approving **24 board edits and 4 code edits** against **2 distinct new strings** plus
one already-approved string. Boards and build converge on identical text.

Two notes for whoever implements it:
- The two code paths are exact duplicates. Extracting one constant would make the pair unable to
  drift again. **Flagged as an implementation suggestion, not a requirement of this grant.**
- `:546-551` / `:1042-…` render `SelectableText(deployKey.publicKey)`. That is the **public** half,
  which ADR 0018 §"Effect on presentation" (`:97`) explicitly keeps surfaced: *"The public half is
  surfaced in the UI exactly as before."* Not a G-7 concern. No change proposed.

---

## 8. `BP`'s footer — REPORTED, NOT FIXED

Verified myself on `BP · Add Product · Dark` and `Light`, both read-only.

| measurement | `BP · Dark` | `BP · Light` |
|---|---|---|
| **`Footer` layer type** | **`text` — COPY, not a divider** | **`text`** |
| id | `…a999041263f1` | `…a9a8f2ec0dff` |
| `characters` | `Your decision is recorded permanently. The same piece of work then continues — nothing is restarted.` (100 ch) | identical |
| position / box | (236, 862) **1020×15** | (236, 862) 1020×15 |
| font / rendered | Mono 10 · **600.00 × 13** — 1 line, no wrap | Mono 10 · **600.00 × 12.5** |
| `Footer Rule` | **rectangle**, (236, 848), **1020×1** — the divider, correctly typed | identical |
| `Disclose` | `Show technical details ▸`, (1036, 862), 220×15, right edge **1256** = 236+1020 = content right edge → right-aligned ✓ | identical |
| overlap `Footer` vs `Disclose` | **none** — copy ends at 836, box starts at 1036 | none |

**Confirmed: the footer is a TEXT layer carrying 100 chars, not a divider.** `BP` violates
`27ea6536`'s no-footer-copy clause at the same coordinates the `S` boards did.

⚠️ **This finding is WIDER than pass 1 reported.** Pass 1 scoped it to the two `BP` boards. While
dumping `S · Product Credentials · No key · Dark` I found the **same 100-character `Footer` text
layer at the same (236, 862) 1020×15, rendering 600×13**, on **both** `S · Product Credentials · No
key` boards as well. So the footer copy spans **at least 4 boards across 2 board families**, not 2.
That changes the size of whatever grant follows, and the answer to "`27ea6536` names only the `S`
boards — is `BP` in scope?" now has to account for a second family. **Separate grant. I fixed
nothing.** A page-wide census of this exact string was **NOT_RUN** (§9).

---

## 9. Not measured / NOT_RUN — stated, not assumed

| # | item | status | why / mitigating |
|---|---|---|---|
| 1 | Back-test of all 24 models against each layer's own measured width | **NOT_RUN** | Penpot dormancy, 125 s no-heartbeat; stopped per the one-recovery rule rather than looping. **Mitigating:** per-font-size corpus residuals are measured (0.22–0.67 px on 214–868 samples) and the mono slots are pinned by the exact advance law, cross-validated to 0.02/0.12 px. Verdicts are insensitive to the two values where methods disagreed (§2a, `Ev What 0` 127.94 vs 138.11 → FITS either way). |
| 2 | Page-wide census of the `Footer` string | **NOT_RUN** | Same dormancy. 4 boards confirmed by direct read. The figure "4" is a **floor, not a total.** |
| 3 | `Art S` (BPM/SM) text metrics re-measured | **NOT_RUN** | Not a target layer; Penpot dormant. Consequence: §2E — pass 1's 214.53 px is a wrapped-**line** width, not a string width. Its overlap finding is unaffected (it used `tbY`/`tbH`). |
| 4 | Downstream-element check for `R Submit Sub` option (b) | **NOT_RUN** | Not granted, and a box change is a human decision. `R Submit L` sits at y364 vs `R Submit Sub` y398 — must be checked before granting. |
| 5 | Pixel/visual diff of any proposal | **NOT_RUN** | No such tooling for Penpot in this repository. Fit verdicts are geometric predictions validated sub-pixel against real rendered strings — strong, but not a screenshot. |
| 6 | Independent design review | **NOT_RUN** | Nothing was applied, so there is nothing to review yet. |

**One Penpot dormancy event occurred**, after a full 160-board census and after every target layer
was measured. One minimal recovery read confirmed 160 boards; the two calls after it (G-7, back-test)
completed and the third timed out. No write was in flight at any point.

---

## 10. A3 compliance audit of my own proposals

Checked clause by clause against `9417f8bf` OPTION_C/A3, ADR 0018 §"Current — custody (A3)" `:80-85`
and §"Effect on presentation" `:95-103`, and the appended **scope note** of 2026-10-07.

| constraint | how the proposals satisfy it |
|---|---|
| Generation is **server-side** | No proposal says "generated here", "created on this device", "create locally", or "generate a keypair here". H→`generated on the server`, F→`generated on the server`, D→`generated on the server`, J→`Generated on the server` — 8 layers. |
| Private half is never **STORED** by SHIP IT | Every custody clause is the **approved** wording *"the private half stays in the secret manager"* / *"in the secret manager"*. |
| The scope note's absolute is **storage-scoped** | I introduce **no** claim that the key "never reaches", "never leaves" or "never touches" anything. I deliberately avoided `never reaches you` and similar, because the 2026-10-07 scope note establishes that a same-uid process-memory exposure exists at transport time and is substrate-independent. **No new absolute.** |
| **A2 permanently excluded** | No proposal implies SHIP IT stores sealed bytes itself. `held in the secret manager` and `in the secret manager` both name the manager as custodian. |
| **G-7 REQUIRED — reference is the most sensitive artifact** | Verified by page-wide scan (§1d): no ARN/vault path/secret path exists. The proposals keep only `GIT_PRODUCT_PR_SHIP_SSH`'s role as the credential **variable name** and add nothing that points at the reference. |
| ADR's four prohibitions | `— never shown, logged or stored.` preserved **verbatim** (string A); `never shown` preserved (string G). |
| Public half still surfaced | `you copy out the public half` (I) and `install the public half` (F, J) retained — ADR `:97` keeps the public half surfaced. |

**Three adjacent items I am NOT proposing changes to, flagged for your judgement** (each is true as
written and asserts no location or custody, so each is outside the 24):

1. `R Submit L` = **`Create a key for this product`** (button label, `S · No key`, 2 boards). It asks
   the user to create a key; under A3 SHIP IT generates on the server and the click triggers it. The
   label is not false, but it puts the generation act on the reader. Worth a look next to J.
2. `Step 0` = **`1   A deploy key is generated for this product`** (6 boards). No location claimed —
   true under A3.
3. `Key Name` / `Art T` = **`Generated for this product`** (8 boards). No location claimed — true.

---

## 11. What changed and why

**Nothing.** No board written, no source written, no file created except this report.

- 24 board `characters` values are **proposed, not applied**.
- 4 code literals in `add_product_page.dart` are **proposed, not applied**.
- `27ea6536`'s footer question and `R Submit Sub`'s box are **reported, not acted on**.
- No `.decisions/**`, no `docs/adr/**`, no commit, no push, no Docker/Compose command of any kind.

## 12. Files touched

```
docs/engineering/dispatch/tasks/design-draft-f5-copy/report.md   (this file — sole OWNED_PATH)
```

## 13. Validation results

| command / check | status | note |
|---|---|---|
| `penpot_high_level_overview` read before any other Penpot tool | **pass** | as required |
| `penpotUtils.getPages()` → Page 1 | **pass** | 1 page, `d8ac01df-6646-81d2-8008-a366c09aa9d3` |
| page inventory, own enumeration | **pass** | 164 root children, 160 boards, re-confirmed after dormancy |
| board ids verified by exact name from own read | **pass** | 12/12; id-substring trap present and avoided |
| needle pass 1 (semantic family) | **pass** | 160/160 boards, 202 hits, 28 distinct strings |
| needle pass 2 (independent, broader) | **pass** | 160/160 boards, 182 novel strings, 0 custody claims |
| single-line baselines before verdicts | **pass** | 6 signatures established per board |
| width models, native size, pooled | **pass** | max err 0.22–0.67 px on 214–868 samples |
| cross-size scaling test | **fail → actioned** | 8.922 px error; **scaled models therefore not used** |
| monospace advance law | **pass** | 0.6 × fontSize exact on 3 sizes, 3 boards; agrees with models to 0.02/0.12 px |
| wrapped-layer width trap | **pass** | confirmed exactly (342.00 = 57 × 6.000); no verdict uses a wrapped width |
| fit measured for all 24 proposals | **pass** | 23 FITS, 1 flagged DOES NOT FIT with measured overflow |
| G-7 reference-exposure scan | **pass** | 6 hits page-wide, all metadata rows in this set; no ARN/vault path |
| `BP` footer measured | **pass** | `text`, 100 ch, (236,862) 1020×15, on 2 boards — plus 2 more found |
| 4 `add_product_page.dart` sites verified | **pass** | 6 lines / 4 sites, both paths byte-identical |
| back-test of models vs measured widths | **NOT_RUN** | dormancy, 125 s heartbeat; stopped per rule — §9.1 |
| page-wide `Footer` census | **NOT_RUN** | dormancy — §9.2 |
| pixel / visual diff | **NOT_RUN** | no such tooling |
| independent design review | **NOT_RUN** | nothing applied yet |
| **any board or source write** | **NOT RUN BY DESIGN** | read-only grant; 0 mutations issued |
| **docker / compose** | **NEVER ISSUED** | no command of any kind, mutating or read-only |
| dart analyze / tests / build | n/a | no production source written, out of grant |

## 14. Durable discoveries (for the Manager to route; this lane persists no knowledge base)

1. **CONTRADICTION — the false-custody scope is 24 layers / 12 boards / 10 strings, not 22 / 8, and
   pass 2's slot-type taxonomy (8/8/4/4) is wrong: it is 2/12/6/4.** The 24th layer is
   `Generate a keypair here…` on `S · Product Credentials · No key`, layer `R Sub` — which sits on a
   **two-layer** board set that pass 2 only half-covers. Its needle list had no term matching it.
   **Generalisable: a census is only as good as its needle list, and a needle list inherited from the
   prior census inherits its blind spots. Four counts in a row were wrong before this one.**
2. **DESIGN_DISCOVERY — the approved 80-char string is not a drop-in even for the eyebrow.** Measured
   at 392.78 px in `Art Sub`'s exact font signature, against a 380 px box: **12.78 px overflow, it
   wraps.** "Replace the false string with the approved string" is well-defined only while the target
   layer has the same slot, the same font and a box wide enough for 80 characters. None of the 24
   qualifies.
3. **DESIGN_DISCOVERY — `textBounds.width` is the widest rendered LINE on a wrapped layer, not the
   string's width.** `R Submit Sub` measures 342.00 but needs 408.00. Taking the measurement at face
   value turns a 450 px proposal into a false "FITS" and would have shipped a silent overflow. This
   also reclassifies pass 1's `Art S` 214.53 px as a wrapped-line width. **Generalisable: never compare
   a proposed string's width against a box using the current string's measured width without first
   confirming the current string is on one line.**
4. **DESIGN_DISCOVERY — glyph width is not linearly scalable across font sizes.** Predicting fs-13
   from the fs-11 model scaled by 13/11 gave **8.922 px** worst-case error (mean 0.289). **Report the
   scaling failure and switch to native-size models; do not scale a font measurement.**
5. **PROJECT_FACT — IBM Plex Mono's advance is exactly `0.6 × fontSize`**, verified at fs 10/11/12 on
   three boards, and it agrees with a fitted per-character model to 0.02/0.12 px. For any monospace
   slot, **character count × 0.6 × fontSize is an exact width prediction** — no model needed.
   Preferable executable knowledge for future measurement lanes.
6. **PROCESS_FACT — establish the single-line baseline per signature before any verdict, and reject
   scaled/estimated widths as evidence.** Pass 2 nearly reported a non-wrap as a wrap (estimate);
   cross-size scaling nearly made me report the opposite error (fit). Both were caught only because
   the measurement was tested rather than trusted.
7. **DESIGN_DISCOVERY — a pre-existing defect can hide inside a copy fix.** `R Submit Sub` already
   renders 2 lines in a 15 px box on both boards. Any custody-correct string there will too. **A
   copy fix scoped to the string alone cannot discharge a box defect on the same layer**, and
   reporting "no box change needed" without checking the current line count would have been false.
8. **CONTRADICTION — footer copy is wider than `27ea6536`'s scope and than pass 1 measured.** The
   same 100-character `Footer` text layer at (236, 862) 1020×15 is on **both**
   `S · Product Credentials · No key` boards, not only the two `BP` boards — at least 4 boards across
   2 families. The scope question needs restating before it can be granted.
9. **PROJECT_FACT / WORKFLOW_IMPROVEMENT — four dispatch figures in this work item were wrong**
   (22 vs 24 layers; 8/8/4/4 vs 2/12/6/4; "the approved string fits the eyebrow" vs 12.78 px
   overflow; footer scope 2 boards vs ≥4). The count in a dispatch prompt is now the **least**
   reliable input to a design lane, ahead of prose.

## 15. Unresolved issues and blockers

- **HUMAN DECISION REQUIRED (1 item, design content).** `S · Product Credentials · No key · R Submit
  Sub` ×2: accept the pre-existing 2-line overflow unchanged (option a, my recommendation), grant a
  box change to 352×30 (option b, needs a downstream check at y398 vs `R Submit L` y364), or author a
  content-deleting rewrite (option c, not recommended). See §5. **I did not decide this.**
- **HUMAN APPROVAL REQUIRED (the deliverable).** 24 board `characters` values and 4 code literals
  (§4, §7), grouped as one approval. `READY_FOR_INDEPENDENT_DESIGN_REVIEW` is **NO** because nothing
  has been applied — the human approves the copy first, then an apply lane runs, then the result goes
  to independent design review.
- **SEPARATE GRANT — `27ea6536` footer scope.** `BP · Add Product · Dark/Light` **and**
  `S · Product Credentials · No key · Dark/Light` carry a 100-char `Footer` **text** layer at
  (236, 862) 1020×15. At least 4 boards; a page-wide census was NOT_RUN (§8, §9.2). Reported only.
- **For the Manager — restate the acceptance criterion.** Any criterion phrased as "the 8/22 remaining
  false layers carry A3-correct copy" is unsatisfiable as written; the measured scope is 24 layers /
  12 boards / 10 strings across four slot types (§1).
- **Carried forward from `design-correct-f5-bpm-stack`, untouched here** — `BPM · Add Product`'s
  `Submit L` is still at parentY 518 (SM: 520) and `fontSize` 13 (SM: 11). No copy relationship.
- **Adjacent copy flagged, not proposed:** `R Submit L`'s `Create a key for this product` (§10.1).

## 16. Cleanup confirmation

- [x] **No Docker or Compose command issued — none of any kind**, mutating or read-only
- [x] No process, container or compose project started
- [x] No temporary artifacts left behind
- [x] **Zero Penpot mutations**: no `characters`, no `resize()`, no `setParentXY`, no `remove()`, no
      `clone()`, no board renamed/moved/deleted/re-parented
- [x] Nothing modified outside `OWNED_PATHS` (this report only)
- [x] No production source written; `add_product_page.dart` read-only
- [x] `.decisions/**` and `docs/adr/**` untouched — read only
- [x] Nothing committed, nothing pushed
- [x] One dormancy event disclosed; stopped rather than retrying in a loop (§9)

## 17. Recommended next action

```
HUMAN_APPROVAL
```

Two decisions, both content-level and both mine to surface rather than make: (1) approve or amend the
24 copy proposals in §4 as one group — 23 fit as drafted, and the 80-char approved string does not
fit the eyebrow it was written for; (2) choose among the three options in §5 for the one layer whose
box cannot hold any honest replacement. An apply lane then writes 24 board values and 4 code
literals, and only then does independent design review have something to review.

---

```
RESULT: DESIGN_REVISION_COMPLETE

FEATURE: Add Product rebuild — draft A3-correct replacement copy for the false custody layers
BRIEF_ID: design-draft-f5-copy
REVISION_ID: design-draft-f5-copy / r1
REVISION_NUMBER: 1
BRANCH: main
BASE_SHA: 7b7efbf7629459676a2781a6871eed472be695af
HEAD_SHA: 7b7efbf7629459676a2781a6871eed472be695af

OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-draft-f5-copy/report.md
READ_ONLY_PATHS:
  - every Penpot board (all 160)
  - apps/control_plane/lib/features/products/add_product_page.dart
  - .decisions/9417f8bf-73b8-4827-9515-bdfe92e5a9d5.yaml
  - docs/adr/0018-per-product-git-credentials.md
  - docs/engineering/dispatch/tasks/design-correct-f5-{pass2,custody-copy,bpm-stack}/report.md
PROHIBITED_PATHS:
  - EVERY Penpot board (drafting lane: zero mutations)
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, docs/adr/**, WORK_STATE.md, LANES.md

ARTIFACT_PATHS:
  - docs/engineering/dispatch/tasks/design-draft-f5-copy/report.md

RISK_LEVEL: 2
RISK_RATIONATIVE: >
  Level 2 (Feature UX Change). The proposals restate user-visible security claims in product copy
  across 24 layers on 12 live shared boards plus 4 shipped code literals. No architecture, decision,
  interface or data change — 9417f8bf OPTION_C/A3 already settled the substrate and ADR 0018 A2
  already recorded it, so this is implementation of a resolved decision in copy, not a new decision.
  Not level 3: no workflow, navigation or IA change, nothing destructive, fully reversible by
  restoring the current strings. Not level 1: the text asserts a security property a reader may rely
  on, and ADR 0018 A2 records that a wrong absolute is worse than an absent one because a trusting
  reader stops looking for the real exposure — so the copy was audited clause-by-clause against the
  2026-10-07 scope note and introduces no new absolute.
CHANGELOG: >
  r1 — initial proposal set. Verified census 24 layers / 12 boards / 10 distinct false strings across
  four slot types (eyebrow 2, body prose 12, metadata row 6, step label 4), from two independent
  needle passes over 160/160 boards. 9 distinct new strings proposed plus 1 already-approved eyebrow
  for the build. 23 of 24 proposals fit their box; 1 (`R Submit Sub`) flagged DOES NOT FIT with
  measured overflow and three costed options, not resolved. Four add_product_page.dart sites drafted
  so boards and build converge; divergence stated. `BP` footer reported not fixed, and the finding
  found to span >= 4 boards across 2 families.

TRACEABILITY:
  REQUIREMENTS_COVERED:
    - 9417f8bf OPTION_C / A3 - external secret manager; SHIP IT holds a reference, not key bytes
    - 9417f8bf resolution consequence (2): A2 permanently excluded - no proposal implies it
    - 9417f8bf resolution consequence (3): G-7 REQUIRED - reference not re-exposed; verified page-wide
    - 9417f8bf SCOPE NOTE 2026-10-07: the "never holds key bytes" absolute is STORAGE-scoped, and a
      same-uid process-memory exposure exists at transport time; no proposal asserts the absolute
    - 9417f8bf CITATION CORRECTION 2026-10-07: read; the ADR's same-uid reasoning taken from
      :159-160 and :96-97, not the pointer the earlier note gave
    - ADR 0018 :80-85 (Current - custody A3): server-side generation, manager custody, reference-only,
      four prohibitions carried verbatim
    - ADR 0018 :95-103 (Effect on presentation): copy must not claim the key stays in the keychain;
      the public half stays surfaced
    - ADR 0018 :33, :52 (Amendment A2) and :4 (accepted status)
    - b869ec24 OPTION_A: generation is server-side (relied on, not reopened)
    - 27ea6536 no-footer-copy clause: measured on BP, reported not fixed
  REQUIREMENTS_GAPS:
    - G-7 remediation itself (remove referenceName from RepositoryCredentialView) is a 9417f8bf
      follow-up owned by design-agent and OUTSIDE this grant. This lane only verified that the copy
      does not re-expose the reference.
    - A3 unavailability remediation copy (9417f8bf follow-up, design-agent) - not drafted here.
    - The `R Submit Sub` box/overflow decision is unresolved by design (Level 2, human).
    - 27ea6536's scope does not name the BP or S-No-key boards; the scope question is open and the
      page-wide footer census is NOT_RUN.

DESIGN_SYSTEM_COMPLIANCE: PASS
UX_ACCESSIBILITY_SCORE: UNKNOWN
IMPLEMENTATION_FEASIBILITY: HIGH

DISCOVERIES:
  - CONTRADICTION: true scope is 24 layers / 12 boards / 10 strings, not 22/8/16/8; pass 2's slot
    taxonomy 8/8/4/4 is wrong, measured 2/12/6/4
  - CONTRADICTION: footer copy spans >= 4 boards across 2 families, wider than 27ea6536 and pass 1
  - DESIGN_DISCOVERY: the approved 80-char string does not fit the eyebrow slot (392.78px vs 380px)
  - DESIGN_DISCOVERY: textBounds.width is the widest LINE on a wrapped layer, not the string width
  - DESIGN_DISCOVERY: glyph width is not linearly scalable across font sizes (8.922px worst case)
  - DESIGN_DISCOVERY: a pre-existing box defect (R Submit Sub, 2 lines in 15px) cannot be discharged
    by a copy-only fix
  - PROJECT_FACT: IBM Plex Mono advance is exactly 0.6 x fontSize, verified fs10/11/12
  - PROCESS_FACT: test the measurement method; two of my own numbers were wrong before being caught
  - RUNTIME_DISCOVERY: one Penpot dormancy event (125s no-heartbeat); disclosed, stopped not retried

KNOWLEDGE_PERSISTED:
  none — this lane is read-only on Penpot and writes only its own report; discoveries are reported
  for the Manager to route under aef-repository-learning authority levels. The exact-mono-advance
  finding (0.6 x fontSize) is the one candidate for executable knowledge (a measurement script).

BLOCKERS:
  - HUMAN_DECISION_REQUIRED: R Submit Sub x2 - accept pre-existing overflow, grant a box change, or
    author a content-deleting rewrite (not recommended). Three costed options in section 5.
  - HUMAN_APPROVAL: the 24 board values and 4 code literals, as one group (the deliverable)
  - Separate grant: 27ea6536 footer scope, now known to span >= 4 boards
  - NOT_RUN: 24-layer model back-test and page-wide Footer census, both lost to Penpot dormancy;
    stated as not-measured rather than assumed

READY_FOR_INDEPENDENT_DESIGN_REVIEW: NO
```