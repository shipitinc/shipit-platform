import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_model_execution_record_store.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// ## WHAT THIS FILE EXISTS TO PROVE
///
/// `getModelStats` answered `Internal Server Error` on EVERY call — grouped
/// and ungrouped alike — for the entire life of the Models → Stats screen, so
/// the screen has never rendered a number. The SQL was fine; two Dart-level
/// `TypeError`s were not:
///
///  1. `SUM()` over a `bigint` column returns `numeric`, and the four token
///     totals were read `as int?`. The postgres driver decodes `numeric` as a
///     String, so the cast threw on every aggregate row.
///  2. The grouped path built its group column as `'"role"'` and then looked up
///     `m['"role"']`, but `toColumnMap()` keys are BARE column names — `role`.
///     `null as String` threw on every grouped row.
///
/// ## WHY THESE ASSERT EXACT NUMBERS AND NOT "DOES NOT THROW"
///
/// A test that only asserts the call does not throw passes with **both** bugs
/// present, because both bugs are exceptions — that test is green on the code
/// that 500s on every request. So every assertion below is a value read out of
/// the aggregate, against a seed whose arithmetic is written out in the test's
/// own doc comment, on rows inserted through the REAL store.
///
/// The seed is chosen so that each assertion is load-bearing:
///
///  * `cachedReadTokens` is non-zero on two rows, so the fourth `SUM` is not
///    covered by the first three.
///  * `costUsd` differs per row, so `AVG` has something to average.
///  * the groups have UNEQUAL sizes (2 / 1 / 1), so the grouped roll-up's
///    `avgCostUsd` can distinguish `total/count` (2.75) from a mean of means
///    (11/3 = 3.667) — see the test that asserts it.
final List<Session> _openSessions = <Session>[];

const _workItemPrefix = 'ms-stats';

Future<PersistenceDatabase> _newDb() async {
  final session = await Serverpod.instance.createSession(enableLogging: false);
  _openSessions.add(session);
  return PersistenceDatabase(session.db);
}

Future<void> _closeSessions() async {
  for (final session in List.of(_openSessions)) {
    await session.close();
  }
  _openSessions.clear();
}

/// Removes only this file's rows.
///
/// Targeted DELETE, never a TRUNCATE: `test/integration` shares one database
/// with files that run concurrently. Every marker is the `ms-stats-` prefix
/// this file mints, so no other file's row can match. Runs in `setUp` as well
/// as `tearDown`, because these rows are inserted on a session of their own and
/// therefore are NOT covered by the suite's rollback.
Future<void> _purgeSuiteRows() async {
  final db = await _newDb();
  await db.execute(
    'DELETE FROM "model_execution_record" WHERE "workItemId" LIKE @p',
    parameters: QueryParameters.named({'p': '$_workItemPrefix-%'}),
  );
}

DateTime _startedAt(int day) => DateTime.utc(2026, 4, day, 9);

/// Four rows, written through the production store.
///
/// | exec | role | model | provider | task | in | out | total | cached | cost | ok |
/// |------|------|-------|----------|------|----|-----|-------|--------|------|----|
/// | 1 | IMPLEMENTER | m-alpha | openai | implementation | 100 | 1000 | 1100 | 0 | 1.50 | true |
/// | 2 | IMPLEMENTER | m-alpha | openai | implementation | 200 | 2000 | 2200 | 0 | 2.50 | true |
/// | 3 | IMPLEMENTER | m-beta | anthropic | implementation | 300 | 3000 | 3300 | 50 | 3.00 | false |
/// | 4 | ENGINEERING_REVIEWER | m-gamma | anthropic | review | 400 | 4000 | 4400 | 70 | 4.00 | true |
///
/// Totals: count 4 · in 1000 · out 10000 · total 11000 · cached 120 ·
/// cost 11.00 · avg 2.75 · success 3 · failure 1.
final List<ModelExecutionRecord> _seed = [
  _row(
    id: 1,
    day: 1,
    role: AgentRole.implementer,
    modelId: 'm-alpha',
    provider: 'openai',
    taskType: 'implementation',
    input: 100,
    output: 1000,
    cached: 0,
    cost: 1.50,
    success: true,
  ),
  _row(
    id: 2,
    day: 2,
    role: AgentRole.implementer,
    modelId: 'm-alpha',
    provider: 'openai',
    taskType: 'implementation',
    input: 200,
    output: 2000,
    cached: 0,
    cost: 2.50,
    success: true,
  ),
  _row(
    id: 3,
    day: 3,
    role: AgentRole.implementer,
    modelId: 'm-beta',
    provider: 'anthropic',
    taskType: 'implementation',
    input: 300,
    output: 3000,
    cached: 50,
    cost: 3.00,
    success: false,
  ),
  _row(
    id: 4,
    day: 4,
    role: AgentRole.engineeringReviewer,
    modelId: 'm-gamma',
    provider: 'anthropic',
    taskType: 'review',
    input: 400,
    output: 4000,
    cached: 70,
    cost: 4.00,
    success: true,
  ),
];

