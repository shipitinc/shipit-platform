# Design Revision 5 — server-side deploy-key service, correction of Revision 4

**Revision ID**: `7C1E4A96-2B58-4D3F-A0C7-5E19D28B4F63`
**Brief ID**: `97484D0E-E16C-485E-BAA2-A277889C0FB6` · **Brief version**: `1.1.0` (`design-brief-1.1.0.md`)
**Revision number**: 5 · **Status**: DRAFT · **Risk level**: **3** (re-derived in § 9.1, not inherited)
**Supersedes**: `F2D5AF31-CA53-481A-ACB4-C75DB033A15A` (Revision 4), **retained intact** at
`design-revision-4.md` (tracked on `main` at `5436a4d`). Revision 3 (`4B017787-25A0-4F45-ABDA-805C250AF63F`)
is retained at `design-revision-3.md`; Revision 2 (`F21D5C64-006D-4203-A813-841E08E38B95`) at
`design-revision-2.md`; Revision 1 (`46980EE0-E638-409C-A7D3-E1B9399FECE5`) at `design-revision.md`. No
retained revision's body is edited; only its supersession header is extended.
**Independent review of Revision 4**: `RESULT: DESIGN_REVIEW_CHANGES_REQUIRED`, **2 BLOCKERS, 3 HIGH, 4 MEDIUM,
9 LOW**, `INDEPENDENT_RISK_LEVEL: 3`, `RISK_LEVEL_AGREEMENT: YES`, `CORRECTION_REQUIRED: YES`,
`HUMAN_DECISION_REQUIRED: NO` — **relayed by the Engineering Manager in this dispatch**. **The review
report itself is NOT PRESENT in this worktree or in any worktree**; see § 0.7, which is a disclosed gap and
not a silent one.
**Worktree**: `/private/tmp/shipit-correct-addproduct-keys` · **Branch**: `design-correct-addproduct-keys`
· **Base SHA**: `5436a4d` · **HEAD SHA**: `5436a4d` · **Committed**: **NO** · **Pushed**: **NO**

> **No revision in this chain has ever been approved.** No prior approval covers this correction.
> Revision 2's `DESIGN_REVIEW_APPROVED` certified Revision 2's content and did not carry over; Revision 3
> returned `CHANGES_REQUIRED`; Revision 4 returned `CHANGES_REQUIRED`; Revision 5 carries **no** approval
> of any kind behind it.

**No Docker or Compose command was executed by this lane** — none issued, not even a read-only one. No
analyzer, build, test, contrast or Penpot tool was run. Compose files were read **as text**. Every gate I
did not run is reported `NOT_RUN` (§ 9.3), and every deletion I did not make is reported as not made.

**One correction to Revision 4 that is not a finding and must not be lost.** Revision 4 asserted the ADR 0018
amendment was *"Accepted by the human"* in thirteen-plus places. **At the base Revision 4 cited, nothing on
disk said so**: the amendment's own metadata read `status: DRAFT`, `reviewed_by: null`, `approved_by: null`,
`human_gate.required: true` at level 3, with a blocking item reading *"ADR 0018 status remains Proposed. This
lane does not declare it Accepted."* — and `.decisions/` held no acceptance object. That was
**blocker B5**, and the acceptance is now real. Every such claim is restated with a citation in § 0.2.

---

## 0. What Revision 5 is

### 0.1 Why it exists, and what kind of pass this was

Revision 4 was reviewed by a **fresh** reviewer and returned `CHANGES_REQUIRED` with two blockers, three high,
four medium and nine low findings. **The two blockers are not cosmetic**: one is an acceptance claimed
thirteen-plus times that nothing on disk supported, and the other is a **cross-product disclosure** created
by the very fix that was meant to close a blocker.

