# Design Revision 1 — ADR 0018 amendment A2

**Supersedes the custody and revocation clauses of ADR 0018.**

| Field | Value |
|---|---|
| Task | `design-adr-0018-amendment` |
| Revision number | 1 (first revision of this artifact) |
| Branch | `design/adr-0018-amendment` |
| Base SHA | `6220951` |
| HEAD SHA | `6220951` (no commit made) |
| Worktree | `/private/tmp/shipit-design-adr0018` |
| Artifact under amendment | `docs/adr/0018-per-product-git-credentials.md` |
| Risk level | **3** |
| Status | `DRAFT` — awaiting independent design review and the ADR owner's sign-off |

---

## 0. Scope, ownership, and what this lane is not

### OWNED_PATHS

- `docs/adr/0018-per-product-git-credentials.md`
- `docs/engineering/dispatch/tasks/design-adr-0018-amendment/**`

### READ_ONLY_PATHS

`docs/adr/**`, `.decisions/**`, `apps/server/lib/**`, `packages/platform_contracts/lib/**`,
`packages/product_registry/lib/**`, `docs/engineering/**`

### PROHIBITED_PATHS (touched: none)

Production source under `apps/**` and `packages/**`; `.decisions/**`;
`docs/engineering/WORK_STATE.md`, `docs/engineering/dispatch/LANES.md`,
`docs/engineering/dispatch/DECISIONS.md`; any ADR other than 0018; the
`design-addproduct-*` task directories.

**No commit and no push.** No Docker or Compose command was issued, not even a read-only one;
`docker/compose.yaml` and its siblings were read as text. Every grep cited below is a file read.

### This lane does not approve this amendment

The six decisions that supply the substance were made by the repository owner. What remains is
the ADR owner's sign-off, plus independent review of this revision. I did not write the original
ADR and I am not its approver.

---

## 1. Itemised clause ledger

Line numbers in the "Was" column are the **A1** revision of the ADR (158 lines, status
`Proposed (amended — A1)`), as the brief and the decision objects cite them. The "Now" column
gives line numbers in the **amended** file (465 lines) produced by this revision.

### 1.1 Clauses SUPERSEDED

| # | Clause | Was | Now | Decision |
|---|---|---|---|---|
| S1 | Custody: generation "on the operator's device" and private half "written to the local secret store (macOS Keychain or `~/.config/shipit/platform/` chmod 600)" | `:85-88` | superseded wording retained at `:198-201`, marked `SUPERSEDED (A2) in part` at `:202-207` | `9417f8bf` (`OPTION_C`) + `b869ec24` (`OPTION_A`) |
| S2 | Revocation: "provider-native … sufficient and requires no ShipIt-side action" | `:113-114` | struck through and marked `SUPERSEDED (A2)` at `:261-265` | `79e860e2` (`OPTION_A`) |

