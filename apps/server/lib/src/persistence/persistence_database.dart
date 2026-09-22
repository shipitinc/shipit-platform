import 'dart:convert';

import 'package:serverpod/database.dart';

/// Session-scoped wrapper around a Serverpod [Database] used by the PostgreSQL
/// control-plane stores.
///
/// A store instance is owned by exactly one logical caller (a session), so a
/// single active transaction slot is safe. Calls made while a transaction is
/// active automatically attach to it; calls made outside a transaction go to
/// the database directly.
class PersistenceDatabase {
  PersistenceDatabase(this._db);

  final Database _db;
  Transaction? _activeTransaction;

  Database get db => _db;

  bool get hasActiveTransaction => _activeTransaction != null;

  /// Runs [body] inside a single database transaction.
  ///
  /// Throws [StateError] if a transaction is already active on this store
  /// (nested transactions are not supported and indicate a design error).
  Future<T> inTransaction<T>(Future<T> Function() body) async {
    if (hasActiveTransaction) {
      throw StateError('A transaction is already active on this store.');
    }
    return _db.transaction((transaction) async {
      _activeTransaction = transaction;
      try {
        return await body();
      } finally {
        _activeTransaction = null;
      }
    });
  }

  /// Runs [sql] outside the wrapper, never inside the active transaction.
  Future<DatabaseResult> queryNoTransaction(String sql) {
    return _db.unsafeQuery(sql);
  }

  Future<DatabaseResult> query(
    String sql, {
    QueryParameters? parameters,
  }) {
    return _db.unsafeQuery(
      sql,
      transaction: _activeTransaction,
      parameters: parameters,
    );
  }

  Future<int> execute(
    String sql, {
    QueryParameters? parameters,
  }) {
    return _db.unsafeExecute(
      sql,
      transaction: _activeTransaction,
      parameters: parameters,
    );
  }

  static String encodeJson(Object? value) =>
      value == null ? '' : jsonEncode(value);

  static T? decodeJson<T>(String? value, T Function(Object? decoded) fromJson) {
    if (value == null || value.isEmpty) return null;
    return fromJson(jsonDecode(value));
  }

  static DateTime? toUtc(DateTime? value) => value?.toUtc();
}