| | Blocker | What was wrong | Fixed in |
|---|---|---|---|
| **B5** | unsourced acceptance | the ADR 0018 amendment was asserted *"Accepted by the human"* throughout, on no record. The amendment lane's own metadata said `DRAFT` / `approved_by: null` and carried a blocking item saying it did not declare acceptance; `.decisions/` held no acceptance object. One of § 9.1's six risk reasons rested on it | **§ 0.2**, **§ R.17.1**, **§ R.16**, **§ 10** — every claim now cites `.decisions/876c6b97-3e23-459d-aa9d-3a5faeb33702.yaml` and amendment revision 2, and **§ 9.1's tally is re-stated**: R6 is **UNCHANGED**, not IMPROVED |
| **B6** | the ownership step was bypassed | § R.14.1 step 4 switched to `productRegistryStore.readActiveCredentialForRepository`, which filters on `repositoryId` and `status <> 'revoked'` and has **no product notion and no `_ensureOwned`**. Step 3's read-first is **not** an ownership check and **skips the write** on exactly the cross-product case. `mintOrReadDeployKey(productId: 'A', repositoryId: <B's repository>)` therefore returned **B's** public key, `credentialId`, `status` and `hostKeyStatus` | **§ R.14.1 step 3a** — a normative ownership step, which is now the source of the error table's 403 row; plus **`T-L`** on **both** store tiers. **And `G-13`'s blast radius is corrected**: it omitted `"productId"`, the one column whose rewrite **reparents** another product's repository reference |

**This is a correction pass, not a redesign.** Every finding below is a local, bounded edit to a specific
normative sentence, table row, construct or gap entry. Where material is *added* — the ownership step, the
`lastFailureReason` clause, the ordering requirement on both tiers, `T-L` — it is because a finding demanded
a construct that did not exist, and an assertion without a construct is what both blockers were about.

### 0.2 The ADR 0018 amendment's acceptance — restated with a citation, because Revision 4 asserted it without one (B5)

**Revision 4 said "Accepted by the human" in thirteen-plus places. At Revision 4's own base, nothing on disk
said so.** The amendment's metadata read `status: DRAFT`, `reviewed_by: null`, `approved_by: null`,
`human_gate.required: true` at level 3, and carried a blocking item reading, verbatim: *"ADR 0018 status
remains Proposed. This lane does not declare it Accepted."* `.decisions/` held no acceptance object. That is
blocker **B5**, and it is right: an acceptance claimed in a frozen design contract, supported by nothing,
is not a citation — it is an assertion wearing one.

**The acceptance is now real, and this is what it is.** Two artifacts, both on `main` at this revision's base:

| | What | Where |
|---|---|---|
| **The decision** | Human Decision object, `type: ARCHITECTURE`, `status: RESOLVED`, `created_by: orchestrator-main`, `decided_at 2026-10-06T14:20:00Z`, recording the owner's verbatim answer **"Accept A2, record the gaps as accepted"** | `.decisions/876c6b97-3e23-459d-aa9d-3a5faeb33702.yaml` |
| **The artifact** | ADR 0018 amendment revision 2 — `status: ACCEPTED`, `approved_by` and `approved_at` **populated**, `reviewed_by` / `reviewed_at` **deliberately `null`**, new field `acceptance_is_not_review: true`, `human_gate.required: false` with `level: 3` **retained**, `blocking_items: []` | `docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-metadata-2.yaml`, `design-revision-2.md` |
| **The ADR itself** | Status line now `Accepted (amended — … A1 credential scope = per repository; A2 credential custody = external secret manager, revocation = two-sided)`, plus a new **§ Accepted risks** section carrying A1–A4, each with a *"Consequence accepted."* paragraph and a named owner | `docs/adr/0018-per-product-git-credentials.md:4`, § Accepted risks `:446-524` |

**So: accepted, yes. Reviewed, no.** That distinction is recorded in the amendment's own
`acceptance_is_not_review_note`, in the ADR's own *"What acceptance is NOT"* bullet, and in the decision
object's first follow-up action. **Independent design review of the amendment has never happened and is the
next gate on its own lane.** This revision therefore relies on the amendment's **status** and nothing else:
it does not treat acceptance as review, and § 10.1 asks for the review separately.

**Where the four gaps actually stand, because this design leans on one of them.** ADR § Accepted risks records
A1 (a revoked credential can be resurrected), A2 (host-key verification has a domain enforcer and **no**
transport enforcer), A3 (the *"local only"* scope is a stated posture, not a property) and A4 (the secret
manager's reachability was never runtime-probed). **A1 is this revision's own subject matter** — § R.9.2 is
the resurrection path, and `D-4` is its fix. **A2 is `G-4`.** A3 and A4 are outside this design.

**And the amendment lane corrected a factual error in its own revision 1, in the direction that would have
made A1 look closed.** Revision 1 of the amendment claimed the partial unique index *"refuses the legitimate
fresh mint"*. **It does not**: `rotateCredential` (`engine:1108-1133`) revokes first, so the superseded row is
already outside the index when the replacement is inserted. The index refuses a **second non-revoked row for
one repository** — the two-caller race — not a fresh mint. Corrected in amendment revision 2 (its `D5`).

> **Therefore this design does not lean on `D-2`'s index to close A1, and neither did Revision 4's § R.9.2.
> § R.9.2 already named `D-2` the *backstop* and the engine's one-active guard the *mechanism*.** The index
> is real, present in **both** homes (`apps/server/tool/schema_bootstrap.sql:98-100` and
> `apps/server/migrations/20261006150645000/migration.sql:53-55`, with `verify_schema_bootstrap.sh:91`
> asserting the two agree) — and it is **weaker** than either Revision 4 or the amendment's first draft
> implied. `D-4` is what closes A1; the index only makes a resurrection *user-visible*.

**What the reviewer confirmed, and the bound on that confirmation.** Confirmed and **not** re-opened here:
the provenance/B1 remedy (all nine cited SHAs are ancestors; `AGENTS.md` 199 lines with §13 at `:65`;
`LANES.md` 399 lines with the retraction at `:204-205`); B2's structural claim (the compensation construct
appears in exactly one place, § R.5.7, with three references and no variant); B3's conclusion (**no new field,
no migration needed**); B4's remedy (Tier A and Tier B constructs genuinely distinct); H1, H4 and H7 closed;
`G-13`, `G-14`, `G-15` all real; **and the citation discipline, called "genuinely high"**, with a long list of
`file:line` refs confirmed exact. **Risk level 3 agreed.**

**The bound.** That list confirms *specific claims* and *sampled* citations. It is **not** an approval of
Revision 4, and it does not carry over. What a reviewer should take from it is *"these things were checked and
are right"* — which is why Revision 5 does not touch them, and why they appear below only where a finding
forced a change.

### 0.3 Provenance — one base, and the citation index (B1, L2, **M6**)

**This worktree's `BASE_SHA` is `5436a4d`, reached by `git merge --ff-only main` from `361256c` — a
fast-forward, not a rebase commit.** `main` advanced by two commits (`43d328b`, `5436a4d`), both of which
landed on `main` while Revision 4 was under review. Every citation in this revision is at `5436a4d`.

**A correction to Revision 4's own topology claim, because a frozen contract must not carry a false one
(M6).** Revision 4 § 0.1 said Revision 3's base `77c19f1` *"is **not** an ancestor of `main`"*. **It is** —
`git merge-base --is-ancestor 77c19f1 main` succeeds; `77c19f1` is **18 commits behind** `main` and diverges
from it at nothing (`git merge-base 77c19f1 main` == `77c19f1`). **B1's substance was staleness, not
divergence**: Revision 3's tree did not contain the resolved decisions, the store-integrity work, the LANES
retraction or the restored `AGENTS.md §13`, and that — not topology — is why two gap entries were false.
Revision 4's own metadata said this correctly; its § 0.1 prose did not. Corrected here.

**Every SHA this revision cites is a verified ancestor of `5436a4d`:**

| Label | SHA | What it is | Ancestor of `5436a4d`? |
|---|---|---|---|
| **[5436a4d]** | this lane's `BASE_SHA` = `HEAD_SHA` | `main`'s tip | — (it *is* the base) |
| `[43d328b]` | on `main` | Revision 4's artifacts, tracked; the mobile-rev4 review; the `876c6b97` decision's first landing | **yes** |
| `[361256c]` | on `main` | Revision 4's base; the `D-4`/`D-5`/`D-18` implementation report | **yes** |
| `[e391c02]` | merged into `main` | the credential-store-integrity work (`D-1`, `D-2`) | **yes** |
| `[07c8c8f]` | landed by `e391c02` | the store, engine and credential tests `D-1`/`D-2` produced | **yes** |
| `[4e2d237]` | on `main` | the `LANES.md` retraction | **yes** |
| `[0bf2fa0]` | on `main` | the restored `AGENTS.md §13`/`§13a`/`§13b` | **yes** |
| `[1aa8755]` | on `main` | the Rev-3 review report | **yes** |
| `[0bf2fa0]` ⚠ | `fix/credential-identity-invariants` | **uncommitted** working tree | **not an ancestor** — see below |

```
$ for c in 43d328b 361256c e391c02 07c8c8f 4e2d237 0bf2fa0 1aa8755 674b871 6220951 3a87e27 77c19f1; do
>   printf '%-9s ' "$c"; git merge-base --is-ancestor "$c" 5436a4d && echo ANCESTOR || echo "NOT AN ANCESTOR"; done
```

All `ANCESTOR`, including `77c19f1` — the claim that corrected M6. Output quoted in the metadata.

**Therefore every unlabelled `file:line` in this revision is at `[5436a4d]`, and a reviewer can verify every
one of them from this worktree.** Where a fact was read elsewhere, it is labelled and the label appears in the
index below.

**The one exception, labelled `[UNCOMMITTED 0bf2fa0]`.** The `D-4`/`D-5`/`D-18` implementation lives in the
working tree of `/private/tmp/shipit-credential-identity` on branch `fix/credential-identity-invariants`,
where `HEAD_SHA == BASE_SHA == 0bf2fa0` and **nothing is committed** (implementer's report,
`docs/engineering/dispatch/tasks/fix-credential-identity-invariants/report.md`, tracked on `main`).
I read it **read-only**, as **evidence of what a construct looks like**, and cite it only where a construct's
existence is the point. **It is not a citation of repository state, and it confers no approval** — that
review returned `APPROVE_WITH_NON_BLOCKING_FOLLOWUP` with no blockers but also a **MEDIUM gap in its own
guard** (`verify_schema_bootstrap.sh:267`), and the design it implements was never approved. **Nothing in
§ R.9 is weakened because code exists.**

#### Citation index

| # | Citation class | Revision | Files / ranges cited from it | Check with |
|---|---|---|---|---|
| 1 | Control plane: services, endpoints, models, generated protocol | `[5436a4d]` | `apps/server/lib/src/services/control_plane_service.dart`, `ui_view_mappers.dart`, `endpoints/product_registry_endpoints.dart`, `models/repository_credential_view.yaml`, `models/product_detail_view.yaml`, `generated/**` | this worktree at `5436a4d` |
| 2 | Postgres store | `[5436a4d]` | `apps/server/lib/src/persistence/postgres_product_registry_store.dart` — `$assignments` `:226-240`, CAS branch `:242-304`, `saveProduct` `:33-102` (its `ON CONFLICT DO UPDATE` at `:92-100`), `saveRepositoryReference` `:127-146` (its `ON CONFLICT DO UPDATE` at `:136-142`), `readRepositoryReference` `:148-157`, the `RETURNING` comment `:306-310`, the falsified branch comment `:312-319`, the conflict branch `:322-331`, the `23505` translation `:332-347`, `readActiveCredentialForRepository` `:370-381`, `readCredentialsForProduct` `:384-393` | same |
| 2b | **The same file AFTER `D-4`/`D-5`/`D-6`** | `[UNCOMMITTED 0bf2fa0]` | post-fix line numbers only. **Not `5436a4d` numbers, quoted only where a construct's post-change shape is the point** | `/private/tmp/shipit-credential-identity`, read-only |
| 3 | In-memory store | `[5436a4d]` | `packages/product_registry/lib/src/store/in_memory_product_registry_store.dart` — `saveProductCredential` `:159-194`, the wholesale write `:193`, `_sameKeyMaterial` `:196-209`, `readActiveCredentialForRepository` `:221-232`, `readCredentialsForProduct` `:233-238` | same |
| 4 | Store contract | `[5436a4d]` | `packages/product_registry/lib/src/store/product_registry_store.dart:40-68` (key material); `:71-76` (`readActiveCredentialForRepository`); `:78-82` (`readCredentialsForProduct`) | same |
| 5 | Domain engine | `[5436a4d]` | `packages/product_registry/lib/src/engine/product_registry_engine.dart` — package boundary `:897-915`, `createProduct` `:43-61`, `addRepositoryReference` `:150-170`, `resolveRepository` `:176-183`, `_ensureOwned` `:1784-1790`, `recordGeneratedCredential` `:926-981` (ownership `:938-939`, one-active guard `:954-961`, construction `:963-978`, write `:979`), `confirmHostKey` `:988-1027`, `recordCredentialCheck` `:1034-1068` (revoked refusal `:1044-1046`, host guard `:1047-1052`, setters `:1054-1065`), `revokeCredential` `:1072-1090`, `rotateCredential` `:1098-1133` (**`credentialId` parameter `:1105`, forwarded `:1129`**), `readActiveCredential` `:1135-1142`, `readCredentials` `:1144-1145`, `requireUsableCredential` `:1152-1175` (host guard `:1162-1167`) | same |
| 6 | Domain types | `[5436a4d]` | `packages/platform_contracts/lib/src/types/repository_credential.dart` — `productId` `:63-65`, `referenceName` `:70-72`, `canReachRepository` `:128-129`, `isHostConfirmed` `:132-135`, `copyWith` `:137-172`; `enums/product_state.dart:24-28`; `enums/credential_status.dart:45-50` | same |
| 7 | Exceptions | `[5436a4d]` | `packages/product_registry/lib/src/exceptions.dart` — `ProductNotFoundException` `:3`, `RepositoryNotFoundException` `:12`, `CrossProductAccessException` `:59`, `CredentialNotFoundException` `:201`, `CredentialNotUsableException` `:215`, `HostKeyNotConfirmedException` `:232` | same |
| 8 | Credential tests (in-memory) | `[5436a4d]` | `packages/product_registry/test/credential_test.dart` — retention `:310`, re-check refusal `:323`, material-chosen-once group `:342` (its comment at `:348`), rotation `:521` | same |
| 9 | Postgres integration tests | `[5436a4d]` | `apps/server/test/integration/product_credential_immutability_postgres_test.dart:15-39` (the two-tier clause `:29-31`); the `GAP-2` chain-replay tests at `:622-624` and `:671-673` | same |
| 10 | Migration + bootstrap | `[5436a4d]` | `apps/server/tool/schema_bootstrap.sql:98-100`; `apps/server/migrations/20261006150645000/migration.sql:53-55`; `definition.sql:618-641` (the `product_credential` table, **`lastFailureReason` at `:632`**); `verify_schema_bootstrap.sh:91` | same |
| 11 | ADR 0018 and framework ADRs | `[5436a4d]` | `docs/adr/0018-per-product-git-credentials.md` — **now 580 lines**: Status `:4`, acceptance block `:6-21`, A1 `:35-51`, A2 `:52-148`, § Accepted risks `:446-524`, § Related `:544+`. **Its `:85-88`/`:113-114` line numbers no longer resolve; § R.17 records the re-anchoring** | same |
| 12 | Compose / env (read as text) | `[5436a4d]` | `docker/compose.yaml:16-17`, `:63`; `.env.example:16-18` | same — **never** by running Compose |
| 13 | Client (desktop web) | `[5436a4d]` | `apps/control_plane/lib/data/control_plane_repository.dart`, `features/product_detail/product_detail_page.dart`, `features/products/add_product_page.dart`, `shared/design_primitives.dart` | same |
| 14 | Client fixtures + goldens | `[5436a4d]` | `apps/control_plane/test/product_detail_mobile_golden_test.dart:33`, `test/widgets/product_detail_page_test.dart:18` | same |
| 15 | Worker transport | `[5436a4d]` | `packages/worker_runtime/lib/src/workspace/git_workspace_inspector.dart:106-112` | same |
| 16 | Decision objects | `[5436a4d]` | `.decisions/{9417f8bf, 7b1bc8b7, 79e860e2, 898b07d0, 27ea6536, 4d2c6b81, ae1c1f79, 570bb640, **876c6b97**}-*.yaml` | same |
| 17 | Ledger + workflow | `[5436a4d]` | `AGENTS.md` (§ Test resource hygiene; **199 lines**; §13 `:65`, §13a `:72`, §13b `:78`, per-repository keypair `:91`, restoration note `:96-101`), `docs/engineering/dispatch/LANES.md` (**427 lines**, retraction at `:204-205`), `DECISIONS.md`, `WORK_STATE.md`, `LEARNING_POLICY.md`, `DESIGN_GOVERNANCE.md` | same |
| 18 | Gate D3 review reports | `[5436a4d]` | `tasks/review-addproduct-keys-rev3/report.md`, `tasks/design-review-addproduct-keyservice/report{,-revision-2}.md`, `tasks/review-credential-identity-invariants/report.md`, `tasks/design-review-addproduct-mobile-rev4/report.md` | same |
| 19 | **Superseded labelling** | historical | Revision 3's own `[77c19f1]` / `[07c8c8f]` / `[6220951]` labels and Revision 4's `[361256c]` labels appear **only** inside the retained `design-revision-3.md` / `design-revision-4.md`, quoted where I correct one of them. They are **not** labels this revision uses | those files |
| 20 | **`D-4`/`D-5`/`D-18` implementation** | `[UNCOMMITTED 0bf2fa0]` | `/private/tmp/shipit-credential-identity` working tree. **Read-only. Uncommitted. Unapproved as a design.** Cited only as *"a construct of this shape exists and was reviewed at this level"*, never as repository state | the worktree, read-only |
| 21 | **ADR 0018 amendment design, revision 2** | **`[5436a4d]`, tracked** | `docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-2.md` and `design-revision-metadata-2.yaml`, both **on `main` at `5436a4d`**. **This is no longer an uncommitted sibling worktree** — it is repository state, and it is cited as such (§ 0.2, § R.17.1) | same |
| 22 | a11y contrast figures | **inherited** | `tasks/design-register-button/report.md:71-76` — `inkTertiary` 4.23:1 dark (**fails WCAG AA**), `inkSecondary` 6.74:1 light / 6.10:1 dark. **Not re-measured by this lane** | — |

#### Content pins — `git hash-object` per artifact (L13)

Revision 4's own lesson (**B1**) was that provenance labelling is necessary and **not sufficient**: the base
must move, and the artifact must be pinned to content, not to a commit. **A SHA alone does not pin reviewed
content** — it pins a commit, and the working tree can differ from it. So every artifact carries its blob hash, run at `5436a4d`:

```
$ git hash-object <artifact>
```

**The superseded Revision 4 artifacts — content this revision corrected, so the reviewer must be able to
confirm which bytes were reviewed:**

| Artifact | `git hash-object` |
|---|---|
| `design-revision-4.md` (tracked on `main` at `43d328b`) | `43908b791c04ed388e46c5a0cf1ff649f72a71aa` |
| `design-revision-metadata-4.yaml` | `4fa791135d1fb4aa80acfec1e855c14f32f87ab3` |
| `report-revision-4.md` | `eb4b3c485e64aba64025ff765a430bd9fdb985c4` |
| `traceability-matrix-4.md` | `9d050a27258747ee5172a25ec07947ea31cceaa2` |

**Where the hashes of Revision 5's OWN four artifacts are recorded, and why not here.** **A file cannot
contain its own hash** — writing the value in changes the value — so this table pins only the artifacts
whose content is already frozen. Revision 5's four hashes live in **`report-revision-5.md`**, which is
written **last** and is this lane's contract with the Manager: it records `git hash-object` for
`design-revision-5.md`, `design-revision-metadata-5.yaml`, `traceability-matrix-5.md` and itself-excluded.
`design-revision-metadata-5.yaml` → `provenance.content_pins` carries the same table for a reviewer who
starts from the metadata. **A reviewer should check the hashes in the report first and then decide whether to
trust this revision at all** — that is what the pin is for.

**A reviewer can re-run `git hash-object` on each of Revision 4's four artifacts and confirm the reviewed
content is byte-identical to what this revision corrected.** I verified exactly that as part of the re-base:
the four files were untracked in this worktree but tracked on `main`, and all four hashes matched, so the
re-base could not silently substitute different content.

**Completeness check a reviewer can run in one command**, and I ran it: the ancestor loop above, plus
`git hash-object` on each artifact row. No `MISSING` line. **§ 10.2 asks for nothing uncheckable.**

### 0.4 Correction map — every finding, and where it lands

**The Rev-4 review's findings, one row each. Revision 4's own corrections (B1–B4, H1–H7, M1–M2, L1–L4) were
confirmed and are carried, not re-listed here.**

| Finding | Class | Where it is corrected in Revision 5 |
|---|---|---|
| **B5** acceptance asserted without a record | **BLOCKER** | **§ 0.2** (the two citations, and *acceptance is not review*) · **§ R.17.1** rewritten · **§ R.16** rows 31 and the ADR row · **§ R.17** lead · **§ 9.1** R6 re-stated and the tally **republished** · **§ 10** and **§ 10.1** · every bare "Accepted" replaced with a citable statement |
| **B6** the corrected step 4 bypassed ownership | **BLOCKER** | **§ R.14.1 step 3a** — a **normative ownership step**, now the source of the error table's 403 row · **§ R.14.1** the two false claims at what were lines 2127/2129 corrected · **`T-L`** added (**both** store tiers) · **§ R.14.1** and **§ R.18.2** `G-13` re-stated with the **full column set including `"productId"`**, and the reparenting hazard named |
| **H8** § R.5.7 FORM 2 violates its own obligation 4 | HIGH | **§ R.5.7** — FORM 2 rewritten as `try { … } catch { destroy; rethrow; } finally { zero(privateHalf); }`; the null-handle/`destroyQuietly` disagreement between the sample and the normative sentence **resolved** · **§ 10.2** item 1 now checks obligation 4 on **both** forms |
| **H9** `D-6`'s requirement box names EIGHT columns; the constructs cover SEVEN | HIGH | **§ R.9.4** — the set is decided **once, as eight**: `lastFailureReason` (`text`, nullable, `definition.sql:632`) added to **Tier A** (`_noClear('lastFailureReason', 'text')`) and to **Tier B** (`_clears`) · **§ R.9.5** and **`SC-17`** and **§ R.9.6 `T-K`** now agree |
| **H10** the replacement count is twelve rows across **six** files, not "eleven files" | HIGH | **§ R.3.2** — "twelve rows across **six** files", stated identically in the § A heading, the reconciling sentence, the § 9.2 feasibility table, **§ R.8.4** row 1 and **`SC-12`** · table B's occurrence count corrected (eleven hits, ten listed, `:19` omitted) · the reconciliation of "eleven edit sites" against "ten code edits and two doc-comment edits" **resolved to one count** · the honest flagging of the difference from the review's *"nine"* **kept** · `protocol.dart` **dropped** from the change list, not merely marked NO-OP |
| **M3** § R.11.2 row 3 claims `revokedAt`/`revokedReason` are on the view | MEDIUM | **§ R.11.2** row 3 corrected — the view carries **neither**; state 4 renders from **`status` alone** |
| **M4** § R.11.2's selection rule is under-specified twice | MEDIUM | **§ R.11.2** — the **direction** is stated (repository-driven, and why credential-driven contradicts `product_detail_view.yaml:11`) · ordering is **required on both tiers** (Tier B has none today) · the *"most recent = highest `version`"* gloss is **dropped and shown to be wrong** · the rule is **added to § R.9.7's** contract sentence |
| **M5** the amendment is not "not in `docs/adr/**`" | MEDIUM | **§ R.17.1** and **§ 9.1** R6 — stated plainly: the amendment is an **in-place edit of `docs/adr/0018-per-product-git-credentials.md`**, **uncommitted and unmerged** at this base · **§ 10.1** action 1 re-worded to ***commit and land that edit*** · and the state at `5436a4d` recorded: it is now **both** — merged, and still carrying `reviewed_by: null` |
| **M6** § 0.1's false topology claim about `77c19f1` | MEDIUM | **§ 0.3** — `77c19f1` **is** an ancestor, 18 commits behind, diverging from nothing; **B1's substance was staleness** |
| **M7** § R.9.1's reason for the conflict branch being mint-only | MEDIUM | **§ R.9.1** — the sentence is corrected: `rotateCredential` takes `String? credentialId` as a **caller parameter** (`engine:1105`) and forwards it (`:1129`), so a caller passing the superseded id **reaches the branch** — `D-18`'s resurrection path through a **first-class domain method** · **`rotateCredential`'s `credentialId`** added to § R.9.5's identity row · **`T-D`** extended to drive the attempt through `rotateCredential` too |
| **L5** wrong step numbers in § R.5.7's "where this is used" and § 0.4's B2 row | LOW | Corrected in **§ R.5.7** and in the Revision-4 correction map's note here (the verbatim claim itself holds) |
| **L6** "four obligations" should be **five** | LOW | **§ 9.2**'s feasibility table and **`design-revision-metadata-5.yaml`** |
| **L7** the tally is not **verbatim** in the metadata (off by one word) | LOW | **§ 9.1** / metadata / report now carry **one identical sentence**, character for character |
| **L8** § R.11g item 7 inverts `_buildFooter`'s definition and call site | LOW | **§ R.11g item 7 rewritten** — **call site `:314`, definition `:375`, copy `:383`** — and the two mis-cited neighbours corrected. **And the claim that mobile's `TechnicalDetails` has no `note:` is false: `:925` is the DESKTOP one and it does.** Both `note:` sites named. **This is a binding consumption contract and the sibling lane is being pointed at the wrong lines, so it is fixed in full** |
| **L9** § R.8.5's blockquote truncates the comment it declares falsified | LOW | **§ R.8.5** — the comment is quoted **in full**, including the trailing `rotateCredential` sentence Revision 4 cut |
| **L10** a second falsifiable comment (`credential_test.dart:348`) is unnamed | LOW | **§ R.8.5** — named, with its **wrong line citation for the one-active rule** corrected (`engine:940-941` is the empty-key check; the one-active rule is **`engine:954-961`**), and added to `D-4`'s comment-correction scope |
| **L11** `GAP-2` unmapped in § R.9.6's tier table | LOW | **§ R.9.6** — `GAP-2` mapped into the tier table (the `definition.sql`/`schema_bootstrap.sql` chain-path test, **Postgres-only**) |
| **L12** a one-line citation slip | LOW | **§ R.11g item 7** — the `TechnicalDetails` line, corrected under L8. (The review named one slip; L8's is the same line.) |
| **L13** no SHA pins the reviewed content | LOW | **§ 0.3** — `git hash-object` recorded **per artifact** alongside `HEAD_SHA`, in § 0.3, the metadata and the report |
| **new** | — | **§ 0.7** — the Rev-4 review report is **absent from every worktree**; disclosed rather than worked around silently |
| **new** | — | **§ R.11g** — a **"what the sibling lane needs from § R.11g"** block, because Design Revision 4 of the mobile boards is **blocked on Penpot** and cannot re-ground the Unknown-host pair without this revision |

### 0.5 What Revision 4 got right and this revision therefore does **not** touch

Carried **verbatim in normative voice**, with no edit: § R.1.1–R.1.7 (with § R.1.1 consequence (1) re-worded only
where it names the amendment's status) · § R.2 constraints 1–3 and § R.2.4 · § R.3.1, § R.3.3, § R.3.4 · § R.4
(the withdrawal notice) · § R.5.1, § R.5.2 (steps 0–4, 6, 7), § R.5.3, § R.5.4, § R.5.5, § R.5.6 ·
§ R.6.1–R.6.3 · § R.7 and § R.7.1 · § R.8.1–R.8.4 · § R.9.1's **call-site table** · § R.9.2 · § R.9.3 ·
§ R.9.7's first three required edits · § R.10.0, § R.10.1, § R.10.2's `N-1`–`N-9` including the exact custody
string · § R.11's two axes and `canRegister` · § R.11.1 · § R.12's claims table · § R.13.1 and § R.13.2's
taxonomy · § R.14.2, § R.14.3 · § R.15 in full · § R.16 rows 1–30, 32–43 · § 8's `SC-01`–`SC-16` except where
extended · § 9.2's three ratings and its per-component table except the two corrected cells.

### 0.6 Section map — Revision 4 → Revision 5

| Revision 4 § | Revision 5 § | Disposition |
|---|---|---|
| 0.1–0.6 | **0.1–0.7** | Replaced — provenance moved to `5436a4d`; § 0.2 is now the acceptance citation; § 0.7 new |
| R.1 | **R.1** | Carried; § R.1.1 consequence (1)'s acceptance wording cited |
| R.2, R.2.4 | **R.2**, R.2.4 | Carried unchanged |
| R.3 | **R.3** | Carried; **R.3.2 counts corrected** (H10) |
| R.4 | **R.4** | Carried unchanged — still a withdrawal notice |
| R.5 | **R.5** | Carried; **R.5.7 both forms rewritten** (H8) |
| R.6 | **R.6** | Carried unchanged |
| R.7, R.7.1 | **R.7** | Carried unchanged |
| R.8 | **R.8** | Carried; **R.8.4 row 1's count corrected**; **R.8.5's blockquote completed** and the second falsified comment named (L9, L10) |
| R.9 | **R.9** | **R.9.1's conflict-branch reason corrected** (M7); **R.9.4's set decided once as eight** (H9); **R.9.6 gains `T-L`** and `GAP-2` mapped (L11); **R.9.7 gains the ordering rule** (M4) |
| R.10 | **R.10** | Carried unchanged |
| R.11, R.11.1, R.11g | **R.11** | Carried; **R.11.2 rows 2–3 and the selection rule rewritten** (M3, M4); **R.11g item 7 rewritten** (L8) and the sibling-needs block added |
| R.12 | **R.12** | Carried unchanged |
| R.13 | **R.13** | Carried unchanged |
| R.14 | **R.14** | **R.14.1 gains step 3a — the normative ownership step** (B6), and its two false claims corrected |
| R.15 | **R.15** | Carried unchanged |
| R.16 | **R.16** | Carried; **rows 31 and 46** corrected for the acceptance wording and the ownership step |
| R.17, R.17.1 | **R.17** | **R.17.1 rewritten** — the citations, *acceptance is not review*, and the real state of the edit (B5, M5) |
| R.18 | **R.18** | **R.18.2** — `G-13` re-stated with the full column set; `G-16` added for the ownership step's own test |
| 8 | **8** | `SC-12`, `SC-17`, `SC-18` corrected; **`SC-20`** added for ownership |
| 9 | **9** | Risk re-derived; **the tally republished** — 0 IMPROVED / 2 UNCHANGED / 4 WORSE (B5) |
| 10 | **10** | **10.1** action 1 re-worded; **10.2** item 1 extended to both forms (H8) and item 11's tally updated |

### 0.7 A disclosed gap: the Rev-4 review report is not on disk

**The Manager directed me to read `docs/engineering/dispatch/tasks/review-addproduct-keys-rev4/report.md` in
full. It does not exist.** I checked every worktree (`git worktree list` — 31 of them), the canonical
repository, both plausible directory names (`review-addproduct-keys-rev4` and
`design-review-addproduct-keys-rev4`; the latter exists and is **empty**), and every commit reachable from any
ref. Nothing. The directory `docs/engineering/dispatch/tasks/design-review-addproduct-keys-rev4/` was created
and never written to.

**So this revision is corrected against the review's findings *as relayed by the Manager in this dispatch*,
not against the report.** That is a real limitation and I state it rather than implying I read the source:

- I did **not** re-derive the finding set. I took **18 findings** — B5, B6, H8, H9, H10, M3–M7, L5–L13 — as
  given, and verified each one's **underlying factual claim against the repository** independently before
  correcting it. Every `file:line` in this revision was opened and read at `5436a4d`.
- The Manager's relay includes the reviewer's **evidence for each finding**, and where that evidence was
  checkable I confirmed it (B6's `engine:1135-1142`, `addRepositoryReference`'s `readProduct` call, H9's
  `definition.sql:632`, H10's twelve rows, M3's `repository_credential_view.yaml`, M4's missing Tier B
  ordering, M6's `77c19f1` topology, M7's `engine:1105`/`:1129`, L8's `_buildFooter` lines). **Where the
  relay's evidence did not match source, I say so in the place it affects** — see § R.11g item 7, where the
  relay's claim about *which* `TechnicalDetails` site is the desktop one is itself inverted, and the
  correction is made against source.
- **A reviewer should read the actual report before approving this revision**, because a finding's *wording*
  may differ from its substance and a correction can answer the wrong sentence. **Owner: the Manager** —
  either supply the report, or accept the relay as the finding set of record. **This is a
  `PROVENANCE_GAP`, not a `HUMAN_DECISION_REQUIRED`**: it does not gate a design decision, and the design
  content is complete either way.

---

---

## R.1 — The at-rest protection model — **CLOSED**

### R.1.1 What was decided, and what that forecloses

`9417f8bf` **RESOLVED, OPTION_C**, `decided_at 2026-10-06T13:05:00Z` **[5436a4d]**:

> The human chose to SUPERSEDE ADR 0018 `:85-88`'s local-secret-store clause and adopt **A3, an external
> secret manager** — SHIP IT never holds key bytes, only a reference, and asks the manager for the
> material at push time.

Three of its consequences are binding on this revision, and I treat them as normative input rather than
as commentary:

1. **ADR 0018 `:85-88` is superseded** and must be amended by a follow-up, not silently ignored. § R.17
   states the amendment contract. **The amendment exists and is human-accepted** — Human Decision
   `876c6b97-3e23-459d-aa9d-3a5faeb33702.yaml` (`ARCHITECTURE`, `RESOLVED`) and amendment revision 2
   (`status: ACCEPTED`, `approved_by`/`approved_at` populated, `reviewed_by`/`reviewed_at` still `null`) —
   so this is no longer a pending predecessor. **It has never been independently reviewed**, and it remains
   subject to § R.17.1's residual. **I did not author it and `docs/adr/**` is `PROHIBITED_PATHS` for this
   lane**, so I record its state and do not perform it.
2. **A2 is permanently excluded.** The ADR's *"never persisted to the durable record"* still binds it —
   the prohibition survives even though the custody sentence above it does not. See § R.1.6.
3. **A3 makes the reference the most sensitive artifact SHIP IT holds**, because an ARN or secret path
   discloses vault topology. `G-7` is therefore **REQUIRED**, not optional.

### R.1.2 The manager interface — normative

A new **`SecretProvider`** port lives in `apps/server/**` and its implementation in
`apps/server/lib/src/secret/**`. **It must not live in `packages/product_registry`** — `C-02`, and
`product_registry_engine.dart:897-915` **[5436a4d]** (the section header for
*"Repository credentials (ADR 0018 A1 — scope is one repository)"*): *"This engine never generates or holds
key material … A private key must never reach this package."* The domain receives only a handle.

```dart
// apps/server/lib/src/secret/secret_provider.dart  — the port lives HERE, not in product_registry
abstract interface class SecretProvider {
  /// Proves the manager is reachable AND that its protection is what we require.
  /// Throws [SecretSubstrateUnavailable] rather than returning a degraded value.
  Future<void> verifyProtection(SecretProtectionPolicy policy);

  /// Writes the private half. Returns the durable handle SHIP IT stores.
  /// `bytes` must be zeroed by the caller immediately after this returns.
  Future<String> put(SecretBinding binding, List<int> bytes);

  /// Resolves a handle to the private half. Only the transport may call this (§ R.7).
  Future<List<int>> resolve(String handle);

  /// Destroys the manager-side object. MUST be idempotent: a missing object is success.
  Future<void> destroy(String handle);
}
```

`SecretBinding` carries **no vault topology from the caller**: the manager address, the path prefix and
the key-name template come from **server configuration** — never from the request, never from the
database. `SecretProtectionPolicy` is the machine-checkable form of ADR 0018 `:92-95`'s intent under A3:
encryption at rest enabled, and the application's own identity permitted to read **and delete** in the
credential path. **Delete permission is required**, not optional, because § R.6's revocation is now a
ShipIt-side action.

**`verifyProtection` is a separate call, not a side effect of `put`.** Under `7b1bc8b7` the refusal must
happen *before* anything is generated, and a check sharing a code path with the write cannot guarantee
that ordering.

### R.1.3 How the reference is formed — the one design choice inside the decision

**This is the only place in this revision where I chose something the resolved decision did not spell
out, so it is stated as a choice with its alternative named, rather than buried.** The reviewer confirmed
it is a proper judgement and raised no finding against it.

The decision's option text says *"`referenceName` is a secret path or ARN"*. Taken literally the durable
record would carry vault topology — and this repository's durable record is **readable by an off-host
caller with a password published in a committed file**: `docker/compose.yaml:63` hardcodes
`SERVERPOD_DATABASE_PASSWORD: shipit`, `docker/compose.yaml:16-17` publishes `"5432:5432"` unqualified
(Docker resolves that to `0.0.0.0`), and `.env.example:16-18` documents
`POSTGRES_USER=shipit / POSTGRES_PASSWORD=shipit` — all **[5436a4d]**, read as text.

So the literal-ARN form and consequence (3) of `9417f8bf` are in tension **in this repository
specifically**. I resolve it in the direction that satisfies consequence (3) without re-opening the
substrate decision:

> **`referenceName` is a server-generated opaque handle, not a path and not an ARN.** It is
> `credbind_<32 hex chars>` — 128 bits from the platform CSPRNG, carrying no product, repository,
> product-name or manager-name information. The manager's actual address, path prefix and secret name are
> **derived at resolve time** from server configuration plus the handle. The durable record therefore
> discloses **only that a credential exists** — not which vault, not which path, not whose.

This keeps ADR 0018 `:92-95` *"referenced by name, never by value"* literally true (the handle **is** the
reference), keeps the decision's custody property intact, and closes the topology-disclosure channel the
decision itself flagged. The alternative — store the ARN in the column — remains available and is **not**
forbidden by the decision. It costs exactly one thing: anyone who reaches 5432 with the committed default
password learns the vault layout and every secret name in it. **I rejected it on that basis and record
the rejection here so a reviewer can challenge it.**

**What this choice does not do:** it does not make the handle safe to publish. Knowing a handle grants
nothing — the manager is separately authenticated — but it is an internal identifier for a live secret,
so § R.3.2 still removes it from every client surface.

### R.1.4 How the reference is resolved at push time — normative

At transport time, and **only** there (§ R.7):

1. The credential row yields `referenceName`.
2. The transport calls `SecretProvider.resolve(referenceName)`.
3. The transport builds an ephemeral `ssh` invocation carrying the material through the `IdentityFile`
   mechanism **out of the work tree**, in a private directory removed in a `finally`.
4. The material is zeroed; the handle is never written to a command line, to an env var that is logged,
   or to a subprocess argument that would appear in a process listing.

Step 4 is not a nicety: `git_workspace_inspector.dart:106-112` **[5436a4d]** runs `Process.run(git, args)`
with **no `environment:`**, and a repository-wide grep for
`SSH_AUTH_SOCK|known_hosts|ssh-keyscan|StrictHostKeyChecking|IdentityFile` across `apps` and `packages`
returns **0 matches**. ADR 0015 `:55-59` (`EnvironmentPolicy`) and ADR 0018 `:67` are where this seam is
homed. Until it exists, `resolve` has no caller and step 4 has no enforcement — § R.10.3 and § 9.4.

### R.1.5 A1/A4 as the documented fallback, with the trigger condition

`9417f8bf`'s follow-up action keeps them: *"keep A1/A4 as the documented fallback when no manager is
reachable in the target topology."* Normative, and **only** as a fallback:

| Substrate | Shape | **Trigger condition — the only condition under which it may be selected** |
|---|---|---|
| **A1** | private half written under a dedicated directory **outside the work tree**, owned by the service user, mode `0600`, on a volume not shared with application code | The deployment topology is a **single host**, and `verifyProtection` reports that **no manager endpoint is configured at all** (`SHIPIT_SECRET_MANAGER_ENDPOINT` unset). It is **not** a fallback for a manager that is configured but down: a configured-but-unreachable manager is `secretManagerUnreachable` and **fails closed** (§ R.5), because silently downgrading custody is precisely what `7b1bc8b7` refused. |
| **A4** | private half in the host keychain or a TPM-backed store, read by handle at transport time | The deployment target **exposes such a store to the server process**, and that reachability is proven **on the target**, not inferred from a development machine. |

**Both fallbacks are single-host, and both inherit the topology condition that made A1's compliance *"by
coincidence of topology"* in Revision 2.** A1 protects nothing against a same-uid process — which is the
git transport (`git_workspace_inspector.dart:106-112`, no `environment:`) — and A4's container→host
reachability is **`UNVERIFIED`** (§ 9.4; I could not test it, and this lane issued no Docker command).
Selecting either is therefore a **deployment-topology assertion the operator must make and record**, not
an implementation default. **A3 is the default; a fallback is a recorded deviation.**

### R.1.6 A2 is excluded — permanently

**ADR 0018 `:86-88` forbids it, and that prohibition survives the supersession.** The supersession
replaced the *custody* sentence — where the bytes live. It did not license persisting bytes to the
durable record; `9417f8bf` says so in terms: *"A2 is permanently excluded — the ADR's 'never persisted to
the durable record' still binds it."*

A2 appears in this revision **once**, here, so that a reader holding Revision 3 knows it is *closed*
rather than *missing*. It is **not** presented as an option, it has no advantages listed, and the
`referenceName`-as-opaque-row-reference variant it implied is superseded anyway by § R.1.3.

### R.1.7 Where the composition lives — **NEW, and it is a boundary, not a preference (H7)**

**The defect the finding named.** Revision 3's § R.6.1 presented its four-line pseudocode under the
heading `revokeCredential(productId, credentialId, reason)`, using the engine's private `_ensureOwned`. Read
literally — and it reads literally, because it is named after an engine method and uses an engine-private
symbol — it places a `SecretProvider.destroy` call **inside `packages/product_registry`**, which § R.1.2
and `C-02` forbid and which `product_registry_engine.dart:897-915` states in its own section header.

**The corrected split, stated normatively.** There are exactly **three** layers, and each one is named:

| Layer | Home | What it may touch | What it may **never** touch |
|---|---|---|---|
| **Domain** | `packages/product_registry` | credentials, products, repository references, host trust | **any `SecretProvider`**, any handle, any key bytes (`engine:897-915`) |
| **Application / composition** | `apps/server/lib/src/secret/**` **and the endpoint + service layer that owns the flow** | the `SecretProvider` port, `verifyProtection`, `put`, `destroy`, the compensation construct, the substrate exception | key bytes beyond the memory window of one call |
| **Transport** | the git transport adapter (`§ R.1.4`) | `resolve`, the ephemeral `IdentityFile`, zeroing | anything durable |

**So the composition this revision specifies lives in `apps/server`.** Concretely, and this is the
normative statement:

```dart
// apps/server — the composition root. NOT the engine, NOT the domain package.
// The endpoint (or a service beside it) owns the substrate and calls the engine
// for domain work only. The engine is never handed a SecretProvider.
Future<CredentialStatusView> revokeRepositoryCredential(Session session, {
  required String productId, required String credentialId, required String reason,
}) async {
  final engine = ControlPlaneService(session).productRegistryEngine;   // domain
  final provider = session.services.secretProvider;                    // apps/server

  final c = await engine.readProductCredential(credentialId);   // domain read
  // ownership is the engine's to enforce; the application layer does not re-derive it
  await provider.destroy(c.referenceName);                      // ← FIRST (§ R.6.1)
  return engine.revokeCredential(                               // ← domain write, CAS
    productId: productId, credentialId: credentialId, reason: reason);
}
```

**Three obligations that follow, and they are testable:**

1. **`SecretProvider` is never a constructor parameter of `ProductRegistryEngine`.** If it were, the domain
   would hold the port and the boundary would be a comment. `grep -n "SecretProvider" packages/product_registry/`
   must return **0 matches** in production sources — `SC-18`.
2. **The substrate precondition and the compensation construct (§ R.5.7) are application-layer code**, for
   the same reason. `SecretSubstrateUnavailable` lives in `apps/server` (§ R.5.5, obligation 3) and the
   engine has no way to throw it.
3. **The revocation endpoint's two-sidedness is therefore an application-layer ordering**, and the engine's
   `revokeCredential` remains a single-row CAS write that knows nothing about a manager. That is the
   correct decomposition: it is what keeps `rotateCredential` (§ R.6.1) working unchanged, and it is what
   makes the domain testable without a manager.

**What this changes about the pseudocode in § R.6.1:** only its attribution. The four steps and their
order are unchanged and still normative; the pseudocode is now explicitly `apps/server`, and the engine's
participation is exactly one read and one CAS write.

---

## R.2 — What the existing domain constrains

Carried from Revision 2 § R.2 and Revision 3 § R.2. Constraints 1–3 hold; 1 and 3 are **structurally**
satisfied rather than merely respected.

1. **The private half never enters `packages/product_registry`.** Under A3 this is stronger than a rule
   the implementation must honour: SHIP IT's own process **never holds the bytes** except in the
   transport's memory window (§ R.1.4 steps 3–4). `recordGeneratedCredential`'s existing refusal of a
   `publicKey` containing `PRIVATE KEY` (`engine:946-953` **[5436a4d]**) stays, and the
   `credential_test.dart` group *"no key material reaches the domain"* stays as the guard. **§ R.1.7 adds
   the mechanical check that the boundary has not been crossed by an import.**
2. **`RepositoryCredential` never gains a key-material field.** Unchanged. Under A3 this is no longer
   even a temptation, because SHIP IT does not have the material to store.
3. **The private half is immutable per credential — in memory only; the persistence boundary is
   separately guarded.** `copyWith` (`packages/platform_contracts/lib/src/types/repository_credential.dart:137-172`
   **[5436a4d]**) takes exactly `status, lastVerifiedAt, lastVerifiedBy, lastFailureReason, hostKeyStatus,
   host, hostKeyFingerprint, hostConfirmedAt, hostConfirmedBy, revokedAt, revokedReason, version` — so it
   **cannot** change `credentialId`, `productId`, `repositoryId`, `referenceName`, `publicKey`,
   `fingerprint`, `algorithm`, `createdAt` or `supersedesCredentialId`. Revision 2's overstated version of
   this is still withdrawn; what holds at the persistence layer is `D-1`/`D-2` (landed, § R.8.1) and, as
   of this revision, `D-4`/`D-5`/`D-6` (**specified per tier, not built**, § R.9).

### R.2.4 The substrate is a runtime dependency

Carried from `7b1bc8b7`'s own reasoning: under A3, **the manager can be unavailable**, and the credential
flow depends on it at mint, at push and at revoke. Three consequences that bind the design:

- **It fails closed** (§ R.5), so an unavailable manager **blocks** the flow. Correct posture, and also a
  **denial-of-service surface on the credential path** — § R.15.3.
- **It is not local-only and it is not loopback**: a manager is by definition a network service, so the
  *"local only"* scope `570bb640` relies on has **no bearing whatsoever** on it. `570bb640`'s loopback
  pinning is still un-implemented (§ R.15.1) and A3 does not make it easier.
- **A3's reachability in this repository's target topology is `UNVERIFIED`** — `9417f8bf`'s own follow-up
  action assigns the probe to the implementer. § 9.4 keeps that honest, and the risk level in § 9.1
  reflects it.

---

## R.3 — `referenceName`: the invariant, the settled subject, and G-7 as REQUIRED work

### R.3.1 The invariant — carried verbatim

> **`referenceName` continues to name a reference. It never carries a value.** It does not hold key
> material, is not an obfuscation of key material, and must not be derived from it.

Unchanged. Under A3 this is no longer merely an invariant the design asserts — it is the **mechanism**,
and § R.1.3's opaque-handle form is chosen partly because it keeps this statement true under inspection.

Revision 2 marked three things `OPEN`: the field's **subject**, its **substrate**, and its **client
exposure**. Under `9417f8bf`: the **subject** is a secret manager (settled), the **substrate** is A3
(settled), the **client exposure** is **no** (settled — § R.3.2). **All three are closed. None is
re-opened here.**

### R.3.2 `G-7` — REQUIRED: `referenceName` leaves `RepositoryCredentialView` — **the change list, verified site by site (H5)**

**Required behaviour.** `RepositoryCredentialView` **loses the `referenceName` field and gains nothing in
its place.**

Revision 3 presented this as a seven-row change list. It is **not seven**, two of the sites it omitted **will
not compile**, and one file it listed changes **not at all**. The table below is the complete list, derived
by grepping every `referenceName` occurrence in `apps/**` and `packages/**` at `[5436a4d]` and classifying
each. **It is a complete change list, and a reviewer can regenerate it with the command in the caption.**

```
$ grep -rn "referenceName" --include="*.dart" --include="*.yaml" apps packages \
    | grep -v "/generated/" | grep -v platform_contracts | grep -v "product_registry/lib" \
    | grep -v "product_registry/test" | grep -v "persistence/" | grep -v "apps/server/test"
$ … | awk -F: '{print $1}' | sort | uniq -c     # the file census this section's count comes from
```

The census, run at `[5436a4d]` — **ten files carry a hit, and the six that must be edited are rows 1–12
below**:

```
   4 apps/control_plane/lib/data/control_plane_repository.dart
   2 apps/control_plane/lib/features/product_detail/product_detail_page.dart
   1 apps/control_plane/test/product_detail_mobile_golden_test.dart
   1 apps/control_plane/test/widgets/product_detail_page_test.dart
   1 apps/server/lib/src/database/repository_credential.spy.yaml          ← § D, keeps the field
   2 apps/server/lib/src/models/repository_credential_view.yaml            ← rows 1–2
   1 apps/server/lib/src/services/ui_view_mappers.dart                    ← row 3
   1 apps/server/tool/schema_bootstrap.dart                               ← § D, keeps it
  11 packages/control_plane_client/lib/src/protocol/repository_credential_view.dart   ← generated
```

#### A. Hand-written sites that MUST be edited — **twelve rows across SIX files**

| # | File:line | What is there now | Edit | Compiles without it? |
|---|---|---|---|---|
| 1 | `apps/server/lib/src/models/repository_credential_view.yaml:11` | `referenceName: String` | delete the field | the model source drives the generation; everything below follows |
| 2 | `apps/server/lib/src/models/repository_credential_view.yaml:4` | doc comment naming `referenceName` | rewrite the sentence | compiles; **stale prose otherwise** |
| 3 | `apps/server/lib/src/services/ui_view_mappers.dart:176` | `referenceName: c.referenceName,` | delete the assignment (method spans `:169-188`) | **no** — the generated ctor no longer takes it |
| 4 | `apps/control_plane/lib/data/control_plane_repository.dart:1691` | `required this.referenceName,` | delete the constructor parameter | **no** — the parameter is required and the named-arg call sites stop matching |
| 5 | `apps/control_plane/lib/data/control_plane_repository.dart:1709` | `final String referenceName;` | delete the field | **no** |
| 6 | `apps/control_plane/lib/data/control_plane_repository.dart:1708` | doc comment *"Name of the local secret-store entry. Never the value."* | delete with the field | compiles; **stale prose otherwise** — and it asserts a custody model A3 replaced |
| 7 | `apps/control_plane/lib/data/control_plane_repository.dart:108` | `referenceName: c.referenceName,` | delete the mapping | **no** |
| 8 | `apps/control_plane/lib/data/control_plane_repository.dart:1098` | `referenceName: c.referenceName,` | delete the mapping | **no** |
| 9 | `apps/control_plane/lib/features/product_detail/product_detail_page.dart:471` | `'${c.referenceName} · ${c.algorithm} ${c.fingerprint} · '` | rewrite — `referenceName` is its **leading token** | **no** |
| 10 | `apps/control_plane/lib/features/product_detail/product_detail_page.dart:676` | `': ${c.referenceName} · ${c.algorithm} '` | rewrite | **no** |
| 11 | `apps/control_plane/test/product_detail_mobile_golden_test.dart:33` | `referenceName: 'GIT_PRODUCT_SHIPIT_REPO1_SSH',` | delete the named argument | **no — `CredentialResponse`'s constructor is `required`-parameterised**, so the fixture is a **compile error**, not a visual diff |
| 12 | `apps/control_plane/test/widgets/product_detail_page_test.dart:18` | `referenceName: 'GIT_PRODUCT_SHIPIT_REPO1_SSH',` | delete the named argument | **no — same** |

**THE COUNT, ONCE, and the three numbers Revision 4 gave are reconciled here (H10).**
**Twelve rows. Six files. Ten code edits plus two doc-comment edits.**

| | Count | Files |
|---|---|---|
| **Rows in table A** | **12** | **6** — `repository_credential_view.yaml` (rows 1–2), `ui_view_mappers.dart` (row 3), `control_plane_repository.dart` (rows 4–8), `product_detail_page.dart` (rows 9–10), `product_detail_mobile_golden_test.dart` (row 11), `product_detail_page_test.dart` (row 12) |
| Of which **code edits** | **10** | rows 1, 3, 4, 5, 7, 8, 9, 10, 11, 12 |
| Of which **doc-comment edits** | **2** | rows 2 and 6 — each *inside* a file already being edited (row 2 inside row 1's; row 6 inside row 5's) |

**What Revision 4 got wrong about its own count, stated so it is not repeated.** Revision 4 said *"twelve rows
covering eleven **edit sites** plus one doc-comment row"* in one place and *"ten code edits and two
doc-comment edits"* in another. **Eleven and ten cannot both be right**, and neither is the file count:
**"eleven" and "ten" were counts of *rows*, and the number that matters for a change list is *files*.** The
correct figures, each derived from the census above, are **12 rows / 6 files / 10 code edits / 2 doc-comment
edits**. **Revision 4's "eleven files" was wrong on all three counts** — it is six.

**The compile-breaking sites, which is why the file count is the operative one.** Rows 4, 11 and 12 all fail
for the same reason: `required this.referenceName` (`control_plane_repository.dart:1691`) means every
existing construction site must be edited in the **same commit** as the field's removal. A change list that
spans six files and has three compile errors in it is a list with an ordering constraint in it.
**A reviewer can check this claim by deleting the field and running `dart analyze` — and the design's point
is that the list must already be correct before anyone tries.**

**One number I still state differently from the finding, and why — this survives the correction.**
The finding said *"nine hand-written sites"*. I count **twelve rows across six files**. The difference is
that a *"site"* count folds the two doc-comment rows into the files they live in and so never exceeds the
file count, while a *row* count does not. **Both are defensible; the claim that matters is completeness, and
the list is complete and individually checkable** — which Revision 3's seven-row table was not: it had rows
1, 5, 6 and 7 bundling multiple sites, and it omitted rows 11 and 12 entirely. I keep the flag rather than
quietly adopting the finding's number, because the two documents will be compared side by side and a silent
divergence reads as an error in one of them.

#### B. Generated files — regenerated by `serverpod generate`, **not hand-edited**

| Package | Files | Note |
|---|---|---|
| `apps/server` | `lib/src/generated/repository_credential_view.dart`, `lib/src/generated/protocol.dart` | `protocol.dart` **does** change: it carries a `ColumnDefinition(name: 'referenceName', …)` at `:3840-3845` **[5436a4d]**, which the generator emits for every model field. `grep -c referenceName apps/server/lib/src/generated/protocol.dart` → **1**, and it is that `ColumnDefinition` |
| `packages/control_plane_client` | `lib/src/protocol/repository_credential_view.dart` **only** | **11** `referenceName` occurrences in the model alone (`:19`, `:25`, `:42`, `:62`, `:92`, `:125`, `:144`, `:171`, `:186`, `:207`, `:223`) — **corrected (H10): Revision 4 said "9" while listing ten line numbers, and the file has eleven hits.** `:19` is a doc comment (*"…is named only by `referenceName`…"*) and is the one the ten-item list omitted; it is stale prose and is regenerated away with the field |

#### C. Files Revision 3 listed or implied that **change not at all**

| File | Why Revision 3's treatment was wrong |
|---|---|
| `packages/control_plane_client/lib/src/protocol/protocol.dart` | **NO-OP — DROPPED.** `grep -c referenceName` → **0**. It is a *type* registry — `if (t == _i19.RepositoryCredentialView)` (`:164`), `case _i19.RepositoryCredentialView():` (`:533`), `if (dataClassName == 'RepositoryCredentialView')` (`:608`). It enumerates **classes, not fields**, so removing a field regenerates it byte-identically. It may still be rewritten by regeneration with a different import order; that is not a change to make or plan for |
| `packages/control_plane_client/lib/src/protocol/product_detail_view.dart` | **NO-OP — DROPPED.** It holds `List<RepositoryCredentialView> credentials`; the element type is named, not expanded. `grep -c referenceName` → **0** |

**Revision 4 marked `protocol.dart` NO-OP but left it in § B's package row, which is how a no-op becomes a
task (H10).** It is removed from the change list here, and the two package rows in § B now name **only files
that regenerate differently**: `apps/server`'s three and `control_plane_client`'s `repository_credential_view.dart`.

#### D. Files that are **not** in scope, and why

| File | Why it keeps the field |
|---|---|
| `apps/server/lib/src/database/repository_credential.spy.yaml:19` | this is the **`product_credential` table** definition, not the view. G-7 removes the field from the **wire**, never from the durable record — § R.1.3 requires the handle to be stored there |
| `apps/server/tool/schema_bootstrap.dart:509`, `apps/server/migrations/**`, `postgres_product_registry_store.dart` | same: the durable record and its schema keep `referenceName` |
| `packages/platform_contracts/lib/src/types/repository_credential.dart:72`, `.g.dart`, `packages/product_registry/lib/src/store/**` | the **domain type** keeps it. The domain must be able to resolve and destroy the handle (§ R.1.2, § R.6.1) |
| `packages/product_registry/test/credential_test.dart`, `apps/server/test/integration/**` | domain-level and store-level tests; they assert the invariant, not the wire |

**This is the "generated-contract change in two packages" the decision refers to: `apps/server` (the model
source plus its generated protocol) and `packages/control_plane_client` (the generated protocol).** All of
the above are `PROHIBITED_PATHS` for this lane — it writes none of them.

**What the client receives instead: nothing.** No substitute field is added. The client already holds
everything it legitimately needs, and `credentialId` is already the non-identifying handle it uses to
address the credential:

| Field already on the view | Why it is sufficient |
|---|---|
| `credentialId` | the handle every later action reuses — already an opaque server-generated id |
| `fingerprint`, `algorithm` | identifies *which* key is installed, which is what the operator needs |
| `status`, `hostKeyStatus`, `host` | the trust and lifecycle axes — and `status` is what makes § R.11.2's state 4 renderable |
| `canReachRepository` | the single fact ADR 0018 `:100-102` requires the UI to show |
| `lastVerifiedAt/By`, `lastFailureReason`, `hostConfirmedAt/By` | provenance |

### R.3.3 What must **not** replace it

The decision permits *"replace it with a non-identifying handle"*. I specify **removal**, and rule out
the two obvious substitutes, because both re-create the disclosure the decision closed:

- **No hash, digest or truncation of the handle.** A stable digest of a secret identifier is a stable
  identifier for the same secret: it enables correlation of one vault object across every product and
  repository in the deployment, and it survives a handle rotation in a way that defeats exactly the audit
  goal `ADR 0019 :49-51` serves (`AuditEntityType.productCredential`).
- **No prefix, suffix or redacted form.** `"credbind_****"` discloses the naming scheme, which *is*
  topology; the whole value of § R.1.3 is that the handle carries no structure to disclose.

If a future need appears for an operator-facing reference identifier, it is a **new, deliberately
non-derived** field with its own design revision — not a transformation of this one.

### R.3.4 What the boards and the client must never show

Binding on the sibling mobile lane (`C-11` — this lane authors no board and edits none):

- **No board may render a credential reference**, and in particular **no
  `GIT_PRODUCT_<productRef>_<repoRef>_SSH`-shaped token** — the shape ADR 0018 `:29-30` specifies and that
  two client fixtures still use (`product_detail_mobile_golden_test.dart:33`,
  `widgets/product_detail_page_test.dart:18`, both `GIT_PRODUCT_SHIPIT_REPO1_SSH`). Under A3 the column's
  *value shape* has changed anyway (§ R.1.3), so any board still showing that token is showing a stale
  design **and** disclosing a naming scheme. **Both of those fixtures are also compile-breaking** — § R.3.2
  rows 11 and 12.
- **No board may name the secret manager** — not its vendor, not its address, not *"the vault"*, not
  *"the keychain"*. The copy says *a* secret manager exists and that the private half is not in SHIP IT.
- Removing the field from the view changes rendered output at `product_detail_page.dart:471` and `:676`,
  so the **`product_detail` golden baselines must be regenerated** by the implementation/QA lane. **The
  regeneration must cover both fixtures in § R.3.2 rows 11 and 12**, and both supply a `referenceName`
  that disappears — so the goldens' *data* changes as well as their pixels. They are QA artifacts and are
  `PROHIBITED_PATHS` here. Flagged because it is an easily-missed consequence: a wire change that silently
  invalidates committed goldens surfaces as a *visual* regression, not a contract one.

---

## R.4 — The four-option substrate set is **WITHDRAWN**

Revision 2 § R.4 presented A1/A2/A3/A4 as options, with per-option ADR status and a confidence table.
That presentation existed only to let the human choose, and the choice is made. **This revision contains
no substrate option set, no `Q1`/`Q1′`, no confidence column, and no "if the human answers" branch.**
Carried from Revision 3 unchanged, which the reviewer confirmed.

| Revision 2 option | Disposition |
|---|---|
| **A3** external secret manager | **THE DESIGN.** § R.1.1–R.1.4, normative. |
| **A1** filesystem `0600` | **Documented fallback** with an explicit trigger condition — § R.1.5. Reachable only when no manager is *configured*. |
| **A4** host keychain / TPM | **Documented fallback** with an explicit trigger condition — § R.1.5. Reachability `UNVERIFIED` on the target. |
| **A2** envelope-encrypted table | **Excluded, permanently** — § R.1.6. ADR 0018 `:87-88` still binds it. |

§ R.16 reuse row #31 is *"NEW — decided by `9417f8bf` OPTION_C"*, and row #35 is **`none required`** (A3
stores a handle in an existing column, so no migration is needed for the substrate — worth stating, because
under the withdrawn A2 it would have needed one).

---

## R.5 — The degraded path: fail closed, with named remediation

**`7b1bc8b7` RESOLVED, OPTION_A.** If the substrate is unavailable or its protection cannot be verified,
**no keypair is generated and no credential row is created**, and the user is told the concrete operator
action. The decision states that the remediation copy *is* the deliverable that distinguishes this dead
end from human point 2d's rejected one. **It is therefore specified verbatim below, and it is a required
deliverable of this revision** (`SC-11`).

The decision also states the path is *materially more likely* under A3 than under a filesystem store.
This design treats it as an ordinary, frequently-exercised branch, not an edge case.

### R.5.1 The four trigger conditions — each distinguishable

| `substrateFailure` | Detected how | Distinct? |
|---|---|---|
| `secretManagerUnconfigured` | No manager endpoint configured in server configuration | yes — this is the **A1/A4 fallback** case (§ R.1.5), and its remediation is *"configure a manager"*, not *"fix the manager"* |
| `secretManagerUnreachable` | `verifyProtection` did not complete within the configured timeout | yes |
| `secretManagerProtectionUnverifiable` | The manager answered, but the reported protection does not meet `SecretProtectionPolicy`, **or the policy could not be evaluated** (missing capability, unsupported version) | yes — and note the *unevaluable* case is folded in deliberately: *"we could not check"* must not read as *"it is fine"* |
| `secretManagerWriteRefused` | `put` was refused by the manager (policy, quota, size) | yes — the manager's own reason goes to the audit log, never raw to the wire (§ R.5.3) |

### R.5.2 The mint sequence — **implemented as decided**, with the ordering corrected (H1, B2, H4)

**This section is no longer an interpretation awaiting confirmation (H4).** Revision 3 § 10.1 item 3 asked
the human to *"confirm or correct"* the ordering, because Revision 3 had escalated the interaction between
`7b1bc8b7` and `898b07d0` as undecided. **It was decided.** `ae1c1f79`
(`.decisions/ae1c1f79-338c-4d8f-97e0-452adaed021d.yaml`, **`status: RESOLVED`**,
`decided_at 2026-10-06T13:50:00Z`) **[5436a4d]** resolved the exact question Revision 3 raised:

> **OPTION_A — "Refusal creates nothing."** *"The substrate precondition is evaluated before any write. If
> it fails, no `Product` row, no `RepositoryReference` and no credential row are created, and the user is
> told the remediation."*

Its own context names this revision as the blocker: `blocking_work_item.item_id:
4B017787-25A0-4F45-ABDA-805C250AF63F` — Revision 3's id. **Revision 3's reading was taken up and adopted
unchanged**; `ae1c1f79`'s `recommended_option` was `OPTION_A` with `confidence: HIGH`, and its rationale is
Revision 3's argument. So what follows is **decided content, not a proposal**, and § 10.1 no longer asks
the human anything about it.

Two of `ae1c1f79`'s three follow-up actions are **mine**:

| Follow-up action | Owner | Where it is discharged here |
|---|---|---|
| *"Specify in Design Revision 3 that the substrate precondition is evaluated before the first write, and that no `Product`, `RepositoryReference` or credential row is created on refusal. Add a test that asserts **zero rows** after a refused mint — not merely that the credential row is absent."* | `design-agent` | § R.5.2's table + **`T-H`** |
| *"State the consequence for the mobile boards: after a refused mint the Products list is unchanged, so the Unknown-host state must not imply that a product was created."* | `design-agent` (coupled to `design-addproduct-mobile`) | **§ R.11g item 5 — new** |
| *"Implement the precondition check ahead of the first write, and cover it with a test proving a refusal leaves `Product` and `RepositoryReference` counts unchanged."* | `implementer` | § 10.1 item 4 |

**The normative rule, unchanged and now decided:**

> **The substrate precondition is evaluated before the flow writes anything, so a substrate refusal
> creates no `Product` row, no `RepositoryReference` row, no credential row, and no keypair.**

**The mint sequence, in order, with the failure window made explicit.** Step 1 is corrected (H1):

| Step | Action | Key material in existence? | On failure |
|---|---|---|---|
| 0 | `verifyProtection(policy)` — **before any write** | **no** | refuse; nothing written |
| 1 | **derive `host` by parsing the endpoint's own `repositoryUri` parameter** — a `Uri` parse of a value the caller supplied in this request. **No row is read, and none may be**: at this point no `RepositoryReference` exists on a first mint (§ R.14.1 step 3 creates it) | no | refuse (`repositoryUriUnparseable`); nothing written |
| 2 | *(reserved — see § R.5.2.1)* | — | — |
| 3 | **get-or-create** `Product` (`registered`) + `RepositoryReference` — **read first; write only when the row is absent** (§ R.14.1, and `G-13`) | no | refuse; nothing written |
| 4 | generate the keypair **in memory** | **yes, in process memory only** | — |
| 5 | `put(privateHalf)` → handle | yes | zero the buffer; **no handle exists, so there is nothing to destroy**; refuse (`secretManagerWriteRefused`) |
| 6 | `recordGeneratedCredential(..., referenceName: handle)` — **passing no caller-supplied `credentialId`** (normative; § R.8.2) | yes, in memory | **compensate** per **§ R.5.7** |
| 7 | zero the buffer; return the public half | no (only the public half) | — |

**What changed at step 1, and why it was a real defect (H1).** Revision 3's step 1 read *"derive `host`
from `RepositoryReference.uri`"* and its step 2 *"create `Product` + `RepositoryReference`"*. That ordering
is **unsatisfiable**: the row step 1 reads is the row step 2 creates. § R.14.1 already had it right — it
derives from the endpoint's `repositoryUri` parameter — so Revision 3 stated the same step two different ways
in two normative locations, and one of them cannot be implemented. **The rule is now stated once, here, and
§ R.10.1 and § R.14.1 both point at it.** The derived `host` is written to `RepositoryReference.uri` **and**
to the credential's `host` field in the same step 3, so the two cannot diverge.

#### R.5.2.1 Why step 2 is reserved rather than numbered away

The sequence has seven steps and one gap, because **§ R.5.7's compensation construct sits between step 6
and step 7** and is named there rather than inlined. A reader implementing this should treat steps 5–7 as
one block, entered only after step 4 has produced a buffer, and exited only through § R.5.7.

**Step 6's compensation is mandatory, and it is the reason the ordering matters.** Without it, a failure
between `put` and the row write leaves a live private half in the manager that **no row points at** — an
unmanaged key that no revocation can ever reach, which is the exact class of orphan `79e860e2` exists to
eliminate. Any implementation that cannot compensate must instead order `put` after the row write, and
**that order is forbidden**: it would put a row pointing at a handle that may not exist, so a later push
would fail in a way that looks like `secretReferenceMissing` rather than like a failed mint.

**On "no keypair is generated".** Steps 4→5 are the only window in which material exists, and it is
process memory that is zeroed and dropped on every failure path. A *literal* *"never generate a keypair"*
is not achievable and cannot have been what the decision meant — generating and then refusing to store
would itself create the unmanaged key the decision forbids. I record this interpretation explicitly so it
is reviewable rather than smuggled. It is consistent with `ae1c1f79`, whose `quantitative_data` counts *"0
credential"* for both readings and whose question was about the **`Product` row**, not about generation.

### R.5.3 The refusal, on the wire

| Property | Value |
|---|---|
| HTTP | **503** |
| Wire `failureKind` | `substrateUnavailable` (presentation-layer enum, § R.13.2 — the **domain** vocabulary is unchanged) |
| Body | `{ failureKind, remediation: { title, body, action, substrateFailure }, retryable: true }` |
| State written | **none**, at any tier — asserted by `SC-11` / `T-H` |
| Audit | one `AuditEntityType.productCredential` event recording the attempt, the `substrateFailure` kind, and **no** handle |
| Typed exception | `SecretSubstrateUnavailable(substrateFailure, remediationAction)` in `apps/server` — **not** in `packages/product_registry` (`C-02`, § R.1.7) |

**Deliberately coarse.** One wire `failureKind` with four server-side discriminators, so an
unauthenticated caller (§ R.15) cannot use the endpoint as an **oracle** for whether a manager exists,
where it is, or how its policy is configured. The four discriminators are for **operators and logs**, not
for clients.

### R.5.4 The remediation copy — **required deliverable, specified verbatim**

Every string below is **`palette.inkSecondary`**, never `inkTertiary` (`N-8`, § R.10.2): `inkTertiary`
measures 4.23:1 on the card surface in dark and **fails WCAG AA**, and it is the current idiom for exactly
this kind of helper text (`add_product_page.dart:542`, `:590` **[5436a4d]**). Rendered on the card surface,
one column, no truncation of the action line.

---

**`substrateFailure: secretManagerUnconfigured`**

> **Title** — SHIP IT has nowhere safe to put this key, so it will not create one
> **Body** — This deploy key is **not** created. SHIP IT never generates key material it cannot store
> safely, and no secret manager is configured for this installation. Nothing has been saved for this
> product.
> **Action** — Ask the operator of this SHIP IT installation to configure a secret manager
> (`SHIPIT_SECRET_MANAGER_ENDPOINT`), or to record that this installation runs the documented
> single-host fallback. Then select **Generate** again.

**`substrateFailure: secretManagerUnreachable`**

> **Title** — SHIP IT cannot reach the secret manager, so it will not create this key
> **Body** — The deploy key for this repository is **not** created, and no credential is saved. No key
> exists yet, so nothing needs cleaning up.
> **Action** — Confirm the secret manager is running and reachable **from the SHIP IT server** (name
> resolution, network policy, TLS trust), then select **Generate** again. The exact endpoint SHIP IT
> tried is recorded in the audit log for this attempt.

**`substrateFailure: secretManagerProtectionUnverifiable`**

> **Title** — SHIP IT cannot confirm how the secret manager protects this key
> **Body** — A deploy key is only created once SHIP IT can confirm where the private half will be held and
> that only this installation can read and delete it. That check could not be completed, so no key was
> generated and no credential was saved. This is deliberately **not** treated as *"probably fine"*.
> **Action** — Ask the secret manager's operator to confirm that encryption at rest is enabled and that
> this installation's identity may read **and delete** secrets in the credential path, then select
> **Generate** again.

**`substrateFailure: secretManagerWriteRefused`**

> **Title** — The secret manager refused to store the private half
> **Body** — SHIP IT generated nothing it could not store, so no key exists and no credential was saved.
> The manager's own refusal reason is recorded in the audit log.
> **Action** — Read the refusal reason in the audit log for this attempt, correct the manager's policy or
> quota, then select **Generate** again.

---

**Four copy obligations that apply to all four:**

1. **Each names the operator action, and the action is one a human can perform.** This is the whole
   point of the decision, and the test is: *can someone who is not an engineer, acting on this sentence
   alone, do the thing it names?* *"Check that the secret manager is reachable from the server"* passes;
   *"check your secret configuration"* does not.
2. **Each states that nothing was created.** A user who has been told *"not created"* and then finds a
   half-built product has been told something false — and under § R.5.2 no product is created either.
3. **Each offers retry, and says what retry will and will not have left behind.** Retry is safe
   precisely because § R.5.2's compensation makes it so, so the copy may say so.
4. **None of them overclaims, and one says so explicitly.** This is ADR 0018 `:99` — *"ShipIt does not
   claim to have verified a host it cannot verify"* — applied to the substrate rather than the host. The
   `secretManagerProtectionUnverifiable` body states the unevaluable case plainly rather than implying a
   check that did not happen.

**One failure has no mint-time copy**, because it cannot occur at mint: `secretReferenceMissing` — the
handle resolves to nothing, i.e. the manager object was deleted out of band. That is a **push-time**
failure and its copy is specified in § R.13.2.

### R.5.5 Consistency with the four existing credential refusals

The decision asks that consistency be stated. There are **four** existing credential refusals, all in
`packages/product_registry/lib/src/exceptions.dart` **[5436a4d]**, all `implements Exception`, all with
typed fields and a `toString()`:

| Existing | Location **[5436a4d]** | Shape | Why the new one is consistent |
|---|---|---|---|
| `CredentialNotFoundException` | `:201` | `(String credentialId)` | the substrate refusal is **not** this: nothing was created, so there is no id. It is a new type, and the distinction matters — *"not found"* is a **query** outcome, the substrate refusal is a **precondition** outcome. |
| `CredentialNotUsableException` | `:215` | `(String credentialId, String reason)` | already the catch-all the store raises for a refused credential write. The substrate refusal is **not** this type either: it happens **before** a credential exists, so a `credentialId` argument would be a fiction. |
| `HostKeyNotConfirmedException` | `:232` | `(String host, HostKeyStatus status)` | the closest analogue, and the precedent that matters: `credential_status.dart:48-50` fails closed because *"this is indistinguishable from an interception"*. The substrate refusal uses the same reasoning — **an unverifiable store is indistinguishable from an unsafe one**. |
| `CrossProductAccessException` | `:59` | `(String message)` | not applicable. |

**Therefore the new refusal is a new type, `SecretSubstrateUnavailable`, and consistency requires four
specific things:**

1. **It fails closed**, exactly like `HostKeyNotConfirmedException` — no partial state, at any tier.
2. **It carries the remediation action as data**, so the client renders server-supplied copy rather than
   inventing its own. This mirrors how `HostKeyNotConfirmedException`'s two `status` values drive two
   distinct `toString()` messages (`exceptions.dart:238-246`) — **the cause is a field, not a subclass per
   cause**. One type, four discriminators.
3. **It does not enter `packages/product_registry`.** The four existing refusals live there because they
   are *domain* refusals; the substrate is outside the domain (`C-02`, § R.1.7), and its exception belongs
   to `apps/server`. Surfacing it through the domain would put a secret-manager concern in a package whose
   stated contract is that it never sees one — and it is the reason § R.5.7's construct is application-layer
   code.
4. **It must be mappable to the wire without leaking.** The existing exceptions are safe to render
   because they carry domain ids and reasons. The new one carries a remediation string, so § R.5.3's
   coarse single `failureKind` is what keeps it from becoming an oracle.

### R.5.6 The accepted dead end, stated rather than smoothed

`7b1bc8b7` accepted that refusing is *"a dead end — the same shape as human point 2d"*, on the grounds
that the remedy is a concrete operator action rather than a missing UI affordance. Two consequences a
reviewer should check rather than take on trust:

- **The user is blocked, and the block is not self-clearing.** There is no path forward that does not
  involve an operator. That is correct, and it is also worse than the pre-A3 world, where a local
  filesystem substrate could not be down. § R.15.3 states the resulting availability risk.
- **The way out still exists** (§ R.12): the user can leave, and because nothing partial was created
  (§ R.5.2, `ae1c1f79`), re-entry re-runs step 0 and re-mints from scratch with a **new** keypair. Because
  § R.9's `D-4` forbids re-minting an existing identity, a re-mint after a substrate failure is a genuinely
  new credential — correct, since the previous attempt produced no key at all.

### R.5.7 The compensation construct — **stated once, used verbatim (B2)**

**The defect this replaces.** Revision 3 said the compensation was *"**`destroy(handle)` in a `finally`**"*
(§ R.5.2 step 5) and *"**inside a `try`, with `destroy(handle)` in the `finally` on any failure**"* (§ R.14.1
step 5). **Dart has no failure-only `finally`.** `finally` runs on every exit path, so on the literal
reading of both sentences the **success** path destroys the handle it has just recorded — producing exactly
the forbidden state § R.5.2 names: a row pointing at a handle that no longer exists, which later looks like
`secretReferenceMissing` rather than like a successful mint. **A design that specifies a construct which
cannot express the requirement it specifies is a defect regardless of intent**, and this is that.

**The construct.** Two forms are acceptable; **the required behaviour is identical**, and it is the
behaviour, not the syntax, that is normative. **Both forms below are now correct on every path, including
the path where `put` itself throws** — which is what Revision 4's FORM 2 got wrong (H8).

```dart
// ── FORM 1 — success flag. Preferred: it reads top-to-bottom in the order the effects happen.
String? handle;
var recorded = false;
try {
  handle = await provider.put(binding, privateHalf);            // step 5
  await engine.recordGeneratedCredential(                        // step 6
    productId: productId,
    repositoryId: repositoryId,
    referenceName: handle,          // no caller-supplied credentialId (§ R.8.2)
    publicKey: publicHalf,
    fingerprint: fingerprintOf(publicHalf),
    host: host,                     // derived in step 1, written in step 3
  );
  recorded = true;                  // ◀── the ONLY statement that keeps the handle alive
} finally {
  if (!recorded && handle != null) {
    await destroyQuietly(handle);   // best-effort; never rethrows — see obligation 3
  }
  zero(privateHalf);                // EVERY path, success included
}

// ── FORM 2 — catch, destroy, rethrow, and zero in a `finally`. Equivalent to FORM 1.
String? handle;                      // null when `put` itself threw
try {
  handle = await provider.put(binding, privateHalf);
  await engine.recordGeneratedCredential(/* … */ referenceName: handle);
} catch (error, stack) {
  if (handle != null) {
    await destroyQuietly(handle);    // best-effort; never rethrows — see obligation 3
  }
  rethrow;                           // Dart's bare `rethrow` — preserves error AND stack trace
} finally {
  zero(privateHalf);                 // ★ obligation 4 — EVERY path, success included (H8)
}
```

**Why FORM 2 is now a `finally` and was not (H8).** Revision 4's FORM 2 was:

```dart
final handle = await provider.put(binding, privateHalf);   // ✗ outside any try
try {
  await engine.recordGeneratedCredential(/* … */ referenceName: handle);
} catch (error, stack) {
  await destroyQuietly(handle);
  rethrow;                                                 // ✗ ends here
}
zero(privateHalf);                                          // ✗ UNREACHABLE after rethrow
```

**Two defects in three lines, both of them obligation 4 violations and one of them a `null`-handle crash:**

1. **A `put` throw propagates past `zero(privateHalf)` entirely.** `put` is outside the `try`, so the
   exception never reaches the trailing `zero` and the buffer — the only copy of a freshly generated private
   half — stays live in a long-lived object. **Obligation 4 says "zeroed on every path, success included",
   and § R.5.7 states the required behaviour is identical between the two forms.** Revision 4's FORM 2
   violated its own obligation 4 on the `put`-throws path while its prose claimed otherwise.
2. **The trailing `zero` is unreachable after `rethrow`.** Not *equivalent* to FORM 1 — strictly worse.

The rewrite above fixes both with **one** mechanism: **`finally` runs on every exit path, including a
`rethrow`**, so obligation 4 becomes structural rather than a statement someone has to remember to place
after the last exit. **`catch` keeps the `destroy`; `finally` keeps the `zero`.** They are not
interchangeable — moving `destroy` into the `finally` would re-introduce B2, because `finally` also runs on
the success path.

**And the `null` guard, because Revision 4's sample and its normative sentence disagreed.** Revision 4's prose
said:

> *"**What `destroyQuietly` must do when the handle is `null`** — the case where `put` itself failed: nothing.
> There is no manager object to remove, so the call is skipped, **not** made with a null argument."*

while FORM 1's `finally` called `await destroyQuietly(handle)` **unconditionally** inside `if (!recorded)` —
which is reached with a `null` handle **exactly** when `put` throws, because `recorded` is still `false` and
`handle` was never assigned. **The sample and the sentence disagreed, and the sample was the one an
implementer copies.** Both forms now guard on `handle != null`, so the sample and the normative sentence
agree. § 10.2 item 1 now checks obligation 4 on **both** forms, and this guard with it.

**The required behaviour — five obligations, each one testable:**

| # | Obligation | Why, and what it forbids |
|---|---|---|
| **1** | **The handle is destroyed if and only if the credential row was not recorded.** `recorded` is set **after** `recordGeneratedCredential` returns, and nowhere else | this is the whole requirement. It forbids a bare `try { … } finally { destroy(handle); }` around the mint, which is what Revision 3 specified |
| **2** | **On the success path the handle survives, and it must be resolvable.** `T-I` (§ R.9.6) asserts `resolve(handle)` returns the material immediately after a successful mint | a mint that records a handle the manager cannot resolve has produced § R.5.4's `secretReferenceMissing` at push time — a credential that is born broken. **This is the counterpart `T-H` lacked**, and its absence is why the success path went unchecked |
| **3** | **`destroy` on the failure path is best-effort, and its own failure is audited, never rethrown** | a `destroy` that throws inside a `finally` **replaces** the original error, so the caller sees a manager error instead of *"the row write failed"* — the exact diagnostic loss `AGENTS.md`'s test-resource-hygiene rule warns about in the teardown case. `destroyQuietly` catches, audits the `substrateFailure`, and returns |
| **4** | **The private-half buffer is zeroed on every path, success included**, and `put`'s contract requires the caller to zero it (`§ R.1.2`) | zeroing only on failure leaves the buffer live in a long-lived object after a *successful* mint |
| **5** | **The construct is application-layer code** (§ R.1.7). `SecretProvider` is never reachable from the engine | obligation 3's audit call and the substrate exception are both `apps/server` types; putting this code in `packages/product_registry` would put both there |

**Ordering inside the failure path, normative:** `destroy(handle)` **first**, then `zero(privateHalf)`.
The reverse would destroy the only copy of the bytes before handing the handle to the thing that must
delete it — and the `destroy` call itself needs no bytes, so zeroing first buys nothing and risks a
mid-`destroy` failure losing both.

**What `destroyQuietly` must do when the handle is `null`** — the case where `put` itself failed: nothing.
There is no manager object to remove, so the call is **skipped, not made with a null argument** — and **both
forms above now guard on `handle != null`**, so the normative sentence and the sample agree (H8; this was the
sample/sentence disagreement noted above). This is § R.5.2 step 5's failure column, and it is why that column
says *"no handle exists, so there is nothing to destroy"* rather than *"compensate"*.

**Where this is used — the step numbers corrected (L5).** § R.5.2 **step 6**, § R.10.1 **step 4** and
§ R.14.1 **step 6** all **reference this section and reproduce no variant of it**. (Revision 4 wrote *"§ R.10.1
step 3"*, which is the get-or-create step; the mint, and therefore the compensation, is step 4 of that
machine.) **The substantive claim the finding did not dispute holds: the construct appears in exactly one
place, with three references and no variant** — which is what B2 required. If an implementation needs a
different shape, that is a deviation from this section and must be reported as one — not silently
re-derived at a second call site, which is how Revision 3 produced two sentences that disagree.

---

## R.6 — Revocation is two-sided

**`79e860e2` RESOLVED, OPTION_A**: destroy the private half on revoke, keep the row. Under A3 *"destroy"*
means **deleting the manager handle**. **ADR 0018 `:113-114` is superseded** (§ R.17).

### R.6.1 Required behaviour, and its order — which is load-bearing — and where it runs (H7)

**This pseudocode is `apps/server`, not the engine.** The four steps and their order are normative; the
attribution is the correction the finding asked for. § R.1.7 gives the composition root and explains why
the engine's participation is exactly one read and one CAS write.

```
// apps/server — the revocation endpoint (or the service beside it). NOT ProductRegistryEngine.
revokeRepositoryCredential(productId, credentialId, reason)   // § R.14.3
  1. c = engine.readProductCredential(credentialId)   // domain read; _ensureOwned is the engine's job
     if c.status == revoked → return unchanged (idempotent)
  2. await provider.destroy(c.referenceName)         ← FIRST   (apps/server holds the provider)
  3. updated = c.copyWith(status: revoked, revokedAt, revokedReason, version+1)
  4. engine.revokeCredential(productId, credentialId, reason)   // domain write, CAS
