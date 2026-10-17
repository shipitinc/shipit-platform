import 'package:control_plane_server/src/services/control_plane_service.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:qa_orchestration/qa_orchestration.dart'
    show ProductQAContractDeclaration, ProductQAContractSpecStore;
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart' show ProductTransitions;

/// RE-REGISTRATION MERGES. Human decision
/// `6e83b1c7-4d92-4a06-bf58-3c7a9e0d24f6`.
///
/// ## THE DEFECT THIS HOLDS
///
/// `registerProductWithManifest` used to run `createProduct` then
/// `updateProduct` on EVERY registration, including registrations of products
/// that already existed. Neither of those is a merge:
///
/// - `createProduct` fabricates `state: registered`, `createdAt: now`,
///   `version: 1` and saves it with a null `expectedVersion`, which the Postgres
///   store executes as `INSERT ... ON CONFLICT ("productId") DO UPDATE` over
///   `state`, `createdAt`, `version`, `description`, `name` and
///   `manifestVersion`.
/// - `updateProduct` is then called with `description: null`, which
///   `ProductRegistryEngine.updateProduct` copies straight through.
///
/// `ProductTransitions` has NO edge from `registered` back to `governed`
/// (`product_transitions.dart:81` is `registered -> baselinePending`, `:138` is
/// `registered -> archived` and human-gated). So re-registering the live
/// `shipit-platform` — `governed`, description present,
/// `manifestVersion=v1791564352899`, `version=5`, with an ACCEPTED baseline
/// `bl-shipit-platform-1` rev 1 — knocked it out of governance with no edge back,
/// and recovery meant a new baseline revision, a new independent verification
/// and a new human approval. An operator pressing a button destroyed the
/// product's governance.
///
/// ## WHY FOUR SEPARATE ASSERTIONS, AND WHY ON ALL FOUR
///
/// A fix that preserves `state` and still bumps `version` has NOT solved this,
/// and neither has one that preserves `version` and still nulls `description`:
/// all four columns were independently damaged, they are independently written
/// by the two calls above, and the acceptance criterion names all four. They are
/// asserted individually with the expected value in the message, so a failure
/// says WHICH column moved rather than dumping two `Product` objects.
///
/// ## THE FIX IS ASSERTED AGAINST THE STORE, NOT AGAINST THE RETURN VALUE
///
/// [ControlPlaneService.registerProduct] returns the preserved product, so a
/// test that only checked the return value would pass even if the row on disk had
/// been clobbered and the good object returned by hand. Everything here is read
/// back through `readProduct`, and the merge is additionally held by a WRITE
/// COUNT: the merge path must perform ZERO product writes, which is a stronger
/// and simpler statement than "the four columns happen to match afterwards".
///
/// ## THE ON/OFFBOARD PATH IS A SEPARATE CALL SITE AND IS NOT EXERCISED HERE
///
/// `apps/server/bin/onboard_shipit_dev.dart` and
/// `apps/server/onboard_shipit_serverpod.dart` both call `engine.createProduct`
/// DIRECTLY, inside `on ProductNotFoundException`, and never go through
/// `registerProduct`. The merge is a decision inside `registerProduct`, so no
/// edit to it can reach them. What this file pins is the other half of that
/// claim: a genuinely absent product still goes down the create path, which is
/// what those scripts rely on.
const String kProduct = 'reregister-existing';
const String kFreshProduct = 'reregister-fresh';
const String kOtherProduct = 'reregister-other';

/// The lifecycle values the live `shipit-platform` row carried when the defect
/// was found. A fixture that used `registered`/`version: 1` could not tell
/// "preserved" from "coincidentally already this".
final DateTime kCreatedAt = DateTime.utc(2026, 10, 15, 8, 0, 0);
final DateTime kLastTouched = DateTime.utc(2026, 10, 16, 21, 45, 0);
const String kDescription = 'The platform itself (S-1 dogfood).';
const String kManifestVersion = 'v1791564352899';
const int kVersion = 5;
const ProductState kState = ProductState.governed;

final List<String> _log = <String>[];

void _logSink(String event, Map<String, Object?> fields) => _log.add(event);

