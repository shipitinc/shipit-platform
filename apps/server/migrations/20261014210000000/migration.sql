BEGIN;

--
-- SHIPIT CONTROL PLANE REPAIR: every engineering-review decision whose claimed
-- verdict no reviewer ever produced as a MACHINE-READABLE VERDICT is voided
-- without being deleted, and its work item is returned to a dispatchable review
-- at a FRESH key, so the review is actually re-run.
--
-- ## WHAT BROKE
--
-- `EngineeringReviewGate` used to default a missing verdict to
-- `changes_required`. A reviewer that timed out produced no result, the gate
-- invented the verdict, and an `engineering_review` decision was raised asking a
-- human to approve or reject code nobody had read. Commit 93587cf (b1) removed
-- all three fallback sites and made the parser fail closed, so a NEW fabricated
-- decision can no longer be created -- but the rows the old default produced are
-- still there, still blocking their work items, and still reading "We suggest:
-- CHANGES_REQUIRED". b1 fixes the cause. This repairs the data the cause
-- produced.
--
-- ## THE SCOPE OF THIS FILE IS A DECISION, NOT A PROPERTY OF THE DATA
--
-- READ THIS BEFORE "CLEANING UP" THE TARGET LIST. A reasonable reader will look
-- at this file, notice that two of its five targets carry a genuine reviewer's
-- assessment, and conclude that the selection predicate is too wide. It is not
-- too wide. It is DELIBERATELY not a predicate at all.
--
-- The five decisions below were enumerated, reviewed and approved one by one by
-- an operator, under the recorded human decision
-- `8f1ed5bf-4147-449a-a221-558aac2303a9` (DATA_REMEDIATION, RESOLVED), whose
-- resolution is, verbatim:
--
--     Void EVERY fabricated engineering-review decision -- all five -- and
--     re-run the review from scratch.
--
-- Asked separately whether to RE-DERIVE each decision's claim from the reviewer's
-- own prose or to RE-RUN, the operator chose to re-run, for consistency. The
-- reasoning, recorded in that decision and not restated here: the claim and the
-- prose came out of the SAME run the bug corrupted, so treating one as
-- authoritative and the other as noise is an assumption, not a derivation.
-- Nothing flowing from a fabricated claim is preserved by parsing it.
--
-- So: the defect is not "these rows have no verdict". The defect is "these five
-- decisions were produced by a gate that fabricated verdicts, and therefore
-- nothing downstream of them can be trusted". That is a fact about FIVE NAMED
-- ROWS, not a shape any predicate could have selected correctly. Adding or
-- narrowing a predicate here -- in either direction -- would be substituting
-- this file's author's judgement for the operator's decision, and would silently
-- change what gets voided on every future apply.
--
-- The consequence, stated so it is not rediscovered as a bug: this migration
-- voids two decisions whose reviewers DID write real assessments, and discards
-- those assessments along with the fabricated claim. Each reviewer's summary is
-- preserved verbatim in `agent_result.summary`, which this migration never
-- writes; it stops being reachable from the decision, which is the point.
--
-- ## WHAT WAS MEASURED IN QA BEFORE THIS FILE WAS WRITTEN
--
-- Read read-only off the live QA database, re-verified 2026-10-15, immediately
-- before this revision. Every `engineering_review` decision that exists, with
-- the reviewer execution its own metadata names, and what that reviewer
-- ACTUALLY wrote:
--
--   decisionId            work item                 exec status  payload  summary  verdict claimed  VOIDED HERE
--   --------------------  ------------------------  -----------  -------  -------  ---------------  -----------
--   dec-hn7h7d9j8i-1oh8pgm  DEF-1791684557133597    failed       {}       empty    changes_required  yes
--   dec-hn7h7db3w9-hdzu8c  DEF-1791685924503981    failed       {}       empty    changes_required  yes
--   dec-hn7h7dagw5-l4o193  DEF-1791685024220546    completed    {}       2000 ch  changes_required  yes
--   dec-hn7iw644nz-rmmpcn  DEF-1791686357139031    completed    {}       2000 ch  changes_required  yes
--   dec-hn7h7daum6-2atjhe  DEF-1791685264570406    failed       {}       empty    changes_required  yes
--
-- The two completed reviewers are `agx-wx-jb-hn7gq1n2dc-1llxxyk`
-- (`defect-DEF-1791685024220546`), whose summary opens "## Engineering Review"
-- and states **"Verdict: `APPROVE_WITH_NON_BLOCKING_FOLLOWUP`"**, and
-- `agx-wx-jb-hn7itcezii-1igc7vp` (`defect-DEF-1791686357139031`), which
-- confirms all three of its diagnoses by inspection. Neither string is one of
-- `ReviewVerdict`'s four wires, so neither produced a verdict the gate could
-- read, and the gate invented one. Both are voided anyway: see the banner.
--
-- ## THE ONE THAT WAS ALREADY APPROVED, AND WHAT VOITING IT PRESERVES
--
-- `dec-hn7h7daum6-2atjhe` was NOT pending when this file was first written. An
-- operator had resolved it:
--
--     choice = approve   decider = operator   rationale = "gotta get this rolling"
--     signature = {"algorithm":"ed25519","publicKey":"operator-pub-key",
--                   "signature":"operator-sig-1792005550089",
--                   "signedAt":"2026-10-14T19:19:10.089Z"}
--     timestamp = 2026-10-14 19:19:10.289486
--
-- and its work item had MOVED ON to `review_approved`. That is the harm this
-- whole mechanism exists to prevent, and it had already happened once, in QA,
-- to a decision whose reviewer had timed out.
--
-- **This migration overwrites a recorded human approval.** The operator chose
-- that knowing it, and the choice is the recorded decision cited in the banner.
-- It is called out here, in the file, because a reader auditing this migration
-- in a year must be able to find the fact that a human approval was undone and
-- why, without reading the decision record first.
--
-- **VOIDING IS NOT ERASING.** `decider`, `choice`, `rationale`,
-- `signatureJson`, `resolvedOptionId` and `timestamp` are NOT written by any
-- statement below. That is not an accident of the implementation, it is the
-- mechanism: the approval survives because nothing ever touched it. The void is
-- expressed in `status` plus the `reviewUnreviewed*` markers in `metadata`, and
-- the approval is additionally copied into the audit row's before-image and into
-- `metadata.reviewApprovalVoided`, so the record of what was approved exists in
-- three places even though it no longer has any effect.
--
-- WHY A `cancelled` DECISION WITH A POPULATED `choice` CANNOT BE MISREAD AS AN
-- APPROVAL. This is the whole safety argument for voiding by status rather than
-- by clearing the columns, so it is checked rather than asserted:
--
--   * `blockingHumanDecisionResolved` -- the only guard that reads a decision --
--     requires `decision.status.isResolved`, i.e. `status = 'resolved'`.
--     `cancelled` fails it. (workflow_engine/lib/src/validation/guard_conditions.dart)
--   * `DurableWorkflowEngine.resolveDecision` computes
--     `alreadyResolved = decision.status.isResolved` and only then reuses a
--     recorded `choice`/`decider`/`rationale`/`signature`/`timestamp`. On a
--     `cancelled` decision that is false, so the preserved columns are never
--     read as an answer. (workflow_store/lib/src/durable_workflow_engine.dart)
--   * The three operator-UI reads in `HomeEndpoints` -- `waitingOnYou`,
--     `pendingDecisions` and `recentDecisions` -- key off
--     `blockingHumanDecisionId` or `isResolved`. The work item's blocking id is
--     cleared below, and `cancelled` is not resolved, so a voided approval is
--     invisible in all three.
--
-- ## THE TARGET SET IS ENUMERATED, AND THE LIST APPEARS ONCE
--
-- `shipit_unreviewed_review_repair_target` is the single definition of what this
-- migration touches; the drift guard and both UPDATEs read it, and nothing else
-- in this file names a decision id. Spelling the ids out a second time is how a
-- guard and the statement it guards come to test a different set than the one
-- being written -- a guard that then passes for the wrong reason.
--
-- Every row is PINNED, not merely listed: the work item state and blocking
-- pointer it held, the decision's status, and every resolution column including
-- the operator signature. Those pins are the compare-and-swap, and they are the
-- reason this migration is safe to apply to a database that has moved on since
-- the table above was read.
--
-- ## THE DRIFT GUARD IS LOAD-BEARING NOW, NOT BELT-AND-BRACES
--
-- It used to be a guard about the DATA -- "this decision is not actually
-- fabricated" -- and it is now a guard about TIME. A target that has changed
-- state since this table was written is a target whose reasoning was not written
-- for, and the migration refuses the WHOLE thing rather than skipping it.
--
-- The case that matters most is the approved one. An approval that had been
-- re-recorded, re-signed or re-resolved since 2026-10-15 would be a DIFFERENT
-- human act from the one the operator reasoned about, and voiding it on the
-- strength of a stale row would be destroying an approval nobody authorised
-- destroying. Naming the decision and refusing is the only safe answer, and it
-- is why every resolution column is pinned rather than just `status`.
--
-- `work_item.version` is deliberately NOT pinned. It is a compare-and-swap the
-- engine bumps on any write, including a reconciliation pass that changes
-- nothing this migration reasons about; pinning it would make this migration
-- refuse for reasons that are not drift. The pins above cover every field the
-- migration reads or writes.
--
-- IDEMPOTENT, BY ID AND NOT BY STATE. A second run classifies every row as
-- ALREADY APPLIED and writes nothing, because each repaired decision carries
-- this migration's `reviewUnreviewedMigration` marker and each repaired item
-- carries this migration's audit row. That arm is checked BEFORE the pins, so a
-- forced replay against items the scheduler has since moved on does not report
-- false drift.
--
-- Under CONCURRENCY two appliers cannot both write: the second blocks on the
-- row lock, and on READ COMMITTED PostgreSQL re-evaluates the UPDATE's WHERE
-- against the newly committed row, sees this migration's marker, and matches
-- nothing. The `transitionId`s are deterministic rather than random, so even a
-- replay that bypassed the arm entirely would collide on
-- `work_item_transition_id_unique` and abort loudly rather than write a second,
-- differently-named audit row.
--
-- FAIL LOUDLY, ON THREE CONDITIONS, ROLLING EVERYTHING BACK.
--
-- None of these is a "skip it" case:
--
--   * A TARGET THAT HAS MOVED SINCE THE TABLE ABOVE WAS READ. See above.
--   * A DECISION WITH NO WORK ITEM. Something deleted the item out from under a
--     live question, which nothing in this codebase does. A target with NO
--     decision at all is NOT this arm: there is nothing to void, and that shape
--     is what three of this repository's own chain-replay harnesses produce.
--   * METADATA THAT CANNOT BE MERGED. The markers are written with a jsonb `||`,
--     which MERGES and never replaces: the defect payload the re-run triage
--     reads must survive, or the item classifies nothing while looking healthy.
--     Both `human_decision.metadataJson` and `work_item.metadataJson` are
--     nullable `text` and are NOT guaranteed to hold parseable JSON. For an
--     UNPARSEABLE or non-object value there is nothing safe to write: the only
--     way to stamp a marker is to overwrite the whole document, which is silent
--     destruction of whatever was there.
--
-- Because all of these raise inside the surrounding transaction, the failure
-- mode is all-or-nothing: no decision is voided, no item moves, no audit row is
-- written, and no approval is disturbed.
--
-- ## THE NEW KEY IS AN ARITHMETIC BORROW, NOT A GUESS
--
-- `engineeringReviewDedupeKey` (packages/scheduler/lib/src/scheduler.dart)
-- builds `'<workItemId>:engineering_review'` plus `':a<n>'` when
-- `metadata.triageAttempt` is readable, and returns the BARE key when it is not.
-- `JobQueue.enqueueIfAbsent` resolves any key a job already holds, terminal or
-- not -- and every one of these five items holds a job that took its key. So
-- each item is inert without a bump, and the bump is what makes the re-review
-- actually dispatch rather than deduplicate against the attempt that caused the
-- fault.
--
-- The bump is `greatest(<marker>, <highest attempt encoded in this item's own
-- engineering_review job dedupe keys>) + 1`, the same two-watermark rule
-- `20261014093000000` used for the triage key and the same one
-- `DurableWorkflowEngine.nextTriageAttempt` computes. Taking the max over the
-- item's OWN jobs as well is what makes the result PROVABLY UNHELD: the only
-- place an attempt number can already have a holder is a job.
--
-- MEASURED, not assumed. Read off QA on 2026-10-15:
--
--   work item                 marker  job keys held                      -> new key
--   ------------------------  ------  ---------------------------------  ----------------
--   defect-DEF-1791684557133597      2  (bare)                            -> :a3
--   defect-DEF-1791685024220546      2  (bare)                            -> :a3
--   defect-DEF-1791685264570406      2  (bare)                            -> :a3
--   defect-DEF-1791685924503981      2  (bare)                            -> :a3
--   defect-DEF-1791686357139031      3  (bare), :a3                       -> :a4
--
-- The fifth is the one worth reading twice, and NOT for the reason a reader
-- expects. Its marker reads 3, not 2, so `marker + 1` would already give
-- `:a4` -- the second watermark changes the answer for NONE of these five, and
-- a banner that claimed otherwise would be overstating its own guard.
--
-- What the fifth proves is that the MARKER has to be read correctly. At its
-- current `:a3`, that item's own live job already holds the key the scheduler
-- computes today, so an un-bumped item is inert; a repair that read only the
-- bare key and "tidied" 3 to 2 would hand back `:a3` and recreate the exact
-- strand this migration exists to end.
--
-- The job floor is kept anyway, for the shape the measurement does not cover:
-- an item whose marker lags behind the attempts its own jobs have already
-- consumed. No such item exists in QA today, so the arm is SAFETY rather than
-- necessity -- recorded as such, because a guard that looks load-bearing and is
-- not is one somebody will later trust in a case it does not cover.
--
-- The marker is read by REPLICATING `DurableWorkflowEngine.readTriageAttempt`
-- rather than by re-deciding which shapes are attempts: it accepts an int, a
-- whole-valued double and a numeric String, and throws on anything else. The
-- `CASE` in the "marker" CTE encodes those same arms, exactly as
-- `20261014093000000` does and for the same reason -- a second copy of "how a
-- marker is read" is how a writer and a reader come to disagree about which
-- numbers are attempts, and the disagreement would not throw, it would build a
-- different key and enqueue nothing. An ABSENT key and an EXPLICIT JSON null
-- both mean `null` to the Dart reader, so both normalise to 0 here.
--
-- PLAN-ORDER INDEPENDENCE OF THE `::jsonb` CAST. Every cast is confined to the
-- ELSE branch of a `CASE`, which PostgreSQL documents to evaluate in order and
-- not to evaluate an unselected branch at all, so no unparseable value can raise
-- here regardless of the plan.
--
-- NON-COLLIDING ID CONVENTION. `transitionId` is
-- `tr-unreviewed-review-repair-<workItemId>`, `idempotencyKey` is
-- `unreviewed-review-repair:void-fabricated-verdict`, and the audit row's
-- restore payload is namespaced by `"migration": "20261014210000000"`. The
-- earlier repairs in this repository wrote `tr-stranded-repair-`,
-- `tr-stranded-exec-repair-`, `tr-dedupe-bump-repair-` and
-- `tr-stranded-key-repair-`; reusing any of those prefixes would violate
-- `work_item_transition_id_unique` or `work_item_transition_idempotency_unique`
-- and abort. Note `tr-unreviewed-review-repair-` is not matched by any of their
-- LIKE patterns, so a rollback of one of those cannot delete these rows.
--
-- ## WHAT IS AND IS NOT WRITTEN.
--
--   * `human_decision`: `status`, `metadataJson`, `updatedAt`. NOTHING ELSE. In
--     particular NOT `question`, `optionsJson`, `recommendation`, `contextJson`,
--     and NOT `decider`, `choice`, `rationale`, `signatureJson`,
--     `resolvedOptionId` or `timestamp`. The fabricated question, its
--     recommendation and its options are the EVIDENCE and are preserved
--     verbatim; the resolution columns are never written, which is what makes
--     the approved decision's approval survive its own voiding. This migration
--     therefore cannot forge a human answer even by accident, and cannot erase
--     one either. **Nothing is deleted.** Every decision survives as the record
--     of what was claimed.
--   * `work_item`: `state`, `blockingHumanDecisionId`, `blockingReason`,
--     `metadataJson`, `updatedAt`, `version`.
--   * One audit row per repaired item in `work_item_transition`.
--   * No `job` row is touched, so a repaired item enqueues against a FRESH key
--     rather than resuming anything, and the review jobs that stranded these
--     items are left exactly as they are. No `agent_execution`, `agent_result`,
--     `worker_execution` or `model_execution_record` row is touched -- the
--     reviewers' evidence is read, never rewritten, so the two real reviews
--     survive in `agent_result.summary` even though their decisions are voided.
--   * `pinnedRevision`, `workspace`, producer anchors, `qaContractId`,
--     `designContractId`, `agentSessionId`, `artifactRefsJson`, `completedAt`
--     and `terminatedAt` are all untouched.
--   * `version` is incremented and `updatedAt` set, exactly as a real transition
--     writes them, so the engine's compare-and-swap on `version` still behaves.
--
-- SAFETY / DATA LOSS: this migration deletes nothing and overwrites no payload.
-- It voids five decisions the operator enumerated and approved voiding, moves
-- five stranded work items, and writes the audit rows describing both. It DOES
-- undo one recorded human approval, deliberately, by a decision the operator
-- made with that consequence stated. Every statement is inside the surrounding
-- transaction, so a failure rolls back the decision changes, the state moves,
-- the marker writes and the audit rows together -- there is no reachable state
-- in which an item moved with no audit row describing it, and no reachable state
-- in which one item was repaired and the other was not.
--
-- WHY `agent_completed`. That is `engineeringReviewDefinition.entryStates`
-- (packages/scheduler/lib/src/scheduler.dart), so the ordinary tick dispatches
-- the re-review on the ordinary path. NEITHER `waiting_for_human_decision ->
-- agent_completed` NOR `review_approved -> agent_completed` has an edge in
-- `WorkItemTransitions` -- no edge models "a question was asked that nobody
-- asked", and none models "an approval rested on nothing" -- so, exactly as in
-- every other repair migration in this repository, the state is written directly
-- into the column and the audit row records that no edge was taken.
--
-- The one place an operator could have been moved forward from here --
-- `waiting_for_human_decision -> review_approved` -- is not reachable from
-- `agent_completed` at all, so nothing this migration does can approve anything.

