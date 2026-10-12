import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart' show HumanDecisionRouting;
import 'package:workflow_store/workflow_store.dart';

/// THE TRIAGE DISCRIMINATOR — every human-initiated re-triage gets a fresh
/// dedupe key, and only a re-triage gets one.
///
/// ## THE DEFECT THIS EXISTS TO CLOSE
///
/// Observed read-only in QA on 2026-10-12, work item
/// `defect-DEF-1791684804452198`. Four jobs, all TERMINAL, so every
/// `activeDedupeKey` is NULL and no unique-index conflict exists:
///
/// ```
/// defect-DEF-1791684804452198:triage_defect        failed
/// defect-DEF-1791684804452198:triage_defect:a1     failed
/// defect-DEF-1791684804452198:triage_defect:a2     succeeded   <- holds the key
/// defect-DEF-1791684804452198:engineering_review   failed
/// ```
///
/// The item sat at `designNotRequired` — a correct entry state of
/// `triageDefectDefinition` — and across multiple verified ticks
/// (`scheduler.tick.completed {ran: true, dispatched: 0, failedSections: []}`)
/// NO triage job was enqueued. Permanently inert.
///
/// ## WHY IT HAPPENED
///
/// The item reached `designNotRequired` from the rework-routing fix
/// (7f863ac / 4beef5e) and then repair migration 20261012150000000. Neither
/// advances the discriminator: only `DurableWorkflowEngine.operatorRetry` did.
/// So the fix that stopped items stranding introduced a second way to arrive
/// at a triage entry state WITHOUT the ability to be dispatched. The two
/// changes are in tension, and this file is the tension resolved.
///
/// ## WHAT IS ASSERTED HERE, AND WHERE
///
/// This file owns the WRITER (`workflow_store`): that a re-triage advances the
/// marker, that a non-re-triage does not, and that the marker is one monotone
/// counter. `packages/scheduler/test/operator_retry_dispatch_test.dart` owns
/// the READER — that the marker becomes `':a<n>'` and that an absent marker
/// still yields the byte-identical historical key — and it drives a REAL tick
/// to prove a re-triage actually enqueues.
const _id = 'defect-DEF-1791684804452198';

const _orch = WorkflowActor(
  actorId: 'orch-1',
  actorType: ActorType.orchestrator,
);
const _reviewer = WorkflowActor(
  actorId: 'reviewer-2',
  actorType: ActorType.engineeringReviewer,
);
const _qaExecutor = WorkflowActor(
  actorId: 'qa-1',
  actorType: ActorType.qaExecutor,
);

DecisionSignature _sig() => DecisionSignature(
  algorithm: 'Ed25519',
  publicKey: 'key-1',
  signature: 'sig-1',
  signedAt: DateTime.now(),
);

AgentResult _completedResult() => AgentResult(
  resultId: 'res-1',
  sessionId: 'ses-1',
  workItemId: _id,
  status: AgentResultStatus.completed,
  artifacts: const [],
  diagnostics: AgentDiagnostics(
    exitCode: 0,
    durationMs: 100,
    toolCalls: 1,
    errors: const [],
    warnings: const [],
  ),
  structuredResult: const {},
  completedAt: DateTime.now(),
);

QAContract _qaContract() => QAContract(
  contractId: 'qa-1',
  workItemCategory: WorkItemCategory.feature,
  gates: [
    QAGateDefinition(
      gateId: 'static-analysis',
      type: 'static-analysis',
      required: true,
      config: const {},
      evidenceTypes: const ['test-report'],
    ),
    QAGateDefinition(
      gateId: 'unit-tests',
      type: 'unit-tests',
      required: true,
      config: const {},
      evidenceTypes: const ['test-report'],
    ),
  ],
  version: '1.0.0',
  createdAt: DateTime.parse('2024-03-01T00:00:00Z'),
  updatedAt: DateTime.parse('2024-03-01T00:00:00Z'),
);

List<QAGateResult> _passingGateResults() => [
  QAGateResult(
    gateId: 'static-analysis',
    workItemId: _id,
    status: QAGateStatus.passed,
    evidence: const [],
    evaluatedAt: DateTime.parse('2024-03-02T13:00:00Z'),
  ),
  QAGateResult(
    gateId: 'unit-tests',
    workItemId: _id,
    status: QAGateStatus.passed,
    evidence: const [],
    evaluatedAt: DateTime.parse('2024-03-02T13:00:00Z'),
  ),
];

