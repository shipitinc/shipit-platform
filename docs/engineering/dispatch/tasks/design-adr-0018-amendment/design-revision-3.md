# Design Revision 3 — ADR 0018 amendment A2: make the ADR's tense match its acceptance

**Supersedes Design Revision 2** (`design-revision-2.md`, `design-revision-metadata-2.yaml`) as the
current description of amendment A2's design state. Revisions 1 and 2 are **retained unaltered** as
history, per this ADR's own convention at `:37-40` ("Amendments are recorded by revision, not by
silent rewrite"). Revision 3 corrects three defects: two HIGH findings from the independent review
of revision 2, and one new finding (G-17) surfaced by the keys rev-5 review.

| Field | Value |
|---|---|
| Task | `design-adr-0018-amendment` (correction pass: `design-correct-adr-0018-a2-2`) |
| Revision number | 3 |
| Supersedes | `ADR0018-A2-REV2` (declared `status: ACCEPTED`, `reviewed_by: null`) |
| Branch | `design/adr-0018-amendment` |
| Base SHA | `289f1d3` (re-based from `43d328b`) |
| HEAD SHA | `289f1d3` (**no commit made** — dispatch forbids committing) |
| Worktree | `/private/tmp/shipit-design-adr0018` |
| Artifact corrected | `docs/adr/0018-per-product-git-credentials.md` (580 → 811 lines) |
| Risk level | **3** (unchanged — see §5) |
| Status | **DRAFT — correction. Never independently reviewed.** |

---

## 0. Scope, ownership, and what this lane is not

### OWNED_PATHS

- `docs/adr/0018-per-product-git-credentials.md`
- `docs/engineering/dispatch/tasks/design-adr-0018-amendment/**`

### READ_ONLY_PATHS

`docs/adr/**` (every other ADR), `.decisions/**` (all 14 objects), `apps/**`, `packages/**`,
`infrastructure/**`, `docker/**` (read as text), `.github/**`,
`docs/engineering/WORK_STATE.md`, `docs/engineering/dispatch/LANES.md`,
`docs/engineering/dispatch/tasks/design-addproduct-keyservice/**`,
`docs/engineering/dispatch/tasks/design-addproduct-mobile/**`.

### PROHIBITED_PATHS (written: none)

Any ADR other than 0018; `.decisions/**`; production source under `apps/**`, `packages/**`,
`infrastructure/**`; QA artifacts; the `design-review-addproduct-*` task directories.

**No commit and no push.**

**No Docker or Compose command was issued by this lane — not `info`, not `ps`, not `logs`, not
`config`, not any mutating one.** `AGENTS.md` binds every lane without deployment authority, and
this repository has already lost its QA database to a lane running
`docker compose -f docker/compose.qa.yaml down -v --rmi local`. Compose files and Terraform were
read **as text** with `rg`/`read`. Every finding below is a file read or a `git` query. Where a
runtime property would be needed, this revision says so rather than asserting it.

### Re-base — and the pre-flight finding about the uncommitted local edit

The worktree arrived at `43d328b` with an uncommitted modification to
`docs/adr/0018-per-product-git-credentials.md` plus an untracked copy of this task directory, and
`git merge --ff-only 289f1d3` failed. **The uncommitted work was not discarded. It was captured,
identified, and found to be fully superseded.** Full detail in `report.md` §Pre-flight; the
conclusion:

- The local working-tree file was **580 lines**; `HEAD` (`43d328b`) was **158**; `main` (`289f1d3`)
  is **580**.
- The local working-tree file and `main`'s version are **byte-identical**: SHA-256
  `9e5b47723e40fd0fd42b69ddf4b5330768ca4fcf782acb0f1992e7aebb83b4fb` for both, and
  `diff -u` between them produced **0 bytes**.
- Therefore the "uncommitted local edit" **was** amendment A2 — the same 158 → 580 revision that
  landed on `main` in commit `5436a4d`. `git merge --ff-only` refused only because git cannot
  fast-forward a branch with a local modification to a file the merge touches, even when the result
  would be byte-identical.

**Sequence actually performed**, preserving rather than discarding:

1. `git diff > …/adr-a2-prelocal.patch` — the edit captured as a patch (34 993 bytes, 496 lines)
   **before** anything else.
2. Copied the working-tree ADR and the whole untracked task directory to an out-of-tree backup.
3. Compared the local file against `main`'s by SHA-256 and `diff` → identical (above).
4. `git stash push` (never `checkout --`), with a message recording that the entry is superseded
   and must not be dropped blindly.
5. **A second obstacle the Manager's pre-flight did not report:** the fast-forward then failed with
   *"The following untracked working tree files would be overwritten by merge"* for all four files
   in this task directory, because `5436a4d` began tracking them. Compared all four against
   `main`'s tracked copies by SHA-256 → **all four identical**; removed the duplicates and
   fast-forwarded. Backup retained.