```

**The engine's `revokeCredential` (`engine:1072-1090`) is step 4, unchanged.** It reads, enforces
ownership, early-returns if already revoked, `copyWith`es and CAS-writes. **It has no `SecretProvider` and
is given none** (§ R.1.7, obligation 1). `79e860e2` is delivered by the **ordering between step 2 and
step 4**, which lives in the application layer because the substrate does.

**The manager handle is deleted before the row is marked revoked, and this ordering is normative.**

| Failure at | Result | Safe? |
|---|---|---|
| step 2 fails (manager unreachable / refuses) | the row is **not** marked revoked; the refusal surfaces with the § R.5.4 remediation | **yes** — marking the row revoked without destroying the material would assert a security property that does not hold. This is `7b1bc8b7`'s posture applied to revocation. |
| step 4 fails, after step 2 succeeded | a **live** row whose material is destroyed | **yes, and recoverable** — `destroy` is idempotent (§ R.1.2), so a retry re-issues it harmlessly and then marks the row. Until the retry the row over-claims usability; `canReachRepository` is false in fact and the failure is loud, not silent. |

The reverse order is the dangerous one and is **forbidden**: mark the row revoked first, and a failed
`destroy` leaves a **revoked row with a live private half** — a credential the operator believes is dead
and which still authenticates to the repository.

**Rotation is unaffected**, because `rotateCredential` revokes first and mints second (`engine:1098-1133`),
so the old row leaves `D-2`'s partial unique index before the replacement enters it. Under A3 rotation
additionally means the old handle is destroyed before the new one is written, so a rotation failure leaves
no half-rotated credential — and, because `rotateCredential` needs no new domain method, § R.1.7's
decomposition leaves it working unchanged.

### R.6.2 The row is retained — C-1 does not contradict the retention test

- `revokeCredential` (`engine:1072-1090`) is `readProductCredential` → `_ensureOwned` → early return if
  already revoked → `copyWith(status: revoked, revokedAt, revokedReason, version+1)` →
  `saveProductCredential(…, expectedVersion: c.version)`. **It never deletes the row.**
- `credential_test.dart:310` **[5436a4d]** — *"revoked credentials stay readable, never deleted"* —
  asserts `readActiveCredential` returns `null` **and** `readCredentials` returns the row with
  `revokedReason` preserved.
- `apps/server/test/integration/product_credential_immutability_postgres_test.dart:15-39` runs the
  immutability proofs against **real PostgreSQL** *"because the two defects it covers are properties of the
  database and cannot be demonstrated by an in-memory map"* **[5436a4d]**.

**Destroying the private half does not contradict that test, because the test asserts the *record*, not
the *bytes*.** Under A3 this is cleaner still: SHIP IT never held the bytes to destroy, so there is
nothing for the record to disagree with.

**One consequence for § R.11.2, stated here so it is not discovered twice.** `readCredentials(productId)`
(`engine:1144-1145` → `readCredentialsForProduct`) returns **every** credential including revoked ones, and
its store contract already says so: *"Every credential ever issued for [productId], including revoked ones,
so the historical record stays readable"* (`product_registry_store.dart:78-82` **[5436a4d]**). **The data
§ R.11.2 needs already exists and is already contracted.** The read path simply does not use it.

### R.6.3 What revocation now **depends on** — and one of those dependencies is not built

`revokedAt`/`revokedReason` are only trustworthy if **no write can clear them**. Two facts, and the second
is a live defect:

- `"revokedAt" = @revokedAt, "revokedReason" = @revokedReason` are in `$assignments`
  (`postgres_product_registry_store.dart:226-240` **[5436a4d]**) — i.e. they are in scope of the
  conflict-branch update.
- **The conflict branch can be reached for a revoked row**, and doing so clears them. This is finding
  **M-3** / `D-18` and its derived consequence **§ R.9.2** — including the fact that it produces a revoked
  credential resurrected into the active set whose **manager handle has already been destroyed** by
  § R.6.1.

So: **§ R.6's semantics are only actually delivered once `D-4` (§ R.9.1) is built.** Until then,
revocation is best-effort against a reachable public API. That is stated here because `79e860e2`'s
follow-up action tells the implementer to *"test that a revoked credential cannot reach the repository"* —
and **that test fails until `D-4` lands**, because the resurrection path leaves a `generated` row in the
active set.

**Correction to this section, and it matters (H3).** Revision 3 asserted the clearing "follows from
reading `$assignments` against `readActiveCredentialForRepository`" and left the *shape* of the fix
unstated, extending `D-4` to the CAS branch *"to the mutable set too"* with no construct. **That is not
implementable as written**, because `revokeCredential` legitimately **sets** `revokedAt` and
`revokedReason` through that very branch (`engine:1082-1088`). A predicate that forbids touching those
columns would break revocation. **The requirement is therefore split**, and the second half is now its own
named deliverable: `D-4` governs the **mint** branch, `D-6` governs the **CAS** branch, and `D-6`'s rule is
**"may SET, must not transition non-null → null"** — § R.9.4.

---

## R.7 — Transport exposure — carried, with the threat model's A3 row added

Revision 1 § R.7 is carried **verbatim and in normative voice**. Normative constraints:

- The private half **must never** be returned by any endpoint, serialised into any wire type, logged,
  included in an exception message, or exposed to a `Session`.
- Under A3 it is readable **only** by the transport component, immediately before a transport attempt, for
  the minimum time needed, and never cached in a long-lived field. It is never written to disk inside the
  work tree (ADR 0015 `:29-31` puts `WorkspaceDescriptor` outside the worktree; the same rule applies
  here).
- Every read is an auditable event (`AuditEntityType.productCredential`, `audit_entity_type.dart:8`).

**Two additions under A3, both consequences the decision forces:**

1. **The handle must never be logged either.** `resolve(handle)` names a live secret. The audit event for a
   push records the `credentialId`, not the handle — the same rule ADR 0020 `:137`'s `EvidenceRedactor`
   already applies to `private_key`/`secret`/`token`/`signing_key`, extended to this field.
2. **The secret manager's address is infrastructure, not a client fact.** It appears in operator-facing
   remediation (§ R.5.4) and in server logs. It must not appear in any wire response — § R.5.3's
   deliberate coarseness.

### R.7.1 Threat model

| Asset at risk | Reachable by | Today **[5436a4d]** |
|---|---|---|
| The private half | **Only** the secret manager, plus the transport process for the duration of one attempt | A3 is the right answer to this row: SHIP IT holds none |
| **The handle** (an opaque secret identifier) | Anyone who reaches the **live database** with the **committed default credentials**; **every client**, until G-7 lands | `docker/compose.yaml:63`, `:16-17`; `.env.example:16-18` **[5436a4d]** — **unchanged**. § R.1.3 removes topology disclosure from the handle's value; it does **not** remove the database's exposure |
| Host-key trust **at the domain layer** | — | **enforced**, and this revision corrects Revision 3's over-broad claim: `recordCredentialCheck` and the pre-push `requireUsableCredential` both throw `HostKeyNotConfirmedException` unless `hostKeyStatus.permitsConnection` (`engine:1047-1052`, `:1162-1167`), and `canReachRepository` requires a confirmed host (`repository_credential.dart:128-129`) |
| Host-key trust **at the transport layer** | **nothing enforces it** — no `known_hosts`, no `StrictHostKeyChecking`, no `IdentityFile`; `git_workspace_inspector.dart:106-112` runs `Process.run` with no `environment:` | the **ADR 0018 `:96-99` gap** `G-4` — § R.10.3 |
| The manager's reachability | Anything that can make it unreachable | **New under A3.** § R.15.3 |

**The load-bearing conclusion, restated for A3:** custody has moved off SHIP IT, but the *identifier* that
points at the material did not, and that identifier now sits in the least-protected component in this
topology. A3 is still the right answer — it removes the bytes from every path that can read the database —
but it does not make the database safe, and a design that implied otherwise would be misleading. G-7
(§ R.3.2) removes the second half of the exposure.

**And the host-key row is now split, because the split is the finding.** The domain refuses to *record*
trust it does not have and refuses to *hand out* a credential for an unconfirmed host. The **connection
itself is unverified**, because no transport code asks git to check anything. A single row saying
*"nothing enforces host-key trust"* would be **false about the domain and true about the transport**, and a
reviewer who found the domain enforcer would reasonably distrust the rest of the table.

---

## R.8 — The store invariant is real. What now rests on it.

The credential-store-integrity work is merged into `main` at **`e391c02`**, which carries the implementation
at **`07c8c8f`**. **Both are ancestors of this revision's base** (§ 0.3) — so unlike Revision 3, this
section cites work a reviewer can read in this worktree. `4d2c6b81` resolved **OPTION_A**, so the index
reaches deployed databases.

### R.8.1 What landed — verified by reading it, not by running it

**`D-1` — key-material immutability, in the statement, on both branches.**
`postgres_product_registry_store.dart` **[5436a4d]**:

- **CAS branch** — the `UPDATE` carries `AND "publicKey" = @publicKey AND "fingerprint" =
  @fingerprint AND "algorithm" = @algorithm AND "referenceName" = @referenceName` alongside the version
  CAS. It reads the row back to distinguish *re-pointed key material* from *lost race*, so the caller is
  told **which** invariant it broke.
- **Upsert branch** — `INSERT … ON CONFLICT ("credentialId") DO UPDATE SET $assignments WHERE
  <the same four predicates> RETURNING "credentialId"`. The comment states why `RETURNING` is the
  detection mechanism: a filtered-out row returns nothing, and an empty result is unmissable (`:306-310`).
- SQLSTATE `23505` **and** the constraint name `product_credential_active_repository_unique` are both
  translated into a typed refusal (`:332-347`).

**`D-2` — one active credential per repository, in both homes.** The partial unique index
`ON "product_credential" ("repositoryId") WHERE "status" <> 'revoked'` is in **both**
`apps/server/tool/schema_bootstrap.sql` (the fresh-database path) **and** the migration
**`apps/server/migrations/20261006150645000/migration.sql`** (the chain-replayed / deployed path), with the
index name in `verify_schema_bootstrap.sh`'s `required_objects`. That last half is `4d2c6b81`'s subject and
it is done.

**Its predicate is identical to the predicate that defines "active" in the read path** —
`readActiveCredentialForRepository` selects `WHERE "repositoryId" = @repositoryId AND "status" <>
'revoked'` (`postgres_product_registry_store.dart:370-381` **[5436a4d]**; `in_memory:220-231` **[5436a4d]**
for the other tier). So the constraint and the query **cannot contradict** — which was the justification in
Revision 2 § R.15b.2 and it still holds.

### R.8.2 B6's structural kill — honestly, in three mechanism classes

| Class | Mechanism | Status **[5436a4d]** | What it actually buys |
|---|---|---|---|
| **A — persistence** | `D-1`: material immutability in the statement, both branches | **REAL** | A write that changes `publicKey`/`fingerprint`/`algorithm`/`referenceName` on an existing `credentialId` updates **nothing**. |
| **A — persistence** | `D-2`: partial unique index on the active set, two homes | **REAL** | Two concurrent mints cannot both insert. The loser gets `23505` + the index name, translated to a typed refusal. |
| **B — application** | Endpoint get-or-create; **no caller-supplied `credentialId`** | **NOT YET WRITTEN** — a property of code that does not exist | Removes the *accidental* re-mint from the UI. A caller that skips it is still protected by class A. |
| **B — application** | The engine's one-active guard (`engine:954-961`) | Holds, **conditionally** | A refusal of a second **row**, keyed on `supersedesCredentialId`. Not an immutability guard. |
| **C — in-memory only** | `copyWith` cannot change the four immutable fields | True, and **still worth nothing at the boundary** | Zero protection on the statement that persists the row. |

**Honest status of `R-B6`** (*"each press silently rotates the key the user just installed"*):

- **The original defect is closed at the persistence layer.** Any write that changes the key material of
  an existing `credentialId` now changes nothing. Any mint that creates a *new* `credentialId` for a
  repository that already has an active credential now hits `D-2`.
- **It is closed conditionally on one application requirement**: that the mint endpoint passes **no
  caller-supplied `credentialId`** (`credentialId` is a caller parameter at `engine:934`;
  `store:212-219` carries it into `$cols`). That is a design obligation, not code, which is why § R.14.1
  step 6 keeps it normative.
- **The family of state-loss defects around it is NOT closed.** `D-1`'s predicate is *satisfied by
  identical values*, so an identical-material re-mint still upserts and still resets state — § R.9.1. And
  `repositoryId` is still rewritable — § R.9.3. `D-1` named four fields; the **set** of things a mint must
  not touch is larger, and this revision specifies it, per tier.

Revision 2's sentence — *"two mechanisms, not four, and not independent"* — is **restated, not
withdrawn**: two of its four were properties of unbuilt code, and the two that mattered were not
independent of the boundary. The count that is now true is **two persistence mechanisms, both real, plus
one application requirement** — and the state-loss family is open.

### R.8.3 What now rests on the invariant — itemised, so a reviewer can check each

| Requirement | Rests on | Why it holds / what breaks if it does not |
|---|---|---|
| `SC-02`, `SC-03`, `T-A`, `T-B` | `D-1`, `D-2` | `T-A`/`T-B` exist and are reported passing by the implementer's report at `07c8c8f`. **Not re-verified by this lane — no test was run** |
| § R.14.1 step 7 — concurrent mints resolve on **D-2's** unique violation | `D-2` | Revision 2 rewrote this off the engine's one-active exception **because that exception would not fire**. It still would not. The `23505`-plus-index-name translation is what makes it resolvable |
| § R.12 — *"the key is still the same key"* | `D-1` | The restored key is byte-identical only because the material cannot have changed |
| § R.14.1 step 6 — mint passes no caller-supplied `credentialId` | application requirement, **not** `D-1` | Stated as normative precisely because `D-1` alone does not remove the route |
| `rotateCredential`'s revoke-then-mint ordering | `D-2` | The old row must leave the active set before the new one enters it, or the index refuses the rotation (`engine:1098-1133`) |
| **§ R.6 revocation's two-sidedness** | **`D-4` + `D-6` — not built** | § R.6.3. `revokedAt`/`revokedReason` are clearable today, and only a *transition* to null is forbidden once `D-6` lands |
| § R.10's `N-7` (host confirmation is durable) | **`D-4` + `D-6` — not built** | An identical-material re-mint nulls `hostConfirmedAt`/`hostConfirmedBy` today (§ R.9.1) |
| § R.9.4 `D-6`'s "`N-7` is durable" claim | **`D-6` — not built** | Same, on the CAS branch |
| `G-9` — ADR 0018 A1's one-per-repository invariant | `D-2` — **CLOSED** | Was `OPEN` in Revision 2. It is a database invariant now, in both homes |

### R.8.4 Blast-radius accounting for the changes this revision specifies — **complete (B3, M1)**

Revision 3's blast-radius accounting named G-7's sites and said nothing about the **server-side** changes
§ R.11.2 requires, and did not list the duplicate-credential audit anywhere but prose. Both are fixed here.
**Every row is a file a reviewer can open; nothing is summarised.**

| # | Change | Files | Tier | Owner | In this revision |
|---|---|---|---|---|---|
| 1 | **G-7** — `referenceName` off the wire | **twelve rows across SIX files** — see § R.3.2 § A | wire / client | implementation + QA | § R.3.2 |
| 2 | **`G-14`** — revoked credentials reach `loadProductDetail` | `apps/server/lib/src/services/control_plane_service.dart:360-367` (**1 method**), plus its test | **service** | implementation | **§ R.11.2** |
| 3 | **`G-14`'s test fixture** | the `product_detail` fixtures that assert `credentials.length` — **I have not enumerated them**; the implementer must grep `credentials:` and `length` in `apps/server/test/**` and `apps/control_plane/test/**` and report the count. **Stated as un-enumerated rather than guessed** | test | implementation | § R.11.2 |
| 4 | **`D-4`/`D-5`/`D-6`** | Postgres store, in-memory store, store contract doc, `credential_test.dart`, `product_credential_immutability_postgres_test.dart` | **store, both tiers** | implementation | § R.9 |
| 5 | **`SecretProvider` + the composition root** | `apps/server/lib/src/secret/**` (new), the mint endpoint, the check path, the revoke endpoint | application | implementation | § R.1.2, § R.1.7 |
| 6 | **`product_detail` goldens** | the committed baselines behind `product_detail_mobile_golden_test.dart` and `product_detail_page_test.dart` | QA artifact | **QA** | § R.3.4 |
| 7 | **Duplicate-credential audit** | **no file.** A query a human runs against every deployed database before migration `20261006150645000` is applied | deployment precondition | **human** | **`G-12`**, § R.10.1 item 8 |

**Row 7, carried forward verbatim from the implementer's own disclosure and deliberately not smoothed:** the
duplicate-credential audit must be run **by a human against every deployed database** before migration
`20261006150645000` is applied, because `CREATE UNIQUE INDEX` fails on duplicates. The audit query **as
originally dispatched does not execute** — `"repositoryId"` is quoted camelCase, and unquoted it folds to
`repositoryid` and **errors**, which reads exactly like *"no duplicates"*. The migration embeds the
corrected form. Zero duplicates were found in every database reachable to that lane, but the only
credential-bearing one held **0 rows**, which is a vacuous *"no"*. **This is a deployment precondition owned
by a human**, not a design item — and it is now in **both** gap registers (§ R.18.2 `G-12` and
`requirements_gaps` in the metadata), which is what the finding asked for.

### R.8.5 Two landed comments that `D-18` falsifies — and whose correction is `D-4`'s required behaviour (L1, **L9, L10**)

#### The first: `postgres_product_registry_store.dart:312-319` **[5436a4d]**, immediately above the conflict branch

Revision 4 quoted this comment **and truncated it** (L9) — it cut the comment at the end of the sentence it
was analysing, which is the sentence that carries the part that is still *true*. **The comment, in full:**

> *"`RETURNING` is the whole detection mechanism: a conflicting row whose key material differs is filtered
> out by the `WHERE` above, so no row comes back and this write is refused. Checking the affected-row count of
> a bare `execute` would work too, but `RETURNING` cannot be ignored by accident — an empty result is
> unmissable here."* **[`:306-310]`, the paragraph above, which is true and is not in dispute.**
>
> *"Only THIS branch can be refused by `_activeCredentialUniqueIndex`, and so only this one translates it.
> The `expectedVersion` branch above is an UPDATE, and **no reachable path moves a credential from revoked
> back into the active set**: `revokeCredential` is the only writer of `revoked` and `recordCredentialCheck`
> refuses a revoked credential outright, so the index can never be the constraint an UPDATE trips.
> **`rotateCredential` relies on that ordering — it revokes first, so the old row leaves the index before the
> replacement is inserted.**"* **[`:312-319`]**

**The bolded middle sentence is falsified by `D-18`.** § R.9.2's path is exactly a reachable path that moves
a revoked credential back into the active set: it goes through the **conflict branch** (`store:322-331`) with
a caller-supplied `credentialId` naming the revoked row and identical material, and `$assignments` writes
`status = 'generated'` — which satisfies the index's `WHERE "status" <> 'revoked'` predicate and puts the row
**back inside** the index. The two justifications it offers do not hold either: `revokeCredential` is not the
only writer of `revoked` (the re-mint writes `status`, and `revokedAt` is in `$assignments` and is written to
`NULL` by the same statement), and `recordCredentialCheck` refusing a revoked credential is irrelevant to the
mint path.

**The trailing `rotateCredential` sentence is TRUE, and Revision 4's truncation deleted the only part of the
comment that survives intact.** `rotateCredential` (`engine:1108-1133`) reads the active credential, calls
`revokeCredential` on it (`:1116-1122`), and only then mints the replacement (`:1124-1132`) — so the
superseded row is outside the index when the replacement is inserted. **That is precisely the fact the
amendment's own `D5` correction turns on**, and Revision 4 quoted a comment with that sentence removed while
§ R.9.2 asserted the same fact. The corrected comment must therefore **keep** it.

**So the corrected comment is a three-way split, not a two-way one** — and stating it as anything less is what
made Revision 4's quotation misleading:

| Part | Verdict |
|---|---|
| `RETURNING` is the detection mechanism, and cannot be ignored by accident (`:306-310`) | **TRUE** — keep verbatim |
| Only THIS branch translates the `23505` (`:312-313`) | **TRUE** — keep |
| The `expectedVersion` branch can never trip the index (`:314`, `:317`) | **TRUE** — keep |
| *"no reachable path moves a credential from revoked back into the active set"* (`:314-315`) | **FALSE** — `D-18` is that path. Delete |
| *"`revokeCredential` is the only writer of `revoked`"* (`:315`) | **FALSE** — delete |
| *"`recordCredentialCheck` refuses a revoked credential outright"* as a reason the mint cannot reach the index (`:316-317`) | **irrelevant to this branch** — keep the clause about `recordCredentialCheck` if it is about the *check* path, drop it as a reason about the *mint* path |
| *"`rotateCredential` relies on that ordering — it revokes first"* (`:317-319`) | **TRUE, and load-bearing** — keep, and cite `engine:1108-1133` |

#### The second: `credential_test.dart:348` **[5436a4d]** — a falsifiable comment Revision 4 never named (L10)

Inside the group heading `key material is chosen once, at mint` (`:342`), the comment at `:348-350` reads:

> *"The engine's one-active rule (`engine:940-941`) does NOT catch this: it declines to refuse precisely
> when `supersedesCredentialId` equals the active credential's id, which is what makes this call reach the
> write."*

**The claim is right and the citation is wrong.** `engine:940-945` is the **empty-key check** —
`if (publicKey.trim().isEmpty || fingerprint.trim().isEmpty) throw CredentialNotUsableException(...)`. **The
one-active rule is at `engine:954-961`** — `readActiveCredentialForRepository` followed by
`if (active != null && active.credentialId != supersedesCredentialId) throw …`. So a reader sent to `:940-941`
to find the rule finds a different guard, and a reader sent to `:954-961` finds the rule the comment describes.

**This comment is in scope of `D-4`'s comment correction and Revision 4 did not say so.** It asserts a
location, the location is wrong, and it is the same class of defect as the store comment: **a comment that
points a reader at the wrong line is worse than no comment**, because it looks like evidence. It is therefore
part of `D-4`'s required deliverable, with the corrected citation `engine:954-961`.

#### Why both corrections belong in the design and not in a comment-only ticket

**So `D-4`'s required behaviour has four parts, not three:**

1. the mint branch is insert-only (§ R.9.1), **and**
2. **the comment at `store:312-319` is corrected** — per the three-way split above: the branch-specific
   claims survive, the blanket claim does not, and the `rotateCredential` ordering sentence is **kept**,
   **and**
3. **the comment at `credential_test.dart:348` is corrected** to cite `engine:954-961`, **and**
4. **`T-D` (§ R.9.6) is the test that makes the corrected claims true**, so neither comment can rot into a new
   falsehood the way the old ones did.

**Why this belongs in the design and not in a comment-only ticket:** a comment asserting an invariant that a
live defect falsifies is worse than no comment, because the next reader treats it as evidence. The fix is not
the words; it is that the words become **checkable**.

---

## R.9 — Two confirmed security defects and one unnamed one, specified **per tier**

**One correction to how this section reads, because it changes what "reachable" means (L3).** Revision 3
opened § R.9 by saying the engineering review confirmed both defects are *"real and reachable through the
**public domain API** today"*. That is **true of the Dart library and false of any HTTP surface**, and the
difference matters because the sentence reads as though a caller could trigger it. Precisely:

> `recordGeneratedCredential` is a **public method on `ProductRegistryEngine`**, so any code in the Dart
> program can reach it. **`grep -rn "recordGeneratedCredential" apps/server/lib/src/endpoints/` returns no
> match** — **no Serverpod endpoint calls it**, at `[5436a4d]`. There is therefore **no HTTP-reachable
> surface** for either defect today.

That is still a live defect and not a softened one: the engine's section header says in terms that the
method *"is reached with an existing id and fresh key material"* (`engine:907-915`), the *library* is the
API the mint endpoint this design specifies will call, and `G-7`'s endpoint work will make it reachable from
the wire. **It is a defect in the domain's public contract, reachable in-process, and about to become
reachable over HTTP.** Stated precisely, because an inflated reachability claim is the same defect class as
an understated one.

Both original defects are **outside `D-1`'s literal scope** because `D-1` named four fields. `D-1` named
what it was asked to name; § R.9 states the set a mint must not touch. **Revision 4 also adds a third
requirement, `D-6`**, because § R.6.3 shows that extending `D-4` to the CAS branch as Revision 3 wrote it
would break revocation.

### R.9.1 `M-3` — identical-material re-mint is still permitted → **`D-4`, on both tiers**

**The defect.** `D-1`'s `WHERE` predicate is *satisfied by identical values*. So:

```dart
recordGeneratedCredential(
  credentialId: <an existing credential's id>,
  supersedesCredentialId: <the same id>,        // passes the engine's one-active guard
  referenceName: <identical>,                   // predicate satisfied
  publicKey:    <identical>,                    // predicate satisfied
  fingerprint:  <identical>,                    // predicate satisfied
)
```

passes the guard at `engine:954-961`, reaches `saveProductCredential` with no `expectedVersion`
(`engine:979`), and takes the conflict branch — where `$assignments` (`store:226-240`) writes **every**
mutable column from the freshly constructed object (`engine:963-978`), which carries
`status: CredentialStatus.generated`, `version: 1`, and **no** host or verification state at all.

**What is silently lost, column by column — this list is the requirement, not a summary:**

| Column | After the re-mint | Consequence |
|---|---|---|
| `status` | `generated` | a `verified` credential silently reverts to unproven |
| `hostKeyStatus` | `unknown` | a confirmed host becomes unrecognised |
| `hostConfirmedAt`, `hostConfirmedBy` | **null** | **a human's out-of-band trust decision is erased** |
| `lastVerifiedAt`, `lastVerifiedBy` | **null** | the proof of access is erased |
| `lastFailureReason`, `hostKeyFingerprint` | **null** | diagnostics erased |
| `createdAt` | rewritten | the record's age is falsified |
| `revokedAt`, `revokedReason` | **null** | **§ R.9.2** |
| `version` | `1` | the optimistic-lock counter restarts |

**`D-4` — the mint path never upserts. Required behaviour, stated for each tier separately:**

> **Tier A — Postgres** (`apps/server/lib/src/persistence/postgres_product_registry_store.dart`). On the
> conflict branch, an `ON CONFLICT ("credentialId")` that matches an **existing** row must **update
> nothing**. The construct is:
>
> ```sql
> INSERT INTO "product_credential" (…) VALUES (…)
> ON CONFLICT ("credentialId") DO NOTHING
> RETURNING "credentialId"
> ```
>
> An empty result is a typed refusal — `CredentialIdentityConflictException(credentialId)`, or
> `CredentialNotUsableException` carrying a distinct greppable reason, § R.16 row 44.
>
> **Tier B — in-memory** (`packages/product_registry/lib/src/store/in_memory_product_registry_store.dart`).
> `DO NOTHING` has no Dart analogue, so Tier B needs its **own** construct, and this is the requirement the
> finding named as missing:
>
> ```dart
> // A null `expectedVersion` is what marks this write as a MINT, and a mint is INSERT-ONLY.
> if (existing != null && expectedVersion == null) {
>   throw CredentialIdentityConflictException(credential.credentialId);   // or the reason string
> }
> ```
>
> **It is checked FIRST — ahead of the key-material check** — because that is the order Tier A is forced
> into: `DO NOTHING` evaluates no column predicate, so on Tier A an *identical*-material re-mint and a
> *different*-material re-mint are **indistinguishable to the statement**. Tier B ordering its key-material
> check first would make the two tiers return **different messages for the same defect**, which is a
> two-tier disagreement in everything but outcome.

**Why `DO NOTHING`, and not `DO UPDATE … WHERE <always false>`.** The latter is **still an update**. It
would keep the predicate's shape alive as an accidental second source of truth — the exact thing that
made `D-1`'s predicate satisfiable by identical values in the first place. `DO NOTHING` removes the
predicate entirely. Revision 3 already argued this and the finding agreed; it is restated because it is the
load-bearing choice.

**Why this is safe — the safety argument, verified rather than asserted.** Every call site of
`saveProductCredential` at **[5436a4d]**, in the engine:

| Call site | `expectedVersion`? | Branch |
|---|---|---|
| `engine:979` — `recordGeneratedCredential` (the mint) | **none** | **conflict / mint** |
| `engine:1011` — `confirmHostKey` | `c.version` | CAS |
| `engine:1025` — `confirmHostKey` | `c.version` | CAS |
| `engine:1066` — `recordCredentialCheck` | `c.version` | CAS |
| `engine:1088` — `revokeCredential` | `c.version` | CAS |

**Which call sites reach the conflict branch — corrected (M7).** `revokeCredential`, `confirmHostKey` and
`recordCredentialCheck` all go through `copyWith` + CAS, so `D-4` cannot break any of them. **Those three
are the only engine methods that cannot reach it.** But Revision 4's stronger claim — *"**The conflict branch
is reached only by the mint path.** … `rotateCredential` reaches it only by minting a **new** `credentialId`,
which is what it already does"* — **was false, and it was false about the domain's own API**:

> `rotateCredential` declares `String? credentialId` as a **caller parameter** (`engine:1105`) and forwards
> it **verbatim** (`engine:1129`) into `recordGeneratedCredential`. A caller passing the **superseded** id
> reaches the conflict branch through a first-class domain method. The domain does not enforce the
> convention; § R.9.2 states the resulting path and § R.9.6's `T-D` now drives it through `rotateCredential`
> as well as through the direct call.

**What does not change is `D-4`'s scope.** The requirement is unchanged and was never in doubt: the mint
branch is insert-only, **whichever caller reaches it**. What changes is the **reason** — from *"no other
caller can get there"* (a convention the domain does not enforce) to *"the branch refuses any write onto an
existing id, so no caller matters"* (which the construct actually guarantees). **`D-4` is now justified by
the construct rather than by a caller convention**, and that is the correct order of reasons: a construct
holds when every caller behaves; a convention holds until one does not.

The rotation test's own statement — `credential_test.dart:521` **[5436a4d]**, *"rotation is the only way to
change the key, and it mints a new id"* (corrected from Revision 3's `:520`, L4) — **describes the tested
behaviour, and the test passes `credentialId: 'cred-2'`, a new id** (`:532`). So the test is green and the
convention is untested: nothing asserts that a caller passing the *old* id is refused, which is why `T-D` is
extended rather than merely re-run.

**`D-4` does not extend to the CAS branch, and that is a correction (H3).** Revision 3 wrote that `D-4`
*"extends to the mutable set too — a CAS write must not be able to clear `hostConfirmedAt`,
`lastVerifiedAt` or `revokedAt` either"*, with no construct and no test. **That sentence cannot be
implemented as written**: `revokeCredential` legitimately **sets** `revokedAt` and `revokedReason` through
the CAS branch (`engine:1082-1088`), and `confirmHostKey` legitimately **sets** `hostConfirmedAt` and
`hostConfirmedBy` (**`engine:1018-1025`** — Revision 4 cited `:1006-1011`, which is the *changed-fingerprint*
branch and sets only `hostKeyStatus` and `hostKeyFingerprint`; corrected here). A predicate forbidding those
columns from being *assigned* would refuse the two most important legitimate writes in the credential
lifecycle. The requirement is split, and the second half is **`D-6`** (§ R.9.4), which forbids the
**transition**, not the assignment. **A reviewer should check that split rather than the merged sentence.**

**Evidence that these constructs exist, without treating that as approval.** `fix/credential-identity-invariants`
(`/private/tmp/shipit-credential-identity`, `HEAD == BASE == 0bf2fa0`, **uncommitted**, reviewed
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` with no blockers but one MEDIUM gap in its own guard) **[UNCOMMITTED
0bf2fa0]** implements `DO NOTHING … RETURNING` on Tier A and the `existing != null && expectedVersion == null`
identity guard first on Tier B, with the identity and scope refusal strings **byte-identical across tiers**.
I cite that as *a construct of this shape exists and survived a review at that level*. **I did not weaken
the specification because the code exists**, the code is not the specification, and the guard gap
(`verify_schema_bootstrap.sh:267` — the `IF NOT EXISTS` normalisation forgives the one divergence in that
clause that breaks the chain path) is a live follow-up against it.

### R.9.2 The derived consequence: a revoked credential can be resurrected — and the mechanism, named correctly (L1)

I did not find this in the engineering review; it follows from reading `$assignments` against
`readActiveCredentialForRepository`. The reviewer **re-derived it independently and confirmed it**, and I
re-verified every step at the new base. It is **worse under `79e860e2`** than it was before.

**The path, entirely through the Dart public API** (L3: not over HTTP — see the preamble):

```dart
engine.recordGeneratedCredential(
  productId: 'shipit',
  repositoryId: 'repo-1',
  credentialId:   <the REVOKED credential's id>,
  referenceName:  <identical>,    // D-1 predicate satisfied
  publicKey:      <identical>,    // D-1 predicate satisfied
  fingerprint:    <identical>,    // D-1 predicate satisfied
  // algorithm defaults to 'ed25519' — identical
  // supersedesCredentialId omitted
)
```

1. `readRepositoryReference` (`engine:938`) + `_ensureOwned` (`engine:939`) → pass.
2. `publicKey` non-empty (`engine:940-945`), no `PRIVATE KEY` (`engine:946-953`) → pass.
3. `readActiveCredentialForRepository('repo-1')` (`engine:954`) → **`null`**, because the revoked row is
   excluded by `status <> 'revoked'` (`store:370-381`; `in_memory:220-231`). So the one-active guard at
   `engine:955-961` **cannot fire** — there is no *active* credential to conflict with.
4. A fresh `RepositoryCredential` is constructed with `status: generated`, `revokedAt: null`,
   `revokedReason: null` (`engine:963-978`).
5. The conflict branch's predicate is satisfied, so the row is updated; `RETURNING` yields a row; the call
   **succeeds**.

**Result.** A credential the operator revoked is **back in the active set as `generated`**, with
`revokedAt`/`revokedReason` **erased** — and under § R.6.1 its **manager handle has already been
destroyed**. The row therefore claims a shape that says *"a deploy key exists"* while the key exists
nowhere. It also now occupies the active set for `repo-1`, so **`D-2`'s partial unique index refuses the
legitimate fresh mint** for that repository with *"already has an active credential"*. Recovery is
`rotateCredential` (revoke-then-mint), so it is recoverable — but the state in between is corrupted and
the audit trail is falsified.

**And this path is reachable through a first-class domain method, not only through the public API (M7).**
The block above is written as a direct `recordGeneratedCredential` call, which is how § R.9.2 has always shown
it. **That framing understated the exposure.** `rotateCredential` (`engine:1098-1133`) declares:

```dart
Future<RepositoryCredential> rotateCredential({
  required String productId,
  required String repositoryId,
  required String referenceName,
  required String publicKey,
  required String fingerprint,
  required String reason,
  String? credentialId,        // ← engine:1105. A CALLER PARAMETER, not a fresh id
  DateTime? now,
})
```

and forwards it **verbatim** into `recordGeneratedCredential` at **`engine:1129`**. So a caller that passes
the **superseded** credential's own id as `credentialId` reaches the conflict branch through a documented,
intended-to-be-used domain method — `rotateCredential`'s parameter exists so a caller *can* choose the new
credential's id, and nothing stops it choosing the old one. § R.9.2's path is therefore reachable through
**both** entry points. `T-D` (§ R.9.6) now drives it through **each**.

**Why the distinction matters for the requirement, not just for the prose.** Revision 4 justified `D-4`'s
scope by saying the conflict branch *"is reached only by the mint path… `rotateCredential` reaches it only by
minting a **new** `credentialId`, which is what it already does"*. **That reason is false** — and it was false
in a way that mattered, because a reader who accepts it concludes the domain enforces a convention it does
not enforce. **The outcome is safe after `D-4`** (the branch is insert-only, so a caller-supplied id cannot
reach it), and the correction is to the **stated reason**, not to the requirement.

#### The mechanism, named correctly — and what is **not** the mechanism

Revision 3's `D-18` entry and § R.9.2 both let it read as though **`D-2`'s index** is the thing that
refuses. **It is not, and the distinction is the whole reason the path works.** Three named facts:

| Element | Role | Verified at **[5436a4d]** |
|---|---|---|
| **The engine's one-active guard** | **This is the guard that would have refused the write** — `if (active != null && active.credentialId != supersedesCredentialId) throw …`. It reads `null` and stands down. **Its stand-down is the mechanism.** | `engine:954-961` |
| **`D-2`'s partial unique index** | **Not** the refuser, on either side. It is (a) the thing the re-mint **evades** — the row was *outside* the index while revoked and the update moves it *into* the index with no other row there to conflict with — and (b) the **backstop that blocks the legitimate fresh mint afterwards**. `D-2` is where the corruption becomes a *user-visible* outage; it is not where the corruption is *done*. | `store:313-319` predicate; the comment there is falsified — § R.8.5 |
| **`D-1`'s predicate** | Not the refuser either: it is **satisfied** by identical values, which is what lets the write reach the statement at all. | `store:322-329` |

**Why the naming matters and is not pedantry.** A reader told "the index stops this" will implement a
check for the index, find that the index is satisfied, and conclude the path is closed. A reader told "the
one-active guard stands down because the read excludes revoked rows" knows exactly which line to read and
exactly which test to write. `D-2` is a real invariant and is doing real work here — just not this work.

**What is covered and what is not.** `credential_test.dart:323` **[5436a4d]** — *"a revoked credential
cannot be re-checked into life"* — closes the **check** path (`recordCredentialCheck` refuses a revoked
credential, `engine:1044-1046`). It does **not** close the **mint** path. The distinction is easy to miss
because both sentences contain *"revoked credential"*.

**Required behaviour** is `D-4`'s: a mint may never write to an existing `credentialId`, so
`revokedAt`/`revokedReason` are unreachable from the mint path. Stated separately because it is the
**consequence** a reviewer should test first: **`T-D`** (§ R.9.6).

### R.9.3 `M-4` — `repositoryId` remains rewritable → **`D-5`, on both tiers**

**The defect.** `"repositoryId" = @repositoryId` is in `$assignments` (`store:227-228` **[5436a4d]**) and is
**not** in `D-1`'s predicate (`store:325-328`). So a conflicting write can move an existing credential to
a different repository. `copyWith` cannot do it (`repository_credential.dart:137-172`); the route is the
same caller-supplied-`credentialId` mint as `M-3`.

**What it produces, precisely.** An installed deploy key is silently re-pointed between two repositories
**of the same product**, with **no rotation record** — `supersedesCredentialId` is untouched, so the
rotation chain does not show it. `_ensureOwned` (`engine:1784-1790`) blocks crossing products, so the
blast radius is **one product's repositories**.

**Correction to Revision 3's prose, which the engineering review caught and confirmed (I verified it too).**
Revision 3 § R.9.3 said a re-point *"carries a human's confirmation of **repo-1's host** across to
**repo-2's host**."* **That is true of the CAS branch and false of the mint path**, and Revision 3 stated
it as if it were both. The two behave differently, and the difference is worth stating precisely because
both are wrong:

| Branch | What re-pointing does to host trust | Contradicts ADR 0018 `:96-99`? |
|---|---|---|
| **Mint** (`$assignments` from `engine:963-978`) | **destroys** the confirmation: the new object carries `hostKeyStatus: unknown` and no `hostConfirmedAt`, and `$assignments` writes those | **yes** — a host nobody confirmed is marked unconfirmed, and an *unrecognised* host is left unrecognised. The record is honest; the scope is wrong |
| **CAS** (`copyWith` at a call site that re-points) | **carries** `hostKeyStatus`, `hostConfirmedAt`, `hostConfirmedBy` and `hostKeyFingerprint` across, because none is in the predicate and the caller supplies fresh values | **yes, and worse** — a host whose key was **never shown to anybody** has been marked confirmed |

ADR 0018 `:96-99` requires that the operator *"is shown the host, key type and fingerprint and must confirm
it"*. Neither branch satisfies it. **The requirement `D-5` states is unaffected** — immutability of the
scope set is one requirement with two harms, not two requirements — and only the sentence was wrong.

**`D-5` — the scope set is immutable too. Required behaviour, per tier:**

> **Tier A — Postgres.** Two changes, because the two branches differ after `D-4`:
> - **Conflict/mint branch: nothing to add.** `DO NOTHING` updates nothing, so no scope predicate is needed
>   there. *(This is worth stating, because a reader who assumes symmetry will add a predicate that can
>   never be evaluated and will believe it is doing work.)*
> - **CAS branch:** add `AND "productId" = @productId AND "repositoryId" = @repositoryId` to the existing
>   `WHERE`, alongside `D-1`'s four-field predicate. All of it stays **in the statement**, not in a read
>   before it — a check-then-write is a race against any other connection.
>
> **Tier B — in-memory.** Its own construct, and it is **not** `_sameKeyMaterial`'s:
> ```dart
> if (existing != null &&
>     (existing.productId != credential.productId ||
>      existing.repositoryId != credential.repositoryId)) {
>   throw CredentialNotUsableException(
>     credential.credentialId,
>     'the scope of an existing credential cannot be changed; …',   // a reason naming SCOPE, never the key
>   );
> }
> ```
> Checked on **both** branches, deliberately: a re-point is the defect, not the branch it arrived on.
>
> **A separate refusal reason is required**, and this is the correctness point for the two tiers
> agreeing. `_sameKeyMaterial`'s own doc comment says `repositoryId`/`productId` are *"deliberately not
> part of this predicate: it mirrors the immutability the Postgres store's write enforces, and the two must
> agree"* **[5436a4d]**. **After `D-5` they agree, but not by being merged into one predicate** — they
> agree because the same *fields* are checked and a **different** *reason* is produced. Merging them would
> make `_sameKeyMaterial` a misnomer and would tell a caller re-pointing a key that it had tried to change
> the key's bytes.

**Why this cannot break rotation:** `rotateCredential` mints a **new** `credentialId` for the **same**
`repositoryId` (`engine:1098-1133`; `credential_test.dart:521`). No legitimate path changes either field on
an existing identity, so predicating on them refuses only illegitimate writes. This also closes the
implementer's pre-existing follow-up #5 (*"`productId`/`repositoryId` on the conflict branch, unchanged by
this work"*) as part of the same requirement, rather than leaving it dangling — **though note that after
`D-4` the conflict branch updates nothing at all, so that half of the follow-up is discharged by `D-4` and
the CAS half by `D-5`.**

### R.9.4 `D-6` — a recorded fact may be **set**, never **erased** — **the set is decided ONCE, as EIGHT columns (H3, H9)**

**The requirement, stated once, in the only form that is satisfiable — and the set is now decided rather
than implied (H9):**

> A write **MAY** set `hostConfirmedAt`, `hostConfirmedBy`, `lastVerifiedAt`, `lastVerifiedBy`,
> `lastFailureReason`, `hostKeyFingerprint`, `revokedAt` and `revokedReason` — including overwriting an
> existing non-null value. A write **MUST NOT** transition any of them from **non-null** to **null**.
> **This applies to the CAS branch only**; the mint branch is already insert-only under `D-4`.
>
> **That is EIGHT columns. Both tier constructs below cover all eight. There is no seventh.**

**The defect H9 corrected, stated so it cannot recur.** Revision 4's requirement box named **eight** columns
and both of its constructs covered **seven** — `lastFailureReason` was silently absent from Tier A's
`_noClear` set and from Tier B's `_clearsDurableEvidence`, with no rationale, while the paragraph *below*
the box reasoned about `lastFailureReason` explicitly. **`lastFailureReason` is a real, nullable `text`
column** (`apps/server/migrations/20261006150645000/definition.sql:632`), and `recordCredentialCheck`'s
failure branch writes it. So **an implementer who follows Revision 4's constructs ships
`lastFailureReason` erasable on the CAS branch, on both tiers** — the one diagnostic column, cleared by
nothing more than a caller omitting a parameter.

**The decision is to KEEP the column in the set.** The alternative — removing it from the requirement, § R.9.5
and `SC-17` — was available and was rejected, for a reason that is about the column's meaning rather than
about symmetry: **`lastFailureReason` is the only record of *why* a check failed**, and it is written by the
failure branch of `recordCredentialCheck` (`:1061-1065`) with no sibling write. A CAS write that drops it to
`null` while leaving `status: failing` in place produces a row that says *"the last check failed"* and
*"nothing is known about why"* — which is § R.5.4's *"we could not check ≠ it is fine"* failure mode, one
layer down. Erasing a fact is what `D-6` exists to prevent, and this one is a fact.

**Why "may SET" is the operative half, and why Revision 3 could not say it.** Three legitimate writes set
these columns through the CAS branch, and all three would be refused by a predicate that forbade touching
them:

| Caller | Sets | Verified at **[5436a4d]** |
|---|---|---|
| `revokeCredential` | `revokedAt`, `revokedReason` | `engine:1082-1087` |
| `confirmHostKey` | `hostKeyStatus`, `hostKeyFingerprint`, `hostConfirmedAt`, `hostConfirmedBy` | **`engine:1018-1025`** — the confirmed branch. *(Revision 4 cited `:1006-1011`, which is the **changed-fingerprint** branch: it sets only `hostKeyStatus` and `hostKeyFingerprint`, and it throws. Corrected.)* |
| `recordCredentialCheck` | `lastVerifiedAt`, `lastVerifiedBy` (success branch, `:1054-1060`); **`lastFailureReason`** (failure branch, `:1061-1065`) | `engine:1054-1065` |

So the predicate is **per-column and per-direction**, not per-column. Note also that
`recordCredentialCheck`'s *failure* branch sets `lastFailureReason` while leaving `lastVerifiedAt` alone
(**`engine:1061-1065`**) — which the transition rule permits, because that is a **set**, not a clearing.

**Tier A — Postgres.** The construct is one helper plus one clause per column:

```sql
-- A parameter whose value may be NULL must be declared so Postgres can infer its
-- type at Parse time. A bare `@p IS NOT NULL` fails with 42P08 before a row is
-- examined; CAST(... AS text) then fails the SET with 42804 because it pins the
-- parameter to text while the column is a timestamp. So the COLUMN'S REAL TYPE
-- is the parameter — and it is read off migrations/*/definition.sql, so a type
-- change fails loudly at Parse inside the integration suite rather than silently.
static String _noClear(String column, String type) =>
    'AND ("$column" IS NULL OR CAST(@$column AS $type) IS NOT NULL)';
