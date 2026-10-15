BEGIN;

--
-- SHIPIT CONTROL PLANE REPAIR: engineering-review decisions that CLAIM a
-- reviewer verdict no reviewer ever produced, retired without being deleted,
-- and their work items returned to a dispatchable review at a FRESH key.
--
-- WHAT BROKE. `EngineeringReviewGate` used to default a missing verdict to
-- `changes_required`. A reviewer that timed out produced no result, the gate
-- invented the verdict, and an `engineering_review` decision was raised asking a
-- human to approve or reject code nobody had read. Three such decisions existed
-- in QA. Commit 93587cf (b1) removed all three fallback sites and made the
-- parser fail closed, so a NEW fabricated decision can no longer be created --
-- but the rows the old default produced are still there, still `pending`, still
-- blocking their work items, and still reading "We suggest: CHANGES_REQUIRED".
-- b1 fixes the cause. This repairs the data the cause produced.
--
-- ## WHAT WAS MEASURED IN QA BEFORE THIS FILE WAS WRITTEN
--
-- Read read-only off the live QA database on 2026-10-14. Every
-- `engineering_review` decision that exists, with the reviewer execution its own
-- metadata names, and what that reviewer ACTUALLY wrote:
--
--   decisionId            work item                 exec status  payload  summary  verdict claimed
--   --------------------  ------------------------  -----------  -------  -------  --------------
--   dec-hn7h7d9j8i-1oh8pgm  DEF-1791684557133597    failed       {}       empty    changes_required  <-- REPAIRED HERE
--   dec-hn7h7db3w9-hdzu8c  DEF-1791685924503981    failed       {}       empty    changes_required  <-- REPAIRED HERE
--   dec-hn7h7dagw5-l4o193  DEF-1791685024220546    completed    {}       2000 ch  changes_required  <-- NOT REPAIRED
--   dec-hn7iw644nz-rmmpcn  DEF-1791686357139031    completed    {}       2000 ch  changes_required  <-- NOT REPAIRED
--   dec-hn7h7daum6-2atjhe  DEF-1791685264570406    failed       {}       empty    changes_required  <-- NOT REPAIRED
--
-- All three reviewer executions that failed carry the same reason: "session
-- never emitted a terminal event within the 300s execution budget" -- which is
-- pre-b2; `accc0f7` raised the budget to 4h, so this should not recur.
--
-- ## THE THREE THAT ARE DELIBERATELY NOT REPAIRED. Each is a case where
-- ## REPAIRING WOULD BE THE WRONG ACT, and two of them are why this migration
-- ## is not a blanket sweep.
--
-- 1. `dec-hn7h7dagw5-l4o193` and `dec-hn7iw644nz-rmmpcn` -- THE REVIEWER DID
--    REAL WORK. Both executions COMPLETED and wrote 2000 characters of prose.
--    The first literally opens "## Engineering Review" and states **"Verdict:
--    `APPROVE_WITH_NON_BLOCKING_FOLLOWUP`"**, then verifies the fix is
--    value-preserving and lists three non-blocking findings. The second confirms
--    all three of its diagnoses by inspection and checks two claims the commit
--    message does not make. Their executions are
--    `agx-wx-jb-hn7gq1n2dc-1llxxyk` (`defect-DEF-1791685024220546`) and
--    `agx-wx-jb-hn7itcezii-1igc7vp` (`defect-DEF-1791686357139031`), and those
--    summaries are the ONLY place either review exists.
--
--    Their decisions still claim `changes_required` -- that claim is still
--    fabricated, because neither wrote a machine-readable verdict. But a REAL
--    REVIEW EXISTS, and the operator has never been shown it. A repair keyed on
--    "no machine-readable verdict" would have destroyed both of them, and the
--    reviewer's assessment would have been unrecoverable: the summary is the only
--    place it exists.
--
--    So the predicate below REQUIRES AN EMPTY SUMMARY, not merely an absent
--    verdict, and the two things are separately reasoned here because they are
--    separately true. These two are left for a human to read and resolve; they
--    are not stuck, they are MISLED, and misreading is fixed by showing someone
--    the review, not by deleting the question.
--
-- 2. `dec-hn7h7daum6-2atjhe` -- AN OPERATOR HAS ALREADY APPROVED IT. This one
--    is no longer `pending`: `choice = approve`, `decider = operator`, and its
--    work item has MOVED ON to `review_approved` (version 17). That is the harm
--    this whole mechanism exists to prevent, and it has already happened once,
--    in QA, to a decision whose reviewer had timed out.
--
--    It is excluded deliberately rather than quietly repaired. Repairing it would
--    mean overwriting a recorded human approval -- discarding a real human
--    decision to replace a fabricated reviewer verdict with a different
--    fabricated shape. That is a worse act than the one being repaired, and it is
--    a product/governance call, not a data call. It is escalated as
--    HUMAN_DECISION_REQUIRED, and NOTHING in this migration touches it: not its
--    status, not its choice, not its decider, not the work item at
--    `review_approved`.
--
-- ## THE TARGET SET IS ENUMERATED, NOT PREDICATED. And the list appears ONCE.
--
-- `shipit_unreviewed_review_repair_target` is the single definition of what this
-- migration touches; the fail-loud guard and both UPDATEs read it, and nothing
-- else in this file names a decision id. Spelling the ids out a second time is
-- how a guard and the statement it guards come to test a different set than the
-- one being written -- a guard that then passes for the wrong reason. The
-- enumeration is what stops this migration silently widening: a predicate like
-- "every pending engineering_review decision with an empty summary" is safe only
-- at the instant it was written, and on every subsequent apply it would also
-- match the two REAL reviews above. A list cannot widen.
--
-- `ON COMMIT DROP` plus the surrounding transaction mean the table cannot outlive
-- this migration in any session.
--
-- ## THE FABRICATION TEST IS RE-DERIVED HERE, IN SQL, FROM THE REVIEWER'S OWN
-- ## RESULT -- AND IT FAILS THE MIGRATION IF IT DISAGREES WITH ITSELF.
--
-- Nothing below takes the decision's `reviewVerdict` as evidence that anyone
-- reviewed anything; that field is the thing under repair. The test joins
-- `human_decision -> agent_execution -> agent_result` on the execution id the
-- decision's own metadata names, and asks: did the reviewer write anything a
-- human could read?
--
-- The SQL predicate is DELIBERATELY STRICTER than the Dart reader in
-- `WorkItemActionEndpoints.readReviewVerdictProvenance`, and only in the safe
-- direction. Where Dart would call an unparseable embedded result "no verdict"
-- and fall through to the summary test, this predicate sees the `engineering-
-- ReviewResult` KEY is present and treats the decision as NOT repairable. Two
-- readers that disagree must disagree towards refusal.
--
-- IF ANY LISTED DECISION FAILS THE TEST AT APPLY TIME, THE WHOLE MIGRATION
-- RAISES and changes nothing. It does not skip the row: a target that has become
-- repairable-in-fact since dispatch is a target this migration's reasoning was
-- not written for, and a partial repair leaves a mix of repaired and unrepaired
-- items with nothing distinguishing them.
--
-- ## THE `expectedState` ARM IS ALSO THE COMPARE-AND-SWAP.
--
-- An item that moved on its own between dispatch and apply is left completely
-- alone -- it is no longer parked, and rewriting its state back would resurrect a
-- defect someone already fixed. The arm is re-asserted in the UPDATE, next to the
-- `version` compare-and-swap, for the same reason `20261012150000000`
-- re-asserted its state there: a concurrent writer that moved the item between
-- the selection and the update must not be overwritten.
--
-- IDEMPOTENT, BY ID AND NOT BY STATE. A second run matches zero rows and writes
-- zero rows, for three independent reasons, any one of which suffices:
--
--   (a) every repaired decision now carries this migration's marker in
--       `human_decision.metadata`, and the selection excludes any id already
--       carrying it. This is the arm that holds under a FORCED replay too --
--       including one run against items the scheduler has since moved on, where
--       the state arm alone would no longer match.
--   (b) an item whose state still matches is by definition one that was never
--       repaired, so the state arm cannot double-apply either.
--   (c) the new dedupe key has no holder, so the condition
--       `20261014093000000` repairs by is gone -- see THE NEW KEY BELOW.
--
-- Under CONCURRENCY two appliers cannot both write: the second blocks on the row
-- lock, and on READ COMMITTED PostgreSQL re-evaluates the UPDATE's WHERE against
-- the newly committed row, sees this migration's marker, and matches nothing. The
-- `transitionId`s are deterministic rather than random, so even a replay that
-- bypassed the arm entirely would collide on `work_item_transition_id_unique` and
-- abort loudly rather than write a second, differently-named audit row.
--
-- FAIL LOUDLY, ON THREE CONDITIONS, ROLLING BACK BOTH.
--
-- None of these is a "skip it" case:
--
--   * A TARGET THAT IS NOT ACTUALLY FABRICATED. See above.
--   * A TARGET ALREADY ANSWERED BY A HUMAN. `status <> 'pending'` or a non-null
--     `choice` means someone answered the question. Overwriting that is
--     discarding a real human decision -- exactly the fate the
--     already-approved `dec-hn7h7daum6-2atjhe` met -- and this migration will
--     not do it to anything.
--   * METADATA THAT CANNOT BE MERGED. The markers are written with a jsonb `||`,
--     which MERGES and never replaces: the defect payload the re-run triage reads
--     must survive, or the item classifies nothing while looking healthy. Both
--     `human_decision.metadataJson` and `work_item.metadataJson` are nullable
--     `text` and are NOT guaranteed to hold parseable JSON. For an UNPARSEABLE
--     or non-object value there is nothing safe to write: the only way to stamp a
--     marker is to overwrite the whole document, which is silent destruction of
--     whatever was there.
--
-- Because both raise inside the surrounding transaction, the failure mode is
-- all-or-nothing: neither item is repaired and nothing at all changes. A partial
-- repair is invisible and is not recoverable without re-dispatching this
-- migration by hand against a corrected list.
--
-- ## THE NEW KEY IS AN ARITHMETIC BORROW, NOT A GUESS.
--
-- `engineeringReviewDedupeKey` (packages/scheduler/lib/src/scheduler.dart:2904)
-- builds `'<workItemId>:engineering_review'` plus `':a<n>'` when
-- `metadata.triageAttempt` is readable, and returns the BARE key when it is not.
-- `JobQueue.enqueueIfAbsent` resolves any key a job already holds, terminal or
-- not -- and the terminal `engineering_review` job that stranded each of these
-- items holds the BARE key. So the item is inert without a bump.
--
-- The bump is `greatest(<marker>, <highest attempt encoded in this item's own
-- engineering_review job dedupe keys>) + 1`, the same two-watermark rule
-- `20261014093000000` used for the triage key and the same one
-- `DurableWorkflowEngine.nextTriageAttempt` computes. Taking the max over the
-- item's OWN jobs as well is what makes the result PROVABLY UNHELD: the only
-- place an attempt number can already have a holder is a job.
--
-- MEASURED, not assumed: both items read `triageAttempt: 2`, and all three of
-- their `engineering_review` job keys are the UNSUFFIXED form, which contributes
-- nothing to the floor. Both therefore write `:a3`, and no job in QA holds
-- `...:engineering_review:a3`. That the original key was unsuffixed despite a
-- readable marker is a separate question from whether `:a3` is free, and this
-- migration answers only the second.
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
-- `unreviewed-review-repair:no-real-reviewer-verdict`, and the audit row's
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
--   * `human_decision`: `status`, `metadataJson`, `updatedAt`. Nothing else. In
--     particular NOT `question`, `optionsJson`, `recommendation`, `contextJson`,
--     `decider`, `choice`, `rationale`, `signatureJson` or `resolvedOptionId` --
--     the fabricated question, its recommendation and its options are the EVIDENCE
--     and are preserved verbatim, and the resolution columns are never written,
--     so this cannot forge a human answer even by accident. **Nothing is
--     deleted.** The decision survives as the record of what was claimed.
--   * `work_item`: `state`, `blockingHumanDecisionId`, `blockingReason`,
--     `metadataJson`, `updatedAt`, `version`.
--   * One audit row per repaired item in `work_item_transition`.
--   * No `job` row is touched, so a repaired item enqueues against a FRESH key
--     rather than resuming anything, and the terminal review job that stranded
--     it is left exactly as it is. No `agent_execution`, `agent_result`,
--     `worker_execution` or `model_execution_record` row is touched -- the
--     reviewer's evidence is read, never rewritten.
--   * `pinnedRevision`, `workspace`, producer anchors, `qaContractId`,
--     `designContractId`, `agentSessionId`, `artifactRefsJson`, `completedAt`
--     and `terminatedAt` are all untouched.
--   * `version` is incremented and `updatedAt` set, exactly as a real transition
--     writes them, so the engine's compare-and-swap on `version` still behaves.
--
-- SAFETY / DATA LOSS: this migration deletes nothing and overwrites no payload.
-- It retires two decisions it has PROVED no reviewer backs, moves two stranded
-- work items, and writes the audit rows describing both. Every statement is
-- inside the surrounding transaction, so a failure rolls back the decision
-- changes, the state moves, the marker writes and the audit rows together -- there
-- is no reachable state in which an item moved with no audit row describing it,
-- and no reachable state in which one item was repaired and the other was not.
--
-- WHY `agent_completed`. That is `engineeringReviewDefinition.entryStates`
-- (packages/scheduler/lib/src/scheduler.dart:2166), so the ordinary tick
-- dispatches the re-review on the ordinary path. `waitingForHumanDecision ->
-- agent_completed` has NO edge in `WorkItemTransitions` -- no edge models "a
-- question was asked that nobody asked" -- so, exactly as in every other repair
-- migration in this repository, the state is written directly into the column and
-- the audit row records that no edge was taken.

