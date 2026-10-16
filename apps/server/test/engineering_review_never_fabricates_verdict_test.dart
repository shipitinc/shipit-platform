import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';
import 'package:workflow_store/workflow_store.dart';

import 'package:control_plane_server/src/review/engineering_review_gate.dart';

/// ## WHAT THIS FILE EXISTS TO PROVE
///
/// **No decision ever asserts a verdict that was not parsed.**
///
/// That is the invariant as it stands after decision
/// `c495e02f-5c5d-4b45-8124-42ad0e90d6d4` (ARCHITECTURE, RESOLVED, option A).
/// It replaced a deliberately stricter one — *"a reviewer that produced no
/// verdict must never become a human decision"* — which is quoted, with its
/// reason and its decision id, at each site it was amended and in the file
/// header below this one. Read that before changing anything here.
///
/// Three work items sat at `waitingForHumanDecision` on 2026-10-14 reading
/// *"Engineering review requires changes. Approve, reject, or request rework?"*
/// with *"WHAT WE SUGGEST: CHANGES_REQUIRED"* and an empty context — for code no
/// reviewer had assessed. Their reviewers had failed:
/// three at exactly 300s ("session never emitted a terminal event within the
/// 300s execution budget"), two completing on `end_turn` with `{}` in
/// `structuredResultJson` and ~2000 bytes of markdown in `summary`.
///
/// Three separate lines in `engineering_review_gate.dart` collapsed "we have no
/// verdict" into `ReviewVerdict.changesRequired`:
///  * the wire default assigned **before any result had been read**;
///  * the `fromWire` catch-all, which turned an **unreadable** string into a
///    verdict and read like an ordinary parse fallback;
///  * the "no reviewer result at all" branch, which built a result object with
///    `findings: const []`.
///
/// Each site has a test below that fails if that line comes back, and each test
/// was run against the restored original line to prove it is not vacuous (see
/// the NON-VACUITY blocks).
///
/// ## WHAT "RETRYABLE" IS ASSERTED TO MEAN HERE
///
/// `reviewInProgress`, with no `blockingHumanDecisionId`. Not "left alone" in the
/// abstract: a decision is the item's only one-way exit out of review, so the
/// absence of one is the assertion that the retry path still exists. The gate
/// does not create, reset or duplicate a retry — the reviewer job's own bounded
/// `maxAttempts` is the mechanism, and `a reviewer job whose budget is untouched
/// by a no-verdict gate` asserts that contract holds.
///
/// ## AMENDED 2026-10-15 — READ THIS BEFORE RESTORING EITHER ZERO-ROW ASSERTION
///
/// Two tests in this file asserted **zero** `HumanDecision` rows for absences
/// that decision `c495e02f-5c5d-4b45-8124-42ad0e90d6d4` (ARCHITECTURE, RESOLVED,
/// option A) has since made operator-actionable. They are AMENDED, not deleted,
/// and each carries its reason inline. The three sibling tests that were NOT
/// amended — `SITE 3: no reviewer result at all raises NOTHING`,
/// `a no-verdict gate leaves the reviewer job's bounded budget untouched` and
/// `the item is left RETRYABLE: reviewInProgress, no blocking decision` — still
/// assert zero rows, byte-identical, because a review that did not finish still
/// has `maxAttempts` owed to it.
///
/// | | before | after |
/// |---|---|---|
/// | invariant | "**a reviewer that produced no verdict must never become a human decision**" | "**no decision asserts a verdict that was not parsed**" |
/// | strength | also forbade a decision that says *no verdict was produced* | permits exactly that one decision, and only that one |
/// | why | "no decision exists without a parsed verdict" | a decision that STATES THE ABSENCE preserves the property that protects the reader, and closes a silent park: four reviews completed against real commits on 2026-10-15, produced real findings in prose, recorded `{}`, and left four work items at `reviewIn_progress` with nothing on any operator screen. The job SUCCEEDED, so `maxAttempts` never retried it |
/// | decided by | `93587cf` (b1) | `c495e02f-5c5d-4b45-8124-42ad0e90d6d4`, option A, RESOLVED by `operator` |
///
/// **What is load-bearing in BOTH versions and is still asserted below:** a
/// decision that carries an `UNPARSED` verdict — `'CHANGES_REQUIRED'`,
/// `'changesRequired'`, `'needs_work'`, `'changes_required '` — is still refused,
/// and still records `verdict_unreadable` as its cause. That is the invariant
/// that actually stops a reviewer being reported as having found problems when
/// it did not, and the amendment does not touch it.
///
/// If you are here to restore a zero-row assertion, read
/// `apps/server/lib/src/review/engineering_review_gate.dart` § WHY THERE IS NO
/// "NO VERDICT" MEMBER OF `ReviewVerdict` and the decision file first.
void main() {
  group('no verdict means no decision — the three fabrication sites', () {
    test(
      'SITE 1: a reviewer result carrying no verdict raises a decision that '
      'asserts NO verdict',
      () async {
        // The live case, verbatim: `end_turn` at 131s/160s, 2000 bytes of
        // markdown in `summary`, `{}` in `structuredResultJson`.
        //
        // The pre-fix gate read `verdictWire` (default `changes_required`) out
        // of this empty map and raised "engineering review requires changes".
        //
        // ── AMENDED 2026-10-15, per decision
        // `c495e02f-5c5d-4b45-8124-42ad0e90d6d4` (ARCHITECTURE, RESOLVED, option
        // A). This test asserted ZERO rows here, which was the b1 (93587cf)
        // instruction "a reviewer that produced no verdict must never become a
        // human decision". That invariant is now "no decision asserts a verdict
        // that was not parsed" — deliberately weaker, because the original form
        // left a review that COMPLETED with real findings parked at
        // `review_in_progress` with nothing on any operator screen, and the job
        // succeeded so no retry was coming.
        //
        // WHAT IT NOW CATCHES THAT IT DID NOT: that the gate is silent about a
        // review that concluded nothing. Reverting the gate to b1's behaviour
        // turns this red.
        //
        // WHAT IT CATCHES EXACTLY AS BEFORE: that `changes_required` is not
        // invented out of an empty map. The decision asserted below carries no
        // verdict token anywhere, so the original defect is still caught — by a
        // stricter assertion than the zero-row one, because it names every key a
        // reader could mistake for an assessment.
        final host = await _GateHost.reviewerResult(
          structuredResult: const {},
          summary:
              '## Engineering review\n\nThe diff adds a retry loop...\n\n'
              'Findings: none blocking.',
        );

        await host.drainGate();

        await host.expectNoVerdictRaised(
          why:
              'a reviewer that answered in prose and emitted no structured '
              'verdict was assessed by nobody. `changes_required` here was '
              'invented by the default at the top of the read.',
          reviewCompleted: true,
        );
        expect(host.absenceCauses, ['verdict_absent']);
      },
    );

    test(
      'SITE 2: an UNREADABLE verdict wire raises a decision that asserts NO '
      'verdict',
      () async {
        // The site that is easy to miss, because it reads like a parse fallback
        // and a parse fallback returning a conservative default is a normal
        // thing to see. It is not one here: `'CHANGES_REQUIRED'` is a string this
        // build does not recognise as a verdict, and the reviewer wrote it. The
        // pre-fix gate reported it to an operator as a reviewer having found
        // problems.
        //
        // Several spellings, because any of them reaching an operator as
        // "the reviewer found problems" is the same fabrication.
        //
        // ── AMENDED 2026-10-15, per decision
        // `c495e02f-5c5d-4b45-8124-42ad0e90d6d4` (ARCHITECTURE, RESOLVED, option
        // A), same amendment as SITE 1 and for the same reason: the review
        // COMPLETED, so nothing will retry it, so a decision is owed.
        //
        // WHAT IT NOW CATCHES THAT IT DID NOT: that an unrecognised verdict is
        // silently dropped on the floor. This is the residue of the Q1 prompt
        // defect — the reviewer answered `CHANGES_REQUIRED` and this build could
        // not read it — and it must reach an operator rather than a log.
        //
        // WHAT IT CATCHES EXACTLY AS BEFORE, and this is the load-bearing half:
        // that `'CHANGES_REQUIRED'` is NOT recorded as a verdict. The decision
        // raised below carries no `reviewVerdict` and no
        // `engineeringReviewResult`, and its question quotes the unreadable
        // string as a string this build does not recognise — never as a
        // conclusion. Reverting the `fromWire` catch-all to `changes_required`
        // turns this red on the `noVerdictOnTheRecord` assertion, not on a row
        // count.
        for (final wire in const [
          'CHANGES_REQUIRED',
          'changesRequired',
          'needs_work',
          'changes_required ',
          '',
        ]) {
          final host = await _GateHost.reviewerResult(
            structuredResult: {'verdict': wire},
            summary: 'I looked at it and here is my answer: $wire',
          );

          await host.drainGate();

          await host.expectNoVerdictRaised(
            why:
                "'$wire' is not one of ReviewVerdict's four wire values. "
                'Reading it as `changes_required` asserts a finding no reviewer '
                'made.',
            reviewCompleted: true,
          );
          expect(
            host.absenceCauses,
            [
              // An empty string is not even a wire value — it is "no verdict
              // said", which is a different absence with the same outcome.
              wire.isEmpty ? 'verdict_absent' : 'verdict_unreadable',
            ],
            reason:
                'the cause must name WHICH absence this is, not just that '
                'one happened',
          );
        }
      },
    );

    test('SITE 3: no reviewer result at all raises NOTHING', () async {
      // The live timeout case, verbatim: the execution reached `failed` at
      // exactly 300s with the coordinator's budget reason and the coordinator's
      // own fallback result never landed in the store.
      //
      // `_expireExecution` settles that as `interrupted`, which
      // `RetryPolicy.classify` reads as `transient`, which `_adopt` hands to
      // `scheduleRetry` — so this host carries a `retryWaiting` job, and that is
      // WHY nothing is raised. Not because the review stopped: a permanent
      // failure stops it just as dead and raises (see the other group).
      final host = await _GateHost.noResult(
        executionStatus: AgentSessionStatus.failed,
        executionReason:
            'execution exceeded its 300s timeout budget without reaching a '
            'terminal agent event',
      );

      await host.drainGate();

      await host.expectNoDecisionRaised(
        reason:
            'no reviewer ran to completion, so there is no assessment, AND a '
            'retry is still owed. The pre-fix gate built an '
            'EngineeringReviewResult with `findings: const []` and verdict '
            '`changesRequired`, which is an invented verdict AND an invented '
            'empty findings list.',
      );
      expect(
        host.absenceCauses,
        ['reviewer_timed_out'],
        reason:
            'requirement 3: the recorded reason must let the next operator tell '
            'a SLOW review from a BROKEN one. This one names the budget.',
      );
      expect(host.absenceDetails.single, contains('budget'));
    });

    test('a CRASH is recorded as a different cause than a timeout', () async {
      // Requirement 3 again, the other half: the same absence must not collapse
      // into one vague word, or "tell a slow review from a broken one" is not
      // actually delivered.
      final crashed = await _GateHost.noResult(
        executionStatus: AgentSessionStatus.failed,
        executionReason: 'start failure: could not open the workspace',
      );
      await crashed.drainGate();
      expect(crashed.absenceCauses, ['reviewer_execution_failed']);

      final interrupted = await _GateHost.noResult(
        executionStatus: AgentSessionStatus.interrupted,
        executionReason: null,
      );
      await interrupted.drainGate();
      expect(interrupted.absenceCauses, ['reviewer_timed_out']);

      final completedButSilent = await _GateHost.noResult(
        executionStatus: AgentSessionStatus.completed,
        executionReason: null,
      );
      await completedButSilent.drainGate();
      expect(completedButSilent.absenceCauses, ['reviewer_result_missing']);
    });

    test('the absence is DURABLE, on the reviewer execution itself', () async {
      // A log line leaves with the process. The next operator to open this item
      // has to be able to see why there is no verdict without reading logs, so
      // the record goes on the reviewer's own execution timeline next to the
      // `AgentExecution` and `AgentResult` that explain it.
      final host = await _GateHost.noResult(
        executionStatus: AgentSessionStatus.failed,
        executionReason: 'execution exceeded its 300s timeout budget',
      );

      await host.drainGate();

      final recorded = (await host.executionStore.readEvents(
        _GateHost.reviewerExecutionId,
      )).where((e) => e.payload?['reviewGate'] == 'no_verdict').toList();
      expect(recorded, hasLength(1));
      expect(recorded.single.payload?['cause'], 'reviewer_timed_out');
      expect(recorded.single.payload?['detail'], contains('budget'));
      expect(
        recorded.single.type,
        AgentEventType.warning,
        reason:
            'a reviewer that ended on `end_turn` with an unreadable payload did '
            'not FAIL. Stamping executionFailed onto it would be the same '
            'fabrication one layer down.',
      );
      expect(
        recorded.single.sequence,
        greaterThan(0),
        reason: 'it must not collide with the events already on the timeline',
      );
    });

    test(
      'draining the gate twice is idempotent and still raises nothing',
      () async {
        // The drain runs on every tick for as long as the job is terminal, so a
        // second pass over the same job must not accumulate records or — worse —
        // find its way to a decision.
        final host = await _GateHost.noResult(
          executionStatus: AgentSessionStatus.failed,
          executionReason: 'execution exceeded its 300s timeout budget',
        );

        await host.drainGate();
        await host.drainGate();

        await host.expectNoDecisionRaised();
        expect(host.absenceCauses, hasLength(2));
        expect(
          host.absenceCauses.toSet(),
          {'reviewer_timed_out'},
          reason: 'the cause is stable across passes',
        );
      },
    );
  });

  group('the INVERSE: a real verdict does raise the decision', () {
    test('a real changesRequired verdict raises the decision', () async {
      final host = await _GateHost.reviewerResult(
        structuredResult: {
          'verdict': ReviewVerdict.changesRequired.wire,
          'findings': [_GateHost.blockingFinding],
        },
      );

      await host.drainGate();

      final decision = await host.requireDecision();
      expect(decision.decisionType, HumanDecisionType.engineeringReview);
      expect(decision.blocking, isTrue);
      expect(
        decision.recommendation,
        'CHANGES_REQUIRED',
        reason:
            'this is the string the operator was shown BEFORE for code nobody '
            'reviewed. It must now be reachable only from a verdict that says '
            'so.',
      );
      expect(decision.metadata?['reviewVerdict'], 'changes_required');
      final result = decision.metadata?['engineeringReviewResult'] as Map;
      expect(
        result['verdict'],
        'changes_required',
        reason: 'the persisted result carries the verdict the reviewer gave',
      );
      expect(
        result['findings'],
        hasLength(1),
        reason:
            'and the findings the reviewer gave, so an operator can see WHAT '
            'was wrong rather than only that something was',
      );
    });

    test('a real approved verdict raises an APPROVE recommendation', () async {
      final host = await _GateHost.reviewerResult(
        structuredResult: {'verdict': ReviewVerdict.approved.wire},
      );

      await host.drainGate();

      expect((await host.requireDecision()).recommendation, 'APPROVE');
    });

    test(
      'a full embedded EngineeringReviewResult is used verbatim, findings and all',
      () async {
        final host = await _GateHost.reviewerResult(
          structuredResult: {
            'engineeringReviewResult': {
              'reviewExecutionId': _GateHost.reviewerExecutionId,
              'workItemId': _GateHost.workItemId,
              'verdict': ReviewVerdict.rejected.wire,
              'findings': [_GateHost.blockingFinding],
              'assessedDimensions': ['correctness', 'security'],
              'createdAt': '2026-10-14T09:00:00.000Z',
              'version': 1,
              'reviewerRole': AgentRole.engineeringReviewer.wire,
            },
          },
        );

        await host.drainGate();

        final decision = await host.requireDecision();
        expect(decision.recommendation, 'CHANGES_REQUIRED');
        final result = decision.metadata?['engineeringReviewResult'] as Map;
        expect(result['verdict'], 'rejected');
        expect(result['findings'], hasLength(1));
        expect(
          result['assessedDimensions'],
          ['correctness', 'security'],
          reason:
              'the embedded result is the richest thing a reviewer returns and '
              'it must survive to the decision rather than being rebuilt from '
              'two loose keys',
        );
      },
    );

    test(
      'an UNPARSEABLE embedded result falls back to the wire verdict',
      () async {
        // Not an absence on its own: the payload also carries a readable wire
        // verdict, and refusing to look at it would be a fabrication of its own.
        final host = await _GateHost.reviewerResult(
          structuredResult: {
            'engineeringReviewResult': {
              'verdict': 'not-a-verdict-in-the-model',
            },
            'verdict': ReviewVerdict.approvedWithMinorFindings.wire,
          },
        );

        await host.drainGate();

        expect((await host.requireDecision()).recommendation, 'APPROVE');
        expect(host.absenceCauses, isEmpty);
      },
    );
  });

  group('the review gate is not a second retry mechanism', () {
    test(
      'a no-verdict gate leaves the reviewer job\'s bounded budget untouched',
      () async {
        // Requirement 2. The gate is a CONSUMER of a terminal job outcome; it
        // never enqueues, re-queues, resets or re-attempts anything. The retry
        // that matters is `engineeringReviewDefinition.maxAttempts`, applied by
        // the scheduler's own `RetryPolicy`, and this asserts the gate is not
        // reaching around it.
        final host = await _GateHost.noResult(
          executionStatus: AgentSessionStatus.failed,
          executionReason: 'execution exceeded its 300s timeout budget',
        );

        expect(host.job.attempt, host.job.maxAttempts);
        expect(
          host.job.maxAttempts,
          engineeringReviewDefinition.maxAttempts,
          reason: 'the budget is the definition\'s, not the gate\'s',
        );
        expect(
          host.job.failure?.kind,
          JobFailureKind.transient,
          reason:
              'the scheduler wrote this, not the gate — `RetryPolicy` classified '
              'the interrupted worker execution as transient and `scheduleRetry '
              'recorded it. The assertion that matters is the one below it: that '
              'the row is byte-identical after the drain.',
        );

        await host.drainGate();

        expect(
          await host.readJob(),
          host.job,
          reason:
              'the gate wrote nothing to the job: no attempt charged, no failure '
              'invented, no requeue. A gate that reached into the queue would '
              'show up here.',
        );
        expect(
          (await host.jobStore.listJobsForWorkItem(
            _GateHost.workItemId,
          )).where((j) => j.jobType == JobType.engineeringReview),
          hasLength(1),
          reason: 'and it minted no second review job of its own',
        );
      },
    );

    test(
      'the item is left RETRYABLE: reviewInProgress, no blocking decision',
      () async {
        final host = await _GateHost.noResult(
          executionStatus: AgentSessionStatus.failed,
          executionReason: 'execution exceeded its 300s timeout budget',
        );

        await host.drainGate();

        final item = await host.workflowEngine.loadWorkItem(
          _GateHost.workItemId,
        );
        expect(item.state, WorkItemState.reviewInProgress);
        expect(item.blockingHumanDecisionId, isNull);
        expect(
          (await host.workflowStore.readHumanDecisionsForWorkItem(
            _GateHost.workItemId,
          )),
          isEmpty,
          reason:
              'not even a non-blocking decision row: a decision of type '
              'engineeringReview is the thing this invariant forbids, and a '
              'zero-row assertion cannot be satisfied by a decision of some '
              'other type either.',
        );
      },
    );

    // ## THE OTHER HALF OF THE SAME QUESTION
    //
    // Everything above holds the item because a retry is STILL OWED. The gate's
    // trigger is that question, not "did the review finish" — so it also has to
    // hold for the row where the answer is NO, and the row where the answer is
    // no is a `permanent` failure: `_adopt` completes it `failed` without ever
    // calling `scheduleRetry`, and `_returnRetriableItemsToEntryStates` only
    // returns items for a `retryWaiting` job.
    //
    // This is the shape measured on 2026-10-15 on `defect-DEF-1791685024220546`
    // and `defect-DEF-1791686357139031`: `AgpTransportException: ACP request
    // timed out`, job `failed`, `kind: permanent`, execution `failed`.
    test(
      'a PERMANENT failure with no retry owed reaches a person, and still '
      'fabricates nothing',
      () async {
        final host = await _GateHost.noResult(
          executionStatus: AgentSessionStatus.failed,
          executionReason: 'AgpTransportException: ACP request timed out',
          retryOwed: false,
          jobFailureReason: 'AgpTransportException: ACP request timed out',
        );

        await host.drainGate();

        // Reached a person. Before this lane the gate tested
        // `execution.status == completed`, which a permanent failure never
        // satisfies, so the item sat at review_in_progress for ever.
        await host.expectNoVerdictRaised(
          why:
              'the review job is terminally failed with kind permanent, so '
              'nothing will ever retry it and no other lane can re-mint it — '
              'reviewInProgress is not in engineeringReviewDefinition.'
              'entryStates, so RunnableWorkEvaluator answers noAction before '
              'any policy probe',
          reviewCompleted: false,
        );

        // And it did so without turning the crash into an assessment. This is
        // the property the whole file exists to protect: reaching a human is
        // not inventing a verdict.
        final decision = await host.requireDecision();
        expect(
          decision.question,
          isNot(contains('ran to completion')),
          reason:
              'the reviewer did not finish. Telling an operator that a review '
              'which died on an ACP timeout "ran to completion" is the same '
              'class of statement as inventing its verdict: a confident '
              'sentence about a fact nobody established.',
        );
        expect(
          decision.question,
          contains('did not finish'),
          reason:
              'and the operator has to be able to TELL the two apart, which is '
              'the whole reason the sentence is selected rather than assumed',
        );
        expect(
          decision.recommendation,
          verdictAbsentReviewFailedRecommendation,
          reason:
              'verdictAbsentRecommendation tells an operator to go and read what '
              'the reviewer wrote. On a review that crashed there is nothing to '
              'read, so pointing at prose that does not exist is a different '
              'false statement rather than a smaller version of this one.',
        );
        expect(
          decision.recommendation,
          startsWith('NO VERDICT'),
          reason:
              'both recommendations lead with the literal NO VERDICT, which is '
              'what stops "WHAT WE SUGGEST" being skimmed as an assessment',
        );
      },
    );

    test(
      'the failed-review decision records WHY the job is never retried, in the '
      'job\'s own words',
      () async {
        final host = await _GateHost.noResult(
          executionStatus: AgentSessionStatus.failed,
          executionReason: 'AgpTransportException: ACP request timed out',
          retryOwed: false,
          jobFailureReason: 'AgpTransportException: ACP request timed out',
        );

        await host.drainGate();

        final decision = await host.requireDecision();
        final recorded =
            (decision.metadata![reviewVerdictAbsentMetadataKey]!
                    as Map<String, dynamic>)['reviewJobFailure']!
                as Map<String, dynamic>;

        // The raw worker-side text. The coordinator composes its OWN
        // `AgentExecution.reason`, so this string survives nowhere else, and it
        // is the difference between "the reviewer was slow" and "the reviewer
        // could not be reached at all" — which is what an operator is choosing
        // between when they pick rework or cancel.
        expect(
          recorded['reason'],
          contains('ACP request timed out'),
        );
        expect(
          recorded['kind'],
          'permanent',
          reason:
              '`kind` is the field that answers "will this ever run again", and '
              'permanent is the class nothing retries',
        );
        expect(recorded['jobState'], 'failed');
        expect(recorded['attempt'], 1);
        expect(
          recorded['maxAttempts'],
          engineeringReviewDefinition.maxAttempts,
        );
        expect(
          decision
              .metadata![reviewVerdictAbsentMetadataKey]!['reviewCompleted'],
          isFalse,
          reason:
              'the absence and the completion are separate facts. A verdict-less '
              'review that finished and one that died are both absences, and an '
              'operator has to be able to tell them apart before acting.',
        );
      },
    );

    test(
      'a live retry is NOT read as a spent one: retryWaiting at attempt == '
      'maxAttempts still raises nothing',
      () async {
        // NON-VACUITY, and it is the shape production actually writes.
        // `JobQueue.scheduleRetry` PRE-INCREMENTS `attempt`, so a retry that is
        // perfectly live answers `attempt == maxAttempts` and `2 < 2`, which is
        // false. A gate that asked "has the budget been spent?" instead of "is a
        // retry owed?" would park this item and pre-empt the retry that is
        // about to be claimed — so this test is written to fail against exactly
        // that reading, not merely against "the review did not finish".
        final host = await _GateHost.noResult(
          executionStatus: AgentSessionStatus.failed,
          executionReason: 'execution exceeded its 300s timeout budget',
        );

        expect(
          host.job.state,
          JobState.retryWaiting,
          reason: 'a transient failure is scheduled for retry by the scheduler',
        );
        expect(host.job.attempt, host.job.maxAttempts);
        expect(
          host.job.failure?.kind.isRetryable,
          isTrue,
          reason:
              'and it is the class `_returnRetriableItemsToEntryStates` returns '
              'items for — `isRetryable` is `== transient` by construction',
        );

        await host.drainGate();

        await host.expectNoDecisionRaised(
          reason:
              'a retry is still owed, so parking this item at '
              'waitingForHumanDecision would pre-empt it: that state is the one '
              'state `_returnOneToEntryState` explicitly skips',
        );
      },
    );

    test(
      'a review that COMPLETED with no verdict is not regressed by the new '
      'trigger',
      () async {
        // The other stranded pair, `defect-DEF-1791685264570406` and
        // `defect-DEF-1791685924503981`: the reviewers ran to `completed` and
        // recorded `{}`, so no verdict parsed. They were fixed by the review
        // instruction change, and this is the assertion that a trigger keyed on
        // "no retry is owed" still raises for them — a terminal `succeeded` job
        // owes no retry either, so the two cases share one path and this guards
        // against that sharing costing either of them.
        final host = await _GateHost.reviewerResult(structuredResult: const {});

        await host.drainGate();

        await host.expectNoVerdictRaised(
          why: 'the job SUCCEEDED, so maxAttempts only ever retries a failure',
          reviewCompleted: true,
        );
        expect(
          (await host.requireDecision()).recommendation,
          verdictAbsentRecommendation,
          reason:
              'and it keeps its OWN recommendation: the completed-review case '
              'still has prose to read, and sharing the failed-review one would '
              'point at prose that is not there',
        );
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // A ROUTE IS NOT A VERDICT — decision 92d567e3-da03-4c43-99f4-e3726472f0ab.
  //
  // Everything above this line is about a review that reached `reviewInProgress`
  // and left no verdict behind. This block is about the NEW thing that review now
  // causes: the platform MOVES the item instead of parking it, because the pair
  // it was parked on (`[rework, reject]`) reaches no reviewer at all.
  //
  // Moving a work item between states is the one operation in this repository
  // with no natural anti-fabrication property of its own. A verdict is carried on
  // named fields that a reader checks; a route is carried on a state, and a
  // state says nothing about who assessed what. So the risk is not "a route
  // writes a verdict-shaped field" — it is "a route reads, six weeks later, as
  // though somebody had reviewed the work". These tests close both: nothing
  // verdict-shaped is written on ANY branch, and the durable record of the move
  // says in its own text that no reviewer looked.
  // ══════════════════════════════════════════════════════════════════════════

  group('a ROUTE is not a verdict', () {
    // BOTH BRANCHES, because a one-branch test proves the branch it ran. The
    // re-review branch is the dangerous one — it is the branch where the item
    // goes looking, to an operator and to every downstream reader, as though a
    // review were imminent or had happened.
    for (final entry in const [
      (
        label: 'implementation DID commit (re-review)',
        endingRevision: 'a-real-commit',
      ),
      (
        label: 'implementation produced NOTHING (implementation)',
        endingRevision: null,
      ),
    ]) {
      test(
        '${entry.label}: the routed item carries NO verdict on any record',
        () async {
          final host = await _GateHost.producerArtifact(
            endingRevision: entry.endingRevision,
          );

          await host.runMissingArtifact();

          final item = await host.workflowEngine.loadWorkItem(
            _GateHost.workItemId,
          );
          expect(
            await host.workflowStore.readHumanDecisionsForWorkItem(
              _GateHost.workItemId,
            ),
            isEmpty,
            reason:
                'a routed item is not offered to anybody, so there is no '
                'decision on which a verdict could have been smuggled. This is '
                'the b1 invariant applied to the branch that raises NOTHING',
          );

          // And nothing on the item itself. `metadata` is where a verdict would
          // live if the route had been taken as an assessment, and the keys
          // checked here are the exact keys `readReviewVerdictProvenance` and
          // every downstream reader look for.
          final metadata = item.metadata ?? const <String, dynamic>{};
          expect(
            metadata.containsKey('reviewVerdict'),
            isFalse,
            reason:
                'its presence is read as "a reviewer assessed this and here is '
                'how". Nothing assessed it',
          );
          expect(
            metadata.containsKey('engineeringReviewResult'),
            isFalse,
            reason: 'a result object would classify this item as `assessed`',
          );
          expect(
            metadata.containsKey('verdictRecorded'),
            isFalse,
            reason:
                'this key is the verdict-less decision\'s own marker. Writing it '
                'on a routed item would claim a verdict-less DECISION exists, '
                'and none does',
          );

          // The log line is the operator-facing half of the same claim.
          final route = host.eventNamed(
            'engineering-review-verdict-absent-routed',
          );
          expect(route, isNotNull);
          expect(
            route!['carriesVerdict'],
            isFalse,
            reason: 'and it says so in the field a reader looks at',
          );
          expect(
            route['decision'],
            contains('not a review verdict'),
            reason:
                'the sentence states what kind of statement this is. A move '
                'that does not label itself is a move a later reader has to '
                'guess about',
          );
        },
      );
    }

    test(
      'the DURABLE transition record of a route reads as a route, and names no '
      'verdict',
      () async {
        // A log line is not a record: it leaves with the process. The transition
        // record is what an operator, a reviewer of this repository, or a future
        // agent reads when they ask "why is this item back at agent_completed
        // and what happened to the review?". A record that said "review
        // requested changes" would be the b1 defect one layer down.
        final host = await _GateHost.producerArtifact(
          endingRevision: 'a-real-commit',
        );

        await host.runMissingArtifact();

        final records = await host.workflowStore.readTransitionHistory(
          _GateHost.workItemId,
        );
        final route = records.lastWhere(
          (r) => r.toState == WorkItemState.agentCompleted,
          orElse: () => throw StateError('no route was recorded'),
        );
        expect(route.outcome, TransitionOutcome.accepted);
        expect(route.actorType, ActorType.orchestrator);

        final reason = route.reason ?? '';
        expect(reason, contains('the reviewer concluded nothing'));
        expect(
          reason,
          contains('No reviewer assessed this work'),
          reason:
              'the record has to deny the assessment in its own words, because '
              'the state it moves to cannot. `agent_completed` says "a '
              'producer finished"; only the reason can say nobody looked',
        );
        expect(reason, contains('a-real-commit'));
        for (final wire in ReviewVerdict.values) {
          expect(
            reason,
            isNot(contains(wire.wire)),
            reason:
                '${wire.wire} is a reviewer assessment. No reviewer produced '
                'one, and a durable record asserting otherwise is exactly the '
                'fabrication this repository has already paid for once',
          );
        }
        expect(reason, isNot(contains('CHANGES_REQUIRED')));
        expect(reason, isNot(contains('APPROVE')));
      },
    );

    test(
      'a reviewer that DID return a verdict is untouched: unchanged behaviour, '
      'verdict intact',
      () async {
        // Acceptance criterion 1, and the regression guard for the whole block.
        // The routing was added to a file whose other job is to raise a
        // verdict-carrying decision, and the failure mode to fear is that it
        // starts reading as a review that happened.
        final host = await _GateHost.reviewerResult(
          structuredResult: const {'verdict': 'approved'},
        );

        await host.drainGate();

        final item = await host.workflowEngine.loadWorkItem(
          _GateHost.workItemId,
        );
        expect(item.state, WorkItemState.waitingForHumanDecision);
        final decision = await host.workflowStore.readHumanDecision(
          item.blockingHumanDecisionId!,
        );
        expect(
          decision.metadata?['reviewVerdict'],
          'approved',
          reason:
              'the real verdict, on the real key, exactly as before. If the '
              'routing had been wired into this path this would be null and the '
              'operator would be asked to adjudicate a review that happened',
        );
        expect(
          decision.metadata?['engineeringReviewResult'],
          isA<Map<String, dynamic>>(),
          reason: 'and the parsed result is still attached to it',
        );
        expect(decision.recommendation, 'APPROVE');
        expect(
          decision.options!.map((o) => o.optionId),
          ['approve', 'reject', 'rework'],
          reason:
              'all three, because a reviewer DID conclude. This is the pair '
              'that only exists when an assessment was actually produced',
        );

        // And the routing gate, pointed at that same item, changes nothing: it
        // short-circuits on the already-parked state.
        await host.runMissingArtifact();
        final after = await host.workflowEngine.loadWorkItem(
          _GateHost.workItemId,
        );
        expect(after.state, WorkItemState.waitingForHumanDecision);
        expect(after.blockingHumanDecisionId, decision.decisionId);
        expect(
          host.eventNamed('engineering-review-verdict-absent-routed'),
          isNull,
          reason:
              'no route was taken, and a route is never taken on an item that a '
              'reviewer already assessed',
        );
      },
    );
  });
}

/// A minimal, real-by-construction harness for the gate.
///
/// Real [DurableWorkflowEngine], real [InMemoryWorkflowStore], real
/// [InMemoryExecutionStore], and a real [JobQueue]-minted [Job] so the budget
/// under test is [engineeringReviewDefinition]'s rather than a literal written
/// here. The reviewer execution and result are the two shapes QA actually holds.
class _GateHost {
  _GateHost._({
    required this.workflowStore,
    required this.workflowEngine,
    required this.executionStore,
    required this.workerStore,
    required this.jobStore,
    required this.job,
    required this.loggedEvents,
  });

  static const workItemId = 'wi-verdict';
  static const reviewerExecutionId = 'agx-wx-review';
  static const producerExecutionId = 'agx-wx-impl';
  static final _now = DateTime.utc(2026, 10, 14, 9);

  /// A finding in [DesignFinding]'s own wire shape — every required field
  /// present, because the point of the inverse tests is that a REAL review
  /// survives to the decision intact, and a hand-waved finding that fails to
  /// parse would be testing the parser rather than the gate.
  static final blockingFinding = <String, dynamic>{
    'findingId': 'fnd-1',
    'revisionId': 'rev-1',
    'reviewExecutionId': reviewerExecutionId,
    'category': DesignFindingCategory.feasibility.wire,
    'severity': DesignFindingSeverity.blocker.wire,
    'dimension': 'correctness',
    'evidence': 'apps/server/lib/src/review/engineering_review_gate.dart',
    'requiredCorrection': 'the retry loop carries no bound',
    'affectedSurface': 'lib/retry.dart',
    'createdAt': _now.toIso8601String(),
    'version': 1,
  };

  /// A work item at `reviewInProgress` with a real producer identity — the
  /// state every one of the three stranded items was actually in.
  ///
  /// [jobState]/[failure]/[attempt] exist because the gate's trigger is a fact
  /// about the QUEUE, and a fixture that always answered `succeeded` could not tell
  /// a live retry from a spent one. They are stamped exactly as `Scheduler._adopt`
  /// stamps them for the same worker outcome, so a host models a row the scheduler
  /// can really produce rather than one it cannot.
  static Future<_GateHost> _base({
    JobState jobState = JobState.succeeded,
    JobFailure? failure,
    int? attempt,
  }) async {
    final workflowStore = InMemoryWorkflowStore();
    final jobStore = InMemoryJobStore();
    await workflowStore.saveWorkItem(
      WorkItem(
        workItemId: workItemId,
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'A change nobody reviewed',
        description: 'The implementer committed; the reviewer did not answer.',
        state: WorkItemState.reviewInProgress,
        metadata: const {'producerActorId': producerExecutionId},
        createdAt: _now,
        updatedAt: _now,
      ),
    );

    // Minted through the real queue so `attempt`/`maxAttempts` are the
    // definition's own, then stamped with the reviewer execution exactly as
    // `_adopt` does.
    final enqueued = await JobQueue(store: jobStore).enqueueIfAbsent(
      workItemId: workItemId,
      definition: engineeringReviewDefinition,
      dedupeKey: '$workItemId:engineering_review:a0',
      instruction: 'Review the implementation.',
    );
    final job = enqueued.job.copyWith(
      state: jobState,
      failure: failure,
      attempt: attempt,
      executionReference: JobExecutionReference(
        workerExecutionId: 'wx-review',
        agentExecutionId: reviewerExecutionId,
        createdAt: _now,
      ),
    );
    await jobStore.saveJob(job);

    return _GateHost._(
      workflowStore: workflowStore,
      workflowEngine: DurableWorkflowEngine(store: workflowStore),
      executionStore: InMemoryExecutionStore(),
      workerStore: InMemoryWorkerStore(),
      jobStore: jobStore,
      job: job,
      loggedEvents: <Map<String, dynamic>>[],
    );
  }

  /// A producer that left [endingRevision] behind — `null` being the shape that
  /// started all of this, and a commit being the shape this routing is FOR.
  ///
  /// Written the way `LocalWorker` writes it, against the same
  /// `producerActorId` the coordinator stamps, because `producedCommitFor` joins
  /// the two records on exactly that pair and refuses to guess when it cannot.
  static Future<_GateHost> producerArtifact({
    required String? endingRevision,
  }) async {
    final host = await _base();
    await host.workerStore.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: 'wx-impl',
        workItemId: workItemId,
        repositoryPath: '/durable/clone',
        requestedStartingRevision: 'aaaaaaa',
        requiredCapabilities: const {
          WorkerCapability.linux,
          WorkerCapability.git,
        },
        agentExecutionId: producerExecutionId,
        endingRevision: endingRevision,
        status: WorkerExecutionStatus.executedPass,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
      ),
    );
    return host;
  }

  /// A reviewer that FINISHED and left a result — the shape whose
  /// `structuredResultJson` was `{}` in QA.
  static Future<_GateHost> reviewerResult({
    required Map<String, dynamic> structuredResult,
    String summary = 'the reviewer answered',
  }) async {
    final host = await _base();
    await host._saveReviewerExecution(AgentSessionStatus.completed, null);
    await host.executionStore.saveResult(
      reviewerExecutionId,
      AgentResult(
        resultId: 'result-$reviewerExecutionId',
        sessionId: 'ses-review',
        workItemId: workItemId,
        executionId: reviewerExecutionId,
        role: AgentRole.engineeringReviewer,
        status: AgentResultStatus.completed,
        artifacts: const [],
        diagnostics: AgentDiagnostics(
          exitCode: 0,
          durationMs: 131000,
          toolCalls: 7,
          errors: const [],
          warnings: const [],
        ),
        structuredResult: structuredResult,
        summary: summary,
        completedAt: _now,
      ),
    );
    return host;
  }

  /// A reviewer that produced NO result — the 300s budget case, or the crash.
  ///
  /// ## `retryOwed` IS THE GATE'S TRIGGER, AND IT IS THE QUEUE'S ANSWER
  ///
  /// A reviewer that fails transiently is NOT on a `succeeded` job: `RetryPolicy`
  /// classifies `timedOut`/`orphaned` as `transient`, and `Scheduler._adopt` hands
  /// those to `JobQueue.scheduleRetry`, which writes `retryWaiting` and
  /// PRE-INCREMENTS `attempt`. So the real live-retry row is
  /// `state == retryWaiting` with `attempt == maxAttempts` — a gate that tested
  /// `attempt < maxAttempts` would read that perfectly live retry as spent. The
  /// gate checks `retryWaiting` first, and this fixture writes the row that would
  /// catch it if it did not.
  ///
  /// `retryOwed: false` is the other half: a `permanent` failure, which `_adopt`
  /// routes straight to `complete(failed)` without ever scheduling a retry.
  static Future<_GateHost> noResult({
    required AgentSessionStatus executionStatus,
    required String? executionReason,
    bool retryOwed = true,
    String? jobFailureReason,
  }) async {
    final host = await _base(
      jobState: retryOwed ? JobState.retryWaiting : JobState.failed,
      // `scheduleRetry` pre-increments, so a live retry has already spent the
      // counter. Modelling that is the whole point — see the doc above.
      attempt: retryOwed ? engineeringReviewDefinition.maxAttempts : 1,
      failure: retryOwed
          ? JobFailure(
              code: JobFailureCode.executionInterrupted,
              kind: JobFailureKind.transient,
              reason: jobFailureReason ?? executionReason,
            )
          : JobFailure(
              code: JobFailureCode.executionFailed,
              kind: JobFailureKind.permanent,
              reason: jobFailureReason,
            ),
    );
    await host._saveReviewerExecution(executionStatus, executionReason);
    return host;
  }

  Future<void> _saveReviewerExecution(
    AgentSessionStatus status,
    String? reason,
  ) async {
    await executionStore.saveExecution(
      AgentExecution(
        executionId: reviewerExecutionId,
        workItemId: workItemId,
        requestId: reviewerExecutionId,
        runtimeTypeId: 'eng-review-runtime',
        role: AgentRole.engineeringReviewer,
        status: status,
        workspace: const AgentWorkspace(
          workspaceId: 'ws-review',
          path: '/worktrees/review',
          startingRevision: 'abc1234',
        ),
        startedAt: _now,
        completedAt: _now,
        reason: reason,
      ),
    );
  }

  final InMemoryWorkflowStore workflowStore;
  final DurableWorkflowEngine workflowEngine;
  final InMemoryExecutionStore executionStore;
  final InMemoryWorkerStore workerStore;
  final InMemoryJobStore jobStore;
  final Job job;
  final List<Map<String, dynamic>> loggedEvents;

  /// The gate the operator's item actually reached: the fail-closed handler the
  /// composition root runs for a review job the scheduler could not resolve an
  /// artifact for.
  ///
  /// Driven rather than hand-built, for the same reason [drainGate] is: a test
  /// that assembles the expected state itself proves only that a test can build
  /// two equal objects.
  Future<void> runMissingArtifact() => engineeringReviewMissingArtifact(
    workflowEngine: workflowEngine,
    executionStore: executionStore,
    workerStore: workerStore,
    job: job,
    logger: (message, context) {
      loggedEvents.add({...context, '_message': message});
    },
  );

  Map<String, dynamic>? eventNamed(String name) {
    for (final event in loggedEvents) {
      if (event['_message'] == name) return event;
    }
    return null;
  }

  /// Every `no_verdict` cause this host's drain(s) recorded, in order.
  List<String> get absenceCauses => loggedEvents
      .where((e) => e['cause'] != null)
      .map((e) => e['cause']! as String)
      .toList();

  List<String> get absenceDetails => loggedEvents
      .where((e) => e['why'] != null)
      .map((e) => e['why']! as String)
      .toList();

  Future<void> drainGate() => engineeringReviewTickHandler(
    workflowEngine: workflowEngine,
    executionStore: executionStore,
    logger: (message, context) {
      if (message == 'engineering-review-gate-no-verdict') {
        loggedEvents.add(context);
      }
    },
  )(job);

  Future<Job> readJob() async => (await jobStore.readJob(job.jobId))!;

  /// The decision the gate raised, failing loudly if it raised none.
  ///
  /// Async on purpose: the caller reads it as `await host.requireDecision()`,
  /// and a synchronous version could not survive an await inside itself.
  Future<HumanDecision> requireDecision() async {
    final item = await workflowEngine.loadWorkItem(workItemId);
    final id = item.blockingHumanDecisionId;
    if (id == null) {
      throw StateError(
        'no blocking decision was raised; the item is at ${item.state.wire}',
      );
    }
    return workflowStore.readHumanDecision(id);
  }

  /// The central assertion for a review whose JOB STILL OWES A RETRY: no decision
  /// at all, and the item still retryable.
  ///
  /// Used by the tests whose host carries `retryOwed: true` — `SITE 3`, the
  /// double-drain, and `the item is left RETRYABLE`.
  ///
  /// ## THE TRIGGER IS THE QUEUE, SO THIS IS NOT ABOUT THE REVIEW
  ///
  /// The original assertion was "a review that did not finish raises nothing",
  /// which was right for the wrong reason: it read the EXECUTION's status to
  /// decide whether the queue still had work pending. Those came apart on
  /// 2026-10-15 — a permanent review failure is `failed`/`interrupted` and never
  /// `completed`, AND is owed no retry by anything, so the execution's status
  /// could not answer the question.
  ///
  /// So every host calling this must carry `retryOwed: true`, which is what makes
  /// the name true: the reason nothing is raised here is that a retry is coming,
  /// not that the review stopped. The mirror case — same dead execution, no retry
  /// owed — is asserted in the other group, and it raises.
  Future<void> expectNoDecisionRaised({String? reason}) async {
    expect(
      job.state,
      JobState.retryWaiting,
      reason:
          'this assertion only holds while a retry is owed. A host calling it must '
          'carry `retryOwed: true`, or it is asserting that a stranded item is '
          'fine — which is the defect.',
    );
    final decisions = await workflowStore.readHumanDecisionsForWorkItem(
      workItemId,
    );
    expect(
      decisions,
      isEmpty,
      reason:
          reason ??
          'an engineeringReview decision exists while the reviewer job is still '
              'owed a retry, so it pre-empts a retry that is coming',
    );
    final item = await workflowEngine.loadWorkItem(workItemId);
    expect(
      item.state,
      WorkItemState.reviewInProgress,
      reason: 'the item must stay where the retry path can still reach it',
    );
    expect(item.blockingHumanDecisionId, isNull);
  }

  /// The AMENDED central assertion, for a review that produced no verdict while
  /// its job owed no retry — whether it COMPLETED silently or FAILED.
  ///
  /// ## IT IS STRICTER THAN THE ZERO-ROW ONE IT REPLACES, NOT LOOSER
  ///
  /// `isEmpty` could be satisfied by a decision of ANY type, which is why b1's
  /// comment insisted it "cannot be satisfied by a decision of some other type
  /// either". But it could equally be satisfied by a decision that is merely
  /// *quiet* about the verdict — and quietness is exactly the failure this lane
  /// was produced by. So this asserts the three things a reader would actually
  /// mistake for an assessment, and asserts that none of them is present:
  ///
  ///  1. `metadata['reviewVerdict']` — absent. Every downstream reader that
  ///     asks "was this reviewed, and how" asks this first.
  ///  2. `metadata['engineeringReviewResult']` — absent. It is what
  ///     `readReviewVerdictProvenance` parses, and a result object with a
  ///     verdict in it would classify this decision as `assessed`.
  ///  3. `recommendation` — not one of [ReviewVerdict]'s four wire values, not
  ///     `APPROVE`, and not `CHANGES_REQUIRED`. It is rendered to an operator
  ///     under "WHAT WE SUGGEST".
  ///
  /// Plus the positive half: the decision says, in its own text, that no verdict
  /// was produced, and offers only choices that assert none.
  ///
  /// [reviewCompleted] is passed rather than read, because the recommendation
  /// differs on the two paths and this helper is the one place that asserts it —
  /// it must not be allowed to drift into asserting the completed-review
  /// sentence for a review that died.
  Future<void> expectNoVerdictRaised({
    required String why,
    required bool reviewCompleted,
  }) async {
    final item = await workflowEngine.loadWorkItem(workItemId);
    final blockingId = item.blockingHumanDecisionId;

    expect(
      blockingId,
      isNotNull,
      reason:
          'no retry is owed on this job, so nothing else will ever move this '
          'item: $why. Leaving it at reviewInProgress with no decision is the '
          'silent park this decision was resolved to end.',
    );
    expect(
      item.state,
      WorkItemState.waitingForHumanDecision,
      reason: 'the item must be reachable by a person',
    );

    final decision = await workflowStore.readHumanDecision(blockingId!);
    final metadata = decision.metadata ?? const <String, dynamic>{};

    expect(
      metadata.containsKey('reviewVerdict'),
      isFalse,
      reason:
          'no key named reviewVerdict may exist on this decision, not even '
          'carrying null. Every reader downstream treats its presence as "a '
          'reviewer assessed this". $why',
    );
    expect(
      metadata.containsKey('engineeringReviewResult'),
      isFalse,
      reason:
          'a result object would be parsed by readReviewVerdictProvenance and '
          'this decision would classify as `assessed`. $why',
    );
    expect(
      metadata[reviewVerdictAbsentMetadataKey],
      isA<Map<String, dynamic>>(),
      reason:
          'the decision must be recognisable as the verdict-less one from the '
          'record alone, which is what keeps it apart from a supersession '
          'stall. $why',
    );
    expect(
      metadata[reviewVerdictAbsentMetadataKey]!['verdictRecorded'],
      isFalse,
      reason: 'and it must say so in its own words',
    );
    expect(
      decision.recommendation,
      isNot(
        anyOf('APPROVE', 'CHANGES_REQUIRED', 'approved', 'changes_required'),
      ),
      reason:
          'the recommendation is rendered to an operator under "WHAT WE '
          'SUGGEST". On this decision it must not be readable as an assessment. '
          '$why',
    );
    expect(
      decision.recommendation,
      verdictAbsentRecommendationFor(reviewCompleted: reviewCompleted),
      reason:
          'and it must be the one the gate documents FOR THIS PATH — the '
          'completed-review line tells an operator to read what the reviewer '
          'wrote, which is wrong when it wrote nothing $why',
    );
    expect(
      decision.question,
      allOf(
        contains('NO VERDICT'),
        contains(absenceReasonFragment()),
      ),
      reason:
          'the question is what an operator reads first and the only field of a '
          'decision that reaches the screen. It must state the absence in those '
          'terms. $why',
    );
    expect(
      decision.options!.map((o) => o.optionId),
      unorderedEquals(['rework', 'cancel']),
      reason:
          'approve routes to reviewApproved and reject to reviewRejected — both '
          'are assessments, and a decision carrying no verdict cannot offer '
          'either. $why',
    );
    expect(
      decision.options!.any((o) => o.recommended ?? false),
      isFalse,
      reason:
          'the platform has no basis for preferring one answer over the other '
          'here, and highlighting one would be it nudging an operator toward a '
          'judgement nobody made',
    );
    for (final wire in ReviewVerdict.values) {
      expect(
        decision.recommendation,
        isNot(wire.wire),
        reason: '${wire.wire} is a reviewer assessment; this decision has none',
      );
    }

    // Exactly one decision, and the absence is still on the execution timeline.
    expect(
      await workflowStore.readHumanDecisionsForWorkItem(workItemId),
      hasLength(1),
      reason: 'one question, not a queue of them',
    );
    expect(
      (await executionStore.readEvents(
        reviewerExecutionId,
      )).where((e) => e.payload?['reviewGate'] == 'no_verdict'),
      isNotEmpty,
      reason:
          'b1\'s durable absence record is kept as well: the decision is the '
          'thing the operator acts on, the timeline entry is the thing a later '
          'reader audits',
    );
  }

  /// The substring [expectNoVerdictRaised] requires the question to carry for
  /// the cause this host produced.
  ///
  /// Every cause in the gate's `_NoVerdictCause`, not just the two a COMPLETED
  /// review can produce: the question quotes [Absence.detail] verbatim, and the
  /// detail is what differs between "the reviewer answered and said nothing
  /// assessable" and "the reviewer never wrote an answer at all". A helper that
  /// only knew two causes would have made this assertion vacuous on the path that
  /// matters most here.
  String absenceReasonFragment() {
    final cause = absenceCauses.isEmpty ? '' : absenceCauses.last;
    return switch (cause) {
      'verdict_absent' => 'carrying no verdict',
      'verdict_unreadable' => 'is not a review verdict',
      'structured_result_unreadable' => 'the reviewer result could not be read',
      'reviewer_timed_out' ||
      'reviewer_execution_failed' ||
      'reviewer_result_missing' => 'without writing an agent result',
      _ => 'no cause recorded',
    };
  }
}
