import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/triage/lane_a_defect_triage_work_item.dart'
    show defectTriageWorkItemId;
import 'package:control_plane_server/src/triage/lane_e_design_remediation_work_item.dart'
    show designRemediationWorkItemId;
import 'package:control_plane_server/src/persistence/postgres_product_qa_contract_spec_store.dart';
import 'package:control_plane_server/src/persistence/postgres_qa_contract_store.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// REAL PostgreSQL proof of the two properties the per-product QA-contract route
/// depends on, neither of which an in-memory store can demonstrate.
///
/// ## WHY A REAL DATABASE, AND NOT THE IN-MEMORY TIER
///
///   * `saveQAContract` is `ON CONFLICT ("contractId") DO UPDATE`. The whole
///     reason `productQAContractIdForWorkItem` is work-item-scoped is that a
///     `contractId` is the primary key of a row a second write REPLACES. A map
///     that assigns by key reproduces that, but only by coincidence; a map that
///     appends would pass every assertion while the production statement
///     silently repoints the triage parent's `metadata.workItemId`. Only the
///     real statement exhibits the damage.
///   * The declaration's round trip is the property that has NEVER held on this
///     data. `ProductManifest.contracts.qaContract` was constructed empty at one
///     site and then discarded by `saveProduct`, which wrote eight columns and
///     none of them `contracts`. A codec test proves the two halves of the
///     mapping agree; only this proves the WRITE reached a table a later READ
///     can find.
///
/// ## WHAT IS DELIBERATELY NOT ASSERTED HERE
///
/// That the three items stranded in `agentExecuting` complete. They will not,
/// and cannot, without a human operator transition: `agentExecuting` has exactly
/// two outgoing edges (`agentCompleted`, which the guard refuses without a
/// contract, and `agentFailed`), and no path replays a refused completion. This
/// change makes the recovery POSSIBLE by making the contract exist; it does not
/// perform it, and a test that implied otherwise would be asserting a
/// transition the graph does not contain.
///
/// ## RESOURCE HYGIENE
///
/// Every row this file writes is prefixed `qa-spec-it-` and deleted in both
/// `setUp` and `tearDown`, scoped by that prefix rather than by TRUNCATE —
/// `test/integration` shares one database with files that run concurrently, and
/// truncating `qa_contract` out from under them breaks their assertions. This
/// file creates NO compose project, NO container and NO schema, so it has no
/// teardown beyond its own rows.
const _productPrefix = 'qa-spec-it-';

const _declaringProduct = '${_productPrefix}declares';
const _undeclaredProduct = '${_productPrefix}undeclared';
const _emptyProduct = '${_productPrefix}empty';

const _workItemId = '${_productPrefix}WI-1';
const _otherWorkItemId = '${_productPrefix}WI-2';

final List<Session> _openSessions = <Session>[];

Future<PersistenceDatabase> _newDb() async {
  final session = await Serverpod.instance.createSession(enableLogging: false);
  _openSessions.add(session);
  return PersistenceDatabase(session.db);
}

Future<void> _closeSessions() async {
  for (final session in List.of(_openSessions)) {
    await session.close();
  }
  _openSessions.clear();
}

Future<void> _purgeSuiteRows() async {
  final db = await _newDb();
  // `work_item` first: nothing here declares a foreign key to it, but the
  // order is stated rather than assumed so a later schema change that DOES
  // declare one fails as a constraint violation naming this file, not as a
  // flaky assertion somewhere else.
  for (final statement in const <String>[
    'DELETE FROM "product_qa_contract_spec" WHERE "productId" LIKE '
        '\'$_productPrefix%\'',
    'DELETE FROM "qa_contract" WHERE "contractId" LIKE \'$_productPrefix%\'',
  ]) {
    await db.query(statement);
  }
}

/// A declaration of two gates, one required and one not, with a nested config
/// value so a lossy JSON round trip is visible rather than invisible.
ProductQAContractDeclaration _declaration(String productId, {int version = 1}) {
  final at = DateTime.utc(2026, 10, 17, 9, 30, 0);
  return ProductQAContractDeclaration(
    productId: productId,
    gates: const [
      QAGateSpec(
        gateId: 'build-passes',
        type: 'static-analysis',
        required: true,
        config: {
          'tool': 'dart analyze',
          'evidenceTypes': ['analysis-report'],
          'nested': {'depth': 2},
        },
      ),
      QAGateSpec(
        gateId: 'smoke',
        type: 'smoke-test',
        required: false,
        config: <String, dynamic>{},
      ),
    ],
    manifestVersion: 'v$version',
    createdAt: at,
    updatedAt: at,
    version: version,
  );
}

