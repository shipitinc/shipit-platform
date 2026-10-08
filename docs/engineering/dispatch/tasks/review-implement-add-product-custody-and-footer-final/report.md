# Report — review-implement-add-product-custody-and-footer-final

```yaml
RESULT: APPROVE_CORRECTIONS
TASK_ID: review-implement-add-product-custody-and-footer-final
TASK_TYPE: re-review
FEATURE: Focused re-review of the B1 eyebrow correction (Add Product key-meta custody line)
WORKTREE: /private/tmp/shipit-implement-custody-footer
BRANCH: implement/add-product-custody-and-footer
BASE_SHA: 52d0894
HEAD_SHA: 52d0894   (UNCOMMITTED working tree — nothing committed, nothing pushed, and I created no commit)
COMMITTED: NO
```

---

## 0. Bottom line

**B1 is genuinely resolved, not merely claimed.** I decoded both shipped literals and compared them
to the approved value I extracted myself from `design-draft-f5-copy/report.md` §7 **line 299** — not to
the correction lane's account of it. Both sites are **byte-identical to the approved value in both
source form and rendered form** (sha256 `7cda897e19e679f4…`, 80 chars), and byte-identical to each
other. The escaping convention is intact (**6 `\u00b7` escapes, 0 raw `·`** — I measured it; it agrees
with the Manager). The correction-only diff is **exactly 2 lines in 1 file**, and I proved the reviewed
state survives underneath by reconstructing it and matching the recorded BEFORE bytes **exactly**.

**My prior conclusion still holds: the dispatch was the defective artifact, not the implementer.** I
re-verified all three artifacts at their exact cited lines (§2.1).

**All four gates reproduce their exact baselines, re-run by me** — 631/0, 110/0, `No issues found!`
exit 0, 190/190. No `prefer_single_quotes`. No gate regressed.

**No regressions. No blockers.** Two accuracy notes for the record (§7) — one of them a correction to
**my own prior report**, which cited the eyebrow at `:519` when it is at `:521`.

**The one thing that remains unverified is the boards, and it is not verifiable by any code lane.**
Item 6 answers it: the transitive discharge **is sufficient for the code decision**, and I say exactly
why, and exactly what is still unproven.

---

## 1. Provenance — VERIFIED

| Check | Result |
|---|---|
| `git rev-parse HEAD` (worktree) | `52d0894de7f60c04e39c1ad7d287e502d804bf9c` — **unchanged**, `== BASE_SHA` |
| `git rev-parse --abbrev-ref HEAD` | `implement/add-product-custody-and-footer` |
| `git status --porcelain --untracked-files=all` | **exactly 2** entries, both reviewed-owned; **0** untracked outside gitignored `.dart_tool` |
| `git log --oneline -n 3` | `52d0894 docs(boards): F5 copy drafted and approved…` — nothing committed on top |
| `git reflog --date=iso` | last entry `52d0894 … reset: moving to HEAD` at **15:10:53** — no reset/checkout/commit since |
| `git stash list --date=iso` | 2 entries, **both pre-existing and on other branches** (`design-correct-addproduct-mobile` 08:25:48; `design/adr-0018-amendment` 00:36:52). None from this branch or this session. |

**Content pins** (no commit exists, so the state must be named by hash):

| state | `add_product_page.dart` | `design_primitives.dart` |
|---|---|---|
| reviewed (pre-correction) | `ba161fe15d562a8eec98a1ef2a963d9536d5a75976efd8295c5780298e20e360` | `2b0c4519eaeafabf3e8d5c65db5d99e6c1e16bcbb03b99b4fc238e85f2908c20` |
| corrected (reviewed here) | `deeccbf4806351c03a9a6ae2cae7d7f2e3b0e17e0199fa8acd74740c5642ea31` | `2b0c4519…` (**unchanged — mtime 15:19:26, predating the correction at 20:02:46**) |

**main has advanced `2dd2b3e` → `f7c0dfb`** (1 commit). Verified, not assumed: the delta is **6 files,
all under `docs/engineering/dispatch/tasks/`**. `git diff --stat 52d0894..main -- apps packages docker
.github` is **empty** — **no production code moved**, so the reviewed revision does not conflict and no
rebase is needed on content grounds.

---

## 2. ITEM 1 — both sites byte-identical to the approved §7 value · **VERDICT: PASS**

I extracted the approved value **myself** from the §7 table row at `design-draft-f5-copy/report.md`
**line 299**, split the markdown row on `|`, and took the **`proposed code`** column:

```
col1: **:541-544** desktop<br>**:1037-1040** mobile
col2: 'ed25519 · created on this device · the private half stays in the keychain'     <- "current code"
col3: 'ed25519 \u00b7 generated on the server \u00b7 the private half stays in the secret manager'   <- APPROVED
col4: Key Meta / Art S — already correct on all 12 boards
```

Decoding Dart `\uXXXX` escapes on **both** sides and comparing bytes:

```
APPROVED  rendered : ed25519 · generated on the server · the private half stays in the secret manager
APPROVED  charlen  : 80
APPROVED  sha256   : 7cda897e19e679f4df96f3d0a096f87a2737782cb14eecd751aff3f5a57aa01d

line  521  source : ed25519 \u00b7 generated on the server \u00b7 the private half stays in the secret manager
line  521  sha256 : 7cda897e19e679f4df96f3d0a096f87a2737782cb14eecd751aff3f5a57aa01d
line  521  == APPROVED rendered : True      == APPROVED source : True

line 1016  source : (identical to 521)
line 1016  == APPROVED rendered : True      == APPROVED source : True
line  521  == line 1016 (byte-identical)   : True   (each 109 bytes, line sha 9bb7bb1e…)
```

**Comparison is byte-level on decoded strings, not an eyeball.** It matches in **both** the source form
(so the escapes are right too) and the rendered form.

