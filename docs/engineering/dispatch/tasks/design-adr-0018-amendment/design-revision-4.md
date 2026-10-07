# Design Revision 4 — ADR 0018 amendment A2: sweep the stale-normative-text class

**Supersedes Design Revision 3** (`design-revision-3.md`, `design-revision-metadata-3.yaml`) as the
current description of amendment A2's design state. Revisions 1, 2 and 3 are **retained unaltered**
as history, per this ADR's own convention at `:37-40` ("Amendments are recorded by revision, not by
silent rewrite").

Revision 3 repaired the findings it was given and did not sweep the class they belong to. The
independent review of revision 3 said so in terms worth repeating verbatim, because the instruction it
gives is the whole content of this revision:

> The defect is not a one-off; it is a class, and G-17 is the third instance of it. … Revision 3 fixed
> G-17's instance properly. It did not sweep the class — and adopting the lane's framing ("the defect
> was the tense") licenses exactly the outcome the dispatch warned against: two sentences repaired,
> the stale-and-unmarked normatives left standing.
>
> The correct generalisation for the next pass: ADR 0018's defect is **systemic stale-but-unmarked
> normative text**, and the repair is a sweep of every normative claim against the amendment ledger,
> not a repair of individually-reported findings. B-1, H-1 and H-2 are what that sweep finds. I would
> rather say that than approve a document that has been corrected at three points and is wrong at four.

| Field | Value |
|---|---|
| Task | `design-correct-adr-0018-a2-3` (correction pass) |
| Revision number | 4 |
| Supersedes | `ADR0018-A2-REV3` (`status: DRAFT`, `reviewed_by: null`) |
| Branch | `design/adr-0018-amendment` |
| Base SHA | `289f1d3` (worktree HEAD — **unchanged**; no commit, no rebase, no fast-forward) |
| Re-verified against | **`main` `c6f301d`** (dispatch stated `16cd497`; `main` had advanced one further commit) |
| Worktree | `/private/tmp/shipit-design-adr0018` |
| Artifact corrected | `docs/adr/0018-per-product-git-credentials.md` (811 → 999 lines) |
| Risk level | **3** (unchanged — see §7) |
| Status | **DRAFT — correction. Never independently reviewed.** |

---

## 0. Scope, ownership, provenance corrections

### OWNED_PATHS — as declared, and what was actually written

- `docs/adr/0018-per-product-git-credentials.md` — **the only file written outside this task
  directory.** ✅
- `docs/engineering/dispatch/tasks/design-adr-0018-amendment/**` ✅

### PROHIBITED_PATHS — written: none

`.decisions/**` — **read only.** The two files that needed editing for H-3/F-1 are Manager-owned; the
**precise note text is reported in §11 and NOT written here.** No ADR other than 0018. No production
source. No QA artifacts.

### Two provenance corrections to the dispatch, both verified before acting

**1. `BASE_SHA` in the dispatch is `16cd497`; `main` was at `c6f301d` when this lane started.**
`16cd497` is an ancestor of `main` (`git merge-base --is-ancestor 16cd497 main` → yes). The worktree
was **not** fast-forwarded, because the dispatch forbids nothing on this point but the ADR amendment is
**uncommitted** — a fast-forward would have to either carry or conflict with it, and the reviewed
provenance is `289f1d3`. So the worktree stays at `289f1d3` and everything M-4 required is verified
**against `main` explicitly**, by `git show main:<path>`. `c6f301d` is
"docs(state): record the 08c7590 merge, all three review verdicts, and the stale-normative-text
class" — i.e. the commit that recorded this very class as a repository fact.

**2. `stash@{0}` is NOT the ADR stash the dispatch described.** The dispatch says the preserved ADR
edit is at `stash@{0}`. It is at **`stash@{1}`**:

```
stash@{0}: On design-correct-addproduct-mobile: rev5-uncommitted-identical-to 16cd497
stash@{1}: On design/adr-0018-amendment: ADR0018 A2 rev1 local edit (superseded by main 5436a4d;
           sha256 9e5b4772) -- preserved, do not drop blindly
```

A concurrent lane created a new `stash@{0}` after the dispatch was written, which pushed the ADR stash
down one index. **This is exactly the trap the dispatch warned about — an index that moved under a
citation.** Recorded because a future reader following the dispatch literally would inspect the wrong
stash. I verified the content the label claims, by label rather than by index:

- `git show 'stash@{1}:docs/adr/0018-per-product-git-credentials.md' | shasum -a 256` →
  `9e5b47723e40fd0fd42b69ddf4b5330768ca4fcf782acb0f1992e7aebb83b4fb` — **matches the label's stated
  sha256 prefix and revision 3's V-10**, so the preserved content is intact.
- **I did not drop, pop, apply, or modify either stash.** `git stash list` is byte-identical to what I
  found. Both stashes remain.

### No Docker or Compose command was issued by this lane

Not `info`, not `ps`, not `logs`, not `config`, not any mutating one. This repository has already lost
its QA database to a review lane running `docker compose -f docker/compose.qa.yaml down -v --rmi
local`. Every finding below is a `git` query, a file read, or an `rg`. Compose files and Terraform
were read **as text**.

### This lane does not approve its own work

Revision 4 has **never been independently reviewed**. `reviewed_by` and `reviewed_at` are `null`;
`status` is `DRAFT`. The independent review of revision 3 exists and returned `CHANGES_REQUIRED`; this
revision responds to it. The independent review of **revision 4** has not happened and is the next
step. See §2 — correcting a false claim about review status is the one thing this lane is most
careful about here.

---

## 1. The sweep, and what it found

### 1.1 The method, stated so a reviewer can check it

The ADR's own convention at `:37-40` requires every superseded clause to carry a marker naming the
amendment that superseded it. Revision 3's error was treating the four reported sites as the scope of
work. So the sweep was run as **six greps over the whole document**, one per superseded axis, plus a
read of every section against the amendment ledger — not as four targeted edits.

| # | Axis swept | What "unmarked" means for that axis |
|---|---|---|
| W1 | **per-product scope** | any clause asserting the product as the unit of scope, unmarked |
| W2 | **custody (local secret store / operator device)** | any clause asserting A1 custody as current, unmarked |
| W3 | **rotation scope** | any clause asserting rotation as per-product, unmarked |
| W4 | **revocation** | any clause asserting provider-native / no-ShipIt-side-action, unmarked |
| W5 | **key-count arithmetic** | any "N products ⇒ N keypairs" claim, unmarked |
| W6 | **reference-name format** | the pre-A1 `GIT_PRODUCT_<productRef>_SSH` form asserted as current |

Each grep's hits were then adjudicated one at a time: **marked already** (leave), **quoted history in
a dated correction block** (leave), **correct as written** (leave), or **unmarked and normative**
(fix). That last category is the class.

### 1.2 The result — and the number is the point

**The four reported sites were not four instances of a bounded set. The sweep found eleven.**

| ID | Site (at 811-line revision) | Axis | Disposition |
|---|---|---|---|
| B-1 | `:272-273` §Decision **headline** — "scoped per product, not per platform" | W1 | reported → **FIXED** |
| H-2a | `:384-385` §Decision → Specifics — "Rotation is per product" | W3 | reported → **FIXED** |
| H-2b | `:401` §Positive — "Rotation blast radius is one product, not the fleet" | W3 | reported → **FIXED** |
| H-1 | `:287` §Decision status row 2 — "Built: yes" citing doc comments that assert superseded custody | W2 | reported → **FIXED** |
| **S-1** | `:362-364` — public half "install as a deploy key on **the product's repository**"; no table row for the clause | W1 | **NEW** → FIXED |
| **S-2** | `:365-368` — reference example `GIT_PRODUCT_<productRef>_SSH`, the **pre-A1 form**, asserted as current | W6 | **NEW** → FIXED |
| **S-3** | `:429` §Negative — "**N products means N keypairs**", four bullets above the §Negative bullet that contradicts it | W5 | **NEW** → FIXED |
| **S-4** | `:448-449` §Mitigation — "UI surfaces key state **per product**" | W1 | **NEW** → FIXED |
| **S-5** | `:451-452` §Mitigation — "dedicated **per-product page**", with rotation implied as one act | W1+W3 | **NEW** → FIXED |
| **S-6** | `:6-21` §Status — "the Design Revision … **has never been independently reviewed**" | *review-status* | **NEW → FIXED. This is G-17's own class, reproduced by the revision that fixed G-17.** |
| **S-7** | `:191-193`, `:292`, `:417-420`, `:515-517`, `:625-630`, `:638-641` — six claims about accepted risk A1, all false against current `main` | *state-freshness* | **NEW → FIXED** (this is M-4, and the sweep found **six** sites, not the three the review named) |

**S-6 deserves its own paragraph, because it is the strongest evidence in this revision that the
sweep was necessary.**

### 1.3 S-6 — the sweep found G-17's defect class in the very sentence revision 3 wrote to fix it

§Status `:17-21` read:

> The Design Revision recording A2 … **has never been independently reviewed**; `reviewed_by` is null
> and stays null until a reviewer signs it.

That was **false**, and it is the identical shape of defect revision 3 existed to eliminate:

| | G-17 (revision 3's finding) | S-6 (found by this sweep) |
|---|---|---|
| Claim | "**no** Human Decision object records this acceptance" | "**has never been** independently reviewed" |
| True at | `43d328b` | until the rev-3 review landed |
| False against | `5436a4d`, **the same commit that wrote the claim** | `design-review-adr-0018-a2-rev3/report.md`, which exists **on `main` today** |
| Device | a recommendation to create an object that already existed | a **prescription** — "stays null until a reviewer signs it" |
| Class | fact with a shelf life written as a standing claim | **identical** |

Verified: `git ls-tree -r --name-only main -- docs/engineering/dispatch/tasks/design-review-adr-0018-a2-rev3/`
returns `prompt.md` and `report.md`; the report's `RESULT` is `DESIGN_REVIEW_CHANGES_REQUIRED`,
`REVIEWED_HEAD: 289f1d3`, `REVISION_ID: ADR0018-A2-REV3`.

**The load-bearing point of the sentence — acceptance is not review — survives intact and is now
stated truthfully**: `reviewed_by` is still `null`, because a `CHANGES_REQUIRED` verdict is not a
signature; revision 4 responds to that review and is itself unreviewed. A reader loses nothing and
gains the truth. The same false claim also appeared in revision 3's own metadata (`review_note`:
"Independent design review HAS NEVER HAPPENED for this artifact, at any revision") — retained
unaltered there as history, corrected here, which is the same treatment revisions 1 and 2 received.

**Had I fixed only the four reported findings, this sentence would still be telling a future reader
that no independent review of this work exists — and there is one, with ten findings in it.**

### 1.4 What the sweep found and deliberately did **not** change

Recording these matters as much as the fixes: a sweep that only accumulates findings is a search, not
a judgement.

| Hit | Why left alone |
|---|---|
| `:59` A1 amendment row — "one keypair per product → one keypair per repository" | already marked; the old text is **struck** in the table |
| `:64-65` A1 "Previous (superseded)" | already labelled superseded |
| `:379-384` §Decision Specifics first bullet | already marked **SUPERSEDED (A1)** *and* **SUPERSEDED (A2) in part** — the model for what a correct marker looks like |
| `:478` §Positive revocation | already marked **SUPERSEDED (A2)** |
| `:520` §Negative deploy-key constraint | already marked **SUPERSEDED (A1)** |
| `:38` the convention statement itself | the device, not an instance |
| `:877` §Known gaps rotation entry | was an open gap; **closed and rewritten** rather than left (§1.5) |
| `:295-302` §Decision headline **after** the fix | struck + marked + current stated; the sweep's own output |
| `:109-139` "never holds key bytes" scoping | bounded three ways by revision 3; no unmarked residue |
| `:189-193`, `:478-497` custody/revocation clauses | marked or explicitly "specified, not built" |
| `9417f8bf:116-119`, `:194-201` | correct, current, and cited **as** the source of the same-uid reasoning |

### 1.5 G-e closed rather than restated

Revision 3 recorded G-e — "§Known gaps: rotation still described in product scope in two places" —
and declined to fix it as "out of scope". The reviewer rejected that (H-2). Revision 4 fixes both sites
and **closes the gap entry**, restating it as history. Three sites are now corrected, not two, because
the sweep found a third (§Mitigation, S-5) and a fourth (§Negative key count, S-3).

---

## 2. The findings, one by one

### B-1 — §Decision's normative headline asserted the scope A1 superseded — **FIXED**

`:272-273` read *"Each product owns its own SSH keypair. Git credentials are scoped per product, not
per platform."* Struck, marked **SUPERSEDED (A1)**, with §Amendments A1's own reason quoted (a
per-product key "is not installable for a multi-repo product") and the current per-repository scope
stated. The internal contradiction the reviewer identified is now gone: the headline, the §Decision
status row 14 lines below, and §Amendments A1 all say the same thing.

