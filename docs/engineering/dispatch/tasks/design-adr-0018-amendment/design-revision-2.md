# Design Revision 2 — ADR 0018 amendment A2: record the owner's acceptance

**Supersedes Design Revision 1 of this artifact.** Revision 2 records the human's acceptance of
A2, converts the four knowingly-open gaps from blockers into recorded accepted risks, and
re-verifies every claim against `main` at `43d328b`.

| Field | Value |
|---|---|
| Task | `design-adr-0018-amendment` |
| Revision number | 2 |
| Supersedes | `ADR0018-A2-REV1` (`design-revision.md`, `design-revision-metadata.yaml`) |
| Branch | `design/adr-0018-amendment` |
| Base SHA | `43d328b` (re-based from `6220951`) |
| HEAD SHA | `43d328b` (no commit made) |
| Worktree | `/private/tmp/shipit-design-adr0018` |
| Artifact under amendment | `docs/adr/0018-per-product-git-credentials.md` |
| Risk level | **3** (unchanged) |
| Status | **`ACCEPTED`** — owner accepted. **Never independently reviewed** |

---

## 0. Scope, ownership, and what this lane is not

### OWNED_PATHS

- `docs/adr/0018-per-product-git-credentials.md`
- `docs/engineering/dispatch/tasks/design-adr-0018-amendment/**`

### READ_ONLY_PATHS

`docs/adr/**`, `.decisions/**`, `apps/server/lib/**`, `packages/platform_contracts/lib/**`,
`packages/product_registry/lib/**`, `docs/engineering/**`

### PROHIBITED_PATHS (written: none)

Production source under `apps/**` and `packages/**`; `.decisions/**`;
`docs/engineering/WORK_STATE.md`, `docs/engineering/dispatch/LANES.md`,
`docs/engineering/dispatch/DECISIONS.md`; any ADR other than 0018; the
`design-addproduct-*` task directories.

**No commit and no push.** **No Docker or Compose command was issued, not even a read-only
one** — `AGENTS.md` binds every lane without deployment authority. `docker/compose.yaml` and its
siblings were read as text. Every grep cited below is a file read.

### Re-base

The worktree was re-based from `6220951` to `43d328b` before any write:
`git stash push -u` → `git rebase main` → `git stash pop`. `6220951` is a clean ancestor of
`43d328b` and this branch carried no commits of its own, so the re-base was a fast-forward with no
conflicts. `docs/adr/0018-per-product-git-credentials.md` **did not change on `main` between
`6220951` and `43d328b`** (`git log 6220951..main -- docs/adr/0018-…` → empty;
`git diff 6220951 main -- docs/adr/0018-…` → empty), so the amendment text survived the re-base
unchanged and only the *evidence behind it* needed re-verification.

### This lane still does not approve its own work

The acceptance recorded here is **the ADR owner's**, granted through the structured question UI
and relayed by the Manager. **Independent design review of this artifact has never happened and
is the next gate.** `reviewed_by` and `reviewed_at` remain `null`. I authored amendment A2; I am
not its reviewer.

### Disclosure: one out-of-scope read

While re-verifying the board-copy claim at ADR `:95-103`, I read
`apps/control_plane/lib/features/products/add_product_page.dart`. **`apps/control_plane/**` is
not in this dispatch's `READ_ONLY_PATHS`.** It was a read, not a write; nothing was modified. I am
disclosing it rather than relying on it silently, and — more importantly — **I have not used it as
evidence in the ADR.** The ADR's existing statement that this lane does not re-verify that
reference stands, because an out-of-scope read is not a lane-verified claim. See §7, finding F-2,
for why the observation still matters to another lane.

---

## 1. What revision 2 changes, itemised

### 1.1 Approval fields in `design-revision-metadata-2.yaml`