**Base-coordinate cross-check that the right slot was fixed.** The diff hunks are
`@@ -542 +521 @@` and `@@ -1038 +1016 @@` — and `:542` desktop / `:1038` mobile are **exactly** the
coordinates §7:299 (`:541-544` / `:1037-1040`) and `design-apply-f5-copy/report-r3.md:486` designate for
this eyebrow slot. The correction landed on the designated lines, not merely on a matching string.

**My prior conclusion re-verified — the dispatch was wrong, not the implementer.** All three artifacts
re-read at their exact lines:

| Artifact · line | What it says (verbatim) | Verdict |
|---|---|---|
| `design-draft-f5-copy/report.md` **:299** | proposed code = the **80-char with `ed25519`**; counterpart `Key Meta` / `Art S` — *"already correct on all 12 boards"* | this slot's required value |
| `design-apply-f5-copy/report-r3.md` **:486** (§9.3) | `eyebrow ×2` \| `:542` desktop · `:1038` mobile \| → `'ed25519 · generated on the server · the private half stays in the secret manager'` | independent re-verification |
| `design-apply-f5-copy/report-r3.md` **:299** | `\| **H** \| Generated on the server · the private half stays in the secret manager \| Art Sub ×2 \|` | the 70-char is **string H on `Art Sub`**, a different layer |
| `design-draft-f5-copy/report.md` **:215** (§4a) | `\| Art Sub (eyebrow, **380×18**, Sans 11, @410,496) \| Generated here · the private half never leaves the keychain \| Generated on the server · … \|` | the 70-char's home: `Art Sub` on `BP · Rotate Key`, whose **current** text is a different sentence |
| `design-draft-f5-copy/report.md` **:181** (§3) | `BP · Rotate Key · Dark/Light` \| `Art Sub` \| … \| 289.34 → **340.29** \| 380×18 \| **FITS** | the 340px figure is `Art Sub`'s |

**Confirmed: the 380px box and the fit warning belong to `BP · Rotate Key` / `Art Sub`, not to this
slot.** The dispatch conflated two rows of the source it cited. The implementer was right to escalate.

**The displaced value is fully gone:** 0 occurrences of the 94-byte literal, 0 of
`"Generated on the server"` anywhere in the file, 0 of `"created on this device"`, 0 of
`"stays in the keychain"`. `secret manager` now appears 4× — `:459` and `:521` (desktop),
`:957` and `:1016` (mobile).

---

## 3. ITEM 2 — escaping convention preserved · **VERDICT: PASS (6 escapes, 0 raw middots)**

Measured by me, three independent ways:

| measure | reviewed | corrected |
|---|---|---|
| `\u00b7` occurrences (byte count of the 6-char sequence) | **4** | **6** |
| `\u00b7` occurrences (regex, on decoded text) | 4 | **6** |
| **raw U+00B7 `·` characters anywhere in the file** | **0** | **0** |

Per-line distribution in the corrected file: `{511: 1, 521: 2, 1006: 1, 1016: 2}` — the two extra
escapes are one per site, exactly as claimed, and `:511`/`:1006` carry the pre-existing
`DEPLOY KEY  \u00b7  THIS PRODUCT ONLY` MicroLabel. **This agrees with the Manager's independent
measurement (6 occurrences, 0 raw middots).** No mixed convention introduced.

---

## 4. ITEM 3 — nothing else changed · **VERDICT: PASS**, with one disclosure gap in the lane's report

### 4.1 The reviewed state survives underneath — proven, not asserted

I reconstructed the reviewed state by replacing the literal source at `:521`/`:1016` with the 94-byte
BEFORE line recorded in the correction report, then compared **the reconstruction's raw hex** against
that report's recorded BEFORE hex:

```
reconstructed :521 hex : 2020…2020 47656e657261746564206f6e20746865207365727665 72205c7530306237
                2074686520707269766174652068616c6620737461797320696e2074686520
                736563726574206d616e61676572272c
report §3 BEFORE hex : 2020…2020 47656e657261746564206f6e20746865207365727665 72205c7530306237
                2074686520707269766174652068616c6620737461797320696e2074686520
                736563726574206d616e61676572272c
HEX MATCH               : True          reconstructed line length: 94  (AFTER: 109)
:521 == :1016 in the reviewed reconstruction : True
rendered reviewed value : Generated on the server · the private half stays in the secret manager (70 chars)
                        — matches EXACTLY what my prior review recorded as shipped
```

### 4.2 The authoritative correction-only diff — 2 lines

```diff
--- REVIEWED(add_product_page.dart)
+++ CORRECTED(add_product_page.dart)
@@ -518,7 +518,7 @@
               const SizedBox(height: 8),
               Text(
-                'Generated on the server \u00b7 the private half stays in the secret manager',
+                'ed25519 \u00b7 generated on the server \u00b7 the private half stays in the secret manager',
                 style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
               ),
@@ -1013,7 +1013,7 @@
               const SizedBox(height: 8),
               Text(
-                'Generated on the server \u00b7 the private half stays in the secret manager',
+                'ed25519 \u00b7 generated on the server \u00b7 the private half stays in the secret manager',
                 style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
               ),
```

