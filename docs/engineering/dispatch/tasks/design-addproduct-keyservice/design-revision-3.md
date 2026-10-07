> ## SUPERSEDED BY DESIGN REVISION 5 — `7C1E4A96-2B58-4D3F-A0C7-5E19D28B4F63` (`design-revision-5.md`)
>
> This artifact is **retained verbatim**. **No body line below has been edited** — only this banner is
> added. Its `REVISION_ID`, `BASE_SHA` and `HEAD_SHA` are its own and are **not** current: the chain is
> now at `5436a4d`.
>
> **Revision 4 was returned `CHANGES_REQUIRED` (2 BLOCKERS, 3 HIGH, 4 MEDIUM, 9 LOW) and was never
> approved. NO approval of any kind stands behind Revisions 1, 2, 3 or 4.**
>
> **The three things in here that Revision 5 corrects, so a reader does not carry them forward:**
> **§ 9.1's tally** (`1 reason IMPROVED (R6), 1 UNCHANGED, 4 WORSE`) is **withdrawn** — its IMPROVED
> leg rested on an ADR-amendment acceptance that did not exist on the record at `361256c`, and the true
> tally is **0 IMPROVED / 2 UNCHANGED / 4 WORSE**; **every "the amendment is Accepted" sentence here is
> uncited**, and the acceptance is now real and citable at `876c6b97` + amendment revision 2 — **but
> acceptance is not review and the amendment has never been independently reviewed**; and **§ R.14.1
> step 4 as specified below is a cross-product disclosure** — § R.14.1 **step 3a** and test **`T-L`** are
> the fix. Its `G-13` blast radius also omits `"productId"`, the one column whose rewrite reparents a
> repository across products.
>
> **⚠ The Rev-4 review report is ABSENT from the repository** (`tasks/review-addproduct-keys-rev4/` exists
> and is empty), so Revision 5 was corrected against the Manager's relay with every finding's evidence
> re-verified at `5436a4d`. See `design-revision-5.md` § 0.7.

> ## ⚠ SUPERSEDED BY REVISION 4 — `F2D5AF31-CA53-481A-ACB4-C75DB033A15A`
>
> **REVISION 3 WAS NEVER APPROVED.** A fresh independent reviewer returned
> `RESULT: DESIGN_REVIEW_CHANGES_REQUIRED` (`REVIEWED_HEAD 77c19f1`, `CORRECTION_REQUIRED: YES`,
> `HUMAN_DECISION_REQUIRED: NO`, `INDEPENDENT_RISK_LEVEL: 3`, `RISK_LEVEL_AGREEMENT: YES`) with
> **4 BLOCKERS, 7 HIGH, 2 MEDIUM and 4 LOW** —
> `docs/engineering/dispatch/tasks/review-addproduct-keys-rev3/report.md`, tracked on `main` at `1aa8755`.
> **No approval of any kind stands behind this document**, and none carries over to Revision 4.
>
> **This document is retained intact as the artifact that was reviewed. Its content below is NOT edited
> and must not be implemented.** Revision 4 states each correction in its own text rather than editing
> here, so the reviewed artifact stays checkable.
>
> **Its base was stale, and that was one of the blockers.** `BASE_SHA`/`HEAD_SHA` `77c19f1` is **not** an
> ancestor of `main` and does not contain `e391c02`, `07c8c8f`, `4e2d237`, `0bf2fa0`, `1aa8755` or
> `ae1c1f79`. **Two gap entries in § R.18.2 were therefore false** (`LANES.md:204-205`, `G-1′`) and
> **§ 10.1's items 3, 6 and 7 asked for actions already taken.** Revision 4's base is `361256c`.
> See `discoveries.md` **D-20** and Revision 4 § 0.3.
>
> **Withdrawn from this document, by name — the full list is Revision 4's changelog and § 0.4:**
>
> - **§ R.5.2 step 5 and § R.14.1 step 5** — *"`destroy(handle)` in a `finally`"*. **Dart has no
>   failure-only `finally`; on the literal reading the SUCCESS path destroys the handle just recorded.**
>   Replaced by Revision 4 § R.5.7, one construct with five obligations, referenced everywhere.
> - **§ R.16 row 46's *"no new server field"*** — **false.** `loadProductDetail` reads only
>   `readActiveCredentialForRepository`, which excludes revoked rows on both tiers, so § R.11.1's state 4
>   is **indistinguishable from state 1**. Replaced by Revision 4 § R.11.2 / gap `G-14`.
> - **§ R.9.1–R.9.3's SQL-only `D-4`/`D-5` and their CAS-branch extension** — the named tests `T-C`/`T-F`/
>   `T-G` are **entirely in-memory**, and the extension was **unsatisfiable** (`revokeCredential` legitimately
>   SETS `revokedAt` through that branch). Replaced by Revision 4 § R.9.1/§ R.9.3 (per tier) and § R.9.4
>   (`D-6`).
> - **§ R.5.2 step 1 and § R.10.1 step 1** — deriving `host` from `RepositoryReference.uri` at step 1 while
>   step 2 creates that row. **Unsatisfiable ordering** in two normative locations.
> - **§ R.14.1 step 2** — the get-or-create read **precedes** the `RepositoryReference` it needs, and the
>   endpoint signature had **no `repositoryId`**. `engine:1139` throws `RepositoryNotFoundException` on a
>   first mint, so the step **threw instead of returning `null`**.
> - **§ R.6.1's pseudocode** — attributed to `revokeCredential`, so it reads as engine code and would place a
>   `SecretProvider` call inside `packages/product_registry`. Re-attributed to `apps/server` (Revision 4
>   § R.1.7).
> - **§ R.3.2's seven-row change list** — **twelve rows across eleven files**; two fixtures **will not
>   compile**; the client's `protocol.dart` is a **no-op**.
> - **§ R.10.3 and § R.7.1's *"no runtime enforcer" / *"decorative"*** — **over-broad.** The **domain**
>   enforces `HostKeyStatus` (`engine:1047-1052`, `:1162-1167`); the **transport** does not.
> - **§ R.9.3's host-trust sentence** — conflates the mint path (which **destroys** a confirmation) with the
>   CAS branch (which **carries** it). Both contradict ADR 0018 `:96-99`, differently.
> - **§ R.18.2's `G-1′` and `LANES.md` rows** — **closed** by `0bf2fa0` and `4e2d237`.
> - **§ 9.1's risk tally** — incoherent across three artifacts. Revision 4 publishes **one** tally, in three
>   places, verbatim.
> - **§ 10.1 item 3** — **withdrawn**: `ae1c1f79` RESOLVED OPTION_A and **adopted this document's reading**.
>
> **Confirmed correct by that review and carried unchanged:** the substrate option set is genuinely gone and
> the human's reserved decision is not nudged anywhere; § R.1.3 is a proper judgement; `D-18`'s derivation
> re-derived and confirmed independently; § R.9.1's call-site table is exact; revocation two-sided; fail-closed
> end to end; the B6 split is honest; ≈40 sampled citations all resolved at their labelled SHA.
>
> Successor: **`design-revision-4.md`** (`F2D5AF31-…`), `RISK_LEVEL 3` (re-derived), `BASE_SHA`/`HEAD_SHA`
> `361256c`, `COMMITTED: NO`.

---

# Design Revision 3 — server-side deploy-key service, against resolved Gate D4

**Revision ID**: `4B017787-25A0-4F45-ABDA-805C250AF63F`
**Brief ID**: `97484D0E-E16C-485E-BAA2-A277889C0FB6` · **Brief version**: `1.1.0` (`design-brief-1.1.0.md`)
**Revision number**: 3 · **Status**: DRAFT · **Risk level**: **3** (re-derived in § 9, not inherited)
**Supersedes**: `F21D5C64-006D-4203-A813-841E08E38B95` (Revision 2), **retained intact** at
`design-revision-2.md`. Revision 1 (`46980EE0-E638-409C-A7D3-E1B9399FECE5`) is retained intact at
`design-revision.md` and was edited by neither Revision 2 nor this revision.
**Independent review of Revision 2**: `RESULT: DESIGN_REVIEW_APPROVED`, `REVIEWED_HEAD 77c19f1`,
content anchor `3a87e27`, `INDEPENDENT_RISK_LEVEL: 3`, `RISK_LEVEL_AGREEMENT: YES`
(`docs/engineering/dispatch/tasks/design-review-addproduct-keyservice/report-revision-2.md`).
**Worktree**: `/private/tmp/shipit-correct-addproduct-keys` · **Branch**: `design-correct-addproduct-keys`
· **Base SHA**: `77c19f1` · **HEAD SHA**: `77c19f1` · **Committed**: NO

**No Docker or Compose command was executed by this lane** — none issued, not even a read-only one.
No analyzer, build, test or contrast tool was run. See § 9.3. Every unrun gate is `NOT_RUN`.

---

## 0. What this revision is, and the bound on Revision 2's approval

### 0.1 Why Revision 3 exists

Revision 2 was written against **unresolved** Gate D4 decisions and correctly refused to default any of
them. The human then resolved all six (`674b871`, `decided_at 2026-10-06T13:05:00Z`). Five change the
design's normative content; one (`4d2c6b81`) reports work already built and reviewed. Revision 3
therefore **replaces** Revision 2 on its central question rather than amending it.

| Decision | Outcome | What it changes here |
|---|---|---|
| `9417f8bf` | **OPTION_C — A3, an external secret manager** | § R.4's four-option substrate set is **withdrawn**. § R.1 is closed and normative. § R.3 G-7 becomes **REQUIRED**. § R.5's degraded path becomes a common path. § R.6 revocation gains a ShipIt-side action. |
| `7b1bc8b7` | **OPTION_A — fail closed with named remediation** | § R.5 is written end to end, including the **remediation copy itself** as a required deliverable. |
| `79e860e2` | **OPTION_A — destroy the private half on revoke, keep the row** | § R.6. Two-sided revocation. **ADR 0018 `:113-114` is superseded.** |
| `898b07d0` | **OPTION_A — split identity from registration** | § R.10. The key flow now creates the `Product` row first. **ADR 0018 `:100-102` is upheld.** § R.12's read path stops being conditional. § R.11g is a binding consumption contract for the sibling lane. |
| `27ea6536` | footer copy removed on both platforms; per-platform footer structure | Sibling lane's scope (`C-11`). Recorded here as binding coupling (§ R.11g item 6, `SC-06`). **No board is authored and none is edited by this lane.** |
| `4d2c6b81` | **OPTION_A — index goes into a migration as well as the bootstrap** | **Already implemented and independently reviewed** at `07c8c8f`. § R.8 states what now rests on the resulting invariant instead of proposing it. |

**The substrate question is closed and is not re-presented anywhere in this revision.** There is no
option set, no confidence table, no "if the human answers…", and no hedge. The one design choice this
revision makes *inside* the resolved decision is stated and bounded in § R.1.3, where it belongs.

### 0.2 What Revision 2's approval was worth, and what it was not — recorded per `LEARNING_POLICY.md`

A fresh independent reviewer approved Revision 2. That approval was real and earned: the reviewer
verified clause by clause that ADR 0018 had been read, that the claimed hole in the store was real, and
that the reviewer's own tempting fix — a version CAS — would have left the hole open **and** broken
minting. That work is carried forward here and nothing in this subsection diminishes it.

**But the approval's value was bounded by what was open at review time, and that bound belongs in this
artifact rather than only in the review record.** Per `docs/engineering/LEARNING_POLICY.md` this is
classified and persisted as `D-15` in `discoveries.md`:

> **A design approved against unresolved human decisions is superseded the moment those decisions
> resolve, and its approval is bounded by the open set.** "Open" is not an absence of risk — it is a
> **scope limit on the review**. A reviewer can verify that a design correctly presents and correctly
> withholds an open question; they cannot verify the content of an answer. So a Gate D3 approval of a
> design carrying `OPEN-D4-*` items certifies **the framing, not the design**. Two consequences follow,
> and both are workflow rules rather than opinions:
>
> 1. **The approval record must name the open set.** `report-revision-2.md` § 3 did name it, and
>    `HUMAN_DECISION_REQUIRED: YES` was set correctly. That is the behaviour to keep, and it is why this
>    defect was visible within hours instead of being discovered in implementation.
> 2. **A revision written against open decisions must carry a `SUPERSEDED_BY_DECISION` disposition
>    before the resolutions land**, so the ledger marks it rather than a human noticing later. The
>    Manager did that (`WORK_STATE.md` `DESIGN_SUPERSEDED_BY_DECISION`); the artifact did not. This
>    revision therefore carries the disposition itself — here, and in the header of
>    `design-revision-2.md`.
>
> The generalisation: **"correctly deferred" is a claim a reviewer can check, and it is not the same as
> "ready to build".** A design that has discharged its duty to the human is not thereby discharged of
> the answer.

### 0.3 Correction map — every Revision 2 open marker, and where it lands