```

Each clause reads: *leave the column alone, or write a non-null value into it.* **Applied to all EIGHT
columns** — read off `apps/server/migrations/20261006150645000/definition.sql:619-642`, which declares
**three `timestamp without time zone`** and **five `text`**, all nullable:

```dart
// Tier A: eight _noClear clauses — three timestamp, five text.
_noClear('lastVerifiedAt',    'timestamp without time zone')   // definition.sql:630
_noClear('lastVerifiedBy',    'text')                          // :631
_noClear('lastFailureReason', 'text')                          // ★ ADDED — :632
_noClear('hostKeyFingerprint', 'text')                         // :635
_noClear('hostConfirmedAt',   'timestamp without time zone')    // :636
_noClear('hostConfirmedBy',   'text')                          // :637
_noClear('revokedAt',         'timestamp without time zone')    // :638
_noClear('revokedReason',     'text')                          // :639
```

| # | Column | Type | `definition.sql` |
|---|---|---|---|
| 1 | `lastVerifiedAt` | `timestamp without time zone` | `:630` |
| 2 | `lastVerifiedBy` | `text` | `:631` |
| 3 | **`lastFailureReason`** | **`text`** | **`:632`** |
| 4 | `hostKeyFingerprint` | `text` | `:635` |
| 5 | `hostConfirmedAt` | `timestamp without time zone` | `:636` |
| 6 | `hostConfirmedBy` | `text` | `:637` |
| 7 | `revokedAt` | `timestamp without time zone` | `:638` |
| 8 | `revokedReason` | `text` | `:639` |

**Tier B — in-memory.** Same rule, same direction, same eight columns, in Dart:

```dart
/// Only a non-null → null transition counts. Re-recording a host confirmation
/// with a fresh timestamp is something `copyWith` can express and nothing
/// legitimate does today; erasing what is on the record is what `D-6` refuses.
static bool _clearsDurableEvidence(prev, next) =>
    _clears(prev.hostConfirmedAt,  next.hostConfirmedAt)  ||
    _clears(prev.hostConfirmedBy,  next.hostConfirmedBy)  ||
    _clears(prev.lastVerifiedAt,   next.lastVerifiedAt)   ||
    _clears(prev.lastVerifiedBy,   next.lastVerifiedBy)   ||
    _clears(prev.lastFailureReason, next.lastFailureReason) ||   // ★ ADDED
    _clears(prev.hostKeyFingerprint, next.hostKeyFingerprint) ||
    _clears(prev.revokedAt,        next.revokedAt)        ||
    _clears(prev.revokedReason,    next.revokedReason);

static bool _clears(Object? previous, Object? next) =>
    previous != null && next == null;
