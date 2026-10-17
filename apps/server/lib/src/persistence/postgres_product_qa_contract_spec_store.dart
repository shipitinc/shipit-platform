import 'dart:convert';

import 'package:qa_orchestration/qa_orchestration.dart';
import 'package:serverpod/database.dart';

import 'persistence_database.dart';
import 'util/db_row_util.dart';

/// The one mapper between a `product_qa_contract_spec` row and a
/// [ProductQAContractDeclaration].
///
/// It is TOP-LEVEL rather than a private member of the store so that the row
/// shape can be round-tripped in a test that needs no database. A store whose
/// encoder and decoder are private cannot be tested at all without one, and
/// "the declared contract survives save to load" is precisely the property that
/// has never been true on this data — `ProductManifest.contracts.qaContract`
/// was discarded on write for the whole life of the platform, which is only
/// detectable by reading it back. So the codec is public, the store is a thin
/// wrapper over two statements, and the codec is what the tests hold to.
///
/// Column naming and types are the ones declared by migration `20261017102506000`.
/// `gatesJson` is a `text` column holding a JSON array of `QAGateSpec`
/// documents, matching `qa_contract."gatesJson"`, and it is decoded one gate at
/// a time so a failure is attributable to one gate rather than to the row.
Map<String, Object?> productQAContractSpecParams(
  ProductQAContractDeclaration declaration,
) {
  return {
    'productId': declaration.productId,
    'gates': jsonEncode(
      declaration.gates.map((gate) => gate.toJson()).toList(),
    ),
    'manifestVersion': declaration.manifestVersion,
    'createdAt': PersistenceDatabase.toUtc(declaration.createdAt),
    'updatedAt': PersistenceDatabase.toUtc(declaration.updatedAt),
    'version': declaration.version,
  };
}

/// Reads a [ProductQAContractDeclaration] back out of a `product_qa_contract_spec`
/// row.
///
/// The two halves of this file mirror each other column for column, and the
/// round trip is what makes them checkable: [productQAContractSpecParams] names
/// six parameters and this names the same six columns. A column added to one
/// and not the other is a bug that is visible in a diff rather than a runtime
/// surprise.
///
/// The `id` surrogate key is deliberately absent from both sides: nothing reads
/// it, and threading it through would put a database-generated value into a
/// domain object that has no business knowing one.
ProductQAContractDeclaration productQAContractSpecFromRow(
  DatabaseResultRow row,
) {
  final m = row.toColumnMap();
  return ProductQAContractDeclaration(
    productId: m['productId'] as String,
    gates: productQAContractSpecGates(m['gatesJson']),
    manifestVersion: m['manifestVersion'] as String?,
    createdAt: _decodeUtcOrThrow(m['createdAt'], 'createdAt')!,
    updatedAt: _decodeUtcOrThrow(m['updatedAt'], 'updatedAt')!,
    version: (m['version'] as num?)?.toInt() ?? 1,
  );
}

/// Decodes the `gatesJson` column.
///
/// Deliberately strict, for the same reason `db_row_util.dart`'s
/// `decodeJsonArray` is: a malformed column here means the product's declared
/// QA contract cannot be read, and every product's QA provisioning fails
/// closed because of it. Degrading that to an empty gate list would convert a
/// visible data fault into the silent `declaresNoGates` refusal — a reason that
/// reads as "this product declared nothing" and sends an operator to fix the
/// wrong thing. So it throws, and the message names the column.
List<QAGateSpec> productQAContractSpecGates(Object? value) {
  final Object? decoded;
  if (value == null) {
    decoded = null;
  } else if (value is String) {
    if (value.trim().isEmpty) return const [];
    try {
      decoded = jsonDecode(value);
    } on FormatException catch (error) {
      throw FormatException(
        'product_qa_contract_spec.gatesJson is not parseable JSON: ${error.message}',
      );
    }
  } else {
    // The driver may hand a `json` column back already decoded. A `text`
    // column does not, but accepting both shapes costs nothing and means the
    // store keeps working if this column is ever retyped.
    decoded = value;
  }
  if (decoded == null) return const [];
  if (decoded is! List) {
    throw FormatException(
      'product_qa_contract_spec.gatesJson must be a JSON array of gate '
      'declarations, got ${decoded.runtimeType}',
    );
  }
  return List<QAGateSpec>.unmodifiable(
    decoded.indexed.map((entry) {
      final (index, element) = entry;
      if (element is! Map) {
        throw FormatException(
          'product_qa_contract_spec.gatesJson must contain gate declaration '
          'objects, got ${element.runtimeType} at position $index',
        );
      }
      return QAGateSpec.fromJson(Map<String, dynamic>.from(element));
    }),
  );
}

