/// F-238 — `PersistenceDatabase`'s transaction binding must follow the
/// LOGICAL CALLER, not the wrapper instance.
///
/// The wrapper used to keep one `_activeTransaction` field: a single slot
/// every caller of a shared wrapper read. Under detached dispatch (F-237)
/// that answered the wrong question — it could only say "is SOME caller's
/// transaction open", never "is the CALLER'S transaction open" — and both
/// failure shapes were observed live on QA:
///
///  * a second `inTransaction` (a detached run's commit, or a tick's own tx)
///    colliding with an in-flight one — `StateError` where the slot was set,
///    or silent cross-attachment where the second caller's writes rode the
///    first caller's `Transaction`;
///  * a plain `query` issued concurrently with somebody else's open
///    transaction attaching to it and dying with
///    `DatabaseQueryException: Session or transaction has already finished`
///    the moment the commit landed mid-query (`PostgresJobStore.listJobs`,
///    `design.tick`, `implementation.tick`, `redriveSettledReviews`).
///
/// The fix binds the open transaction as a zone value keyed on the wrapper:
/// `inTransaction` runs its body inside that zone, so attachment is a
/// property of the caller's async context. One shared wrapper then serves
/// every logical caller correctly — concurrent `inTransaction` calls open
/// their own transactions on their own pooled connections.
///
/// ## What is and is not verified here
///
/// **No PostgreSQL was involved in any test below.** `_PoolBackedDatabase`
/// is a statement-level double that models the two driver facts this fix
/// relies on: each `transaction()` call gets its own `TxSession` (a pool
/// supports concurrent transactions), and a statement that arrives on a
/// FINISHED transaction dies with
/// "Session or transaction has already finished". What IS verified: which
/// transaction — if any — each statement was handed, that concurrent
/// logical writers on ONE shared wrapper no longer collide, that a poll
/// crossing a commit survives, and that the preserved contracts (attach
/// inside the body, nested refusal, rollback, cross-wrapper isolation) all
/// hold. What is NOT verified: real pool behaviour, real advisory-lock
/// semantics — those are integration-tier facts for `make test-integration`.
library;

import 'dart:async';
import 'dart:collection';

import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_job_store.dart';
import 'package:serverpod/database.dart';
import 'package:test/test.dart';

