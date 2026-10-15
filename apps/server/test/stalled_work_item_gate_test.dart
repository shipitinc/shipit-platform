import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart' show SchedulerStall;
import 'package:control_plane_server/src/triage/stalled_work_item_gate.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

/// THE PROOF that a scheduler stall reaches a human, and that a human can
/// recover the item.
///
/// ## WHAT WAS MISSING
///
/// `SchedulerTickResult.stalled` carries a structured, operator-facing
/// conclusion — the lane has stopped producing work for an item and wants a
/// person. Before `apps/server/lib/src/triage/stalled_work_item_gate.dart` the
/// conclusion was written to `scheduler_event.payloadJson` and read by nobody,
/// while the item's state said `agent_completed` and every operator screen
/// called it "Awaiting review". See
/// `docs/engineering/learning/236-transition-rows-that-moved-nothing.md` §6.
///
/// ## WHY A HUMAN DECISION, AND NOT A NEW ENDPOINT
///
/// Because the existing decision screen already renders an `escalation` gate's
/// options as "Resume" and "Stop this work" and submits them through
/// `resolveDecision`. Raising that decision is what makes the conclusion
/// reachable by an operator with NO new surface invented — and resolving it is
/// what makes the item retryable. A new endpoint would have been a second way
/// to reach the server from the feature layer, and the repository already
/// documents that class of defect.
void main() {
  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine engine;
  late InMemoryExecutionStore executionStore;

  setUp(() {
    workflowStore = InMemoryWorkflowStore();
    engine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();
  });

  final t0 = DateTime.utc(2026, 1, 1);

  SchedulerStall stall({String workItemId = 'wi-1'}) => SchedulerStall(
    workItemId: workItemId,
    state: WorkItemState.agentCompleted,
    jobType: JobType.engineeringReview,
    deferrals: 3,
    reason:
        'this lane has burned its supersession-deferral budget and has stopped '
        'launching work for this item until somebody says why',
  );

  /// A work item parked at `agentCompleted` the way the completion path leaves
  /// it: real `agentExecuting -> agentCompleted` edge, real producer stamped.
  Future<void> readyItemAtAgentCompleted() async {
    await engine.createWorkItem(
      workItemId: 'wi-1',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'The work that cannot complete an execution',
      description:
          'This work item cannot complete an execution and needs a person to look at it.',
      qaContractId: 'qa-1',
      featureRef: 'feature/calc',
    );
    for (final state in [
      WorkItemState.planning,
      WorkItemState.planned,
      WorkItemState.designNotRequired,
      WorkItemState.agentExecuting,
    ]) {
      await engine.transition(
        workItemId: 'wi-1',
        to: state,
        trigger: TransitionTrigger.systemEvent,
        // `designNotRequired -> agentExecuting` carries the agent-availability
        // guards, so the walk must supply them to reach `agent_completed` at
        // all — exactly as the production entry transition does.
        context: const {
          'featureRef': 'feature/calc',
          'agentAvailable': true,
          'capabilitiesMatch': true,
        },
      );
    }
    await executionStore.saveExecution(
      AgentExecution(
        executionId: 'exec-impl',
        workItemId: 'wi-1',
        requestId: 'exec-impl',
        runtimeTypeId: 'fake',
        role: AgentRole.implementer,
        status: AgentSessionStatus.completed,
        workspace: AgentWorkspace(workspaceId: 'ws-1', path: '/tmp/ws-1'),
        startedAt: t0,
        version: 1,
      ),
    );
    await executionStore.saveResult(
      'exec-impl',
      AgentResult(
        resultId: 'res-exec-impl',
        sessionId: 'ses',
        workItemId: 'wi-1',
        status: AgentResultStatus.completed,
        artifacts: const [],
        diagnostics: const AgentDiagnostics(
          exitCode: 0,
          durationMs: 1,
          toolCalls: 0,
          errors: [],
          warnings: [],
        ),
        structuredResult: const {},
        completedAt: t0,
      ),
    );
    // The real completion path stamps the producer in the SAME transition that
    // moves the item, so this mirrors it rather than writing metadata directly.
    await engine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.agentCompleted,
      trigger: TransitionTrigger.agentResult,
      actor: const WorkflowActor(
        actorId: 'orchestrator',
        actorType: ActorType.orchestrator,
      ),
      context: {
        'qaContractId': 'qa-1',
        'agentResult': await executionStore.readResult('exec-impl'),
      },
      metadataMerge: const {'producerActorId': 'exec-impl'},
    );
  }

  group('the conclusion reaches a human', () {
    test(
      'a stall parks the item at the human gate with a BLOCKING '
      'decision carrying the facts',
      () async {
        await readyItemAtAgentCompleted();

        final outcome = await raiseStallDecision(
          workflowEngine: engine,
          executionStore: executionStore,
          stall: stall(),
        );
        expect(outcome, StallGateOutcome.raised);

        final item = await engine.loadWorkItem('wi-1');
        expect(
          item.state,
          WorkItemState.waitingForHumanDecision,
          reason:
              'the item must be in a state an operator screen already renders '
              'as "needs you". It was at agent_completed, which every screen '
              'called "Awaiting review"',
        );

        final decisions = await workflowStore.readHumanDecisionsForWorkItem(
          'wi-1',
        );
        expect(decisions, hasLength(1));
        final decision = decisions.single;
        expect(
          decision.decisionType,
          HumanDecisionType.engineeringReview,
          reason:
              'forced by the state machine: the only route from agent_completed '
              'to the human gate runs through reviewInProgress, and that edge '
              'requires a pending engineeringReview decision. Naming an '
              'escalation here would have meant adding an edge',
        );
        expect(decision.blocking, isTrue);
        expect(decision.status, HumanDecisionStatus.pending);
        expect(
          decision.options!.map((o) => o.optionId),
          containsAll(<String>['rework', 'cancel']),
          reason:
              'both answers must be offerable: the operator needs to retry the '
              'item once the cause is fixed, and to stop it',
        );
        expect(decision.question, contains('agent_completed'));
        expect(decision.question, contains('3 attempts'));

        // The structured facts travel BESIDE the prose, so a surface can render
        // them without parsing English.
        final recorded = decision.metadata![stalledWorkItemMetadataKey];
        expect(recorded['jobType'], JobType.engineeringReview.wire);
        expect(recorded['deferrals'], 3);
        expect(recorded['state'], WorkItemState.agentCompleted.wire);
      },
    );

    test(
      'a SECOND tick does not mint a second question — the scheduler re-reports '
      'a stall every 30s for as long as it holds',
      () async {
        await readyItemAtAgentCompleted();

        final first = await raiseStallDecisions(
          workflowEngine: engine,
          executionStore: executionStore,
          stalls: [stall()],
        );
        final second = await raiseStallDecisions(
          workflowEngine: engine,
          executionStore: executionStore,
          stalls: [stall()],
        );
        final third = await raiseStallDecisions(
          workflowEngine: engine,
          executionStore: executionStore,
          stalls: [stall()],
        );

        expect(first.raised, 1);
        expect(second.raised, 0);
        expect(second.alreadyPending, 1);
        expect(third.alreadyPending, 1);
        expect(
          await workflowStore.readHumanDecisionsForWorkItem('wi-1'),
          hasLength(1),
          reason:
              'three ticks, three reported stalls, ONE question. Without this '
              'the operator gets a new decision every 30 seconds and none of '
              'them are answerable',
        );
      },
    );

    test(
      'the drain is ordered by item id, so every tick writes the same way',
      () async {
        await engine.createWorkItem(
          workItemId: 'wi-2',
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'A second work item',
          description:
              'A second work item that the engine will never let this gate park.',
        );
        await readyItemAtAgentCompleted();

        final result = await raiseStallDecisions(
          workflowEngine: engine,
          executionStore: executionStore,
          stalls: [
            stall(workItemId: 'wi-2'),
            stall(),
          ],
        );

        expect(result.considered, 2);
        expect(result.notParkable, 1, reason: 'wi-2 is at draft, not parkable');
        expect(result.raised, 1);
      },
    );
  });

  group('the operator can recover the item', () {
    test(
      'resolving with `rework` returns the item to implementation_ready — the '
      "implementation lane's entry state, so the work is genuinely retried",
      () async {
        await readyItemAtAgentCompleted();
        await raiseStallDecision(
          workflowEngine: engine,
          executionStore: executionStore,
          stall: stall(),
        );

        final decision = (await workflowStore.readHumanDecisionsForWorkItem(
          'wi-1',
        )).single;

        final item = await engine.resolveHumanDecision(
          decisionId: decision.decisionId,
          choice: HumanDecisionChoice.rework,
          decider: 'operator@example.com',
          rationale: 'The producer lookup is fixed; resuming.',
          signature: DecisionSignature(
            algorithm: 'test',
            publicKey: 'test',
            signature: 'test',
            signedAt: t0,
          ),
        );

        expect(
          item.state,
          WorkItemState.implementationReady,
          reason:
              'engineeringReview/rework routes to implementationReady, the '
              "implementation lane's entry state. That IS the operator retry: "
              'the work runs again, a fresh producer runs, and it reaches '
              'agent_completed with a fresh producerActorId',
        );
        expect(item.blockingHumanDecisionId, isNull);
      },
    );

    test(
      'the recovery LIFTS the stall by evidence, not by a flag — the version '
      'moved past the one recorded when the stall fired',
      () async {
        await readyItemAtAgentCompleted();
        final versionAtStall = (await engine.loadWorkItem('wi-1')).version;

        await raiseStallDecision(
          workflowEngine: engine,
          executionStore: executionStore,
          stall: stall(),
        );
        final decision = (await workflowStore.readHumanDecisionsForWorkItem(
          'wi-1',
        )).single;
        await engine.resolveHumanDecision(
          decisionId: decision.decisionId,
          choice: HumanDecisionChoice.rework,
          decider: 'operator@example.com',
          rationale: 'fixed',
          signature: DecisionSignature(
            algorithm: 'test',
            publicKey: 'test',
            signature: 'test',
            signedAt: t0,
          ),
        );

        expect(
          (await engine.loadWorkItem('wi-1')).version,
          greaterThan(versionAtStall),
          reason:
              'this is the whole recovery contract. `Scheduler` lifts a stall '
              'when WorkItem.version moves past the recorded one, so the '
              'operator needs no "clear the stall" control and there is no '
              'flag anybody has to remember to reset',
        );
      },
    );

    test('resolving with `cancel` stops the work outright', () async {
      await readyItemAtAgentCompleted();
      await raiseStallDecision(
        workflowEngine: engine,
        executionStore: executionStore,
        stall: stall(),
      );
      final decision = (await workflowStore.readHumanDecisionsForWorkItem(
        'wi-1',
      )).single;

      final item = await engine.resolveHumanDecision(
        decisionId: decision.decisionId,
        choice: HumanDecisionChoice.cancel,
        decider: 'operator@example.com',
        rationale: 'Not worth retrying.',
        signature: DecisionSignature(
          algorithm: 'test',
          publicKey: 'test',
          signature: 'test',
          signedAt: t0,
        ),
      );

      expect(item.state, WorkItemState.cancelled);
    });
  });

  group('what it refuses, and what it does NOT fabricate', () {
    test(
      'an item with NO readable producer result is NOT parked — nothing is '
      'fabricated to satisfy the entry guard',
      () async {
        await engine.createWorkItem(
          workItemId: 'wi-1',
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'The work that cannot complete an execution',
          description:
              'A work item whose producer result is no longer readable at all.',
          qaContractId: 'qa-1',
          featureRef: 'feature/calc',
        );
        for (final state in [
          WorkItemState.planning,
          WorkItemState.planned,
          WorkItemState.designNotRequired,
          WorkItemState.agentExecuting,
        ]) {
          await engine.transition(
            workItemId: 'wi-1',
            to: state,
            trigger: TransitionTrigger.systemEvent,
            // Same guards the production entry transition supplies.
            context: const {
              'featureRef': 'feature/calc',
              'agentAvailable': true,
              'capabilitiesMatch': true,
            },
          );
        }
        // Reached agent_completed, then the producer's durable result became
        // unreadable. There is no producer evidence to park on.
        await engine.transition(
          workItemId: 'wi-1',
          to: WorkItemState.agentCompleted,
          trigger: TransitionTrigger.agentResult,
          actor: const WorkflowActor(
            actorId: 'orchestrator',
            actorType: ActorType.orchestrator,
          ),
          context: {
            'qaContractId': 'qa-1',
            'agentResult': AgentResult(
              resultId: 'res',
              sessionId: 'ses',
              workItemId: 'wi-1',
              status: AgentResultStatus.completed,
              artifacts: const [],
              diagnostics: const AgentDiagnostics(
                exitCode: 0,
                durationMs: 1,
                toolCalls: 0,
                errors: [],
                warnings: [],
              ),
              structuredResult: const {},
              completedAt: t0,
            ),
          },
          metadataMerge: const {'producerActorId': 'exec-vanished'},
        );

        final outcome = await raiseStallDecision(
          workflowEngine: engine,
          executionStore: executionStore,
          stall: stall(),
        );

        expect(outcome, StallGateOutcome.producerEvidenceUnreadable);
        expect(
          (await engine.loadWorkItem('wi-1')).state,
          WorkItemState.agentCompleted,
          reason:
              'the item stays put. Forcing the `agentCompleted -> '
              'reviewInProgress` edge would mean fabricating the very result '
              'agentResultValid() exists to check — the review_repair lane '
              'already records how expensive that class of fabrication is',
        );
        expect(
          await workflowStore.readHumanDecisionsForWorkItem('wi-1'),
          isEmpty,
        );
      },
    );

    test(
      'an item at a state this gate may not park from writes nothing',
      () async {
        await engine.createWorkItem(
          workItemId: 'wi-9',
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'A work item that never ran',
          description:
              'A work item that never ran an agent and is still at its initial state.',
        );

        final result = await raiseStallDecisions(
          workflowEngine: engine,
          executionStore: executionStore,
          stalls: [stall(workItemId: 'wi-9')],
        );

        expect(result.notParkable, 1);
        expect(result.raised, 0);
        expect((await engine.loadWorkItem('wi-9')).state, WorkItemState.draft);
        expect(
          await workflowStore.readHumanDecisionsForWorkItem('wi-9'),
          isEmpty,
        );
      },
    );

    test('an empty stall list does nothing at all', () {
      expect(StallGateResult.empty.isEmpty, isTrue);
      expect(StallGateResult.empty.considered, 0);
    });
  });
}
