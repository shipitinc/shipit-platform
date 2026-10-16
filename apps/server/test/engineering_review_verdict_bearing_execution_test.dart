/// The two defects the previous correction shipped green and did not fix.
///
/// `5ca2acb` added `redriveSettledReviews`, and its tests passed. Deployed to QA
/// at main `b8feffe`, one tick after boot:
///
/// ```text
/// [engineering-review-settled-redrive] {considered: 18, redriven: 0,
///                                       alreadyConsumed: 0, failed: 7}
/// [engineering-review-verdict-absent-routed]  x7   route: re_review
/// [engineering-review-gate-no-verdict]       x7
/// [engineering-review-settled-redrive-not-marked] x7
///     error: DatabaseQueryException: duplicate key value violates unique
///            constraint "agent_event_execution_sequence_unique"
/// ```
///
/// ## WHY THE PREVIOUS TESTS WERE GREEN AND THE STACK WAS NOT
///
/// Both previous tests fail to touch either defect, and for a reason worth
/// recording rather than merely fixing:
///
///  * **The marker collision was invisible** because every fixture used
///    `InMemoryExecutionStore`, whose `appendEvent` keys on `eventId` and
///    enforces NOTHING about `(executionId, sequence)`. The constraint that
///    actually rejects the write exists only in Postgres
///    (`agent_event_execution_sequence_unique`). A fixture that cannot express
///    the production constraint cannot fail on it — so the test measured the
///    mechanism the lane had built and not the table it writes into. Every store
///    below therefore enforces that index, so this defect is expressible at all.
///  * **The wrong-execution read was invisible** because every fixture pointed
///    the job at the very execution that produced the verdict. That is the one
///    arrangement under which `job.executionReference?.agentExecutionId`
///    happens to be the right answer.
///
/// ## WHAT EACH TEST HERE IS RED ON
///
/// At `e386909` — before this correction — every test in this file fails, and
/// four of them fail for a behavioural reason:
///
///  * `a verdict on a PRIOR reviewer execution is raised…` and
///    `the reviewer's job was retired BEFORE the verdict existed…` fail on the
///    item still sitting at `review_in_progress` with a readable
///    `changes_required` on it. That is the reported symptom.
///  * `the marker persists…` fails on the recorded unique-index violation, and
///    `the bound HOLDS across six ticks…` fails on a marker count of zero. That
///    is the second reported defect.
///  * `no verdict is fabricated when there is none anywhere` fails for a
///    WEAKER reason, and it is recorded here rather than dressed up: at
///    `e386909` the gate's decline line carried no statement at all about
///    whether it held a verdict, so a log line an operator reads had nothing to
///    rule a verdict out. That is a b1 property this correction adds to the
///    line, not a behavioural difference — its value is that it now FAILS if a
///    future scan starts settling for "a reviewer ran".
///
/// The two REVERT probes at the bottom of this header say which test catches
/// which half of the fix, which is the question that decides whether these tests
/// are testing the fix or the mechanism.
///
/// ## REVERT PROBE 1 — `job.executionReference?.agentExecutionId`
///
/// Run, not asserted: deleting the scan from `resolveReviewSubject`, so the
/// gate resolves the job's execution and nothing else, fails exactly
/// `a verdict on a PRIOR reviewer execution is raised, even though the job the
/// gate is handed points at a different, unfinished reviewer` and
/// `the reviewer's job was retired BEFORE the verdict existed, and the verdict
/// still reaches a person`. Nothing else in this file does — every other fixture
/// either has no verdict anywhere, or points the job at the verdict-bearing
/// execution. The three marker and no-fabrication tests still pass under this
/// revert, which is correct: they are about the marker's write, not about which
/// execution is read.
///
/// ## REVERT PROBE 2 — the marker write as it was at `e386909`
///
/// Run, not asserted: restoring the stale pre-handler snapshot and the
/// timestamped event id fails exactly `the marker persists: the write collides
/// with nothing and loses nothing` and `the bound HOLDS across six ticks,
/// counted`, on the recorded unique-index violation and on a marker count of
/// zero. The two verdict-resolution tests still pass under this revert.
///
/// A third variant was measured and is why the fix is a reserved namespace and
/// not a fresh read: allocating `max + 1` from a read taken IMMEDIATELY before
/// the write does not collide, because the handler's append is already visible.
/// It fails this file's `the marker persists` test only on the sequence
/// namespace assertion — and it would keep passing on a quiet stack while two
/// review ticks overlapped, since both would read the same `max`. A bound that
/// holds until two writers arrive is not a bound.
///
/// ## AND WHAT IS ASSERTED HERE FOR THE SAKE OF LATER EDITS
///
/// `no verdict is fabricated when there is none anywhere` is mostly a guard
/// against THIS correction inventing something rather than against the previous
/// one. It is kept non-vacuous by driving the replacement-reviewer shape — the
/// one that makes a scan tempting — and by counting what was written: markers,
/// resolutions, decisions and verdict-shaped log values, each measured rather
/// than inferred from the absence of an exception.
library;

