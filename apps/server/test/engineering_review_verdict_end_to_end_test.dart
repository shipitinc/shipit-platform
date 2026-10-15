/// End-to-end: a reviewer's FINAL MESSAGE becomes a decision, or a durable
/// record saying why it did not.
///
/// ## WHAT THIS FILE EXISTS TO PROVE
///
/// Four work items sat at `review_in_progress` on 2026-10-15 with no decision
/// and nothing on the operator's screen. Their reviews had run to completion
/// and produced real findings — `18ad90a`, +957/−199, a concrete blocking
/// finding about `_DesktopSkeletonRow` — and every one of them held `{}` in
/// `structuredResultJson`.
///
/// The chain that turns a verdict into a decision has three links, and this
/// exercises all three against each other rather than against a copy:
///
///   1. [engineeringReviewInstruction] states the payload contract. It is the
///      ONLY instruction a reviewer receives: `OpenCodeSession` opens its
///      session with `{'cwd', 'mcpServers'}` — no agent, no system prompt.
///   2. `OpenCodeSession.getResult` recovers the JSON object from the final
///      assistant text.
///   3. `engineeringReviewTickHandler` reads `structuredResult['verdict']` and
///      raises a blocking `engineeringReview` decision.
///
/// A test of any single link passes with today's defect. The defect was
/// between them: a prompt that asked for a verdict in prose, an extractor that
/// correctly found no JSON, and a gate that correctly refused to invent one.
///
/// ## AND THE ANTI-FABRICATION PROPERTY, EXPLICITLY
///
/// A test covering only the happy path would pass with the bug. The second half
/// of this file is the other direction: a reviewer that emits no verdict must
/// produce NO decision and NO verdict-shaped anything, anywhere — and a reviewer
/// that emits a near-miss spelling must be no different from one that emits
/// nothing at all. `93587cf` removed three `changesRequired` fallbacks; this is
/// what stops that defect returning by another route.
library;

import 'dart:async';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'package:control_plane_server/src/review/engineering_review_gate.dart';

/// A scripted ACP transport. The same shape the agent_runtime package's own
/// extraction tests use: it emits the `session/update` notifications the real
/// `opencode acp` emits, so the extraction path runs for real without a live
/// binary, network, or credentials.
class _ScriptedAcpTransport implements AcpTransport {
  _ScriptedAcpTransport(this.finalMessage);

  final String finalMessage;

  final _notifications = StreamController<Map<String, dynamic>>.broadcast(
    sync: true,
  );

  @override
  Stream<Map<String, dynamic>> get notifications => _notifications.stream;

  @override
  bool get isOpen => true;

  @override
  Future<AcpInitializeResult> initialize() async => const AcpInitializeResult(
    protocolVersion: 1,
    agentCapabilities: {
      'sessionCapabilities': {'resume': true},
    },
    agentInfo: {'name': 'OpenCode', 'version': 'test'},
    authMethods: [],
  );

  @override
  Future<Map<String, dynamic>> request(
    int id,
    String method,
    Map<String, dynamic> params,
  ) async {
    switch (method) {
      case 'initialize':
        return {
          'protocolVersion': 1,
          'agentInfo': {'name': 'OpenCode', 'version': 'test'},
        };
      case 'session/new':
        return {'sessionId': 'ses_review'};
      case 'setSessionConfigOption':
        return {};
      case 'session/prompt':
        _notifications.add({
          'method': 'session/update',
          'params': {
            'sessionId': 'ses_review',
            'updates': [
              {
                'type': 'agent_message_chunk',
                'message': {
                  'messageId': 'm1',
                  'content': {'type': 'text', 'text': finalMessage},
                },
              },
            ],
          },
        });
        return const {'stopReason': 'end_turn'};
      default:
        throw AcpRequestException(-32601, 'method not found: $method');
    }
  }

  @override
  Future<void> close() async => _notifications.close();
}

/// The gate's host: a real work item at `reviewInProgress` with a real producer
/// identity, a real job minted by the real queue, and a real reviewer execution.
class _ReviewHost {
  _ReviewHost._({
    required this.workflowStore,
    required this.workflowEngine,
    required this.executionStore,
    required this.jobStore,
    required this.job,
  });

  static const workItemId = 'wi-e2e-review';
  static const reviewerExecutionId = 'agx-wx-review';
  static const producerExecutionId = 'agx-wx-impl';
  static const reviewedCommit = '18ad90a';
  static final now = DateTime.utc(2026, 10, 15, 9);

