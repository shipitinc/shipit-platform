import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/run_detail/run_detail_bloc.dart';
import 'package:control_plane/features/run_detail/run_detail_event.dart';
import 'package:control_plane/features/run_detail/operator_action_copy.dart';
import '../helpers/unimplemented_repository_apis.dart';

class MockControlPlaneRepository
    with UnimplementedRepositoryApis
    implements ControlPlaneRepository {
  MockControlPlaneRepository({this.workItemDetailResponse, this.throwError});

  WorkItemDetailResponse? workItemDetailResponse;
  Object? throwError;

  // --- the review repair ---------------------------------------------------
  //
  // Recorded rather than merely faked, because the load-bearing claim about
  // this action is about what goes ON THE WIRE: which decision is named, whose
  // name is attached, and that the reason crosses unchanged. A fake that only
  // returned a result could not see any of that.
  ReviewRepairResultResponse? repairResult;
  Object? repairError;
  final List<
    ({String requestId, String requestedBy, String reason, String? decisionId})
  >
  repairCalls = [];

  @override
  Future<ReviewRepairResultResponse> repairUnreviewedReview({
    required String workItemId,
    required String requestId,
    required String requestedBy,
    required String reason,
    String? decisionId,
  }) async {
    repairCalls.add((
      requestId: requestId,
      requestedBy: requestedBy,
      reason: reason,
      decisionId: decisionId,
    ));
    final error = repairError;
    if (error != null) throw error;
    final result = repairResult;
    if (result == null) throw StateError('no repair result in fake');
    // A real endpoint retires the decision on `accepted`, so the fake does too
    // — otherwise no test could ever reach the state the receipt has to
    // survive, which is the one state it exists for.
    if (result.repaired && workItemDetailResponse != null) {
      workItemDetailResponse = WorkItemDetailResponse(
        workItem: WorkItemResponse(
          workItemId: workItemDetailResponse!.workItem.workItemId,
          title: workItemDetailResponse!.workItem.title,
          description: workItemDetailResponse!.workItem.description,
          state: 'review_in_progress',
          createdAt: workItemDetailResponse!.workItem.createdAt,
          updatedAt: workItemDetailResponse!.workItem.updatedAt,
        ),
        transitionHistory: workItemDetailResponse!.transitionHistory,
      );
    }
    return result;
  }

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
  }) async => [];

  @override
  Future<List<DecisionResponse>> pendingDecisions({int? limit}) async => [];

  @override
  Future<WorkItemDetailResponse> inspectWorkItem(String workItemId) async {
    if (throwError != null) throw throwError!;
    if (workItemDetailResponse == null) throw StateError('No response');
    return workItemDetailResponse!;
  }

  @override
  Future<DecisionDetailResponse> inspectDecision(String workItemId) async =>
      throw UnimplementedError();

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
  group('RunDetailBloc', () {
    late MockControlPlaneRepository repository;

    setUp(() {
      repository = MockControlPlaneRepository();
    });

    test('initial state is empty', () {
      final bloc = RunDetailBloc(runId: 'wi-001', repository: repository);
      expect(bloc.state.isLoading, false);
      expect(bloc.state.runId, '');
      expect(bloc.state.name, '');
      expect(bloc.state.events, isEmpty);
    });

    test('emits loaded state with data on RunDetailLoaded', () async {
      repository.workItemDetailResponse = WorkItemDetailResponse(
        workItem: WorkItemResponse(
          workItemId: 'wi-001',
          title: 'Ship bootstrap E2E journey',
          description: 'Test the full sign-up journey',
          state: 'waiting_for_human_decision',
          blockingHumanDecisionId: 'dec-1',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        transitionHistory: [
          TransitionResponse(
            transitionId: 't-001',
            workItemId: 'wi-001',
            fromState: 'design_approved',
            toState: 'agent_executing',
            transitionedAt: DateTime(2026, 1, 1),
          ),
          TransitionResponse(
            transitionId: 't-002',
            workItemId: 'wi-001',
            fromState: 'review_in_progress',
            toState: 'waiting_for_human_decision',
            transitionedAt: DateTime(2026, 1, 1),
          ),
        ],
      );

      final bloc = RunDetailBloc(runId: 'wi-001', repository: repository)
        ..add(RunDetailLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      expect(bloc.state.runId, 'wi-001');
      expect(bloc.state.name, 'Ship bootstrap E2E journey');
      expect(bloc.state.description, 'Test the full sign-up journey');
      expect(bloc.state.state, 'waiting_for_human_decision');
      expect(bloc.state.blockingHumanDecisionId, 'dec-1');
      expect(bloc.state.events.length, 2);
      expect(bloc.state.events.first.type, 'agent_executing');
      expect(bloc.state.events.first.message, 'Agent started work');
      expect(bloc.state.events.first.raw, 'design_approved -> agent_executing');
      expect(bloc.state.events.last.message, 'Sent to you for approval');
      expect(
        bloc.state.events.last.raw,
        'review_in_progress -> waiting_for_human_decision',
      );
    });

    test(
      'unmapped transitions use neutral default and keep the raw pair',
      () async {
        repository.workItemDetailResponse = WorkItemDetailResponse(
          workItem: WorkItemResponse(
            workItemId: 'wi-001',
            title: 'Deploy frontend',
            state: 'running',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
          transitionHistory: [
            TransitionResponse(
              transitionId: 't-001',
              workItemId: 'wi-001',
              fromState: 'pending',
              toState: 'running',
              transitionedAt: DateTime(2026, 1, 1),
            ),
          ],
        );

        final bloc = RunDetailBloc(runId: 'wi-001', repository: repository)
          ..add(RunDetailLoaded());
        await bloc.stream.firstWhere((s) => !s.isLoading);

        expect(
          bloc.state.events.first.message,
          'The work moved to a new stage.',
        );
        expect(bloc.state.events.first.raw, 'pending -> running');
      },
    );

    test('emits error state on failure', () async {
      repository.throwError = Exception('Not found');

      final bloc = RunDetailBloc(runId: 'wi-001', repository: repository)
        ..add(RunDetailLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);

      expect(bloc.state.errorMessage, isNotNull);
      expect(bloc.state.errorMessage!, contains('Not found'));
    });
  });

  group('the review repair', () {
    late MockControlPlaneRepository repository;

    WorkItemDetailResponse parked({String? blockingDecisionId = 'dec-9'}) =>
        WorkItemDetailResponse(
          workItem: WorkItemResponse(
            workItemId: 'wi-001',
            title: 'Patch the scheduler CAS',
            state: 'waiting_for_human_decision',
            blockingHumanDecisionId: blockingDecisionId,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
          transitionHistory: const [],
        );

    ReviewRepairResultResponse result(
      String outcome, {
      String detail = 'why',
      String? decisionId = 'dec-9',
    }) => ReviewRepairResultResponse(
      outcome: outcome,
      detail: detail,
      workItem: WorkItemResponse(
        workItemId: 'wi-001',
        title: 'Patch the scheduler CAS',
        state: 'waiting_for_human_decision',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      decisionId: decisionId,
    );

    Future<RunDetailBloc> loaded() async {
      final bloc = RunDetailBloc(runId: 'wi-001', repository: repository)
        ..add(RunDetailLoaded());
      await bloc.stream.firstWhere((s) => !s.isLoading);
      return bloc;
    }

    setUp(() {
      repository = MockControlPlaneRepository();
    });

    test('names the item\'s OWN blocking decision, and forwards the reason '
        'verbatim', () async {
      repository.workItemDetailResponse = parked();
      repository.repairResult = result('accepted');
      final bloc = await loaded();

      bloc.add(
        RunDetailReviewRepairSubmitted(
          reason: '  no reviewer ever ran  ',
          requestId: 'op-1',
        ),
      );
      await bloc.stream.firstWhere((s) => s.repairReport != null);

      final call = repository.repairCalls.single;
      // The decision the item is actually parked on — not a guess, and not
      // null, because null would make the server resolve one and this client
      // has no business resolving it.
      expect(call.decisionId, 'dec-9');
      expect(call.requestId, 'op-1');
      expect(call.requestedBy, isNotEmpty);
      expect(call.reason, '  no reviewer ever ran  ');
    });

    test('names no decision when the item is not parked on one', () async {
      repository.workItemDetailResponse = parked(blockingDecisionId: null);
      repository.repairResult = result('notApplicable');
      final bloc = await loaded();

      bloc.add(RunDetailReviewRepairSubmitted(reason: 'x', requestId: 'op-1'));
      await bloc.stream.firstWhere((s) => s.repairReport != null);

      // Nothing to name, so nothing is invented — the server does the lookup.
      expect(repository.repairCalls.single.decisionId, isNull);
    });

    test('an accepted repair closes the strip and says it landed', () async {
      repository.workItemDetailResponse = parked();
      repository.repairResult = result('accepted');
      final bloc = await loaded();

      bloc.add(RunDetailReviewRepairStarted());
      await bloc.stream.firstWhere((s) => s.isRepairStripOpen);
      bloc.add(RunDetailReviewRepairSubmitted(reason: 'x', requestId: 'op-1'));
      await bloc.stream.firstWhere((s) => s.repairReport != null);

      expect(bloc.state.repairReport!.accepted, isTrue);
      expect(bloc.state.repairReport!.sentence, reviewRepairedSentence);
      // The strip closes: leaving a live "Void the decision" button up after it
      // has committed is an invitation to spend twice.
      expect(bloc.state.isRepairStripOpen, isFalse);
      expect(bloc.state.isSubmittingRepair, isFalse);
    });

    test(
      'a refusal carries the SERVER\'s own sentence, not a generic one',
      () async {
        repository.workItemDetailResponse = parked();
        repository.repairResult = result(
          'reviewerProducedVerdict',
          detail: 'A reviewer really did return a verdict for this decision.',
        );
        final bloc = await loaded();

        bloc.add(
          RunDetailReviewRepairSubmitted(reason: 'x', requestId: 'op-1'),
        );
        await bloc.stream.firstWhere((s) => s.repairReport != null);

        // "We could not do that. Nothing changed." would tell the operator
        // nothing they can act on; the server's sentence is the entire product of
        // a control that turned out to be wrong.
        expect(bloc.state.repairReport!.accepted, isFalse);
        expect(
          bloc.state.repairReport!.sentence,
          'A reviewer really did return a verdict for this decision.',
        );
        expect(bloc.state.repairReport!.sentence, isNot(failedSentence));
      },
    );

    test('THE RECEIPT OUTLIVES THE DECISION: a repair retires it, and the '
        'reload must not take the receipt with it', () async {
      repository.workItemDetailResponse = parked();
      repository.repairResult = result('accepted');
      final bloc = await loaded();

      bloc.add(RunDetailReviewRepairSubmitted(reason: 'x', requestId: 'op-1'));
      // Let the reload the repair triggers settle as well.
      await bloc.stream.firstWhere(
        (s) => s.repairReport != null && s.blockingHumanDecisionId == null,
      );

      // The decision is gone — that is what a repair does to it.
      expect(bloc.state.blockingHumanDecisionId, isNull);
      // And the receipt is still there, which is the only thing left telling
      // the operator what happened. Gating it on the offer condition would
      // have deleted it here, at the exact moment it mattered most.
      expect(bloc.state.repairReport, isNotNull);
      expect(bloc.state.repairReport!.accepted, isTrue);
    });

    test('starting a new repair clears the previous receipt', () async {
      repository.workItemDetailResponse = parked();
      repository.repairResult = result('accepted');
      final bloc = await loaded();

      bloc.add(RunDetailReviewRepairSubmitted(reason: 'x', requestId: 'op-1'));
      await bloc.stream.firstWhere((s) => s.repairReport != null);

      // A refusal must not be openable again on the same dead decision.
      repository.workItemDetailResponse = parked();
      bloc.add(RunDetailReviewRepairStarted());
      await bloc.stream.firstWhere((s) => s.isRepairStripOpen);
      // No stale "done" sitting under a fresh confirm strip.
      expect(bloc.state.repairReport, isNull);
    });

    // -------------------------------------------------------------------
    // THE RECEIPT IS KEYED TO A DECISION, NOT TO THE RUN
    // -------------------------------------------------------------------

    test(
      'a receipt carries the decision it CONCERNED, which is not always the '
      'one on screen',
      () async {
        // A work item parks on a decision more than once. The prior receipt's
        // SUBJECT is stable; the item's durable state is not. The receipt used
        // to carry no subject at all, so it could not be told apart from a
        // receipt about whatever is parked now — which is how the repair got
        // silently disabled for the next fabrication.
        repository.workItemDetailResponse = parked(blockingDecisionId: 'dec-9');
        repository.repairResult = result(
          'reviewerProducedVerdict',
          detail: 'a reviewer really did return a verdict',
        );
        final bloc = await loaded();

        bloc.add(
          RunDetailReviewRepairSubmitted(reason: 'x', requestId: 'op-1'),
        );
        await bloc.stream.firstWhere((s) => s.repairReport != null);

        expect(bloc.state.repairReport!.decisionId, 'dec-9');
      },
    );

    test(
      'THE RECURRENCE: a new blocking decision parks and the offer IS back',
      () async {
        // The shape the reviewer named, end to end through the bloc. Attempt a
        // repair; the re-queued review runs; the item parks behind a DIFFERENT
        // decision. The receipt is deliberately preserved across the reload, so
        // before the fix the offer was unreachable for the life of the bloc.
        repository.workItemDetailResponse = parked(blockingDecisionId: 'dec-9');
        repository.repairResult = result(
          'reviewerProducedVerdict',
          detail: 'a reviewer really did return a verdict for dec-9',
        );
        final bloc = await loaded();

        bloc.add(
          RunDetailReviewRepairSubmitted(reason: 'x', requestId: 'op-1'),
        );
        await bloc.stream.firstWhere((s) => s.repairReport != null);

        // The review ran and the item parked again — behind a different question.
        repository.workItemDetailResponse = parked(blockingDecisionId: 'dec-10');
        bloc.add(RunDetailLoaded());
        await bloc.stream.firstWhere((s) => s.blockingHumanDecisionId == 'dec-10');

        expect(bloc.state.repairReport, isNotNull, reason: 'it is preserved');
        expect(
          bloc.state.repairReport!.decisionId,
          'dec-9',
          reason:
              'the receipt is still ABOUT dec-9 — it is the item that moved, '
              'not the receipt. Asserted explicitly because a report carrying '
              'no subject would satisfy a bare `!= dec-10` comparison and make '
              'this test pass while the fix was reverted.',
        );
        expect(
          bloc.state.repairReport!.decisionId,
          isNot(bloc.state.blockingHumanDecisionId),
          reason:
              'THE WHOLE FIX, in one assertion: the receipt is about dec-9 and '
              'the item is parked on dec-10, so the offer must render rather '
              'than the stale receipt.',
        );
      },
    );

    test('the SAME decision keeps its receipt, so the one-way rule survives',
        () async {
      repository.workItemDetailResponse = parked(blockingDecisionId: 'dec-9');
      repository.repairResult = result(
        'reviewerProducedVerdict',
        detail: 'a reviewer really did return a verdict',
      );
      final bloc = await loaded();

      bloc.add(RunDetailReviewRepairSubmitted(reason: 'x', requestId: 'op-1'));
      await bloc.stream.firstWhere((s) => s.repairReport != null);

      repository.workItemDetailResponse = parked(blockingDecisionId: 'dec-9');
      bloc.add(RunDetailLoaded());
      await bloc.stream.firstWhere((s) => s.repairReport != null);
      // Let the reload settle.
      await Future<void>.delayed(Duration.zero);

      expect(
        bloc.state.repairReport!.decisionId,
        bloc.state.blockingHumanDecisionId,
        reason:
            'asking again would be refused again, identically. Keying must not '
            'become "any receipt re-offers".',
      );
    });

    test(
      'a transport failure keeps the strip, so the reason and the request id '
      'survive a retry of the same intent',
      () async {
        repository.workItemDetailResponse = parked();
        repository.repairError = Exception('connection reset');
        final bloc = await loaded();

        bloc.add(RunDetailReviewRepairStarted());
        await bloc.stream.firstWhere((s) => s.isRepairStripOpen);
        bloc.add(
          RunDetailReviewRepairSubmitted(reason: 'typed', requestId: 'op-7'),
        );
        await bloc.stream.firstWhere((s) => s.repairReport != null);

        expect(bloc.state.repairReport!.accepted, isFalse);
        // There is no `detail` to show here, so the honest sentence is the
        // generic one — and it says nothing changed, which is true.
        expect(bloc.state.repairReport!.sentence, failedSentence);
        // The strip is KEPT: the operator's words survive and the SAME request
        // id can be retried, which is the whole point of minting it once per
        // confirmation rather than per attempt.
        expect(bloc.state.isRepairStripOpen, isTrue);
        expect(bloc.state.isSubmittingRepair, isFalse);
        expect(repository.repairCalls.single.requestId, 'op-7');
      },
    );

    test('cancelling closes the strip and writes nothing', () async {
      repository.workItemDetailResponse = parked();
      final bloc = await loaded();

      bloc.add(RunDetailReviewRepairStarted());
      await bloc.stream.firstWhere((s) => s.isRepairStripOpen);
      bloc.add(RunDetailReviewRepairCancelled());
      await bloc.stream.firstWhere((s) => !s.isRepairStripOpen);

      expect(repository.repairCalls, isEmpty);
    });

    test(
      'opening the strip and backing out never touches the repository',
      () async {
        repository.workItemDetailResponse = parked();
        final bloc = await loaded();

        bloc.add(RunDetailReviewRepairStarted());
        await bloc.stream.firstWhere((s) => s.isRepairStripOpen);
        bloc.add(RunDetailReviewRepairCancelled());
        await bloc.stream.firstWhere((s) => !s.isRepairStripOpen);
        await Future<void>.delayed(Duration.zero);

        expect(repository.repairCalls, isEmpty);
        expect(repository.revision.value, 0);
      },
    );
  });
}