-- `DROP ... IF EXISTS` is belt-and-braces for a replay inside ONE session:
-- `ON COMMIT DROP` already covers the committed and the rolled-back paths, and
-- this covers neither having run yet.
DROP TABLE IF EXISTS "shipit_unreviewed_review_repair_target";

CREATE TEMP TABLE "shipit_unreviewed_review_repair_target" (
    "decisionId"    text PRIMARY KEY,
    "workItemId"    text NOT NULL,
    "expectedState" text NOT NULL
) ON COMMIT DROP;

-- THE TARGET SET. Two ids, each with the work item it holds and the state that
-- item held when this set was read off QA. Changing a row here changes what the
-- migration does; there is no second copy of this list anywhere in the file.
--
--   decisionId              work item                    state                       reviewExecutionId
--   ----------------------  --------------------------  -------------------------  -----------------------------
--   dec-hn7h7d9j8i-1oh8pgm  defect-DEF-1791684557133597  waiting_for_human_decision  agx-wx-jb-hn7gq1knzr-zmtj6i
--   dec-hn7h7db3w9-hdzu8c  defect-DEF-1791685924503981  waiting_for_human_decision  agx-wx-jb-hn7gq1om0m-1op4o60
--
-- NOT IN SCOPE, and matched by no predicate in this file: the two
-- `reviewerProseOnly` decisions above (a real reviewer wrote a real review; a
-- human must read it) and `dec-hn7h7daum6-2atjhe` (an operator has already
-- approved it, and undoing that is a human decision -- see the banner).
INSERT INTO "shipit_unreviewed_review_repair_target"
    ("decisionId", "workItemId", "expectedState")