import 'package:control_plane_server/server.dart';
import 'package:control_plane_server/src/review/engineering_review_gate.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';
import 'package:workflow_store/workflow_store.dart';

void main() {
  group('the verdict on the review execution, not the one the job names', () {
    test(
      'a verdict on a PRIOR reviewer execution is raised, even though the job '
      'the gate is handed points at a different, unfinished reviewer',
      () async {
        final host = await _Host.started();

        // THE EXACT SHAPE FROM QA. `defect-DEF-1791684804452198` concluded at
        // 20:02:28 and its verdict is readable; the job the gate is handed is a
        // replacement whose execution is still running.
        await host.armTheReplacementReview();
        await host.settleReviewerOneWithTheLiveVerdict();
        await host.settleTheReplacementJob();

        final before = await host.item;
        expect(before.state, WorkItemState.reviewInProgress);
        expect(
          before.blockingHumanDecisionId,
          isNull,
          reason:
              'the reported symptom, asserted first so nothing below can be '
              'satisfied by an item that was already parked',
        );

        final result = await host.runReviewSection();

        // 1. THE VERDICT REACHED A PERSON.
        final parked = await host.item;
        expect(
          parked.state,
          WorkItemState.waitingForHumanDecision,
          reason:
              'at e386909 the gate reads job.executionReference — reviewer TWO, '
              'which is still running and has no result — finds no verdict, and '
              'leaves the item at review_in_progress with a real changes_required '
              'sitting unread on reviewer one',
        );

        final decision = await host.workflowStore.readHumanDecision(
          parked.blockingHumanDecisionId!,
        );

        // 2. IT CARRIES THE REVIEWER'S VERDICT, read back from that reviewer's
        //    own result. Not a constant, not a default, not the wire value of a
        //    verdict nobody produced.
        final reviewerResult = await host.executionStore.readResult(
          _Host.reviewerOneId,
        );
        expect(
          reviewerResult?.structuredResult['verdict'],
          _Host.verdictWire,
          reason:
              'the fixture, asserted so the comparison below cannot be '
              'satisfied by two wrong values agreeing',
        );
        expect(
          decision.metadata?['reviewVerdict'],
          reviewerResult?.structuredResult['verdict'],
        );
        expect(decision.metadata?['engineeringReviewResult'], isNotNull);
        expect(
          decision.options?.map((o) => o.optionId).toList(),
          ['approve', 'reject', 'rework'],
          reason:
              'this IS a verdict, so unlike the verdict-LESS decision it may '
              'offer approval and rejection',
        );

        // 3. AND IT NAMES THE EXECUTION THAT PRODUCED IT — the sharpest single
        //    assertion in this file. Reviewer TWO is the job's execution and is
        //    still running; it produced nothing and is named nowhere.
        expect(
          decision.metadata?['reviewExecutionId'],
          _Host.reviewerOneId,
          reason:
              'the decision must attribute the verdict to the execution that '
              'wrote it. At e386909 this is reviewer two, which never concluded',
        );
        // 4. THE RAISE ATTRIBUTED ITSELF TO THE REVIEWER, not to the implementer
        //    and not to a constant — which is what `actorIsNotSelf()` checks, and
        //    the implementer's id is on the item precisely because it is the
        //    OTHER side of that guard.
        final records = await host.workflowStore.readTransitionHistory(
          _Host.workItemId,
        );
        final raised = records.lastWhere(
          (r) => r.toState == WorkItemState.waitingForHumanDecision,
        );
        expect(raised.actorType, ActorType.engineeringReviewer);
        expect(raised.actorId, _Host.reviewerOneId);
        expect(
          (await host.executionStore.readExecution(_Host.reviewerTwoId)).status,
          AgentSessionStatus.running,
          reason:
              'and reviewer two is untouched — the gate resolved PAST it rather '
              'than acting on it, so a live reviewer is not disturbed',
        );
        expect(
          {
            for (final g in raised.guardEvaluations) g.guardName: g.passed,
          }['actor_not_self'],
          isTrue,
          reason:
              'two real, independent execution ids — which is the property a '
              'literal fallback there would have made vacuous',
        );
        expect(
          parked.metadata?['producerActorId'],
          _Host.producerExecutionId,
          reason:
              'the IMPLEMENTER\'s execution. It is on the item because the guard '
              'needs it, and it is not on the decision — which is why it could '
              'never have been the answer to "which reviewer concluded"',
        );

        // 5. EXACT COUNTS. One decision, from one tick.
        expect(
          await host.workflowStore.readHumanDecisionsForWorkItem(
            _Host.workItemId,
          ),
          hasLength(1),
        );
        expect(result.settledRedrive.redrivenJobIds, hasLength(1));
      },
    );

    test(
      'the reviewer\'s job was retired BEFORE the verdict existed, and the '
      'verdict still reaches a person',
      () async {
        // THE ORDERING THAT PRODUCED THE ORIGINAL FAILURE, produced by the real
        // scheduler rather than by hand-writing an already-broken job.
        //
        // Tick 1: reviewer one is `running` on a job whose claim nothing renews
        // and which is older than the staleness bound, so
        // `Scheduler._reclaimZombie` settles that JOB terminal while the
        // reviewer is still open. The drain hands it to the gate, which correctly
        // declines — there is no verdict and nothing settled to adjudicate. That
        // job is now terminal and will never be handed to the gate again.
        final host = await _Host.started();
        await host.runReviewSection();
        expect(
          host.jobsNamed('engineering-review-gate-execution-not-terminal'),
          1,
          reason:
              'the drain DID reach the gate on tick 1 and it DID decline, '
              'because a reviewer that has not finished has no verdict to read',
        );
        expect((await host.item).blockingHumanDecisionId, isNull);

        // THEN: the reviewer concludes, and the platform arms a replacement
        // review behind it. That replacement is what the terminal job will
        // eventually name.
        await host.settleReviewerOneWithTheLiveVerdict();
        await host.armTheReplacementReview();

        // Tick 2. The replacement's job is reclaimed terminal by the same
        // machinery, so it is handed to the gate while its reviewer is STILL
        // RUNNING. At e386909 that is the whole failure: the gate reads the
        // running replacement, finds no verdict, and discards the job forever —
        // and the sweep cannot rescue it either, because the sweep filtered on
        // that same job-relative execution and skipped it as "not settled".
        await host.runReviewSection();

        final parked = await host.item;
        expect(
          parked.state,
          WorkItemState.waitingForHumanDecision,
          reason:
              'the verdict exists and is parseable on a settled reviewer of this '
              'item, and nothing acted on it. At e386909 the item is still at '
              'review_in_progress with blockingHumanDecisionId NULL',
        );
        final decision = await host.workflowStore.readHumanDecision(
          parked.blockingHumanDecisionId!,
        );
        expect(decision.metadata?['reviewVerdict'], _Host.verdictWire);
        expect(
          decision.metadata?['reviewExecutionId'],
          _Host.reviewerOneId,
        );
        expect(
          host.jobsNamed('engineering-review-gate-verdict-bearing-execution'),
          greaterThanOrEqualTo(1),
          reason:
              'the gate says out loud that it read a verdict off an execution the '
              'job does not reference. Without that line, a decision whose '
              'reviewExecutionId matches no job the operator can find is '
              'unexplainable from the logs alone',
        );
        expect(
          await host.workflowStore.readHumanDecisionsForWorkItem(
            _Host.workItemId,
          ),
          hasLength(1),
          reason:
              'the drain and the sweep both run in this tick and both can see the '
              'same terminal job. The raise is guarded, so exactly one question '
              'is asked — counted, not assumed',
        );
      },
    );
  });

  group('the consumption marker actually persists', () {
    test(
      'the marker persists: the write collides with nothing and loses nothing',
      () async {
        // THE SCENARIO, MADE EXPRESSIBLE. `_recordNoVerdict` appends to this
        // execution's own timeline while the re-drive is running. At e386909 the
        // marker was then allocated from a snapshot read BEFORE that append, so
        // it asked for a sequence the append had just taken.
        //
        // The store below enforces `agent_event_execution_sequence_unique`
        // exactly as Postgres does, so this is the shape that threw on QA and
        // the shape no in-memory fixture can express.
        final host = await _Host.started();

        // Settle the replacement's job with a reviewer that concluded NOTHING,
        // which is the live log line
        // `[engineering-review-verdict-absent-routed] route: re_review` — and is
        // the only path on which the handler appends to the timeline the marker
        // then writes to.
        await host.settleReviewerTwoWithoutAVerdict();
        await host.settleTheReplacementJob();

        await host.runReviewSection();

        // 1. NO CONSTRAINT VIOLATION AT ALL, counted on the store rather than
        //    inferred from the absence of an exception: the gate catches write
        //    faults and logs them, so a test that only checked "it did not
        //    throw" would pass on the defect that was reported.
        expect(
          host.executionStore.constraintViolations,
          isEmpty,
          reason:
              'a second DatabaseQueryException on this path is a BLOCKER. At '
              'e386909 this is exactly '
              '[engineering-review-settled-redrive-not-marked] x7 with '
              'duplicate key value violates unique constraint '
              '"agent_event_execution_sequence_unique"',
        );

        // 2. THE MARKER IS THERE. Not "the pass reported no failure" — the row.
        expect(
          await host.markerCountOn(_Host.reviewerTwoId),
          1,
          reason:
              'at e386909 this is 0, because every marker write collided and '
              'the bound never advanced',
        );

        // 3. THE APPEND THE HANDLER MADE COEXISTS WITH IT, on one timeline.
        expect(
          await host.noVerdictCountOn(_Host.reviewerTwoId),
          1,
          reason:
              'the absence record the handler wrote. It and the marker share the '
              '(executionId, sequence) space, which is the collision — so both '
              'being present is the assertion that the space is no longer shared',
        );
        final events = await host.executionStore.readEvents(
          _Host.reviewerTwoId,
        );
        expect(
          events.map((e) => e.sequence).toSet(),
          hasLength(events.length),
          reason:
              'every row on this timeline holds a distinct sequence, which is '
              'what the unique index guarantees and what the old allocation broke',
        );

        // 4. THE MARKER'S SEQUENCE IS OUTSIDE EVERY OTHER ALLOCATOR'S RANGE.
        final marker = events.firstWhere(
          (e) => e.payload?['reviewGateConsumed'] != null,
        );
        expect(
          marker.sequence,
          lessThan(0),
          reason:
              'every other writer of agent_event allocates from 1 upwards '
              '(ExecutionCoordinator._nextSequence is an in-process counter over '
              '0; _recordNoVerdict is max(prior)+1 over a floor of 0), so a '
              'negative sequence is not "unlikely to be taken" but not '
              'producible by any of them',
        );
        expect(
          marker.eventId,
          'review-gate-consumed-${_Host.reviewerTwoId}',
          reason:
              'deterministic, so a retry collides on agent_event_id_unique rather '
              'than appending a second marker under a fresh timestamp',
        );

        // 5. AND IT STILL SAYS NOTHING ABOUT THE REVIEW.
        for (final wire in ReviewVerdict.values) {
          expect(
            marker.payload!.values.map((v) => '$v').join(' '),
            isNot(contains(wire.wire)),
            reason:
                'a marker recording "${wire.wire}" would be a verdict written '
                'by a bookkeeping append — the fabrication this file exists to '
                'prevent, and the one this row is easiest to introduce into',
          );
        }
      },
    );

    test(
      'the bound HOLDS across six ticks, counted',
      () async {
        final host = await _Host.started();
        await host.settleReviewerTwoWithoutAVerdict();
        await host.settleTheReplacementJob();

        // TICK 1 is the re-drive. The bound is spent on it.
        await host.runReviewSection();
        expect(
          await host.markerCountOn(_Host.reviewerTwoId),
          1,
          reason:
              'asserted first so "nothing happened on ticks 2-7" below cannot '
              'be satisfied by a marker that never existed',
        );
        final redrivesAfterFirst = host.jobsNamed(
          'engineering-review-settled-redrive',
        );
        expect(redrivesAfterFirst, 1);

        // Six more ticks, thirty seconds apart in production. Nothing may happen.
        for (var i = 0; i < 6; i++) {
          await host.runReviewSection();
        }

        expect(
          await host.markerCountOn(_Host.reviewerTwoId),
          1,
          reason:
              'THE BOUND, counted. One settled review execution is handed to this '
              'gate exactly once, ever. At e386909 this is 0 forever, because the '
              'write that would have spent the bound is the one that threw',
        );
        expect(
          host.jobsNamed('engineering-review-settled-redrive-not-marked'),
          0,
          reason:
              'the unbound shape, measured. At e386909 this is 7 — one per tick — '
              'and each line is a pass that re-drove a review it had already '
              'consumed',
        );
        expect(
          host.jobsNamed('engineering-review-settled-redrive'),
          redrivesAfterFirst,
          reason: 'and the pass reports activity on tick 1 only',
        );
        expect(
          host.executionStore.constraintViolations,
          isEmpty,
          reason:
              'still: a unique-index violation is never the bound being '
              'enforced, it is the bound silently failing to be written',
        );
      },
    );
  });

  group('and nothing is invented when there is no verdict anywhere', () {
    test('no verdict is fabricated when there is none anywhere', () async {
      // The replacement-reviewer shape is the one that makes a scan tempting:
      // there is something to find IF the scan is allowed to settle for "a
      // reviewer ran". It must not.
      final host = await _Host.started();

      // Tick 1 reclaims reviewer one's job beneath it and the gate declines.
      await host.runReviewSection();

      // Reviewer one then ends — having produced NOTHING. No result row at all,
      // which is a different durable state from "a result that parses to no
      // verdict", and the scan must not confuse the two.
      await host.settleReviewerOneWithoutAResult();
      await host.armTheReplacementReview();

      // Ticks 2..5. The replacement's job is reclaimed by the same machinery and
      // handed to the gate while its reviewer is still running.
      for (var i = 0; i < 4; i++) {
        await host.runReviewSection();
      }

      // Reviewer one exists and has concluded. It concluded NOTHING: no result at
      // all. Reviewer two is still running. So there is no verdict here, and the
      // answer must be that there is no verdict.
      expect(
        await host.executionStore.readResult(_Host.reviewerOneId),
        isNull,
        reason: 'the fixture: reviewer one is terminal with no result written',
      );
      expect(
        await host.markerCountOn(_Host.reviewerOneId),
        0,
        reason:
            'reviewer one has no result, so resolveReviewSubject does not settle '
            'on it and the sweep declines. A scan that accepted "a reviewer ran" '
            'instead of "a reviewer produced a verdict" would write a marker and '
            'silently burn the one attempt that run gets',
      );
      expect(
        host.jobsNamed('engineering-review-gate-verdict-bearing-execution'),
        0,
        reason: 'nothing was resolved off a non-verdict-bearing execution',
      );

      // The only statement made about it asserts the ABSENCE, and says so.
      final declines = host.eventsNamed(
        'engineering-review-gate-execution-not-terminal',
      );
      expect(declines, isNot(isEmpty), reason: 'the fixture reached the guard');
      for (final context in declines) {
        expect(context['carriesVerdict'], isFalse);
      }

      // AND NO VERDICT-SHAPED VALUE APPEARS ANYWHERE THE GATE WROTE.
      final writtenVerdicts = <String>{
        for (final e in host.loggedEvents)
          if (e.$2['reviewVerdict'] != null) '${e.$2['reviewVerdict']}',
      };
      expect(
        writtenVerdicts,
        isEmpty,
        reason:
            'every log line this gate emitted names a verdict only when it read '
            'one from a real result. A non-empty set here would be a fabricated '
            'verdict in a log an operator reads as fact',
      );
      expect(
        await host.workflowStore.readHumanDecisionsForWorkItem(
          _Host.workItemId,
        ),
        isEmpty,
        reason:
            'no question was asked, because no review concluded to ask about',
      );
      expect((await host.item).state, WorkItemState.reviewInProgress);
    });
  });
}