| proof | result |
|---|---|
| lines differing, reviewed vs corrected | **`[521, 1016]`** — exactly 2 |
| line count, both states | `wc -l` **1095 / 1095**, unchanged; (the lane's "1096/1096" counts split elements — same convention I get, so no discrepancy of substance) |
| `git diff --stat 52d0894` | **`2 files changed, 42 insertions(+), 42 deletions(-)`** — matches my prior pass's `+42 −42` |
| per-file numstat | `add_product_page.dart` 8/30 · `design_primitives.dart` 34/12 |
| reconstruction's own diff vs base | 8/30 — identical, so the diffstat invariance is explained (the lane explained this too, correctly) |
| hunk ranges vs base | `314-315, 317-319, 374-389, 480-481, 542, 926-928, 979-980, 1038` — **identical to the ranges I recorded in my prior review** |
| `git status --porcelain` | 2 entries, same 2 paths; **0** new paths |

### 4.3 Disclosure gap (L3-class, not a defect) — the correction is **not purely additive**

Per site the correction made **two** byte-level changes:
1. prepended the 15-byte `ed25519 \u00b7 `, and
2. **lowercased `Generated` → `generated`** — which §7:299 requires (`ed25519 \u00b7 generated on the
   server …`).

The lane's report says *"Delta: exactly `ed25519 \u00b7 ` = 15 bytes, twice"* and *"delta = the 15 bytes …
per site, 30 bytes total"*. The **arithmetic is right** (the case change is value-only, same length, so
the net length delta is +15/site and +30/file, which is what I measured) but the **wording omits a
second change it made**. Recorded so the next lane does not assume prefix-only. The lowercase `g` is
**required** for the byte-identity with §7:299 that I verified in §2 — so the change is right, only its
accounting sentence is incomplete.

### 4.4 No reset or stash flattened the reviewed work

`git reflog` shows no entry after `15:10:53` (a `reset: moving to HEAD` from the implementer's own
session, recorded before `design_primitives.dart` was written at 15:19:26). No commit, no checkout, no
stash on this branch. The two stash entries belong to other branches and predate this lane by hours.
**The reviewed work is demonstrably intact underneath — its reconstruction matches the recorded BEFORE
bytes exactly, and its every structural invariant still holds (§5).**

---

## 5. ITEM 4 — everything else untouched · **VERDICT: PASS** (re-pinned from my own prior-pass evidence, not from the lane's account)

| area | prior verdict | my re-verification at the corrected HEAD |
|---|---|---|
| `:459` / `:957` Ev Body pair | PASS | rendered concatenation **byte-identical** to approved §4b string A (`It clones over SSH. The private half stays in the secret manager — never shown, logged or stored.`); desktop == mobile; `\u2014` escape preserved, **0 raw em-dash bytes**; `device's keychain` **0** occurrences, `keychain` **0** occurrences in the file |
| `:389` mid-page prose — **"the trap"** | PASS | md5 of working lines 385-391 (join + trailing newline) = **`f554ab3d7eb520546d66108afe440d2e`** = the value **I recorded in my prior review**, and = md5 of base lines 406-412 under the same convention → **byte-identical, offset −21**. The string occurs **3× in base** (`:318`, `:410`, `:927`) and **1× in the tree** (`:389`), and `:389` carries the `until you ` line break. **The trap is still safe.** |
| base 409-411 overlap | NONE | re-parsed the hunk headers programmatically: intersection with base `409-411` is **NONE** |
| `_buildFooter` | 0 | **0** occurrences |
| structure | intact | `_buildBreadcrumb` `:330`, `_buildH1` `:342`, `_buildStatusRow` `:356` all intact; `class _DesktopAddProduct` closes at `:369`; desktop `TechnicalDetails(` at `:314` (defaults, 0 new args); the single new-args call site at `:904-906` (`showRule: false`, `disclosureAlignment: DisclosureAlignment.start`) |
| `design_primitives.dart` | PASS | sha256 `2b0c4519…`, **mtime 15:19:26 — predating the correction (20:02:46)**. Full diff vs base matches exactly what I cleared: `enum DisclosureAlignment { start, end }`; constructor `showRule = true` / `disclosureAlignment = DisclosureAlignment.end`; two doc'd fields; `noteStyle` hoist `:401`; `if (widget.showRule) const ContentRule()` `:418`; **`Expanded` retained at `:426` inside the `end` branch**; `Flexible` on the `start` branch; `InlineLink` unconditional `:433` |
| call-site census | 17/1/16/13 | unchanged HEAD↔tree: **17** raw `TechnicalDetails(` matches, **1** class decl, **16** construction call sites, **14** files with matches (**13** feature files with call sites). `showRule` / `disclosureAlignment` / `DisclosureAlignment` appear **only** in `add_product_page.dart` + `design_primitives.dart`. Remaining `note:` sites = **7**, exactly the 7 I listed |
| test files | none | `git status --porcelain -- apps/control_plane/test` → **0 entries**. `@Ignore` **0** files, `@Skip` **0** files, `skip:` **0** lines |
| prohibited paths | clean | `apps/server` **0**, `packages` **0**, `docker` **0**, `.github` **0**, `.decisions` **0**, `docs/adr` **0**, `WORK_STATE.md` **0**, `LANES.md` **0**, `.claude` **0**, `.junie` **0**, `.opencode` **0**, `framework-manifest.yaml` **0** |

**Docker / Compose commands by me: ZERO** — none issued, mutating or read-only-looking. Not `info`,
`ps`, `logs`, `config`, `down`, `up`, `prune`. **I did not run `make clean`, `make test-env-down`,
`make e2e-down`, or any `docker compose …`. This repository has already lost its QA database
irrecoverably to a lane running `docker compose -f docker/compose.qa.yaml down -v --rmi local`; I did
not test that rule and did not come near it.** Before running `flutter test` I confirmed the suite
spawns no processes (`Process.run` / `Process.start` / `exec(` → **0** hits) and its only
docker/compose mentions are **3 string literals** in `product_detail_page_test.dart` (`:372`, `:374`,
`:379`) — the same 3 my prior pass found.

---

## 6. ITEM 5 — gates re-run by me · **ALL PASS, exact baselines**

`dart pub get` was run at the **repository root first**, per the known fresh-worktree hazard. I did not
chase anything into `apps/server`.