```

**The one check that keeps the box and the constructs from diverging again.** The defect H9 found is that a
requirement box and two constructs can disagree about a set **and nothing notices**, because the prose around
them reasons about the missing member. So: **`T-K` (§ R.9.6) asserts all eight columns by name, on both
tiers**, and § 10.2 item 2 makes "name the column set from the requirement box and compare it, member by
member, against both constructs" a review step. **A count is not a check; naming the members is.**

**The tier-scoping is load-bearing and it is the one place the tiers must differ in *reach*, not in
outcome.** Tier B's evidence guard is **CAS-branch only** (`expectedVersion != null`), because Tier A's mint
branch is a single `ON CONFLICT … DO NOTHING` that **evaluates no column predicate at all** — on that
branch Tier A's *only* guard is `D-4`'s identity conflict. Applying the evidence guard to Tier B's mint
path would mean **Tier B refuses for a reason Tier A cannot see**, which is a mask: it hides `D-4` behind a
later check, so removing `D-4` leaves the test green. **The rule to check is: the mint path must be
*total* on both tiers — `D-4`'s identity guard fires for any existing row, before anything else — so no
mint-path write exists that could clear evidence, and scoping the evidence guard to CAS removed a mask
rather than opening a hole.** A reviewer should verify that by deleting `D-4` and confirming `T-D` goes
red (§ R.9.6).

**Not in `D-6`'s set, and why.** `status` is absent deliberately: `revokeCredential` sets it **to**
`revoked` and `recordCredentialCheck` sets it **to** `failing` — and a transition `revoked → generated` is
exactly what `D-4` prevents, from the other direction. `version`, `createdAt` and `supersedesCredentialId`
are absent because they are `D-4`'s mint-branch concern, not a durable-evidence concern.

### R.9.5 The set, stated once

`D-1` named four fields because four fields were asked for. The complete statement of what a mint must not
touch, and of what no write may erase:

| Set | Fields | Which requirement | Branch | Tier |
|---|---|---|---|---|
| **Material** | `publicKey`, `fingerprint`, `algorithm`, `referenceName` | `D-1` — **landed** | both | both |
| **Scope** | `productId`, `repositoryId` | `D-5` | **CAS only** — the mint branch updates nothing under `D-4` | both |
| **Identity of the record** | `credentialId` (the conflict key), `createdAt`, `supersedesCredentialId` | `D-4` — **the mint may not write onto an existing row at all** | mint | both |
| **★ Identity, by the *route* it arrives on (M7)** | **`rotateCredential`'s `String? credentialId` parameter** — `engine:1105`, forwarded verbatim at `engine:1129` | `D-4` — **the same insert-only rule, on the same conflict branch**. It is listed separately because it is a **second, independent way** a caller-supplied id reaches that branch, and Revision 4's justification of `D-4`'s scope assumed there was only one | mint | both |
| **Everything mutable, on the mint path** | `status`, `hostKeyStatus`, `hostConfirmedAt/By`, `hostKeyFingerprint`, `lastVerifiedAt/By`, `lastFailureReason`, `revokedAt`, `revokedReason`, `version` | `D-4` — **subsumed**: an insert-only mint writes none of them | mint | both |
| **Durable evidence** | `lastVerifiedAt`, `lastVerifiedBy`, **`lastFailureReason`**, `hostKeyFingerprint`, `hostConfirmedAt`, `hostConfirmedBy`, `revokedAt`, `revokedReason` — **eight, in § R.9.4's order** | `D-6` — **may SET, must not erase** | **CAS only** | both |

**Why `rotateCredential`'s parameter is its own row and not a footnote (M7).** Revision 4 justified `D-4`'s
scope with *"the conflict branch is reached only by the mint path … `rotateCredential` reaches it only by
minting a **new** `credentialId`, which is what it already does"*. **That is a caller convention the domain
does not enforce**: the parameter exists so a caller **can** choose the id, and a caller passing the superseded
one reaches the branch through a first-class domain method. Listing it separately makes the requirement's real
basis explicit — **the branch refuses any write onto an existing id, whichever route the write arrived on** —
so the row cannot be deleted again on the assumption that one route is the only one.

### R.9.6 Tests — `T-A` … `T-L`, and **which tier each one lives on**

**None of these was run by this lane.** `T-A`/`T-B`/`GAP-2` **are** reported green at `07c8c8f` by the
implementer's report; I did not re-run them and make no claim beyond that. **`T-C` … `T-L` are specified here,
not executed**, and their predicted pre-fix failures are stated as predictions derived from the code path with
the path shown — never as results.

**The tier column is the correction the finding demanded (B4).** Revision 3 placed `T-C`, `T-F` and `T-G` in
`packages/product_registry/test/credential_test.dart` and wrote `D-4`/`D-5` as **SQL statement changes** —
so the named tests and the named requirement were about **different tiers**, and a Postgres-only fix would
have left those three tests red. The words `InMemory`, `both tiers` and `memory tier` appeared **zero
times** in all four Revision 3 artifacts. **They appear in the table below, and in § R.9.1–R.9.4.**

| ID | Test | Tier(s) | Asserts | Predicted before the fix |
|---|---|---|---|---|
| **`T-A`** | A same-id, different-material re-mint is refused and the row is untouched | **Postgres** (the predicating statement); also in-memory via `D-1`'s `_sameKeyMaterial` | write refused; every column byte-identical afterwards | **passes today** — reported green at `07c8c8f`, not re-run by me |
| **`T-B`** | Two concurrent mints for one repository yield exactly one active row | **Postgres only** — it is a unique index; an in-memory map cannot have one | one winner, one typed `23505` refusal | **passes today** — reported green, not re-run by me |
| **`T-C`** | **Identical-material re-mint is refused and every column is untouched** | **BOTH** — in-memory beside the existing *"key material is chosen once, at mint"* group (`credential_test.dart:342`); **and** Postgres in `product_credential_immutability_postgres_test.dart` | `recordGeneratedCredential(credentialId: <existing>, supersedesCredentialId: <existing>, identical referenceName/publicKey/fingerprint/algorithm)` **throws**; afterwards **every** column is byte-identical — `status`, `hostKeyStatus`, `hostConfirmedAt`, `hostConfirmedBy`, `hostKeyFingerprint`, `lastVerifiedAt`, `lastVerifiedBy`, `lastFailureReason`, `createdAt`, `revokedAt`, `revokedReason`, `version` | **FAILS today on both tiers** — the in-memory tier overwrites wholesale (`in_memory:193`) and the Postgres tier upserts |
| **`T-D`** | **A revoked credential cannot be resurrected**, and the legitimate mint then works — **driven through BOTH entry points (M7)** | **BOTH** — and its second half **additionally** needs **Postgres**, because the index it asserts is a database object | **Entry point 1** — `recordGeneratedCredential(credentialId: <the revoked row's id>, identical material)` **throws**; the row stays `revoked` with `revokedAt`/`revokedReason` intact; `readActiveCredentialForRepository` still returns `null`. **Entry point 2 (added in Rev 5)** — the *same* attempt driven through **`rotateCredential(credentialId: <the revoked row's id>, …)`** also throws, because the parameter is a caller-supplied value forwarded verbatim (`engine:1105`, `:1129`). **And a fresh mint for that repository then succeeds** | **FAILS today on both tiers, on both entry points.** On Postgres the second half fails because the resurrected row occupies the active set and `D-2`'s index refuses the legitimate mint |
| **`T-E`** | **A different-material re-mint is still refused, and stays distinguishable** | **BOTH**, and **Postgres is the tier that can witness the distinction** | a different-material re-mint throws; the message identifies the **identity conflict**, not the material — because under `DO NOTHING` a different-material and an identical-material re-mint are indistinguishable to the statement | passes today; **this is `D-4`'s regression guard**, and it is the control that proves `D-4` did not silently swallow `D-1`'s message |
| **`T-F`** | `repositoryId` is immutable on an existing row | **BOTH** | re-pointing to another repository of the **same** product throws; `repositoryId` unchanged; and the **refusal reason names the scope**, not the key | **FAILS today on both tiers** — `_sameKeyMaterial` excludes it by design (`in_memory:196-209`) and no predicate covers it (`store:325-328`) |
| **`T-G`** | `productId` is immutable on an existing row | **BOTH** | as `T-F`, for `productId` | **FAILS today on both tiers** |
| **`T-J`** | **A CAS write may SET durable evidence** — `D-6` does not over-refuse | **BOTH** | `revokeCredential` **succeeds** and writes `revokedAt`/`revokedReason`; `confirmHostKey` **succeeds** and writes `hostConfirmedAt`/`hostConfirmedBy`; `recordCredentialCheck` **succeeds** on both the success and failure paths | passes today — **and this is `D-6`'s regression guard.** Without it, the obvious implementation of `D-6` (forbid the columns) turns `T-J` red |
| **`T-K`** | **A CAS write may not ERASE durable evidence — all EIGHT columns, by name (H9)** | **BOTH** | a `saveProductCredential(…, expectedVersion:)` whose object drops **any** of the eight from non-null to null throws — asserted **member by member**: `lastVerifiedAt`, `lastVerifiedBy`, **`lastFailureReason`**, `hostKeyFingerprint`, `hostConfirmedAt`, `hostConfirmedBy`, `revokedAt`, `revokedReason` — and the row is unchanged. **`T-K` names every column rather than counting them, because H9's defect was a requirement box and two constructs disagreeing about a set with nothing noticing** | **FAILS today** — `$assignments` writes all of them (`store:226-240`). It would **still** fail on `lastFailureReason` alone if only Revision 4's seven-column constructs were built |
| **`T-L`** | **★ NEW (B6) — a foreign `repositoryId` is refused with 403, and NO field of the other product's credential is returned** | **BOTH store tiers** — and it needs the **real endpoint path**, because the disclosure this asserts against is created by the endpoint's own call sequence, not by the store | `mintOrReadDeployKey(productId: 'A', repositoryId: <a repository of product 'B'>, …)` **throws `CrossProductAccessException`** → **403**; and the response body carries **no field** of B's credential — not `publicKey`, not `fingerprint`, not `algorithm`, not `credentialId`, not `status`, not `hostKeyStatus`, and **not** `alreadyExisted: true` (which would itself disclose that a credential exists) | **cannot pass today** — the endpoint does not exist, and **the sequence Revision 4 specified would fail this test on both tiers**, because § R.14.1 step 4's store method has no product notion (B6) |
| **`GAP-2`** | *(pre-existing, landed — mapped here because the tier table omitted it, L11)* | **Postgres only** | *"replaying the migration chain alone creates the index"* (`product_credential_immutability_postgres_test.dart:622-624`) and its negative control *"without that migration the chain does not enforce it"* (`:671-673`) | **passes** — landed at `07c8c8f`, reported by the implementer; **not re-run by me**. Included because `D-2` is `G-11`'s dependency and a reader asking "which tier asserts what?" could not answer from Revision 4's table |
| **`T-I`** | **After a successful mint, the handle resolves** — the `T-H` counterpart | **none — a fake `SecretProvider`, no store tier** | given a fake provider, a mint that returns normally leaves `resolve(handle)` **returning the material**; and the handle is **not** among `destroy`ed calls. **And (Rev 5, H8) `privateHalf` is zeroed on every exit** — asserted for **both** forms of § R.5.7's construct, including the path where `put` itself throws | **cannot fail today** — no code exists. It is specified because its absence is what let B2 through: without an assertion on the success path, a `finally` that destroys the handle is indistinguishable from a correct one. **Revision 4's obligation-4 gap on FORM 2 is exactly this test not existing** |
| **`T-H`** | A refused substrate mint writes **zero** rows | **none for the store tier; the real engine plus a fake provider** | for **each** of the four `substrateFailure` causes, the mint throws `SecretSubstrateUnavailable` carrying that cause, **and** counts of `product_credential`, `product` and `repository_reference` are **all unchanged** — not merely the credential absent | cannot fail today — no code exists |

**Where each tier's tests live, and why it is not negotiable:**

| Tier | File | Command |
|---|---|---|
| **In-memory** | `packages/product_registry/test/credential_test.dart` | `dart test packages/product_registry/test` |
| **Postgres** | `apps/server/test/integration/product_credential_immutability_postgres_test.dart` | `make test-integration` — the **only** sanctioned exemption from the Docker rule (`AGENTS.md` § Test resource hygiene); disposable Postgres under project `shipit_integration_<pid>`, self-cleaning |

**`GAP-2` is in this table, and its absence was the L11 finding.** It was a landed, passing, **Postgres-only**
test that the tier table did not mention — so a reader asking *"which tier asserts `D-2`?"* had no answer, and
the honest reading of the omission was that nothing asserted it on any tier. It is now mapped, with its file
and line numbers. **`GAP-2` is not part of `D-4`/`D-5`/`D-6` and this revision does not change it**; it is
listed because a tier table that omits a landed test is not complete, and § R.9.6's whole purpose is
completeness per tier.

**`T-C`, `T-F`, `T-G`, `T-J`, `T-K` and `T-L` must exist on **both** tiers**, and
`product_credential_immutability_postgres_test.dart:29-31`
already says why in its own doc comment: *"the CAS branch of `saveProductCredential` must refuse a
key-material change too. Asserted on this tier as well as in-memory, **because a predicate that exists on
only one tier is the same defect this file exists to catch**."* **[5436a4d]** That sentence is now the
specification this revision is measured against, and § R.9.1–R.9.4 are written to satisfy it.

**`T-D` needs Postgres for its second half** and in-memory for its first; both are specified, and it is now
driven through **two entry points** (M7). `T-B` and `GAP-2` are Postgres-only by nature.
**`T-H` and `T-I` need neither tier** — they need the real engine (because § R.5.2's
ordering lives across the endpoint, the service layer and the engine together) and a fake `SecretProvider`.
**`T-L` needs both store tiers plus the real endpoint sequence.** **Nothing here was run by this lane.**

### R.9.7 The store contract doc is a required change — **`product_registry_store.dart:40-68` (M2)**

`D-4`/`D-5`/`D-6` **widen that contract**, and the finding is right that it is named in no change list. Its
current text **[5436a4d]** is accurate for `D-1` and **inaccurate for everything this revision specifies**,
in three specific ways:

| What the doc says now | Why it becomes false or incomplete |
|---|---|
| *"A write whose `credentialId` already exists but whose key material differs MUST throw and MUST leave the stored row untouched."* | **Narrows `D-4` to *differs*.** `D-4` refuses **any** mint onto an existing id, identical or not. A reader who implements to this sentence reproduces `M-3` exactly |
| *"The guard is enforced in the write itself, not by a read before it, on BOTH paths: with a null `expectedVersion` and with a CAS."* | **Still true and still required** — but it describes `D-1`'s predicate only. It says nothing about the scope set (`D-5`) or the evidence rule (`D-6`), so a reader implementing to it delivers `D-1` and believes the contract is met |
| *"When the guard refuses, an implementation reports the immutability refusal rather than a version conflict…"* | **Correct and worth keeping** — and `D-4`/`D-5` must join it, each with its **own** reason (scope ≠ key ≠ identity), or a caller that re-points cannot tell what to do |

**Required changes to the contract doc — FIVE, and each is one sentence:**

1. State that **a null `expectedVersion` marks a mint, and a mint is insert-only**: a write whose
   `credentialId` already exists MUST throw **regardless of whether any value differs**, and MUST leave the
   stored row untouched.
2. State that **`productId` and `repositoryId` are immutable on an existing `credentialId`**, with its own
   refusal reason.
3. State that **recorded evidence may be set and may not be erased** — the non-null → null formulation, over
   **all eight** columns **named explicitly** — and that it applies to the CAS path. *(H9: the eight must be
   written out. A doc that says "the evidence columns" is the same defect as a construct that covers seven.)*
4. State that **these predicates hold identically on every tier**, and name the in-memory store as a tier
   that must implement them with its own constructs rather than by mirroring a SQL string.
5. **★ NEW (M4) — state the ordering guarantee `readCredentialsForProduct` must provide**, because § R.11.2's
   `G-14` selection rule is unimplementable without it:

   > *"`readCredentialsForProduct` returns each product's credentials in a **stable, documented order** —
   > oldest first by `createdAt`, with `credentialId` as the tie-breaker for equal `createdAt` — on **every**
   > tier, so that a caller can select the most recent revoked credential for a repository without
   > re-sorting."*

**Why item 5 belongs in the contract and not in `G-14`'s own implementation.** Today only Tier A orders at
all — `ORDER BY "createdAt" ASC` (`store:389`) — and **Tier B has no ordering whatsoever** (`in_memory:236-238`
is a bare `.where(...)`). So the rule § R.11.2 needs is satisfiable on one tier and silently unsatisfiable on
the other, and a reader implementing `G-14` per tier would produce **two different behaviours from one
specification** — the same class of defect as B4, one level up. **A read's ordering is part of its
contract** whenever a caller is told to rely on it, and the contract is the place to say so.

**Items 4 and 5 are the two this revision would not have written and now would not omit.** Item 4 turns B4
from a defect in a design into a property of the contract; item 5 is what makes `G-14` implementable on both
tiers rather than one.

---

## R.10 — The key flow creates the `Product` row first, and the `hostUnrecognised` trust state

### R.10.0 What `898b07d0` changed, and what it did not

**`898b07d0` RESOLVED, OPTION_A.** The flow that used to end at *"Register product"* now has an explicit
**first step that creates the `Product` row (state `registered`) plus the `RepositoryReference`**;
"Register product" then **commits credential verification**.

**ADR 0018 `:100-102` is UPHELD, not contradicted.** The human's point 2b — registration gated on proven
access — becomes *satisfiable*, because the credential can now be minted before the registration act
completes. Revision 2 called this conflict an **ADR contradiction**; `898b07d0` resolved it **in favour of
the ADR**. `:100-102` must therefore **not** be amended (§ R.17).

**Cycle, now closed.** Revision 2 proved it unsatisfiable: `recordGeneratedCredential` requires
`readRepositoryReference` + `_ensureOwned` (`engine:938-939` **[5436a4d]**), so a credential cannot exist
before the `Product` and `RepositoryReference` do — and those are what registration creates. The fix is
that **the key flow creates them**, and registration stops being their creator.

```dart
createProduct(productId, …)            engine:43   → state: ProductState.registered  (engine:54)
addRepositoryReference(productId, …)   engine:150  → requires the product to exist
recordGeneratedCredential(…)           engine:926  → readRepositoryReference + _ensureOwned
                                                ⇒ requires the repository AND product  ← SATISFIED by step 3