/// The exact index `apps/server/migrations/*/definition.sql` creates:
///
/// ```sql
/// CREATE UNIQUE INDEX agent_event_execution_sequence_unique
///   ON agent_event USING btree ("executionId", "sequence");
/// ```
class _IndexedExecutionStore implements ExecutionStore {
  _IndexedExecutionStore(this._inner);

  final InMemoryExecutionStore _inner;

  final List<({String constraintName, String eventId, String executionId})>
  constraintViolations = [];

  @override
  Future<void> appendEvent(AgentEventRecord event) async {
    final existing = await _inner.readEvents(event.executionId);
    final sameSequence = existing.where((e) => e.sequence == event.sequence);
    if (sameSequence.isNotEmpty) {
      final record = (
        constraintName: 'agent_event_execution_sequence_unique',
        eventId: event.eventId,
        executionId: event.executionId,
      );
      constraintViolations.add(record);
      throw _UniqueViolation(record);
    }
    final sameId = existing.where((e) => e.eventId == event.eventId);
    if (sameId.isNotEmpty) {
      final record = (
        constraintName: 'agent_event_id_unique',
        eventId: event.eventId,
        executionId: event.executionId,
      );
      constraintViolations.add(record);
      throw _UniqueViolation(record);
    }
    await _inner.appendEvent(event);
  }