6. `git merge --ff-only 289f1d3` → **succeeded**, fast-forward `43d328b..289f1d3`, HEAD now
   `289f1d3`, working tree clean. Post-merge ADR SHA-256 is `9e5b4772…` — **identical to the
   preserved local edit**, which is the proof that nothing was lost.
7. **`stash@{0}` is retained, not dropped.** A reviewer may `git stash drop` it after confirming the
   SHA; this lane left it in place so that nothing was destroyed on a judgement call.

**Correction to the dispatch's provenance.** The dispatch states the A2 revision landed in
`6220951`. That SHA does not describe it: `6220951` is
`AGENTS.md: adopt the read-only-over-shared-Docker rule (item G-2)` and **does not touch this ADR**.
The commit that took ADR 0018 from 158 to 580 lines is **`5436a4d`**
("docs(adr): record ADR 0018 A2 acceptance; Penpot instance binding blocks mobile rev5",
2026-10-06 22:11:24 -0400), confirmed by `git log -- docs/adr/0018-per-product-git-credentials.md`
and by line counts at `43d328b` / `5436a4d` / `289f1d3` (158 / 580 / 580). `876c6b97` is a
**decision-object id**, not a commit. This matters for G-17 and is the reason the correction below
cites commits rather than repeating the dispatch's shorthand.

### This lane still does not approve its own work

**Independent design review of this artifact has still never happened.** Revision 2 was returned
`CHANGES_REQUIRED` with 2 HIGH findings; this revision addresses them. `reviewed_by` and
`reviewed_at` remain `null`, and this revision's `status` is **`DRAFT`**, not `ACCEPTED`.

Revision 2's `status: ACCEPTED` referred to **the owner's acceptance of the design** (recorded in
`876c6b97`), which is unchanged and real. It was **not** a statement that the artifact was sound.
This revision keeps that distinction explicit and does not restate the acceptance as if it were a
review.

### The review report that created this task is ABSENT

`docs/engineering/dispatch/tasks/design-adr-0018-amendment/report.md` **does not exist** — this
work item has now lost its reports three times. The task directory contained only
`design-revision.md`, `design-revision-metadata.yaml`, `design-revision-2.md` and
`design-revision-metadata-2.yaml`.

**The finding set below was therefore reconstructed from the ADR text itself**, then checked against
the Manager's recorded summary (`CHANGES_REQUIRED`, 0 BLOCKERS, 2 HIGH) and against the source
decisions. Both HIGH findings were **independently re-verified before being acted on** — see §2 and
§3, each of which states the ADR lines that carry the defect and the evidence. Reconstruction is
recorded here rather than presented as if the report had been read.

---

## 1. What revision 3 changes, itemised

### 1.1 HIGH 1 — "never holds key bytes" is scoped by dimension

**Verified.** The ADR asserted the absolute **and** required the behaviour that falsifies it, in the
same subsection: `:83` read *"SHIP IT writes a reference … and asks the manager for the material at
transport time. **SHIP IT never holds key bytes.**"* Requiring SHIP IT to transmit the private half
is requiring it to hold the private half. The absolute recurred at `:226` (§Decision), `:331-333`
(§Invariants preamble) and in the amendments table.

**Resolution — scope, do not assert (per the dispatch).** The architecture is unchanged. The claim is
now bounded by the dimension it was always about, **storage and custody, not process memory**:

- New §Amendments A2 → **"never holds key bytes" — what that claim does and does not mean**, with
  three parts: what is true and *is* the guarantee (never stored — not in the durable record, a
  table, a file, a log, a backup, a device, or a client payload); what is true and is *not* a
  guarantee (at transport time SHIP IT **must materialise** the private half, and holds it in process
  memory for the connection's lifetime); and the consequence, stated because it was obscured.
- The consequence is the part that matters for security review: **the same-uid exposure does not
  disappear under A3, it moves.** `9417f8bf:116-119` rejected A1 (filesystem `0600`) precisely
  because *"permissions do not defend against a same-uid process — which is the git transport."*
  Under A3 the filesystem is not the exposure; process memory is, for the duration of the
  connection. A3 narrows the window and removes the at-rest artefact. It does not remove the class,
  and no hardening argument resting on "the key is not on the box" is valid.
- Corrected in place at `:45` (amendments table), `:141-149` ("true *literally*" bounded),
`:346-348` (§Decision), `:459-470` (§Invariants preamble, with a correction note so its downstream
readers inherit the right reading), `:181-186` (revocation "bytes SHIP IT does not store").

**This weakens no clause and changes no decision.** It removes a false absolute from a security
document, where a false absolute is more dangerous than an absent one: a reader who trusts it will
not look for the real exposure.

**Recorded, not decided:** the identical absolute phrasing also sits in `9417f8bf:210-211`
("SHIP IT never holds key bytes, only a reference, and asks the manager for the material at push
time") and in `876c6b97:20-21`. Both are Manager-owned and `PROHIBITED` to this lane, so they are
**reported upward** (§8, F-1), not edited.

### 1.2 HIGH 2 — A3 custody is stated as decided-and-unbuilt, in the ADR's own idiom

**Verified.** `9417f8bf` chose A3 and `876c6b97` accepted it *with gap A4*, which `876c6b97:153-155`
describes as **"no adapter exists yet, so there is nothing to probe."** Nothing implements A3:

| Search across `apps/server/lib` and `packages/*/lib` | Result |
|---|---|
| `SecretProvider\|secretProvider\|secret_manager\|secretManager` | **no match** |
| `resolveSecret\|getSecret\|fetchSecret\|readSecret\|secretRef` | **no match** |
| `vault\|awskms\|AWSSecretsManager\|keyvault\|GoogleSecretManager` | **no match** |
| `custodyMode\|secretStrategy\|substrate` | **no match** |

So no adapter, no resolver, no endpoint, and `9417f8bf:133,149` records confidence **LOW**. The ADR
nevertheless stated A3 in the present indicative — `:4` Status, `:33` table, `:78` "**Current** —
custody (A3)", `:226` "**Custody is an external secret manager (A3)**" — which is the class of defect
the keys review caught as B5: asserting a state the record does not support.

**Resolution — the ADR already had the correct idiom 40 lines later.** The host-key clause at
`:368-370` reads **"Requirement, not yet enforced at the transport."** Revision 3 applies the same
device to A3 rather than inventing one:

- New **§Decision status — decided vs. built** (`:278-312`): a nine-row table marking every clause
  **Decided** / **Built** with file-level evidence for each "not built" cell, plus the stated
  consequence. Three clauses are built (per-repository scope; the prohibition on persisting key
  material; key-material immutability as of `e391c02`). Two are **partly** built and recorded that
  way, because the partial state is what an implementer actually meets: `revokeCredential`
  (`:1072-1085`) writes the audit row but nothing destroys a manager handle, and
  `recordCredentialCheck` / `requireUsableCredential` exist but nothing orders **registration** after
  a successful check (`ProductState.registered` is still the default at `product.dart:26`).
  Every A3 clause is decided and unbuilt.
- `#### Current — custody (A3)` → **`#### Decided custody (A3) — specified, not built`**, opening with
  an explicit DECIDED-NOT-IMPLEMENTED marker.
- §Decision bullet retitled to **"Custody is specified to be an external secret manager (A3) …"**
  with an **Implementation status** paragraph carrying the search evidence.
- §Positive revocation bullet → **"specified to be two-sided"**, with "The ShipIt-side action is not
  implemented — no code destroys a manager handle — so today revocation is one-sided in practice."
- Fallback clause: records that **neither A3 nor the fallback is implemented**, so the credential
  path has no working custody story today, and that selecting the fallback adopts the superseded A1
  model with a weaker at-rest property.

**The count of accepted gaps is unchanged: four.** This revision adds **no fifth gap** and closes
none. §Accepted risks now states this explicitly, because the tempting move here is to enshrine the
same-uid point as a fifth accepted risk — that would misstate what the owner was asked and answered.

### 1.3 G-17 — the ADR denied the existence of its own acceptance decision

**Verified, and it is worse than "stale".** Two passages denied the object: §Status `:16-21` ("**no
Human Decision object on disk records this acceptance**" … "A decision object should be created by
the Manager") and §Related "The acceptance itself" `:572-580` ("**There is no Human Decision object
for it in `.decisions/`**").

| Claim | Established by |
|---|---|
| The object exists, `RESOLVED`, `OPTION_A` | file on disk at `289f1d3`, 164 lines, `decision_id: 876c6b97-3e23-459d-aa9d-3a5faeb33702` |
| It was **added** in `5436a4d` | `git log --diff-filter=A -- .decisions/876c6b97*` → `5436a4d`, 2026-10-06 22:11:24 -0400 |
| The **denial** was added in that same commit | `git log -- docs/adr/0018-per-product-git-credentials.md` → `5436a4d`, 158 → 580 lines |
| The denial was **true 48 minutes earlier** | at `43d328b` (21:23:01 -0400), `git ls-tree .decisions/` → **13** objects, none recording this acceptance |

**The account matters, so it is stated precisely.** Revision 2 did **not** fabricate this. Its
verification (R25) was sound **at its base revision `43d328b`**. The failure is that **a fact with a
shelf life was recorded without one**: "none *yet*" was written as "none exists". And the commit that
made it false is **the same commit that published the denial** — the advice at `:20-21` (create a
decision object, per the precedent at `ae1c1f79:8-11`) was followed in the very commit that recorded
the advice, by the Manager, and the two were never reconciled. `876c6b97:8-12` says so itself: the
object exists because *"a sibling design artifact was able to assert an 'Accepted by the human'
amendment that nothing on disk supported."* That is this very work item.

**Resolution.** Both passages now cite `876c6b97-3e23-459d-aa9d-3a5faeb33702` with its decision
fields; the denial is quoted inside a dated correction block that gives the commit, the
`--diff-filter=A` evidence, and the 13-versus-14 timeline; `876c6b97` is added to §Related →
"Decisions governing amendment A2"; and §Status records the correct id and dates. The correction
states explicitly that the earlier verification was sound and that the defect was the tense.

### 1.4 NEW — gap A4's evidence was scoped to `*.dart` and understated what exists

Not in the dispatch. Found while re-verifying HIGH 2's premise, and it changes what an implementer
must do, so it is recorded rather than kept to myself.

Revision 2 justified A4 with a search for `secretmanager|secret_manager|vault|substrate` across
**`*.dart` only**, concluding *"no substrate adapter exists to have been probed."* Sound for the Dart
layer; **misleading as a statement about the substrate**, because it never looked at the
infrastructure — and **a secret manager is already provisioned in this repository's own Terraform**:

| Finding | Evidence |
|---|---|
| GCP Secret Manager secrets declared: `github_token`, `penpot_token`, `serverpod_signing_key` | `infrastructure/modules/secrets/main.tf:23,31,39` |
| A fourth secret, `db_password`, with a managed version | `infrastructure/modules/cloudsql/main.tf:77-89` |
| `roles/secretmanager.secretAccessor` **already granted to the Cloud Run service account** | `infrastructure/modules/iam/main.tf:31-34` |
| Same role granted to the Cloud Build service account | `infrastructure/modules/cloudbuild/main.tf:72-76` |
| Module genuinely instantiated, not orphaned | `infrastructure/main/main.tf:82-87` |
| **No deploy-key secret declared anywhere in `infrastructure/`** | `rg -in 'ssh\|deploy_key\|deployKey\|ed25519\|git_?key' infrastructure/` → **no match** |
| **Nothing binds SHIP IT's server to a secret manager at runtime** | no secret-name / `GOOGLE_*` resolution in `apps/server/lib` or `apps/server/config` |

**Effect: A4 gets narrower, cheaper to close, and more concrete — and stays open.** The question is
no longer "does a secret manager exist for SHIP IT?" but "does the Cloud Run **workload identity**
actually reach it from SHIP IT's topology, and can a deploy key be stored there?" Reachability is
still **UNVERIFIED**, no deploy-key secret exists, no adapter exists. **The accepted consequence is
restated unchanged**, and no Docker or Compose command was run to check any of this.

### 1.5 NEW — `A1`/`A4` are two different identifier spaces in one file

Flagged because it has already produced one wrong conclusion in this session: **"A1/A4"** means
*substrate options* in §Amendments, §Decision and §Preconditions, and *accepted risk ids* in
§Accepted risks. "The A1/A4 fallback" (a custody choice) and "accepted risk A1" (the resurrection
gap) are different things, and **"A3" is simultaneously the adopted substrate and an accepted risk**.
A disambiguation table is added at the head of §Accepted risks. No clause was changed on the strength
of it.

### 1.6 Not changed

- **Revisions 1 and 2 are untouched**, per the ADR's own no-silent-rewrite convention. They remain
  the record of what was believed at `43d328b`.
- **The acceptance itself.** `876c6b97` stands; nothing here re-opens it, and no clause of the
  owner's answer was rewritten. The amendments table's A2 row was re-worded to carry the scoping
  pointers, and the architecture it names is identical.
- **The four accepted risks.** Same four, none closed, none added.
- **`9417f8bf`, `79e860e2`, `898b07d0`, `b869ec24`, `27ea6536`, `570bb640`, `73097d48`, `ae1c1f79`** —
  read, cited, none edited. `.decisions/**` untouched (14 objects, verified unchanged).
- **§13 restoration, the one-active-credential index, key-material immutability, the three
  `HostKeyStatus` sites, the resurrection gap, the unenforced "local only" scope, the
  `referenceName`/G-7 exposure.** All re-read and all still accurate; none altered.
- **Every other ADR**, every production file, every QA artifact.

---

## 2. HIGH 1 — re-verification ledger

| # | ADR site (pre-revision) | Text asserted | Verdict | Action |
|---|---|---|---|---|
| H1-a | `:83` | "…asks the manager for the material at transport time. **SHIP IT never holds key bytes.**" | **Self-contradictory in one sentence** | Replaced with the three-part scoped subsection |
| H1-b | `:226` | "**Custody is an external secret manager (A3). SHIP IT holds a reference, never key bytes.**" | Absolute, in the normative clause | "specified to be"; "stores"; scoping paragraph + cross-reference |
| H1-c | `:33` | "SHIP IT holds a **reference**, never key bytes" | Absolute, in the amendments table | "**stores** a reference and never stores key bytes", pointer to the scoping subsection |
| H1-d | `:331-333` | "SHIP IT holds no key bytes, so every property that used to follow from *having* a key…" | Absolute, and two downstream arguments lean on it | "stores no key bytes"; correction note binding every reader below it to the scoped reading |
| H1-e | `:123` | "not overwriting bytes SHIP IT does not hold" | Absolute, in the revocation clause | "does not store"; "Specified, not implemented" marker added |
| H1-f | `:89-93` | A3 makes the contract true *literally* | True at rest, false in transit | "Literally" explicitly bounded |

Corroborating source: `9417f8bf:210-211` (resolution rationale) and `876c6b97:20-21` both carry the
same absolute. Both are Manager-owned; reported, not edited (§8 F-1).

## 3. HIGH 2 — re-verification ledger

| # | ADR site (pre-revision) | Tense | Verdict | Action |
|---|---|---|---|---|
| H2-a | `:4` Status | "A2 credential custody = external secret manager, revocation = two-sided" | Present indicative for unbuilt clauses | "**specified to be** … — **neither A2 clause is implemented**; see §Decision status" |
| H2-b | `:33` table | "→ an external secret manager (A3)" | Present | "**specified and not yet built**" |
| H2-c | `:78` heading | "**Current** — custody (A3)" | "Current" asserts a running system | "**Decided custody (A3) — specified, not built**", opening with a DECIDED-NOT-IMPLEMENTED marker |
| H2-d | `:226-232` §Decision | "The private half **is** held by the secret manager" | Present indicative, normative | "**is to be** held"; full implementation-status paragraph with search evidence |
| H2-e | `:284-293` §Positive | "Revocation **is** two-sided" | Present indicative for absent code | "**specified to be** two-sided"; "today revocation is one-sided in practice" |
| H2-f | `:233-235` fallback | "remain the documented fallback when no secret manager is reachable" | Implies a reachable manager exists | Records that neither substrate is implemented and that the fallback is a weaker guarantee |
| H2-g | `:511-523` gap A4 | "no substrate adapter exists to have been probed" | True of `*.dart`, misleading of the substrate | Corrected with the Terraform findings; accepted consequence **restated unchanged** |
| H2-h | whole ADR | — | No single place distinguished decided from built | **New §Decision status**, nine clauses, per-clause evidence |

## 4. Corrections to revision 2 found during this re-verification

Recorded because the ADR's own convention requires that a reader can see what changed and why, and
because two of these are errors of my own earlier work.

- **C-1 — the false denial of the acceptance decision (§1.3).** The most consequential defect, and
  one this revision corrects in three artifacts: the ADR at two sites, and revision 2's own
  `design-revision-metadata-2.yaml` (`decision_object: null` plus a note asserting no object exists)
  and `design-revision-2.md` (R25, and the handover item at `:430` "**The absence of a decision
  object for the acceptance**"). Those two are **retained unaltered** as history and superseded by
  this revision's metadata, which records `decision_object` with the real id. Revising them in place
  would repeat the exact defect being corrected.
- **C-2 — R25 counted 14 decision files at `43d328b`; there were 13.**
  `git ls-tree --name-only 43d328b .decisions/ | grep -c yaml` → `13`. R25's *conclusion* — that
  none of them recorded the A2 acceptance — was correct, and its parenthetical count was not. Immaterial
  to the finding, material to the ledger's reliability.
- **C-3 — A4's search scope was `*.dart`-only (§1.4).** The conclusion drawn from it was too broad
  for the scope searched.
- **C-4 — the dispatch's provenance for the A2 revision (`6220951`) is wrong**; it is `5436a4d`
  (§0, Re-base). `876c6b97` is a decision id, not a commit. Recorded because §1.3's entire argument
  is a commit-ordering argument, and the wrong SHA would have made it unverifiable.

---

## 5. Risk level

**RISK_LEVEL: 3** (Major Workflow / Architecture Change), **unchanged from revisions 1 and 2.**

The level describes *the change*, not whether a human blessed it or how carefully it is worded.
Acceptance did not lower it in revision 2, and a precision correction does not lower it here.

1. **Amends recorded architecture on a security boundary.** It governs where a private key capable
   of authorising repository **write** access is held, and what "revoked" means. No such secret
   exists in the repository today.
2. **Changes a core workflow.** Revocation acquires a ShipIt-side action where ADR 0018 said none
   was required, plus a runtime dependency that can block the credential path.
3. **Depends on enforcement that lives elsewhere and is still partly absent.** Improved at
   `43d328b` (the one-active index and predicating upsert merged in `e391c02`); still unsatisfied at
   `289f1d3`: no transport host-key enforcer, no secret-manager adapter, no handle-deletion code, and
   registration is not wired to a connectivity check.
4. **Carries four accepted risks on a security boundary**, recorded with their consequences at
   §Accepted risks A1–A4. The owner accepted them alongside A2 on 2026-10-06 (`876c6b97`) rather
   than gating A2 behind them. **This revision does not close any of them and does not add a fifth**;
   it makes A4's evidence accurate, which narrows the work without changing the risk.
5. **This revision newly discloses a security consequence the earlier revision obscured** — the
   transport-time same-uid exposure (§1.1). It is a **disclosure, not an added risk**: the exposure
   existed in the accepted architecture from the moment A3 was chosen, and this revision is the first
   to state it. Stating it plainly is the reason the risk level does not fall.

**Human gate:** Level 3 approval was satisfied on 2026-10-06 by the repository owner as ADR owner
(`876c6b97`). **That satisfied the gate; it does not satisfy independent review, which has never
happened.** No Level 2/3 **new** decision is required by this revision — it changes wording, tense
and scoping inside an already-accepted architecture, and the dispatch directs exactly that. The
residual item in §8 F-1 is **reported to the Manager for routing**, not decided here.

---

## 6. Traceability

### Requirements covered

| Requirement | Source | Where satisfied |
|---|---|---|
| Stop the "never holds key bytes" claim contradicting the transport-time clause | Dispatch HIGH 1 | §1.1; ADR §Amendments A2 scoping subsection, `:45`, `:141-149`, `:346-348`, `:459-470`, `:181-186` |
| Stop stating A3 custody in the present indicative with no substrate adapter | Dispatch HIGH 2 | §1.2; ADR §Decision status, `:4`, `:45`, `:90`, `:332-348`, revocation bullet, fallback bullet |
| Re-verify both HIGH findings before acting | Dispatch | §2, §3 — each with per-site ledger and file-level evidence |
| Correct the denial of `876c6b97`; say how it was established | Dispatch G-17 | §1.3; ADR §Status and §Related → "The acceptance itself" |
| Preserve the uncommitted local edit; report what was found and done | Dispatch isolation | §0 Re-base; `report.md` §Pre-flight |
| Make the ADR's tense match `876c6b97`'s acceptance-with-four-gaps | Dispatch | §1.2; ADR §Accepted risks preamble ("does not change the count") |
| Read `876c6b97` in full before drafting | Dispatch | Read in full (164 lines) before any edit; it supplied gap A4's wording and the four-gap count |
| Do not re-open settled decisions | Dispatch | §1.6 — nine decisions read and cited, none edited |
| No Docker/Compose command | Hard rule | §0; no command of any kind issued |
| State decided vs planned | Hard rule | §1.2 §Decision status; every clause marked |
| Search the domain's vocabulary; verify paths exist | Hard rule | §1.4 — `docs/adr/`, `infrastructure/`, and both conventions checked; found a substrate a `*.dart`-only search could not see |
| Exact provenance | Hard rule | §0, `design-revision-metadata-3.yaml`, `report.md` |

### Requirements gaps

- **G-a — `9417f8bf` and `876c6b97` still carry the absolute wording** (HIGH 1's root). `PROHIBITED`
  to this lane; routed as §8 F-1. Until the Manager corrects them, the overclaim remains in two
  authoritative records.
- **G-b — the transport-time same-uid exposure has no owner.** It is recorded as a property of the
  accepted architecture (§1.1, gap A4's second consequence) but is **not** one of the four accepted
  risks, so no follow-up action owns it. `876c6b97:147-151` assigns gap A2 (host-key transport) to
  `design-agent` and gaps A3/A4 to implementation/deployment authority; this exposure belongs to
  neither. **Surfaced for the Manager to route; deliberately not self-assigned.**
- **G-c — A3 reachability remains UNVERIFIED and cannot be closed by a design lane.** Verifying it
  requires the runtime probe `876c6b97:152-156` assigns outside this scope. No Docker or Compose
  command was run, and none was needed for any claim made here.
- **G-d — the review report this task was created from is absent**, so the finding set was
  reconstructed (§0). If the report surfaces later and contains findings beyond the two HIGHs and
  G-17, they are **not** addressed by this revision.
- **G-e — §Known gaps "Rotation is still described in product scope in two places"** (§Decision and
  §Positive say "per product"; A1 made it per-repository) is **still open**. It was left alone
  deliberately: it is a documentation reconciliation with no security consequence, it is recorded
  rather than silently rewritten by the ADR's own convention, and it is out of this task's scope.
  Recorded here so it is not mistaken for something this revision fixed.
- **G-f — `876c6b97`'s `confidence: HIGH` recommendation stands against `9417f8bf`'s `confidence:
  LOW`.** Both are Manager-owned records of the same substrate. Not resolved here; noted because a
  reader comparing them will notice.

---

## 7. Design-system compliance, UX/accessibility, feasibility

- **DESIGN_SYSTEM_COMPLIANCE: PASS (not applicable — no UI change).** This revision touches ADR prose
  and a design artifact. It adds no component, token, or layout. It does affect **operator-facing
  copy constraints**: §Amendments A2 already forbids UI text claiming the key "stays in the keychain"
  on a device that no longer holds it, and §1.1 strengthens the underlying truth that copy must not
  rely on — under A3 the private half **is** materialised in SHIP IT's process at transport time, so
  no copy may claim SHIP IT "never holds" it. No copy was authored or changed; the constraint is
  recorded for the mobile lane, which owns that text.
- **UX_ACCESSIBILITY_SCORE: PASS (not applicable — no UI change).** No interface is added, removed or
  restyled. The accessibility surface of this artifact is the ADR itself, and the revision improves
  it: §Decision status is a table rather than prose, the two correction blocks are dated and attributed
  so a reader can tell which text is current, and every negative claim carries the file-level evidence
  that makes it checkable.
- **IMPLEMENTATION_FEASIBILITY: MEDIUM** — unchanged from revision 2, and for the same reason
  recorded there: A3 depends on a substrate that is **decided, provisioned in this repository's
  Terraform, and not yet wired to the credential path**, whose reachability is **UNVERIFIED**, and
  on a transport-time window this revision has just made visible. Revision 3 **reduces** the
  uncertainty an implementer faces (§1.4 turns "is there a secret manager?" into a concrete
  work item) while **increasing** the honesty about what must be built. Feasibility does not rise,
  because nothing was implemented; the estimate does get sharper.

---

## 8. Discoveries

Classified per `docs/engineering/LEARNING_POLICY.md`. **Nothing outside `OWNED_PATHS` was written**;
items needing higher authority are reported for routing, not persisted here.

| # | Finding | Class | Authority | Disposition |
|---|---|---|---|---|
| **F-1** | **`9417f8bf:210-211` and `876c6b97:20-21` both state "SHIP IT never holds key bytes … and asks the manager for the material at push time"** — HIGH 1's root contradiction, sitting in the two Manager-owned decision objects the ADR cites. The ADR is now corrected; **its cited authority is not.** | `CONTRADICTION` | **Human / Manager** — `.decisions/**` is Manager-owned and `PROHIBITED` to design lanes | **Reported.** Not edited. Note `9417f8bf:116-119` already contains the correct same-uid reasoning, so the records are internally inconsistent |
| **F-2** | **GCP Secret Manager is already provisioned in this repository's Terraform**, with `roles/secretmanager.secretAccessor` granted to the Cloud Run service account (`modules/secrets/main.tf:23,31,39`; `modules/iam/main.tf:31-34`; `modules/cloudsql/main.tf:77`; `main/main.tf:82-87`), and **no deploy-key secret declared**. Revision 2's A4 evidence was `*.dart`-only and so could not see it. | `PROJECT_FACT` | Automatic (verified, evidence-backed) | **Persisted** — written into ADR §Decision status and §Accepted risks A4, both in `OWNED_PATHS` |
| **F-3** | **The third lost report.** `design-adr-0018-amendment/report.md` is absent; the task directory holds only the four revision files. The finding set was reconstructed from ADR text, then checked against the Manager's recorded summary and the source decisions. | `WORKFLOW_IMPROVEMENT` | Independent review | **Reported.** Loss of a review report breaks the audit trail: the reviewer's reasoning survives only as a Manager paraphrase in a dispatch prompt. Recommend the Manager persist review output before dispatching a correction task |
| **F-4** | **A second merge obstacle existed that the pre-flight did not report:** after stashing the ADR edit, `git merge --ff-only` failed because the **untracked task directory** collided with files `5436a4d` began tracking. All four were byte-identical to `main`'s copies. Isolation pre-flights should check untracked files against the target commit, not only tracked modifications. | `WORKFLOW_IMPROVEMENT` | Independent review | **Reported.** Worked around safely (SHA-compare, back up, remove duplicates, fast-forward) |
| **F-5** | **`A1`–`A4` denote two different identifier spaces** in ADR 0018 (substrate options vs accepted risk ids), and **"A3" is both the adopted substrate and an accepted risk.** | `PROJECT_FACT` | Automatic | **Persisted** — disambiguation table added to §Accepted risks |
| **F-6** | **`6220951` is not the commit that landed amendment A2.** It is an `AGENTS.md` commit that does not touch this ADR; the A2 revision is `5436a4d`. `876c6b97` is a decision id, not a commit. | `PROJECT_FACT` | Automatic | **Persisted** — ADR §Status, §Related, and `report.md`. Material because G-17's argument is a commit-ordering argument |
| **F-7** | **Two clauses are *partly* built, which a binary "built / not built" reading would hide:** `revokeCredential` writes the audit row but nothing destroys a manager handle; `recordCredentialCheck`/`requireUsableCredential` exist but registration is not wired to them (`ProductState.registered` is the default at `product.dart:26`). | `PROJECT_FACT` | Automatic | **Persisted** — §Decision status marks both "partly" with evidence |

---

## 9. Validation

Every command below was run in `/private/tmp/shipit-design-adr0018`. **No Docker or Compose command
appears in this list or was executed.**

| # | Check | Result |
|---|---|---|
| V-1 | `git rev-parse --short HEAD` (dispatch `VALIDATION_COMMANDS`) | `289f1d3` |
| V-2 | `git status --porcelain` | only the intended ADR modification + untracked revision-3 artifacts |
| V-3 | `grep -n "never holds\|transport" docs/adr/0018-per-product-git-credentials.md` (dispatch `VALIDATION_COMMANDS`) | every hit is either the scoped definition, a cross-reference to it, or the quoted historical wording inside a dated correction block. **No un-scoped assertion remains** |
| V-4 | `grep -n "no Human Decision object\|no citable decision id"` | only inside the correction blockquote that quotes the old denial. **The denial no longer stands as ADR text** |
| V-5 | Substrate searches across `apps/server/lib`, `packages/*/lib` (`SecretProvider`, `secret_manager`, `resolveSecret`/`getSecret`/`fetchSecret`/`readSecret`, `vault`/`awskms`/`keyvault`, `custodyMode`/`secretStrategy`/`substrate`) | **no match** in every family — HIGH 2's premise re-verified |
| V-6 | `infrastructure/` deploy-key search (`ssh\|deploy_key\|deployKey\|ed25519\|git_?key`) | **no match** — F-2's negative half |
| V-7 | `git log --diff-filter=A -- .decisions/876c6b97*` | `5436a4d`, 2026-10-06 22:11:24 -0400 — G-17's proof |
| V-8 | `git log -- docs/adr/0018-per-product-git-credentials.md` | `5436a4d` (158 → 580) — same commit as the denial |
| V-9 | `git ls-tree --name-only 43d328b .decisions/` | **13** objects; at `289f1d3`, **14** — the 48-minute timeline |
| V-10 | SHA-256 of local pre-existing edit vs `main` at `289f1d3` | both `9e5b4772…`; `diff -u` → 0 bytes — the pre-flight finding |
| V-11 | SHA-256 of the four untracked task files vs `main`'s tracked copies | **all four identical** |
| V-12 | ADR line count | 580 → **811** |
| V-13 | `.decisions/**` untouched | 14 objects, no modification; `PROHIBITED_PATHS` respected |
| V-14 | No Docker/Compose command issued | confirmed by this lane's command history; nothing in this table is a Docker read |

**Not validated, and not claimed:** A3 reachability (needs the runtime probe assigned outside this
scope); whether the server's Cloud Run workload identity can actually resolve a secret; any
behaviour of the git transport. §Accepted risks A4 stays **UNVERIFIED**.

---

## 10. Blockers

**None.** `blockers: []`.

No `HUMAN_DECISION_REQUIRED` gate is raised. Reasoning, stated so it can be challenged: this
revision changes **wording, tense, scoping and evidence** inside an architecture the owner accepted
(`876c6b97`), and the dispatch explicitly directs "scope the clauses; do not assert flatly". It
changes no substrate, no revocation model, no gap, no clause of the owner's answer, and adds no
requirement on any implementer beyond what A2 already specified. Inventing a gate here would be the
same error as asserting a state the record does not support — manufacturing process to avoid a
decision.

**Two items are surfaced for the Manager rather than decided here**, and neither blocks this
revision: **F-1** (the same overclaim persists in two Manager-owned decision objects — a
`CONTRADICTION` touching recorded security architecture, which is human/Manager authority) and
**G-b** (the transport-time same-uid exposure has no owning follow-up action).

---

## 11. Handover

**Ready for independent design review.** `reviewed_by` and `reviewed_at` remain **`null`**; this
revision's status is **`DRAFT`**. Revision 2's `status: ACCEPTED` recorded the **owner's** acceptance
of the design and was never a review; this revision does not restate it as one.

A reviewer should check, in this order:

1. **HIGH 1** — that the scoping at §Amendments A2 resolves the contradiction without weakening the
   guarantee, and that the same-uid consequence is stated accurately and not overstated.
2. **HIGH 2** — that §Decision status is right in all nine rows, especially the two **partly**-built
   ones, and that A4's corrected evidence still leaves the gap **open**.
3. **G-17** — that the commit-ordering argument holds and that the correction does not over-claim
   that revision 2 fabricated anything.
4. **§1.4 / F-2** — the Terraform findings, which are **new** and which narrow accepted gap A4.
5. **§0 Re-base** — that the preserved local edit was correctly identified as superseded, and that
   `stash@{0}` may now be dropped (V-10 proves the content is already on `main`).

**Not in this revision's scope**, recorded so absence is not mistaken for completion: §Known gaps'
rotation wording (G-e); A3 reachability (G-c); anything requiring a runtime probe.
