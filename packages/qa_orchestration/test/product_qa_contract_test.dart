import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:test/test.dart';

/// Product ids that are obviously not each other, so no assertion can pass
/// because two subjects happened to share a name.
const String kProduct = 'product-that-declares';
const String kOtherProduct = 'a-different-product';

/// A fixed instant, so two provisionings with it are byte-identical writes and
/// a test can assert "one row", not "one row that happens to have moved on".
final DateTime kNow = DateTime.utc(2026, 10, 17, 9, 30, 0);

/// The SAME defect both lanes are given, which is the case that makes the id
/// scoping question real rather than theoretical:
/// `design-remediation-DEF-1` and `defect-DEF-1` name one defect.
const String kDefectId = 'DEF-1';
const String kRemediationWorkItemId = 'design-remediation-DEF-1';
const String kTriageWorkItemId = 'defect-DEF-1';

/// A [QAContractStore] that really stores, keyed the way PostgreSQL is.
///
/// Deliberately not a stub that answers every call with the value it was given:
/// the whole reason contract ids are work-item-scoped is that
/// `saveQAContract` is `ON CONFLICT ("contractId") DO UPDATE` in production,
/// so a second write REPLACES a row. A store that appended would make the
/// collision assertion below vacuous — the very defect it exists to catch would
/// pass on a store that cannot exhibit it.
class InMemoryQAContractStore implements QAContractStore {
  final Map<String, QAContract> _rows = <String, QAContract>{};

  /// How many times each id was WRITTEN, separate from how many rows exist.
  ///
  /// Both numbers are needed and they answer different questions: `rows.length`
  /// says whether a replay duplicated anything, and this says whether a replay
  /// even reached the store or short-circuited somewhere above it.
  final Map<String, int> writeCounts = <String, int>{};

  /// Every write, in order, so a test can prove one lane's write did not land
  /// on another's id.
  final List<String> writeOrder = <String>[];

  int get rowCount => _rows.length;

  @override
  Future<void> saveQAContract(QAContract contract) async {
    writeCounts.update(
      contract.contractId,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    writeOrder.add(contract.contractId);
    // ON CONFLICT ("contractId") DO UPDATE — the production semantics.
    _rows[contract.contractId] = contract;
  }

  @override
  Future<QAContract> provisionQAContract(QAContract contract) async {
    await saveQAContract(contract);
    final stored = await readQAContract(contract.contractId);
    if (stored == null) {
      throw StateError('${contract.contractId} was written but not readable');
    }
    return stored;
  }

  @override
  Future<QAContract?> readQAContract(String contractId) async =>
      _rows[contractId];

  @override
  Future<bool> hasQAContract(String contractId) async =>
      _rows.containsKey(contractId);

  @override
  Future<List<QAContract>> listQAContractsForWorkItem(
    String workItemId,
  ) async => _rows.values
      .where((c) => c.metadata?[qaContractWorkItemIdMetadataKey] == workItemId)
      .toList();

  @override
  Future<List<QAContract>> listQAContractsByCategory(
    WorkItemCategory category,
  ) async => _rows.values
      .where((c) => c.workItemCategory == category)
      .toList(growable: false);
}

/// A [ProductQAContractSpecStore] over a plain map, with the same "it really
/// stores" discipline as the contract store above: a read returns what a write
/// put there, and a product that never wrote returns null rather than a
/// fabricated declaration.
class InMemoryProductQAContractSpecStore implements ProductQAContractSpecStore {
  InMemoryProductQAContractSpecStore([
    Map<String, ProductQAContractDeclaration>? seed,
  ]) {
    if (seed != null) _rows.addAll(seed);
  }

  final Map<String, ProductQAContractDeclaration> _rows =
      <String, ProductQAContractDeclaration>{};

  int get rowCount => _rows.length;

  @override
  Future<void> saveQAContractSpec(
    ProductQAContractDeclaration declaration,
  ) async {
    _rows[declaration.productId] = declaration;
  }

