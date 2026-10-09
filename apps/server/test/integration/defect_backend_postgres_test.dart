import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart'
    show ProductNotFoundException;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart' show DurableWorkflowEngine;

import 'test_tools/serverpod_test_tools.dart';

/// The id space this suite exclusively owns.
///
/// `ControlPlaneService.createDefect` allocates `DEF-<microsecondsSinceEpoch>`,
/// and this file is the only caller of that path in `test/`. The sibling
/// `triage_execution_test.dart` seeds its defects as `DEF-triage-r<n>`, so an
/// all-digits suffix is a marker no other suite's row can carry.
const String _defectId = r'^DEF-[0-9]+$';

/// `defectTriageWorkItemId(defectId)` is `defect-<defectId>`, and the triage
/// job is enqueued against that work item.
const String _workItemId = r'^defect-DEF-[0-9]+$';

/// Since B8, every `createDefect` provisions a real `QAContract` through
/// `buildAdvisoryTriageQAContract`, whose id is `qa-triage-<defectId>`
/// (`triageQAContractIdForDefect`). The `qa_contract` table is keyed by that
/// contract id and declares no foreign key to `defect` or `work_item`, so no
/// sweep by defect id or work item id can reach it and this suite leaked one
/// orphaned advisory declaration per created defect.
const String _qaContractId = r'^qa-triage-DEF-[0-9]+$';

/// The product every defect in this suite is filed against.
///
/// `createDefect` requires a `productId`, and the service resolves the display
/// name through the Product Registry. A real `product` row is registered for
/// this id in [registerSuiteProduct] so the enrichment path is exercised
/// against a registry row rather than a miss.
const String _suiteProductId = 'lane-f-defect-product';

/// Registers (or re-arms) the suite-owned [ProductRow] backing
/// [_suiteProductId].
///
/// Written with the store's own `ON CONFLICT` shape so it is idempotent and
/// every test can call it without a `setUp` ordering dependency. Returns the
/// name the service should surface for the id, so tests can assert enrichment
/// against the value rather than a hardcoded duplicate of it.
Future<String> registerSuiteProduct(PersistenceDatabase db) async {
  const name = 'Lane F Defect Product';
  await db.execute(
    'INSERT INTO "product" ("productId", "name", "description", '
    '"manifestVersion", "state", "createdAt", "updatedAt", "version") '
    "VALUES (@productId, @name, @description, @manifestVersion, @state, "
    'now(), now(), 0) ON CONFLICT ("productId") DO UPDATE SET '
    '"name" = EXCLUDED."name", "updatedAt" = now()',
    parameters: QueryParameters.named({
      'productId': _suiteProductId,
      'name': name,
      'description': 'Suite-owned product for the defect backend suite.',
      'manifestVersion': 'lane-f-defect-1',
      'state': 'active',
    }),
  );
  return name;
}

/// `requestClarification` raises its blocking decision against
/// `defect-clarification:<defectId>` and `verifyFix` against
/// `defect-fix-verification:<defectId>`.
const String _decisionWorkItemId =
    r'^defect-(clarification|fix-verification):DEF-[0-9]+$';

/// A work item under a product id unique to this suite, used to scope the
/// `defect` reads below to the defects this suite created.
///
/// `PostgresDefectStore.listDefects` / `countDefects` read the whole `defect`
/// table, which `test/integration` shares with suites that leave their own
/// rows behind (`triage_execution_test.dart` keeps a `DEF-triage-r<n>` defect
/// per test). Neither method takes a reporter or a `defectId` filter, so an
/// unfiltered `list()` legitimately returns another suite's defects and an
/// unscoped `hasLength(n)` is a race against that suite's timing.
///
/// The `productId` filter is the one production-side filter that can scope
/// the COUNT as well as the rows: it resolves through
/// `"affectedWorkItemId" IN (SELECT "workItemId" FROM "work_item" WHERE
/// "productId" = @productId)`, so a work item filed under a suite-unique
/// product id scopes `totalCount` to exactly the defects linked to it —
/// computed by the production SQL, not by the test. Row-level assertions are
/// additionally pinned on the suite-unique `affectedWorkItemId`, which needs
/// no work item row at all (`defect."affectedWorkItemId"` has no foreign key).
class _DefectReadScope {
  _DefectReadScope({
    required this.db,
    required this.productId,
    required this.workItemId,
  });

