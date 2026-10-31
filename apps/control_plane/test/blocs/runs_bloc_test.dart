import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:control_plane/core/plain_language.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/runs/runs_bloc.dart';
import 'package:control_plane/features/runs/runs_event.dart';
import '../helpers/unimplemented_repository_apis.dart';

class MockControlPlaneRepository
    with UnimplementedRepositoryApis
    implements ControlPlaneRepository {
  MockControlPlaneRepository({this.workItemsResponse, this.throwError});

  List<WorkItemResponse>? workItemsResponse;
  Object? throwError;

  @override
  Future<ProductDetailResponse> getProductDetail(String productId) async {
    final d = productDetail;
    if (d == null) throw StateError('no product detail in fake');
    return d;
  }

  /// Detail the fake returns. Null unless a test sets it.
  ProductDetailResponse? productDetail;

  @override
  Future<List<ProductSummaryResponse>> listProductSummaries() async =>
      productSummaries;

  /// Products the fake reports. Empty unless a test sets it.
  List<ProductSummaryResponse> productSummaries = const [];

  @override
  Future<OverviewResponse> getOverview() async => throw UnimplementedError();

  @override
  Future<List<WorkItemResponse>> listWorkItems({
    String? state,
    String? productId,
    int? limit,
  }) async {
    if (throwError != null) throw throwError!;
    return workItemsResponse ?? [];
  }

  @override
  Future<List<DecisionResponse>> pendingDecisions({int? limit}) async => [];

  @override
  Future<WorkItemDetailResponse> inspectWorkItem(String workItemId) async =>
      throw UnimplementedError();

  @override
  Future<DecisionDetailResponse> inspectDecision(
    String workItemId, {
    String? decisionId,
  }) async => throw UnimplementedError();

  @override
  Future<void> resolveDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
  }) async {}
  @override
  Future<List<JobSummaryResponse>> jobsForWorkItem(String workItemId) async =>
      const [];
  @override
  Future<List<DecisionResponse>> recentDecisions({
    int? limit,
    int? offset,
  }) async => const [];
  @override
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  // ---- ADR 0020 + ADR 0019 governance fakes -------------------------------

  @override
  Future<DecisionResponse> requestLifecycleDecision({
    required String productId,
    required String action,
    bool drainInFlight = true,
  }) async => throw UnimplementedError('fake: requestLifecycleDecision');

  @override
  Future<DecisionResponse> requestPolicyAuthorisation({
    required String productId,
    required List<String> actions,
  }) async => throw UnimplementedError('fake: requestPolicyAuthorisation');

  @override
  Future<DecisionResponse> resolveLifecycleDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    bool noWorkInFlight = false,
  }) async => throw UnimplementedError('fake: resolveLifecycleDecision');

  @override
  Future<PolicyResponse> resolvePolicyAuthorisation({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
  }) async => throw UnimplementedError('fake: resolvePolicyAuthorisation');

  @override
  Future<void> revokeStandingPolicy({
    required String productId,
    required String policyId,
    required String revokedBy,
  }) async => throw UnimplementedError('fake: revokeStandingPolicy');

  @override
  Future<void> addRepositoryReference({
    required String productId,
    required String repositoryId,
    required String uri,
    required String kind,
    required String provider,
  }) async => throw UnimplementedError('fake: addRepositoryReference');

  @override
  Future<ProductDetailResponse> createProduct({
    required String productId,
    required String name,
    String? description,
    required String manifestJson,
    String? manifestVersion,
  }) async => throw UnimplementedError('fake: createProduct');
}