| Command | Status | Evidence — exact output this session |
|---|---|---|
| `dart pub get` (repo root) | pass | `Got dependencies!` |
| `dart format --output=none --set-exit-if-changed .` (root) | **pass** | `Formatted 631 files (0 changed) in 9.51 seconds.` — **exit 0**. Baseline **631/0 exactly reproduced.** |
| `dart format --output=none --set-exit-if-changed lib test` | **pass** | `Formatted 110 files (0 changed) in 2.49 seconds.` — **exit 0**. Baseline **110/0 reproduced.** |
| `cd apps/control_plane && flutter analyze` | **pass** | `No issues found! (ran in 8.7s)` — **exit 0** (captured with `; echo $?` → `0`). **0 errors, 0 infos.** |
| `cd apps/control_plane && flutter test` | **pass** | `01:03 +190: All tests passed!` — **exit 0**. Baseline **190/190 exactly reproduced.** |
| post-gate `apps/server` churn | none | `git status --porcelain -- apps/server` → **0 entries** after `pub get` + both format gates |
| `make test-integration` | NOT_RUN | Not applicable — a 2-line string-literal correction with no data path. |
| Docker / Compose (any command) | **ZERO issued** | — |
| `build` | n/a | A string literal produces no buildable artifact. |
| runtime / visual | **NOT_RUN** | No runtime, browser or visual evidence. **I make no claim that the rendered eyebrow matches a board** — see §8. |

**`prefer_single_quotes` did not fire, as predicted and now confirmed empirically:** the restored string
contains **no apostrophe** and both sites already used single-quote delimiters, and `flutter analyze`
returned `No issues found!` with **0 infos** — the previous pass's delimiter fix is not undone.

**The 109-char lines pass the format gate** (`631 files (0 changed)`), confirming the correction lane's
D1: `dart_style` will not split a single string literal to satisfy page width. So line length was never
a reason to prefer the shorter 70-char variant.

**No test was weakened, skipped, `@Ignore`d or deleted.** Zero test files changed. No coverage removed.

---

## 7. Item-by-item verdict table

| # | Item | Verdict |
|---|---|---|
| 1 | Both sites byte-identical to the approved §7:299 value (source **and** rendered) | **PASS** |
| 2 | Escaping convention — 6 `\u00b7`, 0 raw `·` (was 4) | **PASS** |
| 3 | Nothing else changed — lines differing `[521, 1016]`, reviewed state survives (hex-exact) | **PASS** |
| 4 | `:459`/`:957`, `:389`, `:409-411`, `design_primitives.dart`, tests, `apps/server/**` untouched | **PASS** |
| 5 | Gates re-run by me at 631/0, 110/0, analyze 0-exit, 190/190 | **PASS** |
| 6 | The fit question (board measurement of `Key Meta` / `Art S`) | **TRANSITIVE DISCHARGE IS SUFFICIENT for the code decision**; board contents remain **unverified by anyone** — see §8 |
| 7 | M1, the coverage gap | **FOLLOW-UP, NOT a blocker for this change** — see §9 |

---

## 8. ITEM 6 — the fit question: is the transitive discharge sufficient? · **YES for the code side**

My prior review held B1 open partly because it owed an answer on fit: the 380px box belongs to a
different board, and the code's `Text` wraps with viewport-dependent width. The correction lane
discharged this **transitively** — §7 asserts the boards already carry these 80 characters — and said so
plainly rather than claiming a measurement. **I judge that sufficient, for four reasons, three of which
I verified in the source.**

**(a) It is a restoration, not an invention.** The shipped value is the one **two** artifacts designate
for **this exact slot** (verified at §2). Nothing was chosen; the approved value was written back. A
restoration cannot introduce an unapproved fit risk, because the approved value is by definition the one
the design source measured or asserted for that slot.

**(b) The build is wrap-safe at both lengths — verified.** The eyebrow `Text` (`:520-523` desktop,
`:1015-1018` mobile) has **no `maxLines` and no `overflow`**, and its parent is a `Column` with
`crossAxisAlignment: CrossAxisAlignment.start`. Extra width therefore **wraps; it does not overflow.**
`ShipItType.monoMeta` is **Mono 10 / 400 with no `letterSpacing`** (`design_tokens.dart:516`), i.e. ≈6px
per character: 70 chars ≈ 420px, 80 chars ≈ 480px. Both exceed a phone content width (~320-390px), so
**mobile already wrapped to 2 lines before the correction and still wraps to 2 lines after.** The
correction **cannot introduce a new layout failure mode in the build** — the line count on the narrowest
viewport is unchanged. Desktop has ample width either way.

**(c) The asymmetry is what makes a transitive argument safe here.** If §7's *"already correct on all 12
boards"* is **true**, the boards already render these 80 characters on `Key Meta` / `Art S`, so it fits
that layer by construction. If it is **false**, the approved value is *still* the value to ship and the
divergence is a **board-side** defect to fix on the boards. **Shipping §7's value is correct under both
hypotheses; shipping the 70-char was wrong under both** — which is exactly why the code decision does
not depend on resolving the board question. (The 70-char's own home, `Art Sub` on `BP · Rotate Key`, was
measured at 340.29px against a 380px box and marked `FITS` — a fit verdict for a layer that is not this
one, and it cannot be transferred in either direction.)

**(d) The only true unknown is board content, and no code lane can reach it.**

### What remains unverified — stated plainly

1. **The boards' actual current `Key Meta` / `Art S` text is asserted, never read.** §7:299 asserts
   *"already correct on all 12 boards"*. No lane in this work item had Penpot access — not the
   implementer, not the correction lane, not me. This is an **assertion-level** claim. The human must
   confirm it before treating build and boards as converged.
2. **`Key Meta` / `Art S` box geometry is unmeasured, and unmeasurable from the artifacts.** No box
   measurement for that layer exists in the draft. The only measurement in the F5 set (380×18,
   `Art Sub`, `BP · Rotate Key`) belongs to a different board and layer. Given (b), this is a **visual
   fidelity** question, not a build-correctness one.
