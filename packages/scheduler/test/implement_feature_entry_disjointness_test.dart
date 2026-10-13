import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';

/// The A1/A2 dispatch collision is UNREACHABLE BY CONSTRUCTION, and this is
/// the file that proves it.
///
/// ## The defect this prevents
///
/// `Scheduler.tick` reads EVERY work item in the store (`readAllWorkItems`)
/// and enqueues for every one the policy calls `runnable`. `RunnableWorkEvaluator`
/// performs **no job-type check and no product-state check**: it reads
/// `item.state`, asks whether it is in `definition.entryStates`, and asks the
/// policy. Two definitions sharing one entry state therefore BOTH classify the
/// same item runnable in the same tick, two jobs are minted, and whichever wins
/// the claim CAS starts an agent against an item the other lane was going to
/// classify. That was the observed failure: a triage job and an implementation
/// job contending for one defect.
///
/// ## Why the guarantee is STRUCTURAL and not guarded
///
/// The argument has exactly two steps, and neither is a guard anybody can
/// forget:
///
///  1. `RunnableWorkEvaluator.evaluate` returns `noAction` for any state not in
///     `definition.entryStates` — before the policy is consulted, before any
///     probe, before any capability question.
///  2. `EntryHopper.prepare` is only reached from inside the `runnable` arm of
///     `tick`, and may only land a hop on **its own definition's** entry states
///     (`_refusalFor`, `policy/entry_hop.dart`). So a hop cannot be the
///     mechanism that carries an item from one definition's entry set into
///     another's.
///
/// Disjoint sets make step 1 fire for whichever definition does not own the
/// state, and step 2 stops the hop from undoing it. A guard would be a third
/// thing to forget; this is a property of two data structures.
///
/// ## Why the test enumerates definitions rather than naming two
///
/// Naming only `triageDefectDefinition` would leave the guarantee resting on an
/// enumeration that a future definition silently escapes. Every production
/// definition this package ships is listed, and a new one that is not listed
/// fails `entry_hop_drift_guard_test.dart` — the two files cross-check each
/// other, so there is no way to add a definition and miss both.
///
/// ## The pre-existing overlaps are RECORDED, not excluded
///
/// `defaultImplementFeatureDefinition` already overlapped
/// `triageDefectDefinition` on `designNotRequired` and `designApproved` before
/// this lane existed, and `onboardProductDefinition` overlaps them too. Both
/// are accounted for and neither is swept under the rug:
///
///  * `defaultImplementFeatureDefinition` is **test-only in production**. Its
///    sole non-test reference is its own definition site; it is what roughly
///    twenty test files use as a generic host. Two definitions contending for
///    one item needs both of them to be DRIVEN, and nothing drives it.
///  * `onboardProductDefinition` is dispatched per `JobType` by
///    `BaselineProductDispatcher`, not by a `Scheduler`. It never asks
///    `RunnableWorkEvaluator` about a work item at all, so it cannot join a
///    tick-time collision. `entry_hop_drift_guard_test.dart` already declines to
///    list it for exactly this reason.
///
/// So the assertion below is scoped to what the structural argument actually
/// covers — the new definition against every other — and the pre-existing
/// overlaps are pinned by their own test so that republishing one of them into
/// a production lane is a named failure rather than a silent one.
void main() {
  /// Every production definition this package ships. Kept in step with
  /// `entry_hop_drift_guard_test.dart`'s own list, deliberately: that test is
  /// what fails if a definition is added and this one is not.
  const definitions = <JobDefinition>[
    defaultImplementFeatureDefinition,
    implementFeatureDefinition,
    triageDefectDefinition,
    designRevisionDefinition,
    designReviewDefinition,
    engineeringReviewDefinition,
    onboardProductDefinition,
  ];

  /// `Set` has no set algebra in Dart core, so an intersection is spelled once
  /// here rather than three times inline.
  Set<WorkItemState> shared(JobDefinition a, JobDefinition b) =>
      a.entryStates.where(b.entryStates.contains).toSet();

  group('the implementation entry state belongs to one definition only', () {
    test('implementFeatureDefinition declares exactly one entry state', () {
      expect(implementFeatureDefinition.entryStates, {
        WorkItemState.implementationReady,
      });
    });

    test('no other production definition lists implementationReady', () {
      final claimants = definitions
          .where((d) => d != implementFeatureDefinition)
          .where(
            (d) => d.entryStates.contains(WorkItemState.implementationReady),
          )
          .map((d) => d.jobType.wire)
          .toList();

      expect(
        claimants,
        isEmpty,
        reason:
            'these definitions also list implementation_ready, so one work '
            'item sitting there is runnable for each of them in the same tick '
            'and both lanes contend for it: $claimants',
      );
    });

    test('the implementation entry set is disjoint from EVERY other one', () {
      final overlaps = <String>[];
      for (final other in definitions.where(
        (d) => d != implementFeatureDefinition,
      )) {
        final shared =
            implementFeatureDefinition.entryStates
                .where(other.entryStates.contains)
                .map((s) => s.wire)
                .toList()
              ..sort();
        if (shared.isNotEmpty) {
          overlaps.add('${other.jobType.wire}: $shared');
        }
      }

      expect(
        overlaps,
        isEmpty,
        reason:
            'two definitions sharing an entry state can both classify one item '
            'runnable in one tick, which is the collision this lane exists to '
            'make unreachable: $overlaps',
      );
    });

    test('the two pre-existing overlaps are pinned, not inherited silently', () {
      // Recorded so they cannot be rediscovered as a surprise and so that
      // promoting either of these definitions into a production lane is a named
      // failure. `defaultImplementFeatureDefinition` is test-only and
      // `onboardProductDefinition` is dispatched per `JobType` rather than by a
      // `Scheduler`; both reasons are stated in this file's own header.
      expect(
        shared(defaultImplementFeatureDefinition, triageDefectDefinition),
        {WorkItemState.designNotRequired, WorkItemState.designApproved},
        reason:
            'this overlap is the reason implementFeatureDefinition had to be a '
            'SIBLING rather than a widening of the existing definition. If this '
            'expectation starts failing, the pre-existing condition was changed '
            'and the structural argument in this file\'s header must be re-read',
      );
      expect(
        shared(onboardProductDefinition, triageDefectDefinition),
        {WorkItemState.designNotRequired},
        reason:
            'onboarding is dispatched per JobType by BaselineProductDispatcher '
            'and never asks RunnableWorkEvaluator about a work item, so it '
            'cannot join a tick-time collision',
      );
      expect(
        implementFeatureDefinition.jobType,
        defaultImplementFeatureDefinition.jobType,
        reason:
            'they are siblings over one JobType on purpose — the wire contract '
            'the composition seeds per role must not fork just because the entry '
            'set did',
      );
      expect(
        defaultImplementFeatureDefinition.entryStates,
        {WorkItemState.designNotRequired, WorkItemState.designApproved},
        reason:
            'design brief §7.2 / D-11: the existing definition must NOT be '
            'repurposed. It is const, test-only in production, and about twenty '
            'test files use it as a generic host; widening or renaming it would '
            'churn all of them for no production benefit. A sibling was added '
            'beside it instead, and this assertion is what makes "beside" mean '
            'unchanged rather than "on top of"',
      );
      expect(
        defaultImplementFeatureDefinition.requiredCapabilities,
        {WorkerCapability.linux},
        reason:
            'the git capability belongs to the NEW definition only. Changing '
            'the old one would silently change what roughly twenty test hosts '
            'register their workers with',
      );
    });
  });

  group('the evaluator cannot be runnable for two definitions at once', () {
    const engine = WorkflowEngine();
    final evaluator = RunnableWorkEvaluator(policy: engine);

    WorkItem itemAt(WorkItemState state) {
      final now = DateTime.utc(2026);
      return WorkItem(
        workItemId: 'wi-collision',
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'A fixture used only to ask the evaluator about a state',
        description: 'The evaluator reads the state and nothing else.',
        state: state,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('an item at implementation_ready is runnable for exactly one job', () {
      final runnableFor = definitions
          .where(
            (d) =>
                evaluator.evaluate(
                  itemAt(WorkItemState.implementationReady),
                  d,
                ) ==
                RunnableWorkStatus.runnable,
          )
          .map((d) => d.jobType.wire)
          .toList();

      expect(runnableFor, [JobType.implementFeature.wire]);
    });

    test(
      'an item at a triage entry state is never runnable for implementation',
      () {
        for (final entry in triageDefectDefinition.entryStates) {
          expect(
            evaluator.evaluate(itemAt(entry), implementFeatureDefinition),
            isNot(RunnableWorkStatus.runnable),
            reason:
                '${entry.wire} is a triage entry state and the implementation '
                'definition also calls it runnable, so the same item is '
                'dispatchable by both lanes in one tick',
          );
        }
      },
    );

    test('the policy is asked about the implementation edge, not bypassed', () {
      // The probe is live: `implementationReady -> agentExecuting` is a real
      // edge with guards the scheduler's own context satisfies. If the bypass
      // were ever set, this would still pass — which is why the next test
      // asserts the bypass itself rather than the outcome.
      expect(implementFeatureDefinition.skipWorkflowPolicyCheck, isFalse);
      expect(
        engine
            .evaluateWorkItemTransition(
              from: WorkItemState.implementationReady,
              to: WorkItemState.agentExecuting,
              trigger: TransitionTrigger.systemEvent,
              actor: schedulerOrchestratorActor,
              context: const {
                'agentAvailable': true,
                'capabilitiesMatch': true,
              },
            )
            .isValid,
        isTrue,
        reason:
            'the direct edge the drift guard relies on must be one the policy '
            'accepts in the scheduler\'s context',
      );
    });
  });

  group('the entry edge asserts only what its own table says it does', () {
    test('the implementation edge carries the two execution-edge guards', () {
      final transition = const WorkflowEngine().evaluateWorkItemTransition(
        from: WorkItemState.implementationReady,
        to: WorkItemState.agentExecuting,
        trigger: TransitionTrigger.systemEvent,
        actor: schedulerOrchestratorActor,
        context: const {'agentAvailable': true, 'capabilitiesMatch': true},
      );
      expect(transition.isValid, isTrue);
      // `qaContractExists()` is deliberately NOT here: the scheduler has no
      // `qaContractId` to supply, so requiring it would make the edge
      // unreachable from the scheduler and every dispatch would be refused by
      // the coordinator at the cost of a real worker execution. Whether an item
      // may be dispatched without a QA contract is `OD-5`, and this edge does
      // not decide it.
      final passed = transition.guardResults
          .where((g) => g.passed)
          .map((g) => g.name)
          .toList();
      expect(passed, contains('actor_allowed'));
      expect(
        transition.failedGuards,
        isEmpty,
        reason: 'the scheduler\'s own context must satisfy every guard here',
      );
      expect(
        passed,
        isNot(contains('qa_contract_exists')),
        reason:
            'qaContractExists belongs on the EXIT edge. On the entry edge the '
            'scheduler has no qaContractId to supply, so requiring it would '
            'make every implementation dispatch unreachable',
      );
    });

    test('without an agent the implementation edge refuses to start one', () {
      final transition = const WorkflowEngine().evaluateWorkItemTransition(
        from: WorkItemState.implementationReady,
        to: WorkItemState.agentExecuting,
        trigger: TransitionTrigger.systemEvent,
        actor: schedulerOrchestratorActor,
        context: const {'agentAvailable': false},
      );
      expect(transition.isValid, isFalse);
    });
  });
}
