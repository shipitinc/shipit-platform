# Report — Independent Design Review, deploy-key Design Revision 3 (Gate D3)

Persisted per `aef-orchestrator` §14. Reviewer: fresh `design-reviewer`, read-only.
REVIEWED_HEAD `77c19f1`; REVISION_ID `4B017787-25A0-4F45-ABDA-805C250AF63F`. `main` at review time `0bf2fa0`.

```
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
REVIEWED_HEAD: 77c19f114ee691e8c434afe37b7c84494b66dc40
CORRECTION_REQUIRED: YES
HUMAN_DECISION_REQUIRED: NO
INDEPENDENT_RISK_LEVEL: 3
RISK_LEVEL_AGREEMENT: YES
```

## Verified CORRECT

1. **The substrate option set is genuinely gone from normative text.** § R.4 is a withdrawal notice; no `Q1`/`Q1′`, no confidence column, no "if the human answers" branch. A1/A4 appear **only** in § R.1.5 as a fallback with a non-triggerable-by-outage condition (`SHIPIT_SECRET_MANAGER_ENDPOINT` unset ⇒ configured-but-down still fails closed). A2 appears once, closed, with `:87-88`'s prohibition stated as surviving. `SC-08a` makes re-presentation the defect. **No HIGH finding — the human's reserved decision is not nudged anywhere.**
2. **§ R.1.3 is a proper judgement.** The literal-ARN alternative is named, its single cost stated, the rejection recorded "so a reviewer can challenge it". Supporting facts check out at `main`: `docker/compose.yaml:16-17` (`"5432:5432"`), `:63` (`SERVERPOD_DATABASE_PASSWORD: shipit`), `.env.example:16-18`.
3. **`D-18` verified independently.** `engine:938-939` → `:940-951` → `:954` `readActiveCredentialForRepository` returns **`null`** for a revoked-only repository (`store:370-381`, `"status" <> 'revoked'`; same `in_memory:221-231`) → the guard at `:955` cannot fire → `:963-978` builds a fresh row `status: generated, revokedAt: null, version: 1` → `:979` reaches the upsert branch with `expectedVersion == null` and the predicate is satisfied by identical values → **the call succeeds**. No existing test covers it (`credential_test.dart:323` closes only `recordCredentialCheck`).
4. **`D-4`'s call-site table is exact.** Five `saveProductCredential` sites: `engine:979` (mint, no `expectedVersion` → upsert), `:1011`, `:1025`, `:1066`, `:1088` (all CAS). `rotateCredential` mints a new `credentialId`.
5. **Revocation two-sided**, ordering normative, row retained — matches `79e860e2` exactly.
6. **Fail-closed end to end** — four triggers, the coarse single wire `failureKind` against the unauthenticated-caller oracle, all four remediation blocks verbatim.
7. **Store invariant and the honest B6 split** — § R.8.2's "two real persistence mechanisms + one application requirement; the state-loss family is NOT closed". § R.8.3's eight rows reconcile with the claim.
8. **Citations honest** — ≈40 sampled `file:line` all resolved at their labelled SHA. No citation at the wrong SHA; the `07c8c8f` blobs are byte-identical on `main`.

## BLOCKERS

**B1 — The base is stale: two of the revision's gap entries are false and one RESOLVED decision is absent. Re-base before freeze.**
- `LANES.md:204-205` is **not** a surviving false claim. At `77c19f1` `LANES.md` is 172 lines with no such assertion; on `main` line 205 reads the **retraction** (`"That was false."`, landed `4e2d237`). § 10.1 item 6 would send the Manager to retract an already-retracted claim.
- **`G-1′` is closed on `main`.** `0bf2fa0` restored `AGENTS.md` §13/§13a/§13b. § 10.1 item 7 asks for an action already completed.
- **`ae1c1f79` appears zero times** across all four artifacts. Revision 3's mtime is 13:31; the decision is `decided_at 13:50`. **It predates the decision.**
- **Directive:** re-verify every gap entry and `[6220951]` citation against `main`, or re-dispatch on a base containing `07c8c8f`, `674b871` **and** `0bf2fa0`.

