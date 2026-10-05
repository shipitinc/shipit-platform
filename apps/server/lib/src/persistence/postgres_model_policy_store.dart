import 'dart:convert';

import 'package:platform_contracts/platform_contracts.dart'
    show ModelPolicy, ModelStep, AgentRole, ModelPolicyStore;
import 'package:serverpod/database.dart';

import 'persistence_database.dart';
import 'util/db_row_util.dart';

/// PostgreSQL implementation of [ModelPolicyStore].
class PostgresModelPolicyStore implements ModelPolicyStore {
  PostgresModelPolicyStore(this._db);

  final PersistenceDatabase _db;

  Future<T> inTransaction<T>(
    Future<T> Function(PostgresModelPolicyStore store) body,
  ) {
    return _db.inTransaction<T>(() => body(this));
  }

  @override
  Future<ModelPolicy?> getPolicy(AgentRole role) async {
    final rows = await _db.query(
      'SELECT * FROM "model_policy" WHERE "role" = @role',
      parameters: QueryParameters.named({'role': role.wire}),
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<void> upsertPolicy(ModelPolicy policy) async {
    await _db.execute(
      '''INSERT INTO "model_policy" ("role", "chainJson", "version", "updatedAt", "updatedByDecisionId")
         VALUES (@role, @chainJson, @version, @updatedAt, @updatedByDecisionId)
         ON CONFLICT ("role") DO UPDATE SET
           "chainJson" = EXCLUDED."chainJson",
           "version" = EXCLUDED."version",
           "updatedAt" = EXCLUDED."updatedAt",
           "updatedByDecisionId" = EXCLUDED."updatedByDecisionId"''',
      parameters: QueryParameters.named({
        'role': policy.role.wire,
        'chainJson': jsonEncode(policy.chain.map((s) => s.toJson()).toList()),
        'version': policy.version,
        'updatedAt': policy.updatedAt.toUtc(),
        'updatedByDecisionId': policy.updatedByDecisionId,
      }),
    );
  }

  @override
  Future<List<ModelPolicy>> getAllPolicies() async {
    final rows = await _db.query('SELECT * FROM "model_policy"');
    return rows.map(_fromRow).toList();
  }

  ModelPolicy _fromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return ModelPolicy(
      role: AgentRole.fromWire(m['role'] as String),
      chain: (jsonDecode(m['chainJson'] as String) as List)
          .map((e) => ModelStep.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      version: m['version'] as int,
      updatedAt: decodeUtc(m['updatedAt'])!,
      updatedByDecisionId: m['updatedByDecisionId'] as String,
    );
  }
}

/// Exception thrown when a model policy is not found.
class ModelPolicyNotFoundException implements Exception {
  ModelPolicyNotFoundException(this.role);

  final AgentRole role;

  @override
  String toString() => 'Model policy not found for role: ${role.wire}';
}
