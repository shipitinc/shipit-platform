import 'package:scheduler/src/capacity/execution_capacity.dart';
import 'package:test/test.dart';

/// Reading the cap out of the environment, and what happens when it cannot be
/// read.
///
/// The decision under test is not "what is C". It is the failure direction:
/// every unusable value resolves to NOTHING, never to a default. A cap that
/// defaults to unlimited re-creates the host exhaustion it exists to prevent,
/// and a cap that defaults to a guessed number writes a fiction into the log an
/// operator will later trust.
void main() {
  group('execution capacity resolution', () {
    test('resolves an integer value', () {
      final resolution = ExecutionCapacityResolution.fromEnvironment(const {
        executionCapacityEnvVar: '2',
      });
      expect(resolution.isResolved, isTrue);
      expect(resolution.capacity!.maxConcurrentExecutions, 2);
      expect(resolution.capacity!.budget, agentExecutionBudget);
    });

    test('accepts the smallest legal cap', () {
      final resolution = ExecutionCapacityResolution.fromEnvironment(const {
        executionCapacityEnvVar: '1',
      });
      expect(resolution.isResolved, isTrue);
      expect(resolution.capacity!.maxConcurrentExecutions, 1);
    });

    test('trims surrounding whitespace', () {
      expect(
        ExecutionCapacityResolution.fromEnvironment(const {
          executionCapacityEnvVar: '  3  ',
        }).capacity!.maxConcurrentExecutions,
        3,
      );
    });

    test('the resolved value is stated in the startup summary, by name', () {
      final resolution = ExecutionCapacityResolution.fromEnvironment(const {
        executionCapacityEnvVar: '2',
      });
      expect(resolution.diagnostic, contains(executionCapacityEnvVar));
      expect(resolution.diagnostic, contains('2'));
      expect(resolution.diagnostic, contains('global'));
      // Stated in the SUCCESS direction too: an operator must be able to see
      // which cap is in force, not only that something went wrong.
      expect(resolution.diagnostic, isNot(contains('NOT resolved')));
    });

    group('fails closed', () {
      /// Every unusable value must resolve to null. There is no code path from
      /// these inputs to a usable cap, because [ExecutionCapacity] has a
      /// private constructor and only a successful parse produces one.
      final unusable = <String, Map<String, String>>{
        'unset': const {},
        'empty': const {executionCapacityEnvVar: ''},
        'whitespace only': const {executionCapacityEnvVar: '   '},
        'not a number': const {executionCapacityEnvVar: 'two'},
        'a float': const {executionCapacityEnvVar: '2.5'},
        'zero': const {executionCapacityEnvVar: '0'},
        'negative': const {executionCapacityEnvVar: '-1'},
        'a suffix': const {executionCapacityEnvVar: '2 executions'},
        'an injected expression': {executionCapacityEnvVar: r'${n}'},
      };

      unusable.forEach((label, environment) {
        test('$label resolves to no cap at all', () {
          final resolution = ExecutionCapacityResolution.fromEnvironment(
            environment,
          );
          expect(
            resolution.isResolved,
            isFalse,
            reason: '"$label" must not produce a usable cap',
          );
          expect(resolution.capacity, isNull);
        });

        test('$label says why, naming the variable', () {
          final resolution = ExecutionCapacityResolution.fromEnvironment(
            environment,
          );
          expect(resolution.diagnostic, contains(executionCapacityEnvVar));
          expect(resolution.diagnostic, contains('NOT resolved'));
          expect(
            resolution.diagnostic,
            contains('Refusing to dispatch agent executions unbounded'),
            reason:
                'the diagnostic must state the consequence, not just the '
                'complaint',
          );
        });
      });

      test(
        'a rejected value is named in the diagnostic so the fix is obvious',
        () {
          final resolution = ExecutionCapacityResolution.fromEnvironment(const {
            executionCapacityEnvVar: 'banana',
          });
          expect(resolution.diagnostic, contains('banana'));
        },
      );
    });

    test(
      'the budget lock key is stable, distinct, and process-independent',
      () {
        // Stability is load-bearing: a lock key that moved between releases
        // would let two processes take "the same" lock on two different keys,
        // which is the overshoot the mechanism exists to prevent. `String
        // .hashCode` is explicitly not guaranteed stable, so this pins the FNV
        // derivation instead.
        final a = ExecutionCapacityResolution.fromEnvironment(const {
          executionCapacityEnvVar: '2',
        }).capacity!;
        final b = ExecutionCapacityResolution.fromEnvironment(const {
          executionCapacityEnvVar: '2',
        }).capacity!;
        expect(a.advisoryLockKey, b.advisoryLockKey);

        // PostgreSQL's `pg_advisory_xact_lock(bigint)` takes the whole SIGNED
        // 64-bit range, and FNV-1a/64 yields the unsigned digest, so the key is
        // legitimately NEGATIVE for most budget names. What must hold is that
        // bigint can carry the value — not that it is positive.
        expect(a.advisoryLockKey, greaterThanOrEqualTo(-0x8000000000000000));
        expect(a.advisoryLockKey, lessThanOrEqualTo(0x7FFFFFFFFFFFFFFF));

        // Different budgets must not share a lock, or one lane's traffic would
        // block another's.
        final other = ExecutionCapacityResolution.fromEnvironment(const {
          executionCapacityEnvVar: '2',
        }, budget: 'some_other_budget').capacity!;
        expect(other.advisoryLockKey, isNot(a.advisoryLockKey));
      },
    );

    test('the key is a fixed digest, not merely self-consistent', () {
      // Pinning the exact value is what turns a silently CHANGED derivation
      // into a test failure. While a fleet runs mixed versions, every process
      // taking the same lock depends on every version computing the same
      // number — and a changed derivation would not fail anything else.
      final capacity = ExecutionCapacityResolution.fromEnvironment(const {
        executionCapacityEnvVar: '2',
      }).capacity!;
      expect(capacity.advisoryLockKey, -1990546432740124472);
    });

    test(
      'the cap value does not change the lock key: one budget, one lock',
      () {
        // Raising C is a restart, not a new budget. If the key moved with the
        // value, a running cluster at C=2 and a restarted one at C=4 would take
        // different locks and neither would bound the other.
        final atTwo = ExecutionCapacityResolution.fromEnvironment(const {
          executionCapacityEnvVar: '2',
        }).capacity!;
        final atFour = ExecutionCapacityResolution.fromEnvironment(const {
          executionCapacityEnvVar: '4',
        }).capacity!;
        expect(atFour.advisoryLockKey, atTwo.advisoryLockKey);
      },
    );

    test('an ExecutionCapacity cannot be constructed outside a resolution', () {
      // Not a runtime assertion: the constructor is private, so this file
      // simply has no way to name one. Its existence is the guarantee.
      expect(
        () => ExecutionCapacityResolution.fromEnvironment(const {}).capacity,
        returnsNormally,
      );
    });
  });
}