| Revision 2 marker | Revision 3 disposition |
|---|---|
| § R.1 / § R.1.1 `Q1′` — does server-side custody supersede ADR 0018 `:85-88`? **OPEN** | **ANSWERED YES** — `9417f8bf` OPTION_C. Replaced by § R.1, closed. |
| § R.4 — the four-option substrate set **A1–A4**, presented as options | **WITHDRAWN** — § R.4 is now a withdrawal notice naming what replaced it. A3 specified in § R.1; A1/A4 are the **documented fallback** in § R.1.5 with an explicit trigger; A2 is **excluded** in § R.1.6. |
| § R.4.1 `Q4` — may `referenceName` reach the client? **OPEN** | **ANSWERED NO** — § R.3.2 G-7 is **REQUIRED**, with the change, its blast radius, and what the client receives instead. |
| § R.5 `Q2` — fail open vs fail closed. **OPEN** | **ANSWERED fail closed** — `7b1bc8b7` OPTION_A. § R.5 written end to end. |
| § R.6 `Q3′` — does ADR 0018 `:113-114` survive the custody move? **OPEN**, with a C-1/C-2/C-3 menu | **ANSWERED NO, and C-1 chosen** — `79e860e2` OPTION_A. § R.6. The C-2/C-3 menu is withdrawn. |
| § R.19 / § R.19.2 — registration ordering, three options, **OPEN** | **ANSWERED option 1** — `898b07d0` OPTION_A. § R.10 states the new state machine. Options 2 and 3 are withdrawn; option 3's ADR contradiction is moot because `:100-102` is upheld. |
| § R.15b.1 `D-1`, § R.15b.2 `D-2` — required deliverables, **proposed only** | **DONE** at `07c8c8f`, independently reviewed. § R.8 states the invariant they now establish and itemises what rests on it. `D-1`'s named exception type was not used (the behaviour is typed `CredentialNotUsableException`) — a naming follow-up, recorded. |
| § R.15b.3 `T-A`, `T-B` — *\"fail today\"* | **PASS** per the implementer's report at `07c8c8f`. **Not re-verified by this lane** — no test was run. New tests `T-C`–`T-G` specified in § R.9.5. |
| `G-7` — owner `9417f8bf`, *\"a gap\"* | **REQUIRED WORK**, specified in § R.3.2. The owner is now this lane, per `9417f8bf`'s own follow-up action. |
| `G-9` — ADR 0018 A1's one-per-repository invariant not a DB constraint | **CLOSED** — the partial unique index is in **both** `tool/schema_bootstrap.sql` and migration `20261006150645000` (§ R.8.1). |
| `L-B` (reviewer) — the word *"default"* used of C-2 under `Q3′=YES` | **Moot** — `Q3′` is answered; § R.6 states the answer without the word. |
| `L-E` (reviewer) — branch recorded as `design/correct-addproduct-keys` | **Fixed** — `design-correct-addproduct-keys` in this header, in `design-revision-metadata-3.yaml`, and in the note added to `design-revision-2.md`. |
| `AC-03` — *\"at-rest model presented as an OPEN decision, defaulted nowhere\"* | **Superseded by its own resolution.** The brief's `AC-03` was a correct obligation while `C-01` was in force; `C-01` is discharged. `SC-08a` replaces it (§ 8): the model is now carried as decided, and **re-presenting it as open is itself the defect**. |

### 0.4 Citations in this revision span three revisions — read this before checking any `file:line`

This lane's `HEAD_SHA` is `77c19f1`. **The resolved decisions (`674b871`) and the store-integrity branch
(`07c8c8f`) are not ancestors of it** — verified: `git merge-base --is-ancestor 07c8c8f 77c19f1` → not
an ancestor; the same for `674b871` and `3a87e27`. **A reviewer therefore cannot verify this revision
from this worktree alone.** Every citation is labelled with the revision it was read at:

| Label | SHA | Read from | Contains |
|---|---|---|---|
| **[77c19f1]** | my `BASE_SHA`/`HEAD_SHA` | `/private/tmp/shipit-correct-addproduct-keys` | ADR 0018, the control plane, compose files, the client page |
| **[07c8c8f]** | `fix/credential-store-integrity` | `/private/tmp/shipit-credential-store` (**read-only**) | the store, the engine, the credential tests, `D-1`/`D-2`, migration `20261006150645000` |
| **[6220951]** | `main` | `/Users/alkebut/air/shipit-platform` (**read-only**) | the six resolved decision objects |

Unlabelled citations are at **[77c19f1]**, which is where Revisions 1 and 2 put them. Where a line number
moved between `77c19f1` and `07c8c8f` I give both, because Revision 2's numbers are what a reviewer has
already read. **This is a lane-hygiene defect rather than a content defect**, and § 10 asks that
Revision 3 be re-based onto a branch containing both `07c8c8f` and `674b871` before it is implemented.

### 0.5 Section map — Revision 2 → Revision 3

| Revision 2 § | Revision 3 § | Disposition |
|---|---|---|
| R.1, R.1.1, R.1.2 | **R.1** | **Replaced** — closed, normative |
| R.2 | **R.2** | Carried, amended (§ R.2.4 is new) |
| R.3 | **R.3** | Carried; **R.3.2–R.3.4 new** (G-7 required) |
| R.4, R.4.1 | **R.4** | **Withdrawn** — replaced by R.1 / R.1.5 / R.1.6 |
| R.5 | **R.5** | **Replaced** — degraded path, end to end |
| R.6, R.6.1, R.6.2 | **R.6** | **Replaced** — two-sided revocation |
| R.7, R.7.1 | **R.7** | Carried; threat-model row amended for A3 |
| R.8 | **R.8** | **Replaced** — the store invariant is real |
| R.15, R.15.1–R.15.4 | **R.8.2, R.9** | Superseded by what landed, plus two new findings |
| R.15b | **R.8.1, R.9** | `D-1`/`D-2` done; `D-4`/`D-5` new |
| R-2, R.9, R.10 (`N-1`–`N-8`) | **R.10** | Carried unchanged; **`N-9` new** (§ R.10.1) |
| R.11 | **R.11** | Carried; **§ R.11.1 and § R.11g new** |
| R.12 | **R.12** | Carried; **no longer conditional** on the ordering decision |
| R.13, R.14 (R-3-client) | **R.13** | Carried; one `failureKind` added |
| R.16, R.17 | **R.14** | Amended — new step 0, a third endpoint, a revised error table |
| R.18 | **R.15** | Carried; **one new consequence** (§ R.15.3) |
| R-4 (reuse table) | **R.16** | Extended to 46 rows |
| R.19, R.19.1, R.19.2 | **R.10** | **Resolved** — option 1 |
| R.21, R.21.1–R.21.4, R.22 | **R.17, R.18** | Carried, amended; ADR supersession added as R.17 |
| 8 | **§ 8** | `SC-08` re-framed; `SC-11`–`SC-16` new |
| 9 | **§ 9** | Risk re-derived; self-assessment revised; feasibility lowered on the transport seam |
| 10 | **§ 10** | Replaced — Manager actions and the sibling-lane contract |

---

## R.1 — The at-rest protection model — **CLOSED**

### R.1.1 What was decided, and what that forecloses

`9417f8bf` **RESOLVED, OPTION_C**, `decided_at 2026-10-06T13:05:00Z` **[6220951]**:

> The human chose to SUPERSEDE ADR 0018 `:85-88`'s local-secret-store clause and adopt **A3, an external
> secret manager** — SHIP IT never holds key bytes, only a reference, and asks the manager for the
> material at push time.

Three of its consequences are binding on this revision, and I treat them as normative input rather than
as commentary:

1. **ADR 0018 `:85-88` is superseded** and must be amended by a follow-up, not silently ignored. § R.17
   states the amendment this design depends on; `docs/adr/**` is `PROHIBITED_PATHS` here and a sibling
   lane owns it.
2. **A2 is permanently excluded.** The ADR's *"never persisted to the durable record"* still binds it —
   the prohibition survives even though the custody sentence above it does not. See § R.1.6.
3. **A3 makes the reference the most sensitive artifact SHIP IT holds**, because an ARN or secret path
   discloses vault topology. `G-7` is therefore **REQUIRED**, not optional.

### R.1.2 The manager interface — normative

A new **`SecretProvider`** port lives in `apps/server/**` and its implementation in
`apps/server/lib/src/secret/**`. **It must not live in `packages/product_registry`** — `C-02`, and
`product_registry_engine.dart:899-905` **[77c19f1]**: *"This engine never generates or holds key
material … A private key must never reach this package."* The domain receives only a handle.