| Field | Revision 1 | Revision 2 | Why |
|---|---|---|---|
| `status` | `DRAFT` | `ACCEPTED` | The owner accepted. |
| `approved_by` | `null` | `"repository owner (ADR owner, interactive structured question UI, session orchestrator-main)"` | The acceptance has an owner. |
| `approved_at` | `null` | `"2026-10-06"` | The acceptance has a date. |
| `reviewed_by` | `null` | **`null` (unchanged)** | Independent review has not happened. |
| `reviewed_at` | `null` | **`null` (unchanged)** | Same. |
| `human_gate.required` | `true` | `false` | The gate was answered. |
| `human_gate.level` | `3` | `3` (retained) | The risk level is a property of the change, not of whether a human was asked. |
| `human_gate.blocking_items` | 2 items, both "status/§13" | **`[]`** | Both were answered; see §1.4. |
| `acceptance_is_not_review` | — (field did not exist) | `true` + statement | Prevents the exact drift this dispatch exists to correct. |
| `base_sha` / `head_sha` | `6220951` | `43d328b` | Re-based. |

### 1.2 ADR Status line and acceptance block

| # | Change | ADR lines |
|---|---|---|
| C1 | Status line `Proposed` → **`Accepted`**, keeping the file's own parenthesised convention and both amendments' scope/custody summaries | `:4` |
| C2 | New acceptance block: who accepted, the recorded answer verbatim, what the acceptance covers, what it is **not**, and the authority note | `:6-21` |
| C3 | `§Related` AGENTS.md §13 entry rewritten — the section **exists**; the "does not exist" note retired | `:546-549` |
| C4 | New `### The acceptance itself` recording that **no `.decisions/` object exists** for the acceptance, and why | `:572-580` |

### 1.3 Two stale absence markers corrected (the dispatch's item 4)

Revision 1's §Invariants enforced elsewhere carried two markers reading *"not present at this
revision"*. Both were **true at `6220951` and false at `43d328b`**, because `e391c02` merged the
credential-store work. A stale absence in a frozen ADR is an error, so both are corrected and the
correction is dated rather than made silently.

| # | Was (revision 1, written at `6220951`) | Now (re-verified at `43d328b`) | ADR lines |
|---|---|---|---|
| C5 | "Database guard, **not present at this revision** … Do not cite the index as present until it lands." | Index **is** present at `43d328b`, in both `schema_bootstrap.sql:98-100` and `20261006150645000/migration.sql:53-55`, asserted equal by `verify_schema_bootstrap.sh:91`. Plus a new paragraph on what the index does and does not do (§4.1). | `:342-359` |
| C6 | "**At the revision this amendment is written against, that guard does not exist**: `postgres_product_registry_store.dart:237-241` is a bare `ON CONFLICT … DO UPDATE SET $assignments` with no `WHERE` and no `RETURNING`" | Predicating upsert **is** present at `43d328b` at `apps/server/lib/src/persistence/postgres_product_registry_store.dart:322-331`, with the unique-constraint translation at `:332-347`. Added the explicit boundary that immutability ≠ closing the resurrection gap. | `:361-378` |
| C7 | Section lead-in said "as verified against source at the revision this amendment was written on" | Names `43d328b` explicitly, and a dated blockquote records that the section was first written against `6220951` and why the markers changed | `:334-340` |

### 1.4 Discovery `ADR-0018-A2-D1` re-verified and **closed** (dispatch item 4, second bullet)

Revision 1 recorded as a `CONTRADICTION` and escalated to the human that `AGENTS.md` §13 did not
exist. `0bf2fa0` restored it. Re-verified at `43d328b`:

| # | Change | ADR lines |
|---|---|---|
| C8 | §Known gaps item "The `AGENTS.md` §13 carve-out this ADR relies on does not exist" replaced by "**now exists — this gap is CLOSED as of `0bf2fa0`**", citing `AGENTS.md:65`, `:72`, `:78`, `:91`, `:96-101` | `:530-537` |
| C9 | Revision 1's blocking item `ADR-0018-A2-D1` removed from `human_gate.blocking_items` — it is resolved, not answered | metadata |
| C10 | §Accepted risks does **not** contain a §13 entry. The four accepted risks are exactly the four the owner was asked about. | `:446-523` |

### 1.5 The four blockers converted to accepted risks (dispatch item 3)

Revision 1 listed these as open blockers. Revision 2 records each as an **accepted risk** with its
verified state and **the consequence that was accepted**, in a new `## Accepted risks` section.

