# Report — Independent Design Review, deploy-key Design Revision 4 (Gate D3)

Persisted per `aef-orchestrator` §14. Reviewer: fresh `design-reviewer`, read-only.
REVIEWED_HEAD `361256c`; REVISION_ID `F2D5AF31-CA53-481A-ACB4-C75DB033A15A`. `main` at review time `43d328b`.

```
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
REVIEWED_HEAD: 361256c8948b00da7f0609a4f29cf075eef26ca2
BLOCKERS: B5, B6
HIGH: H8, H9, H10
MEDIUM: M3, M4, M5, M6, M7
LOW: L5 … L13
CORRECTION_REQUIRED: YES
HUMAN_DECISION_REQUIRED: NO
INDEPENDENT_RISK_LEVEL: 3
RISK_LEVEL_AGREEMENT: YES
```

> **Persistence note.** This report was returned and parsed but **not written to disk** before the
> correction lane was dispatched. The correction lane checked all 31 worktrees, the canonical repository,
> both plausible directory names and every commit reachable from any ref, found
> `tasks/design-review-addproduct-keys-rev4/` **empty**, and reported it as a **PROVENANCE_GAP** — then
> corrected against the Manager's relay of 18 findings with every finding's evidence re-verified against
> source. It also **corrected two of the relay's attributions against source**. This file is the
> authoritative copy. Same class of failure as the mobile rev-1 review earlier this session.

## Verified CORRECT

Provenance/B1 remedy (all nine cited SHAs are ancestors; `AGENTS.md` 199 lines with §13 at `:65`;
`LANES.md` 399 lines with the retraction at `:204-205`; both withdrawn Manager actions genuinely already
done). **B2's structural claim** — the compensation construct appears in exactly one place (§ R.5.7,
lines 830–899) with three references and no variant, and `T-I` does assert `resolve(handle)` returns the
material after a *successful* mint. **B3's conclusion** — `loadProductDetail` is
`control_plane_service.dart:360-367`, populated exclusively from `readActiveCredentialForRepository`;
`status` already declares `revoked`; `repositoryId` is already on the view; `readCredentialsForProduct`
exists on both tiers with the "including revoked ones" contract. **No new field, no migration.**
**B4's remedy** — Tier A and Tier B constructs genuinely distinct; § R.9.6 assigns tiers; § R.9.7 puts the
tier rule in the contract. **H1/H4/H7 closed.** **`G-13` real** — `saveProduct:92-99` and
`saveRepositoryReference:136-142` are both `ON CONFLICT DO UPDATE SET`. **`G-15` real** —
`CredentialIdentityConflictException` has 0 matches repository-wide. **`G-14`'s second instance** addressed
in § R.11.2.

**Citation discipline called "genuinely high"** — a long list of `file:line` refs confirmed exact, and
**no gap living only in prose**: every `G-3`…`G-15` and `L-6` appears in **all four** artifacts.

## B5 — the ADR amendment is NOT "Accepted by the human". It was a DRAFT.

The producer asserted acceptance in **at least thirteen places** — metadata `risk_rationale` R6,
`requirements_covered`, `changelog`; § 0.4; § R.10.3; § R.17.1 heading and body; § 9.1 R6; § 10; four places
in `report-revision-4.md`; matrix row 68 and § 4.

Its own amendment lane's metadata read `status: "DRAFT"`, `reviewed_by: null`, `approved_by: null`,
`human_gate: {required: true, level: 3}`, and `blocking_items: ["ADR 0018 status remains Proposed. This lane
does not declare it Accepted."]` — and its `design-revision.md:249` said *"Only the ADR owner may declare an
ADR accepted. This lane proposes the wording and the reason; it does not grant the authority."* **No
`.decisions/` object recorded an acceptance.**

**Consequence, and it is the finding's weight:** the published tally's single IMPROVED leg (R6) is
unsupported, so the true tally is **0 IMPROVED / 2 UNCHANGED / 4 WORSE**. `RISK_LEVEL: 3` is unaffected and
better supported. **Asserting a human acceptance that is not recorded is a manufactured human gate**, and
Gate D4 is the one this revision was heading toward.

## B6 — the corrected step 4 **bypasses ownership**, and no step produces the promised exception

