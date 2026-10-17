import 'package:flutter_test/flutter_test.dart';
import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/features/defect_report/create_defect_bloc.dart';
import 'package:control_plane/features/defect_report/create_defect_event.dart';
import 'package:control_plane/features/defect_report/create_defect_state.dart';

import '../fixtures/defect_fixtures.dart';

/// A defect fake that also records what the form sends, so the create flow can
/// be asserted end to end without a server.
class FakeDefectRepository extends DefectRepository {
  FakeDefectRepository({super.defects});

  /// Every `listWorkItems` call's `productId`, in order.
  final List<String?> workItemFilters = [];

  /// The arguments of the last `createDefect` call.
  Map<String, Object?>? lastCreate;

  /// Arguments of every `addDefectEvidence` call.
  final List<Map<String, Object?>> evidenceCalls = [];

  /// Work items the fake reports, whatever product is asked for.
  List<WorkItemResponse> workItemsResponse = const [];

  Object? createError;
  Object? evidenceError;
  Object? productError;

  /// Hashes whose attachment throws, so a test can fail exactly one file and
  /// let the rest attach. Empty means "fail every attachment" (via
  /// [evidenceError]), which is the all-or-nothing case.
  final Set<String> evidenceFailuresFor = {};

  @override
  Future<List<ProductSummaryResponse>> listProductSummaries() async {
    if (productError != null) throw productError!;
    return super.listProductSummaries();
  }

  @override
  Future<List<WorkItemResponse>> listWorkItems({
    String? state,
    String? productId,
    int? limit,
  }) async {
    workItemFilters.add(productId);
    return workItemsResponse;
  }

  @override
  Future<CreateDefectResponse> createDefect({
    required String title,
    required String description,
    String? expectedBehavior,
    String? reproductionSteps,
    required String severity,
    String? intakeCategory,
    required String productId,
    String? affectedWorkItemId,
    String? affectedRunId,
    String? clientContextJson,
    required String reporter,
  }) async {
    if (createError != null) throw createError!;
    lastCreate = {
      'title': title,
      'description': description,
      'expectedBehavior': expectedBehavior,
      'reproductionSteps': reproductionSteps,
      'severity': severity,
      'intakeCategory': intakeCategory,
      'productId': productId,
      'affectedWorkItemId': affectedWorkItemId,
      'affectedRunId': affectedRunId,
      'clientContextJson': clientContextJson,
      'reporter': reporter,
    };
    return CreateDefectResponse(defectId: 'DEF-42');
  }

  @override
  Future<DefectEvidenceResponse> addDefectEvidence({
    required String defectId,
    required String kind,
    String? description,
    String? artifactId,
    String? contentHash,
    String? sourceRef,
  }) async {
    final failsForThis =
        evidenceFailuresFor.contains(contentHash) ||
        (evidenceFailuresFor.isEmpty && evidenceError != null);
    if (failsForThis) {
      throw evidenceError ?? StateError('artifact store rejected the upload');
    }
    evidenceCalls.add({
      'defectId': defectId,
      'kind': kind,
      'description': description,
      'contentHash': contentHash,
      'sourceRef': sourceRef,
    });
    return DefectEvidenceResponse(
      evidenceId: 'ev-1',
      defectId: defectId,
      kind: kind,
      contentHash: contentHash,
      description: description,
      sourceRef: sourceRef,
      capturedAt: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
    );
  }
}

ProductSummaryResponse product(String id, String name) =>
    ProductSummaryResponse(
      productId: id,
      name: name,
      state: 'active',
      allowsDispatch: true,
      pendingBaselineVerified: true,
      baselineFactCount: 0,
      openClarifications: 0,
      repositoryCount: 1,
      reachableRepositoryCount: 1,
      updatedAt: DateTime(2026, 1, 1),
    );