  @override
  Future<void> saveRequest(AgentExecutionRequest request) =>
      _inner.saveRequest(request);

  @override
  Future<AgentExecutionRequest?> readRequest(String executionId) =>
      _inner.readRequest(executionId);

  @override
  Future<void> saveExecution(
    AgentExecution execution, {
    int? expectedVersion,
  }) => _inner.saveExecution(execution, expectedVersion: expectedVersion);

  @override
  Future<AgentExecution> readExecution(String executionId) =>
      _inner.readExecution(executionId);

  @override
  Future<AgentExecution?> readExecutionOrNull(String executionId) =>
      _inner.readExecutionOrNull(executionId);

  @override
  Future<List<AgentExecution>> listExecutions({String? workItemId}) =>
      _inner.listExecutions(workItemId: workItemId);

  @override
  Future<AgentExecution?> latestExecutionForWorkItem(String workItemId) =>
      _inner.latestExecutionForWorkItem(workItemId);

  @override
  Future<List<AgentEventRecord>> readEvents(String executionId) =>
      _inner.readEvents(executionId);

  @override
  Future<void> saveResult(String executionId, AgentResult result) =>
      _inner.saveResult(executionId, result);

  @override
  Future<AgentResult?> readResult(String executionId) =>
      _inner.readResult(executionId);

