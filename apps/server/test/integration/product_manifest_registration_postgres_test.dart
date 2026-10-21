import 'dart:convert';
import 'dart:io';

import 'package:control_plane_server/src/endpoints/product_registry_endpoints.dart';
import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_product_qa_contract_spec_store.dart';
import 'package:control_plane_server/src/persistence/postgres_qa_contract_store.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// REAL PostgreSQL proof that the checked-in `shipit-platform` declaration
/// reaches the `product_qa_contract_spec` table through the product's OWN
/// write path.
///
/// ## WHY THIS NEEDS A DATABASE
///
/// The declaration file, the manifest codec and the gate contents are all
/// provable without one (`test/product_manifest_declaration_test.dart`). What
/// they cannot prove is the half that has never once held on this platform:
/// that a manifest supplied at an ENDPOINT arrives in a table a LATER READ can
/// find. `ProductManifest.contracts.qaContract` was constructed empty at its
/// one production site and then dropped by `saveProduct`, which wrote eight
/// columns and none of them `contracts` — so the type was reachable and its
/// value unreachable, for the whole life of the platform. A codec test proves
/// the two halves of a mapping agree; only this proves the WRITE landed.
///
/// So the subject of this file is the ROUND TRIP, and the file the operator
/// will register is the input to it. That is deliberate: if the declaration and
/// the write path ever disagree, the thing that is tested is the thing that will
/// be run.
///
/// ## WHAT IS DELIBERATELY NOT ASSERTED HERE
///
/// That the three work items stranded in `agentExecuting` complete, or that
/// their `qaContractId` becomes non-null. Nothing here moves a work item:
/// `ProductRegistryEndpoints.createProduct` writes the `product` row and the
/// `product_qa_contract_spec` row and nothing else. Whether a given item is
/// then backfilled is a property of the lane that owns that item
/// (`DesignRemediationWorkItemProvisioner._attachQAContract` for
/// `design-remediation-*`; and `createFeatureWorkItem` has no equivalent, which
/// is why a `WI-feature-*` item is not repairable by this route at all).
///
/// Nor is the PRODUCT ROW's behaviour on re-registration asserted here, and
/// the reason has changed. It used to say that
/// `PostgresProductRegistryStore.saveProduct` is an unconditional `ON CONFLICT
/// DO UPDATE` that rewrites `state`, `createdAt` and `description`, and that
/// pinning that here would bless it as intended behaviour — so it was
/// reported to the Manager as a blocker on registering an EXISTING product.
///
/// It is fixed (human decision `6e83b1c7-4d92-4a06-bf58-3c7a9e0d24f6`):
/// `ControlPlaneService.registerProductWithManifest` MERGES an existing
/// product instead of re-creating it, and the store's null-`expectedVersion`
/// branch is insert-only. The merge is held, without a database, by
/// `test/product_reregistration_merge_test.dart`, which asserts all four
/// preserved columns and a zero product-write count. This file still does not
/// cover re-registration, because its subject is the DECLARATION round trip
/// against a real database and it registers a NEW product under a fixture id;
/// the merge's behaviour against real Postgres bytes is the Manager's runtime
/// verification, not this file's.
///
/// ## RESOURCE HYGIENE
///
/// Every row this file writes is under the `qa-manifest-it-` prefix and is
/// deleted in both `setUp` and `tearDown`, scoped by that prefix rather than by
/// TRUNCATE — `test/integration` shares one database with files that run
/// concurrently, and truncating `product` or `qa_contract` out from under them
/// breaks their assertions. This file creates NO compose project, NO container
/// and NO schema, so it has no teardown beyond its own rows.
const _prefix = 'qa-manifest-it-';
const _fixtureProductId = '${_prefix}shipit-platform';

final List<Session> _openSessions = <Session>[];

Future<Session> _newSession() async {
  final session = await Serverpod.instance.createSession(enableLogging: false);
  _openSessions.add(session);
  return session;
}

Future<void> _closeSessions() async {
  for (final session in List.of(_openSessions)) {
    await session.close();
  }
  _openSessions.clear();
}