-- `DROP ... IF EXISTS` is belt-and-braces for a replay inside ONE session:
-- `ON COMMIT DROP` already covers the committed and the rolled-back paths, and
-- this covers neither having run yet.
DROP TABLE IF EXISTS "shipit_unreviewed_review_repair_target";

CREATE TEMP TABLE "shipit_unreviewed_review_repair_target" (
    "decisionId"                 text PRIMARY KEY,
    "workItemId"                 text NOT NULL,
    "expectedState"              text NOT NULL,
    "expectedBlockingDecisionId" text,
    "expectedDecisionStatus"     text NOT NULL,
    "expectedChoice"             text,
    "expectedResolvedOptionId"   text,
    "expectedDecider"            text,
    "expectedRationale"          text,
    "expectedSignatureJson"      text,
    "expectedDecisionTimestamp"  timestamp,
    "expectedDecisionDigest"     text NOT NULL,
    "voidsHumanApproval"         boolean NOT NULL
) ON COMMIT DROP;

-- THE TARGET SET: five decisions, every column pinned to what live QA held when
-- this table was written. Changing a row here changes what the migration does,
-- and a value that no longer matches what the database holds makes the whole
-- migration refuse. There is no second copy of this list anywhere in the file.
--
-- `expectedDecisionDigest` is `md5` over the canonical `jsonb` text of
-- `jsonb_build_object(status, choice, resolvedOptionId, decider, rationale,
-- signatureJson, timestamp, metadataJson)`. jsonb normalises key order and
-- whitespace, so the digest is stable across byte-level re-serialisation of the
-- same document and changes if any pinned field changes at all. It is the one
-- place a digest is computed in this file; the compare-and-swap in the UPDATE
-- below does NOT use it, and pins the columns directly, so there is no second
-- copy of this expression to drift out of step with the first.
INSERT INTO "shipit_unreviewed_review_repair_target"
    ("decisionId", "workItemId", "expectedState", "expectedBlockingDecisionId",
     "expectedDecisionStatus", "expectedChoice", "expectedResolvedOptionId",
     "expectedDecider", "expectedRationale", "expectedSignatureJson",
     "expectedDecisionTimestamp", "expectedDecisionDigest",
     "voidsHumanApproval")
