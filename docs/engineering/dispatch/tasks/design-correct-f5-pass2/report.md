# Report — design-correct-f5-pass2 (BPM overlap repaired; 22 false layers remain, not 8)

```
RESULT: DESIGN_REVISION_BLOCKED
TASK_ID: design-correct-f5-pass2
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — F5 pass 2: repair the BPM overlap, then fix the 8 remaining false layers
AREA: Penpot — 2 BPM board layouts, then 8 remaining text layers across 6 boards
WORKTREE: /Users/alkebut/air/shipit-platform  (canonical checkout; Penpot is a live shared file)
BRANCH: main
BASE_SHA: b0d645687817ef4aa96ceb1933979b5a86fb320a
HEAD_SHA: b0d645687817ef4aa96ceb1933979b5a86fb320a
COMMITTED: NO
```

**WHY `BLOCKED` AND NOT `COMPLETE`.** Part 1 is done and verified. Part 2 is not, and cannot be,
inside this grant:

1. **The scope premise is falsified again, and more severely than last time.** The dispatch grants
   **8** remaining false layers. **My own sweep of all 160 boards measures 22.** The prior lane
   measured 16. Three consecutive lanes have now been handed a shrinking false count, and the
   truth is larger than all three.
2. **Zero of the 22 accepts the approved string as a substitution.** The approved string is a
   self-contained 80-char *eyebrow* whose subject is the key. It is a drop-in only for a layer
   that already read `ed25519 · created on this device · the private half stays in the keychain` —
   exactly the 8 the prior lane already fixed. Every one of the 22 asserts a **different fact in a
   different layer role**, so each needs copy authored for its own role. That is a Level 2 content
   decision, which `aef-design-workflow` §6 reserves for a human gate.
3. **Part 1 achieved its acceptance criterion but surfaced a knock-on overlap** between `Key State`
   and `Art L1`/`Art L2` on both BPM boards, caused by a third variable I was explicitly not
   granted (§3c).

A green here would be a false green on all three counts.

---

## 1. Provenance

`main` is at `b0d645687817ef4aa96ceb1933979b5a86fb320a`, **identical** to the `BASE_SHA` and
`HEAD_SHA` recorded by the prior lane. No commit, no push, no source change.

**No Docker or Compose command was issued — not `info`, not `ps`, not `logs`, not `config`, not any
mutating one.** I ran no Docker command of any kind. No production source written. Nothing touched
outside `OWNED_PATHS`.

## 2. Page baseline — my own enumeration, ids verbatim, never reconstructed

`penpotUtils.getPages()` → exactly one page, `Page 1` (`d8ac01df-6646-81d2-8008-a366c09aa9d3`).
**164 root children, 160 boards**, matching the prior lane's baseline exactly (its two `NOT_RUN`
confirmations in §9 are now closed).

Every board id below was taken from my own root-children read and matched by **exact full id AND
asserted exact board name** before any write. The id-substring trap is real and present on this page:
`…a9a03d9da341` (`S · Add Product · Unknown host · Dark`) is a substring of `…a9ac5f5ad2dc`
(`BPM · Add Product · Dark`).

## 3. PART 1 — the `BPM` overlap. REPAIRED AND VERIFIED.

### 3a. The approved `SM` reference, measured myself first

`SM - Add Product - Unknown host - Light` · `6d055762-a70b-804c-8008-bf65ff750422` · 44 children

| layer | id | parentXY | box | fs | chars | textBounds y / h |
|---|---|---|---|---|---|---|
| `Art S` | `…bf66060a479d` | **(138, 418)** | **220×24** | 10 | 80 | 11167.5 / 24.5 |
| `Key State` | `…bf6606509318` | **(138, 446)** | 220×15 | 10 | 19 | 11195.5 / 12.5 |

- **BOX gap = 446 − 418 − 24 = 4** ← the reference figure the dispatch states
- **RENDERED gap = 11195.5 − (11167.5 + 24.5) = 3.5**

### 3b. Before → after, per board

I measured the SM reference and BPM's *neighbouring stack* **before** writing, not after.

**`BPM · Add Product · Dark`** · `b5b63334-c22a-80a6-8008-a9ac5f5ad2dc` · 36 children