### H-1 — "Built: yes" resting on evidence that asserted the superseded custody model — **FIXED**

The row's *claim* was correct — `RepositoryCredential` has no key-material field — but it pointed at
`:12-18` and `:70-72`, whose doc comments say custody is **the operator's local secret store**. A
`Built` claim whose evidence names the wrong custodian is worse than no claim, because it transfers
confidence it has not earned.

Now: cites the **field declarations** `repository_credential.dart:61-122` (the whole list; there is no
private-key field — *that* is the evidence), and states explicitly that the doc comments are stale
rather than quoting them as support:

> **The doc comments either side of it are stale and are NOT the evidence:** `:14-15` still says the
> private half "is written to the operator's local secret store" (**stale by A2 — custody**) and
> `:70-71` repeats it plus the pre-A1 example name `GIT_PRODUCT_<productRef>_SSH` (**stale by A2 and by
> A1**).

**Verified the fix is not self-serving:** `:20-27` of the same file is *correct* about scope ("Scope is
one repository, not one product"), so the file is right where A1 governs and stale where A2 governs —
the same asymmetry the reviewer described, now stated as such rather than leaned on. The stale comments
are **production source**, which this lane may not write, so they are filed as an **implementation
follow-up in §Known gaps** rather than fixed here. That is the honest disposition: the claim is
re-grounded on evidence that supports it, and the stale evidence is named rather than deleted.

### H-2 — rotation clauses, one of them listed as a benefit — **FIXED, both**

`:384-385` and `:401` are struck and marked **SUPERSEDED (A1)**, with per-repository rotation stated
as current and built (`rotateCredential` revokes then mints a new `credentialId`).

`:401` needed more than a marker, and this is the part worth a reviewer's attention: it sat in
**§Consequences → Positive**, so the superseded scope was presented as an argument *in favour of the
design*. Marking it SUPERSEDED would have satisfied the convention and left the document arguing from
a premise it had already abandoned. Its substance is now corrected:

> **Rotation blast radius is one repository, not the fleet — and one *product* is no longer the unit an
> operator rotates.** Per-repository scoping buys the fleet-wide isolation this bullet credited to
> per-product scoping, and buys it strictly more narrowly, **but it moves cost rather than removing
> it**: a product with *n* repositories has *n* keys to rotate, verify and reinstall.

And the honest version of that cost is where it belongs — §Negative, which already said it correctly at
the time (S-3).

### H-3 — two governing decisions cited as authority while carrying the absolute the ADR corrected — **FIXED IN PART; the rest reported with exact text**

**The in-scope half is done.** §Related → "Decisions governing amendment A2" now carries a **dated,
attributed scope note** — the device `LEARNING_POLICY.md:261` prescribes for a `CONTRADICTION` and the
one `:37-40` already uses. It states that both objects carry the pre-correction absolute, tables **all
four sites** (`9417f8bf:113`, `:140`, `:210`; `876c6b97:20`), says the decisions are **not re-opened**,
notes that `9417f8bf:116-119` already contains the correct same-uid reasoning so each object is
internally inconsistent, and points at §Related → "The acceptance itself". The A2 amendment-row and the
`876c6b97` list entry cross-reference it. **The ADR's own citations are unchanged** — nothing here
implies the objects say otherwise.

**F-1's scope is four sites, confirmed by reading both objects in full.** `:140` is the load-bearing
one and is called out as such: *"the **only** option under which SHIP IT never holds key bytes at
all"* — the uniqueness argument the human actually read. A two-line fix would leave that standing on a
false premise. The uniqueness argument does survive at rest (A1 and A2 both write bytes at rest), and
the note says so rather than implying the choice was wrong.

**The upstream half is reported, not written.** `.decisions/**` is Manager-owned. Exact text in §11.

### M-1 — §Decision status did not cover every clause it appeared to — **FIXED by adding rows**

`:281`'s "Every clause below is therefore marked" is now scoped to what the table actually covers
("Every normative clause in §Decision → Specifics"), **and** the two missing rows were added rather
than the sentence narrowed alone — narrowing would have made the table useless for the UI clause:

- **Public half surfaced in the UI** — new row, and adding it **surfaced a real defect**: the UI
  surface is genuinely built (`add_product_page.dart:547`, `:1043`, with copy affordances at `:558`,
  `:1054`), **but the value is a client-side mock** — `_generateMockKeyPair` at `:126-138` builds 32
  bytes from `Random.secure()`, labels them `ssh-ed25519`, and fingerprints a 16-byte digest. **No
  server-issued public half reaches the UI**, so an operator who installs what that screen offers gets
  a key registered nowhere — the "non-installable mock" `73097d48` was issued to replace. This is the
  **third** partly-built clause; the count moved from two to three. The negative half (no secret value
  typed in) is **yes** — no control-plane widget accepts a private key.
- **Rotation per repository** — new row, **yes/yes**, evidence `rotateCredential`.

Table is nine → **eleven** rows; the consequence paragraph and the partly-built count were updated to
match, so the document is internally consistent about its own inventory.

### M-2 / G-b — the same-uid exposure had no home — **FIXED (surfaced *and* filed)**

Revision 3 was right not to create a fifth accepted risk and wrong to stop there. Both halves now hold:

- Under §Accepted risks, the bullet is **explicitly not counted** and says so where a reader will see
  it — its position under an `ACCEPTED` header is now called out as the reason it is not the discovery
  point, and it cross-references §Known gaps.
- **§Known gaps carries the entry**, which is that section's declared purpose ("Remaining items.
  None of these is one of the four accepted risks"). It states the exposure, names why no owner
  exists (`876c6b97:136-161` assigns gap A2 to the design agent and gaps A3/A4 to implementation and
  deployment authority; this belongs to neither), records the reviewer's **substrate-independence**
  reasoning — SHIP IT pushes git itself, so it must materialise the private half under A1, A2, A3 and
  A4 alike; it follows from `b869ec24`'s server-side move, not the custody choice — and marks it
  **surfaced for the Manager to route, not self-assigned**.

Filing needed no owner authority and changed no clause of the owner's answer. That was available and
was not done; it is now done.

### M-3 — `570bb640` cited as a commit; `git log` on it fails — **FIXED**

Confirmed independently: `git log -n1 570bb640` → *"fatal: ambiguous argument: unknown revision"*; it is
`.decisions/570bb640-76e1-485d-9a80-309b07585ccd.yaml` (DEPLOYMENT_AUTHORITY, `RESOLVED`).

I swept **every** 8-hex token in the ADR, not just the reported one, and classified each — because M-3
is a class too and I would have been guessing at scope otherwise:

```
27ea6536  570bb640  73097d48  79e860e2  876c6b97  898b07d0  9417f8bf  ae1c1f79  b869ec24
```

**All nine are decision-object ids; none is a commit.** The ADR's *commit* citations are 7-hex
(`0bf2fa0`, `289f1d3`, `43d328b`, `5436a4d`, `6220951`, `e391c02`) and I confirmed each resolves as a
commit. So the defect is precisely one site, and it is fixed at **both** places the reviewer named —
`:567` §Preconditions and `:772` §Related — each now carrying
**"(decision object id, not a commit; `git log 570bb640` fails)"** plus the type, matching how `:765-771`
label the others. (`ed25519` is the only other 7-hex token in the file and is not a SHA.)

### M-4 — the landing hazard — **FIXED, and the sweep found six sites, not three**

The dispatch asked for re-verification against **current `main`** and the result is unambiguous.

| Claim in the ADR at 811 lines | State at `main` `c6f301d` |
|---|---|
| `:638-641` "not merged into `main` as of `43d328b`" | **false as a standing claim** — `08c7590` merged it |
| `:625-630` "a re-mint supplying **identical** material still satisfies the predicate, still takes the `DO UPDATE` branch, and still overwrites `status`" | **false** — the mint no longer takes that branch |
| `:191-193`, `:417-420` "a revoked credential **can currently be** resurrected by a re-mint" | **false** |
| `:292` "accepted risk A1 (resurrection by re-mint) **is open**" | **false as stated** |
| `:515-517` "immutability makes the branch *predicated*; it does not make it *unreachable*" | **superseded on `main`** |
| `:288` "Immutability … yes (as of `e391c02`)" | **true but understated** — `08c7590` strengthened it |

**Verified on `main`, not inferred** — all six rows of the ADR's new landing note are
`git show main:<path>` reads:

| Established by | Claim |
|---|---|
| `product_registry_engine.dart:933-936` | "A mint is insert-only: supplying an id that already exists is refused by the store and changes nothing — whether the supplied material differs, matches, **or the existing credential is revoked**." |
| `postgres_product_registry_store.dart:413-439` | "THE MINT IS INSERT-ONLY. `DO NOTHING`, not a predicated `DO UPDATE`" — `ON CONFLICT ("credentialId") DO NOTHING` |
| `postgres_product_registry_store.dart:466-471` | `CredentialNotUsableException`: "a credential with this id already exists; minting is insert-only, so issue a NEW `credentialId` — or use `rotateCredential`" |
| `postgres_product_registry_store.dart:428-431` | "no reachable path moves a credential from revoked back into the active set … and **D-4 removes the mint's ability to resurrect one**" |
| `in_memory_product_registry_store.dart:178-185` | the in-memory tier refuses identically, so the two tiers agree |
| `postgres_product_registry_store.dart:296-320` | immutability is **stronger** than the `e391c02` reading: unconditional predicates on `productId`/`repositoryId` **and** on non-null → null transitions for durable evidence |

**What I did about it, and the line I held.** I corrected the six stale claims and recorded the fact.
**I did not retire accepted risk A1**, and the distinction is deliberate and stated in the ADR:

> This does not re-open, re-count, or silently close an accepted risk. The owner accepted four gaps as
> of 2026-10-06 and this section still records **four**. The finding above is a statement about code
> state on a later `main`, not a new decision by a design lane; **retiring A1 from the owner's register
> is a Manager/human action** and is reported upward.

Why that line: closing an accepted risk **is** a consequential change to what the owner accepted, and a
design lane taking it unilaterally would be exactly the defect class this revision exists to remove —
a lane asserting a state the record does not support, in the other direction. So the technical closure
is recorded as verified fact with citations, the accepted-risk accounting is untouched, and the
register action is routed. The A1 heading now carries **both** facts, because a heading that said only
"ACCEPTED" would tell an implementer the gap is live and a heading that said only "CLOSED" would
misstate what the owner accepted.

**The landing obligation survives and is stated:** `main` moving is exactly what made this necessary, so
the §Decision status table keeps its `289f1d3` anchor and §Known gaps records that re-verification
against `main` is a standing obligation at commit time, not a one-off.

### L-1 — pre- and post-revision line numbers with no marker — **FIXED**

§1.1 of revision 4 cites **post-revision** ADR lines and §2's ledger cites **pre-revision** lines, in
adjacent sections. Both are now labelled inline, and §2's header says which base each column uses.
Cheap, and a reader cross-checking the two can now tell why the numbers differ.

### L-2 — risk rationale leaned on a non-causal claim — **FIXED**

Revision 3's rationale item 5 held Level 3 partly because "this revision newly discloses a security
consequence … Stating it plainly is the reason the risk level does not fall." **A disclosure neither
raises nor holds a risk level; the level is set by the change being recorded.** Revision 4's rationale
(§7) states that explicitly and rests the level on items 1–4, which are causal. The conclusion (3) is
unchanged — the reviewer agreed with it — but the stated reason is now load-bearing or absent, and it
is absent.

---

## 3. Traceability

### Requirements covered

| Requirement | Source | Where satisfied |
|---|---|---|
| Sweep the **class**, not the four reported findings | Dispatch §Acceptance criteria | §1.1 six-axis method; §1.2 eleven sites; **1.4** what was deliberately left alone |
| B-1 — headline marked, current scope stated | Review | ADR `:295-302` |
| H-1 — no "Built" claim on contradicting evidence | Review | ADR §Decision status row 2; §Known gaps follow-up |
| H-2 — rotation marked, §Positive substance corrected | Review | ADR `:442-449`, `:467-475`; G-e closed |
| H-3 — dated scope note; F-1 scope is **four** sites | Review, dispatch | ADR §Related scope note (4-row table); §11 exact note text |
| M-1 — cover every normative clause, or narrow the sentence | Review | ADR `:281` narrowed **and** two rows added (9 → 11) |
| M-2 / G-b — file the same-uid exposure in §Known gaps | Review, dispatch | ADR §Known gaps; not self-assigned |
| M-3 — mark `570bb640` as a decision id | Review | ADR §Preconditions **and** §Related; all 9 tokens classified |
| M-4 — re-verify A1 against **current** `main`; record the result | Review, dispatch | §5; ADR landing note; six sites corrected |
| L-1 — mark the numbering bases | Review | §1 tables labelled post-revision; §2 header labelled pre-revision |
| L-2 — drop the non-causal risk rationale | Review | §7 |
| No Docker or Compose command, of any kind | Hard rule | §0; none issued |
| Leave the stash untouched | Hard rule | §0 — and the dispatch's `stash@{0}` is wrong; the ADR stash is `stash@{1}`, verified by label |
| No `.decisions/**` write | Hard rule | §0; exact text reported in §11 instead |
| Search the domain's vocabulary; verify paths exist | Hard rule | §1.1 W6 found the pre-A1 reference form; the `stash@{0}`/`stash@{1}` slip is the same class and was caught |
| State decided vs planned honestly | Hard rule | §Decision status, now eleven rows with a `main`-re-verified landing note |
| Exact provenance incl. ADR line count before/after | Hard rule | §0, header table, §9 |

### Requirements gaps

- **G-a (unchanged, escalated).** `9417f8bf:113`, `:140`, `:210` and `876c6b97:20` still carry the
  absolute. `.decisions/**` is Manager-owned. **Precise append-only note text supplied in §11.**
- **G-b (closed as a *filing*; the *routing* remains).** The same-uid exposure now has a home in
  §Known gaps. **It still has no owner**, and assigning one is the Manager's call — §6.
- **G-c (unchanged).** A3 reachability stays **UNVERIFIED**. Verifying it needs the runtime probe
  `876c6b97:152-156` assigns elsewhere, and no probe is claimed. **No Docker command was run.**
- **G-g (new).** `add_product_page.dart`'s client-side mock key (§2, M-1) and
  `repository_credential.dart`'s stale custody doc comments (§2, H-1) are **production source**. Both
  are filed as §Known gaps implementation follow-ups and reported for routing. Neither is fixable by a
  design lane, and neither is silently absorbed here.
- **G-h (new, from the provenance sweep).** The dispatch's `stash@{0}` reference is stale — the ADR
  stash is at `stash@{1}`. Recorded because the dispatch is authoritative and a lane following it
  literally would inspect the wrong stash.

---

## 4. Design system, UX/accessibility, feasibility

- **DESIGN_SYSTEM_COMPLIANCE: PASS (not applicable — no UI authored).** Revision 4 authors no UI. It
  does tighten the **operator-facing copy constraints** recorded for the mobile lane: the ADR's
  §Amendments A2 forbids copy claiming the key "stays in the keychain", and M-1 adds a **new** binding
  constraint discovered here — no copy may present the UI's key as installable, because the value is a
  client-side mock (§Decision status row). A mobile lane reading only §Amendments A2 would not know
  this. Reported for routing; `apps/control_plane/**` is outside this lane's write scope.
- **UX_ACCESSIBILITY_SCORE: PASS (not applicable — no interface change).** No interface is added,
  removed or restyled. The accessibility surface of this artifact is the ADR, and this revision improves
  it in the property that matters for a document a future reader must trust without the author's
  session: **every superseded clause now carries a visible marker**, the decided-vs-built inventory is a
  table with per-row evidence rather than prose, the same-uid exposure is reachable from §Known gaps
  rather than only from §Accepted risks, and the two places that mislead (a stale headline, a false
  review-status claim) are corrected rather than left to be discovered.
- **IMPLEMENTATION_FEASIBILITY: MEDIUM — unchanged.** A3 is still decided, provisioned in this
  repository's Terraform, **not wired to the credential path**, and **UNVERIFIED** for reachability;
  no adapter, no resolver, no endpoint, no handle-deletion code. Revision 4 **improves what an
  implementer inherits** without changing the estimate:
  - **Rotation is now correctly scoped and confirmed built** — an implementer no longer has to infer
    that "per product" meant "per repository".
  - **The public-half UI is now marked partly-built with the mock named**, so nobody builds on the
    assumption that the screen offers an installable key. That is a **discovered** implementation
    prerequisite, not one revision 4 created.
  - **Immutability is now recorded as stronger than `e391c02`**, with the extra predicates named.
  - **The pre-A1 reference-name form is now forbidden by name** — using it would collide two
    repositories of one product on one secret name.

---

## 5. Verification of M-4 against current `main`, in full

Recorded as its own section because it is the finding with the most evidence and the most authority
sensitivity, and a reviewer should be able to re-run every row.

**Base situation.** Worktree `289f1d3`; `main` `c6f301d`. `08c7590` (merge of
`fix/credential-identity-invariants`, 2026-10-07 07:16:35 -0400) touched 9 files, +1775/−95, including
`postgres_product_registry_store.dart` (+213), `product_registry_engine.dart` (+35),
`in_memory_product_registry_store.dart` (+93), `schema_bootstrap.sql` (+32), `credential_test.dart`
(+360) and a new negative-controls shell script.

**Conclusion: accepted risk A1's exposure no longer reproduces against `main`.** The ADR now says so,
with citations, and routes the register change rather than taking it.

**Two-tier agreement — checked, because one tier refusing proves little.** The ADR's original A1
analysis rested on *both* stores excluding revoked rows, so the fix had to land in both to close the
gap. It did: `in_memory_product_registry_store.dart:178-185` refuses identically. The schema index
(`schema_bootstrap.sql:112-114`, `migration.sql:53-55`) is unchanged and still
`WHERE ("status" <> 'revoked')` — correctly so, because the index was never the mechanism that closed
this; the mint path was.

**What is still open, and the ADR says which.** `08c7590` closed the *resurrection* half. It did
**not** implement handle destruction, so **two-sided revocation is still one-sided in practice** and
§Decision status still marks that clause **partly built**. The revision does not let a closed gap
launder an open one — the §Positive bullet was rewritten to carry the split explicitly ("that
specific hole is closed … **but** the ShipIt-side handle destruction above still is not implemented").

**Standing obligation, recorded in §Known gaps.** Because this finding exists *only* because `main`
moved, re-verification against `main` is an obligation **at every commit**, not a one-off. The ADR
records it.

---

## 6. Discoveries

Classified per `docs/engineering/LEARNING_POLICY.md`. Nothing outside `OWNED_PATHS` was written;
items above this lane's authority are reported, not persisted here.

| # | Finding | Class | Authority | Disposition |
|---|---|---|---|---|
| **F-8** | **The stale-normative-text class is systemic and self-renewing.** The sweep found **eleven** unmarked/stale normative sites against **four** reported. The most damning instance (**S-6**) is **G-17's own defect reproduced by the revision that fixed G-17** — a false "never been independently reviewed" claim with a prescription attached, in the same §Status bullet block, while a ten-finding review sat on `main`. **A correction pass that repairs only its finding set reliably leaves the class alive**, because the class is bigger than any review's patience and the lane has no incentive to look past the list it was handed. | `WORKFLOW_IMPROVEMENT` | Independent review | **Reported.** Recommend the `aef-correction-loop` contract require a **class-sweep step with a stated grep/axis list and an explicit count**, and require the producing lane to record which hits it considered and **declined** — §1.4 exists because that is what made the sweep auditable rather than a search |
| **F-9** | **`add_product_page.dart` renders a client-side mock deploy key.** `_generateMockKeyPair` (`:126-138`) builds 32 bytes from `Random.secure()`, labels them `ssh-ed25519`, and fingerprints a 16-byte digest; the UI offers it with "Copy public key" (`:547`, `:558`, `:1043`, `:1054`). **No server-issued public half reaches the UI**, so an operator can install a key registered nowhere. This is the "non-installable mock" `73097d48` was issued to replace, still present. | `PROJECT_FACT` | Automatic (verified) | **Persisted** in ADR §Decision status + §Known gaps (both in `OWNED_PATHS`). **The fix is production source** — reported for routing |
| **F-10** | **`repository_credential.dart`'s doc comments state the superseded A2 custody model and the pre-A1 reference name.** `:14-15` and `:70-71`; `:20-27` is correctly A1-aware. The type is unaffected — `referenceName` is non-identifying and the field list holds no key material — so this is comment hygiene, not a code defect. | `PROJECT_FACT` | Automatic (verified) | **Persisted** in ADR §Decision status (as *not* evidence) + §Known gaps. Fix is production source — reported |
| **F-11** | **Accepted risk A1's substance is closed on `main` `c6f301d` by `08c7590`**, six sites in the ADR stale-wrong as a result. The fix is insert-only mint + refusal in **both** store tiers. | `PROJECT_FACT` + `CONTRADICTION` | Verified fact **persisted**; **retiring the risk is human/Manager authority** | **Persisted** as verified state with citations; the register action **reported, not taken**. This is the only correct disposition: correcting the stale claims is a design lane's job, closing an accepted risk is the owner's |
| **F-12** | **A stale stash index is a citation hazard.** The dispatch's `stash@{0}` is now `stash@{1}` because a concurrent lane stashed; the ADR stash is at index 1. Content verified **by label** (`9e5b4772…`), not by index. | `WORKFLOW_IMPROVEMENT` | Independent review | **Reported.** Recommend dispatch pre-flights name preserved evidence by **label or content hash**, never by index, since any concurrent `git stash` renumbers the stack |
| **F-13** | **All nine 8-hex ids in the ADR are decision-object ids; all seven 7-hex tokens are commits.** Length alone distinguishes them, and `git log` on any of the nine fails. M-3 was one instance of a systematic ambiguity. | `PROJECT_FACT` | Automatic (verified) | **Persisted** — both `570bb640` citations now carry the type and the failure mode |
| **F-14** | **Revision 3's own metadata repeated S-6**: `review_note` read "Independent design review HAS NEVER HAPPENED for this artifact, at any revision", which was false when revision 3 was written and is false now. | `PROJECT_FACT` | Automatic (verified) | **Reported and retained unaltered as history** (revisions 1–3 are not rewritten). Corrected in revision 4. Same device as C-1 |

---

## 7. Risk level

**RISK_LEVEL: 3** — unchanged from revisions 1, 2 and 3, and unchanged from the independent review's
own assessment (`INDEPENDENT_RISK_LEVEL: 3`, `RISK_LEVEL_AGREEMENT: YES`).

The level describes **the change being recorded**, not the accuracy of the prose or whether a human
blessed it. Acceptance did not lower it in revision 2, and a precision correction does not lower it
here.

1. **Amends recorded architecture on a security boundary.** It governs where a private key capable of
   authorising repository **write** access is held, and what "revoked" means. No such secret exists in
   the repository today.
2. **Changes a core workflow.** Revocation acquires a ShipIt-side action where ADR 0018 said none was
   required, plus a runtime dependency (the secret manager) that can block the credential path.
3. **Depends on enforcement that lives elsewhere and is still partly absent.** At `289f1d3`: no
   transport host-key enforcer, no secret-manager adapter, no handle-deletion code, registration not
   wired to a connectivity check, and the UI's deploy key still a client-side mock (F-9).
4. **Carries four accepted risks on a security boundary**, recorded with consequences at §Accepted risks
   A1–A4. The owner accepted them on 2026-10-06 (`876c6b97`). **Revision 4 does not close any of them,
   does not add a fifth, and does not re-count them** — it records that A1's exposure no longer
   reproduces on `main` and routes the retirement (§5).
5. **~~This revision newly discloses a security consequence, which is why the level does not fall.~~**
   **REMOVED as a rationale, and the reason is L-2.** A disclosure **neither raises nor holds** a risk
   level: the level is set by the change being recorded, and the change is the same one items 1–4
   already describe. Holding Level 3 on "we were honest this time" would make the scale mean something
   it does not. The level rests on items 1–4, which are causal.

**Human gate:** Level 3 approval was satisfied on 2026-10-06 by the repository owner as ADR owner
(`876c6b97`). **That satisfied the gate; it does not satisfy independent review, which for revision 4
has not happened.** Revision 4 changes wording, markers, evidence and one verified state record. It
changes **no substrate, no revocation model, no accepted gap, no clause of the owner's answer, and no
requirement on any implementer**. **No new Level 2/3 decision is required, and none is manufactured** —
inventing a gate here would be the same error as asserting a state the record does not support, in
process form.

The one item that *could* be argued as a gate — retiring accepted risk A1 — is **deliberately not
decided here** and is routed instead (§5, F-11), for the same reason: it changes what the owner
accepted, which is theirs to change.

---

## 8. Validation

Every command was run in `/private/tmp/shipit-design-adr0018`. **No Docker or Compose command appears
in this list or was executed.**

| # | Check | Result |
|---|---|---|
| V-1 | `git rev-parse --short HEAD` | `289f1d3` — **unchanged**; no commit, no rebase |
| V-2 | `git status --short` | only ` M docs/adr/0018-…md` + the three revision-3 artifacts + revision 4's three. **No other file modified** |
| V-3 | `grep -n "SUPERSEDED\|superseded by" docs/adr/0018-…md` (dispatch `VALIDATION_COMMANDS`) | **10 hits**, up from 4 at revision 3. Every superseded clause now carries one |
| V-4 | Sweep W1 (per-product scope) | 11 hits; 5 fixed, 5 correctly-marked/history, 1 correctly-current |
| V-5 | Sweep W2 (custody) | `:14-15`, `:70-71` doc comments named as stale in §Decision status + §Known gaps |
| V-6 | Sweep W3 (rotation scope) | 3 hits; all 2 normative ones fixed, §Known gaps entry closed |
| V-7 | Sweep W4 (revocation) | 2 hits; **already marked** — no action. Confirms no gap here |
| V-8 | Sweep W5 (key-count arithmetic) | `:429` found and fixed — **not in any finding set** |
| V-9 | Sweep W6 (reference-name format) | `:367` found: pre-A1 `GIT_PRODUCT_<productRef>_SSH` as current — **not in any finding set** |
| V-10 | `rg -o '\b[0-9a-f]{8}\b'` → classify each | 9 tokens, **all decision ids**; `git log` fails on each |
| V-11 | `rg -o '\b[0-9a-f]{7}\b'` → classify each | 6 commits, all resolve; 7th token is `ed25519` |
| V-12 | `git log -n1 570bb640` | **fails** — *unknown revision*. Confirms M-3 |
| V-13 | `git show main:…product_registry_engine.dart \| rg insert-only` | "refused … whether the supplied material differs, matches, **or the existing credential is revoked**" (`:933-936`) |
| V-14 | `git show main:…postgres_product_registry_store.dart` | `ON CONFLICT ("credentialId") DO NOTHING` (`:439`); `CredentialNotUsableException` (`:466-471`); "D-4 removes the mint's ability to resurrect one" (`:428-431`); stronger predicates (`:296-320`) |
| V-15 | `git show main:…in_memory_product_registry_store.dart` | refuses identically (`:178-185`) — two tiers agree |
| V-16 | `git ls-tree -r --name-only main -- …/design-review-adr-0018-a2-rev3/` | `prompt.md`, `report.md` — **the review exists on `main`**; confirms S-6 |
| V-17 | that report's `RESULT` / `REVIEWED_HEAD` | `DESIGN_REVIEW_CHANGES_REQUIRED` / `289f1d3` |
| V-18 | `git merge-base --is-ancestor 16cd497 main` | yes — dispatch `BASE_SHA` is an ancestor; `main` had advanced to `c6f301d` |
| V-19 | `git stash list` (read only) | `stash@{0}` = mobile lane, **`stash@{1}` = the ADR stash**. **Neither touched** |
| V-20 | `git show 'stash@{1}:docs/adr/…md' \| shasum -a 256` | `9e5b47723e40fd0fd42b69ddf4b5330768ca4fcf782acb0f1992e7aebb83b4fb` — matches the label; **intact** |
| V-21 | `git status --short .decisions/` | **empty** — 14 objects untouched; **H-3's upstream half reported, not written** |
| V-22 | ADR line count | 811 → **999** |
| V-23 | Revisions 1–3 unaltered | `design-revision{,-metadata,-2,-metadata-2,-3,-metadata-3}` all untouched by this lane |
| V-24 | `git show main:…add_product_page.dart \| rg publicKey` | mock generator `:126-138`; renders `:547`/`:558`/`:1043`/`:1054`. Confirms F-9 |
| V-25 | `git show main:…repository_credential.dart` | no private-key field (`:61-122`); stale `:14-15`, `:70-71`; correct `:20-27`. Confirms H-1's fix and F-10 |
| V-26 | `git show main:AGENTS.md \| rg '^### §13\|^#### §13'` | `:65`, `:72`, `:78` — §Known gaps' AGENTS.md citations **still exact at `main`** |
| V-27 | Docker / Compose — any command | **NOT_RUN.** Deliberately. None issued, not even read-only |
| V-28 | A3 reachability runtime probe | **NOT_RUN.** Needs Docker; outside this scope. **No probe is claimed** |

**Not validated, and not claimed:** A3 reachability; whether the Cloud Run workload identity can
resolve a secret; any behaviour of the git transport; the mobile copy at `add_product_page.dart:542`/
`:1038` (the mobile lane owns it — this lane read the file only to establish the mock-key finding);
§Accepted risks A2, A3 and A4, which this revision does not re-verify beyond noting A1's status change.

---

## 9. Provenance

| | |
|---|---|
| Worktree | `/private/tmp/shipit-design-adr0018` |
| Branch | `design/adr-0018-amendment` |
| `HEAD_SHA` | `289f1d3` — **unchanged; no commit, no push** (dispatch: "Do not commit or push") |
| `BASE_SHA` | `289f1d3` (as dispatched) |
| Re-verified against | `main` `c6f301d`; dispatch `BASE_SHA` `16cd497`, also an ancestor |
| ADR before | **811** lines (`289f1d3`, uncommitted) |
| ADR after | **999** lines, uncommitted |
| Committed | **NO** — a reviewer must read the worktree and `git diff`, not a commit |
| Files written | `docs/adr/0018-per-product-git-credentials.md`; `design-revision-4.md`; `design-revision-metadata-4.yaml`; `report.md` |
| `.decisions/**` | **14 objects, untouched** |

---

## 10. Blockers

**None.** `blockers: []`. No `HUMAN_DECISION_REQUIRED` gate is raised — reasoning in §7 so it can be
challenged. Three items are **surfaced for the Manager**, none of which this lane may decide:

1. **F-1 / G-a** — append a dated scope note to `9417f8bf` and `876c6b97`. Exact text in §11.
   `.decisions/**` is Manager-owned; refusing to write it was correct, **stopping there was not**.
2. **F-11** — accepted risk A1's exposure is closed on `main`; **retiring it from the owner's register
   is the Manager's/human's action.** The ADR records the verified fact and does not re-count.
3. **G-b** — the same-uid exposure is now **filed** in §Known gaps and still needs **an owner**.

Plus two for routing, both production source this lane may not write: **F-9** (mock deploy key in the
UI) and **F-10** (stale custody doc comments).

---

## 11. The exact text the Manager must append to the two decision objects

`.decisions/**` is Manager-owned and `PROHIBITED` to this lane, so these are **specified here and not
written**. **Append-only. Never rewrite a resolution rationale** — that is the human's own recorded
answer, and `LEARNING_POLICY.md:261` prescribes "surface and reconcile — do not silently overwrite"
for a `CONTRADICTION`. Same device as the ADR's own `:37-40`.

### 11.1 Append to `.decisions/9417f8bf-73b8-4827-9515-bdfe92e5a9d5.yaml`

```yaml
# ---- SCOPE NOTE appended 2026-10-07 by orchestrator-main. APPEND-ONLY: no line above this
# comment is altered. The resolution above stands and is NOT re-opened. ------------------------
#
# This object states, as a standing claim, that "SHIP IT never holds key bytes". That was
# answered on 2026-10-06, before ADR 0018 amendment A2 recorded that at transport time SHIP IT
# MUST materialise the private half in its own process memory to authenticate the git
# connection. The claim is therefore FALSE as written and true only in the **storage**
# dimension: SHIP IT never STORES the private half (not in the durable record, a table, a file,
# a log, a backup, a client payload), and does transiently HOLD it for the lifetime of the
# connection.
#
# FOUR sites carry the absolute, not two:
#   - :113  "A3 is literally the existing contract - SHIP IT never touches key bytes"
#   - :140  "the only option under which SHIP IT never holds key bytes at all"
#            (the load-bearing UNIQUENESS argument the human actually read)
#   - :210  "SHIP IT never holds key bytes, only a reference, and asks the manager for the
#            material at push time"
#   - 876c6b97:20 (separate object; same absolute)
#
# WHAT IS UNCHANGED. The substrate choice (OPTION_C, external secret manager / A3) stands. The
# exclusion of A2 (envelope-encrypted table) stands - it is a separate conclusion resting on the
# durable-record prohibition, not on this absolute. G-7's elevation to REQUIRED stands. The
# uniqueness argument at :140 SURVIVES in the dimension that matters: A1 and A2 both write key
# bytes at rest, and A3 does not.
#
# WHY THIS OBJECT IS NOT INTERNALLY CONSISTENT. :116-119 already contains the CORRECT reasoning -
# it rejected A1 precisely because "permissions do not defend against a same-uid process - which
# is the git transport". Under A3 the exposure is process memory rather than the filesystem, and
# it MOVES rather than disappears; A3 narrows the window and removes the at-rest artefact but
# does not remove the class. A hardening argument resting on "the key is not on the box" is
# invalid; one resting on "the key is never on the box at all" was never available.
#
# The consequence - a same-uid exposure with no owning follow-up - is recorded at
# docs/adr/0018-per-product-git-credentials.md (Amendments A2 -> "never holds key bytes", and
# section Known gaps). It is deliberately NOT a fifth accepted risk: this object and 876c6b97
# accepted four gaps, and the property is SUBSTRATE-INDEPENDENT - SHIP IT pushes git itself, so it
# must materialise the private half under A1, A2, A3 and A4 alike.
#
# Correcting source of record: docs/adr/0018-per-product-git-credentials.md, amendment A2
# (Design Revision 4, correcting Design Revision 3). Read this object at the ADR's scoped
# reading, not at its literal wording.
```

### 11.2 Append to `.decisions/876c6b97-3e23-459d-aa9d-3a5faeb33702.yaml`

```yaml
# ---- SCOPE NOTE appended 2026-10-07 by orchestrator-main. APPEND-ONLY: no line above this
# comment is altered. The acceptance above stands, is NOT withdrawn, and no clause of the
# owner's answer is re-opened. --------------------------------------------------
#
# The CONTEXT block at :20 states, as a standing claim, that under A3 "SHIP IT never holds key
# bytes at all, only a reference it asks the manager to resolve at push time". That was written
# on 2026-10-06, before ADR 0018 amendment A2 established that at transport time SHIP IT MUST
# materialise the private half in process memory. The sentence is FALSE as written and true only
# in the STORAGE dimension: SHIP IT never STORES the private half, and transiently HOLDS it for
# the connection's lifetime. Requiring SHIP IT to transmit the private half is requiring it to
# hold it.
#
# This is the fourth site carrying that absolute; the other three are in 9417f8bf (:113, :140,
# :210), whose own :116-119 already contains the correct same-uid reasoning.
#
# WHAT IS UNCHANGED - stated explicitly, because this object is the citable id for the
# acceptance and nothing about it is disturbed:
#   - "Accept A2, record the gaps as accepted" (OPTION_A, decided_at 2026-10-06T14:20:00Z) STANDS.
#   - EXACTLY FOUR accepted risks were put to the owner and exactly four are recorded. This note
#     adds no fifth and closes none.
#   - The four follow-up_action owners below STANDS as recorded.
#   - Only the substrate choice, the A2 exclusion, G-7's elevation to REQUIRED, and the four-gap
#     acceptance depend on the corrected claim, and each survives in the storage dimension.
#
# ONE THING A READER SHOULD NOW KNOW. Accepted risk A1 (resurrection of a revoked credential by
# a re-mint) was verified against main c6f301d on 2026-10-07: 08c7590 merged the reviewed fix,
# and the mint path is now insert-only - a mint refuses any existing credentialId, "whether the
# supplied material differs, matches, or the existing credential is revoked" - so the exposure
# this gap described no longer reproduces. The accepted-risk entry is RETAINED here deliberately:
# it records what the owner accepted on 2026-10-06, and RETIRING IT IS THE OWNER'S CALL, not a
# design-lane edit. See ADR section Accepted risks A1. The other half of the revocation clause -
# no code destroys a secret-manager handle - remains unimplemented, so revocation is still
# one-sided in practice.
#
# Correcting source of record: docs/adr/0018-per-product-git-credentials.md, amendment A2
# (Design Revision 4, correcting Design Revision 3).
```

---

## 12. Handover

**Ready for independent design review.** `reviewed_by` and `reviewed_at` are `null`; `status` is
`DRAFT`. This lane has not approved its own work and cannot.

**A reviewer should check, in this order — and the first item is the one that matters most:**

1. **The sweep.** §1.1 states the six axes as greps and §1.2 tabulates **eleven** sites. The real
   question is not whether eleven is right but whether **twelve or thirteen exist**. Re-run W1–W6
   independently; a higher count means the sweep is incomplete, which is the failure mode that
   produced this revision.
2. **S-6** (§Status's "has never been independently reviewed"). It is a correction *about review
   status*, so it deserves the most suspicion: is `reviewed_by: null` still accurate, and is
   "`reviewed_by` stays null until a reviewer signs it" still a fair statement given a
   `CHANGES_REQUIRED` verdict exists? Check `design-review-adr-0018-a2-rev3/report.md` on `main`.
3. **§1.4** — the sweep's *declined* hits. If a declined hit should have been fixed, the sweep is
   over-cautious; if a declined hit was right, the omissions are accounted for.
4. **M-4's authority line** (§5, F-11). The technical closure is recorded as verified fact with
   citations; the accepted risk is **not** retired and the count stays four. Challenge that boundary —
   it is the judgement in this revision most worth challenging.
5. **M-1's discovered defect** (F-9). A `Built`-adjacent clause turned out to be a client-side mock.
   Confirm the reading of `add_product_page.dart:126-138` and that marking it **partly built** rather
   than **not built** is right.
6. **§11's note text** — that it is append-only, attributes the absolute correctly, and does not
   re-open or re-count anything the human decided.

**Known not-done, so absence is not read as completion:** the `.decisions/**` notes (§11, Manager);
retiring accepted risk A1 (Manager/human); an owner for the same-uid exposure; F-9 and F-10 (both
production source); A3 reachability (runtime probe, outside this scope, `UNVERIFIED`); the mobile copy
at `add_product_page.dart:542`/`:1038` (mobile lane); independent review of revision 4.