VALUES
    -- Group 1 -- the reviewer produced NOTHING. The timeout is the whole defect.
    -- NOTE THE `''`. QA does not hold a NULL signature on these four; it holds
    -- an EMPTY STRING. That is a real distinction and the pinned digest catches
    -- it: `jsonb_build_object` renders a NULL as `null` and `''` as `""`, so a
    -- fixture -- or a later repair -- that "tidied" the empty string to NULL
    -- would change the digest and be refused by the very guard meant to prove
    -- nothing drifted. Pinned as QA holds it.
    ('dec-hn7h7d9j8i-1oh8pgm', 'defect-DEF-1791684557133597',
     'waiting_for_human_decision', 'dec-hn7h7d9j8i-1oh8pgm',
     'pending', NULL, NULL, NULL, NULL, '', NULL,
     'e83429482675eff1eab71fa4fe508891', false),
    ('dec-hn7h7db3w9-hdzu8c', 'defect-DEF-1791685924503981',
     'waiting_for_human_decision', 'dec-hn7h7db3w9-hdzu8c',
     'pending', NULL, NULL, NULL, NULL, '', NULL,
     'fa3c44f56877b790f53b83084744ead0', false),
    -- Group 2 -- the reviewer COMPLETED and wrote a real assessment, but the
    -- verdict it stated is not one of ReviewVerdict's four wires, so the gate
    -- fabricated the machine-readable claim anyway. Voided by operator decision,
    -- not by predicate. See THE SCOPE OF THIS FILE IS A DECISION banner.
    ('dec-hn7h7dagw5-l4o193', 'defect-DEF-1791685024220546',
     'waiting_for_human_decision', 'dec-hn7h7dagw5-l4o193',
     'pending', NULL, NULL, NULL, NULL, '', NULL,
     '557f01925ae14a43f271e4f784674eea', false),
    ('dec-hn7iw644nz-rmmpcn', 'defect-DEF-1791686357139031',
     'waiting_for_human_decision', 'dec-hn7iw644nz-rmmpcn',
     'pending', NULL, NULL, NULL, NULL, '', NULL,
     'c45fd3bac4ed992e1d696c9ae059af2b', false),
    -- Group 3 -- ALREADY APPROVED BY AN OPERATOR, and the item has moved on to
    -- `review_approved` with no blocking pointer. Voiding this overwrites a
    -- recorded human approval. The six resolution columns below are what makes
    -- that refusal loud if they ever change, and they are what the audit row
    -- copies forward so the approval survives its own voiding.
    ('dec-hn7h7daum6-2atjhe', 'defect-DEF-1791685264570406',
     'review_approved', NULL,
     'resolved', 'approve', 'approve', 'operator',
     'gotta get this rolling',
     '{"algorithm":"ed25519","publicKey":"operator-pub-key","signature":"operator-sig-1792005550089","signedAt":"2026-10-14T19:19:10.089Z"}',
     TIMESTAMP '2026-10-14 19:19:10.289486',
     'bf7eaae6d92d92c32ed494b02d2b42d6', true);

--
-- FAIL LOUDLY ON DRIFT. Refuse the whole migration, naming every offending
-- decision, rather than voiding a decision or work item that has moved since
-- the table above was written.
--
-- The first arm is idempotence, checked BEFORE the pins: a row this migration
-- already repaired is not drift. That row is identified by the decision
-- carrying this migration's own marker AND the work item carrying this
-- migration's own audit row, which is why a forced replay against items the
-- scheduler has since moved on still classifies as ALREADY APPLIED rather than
-- reporting false drift.
--
-- Everything after that arm compares the live row against the pins, field by
-- field. A null pin matches a null column through `IS NOT DISTINCT FROM`; a
-- plain `=` would silently match nothing and read as drift, which is the right
-- verdict for the wrong reason and a very confusing message to debug.
--
-- The metadata checks are `BEGIN ... EXCEPTION` blocks rather than boolean
-- expressions because there is no way to ask "does this text parse as JSON?"
-- without attempting the cast, and `''::jsonb` raises. Catching the raise is what
-- turns an unparseable payload into a reported id instead of an aborted
-- statement whose message names no decision.
DO $$
DECLARE
    r           record;
    meta        jsonb;
    itemMeta    jsonb;
    observed    text;
    offenders   text := '';
    missing     text := '';