DateTime? _decodeUtcOrThrow(Object? value, String column) {
  final decoded = decodeUtc(value);
  if (decoded == null) {
    throw FormatException(
      'product_qa_contract_spec.$column is NULL; the column is NOT NULL and a '
      'row without it was not written by this store',
    );
  }
  return decoded;
}

/// The single owner of every read and write against
/// `product_qa_contract_spec`.
///
/// ## What this store is for
///
/// `ProductManifest.contracts.qaContract` had exactly one production
/// construction site and no read path at all: the endpoint wrote
/// `QAContractSpec(gates: const [])` and `saveProduct` wrote eight columns,
/// none of them `contracts`. So a product's declared QA contract was discarded
/// on write, could never be loaded, and every work item the defect-triage lane
/// did not create was refused forever at `agentExecuting -> agentCompleted` by
/// `GuardConditions.qaContractExists()`.
///
/// ## Why the write is an upsert keyed on `productId`
///
/// A product has one declared QA contract. `product_qa_contract_spec_product_unique`
/// enforces that at the database, and `ON CONFLICT ("productId") DO UPDATE`
/// makes re-declaring converge on one row instead of failing or duplicating.
/// This is the same shape as `saveProduct`, `saveRepositoryReference` and every
/// other single-row-per-entity writer in this repository.
///
/// ## Why `createdAt` is preserved on the update branch
///
/// Re-declaring a product's QA contract changes what the gates are, not when
/// the product first declared anything, so `createdAt` is carried from the
/// existing row rather than overwritten. That is what lets a reader see both
/// how long a product has declared these gates and when they last changed.
/// `updatedAt` and `version` come from the caller, which is the same contract
/// every other store here has: the caller asserts when the change happened.
class PostgresProductQAContractSpecStore implements ProductQAContractSpecStore {
  PostgresProductQAContractSpecStore(this._db);

  final PersistenceDatabase _db;

  @override
  Future<void> saveQAContractSpec(
    ProductQAContractDeclaration declaration,
  ) async {
    final params = productQAContractSpecParams(declaration);
    await _db.execute(
      '''INSERT INTO "product_qa_contract_spec" (
             "productId", "gatesJson", "manifestVersion",
             "createdAt", "updatedAt", "version"
           ) VALUES (
             @productId, @gates, @manifestVersion,
             @createdAt, @updatedAt, @version
           )
           ON CONFLICT ("productId") DO UPDATE SET
             "gatesJson" = EXCLUDED."gatesJson",
             "manifestVersion" = EXCLUDED."manifestVersion",
             "createdAt" = "product_qa_contract_spec"."createdAt",
             "updatedAt" = EXCLUDED."updatedAt",
             "version" = EXCLUDED."version"''',
      parameters: QueryParameters.named(params),
    );
  }

  @override
  Future<ProductQAContractDeclaration?> readQAContractSpec(
    String productId,
  ) async {
    final rows = await _db.query(
      'SELECT * FROM "product_qa_contract_spec" WHERE "productId" = @productId',
      parameters: QueryParameters.named({'productId': productId}),
    );
    if (rows.isEmpty) return null;
    return productQAContractSpecFromRow(rows.first);
  }
}
