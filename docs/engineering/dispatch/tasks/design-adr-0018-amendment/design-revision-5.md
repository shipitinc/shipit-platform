# Design Revision 5 — ADR 0018 amendment A2: sweep the referential class, retire accepted risk A1

**Supersedes Design Revision 4** (`design-revision-4.md`, `design-revision-metadata-4.yaml`) as the
current description of amendment A2's design state. Revisions 1–4 are **retained unaltered** as
history, per this ADR's own convention at §Amendments (`:65-68`): *"Amendments are recorded by
revision, not by silent rewrite."*

Revision 4 was right about the class it swept and wrong about which class was largest. It swept
**claims** — six axes over normative text — and found eleven, and that count survives independent
re-derivation. But the defect its own finding **M-3** had just proven is **referential integrity**,
and revision 4 swept only *hex tokens*. Five line-number citations resolved into the wrong text when
revision 4 was reviewed; **one of them was introduced by revision 4 and propagated by the Manager
into a resolved human decision object.** This revision sweeps that axis.

It also records a decision that is **not mine**: the repository owner retired accepted risk A1 on
2026-10-07. Two prior lanes deliberately declined to do this and were right to.

| Field | Value |
|---|---|
| Task | `design-correct-adr-0018-a2-4` (correction pass) |
| Revision number | 5 |
| Supersedes | `ADR0018-A2-REV4` (`status: DRAFT`, `reviewed_by: null`) |
| Branch | `design/adr-0018-amendment` |
| Base SHA | `289f1d3` — **fast-forwarded to `1c3f5ad`** per the dispatch pre-flight; the ADR amendment itself is still **uncommitted** |
| HEAD after fast-forward | `1c3f5ad` — **unchanged by this lane**; no commit, no rebase, no push |
| Re-verified against | **`main` `762e5cd`** (dispatch named `1c3f5ad`; `main` had advanced two further commits) |
| Worktree | `/private/tmp/shipit-design-adr0018` |
| Artifact corrected | `docs/adr/0018-per-product-git-credentials.md` (999 → **1212** lines) |
| Risk level | **3** (unchanged — see §7) |
| Status | **DRAFT — correction. Never independently reviewed.** |

---

## 0. Scope, ownership, provenance

### OWNED_PATHS — as declared, and what was actually written

- `docs/adr/0018-per-product-git-credentials.md` — **the only file written outside this task
  directory.** ✅
- `docs/engineering/dispatch/tasks/design-adr-0018-amendment/**` ✅ — `design-revision-5.md`,
  `design-revision-metadata-5.yaml`, `report.md`, and `report-revision-4.md`.

### PROHIBITED_PATHS — written: none

`.decisions/**` — **read only.** Three corrections are needed there (§11) and the exact append-only
text is reported, **not written**. No ADR other than 0018. No production source. No QA artifacts.

### Isolation pre-flight — the fast-forward, and the six files it nearly destroyed

The dispatch required a `--ff-only` onto `1c3f5ad`. **It failed**, and the reason is worth recording:
six untracked files in this task directory — `design-revision-3.md`, `design-revision-4.md`,
`design-revision-metadata-3.yaml`, `design-revision-metadata-4.yaml`, `report-revision-3.md`,
`report.md` — were **byte-identical copies of what had already landed on `main` at `1c3f5ad`**.
Verified by `shasum -a 256` against `git show 1c3f5ad:<path>` for all six: **all six IDENTICAL**.
Copied to a temp directory outside the repository before removal, then fast-forwarded. **No artifact
was lost and none was rewritten.** Had this lane obeyed the pre-flight blindly, it would have had to
choose between refusing to start and deleting six files whose provenance it had not checked.

`1c3f5ad` **does not touch the ADR** (`git diff --stat 289f1d3 1c3f5ad -- …0018…` → empty), so the
uncommitted amendment carried through the fast-forward intact.

### Both stashes — verified BY LABEL, untouched

```
stash@{0}: On design-correct-addproduct-mobile: rev5-uncommitted-identical-to-16cd497
stash@{1}: On design/adr-0018-amendment: ADR0018 A2 rev1 local edit (… sha256 9e5b4772) -- preserved
```

Resolved by **label substring** (`stash list --format='%gd %s' | grep 'adr-0018-amendment'`), not by
index:

- `git show '<that ref>':docs/adr/0018-per-product-git-credentials.md | shasum -a 256` →
  `9e5b47723e40fd0fd42b69ddf4b5330768ca4fcf782acb0f1992e7aebb83b4fb`
- `git show main:docs/adr/0018-per-product-git-credentials.md | shasum -a 256` → **the same**
- Both **580 lines**.

**The ADR stash is byte-identical to `main`'s ADR and both stashes are exactly as found.** I issued no
`stash`, `checkout`, `reset`, `commit`, `push` or `clean`.

### No Docker or Compose command was issued by this lane

Not `info`, not `ps`, not `logs`, not `config`, not any mutating one. **This repository has already lost
its QA database** to a review lane running `docker compose -f docker/compose.qa.yaml down -v --rmi
local`. The rule was not tested. Every finding below is a `git` query, a file read, or a Python
resolution script. Compose files and Terraform were read **as text**.

### This lane does not approve its own work

Revision 5 has **never been independently reviewed**. `reviewed_by` and `reviewed_at` are `null`;
`status` is `DRAFT`. Two independent reviews of this amendment exist — revision 3 at
`design-review-adr-0018-a2-rev3` and revision 4 at `design-rereview-adr-0018-a2-rev4` — and **both
returned `CHANGES_REQUIRED`**. That is the durable statement and the ADR now carries it in that form
(§1).

---

## 1. The central finding, stated so a reviewer can check it

