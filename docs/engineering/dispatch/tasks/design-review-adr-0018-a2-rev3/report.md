# Subtask Report — design-review-adr-0018-a2-rev3

**FIRST independent review of ADR 0018 amendment A2 revision 3.** The review that produced the two
HIGH findings this revision answers is LOST; there was no baseline to check against. Persisted to disk
before returning, per the dispatch.

## Mandatory header

```yaml
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
TASK_ID: design-review-adr-0018-a2-rev3
TASK_TYPE: design-review
FEATURE: ADR 0018 amendment A2, revision 3 (ADR0018-A2-REV3) — make the ADR's tense honest
WORKTREE: /Users/alkebut/air/shipit-platform (canonical) reviewing /private/tmp/shipit-design-adr0018 (artifact)
BRANCH: design/adr-0018-amendment @ 289f1d3
BASE_SHA: 289f1d3
HEAD_SHA: 289f1d3  (worktree — the ADR amendment is UNCOMMITTED; canonical checkout is main @ 08c7590)
COMMITTED: NO
REVIEWED_HEAD: 289f1d3
REVISION_ID: ADR0018-A2-REV3
```

## Provenance — independently verified, not taken on trust

| Claim | Verification | Result |
|---|---|---|
| Worktree branch/HEAD `design/adr-0018-amendment` @ `289f1d3` | `git rev-parse` in `/private/tmp/shipit-design-adr0018` | **confirmed** |
| Canonical checkout `main` @ `08c7590` | `git rev-parse` | **confirmed** (matches dispatch `VALIDATION_COMMANDS`) |
| ADR is **811 lines** in the worktree, **580 on `main`** | `wc -l`; `git show main:…\| wc -l` | **confirmed exactly** |
| ADR amendment is uncommitted | `git status --short` → ` M docs/adr/0018-per-product-git-credentials.md` | **confirmed** |
| **main does not yet contain the amendment** | `git show main:docs/adr/0018-per-product-git-credentials.md` = 580 lines; 811 exists only in the worktree | **confirmed — recorded as required** |
| Stash **retained**, not dropped | `git stash list` → `stash@{0}: … do not drop blindly` | **confirmed. I did not touch it.** |
| Local edit was **byte-identical to main's** | `git show stash@{0}:…\| shasum -a 256` = `9e5b4772…`; `git show 289f1d3:…` = `9e5b4772…`; base `43d328b` = `a0999004…` | **confirmed exactly. Both claims true.** |
| G-17: `876c6b97` added in `5436a4d` | `git log --diff-filter=A -- .decisions/876c6b97*` → `5436a4d`, 2026-10-06 22:11:24 -0400 | **confirmed** |
| G-17: `5436a4d` is the commit that wrote the denial (158→580) | `git log -- docs/adr/0018-…`; line counts 158/580/580 | **confirmed. Same commit. The lane's argument holds.** |
| 13 decision objects at `43d328b`, 14 at `289f1d3` | `git ls-tree --name-only … .decisions/ \| grep -c yaml` | **confirmed (13 / 14)** |
| Revisions 1 and 2 untouched | `git diff 289f1d3 -- design-revision{,-metadata,-2,-metadata-2}.*` | **empty — confirmed** |
| `.decisions/**` untouched | `git status --short .decisions/` | **empty — confirmed** |
| Manager's `6220951` for the A2 revision is **wrong** | `git show --stat 6220951` = `AGENTS.md` only, 0 files matching `0018` | **confirmed wrong**; `5436a4d` is correct, `876c6b97` is a decision id. **The Manager's self-correction is itself correct.** |
| All nine named decisions exist and are `RESOLVED` | `9417f8bf 898b07d0 79e860e2 ae1c1f79 7b1bc8b7 4d2c6b81 27ea6536 b869ec24 876c6b97` | **all 9 confirmed** |
| `0bf2fa0`, `e391c02`, `43d328b`, `5436a4d`, `289f1d3` are commits | `git log -n1` each | **confirmed** |
| **`570bb640`** — cited by the ADR as if a commit | `git log 570bb640` → *unknown revision*; it is `.decisions/570bb640-76e1-485d-9a80-309b07585ccd.yaml` (DEPLOYMENT_AUTHORITY) | **it is a DECISION ID. See M-3.** |

**Dispatch provenance claims otherwise checked and all sound**: the 811/580 divergence, the base
`289f1d3`, the nine resolved decisions, the `5436a4d` correction, and the stash label.

---

## What I verified in the ADR's own evidence — every `file:line` reference, independently

I checked each claim rather than accepting it. **All of the producing lane's evidence citations are
accurate to the exact line.** That is a real quality result and I record it as such.

