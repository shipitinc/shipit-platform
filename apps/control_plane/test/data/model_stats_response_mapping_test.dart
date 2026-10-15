import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane_client/control_plane_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// ## WHAT THIS FILE IS
///
/// The `getModelStats` client mapping, checked against the ACTUAL generated
/// wire type rather than a hand-written map.
///
/// The screen this feeds read nine keys the server never sent
/// (`totalExecutions`, `successRate`, `costOverTime`, `tokensByProvider`,
/// `successRateByModel`, `escalationFrequency`, `costByTaskType`), defaulted
/// every one of them to `0.0` / `0` / `const []`, and discarded all eight keys
/// the server does send. So the success-rate card read `0.0%` on every load
/// for ever, and its `>= 0.95` threshold could never be true.
///
/// Building the payload from `ModelStatsView(...).toJson()` is deliberate: if
/// the generated type ever gains, drops or retypes a field, these tests fail
/// here rather than passing against a map that has quietly stopped matching
/// the wire.
///
/// The headline figures are the ones measured on the QA database at
/// `28238ae`: 41 executions, 35 successful, 6 failed — 85.4%, not 0.0%.
void main() {
  /// The QA shape, as the generated type produces it.
  Map<String, dynamic> qaPayload() => ModelStatsView(
    count: 41,
    totalInputTokens: 594996,
    totalOutputTokens: 29516556,
    totalTokens: 30111552,
    totalCachedReadTokens: 0,
    totalCostUsd: 12.5,
    avgCostUsd: 0.304878,
    successCount: 35,
    failureCount: 6,
    byGroup: const [],
  ).toJson();

  group('success rate', () {
    test('is derived from the counts the server sends: 35 of 41, not 0.0', () {
      final stats = ModelStatsResponse.fromJson(qaPayload());

      expect(stats.successCount, 35);
      expect(stats.failureCount, 6);
      expect(stats.totalExecutions, 41);
      expect(
        stats.successRate,
        closeTo(35 / 41, 1e-12),
        reason:
            '85.37%. The old mapping read a `successRate` key the server has '
            'never sent and reported 0.0%, which reads as "nothing ever '
            'succeeds" and is indistinguishable from a real measurement.',
      );
      expect(
        stats.successRate,
        isNot(0.0),
        reason: 'the regression this file exists to pin',
      );
      expect((stats.successRate! * 100).toStringAsFixed(1), '85.4');
    });

    test('is NULL, not zero, when nothing ran in the range', () {
      final stats = ModelStatsResponse.fromJson(
        ModelStatsView(
          count: 0,
          totalInputTokens: 0,
          totalOutputTokens: 0,
          totalTokens: 0,
          totalCachedReadTokens: 0,
          totalCostUsd: 0,
          avgCostUsd: 0,
          successCount: 0,
          failureCount: 0,
          byGroup: const [],
        ).toJson(),
      );

      expect(
        stats.successRate,
        isNull,
        reason:
            '0 successes out of 0 runs is 0/0. Rendering it as 0.0% asserts a '
            'measurement that was never taken, which is the exact failure this '
            'screen is being repaired for.',
      );
      expect(
        stats.avgCostPerExecution,
        isNull,
        reason:
            'the server sends avgCostUsd 0.0 for an empty range because the '
            'wire field is non-nullable. 0.00 is a real sum and a NOT a real '
            'mean; the two must not look alike.',
      );
    });
  });

  group('every key the server sends is read', () {
    test('no field is left at a default while the wire carries a value', () {
      final stats = ModelStatsResponse.fromJson(qaPayload());

      expect(stats.totalExecutions, 41, reason: 'wire `count`');
      expect(stats.totalInputTokens, 594996);
      expect(stats.totalOutputTokens, 29516556);
      expect(stats.totalTokens, 30111552);
      expect(stats.totalCachedReadTokens, 0, reason: 'genuinely zero on QA');
      expect(stats.totalCostUsd, closeTo(12.5, 1e-9));
      expect(stats.avgCostUsd, closeTo(0.304878, 1e-9));
      expect(stats.successCount, 35);
      expect(stats.failureCount, 6);
    });

    test(
      'a non-zero cachedReadTokens survives, so the column is not dropped',
      () {
        final stats = ModelStatsResponse.fromJson(
          ModelStatsView(
            count: 2,
            totalInputTokens: 10,
            totalOutputTokens: 20,
            totalTokens: 30,
            totalCachedReadTokens: 7,
            totalCostUsd: 0.5,
            avgCostUsd: 0.25,
            successCount: 1,
            failureCount: 1,
            byGroup: const [],
          ).toJson(),
        );

        expect(stats.totalCachedReadTokens, 7);
      },
    );
  });

  group('byGroup', () {
    test('is mapped, and each bucket derives its own rate', () {
      final stats = ModelStatsResponse.fromJson(
        ModelStatsView(
          count: 41,
          totalInputTokens: 594996,
          totalOutputTokens: 29516556,
          totalTokens: 30111552,
          totalCachedReadTokens: 0,
          totalCostUsd: 12.5,
          avgCostUsd: 0.304878,
          successCount: 35,
          failureCount: 6,
          byGroup: [
            ModelStatsGroupView(
              groupKey: 'claude-sonnet-4',
              count: 29,
              totalInputTokens: 241701,
              totalOutputTokens: 1000000,
              totalTokens: 1241701,
              totalCachedReadTokens: 0,
              totalCostUsd: 9.0,
              avgCostUsd: 0.310345,
              successCount: 28,
              failureCount: 1,
            ),
            ModelStatsGroupView(
              groupKey: 'gpt-5',
              count: 12,
              totalInputTokens: 353295,
              totalOutputTokens: 28516556,
              totalTokens: 28869851,
              totalCachedReadTokens: 0,
              totalCostUsd: 3.5,
              avgCostUsd: 0.291667,
              successCount: 7,
              failureCount: 5,
            ),
          ],
        ).toJson(),
      );

      expect(stats.byGroup, hasLength(2));
      expect(stats.byGroup.first.key, 'claude-sonnet-4');
      expect(stats.byGroup.first.count, 29);
      expect(stats.byGroup.first.totalCostUsd, closeTo(9.0, 1e-9));
      expect(stats.byGroup.first.successRate, closeTo(28 / 29, 1e-12));
      expect(stats.byGroup.last.key, 'gpt-5');
      expect(stats.byGroup.last.successRate, closeTo(7 / 12, 1e-12));

      expect(
        stats.byGroup.fold<int>(0, (sum, g) => sum + g.count),
        stats.totalExecutions,
        reason: 'the groups partition the same rows the totals summarise',
      );
    });

    test('is empty when no grouping was asked for, which is an answer', () {
      expect(ModelStatsResponse.fromJson(qaPayload()).byGroup, isEmpty);
    });
  });

  group('a divergent payload fails instead of defaulting', () {
    test('a missing key throws rather than becoming a confident zero', () {
      final payload = qaPayload()..remove('successCount');

      expect(
        () => ModelStatsResponse.fromJson(payload),
        throwsA(isA<TypeError>()),
        reason:
            'This is the guard against the exact regression. The old mapping '
            'wrote `(json[\'successRate\'] as num?)?.toDouble() ?? 0.0`, which '
            'cannot distinguish "the server sent 0.0" from "the server sent '
            'nothing", and reported 0.0% for both.',
      );
    });

    test('a null key throws rather than becoming a confident zero', () {
      final payload = qaPayload()..['count'] = null;

      expect(
        () => ModelStatsResponse.fromJson(payload),
        throwsA(isA<TypeError>()),
      );
    });

    test(
      'the nine keys the old mapping invented have no effect on the result',
      () {
        final polluted = qaPayload()
          ..['successRate'] = 0.0
          ..['totalExecutions'] = 0
          ..['costOverTime'] = 'anything'
          ..['tokensByProvider'] = 'anything'
          ..['successRateByModel'] = 'anything'
          ..['escalationFrequency'] = 'anything'
          ..['costByTaskType'] = 'anything';

        final stats = ModelStatsResponse.fromJson(polluted);

        expect(
          stats.totalExecutions,
          41,
          reason: 'from `count`, not the 0 above',
        );
        expect(
          stats.successRate,
          closeTo(35 / 41, 1e-12),
          reason:
              'derived from the counts, so a `successRate` key cannot be '
              'used to override the truth',
        );
      },
    );
  });
}
