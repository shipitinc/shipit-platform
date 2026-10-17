import 'dart:convert';

import 'package:control_plane_server/src/persistence/postgres_product_qa_contract_spec_store.dart';
import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:serverpod/database.dart';
// `test` is a dev_dependency of `control_plane_server`; it is unresolved as a
// `lib/` import, which is a known cost of co-locating tests here.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

/// A [DatabaseResultRow] over a plain map, so the production row mapper can be
/// exercised on real column values without a database.
///
/// `decodeUtc` in `db_row_util.dart` takes the raw driver shape — a [DateTime]
/// with no zone — and these hand it exactly that, rather than an ISO string,
/// because the string branch is a compatibility fallback and asserting against
/// it would leave the branch a `text`-column actually takes untested.
DatabaseResultRow _row(Map<String, Object?> columns) => _StubRow(columns);

/// The VALUES a query returns are the columns in order; [toColumnMap] is the
/// accessor the production reader uses, so only it has to be faithful.
class _StubRow extends DatabaseResultRow {
  _StubRow(this.columns) : super(columns.values.toList());

  final Map<String, Object?> columns;

  @override
  Map<String, dynamic> toColumnMap() => Map<String, dynamic>.from(columns);
}

final DateTime kCreated = DateTime.utc(2026, 10, 17, 9, 0, 0);
final DateTime kUpdated = DateTime.utc(2026, 10, 17, 9, 30, 0);

ProductQAContractDeclaration _declaration({
  List<QAGateSpec>? gates,
  String? manifestVersion = 'v7',
  int version = 1,
}) => ProductQAContractDeclaration(
  productId: 'product-under-test',
  gates:
      gates ??
      const [
        QAGateSpec(
          gateId: 'a-gate',
          type: 'static-analysis',
          required: true,
          config: {
            'tool': 'dart analyze',
            'evidenceTypes': ['analysis-report'],
          },
        ),
        QAGateSpec(
          gateId: 'b-gate',
          type: 'smoke-test',
          required: false,
          config: <String, dynamic>{},
        ),
      ],
  manifestVersion: manifestVersion,
  createdAt: kCreated,
  updatedAt: kUpdated,
  version: version,
);

/// The column map a `product_qa_contract_spec` row produces, built by DECODING
/// the JSON the writer would have written — not by re-using a hand-written
/// literal. That is what makes this a ROUND TRIP rather than two halves of a
/// test agreeing with each other: the reader is handed the writer's bytes.
Map<String, Object?> _columnsFrom(ProductQAContractDeclaration declaration) {
  final params = productQAContractSpecParams(declaration);
  return <String, Object?>{
    'id': 1,
    'productId': params['productId'],
    'gatesJson': jsonDecode(params['gates'] as String) as Object,
    'manifestVersion': params['manifestVersion'],
    'createdAt': params['createdAt'],
    'updatedAt': params['updatedAt'],
    'version': params['version'],
  };
}