Revision 4's own F-8 recommended that the `aef-correction-loop` contract require *"a class-sweep step
with a stated grep/axis list and an explicit count."* **The axis list is the deliverable.** Revision 4
stated six — all six about **claims** — and its own finding **M-3** (*"`570bb640` cited as a commit;
`git log` fails"*) was a finding about a **reference**. So revision 4 proved the reference class
existed and then swept only hex tokens, declaring M-3 fixed.

The re-reviewer put it as: *"W1–W6 swept claims. The class also includes the references into those
claims."* That is correct, and the fix is not cosmetic. **This ADR argues at §Amendments A2 →
"never holds key bytes" (`:188-190`) that a wrong absolute is more dangerous than an absent one,
because a reader who trusts it will not look for the real exposure** — and revision 4 shipped **five
citations that land 43 lines off the quoted text**, one of them into a human decision record.

**Axis R7 — the axis revision 4 did not name: does every cross-reference in this artifact resolve?**
Every `file:line`, every bare `:NNN`, every `decision-id:NNN`, every `AGENTS.md:NNN`. Mechanical,
exhaustive, and — as §2 shows — it finds more than the re-reviewer reported.

---

## 2. The sweep: what it found

### 2.1 Method — mechanical first, adjudicated by hand, and re-run after every edit

1. Extract **every** `:NNN` token in the ADR with its immediately preceding token (so `file:NNN` is
   distinguishable from a bare internal `:NNN`). 138 tokens at 999 lines.
2. Classify each: internal-self-referential, into another file, into a decision object, a timestamp,
   or noise.
3. Resolve **every** external range at **the revision the document itself declares as that
   citation's anchor** — not at `main`. `git show <anchor>:<path>`.
4. Re-run the five **negative** search claims, which are the only claims here that cannot be checked
   by reading a line.
5. **After every edit, re-derive every internal citation from the live file.** Line numbers move when
   you edit. This is not a formality: **my own edits broke three of the anchors I had just written**
   (`:52-55`, `:152-154`, `:430-436` → `:65-68`, `:188-190`, `:488-494`), and I caught them only
   because step 5 exists.

### 2.2 The result — **NINE distinct broken cross-references across FOURTEEN citation sites**

That is the number the dispatch asked for, and it is the real measure of whether the sweep was done.

| # | Broken reference | Sites | Should be | Reported by the re-reviewer? |
|---|---|---|---|---|
| **1** | `9417f8bf:116-119` for the same-uid reasoning | **5** (ADR `:180`, `:224`, `:959`, `:1016`, `:1111`) | **`9417f8bf:159-160`** (+ `9417f8bf:96-97`) | **yes — H-R1** |
| **2** | `:219` for §Amendments A2 → "What survives A2 unchanged" | 1 (ADR `:509`) | `:284` / clause `:289` | yes — H-R3 |
| **3** | `:37-40` for the §Amendments marking convention | 1 (ADR `:1141`) | **`:65-68`** | yes — H-R3 |
| **4** | `:137-139` for "a false absolute is worse than an absent one" | 1 (ADR `:1143`) | **`:188-190`** | yes — H-R3 |
| **5** | **`:96-99`** for the host-key clause, used **outside §Amendments** | **2** (ADR `:711`, `:879`) | **§Decision → Specifics `:488-494`** | **NO — new** |
| **6** | **`876c6b97:53-55`** for the reachability gap | 1 (ADR `:909`) | **`876c6b97:54-56`** (phrase at `:55`) | **NO — new** |
| **7** | **`docs/engineering/WORK_STATE.md:326-327`** for the structured-question relay | 1 (ADR `:1176`) | **`876c6b97:117`** + `design-revision-2.md:400` | **NO — new** |
| **8** | **`infrastructure/modules/cloudbuild/main.tf:72-76`** | 1 (ADR `:934`) | **`:73-76`** — `:72` is blank | **NO — new** |
| **9** | **`apps/server/tool/schema_bootstrap.sql:98-100`** — correct at its anchor, **moved on `main`** | 2 (ADR `:368`, `:645`) | `schema_bootstrap.sql:112-114` on `main`; `verify_schema_bootstrap.sh:91` → **`:130`** | **NO — new** |

**Reported (H-R3, three distinct pointers at four sites). Mine alone: FIVE distinct pointers at TEN
sites.** Including the ones the re-reviewer had already named, the re-reviewer's script reported five;
my re-derivation finds nine.

### 2.3 The five I found that nobody had reported

**#5 — `:96-99`, the A1-revision number leaking outside §Amendments.** The convention at `:65-68`
scopes pre-revision line numbers to §Amendments **only**. Two sites used an A1-revision number from
outside §Amendments: §Invariants (`:711`) and the §Accepted risks A2 heading (`:879`). In the
999-line file `:96-99` is **a row of the "Decisions recorded" table naming `27ea6536`** — the reader
lands on an unrelated decision. The clause both sites mean is §Decision → Specifics `:488-494`. Both
now carry the **section name** beside the number.

**#6 — `876c6b97:53-55`.** The object is 200 lines; `:55` is the `value:` line of the "Four gaps the
amendment recorded as open" metric and holds the quoted phrase *"the external secret manager's
reachability has never been runtime-probed"*. **`:53` is the previous metric's `source:`.** The ADR
cited a range starting one line above the quote and including an unrelated line. Now `876c6b97:54-56`
with `:55` named.

**#7 — `WORK_STATE.md:326-327` — the worst one, because it never resolved at all.** The ADR claimed
the structured-question answer was "recorded at `docs/engineering/WORK_STATE.md:326-327`". Verified:
that range reads *"Verified again by the Manager on the merged tree: format **631/0** · analyze **exit
0** …"* — validation output. A `git rev-list --all -- docs/engineering/WORK_STATE.md` sweep across
**all fifteen revisions** of that file for `record the gaps as accepted` / `accept a2` returns **no
match at any revision**. The relay was never there. **The defect predates amendment A2** — it entered
with `5436a4d` and survived three revision passes unexamined, which is the same class as the §Related
citations revision 4 introduced. Corrected to `876c6b97:117` (the decision object, which is the
authoritative and append-only-stable home) plus `design-revision-2.md:400`, and the correction is
recorded in the ADR rather than made silently.

**#8 — `cloudbuild/main.tf:72-76`.** `:72` is a blank line. The claim starts at `:73`. Small, but it is
exactly the shape that trains a reader to distrust the document's pointers.

**#9 — the one that is not an error and is still the most instructive.** `schema_bootstrap.sql:98-100`
and `verify_schema_bootstrap.sh:91` are **exact at `43d328b`**, where §Invariants anchors them, and
**wrong on `main` today**: the index moved to `:112-114` (its comment block grew) and the assertion
moved to `:130`, where the asserted string itself became `…:both`. **The migration path did not
move.** So of the three citations that make the "both paths agree" claim, **one resolves, one lands on
the wrong line, and one lands on a blank line — while all three remain correct as of their stated
anchor.** This is the ADR's own hazard reached by **drift rather than error**, which is worse, because
nothing announces it.

### 2.4 And the one revision 4 *claimed* to have recorded and never did

Revision 4 § 2 (M-4) states: *"The landing obligation survives and is stated … §Known gaps records that
re-verification against `main` is a standing obligation at commit time, not a one-off."*

**`grep -i 'obligation|at every commit|commit time'` over the 999-line ADR returns nothing.** The
obligation was asserted and never written. It is now written — as a §Known gaps entry that names the
two citations that have drifted since, so the obligation is discharged once, visibly, rather than
promised.

### 2.5 What the sweep found and deliberately did **not** change

| Hit | Why left alone |
|---|---|
| `9417f8bf:194-201` as a same-uid source (revision 4's § 1.4 decline row) | It is **OPTION_D's description and implications** (verified: `:192` `option_id: OPTION_D`, `:194-196` description, `:197-201` implications). Revision 4's decline called it "correct, current, and cited **as** the source of the same-uid reasoning" — wrong, and **the decline is retained unaltered in revision 4**; this ledger is the correction |
| `# ADR 0018: Per-Product Git Credentials` (the title) | The most visible unmarked per-product claim in the file. **Declined with the reason now written into the ADR**: a title is an *identifier*, retitling breaks fifteen citing files, three dependent ADRs and the prose of `876c6b97:8-12`, and no implementer reads scope off it. A decline that is not recorded is indistinguishable from an oversight |
| `:85-88`, `:100-102`, `:113-114` in §Amendments | Correct **by the convention** — A1-revision numbers, in the section the convention scopes. The convention is now stated explicitly rather than left to be inferred |
| `:466-471`, `:14-15`, `:70-71`, `:306-310`, `:1162-1167`, `:1034`, `:63`, `:20-27` … (bare, after a named file) | Contextually attributed by the preceding file name and verified in that file. Bare-by-convention, not broken |
| All 138 tokens that are timestamps (`14:20:00Z`, `22:11:24`) | Not citations |

---

## 3. Per-finding disposition

### H-R1 — `9417f8bf:116-119` is a wrong citation, propagated into a resolved human decision object → **FIXED in the ADR at all five sites; the decision-object half REPORTED, not written**

**Verified independently, not taken on trust.** `9417f8bf:116-119` is the tail of the "Where the
guarantee lives" assessment (`unavailability lands directly on the fail-open/fail-closed question in
7b1bc8b7…`) plus the head of the "Insider/backup exposure" dimension. The quoted sentence — *"permissions
do not defend against a same-uid process — which is the git transport"* — is at **`:159-160`**, inside
OPTION_A's `implications`. A **second, independent** statement of the same property is at **`:96-97`**,
where it is recorded as a *metric*: *"A1 filesystem-only protection against a same-uid process / none —
the git transport runs as the same uid that would read the file."*

**The substance was always right** — the object *does* contain the correct reasoning, so it *is*
internally inconsistent and the reconciliation holds. Only the pointer was wrong. All five ADR sites
now cite `9417f8bf:159-160` and **name `:96-97` as the second witness**, which is the stronger form
because it is stated as a measured fact rather than prose.

**The decision-object half I did not write.** `.decisions/**` is `PROHIBITED`. The exact append-only
correction is in **§ 11.1** for the Manager.

**One judgement I made differently from the re-reviewer, and I will defend it.** The re-reviewer
recommended correcting `design-revision-4.md` § 11.1 and § 1.4. **I did not, and did not edit
`design-revision-metadata-4.yaml` either — both contain the wrong pointer and both stay unaltered.**
Revision 4 is on `main` at `1c3f5ad`; it is a reviewed artifact; and the no-silent-rewrite device is the
one thing that has survived four passes in this work item. Editing it would create the first divergence
between a committed artifact and its reviewed content, and it would destroy the evidence that the class
recurs. § 2.5 records what revision 4 got wrong, in revision 5, which is the device. **If the Manager
prefers a footnote on revision 4 itself, § 11.3 gives the exact text.**

### H-R2 — §Accepted risks' preamble said "Nothing here is closed", which revision 4 made false → **FIXED, and then superseded by the retirement**

The re-reviewer's fix was right and is applied in substance. But the dispatch authorized the
retirement, so the preamble is now stronger than the re-reviewer's replacement: it states the count
(**one retired, three recorded**), names **who** retired it and **that two prior lanes were right to
decline**, and states **what retirement does not reach**.

`:691`'s narrower phrasing ("None is closed by the wording changes") showed the distinction was known
and simply not applied at `:687`. Both are now applied.

### H-R3 — three internal `:NNN` citations broke under the +188-line growth, one introduced by revision 4 → **ALL THREE FIXED, AND EVERY REMAINING ONE RE-DERIVED**

`:219`→`:284`, `:37-40`→`:65-68`, `:137-139`→`:188-190`. The re-reviewer was right that "three found
broken by one growth event is an undercount, not a sample" — **it was an undercount, by five distinct
pointers.** See § 2.2.

**And the durable answer to the growth problem:** every self-referential citation in the ADR now
carries **its section name beside its line number**, so the next growth event degrades it to a stale
pointer rather than a wrong one — which is strictly better, because a stale number next to a correct
section heading is still findable, and this ADR's own argument is that a wrong one stops the reader
looking at all.

### M-R1 — `.decisions/876c6b97:122-123` carries a false review-status absolute → **CONFIRMED; REPORTED, not written; the ADR's half is fixed**

`:122-123` reads verbatim: *"`reviewed_by` and `reviewed_at` remain `null` because independent design
review of the amendment has still never happened."* Neither the appended note nor the ADR mentions it.
**Confirmed stale**: two independent reviews of this amendment now exist and both returned
`CHANGES_REQUIRED`. The device is an **appended dated note, never an edit** — the rationale is the
human's own recorded answer. Exact text: **§ 11.2**.

The ADR's own half is fixed and phrased in the durable form the re-reviewer endorsed: **"`reviewed_by`
names a reviewer who *approved*. No reviewer has approved any revision of A2."** The contingent
prescription (*"stays null until a reviewer signs it"*) is **removed** — a prescription keyed to a
contingency is how the original defect was born.

### M-R2 — the decline ledger is incomplete; §Known gaps holds CLOSED items under "Remaining items" → **BOTH FIXED**

The title now has a written decline in the ADR (§ 2.5) with its reason. §Known gaps' header now says
*"Open items, plus entries closed later and retained as history"* and states that its list is not a live
count — which was the "claiming sentence outrunning the table" failure in a different key.

### M-R3 — the correction-loop contract should name a reference-resolution axis → **CARRIED, unchanged and reinforced**

Revision 4's F-8 recommendation is right and is why this review found H-R1–H-R3. Revision 5's evidence
sharpens it: an axis list is a deliverable, **and the producing lane cannot be the only auditor of its
own completeness.** Revision 4 stated six axes and the reviewer had to find a seventh. **A stated axis
list plus an independently re-run axis list**, with the counts compared, is what catches this. That is
now the recommendation (§ 10, F-15).

### L-R1 — `reviewed_by: null` → **ENDORSED, wording aligned to the stronger reason.** Not re-litigated.

### L-R2 — F-9 is stronger than recorded → **CORRECTED, and it is stronger than the re-reviewer stated**

Verified `_onRegisterProductRequested` (`add_product_page.dart:145-181`) in full: `createProduct`
(`:161`), then `addRepositoryReference` (`:169`) with **`repositoryId: productId` and the comment
*"Use productId as repositoryId for simplicity"* (`:171`)**. **There is no credential-creation call in
the flow at all.** So the mock is not merely unregistered — **it is never transmitted**, and the
register path violates **A1's scope invariant** by writing the product's own name into the
repository-identity column. §Decision status's row and a new §Known gaps entry now say so, and
explicitly say that "partly built" must not be read as "cosmetic".

### L-R3 — the Manager's three applied notes are append-only, faithful and well-judged → **AUDITED, CONFIRMED, one defect reported**

I re-verified the byte-level property myself: `9417f8bf` **42 added / 0 removed**; `876c6b97` and
`27ea6536` **1 removed each**, being exactly the `updated_at` replacement carrying an inline comment,
below the marker. Quotes match verbatim; counts unchanged; `human_correction_verbatim` preserved
unedited with the owner's spelling explicitly protected. **The `27ea6536` framing is accurate**: the
object records the lane's *observation* (a footer copy line at (236,862) — I confirmed the
corroborating string at `add_product_page.dart:383-384`) and the owner was entitled to reverse the
*conclusion*. **The single defect in that work is the wrong pointer inside the `9417f8bf` note
(H-R1).** Reported in § 11.1; **not written.**

---

## 4. §Accepted risk A1 — the retirement, and what remains open

**Authorized and decided by the repository owner on 2026-10-07.** This is recorded, not made. Two prior
lanes declined to do it and were right: a lane asserting a state the record does not support is the
defect class this amendment exists to remove, and that principle is symmetric in direction. **That
boundary is why the evidence had to exist before the retirement could be honest** — and it did, from
revision 4.

**Retired in place**, with the date, the authorizing decision, and the evidence the owner was shown:
`product_registry_engine.dart:933-936`, `postgres_product_registry_store.dart:413-439` and `:466-471`,
`in_memory_product_registry_store.dart:178-185`, and `postgres_product_registry_store.dart:428-431` —
**all five re-read at `main` `762e5cd` on 2026-10-07 and all five still resolve**, four commits after
`c6f301d`.

**A2, A3 and A4 were NOT retired and remain recorded.** Three. The owner retired A1 only.

**What remains open, and why that is what makes the retirement honest.** A1 was the *resurrection*
half of the revocation clause. **The other half — no code destroys a secret-manager handle — is still
unimplemented**, re-verified at `762e5cd`, so **revocation remains one-sided in practice.** That is
`79e860e2`'s territory; it was **never** an accepted risk; and retiring A1 did not close it, accept it,
or transfer it to A2–A4. It is now stated in **five** places — §Amendments A2's status-change note, the
§Accepted risks preamble, the A1 entry itself, the §Decision status row, and §Consequences → Positive —
so that a reader cannot infer it away from A1's retirement. **A closed gap must never launder an open
one.**

**The identifier-collision table is updated, because "A1" now has THREE readings** in this file: a
substrate option (live), a retired risk id (live as a fact), and the historical risk id (what the owner
accepted). The table says so, and the A1 heading carries `RETIRED` in the heading itself.

---

## 5. Verify, do not assume — the dispatch's four checks, all re-run here

| Dispatch claim | My verification | Result |
|---|---|---|
| Manager's three append-only notes are sound, `27ea6536` framing included | `git show 1c3f5ad -- .decisions/` diff counts + object re-read | **confirmed** — 42/0; 1/1 ×2, both the `updated_at` line below the marker with an inline comment. Framing accurate |
| `human_correction_verbatim` unedited, owner's spelling protected | re-read `27ea6536` | **confirmed** |
| H-R1's wrong pointer inside the `9417f8bf` note is the one defect there | re-read `:266-268` of the object | **confirmed**, verbatim |
| F-9 is stronger; `20261006150645000` is on `main` and is newest; H-1's re-grounding is correct | `git ls-tree -r main -- apps/server/migrations/` sorted; `add_product_page.dart:145-181`; `repository_credential.dart:61-122` field-by-field | **all confirmed** — the migration is newest, the predecessor still present; 21 fields, no key material |

`main` has advanced from the `bd01bc0` the re-reviewer saw, past the `1c3f5ad` the dispatch named, to
**`762e5cd`**. `08c7590` remains an ancestor, so no M-4 claim moved — and I confirmed it directly rather
than inferring: all five A1-closure ranges still resolve at `762e5cd`.

---

## 6. Traceability

### Requirements covered

| Requirement | Source | Where satisfied |
|---|---|---|
| H-R1 — correct the `9417f8bf` pointer at every ADR site | Review, dispatch | ADR `:180`, `:224`, `:959`, `:1016`, `:1111`; § 11.1 for the object |
| H-R2 — the §Accepted risks preamble must not be falsified by its own body | Review | §Accepted risks preamble, rewritten with the count and the retirement |
| H-R3 — re-anchor all three, then re-verify **every** remaining citation | Review, dispatch | § 2.2 (nine distinct, fourteen sites), § 8 (V-1…V-40) |
| **Re-derive the class across the whole ADR** | Dispatch | § 2 — mechanical extraction of all 138 tokens, resolved at declared anchors |
| **Retire accepted risk A1** with date, authorizing decision, evidence | Human authorization | § 4; ADR A1 heading + three bullets + §Status + the count in five places |
| **Do not retire A2, A3, A4** | Dispatch | § 4; ADR A2–A4 untouched except the count |
| **Update the identifier-collision table — three readings of "A1"** | Dispatch | §Accepted risks collision table, third row added |
| **Record what remains open: no code destroys a secret-manager handle** | Dispatch | § 4; stated in five ADR locations |
| **Record that the retirement is the owner's, not a design lane's** | Dispatch | § 4; ADR §Accepted risks preamble and A1 bullet |
| **Align `reviewed_by: null` to the stronger reason if §Status is touched** | Re-reviewer L-R1 | ADR §Status correction block — rewritten in the durable form; prescription removed |
| **Report, do not write, the `.decisions/9417f8bf` correction** | Hard rule | § 11.1 — exact append-only text |
| **Correct §Known gaps if it understates F-9** | Dispatch, L-R2 | §Decision status row; new §Known gaps entry |
| **Record the title decline with its reason** | M-R2 | § 2.5; ADR §Amendments |
| **Re-head §Known gaps** | M-R2 | ADR §Known gaps header |
| **Re-verify against current `main`**; the obligation was claimed and never written | M-4, § 2.4 | § 2.4; §Known gaps standing-obligation entry; § 8 |
| **No Docker or Compose command, of any kind** | Hard rule | § 0; none issued |
| **Leave both stashes untouched; verify by label** | Hard rule | § 0; both verified by label, byte-identical |
| **Line numbers move — re-read after each edit** | Hard rule | § 2.1 step 5 — and it caught three of my own |
| **No `.decisions/**` write** | Hard rule | § 0; three corrections reported in § 11 |
| **Search the domain's own vocabulary; full paths, never basenames** | Hard rule | § 8 V-4 — `add_product_page.dart` resolves to one file; the ADR now records the **full path** because the mobile lane recorded a bare basename |
| **Do not commit or push** | Hard rule | § 0, § 9 |
| **Persist the report to disk** | Hard rule | `report.md` + `report-revision-4.md`, byte-identical preservation first |

### Requirements gaps

- **G-a (unchanged, escalated).** `9417f8bf:113`, `:140`, `:210` and `876c6b97:20` still carry the
  absolute. `.decisions/**` is Manager-owned. Append-only note text in § 11.1 and § 11.2 — **and now
  also the H-R1 citation correction, which the applied `9417f8bf` note needs.**
- **G-b (unchanged).** The same-uid exposure is filed in §Known gaps and **still has no owner**;
  assigning one is the Manager's call.
- **G-c (unchanged).** A3 reachability stays **UNVERIFIED**. Needs a runtime probe; needs Docker;
  **no probe is claimed and no Docker command was issued.**
- **G-g (widened).** F-9 is now three defects, not one: the mock key, **the register flow never
  transmitting it**, and **`repositoryId: productId` violating A1's scope invariant**. All production
  source; all filed; none fixable by a design lane.
- **G-i (new).** `design-revision-metadata-4.yaml:333` records the same non-existent
  `WORK_STATE.md:326-327` relay, with a paraphrase of text that file never contained. **Retained
  unaltered** as revision 4's metadata; reported in § 11.4.
- **G-j (new).** The pre-flight's `--ff-only` fails against this worktree because six untracked files
  shadow content already on `main`. **Any future dispatch that fast-forwards this worktree will hit
  it.** Reported as F-16.

---

## 7. Risk level

**RISK_LEVEL: 3** — unchanged from revisions 1–4 and unchanged from the re-reviewer's own assessment
(`INDEPENDENT_RISK_LEVEL: 3`, `RISK_LEVEL_AGREEMENT: YES`).

The level describes **the change being recorded**, not the accuracy of the prose.

1. **Amends recorded architecture on a security boundary.** It governs where a private key capable of
   authorising repository **write** access is held, and what "revoked" means. No such secret exists in
   the repository today.
2. **Changes a core workflow.** Revocation acquires a ShipIt-side action where ADR 0018 said none was
   required, plus a runtime dependency (the secret manager) that can block the credential path.
3. **Depends on enforcement that lives elsewhere and is still partly absent.** At `762e5cd`: no
   transport host-key enforcer, no secret-manager adapter, **no handle-deletion code**, registration not
   wired to a connectivity check, and the UI's deploy key still a client-side mock the register flow
   never sends (F-9).
4. **Carries accepted risks on a security boundary.** Three remain recorded (A2, A3, A4); the owner
   accepted four on 2026-10-06 and **retired A1 on 2026-10-07**. **Revision 5 retires nothing of its
   own authority, adds no risk, and closes no remaining one.**

**A disclosure neither raises nor holds a risk level.** Revision 4 removed that rationale (L-2) and the
removal was right. **Revision 5's retirement is not a disclosure — it is a change to what is carried on
a security boundary, recorded by the owner.** It does not lower the level either, because the level
describes the architecture, and the architecture is unchanged.

**Human gate:** Level 3 approval was satisfied on 2026-10-06 by the repository owner as ADR owner
(`876c6b97`), and the A1 retirement was the owner's own decision on 2026-10-07. **That satisfies neither
independent review nor the requirement that no reviewer has approved any revision of A2.** Revision 5
changes wording, citations, markers, one verified state record, and the recorded count. It changes **no
substrate, no revocation model, no accepted gap other than by the owner's retirement, no clause of the
owner's answer, and no requirement on any implementer.** **No new Level 2/3 decision is required, and
none is manufactured.**

---

## 8. Validation

Every command was run in `/private/tmp/shipit-design-adr0018`. **No Docker or Compose command appears in
this list or was executed.**

### 8.1 Isolation and provenance

| # | Check | Result |
|---|---|---|
| V-1 | `git branch --show-current` | `design/adr-0018-amendment` |
| V-2 | `git merge --ff-only 1c3f5ad` | **failed** — six untracked files shadow `main` content; `shasum` proved all six byte-identical to `1c3f5ad`, backed them up outside the repo, then succeeded |
| V-3 | `git rev-parse HEAD` after fast-forward | `1c3f5ad` — **unchanged by this lane** |
| V-4 | `git diff --stat 289f1d3 1c3f5ad -- …0018…` | **empty** — the fast-forward does not touch the ADR |
| V-5 | `git stash list` | both entries present, exactly as found |
| V-6 | ADR stash resolved **by label** → `shasum -a 256` | `9e5b4772…` vs `main`'s `9e5b4772…`, both 580 lines — **byte-identical** |
| V-7 | `git status --short` | one ` M` (the ADR) + four untracked task artifacts |

### 8.2 The referential sweep — resolution, not assertion

| # | Check | Result |
|---|---|---|
| V-8 | Extract every `:NNN` token with its preceding token | **138 tokens** at 999 lines; every one classified |
| V-9 | Resolve **every** external range at its **declared anchor** (`43d328b` / `289f1d3` / `762e5cd`) | **all resolve**; 0 out-of-range, 0 blank |
| V-10 | Same, on the **final 1212-line** file | **all resolve**; re-run after every edit |
| V-11 | Decision-object ranges: `9417f8bf` ×9, `876c6b97` ×7, `ae1c1f79` ×1 | **all resolve and are non-blank** |
| V-12 | Re-derive every **internal** bare `:NNN` after the final edit | **all resolve, or are §Amendments A1-revision by convention, or contextually attributed, or explicitly labelled superseded inside a correction block** |
| V-13 | `9417f8bf:116-119` read | fail-open/fail-closed tail + "Insider/backup exposure" head — **no same-uid text** |
| V-14 | `9417f8bf:159-160` read | the quoted sentence, verbatim, inside OPTION_A's `implications` |
| V-15 | `9417f8bf:96-97` read | the same property as a **metric** |
| V-16 | `9417f8bf:194-201` read | **OPTION_D** — revision 4's decline row is wrong; retained unaltered |
| V-17 | `876c6b97:53-55` read | `:53` is the **previous** metric's `source:`; the phrase is at `:55` |
| V-18 | `876c6b97:122-123` read | the M-R1 review-status absolute, verbatim; **confirmed stale** |
| V-19 | `WORK_STATE.md:326-327` read at `762e5cd` | validation output, not the relay |
| V-20 | `git rev-list --all -- WORK_STATE.md` (15 revisions) × grep for the relay | **no match at any revision** |
| V-21 | `ae1c1f79:8-11` read | the "citable id" precedent comment — **correct** |
| V-22 | `git ls-tree -r main -- apps/server/migrations/` sorted | `20261006150645000` **newest**; predecessor `20261001205247600` still present |
| V-23 | Five **negative** search claims re-run at `762e5cd` | **all five still return no match** |
| V-24 | `schema_bootstrap.sql` index at `43d328b` / `289f1d3` / `762e5cd` | `:98-100` / `:98-100` / **`:112-114`** — moved |
| V-25 | `verify_schema_bootstrap.sh` assertion at `43d328b` / `762e5cd` | `:91` / **`:130`**, string now `…:both` — moved |
| V-26 | `migration.sql:53-55` at `289f1d3` / `762e5cd` | **unchanged** |
| V-27 | `AGENTS.md:65`, `:72`, `:78`, `:91`, `:96-101` at `762e5cd` | **all five exact** |
| V-28 | `LEARNING_POLICY.md:261`, ADR 0012`:34`, ADR 0019`:121` | all exact |
| V-29 | `add_product_page.dart:542`/`:1038` at `762e5cd` | **both exact** — the ADR's "not re-verified" caveat discharged |
| V-30 | `add_product_page.dart:145-181`, `:171` | **no credential call in the flow**; `repositoryId: productId` confirmed |
| V-31 | `repository_credential.dart:61-122` field-by-field | **21 fields, no private-key field**; `:14-15`, `:20-27`, `:70-71` all exact |
| V-32 | All five A1-closure ranges at `762e5cd` | **all resolve** |
| V-33 | All four Terraform ranges + both negative searches | exact / no match |
| V-34 | `git show 1c3f5ad -- .decisions/` diff counts | 9417f8bf **42/0**; 876c6b97, 27ea6536 **1/1** each (the `updated_at` line, below the marker) |
| V-35 | `git status --short .decisions/` | **empty** — 14 objects untouched |
| V-36 | ADR line count | 999 → **1212** |
| V-37 | Revision 4 preserved before rewriting `report.md` | `report.md` → `report-revision-4.md`, sha256 `81db0f67…` both, and equal to `main`'s `report.md` |
| V-38 | `git grep` re-run of `27ea6536`'s corroborated string | present at `add_product_page.dart:383-384` |
| V-39 | Docker / Compose — any command | **NOT_RUN.** Deliberately. None issued, not even read-only |
| V-40 | A3 reachability runtime probe | **NOT_RUN.** Needs Docker; **no probe is claimed** |

**Not validated, and not claimed:** A3 reachability; whether the Cloud Run workload identity can resolve
a secret; any behaviour of the git transport; the merits of any of the nine resolved decisions; that the
mobile copy at `add_product_page.dart:542`/`:1038` is *discharged* (the string is confirmed present —
the mobile lane owns the fix); §Accepted risks A2, A3 and A4, which this revision does not re-verify
beyond re-reading their cited evidence.

---

## 9. Discoveries

Classified per `docs/engineering/LEARNING_POLICY.md`. Nothing outside `OWNED_PATHS` was written;
items above this lane's authority are reported, not persisted here.

| # | Finding | Class | Authority | Disposition |
|---|---|---|---|---|
| **F-15** | **The axis list is the deliverable, and a producing lane cannot be the only auditor of its own completeness.** Revision 4 stated six axes; the reviewer had to find a seventh. Nine distinct cross-references were broken across fourteen sites — **five of them at sites nobody had reported, and one (`WORK_STATE.md:326-327`) that never resolved at any revision in the file's entire history.** **The correct contract clause is not "state an axis list"; it is "state an axis list AND have it independently re-run, with both counts compared."** A stated list the producing lane audits is a search. | `WORKFLOW_IMPROVEMENT` | Independent review | **Reported.** Extends F-8. Concrete clause: *every `file:line` and `:NNN` cross-reference in the edited artifact resolves at the anchor the artifact names for it, or is explicitly marked as referring to a named prior revision* — mechanically checkable, and this lane detected the entire class in one script |
| **F-16** | **A `--ff-only` pre-flight can fail against untracked files that shadow committed content — and the safe response is to hash them, not delete them.** Six untracked files here were byte-identical to `1c3f5ad`. | `WORKFLOW_IMPROVEMENT` | Independent review | **Reported.** Dispatch pre-flights that fast-forward a worktree should either tolerate this or tell the lane to verify-and-back-up rather than delete |
| **F-17** | **A wrong pointer propagates further than the document it came from.** `9417f8bf:116-119` reached five sites in the ADR, the revision that prescribed the note, **the note the Manager actually applied to a resolved human decision object**, and that object's sibling note in `876c6b97`. `.decisions/**` is where a reader is *most* likely to land, because it is the citable id. | `PROJECT_FACT` | Automatic (verified) | **Persisted** in the ADR's §Related scope note. The object-side fix is **reported** (§ 11.1), not written |
| **F-18** | **A claim about your own artifact can be as false as a claim about anyone else's.** Revision 4 stated that §Known gaps records the standing re-verification obligation. `grep -i obligation` over the ADR returned **nothing**. | `PROJECT_FACT` | Automatic (verified) | **Persisted.** The obligation is now written, and discharged once, visibly, with the two citations that have drifted since |
| **F-19** | **The mobile register flow never transmits the deploy key and violates A1's scope invariant.** `add_product_page.dart:169-175` passes `repositoryId: productId` with a *"for simplicity"* comment; there is no credential-creation call in the handler. Stronger than F-9 as recorded. | `PROJECT_FACT` | Automatic (verified) | **Persisted** in §Decision status and §Known gaps. Fix is production source — reported |
| **F-11** | **Accepted risk A1 retired by the owner on 2026-10-07.** Recorded as verified state with citations; three risks remain. | `PROJECT_FACT` + `CONTRADICTION` | Verified fact **persisted**; the retirement is **human/Manager authority** | **Persisted.** The retirement is the owner's; two prior lanes' refusal was correct; the second half of the revocation clause is stated as still open in five places so the retirement cannot launder it |

---

## 10. Blockers

**None.** `blockers: []`. **No `HUMAN_DECISION_REQUIRED` gate is raised**, reasoning so it can be
challenged: the A1 retirement is the owner's own decision and this revision records it; nothing in
H-R1–H-R3, M-R1–M-R3 or my own findings requires a human to choose between options — each has exactly
one correct repair, and every one is either inside `OWNED_PATH` or an append-only note, which is the
device `LEARNING_POLICY.md:261` prescribes for a `CONTRADICTION`. Manufacturing a gate here would be
the process-form of the same error revision 4 correctly avoided.

**Surfaced for the Manager**, none of which this lane may decide:

1. **§ 11.1** — append the citation correction to `.decisions/9417f8bf`. **`.decisions/**` is
   `PROHIBITED` here and the wrong pointer is inside a note you applied.**
2. **§ 11.2** — append the review-status scope note to `.decisions/876c6b97` (`876c6b97:122-123`).
3. **§ 11.3** — optional footnote on `design-revision-4.md` § 11.1 / § 1.4 (I declined to edit it; text
   supplied).
4. **§ 11.4** — optional correction note on `design-revision-metadata-4.yaml:333`.
5. **G-b** — the same-uid exposure is filed in §Known gaps and **still needs an owner**.

Plus, for routing, all production source this lane may not write: **F-19** (three defects in the Add
Product register flow) and **F-10** (stale custody doc comments).

---

## 11. The exact text the Manager must apply — reported, not written

`.decisions/**` is Manager-owned and `PROHIBITED` to this lane. **Append-only throughout. Never rewrite a
resolution rationale or a human's verbatim words** — that is the human's own recorded answer, and
`LEARNING_POLICY.md:261` prescribes *"surface and reconcile — do not silently overwrite"* for a
`CONTRADICTION`. Same device as the ADR's own §Amendments convention (`:65-68`).

### 11.1 `.decisions/9417f8bf-73b8-4827-9515-bdfe92e5a9d5.yaml` — append at the end

The existing note stays exactly as it is; this is a **second dated append**, same device.

```yaml
# ---- CITATION CORRECTION appended 2026-10-07 by orchestrator-main. APPEND-ONLY: no line above
# this comment is altered. The scope note above stands; only a citation inside it is corrected.
# -------------------------------------------------------------------------------------------
#
# The scope note above says "WHY THIS OBJECT IS NOT INTERNALLY CONSISTENT. :116-119 already
# contains the CORRECT reasoning". THAT POINTER IS WRONG. :116-119 is the tail of the "Where the
# guarantee lives" assessment ("unavailability lands directly on the fail-open/fail-closed question
# in 7b1bc8b7-...") plus the head of the "Insider/backup exposure" dimension. It contains no
# same-uid text.
#
# THE CORRECT CITATIONS ARE:
#   :159-160  inside OPTION_A's `implications` -
#             "...a stolen volume, a backup or a `docker cp` yields the key in cleartext, and
#              permissions do not defend against a same-uid process - which is the git transport."
#   :96-97    an INDEPENDENT, second statement of the same property, recorded as a quantitative
#             metric rather than as prose -
#             metric "A1 filesystem-only protection against a same-uid process",
#             value "none - the git transport runs as the same uid that would read the file".
#             :96-97 is the stronger witness, because it is a stated measurement.
#
# THE SUBSTANCE OF THE NOTE IS UNCHANGED AND CORRECT. The object does contain the correct same-uid
# reasoning, so it is internally inconsistent with its own "SHIP IT never holds key bytes" absolute,
# and the reconciliation in the note above stands. Only the pointer was wrong.
#
# Why this is recorded rather than quietly fixed: ADR 0018 argues (Amendments A2 -> "never holds
# key bytes") that a wrong absolute is worse than an absent one, "because a reader who trusts it
# will not look for the real exposure". A pointer 43 lines off the quoted text produces exactly
# that behaviour - and a decision object is where a reader is most likely to land, because this
# file is the citable id.
#
# Read with: the dated scope note above (absolute scoping), this correction (pointer), and
# docs/adr/0018-per-product-git-credentials.md sections "Amendments A2", "Accepted risks" and
# "Known gaps" (Design Revision 5, superseding Revision 4).
```

### 11.2 `.decisions/876c6b97-3e23-459d-aa9d-3a5faeb33702.yaml` — append at the end

```yaml
# ---- SCOPE NOTE appended 2026-10-07 by orchestrator-main. APPEND-ONLY: no line above this
# comment is altered. The resolution above stands, is NOT withdrawn, and no clause of the owner's
# answer is re-opened. -----------------------------------------------------------------------
#
# A SECOND FALSE STANDING CLAIM, in resolution.rationale at :122-123:
#
#   "`reviewed_by` and `reviewed_at` remain `null` because independent design review of the
#    amendment has still never happened."
#
# That was true when written and is FALSE NOW, in the same shape as the :20 absolute the scope
# note above already corrects: a fact with a shelf life recorded as a standing claim. Independent
# design review of amendment A2 has happened, twice -
#   - docs/engineering/dispatch/tasks/design-review-adr-0018-a2-rev3/report.md
#     RESULT: DESIGN_REVIEW_CHANGES_REQUIRED, REVIEWED_HEAD: 289f1d3
#   - docs/engineering/dispatch/tasks/design-rereview-adr-0018-a2-rev4/report.md
#     RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
# The human-recorded rationale is NOT edited; this note supersedes its wording only.
#
# WHAT IS TRUE, and is the durable form: `reviewed_by` remains `null` because NO REVIEWER HAS
# APPROVED ANY REVISION OF A2. "Never reviewed" and "reviewed but not approved" are the same
# operational state for anything deciding whether to trust the prose; the field fills when someone
# approves.
#
# ALSO NOW STALE AT :54-55 (cited as :53-55 elsewhere): the "Four gaps the amendment recorded as
# open" metric. Four gaps were accepted; the repository owner RETIRED A1 on 2026-10-07 after being
# shown that 08c7590 made the mint insert-only on both tiers. THREE are now recorded (A2, A3, A4).
# The owner's answer - "Accept A2, record the gaps as accepted" - is not withdrawn or re-opened, and
# nothing is added. Also: the OTHER half of the revocation clause - no code destroys a
# secret-manager handle - remains unimplemented, so revocation is still one-sided in practice.
# That half was never an accepted risk and retiring A1 did not accept it.
#
# Read with: the scope note above, this note, and ADR 0018 sections "Accepted risks" and
# "Known gaps" (Design Revision 5).
```

### 11.3 `design-revision-4.md` — OPTIONAL footnote; I declined to write it

Revision 4 is on `main` at `1c3f5ad`, is a reviewed artifact, and the no-silent-rewrite device has
survived four passes here. **I did not edit it, and I did not edit `design-revision-metadata-4.yaml`.**
Both contain the wrong pointer and both are retained as history; § 2.5 and § 2.2 record the defect in
revision 5, which is the device this work item uses. If you would rather have the correction in place:

```markdown
> **[Appended 2026-10-07 by Design Revision 5. The text below is retained unaltered; this note
> corrects two citations inside it. § 11.1 above prescribed the same wrong pointer into
> `.decisions/9417f8bf`, where a second dated append corrects it. The pointer `9417f8bf:116-119`
> is wrong: the quoted same-uid reasoning is at `:159-160`, with an independent second statement
> at `:96-97`. And `:194-201` in § 1.4's decline row is OPTION_D's description, not the same-uid
> source.]**
```

### 11.4 `design-revision-metadata-4.yaml:333` — OPTIONAL; retained as history

It records `docs/engineering/WORK_STATE.md:326-327` as holding *"amendment A2 is drafted and awaiting
independent review, and the human has accepted it with four gaps recorded as accepted."* **That file
does not contain that sentence at any of its fifteen revisions.** Same class as ADR `:1176`. Left
unaltered as revision 4's metadata; the correction is in the ADR at §Related → "The acceptance itself".

---

## 12. Handover

**Ready for focused independent review.** `reviewed_by` and `reviewed_at` are `null`; `status` is
`DRAFT`. This lane has not approved its own work and cannot. **A full re-run of revision 4's W1–W6 is
not needed** — the re-reviewer already did that and confirmed eleven with no twelfth; revision 5 did
not change any claim's wording on those axes.

**A reviewer should check, in this order:**

1. **The count in § 2.2 — nine distinct, fourteen sites.** Run the extraction script and adjudicate
   rows 5–9, which nobody had reported. If a tenth exists, this sweep is incomplete, which is the
   failure mode that produced this revision.
2. **The four `:NNN` anchors I re-anchored *in my own edits*** — `:65-68`, `:188-190`, `:284`/`:289`,
   `:488-494`. I broke them once during this very pass. Confirm they are right **in the final
   1212-line file**, not in the file as I found it.
3. **The A1 retirement (§ 4).** That three remain, that A2–A4 are untouched, that the second half of
   the revocation clause is recorded as still open, and that the retirement is attributed to the owner
   rather than to this lane.
4. **§ 11.1 and § 11.2** — that they are append-only, that neither edits a resolution rationale, and
   that § 11.1's pointer correction is the one the applied `9417f8bf` note needs.
5. **The decision to leave `design-revision-4.md` unedited** (§ 11.3). This is the judgement most worth
   challenging in this revision.

**Known not-done, so absence is not read as completion:** the `.decisions/**` notes (§ 11, Manager);
an owner for the same-uid exposure; F-19 and F-10 (both production source); A3 reachability (runtime
probe, `UNVERIFIED`); the mobile copy at `add_product_page.dart:542`/`:1038` (mobile lane);
independent review of revision 5.