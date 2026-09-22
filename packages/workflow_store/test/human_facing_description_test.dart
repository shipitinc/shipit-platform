import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

void main() {
  group('humanFacingDescriptionViolation (PL-6)', () {
    test('accepts meaningful human-readable prose', () {
      expect(
        humanFacingDescriptionViolation(
          'Build the login page described in the brief.',
        ),
        isNull,
      );
    });

    test('rejects null', () {
      expect(humanFacingDescriptionViolation(null), isNotNull);
    });

    test('rejects blank and whitespace-only', () {
      expect(humanFacingDescriptionViolation(''), isNotNull);
      expect(humanFacingDescriptionViolation('   '), isNotNull);
      expect(humanFacingDescriptionViolation('\n\t '), isNotNull);
    });

    test('rejects bare technical identifiers (too short to be prose)', () {
      expect(humanFacingDescriptionViolation('wi-1'), isNotNull);
      expect(humanFacingDescriptionViolation('abc'), isNotNull);
    });

    test('rejects a description that duplicates the technical title', () {
      final violation = humanFacingDescriptionViolation(
        'Scheduler CAS patch',
        title: 'Scheduler CAS patch',
      );
      expect(violation, isNotNull);
    });

    test('trims before validating', () {
      expect(
        humanFacingDescriptionViolation('  Build the landing page.  '),
        isNull,
      );
    });
  });

  group('DurableWorkflowEngine.createWorkItem boundary (PL-6)', () {
    late InMemoryWorkflowStore store;
    late DurableWorkflowEngine engine;

    setUp(() {
      store = InMemoryWorkflowStore();
      engine = DurableWorkflowEngine(store: store);
    });

    test('accepts and persists a meaningful description', () async {
      final item = await engine.createWorkItem(
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Add landing page',
        description: 'Build the landing page described in the brief.',
        workItemId: 'wi-pl6-1',
      );
      expect(
        item.description,
        'Build the landing page described in the brief.',
      );
    });

    test('rejects whitespace-only descriptions at creation', () async {
      expect(
        () => engine.createWorkItem(
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'Add landing page',
          description: '   ',
        ),
        throwsArgumentError,
      );
      expect(
        () => store.readWorkItem('wi'),
        throwsA(isA<WorkItemNotFoundException>()),
      );
    });

    test('rejects a description duplicating the title', () async {
      expect(
        () => engine.createWorkItem(
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'Scheduler CAS patch',
          description: 'Scheduler CAS patch',
        ),
        throwsArgumentError,
      );
    });

    test('rejects a bare identifier description', () async {
      expect(
        () => engine.createWorkItem(
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'Whatever',
          description: 'dc-1',
        ),
        throwsArgumentError,
      );
    });

    test('description survives persist + reload round-trip', () async {
      await engine.createWorkItem(
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Add landing page',
        description: 'Build the landing page described in the brief.',
        workItemId: 'wi-pl6-2',
      );
      final reloaded = await engine.loadWorkItem('wi-pl6-2');
      expect(
        reloaded.description,
        'Build the landing page described in the brief.',
      );
      expect(reloaded.title, 'Add landing page');
    });

    test(
      'legacy records with null description still persist and reload',
      () async {
        final legacy = WorkItem(
          workItemId: 'wi-legacy',
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'Old historical item',
          description: null,
          state: WorkItemState.waitingForHumanDecision,
          blockingHumanDecisionId: 'dec-legacy',
          createdAt: DateTime.utc(2026, 1, 15),
          updatedAt: DateTime.utc(2026, 1, 15),
          version: 3,
        );
        await store.saveWorkItem(legacy);

        final reloaded = await store.readWorkItem('wi-legacy');
        expect(reloaded.description, isNull);
        expect(reloaded.title, 'Old historical item');
        expect(reloaded.blockingHumanDecisionId, 'dec-legacy');
      },
    );
  });
}
