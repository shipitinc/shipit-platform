# Report — Independent Engineering Review, `fix-credential-identity-invariants`

Persisted per `aef-orchestrator` §14. Reviewer: `engineering-reviewer`, read-only.
REVIEWED_HEAD `0bf2fa0` (working tree; 8 files, +1271/-90, nothing committed).

```
RESULT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP
REVIEWED_HEAD: 0bf2fa0058bbbab12eeea43b4e6a50eadff07b4d
CORRECTION_REQUIRED: NO
BLOCKERS: none    HIGH: none    MEDIUM: 1    LOW: 4
```

## Gates — all re-run by the reviewer

format pass (134 + 32 files, 0 changed) · analyze pass "No issues found!" · unit pass `+148` ·
integration `+171 -1` (sole failure the dogfood `.git` file-vs-directory assertion) ·
schema guard pass, 18 `OK:` 0 `FAIL:`. **`NOT_RUN`: nothing.**

## The four pressed-on points

1. **The in-memory masking fix — the implementer's argument is CORRECT, and it closes a defect rather than hiding one.** The reviewer walked the full decision table for both tiers (mint/CAS × row-missing/row-present × material/scope/evidence/version). The tiers agree on the **outcome** in every reachable case; only the evidence-guard *message* differs. Critically, **the mint path is now total**: the identity guard fires for any existing row before anything else, so no mint-path write exists that could clear evidence — scoping the evidence guard to CAS removed a mask, it did not open a hole. The identity and scope refusal strings are **byte-identical across tiers**. The store contract was narrowed to say "A CAS write MUST NOT…" so the doc matches the behaviour.
2. **`_noClear`'s types — all seven verified against `20261006150645000/definition.sql`**; three are `timestamp without time zone` → `'timestamp'`, four are `text`. All correct. A loud Parse-time `42P08` on every CAS write, inside the integration suite, is the right mode: early, named, actionable, fails **closed**. No false positives either: both engine writes of `hostKeyFingerprint` pass a `required String`, and no path clears `revokedAt`.
3. **Tier ordering — genuinely forced, and the message is accurate.** `DO NOTHING` has no `WHERE`, so a different-material and an identical-material re-mint are indistinguishable to the statement; predicating on material differing would restore the very re-point D-1 closed. The message states a true fact (the id **is** taken), does not falsely claim the material was fine, and gives the correct single remedy. The concurrency test pins that this stays distinct from D-2's active-index refusal.
4. **The design's § R.9.3 sentence is a genuine design bug.** Verified: the mint path builds the row with `hostKeyStatus` defaulting to `unknown` and no `hostConfirmedAt`, and `$assignments` wrote those pre-fix — so re-pointing **destroyed** repo-1's confirmation rather than carrying it. True only of the CAS branch. Both behaviours contradict **ADR 0018 `:96-99`**. The D-5 requirement is unaffected and the code is correct; the prose needs a design-lane correction.

## Pre-fix failures captured independently