```dart
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
out, so it is stated as a choice with its alternative named, rather than buried.**

The decision's option text says *"`referenceName` is a secret path or ARN"*. Taken literally the durable
record would carry vault topology — and this repository's durable record is **readable by an off-host
caller with a password published in a committed file**: `docker/compose.yaml:63` hardcodes
`SERVERPOD_DATABASE_PASSWORD: shipit`, `docker/compose.yaml:16-17` publishes `"5432:5432"` unqualified
(Docker resolves that to `0.0.0.0`), and `.env.example:16-18` documents
`POSTGRES_USER=shipit / POSTGRES_PASSWORD=shipit` — all **[77c19f1]**, all unchanged at **[07c8c8f]**.

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

Step 4 is not a nicety: `git_workspace_inspector.dart:106-112` **[07c8c8f]** runs `Process.run(git,
args)` with **no `environment:`**, and a repository-wide grep for
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

A2 appears in this revision **once**, here, so that a reader holding Revision 2 knows it is *closed*
rather than *missing*. It is **not** presented as an option, it has no advantages listed, and the
`referenceName`-as-opaque-row-reference variant it implied is superseded anyway by § R.1.3.

---

## R.2 — What the existing domain constrains

Carried from Revision 2 § R.2. Constraints 1–3 hold; 1 and 3 are now **structurally** satisfied rather
than merely respected.

1. **The private half never enters `packages/product_registry`.** Under A3 this is stronger than a rule
   the implementation must honour: SHIP IT's own process **never holds the bytes** except in the
   transport's memory window (§ R.1.4 steps 3–4). `recordGeneratedCredential`'s existing refusal of a
   `publicKey` containing `PRIVATE KEY` (`engine:933-939` **[77c19f1]**) stays, and the
   `credential_test.dart` group *"no key material reaches the domain"* stays as the guard.
2. **`RepositoryCredential` never gains a key-material field.** Unchanged. Under A3 this is no longer
   even a temptation, because SHIP IT does not have the material to store.
3. **The private half is immutable per credential — in memory only; the persistence boundary is
   separately guarded.** `copyWith` (`repository_credential.dart:137-172` **[07c8c8f]**) takes exactly
   `status, lastVerifiedAt, lastVerifiedBy, lastFailureReason, hostKeyStatus, host, hostKeyFingerprint,
   hostConfirmedAt, hostConfirmedBy, revokedAt, revokedReason, version` — so it **cannot** change
   `credentialId`, `productId`, `repositoryId`, `referenceName`, `publicKey`, `fingerprint`, `algorithm`,
   `createdAt` or `supersedesCredentialId`. Revision 2's overstated version of this is still withdrawn;
   what holds at the persistence layer is `D-1`/`D-2` (landed, § R.8.1) and, as of this revision,
   `D-4`/`D-5` (**specified, not built**, § R.9).

### R.2.4 New constraint — the substrate is a runtime dependency

Carried from `7b1bc8b7`'s own reasoning: under A3, **the manager can be unavailable**, and the credential
flow depends on it at mint, at push and at revoke. Three consequences that bind the design:

- **It fails closed** (§ R.5), so an unavailable manager **blocks** the flow. Correct posture, and also a
  **denial-of-service surface on the credential path** — § R.15.3.
- **It is not local-only and it is not loopback**: a manager is by definition a network service, so the
  *"local only"* scope `570bb640` relies on has **no bearing whatsoever** on it. `570bb640`'s loopback
  pinning is still un-implemented (§ R.15.1) and A3 does not make it easier.
- **A3's reachability in this repository's target topology is `UNVERIFIED`** — `9417f8bf`'s own
  follow-up action assigns the probe to the implementer. § 9.4 keeps that honest, and the risk level in
  § 9.1 reflects it.

---

## R.3 — `referenceName`: the invariant, the settled subject, and G-7 as REQUIRED work

### R.3.1 The invariant — carried verbatim from Revision 2 § R.3.1

> **`referenceName` continues to name a reference. It never carries a value.** It does not hold key
> material, is not an obfuscation of key material, and must not be derived from it.

Unchanged. Under A3 this is no longer merely an invariant the design asserts — it is the **mechanism**,
and § R.1.3's opaque-handle form is chosen partly because it keeps this statement true under inspection.

Revision 2 marked three things `OPEN`: the field's **subject**, its **substrate**, and its **client
exposure**. Under `9417f8bf`: the **subject** is a secret manager (settled), the **substrate** is A3
(settled), the **client exposure** is **no** (settled — § R.3.2). **All three are closed. None is
re-opened here.**

### R.3.2 `G-7` — REQUIRED: `referenceName` leaves `RepositoryCredentialView`

**Required behaviour.** `RepositoryCredentialView` **loses the `referenceName` field and gains nothing
in its place.** Concretely:

| # | Change | Location **[07c8c8f]** | Kind |
|---|---|---|---|
| 1 | Delete `referenceName: String` from the Serverpod model source | `apps/server/lib/src/models/repository_credential_view.yaml:11` | **model source** (single source of truth) |
| 2 | Regenerate the server protocol | `apps/server/lib/src/generated/repository_credential_view.dart`, `protocol.dart`, `product_detail_view.dart` | generated — `serverpod generate` |
| 3 | Regenerate the client protocol | `packages/control_plane_client/lib/src/protocol/repository_credential_view.dart`, `protocol.dart`, `product_detail_view.dart` | generated |
| 4 | Drop the mapper assignment | `apps/server/lib/src/services/ui_view_mappers.dart:176` (mapper spans `:169-188`) | hand-written |
| 5 | Drop the field from the hand-written client DTO | `apps/control_plane/lib/data/control_plane_repository.dart:1691` (constructor param), `:1709` (field), and its doc comment at `:1708` (*"Name of the local secret-store entry. Never the value."*) | hand-written |
| 6 | Drop the two mapping sites | `control_plane_repository.dart:108`, `:1098` | hand-written |
| 7 | Rewrite the two display sites | `product_detail_page.dart:471` (technical-details line — `referenceName` is its **leading token**) and `:676` (repository-card meta line) | hand-written |

**This is the "generated-contract change in two packages" the decision refers to: `apps/server` (the
model source plus its generated protocol) and `packages/control_plane_client` (the generated protocol).**
Both are regenerations of one field deletion; neither is a redesign. All of the above are
`PROHIBITED_PATHS` for this lane — it writes none of them.

**What the client receives instead: nothing.** No substitute field is added. The client already holds
everything it legitimately needs, and `credentialId` is already the non-identifying handle it uses to
address the credential:

| Field already on the view | Why it is sufficient |
|---|---|
| `credentialId` | the handle every later action reuses — already an opaque server-generated id |
| `fingerprint`, `algorithm` | identifies *which* key is installed, which is what the operator needs |
| `status`, `hostKeyStatus`, `host` | the trust and lifecycle axes |
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
  existing client fixtures still use (`product_detail_mobile_golden_test.dart:33`,
  `widgets/product_detail_page_test.dart:18`, both `GIT_PRODUCT_SHIPIT_REPO1_SSH`). Under A3 the column's
  *value shape* has changed anyway (§ R.1.3), so any board still showing that token is showing a stale
  design **and** disclosing a naming scheme.
- **No board may name the secret manager** — not its vendor, not its address, not *"the vault"*, not
  *"the keychain"*. The copy says *a* secret manager exists and that the private half is not in SHIP IT.
- Removing the field from the view changes rendered output at `product_detail_page.dart:471` and `:676`,
  so the **`product_detail` golden baselines must be regenerated** by the implementation/QA lane. They
  are QA artifacts and are `PROHIBITED_PATHS` here. Flagged because it is an easily-missed consequence: a
  wire change that silently invalidates committed goldens surfaces as a *visual* regression, not a
  contract one.

---

## R.4 — The four-option substrate set is **WITHDRAWN**

Revision 2 § R.4 presented A1/A2/A3/A4 as options, with per-option ADR status and a confidence table.
That presentation existed only to let the human choose, and the choice is made. **This revision contains
no substrate option set, no `Q1`/`Q1′`, no confidence column, and no "if the human answers" branch.**

What replaces it, for anyone holding Revision 2 open:

| Revision 2 option | Revision 3 disposition |
|---|---|
| **A3** external secret manager | **THE DESIGN.** § R.1.1–R.1.4, normative. |
| **A1** filesystem `0600` | **Documented fallback** with an explicit trigger condition — § R.1.5. Reachable only when no manager is *configured*. |
| **A4** host keychain / TPM | **Documented fallback** with an explicit trigger condition — § R.1.5. Reachability `UNVERIFIED` on the target. |
| **A2** envelope-encrypted table | **Excluded, permanently** — § R.1.6. ADR 0018 `:87-88` still binds it. |

§ R.16 reuse row #31 changes from *"NEW, and `OPEN — HUMAN DECISION REQUIRED AT GATE D4`"* to *"NEW —
decided by `9417f8bf` OPTION_C"*, and row #35 changes from `CONDITIONAL — none proposed` to **`none
required`** (A3 stores a handle in an existing column, so no migration is needed for the substrate — worth
stating, because under the withdrawn A2 it would have needed one).

---

## R.5 — The degraded path: fail closed, with named remediation

**`7b1bc8b7` RESOLVED, OPTION_A.** If the substrate is unavailable or its protection cannot be verified,
**no keypair is generated and no credential row is created**, and the user is told the concrete operator
action. The decision states that the remediation copy *is* the deliverable that distinguishes this dead
end from human point 2d's rejected one. **It is therefore specified verbatim below, and it is a required
deliverable of this revision** (`SC-11`, and the successor to the brief's `AC-03`).

The decision also states the path is *materially more likely* under A3 than under a filesystem store.
This design treats it as an ordinary, frequently-exercised branch, not an edge case.

### R.5.1 The four trigger conditions — each distinguishable

| `substrateFailure` | Detected how | Distinct? |
|---|---|---|
| `secretManagerUnconfigured` | No manager endpoint configured in server configuration | yes — this is the **A1/A4 fallback** case (§ R.1.5), and its remediation is *"configure a manager"*, not *"fix the manager"* |
| `secretManagerUnreachable` | `verifyProtection` did not complete within the configured timeout | yes |
| `secretManagerProtectionUnverifiable` | The manager answered, but the reported protection does not meet `SecretProtectionPolicy`, **or the policy could not be evaluated** (missing capability, unsupported version) | yes — and note the *unevaluable* case is folded in deliberately: *"we could not check"* must not read as *"it is fine"* |
| `secretManagerWriteRefused` | `put` was refused by the manager (policy, quota, size) | yes — the manager's own reason goes to the audit log, never raw to the wire (§ R.5.3) |

### R.5.2 Where the refusal is evaluated — and the one ordering decision this revision makes

`7b1bc8b7` scopes the refusal to *"no keypair is generated and no credential row is created"*. Under
`898b07d0` the key flow's **first step creates the `Product` row and the `RepositoryReference`** (§ R.10).
Those two decisions interact, and the interaction is not spelled out in either object. I specify it, and
flag it for the reviewer and the Manager in § 10:

> **The substrate precondition is evaluated before the flow writes anything, so a substrate refusal
> creates no `Product` row, no `RepositoryReference` row, no credential row, and no keypair.**

**Rationale.** Step 1 under `898b07d0` exists for exactly one purpose: to make the mint satisfiable. If
the substrate is down, step 1 accomplishes nothing and produces precisely the consequence the human
accepted in `898b07d0` — a visible product with no usable credential — **without any of the benefit that
made that consequence acceptable**, because there is no key to come back to. Creating the product anyway
would also leave the user with a product row they did not ask for, created by a failure they did not
cause.

**The alternative reading** — create the product, then refuse the mint — is available and is not
forbidden by either decision's text. I rejected it because it produces the worse of both outcomes. This
is a **sequencing decision inside two binding decisions**, not a new product question: the user-visible
result is the same either way (an error with remediation, and no credential), so it is not a Level 2 UX
change. It is listed in § 10 for the human to confirm rather than treated as blocking.

**The mint sequence, in order, with the failure window made explicit:**

| Step | Action | Key material in existence? | On failure |
|---|---|---|---|
| 0 | `verifyProtection(policy)` — **before any write** | **no** | refuse; nothing written |
| 1 | derive `host` from `RepositoryReference.uri` | no | refuse (`repositoryUriUnparseable`); nothing written |
| 2 | create `Product` (`registered`) + `RepositoryReference` (§ R.10) | no | refuse; nothing written |
| 3 | generate the keypair **in memory** | **yes, in process memory only** | — |
| 4 | `put(privateHalf)` → handle | yes | **compensate**: zero the buffer; nothing was written, so there is nothing to destroy; refuse |
| 5 | `recordGeneratedCredential(..., referenceName: handle)` | yes, in memory | **compensate**: `destroy(handle)` in a `finally`, then refuse |
| 6 | return the public half to the client | no (only the public half) | — |

**Step 5's compensation is mandatory, and it is the reason the ordering matters.** Without it, a failure
between `put` and the row write leaves a live private half in the manager that **no row points at** — an
unmanaged key that no revocation can ever reach, which is the exact class of orphan `79e860e2` exists to
eliminate. Any implementation that cannot compensate must instead order `put` after the row write, and
**that order is forbidden**: it would put a row pointing at a handle that may not exist, so a later push
would fail in a way that looks like `secretReferenceMissing` rather than like a failed mint.

**On "no keypair is generated".** Steps 3→4 are the only window in which material exists, and it is
process memory that is zeroed and dropped on every failure path. A *literal* *"never generate a keypair"*
is not achievable and cannot have been what the decision meant — generating and then refusing to store
would itself create the unmanaged key the decision forbids. I record this interpretation explicitly so it
is reviewable rather than smuggled.

### R.5.3 The refusal, on the wire

| Property | Value |
|---|---|
| HTTP | **503** |
| Wire `failureKind` | `substrateUnavailable` (presentation-layer enum, § R.13.2 — the **domain** vocabulary is unchanged) |
| Body | `{ failureKind, remediation: { title, body, action, substrateFailure }, retryable: true }` |
| State written | **none**, at any tier — asserted by `SC-11` / `T-H` |
| Audit | one `AuditEntityType.productCredential` event recording the attempt, the `substrateFailure` kind, and **no** handle |
| Typed exception | `SecretSubstrateUnavailable(substrateFailure, remediationAction)` in `apps/server` — **not** in `packages/product_registry` (`C-02`) |

**Deliberately coarse.** One wire `failureKind` with four server-side discriminators, so an
unauthenticated caller (§ R.15) cannot use the endpoint as an **oracle** for whether a manager exists,
where it is, or how its policy is configured. The four discriminators are for **operators and logs**, not
for clients.

### R.5.4 The remediation copy — **required deliverable, specified verbatim**

Every string below is **`palette.inkSecondary`**, never `inkTertiary` (`N-8`, § R.10.1): `inkTertiary`
measures 4.23:1 on the card surface in dark and **fails WCAG AA**, and it is the current idiom for exactly
this kind of helper text (`add_product_page.dart:542`, `:590` **[77c19f1]**). Rendered on the card surface,
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
`packages/product_registry/lib/src/exceptions.dart` **[07c8c8f]**, all `implements Exception`, all with
typed fields and a `toString()`:

| Existing | Location **[07c8c8f]** | Shape | Why the new one is consistent |
|---|---|---|---|
| `CredentialNotFoundException` | `:201` | `(String credentialId)` | the substrate refusal is **not** this: nothing was created, so there is no id. It is a new type, and the distinction matters — *"not found"* is a **query** outcome, the substrate refusal is a **precondition** outcome. |
| `CredentialNotUsableException` | `:215` | `(String credentialId, String reason)` | already the catch-all the store raises for a refused credential write (`postgres_product_registry_store.dart:292`, `:341`). The substrate refusal is **not** this type either: it happens **before** a credential exists, so a `credentialId` argument would be a fiction. |
| `HostKeyNotConfirmedException` | `:232` | `(String host, HostKeyStatus status)` | the closest analogue, and the precedent that matters: `credential_status.dart:49-50` fails closed because *"an unrecognised host is indistinguishable from an interception"*. The substrate refusal uses the same reasoning — **an unverifiable store is indistinguishable from an unsafe one**. |
| `CrossProductAccessException` | `:59` | `(String message)` | not applicable. |

**Therefore the new refusal is a new type, `SecretSubstrateUnavailable`, and consistency requires four
specific things:**

1. **It fails closed**, exactly like `HostKeyNotConfirmedException` — no partial state, at any tier.
2. **It carries the remediation action as data**, so the client renders server-supplied copy rather than
   inventing its own. This mirrors how `HostKeyNotConfirmedException`'s two `status` values drive two
   distinct `toString()` messages (`exceptions.dart:238-246`) — **the cause is a field, not a subclass per
   cause**. One type, four discriminators.
3. **It does not enter `packages/product_registry`.** The four existing refusals live there because they
   are *domain* refusals; the substrate is outside the domain (`C-02`), and its exception belongs to
   `apps/server`. Surfacing it through the domain would put a secret-manager concern in a package whose
   stated contract is that it never sees one.
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
  (§ R.5.2), re-entry re-runs step 0 and re-mints from scratch with a **new** keypair. Because § R.9's
  `D-4` forbids re-minting an existing identity, a re-mint after a substrate failure is a genuinely new
  credential — correct, since the previous attempt produced no key at all.

---

## R.6 — Revocation is two-sided

**`79e860e2` RESOLVED, OPTION_A**: destroy the private half on revoke, keep the row. Under A3 *"destroy"*
means **deleting the manager handle**. **ADR 0018 `:113-114` is superseded** (§ R.17).

### R.6.1 Required behaviour, and its order — which is load-bearing

```
revokeCredential(productId, credentialId, reason)
  1. read the credential; _ensureOwned; if already revoked → return unchanged (idempotent)
  2. SecretProvider.destroy(referenceName)          ← FIRST
  3. copyWith(status: revoked, revokedAt, revokedReason, version+1)
  4. saveProductCredential(updated, expectedVersion: c.version)
