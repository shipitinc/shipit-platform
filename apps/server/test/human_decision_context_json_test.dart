import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

/// ## WHAT THIS FILE EXISTS TO PROVE
///
/// ## `human_decision.contextJson` was empty for every decision the engine
/// raised, and the reason was in the engine, not the store.
///
/// `engineering_review_gate.dart` passes the whole review result as the
/// decision's `metadata`. The store wrote it to `metadataJson` faithfully. But
/// the column an operator-facing reader looks at is `contextJson`, and
/// `DurableWorkflowEngine.requestHumanDecision` never set
/// `HumanDecision.context` — so `PostgresWorkflowStore._humanDecisionToParams`
/// encoded `null` as `''` and every decision in QA persisted an EMPTY
/// `contextJson`. The persistence layer was correct; it was handed nothing.
///
/// ## WHY THE TEST LIVES HERE AND NOT IN `packages/workflow_store/test`
///
/// Path ownership for this lane is `apps/server/test/**`, and the assertion
/// needs nothing a package test could not see: `control_plane_server` already
/// depends on `workflow_store`, so it exercises the real engine against the real
/// in-memory store rather than a re-declared copy of the logic.
///
/// ## WHAT IT DOES NOT CLAIM
///
/// It does not claim a reviewer's FINDINGS reach the operator screen. They do
/// not, and cannot from here: `DecisionContext` is a closed three-field shape in
/// `packages/platform_contracts` (read-only to this lane) with nowhere to put an
/// arbitrary payload, and `DecisionView` — the Serverpod wire model behind
/// "WHAT WE SUGGEST" — carries no metadata field at all and lives in
/// `apps/server/lib/src/generated/`. The findings ride `metadata` →
/// `metadataJson`, which is durable and readable; the last hop is a wire-contract
/// change reported to the Manager rather than faked here.
void main() {
  late InMemoryWorkflowStore store;
  late DurableWorkflowEngine engine;
  const workItemId = 'wi-ctx';

  setUp(() async {
    store = InMemoryWorkflowStore();
    engine = DurableWorkflowEngine(store: store);
    await store.saveWorkItem(
      WorkItem(
        workItemId: workItemId,
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'A reviewed change',
        description: 'The reviewer answered.',
        state: WorkItemState.reviewInProgress,
        metadata: const {'producerActorId': 'agx-impl'},
        createdAt: DateTime.utc(2026, 10, 14),
        updatedAt: DateTime.utc(2026, 10, 14),
      ),
    );
  });

  Future<HumanDecision> request() => engine.requestHumanDecision(
    workItemId: workItemId,
    decisionType: HumanDecisionType.engineeringReview,
    question:
        'Engineering review requires changes. Approve, reject, or rework?',
    options: const [
      HumanDecisionOption(optionId: 'approve', label: 'Approve'),
      HumanDecisionOption(optionId: 'reject', label: 'Reject'),
      HumanDecisionOption(optionId: 'rework', label: 'Rework'),
    ],
    recommendation: 'CHANGES_REQUIRED',
    metadata: const {
      'reviewVerdict': 'changes_required',
      'engineeringReviewResult': {
        'verdict': 'changes_required',
        'findings': ['the retry loop carries no bound'],
      },
    },
    // The same shape `engineeringReviewTickHandler` sends. The gate-entry guard
    // requires a real producer identity and a reviewing actor distinct from it,
    // so this request has to be an honest one rather than a convenient one.
    actor: WorkflowActor(
      actorId: 'agx-review',
      actorType: ActorType.engineeringReviewer,
    ),
    extraContext: const {
      'producerActorId': 'agx-impl',
      'reviewExecutionId': 'agx-review',
      'reviewVerdict': 'changes_required',
    },
  );

  test(
    'the decision is persisted WITH a context, not with an empty one',
    () async {
      final decision = await request();

      expect(
        decision.context,
        isNotNull,
        reason:
            'this is the assertion that fails against the pre-fix engine: '
            '`context` was never set here, so `contextJson` was written as the '
            'empty string for every decision the engine ever raised.',
      );
    },
  );

  test(
    'the context carries the facts the request already held — no invention',
    () async {
      final decision = await request();

      expect(
        decision.context!.workflowState,
        WorkItemState.reviewInProgress.wire,
        reason:
            'the state the decision was raised FROM. The item is still at '
            '`reviewInProgress` when `requestHumanDecision` builds it; the gate '
            'entry happens after. Writing `waiting_for_human_decision` here would '
            'be a state the item had not reached yet.',
      );
      expect(
        decision.context!.availableOptions,
        ['approve', 'reject', 'rework'],
        reason: 'the caller\'s own option ids, in the caller\'s order',
      );
    },
  );

  test('it SURVIVES the round trip through the store', () async {
    // `contextJson` is what an operator-facing reader sees, so what matters is
    // the value that comes BACK, not the one that was constructed.
    final decision = await request();
    final reread = await store.readHumanDecision(decision.decisionId);

    expect(reread.context, isNotNull);
    expect(reread.context!.workflowState, WorkItemState.reviewInProgress.wire);
    expect(reread.context!.availableOptions, ['approve', 'reject', 'rework']);
  });

  test('it SURVIVES resolution — the resolved row keeps it', () async {
    final decision = await request();
    final reworked = await engine.resolveHumanDecision(
      decisionId: decision.decisionId,
      choice: HumanDecisionChoice.rework,
      decider: 'hum@shipit.platform',
      rationale: 'the retry loop needs a bound',
      signature: DecisionSignature(
        algorithm: 'ed25519',
        publicKey: 'test-public-key',
        signature: 'sig-rework',
        signedAt: DateTime.utc(2026, 10, 14),
      ),
    );
    expect(
      reworked.state,
      isNot(WorkItemState.waitingForHumanDecision),
      reason:
          'the gate really was entered and really was resolved. Without this '
          'the test could pass against a request the engine never accepted, '
          'and would then be asserting nothing.',
    );

    final reread = await store.readHumanDecision(decision.decisionId);
    expect(reread.status, HumanDecisionStatus.resolved);
    expect(
      reread.context,
      isNotNull,
      reason:
          'a decision whose context evaporates on resolution is a decision an '
          'operator can see nothing about after they answered it',
    );
  });

  test(
    'a request with NO options records an empty list, not a guess',
    () async {
      final decision = await engine.requestHumanDecision(
        workItemId: workItemId,
        decisionType: HumanDecisionType.engineeringReview,
        question: 'Proceed?',
        actor: WorkflowActor(
          actorId: 'agx-review',
          actorType: ActorType.engineeringReviewer,
        ),
        extraContext: const {'producerActorId': 'agx-impl'},
      );

      expect(decision.context, isNotNull);
      expect(
        decision.context!.availableOptions,
        isEmpty,
        reason:
            'the engine knows there were no options. Inventing three would put '
            'answers in front of a human that no caller offered.',
      );
    },
  );

  test('the metadata the gate passes is still persisted alongside it', () async {
    // The context and the metadata are two different columns and two different
    // claims. Populating one must not have displaced the other.
    final decision = await request();
    final reread = await store.readHumanDecision(decision.decisionId);

    expect(reread.metadata?['reviewVerdict'], 'changes_required');
    expect(reread.metadata?['engineeringReviewResult'], isNotNull);
  });
}
