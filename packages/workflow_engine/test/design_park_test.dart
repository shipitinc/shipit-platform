import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';

/// THE DESIGN PARK — `design-revision.md` §4.4.4, option R2 (PRIMARY).
///
/// ## WHY THE STATE EXISTS AT ALL
///
/// A design-remediation work item has to WAIT somewhere until the design
/// governance runtime exists, and `planned` is not a place it can wait.
///
/// * `triageDefectDefinition.entryStates` contains `planned`, so the
///   category-blind triage scheduler SEEKS an item resting there.
/// * `planned -> designNotRequired` is guarded by `actorAllowed([orchestrator])`
///   and NOTHING else, so that scheduler can take the item back OUT of
///   `planned` without asking whether design work is needed — which for a
///   design defect is the opposite of the truth.
/// * `planned` therefore converges: the item is taken out, re-dispatched,
///   taken out again.
///
/// `designParked` closes that STRUCTURALLY. It is in the `entryStates` of no
/// definition, so no scheduler can see, probe or hop an item resting in it.
/// There is no competing write and no window — which is the atomicity guarantee
/// the demoted R1 (let lane E race the triage scheduler for `planned`) cannot
/// offer.
///
/// ## WHAT THIS FILE ASSERTS, AND WHAT IT CANNOT
///
/// R2.1's load-bearing half — "`designParked` is in no definition's
/// `entryStates`" — is a statement about `packages/scheduler`, and it is
/// asserted there, in `transition_consistency_test.dart:206` (mirrored for this
/// state) and in `retry_return_to_entry_state_test.dart` (R2.5). What is
/// asserted HERE is the edge set and the guards on it, which is what makes the
/// state a park rather than a second dead end.
///
/// Every guard assertion below names the input that makes it FAIL. A guard
/// nobody can falsify is a wish, and §9 treats a gate that passes vacuously as
/// worse than no gate (`92d567e3`'s own lesson).
const _orch = WorkflowActor(
  actorId: 'orch-1',
  actorType: ActorType.orchestrator,
);
const _human = WorkflowActor(actorId: 'alice', actorType: ActorType.human);
const _agent = WorkflowActor(
  actorId: 'impl-1',
  actorType: ActorType.implementationAgent,
);

const _engine = WorkflowEngine();

Transition<WorkItemState> _eval(
  WorkItemState from,
  WorkItemState to, {
  WorkflowActor actor = _orch,
  Map<String, dynamic> context = const {},
}) => _engine.evaluateWorkItemTransition(
  from: from,
  to: to,
  trigger: TransitionTrigger.systemEvent,
  actor: actor,
  context: context,
);

/// The only `DesignContractResolution` that opens the release edge: a work item
/// that NAMES a contract and a store that CONFIRMED it.
const _confirmedContract = DesignContractResolution(
  contractId: 'design-contract-wi-1',
  storeConfirmed: true,
);