| ADR claim | Verified |
|---|---|
| `modules/secrets/main.tf:23,31,39` = the three `google_secret_manager_secret` resources | **exact** — lines 23, 31, 39 |
| `modules/iam/main.tf:31-34` = `roles/secretmanager.secretAccessor` → Cloud Run SA | **exact** — 31–34, `member = "serviceAccount:${var.cloudrun_sa}"` |
| `modules/cloudsql/main.tf:77-89` = `db_password` secret + managed version | **exact** |
| `main/main.tf:82-87` instantiates the module | **exact** — `module "secrets"` at :82 |
| **no deploy-key secret anywhere in `infrastructure/`** | **confirmed** (negative half holds) |
| no secret-manager adapter/resolver/endpoint in `apps/server/lib`, `packages/*/lib` | **confirmed** — no match, every family |
| `git_workspace_inspector.dart:107` runs `Process.run(git, args)` with no `environment:` | **exact** |
| no `SSH_AUTH_SOCK\|known_hosts\|ssh-keyscan\|StrictHostKeyChecking\|IdentityFile` anywhere | **confirmed absent** |
| no `custodyMode\|secretStrategy\|substrate` anywhere | **confirmed absent** |
| `product.dart:26` — `ProductState.registered` is the default | **exact** |
| `repository_credential_view.dart:145` and `:166` emit `referenceName`; client mirror `:144` | **exact, all three** |
| `schema_bootstrap.sql:98-100`, `migration.sql:53-55` = partial unique index `WHERE status <> 'revoked'` | **exact, both** |
| `postgres_product_registry_store.dart:322-331` = predicating `ON CONFLICT … DO UPDATE … WHERE` | **exact** |
| V-3: no un-scoped "never holds key bytes" assertion remains | **confirmed by my own grep** |
| V-4: the denial survives only inside the quoted correction block | **confirmed** |

**F-2 is TRUE and it is the most valuable thing in this revision.** A GCP Secret Manager is already
provisioned in this repository's own Terraform with `secretAccessor` already granted to the identity
SHIP IT would run as — and revision 2's `*.dart`-only evidence could not see it. A lane found this by
looking outside its own declared search space. It genuinely narrows gap A4.

---

## Judgement on the two fixes — both sound, and both verified independently

**HIGH 1 is genuinely fixed.** The three-part scoping (never **stored** = the guarantee / materialised
transiently at transport time = true but not a guarantee / the same-uid consequence) cuts on the right
dimension. I checked the claim *"This correction weakens no clause"* (ADR `:137`): the prohibitions at
`:102-105` are unchanged and still exclude the envelope-encrypted-table substrate, so nothing was
weakened. The consequence is stated accurately and **not overstated**.

**HIGH 2 is genuinely fixed.** §Decision status is **accurate in all nine rows** on my independent
check, including the two **partly built** ones — `product.dart:26` confirms `registered` is still the
default, so F-7 holds. The idiom was genuinely reused, not invented: `:373` is the ADR's own
pre-existing *"Requirement, not yet enforced at the transport"*, and the new sections follow it. That
was the right call.

**G-17's factual core is verified and its conclusion is correct:** revision 2 did not fabricate; its
verification was sound at `43d328b`; the object landed in the same commit that published the denial.
**But I disagree with the framing — see "Judgement on G-17's framing" below.**

---

## BLOCKERS

### B-1 — §Decision's normative headline still asserts the scope A1 superseded, unmarked and unlisted

`docs/adr/0018-per-product-git-credentials.md:272-273`, the first two lines of the **Decision** section:

> **Each product owns its own SSH keypair. Git credentials are scoped per product,
> not per platform.**

This is:

- **The exact wording A1 superseded.** §Amendments `:44`: *"Credential scope: one keypair per product
  → **one keypair per repository**"*; `:51-53`: *"**Current:** one `ed25519` keypair **per repository**."*
- **Not marked.** `:37-40` states the convention — *"Superseded wording is retained in-place and marked
  **SUPERSEDED (A1)**"*. Four clauses honour it (`:321`, `:403`, `:438`, `:326`). This one does not.
- **Not in §Known gaps**, whose entire job is catching exactly this. `:739` flags *rotation* and misses
  the headline.
- **Contradicted 14 lines later by the table revision 3 itself added.** `:286`: *"One `ed25519` keypair
  **per repository** (A1 scope) | yes | **yes**"*.
- **Contradicted by the code it cites as authority.** `repository_credential.dart:20-22`: *"## Scope is
  one repository, not one product / ADR 0018 originally said one keypair per **product**."*
- **Stale by the ADR's own strongest statement.** §Amendments `:44`: a per-product key *"is therefore
  not installable for a multi-repo product"*. The Decision section still says per product.

**Why this blocks.** It is the same species of defect as HIGH 1 — a normative claim contradicted by the
ADR's own nearby clause — but it sits in the **normative section**, in the most prominent position in
the document, and it was **not introduced by revision 3 but was left visible by it**: the device added
to fix HIGH 2 now disagrees with the sentence it was added next to. An ADR read years later by someone
who reads §Decision gets the wrong credential scope, which determines how many keys a customer installs
and the blast radius of a leak. It is a two-line fix inside the producing lane's `OWNED_PATH`.

**Fix:** strike `:272-273` and mark **SUPERSEDED (A1)**, naming §Amendments A1 — as `:321` and `:403`
already do — and state per-repository scope as current. Add a §Known gaps entry if the convention
prefers the note device; do not leave it unmarked either way.

---

## HIGH

### H-1 — §Decision status row 2 marks a custody clause "Built: yes" citing evidence that asserts the SUPERSEDED custody model

ADR `:287` marks *"Private half **never displayed, logged, persisted to the durable record, or
transmitted** | yes | **yes**"* citing `repository_credential.dart:12-18`, `:70-72`.

Those exact ranges say:

```
:12-18  /// ## This type never holds key material
        /// There is no private-key field, and there never may be. The private half is
        /// written to the operator's local secret store and is referenced only by
        /// [referenceName] …
:70-72  /// Name under which the private half is held in the local secret store,
        /// e.g. `GIT_PRODUCT_<productRef>_SSH`. Never the value itself.
```