3. **No rendered/visual evidence exists** for this change. My Item 1 and (b) findings are
   **source-derived**, not rendered-confirmed. I make no claim that the rendered eyebrow matches any
   board.

**This is a design/human confirmation item, not a code blocker** — and the correction lane was right to
keep it in its §8.1/§8.2 rather than claim it. It should be recorded as such rather than closed.

---

## 9. ITEM 7 — M1, the coverage gap · **FOLLOW-UP, NOT a blocker for THIS change**

Re-verified independently, unchanged: **26** `*_test.dart` files; **0** mention `add_product_page`,
**0** mention `design_primitives`, **0** mention `TechnicalDetails`, **0** `showRule`, **0**
`disclosureAlignment`, **0** `ContentRule`; **0** import either file.

**My prior point stands and is now re-confirmed from the source:** `TechnicalDetails`' class body
(`design_primitives.dart:357-397`) contains **0** references to `Bloc` or `Repository`. It is a
self-contained `StatefulWidget`; pumping it needs no bloc, no fixture and no new architecture, so the
stated reason for having no coverage does not apply to it.

**Why it is a follow-up and not a blocker here — three reasons:**

1. **The code is correct today.** Re-verified again in §5: `Expanded` intact on the `end` path (`:426`),
   `showRule: false` reachable and genuinely suppressing (`:418`), defaults reproduce today's rendering
   byte-for-byte on all 16 other call sites. M1 is about a **missing guard**, not a live bug.
2. **This change cannot regress it.** The correction-only diff is **2 lines in
   `add_product_page.dart`** — a different file from the primitive, and a string literal that touches no
   layout. Holding M1 open would block a change that is incapable of affecting the invariant it guards.
3. **The blocking relationship runs the other way.** M1's guard should assert the **final** state of the
   primitive; it is unblocked now that B1 is settled.

**So: M1 stays open as a follow-up, unchanged, at the same severity (MEDIUM), with the same concrete
ask** — `apps/control_plane/test/shared/technical_details_test.dart`, ~40 lines, no bloc, no golden, no
new architecture: (1) default `TechnicalDetails(lines: […])` renders **one** `ContentRule`; (2)
`showRule: false` renders **zero**; (3) default + null note → the `Show technical details` link's right
edge ≈ the widget's right edge (**the `Expanded` regression guard**); (4) `DisclosureAlignment.start` →
its left edge ≈ the widget's left edge.

---

## 10. Accuracy notes for the record (L3-class; no effect on the code)

1. **Correction to MY OWN prior report.** I cited the eyebrow at **`:519`**; it is at **`:521`**. The
   base-coordinate arithmetic pins this: the diff hunk is `@@ -542 +521 @@` (offset −21), and the −21
   offset is independently confirmed by the trap block's identical md5 at base 406-412 / working 385-391.
   `:519` was my citation error; the correction lane's `:521` is right. Recorded so the next lane does
   not inherit it.
2. **Correction lane's report, §3/§16 — understated delta.** The correction is prefix + case change, not
   prefix only (see §4.3). Arithmetic correct, wording incomplete.
3. **Correction lane's report, §8.4 — "0".** `apps/control_plane/test/failures/**` holds **80 tracked
   baseline PNGs, 0 dirty**. Both the dispatch's figure ("48 dirty binaries") and the lane's ("0") are
   wrong; the accurate statement is **80 tracked, 0 dirty**. Inert for this change — nothing was staged,
   reverted or cleaned there by either lane — but recorded so the next lane starts from the truth.
4. **Correction lane's report, §1 — line count.** "1096 / 1096" is split-element counting; `wc -l` says
   **1095**. Both unchanged, so no discrepancy of substance.
5. **The correction lane's own `CORRECTED_FROM_HEAD` label** points at a hash that is the *corrected*
   file; it flags this inline, and I supplied the missing reviewed-state pin
   (`ba161fe15d562a8e…`) in §1 so both states are now named unambiguously.

---

## 11. What I did NOT review

Stated explicitly:

- **Anything my prior pass already cleared**, beyond re-pinning it (§5). I did not re-review the whole
  change: the `TechnicalDetails` design against `.decisions/27ea6536`, the `_buildFooter` deletion
  reasoning, the implementer's process, or the copy decision's merits — except where the correction's
  2-line diff could have touched them, which I verified it did not.
- **The boards.** No Penpot access, no board read, no board edit. I verified what the **artifacts
  assert**, which is a different claim from what the boards contain. I cannot confirm that all 12
  `Add Product` boards carry the 80-char string, nor the `Key Meta` / `Art S` geometry.
- **Rendered behaviour.** No runtime, no browser, no visual capture. Item 1 and §8(b) are
  source-derived. I verified widget/wrap semantics from the pinned Flutter SDK's layout rules and from
  the absence of `maxLines`/`overflow`, which is strong for *whether a string can overflow* and
  worthless for *whether it matches a board*.
- **The Manager's ruling itself.** I verified the ruling resolves B1 against the cited sources; I did not
  re-open the decision to commission a different fitting variant, because the restored value is the
  approved one and (b) shows the length is not a build risk.
- **The other 15 call sites' screens.** I relied on default-path equivalence plus the re-measured
  census (17/1/16, 13 files), which is the correct basis; I did not review each screen's layout.
- **L1 (vertical rhythm) and L2 (`noteStyle` computed unconditionally)** — unchanged by the correction and
  already judged defensible/immaterial in my prior pass. Not re-litigated.
- **`9417f8bf` A3 reachability / substrate.** Untouched here; the change remains A3-*consistent* copy.
- **`AGENTS.md` §13 / ADR 0018 credential mechanics.** I confirmed again that no secret value appears
  anywhere in the diff — every string is prose.