```

**The manager handle is deleted before the row is marked revoked, and this ordering is normative.**

| Failure at | Result | Safe? |
|---|---|---|
| step 2 fails (manager unreachable / refuses) | the row is **not** marked revoked; the refusal surfaces with the § R.5.4 remediation | **yes** — marking the row revoked without destroying the material would assert a security property that does not hold. This is `7b1bc8b7`'s posture applied to revocation. |
| step 4 fails, after step 2 succeeded | a **live** row whose material is destroyed | **yes, and recoverable** — `destroy` is idempotent (§ R.1.2), so a retry re-issues it harmlessly and then marks the row. Until the retry the row over-claims usability; `canReachRepository` is false in fact and the failure is loud, not silent. |

The reverse order is the dangerous one and is **forbidden**: mark the row revoked first, and a failed
`destroy` leaves a **revoked row with a live private half** — a credential the operator believes is dead
and which still authenticates to the repository.

**Rotation is unaffected**, because `rotateCredential` revokes first and mints second (`engine:1116`,
`:1098` **[07c8c8f]**), so the old row leaves `D-2`'s partial unique index before the replacement enters
it. Under A3 rotation additionally means the old handle is destroyed before the new one is written, so a
rotation failure leaves no half-rotated credential.

### R.6.2 The row is retained — C-1 does not contradict the retention test

Revision 2 already noted this and it remains correct, now against the code at **[07c8c8f]**:

- `revokeCredential` (`:1072-1090`) is `readProductCredential` → `_ensureOwned` → early return if already
  revoked → `copyWith(status: revoked, revokedAt, revokedReason, version+1)` →
  `saveProductCredential(…, expectedVersion: c.version)`. **It never deletes the row.**
- `credential_test.dart:310` — *"revoked credentials stay readable, never deleted"* — asserts
  `readActiveCredential` returns `null` **and** `readCredentials` returns the row with `revokedReason`
  preserved.
- (Revision 2's anchor was `credential_test.dart:246` at **[77c19f1]**; the test moved to `:310` at
  **[07c8c8f]** by the store-integrity lane.)

**Destroying the private half does not contradict that test, because the test asserts the *record*, not
the *bytes*.** Under A3 this is cleaner still: SHIP IT never held the bytes to destroy, so there is
nothing for the record to disagree with.

### R.6.3 What revocation now **depends on** — and one of those dependencies is not built

`revokedAt`/`revokedReason` are only trustworthy if **no write can clear them**. Two facts, and the second
is a live defect:

- `"revokedAt" = @revokedAt, "revokedReason" = @revokedReason` are in `$assignments`
  (`postgres_product_registry_store.dart:237-238` **[07c8c8f]**) — i.e. they are in scope of the
  conflict-branch update.
- **The conflict branch can be reached for a revoked row**, and doing so clears them. This is finding
  **M-3** and its derived consequence **§ R.9.2** — including the fact that it produces a revoked
  credential resurrected into the active set whose **manager handle has already been destroyed** by
  § R.6.1.

So: **§ R.6's semantics are only actually delivered once `D-4` (§ R.9.1) is built.** Until then,
revocation is best-effort against a reachable public API. That is stated here because `79e860e2`'s
follow-up action tells the implementer to *"test that a revoked credential cannot reach the repository"* —
and **that test fails until `D-4` lands**, because the resurrection path leaves a `generated` row in the
active set.

---

## R.7 — Transport exposure — carried, with the threat model's A3 row added

Revision 2 § R.7 is carried **verbatim and in normative voice**. Normative constraints:

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

### R.7.1 Threat model — the A3 row

| Asset at risk | Reachable by | Today **[07c8c8f]** |
|---|---|---|
| The private half | **Only** the secret manager, plus the transport process for the duration of one attempt | A3 is the right answer to this row: SHIP IT holds none |
| **The handle** (an opaque secret identifier) | Anyone who reaches the **live database** with the **committed default credentials**; **every client**, until G-7 lands | `docker/compose.yaml:63`, `:16-17`; `.env.example:16-18` **[77c19f1]** — **unchanged**. § R.1.3 removes topology disclosure from the handle's value; it does **not** remove the database's exposure. |
| Host-key trust | Nothing enforces it — `HostKeyStatus.permitsConnection` has no runtime enforcer | `D-3`; **re-verified this pass**, § R.10.2 |
| The manager's reachability | Anything that can make it unreachable | **New under A3.** § R.15.3 |

**The load-bearing conclusion, restated for A3:** custody has moved off SHIP IT, but the *identifier* that
points at the material did not, and that identifier now sits in the least-protected component in this
topology. A3 is still the right answer — it removes the bytes from every path that can read the database —
but it does not make the database safe, and a design that implied otherwise would be misleading. G-7
(§ R.3.2) removes the second half of the exposure.

---

## R.8 — The store invariant is real. What now rests on it.

`fix/credential-store-integrity` is implemented at **`07c8c8f`** (`BASE_SHA 064703d`), `RESULT:
IMPLEMENTED`, `READY_FOR_INDEPENDENT_REVIEW: YES`, and `4d2c6b81` resolved **OPTION_A** so the index
reaches deployed databases. **Nothing is committed** (`HEAD_SHA == BASE_SHA` on that branch). Revision 2
proposed this work; this revision treats it as a **dependency that exists**.

### R.8.1 What landed — verified by reading it, not by running it

**`D-1` — key-material immutability, in the statement, on both branches.**
`postgres_product_registry_store.dart` **[07c8c8f]**:

- **CAS branch `:251-262`** — the `UPDATE` carries `AND "publicKey" = @publicKey AND "fingerprint" =
  @fingerprint AND "algorithm" = @algorithm AND "referenceName" = @referenceName` alongside the version
  CAS. `:265-303` reads the row back to distinguish *re-pointed key material* from *lost race*, so the
  caller is told **which** invariant it broke.
- **Upsert branch `:322-331`** — `INSERT … ON CONFLICT ("credentialId") DO UPDATE SET $assignments WHERE
  <the same four predicates> RETURNING "credentialId"`. `:306-310` states why `RETURNING` is the
  detection mechanism: a filtered-out row returns nothing, and an empty result is unmissable.
- `:332-347` translates SQLSTATE `23505` **and** the constraint name
  `product_credential_active_repository_unique` (`:201-202`) into a typed refusal.

**`D-2` — one active credential per repository, in both homes.** The partial unique index
`ON "product_credential" ("repositoryId") WHERE "status" <> 'revoked'` is in **both**
`apps/server/tool/schema_bootstrap.sql` (the fresh-database path) **and** the new migration
**`apps/server/migrations/20261006150645000/migration.sql`** (the chain-replayed / deployed path), with
`index:product_credential_active_repository_unique` in `verify_schema_bootstrap.sh` `required_objects` so
the guard is no longer blind to it. That last half is `4d2c6b81`'s subject and it is done.

**Its predicate is identical to the predicate that defines "active" in the read path** —
`readActiveCredentialForRepository` selects `WHERE "repositoryId" = @repositoryId AND "status" <>
'revoked'` (`postgres_product_registry_store.dart:370-381` **[07c8c8f]**). So the constraint and the
query **cannot contradict**, which was the justification in Revision 2 § R.15b.2 and it still holds.

### R.8.2 B6's structural kill — honestly, in three mechanism classes

| Class | Mechanism | Status **[07c8c8f]** | What it actually buys |
|---|---|---|---|
| **A — persistence** | `D-1`: material immutability in the statement, both branches | **REAL** | A write that changes `publicKey`/`fingerprint`/`algorithm`/`referenceName` on an existing `credentialId` updates **nothing**. |
| **A — persistence** | `D-2`: partial unique index on the active set, two homes | **REAL** | Two concurrent mints cannot both insert. The loser gets `23505` + the index name, translated to a typed refusal. |
| **B — application** | Endpoint get-or-create; **no caller-supplied `credentialId`** | **NOT YET WRITTEN** — a property of code that does not exist | Removes the *accidental* re-mint from the UI. A caller that skips it is still protected by class A. |
| **B — application** | The engine's one-active guard (`engine:954-960`) | Holds, **conditionally** | A refusal of a second **row**, keyed on `supersedesCredentialId`. Not an immutability guard. |
| **C — in-memory only** | `copyWith` cannot change the four immutable fields | True, and **still worth nothing at the boundary** | Zero protection on the statement that persists the row. |

**Honest status of `R-B6`** (*"each press silently rotates the key the user just installed"*):

- **The original defect is closed at the persistence layer.** Any write that changes the key material of
  an existing `credentialId` now changes nothing. Any mint that creates a *new* `credentialId` for a
  repository that already has an active credential now hits `D-2`.
- **It is closed conditionally on one application requirement**: that the mint endpoint passes **no
  caller-supplied `credentialId`** (`credentialId` is a caller parameter at `engine:934`;
  `store:226-240` carries it into `$cols`). That is a design obligation, not code, which is why § R.14.1
  step 6 keeps it normative.
- **The family of state-loss defects around it is NOT closed.** `D-1`'s predicate is *satisfied by
  identical values*, so an identical-material re-mint still upserts and still resets state — § R.9.1. And
  `repositoryId` is still rewritable — § R.9.3. `D-1` named four fields; the **set** of things a mint
  must not touch is larger, and this revision specifies it.

Revision 2's sentence — *"two mechanisms, not four, and not independent"* — is **restated, not
withdrawn**: two of its four were properties of unbuilt code, and the two that mattered were not
independent of the boundary. The count that is now true is **two persistence mechanisms, both real, plus
one application requirement** — and the state-loss family is open.

### R.8.3 What now rests on the invariant — itemised, so a reviewer can check each

| Requirement | Rests on | Why it holds / what breaks if it does not |
|---|---|---|
| `SC-02`, `SC-03`, `T-A`, `T-B` | `D-1`, `D-2` | `T-A`/`T-B` exist and pass per the implementer's report at `07c8c8f`. **Not re-verified by this lane — no test was run.** |
| § R.14.1 step 7 — concurrent mints resolve on **D-2's** unique violation | `D-2` | Revision 2 rewrote this off the engine's one-active exception **because that exception would not fire**. It still would not. The `23505`-plus-index-name translation (`store:332-347`) is what makes it resolvable. |
| § R.12 — *"the key is still the same key"* | `D-1` | The restored key is byte-identical only because the material cannot have changed. |
| § R.14.1 step 6 — mint passes no caller-supplied `credentialId` | application requirement, **not** `D-1` | Stated as normative precisely because `D-1` alone does not remove the route. |
| `rotateCredential`'s revoke-then-mint ordering | `D-2` | The old row must leave the active set before the new one enters it, or the index refuses the rotation (`engine:1116`, `:1098` **[07c8c8f]**). |
| **§ R.6 revocation's two-sidedness** | **`D-4` — not built** | § R.6.3. `revokedAt`/`revokedReason` are clearable today. |
| § R.10's `N-7` (host confirmation is durable) | **`D-4` — not built** | An identical-material re-mint nulls `hostConfirmedAt`/`hostConfirmedBy` (§ R.9.1). |
| `G-9` — ADR 0018 A1's one-per-repository invariant | `D-2` — **CLOSED** | Was `OPEN` in Revision 2. It is a database invariant now, in both homes. |

**One operational precondition, carried forward verbatim from the implementer's own disclosure and not
smoothed:** the **duplicate-credential audit must be run by a human against every deployed database before
migration `20261006150645000` is applied**, because `CREATE UNIQUE INDEX` fails on duplicates. The audit
query **as originally dispatched does not execute** — `"repositoryId"` is quoted camelCase, and unquoted
it folds to `repositoryid` and **errors**, which reads exactly like *"no duplicates"*. The migration
embeds the corrected form. Zero duplicates were found in every database reachable to that lane, but the
only credential-bearing one held **0 rows**, which is a vacuous *"no"*. This is a **deployment
precondition owned by a human**, not a design item; § 10 carries it.

---

## R.9 — Two confirmed security defects, specified as requirements

The engineering review confirmed both are real and reachable through the **public domain API today**, and
both are **outside `D-1`'s literal scope** because `D-1` named four fields. `D-1` named what it was asked
to name; § R.9 states the set a mint must not touch. Both are credential invariants, so they are specified
with the same rigour as `D-1`.

### R.9.1 `M-3` — identical-material re-mint is still permitted → required behaviour **`D-4`**

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

passes the guard at `engine:954-960`, reaches `saveProductCredential` with no `expectedVersion`
(`engine:979`), and takes the upsert branch — where `$assignments` (`store:226-240`) writes **every**
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

**`D-4` — the mint path never upserts.** Required behaviour:

> On the conflict branch, an `ON CONFLICT ("credentialId")` that matches an **existing** row must
> **update nothing**. The mint path is an **insert-only** path.

**Why this is safe, verified rather than asserted** — the single most important structural fact in this
section. Every call site of `saveProductCredential` at **[07c8c8f]**, in the engine:

| Call site | `expectedVersion`? | Branch |
|---|---|---|
| `engine:979` — `recordGeneratedCredential` (the mint) | **none** | **upsert** |
| `engine:1011` — `confirmHostKey` | `c.version` | CAS |
| `engine:1025` — `confirmHostKey` | `c.version` | CAS |
| `engine:1066` — `recordCredentialCheck` | `c.version` | CAS |
| `engine:1088` — `revokeCredential` | `c.version` | CAS |

**The upsert branch is reached only by the mint path.** `revokeCredential`, `confirmHostKey` and
`recordCredentialCheck` all go through `copyWith` + CAS, so `D-4` cannot break any of them.
`rotateCredential` reaches the upsert branch only by minting a **new** `credentialId`, which is what it
already does (`engine:1098`; `credential_test.dart:520` — *"rotation is the only way to change the key,
and it mints a new id"*).

**Required shape.** `DO NOTHING` + `RETURNING "credentialId"`; an empty result is a typed
`CredentialIdentityConflictException(credentialId)`. `DO NOTHING` is the correct construct here, **not**
`DO UPDATE … WHERE <always false>`: the latter is still an update, and it would keep the predicate's
shape alive as an accidental second source of truth. **And on the CAS branch, `D-4` extends to the
mutable set too** — a CAS write must not be able to clear `hostConfirmedAt`, `lastVerifiedAt` or
`revokedAt` either, which `copyWith`'s inability to unset them (`repository_credential.dart:137-172`
**[07c8c8f]**) already prevents in memory. The statement is where that becomes true against any other
connection.

### R.9.2 The derived consequence: a revoked credential can be resurrected — **new in this revision**

I did not find this in the engineering review; it follows from reading `$assignments` against
`readActiveCredentialForRepository`, and it is **worse under `79e860e2`** than it was before.

**The path**, entirely through the public domain API:

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

1. `readRepositoryReference` + `_ensureOwned` → pass.
2. `publicKey` non-empty, no `PRIVATE KEY` → pass.
3. `readActiveCredentialForRepository('repo-1')` → **`null`**, because the revoked row is excluded by
   `status <> 'revoked'` (`store:370-381` **[07c8c8f]**). So the one-active guard at `engine:954-960`
   **does not throw** — there is no *active* credential to conflict with.
4. A fresh `RepositoryCredential` is constructed with `status: generated`, `revokedAt: null`,
   `revokedReason: null` (`engine:963-978`).
5. The upsert branch's predicate is satisfied, so the row is updated; `RETURNING` yields a row; the call
   **succeeds**.

**Result.** A credential the operator revoked is **back in the active set as `generated`**, with
`revokedAt`/`revokedReason` **erased** — and under § R.6.1 its **manager handle has already been
destroyed**. The row therefore claims a shape that says *"a deploy key exists"* while the key exists
nowhere. It also now occupies the active set for `repo-1`, so **`D-2`'s partial unique index refuses the
legitimate fresh mint** for that repository with *"already has an active credential"*. Recovery is
`rotateCredential` (revoke-then-mint), so it is recoverable — but the state in between is corrupted and
the audit trail is falsified.

**No existing test covers this.** `credential_test.dart:323` — *"a revoked credential cannot be
re-checked into life"* — closes the **check** path (`recordCredentialCheck` refuses a revoked
credential). It does **not** close the **mint** path. Read at **[07c8c8f]**; the test is real and its
scope is exactly what it says.

**Required behaviour** is `D-4`'s, and `D-4` delivers it: a mint may never write to an existing
`credentialId`, so `revokedAt`/`revokedReason` are unreachable from the mint path. Stated separately
because it is the **consequence** a reviewer should test first: **`T-D`**.

### R.9.3 `M-4` — `repositoryId` remains rewritable → required behaviour **`D-5`**

**The defect.** `"repositoryId" = @repositoryId` is in `$assignments` (`store:228` **[07c8c8f]**) and is
**not** in `D-1`'s predicate (`store:325-328`). So a conflicting write can move an existing credential to
a different repository. `copyWith` cannot do it (`repository_credential.dart:137-172`); the route is the
same caller-supplied-`credentialId` mint as `M-3`.

**What it produces, precisely.** An installed deploy key is silently re-pointed between two repositories
**of the same product**, with **no rotation record** — `supersedesCredentialId` is untouched, so the
rotation chain does not show it. `_ensureOwned` (`engine:1784-1790`) blocks crossing products, so the
blast radius is **one product's repositories**.

**Two consequences beyond the scope violation itself**, and the second is the one that matters:

1. **The host confirmation travels with it.** `hostKeyStatus`, `hostConfirmedAt`, `hostConfirmedBy` and
   `hostKeyFingerprint` are **not** in `D-1`'s predicate either, and the caller supplies fresh values — so
   re-pointing carries a human's confirmation of **repo-1's host** across to **repo-2's host**. That
   contradicts **ADR 0018 `:96-99`** directly: the operator *"is shown the host, key type and fingerprint
   and must confirm it"*, and a host whose key was never shown to anybody has been marked confirmed.
2. **It defeats the scope control the ADR relies on.** ADR 0018 A1 `:19-21` keeps `productId` *"retained
   for ownership checks only"*, and `repository_credential.dart:62-65` states `productId`'s purpose as
   *"scope enforcement so that knowing a credential id does not bypass the ownership graph"*. A rewritable
   `repositoryId` means a known `credentialId` **is** a way to change which repository a key authorises.

**`D-5` — the scope set is immutable too.** Required behaviour:

> `productId` and `repositoryId` are **immutable on an existing `credentialId`**, on **both** branches —
> in the statement, not in a read before it.

**Why this cannot break rotation:** `rotateCredential` mints a **new** `credentialId` for the **same**
`repositoryId` (`engine:1098`; `credential_test.dart:520`). No legitimate path changes either field on an
existing identity, so predicating on them refuses only illegitimate writes. This also closes the
implementer's pre-existing follow-up #5 (*"`productId`/`repositoryId` on the conflict branch, unchanged by
this work"*) as part of the same requirement, rather than leaving it dangling.

### R.9.4 The set, stated once

`D-1` named four fields because four fields were asked for. The complete statement of what a mint must not
touch:

| Set | Fields | Status |
|---|---|---|
| **Material** | `publicKey`, `fingerprint`, `algorithm`, `referenceName` | `D-1` — **landed** |
| **Scope** | `productId`, `repositoryId` | `D-5` — **specified here, not built** |
| **Identity of the record** | `credentialId` (the conflict key), `createdAt`, `supersedesCredentialId` | `D-4` — **specified here, not built** |
| **Everything mutable** | `status`, `hostKeyStatus`, `hostConfirmedAt/By`, `hostKeyFingerprint`, `lastVerifiedAt/By`, `lastFailureReason`, `revokedAt`, `revokedReason`, `version` | `D-4` — **the mint may not write any of them onto an existing row** |

### R.9.5 Tests — `T-C` … `T-G`, and what they assert

None of these was run by this lane. `T-A`/`T-B` **are** run and passing at `07c8c8f` per the
implementer's report; I did not re-run them and make no claim beyond that.

| ID | Test | Asserts | Status |
|---|---|---|---|
| **`T-C`** | Identical-material re-mint is refused and the row is untouched | `recordGeneratedCredential(credentialId: <existing>, supersedesCredentialId: <existing>, referenceName/publicKey/fingerprint/algorithm: <identical>)` **throws**; afterwards **every** column of the row is byte-identical to before — `status`, `hostKeyStatus`, `hostConfirmedAt`, `hostConfirmedBy`, `hostKeyFingerprint`, `lastVerifiedAt`, `lastVerifiedBy`, `lastFailureReason`, `createdAt`, `revokedAt`, `revokedReason`, `version` | **FAILS today** — upserts (§ R.9.1) |
| **`T-D`** | A revoked credential cannot be resurrected by a re-mint | `recordGeneratedCredential` on a revoked row's `credentialId` with identical material **throws**; the row stays `status: revoked` with `revokedAt`/`revokedReason` intact; `readActiveCredentialForRepository` still returns `null`; and a **fresh mint for that repository then succeeds** | **FAILS today** — the index refuses the legitimate mint because the row has been resurrected (§ R.9.2) |
| **`T-E`** | A different-material re-mint is still refused | `D-1`'s existing `T-A` behaviour is **unchanged** by `D-4` — i.e. `D-4` does not regress `D-1` | passes today; **regression guard for `D-4`** |
| **`T-F`** | `repositoryId` is immutable on an existing row | Re-pointing to another repository of the **same** product throws on the upsert branch; `repositoryId` unchanged; `hostKeyStatus`/`hostConfirmedAt` unchanged | **FAILS today** (§ R.9.3) |
| **`T-G`** | `productId` is immutable on an existing row | As `T-F`, for `productId` | **FAILS today** |

`T-C`, `T-F` and `T-G` belong in `packages/product_registry/test/credential_test.dart` beside the existing
group *"key material is chosen once, at mint"* (`credential_test.dart:342` **[07c8c8f]**) — which is the
right home, because `D-4`/`D-5` turn that group's claim into the complete one. `T-D` needs the
Postgres-backed tier, because its second half asserts the index's behaviour (`make test-integration`,
disposable Postgres, self-cleaning per `AGENTS.md` § Test resource hygiene). **Not run by this lane.**

**`T-H` is the seventh, and it is not a store test**, so it is defined here rather than left to § 8 where
`SC-11` uses it: given an unavailable / unconfigured / unverifiable / write-refused `SecretProvider`, a mint
attempt throws `SecretSubstrateUnavailable` carrying the right `substrateFailure`, **and a count of
`product_credential`, `product` and `repository_reference` rows is unchanged from before the attempt** — the
whole point of § R.5.2, and the only test that distinguishes *"fail closed"* from *"fail closed after
creating a product"*. It needs a fake `SecretProvider` rather than a database, but it does need the real
engine, because § R.5.2's ordering lives across the endpoint, the service layer and the engine together.
**Not run by this lane.**

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
`readRepositoryReference` + `_ensureOwned` (`engine:938-939` **[07c8c8f]**), so a credential cannot exist
before the `Product` and `RepositoryReference` do — and those are what registration creates. The fix is
that **the key flow creates them**, and registration stops being their creator.

```dart
createProduct(productId, …)            engine:43   → state: ProductState.registered  (engine:54)
addRepositoryReference(productId, …)   engine:150  → requires the product to exist
recordGeneratedCredential(…)          engine:926  → readRepositoryReference + _ensureOwned
                                                ⇒ requires the repository AND product  ← SATISFIED by step 2
