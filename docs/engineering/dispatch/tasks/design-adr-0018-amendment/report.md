# Subtask Report — design-correct-adr-0018-a2-3 (ADR0018-A2-REV4)

Persisted to disk before returning, per the dispatch ("a review report has been lost three times in this
work item").

> Revision 3's report was **not overwritten**. It is preserved byte-unaltered as
> `report-revision-3.md` in this directory, per the ADR's own `:37-40` no-silent-rewrite convention
> and the same treatment revisions 1–3 received.

## Mandatory header

```yaml
RESULT: DESIGN_REVISION_COMPLETE
TASK_ID: design-correct-adr-0018-a2-3
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — ADR 0018 amendment A2, revision 4 (the stale-normative-text sweep)
WORKTREE: /private/tmp/shipit-design-adr0018
BRANCH: design/adr-0018-amendment
BASE_SHA: 289f1d3
HEAD_SHA: 289f1d3   (UNCHANGED — no commit, no rebase, no fast-forward)
COMMITTED: NO
REVISION_ID: ADR0018-A2-REV4
ADR_LINES_BEFORE: 811
ADR_LINES_AFTER: 999
```

---

## The answer to the question the dispatch actually asked

> "the list of any further unmarked superseded clauses YOUR SWEEP found beyond the four reported —
> since that number is the real measure of whether the sweep was done."

**Seven further sites. Eleven total. The four reported were not a bounded set.**

| ID | Site (at 811-line revision) | Axis | In a finding set? |
|---|---|---|---|
| B-1 | `:272-273` §Decision headline — "scoped per product, not per platform" | W1 scope | reported |
| H-1 | `:287` "Built: yes" on evidence asserting superseded custody | W2 custody | reported |
| H-2a | `:384-385` "Rotation is per product" | W3 rotation | reported |
| H-2b | `:401` §Positive — superseded scope presented **as a benefit** | W3 rotation | reported |
| **S-1** | `:362-364` public-half clause had **no table row**, and targeted "the product's repository" | W1 | **no** |
| **S-2** | `:365-368` reference example was the **pre-A1** `GIT_PRODUCT_<productRef>_SSH` | W6 | **no** |
| **S-3** | `:429` §Negative — "**N products means N keypairs**", contradicted four lines below by a bullet that already said it correctly | W5 | **no** |
| **S-4** | `:448-449` §Mitigation — "UI surfaces key state **per product**" | W1 | **no** |
| **S-5** | `:451-452` §Mitigation — "dedicated **per-product page**", implying rotation as one act | W1+W3 | **no** |
| **S-6** | `:6-21` §Status — "the Design Revision … **has never been independently reviewed**" | review-status | **no** |
| **S-7** | six accepted-risk-A1 claims false against current `main` | state-freshness | partly (M-4 named three) |

`SUPERSEDED` markers: **4 → 10**. ADR: **811 → 999** lines. All eleven fixed.

### S-6 is the one that proves the sweep was necessary

§Status claimed the design revision *"has never been independently reviewed"*, with a prescription
attached — *"stays null until a reviewer signs it"*. **That is false, and it is G-17's own defect
class: a fact with a shelf life written as a standing claim, carrying a prescription, reproduced by the
very revision that fixed G-17.**

Verified: `git ls-tree -r --name-only main -- docs/engineering/dispatch/tasks/design-review-adr-0018-a2-rev3/`
→ `prompt.md`, `report.md`; the report's `RESULT` is `DESIGN_REVIEW_CHANGES_REQUIRED`,
`REVIEWED_HEAD: 289f1d3`. **A review of this work item exists, on `main`, with ten findings in it.**

Had I fixed the four reported findings, that sentence would still tell a future reader that no
independent review of this work exists. That is what "repair the finding set, not the class" costs.

The load-bearing point survives intact and is now truthful: `reviewed_by` is still `null` — correctly,
because `CHANGES_REQUIRED` is not a signature — and revision 4 is itself unreviewed.

---

## Per-finding disposition

| Finding | Disposition | Where |
|---|---|---|
| **B-1** BLOCKER | **FIXED.** Struck, marked **SUPERSEDED (A1)**, amendment A1's own reason quoted ("not installable for a multi-repo product"), per-repository scope stated as current. Headline, status row and §Amendments A1 now agree. | ADR `:295-302` |
| **H-1** HIGH | **FIXED.** Row re-grounded on the **field declarations** `repository_credential.dart:61-122` — no private-key field, which *is* the claim — and `:14-15`/`:70-71` named as **stale and explicitly not the evidence**. Verified `:20-27` is correctly A1-aware, so the file is right where A1 governs and stale where A2 governs. Stale comments are production source → **§Known gaps follow-up (F-10)**, not fixed here. | ADR §Decision status row 2; §Known gaps |
| **H-2** HIGH | **FIXED, both.** `:384-385` and `:401` struck and marked **SUPERSEDED (A1)**, per-repository rotation stated and confirmed built. `:401` needed more than a marker — it sat in **§Positive**, so marking it would leave the document *arguing from a premise it had abandoned*. Substance corrected: per-repository scoping **moves cost rather than removing it** (*n* repositories, *n* rotations). Honest cost left in §Negative, which already had it. **G-e closed.** | ADR `:442-449`, `:467-475`, §Known gaps |
| **H-3** HIGH | **FIXED in the in-scope half; upstream half reported with exact text.** §Related now carries a **dated, attributed scope note** tabulating **all four sites** (`9417f8bf:113`, `:140`, `:210`; `876c6b97:20`), naming `:140` the load-bearing uniqueness argument, stating the decisions are **not re-opened**, noting each object is internally inconsistent because `:116-119` already holds the correct reasoning. **The ADR's own citations unchanged.** `.decisions/**` **not written** — the refusal was right, stopping there was not; exact append-only text in §11 of the revision. | ADR §Related scope note; revision §11 |
| **M-1** MEDIUM | **FIXED by adding rows, not only narrowing the sentence.** Two rows added (public half; rotation); the claiming sentence scoped. **Table nine → eleven.** Adding the UI row **surfaced a real defect**: the surface is built (`add_product_page.dart:547`, `:1043`) but the value is a **client-side mock** (`:126-138`) — no server-issued public half reaches the UI. **Third partly-built clause**; count two → three. | ADR §Decision status |
| **M-2** MEDIUM | **FIXED (surfaced *and* filed).** §Accepted risks says explicitly it is not counted there and why; a **§Known gaps entry** now carries it with its ownerless status (`876c6b97:136-161` assigns A2 to design-agent, A3/A4 to implementation/deployment) and **substrate-independence** recorded. **Not self-assigned; no fifth accepted risk.** | ADR §Accepted risks, §Known gaps |
| **M-3** MEDIUM | **FIXED at both sites** (§Preconditions, §Related), each reading "decision object id, not a commit" with the type and the `git log` failure mode. **Swept the class:** all **nine** 8-hex tokens in the ADR are decision ids; all six 7-hex tokens are commits. Exactly one site. | ADR §Preconditions, §Related |
| **M-4** MEDIUM | **FIXED — six sites, not three.** Re-verified against **`main` `c6f301d`**; `08c7590` closed A1's substance: the mint is **insert-only** and refuses an existing `credentialId` *"whether the supplied material differs, matches, **or the existing credential is revoked**"*, in **both** store tiers, with the store comment *"D-4 removes the mint's ability to resurrect one"*. All six stale claims corrected; immutability recorded as **stronger** than `e391c02`. **A1 not retired, count stays four** — that is the owner's register. | ADR §Decision status landing note; §Accepted risks A1 |
| **L-1** LOW | **FIXED.** Post-revision and pre-revision numbering bases labelled. | revision §1, §2 |
| **L-2** LOW | **FIXED.** Rationale item 5 **removed as a rationale**, with the reason stated: a disclosure neither raises nor holds a risk level. Level rests on items 1–4, which are causal. Conclusion (3) unchanged. | revision §7 |

---

## The PRECISE dated scope note text you must append to each decision object

`.decisions/**` is Manager-owned and `PROHIBITED` to me — **I did not write these.** Reproduced in full
in `design-revision-4.md` §11.1 and §11.2; the essential content:

### → `9417f8bf-73b8-4827-9515-bdfe92e5a9d5.yaml`

An **append-only** YAML comment block, dated 2026-10-07 by `orchestrator-main`, stating:

1. **Append-only; nothing above is altered**; the resolution stands and is not re-opened.
2. The object states as a standing claim that "SHIP IT never holds key bytes" — answered 2026-10-06,
   before A2 recorded that SHIP IT **must** materialise the private half in process memory at transport
   time. **False as written; true only in the STORAGE dimension.**
3. **Four sites**, named individually: `:113`, `:140` (named as the load-bearing uniqueness argument),
   `:210`, and `876c6b97:20`.
4. **What is unchanged:** substrate choice (OPTION_C / A3); the **A2 exclusion**, which rests on the
   durable-record prohibition and *not* on this absolute; G-7's elevation to required; and the uniqueness
   argument at `:140`, which **survives** in the dimension that matters (A1 and A2 both write bytes at
   rest, A3 does not).
5. **Why the object is internally inconsistent:** `:116-119` already contains the correct reasoning —
   it rejected A1 because *"permissions do not defend against a same-uid process — which is the git
   transport."*
6. The same-uid consequence is recorded in the ADR and is **deliberately not a fifth accepted risk**;
   it is substrate-independent.

### → `876c6b97-3e23-459d-aa9d-3a5faeb33702.yaml`

An **append-only** YAML comment block, dated 2026-10-07 by `orchestrator-main`, stating:

1. **Append-only; the acceptance is not withdrawn** and no clause of the owner's answer is re-opened.
2. `:20` carries the same absolute; corrected in the storage dimension, with the other three sites named.
3. **What is unchanged, explicitly** — this is the citable id, so nothing about it is disturbed:
   *"Accept A2, record the gaps as accepted"* **STANDS**; **exactly four** accepted risks were put to the
   owner and exactly four are recorded — **this note adds no fifth and closes none**; the four
   `follow_up_action` owners **stand as recorded**.
4. **One thing a reader should now know:** accepted risk A1's exposure no longer reproduces against
   `main` `c6f301d` (`08c7590`), but **the entry is retained deliberately** — it records what the owner
   accepted on 2026-10-06 and **retiring it is the owner's call, not a design-lane edit**. And the
   other half of the revocation clause — no handle destruction — remains unimplemented, so revocation is
   still one-sided in practice.

**Never rewrite a resolution rationale.** `LEARNING_POLICY.md:261` prescribes exactly this for a
`CONTRADICTION` ("surface and reconcile — do not silently overwrite"), and the ADR's own `:37-40` points
at the same device.

---

## M-4 — the landing hazard, re-verified as instructed

| ADR claim at 811 lines | State at `main` `c6f301d` |
|---|---|
| `:638-641` "not merged into `main` as of `43d328b`" | **false** — `08c7590` merged it |
| `:625-630` "a re-mint supplying **identical** material … still overwrites `status`" | **false** — no such branch |
| `:191-193`, `:417-420` "**can currently be** resurrected by a re-mint" | **false** |
| `:292` "accepted risk A1 … **is open**" | **false as stated** |
| `:515-517` "predicated … not unreachable" | **superseded on `main`** |
| `:288` "Immutability … as of `e391c02`" | **true but understated** — `08c7590` strengthened it |

Evidence, all `git show main:<path>`: `product_registry_engine.dart:933-936`;
`postgres_product_registry_store.dart:413-439`, `:466-471`, `:428-431`, `:296-320`;
`in_memory_product_registry_store.dart:178-185` (**two tiers agree** — one refusing proves little, so
this was checked).

**The line I held, stated so it can be challenged:** I corrected the six stale claims and recorded the
technical closure with citations. **I did not retire accepted risk A1 and did not re-count.** Closing an
accepted risk is a consequential change to what the owner accepted, and a lane taking it unilaterally
would be this revision's own defect class — asserting a state the record does not support, in the other
direction. The A1 heading now carries **both** facts.

**The landing obligation survives and is recorded in §Known gaps:** this finding exists *only* because
`main` moved, so re-verification against `main` is a standing obligation at every commit. The
§Decision status table keeps its `289f1d3` anchor and carries a dated landing note so the anchor is not
read as current.

---

## Two provenance corrections to the dispatch — both verified before acting

**1. `BASE_SHA` is stale.** Dispatch says `16cd497`; `main` was at **`c6f301d`**. `16cd497` *is* an
ancestor (`git merge-base --is-ancestor` → yes). The worktree was **deliberately not fast-forwarded** —
the reviewed provenance is `289f1d3` and the amendment is uncommitted — so everything M-4 needed was
verified explicitly against `main` by `git show main:<path>`.

**2. ⚠ `stash@{0}` is NOT the ADR stash.** The dispatch says the preserved edit is at `stash@{0}`. It is
at **`stash@{1}`** — a concurrent lane created a new `stash@{0}`
(`rev5-uncommitted-identical-to 16cd497`) and renumbered the stack.

```
stash@{0}: On design-correct-addproduct-mobile: rev5-uncommitted-identical-to 16cd497
stash@{1}: On design/adr-0018-amendment: ADR0018 A2 rev1 local edit (superseded by main 5436a4d;
           sha256 9e5b4772) -- preserved, do not drop blindly
```

**Verified by label, not index:** `git show 'stash@{1}:docs/adr/0018-…md' | shasum -a 256` →
`9e5b47723e40fd0fd42b69ddf4b5330768ca4fcf782acb0f1992e7aebb83b4fb` — matches the label and revision 3's
V-10. **Intact.**

**I left both stashes exactly as I found them — not dropped, popped, applied or modified.** Recorded as
F-12: a stale stash index is a citation hazard, and pre-flights should name preserved evidence by label
or content hash.

---

## The two things the reviewer told me to adopt — both done

- **G-b.** "Right to surface, incomplete as handled." → the same-uid exposure is now **filed** in
  §Known gaps with its ownerless status and substrate-independence recorded, **routed for an owner, not
  self-assigned**. No fifth accepted risk was created.
- **H-3.** "The refusal was correct; stopping there was not." → the **in-scope half is fixed** (dated
  scope note, four sites); the **upstream half is reported with exact append-only text** for you to
  apply. `.decisions/**` untouched.

## What I did NOT re-verify

Per the dispatch: every `file:line` citation in §Decision status and F-2; the GCP Secret Manager
substrate with `secretAccessor` already granted to the Cloud Run SA (A4 genuinely narrows — no
deploy-key secret, no runtime binding); G-17's same-commit proof; the four accepted gaps (still four).
I read `876c6b97` (164 lines) and `9417f8bf` (239 lines) **in full** — which is how F-1's scope came to
be four sites rather than two, and it was required reading, not re-verification.

## Deliberate non-fixes, recorded so absence is not read as oversight

| Hit | Why left |
|---|---|
| `:59`, `:64-65`, `:379-384`, `:478`, `:520` | already marked `SUPERSEDED` — the device working correctly |
| `:109-139` "never holds key bytes" scoping | bounded three ways by revision 3; no residue |
| Revisions 1, 2, 3 artifacts | **retained unaltered as history** — same device revision 3 used; revising them would repeat the defect |
| `add_product_page.dart:542`/`:1038` copy | mobile lane's scope; I read the file only to establish F-9 |
| A3 reachability | needs the runtime probe; **UNVERIFIED**, no probe claimed |

---

## Files touched

```text
docs/adr/0018-per-product-git-credentials.md                          ← 811 → 999 lines
docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-4.md
docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-metadata-4.yaml
docs/engineering/dispatch/tasks/design-adr-0018-amendment/report.md
docs/engineering/dispatch/tasks/design-adr-0018-amendment/report-revision-3.md   ← rev 3's report PRESERVED
```

The ADR is the **only** file written outside this task directory. **Nothing committed, nothing pushed.**

---

## Validation

| Command | Result | Evidence |
|---|---|---|
| `git rev-parse --short HEAD` (dispatch) | pass | `289f1d3` — unchanged |
| `grep -n "SUPERSEDED\|superseded by" …` (dispatch) | pass | **10** hits, up from **4** |
| `wc -l` ADR | pass | **811 → 999** |
| Sweep W1–W6 (six axes over the whole document) | pass | 11 unmarked/stale sites found and fixed; declines recorded with reasons |
| `rg -o '\b[0-9a-f]{8}\b'` → classify all 9 | pass | **all decision ids**; none is a commit |
| `rg -o '\b[0-9a-f]{7}\b'` → classify all 7 | pass | 6 commits resolve; 7th is `ed25519` |
| `git log -n1 570bb640` | **fail (ADR defect, fixed)** | *unknown revision* — decision object |
| `git show main:…` × 5 files (A1 closure) | pass | insert-only mint + refusal, **both tiers** |
| `git ls-tree -r --name-only main -- …design-review-adr-0018-a2-rev3/` | pass | review **exists on `main`** — confirms S-6 |
| `git merge-base --is-ancestor 16cd497 main` | pass | yes; `main` at `c6f301d` |
| `git show 'stash@{1}:…' \| shasum -a 256` | pass | `9e5b4772…` — matches label; **both stashes untouched** |
| `git status --short .decisions/` | pass | **empty** — 14 objects untouched |
| `git diff 289f1d3 -- design-revision{,-metadata,-2,-metadata-2}` | pass | **empty** — revisions 1–2 untouched |
| `git show main:AGENTS.md \| rg '^### §13\|^#### §13'` | pass | `:65`, `:72`, `:78`, `:91` — §Known gaps' citations **still exact** |
| **Docker / Compose — any command** | **NOT_RUN** | Deliberately. None issued, not even read-only |
| A3 reachability probe | **NOT_RUN** | Needs Docker; outside scope. **No probe claimed** |

---

## Evidence (revision-pinned)

```yaml
EVIDENCE_REVISION: 289f1d3        # worktree; ADR amendment UNCOMMITTED
REVERIFIED_AGAINST: main c6f301d  # every "closed on main" claim; 16cd497 is its ancestor
BUILD_COMMAND: n/a — documentation / architecture record only
SERVE_OR_RUN_COMMAND: n/a — nothing built, served, or executed
ENVIRONMENT / BASE_URL: n/a
ARTIFACTS:
  - docs/adr/0018-per-product-git-credentials.md                                   (999 lines, UNCOMMITTED)
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-4.md
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-metadata-4.yaml
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/report.md
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/report-revision-3.md  (rev 3's report, preserved)
  - .decisions/876c6b97-3e23-459d-aa9d-3a5faeb33702.yaml  (164 lines, read in full, UNMODIFIED)
  - .decisions/9417f8bf-73b8-4827-9515-bdfe92e5a9d5.yaml  (239 lines, read in full, UNMODIFIED)
  - docs/engineering/dispatch/tasks/design-review-adr-0018-a2-rev3/report.md      (read; the finding set)
  - stash@{1}  docs/adr/0018-per-product-git-credentials.md  (sha256 9e5b4772… — verified by LABEL, INTACT)
```

---

## Documentation updated

```text
docs/adr/0018-per-product-git-credentials.md
docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-4.md
docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-metadata-4.yaml
docs/engineering/dispatch/tasks/design-adr-0018-amendment/report.md
```

## Model and reasoning effort

```yaml
ROUTING_CLASS_REQUESTED: PRECISION
MODEL_USED: opencode/space-bunny-free
REASONING_EFFORT: n/a
ESCALATED_INSIDE_TASK: NO
ESCALATION_REASON: n/a
```

---

## Unresolved issues and blockers

**`blockers: []`. No `HUMAN_DECISION_REQUIRED` gate raised.**

1. **F-1 / G-a — needs you.** Append the dated scope note to `9417f8bf` and `876c6b97`. Exact text in
   revision §11.1/§11.2. **Append-only; never rewrite a rationale.**
2. **F-11 — needs you or the human.** Accepted risk A1's exposure is closed on `main`; **retiring it
   from the owner's register is not a design-lane edit.** The ADR records the verified state, keeps the
   count at four, and routes this.
3. **G-b — needs an owner.** The same-uid exposure is now **filed**; it still has **no owner**.
4. **F-9 / F-10 — production source, for routing.** The UI renders a **client-side mock deploy key**
   (`add_product_page.dart:126-138`); `repository_credential.dart`'s doc comments state the superseded
   custody model and the pre-A1 reference name. Both recorded in the ADR's §Known gaps; neither
   writable by this lane.
5. **M-4's landing obligation — at commit time.** Re-verify against `main` again; this finding exists
   only because `main` moved, so it will recur.
6. **Independent review of revision 4 has not happened.** That is the next step, and the reason
   `status: DRAFT` and `reviewed_by: null`.

## Safe parallelism

```yaml
SAFE_PARALLEL_WORK:
  - "Applying the two decision-object scope notes (.decisions/**) — Manager-owned, append-only, text in revision §11."
  - "A lane owning add_product_page.dart (F-9 mock key) — read ADR §Decision status first: no copy may present that screen's key as installable."
  - "A lane owning repository_credential.dart doc comments (F-10) — :14-15 and :70-71 are stale by A2 and by A1; the type itself is correct."
  - "design-reviewer lanes for the keys and mobile rev-5 items — no path overlap."
PROHIBITED_PARALLEL_WORK:
  - "Any lane writing docs/adr/0018-per-product-git-credentials.md — serialise until revision 4 is reviewed."
  - "Retiring or re-counting accepted risk A1 by a design lane — that is the owner's register."
  - "Dropping either stash — evidence. Safe only as a deliberate recorded act, and note the ADR stash is at stash@{1}, not stash@{0}."
```

## Cleanup confirmation

- [x] **All processes started by this lane are stopped.** None were started.
- [x] **Temporary artifacts: none created** outside `OWNED_PATHS`.
- [x] **Worktree git state untouched.** No `stash`, `checkout`, `reset`, `merge`, `commit`, `push` or
      `clean` was issued. **Both stashes read-only and intact** — the ADR stash is at `stash@{1}`, and
      that is how I found it.
- [x] **No files modified outside `OWNED_PATHS`** — the ADR plus this task directory.
- [x] **`.decisions/**` untouched** — 14 objects, `git status` empty. H-3's required edit is
      **reported as text, not written**.
- [x] **Revisions 1, 2 and 3 unaltered** — retained as history, per the ADR's own `:37-40` convention.
      Revision 3's `report.md` was **copied to `report-revision-3.md`, not overwritten**.
- [x] **No Docker or Compose command was issued by this lane** — not `info`, not `ps`, not `logs`, not
      `config`, not any mutating one. This repository has already lost its QA database to a lane running
      `docker compose -f docker/compose.qa.yaml down -v --rmi local`; the rule was not tested. Compose
      files and Terraform were read **as text**.
- [x] **No commit, no push.**
- [x] **This lane did not approve its own work.**

## Recommended next action

**`DESIGN_REVIEW`** of `ADR0018-A2-REV4` — and the review should be asked for **the sweep**, not for the
eleven findings. The first question is not "are eleven right?" but **"are twelve or thirteen there?"**
Re-run W1–W6 independently; a higher count means the sweep is incomplete, which is the exact failure
mode that produced this revision. Second: **S-6**, because it is a correction *about review status* and
deserves the most suspicion. Third: **§1.4**, the declined hits — if one of those should have been
fixed, the omissions are now accounted for. Fourth: **M-4's authority line**, the judgement in this
revision most worth challenging.

In parallel, apply the two decision-object notes (§11) and route F-9, F-10 and the A1 retirement.

---

## Structured result

```text
RESULT: DESIGN_REVISION_COMPLETE

FEATURE: Add Product rebuild — ADR 0018 amendment A2, revision 4 (the stale-normative-text sweep)
BRIEF_ID: design-adr-0018-amendment (brief_version: n/a — no formal Design Brief exists; the dispatch header served as the brief, recorded rather than fabricated)
REVISION_ID: ADR0018-A2-REV4
REVISION_NUMBER: 4
BRANCH: design/adr-0018-amendment
BASE_SHA: 289f1d3
HEAD_SHA: 289f1d3  (UNCHANGED — no commit, no rebase, no fast-forward; ADR amendment UNCOMMITTED, 811 → 999 lines)
COMMITTED: NO

OWNED_PATHS:
  - docs/adr/0018-per-product-git-credentials.md    ← the ONLY file written outside the task directory
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/**
READ_ONLY_PATHS:
  - docs/adr/** (every other ADR)   - .decisions/** (all 14 objects)   - apps/**   - packages/**
  - infrastructure/**   - docker/** (read as text only)   - .github/**
  - docs/engineering/WORK_STATE.md, docs/engineering/dispatch/LANES.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**
  - docs/engineering/dispatch/tasks/design-review-*/**   ← my finding set, read in full
PROHIBITED_PATHS (written: none):
  - .decisions/**                  ← H-3/F-1: exact append-only note text REPORTED, not written
  - docs/adr/** except 0018-per-product-git-credentials.md
  - any production source          ← F-9, F-10 recorded as follow-ups, not edited
  - any Docker or Compose command  ← none issued, not even read-only

ARTIFACT_PATHS:
  - docs/adr/0018-per-product-git-credentials.md                                    (999 lines)
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-4.md
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-metadata-4.yaml
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/report.md

RISK_LEVEL: 3
RISK_RATIONALE: |
  Unchanged from revisions 1-3 and from the independent review's own INDEPENDENT_RISK_LEVEL: 3
  (RISK_LEVEL_AGREEMENT: YES). The level describes THE CHANGE BEING RECORDED — custody of a private key
  capable of repository WRITE access, on a security boundary, plus a core-workflow change (two-sided
  revocation and a runtime dependency that can block the credential path) — not the accuracy of the prose
  and not whether a human blessed it.
    1. Amends recorded architecture on a security boundary; no such secret exists in the repository today.
    2. Changes a core workflow: revocation gains a ShipIt-side action, plus a substrate whose
       unavailability blocks minting, verification and push together.
    3. Depends on enforcement that lives elsewhere and is still partly absent: no transport host-key
       enforcer, no secret-manager adapter, no handle-deletion code, registration not wired to a
       connectivity check, and the UI's deploy key still a client-side mock (F-9).
    4. Carries four accepted risks on a security boundary. Revision 4 closes NONE, adds no fifth, and
       does not re-count them — it records that A1's exposure no longer reproduces on main and ROUTES the
       retirement to the owner.
    5. L-2 APPLIED: the prior rationale held Level 3 partly because "this revision newly discloses a
       security consequence". A disclosure neither raises nor holds a risk level. That item is REMOVED as
       a rationale and its removal is stated; the level rests on items 1-4, which are causal.
  Level 3 approval was satisfied 2026-10-06 by the repository owner (876c6b97). That satisfied the human
  gate; it does not satisfy independent review, which for REVISION 4 has never happened.

CHANGELOG: |
  ADR0018-A2-REV4 — the organising change is a SWEEP, not a fix. Eleven sites found against four
  reported; SUPERSEDED markers 4 → 10; ADR 811 → 999 lines. Revisions 1-3 retained unaltered as history
  per the ADR's own convention at :37-40.

  ALL ELEVEN FIXED: B-1 (headline struck, marked A1, current scope stated) · H-1 (custody row re-grounded
  on the field declarations; the stale doc comments named as NOT the evidence) · H-2a/H-2b (both rotation
  clauses struck and marked; the §Positive bullet's SUBSTANCE corrected, since it argued in favour of the
  design from a premise the document had abandoned) · H-3 (dated scope note covering all FOUR sites of the
  absolute; upstream half reported, not written) · M-1 (two rows added, table 9 → 11, which surfaced a real
  defect) · M-2 (same-uid exposure FILED in §Known gaps) · M-3 (570bb640 marked a decision id at both
  sites; all nine 8-hex tokens classified) · M-4 (six A1 sites corrected, verified against main c6f301d)
  · L-1 (numbering bases labelled) · L-2 (non-causal rationale item removed).

  BEYOND THE FINDING SET: S-1 public-half clause had no row and targeted "the product's repository" ·
  S-2 reference example was the PRE-A1 name, which two repositories of one product would collide on ·
  S-3 "N products means N keypairs", contradicted four lines below by a bullet that already had it right ·
  S-4/S-5 §Mitigation per-product wording · S-6 §Status claimed "has never been independently reviewed",
  which is FALSE — the rev-3 review exists on main, and this is G-17's own defect class reproduced by the
  revision that fixed G-17, complete with a prescription · S-7 M-4 sized at six sites, not three.

  NEW DISCOVERIES PERSISTED IN THE ADR (both owned): F-9 add_product_page.dart renders a CLIENT-SIDE MOCK
  deploy key (:126-138) with a "Copy public key" affordance — no server-issued public half reaches the UI;
  F-10 repository_credential.dart's doc comments state the superseded A2 custody model and the pre-A1
  reference name. Both are production source and are routed, not absorbed.

TRACEABILITY:
  REQUIREMENTS_COVERED: |
    All ten findings B-1, H-1, H-2, H-3, M-1..M-4, L-1, L-2 — per-finding disposition above and
    revision §2. The class sweep: six axes (W1 per-product scope, W2 custody, W3 rotation scope, W4
    revocation, W5 key-count arithmetic, W6 reference-name format), each hit adjudicated as
    marked / quoted-history / correct-as-written / unmarked-and-normative, with DECLINES recorded and
    reasoned in revision §1.4 so the sweep is auditable rather than a search. Both reviewer calls adopted:
    G-b surfaced AND filed; H-3's upstream remedy specified as append-only text with LEARNING_POLICY.md:261
    and the ADR's own :37-40 cited as the basis. Hard rules: no Docker/Compose command of any kind; only
    the ADR written outside the task directory; no .decisions/** write; both stashes left untouched and
    the dispatch's stale stash@{0} reported; no commit; no push; exact provenance with the ADR line count
    before and after.
  REQUIREMENTS_GAPS: |
    G-a — 9417f8bf:113/:140/:210 and 876c6b97:20 still carry the absolute. PROHIBITED (Manager-owned);
      exact append-only note text supplied for both objects in revision §11.
    G-b — the same-uid exposure is now FILED but still has NO OWNER; 876c6b97:136-161 assigns A2 to
      design-agent and A3/A4 to implementation/deployment authority, and this belongs to neither.
      Substrate-independent, so no new gate — but the Manager must route an owner.
    G-c — A3 reachability remains UNVERIFIED; needs the runtime probe assigned outside this scope.
    G-g — F-9 and F-10 are production source; recorded as §Known gaps follow-ups and routed, not absorbed.
    G-i — accepted risk A1's exposure is CLOSED on main c6f301d but the risk is NOT retired from the
      owner's register and the count stays four; that is the Manager's/human's action.
    G-h — the dispatch's stash@{0} reference is stale (the ADR stash is at stash@{1}); recorded as F-12.
    G-d (carried) — revision 2's own review report remains lost; revision 3's IS now on disk.
    Independent design review of revision 4 has not happened.

DESIGN_SYSTEM_COMPLIANCE: PASS
  PASS (not applicable — this revision authors no UI). It does tighten the operator-facing copy
  constraints recorded for the mobile lane, and M-1 adds a new binding one: no copy may present the
  Add Product screen's key as installable, because that value is a client-side mock (F-9). A mobile lane
  reading only §Amendments A2 would not know this. Recorded for routing; apps/control_plane/** is outside
  this lane's write scope.

UX_ACCESSIBILITY_SCORE: PASS
  PASS (not applicable — no interface added, removed or restyled). The accessibility surface of this
  artifact is the ADR, and this revision improves it in the property that matters for a document a future
  reader must trust without the author's session: every superseded clause now carries a visible marker
  (4 → 10), decided-vs-built is a table with per-row evidence rather than prose, the same-uid exposure is
  reachable from §Known gaps rather than only §Accepted risks, and the two passages that actively mislead
  — a stale scope headline and a false review-status claim — are corrected rather than left to be found.

IMPLEMENTATION_FEASIBILITY: MEDIUM
  Unchanged. A3 is decided, provisioned in this repository's Terraform, NOT wired to the credential path,
  and UNVERIFIED for reachability; no adapter, no resolver, no endpoint, no handle-deletion code.
  Revision 4 improves what an implementer inherits without changing the estimate: rotation is correctly
  scoped and confirmed built; the public-half UI is marked partly-built with the mock named (a DISCOVERED
  prerequisite, not one revision 4 created); immutability is recorded as stronger than the e391c02
  reading; and the pre-A1 reference-name form is forbidden by name, since two repositories of one product
  would collide on it.

DISCOVERIES:
  F-8  WORKFLOW_IMPROVEMENT — the stale-normative-text class is systemic and self-renewing: eleven sites
       against four reported, and the most damning instance (S-6) is G-17's own defect reproduced by the
       revision that fixed G-17. A correction pass that repairs only its finding set reliably leaves the
       class alive. Recommend the correction-loop contract require a class-sweep step with a stated
       axis list, an explicit count, and a record of which hits were DECLINED and why. Reported.
  F-9  PROJECT_FACT — add_product_page.dart renders a client-side MOCK deploy key (_generateMockKeyPair,
       :126-138), offered with "Copy public key". No server-issued public half reaches the UI, so an
       operator can install a key registered nowhere — the "non-installable mock" 73097d48 was issued to
       replace, still present. Persisted in the ADR (owned). Fix is production source; routed.
  F-10 PROJECT_FACT — repository_credential.dart's doc comments state the superseded A2 custody model
       (:14-15, :70-71) and the pre-A1 reference name; :20-27 is correctly A1-aware. The type is
       unaffected, so this is comment hygiene. Persisted as NOT-the-evidence in §Decision status plus a
       §Known gaps follow-up. Fix is production source; routed.
  F-11 PROJECT_FACT + CONTRADICTION — accepted risk A1's substance is closed on main c6f301d by 08c7590;
       six ADR sites stale-wrong. Verified fact PERSISTED with citations; the register retirement
       REPORTED, not taken. The only correct disposition: correcting stale claims is a design lane's job;
       closing an accepted risk is the owner's.
  F-12 WORKFLOW_IMPROVEMENT — a stale stash index is a citation hazard: the dispatch's stash@{0} is now
       stash@{1}. Recommend pre-flights name preserved evidence by LABEL or content hash, never by index.
  F-13 PROJECT_FACT — all nine 8-hex tokens in the ADR are decision-object ids and all six 7-hex tokens
       are commits; `git log` fails on every one of the nine. M-3 was one instance of a systematic
       ambiguity. Persisted.
  F-14 PROJECT_FACT — revision 3's own metadata repeated S-6 ("HAS NEVER HAPPENED ... at any revision").
       Reported; retained unaltered as history and superseded, the same device revision 3 used for 1-2.

KNOWLEDGE_PERSISTED:
  - "docs/adr/0018-per-product-git-credentials.md — eleven marked/corrected clauses, §Decision status
     landing note against main c6f301d, dated scope note on the four decision-object sites, three new
     §Known gaps entries (same-uid exposure, stale custody doc comments, re-verification obligation), and
     the corrected review-status block. All inside OWNED_PATHS."
  - "design-revision-4.md + design-revision-metadata-4.yaml + report.md in this task directory."
  - "NOT persisted here, by design: the two .decisions/** scope notes (Manager-owned — text supplied in
     revision §11); the retirement of accepted risk A1 (owner's register); an owner for the same-uid
     exposure; and the F-9/F-10 production-source fixes. Each is reported with its precise text or its
     exact file:line."

BLOCKERS:
  - none. blockers: []. No HUMAN_DECISION_REQUIRED gate is raised — revision 4 changes no substrate, no
    revocation model, no accepted gap, no clause of the owner's answer, and adds no requirement on any
    implementer. Manufacturing a gate would be the same error as asserting an unsupported state, in
    process form. The one arguable gate — retiring accepted risk A1 — is deliberately NOT decided here and
    is routed instead.

READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES
```

---

**One closing judgement.** Revision 3 was right that its verification was sound and wrong about what that
meant. This revision's finding is narrower and less comfortable: the defect was not G-17's tense, and it
was not four sentences. It was a class, the class is bigger than any single review's finding list, and the
revision that fixed G-17 wrote a fresh instance of it into the same §Status block while a ten-finding
review sat on `main`. That is the argument for requiring a sweep with a stated count — not because eleven
is certainly the right number, but because **a number is falsifiable and a repaired sentence list is
not.** I have given you eleven and the greps that produce them; the next reviewer should try to make it
thirteen.