WorkItemResponse workItem(String id, String title) => WorkItemResponse(
  workItemId: id,
  title: title,
  state: 'running',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// Fills the form to the point where only `severity` is missing.
void fillRequiredExceptSeverity(CreateDefectBloc bloc) {
  bloc
    ..add(CreateDefectTitleChanged('Checkout button does nothing'))
    ..add(CreateDefectDescriptionChanged('Clicked pay, nothing happened.'))
    ..add(CreateDefectExpectedBehaviorChanged('The payment sheet opens.'))
    ..add(CreateDefectProductChanged('PRD-1'));
}

void main() {
  group('CreateDefectBloc', () {
    late FakeDefectRepository repository;

    setUp(() {
      repository = FakeDefectRepository();
    });

    CreateDefectBloc build({String? workItemId, String? runId}) =>
        CreateDefectBloc(
          repository: repository,
          reporter: 'operator@shipit.dev',
          prefilledWorkItemId: workItemId,
          prefilledRunId: runId,
        );

    /// The bloc loads options in its constructor, so every test starts by
    /// waiting for that first round to settle.
    Future<CreateDefectBloc> settled({
      String? workItemId,
      String? runId,
    }) async {
      final bloc = build(workItemId: workItemId, runId: runId);
      await pumpEventQueue();
      return bloc;
    }

    test('loads product and work-item options on start', () async {
      repository.productSummaries = [product('prod-1', 'Payments')];
      repository.workItemsResponse = [workItem('wi-001', 'Checkout breaks')];

      final bloc = await settled();
      addTearDown(bloc.close);

      expect(bloc.state.products, [('prod-1', 'Payments')]);
      expect(bloc.state.workItems, hasLength(1));
      expect(bloc.state.optionsLoading, isFalse);
      // Nothing was chosen, so the first load asked for every work item.
      expect(repository.workItemFilters, contains(null));
    });

    test('a failed option load leaves the form usable', () async {
      repository.productError = Exception('registry unreachable');

      final bloc = await settled();
      addTearDown(bloc.close);

      expect(bloc.state.products, isEmpty);
      expect(bloc.state.optionsLoading, isFalse);
      expect(bloc.state.errorMessage, isNull);
      expect(bloc.state.isValid, isFalse);
    });

    test('rejects an empty title before calling the backend', () async {
      final bloc = await settled();
      addTearDown(bloc.close);

      bloc.add(CreateDefectSubmitted());
      await pumpEventQueue();

      expect(bloc.state.errorMessage, 'Title is required');
      expect(bloc.state.success, isFalse);
      expect(repository.lastCreate, isNull);
    });

    test('rejects a missing description and a missing severity', () async {
      final bloc = await settled();
      addTearDown(bloc.close);

      bloc.add(CreateDefectTitleChanged('Checkout button does nothing'));
      bloc.add(CreateDefectSubmitted());
      await pumpEventQueue();
      expect(bloc.state.errorMessage, 'Description is required');

      bloc
        ..add(CreateDefectDescriptionChanged('Clicked pay, nothing happened.'))
        ..add(CreateDefectExpectedBehaviorChanged('The payment sheet opens.'))
        ..add(CreateDefectSubmitted());
      await pumpEventQueue();
      expect(bloc.state.errorMessage, 'Severity is required');
      expect(repository.lastCreate, isNull);
    });

    test(
      'choosing a product drops the stale work item and refilters',
      () async {
        repository.workItemsResponse = [workItem('wi-001', 'Checkout breaks')];
        final bloc = await settled();
        addTearDown(bloc.close);

        bloc
          ..add(CreateDefectAffectedWorkItemChanged('wi-001'))
          ..add(CreateDefectProductChanged('prod-1'));
        await pumpEventQueue();

        expect(bloc.state.productId, 'prod-1');
        expect(bloc.state.affectedWorkItemId, isNull);
        expect(repository.workItemFilters.last, 'prod-1');
      },
    );

    test(
      'submits trimmed fields, product and the prefilled work item',
      () async {
        repository.productSummaries = [product('prod-1', 'Payments')];
        final bloc = await settled(workItemId: 'wi-007', runId: 'run-3');
        addTearDown(bloc.close);
        fillRequiredExceptSeverity(bloc);

        bloc
          ..add(CreateDefectSeverityChanged('blocking'))
          ..add(CreateDefectProductChanged('prod-1'))
          ..add(
            CreateDefectClientContextCaptured('{"userAgent": "Flutter Web"}'),
          );
        await pumpEventQueue();

        bloc.add(CreateDefectSubmitted());
        await pumpEventQueue();

        expect(bloc.state.success, isTrue);
        expect(bloc.state.createdDefectId, 'DEF-42');
        expect(bloc.state.errorMessage, isNull);
        expect(bloc.state.partialFailureMessage, isNull);
        expect(repository.lastCreate, {
          'title': 'Checkout button does nothing',
          'description': 'Clicked pay, nothing happened.',
          'expectedBehavior': 'The payment sheet opens.',
          'reproductionSteps': '',
          'severity': 'blocking',
          'intakeCategory': null,
          'productId': 'prod-1',
          'affectedWorkItemId': 'wi-007',
          'affectedRunId': 'run-3',
          'clientContextJson': '{"userAgent": "Flutter Web"}',
          'reporter': 'operator@shipit.dev',
        });
      },
    );

    test('a backend failure is reported and no success is claimed', () async {
      repository.createError = Exception('Connection failed');
      final bloc = await settled();
      addTearDown(bloc.close);
      fillRequiredExceptSeverity(bloc);
      bloc.add(CreateDefectSeverityChanged('annoying'));
      await pumpEventQueue();

      bloc.add(CreateDefectSubmitted());
      await pumpEventQueue();

      expect(bloc.state.success, isFalse);
      expect(bloc.state.createdDefectId, isNull);
      expect(bloc.state.errorMessage, contains('Connection failed'));
      // Nothing was created, so there is no partial outcome to report either:
      // this is the one state where a failure message is the whole story.
      expect(bloc.state.partialFailureMessage, isNull);
    });

    test('attaches evidence to the new defect after it exists', () async {
      final bloc = await settled();
      addTearDown(bloc.close);
      fillRequiredExceptSeverity(bloc);
      bloc
        ..add(CreateDefectSeverityChanged('blocking'))
        ..add(
          CreateDefectEvidenceAdded([
            const CreateDefectEvidenceFile(
              name: 'failure.png',
              size: 12400,
              sha256: 'abc123',
            ),
          ]),
        );
      await pumpEventQueue();

      bloc.add(CreateDefectSubmitted());
      await pumpEventQueue();

      expect(bloc.state.success, isTrue);
      expect(repository.evidenceCalls, [
        {
          'defectId': 'DEF-42',
          'kind': 'screenshot',
          'description': 'failure.png (12.1 KB)',
          'contentHash': 'abc123',
          'sourceRef': 'file-picker',
        },
      ]);
    });

    test(
      'evidence failure keeps the report and says which file was lost',
      () async {
        repository.evidenceError = Exception('no artifact store');
        final bloc = await settled();
        addTearDown(bloc.close);
        fillRequiredExceptSeverity(bloc);
        bloc
          ..add(CreateDefectSeverityChanged('blocking'))
          ..add(
            CreateDefectEvidenceAdded([
              const CreateDefectEvidenceFile(
                name: 'failure.png',
                size: 10,
                sha256: 'abc123',
              ),
            ]),
          );
        await pumpEventQueue();

        bloc.add(CreateDefectSubmitted());
        await pumpEventQueue();

        // The defect exists and the operator must be told the file was lost.
        expect(bloc.state.success, isTrue);
        expect(bloc.state.createdDefectId, 'DEF-42');
        expect(bloc.state.partialFailureMessage, contains('failure.png'));
        // The load-bearing assertion: a created defect is NOT a failed
        // submission. Before the fix this state carried `errorMessage`, which
        // rendered as "Could not create defect" and sent the operator off to
        // file the same bug twice.
        expect(bloc.state.errorMessage, isNull);
        expect(bloc.state.hasPartialFailure, isTrue);
      },
    );

    test('a clean create carries no failure message on either field', () async {
      final bloc = await settled();
      addTearDown(bloc.close);
      fillRequiredExceptSeverity(bloc);
      bloc
        ..add(CreateDefectSeverityChanged('blocking'))
        ..add(
          CreateDefectEvidenceAdded([
            const CreateDefectEvidenceFile(
              name: 'failure.png',
              size: 10,
              sha256: 'abc123',
            ),
          ]),
        );
      await pumpEventQueue();

      bloc.add(CreateDefectSubmitted());
      await pumpEventQueue();

      expect(bloc.state.success, isTrue);
      expect(bloc.state.createdDefectId, 'DEF-42');
      expect(repository.evidenceCalls, hasLength(1));
      expect(bloc.state.partialFailureMessage, isNull);
      expect(bloc.state.errorMessage, isNull);
      expect(bloc.state.hasPartialFailure, isFalse);
    });

    test('one attachment failing still attaches the other, and names only the '
        'lost file', () async {
      repository.evidenceFailuresFor.add('bad1');
      repository.evidenceError = Exception('no artifact store');
      final bloc = await settled();
      addTearDown(bloc.close);
      fillRequiredExceptSeverity(bloc);
      bloc
        ..add(CreateDefectSeverityChanged('blocking'))
        ..add(
          CreateDefectEvidenceAdded([
            const CreateDefectEvidenceFile(
              name: 'kept.png',
              size: 10,
              sha256: 'good',
            ),
            const CreateDefectEvidenceFile(
              name: 'lost.png',
              size: 10,
              sha256: 'bad1',
            ),
          ]),
        );
      await pumpEventQueue();

      bloc.add(CreateDefectSubmitted());
      await pumpEventQueue();

      // The surviving file was really attached — a partial failure is not a
      // wholesale loss dressed up as one.
      expect(repository.evidenceCalls, hasLength(1));
      expect(repository.evidenceCalls.single['contentHash'], 'good');
      expect(bloc.state.success, isTrue);
      expect(bloc.state.createdDefectId, 'DEF-42');
      expect(bloc.state.partialFailureMessage, contains('lost.png'));
      expect(bloc.state.partialFailureMessage, isNot(contains('kept.png')));
      expect(bloc.state.errorMessage, isNull);
    });

    test('two failing attachments are both named', () async {
      repository.evidenceFailuresFor.addAll(['bad1', 'bad2']);
      repository.evidenceError = Exception('no artifact store');
      final bloc = await settled();
      addTearDown(bloc.close);
      fillRequiredExceptSeverity(bloc);
      bloc
        ..add(CreateDefectSeverityChanged('blocking'))
        ..add(
          CreateDefectEvidenceAdded([
            const CreateDefectEvidenceFile(
              name: 'first.png',
              size: 10,
              sha256: 'bad1',
            ),
            const CreateDefectEvidenceFile(
              name: 'second.png',
              size: 10,
              sha256: 'bad2',
            ),
          ]),
        );
      await pumpEventQueue();

      bloc.add(CreateDefectSubmitted());
      await pumpEventQueue();

      // Reporting only the last failure is the same defect in miniature: the
      // reporter would assume `first.png` was attached and stop looking.
      expect(bloc.state.partialFailureMessage, contains('first.png'));
      expect(bloc.state.partialFailureMessage, contains('second.png'));
      expect(bloc.state.errorMessage, isNull);
      expect(bloc.state.success, isTrue);
      expect(bloc.state.createdDefectId, 'DEF-42');
    });

    test(
      'a resubmit does not inherit the previous attempt’s failure',
      () async {
        repository.evidenceError = Exception('no artifact store');
        final bloc = await settled();
        addTearDown(bloc.close);
        fillRequiredExceptSeverity(bloc);
        bloc
          ..add(CreateDefectSeverityChanged('blocking'))
          ..add(
            CreateDefectEvidenceAdded([
              const CreateDefectEvidenceFile(
                name: 'failure.png',
                size: 10,
                sha256: 'abc123',
              ),
            ]),
          );
        await pumpEventQueue();

        bloc.add(CreateDefectSubmitted());
        await pumpEventQueue();
        expect(bloc.state.hasPartialFailure, isTrue);

        // The second attempt's attachments all succeed.
        repository.evidenceError = null;
        bloc.add(CreateDefectSubmitted());
        await pumpEventQueue();

        expect(bloc.state.partialFailureMessage, isNull);
        expect(bloc.state.errorMessage, isNull);
      },
    );

    test(
      'the state refuses to be a success and a failed submission at once',
      () {
        // The contradiction the old code relied on convention to avoid: any
        // consumer that reads `errorMessage != null` as "this failed" is right
        // for one state and wrong for the other, and only one caller existed.
        expect(
          () => CreateDefectState(
            success: true,
            createdDefectId: 'DEF-42',
            errorMessage: 'Evidence "a.png" was not attached: boom',
          ),
          throwsA(isA<AssertionError>()),
        );
      },
    );

    test('the state refuses a success that has no reference to show', () {
      // The advisory case: success with no id fell through to the editable
      // form, which is an invitation to file the same defect a second time.
      expect(
        () => CreateDefectState(success: true),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => CreateDefectState(success: true, createdDefectId: ''),
        throwsA(isA<AssertionError>()),
      );
    });

    test('removing an evidence row is bounded by the list length', () async {
      final bloc = await settled();
      addTearDown(bloc.close);

      bloc
        ..add(CreateDefectEvidenceRemoved(0))
        ..add(CreateDefectEvidenceRemoved(4));
      await pumpEventQueue();

      expect(bloc.state.evidence, isEmpty);
    });
  });

  group('CreateDefectEvidenceFile', () {
    test('reads back with a human size', () {
      const bytes = CreateDefectEvidenceFile(
        name: 'shot.png',
        size: 512,
        sha256: 'x',
      );
      const kb = CreateDefectEvidenceFile(
        name: 'trace.log',
        size: 12400,
        sha256: 'x',
      );
      const mb = CreateDefectEvidenceFile(
        name: 'video.mov',
        size: 3 * 1024 * 1024,
        sha256: 'x',
      );

      expect(bytes.description, 'shot.png (512 B)');
      expect(kb.description, 'trace.log (12.1 KB)');
      expect(mb.description, 'video.mov (3.0 MB)');
    });
  });
}
