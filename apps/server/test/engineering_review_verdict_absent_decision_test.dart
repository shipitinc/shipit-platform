import 'package:control_plane_server/src/endpoints/work_item_action_endpoints.dart';
import 'package:control_plane_server/src/review/engineering_review_gate.dart';
import 'package:control_plane_server/src/services/control_plane_service.dart';
import 'package:control_plane_server/src/triage/stalled_work_item_gate.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

/// ## WHAT THIS FILE PROVES, AND WHY IT IS A SEPARATE FILE
///
/// On 2026-10-15 four engineering-review executions reached `completed` against
/// real commits — one of them `18ad90a`, +957/-199 — and every one produced real,
/// specific findings in its prose. Every one recorded `{}` in
/// `structuredResultJson`. So no verdict was parsed, so no decision was raised,
/// so all four work items sat at `review_in_progress` with nothing on any
/// operator screen and nothing coming: the job SUCCEEDED, and `maxAttempts` only
/// ever retries a failure.
///
/// Decision `c495e02f-5c5d-4b45-8124-42ad0e90d6d4` (ARCHITECTURE, RESOLVED,
/// option A) resolved that by permitting a decision that carries NO verdict, and
/// by requiring four things of it: it must not read as an assessment, it must be
/// distinguishable from a supersession stall, it must be idempotent, and it must
/// be recoverable. This file drives each of those.
///
/// It is separate from `engineering_review_never_fabricates_verdict_test.dart`
/// because that file is b1's, and b1's invariant is quoted and amended IN PLACE
/// there with its reason inline. This file is the new behaviour's own evidence
/// and is red against `2b29bdd` — the reviewed HEAD this lane corrected from.
///
/// ## THE FOUR ASSERTIONS THE DECISION FILE FORBADE, AS TESTS
///
/// * "no decision asserts a verdict the reviewer did not parse and return" —
///   `a verdict-less decision carries no verdict on ANY key a reader could
///   mistake for one`, and `the repository's OTHER, independent verdict reader
///   agrees there is none`.
/// * "no inferring, defaulting or deriving a verdict from prose" —
///   `prose that reads like a verdict does not become one`.
/// * "not treating the review succeeded as the review concluded" —
///   `the decision says the review SUCCEEDED and CONCLUDED NOTHING, in those
///   words`.
/// * "no relaxing the parser" — covered in the other file: an unparsed wire is
///   still `verdict_unreadable` and still no verdict.
void main() {
  group(
    'a COMPLETED review with no verdict raises a decision an operator can act on',
    () {
      test(
        'the four parked items\' exact shape: completed, `{}` in the structured '
        'result, real prose in the summary',
        () async {
          // The live shape, not an approximation. This is what
          // `{}` + a 2000-byte markdown `summary` + `end_turn` produces, and it is
          // the shape all four items were in.
          final host = await _Host.completedWithoutVerdict(
            prose: _realReviewProse,
          );

          await host.drainGate();

          final decision = await host.requireDecision();
          expect(
            decision.decisionType,
            HumanDecisionType.engineeringReview,
            reason:
                'forced, not chosen: `reviewInProgress -> '
                'waitingForHumanDecision` carries '
                'blockingHumanDecisionPendingOfType([engineeringReview]), so no '
                'other type is reachable from this state',
          );
          expect(decision.blocking, isTrue);
          expect(
            isVerdictAbsentDecision(decision),
            isTrue,
            reason:
                'and it must be recognisable as the verdict-less one from the '
                'record alone',
          );
          expect(
            (await host.workflowEngine.loadWorkItem(_Host.workItemId)).state,
            WorkItemState.waitingForHumanDecision,
            reason:
                'the item moves, so a person can act on it. This is the whole '
                'point: at 2b29bdd it stayed at review_in_progress with no '
                'decision and nothing on screen',
          );
        },
      );

      test(
        'the reviewer\'s ACTUAL prose reaches the operator, unedited',
        () async {
          final host = await _Host.completedWithoutVerdict(
            prose: _realReviewProse,
          );

          await host.drainGate();

          final decision = await host.requireDecision();
          expect(
            decision.question,
            contains(_realReviewProse),
            reason:
                'the reviewer did real work against a real commit and it costs '
                'real credits. Hiding it would replace one false state — an item '
                'nobody can see — with another: an item whose operator is told '
                '"nothing happened" when a reviewer wrote 2000 characters. The '
                'prose is also the ONLY thing that lets an operator judge whether '
                'this review is worth repeating',
          );
        },
      );

      test('a review that wrote NO prose still raises, and says so', () async {
        // Not hypothetical: `ReviewAssessment.noReviewerOutput` in
        // `readReviewVerdictProvenance` is a real class, and an empty `summary`
        // is a real shape. The operator must not be handed an empty section that
        // reads like something failed to load.
        final host = await _Host.completedWithoutVerdict(prose: '');

        await host.drainGate();

        final decision = await host.requireDecision();
        expect(
          decision.question,
          contains('The reviewer wrote no summary either'),
        );
        expect(
          decision
              .metadata![reviewVerdictAbsentMetadataKey]['reviewProsePresent'],
          isFalse,
          reason:
              'and the record says so structurally, so a surface can render it '
              'without parsing the question',
        );
      });

      test('an UNREADABLE verdict wire takes the same path', () async {
        // The residue of the Q1 prompt defect: a reviewer that answered
        // `CHANGES_REQUIRED` in a spelling this build does not parse. It
        // completed, so it needs the same treatment — and the decision has to
        // quote the string as a string this build does not recognise, never as a
        // conclusion the reviewer reached.
        final host = await _Host.completedWithoutVerdict(
          structuredResult: {'verdict': 'CHANGES_REQUIRED'},
          prose: 'I looked at it and here is my answer: CHANGES_REQUIRED',
        );

        await host.drainGate();

        final decision = await host.requireDecision();
        expect(
          decision.metadata![reviewVerdictAbsentMetadataKey]!['cause'],
          'verdict_unreadable',
        );
        expect(
          decision.question,
          allOf(contains('NO VERDICT'), contains('CHANGES_REQUIRED')),
        );
        expect(
          verdictAbsentDecisionCarriesAVerdict(decision),
          isFalse,
        );
      });

      test('idempotent under repeated ticks — one decision, not a queue', () async {
        // The gate is drained every tick (30s period) for as long as the job is
        // terminal. A gate that minted a decision per tick would bury the item in
        // questions nobody asked.
        final host = await _Host.completedWithoutVerdict(
          prose: _realReviewProse,
        );

        await host.drainGate();
        final first = await host.requireDecision();
        await host.drainGate();
        await host.drainGate();

        final all = await host.workflowStore.readHumanDecisionsForWorkItem(
          _Host.workItemId,
        );
        expect(all, hasLength(1));
        expect(all.single.decisionId, first.decisionId);
        expect(
          host.raisedCount,
          1,
          reason:
              'the gate returns early for an item already at '
              'waitingForHumanDecision, and DurableWorkflowEngine.'
              'requestHumanDecision independently returns the existing pending '
              'decision. Two layers, and the second one is not this lane\'s',
        );
      });

      test(
        'a producer identity is required, and its absence writes NOTHING',
        () async {
          // Fail closed. `actorIsNotSelf()` refuses a gate entry with no producer
          // identity, so raising here would THROW — and a throwing review gate
          // takes the whole `review` section of the tick down with it. What is
          // asserted is that the gate notices first, records why, and leaves the
          // absence durable on the reviewer's own timeline.
          final host = await _Host.completedWithoutVerdict(
            prose: _realReviewProse,
            producerActorId: null,
          );

          await host.drainGate();

          expect(
            await host.workflowStore.readHumanDecisionsForWorkItem(
              _Host.workItemId,
            ),
            isEmpty,
            reason:
                'a fabricated producer identity is the one thing never to do here',
          );
          expect(
            host.loggedEvents.map((l) => l.$1),
            contains('engineering-review-no-verdict-decision-no-producer'),
          );
          expect(
            (await host.executionStore.readEvents(
              _Host.reviewerExecutionId,
            )).where((e) => e.payload?['reviewGate'] == 'no_verdict'),
            isNotEmpty,
            reason:
                'and the absence is still durable where the operator can find it',
          );
        },
      );
    },
  );

  group('it asserts NO verdict — the anti-fabrication property', () {
    test(
      'a verdict-less decision carries no verdict on ANY reader-visible key',
      () async {
        final host = await _Host.completedWithoutVerdict(
          prose: _realReviewProse,
        );
        await host.drainGate();
        final decision = await host.requireDecision();

        expect(
          verdictAbsentDecisionCarriesAVerdict(decision),
          isFalse,
          reason:
              'the whole decision rests on this. `reviewVerdict` and '
              '`engineeringReviewResult` are the two keys every downstream '
              'reader treats as "a reviewer assessed this"; a recommendation '
              'reading like a token is the third place an operator is shown one',
        );
        expect(decision.metadata, isNot(contains('reviewVerdict')));
        expect(decision.metadata, isNot(contains('engineeringReviewResult')));
        expect(
          decision.recommendation,
          isNot(anyOf('APPROVE', 'CHANGES_REQUIRED')),
          reason:
              'this string is rendered to an operator under "WHAT WE SUGGEST". It '
              'is the one field of a decision most likely to be skimmed and '
              'misread, which is why it opens with the words NO VERDICT',
        );
        for (final wire in ReviewVerdict.values) {
          expect(decision.recommendation, isNot(wire.wire));
        }
        expect(decision.recommendation, verdictAbsentRecommendation);
      },
    );

    test(
      "prose that reads exactly like a verdict does not become one",
      () async {
        // The sharpest form of "no inferring a verdict from prose". This
        // reviewer said, in words, "Verdict: CHANGES_REQUIRED" — which is what
        // `agx-wx-jb-hn7gq1n2dc-1llxxyk` did on 2026-10-14 and what b1 refused
        // to invent. The ruling permits a decision that says no verdict was
        // parsed. It does NOT permit reading one out of English.
        const verdictShapedProse = '''
## Engineering Review

Verdict: CHANGES_REQUIRED

The diff introduces a retry loop with no bound. It must be capped.
''';
        final host = await _Host.completedWithoutVerdict(
          prose: verdictShapedProse,
        );

        await host.drainGate();

        final decision = await host.requireDecision();
        expect(
          verdictAbsentDecisionCarriesAVerdict(decision),
          isFalse,
          reason:
              'the parser is NOT relaxed. `structuredResult` is `{}` here, so '
              'there is no verdict to read, and the sentence in the summary is '
              'a reviewer\'s English, not a field this build parsed. Promoting '
              'it would be exactly the fabrication decision '
              'c495e02f-5c5d-4b45-8124-42ad0e90d6d4 forbids in its first line',
        );
        expect(
          decision.metadata![reviewVerdictAbsentMetadataKey]!['cause'],
          'verdict_absent',
        );
        expect(
          decision.question,
          contains('has NOT been read as a verdict'),
          reason:
              'and the question says so out loud, so an operator who has just '
              'read "Verdict: CHANGES_REQUIRED" in the quoted prose is not left '
              'to decide whether the platform agrees with it',
        );
      },
    );

    test('absence did not become `changes_required`', () async {
      final host = await _Host.completedWithoutVerdict(
        structuredResult: const {},
        prose: _realReviewProse,
      );
      await host.drainGate();
      final decision = await host.requireDecision();

      expect(
        decision.metadata![reviewVerdictAbsentMetadataKey]!['verdictRecorded'],
        isFalse,
      );
      expect(
        decision.recommendation,
        isNot('CHANGES_REQUIRED'),
      );
      expect(
        decision.question!.toLowerCase(),
        isNot(contains('review requires changes')),
        reason:
            'that is the exact sentence b1 removed, on items whose reviewers '
            'had timed out. The decision the gate raises now has to be unable '
            'to produce it at all',
      );
    });

    test(
      "'the review succeeded' did not become 'the review concluded'",
      () async {
        final host = await _Host.completedWithoutVerdict(
          prose: _realReviewProse,
        );
        await host.drainGate();
        final decision = await host.requireDecision();

        expect(
          decision.question,
          allOf(
            contains('ran to completion'),
            contains(
              'The review PROCESS succeeded; that is not the same as the '
              'review CONCLUDING anything.',
            ),
            contains('Nothing has been assessed on this work item.'),
          ),
          reason:
              'the fourth line of decision c495e02f forbids treating "the '
              'review succeeded" as "the review concluded", and the only place '
              'an operator learns what happened is this string. Every clause of '
              'it is asserted rather than described',
        );
      },
    );

    test(
      "the repository's OTHER, independent verdict reader agrees there is none",
      () async {
        // Two readers, written independently, answering the same question about
        // the same durable rows: the gate's `_readReviewVerdict` and
        // `readReviewVerdictProvenance` — which `repairUnreviewedReview` uses to
        // decide whether a decision may be discarded. If this decision were
        // resolvable as an assessment, the repair affordance would treat it as a
        // fabricated verdict and let an operator throw the review away; and if it
        // were discardable, it would be resolvable as one.
        final host = await _Host.completedWithoutVerdict(
          prose: _realReviewProse,
        );
        await host.drainGate();
        final decision = await host.requireDecision();

        final provenance = await readReviewVerdictProvenance(
          executionStore: host.executionStore,
          decision: decision,
        );

        expect(
          provenance.verdict,
          isNull,
          reason:
              'null NEVER means a stand-in verdict — see its own doc comment',
        );
        expect(
          provenance.assessment,
          ReviewAssessment.reviewerProseOnly,
          reason:
              'which is the honest classification: a reviewer wrote real prose '
              'and no machine-readable verdict. It is deliberately NOT '
              'repairable, so the operator is told to read the review and '
              'resolve the decision rather than being offered a button that '
              'discards a real assessment',
        );
        expect(provenance.assessment.isRepairable, isFalse);
      },
    );
  });

  group('it cannot be turned into a verdict afterwards', () {
    test(
      'only `rework` and `cancel` are offered, and neither asserts quality',
      () async {
        final host = await _Host.completedWithoutVerdict(
          prose: _realReviewProse,
        );
        await host.drainGate();
        final decision = await host.requireDecision();

        expect(
          decision.options!.map((o) => o.optionId),
          unorderedEquals(['rework', 'cancel']),
          reason:
              '`approve` routes to reviewApproved — the state that admits a '
              'change to the rest of the pipeline on a review nobody concluded — '
              'and `reject` routes to reviewRejected, which records a reviewer '
              'having rejected work for reasons no reviewer gave. Neither may be '
              'offered by a decision that says no verdict was produced',
        );
        expect(
          decision.options!.any((o) => o.recommended ?? false),
          isFalse,
        );
      },
    );

    test(
      'a crafted `approve` is REFUSED by the resolution path, and writes '
      'nothing',
      () async {
        // `WorkflowEndpoints.resolveDecision` takes a `choice` off the wire and
        // never checks it against the decision's own options, so "we did not
        // offer it" is a property of the SCREEN. This drives the production
        // resolution method and asserts the record is untouched afterwards.
        final host = await _Host.completedWithoutVerdict(
          prose: _realReviewProse,
        );
        await host.drainGate();
        final decision = await host.requireDecision();

        final service = _TestService(
          _FakeSession(),
          host.workflowStore,
          host.executionStore,
        );

        for (final choice in const [
          HumanDecisionChoice.approve,
          HumanDecisionChoice.reject,
        ]) {
          await expectLater(
            service.resolveHumanDecision(
              decisionId: decision.decisionId,
              choice: choice,
              decider: 'operator@example.com',
              rationale: 'looks right to me',
              signature: _signature,
            ),
            throwsA(isA<StateError>()),
            reason:
                '$choice is an ASSESSMENT. A decision that records no verdict '
                'cannot be resolved with one, however the request is built',
          );
        }

        final item = await host.workflowEngine.loadWorkItem(_Host.workItemId);
        expect(
          item.state,
          WorkItemState.waitingForHumanDecision,
          reason: 'nothing was written: the item has not moved',
        );
        expect(
          item.blockingHumanDecisionId,
          decision.decisionId,
        );
        expect(
          (await host.workflowStore.readHumanDecision(
            decision.decisionId,
          )).status,
          HumanDecisionStatus.pending,
          reason: 'and the decision is still pending, with no recorded choice',
        );
        expect(
          (await host.workflowStore.readHumanDecision(
            decision.decisionId,
          )).choice,
          isNull,
        );
      },
    );

    test(
      'a REAL review decision is unaffected by that refusal',
      () async {
        // The refusal is scoped on purpose. Widening it to "any choice must be
        // one of the decision's options" would change every lifecycle gate in
        // the platform; the decision asked for a narrower thing. This asserts
        // the narrower thing did not leak.
        final host = await _Host.completedWithVerdict(
          ReviewVerdict.approved.wire,
        );
        await host.drainGate();
        final decision = await host.requireDecision();

        final service = _TestService(
          _FakeSession(),
          host.workflowStore,
          host.executionStore,
        );

        final item = await service.resolveHumanDecision(
          decisionId: decision.decisionId,
          choice: HumanDecisionChoice.approve,
          decider: 'operator@example.com',
          rationale: 'reviewer said so',
          signature: _signature,
        );

        expect(item.state, WorkItemState.reviewApproved);
      },
    );
  });

  group('the operator acts and the item MOVES', () {
    test('`rework` sends it back to be built and reviewed again', () async {
      final host = await _Host.completedWithoutVerdict(prose: _realReviewProse);
      await host.drainGate();
      final decision = await host.requireDecision();

      final item = await host.workflowEngine.resolveHumanDecision(
        decisionId: decision.decisionId,
        choice: HumanDecisionChoice.rework,
        decider: 'operator@example.com',
        rationale:
            'The review wrote real findings in prose; have it done again.',
        signature: _signature,
      );

      expect(
        item.state,
        WorkItemState.implementationReady,
        reason:
            "engineeringReview/rework routes to implementationReady, the "
            "implementation lane's entry state. That IS the operator retry: the "
            'work runs again, a fresh producer stamps a fresh producerActorId, '
            'and the item reaches agent_completed ready for a review run under '
            "the Q1 prompt that tells the reviewer what to emit",
      );
      expect(item.blockingHumanDecisionId, isNull);
    });

    test('`cancel` stops it and keeps the record', () async {
      final host = await _Host.completedWithoutVerdict(prose: _realReviewProse);
      await host.drainGate();
      final decision = await host.requireDecision();

      final item = await host.workflowEngine.resolveHumanDecision(
        decisionId: decision.decisionId,
        choice: HumanDecisionChoice.cancel,
        decider: 'operator@example.com',
        rationale: 'Not pursuing this.',
        signature: _signature,
      );

      expect(item.state, WorkItemState.cancelled);
    });
  });

  group('distinguishable from a supersession STALL', () {
    test('the two decisions differ on every field a surface can render', () async {
      // Driven, not described. `DecisionView` carries `question`,
      // `recommendation`, `options` and NO metadata field at all — so if these
      // four disagree, no screen in this repository can render them as the same
      // question.
      final verdictAbsentHost = await _Host.completedWithoutVerdict(
        prose: _realReviewProse,
      );
      await verdictAbsentHost.drainGate();
      final verdictAbsent = await verdictAbsentHost.requireDecision();

      final stallHost = await _Host.stalled();
      await stallHost.raiseStall();
      final stall = await stallHost.requireDecision();

      // 1. The marker. Mutually exclusive on the record, from the row alone.
      expect(
        isVerdictAbsentDecision(stall),
        isFalse,
        reason: 'a supersession stall is not a verdict-less review',
      );
      expect(isVerdictAbsentDecision(verdictAbsent), isTrue);
      expect(stall.metadata, contains(stalledWorkItemMetadataKey));
      expect(stall.metadata, isNot(contains(reviewVerdictAbsentMetadataKey)));
      expect(verdictAbsent.metadata, contains(reviewVerdictAbsentMetadataKey));
      expect(
        verdictAbsent.metadata,
        isNot(contains(stalledWorkItemMetadataKey)),
      );

      // 2. The recommendation — the one line under "WHAT WE SUGGEST".
      expect(stall.recommendation, 'REWORK');
      expect(verdictAbsent.recommendation, isNot('REWORK'));
      expect(
        verdictAbsent.recommendation,
        startsWith('NO VERDICT'),
        reason:
            'a recommendation that begins with the words NO VERDICT cannot be '
            'skimmed as an assessment, and it cannot be confused with REWORK, '
            'which is what the stall carries and which on a review decision '
            'would read as "the reviewer asked for changes"',
      );

      // 3. The question's first sentence.
      expect(stall.question, startsWith('This work cannot make progress'));
      expect(
        verdictAbsent.question,
        isNot(contains('stopped automatically')),
        reason: 'the stall says the lane stopped launching; this one did not',
      );

      // 4. The option labels.
      expect(
        verdictAbsent.options!.map((o) => o.label),
        unorderedEquals([
          'Build it again and review it again',
          'Abandon this work item',
        ]),
      );
      expect(
        verdictAbsent.options!
            .map((o) => o.label)
            .toSet()
            .intersection(
              stall.options!.map((o) => o.label).toSet(),
            ),
        isEmpty,
        reason:
            'the two gates raise the SAME decision type — '
            'blockingHumanDecisionPendingOfType([engineeringReview]) admits no '
            'other from this state — so the labels are the last line of defence '
            'against an operator answering the wrong question',
      );

      // 5. The causes differ, and the record says which is which.
      expect(
        verdictAbsent.metadata![reviewVerdictAbsentMetadataKey]!['cause'],
        isA<String>(),
      );
      expect(
        stall.metadata![stalledWorkItemMetadataKey]!['deferrals'],
        isA<int>(),
        reason:
            'a stall always names how many deferrals it burned; a verdict-less '
            'review has no deferrals, because a deferral is the lane refusing '
            'to launch and this review DID launch',
      );
    });

    test('the operator ACTION differs, and both are the right one', () async {
      final verdictAbsentHost = await _Host.completedWithoutVerdict(
        prose: _realReviewProse,
      );
      await verdictAbsentHost.drainGate();
      final verdictAbsent = await verdictAbsentHost.requireDecision();

      final stallHost = await _Host.stalled();
      await stallHost.raiseStall();
      final stall = await stallHost.requireDecision();

      expect(
        verdictAbsent.question,
        contains('What the reviewer actually wrote follows'),
        reason:
            'the operator is told to read what the reviewer wrote. A stall has '
            'nothing to read — no execution ever started — so it cannot say '
            'that, and must not imply it',
      );
      expect(
        stall.question,
        isNot(contains('reviewer')),
        reason: 'there is no reviewer run behind a supersession stall',
      );
      expect(
        verdictAbsentHost.loggedEvents.map((l) => l.$1),
        isNot(contains('stall.parked')),
      );
    });
  });

  group('a review that did NOT finish is untouched', () {
    // The other half of b1, deliberately left exactly as it was. A timed-out or
    // crashed review still has `maxAttempts` owed to it, and
    // `Scheduler._returnOneToEntryState` returns the item to a lane entry state
    // to make the retry claimable — while `waitingForHumanDecision` is
    // explicitly SKIPPED by that return. Parking those items would pre-empt a
    // retry that is coming, which is the mirror image of the bug this decision
    // fixes.
    test(
      'a timed-out review still raises NOTHING and stays retryable',
      () async {
        final host = await _Host.notFinished(
          executionStatus: AgentSessionStatus.failed,
          executionReason: 'execution exceeded its 300s timeout budget',
        );

        await host.drainGate();

        expect(
          await host.workflowStore.readHumanDecisionsForWorkItem(
            _Host.workItemId,
          ),
          isEmpty,
        );
        final item = await host.workflowEngine.loadWorkItem(_Host.workItemId);
        expect(item.state, WorkItemState.reviewInProgress);
        expect(item.blockingHumanDecisionId, isNull);
        expect(
          host.raisedCount,
          0,
        );
      },
    );

    test(
      'the durable absence record says the review had NOT completed, so a '
      'reader cannot mistake this for a dropped item',
      () async {
        final host = await _Host.notFinished(
          executionStatus: AgentSessionStatus.failed,
          executionReason: 'execution exceeded its 300s timeout budget',
        );

        await host.drainGate();

        final recorded = (await host.executionStore.readEvents(
          _Host.reviewerExecutionId,
        )).where((e) => e.payload?['reviewGate'] == 'no_verdict').toList();
        expect(recorded, hasLength(1));
        expect(recorded.single.payload?['reviewCompleted'], isFalse);
        expect(
          host.loggedEvents
              .firstWhere((l) => l.$1 == 'engineering-review-gate-no-verdict')
              .$2['decision'],
          contains('maxAttempts'),
        );
      },
    );
  });

  // THE MEDIUM FINDING: `_recordNoVerdict` logged
  // `'raised a verdict-less engineering review decision: …'` BEFORE
  // `raiseVerdictAbsentDecision` ran, and that raise has three outcomes which
  // write nothing. So the line asserted a fact about a call whose result was not
  // yet known, and on those three paths it asserted something that did not
  // happen — the same false-state class this lane exists to end, one layer down.
  //
  // The fix moved the claim AFTER the raise and made it read the returned
  // outcome. These tests hold that on all FOUR outcomes, and the non-vacuity
  // test at the end proves the matcher can actually match: a negative assertion
  // over a string that never occurs would pass forever.
  group('the decision log states what the raise DID, on every outcome', () {
    /// The sentence the gate reports about the decision, read from the log line
    /// written AFTER the raise returned.
    String decisionSentence(_Host host) =>
        host.loggedEvents
                .firstWhere(
                  (l) => l.$1 == 'engineering-review-gate-no-verdict-decision',
                )
                .$2['decision']
            as String;

    String outcomeName(_Host host) =>
        host.loggedEvents
                .firstWhere(
                  (l) => l.$1 == 'engineering-review-gate-no-verdict-decision',
                )
                .$2['outcome']
            as String;

    /// The exact false claim the finding named. Matched as a whole phrase so a
    /// line may still use the word "raised" truthfully without tripping it.
    const falseClaim = 'raised a verdict-less engineering review decision';

    test('when the decision IS raised, the log says so', () async {
      final host = await _Host.completedWithoutVerdict(
        prose: _realReviewProse,
      );

      await host.drainGate();

      expect(outcomeName(host), 'raised');
      expect(decisionSentence(host), contains(falseClaim));
    });

    test(
      'alreadyPending: the log says NOT raised, and no line claims it',
      () async {
        final host = await _Host.completedWithoutVerdict(
          prose: _realReviewProse,
          parkedBetweenReads: true,
        );

        await host.drainGate();

        expect(outcomeName(host), 'alreadyPending');
        expect(decisionSentence(host), contains('not raised'));
        // Checked across EVERY line, not just the decision field: the pre-raise
        // record is where the false sentence used to live.
        expect(
          host.loggedEvents.map((l) => l.$2['decision'] ?? ''),
          isNot(contains(contains(falseClaim))),
          reason:
              'NO log line may claim a decision was raised when the raise '
              'returned alreadyPending and wrote nothing',
        );
        expect(
          await host.workflowStore.readHumanDecisionsForWorkItem(
            _Host.workItemId,
          ),
          isEmpty,
          reason: 'and the write-nothing claim has to be true as well',
        );
      },
    );

    test(
      'producerIdentityUnreadable: the log says NOT raised, and no line claims '
      'it',
      () async {
        final host = await _Host.completedWithoutVerdict(
          prose: _realReviewProse,
          producerActorId: null,
        );

        await host.drainGate();

        expect(outcomeName(host), 'producerIdentityUnreadable');
        expect(decisionSentence(host), contains('not raised'));
        expect(decisionSentence(host), contains('actorIsNotSelf()'));
        expect(
          host.loggedEvents.map((l) => l.$2['decision'] ?? ''),
          isNot(contains(contains(falseClaim))),
        );
        expect(
          await host.workflowStore.readHumanDecisionsForWorkItem(
            _Host.workItemId,
          ),
          isEmpty,
        );
      },
    );

    test('refused: the log says NOT raised, and no line claims it', () async {
      // A REAL refusal, not a stub: the producer identity is the orchestrator's
      // own actor id, so `actorIsNotSelf()` — which
      // `reviewInProgress -> waitingForHumanDecision` carries — rejects the
      // entry exactly as it would for a mis-stamped producer id in production.
      final host = await _Host.completedWithoutVerdict(
        prose: _realReviewProse,
        producerActorId: 'orchestrator',
      );

      await host.drainGate();

      expect(outcomeName(host), 'refused');
      expect(decisionSentence(host), contains('not raised'));
      expect(
        host.loggedEvents.map((l) => l.$2['decision'] ?? ''),
        isNot(contains(contains(falseClaim))),
      );
      expect(
        await host.workflowStore.readHumanDecisionsForWorkItem(
          _Host.workItemId,
        ),
        isEmpty,
      );
    });

    test('a review that did NOT finish still claims nothing either', () async {
      // The pre-existing assertion, kept: `maxAttempts` is still owed a retry.
      final host = await _Host.notFinished(
        executionStatus: AgentSessionStatus.failed,
        executionReason: 'execution exceeded its 300s timeout budget',
      );

      await host.drainGate();

      expect(
        host.loggedEvents
            .firstWhere((l) => l.$1 == 'engineering-review-gate-no-verdict')
            .$2['decision'],
        contains('maxAttempts'),
      );
      expect(
        host.loggedEvents.map((l) => l.$2['decision'] ?? ''),
        isNot(contains(contains(falseClaim))),
      );
    });

    test(
      'NON-VACUITY: the matcher matches on the raised path, and the four '
      'outcomes produce four DIFFERENT sentences',
      () async {
        // Without this, every negative assertion above would also pass if
        // `verdictAbsentDecisionSentence` returned one constant string for all
        // four outcomes — including the raised one.
        final raised = await _Host.completedWithoutVerdict(
          prose: _realReviewProse,
        );
        await raised.drainGate();

        final alreadyPending = await _Host.completedWithoutVerdict(
          prose: _realReviewProse,
          parkedBetweenReads: true,
        );
        await alreadyPending.drainGate();

        final unreadable = await _Host.completedWithoutVerdict(
          prose: _realReviewProse,
          producerActorId: null,
        );
        await unreadable.drainGate();

        final refused = await _Host.completedWithoutVerdict(
          prose: _realReviewProse,
          producerActorId: 'orchestrator',
        );
        await refused.drainGate();

        final sentences = [
          decisionSentence(raised),
          decisionSentence(alreadyPending),
          decisionSentence(unreadable),
          decisionSentence(refused),
        ];

        expect(sentences.toSet(), hasLength(4));
        expect(sentences.where((s) => s.contains(falseClaim)), hasLength(1));
        expect(sentences.where((s) => s.contains('not raised')), hasLength(3));
      },
    );
  });
}