Future<void> _purgeSuiteRows() async {
  final session = await _newSession();
  final db = PersistenceDatabase(session.db);
  // Ordered so a row this file's endpoint wrote is never removed while a row
  // referencing it survives. Stated rather than assumed: a later migration that
  // adds a foreign key onto one of these makes a wrong order fail as a
  // constraint violation naming this file, not as a flaky assertion elsewhere.
  for (final statement in const <String>[
    'DELETE FROM "product_qa_contract_spec" WHERE "productId" LIKE '
        '\'$_prefix%\'',
    'DELETE FROM "product_registry_audit" WHERE "productId" LIKE '
        '\'$_prefix%\'',
    'DELETE FROM "repository_reference" WHERE "productId" LIKE '
        '\'$_prefix%\'',
    'DELETE FROM "onboarding_record" WHERE "productId" LIKE \'$_prefix%\'',
    'DELETE FROM "baseline_fact" WHERE "baselineId" IN '
        '(SELECT "baselineId" FROM "product_baseline" WHERE "productId" LIKE '
        '\'$_prefix%\')',
    'DELETE FROM "product_baseline" WHERE "productId" LIKE \'$_prefix%\'',
    'DELETE FROM "human_decision" WHERE "workItemId" LIKE \'\$_prefix%\'',
    'DELETE FROM "product" WHERE "productId" LIKE \'$_prefix%\'',
  ]) {
    await db.query(statement);
  }
}

/// The declaration file as it sits in the repository, read as bytes.
///
/// Read from disk rather than inlined, so the thing under test is the artefact
/// an operator will actually register. A copy in this file would pass every
/// assertion here while the registered file said something else.
String _manifestJson() {
  final repoRoot = _findRepoRoot();
  return File(
    '$repoRoot${Platform.pathSeparator}apps${Platform.pathSeparator}'
    'server${Platform.pathSeparator}manifests${Platform.pathSeparator}'
    'shipit-platform.product-manifest.json',
  ).readAsStringSync();
}

String _findRepoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (Directory(
          '${dir.path}${Platform.pathSeparator}packages',
        ).existsSync() &&
        Directory('${dir.path}${Platform.pathSeparator}apps').existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('repository root not found from ${Directory.current}');
    }
    dir = parent;
  }
}

void main() {
  withServerpod(
    'The shipit-platform QA declaration reaches product_qa_contract_spec '
    'through the product\'s own endpoint',
    (sessionBuilder, endpoints) {
      setUp(_purgeSuiteRows);
      tearDown(() async {
        await _purgeSuiteRows();
        await _closeSessions();
      });
      _registrationTests();
    },
  );
}