  final PersistenceDatabase db;
  final String productId;
  final String workItemId;

  /// Additional anchor work items created inside [productId] by a test that
  /// needs more than one (the `affectedWorkItemId` split test). Cleaned up
  /// together with the scope's own work item.
  final List<String> extraWorkItemIds = <String>[];

  /// The `affectedWorkItemId` to stamp on a defect so it lands inside this
  /// scope. Uses the work item id itself, so the value is unique per scope.
  String get affectedWorkItemId => workItemId;

  /// Deletes every work item this scope created, with its transition history.
  ///
  /// Targeted DELETEs by exact id, in FK order. Called from the owning test's
  /// `addTearDown` rather than from [purgeSuiteRows] because the scope work
  /// items are not part of the defect fan-out the sweep exists for, and the
  /// sweep's markers are `DEF-<digits>` shapes these ids deliberately are not.
  Future<void> dispose() async {
    for (final id in [workItemId, ...extraWorkItemIds]) {
      await db.query(
        'DELETE FROM "work_item_transition" WHERE "workItemId" = \'$id\'',
      );
      await db.query('DELETE FROM "work_item" WHERE "workItemId" = \'$id\'');
    }
  }
}

/// Creates a [WorkItem] under a product id no other suite can collide with.
///
/// A `draft` work item is inert to every other suite: it is not an entry state
/// of `triageDefectDefinition`, so `RunnableWorkEvaluator` classifies it
/// `noAction` and no scheduler ever enqueues or dispatches for it. It is
/// created through [DurableWorkflowEngine] so it goes through the same durable
/// write path production uses, and it is never transitioned.
Future<_DefectReadScope> _createDefectReadScope(
  PersistenceDatabase db, {
  required String label,
  required int counter,
}) async {
  final suffix = '$label-$counter';
  final productId = 'lane-f-defect-scope-$suffix';
  final workItemId = 'lane-f-scope-wi-$suffix';
  await DurableWorkflowEngine(store: PostgresWorkflowStore(db)).createWorkItem(
    workItemId: workItemId,
    productId: productId,
    category: WorkItemCategory.chore,
    title: 'Read scope for the defect backend suite ($suffix)',
    description:
        'Suite-owned anchor work item. Defects created against it are the '
        'only rows the product-scoped defect reads in this file can return, '
        'so the assertions cannot observe another suite\'s defects.',
  );
  return _DefectReadScope(db: db, productId: productId, workItemId: workItemId);
}

