# Subtask Report — design-rereview-adr-0018-a2-rev4

**FOCUSED RE-REVIEW** of ADR 0018 amendment A2 revision 4. READ-ONLY. Persisted to disk before
returning, per the dispatch and because three review reports have been lost in this work item.

---

# 1. LEAD: MY INDEPENDENT W1–W6 COUNT

## **ELEVEN confirmed fixed. Zero additional scope-class sites. One unadjudicated hit (the title).**

I re-ran all six axes with my own greps over the 999-line artifact, then adjudicated every hit
independently rather than checking the lane's dispositions.

| # | Axis | My independent result |
|---|---|---|
| **W1** | per-product scope | 22 hits. All 11 substantive ones adjudicated: 5 fixed (B-1, S-1, S-4, S-5, + the `:422` parenthetical), 5 correctly marked or quoted-history, 1 correct-as-written. **One hit not adjudicated by the sweep at all — see §1.3.** |
| **W2** | custody (local store / operator device) | 14 hits. All marked, scoped, or explicitly named as stale. `:178`/`:412` fallback clauses are bounded by `:182-187`/`:414-416`, which name the fallback as "the superseded custody model and its weaker at-rest property". **No residue.** |
| **W3** | rotation scope | 18 hits. `:445` and `:470` both struck and marked; `:242`, `:329`, `:541-543` all correctly per-repository. `:280` ("Rotation is fleet-wide") is §**Context** describing the rejected single-token alternative — correct as written. **No residue.** |
| **W4** | revocation | 30 hits. No provider-native/no-ShipIt-action claim survives unmarked. **No residue** — the lane's V-7 ("already marked") is correct. |
| **W5** | key-count arithmetic | 40 hits, overlapping W1. `:509` fixed (S-3); `:520` already correct. **No residue.** |
| **W6** | reference-name format | 5 hits. `:427-429` correct and the pre-A1 form explicitly forbidden; `:77` correct. **No residue.** |

**The producing lane's eleven is right for its six axes.** I did not find a twelfth unmarked
per-product, custody, rotation, revocation, key-count or reference-name claim. Had I found one it
would have been the BLOCKER. I did not.

## 1.1 But the sweep's axes do not cover the class it says it covers

The revision's thesis (F-8, and §1.1) is that the defect is **a class** — *stale normative text* —
and that the repair is a sweep with a stated axis list. That thesis is right and the eleven are right.

**But the class is larger than the six axes, and the missing axis is the one its own finding M-3 had
just exposed.** M-3 was "a citation a reader cannot verify" (`570bb640` cited as a commit). Revision 4
swept the *token* class (V-10/V-11: all 9 eight-hex ids classified, all 6 seven-hex commits resolved)
and declared M-3 fixed. It did **not** sweep the **line-number citation** class — and five broken
line-number citations survive, **one of them introduced by revision 4 itself and propagated by the
Manager into a resolved human decision object.**

That is the substantive finding of this review, and it is what "twelve or thirteen exist" was asking
about. The answer is: not on W1–W6, **yes on an axis the sweep did not name.**

## 1.2 All eleven claimed fixes verified individually

Every one is real. I checked each against source, not against the lane's word.

| Finding | Verified how | Result |
|---|---|---|
| **B-1** `:295-302` | struck, **SUPERSEDED (A1)**, A1's own reason quoted, current per-repository scope stated | **confirmed** |
| **H-1** re-grounding | `repository_credential.dart:61-122` read field-by-field: `credentialId`, `productId`, `repositoryId`, `referenceName`, `publicKey`, `fingerprint`, `algorithm`, `status`, `createdAt`, `lastVerifiedAt`, `lastVerifiedBy`, `lastFailureReason`, `hostKeyStatus`, `host`, `hostKeyFingerprint`, `hostConfirmedAt`, `hostConfirmedBy`, `revokedAt`, `revokedReason`, `supersedesCredentialId`, `version` — **no private-key field**. The `:14-15`/`:70-71` stale claim and the `:20-27` correct claim are both exact. | **confirmed — the re-grounding is correct and does not rest on the swapped-out evidence** |
| **H-2a** `:445-454` | struck, marked, per-repository rotation stated, `rotateCredential` named | **confirmed** (but see H-R3 for a broken citation *inside* the new text) |
| **H-2b** `:470-479` | **substance** corrected, not merely marked — "moves cost rather than removing it: a product with *n* repositories has *n* keys to rotate, verify and reinstall" | **confirmed, and the corrected argument HOLDS.** Per-repository scoping does deliver strictly-narrower fleet isolation, and the cost it relocates (n rotations, not 1) is now stated in §Positive and correctly left in §Negative (`:509-516`, `:519-521`) |
| **H-3** §Related scope note `:920-949` | dated, attributed, tables **four** sites, states decisions not re-opened, points at `LEARNING_POLICY.md:261` and `:37-40` | **confirmed in form**; the ADR's own citations are unchanged, as required |
| **M-1** two rows added | table 9 → 11 rows (I counted **11** clause rows + header); "Every normative clause" scoped; partly-built count 2 → 3 | **confirmed** |
| **M-2/G-b** filed | §Known gaps `:861-873` carries it with ownerless status and substrate-independence; §Accepted risks `:835-844` says explicitly not counted | **confirmed — surfaced *and* filed, and no fifth risk created** |
| **M-3** `:662-664`, `:958-959` | `git log -n1 570bb640` → `fatal: ambiguous argument`; file exists; `type: DEPLOYMENT_AUTHORITY`, `status: RESOLVED`; all 9 eight-hex tokens are decision ids | **confirmed at both sites** |
| **M-4** six A1 sites | `product_registry_engine.dart:933-936` (exact quote); `postgres_product_registry_store.dart:413-439` `DO NOTHING`; `:466-471` exception text; `:428-431` "D-4 removes the mint's ability to resurrect one"; `in_memory_product_registry_store.dart:178-185` **refuses identically — two tiers agree**; `:296-320` three unconditional predicates | **confirmed, all six, line-exact** |
| **S-6** `:21-36` | `git ls-tree -r main -- …design-review-adr-0018-a2-rev3/` returns `prompt.md` + `report.md`; `RESULT: DESIGN_REVIEW_CHANGES_REQUIRED`, `REVIEWED_HEAD: 289f1d3`, added by `16cd497` — so it was on `main` **before** revision 4 was written | **confirmed — the git argument is exactly right** |
| **F-9** `add_product_page.dart:126-138` | `Random.secure()`, 32 bytes, labelled `ssh-ed25519`, 16-byte fingerprint digest | **confirmed, and it is STRONGER than recorded — see L-R2** |