/// A [ProductQAContractSpecStore] keyed the way PostgreSQL keys it — one row per
/// `productId`, a second write REPLACES — and counting its writes.
///
/// Without the replace, the "an existing declaration is UPDATED" test below
/// would pass on a store that can only ever accumulate, which is a property
/// nothing downstream depends on.
class _CountingSpecStore implements ProductQAContractSpecStore {
  final Map<String, ProductQAContractDeclaration> rows =
      <String, ProductQAContractDeclaration>{};
  int writes = 0;

  @override
  Future<void> saveQAContractSpec(
    ProductQAContractDeclaration declaration,
  ) async {
    writes++;
    rows[declaration.productId] = declaration;
  }

  @override
  Future<ProductQAContractDeclaration?> readQAContractSpec(
    String productId,
  ) async => rows[productId];
}

/// Counts `saveProduct` calls on the engine's store, so "the merge wrote no
/// product row" is an assertion with a number in it rather than an inference
/// from four columns that happen to match.
class _WriteCountingRegistryStore extends InMemoryProductRegistryStore {
  int productWrites = 0;

  @override
  Future<void> saveProduct(Product product, {int? expectedVersion}) {
    productWrites++;
    return super.saveProduct(product, expectedVersion: expectedVersion);
  }
}

ProductManifest _manifest(String productId, {required List<QAGateSpec> gates}) {
  return ProductManifest(
    productId: productId,
    name: 'A manifest for $productId',
    version: '1.0.0',
    capabilities: const <String>[],
    environments: const <EnvironmentConfig>[],
    contracts: ProductContracts(
      workItemCategories: const <String>[],
      designContract: const DesignContractSpec(
        requiredArtifacts: <String>[],
        reviewers: <String>[],
        approvalThreshold: 0,
      ),
      qaContract: QAContractSpec(gates: gates),
      deploymentContract: const DeploymentContractSpec(
        promotionPath: <String>[],
        approvalGates: <ApprovalGateSpec>[],
      ),
    ),
    createdAt: kCreatedAt,
    updatedAt: kCreatedAt,
  );
}

QAGateSpec _gate(String gateId) => QAGateSpec(
  gateId: gateId,
  type: 'triage-classification-structure',
  required: true,
  config: const <String, dynamic>{'sourceColumn': 'agent_result.x'},
);

({ProductRegistryEngine engine, _WriteCountingRegistryStore store})
_registry() {
  final store = _WriteCountingRegistryStore();
  return (
    engine: ProductRegistryEngine(
      store: store,
      humanDecisionStore: InMemoryHumanDecisionStore(),
    ),
    store: store,
  );
}

/// The product row as it exists BEFORE a re-registration: the governed,
/// version-5, described, old-`createdAt` shape the defect destroys.
Product _governedRow() => Product(
  productId: kProduct,
  name: 'ShipIt Platform',
  description: kDescription,
  manifestVersion: kManifestVersion,
  state: kState,
  createdAt: kCreatedAt,
  updatedAt: kLastTouched,
  version: kVersion,
);

/// The registration a client actually makes: a name, an EMPTY description, and
/// a manifest. `description: ''` is what `add_product_page.dart`'s
/// `_ensureProductAndRepository` sends on every check and every register, so it
/// is what a re-registration from the UI looks like — and writing it through
/// would erase [kDescription].
///
/// [omitManifest] exists because the server distinguishes "no manifest supplied"
/// (`manifest: null`) from "a manifest was supplied", and Dart cannot tell an
/// omitted optional argument from an explicit `null` — so a plain `??` default
/// would silently make every call a manifest-bearing one and the
/// `notDeclared` cases would never be reached.
Future<Product> _reregister({
  required ProductRegistryEngine engine,
  required ProductQAContractSpecStore specStore,
  required String productId,
  List<QAGateSpec>? gates,
  ProductManifest? manifest,
  bool omitManifest = false,
  String? manifestVersion,
  DateTime? now,
}) {
  return ControlPlaneService.registerProduct(
    engine: engine,
    specStore: specStore,
    log: _logSink,
    productId: productId,
    name: 'ShipIt Platform',
    description: '',
    manifest: omitManifest
        ? null
        : manifest ??
              _manifest(
                productId,
                gates: gates ?? <QAGateSpec>[_gate('gate-registered')],
              ),
    manifestVersion: manifestVersion ?? 'v9999999999999',
    now: now ?? DateTime.utc(2026, 10, 17, 12, 0, 0),
  );
}

