# Report — Independent Design Re-Review, deploy-key service, Revision 2 (Gate D3)

Persisted per `aef-orchestrator` §14. Reviewer: a **fresh** `design-reviewer`, read-only, who did not
produce the design and did not write the correction.

**REVIEWED_HEAD `77c19f1`** (content anchor **`3a87e27`** — see L-F). Worktree
`/private/tmp/shipit-correct-addproduct-keys`, actual branch `design-correct-addproduct-keys`.
REVISION_ID `F21D5C64-006D-4203-A813-841E08E38B95`, supersedes `46980EE0-E638-409C-A7D3-E1B9399FECE5`.

```
RESULT: DESIGN_REVIEW_APPROVED
REVIEWED_HEAD: 77c19f1  (content anchor 3a87e27)
CORRECTION_REQUIRED: NO
HUMAN_DECISION_REQUIRED: YES
HUMAN_DECISION_TYPE: DESIGN
INDEPENDENT_RISK_LEVEL: 3
RISK_LEVEL_AGREEMENT: YES
```

| Severity | Finding |
|---|---|
| BLOCKERS | none |
| HIGH | none |
| MEDIUM | **M-A** |
| LOW | L-A … L-F |

## PROVENANCE

Verified, not accepted. `git rev-parse HEAD` = `77c19f114ee691e8c434afe37b7c84494b66dc40` ✓. Actual
branch is **`design-correct-addproduct-keys`**, not the `design/correct-addproduct-keys` recorded in
three artifacts (L-E). `git status --porcelain -uall` shows the lane touched **only** its own
`OWNED_PATHS`; no `PROHIBITED_PATH` modified. Revision 1 retained byte-identical as claimed.
Metadata declares `committed: false` honestly and does not self-approve.

## 1. ADR 0018 IS NOW GENUINELY READ — verified clause by clause