BEGIN
    FOR r IN
        SELECT t."decisionId",
               t."workItemId",
               t."expectedState",
               t."expectedBlockingDecisionId",
               t."expectedDecisionStatus",
               t."expectedChoice",
               t."expectedResolvedOptionId",
               t."expectedDecider",
               t."expectedRationale",
               t."expectedSignatureJson",
               t."expectedDecisionTimestamp",
               t."expectedDecisionDigest",
               t."voidsHumanApproval",
               d."status"                AS "liveStatus",
               d."choice"                AS "liveChoice",
               d."resolvedOptionId"      AS "liveResolvedOptionId",
               d."decider"               AS "liveDecider",
               d."rationale"             AS "liveRationale",
               d."signatureJson"         AS "liveSignatureJson",
               d."timestamp"             AS "liveTimestamp",
               d."metadataJson"          AS "liveMetadataJson",
               w."state"                 AS "liveState",
               w."blockingHumanDecisionId" AS "liveBlockingDecisionId",
               w."metadataJson"          AS "liveItemMetadataJson"
          FROM "shipit_unreviewed_review_repair_target" t
          LEFT JOIN human_decision d ON d."decisionId" = t."decisionId"
          LEFT JOIN work_item w      ON w."workItemId" = t."workItemId"
         ORDER BY t."decisionId"
    LOOP
        -- (0) ALREADY APPLIED BY THIS MIGRATION. Not drift; a replay.
        IF r."liveMetadataJson" IS NOT NULL
           AND btrim(r."liveMetadataJson") LIKE '{%'
           AND EXISTS (
                   SELECT 1 FROM "work_item_transition" x
                    WHERE x."transitionId" =
                              'tr-unreviewed-review-repair-' || r."workItemId"
                      AND x."idempotencyKey" =
                              'unreviewed-review-repair:void-fabricated-verdict'
                      AND x."guardEvaluationsJson"::jsonb ->> 'decisionId'
                          = r."decisionId"
               )
        THEN
            CONTINUE;
        END IF;

        -- (1) A TARGET WITH NO DECISION TO VOID. This is NOT the same as a
        --     target that has moved, and the difference is the whole reason this
        --     arm does not refuse.
        --
        --     What this migration repairs is a DECISION and the work item it
        --     parks. With no decision row there is nothing to void, and a work
        --     item sitting at `waiting_for_human_decision` with no decision is a
        --     different defect that the operator was not asked about and this
        --     migration has no instruction to fix.
        --
        --     It is also the ordinary shape in this repository's OWN chain-replay
        --     harnesses. `stranded_key_repair_migration_test.dart`,
        --     `onboarding_workspace_postgres_test.dart` and
        --     `product_repoint_migration_test.dart` seed the twelve work items
        --     that `20261014130500000` repoints WITHOUT seeding any
        --     `human_decision` rows, so during a full chain replay all five of
        --     this migration's work items exist and none of its decisions do.
        --     Refusing there aborts three unrelated tests over rows that were
        --     never there, which is a far worse failure than doing nothing.
        IF r."liveStatus" IS NULL THEN
            CONTINUE;
        END IF;

        -- (2) A DECISION WITH NO WORK ITEM. The genuine anomaly, and the only
        --     shape in this arm worth stopping for: something deleted the item
        --     out from under a live decision. Nothing in this codebase deletes
        --     either row, so that means something outside this migration touched
        --     it, and re-deciding what to do about the orphaned question from
        --     here would be guessing.
        IF r."liveState" IS NULL THEN
            missing := missing
                     || r."decisionId"
                     || ' [human_decision ' || r."decisionId" || ' is present '
                     || 'but work_item ' || r."workItemId"
                     || ' does not, so one half of the pair is gone], ';
            CONTINUE;
        END IF;

        -- (2) THE WORK ITEM MOVED. Compared field by field against the pins.
        IF r."liveState" IS DISTINCT FROM r."expectedState"
           OR r."liveBlockingDecisionId"
                  IS DISTINCT FROM r."expectedBlockingDecisionId" THEN
            offenders := offenders
                         || r."decisionId"
                         || ' [work item ' || r."workItemId"
                         || ' moved: state is ' || coalesce(r."liveState", '<null>')
                         || ', expected ' || r."expectedState"
                         || '; blockingHumanDecisionId is '
                         || coalesce(r."liveBlockingDecisionId", '<null>')
                         || ', expected '
                         || coalesce(r."expectedBlockingDecisionId", '<null>')
                         || '], ';
            CONTINUE;
        END IF;

        -- (3) THE DECISION MOVED -- AND FOR THE APPROVED ONE, THIS IS THE
        --     CASE THE WHOLE GUARD EXISTS FOR. An approval that had been
        --     re-recorded or re-signed since this table was written is a
        --     DIFFERENT human act from the one the operator reasoned about, and
        --     voiding it off a stale row would destroy an approval nobody
        --     authorised destroying.
        IF r."liveStatus" IS DISTINCT FROM r."expectedDecisionStatus"
           OR r."liveChoice" IS DISTINCT FROM r."expectedChoice"
           OR r."liveResolvedOptionId" IS DISTINCT FROM r."expectedResolvedOptionId"
           OR r."liveDecider" IS DISTINCT FROM r."expectedDecider"
           OR r."liveRationale" IS DISTINCT FROM r."expectedRationale"
           OR r."liveSignatureJson" IS DISTINCT FROM r."expectedSignatureJson"
           OR r."liveTimestamp" IS DISTINCT FROM r."expectedDecisionTimestamp" THEN
            offenders := offenders
                         || r."decisionId"
                         || ' [the decision itself moved since this migration '
                         'was written: status '
                         || coalesce(r."liveStatus", '<null>')
                         || ' (expected ' || r."expectedDecisionStatus" || ')'
                         || CASE WHEN r."liveChoice" IS DISTINCT FROM r."expectedChoice"
                                 THEN ', choice ' || coalesce(r."liveChoice", '<null>')
                                      || ' (expected '
                                      || coalesce(r."expectedChoice", '<null>') || ')'
                                 ELSE '' END
                         || CASE WHEN r."liveDecider" IS DISTINCT FROM r."expectedDecider"
                                 THEN ', decider ' || coalesce(r."liveDecider", '<null>')
                                      || ' (expected '
                                      || coalesce(r."expectedDecider", '<null>') || ')'
                                 ELSE '' END
                         || CASE WHEN r."liveTimestamp"
                                      IS DISTINCT FROM r."expectedDecisionTimestamp"
                                 THEN ', timestamp ' || coalesce(r."liveTimestamp"::text, '<null>')
                                      || ' (expected '
                                      || coalesce(r."expectedDecisionTimestamp"::text, '<null>') || ')'
                                 ELSE '' END
                         || CASE WHEN r."voidsHumanApproval"
                                 THEN ' -- THIS IS A VOIDED HUMAN APPROVAL' ELSE '' END
                         || '], ';
            CONTINUE;
        END IF;

        -- (4) THE CLAIMED VERDICT MOVED. The digest pins every field checked
        --     above PLUS `metadataJson`, so it catches an `engineering_review`
        --     decision that has been re-pointed at a different reviewer
        --     execution or had its claimed verdict rewritten. NAMED, NOT CAST
        --     INLINE: `metadataJson` is nullable TEXT and is not guaranteed to
        --     hold parseable JSON, so the guard's parseability test comes first
        --     and the digest reads `meta`, which is a jsonb by construction.
        meta := NULL;
        BEGIN
            SELECT r."liveMetadataJson"::jsonb INTO meta;
        EXCEPTION WHEN others THEN
            offenders := offenders
                         || r."decisionId"
                         || ' [metadataJson is not parseable JSON: '
                         || coalesce(left(r."liveMetadataJson", 80), '<null>')
                         || '], ';
        END;
        IF meta IS NOT NULL AND jsonb_typeof(meta) <> 'object' THEN
            offenders := offenders
                         || r."decisionId"
                         || ' [metadataJson is JSON '
                         || jsonb_typeof(meta) || ', not an object], ';
            CONTINUE;
        END IF;

        observed := md5(jsonb_build_object(
                            'status', r."liveStatus",
                            'choice', r."liveChoice",
                            'resolvedOptionId', r."liveResolvedOptionId",
                            'decider', r."liveDecider",
                            'rationale', r."liveRationale",
                            'signatureJson', r."liveSignatureJson",
                            'timestamp', r."liveTimestamp",
                            'metadataJson', r."liveMetadataJson")::text);
        IF observed IS DISTINCT FROM r."expectedDecisionDigest" THEN
            offenders := offenders
                         || r."decisionId"
                         || ' [the decision metadata changed since this '
                         'migration was written: digest ' || observed
                         || ', expected ' || r."expectedDecisionDigest" || '], ';
            CONTINUE;
        END IF;

        -- (5) METADATA THAT CANNOT BE MERGED, on the work item's row. Checked
        --     last, because a target that has drifted must be reported for what
        --     it drifted on rather than for an incidental parse failure.
        itemMeta := NULL;
        BEGIN
            SELECT r."liveItemMetadataJson"::jsonb INTO itemMeta;
        EXCEPTION WHEN others THEN
            offenders := offenders
                         || r."workItemId"
                         || ' [work_item.metadataJson is not parseable JSON], ';
        END;
        IF itemMeta IS NOT NULL AND jsonb_typeof(itemMeta) <> 'object' THEN
            offenders := offenders
                         || r."workItemId"
                         || ' [work_item.metadataJson is JSON '
                         || jsonb_typeof(itemMeta) || ', not an object], ';
            CONTINUE;
        END IF;
    END LOOP;

    IF offenders <> '' OR missing <> '' THEN
        RAISE EXCEPTION
            'unreviewed-review-repair refused. Targets whose work item is gone: %. '
            'Targets that have moved since this migration was written: %. '
            'This migration voids only the five decisions human decision '
            '8f1ed5bf-4147-449a-a221-558aac2303a9 enumerated, and it refuses '
            'rather than re-deciding any target that has moved since that list '
            'was written. Voiding a decision that has since been resolved by a '
            'human would be far worse than the defect being repaired. Nothing '
            'was changed: no decision was voided, no work item moved, no '
            'approval disturbed.',
            CASE WHEN missing <> '' THEN left(missing, length(missing) - 2) ELSE 'none' END,
            CASE WHEN offenders <> '' THEN left(offenders, length(offenders) - 2) ELSE 'none' END;
    END IF;
END $$;

