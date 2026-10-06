# Report — Independent Design Review, deploy-key service (Gate D3)

Persisted per `aef-orchestrator` §14. Reviewer: `design-reviewer`, read-only.
REVIEWED_HEAD `77c19f1` (lane worktree `/private/tmp/shipit-design-addproduct-keys`, branch
`design/addproduct-keyservice`; artifacts persisted into the canonical tree at `064703d`, whose
parent is `77c19f1` — provenance verified).
REVISION_ID `46980EE0-E638-409C-A7D3-E1B9399FECE5` · BRIEF_ID `97484D0E-E16C-485E-BAA2-A277889C0FB6`.
**No Docker or Compose command was executed by this review.**

```
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
REVIEWED_HEAD: 77c19f1
CORRECTION_REQUIRED: YES
HUMAN_DECISION_REQUIRED: YES
HUMAN_DECISION_TYPE: DESIGN
INDEPENDENT_RISK_LEVEL: 3
RISK_LEVEL_AGREEMENT: YES
```

## What I independently confirmed

| Claim | Result |
|---|---|
| `copyWith` omits `publicKey`/`credentialId` | ✓ **EXACT** — `repository_credential.dart:137-172`; params are only `status, lastVerifiedAt, lastVerifiedBy, lastFailureReason, hostKeyStatus, host, hostKeyFingerprint, hostConfirmedAt, hostConfirmedBy, revokedAt, revokedReason, version`. Class is `@immutable`, all fields `final`. |
| Six engine methods at 912/974/1020/1058/1084/1138 | ✓ **all six exact**; plus `readActiveCredential:1121`, `requireUsableCredential:1138-1161`, `createProduct:43`, `addRepositoryReference:150`. |
| Reuse table honest | ✓ ~33 of 35 rows verified at cited lines, including `repository_credential_view.yaml:24-25`, `ui_view_mappers.dart:169-188`, `exceptions.dart:201/215/232`, `audit_entity_type.dart:8`, `credential_test.dart` = 16 tests, `server.dart:71-72`. |
| `AccessStatus.verified` never assigned | ✓ `:235,563,609,659,731,884,1059,1105` are all predicates/`case` labels; only `accessStatus:` initialiser is `:118 → notChecked`. |
| `canGenerateKey` zero call sites | ✓ `:230` is the only occurrence in the file. `deployKey` assigned only at `:117`; `_buildKeyBox` gated by `if (state.deployKey != null)` at `:444`/`:851`. **Bootstrap deadlock confirmed.** |
| No endpoint exposes a credential view | ✓ 11 endpoint files, `grep -c RepositoryCredentialView` = 0 for all. Only "credential" mention is a doc comment at `product_registry_endpoints.dart:59`. |
| D-7 loopback unenforced | ✓ `grep "127.0.0.1:"` → no match; `compose.qa.yaml:17,56,74` = `5432:5432`, `8080:8080`, `8081:8081` unqualified. |
| D-3 no runtime enforcer | ✓ **EXACT** — `git_workspace_inspector.dart:106-112` is `Process.run(git, args)` with no `environment:`; repo-wide `SSH_AUTH_SOCK\|known_hosts\|ssh-keyscan\|StrictHostKeyChecking\|IdentityFile` in `apps`+`packages` → no match. `HostKeyStatus.permitsConnection` is decorative at runtime. |
| OPEN-D4-2 cycle is real | ✓ **REAL** — `recordGeneratedCredential:924-925` needs the repo + ownership; `addRepositoryReference:158` needs the product; `createProduct:54` hardcodes `ProductState.registered`; no pre-registration state exists (`product_state.dart:23-28`). Escalating rather than deciding was correct. |
| a11y figures (inherited, not re-measured) | ✓ **I re-measured them anyway** from `design_tokens.dart:96,100,101,117,121,122` with a sanity-checked WCAG implementation (black-on-white = 21.00). `inkTertiary` on `palette.card` = **4.99:1 light / 4.23:1 dark (fails AA)**; `inkSecondary` = **6.74:1 light / 6.10:1 dark**. Every inherited figure is correct, and labelling them inherited rather than claiming them was the honest call. |
| Self-assessment honesty | ✓ genuine. `PARTIAL`/`PARTIAL`/`MEDIUM` are each substantiated or honestly bounded; no gate claimed that was not run. |
| Security exposure not buried | ✓ § R.18 is a titled section stating plainly that *nothing* protects the endpoint, that it is worse in kind than existing endpoints, and that it is not proposing auth. Correctly framed as a consequence of the revision. |

