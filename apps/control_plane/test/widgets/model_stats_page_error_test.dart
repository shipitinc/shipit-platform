import 'package:control_plane/core/theme.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/models/model_stats_bloc.dart';
import 'package:control_plane/features/models/model_stats_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/unimplemented_repository_apis.dart';

/// ## WHAT THIS FILE IS
///
/// Layer three of the original defect, asserted at the WIDGET layer.
///
/// The Stats screen has three different states for every figure, and they must
/// never collapse into one another:
///
///  * a real measurement — `41` executions, `85.4%` success
///  * a real measurement of nothing — `0` executions in the range
///  * a failure to read — the query threw
///
/// The middle one is easy. The third is the dangerous one, because a card that
/// renders `0.0%` or `$0.00` when the read threw is indistinguishable from a
/// real measurement, and an operator tuning budgets cannot tell the difference
/// by looking.
///
/// So every assertion below is on RENDERED TEXT, and the negative assertions
/// are the ones that matter: a failed read must not produce a digit.
///
/// ## WHY THE FAILING CASE IS "A RELOAD THAT FAILS WITH DATA ALREADY ON SCREEN"
///
/// A first load that throws already shows a full-page error and has no cards
/// to get wrong. The live defect was elsewhere: a refresh that failed left the
/// PREVIOUS numbers on screen with nothing marking them as not current — a
/// stale total presented as a measurement. That is the case exercised here.
class FakeRepository
    with UnimplementedRepositoryApis
    implements ControlPlaneRepository {
  FakeRepository({this.stats, this.failAfter = false});

  /// The figures the first read returns.
  ModelStatsResponse? stats;

  /// When true, every read after the first throws.
  bool failAfter;

  int calls = 0;

  @override
  Future<ModelStatsResponse> getModelStats({
    DateTime? from,
    DateTime? to,
    String? groupBy,
  }) async {
    calls++;
    if (failAfter || stats == null) {
      throw StateError('getModelStats failed (503 Service Unavailable)');
    }
    return stats!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('fake: ${invocation.memberName}');
}

/// 41 executions, 35 successful, grouped by model — the QA shape.
const _qa = ModelStatsResponse(
  totalExecutions: 41,
  successCount: 35,
  failureCount: 6,
  totalInputTokens: 594996,
  totalOutputTokens: 29516556,
  totalTokens: 30111552,
  totalCachedReadTokens: 0,
  totalCostUsd: 12.5,
  avgCostUsd: 0.304878,
  byGroup: [
    ModelStatsGroupResponse(
      key: 'claude-sonnet-4',
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
    ModelStatsGroupResponse(
      key: 'gpt-5',
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
);

Widget wrap(ModelStatsBloc bloc) => MaterialApp(
  theme: ShipItTheme.light(),
  home: Scaffold(body: ModelStatsPage(bloc: bloc)),
);

void main() {
  testWidgets('a successful read renders the figures the server sent', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final bloc = ModelStatsBloc(repository: FakeRepository(stats: _qa));

    await tester.pumpWidget(wrap(bloc));
    bloc.add(const ModelStatsLoaded());
    await tester.pumpAndSettle();

    expect(find.text('\$12.50'), findsWidgets, reason: 'total cost card');
    expect(find.text('41'), findsWidgets, reason: 'executions card');
    expect(find.text('85.4%'), findsWidgets, reason: 'success rate card');

    // The by-group charts are the ones the screen previously never had data
    // for at all, so the labels themselves are the assertion. They are read
    // from the semantics tree because a bar chart's labels are painted — which
    // is also why a screen reader could never see them.
    expect(find.textContaining('Tokens by model'), findsOneWidget);
    expect(find.textContaining('Success Rate by model'), findsWidgets);
    expect(find.textContaining('Cost by model'), findsWidgets);
    expect(
      find.bySemanticsLabel(RegExp('claude-sonnet-4')),
      findsWidgets,
      reason: 'the grouped token chart carries its buckets as text',
    );
    expect(
      find.bySemanticsLabel(RegExp('claude-sonnet-4: 1\\.2M')),
      findsWidgets,
      reason: 'and with the value the bar stands for',
    );
    semantics.dispose();
  });

  testWidgets('a reload that FAILS shows an error on every card, and no '
      'number at all', (tester) async {
    final semantics = tester.ensureSemantics();
    final repository = FakeRepository(stats: _qa);
    final bloc = ModelStatsBloc(repository: repository);

    await tester.pumpWidget(wrap(bloc));
    bloc.add(const ModelStatsLoaded());
    await tester.pumpAndSettle();
    expect(find.text('85.4%'), findsWidgets, reason: 'precondition');

    repository.failAfter = true;
    bloc.add(const ModelStatsLoaded());
    await tester.pumpAndSettle();

    // The failure is named and visible.
    expect(
      find.textContaining('503 Service Unavailable'),
      findsWidgets,
      reason:
          'the operator must learn the read FAILED, not merely that a number '
          'is absent',
    );
    expect(
      find.textContaining('NOT current'),
      findsOneWidget,
      reason: 'and must learn the figures on screen are stale, not live',
    );

    // And the figures are gone. Each of these is what a card would show if the
    // error were still being swallowed as a zero.
    expect(find.text('\$12.50'), findsNothing, reason: 'total cost');
    expect(find.text('85.4%'), findsNothing, reason: 'success rate');
    expect(find.text('41'), findsNothing, reason: 'executions');
    expect(find.text('30.1M'), findsNothing, reason: 'total tokens');
    expect(
      find.bySemanticsLabel(RegExp('claude-sonnet-4')),
      findsNothing,
      reason:
          'the by-group charts are the ones that would keep painting stale '
          'bars behind a failure banner — the stale-chart form of the lie',
    );

    // Not even a bare zero of the same shape.
    expect(find.text('\$0.00'), findsNothing);
    expect(find.text('0.0%'), findsNothing);
    expect(find.text('0%'), findsNothing);
    expect(find.text('0'), findsNothing);
    expect(find.text('0K'), findsNothing);
    expect(find.text('0M'), findsNothing);

    // Every card shows the em dash instead — the one glyph on this screen that
    // means "no figure here", never produced by a number that failed to arrive.
    expect(find.text('—'), findsNWidgets(4), reason: 'one per summary card');
    semantics.dispose();
  });

  testWidgets('a first load that FAILS shows a page-level error and no cards', (
    tester,
  ) async {
    final bloc = ModelStatsBloc(repository: FakeRepository());

    await tester.pumpWidget(wrap(bloc));
    bloc.add(const ModelStatsLoaded());
    await tester.pumpAndSettle();

    expect(
      find.textContaining("could not reach the system's records"),
      findsOneWidget,
    );
    expect(find.text('\$0.00'), findsNothing);
    expect(find.text('0.0%'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('a range with no runs says so, and does not claim 0% success', (
    tester,
  ) async {
    final bloc = ModelStatsBloc(
      repository: FakeRepository(
        stats: const ModelStatsResponse(
          totalExecutions: 0,
          successCount: 0,
          failureCount: 0,
          totalInputTokens: 0,
          totalOutputTokens: 0,
          totalTokens: 0,
          totalCachedReadTokens: 0,
          totalCostUsd: 0,
          avgCostUsd: 0,
          byGroup: [],
        ),
      ),
    );

    await tester.pumpWidget(wrap(bloc));
    bloc.add(const ModelStatsLoaded());
    await tester.pumpAndSettle();

    expect(find.text('no runs in range'), findsWidgets);
    expect(
      find.text('0.0%'),
      findsNothing,
      reason:
          'this is the other half of the null-rate rule: zero runs is a real '
          'measurement of NOTHING, and its success rate has no answer — which '
          'is not the same as answering 0%.',
    );
    expect(
      find.text(
        'No executions in this range, so there are no model '
        'tokens to show.',
      ),
      findsOneWidget,
    );
  });
}