| | `Art S` before | `Art S` after | `Key State` before | `Key State` after |
|---|---|---|---|---|
| box | 220×**15** | 220×**24** | 220×15 | 220×15 |
| parentXY | (138, 418) | (138, 418) | (138, **436**) | (138, **446**) |
| textBounds y / h | 10217 / 25 | 10217 / 25 | 10235 / 13 | 10245 / 13 |
| textBounds bottom | **10242** | **10242** | 10248 | 10258 |

**`BPM · Add Product · Light`** · `b5b63334-c22a-80a6-8008-a9ad42be419b` · 36 children

| | `Art S` before | `Art S` after | `Key State` before | `Key State` after |
|---|---|---|---|---|
| box | 220×**15** | 220×**24** | 220×15 | 220×15 |
| parentXY | (138, 418) | (138, 418) | (138, **436**) | (138, **446**) |
| textBounds y / h | 11167 / 25 | 11167 / 25 | 11185 / 13 | 11195 / 13 |
| textBounds bottom | **11192** | **11192** | 11198 | 11208 |

Children **36 → 36** on both boards — the correct signature for a geometry-only edit. Layer names,
ids, font sizes, `growType` (already `fixed`) and **`characters`** are unchanged; only
`resize(220,24)` and `setParentXY(…,138,446)` were applied. Each write was guarded by exact full-id
lookup, exact board-name assertion, `isContainedIn` board membership, an exact pre-state match on
box and position, and an 80-char/`secret manager`/no-`keychain` guard on the string — so the guard
also proves I did not re-apply over a foreign string.

### 3c. VERIFICATION AGAINST THE SM REFERENCE — read in a SEPARATE, settled call

Per the stale-`textBounds` discipline, the verification below is a distinct call from the write.

| measurement | SM reference | `BPM · Dark` after | `BPM · Light` after | verdict |
|---|---|---|---|---|
| `Art S` box | 220×24 @ 418 | 220×24 @ 418 | 220×24 @ 418 | **IDENTICAL** |
| `Key State` box | 220×15 @ 446 | 220×15 @ 446 | 220×15 @ 446 | **IDENTICAL** |
| **BOX gap `Art S` → `Key State`** | **4** | **4** | **4** | **EXACT MATCH — 4px as on SM** |
| **RENDERED gap** | **3.5** | **3** | **3** | 0.5px narrower — see below |
| `Art S` vs `Key State` overlap | none | **none** (clearance 3) | **none** (clearance 3) | **AC #1 MET** |
| overlap *before* the edit | — | **+7** | **+7** | dispatch's figure confirmed exactly |

**The 7px overrun the dispatch measured is confirmed to the pixel on both boards** (`10242` vs
`10235`; `11192` vs `11185`) and is cleared.

**The 0.5px rendered difference is not a third variable and I did not tune it.** It is sub-pixel
text-layout rounding that predates this lane and differs between the two boards at the *same* font
size and box: BPM renders `Art S` `textBounds.h = 25.0` with its text top 1.0px above its box top,
SM renders `24.5` with its text top 0.5px above. The **box geometry is bit-identical to the approved
reference**, which is what the grant specifies and what "4px" denotes. Reporting it rather than
absorbing it into a new position is the whole point of the instruction.

### 3d. ⚠️ KNOCK-ON OVERLAP INTRODUCED — REPORTED, NOT FIXED

I measured BPM's stack below `Key State` **before** writing, and it is **not** the SM stack.

| layer | SM parentY | BPM parentY | delta |
|---|---|---|---|
| `Art S` | 418 | 418 | 0 |
| `Key State` | 446 | 436 | −10 |
| **`Art L1` / `Art L2`** | **466** | **456** | **−10** |
| next | `Trust K` 514 / `Trust Body` 532 | `Submit L` 518 | different structure |

Consequence of the two granted variables, measured:

| | SM reference | `BPM` after |
|---|---|---|
| `Key State` box bottom | 461 | 461 |
| `Art L1` box top | 466 | **456** |
| BOX gap | +5 | **−5 (boxes overlap)** |
| `Key State` textBounds bottom | 11208 | 10258 / 11208 |
| `Art L1` textBounds top | 11215 | **10255 / 11205** |
| **RENDERED** | **+7 clear** | **−3 OVERLAP** |