- **The rest of the work item** (`design/add-product`, `implement/add-product`, the sibling worktrees).
  Out of scope for a focused re-review.

---

## 12. Validation results

| Command | Status | Evidence / note |
|---------|--------|-----------------|
| `dart pub get` (repo root) | pass | `Got dependencies!` — run first per the fresh-worktree hazard |
| `dart format --output=none --set-exit-if-changed .` | pass | `Formatted 631 files (0 changed) in 9.51 seconds.` exit 0 |
| `cd apps/control_plane && dart format --output=none --set-exit-if-changed lib test` | pass | `Formatted 110 files (0 changed) in 2.49 seconds.` exit 0 |
| `cd apps/control_plane && flutter analyze` | pass | `No issues found! (ran in 8.7s)` exit 0 |
| `cd apps/control_plane && flutter test` | pass | `01:03 +190: All tests passed!` exit 0 |
| `make test-integration` | NOT_RUN | not applicable to a string-literal correction |
| Docker / Compose (any) | NOT_RUN | **ZERO commands issued** |
| runtime / visual | NOT_RUN | no visual claim made |

---

## 13. Evidence (revision-pinned)

```yaml
EVIDENCE_REVISION: 52d0894de7f60c04e39c1ad7d287e502d804bf9c + uncommitted working tree at
  /private/tmp/shipit-implement-custody-footer  (branch implement/add-product-custody-and-footer)
  add_product_page.dart    sha256 deeccbf4806351c03a9a6ae2cae7d7f2e3b0e17e0199fa8acd74740c5642ea31
  design_primitives.dart   sha256 2b0c4519eaeafabf3e8d5c65db5d99e6c1e16bcbb03b99b4fc238e85f2908c20
  reviewed-state pin (reconstructed, verified byte-exact):
    add_product_page.dart sha256 ba161fe15d562a8eec98a1ef2a963d9536d5a75976efd8295c5780298e20e360
  (no commit exists; HEAD == BASE_SHA == 52d0894; nothing committed or pushed)
BUILD_COMMAND: n/a — no buildable artifact
SERVE_OR_RUN_COMMAND: n/a — no runtime exercised
ENVIRONMENT / BASE_URL: local worktree, Dart SDK from /Users/alkebut/fvm/default/bin
ARTIFACTS:
  - corrected eyebrow, desktop: apps/control_plane/lib/features/products/add_product_page.dart:521
  - corrected eyebrow, mobile:  apps/control_plane/lib/features/products/add_product_page.dart:1016
  - approved source of truth: docs/engineering/dispatch/tasks/design-draft-f5-copy/report.md §7 line 299
  - corroboration: design-apply-f5-copy/report-r3.md §9.3 line 486; registry line 299 (string H → Art Sub ×2);
    design-draft-f5-copy/report.md §4a line 215 and §3 line 181 (the 380×18 Art Sub box)
  - verdict being corrected: docs/engineering/dispatch/tasks/review-implement-add-product-custody-and-footer/report.md
  - correction report: docs/engineering/dispatch/tasks/correct-add-product-eyebrow-copy/report.md
  - this report
```

---

## 14. Documentation updated

```text
docs/engineering/dispatch/tasks/review-implement-add-product-custody-and-footer-final/report.md   (this report — the only file created)
```

---

## 15. Cleanup confirmation

- [x] **ZERO Docker or Compose commands issued** — none, mutating or read-only-looking. Not `info`, `ps`,
      `logs`, `config`, `down`, `up`, `prune`. **This repository has already lost its QA database
      irrecoverably to a lane running `docker compose -f docker/compose.qa.yaml down -v --rmi local`;
      I did not test that rule.**
- [x] No process, container or compose project started; nothing left running.
- [x] `make test-integration` not run — not needed; it is the only sanctioned way to obtain a real
      database, and I did not need one.
- [x] **No production file modified.** I hold no `Write`/`Edit` tool; the only file I created is this
      report. I did not touch either lane's report, the reviewed worktree, or any tracked file. Scratch
      scripts were written only to the session temp dir
      (`/var/folders/.../T/opencode/focused-rereview/`), outside the repository.
- [x] **Nothing committed, nothing pushed.** The reviewed work still has **no commit**, and I created
      none.
- [x] The reviewed worktree's state is exactly as I found it: 2 modified files, both owned; 0 untracked.
- [x] I did not approve the correction lane's work, and I did not re-approve my own prior pass — I
      re-derived every claim in §2 and §5 from source.

---

## 16. Safe parallelism

```yaml
SAFE_PARALLEL_WORK:
  - M1's test file — apps/control_plane/test/shared/technical_details_test.dart — reads the primitive and
    writes only under test/, so it does not overlap either owned lib file; it asserts the FINAL state,
    which the correction did not change
  - L1's vertical-rhythm confirmation against board coordinates (read-only on the boards)
  - the design/human confirmation of the boards' actual Key Meta / Art S text (item 6) — needs board
    access, not code access
PROHIBITED_PARALLEL_WORK:
  - any lane writing apps/control_plane/lib/features/products/add_product_page.dart — the eyebrow is now
    correct and independently verified at :521/:1016; a second writer would race a settled value
  - any lane writing apps/control_plane/lib/shared/design_primitives.dart — untouched but still the
    subject of open follow-up M1; M1's guard should land against the final state
  - any Penpot board edit to the Add Product footer or Key Meta — G-18 ownership must be granted first
```

---

## 17. The no-commit question

The tree still has **no commit**, and it blocked integration once already in this work item. **I did not
create one, and I am not asking the correction lane to have created one** — it correctly refused.

- **It does not block this approval.** An approval is a statement about a *state*, and I have pinned
  that state by content hash in §13. The corrected state is unambiguous and reproducible.
- **It does block the integrator.** The `integrator` lane merges or cherry-picks a **commit**; there is
  nothing to point at. Provenance by hash alone is not merge provenance.