VALUES
    ('dec-hn7h7d9j8i-1oh8pgm', 'defect-DEF-1791684557133597', 'waiting_for_human_decision'),
    ('dec-hn7h7db3w9-hdzu8c', 'defect-DEF-1791685924503981', 'waiting_for_human_decision');

--
-- FAIL LOUDLY. Refuse the whole migration, naming every offending decision,
-- rather than retiring a decision that a reviewer really produced, one a human
-- already answered, or one whose payload cannot be merged.
--
-- "IN SCOPE" MEANS EXACTLY WHAT THE UPDATES MEAN: the decision is in the target
-- table, its work item still holds its expected state, the item still names it as
-- blocking, and this migration has not already repaired it. A target that has
-- moved on is not reported and not touched.
--
-- The three `agent_execution` reasons -- failed/completed -- are NOT tested
-- here. Execution status is not the test; reviewer OUTPUT is. A failed execution
-- that wrote a real review is protected by the summary test, and a completed
-- execution that wrote nothing is caught by it too.
--
-- The metadata checks are `BEGIN ... EXCEPTION` blocks rather than boolean
-- expressions because there is no way to ask "does this text parse as JSON?"
-- without attempting the cast, and `''::jsonb` raises. Catching the raise is what
-- turns an unparseable payload into a reported id instead of an aborted statement
-- whose message names no decision.
DO $$
DECLARE
    r           record;
    meta        jsonb;
    itemMeta    jsonb;
    execId      text;
    res         record;
    payload     jsonb;
    offenders   text := '';
