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

> ## ⚠ SUPERSEDED BY REVISION 3 — `4B017787-25A0-4F45-ABDA-805C250AF63F`
>
> **This document is retained intact as the Gate D3-reviewed artifact. Its content below is NOT edited
> and must not be implemented.** It is superseded because it was written against **unresolved** Gate D4
> decisions, and the human resolved all six on `2026-10-06T13:05:00Z` (`674b871`).
>
> **Its approval does not carry over.** `RESULT: DESIGN_REVIEW_APPROVED` (`REVIEWED_HEAD 77c19f1`,
> content anchor `3a87e27`) certified **this** content. Per `LEARNING_POLICY.md`, an approval of a design
> carrying open decisions certifies **the framing, not the design** — the reviewer's value was bounded by
> what was open at review time. See revision 3 § 0.2, and `D-15` in `discoveries.md`.
>
> **What is withdrawn from this document, in normative text:**
>
> - **§ R.4's four-option substrate set (A1–A4), the `Q1`/`Q1′` framing, the per-option confidence table
>   and the `A2` option itself.** `9417f8bf` RESOLVED **OPTION_C**: **A3, an external secret manager**.
>   A1/A4 are the **documented fallback** with an explicit trigger; **A2 is permanently excluded** because
>   ADR 0018 `:87-88`'s *"never persisted to the durable record"* survives the supersession of `:85-88`.
> - **§ R.5's `Q2` open marker.** `7b1bc8b7` RESOLVED **OPTION_A** — fail closed, with the remediation copy
>   as a required deliverable.
> - **§ R.6's `Q3′` open marker and the C-1/C-2/C-3 menu.** `79e860e2` RESOLVED **OPTION_A** — C-1.
> - **§ R.4.1's `Q4` open marker.** ANSWERED **no** — `G-7` is now **REQUIRED** work.
> - **§ R.19/§ R.19.2's three-option menu and the `OPEN-D4-2` marker.** `898b07d0` RESOLVED **OPTION_A**.
>   The § R.19.1 *ADR contradiction* framing is **withdrawn**: ADR 0018 `:100-102` is **upheld**, not
>   contradicted.
> - **§ R.15b's "proposed only" framing for `D-1`/`D-2`.** Both **landed** at `07c8c8f`, independently
>   reviewed. `T-A`/`T-B` are reported green by the implementer; **revision 3 did not re-run them.**
> - **`G-9`** (ADR 0018 A1's one-per-repository invariant not a DB constraint) — **CLOSED**.
>
> **What remains valid in this document** and is carried forward by revision 3: § R.9's state machine,
> `N-1`–`N-8`, § R.11's two axes, § R.12's read-path table (whose `OPEN-D4-2` condition is now discharged),
> § R.13/R.14, § R.18's four exposure points, § R.21, § R.22, and § R.15.3's *"two mechanisms, not four,
> and not independent"* — which revision 3 **restates** rather than withdraws, with two persistence
> mechanisms now **real** plus one application requirement.
>
> **Superseded a SECOND time by Revision 4** (`F2D5AF31-CA53-481A-ACB4-C75DB033A15A`,
> `design-revision-4.md`), which corrects **Revision 3** (`4B017787-…`) — a document that was **never
> approved**: its Gate D3 review returned `RESULT: DESIGN_REVIEW_CHANGES_REQUIRED` with **4 BLOCKERS,
> 7 HIGH, 2 MEDIUM and 4 LOW** (`tasks/review-addproduct-keys-rev3/report.md`). **No approval has ever stood
> behind Revision 3, so none is displaced here.** Revision 4's base is `361256c`, which contains every
> commit this chain depends on.
>
> **Not superseded, and still load-bearing:** `D-3` (no runtime enforcer for `HostKeyStatus`) and `D-7`
> (loopback pinning un-implemented). Both re-verified by revision 3 at `07c8c8f`.
>
> ⚠ **`D-3` IS NOW PARTLY CORRECTED, and this is the one place a reader of Revision 2 will read a
> superseded claim as current.** *"No runtime enforcer for `HostKeyStatus`"* is **over-broad**: the
> **domain** enforces it (`product_registry_engine.dart:1047-1052`, `:1162-1167`, `:1003-1015`;
> `repository_credential.dart:128-129`) and the **transport** is what has none
> (`git_workspace_inspector.dart:106-112`, no `environment:`; five host-key tokens grep to **0** matches).
> ADR 0018 `:96-99` is **half-implemented**, and `G-4` is scoped to the transport half. See Revision 4
> § R.10.3 and `discoveries.md` **D-23**. **`D-7` is confirmed still true** at `361256c` and unchanged.
>
> Successor: **`design-revision-4.md`** (`F2D5AF31-CA53-481A-ACB4-C75DB033A15A`), `RISK_LEVEL 3`
> (re-derived), `BASE_SHA`/`HEAD_SHA` `361256c`, `COMMITTED: NO`. **Supersedes `design-revision-3.md`**
> (`4B017787-…`, `RISK_LEVEL 3`, retained intact and never approved).

# Design Revision 2 — server-side deploy-key service + `hostUnrecognised` trust state

**Revision ID**: `F21D5C64-006D-4203-A813-841E08E38B95`
**Brief ID**: `97484D0E-E16C-485E-BAA2-A277889C0FB6` · **Brief version**: `1.1.0` (see § 0.3)
**Revision number**: 2 · **Status**: DRAFT · **Risk level**: 3
**Supersedes**: `46980EE0-E638-409C-A7D3-E1B9399FECE5` (Revision 1), which is **retained intact** at
`design-revision.md` as the reviewed artifact and is not edited by this correction.
**Corrects**: Independent Design Review `RESULT: DESIGN_REVIEW_CHANGES_REQUIRED`,
`REVIEWED_HEAD 77c19f1`, `INDEPENDENT_RISK_LEVEL: 3`, `RISK_LEVEL_AGREEMENT: YES`
(`docs/engineering/dispatch/tasks/design-review-addproduct-keyservice/report.md`).
**Worktree**: `/private/tmp/shipit-correct-addproduct-keys` · **Branch**: `design/correct-addproduct-keys`
· **Base SHA**: `77c19f1` · **HEAD SHA**: `77c19f1` · **Committed**: NO

**No Docker or Compose command was executed by this correction lane.** No analyzer, build or test was
run. See § 9.

---

## 0. What this revision changes, and the one thing that was simply wrong

### 0.1 A retraction, stated first because it is the most consequential sentence in the document

Revision 1 § R.21 and `discoveries.md` D-6 asserted, as a "traceability gap of the first order",
that **`docs/adr/0018-per-product-git-credentials.md` does not exist** and that therefore *"the
document that defines the credential model I am designing onto does not exist in this
repository."*

**That was false, and it was produced by looking in `docs/engineering/adr/` — the wrong
directory.** Verified for revision 2:

- `docs/adr/0018-per-product-git-credentials.md` exists: **158 lines**, title *"ADR 0018: Per-Product
  Git Credentials"*, status *"Proposed (amended — see §Amendments; A1 credential scope = per
  repository)"* (`:3-4`).
- `docs/adr/` holds **21** ADRs, `0001`–`0021`.
- `docs/engineering/adr/` holds exactly three, and they are the framework-distribution ADRs
  (`0001-framework-distribution-and-versioning.md`, `0002-dart-mason-git-framework-driver.md`,
  `0003-product-generic-orchestrator-skill.md`). That directory legitimately contains no product
  ADRs — which is exactly why the inference from it was unsound.

It is not a defensible reading of a citation. **13 production files cite ADR 0018 by number, several
by amendment** — `postgres_product_registry_store.dart:172` (*"ProductCredential (ADR 0018 A1 — one
per repository, no key material)"*), `product_registry_store.dart:35` (*"Product credentials (ADR
0018)"*), `repository_credential.spy.yaml:4`, `repository_credential_view.yaml:1`,
`repository_credential.dart:10` (*"(ADR 0018, AGENTS.md §13a)"*) and `:22`,
`credential_status.dart:1` and `:36`, `repository_provider.dart:8`, `product_state.dart:1`,
`product_registry_engine.dart:898` (*"ADR 0018 A1 — scope is one repository"*) and `:1057`,
`exceptions.dart:213`, `ui_view_mappers.dart:138`, `products_page.dart:308`. Revision 1 cited some
of these very files as evidence that the ADR was absent.

Revision 1's false `G-1` is **withdrawn**, not restated. The **real** gap is in § R.21 and it is
different — and larger.

### 0.2 Correction map — every finding, and where it landed

| Finding | Severity | Where addressed in revision 2 |
|---|---|---|
| **B1** ADR 0018 exists; `G-1` false; `architecture_refs` empty of credential ADRs | BLOCKER | § 0.1, § R.1, § R.4, § R.6, § R.21, `design-brief-1.1.0.md` § `architecture_refs`, `traceability-matrix-2.md` § 4 |
| **B2** "four independent mechanisms" false at the store; concurrent-mint exception will not fire | BLOCKER | § R.15 (rewritten), § R.15b (**new required deliverables**), § R.16 step 4, § R.2 constraint 3, § 8 SC-02/SC-03 |
| **H1** § R.3 leaks the reserved decision in normative voice | HIGH | § R.3 (rewritten, invariant-only), reuse row #35 |
| **H2** Q3 pre-answered by ADR 0018 `:113-114` | HIGH | § R.6 preamble and Q3 framing |
| **H3** A2's threat model understated — the *live* DB is the target | HIGH | § R.4 A2 *Against*, § R.7 threat model |
| **H4** § R.18 omits the direct-database path | HIGH | § R.18, fourth point |
| **M1** "three-step `_StepText` list" is four | MEDIUM | `design-brief-1.1.0.md` § Implications #2 |
| **M2** MEDIUM confidence on Q1 not defensible | MEDIUM | § R.8, split per option |
| **M3** `inkSecondary` must be **normative** for new copy, not a note | MEDIUM | § R.10 `N-8` (**new, normative**), § R.8, § 9 |
| **M4** `G-7` has no owner | MEDIUM | § R.4 § Q1 sub-question Q4, § R.21 `G-7` owner named |
| **L1** `engine:52` → `:54` | LOW | § R.19, `traceability-matrix-2.md` § 1 |
| **L2** `product_state.dart:29-32` → `:24-27` | LOW | § R.12, § R.19 |
| **L3** range endpoints off by a few lines | LOW | § R.4 reuse table, `traceability-matrix-2.md` § 1 |
| **L4** `referenceName` has no index | LOW | § R.3 |
| **L5** D-7 is a re-confirmation, not a new finding | LOW | `discoveries.md` D-7 (restated in place, content intact) |
| **L6** `DECISIONS.md` omits `570bb640` from its index table | LOW | § R.22 `L-6` — **reported, not edited** (Manager-owned) |

**Kept intact, because the reviewer praised them and they were correct:** `N-1`'s normative no-Cancel
rule with its rationale and its cost; `N-2`–`N-7`; § R.12's traceable way out; `R.12`'s explicit
dependence on OPEN-D4-2; `N-6`'s `HostKeyStatus.changed` path with no "trust anyway"; § R.18's
honesty about the endpoint; the § R.9 state machine; `R.13`/`R.14`'s normative definition and
five-way failure taxonomy; and the § R.5 / § R.7 fail-closed framing. Sections carried forward
unchanged say so explicitly and name their revision-1 §.

### 0.3 Brief version bump

Design Brief **v1.1.0** is `design-brief-1.1.0.md`, a complete self-contained corrected brief. It
changes exactly two things from v1.0.0 (`design-brief.md`, retained intact):

1. The `architecture_refs` table — repopulated with ADR 0012/0015/0018/0019/0020/0021 and with
   ADR 0018 and `AGENTS.md §13`/`§13b` recorded as **PRESENT/ABSENT** on verified evidence (B1).
2. Sibling-lane implication #2 — four `_StepText` entries, not three (M1).

v1.0.0 is **not** edited, so a lane that already read it is not silently contradicted; the Manager
must notify `design-addproduct-mobile` that implication #2 in v1.0.0 is superseded by v1.1.0. That
notification is listed in § 10 as a Manager action.

---

## R.1 — At-rest protection model — still `OPEN — HUMAN DECISION REQUIRED AT GATE D4`

### R.1.1 What ADR 0018 already decides, as read

The human reserved the at-rest protection model. Reading ADR 0018 in full does not remove that
reservation, but it **changes the question from four substrates to one supersession**, and it forbids
one option outright. All citations are to the file as read at `77c19f1`.

| ADR 0018 clause | What it decides | Effect on this design |
|---|---|---|
| `:84-88` | *"One `ed25519` keypair **per repository**, generated by ShipIt on the operator's device. The private half is written to **the local secret store** (macOS Keychain or `~/.config/shipit/platform/` chmod 600) and is never displayed, logged, **persisted to the durable record**, or transmitted."* | **Already names A1 (filesystem `0600` outside the tree) and A4 (host keychain), and forbids A2.** Persisting ciphertext in a table *is* persisting to the durable record. |
| `:92-95` | *"**Referenced by name, never by value** — §13's core rule is preserved. The product record stores a credential *reference* … plus the public key fingerprint. It never stores key material."* | `referenceName`'s **type** contract is settled architecture. Its **subject** is what is in dispute. |
| `:96-99` | *"Host keys are trust-on-first-use with an explicit human confirmation. **ShipIt refuses to connect to an unrecognised host.** The operator is shown the host, key type and fingerprint and must confirm it. ShipIt does not claim to have verified a host it cannot verify."* | `N-3`, `N-4`, `N-5`, `N-6` are **requirements**, not design choices. Strengthens feasibility (the transport seam is mandated, not speculative). |
| `:100-102` | *"**Access is proven, not assumed.** A product cannot be registered until a connectivity check has succeeded against the real host with the real key. The result is stored with a timestamp and shown in the UI as a fact."* | Human point 2b is an **ADR requirement**, not only a product request. Makes OPEN-D4-2 an **ADR contradiction** (§ R.19.1). |
| `:113-114` | *"Revocation is provider-native: removing the deploy key from the repository is sufficient and **requires no Shipit-side action**."* | Reframes Q3 (§ R.6). |
| `:15-30` (A1) | *"**Current:** one `ed25519` keypair **per repository**. `RepositoryCredential` is keyed by `repositoryId`; `productId` is retained for ownership checks only and is no longer the unit of scope."* | Scope is settled. `:29-30` also fixes the reference-name shape: `GIT_PRODUCT_<productRef>_<repoRef>_SSH`. |
| `:79-80` | *"This is a deliberate, scoped deviation from AGENTS.md §13 for git credentials only."* | The deviation is **recorded and deliberate**. |
| `:140-141` | *"AGENTS.md §13 gains a git-specific carve-out pointing at this ADR, so the two conventions are explicit rather than contradictory."* | The mitigation was **never applied** — `AGENTS.md` has no §13. This is the real gap (§ R.21). |

**The genuinely open delta is now one question, not four.** `DEC-b869ec24` (RESOLVED, ARCHITECTURE,
OPTION_A) moved generation **and storage** server-side behind an API returning only the public half.
`b869ec24` is **silent on the private half's custody model** — `grep -i "revoc\|rotate"` over
`.decisions/b869ec24-*.yaml` returns nothing, and no clause addresses where bytes land.

So the open question is precisely:

> **Q1′ — Does `b869ec24`'s server-side custody supersede ADR 0018 `:85-88`'s local-secret-store
> clause?**
>
> - **If NO** — ADR 0018 stands and custody stays on *"the operator's device"* (`:85-86`).
>   **A2 is forbidden**: persisting ciphertext in a table *is* persisting to the durable record
>   (`:87-88`). `b869ec24`'s "store server-side" then reduces to storing the **reference**
>   server-side — which `referenceName` already does. Note the trap: A1 and A4 *appear* ADR-native
>   (they are `:86`'s two substrates) but in this design they write **on the server**, and the
>   server is the operator's device **only** while the topology is the local Docker Compose stack of
>   today. A1/A4 therefore comply by coincidence of topology and stop complying the moment the
>   server moves; A3 is the only option that complies unconditionally, because SHIP IT never holds
>   bytes. Naming that is not choosing it — the human decides.
> - **If YES** — "never persisted to the durable record" is revoked, and the substrate choice
>   re-opens: A1, A2 and A3 all become available again, with A3 the only one that keeps
>   "referenced by name, never by value" *literally* true.
>
> **This remains the human's decision.** Revision 2 does not answer it, does not recommend a
> supersession, and defaults nothing.

Decision object: **`9417f8bf`** (SECURITY, PENDING). **Manager-owned** — not edited by this lane. The
Manager's `SUPERSEDED-IN-PART` note on that object already states consequence 2 (*"The ADR forbids A2
outright"*) and consequence 3 (*the genuinely open delta is the supersession question*). This revision
agrees with both and supplies the option framing they refer to. **The object must be reissued
against ADR 0018 before it reaches the human** — an answer given on revision-1 evidence would ask
the human to choose among options the ADR has already ruled on.

### R.1.2 What `b869ec24` settled, and what it did not

`b869ec24` settles **where generation happens and what crosses the wire**: server-side, behind an
API, public half only. It does **not** settle how the bytes are protected at rest. Both statements
are consistent with ADR 0018 — a server may hold a *reference* to an operator-local secret without
violating `:85-88` — which is why Q1′ is a supersession question and not a contradiction.

---

## R.2 — What the existing domain constrains (independent of the decision)

Three constraints hold under **every** option, because they are structural.

1. **The private half never enters `packages/product_registry`.**
   `product_registry_engine.dart:899-905` states it outright (*"This engine never generates or holds
   key material … A private key must never reach this package."*); `:933-939` rejects any `publicKey`
   containing `PRIVATE KEY`; `credential_test.dart` group *"no key material reaches the domain"*
   locks it. The key service lives in `apps/server/**` (or a new package), never in the registry
   engine.
2. **`RepositoryCredential` never gains a key-material field.** Its doc (`:12-18`) and `C-04` forbid
   it. A substrate storing key bytes **anywhere in PostgreSQL** must use a **separate table/type**,
   not a new column on `product_credential`.
3. **The private half is immutable per credential — but only in memory, and only for `copyWith`
   callers.** `copyWith` (`repository_credential.dart:137-172`) cannot change `referenceName`,
   `publicKey`, `fingerprint`, `algorithm` or `credentialId`. **Revision 1 overstated this** as a
   structural guarantee; see § R.15 for what holds at the persistence layer and what does not. The
   design's requirement is unchanged and now explicitly includes a **store-level** guard (§ R.15b).

---

## R.3 — Reconciling `referenceName` — invariant only (rewritten; `H1`)

`DEC-b869ec24` moves the private half server-side, and `referenceName` is documented as *"Name under
which the private half is held in the local secret store, e.g.
`GIT_PRODUCT_<productRef>_SSH`"* (`repository_credential.dart:70-72`). The same sentence appears in
the store interface (`product_registry_store.dart:37-38`), the table comment
(`repository_credential.spy.yaml:4-6`) and the wire view (`repository_credential_view.yaml:3-11`).

### R.3.1 The invariant this revision fixes — normative

> **`referenceName` continues to name a reference. It never carries a value.** `referenceName`
> **does not** hold key material, is **not** an obfuscation of key material, and must not be
> derived from it. This holds under every option in § R.4, under both answers to Q1′, and under
> both fail-open and fail-closed modes. It is the one statement about `referenceName` that is
> settled — and it is settled by ADR 0018 `:92-95`, not by this design.

That is the whole of the normative content. **Three things are `OPEN` and are stated as open:**

- **Its subject** — *which* store or handle the reference names. **`OPEN`, and coupled to Q1′
  (OPEN-D4-1).**
- **The substrate it names** — there is no default and no implied default. **`OPEN`.**
- **Whether it may reach the client.** **`OPEN`** — Q4 of OPEN-D4-1, owned by `9417f8bf`; see § R.4.

### R.3.2 Deleted from revision 1

| Revision 1 text (`:69-91`) | Why it is gone |
|---|---|
| *"**Decision (normative, within this design agent's authority — it selects a substrate):**"* | It self-described as selecting a substrate, for the question the human reserved. Deleted. |
| *"What changes is whose store it names: from *the operator's local secret store* to \*SHIP IT's own at-rest store\* for this credential."* | `"SHIP IT's own at-rest store"` silently **excludes A3** — the external secret manager, which § R.8 recommends and `9417f8bf` recommends as `OPTION_C`. A human could lose an option to a sentence they never read. Deleted. |
| *"**No wire-contract break from the field's existence.** Its meaning changes, not its type."* | **Retracted.** Revision 1 contradicted itself 30 lines later. Whether the wire changes depends on Q4 (`G-7`), which is open. |
| *"The column is already `referenceName: String` and **already indexed as part of the row**."* | **False (`L4`).** `repository_credential.spy.yaml:7-14` declares exactly three indexes: `product_credential_id_unique` (unique, `credentialId`), `product_credential_repo_idx` (`repositoryId`), `product_credential_product_idx` (`productId`). **`referenceName` has no index**, and it needs none under the invariant-only reading, because nothing looks a credential up by it. |

### R.3.3 What survives from revision 1's rejected-alternatives analysis

Retained because they are correct *as analysis of the field's shape*, which is orthogonal to the
substrate:

| Alternative | Why still rejected |
|---|---|
| Add a second column `privateKeyRef` beside `referenceName` | Two references to one key with no way to tell which is authoritative; `referenceName`'s contract is explicitly singular (`repository_credential.dart:70-72`) |
| Drop/null `referenceName` | Breaks the non-null `referenceName: String` on the domain type, the store interface and the table, and discards the only record of where the key is. Requires a migration for no invariant gain |

The engine's `referenceName` **parameter** keeps its name and position either way:
`recordGeneratedCredential` already takes it (`product_registry_engine.dart:915`) and already refuses
key material passed as `publicKey`.

---

## R.4 — Q1′ storage substrate — `OPEN`, re-framed against ADR 0018

Each option is independently selectable and self-contained. **Their status against ADR 0018 is now
stated per option**, which revision 1 did not do.

### A1 — Filesystem, mode `0600`, outside the repository tree — **this is what ADR 0018 `:86-87` names**

The private half is written under a dedicated directory outside the work tree, owned by the server's
service user, mode `0600`. `referenceName` = a path relative to that root.

- *ADR status*: **named by the governing ADR** as one of the two named substrates — `:86-87`'s
  *"`~/.config/shipit/platform/` chmod 600"* is A1 generalized to a server path.
- ***The condition A1 depends on, stated plainly:*** ADR 0018 `:85-86` puts custody on *"the
  operator's device"*. A1 as specified here writes on the **server**. Those are the same machine
  **only** while the topology is the local Docker Compose stack of today. So A1 satisfies ADR 0018
  *by coincidence of topology*, and the coincidence expires the moment the server moves off that
  machine — at which point A1 is server-side persistence and Q1′ resolves YES by fact rather than by
  decision. This is worth saying plainly because it is the same unenforced premise as
  `DEC-570bb640`'s *"local only"*, which is a promise rather than a control
  (`grep "127.0.0.1:"` → no match).
- *For*: no new dependency; works in the current Compose topology; trivially inspectable by a human
  debugging a stuck registration; works under a container.
- *Against*: protection is entirely the host filesystem's. With no volume encryption, a stolen
  volume, a backup, or a `docker cp` yields the key in cleartext. Filesystem permissions do not
  defend against a process running as the same uid — **which is the git transport**
  (`git_workspace_inspector.dart:106-112` runs `Process.run(git, args)` with no `environment:`).
- *Blast radius of a mistake*: the whole key store.

### A2 — Envelope-encrypted ciphertext in a **separate** table — **FORBIDDEN by ADR 0018 `:87-88`**

The private half is sealed with a key-encryption key (KEK); the ciphertext lives in its own table,
never on `product_credential` (§ R.2 constraint 2). `referenceName` = an opaque row reference. The
KEK comes from configuration, never from the database.

> **ADR 0018 forbids this option.** `:86-88`: the private half *"is never displayed, logged,
> **persisted to the durable record**, or transmitted."* Storing ciphertext in a table **is**
> persisting to the durable record. Offering A2 to the human **without this sentence** would ask the
> human to approve a violation of the governing ADR. It appears in this revision only so the option
> set is complete *and* visibly closed.

- *ADR status*: **FORBIDDEN**, unless and until the human supersedes `:85-88` — i.e. answers Q1′ in
  the affirmative. Under that answer A2 becomes available again.
- *For (only under supersession)*: survives container replacement; the ciphertext is useless without
  the KEK; keeps rotation transactional with the rest of the store.
- *Against — amended per `H3`*:
  - Adds a migration and a second persistence path; the KEK becomes the single most valuable secret
    in the system and needs its own rotation story; if the KEK lives in an env file, the
    ciphertext's strength equals the env file's protection.
  - A SQL injection elsewhere in the server becomes a key-disclosure path rather than a data leak.
  - **Revision 1's claim that "backups of the database alone no longer disclose the key" was
    false comfort, and is withdrawn.** The live database is the *least*-protected component in the
    system. An attacker needs **no backup**:
    - `docker/compose.yaml:62` hardcodes `SERVERPOD_DATABASE_PASSWORD: shipit` in a **committed**
      file;
    - `docker/compose.yaml:16-17` publishes `"5432:5432"` unqualified, which Docker resolves to
      `0.0.0.0` — every interface, including the LAN;
    - `.env.example:16-18` documents `POSTGRES_DB=shipit`, `POSTGRES_USER=shipit`,
      `POSTGRES_PASSWORD=shipit`, and `DEC-570bb640` records those defaults as evidence of exactly
      this exposure (`570bb640` `:34-37`, `:73-75`).

    So under A2 the sealed material sits in the one store an off-host caller can read directly with
    documented credentials. A2 converts *"an attacker needs a backup"* into *"an attacker needs the
    port"*.
- *Note*: this is the only option that changes the shape of the data layer — which is also why the
  § R.3 wire-contract question (Q4) cannot be answered independently of it.

### A3 — External secret manager / mounted secret — **unchanged, and no longer excluded by § R.3**

SHIP IT never writes key bytes; it writes a *reference* and asks the manager for the material at
transport time. `referenceName` = a secret path or ARN.

- *ADR status*: **not named by `:85-88`**, but not forbidden by it either. Under a strict reading of
  Q1′-negative (SHIP IT holds only a reference), A3 is the option that satisfies the ADR and
  `b869ec24` *simultaneously and unconditionally* — SHIP IT never holds bytes, so it complies
  wherever the server runs, and it satisfies the strongest reading of `b869ec24`'s *"never exposing
  it to the browser"*. A1 and A4 comply only while the server is co-located with the operator (see
  A1's topology condition). That makes A3 the natural consequence of Q1′-negative rather than a
  competing choice — a consequence, **not** a selection: the human decides Q1′, this revision does
  not.
- *For*: strongest separation — SHIP IT holds a reference and never a value, which is **literally
  the existing contract** (ADR 0018 `:92-95`; `repository_credential.dart:12-18`), so
  `referenceName` needs no reinterpretation at all; rotation and revocation are manager features;
  the key never appears in the database or its backups.
- *Against*: adds a runtime dependency that can be unavailable; introduces a failure mode that lands
  directly on § R.5; on a single local machine this may be more machinery than the problem warrants.
- *Consequence*: this option makes the reference's sensitivity **highest** — an ARN discloses vault
  topology and path names — which is why its client exposure is a Q4 consequence, not a fixed answer.

### A4 — OS keychain / hardware-backed keystore on the host — **this is what ADR 0018 `:86` names**

The private half is stored in the host's keychain (e.g. macOS Keychain) or a TPM-backed store, and
read by handle at transport time. `referenceName` = a keychain item label.

- *ADR status*: **named by the governing ADR** as the other of its two substrates.
- *For*: strongest at-rest property of the four; hardware binding; per-item ACLs.
- *Against — feasibility uncertain in this repository's topology*. SHIP IT runs as a container
  (`docker/compose.yaml`) while the keychain is the *host's*; container→host keychain access is
  awkward and host-dependent, and CI or another machine would have a different store. Per the
  no-Docker rule I could not test this — see § 9, `UNVERIFIED`.
- *Consequence if chosen*: the "local only" scope in `DEC-570bb640` becomes load-bearing for
  **correctness**, not just for security posture.

### R.4.1 Q4 — may `referenceName` reach the client? — `OPEN`, now with an owner (`M4`)

Revision 1 recorded this as `G-7` with **no owner**. It does have one:

> **Owner: `9417f8bf`.** Its stated question is the substrate; `G-7` is a *consequence* of the
> substrate answer (an ARN discloses topology; a filesystem path discloses layout; an opaque row
> reference discloses nothing) and **must be asked in the same reissued object**. Revision 1's
> omission let a security-relevant question have no decision attached to it. The Manager should
> widen `9417f8bf`'s question to cover client exposure explicitly, alongside Q1′.

**Not answered here.** `G-7` remains a gap; it now has a name attached to it.

---

## R.5 — Q2 degraded mode — `OPEN`, unchanged

Carried forward from revision 1 § R.5 with no change: **B1 — fail closed** (refuse to mint, name the
remediation) vs **B2 — fail open with a recorded warning** (mint anyway, record degradation, warn in
the UI). The review confirmed the `OPEN` marker held and the analysis was sound.

**One addition, from re-reading ADR 0018.** ADR 0018 `:99` — *"ShipIt does not claim to have verified
a host it cannot verify"* — establishes that the platform's recorded posture is *never assert what it
has not proven*. B2 would introduce the one place in the credential design where something is
recorded rather than proven. That strengthens the reviewer's `MEDIUM` confidence on Q2; it does not
decide it.

**Question asked at Gate D4 (Q2):** unchanged — fail closed (`B1`) or fail open (`B2`).

---

## R.6 — Q3 key lifecycle — `OPEN`, re-framed (`H2`)

`revokedAt`/`revokedReason` exist (`repository_credential.dart:115-117`) and `revokeCredential`
(`engine:1058-1076`) **never deletes the row** — the historical record stays readable
(`credential_test.dart:246`). What governs the private half's *disposal* is a different question.

### R.6.1 What ADR 0018 `:113-114` already says, and why Q3 is still open

ADR 0018 `:113-114`, read: *"Revocation is provider-native: removing the deploy key from the
repository is sufficient and **requires no Shipit-side action**."*

Revision 1 presented Q3 as an untouched open question. That was a **presentational error**, and the
correction is precise rather than a withdrawal:

- Under **ADR 0018's own custody model**, that clause **is** the complete answer: SHIP IT holds no
  bytes, so removing the deploy key at the host is the whole procedure. C-2 (retain) is what the ADR
  already specifies, and it needs no decision.
- Under **`b869ec24`'s custody model**, SHIP IT **does** hold bytes — bytes the ADR said would never
  exist. In that world "requires no Shipit-side action" is either (a) still true because the operator
  uninstalls at the host and the retained bytes are inert, or (b) false because a retained
  server-side key remains a live credential in SHIP IT after the operator believes they have revoked.
- **`b869ec24` is silent**: `grep -i "revoc\|rotat"` over `.decisions/b869ec24-*.yaml` → **no match**.

**So: `b869ec24` supersedes ADR 0018 `:85-88`'s custody clause by implication, and does not address
`:113-114` at all.** Q3 therefore stays open — but on a stated basis, not on the impression that
nobody had considered it:

> **Q3 — does ADR 0018 `:113-114` ("requires no Shipit-side action") survive `b869ec24`'s server-side
> custody?**
>
> - **YES** → C-2 is the answer and no Shipit-side disposal ever happens; `revoked` is a record, not
>   a control.
> - **NO** → the human chooses among C-1 / C-2 / C-3.

This is **not** a question about an unexplored option space, and it must not be presented to the
human as one. Decision object **`79e860e2`** must be restated in exactly these terms.

### R.6.2 The three options — unchanged, with the ADR's default named

- **C-1 — Destroy the private half on revoke; keep the row.** `revokeCredential` additionally
  destroys the key bytes. The row remains, fully readable, with `status: revoked`, `revokedAt`,
  `revokedReason`. The audit trail is untouched.
  - *For*: revocation becomes real; a leaked key stops working on the SHIP IT side immediately.
  - *Against*: no forensic re-verification after revocation.
  - *Against, per ADR 0018*: **contradicts `:113-114`** — it adds a Shipit-side action the ADR says
    is unnecessary.
  - *Note*: the existing test *"revoked credentials stay readable, never deleted"* asserts the
    **record**, so C-1 does not contradict it.
- **C-2 — Retain the private half; revocation is a logical flag only.** *This is ADR 0018's answer
  under its own model, and is the default if Q3 resolves YES.*
  - *For*: forensic re-verification stays possible; simplest; matches the ADR.
  - *Against*: `revoked` is a label with no corresponding security property while bytes are retained;
    the operator's mental model ("revoked") is misleading.
- **C-3 — Retain for a grace period, then destroy.**
  - *For*: bounded forensic window; supports undoing an accidental revocation.
  - *Against*: requires a background job and a durable schedule; the grace period is a new tuning
    parameter nobody has justified; also departs from `:113-114` like C-1.

**Rotation is not open.** It is already specified: `rotateCredential` (`engine:1084-1119`) revokes
the old credential, then mints a new one carrying `supersedesCredentialId`; host confirmation does
**not** carry over, so the new key re-enters `hostUnrecognised` by design. `rotateCredential`'s
order (revoke at `:1104`, mint at `:1108-1119`) is also what makes the new partial unique index safe
— see § R.15b.

---

## R.7 — Q4 transport exposure — normative, with the threat model corrected (`H3`)

Stated as a constraint rather than a choice, because every option in § R.4 and § R.5 must satisfy it.

- The private half **must never** be returned by any endpoint, serialised into any wire type, logged,
  included in an exception message, or exposed to a Serverpod `Session`.
- It is readable **only** by the key-transport component, immediately before a transport attempt, for
  the minimum time needed, and never cached in a long-lived field.
- Every read is an auditable event. `AuditEntityType.productCredential` already exists
  (`packages/platform_contracts/lib/src/enums/audit_entity_type.dart:8`).

### R.7.1 Threat model — amended

Revision 1 listed what the constraint protects against. Revision 2 adds the component that the
reviewer's `H3` showed to be the weakest link, because it is the **most** reachable one:

| Asset at risk | Reachable by | Today |
|---|---|---|
| Private half in a filesystem/A4 store | Any process as the same uid — **including the git transport** | No `environment:` injection exists (`git_workspace_inspector.dart:106-112`) |
| Private half **sealed in PostgreSQL** (A2) | Any caller who can reach **5432**, using the **documented default credentials** | `docker/compose.yaml:62` commits `SERVERPOD_DATABASE_PASSWORD: shipit`; `docker/compose.yaml:16-17` publishes `5432:5432` on `0.0.0.0`; `.env.example:16-18` documents the defaults; `DEC-570bb640` `:73-75` records them |
| Host-key trust | Nothing — `HostKeyStatus.permitsConnection` has **no runtime enforcer** | `ARCHITECTURE_DISCOVERY` `D-3` |
| The reference itself (an ARN / a path) | Any client, because `RepositoryCredentialView` exposes `referenceName` | `Q4` / `G-7`, `OPEN`, owned by `9417f8bf` |

**The load-bearing conclusion:** under A2 the sealed material sits in the *only* store in this
topology that an off-host caller can read directly with credentials published in a committed file.
That is a property of the **environment**, not of the cryptography, and no envelope scheme changes it.

**Honest status: the constraint above is currently unenforceable.** There is no transport seam to
constrain, `Session` is the ambient authority in every existing endpoint, and redaction is not
demonstrable from source. What the design commits to is the **interface** — key material crosses
exactly one component boundary — and states that enforcement requires that boundary to be built and
independently reviewed. An implementation-time obligation, not a delivered property.

ADR 0018 `:96-99` makes the first of these an explicit requirement rather than a design choice
(*"ShipIt refuses to connect to an unrecognised host"*), which is why the transport seam's
feasibility is rated as a build obligation rather than an optional extra (§ 9).

---

## R.8 — Recommendation, evidence, risk (**not** a decision)

The human asked for options and did not ask me to choose. Recorded as a recommendation only. This is
a correction of the shape revision 1 used: revision 1 gave **one** confidence for Q1 across four
options whose reachability differed, and the reviewer found `MEDIUM` indefensible on its own stated
basis (`M2`). Confidence is now **per option**, and no option has been runtime-verified.

| Sub-question | Option | Recommendation | Confidence | Evidence behind it |
|---|---|---|---|---|
| Q1′ / Q1 | **A1** | Only if Q1′ resolves **NO** (ADR 0018 `:86-87` stands) | **LOW** | Named by the governing ADR, and reachable from a container. Protection is the host filesystem's, and it does not survive a same-uid process — which is the transport. Nothing runtime-verified. |
| Q1′ / Q1 | **A2** | **Not recommendable while `:85-88` stands** — forbidden by the ADR. Recommendable only after supersession | **LOW** | Under supersession: the strongest option that stays inside the current transactional store. Against it: the live database is reachable at 5432 with committed default credentials (§ R.7.1), which is a stronger attacker path than a backup. |
| Q1′ / Q1 | **A3** | Preferred under **either** answer to Q1′, if a manager is genuinely reachable in the target topology | **LOW** | Preserves "referenced by name, never by value" **verbatim** (ADR 0018 `:92-95`; `repository_credential.dart:12-18`) — the strongest existing property. The only option that is ADR-compliant **regardless of topology**, since SHIP IT never holds bytes. Reachability untested. |
| Q1′ / Q1 | **A4** | **Not recommended** | **LOW** | Named by the ADR (`:86`) but container→host keychain reachability is `UNVERIFIED` (§ 9), and choosing it makes `570bb640`'s unenforced "local only" load-bearing for correctness. |
| Q2 | **B1 (fail closed)**, only if the error names a concrete remediation | Recommended | **MEDIUM** | Unchanged from revision 1 and independently accepted: `HostKeyStatus.changed` already fails closed (`credential_status.dart:49-50`), `confirmHostKey` records-then-refuses (`engine:992-1011`), and ADR 0018 `:99` establishes the platform posture of not asserting what it has not proven. |
| Q3 | Depends on the Q3′ framing (§ R.6.1). If Q3′ resolves YES → **C-2**, no decision needed | Conditional | **MEDIUM** that the framing is right; **LOW** on any C-option's implementation cost | ADR 0018 `:113-114` is the recorded answer under the ADR's own custody model; `b869ec24` is silent. |
| Q4 (`referenceName` to clients) | Decide together with Q1′ | — | **LOW** | Whether it is a path, an ARN or an opaque row reference **is** the answer's output, not an input. |
| Transport exposure | The single-boundary constraint in § R.7, enforced by construction | — | **LOW** | No SSH transport seam exists today; ADR 0018 `:96-99` mandates it, which raises the obligation without making it easier. |

**Risk of getting this wrong**: under-protecting a repository write key (§ R.4 A1) leaks the key;
over-blocking (§ R.5 B1) reintroduces exactly the "stuck and unable to register" outcome the human
objected to in point 2d — which is why B1's remediation text is a design obligation, not a nicety.

---

## R-2 — The `hostUnrecognised` trust state (`R-2d`) — carried forward from revision 1

The reviewer confirmed `N-1` (`R.10`) is the right rule stated the right way, and that `N-6` gives
`changed` a user-facing path without a "trust anyway" affordance. **Nothing here is rewritten.** The
state machine (§ R.9), requirements `N-1`–`N-7` (§ R.10), the client state model (§ R.11) and the
two-factor `canRegister` are carried forward from `design-revision.md` § R.9–R.11.

**Two changes, both additive:**

1. **Line-number corrections (`L1`, `L2`).** `createProduct` hardcodes `state: ProductState.registered`
   at **`engine:54`** (revision 1 said `:52`). The *"Registered in the registry. No baseline, no
   governance, no work … a product is visible here before anything about it has been approved"* text
   is `product_state.dart:24-27` (revision 1 said `:29-32`). Substance unchanged and re-verified: no
   pre-registration `ProductState` exists — `enum ProductState { registered('registered'), … }` at
   `:23-28`.
2. **`N-8` is new** — see below (`M3`).

### R.10 `N-8` — Normative contrast requirement for all new copy (`M3`)

> **`N-8` — New copy uses `palette.inkSecondary`, never `palette.inkTertiary`.** Every string this
> design adds to the Add Product page — the five failure-kind messages (`R-14`) and the two host-state
> messages (`R.9`/`R-10`) — is helper/technical text rendered on the card surface, and **must** use
> `ShipItPalette.inkSecondary`. `inkTertiary` is **not** permitted for new copy.
>
> **Why this is normative and not advisory.** The current idiom for exactly this copy is
> `inkTertiary` on `palette.card` — `add_product_page.dart:542` (*"ed25519 · created on this device
> · the private half stays in the keychain"*) and `:590` (*"Add this key to the repository's deploy
> keys with write access, then check."*). Measured on the card surface: **`inkTertiary` = 4.23:1 in
> dark, which fails WCAG AA**; `inkSecondary` = **6.74:1 light / 6.10:1 dark**, both passing AA.
> Revision 1 stated the requirement in § R.8's recommendation table, where an implementer reading
> requirements — not recommendations — would not find it. Every one of the seven new strings would
> otherwise follow the failing idiom by default, because that is what the surrounding copy uses.
>
> **Measurement provenance.** These ratios are **inherited**, not re-measured by this lane: they come
> from `docs/engineering/dispatch/tasks/design-register-button/report.md:71-76` and were
> **independently re-measured and confirmed** by the Independent Design Review
> (`design-review-addproduct-keyservice/report.md:33`). This correction lane ran **no** contrast
> tool; see § 9.

`design_system_compliance` remains `PARTIAL` and `ux_accessibility_score` remains `PARTIAL` — the
boards are the sibling lane's (`C-11`), and `N-8` constrains the tokens, not the boards. See § 9.

---

## R.3-client — "Check access" (`R-2c`) — carried forward from revision 1

§ R.13 (the normative definition of what Check access attempts, against which host, with which
credential, and what success does and does not prove) and § R.14 (the five-way `failureKind`
taxonomy mapped onto the existing `CredentialStatus.failing` + `lastFailureReason` vocabulary) are
carried forward from `design-revision.md` § R.13–R.14 unchanged. The review confirmed them.

**One change, from `N-8`:** the five user-facing strings in § R.14's "User sees" column are now bound
to `palette.inkSecondary`.

---

## R.15 — Silent key rotation is **not** structurally impossible today (rewritten; `B2`)

> **This section replaces revision 1 § R.15 in full.** Revision 1 claimed B6 was "structurally
> impossible" via "four **independent** mechanisms", the strongest being that `copyWith` cannot
> change `publicKey`. Verified for revision 2: **that claim is false at the layer that persists the
> row**, and mechanisms 3 and 4 are not independent of it. The finding B6 itself is real; the claim
> that it cannot recur structurally was overstated.

### R.15.1 What the store actually does

`saveProductCredential` (`apps/server/lib/src/persistence/postgres_product_registry_store.dart:177-243`):

```dart
Future<void> saveProductCredential(RepositoryCredential credential, {int? expectedVersion})
```

- With a **non-null** `expectedVersion` (`:212-236`) it runs a guarded
  `UPDATE … WHERE "credentialId" = @credentialId AND "version" = @expected` and throws
  `ConcurrentModificationException` when `affected != 1`.
- With a **null** `expectedVersion` (`:238-243`) it runs
  `INSERT INTO "product_credential" (…) VALUES (…) ON CONFLICT ("credentialId") DO UPDATE SET $assignments`,
  where `$assignments` (`store:195-210`) includes
  `"publicKey" = @publicKey, "fingerprint" = @fingerprint, "algorithm" = @algorithm,
  "referenceName" = @referenceName, "repositoryId" = @repositoryId, "productId" = @productId,
  "status" = @status, …`.

`recordGeneratedCredential` (`engine:912-967`) calls it at **`engine:965`** as
`await _store.saveProductCredential(credential);` — **with no `expectedVersion`.** It accepts a
**caller-supplied** `credentialId` (`engine:920`), and its one-active guard is `engine:940-941`:

```dart
final active = await _store.readActiveCredentialForRepository(repositoryId);
if (active != null && active.credentialId != supersedesCredentialId) { throw … }
```

### R.15.2 The overwrite, verified by construction

```dart
recordGeneratedCredential(
  credentialId:         <the EXISTING credential's id>,
  supersedesCredentialId:<the SAME id>,     // ← passes the engine:941 guard
  publicKey:            <a different key>,
  fingerprint:          <its fingerprint>,
  …
);
```

1. `engine:925` ownership check passes.
2. `engine:940-941` — `active != null` is true, but `active.credentialId == supersedesCredentialId`,
   so the guard **does not throw**.
3. `engine:950-964` constructs a **fresh** `RepositoryCredential` with `status: CredentialStatus.generated`
   (`engine:959`) and `version: 1` (`engine:963`). **`copyWith` is not on this path at all.**
4. `engine:965` → `saveProductCredential` with null `expectedVersion` → the `ON CONFLICT DO UPDATE`
   overwrites `"publicKey"`, `"fingerprint"`, `"algorithm"` and `"referenceName"` **on the existing
   row**, resets `status` to `generated`, and — because the new object carries no confirmation — sets
   `hostKeyStatus` back to `unknown` and clears `hostConfirmedAt`/`hostConfirmedBy`.

**Result: the stored key the operator installed is silently replaced, with no rotation record, and
their host confirmation is discarded.** That is finding B6 exactly, reachable through the domain's
own public API. `rotateCredential` (`engine:1084-1119`) is a second route: it forwards an optional
caller-supplied `credentialId` (`engine:1091`, `:1117`) straight into `recordGeneratedCredential`.

### R.15.3 What holds, and what it is worth — **two mechanisms, not four, and not independent**

| # | Mechanism | Status | What it actually buys |
|---|---|---|---|
| 1 | **Endpoint-level get-or-create.** R.16 step 2 returns the existing public half with `alreadyExisted: true` and never generates. | **Holds — but only if the new endpoint is written that way.** It is a property of code that does not exist yet, not of the domain. | Removes the *accidental* re-mint from the UI. A caller that skips it (a second endpoint, a script, a test) is unprotected. |
| 2 | **Check path contains no generation call.** | **Holds — same character as #1.** It is a design statement about a not-yet-written endpoint, not an existing guard. | Prevents the check control from minting. Nothing prevents anything *else* from minting. |
| 3 | **Engine refuses a second active credential** (`engine:940-941`). | **Holds, but conditionally** — it is a **refusal of a second row**, keyed on `supersedesCredentialId`. It is *not* an immutability guard, and it is **not enforced by the database** (see § R.15.4). | Prevents key *sprawl* on one repository. Provides **no** protection against re-pointing an existing id, which is the actual B6 mechanism. |
| 4 | **`copyWith` cannot change `publicKey`** (`repository_credential.dart:137-172`). | **True in memory; irrelevant at the persistence layer.** `copyWith` is not called on the mint path — a fresh object is constructed and upserted. | Zero protection on the boundary that persists the row. |

**These are not independent.** #3 and #4 both live *upstream* of the boundary that fails; #1 and #2
are the same control written twice. Revision 1's sentence *"These are independent. Even if the
endpoint's idempotency were removed, mechanism 3 still refuses and mechanism 4 still prevents silent
substitution"* is **withdrawn** — mechanism 4 prevents nothing there, and mechanism 3 declines to
refuse exactly the case that matters.

**Accurate statement of what revision 2 claims:** with R.15b implemented, silent re-pointing of a
stored `publicKey` is refused at the store boundary and concurrent mints collapse to one row. Until
then, `R-B6` is *not* closed, and the design says so.

### R.15.4 Why two concurrent mints can produce two active credentials

`product_credential` carries **one** unique index and two non-unique ones
(`apps/server/migrations/20261001205247600/definition.sql:645-647`):

```sql
CREATE UNIQUE INDEX "product_credential_id_unique"   ON "product_credential" USING btree ("credentialId");
CREATE INDEX        "product_credential_repo_idx"    ON "product_credential" USING btree ("repositoryId");
CREATE INDEX        "product_credential_product_idx" ON "product_credential" USING btree ("productId");
```

`ON CONFLICT` is keyed on `"credentialId"` (`store:239`). Two concurrent mints that generate different
ids both pass the read-then-write at `engine:940`/`engine:965` and both insert. `repositoryId` has
**no** unique constraint. The result is **two active credentials for one repository**, violating ADR
0018 A1's *"`RepositoryCredential` is keyed by `repositoryId` … one keypair per repository"* (`:19-21`).

So the exception revision 1's § R.16 step 4 relied on **will not fire**, and *"two simultaneous
presses must still yield one key"* was **not guaranteed** — it was hoped for.

---

## R.15b — New required design deliverables (`B2`)

These are **not optional refinements**. Revision 2's `R-B6` and `SC-02`/`SC-03` claims depend on
them, and the risk assessment in § 9 cites them. They are specified here so an implementer cannot
claim B6 is closed while the store still allows it.

### R.15b.1 `D-1` — Store-level key-material immutability guard (**required**)

**Requirement.** `saveProductCredential` must **refuse** to change `publicKey`, `fingerprint`,
`algorithm` or `referenceName` on a row whose `credentialId` already exists. A conflicting write
against an existing identity must **throw**, never silently upsert.

**The CAS pattern alone is NOT sufficient — and this matters.** The reviewer observed that
`recordCredentialCheck:1052` and `confirmHostKey:997` already pass `expectedVersion`, so the pattern
exists. True, and the engine uses it correctly at `engine:997`, `:1011`, `:1052`, `:1074`. But on the
**mint** path `recordGeneratedCredential` hardcodes `version: 1` (`engine:963`), so a row created by
an earlier mint is *also* at version 1: passing `expectedVersion: 1` would match, the `UPDATE` would
succeed, and `publicKey` would still be overwritten. **A version CAS alone does not close this hole.**

**Required shape.** The guard must be expressed in terms of the immutable fields themselves. Two
acceptable implementations; the design requires **one** of them, not a preference between them:

- **(i) Predicated `DO UPDATE` (preferred — one place, no API change).** Give the `ON CONFLICT`
  branch a `WHERE` clause on the immutable fields:

  ```sql
  INSERT INTO "product_credential" (…) VALUES (…)
  ON CONFLICT ("credentialId") DO UPDATE SET <mutable assignments>
  WHERE "product_credential"."publicKey"    = @publicKey
    AND "product_credential"."fingerprint"  = @fingerprint
    AND "product_credential"."algorithm"    = @algorithm
    AND "product_credential"."referenceName" = @referenceName
  RETURNING "credentialId"
  ```

  A conflicting row whose immutable fields differ is then **not updated**, `RETURNING` yields
  nothing, and the store throws. One function, one statement, no interface change. Because the
  mutable set (`status`, `lastVerifiedAt`, `lastVerifiedBy`, `lastFailureReason`, `hostKeyStatus`,
  `host`, `hostKeyFingerprint`, `hostConfirmedAt`, `hostConfirmedBy`, `revokedAt`, `revokedReason`,
  `version`) is exactly the `copyWith` parameter set, the predicate mirrors the in-memory
  immutability the domain already has, and the two finally agree.
- **(ii) Explicit pre-check + typed refusal.** Before the write, read the existing row by
  `credentialId`; if present and any immutable field differs, throw a typed
  `CredentialImmutabilityViolationException` (added to `packages/product_registry/lib/src/exceptions.dart`
  next to `CredentialNotUsableException:201`). **Do not** implement this as a bare
  `readProductCredential` + `if` without the `DO UPDATE` predicate — a check-then-write without a
  predicating write is itself racy.

Either way: **`recordGeneratedCredential` must continue to pass no `expectedVersion` for genuine
inserts** — a new credential has no prior version — so the guard must live in the immutability
predicate, not only in CAS.

**Invariant restated for the contract:** key material is chosen **once, at mint**, by the mint path
only. Rotation mints a **new** `credentialId` (it already does: `rotateCredential` passes
`supersedesCredentialId` and no `credentialId` by default, `engine:1108-1119`). **No path may change
the key material of an existing `credentialId`.** Changing the substrate for an existing key requires
rotation.

### R.15b.2 `D-2` — Partial unique index on the active set (**required migration, proposed only**)

**Requirement.** ADR 0018 A1's one-credential-per-repository invariant must be a **database**
invariant, not an application convention. Propose — and per `C-09` **do not create**; `apps/server/migrations/**`
is `PROHIBITED_PATHS` for this lane:

```sql
-- Proposed migration, NOT created by this lane (C-09)
CREATE UNIQUE INDEX "product_credential_active_repository_unique"
  ON "product_credential" USING btree ("repositoryId")
  WHERE "status" <> 'revoked';
```

**Why this predicate is the right one, by construction.** `readActiveCredentialForRepository`
(`postgres_product_registry_store.dart:257-268`) selects
`WHERE "repositoryId" = @repositoryId AND "status" <> 'revoked' ORDER BY "createdAt" DESC LIMIT 1`,
and the store interface documents *"Revoked credentials are never returned here"*
(`product_registry_store.dart:46-47`). The index predicate is therefore **identical to the predicate
that defines "active" in the read path**, so the constraint can never contradict the query. It also
preserves `readCredentialsForProduct`'s contract that the historical record — revoked rows included —
stays readable (`product_registry_store.dart:52-56`).

**What it changes.** Two concurrent mints can no longer both insert. The loser gets a unique
violation instead of a second active row. § R.16 step 4 is rewritten to match.

**What it does not break.** `rotateCredential` revokes first (`engine:1104`) and mints second
(`engine:1108-1119`), so the old row leaves the active set before the new one enters it — the index
is satisfied in order. `re-registration after revocation` is unaffected, because revoked rows are
outside the predicate.

**Cost, stated.** A migration, plus one behaviour change implementers must handle: a genuine
double-rotation race now surfaces as a unique violation rather than as a second row. That is the
point; it must be mapped to a typed error, not swallowed.

### R.15b.3 `D-3` — Two engine-level tests that **fail today**

The existing coverage does not reach either case. `credential_test.dart:206` asserts that a second
credential for a repository is refused, using `credentialId: 'cred-2'` with **no**
`supersedesCredentialId` — i.e. it exercises the *second-row* refusal (mechanism 3), not the
*same-id replacement* that is the actual B6 path, and not the concurrency case.

| ID | Test | Asserts | Status today |
|---|---|---|---|
| **T-A** | Same-`credentialId` re-mint must throw and change nothing | `recordGeneratedCredential(credentialId: <existing>, supersedesCredentialId: <existing>, publicKey: <different>, fingerprint: <different>, …)` throws; afterwards `readProductCredential(<existing>).publicKey` is **byte-identical** to before, and `fingerprint`, `algorithm`, `referenceName`, `status`, `hostKeyStatus`, `hostConfirmedAt` are unchanged | **FAILS** — no throw; `publicKey` is overwritten in place (§ R.15.2) |
| **T-B** | Two concurrent mints yield exactly one active row | Two `recordGeneratedCredential` calls for the same `repositoryId`, both past the read at `engine:940`, produce exactly **one** row with `status <> 'revoked'` | **FAILS** — `repositoryId` is non-unique (`definition.sql:646`), so two rows are inserted (§ R.15.4) |

**T-B requires the Postgres-backed store**, not a fake: a fake cannot demonstrate a unique index. It
belongs to the integration tier (`make test-integration`, disposable Postgres, self-cleaning per
`AGENTS.md` § Test resource hygiene). **Neither test was run by this lane** — no test was run; see
§ 9.

### R.15b.4 Traceability

`D-1` and `D-2` are **required** because they are the difference between "`R-B6` is closed" and
"`R-B6` is documented and still open". They are additional to, not a substitute for, OPEN-D4-1: they
are substrate-independent — no choice of A1/A2/A3/A4 affects whether an existing `publicKey` may be
changed. **They are therefore not part of the human's reserved decision and are not gated on it.**

---

## R-4 — Reuse table (reverified; rows #31 and #35 amended; rows added)

Every element maps to a named existing artifact. Line ranges are re-verified at `77c19f1`;
`L3`'s off-by-a-few-lines endpoints are corrected.

| # | Design element | Maps onto | New? |
|---|---|---|---|
| 1 | The credential record | `RepositoryCredential` (`repository_credential.dart:36`) | — |
| 2 | Credential lifecycle states | `CredentialStatus` `generated\|verified\|failing\|revoked` (`credential_status.dart:6-21`) | — |
| 3 | Host-trust states | `HostKeyStatus` `unknown\|confirmed\|changed` (`credential_status.dart:41-50`) | — |
| 4 | The "both halves" gate | `canReachRepository` (`:128-129`), `permitsConnection`, `isUsable` | — |
| 5 | Recording a minted credential | `recordGeneratedCredential` (`engine:912-967`) | — |
| 6 | Host confirmation | `confirmHostKey` (`engine:974-1013`) | — |
| 7 | Recording a check result | `recordCredentialCheck` (`engine:1020-1054`) | — |
| 8 | Revocation | `revokeCredential` (`engine:1058-1076`), `revokedAt`/`revokedReason` | — |
| 9 | Rotation | `rotateCredential` (`engine:1084-1119`), `supersedesCredentialId` | — |
| 10 | The credential a caller must use | `requireUsableCredential` (`engine:1138-1162`) | — |
| 11 | One-active-credential rule | `engine:940-941` + `credential_test.dart:206` | — |
| 12 | Key-material guard | `engine:933-939` + `credential_test.dart` group "no key material reaches the domain" | — |
| 13 | Durable storage | `saveProductCredential`, `readProductCredential`, `readActiveCredentialForRepository`, `readCredentialsForProduct` (`product_registry_store.dart:39-56`) | — |
| 14 | Postgres implementation | `postgres_product_registry_store.dart:173-320` | — |
| 15 | Table | `product_credential` (`repository_credential.spy.yaml:1-14`) | — |
| 16 | Existing credential wire type | `RepositoryCredentialView` (`repository_credential_view.yaml`) | — |
| 17 | View mapping | `UiViewMappers.repositoryCredentialView` (`ui_view_mappers.dart:169-188`) | — |
| 18 | Already surfaced to clients | `ProductDetailView.credentials` (`control_plane_service.dart:362-403`) | — |
| 19 | Error vocabulary | `CredentialNotFoundException`, `CredentialNotUsableException`, `HostKeyNotConfirmedException` (`packages/product_registry/lib/src/exceptions.dart:201,215,232`) | — |
| 20 | Audit sink | `AuditEntityType.productCredential` (`audit_entity_type.dart:8`) | — |
| 21 | Endpoint home | `ProductRegistryEndpoints` (`apps/server/lib/src/endpoints/product_registry_endpoints.dart`) — *"an endpoint never sets state directly"* | — |
| 22 | Service layer | `ControlPlaneService` (`control_plane_service.dart`) | — |
| 23 | Repository identity | `RepositoryReference` (`repository_reference.dart`), `.uri`, `.provider` | — |
| 24 | Client check axis | `AccessStatus` (`add_product_page.dart:239`) — unchanged | — |
| 25 | UI components | `DesignPanel`, `MicroLabel`, `InlineLink`, `ShipItType`, `ShipItPalette`, `ShipItMetrics` | — |
| 26 | Mint endpoint | `ProductRegistryEndpoints.mintOrReadDeployKey` | **NEW** — required by `R-H1`; no endpoint currently exposes a credential view (`grep -c RepositoryCredentialView apps/server/lib/src/endpoints/*.dart` → **0** for all 11 files) |
| 27 | Check endpoint | `ProductRegistryEndpoints.checkRepositoryAccess` | **NEW** — no access-check capability exists |
| 28 | Mint response type | `DeployPublicKeyView` | **NEW** — `RepositoryCredentialView` has **no** `publicKey` field (`repository_credential_view.yaml:7-26`) |
| 29 | Check response type | `CredentialCheckResultView` + `failureKind` presentation enum | **NEW** — the wire must distinguish causes; the *domain* vocabulary is unchanged (§ R.14) |
| 30 | Client host-trust enum | `HostTrustStatus` | **NEW** — mirrors server `HostKeyStatus`; no client equivalent exists |
| 31 | The private-half store | — | **NEW, and `OPEN — HUMAN DECISION REQUIRED AT GATE D4` (`9417f8bf`)**, re-framed in § R.1.1 as Q1′. **ADR 0018 `:85-88` names A1/A4 and forbids A2** |
| 32 | Keypair generation | — | **NEW** — a real SSH implementation replaces `_generateMockKeyPair`; belongs in `apps/server/**` per `C-02` |
| 33 | SSH host-key verification | — | **NEW** — **no such code exists anywhere**; mandated by ADR 0018 `:96-99`; see § 9 |
| 34 | Credential injection into the transport | — | **NEW** — `GitWorkspaceInspector._capture` passes no `environment:` |
| 35 | Migration for the private half | **CONDITIONAL — none proposed** | **Amended (`H1`).** "None proposed" holds **only** if the substrate is A1, A3 or A4. If the human supersedes ADR 0018 `:85-88` **and** selects A2, a migration for a separate ciphertext table **is** required. The cell is a conditional, not a settled answer, and is now marked as one |
| 36 | **Store-level key-material immutability guard** | `saveProductCredential` (`postgres_product_registry_store.dart:177-243`); `expectedVersion` pattern exists at `engine:997,1011,1052,1074` | **NEW behaviour, existing function** — `D-1`, § R.15b.1 |
| 37 | **Partial unique index on the active set** | `definition.sql:645-647`; `readActiveCredentialForRepository` (`:257-268`) | **NEW migration, proposed only** — `D-2`, § R.15b.2 (`C-09`: not created) |
| 38 | Typed immutability error | `exceptions.dart:201,215,232` | **NEW** (option (ii) of `D-1` only) |
| 39 | Active-credential read path | `product_registry_store.dart:46-50` | — (its predicate is what fixes the `D-2` index predicate) |

**No parallel credential abstraction is introduced.** #26–#38 are transport, presentation, secret
material and persistence-integrity concerns; the credential *model* is entirely the existing one.

---

## R-5 — The endpoint (`R-5`)

### R.16 `mintOrReadDeployKey`

Placed on the existing `ProductRegistryEndpoints`, which states *"an endpoint never sets state
directly"* — the endpoint delegates to `ControlPlaneService`, which delegates to the engine.

```dart
Future<DeployPublicKeyView> mintOrReadDeployKey(Session session, {
  required String productId,
  required String repositoryId,
})
```

**Semantics — get-or-create:**

1. `readActiveCredential(productId, repositoryId)`.
2. **If a credential exists → return it with `alreadyExisted: true`. Never generate.**
3. Else: derive `host` from `RepositoryReference.uri`; if no host can be derived → refuse, write
   nothing. Generate the keypair; store the private half per **OPEN-D4-1**;
   `recordGeneratedCredential(...)` — **passing no caller-supplied `credentialId`**, so the engine
   generates one (`engine:951-952`). *This is now normative: supplying a `credentialId` is the
   precondition of the overwrite in § R.15.2.*
4. **Concurrency — REWRITTEN (`B2`).** On a **unique-violation of `D-2`**
   (`product_credential_active_repository_unique`), *not* on the engine's one-active exception:
   re-read the active credential for the repository and return **its** public half with
   `alreadyExisted: true`. This is a concurrency resolution, not an error: two simultaneous presses
   must still yield **one** key — and with `D-2` that is a guarantee rather than a hope.
   **Revision 1's version of this step relied on an exception (`engine:940-947`) that will not fire**,
   because `ON CONFLICT` is keyed on `credentialId` and `repositoryId` carries no unique constraint.
5. **Any `CredentialImmutabilityViolationException` from `D-1` is a defect, not a concurrency
   outcome.** It must propagate; it must not be converted into `alreadyExisted: true`.

**`DeployPublicKeyView`** (NEW; `apps/server/lib/src/models/deploy_public_key_view.yaml`) — unchanged
from revision 1, which the review confirmed:

| Field | Type | Note |
|---|---|---|
| `credentialId` | `String` | The handle every later action reuses |
| `publicKey` | `String` | The installable half |
| `fingerprint` | `String` | `SHA256:…` |
| `algorithm` | `String` | `ed25519` |
| `host` | `String?` | Derived from the repository URI |
| `hostKeyStatus` | `String` | `unknown\|confirmed\|changed` |
| `status` | `String` | `generated\|verified\|failing\|revoked` |
| `createdAt` | `DateTime` | |
| `alreadyExisted` | `bool` | The B6 guard, observable by the client |

**There is no field capable of carrying private key material** — not as an omission, as a design
property. `SC-09` makes it testable.

**Error cases:**

| Case | Response | State written |
|---|---|---|
| Unknown product / repository, or cross-product access | `CredentialNotFoundException` / scope error → 4xx | none |
| Host not derivable from `RepositoryReference.uri` | 400 `repositoryUriUnparseable` | none |
| Concurrent mint (`D-2` unique violation) | 200, winner's credential, `alreadyExisted: true` | one row |
| Immutability violation (`D-1`) | 500 typed error — **a defect** | unchanged |
| Substrate unavailable / protection inadequate | **depends on Q2 — `OPEN`** (`B1` 503 + named remediation / `B2` mint + record degradation) | **`OPEN`** |
| `publicKey` containing `PRIVATE KEY` | `CredentialNotUsableException` (`engine:933-939`) | none |

### R.17 `checkRepositoryAccess` — carried forward from revision 1, unchanged

Reads by id; **contains no generation step**. Refuses when `!hostKeyStatus.permitsConnection`
(`N-3`), performs the transport attempt, calls `recordCredentialCheck`, returns
`{ credentialId, status, hostKeyStatus, lastVerifiedAt, lastVerifiedBy, failureKind?, failureReason? }`
per § R.14.

### R.18 Exposure of a credential-minting endpoint — the honest answer, **with a fourth point** (`H4`)

**Today, nothing protects this endpoint from an off-host caller.** Not a weakened control — none of
the controls exist:

- `apps/server/lib/server.dart:71-72` declares **no authentication services** for the control plane.
  `DEC-048f3367` resolved OPTION_C (*"Fix and add authentication"*), but `DEC-570bb640` superseded its
  authentication half: no auth now, accepted risk scoped to local/QA, auth a **blocking production
  precondition**.
- The "local only" premise `DEC-570bb640` relies on is **not enforced**.
  `grep -rn "127.0.0.1:" docker/*.yaml apps/server/docker-compose.yaml` returns **no match**; the
  mappings are unqualified (`docker/compose.qa.yaml:17,56,74` → `5432:5432`, `8080:8080`,
  `8081:8081`), which Docker publishes on `0.0.0.0`. `DEC-570bb640`'s own loopback-pinning follow-up
  is **un-implemented** (a confirmed-unimplemented follow-up to `570bb640`, not a new finding — `L5`).
- So this is not merely theoretical: on any shared network the endpoint is reachable today.

**What this changes relative to every existing endpoint.** The control plane can already be driven
without authentication — create and execute jobs, resolve human decisions (`DEC-048f3367` finding M4).
This endpoint is different in kind in **four** ways, and the revision states so rather than
footnoting it:

1. **It is the first endpoint whose side effect is *persisting secret material*.** Every prior
   unauthenticated call is a governance bypass; this one causes a private key to come into existence.
2. **It is not bounded by an existing record.** Job creation and decision resolution operate on rows
   that must already exist. Minting *creates* one, so an off-host caller can cause unbounded key
   creation across repositories it names — a resource-exhaustion and key-sprawl vector, not just a
   read.
3. **The public half it returns is usable by anyone holding it**, because the design intends it to be
   pasted into `authorized_keys`.
4. **NEW (`H4`) — It is not the only way in, and the direct-database path bypasses it entirely.** An
   off-host caller who reaches **5432** with the **committed default credentials**
   (`docker/compose.yaml:62` → `SERVERPOD_DATABASE_PASSWORD: shipit`;
   `docker/compose.yaml:16-17` publishes `5432:5432` on `0.0.0.0`; `.env.example:16-18` documents
   `POSTGRES_USER=shipit / POSTGRES_PASSWORD=shipit`; `DEC-570bb640` `:34-37` and `:73-75` record
   exactly this) never touches this endpoint at all: it reads and writes `product_credential`
   directly. Auditing the endpoint (§ R.18 mitigations) and constraining the endpoint therefore
   **does not constrain the data**. And under a Q1′-supersession that selects **A2**, that is
   precisely where the sealed key material sits — the fourth path is not a lesser variant of the
   third, it is the one that matters most under that option.

**Consequences this revision accepts, and the mitigations that do not pretend to be authentication:**

- Every mint and every check is **logged and audited** via the existing `AuditEntityType.productCredential`.
- The endpoint refuses to mint when the host cannot be derived, which limits arbitrary target creation
  to syntactically valid SSH remotes.
- **The dependency to record, not to solve:** this endpoint must not ship to any environment where the
  control plane is reachable off-host until either the `DEC-570bb640` loopback pinning lands or API
  authentication lands. That is a **deployment precondition**, owned by the Manager/deployment
  authority.
- **I am not proposing API authentication.** `DEC-570bb640` deferred it deliberately; smuggling a
  cross-cutting auth change in as a side effect of a deploy-key feature is exactly what
  `DEC-048f3367`'s own resolution warned against.
- **The fourth path is out of this revision's authority.** Committing a database superuser password
  and publishing Postgres on `0.0.0.0` are repository-level decisions (`DEC-048f3367` action half,
  `DEC-570bb640` pinning half) that this design neither makes nor claims to mitigate. It is named
  because a design that presents endpoint hardening as its mitigation while a committed credential
  sits two ports away would be misleading.

---

## R-6 — OPEN-D4-2, registration ordering — still `OPEN — HUMAN DECISION REQUIRED AT GATE D4`

### R.19.1 The circular dependency — now also an **ADR contradiction** (`B1`)

Human point 2b requires "Register product" to be **dependent on** key generation and host trust. The
domain requires the opposite order:

```
createProduct(productId, …)            engine:43-61    → state: ProductState.registered  (engine:54)
addRepositoryReference(productId, …)   engine:150-170  → requires the product to exist
recordGeneratedCredential(productId, repositoryId, …)
                                      engine:912-967   → readRepositoryReference (:924) + _ensureOwned (:925)
                                                          ⇒ REQUIRES the repository AND product
confirmHostKey(…)                      engine:974-1013
recordCredentialCheck(…)               engine:1020-1054
```

`recordGeneratedCredential` **cannot** run before the product and repository exist (`engine:924-925`).
So if "Register product" is the act that creates the product and is gated on a credential that
requires the product, the gate is **unsatisfiable** — the same class of defect as the current
`canRegister`.

**Escalation in severity, from re-reading ADR 0018.** `:100-102` is recorded architecture, not a
product request: *"A product cannot be registered until a connectivity check has succeeded against
the real host with the real key."* So OPEN-D4-2 is not merely *which of three orderings* — it is a
**contradiction between a Proposed ADR and the domain's product-ownership requirement**, in which one
side is already written into nine source files and the other into a design that has not shipped.
Revision 1 described this as "circular against the domain". That was true and understated.
Decision object `898b07d0` should be reframed accordingly.

There is no pre-registration `ProductState` to hide in: `createProduct` hardcodes
`ProductState.registered` (`engine:54`), and `registered` is defined as *"Registered in the registry.
No baseline, no governance, no work … Registering is deliberately not governing: a product is visible
here before anything about it has been approved"* (`product_state.dart:24-27`).

### R.19.2 Options — `OPEN`, unchanged from revision 1

| Option | Shape | Consequence |
|---|---|---|
| **1 — Split identity from registration** | The key flow creates the `Product` row (`registered`) + `RepositoryReference` as an explicit first step; "Register product" then commits credential verification. | Satisfies 2a/2b literally and matches `registered`'s existing semantics. **But** leaving the page early leaves a visible product with no usable credential, which sits awkwardly with the human's *"if when down the road we want to create that product"*. Makes § R.12's read path exact. |
| **2 — Decouple the credential from product ownership** | Mint against the repository only; `productId` nullable/pending until the product exists. | Preserves 2a/2b and the addendum's promise most faithfully. **But** breaks `RepositoryCredential.productId`'s non-null invariant and its stated purpose (*"scope enforcement so that knowing a credential id does not bypass the ownership graph"*, `:62-65`) — a contract **and** schema change with real blast radius. **New in revision 2:** it also collides with ADR 0018 A1 (`:19-21`), where `productId` is *retained for ownership checks only* — so option 2 weakens a control the ADR now relies on. |
| **3 — Mint at registration** | Key generation happens inside the register action; the key is copyable afterwards. | Minimal change to the domain; keeps product creation one explicit act; "the key persists" still holds. **But** it rejects human point 2a and point 2b as written, **and** it directly contradicts ADR 0018 `:100-102`, which forbids registration before a successful check. |

**Recommendation**: **Option 1** — unchanged, and now the *only* option consistent with ADR 0018
`:100-102`. Confidence **MEDIUM**: it trades a visible half-registered product against a stricter
reading of `R-H2`, and that trade is a product judgement, not an architecture one.

**Question asked at Gate D4:** unchanged in substance, reframed as an ADR contradiction — *which of
1/2/3 resolves the contradiction between ADR 0018 `:100-102` and `R-2b`, given that minting a
credential requires the product to exist?*

**What is NOT open regardless of the answer:** the endpoint shapes (§ R.16–R.17), the trust state
machine (§ R.9–R.10), the check semantics (§ R.13–R.14), and `D-1`/`D-2` (§ R.15b). All three
options implement them identically; only the trigger moves.

---

## R-7 — Traceability (`R-6`)

### R.21 ADR 0018 exists and has been read — the real gap is `AGENTS.md §13` (**rewritten**)

**Retracted.** Revision 1 § R.21 — *"the document that defines the credential model I am designing
onto does not exist in this repository"* — was **false**, produced by listing `docs/engineering/adr/`
instead of `docs/adr/`. See § 0.1. `G-1` as recorded is **withdrawn**.

**What is read and now governs this design:**

| Ref | Artifact | Read? | What it fixes here |
|---|---|---|---|
| **ADR 0018** | `docs/adr/0018-per-product-git-credentials.md` — 158 lines, status *"Proposed (amended — A1)"* | **Yes, in full** | Q1′ (`:85-88`); host-trust requirement (`:96-99`); registration precondition (`:100-102`); revocation (`:113-114`); scope (`:15-30`); reference-name shape (`:29-30`) |
| **ADR 0012** | `docs/adr/0012-immutable-artifact-promotion.md` — 241 lines, *Accepted (amended — A1)* | Yes | `:34` *"Credentials referenced by name only (AGENTS.md §13 convention)"* — the same convention, cited by an **Accepted** ADR. Write access to product repositories is required by ADR 0012's promotion/result-branch flows, which is why the deploy key needs **write**. |
| **ADR 0015** | `docs/adr/0015-worker-execution-layer.md` — 77 lines, *Accepted* | Yes | The worker layer this credential must be injected into: `:19-22` (worktree pinned to the requested revision), `:29-31` (`WorkspaceDescriptor` written **outside** the worktree), `:55-59` (`EnvironmentPolicy`: allowlisted host variables + non-secret overrides; precedence allowlist → request `environment` → policy `explicit`). **This is the seam ADR 0018 `:67` anticipated** ("injectable at the worker without redesign") and the place `D-1`/`N-8`'s transport obligations land. |
| **ADR 0019** | `docs/adr/0019-standing-policy-authorisations.md` — 122 lines, *Proposed* | Yes | `:49-51` *"Every authorised action cites its policy"* — the audit obligation `AuditEntityType.productCredential` serves. `:121` cites `AGENTS.md §13b`, **also absent** (see below). |
| **ADR 0020** | `docs/adr/0020-defect-domain-model.md` — 178 lines, *ACCEPTED* | Yes | `:137` `EvidenceRedactor` redacts `private_key`/`secret`/`token`/`signing_key` **before** storage — the existing redaction vocabulary a § R.7 audit record should reuse. |
| **ADR 0021** | `docs/adr/0021-design-defect-routing.md` — 179 lines, *ACCEPTED* | Yes | `:86-91` **Hard Rules**: a coding agent must not adjust layout/spacing/flow to fix a design defect; unclear design is a *finding* routed back to design authority. This revision therefore specifies the contrast token (`N-8`) rather than leaving it to an implementer. |
| **ADR 0001/0002/0003** | `docs/engineering/adr/` | Yes | Framework distribution. **They govern nothing in this design.** Retained in the refs list only because the correction began with a directory mistake, and dropping them silently would hide the mistake's source. |

### R.21.1 The real gap — `AGENTS.md` has no §13, so three ADRs' mitigations were never applied

**This replaces `G-1`, and it is materially worse than what revision 1 reported.**

- **`AGENTS.md` has no `§13`.** Verified at `77c19f1`: `AGENTS.md` is **129 lines**; its sections are
  `Inherited invariants` (`:12`), `Orchestration` (`:24`), `Product-specific policy (fill in)`
  (`:58`), `Test resource hygiene` (`:65`), `Framework provenance` (`:123`).
  `grep -n "§13"` → **no match**. It is the un-instantiated framework template: its
  `Product-specific policy` block is `- Required validation gates: TBD`, `- Environments & deployment
  strategy: TBD`, `- Path ownership map: TBD`, `- Orchestration conventions: TBD` (`:59-63`).
- **`§13b` is absent too** — ADR 0019 `:121` cites `AGENTS.md §13b — Where Human Gates Belong`.
- **ADR 0018 depends on a carve-out that does not exist.** `:38-44` quotes §13 as *establishing* the
  platform's credential convention; `:79-80` calls the decision *"a deliberate, scoped deviation from
  AGENTS.md §13 for git credentials only"*; `:126-127` records the Negative *"Deviates from the
  single-secret principle in AGENTS.md §13, so the repository now holds two credential conventions and
  must document which applies where"*; and `:140-141` names the mitigation — *"AGENTS.md §13 gains a
  git-specific carve-out pointing at this ADR, so the two conventions are explicit rather than
  contradictory."* **That mitigation was never applied.**
- **ADR 0012 (Accepted) depends on it too** — `:34` *"Credentials referenced by name only (AGENTS.md
  §13 convention)"* — and ADR 0018 `:152-153` lists it under *Related*.
- **Consequence, stated precisely.** The governing architecture says the platform's credential
  convention is *"one role-scoped service-profile token … never a token per project"*, with
  *"separation comes from role-scoping, never from spreading more secret values"* (ADR 0018 `:40-44`).
  The convention that **four** documents rely on and that **one per-repository** design deliberately
  carves out of is **not written down anywhere in this repository**. A reader of `AGENTS.md` alone
  would find a platform whose credential policy is `TBD`, with 13 source files citing a § that does
  not exist.
- **Who fixes it.** Writing `§13` + `§13b` into `AGENTS.md` is a **governance/architecture change
  outside this lane's `OWNED_PATHS`** (`AGENTS.md` is not a design artifact). It is reported as
  `G-1′` and escalated; **not** written by me. It is also **not** a prerequisite for Gate D3: this
  revision's design content is unaffected by the absence, because ADR 0018 — the substantive document
  — is present and read.

### R.21.2 Assumptions demoted: seven of revision 1's "substitute assumptions" are ADR 0018 decisions

Revision 1 listed ten assumptions in place of an ADR it believed was unreadable, so that a reviewer
could falsify any of them. Having read the ADR, **seven are not assumptions at all** — they are
recorded architecture. Presenting settled architecture as unverified inference is itself a defect.

| # | Revision 1's "assumption" | Actual status | ADR 0018 |
|---|---|---|---|
| 1 | Scope is one repository, not one product | **SETTLED** — not an assumption | A1 `:19-21`, `:84-85` |
| 2 | The private half is referenced by name, never by value | **SETTLED** | `:92-95` |
| 3 | Access is proven, never assumed | **SETTLED** | `:100-102` |
| 4 | Host trust is human, attributable, out-of-band | **SETTLED** | `:96-99` |
| 5 | `changed` fails closed | **SETTLED** (requirement) + code | `:96-99` + `credential_status.dart:49-50` |
| 6 | One active credential per repository; rotate instead | **SETTLED as intent, NOT enforced** — see `G-9` | `:19-21`, `:103-104` |
| 8 | `referenceName` names the operator's local secret store | **SETTLED** — and it is the clause under dispute with `b869ec24` | `:85-88`, `:92-95` |
| 10 | A deploy key is per-repository installable with **write** access | **SETTLED** | `:53-55`, `:57-59`, `:118-119` |
| 7 | Revoked records are retained, never deleted | Remains a code-backed assumption (ADR silent) | — (`:113-114` bears on the *key bytes*) |
| 9 | SHA-256 host-key fingerprinting is the expected format | Remains a code-backed assumption (ADR silent) | — |

Revision 1's reusable instruction — *"invent no ADR content"* — was right and is honoured: nothing
above is inferred. Where the ADR is silent (`#7`, `#9`), the row says so.

### R.21.3 New gap `G-9` — ADR 0018 A1's central invariant is documented but unenforced

ADR 0018 `:19-21` — *"`RepositoryCredential` is keyed by `repositoryId`"* — is **not** a database
constraint. `repositoryId` carries a **non-unique** index (`definition.sql:646`) and the one-active
rule is an application-level read-then-write (`engine:940-941`) with no transaction. § R.15.4 shows
the consequence: two concurrent mints produce two active credentials. `D-2` (§ R.15b.2) is the
remedy. Classified `ARCHITECTURE_DISCOVERY`; reported, not persisted by me.

### R.21.4 `architecture_refs` — repopulated

Revision 1's Brief listed only ADR-0001/0002/0003, the framework-distribution ADRs, which govern
nothing here — so **no design element in revision 1 traced to the architecture it depended on.**
Gate D3's traceability criterion was not met while that stood. The corrected table is in
`design-brief-1.1.0.md` § `architecture_refs` and in `traceability-matrix-2.md` § 4; every § R section
above now names the ADR clauses it rests on.

### R.22 Other recorded gaps

| # | Gap | Why it is a gap | Owner |
|---|---|---|---|
| ~~`G-1`~~ | ~~ADR 0018 / `§13a` absent~~ | **WITHDRAWN — false.** See § 0.1, § R.21. | — |
| `G-1′` | **`AGENTS.md` has no `§13`/`§13b`**, so ADR 0018's carve-out (`:140-141`), ADR 0012's convention (`:34`) and ADR 0019's §13b reference (`:121`) point at text that does not exist; `Product-specific policy` is `TBD` throughout | Governance | **Manager / human** — `AGENTS.md` is outside `OWNED_PATHS` |
| `G-2` | No read-only-over-Docker rule in `AGENTS.md` | A design claim about the runtime could not be verified (§ 9) | Gate D4 item; not blocking |
| `G-3` | No test anywhere imports `add_product_page.dart` (0 of 26 per `DEC-73097d48`) | `SC-02`, `SC-04`, `SC-06` have no existing harness | Implementation / QA Contract |
| `G-4` | No SSH host-key verification exists | `HostKeyStatus` has no runtime enforcer; mandated by ADR 0018 `:96-99` | Implementation (architecture) |
| `G-5` | No read-only public-key endpoint | Fine — mint/get-or-create covers it, but the client cannot re-read a key without holding a `credentialId` | Implementation |
| `G-6` | `recordGeneratedCredential`'s `host` is optional and defaults to `null` | A credential can exist with no host; the design refuses to mint without one (§ R.16) but the domain does not enforce it | Implementation |
| `G-7` | `RepositoryCredentialView` exposes `referenceName` to clients | Under server-side storage that is a **path/ARN disclosure**. Removing it is a generated-contract change in two packages | **`9417f8bf`** (`M4`) — named explicitly; Q4 of OPEN-D4-1 |
| `G-8` | Host fingerprint's provenance unspecified (`ssh-keyscan` vs handshake) | `N-4`'s copy says "the fingerprint the server actually observed"; **how** is part of the new transport seam | Implementation |
| `G-9` | ADR 0018 A1's one-per-repository invariant is **not** a database constraint | § R.15.4; two concurrent mints → two active credentials | Implementation (`D-2`) |
| `L-6` | `docs/engineering/dispatch/DECISIONS.md`'s index table (`:8-12`) **omits `570bb640`**, which appears only in the closing prose | An index that omits a RESOLVED risk-acceptance decision understates what has been accepted | **Manager** — `DECISIONS.md` is outside `OWNED_PATHS`; **reported, not edited** |

---

## 8 — Success criteria changes

Revision 1's `SC-01`–`SC-10` stand. **Three are extended**, and one correction is recorded.

| ID | Change |
|---|---|
| `SC-02` | **Extended (`B2`).** *Generation happens exactly once per credential.* Now also: **T-A** — a `recordGeneratedCredential` call supplying an existing `credentialId` **and** a matching `supersedesCredentialId` **must throw**, and the stored `publicKey`/`fingerprint`/`algorithm`/`referenceName`/`status`/`hostKeyStatus`/`hostConfirmedAt` must be byte-identical afterwards. **This test fails today** (§ R.15.2). |
| `SC-03` | **Extended (`B2`).** *A second mint never silently rotates the key.* The concurrency clause is corrected from "resolves via the engine's one-active rule" — which will not fire — to: **T-B** — two concurrent mints for one `repositoryId` yield **exactly one** row with `status <> 'revoked'`, enforced by `D-2`'s partial unique index. **This test fails today** (§ R.15.4). Requires the Postgres-backed store. |
| `SC-06` | **Extended (`M3`).** *No cancel/reject affordance.* Now also: the trust step's copy is rendered in `palette.inkSecondary`, never `palette.inkTertiary` (`N-8`). |
| `SC-08` | **Re-framed (`B1`/`H2`).** *The at-rest protection model is decided by the human at Gate D4.* The decision must be taken against **ADR 0018 in evidence**, and `79e860e2` must be asked as Q3′ (§ R.6.1), not as an unanswered disposal menu. |
| — | **Withdrawn:** revision 1's § R.3 claim that "no wire-contract break from the field's existence" follows. Whether the wire changes is `Q4`/`G-7`, open, owned by `9417f8bf`. |

---

## 9 — Self-assessment (honest; no gate claimed that was not run)

### `design_system_compliance: PARTIAL` · `ux_accessibility_score: PARTIAL` · `implementation_feasibility: MEDIUM`

Unchanged from revision 1 on all three, and the review accepted each with reasons. What changed:

- **`N-8` is now normative** (`M3`), so the token risk is a requirement rather than a note. The
  boards remain the sibling lane's (`C-11`), so board compliance is still `UNVERIFIED` and
  `design_system_compliance` remains `PARTIAL`.
- **Feasibility, revised for `B2`.** The domain half is still **HIGH** (implemented and covered by 16
  tests in `credential_test.dart`). But the *persistence-integrity* half is now explicitly part of
  the work and is currently **absent**: `D-1` and `D-2` are both unbuilt, and two named tests fail
  today. `D-1` is a single-statement change in an existing function (**MEDIUM**); `D-2` is a migration
  plus one error mapping (**MEDIUM**). Neither raises the revision-level rating, and neither lowers
  it. The **SSH transport seam remains LOW** — nothing exists; `git_workspace_inspector.dart:106-112`
  runs `Process.run(git, args)` with no `environment:`; repo-wide grep for
  `SSH_AUTH_SOCK\|known_hosts\|ssh-keyscan\|StrictHostKeyChecking\|IdentityFile` across `apps` and
  `packages` returns **no match**. ADR 0018 `:96-99` and ADR 0015 `:55-59` make that seam mandatory
  and give it a home, which **raises confidence that it will be built** without raising confidence
  that it will be built *correctly* — it is security-critical, so it needs its own review.
- **Risk level stays 3.** Independent risk level 3 with `RISK_LEVEL_AGREEMENT: YES`, so no
  re-derivation was needed. Revision 2 notes that the reviewer's *independent* ground for 3 —
  *"ADR 0018 A1's one-active-credential-per-repository invariant is not currently enforced by any
  database constraint"* — is now the design's own `D-2`, and that it was correct.

**`MEDIUM`, not `HIGH`:** the domain half is well-evidenced, the transport half is new and
security-critical, and the store half is now specified but unbuilt.

### 9.1 Gates and commands — nothing was run

| Command / check | Status | Note |
|---|---|---|
| `dart analyze` / `flutter analyze` | **NOT_RUN** | Implementation-lane gate; no claim is made about its output |
| Build | **NOT_RUN** | — |
| Test suite (`make test-integration` et al.) | **NOT_RUN** | T-A and T-B are specified and **fail today by inspection**; I did not execute them |
| **Any Docker or Compose command** | **NOT_RUN — none issued** | `AGENTS.md` § Test resource hygiene records that this repository **lost a QA database** to a review lane running `docker compose … down -v`. I ran no `docker`, no `docker compose`, not even read-only (`ps`, `config`, `logs`). |
| Contrast-ratio measurement (`N-8`) | **NOT_RUN** | Ratios are inherited from `design-register-button/report.md:71-76` and were **independently re-measured and confirmed** by the Independent Design Review (`design-review-…/report.md:33`). Not re-measured here. |
| Penpot boards | **NOT_RUN / not authored** | Prohibited for this lane (`C-11`) |
| Read-only source inspection | **pass** | Every `file:line` in this revision was opened and read at `77c19f1` — including the store, the engine, the migration, the ADR set, and `add_product_page.dart` |

### 9.2 `UNVERIFIED` — with the command a human should run

| Claim | Status | What a human should run |
|---|---|---|
| A real SSH transport accepts the generated public key | `UNVERIFIED` | `docker compose -f docker/compose.test.yaml up` (with an explicit `-p`), then install the returned `publicKey` into a scratch repo's `authorized_keys` inside the server container and run a real check |
| A4 (host keychain from a container) is feasible | `UNVERIFIED` | Reachability must be tested on the actual deployment target |
| Host-key `changed` detection against a host presenting a different key | `UNVERIFIED` | Requires such a host |
| `D-2`'s index actually collapses concurrent mints | `UNVERIFIED by execution**; `DESIGNED` from `definition.sql:645-647` | T-B against the Postgres-backed store |
| `D-1`'s `DO UPDATE … WHERE` predicate behaves as specified on this driver | `UNVERIFIED` | T-A against the Postgres-backed store |
| Loopback pinning un-implemented | **VERIFIED (negative)** | `grep -rn "127.0.0.1:" docker/*.yaml apps/server/docker-compose.yaml` → no match |

---

## 10 — Readiness

Ready for **Independent Design Review** of revision 2. **Not approved by its author.**

**Carried forward unchanged and still `OPEN — HUMAN DECISION REQUIRED AT GATE D4`:** the at-rest
protection model (**OPEN-D4-1**, re-framed as **Q1′** — supersession of ADR 0018 `:85-88` — in
§ R.1.1, owned by `9417f8bf`) and the registration-ordering contradiction (**OPEN-D4-2**, now also an
ADR contradiction per § R.19.1, owned by `898b07d0`). **Neither is answered here and neither is
defaulted anywhere in normative text.**

**Manager actions this revision requests** (all outside `OWNED_PATHS`, none performed by me):

1. **Reissue `9417f8bf`** against ADR 0018 with **Q1′** as the question, **A2 marked forbidden by
   ADR 0018 `:85-88`**, and **Q4 / `G-7` (client exposure) folded in** — per `M4`. **Do not present
   it before this revision is reviewed.**
2. **Restate `79e860e2`** as Q3′ (§ R.6.1), not as an unanswered disposal menu.
3. **Reframe `898b07d0`** as an ADR contradiction with `ADR 0018:100-102`, and correct `engine:52` →
   `:54` and `product_state.dart:29-32` → `:24-27` in its context.
4. **Notify `design-addproduct-mobile`** that Design Brief **v1.1.0** supersedes implication #2 of
   v1.0.0 (four `_StepText` entries, not three).
5. **Retract the false ledger facts** in `WORK_STATE.md:484-490` and `LANES.md:204-205`, and correct
   `discoveries.md` **D-6**, whose recorded fact is false. **Correcting D-6 requires the Manager** —
   I have restated it in place and appended the retraction alongside, but the ledger copy is
   Manager-owned.
6. **Add `570bb640` to `DECISIONS.md`'s index table** (`L-6`), and record `AGENTS.md §13`/`§13b`
   (`G-1′`) as a governance action.