/// Verbatim from the QA record on 2026-10-14, trimmed. This is what a real
/// reviewer wrote when it emitted no verdict, and it is the reason the decision
/// carries prose: the review happened, it was specific, and telling an operator
/// "nothing happened" would be its own lie.
const _realReviewProse = '''
## Engineering Review

I read the diff on `18ad90a` (+957/-199) and checked the three claims it makes.

1. The `_DesktopSkeletonRow` widget is given a column count of 5 while the
   header row reserves 6. At the 1280px breakpoint the trailing cell wraps and
   the row height changes by 4px, so every row below it is offset. This is a
   blocking layout defect and it is visible in the attached screenshot.

2. `packages/scheduler/lib/src/scheduler.dart` charges a supersession deferral
   per tick rather than per job, so an item that is genuinely shuttling between
   states reaches the cap and stalls while healthy. There is a test for the
   opposite reading in `supersession_requeue_test.dart`; the two contradict.

3. The migration `20261014210000000` is additive. I confirmed no column is
   dropped and no NOT NULL is added to a populated table.

I could not finish verifying the retry-return edge before the budget ran out.
''';

/// Whether [decision] asserts a verdict anywhere.
///
/// The single predicate every anti-fabrication test in this file leans on, and
/// deliberately STRICTER than "the recommendation does not say APPROVE": it
/// walks every place a reader could take a verdict from, because "it is only in
/// the recommendation" is exactly the shape that survives review.
bool verdictAbsentDecisionCarriesAVerdict(HumanDecision decision) {
  final metadata = decision.metadata ?? const <String, dynamic>{};
  if (metadata.containsKey('reviewVerdict')) return true;
  if (metadata.containsKey('engineeringReviewResult')) return true;
  if (metadata.containsKey('findings')) return true;

  final recommendation = decision.recommendation ?? '';
  if (ReviewVerdict.values.any((v) => recommendation == v.wire)) return true;
  if (recommendation == 'APPROVE' || recommendation == 'CHANGES_REQUIRED') {
    return true;
  }
  return false;
}