- **Minimum remaining step, before integration:** an authorized lane commits the two-file change, and the
  resulting commit's tree must hash to
  `add_product_page.dart = deeccbf4806351c03a9a6ae2cae7d7f2e3b0e17e0199fa8acd74740c5642ea31` and
  `design_primitives.dart = 2b0c4519eaeafabf3e8d5c65db5d99e6c1e16bcbb03b99b4fc238e85f2908c20`.
  If it does not, this approval does not apply to it.
- **No rebase is needed on content grounds**: `main` advanced `2dd2b3e` → `f7c0dfb`, but that delta is
  **6 docs files under `docs/engineering/dispatch/tasks/`** and **zero** production code.
- **M1 does not need to land first** (see §9); it is a follow-up, not a gate on this change.

---

## 18. Recommended next action

`MERGE` — for the integrator, once the two-file change is committed by an authorized lane with the
content hashes in §13 verified. Two non-blocking items travel with it: **M1** as a follow-up test file
(§9), and the **board confirmation** of `Key Meta` / `Art S` as a design/human item (§8).

---

## 19. Required structured result (verbatim block from `.agents/agents/focused-reviewer.md`)

```
RESULT: APPROVE_CORRECTIONS

REVIEWED_HEAD:
  52d0894de7f60c04e39c1ad7d287e502d804bf9c + uncommitted working tree at
  /private/tmp/shipit-implement-custody-footer (branch implement/add-product-custody-and-footer).
  HEAD == BASE_SHA; 2 owned files modified; nothing committed or pushed; I created no commit.
  Content pins (the state cannot be named by SHA, so it is named by hash):
    add_product_page.dart    sha256 deeccbf4806351c03a9a6ae2cae7d7f2e3b0e17e0199fa8acd74740c5642ea31
    design_primitives.dart   sha256 2b0c4519eaeafabf3e8d5c65db5d99e6c1e16bcbb03b99b4fc238e85f2908c20
    reviewed state (reconstructed and verified byte-exact against the recorded BEFORE bytes):
      add_product_page.dart sha256 ba161fe15d562a8eec98a1ef2a963d9536d5a75976efd8295c5780298e20e360
  main = f7c0dfb (advanced from 2dd2b3e by 1 commit): verified bookkeeping-only — 6 files, all under
  docs/engineering/dispatch/tasks/, zero production code moved, no rebase needed on content grounds.

FINDINGS_REVIEWED:
  B1 — the Add Product key-meta eyebrow (the single DO_NOT_MERGE blocker). RESOLVED, verified from
  source and not from the correction lane's account.
    ITEM 1 PASS — I extracted the approved value myself from design-draft-f5-copy/report.md §7 line 299
      (the 'proposed code' column), decoded Dart \uXXXX escapes on both sides and compared bytes. Both
      add_product_page.dart:521 (desktop) and :1016 (mobile) are BYTE-IDENTICAL to the approved value in
      BOTH source form and rendered form: 80 chars, sha256
      7cda897e19e679f4df96f3d0a096f87a2737782cb14eecd751aff3f5a57aa01d at both sites, and the two sites
      are byte-identical to each other (109 bytes each). The diff hunks @@ -542 +521 @@ and
      @@ -1038 +1016 @@ land on exactly the coordinates §7:299 and r3:486 designate for this slot.
      The displaced 70-char value now has 0 occurrences. My prior conclusion re-affirmed and re-verified:
      the DISPATCH was the defective artifact, not the implementer — r3:299 registers the 70-char as
      string H scoped to 'Art Sub' ×2, and draft §4a:215 / §3:181 show that value belongs to
      'BP · Rotate Key' 'Art Sub' (380×18, current text 'Generated here · …'), measured 340.29px FITS.
    ITEM 2 PASS — escaping convention preserved. Measured three ways: \u00b7 occurrences 4 -> 6 (byte
      count and regex agree), raw U+00B7 '·' characters = 0. Per-line {511:1, 521:2, 1006:1, 1016:2}.
      Agrees with the Manager's independent measurement (6 occurrences, 0 raw middots).
    ITEM 3 PASS — nothing else changed. I reconstructed the reviewed state by substituting the recorded
      94-byte BEFORE line at the two sites; the reconstruction's raw hex matches that recorded BEFORE hex
      BYTE-FOR-BYTE at both sites, and the reconstruction differs from the corrected state in EXACTLY
      lines [521, 1016]. Real line count unchanged (wc -l 1095 both; the lane's '1096' is split-element
      counting). git diff --stat vs base unchanged at 2 files / +42 / -42, numstat 8/30 and 34/12. Hunk
      ranges vs base identical to my prior review (314-315, 317-319, 374-389, 480-481, 542, 926-928,
      979-980, 1038). The reviewed state survives underneath: reflog has no entry after 15:10:53, the 2
      stash entries are pre-existing and on other branches, nothing was committed, and no reset/stash/
      checkout flattened anything. DISCLOSURE GAP (L3, not a defect): the correction is not purely
      additive — per site it also lowercased 'Generated' -> 'generated', which §7:299 requires; the lane's
      arithmetic (+15 bytes/site) is right but its wording ("exactly the 15-byte prefix") omits the case
      change.
    ITEM 4 PASS — everything previously cleared re-verified from source: :459/:957 Ev Body pair
      byte-identical to approved §4b string A (desktop == mobile, \u2014 escape kept, 0 raw em-dash bytes);
      :389 mid-page prose md5 f554ab3d7eb520546d66108afe440d2e == my prior review's value == base
      406-412 under the same convention (offset -21), string 3x in base and 1x in the tree, :389 carries
      the 'until you ' break — the trap is still safe; no hunk intersects base 409-411; _buildFooter = 0;
      structure intact (:330/:342/:356/:369/:314/:904-906); design_primitives.dart untouched (hash
      2b0c4519…, mtime 15:19:26 PREDATING the correction at 20:02:46) with the Expanded invariant intact
      at :426 inside the DisclosureAlignment.end branch; census unchanged HEAD<->tree (17 raw matches,
      1 decl, 16 call sites, 13 feature files); showRule/disclosureAlignment confined to the two files;
      7 remaining note: sites; ZERO test files changed; @Ignore/@Skip/skip: all 0;
      apps/server, packages, docker, .github, .decisions, docs/adr, WORK_STATE.md, LANES.md, .claude,
      .junie, .opencode, framework-manifest.yaml all 0 entries; 0 untracked outside gitignored .dart_tool.
    ITEM 5 PASS — all four gates re-run by me at the corrected HEAD after dart pub get at the repo root:
      format root 'Formatted 631 files (0 changed)' exit 0 (baseline 631/0 exact); scoped lib test
      'Formatted 110 files (0 changed)' exit 0; flutter analyze 'No issues found!' exit 0 (0 errors,
      0 infos — prefer_single_quotes did not fire, as the string has no apostrophe and both sites
      already used single-quote delimiters); flutter test '01:03 +190: All tests passed!' exit 0 (190/190
      exact). No apps/server churn after pub get + format. The 109-char lines pass the format gate,
      confirming dart_style will not split a string literal — so line length was never a reason to prefer
      the shorter variant.
    ITEM 6 — the fit question. THE TRANSITIVE DISCHARGE IS SUFFICIENT FOR THE CODE DECISION, and I say
      why: (a) this is a restoration of the value two artifacts designate for this slot, not an invented
      variant; (b) the build is wrap-safe at both lengths — verified: the eyebrow Text has no maxLines and
      no overflow and its parent Column is crossAxisAlignment.start, and monoMeta is Mono 10/400 with no
      letterSpacing (~6px/char, so 70 chars ~420px and 80 chars ~480px, both exceeding a phone content
      width) — mobile already wrapped to 2 lines before the correction and still wraps to 2 lines after,
      so the correction cannot introduce a new layout failure mode; (c) the deciding asymmetry: if §7's
      'already correct on all 12 boards' is TRUE the boards already render those 80 characters so it fits
      by construction, and if it is FALSE the approved value is still the value to ship and the
      divergence is a board-side defect — shipping §7's value is correct under BOTH hypotheses, while
      shipping the 70-char was wrong under both; (d) the only true unknown is board content, which no code
      lane can reach.
      STILL UNVERIFIED, stated plainly: (i) the boards' actual current Key Meta / Art S text is asserted
      by §7:299 and never read — no lane in this work item had Penpot access; (ii) that layer's box
      geometry is unmeasured and unmeasurable from the artifacts (the only F5 measurement, 380×18, is
      Art Sub on BP · Rotate Key); (iii) no rendered or visual evidence exists — my findings are
      source-derived, not rendered-confirmed, and I make no claim that the rendered eyebrow matches a
      board. This remains a design/human confirmation item and must be recorded as such, not closed.
    ITEM 7 — M1. FOLLOW-UP, NOT A BLOCKER FOR THIS CHANGE. Re-verified independently: 26 _test.dart files,
      0 mention add_product_page / design_primitives / TechnicalDetails / showRule / disclosureAlignment /
      ContentRule, 0 import either file. My prior point re-confirmed from source: TechnicalDetails' class
      body (design_primitives.dart:357-397) contains 0 Bloc/Repository references — a self-contained
      StatefulWidget, so the stated reason for no coverage does not apply to it and the harness is ~10
      lines. It is a follow-up rather than a blocker because the code is correct today (Expanded intact,
      showRule:false reachable and suppressing, defaults byte-equivalent on all 16 other call sites);
      because this change is 2 lines in a different file and cannot regress the invariant M1 guards; and
      because M1's guard should assert the final primitive state, which B1's settlement now unblocks.
      Same MEDIUM severity, same concrete ask: apps/control_plane/test/shared/technical_details_test.dart,
      ~40 lines, no bloc, no golden, no new architecture — (1) default renders one ContentRule, (2)
      showRule:false renders zero, (3) default + null note puts the link at the trailing edge (the
      Expanded regression guard), (4) DisclosureAlignment.start puts it at the leading edge.

REGRESSIONS: none. The correction-only diff is 2 lines in 1 file (add_product_page.dart:521 and :1016);
  design_primitives.dart is untouched (hash unchanged, mtime predating the correction); the trap region,
  the Ev Body pair, the mid-page prose, the class structure, the call-site census, all 7 remaining note:
  sites, every test file and every prohibited path re-verified unchanged; all four gates reproduce their
  exact baselines; no test weakened, skipped, @Ignore'd or deleted; no coverage removed; the escaped-string
  convention preserved with 6 escapes and 0 raw middots. Accuracy notes recorded without consequence:
  the correction lane's delta wording omits the required G->g case change, its 'test/failures holds 0'
  should read 80 tracked PNGs / 0 dirty (the dispatch's '48 dirty binaries' is also wrong), its '1096' is
  split-element counting (wc -l 1095), and MY OWN prior report cited the eyebrow at :519 when it is at
  :521 — pinned by the @@ -542 +521 @@ hunk and the -21 offset confirmed by the trap block's md5.

BLOCKERS: none.

READY_FOR_MERGE: YES
```

---

**One line for the Manager:** B1 is genuinely fixed — both sites decode to the approved §7:299 value
byte-for-byte, the escaping convention holds at 6 escapes / 0 raw middots, the reviewed state is intact
underneath a 2-line diff, and all four gates reproduce their exact baselines; the only thing still
unproven is the **boards'** actual `Key Meta` / `Art S` text, which no code lane can verify — and the
tree still has **no commit**, which does not block this approval but does block the integrator.