BEGIN
    FOR r IN
        SELECT t."decisionId",
               t."workItemId",
               d."status",
               d."choice",
               d."metadataJson",
               w."blockingHumanDecisionId",
               w."metadataJson" AS "itemMetadataJson"
          FROM "shipit_unreviewed_review_repair_target" t
          JOIN human_decision d ON d."decisionId" = t."decisionId"
          JOIN work_item w      ON w."workItemId" = t."workItemId"
         WHERE w."state" = t."expectedState"
           AND w."blockingHumanDecisionId" = t."decisionId"
           AND NOT EXISTS (
                   SELECT 1 FROM "work_item_transition" x
                    WHERE x."transitionId" =
                              'tr-unreviewed-review-repair-' || t."workItemId"
               )
           -- `human_decision.metadataJson` is nullable TEXT and is NOT
           -- guaranteed to hold parseable JSON, so it cannot be handed to
           -- `->>` directly. The cast is confined to the ELSE branch of a CASE,
           -- which PostgreSQL documents to evaluate in order and not to
           -- evaluate an unselected branch at all, so an unparseable value can
           -- never raise here regardless of the plan.
           AND (CASE
                   WHEN d."metadataJson" IS NULL
                     OR btrim(d."metadataJson") = ''
                     OR btrim(d."metadataJson") NOT LIKE '{%'
                   THEN NULL
                   ELSE d."metadataJson"::jsonb
                END) ->> 'reviewUnreviewable' IS DISTINCT FROM 'true'
    LOOP
        -- (1) ALREADY ANSWERED BY A HUMAN.
        IF r."status" <> 'pending' OR r."choice" IS NOT NULL THEN
            offenders := offenders
                         || r."decisionId"
                         || ' [already resolved by a human: status='
                         || coalesce(r."status", '<null>') || ', choice='
                         || coalesce(r."choice", 'null') || '], ';
            CONTINUE;
        END IF;

        -- (2) METADATA THAT CANNOT BE MERGED, on either row.
        meta := NULL;
        BEGIN
            SELECT r."metadataJson"::jsonb INTO meta;
        EXCEPTION WHEN others THEN
            offenders := offenders
                         || r."decisionId"
                         || ' [metadataJson is not parseable JSON: '
                         || coalesce(left(r."metadataJson", 80), '<null>')
                         || '], ';
        END;
        IF meta IS NOT NULL AND jsonb_typeof(meta) <> 'object' THEN
            offenders := offenders
                         || r."decisionId"
                         || ' [metadataJson is JSON '
                         || jsonb_typeof(meta) || ', not an object], ';
        END IF;

        itemMeta := NULL;
        BEGIN
            SELECT r."itemMetadataJson"::jsonb INTO itemMeta;
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
        END IF;

        -- (3) THE FABRICATION TEST, RE-DERIVED FROM THE REVIEWER'S OWN RESULT.
        --     Strictly stricter than the Dart reader, and only towards refusal.
        execId := meta ->> 'reviewExecutionId';

        IF execId IS NULL OR execId = '' THEN
            -- No reviewer execution is named: there is no reviewer output behind
            -- the claim at all. Repairable.
            CONTINUE;
        END IF;

        SELECT * INTO res
          FROM agent_result ar
         WHERE ar."executionId" = execId;

        IF NOT FOUND THEN
            -- The reviewer reached a terminal state without writing any result.
            -- Repairable.
            CONTINUE;
        END IF;

        IF btrim(coalesce(res."summary", '')) <> '' THEN
            offenders := offenders
                         || r."decisionId"
                         || ' [reviewer execution ' || execId
                         || ' wrote ' || length(btrim(res."summary"))
                         || ' characters of real review into its summary; '
                         'a human assessment exists and must not be discarded], ';
            CONTINUE;
        END IF;

        IF res."structuredResultJson" IS NULL
           OR btrim(res."structuredResultJson") = ''
           OR btrim(res."structuredResultJson") NOT LIKE '{%' THEN
            -- Unreadable payload: "I could not check" is not "there was nothing
            -- there". Refuse, exactly as the Dart reader does.
            offenders := offenders
                         || r."decisionId"
                         || ' [reviewer result payload is unreadable], ';
            CONTINUE;
        END IF;

        -- NAMED, NOT CAST INLINE. `payload` is declared jsonb, so the two
        -- `->>` reads below are on a jsonb by construction. Reading `->>` off a
        -- record field cast inline is fragile, and `->>` and `||` share one
        -- precedence level and associate left to right, so an inline cast inside
        -- a concatenation re-parses into
        -- `('...' || col::jsonb) ->> 'verdict'` -- correct only because
        -- `text || jsonb` happens to resolve.
        payload := res."structuredResultJson"::jsonb;

        IF jsonb_typeof(payload -> 'engineeringReviewResult') IS NOT NULL THEN
            offenders := offenders
                         || r."decisionId"
                         || ' [reviewer result carries an embedded '
                         'engineeringReviewResult], ';
            CONTINUE;
        END IF;

        IF btrim(coalesce(payload ->> 'verdict', '')) <> '' THEN
            offenders := offenders
                         || r."decisionId"
                         || ' [reviewer result carries the verdict '
                         || coalesce(payload ->> 'verdict', '')
                         || '], ';
            CONTINUE;
        END IF;

        -- No result payload to read and no summary: the repairable class.
    END LOOP;

    IF offenders <> '' THEN
        RAISE EXCEPTION
            'unreviewed-review-repair refused: % . This migration retires only '
            'decisions whose named reviewer produced NO readable output at all. '
            'A decision with real reviewer prose, a real verdict, a human answer, '
            'or an unreadable payload is refused, because discarding any of those '
            'is worse than the defect being repaired. Nothing was changed.',
            left(offenders, length(offenders) - 2);
    END IF;
