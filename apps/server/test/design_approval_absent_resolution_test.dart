import 'package:control_plane_server/src/design/design_review_recorder.dart';
import 'package:control_plane_server/src/implementation/design_scope_grant.dart'
    show designScopeGrantProvenanceKey;
import 'package:control_plane_server/src/services/control_plane_service.dart';
import 'package:design_governance/design_governance.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

/// ## WHAT THIS FILE PROVES
///
/// Step 9 records a design review and raises a blocking `designApproval`
/// decision. When the reviewer produced NO readable verdict, the recorder
/// raises a labelled non-verdict decision carrying
/// [designReviewVerdictAbsentMetadataKey], and
/// [designApprovalAbsentChoiceIsResolvable] says such a decision may only be
/// resolved with `reject` or `rework`.
///
/// **A pure helper with no caller guards nothing.** The production chokepoint
/// is `ControlPlaneService.resolveHumanDecision`, and
/// `WorkflowEndpoints.resolveDecision` hands it a `choice` straight off the
/// wire — it never checks the choice against the decision's own `options`,
/// because that is the shape every lifecycle gate in this platform uses. So
/// "the screen does not offer `approve`" is a property of the SCREEN. Before
/// this file's guard was wired in, an API caller could resolve the absent
/// design decision with `approve`: the scope grant was recorded from an empty
/// declaration and the engine moved `waitingForHumanDecision -> designApproved`
/// with no reviewer verdict. That is exactly the fabrication the recorder's own
/// doc comment says it prevents.
///
/// It mirrors `engineering_review_verdict_absent_decision_test.dart`, which
/// documents the same wire-trust defect one lane over and drives the same
/// production method. It is RED before the guard is wired into
/// `resolveHumanDecision` and green after.
void main() {
  const workItemId = 'wi-design-absent-resolution';

  group('a design approval raised without a verdict cannot be approved', () {
    test(
      'a crafted `approve` is REFUSED by the production resolution path, and '
      'writes nothing',
      () async {
        final host = await _Host.withAbsentVerdictDecision();

        await expectLater(
          host.service.resolveHumanDecision(
            decisionId: host.decision.decisionId,
            choice: HumanDecisionChoice.approve,
            decider: 'operator@example.com',
            rationale: 'looks right to me',
            signature: _signature,
          ),
          throwsA(isA<StateError>()),
          reason:
              'approve is an ASSESSMENT. A decision that records no reviewer '
              'verdict cannot be resolved with one, however the request is '
              'built. The recorder records the absence, and this refusal is '
              'what makes that record mean something',
        );

        final item = await host.workflowStore.readWorkItem(workItemId);
        expect(
          item.state,
          WorkItemState.waitingForHumanDecision,
          reason: 'nothing was written: the item has not moved',
        );
        expect(item.blockingHumanDecisionId, host.decision.decisionId);

        final reread = await host.workflowStore.readHumanDecision(
          host.decision.decisionId,
        );
        expect(
          reread.status,
          HumanDecisionStatus.pending,
          reason: 'and the decision is still pending, with no recorded choice',
        );
        expect(reread.choice, isNull);
        expect(
          item.metadata?[designScopeGrantProvenanceKey],
          isNull,
          reason:
              'no scope grant was recorded from an empty declaration — the '
              'refusal happens before the grant write',
        );
      },
    );

    test('`reject` is still allowed, so the refusal is scoped to the '
        'assessment choices', () async {
      final host = await _Host.withAbsentVerdictDecision();

      final item = await host.service.resolveHumanDecision(
        decisionId: host.decision.decisionId,
        choice: HumanDecisionChoice.reject,
        decider: 'operator@example.com',
        rationale: 'No reviewer assessed it; send it back.',
        signature: _signature,
      );

      expect(
        item.state,
        WorkItemState.designRejected,
        reason:
            'reject sends the item back rather than asserting quality. The '
            'absent-verdict guard must not refuse the honest choices',
      );
    });
  });

  group('a REAL design approval is unaffected', () {
    test(
      '`approve` on a verdict-backed decision still moves the item',
      () async {
        final host = await _Host.withRealVerdictDecision();

        final item = await host.service.resolveHumanDecision(
          decisionId: host.decision.decisionId,
          choice: HumanDecisionChoice.approve,
          decider: 'operator@example.com',
          rationale: 'The reviewer approved it.',
          signature: _signature,
        );

        expect(
          item.state,
          WorkItemState.designApproved,
          reason:
              'the guard is scoped to decisions that record NO verdict. A '
              'decision carrying designReviewVerdict must resolve exactly as it '
              'did before',
        );
      },
    );
  });
}

final _signature = DecisionSignature(
  algorithm: 'test',
  publicKey: 'test',
  signature: 'test',
  signedAt: DateTime.utc(2026, 10, 22, 12),
);