confirmHostKey(…)                      engine:988
recordCredentialCheck(…)               engine:1034
```

There is still **no pre-registration `ProductState`**, and none is introduced: `createProduct` hardcodes
`registered`, and `registered` is already defined as *"Registering is deliberately not governing: a product
is visible here before anything about it has been approved"* (`product_state.dart:24-28`). **The human's
resolution uses that existing semantics rather than inventing a new state**, which is why it needs no
schema or contract change.

**One hazard this creates, which Revision 3 did not see (`G-13`, § R.14.1) — with the FULL column set, because
one of the omitted columns reparents another product's repository (B6).** Both `createProduct` and
`addRepositoryReference` are **destructive on an existing row**, not get-or-create. Their conflict branches
assign **every** column below **[5436a4d]**:

| Write | Conflict branch | Columns it overwrites on conflict |
|---|---|---|
| `saveProduct` (`store:33-102`) | `ON CONFLICT ("productId") DO UPDATE SET` at **`:92-100`** | **`name`**, **`description`**, **`manifestVersion`**, **`state`**, **`createdAt`**, **`updatedAt`**, **`version`** — **seven** |
| `saveRepositoryReference` (`store:127-146`) | `ON CONFLICT ("repositoryId") DO UPDATE SET` at **`:136-142`** | **`productId`**, **`kind`**, **`uri`**, **`provider`**, **`addedAt`**, **`version`** — **six** |

**Two of those are not cosmetic, and `G-13` originally named neither.**

1. **`"productId"` is rewritten — so the conflict branch can REPARENT another product's repository
   reference.** `saveRepositoryReference`'s conflict branch sets `"productId" = EXCLUDED."productId"`
   (`store:137`). Calling `addRepositoryReference` with an existing `repositoryId` and a **different**
   `productId` does not fail, does not warn and does not change any scope column — **it moves the
   repository from one product to another.** That is the ownership graph moving underneath a credential that
   is already attached to it, and it is the *same* cross-product hazard B6 found one layer down: after the
   move, `_ensureOwned(productId, credential.productId, …)` on every credential for that repository resolves
   against the **new** owner. **`G-13`'s read-first discipline is what prevents this**, which makes it
   **load-bearing rather than a footnote** — and it is the reason § R.14.1 step 3a must run *before* the
   decision to create, not only on the create path.
2. **`"state"` and `"createdAt"` are rewritten — so the write un-commits a registered product and falsifies
   its age.** (`"name"` `:93`, `"description"` `:94`, `"manifestVersion"` `:95`, `"state"` `:96`,
   `"createdAt"` `:97`, `"updatedAt"` `:98`, `"version"` `:99`.) `saveProduct`'s conflict branch sets both from `EXCLUDED` (`store:96`, `:97`).

**So the read-first discipline is not tidiness; it is the only thing standing between a re-entry and a
reparented repository or an un-committed product.** Revision 4's `G-13` entry named `state`, `name`,
`createdAt`, `uri` and `addedAt` and **omitted `productId` entirely** — which is the one column whose rewrite
is a **cross-product** event rather than a data-freshness event. The gap entry and this section now carry the
full set.

### R.10.1 The state machine — one new step, then the existing trust machine unchanged

Steps 0–3 are new; everything from step 4 onward is Revision 1 § R.9's machine, carried unchanged.

```
  step 0  SecretProvider.verifyProtection(...)          ← NEW (§ R.5.2). refuses, writes nothing.
    │
  step 1  derive host by parsing THIS REQUEST's repositoryUri    ← CORRECTED (H1).
    │        a Uri parse of a caller-supplied value. NO ROW IS READ:
    │        the RepositoryReference does not exist yet on a first mint.
    │        no host → refuse; writes nothing
    │
  step 2  (reserved — § R.5.7's compensation construct sits between steps 5 and 6)
    │
  step 3  ★ get-or-create Product (state: registered) + RepositoryReference   ← NEW (898b07d0)
    │      ★ READ FIRST; write only when absent (G-13 — both saves are ON CONFLICT DO UPDATE)
    │        ══ the rows now exist. FROM HERE THE PRODUCT IS VISIBLE.
    │           leaving at any later state leaves a visible product (the accepted consequence)
    │
  step 4  mint: generate keypair → put to manager → recordGeneratedCredential
    │        failures at the put/record boundary are compensated by § R.5.7
    │        failures in the get-or-create read re-read and may return alreadyExisted (§ R.14.1)
    │
    ▼
        ┌───────────────────  hostUnrecognised  ────────────────────┐
        │   hostKeyStatus = unknown                                │
        │   permitsConnection = false                              │
        │   user has seen: host name + fingerprint to confirm      │
        │   user has NOT seen: any cancel / reject / skip control  │
        │   ★ the product row ALREADY EXISTS (§ R.11g item 1)       │
        └───────────┬──────────────────────────┬───────────────────┘
                    │ "Trust this host"         │ navigate away
                    │ (confirmHostKey,          │ → Products page
                    │  confirmedBy = actor)     │   state PERSISTS
                    ▼                           │
        ┌────────────────────────┐             │
        │  hostConfirmed         │             │
        │  hostKeyStatus=confirmed│            │
        │  permitsConnection=true │             │
        └───────────┬────────────┘             │
                    │                           │
                    │ "Check access"            │
                    ▼                           │
        ┌────────────────────────┐             │
        │ checkSucceeded /       │             │
        │ checkFailed            │             │
        └───────────┬────────────┘             │
                    │                           │
                    ▼                           │
        ┌────────────────────────┐             │
        │ ★ REGISTER PRODUCT     │             │  ← commits credential verification
        │   (commits; productId  │             │     (898b07d0)
        │    already exists)     │             │
        └────────────────────────┘             │

        ┌────────────────────────┐  confirm a DIFFERENT fingerprint
        │  hostKeyChanged        │◀──────────────────────────────────┐
        │  hostKeyStatus=changed │                                   │
        │  permitsConnection=false│  (also reachable by the transport│
        │  FAILS CLOSED           │   itself presenting a new key)     │
        └────────────────────────┘                                   │
                                                                      │
        On re-entry: hostUnrecognised ──────────────────────────────┘
```

**Note what is *not* in this machine:** a *"Register product"* state that creates the product. That was
the source of the unsatisfiable gate, and it is gone. Registration is now a **commit**, and the product's
existence no longer depends on it.

### R.10.2 `N-1`–`N-9` — carried forward unchanged, with `N-9` added in Revision 3

`design-revision.md:309-343` (`N-1`…`N-7`) and `design-revision.md:504-524` (`N-8`) are carried **without
change**, including `N-1`'s normative no-Cancel rule with its rationale and its cost, and `N-6`'s
`changed` path with no *"trust anyway"*. The reviewer praised these and none of the six resolutions
touches them. `N-8` is **also binding on § R.5.4's remediation copy** — the largest body of new user-facing
text this revision adds.

#### `N-9` — copy must describe custody truthfully, and name no substrate

> **`N-9` — Copy says where the key was generated, says the private half is not in SHIP IT, and names no
> substrate.** No *"on this device"*, no *"the keychain"*, no *"the vault"*, no manager name or address.

**Why this is normative and not a style note.** The current line at `add_product_page.dart:542`
**[5436a4d]** reads *"ed25519 · created on this device · the private half stays in the keychain"*. Both
halves are false: `b869ec24` moved generation **server-side**, and A3 replaced the keychain with an
external manager. The brief's implication #6 already said *"do not describe the credential as 'created on
this device'"*; under A3 the second half is equally wrong, and `27ea6536`'s footer work touches the same
region of the page.

**The exact string the board and the build should carry** — this is the specification the sibling mobile
lane's `Art S` board text is to be reconciled to:

```
ed25519 · generated on the server · the private half stays in the secret manager
```

And what it must **not** say, each with its reason:

| Must not say | Why |
|---|---|
| *"created on this device"* | false since `b869ec24`; contradicts the addendum's own server-side premise |
| *"the private half stays in the keychain"* | A4 is now a **fallback**, selected only in single-host topologies (§ R.1.5). Stating it unconditionally asserts a custody SHIP IT does not have in the default configuration |
| *"the private half never leaves SHIP IT"* / *"is never transmitted"* | the **opposite** of A3 — SHIP IT does not hold it at all |
| any manager vendor, address or path | § R.3.4; the address is infrastructure, not a client fact |

The second helper line, `add_product_page.dart:590` — *"Add this key to the repository's deploy keys with
write access, then check."* — is **instruction, not a custody claim**, and stands unchanged in substance.
It moves to `palette.inkSecondary` with everything else (`N-8`).

### R.10.3 `D-3` still holds — and the accurate statement is **narrower** than Revision 3's, which was over-broad

**The correction.** Revision 3 § R.10.3 and its § R.7.1 threat-model row both said
*"`HostKeyStatus.permitsConnection` has **no runtime enforcer**"* and *"SHIP IT refuses to connect to an
unrecognised host is decorative today."* **Both were over-broad, and the finding that reached me is the
ADR 0018 amendment design's § 3.1** — now tracked on `main` at `5436a4d` as
`docs/engineering/dispatch/tasks/design-adr-0018-amendment/design-revision-2.md` (§ R.17.1), which records:

> *"`HostKeyStatus` **does** have a runtime enforcer — but not the one that matters. … `recordCredentialCheck`
> and the pre-push `requireUsableCredential` both throw `HostKeyNotConfirmedException` unless
> `hostKeyStatus.permitsConnection`, and `canReachRepository` requires a confirmed host. What has **no**
> enforcer is the **transport**: nothing configures git to verify the host key, so no `known_hosts` is
> written and no `StrictHostKeyChecking` is set. … A blanket 'decorative' label would have been false, and
> would have invited a reviewer to trust a gate that exists."*

**I re-verified the whole split at `[5436a4d]`**, because **that lane's revision 1 cited its own base**
(`6220951`, where the guards are at `engine:1033` and `:1148`) and the store-integrity work shifted engine
line numbers by **+14**. Its revision 2 re-verified them; I re-verified them again, independently, at
`5436a4d`:

| Half | Exists? | Verified at **[5436a4d]** |
|---|---|---|
| **Domain enforcer** | **YES** | `recordCredentialCheck` throws unless `permitsConnection` — `engine:1047-1052`. `requireUsableCredential` — `engine:1162-1167`. `confirmHostKey` throws `HostKeyNotConfirmedException` when a *different* fingerprint is presented — **`engine:1003-1015`**, and it records the change at `:1011` before failing closed. `canReachRepository => status.isUsable && hostKeyStatus.permitsConnection` — `repository_credential.dart:128-129` |
| **Transport enforcer** | **NO** | `git_workspace_inspector.dart:106-112` runs `Process.run(git, args)` with **no `environment:`**. A repository-wide grep for `SSH_AUTH_SOCK\|known_hosts\|ssh-keyscan\|StrictHostKeyChecking\|IdentityFile` across `apps` and `packages` returns **0 matches** |

**The accurate normative statement, and it replaces Revision 3's:**

> **SHIP IT will not *record* trust it does not have, and will not *hand out* a credential for an unconfirmed
> host. The connection itself is unverified.** ADR 0018 `:96-99`'s *"ShipIt refuses to connect to an
> unrecognised host"* is therefore **half-implemented**: the refusal to *proceed* is enforced; the refusal
> to *connect* is not. `G-4` and `D-3` are unchanged as open items, and `D-3`'s remaining half is the
> **transport**.

**This is an ADR gap, and that is the correct classification.** ADR 0018 `:96-99` is a **requirement** in
a recorded, read, cited ADR: *"ShipIt refuses to connect to an unrecognised host … ShipIt does not claim to
have verified a host it cannot verify."* The code does not implement the connection half. A design may note
that work is missing; it may not treat an ADR requirement as an optional feature. `G-4` stays open **with
ADR status attached**, and the seam is sized accordingly in § 9.2.

**And under A3 the seam is larger, not smaller.** It must now do two new things at once:

| Capability | Why it is new | Where it is homed |
|---|---|---|
| Host-key TOFU verification with fingerprint presentation and out-of-band confirmation | the **transport half** of `D-3` — see the corrected statement above | ADR 0018 `:96-99`; ADR 0015 `:55-59` (`EnvironmentPolicy`) |
| Resolving material from a secret manager at push time, into an ephemeral identity outside the work tree, zeroed afterwards | new under A3 | ADR 0018 `:67` (the injectable seam the ADR anticipated); § R.1.4 |

**Two security-critical capabilities in one seam, one of which has no precedent anywhere in the
repository.** § 9.2 rates feasibility accordingly, and § 10 asks that the seam get **its own** review
rather than riding in as a side effect of this feature.

---

## R.11 — Client state model — carried, plus the server-side change that makes state 4 renderable

`design-revision.md:345-372` is carried: two orthogonal axes (`AccessStatus` kept unchanged;
`HostTrustStatus` new and mirroring the server enum 1:1), and `canRegister` becoming two-factor to mirror
the server's own `canReachRepository` (`repository_credential.dart:128-129`).

```dart
canRegister = productName.isNotEmpty
           && repositorySshUrl is valid
           && credentialId != null
           && hostTrustStatus == confirmed
           && accessStatus   == verified
           && !isRegistering
```

### R.11.1 The five client-observable states that must be visually distinct

`898b07d0`'s accepted consequence — **a visible product may exist with no usable credential** — is a
third derived fact, and **the UI must distinguish it**. It is not a variant of an existing axis; it is
their combination:

> **`RegistrationCommitState` = `committed` ⟺ some credential on this product has `canReachRepository ==
> true`.** When `notCommitted`, the product **exists**, is listed on the Products page, and has a repository
> reference — and none of that means it is usable.

This is the normative list; a reviewer can check each against a board:

| # | `RegistrationCommitState` | Credential | Host trust | What the user must be able to tell |
|---|---|---|---|---|
| 1 | `notCommitted` | **none** | — | *"no key generated yet"* — matches today's copy at `product_detail_page.dart:676` |
| 2 | `notCommitted` | `generated` | `unknown` | **the Unknown-host state**: a product that exists, is waiting on *you*, and has no escape control on the card (`N-1`) |
| 3 | `notCommitted` | `generated` / `failing` | `confirmed` | access not yet proven — install the key, *or* the network is at fault (§ R.13.2) |
| 4 | `notCommitted` | **`revoked`** | any | **this key was withdrawn; a new one must be generated and re-installed** — not *"try again"* |
| 5 | `committed` | `verified` | `confirmed` | access proven, with `lastVerifiedAt` shown as a fact (ADR 0018 `:100-102`) |

### R.11.2 State 4 is not derivable from the read path this revision keeps — **the required server change (B3)**

**The defect, stated exactly.** Revision 3's § R.16 reuse row 46 specified `RegistrationCommitState` as
**client-derived** from `ProductDetailView.credentials` with **"no new server field"**, while § R.12 said a
revoked credential *"does not come back — that is state 4 of § R.11.1"*. **Both cannot hold.** The chain,
verified at `[5436a4d]`:

1. `loadProductDetail` (`control_plane_service.dart:360-367`) populates `credentials` **exclusively** from
   `productRegistryStore.readActiveCredentialForRepository(repo.repositoryId)` — a loop over
   `context.repositories` that appends only non-null results. There is **no second source**.
2. `readActiveCredentialForRepository` selects `WHERE "repositoryId" = @repositoryId AND "status" <> 'revoked'`
   (`store:370-381`), and the in-memory tier filters `c.status != CredentialStatus.revoked`
   (`in_memory:220-231`). **A revoked row is never emitted by either tier.**
3. `ProductDetailView` (`repository_credential_view.yaml`, `product_detail_view.yaml`) carries **no
   revoked summary** — no count, no "last withdrawn at", nothing.
4. `RepositoryCredentialView.status` **already** declares *"generated | verified | failing | revoked"*
   (`repository_credential_view.yaml:15` **[5436a4d]**). The wire type can already express state 4.

**So state 4 is indistinguishable from state 1.** A repository whose only credential was revoked reaches the
client as *"no key generated yet"* — while, in reality, a key **existed, was withdrawn, and may still be
installed in the repository's deploy keys**. The user is told to generate one; the one they generate is a
*second* key beside an orphaned first; and the account of *why* is gone. This is worse than a missing UI
state: it is a **false statement about the user's infrastructure**.

**Revision 3's stated cause was wrong, and correcting it matters.** Revision 3 § R.11.1 said: *"State 4 is
the one that is easy to omit and the one the old model **cannot express**: `AccessStatus` has no `revoked`
member, so a revoked credential currently renders as one of the five existing values."* That **mislocates
the cause by one layer.** `AccessStatus` is a **client-side presentation enum**, and it is *downstream* of a
query that never emits the row: adding a `revoked` member to `AccessStatus` would give the client a value
it can never be handed. **The fix is a query change, not a new model** — as the finding states, and as the
wire type's own `status` comment confirms.

#### The required deliverable — `G-14`

> **`G-14` — `loadProductDetail` must source each repository's credential from a read that includes
> revoked rows. No new model field, no new wire field, no schema change, no migration.**

Precisely:

| # | Change | Location **[5436a4d]** | Kind |
|---|---|---|---|
| 1 | Read the product's credentials through the existing **`readCredentialsForProduct(productId)`** — whose contract already says *"Every credential ever issued for [productId], **including revoked ones**, so the historical record stays readable"* (`product_registry_store.dart:78-82`), whose Postgres implementation is `SELECT * … WHERE "productId" = @productId ORDER BY "createdAt" ASC` (`store:384-393`, order at `:389`) and whose in-memory implementation is a bare `where(c.productId == productId)` filter with **no ordering** (`in_memory:233-238`) — **which § R.9.7's item 5 requires changing** | `control_plane_service.dart:360-367` | **one method's data source** |
| 2 | Select, **per repository, iterating repositories** (not credentials): the **active** credential if one exists, otherwise the **most recent revoked** one — greatest `createdAt`, `credentialId` as tie-breaker. So a repository has exactly one entry and the revoked case renders as state 4 rather than as state 1. **The direction, the ordering and the tie-breaker are specified below and are normative** | same | **selection rule**, fully specified |
| 3 | **No new field — and no field is being removed either.** `RepositoryCredentialView` already carries **`status`** (`:15`), whose own doc comment already lists `revoked` as a legal value (`:14`). **State 4 therefore renders from `status` alone.** ⚠ **Revision 4's version of this row was false in the implementer's favour and against them:** it claimed *"`revokedAt`/`revokedReason` are already on the view"*. **They are not.** The full field list is `credentialId`, `repositoryId`, `referenceName`, `fingerprint`, `algorithm`, `status`, `hostKeyStatus`, `host`, `canReachRepository`, `lastVerifiedAt`, `lastVerifiedBy`, `lastFailureReason`, `hostConfirmedAt`, `hostConfirmedBy` (`repository_credential_view.yaml:8-25`) — **no `revokedAt`, no `revokedReason`.** B3's *conclusion* still holds: **no new field is needed and no migration is needed** | — | **none** |

#### The selection rule, stated completely (M4)

Revision 4 specified *"Select, per repository, the **active** credential if one exists and otherwise the
**most recent revoked** one"* and left three things unstated. **All three are now stated, because each one
changes what the implementer writes.**

**(a) The iteration DIRECTION is repository-driven, and it must stay that way.** The loop today is
`for (final repo in context.repositories)` (`control_plane_service.dart:363-367`), and `ProductDetailView`
declares `credentials: List<RepositoryCredentialView>` under the doc comment *"One credential per repository;
absent where none has been generated"* (`product_detail_view.yaml:11-12`). **`G-14` therefore iterates
repositories and, for each, selects one credential — it does NOT iterate credentials and group them by
repository.** The difference is not cosmetic: credential-driven iteration produces **N cards for a repository
whose credentials all predate the product's current reference**, and emits **no entry at all for a repository
with no credentials** — which is exactly the shape § R.11.1 state 1 needs to be able to render. Credential-
driven iteration contradicts the view's own cardinality contract.

**(b) Ordering is REQUIRED, and it must be provided on BOTH tiers.** The selection needs a total order over
revoked rows to pick "the most recent". Today: **Tier A orders** — `ORDER BY "createdAt" ASC`
(`store:389`); **Tier B has no ordering at all** — `in_memory:236-238` is a bare
`.where((c) => c.productId == productId).toList(growable: false)`, whose order is map insertion order and is
not a contract anything may rely on. So the rule as Revision 4 wrote it is satisfiable on one tier and
**silently unsatisfiable** on the other, and an implementer following it per tier ships two behaviours from one
specification. **Therefore § R.9.7's item 5 puts the ordering in the store contract:**

> *"`readCredentialsForProduct` returns credentials in a stable documented order — oldest first by `createdAt`,
> `credentialId` as tie-breaker — on **every** tier."*

**(c) "Most recent revoked" means last in that order, and the `version` gloss is REMOVED.** Revision 4 wrote
*"so 'most recent' = last in that order = **highest `version`**"*. **That gloss is wrong across a rotation
chain**, and wrong in a way that would produce the wrong credential: `rotateCredential` mints the replacement
through `recordGeneratedCredential`, which constructs the new row with **`version: 1`** (`engine:977`) — the
optimistic-lock counter restarts on every rotation. So within a repository's history `version` is `1, 1, 1, …`
and *"highest `version`"* is a **tie**, broken by nothing. **`version` is not an ordering key and is not used
as one here.** The correct statement is the chain's own chronology: **most recent = greatest `createdAt`**,
because `createdAt` is set once at construction (`engine:963-964`, `:974`) and § R.9.5's `D-4` makes it
**unwritable on an existing row** — so it is the one column in the chain that cannot be rewritten. Equal
`createdAt` (same-microsecond mints) are broken by `credentialId`, per item 5.

**Why "most recent revoked" and not "all credentials".** `readCredentialsForProduct` returns the product's
whole credential history, and rotation leaves several revoked rows per repository over time
(`rotateCredential` mints a new id each time, `engine:1098-1133`). Emitting them all would put N cards on a
repository with 1. Emitting none is today's bug. **One entry per repository, preferring active, is the rule
that makes the five states exhaustive** — and it is the same cardinality the existing loop already
produces, so the change is a data source plus a selection, not a reshaping.

**The client side, unchanged and unchanged by design.** `RegistrationCommitState` stays **client-derived**,
exactly as Revision 3 specified — so row 46's *"client-derived"* claim **survives**, and only its *"no new
server field"* half needed qualifying. `AccessStatus` gains a `revoked` member, because after `G-14` the
client can be handed one. **State 4 is then a rendering decision, not a data-availability problem**, which
is what Revision 3 should have said.

**Dependency, and it is a real ordering constraint.** `G-14` must land **before** the revoke endpoint's UI
work, or a shipped revoke produces state 1's copy — which is exactly the situation § R.14.3 creates the
endpoint to avoid. § 10.1 item 5 carries the ordering to the Manager.

#### One more thing this section fixes by accident

`G-14` also makes § R.12's **first** claim true rather than aspirational. Revision 3's § R.12 table used the
revoked-row exclusion as *evidence* for *"a revoked credential correctly does not come back"*. That is a
**read-path accident being read as a designed property**: the query excludes revoked rows because it answers
a different question (*what credential is in force*), not because *hiding a revocation* is desirable. With
`G-14` the two questions are answered by two reads, each correct for its purpose.

### R.11g Consumption contract for `design-addproduct-mobile` — binding, from `898b07d0` **and `ae1c1f79`**

The sibling lane owns the boards (`C-11`). **This lane authors and edits none of them.** Its follow-up
action — *"Re-ground the mobile boards' Unknown-host state on the split — the product row now exists before
trust"* — couples the two revisions, so this revision states what the boards must show, so the sibling can
consume it rather than infer it. **Item 5 is new in this revision** and discharges `ae1c1f79`'s second
follow-up action, which named this lane as its owner.

1. **The Unknown-host state depicts a product that already exists.** The `Product` row (state
   `registered`) and the `RepositoryReference` exist **before** the trust decision is taken — § R.10.1
   step 3. **No board may depict *"nothing is saved yet"* at that state.**
2. **Leaving at Unknown-host leaves a visible product.** That is the accepted consequence, and the boards
   must not imply the flow is discardable.
3. **Therefore the Add Product flow must be re-enterable from the product, not only from the Products
   page's "Add product" control.** Without this, the accepted consequence becomes a **dead end** — the
   exact failure human point 2d objected to, arriving by a different route. This is a **requirement on
   the sibling lane's design**, not an observation: `ProductDetailPage` needs a resume affordance into the
   credential flow. Listed in § 10 as a Manager notification, because the sibling lane's revision must
   carry it.
4. **The custody line is the string in § R.10.2**, and the board's `Art S` text is to be reconciled to it.
5. **★ NEW (H4) — after a refused mint, the Products list is UNCHANGED, and no board may imply otherwise.**
   `ae1c1f79` decided this: *"An outage leaves the user's state exactly as it was — nothing to clean up,
   nothing to reason about, and no visible product that cannot be used."* Concretely:
   - The substrate-refusal state is **not** state 1, **not** state 2 and **not** state 3. It is a
     **separate surface**: the Add Product sheet is still open, the product was never created, and the
     board shows § R.5.4's remediation for the named cause.
   - **The Unknown-host board must not double as the refused-mint board**, even though both are "the user
     is stuck". They differ in what exists afterwards: Unknown-host leaves a **visible product**;
     refused-mint leaves **nothing**. Rendering them the same would tell the user to look for a product
     that does not exist, and would quietly re-open the dead end `ae1c1f79` closed.
   - **After the operator fixes the substrate and the user retries, the flow must reach state 2** — a
     product now exists and is waiting on the host confirmation — with **no intermediate "product created"
     state shown**, because nothing was created on the first attempt.
6. **No board may render a credential reference** (§ R.3.4).
7. **The footer follows `27ea6536` verbatim**, per the human's correction after checking the boards
   directly. **Desktop** (`S - Add Product - Unknown host`, `S - Add Product - Verified`) = a divider and a
   **right-aligned** `Show technical details` **text button**, **no footer copy**. **Mobile** (`BPM - Add
   Product`) = a **left-aligned** `Show technical details` button with **no divider**, **no footer copy**.
   The human's instruction — *"Stay true to both designs in Penpot and in code"* — governs, and **the
   boards are authoritative over both lanes' readings**.

   **Implementation context, corrected against source (L8) — every line below re-read at `5436a4d`:**

   | What | Where **[5436a4d]** | Note |
   |---|---|---|
   | `_buildFooter` — **DEFINITION** | `add_product_page.dart:375` | `Widget _buildFooter(BuildContext context) {` |
   | `_buildFooter` — **CALL SITE** | **`add_product_page.dart:314`** | `_buildFooter(context),` inside `_DesktopAddProduct` (`:276`–`:391`) |
   | The footer **copy** it renders | `add_product_page.dart:382-386` (string literal spans `:383-384`) | *"Your decision is recorded permanently. The same piece of work then continues — nothing is restarted."* |
   | The **duplicated** `ContentRule` | `:380` (inside `_buildFooter`) and `:300` (in the desktop column, above the two-column row) | `design_primitives.dart:396` paints it **unconditionally** |
   | `_DesktopAddProduct` | `:276`–`:390` | contains the `:314` call; `_buildFooter` is `:375-389` |
   | **Desktop** `TechnicalDetails` — **definition site** | **`add_product_page.dart:316`** | inside `_DesktopAddProduct`, at `:316-328` |
   | ↳ its **`note:`** | **`:317-319`** | *"Registering records the product. Nothing is governed until you approve a baseline."* |
   | `_MobileAddProduct` | `:774`–`:1117` (end of file) | renders no `_buildFooter` — correct |
   | **Mobile** `TechnicalDetails` — **definition site** | **`add_product_page.dart:925`** | inside `_MobileAddProduct`, at `:925-938` |
   | ↳ its **`note:`** | **`:926-928`** | the **same string** as desktop |

   **Two of Revision 4's claims here were wrong, and one of them is what the sibling lane would have built
   from (L8).** Revision 4 wrote *"`_buildFooter` (`add_product_page.dart:375`, called from the desktop branch
   at `:314`, with its copy at `:383`)"* — **that is correct**: definition `:375`, call `:314`, copy `:383`.
   But Revision 4 also wrote *"`_MobileAddProduct` (`:774`) renders no footer copy and **its `TechnicalDetails`
   (`:925`) has no `note:`**"* — **false in two ways.** `:925` is inside `_MobileAddProduct`, so it is the
   **mobile** site, not the desktop one; and it **does** carry a `note:`, at `:926-928`. **"No footer copy" is
   therefore two `note:` sites plus a `_buildFooter`**, not one: the desktop note at `:317-319`, the mobile
   note at `:926-928`, and the `_buildFooter` block at `:375-389` with its copy at `:383-384`.

   **So the removal `27ea6536` implies is: delete `_buildFooter` and pass `note: null` at BOTH
   `TechnicalDetails` call sites** — `:317-319` and `:926-928`. `design_primitives.dart:398-410` shows that
   `note: null` already produces the desktop spec *for free* (`Expanded(child: widget.note == null ? const
   SizedBox.shrink() : …)`), and that the **mobile** spec — no divider, start-aligned disclosure — is **not
   expressible today**, because `:396` paints the `ContentRule` unconditionally. **That is a shared-component
   requirement for the design-system owner, not for this lane and not for the sibling lane** — it is the
   sibling lane's own finding, and I record it here only so the two lanes do not each solve it separately.

   **This revision changes none of the code** — it records the specification, with the numbers corrected, so
   both lanes reconcile to one of them. **A sibling that consumed Revision 4's numbers would have been pointed
   at the wrong function boundaries and told the mobile footer note does not exist.**

**Consumption status, so no one assumes this contract has been picked up.** The sibling lane's current
artifact (`design-addproduct-mobile/design-revision-4.md`, **tracked on `main` at `43d328b`**, base `77c19f1`)
carries **no** `RegistrationCommitState` model and **no** reference to § R.11g — `grep` returns nothing for
either. **Items 1, 2, 4, 6 and 7 were notified and are evidently consumed; items 3 and 5 are not yet.**
Item 5 is new here, so "not yet" is expected rather than a defect. § 10.1 item 6 carries the notification.

#### ★ What the sibling lane needs from § R.11g — stated so it does not need me to be reachable

**This block exists because the sibling lane is blocked and cannot ask.** Design Revision 4 of the mobile
boards (`design-addproduct-mobile/`) is **blocked on Penpot**, and the block is not a missing plugin: per
`docs/engineering/dispatch/tasks/design-correct-addproduct-mobile-5/correction-report-5-retry.md` § B1 and
`WORK_STATE.md`'s `INFRASTRUCTURE_BLOCKED`, `penpot_execute_code` fails with *"No Penpot instance connected
for user token"* on **every instance-bound call, before the JavaScript executes** (proved by a `try`/`catch`
whose `catch` never ran) — a token-to-instance binding fault. **`docs/adr/**`, the mobile lane's directory and
Penpot are all outside my `OWNED_PATHS`, so I cannot unblock it, re-ground it, or edit a byte of it.** What I
can do is make § R.11g self-sufficient. **These are the four things the next mobile pass needs from me, and
they are the four it cannot re-derive:**

**1. Item 3, in the form of a requirement — not an observation.** The flow must be **re-enterable from the
product**, not only from the Products page's *"Add product"* control. `ProductDetailPage` needs a resume
affordance into the credential flow. **Why it cannot be optional:** `898b07d0`'s accepted consequence is a
**visible product that exists but is not yet usable**; without a resume route, leaving the flow at Unknown-host
converts that consequence into a dead end — the exact failure human point 2d objected to, arriving by a
different route. **What the board must therefore not show:** anything implying the product can be discarded,
and any state implying *"nothing is saved yet"* (item 1). **This is a binding requirement on the sibling's
design**, and it is the one item the sibling has explicitly not yet picked up.

**2. Item 7's corrected numbers — because Revision 4's were wrong and the sibling would have consumed them.**
See item 7's table. The load-bearing corrections: **`_buildFooter`'s definition is `:375` and its call site is
`:314`**; the footer copy is `:383-384`; **the duplicated `ContentRule` is `:380` and `:300`**;
`_DesktopAddProduct` is `:276-390`; `_MobileAddProduct` is `:774` to end-of-file; **the desktop
`TechnicalDetails` is `:316` with its `note:` at `:317-319`; the mobile `TechnicalDetails` is `:925` with its
`note:` at `:926-928`** — **the mobile one EXISTS**, which is the specific thing Revision 4 denied. The
removal `27ea6536` implies is therefore **three edits**, not two: delete `_buildFooter` (`:375-389`) and pass
`note: null` at **both** `:317` and `:926`. The sibling's own `D-3` reached the same three sites; that
agreement is the confirmation that this correction landed on the right lines.

**3. The one shared-component requirement neither lane can own.** `design_primitives.dart:396` paints
`TechnicalDetails`' `ContentRule` unconditionally and `:398-410` renders `Row[Expanded(note ?? SizedBox.shrink()),
InlineLink]`. So **the desktop spec is produced for free by `note: null`**, and **the mobile spec — no divider,
start-aligned disclosure — is NOT expressible today**. That is a **shared-primitive change for the
design-system owner**; it is neither this lane's nor the sibling's to make, and it is recorded here so the two
lanes do not each open a separate item for it.

**4. The custody string, and why the boards are currently wrong rather than merely stale.** § R.10.2's `N-9`
string is **`ed25519 · generated on the server · the private half stays in the secret manager`** (item 4). The
sibling's `Art S` layer reads *"ed25519 · private half stays server-side"* on all four boards, and **that is
now false in the opposite direction from Revision 4's fear**: under `9417f8bf` OPTION_C (A3) SHIP IT **never
holds the private half at all**, so "stays server-side" asserts a custody model the architecture retired.
**This is wrong security copy on four boards, and it cannot be corrected without Penpot** — which is a second,
independent reason the sibling is blocked, and a stronger one than staleness.

**And one thing the sibling must NOT take from me:** § R.11g is a **consumption contract**. It does not
specify copy, tokens or layout — `N-8` binds the tokens automatically and `27ea6536` owns the footer
structure. **Nothing in items 1–7 authorises the sibling to skip its own design work; the point is that it
does not have to re-derive any of this.**

---

## R.12 — The read path — carried, no longer conditional, and no longer carrying a false claim

`design-revision.md:374-396`'s table is carried, with **row 1 rewritten** (B3) and one paragraph deleted.

Revision 2 recorded: *"**This row depends on OPEN-D4-2.** If the `Product`/`RepositoryReference` rows
exist when the user leaves (option 1) the read path above is exact. If they do not, the credential cannot
exist at all today."* **`898b07d0` chose option 1. The dependency is discharged.** The table is now exact
as written, with no conditional.

**Why the human's addendum is now literally true.** `898b07d0`: *"if down the road we want to create that
product we'll find the key ready to be verified again."* Under § R.10 the rows are created at step 3 and
the credential at step 4, so on re-entry:

```
Add Product re-entry
  → Product row exists (state registered)           ← step 3 already ran
  → RepositoryReference exists                      ← step 3 already ran
  → readActiveCredentialForRepository(repositoryId) → credential row exists; status and host state preserved
  → restore publicKey  (a pure READ of product_credential.publicKey — never regenerated)
  → restore fingerprint, hostKeyStatus, hostConfirmedAt/By
  → user re-enters at the trust step or the check step
```

**And the re-entry must not re-run step 3's writes (`G-13`).** Because `saveProduct` and
`saveRepositoryReference` are both `ON CONFLICT DO UPDATE` (§ R.10.0), a naive re-entry resets the
product's `state` to `registered` and rewrites its `name`, `createdAt` and the reference's `uri` and
`addedAt` — which would un-commit a registered product back to `registered` and falsify the record's age.
**Step 3 is read-first, write-only-when-absent**, and that is normative.

| Claim | Field | Read path |
|---|---|---|
| The credential survives navigation | `product_credential.credentialId` | `readActiveCredentialForRepository(repositoryId)` — revoked rows excluded (`store:370-381`; `in_memory:221-232`), which is **correct for this question** (*what credential is in force*) |
| **A revocation is visible to the user** *(rewritten, B3)* | `product_credential.status` | **`G-14` — a second read**: `readCredentialsForProduct(productId)`, which returns revoked rows too (`store:384-393`; `in_memory:233-238`, **unordered today** — § R.9.7 item 5). **Without it, § R.11.1's state 4 is not derivable and the user is told "no key generated yet" about a withdrawn key.** Revision 3 used the *same* exclusion as evidence that a revoked credential *"correctly does not come back — that is state 4"*; the exclusion does not produce state 4, it hides it |
| *"The key is still there"* | `product_credential.publicKey` | re-copy is a pure **read**; it never regenerates |
| The key is still the same key | `product_credential.fingerprint` | **`D-1` makes this true at the store** (§ R.8.3) — the restored key is byte-identical *because the material cannot have changed* |
| Host trust survives too | `hostKeyStatus`, `hostKeyFingerprint`, `hostConfirmedAt`, `hostConfirmedBy` | **Conditional on `D-4`** — an identical-material re-mint nulls them today (§ R.9.1) |
| Recorded evidence is never erased | `revokedAt`, `revokedReason`, `lastVerifiedAt`, **`lastFailureReason`** | **Conditional on `D-6`** (§ R.9.4) — the CAS branch can null all **eight** today, `lastFailureReason` included (H9) |
| The user is not blocked | `ProductState.registered` semantics | `product_state.dart:24-28`: *"Registering is deliberately not governing: a product is visible here before anything about it has been approved"* — which is exactly the semantics option 1 relies on |

**One honest addition.** Under A3 the private half is not on this machine at all, so *"the key is on the
machine"* from the addendum is now literally false — and **it was never the property being relied on.** The
property is that the *record* persists and the *material* is retrievable from the manager. If the manager
is down on re-entry, the credential still reads back (the first row is a database read) but **cannot be
used** until the manager answers, which surfaces as `secretReferenceMissing` (§ R.13.2) rather than as a
silent failure.

---

## R.13 — "Check access" — carried, bound to the substrate

### R.13.1 The normative definition — carried verbatim

`design-revision.md:402-415`. **Check access** performs exactly one real SSH transport attempt to the
repository's host, using the private half for **this** credential, and records the outcome. It generates
nothing, installs nothing, and changes no host-trust state. Success proves the key is installed and
accepted **and** that the host presented the confirmed fingerprint. It proves nothing about the user's
typing, the baseline, or approval. It is repeatable: N presses → N recorded outcomes on the **same**
`credentialId` and **one** `product_credential` row.

**The check path also contains no generation call** — carried from Revision 2, and it is what stops the
check control from minting. **And it must contain no `put`** — § R.1.7: the check path *resolves* a
handle, it never creates one, so the compensation construct is not on this path and cannot leak into it.

### R.13.2 The outcome taxonomy — carried, plus one cause

`design-revision.md:417-434`'s five-way taxonomy is carried, with its **User sees** column now bound to
`palette.inkSecondary` (`N-8`), and one row added:

| `failureKind` | Detected how | State transition | User sees |
|---|---|---|---|
| `hostUntrusted` | `!hostKeyStatus.permitsConnection` | **none** | *"Confirm this host's key first."* |
| `hostKeyChanged` | transport presented a fingerprint ≠ the confirmed one | `hostKeyStatus → changed`, then **refuse** | security stop per `N-6`; no *"trust anyway"* |
| `credentialNotInstalled` | transport reached the host; the host rejected the key | `status → failing`, reason recorded | *"Install the public key as a deploy key with **write** access, then check again."* |
| `networkUnreachable` | DNS/TCP/timeout before authentication | `status → failing` | *"Could not reach `<host>`."* — explicitly **not** *"install the key"* |
| `revoked` | `status == revoked` | **none** | withdrawn; rotation required (§ R.11.1 state 4) |
| **`secretReferenceMissing`** | **NEW under A3** — `SecretProvider.resolve` found nothing | **none** | *"The stored reference for this repository no longer exists in the secret manager — it was deleted outside SHIP IT. This credential cannot be used and cannot be recovered. Generate a new key and install it."* |

**`secretReferenceMissing` gets its own row, not a fold into `networkUnreachable`**, because the two demand
opposite actions — one is *"check the network"*, the other is *"rotate the key"* — and folding them into
one string is precisely the defect `design-revision.md:432-434` identifies in the *existing* copy. It is
also the only way § R.5.4's out-of-band case surfaces, and it is why § R.5.4 specifies no mint-time copy
for it.

**One addition this revision makes, and it is a consequence of B2.** `secretReferenceMissing` is now
reachable **immediately after a successful mint** if § R.5.7 is implemented wrongly — a `finally` that
destroys the handle on the success path produces a credential that reads back fine and fails on first use.
**That failure mode is invisible until the first push**, which is why `T-I` (§ R.9.6) asserts
`resolve(handle)` at mint time rather than at push time.

---

## R.14 — The endpoints

Placed on the existing `ProductRegistryEndpoints`, which states *"an endpoint never sets state directly"*.

### R.14.1 `mintOrReadDeployKey` — **the whole sequence, corrected**

**The signature. Revision 3's had no `repositoryId`, yet three of its steps needed one (H2).** The endpoint
now takes it:

```dart
Future<DeployPublicKeyView> mintOrReadDeployKey(Session session, {
  required String productId,      // the product the flow is registering
  required String repositoryId,   // REQUIRED — see "where repositoryId comes from" below
  required String name,           // product name — step 3 creates the Product
  required String repositoryUri,  // parsed in step 1; written to the RepositoryReference in step 3
})
```

**Where `repositoryId` comes from, and the one thing this design does not do.** `resolveRepository`
states the rule this design holds to: *"Durable repository identity — never derived from worktree/path/process"*
(**`engine:175-183`**, doc comment at `:175`, method at `:176-183` **[5436a4d]**). So:

- **`repositoryId` is NOT derived from `repositoryUri` inside this endpoint.** Deriving it here would make
  the get-or-create non-idempotent under a URI edit — a corrected SSH URL would silently create a **second**
  credential identity for the same repository — and it would contradict `engine:175`.
- The **caller supplies it**, which is what the existing flow already does: `add_product_page.dart:169-175`
  calls `addRepositoryReference(productId: …, repositoryId: productId /* "Use productId as repositoryId for
  simplicity" */, uri: …)` **[5436a4d]**. **That placeholder is a UI-layer simplification, not an identity
  rule, and this design does not adopt it as one**: a single-repository product sharing its id namespace
  with a multi-repository one is precisely the confusion `D-5` makes load-bearing. Retiring it is recorded
  as a required change in § 10.1 item 7; **who issues the id (client-generated and retained, or
  server-minted and returned) is not decided here**, because both satisfy this design and choosing between
  them is a product decision about the client, not about this endpoint's correctness.
- On **re-entry** the caller must supply the **same** `repositoryId` it supplied first time — which § R.12's
  re-entry requires anyway, since `readActiveCredentialForRepository(repositoryId)` is keyed on it.
- **⚠ The placeholder makes the cross-product case trivially reachable, and that is why B6 matters here.**
  `repositoryId: productId` means every product's single repository carries **that product's own id**. A
  client that sends `productId: 'A'` with `repositoryId: 'B'` — a typo, a stale client, a crafted request on
  an endpoint with **no authentication** (§ R.15.1) — asks for *B's* credential while claiming to be *A*.
  **The retire-the-placeholder action and the ownership step are the same fix seen from two sides**: with
  3a in place the placeholder is merely redundant; without it, it is a disclosure.

**The sequence, in order. Every step cites the section that owns it.**

1. **`SecretProvider.verifyProtection(policy)`** — **step 0** (§ R.5.2). Refuses with § R.5.3's 503 and
   writes nothing. **Decided by `ae1c1f79`**: refusal creates nothing at any tier.
2. **Derive `host` by parsing `repositoryUri`** — **step 1** (§ R.5.2). **No row is read** (H1). If no host
   can be derived → refuse (`repositoryUriUnparseable`), write nothing.
3. **get-or-create `Product` (`registered`) and `RepositoryReference` (`G-13`)** — **step 3** (§ R.5.2).
   **READ FIRST; WRITE ONLY WHEN THE ROW IS ABSENT** — `createProduct` (`engine:43-61`) and
   `addRepositoryReference` (`engine:150-170`) are both `ON CONFLICT DO UPDATE` (`store:92-100`,
   `:136-142` **[5436a4d]**), so calling either on an existing row rewrites its columns in place. Use
   `readProduct` / `readRepositoryReference` to test absence; `readProduct` throws
   `ProductNotFoundException` and `readRepositoryReference` throws `RepositoryNotFoundException`
   (`exceptions.dart:3`, `:12`), so **catch-and-create** is the test.

   **★ Step 3a — OWNERSHIP. Normative, and it is the only thing standing between this endpoint and a
   cross-product disclosure (B6).**

   > **Immediately after `readRepositoryReference(repositoryId)` returns, and BEFORE deciding whether to
   > create anything, establish that the reference belongs to `productId`. If it does not, throw
   > `CrossProductAccessException` (`exceptions.dart:59`). Never reach step 4 for a foreign
   > `repositoryId`, on any code path, at any tier.**

   Two forms are acceptable and either satisfies the obligation:

   | Form | How | Note |
   |---|---|---|
   | **(a) Compare directly** — cheapest | `final ref = await readRepositoryReference(repositoryId); if (ref.productId != productId) throw CrossProductAccessException('repository $repositoryId belongs to product ${ref.productId}, not $productId');` | literally what `_ensureOwned` (`engine:1784-1790`) does |
   | **(b) Delegate to the domain** — preferred | `await engine.resolveRepository(productId, repositoryId)` (`engine:176-183`), which reads the reference **and** calls `_ensureOwned` at `:181`. Its `RepositoryNotFoundException` is then **the create signal** — so it collapses step 3's absence test and step 3a's ownership check into one call | keeps `_ensureOwned` in the domain, where it belongs, and keeps the endpoint from re-implementing a security check |

   **On a first mint** the reference is absent, `resolveRepository` throws `RepositoryNotFoundException`, and
   that is the **create** signal — so the ownership check is vacuously satisfied for a repository this
   endpoint is creating, and only ever bites when the repository already exists **and belongs to someone else**.

   **Why this step had to be added, stated as the defect (B6).** Revision 4 corrected `H2` by moving the
   get-or-create read to step 4 and switching it to the **store** method, and then justified that with two
   sentences. **Both were false:**

   - *"`readActiveCredentialForRepository` is a pure lookup that returns `null` and **never** resolves a
     reference — and **by step 4 ownership is already established, because step 3 created the reference under
     `productId`**."* **Step 3 does not establish ownership**, and on exactly the cross-product case **step 3
     performs no write at all**: `addRepositoryReference` calls `await _store.readProduct(productId)`
     (`engine:159`) — which the code itself annotates `// existence + scope` and which is in fact
     **existence only**; it never calls `_ensureOwned` — and then `saveRepositoryReference`. Under `G-13`'s
     read-first discipline the write is **skipped whenever the reference already exists**. So the rule is
     *"create it under `productId`"*, and on a reference that exists it does nothing at all.
   - *"`_ensureOwned` is the engine's job; **this endpoint does not call it and does not bypass it**."*
     **Choosing the store method is the bypass.** `readActiveCredentialForRepository`
     (`store:370-381`; `in_memory:221-232`) filters on `"repositoryId" = @repositoryId AND "status" <> 'revoked'`
     and **has no notion of a product and no `_ensureOwned` at all**. The engine's `readActiveCredential`
     (`engine:1135-1142`) opens with `readRepositoryReference` **then** `_ensureOwned` at `:1140` — that
     guard is the *only* thing that made the old path safe, and the fix removed the call that contained it.

   **The consequence, precisely.** `mintOrReadDeployKey(productId: 'A', repositoryId: <a repository of
   product 'B'>, …)` would step 3's read, find the reference present, **skip the write** (so no
   `_ensureOwned` is ever reached), reach step 4, and receive **B's** `publicKey`, `credentialId`, `status`,
   `hostKeyStatus` and `alreadyExisted: true` — on an endpoint this revision's own § R.15.1 records as
   carrying **no authentication services** (`apps/server/lib/server.dart:71-73`) and with loopback pinning
   **un-implemented** (`G-4`/A3). **No step of Revision 4's § R.14.1 raised the `CrossProductAccessException`
   its own error table promised.** `T-L` (§ R.9.6) asserts the fix on **both** store tiers.

   **Read-first at step 3 is NOT an ownership check, and this revision says so in the sentence that needs
   it.** Absence-testing and ownership-testing are different questions answered by different methods
   (`readRepositoryReference` vs `resolveRepository`), and a get-or-create loop naturally answers only the
   first. **That is why step 4's store call is safe: ownership was established one step earlier, at 3a — not
   inherited from step 3's write, which on this case does not happen.**
4. **Get-or-create read for an existing active credential** — `productRegistryStore.readActiveCredentialForRepository(repositoryId)`.
   **If one exists → return it with `alreadyExisted: true`. Never generate.**
   **Three corrections to Revision 3 here (H2), and a fourth added by B6:**
   - **It runs at step 4, after step 3 — not before it.** Revision 3 put it at step 2, ahead of the
     `RepositoryReference` it needs. Unsatisfiable on a first mint.
   - **It calls the STORE method, not the engine's.** `engine.readActiveCredential` (`engine:1135-1142`)
     begins with `final repo = await _store.readRepositoryReference(repositoryId)`, and **that throws
     `RepositoryNotFoundException` when the reference is absent** (`in_memory:145`; `store:155`). On a
     first mint it therefore **throws instead of returning `null`**, so Revision 3's step 2 could never
     have returned `null` as written. `readActiveCredentialForRepository` is a pure lookup that returns
     `null` and **never** resolves a reference.
   - **★ Ownership was established at step 3a, which is why the store method is safe here (B6).** The
     statement is now attached to the step that makes it true. Revision 4 attached it to a *write* that does
     not occur on this case.
   - **This step does not itself check ownership, and must not be asked to.** `_ensureOwned`
     (`engine:1784-1790`) is the domain's; the store interface has no product parameter on this method and
     **adding one would change a contract § R.9.7 already has to widen for other reasons.** The check lives
     at 3a, once, before anything is returned.
5. **Generate the keypair in memory and `put` the private half → handle** — § R.5.2 steps 4–5. A failed
   `put` means **no handle exists**: zero the buffer and refuse with `secretManagerWriteRefused`.
6. **`recordGeneratedCredential(…)` — passing no caller-supplied `credentialId`** (normative; § R.8.2) —
   **inside § R.5.7's compensation construct, verbatim**. This is the only place `destroy(handle)` appears,
   and § R.5.7 says exactly when it fires.