--
-- THE WORK ITEM, and the fresh review key that lets the re-review dispatch.
--
-- ORDERING IS LOAD-BEARING, AND IT IS THE REVERSE OF THE OBVIOUS ONE. This
-- block runs BEFORE the decision is voided, not after, because the audit row it
-- writes is the restore payload the DOWN section reads back. Every
-- `priorDecision*` field is read out of `human_decision` at this point; if the
-- decision had already been voided, this statement would record the
-- ALREADY-UPDATED row as the "prior" one, and the rollback would restore the
-- repair's own output while claiming to undo it -- a rollback that silently does
-- the wrong thing, which is the exact defect `20261014093000000`'s DOWN section
-- documents and does not commit. Both statements are inside one transaction, so
-- the order the rows become visible in is not an ordering an applier can
-- observe.
--
-- "IN SCOPE" IS THE PINS, RE-ASSERTED. The drift guard above established that
-- every enumerated target still matches. This statement re-asserts the same
-- conditions next to the write, which is a different job: the guard ran in an
-- earlier statement and this row has been locked only since this one started. A
-- concurrent writer that moved the item in between must not be overwritten.
--
-- The marker arms below replicate DurableWorkflowEngine.readTriageAttempt
-- exactly, for the reason stated in the banner: two copies of "how a marker is
-- read" is how a writer and a reader come to disagree about which numbers are
-- attempts, and the disagreement would build a key nothing holds and enqueue
-- nothing.
WITH "parsed" AS (
    SELECT w."workItemId",
           w."version",
           w."blockingHumanDecisionId",
           w."blockingReason",
           t."decisionId",
           t."expectedState",
           t."expectedBlockingDecisionId",
           (CASE
                WHEN w."metadataJson" IS NULL
                  OR btrim(w."metadataJson") = ''
                  OR btrim(w."metadataJson") NOT LIKE '{%'
                THEN NULL
                ELSE w."metadataJson"::jsonb
             END) AS "meta"
      FROM "shipit_unreviewed_review_repair_target" t
      JOIN work_item w ON w."workItemId" = t."workItemId"
     WHERE w."state" = t."expectedState"
       AND w."blockingHumanDecisionId"
               IS NOT DISTINCT FROM t."expectedBlockingDecisionId"
       -- THE DECISION MUST BE THERE, and this arm is not a formality. The
       -- drift guard SKIPS a target whose decision is absent -- there is
       -- nothing to void, and a work item parked with no decision is a
       -- different defect this migration has no instruction to fix -- so if
       -- this CTE did not re-assert the decision's existence, it would move
       -- exactly those items the guard declined to touch, and write an audit
       -- row claiming a decision was voided that was never read. Its
       -- `priorDecisionStatus` would be null. The guard and the statement it
       -- guards disagreed about what "in scope" means, and only the audit row
       -- would have shown it: a moved item, an un-voided question, and a
       -- ledger entry saying otherwise.
       AND EXISTS (
               SELECT 1 FROM human_decision d
                WHERE d."decisionId" = t."decisionId"
           )
       -- IDEMPOTENCE BY ID, on the audit row this statement writes.
       AND NOT EXISTS (
               SELECT 1 FROM "work_item_transition" x
                WHERE x."transitionId" =
                          'tr-unreviewed-review-repair-' || w."workItemId"
                  AND x."idempotencyKey" =
                          'unreviewed-review-repair:void-fabricated-verdict'
                  AND x."guardEvaluationsJson"::jsonb ->> 'decisionId'
                      = t."decisionId"
           )
),
"marker" AS (
    -- An ABSENT key and an EXPLICIT JSON null both mean null to the Dart reader,
    -- which resolves both to the bare key; the first arm tests the missing key
    -- (jsonb_typeof -> NULL) and the second the literal JSON null.
    SELECT p.*,
           (CASE
                WHEN jsonb_typeof(p."meta" -> 'triageAttempt') IS NULL      THEN 'absent'
                WHEN jsonb_typeof(p."meta" -> 'triageAttempt') = 'null'     THEN 'absent'
                WHEN jsonb_typeof(p."meta" -> 'triageAttempt') = 'number'
                     AND (p."meta" ->> 'triageAttempt') ~ '^-?[0-9]{1,18}$' THEN 'int'
                WHEN jsonb_typeof(p."meta" -> 'triageAttempt') = 'number'
                     AND (p."meta" ->> 'triageAttempt')
                         ~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$'
                     AND (p."meta" ->> 'triageAttempt')::numeric
                         = trunc((p."meta" ->> 'triageAttempt')::numeric)
                     AND abs((p."meta" ->> 'triageAttempt')::numeric)
                         < 1000000000000000000
                                                                            THEN 'whole-double'
                WHEN jsonb_typeof(p."meta" -> 'triageAttempt') = 'string'
                     AND (p."meta" ->> 'triageAttempt') ~ '^[+-]?[0-9]{1,18}$'
                                                                            THEN 'numeric-string'
                ELSE 'unreadable'
             END) AS "markerForm"
      FROM "parsed" p
),
"attempted" AS (
    SELECT m.*,
           (CASE
                WHEN m."markerForm" = 'int'            THEN (m."meta" ->> 'triageAttempt')::bigint
                WHEN m."markerForm" = 'whole-double'   THEN trunc((m."meta" ->> 'triageAttempt')::numeric)::bigint
                WHEN m."markerForm" = 'numeric-string' THEN (m."meta" ->> 'triageAttempt')::bigint
                ELSE NULL
             END) AS "markerAttempt"
      FROM "marker" m
),
"keyed" AS (
    -- The highest attempt this item's OWN engineering_review jobs have consumed.
    -- The floor is what makes the key this writes provably unheld. An UNSUFFIXED
    -- key consumes no attempt and contributes nothing, which is correct: it is
    -- the bare form that every suffix moves away from. MEASURED: the fifth
    -- target already holds `:a3`, and without this arm its marker of 3 would
    -- hand back `:a3` and deduplicate the re-review against the attempt it is
    -- replacing.
    SELECT a.*,
           COALESCE((
               SELECT max(CASE
                            WHEN substring(j."dedupeKey"
                                            from ':engineering_review:a(.*)$')
                                      ~ '^[0-9]{1,18}$'
                            THEN substring(j."dedupeKey"
                                            from ':engineering_review:a(.*)$')::bigint
                          END)
                 FROM job j
                WHERE j."workItemId" = a."workItemId"
                  AND j."jobType" = 'engineering_review'
           ), 0) AS "jobFloor"
      FROM "attempted" a
),
"selected" AS (
    SELECT k.*,
           greatest(COALESCE(k."markerAttempt", 0), k."jobFloor") + 1 AS "newAttempt"
      FROM "keyed" k
     -- An unreadable marker is skipped, not repaired -- as in
     -- 20261014093000000. Such an item already fails loudly in
     -- engineeringReviewDedupeKey on every tick, and the value that should
     -- replace it is undefined. It is NOT drift, so it is not reported: it is a
     -- pre-existing condition this migration has no opinion about, and the
     -- repair is not what would fix it.
     WHERE k."markerForm" <> 'unreadable'
),
"repaired" AS (
    UPDATE work_item w
       SET -- jsonb `||` MERGES, never replaces: the defect payload the re-run
           -- triage reads must survive or the item classifies nothing while
           -- looking healthy.
           "state" = 'agent_completed',
           "blockingHumanDecisionId" = NULL,
           "blockingReason" = NULL,
           "metadataJson" = (
               COALESCE(s."meta", '{}'::jsonb)
               || jsonb_build_object('triageAttempt', s."newAttempt"))::text,
           "updatedAt" = now(),
           "version" = w."version" + 1
      FROM "selected" s
     WHERE w."workItemId" = s."workItemId"
       -- Re-asserted: after this row is locked, a concurrent writer that moved
       -- the item must not be overwritten. `version` is the compare-and-swap the
       -- engine itself uses, and the two pins are the conditions the drift
       -- guard established.
       AND w."version" = s."version"
       AND w."state" = s."expectedState"
       AND w."blockingHumanDecisionId"
               IS NOT DISTINCT FROM s."expectedBlockingDecisionId"
       AND (CASE
               WHEN w."metadataJson" IS NULL
                 OR btrim(w."metadataJson") = ''
                 OR btrim(w."metadataJson") NOT LIKE '{%'
               THEN NULL
               -- An explicit JSON null normalises to SQL NULL so it compares
               -- equal to the NULL the selection carried for an 'absent' marker.
               -- Without this, an item marked `"triageAttempt": null` would pass
               -- the selection and then never be updated -- silently unrepaired.
               WHEN jsonb_typeof(w."metadataJson"::jsonb -> 'triageAttempt')
                       = 'null'
               THEN NULL
               ELSE w."metadataJson"::jsonb -> 'triageAttempt'
            END) IS NOT DISTINCT FROM
           (CASE WHEN s."markerForm" = 'absent'
                 THEN NULL
                 ELSE s."meta" -> 'triageAttempt'
            END)
     RETURNING w."workItemId",
               s."expectedState" AS "fromState",
               s."decisionId",
               s."blockingHumanDecisionId",
               s."blockingReason",
               s."meta",
               s."markerForm",
               s."markerAttempt",
               s."jobFloor",
               s."newAttempt"
)
INSERT INTO "work_item_transition"
    ("transitionId", "workItemId", "fromState", "toState", "trigger", "actorType",
     "actorId", "decisionId", "outcome", "reason", "guardEvaluationsJson",
     "idempotencyKey", "occurredAt")