confirmHostKey(…)                      engine:988
recordCredentialCheck(…)               engine:1034
```

There is still **no pre-registration `ProductState`**, and none is introduced: `createProduct` hardcodes
`registered`, and `registered` is already defined as *"Registered in the registry. No baseline, no
governance, no work … a product is visible here before anything about it has been approved"*
(`product_state.dart:24-27`, `registered` at `:28`). **The human's resolution uses that existing
semantics rather than inventing a new state**, which is why it needs no schema or contract change.

### R.10.1 The state machine — one new step, then the existing trust machine unchanged

Steps 0–2 are new; everything from step 3 onward is Revision 1 § R.9's machine, carried unchanged.

```
  step 0  SecretProvider.verifyProtection(...)          ← NEW (§ R.5.2). refuses, writes nothing.
    │
  step 1  derive host from RepositoryReference.uri      ← carried (§ R.14.1 step 3)
    │        no host → refuse; writes nothing
    │
  step 2  ★ CREATE Product (state: registered)          ← NEW (898b07d0)
    │      ★ CREATE RepositoryReference
    │        ══ the rows now exist. FROM HERE THE PRODUCT IS VISIBLE.
    │           leaving at any later state leaves a visible product (the accepted consequence)
    │
  step 3  mint: generate keypair → put to manager → recordGeneratedCredential
    │        failures here are compensated (§ R.5.2 step 5)
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

### R.10.2 `N-1`–`N-8` — carried forward unchanged, with `N-9` added

`design-revision.md:309-343` (`N-1`…`N-7`) and `design-revision.md:504-524` (`N-8`) are carried **without
change**, including `N-1`'s normative no-Cancel rule with its rationale and its cost, and `N-6`'s
`changed` path with no *"trust anyway"*. The reviewer praised these and none of the six resolutions
touches them.

`N-8` is now **also binding on § R.5.4's remediation copy** — the largest body of new user-facing text
this revision adds.

#### `N-9` — new: copy must describe custody truthfully, and name no substrate

> **`N-9` — Copy says where the key was generated, says the private half is not in SHIP IT, and names no
> substrate.** No *"on this device"*, no *"the keychain"*, no *"the vault"*, no manager name or address.

**Why this is normative and not a style note.** The current line at `add_product_page.dart:542`
**[77c19f1]** reads *"ed25519 · created on this device · the private half stays in the keychain"*. Both
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

### R.10.3 `D-3` still holds, and it is an **ADR gap**, not only a missing feature — **re-verified**

**Verified this pass at `07c8c8f`:**

```bash
grep -rn "SSH_AUTH_SOCK|known_hosts|ssh-keyscan|StrictHostKeyChecking|IdentityFile" apps packages
# → 0 matches

# packages/worker_runtime/lib/src/workspace/git_workspace_inspector.dart:106-112
Future<String> _capture(List<String> args) async {
  final result = await Process.run(git, args);      # no environment:
```

`HostKeyStatus.permitsConnection` has **no runtime enforcer**. *"ShipIt refuses to connect to an
unrecognised host"* is decorative today. **D-3 still holds.**

**This is an ADR gap, and that is the correct classification.** ADR 0018 `:96-99` is a **requirement** in
a recorded, read, cited ADR: *"ShipIt refuses to connect to an unrecognised host … ShipIt does not claim to
have verified a host it cannot verify."* The code does not implement it. A design may note that work is
missing; it may not treat an ADR requirement as an optional feature. `G-4` stays open **with ADR status
attached**, and the seam is sized accordingly in § 9.2.

**And under A3 the seam is larger, not smaller.** It must now do two new things at once:

| Capability | Why it is new | Where it is homed |
|---|---|---|
| Host-key TOFU verification with fingerprint presentation and out-of-band confirmation | already missing — `D-3` | ADR 0018 `:96-99`; ADR 0015 `:55-59` (`EnvironmentPolicy`) |
| Resolving material from a secret manager at push time, into an ephemeral identity outside the work tree, zeroed afterwards | new under A3 | ADR 0018 `:67` (the injectable seam the ADR anticipated); § R.1.4 |

