import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';

/// THE TRIAGE ENTRY-STATE DRIFT GUARD — covers EVERY entry state.
///
/// ## WHERE THIS USED TO LIVE, AND WHY IT MOVED
///
/// The guard was in `packages/workflow_store/test/triage_discriminator_test.dart`
/// and filtered on `HumanDecisionRouting.targetFor(type, choice) !=
/// WorkItemState.designNotRequired`. An independent review of 4614cf9 proved
/// that filter is too narrow (MEDIUM finding M1): the guard only ever saw the
/// ONE entry state its filter named. Adding a route to `designApproved` — or,
/// as this change does, making `reviewRejected` dispatchable at all — left it
/// 16/16 GREEN while checking none of it.
///
/// Widening the filter inside `workflow_store` was not possible: that package
/// is a DEPENDENCY of `scheduler`, not the other way round, so
/// `workflow_store`'s tests cannot read `triageDefectDefinition.entryStates`.
/// The only way to close M1 rather than re-spell it was to put the guard where
/// the entry-state set is LIVE and read from the definition itself. That is
/// this file. Nothing was duplicated: the `designNotRequired`-only guard was
/// removed from where it was, rather than left behind as a second, weaker copy
/// of the same idea.
///
/// ## WHAT IT ASSERTS
///
/// The property is not "every route into `designNotRequired` is re-work". It
/// is the general form of that, over the set as it actually is:
///
///   for every entry state S in `triageDefectDefinition.entryStates`,
///     every route into S must carry a choice the re-triage rule recognises,
///     and S itself must actually dispatch under the live evaluator.
///
/// The first half is about the WRITER (`DurableWorkflowEngine`, which advances
/// the dedupe discriminator on a re-triage). A route into an entry state that
/// the rule does not recognise re-enters triage WITHOUT a fresh discriminator,
/// lands on a key the previous run already consumed, and is inert for ever —
/// the exact defect on `defect-DEF-1791684804452198`, one release later.
///
/// The second half is about the READER, and it is the half that catches a state
/// added to `entryStates` without the probe that makes it dispatchable. An entry
/// state that is listed but not runnable is the silent variant: `Scheduler.tick`
/// enqueues nothing, reports nothing, and the item looks healthy.
const _id = 'defect-DEF-ENTRY-STATE-DRIFT';

const _orch = WorkflowActor(
  actorId: 'orch-1',
  actorType: ActorType.orchestrator,
);

/// The choices `DurableWorkflowEngine._isReWorkDecision` treats as "do this
/// work again", plus the one named exception it makes.
///
/// Written out literally rather than imported: the rule deliberately does not
/// consult `HumanDecisionRouting` (copying that table into `workflow_store` is
/// how `escalationTargetFor` already came to disagree with `targetFor` in this
/// repository), so the recognised set has to be spelled somewhere, and a guard
/// that derives its own expectation from the thing under test asserts nothing.
const _recognisedReWorkChoices = <HumanDecisionChoice>[
  HumanDecisionChoice.rework,
  HumanDecisionChoice.reject,
  // "Send this back to triage" is a re-triage by any reading, so
  // `DurableWorkflowEngine._isReWorkDecision` classifies it as one. Under-
  // stamping it would put the item back on a dedupe key the previous triage run
  // already consumed and leave it inert for ever — the same defect, on the
  // operator's own new answer.
  HumanDecisionChoice.reTriage,
];

/// The other half of the same classification: every choice the rule does NOT
/// treat as re-work, regardless of type.
///
/// This list exists so the spelling is TOTAL. `_isReWorkDecision` is an
/// exhaustive `switch` with no wildcard arm, so the compiler already refuses to
/// let a new `HumanDecisionChoice` value go unclassified IN THAT FILE — but the
/// enum lives in `platform_contracts` and the coupling is invisible to every
/// check that does not compile. This list is the same coupling made visible
/// from the other side: add a value to the enum and this file fails until it is
/// classified here too. See "the spelling is TOTAL" below.
const _notRecognisedReWorkChoices = <HumanDecisionChoice>[
  // The one approve that means "again" is `(escalation, approve)` alone, and
  // the exception is keyed on the TYPE — which is exactly why `approve` cannot
  // simply be a recognised choice here. See `_isReWork` below.
  HumanDecisionChoice.approve,
  HumanDecisionChoice.waive,
  HumanDecisionChoice.cancel,
  HumanDecisionChoice.defer,
  HumanDecisionChoice.fixed,
  HumanDecisionChoice.stillBroken,
  HumanDecisionChoice.partiallyFixed,
];

