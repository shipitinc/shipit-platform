import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/models/model_stats_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/unimplemented_repository_apis.dart';

/// The Run Duration panel must never lie, and there are three specific ways it
/// could: it could claim durations it does not have (a failed read rendered as
/// an empty table), it could drop the killed-at-budget runs that make the
/// budget question answerable (a range filter that only keeps completed runs),
/// and it could make a duration-read failure blank the cost panel beside it.
///
/// All three are here.
class FakeRepository
    with UnimplementedRepositoryApis
    implements ControlPlaneRepository {
  FakeRepository({this.samples = const [], this.samplesThrow, this.statsThrow});

  List<AgentExecutionSample> samples;
  Object? samplesThrow;
  Object? statsThrow;
  DateTime? lastFrom;
  DateTime? lastTo;
  String? lastGroupBy;

  @override
  Future<ModelStatsResponse> getModelStats({
    DateTime? from,
    DateTime? to,
    String? groupBy,
  }) async {
    if (statsThrow != null) throw statsThrow!;
    lastFrom = from;
    lastTo = to;
    lastGroupBy = groupBy;
    // 2 runs, 1 of them a success: successRate derives to 0.5. Spelled out as
    // the two counts rather than as a rate so this fake cannot drift from the
    // derivation the production mapping performs.
    return const ModelStatsResponse(
      totalExecutions: 2,
      successCount: 1,
      failureCount: 1,
      totalInputTokens: 20,
      totalOutputTokens: 80,
      totalTokens: 100,
      totalCachedReadTokens: 0,
      totalCostUsd: 1.5,
      avgCostUsd: 0.75,
      byGroup: [],
    );
  }

  @override
  Future<List<AgentExecutionSample>> listAgentExecutionSamples({
    DateTime? from,
    DateTime? to,
  }) async {
    if (samplesThrow != null) throw samplesThrow!;
    lastFrom = from;
    lastTo = to;
    return samples;
  }

  /// `UnimplementedRepositoryApis` deliberately enumerates the APIs it fakes
  /// rather than stubbing everything, so this fake covers only the two reads
  /// the Stats page makes. Anything else is unreachable from this test and says
  /// so loudly rather than returning a plausible-looking empty value.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('fake: ${invocation.memberName}');
}

AgentExecutionSample measurable(
  String role,
  String status,
  int seconds, {
  String? reason,
}) {
  final start = DateTime.utc(2026, 3, 1, 12);
  return AgentExecutionSample(
    executionId: 'agx-$role-$status-$seconds',
    workItemId: 'wi-1',
    role: role,
    status: status,
    reason: reason,
    startedAt: start,
    completedAt: start.add(Duration(seconds: seconds)),
    durationSeconds: seconds,
  );
}

AgentExecutionSample unmeasurable(String role, String status) =>
    AgentExecutionSample(
      executionId: 'agx-$role-$status-open',
      workItemId: 'wi-1',
      role: role,
      status: status,
      reason: 'still running',
      startedAt: DateTime.utc(2026, 3, 1, 12),
      completedAt: null,
      durationSeconds: null,
    );

void main() {
  test('durations and the cost projection load together', () async {
    final repository = FakeRepository(
      samples: [
        measurable('engineering_reviewer', 'completed', 900),
        measurable('engineering_reviewer', 'completed', 1800),
        measurable(
          'engineering_reviewer',
          'interrupted',
          10800,
          reason: 'execution exceeded its 10800s timeout budget',
        ),
      ],
    );
    final bloc = ModelStatsBloc(repository: repository);

    bloc.add(const ModelStatsLoaded());
    await bloc.stream.firstWhere((s) => s.durations != null);

    final state = bloc.state;
    expect(state.stats, isNotNull, reason: 'the cost panel still loaded');
    expect(state.durationErrorMessage, isNull);

    final reviewer = state.durations!.forRole('engineering_reviewer');
    final completed = reviewer.firstWhere((b) => b.status == 'completed');
    expect(completed.count, 2);
    expect(completed.medianSeconds, 1350);
    expect(completed.maxSeconds, 1800);

    final killed = reviewer.firstWhere((b) => b.status == 'interrupted');
    expect(
      killed.count,
      1,
      reason:
          'the run killed at the 3h review budget must survive into the table. '
          'It is the single most informative row on it.',
    );
    expect(killed.maxSeconds, 10800);
  });

  test('a duration read that FAILS does not blank the cost panel, and does '
      'not render as an empty table', () async {
    final repository = FakeRepository(
      samplesThrow: StateError('agent_execution unreadable'),
    );
    final bloc = ModelStatsBloc(repository: repository);

    bloc.add(const ModelStatsLoaded());
    await bloc.stream.firstWhere((s) => s.durationErrorMessage != null);

    final state = bloc.state;
    expect(
      state.stats,
      isNotNull,
      reason: 'a duration failure must not take the cost projection with it',
    );
    expect(
      state.durations,
      isNull,
      reason:
          'null means "could not be read". An EMPTY RunDurationStats would be '
          'indistinguishable from a deployment that has run nothing, and the '
          'panel renders those two states differently on purpose.',
    );
    expect(state.durationErrorMessage, contains('unreadable'));
  });

  test(
    'a cost read that FAILS still leaves the duration table standing',
    () async {
      final repository = FakeRepository(
        statsThrow: StateError('model stats unreadable'),
        samples: [measurable('implementer', 'completed', 600)],
      );
      final bloc = ModelStatsBloc(repository: repository);

      bloc.add(const ModelStatsLoaded());
      await bloc.stream.firstWhere(
        (s) => s.errorMessage != null && s.durations != null,
      );

      final state = bloc.state;
      expect(state.errorMessage, contains('unreadable'));
      expect(
        state.durations!.forRole('implementer').single.medianSeconds,
        600,
        reason:
            'the two reads are independent on purpose, so one failing does not '
            'hide the other',
      );
    },
  );

  test(
    'runs with no duration are excluded from the figures AND counted',
    () async {
      final repository = FakeRepository(
        samples: [
          measurable('implementer', 'completed', 600),
          unmeasurable('implementer', 'running'),
        ],
      );
      final bloc = ModelStatsBloc(repository: repository);

      bloc.add(const ModelStatsLoaded());
      await bloc.stream.firstWhere((s) => s.durations != null);

      final state = bloc.state;
      expect(state.durations!.forRole('implementer').single.count, 1);
      expect(
        state.unmeasuredRuns,
        1,
        reason:
            'a run with no duration is not a run of zero seconds. It is a run '
            'that was not measured, and the panel says so out loud.',
      );
    },
  );

  test('the selected time range reaches BOTH reads', () async {
    final repository = FakeRepository(
      samples: [measurable('implementer', 'completed', 600)],
    );
    final bloc = ModelStatsBloc(repository: repository);
    final from = DateTime.utc(2026, 3, 1);
    final to = DateTime.utc(2026, 3, 8);

    bloc.add(ModelStatsLoaded(from: from, to: to));
    await bloc.stream.firstWhere((s) => s.durations != null);

    expect(repository.lastFrom, from);
    expect(repository.lastTo, to);
  });

  test('no runs at all is an empty table, not an error', () async {
    final repository = FakeRepository();
    final bloc = ModelStatsBloc(repository: repository);

    bloc.add(const ModelStatsLoaded());
    await bloc.stream.firstWhere((s) => s.durations != null);

    final state = bloc.state;
    expect(state.durationErrorMessage, isNull);
    expect(state.durations!.isEmpty, isTrue);
    expect(state.durations!.samplesConsidered, 0);
    expect(state.unmeasuredRuns, 0);
  });
}