| Risk | Statement | ADR lines | State change |
|---|---|---|---|
| **A1** | A revoked credential can be resurrected by a re-mint | `:453-481` | **blocker → accepted risk** |
| **A2** | Host-key verification has a domain enforcer and no transport enforcer, while ADR `:96-99` requires one | `:482-497` | **blocker → accepted risk** |
| **A3** | The "local only" scope is unenforced (`docker/compose.yaml:16-17` publishes `5432:5432` unqualified) | `:498-510` | **precondition → accepted risk** |
| **A4** | The external secret manager's reachability has never been runtime-probed | `:511-524` | **precondition → accepted risk** |

Two cross-references were updated so a reader cannot reach a "known gap" label for something the
owner accepted: `:125-128` (the §Amendments A2 revocation caveat) and `:291-293` (the §Decision
revocation clause) now say *accepted risk A1*, and `:250-252` (the host-key clause) now cites
§Accepted risks A2.

### 1.6 Not amended

Per the dispatch: **A2's substance was not amended.** The custody clause, the two-sided revocation
clause, the fallback precondition, the permanent exclusion of the envelope-encrypted-table
substrate, the upheld registration clause, and amendment A1 are all untouched. Every §1.2–§1.5
change is a status record, a provenance correction, or a gap re-classification.

---

## 2. What acceptance is, in the artifact's own fields

Recorded in `design-revision-metadata-2.yaml` and mirrored in the ADR at `:6-21`:

- **`status: ACCEPTED`** — the ADR owner accepted A2 and its four gaps.
- **`approved_by`** / **`approved_at`** — the owner, via the structured question UI, on 2026-10-06.
- **`reviewed_by: null` / `reviewed_at: null`** — untouched, deliberately.
- **`acceptance_is_not_review: true`**, with this statement: *Acceptance is the ADR owner's
  authority over the design. Review is an independent agent's judgement of the artifact. This
  artifact has been accepted and has never been reviewed; the two must not be conflated, and a
  downstream artifact must not treat acceptance as review.*

That last field exists because of a specific observed failure: a sibling design revision that read
revision 1 asserted in thirteen-plus places that the amendment was "Accepted" while revision 1 said
`status: DRAFT`, `approved_by: null`, and carried a blocking item reading "ADR 0018 status remains
Proposed. This lane does not declare it Accepted." The acceptance is now on disk in both the
metadata and the ADR, so the assertion is true — and the distinction from review is recorded next
to it, so the same drift cannot recur by a different route.

---

## 3. Re-verification ledger at `43d328b`

Every claim below was checked against `main` at `43d328b` before being written. `NOT_RUN` is stated
where nothing was run.