## The leakage hunt — where the boundary is

**Correctly withheld (no leakage):** § R.4 A1–A4 / § R.5 B1–B2 / § R.6 C-1..C-3 are option sets with
for/against and no selection; § R.16's error table carries `depends on Q2 — OPEN` in both the
response and the state-written columns; reuse row #31 marks the private-half store
`OPEN — HUMAN DECISION REQUIRED AT GATE D4`; § R.12 explicitly flags "**This row depends on
OPEN-D4-2**" and says the key "persists" only under options 1 or 3; § R.7's transport constraint is
legitimately normative (every option must satisfy it) and is honestly labelled "currently
unenforceable". § R.8's recommendation table is labelled "**not** a decision" with per-row confidence.
**This is a recommendation, not a default.**

**Leakage found — one location.** § R.3, which sits *outside* the OPEN-D4-1 section:

> **Decision (normative, within this design agent's authority — it selects a substrate):** … What
> changes is whose store it names: from *the operator's local secret store* to **\*SHIP IT's own
> at-rest store\*** for this credential.

Two problems. (1) It self-describes as selecting a substrate, in normative voice, for the question
the human reserved. (2) "**SHIP IT's own** at-rest store" excludes **A3** — the external secret
manager, which is the option § R.8 *recommends* and `9417f8bf` recommends as OPTION_C. If
implemented as written, A3 is excluded by a sentence the human may never read. The same paragraph
adds "**No wire-contract break from the field's existence**" flatly, which is retracted 30 lines
later. Reuse row #35 ("Migration: none proposed", `New? —`) marks a conditional as settled.
Everything else in R-1/R-5/R-6 holds the line.

## BLOCKERS

**B1. ADR 0018 EXISTS.** The revision's central traceability finding (D-6 / G-1 / § R.21, "I cannot
read my own governing ADR") is FALSE, and it has already been persisted as a ledger VERIFIED FACT.
Verified: `docs/adr/0018-per-product-git-credentials.md` — 158 lines, "ADR 0018: Per-Product Git
Credentials", status "Proposed (amended — A1)". `docs/adr/` holds **21** ADRs (0001–0021). The
producer ran `ls docs/engineering/adr/`, which legitimately contains only the three
framework-distribution ADRs — **the same wrong-identifier class of error the revision itself
criticises in D-1.** Read it. It decides, today, four of the things the revision presents as open:

- `:85-88` "One `ed25519` keypair per repository, generated by ShipIt on the operator's device. The
  private half is written to the local secret store (macOS Keychain or `~/.config/shipit/platform/`
  chmod 600) and is **never displayed, logged, persisted to the durable record, or transmitted**."
  That is A1 + A4 already chosen, and it **excludes A2 outright** (A2 *is* persistence to the
  durable record). A2 is offered to the human in § R.4 with no note that it contradicts the
  governing ADR.
- `:96-99` "ShipIt refuses to connect to an unrecognised host" — this is the authority behind D-3;
  the transport seam is an explicit ADR requirement, which strengthens the MEDIUM feasibility rating
  rather than weakening it.
- `:100-102` "A product cannot be registered until a connectivity check has succeeded" — human point
  2b as a *settled architecture decision*, and it is itself unsatisfiable under the current engine.
  OPEN-D4-2 is therefore an **ADR contradiction**, not only a design-level circularity.
- `:113-114` "Revocation is provider-native: removing the deploy key from the repository is
  sufficient and **requires no Shipit-side action**." This already answers OPEN-D4-1 Q3.
- `:15-30` amendment A1 settles assumption #1 in § R.21 verbatim ("one keypair per product" →
  "per repository"); `:86-88` settles assumption #8.

Also unreferenced by the revision's `architecture_refs`, which lists only the three framework ADRs:
**ADR 0012** (immutable promotion; "Credentials referenced by name only (AGENTS.md §13 convention)" at
`:34`), **ADR 0015** (worker execution layer — governs the transport seam D-3 is about), **ADR 0019**,
**ADR 0020**, **ADR 0021**.

*Contamination already in the audit trail — all Manager-owned, not the reviewer's to fix:*
`docs/engineering/WORK_STATE.md:484-490` (heading "### ADR 0018 DOES NOT EXIST"), `LANES.md:204-205`,
`.decisions/898b07d0-…yaml` context (verbatim), `.decisions/9417f8bf-…yaml` evidence.