**Both cited ranges assert the A1 custody model that A2 superseded.** The row's *claim* is correct —
there is no key-material field — but the pointer sends a reader to code comments saying custody is
**the operator's local secret store**. In an ADR whose subject *is* custody, marking a custody clause
`Built: yes` on evidence that names the wrong custodian is a defect in the class revision 3 exists to
remove. Note the symmetry: the code comment is **right about scope (A1)** and **stale about custody
(A2)**; the ADR's Decision headline (B-1) is **stale about scope (A1)** and **right about custody
(A2)**. Each is authoritative where the other is wrong.

**Fix:** cite the field declarations (`repository_credential.dart:12-18`'s "no private-key field",
`:72` `final String referenceName`) and either add a line recording that the cited doc comments are
stale-by-A2, or raise the doc-comment staleness as an implementation follow-up. Do not leave a
`Built: yes` resting on superseded-custody prose.

### H-2 — the rotation clauses are stale-by-A1, unmarked, and one of them is listed as a *benefit*

ADR `:384` (*"**Rotation is per product.** Rotating a key affects exactly one product"*) and `:401`
(*"Rotation blast radius is one product, not the fleet."*).

- Both are **superseded by A1** and **neither is struck through nor marked SUPERSEDED**, unlike
  `:321`/`:403`/`:438`.
- Both **contradict the same document**: `:219` says *"rotation scoped to one repository"*; §Negative
  `:434-436` says *"Per-repository scoping (A1) means key count grows with repository count, not
  product count"*.
- `:401` is worse than a stale clause: it is in **§Consequences → Positive**, so the superseded scope
  is presented as an argument *in favour of the design*.
- The substance is not cosmetic. Credential count and rotation blast radius are the operator-visible
  consequence of A1: a product with five repositories needs five keys, not one.

The producing lane recorded this as **G-e** — *"a documentation reconciliation with no security
consequence … out of this task's scope"* (§6, report item 6). **I judge that wrong on two grounds.**
First, it is not out of scope: it is inside the producing lane's `OWNED_PATH`, and the ADR already has
the exact device for it at `:37-40` plus four worked examples. Declaring a one-line application of the
document's own stated convention "out of scope" is a scope decision the lane made for itself. Second,
"no security consequence" is not the test the document sets — the test at `:37-40` is whether the
reader can tell current text from superseded text.

**Fix:** apply the `:37-40` convention at `:384` and `:401` — strike, mark **SUPERSEDED (A1)**, state
per-repository rotation, and correct the §Positive bullet's substance. Then remove or restate the G-e
entry, since it would no longer be open.

### H-3 — the ADR cites both governing decisions as authority **without warning that they carry the absolute it just corrected**

This is the in-scope half of F-1, and F-1's own framing is incomplete (below).

Revision 3 cites `9417f8bf` at §Amendments A2's table row `:45` and §Related `:767`, and `876c6b97` at
`:773-775` and throughout §Status — **with no note that both objects carry the pre-correction absolute
the ADR now declares false.** ADR `:137-139` argues that *"a false absolute is more dangerous than an
absent one, because a reader who trusts it will not look for the real exposure."* Applied consistently
— which is the standard revision 3 sets for itself — that argument forbids sending a reader to a
contradicting citation unannounced. The ADR's own scoping device (`:107-139`) makes this a small edit.

**Fix:** add a dated, attributed scope note in §Related → "Decisions governing amendment A2" (and/or
the §Amendments A2 table row) recording that the two cited objects carry the pre-correction absolute,
that the ADR's scoped reading governs, and that the objects are Manager-owned. Do **not** rewrite the
ADR's citations to imply the objects say otherwise.

**F-1's scope is understated — this part is upstream, but the scope matters.** The lane reported
`9417f8bf:210-211` and `876c6b97:20-21`. Those citations are correct. But the same absolute appears at
**`9417f8bf:113`** (*"A3 is literally the existing contract — SHIP IT **never touches key bytes**"*),
**`9417f8bf:140`** (*"the only option under which SHIP IT **never holds key bytes at all**"*) and
**`876c6b97:20`** — so **four substantive sites across two objects, not two.** `:140` is the
load-bearing one: it is the sentence justifying A3 as the *only* option satisfying the property, i.e.
the uniqueness argument the human actually read when choosing. A Manager who fixes "two lines" leaves
the uniqueness argument standing on a false premise. The uniqueness argument does survive at rest
(A1 and A2 both store bytes at rest), but the sentence as written is false and is what H-1's root
looks like in the record.

**What should happen, though it is outside this lane's scope:** append a **dated, attributed scope
note** to `9417f8bf` and `876c6b97`; do **not** rewrite the resolution rationale. Three reasons.
(i) The rationale is the human's own recorded answer, and the ADR's `:37-40` convention forbids silent
rewrite. (ii) `LEARNING_POLICY.md:261` prescribes exactly this for `CONTRADICTION`: *"surface and
reconcile — do not silently overwrite."* (iii) It is the same device revision 3 used on the ADR
itself, so it is consistent, non-destructive, and keeps the audit trail. It is Manager/human authority
(`.decisions/**`, `created_by: orchestrator-main`) and the lane was right to route rather than write —
**the refusal was correct; stopping there was not.**

---

## MEDIUM