| # | Claim | Verified at | Evidence |
|---|---|---|---|
| R1 | ADR 0018 unchanged on `main` since `6220951` | `43d328b` | `git log 6220951..main -- docs/adr/0018-…` → empty; `git diff 6220951 main -- docs/adr/0018-…` → empty |
| R2 | Partial unique index present, bootstrap | `43d328b` | `apps/server/tool/schema_bootstrap.sql:98-100`; `WHERE ("status" <> 'revoked')` |
| R3 | Partial unique index present, chain migration | `43d328b` | `apps/server/migrations/20261006150645000/migration.sql:53-55`; `20261006150645000` is now the newest migration (was `20261001205247600`) |
| R4 | The two index copies are asserted equal | `43d328b` | `apps/server/tool/verify_schema_bootstrap.sh:91` — `index:product_credential_active_repository_unique` |
| R5 | Predicating upsert present | `43d328b` | `apps/server/lib/src/persistence/postgres_product_registry_store.dart:322-331`; comment `:306-310`; empty-result → exception `:348-350`; unique-violation translation `:332-347` |
| R6 | The engine documents the store-side enforcement boundary | `43d328b` | `product_registry_engine.dart:907-915` — "`[credentialId]` must be a NEW identity"; "only the write can be atomic" |
| R7 | **A1 open**: both active read paths still exclude revoked rows | `43d328b` | `postgres_product_registry_store.dart:373-378`; `in_memory_product_registry_store.dart:224-227` |
| R8 | **A1 open**: one-active guard therefore cannot fire after revocation | `43d328b` | `product_registry_engine.dart:954-960` |
| R9 | **A1 open**: `recordGeneratedCredential` has no existing-credential status check | `43d328b` | `product_registry_engine.dart:926-981` — parameter list `:926-936`, guard `:940-961`, write `:979` |
| R10 | `rotateCredential` revokes then mints a new id | `43d328b` | `product_registry_engine.dart:1116-1132` |
| R11 | Existing coverage closes only the check path | `43d328b` | `packages/product_registry/test/credential_test.dart:323` "a revoked credential cannot be re-checked into life"; retention test `:310` |
| R12 | The resurrection fix is **not merged** | `43d328b` | `docs/engineering/WORK_STATE.md:342-346` — `fix/credential-identity-invariants`, `APPROVE_WITH_NON_BLOCKING_FOLLOWUP`, **uncommitted**; branch tip `0bf2fa0` is an ancestor of `main` and does not contain the fix |
| R13 | **D-3 re-verified**: domain enforcers exist, at **+14 lines**, and there are **three** | `43d328b` | `product_registry_engine.dart:1047-1052` (`recordCredentialCheck`), `:1162-1167` (`requireUsableCredential`), `:1012-1015` (changed fingerprint). At `6220951` these were `:1033`, `:1148`, `:998` — a uniform **+14**, confirming the sibling lane's reported offset rather than assuming it |
| R14 | `canReachRepository` requires both halves | `43d328b` | `packages/platform_contracts/lib/src/types/repository_credential.dart:128-129` (unchanged) |
| R15 | **A2 open**: transport still has no enforcer | `43d328b` | `packages/worker_runtime/lib/src/workspace/git_workspace_inspector.dart:107` — `Process.run(git, args)`, no `environment:`; repo-wide `grep -rniE "SSH_AUTH_SOCK\|known_hosts\|ssh-keyscan\|StrictHostKeyChecking\|IdentityFile" --include="*.dart" --include="*.sql" apps packages` → **exit 1, 0 matches** |
| R16 | The clause requiring a transport enforcer is `:96-99` | `43d328b` | `git show 6220951:docs/adr/0018-…` `:96-99` — host keys are TOFU with human confirmation |
| R17 | **A3 open**: `5432:5432` unqualified | `43d328b` | `docker/compose.yaml:16-17`. **Read as text** — no Docker or Compose command was issued |
| R18 | `:62` is the user line, `:63` the password | `43d328b` | `docker/compose.yaml:62` `SERVERPOD_DATABASE_USER`, `:63` `SERVERPOD_DATABASE_PASSWORD: shipit`. Revision 1's correction 4 holds |
| R19 | **A3 open**: loopback pinning still absent, all nine mappings unqualified | `43d328b` | `grep -n "127.0.0.1:" docker/*.yaml apps/server/docker-compose.yaml` → exit 1. Mappings: `compose.yaml:17,71,86`, `compose.qa.yaml:17,56,74`, `compose.test.yaml:16,103,121` |
| R20 | Default password documented | `43d328b` | `.env.example:16-18` |
| R21 | **A4 open**: no substrate adapter exists, so nothing could have been probed | `43d328b` | `grep -rniE "secretmanager\|secret_manager\|vault\|substrate" --include="*.dart" apps/server/lib packages/*/lib` → 0 matches; `9417f8bf:133,149` records confidence LOW and that no option was runtime-verified |
| R22 | `referenceName` still serialised to clients | `43d328b` | `apps/server/lib/src/generated/repository_credential_view.dart:145`, `:166`; `packages/control_plane_client/lib/src/protocol/repository_credential_view.dart:144` (unchanged) |
| R23 | **`AGENTS.md` §13/§13a/§13b exist** | `43d328b` | `AGENTS.md:65` `### §13 Credentials`, `:72` `#### §13a`, `:78` `#### §13b`; `:91` "one SSH deploy keypair per repository"; `:96-101` records the restoration and names ADR 0018, 0012, 0019 as the dependents |
| R24 | The Manager has independently recorded the acceptance | `43d328b` | `docs/engineering/WORK_STATE.md:326-327` — "the human has accepted it with four gaps recorded as accepted" |
| R25 | **No decision object records the A2 acceptance** | `43d328b` | All 14 files in `.decisions/` inspected; `ae1c1f79` (the newest) is about the substrate precondition, not A2 acceptance; `grep -rniE "accept a2\|amendment a2\|a2 acceptance\|record the gaps" .decisions/` → 0 matches |
| R26 | `NOT_RUN` — Docker / Compose | — | No Docker or Compose command of any kind, per `AGENTS.md` |
| R27 | `NOT_RUN` — code gates | — | `dart analyze`, `dart format`, `dart test`, integration, visual: none run, none claimed. No production code changed |
| R28 | `NOT_RUN` — independent design review | — | Has never happened. Not claimed, not implied by acceptance |