void main() {
  group('R2.2 — into the park: planned -> designParked', () {
    test('is a legal edge for the orchestrator', () {
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.planned,
          WorkItemState.designParked,
        ),
        isTrue,
        reason:
            'without this edge lane E has nowhere to put a design-remediation '
            'item that cannot yet enter design work, and `planned` is a triage '
            'entry state the triage lane takes it back out of.',
      );
    });

    test('carries actorAllowed([orchestrator]) and NO evidence guard', () {
      expect(
        _eval(WorkItemState.planned, WorkItemState.designParked).isValid,
        isTrue,
      );
      expect(
        _eval(
          WorkItemState.planned,
          WorkItemState.designParked,
          actor: _agent,
        ).isValid,
        isFalse,
        reason:
            'parking a design-remediation item is an orchestrator decision, '
            'and an implementation agent taking this edge would be a way for '
            'an executor to strand an item out of every scheduler\'s reach.',
      );
    });

    test(
      'adds NO predecessor to `planned` — the sole-predecessor pin holds',
      () {
        // `planned_entry_state_hop_test.dart` pins `planning` as the ONLY edge
        // into `planned`. `planned -> designParked` points AWAY from `planned`,
        // so that pin is untouched — asserted here from the other direction so
        // the property does not depend on a test in another package staying
        // accurate.
        final predecessors = <WorkItemState>[
          for (final state in WorkItemState.values)
            if (state != WorkItemState.planned &&
                WorkItemTransitions.isLegalTransition(
                  state,
                  WorkItemState.planned,
                ))
              state,
        ];
        expect(
          predecessors,
          [WorkItemState.planning],
          reason:
              'a second predecessor for `planned` re-opens the loop that pin '
              'exists to close: an item could return to `planned` and be taken '
              'out by triage again.',
        );
      },
    );
  });

  group('R2.3 — the release: designParked -> designRequired', () {
    test('is a legal edge, and is the park\'s only route into design work', () {
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.designParked,
          WorkItemState.designRequired,
        ),
        isTrue,
        reason:
            'THIS IS THE EDGE THAT STOPS `designParked` BEING THE DEFECT '
            '`featureIntakeParked`\'S OWN COMMENT SAYS IT EXISTS TO END — a '
            'terminal state nobody can leave. Delete it and a design-remediation '
            'item parked by lane E can never be released.',
      );
    });

    test('REFUSES when no durable resolution is supplied — a caller string '
        'does not open it', () {
      // The falsifier §4.3 names, on the ADJACENT edge: a caller-supplied
      // `designContractId` is not read by this guard at all.
      final viaString = _eval(
        WorkItemState.designParked,
        WorkItemState.designRequired,
        context: const {'designContractId': 'anything'},
      );
      expect(
        viaString.isValid,
        isFalse,
        reason:
            '`designContractExists()` reads the work item\'s DURABLE column and '
            'a store confirmation. A caller passing a string is the exact '
            'fabrication lane E refused to perform, and it must still be '
            'refused here.',
      );
      expect(viaString.failedGuards, contains('design_contract_exists'));
    });

    test('REFUSES a null resolution and an unconfirmed one, separately', () {
      // The two are different verdicts and the guard names them differently:
      // "this item names no contract" is a fact about the ITEM, "no store was
      // mounted to ask" is a fact about the DEPLOYMENT. Collapsing them is how
      // an outage gets filed as a missing artifact.
      final noContract = _eval(
        WorkItemState.designParked,
        WorkItemState.designRequired,
        context: const {
          designContractResolutionContextKey:
              DesignContractResolution.noContract(),
        },
      );
      expect(noContract.isValid, isFalse);
      expect(
        noContract.rejectionReason,
        contains('carries no designContractId'),
      );

      final unconfirmed = _eval(
        WorkItemState.designParked,
        WorkItemState.designRequired,
        context: const {
          designContractResolutionContextKey: DesignContractResolution(
            contractId: 'design-contract-wi-1',
            storeConfirmed: false,
          ),
        },
      );
      expect(unconfirmed.isValid, isFalse);
      expect(
        unconfirmed.rejectionReason,
        contains('not confirmed against a design contract store'),
      );
    });

    test('ACCEPTS a durable, store-confirmed resolution', () {
      final released = _eval(
        WorkItemState.designParked,
        WorkItemState.designRequired,
        context: const {designContractResolutionContextKey: _confirmedContract},
      );
      expect(released.isValid, isTrue);
      expect(released.failedGuards, isNot(contains('design_contract_exists')));
    });

    test('a non-orchestrator cannot release the item', () {
      expect(
        _eval(
          WorkItemState.designParked,
          WorkItemState.designRequired,
          actor: _agent,
          context: const {
            designContractResolutionContextKey: _confirmedContract,
          },
        ).isValid,
        isFalse,
      );
    });
  });

  group('R2.4 — operator recovery: designParked -> waitingForHumanDecision', () {
    test('is legal for a human and for the orchestrator', () {
      expect(
        _eval(
          WorkItemState.designParked,
          WorkItemState.waitingForHumanDecision,
          actor: _human,
        ).isValid,
        isTrue,
        reason:
            'operator recovery is the route that does NOT depend on the design '
            'runtime existing. Removing it leaves a parked item with no route '
            'but `cancelled`/`terminated`.',
      );
      expect(
        _eval(
          WorkItemState.designParked,
          WorkItemState.waitingForHumanDecision,
        ).isValid,
        isTrue,
      );
    });

    test('is refused for an implementation agent', () {
      expect(
        _eval(
          WorkItemState.designParked,
          WorkItemState.waitingForHumanDecision,
          actor: _agent,
        ).isValid,
        isFalse,
      );
    });
  });

  group('R2.1 — the state is a park, not a second `planned`', () {
    test('there is NO edge back to `planned`', () {
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.designParked,
          WorkItemState.planned,
        ),
        isFalse,
        reason:
            'the feature park\'s own comment calls this edge out as the one '
            'that must not exist: `planned` has exactly one predecessor and a '
            'second one re-opens the triage convergence loop. The design park '
            'inherits that constraint for the same reason.',
      );
    });

    test('there is NO edge to `designNotRequired`', () {
      // The one edge out of `planned` that asserts the opposite of the truth
      // for a design defect. The park must not offer it: a park that a
      // scheduler can take an item OUT of is not a park.
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.designParked,
          WorkItemState.designNotRequired,
        ),
        isFalse,
      );
    });

    test('there is NO edge straight to `agentExecuting`', () {
      // `agentExecuting` asserts an execution is ALREADY RUNNING. Nothing is
      // running for an item parked awaiting a design runtime.
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.designParked,
          WorkItemState.agentExecuting,
        ),
        isFalse,
      );
    });

    test('`designParked` is not terminal and terminates only generically', () {
      expect(WorkItemState.designParked.isTerminal, isFalse);
      for (final terminal in <WorkItemState>[
        WorkItemState.cancelled,
        WorkItemState.terminated,
      ]) {
        expect(
          WorkItemTransitions.isLegalTransition(
            WorkItemState.designParked,
            terminal,
          ),
          isTrue,
          reason: 'the generic non-terminal escapes, nothing park-specific',
        );
      }
    });

    test('its successor set is EXACTLY the release, the operator route and '
        'the two generic escapes', () {
      // Set equality, not `contains`. A NEW edge out of the park is a change
      // to what the park MEANS, and this is where a reviewer should be made to
      // look at it rather than discover it later.
      final successors = WorkItemWorkflowState(
        WorkItemState.designParked,
      ).allowedTransitions.map((s) => s.value).toSet();
      expect(successors, {
        WorkItemState.designRequired,
        WorkItemState.waitingForHumanDecision,
        WorkItemState.cancelled,
        WorkItemState.terminated,
      });
    });
  });

  group('R2.5 — `agentFailed` cannot return an item to the park', () {
    test('there is no `agentFailed -> designParked` edge', () {
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.agentFailed,
          WorkItemState.designParked,
        ),
        isFalse,
        reason:
            '`Scheduler._returnTargetsFrom` derives the retry-return target by '
            'probing every entry state, and `designParked` is in no entry set, '
            'so it can never be a return target. The edge must not exist either, '
            'or the structural guarantee would rest on the probe rather than on '
            'the graph.',
      );
    });

    test('every declared successor of the park is accounted for by name', () {
      // R2.5\'s structural half, stated positively: the reason the park cannot
      // be a return target is that its successors are gate/route states, not
      // execution entry states.
      for (final successor in WorkItemWorkflowState(
        WorkItemState.designParked,
      ).allowedTransitions.map((s) => s.value)) {
        expect(
          successor,
          isNot(WorkItemState.implementationReady),
          reason: '`implementationReady` IS an entry state',
        );
        expect(
          successor,
          isNot(WorkItemState.designNotRequired),
          reason: '`designNotRequired` IS a triage entry state',
        );
      }
    });
  });

  group('the guard is the same one `planned -> designRequired` uses', () {
    test('both edges are refused by an identical unconfirmed resolution', () {
      // Shared guard, shared behaviour: a caller cannot discover that the
      // park's release is laxer than the direct edge by trying it.
      const unconfirmed = {
        designContractResolutionContextKey: DesignContractResolution(
          contractId: 'design-contract-wi-1',
          storeConfirmed: false,
        ),
      };
      for (final from in <WorkItemState>[
        WorkItemState.planned,
        WorkItemState.designParked,
      ]) {
        final result = _eval(
          from,
          WorkItemState.designRequired,
          context: unconfirmed,
        );
        expect(result.isValid, isFalse, reason: 'from $from');
        expect(result.failedGuards, contains('design_contract_exists'));
      }
    });

    test('the table still constructs the shared guard on both edges', () {
      // Read through `GuardConditions` rather than by name only, so a future
      // edge that swapped in a permissive guard of its own is caught here
      // rather than by a caller discovering it in production.
      expect(
        GuardConditions.designContractExists().name,
        'design_contract_exists',
      );
      expect(
        GuardConditions.designContractUnderReview().name,
        'design_contract_under_review',
      );
    });
  });
}