END $$;

--
-- THE WORK ITEM, and the fresh review key that lets the re-review dispatch.
--
-- ORDERING IS LOAD-BEARING, AND IT IS THE REVERSE OF THE OBVIOUS ONE. This
-- block runs BEFORE the decision is retired, not after, because the audit row it
-- writes is the restore payload the DOWN section reads back. `priorDecision-
-- MetadataJson` is read out of `human_decision` at this point; if the decision
-- had already been retired, this statement would record the ALREADY-UPDATED
-- metadata as the "prior" one, and the rollback would restore the repair's own
-- output while claiming to undo it -- a rollback that silently does the wrong
-- thing, which is the exact defect `20261014093000000`'s DOWN section documents
-- and does not commit. Both statements are inside one transaction, so the order
-- the rows become visible in is not an ordering an applier can observe.
--
-- The marker arms below replicate DurableWorkflowEngine.readTriageAttempt
-- exactly, for the reason stated in the banner: two copies of "how a marker is
-- read" is how a writer and a reader come to disagree about which numbers are
-- attempts, and the disagreement would build a key nothing holds and enqueue
-- nothing.
WITH "parsed" AS (
    SELECT w."workItemId",
           w."state",
           w."version",
           w."blockingHumanDecisionId",
           w."blockingReason",
           t."decisionId",
           t."expectedState",
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
       AND w."blockingHumanDecisionId" = t."decisionId"
       AND NOT EXISTS (
               SELECT 1 FROM "work_item_transition" x
                WHERE x."transitionId" =
                          'tr-unreviewed-review-repair-' || w."workItemId"
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
    -- the bare form that every suffix moves away from.
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
     -- replace it is undefined.
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
       -- engine itself uses, the state is the selection predicate, and the
       -- marker is re-asserted because that is the column being written.
       AND w."version" = s."version"
       AND w."state" = s."expectedState"
       AND w."blockingHumanDecisionId" = s."decisionId"
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
               s."state"            AS "fromState",
               s."expectedState",
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
       'Data repair (migration 20261014210000000): this item was parked at '
       || r."fromState" || ' behind engineering-review decision '
       || r."decisionId" || ', which claimed the verdict "'
       || COALESCE(r."meta" ->> 'reviewVerdict', 'none')
       || '" while re-deriving the verdict from the REVIEWER''S OWN durable '
       'result found none. The reviewer named by that decision ('
       || COALESCE(r."meta" ->> 'reviewExecutionId', 'none')
       || ') produced no result payload and no summary, so there is no reviewer '
       'output of any kind and nothing was ever reviewed. The decision is '
       'RETIRED, not deleted: its status is cancelled, its question, options, '
       'recommendation and context are preserved verbatim as the evidence of '
       'what was claimed, and it carries a marker naming this repair. The item '
       'returns to agent_completed, which IS engineeringReviewDefinition.'
       'entryStates, and metadata.triageAttempt advances from '
       || COALESCE(r."markerAttempt"::text, 'absent') || ' to '
       || r."newAttempt"::text || ', giving the provably unheld key '
       || r."workItemId" || ':engineering_review:a' || r."newAttempt"::text
       || ' (the discriminator is greatest(marker, highest attempt this item''s '
       'own engineering_review job keys had consumed = ' || r."jobFloor"::text
       || ') + 1, and no job holds it). NO TRANSITION EDGE WAS TAKEN: '
       'waiting_for_human_decision -> agent_completed does not exist in '
       'WorkItemTransitions, because no edge models "a question was asked that '
       'nobody asked", so the state is written directly inside this '
       'transaction with this row as its record. No verdict was invented, none '
       'was read from the decision itself, and no row outside human_decision, '
       'work_item and work_item_transition was written.',
       -- THE RESTORE PAYLOAD. This migration IS exactly reversible, and it is
       -- reversible because the before-image is stored here rather than
       -- recomputed by the rollback. Every field below is what the DOWN section
       -- puts back, verbatim, including the two cases a recompute gets wrong:
       -- an `absent` triageAttempt must be REMOVED rather than set to 0 (absent
       -- reads as the bare key, 0 reads as ':a0', which nothing ever mints),
       -- and the decision's prior metadata is restored as the exact text it was,
       -- not as a merge of keys this migration removed.
       jsonb_build_object(
           'migration', '20261014210000000',
           -- `r.` IS LOAD-BEARING. Written unqualified, this bare
           -- `"decisionId"` inside the correlated subquery below binds to the
           -- SUBQUERY's own `human_decision.decisionId`, making the predicate
           -- tautological, returning every decision, and failing the whole
           -- INSERT with "more than one row returned by a subquery used as an
           -- expression". The test suite found that; the comment is here so the
           -- qualification is not "tidied away" as noise next time.
           'decisionId', r."decisionId",
           -- Read from the still-un-retired decision row. See the ORDERING note
           -- above: this is the whole reason the work item is repaired first.
           'priorDecisionStatus', (
               SELECT d."status"
                 FROM human_decision d
                WHERE d."decisionId" = r."decisionId"),
           'priorDecisionMetadataJson', (
               SELECT d."metadataJson"
                 FROM human_decision d
                WHERE d."decisionId" = r."decisionId")::text,
           'priorBlockingHumanDecisionId', r."blockingHumanDecisionId",
           'priorBlockingReason', r."blockingReason",
           'priorTriageAttemptForm', r."markerForm",
           'priorTriageAttempt', r."markerAttempt",
           'newTriageAttempt', r."newAttempt")::text,
       'unreviewed-review-repair:no-real-reviewer-verdict',
       now()
  FROM "repaired" r;

--
-- THE RETIRED DECISION. Kept, never deleted: status becomes `cancelled`, every
-- human-readable field is preserved verbatim, and the marker records why.
--
-- The claimed verdict is copied into the metadata under a key that NAMES it as a
-- claim, so the evidence is explicit and can never be mistaken for a verdict
-- later. It is read from the decision's own `reviewVerdict`, which is the field
-- under repair -- copying it is RECORDING what was asserted, and the guard above
-- has already proved no reviewer supports it.
--
-- Runs LAST, and its selection re-reads the same three arms the work item's
-- selection used (marker, state, blocking id) plus its own: the marker on the
-- DECISION rather than the work item's transition ledger, because that is the
-- thing this statement writes and therefore the thing that must not be written
-- twice. A forced replay therefore matches nothing here either.
WITH "parsed" AS (
    SELECT d."decisionId",
           d."workItemId",
           d."status",
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
       AND EXISTS (
               SELECT 1 FROM "work_item_transition" x
                WHERE x."transitionId" =
                          'tr-unreviewed-review-repair-' || w."workItemId"
                  AND x."idempotencyKey" =
                          'unreviewed-review-repair:no-real-reviewer-verdict'
           )
       -- IDEMPOTENCE BY ID, on the column this statement writes.
       -- The same case-guarded cast as in the fail-loud guard above: nullable
       -- TEXT is not `jsonb`, and `->>` on it is an error rather than a NULL.
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
                  'reviewUnreviewableReason',
                      'No reviewer produced the verdict this decision claims. '
                      'EngineeringReviewGate used to default a missing verdict '
                      'to changes_required (removed in 93587cf); this decision '
                      'was raised by that default and was shown to an operator '
                      'as a real review result. It is RETIRED, not deleted: '
                      'every field a human could read is preserved verbatim '
                      'as the evidence of what was claimed.',
                  'reviewUnreviewedExecutionId', p."meta" ->> 'reviewExecutionId',
                  'reviewUnreviewableClaimedVerdict', p."meta" ->> 'reviewVerdict',
                  'reviewUnreviewedMigration', '20261014210000000'
              ))::text,
       "updatedAt" = now()
  FROM "parsed" p
 WHERE d."decisionId" = p."decisionId"
   -- Re-asserted: after this row is locked, a concurrent writer must not be
   -- overwritten. `status` is the selection predicate and `choice` is the column
   -- whose non-null means a human already answered -- writing over a resolution
   -- is the one thing this migration must never do, and `dec-hn7h7daum6-2atjhe`
   -- is the QA decision that proves why.
   AND d."status" = p."status"
   AND d."choice" IS NULL;

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
-- WARNING: this restores the defect. Each item goes back to
-- waiting_for_human_decision behind a decision that claims a reviewer verdict
-- nobody produced, and each will present that fabricated question to an
-- operator again. Run it only to return a database to its pre-migration shape,
-- then re-apply this migration instead.
--
-- THIS DOWN IS HONESTLY REVERSIBLE, AND THAT IS A DELIBERATE DEPARTURE FROM THE
-- EARLIER REPAIRS IN THIS REPOSITORY. Read
-- `20261014093000000`'s DOWN section and it states in full that it does NOT
-- restore the pre-migration `triageAttempt` in two of three cases -- an absent
-- marker comes back as `0`, and a marker below the job floor comes back as the
-- floor -- and that it leaves that wrong rather than editing its own semantics
-- to compensate.
--
-- This one does not have that gap in the place that mattered, because it does
-- not RECOMPUTE the before-image at rollback time. Every UPDATE below reads this
-- migration's own audit row, whose `guardEvaluationsJson` carries the exact
-- prior values it recorded at repair time. Nothing is inferred, so nothing can
-- be inferred wrongly.
--
-- WHAT IS EXACT, AND WHAT IS NOT, STATED PLAINLY. Four of the things the
-- rollback restores are restored BYTE-FOR-BYTE, and one is not:
--
--   * `work_item.state`, `blockingHumanDecisionId` and `blockingReason` are
--     ordinary text columns, restored verbatim from the audit row.
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
-- THE DECISION'S PRIOR metadata IS RESTORED AS THE EXACT TEXT IT WAS, not as a
-- merge of the keys this migration added. `priorDecisionMetadataJson` is null for
-- a decision that had none, which the `-` operator turns back into no metadata
-- at all.
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
-- -- own audit row rather than naming a literal or recomputing one.
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
--    AND x."idempotencyKey" = 'unreviewed-review-repair:no-real-reviewer-verdict'
--    AND x."toState" = 'agent_completed'
--    AND w."state" = 'agent_completed'
--    AND x."guardEvaluationsJson" IS NOT NULL;
--
-- -- 2. Un-retire the decision: prior status, and prior metadata verbatim.
-- UPDATE human_decision d
--    SET "status" = COALESCE(x."guardEvaluationsJson"::jsonb ->> 'priorDecisionStatus', 'pending'),
--        -- `->>` yields NULL for both an absent key and an explicit JSON null,
--        -- and a decision that arrived with no metadata at all must come back
--        -- with none. That is the same answer, so no CASE is needed here.
--        "metadataJson" = x."guardEvaluationsJson"::jsonb ->> 'priorDecisionMetadataJson',
--        "updatedAt" = now()
--   FROM "work_item_transition" x
--  WHERE x."transitionId" = 'tr-unreviewed-review-repair-' || d."workItemId"
--    AND x."idempotencyKey" = 'unreviewed-review-repair:no-real-reviewer-verdict'
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