**S1 is a partial supersession and is marked as one.** Within `:85-88`, only the custody clause
is superseded. The A1 **scope** clause ("one keypair per repository") and the whole
**prohibition** clause ("never displayed, logged, persisted to the durable record, or
transmitted") survive and are stated as surviving in place. Marking the whole block superseded
would have silently repealed the prohibition that permanently excludes the
envelope-encrypted-table substrate, which is the opposite of what was decided.

### 1.2 Clauses ADDED as replacements

| # | Clause | ADR line | Decision |
|---|---|---|---|
| N1 | Custody is an external secret manager (A3); SHIP IT holds a reference, never key bytes | `:208-214` | `9417f8bf`, `b869ec24` |
| N2 | A1 (filesystem `0600`) / A4 (host keychain) remain the **documented fallback**, selected as a recorded precondition and never defaulted | `:215-217` | `9417f8bf` follow-up action 1 |
| N3 | Envelope-encrypted-table substrate is **permanently excluded**, recorded so it is not re-proposed | `:218-220` | `9417f8bf` resolution (2) |
| N4 | Revocation is **two-sided**: provider-side removal **and** destruction of the secret-manager handle; the credential row is retained | `:266-274` | `79e860e2` |
| N5 | Amendment table row A2, with date, change and reason, in the file's own four-column format | `:16` | all six |
| N6 | The A2 amendment section: decisions recorded, previous/current, effect on intent, effect on presentation, fallback, permanent exclusion, revocation, the upheld registration clause, what survives, and the `27ea6536` check | `:35-143` | all six |
| N7 | Status line extended to name A2's two changes | `:4` | `9417f8bf`, `79e860e2` |
| N8 | Convention sentence generalised to name the superseding amendment, plus a note that cited line numbers refer to the named revision | `:8-11` | this amendment's own convention |

### 1.3 Clauses LEFT STANDING, with a recorded qualification

| # | Clause | Was | Now | Treatment |
|---|---|---|---|---|
| L1 | **Referenced by name, never by value** — the record stores a reference plus fingerprint, never key material | `:92-95` | `:224-227` | **Unchanged wording. Strengthened by A3**, and stated as strengthened in the A2 section. No edit to the clause itself. |
| L2 | The public half is surfaced in the UI; no secret value is ever typed into ShipIt | `:89-91` | `:221-223` | **Unchanged wording.** Verified against `27ea6536` and that decision does not reach it (§3.6). Under A3 the statement becomes literally true rather than conventional. |
| L3 | Host keys are TOFU with explicit human confirmation | `:96-99` | `:228-234` | Clause stands as a **requirement**; annotated in place as *not yet enforced at the transport*, with the precise split recorded (§3.2). |
| L4 | Access is proven, not assumed — no registration without a connectivity check | `:100-102` | `:235-242` | **UPHELD, not superseded** (`898b07d0`). Annotated in place with the fact that it was **unsatisfiable as written**, why, and how the split resolves it. |
| L5 | Amendment A1 in its entirety — scope is the repository, not the product | `:15-33` | `:15`, `:18-33` | **Untouched.** |
| L6 | One keypair per repository | within `:85-88` | `:208`, `:190` | Carried into the A3 clause; scope unchanged. |

### 1.4 New sections

| Section | ADR line | Purpose |
|---|---|---|
| §Invariants enforced elsewhere | `:310-383` | Inventory of what enforces each now-externalised invariant, with verified provenance and explicit `not present at this revision` markers |
| §Preconditions | `:384-406` | Local-only scope unenforced; secret-manager reachability as a blocking runtime dependency; fallback selection |
| §Known gaps | `:407-443` | Resurrection (D-18), missing `AGENTS.md` §13 carve-out, product-scoped rotation wording |
| Related → Decisions governing amendment A2 | `:454-465` | The seven decision ids that authorise this amendment, plus the §13-absence note |

---

## 2. Verification ledger

Every claim written into the ADR was checked against source before being written. `6220951` is
this worktree's HEAD; `07c8c8f` is `fix/credential-store-integrity`; `77c19f1` is
`design-correct-addproduct-keys`.

| # | Claim | Verified at | Evidence |
|---|---|---|---|
| V1 | ADR is 158 lines, status `Proposed (amended — A1)` | `6220951` | Read in full; amendment table at `:11-13`, A1 section at `:15-30` |
| V2 | `:85-88` specifies the local secret store | `6220951` | Read; exact wording quoted |
| V3 | `:113-114` says revocation "requires no ShipIt-side action" | `6220951` | Read; exact wording quoted |
| V4 | `:100-102` requires a connectivity check before registration | `6220951` | Read; annotated, not rewritten |
| V5 | Git transport runs `Process.run` with no `environment:` | `6220951` | `packages/worker_runtime/lib/src/workspace/git_workspace_inspector.dart:107`; `grep -n "environment"` in that file → no match |
| V6 | No SSH enforcement identifier exists anywhere in Dart or SQL | `6220951` | `grep -rniE "SSH_AUTH_SOCK\|known_hosts\|ssh-keyscan\|StrictHostKeyChecking\|IdentityFile" --include="*.dart" --include="*.sql"` → **0** matches |
| V7 | `HostKeyStatus.permitsConnection` **is** called at runtime (brief said it was not) | `6220951` | `product_registry_engine.dart:1033` and `:1148`; `repository_credential.dart:128-129` |
| V8 | Active-credential read paths exclude revoked rows | `6220951` | `postgres_product_registry_store.dart:260-265` (`AND "status" <> 'revoked'`); `in_memory_product_registry_store.dart:190-197`; contract documented at `product_registry_store.dart:46-48` |
| V9 | One-active guard reads through that path, so it cannot see a revoked credential | `6220951` | `product_registry_engine.dart:940-947` |
| V10 | Credential upsert at this revision has **no** `WHERE` and **no** `RETURNING` | `6220951` | `postgres_product_registry_store.dart:237-241`; `$assignments` at `:196-209` overwrites `status`, `revokedAt`, `revokedReason`, `hostKeyStatus`, host confirmation, verification fields |
| V11 | Predicating upsert exists on `07c8c8f` | `07c8c8f` | `postgres_product_registry_store.dart:322-331` (`ON CONFLICT … DO UPDATE SET … WHERE publicKey = … AND fingerprint = … AND algorithm = … AND referenceName = … RETURNING "credentialId"`) |
| V12 | Partial unique index exists on `07c8c8f` in both places | `07c8c8f` | `apps/server/tool/schema_bootstrap.sql:98-100` and `apps/server/migrations/20261006150645000/migration.sql:53-55`, both `WHERE ("status" <> 'revoked')`; drift test asserted at `migration.sql:28` |
| V13 | **Neither** index nor predicating upsert exists at `6220951` | `6220951` | `schema_bootstrap.sql` declares no `product_credential` index (only `design_revision_approved_unique_per_work_item` at `:59`); newest migration is `20261001205247600` |
| V14 | D-18 derivation is at `design-revision-3.md` § R.9.2; the discovery id is registered at `discoveries.md:452` | `77c19f1` | Read both; § R.9.2 begins at line 876 |
| V15 | `credential_test.dart` closes only the check path | `6220951` | `:259` "a revoked credential cannot be re-checked into life"; retention test at `:246` |
| V16 | `referenceName` is serialised to clients in both generated packages | `6220951` | `apps/server/lib/src/generated/repository_credential_view.dart:145` (`toJson`), `:166` (`toJsonForProtocol`); client mirror `packages/control_plane_client/lib/src/protocol/repository_credential_view.dart:144` |
| V17 | Database reachable on all interfaces with a committed default password | `6220951` | `docker/compose.yaml:16-17` = `"5432:5432"` unqualified; `:63` = `SERVERPOD_DATABASE_PASSWORD: shipit`; `.env.example:16-18` |
| V18 | Loopback pinning is un-implemented | `6220951` | `grep "127.0.0.1:" docker/*.yaml apps/server/docker-compose.yaml` → exit 1, no match. All 9 mappings unqualified |
| V19 | `570bb640` accepted local-only and set pinning as a follow-up | `6220951` | `resolution.follow_up_actions[0]` |
| V20 | `AGENTS.md` has **no** §13 | `6220951` | Sections are Inherited invariants / Orchestration / Product-specific policy / Shared Docker state / Test resource hygiene / Framework provenance; product-specific policy still `TBD` |
| V21 | Cite count | `6220951` | `grep -rl "ADR 0018" apps/server/lib packages/*/lib --include="*.dart"` → **15** distinct files, **19** occurrences. The dispatch's own command omits `-r` and returns 0 (§8) |
| V22 | `27ea6536` is a footer-copy/alignment decision | `6220951` | Read in full; no statement about custody, references or key material |

---

## 3. Corrections to the brief's premises

The brief instructed me to verify rather than restate. Five premises did not survive checking.
Each correction is reflected in the artifact.

### 3.1 `HostKeyStatus` does have a runtime enforcer — but not the one that matters

The brief said "`HostKeyStatus` has **no runtime enforcer today**". That is **over-broad**. It
*does* have one, at the domain layer: `recordCredentialCheck` and the pre-push
`requireUsableCredential` both throw `HostKeyNotConfirmedException` unless
`hostKeyStatus.permitsConnection` (V7), and `canReachRepository` requires a confirmed host.

What has **no** enforcer is the **transport**: nothing configures git to verify the host key
(V5, V6), so no `known_hosts` is written and no `StrictHostKeyChecking` is set.

The accurate statement is narrower and more useful: SHIP IT will not *record* trust it does not
have, and will not *hand out* a credential for an unconfirmed host — but the connection itself
is unverified. A blanket "decorative" label would have been false, and would have invited a
reviewer to trust a gate that exists. The ADR records the split.

### 3.2 Both enforcement claims are true on `07c8c8f` and absent at this amendment's base SHA

The brief cited the partial unique index and the predicating upsert as enforcement the ADR should
reference. Both exist at `07c8c8f`. **Neither exists at `6220951`** (V13): the ADR's own base SHA.

The ADR therefore records each with explicit provenance and an `not present at this revision`
marker, and instructs the reader not to cite the index as present until it lands. An ADR that
asserted enforcement absent from its own tree would be worse than one that says nothing.

### 3.3 The resurrection gap is worse at this revision than on `07c8c8f`

The brief described D-18 as derived against `07c8c8f`, where the upsert is predicating — so
resurrection requires identical material. At `6220951` the `DO UPDATE` branch is taken
**unconditionally** with no predicate and no `RETURNING` (V10). Any re-mint naming a revoked
credential's id resurrects it regardless of material, and nothing is returned to detect it.

So D-18 is not only confirmed at this revision, it is live *now* and in a worse form. The ADR
states both forms.

### 3.4 `docker/compose.yaml:63`, not `:62`

An earlier design artifact cites `:62` for the password. The password is at `:63`; `:62` is
`SERVERPOD_DATABASE_USER`. The ADR cites `:63`.

### 3.5 `design-revision-3.md` and D-18 are not on this branch

Both are on `design-correct-addproduct-keys` at `77c19f1`. Grepping the wrong path produced a
false absence first; the artifacts were then located by name across worktrees (V14). Recorded so
a reviewer does not repeat the search.

### 3.6 `27ea6536` does not bear on `:89-91`

The brief flagged that the "no secret value is ever typed into ShipIt" wording "may need its
wording checked against the boards' corrected copy". Read in full, `27ea6536` is solely about the
footer — the `Show technical details` button, dividers, and removal of footer copy on both
platforms. It makes no statement about custody, references or key material (V22).

`:89-91` is therefore **left standing unchanged**, and the ADR says explicitly that it was
checked and does not apply. The genuinely false board copy ("the private half stays in the
keychain") sits inside the superseded `:85-88`, and its correction is already owned by the
Add Product mobile design lane — recorded, not re-verified here, since `apps/control_plane/**`
is outside this lane's read scope.

---

## 4. Risk level

**Level 3 — Major Workflow / Architecture Change** per `DESIGN_GOVERNANCE.md`. Derived here, not
inherited:

1. It amends **recorded architecture** on a security boundary — where a private key capable of
   authorizing repository **write** access is held, and what "revoked" means.
2. It changes a **core workflow** for the operator: revocation now has a ShipIt-side action where
   the ADR said it had none, and a new runtime dependency can block the credential path.
3. It depends on enforcement that **lives elsewhere** and is partly **absent at this revision**
   (§1.4, §3.2). An ADR whose guarantees rest on invariants it does not itself hold is not a
   component-level change.
4. It records three open gaps (resurrection, missing §13 carve-out, unenforced host-key
   verification) rather than closing them, so accepting it accepts a knowingly-incomplete
   security posture.

Level 3 requires product/design/architecture approval. That approval is the repository owner's,
as ADR owner. The substance is already pre-decided by the six resolved decisions; what needs the
human is the sign-off on the ADR as a whole, and a judgement on whether to accept the recorded
gaps or gate them first.

---

## 5. Traceability

### Requirements covered

| Requirement | Source | Where satisfied |
|---|---|---|
| Record A2 in the existing amendment-table format | `ACCEPTANCE_CRITERIA` | `:16` |
| Supersede `:85-88` in place, old wording retained and marked | `9417f8bf` follow-up 1 | `:207-220`, S1/N1/N2/N3 |
| Supersede `:113-114` in place, same treatment | `79e860e2` follow-up 1 | `:261-274`, S2/N4 |
| Leave `:100-102` and A1 standing; record unsatisfiability and the resolution | `898b07d0` | `:235-242`, L4, §Amendments A2 |
| Every superseded clause's replacement traceable to a decision object | `ACCEPTANCE_CRITERIA` | `:40-52` (decision table) and per-clause attribution |
| Preserve "never persisted to the durable record"; record A2's permanent exclusion | `9417f8bf` resolution (2) | `:218-220`, N3 |
| Record that "referenced by name, never by value" is strengthened, not weakened | brief §5 | `:224-227`, L1 |
| Record invariants the ADR now depends on elsewhere | `ACCEPTANCE_CRITERIA` | §Invariants enforced elsewhere |
| Record "local only" and A3 availability as preconditions | `570bb640`, `9417f8bf` | §Preconditions |
| Record the resurrection finding | D-18 | §Known gaps |
| Record the reference as the most sensitive artifact held | `9417f8bf` gap G-7 | `:250-259`, §Invariants enforced elsewhere |
| Record the six resolved decisions with their ids | `ACCEPTANCE_CRITERIA` | `:40-52`, Related |
| State what the status line should become and why | brief | `:4` |

### Requirements gaps

| Gap | Why it is not closed here |
|---|---|
| Status remains `Proposed`, not `Accepted` | Only the ADR owner may declare an ADR accepted. This lane proposes the wording and the reason; it does not grant the authority. |
| Host-key verification at the transport is specified, not built | Implementation. Security-critical enough to warrant its own review once built. |
| The one-active index and the predicating upsert are absent at this revision | Implementation, already implemented and independently reviewed on `07c8c8f` and awaiting integration. |
| Resurrection (D-18) is recorded, not closed | Requires a mint path that can never write to an existing `credentialId`; production code is prohibited to this lane. |
| `referenceName` still exposed to clients | Generated-contract change in two packages; required by `9417f8bf` follow-up 2. |
| `AGENTS.md` §13 carve-out does not exist | `AGENTS.md` is outside this lane's owned paths. |
| Boards' "stays in the keychain" copy not corrected here | Owned by the Add Product mobile lane; `apps/control_plane/**` outside this lane's read scope. |
| A3 reachability never runtime-probed | `9417f8bf` records confidence LOW and states no option was runtime-verified. No Docker command was run under the no-Docker rule. |

---

## 6. Design-system compliance, UX/accessibility, feasibility

- **DESIGN_SYSTEM_COMPLIANCE: PASS** — with a scope caveat stated rather than assumed. This
  revision changes no board, no token, no component and no layout. Its only UI-facing consequence
  is copy that must not assert device-local key custody; the existing tokens and the per-platform
  footer pattern are untouched.
- **UX_ACCESSIBILITY_SCORE: PASS (for what this revision changes), with a gap handed on.**
  `:89-91` is unchanged and remains screen-reader-safe. Nothing here removes a label, a focus
  target, or a confirmation affordance; the two-sided revocation adds no new user-facing surface.
  **Not assessed and not claimed:** the board-copy corrections owned by the mobile lane, and the
  remediation copy for secret-manager unavailability, which `9417f8bf` follow-up 3 assigns to a
  design lane and which this amendment records as a precondition rather than specifying.
- **IMPLEMENTATION_FEASIBILITY: MEDIUM.** The amendment itself is documentation and is complete.
  Feasibility of the *architecture it records* is MEDIUM and was never higher: `9417f8bf` records
  confidence **LOW** and states plainly that no substrate option was runtime-verified, and A3
  adds a runtime dependency whose availability now gates the credential path. The fallback is
  documented, which is what keeps this MEDIUM rather than LOW.

---

## 7. Discoveries

| id | Category | Finding | Disposition |
|---|---|---|---|
| ADR-0018-A2-D1 | `CONTRADICTION` | `AGENTS.md` §13 does not exist, so this ADR's own §Mitigation carve-out, its §Related entry, and ADR 0012 and ADR 0019's citations all point at absent text. The documented §13-vs-0018 contradiction is unreconciled. | Recorded in §Known gaps. Touches governance → **routed to the human**, per `LEARNING_POLICY.md`. |
| ADR-0018-A2-D2 | `PROJECT_FACT` | The credential upsert at `6220951` is an unpredicated `DO UPDATE SET $assignments` with no `RETURNING`, and it can overwrite `status`, `revokedAt`, `revokedReason` and host-trust fields. | Recorded in §Invariants enforced elsewhere and §Known gaps. Evidence-backed; within automatic authority. |
| ADR-0018-A2-D3 | `PROJECT_FACT` | `HostKeyStatus` has a **domain** enforcer and **no transport** enforcer. | Recorded precisely. Corrects an over-broad claim that had entered the design record. |
| ADR-0018-A2-D4 | `ARCHITECTURE_DISCOVERY` | Resurrection (D-18) is live at `6220951` and worse than on `07c8c8f`. | Already carried as D-18 by the keyservice lane. Re-verified independently here; not re-registered, to avoid a duplicate id. |

---

## 8. Validation

Run in `/private/tmp/shipit-design-adr0018`. No Docker or Compose command was issued.

| Command | Result |
|---|---|
| `git branch --show-current` | `design/adr-0018-amendment` — PASS |
| `git rev-parse --short HEAD` | `6220951` — PASS |
| `sed -n '1,40p' docs/adr/0018-per-product-git-credentials.md` | Amendment table at `:13-16` with both A1 and A2 rows in the file's own format — PASS |
| `grep -n "ADR 0018" apps/server/lib packages/*/lib --include="*.dart" \| wc -l` | **0 — the command is malformed**; see below. Corrected form with `-r` added returns **19** across **15** distinct files |

**The cite-count validation command in the dispatch does not work, and this is reported rather
than quietly repaired.** The command omits `-r`, so `grep` is handed two **directories** and no
files: it recurses into nothing and returns 0 regardless of what the repository contains. Read
naively, "0 citations" would say ADR 0018 is uncited — the opposite of the truth. Adding `-r`
gives 19 occurrences across 15 distinct production Dart files (`apps/server/lib` 4 files,
`packages/**/lib` 11 files), listed in §7's CITE COUNT entry.

This is the same failure class the dispatch itself warns about — a false "artifact absent"
conclusion produced by grepping the wrong thing — except here it is baked into the dispatch's own
validation command. Worth fixing at the dispatch level, since any lane that runs it verbatim gets
a meaningless green.

**NOT RUN** — and not claimed: `dart analyze`, `dart format`, `dart test`, and any integration or
visual gate. No production code changed, so no code gate applies; but none was run and none is
claimed. No Markdown linter is configured in this repository and none was run.

---

## 9. Blockers

None for this revision. Two items require the human, neither of which blocks independent review:

1. **Status-line authority.** This revision proposes the status wording and the reasoning; it
   cannot declare the ADR `Accepted`. The ADR owner signs it off.
2. **Acceptance of the recorded gaps.** Resurrection, absent host-key verification at the
   transport, the unenforced local-only scope, and the missing §13 carve-out are recorded as open.
   Whether to accept them alongside A2 or gate A2 behind them is a human judgement, and this
   revision deliberately does not make it.

## 10. Handover

`READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES`. A reviewer should check, in order: the partial
supersession at `:207-220` (whether the surviving prohibition is correctly preserved rather than
repealed); the provenance markers in §Invariants enforced elsewhere (whether `07c8c8f`-only
enforcement is correctly distinguished from what exists at `6220951`); the D-18 restatement in
§Known gaps against the code; and the §3 corrections against the brief, since each one contradicts
something the reviewer may have been told.