ModelExecutionRecord _row({
  required int id,
  required int day,
  required AgentRole role,
  required String modelId,
  required String provider,
  required String taskType,
  required int input,
  required int output,
  required int cached,
  required double cost,
  required bool success,
}) => ModelExecutionRecord(
  workItemId: '$_workItemPrefix-$id',
  jobId: '$_workItemPrefix-job-$id',
  agentExecutionId: '$_workItemPrefix-agx-$id',
  role: role,
  modelId: modelId,
  provider: provider,
  inputTokens: input,
  outputTokens: output,
  totalTokens: input + output,
  cachedReadTokens: cached,
  costUsd: cost,
  currency: 'USD',
  startedAt: _startedAt(day),
  finishedAt: _startedAt(day).add(const Duration(seconds: 30)),
  success: success,
  error: success ? null : 'provider rejected the request',
  escalationIndex: 0,
  taskType: taskType,
);

void main() {
  withServerpod(
    'getModelStats returns the numbers the aggregate actually computed',
    (sessionBuilder, endpoints) {
      setUp(() async {
        await _purgeSuiteRows();
        await PostgresModelExecutionRecordStore(
          await _newDb(),
        ).insertAll(_seed);
      });

      tearDown(() async {
        await _purgeSuiteRows();
        await _closeSessions();
      });

      test(
        'ungrouped: every aggregate is the value the seed sums to',
        () async {
          final view = await endpoints.providerHealthEndpoints.getModelStats(
            sessionBuilder,
          );

          expect(
            view.count,
            4,
            reason: 'four rows were inserted and none is filtered out',
          );
          expect(
            view.totalInputTokens,
            1000,
            reason:
                '100+200+300+400. This column is SUM(bigint) -> numeric on '
                'the wire, and reading it `as int?` is the TypeError that made '
                'every ungrouped call 500.',
          );
          expect(view.totalOutputTokens, 10000, reason: '1000+2000+3000+4000');
          expect(view.totalTokens, 11000, reason: '1100+2200+3300+4400');
          expect(
            view.totalCachedReadTokens,
            120,
            reason:
                '0+0+50+70 — the fourth SUM, which a three-column fix '
                'would leave broken while the first three passed',
          );
          expect(
            view.totalCostUsd,
            closeTo(11.00, 1e-9),
            reason: '1.5+2.5+3+4',
          );
          expect(
            view.avgCostUsd,
            closeTo(2.75, 1e-9),
            reason: '11.00 / 4 runs',
          );
          expect(view.successCount, 3);
          expect(view.failureCount, 1);
          expect(
            view.byGroup,
            isEmpty,
            reason: 'no groupBy was asked for, so nothing is claimed per group',
          );
        },
      );

      test('the success rate the screen shows is derivable from what the '
          'server sends', () async {
        final view = await endpoints.providerHealthEndpoints.getModelStats(
          sessionBuilder,
        );

        expect(view.successCount + view.failureCount, view.count);
        expect(
          view.successCount / view.count,
          closeTo(0.75, 1e-9),
          reason:
              'this is the figure the Stats screen used to render as 0.0% on '
              'every load, because it read a `successRate` key the server '
              'never sends',
        );
      });

      test('grouped by modelId: group keys are BARE column names', () async {
        final view = await endpoints.providerHealthEndpoints.getModelStats(
          sessionBuilder,
          groupBy: 'modelId',
        );

        final byKey = {for (final g in view.byGroup) g.groupKey: g};

        expect(
          byKey.keys.toSet(),
          {'m-alpha', 'm-beta', 'm-gamma'},
          reason:
              'the grouped path used to look up m[\'"modelId"\'] — with the SQL '
              'quotes still on — against toColumnMap() keys that never carry '
              'them, so every grouped call threw',
        );

        final alpha = byKey['m-alpha']!;
        expect(alpha.count, 2);
        expect(alpha.totalInputTokens, 300, reason: '100+200');
        expect(alpha.totalOutputTokens, 3000, reason: '1000+2000');
        expect(alpha.totalTokens, 3300);
        expect(alpha.totalCachedReadTokens, 0);
        expect(alpha.totalCostUsd, closeTo(4.00, 1e-9));
        expect(alpha.successCount, 2);
        expect(alpha.failureCount, 0);

        final beta = byKey['m-beta']!;
        expect(beta.count, 1);
        expect(beta.totalInputTokens, 300);
        expect(beta.totalOutputTokens, 3000);
        expect(beta.totalTokens, 3300);
        expect(beta.totalCachedReadTokens, 50);
        expect(beta.totalCostUsd, closeTo(3.00, 1e-9));
        expect(beta.successCount, 0, reason: 'the one seeded failure');
        expect(beta.failureCount, 1);

        final gamma = byKey['m-gamma']!;
        expect(gamma.count, 1);
        expect(gamma.totalInputTokens, 400);
        expect(gamma.totalOutputTokens, 4000);
        expect(gamma.totalTokens, 4400);
        expect(gamma.totalCachedReadTokens, 70);
        expect(gamma.totalCostUsd, closeTo(4.00, 1e-9));
        expect(gamma.successCount, 1);
        expect(gamma.failureCount, 0);
      });

      test(
        'grouped by role: the third and fourth groupings aggregate too',
        () async {
          for (final groupBy in ['role', 'provider', 'taskType']) {
            final view = await endpoints.providerHealthEndpoints.getModelStats(
              sessionBuilder,
              groupBy: groupBy,
            );
            expect(
              view.byGroup.fold<int>(0, (sum, g) => sum + g.count),
              4,
              reason: 'every seeded row lands in exactly one $groupBy group',
            );
            expect(
              view.byGroup.fold<int>(0, (sum, g) => sum + g.totalInputTokens),
              1000,
              reason:
                  'grouped token sums must equal the ungrouped total ($groupBy)',
            );
          }
        },
      );

      test('a grouped roll-up averages cost PER RUN, not per group', () async {
        final view = await endpoints.providerHealthEndpoints.getModelStats(
          sessionBuilder,
          groupBy: 'modelId',
        );

        expect(
          view.count,
          4,
          reason: 'the grouped roll-up is the sum over its groups',
        );
        expect(view.totalCostUsd, closeTo(11.00, 1e-9));
        expect(
          view.avgCostUsd,
          closeTo(2.75, 1e-9),
          reason:
              '11.00 over 4 runs. The roll-up used to take the MEAN OF THE '
              'PER-GROUP MEANS — (4.00 + 3.00 + 4.00) / 3 = 3.6667 — which '
              'weights a one-run model the same as a two-run one and reports '
              'an average cost no execution ever cost.',
        );
      });

      test('the time range narrows the aggregate, and an empty range is a '
          'true zero rather than a failure', () async {
        final april2to3 = await endpoints.providerHealthEndpoints.getModelStats(
          sessionBuilder,
          from: _startedAt(2),
          // One hour past row 3's start. The bound is INCLUSIVE
          // (`"startedAt" <= @to`), so a `+ 1 day` here would also pull in
          // row 4 at April 4 09:00 and this assertion would be off by one.
          to: _startedAt(3).add(const Duration(hours: 1)),
        );

        expect(april2to3.count, 2, reason: 'rows 2 and 3 only');
        expect(april2to3.totalInputTokens, 500);
        expect(april2to3.totalOutputTokens, 5000);
        expect(april2to3.totalTokens, 5500);
        expect(april2to3.totalCachedReadTokens, 50);
        expect(april2to3.successCount, 1);
        expect(april2to3.failureCount, 1);

        final nothing = await endpoints.providerHealthEndpoints.getModelStats(
          sessionBuilder,
          from: DateTime.utc(2030),
          to: DateTime.utc(2031),
        );

        expect(
          nothing.count,
          0,
          reason:
              'nothing ran in the range — a real measurement of zero, '
              'which is exactly why it must not be confused with a failed '
              'read. The bloc, not this view, carries that distinction.',
        );
        expect(nothing.totalInputTokens, 0);
        expect(nothing.totalOutputTokens, 0);
        expect(nothing.totalTokens, 0);
        expect(nothing.totalCachedReadTokens, 0);
        expect(nothing.successCount, 0);
        expect(nothing.failureCount, 0);
      });

      test('a grouping that is not a column fails by name instead of by '
          'accident', () async {
        await expectLater(
          endpoints.providerHealthEndpoints.getModelStats(
            sessionBuilder,
            groupBy: 'escalationIndex',
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message.toString(),
              'message',
              contains('modelId, provider, taskType, role'),
            ),
          ),
          reason:
              'the old `default: groupByColumn = 1` produced `GROUP BY 1` and '
              'then `m[\'1\'] as String` — a TypeError naming nothing. There '
              'was no working behaviour to preserve: every such call threw.',
        );
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}