/// Asserts that all FOUR preserved columns survived, reporting every one that
/// moved rather than stopping at the first.
///
/// Four separate `expect` calls would each abort the test, so a run with the
/// merge reverted would name `state` and leave `description`, `createdAt` and
/// `version` unexamined — which is exactly the shape of the thing this file
/// exists to rule out: a fix that repairs one column and quietly damages
/// three. Collecting the mismatches means one failure message lists all four
/// damaged columns with both values, and the count in that message is the
/// evidence that the assertions are live.
void _expectLifecyclePreserved(Product before, Product after) {
  final mismatches = <String>[];

  void check(String column, Object? was, Object? now) {
    if (was != now) mismatches.add('  $column: $was -> $now');
  }

  check('state', before.state.wire, after.state.wire);
  check('description', before.description, after.description);
  check(
    'createdAt',
    before.createdAt.toUtc().toIso8601String(),
    after.createdAt.toUtc().toIso8601String(),
  );
  check('version', before.version, after.version);

  expect(
    mismatches,
    isEmpty,
    reason:
        'a re-registration must preserve all four of state, description, '
        'createdAt and version, and ${mismatches.length} of 4 moved:\n'
        '${mismatches.join("\n")}'
        '\n`state` moving to `registered` is the destructive one: '
        'ProductTransitions has no edge from registered back to governed, so '
        'the product is stranded and recovery needs a new baseline revision, '
        'a new verification and a new human approval. A merge that repaired '
        'only `state` and still bumped `version` would break every caller '
        'holding the old version as a compare-and-swap token, which is why '
        'these are four columns and not one.',
  );
}