**B2 — § R.5.2 step 5 / § R.14.1 step 5 mandate `destroy(handle)` in a `finally`, which on the literal reading destroys the handle on the SUCCESS path.** § R.5.2: "**compensate**: `destroy(handle)` in a `finally`, then refuse". § R.14.1: "inside a `try`, with `destroy(handle)` in the `finally` on any failure". Dart has no failure-only `finally`. As written the success path destroys the handle just recorded — producing exactly the forbidden state § R.5.2 names. **Fix:** state the construct once normatively (success flag / catch-rethrow) and use it verbatim in both. Add `T-H`'s counterpart: after a **successful** mint, `resolve(handle)` must return the material.

**B3 — § R.11.1's state 4 (`revoked`) is not derivable from the read path the design keeps.** § R.16 row 46 specifies `RegistrationCommitState` as client-derived from `ProductDetailView.credentials` with "no new server field"; § R.12 says a revoked credential "does not come back — that is state 4". Both cannot hold: `loadProductDetail` (`control_plane_service.dart:362-366`) populates `credentials` **exclusively** from `readActiveCredentialForRepository`, which excludes revoked rows, and `ProductDetailView` carries no revoked summary. So **state 4 is indistinguishable from state 1** — the user is told "no key generated yet" for a key that existed and was withdrawn. § R.11.1's stated cause ("`AccessStatus` has no `revoked` member") mislocates it: `AccessStatus` is downstream of a query that never emits the row. `RepositoryCredentialView.status` already carries `revoked`, so the fix is a **query change, not a new model**. **Fix:** specify the server change as a required deliverable, add it to § R.16's reuse table and blast radius, correct the stated cause.

**B4 — `D-4`/`D-5` are specified as SQL statement changes only; the named tests run in-memory, and the two-tier agreement would break.** `in_memory_product_registry_store.dart:205-213`'s `_sameKeyMaterial` **deliberately excludes** `repositoryId`/`productId` — "it mirrors the immutability the Postgres store's write enforces, and the two must agree" — then overwrites wholesale. `T-C`, `T-F`, `T-G` are all in `credential_test.dart`, which is entirely in-memory. After a Postgres-only fix those tests **still fail**, and `D-5` would leave the tiers holding *different* predicates — the exact defect `product_credential_immutability_postgres_test.dart:29-31` exists to catch. The words `InMemory`, `both tiers` and `memory tier` appear **zero** times in all four artifacts. **Fix:** add the in-memory tier to `D-4`/`D-5` with its own construct, and update `product_registry_store.dart`'s contract doc.

## HIGH