---

## 4. Corrections to revision 1 found during re-verification

### 4.1 The partial unique index does **not** refuse a legitimate fresh mint

Revision 1 (ADR §Known gaps, `:425` at the time) claimed the index "then **refuses the legitimate
fresh mint** for that repository." **That is wrong**, and it was wrong in the direction of
over-claiming the index's protection.

`rotateCredential` (`product_registry_engine.dart:1116-1132`) revokes **first** and mints second.
After the revocation the superseded row satisfies `WHERE ("status" <> 'revoked')` = false, so it is
excluded from the index, and the replacement is then the **only** non-revoked row for that
repository. No index constraint is violated. What the index actually refuses is a **second**
non-revoked row for one repository — the race in which two callers both pass the domain read
(`:954-960`) before either writes. ADR `:352-359` now states both halves of this.

This correction matters to the resurrection risk rather than to it being decorative: A1 is *not*
closed by the index, and the corrected sentence makes the reason plain — a resurrected row is the
repository's only non-revoked row, so nothing trips.

### 4.2 Immutability makes the upsert *predicated*, not *unreachable*

Revision 1 asserted resurrection "remains reachable, because identical material is exactly what a
re-mint after revocation would supply" — correct, but stated only for the `07c8c8f` branch and
without separating the two properties. Revision 2 states the boundary explicitly at ADR `:374-378`:
the predicating `WHERE` prevents a *material change*; it does not prevent an *identical-material*
write from taking the branch. A reader who saw "immutable key material" and "resurrection still
possible" as a contradiction now has the reason they are not.

### 4.3 The `HostKeyStatus` enforcers are three, not two

Revision 1 cited two sites. At `43d328b` there are three: `product_registry_engine.dart:1012-1015`
throws `HostKeyNotConfirmedException` when a **changed** host fingerprint is presented, recording
the change first so the operator must resolve it. This site existed at `6220951` too (`:998`), so
this is a completeness correction rather than new code. ADR `:382-400` now records all three and
the `+14` shift, and drops the `07c8c8f`-only framing.

### 4.4 Store path corrected

Revision 1 cited `postgres_product_registry_store.dart:237-241` and `:322-331` without the
directory, which is how a reader could have looked in the wrong place. Revision 2 gives the full
path `apps/server/lib/src/persistence/…` in every citation.

---

## 5. Risk level

**Level 3 — Major Workflow / Architecture Change**, unchanged from revision 1. Acceptance did not
lower it: the level describes the change, not whether a human has blessed it.

1. It amends **recorded architecture on a security boundary** — where a private key capable of
   authorising repository **write** access is held, and what "revoked" means.
2. It changes a **core workflow**: revocation acquires a ShipIt-side action where the ADR said none
   was required, and a new runtime dependency can block the credential path.
3. It depends on enforcement that **lives elsewhere**. That dependence is now *better* than at
   `6220951` — the index and the predicating upsert are merged — and *still partly absent* at the
   transport (§Accepted risks A2).
4. It now carries **four accepted risks** on a security boundary, each with its consequence
   recorded (`:446-524`).

Level 3's approval requirement was satisfied on 2026-10-06 by the repository owner as ADR owner.
**That satisfies the human gate. It does not satisfy independent review.**