**In-memory: 6 of 6 red** (the implementer's "5 of 6" *understated* its own test strength).
**Real Postgres: `+164 -8`** — dogfood plus **exactly 7** new tests red. The concurrency failure reproduced
verbatim: `WhereTypeIterable<RepositoryCredential>` **has length of 2** — *both callers returned success*.
Pre-existing T-A, T-B, M-2, GAP-2 ×2, rotation and first-mint stayed green.

## No regression to D-1 / D-2

Byte-diffed the CAS branch's four-field predicate: **only** `'AND "referenceName" = @referenceName',` →
`...' '` — a trailing comma became a trailing space, otherwise byte-identical and still present.
`git diff -- apps/server/migrations` is **empty**. The SQLSTATE-plus-constraint-name translation is intact.
Guard coverage went 16 → 18 `OK:`, **added** coverage and removed none. `product_registry_engine.dart` has
**zero** non-comment changed lines.

## LOW-1 / LOW-2 judged

LOW-1 catches what it claims — mutating a mirror confirms exit 1 on WHERE-predicate drift, key-column drift
and table drift. LOW-2 is real and sufficient: planting the index name in a generated `definition.sql` is
caught; adding a 5th object to `required_objects` alone fails **four** checks, so it cannot be silently
forgotten; emptying the array fails closed. `rotateCredential` verified on both tiers — revokes then mints a
new `credentialId`, landing at `HostKeyStatus.unknown` with null confirmation fields, satisfying ADR 0018.

## The MEDIUM — a real gap in the new guard

`verify_schema_bootstrap.sh:267` — the `IF NOT EXISTS` normalisation in the new full-DDL comparison
**forgives the one divergence in that clause that breaks the chain path.** **Proven:** deleting
`IF NOT EXISTS` from `20261006150645000`'s credential index leaves the guard at exit 0; deleting it from the
bootstrap asset also leaves exit 0.

That clause is **not free to differ for this object**: `20261006150645000`'s own comment states both copies
carry `IF NOT EXISTS` *"because a database that was created fresh and has since had the bootstrap applied
already carries this index, and replaying this migration onto it must be a no-op rather than an error."*
Dropping it makes that migration fail on exactly the bootstrapped database it was written to survive. Both
files carry it today, so **nothing is broken now — this is a gap in the guard, not a live defect.** The
blanket normalisation is needed for the *other* index (asset has the clause, `20260920232118956` does not —
verified), which is the legitimate case; it is wrongly applied to the credential index too, and the guard's
own comment is self-contradictory (it justifies removing the clause by the chain path needing not to fail,
which is an argument that the clause must be there).

**Fix:** keep whitespace collapse as the only blanket normalisation and make the idempotence clause an
explicit per-object expectation — assert both homes carry it for
`product_credential_active_repository_unique`, and the asset-only clause for
`design_revision_approved_unique_per_work_item`. Add a negative control that drops the clause from
`20261006150645000` and asserts exit 1.

## LOW

1. `product_registry_store.dart:82-84` — the authoritative durable-evidence contract names **six** columns
   while **both tiers enforce seven**: `hostKeyFingerprint` is guarded in
   `in_memory_product_registry_store.dart:281` and in the Postgres `_noClear` list and readback loop, but is
   absent from the prose. No behavioural divergence, but a future implementer reading only the contract would
   conclude clearing the host fingerprint is permitted.
2. `report.md` "Files changed" — line counts wrong on 5 of 8 entries, and
   `product_credential_immutability_postgres_test.dart` is labelled `A` when it exists at `0bf2fa0` and is `M`
   (+478/-5 actual). The gate table's "19 OK:" is 18. **Cosmetic, but this report is the provenance record for
   an uncommitted change and the misclassification hides that the file already carries D-1/D-2's tests.**
3. `product_credential_immutability_postgres_test.dart:100-114` — the prefix purge closes the leak class **by
   convention**: it works because every id this file creates carries `credimm-`. A future test here
   re-pointing to a non-prefixed id leaks again, surfacing as a `createProduct` unique-constraint failure in
   the **next** test rather than as itself — loud, not silent, so acceptable. Stronger closure: track the ids
   the suite created and delete by that set, or key on `referenceName LIKE 'GIT_PRODUCT_CREDIMM%'`.
4. **Learning** — nothing persisted to `docs/engineering/learning/`. Two durable discoveries are recorded
   only as colocated code comments: the Serverpod `Type.unspecified` binding that makes a bare
   `@param IS NOT NULL` fail at Parse with `42P08` (**this generalises to EVERY raw-SQL parameter in
   `apps/server`**, so it is worth a PROJECT_FACT entry), and the shared-database teardown lesson
   (QA_DISCOVERY). Mitigating: the preceding lane touched zero `docs/` files, and `LEARNING_POLICY` prefers
   executable knowledge.

## Test hygiene

No `skip:`, `tags:`, `@Skip`, `expectedFailure`, `only(`, `xtest`, `@Timeout` or `TODO` anywhere in the diff.
No test removed or weakened. The 5 removed lines are 2 comment lines plus 3 exact-match `DELETE`s **replaced
by prefix `DELETE`s** — strictly broader cleanup. `tmp_tokenizer_diag_test.dart` confirmed gone with no
residue. The `credimm-` prefix is unique to this suite, so the prefix purge cannot reach another file's rows.

## Docker disclosure — no breach

`make test-integration` **three times** and no other Docker or Compose command — not `down`, `stop`, `rm`,
`prune`, `up`, `pull`, `build`, `--rmi`, and not `docker info`, `compose ps`, `compose logs` or `compose
config`. Never `make clean`, `test-env-down`, `e2e-down`, or a bare `down -v`. Each run reported
`Container … Removed` / `Network … Removed` for its own `shipit_integration_<pid>` project, no
`CLEANUP FAILED`. The reviewed worktree and `main` left byte-identical; all mutation experiments ran in
throwaway copies outside the workspace, now deleted.

**Usability note worth knowing:** the target's trap reports `nothing to remove` while `make` still prints
`Error 2` from the recipe — harmless, and the same trap that reported successful removal on every other run.

## HUMAN_DECISION_REQUIRED: YES

- **`design-revision-3.md` is UNCOMMITTED and UNAPPROVED**, existing only as an untracked file in
  `design-correct-addproduct-keys`' worktree at `77c19f1`. D-4/D-18/D-5 cannot land with reviewed provenance
  behind them until it is committed and independently approved. A governance gate, not a code defect; **no
  correction lane can discharge it.**
- **§ R.9.3:937-941 is factually wrong about the mint path** — design-owner scope, routed to the design lane.
  The D-5 requirement and the code are correct.
- Carried forward unchanged: the duplicate-credential audit must be run by a human against every deployed
  database before migration `20261006150645000`.
- Outstanding: `CredentialIdentityConflictException` was not created because `exceptions.dart` is outside
  `OWNED_PATHS`. Behaviour is complete (a distinct greppable reason, mapped to a typed 500 per the design's
  table, so no API change). Closing it needs an ownership grant.

## SAFE_PARALLEL_WORK

- The MEDIUM guard fix touches **only** `verify_schema_bootstrap.sh` and its comments — disjoint from every
  Dart file in this change. **Safe in parallel.**
- LOW-1..3 are comment- or doc-only, except the store-contract line at `product_registry_store.dart:83`,
  which is in a file this change owns and must be sequenced after it (one-line comment edit, no behaviour).
- **NOT safe in parallel:** any edit to `postgres_product_registry_store.dart`,
  `in_memory_product_registry_store.dart`, `schema_bootstrap.sql`, or either test file — those are this
  change's exact `OWNED_PATHS` and every finding is stated against their exact bytes.
- The design-prose correction is a different lane with a different worktree; it may proceed independently,
  **but the design must be committed and approved before this change merges.**

## Bottom line

The three defects are genuinely closed, and the reviewer proved it rather than taking the report's word —
all 13 new tests independently red on pristine base, including the concurrency test where **both callers
won**. The implementer's masking-defect reasoning is sound and its self-report **understated** its own test
strength. One real gap: the new DDL-parity check forgives exactly the `IF NOT EXISTS` divergence that would
break the credential index's migration on a bootstrapped database. Non-blocking, precisely scoped, with a
proven fix.