- **H1 — Host derivation reads a row the next step creates.** § R.5.2 and § R.10.1 derive `host` from `RepositoryReference.uri` at step 1, then create the reference at step 2. § R.14.1 gets it right (derives from the endpoint's `repositoryUri` parameter). Two normative locations state an unsatisfiable ordering.
- **H2 — § R.14.1 step 2's get-or-create read precedes the `RepositoryReference` it requires, and the endpoint has no `repositoryId`.** Step 2 is `readActiveCredential(productId, repositoryId)`, but `engine:1139` calls `_store.readRepositoryReference`, which throws `RepositoryNotFoundException` when absent — so on a first mint step 2 throws instead of returning null. Separately the endpoint signature is `{productId, name, repositoryUri}` — **no `repositoryId`** — yet steps 2, 4, 7 and `addRepositoryReference` all require one, with no derivation specified. And the error table maps "unknown repository" to `CredentialNotFoundException` where the domain throws `RepositoryNotFoundException`.
- **H3 — `D-4`'s CAS-branch extension has no construct and no test, and its stated argument does not reach it.** § R.9.1 rejects `DO UPDATE … WHERE <always false>` as a "second source of truth" — but `D-4` then extends to the CAS branch with no construct and no test, while that branch's predicate **is** that shape. `revokeCredential` legitimately **sets** `revokedAt` through it, so the requirement needs the explicit "may SET, must not transition non-null → null" formulation plus a test.
- **H4 — `ae1c1f79` is not reflected.** The revision predates the decision, and its content already matches OPTION_A exactly, so **nothing is contradicted**. But (a) § 10.1 item 3 re-presents a made decision as open; (b) `requirements_gaps` and matrix row 34 still carry it open; (c) the decision's **second follow-up action** — "State the consequence for the mobile boards" — appears nowhere (`"Products list"`, `"after a refused mint"` occur zero times).
- **H5 — G-7's blast radius is nine hand-written sites, not seven, and two will not compile.** `CredentialResponse.referenceName` is `required` (`control_plane_repository.dart:1691`) and two test files pass it (`product_detail_mobile_golden_test.dart:33`, `product_detail_page_test.dart:18`). § R.3.2 presents itself as the complete change list. Also `packages/control_plane_client/lib/src/protocol/protocol.dart` contains **zero** field enumerations and will not change — drop it or mark it a no-op.
- **H6 — The risk rationale is tallied four different ways across three artifacts** (5 rows vs "one improved, two unchanged, three worse"; `metadata-3` heads "UNCHANGED OR WORSE (4 reasons)" then enumerates 5; `report-revision-3` says "Two improved, four unchanged or worse"). **The level 3 is right** — the disagreement is with the arithmetic, not the level. Publish one tally used identically in all three.
- **H7 — § R.6.1's pseudocode would place a `SecretProvider` call inside `packages/product_registry`.** It is headed `revokeCredential(...)` and uses the engine's private `_ensureOwned`, so it reads as the engine method's body — but § R.1.2 and `C-02` forbid `SecretProvider` there and `engine:899-905` states the boundary. The composition must live in `apps/server`.

## MEDIUM / LOW

- **M1** — the duplicate-credential audit is missing from **both** gap registers (§ R.18.2 and `requirements_gaps`), carried only in prose and the changelog: the "hidden in a second list" pattern.
- **M2** — `product_registry_store.dart:41-64`'s tier-agnostic contract doc is in no change list, though `D-4`/`D-5` widen that contract.
- **L1** — `D-18`'s mechanism is misnamed: the refusal comes from the engine's one-active guard (`engine:954-960`) **before** `D-2`'s index; `D-2` is the backstop only. And the landed store comment at `store:313-319` asserting "no reachable path moves a credential from revoked back into the active set" is **falsified** by `D-18`.
- **L2** — § 10.2 item 6 asks a reviewer to verify the citation labelling is complete, but no citation index exists (§ 0.4 names only three labels).
- **L3** — "reachable through the public domain API today" is true of the Dart library; **no Serverpod endpoint calls `recordGeneratedCredential`** (verified — engine and tests only).
- **L4** — `credential_test.dart`'s rotation test is at `:521`, cited as `:520`.

## Traceability

**Still open:** `G-4` (ADR `:96-99` requirement with no implementation), `G-10` (A3 reachability `UNVERIFIED`), `G-11` (`D-4`/`D-5` unbuilt — and per B4 not fully specified), `G-3`, `G-5`, `G-6`, `G-8`, `L-6` (`DECISIONS.md:8-12` omits `570bb640`; the file also still says "All five are `PENDING`" at `:16`, now false), and the ADR 0018 amendment as a blocking predecessor.

**Added by this review:** the duplicate-credential audit (M1); the server-side data source for state 4 (B3); the in-memory tier for `D-4`/`D-5` (B4); `ae1c1f79`'s board-consequence follow-up (H4); `D-4`'s CAS-branch construct and test (H3).

**Closed by this review, not the producer:** the `LANES.md` and `G-1′` "gaps" are **not real** at the revision's base or at `main` (B1).

Eight decisions are RESOLVED. **None is re-escalated, and none was re-opened by the revision.**

## SAFE_PARALLEL_WORK

**Safe now:** dispatch `D-4`/`D-5` (B4 *strengthens* the case for the in-memory tier); the ADR 0018 amendment; **notify `design-addproduct-mobile`** of § R.11g items 1, 2, 4, 5, 6 — **item 3 is a requirement on their design** and is unaffected, plus H4's missing board-consequence statement; QA Contract drafting including the `product_detail` golden regeneration (**H5** widens it to two fixture files); `L-6`; the human-run duplicate audit with the corrected quoted-`"repositoryId"` query.

**Not safe until corrected:** freezing the Design Contract on this base (**B1**); implementing `mintOrReadDeployKey` (**B2**, its `T-H` success assertion, **H1**, **H2**); implementing `revokeRepositoryCredential` (**H7**, and **B3**'s read-path change must land first for state 4 to render); implementing `D-4`/`D-5` without the in-memory tier (**B4**) or the CAS-branch construct (**H3**); making the `G-7` wire change against a 7-row list (**H5**).