final _signature = DecisionSignature(
  algorithm: 'test',
  publicKey: 'test',
  signature: 'test',
  signedAt: DateTime.utc(2026, 10, 15, 12),
);

/// A real-by-construction host: real [DurableWorkflowEngine], real
/// [InMemoryWorkflowStore], real [InMemoryExecutionStore], and a real
/// [JobQueue]-minted [Job], so `attempt`/`maxAttempts` are
/// [engineeringReviewDefinition]'s rather than literals written here.
class _Host {
  _Host._({
    required this.workflowStore,
    required this.workflowEngine,
    required this.executionStore,
    required this.jobStore,
    required this.job,
    required this.loggedEvents,
  });

  static const workItemId = 'wi-no-verdict';
  static const reviewerExecutionId = 'agx-wx-review';
  static const producerExecutionId = 'agx-wx-impl';
  static final _now = DateTime.utc(2026, 10, 15, 12);

  static Future<_Host> _base({
    String? producerActorId,
    bool parkedBetweenReads = false,
  }) async {
    final workflowStore = InMemoryWorkflowStore();
    final jobStore = InMemoryJobStore();
    await workflowStore.saveWorkItem(
      WorkItem(
        workItemId: workItemId,
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'A change nobody could review',
        description: 'The implementer committed; the review said nothing.',
        state: WorkItemState.reviewInProgress,
        metadata: {
          if (producerActorId != null) 'producerActorId': producerActorId,
        },
        createdAt: _now,
        updatedAt: _now,
      ),
    );

    final enqueued = await JobQueue(store: jobStore).enqueueIfAbsent(
      workItemId: workItemId,
      definition: engineeringReviewDefinition,
      dedupeKey: '$workItemId:engineering_review:a0',
      instruction: 'Review the implementation.',
    );
    final job = enqueued.job.copyWith(
      state: JobState.succeeded,
      executionReference: JobExecutionReference(
        workerExecutionId: 'wx-review',
        agentExecutionId: reviewerExecutionId,
        createdAt: _now,
      ),
    );
    await jobStore.saveJob(job);

    // Only the ENGINE sees the decorator. `workflowStore` stays the real
    // in-memory store, so assertions in these tests read what was actually
    // persisted rather than what the decorator answered.
    final engineStore = parkedBetweenReads
        ? _ParkedBetweenReads(workflowStore)
        : workflowStore;

    return _Host._(
      workflowStore: workflowStore,
      workflowEngine: DurableWorkflowEngine(store: engineStore),
      executionStore: InMemoryExecutionStore(),
      jobStore: jobStore,
      job: job,
      loggedEvents: <(String, Map<String, dynamic>)>[],
    );
  }