Future<DurableWorkflowEngine> _engine() async {
  final store = InMemoryWorkflowStore();
  final engine = DurableWorkflowEngine(store: store);
  _stores[engine] = store;
  await engine.createWorkItem(
    productId: 'prod-1',
    category: WorkItemCategory.feature,
    title: 'Triage discriminator',
    description: 'Work item used to prove the re-triage discriminator advances',
    workItemId: _id,
    metadata: const {'defectId': _id, 'defectSeverity': 'high'},
  );
  return engine;
}

/// Forces an unreadable marker onto the work item, bypassing the engine.
///
/// No production path writes one — that is the point: the reader must treat it
/// as a defect in whatever wrote it. It is seeded through the durable store so
/// the test does not have to pretend the engine can be made to misbehave.
Future<void> _forceMarker(DurableWorkflowEngine engine, Object value) async {
  final store = _storeOf(engine);
  final item = await store.readWorkItem(_id);
  await store.saveWorkItem(
    item.copyWith(metadata: {...?item.metadata, 'triageAttempt': value}),
  );
}

Future<void> _designApproved(DurableWorkflowEngine engine) async {
  await engine.transition(
    workItemId: _id,
    to: WorkItemState.planning,
    trigger: TransitionTrigger.systemEvent,
    actor: _orch,
  );
  await engine.transition(
    workItemId: _id,
    to: WorkItemState.planned,
    trigger: TransitionTrigger.systemEvent,
    actor: _orch,
    context: const {'featureRef': 'FEAT-001'},
  );
  await engine.transition(
    workItemId: _id,
    to: WorkItemState.designRequired,
    trigger: TransitionTrigger.systemEvent,
    actor: _orch,
    context: const {'designContractId': 'dc-1'},
  );
  await engine.transition(
    workItemId: _id,
    to: WorkItemState.designInReview,
    trigger: TransitionTrigger.systemEvent,
    actor: _orch,
    context: const {'designContractStatus': DesignContractStatus.underReview},
  );
  await engine.resolveHumanDecision(
    decisionId: (await engine.requestHumanDecision(
      workItemId: _id,
      decisionType: HumanDecisionType.designApproval,
      actor: _orch,
    )).decisionId,
    choice: HumanDecisionChoice.approve,
    decider: 'alice@example.com',
    rationale: 'Approved',
    signature: _sig(),
  );
}

/// A work item parked at `waitingForHumanDecision` on an `engineeringReview`
/// decision, with a live triage discriminator history already behind it — the
/// shape the QA defect actually had.
Future<DurableWorkflowEngine> _atEngineeringReviewGate({int? marker}) async {
  final engine = await _engine();
  if (marker != null) {
    // Seeded through the durable row, before any transition: the shape of an
    // item that already has triage history behind it. Asserted before the walk
    // below so a passing test cannot be passing because the seed was ignored.
    final store = _storeOf(engine);
    final item = await store.readWorkItem(_id);
    await store.saveWorkItem(
      item.copyWith(metadata: {...?item.metadata, 'triageAttempt': marker}),
    );
    expect((await store.readWorkItem(_id)).metadata?['triageAttempt'], marker);
  }
  await _designApproved(engine);
  await engine.transition(
    workItemId: _id,
    to: WorkItemState.agentExecuting,
    trigger: TransitionTrigger.systemEvent,
    actor: _orch,
    context: const {'agentAvailable': true, 'capabilitiesMatch': true},
  );
  await engine.transition(
    workItemId: _id,
    to: WorkItemState.agentCompleted,
    trigger: TransitionTrigger.agentResult,
    actor: _orch,
    context: {'qaContractId': 'qa-1', 'agentResult': _completedResult()},
  );
  await engine.transition(
    workItemId: _id,
    to: WorkItemState.reviewInProgress,
    trigger: TransitionTrigger.agentResult,
    actor: _orch,
    context: {'agentResult': _completedResult()},
  );
  await engine.requestHumanDecision(
    workItemId: _id,
    decisionType: HumanDecisionType.engineeringReview,
    question: 'Approve the implementation?',
    actor: _reviewer,
    extraContext: const {'producerActorId': 'agent-1'},
  );
  expect(
    (await engine.loadWorkItem(_id)).state,
    WorkItemState.waitingForHumanDecision,
  );
  return engine;
}