void main() {
  group(
    'a declared QA contract survives the write AND the read',
    () {
      test('the declaration comes back equal, gates and all', () {
        final original = _declaration();

        final loaded = productQAContractSpecFromRow(
          _row(_columnsFrom(original)),
        );

        expect(
          loaded,
          original,
          reason:
              'the WRITE alone proves nothing. ProductManifest.contracts.qaContract '
              'was written and then DISCARDED for the whole life of the platform '
              '— no read path existed at all — and only reading it back can '
              'distinguish "persisted" from "persisted and thrown away".',
        );
        expect(loaded.gates, original.gates);
        expect(loaded.gates.map((g) => g.gateId), ['a-gate', 'b-gate']);
        expect(
          loaded.gates.first.config['evidenceTypes'],
          ['analysis-report'],
          reason: 'gate config must survive verbatim, nested values included',
        );
        expect(loaded.manifestVersion, 'v7');
        expect(loaded.createdAt, kCreated);
        expect(loaded.updatedAt, kUpdated);
        expect(loaded.declaresQAContract, isTrue);
      });

      test(
        'gate ORDER is preserved — it is the order they were declared in',
        () {
          final original = _declaration(
            gates: const [
              QAGateSpec(gateId: 'z', type: 't', required: true, config: {}),
              QAGateSpec(gateId: 'a', type: 't', required: true, config: {}),
              QAGateSpec(gateId: 'm', type: 't', required: true, config: {}),
            ],
          );

          final loaded = productQAContractSpecFromRow(
            _row(_columnsFrom(original)),
          );

          expect(loaded.gates.map((g) => g.gateId), ['z', 'a', 'm']);
        },
      );

      test('a re-declaration with a different manifestVersion reads back the '
          'new one', () {
        final reloaded = productQAContractSpecFromRow(
          _row(_columnsFrom(_declaration(manifestVersion: 'v8', version: 2))),
        );

        expect(reloaded.manifestVersion, 'v8');
        expect(reloaded.version, 2);
      });

      test(
        'a null manifestVersion round-trips as null, not as an empty string',
        () {
          final original = _declaration(manifestVersion: null);

          final loaded = productQAContractSpecFromRow(
            _row(_columnsFrom(original)),
          );

          expect(loaded.manifestVersion, isNull);
          expect(loaded, original);
        },
      );

      test('a declaration with NO gates round-trips as no gates', () {
        // An empty list is readable as an empty list. Whether that is a valid
        // DECLARATION is the provisioner's question and it answers it by name;
        // what the store must not do is turn it into something else on the way
        // through.
        final original = _declaration(gates: const []);

        final loaded = productQAContractSpecFromRow(
          _row(_columnsFrom(original)),
        );

        expect(loaded.gates, isEmpty);
        expect(loaded.declaresQAContract, isFalse);
      });
    },
  );

  group('a defective column is refused, not degraded', () {
    // The failure this prevents: `productQAContractSpecGates` returning `[]`
    // for an unparseable column would turn a DATA FAULT into the
    // `declaresNoGates` refusal, whose message reads "this product declared
    // nothing" and sends an operator to fix the wrong thing entirely.
    test('unparseable JSON throws, naming the column', () {
      expect(
        () => productQAContractSpecGates('{not json'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('product_qa_contract_spec.gatesJson'),
          ),
        ),
      );
    });

    test('JSON that is not an array throws', () {
      expect(
        () => productQAContractSpecGates('{"gateId":"g1"}'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('must be a JSON array'),
          ),
        ),
      );
    });

    test('an array of non-objects throws, and names the position', () {
      expect(
        () => productQAContractSpecGates(
          '[{"gateId":"g","type":"t","required":true,"config":{}}, 2]',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('position 1'),
          ),
        ),
      );
    });

    test('NULL and empty columns read as no gates — the honest answer', () {
      expect(productQAContractSpecGates(null), isEmpty);
      expect(productQAContractSpecGates('   '), isEmpty);
    });

    test('a NULL createdAt is refused rather than defaulted to now', () {
      // Defaulting would invent a creation instant, and a reader would have no
      // way to tell an invented one from a recorded one.
      expect(
        () => productQAContractSpecFromRow(
          _row(const <String, Object?>{
            'productId': 'p',
            'gatesJson': '[]',
            'manifestVersion': null,
            'createdAt': null,
            'updatedAt': null,
            'version': 1,
          }),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('createdAt'),
          ),
        ),
      );
    });
  });

  group('the writer parameters name every column the reader reads', () {
    test('the two sides agree on the column set', () {
      // A column added to one and not the other is a runtime surprise, and the
      // two halves are in the same file for exactly this check.
      final params = productQAContractSpecParams(_declaration());
      expect(
        params.keys.toSet(),
        {
          'productId',
          'gates',
          'manifestVersion',
          'createdAt',
          'updatedAt',
          'version',
        },
        reason:
            'these are the six @parameters the INSERT binds and the six columns '
            'the SELECT mapper reads. The surrogate `id` is in neither: nothing '
            'reads it and threading a database-generated value into the domain '
            'object would be the wrong shape.',
      );
    });
  });
}