Read in full (158 lines) plus 0012, 0015, 0019, 0020, 0021. Every clause citation in revision 2's
§ R.1.1 table resolves to the quoted text: `:84-88` (per-repository keypair, local secret store,
"never … **persisted to the durable record**"), `:92-95` ("Referenced by name, never by value"),
`:96-99` ("ShipIt refuses to connect to an unrecognised host"), `:100-102` ("A product cannot be
registered until a connectivity check has succeeded"), `:113-114` ("requires no Shipit-side action"),
`:15-30` (amendment A1), `:79-80` (scoped deviation from AGENTS.md §13), `:140-141` (the carve-out).

Three claims confirmed specifically:

- **Q1 collapsed to Q1′** — verbatim: *"Q1′ — Does `b869ec24`'s server-side custody supersede ADR 0018
  `:85-88`'s local-secret-store clause?"* with both branches spelled out. ✓
- **A2 forbidden at the option itself** — the A2 heading reads "**FORBIDDEN by ADR 0018 `:87-88`**",
  with a blockquote stating the human "would [be asked to] approve a violation of the governing ADR",
  plus per-option "*ADR status*" lines on A1/A3/A4. The blocker is closed. ✓
- **False G-1 replaced by the real gap** — `AGENTS.md` is **129 lines** (the producer's number is right;
  the prior review's 71 was wrong) with `Product-specific policy` = `TBD` at `:59-63`, and
  `grep "§13"` → no match. §13b absent (cited by ADR 0019 `:121`). So ADR 0018's carve-out at `:140-141`
  and ADR 0012 `:34` both point at text that does not exist. Recorded as `G-1′`, owner Manager,
  correctly marked not blocking. ✓
- **`architecture_refs` repopulated** ✓

One thing that got *better* than asked: each ADR row **quotes the text**, not just the number, so a
reviewer can check a citation without opening the file.

## 2. B2 — THE CLAIM IS NOW TRUE AND THE FIX IS THE RIGHT ONE

**The hole is real.** `saveProductCredential` (`postgres_product_registry_store.dart:177-243`): with
null `expectedVersion` (`:237-241`) it runs `INSERT … ON CONFLICT ("credentialId") DO UPDATE SET
$assignments` where `$assignments` (`:195-209`) includes `"publicKey"`, `"fingerprint"`, `"algorithm"`,
`"referenceName"`. `recordGeneratedCredential` passes none (`engine:965`), accepts a caller-supplied
`credentialId` (`engine:920`), and its one-active guard (`engine:940-941`) is
`if (active != null && active.credentialId != supersedesCredentialId)` — so
`credentialId == supersedesCredentialId` passes and the stored key is overwritten in place.
`copyWith` is never on that path (`:950-964` builds a fresh object).

**The "a version CAS would not close it" analysis is CORRECT, and it is better than the prior review's
own remedy.** `engine:963` hardcodes `version: 1`, so an already-minted row is *also* at version 1 —
`expectedVersion: 1` matches at `store:214` and `$assignments` still rewrites `publicKey`. There is a
**second consequence the correction does not spell out**: on a *first* mint no row exists, so
`affected == 0` and `store:229-234` throws `ConcurrentModificationException(expectedVersion: 1,
actualVersion: 0)`. So the fix the prior review recommended — *"`recordCredentialCheck:1052` and
`confirmHostKey:997` already pass `expectedVersion`, so the pattern exists"* — would have produced a
change that reads plausible, still overwrites the key, **and breaks minting outright**. Verified the
four neighbouring writers do use CAS correctly at exactly `engine:997/1011/1052/1074`, which is what
makes the wrong fix tempting.

**The required fix is the right shape.** `D-1` requires the guard to **predicate the immutable fields**,
offers two acceptable implementations, marks (i) predicated `ON CONFLICT … DO UPDATE … WHERE …
RETURNING` as preferred, and explicitly forbids the racy bare read-then-write in (ii) — *"a
check-then-write without a predicating write is itself racy."* It also correctly preserves
`recordGeneratedCredential`'s null `expectedVersion` for genuine inserts, so the guard cannot live in
CAS alone. `D-2` is a **required deliverable** (PROPOSED ONLY under `C-09`, `apps/server/migrations/**`
correctly left uncreated), and its predicate justification is **verified verbatim**:
`readActiveCredentialForRepository` selects `WHERE "repositoryId" = @repositoryId AND "status" <>
'revoked'` (`store:257-268`), so constraint and query cannot contradict. SC-02/SC-03 gained **T-A** and
**T-B**, both marked failing today, T-B correctly assigned to the Postgres integration tier because a
fake cannot demonstrate a unique index.

**"Two mechanisms, not four, and not independent"** — stated verbatim in the § R.15.3 heading and the
metadata changelog. The four-row table is kept as *evidence* for collapsing four to two, with a
per-mechanism verdict: #1/#2 are one control in not-yet-written code, #3 is a refusal of a second
**row** keyed on `supersedesCredentialId` (not an immutability guard, not DB-enforced), #4 "Zero
protection on the boundary that persists the row." Revision 1's "These are independent" sentence is
withdrawn in place. § R.16 step 4 is rewritten onto `D-2`'s unique violation rather than the exception
that will not fire. **`G-9` is new and correct** — all eight `product_credential` migrations checked:
`definition.sql:645-647` gives one unique index (`credentialId`) and two non-unique ones, and **no**
partial unique index exists.

## 3. THE HUMAN'S RESERVED DECISION IS STILL VISIBLY OPEN

Re-ran the leakage hunt on revision 2 in full, sweeping every occurrence of `default`, `secret store`,
`keychain`, `substrate`, `encrypt`, `ciphertext`, `0600`, `vault`, and every normative section, table
cell, field default, schema note and interface signature.

**Where the line is.** A **recommendation** is permitted; a **default** is not. The line is: does the
text state a *fact about the world* from which the answer follows, or does it state *the answer* in a
form an implementer could act on without the human?

**Correctly withheld — the boundary holds.** § R.3 now states exactly one normative invariant
(*"`referenceName` continues to name a reference. It never carries a value."*), attributes it to ADR
0018 rather than to the design, and marks **three** things OPEN: its subject, its substrate ("there is
no default and no implied default"), and client exposure. The four deleted rev-1 strings are itemised
with reasons. Reuse row #35's migration cell is CONDITIONAL. § R.16's error table carries
`depends on Q2 — OPEN` in **both** the response and state-written columns. § R.7 is normative but
constrains *every* option and says plainly it "is currently unenforceable," committing to the interface
rather than a delivered property. § R.2 constraint 2's separate-table rule is a *shape* constraint
stated conditionally; it binds only A2 and selects nothing. § 10 states "neither is answered here and
neither is defaulted anywhere in normative text" — and that is now true.

**The one place it comes close is L-B.** LOW, with the fix below.

**The strongest steer, named so the Manager can present it honestly.** § R.4 A3 says A3 "is the natural
consequence of Q1′-negative rather than a competing choice — a consequence, **not** a selection", and
§ R.8 recommends A3 "preferred under **either** answer". Both are labelled as argument/recommendation,
both keep A1/A4 alive under the topology caveat, and both are recoverable as the human's answer. **This
is not a default.** But it is the sentence most likely to read as an answer in the reissued decision,
and the reissue should present it as the design's argument rather than as a neutral menu.

**`9417f8bf` — is there now enough basis to reissue and widen? Yes, and more work is needed before it
reaches the human.** Revision 2 supplies everything: Q1′ as the question, the A2-forbidden marker,
per-option LOW confidence, the withdrawn backup claim, and the Q4/`G-7` consequence chain, plus §10
item 1 as the instruction. But the object **still contains two statements revision 2 withdrew, and
still recommends a forbidden option**: `options[OPTION_B].implications` asserts *"a database backup
alone no longer discloses the key"* — the exact false comfort H3 withdrew — with no mention of the
live-DB path; `recommendation.rationale` offers "otherwise **A2** with a KEK … as the strongest option
that stays inside the current transactional store" and attributes "confidence MEDIUM" to a design that
now says LOW per option. `blocking_work_item.item_id` and `evidence.documents` still point at Revision 1
only, and `question` is neither Q1′ nor does it cover Q4.

> **So: basis sufficient, reissue not yet performed, and mandatory before the human sees it.**
> `79e860e2`'s question is still the bare disposal menu and must become Q3′. `898b07d0` is still framed
> as bare circularity and must be reframed as an ADR contradiction. All five PENDING decisions confirmed
> present.

## 4. Q3 RE-FRAMING — HONEST, NOT A RE-ASK

`grep -ic 'revoc\|rotat' .decisions/b869ec24-*.yaml` → **0**. `b869ec24` moved generation *and storage*
server-side, so under ADR 0018's own custody model (SHIP IT holds no bytes) `:113-114` *is* the complete
answer — but in the world `b869ec24` creates, SHIP IT does hold bytes, and "requires no Shipit-side
action" may no longer be true. That is a genuinely new and much narrower question, not a settled one
re-litigated. § R.6.1 states the reasoning, marks C-1 and C-3 as contradicting `:113-114`, and § R.8
records it as Conditional.

**One condition on the Manager:** `79e860e2` must be restated as Q3′ before it reaches the human, as
§ 10 item 2 requests.

## 5. `898b07d0` / OPEN-D4-2 — the ADR framing raises severity correctly

Independently verified: `createProduct` hardcodes `state: ProductState.registered` (`engine:54`),
`recordGeneratedCredential` requires `readRepositoryReference` + `_ensureOwned` (`engine:924-925`), and
no pre-registration `ProductState` exists (`product_state.dart:23-28`). **The gate is unsatisfiable.**
Framing it as a contradiction with ADR 0018 `:100-102` is right because that clause is *recorded
architecture* ("Proposed (amended — A1)", read, cited by 21 files), so the conflict is ADR-vs-domain,
not preference-vs-requirement. § R.19.2's new observation that option 2 also weakens a control ADR 0018
A1 now relies on (`productId` "retained for ownership checks only") is correct and adds weight.

## 6. REMAINING CHECKS

**H3/H4** — verified against the compose file **as text**; no Docker run. `docker/compose.yaml:16-17`
publishes `"5432:5432"` unqualified (Docker resolves to 0.0.0.0) ✓; `.env.example:16-18` documents
`POSTGRES_DB/USER/PASSWORD=shipit` ✓; `SERVERPOD_DATABASE_PASSWORD: shipit` is hardcoded in a committed
file (at `:63`, L-A). H3's "backups alone" withdrawal and H4's fourth exposure path are both correct and
both now stated — including the sharp observation that endpoint auditing and endpoint constraints do
not constrain the data.

**M3 — now normative, correctly.** `N-8` sits in the requirements section (§ R.10), states
`inkSecondary` is required and `inkTertiary` is "not permitted for new copy", covers all seven new
strings, and binds § R.14's "User sees" column. Citations verified: `add_product_page.dart:542` and
`:590` are exactly the two string lines quoted, and `inkTertiary` is the surrounding idiom (also at
`:341/:365/:369/:385/:476/:533`), while `inkSecondary` is already in use 11× in that file.

**L1–L6 all genuinely addressed.** L1 `engine:54` ✓ exact. L2 `product_state.dart:24-27` ✓ exact.
L3 `createProduct 43-61` ✓ and `addRepositoryReference 150-170` ✓ both now correct. L4 ✓ —
`referenceName` has **no** index; `repository_credential.spy.yaml:7-14` declares exactly `credentialId`
(unique), `repositoryId`, `productId`. L5 ✓ — D-7 reframed in place as a confirmed-unimplemented
follow-up to `570bb640`, citing that decision's own `:22-27`/`:67-72`, original content preserved.
L6 ✓ reported-not-edited, and `DECISIONS.md:8-12` genuinely omits `570bb640`. **M1** ✓ with a per-line
four-step table verified against `:650/:656/:662/:668`. **M2** ✓ all Q1 options now LOW, Q2 MEDIUM
retained on the prior review's independent grounds. **M4** ✓ `9417f8bf` named as owner in four places.

**Self-assessment honest.** `PARTIAL`/`PARTIAL`/`MEDIUM` each substantiated: boards are the sibling
lane's (`C-11`), `N-8` constrains tokens not boards; feasibility is split domain-HIGH /
store-MEDIUM-and-unbuilt / transport-LOW, which is more honest than a single figure. **No gate claimed
that was not run** — § 9.1 marks analyzer, build, tests, Docker/Compose, and contrast measurement all
`NOT_RUN`, and § 9.2 lists five `UNVERIFIED` claims each with the command a human should run.

**Learning — complete.** `discoveries.md` carries Category + Authority + Evidence on every entry, D-6 is
retracted **in place with the original text preserved**, and new **D-10** classifies the
wrong-identifier pattern as `AUTOMATION_OPPORTUNITY` — a reusable workflow change, correctly routed by
`LEARNING_POLICY.md` §2 to independent review rather than auto-persisted. Manager-owned ledgers not
touched. ✓

## FINDINGS

### M-A — D-1 / D-2 / T-A / T-B are specified correctly but **OWNED BY NOTHING**

§ R.15b.4 states they are "not gated on" OPEN-D4-1, and § 9 sizes each at MEDIUM; § R.22 records G-9's
owner only as the vague "Implementation (D-2)". Meanwhile **the sole lane that could execute them
(`implement-addproduct`) is blocked by this very Gate D4.**

The correction lane therefore specifies required work with no dispatchable owner, and **a live
silent-key-rotation path stays in `main` for a reason unrelated to it.**

**ACTION (Manager, dispatch now, independent of Gate D4):** open a **store-integrity work item** owning
D-1 (predicated `ON CONFLICT DO UPDATE … WHERE` over
`publicKey`/`fingerprint`/`algorithm`/`referenceName`, or the typed-refusal variant), D-2 (partial unique
index), and T-A/T-B. Path ownership: `apps/server/lib/src/persistence/postgres_product_registry_store.dart`,
`apps/server/migrations/**`, `packages/product_registry/**`. **Reference the design's § R.15b as the
specification; it is correct and does not need redoing.**

This is reachable through the domain's public API today with **no feature code**, it is
substrate-independent, it is sized at one statement plus one migration, and it is the persistence
guarantee ADR 0018 A1 depends on. The revision got the *content* right and explicitly says the work is
not gated on the human. **What is missing is dispatch.** That is a Manager action, not a design defect,
so it does not block Gate D3.

### LOW

- **L-A** `docker/compose.yaml:62` → **`:63`**. "SERVERPOD_DATABASE_PASSWORD: shipit" is at `:63`
  (`:62` is `SERVERPOD_DATABASE_USER`). Appears 3× in revision 2 (§ R.4 A2 Against, § R.7.1 threat
  table, § R.18 point 4) plus `design-brief-1.1.0.md` C-08 and `metadata-2.yaml` H3. The prior review's
  error was carried forward un-corrected despite § 9.1's claim that "every file:line in this revision
  was opened and read at 77c19f1". **Substance is CORRECT and important** — `:16-17` publishes
  `"5432:5432"` unqualified and `.env.example:16-18` documents `POSTGRES_USER/PASSWORD=shipit`, both
  verified exact. Cite `:63`.
- **L-B** § R.6.2:395 heading "with the ADR's default named" and `:407` "C-2 … is the default if Q3
  resolves YES." Uses the one word the human prohibited and that this document forbids four times
  elsewhere (§ R.1.1 "defaults nothing"; § R.3.1 "no default and no implied default"; brief C-01/AC-03;
  metadata "defaulted nowhere"). Substantively it is a conditional consequence of the human's own Q3′
  answer, not a substrate default — **so this is vocabulary, not leakage.** Also says "Q3" not "Q3′" in
  the one sentence that does the defaulting. Replace with "the consequence if Q3′ resolves YES — and
  only if the human answers YES", and retitle `:395` "with the ADR's consequence under Q3′=YES named".
- **L-C** § R.15b.1 states rotation "mints a new credentialId (it already does: `rotateCredential`
  passes `supersedesCredentialId` and no `credentialId` by default, `engine:1108-1119`)". True only **by
  default**: `rotateCredential`'s `credentialId` parameter is at `engine:1091` and is forwarded at
  `engine:1115`, which is the "second route" § R.15.2 correctly names. The cited `:1117` is "now: t," —
  the forward is `:1115`. State that D-1 is what closes that route, matching § R.15.2's own framing.
- **L-D** Range endpoints off by one, all substance-correct: ADR 0019 quoted phrase at `:48` (not
  `:49-51`); ADR 0020 EvidenceRedactor text at `:138` (not `:137`); ADR 0021 Hard Rules heading `:83` /
  table `:85-91` (cited `:86-91`, where `:86` is the separator row); store `$assignments` `:195-209`
  (cited `:195-210`); store non-null branch `:211-235` (cited `:212-236`); store null branch `:237-241`
  (cited `:238-243`); `requireUsableCredential` `:1138-1161` (cited `:1138-1162`).
- **L-E** **BRANCH name is wrong in three artifacts.** `design-revision-2.md:11`,
  `metadata-2.yaml:274` and `design-brief-1.1.0.md:47` all record `design/correct-addproduct-keys`. The
  actual branch is **`design-correct-addproduct-keys`**; no branch of the recorded name exists
  (`git worktree list`). Worktree path and base/head SHA are correct.
- **L-F** **PROVENANCE.** The entire revision-2 artifact set is **UNTRACKED at 77c19f1** — all 12 files
  in `design-addproduct-keyservice/` are `??`, and `git ls-tree -r HEAD` contains zero of them.
  `REVIEWED_HEAD 77c19f1` therefore does not contain the reviewed design, and the "revision 1 retained
  byte-identical so corrections are diffable" claim is not checkable against git in that worktree.
  **Mitigating and verified:** all 12 files are byte-identical (shasum) to `main`'s `HEAD 3a87e27`,
  where they ARE tracked, so the content is unambiguous and reproducible — **`3a87e27` is the correct
  content anchor.** `metadata` honestly declares `committed: false`; this is a lane-hygiene defect, not a
  content defect. **Not blocking.**

## TRACEABILITY_GAPS

**(none remaining in the design artifact set)** — the prior review's gaps 1–4 are all closed, and
closed substantively. Gap 1 (false G-1) and gap 2 (`architecture_refs`) verified closed: each of ADR
0012/0015/0018/0019/0020/0021 now listed with status, line count and what it governs here, plus ADR
0001/0002/0003 retained and annotated as governing nothing, and `AGENTS.md` §13/§13b recorded
PRESENT/ABSENT on evidence. Gap 3 (assumptions 1 and 8 presented as inference) closed by § R.21.2,
which demotes seven of ten to recorded ADR decisions and marks the two the ADR is silent on (#7, #9) as
such. Gap 4 (Q4/G-7 ownerless) closed by naming `9417f8bf` in four places. `G-9` is new and correct.
`requirements_gaps` is now honest in every entry checked.

**LIVE, MANAGER-OWNED, OUTSIDE THIS GATE (not design-artifact gaps):**
- `docs/engineering/dispatch/LANES.md:204-205` **still asserts** "ADR 0018 and `AGENTS.md §13a` do not
  exist. Nine code locations cite them; the governing ADR for the credential model is absent from the
  repository." `WORK_STATE.md` **was** retracted; **`LANES.md` was NOT.** Revision 2 §10 item 5
  correctly lists this — flagging, not escalating.
- `docs/engineering/dispatch/DECISIONS.md:8-12` index table omits `570bb640` (verified: rows are
  `130f3a7e`, `70b47372`, `048f3367`, `73097d48`, `b869ec24`). L-6 accurate.

## NOT RUN / UNVERIFIED BY THIS REVIEW

- `dart analyze` / `flutter analyze` / build / test — **NOT_RUN.** No claim made about their output. In
  particular **no** feasibility claim is derived from a build.
- **Any Docker or Compose command — NOT_RUN, none issued**, not even read-only. Compose files were read
  as text.
- **Contrast-ratio measurement — NOT_RUN.** The reviewer relied on the prior review's
  independently-measured 4.23:1 dark / 6.74:1 light / 6.10:1 dark, and verified only the *citations* and
  that the idiom is real.
- Still `UNVERIFIED` (need a running stack; **the human's to run**): a real SSH transport accepting the
  generated public key (SC-01); container→host keychain reachability (A4); host-key `changed` detection
  against a host presenting a different key (N-6/`G-8`); `D-1`'s `DO UPDATE … WHERE` predicate behaving
  as specified on this driver (T-A); `D-2`'s index collapsing concurrent mints (T-B). `D-1`/`D-2` are
  `DESIGNED` from `definition.sql:645-647` — the schema was verified, the runtime behaviour was not.
- Loopback pinning verified **negatively by grep only**.

## BOTTOM LINE

Both blockers are genuinely closed, and each was verified against source rather than against the
producer's account. B1 is closed by actually reading the ADR — 158 lines, 21 ADRs in `docs/adr/`, every
clause citation resolving to the text it claims, Q1 collapsed to a single supersession question, A2 marked
forbidden at the option itself, the false G-1 withdrawn and replaced by a real and larger gap, and
`architecture_refs` repopulated with each credential ADR mapped to what it governs. B2 is closed by a
correction that is **better than the remedy the prior review prescribed**: it shows the obvious fix —
the version CAS the review pointed at — would have left the hole open *and* broken minting, and it
specifies a guard on the immutable fields, the required partial unique index with a predicate verified
identical to the read path's, and the two engine-level tests that fail today. Revision 2 now says two
mechanisms, not four, and not independent.

The human's reserved decision remains visibly open. The one place the document comes close is a single
use of the word "default" in § R.6.2 (L-B), which is a conditional consequence of the human's own answer
rather than an imposed choice — and the strongest steer, § R.4 A3's "natural consequence", is labelled
as argument and keeps A1/A4 alive. `9417f8bf` now has sufficient basis for the reissue and widening to
Q4/`G-7`, but the object still carries two statements this revision withdrew and still recommends an
ADR-forbidden option; **it must not reach the human before the reissue.**

The one thing the reviewer would not let pass is **M-A**: the design specified required work correctly and
then left it owned by nobody, behind a lane that cannot start. That, plus L-F (artifacts untracked at the
reviewed HEAD) and the still-unretracted `LANES.md:204-205`, are Manager actions, not reasons to fail this
gate.

Nothing was written, edited, committed or pushed.