/// A real-by-construction host: real [DurableWorkflowEngine] over the
/// package's [InMemoryWorkflowStore], and the production
/// [ControlPlaneService.resolveHumanDecision] with only its durable substrate
/// substituted. The decision is raised through the real engine, with the same
/// metadata shape the recorder writes, so the production guard reads a record
/// it could actually encounter.
class _Host {
  _Host._({
    required this.workflowStore,
    required this.executionStore,
    required this.service,
    required this.decision,
  });

  final InMemoryWorkflowStore workflowStore;
  final InMemoryExecutionStore executionStore;
  final _TestService service;
  final HumanDecision decision;

  static Future<_Host> withAbsentVerdictDecision() async {
    final workflowStore = InMemoryWorkflowStore();
    final engine = DurableWorkflowEngine(store: workflowStore);
    final executionStore = InMemoryExecutionStore();
    await _saveItem(workflowStore);

    final decision = await engine.requestHumanDecision(
      workItemId: 'wi-design-absent-resolution',
      decisionType: HumanDecisionType.designApproval,
      question:
          'NO VERDICT — NO REVIEWER ASSESSED THIS REVISION; READ THE RECORD, '
          'THEN APPROVE, SEND IT BACK, OR RETURN IT TO REVIEW',
      options: const [
        HumanDecisionOption(
          optionId: 'reject',
          label: 'Reject this design',
          description: 'The design is not accepted.',
        ),
        HumanDecisionOption(
          optionId: 'rework',
          label: 'Send it back for another review',
          description: 'The design returns to design review.',
        ),
      ],
      recommendation: designApprovalNoVerdictRecommendation,
      blocking: true,
      metadata: {
        designReviewVerdictAbsentMetadataKey: {
          'verdictRecorded': false,
          'cause': DesignReviewNoVerdictCause.verdictAbsent.wire,
          'detail': 'the reviewer result carried no verdict',
          'reviewExecutionId': 'agx-reviewer',
          'revisionId': 'rev-1',
        },
        'reviewExecutionId': 'agx-reviewer',
      },
      actor: const WorkflowActor(
        actorId: 'orchestrator',
        actorType: ActorType.orchestrator,
      ),
    );

    return _Host._(
      workflowStore: workflowStore,
      executionStore: executionStore,
      service: _TestService(_FakeSession(), workflowStore, executionStore),
      decision: decision,
    );
  }

  static Future<_Host> withRealVerdictDecision() async {
    final workflowStore = InMemoryWorkflowStore();
    final engine = DurableWorkflowEngine(store: workflowStore);
    final executionStore = InMemoryExecutionStore();

    await _saveItem(workflowStore);

    final decision = await engine.requestHumanDecision(
      workItemId: 'wi-design-absent-resolution',
      decisionType: HumanDecisionType.designApproval,
      question: 'Approve the login design?',
      options: designApprovalGateOptions,
      recommendation: designApprovalRecommendationFor(
        DesignReviewVerdict.approved,
      ),
      blocking: true,
      metadata: {
        designReviewVerdictMetadataKey: DesignReviewVerdict.approved.wire,
        'reviewExecutionId': 'agx-reviewer',
      },
      actor: const WorkflowActor(
        actorId: 'orchestrator',
        actorType: ActorType.orchestrator,
      ),
    );

    return _Host._(
      workflowStore: workflowStore,
      executionStore: executionStore,
      service: _TestService(_FakeSession(), workflowStore, executionStore),
      decision: decision,
    );
  }

  static Future<void> _saveItem(InMemoryWorkflowStore workflowStore) {
    return workflowStore.saveWorkItem(
      WorkItem(
        workItemId: 'wi-design-absent-resolution',
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Design the login screen',
        state: WorkItemState.designInReview,
        qaContractId: 'qa-1',
        metadata: const {},
        createdAt: _now(),
        updatedAt: _now(),
      ),
    );
  }
}

DateTime _now() => DateTime.utc(2026, 10, 22, 12);

/// [ControlPlaneService] with its durable substrate substituted, so the
/// production [ControlPlaneService.resolveHumanDecision] runs for real. The same
/// shape `engineering_review_verdict_absent_decision_test.dart` uses.
class _TestService extends ControlPlaneService {
  _TestService(super.session, this._store, this._executions);

  final WorkflowStore _store;
  final ExecutionStore _executions;
  final DesignGovernanceStore _designGovernance =
      InMemoryDesignGovernanceStore();

  @override
  WorkflowStore get workflowStore => _store;

  @override
  ExecutionStore get executionStore => _executions;

  @override
  DesignGovernanceStore get designGovernanceStore => _designGovernance;

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
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('not used by this test: ${invocation.memberName}');
}