  @override
  Future<ProductQAContractDeclaration?> readQAContractSpec(
    String productId,
  ) async => _rows[productId];
}

/// A gate declaration of the shape a product manifest carries.
QAGateSpec declaredGate({
  String gateId = 'g1',
  String type = 'declared-gate',
  bool required = true,
  Map<String, dynamic> config = const {'tool': 'a human choice'},
}) =>
    QAGateSpec(gateId: gateId, type: type, required: required, config: config);

ProductQAContractDeclaration declarationFor(
  String productId, {
  List<QAGateSpec>? gates,
  String? manifestVersion = 'v1',
}) => ProductQAContractDeclaration(
  productId: productId,
  gates: gates ?? [declaredGate()],
  manifestVersion: manifestVersion,
  createdAt: kNow,
  updatedAt: kNow,
);

void main() {
  group('the contract id is WORK-ITEM-scoped, not defect-scoped', () {
    test('it is derived from the work item, never from a defect', () {
      expect(
        productQAContractIdForWorkItem(kRemediationWorkItemId),
        'qa-product-$kRemediationWorkItemId',
        reason:
            'a defect-scoped id would be qa-triage-DEF-1, which is the triage '
            "parent's primary key; saveQAContract is ON CONFLICT DO UPDATE on "
            'that key, so reusing it would overwrite the triage contract and '
            "repoint its metadata.workItemId at this item",
      );
      expect(
        productQAContractIdForWorkItem(kRemediationWorkItemId),
        isNot(triageQAContractIdForDefect(kDefectId)),
      );
    });

    test(
      'provisioning for a remediation item leaves the triage contract for the '
      'SAME defect byte-identical',
      () async {
        final contracts = InMemoryQAContractStore();

        // The triage parent is provisioned FIRST, exactly as lane A does it,
        // and its stored row is captured verbatim.
        final triageContract = await contracts.provisionQAContract(
          buildAdvisoryTriageQAContract(
            defectId: kDefectId,
            workItemId: kTriageWorkItemId,
            now: kNow,
          ),
        );
        final triageBefore = await contracts.readQAContract(
          triageQAContractIdForDefect(kDefectId),
        );

        // Lane E then provisions for the remediation item of the same defect.
        final provisioner = ProductQAContractProvisioner(
          contractStore: contracts,
          specStore: InMemoryProductQAContractSpecStore({
            kProduct: declarationFor(kProduct),
          }),
        );
        final remediation = await provisioner.provisionForWorkItem(
          productId: kProduct,
          workItemCategory: WorkItemCategory.feature,
          workItemId: kRemediationWorkItemId,
          now: kNow,
        );

        expect(
          remediation.contractId,
          productQAContractIdForWorkItem(kRemediationWorkItemId),
        );
        expect(contracts.rowCount, 2, reason: 'two work items, two contracts');

        // THE ASSERTION THAT MATTERS: the parent's row is untouched — same
        // object, same metadata, same work-item link, same update instant.
        final triageAfter = await contracts.readQAContract(
          triageQAContractIdForDefect(kDefectId),
        );
        expect(triageAfter, triageBefore);
        expect(triageAfter, isNotNull);
        expect(
          triageAfter!.metadata?[qaContractWorkItemIdMetadataKey],
          kTriageWorkItemId,
          reason:
              'the triage contract must still be linked to the TRIAGE work '
              'item; a re-pointed link is what listQAContractsForWorkItem '
              'answers from, and it would make the triage item look '
              'unprovisioned while the remediation item looks provisioned',
        );
        expect(triageAfter.metadata?[qaContractDefectIdMetadataKey], kDefectId);
        expect(triageAfter.gates, triageContract.gates);

        // And the two lanes' contracts are separately discoverable.
        expect(
          (await contracts.listQAContractsForWorkItem(
            kTriageWorkItemId,
          )).map((c) => c.contractId),
          [triageQAContractIdForDefect(kDefectId)],
        );
        expect(
          (await contracts.listQAContractsForWorkItem(
            kRemediationWorkItemId,
          )).map((c) => c.contractId),
          [remediation.contractId],
        );
      },
    );
  });

  group('idempotence: two provisioner calls for one item leave one row', () {
    test(
      'the count is asserted on ROWS and on WRITES, and both are named',
      () async {
        final contracts = InMemoryQAContractStore();
        final provisioner = ProductQAContractProvisioner(
          contractStore: contracts,
          specStore: InMemoryProductQAContractSpecStore({
            kProduct: declarationFor(kProduct),
          }),
        );

        Future<QAContract> provision() => provisioner.provisionForWorkItem(
          productId: kProduct,
          workItemCategory: WorkItemCategory.feature,
          workItemId: kRemediationWorkItemId,
          now: kNow,
        );

        final first = await provision();
        final second = await provision();

        expect(
          contracts.rowCount,
          1,
          reason:
              'ONE row for ONE work item. This is the criterion: a provisioner '
              'that appended, or that derived a fresh id per call, would leave '
              '2 here, and a second qa_contract row for one work item is a row '
              'nothing can tell apart from a different item\'s.',
        );
        expect(
          contracts.writeCounts[productQAContractIdForWorkItem(
            kRemediationWorkItemId,
          )],
          2,
          reason:
              'both calls DID reach the store — this rules out the opposite '
              'vacuity, where a provisioner returns a cached id and the second '
              'call never writes at all',
        );
        expect(second.contractId, first.contractId);
        expect(
          await contracts.listQAContractsForWorkItem(kRemediationWorkItemId),
          hasLength(1),
          reason:
              'and the row is reachable under the work item id, which is how '
              'the completion guard\'s contract is looked up by an auditor',
        );
      },
    );

    test('two DIFFERENT work items produce two rows', () async {
      final contracts = InMemoryQAContractStore();
      final provisioner = ProductQAContractProvisioner(
        contractStore: contracts,
        specStore: InMemoryProductQAContractSpecStore({
          kProduct: declarationFor(kProduct),
        }),
      );

      await provisioner.provisionForWorkItem(
        productId: kProduct,
        workItemCategory: WorkItemCategory.feature,
        workItemId: 'WI-feature-1791823723502264',
        now: kNow,
      );
      await provisioner.provisionForWorkItem(
        productId: kProduct,
        workItemCategory: WorkItemCategory.feature,
        workItemId: kRemediationWorkItemId,
        now: kNow,
      );

      expect(contracts.rowCount, 2);
      expect(
        contracts.writeOrder,
        hasLength(2),
        reason:
            'the idempotence above must be work-item-scoped, not a store that '
            'refuses to write twice',
      );
    });
  });

  group('fail closed, with a NAMED reason and no row written', () {
    // The prior lane's warning, taken as the acceptance criterion: a
    // provisioner that returns null has NOTHING TO REMOVE, so "it refused" is
    // indistinguishable from "it quietly did nothing". Every test below
    // therefore asserts a THROWN, NAMED failure AND a row count of zero — two
    // facts, so neither can pass for the other.
    late InMemoryQAContractStore contracts;
    late InMemoryProductQAContractSpecStore specs;

    setUp(() {
      contracts = InMemoryQAContractStore();
      specs = InMemoryProductQAContractSpecStore();
    });

    ProductQAContractProvisioner provisioner() => ProductQAContractProvisioner(
      contractStore: contracts,
      specStore: specs,
    );

    test('a product that never declared: notDeclared', () async {
      // specs is empty — no write ever happened for this product.
      expect(
        () => provisioner().provisionForWorkItem(
          productId: kProduct,
          workItemCategory: WorkItemCategory.feature,
          workItemId: kRemediationWorkItemId,
          now: kNow,
        ),
        throwsA(
          isA<ProductQAContractSpecUnavailable>()
              .having(
                (e) => e.refusal,
                'refusal',
                ProductQAContractSpecRefusal.notDeclared,
              )
              .having((e) => e.productId, 'productId', kProduct)
              .having((e) => e.workItemId, 'workItemId', kRemediationWorkItemId)
              .having((e) => e.toString(), 'toString', contains(kProduct))
              .having(
                (e) => e.toString(),
                'toString',
                contains(kRemediationWorkItemId),
              ),
        ),
      );
      expect(
        contracts.rowCount,
        0,
        reason:
            'NOTHING was written. A contract with zero gates would satisfy '
            "GuardConditions.qaContractExists()'s null-check and constrain "
            'nothing, which is the fiction this route exists to remove.',
      );
      expect(contracts.writeOrder, isEmpty);
    });

    test('a product that declared an EMPTY gate list: declaresNoGates', () async {
      // A row exists — this is the case that used to be indistinguishable from
      // the one above, and that is why the reasons are two names rather than a
      // boolean.
      await specs.saveQAContractSpec(declarationFor(kProduct, gates: const []));
      expect(specs.rowCount, 1);

      expect(
        () => provisioner().provisionForWorkItem(
          productId: kProduct,
          workItemCategory: WorkItemCategory.feature,
          workItemId: kRemediationWorkItemId,
          now: kNow,
        ),
        throwsA(
          isA<ProductQAContractSpecUnavailable>().having(
            (e) => e.refusal,
            'refusal',
            ProductQAContractSpecRefusal.declaresNoGates,
          ),
        ),
      );
      expect(contracts.rowCount, 0);
      expect(contracts.writeOrder, isEmpty);
    });

    test('a product that DID declare produces a row — the control', () async {
      await specs.saveQAContractSpec(declarationFor(kProduct));

      final contract = await provisioner().provisionForWorkItem(
        productId: kProduct,
        workItemCategory: WorkItemCategory.feature,
        workItemId: kRemediationWorkItemId,
        now: kNow,
      );

      expect(contract.contractId, isNotNull);
      expect(
        contracts.rowCount,
        1,
        reason:
            'the refusal above is not the only '
            'outcome this method has; without this the two refusals would pass on '
            'a provisioner that simply never succeeds',
      );
    });

    test('the refusal names the product, not just the category, so a log line '
        'from it is actionable', () {
      const refusal = ProductQAContractSpecUnavailable(
        productId: kProduct,
        refusal: ProductQAContractSpecRefusal.declaresNoGates,
        workItemId: kRemediationWorkItemId,
      );
      final rendered = refusal.toString();
      expect(rendered, contains(kProduct));
      expect(rendered, contains(kRemediationWorkItemId));
      expect(
        rendered,
        contains('gates'),
        reason: 'the message must say WHICH of the two reasons applied',
      );
    });

    test(
      'the refusal is a distinct type, so a catch-all cannot absorb it as an '
      'internal fault',
      () {
        const refusal = ProductQAContractSpecUnavailable(
          productId: kProduct,
          refusal: ProductQAContractSpecRefusal.notDeclared,
        );
        expect(refusal, isA<Exception>());
        expect(
          refusal,
          isNot(isA<StateError>()),
          reason:
              'a StateError is what a store failure looks like, and letting a '
              'broad "catch (e)" treat both as one thing is how a database '
              'fault gets recorded as "this product declared nothing"',
        );
      },
    );
  });

  group('the built contract is the declaration, not the triage contract', () {
    test('gates carry over verbatim, with evidenceTypes read from config', () {
      final contract = buildProductQAContract(
        spec: QAContractSpec(
          gates: [
            declaredGate(
              gateId: 'build-passes',
              type: 'static-analysis',
              required: true,
              config: {
                'tool': 'dart analyze',
                declaredGateEvidenceTypesConfigKey: ['analysis-report'],
              },
            ),
            declaredGate(gateId: 'smoke', type: 'smoke-test', required: false),
          ],
        ),
        productId: kProduct,
        workItemCategory: WorkItemCategory.feature,
        workItemId: kRemediationWorkItemId,
        manifestVersion: 'v7',
        now: kNow,
      );

      expect(
        contract.contractId,
        productQAContractIdForWorkItem(kRemediationWorkItemId),
      );
      expect(contract.gates.map((g) => g.gateId), ['build-passes', 'smoke']);
      expect(contract.gates.first.required, isTrue);
      expect(
        contract.gates.first.evidenceTypes,
        ['analysis-report'],
        reason:
            'QAGateDefinition requires evidenceTypes and QAGateSpec does not '
            'carry the field, so config is the only place it can be declared',
      );
      expect(
        contract.gates.last.evidenceTypes,
        isEmpty,
        reason:
            'a gate that declares none says so explicitly rather than being '
            'skipped',
      );
      expect(contract.workItemCategory, WorkItemCategory.feature);
      expect(contract.version, productQAContractDeclarationVersion);
      expect(contract.createdAt, kNow);
      expect(contract.updatedAt, kNow);

      expect(
        contract.metadata?[qaContractWorkItemIdMetadataKey],
        kRemediationWorkItemId,
      );
      expect(contract.metadata?[qaContractProductIdMetadataKey], kProduct);
      expect(
        contract.metadata?[qaContractManifestVersionMetadataKey],
        'v7',
        reason:
            'so a later change to the product\'s manifest can be traced back to '
            'the version the gates came from',
      );
    });

    test(
      'pass criteria are DERIVED from the gates, not invented per product',
      () {
        QAContract build(List<QAGateSpec> gates) => buildProductQAContract(
          spec: QAContractSpec(gates: gates),
          productId: kProduct,
          workItemCategory: WorkItemCategory.feature,
          workItemId: kRemediationWorkItemId,
          now: kNow,
        );

        final oneOptional = build([
          declaredGate(gateId: 'a'),
          declaredGate(gateId: 'b', required: false),
        ]);
        final twoOptional = build([
          declaredGate(gateId: 'a'),
          declaredGate(gateId: 'b', required: false),
          declaredGate(gateId: 'c', required: false),
        ]);

        expect(oneOptional.passCriteria?.allRequiredGatesMustPass, isTrue);
        expect(
          oneOptional.passCriteria?.optionalGateFailuresAllowed,
          1,
          reason:
              'the count follows the gates, so a product declaring two optional '
              'gates is not held to the one-gate rule by accident',
        );
        expect(twoOptional.passCriteria?.optionalGateFailuresAllowed, 2);
        expect(
          oneOptional.passCriteria?.waiverRequiresHumanDecision,
          isTrue,
          reason:
              'a waiver is a human decision; a provisioner waiving its own '
              'gates would make the gate a suggestion',
        );
      },
    );

    test('a malformed evidenceTypes is refused, not silently dropped', () {
      // Silently coercing this to [] would produce a row that reads as a
      // faithful copy of a declaration whose evidence requirement differs.
      expect(
        () => buildProductQAContract(
          spec: QAContractSpec(
            gates: [
              declaredGate(
                config: {declaredGateEvidenceTypesConfigKey: 'not-a-list'},
              ),
            ],
          ),
          productId: kProduct,
          workItemCategory: WorkItemCategory.feature,
          workItemId: kRemediationWorkItemId,
          now: kNow,
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('g1'),
          ),
        ),
      );
    });

    test('NO triage gate, role or defect metadata is ever copied in', () {
      final contract = buildProductQAContract(
        spec: QAContractSpec(gates: [declaredGate()]),
        productId: kProduct,
        workItemCategory: WorkItemCategory.feature,
        workItemId: kRemediationWorkItemId,
        now: kNow,
      );

      final rendered = contract.toJson().toString();
      for (final forbidden in [
        'triage-classification-structure',
        'triage-evidence-grounding',
        'defect_evidence_reference',
        'triageDefect',
        qaContractDefectIdMetadataKey,
      ]) {
        expect(
          rendered.contains(forbidden),
          isFalse,
          reason:
              '$forbidden is triage-specific. Stamping it onto a feature item '
              'would declare defect_evidence_reference gates against a work '
              'item that has no defect — which is exactly the shortcut this '
              'route exists to avoid.',
        );
      }
    });

    test('the two contracts for the same subject declare different gates', () {
      final triage = buildAdvisoryTriageQAContract(
        defectId: kDefectId,
        workItemId: kTriageWorkItemId,
        now: kNow,
      );
      final product = buildProductQAContract(
        spec: QAContractSpec(
          gates: [declaredGate(gateId: 'declared-by-human')],
        ),
        productId: kProduct,
        workItemCategory: WorkItemCategory.feature,
        workItemId: kRemediationWorkItemId,
        now: kNow,
      );

      expect(
        triage.gates
            .map((g) => g.gateId)
            .toSet()
            .intersection(product.gates.map((g) => g.gateId).toSet()),
        isEmpty,
        reason: 'not one triage gate may appear on a product-declared contract',
      );
      expect(
        triage.gates.map((g) => g.gateId),
        isNot(product.gates.map((g) => g.gateId)),
      );
    });
  });

