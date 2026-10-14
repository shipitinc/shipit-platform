import 'package:control_plane/features/models/run_duration_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// The duration table is the measurement that should REPLACE the agent-execution
/// budgets. That only holds if it is right about three things it is easy to get
/// wrong, and each of those has exactly one test below:
///
///  * the median, not the mean — a bimodal set (fast, or killed at the
///    ceiling) means a mean is dominated by the ceiling;
///  * the failures are a SEPARATE bucket, not folded in and not dropped;
///  * a run with no duration is excluded and COUNTED, never silently treated
///    as zero.
void main() {
  RunDurationSample sample(String role, String status, int seconds) =>
      RunDurationSample(role: role, status: status, durationSeconds: seconds);

  group('median', () {
    test('odd count is the middle value', () {
      expect(RunDurationStats.median([30, 10, 20]), 20);
    });

    test('even count is the mean of the two middle values', () {
      expect(RunDurationStats.median([10, 20, 30, 40]), 25);
    });

    test('is order-independent', () {
      expect(RunDurationStats.median([40, 10, 30, 20]), 25);
    });

    test('a single sample is itself', () {
      expect(RunDurationStats.median([99]), 99);
    });
  });

  group('per role and per status', () {
    final stats = RunDurationStats.compute([
      // An implementation lane that usually works: 600..900s.
      sample('implementer', 'completed', 600),
      sample('implementer', 'completed', 750),
      sample('implementer', 'completed', 900),
      // ...and one killed at its 14400s ceiling, which is a DIFFERENT question
      // and must not be averaged into the three above.
      sample('implementer', 'interrupted', 14400),
      // A reviewer: 900..1800s.
      sample('engineering_reviewer', 'completed', 900),
      sample('engineering_reviewer', 'completed', 1800),
      sample('engineering_reviewer', 'failed', 120),
    ]);

    test('one bucket per (role, status) pair', () {
      expect(stats.buckets, hasLength(4));
      expect(stats.buckets.map((b) => '${b.role}/${b.status}').toList(), [
        'engineering_reviewer/completed',
        'engineering_reviewer/failed',
        'implementer/completed',
        'implementer/interrupted',
      ]);
    });

    test('count / min / median / max are right', () {
      final impl = stats.forRole('implementer');
      final completed = impl.firstWhere((b) => b.status == 'completed');
      expect(completed.count, 3);
      expect(completed.minSeconds, 600);
      expect(completed.medianSeconds, 750);
      expect(completed.maxSeconds, 900);

      final killed = impl.firstWhere((b) => b.status == 'interrupted');
      expect(killed.count, 1);
      expect(killed.maxSeconds, 14400);
    });

    test(
      'the killed-at-budget run is NOT averaged into the completed ones',
      () {
        final impl = stats.forRole('implementer');
        final completed = impl.firstWhere((b) => b.status == 'completed');
        // 14400 must not drag this anywhere near 750.
        expect(completed.medianSeconds, 750);
        expect(
          impl.every((b) => b.status != 'completed' || b.maxSeconds < 14400),
          isTrue,
        );
      },
    );

    test('a mean would have been the wrong number, and this is why', () {
      final impl = stats
          .forRole('implementer')
          .firstWhere((b) => b.status == 'completed');
      const mean = (600 + 750 + 900) / 3;
      // The mean and the median agree for this set, which is the POINT: the
      // median is the figure that stays stable when a killed run joins it, and
      // the killed run lives in its own bucket precisely so it can.
      expect(mean, closeTo(impl.medianSeconds.toDouble(), 0.001));
      final withKill = RunDurationStats.compute([
        sample('implementer', 'completed', 600),
        sample('implementer', 'completed', 900),
        sample('implementer', 'interrupted', 14400),
      ]);
      final completedOnly = withKill
          .forRole('implementer')
          .firstWhere((b) => b.status == 'completed');
      expect(
        completedOnly.medianSeconds,
        750,
        reason: 'the completed bucket is unchanged by the killed run',
      );
    });

    test(
      'roles are listed in wire order and each role reads success-first',
      () {
        expect(stats.roles, ['engineering_reviewer', 'implementer']);
        final reviewer = stats.forRoleSorted('engineering_reviewer');
        expect(reviewer.first.status, 'completed');
        expect(reviewer.last.status, 'failed');
      },
    );

    test('success and killed-at-budget are distinguishable by name', () {
      final killed = stats
          .forRole('implementer')
          .firstWhere((b) => b.status == 'interrupted');
      expect(killed.isKilledAtBudget, isTrue);
      expect(killed.isSuccess, isFalse);

      final failed = stats
          .forRole('engineering_reviewer')
          .firstWhere((b) => b.status == 'failed');
      expect(
        failed.isKilledAtBudget,
        isFalse,
        reason:
            'a crash and a run killed at its budget must not look alike, or '
            'the table cannot answer "how often do we hit the ceiling?"',
      );
      expect(failed.isSuccess, isFalse);
    });

    test(
      'a uniform non-successful bucket is flagged as a ceiling signature',
      () {
        final ceiling = RunDurationStats.compute([
          sample('implementer', 'interrupted', 14400),
          sample('implementer', 'interrupted', 14400),
          sample('implementer', 'interrupted', 14400),
        ]).buckets.single;
        expect(ceiling.isUniform, isTrue);

        final varied = RunDurationStats.compute([
          sample('implementer', 'failed', 10),
          sample('implementer', 'failed', 20),
        ]).buckets.single;
        expect(
          varied.isUniform,
          isFalse,
          reason: 'genuine failures are not all the same duration',
        );
      },
    );
  });

  group('what the table refuses to claim', () {
    test('an empty input is an empty table, not a table of zeroes', () {
      final stats = RunDurationStats.compute(const []);
      expect(stats.isEmpty, isTrue);
      expect(stats.samplesConsidered, 0);
    });

    test('one sample is not a uniform bucket', () {
      final stats = RunDurationStats.compute([
        sample('implementer', 'interrupted', 14400),
      ]);
      expect(
        stats.buckets.single.isUniform,
        isFalse,
        reason:
            'a single sample is trivially identical to itself, and calling that '
            '"everyone hits the ceiling exactly" would be manufacturing a '
            'finding from one row',
      );
    });

    test('a role filter keeps only that role', () {
      final all = RunDurationStats.compute([
        sample('implementer', 'completed', 600),
        sample('engineering_reviewer', 'completed', 900),
      ]);
      final only = RunDurationStats.compute([
        sample('implementer', 'completed', 600),
      ], roleFilter: 'implementer');
      expect(all.buckets, hasLength(2));
      expect(only.buckets, hasLength(1));
      expect(only.samplesConsidered, 1);
    });
  });

  group('formatting', () {
    test('seconds below a minute read as seconds', () {
      expect(formatRunDuration(0), '0s');
      expect(formatRunDuration(45), '45s');
      expect(formatRunDuration(59), '59s');
    });

    test('minutes read as minutes and seconds', () {
      expect(formatRunDuration(60), '1m 00s');
      expect(formatRunDuration(900), '15m 00s');
      expect(formatRunDuration(1800), '30m 00s');
      expect(formatRunDuration(750), '12m 30s');
    });

    test('hours read as hours and minutes', () {
      expect(formatRunDuration(3600), '1h 00m');
      expect(formatRunDuration(14400), '4h 00m');
      expect(formatRunDuration(10800 + 1800), '3h 30m');
    });

    test('a raw second count is never shown above a minute', () {
      // The numbers this table exists to show are tens of minutes long, so a
      // bare `1800` is a number the operator has to translate in their head.
      expect(formatRunDuration(1800), isNot('1800'));
    });
  });
}