7. **Concurrency** — on a `23505` violation **of `product_credential_active_repository_unique`** (not on
   the engine's one-active exception, which will not fire): re-read the active credential for the
   repository and return **its** public half with `alreadyExisted: true`. A concurrency resolution, not
   an error. **Both tiers**: the in-memory tier's `saveProduct` also carries an `expectedVersion`-free
   insert path, so it must raise the same typed signal rather than silently overwriting.
8. **`CredentialIdentityConflictException` (`D-4`) is a defect, not a concurrency outcome.** It must
   propagate. Converting it into `alreadyExisted: true` would turn a broken invariant into a plausible
   answer.
9. **`CredentialNotUsableException` from `D-1`/`D-5`/`D-6` is also a defect** and must propagate.

`DeployPublicKeyView` is **unchanged from Revision 2** — nine fields, **no field capable of carrying
private key material**, and now also **no field carrying the handle**. `SC-09` makes it testable.

**Revised error table.** Revision 3's mapped *"unknown repository"* to `CredentialNotFoundException`;
**the domain throws `RepositoryNotFoundException`** (`exceptions.dart:12`; raised by
`readRepositoryReference` at `in_memory:145` and `store:155`) **[5436a4d]**. Corrected:

| Case | Thrown / response | State written |
|---|---|---|
| **Unknown repository** (no `repositoryReference` for `repositoryId`) | **`RepositoryNotFoundException`** → 4xx. **Not** `CredentialNotFoundException` — that type is for a **credential** id, and no credential is being looked up yet at step 3 | none |
| Unknown product (no `product` row at step 3) | `ProductNotFoundException` (`exceptions.dart:3`) → 4xx | none |
| **Cross-product access** (`repositoryId` exists but belongs to another product) | **`CrossProductAccessException` (`exceptions.dart:59`) → 403. Raised at step 3a, and only there.** ⚠ **This row had no producing step in Revision 4** — it was in the error table with nothing to raise it, which is how a cross-product disclosure survived into a frozen contract (B6) | none |
| No credential for the repository | `CredentialNotFoundException` (`exceptions.dart:201`) → 4xx | none |
| Host not derivable from `repositoryUri` | 400 `repositoryUriUnparseable` | none |
| **Substrate unavailable / unverifiable / refused** | **503 `substrateUnavailable` + the § R.5.4 remediation for the named cause** (`SecretSubstrateUnavailable`) | **none, at any tier** — `ae1c1f79` |
| Concurrent mint (`D-2` unique violation) | 200, winner's credential, `alreadyExisted: true` | one row |
| Identity conflict (`D-4`) | 500 typed — **a defect** | unchanged |
| Immutability violation (`D-1`, `D-5`, `D-6`) | 500 typed — **a defect** | unchanged |
| `publicKey` containing `PRIVATE KEY` | `CredentialNotUsableException` (`engine:946-953`) | none |

**The three rows that are new or corrected, and why each exists.** *Unknown repository* is split out because
Revision 3's single row conflated two different exceptions with two different meanings, and because `G-13`
makes step 3 a read that can legitimately fail. *Unknown product* is split out because § R.10.1 step 3
creates the product, so "the product does not exist yet" is now an **expected** condition on a first mint
rather than an error — and an implementation that treats it as one will refuse first mints. ***Cross-product
access*** now names **step 3a** as its only producing step, and says so, because **B6 is precisely the case
of an error-table row with no producing step**: the row promised a 403 that nothing raised, on an endpoint
with no authentication. **An error table is a specification of refusals, and a refusal nothing produces is
not a refusal.**

### R.14.2 `checkRepositoryAccess` — carried, with the manager in the path

Reads by id; **contains no generation step and no `put`** (§ R.13.1). Refuses when
`!hostKeyStatus.permitsConnection` (`N-3`) — and note that refusal is **already enforced in the domain** at
`requireUsableCredential` (`engine:1162-1167`) **[5436a4d]**, so this endpoint inherits it rather than
re-implementing it. Resolves the handle from the manager (§ R.1.4), performs the transport attempt, calls
`recordCredentialCheck`, returns `{ credentialId, status, hostKeyStatus, lastVerifiedAt, lastVerifiedBy,
failureKind?, failureReason? }` per § R.13.2.

**New failure surface.** A `resolve` failure is `secretReferenceMissing` (a `failureKind`, so the client
shows § R.13.2's copy) or a substrate refusal (a 503 with § R.5.4's copy — **the same remediation**,
because the operator action is identical). The check path **must not** invent a third remediation
vocabulary for a substrate problem: one copy, two callers.

### R.14.3 `revokeRepositoryCredential` — **required by `79e860e2`**, carried from Revision 4 unchanged

```dart
Future<CredentialStatusView> revokeRepositoryCredential(Session session, {
  required String productId, required String credentialId, required String reason,
})
```

`revokeCredential` already exists in the engine; what is new is that the flow must now do **two** things
(§ R.6.1) in a **normative order**, and that ordering lives in `apps/server` because the substrate does
(§ R.1.7). Errors: `CredentialNotFoundException`; `CrossProductAccessException` for another product's
credential; `RepositoryNotFoundException` is **not** reachable here (the credential carries its own
`repositoryId`); substrate refusal → 503 with § R.5.4's copy and **the row left unchanged**; already revoked
→ 200 with the row, idempotent.

**Why a new endpoint rather than a flag on an existing one.** No existing endpoint exposes a credential
view at all (`grep -c RepositoryCredentialView apps/server/lib/src/endpoints/*.dart` → **0** across all 11
files **[5436a4d]**), so there is nothing to extend. The endpoint exists because revocation now has a
ShipIt-side effect that must be auditable and must not be reachable by a path that skips it.

**Its dependency on `G-14`, and it is a real ordering constraint.** Revoking makes the credential
**invisible** to the current `loadProductDetail` (§ R.11.2). Shipping this endpoint before `G-14` would
produce, on the very first revoke, a product whose detail page says *"no key generated yet"* about a
withdrawn key. **`G-14` before the revoke UI ships.** § 10.1 item 5.

---

## R.15 — Exposure of a credential-minting endpoint — carried, with one new consequence

Revision 1 § R.18 is carried **in full**, including its four points and its refusal to pretend that
endpoint hardening mitigates a committed database password. **Nothing in it is softened.**

### R.15.1 What is still true (re-verified at **[5436a4d]**)

- `apps/server/lib/server.dart:71-73` declares **no authentication services** for the control plane, with a
  comment saying the API is *"intended for local / trusted-network use"*.
- The *"local only"* premise `570bb640` relies on is **still un-implemented**:
  `grep -rn "127.0.0.1:" docker apps/server/docker-compose.yaml` → **no match**, and
  `docker/compose.yaml:16-17` publishes `"5432:5432"` unqualified, which Docker resolves to `0.0.0.0`.
  **D-7 stands.**
- `docker/compose.yaml:63` hardcodes `SERVERPOD_DATABASE_PASSWORD: shipit` in a **committed** file, and
  `.env.example:16-18` documents `POSTGRES_USER=shipit / POSTGRES_PASSWORD=shipit`.
- So this is not theoretical: on any shared network the endpoint is reachable today, and the **fourth
  path** — direct database access with the published credentials — bypasses the endpoint entirely.
  Auditing the endpoint does not constrain the data.

**Consequence under A3, restated honestly.** A3 *reduces* what the fourth path yields: an attacker with the
database gets a handle per credential, not a key, and § R.1.3's opaque handle removes the topology
disclosure a literal ARN would have given them. It does **not** stop them from **deleting handles**, which
denies every push — so the fourth path moves from *disclosure* to *denial*. § R.5.2's compensation means a
denied mint cannot be used to destroy an existing credential. **It also does not stop them from setting
`status = 'revoked'`**, and `D-2`'s index would then block the legitimate re-mint (§ R.9.2) — so `D-4`
matters here too, not only to the credential's own integrity.

### R.15.2 The deployment precondition — carried verbatim, owner unchanged

**This endpoint must not ship to any environment where the control plane is reachable off-host, until
either `570bb640`'s loopback pinning lands or API authentication lands.** That is a **deployment
precondition** owned by the Manager / deployment authority, not something this design solves. **I am still
not proposing API authentication** — `570bb640` deferred it deliberately, and smuggling a cross-cutting
auth change in as a side effect of a deploy-key feature is what `048f3367`'s own resolution warned
against. **A3 does not change this**: a secret manager is a *new* network dependency with its own
reachability, and nothing about it constrains the control plane's own exposure.

### R.15.3 New under A3: an unauthenticated caller can now **deny** registration

`7b1bc8b7` chose fail-closed, which is correct. Its cost under A3 is new, and it belongs here rather than
in § R.5:

- **An off-host caller who can reach the control plane and influence manager reachability can block the
  credential flow outright.** Failing closed means the flow stops; there is no degraded fallback — that is
  the point of the decision. If the manager's reachability is influenceable from the same network the
  control plane is exposed on, the credential path is **deniable by an unauthenticated party.**
- **`R-H2`'s promise narrows.** The Products page stays reachable and **no partial state is created**
  (`ae1c1f79` makes this stronger than Revision 3 could claim: not even a `Product` row), so the user is
  not *stuck*; but *"we'll find the key ready to be verified again"* now also requires the manager to have
  been reachable **when the key was minted**. That is a **real narrowing of the addendum's promise**, and
  it is a consequence of A3 plus fail-closed, not a defect in either.
- **Mitigations that do not pretend to be authentication:** every substrate failure is audited (§ R.5.3)
  with its `substrateFailure` kind, so a denial campaign is visible as a rate of `secretManagerUnreachable`
  refusals; and the remediation names the endpoint tried **in the audit log only**, never on the wire
  (§ R.5.3).

---

## R.16 — Reuse table

Revision 1's rows are carried; Revision 2's 39 rows are carried; rows **#31**, **#35** and **#46** change;
rows **#40**–**#49** are Revision 3's and this revision's.

| # | Design element | Maps onto | New? |
|---|---|---|---|
| 1–30, 32–34, 36–39 | *(as Revision 2 § R-4)* | *(as Revision 2)* | — |
| **31** | **The private-half store** | `SecretProvider` + `apps/server/lib/src/secret/**` | **NEW — decided.** `9417f8bf` **OPTION_C: an external secret manager.** A3. ADR 0018 `:85-88` superseded by the human; the amendment is **human-ACCEPTED** — Human Decision `876c6b97`, amendment revision 2 — and **never independently reviewed** (§ R.17.1) |
| **32** | Keypair generation | `apps/server/**` | **NEW** — a real SSH implementation replaces `_generateMockKeyPair` (`add_product_page.dart:113`, `:126`) |
| **33** | SSH host-key verification | — | **NEW, and mandated** — the **transport** half does not exist; the **domain** half does (`engine:1047-1052`, `:1162-1167`). ADR 0018 `:96-99`; § R.10.3 |
| **34** | Credential injection into the transport | — | **NEW** — `git_workspace_inspector.dart:106-112` passes no `environment:` |
| **35** | Migration for the private half | — | **`none required`** (was `CONDITIONAL`). A3 stores an opaque handle in the **existing** `referenceName` column: no new table, no new column, no migration |
| 36 | `D-1` store-level material immutability | `saveProductCredential` | **DONE** at `07c8c8f`, merged as `e391c02` |
| 37 | `D-2` partial unique index on the active set | bootstrap **+** migration `20261006150645000` | **DONE** at `07c8c8f`, in **both** homes per `4d2c6b81` |
| 38 | Typed immutability error | `exceptions.dart:201,215,232` | **naming follow-up only** for `D-1` — the behaviour is typed `CredentialNotUsableException`. **`D-4`'s distinct type (`CredentialIdentityConflictException`) is a separate naming follow-up, and it is still unbuilt** — § R.18.2 `G-15` |
| 39 | Active-credential read path | `store:370-381` | — its predicate is what fixes `D-2`'s index predicate |
| **40** | **Opaque credential binding** (`credbind_<32 hex>`) | server configuration + `SecretProvider` | **NEW** — § R.1.3. Replaces the literal ARN/path form |
| **41** | **Substrate precondition + compensation** | § R.5.2 steps 0 and 5→6 | **NEW** — `verifyProtection` before any write; the compensation construct of **§ R.5.7**, stated once |
| **42** | **`SecretSubstrateUnavailable`** | `apps/server` (not `product_registry`, `C-02`, § R.1.7) | **NEW** — § R.5.5's four consistency obligations |
| **43** | **Revocation endpoint** | `ProductRegistryEndpoints` (new method) | **NEW** — § R.14.3; required because revocation now has a ShipIt-side effect |
| **44** | **`D-4` mint is insert-only** | `saveProductCredential` conflict branch, **both tiers** | **NEW behaviour, existing function** — § R.9.1. Tier A `DO NOTHING … RETURNING`; **Tier B `existing != null && expectedVersion == null`**, checked first |
| **45** | **`D-5` scope immutability** | the same statement, **CAS branch**, **both tiers** | **NEW behaviour, existing function** — § R.9.3. The mint branch needs nothing, because `D-4` updates nothing |
| **46** | **`RegistrationCommitState`** (client) | `ProductDetailView.credentials` + `canReachRepository` | **NEW, client-derived — and now genuinely derivable.** *Corrected (B3):* Revision 3 added "no new server field", which was **false**, because the read path never emitted a revoked row. **No new *field* is needed — a new *read* is** (§ R.11.2), and `AccessStatus` gains a `revoked` member as a consequence. **Rev 5 (M3): state 4 renders from `status` ALONE** — the view carries no `revokedAt`/`revokedReason`, so an implementer must not go looking for them or add them (**`SC-19` forbids a new wire field**) |
| **47** | **`G-14` revoked credentials reach the product detail** | `readCredentialsForProduct(productId)` ← `loadProductDetail` | **NEW behaviour, existing query and existing view.** One method's data source plus one selection rule. **No schema change, no migration, no new wire field.** § R.11.2 |
| **48** | **`D-6` durable evidence may be set, never erased — EIGHT columns** | `saveProductCredential` CAS branch, **both tiers** | **NEW behaviour, existing function** — § R.9.4. Tier A `_noClear(column, type)` × **8**; **Tier B `_clearsDurableEvidence`** × **8**. **Rev 5 (H9): the set is eight and both constructs now carry eight** — `lastFailureReason` was missing from both. **This is the half of Revision 3's sentence that was unsatisfiable** |
| **49** | **`SecretProvider` composition root** | `apps/server` endpoint/service layer | **NEW, and it is a boundary** — § R.1.7. Three named layers; `grep "SecretProvider" packages/product_registry/` → 0 matches, asserted by `SC-18` |

**No parallel credential abstraction is introduced.** #40–#49 are substrate, integrity and presentation
concerns; the credential *model* is entirely the existing one.

---

## R.17 — ADR 0018: what this design depends on, and what it supersedes

`docs/adr/**` is `PROHIBITED_PATHS` for this lane. **A sibling lane drafted the amendment; the repository
owner accepted it as ADR owner** — Human Decision `876c6b97-3e23-459d-aa9d-3a5faeb33702.yaml`
(`ARCHITECTURE`, `RESOLVED`, `decided_at 2026-10-06T14:20:00Z`), recorded in amendment revision 2
(`status: ACCEPTED`). **Acceptance is not review: `reviewed_by`/`reviewed_at` are still `null`** (§ R.17.1).
This section is the dependency contract that amendment was written against.

**⚠ Line numbers in this table are the A1 revision's, and the file no longer has them (B5, M5).** ADR 0018
was **158 lines** at the base Revision 4 cited and is **580 lines** at `5436a4d`. Every `:NN` below is a
reference to the **A1-revision** wording, which the ADR itself retains in place marked **SUPERSEDED (A2)**
(`:215-225`, `:279-283`) — and the file's own §Amendments states the convention: *"Line numbers cited in
§Amendments refer to the revision named there, not to the current file."* **The current-base anchors for the
clauses that still stand are given in the re-anchoring table in § R.17.1**, because a frozen contract citing
line numbers that resolve to the wrong text is the same defect as citing text that is not there.

| ADR 0018 clause | Status | What this design does with it |
|---|---|---|
| `:84-88` — per-repository `ed25519`; private half to the **local secret store**; *"never … persisted to the durable record"* | **⚠ `:85-88` SUPERSEDED** by `9417f8bf` — the custody substrate is now an **external secret manager**. The amendment is **human-ACCEPTED** (`876c6b97`; amendment rev. 2) and **never independently reviewed** (§ R.17.1). **A1-revision line numbers; see § R.17.1's re-anchoring table** | § R.1. **But the prohibition survives:** `:87-88`'s *"never persisted to the durable record"* still **excludes A2** permanently (§ R.1.6). The amendment replaces the **custody sentence** and **keeps the prohibition sentence** — as specified, and as accepted |
| `:92-95` — *"Referenced by name, never by value"*; the record stores a credential **reference** + fingerprint, never key material | **UPHELD, and now load-bearing** | § R.1.3's opaque handle *is* this rule; § R.3.1's invariant is this rule. A3 is the first substrate that satisfies it **unconditionally**, independent of topology |
| `:96-99` — TOFU with explicit human confirmation; *"ShipIt refuses to connect to an unrecognised host"*; *"does not claim to have verified a host it cannot verify"* | **UPHELD — and it is a REQUIREMENT, **half**-implemented** | § R.10 (`N-1`–`N-9`), § R.10.3, § R.5.4's *"we could not check ≠ it is fine"*. **The domain half is enforced** (`engine:1047-1052`, `:1162-1167`); **the transport half is not**, and that half is the ADR gap `G-4`. **Revision 3's "no runtime enforcer / decorative" claim was over-broad and is withdrawn** (§ R.10.3) |
| `:100-102` — *"A product cannot be registered until a connectivity check has succeeded against the real host with the real key"* | **✅ UPHELD — and now satisfiable** | `898b07d0` resolved the cycle **in favour of** this clause. § R.10 makes the ordering real: the credential is minted **before** the registration act completes. **This clause is not contradicted and must not be amended** — and the amendment upholds it too, recording `UPHELD (A2) — not superseded` at `ADR:256` |
| `:103-104` — rotation is per repository, re-install required | UPHELD | § R.6.1; `rotateCredential` unchanged. **One wording note for the ADR lane, not a change:** `:103` reads *"Rotation is per product"* while `:104` reads *"re-installing the new public key on that repository"*, and A1 (`:19-21`) scopes to the repository. `D-2` enforces **one active credential per repository**. The clause is **upheld as the design relies on it**; its `:103` wording is internally inconsistent with its own `:104` and with A1. § 10.1 item 8 |
| `:113-114` — *"Revocation is provider-native … requires no Shipit-side action"* | **⚠ SUPERSEDED** by `79e860e2`, and superseded by the amendment (retained struck-through at `ADR:279-280`) | § R.6. **Because A3 makes SHIP IT a participant in custody**, a ShipIt-side action — deleting the manager handle — is now required, and provider-side removal alone no longer releases material SHIP IT can reach |
| `:15-30` (A1) — one keypair **per repository**; `productId` retained for ownership checks only | UPHELD | § R.16 row 46; `D-2` enforces it in the database (§ R.8.1); `D-5` makes the retained `productId` non-rewritable (§ R.9.3); **and § R.14.1 step 3a enforces the ownership relation at the endpoint (B6)** |
| `:29-30` — reference-name shape `GIT_PRODUCT_<productRef>_<repoRef>_SSH` | **⚠ SUPERSEDED IN SHAPE** by § R.1.3 | The handle is `credbind_<32 hex>`, with no product or repository information. The clause's **shape** is superseded; its **rule** (§ `:92-95`) is upheld. Any board or fixture still using the old shape is stale (§ R.3.4) — and two such fixtures **will not compile** (§ R.3.2 rows 11–12) |
| `:79-80`, `:126-127`, `:140-141` — the deliberate scoped deviation from `AGENTS.md §13`, its Negative, and the §13 carve-out | **✅ CLOSED — `G-1′` is closed** (B1) | `0bf2fa0` restored `AGENTS.md` §13/§13a/§13b (**199 lines**; §13 at `:65`, §13a `:72`, §13b `:78`, `:91`, restoration note `:96-101`) **[5436a4d]**, and the ADR records its own closure at `:530-539`. **The carve-out is applied, not merely described.** Revision 3 listed this as an open gap and asked the Manager for an action that has already been taken — § R.18.2 records the correction |

### R.17.1 The amendment's real state — accepted, **not reviewed**, and **no longer "not in `docs/adr/**`" (B5, M5)**

**The artifact.** The ADR 0018 amendment is `docs/engineering/dispatch/tasks/design-adr-0018-amendment/` —
**now tracked on `main` at `5436a4d`**, at `design-revision-2.md` and `design-revision-metadata-2.yaml`. It
grew from **158 → 580 lines**, and it is an **in-place edit of `docs/adr/0018-per-product-git-credentials.md`
itself**, not a separate file. **[Citation index row 21 — this is repository state at `5436a4d`, not an
uncommitted sibling worktree, and Revision 4's labelling of it as `[UNCOMMITTED 6220951]` is superseded.]**

**The acceptance, with its two citations (B5):**

| | |
|---|---|
| **The decision** | `.decisions/876c6b97-3e23-459d-aa9d-3a5faeb33702.yaml` — `type: ARCHITECTURE`, `status: RESOLVED`, `created_by: orchestrator-main`, `decided_at 2026-10-06T14:20:00Z`. The owner's verbatim answer: **"Accept A2, record the gaps as accepted."** |
| **The artifact** | `design-revision-metadata-2.yaml` — `status: ACCEPTED`, `approved_by` and `approved_at` **populated**, `human_gate.required: false` with `level: 3` **retained**, `blocking_items: []` |
| **The ADR** | `docs/adr/0018-per-product-git-credentials.md:4` Status line → `Accepted (amended — … A1 credential scope = per repository; A2 credential custody = external secret manager, revocation = two-sided)`; **§ Accepted risks `:446-524`** carrying A1–A4, each with a *"Consequence accepted."* paragraph and a named owner |

**⚠ ACCEPTANCE IS NOT REVIEW, and this design may not treat it as review (B5).**
`design-revision-metadata-2.yaml` carries **`reviewed_by: null` and `reviewed_at: null` deliberately**, plus a
new `acceptance_is_not_review: true` field whose note states the distinction: *"an accepted design is not a
reviewed artifact, and no downstream artifact may treat it as one."* The ADR says the same in its
*"What acceptance is NOT"* bullet. **Independent design review of the amendment has NEVER happened and is
the next gate on that lane** — `876c6b97`'s own first follow-up action, owned by the independent design
reviewer. **So: accepted, yes; reviewed, no — and § 10.1 asks for the review.**

**⚠ M5 — what Revision 4 said, and what is true.** Revision 4 wrote that the amendment *"is **uncommitted and
not in `docs/adr/**`**" and asked the Manager to *"merge the ADR 0018 amendment **into** `docs/adr/**`"*.
**That was wrong twice over, and the finding is right.** It **was** `docs/adr/**` — the amendment *is* an
in-place edit of that exact file, so describing it as *not in* `docs/adr/**` was false on its face even
before the re-base. And at **this** base the edit is **committed and landed**: `5436a4d` is
*"docs(adr): record ADR 0018 A2 acceptance"*, and the amendment's own artifacts landed in the same commit. So
the correct statement is **"the edit is merged"**, and the outstanding work is **not** a merge.

**⚠ And a contradiction I must report rather than fix: the ADR's own text is now stale on this very point.**
`docs/adr/0018-per-product-git-credentials.md:16-21` (*"no Human Decision object on disk records this
acceptance"*, and *"A decision object should be created by the Manager"*) and its § *"The acceptance itself"*
(`:572-580`, *"There is no Human Decision object for it in `.decisions/`"*, *"the acceptance has no citable
decision id"*) are **both false as of `5436a4d`** — `876c6b97` exists and was committed in that same commit.
**`docs/adr/**` is `PROHIBITED_PATHS` for this lane, so I did not edit it and make no claim of having done so.**
**Owner: the ADR lane or the human as ADR owner.** Recorded as `G-17`.

**What the acceptance changes for this design, precisely:**

| Item | Status |
|---|---|
| ADR 0018 `:85-88` (custody) | **superseded** — by `9417f8bf` and recorded by the amendment. **See the re-anchoring table below for where that wording now lives** |
| ADR 0018 `:87-88`'s prohibition (*"never persisted to the durable record"*) | **KEPT** by the amendment, exactly as § R.1.6 requires — and now **load-bearing**, because it is what permanently excludes the envelope-encrypted-table substrate (`ADR:113-115`) |
| ADR 0018 `:113-114` | **superseded** — two-sided revocation |
| ADR 0018 `:100-102` | **upheld**, untouched, and the ADR says so at `:256-260` (*"UPHELD (A2) — not superseded"*) |
| The four gaps | recorded by the owner as **accepted risks** (`ADR:446-524`) with consequences and owners — **not** as open work for me, and **not** as closed |
| **The amendment is merged into `docs/adr/**`** at `5436a4d` | **so § 10.1 action 1 is no longer a merge.** What remains is (a) **independent review of the amendment**, and (b) **correcting the ADR's two now-false "no decision object" statements** (`G-17`) |
| **Its § 3.1 finding** | **adopted by this revision** as § R.10.3's corrected host-key split — with its engine citations **re-verified at this revision's base** (`6220951`'s `:1033`/`:1148` are `[5436a4d]`'s `:1047`/`:1162`), because the store-integrity work shifted them by +14 |
| **Its `D5` self-correction** | **adopted**: the partial unique index does **not** refuse a legitimate fresh mint, because `rotateCredential` revokes first. **This design does not lean on the index to close accepted risk A1** — `D-4` does (§ 0.2, § R.9.2) |

#### Re-anchoring the clause citations, because the file is 580 lines now and the old numbers do not resolve

Revision 4's § R.17 cites `:85-88`, `:92-95`, `:96-99`, `:100-102`, `:103-104`, `:113-114`, `:19-21`,
`:29-30`, `:15-30`, `:79-80`, `:126-127`, `:140-141` — all **A1-revision (158-line) numbers**. **At `5436a4d`
those line numbers resolve to different text**, so a reviewer checking them would find the wrong clauses.
**The A1 wording is retained in place, marked `SUPERSEDED (A2)`** (`ADR:215-225` for custody, `:279-283` for
revocation), which is the file's own documented convention. **The anchors a reviewer should actually use:**

| A1-revision citation | What it is | Where that text now lives at `5436a4d` |
|---|---|---|
| `:85-88` — custody (local secret store) | **SUPERSEDED** | Retained struck-through at `ADR:215-219` with `SUPERSEDED (A2) in part` at `:220-225`; the replacement is § A2 *"Current — custody (A3)"* at `:78-85` |
| `:87-88` — *"never persisted to the durable record"* | **KEPT, load-bearing** | `ADR:223-225` (in place), and the sealing reasoning at `:113-115` |
| `:92-95` — *"Referenced by name, never by value"* | **UPHELD** | `ADR:242-245` |
| `:96-99` — TOFU / *"refuses to connect to an unrecognised host"* | **UPHELD, half-implemented** | `ADR:246-252` — and note `:250-252` now records *"Requirement, not yet enforced at the transport"* and points at **§ Accepted risks A2** |
| `:100-102` — registration gated on a real check | **UPHELD, not superseded** | `ADR:253-260`, with `UPHELD (A2)` at `:256` |
| `:103-104` — rotation | **UPHELD**; `:103`'s *"per product"* is the known wording inconsistency | `ADR:261-262`; the inconsistency is recorded at `ADR:540-542` |
| `:113-114` — revocation needs no ShipIt-side action | **SUPERSEDED** | Retained struck-through at `ADR:279-280` with `SUPERSEDED (A2)`; the replacement is `:284-293`, including the accepted A1 caveat at `:291-293` |
| `:19-21` / A1 — one keypair **per repository** | **UPHELD** | § A1, `ADR:35-51` |
| `:29-30` — reference-name shape `GIT_PRODUCT_<…>_SSH` | **SUPERSEDED IN SHAPE** by § R.1.3 | the shape survives only as an example at `ADR:243-244` |
| `AGENTS.md §13` carve-out (`:79-80`, `:126-127`, `:140-141`) | **✅ CLOSED** | the section exists (`AGENTS.md:65-101`); the ADR records its own closure at `:530-539` |

---

## R.18 — Traceability and gaps

### R.18.1 Gaps this revision **closes**

| Gap | Closed by |
|---|---|
| `OPEN-D4-1` (all four sub-questions) | `9417f8bf`, `7b1bc8b7`, `79e860e2` — § R.1, R.5, R.6 |
| `OPEN-D4-2` (registration ordering) | `898b07d0` OPTION_A — § R.10 |
| **`§ R.5.2's ordering interpretation`** | **`ae1c1f79` OPTION_A** — the human adopted it, so § R.5.2 is decided content and § 10.1 asks nothing about it (H4) |
| **`G-7` was *"a gap, owner named"*** | **REQUIRED work, specified with a verified site-by-site change list** — § R.3.2, plus § R.3.3 and § R.3.4 |
| `G-9` (one-per-repository not a DB constraint) | `D-2` **landed** at `07c8c8f` in **both** homes — § R.8.1 |
| **`G-1′` (`AGENTS.md` has no `§13`/`§13b`)** | **`0bf2fa0` restored §13/§13a/§13b** **[5436a4d]**. **B1.** Revision 3 carried this as open and asked the Manager for an action already taken; `AGENTS.md:78-91` now states the per-repository keypair, §13a, and §13b's two-sided revocation and external-custody model, and the note at `:96-102` records the restoration. **No further action is required from anyone** |
| **The surviving false ledger claim** | **Already retracted at `main` by `4e2d237`** **[5436a4d]**. Revision 3 listed `LANES.md:204-205` as a live false claim; at that base `LANES.md` was 172 lines with no such assertion, and at this base **427 lines** with the **retraction** at `:204-205` (*"AND SINCE RETRACTED, see the Gate D3 section below"* at `:204`). **B1.** § 10.1 item 6 is withdrawn, not re-requested |
| Revision 2's `SC-08` (*"decided by the human at Gate D4"*) | Decided. `SC-08a` replaces it (§ 8) |

### R.18.2 Gaps that remain **open**

| # | Gap | Why it is a gap | Owner |
|---|---|---|---|
| **`G-4`** | **No SSH host-key verification in the transport.** Nothing configures git to verify a host key: `git_workspace_inspector.dart:106-112` runs `Process.run` with no `environment:`; grep for the five host-key tokens across `apps`/`packages` returns **0**. **The domain half exists** (`engine:1047-1052`, `:1162-1167`) — **ADR 0018 `:96-99` is therefore half-implemented, not unimplemented** (§ R.10.3) | **An ADR gap, not only a missing feature.** A design may note missing work; it may not treat an ADR requirement as optional | Implementation (architecture) — § 10 asks that it get **its own** review |
| `G-3` | Zero test files import `add_product_page.dart` (`73097d48`), so `SC-02`/`SC-04`/`SC-06` have no existing harness | test infrastructure | Implementation / QA Contract |
| `G-5` | No read-only endpoint for a product's public key | a client holding only a `credentialId` cannot re-read | Implementation |
| `G-6` | `recordGeneratedCredential`'s `host` is optional and defaults to `null`; the design refuses to mint without one but the domain does not enforce it | design/domain mismatch | Implementation |
| `G-8` | Host-fingerprint provenance unspecified (`ssh-keyscan` vs handshake) | `N-4`'s copy says *"the fingerprint the server actually observed"*; **how** is part of the new seam | Implementation |
| **`G-10`** | **A3's reachability in the target topology is `UNVERIFIED`.** No secret manager exists in this repository, no probe was run, and this lane issued no Docker command | `9417f8bf`'s own follow-up action assigns the probe to the **implementer**; the decision records `confidence: LOW` and states that no option was runtime-verified | **Implementer, before completion** |
| **`G-11`** | **`D-4`/`D-5`/`D-6` are specified, not merged.** `R-B6`'s state-loss family, § R.6's revocation semantics, `N-7`'s durability and § R.9.4's evidence rule all rest on them (§ R.8.3). **B4 sharpened it:** the specification was incomplete for one whole tier | the design names required invariants that do not exist yet, and named tests that would not have witnessed them. Stated, not smoothed | **Implementer** — a `fix/credential-identity-invariants` merge, after **this** design is approved |
| **`G-12`** | **The duplicate-credential audit is a human-run deployment precondition, carried in prose and a changelog only until now (M1).** `CREATE UNIQUE INDEX` fails on duplicates; the audit query **as originally dispatched does not execute** (`"repositoryId"` is quoted camelCase; unquoted it folds to `repositoryid` and **errors**, which reads exactly like *"no duplicates"*). Zero duplicates were found in every database reachable to the implementer, but the only credential-bearing one held **0 rows** — a vacuous *"no"*. **No QA, staging or production database is reachable from any lane** | an unrunnable query whose failure mode reads as a pass. Migration `20261006150645000` must not be applied before it is run, **with the corrected query** | **Human** — before the migration is applied, anywhere. § R.8.4 row 7, § 10.1 item 8 |
| **`G-13`** | **The § R.14.1 get-or-create step is destructive on both rows — and one of the columns it rewrites **reparents** another product's repository reference (B6).** **Full column set**, `ON CONFLICT … DO UPDATE SET`, at **[5436a4d]**: `saveProduct`'s conflict branch (`:92-100`) sets **`name` `:93`, `description` `:94`, `manifestVersion` `:95`, `state` `:96`, `createdAt` `:97`, `updatedAt` `:98`, `version` `:99`**; `saveRepositoryReference`'s (`:136-142`) sets **`productId` `:137`, `kind` `:138`, `uri` `:139`, `provider` `:140`, `addedAt` `:141`, `version` `:142`**. **Revision 4's entry named `state`, `name`, `createdAt`, `uri` and `addedAt` and omitted `productId`** — which is the only column whose rewrite is a **cross-product** event rather than a data-freshness one: `addRepositoryReference` with an existing `repositoryId` and a different `productId` **moves the repository to another product**, silently, moving the ownership graph out from under every credential already attached to it | two distinct harms, and the second is the more serious: (a) `state`/`createdAt` reset a registered product and falsify its age; (b) **`productId` reparents a repository reference**, after which `_ensureOwned(productId, credential.productId, …)` on that repository's credentials resolves against the new owner. **§ R.12's re-entry and § R.10's `registered` semantics depend on a product's state not being rewritten, and § R.14.1 step 3a's 403 depends on `productId` not being rewritten under it.** **The read-first discipline is therefore load-bearing, not a footnote** — it is the only thing preventing either | **Implementation** — the read-first discipline is normative in § R.14.1 step 3, and **step 3a's ownership check runs before the decision to create**, which is what stops the reparenting path from being reached at all |
| **`G-16`** | **★ NEW (B6) — `mintOrReadDeployKey` has no ownership step, and no test.** Revision 4 corrected `H2` by switching step 4 to the **store** method, which removed the *only* `_ensureOwned` on the path (`engine:1140`) without adding one, and step 3's read-first cannot supply it (no write, no check, on exactly the cross-product case). **§ R.14.1 step 3a now specifies the check; `T-L` now specifies the test on both tiers** | a cross-product disclosure: another product's `publicKey`, `credentialId`, `status`, `hostKeyStatus` and `alreadyExisted: true`, on an endpoint with **no authentication** (§ R.15.1) and no loopback pinning. **A gap entry with no producing step is still a gap even when the error table promises one** — the 403 row existed and nothing raised it | **Implementation**, in the same dispatch as the mint endpoint (§ 10.1 item 5) |
| **`G-17`** | **★ NEW (B5/M5) — ADR 0018's own text now falsely denies its own acceptance.** `ADR:16-21` and `ADR:572-580` both state that **no Human Decision object records the acceptance** and that *"the acceptance has no citable decision id"*. **`876c6b97` exists** and was committed at `5436a4d` — in the same commit that landed the ADR text. **I did not edit `docs/adr/**`** (`PROHIBITED_PATHS`) and make no claim of having done so | the ADR is the artifact every future lane cites for custody, and two of its sentences are false **about its own status**. That is the same class as the defect `876c6b97` was created to fix — an absence recorded as fact, in a document nothing will re-check because it is an ADR | **ADR lane / human as ADR owner.** Two sentences in one file. **Not mine to write** |
| **`G-14`** | **State 4 (`revoked`) is not derivable from the read path this design keeps (B3).** `loadProductDetail` populates `credentials` exclusively from `readActiveCredentialForRepository`, which excludes revoked rows on **both** tiers, and `ProductDetailView` carries no revoked summary. **Revision 3's stated cause (`AccessStatus` has no `revoked` member) mislocated it one layer down** | a user told *"no key generated yet"* about a key that existed, was withdrawn, and may still be installed on the repository. The wire type can already express it (`status` already lists `revoked`); the **query** cannot emit it | **Implementation** — § R.11.2, one method. **Must land before the revoke UI ships** (§ R.14.3) |
| **`G-15`** | **`CredentialIdentityConflictException` is named by `D-4` and does not exist.** The implementer reports it could not be created because `packages/product_registry/lib/src/exceptions.dart` was outside its `OWNED_PATHS`; behaviour is complete and the refusal carries a distinct greppable reason, so **no API behaviour changes** | a design naming a type that does not exist is a gap in the specification's *terminology*, not its behaviour — and `D-5`'s separate scope reason (§ R.9.3) makes the distinction meaningful | **Implementation**, with an ownership grant |
| `L-6` | **`DECISIONS.md`'s index table (`:8-12`) omits `570bb640`**, which appears only in the closing prose at `:44-46`; and `:16` still reads *"All five are `PENDING`"*, which is **false** — all six resolved (`:53`+) | an index that omits a RESOLVED risk-acceptance decision understates what has been accepted, and a status line that is false is read as a status | **Manager** — **reported, not edited** |
| — | **ADR 0018 `:103`'s wording** — *"Rotation is per product"* — is inconsistent with its own `:104` (*"on that repository"*) and with A1 (`:19-21`). § R.17 upholds the clause **as the design relies on it** and flags the wording | a clause whose two sentences disagree about scope; `D-2` enforces the repository reading | **ADR lane / human** — § 10.1 item 8 |

**Out of scope for this lane, by design** (not gaps): the Penpot boards and the mobile/desktop footer
layout itself (`C-11`). § R.11g states what the boards must show so the sibling can consume it rather than
re-derive it; **no board is authored and none is edited here.**

---

## 8 — Success criteria changes

Revision 1's `SC-01`–`SC-10` stand except where noted. `SC-08` is re-framed; `SC-11`–`SC-20` are named.

| ID | Change |
|---|---|
| `SC-02` | **Extended twice.** Rev 2 added `T-A`. Rev 3 added **`T-C`** — an identical-material re-mint must throw and **every** column must be byte-identical afterwards. **Rev 4 adds the tier requirement: `T-C` must exist and pass on the in-memory store as well as on Postgres**, because the in-memory tier overwrites wholesale and a Postgres-only fix leaves it failing (§ R.9.1, B4) |
| `SC-03` | **Extended.** `T-B` (passing at `07c8c8f` per the implementer's report; **not re-verified by this lane**), plus **`T-D`** — a revoked credential must not be resurrectable, and a fresh mint for that repository must then succeed. **Rev 4: `T-D` on both tiers, with its second half on Postgres** |
| `SC-06` | **Extended twice.** All new copy bound to `palette.inkSecondary` (`N-8`); plus `N-9`'s custody truthfulness and the exact string at § R.10.2; plus `27ea6536`'s footer. **Rev 4 adds: § R.11.1 state 4 must render (via `G-14`), and § R.11g item 5's refused-mint surface must not reuse the Unknown-host board** |
| **`SC-08a`** | **Replaces `SC-08`.** `SC-08` (*"the at-rest model is decided by the human at Gate D4"*) is satisfied: `9417f8bf` is RESOLVED OPTION_C. **`SC-08a`**: the frozen contract carries **A3** normatively, and **re-presenting the substrate as an open choice is itself a defect** — the human reserved and then made that decision |
| **`SC-11`** | **Fail-closed path.** A substrate refusal creates **no keypair, no credential row, no `Product` row and no `RepositoryReference` row**; it returns 503 `substrateUnavailable`; and it surfaces the remediation named for its cause. `T-H`: all four `substrateFailure` causes are distinguishable server-side, and **all three row counts** are unchanged afterwards. **Decided by `ae1c1f79`, so this is no longer an interpretation** |
| **`SC-12`** | **G-7.** `RepositoryCredentialView` carries **no** reference, **no substitute field is added**, and no client surface or board renders a reference-shaped token. A test asserts the field's absence from the regenerated protocol in **both** packages. **Rev 5 (H10): the change list is the verified TWELVE ROWS ACROSS SIX FILES** (§ R.3.2 § A), `protocol.dart` is **dropped** rather than marked no-op, and the two client fixtures (§ R.3.2 rows 11–12) compile and pass |
| **`SC-13`** | **Two-sided revocation.** Revoke deletes the manager handle **and** marks the row revoked, with the row retained; a revoked credential cannot reach the repository; its history stays readable (`credential_test.dart:310`); and a manager `destroy` failure leaves the row unchanged. **Depends on `D-4` and `D-6`** (§ R.6.3). **Rev 4: the ordering is specified as `apps/server` code and `SecretProvider` is absent from the domain** (§ R.1.7) |
| **`SC-14`** | **Split identity.** The flow creates the `Product` (state `registered`) and the `RepositoryReference` before minting — **and does not rewrite either on re-entry** (`G-13`); re-entry finds the key ready to verify without regenerating; and the UI distinguishes all five states of § R.11.1 |
| **`SC-15`** | **Never-upsert.** `T-C`, `T-D`, `T-E`, **both tiers** |
| **`SC-16`** | **Scope immutability.** `T-F`, `T-G`, **both tiers** |
| **`SC-17`** | **Durable evidence (H3), with the set decided ONCE as EIGHT (H9).** `D-6`: a CAS write **MAY** set `lastVerifiedAt`, `lastVerifiedBy`, **`lastFailureReason`**, `hostKeyFingerprint`, `hostConfirmedAt`, `hostConfirmedBy`, `revokedAt`, `revokedReason` — **eight, all named** — and **MUST NOT** transition **any of the eight** non-null → null, on **both** tiers. `T-J` (the legitimate setters still succeed) and `T-K` (**the erasure of each of the eight, by name, is refused**). **Rev 5: `lastFailureReason` was in this criterion and in neither construct** |
| **`SC-18`** | **The boundary is mechanical, not a comment (H7), extended to obligation 4 on BOTH forms (H8).** `grep -rn "SecretProvider" packages/product_registry/` returns **0 matches** in production sources; `SecretProvider` is not a constructor parameter of `ProductRegistryEngine`; `SecretSubstrateUnavailable` is declared in `apps/server`; and the § R.5.7 compensation construct's `destroy` runs **only** when the row was not recorded **and** only when the handle is non-null — witnessed by `T-I`, which asserts `resolve(handle)` returns the material after a **successful** mint **and** that `privateHalf` is zeroed on every exit of **both** accepted forms, including the path where `put` itself throws |
| **`SC-19`** | **Revocation is visible (B3, `G-14`).** After a revoke, the product detail carries the credential with `status: revoked`; the UI renders § R.11.1 **state 4** (*"this key was withdrawn; a new one must be generated and re-installed"*); and **state 1 is not what the user sees**. **No new wire field and no migration are required** — and, per **M3**, **`revokedAt`/`revokedReason` are NOT on the view and must NOT be added**: state 4 renders from **`status` alone**, and adding either field would break this criterion |
| **`SC-20`** | **★ NEW (B6) — ownership on the mint endpoint.** `mintOrReadDeployKey` establishes, **before deciding whether to create anything and before returning anything**, that `repositoryId` belongs to `productId`; a foreign `repositoryId` yields **403 `CrossProductAccessException`** and the response carries **no field** of the other product's credential — not `publicKey`, `fingerprint`, `algorithm`, `credentialId`, `status`, `hostKeyStatus`, **nor `alreadyExisted: true`**. **`T-L`, on both store tiers.** And `G-13`'s read-first discipline is load-bearing: without it, `saveRepositoryReference`'s conflict branch **reparents** the reference (`"productId" = EXCLUDED."productId"`, `store:137`) |

---

## 9 — Self-assessment

### 9.1 Risk level: **3** — re-derived, not inherited, and **the tally republished (B5)**

`DESIGN_GOVERNANCE.md` Invariant 6 makes the classification mandatory **for every** revision, and Revision 4
was independently agreed at 3 (`INDEPENDENT_RISK_LEVEL: 3`, `RISK_LEVEL_AGREEMENT: YES`). **I re-derive it
rather than inherit it, because R6 changed status in this pass.** This section is the **single source** for
the tally, and `design-revision-metadata-5.yaml` → `risk_rationale` and `report-revision-5.md` reproduce it
**verbatim** — one sentence, character for character, in all three places (H6's discipline, and L7's
correction: Revision 4's three copies differed by a word).

**⚠ THE SUPERSEDED SENTENCE, NAMED ONCE (B5).** Revision 4 published:

> *"1 reason IMPROVED (R6), 1 reason UNCHANGED (R1), 4 reasons WORSE (R2, R3, R4, R5)."*

**That sentence is withdrawn.** Its single IMPROVED leg rested on an acceptance that **did not exist on the
record at the base Revision 4 cited** — the amendment carried `status: DRAFT`, `approved_by: null`,
`reviewed_by: null`, `human_gate.required: true` at level 3, and a blocking item reading *"ADR 0018 status
remains Proposed. This lane does not declare it Accepted."*; `.decisions/` held no acceptance object. **The
level was never in question and is unchanged; only the arithmetic was resting on nothing.** R6 is now
**UNCHANGED**, and § 0.2 carries the two citations that make the acceptance real — plus the fact that
acceptance is **not** review, and that the amendment's own revision 1 over-claimed `D-2`'s index in the
direction that would have made accepted risk A1 look closed.

#### The reasons, and their status

| # | Reason this revision is a level-3 change | Status | Why |
|---|---|---|---|
| **R1** | **First handling of key material.** This design is the first time SHIP IT handles a private deploy-key half in a flow it controls | **UNCHANGED** | Still irreversible: a leaked key authorising **write** access to a customer repository cannot be recalled from SHIP IT's side — it must be uninstalled at the host. No such secret exists in the repository today |
| **R2** | **The credential is exposed through an unauthenticated, unpinned control plane** | **WORSE** | Under A3 the endpoint is not the only exposure; there is now a **runtime dependency whose unavailability blocks the credential path** (§ R.15.3), so the failure mode is *disclosure* **and** *denial*. `server.dart:71-73` still declares no authentication; `D-7` still stands; the database is still on `0.0.0.0:5432` with a committed default password. **Rev 4 sharpens it:** an attacker with the database can also set `status = 'revoked'`, and `D-2`'s index would then block the legitimate re-mint — so `D-4` is an availability control here, not only an integrity one |
| **R3** | **Change to the core registration workflow** | **WORSE** | Under `898b07d0` the change is no longer only *"registration is gated"*; it is **identity semantics** — a product becomes visible *before* registration commits, and an accepted consequence is a visible product with no usable credential. That changes what a `Product` means across the Products page, product detail and Add Product, which is closer to information architecture than to a gate. **`ae1c1f79` adds a second interaction:** the same flow's *first* step is now conditional on an infrastructure dependency, so the flow has two distinct failure shapes with different user-visible consequences (§ R.11g item 5) |
| **R4** | **Credential invariants that are reachable and not enforced** | **WORSE** | `R-B6`'s original defect is closed by `D-1`/`D-2` (§ R.8.2). But `D-4`, `D-5` and `D-6` are **still unmerged**, Revision 4 found **three** more defects in the specified flow (`G-13`, `G-14`, `G-15`), and **this pass found three more of its own**: **B6's cross-product disclosure** on the mint endpoint (`G-16`) — a defect **introduced by Revision 4's own correction of a blocker**, which is the worst possible direction; **`D-6`'s silent omission of `lastFailureReason` from both tier constructs** (H9), which would ship one diagnostic column erasable on the CAS branch on both tiers; and **§ R.11.2's selection rule depending on an ordering guarantee that exists on one tier only** (M4). The **count of unbuilt or newly-found credential invariants rose again**, the opposite of the direction the net should move — and this time one of them was manufactured by the previous pass |
| **R5** | **An SSH transport seam with no precedent** | **WORSE** | § R.10.3: the seam must deliver host-key TOFU verification **at the transport** **and** manager-backed material resolution — two security-critical capabilities, one with no precedent anywhere in the repository, and ADR 0018 `:96-99` makes the first a **requirement**. **Rev 4's contribution is precision, not reduction:** the domain half *is* enforced (`engine:1047-1052`, `:1162-1167`), so the remaining half is cleanly nameable — and a cleanly nameable half is still an unbuilt half |
| **R6** | **A design whose outcome may contradict an existing recorded ADR** | **UNCHANGED — and the improvement Revision 4 claimed for it was not real** | The substance moved **twice**, in opposite directions. Revision 4 claimed IMPROVED because the amendment was *"written and Accepted"* — **and at its base that was false** (B5): the amendment read `DRAFT`, and the acceptance existed nowhere but in that sentence. **Now the acceptance is real** — `876c6b97` and amendment revision 2 — **and the residual Revision 4 asked about is gone too**: the edit **is** `docs/adr/0018-*.md`, and it **is** committed and landed at `5436a4d`, so *"merge it"* was never the right action (M5). **Net: UNCHANGED**, for three reasons and none of them credit: **(a)** an acceptance asserted without a record is not an improvement, and republishing the number would have carried the assertion forward; **(b)** acceptance is **not review** — `reviewed_by` is `null` and independent review of the amendment has never happened, so the artifact this design depends on is still unjudged by anyone but its author and the ADR owner; **(c)** the amendment's **revision 1 contained a factual error** — it claimed the partial unique index refuses a legitimate fresh mint, and `rotateCredential` revokes first, so it does not. **That error over-claimed the index in the direction that would have made accepted risk A1 (resurrection) look closed**, and A1 is this design's own subject matter. A dependency whose first draft overstated its own protection against the exact defect under repair is not a reason to mark the risk down. **§ 10.1 asks for the independent review** |

#### **THE TALLY — one, and it is the only one**

> RISK_LEVEL: 3 (Major Workflow / Navigation / IA Change), re-derived on this evidence.
> 0 reasons IMPROVED, 2 reasons UNCHANGED (R1, R6), 4 reasons WORSE (R2, R3, R4, R5).

**Those two lines, unformatted above, ARE the sentence. They appear in THREE places, character for
character, and a reviewer can check that with three `grep -c` calls — which I ran, and all three return 1:**

```
$ grep -c '^> 0 reasons IMPROVED' design-revision-5.md                 # 1
$ grep -c '^  0 reasons IMPROVED' design-revision-metadata-5.yaml   # 1
$ grep -c '^  0 reasons IMPROVED' report-revision-5.md               # 1
```

§ 9.1 here, `design-revision-metadata-5.yaml` → `risk_rationale`, and `report-revision-5.md`. **Bold was
removed from the tally in all three for exactly that reason: a formatted copy cannot be compared to an
unformatted one, which is how Revision 4's three copies came to differ by a word while each of them claimed
to be verbatim (L7).**
**Revision 4's sentence is withdrawn as arithmetic, and named above so a reviewer comparing the two
documents sees the change rather than having to infer it.** Revision 3's four tallies — "5 rows" / "one
improved, two unchanged, three worse" / "IMPROVED (2 reasons) … UNCHANGED OR WORSE (4 reasons)" enumerating
five / "Two improved, four unchanged or worse" — remain withdrawn.

**Why incoherent counting in a risk rationale is not a typo.** The tally is what a reviewer checks to see
whether the reasoning was actually done. **A tally one IMPROVED leg optimistic because a dependency's status
was asserted rather than read is the failure mode this framework's correction loop exists to catch** — and it
survived one full review cycle in Revision 4, which is why the withdrawn sentence is printed beside the new
one rather than quietly deleted.

**Level 3 is unaffected, and this pass supports it more strongly than the last one did.** **Five of the six
reasons are WORSE**, and the sixth moved from *claimed-improved* to *honestly-unchanged* — which removes an
argument for a lower level, not an argument against a higher one. `G-4` remains an **ADR requirement** that is
half-implemented; the SSH transport seam remains **LOW** feasibility carrying an ADR requirement with no
implementation anywhere in the repository; `D-4`/`D-5`/`D-6` remain **unmerged**; `G-13`, `G-14`, `G-15`,
`G-16`, `G-17` remain **open**; and A3's reachability remains `UNVERIFIED` (`G-10`). **Any one of those is a
level-3 fact on its own.**

**What the level means here.** Per `DESIGN_GOVERNANCE.md`, Level 3 requires **product/design/architecture
human approval** at Gate D4. The six Gate D4 decisions are taken, `ae1c1f79` is taken, and the ADR 0018
amendment is human-accepted (`876c6b97`). **The *content* of this revision still requires human
approval** — specifically `D-4`, `D-5`, `D-6` (**now eight columns**), `G-13` (**now including the reparenting
hazard**), `G-14`, `G-16`, `SC-11`–`SC-20`, the `N-9` copy, § R.5.7's **both** forms, and § R.14.1's
**step 3a ownership step**. **And Revision 5 is not self-approved**:
`READY_FOR_INDEPENDENT_DESIGN_REVIEW` is a statement about readiness, not a verdict.

### 9.2 `design_system_compliance: PARTIAL` · `ux_accessibility_score: PARTIAL` · `implementation_feasibility: MEDIUM`

**`design_system_compliance: PARTIAL`** — unchanged, for the same reason as Revisions 2 and 3: the boards
are the sibling lane's (`C-11`), so board compliance is `UNVERIFIED` by this lane. What this revision adds
is **token-level and copy-level**, and it is normative: `N-8` binds § R.5.4's remediation copy (the largest
new body of user-facing text), `N-9` fixes the custody line, and § R.11g item 7 fixes the footer.
`product_detail_page.dart:471` and `:676` must lose their leading `referenceName` token, which changes
rendered output and therefore **invalidates committed `product_detail` goldens** (§ R.3.4).

**`ux_accessibility_score: PARTIAL`** — unchanged. The contrast figures are **inherited, not re-measured**
(`design-register-button/report.md:71-76`: `inkTertiary` = 4.23:1 dark, which **fails WCAG AA**;
`inkSecondary` = 6.74:1 light / 6.10:1 dark, both passing). **No contrast tool was run by this lane.**
Revision 4 adds one new user-facing surface — § R.11g item 5's refused-mint state — and **specifies no copy
for it**, deliberately: the copy belongs to the sibling lane, and `N-8`'s token binding applies to it
automatically. **A surface with no copy yet specified is a reason the score cannot be `PASS`**, and saying
so is more useful than scoring it on copy that does not exist.

**`implementation_feasibility: MEDIUM`** — the revision-level rating is unchanged, and the composition
underneath it is stated per component so the aggregate is not hiding a split:

| Component | Feasibility | Why |
|---|---|---|
| **Domain half** — split identity, credential lifecycle | **HIGH** | The engine methods exist; `createProduct` (`engine:43-61`) and `addRepositoryReference` (`engine:150-170`) already do what § R.10.1 step 3 needs |
| **Store half** — `D-4`, `D-5`, `D-6` | **HIGH** | Three statements (two on Tier A, one of which is `DO NOTHING`), two Dart predicates, **six** tests per tier, **five** required sentences in the contract doc. The call-site table (§ R.9.1) proves `D-4` cannot break `confirmHostKey`, `recordCredentialCheck` or `revokeCredential`; `T-J` proves `D-6` cannot break the legitimate setters. **Rev 5 (H9): eight columns per tier, not seven** — one extra `_noClear` clause and one extra `_clears` disjunct, which is the whole of the added work |
| **`G-14`** | **HIGH** | One method's data source, one selection rule, zero schema or wire change. The query already exists and already returns revoked rows |
| **`G-13` + `G-16`** | **HIGH** | Two reads and a `try`/`catch`, plus **one ownership call** (§ R.14.1 step 3a — `engine.resolveRepository`, which already exists and does the check). The hazard is that the *default* is destructive **and** that one of the columns it rewrites reparents a repository across products (`productId`, B6), so the discipline must be stated rather than assumed — which § R.14.1 does |
| **G-7 wire change** | **HIGH** | One field deleted from one model source; two regenerations; **twelve rows across SIX files** (H10). Boring, and it invalidates two fixtures' data as well as the goldens |
| **Substrate integration** — `SecretProvider`, `verifyProtection`, opaque handles, § R.5.7's compensation, the `apps/server` composition root | **MEDIUM** | No precedent in this repository; reachability `UNVERIFIED` (`G-10`); the unevaluable-policy case requires care rather than a pass-through; and the compensation construct has **FIVE** obligations (§ R.5.7 — L6's correction; Revision 4 said four in this table while the section itself listed five). **Two of them are the subtle ones:** obligation 3, a `destroy` that throws inside a `finally` masks the real error; and obligation 4 — **H8's finding is that Revision 4's FORM 2 never zeroed the buffer on the put-throws path, so one of the two forms this revision accepts did not meet the section's own normative requirement** |
| **SSH transport seam** | **LOW** | Nothing exists at the transport. It must deliver **two** security-critical capabilities (§ R.10.3), one of which is an ADR **requirement**, and the domain's existing enforcer does not help it because the domain does not make the connection |

`MEDIUM` at the revision level because the high-feasibility work is most of the change and the
low-feasibility work is a named, homed, separately-reviewable seam. **It would be dishonest to raise the
number because the substrate decision is settled**: settling *which* store to use does not make the
transport that fetches from it any less new, and it enlarges that seam.

### 9.3 Gates and commands — **nothing was run**

| Command / check | Status | Note |
|---|---|---|
| `dart analyze` / `flutter analyze` | **NOT_RUN** | Implementation-lane gate; no claim is made about its output |
| Build | **NOT_RUN** | — |
| `dart test packages/product_registry/test` | **NOT_RUN** | I make **no** claim about the state of `D-4`/`D-5`/`D-6` beyond what § R.9's reasoning shows |
| `make test-integration` | **NOT_RUN** | The only sanctioned exemption from the Docker rule; I did not need it and did not use it. `T-B`/`T-D`'s second half need it |
| **Any Docker or Compose command** | **NOT_RUN — none issued** | `AGENTS.md`'s read-only-over-shared-Docker rule binds this lane. I ran no `docker`, no `docker compose`, not even `ps`, `config` or `logs`. Compose files were read **as text** (`docker/compose.yaml:16-17`, `:63`; `.env.example:16-18`) |
| Contrast-ratio measurement (`N-8`) | **NOT_RUN** | Ratios **inherited** from `design-register-button/report.md:71-76` and independently re-measured by the Gate D3 review. **Not re-measured here** |
| `T-A` … `T-L` execution | **NOT_RUN** | `T-A`/`T-B`/`GAP-2` are reported as passing **by the implementer's report at `07c8c8f`**; I did not re-run them and make no claim of my own. `T-C`…`T-L` are **specified, not executed**; their predicted pre-fix failures are stated as predictions from the code path |
| The `fix/credential-identity-invariants` gates | **NOT_RUN by me** | That lane reports format/analyze/unit/integration/schema all passing, and its review re-ran them. **I did not re-run any of them and do not adopt its results as mine** |
| Penpot boards | **NOT_RUN / not authored** | Prohibited for this lane (`C-11`) |
| ADR 0018 amendment — merge, edit, review | **NOT_RUN — none of the three** | `docs/adr/**` is `PROHIBITED_PATHS` and independent design review is not this lane's. § R.17.1 reports its state: **merged at `5436a4d`, human-accepted, never independently reviewed, and carrying two now-false no-decision-object statements (`G-17`)**. I did not merge, edit or create it, and make no claim of having done so |
| **Deletions** | **NONE MADE** | This lane created and edited **only** files under `docs/engineering/dispatch/tasks/design-addproduct-keyservice/`. **No file was deleted, moved or renamed anywhere in the repository, and I make no claim of any such action.** (Revision 3's predecessor once reported deletions that had not happened; this line is here so a reviewer does not have to wonder) |
| Read-only source inspection | **pass** | Every `file:line` in this revision was opened and read at **[5436a4d]**, plus the one remaining out-of-base worktree labelled `[UNCOMMITTED 0bf2fa0]`. § 0.3's ancestor check and `git hash-object` were run and their output is recorded in § 0.3 and the metadata. **`design-adr-0018-amendment` is no longer an out-of-base source** — it is tracked at `5436a4d` (citation index row 21) |
| **The Rev-4 review report** | **NOT_FOUND — disclosed** | `tasks/review-addproduct-keys-rev4/report.md` **does not exist** in any of the 31 worktrees, in the canonical repository, or in any commit reachable from any ref; `tasks/design-review-addproduct-keys-rev4/` exists and is **empty**. § 0.7. **I corrected against the Manager's relay and re-verified every finding's evidence against source** |
| Commit / push | **NOT_RUN** | `COMMITTED: NO`, `PUSHED: NO`, as instructed |

### 9.4 `UNVERIFIED` — with the command a human should run

| Claim | Status | What a human should run |
|---|---|---|
| **A3 is reachable in this repository's target topology** | `UNVERIFIED` — **`G-10`**, and the decision's own follow-up action | Provision the manager and run `verifyProtection` against it from the server container. Until this, the design's substrate rests on a decision whose reachability no one has tested |
| A real SSH transport accepts the generated public key | `UNVERIFIED` | Start a stack with an explicit `-p`, install the returned `publicKey` into a scratch repo's `authorized_keys`, run a real check |
| Host-key `changed` detection against a host presenting a different key | `UNVERIFIED` | Requires such a host |
| `secretReferenceMissing` is reachable and surfaces correctly | `UNVERIFIED` | Delete a manager object out of band and run a check |
| `D-2`'s index collapses concurrent mints | **`UNVERIFIED by me`**; reported green at `07c8c8f` | `T-B` against the Postgres-backed store |
| `D-1`'s predicate behaves as specified on this driver | **`UNVERIFIED by me`**; reported green at `07c8c8f` | `T-A` against the Postgres-backed store |
| `D-4`/`D-5`/`D-6` behave as specified **on both tiers** | `UNVERIFIED` — **specified here, not merged** | `T-C`…`T-G`, `T-J`, `T-K` on both tiers |
| **`D-6` refuses the erasure of all EIGHT columns on both tiers** | `UNVERIFIED** — **and Revision 4's constructs would NOT have** | `T-K` with all eight named. **A test that counts columns cannot detect H9's defect; the test names them** |
| **The mint endpoint refuses a foreign `repositoryId` on both tiers** | `UNVERIFIED** — **and Revision 4's sequence would NOT have** | `T-L` against the real endpoint sequence, both store tiers |
| **`readCredentialsForProduct` orders its result on both tiers** | **`UNVERIFIED` — Tier B has no ordering today** (`in_memory:236-238`) | § R.9.7's item 5, then `G-14`'s selection rule |
| The compensation construct keeps a successful handle | `UNVERIFIED` | `T-I` |
| A refused substrate mint writes zero rows at all three tiers | `UNVERIFIED` | `T-H` |
| The duplicate-credential audit finds no duplicates anywhere deployed | **`NOT_RUN, and not runnable from any lane** — **`G-12`** | The **corrected** query, by a human, against every deployed database, before migration `20261006150645000` |
| Loopback pinning un-implemented | **VERIFIED (negative)** | `grep -rn "127.0.0.1:" docker apps/server/docker-compose.yaml` → no match |
| Host-key verification absent **at the transport** | **VERIFIED (negative)** | grep for the five host-key tokens across `apps`/`packages` → 0 matches |
| Host-key verification present **in the domain** | **VERIFIED (positive)** | `engine:1047-1052`, `:1162-1167`; `repository_credential.dart:128-129` |
| No Serverpod endpoint reaches `recordGeneratedCredential` | **VERIFIED (negative)** | `grep -rn recordGeneratedCredential apps/server/lib/src/endpoints/` → no match |

---

## 10 — Readiness

**Ready for Independent Design Review of Revision 5. Not approved by its author.** Revision 4's review was
`CHANGES_REQUIRED`; Revision 3's was too; Revision 2's approval does not carry over; and this revision
carries **no** approval from any reviewer.

**Gate D4 status.** The human's six decisions are taken, `ae1c1f79` is taken, and the ADR 0018 amendment is
**human-accepted** — `876c6b97`, amendment revision 2 — **and has never been independently reviewed**
(`reviewed_by: null`). **Revision 5's own content requires human approval** at its risk level.

**One caveat on this review, stated so the reviewer is not surprised (B5, M5, and § 0.7).** Two of the
findings corrected here concern artifacts this revision does not own: the ADR 0018 amendment's acceptance
and the ADR's own now-false "no decision object" statements (`G-17`). **I recorded and cited them; I did not
edit them**, because `docs/adr/**` is `PROHIBITED_PATHS`. And the Rev-4 review report itself is **not on
disk**, so this revision is corrected against the Manager's relay with every finding's evidence
re-verified against source at `5436a4d`.

### 10.1 Manager actions — all outside `OWNED_PATHS`, none performed by me

**Withdrawn, because the base moved (B1):**

| ~~Was~~ | Why withdrawn |
|---|---|
| ~~Re-base this revision~~ | **DONE TWICE.** `BASE_SHA = HEAD_SHA = 5436a4d`, reached by `git merge --ff-only main` from `361256c` (a fast-forward). It contains `43d328b`, `e391c02`, `4e2d237`, `0bf2fa0`, `1aa8755` and `07c8c8f`. § 0.3 |
| ~~Retract the false ledger facts at `LANES.md:204-205`~~ | **DONE** at `4e2d237`. At this base `LANES.md` is **427** lines and `:204-205` reads the retraction |
| ~~Record `AGENTS.md §13`/`§13b` as a governance action (`G-1′`)~~ | **DONE** at `0bf2fa0`. `AGENTS.md` is **199** lines; §13 `:65`, §13a `:72`, §13b `:78`, per-repository keypair `:91`, restoration note `:96-101` |
| ~~Confirm or correct § R.5.2's ordering interpretation~~ | **DONE** by `ae1c1f79` OPTION_A, which adopted Revision 3's reading. § R.5.2 is decided content |
| ~~**Merge the ADR 0018 amendment** into `docs/adr/**`~~ | **★ WITHDRAWN — the premise was false (M5).** The amendment **is** an in-place edit of `docs/adr/0018-per-product-git-credentials.md`, and it **is committed and landed at `5436a4d`**. There was never a merge to perform. **Replaced by actions 1a and 1b below, which are what is actually outstanding** |

**Open, and needed:**

1. **★ REPLACES Revision 4's "merge the ADR amendment" — two things, because the merge was never the gap
   (M5).**
   **1a — Independent design review of ADR 0018 amendment A2.** It is human-**accepted** (`876c6b97`;
   amendment revision 2) and has **never been reviewed**; `reviewed_by`/`reviewed_at` are `null` **on
   purpose**, and the amendment's own `acceptance_is_not_review` field says an accepted design is not a
   reviewed artifact. **`876c6b97`'s own first follow-up action names this, owned by the independent design
   reviewer.** This design's § R.10.3 adopts the amendment's § 3.1 finding, so the finding is load-bearing
   here. **Owner: the independent design reviewer.**
   **1b — Correct ADR 0018's two now-false statements about its own acceptance (`G-17`).** `ADR:16-21` and
   `ADR:572-580` both say **no Human Decision object records this acceptance** and that *"the acceptance has
   no citable decision id"*. `876c6b97` exists and landed in the **same commit** (`5436a4d`) as that ADR
   text. **Two sentences, one file. `docs/adr/**` is `PROHIBITED_PATHS` for this lane — I did not edit it and
   make no claim of having done so. Owner: the ADR lane, or the human as ADR owner.**
   **Neither of these is a `HUMAN_DECISION_REQUIRED` gate on *this* revision.** They are Manager-owned
   follow-ups, listed because § 9.1's R6 now rests on them.
2. **Dispatch `D-4`/`D-5`/`D-6`** (`G-11`) — **per tier, as § R.9 now specifies**, which is more work than
   Revision 3 asked for and the reason B4 was a blocker. They should **merge ahead of this feature**:
   `T-D` blocks `79e860e2`'s own follow-up test, and `SC-13` depends on both `D-4` and `D-6`.
3. **`G-14` before the revoke UI ships.** § R.14.3's endpoint makes revocations invisible to the product
   detail until `G-14` lands, and § R.11.1 state 4 renders as state 1's copy until it does. Small, and
   strictly ordered.
4. **Implement `ae1c1f79`'s third follow-up action** — *"Implement the precondition check ahead of the first
   write, and cover it with a test proving a refusal leaves `Product` and `RepositoryReference` counts
   unchanged."* `T-H` is the test (§ R.9.6).
5. **`G-13` and `G-16` in the same dispatch as 2**, or in the mint endpoint's own item — **`G-16` first.**
   `G-13` is two reads and a `catch`; `G-16` is **one ownership call** (§ R.14.1 step 3a) plus `T-L`. Both
   are invisible on the happy path, and `G-16` is the more serious of the two: without it the endpoint
   **discloses another product's credential** on a control plane with **no authentication** (§ R.15.1). **Do
   not let `G-16` ride along as a tidy-up inside `G-13` — it is a disclosure, not a data-freshness issue.**
6. **Notify `design-addproduct-mobile`** of § R.11g — **items 1, 2, 4, 6, 7** were previously notified;
   **item 3** (the flow must be re-enterable from the product) is a **requirement on the sibling lane's
   design**, and **item 5** (`ae1c1f79`'s board consequence). **★ § R.11g now carries a "what the sibling
   needs" block** — items 3 and 7's corrected line numbers, the shared-primitive requirement neither lane
   owns, and the `Art S` custody string — **because that lane is blocked on Penpot and cannot re-ground the
   Unknown-host pair without this revision. It cannot ask me.** Also note for the Manager: that lane's
   current artifact is based on **`77c19f1`**, so it carries the stale-base condition this revision fixed in
   Revision 4 and again here, and it states `9417f8bf` as `PENDING` though it has been RESOLVED since
   `2026-10-06T13:05:00Z`. **Not my file to fix, and the Penpot block is not mine to clear.**
7. **Retire the `repositoryId: productId` placeholder** (`add_product_page.dart:171`, comment at `:171`
   reading *"Use productId as repositoryId for simplicity"*) and decide **who issues `repositoryId`**
   (§ R.14.1). **With § R.14.1 step 3a in place this is now merely redundant rather than a disclosure — that
   ordering is deliberate.** Also **grant `packages/product_registry/lib/src/exceptions.dart`** to the
   `D-4` implementer so `G-15` can close.
8. **Human-run deployment actions, none runnable from a lane:**
   - **`G-12`** — the duplicate-credential audit, with the **corrected** query, against **every** deployed
     database, **before** migration `20261006150645000` is applied anywhere.
   - **ADR 0018 `:103`'s wording** — *"Rotation is per product"* against its own `:104` (M5 re-anchored: the
     clause is at `ADR:261-262` at this base and the ADR records the inconsistency itself at `:540-542`).
     § R.17 upholds the clause and flags the wording. **No merge action remains here** — see action 1.
9. **`L-6`** — `DECISIONS.md`'s index table (`:8-12`) omits `570bb640`, and `:16`'s *"All five are `PENDING`"*
   is false. **Manager-owned — reported, not edited.**
10. **`G-10`** — the A3 reachability probe, assigned by `9417f8bf` to the implementer, still un-run.
11. **Supply the Rev-4 review report, or accept the Manager's relay as the finding set of record (§ 0.7).**
   `tasks/review-addproduct-keys-rev4/report.md` does not exist in any worktree or in any reachable commit.
   Every finding's *evidence* was re-verified against source at `5436a4d` and two corrections were made
   against source rather than against the relay (§ R.11g item 7's `_buildFooter` lines, and § R.9.1's
   `confirmHostKey` citation) — but a correction can answer the wrong sentence if the finding's wording
   differs from its substance. **Owner: the Manager.**

### 10.2 What a reviewer should check hardest — **each item is now checkable (L2)**

Revision 3 asked a reviewer to *"verify the three-revision labelling is complete and that no citation is
silently at the wrong SHA"*, which was uncheckable because no index existed. Every item below names **what
to run** and **what would falsify it**.

1. **§ R.5.7's compensation construct — obligation 1 and 2.** *Check:* read the construct, then ask whether
   any `finally` in the implementation can destroy a handle after `recorded = true`. *Falsified if:* a
   `destroy` is reachable on the success path, or `recorded` is set anywhere but immediately after
   `recordGeneratedCredential` returns. **This is the finding most likely to have been half-fixed** — a
   catch block that forgets the success case reads correctly and is wrong.
2. **§ R.9.1–R.9.4's per-tier split.** *Check:* for each of `D-4`, `D-5`, `D-6`, name the Tier A construct
   and the Tier B construct and confirm they refuse the same writes. *Falsified if:* either tier has a
   predicate the other cannot evaluate — which is the exact defect
   `product_credential_immutability_postgres_test.dart:29-31` exists to catch. **Then delete `D-4` and
   confirm `T-D` goes red** — that is the mask check from § R.9.4.
3. **§ R.9.4's "may SET" half against `T-J`.** *Check:* that `revokeCredential`, `confirmHostKey` and both
   `recordCredentialCheck` branches still succeed. *Falsified if:* `D-6` refuses any of them — which is
   what Revision 3's unsatisfiable sentence would have produced.
4. **§ R.9.2's mechanism table.** *Check:* that the **engine's one-active guard** is named as the guard
   that stands down, and `D-2` as the backstop rather than the refuser. *Falsified if:* `D-2` is described
   as preventing the resurrection.
5. **§ R.11.2's `G-14`.** *Check:* `control_plane_service.dart:360-367` plus
   `readCredentialsForProduct`'s two implementations. *Falsified if:* the fix requires a new model field,
   or if state 4 is still reachable only through `AccessStatus`.
6. **§ R.3.2's change list.** *Check:* run the grep in its caption and classify each hit against rows A–D.
   *Falsified if:* a hit is unclassified, or `protocol.dart` is treated as changing. **Then delete
   `referenceName` from the model source and run `dart analyze`** — the two fixtures must be the first
   compile errors, which is the claim row 11 makes.
7. **§ R.10.3's split.** *Check:* `engine:1047-1052` and `:1162-1167` for the domain half;
   `git_workspace_inspector.dart:106-112` plus the five-token grep for the transport half. *Falsified if:*
   either half is described without the other.
8. **§ R.14.1's ordering.** *Check:* that the get-or-create read is after the reference creation, calls the
   **store** method, and that `G-13`'s read-first discipline is stated for **both** rows. *Falsified if:*
   `engine.readActiveCredential` appears before the reference exists — it throws
   `RepositoryNotFoundException` on a first mint (`engine:1139`; `exceptions.dart:12`).
9. **§ R.1.7's boundary.** *Check:* `grep -rn "SecretProvider" packages/product_registry/` → 0 matches in
   production sources. *Falsified if:* it appears anywhere in the domain package.
10. **§ 0.3's citation index and content pins (L13).** *Check:* the ancestor loop in § 0.3, spot-checks of
    one citation from each of the 22 rows, **and `git hash-object` on each artifact row**. *Falsified if:*
    any `file:line` does not resolve at `5436a4d`; **or any artifact's blob hash differs from the metadata's
    `artifacts[].blob_hash`** — which would mean the reviewed content is not what this revision corrected;
    **or a `[UNCOMMITTED …]` citation is found doing the work of a repository-state claim**; **or any ADR
    0018 `:NN` is read as a current-base line number** — they are A1-revision numbers, and § R.17.1's
    re-anchoring table is the map.
11. **§ 9.1's tally — 0 / 2 / 4, character for character, in all three places (B5, L7).** *Check:* that
    `design-revision-5.md` § 9.1, `design-revision-metadata-5.yaml` → `risk_rationale` and
    `report-revision-5.md` each carry the **same sentence** — **`0 reasons IMPROVED, 2 reasons UNCHANGED
    (R1, R6), 4 reasons WORSE (R2, R3, R4, R5)`** — and that no other tally appears anywhere. *Falsified
    if:* a fourth copy has crept in (that was H6); **if the three copies differ by a single word** (that was
    L7, and verbatim-that-is-not-verbatim is worse than no claim of verbatim); **or if R6's status cell
    says IMPROVED** — the acceptance is real now, but `reviewed_by` is `null` and the amendment's revision 1
    over-claimed its own protection against A1.
12. **§ R.18.2's registers.** *Check:* that `G-12`, `G-13`, `G-14`, `G-15`, **`G-16`, `G-17`** appear in
    **both** this table and `requirements_gaps` in the metadata, and that `G-1′` and the LANES row appear in
    **neither** as open. *Falsified if:* a gap lives in prose or a changelog only — which is M1, and the
    pattern that produced it. **`G-16` is the one to check hardest: it is a gap this revision *created* by
    reviewing the previous one.**
13. **★ § 0.2 and § R.17.1's acceptance citations (B5).** *Check:* that every place this revision says the
    ADR amendment was accepted names **`876c6b97`** *and* **amendment revision 2**; that it states
    **acceptance is not review**; and that **`reviewed_by: null`** is reported as the amendment's own
    deliberate choice rather than as an omission. *Falsified if:* a bare "Accepted" survives anywhere
    without a citation beside it — **that was B5, and it survived one full review cycle in Revision 4.**
14. **★ § R.8.5's two comments (L9, L10).** *Check:* that the `store:312-319` blockquote is **complete**,
    including the trailing `rotateCredential` sentence; **and** that `credential_test.dart:348` is named
    with its citation corrected to **`engine:954-961`**. *Falsified if:* the quote is truncated again — the
    truncation deleted the only sentence in that comment that is still true.

---

*End of Design Revision 5. `REVISION_ID 7C1E4A96-2B58-4D3F-A0C7-5E19D28B4F63` · `RISK_LEVEL 3` ·
`design_system_compliance PARTIAL` · `ux_accessibility_score PARTIAL` · `implementation_feasibility MEDIUM`
· `BASE_SHA 5436a4d` · `HEAD_SHA 5436a4d` · `COMMITTED: NO` · `PUSHED: NO` · no Docker command issued ·
not approved by its author. Revisions 1–4 retained intact; no prior approval stands behind any of them.*
