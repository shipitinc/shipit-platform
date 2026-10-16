import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';

/// The NAMED parts of the undetermined brake, pinned to literals.
///
/// `undetermined_return_brake_test.dart` proves the platform READS these keys
/// and STOPS the route; it deliberately uses string literals so it can run on a
/// tree that has no brake at all, which is the only way "it fails before the
/// fix" can be demonstrated. The cost of that choice is that nothing there holds
/// the exported names to the wire — so this file holds them.
///
/// Together the two are airtight: the behavioural file says "the platform reads
/// `successArtifactUndetermined` and `successArtifactUndeterminedStreak`", this
/// one says "and the named constants spell exactly those, and the ceiling is
/// exactly this many". A rename that changed only one side fails here.
void main() {
  group('one key, declared twice, and the two sides agree', () {
    test('the coordinator WRITES the key the scheduler READS', () {
      expect(
        successArtifactUndeterminedMetadataKey,
        SuccessArtifactArtifacts.undeterminedMetadataKey,
        reason:
            '`packages/execution_coordinator` cannot depend on '
            '`worker_runtime` (which depends on it) and `scheduler` sits above '
            'both, so no shared package can hold this string. It is declared on '
            'each side, and this is what stops the two from drifting apart — '
            'which would disable the brake with both suites still green, because '
            'each would keep reading its own spelling. '
            '`producerActorId` has the same shape and NO pin; this one has a pin',
      );
    });

    test('the streak key names itself and cannot collide with the flag', () {
      expect(
        undeterminedReturnStreakMetadataKey,
        'successArtifactUndeterminedStreak',
        reason:
            'spelled out rather than derived. These two keys share a prefix '
            'because they describe the same verdict, and a prefix relationship '
            'is exactly how one ends up overwriting the other',
      );
      expect(
        undeterminedReturnStreakMetadataKey,
        isNot(successArtifactUndeterminedMetadataKey),
      );
    });
  });

  group('the ceiling, stated here rather than read from the constant', () {
    test('it is THREE', () {
      // The value is pinned by a literal on purpose. Every other assertion in
      // this file that touches the ceiling is either seeded from the constant
      // or checks the BEHAVIOUR, and a constant seeded only from itself proves
      // nothing — setting it to 99 would leave all of them green.
      expect(
        maxConsecutiveUndeterminedReturns,
        3,
        reason:
            'the operator\'s "stop auto-routing after N undetermined returns". '
            'If this value is genuinely wrong, change it HERE with the '
            'reasoning updated, not silently in the constant',
      );
    });

    test('the spend it allows is the machine retry this job type already gets', () {
      // The argument the value rests on, stated as an executable claim so it
      // cannot rot into a bare literal. `implementFeatureDefinition
      // .maxAttempts` is the budget the platform already grants a TRANSIENT
      // failure of this same job type — and `Scheduler._adopt`'s own
      // documentation gives the contract as "exactly N executions, never N+1".
      //
      // So the brake grants a fault in the platform's OWN tooling the same
      // single retry a routine transient failure gets, and not one execution
      // more. Setting `maxAttempts` to 3 without revisiting this is a decision
      // about the brake, not an incidental edit.
      expect(
        maxConsecutiveUndeterminedReturns - 1,
        implementFeatureDefinition.maxAttempts,
        reason:
            'N - 1 is what the platform SPENDS: the Nth undetermined return is '
            'refused, so it buys no execution',
      );
    });
  });

  group('the counter rules', () {
    WorkItem item({Map<String, dynamic>? metadata}) => WorkItem(
      workItemId: 'wi-1',
      productId: 'prod-1',
      category: WorkItemCategory.bugfix,
      title: 'Route the federated feed',
      description: 'A producer finished and left whatever it left.',
      state: WorkItemState.agentCompleted,
      metadata: metadata,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

    test('an ABSENT streak is zero, and absent is not undetermined', () {
      expect(readUndeterminedReturnStreak(item()), 0);
      expect(
        lastCompletionWasUndetermined(item()),
        isFalse,
        reason:
            'absence means only "this item predates the flag". Treating it as '
            'undetermined would let the brake count a fault nobody reported',
      );
    });

    test('the flag is a boolean, and only `true` counts', () {
      expect(
        lastCompletionWasUndetermined(item(metadata: const {'k': true})),
        isFalse,
        reason: 'the wrong key is not the flag',
      );
      expect(
        lastCompletionWasUndetermined(
          item(metadata: const {successArtifactUndeterminedMetadataKey: true}),
        ),
        isTrue,
      );
      expect(
        lastCompletionWasUndetermined(
          item(metadata: const {successArtifactUndeterminedMetadataKey: false}),
        ),
        isFalse,
        reason:
            'the coordinator writes `false` on every DETERMINED completion, so '
            'a recovered item clears the flag rather than leaving a stale '
            '`true` that would keep the streak climbing',
      );
    });

    test('undetermined advances by exactly one; determined resets to zero', () {
      expect(
        nextUndeterminedReturnStreak(item(), undetermined: true),
        1,
        reason: 'the first undetermined return is the first one counted',
      );
      expect(
        nextUndeterminedReturnStreak(
          item(metadata: const {undeterminedReturnStreakMetadataKey: 2}),
          undetermined: true,
        ),
        3,
      );
      expect(
        nextUndeterminedReturnStreak(
          item(metadata: const {undeterminedReturnStreakMetadataKey: 2}),
          undetermined: false,
        ),
        0,
        reason:
            'THE property that makes it a consecutive count. Without the reset '
            'a single tooling blip on an item would park it for a human the '
            'next time anything else went wrong, for ever',
      );
    });

    test('every shape the marker legitimately takes through JSON and back is '
        'readable, and anything else THROWS', () {
      for (final form in const <Object>[3, 3.0, '3']) {
        expect(
          readUndeterminedReturnStreak(
            item(metadata: {undeterminedReturnStreakMetadataKey: form}),
          ),
          3,
          reason: 'form $form (${form.runtimeType}) is attempt three',
        );
      }
      // A `1.5` must NOT truncate to 1: two different returns would then be
      // counted as the same one, and the brake would let a third through.
      expect(
        () => readUndeterminedReturnStreak(
          item(metadata: const {undeterminedReturnStreakMetadataKey: 1.5}),
        ),
        throwsFormatException,
      );
      for (final bad in const <Object>[
        true,
        'nope',
        <String>[],
        _NotANumber(),
      ]) {
        expect(
          () => readUndeterminedReturnStreak(
            item(metadata: {undeterminedReturnStreakMetadataKey: bad}),
          ),
          throwsFormatException,
          reason:
              '$bad is a defect in whatever wrote the marker, and it is '
              'reported as one. Coercing it to 0 would RESET a spent brake; '
              'coercing it to the ceiling would park work on a byte nobody '
              'wrote deliberately. Neither is available',
        );
      }
    });
  });
}

/// A value that is neither a number nor a string, so the "anything else throws"
/// loop above covers a shape that is not a literal.
///
/// Deliberately a named class rather than `null`: an ABSENT marker reads as 0
/// by design, and writing `null` into a metadata map would test the absent case
/// twice while leaving the genuinely-wrong-value case uncovered.
class _NotANumber {
  const _NotANumber();
}