void main() {
  final openSessions = <Session>[];
  var scopeCounter = 0;

  Future<PersistenceDatabase> newDb() async {
    final session = await Serverpod.instance.createSession(
      enableLogging: false,
    );
    openSessions.add(session);
    return PersistenceDatabase(session.db);
  }

  /// Removes every row this suite could have created, in an order that
  /// satisfies foreign keys.
  ///
  /// A targeted DELETE scoped to this suite's own id space, never a TRUNCATE:
  /// `test/integration` shares one PostgreSQL database with other test files
  /// that run concurrently, and `TRUNCATE ... CASCADE` on `defect` empties the
  /// table for every suite at once. It did exactly that to
  /// `triage_execution_test.dart`, whose `DEF-triage-r<n>` defects were
  /// deleted out from under a running test. This mirrors the purge helper that
  /// suite already uses correctly (`triage_execution_test.dart` `purgeSuiteRows`)
  /// and keeps the blast radius inside this file.
  ///
  /// It also covers the rows a defect *create* fans out into beyond the defect
  /// tables: `createDefect` durably provisions a triage `WorkItem` and enqueues
  /// a triage `Job`, and `requestClarification` / `verifyFix` each raise a
  /// `HumanDecision`. The previous truncate list missed every one of those, so
  /// they leaked into the shared database permanently.
  ///
  /// The scope is the id space `ControlPlaneService.createDefect` allocates
  /// (`'DEF-${now.microsecondsSinceEpoch}'`), and this file is the only caller
  /// of that path in `test/`, so `DEF-<digits>` is this suite's exclusive
  /// marker. The triage suite's `DEF-triage-r<n>` ids contain no digits after
  /// the prefix and can never match, which is what makes the sweep safe to run
  /// while that suite is mid-test.
  Future<void> purgeSuiteRows() async {
    final db = await newDb();
    // One statement per call: the driver sends a parameterised command as a
    // prepared statement, which accepts exactly one command at a time.
    const statements = <String>[
      'DELETE FROM "product"                WHERE "productId" = \'$_suiteProductId\'',
      'DELETE FROM "triage_result"        WHERE "defectId" ~ \'$_defectId\'',
      'DELETE FROM "defect_clarification" WHERE "defectId" ~ \'$_defectId\'',
      'DELETE FROM "defect_event"         WHERE "defectId" ~ \'$_defectId\'',
      'DELETE FROM "defect_evidence"      WHERE "defectId" ~ \'$_defectId\'',
      'DELETE FROM "human_decision"       WHERE "workItemId" ~ \'$_decisionWorkItemId\'',
      'DELETE FROM "scheduler_event"      WHERE "workItemId" ~ \'$_workItemId\'',
      'DELETE FROM "job_claim" WHERE "jobId" IN '
          '(SELECT "jobId" FROM "job" WHERE "workItemId" ~ \'$_workItemId\')',
      'DELETE FROM "job"                  WHERE "workItemId" ~ \'$_workItemId\'',
      'DELETE FROM "work_item_transition" WHERE "workItemId" ~ \'$_workItemId\'',
      'DELETE FROM "work_item"            WHERE "workItemId" ~ \'$_workItemId\'',
      'DELETE FROM "defect"               WHERE "defectId" ~ \'$_defectId\'',
      // Since B8 every `createDefect` provisions a real `QAContract`, keyed
      // `qa-triage-<defectId>` with no FK to `defect`/`work_item`, so the
      // statements above cannot reach it. Purge it or this suite leaks one
      // orphaned contract per created defect.
      'DELETE FROM "qa_contract" WHERE "contractId" ~ \'$_qaContractId\'',
    ];
    for (final statement in statements) {
      await db.query(statement);
    }
  }

  withServerpod(
    'durable defect backend exercises Postgres CRUD and CAS via typed endpoints',
    (sessionBuilder, endpoints) {
      setUp(() async {
        await purgeSuiteRows();
        await registerSuiteProduct(await newDb());
      });
      tearDown(() async {
        // Purge before closing the sessions so the shared integration database
        // is left as this suite found it. A previous run that aborted mid-test
        // is handled by the same sweep in setUp.
        await purgeSuiteRows();
        for (final session in List.of(openSessions)) {
          await session.close();
        }
        openSessions.clear();
      });

      group('create defect', () {
        test('creates defect with initial evidence and event', () async {
          final result = await endpoints.defectEndpoints.create(
            sessionBuilder,
            productId: _suiteProductId,
            title: 'Test Defect',
            description: 'A test defect',
            expectedBehavior: 'Should work',
            reproductionSteps: '1. Do this\n2. Do that',
            severity: 'high',
            intakeCategory: 'bug',
            affectedWorkItemId: 'wi-1',
            affectedRunId: 'run-1',
            clientContextJson: '{"browser": "chrome"}',
            reporter: 'test@example.com',
          );

          expect(result.defectId, isNotEmpty);
          expect(result.title, 'Test Defect');
          expect(result.status, DefectStatus.reported.wire);
        });

        test('returns defect with correct wire values', () async {
          final result = await endpoints.defectEndpoints.create(
            sessionBuilder,
            productId: _suiteProductId,
            title: 'Wire Test',
            description: 'Test wire',
            severity: 'critical',
            intakeCategory: 'bug',
            reporter: 'wire@example.com',
          );

          expect(result.status, DefectStatus.reported.wire);
          // A REAL `DateTime`, not the ISO-8601 string the endpoint used to
          // pre-format by hand. That is the whole reason the return type is a
          // model: the client parses this field with Serverpod's deserializer
          // instead of calling `DateTime.parse` on a string nobody typed.
          expect(result.createdAt, isA<DateTime>());
        });

        test('rejects a product that is not registered', () async {
          // A defect is filed *against* a product. An id with no registry row is
          // a broken reference, and accepting it would leave a row whose name
          // can never resolve on any read path.
          await expectLater(
            endpoints.defectEndpoints.create(
              sessionBuilder,
              productId: 'lane-f-no-such-product',
              title: 'Unregistered Product',
              description: 'Filed against a product that does not exist',
              severity: 'high',
              intakeCategory: 'bug',
              reporter: 'nobody@example.com',
            ),
            throwsA(isA<ProductNotFoundException>()),
          );
        });
      });

      group('list defects', () {
        test('filters by status', () async {
          // Scoped to this suite: see `_DefectReadScope`. `productId` scopes
          // both halves of the response (the `defects` list AND `totalCount`,
          // which is a global `COUNT(*)` in production and cannot be narrowed
          // any other way without editing production).
          final scope = await _createDefectReadScope(
            await newDb(),
            label: 'status',
            counter: scopeCounter++,
          );
          addTearDown(scope.dispose);

          final first = await endpoints.defectEndpoints.create(
            sessionBuilder,
            productId: _suiteProductId,
            title: 'Defect 1',
            description: 'Desc 1',
            severity: 'high',
            intakeCategory: 'bug',
            affectedWorkItemId: scope.affectedWorkItemId,
            reporter: 'a@a.com',
          );
          final second = await endpoints.defectEndpoints.create(
            sessionBuilder,
            productId: _suiteProductId,
            title: 'Defect 2',
            description: 'Desc 2',
            severity: 'medium',
            intakeCategory: 'feature',
            affectedWorkItemId: scope.affectedWorkItemId,
            reporter: 'b@b.com',
          );

          final created = await endpoints.defectEndpoints.list(
            sessionBuilder,
            productId: scope.productId,
            status: DefectStatus.reported.wire,
            limit: 10,
            offset: 0,
          );

          expect(created.defects, hasLength(2));
          expect(created.totalCount, 2);
          expect(
            created.defects.map((d) => d.defectId).toSet(),
            {first.defectId, second.defectId},
          );

          // The status filter is real rather than a pass-through: a status no
          // defect in this scope holds returns nothing at all.
          final resolved = await endpoints.defectEndpoints.list(
            sessionBuilder,
            productId: scope.productId,
            status: DefectStatus.resolved.wire,
            limit: 10,
            offset: 0,
          );
          expect(resolved.defects, isEmpty);
          expect(resolved.totalCount, 0);
        });

        test('resolves the product name server-side', () async {
          final expectedName = await registerSuiteProduct(await newDb());
          final created = await endpoints.defectEndpoints.create(
            sessionBuilder,
            productId: _suiteProductId,
            title: 'Named Product',
            description: 'Asserts enrichment',
            severity: 'high',
            intakeCategory: 'bug',
            reporter: 'naming@example.com',
          );

          // Listed unfiltered on purpose: the `productId` filter resolves
          // through the *affected* work item, not the defect's own column, so
          // it cannot select a defect that only carries a product reference.
          // This file owns the `DEF-<digits>` id space, so an unfiltered read
          // returns this suite's rows and nothing else.
          final listed = await endpoints.defectEndpoints.list(
            sessionBuilder,
            limit: 50,
            offset: 0,
          );
          final row = listed.defects.firstWhere(
            (d) => d.defectId == created.defectId,
          );
          expect(row.productName, expectedName);

          final inspected = await endpoints.defectEndpoints.inspect(
            sessionBuilder,
            defectId: created.defectId,
          );
          expect(inspected.defect.productName, expectedName);
        });

        test('paginates with limit and offset', () async {
          for (var i = 0; i < 5; i++) {
            await endpoints.defectEndpoints.create(
              sessionBuilder,
              productId: _suiteProductId,
              title: 'Defect $i',
              description: 'Desc $i',
              severity: 'low',
              intakeCategory: 'bug',
              reporter: 'test@example.com',
            );
          }

          final page1 = await endpoints.defectEndpoints.list(
            sessionBuilder,
            limit: 2,
            offset: 0,
          );
          final page2 = await endpoints.defectEndpoints.list(
            sessionBuilder,
            limit: 2,
            offset: 2,
          );
          expect(page1.defects, hasLength(2));
          expect(page2.defects, hasLength(2));
          final ids1 = page1.defects.map((d) => d.defectId).toSet();
          final ids2 = page2.defects.map((d) => d.defectId).toSet();
          expect(ids1.intersection(ids2), isEmpty);
        });
      });

      group('inspect defect', () {
        test(
          'returns full defect with evidence, events, clarifications',
          () async {
            final createResult = await endpoints.defectEndpoints.create(
              sessionBuilder,
              productId: _suiteProductId,
              title: 'Inspect Test',
              description: 'Full inspect',
              severity: 'critical',
              intakeCategory: 'bug',
              reporter: 'inspect@example.com',
            );

            await endpoints.defectEndpoints.addEvidence(
              sessionBuilder,
              defectId: createResult.defectId,
              kind: EvidenceIntakeKind.screenshot.wire,
              description: 'Screenshot',
              artifactId: 'art-1',
              contentHash: 'hash-1',
              sourceRef: 'ref-1',
            );

            await endpoints.defectEndpoints.requestClarification(
              sessionBuilder,
              defectId: createResult.defectId,
              question: 'What version?',
              reason: 'Need to know',
              triageJobId: 'triage-1',
            );

            final inspectResult = await endpoints.defectEndpoints.inspect(
              sessionBuilder,
              defectId: createResult.defectId,
            );

            expect(inspectResult.defect.defectId, createResult.defectId);
            expect(inspectResult.defect.title, 'Inspect Test');
            // 2 evidence: auto-created human report + added screenshot
            expect(inspectResult.evidence, hasLength(2));
            final evidenceKinds = inspectResult.evidence
                .map((e) => e.kind)
                .toSet();
            expect(evidenceKinds, contains(EvidenceIntakeKind.screenshot.wire));
            expect(inspectResult.clarifications, hasLength(1));
            expect(
              inspectResult.clarifications.single.question,
              'What version?',
            );
            expect(
              inspectResult.clarifications.single.status,
              ClarificationStatus.needsAnswer.wire,
            );
            // 3 events: created, evidence_added, clarification_requested
            expect(inspectResult.events, hasLength(3));
          },
        );
      });

      group('evidence metadata', () {
        test('adds evidence with full metadata', () async {
          final createResult = await endpoints.defectEndpoints.create(
            sessionBuilder,
            productId: _suiteProductId,
            title: 'Evidence Test',
            description: 'Test evidence',
            severity: 'high',
            intakeCategory: 'bug',
            reporter: 'test@example.com',
          );

          final addResult = await endpoints.defectEndpoints.addEvidence(
            sessionBuilder,
            defectId: createResult.defectId,
            kind: EvidenceIntakeKind.screenshot.wire,
            description: 'UI screenshot',
            artifactId: 'art-42',
            contentHash: 'sha256-deadbeef',
            sourceRef: 'penpot:frame-123',
          );

          expect(addResult.evidenceId, isNotEmpty);
          expect(addResult.defectId, createResult.defectId);
          expect(addResult.kind, EvidenceIntakeKind.screenshot.wire);
          expect(addResult.artifactId, 'art-42');
          expect(addResult.contentHash, 'sha256-deadbeef');
          expect(addResult.sourceRef, 'penpot:frame-123');
        });
      });

      group('clarification request/answer', () {
        test('requests and answers clarification', () async {
          final createResult = await endpoints.defectEndpoints.create(
            sessionBuilder,
            productId: _suiteProductId,
            title: 'Clarification Test',
            description: 'Test clarification',
            severity: 'medium',
            intakeCategory: 'bug',
            reporter: 'test@example.com',
          );

          final requestResult = await endpoints.defectEndpoints
              .requestClarification(
                sessionBuilder,
                defectId: createResult.defectId,
                question: 'What is the expected behavior?',
                reason: 'Cannot reproduce',
                triageJobId: 'triage-42',
              );

          expect(requestResult.clarificationId, isNotEmpty);
          expect(requestResult.status, ClarificationStatus.needsAnswer.wire);
          expect(requestResult.requestedByTriageJobId, 'triage-42');

          final answerResult = await endpoints.defectEndpoints
              .answerClarification(
                sessionBuilder,
                clarificationId: requestResult.clarificationId,
                answer: 'Expected X but got Y',
                answeredBy: 'human@example.com',
              );

          expect(answerResult.status, ClarificationStatus.answered.wire);
          expect(answerResult.answer, 'Expected X but got Y');
          expect(answerResult.answeredAt, isNotNull);
        });
      });

      group('fix verification', () {
        test('verifies fix with HumanDecision (approve)', () async {
          final createResult = await endpoints.defectEndpoints.create(
            sessionBuilder,
            productId: _suiteProductId,
            title: 'Verification Test',
            description: 'Test fix verification',
            severity: 'high',
            intakeCategory: 'bug',
            reporter: 'test@example.com',
          );

          final verifyResult = await endpoints.defectEndpoints.verifyFix(
            sessionBuilder,
            defectId: createResult.defectId,
            choice: HumanDecisionChoice.approve.wire,
            rationale: 'Fix works',
            decider: 'approver@example.com',
            signature: 'sig-123',
            publicKey: 'pub-key',
            algorithm: 'Ed25519',
            signedAt: DateTime.now(),
          );

          expect(verifyResult.success, isTrue);
          expect(verifyResult.newStatus, DefectStatus.resolved.wire);
        });

        test('rejects fix with reject choice', () async {
          final createResult = await endpoints.defectEndpoints.create(
            sessionBuilder,
            productId: _suiteProductId,
            title: 'Reject Test',
            description: 'Test reject',
            severity: 'high',
            intakeCategory: 'bug',
            reporter: 'test@example.com',
          );

          final verifyResult = await endpoints.defectEndpoints.verifyFix(
            sessionBuilder,
            defectId: createResult.defectId,
            choice: HumanDecisionChoice.reject.wire,
            rationale: 'Still broken',
            decider: 'approver@example.com',
            signature: 'sig-456',
            publicKey: 'pub-key',
            algorithm: 'Ed25519',
            signedAt: DateTime.now(),
          );

          expect(verifyResult.success, isTrue);
          expect(verifyResult.newStatus, DefectStatus.reported.wire);
        });
      });

      group('event history', () {
        test('records all lifecycle events in order', () async {
          final createResult = await endpoints.defectEndpoints.create(
            sessionBuilder,
            productId: _suiteProductId,
            title: 'Event History',
            description: 'Test events',
            severity: 'low',
            intakeCategory: 'bug',
            reporter: 'test@example.com',
          );

          await endpoints.defectEndpoints.addEvidence(
            sessionBuilder,
            defectId: createResult.defectId,
            kind: EvidenceIntakeKind.textDescription.wire,
            description: 'Evidence 1',
          );

          await endpoints.defectEndpoints.requestClarification(
            sessionBuilder,
            defectId: createResult.defectId,
            question: 'Q?',
            reason: 'R',
            triageJobId: 'tj-1',
          );

          await endpoints.defectEndpoints.answerClarification(
            sessionBuilder,
            clarificationId:
                (await endpoints.defectEndpoints.requestClarification(
                  sessionBuilder,
                  defectId: createResult.defectId,
                  question: 'Q2?',
                  reason: 'R2',
                  triageJobId: 'tj-2',
                )).clarificationId,
            answer: 'A2',
            answeredBy: 'human@example.com',
          );

          await endpoints.defectEndpoints.verifyFix(
            sessionBuilder,
            defectId: createResult.defectId,
            choice: HumanDecisionChoice.approve.wire,
            rationale: 'OK',
            decider: 'decider',
            signature: 'sig',
            publicKey: 'key',
            algorithm: 'Ed25519',
            signedAt: DateTime.now(),
          );

          final inspectResult = await endpoints.defectEndpoints.inspect(
            sessionBuilder,
            defectId: createResult.defectId,
          );

          final events = inspectResult.events as List;
          final types = events.map((e) => e.type).toList();
          expect(
            types,
            containsAll([
              DefectEventType.created.wire,
              DefectEventType.evidenceAdded.wire,
              DefectEventType.clarificationRequested.wire,
              DefectEventType.clarificationAnswered.wire,
              DefectEventType.verificationCompleted.wire,
            ]),
          );
        });
      });

      group('restart durability', () {
        test('defect state survives server restart', () async {
          // Scoped to this suite: see `_DefectReadScope`. The unfiltered list
          // would also return the triage suite's `DEF-triage-r<n>` defects,
          // which share this database.
          final scope = await _createDefectReadScope(
            await newDb(),
            label: 'restart',
            counter: scopeCounter++,
          );
          addTearDown(scope.dispose);

          // First server instance creates defect
          late String createdDefectId;
          {
            final createResult = await endpoints.defectEndpoints.create(
              sessionBuilder,
              productId: _suiteProductId,
              title: 'Durability Test',
              description: 'Survives restart',
              severity: 'high',
              intakeCategory: 'bug',
              affectedWorkItemId: scope.affectedWorkItemId,
              reporter: 'test@example.com',
            );
            createdDefectId = createResult.defectId;

            await endpoints.defectEndpoints.addEvidence(
              sessionBuilder,
              defectId: createdDefectId,
              kind: EvidenceIntakeKind.logExcerpt.wire,
              description: 'Persistent log',
              artifactId: 'art-persist',
              contentHash: 'hash-persist',
            );
          }

          // Second server instance (new endpoints) reads it back
          {
            final listResult = await endpoints.defectEndpoints.list(
              sessionBuilder,
              productId: scope.productId,
              limit: 10,
              offset: 0,
            );
            expect(listResult.defects, hasLength(1));
            expect(listResult.totalCount, 1);

            final defect = listResult.defects[0];
            expect(defect.defectId, createdDefectId);
            expect(defect.title, 'Durability Test');
            expect(defect.status, DefectStatus.reported.wire);

            final inspectResult = await endpoints.defectEndpoints.inspect(
              sessionBuilder,
              defectId: defect.defectId,
            );
            // 2 evidence: auto-created human report + added log
            expect(inspectResult.evidence, hasLength(2));
            final artifacts = inspectResult.evidence
                .map((e) => e.artifactId)
                .toSet();
            expect(artifacts, contains('art-persist'));
            // 2 events: created (includes human report), evidence_added (log)
            expect(inspectResult.events, hasLength(2));
          }
        });
      });

      group('Product scoping via affectedWorkItemId', () {
        test('defects can be filtered by affectedWorkItemId', () async {
          // Scoped to this suite: see `_DefectReadScope`. `allDefects` used to
          // be an unfiltered `list(limit: 10)`, so it also carried the triage
          // suite's `DEF-triage-r<n>` defects and `hasLength(2)` was a race
          // against that suite.
          final scope = await _createDefectReadScope(
            await newDb(),
            label: 'product-scope',
            counter: scopeCounter++,
          );
          addTearDown(scope.dispose);

          // Two anchor work items inside the one suite-owned product, so the
          // per-work-item split below is still exercised on top of the
          // product scope.
          final engine = DurableWorkflowEngine(
            store: PostgresWorkflowStore(scope.db),
          );
          final workItemIds = <String, String>{};
          for (final key in ['wi-prod-a', 'wi-prod-b']) {
            final workItemId = 'lane-f-scope-$key-${scope.productId.hashCode}';
            scope.extraWorkItemIds.add(workItemId);
            await engine.createWorkItem(
              workItemId: workItemId,
              productId: scope.productId,
              category: WorkItemCategory.chore,
              title: 'Anchor for $key (defect backend read scope)',
              description:
                  'Suite-owned anchor work item linking a defect to this '
                  'product so the per-work-item filtering is observable.',
            );
            workItemIds[key] = workItemId;
          }

          await endpoints.defectEndpoints.create(
            sessionBuilder,
            productId: _suiteProductId,
            title: 'Product A Defect',
            description: 'For product A',
            severity: 'high',
            intakeCategory: 'bug',
            affectedWorkItemId: workItemIds['wi-prod-a'],
            reporter: 'test@example.com',
          );

          await endpoints.defectEndpoints.create(
            sessionBuilder,
            productId: _suiteProductId,
            title: 'Product B Defect',
            description: 'For product B',
            severity: 'high',
            intakeCategory: 'bug',
            affectedWorkItemId: workItemIds['wi-prod-b'],
            reporter: 'test@example.com',
          );

          final allDefects = await endpoints.defectEndpoints.list(
            sessionBuilder,
            productId: scope.productId,
            limit: 10,
            offset: 0,
          );
          expect(allDefects.defects, hasLength(2));
          expect(allDefects.totalCount, 2);

          // Manual filter by affectedWorkItemId (the product endpoint has no
          // affectedWorkItemId filter).
          final aDefects = allDefects.defects
              .where((d) => d.affectedWorkItemId == workItemIds['wi-prod-a'])
              .toList();
          final bDefects = allDefects.defects
              .where((d) => d.affectedWorkItemId == workItemIds['wi-prod-b'])
              .toList();
          expect(aDefects, hasLength(1));
          expect(bDefects, hasLength(1));
          expect(aDefects.single.title, 'Product A Defect');
          expect(bDefects.single.title, 'Product B Defect');
        });
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}