  @override
  Future<void> saveVerification(PlatformVerification verification) =>
      _inner.saveVerification(verification);

  @override
  Future<List<PlatformVerification>> readVerifications(String executionId) =>
      _inner.readVerifications(executionId);

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(ExecutionStore store) body,
  ) => _inner.inTransaction(body);
}

/// Thrown in place of the driver's unique-violation error.
///
/// Serverpod's `DatabaseQueryException` is an `abstract base class` and Dart
/// forbids implementing a `base` class outside its own library, so the fake
/// cannot throw the exact type. It does not need to: every assertion in this
/// file reads [_IndexedExecutionStore.constraintViolations], which is appended
/// to BEFORE the throw, so the violation is measured as a recorded fact rather
/// than as an exception that happened to escape or not.
///
/// The message shape is kept identical to the production line so a log captured
/// from this file reads like the one from QA.
class _UniqueViolation implements Exception {
  _UniqueViolation(this.record);

  final ({String constraintName, String eventId, String executionId}) record;

  @override
  String toString() =>
      'DatabaseQueryException: { message: duplicate key value violates unique '
      'constraint, code: 23505, table: agent_event, '
      'constraint: ${record.constraintName} }';
}

/// One item, two reviewer executions, and the real [runReviewLaneTick].
class _Host {
  _Host._({
    required this.workflowStore,
    required this.engine,
    required this.workerStore,
    required this.executionStore,
    required this.jobStore,
    required this.scheduler,
  });