SELECT 'tr-unreviewed-review-repair-' || r."workItemId",
       r."workItemId",
       r."fromState",
       'agent_completed',
       'system_event',
       'orchestrator',
       'orchestrator',
       r."decisionId",
       'accepted',
       'Data repair (migration 20261014210000000), voiding engineering-review '
       || 'decision ' || r."decisionId" || ' under recorded human decision '
       || '8f1ed5bf-4147-449a-a221-558aac2303a9 (DATA_REMEDIATION, RESOLVED). '
       || 'EngineeringReviewGate used to default a missing verdict to '
       || 'changes_required; that default was removed in 93587cf, and this '
       || 'decision was raised by it, claiming the verdict "'
       || COALESCE(
              (SELECT d."metadataJson"::jsonb ->> 'reviewVerdict'
                FROM human_decision d
               WHERE d."decisionId" = r."decisionId"
                 AND btrim(COALESCE(d."metadataJson", '')) LIKE '{%'),
              'none')
       || '" for a reviewer that produced no such machine-readable verdict. '
       || CASE
              -- READ FROM THE REVIEWER'S OWN RESULT, not from a marker on the
              -- decision. An earlier revision tested
              -- `metadata ? 'reviewUnreviewedApprovalVoided'`, which is wrong
              -- TWICE: it is not the marker that records prose (the decision
              -- UPDATE that writes the prose marker has not run yet -- this
              -- audit row is written BEFORE it), and a ledger sentence about
              -- discarding a review is not a thing to decide by asking the
              -- decision about itself. `agent_result.summary` is the one place
              -- the answer lives, and it is the same source
              -- `reviewUnreviewedProsePreservedAt` below uses, so the two
              -- cannot disagree.
              WHEN EXISTS (
                      SELECT 1
                        FROM agent_result ar
                       WHERE ar."executionId" =
                                 (SELECT d2."metadataJson"::jsonb
                                            ->> 'reviewExecutionId'
                                   FROM human_decision d2
                                  WHERE d2."decisionId" = r."decisionId"
                                    AND btrim(COALESCE(d2."metadataJson", ''))
                                          LIKE '{%')
                         AND btrim(COALESCE(ar."summary", '')) <> '')
              THEN 'THE REVIEWER DID WRITE A REAL ASSESSMENT (still in '
                   'agent_result.summary for execution '
                   || COALESCE(
                          (SELECT d5."metadataJson"::jsonb
                                     ->> 'reviewExecutionId'
                             FROM human_decision d5
                            WHERE d5."decisionId" = r."decisionId"
                              AND btrim(COALESCE(d5."metadataJson", ''))
                                    LIKE '{%'),
                          'unknown')
                   || '), and it is voided anyway: the operator was asked '
                   'whether to re-derive this claim from the reviewer''s prose '
                   'or to re-run the review, and chose to re-run, because the '
                   'claim and the prose came out of the same run the bug '
                   'corrupted. '
              ELSE ''
          END
       || CASE
              WHEN (
                  SELECT d3."choice"
                    FROM human_decision d3
                   WHERE d3."decisionId" = r."decisionId"
                     AND d3."status" = 'resolved')
                 IS NOT NULL
              THEN 'THIS DECISION HAD ALREADY BEEN APPROVED BY A HUMAN '
                   '(decider='
                   || COALESCE((SELECT d4."decider" FROM human_decision d4 WHERE d4."decisionId" = r."decisionId"), '<null>')
                   || ', choice='
                   || COALESCE((SELECT d5."choice" FROM human_decision d5 WHERE d5."decisionId" = r."decisionId"), '<null>')
                   || ', at '
                   || COALESCE((SELECT to_char(d6."timestamp", 'YYYY-MM-DD"T"HH24:MI:SS.US') FROM human_decision d6 WHERE d6."decisionId" = r."decisionId"), '<null>')
                   || '), and the work item had already advanced on it to '
                   || r."fromState" || '. That approval is VOIDED by the '
                   'operator''s recorded decision and is PRESERVED VERBATIM in '
                   'human_decision.metadata.reviewUnreviewedApprovalVoided and '
                   'in this row''s guardEvaluationsJson; none of its columns is '
                   'written. The item returns from ' || r."fromState" || ' to '
                   'agent_completed so the review is genuinely re-run rather '
                   'than merely unblocked. '
              ELSE 'The item returns from ' || r."fromState" || ' to '
                   'agent_completed, which IS engineeringReviewDefinition.'
                   'entryStates. '
          END
       || 'The decision is RETIRED, not deleted: its question, options, '
       || 'recommendation and context are preserved verbatim as the evidence '
       || 'of what was claimed, and it carries markers naming this repair. '
       || 'metadata.triageAttempt advances from '
       || COALESCE(r."markerAttempt"::text, 'absent') || ' to '
       || r."newAttempt"::text || ', giving the provably unheld key '
       || r."workItemId" || ':engineering_review:a' || r."newAttempt"::text
       || ' (the discriminator is greatest(marker, highest attempt this item''s '
       || 'own engineering_review job keys had consumed = ' || r."jobFloor"::text
       || ') + 1, and no job holds it). NO TRANSITION EDGE WAS TAKEN: '
       || r."fromState" || ' -> agent_completed does not exist in '
       || 'WorkItemTransitions, because no edge models "a question was asked '
       || 'that nobody asked" and none models "an approval rested on nothing", '
       || 'so the state is written directly inside this transaction with this '
       || 'row as its record. No verdict was invented, none was read from the '
       || 'decision itself, no resolution column was written, and no row '
       || 'outside human_decision, work_item and work_item_transition was '
       || 'touched.',
       -- THE RESTORE PAYLOAD. This migration IS exactly reversible, and it is
       -- reversible because the before-image is stored here rather than
       -- recomputed by the rollback. Every field below is what the DOWN section
       -- puts back, verbatim, including the two cases a recompute gets wrong:
       -- an `absent` triageAttempt must be REMOVED rather than set to 0
       -- (absent reads as the bare key, 0 reads as `:a0`, which nothing ever
       -- mints), and the decision's prior metadata is restored as the exact
       -- text it was, not as a merge of keys this migration removed.
       --
       -- The `priorDecision*` resolution columns are carried here for the
       -- RECORD, not for the restore: no statement above writes them, so the
       -- DOWN section does not put them back. Copying them here means an
       -- auditor can read what the voided approval was without trusting the
       -- decision row it was taken from, and it makes the "not written"
       -- property checkable against the file rather than inferred.
       jsonb_build_object(
           'migration', '20261014210000000',
           -- `r.` IS LOAD-BEARING. Written unqualified, this bare
           -- `"decisionId"` inside a correlated subquery below binds to the
           -- SUBQUERY's own `human_decision.decisionId`, making the predicate
           -- tautological, returning every decision, and failing the whole
           -- INSERT with "more than one row returned by a subquery used as an
           -- expression". The test suite found that; the comment is here so the
           -- qualification is not "tidied away" as noise next time.
           'decisionId', r."decisionId",
           'voidedHumanApproval', EXISTS (
               SELECT 1 FROM human_decision v
                WHERE v."decisionId" = r."decisionId"
                  AND v."status" = 'resolved'
                  AND v."choice" IS NOT NULL),
           -- Read from the still-un-voided decision row. See the ORDERING note
           -- above: this is the whole reason the work item is repaired first.
           'priorDecisionStatus', (
               SELECT d."status"
                 FROM human_decision d
                WHERE d."decisionId" = r."decisionId"),
           'priorDecisionMetadataJson', (
               SELECT d."metadataJson"
                 FROM human_decision d
                WHERE d."decisionId" = r."decisionId")::text,
           -- NOT WRITTEN BY THIS MIGRATION. Carried for the record.
           'priorDecisionChoice', (
               SELECT d."choice"
                 FROM human_decision d
                WHERE d."decisionId" = r."decisionId"),
           'priorDecisionResolvedOptionId', (
               SELECT d."resolvedOptionId"
                 FROM human_decision d
                WHERE d."decisionId" = r."decisionId"),
           'priorDecisionDecider', (
               SELECT d."decider"
                 FROM human_decision d
                WHERE d."decisionId" = r."decisionId"),
           'priorDecisionRationale', (
               SELECT d."rationale"
                 FROM human_decision d
                WHERE d."decisionId" = r."decisionId"),
           'priorDecisionSignatureJson', (
               SELECT d."signatureJson"
                 FROM human_decision d
                WHERE d."decisionId" = r."decisionId")::text,
           'priorDecisionTimestamp', (
               SELECT to_char(d."timestamp", 'YYYY-MM-DD"T"HH24:MI:SS.US')
                 FROM human_decision d
                WHERE d."decisionId" = r."decisionId"),
           'priorBlockingHumanDecisionId', r."blockingHumanDecisionId",
           'priorBlockingReason', r."blockingReason",
           'priorTriageAttemptForm', r."markerForm",
           'priorTriageAttempt', r."markerAttempt",
           'newTriageAttempt', r."newAttempt")::text,
       'unreviewed-review-repair:void-fabricated-verdict',
       now()
  FROM "repaired" r;