## 1.3 The one W1 hit the sweep never adjudicated: the document's own title

`docs/adr/0018-per-product-git-credentials.md:1`:

```
# ADR 0018: Per-Product Git Credentials
```

This is the most prominent unmarked statement of the A1-superseded scope in the entire file. It
appears in no fix and **in no §1.4 decline** — §1.4 lists eleven declines and the title is not among
them. There is a legitimate reason to leave it (renaming an ADR breaks every cross-reference to it),
but **that reason was never articulated**, and §1.4 exists precisely so a decline is recorded with its
reason. As it stands a reader cannot tell whether the sweep considered the title and concluded
"titles are stable", or simply missed it. See **M-R2**.

## 1.4 §1.4's declined hits — audited directly

The lane's own test: *"if a declined hit should have been fixed the sweep is over-cautious; if a
declined hit was right, the omissions are accounted for."*

| §1.4 decline | My adjudication |
|---|---|
| `:59` A1 row struck | **right** |
| `:64-65` "Previous (superseded)" labelled | **right** |
| `:379-384` Specifics bullet, doubly marked | **right** — though note the "generated by ShipIt on the operator's device" text is marked by a *trailing* paragraph (`:384-386`), not struck inline. Defensible under `:52-55`; I record it as the weakest of the four worked examples |
| `:478` §Positive revocation | **right** |
| `:520` §Negative deploy-key constraint | **right** |
| `:38` the convention statement | **right** — and note `:38` is itself now a **wrong pointer** (see H-R3) |
| `:877` Known-gaps rotation entry | **right** |
| `:295-302` sweep's own output | **right** |
| `:109-139` "never holds" scoping | **right** — bounded three ways |
| `:189-193`, `:478-497` custody/revocation | **right** |
| `9417f8bf:116-119`, `:194-201` | **WRONG — see H-R1.** `:194-201` is OPTION_D (host keychain) description text. `:116-119` is the tail of a fail-open/fail-closed assessment plus the head of the "Insider/backup exposure" dimension. **Neither contains the same-uid reasoning the decline claims they are "cited as the source of"** |

**Nine of eleven declines are right. Two are wrong citations**, and they are wrong in the one entry
whose function is to certify that the sweep's *reasoning about its citations* was sound.

---

# 2. PROVENANCE — verified independently, not taken on trust

| Dispatch claim | My verification | Result |
|---|---|---|
| Worktree `/private/tmp/shipit-design-adr0018` @ `289f1d3`, branch `design/adr-0018-amendment` | `git rev-parse` | **confirmed exactly** |
| ADR **999 lines** in worktree, **580 on `main`** | `wc -l`; `git show main:…` | **confirmed exactly** |
| **The amendment is NOT committed** | `git status --short` → ` M docs/adr/0018-per-product-git-credentials.md`; `git show main:… \| wc -l` = 580 | **confirmed — RECORDED. `main` does not contain revision 4's ADR at all.** |
| `design-revision-4.md`, `design-revision-metadata-4.yaml` on `main` at `af8e30f` | `git log --all --diff-filter=A -- <exact full path>` → **`1c3f5ad`** for both | **correction: they landed at `1c3f5ad`, not `af8e30f`** |
| `report.md` on `main` | added `16cd497`; current content is revision 4's | **confirmed** |
| Revision 3's report **not overwritten** | `report.md` at `16cd497` = sha256 `b1d14b71…`; `report-revision-3.md` on `main` = sha256 `b1d14b71…` | **confirmed byte-identical.** The no-silent-rewrite device was honoured for the report as well as for revisions 1–3 |
| Only the ADR written outside the task directory | `git status --short` in the worktree: one ` M` + six untracked artifacts in the task dir | **confirmed** |

`main` has since advanced past the dispatched `HEAD_SHA` to **`bd01bc0`**. Everything M-4 asserts is
verified against `main` and re-checked at `bd01bc0` — `08c7590` is an ancestor, so no M-4 claim moved.

## 2.1 Both stashes — verified BY LABEL, untouched

```
stash@{0}: On design-correct-addproduct-mobile: rev5-uncommitted-identical-to-16cd497
stash@{1}: On design/adr-0018-amendment: ADR0018 A2 rev1 local edit (…; sha256 9e5b4772) -- preserved
```

I resolved the ADR stash by **label substring**, not by index:

- `git show <resolved>:docs/adr/0018-per-product-git-credentials.md | shasum -a 256` → **`9e5b4772…`**
- `git show main:docs/adr/0018-per-product-git-credentials.md | shasum -a 256` → **`9e5b4772…`**
- Both 580 lines.

**The ADR stash is byte-identical to `main`'s ADR.** The lane's V-20 and the label agree, and the
producing lane was right that the dispatch's `stash@{0}` was stale. **I issued no `stash`, `checkout`,
`reset`, `merge`, `commit`, `push` or `clean`. Both stashes are exactly as found.**

---

# 3. HIGH

## H-R1 — `9417f8bf:116-119` is a wrong citation, propagated by revision 4 into a resolved human decision object

The note appended to `.decisions/9417f8bf` at `1c3f5ad` states:

> `# WHY THIS OBJECT IS NOT INTERNALLY CONSISTENT. :116-119 already contains the CORRECT reasoning -`
> `# it rejected A1 precisely because "permissions do not defend against a same-uid process - which`
> `# is the git transport".`

**`:116-119` contains no such text.** I read the ranges:

```
115|          unavailability lands directly on the fail-open/fail-closed question in
116|          `7b1bc8b7-6cd1-4ddc-a94f-366de2bed38a`.
117|      - dimension: "Insider/backup exposure"
118|        option_a: "A3 (manager-held) or A2 (encrypted, KEK outside the DB)"
119|        option_b: "A1 (plaintext file)"
```

The quoted reasoning is at **`:159-160`** ("…permissions do not defend / against a same-uid process —
which is the git transport."), inside OPTION_A's `implications`. There is a **second**, independent
same-uid site at **`:96-97`** ("A1 filesystem-only protection against a same-uid process / none — the
git transport runs as the same uid that would read the file").

**Scope of the propagation — five sites in the ADR plus the decision object:**

| File | Line(s) | Form |
|---|---|---|
| ADR | `:144-145`, `:184-185`, `:840-841`, `:862-863`, `:935-937` | "rejected A1 … because *permissions do not defend against a same-uid process*" |
| ADR | `:934` table in the §Related scope note | listed as one of the four internal-inconsistency witnesses |
| `design-revision-4.md` | §11.1 | the text the Manager was **instructed** to apply |
| `.decisions/9417f8bf` (on `main`) | `:266-268` | the note the Manager **actually applied** |
| `design-revision-4.md` §1.4 | decline table | `:194-201` also cited as same-uid source; it is OPTION_D's description |

**Why this is HIGH and not cosmetic.** The **substance** of the claim is true — the object *does*
contain the correct same-uid reasoning, at `:96-97` and `:159-160`, so it *is* internally inconsistent
with itself, and the reconciliation holds. **Only the pointer is wrong.** But the ADR itself argues
at `:152-154` that a wrong absolute is worse than an absent one "because a reader who trusts it will
not look for the real exposure". A security reconciliation whose pointer lands 43 lines off the quoted
text produces exactly that behaviour. And the defect has been **written into a human decision record**,
where it is least likely to be re-checked.

**Fix (two edits, both append-only-friendly):**
1. Correct all five ADR sites and §1.4 to `9417f8bf:159-160` (naming `:96-97` as the second witness is
   worth doing — it is the strongest form, being stated as a *metric* rather than prose).
2. Append a one-line correction to `.decisions/9417f8bf`, naming `:159-160` and `:96-97`. **Do not
   edit the existing note** — it is above the marker only in the sense of being part of an append-only
   block; the remedy is a second dated append, same device.

## H-R2 — §Accepted risks' preamble still says "Nothing here is closed", which revision 4 made false

ADR `:687-688`:

> `Each is therefore an **accepted risk**, not an open blocker. Nothing here is closed; each entry`
> `states the consequence that was accepted.`

Twenty-three lines below, at `:711-712`:

> `**A1 — A revoked credential could be resurrected by a re-mint. ACCEPTED 2026-10-06; the exposure`
> `is CLOSED on `main` as of `08c7590`, and the accepted-risk entry stands until the owner retires it.**`

**The section preamble revision 4 edited is contradicted by the entry revision 4 edited, and the
preamble was not updated.** This is the S-6 class — a section-level normative claim falsified by the
document's own body — occurring on the exact axis (M-4/A1) the revision claimed to have swept, inside
the section it rewrote most.

Note `:691` shows the author *was* aware of the distinction: "None is **closed by the wording changes in
this revision**" is a narrower and correct claim. The unqualified "Nothing here is closed" at `:687` is
the un-updated one.

**Fix:** `:687-688` → "Each is therefore an **accepted risk**, not an open blocker. **No accepted-risk
entry is closed as a register entry**; each states the consequence that was accepted — though A1's
*exposure* is now closed on `main` (see below), which is a change in code state, not a retirement."

## H-R3 — Revision 4 shifted the document by +188 lines and left three of its own internal line-number citations pointing at the wrong text

The ADR's citation convention (`:52-55`) scopes pre-revision line numbers to **§Amendments only**:
*"Line numbers cited in §Amendments refer to the revision named there, not to the current file."*
Every other `:NNN` is therefore a **current-file** citation and must resolve in the 999-line document.

| Cited at | Points to | Actually at | Verdict |
|---|---|---|---|
| **`:447`** (inside revision 4's **new** H-2a text) | §"What survives A2 unchanged", quoting "rotation scoped to one repository" | `:237` / `:242` | **BROKEN — and newly introduced by revision 4** |
| `:943`, `:945` | "this ADR's own `:37-40` convention" | `:52-55` (`:37-40` is the §Status provenance bullet about the decision object) | **BROKEN** |
| `:948` | "the same hazard this ADR identifies at `:137-139` — a false absolute is worse than an absent one" | `:152-154` (`:137-139` is the transport-time materialisation bullet) | **BROKEN — and self-refuting** |

I confirmed `:447` is new text: `git diff HEAD -- …` shows it as a `+` line written by revision 4. It
is a **pre-revision-4 (811-line) number copied verbatim out of the revision-3 review report**, which
cited `:219` against that base. Revision 4 grew the file and did not re-anchor it.

**The `:948` case deserves the reviewer's attention.** The §Related scope note exists to stop a reader
trusting a false absolute, and it argues its own necessity by pointing at `:137-139` — which does not
contain that argument. The note cites a wrong pointer in support of the proposition that wrong
pointers are dangerous. That is the sharpest instance of the class available in this artifact, and it
was introduced by the fix for H-3.

**Fix:** re-anchor all three. Also add `:52-55` to the §Related note's own citations of the convention
(it currently cites `:37-40` twice).

---

# 4. MEDIUM

## M-R1 — `876c6b97:122-123` carries a **second** false standing claim of the S-6 class, and the propagation fix missed it

```
121|    **§ Accepted risks** section carrying A1-A4, each with a "Consequence accepted." paragraph stating
122|    what is being carried. The artifact also records, explicitly, that **acceptance is not review**:
123|    `reviewed_by` and `reviewed_at` remain `null` because independent design review of the amendment has
     |    still never happened.
```

I searched the appended note (`:164-200`) and the whole ADR for any treatment of `:123`: **none.**
The note corrects the *key-bytes* absolute at `:20` and is otherwise scrupulous — but it leaves a
review-status absolute that is now false, unannotated.

This is precisely the defect revision 4 found, named, and fixed **in the ADR's own §Status** (`:21-36`):
a fact with a shelf life written as a standing claim. The fix was applied to the document and **not to
the Manager-owned object the document names as the citable authority for its acceptance** — which is
the one place a future reader is *most* likely to land, because `876c6b97` is the citable id.

Compounding it, ADR `:914` states as a standing claim: *"The independent review of **revision 4** has
not happened and is the next step."* That is the same perishable form, and **this review is that
review** — so by the time this report is on disk the sentence is false in exactly the way `:21-36`
described.

**Fix:** append to `.decisions/876c6b97` a dated scope note that `resolution.rationale:122-123` carries
the review-status absolute and is superseded by the ADR's corrected §Status passage — leaving
`human`-recorded rationale **unedited**. Restate ADR `:913-914` in a form that survives its own
expiry ("as of `289f1d3` / at the time of writing, revision 4's review had not happened; see §Related").

## M-R2 — §1.4's decline ledger is not a complete ledger, and §Known gaps now holds CLOSED items under a "Remaining items" header

Two instances of the same gap in auditability:

1. **The title (`:1`)** — see §1.3. Neither fixed nor declined.
2. **§Known gaps** `:848` reads *"Remaining items."* and now contains **two CLOSED entries**: `:851`
   (pre-existing, §13 carve-out) and `:885` **added by revision 4** ("Rotation-scope wording. CLOSED by
   revision 4."). Revision 4 followed a precedent that was already inconsistent, and so widened it.

The retaining-closed-items-as-history device is the ADR's own `:52-55` convention and is right in
spirit. But a section whose declared purpose is "Remaining items" is being used as a history log
without saying so — which is the `:281` "Every clause below is therefore marked" failure in a different
key: a claiming sentence outrunning the table.

**Fix:** either add one line to the §Known gaps header ("includes entries closed later, retained as
history"), or move closed entries to a short "Closed" sub-heading. Articulate the title decision.

## M-R3 — The recommended correction-loop contract should name a **reference-resolution** axis, or this gap recurs

Revision 4's F-8 recommends the `aef-correction-loop` contract *"require a class-sweep step with a
stated grep/axis list and an explicit count"*. That is the right recommendation and it is the reason I
found what I found — the axis list is the deliverable, and this time the list was incomplete.

Revision 4's own M-3 proved the class ("a citation a reader cannot verify"), and its sweep then covered
only *hex tokens*. Concretely, a contract clause worth adding: **every `file:line` and `:NNN`
cross-reference in the edited artifact resolves, or is explicitly marked as referring to a named prior
revision** — plus a mechanical check, because this whole class is mechanically detectable and I
detected it with a script in one pass.

---

# 5. LOW

## L-R1 — On `reviewed_by: null`: **I agree it is right**, for a sharper reason than either the ADR's or the lane's

I took the dispatch's challenge seriously and my conclusion is that the lane was right.

`CHANGES_REQUIRED` is indeed not a signature — that is correct. But the lane's and the ADR's stated
reasons rest on a distinction that will not survive contact with a directory listing: **"has never
been independently reviewed" and "has been reviewed and not approved" are the same operational state**
for any downstream consumer deciding whether to trust the prose. What actually justifies `null` is
narrower and durable: **`reviewed_by` names a reviewer who approved; no such reviewer exists for any
revision of A2.** That is true today, will be true after this `CHANGES_REQUIRED`, and will be false
only when someone approves — at which point the field should be filled.

So: keep `null`. But state it that way, and drop the *"stays null until a reviewer signs it"*
prescription the ADR itself identifies as the harmful half of S-6. A prescription keyed to a
contingency is how the original defect was born.

## L-R2 — F-9 is **stronger** than the ADR records it

The ADR says an operator "installs what this screen offers gets a key registered nowhere." Reading
`_onRegisterProductRequested` (`add_product_page.dart:145-181`), the truth is one step further:

```
161|      final product = await _repository.createProduct(…
169|      await _repository.addRepositoryReference(
171|        repositoryId: productId, // Use productId as repositoryId for simplicity
```

**The public key is never transmitted at all.** There is no credential-creation call in the register
flow. So the UI offers a key that is (a) not a real Ed25519 public key, (b) never registered, and
(c) never even sent. That also means `repositoryId: productId` — the A1 scope invariant — is
**violated by the shipping build**, which is materially more serious than comment hygiene and belongs
in the ADR's §Known gaps alongside the mock.

Worth noting the ADR's "partly built" marking remains the right call: the *surface* is built and the
*negative half* ("no secret value typed in") is genuinely `yes`. But the register-flow omission should
be recorded.

## L-R3 — The Manager's applied notes: **append-only, faithful, and well-judged**

Both notes were audited against their objects:

- `9417f8bf` — 42 added, **0 removed**. Nothing above the marker changed, including `updated_at`.
- `876c6b97` — 37 added, **1 removed**, and the removed line is exactly
  `updated_at: 2026-10-06T14:20:00Z` → replaced by
  `updated_at: 2026-10-07T00:00:00Z   # scope note appended; the resolution itself is unaltered`,
  which is **below** the marker and carries an inline comment. Same for `27ea6536`. **These are the
  only mutations above the marker, exactly as the dispatch required.**
- `876c6b97` `:20` quote matches the object verbatim. Both notes state "adds no fifth and closes
  none". `876c6b97` `status: RESOLVED`, `type: ARCHITECTURE`, `selected_option: OPTION_A`,
  `decided_at`, `decided_by`, `created_by` all unchanged.
- **§11's prescribed text was applied faithfully** in substance — including the `:140` uniqueness claim
  (which I checked: it **does** survive in the storage dimension, because A1 writes plaintext at rest
  and A2 writes ciphertext at rest, while A3 writes only a reference) and the "retiring it is the
  owner's call" framing.

**On the `27ea6536` framing claim, which I was asked to judge:** *"what the decision overruled was the
lane's CONCLUSION, not its OBSERVATION, and the owner was entitled to reverse it."* I read the object
in full. **The claim is accurate and is the right call.** `supersedes_design_lane_reading` (`:119-126`)
did record the lane's *observation* — a footer copy line at (236,862) — and `follow_up_action #3`
(`:153-155`) did direct that it "should be treated as a misidentification". The note establishes by
measurement that the layer exists at exactly that coordinate on all four boards, so the observation
stands and only the conclusion was reversed. The note then does the three things that keep this
honest: it leaves `human_correction_verbatim` **unedited and explicitly refuses to edit the owner's
spelling** (`:195-198`), it states the OUTCOME stands "ALL OF IT" (`:190-192`), and it registers the
residual board conflict as G-18 rather than hiding it (`:207-213`). **A human's factual premise being
wrong is not a licence to edit the human's words, and this note does not take it.** Corroboration: the
string it quotes is at `add_product_page.dart:383-384` exactly as claimed.

---

# 6. POSITION ON M-4's AUTHORITY LINE — as the dispatch demanded

**The boundary is right on the register. It is incomplete on the label. Those are different faults
and the revision conflates them.**

**Right, and I endorse it.** Not retiring accepted risk A1 is correct. The register records what the
owner accepted on 2026-10-06; retiring A1 changes that, and it is the owner's call. The lane's stated
reason — that a unilateral retirement *"would be this revision's own defect class in the other
direction"* — is a real principle and it is the right one: the defect this revision exists to remove is
a lane asserting a state the record does not support, and that is symmetric in direction. The lane
correctly did everything available to it: corrected all six false claims, recorded the verified closure
with line-exact citations, kept the count at four, put **both** facts in the A1 heading, and routed the
register action with precise text. Declining to over-claim is precisely the behaviour this work item
has spent three review cycles asking for. **This is not an unregistered refusal to close a closed
item; it is a registered refusal to close an item whose *register* is not closed, with the technical
closure recorded as verified fact.**

**Incomplete — and this is a finding, not a nuance (H-R2).** Having declined to touch the register,
the lane still owed the *section* a truthful label, and did not update it: `:687` says "Nothing here is
closed". So the revision produced the worst of the two worlds for a reader scanning the section: the
entry says closed, the preamble says nothing is closed, and neither is marked. The safe action was
taken; the free action adjacent to it was not. **The fix needs no authority at all** — it is inside
`OWNED_PATH`.

**The stakes, verified.** `20261006150645000` **is** on `main` and **is** the newest migration (I
listed `apps/server/migrations/` — the predecessor `20261001205247600` is still there, as `:583` says).
And the revocation clause remains genuinely one-sided: `revokeCredential` writes the audit row and
**nothing destroys a manager handle**. Both halves of that are recorded correctly in the ADR, in the
`876c6b97` note, and in revision §5 — the lane was careful not to let a closed gap launder an open one,
which is the exact error the opposite mistake invites.

**If I were the Manager, the routing would be one item, not two:** "A1's exposure is closed on `main`;
the entry stands pending your retirement decision." The lane got that right.

---

# 7. WHAT I DID **NOT** REVIEW — stated explicitly

- **The lost revision-2 review.** Does not exist on disk. No baseline existed for it or for me; if it
  resurfaces with findings beyond HIGH 1, HIGH 2 and G-17 they are unaddressed.
- **Runtime behaviour of anything.** **I ran no Docker or Compose command of any kind** — not `info`,
  not `ps`, not `logs`, not `config`, not any mutating one. The rule was not tested. **A3 reachability
  (G-c) therefore remains UNVERIFIED and I make no claim about it.** No git transport was exercised.
- **The nine resolved decisions' merits.** I verified the *citations into* them and that the appended
  notes are append-only and faithful. I did not re-open or re-adjudicate any of the nine.
- **`27ea6536`'s Penpot board measurements.** G-19's finding depends on Penpot reads; I verified only
  the corroborating code string at `add_product_page.dart:383-384` and the decision-object text. The
  four-board measurement is the keys lane's claim and I did not reproduce it. That lane is out of my
  scope.
- **`fix/credential-identity-invariants`' `APPROVE_WITH_NON_BLOCKING_FOLLOWUP` verdict** — still
  untracked on disk (the rev-3 review flagged this). A real blocker for *that* work item, not this one.
- **Production code correctness.** I read cited lines to check the ADR's *citations*, not to review the
  credential implementation for defects. I found L-R2 by reading the register flow; that is a
  consequence of checking a citation, not a code review.
- **Revisions 1, 2 and 3 as artifacts** — verified byte-untouched (revision 3's report: sha256
  `b1d14b71…` preserved), not that their content was right.
- **Design-system / UX-accessibility as gates.** `PASS (not applicable)` — revision 4 authors no UI.
  I did **not** review the mobile copy at `add_product_page.dart:542`/`:1038`; I confirmed the string
  exists at both sites but the copy constraint is the mobile lane's to discharge. F-9's new copy
  constraint (no copy may present that screen's key as installable) is correctly recorded and routed.
- **Terraform / infrastructure claims** (F-2, gap A4) — not re-verified by me this pass; out of the
  focused scope, and unchanged from the rev-3 review which verified them line-exact.
- **The mobile and keys lanes' revisions** — out of scope; I read only `27ea6536`'s note, as the
  dispatch asked.

---

# 8. Structured result

```
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED

REVIEWED_HEAD: 289f1d3 (worktree /private/tmp/shipit-design-adr0018, branch design/adr-0018-amendment).
               The ADR amendment is UNCOMMITTED: 999 lines in the worktree, 580 on main. main has
               advanced past the dispatched af8e30f to bd01bc0; design-revision-4.md and
               design-revision-metadata-4.yaml actually landed at 1c3f5ad. Revision 3's report is
               preserved byte-identical as report-revision-3.md (sha256 b1d14b71…).

REVISION_ID: ADR0018-A2-REV4

BLOCKERS:
  none.

  My independent W1-W6 count is ELEVEN confirmed fixed and ZERO additional scope-class sites, so the
  sweep was complete for its stated axes and I do not raise the blocker the dispatch anticipated.

HIGH:
  H-R1 — `9417f8bf:116-119` is a WRONG citation and revision 4 propagated it into a resolved human
         decision object. :116-119 is the tail of a fail-open/fail-closed assessment plus the head of
         the "Insider/backup exposure" dimension; the quoted "permissions do not defend against a
         same-uid process — which is the git transport" is at :159-160, with a second independent
         same-uid metric at :96-97. Present at five ADR sites (:144, :184, :840, :862, :935), in
         design-revision-4.md §11.1, in revision §1.4's decline table (which also mis-cites :194-201 as
         same-uid source — it is OPTION_D's description), and in the note the Manager actually applied at
         .decisions/9417f8bf:266-268. The SUBSTANCE is correct and the reconciliation holds; only the
         pointer is wrong — which is precisely the failure mode ADR :152-154 argues is worse than an
         absent claim. Fix: re-anchor all sites to :159-160 (naming :96-97 as the second witness) and
         append a one-line dated correction to .decisions/9417f8bf. Do not edit the existing note.
  H-R2 — ADR :687-688, the §Accepted risks preamble, still reads "Nothing here is closed" — which
         revision 4 made FALSE, and which the A1 heading it rewrote 23 lines below (:711-712) now
         contradicts without a marker. Section-level normative claim falsified by the document's own
         body, on the exact M-4 axis, in the section revised most. :691's narrower phrasing ("None is
         closed by the wording changes") shows the distinction was known and simply not applied at
         :687. Fix inside OWNED_PATH; needs no authority.
  H-R3 — Revision 4 grew the ADR by 188 lines and left three internal `:NNN` citations pointing at the
         wrong text; one was INTRODUCED by revision 4. The :52-55 convention scopes pre-revision line
         numbers to §Amendments only, so all three are current-file citations. :447 cites `:219` for
         §"What survives A2 unchanged" (actually :237/:242) — new text, an 811-line number copied from
         the revision-3 review. :943 and :945 cite `:37-40` for the marking convention (actually
         :52-55). :948 cites `:137-139` for "a false absolute is worse than an absent one" (actually
         :152-154) — the §Related scope note justifying itself with a wrong pointer, which is
         self-refuting. Fix: re-anchor all three.

MEDIUM:
  M-R1 — .decisions/876c6b97:122-123 still carries "independent design review of the amendment has still
         never happened", a SECOND false standing claim of the S-6 class. Revision 4 fixed the identical
         claim in the ADR's §Status and did not propagate the fix to the object it names as the citable
         authority for acceptance — the one place a reader is most likely to land. Neither the appended
         note nor the ADR mentions it. Compounding: ADR :913-914 ("The independent review of revision 4
         has not happened") is the same perishable form and this review is that review. Fix: append a
         dated note to 876c6b97 superseding the rationale's wording WITHOUT editing it, and re-state ADR
         :913-914 in a form that survives its own expiry.
  M-R2 — §1.4's decline ledger is incomplete. The document TITLE (:1, "ADR 0018: Per-Product Git
         Credentials") is the most prominent unmarked per-product statement in the file: neither fixed
         nor recorded as a decline, though there is a legitimate reason to keep it. Separately §Known
         gaps :848 says "Remaining items" and now holds two CLOSED entries, one of them added by
         revision 4 (:885), following a pre-existing inconsistency it widened. Fix: articulate the title
         decision in §1.4 and either re-head §Known gaps or move closed entries to a "Closed" heading.
  M-R3 — Revision 4's F-8 recommendation (require a class-sweep with a stated axis list) is right and is
         how this review found H-R1..H-R3. But the axis list must also name REFERENCE RESOLUTION: M-3
         proved the citation class and the sweep then covered only hex tokens. Recommend adding a
         contract clause that every file:line / :NNN cross-reference in the edited artifact resolves or
         is explicitly marked as referring to a named prior revision — mechanically checkable, and I
         detected this entire class with one script.

LOW:
  L-R1 — `reviewed_by: null` is CORRECT and I endorse keeping it, but for a durable reason rather than
         the one given: CHANGES_REQUIRED is not a signature, and "never reviewed" and "reviewed and not
         approved" are the same operational state downstream. The durable justification is that no
         reviewer has APPROVED any revision of A2. State it that way, and drop the "stays null until a
         reviewer signs it" prescription — a prescription keyed to a contingency is how S-6 was born.
  L-R2 — F-9 is stronger than recorded. _onRegisterProductRequested (:145-181) never transmits the key
         at all — there is no credential-creation call — and passes `repositoryId: productId` with a
         "for simplicity" comment, so the shipping build VIOLATES A1's scope invariant. That is more
         than mock-key hygiene and belongs in §Known gaps. The "partly built" marking remains correct.
  L-R3 — The Manager's applied notes are append-only and faithful: 9417f8bf 42/0; 876c6b97 and 27ea6536
         1 removed line each, being exactly the updated_at replacement carrying an inline comment, below
         the marker. Quotes match verbatim; counts unchanged; human_correction_verbatim preserved
         unedited with the owner's spelling explicitly protected. The 27ea6536 framing claim — that the
         OVERRULED thing was the lane's CONCLUSION and not its OBSERVATION, and the owner was entitled
         to reverse it — is ACCURATE on the object's own text and is the right judgement. Both open
         items are correctly routed rather than decided.

INDEPENDENT_RISK_LEVEL: 3
RISK_LEVEL_AGREEMENT: YES

TRACEABILITY_GAPS:
  - Line-number cross-references are not covered by any of W1-W6 and are not a declared axis. Five
    resolve into the wrong text; one of those was introduced by revision 4 and one was propagated into a
    resolved human decision object. This is the same referential-integrity class as M-3, unswept.
  - The same-uid exposure (G-b) is now FILED in §Known gaps and still has NO OWNER. Correctly not
    self-assigned and correctly not made a fifth accepted risk; it needs an ownership grant from the
    Manager.
  - Accepted risk A1's exposure is closed on main; the register entry is not retired and the count is
    four. Correct routing, still open, and it needs the owner's decision — not a design lane's.
  - F-9's UI mock is filed; the register-flow omission and the `repositoryId: productId` A1 violation
    discovered here are not yet filed anywhere.
  - The lost revision-2 review: if it surfaces with findings beyond HIGH 1, HIGH 2 and G-17 they are
    unaddressed.
  - No formal Design Brief exists for this work item across revisions 1-4; the dispatch header served as
    one. Correctly recorded rather than fabricated — I endorse it, but the lifecycle gap is real and
    permanent until a brief is authored.

CORRECTION_REQUIRED: YES

HUMAN_DECISION_REQUIRED: NO
  Reasoning, so it can be challenged: none of H-R1..H-R3 or M-R1..M-R3 requires a human to choose between
  options — each has exactly one correct repair and every one is either inside the producing lane's
  OWNED_PATH or an append-only note, which is the device this framework already prescribes for
  CONTRADICTION (LEARNING_POLICY.md:261). Inventing a gate here would be the process-form of the same
  error revision 4 correctly avoided.
  I specifically considered and REJECTED raising a gate over M-4's boundary, on the ground the rev-3
  review used and for the same reason: the A1 register is the owner's, the lane did not touch it, and the
  technical closure is recorded as verified fact with line-exact citations. The item I DO raise about it
  (H-R2) is a stale section label inside OWNED_PATH, not the retirement itself.
  The two items that genuinely need the human — retiring A1, and an owner for the same-uid exposure —
  are already routed with precise text, and re-raising them here would duplicate rather than escalate.

HUMAN_DECISION_TYPE: DESIGN

SAFE_PARALLEL_WORK:
  - Applying the M-R1 second dated scope note to .decisions/876c6b97 (append-only; do not edit the
    existing note or the rationale).
  - A lane owning add_product_page.dart (F-9 + L-R2): the register flow never transmits the key and
    passes repositoryId: productId. Read ADR §Decision status first — no copy may present that screen's
    key as installable.
  - A lane owning repository_credential.dart doc comments (:14-15, :70-71 stale; :20-27 correct).
  - design-reviewer lanes for the keys and mobile items — no path overlap with docs/adr/0018.
  - Read-only mechanical work: a repo-wide check that every file:line citation in docs/adr/** resolves.

PROHIBITED_PARALLEL_WORK:
  - Any lane writing docs/adr/0018-per-product-git-credentials.md — H-R1/H-R2/H-R3 and M-R1/M-R2 are all
    in the producing lane's OWNED_PATH. SERIALISE the correction; do not run two writers over the ADR.
  - Any lane editing the resolution rationale or human_correction_verbatim in ANY .decisions/** object.
    The remedy for M-R1 is an APPENDED dated note, never an edit. A verbatim quote is not a file listing.
  - Retiring or re-counting accepted risk A1 by a design lane — the owner's register.
  - Dropping, popping, applying or modifying EITHER stash. Verify by LABEL, never by index.
  - Any Docker or Compose command from a lane without deployment authority. This repository has already
    lost its QA database to exactly that.
```

---

# 9. What the producing lane got right — and it is a lot

The eleven are eleven. Not "roughly eleven", not "the four plus padding": I re-derived them with my own
greps on all six axes and found **no twelfth**. That is the question the dispatch said mattered most,
and
the lane's number survives it.

Three things are genuinely excellent and I record them as such:

**H-1's re-grounding is correct.** I read `repository_credential.dart:61-122` field by field — 21
fields, no private-key material — and confirmed the claim now rests on evidence that supports it,
with the stale doc comments named as *not* the evidence rather than quoted as support. The reviewer's
central worry (that swapping cited evidence for different evidence is the change most likely to be
wrong) did not materialise.

**H-2b's substance correction holds.** The old §Positive bullet argued *in favour of* the design from a
premise the document had abandoned; a marker alone would have satisfied the convention and left the
argument standing. The replacement is a real argument, not a paraphrase: per-repository scoping buys
strictly narrower fleet isolation, and it **moves cost rather than removing it** — n repositories, n
rotations. The honest cost is left in §Negative, which already had it.

**M-4 did not let a closed gap launder an open one.** Having verified the resurrection path is closed,
it explicitly kept the revocation clause at *partly built* and wrote the two-part split into §Positive
(`:493-500`). That is the harder half of the work and it is where a lesser lane would have
over-claimed.

And the process findings are real: the stale-stash-index hazard (F-12) is a genuine dispatch-citation
failure mode, the 8-hex/7-hex ambiguity (F-13) is a real class, and **S-6 — G-17's own defect class
reproduced by the revision that fixed G-17 — is the most valuable single observation in this work
item.** A correction pass that repairs its finding set reliably leaves the class alive, and that is a
lesson the framework should encode.

The gap is narrow, specific and consistent with everything above: **the axis list was one axis short of
its own thesis.** W1–W6 swept *claims*. The class also includes the *references into* those claims,
and revision 4 had just been handed a finding (M-3) proving that class exists.

---

# 10. Files touched

```text
docs/engineering/dispatch/tasks/design-rereview-adr-0018-a2-rev4/report.md
```

That is the entire list, inside `OWNED_PATHS`. **Nothing else was modified.** I ran **no Docker or
Compose command of any kind** — not `info`, `ps`, `logs` or `config`, not any mutating one. I read
`docs/adr/**` read-only including ADR 0018. I issued **no `stash`, `checkout`, `reset`, `merge`,
`commit`, `push` or `clean`** in either worktree; both stashes were read by label and are intact and
byte-identical to `main` where the label claims it.

## Validation results

| Command | Result | Note |
|---|---|---|
| `git rev-parse` (worktree) / `wc -l` ADR | pass | `289f1d3`; **999** lines worktree / **580** `main` |
| `git status --short` (worktree) | pass | one ` M` (the ADR) + six untracked task artifacts |
| `git ls-tree -r main -- …design-review-adr-0018-a2-rev3/` | pass | `prompt.md`, `report.md`; `RESULT: DESIGN_REVIEW_CHANGES_REQUIRED`, `REVIEWED_HEAD: 289f1d3`; added `16cd497` — **confirms S-6** |
| `git log --all --diff-filter=A -- <full paths>` ×3 | pass | rev-4 artifacts at **`1c3f5ad`** (dispatch said `af8e30f`); `report.md` at `16cd497` |
| `shasum -a 256` report.md@16cd497 vs report-revision-3.md | pass | `b1d14b71…` / `b1d14b71…` — **revision 3's report preserved** |
| ADR stash resolved **by label** vs `main` ADR | pass | `9e5b4772…` / `9e5b4772…`, both 580 lines — **byte-identical; both stashes untouched** |
| `git log -n1 570bb640` | **fail (ADR defect, now fixed)** | *unknown revision* — decision object |
| `git ls-tree main -- .decisions/` | pass | 14 objects; `570bb640` present, `type: DEPLOYMENT_AUTHORITY`, `RESOLVED` |
| `git show 1c3f5ad -- .decisions/` ×2 | pass | 9417f8bf **42/0**; 876c6b97 **37/1**, the 1 being the `updated_at` replacement below the marker with an inline comment |
| `git show af8e30f -- .decisions/27ea6536…` | pass | 58/1, same shape |
| `git show main:` ×5 code files (M-4, H-1, F-9) | pass | every cited line **exact**; two tiers agree |
| W1–W6 re-run (6 axes, whole document) | pass | **11 confirmed fixed, 0 additional scope-class sites** |
| `:NNN` cross-reference resolution (script, whole ADR) | **5 broken** | H-R1 (:116-119 ×5 sites) + H-R3 (:219, :37-40 ×2, :137-139) |
| `.decisions/**:NNN` resolution (script, 10 objects) | pass | all others resolve |
| `git ls-tree main -- apps/server/migrations/` | pass | `20261006150645000` present and **newest** |
| **Docker / Compose — any command** | **NOT_RUN** | Deliberately. None issued, not even read-only. Rule not tested |
| A3 reachability runtime probe | **NOT_RUN** | Needs Docker, outside scope. **No probe claimed; G-c stays UNVERIFIED** |
| Penpot board measurement (G-19) | **NOT_RUN** | Keys lane's scope; I verified only the code string at `add_product_page.dart:383-384` |

## Evidence (revision-pinned)

```yaml
EVIDENCE_REVISION: 289f1d3   # worktree; the ADR amendment is UNCOMMITTED (999 lines)
REVERIFIED_AGAINST: main bd01bc0  # 08c7590 is an ancestor; no M-4 claim moved
BUILD_COMMAND: n/a — documentation / architecture record only
SERVE_OR_RUN_COMMAND: n/a — nothing built, served or executed
ENVIRONMENT / BASE_URL: n/a
ARTIFACTS:
  - /private/tmp/shipit-design-adr0018/docs/adr/0018-per-product-git-credentials.md   (999 lines, UNCOMMITTED)
  - /private/tmp/shipit-design-adr0018/docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-4.md
  - …/design-revision-metadata-4.yaml   …/report.md   …/report-revision-3.md
  - .decisions/876c6b97-…yaml  (200 lines, read IN FULL, incl. its four knowingly-open gaps)
  - .decisions/9417f8bf-…yaml  (281 lines, read in full)
  - .decisions/27ea6536-…yaml  (218 lines, read in full)
  - docs/engineering/dispatch/tasks/design-review-adr-0018-a2-rev3/report.md   (MY BASELINE)
  - stash@{1}  docs/adr/0018-per-product-git-credentials.md  (sha256 9e5b4772… — resolved BY LABEL, INTACT)
```

## Documentation updated

```text
docs/engineering/dispatch/tasks/design-rereview-adr-0018-a2-rev4/report.md
```

## Model and reasoning effort

```yaml
ROUTING_CLASS_REQUESTED: PRECISION
MODEL_USED: opencode/space-bunny-free
REASONING_EFFORT: n/a
ESCALATED_INSIDE_TASK: NO
ESCALATION_REASON: n/a
```

## Recommended next action

**`CORRECTION_LOOP`** against `ADR0018-A2-REV4` for **H-R1, H-R2, H-R3** and **M-R1, M-R2** — all inside
the producing lane's `OWNED_PATH` except the one append-only note in `.decisions/**`, which is
Manager-owned and should be applied with the same device as the two existing notes.

Then a **narrow focused re-review of these five findings plus regression risk only** — not a third
full sweep of W1–W6, which I have now run independently and confirmed at eleven.

In parallel: route F-9 (now including L-R2's register-flow omission and the `repositoryId: productId`
A1 violation), F-10, the A1 retirement decision, and an owner for the same-uid exposure.