**ACTION (design correction lane):** read `docs/adr/0018`, `0012`, `0015`, `0019`, `0020`, `0021`;
rewrite § R.21 (the surviving real gap is `AGENTS.md §13`'s absence and the carve-out ADR 0018
depends on at `:140-141` — that half of D-6 stands); rewrite § R.4 A1/A2/A4 and § R.6 C-1..C-3
against what the ADR already decides, keeping only the genuinely open delta open; repopulate
`architecture_refs` with the credential architecture ADRs; remove the false G-1 from
`requirements_gaps` and replace it with the true gap.

**ACTION (Manager, before Gate D4):** supersede/reissue `9417f8bf` and `79e860e2` so the human is not
asked to choose a substrate the governing ADR has already chosen and constrained, and correct
`WORK_STATE.md:484` and `LANES.md:204`. **Do not present `9417f8bf` to the human before B1 is
corrected — an answer given on the current evidence would be wrong.**

**B2. "B6 is structurally impossible — four independent mechanisms" is FALSE at the persistence
layer, and mechanisms 3 and 4 are not independent.** § R.16 step 4's concurrency resolution is also
not guaranteed.

Verified: `apps/server/lib/src/persistence/postgres_product_registry_store.dart:177-243` —
`saveProductCredential` with a null `expectedVersion` executes
`INSERT INTO "product_credential" (...) VALUES (...) ON CONFLICT ("credentialId") DO UPDATE SET
… "publicKey" = @publicKey, "fingerprint" = @fingerprint, "referenceName" = @referenceName …`.
`recordGeneratedCredential` calls it at `engine:965` with **no** `expectedVersion`. It also accepts a
caller-supplied `credentialId` (`engine:920`), and the one-active guard at `engine:941` is
`if (active != null && active.credentialId != supersedesCredentialId)`. Therefore:

```
recordGeneratedCredential(credentialId: 'cred-1', supersedesCredentialId: 'cred-1',
                          publicKey: <new key>, fingerprint: <new fp>, …)
```

passes the guard and **overwrites the stored `publicKey` on the existing row** — same
`credentialId`, no rotation record, `status` reset to `generated`, host confirmation lost.
`copyWith` is not on this path at all; it constructs a fresh `RepositoryCredential`
(`engine:950-964`) and upserts it. This refutes:

- R.15 #4 — "`copyWith` cannot change `publicKey`, so even a buggy caller cannot re-point an
  existing credential's key."
- R.15 — "These are independent. Even if the endpoint's idempotency were removed, mechanism 3 still
  refuses and mechanism 4 still prevents silent substitution."
- § R.2 constraint 3 — "The private half is immutable per credential … cannot be silently repointed
  later."
- the metadata changelog's "strongest [mechanism] being that `copyWith` cannot change `publicKey` or
  `credentialId`, so even a buggy caller cannot re-point an existing credential's key."

The existing test does not catch it: `credential_test.dart:206` uses `credentialId: 'cred-2'` with
**no** `supersedesCredentialId`.

Separately, § R.16 step 4 ("On the engine's one-active-credential exception … a concurrent mint")
relies on an exception that will not fire. `product_credential` carries a unique index on
`credentialId` only (`20261001205247600/definition.sql:645`); `repositoryId` has a **non-unique**
index (`:646`). `ON CONFLICT` is keyed on `credentialId`, so two concurrent mints with different
generated ids both pass the read-then-write at `engine:940`/`965` and both insert → **two active
credentials for one repository**, violating ADR 0018 A1's "one per repository". "Two simultaneous
presses must still yield one key" is therefore not guaranteed.

**ACTION:** (a) add a compare-and-swap/refusal so `saveProductCredential` (or
`recordGeneratedCredential`) cannot change `publicKey`/`fingerprint`/`algorithm`/`referenceName` on
an existing `credentialId` — `recordCredentialCheck:1052` and `confirmHostKey:997` already pass
`expectedVersion`, so the pattern exists; (b) add a partial unique index
`ON product_credential (repositoryId) WHERE status <> 'revoked'`; (c) rewrite R.15 mechanisms 3/4 and
R.16 step 4 to state what actually holds (endpoint-level get-or-create plus a store-level immutability
guard — **two, not four, and not independent**); (d) extend SC-02/SC-03 with the two engine-level
tests that fail today: same-`credentialId` re-mint must throw, and two concurrent mints must yield
one row.

