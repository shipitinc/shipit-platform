import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/needs_you/needs_you_bloc.dart';
import 'package:control_plane/features/needs_you/needs_you_event.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/app_fixtures.dart';

/// Records the paging arguments so the test can prove the ledger asks for
/// successive pages rather than re-reading the first one.
class _PagingRepository extends MockRepository {
  _PagingRepository(this._total) : super(decisions: const []);

  final int _total;
  final List<(int?, int?)> calls = [];

  @override
  Future<List<DecisionResponse>> recentDecisions({
    int? limit,
    int? offset,
  }) async {
    calls.add((limit, offset));
    final start = offset ?? 0;
    final size = limit ?? 10;
    final end = (start + size).clamp(0, _total);
    if (start >= _total) return const [];
    return [
      for (var i = start; i < end; i++)
        makeDecision(
          id: 'GD-$i',
          workItemId: 'WI-$i',
          workItemTitle: 'Work $i',
          question: 'Decision $i',
        ).copyWithOutcome(
          choice: 'approve',
          resolvedAt: DateTime(2026, 9, 16, 12).subtract(Duration(hours: i)),
        ),
    ];
  }
}

void main() {
  test('the first load takes one page and reports more behind it', () async {
    final repo = _PagingRepository(25);
    final bloc = NeedsYouBloc(repository: repo)..add(NeedsYouLoaded());
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(bloc.state.resolved.length, NeedsYouBloc.historyPageSize);
    expect(bloc.state.hasMoreHistory, isTrue);
    expect(repo.calls.single, (NeedsYouBloc.historyPageSize, null));
    await bloc.close();
  });

  test('each request appends the next page by offset', () async {
    final repo = _PagingRepository(25);
    final bloc = NeedsYouBloc(repository: repo)..add(NeedsYouLoaded());
    await Future<void>.delayed(const Duration(milliseconds: 60));

    bloc.add(NeedsYouHistoryRequested());
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(bloc.state.resolved.length, 20);
    expect(repo.calls.last, (NeedsYouBloc.historyPageSize, 10));
    // No duplicates across pages.
    final ids = bloc.state.resolved.map((r) => r.decisionId).toList();
    expect(ids.toSet().length, ids.length);
    await bloc.close();
  });

  test('paging stops at the end of the record', () async {
    final repo = _PagingRepository(12);
    final bloc = NeedsYouBloc(repository: repo)..add(NeedsYouLoaded());
    await Future<void>.delayed(const Duration(milliseconds: 60));

    bloc.add(NeedsYouHistoryRequested());
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(bloc.state.resolved.length, 12);
    expect(bloc.state.hasMoreHistory, isFalse);

    // A further request must not hit the wire again.
    final before = repo.calls.length;
    bloc.add(NeedsYouHistoryRequested());
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(repo.calls.length, before);
    await bloc.close();
  });

  test('a short first page means there is nothing behind it', () async {
    final repo = _PagingRepository(3);
    final bloc = NeedsYouBloc(repository: repo)..add(NeedsYouLoaded());
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(bloc.state.resolved.length, 3);
    expect(bloc.state.hasMoreHistory, isFalse);
    await bloc.close();
  });
}