void main() {
  group('F-238: the transaction binding follows the caller', () {
    test(
      'two concurrent inTransaction calls on ONE shared wrapper each '
      'commit independently — detached-run commit racing a tick',
      () async {
        final db = _PoolBackedDatabase();
        final pdb = PersistenceDatabase(db);

        final holdA = Completer<void>();
        final aOpened = Completer<void>();
        // "The tick": opens a transaction and holds it.
        final txA = pdb.inTransaction(() async {
          aOpened.complete();
          await holdA.future;
          await pdb.execute('A-STATEMENT');
          return 'A';
        });
        await aOpened.future;

        // "The detached run's commit": a second inTransaction on the SAME
        // wrapper while A is in flight. Under the slot this was StateError;
        // under the binding it opens its own pooled transaction.
        final resultB = await pdb.inTransaction(() async {
          await pdb.execute('B-STATEMENT');
          return 'B';
        });
        expect(resultB, 'B');

        holdA.complete();
        expect(await txA, 'A');

        expect(db.transactions, hasLength(2));
        expect(
          db.statement('A-STATEMENT').transaction,
          same(db.transactions[0]),
          reason: "A's writes attach to A's transaction",
        );
        expect(
          db.statement('B-STATEMENT').transaction,
          same(db.transactions[1]),
          reason:
              "B's writes attach to B's transaction — not through A's open "
              'slot, which is the cross-attachment the slot allowed',
        );
      },
    );

    test(
      'a query issued while another caller\'s transaction is open attaches '
      'to NOTHING — the listJobs site',
      () async {
        final db = _PoolBackedDatabase();
        final pdb = PersistenceDatabase(db);

        final holdA = Completer<void>();
        final aOpened = Completer<void>();
        final txA = pdb.inTransaction(() async {
          aOpened.complete();
          await holdA.future;
          return 'A';
        });
        await aOpened.future;

        // `redriveSettledReviews -> PostgresJobStore.listJobs` reaching
        // across a detached commit. From THIS context there is no binding,
        // so the statement must go straight to the pool.
        expect(
          pdb.hasActiveTransaction,
          isFalse,
          reason:
              'this caller has no transaction — only the other context does',
        );
        await pdb.query('SELECT * FROM "job" ORDER BY "createdAt" ASC');
        expect(
          db.statements.last.transaction,
          isNull,
          reason:
              'an outsider statement must not enter another caller\'s '
              'transaction — that attachment is what died mid-commit on QA',
        );

        holdA.complete();
        expect(await txA, 'A');
      },
    );

    test(
      'a poll in flight while another caller\'s transaction commits does '
      'not die — the harness collision, mirrored',
      () async {
        final db = _PoolBackedDatabase();
        final pdb = PersistenceDatabase(db);

        final holdA = Completer<void>();
        final aOpened = Completer<void>();
        // The statement round-trip window: the poll waits here while the
        // other caller's transaction commits underneath it.
        db.gate = Completer<void>();

        final txA = pdb.inTransaction(() async {
          aOpened.complete();
          await holdA.future;
          return 'A';
        });
        await aOpened.future;

        // The poll is issued while A's transaction is open and resolves
        // only after A has committed — the exact interleaving that produced
        // "Session or transaction has already finished" in the harness.
        final poll = pdb.query('SELECT * FROM "job" ORDER BY "createdAt" ASC');
        await pumpEventQueue();
        expect(
          db.pendingStatements,
          1,
          reason: 'the poll must be in flight before A commits',
        );

        holdA.complete();
        await txA;
        db.gate!.complete();
        // Under the slot this threw _SessionFinishedException, because the
        // poll had attached to A's transaction. Under the binding it
        // carried no transaction and survives.
        await poll;
      },
    );

    test(
      'statements inside a transaction body still attach to that '
      'transaction, and the binding ends with it',
      () async {
        final db = _PoolBackedDatabase();
        final pdb = PersistenceDatabase(db);

        await pdb.inTransaction(() async {
          expect(pdb.hasActiveTransaction, isTrue);
          await pdb.execute('INSIDE-STATEMENT');
        });

        expect(db.transactions, hasLength(1));
        expect(
          db.statement('INSIDE-STATEMENT').transaction,
          same(db.transactions.single),
          reason: 'per-caller transaction semantics are unchanged',
        );
        expect(pdb.hasActiveTransaction, isFalse);
      },
    );

    test(
      'nested inTransaction in the SAME context is still refused with '
      'StateError',
      () async {
        final pdb = PersistenceDatabase(_PoolBackedDatabase());
        await pdb.inTransaction(() async {
          await expectLater(
            pdb.inTransaction(() async {}),
            throwsStateError,
            reason:
                'nesting still indicates a design error; the refusal is '
                'part of the contract, not part of the defect',
          );
        });
      },
    );

    test(
      'a body that throws rolls back and propagates; the binding does not '
      'leak',
      () async {
        final db = _PoolBackedDatabase();
        final pdb = PersistenceDatabase(db);

        await expectLater(
          pdb.inTransaction(() async {
            await pdb.execute('DOOMED-STATEMENT');
            throw StateError('the claim failed');
          }),
          throwsStateError,
        );

        expect(db.transactions.single.rolledBack, isTrue);
        expect(db.transactions.single.finished, isTrue);
        expect(pdb.hasActiveTransaction, isFalse);
      },
    );

    test(
      'a query through a DIFFERENT wrapper over the same Database stays '
      'outside the transaction — per-wrapper scoping preserved',
      () async {
        final db = _PoolBackedDatabase();
        final pdbA = PersistenceDatabase(db);
        final pdbB = PersistenceDatabase(db);

        await pdbA.inTransaction(() async {
          await pdbB.query('SELECT * FROM "job"');
        });

        expect(
          db.statements.last.transaction,
          isNull,
          reason:
              'a store built on a different wrapper was never inside this '
              'transaction under the slot either — the per-instance scope '
              'is preserved, not widened',
        );
      },
    );

    test(
      'two concurrent inTransaction calls on ONE shared PostgresJobStore '
      'complete — the shared-store case per-store wrappers cannot fix',
      () async {
        final db = _PoolBackedDatabase();
        final store = PostgresJobStore(PersistenceDatabase(db));

        final holdA = Completer<void>();
        final aOpened = Completer<void>();
        // The five LocalWorkers share one PostgresWorkerStore in
        // production; a detached continuation and a tick reach the same
        // store object. One wrapper per store cannot separate them — only
        // a binding that follows the caller can.
        final txA = store.inTransaction((tx) async {
          aOpened.complete();
          await holdA.future;
          await tx.readJob('job-a');
          return 'A';
        });
        await aOpened.future;

        final resultB = await store.inTransaction((tx) async {
          await tx.readJob('job-b');
          return 'B';
        });
        expect(resultB, 'B');

        holdA.complete();
        expect(await txA, 'A');

        final aStatement = db.statements.firstWhere(
          (s) => s.parameters?['jobId'] == 'job-a',
        );
        final bStatement = db.statements.firstWhere(
          (s) => s.parameters?['jobId'] == 'job-b',
        );
        expect(aStatement.transaction, same(db.transactions[0]));
        expect(bStatement.transaction, same(db.transactions[1]));
      },
    );

    test(
      'inCapacityLockedTransaction takes the advisory lock on its OWN '
      'transaction while another is in flight',
      () async {
        final db = _PoolBackedDatabase();
        final store = PostgresJobStore(PersistenceDatabase(db));

        final holdA = Completer<void>();
        final aOpened = Completer<void>();
        final other = store.inTransaction((tx) async {
          aOpened.complete();
          await holdA.future;
          return 0;
        });
        await aOpened.future;

        final claimed = await store.inCapacityLockedTransaction(42, (
          tx,
        ) async {
          await tx.readJob('job-1');
          return 'claimed';
        });
        expect(claimed, 'claimed');

        final lock = db.statements.firstWhere(
          (s) => s.sql.contains('pg_advisory_xact_lock'),
        );
        expect(
          lock.transaction,
          same(db.transactions[1]),
          reason:
              'the capacity lock must be taken on the transaction that '
              'holds it — under the slot it would have ridden the OTHER '
              'caller\'s transaction and released at the wrong commit',
        );

        holdA.complete();
        await other;
      },
    );
  });
}

