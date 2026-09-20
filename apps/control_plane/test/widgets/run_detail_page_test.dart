import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/run_detail/run_detail_bloc.dart';
import 'package:control_plane/features/run_detail/run_detail_page.dart';

import '../fixtures/app_fixtures.dart';

void main() {
  Future<RunDetailBloc> pump(
    WidgetTester tester, {
    required WorkItemDetailResponse detail,
  }) async {
    final repository = MockRepository(workItemDetail: detail);
    final bloc = createSeededRunDetailBloc(repository: repository);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<RunDetailBloc>.value(
          value: bloc,
          child: Scaffold(
            body: RunDetailPage(runId: 'wi-1', bloc: bloc),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return bloc;
  }

  WorkItemDetailResponse detail({
    String? description,
    String state = 'agent_executing',
    String? blockingHumanDecisionId,
    List<TransitionResponse> transitions = const [],
  }) {
    return WorkItemDetailResponse(
      workItem: WorkItemResponse(
        workItemId: 'wi-1',
        title: 'Scheduler CAS patch',
        description: description,
        state: state,
        blockingHumanDecisionId: blockingHumanDecisionId,
        createdAt: DateTime(2026, 9, 15, 10, 0),
        updatedAt: DateTime(2026, 9, 15, 10, 30),
      ),
      transitionHistory: transitions,
    );
  }

  testWidgets(
    'description leads; ref on the breadcrumb, technical title disclosed',
    (tester) async {
      await pump(
        tester,
        detail: detail(description: 'Stop duplicate jobs from running twice.'),
      );

      // The plain description is the headline.
      final headline = tester.widget<Text>(
        find.byKey(const Key('run-detail-title')),
      );
      expect(headline.data, 'Stop duplicate jobs from running twice.');

      // The reference stays visible on the breadcrumb.
      expect(find.textContaining('ref wi-1'), findsWidgets);

      // The technical title is not lost - it lives under the disclosure.
      expect(find.textContaining('Scheduler CAS patch'), findsNothing);
      await tester.tap(find.textContaining('Show technical details'));
      await tester.pumpAndSettle();
      expect(find.textContaining('title: Scheduler CAS patch'), findsOneWidget);
    },
  );

  testWidgets(
    'legacy item with no description falls back to the technical title',
    (tester) async {
      await pump(tester, detail: detail(description: null));

      final headline = tester.widget<Text>(
        find.byKey(const Key('run-detail-title')),
      );
      expect(headline.data, 'Scheduler CAS patch');
      expect(find.textContaining('ref wi-1'), findsWidgets);
    },
  );

  testWidgets('known transition renders plain copy', (tester) async {
    await pump(
      tester,
      detail: detail(
        transitions: [
          makeTransition(from: 'design_not_required', to: 'agent_executing'),
        ],
      ),
    );
    expect(find.text('Agent started work'), findsOneWidget);
  });

  testWidgets(
    'unknown transition uses neutral default and preserves raw pair',
    (tester) async {
      await pump(
        tester,
        detail: detail(
          transitions: [makeTransition(from: 'pending', to: 'running')],
        ),
      );
      expect(find.text('The work moved to a new stage.'), findsOneWidget);

      // The raw state pair is preserved, under the disclosure.
      await tester.tap(find.textContaining('Show technical details'));
      await tester.pumpAndSettle();
      expect(find.textContaining('pending -> running'), findsOneWidget);
    },
  );

  testWidgets('Review and decide CTA only for a blocking human gate', (
    tester,
  ) async {
    await pump(
      tester,
      detail: detail(
        description: 'Blocked item awaiting approval.',
        state: 'waiting_for_human_decision',
        blockingHumanDecisionId: 'dec-1',
      ),
    );
    expect(find.text('Review and decide'), findsOneWidget);

    await pump(
      tester,
      detail: detail(
        description: 'Running normally.',
        state: 'agent_executing',
      ),
    );
    expect(find.text('Review and decide'), findsNothing);
  });
}