- **M-1 — §Decision status does not cover every clause it appears to.** `:281` says *"Every clause below
  is therefore marked."* §Decision → Specifics has nine bullets; the table has nine rows; they do not
  map one-to-one. Two normative bullets have **no row**: *"The public half is surfaced in the UI"* /
  *"No secret value is ever typed into ShipIt"* (`:362-364`), and rotation (`:384-385`). A reader
  checking whether the UI clause is built finds nothing and may infer it is built. Either add rows or
  narrow the sentence to the clauses the table covers.

- **M-2 — the transport-time same-uid exposure is filed under an `ACCEPTED` header and absent from
  §Known gaps.** ADR `:717-722` places it as *"A second consequence this revision records, without
  widening the accepted gap"* **inside §Accepted risks A4, whose header reads `ACCEPTED`**. The bullet
  is honest — it says explicitly it is not a fifth accepted gap and that four remain four — but its
  position is under an ACCEPTED entry, and §Known gaps — declared *"Remaining items"* at `:726` — does
  not list it. §Amendments A2 `:107-139` is the right primary home and it is thorough, so the item is
  durably recorded; the gap is that a reader scanning for **open** items finds nothing security-related.
  Add a §Known gaps entry marked as not one of the four accepted risks.

  **On the lane's decision not to self-assign: the right call, for a reason it gave only partly.** It
  was right not to create a fifth accepted risk — that would misstate what the owner was asked and
  answered, which is precisely the defect class this revision exists to fix. But §Known gaps is the
  document's own home for *"not an accepted risk, needs follow-up"*, it is inside `OWNED_PATH`, and
  filing it there needs no owner authority. Surfacing without filing is half the available remedy.

- **M-3 — `570bb640` is cited as if it were a commit; it is a decision id.** ADR `:567` (*§Preconditions*)
  and `:772` (*§Related*) cite `570bb640` bare, in the same form as genuine commit SHAs (`e391c02`,
  `0bf2fa0`, `43d328b`, `5436a4d`). `git log 570bb640` → *unknown revision*; it is
  `.decisions/570bb640-76e1-485d-9a80-309b07585ccd.yaml` (`DEPLOYMENT_AUTHORITY`, `RESOLVED`). I hit
  this while verifying, and so would any reader. This is **exactly the ambiguity F-6 corrected for
  `876c6b97`** — and G-17's whole argument was a commit-ordering argument that the wrong SHA would have
  made unverifiable. The same standard applies here: mark it as a decision id (and give its type, as
  the other §Related entries do at `:765-771`).

- **M-4 — landing hazard on accepted risk A1.** ADR `:639-641` records A1's fix as *"not merged into
  `main` as of `43d328b`"*, and `:641` correctly time-indexes it. **That is true at the reviewed
  revision.** But the canonical `main` is now **`08c7590`**, which merges
  `fix/credential-identity-invariants`, and `recordGeneratedCredential` there documents: *"A mint is
  insert-only: supplying an id that already exists is refused by the store and changes nothing — whether
  the supplied material differs, matches, or the existing credential is revoked."* So **A1's substance
  is closed on the `main` this artifact will land on.** `:288` (*"Immutability … yes (as of `e391c02`)"*)
  is in the same position. This is **not** a defect at `289f1d3` and I record it as such — it is a
  re-verification obligation at commit/rebase time, or the shipped ADR will be stale-wrong inside the
  same merge. Given that G-17's entire subject is a shelf-lived fact, holding the artifact to the same
  standard is consistent.

---

## LOW

- **L-1 — pre- and post-revision line numbers sit in adjacent tables with no marker.**
  `design-revision-3.md` §1.1 (`:150-152`) cites **post**-revision ADR lines (`:45`, `:141-149`,
  `:346-348`, `:459-470`, `:181-186`), while §2's ledger immediately below cites **pre**-revision lines
  (H1-e `:123` for text now at `:186`). §2's column header does say *"(pre-revision)"*; §1.1's does not
  say *"(post-revision)"*. A reader cross-checking `:181-186` against `:123` has no way to know they are
  different numbering bases.
- **L-2 — risk rationale leans on a non-causal claim.** `design-revision-3.md` §5 item 5 and the
  metadata's `risk_rationale` item 5 justify holding Level 3 partly because *"this revision newly
  discloses a security consequence … Stating it plainly is the reason the risk level does not fall."* A
  disclosure neither raises nor holds a risk level; the level is set by the change being recorded. The
  conclusion (3) is right — see below — but the stated reason is not load-bearing and should not be.

---

## Independent risk assessment

**INDEPENDENT_RISK_LEVEL: 3 — RISK_LEVEL_AGREEMENT: YES.**