**Two security-critical capabilities in one seam, one of which has no precedent anywhere in the
repository.** § 9.2 lowers feasibility accordingly, and § 10 asks that the seam get **its own** review
rather than riding in as a side effect of this feature.

---

## R.11 — Client state model — carried, plus the sibling-lane consumption contract

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

### R.11.1 One derived fact the UI must be able to tell apart

`898b07d0`'s accepted consequence — **a visible product may exist with no usable credential** — is a
third derived fact, and **the UI must distinguish it**. It is not a variant of an existing axis; it is
their combination:

> **`RegistrationCommitState` = `committed` ⟺ some credential on this product has `canReachRepository ==
> true`.** When `notCommitted`, the product **exists**, is listed on the Products page, and has a repository
> reference — and none of that means it is usable.

**The five client-observable states that must be visually distinct.** This is the normative list; a
reviewer can check each against a board:

| # | `RegistrationCommitState` | Credential | Host trust | What the user must be able to tell |
|---|---|---|---|---|
| 1 | `notCommitted` | **none** | — | *"no key generated yet"* — matches today's copy at `product_detail_page.dart:676` |
| 2 | `notCommitted` | `generated` | `unknown` | **the Unknown-host state**: a product that exists, is waiting on *you*, and has no escape control on the card (`N-1`) |
| 3 | `notCommitted` | `generated` / `failing` | `confirmed` | access not yet proven — install the key, *or* the network is at fault (§ R.13.2) |
| 4 | `notCommitted` | `revoked` | any | **this key was withdrawn; a new one must be generated and re-installed** — not *"try again"* |
| 5 | `committed` | `verified` | `confirmed` | access proven, with `lastVerifiedAt` shown as a fact (ADR 0018 `:100-102`) |

State 4 is the one that is easy to omit and the one the old model **cannot express**: `AccessStatus` has
no `revoked` member, so a revoked credential currently renders as one of the five existing values.

### R.11g Consumption contract for `design-addproduct-mobile` — binding, from `898b07d0`

The sibling lane owns the boards (`C-11`). **This lane authors and edits none of them.** Its
follow-up action — *"Re-ground the mobile boards' Unknown-host state on the split — the product row now
exists before trust"* — couples the two revisions, so this revision states what the boards must show, so
the sibling can consume it rather than infer it.

1. **The Unknown-host state depicts a product that already exists.** The `Product` row (state
   `registered`) and the `RepositoryReference` exist **before** the trust decision is taken — § R.10.1
   step 2. **No board may depict *"nothing is saved yet"* at that state.**
2. **Leaving at Unknown-host leaves a visible product.** That is the accepted consequence, and the boards
   must not imply the flow is discardable.
3. **Therefore the Add Product flow must be re-enterable from the product, not only from the Products
   page's "Add product" control.** Without this, the accepted consequence becomes a **dead end** — the
   exact failure human point 2d objected to, arriving by a different route. This is a **requirement on
   the sibling lane's design**, not an observation: `ProductDetailPage` needs a resume affordance into the
   credential flow. Listed in § 10 as a Manager notification, because the sibling lane's revision must
   carry it.
4. **The custody line is the string in § R.10.2**, and the board's `Art S` text is to be reconciled to it.
5. **No board may render a credential reference** (§ R.3.4).
6. **The footer follows `27ea6536` verbatim**, per the human's correction after checking the boards
   directly. **Desktop** (`S - Add Product - Unknown host`, `S - Add Product - Verified`) = a divider and a
   **right-aligned** `Show technical details` **text button**, **no footer copy**. **Mobile** (`BPM - Add
   Product`) = a **left-aligned** `Show technical details` button with **no divider**, **no footer copy**.
   The human's instruction — *"Stay true to both designs in Penpot and in code"* — governs, and **the
   boards are authoritative over both lanes' readings**. For implementation context: `_buildFooter`
   (`add_product_page.dart:375`, called from the desktop branch at `:314`, with its copy at `:383`) is
   desktop-only and is the source of both the copy and the duplicated `ContentRule`; `_MobileAddProduct`
   (`:774`) renders no footer copy and its `TechnicalDetails` (`:925`) has no `note:`.
   **This revision changes none of it** — it records the specification so both lanes reconcile to one of
   them.

---

## R.12 — The read path — carried, and no longer conditional

`design-revision.md:374-396`'s table is carried verbatim, with one line changed and one paragraph deleted.

Revision 2 recorded: *"**This row depends on OPEN-D4-2.** If the `Product`/`RepositoryReference` rows
exist when the user leaves (option 1) the read path above is exact. If they do not, the credential cannot
exist at all today."* **`898b07d0` chose option 1. The dependency is discharged.** The table is now exact
as written, with no conditional.

**Why the human's addendum is now literally true.** `898b07d0`: *"if down the road we want to create that
product we'll find the key ready to be verified again."* Under § R.10 the rows are created at step 2 and
the credential at step 3, so on re-entry:

```
Add Product re-entry
  → Product row exists (state registered)           ← step 2 already ran
  → RepositoryReference exists                      ← step 2 already ran
  → readActiveCredentialForRepository(repositoryId) → credential row exists; status and host state preserved
  → restore publicKey  (a pure READ of product_credential.publicKey — never regenerated)
  → restore fingerprint, hostKeyStatus, hostConfirmedAt/By
  → user re-enters at the trust step or the check step
```

| Claim | Field | Read path |
|---|---|---|
| The credential survives navigation | `product_credential.credentialId` | `readActiveCredentialForRepository(repositoryId)`; revoked rows excluded (`store:370-381` **[07c8c8f]**), so a revoked credential correctly does **not** come back — that is state 4 of § R.11.1 |
| *"The key is still there"* | `product_credential.publicKey` | re-copy is a pure **read**; it never regenerates |
| The key is still the same key | `product_credential.fingerprint` | **`D-1` makes this true at the store** (§ R.8.3) — the restored key is byte-identical *because the material cannot have changed* |
| Host trust survives too | `hostKeyStatus`, `hostKeyFingerprint`, `hostConfirmedAt`, `hostConfirmedBy` | **Conditional on `D-4`** — an identical-material re-mint nulls them today (§ R.8.3, § R.9.1) |
| The user is not blocked | `ProductState.registered` semantics | `product_state.dart:24-27`: *"Registering is deliberately not governing: a product is visible here before anything about it has been approved"* — which is exactly the semantics option 1 relies on |

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
check control from minting.

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

---

## R.14 — The endpoints

Placed on the existing `ProductRegistryEndpoints`, which states *"an endpoint never sets state directly"*.

### R.14.1 `mintOrReadDeployKey` — Revision 2 § R.16, amended

```dart
Future<DeployPublicKeyView> mintOrReadDeployKey(Session session, {
  required String productId,      // the product the flow is registering
  required String name,           // product name — step 2 creates the Product
  required String repositoryUri,  // step 2 creates the RepositoryReference
})
```

**The step-2 creation of `Product` + `RepositoryReference` moves into this endpoint**, because it must be
atomic with the mint to satisfy § R.5.2: if the substrate is down, nothing is written at all.

1. **`SecretProvider.verifyProtection(policy)`** — **step 0.** Refuses with § R.5.3's 503 and writes
   nothing. *This step did not exist in Revision 2.*
2. `readActiveCredential(productId, repositoryId)`. **If a credential exists → return it with
   `alreadyExisted: true`. Never generate.**
3. Derive `host` from the URI; if none can be derived → refuse (`repositoryUriUnparseable`), write nothing.
4. **Create the `Product` row (`ProductState.registered`) and the `RepositoryReference`** if absent —
   `createProduct` (`engine:43`) and `addRepositoryReference` (`engine:150`), both idempotent by
   read-then-write. *New.*
5. Generate the keypair in memory; `put` the private half → handle; **inside a `try`, with
   `destroy(handle)` in the `finally` on any failure** (§ R.5.2 step 5).
