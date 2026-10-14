BEGIN;

--
-- SHIPIT CONTROL PLANE REPAIR: twelve work items filed under a product that
-- does not exist.
--
-- THE DEFECT, MEASURED. `product` holds exactly one row in QA --
-- `shipit-platform`, state `governed`, with an `onboarding_record` pinning a
-- durable product clone at f58d6fb129c1d4265ada5af9dc359eb5ac27a9a2. There is
-- no `defects` product row, and no migration in this repository creates one.
-- Twelve `work_item` rows carry `productId = 'defects'` anyway.
--
-- WHY THAT IS A TOTAL DISPATCH BLOCK, NOT A COSMETIC ONE. The implementation
-- readiness probe
-- (apps/server/lib/src/implementation/implementation_readiness_probe.dart)
-- resolves `item.productId` against the product registry and DEFERS on a miss:
--
--   * :308  `implementation.deferred.product_state_unreadable`
--   * :316  `implementation.deferred.product_missing`
--   * :326  `implementation.deferred.product_not_governed`
--
-- For these twelve the second of those applies -- there is no product row to
-- read a state from -- so the probe returns a deferral and the implementation
-- lane builds no dispatch request. Seven of them sit at `implementation_ready`,
-- which IS `implementFeatureDefinition.entryStates`
-- (packages/scheduler/lib/src/implement_feature.dart:108) and is otherwise
-- perfectly dispatchable. The probe is behaving correctly: an item scoped to a
-- product that does not exist has no code to be built in.
--
-- WHERE 'defects' CAME FROM, AND WHY IT IS NOT WHAT IT LOOKS LIKE.
-- `'defects'` is not a stray string that landed in these rows. It is the
-- constant `defectTriageBucketProductId`
-- (apps/server/lib/src/triage/lane_a_defect_triage_work_item.dart:17), and its
-- doc comment states what it is: a synthetic TRIAGE BUCKET, deliberately not a
-- product, used when a defect carries no resolvable
-- `defect.affectedWorkItemId -> work_item.productId` link. Both provisioners
-- fall back to it the same way --
-- `DefectTriageWorkItemProvisioner._resolveProductId`
-- (lane_a_defect_triage_work_item.dart:379-395) and
-- `resolveDesignRemediationProductId`
-- (lane_e_design_remediation_work_item.dart:59-80) -- which is why a triage item
-- and its design remediation always agree.
--
-- The defect behind these twelve came from a bug-report surface, which carries
-- no work item, so the fallback fired. The bucket was RIGHT for that design:
-- it is what the provisioners do when there is nothing to resolve. What is
-- wrong is that the product was already known and neither provisioner looked
-- at it. `Defect.productId` exists and is populated -- `createDefect` takes it
-- as a required parameter and refuses a product that is not registered
-- (apps/server/lib/src/services/control_plane_service.dart:1142
-- `_requireRegisteredProduct`) -- so every one of these defects already carries
-- an authoritative, registry-backed product, and the work item it produced is
-- filed somewhere else anyway. The two doc comments that explain why
-- ("`Defect` carries no `productId` and the `defect` table has no such
-- column", lane_a:9-11 and lane_e:43-46) are STALE: the column was added and
-- the comment was never updated. That is the root cause, it is a provider bug,
-- and it is in `apps/server/lib/**` -- OUT OF SCOPE for this migration.
--
-- CONSEQUENCE, STATED PLAINLY, BECAUSE IT DECIDES WHAT THIS IS WORTH. THIS
-- REPAIR DOES NOT STOP THE CLASS. The provisioner still resolves the product
-- the old way, so the next bug report filed without a work item produces a
-- thirteenth row under `defects`, and the one after that a fourteenth. This
-- migration unblocks twelve specific items; it does not make the bucket
-- resolvable. The follow-up is to teach both provisioners to fall back to
-- `defect.productId` BEFORE the bucket, and to correct the two stale comments.
-- Do not read this migration as having fixed defect intake.
--
-- HUMAN DECISION `b366bba0` IS NOT IN CONFLICT WITH THIS, AND WHY THAT IS
-- WORTH SAYING OUT LOUD. That decision (RESOLVED, ARCHITECTURE,
-- `human-operator`, `.decisions/b366bba0-bd53-4090-932e-39e231819777.yaml`)
-- chose OPTION_B for the triage bucket: give the bucket a real registry row and
-- a lifecycle, rather than carve it out or block it. Its stated premise was
-- that a defect with no resolvable `affectedWorkItemId` has NO product to file
-- under -- which was true when the bucket was designed and is no longer what
-- the data says, because `defect.productId` arrived afterwards and
-- `createDefect` now makes it mandatory and registry-checked. The bucket's
-- remaining legitimate case is a defect with NEITHER a product nor a work item,
-- and these twelve are not that case: their defects carry a real product, which
-- is the value this migration moves them to. Nothing here exempts the bucket,
-- promotes it, or narrows `b366bba0`; the bucket's lifecycle work is still
-- owed and is untouched by this file.
--
-- TARGETING. TWELVE LITERAL IDS, AND NOTHING ELSE MAY SELECT A ROW.
--
-- `workItemId IN (...)`, each paired with the product id it is expected to
-- carry, is the whole selection. There is deliberately NO `productId =
-- 'defects'` arm in the UPDATE. A predicate over a column value is safe only
-- at the instant it was written and silently widens on every subsequent apply:
-- it would sweep up any defect triaged under that name after this migration
-- was dispatched, and repoint work nobody had looked at. The list was read off
-- QA at dispatch, and the `expectedProductId` beside each id is the value that
-- row held then.
--
-- The list is declared EXACTLY ONCE. `shipit_product_repoint_target` below is
-- the single definition of the target set, and the fail-loud guard, the
-- linkage guard, the orphan sweep, the audit row and the UPDATE all read it.
-- Spelling twelve ids a second time in the guard is how a guard and the
-- statement it guards drift apart and end up testing a different set than the
-- one being written -- which is a guard that passes for the wrong reason.
-- `ON COMMIT DROP` and the surrounding transaction mean the table cannot
-- outlive this migration in any session.
--
-- THE `expectedProductId` ARM AND THE AUDIT-ROW ARM ARE BOTH THE
-- IDEMPOTENCE, AND THEY ARE NOT REDUNDANT. After this migration no enumerated
-- row carries 'defects' any more, so the value arm matches nothing on a second
-- apply. The audit-row arm is what also holds under a FORCED replay of the file
-- against items the scheduler has since moved on, exactly as
-- 20261014093000000 found necessary: that migration's state arm alone stopped
-- matching once an item left the stranded state, and a replay would have
-- repaired it twice. Both arms are re-asserted in the UPDATE next to
-- `version`, for the reason 20261012150000000 re-asserted its state there: a
-- concurrent writer that re-filed a row between the guard and the UPDATE must
-- not be overwritten, and the row count is checked against the eligible count
-- so a partial repair aborts instead of leaving eleven of twelve moved.
--
-- FAIL LOUDLY, REFUSING RATHER THAN SKIPPING. A silent skip on a changed
-- dataset is how a repair becomes a lie, so each enumerated id is classified
-- and only two outcomes are tolerated:
--
--   * it carries `expectedProductId` -> eligible, and moves;
--   * it already carries the destination -> already repointed, by this
--     migration or by a human, and needs nothing.
--
-- Anything else RAISES and names the offending id, rolling all twelve back
-- together: a row that does not exist, a row filed under some third product, a
-- row that was deleted or re-filed under us between dispatch and apply. None of
-- those is "nothing to do" -- each means the dataset is not the one this
-- migration was written against, and an operator has to look.
--
-- The destination is checked BEFORE anything is written, and on the same
-- condition the readiness probe defers on: `shipit-platform` must EXIST and be
-- `governed`. Repointing onto a missing product would recreate the exact defect
-- being repaired; repointing onto a paused one would give twelve items a
-- product id that LOOKS right while every one of them still deferred on
-- `product_not_governed`, and the wrong product id would no longer be the
-- thing to look at. Refusing here is what turns a guessed destination into a
-- checked one.
--
-- THIS GUARD HAS A COST THAT IS NOT A BUG, AND IT BIT TWICE. A chain-replayed
-- schema carries no `product` row, because no migration in this repository
-- inserts one -- `product` rows are created by the application, not by a
-- migration. So on a schema built from `definition.sql` alone this migration
-- REFUSES, by design: there is no governed product to point twelve work items
-- at, and writing them anyway would be the fabrication the guard exists to
-- prevent. Two chain-replay harnesses
-- (`test/integration/stranded_key_repair_migration_test.dart` and
-- `test/integration/onboarding_workspace_postgres_test.dart`) seed a registry
-- row before replaying this file, exactly as they already seed work items and
-- jobs. An operator who sees `product-repoint refused: destination product
-- shipit-platform does not exist` on a real deployment is being told the
-- registry is empty, not that this migration is malformed.
--
-- THE TWO `design-remediation-*` ROWS MOVE WITH THEIR PARENTS, AND THE
-- LINKAGE IS VERIFIED HERE RATHER THAN ASSUMED. It is carried on the work item
-- itself, by three routes that the producer writes in one place
-- (apps/server/lib/src/triage/lane_e_design_remediation_work_item.dart):
--
--   * the ID, `designRemediationWorkItemId(defectId)` = 'design-remediation-$id'
--     (lane_e:39-40), which is what makes `ensurePersisted` idempotent;
--   * `featureRef` = the defect id on the remediation item (lane_e:208) AND on
--     the parent's triage item (lane_a_defect_triage_work_item.dart:260) -- the
--     same `createWorkItem` call that writes the id writes the featureRef, so
--     an id and a featureRef that disagree mean the row did not come from that
--     producer;
--   * `metadataJson.defectId`, NOT read here -- see METADATA IS NOT READ.
--
-- The first route is PROVABLE FROM THE ROW EXISTING and the guard leans on it:
-- `designRemediationWorkItemId` is a pure function of the defect id, so a row
-- whose id is `design-remediation-DEF-X` is evidence that a defect `DEF-X`
-- existed and was provisioned through that function. The guard below requires
-- all three of the things checkable without parsing free text: that the id
-- yields a defect id; that the remediation's own `featureRef` equals it; and
-- that the derived parent `defect-<id>` is itself a member of the target set
-- AND carries the same `featureRef`. A remediation row whose parent is absent
-- from the set RAISES rather than moving alone, which is the "must not move
-- independently of its parent" case: an orphan remediation filed under a
-- repaired product while its parent stayed behind would be a worse record than
-- the one being repaired.
--
-- `defect.remediationWorkItemId` EXISTS as a column and is deliberately NOT
-- read. It is a nullable link on the defect row that no code path in this
-- repository writes, so its value in any given database is not established
-- here and the guard does not depend on it. Reading it would be reading an
-- unpopulated column as if it were an authority.
--
-- METADATA IS NOT READ, AND WHY. `metadataJson` also carries
-- `designRemediationRequest.productId`, and that copy is still `"defects"`.
-- It is not corrected here, for two reasons that are stated rather than
-- glossed: this migration changes `productId` and nothing else (see WHAT IS
-- AND IS NOT WRITTEN), and `work_item.metadataJson` is nullable free text that
-- is NOT guaranteed to hold parseable JSON -- `WI-feature-1791686174076431`
-- carries the EMPTY STRING, and `''::jsonb` raises. 20261014093000000 documents
-- the whole shape of that hazard at length. The stale copy is recorded here so
-- that it is a KNOWN stale copy rather than an undiscovered one.
--
-- NO ORPHANS, CHECKED ACROSS EVERY TABLE THAT HAS A `productId` COLUMN, AT
-- APPLY TIME. ELEVEN tables in this schema carry such a column --
-- `clarification_request`, `defect`, `design_revision`, `onboarding_record`,
-- `product`, `product_baseline`, `product_credential`, `product_registry_audit`,
-- `repository_reference`, `standing_policy`, `work_item` -- read off
-- `definition.sql` for this migration. Rather than bake that list into the
-- file, where a table added later would not be checked at all, the migration
-- sweeps `information_schema` for every base table carrying a `productId`
-- column and REFUSES if any of them other than `work_item` still holds a row
-- under 'defects' -- or if `work_item` holds one outside the enumerated twelve.
-- That converts a one-time measurement into a standing invariant OVER ROWS
-- OUTSIDE THE ENUMERATED SET: if the repair ever becomes incomplete by a
-- thirteenth row appearing under the bucket, the migration that would have
-- completed it will not run to completion without saying so.
--
-- THAT INVARIANT DOES NOT HOLD FOR AN ENUMERATED ROW HAND-REFILED BACK UNDER
-- THE BUCKET, AND THE GAP IS RECORDED RATHER THAN PAPERED OVER. The sweep
-- excludes the twelve by construction -- it counts `work_item` rows under the
-- bucket only OUTSIDE the set -- and the audit-row arm then excludes them from
-- `eligible` too. So an enumerated row hand-re-filed back to `defects` after
-- this migration has run is classified ELIGIBLE by guard (c), skipped by the
-- sweep, excluded from the UPDATE by the audit-row arm, reported as
-- `moved = 0 = eligible`, and the migration SUCCEEDS with that one item left
-- under a product that does not exist -- deferring on
-- `implementation.deferred.product_missing` for ever, with a SUCCESS in the log
-- saying nothing was wrong. The forced-replay test in
-- `apps/server/test/integration/product_repoint_migration_test.dart` codifies
-- that behaviour DELIBERATELY: the audit row must win over the value, or a
-- hand re-file would be silently repointed a second time. The two properties
-- are in genuine tension and this file chooses the audit row.
--
-- REACHABILITY TODAY IS NONE, through the two producers that file under the
-- bucket: `DefectTriageWorkItemProvisioner._persist`
-- (apps/server/lib/src/triage/lane_a_defect_triage_work_item.dart:229-232)
-- and lane_e's `ensurePersisted`
-- (apps/server/lib/src/triage/lane_e_design_remediation_work_item.dart:172-186)
-- both READ the row before creating it and only create when it is absent, so
-- neither writes over a row that already exists. The hazard that would open
-- this gap is in the STORE, not in the producers, and is recorded here so the
-- follow-up that fixes the provisioners sees it too:
-- `WorkflowStore.saveWorkItem` called WITHOUT `expectedVersion`
-- (apps/server/lib/src/persistence/postgres_workflow_store.dart:126-145,
-- signature at :45) issues `ON CONFLICT ("workItemId") DO UPDATE SET` naming
-- EVERY column -- `"productId" = EXCLUDED."productId"` among them -- so such a
-- call rewrites `productId` unconditionally, with no version check at all, and
-- would re-file a repointed row back under the bucket. With `expectedVersion`
-- supplied it takes the versioned `UPDATE ... WHERE "version" = @expected`
-- branch at :61-82 instead and cannot. That call site is in
-- `apps/server/lib/**` and is OUT OF SCOPE for this migration.
--
-- A LATE ARRIVAL STOPS THIS MIGRATION; IT DOES NOT WIDEN IT. Given the
-- provisioner above, a thirteenth row under 'defects' between dispatch and
-- apply is an EXPECTED outcome, not a hypothetical one -- and the sweep above
-- turns that expectation into a refusal with the table and the count named,
-- rather than a silent partial repair. The operator's next step is to extend
-- the target list below and re-dispatch, never to relax the sweep.
--
-- WHAT IS AND IS NOT WRITTEN. `work_item."productId"`, `"updatedAt"` and
-- `"version"` on the twelve enumerated rows, one `work_item_transition` audit
-- row per row actually repointed, and NOTHING ELSE -- in `work_item` or in any
-- other table. In particular:
--
--   * `state` is NOT touched. Seven items keep `implementation_ready`, three
--     keep `agent_completed`, two keep `planned`.
--   * `metadataJson` is NOT touched -- including `triageAttempt`, which is the
--     SHARED re-work discriminator. See WHAT WILL NOT CHANGE.
--   * No `defect`, `job`, `worker_execution`, `agent_execution`,
--     `model_execution_record`, `design_revision`, `onboarding_record`,
--     `product_baseline`, `product_credential`, `repository_reference`,
--     `clarification_request`, `standing_policy` or `product_registry_audit`
--     row is read for update or written.
--
-- THE AUDIT ROW, AND WHY `fromState` EQUALS `toState`. One
-- `work_item_transition` row per repointed item, deterministic id
-- `tr-product-repoint-<workItemId>`, so the repair leaves the same durable
-- record every other repair in this repository leaves -- this one is the only
-- change in the set, and the ledger is where an operator looks for it. Both
-- state columns carry the item's UNCHANGED state, so `fromState = toState`, and
-- the `reason` says so in those words rather than implying an edge that does
-- not exist. The columns are not lying: they record where the item was and
-- where it still is. Nothing reads them as an edge --
-- `WorkItemFailureView` selects on `toState == agentFailed`
-- (apps/server/lib/src/endpoints/work_item_action_endpoints.dart:948-950), the
-- detail view renders history, and the operator-retry budget counts
-- `operator_action` rows, not transitions
-- (work_item_action_endpoints.dart:1003-1006) -- so an equal pair is inert to
-- every current reader while remaining readable to a person.
--
-- `version` is incremented and `updatedAt` set, exactly as a real write sets
-- them, so the engine's compare-and-swap on `version` still behaves against a
-- row this migration touched.
--
-- WHAT A NO-OP RESULT WOULD MEAN. If the migration repoints zero rows on a
-- first apply, it did not find the dataset it was written against and the
-- guard should have said why: the ids were re-filed, or the product registry
-- moved. If it repoints zero rows because every enumerated id already carries
-- 'shipit-platform', that is a completed repair or a hand fix, and nothing
-- further is owed. The `RAISE NOTICE` at the end reports both counts, so the
-- difference is visible in the migration log rather than inferred.
--
-- WHAT WILL NOT CHANGE. Stated here because a dispatch that expects twelve
-- moving items to start dispatching would otherwise report a false success:
--
--   * THREE items will not be AUTOMATICALLY re-routed. Read the word
--     `automatically` as doing the work: what `maxImplementationInflows`
--     bounds is the AUTOMATIC completion inflow, not every route into the
--     implementation lane, and a HUMAN can still act on these three wherever
--     their producer left a commit. The three at
--     `agent_completed` carry `triageAttempt` 3, 4 and 4, and the OD-10
--     completion inflow refuses to route an item whose SHARED re-work
--     discriminator reads at or above `maxImplementationInflows = 3`
--     (packages/scheduler/lib/src/implementation_inflow.dart:264,
--     packages/scheduler/lib/src/scheduler.dart:926-940). That discriminator
--     is `metadata.triageAttempt`, which this migration does not touch, and it
--     is shared with operator retry and with resolved rework/reject decisions
--     -- so these items may never have entered the lane at all. Clearing the
--     marker to unblock them would silently defeat that bound rather than fix
--     anything, and is exactly the change this migration is scoped to exclude.
--     Depending on whether their producer left a commit, each either completes
--     review normally or is parked at a blocking `engineeringReview`
--     HumanDecision for a human
--     (apps/server/lib/src/review/engineering_review_gate.dart:328-337).
--   * TWO items will still not dispatch, for a different and legitimate
--     reason: `planned` is in NO `JobDefinition.entryStates` in this
--     repository -- the only wired sets are `designNotRequired`,
--     `designApproved`, `designRequired`, `designRejected`, `designInReview`,
--     `agentCompleted`, `implementationReady` and `reviewRejected`
--     (`triageDefectDefinition.entryStates`,
--     packages/scheduler/lib/src/triage_defect.dart:58-62). The two
--     `design-remediation-*` rows stop at `planned` by design (ADR 0021,
--     `EXTERNAL_DESIGN_GOVERNANCE_DEPENDENCY`) until the design governance
--     runtime exists. Repointing them is correct -- they are owned by this
--     product -- and it is not a dispatch.
--
-- SAFETY / DATA LOSS: this migration deletes nothing and overwrites no
-- payload. It rewrites one column on twelve named rows, from a value that
-- names a product which does not exist to one that does, and it refuses rather
-- than guesses. Every statement is inside the surrounding transaction, so a
-- failure rolls back the repoint, the version stamps and the audit rows
-- together -- there is no reachable state in which eleven items were repointed
-- and the twelfth was not, and none in which a row moved with no audit row
-- describing it.
--

-- `DROP ... IF EXISTS` is belt-and-braces for a replay inside ONE session:
-- `ON COMMIT DROP` already covers the committed and the rolled-back paths, and
-- this covers neither having run yet.
DROP TABLE IF EXISTS "shipit_product_repoint_target";
DROP TABLE IF EXISTS "shipit_product_repoint_dest";

CREATE TEMP TABLE "shipit_product_repoint_target" (
    "workItemId"        text PRIMARY KEY,
    "expectedProductId" text NOT NULL
) ON COMMIT DROP;

CREATE TEMP TABLE "shipit_product_repoint_dest" (
    "productId" text PRIMARY KEY
) ON COMMIT DROP;

-- THE DESTINATION. Declared once, read by the guard's two refusals, the
-- UPDATE's SET and the audit row, so the product the migration CHECKS is
-- governed is by construction the product it WRITES.
INSERT INTO "shipit_product_repoint_dest" ("productId") VALUES ('shipit-platform');

-- THE TARGET SET. Twelve ids, each with the product id it held when this set
-- was read off QA at dispatch. Changing a row here changes what the migration
-- does; there is no second copy of this list anywhere in the file.
--
--   workItemId                              productId  state                  triageAttempt
--   defect-DEF-1791684557133597              defects    implementation_ready   2
--   defect-DEF-1791684804452198              defects    agent_completed        4
--   defect-DEF-1791685024220546              defects    implementation_ready   2
--   defect-DEF-1791685264570406              defects    implementation_ready   2
--   defect-DEF-1791685401972067              defects    implementation_ready   3
--   defect-DEF-1791685722309971              defects    implementation_ready   2
--   defect-DEF-1791685924503981              defects    implementation_ready   2
--   defect-DEF-1791686085546076              defects    agent_completed        3
--   defect-DEF-1791686357139031              defects    implementation_ready   3
--   defect-DEF-1791686704991884              defects    agent_completed        4
--   design-remediation-DEF-1791685264570406  defects    planned                absent
--   design-remediation-DEF-1791686085546076  defects    planned                absent
--
-- NOT IN SCOPE, and matched by no predicate in this file: the two
-- `WI-feature-*` items, which already carry `shipit-platform`. They are the
-- evidence that the destination product is reachable and that these twelve are
-- the anomaly rather than the rule.
--
-- The `state` and `triageAttempt` columns above are recorded so an operator
-- reading this file can tell what each item was left holding. Neither is a
-- precondition here and neither is compared: `state` is not written, and
-- `triageAttempt` lives in `metadataJson`, which this migration does not
-- touch. The pair is written down precisely so that nobody later reads an
-- absent `state` arm as an oversight -- an item that moved on between dispatch
-- and apply is still repointed, because being filed under a product that does
-- not exist is wrong regardless of what state it has reached.
INSERT INTO "shipit_product_repoint_target" ("workItemId", "expectedProductId")
VALUES
    ('defect-DEF-1791684557133597', 'defects'),
    ('defect-DEF-1791684804452198', 'defects'),
    ('defect-DEF-1791685024220546', 'defects'),
    ('defect-DEF-1791685264570406', 'defects'),
    ('defect-DEF-1791685401972067', 'defects'),
    ('defect-DEF-1791685722309971', 'defects'),
    ('defect-DEF-1791685924503981', 'defects'),
    ('defect-DEF-1791686085546076', 'defects'),
    ('defect-DEF-1791686357139031', 'defects'),
    ('defect-DEF-1791686704991884', 'defects'),
    ('design-remediation-DEF-1791685264570406', 'defects'),
    ('design-remediation-DEF-1791686085546076', 'defects');

--
-- FAIL LOUDLY. Refuse the whole migration, naming every offending id, table
-- and linkage, rather than repoint a dataset this file was not written
-- against.
--
-- Every check below RAISEs rather than skipping. `work_item."productId"` is
-- `text NOT NULL`, so a NULL actual value can only mean the row is absent --
-- which is why the missing-row test is written against NULL and not against an
-- empty string.
--
-- The orphan sweep reads `information_schema` for EVERY base table carrying a
-- `productId` column rather than for a list named here, so a table added after
-- this migration was written is still swept. It filters on `current_schema()`
-- and qualifies nothing, so it resolves through `search_path` -- the same way
-- every unqualified table name in this file resolves -- rather than being
-- pinned to `public`, which would make it read the wrong schema in any
-- deployment whose tables are not there. The `pg_` exclusion is belt-and-braces:
-- `current_schema()` does not return a temp schema, but the two temp tables in
-- this migration BOTH have a `productId` column, and a sweep that ever reached
-- them would count the destination row and refuse on itself.
DO $guard$
DECLARE
    dest                text;
    dest_state          text;
    c                   record;
    classified          record;
    offenders           text := '';
    linkage_offenders   text := '';
    orphan_offenders    text := '';
    stray_rows          bigint;
BEGIN
    SELECT "productId" INTO dest FROM "shipit_product_repoint_dest";
    IF dest IS NULL THEN
        RAISE EXCEPTION
            'product-repoint refused: the destination table is empty, so there '
            'is no product to repoint onto. Nothing was changed.';
    END IF;

    -- (a) THE DESTINATION MUST EXIST.
    SELECT p."state" INTO dest_state FROM product p WHERE p."productId" = dest;
    IF NOT FOUND THEN
        RAISE EXCEPTION
            'product-repoint refused: destination product % does not exist in '
            'the product table, so repointing these work items would recreate '
            'the defect being repaired -- the readiness probe would defer every '
            'one of them on implementation.deferred.product_missing. Nothing '
            'was changed.',
            dest;
    END IF;

    -- (b) THE DESTINATION MUST BE GOVERNED.
    IF dest_state IS DISTINCT FROM 'governed' THEN
        RAISE EXCEPTION
            'product-repoint refused: destination product % is %, and only a '
            'governed product may have work dispatched against it. Repointing '
            'now would give these items a product id that LOOKS correct while '
            'every one of them still deferred on '
            'implementation.deferred.product_not_governed -- and the wrong '
            'product id would stop being the thing to look at. Nothing was '
            'changed.',
            dest, dest_state;
    END IF;

    -- (c) EVERY ENUMERATED ID MUST BE A ROW THIS MIGRATION CAN MOVE. Two
    -- outcomes are tolerated and nothing else: it carries its expected product
    -- id, or it already carries the destination. A third outcome -- a missing
    -- row, or a row under some other product -- means the dataset moved under
    -- this file and an operator has to look before anything is written.
    FOR classified IN
        SELECT t."workItemId",
               t."expectedProductId",
               w."productId" AS "actual"
          FROM "shipit_product_repoint_target" t
          LEFT JOIN work_item w
            ON w."workItemId" = t."workItemId"
         ORDER BY t."workItemId"
    LOOP
        IF classified."expectedProductId" = dest THEN
            -- Cheap invariant, and it catches the worst plausible edit to this
            -- file: an expected value equal to the destination makes every arm
            -- below trivially satisfied and the migration a silent no-op that
            -- reports success.
            offenders := offenders
                         || classified."workItemId"
                         || ' [expectedProductId equals the destination, so it '
                         || 'could never move], ';
        ELSIF classified."actual" IS NULL THEN
            offenders := offenders
                         || classified."workItemId"
                         || ' [no such work_item row], ';
        ELSIF classified."actual" = classified."expectedProductId" THEN
            NULL;  -- eligible
        ELSIF classified."actual" = dest THEN
            NULL;  -- already repointed; this is the idempotent re-run case
        ELSE
            offenders := offenders
                         || classified."workItemId"
                         || ' [productId is '
                         || classified."actual"
                         || ', expected '
                         || classified."expectedProductId"
                         || ' or '
                         || dest
                         || '], ';
        END IF;
    END LOOP;

    -- (d) EVERY REMEDIATION ROW MUST MOVE WITH ITS PARENT. `featureRef` is a
    -- plain text column carrying no JSON, so reading it raises on nothing --
    -- which is why the linkage is checked here and the `metadataJson` copy of
    -- the same relationship is not.
    FOR c IN
        SELECT t."workItemId",
               substring(t."workItemId" from '^design-remediation-(.+)$') AS "suffix",
               w."featureRef" AS "featureRef"
          FROM "shipit_product_repoint_target" t
          JOIN work_item w
            ON w."workItemId" = t."workItemId"
         WHERE t."workItemId" LIKE 'design-remediation-%'
         ORDER BY t."workItemId"
    LOOP
        IF c."suffix" IS NULL OR c."suffix" = '' THEN
            linkage_offenders := linkage_offenders
                                 || c."workItemId"
                                 || ' [id yields no defect id], ';
        ELSIF c."featureRef" IS DISTINCT FROM c."suffix" THEN
            linkage_offenders := linkage_offenders
                                 || c."workItemId"
                                 || ' [featureRef is '
                                 || coalesce(c."featureRef", '<null>')
                                 || ', expected '
                                 || c."suffix"
                                 || '], ';
        ELSIF NOT EXISTS (
                  SELECT 1
                    FROM "shipit_product_repoint_target" p
                   WHERE p."workItemId" = 'defect-' || c."suffix"
              ) THEN
            linkage_offenders := linkage_offenders
                                 || c."workItemId"
                                 || ' [derived parent defect-'
                                 || c."suffix"
                                 || ' is not in the target set, so it would '
                                 || 'be repointed without its parent], ';
        ELSIF NOT EXISTS (
                  SELECT 1
                    FROM work_item p
                   WHERE p."workItemId" = 'defect-' || c."suffix"
                     AND p."featureRef" = c."suffix"
              ) THEN
            linkage_offenders := linkage_offenders
                                 || c."workItemId"
                                 || ' [parent defect-'
                                 || c."suffix"
                                 || ' does not carry the same featureRef, so '
                                 || 'the id suffix and the traceability column '
                                 || 'disagree about which defect this '
                                 || 'remediates], ';
        END IF;
    END LOOP;

    -- (e) NO ORPHANS, IN ANY TABLE. `work_item` is allowed to carry 'defects'
    -- ONLY on the enumerated twelve; every other table is allowed to carry it
    -- not at all.
    FOR c IN
        SELECT cols.table_name
          FROM information_schema.columns cols
          JOIN information_schema.tables tbls
            ON tbls.table_schema = cols.table_schema
           AND tbls.table_name = cols.table_name
         WHERE cols.table_schema = current_schema()
           AND cols.table_schema NOT LIKE 'pg\_%'
           AND cols.column_name = 'productId'
           AND tbls.table_type = 'BASE TABLE'
         ORDER BY cols.table_name
    LOOP
        IF c.table_name = 'work_item' THEN
            EXECUTE $orphan$
                SELECT count(*)
                  FROM work_item w
                 WHERE w."productId" = $1
                   AND NOT EXISTS (
                         SELECT 1
                           FROM "shipit_product_repoint_target" t
                          WHERE t."workItemId" = w."workItemId"
                       )
            $orphan$
              INTO stray_rows
              USING 'defects';
        ELSE
            EXECUTE format(
                'SELECT count(*) FROM %I WHERE "productId" = $1',
                c.table_name
            )
              INTO stray_rows
              USING 'defects';
        END IF;

        IF stray_rows > 0 THEN
            orphan_offenders := orphan_offenders
                               || c.table_name
                               || ' ['
                               || stray_rows
                               || ' row(s) still under defects'
                               || CASE WHEN c.table_name = 'work_item'
                                       THEN ', outside the enumerated set'
                                       ELSE ''
                                  END
                               || '], ';
        END IF;
    END LOOP;

    IF offenders <> '' OR linkage_offenders <> '' OR orphan_offenders <> '' THEN
        RAISE EXCEPTION
            'product-repoint refused; nothing was changed. % % % Each enumerated '
            'work item must still exist and carry the product id it was read '
            'with; each design remediation must still resolve to a parent that '
            'is itself in the set and agrees with it on featureRef; and no table '
            'anywhere in this schema may still hold a row under the product that '
            'does not exist.',
            CASE WHEN offenders <> ''
                 THEN 'Target-set problems: ' || left(offenders, length(offenders) - 2) || '.'
                 ELSE ''
            END,
            CASE WHEN linkage_offenders <> ''
                 THEN 'Remediation linkage problems: '
                      || left(linkage_offenders, length(linkage_offenders) - 2) || '.'
                 ELSE ''
            END,
            CASE WHEN orphan_offenders <> ''
                 THEN 'Orphans: '
                      || left(orphan_offenders, length(orphan_offenders) - 2) || '.'
                 ELSE ''
            END;
    END IF;
END $guard$;

--
-- THE REPOINT, AND THE AUDIT ROW THAT RECORDS IT.
--
-- One data-modifying CTE: the UPDATE's RETURNING feeds the audit INSERT, so a
-- row can only be audited if it was actually repointed. That is the same
-- all-or-nothing property 20261014093000000 relies on, reached the other way
-- round -- there the UPDATE fed the INSERT, here the INSERT is keyed off the
-- UPDATE's own RETURNING rather than off a re-read of the selection.
--
-- `eligible` is counted OUTSIDE this block rather than assumed to be twelve,
-- so the all-or-nothing check holds on the terms that are actually true: on a
-- first apply eligible is twelve, and on an idempotent re-apply it is zero. A
-- hard-coded twelve would refuse its own second run.
DO $repoint$
DECLARE
    dest     text;
    eligible bigint := 0;
    moved    bigint := 0;
BEGIN
    SELECT "productId" INTO dest FROM "shipit_product_repoint_dest";

    SELECT count(*) INTO eligible
      FROM "shipit_product_repoint_target" t
      JOIN work_item w
        ON w."workItemId" = t."workItemId"
     WHERE w."productId" = t."expectedProductId"
       AND NOT EXISTS (
               SELECT 1
                 FROM "work_item_transition" x
                WHERE x."transitionId" =
                          'tr-product-repoint-' || w."workItemId"
           );

    WITH "selected" AS (
        SELECT w."workItemId", w."version", t."expectedProductId"
          FROM "shipit_product_repoint_target" t
          JOIN work_item w
            ON w."workItemId" = t."workItemId"
         WHERE w."productId" = t."expectedProductId"
           -- IDEMPOTENCE BY AUDIT ROW, re-asserted here for the reason it is
           -- in `eligible` above: a FORCED replay of this file against an item
           -- the scheduler has since moved on must not write a second row, and
           -- the value arm alone would still match if the item had been
           -- re-filed by hand.
           AND NOT EXISTS (
                   SELECT 1
                     FROM "work_item_transition" x
                    WHERE x."transitionId" =
                              'tr-product-repoint-' || w."workItemId"
               )
    ),
    "repointed" AS (
        UPDATE work_item w
           SET "productId" = dest,
               "updatedAt" = now(),
               "version" = w."version" + 1
          FROM "selected" s
         WHERE w."workItemId" = s."workItemId"
           -- Re-asserted, for the reason 20261012150000000 re-asserted its
           -- state there: after this row is locked, a concurrent writer that
           -- re-filed it must not be overwritten. `version` is the
           -- compare-and-swap the engine itself uses and `productId` is the
           -- selection predicate AND the column being written.
           --
           -- `state` is deliberately NOT re-asserted, because it is not
           -- written: a compare-and-swap on a column this statement does not
           -- touch would abort the whole repair when the scheduler merely
           -- advanced an item, which is a benign race this migration has no
           -- reason to fail on. The audit row still quotes the true state --
           -- `RETURNING` yields the post-UPDATE value, and `state` is not in
           -- the SET list, so it is the state the item was in and remains in.
           AND w."productId" = s."expectedProductId"
           AND w."version" = s."version"
        RETURNING w."workItemId",
                  w."state" AS "fromState",
                  s."expectedProductId" AS "fromProductId"
    )
    INSERT INTO "work_item_transition"
        ("transitionId", "workItemId", "fromState", "toState", "trigger",
         "actorType", "actorId", "decisionId", "outcome", "reason",
         "guardEvaluationsJson", "idempotencyKey", "occurredAt")
    SELECT 'tr-product-repoint-' || "workItemId",
           "workItemId",
           "fromState",
           -- EQUAL TO fromState, BY DESIGN: no state changed. See the banner.
           "fromState",
           'system_event',
           'orchestrator',
           'orchestrator',
           NULL,
           'accepted',
           'One-time data repair (IMPL-A8-REPOINT-DEFECTS). NO STATE CHANGE: '
           || 'this row records a product repoint only, which is why '
           || 'from_state and to_state are the same value and no transition '
           || 'edge exists or is implied. For this work item, '
           || 'work_item.productId was rewritten from ''' || "fromProductId"
           || ''' to ''' || dest || ''', alongside the updatedAt and version '
           || 'every real write to that table also sets. Nothing else on the '
           || 'row was touched: state, metadataJson (including the shared '
           || 'triageAttempt re-work discriminator), featureRef, '
           || 'designContractId, qaContractId, agentSessionId, '
           || 'artifactRefsJson, blockingHumanDecisionId, completedAt and '
           || 'terminatedAt are unchanged, and no row outside '
           || 'work_item and this audit table was read for update or written '
           || '-- in particular no defect, job, worker_execution, '
           || 'agent_execution, model_execution_record, design_revision, '
            || 'onboarding_record or product_baseline row. The twelve '
            || 'enumerated ids were filed under a product id with no registry '
            || 'row, and the deferral that follows from that is SCOPED TO THE '
            || 'SEVEN AT implementation_ready -- every one of THOSE seven '
            || 'deferred on implementation.deferred.product_missing -- not '
            || 'universal across the twelve. The scope is not incidental: the '
            || 'implementation readiness probe is the IMPLEMENTATION lane''s '
            || 'workload resolver, wired only on '
            || 'sched-impl (apps/server/lib/server.dart:653); '
            || 'RunnableWorkEvaluator.evaluate returns noAction for any item '
            || 'outside its definition''s entryStates '
            || '(packages/scheduler/lib/src/policy/runnable_work.dart:172) '
            || 'BEFORE the resolver is consulted. The three at '
            || 'agent_completed are in '
            || 'engineeringReviewDefinition.entryStates '
            || '(packages/scheduler/lib/src/scheduler.dart:2166), so '
            || 'sched-review claims them and its resolver is not this probe: '
            || 'they were never deferred on '
            || 'implementation.deferred.product_missing, or on anything else. '
            || 'The two at '
            || 'planned are in no wired entryStates at all and are claimed by '
            || 'nothing, so they were never deferred on anything either. Those '
            || 'five are repointed because being filed under a product that '
            || 'does not exist is wrong at ANY state, not because a probe had '
            || 'refused them. The destination was checked to EXIST and to be '
            || 'governed before '
            || 'this row was written. An item that moved on between dispatch '
           || 'and apply was still repointed, because being filed under a '
           || 'product that does not exist is wrong regardless of the state '
           || 'it has reached. This repair does not fix the producer: the '
           || 'triage provisioners still fall back to the synthetic '
           || '''defects'' bucket when a defect has no resolvable '
           || 'affectedWorkItemId, so a further item can be filed under it '
           || 'again.',
           NULL,
           'product-repoint:repointed-to-governed-product',
           now()
      FROM "repointed";

    GET DIAGNOSTICS moved = ROW_COUNT;

    IF moved <> eligible THEN
        RAISE EXCEPTION
            'product-repoint aborted; nothing was changed. % of % eligible work '
            'items were repointed, so a concurrent writer changed a row between '
            'the guard and this statement and the repair would have been '
            'partial. A partial repair is invisible -- it leaves a mix of '
            'repointed and unrepointed items with nothing distinguishing them.',
            moved, eligible;
    END IF;

    -- The second `%` is `eligible`, NOT the size of the enumerated set, and
    -- the wording says so: `eligible` counts enumerated rows that still carried
    -- their expected product id and had no audit row from this migration yet,
    -- so it is 12 on a first apply and 0 on every re-apply. Labelling it
    -- "enumerated" printed "repointed 0 of 0 enumerated work items" on a
    -- completed repair, which reads as an empty target set rather than as a
    -- repair that already finished. The trailing count is `total - eligible`,
    -- so the two together always account for all twelve.
    RAISE NOTICE
        'product-repoint: repointed % of % ELIGIBLE work items from defects '
        'to %; % were already at the destination. ELIGIBLE is the enumerated '
        'rows still carrying the expected product id with no audit row from '
        'this migration yet, so it reads 0 on a re-apply and the pair '
        'ELIGIBLE + already-at-destination is always the full set.',
        moved, eligible, dest,
        (SELECT count(*) FROM "shipit_product_repoint_target") - eligible;
END $repoint$;

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20261014130500000', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261014130500000', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();


--
-- DOWN MIGRATION
--
-- To rollback this migration, run the following:
--
-- WARNING: this restores the defect. Every item goes back to a product id that
-- names a product which does not exist, so the readiness probe defers all of
-- them on `implementation.deferred.product_missing` again and nothing dispatches.
-- Run it only to return a database to its pre-migration shape.
--
-- THE ROLLBACK IS EXACT BY ID, NOT BY COLUMN VALUE. It repoints the twelve
-- enumerated ids and nothing else, so it cannot reach a row that legitimately
-- belongs to some other product -- the mirror of the reason the UP direction
-- will not select on `productId = 'defects'`.
--
-- THE STATEMENT ORDER BELOW IS RESTORE-THEN-DELETE, AND THAT IS A FIX, NOT A
-- COSMETIC DIFFERENCE. `20261012150000000` and `20261012195523112` both DELETE
-- the audit rows FIRST and then run an UPDATE whose arm keys off those same
-- audit rows -- so by the time the UPDATE runs the rows it is looking for are
-- already gone and it restores NOTHING while reporting success. Here the
-- restore runs FIRST and the audit rows are deleted after it, which is the only
-- order in which the audit-row arm can match anything.
--
-- THE RESTORE REVERSES `version` BY SUBTRACTING ONE for the same reason it
-- steps `updatedAt` forward: the forward direction is a visible write, and an
-- invisible inversion of a compare-and-swap counter is a second, unrecorded
-- change to the same rows. This is the one place the rollback does NOT
-- faithfully restore, and it is stated rather than hidden -- `version` returns
-- to its pre-migration value only if nothing else touched the row in between.
--
-- WHAT THE RESTORE DOES NOT DISTINGUISH, STATED PLAINLY. It matches rows that
-- currently carry the destination, so it cannot tell one this migration moved
-- from one that was already at `shipit-platform` before it ran (a hand-fixed
-- row, or a row repointed by an earlier repair). Such a row is returned to
-- 'defects' with the rest. That is the symmetric cost of a convergence
-- operation, and making the rollback able to tell would mean writing a per-row
-- marker beyond the audit row this migration already writes -- which it could,
-- and deliberately does not, because the audit row is keyed by id and not by
-- the value it found.
--
-- The pattern is 'tr-product-repoint-%' and NOT any of the four earlier
-- repairs' prefixes ('tr-stranded-repair-%', 'tr-stranded-exec-repair-%',
-- 'tr-dedupe-bump-repair-%', 'tr-stranded-key-repair-%'), so a rollback of one
-- of those cannot delete this migration's rows and this rollback cannot delete
-- theirs.
--
-- BEGIN;
--
-- UPDATE work_item w
--    SET "productId" = 'defects',
--        "updatedAt" = now(),
--        "version" = w."version" - 1
--   FROM "work_item_transition" x
--  WHERE x."transitionId" = 'tr-product-repoint-' || w."workItemId"
--    AND x."idempotencyKey" = 'product-repoint:repointed-to-governed-product'
--    AND w."productId" = 'shipit-platform';
--
-- -- Only now drop this migration's audit rows, so the restore above had rows to
-- -- key off. Deterministic ids: this matches exactly what this migration
-- -- created and can never reach a row the engine wrote.
-- DELETE FROM "work_item_transition"
--  WHERE "transitionId" LIKE 'tr-product-repoint-%';
--
-- -- Migration version rollback for control_plane
-- DELETE FROM "serverpod_migrations" WHERE "module" = 'control_plane' AND "version" = '20261014130500000';
--
-- COMMIT;


COMMIT;