---

## 6. Traceability

### Requirements covered

| Requirement (this dispatch) | Where satisfied |
|---|---|
| Re-base onto `main` before producing the update | §0 Re-base; `VALIDATION_COMMANDS` §9 |
| Set `status` to reflect human acceptance | metadata `status: ACCEPTED`; ADR `:4` |
| Populate `approved_by` and `approved_at` | metadata; ADR `:6-7` |
| **Leave `reviewed_by` / `reviewed_at` null** | metadata — unchanged at `null`; ADR `:12-15`; §2 |
| **State plainly that acceptance is not review** | ADR `:12-15`; metadata `acceptance_is_not_review`; §2 |
| ADR Status line → Accepted, following the file's convention | ADR `:4` — `Accepted (amended — …)`, same parenthesised shape as the A1/A2 convention |
| Convert the four gaps to recorded accepted risks, each with consequence | ADR `:446-524` — A1 `:453-481`, A2 `:482-497`, A3 `:498-510`, A4 `:511-524` |
| Verify each gap against `main` before recording it as accepted | §3 R7–R21; per-risk "Verified at `43d328b`" lines in the ADR |
| Correct the stale "not present at this revision" markers for the merged `e391c02` objects | §1.3 C5, C6, C7; ADR `:336-378` |
| Re-verify and update the §13 discovery `ADR-0018-A2-D1` | §1.4 C8–C10; ADR `:530-537`; R23 |
| Re-verify D-3 at `main`, checking rather than assuming the `+14` offset | §1.3/§4.3; R13 — offset confirmed as uniform `+14` |
| Do not amend A2 further | §1.6; `git diff` shows no change to any A2 clause |
| Report a substantive new problem rather than revising A2 | §7 F-1, F-3 — reported, not silently fixed |
| Cite `file:line` verified at `43d328b` | §3, and every `file:line` in the ADR |

### Requirements gaps

| Gap | Why not closed here | Owner |
|---|---|---|
| Independent design review of this artifact | Has never happened; this lane cannot perform or substitute for it | Independent design reviewer |
| No `.decisions/` object records the acceptance | `.decisions/**` is PROHIBITED to this lane; every existing object is `created_by: orchestrator-main` | **Manager** |
| A1 resurrection still reachable | Needs a mint path that can never write an existing `credentialId`; a fix is reviewed but **uncommitted** (R12) | Implementation |
| A2 transport host-key verification absent | Specified, not built; security-critical enough for its own review | Implementation |
| A3 loopback pinning absent | `docker/**` is outside this lane's ownership entirely | Implementation |
| A4 substrate reachability unprobed | No adapter exists (R21) and **no Docker command may be issued** by this lane | Implementer, per `9417f8bf` follow-up 4 |
| `referenceName` still on the client wire (G-7) | Generated-contract change in two packages | Implementation |
| Board copy still asserts device-local custody | Owned by the Add Product mobile lane; `apps/control_plane/**` outside read scope | Design (existing lane) |
| `docs/engineering/WORK_STATE.md:347` still reads "awaiting independent review" without the acceptance | PROHIBITED to this lane; and `:326-327` already records the acceptance, so this is a second line to align | Manager |

---

## 7. Design-system compliance, UX/accessibility, feasibility

- **DESIGN_SYSTEM_COMPLIANCE: PASS.** Unchanged from revision 1 and unchanged by revision 2. No
  board, token, component or layout is touched. The only UI-facing consequence remains copy that
  must not assert device-local key custody. The board-copy corrections owned by the mobile lane are
  **not assessed here**.
- **UX_ACCESSIBILITY_SCORE: PASS (for what this revision changes).** `:89-91` is unchanged and
  remains screen-reader-safe. Nothing here removes a label, a focus target or a confirmation
  affordance, and two-sided revocation adds no new user-facing surface. **Not assessed and not
  claimed:** the mobile lane's board-copy corrections, and the remediation copy for
  secret-manager unavailability, which remains a precondition rather than a specification.