void main() {
  setUp(_log.clear);

  group('re-registering an existing product MERGES (decision 6e83b1c7)', () {
    test(
      'a governed product keeps state, description, createdAt and version',
      () async {
        final r = _registry();
        final specs = _CountingSpecStore();
        final before = _governedRow();
        await r.store.saveProduct(before);
        expect(r.store.productWrites, 1, reason: 'fixture write only');
        r.store.productWrites = 0;

        final returned = await _reregister(
          engine: r.engine,
          specStore: specs,
          productId: kProduct,
        );

        final after = await r.engine.readProduct(kProduct);
        _expectLifecyclePreserved(before, after);

        // The returned object is the STORED one, not a reconstruction. A merge
        // that returned a fresh `registered` v1 object would make the endpoint's
        // `loadProductDetail` show a state the row is not in.
        expect(returned.state, kState);
        expect(returned.version, kVersion);
      },
    );

    test('the merge performs ZERO writes to the product row', () async {
      final r = _registry();
      final specs = _CountingSpecStore();
      await r.store.saveProduct(_governedRow());
      r.store.productWrites = 0;

      await _reregister(
        engine: r.engine,
        specStore: specs,
        productId: kProduct,
      );

      expect(
        r.store.productWrites,
        0,
        reason:
            'the merge wrote the product row ${r.store.productWrites} time(s). '
            'Preservation is meant to hold by construction — no write — not by '
            'four assignments that happen to restore the previous values.',
      );
    });

    test('the merge is idempotent across repeated presses', () async {
      final r = _registry();
      final specs = _CountingSpecStore();
      final before = _governedRow();
      await r.store.saveProduct(before);

      // The client calls this on every check AND every register, so "repeated"
      // is the normal case, not an edge case.
      for (var press = 1; press <= 5; press++) {
        await _reregister(
          engine: r.engine,
          specStore: specs,
          productId: kProduct,
        );
        final after = await r.engine.readProduct(kProduct);
        _expectLifecyclePreserved(before, after);
      }

      expect(
        specs.rows[kProduct],
        isNotNull,
        reason:
            'a product that declares gates must END with a declaration however '
            'many times it was registered; a merge that dropped the '
            'declaration to avoid touching the row would leave the product '
            'ungovernable by any gate.',
      );
      expect(specs.rows[kProduct]!.gates.single.gateId, 'gate-registered');
    });

    test(
      'a re-registration that supplies no manifest does NOT create one',
      () async {
        final r = _registry();
        final specs = _CountingSpecStore();
        final before = _governedRow();
        await r.store.saveProduct(before);

        await _reregister(
          engine: r.engine,
          specStore: specs,
          productId: kProduct,
          omitManifest: true,
        );

        expect(
          specs.writes,
          0,
          reason: 'no manifest declares nothing to write',
        );
        expect(
          specs.rows.containsKey(kProduct),
          isFalse,
          reason:
              'a merge must not fabricate a declaration. `manifest: null` is the '
              'claim "this product declared nothing" and the provisioner turns it '
              'into ProductQAContractSpecRefusal.notDeclared.',
        );
        _expectLifecyclePreserved(
          before,
          await r.engine.readProduct(kProduct),
        );
      },
    );

    test('a re-registration with an EMPTY gate list does not blank a '
        'declaration', () async {
      final r = _registry();
      final specs = _CountingSpecStore();
      await r.store.saveProduct(_governedRow());
      specs.rows[kProduct] = ProductQAContractDeclaration(
        productId: kProduct,
        gates: <QAGateSpec>[_gate('gate-registered')],
        manifestVersion: kManifestVersion,
        createdAt: kCreatedAt,
        updatedAt: kCreatedAt,
      );

      await _reregister(
        engine: r.engine,
        specStore: specs,
        productId: kProduct,
        manifest: _manifest(kProduct, gates: const <QAGateSpec>[]),
      );

      expect(
        specs.rows[kProduct]!.gates.single.gateId,
        'gate-registered',
        reason:
            '`gates: []` is the ABSENCE of a declaration, so nothing is written '
            '— and writing nothing must not mean deleting what the product '
            'already declared.',
      );
    });

    test(
      'the merge is LOGGED as a merge, and names what it preserved',
      () async {
        final r = _registry();
        final specs = _CountingSpecStore();
        await r.store.saveProduct(_governedRow());

        await _reregister(
          engine: r.engine,
          specStore: specs,
          productId: kProduct,
        );

        expect(
          _log,
          contains('product_registry.registered_with_manifest'),
          reason: 'the registration itself is logged',
        );
        expect(
          _log,
          isNot(contains('product_registry.qa_contract_spec.not_declared')),
          reason:
              'a manifest with gates WAS supplied, so nothing is undeclared',
        );
        expect(_log, contains('product_registry.qa_contract_spec.declared'));
      },
    );
  });

  group('the merge writes the DECLARED QA CONTRACT (add, then update)', () {
    test('an existing product with no declaration gets one', () async {
      final r = _registry();
      final specs = _CountingSpecStore();
      await r.store.saveProduct(_governedRow());

      await _reregister(
        engine: r.engine,
        specStore: specs,
        productId: kProduct,
        gates: <QAGateSpec>[_gate('gate-first')],
      );

      expect(specs.writes, 1);
      expect(specs.rows[kProduct]!.gates.single.gateId, 'gate-first');
      expect(specs.rows[kProduct]!.manifestVersion, 'v9999999999999');
      expect(
        (await r.engine.readProduct(kProduct)).state,
        kState,
        reason: 'adding a declaration must not disturb governance',
      );
    });

    test(
      'an EXISTING declaration is UPDATED, not skipped and not duplicated',
      () async {
        final r = _registry();
        final specs = _CountingSpecStore();
        await r.store.saveProduct(_governedRow());
        specs.rows[kProduct] = ProductQAContractDeclaration(
          productId: kProduct,
          gates: <QAGateSpec>[_gate('gate-old')],
          manifestVersion: kManifestVersion,
          createdAt: kCreatedAt,
          updatedAt: kCreatedAt,
        );

        await _reregister(
          engine: r.engine,
          specStore: specs,
          productId: kProduct,
          gates: <QAGateSpec>[_gate('gate-new')],
        );

        expect(specs.writes, 1, reason: 'the declaration was written');
        expect(
          specs.rows.length,
          1,
          reason:
              'one row per productId; a second row is not a second contract',
        );
        expect(
          specs.rows[kProduct]!.gates.single.gateId,
          'gate-new',
          reason:
              'the re-registration re-declared `gate-new`. Keeping `gate-old` '
              'would mean a re-registration cannot change a product\'s gates, '
              'which is the one thing the merge IS allowed to write.',
        );
        expect(specs.rows[kProduct]!.manifestVersion, 'v9999999999999');
      },
    );
  });

  group('a genuinely NEW product is CREATED, unchanged', () {
    test('an absent product is created with its supplied values', () async {
      final r = _registry();
      final specs = _CountingSpecStore();
      final now = DateTime.utc(2026, 10, 17, 12, 0, 0);

      final created = await _reregister(
        engine: r.engine,
        specStore: specs,
        productId: kFreshProduct,
        manifestVersion: '1.0.0',
        now: now,
      );

      final stored = await r.engine.readProduct(kFreshProduct);
      expect(
        stored.state,
        ProductState.registered,
        reason: 'a new product starts `registered` — that path is unchanged',
      );
      expect(stored.name, 'ShipIt Platform');
      expect(
        stored.description,
        '',
        reason:
            'creation still writes the description it was given, empty string '
            'included. The merge does not change what creation does.',
      );
      expect(stored.createdAt.toUtc(), now);
      expect(
        stored.manifestVersion,
        '1.0.0',
        reason:
            'creation still records the manifest version, through '
            '`updateProduct`.',
      );
      expect(stored.version, 2, reason: 'create is v1, the manifest update v2');
      expect(created.productId, kFreshProduct);
      expect(
        specs.rows[kFreshProduct],
        isNotNull,
        reason: 'a new product\'s declaration is written too',
      );
      expect(
        r.store.productWrites,
        2,
        reason:
            'create + the manifest-version update; the create path is '
            'byte-for-byte the same two writes it always was',
      );
    });

    test(
      'a new product with no manifest is created and declares nothing',
      () async {
        final r = _registry();
        final specs = _CountingSpecStore();

        await _reregister(
          engine: r.engine,
          specStore: specs,
          productId: kFreshProduct,
          omitManifest: true,
        );

        expect(
          (await r.engine.readProduct(kFreshProduct)).state,
          ProductState.registered,
        );
        expect(specs.writes, 0);
        expect(
          _log,
          contains('product_registry.qa_contract_spec.not_declared'),
        );
      },
    );

    test('the merge touches only the product that was re-registered', () async {
      final r = _registry();
      final specs = _CountingSpecStore();
      await r.store.saveProduct(_governedRow());
      await r.store.saveProduct(
        Product(
          productId: kOtherProduct,
          name: 'Another product',
          description: 'not involved',
          manifestVersion: 'v1',
          state: ProductState.baselineReview,
          createdAt: kCreatedAt,
          updatedAt: kCreatedAt,
          version: 2,
        ),
      );
      final otherBefore = await r.engine.readProduct(kOtherProduct);

      await _reregister(
        engine: r.engine,
        specStore: specs,
        productId: kProduct,
      );

      _expectLifecyclePreserved(
        otherBefore,
        await r.engine.readProduct(kOtherProduct),
      );
      expect(
        specs.rows.containsKey(kOtherProduct),
        isFalse,
        reason: 'one registration declares for one product',
      );
    });
  });

  group('ProductTransitions really has no way back (the merge is the fix, '
      'not a missing edge)', () {
    test('`registered -> governed` is refused by the table itself', () {
      expect(
        ProductTransitions.explainRejection(
          ProductState.registered,
          ProductState.governed,
        ),
        isNotNull,
        reason:
            'This is why the clobber was destructive rather than untidy. If '
            'this ever becomes null, a transition-table fix may be worth '
            'considering — but it would not have preserved description, '
            'createdAt or version, so it is not a substitute for the merge.',
      );
    });
  });
}