## HIGH

**H1.** § R.3 leaks the reserved at-rest decision (see "where the boundary is"). Also retires the "No
wire-contract break" assertion (retracted later in the same section) and leaves reuse row #35 marking
a conditional as settled.
**ACTION:** restate § R.3 invariant-only — "`referenceName` continues to name a reference and never a
value; its subject, the substrate, and whether it may reach the client are OPEN-D4-1." Delete "it
selects a substrate" and "SHIP IT's own at-rest store". Delete the wire-break claim. Mark row #35's
migration cell explicitly conditional on the substrate.

**H2.** Q3 (revocation disposal) is presented as open but ADR 0018:113-114 already answers it
("requires no Shipit-side action"). `79e860e2` will ask the human a settled question.
**ACTION:** fold into B1. If `b869ec24` genuinely supersedes the ADR here (plausible, since SHIP IT now
holds the key), say so explicitly; if not, Q3 is already decided and should be **withdrawn** rather
than escalated.

**H3.** A2's risk analysis understates the threat model. A2's *For* bullet claims "backups of the
database alone no longer disclose the key", but the live database is the least-protected component in
the system: `docker/compose.yaml:62` hardcodes `SERVERPOD_DATABASE_PASSWORD: shipit` in a committed
file, `docker/compose.yaml` publishes `5432:5432` on 0.0.0.0, and `570bb640` records
`POSTGRES_USER=shipit / POSTGRES_PASSWORD=shipit` as documented defaults. An attacker needs no
backup — they read the live `product_credential` table directly.
**ACTION:** add this to § R.4 A2 (*Against*) and to § R.7's threat model.

**H4.** § R.18 lists three ways this endpoint differs in kind but omits the direct-database path: an
off-host caller reaching 5432 with the committed default credentials bypasses the endpoint entirely —
and under A2 that is exactly where the sealed key material sits.
**ACTION:** add as a fourth point. (The section's honesty about the endpoint itself is otherwise sound
and should be preserved.)

## MEDIUM

**M1.** "The current three-step `_StepText` list (`add_product_page.dart:650-672`)" is wrong — there
are **four** `_StepText` entries (`:650, :656, :662, :668`: generate / install+prove / read
revision+build baseline / approve baseline). This is a normative cross-lane instruction in the Brief's
"Implications for the sibling lane" #2, telling `design-addproduct-mobile` the enforced order is "four
steps — not the current three-step list", which would make the sibling mis-describe its own artifact.
**Fix:** state that the current list is four steps and that the key-flow order replaces steps 1–2 with
Generate → Trust → Check, adding Register as distinct.

**M2.** § R.8's confidence of MEDIUM on Q1 is not defensible on its own stated basis ("I could not test
A4 … so I do not recommend it"; A3's reachability is equally untested). Nothing about any option was
runtime-verified. **Recommend LOW for Q1**, or split the confidence per option.

**M3.** `design_system_compliance: PARTIAL` is honest about the boards, but the token risk is stated
too softly. The current idiom for exactly this copy is `palette.inkTertiary` on the card surface
(`add_product_page.dart:542` and `:590`) — which I measured at **4.23:1 dark, failing AA**. All seven
new strings (five failure kinds + two host states) will follow that idiom. **Make `inkSecondary`
(6.74:1 / 6.10:1, both verified) a normative requirement for new copy**, not a note in § R.8.

**M4.** `G-7` (`referenceName` reaching clients — a path/ARN disclosure under server-side storage) is
left with no owner. It is coupled to OPEN-D4-1, but `9417f8bf`'s stated question is the substrate only.
Name `9417f8bf` as owner explicitly, or file it.

## LOW

- **L1.** `engine:52` cited for `state: ProductState.registered` — actual `engine:54`. The wrong number
  has propagated verbatim into `.decisions/898b07d0` and the Brief.
- **L2.** `product_state.dart:29-32` cited for the "no baseline, no governance, no work" text — actual
  `:24-27`. (Substance verified: no pre-registration `ProductState` exists.)
- **L3.** Range endpoints off by a few lines, immaterial: `createProduct :43-63` (ends :61),
  `addRepositoryReference :150-174` (ends :170), `requireUsableCredential :1138-1160` (ends :1161),
  `credential_test.dart:146`→:145 and `:221`→:223. All other ~60 line citations exact.