- **IMPLEMENTATION_FEASIBILITY: MEDIUM.** Unchanged, and the re-verification moves it neither way.
  The amendment is documentation and is complete. The architecture it *records* remains MEDIUM:
  `9417f8bf` records confidence **LOW** with no option runtime-verified, A3 adds a runtime
  dependency that gates the credential path (A4), and the A1/A4 fallback is documented — which is
  what keeps this MEDIUM rather than LOW.

---

## 8. Discoveries

| id | Category | Finding | Disposition |
|---|---|---|---|
| ADR-0018-A2-D1 | `CONTRADICTION` → **RESOLVED** | `AGENTS.md` §13 was absent, so this ADR's carve-out and ADR 0012/0019's citations pointed at absent text. | **Closed.** `0bf2fa0` restored §13/§13a/§13b; re-verified at `43d328b` (R23). ADR `:530-537`. No longer escalated — the human already fixed it. |
| ADR-0018-A2-D2 | `PROJECT_FACT` | Superseded: the credential upsert was an unpredicated `DO UPDATE` with no `RETURNING`. | **Superseded at `43d328b`**: the predicating upsert is merged (R5). The finding remains true of `6220951` and is retained in the ADR's provenance-correction blockquote rather than as a live claim. |
| ADR-0018-A2-D3 | `PROJECT_FACT` | `HostKeyStatus` has a **domain** enforcer and **no transport** enforcer. | **Re-verified, unchanged in substance, corrected in detail** (R13, R15): three sites not two, `+14` lines, confirmed against the sibling lane's reported offset. ADR `:382-400`. |
| ADR-0018-A2-D4 | `ARCHITECTURE_DISCOVERY` | Resurrection (D-18) is reachable. | **Confirmed still live at `43d328b`** (R7–R11), now recorded as accepted risk A1 with the precise mechanism and the index's non-role (ADR `:453-481`). Not re-registered under a new id — it is D-18, carried by the keyservice lane. |
| **ADR-0018-A2-D5** | `PROJECT_FACT` | The partial unique index **does not** refuse a legitimate fresh mint after a proper revocation, because `rotateCredential` revokes first. Revision 1 asserted the opposite. | Recorded as a correction to revision 1 (§4.1) and in the ADR `:352-359`. Evidence-backed; within automatic authority. |
| **ADR-0018-A2-D6** | `CONTRADICTION` | **No Human Decision object on disk records the acceptance of A2.** The acceptance exists in `WORK_STATE.md:326-327` and in this artifact, but `.decisions/` has no object for it — while `ae1c1f79:8-11` records the precedent that an object should exist precisely so an answer has a citable id. | Touches governance → **routed to the Manager.** ADR `:572-580`, §6. Not fixable by this lane (`.decisions/**` is PROHIBITED). |
| **ADR-0018-A2-D7** | `PROJECT_FACT` | Rev 1's cite-count validation command (`grep -n "ADR 0018" apps/server/lib packages/*/lib --include="*.dart" \| wc -l`) omits `-r`, hands `grep` two directories and no files, and returns 0 regardless of repository content. | Reported in revision 1 §8 and repeated in §9. **Worth fixing at the dispatch level**: any lane running it verbatim gets a meaningless green. Not re-run here — it is a code-cite count, not a claim in the ADR. |

### F-1 — Reported, not fixed: an out-of-scope observation another lane should verify