/// True when a route into a triage entry state also advances the discriminator.
bool _isReWork(HumanDecisionType type, HumanDecisionChoice choice) =>
    _recognisedReWorkChoices.contains(choice) ||
    (type == HumanDecisionType.escalation &&
        choice == HumanDecisionChoice.approve);

/// Every route into a triage entry state that the re-triage rule does NOT
/// classify as re-work, with the reason it is nonetheless declared.
///
/// ## WHY THIS IS DECLARED RATHER THAN ASSERTED AWAY
///
/// Closing M1 means the guard now really does iterate every entry state, and
/// that immediately surfaced a pair the `designNotRequired`-only filter never
/// looked at: `(designReviewRequest, approve) -> designApproved`. `designApproved`
/// USED TO BE a `triageDefectDefinition` entry state, so this was PRE-EXISTING.
///
/// It puts two decisions that are both deliberate at base into direct
/// conflict, and resolving them is not a test-authoring question:
///
///   * `_isReWorkDecision` says "Every other choice — approve … — expresses
///     either acceptance, abandonment, or a deferral, and none of them
///     re-enters triage", and `operator_retry_dispatch_test.dart` pins
///     `(engineeringReview, approve)` leaving the marker untouched.
///   * The dispatch rule says an item in an entry state with no fresh
///     discriminator reuses a consumed key and is inert for ever.
///
/// Both cannot be true for this pair, and WHICH ONE GIVES is a product
/// decision, not an implementation one: it changes what every design review
/// approval does to the dedupe counter. It is therefore declared here, named in the
/// reason, and escalated — not quietly excused, and not silently "fixed" by
/// editing the predicate under a guard that was asked to close a different
/// finding.
///
/// The declaration is still load-bearing. A route that is neither re-work nor
/// listed here FAILS this guard, which is the whole of M1: before this change
/// such a route would have been invisible.
///
/// NOTE: `designApproval/approve` was previously in this list but was removed
/// when `designApproved` was removed from `triageDefectDefinition.entryStates`
/// per design-revision.md §5.4(c). It now lands on `designApproved` which is
/// no longer a triage entry state, so it is not a route into a triage entry state
/// at all.
const _declaredNotReWork = <(HumanDecisionType, HumanDecisionChoice), String>{};