/// A statement the double saw, and the `Transaction` it was handed — the
/// whole observable surface this suite asserts on.
class _RecordedStatement {
  _RecordedStatement(this.sql, {this.parameters, this.transaction});

  final String sql;
  final Map<String, Object?>? parameters;
  final Transaction? transaction;
}

/// What the postgres driver throws when a statement lands on a finished
/// `TxSession` — the production failure text, mirrored.
class _SessionFinishedException implements Exception {
  const _SessionFinishedException();

  @override
  String toString() =>
      'DatabaseQueryException: Session or transaction has already finished, '
      'did you forget to await a statement?';
}

/// Present so [PersistenceDatabase.inTransaction] has a `Transaction` to
/// bind. `finished` models `TxSession` end: any statement issued on it
/// after this point dies, exactly as the real driver's does.
class _FakeTransaction implements Transaction {
  bool finished = false;
  bool rolledBack = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A [Database] that models pooled-connection semantics instead of
/// executing SQL.
///
/// `Database` has a private constructor, so this implements the interface
/// and forwards every member it does not care about to `noSuchMethod`. The
/// two facts it models are the two the fix relies on: every `transaction()`
/// call produces an INDEPENDENT `TxSession` (a `pg.Pool` runs them
/// concurrently), and a statement issued on a finished `TxSession` throws —
/// the `_SessionFinishedException` mirror of the production crash.
class _PoolBackedDatabase implements Database {
  final List<_RecordedStatement> statements = <_RecordedStatement>[];
  final List<_FakeTransaction> transactions = <_FakeTransaction>[];

  /// A gate every statement waits on before it is evaluated — the
  /// round-trip window in which a commit can land mid-statement. Tests set
  /// it when they need a statement to be provably in flight across a commit.
  Completer<void>? gate;

  /// Statements currently parked on [gate].
  int pendingStatements = 0;

  _RecordedStatement statement(String sql) =>
      statements.firstWhere((s) => s.sql == sql);

  Future<T> _run<T>(
    String sql,
    QueryParameters? parameters,
    Transaction? transaction,
    T result,
  ) async {
    final tx = transaction;
    if (tx is _FakeTransaction && tx.finished) {
      throw const _SessionFinishedException();
    }
    final gate = this.gate;
    if (gate != null) {
      pendingStatements++;
      try {
        await gate.future;
      } finally {
        pendingStatements--;
      }
      // The commit landed while this statement was on the wire.
      if (tx is _FakeTransaction && tx.finished) {
        throw const _SessionFinishedException();
      }
    }
    statements.add(
      _RecordedStatement(
        sql,
        parameters: parameters?.parameters as Map<String, Object?>?,
        transaction: tx,
      ),
    );
    return result;
  }

  @override
  Future<R> transaction<R>(
    Future<R> Function(Transaction) transactionFn, {
    TransactionSettings? settings,
  }) async {
    final tx = _FakeTransaction();
    transactions.add(tx);
    try {
      return await transactionFn(tx);
    } catch (_) {
      tx.rolledBack = true;
      rethrow;
    } finally {
      tx.finished = true;
    }
  }

  @override
  Future<DatabaseResult> unsafeQuery(
    String query, {
    int? timeoutInSeconds,
    Transaction? transaction,
    QueryParameters? parameters,
  }) => _run(query, parameters, transaction, _EmptyResult());

  @override
  Future<int> unsafeExecute(
    String query, {
    int? timeoutInSeconds,
    Transaction? transaction,
    QueryParameters? parameters,
  }) => _run(query, parameters, transaction, 0);

  /// Everything this double does not care about — the typed find/insert/
  /// update helpers no store in this file uses.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `unsafeQuery` must return something; every statement this double sees
/// returns no rows.
class _EmptyResult extends UnmodifiableListView<DatabaseResultRow>
    implements DatabaseResult {
  _EmptyResult() : super(const <DatabaseResultRow>[]);

  @override
  int get affectedRowCount => 0;

  @override
  DatabaseResultSchema get schema =>
      throw StateError('the double never parses a row description');
}