So: the `Art S`/`Key State` collision is gone, and a **`Key State` vs `Art L1`/`Art L2` collision
appears, 3px, on both BPM boards** — against the "Copy key" / "Check access" labels. The cause is
pre-existing and outside my grant: BPM's `Art L1`/`Art L2` sit 10px higher than SM's. Repairing it
requires moving `Art L1`/`Art L2` 456→466 and re-checking what sits beneath (`Submit L` at 518 is
only 52px below, versus SM's `Trust K` at 514) — **a third variable, and I was not granted it.**
Net effect of the pass on that region: the collision moves down one layer rather than disappearing.

I did not move `Art L1`/`Art L2`. Tuning it would have been exactly the unauthorised third change.

### 3e. What I did NOT do, deliberately

Font size untouched (`Art S` still `fontSize` 10, as on SM). Copy untouched (still the 80-char
approved string). No other layer on either board moved. Both fixes are the granted two variables
and nothing else.

---

## 4. PART 2 — MY OWN SWEEP. **22 REMAINING FALSE LAYERS, NOT 8.**

I established this list before editing anything, per the instruction not to take any count on faith.

**Method.** Eight bounded chunks of 20–21 boards each, covering **160 of 160 boards**, each chunk
scoped to a board subtree (a single page-wide sweep is what times out — 6,823 layers). Needles:
`keychain`, `key chain`, `this device`, `created here`, `generated here`, `never leaves`,
`held in`, `created on this`, `secret store`.

| chunk | boards | raw hits | session/identity (not custody) | **custody claims** |
|---|---|---|---|---|
| 0–20 | 21 | 18 | 18 | 0 |
| 21–41 | 21 | 16 | 16 | 0 |
| 42–62 | 21 | 14 | 14 | 0 |
| 63–83 | 21 | 43 | 34 | **9** |
| 84–104 | 21 | 11 | 6 | **5** |
| 105–125 | 21 | 30 | 22 | **8** |
| 126–146 | 21 | 4 | 4 | 0 |
| 147–159 | 13 | 0 | 0 | 0 |
| **total** | **160** | **136** | **114** | **22** |

**Classified noise (114 layers), three exact phrases, all identity/session copy, none key custody
and none affected by A3:** `Signed in on this device` · `Saved as you, on this device` ·
`you  ·  on this device`. I checked each phrase individually rather than pattern-matching `on this
device` — my first classifier did blanket-match that substring and **wrongly filed `Key created on
this device` as noise**; I caught it and re-ran the affected chunk. Recorded because it is the same
class of error as the prior lane's filtered census, one level up.

### 4a. THE 22 — every layer still asserting device-side custody

**9 distinct false strings on 22 layers across 12 boards.**

| # | board | layer id | layer | parentXY | box | chars | string |
|---|---|---|---|---|---|---|---|
| 1 | `BP · Add Product · Dark` | `…a9990ab5b120` | `Ev Body` | 254, 622 | 560×30 | 101 | **A** |
| 2 | `BP · Add Product · Light` | `…a9a8f38c7ab5` | `Ev Body` | 254, 622 | 560×30 | 101 | **A** |
| 3 | `S · Add Product · Verified · Dark` | `…a9a04d7d9092` | `Ev Body` | 254, 622 | 560×30 | 101 | **A** |
| 4 | `S · Add Product · Verified · Light` | `…a9a97eeafae0` | `Ev Body` | 254, 622 | 560×30 | 101 | **A** |
| 5 | `BP · Product Credentials · Dark` | `…a9a52baee193` | `L Sub` | 236, 154 | 596×30 | 74 | **B** |
| 6 | `BP · Product Credentials · Light` | `…a9a94327b6c6` | `L Sub` | 236, 154 | 596×30 | 74 | **B** |
| 7 | `BP · Product Credentials · Dark` | `…a9a52bce1546` | `F V 0` | 236, 210 | 596×18 | 58 | **C** |
| 8 | `BP · Product Credentials · Light` | `…a9a943529817` | `F V 0` | 236, 210 | 596×18 | 58 | **C** |
| 9 | `BP · Product Credentials · Dark` | `…a9a5318317bd` | `Act What 0` | 406, 704 | 420×16 | 26 | **D** |
| 10 | `BP · Product Credentials · Light` | `…a9a94ae1a7cf` | `Act What 0` | 406, 704 | 420×16 | 26 | **D** |
| 11 | `BPM · Product Credentials · Dark` | `…a9ac6c754e7c` | `F V 0` | 16, 192 | 358×32 | 48 | **E** |
| 12 | `BPM · Product Credentials · Light` | `…a9ad566a30a7` | `F V 0` | 16, 192 | 358×32 | 48 | **E** |
| 13 | `BPM · Product Credentials · Dark` | `…a9ac6e09b986` | `Ev What 0` | 100, 458 | 270×16 | 26 | **D** |
| 14 | `BPM · Product Credentials · Light` | `…a9ad599b6b9a` | `Ev What 0` | 100, 458 | 270×16 | 26 | **D** |
| 15 | `BP · Rotate Key · Dark` | `…a9b7e08c7860` | `L Sub` | 236, 154 | 596×30 | 80 | **F** |
| 16 | `BP · Rotate Key · Dark` | `…a9b7e8f80ed1` | `Tech 0` | 236, 778 | 596×15 | 89 | **G** |
| 17 | `BP · Rotate Key · Dark` | `…a9b7ea0b85de` | `Art Sub` | 410, 496 | 380×18 | 59 | **H** |
| 18 | `BP · Rotate Key · Light` | `…a9b819bbdb21` | `L Sub` | 236, 154 | 596×30 | 80 | **F** |
| 19 | `BP · Rotate Key · Light` | `…a9b82130fa17` | `Tech 0` | 236, 778 | 596×15 | 89 | **G** |
| 20 | `BP · Rotate Key · Light` | `…a9b8223c615c` | `Art Sub` | 410, 496 | 380×18 | 59 | **H** |
| 21 | `S · Product Credentials · No key · Dark` | `…a9b843bdd84b` | `R Submit Sub` | 884, 398 | 352×15 | 68 | **I** |
| 22 | `S · Product Credentials · No key · Light` | `…a9b85b8691fb` | `R Submit Sub` | 884, 398 | 352×15 | 68 | **I** |

| | exact current string | len | layers |
|---|---|---|---|
| **A** | `It clones over SSH. The private half stays in this device's keychain — never shown, logged or stored.` | 101 | 4 |
| **B** | `One key, for this product only. The private half never leaves this device.` | 74 | 2 |
| **C** | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in this device's keychain` | 58 | 2 |
| **D** | `Key created on this device` | 26 | 4 |
| **E** | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in the keychain` | 48 | 2 |
| **F** | `A new keypair is generated here. You install the public half, then work resumes.` | 80 | 2 |
| **G** | `GIT_PRODUCT_PR_SHIP_SSH  ·  ed25519  ·  private half written to the keychain, never shown` | 89 | 2 |
| **H** | `Generated here · the private half never leaves the keychain` | 59 | 2 |
| **I** | `The private half stays on this device — you copy out the public half` | 68 | 2 |

### 4b. Six of these the prior lane did not list

Prior lane `§4a`+`§4b` = **16 layers** (12 `keychain` + 4 `created on this device`) across
**12 boards**. I find **22** across the same 12 boards. The six it missed:

- **B ×2** — `BP · Product Credentials · Dark/Light` `L Sub` (236,154): *"The private half never
  leaves this device."* Its needle matched `never leaves`, which the prior lane did not include.
- **F ×2** — `BP · Rotate Key · Dark/Light` `L Sub` (236,154): *"A new keypair is **generated
  here**."* Matched `generated here`, also not in its needle set.
- **I ×2** — `S · Product Credentials · No key · Dark/Light` `R Submit Sub` (884,398): *"The private
  half **stays on this device**…"* Matched `this device`.

So F5's true board scope is **12 boards**, not 8, and its true layer scope is **22**, not 8 — and
the prior lane's `§4a/§4b` are themselves incomplete. **All three dispatch counts (8, 16, 8) were
wrong.** The prior lane's own census also used a needle set narrower than the one this dispatch
instructs, so its residual count could not have reached mine.

---

## 5. WHY I APPLIED **NOTHING** IN PART 2

### 5a. The approved string is not a substitution for any of the 22

The approved string is

```
ed25519 · generated on the server · the private half stays in the secret manager
```

— a **self-contained 80-char monoMeta eyebrow whose subject is the key**. It is a drop-in *only*
for a layer that already read `ed25519 · created on this device · the private half stays in the
keychain`. **Zero** of the 22 carries that shape:

- **A, B, F, I** are prose sentences with a **different subject** ("It clones over SSH…", "One key,
  for this product only…", "A new keypair is generated here…", "The private half stays on this
  device…"). Pasting the eyebrow into a 560×30 / 596×30 / 352×15 prose slot **deletes the sentence's
  actual content** and leaves the panel explaining nothing.
- **C, E, G** are metadata rows whose subject is the **credential name**
  `GIT_PRODUCT_PR_SHIP_SSH`, not the key type. The approved string silently **drops the credential
  name** — a different fact needing its own copy.
- **D** is a 26-char step/result label in a 16px single-line slot (`420×16`, `270×16`). The 80-char
  eyebrow is **3× the length in half the height**.
- **H** is the closest — see §5b.

Applying it anyway would be the same class of error as the false copy: it would make the boards
assert something that is not what the design says.

### 5b. `BP · Rotate Key` — the priority board. Current strings and my proposal.

Measured on `BP · Rotate Key · Dark` · `b5b63334-c22a-80a6-8008-a9b7dda85056` · 114 children
(`Light` · `…a9b816eea081` is identical).

The dispatch named one layer. **The board carries three**, and they are mutually redundant:

| layer | id | current string | my proposed replacement |
|---|---|---|---|
| `Art Sub` | `…a9b7ea0b85de` | `Generated here · the private half never leaves the keychain` | `Generated on the server · the private half stays in the secret manager` |
| `Tech 0` | `…a9b7e8f80ed1` | `GIT_PRODUCT_PR_SHIP_SSH  ·  ed25519  ·  private half written to the keychain, never shown` | `GIT_PRODUCT_PR_SHIP_SSH  ·  ed25519  ·  private half in the secret manager, never shown` |
| `L Sub` | `…a9b7e08c7860` | `A new keypair is generated here. You install the public half, then work resumes.` | `A new keypair is generated on the server. You install the public half, then work resumes.` |

**`Art Sub` is A3-consistent, and I verified that clause by clause:**

- `Generated on the server` — decision `b869ec24` (OPTION_A) settles generation **server-side**;
  `9417f8bf` OPTION_C/A3 does not reopen it. **True**, and the inverse of the current `Generated here`.
- `the private half stays in the secret manager` — **verbatim** from the approved `SM` string, so it
  is approved language by construction rather than by my assertion.
- Both false claims are removed: device-side generation **and** device-side custody.
- Per `9417f8bf`'s dated scope note, "stays in the secret manager" is true in the **storage**
  dimension — never in a file, table, log, backup or client payload — which is exactly the claim the
  approved `SM` boards already make. I introduce no new absolute.

**Geometry checked, not assumed:** `Art Sub` box is **380×18**, `fontSize` 11, and its current 59-char
string renders **289.34** wide (90.66px clearance). The proposed 70-char string projects to
**343.3px — 36.7px inside the box, no wrap**, at unchanged font size.

**So `Art Sub` alone is applicable, and I still did not apply it.** Fixing one of three redundant
layers would leave the same board simultaneously reading *`Generated on the server · the private
half stays in the secret manager`* (`Art Sub`), *`private half written to the keychain`* (`Tech 0`)
and *`A new keypair is generated here`* (`L Sub`) — a self-contradicting screen on the one screen
whose entire purpose is key rotation. That is the precise failure mode this pass exists to prevent:
**a second distinct custody string on the same page.** `Tech 0` and `L Sub` need two newly authored
strings. I will not author product-security copy unilaterally.

Per the dispatch's own instruction — *"If you judge that needs a design decision rather than a
substitution, STOP AND REPORT rather than guessing"* — **I stopped.** All three proposals above are
ready to apply on approval; `Art Sub` is measured fit, `Tech 0` needs ~366px in a 596px box, `L Sub`
needs ~389px in a 596px box (all from the measured renders on that board), so none of them will wrap.

### 5c. Proposed copy for the other 19 — for one-pass approval, not applied

| # | string | proposed replacement | basis |
|---|---|---|---|
| A (×4) | `It clones over SSH. The private half stays in this device's keychain — never shown, logged or stored.` | `It clones over SSH. The private half stays in the secret manager — never shown, logged or stored.` | **minimal clause substitution**: `in this device's keychain` → `in the secret manager`. Preserves the sentence, the "never shown, logged or stored" tail, and the 560×30 two-line box. Cleanest A3-consistent edit in the set. |
| B (×2) | `One key, for this product only. The private half never leaves this device.` | `One key, for this product only. The private half stays in the secret manager.` | clause substitution; 74→74 chars, no reflow |
| C (×2) | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in this device's keychain` | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in the secret manager` | clause substitution; preserves the credential name |
| D (×4) | `Key created on this device` | `Key generated on the server` | **authored** — no approved 26-char equivalent exists. 26→26 chars, fits `420×16` / `270×16` |
| E (×2) | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in the keychain` | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in the secret manager` | clause substitution; preserves the credential name |
| I (×2) | `The private half stays on this device — you copy out the public half` | `The private half stays in the secret manager — you copy out the public half` | clause substitution; 68→71 chars in a 352×15 box — **needs a wrap check before applying** |

---

## 6. THE FOUR `add_product_page.dart` SITES — VERIFIED, NOT FIXED

`apps/control_plane/lib/features/products/add_product_page.dart` — **read-only, not edited.**
`grep` returns **6 lines in 4 logical sites**, in two duplicated code paths. Confirmed by the
surrounding structure: `_DesktopAddProduct` at `:276`, `_MobileAddProduct` at `:774`, and a paired
`MicroLabel('WHAT SHIPIT DOES WITH THIS KEY')` at `:475` and `:974`.

| lines | code | path | board counterpart |
|---|---|---|---|
| **480–481** | `"It clones over SSH. The private half stays in this device's "` + `'keychain \u2014 never shown, logged or stored.'` | desktop | `Ev Body` — string **A**, 4 boards |
| **542** | `'ed25519 \u00b7 created on this device \u00b7 the private half stays in the keychain'` | desktop | `Art S` / `Key Meta` — **already corrected on the boards, still false in the build** |
| **979–980** | *identical literal* | mobile | `Ev Body` — string **A** |
| **1038** | *identical literal* | mobile | `Art S` — as `:542` |

**This confirms the dispatch's correction of the prior lane's §10, and sharpens it.** The two named
sites (`:542`, `:1038`) are the *eyebrow*. The `Ev Body` pair (`:480-481`, `:979-980`) is the body
copy **directly beneath** it, and it is the string that still carries *this device's keychain*.
Because the boards' A string sits in the same panel as the eyebrow, **a `:542`/`:1038`-only fix
leaves the shipped screen contradicting itself** — exactly the failure mode the dispatch warns of.

⚠️ Additional fact the implementer needs, measured here: **the boards and the build have diverged.**
`:542`/`:1038` still ship `created on this device … stays in the keychain`, but all 12 `Add Product`
boards already carry the corrected A3 string. So the **eyebrow is stale in the build and current on
the boards**, while the **body is stale on both**. Any fix should set both paths to the same final
copy, and the final copy is not yet decided — it is `9417f8bf`'s to own, and it is pending §5c.

---

## 7. THE FOUR `SM` BOARDS ARE UNTOUCHED ✓

| board | id | children (baseline → now) | `Art S` | `Key State` | custody string |
|---|---|---|---|---|---|
| `SM - Add Product - Unknown host - Dark` | `…bf65e644269b` | 44 → **44** | (138,418) 220×24 | — | 80 chars, correct |
| `SM - Add Product - Verified - Dark` | `…bf65f36b1c9a` | 36 → **36** | (138,418) 220×24 | — | 80 chars, correct |
| `SM - Add Product - Unknown host - Light` | `…bf65ff750422` | 44 → **44** | (138,418) 220×24 | (138,446) 220×15 | 80 chars, correct |
| `SM - Add Product - Verified - Light` | `…bf660e124738` | 36 → **36** | (138,418) 220×24 | (138,446) 220×15 | 80 chars, correct |

- **No write was issued against any SM board.** Both Part 1 writes asserted an exact board name
  beginning `BPM ·`; no SM name can match.
- **This closes the prior lane's two `NOT_RUN` items** (§9 there: post-edit SM child counts and
  post-edit page root-children count). Both re-measured here: SM **44/36/44/36** and page root
  children **164** / **160 boards** — all exactly at baseline.
- **Mobile revision 6's approval is VALID, not invalidated.** Nothing outside the two owned BPM
  boards was touched.

---

## 8. What changed and why

**Exactly four geometry values, on two boards, all granted:**

| board | layer | change |
|---|---|---|
| `BPM · Add Product · Dark` | `Art S` | box 220×15 → **220×24** |
| `BPM · Add Product · Dark` | `Key State` | parentY 436 → **446** |
| `BPM · Add Product · Light` | `Art S` | box 220×15 → **220×24** |
| `BPM · Add Product · Light` | `Key State` | parentY 436 → **446** |

Result: the A3-correct custody string now renders two lines inside a box authored for two lines, on
**every** `Add Product` board, matching the approved `SM` treatment exactly (220×24 @ 418, 220×15 @
446, **4px gap**). **No copy was changed anywhere in this pass** — the 80-char A3 string is now
consistent across all 16 mobile and desktop `Add Product` boards.

No abstraction, state or interface change. No `.decisions/**` or `docs/adr/**` touched. Nothing
committed or pushed.

## 9. Validation results

| command / check | status | note |
|---|---|---|
| `penpotUtils.getPages()` → Page 1 | **pass** | 1 page, `d8ac01df-6646-81d2-8008-a366c09aa9d3` |
| page inventory (start) | **pass** | 164 root children, 160 boards |
| page inventory (end) | **pass** | 164 / 160 — unchanged |
| SM reference measured before editing | **pass** | 220×24 @ 418, Key State @ 446, 4px |
| BPM before-state measured (both boards) | **pass** | 7px overrun confirmed to the pixel ×2 |
| BPM neighbour stack measured before editing | **pass** | revealed the `Art L1` 10px delta (§3d) |
| Part 1 writes | **pass** | 2/2, `wrote: true`, children 36→36 ×2 |
| **Part 1 box gap vs SM = 4px** | **pass** | **4 = 4, exact** |
| **Part 1 `Art S`/`Key State` overlap** | **pass** | +7 → **−3 (cleared)** ×2 |
| settled re-read in a separate call | **pass** | per the stale-`textBounds` discipline |
| **Part 1 knock-on overlap** | **FAIL** | `Key State` vs `Art L1`/`Art L2` **−3px** ×2 — §3d, not granted |
| own page-wide sweep, 160/160 boards | **pass** | 8 chunks, 136 raw hits → **22 custody claims** |
| **Part 2 edits** | **NOT RUN** | **0 of 22 applied — §5, Level 2 content decision** |
| **AC #2 — "all 8 remaining false layers carry a true, A3-consistent string"** | **FAIL** | scope is **22**, and none accepts a substitution — §4, §5 |
| SM boards untouched | **pass** | no write issued; 44/36/44/36 unchanged |
| four `add_product_page.dart` sites verified | **pass** | 6 lines / 4 sites confirmed read-only |
| **independent design review** | **NOT RUN** | a lane that wrote 4 geometry values cannot certify them |
| docker / compose | **NEVER ISSUED** | **no command of any kind** |
| dart analyze / tests / build | n/a | no production source written, out of grant |

## 10. Files touched

```
docs/engineering/dispatch/tasks/design-correct-f5-pass2/report.md   (this file — OWNED_PATHS)
```

Nothing else. **Only the 4 granted Penpot geometry values were written.** No board renamed, moved,
deleted or re-parented; no layer created, deleted or re-parented; no `characters` assignment issued
in this pass. The pre-existing modified `apps/control_plane/test/failures/*.png` baselines were
already dirty on arrival and were not touched.

## 11. Durable discoveries (for the Manager to route; this lane persists no knowledge base)

1. **CONTRADICTION — the false-custody scope is 22 layers / 12 boards, and three consecutive
   dispatch counts (8, 16, 8) were all wrong.** The prior lane's own report already showed a count
   of 16 was wrong at 8; measured now, it is wrong at 22. Six of the 22 (`L Sub` on Product
   Credentials ×2, `L Sub` on Rotate Key ×2, `R Submit Sub` ×2) matched only needles
   (`never leaves`, `generated here`, `this device`) the prior sweep did not carry. **Generalisable:
   a census is only as good as its needle list, and a needle list derived from the prior census
   inherits its blind spots.**
2. **DESIGN_DISCOVERY — the A3-correct custody string is an EYEBROW, not a sentence, and it is a
   drop-in only for the eyebrow slot.** Eight of the 22 remaining claims are body prose, metadata
   rows keyed on a credential name, or 26-char step labels. Substituting the approved string into
   any of them deletes the layer's actual content. **"Replace the false string with the approved
   string" is only well-defined while every remaining instance is the same kind of layer** — it stops
   being well-defined the moment a sibling phrasing is found, which is the same lesson as
   discovery 1, one level up.
3. **DESIGN_DISCOVERY — fixing one of several redundant layers on the same board makes it
   self-contradict.** `BP · Rotate Key` carries the same false claim three times (`Art Sub`,
   `Tech 0`, `L Sub`). Correcting only `Art Sub` leaves one board asserting server-side generation
   and local custody simultaneously. **The unit of a custody-copy fix is the board, not the layer.**
4. **DESIGN_DISCOVERY / PROJECT_FACT — `BPM`'s stack is not `SM`'s stack.** `Art L1`/`Art L2` sit at
   parentY **456** on `BPM` versus **466** on `SM`, so a per-layer geometry fix copied from `SM`
   produces a *new* collision one layer down. **A copy approved on one platform's board is not
   thereby applicable on another's** — and neither is its geometry. The prior pass learned the first
   half of this lesson (the 220×15 box); the second half is the same lesson one row down.
5. **PROJECT_FACT — sub-pixel `textBounds` differences between boards are not a third variable.**
   BPM renders `Art S` at `h=25.0` with its text top 1.0px above the box; SM renders `h=24.5` at
   0.5px, at the same font size and box. After an exact geometric match (4px box gap on both), the
   rendered gaps are 3.0 and 3.5. **Report the difference; do not absorb it by nudging a position.**
6. **PROCESS_FACT — measure the replacement's render width before declaring a layout blocked, and
   expect your own estimate to be wrong.** I estimated a 70-char `Art Sub` would exceed its 380px
   box; the measured projection is **343.3px**. Had I reported a wrap blocker on the estimate, I
   would have escalated a non-blocker and mis-stated the scope of the human gate.
7. **RUNTIME_DISCOVERY — re-confirmed, both prior instances.** No write timeout occurred this lane
   (all calls completed), but the stale-`textBounds`-in-the-same-call behaviour reproduced exactly,
   which is why every Part 1 verification is a separate call.

## 12. Unresolved issues and blockers

- **BLOCKER-1 — Part 2 cannot proceed under this grant. `HUMAN_DECISION_REQUIRED`.** 22 false
  layers, not 8 (§4). None accepts the approved string as a substitution (§5a). The A3-consistent
  replacement copy must be **decided**, then applied by a lane holding it. Ready-made proposals for
  all 22 are in §5b (Rotate Key, priority) and §5c, each with its box-fit measured.
- **BLOCKER-2 — `Key State` now overlaps `Art L1`/`Art L2` by 3px on both BPM boards** (§3d).
  Repair requires moving `Art L1`/`Art L2` 456→466 to match SM and re-checking `Submit L` at 518 —
  a third variable I was not granted. **The `Art S`/`Key State` regression the prior pass introduced
  is fixed; the region's crowding is not fully resolved.**
- **BLOCKER-3 — the dispatch's AC #2 ("all 8 remaining false layers carry a true, A3-consistent
  string") is unsatisfiable as written** and must be restated against the measured 22 before it can
  gate anything.
- **For the decision owner — the approved `SM` geometry is now the cross-board standard.** With
  `BPM` matched to it, all three `Add Product` platforms carry the identical 80-char custody string
  in an identical 220×24 box at an identical 4px gap. Confirming that as the house pattern would
  make the next recurrence mechanical.
- **For the implementer — 4 code sites (6 lines) / 4 board-side strings** (§5c, §6). **Boards and
  build have diverged**: the eyebrow is current on the boards and stale in the build; the body is
  stale on both. Fix both paths to one decided string.
- **No independent design review.** This lane wrote four geometry values to two live shared design
  artifacts and cannot certify them. Verifying the Part 1 result and the §3d overlap against the
  `SM` reference is that review's job.

## 13. Cleanup confirmation

- [x] No Docker or Compose command issued — **none of any kind**, mutating or read-only
- [x] No process, container or compose project started by this lane
- [x] No temporary artifacts left behind
- [x] Nothing modified outside `OWNED_PATHS`, other than the 4 granted Penpot geometry values
- [x] No board renamed, moved, deleted or re-parented; no layer created or deleted
- [x] No `characters` assignment issued in this pass
- [x] Nothing committed, nothing pushed; no production source written
- [x] The four `SM` boards untouched — mobile revision 6's approval intact

## 14. Recommended next action

```
HUMAN_DECISION_REQUIRED
```

Part 1 is done and verified against the approved reference — the 4px gap and the cleared overlap
are measured, and the four `SM` boards are provably untouched. Part 2 needs a decision, not a
correction loop: **22 layers across 12 boards still assert device-side custody, and the A3-correct
copy for each must be chosen** (§5b, §5c). §3d's `Art L1` knock-on also needs a geometry grant. A
lane that decided that copy for itself would be guessing at product-security language on twelve
boards.