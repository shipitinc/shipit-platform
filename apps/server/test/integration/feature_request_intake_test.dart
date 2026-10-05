import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_human_direction_store.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart'
    show ProductNotFoundException;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// The id space this suite exclusively owns.
///
/// `createFeatureWorkItem` allocates `WI-feature-<microsecondsSinceEpoch>`, and
/// nothing else in `test/` mints that prefix, so a sweep by it cannot reach
/// another suite's row.
const String _workItemId = r'^WI-feature-[0-9]+$';

/// The `human_direction` row an intake raises targets the new work item, so it
/// shares the work item's id space and the same `WI-feature-` prefix.
const String _directionTargetId = r'^WI-feature-[0-9]+$';

const String _suiteProductId = 'lane-g-feature-product';

/// Registers (or re-arms) the suite-owned product backing [_suiteProductId].
///
/// An upsert keyed on `productId`, so every test can call it without depending
/// on `setUp` ordering.
Future<String> registerSuiteProduct(PersistenceDatabase db) async {
  const name = 'Lane G Feature Product';
  await db.execute(
    'INSERT INTO "product" ("productId", "name", "description", '
    '"manifestVersion", "state", "createdAt", "updatedAt", "version") '
    'VALUES (@productId, @name, @description, @manifestVersion, @state, '
    'now(), now(), 0) ON CONFLICT ("productId") DO UPDATE SET '
    '"name" = EXCLUDED."name", "updatedAt" = now()',
    parameters: QueryParameters.named({
      'productId': _suiteProductId,
      'name': name,
      'description': 'Suite-owned product for the feature intake suite.',
      'manifestVersion': 'lane-g-feature-1',
      'state': 'active',
    }),
  );
  return name;
}

void main() {
  final openSessions = <Session>[];

  Future<PersistenceDatabase> newDb() async {
    final session = await Serverpod.instance.createSession(
      enableLogging: false,
    );
    openSessions.add(session);
    return PersistenceDatabase(session.db);
  }

  /// Removes every row this suite created, in foreign-key order.
  ///
  /// Targeted DELETEs over the suite's own id prefix, never a TRUNCATE:
  /// `test/integration` shares one PostgreSQL database with suites running
  /// concurrently, and a table-wide delete empties it for all of them.
  Future<void> purgeSuiteRows() async {
    final db = await newDb();
    const statements = <String>[
      'DELETE FROM "human_direction" WHERE "targetId" ~ \'$_directionTargetId\'',
      'DELETE FROM "work_item_transition" WHERE "workItemId" ~ \'$_workItemId\'',
      'DELETE FROM "work_item" WHERE "workItemId" ~ \'$_workItemId\'',
      'DELETE FROM "product" WHERE "productId" = \'$_suiteProductId\'',
    ];
    for (final statement in statements) {
      await db.query(statement);
    }
  }

  withServerpod(
    'feature request intake files a draft work item and its intake direction',
    (sessionBuilder, endpoints) async {
      setUp(() async {
        await purgeSuiteRows();
        await registerSuiteProduct(await newDb());
      });
      tearDown(() async {
        await purgeSuiteRows();
        for (final session in List.of(openSessions)) {
          await session.close();
        }
        openSessions.clear();
      });

      /// Reads through a session that joins the test's own transaction.
      ///
      /// `withServerpod` runs the test body in a transaction that is rolled back
      /// afterwards, and only sessions built from the [TestSessionBuilder]
      /// share it. A session from `Serverpod.instance` is outside that
      /// transaction, so it legitimately cannot see what the endpoint wrote.
      PostgresWorkflowStore storeInTestTransaction(
        TestSessionBuilder sessionBuilder,
      ) => PostgresWorkflowStore(
        PersistenceDatabase(sessionBuilder.build().db),
      );

      PostgresHumanDirectionStore directionsInTestTransaction(
        TestSessionBuilder sessionBuilder,
      ) => PostgresHumanDirectionStore(
        PersistenceDatabase(sessionBuilder.build().db),
      );

      test('creates a draft feature work item', () async {
        final result = await endpoints.intakeEndpoints.createFeatureRequest(
          sessionBuilder,
          productId: _suiteProductId,
          title: 'Dark mode',
          description: 'The console should render in dark mode.',
          reporter: 'reporter@example.com',
        );

        expect(result['workItemId'], matches(_workItemId));
        expect(result['title'], 'Dark mode');
        expect(result['state'], WorkItemState.draft.wire);

        final workItem = await storeInTestTransaction(
          sessionBuilder,
        ).readWorkItem(result['workItemId'] as String);
        expect(workItem.category, WorkItemCategory.feature);
        expect(workItem.productId, _suiteProductId);
        expect(workItem.state, WorkItemState.draft);
        expect(workItem.description, contains('dark mode'));
      });

      test(
        'raises a work-intake direction targeting the new work item',
        () async {
          final result = await endpoints.intakeEndpoints.createFeatureRequest(
            sessionBuilder,
            productId: _suiteProductId,
            title: 'Export to CSV',
            description: 'Let a human export a run to CSV.',
            reporter: 'reporter@example.com',
          );
          final workItemId = result['workItemId'] as String;

          final directions = await directionsInTestTransaction(sessionBuilder)
              .listDirectionsForTarget(
                targetType: HumanDirectionTargetType.workItem.wire,
                targetId: workItemId,
              );

          expect(directions, hasLength(1));
          expect(
            directions.single.directionType,
            HumanDirectionType.workIntake,
          );
          expect(directions.single.createdBy, 'reporter@example.com');
        },
      );

      test('rejects a product that is not registered', () async {
        // The work item and the direction are one fact. If the product check
        // let an unregistered id through, a report would be filed against a
        // product that cannot be opened — and the reporter would still be told
        // it was accepted.
        await expectLater(
          endpoints.intakeEndpoints.createFeatureRequest(
            sessionBuilder,
            productId: 'lane-g-no-such-product',
            title: 'Against a ghost',
            description: 'Filed against a product that does not exist',
            reporter: 'reporter@example.com',
          ),
          throwsA(isA<ProductNotFoundException>()),
        );
      });

      test('writes no work item when the product check fails', () async {
        // Ordering, not just rejection. The product check runs before the
        // transaction opens, so a rejected request cannot leave a work item
        // behind for a human to find attached to nothing.
        //
        // Falsifiable here: the endpoint's writes and this read share the test
        // transaction, so a work item written before the rejection *would* be
        // visible below. Finding nothing means it was never written, not that
        // the test simply cannot see it.
        await expectLater(
          endpoints.intakeEndpoints.createFeatureRequest(
            sessionBuilder,
            productId: 'lane-g-no-such-product',
            title: 'No residue',
            description: 'Must not persist a partial intake for any product.',
            reporter: 'reporter@example.com',
          ),
          throwsA(isA<ProductNotFoundException>()),
        );

        final remaining = await storeInTestTransaction(
          sessionBuilder,
        ).readAllWorkItems();
        expect(
          remaining.where((w) => w.title == 'No residue'),
          isEmpty,
        );
      });
    },
  );
}
