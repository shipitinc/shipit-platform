import 'package:control_plane_server/src/endpoints/workflow_endpoints.dart';
import 'package:control_plane_server/src/generated/resolve_decision_view.dart';
import 'package:control_plane_server/src/services/control_plane_service.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/serverpod.dart';
// Same seam as the colocated suites: `package:test` is a dev-only import.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart'
    show DurableWorkflowEngine, InMemoryWorkflowStore, WorkflowStore;

/// F-250 regression: `resolveDecision` on a `system:provider-health`
/// decision 500s — and the decision cannot resolve at all through the
/// sanctioned endpoint.
///
/// ## THE LIVE DEFECT, BOTH HALVES
///
/// The provider-health monitor parks every `hd-provider-*`/`hd-all-down-*`
/// ticket on `system:provider-health`, a durable namespace that has no
/// `work_item` row. The endpoint then failed twice, in order:
///
///  1. `HumanDecisionChoice.fromWire('acknowledge')` threw — the enum
///     carries none of the infra menu's option ids (`acknowledge`,
///     `investigate`, `escalate`).
///  2. `DurableWorkflowEngine.resolveHumanDecision` read the work item
///     before writing anything, so `WorkItemNotFoundException` — the
///     `Internal Server Error` F-250 recorded. ~28 stale tickets sat pending
///     with no legal answer path.
///
/// The fix resolves a `system:`-scoped decision at the store: the option
/// menu is the choice guard, `resolvedOptionId` carries the answer, and an
/// already-resolved ticket replays untouched — the same semantics the engine
/// applies where it can apply them.
///
/// ## HOW IT DRIVES THE ENDPOINT WITHOUT A DATABASE
///
/// Same seam as `home_pending_decisions_test.dart` /
/// `work_item_action_endpoints_test.dart`: [WorkflowEndpoints] builds its
/// service through `serviceFor`, overridden here to hand back the REAL
/// service logic over [InMemoryWorkflowStore] and a REAL
/// [DurableWorkflowEngine]. Only the persistence substrate is substituted.
void main() {
  late InMemoryWorkflowStore store;
  late _TestWorkflowEndpoints endpoints;
  late Session session;

  setUp(() {
    store = InMemoryWorkflowStore();
    endpoints = _TestWorkflowEndpoints(store);
    session = _FakeSession();
  });

  HumanDecision infraDecision({
    required String decisionId,
    required List<String> optionIds,
    bool blocking = false,
    Map<String, dynamic>? metadata,
  }) => HumanDecision(
    decisionId: decisionId,
    workItemId: 'system:provider-health',
    decisionType: HumanDecisionType.infrastructureDecision,
    status: HumanDecisionStatus.pending,
    question: 'Provider openrouter is unavailable',
    context: DecisionContext(
      workflowState: 'provider_unavailable',
      availableOptions: optionIds,
    ),
    options: optionIds
        .map((id) => HumanDecisionOption(optionId: id, label: id))
        .toList(),
    recommendation: optionIds.first,
    blocking: blocking,
    requestedAt: DateTime.utc(2026, 10, 20),
    metadata: metadata ?? {'provider': 'openrouter', 'dismissible': true},
    updatedAt: DateTime.utc(2026, 10, 20),
  );

  Future<ResolveDecisionView> resolve(String decisionId, String choice) =>
      endpoints.resolveDecision(
        session,
        decisionId: decisionId,
        choice: choice,
        decider: 'operator',
        rationale: 'stale ticket cleanup',
        algorithm: 'ed25519',
        publicKey: 'operator-pub-key',
        signature: 'operator-sig-1',
        signedAt: DateTime.utc(2026, 10, 21),
      );

  group('resolveDecision — system:provider-health tickets (F-250)', () {
    test(
      'an hd-provider-* ticket resolves as acknowledge and returns a valid '
      'view — the durable record is answered, not just the response',
      () async {
        await store.saveHumanDecision(
          infraDecision(
            decisionId: 'hd-provider-openrouter-1',
            optionIds: const ['acknowledge', 'investigate'],
          ),
        );

        final view = await resolve('hd-provider-openrouter-1', 'acknowledge');

        // The wire still carries a work item view — the scope, marked as
        // `system` rather than a WorkItemState it never had.
        expect(view.workItem.workItemId, 'system:provider-health');
        expect(view.workItem.state, 'system');
        expect(view.decision, isNotNull);
        expect(view.decision!.decisionType, 'infrastructure_decision');
        expect(view.decision!.status, 'resolved');
        expect(view.decision!.resolvedAt, isNotNull);
        expect(view.decision!.workItemTitle, 'system:provider-health');

        final stored = await store.readHumanDecision(
          'hd-provider-openrouter-1',
        );
        expect(stored.status, HumanDecisionStatus.resolved);
        expect(stored.resolvedOptionId, 'acknowledge');
        expect(stored.decider, 'operator');
        expect(stored.rationale, 'stale ticket cleanup');
        expect(
          stored.choice,
          isNull,
          reason:
              'acknowledge is not a HumanDecisionChoice — the option id is '
              'recorded in resolvedOptionId, never rewritten to an enum '
              'answer the operator was not shown',
        );
      },
    );

    test('an hd-all-down-* BLOCKING ticket resolves the same way — the stale '
        'stack contains both shapes', () async {
      await store.saveHumanDecision(
        infraDecision(
          decisionId: 'hd-all-down-implementer-9',
          optionIds: const ['acknowledge', 'escalate'],
          blocking: true,
          metadata: {'role': 'implementer', 'dismissible': false},
        ),
      );

      final view = await resolve('hd-all-down-implementer-9', 'acknowledge');

      expect(view.decision!.status, 'resolved');
      final stored = await store.readHumanDecision('hd-all-down-implementer-9');
      expect(stored.status, HumanDecisionStatus.resolved);
      expect(stored.resolvedOptionId, 'acknowledge');
    });

    test('a repeated call replays the recorded answer — it never rewrites the '
        'resolution', () async {
      await store.saveHumanDecision(
        infraDecision(
          decisionId: 'hd-provider-anthropic-2',
          optionIds: const ['acknowledge', 'investigate'],
        ),
      );

      final first = await resolve('hd-provider-anthropic-2', 'acknowledge');
      final second = await resolve('hd-provider-anthropic-2', 'investigate');

      final stored = await store.readHumanDecision('hd-provider-anthropic-2');
      expect(stored.resolvedOptionId, 'acknowledge');
      expect(
        stored.timestamp,
        first.decision!.resolvedAt,
        reason:
            'the second call must replay the first outcome, not record '
            'investigate over it',
      );
      expect(second.decision!.resolvedAt, stored.timestamp);
    });

    test(
      'an answer the ticket never offered is refused and NOTHING is written',
      () async {
        await store.saveHumanDecision(
          infraDecision(
            decisionId: 'hd-provider-openrouter-3',
            optionIds: const ['acknowledge', 'investigate'],
          ),
        );

        await expectLater(
          resolve('hd-provider-openrouter-3', 'approve'),
          throwsA(isA<StateError>()),
        );

        final stored = await store.readHumanDecision(
          'hd-provider-openrouter-3',
        );
        expect(
          stored.status,
          HumanDecisionStatus.pending,
          reason: 'a refused answer must leave the ticket awaiting one',
        );
      },
    );
  });

  group('resolveDecision — ordinary work-item decisions are unchanged', () {
    test(
      'a blocking engineering-review decision resolves and the item moves to '
      'the routed state, with the real work item view',
      () async {
        const workItemId = 'defect-DEF-9';
        await store.saveWorkItem(
          WorkItem(
            workItemId: workItemId,
            productId: 'shipit',
            category: WorkItemCategory.bugfix,
            title: 'Sign-in is rejected after a password reset',
            description: 'Operators cannot sign in after a password reset',
            state: WorkItemState.waitingForHumanDecision,
            blockingHumanDecisionId: 'dec-eng-1',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            version: 1,
          ),
        );
        await store.saveHumanDecision(
          HumanDecision(
            decisionId: 'dec-eng-1',
            workItemId: workItemId,
            decisionType: HumanDecisionType.engineeringReview,
            status: HumanDecisionStatus.pending,
            question: 'Approve the review verdict?',
            blocking: true,
            requestedAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        );

        final view = await resolve('dec-eng-1', 'approve');

        expect(view.workItem.workItemId, workItemId);
        expect(view.workItem.state, 'review_approved');
        expect(view.decision!.status, 'resolved');
        expect(view.decision!.choice, 'approve');

        final item = await store.readWorkItem(workItemId);
        expect(item.state, WorkItemState.reviewApproved);
        final stored = await store.readHumanDecision('dec-eng-1');
        expect(stored.status, HumanDecisionStatus.resolved);
        expect(stored.choice, HumanDecisionChoice.approve);
      },
    );
  });
}

/// Drives the REAL endpoint method over an in-memory store.
///
/// Overrides [WorkflowEndpoints.serviceFor] only — the store is substituted,
/// never the resolution logic under test.
class _TestWorkflowEndpoints extends WorkflowEndpoints {
  _TestWorkflowEndpoints(this._store);

  final WorkflowStore _store;

  @override
  ControlPlaneService serviceFor(Session session) =>
      _TestService(session, _store);
}

/// The real service, with its Postgres-backed store replaced by an in-memory
/// one and the durable engine rebuilt over it.
///
/// `ControlPlaneService._db` is `late final` and is never touched here,
/// because every accessor this surface uses is overridden below.
class _TestService extends ControlPlaneService {
  _TestService(super.session, this._store);

  final WorkflowStore _store;

  @override
  WorkflowStore get workflowStore => _store;

  @override
  DurableWorkflowEngine get workflowEngine =>
      DurableWorkflowEngine(store: _store);
}

/// A [Session] that records log lines and never touches a database.
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