Future<int> _contractRowCount(
  PersistenceDatabase db,
  String contractId,
) async {
  final rows = await db.query(
    'SELECT count(*)::int AS "n" FROM "qa_contract" WHERE "contractId" = @id',
    parameters: QueryParameters.named({'id': contractId}),
  );
  return (rows.first.toColumnMap()['n'] as num).toInt();
}

Future<Map<String, String>> _rawRow(
  PersistenceDatabase db,
  String contractId,
) async {
  final rows = await db.query(
    'SELECT "contractId", "gatesJson", "metadataJson", "version", '
    '"workItemCategory" FROM "qa_contract" WHERE "contractId" = @id',
    parameters: QueryParameters.named({'id': contractId}),
  );
  if (rows.isEmpty) return const {};
  final m = rows.first.toColumnMap();
  return {
    'gatesJson': '${m['gatesJson']}',
    'metadataJson': '${m['metadataJson']}',
    'version': '${m['version']}',
    'workItemCategory': '${m['workItemCategory']}',
  };
}

void main() {
  withServerpod(
    'Postgres carries a product DECLARED QA contract, and a product-scoped '
    'contract id cannot overwrite a triage one',
    (sessionBuilder, endpoints) {
      setUp(_purgeSuiteRows);
      tearDown(() async {
        await _purgeSuiteRows();
        await _closeSessions();
      });

      test(
        'AC-1 a declared QA contract survives save to load',
        () async {
          final db = await _newDb();
          final store = PostgresProductQAContractSpecStore(db);
          final original = _declaration(_declaringProduct);

          await store.saveQAContractSpec(original);
          final loaded = await store.readQAContractSpec(_declaringProduct);

          // THE ROUND TRIP, and not the write. The write alone is exactly what
          // the old code did successfully while throwing the declaration away,
          // so asserting only that would pass against the defect this whole
          // lane exists to close.
          expect(loaded, isNotNull);
          expect(loaded, original);
          expect(loaded!.gates.map((g) => g.gateId), ['build-passes', 'smoke']);
          expect(loaded.gates.first.required, isTrue);
          expect(loaded.gates.last.required, isFalse);
          expect(loaded.gates.first.config['nested'], {'depth': 2});
          expect(
            loaded.gates.first.config['evidenceTypes'],
            ['analysis-report'],
          );
          expect(loaded.manifestVersion, 'v1');
          expect(loaded.declaresQAContract, isTrue);
        },
      );

      test(
        'AC-1 re-declaring converges on ONE row and updates the gates',
        () async {
          final db = await _newDb();
          final store = PostgresProductQAContractSpecStore(db);

          await store.saveQAContractSpec(_declaration(_declaringProduct));
          await store.saveQAContractSpec(
            _declaration(_declaringProduct, version: 2),
          );

          final rows = await db.query(
            'SELECT count(*)::int AS "n" FROM "product_qa_contract_spec" '
            'WHERE "productId" = @p',
            parameters: QueryParameters.named({'p': _declaringProduct}),
          );
          expect((rows.first.toColumnMap()['n'] as num).toInt(), 1);

          final loaded = await store.readQAContractSpec(_declaringProduct);
          expect(loaded!.manifestVersion, 'v2');
          expect(
            loaded.createdAt,
            _declaration(_declaringProduct).createdAt,
            reason:
                'createdAt records when the product FIRST declared this, '
                'so a reader can tell how long from how recently',
          );
        },
      );

      test(
        'AC-2 the provisioner writes a resolvable contract for a work item',
        () async {
          final db = await _newDb();
          final specs = PostgresProductQAContractSpecStore(db);
          final contracts = PostgresQAContractStore(db);
          await specs.saveQAContractSpec(_declaration(_declaringProduct));
          final provisioner = ProductQAContractProvisioner(
            contractStore: contracts,
            specStore: specs,
          );

          final contract = await provisioner.provisionForWorkItem(
            productId: _declaringProduct,
            workItemCategory: WorkItemCategory.feature,
            workItemId: _workItemId,
          );

          expect(
            contract.contractId,
            productQAContractIdForWorkItem(_workItemId),
          );
          expect(await contracts.hasQAContract(contract.contractId), isTrue);
          expect(contract.gates.map((g) => g.gateId), [
            'build-passes',
            'smoke',
          ]);
          expect(
            contract.metadata?[qaContractProductIdMetadataKey],
            _declaringProduct,
          );
        },
      );

      test(
        'AC-2 two provisioner calls for ONE work item leave exactly ONE '
        'contract row',
        () async {
          final db = await _newDb();
          final specs = PostgresProductQAContractSpecStore(db);
          final contracts = PostgresQAContractStore(db);
          await specs.saveQAContractSpec(_declaration(_declaringProduct));
          final provisioner = ProductQAContractProvisioner(
            contractStore: contracts,
            specStore: specs,
          );

          Future<QAContract> provision(String workItemId) =>
              provisioner.provisionForWorkItem(
                productId: _declaringProduct,
                workItemCategory: WorkItemCategory.feature,
                workItemId: workItemId,
                // The same instant both times, so the second write is
                // byte-identical and the row cannot look "changed" merely
                // because a test took two passes over it.
                now: DateTime.utc(2026, 10, 17, 9, 30, 0),
              );

          await provision(_workItemId);
          final second = await provision(_workItemId);

          expect(
            await _contractRowCount(
              db,
              productQAContractIdForWorkItem(_workItemId),
            ),
            1,
            reason:
                'THE COUNT. saveQAContract is ON CONFLICT ("contractId") DO '
                'UPDATE, so a second write to the same id converges — and a '
                'work-item-scoped id is what makes "the same id" mean "the '
                'same work item".',
          );
          expect(
            second.contractId,
            productQAContractIdForWorkItem(_workItemId),
          );

          // The control: a DIFFERENT work item is a different row, so the
          // idempotence above is work-item-scoped and not a store that refuses
          // to write twice.
          await provision(_otherWorkItemId);
          final total = await db.query(
            'SELECT count(*)::int AS "n" FROM "qa_contract" '
            'WHERE "contractId" LIKE \'$_productPrefix%\'',
          );
          expect((total.first.toColumnMap()['n'] as num).toInt(), 2);
        },
      );

      test(
        'AC-2/4 lane E cannot touch the triage contract for the same defect',
        () async {
          final db = await _newDb();
          final specs = PostgresProductQAContractSpecStore(db);
          final contracts = PostgresQAContractStore(db);
          await specs.saveQAContractSpec(_declaration(_declaringProduct));

          // One defect, two lanes. `design-remediation-DEF-1` and `defect-DEF-1`
          // name the SAME defect, so a defect-scoped contract id would address
          // the triage parent's own primary key.
          const defectId = '${_productPrefix}DEF-1';
          final triageContractId = triageQAContractIdForDefect(defectId);
          final triageWorkItemId = defectTriageWorkItemId(defectId);
          final remediationWorkItemId = designRemediationWorkItemId(defectId);

          expect(
            triageWorkItemId,
            isNot(remediationWorkItemId),
            reason: 'precondition: the two lanes name different WORK ITEMS',
          );

          await contracts.provisionQAContract(
            buildAdvisoryTriageQAContract(
              defectId: defectId,
              workItemId: triageWorkItemId,
              now: DateTime.utc(2026, 10, 17, 9, 0, 0),
            ),
          );
          final triageBefore = await _rawRow(db, triageContractId);
          expect(triageBefore, isNotEmpty);

          final remediation =
              await ProductQAContractProvisioner(
                contractStore: contracts,
                specStore: specs,
              ).provisionForWorkItem(
                productId: _declaringProduct,
                workItemCategory: WorkItemCategory.feature,
                workItemId: remediationWorkItemId,
                now: DateTime.utc(2026, 10, 17, 9, 30, 0),
              );

          expect(
            remediation.contractId,
            productQAContractIdForWorkItem(remediationWorkItemId),
          );
          expect(remediation.contractId, isNot(triageContractId));

          // THE ASSERTION THAT MATTERS, on the real upsert statement: the
          // parent's row is byte-identical, link included. A defect-scoped id
          // here would have replaced `metadataJson` and repointed
          // `metadata.workItemId` at the remediation item, after which
          // `listQAContractsForWorkItem(triageWorkItemId)` would answer for a
          // contract that is no longer the triage item's.
          expect(await _rawRow(db, triageContractId), triageBefore);
          expect(
            (await contracts.listQAContractsForWorkItem(
              triageWorkItemId,
            )).map((c) => c.contractId),
            [triageContractId],
          );
          expect(
            (await contracts.listQAContractsForWorkItem(
              remediationWorkItemId,
            )).map((c) => c.contractId),
            [remediation.contractId],
          );
        },
      );

      test(
        'AC-4 an undeclared product fails closed with a NAMED reason and NO row',
        () async {
          final db = await _newDb();
          final contracts = PostgresQAContractStore(db);
          final provisioner = ProductQAContractProvisioner(
            contractStore: contracts,
            specStore: PostgresProductQAContractSpecStore(db),
          );

          // NOTHING was written for this product. `readQAContractSpec` is null,
          // which is the honest answer for a product that declared nothing.
          expect(
            await PostgresProductQAContractSpecStore(
              db,
            ).readQAContractSpec(_undeclaredProduct),
            isNull,
          );

          Object? thrown;
          try {
            await provisioner.provisionForWorkItem(
              productId: _undeclaredProduct,
              workItemCategory: WorkItemCategory.feature,
              workItemId: _workItemId,
            );
          } catch (error) {
            thrown = error;
          }

          expect(
            thrown,
            isA<ProductQAContractSpecUnavailable>().having(
              (e) => e.refusal,
              'refusal',
              ProductQAContractSpecRefusal.notDeclared,
            ),
            reason:
                'a THROWN, NAMED refusal — not a null. A null-returning '
                'provisioner has nothing to remove and nothing to report, so '
                '"the product declared nothing" and "the store was never '
                'wired" would produce the same work item and the same silence.',
          );
          expect(
            await _contractRowCount(
              db,
              productQAContractIdForWorkItem(_workItemId),
            ),
            0,
            reason:
                'NON-VACUITY: nothing was written. A contract with zero gates '
                "would satisfy qaContractExists()'s null-check and constrain "
                'nothing, which is the fiction this route exists to remove.',
          );
        },
      );

      test(
        'AC-4 a product whose declaration names NO gates is a DIFFERENT '
        'refusal',
        () async {
          final db = await _newDb();
          final specs = PostgresProductQAContractSpecStore(db);
          final contracts = PostgresQAContractStore(db);
          await specs.saveQAContractSpec(
            ProductQAContractDeclaration(
              productId: _emptyProduct,
              gates: const [],
              manifestVersion: 'v-empty',
              createdAt: DateTime.utc(2026, 10, 17, 9, 0, 0),
              updatedAt: DateTime.utc(2026, 10, 17, 9, 0, 0),
            ),
          );

          Object? thrown;
          try {
            await ProductQAContractProvisioner(
              contractStore: contracts,
              specStore: specs,
            ).provisionForWorkItem(
              productId: _emptyProduct,
              workItemCategory: WorkItemCategory.feature,
              workItemId: _workItemId,
            );
          } catch (error) {
            thrown = error;
          }

          expect(
            thrown,
            isA<ProductQAContractSpecUnavailable>().having(
              (e) => e.refusal,
              'refusal',
              ProductQAContractSpecRefusal.declaresNoGates,
            ),
            reason:
                'two names, not one boolean, because the two need different '
                'remedies: register a contract, versus write gates into the '
                'manifest you already registered',
          );
          expect(
            await _contractRowCount(
              db,
              productQAContractIdForWorkItem(_workItemId),
            ),
            0,
          );
        },
      );

      test(
        'the migration is present in THIS database — otherwise every '
        'assertion above is a shape test against nothing',
        () async {
          final db = await _newDb();
          final rows = await db.query(
            'SELECT column_name FROM information_schema."columns" '
            'WHERE table_name = \'product_qa_contract_spec\' '
            'ORDER BY ordinal_position',
          );
          expect(
            rows.map((r) => r.toColumnMap()['column_name']).toList(),
            [
              'id',
              'productId',
              'gatesJson',
              'manifestVersion',
              'createdAt',
              'updatedAt',
              'version',
            ],
            reason:
                'the table and its exact column order. If this fails the '
                'migration did not reach this database and every other test in '
                'this file is asserting a codec against an absent table.',
          );
        },
      );
    },
  );
}