While re-verifying the board-copy claim I read `apps/control_plane/**`, which is outside this
dispatch's `READ_ONLY_PATHS` (disclosed in §0). The observation: the copy asserting device-local
custody appears at **four** sites, not the two the ADR records — the two technical-details chips
(`add_product_page.dart:542`, `:1038`) plus a longer sentence at `:480-481` and its duplicate at
`:979-980` ("It clones over SSH. The private half stays in this device's keychain — never shown,
logged or stored.").

**This is not recorded in the ADR as verified fact**, because it was not verified within this
lane's declared read scope, and an out-of-scope read is not a lane-verified claim. It is reported
here for the **Add Product mobile design lane**, which owns that path, to verify and act on. If the
two longer strings are live, the correction surface is twice what the ADR currently names — which
matters, because under A3 both assert a custody model the ADR has superseded.

### F-2 — Not fixed, and deliberately: nothing claims A2's gaps are closed

The four accepted risks are recorded as accepted. None is closed, and no wording in the ADR or the
metadata asserts otherwise. The word "accepted" appears where the human's judgement applies and
nowhere else.

### F-3 — Not fixed: a second `WORK_STATE.md` line still describes A2 without the acceptance

`docs/engineering/WORK_STATE.md:326-327` records the acceptance; `:347` (IN_REVIEW) still reads
"ADR 0018 amendment A2 … drafted, awaiting independent review." Both are Manager-owned. The
acceptance is not *contradicted* by `:347` — "awaiting independent review" is still true — but a
reader landing on the IN_REVIEW list alone would not learn the acceptance exists. Reported for the
Manager; not edited.

---

## 9. Validation

Run in `/private/tmp/shipit-design-adr0018`. No Docker or Compose command was issued.

| Command | Result |
|---|---|
| `git branch --show-current` | `design/adr-0018-amendment` — PASS |
| `git rev-parse --short HEAD` | `43d328b` — PASS |
| `sed -n '1,20p' docs/adr/0018-per-product-git-credentials.md` | `:4` Status reads **`Accepted (amended — …)`**; `:6-21` acceptance block with the recorded answer, the acceptance-is-not-review statement and the authority note; amendment table intact at `:30-33` with both A1 and A2 rows — PASS |
| `git log 6220951..main -- docs/adr/0018-…` | empty — the ADR did not move on `main`, so the re-base could not invalidate any A2 clause — PASS |
| `git diff --stat` | one file changed under `docs/adr/`, plus this artifact directory — PASS |

**NOT RUN, and not claimed:** `dart analyze`, `dart format`, `dart test`, any integration or visual
gate (no production code changed, so no code gate applies — but none was run and none is claimed);
any Docker or Compose command; any Markdown linter (none is configured in this repository);
**independent design review**, which has never happened and is the next gate.

Rev 1's malformed cite-count command is **not re-run** — see `ADR-0018-A2-D7`.

---

## 10. Blockers

**None.** Both items revision 1 escalated have been answered:

1. **Status-line authority — ANSWERED.** The ADR owner accepted. Recorded at ADR `:4` and `:6-21`,
   metadata `status: ACCEPTED` / `approved_by` / `approved_at`. This lane still did not grant the
   authority; it recorded the authority the owner granted.
2. **Acceptance of the recorded gaps — ANSWERED.** "Accept A2, record the gaps as accepted."
   Recorded as §Accepted risks A1–A4 at ADR `:446-524`, each with its consequence.

One item is **not** a blocker but is routed up, because it is outside this lane's authority:
`ADR-0018-A2-D6` — no `.decisions/` object records the acceptance.

---

## 11. Handover

`READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES`.

This artifact is ready for review and has **never been reviewed**. A reviewer should check, in
this order:

1. **The approval fields** (`design-revision-metadata-2.yaml`) — that `status`/`approved_by`/
   `approved_at` reflect the owner's decision, that `reviewed_by`/`reviewed_at` are still `null`,
   and that nothing anywhere claims a review that does not exist. This is the specific failure
   mode that produced this dispatch.
2. **The four accepted risks** (ADR `:446-524`) — that each consequence is stated honestly and
   none is softened into a claim of closure.
3. **The provenance correction blockquote** (ADR `:336-340`) and the two corrected markers
   (`:342-378`) — that the re-verification at `43d328b` is real and the "not present at this
   revision" markers are gone rather than merely reworded.
4. **§4.1** — the index correction. Check it against `rotateCredential`
   (`product_registry_engine.dart:1116-1132`) and the index predicate
   (`schema_bootstrap.sql:100`): after a revocation the superseded row is excluded, so the
   replacement does not trip it.
5. **§4.3 / R13** — the `+14` line shift, and whether recording **three** enforcer sites rather
   than two changes any conclusion about gap A2. It should not.
6. **The absence of a decision object for the acceptance** (D6, ADR `:572-580`) — whether that is
   correctly reported as a governance gap for the Manager rather than papered over with an invented
   id.