void main() {
  group('RunsBloc', () {
    late MockControlPlaneRepository repository;

    setUp(() {
      repository = MockControlPlaneRepository();
    });

    test('initial state is empty', () {
      final bloc = RunsBloc(repository: repository);
      expect(bloc.state.isLoading, false);
      expect(bloc.state.runs, isEmpty);
    });

    test('emits loaded state with data on RunsLoaded', () async {
      repository.workItemsResponse = [
        WorkItemResponse(
          workItemId: 'wi-001',
          title: 'Deploy frontend',
          state: 'running',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        WorkItemResponse(
          workItemId: 'wi-002',
          title: 'Run tests',
          state: 'success',
          createdAt: DateTime(2026, 1, 2),
          updatedAt: DateTime(2026, 1, 2),
        ),
      ];

      final bloc = RunsBloc(repository: repository)..add(RunsLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      expect(bloc.state.runs.length, 2);
      expect(bloc.state.runs.first.id, 'wi-001');
      expect(bloc.state.runs.first.name, 'Deploy frontend');
      expect(bloc.state.runs.first.state, 'running');
      expect(bloc.state.runs.last.id, 'wi-002');
    });

    test('emits error state on failure', () async {
      repository.throwError = Exception('Network error');

      final bloc = RunsBloc(repository: repository)..add(RunsLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      expect(bloc.state.errorMessage, isNotNull);
      expect(bloc.state.errorMessage!, contains('Network error'));
    });

    test('filters runs by the working-on-it bucket', () async {
      repository.workItemsResponse = [
        WorkItemResponse(
          workItemId: 'wi-001',
          title: 'Deploy frontend',
          state: 'agent_executing',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        WorkItemResponse(
          workItemId: 'wi-002',
          title: 'Run tests',
          state: 'completed',
          createdAt: DateTime(2026, 1, 2),
          updatedAt: DateTime(2026, 1, 2),
        ),
      ];

      final bloc = RunsBloc(repository: repository)..add(RunsLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      bloc.add(const RunsFilterChanged(RunsFilter.workingOnIt));
      await bloc.stream.firstWhere((s) => s.filter == RunsFilter.workingOnIt);

      expect(bloc.state.runs.length, 1);
      expect(bloc.state.runs.first.id, 'wi-001');
    });

    test(
      'working-on-it keeps every status the operator reads as work in flight',
      () async {
        // This test used to assert the OPPOSITE for `agent_completed`, and it
        // was pinning the defect rather than the intent. The bloc had its own
        // `workingOnIt` — a strict `== PlainStatus.workingOnIt` — which excluded
        // `awaitingReview`, `waitingToStart` and `readyToBuild`, all of which
        // the filter the page actually applies includes. The bloc's copy is
        // gone; there is one implementation now, and this states what it says.
        repository.workItemsResponse = [
          for (final state in [
            'planning',
            'agent_executing',
            'qa_in_progress',
            'deploying',
          ])
            WorkItemResponse(
              workItemId: 'wi-$state',
              title: 'Active $state',
              state: state,
              createdAt: DateTime(2026, 1, 1),
              updatedAt: DateTime(2026, 1, 1),
            ),
          WorkItemResponse(
            workItemId: 'wi-awaiting-review',
            title: 'Finished its work, now awaiting review',
            state: 'agent_completed',
            createdAt: DateTime(2026, 1, 2),
            updatedAt: DateTime(2026, 1, 2),
          ),
          WorkItemResponse(
            workItemId: 'wi-ready-to-build',
            title: 'Queued for the implementation lane',
            state: 'implementation_ready',
            createdAt: DateTime(2026, 1, 3),
            updatedAt: DateTime(2026, 1, 3),
          ),
          WorkItemResponse(
            workItemId: 'wi-waiting-to-start',
            title: 'Accepted, not picked up yet',
            state: 'draft',
            createdAt: DateTime(2026, 1, 4),
            updatedAt: DateTime(2026, 1, 4),
          ),
        ];

        final bloc = RunsBloc(repository: repository)..add(RunsLoaded());
        await bloc.stream.firstWhere((s) => !s.isLoading);

        bloc.add(const RunsFilterChanged(RunsFilter.workingOnIt));
        await bloc.stream.firstWhere((s) => s.filter == RunsFilter.workingOnIt);

        expect(bloc.state.runs.map((r) => r.id).toSet(), {
          'wi-planning',
          'wi-agent_executing',
          'wi-qa_in_progress',
          'wi-deploying',
          'wi-awaiting-review',
          'wi-ready-to-build',
          'wi-waiting-to-start',
        });
      },
    );

    test('needs-you filter only surfaces blocked items', () async {
      repository.workItemsResponse = [
        WorkItemResponse(
          workItemId: 'wi-001',
          title: 'Deploy frontend',
          state: 'agent_executing',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        WorkItemResponse(
          workItemId: 'wi-002',
          title: 'Fix auth',
          state: 'waiting_for_human_decision',
          blockingHumanDecisionId: 'dec-1',
          createdAt: DateTime(2026, 1, 2),
          updatedAt: DateTime(2026, 1, 2),
        ),
      ];

      final bloc = RunsBloc(repository: repository)..add(RunsLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      bloc.add(const RunsFilterChanged(RunsFilter.needsYou));
      await bloc.stream.firstWhere((s) => s.filter == RunsFilter.needsYou);

      expect(bloc.state.runs.length, 1);
      expect(bloc.state.runs.first.id, 'wi-002');
    });

    test('plainName prefers the plain description over the title', () {
      final item = RunItem(
        id: 'wi-1',
        name: 'Scheduler claim-CAS dedupe patch',
        description: 'Stop duplicate jobs running twice',
        state: 'agent_executing',
        startedAt: DateTime(2026, 1, 1),
        agent: 'opencode',
        category: 'workflow',
      );
      expect(item.plainName, 'Stop duplicate jobs running twice');
      expect(
        RunItem(
          id: 'wi-2',
          name: 'No description here',
          state: 'completed',
          startedAt: DateTime(2026, 1, 1),
          agent: 'opencode',
          category: 'workflow',
        ).plainName,
        'No description here',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // THE FILTER TRUTH TABLE — the executable form of the duplication finding.
  //
  // `RunsBloc` once answered "which rows belong under Working on it?" with a
  // switch of its own, over a separate `RunsFilter` enum, and it disagreed with
  // the `WorkFilter` the page applies. It disagreed SILENTLY, and it disagreed
  // safely: the page re-filters what it renders, so the wrong answer was
  // overwritten before it reached a screen, and `state.filter` is always
  // `RunsFilter.all` in production, so the wrong arms were unreachable. Two
  // predicates, one invisible, one unused — which is exactly the shape a defect
  // hides in until somebody wires the unused one up.
  //
  // There is now one implementation, `WorkFilter.matches`. Asserting "the bloc
  // calls WorkFilter" would prove nothing — it would pass just as happily
  // against a second switch that also happens to be right. What stops the
  // duplication regrowing is the table below: it states, for EVERY status, which
  // filters a row belongs under, written out independently of
  // `WorkFilter.matches`. A predicate reintroduced in the bloc diverges from
  // this table and the test fails; a new `PlainStatus` that no row of the table
  // mentions fails too, so the domain cannot grow a status that silently lands
  // in no bucket at all.
  // ---------------------------------------------------------------------------
  group('the bloc filters by exactly the statuses each tab claims', () {
    late MockControlPlaneRepository repository;

    /// Which filters a row of each status appears under.
    ///
    /// `all` is omitted because every row is under it; that is checked
    /// separately rather than asserted here for all eight statuses.
    const Map<PlainStatus, Set<String>> includedIn = {
      PlainStatus.workingOnIt: {'workingOnIt'},
      PlainStatus.awaitingReview: {'workingOnIt'},
      PlainStatus.waitingToStart: {'workingOnIt'},
      PlainStatus.readyToBuild: {'workingOnIt'},
      PlainStatus.needsYourApproval: {'needsYou'},
      PlainStatus.needsYouItFailed: {'needsYou', 'failed'},
      PlainStatus.finished: {'finished'},
      PlainStatus.stopped: {'failed'},
    };

    /// One fixture wire value per status, so the table above is exercised by
    /// real rows rather than by a fabricated `RunItem` list.
    const List<({String id, String state, bool blocked})> fixtures = [
      (id: 'wi-working', state: 'agent_executing', blocked: false),
      (id: 'wi-awaiting', state: 'agent_completed', blocked: false),
      (id: 'wi-waiting', state: 'draft', blocked: false),
      (id: 'wi-ready', state: 'implementation_ready', blocked: false),
      (id: 'wi-approval', state: 'waiting_for_human_decision', blocked: true),
      (id: 'wi-failed-blocked', state: 'agent_failed', blocked: true),
      (id: 'wi-failed', state: 'agent_failed', blocked: false),
      (id: 'wi-finished', state: 'completed', blocked: false),
      (id: 'wi-stopped', state: 'cancelled', blocked: false),
    ];

    setUp(() {
      repository = MockControlPlaneRepository(
        workItemsResponse: [
          for (final f in fixtures)
            WorkItemResponse(
              workItemId: f.id,
              title: 'Fixture ${f.id}',
              state: f.state,
              blockingHumanDecisionId: f.blocked ? 'dec-1' : null,
              createdAt: DateTime(2026, 1, 1),
              updatedAt: DateTime(2026, 1, 1),
            ),
        ],
      );
    });

    test(
      'the table covers every PlainStatus, so none can fall into no bucket',
      () {
        expect(
          includedIn.keys.toSet(),
          PlainStatus.values.toSet(),
          reason:
              'a new PlainStatus with no row here would appear under no tab at '
              'all, silently. Adding it must mean deciding which tabs it belongs '
              'under — which is the decision the duplication used to make twice',
        );
      },
    );

    test('the three statuses that made the trap are under Working on it', () {
      expect(
        includedIn[PlainStatus.readyToBuild],
        {'workingOnIt'},
        reason:
            'an `implementation_ready` row IS work in flight from the operator\'s '
            'side: the system is about to start on it by itself and nobody is '
            'being waited on. The duplicate predicate here excluded it, which '
            'is the whole finding',
      );
      expect(includedIn[PlainStatus.awaitingReview], {'workingOnIt'});
      expect(includedIn[PlainStatus.waitingToStart], {'workingOnIt'});
    });

    for (final filter in RunsFilter.values) {
      test('the bloc agrees with the table under ${filter.name}', () async {
        final bloc = RunsBloc(repository: repository)..add(RunsLoaded());
        await bloc.stream.firstWhere((s) => !s.isLoading);

        bloc.add(RunsFilterChanged(filter));
        await bloc.stream.firstWhere((s) => s.filter == filter);

        final expected = <String>{
          for (final f in fixtures)
            if (filter == RunsFilter.all ||
                includedIn[PlainLanguage.statusFor(
                      f.state,
                      blocked: f.blocked,
                    )]!
                    .contains(filter.name))
              f.id,
        };

        expect(
          bloc.state.runs.map((r) => r.id).toSet(),
          expected,
          reason:
              'under "${filter.label}" the bloc must return exactly the rows the '
              'table above says belong there. A disagreement means a second '
              'predicate has grown next to `WorkFilter.matches`',
        );
      });
    }
  });
}