void _registrationTests() {
  test(
    'the endpoint persists the declared QA contract, and a later read finds it',
    () async {
      final session = await _newSession();

      // THE PRODUCTION CALL. Not the service method, not a store, not SQL: the
      // same `ProductRegistryEndpoints.createProduct` a client reaches at
      // `POST /productRegistryEndpoints.createProduct`, with the same
      // `manifestJson`-as-a-STRING parameter the wire carries.
      await ProductRegistryEndpoints().createProduct(
        session,
        productId: _fixtureProductId,
        name: 'ShipIt Platform',
        description: 'integration fixture',
        manifestJson: _manifestJson(),
        manifestVersion: '1.0.0',
      );

      // THE LATER READ. Through the store a provisioner reads, so this proves
      // the row is reachable by the code that needs it rather than merely
      // present.
      final declaration = await PostgresProductQAContractSpecStore(
        PersistenceDatabase(session.db),
      ).readQAContractSpec(_fixtureProductId);

      expect(
        declaration,
        isNotNull,
        reason:
            'no product_qa_contract_spec row for $_fixtureProductId. This is '
            'the failure the whole declaration route exists to prevent: the '
            'manifest was supplied, so the absence of this row means it was '
            'discarded on write rather than that the product declared nothing.',
      );
      expect(declaration!.declaresQAContract, isTrue);
      expect(declaration.manifestVersion, '1.0.0');

      // M1 raised the shipped declaration from one gate to five, so the row
      // must carry all five. The `single` that stood here passed at base —
      // the base manifest declares exactly one gate — and failed only at M1,
      // which is why it is resolved by id now: the intake gate must be PRESENT
      // among five (a missing one throws StateError), never the only one.
      expect(declaration.gates, hasLength(5));
      expect(
        declaration.gates.map((g) => g.gateId).toSet(),
        <String>{
          'intake-structured-result-admitted',
          'feature-change-committed',
          'feature-change-scope-confined',
          'feature-declared-checks-executed',
          'feature-review-bound-to-revision',
        },
        reason:
            'the persisted row must name exactly the five gate ids the shipped '
            'manifest declares — a subset means a gate was dropped on write, '
            'a superset means one was invented there',
      );
      final gate = declaration.gates.firstWhere(
        (g) => g.gateId == 'intake-structured-result-admitted',
      );
      expect(gate.gateId, 'intake-structured-result-admitted');
      expect(gate.type, 'triage-classification-structure');
      expect(gate.required, isTrue);
      expect(gate.config['sourceColumn'], 'agent_result.structuredResultJson');
      expect(gate.config['requiredFields'], <String>[
        'classification',
        'status',
        'confidence',
        'suspectedCategory',
      ]);
    },
  );

  test(
    'the persisted row is what the provisioner turns into a work item\'s '
    'contract',
    () async {
      final session = await _newSession();
      await ProductRegistryEndpoints().createProduct(
        session,
        productId: _fixtureProductId,
        name: 'ShipIt Platform',
        description: 'integration fixture',
        manifestJson: _manifestJson(),
        manifestVersion: '1.0.0',
      );

      final db = PersistenceDatabase(session.db);
      final declaration = await PostgresProductQAContractSpecStore(
        db,
      ).readQAContractSpec(_fixtureProductId);
      expect(declaration, isNotNull);

      // The end of the route, on a REAL database: read the declaration back and
      // provision from it, which is the operation that turns a missing
      // declaration into `ProductQAContractSpecRefusal.notDeclared` and a
      // present one into a contract id a work item can carry. Without this the
      // test would stop at "a row exists", which is not the property anything
      // downstream depends on.
      final contract =
          await ProductQAContractProvisioner(
            contractStore: PostgresQAContractStore(db),
            specStore: PostgresProductQAContractSpecStore(db),
          ).provisionForWorkItem(
            productId: _fixtureProductId,
            workItemCategory: WorkItemCategory.feature,
            workItemId: '${_prefix}WI-1',
            now: DateTime.utc(2026, 10, 17),
          );

      expect(contract.contractId, 'qa-product-${_prefix}WI-1');
      final intake = contract.gates.firstWhere(
        (g) => g.gateId == 'intake-structured-result-admitted',
      );
      expect(intake.type, 'triage-classification-structure');
      expect(contract.metadata?['productId'], _fixtureProductId);
      expect(contract.metadata?['manifestVersion'], '1.0.0');
      // Stated rather than implied: nothing evaluates this gate type yet, so a
      // passing evaluation here would be a fiction.
      expect(contract.metadata?['evaluatorRuntime'], 'absent');
      // M1: reviewed evaluators registered; runtime drain (3c) still absent.
      expect(gateRegistry.get(intake.type), isNotNull);
    },
  );

  test(
    'a manifest with NO gates writes NO row, and the product is still created',
    () async {
      // The refusal cases are named by the code rather than left to inference:
      // `manifest: null` is `notDeclared` and `gates: []` is `declaresNoGates`,
      // and both are logged as `product_registry.qa_contract_spec.not_declared`
      // at the point the omission is recorded. Asserting them here is what
      // keeps `intake-structured-result-admitted` from being silently replaced
      // by an empty list later — the replacement would still write nothing, but
      // it would also stop looking like a decision.
      final session = await _newSession();
      final db = PersistenceDatabase(session.db);
      final specStore = PostgresProductQAContractSpecStore(db);

      final empty = jsonDecode(_manifestJson()) as Map<String, dynamic>;
      final contracts = empty['contracts'] as Map<String, dynamic>;
      (contracts['qaContract'] as Map<String, dynamic>)['gates'] = <Object>[];

      await ProductRegistryEndpoints().createProduct(
        session,
        productId: _fixtureProductId,
        name: 'ShipIt Platform',
        description: 'integration fixture',
        manifestJson: jsonEncode(empty),
        manifestVersion: '1.0.0',
      );

      expect(
        await specStore.readQAContractSpec(_fixtureProductId),
        isNull,
        reason:
            'a manifest declaring no gates is the ABSENCE of a declaration and '
            'must not persist a row — a row built from it would satisfy '
            "context['qaContractId'] != null while constraining nothing",
      );
      // The product is still registered: a human who filed a request about it is
      // not refused for the platform's sake (human decision 58bad3d1).
      final summaries = await ProductRegistryEndpoints().listProductSummaries(
        session,
      );
      expect(
        summaries.where((s) => s.productId == _fixtureProductId),
        isNotEmpty,
        reason:
            'the product IS registered even though its QA contract was not '
            'declared — human decision 58bad3d1 forbids the platform\'s own '
            'missing configuration becoming a veto over a human\'s request',
      );
    },
  );
}