  /// A reviewer that reached `completed` — the four parked items' shape.
  static Future<_Host> completedWithoutVerdict({
    required String prose,
    Map<String, dynamic> structuredResult = const {},
    String? producerActorId = producerExecutionId,
    bool parkedBetweenReads = false,
  }) async {
    final host = await _base(
      producerActorId: producerActorId,
      parkedBetweenReads: parkedBetweenReads,
    );
    await host._saveExecution(AgentSessionStatus.completed, null);
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
          durationMs: 160000,
          toolCalls: 41,
          errors: const [],
          warnings: const [],
        ),
        structuredResult: structuredResult,
        summary: prose,
        completedAt: _now,
      ),
    );
    return host;
  }

  static Future<_Host> completedWithVerdict(String verdictWire) async {
    return completedWithoutVerdict(
      prose: 'Reviewed. Returning a verdict.',
      structuredResult: {'verdict': verdictWire},
    );
  }

  /// A reviewer that did NOT finish — a budget kill, a crash.
  static Future<_Host> notFinished({
    required AgentSessionStatus executionStatus,
    required String? executionReason,
  }) async {
    final host = await _base();
    await host._saveExecution(executionStatus, executionReason);
    return host;
  }

  /// A work item the scheduler refused to launch at all, for the stall
  /// comparison. Parked through `raiseStallDecision` — b8's own path, not a
  /// hand-built decision.
  static Future<_Host> stalled() async {
    final host = await _base();
    await host._saveExecution(AgentSessionStatus.completed, null);
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
          durationMs: 1,
          toolCalls: 0,
          errors: const [],
          warnings: const [],
        ),
        structuredResult: const {},
        summary: '',
        completedAt: _now,
      ),
    );
    return host;
  }

  Future<void> _saveExecution(
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
          startingRevision: '18ad90a',
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
  final InMemoryJobStore jobStore;
  final Job job;
  final List<(String, Map<String, dynamic>)> loggedEvents;

  /// How many times this host's drains said a decision was raised.
  int get raisedCount => loggedEvents
      .where(
        (l) =>
            l.$1 == 'engineering-review-no-verdict-decision-raised' ||
            l.$1 == 'stall.parked',
      )
      .length;

  Future<void> drainGate() => engineeringReviewTickHandler(
    workflowEngine: workflowEngine,
    executionStore: executionStore,
    logger: (message, context) => loggedEvents.add((message, context)),
  )(job);

  /// Raises b8's supersession stall on this item, through its own gate.
  ///
  /// Driven rather than hand-built: a decision assembled in a test would prove
  /// only that a test can tell two objects apart, which is true of any two
  /// literals. This is what the platform actually writes when the scheduler
  /// stops launching, compared against what this gate actually writes.
  Future<void> raiseStall() => raiseStallDecision(
    workflowEngine: workflowEngine,
    executionStore: executionStore,
    stall: SchedulerStall(
      workItemId: workItemId,
      state: WorkItemState.reviewInProgress,
      jobType: JobType.engineeringReview,
      deferrals: 3,
      reason:
          'work item $workItemId is review_in_progress and this lane has '
          'already deferred it 3 times without one execution ever starting, so '
          'it stopped launching instead of spinning. Nothing was consumed and no '
          'attempt was spent.',
    ),
    logger: (message, context) => loggedEvents.add((message, context)),
  );

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
}