--
-- THE VOIDED DECISION. Kept, never deleted: status becomes `cancelled`, every
-- human-readable field is preserved verbatim, and the markers record why.
--
-- THE COMPARE-AND-SWAP IS COLUMN-BY-COLUMN, NOT THE DIGEST. The drift guard
-- already proved the row matches the pins; this statement re-asserts the same
-- conditions against the row as it stands NOW that this row has been locked,
-- because a concurrent writer could have moved the decision between the guard's
-- statement and this one. Every column the earlier revision wrote or reasoned
-- about is pinned here directly, which is strictly stronger than re-computing
-- the digest -- and, unlike the digest, it is a second expression that can be
-- read against the pins in the target table without decoding a hash.
--
-- NOTE WHAT IS NOT IN THE WHERE CLAUSE: `choice IS NULL`. The earlier revision
-- of this migration refused any decision a human had answered, and that arm is
-- exactly what the operator's decision overrode for the one approved target. It
-- is replaced, not weakened: the approved target's `choice`, `decider`,
-- `rationale`, `signatureJson`, `resolvedOptionId` and `timestamp` are all
-- pinned to the values the operator approved being voided, so a DIFFERENT
-- approval is refused while THIS one proceeds.
--
-- The claimed verdict is copied into the metadata under a key that NAMES it as
-- a claim, so the evidence is explicit and can never be mistaken for a verdict
-- later. It is read from the decision's own `reviewVerdict`, which is the field
-- under repair -- copying it is RECORDING what was asserted, not believing it.
WITH "parsed" AS (
    SELECT d."decisionId",
           d."workItemId",
           d."status",
           d."choice",
           d."resolvedOptionId",
           d."decider",
           d."rationale",
           d."signatureJson",
           d."timestamp",
           (CASE
                WHEN d."metadataJson" IS NULL
                  OR btrim(d."metadataJson") = ''
                  OR btrim(d."metadataJson") NOT LIKE '{%'
                THEN NULL
                ELSE d."metadataJson"::jsonb
             END) AS "meta"
      FROM "shipit_unreviewed_review_repair_target" t
      JOIN human_decision d ON d."decisionId" = t."decisionId"
      JOIN work_item w      ON w."workItemId" = t."workItemId"
     WHERE w."state" = 'agent_completed'
       AND w."blockingHumanDecisionId" IS NULL
       -- IDEMPOTENCE BY ID, on the column this statement writes, AND on the
       -- audit row the statement above wrote. The marker alone is not enough: a
       -- decision could carry it while its item was moved back by something
       -- else, and re-voiding it would double-count the audit trail.
       AND EXISTS (
               SELECT 1 FROM "work_item_transition" x
                WHERE x."transitionId" =
                          'tr-unreviewed-review-repair-' || w."workItemId"
                  AND x."idempotencyKey" =
                          'unreviewed-review-repair:void-fabricated-verdict'
                  AND x."guardEvaluationsJson"::jsonb ->> 'decisionId'
                      = t."decisionId"
           )
       AND (CASE
               WHEN d."metadataJson" IS NULL
                 OR btrim(d."metadataJson") = ''
                 OR btrim(d."metadataJson") NOT LIKE '{%'
               THEN NULL
               ELSE d."metadataJson"::jsonb
            END) ->> 'reviewUnreviewable' IS DISTINCT FROM 'true'
)
UPDATE human_decision d
   SET "status" = 'cancelled',
       "metadataJson" = (
           COALESCE(p."meta", '{}'::jsonb)
           || jsonb_build_object(
                  'reviewUnreviewable', true,
                  'reviewUnreviewableRetiredAt', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
                  'reviewUnreviewableRetiredBy', 'migration 20261014210000000',
                  'reviewUnreviewedByDecision', '8f1ed5bf-4147-449a-a221-558aac2303a9',
                  'reviewUnreviewableReason',
                      'No reviewer produced the verdict this decision claims. '
                      'EngineeringReviewGate used to default a missing verdict '
                      'to changes_required (removed in 93587cf); this decision '
                      'was raised by that default and was shown to an operator '
                      'as a real review result. It is VOIDED, not deleted: '
                      'every field a human could read is preserved verbatim '
                      'as the evidence of what was claimed.',
                  'reviewUnreviewedExecutionId', p."meta" ->> 'reviewExecutionId',
                  'reviewUnreviewableClaimedVerdict', p."meta" ->> 'reviewVerdict',
                  'reviewUnreviewedMigration', '20261014210000000'
              )
           -- The preserved approval, or the ABSENCE of one. Emitted in BOTH
           -- arms and never conditional, so `? 'reviewUnreviewedApprovalVoided'`
           -- is a question about this migration rather than about whichever
           -- target happened to be resolved. A reader can tell "voided an
           -- approval" from "there was no approval" without inferring it.
           || jsonb_build_object(
                  'reviewUnreviewedApprovalVoided',
                  CASE
                      WHEN p."status" = 'resolved' AND p."choice" IS NOT NULL
                      THEN jsonb_build_object(
                               'voidedAt', to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
                               'voidedBy', 'migration 20261014210000000',
                               'voidedUnderHumanDecision', '8f1ed5bf-4147-449a-a221-558aac2303a9',
                               'why',
                                   'An operator resolved this decision and its '
                                   'work item advanced to review_approved on '
                                   'that resolution -- but the decision was '
                                   'raised by a gate that had fabricated the '
                                   'verdict it asked about, so the thing '
                                   'approved was never reviewed. The operator '
                                   'was shown this fact and chose, explicitly, '
                                   'to void the approval and re-run the review '
                                   'from scratch rather than preserve anything '
                                   'derived from a fabricated claim.',
                               'preservedChoice', p."choice",
                               'preservedResolvedOptionId', p."resolvedOptionId",
                               'preservedDecider', p."decider",
                               'preservedRationale', p."rationale",
                               'preservedSignature',
                                   -- BOTH BRANCHES ARE jsonb, and that is the
                                   -- whole reason this is not a bare cast. A
                                   -- CASE whose branches are `text` and
                                   -- `jsonb` does not coerce -- it fails to
                                   -- resolve, with "CASE types jsonb and text
                                   -- cannot be matched", and it fails at RUN
                                   -- time rather than at author time, which is
                                   -- why it only surfaced on a real database.
                                   -- `to_jsonb` on an unparseable signature
                                   -- keeps it as a JSON string instead of
                                   -- raising, so an operator signature that is
                                   -- not an object is preserved rather than
                                   -- refusing the whole migration over it.
                                   CASE
                                       WHEN p."signatureJson" IS NULL
                                            OR btrim(p."signatureJson")
                                                   NOT LIKE '{%'
                                       THEN to_jsonb(p."signatureJson")
                                       ELSE p."signatureJson"::jsonb
                                   END,
                               'preservedTimestamp',
                                   to_char(p."timestamp", 'YYYY-MM-DD"T"HH24:MI:SS.US')
                           )
                      ELSE jsonb_build_object('none', true)
                  END)
              -- Where a reviewer's real prose survives, named. The prose is NOT
              -- copied here: `agent_result.summary` is untouched by this
              -- migration and remains the only copy, deliberately, so that a
              -- re-run review cannot be confused with the review it replaces.
              || jsonb_build_object(
                     'reviewUnreviewedProsePreservedAt',
                     COALESCE(
                         (SELECT ar."executionId" || ' (agent_result.summary, untouched)'
                            FROM agent_result ar
                           WHERE ar."executionId" = p."meta" ->> 'reviewExecutionId'
                             AND btrim(COALESCE(ar."summary", '')) <> ''),
                         'none')))::text,
       "updatedAt" = now()
  FROM "parsed" p
 WHERE d."decisionId" = p."decisionId"
   -- Re-asserted: after this row is locked, a concurrent writer must not be
   -- overwritten. This is the approved target's last line of defence.
   AND d."status" = p."status"
   AND d."choice" IS NOT DISTINCT FROM p."choice"
   AND d."resolvedOptionId" IS NOT DISTINCT FROM p."resolvedOptionId"
   AND d."decider" IS NOT DISTINCT FROM p."decider"
   AND d."rationale" IS NOT DISTINCT FROM p."rationale"
   AND d."signatureJson" IS NOT DISTINCT FROM p."signatureJson"
   AND d."timestamp" IS NOT DISTINCT FROM p."timestamp"
   AND d."metadataJson" IS NOT DISTINCT FROM (
       SELECT d2."metadataJson"
         FROM human_decision d2
        WHERE d2."decisionId" = p."decisionId");