  static const workItemId = 'wi-verdict-bearing';
  static const producerExecutionId = 'agx-wx-impl';

  /// The reviewer that concluded — the execution nothing points at once the
  /// replacement is armed.
  static const reviewerOneId = 'agx-wx-review-1';

  /// The replacement the terminal job names. Still running. Produced nothing.
  static const reviewerTwoId = 'agx-wx-review-2';

  static const replacementDedupeKey = '$workItemId:engineering_review:b7';
  static const producedCommit = 'c0ffee1';
  static const verdictWire = 'changes_required';

  static final _now = DateTime.utc(2026, 10, 16, 20, 2, 28);
  static final _agedBy = const Duration(hours: 3);

  /// REVIEWER ONE'S TIMELINE BEFORE THE GATE EVER TOUCHES IT.
  ///
  /// Three real appends at sequences 1..3, written the way
  /// `ExecutionCoordinator._nextSequence` writes them. Without them the
  /// collision has nothing to collide WITH: `max(prior) + 1` over an empty
  /// timeline is 1, and the handler's own append would land on 1 whether or not
  /// anything had been there before.
  static const _reviewerOnePriorSequences = 3;

  static Future<_Host> started() async {
    final workflowStore = InMemoryWorkflowStore();
    final workerStore = InMemoryWorkerStore();
    final executionStore = _IndexedExecutionStore(InMemoryExecutionStore());
    final jobStore = InMemoryJobStore();

    await workflowStore.saveWorkItem(
      WorkItem(
        workItemId: workItemId,
        productId: 'prod-1',
        category: WorkItemCategory.bugfix,
        title: 'A review that concluded, on an execution no job names',
        description:
            'The re-routed review left the verdict on the execution behind it.',
        state: WorkItemState.reviewInProgress,
        metadata: const {'producerActorId': producerExecutionId},
        createdAt: _now.subtract(_agedBy),
        updatedAt: _now.subtract(_agedBy),
      ),
    );

    // REVIEWER ONE: running, on the job that is about to be reclaimed beneath
    // it. This is the live ordering, not a hand-built broken row.
    await executionStore.saveExecution(
      AgentExecution(
        executionId: reviewerOneId,
        workItemId: workItemId,
        requestId: reviewerOneId,
        runtimeTypeId: 'rt-review',
        role: AgentRole.engineeringReviewer,
        status: AgentSessionStatus.running,
        workspace: const AgentWorkspace(
          workspaceId: 'ws-1',
          path: '/worktrees/review-1',
          startingRevision: producedCommit,
        ),
        startedAt: _now.subtract(_agedBy),
      ),
    );
    for (var i = 1; i <= _reviewerOnePriorSequences; i++) {
      await executionStore.appendEvent(
        AgentEventRecord(
          eventId: 'evt-$reviewerOneId-message-$i',
          executionId: reviewerOneId,
          workItemId: workItemId,
          sequence: i,
          type: AgentEventType.message,
          occurredAt: _now.subtract(_agedBy),
          payload: const {'kind': 'instruction_sent'},
        ),
      );
    }

    // REVIEWER ONE'S WORKER EXECUTION, and it is NOT terminal.
    //
    // This row is what the staleness probe reads, so it is what makes the
    // reclaim possible at all: a job whose worker execution says the reviewer is
    // still going is settled underneath it rather than waited for.
    await workerStore.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: 'wx-review-1',
        workItemId: workItemId,
        repositoryPath: '/durable/clone',
        requestedStartingRevision: producedCommit,
        requiredCapabilities: const {WorkerCapability.engineeringReview},
        agentExecutionId: reviewerOneId,
        status: WorkerExecutionStatus.agentExecuting,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
        startedAt: _now.subtract(_agedBy),
      ),
    );

    final enqueued = await JobQueue(store: jobStore).enqueueIfAbsent(
      workItemId: workItemId,
      definition: engineeringReviewDefinition,
      dedupeKey: replacementDedupeKey,
      instruction: 'Review the produced artifact.',
    );
    await jobStore.saveJob(
      enqueued.job.copyWith(
        state: JobState.running,
        executionReference: JobExecutionReference(
          workerExecutionId: 'wx-review-1',
          agentExecutionId: reviewerOneId,
          createdAt: _now.subtract(_agedBy),
        ),
      ),
    );

    return _Host._(
      workflowStore: workflowStore,
      engine: DurableWorkflowEngine(store: workflowStore),
      workerStore: workerStore,
      executionStore: executionStore,
      jobStore: jobStore,
      scheduler: Scheduler(
        schedulerId: 'sched-review',
        workflowStore: workflowStore,
        jobStore: jobStore,
        workerStore: workerStore,
        dispatch: _NoWorkerDispatch(),
        definition: engineeringReviewDefinition,
        workload: SchedulerWorkload(
          repositoryPath: '/durable/clone',
          startingRevision: 'aaaaaaa',
          timeoutSeconds: AgentExecutionBudgets.engineeringReviewSeconds,
          runtimeTypeId: 'rt-review',
        ),
        dedupeKeyBuilder: engineeringReviewDedupeKey,
        instructionBuilder: engineeringReviewInstruction,
        requestBuilder: engineeringReviewRequest,
        workloadResolver: engineeringReviewWorkloadResolver(
          workerStore: workerStore,
          runtimeTypeId: 'rt-review',
          timeoutSeconds: AgentExecutionBudgets.engineeringReviewSeconds,
        ),
        // SHORT so the reclaim fires on the first tick rather than after four
        // hours of wall clock. A bound on the FIXTURE, not on the behaviour.
        zombieStalenessAfter: const Duration(minutes: 1),
        clock: () => _now,
      ),
    );
  }

  final InMemoryWorkflowStore workflowStore;
  final DurableWorkflowEngine engine;
  final InMemoryWorkerStore workerStore;
  final _IndexedExecutionStore executionStore;
  final InMemoryJobStore jobStore;
  final Scheduler scheduler;
  final List<(String, Map<String, dynamic>)> loggedEvents = [];

  /// The job id `JobQueue` minted for the replacement review. Captured, never
  /// assumed: the dedupe key is not the id.
  String? _replacementJobId;

  Future<ReviewLaneTickResult> runReviewSection() => runReviewLaneTick(
    reviewScheduler: scheduler,
    jobStore: jobStore,
    triageProcessor: null,
    foldStalls: (_) {},
    workflowEngine: engine,
    executionStore: executionStore,
    workerStore: workerStore,
    log: (message, context) => loggedEvents.add((message, context)),
  );

  Future<WorkItem> get item => engine.loadWorkItem(workItemId);

  int jobsNamed(String name) => loggedEvents.where((e) => e.$1 == name).length;

  List<Map<String, dynamic>> eventsNamed(String name) =>
      loggedEvents.where((e) => e.$1 == name).map((e) => e.$2).toList();

  /// STEP: reviewer one concludes. The live payload verbatim — a top-level
  /// `verdict` plus one finding carrying three of the eleven fields a
  /// `DesignFinding` needs, so the finding is dropped as unreadable and the
  /// VERDICT is what the decision has to carry. A fixture that round-tripped a
  /// perfect finding would prove less.
  Future<void> settleReviewerOneWithTheLiveVerdict() async {
    final current = await executionStore.readExecution(reviewerOneId);
    await executionStore.saveExecution(
      current.copyWith(
        status: AgentSessionStatus.completed,
        completedAt: _now,
        version: current.version + 1,
      ),
    );
    await executionStore.saveResult(
      reviewerOneId,
      AgentResult(
        resultId: 'res-review-1',
        sessionId: 'ses-review-1',
        workItemId: workItemId,
        executionId: reviewerOneId,
        role: AgentRole.engineeringReviewer,
        status: AgentResultStatus.completed,
        artifacts: const [],
        diagnostics: const AgentDiagnostics(
          exitCode: 0,
          durationMs: 122000,
          toolCalls: 57,
          errors: [],
          warnings: [],
        ),
        structuredResult: const {
          'verdict': verdictWire,
          'findings': [
            {
              'severity': 'major',
              'dimension': 'correctness / error reporting',
              'evidence':
                  'apps/control_plane/lib/features/defect_report/'
                  'create_defect_bloc.dart:278-289 emits `success: true` '
                  'together with `errorMessage: evidenceError` when evidence '
                  'attachment fails; the commit replaced the only UI that '
                  'rendered it.',
            },
          ],
        },
        summary:
            'Engineering review: one major finding against '
            'create_defect_bloc.dart:278-289.',
        completedAt: _now,
      ),
    );
  }

  /// Reviewer one ends having produced NOTHING — not a result that parses to no
  /// verdict, but no result row at all.
  ///
  /// A different durable state on purpose: "the reviewer ran" and "the reviewer
  /// produced a verdict" are different claims, and a scan that accepted the
  /// first would spend the one attempt a real review gets.
  Future<void> settleReviewerOneWithoutAResult() async {
    final current = await executionStore.readExecution(reviewerOneId);
    await executionStore.saveExecution(
      current.copyWith(
        status: AgentSessionStatus.failed,
        reason: 'the review agent session ended without a result',
        completedAt: _now,
        version: current.version + 1,
      ),
    );
  }

  /// The replacement reviewer, dispatched behind reviewer one and still running,
  /// with the terminal job the platform will hand this gate naming IT.
  ///
  /// `jobId` is captured rather than constructed: `JobQueue` mints its own, and
  /// the dedupe key is not the id — a fixture that assumed they matched would
  /// quietly fail to find the job it had just written.
  Future<void> armTheReplacementReview() async {
    await executionStore.saveExecution(
      AgentExecution(
        executionId: reviewerTwoId,
        workItemId: workItemId,
        requestId: reviewerTwoId,
        runtimeTypeId: 'rt-review',
        role: AgentRole.engineeringReviewer,
        status: AgentSessionStatus.running,
        workspace: const AgentWorkspace(
          workspaceId: 'ws-2',
          path: '/worktrees/review-2',
          startingRevision: producedCommit,
        ),
        startedAt: _now.subtract(_agedBy),
      ),
    );
    await workerStore.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: 'wx-review-2',
        workItemId: workItemId,
        repositoryPath: '/durable/clone',
        requestedStartingRevision: producedCommit,
        requiredCapabilities: const {WorkerCapability.engineeringReview},
        agentExecutionId: reviewerTwoId,
        status: WorkerExecutionStatus.agentExecuting,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
        startedAt: _now.subtract(_agedBy),
      ),
    );
    final enqueued = await JobQueue(store: jobStore).enqueueIfAbsent(
      workItemId: workItemId,
      definition: engineeringReviewDefinition,
      dedupeKey: replacementDedupeKey,
      instruction: 'Review the produced artifact.',
    );
    final job = enqueued.job.copyWith(
      state: JobState.running,
      executionReference: JobExecutionReference(
        workerExecutionId: 'wx-review-2',
        agentExecutionId: reviewerTwoId,
        createdAt: _now.subtract(_agedBy),
      ),
    );
    await jobStore.saveJob(job);
    _replacementJobId = job.jobId;
  }

  /// Ends reviewer two on a timeout having produced nothing — the shape behind
  /// `[engineering-review-gate-no-verdict]`, and the only path on which the
  /// handler appends to the timeline the marker then writes to.
  Future<void> settleReviewerTwoWithoutAVerdict() async {
    await armTheReplacementReview();
    final current = await executionStore.readExecution(reviewerTwoId);
    await executionStore.saveExecution(
      current.copyWith(
        status: AgentSessionStatus.interrupted,
        reason: 'agent session exceeded its review budget',
        completedAt: _now,
        version: current.version + 1,
      ),
    );
    for (var i = 1; i <= 3; i++) {
      await executionStore.appendEvent(
        AgentEventRecord(
          eventId: 'evt-$reviewerTwoId-message-$i',
          executionId: reviewerTwoId,
          workItemId: workItemId,
          sequence: i,
          type: AgentEventType.message,
          occurredAt: _now.subtract(_agedBy),
          payload: const {'kind': 'instruction_sent'},
        ),
      );
    }
  }

  /// Settles the replacement's job terminal while its reviewer is STILL
  /// RUNNING — the row state `Scheduler._reclaimZombie` leaves behind, written
  /// directly so the ordering test does not have to wait for a second reclaim.
  Future<void> settleTheReplacementJob() async {
    final jobId = _replacementJobId;
    if (jobId == null) {
      throw StateError('armTheReplacementReview must run before this');
    }
    final current = await jobStore.readJob(jobId);
    await jobStore.saveJob(current!.copyWith(state: JobState.failed));
  }

  Future<int> markerCountOn(String executionId) async =>
      (await executionStore.readEvents(
        executionId,
      )).where((e) => e.payload?['reviewGateConsumed'] != null).length;

  Future<int> noVerdictCountOn(String executionId) async =>
      (await executionStore.readEvents(
        executionId,
      )).where((e) => e.payload?['reviewGate'] == 'no_verdict').length;
}

/// Reports "no compatible worker" so the scheduler BUILDS each request and never
/// runs one — the same technique the composition-order fixture uses.
class _NoWorkerDispatch implements WorkerDispatch {
  @override
  WorkerSelection select(WorkerExecutionRequest request) =>
      WorkerSelection.noCompatibleWorker();

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) =>
      throw StateError('no execution may run in this file');

  @override
  Future<void> cancel(String workerId, String reason) async {}
}