/// [ControlPlaneService] with its durable substrate substituted, so the
/// production [ControlPlaneService.resolveHumanDecision] runs for real. The same
/// shape `review_repair_action_test.dart` uses.
class _TestService extends ControlPlaneService {
  _TestService(super.session, this._store, this._executions);

  final WorkflowStore _store;
  final ExecutionStore _executions;

  @override
  WorkflowStore get workflowStore => _store;

  @override
  ExecutionStore get executionStore => _executions;

  @override
  DurableWorkflowEngine get workflowEngine =>
      DurableWorkflowEngine(store: _store);
}

class _FakeSession implements Session {
  final List<String> logs = [];

  @override
  void log(
    String message, {
    LogLevel? level,
    dynamic exception,
    StackTrace? stackTrace,
  }) {
    logs.add(message);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Session.${invocation.memberName} is not used here',
  );
}

/// Answers the SECOND and later `readWorkItem` calls with an item already parked
/// behind a pending decision, and delegates everything else unchanged.
///
/// This is the race `raiseVerdictAbsentDecision`'s `alreadyPending` branch exists
/// for: the gate has already read the item at `review_in_progress` and recorded
/// the absence, and by the time the raise re-reads the item something else has
/// parked it. It cannot be simulated by parking the item up front — the gate
/// returns early for an item already at `waitingForHumanDecision`, so the branch
/// would never be reached and the assertion would be vacuous.
class _ParkedBetweenReads implements WorkflowStore {
  _ParkedBetweenReads(this._inner);