--
-- MIGRATION VERSION FOR control_plane
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('control_plane', '20261014210000000', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261014210000000', "timestamp" = now();

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
-- WARNING: this restores the defect, in full. Each item goes back to where it
-- was, four of them behind a decision that claims a reviewer verdict nobody
-- produced and the fifth at `review_approved` behind an approval this migration
-- voided. Run it only to return a database to its pre-migration shape, then
-- re-apply this migration instead.
--
-- ONE FIELD IS NOT PUT BACK, AND IT IS DELIBERATE: the voided approval. The UP
-- pass never wrote `decider`, `choice`, `rationale`, `signatureJson`,
-- `resolvedOptionId` or `timestamp`, so those columns are already exactly what
-- they were, and the DOWN section writing them would be a second, redundant
-- write of a human record on the strength of a rollback. They are carried in the
-- audit row's `guardEvaluationsJson` for the record; the rollback restores
-- `status` and `metadataJson`, which are the only two columns the UP touched.
--
-- This one IS exactly reversible, and that is a deliberate departure from the
-- EARLIER REPAIRS IN THIS REPOSITORY. Read `20261014093000000`'s DOWN section
-- and it states in full that it does NOT restore the pre-migration
-- `triageAttempt` in two of three cases -- an absent marker comes back as `0`,
-- and a marker below the job floor comes back as the floor -- and that it
-- leaves that wrong rather than editing its own semantics to compensate.
--
-- This one does not have that gap in the place that mattered, because it does
-- not RECOMPUTE the before-image at rollback time. Every UPDATE below reads this
-- migration's own audit row, whose `guardEvaluationsJson` carries the exact
-- prior values it recorded at repair time. Nothing is inferred, so nothing can
-- be inferred wrongly.
--
-- WHAT IS EXACT, AND WHAT IS NOT, STATED PLAINLY. Three of the things the
-- rollback restores are restored BYTE-FOR-BYTE, and one is not:
--
--   * `work_item.state`, `blockingHumanDecisionId` and `blockingReason` are
--     ordinary text columns, restored verbatim from the audit row. For the
--     approved target that means `review_approved` and a NULL blocking pointer,
--     which is precisely the state the approval had put it in.
--   * `human_decision.metadataJson` is restored byte-for-byte too, because
--     `priorDecisionMetadataJson` was captured from the row as the exact TEXT
--     that was there (`::text` on an already-text column is a no-op) BEFORE this
--     migration rewrote it, and a JSON string value survives jsonb unchanged.
--   * `work_item.metadataJson` is restored SEMANTICALLY, not textually: same
--     keys, same values, possibly different bytes. The UP pass writes it as
--     `(jsonb || jsonb)::text`, and jsonb normalises on the way in -- it
--     reorders keys and inserts a space after every colon. Once the document
--     has been through that, the original bytes no longer exist and no rollback
--     can return them. This is inherent to merging with `||` rather than
--     overwriting the column, and overwriting would have destroyed the defect
--     payload, which is the far worse outcome. It is stated here rather than
--     left for an auditor to discover from a failing byte comparison.
--
-- The absent-marker branch removes the `triageAttempt` key rather than writing
-- `0`. Absent reads as `null` and builds the BARE key; `0` reads as `0` and
-- builds `:a0`, a discriminator `nextTriageAttempt` never mints. A rollback
-- that wrote `0` would be subtly and permanently wrong.
--
-- THE STATEMENT ORDER IS THE REVERSE OF THE EARLIER REPAIRS', AND THAT IS A FIX,
-- NOT A COSMETIC DIFFERENCE. `20261012150000000` and `20261012195523112` both
-- DELETE the audit rows FIRST and then run an UPDATE whose EXISTS arm keys off
-- those same audit rows -- so by the time the UPDATE runs the rows it is looking
-- for are already gone and it restores NOTHING. Read those two DOWN sections and
-- the bug is invisible: the statements look right in isolation. Here every
-- restore runs FIRST and the audit rows are deleted after, which is the only
-- order in which the arms can match anything.
--
-- ---------------------------------------------------------------------------
-- THE ROLLBACK HAS A TIME WINDOW, AND IT CLOSES ON ITS OWN
--
-- READ THIS BEFORE RUNNING `down`. Step 1 below carries
-- `AND w."state" = 'agent_completed'`. That guard is CORRECT and must stay -- a
-- blind restore would put an item back to `waiting_for_human_decision` behind a
-- decision that has long since moved on, clobbering whatever it has become. But
-- it has a consequence an operator needs stated rather than discovered:
--
--   * THE ROLLBACK RESTORES ONLY WHILE THE REPAIRED ITEMS ARE STILL PARKED AT
--     `agent_completed`. That state is `engineeringReviewDefinition.entryStates`,
--     so the ordinary scheduler tick treats it as runnable and DISPATCHES the
--     re-review that this migration was written to set up.
--
--   * ONCE THE TICK HAS DISPATCHED, THE ITEM LEAVES `agent_completed` -- THE
--     GUARD MATCHES NOTHING, AND THE ROLLBACK IS A SILENT NO-OP ON THAT ITEM.
--     It still deletes this migration's audit rows in step 3, and it still rolls
--     the `serverpod_migrations` version back in step 4. What it does NOT do is
--     restore the item or un-void the decision, because it no longer has a row
--     to read a before-image from. There is no warning, no error and no affected
--     -row count printed: the statements simply match zero rows and succeed.
--
-- IN SHORT: THE WINDOW IS "BEFORE THE RE-QUEUED REVIEW RUNS", AND IT IS NOT A
-- TIME YOU CONTROL. If this DOWN is being considered because the re-review is
-- producing bad results, the tick has very probably already dispatched, and the
-- rollback will do nothing to the item. Check the state first:
--
--     SELECT "state", "blockingHumanDecisionId" FROM "work_item"
--      WHERE "workItemId" IN (...the five enumerated targets...);
--
-- Anything other than `agent_completed` means this rollback cannot restore it.
-- That is the guard working, not the rollback failing -- but the distinction is
-- invisible without this paragraph, which is why it is here.
--
-- ---------------------------------------------------------------------------
-- DOWN SCRIPT -- EXECUTABLE REGION
--
-- Everything ABOVE this region is prose and stays prose. Everything INSIDE it is
-- SQL, written with one leading `-- ` so the whole block is inert and is never
-- executed by accident; the test harness strips exactly that one prefix and
-- runs what is left, so a `down` that is described one way and written another
-- fails rather than quietly rolling nothing back.
--
-- The convention that makes that safe: a COMMENT inside this region is written
-- `-- -- text`, so it survives the prefix strip as `-- text` and is still a
-- comment. Prose belongs outside the region.
-- ---------------------------------------------------------------------------

-- -- DOWN SCRIPT START
-- BEGIN;
-- -- 1. Put the work item back, reading EVERY prior value off this migration's
-- -- own audit row rather than naming a literal or recomputing one. This one
-- -- UPDATE covers both from-states: the approved target returns to
-- -- `review_approved` with a NULL blocking pointer, and the other four return
-- -- to `waiting_for_human_decision` behind their decision, because
-- -- `fromState` and `priorBlockingHumanDecisionId` are per-row fields read out
-- -- of the audit rather than literals written here.
-- UPDATE work_item w
--    SET "state" = x."fromState",
--        "blockingHumanDecisionId" = x."guardEvaluationsJson"::jsonb ->> 'priorBlockingHumanDecisionId',
--        "blockingReason" = x."guardEvaluationsJson"::jsonb ->> 'priorBlockingReason',
--        "metadataJson" = (
--              (CASE
--                 WHEN w."metadataJson" IS NULL
--                   OR btrim(w."metadataJson") = ''
--                   OR btrim(w."metadataJson") NOT LIKE '{%'
--                 THEN NULL
--                 ELSE w."metadataJson"::jsonb
--               END)
--              -- `absent` REMOVES the key. Setting it to 0 instead would give
--              -- the item `:a0`, a discriminator nothing ever mints, and would
--              -- silently change what the item computes on the next tick.
--              || CASE WHEN x."guardEvaluationsJson"::jsonb ->> 'priorTriageAttemptForm' = 'absent'
--                      THEN (CASE
--                              WHEN w."metadataJson" IS NULL
--                                OR btrim(w."metadataJson") = ''
--                                OR btrim(w."metadataJson") NOT LIKE '{%'
--                              THEN NULL
--                              ELSE w."metadataJson"::jsonb
--                           END) - 'triageAttempt'
--                      ELSE jsonb_build_object('triageAttempt',
--                               (x."guardEvaluationsJson"::jsonb ->> 'priorTriageAttempt')::bigint)
--                 END)::text,
--        "updatedAt" = now(),
--        "version" = w."version" + 1
--   FROM "work_item_transition" x
--  WHERE x."transitionId" = 'tr-unreviewed-review-repair-' || w."workItemId"
--    AND x."idempotencyKey" = 'unreviewed-review-repair:void-fabricated-verdict'
--    AND x."toState" = 'agent_completed'
--    AND w."state" = 'agent_completed'
--    AND x."guardEvaluationsJson" IS NOT NULL;
--
-- -- 2. Un-void the decision: prior status, and prior metadata verbatim. The
-- -- resolution columns are deliberately absent from this statement -- see the
-- -- DOWN banner. For the approved target this is what puts the decision back
-- -- to `resolved`, with `choice`, `decider`, `rationale`, `signatureJson`,
-- -- `resolvedOptionId` and `timestamp` untouched exactly where the operator left
-- -- them.
-- UPDATE human_decision d
--    SET "status" = COALESCE(x."guardEvaluationsJson"::jsonb ->> 'priorDecisionStatus', 'pending'),
--        -- `->>` yields NULL for both an absent key and an explicit JSON null,
--        -- and a decision that arrived with no metadata at all must come back
--        -- with none. That is the same answer, so no CASE is needed here.
--        "metadataJson" = x."guardEvaluationsJson"::jsonb ->> 'priorDecisionMetadataJson',
--        "updatedAt" = now()
--   FROM "work_item_transition" x
--  WHERE x."transitionId" = 'tr-unreviewed-review-repair-' || d."workItemId"
--    AND x."idempotencyKey" = 'unreviewed-review-repair:void-fabricated-verdict'
--    AND d."decisionId" = x."guardEvaluationsJson"::jsonb ->> 'decisionId'
--    AND d."status" = 'cancelled';
--
-- -- 3. Only now drop this migration's audit rows, so the restores above had rows
-- -- to key off. Deterministic ids: this matches exactly what this migration
-- -- created and can never reach a row the engine wrote.
-- DELETE FROM "work_item_transition"
--  WHERE "transitionId" LIKE 'tr-unreviewed-review-repair-%';
--
-- -- 4. Migration version rollback for control_plane.
-- DELETE FROM "serverpod_migrations"
--  WHERE "module" = 'control_plane' AND "version" = '20261014210000000';
--
-- COMMIT;
-- -- DOWN SCRIPT END


-- COMMIT;


COMMIT;