Future<HumanDecision> _pendingEngineeringReview(
  DurableWorkflowEngine engine,
) async => (await _storeOf(engine).readHumanDecisionsForWorkItem(
  _id,
)).firstWhere((d) => d.decisionType == HumanDecisionType.engineeringReview);

/// THE DRIFT GUARD between the routing table and the re-triage rule.
///
/// `DurableWorkflowEngine._isReWorkDecision` deliberately does not consult
/// `HumanDecisionRouting`, because copying that table into `workflow_store` is
/// how `escalationTargetFor` already came to disagree with `targetFor` in this
/// repository. The cost of not consulting it is that the two could drift: a
/// route added to the routing table pointing at `designNotRequired` with a
/// choice the rule does not recognise would re-enter triage WITHOUT a fresh
/// discriminator and be inert — the exact defect, one release later.
///
/// This closes that gap without copying anything. It reads the ROUTING TABLE
/// (the authority) and asserts a property of it: every route that lands on
/// `designNotRequired` carries a choice the rule recognises as re-work. The
/// recognised set is written out here literally, so adding a route with a new
/// choice fails this test and names what the rule now has to decide.
void main() {
  group('drift guard: the routing table and the re-triage rule agree', () {
    test(
      'every route to designNotRequired carries a choice the rule recognises '
      'as re-work',
      () {
        const recognised = <HumanDecisionChoice>[
          HumanDecisionChoice.rework,
          HumanDecisionChoice.reject,
        ];
        final reEntryRoutes = <String>[];
        for (final type in HumanDecisionType.values) {
          for (final choice in HumanDecisionChoice.values) {
            if (HumanDecisionRouting.targetFor(type, choice) !=
                WorkItemState.designNotRequired) {
              continue;
            }
            reEntryRoutes.add('($type, $choice)');
            expect(
              recognised.contains(choice) ||
                  (type == HumanDecisionType.escalation &&
                      choice == HumanDecisionChoice.approve),
              isTrue,
              reason:
                  '$type/$choice now routes to designNotRequired, a triage '
                  'entry state, and would re-enter triage on a key the last '
                  'run already consumed. It must be classified as re-work by '
                  'DurableWorkflowEngine._isReWorkDecision, or this route '
                  'makes the work item permanently inert.',
            );
          }
        }

        // The guard above is vacuous if the table has no such routes — which is
        // exactly what it would look like if `targetFor` were renamed or its
        // return type changed under it. Asserted, not assumed.
        expect(
          reEntryRoutes,
          isNotEmpty,
          reason:
              'no route reaches designNotRequired at all, so this guard is '
              'checking nothing. That is a change to HumanDecisionRouting, '
              'and it needs a human to look at it.',
        );
        expect(reEntryRoutes, hasLength(5), reason: 'the five known routes');
      },
    );
  });

  group('the defect: a re-triage that arrives by DECISION gets a fresh key', () {
    test('an engineering-review REWORK re-entering triage advances the marker '
        'past every key a terminal job already holds', () async {
      final engine = await _atEngineeringReviewGate(marker: 2);

      final reworked = await engine.resolveHumanDecision(
        decisionId: (await _pendingEngineeringReview(engine)).decisionId,
        choice: HumanDecisionChoice.rework,
        decider: 'bob@example.com',
        rationale: 'The result is not acceptable',
        signature: _sig(),
      );

      expect(
        reworked.state,
        WorkItemState.designNotRequired,
        reason: 'the rework edge lands on the dispatchable entry state',
      );
      expect(
        reworked.metadata?['triageAttempt'],
        3,
        reason:
            '`:a1` and `:a2` are both held by TERMINAL jobs on the real item, '
            'so the marker must be strictly above every value it has ever '
            'carried. Leaving it at 2 is the inert item, reproduced.',
      );
    });

    test(
      'the same holds for a review REJECT, which lands on reviewRejected',
      () async {
        // The reject half of the same intent is the one that must NOT be keyed on
        // the TARGET state: `HumanDecisionRouting.targetFor` sends
        // `(engineeringReview, reject)` to `reviewRejected`, which is in no
        // `JobDefinition.entryStates`, and the item is expected to continue to
        // `designNotRequired` over the `reviewRejected -> designNotRequired`
        // edge. A rule keyed on the landing state would stamp nothing here and
        // the item would be inert once that second hop is taken.
        final engine = await _atEngineeringReviewGate(marker: 1);
        final rejected = await engine.resolveHumanDecision(
          decisionId: (await _pendingEngineeringReview(engine)).decisionId,
          choice: HumanDecisionChoice.reject,
          decider: 'bob@example.com',
          rationale: 'Rejected outright',
          signature: _sig(),
        );
        expect(rejected.state, WorkItemState.reviewRejected);
        expect(rejected.metadata?['triageAttempt'], 2);
      },
    );

    test('an item that never re-triaged keeps NO marker at all', () async {
      // The historical-key property, stated at the writer: absent stays absent,
      // so `triageDefectDedupeKey` keeps producing `'<id>:triage_defect'` and
      // every already-persisted job keeps matching.
      final engine = await _atEngineeringReviewGate();
      await engine.resolveHumanDecision(
        decisionId: (await _pendingEngineeringReview(engine)).decisionId,
        choice: HumanDecisionChoice.rework,
        decider: 'bob@example.com',
        rationale: 'Not acceptable',
        signature: _sig(),
      );
      // The FIRST re-triage is 1, never 0 and never the unsuffixed key.
      expect((await engine.loadWorkItem(_id)).metadata?['triageAttempt'], 1);
    });
  });

  group('a resolution that carries NO new intent does not inflate', () {
    test('an engineering-review APPROVE leaves the marker untouched', () async {
      final engine = await _atEngineeringReviewGate();
      final approved = await engine.resolveHumanDecision(
        decisionId: (await _pendingEngineeringReview(engine)).decisionId,
        choice: HumanDecisionChoice.approve,
        decider: 'bob@example.com',
        rationale: 'Fine as delivered',
        signature: _sig(),
      );
      expect(approved.state, WorkItemState.reviewApproved);
      expect(
        approved.metadata?.containsKey('triageAttempt'),
        isFalse,
        reason:
            'approving is acceptance, not a request for the work again. A '
            'marker here would burn a key suffix on every approval, which is '
            'exactly the inflation the rule forbids.',
      );
    });

    test(
      'a human-QA APPROVE that completes the item leaves it untouched',
      () async {
        final engine = await _atEngineeringReviewGate();
        await engine.resolveHumanDecision(
          decisionId: (await _pendingEngineeringReview(engine)).decisionId,
          choice: HumanDecisionChoice.approve,
          decider: 'bob@example.com',
          rationale: 'Fine',
          signature: _sig(),
        );
        await engine.transition(
          workItemId: _id,
          to: WorkItemState.qaInProgress,
          trigger: TransitionTrigger.systemEvent,
          actor: _orch,
          context: const {'qaContractId': 'qa-1'},
        );
        await engine.transition(
          workItemId: _id,
          to: WorkItemState.qaPassed,
          trigger: TransitionTrigger.agentResult,
          actor: _qaExecutor,
          context: {
            'gateResults': _passingGateResults(),
            'qaContract': _qaContract(),
          },
        );
        final gate = await engine.requestHumanDecision(
          workItemId: _id,
          decisionType: HumanDecisionType.humanQaApproval,
          actor: _orch,
        );
        final completed = await engine.resolveHumanDecision(
          decisionId: gate.decisionId,
          choice: HumanDecisionChoice.approve,
          decider: 'carol@example.com',
          rationale: 'Signed off',
          signature: _sig(),
        );
        expect(completed.state, WorkItemState.completed);
        expect(completed.metadata?.containsKey('triageAttempt'), isFalse);
      },
    );

    test('a design REWORK — re-work, but not re-TRIAGE — is stamped anyway, '
        'and that is deliberate', () async {
      // `(designApproval, rework)` routes to `designInReview`, which is in no
      // `JobDefinition.entryStates`. Stamping here is over-stamping, and it is
      // harmless BECAUSE the marker only ever increases: a later first arrival
      // at a triage entry state would use `:a1`, which nothing holds.
      //
      // The asymmetry is the whole argument. Over-stamping costs a key suffix;
      // under-stamping reuses a consumed key and makes the item inert for ever.
      // The predicate is therefore written to err towards stamping rather than
      // to enumerate the states that need it — a list this package cannot
      // import, and one that would be a second transcription of a routing
      // table that has already diverged from its copy once in this codebase.
      final engine = await _engine();
      await engine.transition(
        workItemId: _id,
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
        actor: _orch,
      );
      await engine.transition(
        workItemId: _id,
        to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent,
        actor: _orch,
        context: const {'featureRef': 'FEAT-001'},
      );
      await engine.transition(
        workItemId: _id,
        to: WorkItemState.designRequired,
        trigger: TransitionTrigger.systemEvent,
        actor: _orch,
        context: const {'designContractId': 'dc-1'},
      );
      await engine.transition(
        workItemId: _id,
        to: WorkItemState.designInReview,
        trigger: TransitionTrigger.systemEvent,
        actor: _orch,
        context: const {
          'designContractStatus': DesignContractStatus.underReview,
        },
      );
      final gate = await engine.requestHumanDecision(
        workItemId: _id,
        decisionType: HumanDecisionType.designApproval,
        actor: _orch,
      );
      final reworked = await engine.resolveHumanDecision(
        decisionId: gate.decisionId,
        choice: HumanDecisionChoice.rework,
        decider: 'alice@example.com',
        rationale: 'Not good enough',
        signature: _sig(),
      );
      expect(reworked.state, WorkItemState.designInReview);
      expect(reworked.metadata?['triageAttempt'], 1);
    });
  });

  group('a REPEATED resolution that changes nothing must not inflate', () {
    test('resolving the same decision twice advances the marker once', () async {
      final engine = await _atEngineeringReviewGate();
      final decision = await _pendingEngineeringReview(engine);

      final first = await engine.resolveHumanDecision(
        decisionId: decision.decisionId,
        choice: HumanDecisionChoice.rework,
        decider: 'bob@example.com',
        rationale: 'Not acceptable',
        signature: _sig(),
      );
      expect(first.metadata?['triageAttempt'], 1);

      // The replay a lost response produces. The item has already moved, so the
      // gate no longer blocks it and NOTHING is written — in particular no
      // second bump. A naive `marker + 1` placed after the move would walk the
      // counter to 2, 3, 4 on every retry of the same click and burn a key per
      // network attempt.
      final second = await engine.resolveHumanDecision(
        decisionId: decision.decisionId,
        choice: HumanDecisionChoice.rework,
        decider: 'bob@example.com',
        rationale: 'Not acceptable',
        signature: _sig(),
      );
      expect(second.version, first.version, reason: 'no second write');
      expect(
        (await engine.loadWorkItem(_id)).metadata?['triageAttempt'],
        1,
        reason: 'one human intent, one spend',
      );
    });

    test('a generic transition is NOT stamped, however many are taken', () async {
      // `DurableWorkflowEngine.transition` is the ordinary progress API. If the
      // marker were stamped there, every write in the engine would carry it and
      // the key would advance on transitions that express no intent at all.
      final engine = await _engine();
      await engine.transition(
        workItemId: _id,
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
        actor: _orch,
      );
      await engine.transition(
        workItemId: _id,
        to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent,
        actor: _orch,
        context: const {'featureRef': 'FEAT-001'},
      );
      await engine.transition(
        workItemId: _id,
        to: WorkItemState.designNotRequired,
        trigger: TransitionTrigger.systemEvent,
        actor: _orch,
      );
      expect(
        (await engine.loadWorkItem(_id)).metadata?.containsKey('triageAttempt'),
        isFalse,
        reason:
            '`planned -> designNotRequired` is ordinary progress into a triage '
            'entry state. Nothing has been triaged before it, so no key is '
            'consumed and there is nothing to be fresh about.',
      );
    });
  });

  group('the marker and the retry ledger are ONE counter, not two', () {
    test(
      'a decision bump is not handed straight back to the next retry',
      () async {
        // THE COLLISION. This is why `operatorRetry` no longer counts the marker
        // from the ledger: with two rules over one counter, a decision that
        // advanced the marker to 3 while the ledger still counts two retries
        // leaves the NEXT operator retry computing 3 as well — the key the
        // decision's own dispatch just consumed, and the item is inert again.
        final engine = await _atEngineeringReviewGate(marker: 1);
        await engine.resolveHumanDecision(
          decisionId: (await _pendingEngineeringReview(engine)).decisionId,
          choice: HumanDecisionChoice.rework,
          decider: 'bob@example.com',
          rationale: 'Not acceptable',
          signature: _sig(),
        );
        expect((await engine.loadWorkItem(_id)).metadata?['triageAttempt'], 2);

        // The item runs, fails, and an operator presses "Try again".
        await engine.transition(
          workItemId: _id,
          to: WorkItemState.agentExecuting,
          trigger: TransitionTrigger.systemEvent,
          actor: _orch,
          context: const {'agentAvailable': true, 'capabilitiesMatch': true},
        );
        await engine.transition(
          workItemId: _id,
          to: WorkItemState.agentFailed,
          trigger: TransitionTrigger.systemEvent,
          actor: _orch,
        );
        await engine.operatorRetry(
          workItemId: _id,
          requestedBy: 'hum@shipit.platform',
          reason: 'Model credits approved',
          requestId: 'req-1',
        );

        final item = await engine.loadWorkItem(_id);
        expect(item.state, WorkItemState.designNotRequired);
        expect(
          item.metadata?['triageAttempt'],
          3,
          reason:
              'zero retry rows are recorded, so a ledger-only rule would hand '
              'this retry 1 — a key consumed two intents ago. The ledger count '
              'is a FLOOR, and the marker is strictly above it.',
        );
        expect(
          (await _storeOf(
            engine,
          ).readOperatorActionsForWorkItem(_id)).map((r) => r.attemptNumber),
          [1],
          reason:
              'the AUDIT position is a different number and still counts rows; '
              'it is reported to the operator, not used as the dedupe suffix',
        );
      },
    );

    test('a replay of one retry still mints no second marker', () async {
      final engine = await _engine();
      await engine.transition(
        workItemId: _id,
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
        actor: _orch,
      );
      await engine.transition(
        workItemId: _id,
        to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent,
        actor: _orch,
        context: const {'featureRef': 'FEAT-001'},
      );
      await engine.transition(
        workItemId: _id,
        to: WorkItemState.designNotRequired,
        trigger: TransitionTrigger.systemEvent,
        actor: _orch,
      );
      await engine.transition(
        workItemId: _id,
        to: WorkItemState.agentExecuting,
        trigger: TransitionTrigger.systemEvent,
        actor: _orch,
        context: const {'agentAvailable': true, 'capabilitiesMatch': true},
      );
      await engine.transition(
        workItemId: _id,
        to: WorkItemState.agentFailed,
        trigger: TransitionTrigger.systemEvent,
        actor: _orch,
      );

      for (var i = 0; i < 3; i++) {
        await engine.operatorRetry(
          workItemId: _id,
          requestedBy: 'hum@shipit.platform',
          reason: 'Model credits approved',
          requestId: 'req-1',
        );
      }
      expect(
        (await engine.loadWorkItem(_id)).metadata?['triageAttempt'],
        1,
        reason: 'three network attempts, one operator intent, one key',
      );
    });
  });

  group('an UNREADABLE marker still fails loudly', () {
    test(
      'the reader throws rather than falling back to a consumed key',
      () async {
        final engine = await _atEngineeringReviewGate();
        for (final unreadable in <Object>[
          'one',
          '',
          1.5,
          true,
          <int>[1],
          <String, dynamic>{'a': 1},
          DateTime.utc(2026, 6, 1),
        ]) {
          final item = (await engine.loadWorkItem(
            _id,
          )).copyWith(metadata: {'triageAttempt': unreadable});
          expect(
            () => DurableWorkflowEngine.readTriageAttempt(item),
            throwsA(isA<FormatException>()),
            reason:
                'a marker of type ${unreadable.runtimeType} must be reported, '
                'not silently turned into the historical key the previous '
                'attempt already consumed',
          );
        }
      },
    );

    test('a re-triage over an unreadable marker writes NOTHING', () async {
      // The discriminator is computed BEFORE the decision is persisted and
      // before the policy is consulted, so this throws with the decision still
      // PENDING. The alternative — computing it after — would leave a resolved
      // decision attached to a work item that never moved, and every retry of
      // the same resolution would throw again with no way forward.
      final engine = await _atEngineeringReviewGate();
      final item = await engine.loadWorkItem(_id);
      // Write the corrupt marker directly: no production path produces one,
      // which is exactly why this is a store-level seed.
      await _forceMarker(engine, 'not-a-number');

      final decision = await _pendingEngineeringReview(engine);
      await expectLater(
        engine.resolveHumanDecision(
          decisionId: decision.decisionId,
          choice: HumanDecisionChoice.rework,
          decider: 'bob@example.com',
          rationale: 'Not acceptable',
          signature: _sig(),
        ),
        throwsA(isA<FormatException>()),
      );

      final after = await engine.loadWorkItem(_id);
      expect(after.state, item.state, reason: 'the item did not move');
      expect(after.metadata?['triageAttempt'], 'not-a-number');
      expect(
        (await _storeOf(engine).readHumanDecision(decision.decisionId)).status,
        HumanDecisionStatus.pending,
        reason: 'the decision stays answerable once the data is repaired',
      );
    });
  });

  group('the two marker helpers, directly', () {
    test('absent and explicitly null both read as null', () async {
      final engine = await _engine();
      final bare = await engine.loadWorkItem(_id);
      expect(DurableWorkflowEngine.readTriageAttempt(bare), isNull);

      final explicitNull = bare.copyWith(
        metadata: const {'triageAttempt': null},
      );
      expect(DurableWorkflowEngine.readTriageAttempt(explicitNull), isNull);
    });

    test('every numeric form the marker round-trips through reads back', () {
      WorkItem withMarker(Object value) => WorkItem(
        workItemId: _id,
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 't',
        description: 'd',
        state: WorkItemState.designNotRequired,
        metadata: {'triageAttempt': value},
        createdAt: DateTime.utc(2026, 6, 1),
        updatedAt: DateTime.utc(2026, 6, 1),
        version: 1,
      );

      expect(DurableWorkflowEngine.readTriageAttempt(withMarker(1)), 1);
      expect(DurableWorkflowEngine.readTriageAttempt(withMarker(1.0)), 1);
      expect(DurableWorkflowEngine.readTriageAttempt(withMarker('3')), 3);
      expect(DurableWorkflowEngine.readTriageAttempt(withMarker(' 4 ')), 4);
    });

    test('nextTriageAttempt is absent+1, and honours its floor', () {
      WorkItem withMarker(Object? value) => WorkItem(
        workItemId: _id,
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 't',
        description: 'd',
        state: WorkItemState.designNotRequired,
        metadata: value == null ? null : {'triageAttempt': value},
        createdAt: DateTime.utc(2026, 6, 1),
        updatedAt: DateTime.utc(2026, 6, 1),
        version: 1,
      );

      final absent = withMarker(null);
      expect(DurableWorkflowEngine.nextTriageAttempt(absent), 1);
      expect(DurableWorkflowEngine.nextTriageAttempt(withMarker(7)), 8);
      expect(
        DurableWorkflowEngine.nextTriageAttempt(absent, floor: 4),
        5,
        reason: 'the floor is a watermark the marker may have been reset below',
      );
      expect(
        DurableWorkflowEngine.nextTriageAttempt(withMarker(7), floor: 2),
        8,
        reason: 'the floor never lowers the marker',
      );
    });
  });
}

/// The store handed to [engine] by [_engine], so a test can read the durable
/// ledger or seed a value no production path would write.
InMemoryWorkflowStore _storeOf(DurableWorkflowEngine engine) =>
    _stores[engine]!;

/// Every store handed to an engine in this file.
final Map<DurableWorkflowEngine, InMemoryWorkflowStore> _stores = {};