  final WorkflowStore _inner;
  int _reads = 0;

  @override
  Future<WorkItem> readWorkItem(String workItemId) async {
    final item = await _inner.readWorkItem(workItemId);
    _reads++;
    if (_reads < 2) return item;
    return item.copyWith(
      state: WorkItemState.waitingForHumanDecision,
      blockingHumanDecisionId: 'dec-parked-by-something-else',
    );
  }

  @override
  Future<List<WorkItem>> readAllWorkItems() => _inner.readAllWorkItems();

  @override
  Future<void> saveWorkItem(WorkItem item, {int? expectedVersion}) =>
      _inner.saveWorkItem(item, expectedVersion: expectedVersion);

  @override
  Future<HumanDecision> readHumanDecision(String decisionId) =>
      _inner.readHumanDecision(decisionId);

  @override
  Future<List<HumanDecision>> readHumanDecisionsForWorkItem(
    String workItemId,
  ) => _inner.readHumanDecisionsForWorkItem(workItemId);

  @override
  Future<void> saveHumanDecision(HumanDecision decision) =>
      _inner.saveHumanDecision(decision);

  @override
  Future<List<WorkflowTransitionRecord>> readTransitionHistory(
    String workItemId,
  ) => _inner.readTransitionHistory(workItemId);

  @override
  Future<WorkflowTransitionRecord?> findTransitionByIdempotencyKey(
    String workItemId,
    String idempotencyKey,
  ) => _inner.findTransitionByIdempotencyKey(workItemId, idempotencyKey);

  @override
  Future<void> appendTransitionRecord(WorkflowTransitionRecord record) =>
      _inner.appendTransitionRecord(record);

  @override
  Future<void> appendOperatorAction(OperatorActionRecord record) =>
      _inner.appendOperatorAction(record);

  @override
  Future<List<OperatorActionRecord>> readOperatorActionsForWorkItem(
    String workItemId,
  ) => _inner.readOperatorActionsForWorkItem(workItemId);

  @override
  Future<T> inTransaction<T>(Future<T> Function(WorkflowStore store) body) =>
      _inner.inTransaction(body);
}
