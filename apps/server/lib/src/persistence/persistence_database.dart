import 'dart:async';
import 'dart:convert';

import 'package:serverpod/database.dart';

/// Session-scoped wrapper around a Serverpod [Database] used by the PostgreSQL
/// control-plane stores.
///
/// ## The active transaction belongs to the CALLER, not to this wrapper
///
/// [inTransaction] binds the transaction it opens as a [Zone] value keyed on
/// THIS instance and runs the body inside that zone. Every [query]/[execute]
/// issued from the body's asynchronous context — including everything it
/// awaits — resolves the binding and attaches to the transaction; code
/// running in a different logical context sees no binding and goes straight
/// to the pool.
///
/// That is the fix for F-238. The instance field this replaced answered the
/// wrong question under detached dispatch (F-237): it could only say "is SOME
/// caller's transaction open", never "is the CALLER'S transaction open". Both
/// failure shapes were observed live on QA:
///
///  * a second logical writer's `inTransaction` collided with an in-flight
///    one — `StateError` where the slot was already set, or silent cross-
///    attachment where the second caller's writes were routed through the
///    first caller's `Transaction`;
///  * a plain [query] issued concurrently with somebody else's open
///    transaction attached to THAT transaction and died with
///    `DatabaseQueryException: Session or transaction has already finished`
///    the moment the commit landed mid-query (live sites:
///    `PostgresJobStore.listJobs`, `design.tick`, `implementation.tick`,
///    `redriveSettledReviews`).
///
/// Neither wiring-level remedy was structurally sufficient. One wrapper per
/// STORE cannot separate two logical callers sharing one store object — the
/// five `LocalWorker`s hold a single `PostgresWorkerStore`, and per-run
/// wrappers would have to be minted inside `worker_runtime`, outside this
/// layer. Serializing `inTransaction` with a lock cannot stop an outsider's
/// [query] attaching to the open transaction either: the outsider cannot be
/// told apart from the transaction's owner by an instance slot — that
/// distinction is exactly what the zone binding is.
///
/// Because the binding follows the caller, the composition root keeps ONE
/// wrapper shared by every store: concurrent `inTransaction` calls each open
/// their own transaction on their own pooled connection
/// (`pg.Pool.runTx` runs them concurrently), and each caller's statements
/// attach to its own. A nested `inTransaction` in the SAME context is still
/// refused with [StateError]; a transaction open on a DIFFERENT wrapper over
/// the same [Database] is invisible here — the same scoping the per-instance
/// slot gave.
///
/// One deliberate consequence, stated rather than implied: asynchronous work
/// that escapes the body's context — a timer callback or a fire-and-forget
/// future spawned inside the body that outlives it — keeps the binding and
/// attaches to a transaction that has already finished. That is the binding
/// telling the truth: work outside the body's await chain was never inside
/// the transaction's commit boundary, and under the old slot it merely lost
/// the race less loudly.
class PersistenceDatabase {
  PersistenceDatabase(this._db);

  final Database _db;

  Database get db => _db;

  /// The transaction the CALLING asynchronous context is inside, or null.
  ///
  /// Bound by [inTransaction] as a zone value keyed on this instance, so the
  /// lookup follows the logical caller rather than the wrapper.
  Transaction? get _activeTransaction => Zone.current[this] as Transaction?;

  bool get hasActiveTransaction => _activeTransaction != null;

  /// Runs [body] inside a single database transaction.
  ///
  /// Throws [StateError] if the calling context is already inside a
  /// transaction on this wrapper (nested transactions are not supported and
  /// indicate a design error). A transaction in flight on ANOTHER logical
  /// caller does not block this call: it opens its own transaction on its
  /// own pooled connection and the two commit or roll back independently.
  Future<T> inTransaction<T>(Future<T> Function() body) async {
    if (hasActiveTransaction) {
      throw StateError('A transaction is already active on this store.');
    }
    return _db.transaction(
      (transaction) => runZoned(body, zoneValues: {this: transaction}),
    );
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