6. `recordGeneratedCredential(…)` — **passing no caller-supplied `credentialId`** (normative; § R.8.2).
7. **Concurrency** — on a `23505` violation **of `product_credential_active_repository_unique`** (not on
   the engine's one-active exception, which will not fire): re-read the active credential for the
   repository and return **its** public half with `alreadyExisted: true`. A concurrency resolution, not
   an error.
8. **`CredentialIdentityConflictException` (`D-4`) is a defect, not a concurrency outcome.** It must
   propagate. Converting it into `alreadyExisted: true` would turn a broken invariant into a plausible
   answer.
9. **`CredentialNotUsableException` from `D-1`/`D-5` is also a defect** and must propagate.

`DeployPublicKeyView` is **unchanged from Revision 2** — nine fields, **no field capable of carrying
private key material**, and now also **no field carrying the handle**. `SC-09` makes it testable.

**Revised error table:**

| Case | Response | State written |
|---|---|---|
| Unknown product / repository, or cross-product access | `CredentialNotFoundException` / scope error → 4xx | none |
| Host not derivable | 400 `repositoryUriUnparseable` | none |
| **Substrate unavailable / unverifiable / refused** | **503 `substrateUnavailable` + the § R.5.4 remediation for the named cause** | **none, at any tier** |
| Concurrent mint (`D-2` unique violation) | 200, winner's credential, `alreadyExisted: true` | one row |
| Immutability violation (`D-1`, `D-5`) | 500 typed — **a defect** | unchanged |
| Identity conflict (`D-4`) | 500 typed — **a defect** | unchanged |
| `publicKey` containing `PRIVATE KEY` | `CredentialNotUsableException` (`engine:946-951`) | none |

### R.14.2 `checkRepositoryAccess` — carried from Revision 2 § R.17, with the manager in the path

Reads by id; **contains no generation step**. Refuses when `!hostKeyStatus.permitsConnection` (`N-3`),
resolves the handle from the manager (§ R.1.4), performs the transport attempt, calls
`recordCredentialCheck`, returns `{ credentialId, status, hostKeyStatus, lastVerifiedAt, lastVerifiedBy,
failureKind?, failureReason? }` per § R.13.2.

**New failure surface.** A `resolve` failure is `secretReferenceMissing` (a `failureKind`, so the client
shows § R.13.2's copy) or a substrate refusal (a 503 with § R.5.4's copy — **the same remediation**,
because the operator action is identical). The check path **must not** invent a third remediation
vocabulary for a substrate problem: one copy, two callers.

### R.14.3 `revokeRepositoryCredential` — **NEW endpoint**, required by `79e860e2`

```dart
Future<CredentialStatusView> revokeRepositoryCredential(Session session, {
  required String productId, required String credentialId, required String reason,
})
```

`revokeCredential` already exists in the engine; what is new is that it must now do **two** things
(§ R.6.1), and that ordering is normative. Errors: `CredentialNotFoundException`; substrate refusal → 503
with § R.5.4's copy and **the row left unchanged**; already revoked → 200 with the row, idempotent.

**Why a new endpoint rather than a flag on an existing one.** No existing endpoint exposes a credential
view at all (`grep -c RepositoryCredentialView apps/server/lib/src/endpoints/*.dart` → **0** across all
11 files **[77c19f1]**), so there is nothing to extend. The endpoint exists because revocation now has a
ShipIt-side effect that must be auditable and must not be reachable by a path that skips it.

---

## R.15 — Exposure of a credential-minting endpoint — carried, with one new consequence

Revision 2 § R.18 is carried **in full**, including its four points and its refusal to pretend that
endpoint hardening mitigates a committed database password. **Nothing in it is softened, and the numbers
were re-verified this pass.**

### R.15.1 What is still true (re-verified at **[07c8c8f]** / **[77c19f1]**)

- `apps/server/lib/server.dart:71-72` declares **no authentication services** for the control plane.
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
denied mint cannot be used to destroy an existing credential.

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
- **`R-H2`'s promise narrows.** The Products page stays reachable and no partial state is created
  (§ R.5.2), so the user is not *stuck*; but *"we'll find the key ready to be verified again"* now also
  requires the manager to have been reachable **when the key was minted**. That is a **real narrowing of
  the addendum's promise**, and it is a consequence of A3 plus fail-closed, not a defect in either.
- **Mitigations that do not pretend to be authentication:** every substrate failure is audited (§ R.5.3)
  with its `substrateFailure` kind, so a denial campaign is visible as a rate of `secretManagerUnreachable`
  refusals; and the remediation names the endpoint tried **in the audit log only**, never on the wire
  (§ R.5.3).

---

## R.16 — Reuse table

Revision 2's 39 rows are carried. Rows **#31** and **#35** change; **#40**–**#46** are new.

| # | Design element | Maps onto | New? |
|---|---|---|---|
| 1–30, 32–34, 36–39 | *(as Revision 2 § R-4)* | *(as Revision 2)* | — |
| **31** | **The private-half store** | `SecretProvider` + `apps/server/lib/src/secret/**` | **NEW — decided.** `9417f8bf` **OPTION_C: an external secret manager.** A3. ADR 0018 `:85-88` superseded by the human |
| **32** | Keypair generation | `apps/server/**` | **NEW** — a real SSH implementation replaces `_generateMockKeyPair` (`add_product_page.dart:113`, `:126`) |
| **33** | SSH host-key verification | — | **NEW, and mandated** — no such code exists; ADR 0018 `:96-99`; re-verified `UNVERIFIED` (§ R.10.3) |
| **34** | Credential injection into the transport | — | **NEW** — `git_workspace_inspector.dart:106-112` passes no `environment:` |
| **35** | Migration for the private half | — | **`none required`** (was `CONDITIONAL`). A3 stores an opaque handle in the **existing** `referenceName` column: no new table, no new column, no migration |
| 36 | `D-1` store-level material immutability | `saveProductCredential` | **DONE** at `07c8c8f` (`store:251-262`, `:322-331`) |
| 37 | `D-2` partial unique index on the active set | bootstrap **+** migration `20261006150645000` | **DONE** at `07c8c8f`, in **both** homes per `4d2c6b81` |
| 38 | Typed immutability error | `exceptions.dart:201,215,232` | **naming follow-up only** — the behaviour is typed `CredentialNotUsableException` (`store:292`, `:341`), not `CredentialImmutabilityViolationException`. The behaviour is what `D-1` required |
| 39 | Active-credential read path | `store:370-381` | — its predicate is what fixes `D-2`'s index predicate |
| **40** | **Opaque credential binding** (`credbind_<32 hex>`) | server configuration + `SecretProvider` | **NEW** — § R.1.3. Replaces the literal ARN/path form |
| **41** | **Substrate precondition + compensation** | § R.5.2 steps 0 and 5 | **NEW** — `verifyProtection` before any write; `destroy(handle)` in a `finally` |
| **42** | **`SecretSubstrateUnavailable`** | `apps/server` (not `product_registry`, `C-02`) | **NEW** — § R.5.5's four consistency obligations |
| **43** | **Revocation endpoint** | `ProductRegistryEndpoints` (new method) | **NEW** — § R.14.3; required because revocation now has a ShipIt-side effect |
| **44** | **`D-4` mint is insert-only** | `saveProductCredential` conflict branch | **NEW behaviour, existing function** — § R.9.1 |
| **45** | **`D-5` scope immutability** | the same statement, both branches | **NEW behaviour, existing function** — § R.9.3 |
| **46** | **`RegistrationCommitState`** (client) | `ProductDetailView.credentials` + `canReachRepository` | **NEW, client-derived** — § R.11.1; no new server field |

**No parallel credential abstraction is introduced.** #40–#46 are substrate, integrity and presentation
concerns; the credential *model* is entirely the existing one.

---

## R.17 — ADR 0018: what this design depends on, and what it supersedes

`docs/adr/**` is `PROHIBITED_PATHS` for this lane. **A sibling lane is drafting the amendment.** This
section is the dependency contract that amendment must satisfy.

| ADR 0018 clause | Status | What this design does with it |
|---|---|---|
| `:84-88` — per-repository `ed25519`; private half to the **local secret store**; *"never … persisted to the durable record"* | **⚠ `:85-88` SUPERSEDED** by `9417f8bf` — the custody substrate is now an **external secret manager** | § R.1. **But the prohibition survives:** `:87-88`'s *"never persisted to the durable record"* still **excludes A2** permanently (§ R.1.6). The amendment must therefore replace the **custody sentence** and **keep the prohibition sentence** |
| `:92-95` — *"Referenced by name, never by value"*; the record stores a credential **reference** + fingerprint, never key material | **UPHELD, and now load-bearing** | § R.1.3's opaque handle *is* this rule; § R.3.1's invariant is this rule. A3 is the first substrate that satisfies it **unconditionally**, independent of topology |
| `:96-99` — TOFU with explicit human confirmation; *"ShipIt refuses to connect to an unrecognised host"*; *"does not claim to have verified a host it cannot verify"* | **UPHELD — and it is a REQUIREMENT with no implementation** | § R.10 (`N-1`–`N-9`), § R.10.3 (`D-3` re-verified), § R.5.4's *"we could not check ≠ it is fine"*. **This is the ADR gap `G-4` records.** `N-4` and § R.5.4's copy both exist to honour `:99` |
| `:100-102` — *"A product cannot be registered until a connectivity check has succeeded against the real host with the real key"* | **✅ UPHELD — and now satisfiable** | `898b07d0` resolved the cycle **in favour of** this clause. § R.10 makes the ordering real: the credential is minted **before** the registration act completes. **This clause is not contradicted and must not be amended** |
| `:103-104` — rotation is per repository, re-install required | UPHELD | § R.6.1; `rotateCredential` unchanged |
| `:113-114` — *"Revocation is provider-native … requires no Shipit-side action"* | **⚠ SUPERSEDED** by `79e860e2` | § R.6. **Because A3 makes SHIP IT a participant in custody**, a ShipIt-side action — deleting the manager handle — is now required, and provider-side removal alone no longer releases material SHIP IT can reach |
| `:15-30` (A1) — one keypair **per repository**; `productId` retained for ownership checks only | UPHELD | § R.16 row 46; `D-2` now enforces it in the database (§ R.8.1); `D-5` now makes the retained `productId` non-rewritable (§ R.9.3) |
| `:29-30` — reference-name shape `GIT_PRODUCT_<productRef>_<repoRef>_SSH` | **⚠ SUPERSEDED IN SHAPE** by § R.1.3 | The handle is `credbind_<32 hex>`, with no product or repository information. The clause's **shape** is superseded; its **rule** (§ `:92-95`) is upheld. Any board or fixture still using the old shape is stale (§ R.3.4) |
| `:79-80`, `:126-127`, `:140-141` — the deliberate scoped deviation from `AGENTS.md §13`, its Negative, and the §13 carve-out that was **never applied** | **GAP `G-1′`, unchanged and still open** | `AGENTS.md` has no `§13`/`§13b`. `AGENTS.md` is outside `OWNED_PATHS`; escalated, **not edited** |

---

## R.18 — Traceability and gaps

### R.18.1 Gaps this revision **closes**

| Gap | Closed by |
|---|---|
| `OPEN-D4-1` (all four sub-questions) | `9417f8bf`, `7b1bc8b7`, `79e860e2` — § R.1, R.5, R.6 |
| `OPEN-D4-2` (registration ordering) | `898b07d0` OPTION_A — § R.10 |
| `G-7` (`referenceName` to clients) — was *"a gap, owner named"* | **Now REQUIRED work**, specified: § R.3.2 with a 7-row blast radius, plus § R.3.3 and § R.3.4 |
| `G-9` (one-per-repository not a DB constraint) | `D-2` **landed** at `07c8c8f` in **both** homes — § R.8.1 |
| Revision 2's `SC-08` (*"decided by the human at Gate D4"*) | Decided. `SC-08a` replaces it (§ 8) |

### R.18.2 Gaps that remain **open**

| # | Gap | Why it is a gap | Owner |
|---|---|---|---|
| `G-4` | **No SSH host-key verification exists anywhere.** `HostKeyStatus` has no runtime enforcer; `git_workspace_inspector.dart:106-112` runs `Process.run` with no `environment:`; grep for the five host-key tokens returns **0**. **ADR 0018 `:96-99` makes this a requirement** | **An ADR gap, not only a missing feature.** A design may note missing work; it may not treat an ADR requirement as optional | Implementation (architecture) — § 10 asks that it get **its own** review |
| `G-3` | Zero test files import `add_product_page.dart` (`DEC-73097d48`), so `SC-02`/`SC-04`/`SC-06` have no existing harness | test infrastructure | Implementation / QA Contract |
| `G-5` | No read-only endpoint for a product's public key | a client holding only a `credentialId` cannot re-read | Implementation |
| `G-6` | `recordGeneratedCredential`'s `host` is optional and defaults to `null`; the design refuses to mint without one but the domain does not enforce it | design/domain mismatch | Implementation |
| `G-8` | Host-fingerprint provenance unspecified (`ssh-keyscan` vs handshake) | `N-4`'s copy says *"the fingerprint the server actually observed"*; **how** is part of the new seam | Implementation |
| **`G-10`** | **A3's reachability in the target topology is `UNVERIFIED`.** No secret manager exists in this repository, no probe was run, and this lane issued no Docker command | `9417f8bf`'s own follow-up action assigns the probe to the **implementer**; the decision records `confidence: LOW` and states that no option was runtime-verified | **Implementer, before completion** |
| **`G-11`** | **`D-4`/`D-5` are specified, not built.** `R-B6`'s state-loss family, § R.6's revocation semantics and `N-7`'s durability all rest on them (§ R.8.3) | the design names a required invariant that does not exist yet. Stated, not smoothed | **Implementer** — `fix-credential-store-integrity` scope, or a new item |
| `G-1′` | **`AGENTS.md` has no `§13`/`§13b`**, so ADR 0018 `:140-141`, ADR 0012 `:34` and ADR 0019 `:121` all point at text that does not exist; `Product-specific policy` is `TBD` at `:59-63` | a documented mitigation of the governing ADR was never applied | **Manager / human** — `AGENTS.md` is outside `OWNED_PATHS`; **reported, not edited** |
| `L-6` | **`DECISIONS.md`'s index table (`:8-12`) omits `570bb640`**, which appears only in the closing prose | an index that omits a RESOLVED risk-acceptance decision understates what has been accepted | **Manager** — **reported, not edited** |
| — | **A false claim survives in a Manager-owned file:** `docs/engineering/dispatch/LANES.md:204-205` still asserts that *"ADR 0018 and `AGENTS.md §13a` do not exist"*. `WORK_STATE.md` was retracted; `LANES.md` was not | a ledger that still denies the governing ADR exists is worse than no ledger entry, because it reads as verified | **Manager** — **reported, not edited** (§ 10.1 item 6) |

**Out of scope for this lane, by design** (not gaps): the Penpot boards and the mobile/desktop footer
layout itself (`C-11`). § R.11g states what the boards must show so the sibling lane can consume it
rather than re-derive it; **no board is authored and none is edited here.**

---

## 8 — Success criteria changes

Revision 1's `SC-01`–`SC-10` stand except where noted. `SC-08` is re-framed and `SC-11`–`SC-16` are new.

| ID | Change |
|---|---|
| `SC-02` | **Extended twice.** Rev 2 added `T-A`. Rev 3 adds **`T-C`** — an identical-material re-mint must throw and **every** column must be byte-identical afterwards (not only the four immutable ones). **Fails today** (§ R.9.1). |
| `SC-03` | **Extended.** Rev 2 added `T-B`, now passing at `07c8c8f` per the implementer's report (**not re-verified by this lane**). Rev 3 adds **`T-D`** — a revoked credential must not be resurrectable by a re-mint, and a fresh mint for that repository must then succeed. **Fails today** (§ R.9.2). |
| `SC-06` | **Extended twice.** Rev 2 bound all new copy to `palette.inkSecondary` (`N-8`). Rev 3 adds: (a) `N-9`'s custody truthfulness and the exact string at § R.10.2; (b) `27ea6536`'s footer — **no footer copy on either platform**, and the per-platform structure as specified by the human. |
| **`SC-08a`** | **Replaces `SC-08`.** `SC-08` (*"the at-rest model is decided by the human at Gate D4"*) is satisfied: `9417f8bf` is RESOLVED OPTION_C. **`SC-08a`**: the frozen contract carries **A3** normatively, and **re-presenting the substrate as an open choice is itself a defect** — the human reserved and then made that decision. |
| **`SC-11`** | **NEW — fail-closed path.** A substrate refusal creates **no keypair, no credential row, no `Product` row and no `RepositoryReference` row**; it returns 503 `substrateUnavailable`; and it surfaces the remediation named for its cause. `T-H`: all four `substrateFailure` causes are distinguishable server-side, and no row exists at any tier afterwards. |
| **`SC-12`** | **NEW — G-7.** `RepositoryCredentialView` carries **no** reference, **no substitute field is added**, and no client surface or board renders a reference-shaped token. A test asserts the field's absence from the regenerated protocol in **both** packages. |
| **`SC-13`** | **NEW — two-sided revocation.** Revoke deletes the manager handle **and** marks the row revoked, with the row retained; a revoked credential cannot reach the repository; its history stays readable (`credential_test.dart:310`); and a manager `destroy` failure leaves the row unchanged. **Depends on `D-4`** (§ R.6.3). |
| **`SC-14`** | **NEW — split identity.** The flow creates the `Product` (state `registered`) and the `RepositoryReference` before minting; re-entry finds the key ready to verify without regenerating; and the UI distinguishes all five states of § R.11.1. |
| **`SC-15`** | **NEW — never-upsert.** `T-C`, `T-D`, `T-E`. |
| **`SC-16`** | **NEW — scope immutability.** `T-F`, `T-G`. |

---

## 9 — Self-assessment

### 9.1 Risk level: **3** — re-derived, not inherited

Revision 2's 3 was **agreed** by the independent reviewer (`INDEPENDENT_RISK_LEVEL: 3`,
`RISK_LEVEL_AGREEMENT: YES`). I re-derive it because its reasons have partly changed and partly not, and
because `DESIGN_GOVERNANCE.md` Invariant 6 makes the classification mandatory **for every** revision.

**What has improved:**