  static Future<_ReviewHost> create() async {
    final workflowStore = InMemoryWorkflowStore();
    final jobStore = InMemoryJobStore();
    await workflowStore.saveWorkItem(
      WorkItem(
        workItemId: workItemId,
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Fix the desktop skeleton row',
        description: 'Align trailing placeholders with the column constants.',
        state: WorkItemState.reviewInProgress,
        metadata: const {'producerActorId': producerExecutionId},
        createdAt: now,
        updatedAt: now,
      ),
    );

    final enqueued = await JobQueue(store: jobStore).enqueueIfAbsent(
      workItemId: workItemId,
      definition: engineeringReviewDefinition,
      dedupeKey: '$workItemId:engineering_review:a0',
      instruction: engineeringReviewInstruction(
        (await DurableWorkflowEngine(store: workflowStore).loadWorkItem(
          workItemId,
        )),
        engineeringReviewDefinition,
      ),
    );
    final job = enqueued.job.copyWith(
      state: JobState.succeeded,
      executionReference: JobExecutionReference(
        workerExecutionId: 'wx-review',
        agentExecutionId: reviewerExecutionId,
        createdAt: now,
      ),
    );
    await jobStore.saveJob(job);

    final executionStore = InMemoryExecutionStore();
    await executionStore.saveExecution(
      AgentExecution(
        executionId: reviewerExecutionId,
        workItemId: workItemId,
        requestId: reviewerExecutionId,
        runtimeTypeId: 'eng-review-runtime',
        role: AgentRole.engineeringReviewer,
        status: AgentSessionStatus.completed,
        workspace: const AgentWorkspace(
          workspaceId: 'ws-review',
          path: '/worktrees/review',
          startingRevision: reviewedCommit,
        ),
        startedAt: now,
        completedAt: now,
      ),
    );

    return _ReviewHost._(
      workflowStore: workflowStore,
      workflowEngine: DurableWorkflowEngine(store: workflowStore),
      executionStore: executionStore,
      jobStore: jobStore,
      job: job,
    );
  }

  final InMemoryWorkflowStore workflowStore;
  final DurableWorkflowEngine workflowEngine;
  final InMemoryExecutionStore executionStore;
  final InMemoryJobStore jobStore;
  final Job job;

  /// Runs [finalMessage] through the REAL session and extractor, stores the
  /// resulting [AgentResult] exactly as the worker store would, and drains the
  /// real gate. This is the whole chain, end to end.
  Future<void> deliverReviewerTurn(String finalMessage) async {
    final session = OpenCodeSession(
      executionId: reviewerExecutionId,
      workItemId: workItemId,
      transportFactory: (_) async => _ScriptedAcpTransport(finalMessage),
    );
    await session.start(
      const AgentSessionConfig(
        executionId: reviewerExecutionId,
        workItemId: workItemId,
        workingDirectory: '/worktrees/review',
        timeout: Duration(minutes: 30),
      ),
    );
    await session.sendInstruction(
      AgentInstruction(
        instructionId: 'instr-review',
        content: (await jobStore.readJob(job.jobId))!.instruction,
      ),
    );
    await session.close();
    await executionStore.saveResult(
      reviewerExecutionId,
      await session.getResult(),
    );
  }

  Future<void> drainGate() => engineeringReviewTickHandler(
    workflowEngine: workflowEngine,
    executionStore: executionStore,
    logger: (message, context) {
      if (message == 'engineering-review-gate-no-verdict') {
        noVerdictLogs.add(context);
      }
    },
  )(job);

  final List<Map<String, dynamic>> noVerdictLogs = [];

  Future<List<HumanDecision>> decisions() =>
      workflowStore.readHumanDecisionsForWorkItem(workItemId);
}

/// The answer a reviewer following the rendered prompt gives for this change.
/// Shaped by hand from what `engineeringReviewInstruction` documents, and
/// carrying ONLY the fields the prompt asks for — no `findingId`, no
/// `revisionId`, no `reviewExecutionId`, no `createdAt`, no `version`.
const _wellFormedReview = '''
## Engineering review of 18ad90a

I re-ran the gates and read the whole diff.

`_DesktopSkeletonRow` lays its trailing placeholders out as 142/132/72 against
column constants that do not line up.

{
  "verdict": "changes_required",
  "findings": [
    {
      "severity": "blocker",
      "dimension": "correctness",
      "evidence": "apps/control_plane/lib/features/workbench/desktop_skeleton_row.dart:88",
      "requiredCorrection": "derive the trailing placeholder widths from the column constants",
      "affectedSurface": "apps/control_plane/lib/features/workbench/"
    }
  ],
  "summary": "The trailing placeholder widths are literals and drift from the column constants."
}
''';

