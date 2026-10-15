import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'package:control_plane_server/src/review/engineering_review_gate.dart';

/// ## WHAT THIS FILE EXISTS TO PROVE
///
/// **A reviewer that produced no verdict must never become a human decision.**
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
/// `reviewInProgress`, with no `blockingHumanDecisionId`. Not "left alone" in
/// the abstract: a decision is the item's only one-way exit out of review, so
/// the absence of one is the assertion that the retry path still exists. The
/// gate does not create, reset or duplicate a retry — the reviewer job's own
/// bounded `maxAttempts` is the mechanism, and `a reviewer job whose budget is
/// untouched by a no-verdict gate` asserts that contract holds.
void main() {
  group('no verdict means no decision — the three fabrication sites', () {
    test(
      'SITE 1: a reviewer result carrying no verdict at all raises NOTHING',
      () async {
        // The live case, verbatim: `end_turn` at 131s/160s, 2000 bytes of
        // markdown in `summary`, `{}` in `structuredResultJson`.
        //
        // The pre-fix gate read `verdictWire` (default `changes_required`) out
        // of this empty map and raised "engineering review requires changes".
        final host = await _GateHost.reviewerResult(
          structuredResult: const {},
          summary:
              '## Engineering review\n\nThe diff adds a retry loop...\n\n'
              'Findings: none blocking.',
        );

        await host.drainGate();

        await host.expectNoDecisionRaised(
          reason:
              'a reviewer that answered in prose and emitted no structured '
              'verdict was assessed by nobody. `changes_required` here was '
              'invented by the default at the top of the read.',
        );
        expect(host.absenceCauses, ['verdict_absent']);
      },
    );

    test('SITE 2: an UNREADABLE verdict wire is not a review verdict', () async {
      // The site that is easy to miss, because it reads like a parse fallback
      // and a parse fallback returning a conservative default is a normal
      // thing to see. It is not one here: `'CHANGES_REQUIRED'` is a string this
      // build does not recognise as a verdict, and the reviewer wrote it. The
      // pre-fix gate reported it to an operator as a reviewer having found
      // problems.
      //
      // Several spellings, because any of them reaching an operator as
      // "the reviewer found problems" is the same fabrication.
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

        await host.expectNoDecisionRaised(
          reason:
              "'$wire' is not one of ReviewVerdict's four wire values. Reading "
              'it as `changes_required` asserts a finding no reviewer made.',
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
    });

    test('SITE 3: no reviewer result at all raises NOTHING', () async {
      // The live timeout case, verbatim: the execution reached `failed` at
      // exactly 300s with the coordinator's budget reason and the coordinator's
      // own fallback result never landed in the store.
      final host = await _GateHost.noResult(
        executionStatus: AgentSessionStatus.failed,
        executionReason:
            'execution exceeded its 300s timeout budget without reaching a '
            'terminal agent event',
      );

      await host.drainGate();

      await host.expectNoDecisionRaised(
        reason:
            'no reviewer ran to completion, so there is no assessment. The '
            'pre-fix gate built an EngineeringReviewResult with '
            '`findings: const []` and verdict `changesRequired`, which is an '
            'invented verdict AND an invented empty findings list.',
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

        expect(host.job.attempt, 1);
        expect(
          host.job.maxAttempts,
          engineeringReviewDefinition.maxAttempts,
          reason: 'the budget is the definition\'s, not the gate\'s',
        );
        expect(host.job.failure, isNull);

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
  static Future<_GateHost> _base() async {
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
      state: JobState.succeeded,
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
      jobStore: jobStore,
      job: job,
      loggedEvents: <Map<String, dynamic>>[],
    );
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

  /// A reviewer that produced NO result — the 300s budget case.
  static Future<_GateHost> noResult({
    required AgentSessionStatus executionStatus,
    required String? executionReason,
  }) async {
    final host = await _base();
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
  final InMemoryJobStore jobStore;
  final Job job;
  final List<Map<String, dynamic>> loggedEvents;

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

  /// The central assertion: no decision, and the item still retryable.
  Future<void> expectNoDecisionRaised({String? reason}) async {
    final decisions = await workflowStore.readHumanDecisionsForWorkItem(
      workItemId,
    );
    expect(
      decisions,
      isEmpty,
      reason:
          reason ??
          'an engineeringReview decision exists for a review that never '
              'happened',
    );
    final item = await workflowEngine.loadWorkItem(workItemId);
    expect(
      item.state,
      WorkItemState.reviewInProgress,
      reason: 'the item must stay where the retry path can still reach it',
    );
    expect(item.blockingHumanDecisionId, isNull);
  }
}