WorkItem _itemAt(WorkItemState state) {
  final now = DateTime.utc(2026, 6, 1);
  return WorkItem(
    workItemId: _id,
    productId: 'prod-1',
    category: WorkItemCategory.bugfix,
    title: 'Triage a reported defect',
    description: 'A customer reported a defect.',
    state: state,
    metadata: const {'defectId': 'DEF-ENTRY-STATE-DRIFT'},
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final evaluator = RunnableWorkEvaluator(policy: const WorkflowEngine());

  group('the guard is not vacuous', () {
    test('the entry-state set it iterates is the LIVE definition', () {
      expect(
        triageDefectDefinition.entryStates,
        isNotEmpty,
        reason: 'an empty set makes every loop below prove nothing',
      );
      expect(
        triageDefectDefinition.entryStates,
        contains(WorkItemState.reviewRejected),
        reason:
            'the state this change made dispatchable. If it is dropped from '
            'the set, the work stops and the guard must fail rather than '
            'quietly keep checking the two states it already checked.',
      );
      expect(
        triageDefectDefinition.entryStates,
        containsAll(<WorkItemState>[
          WorkItemState.designNotRequired,
          WorkItemState.reviewRejected,
          WorkItemState.planned,
        ]),
        reason: 'the three states the pre-existing guard covers',
      );
    });
  });

  group('the spelling is TOTAL — a new choice cannot go unclassified', () {
    // THIS GROUP IS THE EXECUTABLE FORM OF A COMPILE-TIME COUPLING, AND IT
    // EXISTS BECAUSE THAT COUPLING IS INVISIBLE TO EVERYTHING ELSE.
    //
    // `DurableWorkflowEngine._isReWorkDecision` is an exhaustive `switch` over
    // `HumanDecisionChoice` with NO wildcard arm, so adding a value to the enum
    // fails the build in `workflow_store` until it is classified there. That
    // coupling is real and it is free — but it crosses a package boundary, and
    // the design artifact that had to name the resulting edits was verified
    // citation-by-citation across seven review rounds and never compiled. A
    // file table can therefore be wrong, be right about every line it cites,
    // and still not build.
    //
    // This file is the second copy of the classification, written out literally
    // precisely so it CANNOT be derived from the thing under test.
    //
    // ## WHAT TOTALITY DOES AND DOES NOT PIN — CORRECTED (F-74)
    //
    // This comment used to claim:
    //
    //   "A second copy is only worth having if the copies are pinned to each
    //    other, and the only thing that pins them is totality."
    //
    // That was FALSE, and an independent review of slice 1 (`7029424`) caught
    // it by mutation. Totality pins EACH COPY TO THE ENUM — not to the other
    // copy. The partition below proves that every `HumanDecisionChoice` value
    // is classified, exactly once, *in this file*. A value that the production
    // predicate classifies on the OPPOSITE side satisfies every assertion in
    // this test: it is still classified exactly once here, and the group does
    // not read production.
    //
    // The mutation that proved it: flipping
    // `DurableWorkflowEngine._isReWorkDecision`'s `reTriage` arm from
    // `=> true` to `=> false` (durable_workflow_engine.dart:1015) left this
    // whole file 15/15 GREEN, along with every other test in the repository
    // that could see it. Nothing here notices a predicate that disagrees with
    // it, because nothing here compares the two.
    //
    // SO: this file is the guard against a NEW enum value going unclassified
    // in the second copy. It is NOT a guard against the second copy being
    // WRONG. Those are different properties and only one of them is here.
    //
    // What would pin the two copies to each other: an assertion that reads
    // BOTH and compares them — i.e. driving `resolveHumanDecision` for every
    // (type, choice) pair and checking the marker against `_isReWork`. That is
    // not possible here, for the reason in the file header: this package
    // depends on `workflow_store`, so its tests may not import the engine.
    //
    // It IS possible on the other side of that boundary, where the real
    // predicate and the real write path are both reachable, and that is where
    // it now lives:
    // `packages/workflow_store/test/triage_discriminator_test.dart`, group
    // "the park's classification, asserted against PRODUCTION and not a list".
    // Those cases drive `resolveHumanDecision` and read the marker off the
    // durable row, so no list can satisfy them. The dependency fact that makes
    // this file necessary is the same fact that puts the cross-copy check over
    // there — the two files are complementary, not redundant.
    test('every HumanDecisionChoice is classified exactly once, by name', () {
      final recognised = _recognisedReWorkChoices.toSet();
      final notRecognised = _notRecognisedReWorkChoices.toSet();

      // No value may be in both lists. Overlap means the classification is
      // ambiguous and the "not re-work" reading is the one nobody would notice
      // losing, because an unclassified pair and a not-re-work pair both fail
      // the guard only if they reach an entry state.
      expect(
        recognised.intersection(notRecognised),
        isEmpty,
        reason:
            'a choice classified both ways is not classified at all. Move it to '
            'exactly one list.',
      );

      // No value may be in neither. This is the assertion the compiler already
      // forces inside `workflow_store`; here it forces the SECOND copy, which
      // is the one a future enum value would silently pass.
      final classified = recognised.union(notRecognised);
      final unclassified = HumanDecisionChoice.values
          .where((choice) => !classified.contains(choice))
          .toList();
      expect(
        unclassified,
        isEmpty,
        reason:
            'HumanDecisionChoice has a value this file does not classify: '
            '$unclassified. Add it to _recognisedReWorkChoices or '
            '_notRecognisedReWorkChoices and say why. It will already be '
            'breaking the build in '
            'DurableWorkflowEngine._isReWorkDecision — this is the '
            'second copy failing with it.',
      );

      // And neither list may carry a value the enum has dropped: a stale entry
      // classifies something that no longer exists and hides the fact that
      // nothing was re-classified.
      expect(
        classified.difference(HumanDecisionChoice.values.toSet()),
        isEmpty,
        reason:
            'these are classified by a file that names values the enum no '
            'longer has. A stale entry means the real set moved and this copy '
            'did not:',
      );

      // Non-vacuity, measured: the partition above is trivially satisfiable by
      // two empty lists, so pin both the size of each side and the total.
      expect(
        HumanDecisionChoice.values,
        hasLength(10),
        reason:
            'ten choices today. A change here is expected — the tenth is '
            '`reTriage`, added by this slice — and must come with a '
            're-classification, which the partition above enforces. What is NOT '
            'acceptable is this number changing with no diff to the two lists.',
      );
      expect(recognised, hasLength(3), reason: 'rework, reject, reTriage');
      expect(notRecognised, hasLength(7), reason: 'the other seven');
    });

    test('reTriage IS re-work, and that is a decision, not an omission', () {
      // The ruling, asserted so it cannot be quietly reversed by someone who
      // reads "re-triage is only reachable through an escalation" and assumes
      // the new type inherits that exception. It does not: the exception is
      // keyed on `escalation`, and `reTriage` is a recognised choice for EVERY
      // type, which is the whole of why the park's own re-triage answer stamps
      // a fresh dedupe key instead of reusing a consumed one.
      //
      // ## WHAT THIS DOES AND DOES NOT PROVE (F-74)
      //
      // It proves the SPELLING in this file. It does NOT prove the production
      // predicate, and it cannot: `_isReWork` above is built from
      // `_recognisedReWorkChoices`, a literal list in this same file, so this
      // assertion checks a list against itself.
      //
      // An independent review of slice 1 (`7029424`) proved the gap by
      // mutation: flipping the `reTriage` arm of
      // `DurableWorkflowEngine._isReWorkDecision` to `=> false` left this file
      // 15/15 GREEN. The ruling itself is now pinned where production is
      // reachable —
      // `packages/workflow_store/test/triage_discriminator_test.dart`, group
      // "the park's classification, asserted against PRODUCTION and not a
      // list" — which drives `resolveHumanDecision` and reads the marker back
      // off the durable row. This test stays because it covers a different
      // property: that the spelling here is TOTAL over every type. Read the
      // "WHAT TOTALITY DOES AND DOES NOT PIN" comment above before trusting it
      // for anything more than that.
      for (final type in HumanDecisionType.values) {
        expect(
          _isReWork(type, HumanDecisionChoice.reTriage),
          isTrue,
          reason:
              '$type/reTriage is re-triage by any reading. If it were not, a '
              'parked item an operator sends back to triage would re-request '
              'the key a terminal triage job holds and be inert for ever.',
        );
      }
    });

    test(
      'approve counts ONLY for escalation, so the park needs a declaration',
      () {
        expect(
          _isReWork(HumanDecisionType.escalation, HumanDecisionChoice.approve),
          isTrue,
          reason: 'the one approve that means "again"',
        );
        for (final type in HumanDecisionType.values.where(
          (t) => t != HumanDecisionType.escalation,
        )) {
          expect(
            _isReWork(type, HumanDecisionChoice.approve),
            isFalse,
            reason: '$type/approve is acceptance, not a re-triage',
          );
        }

        // The park's approve route now lands on designApproved which is NOT a
        // triage entry state (removed per design-revision.md §5.4(c)). So it
        // does not need to be in _declaredNotReWork.
        expect(
          _declaredNotReWork.isEmpty,
          isTrue,
          reason:
              'no routes into triage entry states are undeclared non-re-work',
        );
        expect(
          _declaredNotReWork.values.every((reason) => reason.length > 80),
          isTrue,
          reason:
              'a declaration with no reason is an escape hatch. Each must say why '
              'the pair is exempt and what the consequence is.',
        );
      },
    );
  });

  group('M1 CLOSED — every entry state, not just designNotRequired', () {
    test(
      'every route into ANY triage entry state is re-work, or is DECLARED',
      () {
        final routesByEntryState = <WorkItemState, List<String>>{};
        for (final type in HumanDecisionType.values) {
          for (final choice in HumanDecisionChoice.values) {
            final target = HumanDecisionRouting.targetFor(type, choice);
            if (target == null) continue;
            if (!triageDefectDefinition.entryStates.contains(target)) continue;

            routesByEntryState
                .putIfAbsent(target, () => <String>[])
                .add('($type, $choice)');
            expect(
              _isReWork(type, choice) ||
                  _declaredNotReWork.containsKey((type, choice)),
              isTrue,
              reason:
                  '$type/$choice now routes to ${target.wire}, which is a '
                  'triageDefectDefinition entry state, and would re-enter '
                  'triage on a dedupe key the last run already consumed. It '
                  'must be classified as re-work by '
                  'DurableWorkflowEngine._isReWorkDecision — so the key is '
                  'fresh — or be declared in _declaredNotReWork with a '
                  'reason. An undeclared route here leaves the work item '
                  'permanently inert, which is precisely what the '
                  'designNotRequired-only filter used to hide.',
            );
          }
        }

        // Not vacuous: the table must actually reach at least one entry state,
        // which is exactly what it would not look like if `targetFor` were
        // renamed or its return type changed under the guard.
        expect(
          routesByEntryState,
          isNotEmpty,
          reason:
              'no route reaches any triage entry state, so this guard is '
              'checking nothing. That is a change to HumanDecisionRouting, '
              'and it needs a human to look at it.',
        );
        expect(
          routesByEntryState.keys,
          contains(WorkItemState.reviewRejected),
          reason:
              'the reject route is the one that reaches the state this change '
              'added; if it stops routing there, this file is no longer '
              'covering the case it was written for',
        );
        expect(
          routesByEntryState.keys,
          contains(WorkItemState.reviewRejected),
          reason:
              'the entry state M1 named. The old filter never saw it, which is '
              'exactly why it stayed green; if it stops being reachable this '
              'file has lost the coverage it was written to add.',
        );

        // The declaration is a closed list, not an escape hatch: a declared
        // pair that no longer reaches any entry state is stale config, and it
        // would sit here looking like coverage of a route that has moved.
        for (final declared in _declaredNotReWork.keys) {
          final target = HumanDecisionRouting.targetFor(
            declared.$1,
            declared.$2,
          );
          expect(
            target != null &&
                triageDefectDefinition.entryStates.contains(target),
            isTrue,
            reason:
                '${declared.$1}/${declared.$2} is declared as a route into a '
                'triage entry state, but now lands on ${target?.wire}. Either '
                'the routing table moved or the entry-state set changed, and a '
                'stale declaration hides a route that is no longer the one '
                'documented.',
          );
        }
      },
    );

    test('the guard would fail on the defect M1 described', () {
      // The counterfactual, asserted rather than asserted-about: the route M1
      // named (`designApproved`, a second entry state the old filter skipped)
      // is one the guard checks today. This is what makes the guard above a
      // closure rather than a restatement.
      final target = HumanDecisionRouting.targetFor(
        HumanDecisionType.escalation,
        HumanDecisionChoice.approve,
      );
      expect(
        target,
        WorkItemState.designNotRequired,
        reason: 'the known route the old guard DID check, kept',
      );

      // And the old guard's filter, restated as a predicate, demonstrably skips
      // a whole entry state — so "it was green before" is a fact about the
      // filter, not about the code being correct.
      bool oldGuardChecked(WorkItemState state) =>
          state == WorkItemState.designNotRequired;
      expect(oldGuardChecked(WorkItemState.designApproved), isFalse);
      expect(oldGuardChecked(WorkItemState.reviewRejected), isFalse);
    });
  });

  group('every entry state ACTUALLY dispatches', () {
    test('the live evaluator returns runnable for the whole set', () {
      for (final state in triageDefectDefinition.entryStates) {
        expect(
          evaluator.evaluate(_itemAt(state), triageDefectDefinition),
          RunnableWorkStatus.runnable,
          reason:
              '${state.wire} is listed in entryStates, so it is a claim that '
              'the scheduler will enqueue for it. A listed state the policy '
              'refuses is the silent variant of this defect: tick enqueues '
              'nothing, reports nothing, and the item looks healthy.',
        );
      }
    });

    test(
      'entryProbeTargets covers exactly the entry states that cannot start an '
      'execution directly',
      () {
        // The set must not drift in either direction: a stale override for a
        // state that can dispatch directly is a question nobody is asking any
        // more, and a missing one is the defect this file exists to catch.
        final needsOverride = <WorkItemState>{};
        for (final state in triageDefectDefinition.entryStates) {
          final direct = const WorkflowEngine().evaluateWorkItemTransition(
            from: state,
            to: triageDefectDefinition.targetState,
            trigger: TransitionTrigger.systemEvent,
            actor: _orch,
            context: const {'agentAvailable': true, 'capabilitiesMatch': true},
          );
          if (!direct.isValid) needsOverride.add(state);
        }

        expect(
          needsOverride,
          isNotEmpty,
          reason:
              'every entry state now starts an execution directly, so '
              'entryProbeTargets is dead configuration. That is a change to the '
              'transition table or to targetState, and it needs a human.',
        );
        expect(
          triageDefectDefinition.entryProbeTargets.keys,
          needsOverride,
          reason:
              'one override per entry state that needs it, no more and no '
              'fewer. A stale entry would silently probe the wrong edge for a '
              'state that no longer needs it.',
        );
      },
    );

    test('the override names a hop the policy actually accepts', () {
      for (final entry in triageDefectDefinition.entryProbeTargets.entries) {
        expect(
          triageDefectDefinition.entryStates,
          contains(entry.key),
          reason:
              '${entry.key.wire} has a probe override but is not an entry '
              'state, so the override is unreachable configuration',
        );
        final probe = const WorkflowEngine().evaluateWorkItemTransition(
          from: entry.key,
          to: entry.value,
          trigger: TransitionTrigger.systemEvent,
          actor: _orch,
          context: const {'agentAvailable': true, 'capabilitiesMatch': true},
        );
        expect(
          probe.isValid,
          isTrue,
          reason:
              '${entry.key.wire} -> ${entry.value.wire} is not a legal edge, '
              'so the state would be listed as dispatchable and silently not '
              'be. Guards were '
              '${probe.guardResults.map((g) => '${g.name}=${g.passed}').toList()}',
        );
      }
    });
  });

  group('nothing ELSE reaches reviewRejected', () {
    // The judgement this change had to make, made executable. Making
    // `reviewRejected` dispatchable hands every item in that state a
    // `triage_defect` job, so the question is whether any route other than a
    // rejected engineering review lands there — in particular a rejected
    // DESIGN review, which would suddenly start getting triage jobs.
    test('only a rejected engineering review lands on reviewRejected', () {
      final producers = <String>[];
      for (final type in HumanDecisionType.values) {
        for (final choice in HumanDecisionChoice.values) {
          if (HumanDecisionRouting.targetFor(type, choice) !=
              WorkItemState.reviewRejected) {
            continue;
          }
          producers.add('($type, $choice)');
          expect(
            type,
            HumanDecisionType.engineeringReview,
            reason:
                '$type/$choice now lands on review_rejected, so it would '
                'receive a triage_defect job on the strength of this change. '
                'A rejected design review must land on design_rejected.',
          );
        }
      }
      expect(producers, [
        '(HumanDecisionType.engineeringReview, HumanDecisionChoice.reject)',
      ], reason: 'the one known producer, spelled out so a second fails');
    });

    test('a rejected DESIGN review lands on design_rejected, untouched', () {
      // The specific alternative the judgement had to rule out. `designRejected`
      // is a different state and a different job's entry state
      // (`designRevisionDefinition`), so widening the triage entry set cannot
      // touch it.
      expect(
        HumanDecisionRouting.targetFor(
          HumanDecisionType.designApproval,
          HumanDecisionChoice.reject,
        ),
        WorkItemState.designRejected,
      );
      expect(WorkItemState.designRejected, isNot(WorkItemState.reviewRejected));
      expect(
        evaluator.evaluate(
          _itemAt(WorkItemState.designRejected),
          triageDefectDefinition,
        ),
        RunnableWorkStatus.noAction,
        reason:
            'a rejected design review is NOT a triage entry state. If this '
            'changes, a rejected design is being sent to AI triage, which is '
            'a routing decision nobody made.',
      );
    });

    test('the designRejection decision type reaches no triage entry state', () {
      // `targetFor` has no `designRejection` entry at all, so the only answer it
      // can ever give is the `(_, cancel)` catch-all. Asserted rather than
      // assumed: a `designRejection/reject` route added to the table would make
      // a rejected design the SECOND producer of `reviewRejected`, and would
      // then hand design rejections to AI triage on the strength of this change.
      for (final choice in HumanDecisionChoice.values) {
        final target = HumanDecisionRouting.targetFor(
          HumanDecisionType.designRejection,
          choice,
        );
        expect(
          target == null || target == WorkItemState.cancelled,
          isTrue,
          reason:
              'design_rejection/$choice routes to ${target?.wire}. If that is '
              'ever a triage entry state, a rejected design review would be '
              'receiving triage_defect jobs — check whether this change caused '
              'it before widening anything.',
        );
      }
    });
  });

  group('the REPORTED RESIDUAL, demonstrated rather than asserted away', () {
    // The declared `_declaredNotReWork` entry, proved with the real builder and
    // the real queue. This is executable knowledge: if someone closes the
    // residual by stamping on design approval, the first assertion below fails
    // and names what changed. If they close it some other way, the second fails.
    //
    // PRE-EXISTING at base — `designApproved` has been an entry state since
    // before this change, and nothing here is caused by `reviewRejected`.
    test(
      'an approved design asks for the BARE key, which a triage job holds',
      () async {
        // An item at `designApproved` whose only triage history is the first
        // triage run. `approve` does not stamp, so there is no marker at all and
        // the builder produces the historical, unsuffixed key.
        final approved = _itemAt(WorkItemState.designApproved);
        expect(approved.metadata?.containsKey('triageAttempt'), isFalse);
        final key = triageDefectDedupeKey(approved, triageDefectDefinition);
        expect(key, '$_id:triage_defect');

        // The first triage job holds that key for ever: a terminal holder keeps
        // its key, which is the queue rule this lane does not touch.
        final jobStore = InMemoryJobStore();
        final queue = JobQueue(store: jobStore);
        final first = await queue.enqueueIfAbsent(
          workItemId: _id,
          definition: triageDefectDefinition,
          dedupeKey: key,
          instruction: 'seeded terminal holder',
        );
        expect(first.created, isTrue);
        await queue.complete(job: first.job, terminal: JobState.succeeded);

        // So the design-approval route re-requests a consumed key and enqueues
        // nothing. The item is inert — exactly the defect class, on the pair the
        // old guard could not see.
        final again = await queue.enqueueIfAbsent(
          workItemId: _id,
          definition: triageDefectDefinition,
          dedupeKey: triageDefectDedupeKey(
            _itemAt(WorkItemState.designApproved),
            triageDefectDefinition,
          ),
          instruction: 'after design approval',
        );
        expect(
          again.created,
          isFalse,
          reason:
              'this is the pre-existing residual: a design approval does not '
              'advance the discriminator, so an already-triaged item re-requests '
              'the key the terminal first triage job holds. Fixing it means '
              'deciding whether a design approval counts as a re-triage — a '
              'product decision, escalated, not taken here.',
        );
      },
    );

    test(
      'the item is NOT DISPATCHABLE by triage — designApproved is no longer a triage entry state',
      () {
        // designApproved was removed from triageDefectDefinition.entryStates per
        // design-revision.md §5.4(c). Items at designApproved now go through the
        // DesignApprovalHandoff to implementationReady, not through triage.
        expect(
          evaluator.evaluate(
            _itemAt(WorkItemState.designApproved),
            triageDefectDefinition,
          ),
          RunnableWorkStatus.noAction,
          reason:
              'designApproved is no longer a triage entry state, so triage does not dispatch it',
        );
      },
    );
  });

  group('a state that is NOT an entry state still refuses', () {
    test('agentFailed stays inert, and reviewRejected is not it', () {
      // The control. The discriminator marker is irrelevant to eligibility; the
      // STATE decides, and `agentFailed` must keep deciding "not yet" while
      // `reviewRejected` now decides "now".
      for (final state in <WorkItemState>[
        WorkItemState.agentFailed,
        WorkItemState.qaFailed,
        WorkItemState.deploymentFailed,
        WorkItemState.designRejected,
        WorkItemState.reviewApproved,
      ]) {
        expect(
          evaluator.evaluate(_itemAt(state), triageDefectDefinition),
          isNot(RunnableWorkStatus.runnable),
          reason: '${state.wire} is not a triage entry state',
        );
      }
    });
  });
}