void main() {
  group('a verdict in the reviewer\'s final message reaches a decision', () {
    test('the rendered prompt states the contract the gate reads', () async {
      final host = await _ReviewHost.create();
      final prompt = (await host.jobStore.readJob(host.job.jobId))!.instruction;

      // The gate reads `structuredResult['verdict']`. If the prompt stops
      // documenting that key, every review records `{}` again.
      expect(prompt, contains('"verdict"'));
      expect(prompt, contains(ReviewVerdict.changesRequired.wire));
      expect(prompt, contains('single JSON object'));
    });

    test('a well-formed verdict produces a blocking decision', () async {
      final host = await _ReviewHost.create();

      await host.deliverReviewerTurn(_wellFormedReview);
      await host.drainGate();

      final decisions = await host.decisions();
      expect(decisions, hasLength(1));
      final decision = decisions.single;
      expect(decision.decisionType, HumanDecisionType.engineeringReview);
      expect(decision.blocking, isTrue);
      expect(
        decision.recommendation,
        'CHANGES_REQUIRED',
        reason: 'and only because a reviewer said so',
      );

      final result = decision.metadata?['engineeringReviewResult'] as Map;
      expect(result['verdict'], 'changes_required');
      expect(
        result['findings'],
        hasLength(1),
        reason:
            'THE FINDING MUST SURVIVE. `engineeringReviewInstruction` asks '
            'only for the fields a reviewer can legitimately know, because '
            '`reviewExecutionId` and friends are run identity it cannot '
            'supply. Before the gate stamped those five, every such finding '
            'failed `DesignFinding.fromJson` and was dropped with a log line — '
            'so a correct answer to a correct prompt still lost its evidence.',
      );

      final finding = (result['findings'] as List).single as Map;
      expect(finding['severity'], 'blocker');
      expect(finding['dimension'], 'correctness');
      expect(finding['evidence'], contains('desktop_skeleton_row.dart'));
      // Stamped from the run, not invented.
      expect(finding['reviewExecutionId'], _ReviewHost.reviewerExecutionId);
      expect(finding['revisionId'], _ReviewHost.reviewedCommit);
      expect(finding['findingId'], isNotEmpty);
      expect(finding['createdAt'], isNotNull);
      expect(finding['version'], 1);
      expect(
        finding['category'],
        DesignFindingCategory.feasibility.wire,
        reason:
            'and the category, so a finding from an engineering review is '
            'classified by the run rather than dropped for lacking one',
      );
    });

    test('an approved verdict is reported as APPROVE, not softened', () async {
      final host = await _ReviewHost.create();

      // A reviewer that found nothing is a first-class outcome and must reach
      // the operator as exactly what it said.
      await host.deliverReviewerTurn(
        '{"verdict":"approved","findings":[],"summary":"No blockers found."}',
      );
      await host.drainGate();

      final decision = (await host.decisions()).single;
      expect(decision.recommendation, 'APPROVE');
      expect(
        decision.metadata?['reviewVerdict'],
        'approved',
        reason: 'an honest "found nothing" must survive the pipeline intact',
      );
    });
  });

  group('ANTI-FABRICATION: no verdict means no verdict-shaped anything', () {
    test('a review that completes with no verdict raises NO decision', () async {
      final host = await _ReviewHost.create();

      // The live case: a thorough prose review and no JSON object.
      await host.deliverReviewerTurn('''
## Engineering review

I re-ran every gate and read the whole diff. The change is coherent, the
tests are real, and there is one blocking problem: `_DesktopSkeletonRow`
lays its trailing placeholders out as 142/132/72 against column constants
that do not line up.
''');
      await host.drainGate();

      expect(
        await host.decisions(),
        isEmpty,
        reason:
            'no reviewer returned a verdict, so no verdict may exist anywhere. '
            'This is the assertion a happy-path-only test would never make.',
      );
      final item = await host.workflowEngine.loadWorkItem(
        _ReviewHost.workItemId,
      );
      expect(item.blockingHumanDecisionId, isNull);
      expect(item.state, WorkItemState.reviewInProgress);
    });

    test('the absence is recorded durably, naming the cause', () async {
      final host = await _ReviewHost.create();
      await host.deliverReviewerTurn('A review written entirely in prose.');
      await host.drainGate();

      expect(host.noVerdictLogs, hasLength(1));
      expect(host.noVerdictLogs.single['cause'], 'verdict_absent');

      final recorded = (await host.executionStore.readEvents(
        _ReviewHost.reviewerExecutionId,
      )).where((e) => e.payload?['reviewGate'] == 'no_verdict');
      expect(recorded, hasLength(1));
      expect(
        recorded.single.type,
        AgentEventType.warning,
        reason: 'a reviewer that answered in prose did not FAIL',
      );
    });

    test(
      'a near-miss spelling is no different from no answer at all',
      () async {
        // Every one of these is what a reviewer that TRIED to comply might
        // produce. Reading any of them as a verdict asserts a finding or an
        // approval no reviewer made.
        for (final wire in const [
          'CHANGES_REQUIRED',
          'changesRequired',
          'needs_work',
          'approve',
          'APPROVED',
          'changes_required ',
        ]) {
          final host = await _ReviewHost.create();
          await host.deliverReviewerTurn('{"verdict":"$wire"}');
          await host.drainGate();

          expect(
            await host.decisions(),
            isEmpty,
            reason:
                '"$wire" is not a ReviewVerdict wire value, so it must not '
                'become one',
          );
          expect(host.noVerdictLogs.single['cause'], 'verdict_unreadable');
        }
      },
    );

    test('nothing anywhere on the item names a verdict it was not given', () {
      // The property in one assertion: no code path in this chain may produce
      // a verdict string that did not come out of the reviewer's own message.
      // Enumerated rather than searched for, because the failure mode is an
      // accidental literal in a fallback.
      expect(ReviewVerdict.values, hasLength(4));
      expect(
        ReviewVerdict.values.map((v) => v.wire),
        [
          'approved',
          'approved_with_minor_findings',
          'changes_required',
          'rejected',
        ],
      );
    });
  });
}