  group('the declaration store contract', () {
    test('declaresQAContract is the single definition of "declared"', () {
      expect(
        declarationFor(kProduct).declaresQAContract,
        isTrue,
        reason:
            'one definition, used by the writer, the provisioner and the '
            'tests, so the three cannot disagree about what "declared" means',
      );
      expect(
        declarationFor(kProduct, gates: const []).declaresQAContract,
        isFalse,
      );
      expect(
        declarationFor(kProduct, gates: const []).declaresQAContract,
        isNot(true),
      );
    });

    test('a round trip preserves the declaration the product made', () async {
      final store = InMemoryProductQAContractSpecStore();
      final original = declarationFor(
        kProduct,
        gates: [
          declaredGate(
            gateId: 'a-gate',
            config: {
              'nested': {'deep': true},
              declaredGateEvidenceTypesConfigKey: ['e1', 'e2'],
            },
          ),
          declaredGate(gateId: 'b-gate', required: false),
        ],
      );

      await store.saveQAContractSpec(original);
      final loaded = await store.readQAContractSpec(kProduct);

      expect(
        loaded,
        isNotNull,
        reason:
            'the WRITE alone proves nothing; the '
            'declaration was discarded on write for the whole life of the '
            'platform and only a read proves it survived',
      );
      expect(loaded, original);
      expect(loaded!.gates, original.gates);
      expect(loaded.manifestVersion, original.manifestVersion);
    });

    test('an undeclared product reads null, which is not an error', () async {
      expect(
        await InMemoryProductQAContractSpecStore().readQAContractSpec(
          kOtherProduct,
        ),
        isNull,
      );
    });

    test(
      're-declaring converges on one row and does not duplicate it',
      () async {
        final store = InMemoryProductQAContractSpecStore();
        await store.saveQAContractSpec(declarationFor(kProduct));
        await store.saveQAContractSpec(
          declarationFor(
            kProduct,
            gates: [declaredGate(gateId: 'redeclared')],
            manifestVersion: 'v2',
          ),
        );

        expect(store.rowCount, 1);
        final loaded = await store.readQAContractSpec(kProduct);
        expect(loaded!.gates.single.gateId, 'redeclared');
        expect(loaded.manifestVersion, 'v2');
      },
    );
  });
}