`engine.readActiveCredential` (`product_registry_engine.dart:1135-1142`) opens with
`readRepositoryReference(repositoryId)` then `_ensureOwned(productId, repo.productId, …)` — but rev 4's own
H2 fix switched step 4 to `productRegistryStore.readActiveCredentialForRepository(repositoryId)`, a method
(`store:369-381`) with **no notion of a product and no `_ensureOwned` at all**. Line 2127's "by step 4
ownership is already established" is **false**: `addRepositoryReference` (`engine:150-170`) calls
`_store.readProduct(productId)` for **existence only**, never `_ensureOwned`, and under G-13's read-first
discipline the write is **skipped** whenever the reference already exists — so on exactly the cross-product
case, step 3 performs no write and no check. Line 2129's "does not bypass it" is also false: **choosing the
store method is the bypass.**

**`mintOrReadDeployKey(productId: 'A', repositoryId: <a repository of B>)` returns B's public key,
`credentialId`, `status` and `hostKeyStatus`** with `alreadyExisted: true` — a cross-product disclosure on
an endpoint rev 4's own § R.15.1 records as carrying no authentication (`server.dart:71-73`) and no loopback
pinning. **No step raises the `CrossProductAccessException` its error table promises.**

Fix: a normative ownership step, cheapest form being to compare `ref.productId` with `productId` before
deciding not to create, or call `engine.resolveRepository(productId, repositoryId)` (`engine:176-183`) and
treat its `RepositoryNotFoundException` as the create signal. State that step 3's read-first is **not** an
ownership check. Test on **both** tiers that a foreign id yields 403 and **no** field of the other
product's credential is returned.

**Same correction:** `saveRepositoryReference`'s conflict branch sets `"productId" = EXCLUDED."productId"`, so
an unguarded re-entry can **reparent another product's repository reference** — a column the recorded blast
radius omitted.

## H8 / H9 / H10 — the three fixes against B2, H3, H5

**H8** — § R.5.7 **FORM 2 violates obligation 4**: it never zeroes the buffer on any failure path. A `put`
throw propagates past `zero(privateHalf)`, and the `catch` ends in `rethrow`. § 10.2 item 1 checks
obligations 1 and 2; nothing checked 4, which is how it survived.
**H9** — `D-6`'s requirement names **EIGHT** durable-evidence columns; both tier constructs cover **SEVEN**,
dropping `lastFailureReason` — which exists and is nullable, and which the paragraph immediately below
reasons about explicitly. **An implementer following the constructs ships it erasable on both tiers.** The
uncommitted implementation applies `_noClear` to exactly those seven, so the code follows the seven.
**H10** — twelve rows across **SIX files**, not "eleven files" (wrong in five places), and § R.3.2 reconciles
them as "eleven **edit sites**" at one line and "**ten** code edits and two doc-comment edits" at another.

## M3–M7 and L5–L13

M3 `revokedAt`/`revokedReason` are **not** on the view · M4 selection rule under-specified twice, including
an ordering guarantee that exists on **one tier only**, and a "highest `version`" gloss that is wrong across
a rotation chain · M5 the amendment *is* an in-place edit of `docs/adr/**`, just uncommitted · M6 `77c19f1`
**is** an ancestor of `main`, 16 commits behind — B1's substance was staleness, not divergence · M7
`rotateCredential`'s `credentialId` is a **caller parameter**, so it is a second route to resurrection, and
the stated reason was a convention the domain does not enforce · L5 wrong step numbers · L6 "four
obligations" should be five · L7 the tally is not verbatim in the metadata · **L8 § R.11g item 7 inverts
`_buildFooter`'s definition and call site and mis-cites two neighbours, and claims mobile's
`TechnicalDetails` has no `note:` when `:925` is the desktop one that does — a binding consumption contract
pointing the sibling lane at the wrong lines** · L9 a blockquote silently truncates the comment it declares
falsified · L10 a second falsifiable comment unnamed · L11 `GAP-2` unmapped in the tier table · L12 a
citation slip · L13 **no SHA pins the reviewed content**.

## Risk level

Re-derived independently, reaching **3** on IA grounds: `898b07d0` makes a product visible before
registration commits and turns registration into a commit; `RegistrationCommitState` introduces a
five-state client model whose state 4 changes what the detail page asserts; § R.11g item 3 adds a resume
route. **Explicitly recorded, because the binary field cannot carry it: agreement on the level, not on the
rationale's arithmetic.**