| Revision 2's reason for 3 | Status now |
|---|---|
| *"A design whose outcome may contradict an existing ADR is not a component-level change"* (ADR 0018 `:85-88` in tension with `b869ec24`) | **The tension is resolved by the human.** The design no longer carries an unresolved contradiction with a live ADR. It now carries a **known, human-owned, pending amendment** (§ R.17) — a tracked dependency rather than an open question. Different character, similar magnitude: code that ships before the amendment lands would contradict a live ADR, which is arguably worse than not knowing. |
| Two live Gate D4 decisions gating the design | **Zero.** Every reserved decision is resolved. |

**What has not improved, or has got worse:**

| Reason | Why it still holds, or now more strongly |
|---|---|
| **1. First handling of key material** | Still holds, and it is still irreversible: a leaked key authorising **write** access to a customer repository cannot be recalled from SHIP IT's side — it must be uninstalled at the host. No such secret exists today. |
| **2. The credential is exposed through an unauthenticated, unpinned control plane** | **Worse.** Under A3 the endpoint is not the only exposure; there is now a **runtime dependency whose unavailability blocks the credential path** (§ R.15.3), so the failure mode is *disclosure* **and** *denial*. `server.dart:71-72` still declares no authentication; `D-7` still stands; the database is still on `0.0.0.0:5432` with a committed default password. |
| **3. Change to the core registration workflow** | **Stronger.** Under `898b07d0` the change is no longer only *"registration is gated"*; it is **identity semantics** — a product becomes visible *before* registration commits, and an accepted consequence is a visible product with no usable credential. That changes what a `Product` means across the Products page, product detail and Add Product, which is closer to information architecture than to a gate. |
| **4. Two new credential invariants reachable today** | **Split, and the open half is worse than Revision 2's.** `R-B6`'s original defect is closed by `D-1`/`D-2` (§ R.8.2). But two new defects are live and reachable through the public domain API: an identical-material re-mint **erases a human's host confirmation and the revocation record**, and `repositoryId` is **rewritable**, so an installed key is silently re-pointed and carries a host confirmation to a host nobody confirmed (§ R.9). A workflow whose central invariants are not enforced is not a workflow-level change of the safe kind. |
| **5. An SSH transport seam with no precedent** | **Worse.** § R.10.3: the seam must now do host-key TOFU verification **and** manager-backed material resolution, both security-critical, one of which has no precedent anywhere in the repository — and ADR 0018 `:96-99` makes the first a **requirement**, not a feature. |

**Conclusion: `RISK_LEVEL: 3`** (Major Workflow / Navigation / IA Change), re-derived on this evidence. One
reason improved, two are unchanged, three are worse, and one of the two improved and one of the worse
concern the *same* subject (the substrate decision), which is precisely why the net does not move.

**What the level means here.** Per `DESIGN_GOVERNANCE.md`, Level 3 requires **product/design/architecture
human approval** at Gate D4. The six decisions have already been taken through that gate. **The *content*
of this revision still requires human approval** — specifically the three new requirements (`D-4`, `D-5`,
`SC-11`/`SC-12`/`SC-13`/`SC-14`), the `N-9` copy, and the § R.5.2 ordering interpretation. And the ADR
0018 amendment is a **blocking predecessor for implementation**, owned by the human (§ 10).

### 9.2 `design_system_compliance: PARTIAL` · `ux_accessibility_score: PARTIAL` · `implementation_feasibility: MEDIUM`

**`design_system_compliance: PARTIAL`** — unchanged, for the same reason as Revision 2: the boards are the
sibling lane's (`C-11`), so board compliance is `UNVERIFIED` by this lane. What this revision adds is
**token-level and copy-level**, and it is normative: `N-8` binds § R.5.4's remediation copy (the largest
new body of user-facing text), `N-9` fixes the custody line, and § R.11g item 6 fixes the footer.
`product_detail_page.dart:471` and `:676` must lose their leading `referenceName` token, which changes
rendered output and therefore **invalidates committed `product_detail` goldens** (§ R.3.4).

**`ux_accessibility_score: PARTIAL`** — unchanged. The contrast figures are **inherited, not re-measured**
(`design-register-button/report.md:71-76`: `inkTertiary` = 4.23:1 dark, which **fails WCAG AA**;
`inkSecondary` = 6.74:1 light / 6.10:1 dark, both passing). No contrast tool was run by this lane. `N-8`'s
binding of the new remediation copy makes the token requirement load-bearing rather than advisory, which
raises confidence in the *tokens* and changes nothing about the *boards*, which remain unverified here.

**`implementation_feasibility: MEDIUM`** — the revision-level rating is unchanged, but **the composition
underneath it moved in opposite directions**, and saying only "MEDIUM" would hide that:

| Component | Feasibility | Why |
|---|---|---|
| **Domain half** — split identity, credential lifecycle, `D-4`/`D-5` | **HIGH** | The engine methods exist; `createProduct` (`engine:43`) and `addRepositoryReference` (`engine:150`) already do exactly what § R.10.1 step 2 needs. `D-4`/`D-5` are predicated statements on an existing function plus five tests. 142 credential tests green at `07c8c8f`. |
| **Store half** — `D-4`, `D-5` | **HIGH** | One statement, both branches; and the call-site table (§ R.9.1) proves the change cannot break `confirmHostKey`, `recordCredentialCheck` or `revokeCredential`. |
| **G-7 wire change** | **HIGH** | One field deleted from one model source; two regenerations; six hand-written edits. Boring, and it invalidates goldens. |
| **Substrate integration** — `SecretProvider`, `verifyProtection`, opaque handles, compensation | **MEDIUM** | No precedent in this repository; reachability `UNVERIFIED` (`G-10`); and the "unevaluable policy" case requires care to get right rather than treat as pass. |
| **SSH transport seam** | **LOW** | Nothing exists. It must now deliver **two** security-critical capabilities (§ R.10.3), and one of them — host-key TOFU verification — is an ADR **requirement** with no implementation and no precedent. |

`MEDIUM` at the revision level because the high-feasibility work is most of the change and the
low-feasibility work is a named, homed, separately-reviewable seam. **It would be dishonest to raise the
number because the substrate decision is settled**: settling *which* store to use does not make the
transport that fetches from it any less new, and it enlarges that seam.

### 9.3 Gates and commands — nothing was run

| Command / check | Status | Note |
|---|---|---|
| `dart analyze` / `flutter analyze` | **NOT_RUN** | Implementation-lane gate; no claim is made about its output |
| Build | **NOT_RUN** | — |
| `dart test packages/product_registry/test` | **NOT_RUN** | I make **no** claim about the state of `D-4`/`D-5` beyond what § R.9's reasoning shows |
| `make test-integration` | **NOT_RUN** | The only sanctioned exemption from the Docker rule; I did not need it and did not use it. `T-B`/`T-D` need it |
| **Any Docker or Compose command** | **NOT_RUN — none issued** | `AGENTS.md` now carries the read-only-over-shared-Docker rule, which binds this lane. I ran no `docker`, no `docker compose`, not even `ps`, `config` or `logs`. Compose files were read **as text** |
| Contrast-ratio measurement (`N-8`) | **NOT_RUN** | Ratios inherited from `design-register-button/report.md:71-76` and independently re-measured by the Gate D3 review. Not re-measured here |
| `T-A` / `T-B` execution | **NOT_RUN** | They are reported as passing **by the implementer's report at `07c8c8f`**. I did not re-run them and I make no claim of my own |
| Penpot boards | **NOT_RUN / not authored** | Prohibited for this lane (`C-11`) |
| Read-only source inspection | **pass** | Every `file:line` in this revision was opened and read — at **[07c8c8f]** for the store, engine, credential tests and migration; at **[77c19f1]** for ADR 0018, the control plane, compose files and the client page; at **[6220951]** for the six decision objects |
| Commit / push | **NOT_RUN** | `COMMITTED: NO`, as instructed |

### 9.4 `UNVERIFIED` — with the command a human should run

| Claim | Status | What a human should run |
|---|---|---|
| **A3 is reachable in this repository's target topology** | `UNVERIFIED` — **`G-10`**, and the decision's own follow-up action | Provision the manager and run `verifyProtection` against it from the server container. Until this, the design's substrate rests on a decision whose reachability no one has tested |
| A real SSH transport accepts the generated public key | `UNVERIFIED` | Start a stack with an explicit `-p`, install the returned `publicKey` into a scratch repo's `authorized_keys`, run a real check |
| Host-key `changed` detection against a host presenting a different key | `UNVERIFIED` | Requires such a host |
| `secretReferenceMissing` is reachable and surfaces correctly | `UNVERIFIED` | Delete a manager object out of band and run a check |
| `D-2`'s index collapses concurrent mints | **`UNVERIFIED by me`**; reported green at `07c8c8f` | `T-B` against the Postgres-backed store |
| `D-1`'s predicate behaves as specified on this driver | **`UNVERIFIED by me`**; reported green at `07c8c8f` | `T-A` against the Postgres-backed store |
| `D-4`/`D-5` behave as specified | `UNVERIFIED` — **specified here, not built** | `T-C`…`T-G` |
| Loopback pinning un-implemented | **VERIFIED (negative)** | `grep -rn "127.0.0.1:" docker apps/server/docker-compose.yaml` → no match |
| Host-key verification absent | **VERIFIED (negative)** | grep for the five host-key tokens across `apps`/`packages` → 0 matches |

---

## 10 — Readiness

**Ready for Independent Design Review of Revision 3. Not approved by its author.** Revision 2's approval
does not carry over: it certified Revision 2's content, and this is different content.

**Gate D4 status.** The human's six decisions are taken. **Revision 3's own content requires human
approval** at its risk level, and the ADR 0018 amendment (§ R.17) is a **blocking predecessor for
implementation**.

### 10.1 Manager actions this revision requests — all outside `OWNED_PATHS`, none performed by me

1. **Re-base this revision.** `HEAD_SHA 77c19f1` does not contain the resolutions (`674b871`) or the
   store-integrity work (`07c8c8f`) — verified not ancestors (§ 0.4). A reviewer cannot verify this
   revision from this worktree alone. **Re-dispatch on a branch whose base contains both** (§ 10.2).
2. **Have the ADR 0018 amendment written**, per § R.17: replace `:85-88`'s custody sentence with the
   external-secret-manager substrate while **keeping** `:87-88`'s *"never persisted to the durable record"*
   prohibition; supersede `:113-114`; **uphold `:100-102`** untouched; and supersede `:29-30`'s
   reference-name *shape*. **Owner: the human, as ADR owner.** Blocking for implementation.
3. **Confirm or correct § R.5.2's ordering interpretation** — a substrate refusal writes *nothing at all*,
   including no `Product` row. This is the one point where `7b1bc8b7` and `898b07d0` interact and neither
   object spells it out (§ R.5.2). I chose the reading that does not produce the accepted-bad-state
   without its benefit. It is a sequencing decision, not a product question, so I did not block on it —
   but the human should see it.
4. **Dispatch `D-4`/`D-5`** (`G-11`) — two new live credential invariants, reachable today through the
   public domain API, one of which erases a human's host confirmation and the other's re-points an
   installed key between repositories. They fit `fix/credential-store-integrity`'s scope and should
   **merge ahead of this feature**: `T-D` blocks `79e860e2`'s own follow-up test.
5. **Notify `design-addproduct-mobile`** of the § R.11g consumption contract — six items, of which **item
   3** (the flow must be re-enterable from the product, or the accepted consequence becomes the dead end
   human point 2d rejected) is a **requirement on the sibling lane's design**, not an observation.
6. **Retract the false ledger facts**: `docs/engineering/dispatch/LANES.md:204-205` still asserts that ADR
   0018 and `AGENTS.md §13a` do not exist. `WORK_STATE.md` was retracted; `LANES.md` was not. **Manager-
   owned — reported, not edited.**
7. **Add `570bb640` to `DECISIONS.md`'s index table** (`L-6`), and record `AGENTS.md §13`/`§13b` (`G-1′`) as
   a governance action. **Manager-owned — reported, not edited.**
8. **Discharge the deployment precondition**: the duplicate-credential audit must be run **by a human**
   against every deployed database before migration `20261006150645000` is applied (§ R.8.3). No QA,
   staging or production database is reachable from a lane.

### 10.2 What a reviewer should check hardest

Stated so the review is aimed rather than open-ended:

1. **§ R.1.3** — the opaque-handle choice. This is the one place I chose something inside a resolved
   decision. Check the rejection of the literal-ARN form against the decision's own text, and check that
   the handle form does not weaken `:92-95`.
2. **§ R.9.2** — the revocation-resurrection path. It is a finding this lane derived, not one it was
   handed, and it is the sharpest thing here. Try to break it.
3. **§ R.9.1's call-site table** — it is the entire safety argument for `D-4`. If any
   `saveProductCredential` call site outside the mint reaches the upsert branch, `D-4`'s shape is wrong.
4. **§ R.5.2's step-5 compensation** — check that the failure window is genuinely closed, and that no
   implementation ordering makes `put` the last durable effect.
5. **§ R.6.1's ordering** — destroy-before-mark, and the claim that a row-write failure is the safe
   direction.
6. **§ 0.4's provenance split** — verify the three-revision labelling is complete and that no citation is
   silently at the wrong SHA.

---

*End of Design Revision 3. `REVISION_ID 4B017787-25A0-4F45-ABDA-805C250AF63F` · `RISK_LEVEL 3` ·
`design_system_compliance PARTIAL` · `ux_accessibility_score PARTIAL` · `implementation_feasibility MEDIUM`
· `COMMITTED: NO` · not approved by its author.*