`DESIGN_GOVERNANCE.md:99` defines Level 3 as *"Change to core workflow, navigation structure, or
information architecture affecting multiple features or user mental models."* The amendment moves the
credential custody model on a security boundary, gives revocation a ShipIt-side action the ADR
previously said was unnecessary, and introduces a runtime dependency that can block the credential path
— and it spans product registry, worker runtime, control-plane and mobile surfaces. Level 2 (*"Change
to user flow, interaction pattern, or feature-level UX"*) would understate it. Level 3 is correct.

I **agree** with the lane's reasoning that the level describes the recorded change, not the accuracy of
the prose or whether a human blessed it — that is the right principle and it is why a precision
correction does not lower the level. I record one disagreement: rationale item 5's causal claim (L-2).

---

## Judgement on G-17's framing — I disagree with it, and this is why the sweep found what it found

The lane concluded: *"revision 2's verification was SOUND at the time … the defect was writing a fact
with a shelf life as a standing claim."*

**The factual conclusion is correct and I verified it.** The framing is too narrow in two ways, and the
second is why B-1, H-1 and H-2 exist.

**1. The claim was not merely time-indexed — it was prescriptive.** §Status `:20-21` did not just say
*"none exists yet"*; it recommended that **the Manager create a decision object** citing `ae1c1f79:8-11`.
A prescription instructs whoever reads the ADR *later*, so it has no shelf life the way a fact does — and
it was actively harmful to a future reader, who would have created a **duplicate** decision object for an
acceptance that already had one. This is not hypothetical: it materialised **in the same commit**, which
is what `876c6b97:8-12` exists to record — *"a sibling design artifact was able to assert an 'Accepted by
the human' amendment that nothing on disk supported."* G-17 was never a lapsed fact. It was a
**prescription that a future actor would have obeyed wrongly.**

**2. The defect is not a one-off; it is a class, and G-17 is the third instance of it.** The ADR's
convention at `:37-40` requires every superseded clause to carry a marker. G-17 was superseded text with
no marker. **So are B-1** (per-product scope, unmarked) **and H-2** (per-product rotation, unmarked,
one of them presented as a benefit). Revision 3 fixed G-17's instance properly. It did not sweep the
class — and adopting the lane's framing ("the defect was the tense") licenses exactly the outcome the
dispatch warned about: two sentences repaired, the stale-and-unmarked normatives left standing.

**The correct generalisation for the next pass:** ADR 0018's defect is **systemic stale-but-unmarked
normative text**, and the repair is a sweep of every normative claim against the amendment ledger, not a
repair of individually-reported findings. B-1, H-1 and H-2 are what that sweep finds. I would rather say
that than approve a document that has been corrected at three points and is wrong at four.

---

## What I did NOT review — stated explicitly

- **The LOST `CHANGES_REQUIRED` review of revision 2.** It does not exist on disk. I have no baseline.
  My finding set is derived from the ADR text, the nine decisions, and the Manager's summary. **If that
  report surfaces with findings beyond HIGH 1, HIGH 2 and G-17, they are unaddressed** (the lane's own
  G-d, which I endorse).
- **Runtime behaviour of anything.** No Docker or Compose command was issued by me — not `info`, not
  `ps`, not `logs`, not `config`, not any mutating one. A3 reachability (G-c) therefore remains
  **UNVERIFIED** and I make no claim about it. No git transport was exercised.
- **Revisions 1 and 2 as artifacts** — verified only that they are byte-untouched, not that their content
  was right. Their retained false denial (C-1) I accept as correct history.
- **Design-system compliance and UX/accessibility as gates** — both `PASS (not applicable)`, and I agree:
  this revision authors no UI. I did **not** review the mobile copy at `add_product_page.dart:542`/`:1038`
  (the lane states it did not re-verify it; `apps/control_plane/**` was outside its scope and is outside
  mine). The copy constraint is correctly *recorded*; whether that text has since been fixed is unverified.
- **Production code correctness.** I read the cited lines to check that the ADR's *citations* are accurate.
  I did not review the credential implementation for defects.
- **The other nine ADRs** beyond confirming `docs/adr/` holds 21 ADRs `0001`–`0021` and
  `docs/engineering/adr/` holds only three framework-distribution ADRs (the path trap that made ADR 0018
  get declared non-existent). I verified `docs/adr/0018-per-product-git-credentials.md` exists before
  trusting any UNCHANGED result.
- **The `fix/credential-identity-invariants` review** whose `APPROVE_WITH_NON_BLOCKING_FOLLOWUP` verdict
  is still untracked on disk (per the dispatch). Out of scope here; its absence is a real blocker for
  *that* work item, not this one.
- **Integration, QA, deployment.** No gate beyond design review was assessed.

---

## Structured result

```
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED

REVIEWED_HEAD: 289f1d3 (worktree design/adr-0018-amendment, ADR amendment UNCOMMITTED, 811 lines).
                Canonical main is 08c7590 and does NOT contain the amendment — its ADR is 580 lines.

REVISION_ID: ADR0018-A2-REV3

BLOCKERS:
  B-1 — ADR :272-273, the §Decision headline, still reads "Each product owns its own SSH keypair.
        Git credentials are scoped per product, not per platform" — the exact scope A1 superseded.
        Unmarked, contrary to the ADR's own convention at :37-40 that four other clauses honour; absent
        from §Known gaps; and contradicted 14 lines later by the §Decision status row revision 3 itself
        added (:286, "per repository"). §Amendments :44 records that per-product scoping is not even
        installable for a multi-repo product. Strike and mark SUPERSEDED (A1), as :321 and :403 do.

HIGH:
  H-1 — §Decision status :287 marks the custody clause "Built: yes" citing repository_credential.dart
        :12-18 and :70-72, and BOTH ranges assert the superseded A1 custody model ("written to the
        operator's local secret store" / "held in the local secret store"). Cite the field declarations
        and record the doc comments as stale-by-A2.
  H-2 — :384 ("Rotation is per product") and :401 ("Rotation blast radius is one product, not the
        fleet") are superseded by A1, unmarked, and contradicted by :219 and §Negative :434-436; :401
        presents the superseded scope as a BENEFIT in §Positive. The lane declined these as G-e
        ("no security consequence, out of scope") — I judge that wrong: they sit in OWNED_PATH and the
        ADR supplies the exact device. Apply the :37-40 convention; then close the G-e entry.
  H-3 — The ADR cites 9417f8bf (:45, :767) and 876c6b97 (:773-775) as authority with no note that both
        carry the absolute it just corrected — which ADR :137-139 itself calls more dangerous than an
        absent one. Add a dated scope note to §Related → "Decisions governing amendment A2". F-1's scope
        is also understated: FOUR substantive sites, not two — 9417f8bf:113, :140 (the load-bearing
        uniqueness argument) and :210, plus 876c6b97:20.

MEDIUM:
  M-1 — §Decision status :281 claims "Every clause below is therefore marked", but two normative
        §Decision → Specifics bullets have no row: the public-half/UI clause (:362-364) and rotation
        (:384-385). Add rows or narrow the sentence.
  M-2 — The transport-time same-uid exposure sits inside §Accepted risks A4 under an "ACCEPTED" header
        (:717-722) and is absent from §Known gaps. Right not to self-assign as a fifth accepted risk;
        incomplete to leave it with no §Known gaps entry, which is the document's own home for
        "not an accepted risk, needs follow-up".
  M-3 — 570bb640 (ADR :567, :772) is cited as if a commit; it is a decision object
        (.decisions/570bb640-…yaml, DEPLOYMENT_AUTHORITY). `git log 570bb640` fails. Mark it as a
        decision id — the same ambiguity F-6 fixed for 876c6b97.
  M-4 — Landing hazard, not a defect at 289f1d3: accepted risk A1's fix is now merged into canonical
        main (08c7590 = merge of fix/credential-identity-invariants) and recordGeneratedCredential there
        refuses any mint onto an existing credentialId. Re-verify A1 and the "as of e391c02" rows at
        commit/rebase time.

LOW:
  L-1 — design-revision-3.md §1.1 cites post-revision ADR line numbers while §2's adjacent ledger cites
        pre-revision numbers, with no marker distinguishing the two bases.
  L-2 — Risk rationale item 5 holds Level 3 partly on the ground that the revision newly discloses a
        consequence; a disclosure neither raises nor holds a risk level. Conclusion unaffected.

INDEPENDENT_RISK_LEVEL: 3
RISK_LEVEL_AGREEMENT: YES

TRACEABILITY_GAPS:
  - The same-uid exposure is disclosed but owned by nothing: not one of the four accepted risks, so
    876c6b97:136-161's assignments do not reach it. G-b stands as the lane reported it — and my judgement
    is that surfacing was right and filing it under §Known gaps was available and was not done.
  - Two §Decision → Specifics clauses (:362-364, :384-385) have no entry in the Decided/Built table.
  - §Preconditions :567 and §Related :772 cite 570bb640 in a form that cannot be verified as a commit.
  - The lost revision-2 review: if it surfaces with findings beyond HIGH 1, HIGH 2 and G-17 they are
    unaddressed. No baseline existed for this review.

CORRECTION_REQUIRED: YES

HUMAN_DECISION_REQUIRED: NO
  Reasoning, so it can be challenged: I considered raising a gate over the newly disclosed
  transport-time same-uid exposure and concluded NO — on a sharper ground than the lane gave. The lane
  argued the exposure "existed in the accepted architecture from the moment A3 was chosen". True, but
  weak. The stronger point: **the exposure is substrate-independent.** SHIP IT pushes git itself, so it
  must materialise the private half in memory under A1, A2, A3 and A4 alike; it follows from
  b869ec24's server-side move, not from the custody choice. No option was displaced by it and no
  substrate avoids it, so nothing the human chose between is called into question and no new gate is
  warranted. Revision 3 changes wording, tense, scoping and evidence; no substrate, no revocation model,
  no accepted gap, no clause of the owner's answer, and no requirement on any implementer. Correct not to
  manufacture a gate. F-1 and G-b are routed upward, not decided here.

HUMAN_DECISION_TYPE: DESIGN

SAFE_PARALLEL_WORK:
  - design-reviewer lanes for the keys and mobile rev-5 items — no path overlap with docs/adr/0018 or
    this report directory.
  - Any lane owning add_product_page.dart:542/:1038 copy — but read ADR :107-139 first: under A3 no
    operator-facing copy may claim SHIP IT "never holds" the key or that it "stays in the keychain".
  - Read-only research on the 570bb640 citation and on repository_credential.dart's stale A1 doc comments.
PROHIBITED_PARALLEL_WORK:
  - Any lane writing docs/adr/0018-per-product-git-credentials.md — B-1, H-1, H-2 and H-3 are all inside
    the producing lane's OWNED_PATH. Serialise the correction.
  - Any lane amending 9417f8bf or 876c6b97 — .decisions/** is Manager-owned; F-1 must be routed first,
    and the remedy is an appended scope note, never a rewrite of the rationale.
  - Anything that drops stash@{0} — it remains evidence; its content is proven present on 289f1d3
    (sha256 9e5b4772…), so dropping it is safe ONLY as a deliberate, recorded act, never as cleanup.
```

---

## Judgements the dispatch asked for, in one place

**G-17's framing — NOT acceptable as stated.** The factual conclusion is right and I verified it. The
framing is too narrow twice over: the claim was *prescriptive* (it told a future actor to create a
decision object that already existed — harm realised in the same commit), and the defect is a **class**,
not an instance — stale normative text with no `SUPERSEDED` marker, of which G-17 is one and B-1, H-1
and H-2 are three more. Adopting "the defect was the tense" unchanged would license precisely the
two-sentences-fixed outcome the dispatch warned against. The repair is a **sweep of every normative
claim against the amendment ledger**.

**F-1 — the propagation upward is not acceptable, but the remedy is an appended scope note, not a
rewrite, and one half of it is inside this lane's scope.** The lane's refusal to write Manager-owned
decision files was **correct**. Stopping there was not: the ADR must not cite `9417f8bf` and `876c6b97`
as authority while they carry the absolute it just declared false (H-3). Upstream, append a dated,
attributed scope note to both objects — `LEARNING_POLICY.md:261` (*"surface and reconcile — do not
silently overwrite"*) and the ADR's own `:37-40` both point there, and it is the same device revision 3
used on the ADR itself. Also: F-1's scope is **four sites, not two** (H-3).

**G-b — right to surface, incomplete as handled.** Creating a fifth accepted risk would have misstated
what the human was asked and answered, so not self-assigning that was correct. But §Known gaps is the
document's own home for "not an accepted risk, needs follow-up", it is inside `OWNED_PATH`, and filing
it there needs no owner authority (M-2). Surface *and* file.

**The lost review.** Three reports lost in one work item, and the `APPROVE_CORRECTIONS` verdict
authorising this morning's merge is still untracked. F-3's recommendation — persist review output to
disk **before** dispatching a correction — should be treated as part of the review lane's contract, not
a courtesy. This report is on disk before I return.

**What the producing lane got right, and it is a lot.** HIGH 1's scoping is correct, non-weakening and
accurately stated. HIGH 2's nine-row table is accurate in **all nine rows** on my independent check,
with two partly-built states correctly caught. G-17's git proof is exact. The GCP Secret Manager finding
(F-2) is verified line-for-line and is the most valuable thing in the revision — it was found by looking
outside the declared search scope, and it genuinely narrows a gap the owner accepted. Every `file:line`
citation I checked was right. The stash was preserved and not dropped, and its contents were proven
superseded before being set aside. `reviewed_by`/`reviewed_at` left `null` and status moved
`ACCEPTED → DRAFT` were the right calls. The lane declined to approve its own work and it was right to
report F-1 and G-b upward rather than absorb them.

The gap is narrow and specific: **it repaired the findings it was given and did not sweep the class they
belong to.** That is what an independent review is for.

## Files touched

```text
docs/engineering/dispatch/tasks/design-review-adr-0018-a2-rev3/report.md
```

That is the whole list — inside `OWNED_PATHS`. **Nothing else was modified.** I ran **no Docker or
Compose command of any kind**, read `docs/adr/**` read-only including ADR 0018, and issued **no
`stash`, `checkout`, `reset` or any other git-state mutation** in the worktree. `stash@{0}` was read
(`git stash show --stat`, `git show stash@{0}:…`) and is intact.

## Validation results

| Command | Status | Evidence / note |
|---|---|---|
| `git rev-parse --short HEAD` (canonical) | pass | `08c7590` — matches dispatch `VALIDATION_COMMANDS` |
| `git rev-parse` (worktree) | pass | `289f1d3`, branch `design/adr-0018-amendment` |
| `wc -l` ADR (worktree) / `git show main:…` | pass | 811 / 580 — divergence confirmed and recorded |
| `git status --short` (worktree) | pass | only the ADR modification + 3 untracked revision-3 artifacts |
| `git stash list` | pass | `stash@{0}` present with the expected label; **not dropped** |
| `shasum -a 256` stash blob vs `289f1d3` vs `43d328b` | pass | `9e5b4772…` / `9e5b4772…` / `a0999004…` — byte-identity claim proven |
| `git log --diff-filter=A -- .decisions/876c6b97*` | pass | `5436a4d`, 2026-10-06 22:11:24 -0400 |
| `git log -- docs/adr/0018-per-product-git-credentials.md` | pass | `5436a4d` (158→580) — same commit as the denial |
| `git ls-tree --name-only 43d328b/289f1d3 .decisions/ \| grep -c yaml` | pass | 13 / 14 |
| `git diff 289f1d3 -- design-revision{,-metadata,-2,-metadata-2}` | pass | empty — revisions 1 and 2 untouched |
| `git status --short .decisions/` | pass | empty — 14 objects unmodified |
| `git show --stat 6220951` | pass | `AGENTS.md` only; 0 files match `0018` — Manager's original SHA wrong, correction right |
| 9 settled decisions exist and are `RESOLVED` | pass | all 9 confirmed |
| Terraform: `secrets/main.tf`, `iam/main.tf`, `cloudsql/main.tf`, `main/main.tf`, `cloudbuild/main.tf` | pass | every cited line exact; **F-2 confirmed**; negative half confirmed |
| Absence sweeps: secret-manager, host-key transport, substrate-selection | pass | all confirmed absent |
| Citation spot-checks (`product.dart:26`, 3× `repository_credential_view.dart`, both index files, `postgres_…:322-331`, `git_workspace_inspector.dart:107`) | pass | all exact |
| `grep -n "no Human Decision object\|no citable decision id"` | pass | only inside the quoted correction block |
| `grep -n "never holds\|transport"` | pass | re-ran independently; every hit scoped, cross-referenced, or quoted history |
| `git log 570bb640` | **fail (ADR defect, not a command error)** | *unknown revision* — it is a decision object. Finding M-3. |
| A3 reachability runtime probe | **NOT_RUN** | Requires the probe outside this scope; would need Docker. **No probe is claimed.** |
| Docker / Compose — any command | **NOT_RUN** | Deliberately. None issued, not even read-only. |
| Lost revision-2 review | **NOT_RUN** | Does not exist on disk. No baseline; stated under Unresolved issues. |

## Evidence (revision-pinned)

```yaml
EVIDENCE_REVISION: 289f1d3   # the revision every ADR line number and citation refers to
BUILD_COMMAND: n/a — documentation / architecture record only
SERVE_OR_RUN_COMMAND: n/a — nothing built, served, or executed
ENVIRONMENT / BASE_URL: n/a
ARTIFACTS:
  - /private/tmp/shipit-design-adr0018/docs/adr/0018-per-product-git-credentials.md   (811 lines, UNCOMMITTED at 289f1d3)
  - /private/tmp/shipit-design-adr0018/docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-3.md
  - /private/tmp/shipit-design-adr0018/docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-metadata-3.yaml
  - /private/tmp/shipit-design-adr0018/docs/engineering/dispatch/tasks/design-adr-0018-amendment/report.md
  - .decisions/876c6b97-3e23-459d-aa9d-3a5faeb33702.yaml   (164 lines, read in full)
  - .decisions/9417f8bf-73b8-4827-9515-bdfe92e5a9d5.yaml   (239 lines, read in full)
  - stash@{0}  docs/adr/0018-per-product-git-credentials.md   (sha256 9e5b4772… — read, INTACT)
```

## Documentation updated

```text
docs/engineering/dispatch/tasks/design-review-adr-0018-a2-rev3/report.md
```

## Model and reasoning effort

```yaml
ROUTING_CLASS_REQUESTED: PRECISION
MODEL_USED: opencode/space-bunny-free
REASONING_EFFORT: n/a
ESCALATED_INSIDE_TASK: NO
ESCALATION_REASON: n/a
```

## Unresolved issues and blockers

- **B-1 blocks this artifact.** The §Decision normative headline states a scope A1 superseded and that
  §Amendments `:44` calls uninstallable. Four-line fix, inside the producing lane's `OWNED_PATH`.
- **F-1 needs the Manager, and possibly the human.** `9417f8bf:113`, `:140`, `:210` and `876c6b97:20`
  carry the absolute. **Recommend an appended dated scope note to both objects — never a rewrite of the
  resolution rationale** (`LEARNING_POLICY.md:261`; ADR `:37-40`). `.decisions/**` is Manager-owned.
  **H-3 is the part the correction lane can do itself.**
- **G-b needs routing.** The transport-time same-uid exposure has no owning follow-up. Substrate-
  independent (see `HUMAN_DECISION_REQUIRED` reasoning), so no new gate — but it needs an owner.
- **M-4 needs action at landing.** Re-verify accepted risk A1 and the `as of e391c02` rows against
  canonical `main` (`08c7590`) before this ADR is committed, or the shipped ADR will be stale-wrong
  inside the same merge.
- **The `APPROVE_CORRECTIONS` verdict for `fix/credential-identity-invariants` is still untracked on
  disk.** Out of scope here; it blocks *that* integration, not this review.
- **The lost revision-2 review** has no successor on disk. If it resurfaces with findings beyond HIGH 1,
  HIGH 2 and G-17, they are unaddressed and a further correction is needed.

## Safe parallelism

```yaml
SAFE_PARALLEL_WORK:
  - "design-reviewer lanes for keys and mobile rev-5 — no path overlap."
  - "Mobile copy lane owning add_product_page.dart:542/:1038 — read ADR :107-139 first."
  - "Read-only research on 570bb640's citation form and repository_credential.dart's stale A1 comments."
PROHIBITED_PARALLEL_WORK:
  - "Any lane writing docs/adr/0018-per-product-git-credentials.md — B-1/H-1/H-2/H-3 are all in the
     producing lane's OWNED_PATH. Serialise."
  - "Any lane editing 9417f8bf or 876c6b97 — Manager-owned; route F-1 first, scope note only."
  - "Dropping stash@{0} — evidence. Safe only as a deliberate recorded act, never as cleanup."
```

## Cleanup confirmation

- [x] **All processes started by this lane are stopped.** None were started.
- [x] **Temporary artifacts: none created.** No out-of-tree scratch written. The existing
      `/private/tmp/adr-a2-safety/` was not created, modified, or deleted by me.
- [x] **Worktree git state untouched.** No `stash`, `checkout`, `reset`, `merge`, `commit`, `push`, or
      `clean` was issued. `stash@{0}` read only and intact.
- [x] **No files modified outside `OWNED_PATHS`** — only this report.
- [x] **No Docker or Compose command was issued by this lane** — not `info`, not `ps`, not `logs`, not
      `config`, not any mutating one. This repository has already lost its QA database to a lane running
      `docker compose -f docker/compose.qa.yaml down -v --rmi local`; the rule was not tested. Compose
      files and Terraform were read as text.
- [x] **Canonical checkout not modified.** Its `apps/control_plane/test/failures/*.png` modifications
      pre-date this review and are not mine.

## Recommended next action

**`CORRECTION_LOOP`** — dispatch a design correction against `ADR0018-A2-REV3` for **B-1, H-1, H-2 and
H-3** (all inside the producing lane's declared `OWNED_PATH`, all four one-to-three-line edits), then a
fresh independent review focused on the normative sweep rather than the four named findings. Route
**F-1** (with corrected scope: four sites) and **G-b** to the Manager in parallel; schedule **M-4**'s
re-verification against `main` `08c7590` at commit time.