- **L4.** § R.3 "already indexed as part of the row" — `referenceName` has no index; only `credentialId`
  (unique), `repositoryId`, `productId` (`repository_credential.spy.yaml:7-14`).
- **L5.** D-7 is a re-confirmation, not a new discovery: `570bb640`'s own context already records that
  "local only" is unenforced. Recording that the follow-up was never implemented is genuinely new
  information, but present it as a confirmed-unimplemented follow-up rather than a first-time finding.
- **L6.** `DECISIONS.md`'s index table omits `570bb640` (it appears only in the closing prose list).

## INDEPENDENT_RISK_LEVEL: 3 · RISK_LEVEL_AGREEMENT: YES

Assessed against `DESIGN_GOVERNANCE.md` § Design-Change Risk Levels, not by accepting the producer's
argument. Level 3 ("Major Workflow/Navigation/IA Change … affecting multiple features or user mental
models") is met on its own terms: human points 2a/2b make key generation and host trust preconditions
of the product-registration workflow, replacing a single "Check access" control with a four-step
enforced sequence and splitting the client's conflated `AccessStatus` into two orthogonal axes.

I also hold it at 3 on grounds **independent** of the producer's four: (1) the revision's own
OPEN-D4-2 shows the *primary* user flow's triggering act is not specifiable without a human decision,
and the revision says so; (2) ADR 0018 A1's one-active-credential-per-repository invariant is not
currently enforced by any database constraint, so a workflow whose central invariant is unenforceable
is not a workflow-level change of the safe kind.

I considered and rejected arguing it down to 2: the revision turns the page's only working control into
a four-gate sequence and introduces the first secret-bearing endpoint; that is user-behaviour-changing
regardless of label. The producer's refusal to argue it down was correct, and its Level-2 rows for the
transport seam and the wire-contract change are correct as *component* risks without lowering the
revision-level classification.

## TRACEABILITY_GAPS

1. **G-1 is not a gap — ADR 0018 exists** (`docs/adr/0018-per-product-git-credentials.md`). It is
   recorded as a gap in `design-revision-metadata.yaml` `requirements_gaps`, `traceability-matrix.md`
   § 4, `discoveries.md` D-6, the Brief's `architecture_refs`, and `WORK_STATE.md:484`. The true gap,
   and the only one worth keeping, is: **`AGENTS.md` has no §13**, so the carve-out ADR 0018 depends on
   (`:140-141`), ADR 0012 depends on (`:34`) and ADR 0019 depends on was never applied — and `AGENTS.md`
   is now the 71-line framework template with `Product-specific policy: TBD`. That gap is real,
   materially worse than reported (it nullifies a documented mitigation of the governing ADR), and
   should replace the false one.
2. `architecture_refs` lists ADR-0001/0002/0003 — the framework-distribution ADRs, which govern
   nothing in this design. The credential architecture references (0012, 0015, 0018, 0019, 0020, 0021)
   are absent, so **no design element traces to the architecture it actually depends on.** Gate D3's
   traceability criterion is not met while this stands.
3. Assumption #1 (§ R.21, "scope is one repository") and assumption #8 ("`referenceName` names the
   operator's local secret store") are **not assumptions** — both are recorded ADR 0018 decisions
   (amendment A1 at `:15-30`; the local-secret-store subject at `:85-88`). The table presents settled
   architecture as unverified inference.
4. Nothing traces OPEN-D4-1 Q4 (whether `referenceName` may reach the client) to a decision object.
   `9417f8bf`'s stated question is the substrate; its OPTION_C implications touch the ARN sensitivity
   but do not ask the question. Same object as M4.
5. `requirements_gaps` is otherwise honest — OPEN-D4-1, OPEN-D4-2, G-2…G-8 and the explicit
   out-of-scope note for points 2e/2f are all real, and none is being used to hide unfinished design
   work. The one dishonest entry is G-1.

## HUMAN_DECISION_REQUIRED: YES — gating an existing decision, not raising a new one

Precisely because the reserved decision is already filed and **must not be answered yet**:

- **`9417f8bf` (SECURITY, PENDING)** — at-rest substrate. **This is the decision the human explicitly
  reserved.** It is built on a false premise (ADR 0018 unavailability) and its four options are not
  consistent with ADR 0018:85-88, which already names A1+A4 and forbids A2. It must be
  superseded/reissued with ADR 0018 in evidence before it reaches the human.
- **`79e860e2` (SECURITY, PENDING)** — revocation disposal. Likely already answered by ADR
  0018:113-114; **withdraw or restate** after B1.
- **`7b1bc8b7` (SECURITY, PENDING)** — fail-open vs fail-closed. Unaffected by B1; the design's B1
  recommendation and its naming of the tension with point 2d are correct and already faithfully
  transcribed into the decision. No new action.
- **`898b07d0` (ARCHITECTURE, PENDING)** — registration ordering. The cycle is independently VERIFIED
  and the escalation was correct. It should additionally be framed as a contradiction with ADR
  0018:100-102, which raises its severity above "which of three options". Correct the two line numbers
  (L1/L2) in its context.
- **`27ea6536` (DESIGN, PENDING)** — footer-copy scope. Belongs to `design-addproduct-mobile`. Not this
  lane's; nothing further.

No new human decision is required that is not already covered by one of the five. B1's ledger
corrections are **Manager-owned actions**, not a gate — flagging, not escalating.

## SAFE_PARALLEL_WORK

**SAFE:**
- `design-addproduct-mobile` — unaffected. Disjoint `OWNED_PATHS`; owns none of these artifacts. The
  five alignment implications in the Brief are usable once M1 is corrected; items 1, 3, 4 and 5 are
  independently sound as written.
- `qa-contract-addproduct` — may start against AC-01..AC-14 / SC-01..SC-10, with SC-08 treated as an
  OPEN D4 dependency rather than a testable assertion. **Do not draft assertions for SC-02 or SC-03
  yet:** B2 shows both currently pass for the wrong reason.
- Read-only discovery on the SSH transport seam (D-3). The gap is confirmed and does not depend on any
  unresolved decision; producing a design brief for credential injection + host-key verification is
  valuable now and does not pre-empt OPEN-D4-1 or OPEN-D4-2.

**NOT SAFE:**
- `implement-addproduct` (any part) — OPEN-D4-1 is undecided, and after B1 the substrate option set
  itself is wrong. Additionally B2 shows the existing credential store cannot yet uphold the
  immutability the design claims, so implementing mint/check against it today would ship a
  silent-rotation path.
- Any lane creating or editing a Penpot board for this lane's two new states (the sibling owns all four).
- Anyone other than the Manager correcting the D-1/D-6 ledger facts in `WORK_STATE.md`, `LANES.md` or
  `.decisions/**` — and note that correcting **D-6** requires the Manager, since the fact it records
  is false.

**NOT RUN by this review:** `dart analyze` / `flutter analyze` / build / test — NOT_RUN, and no claim
is made about their output. Any Docker or Compose command — NOT_RUN, none issued. Four claims remain
UNVERIFIED and are the human's to run: `docker compose -f docker/compose.test.yaml up`, then install
the returned `publicKey` into a scratch repo's `authorized_keys` inside the server container and run a
real check (SC-01); container→host keychain reachability on the actual deployment target (A4);
`changed` detection against a host presenting a different key (N-6/G-8). Loopback pinning was verified
negatively by grep only.

## Bottom line

The design is unusually strong on the parts the human cares about most: the `OPEN` markers hold, the
recommendation is labelled as a recommendation, the security exposure is a titled section rather than a
footnote, `N-1` states the no-Cancel rule normatively with its rationale and its cost, `R.12` traces
the way out to a real column and a real read path, `N-6` gives `HostKeyStatus.changed` a user-facing
path without a "trust anyway" affordance, and the a11y figures survive independent re-measurement.
Escalating `OPEN-D4-2` rather than picking an option was right, and the cycle is real.

Two things block it. The revision's most prominent finding — "I cannot read my own governing ADR" — is
an artefact of looking in the wrong directory; ADR 0018 exists, has already chosen the substrate
question the human is being asked, and its absence has already been written into the ledger as a fact.
And the revision's headline security claim — that silent key rotation is *structurally* impossible — is
true of the in-memory object and false at the `ON CONFLICT DO UPDATE` boundary that actually persists
the row, where a caller supplying both `credentialId` and `supersedesCredentialId` overwrites the
stored key in place. Both are correctable without touching the human's reserved decision, which is why
this is `CHANGES_REQUIRED` with the existing `9417f8bf` gated rather than a new gate.
