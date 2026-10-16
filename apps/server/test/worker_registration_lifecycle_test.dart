/// The durable worker-registration lifecycle: what writes a worker into the
/// table the operator surface reads, and what proves it stays honest.
///
/// ## WHAT THIS FILE COVERS
///
/// 1. **Registration appears on start.** Every worker in the fleet has a row
///    before `start()` returns — not on the first tick, which is the distinction
///    that matters. The defect this file exists for was a fleet that dispatched
///    work correctly while `workerEndpoints.listWorkers` returned `[]`, so an
///    operator reading "0 of 0 machines busy" was told the work was waiting on
///    a machine shortage that did not exist.
/// 2. **The heartbeat refreshes.** A second pass advances `lastHeartbeat`, which
///    is what keeps a healthy worker from being swept.
/// 3. **A worker that stops heartbeating goes STALE, not absent and not
///    "available".** The existing vocabulary is reused: `WorkerStatus.offline`,
///    the member whose `isAvailable`/`isAcquirable` already mean "not
///    available". No parallel `stale` status is introduced.
/// 4. **The sweep does not resurrect the worker it just condemned.** The
///    rewritten row KEEPS its original `lastHeartbeat`; writing `now` would
///    refresh the very timestamp staleness is reasoned from.
/// 5. **Shutdown is bounded and leaves nothing running.** `stop()` returns
///    within a stated bound even while a write is wedged, cancels the one timer
///    this lifecycle creates, and marks the fleet offline rather than deleting
///    it.
/// 6. **The production composition is PINNED, not merely correct today.** The
///    assertions read `lib/server.dart` as text and fail if a `LocalWorker(` is
///    constructed without `registrationStore:`, because that is precisely how
///    this defect shipped: the store was in scope, wired to nothing, and the
///    type system had no opinion.
///
/// ## WHAT THIS FILE DOES NOT COVER, STATED PLAINLY
///
/// **No PostgreSQL was involved in any test below**, so UNVERIFIED here:
///
///  * that `PostgresWorkerRegistrationStore.registerWorker`'s
///    `ON CONFLICT ("workerId") DO UPDATE` really refreshes `status`,
///    `currentLoad` and `lastHeartbeat` on a second call — the in-memory store
///    used here is a whole-map assignment, which is idempotent in a way the SQL
///    may not be;
///  * that the `worker_registration` table exists with the columns both stores
///    name. The sweep depends on `lastHeartbeat` being persisted as an instant
///    the sweeper's clock can compare;
///  * anything about the live QA stack. Docker is out of bounds for this lane,
///    and no endpoint was called over a real transport.
///
/// What IS verified without a database: the lifecycle's ordering, its bounds,
/// its staleness rule, and — for the production path — that every worker the
/// composition builds names the registration store and starts through the same
/// named seam this file calls.
library;

import 'dart:async';
import 'dart:io' show File;
import 'dart:isolate' show Isolate;

import 'package:control_plane_server/server.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';

void main() {
  group('start — the fleet is in the table before start() returns', () {
    test(
      'every worker has a registration row the moment start() completes',
      () async {
        final store = InMemoryWorkerRegistrationStore();
        final workers = [
          _worker('w-triage-local', store),
          _worker('w-review-local', store),
          _worker('w-impl-local', store),
        ];
        final heartbeat = WorkerRegistrationHeartbeat(
          workers: workers,
          store: store,
          // No timer work is needed to assert this, and a short interval keeps
          // the test's own runtime honest about what it is waiting for.
          interval: const Duration(milliseconds: 20),
          writeTimeout: const Duration(seconds: 5),
        );

        // Before start: the defect's exact shape. Three real workers exist and
        // the durable table is empty, so `listWorkers` reads [].
        expect(await store.listWorkers(), isEmpty);

        final report = await heartbeat.start();
        addTearDown(heartbeat.stop);

        expect(
          (await store.listWorkers()).map((w) => w.workerId).toSet(),
          {'w-triage-local', 'w-review-local', 'w-impl-local'},
          reason: 'listWorkers must return the real fleet, not []',
        );
        expect(report.isComplete, isTrue);
        expect(report.failures, isEmpty);
        expect(report.registeredWorkerIds, hasLength(3));
        // The rows must describe the workers, not merely exist: an
        // unregistered fleet and a registered fleet of blank rows look the same
        // to a count.
        final triage = await store.readWorker('w-triage-local');
        expect(triage, isNotNull);
        expect(triage!.poolId, 'test-pool');
        expect(triage.capabilities.keys, contains(WorkerCapability.linux));
        expect(triage.maxConcurrency, 1);
        expect(triage.platform, 'test-platform');
      },
    );

    test(
      'a registration that fails is reported, not thrown, and never skipped '
      'silently',
      () async {
        final store = InMemoryWorkerRegistrationStore();
        final workers = [
          _worker('w-good', store),
          _worker('w-bad', _RefusingStore()),
        ];
        final heartbeat = WorkerRegistrationHeartbeat(
          workers: workers,
          store: store,
          interval: const Duration(milliseconds: 20),
        );

        final report = await heartbeat.start();
        addTearDown(heartbeat.stop);

        expect(
          report.registeredWorkerIds,
          ['w-good'],
          reason: 'the worker that could be written is still written',
        );
        expect(report.failures.keys, ['w-bad']);
        expect(report.isComplete, isFalse);
        // The failure must be visible to whoever asked, not only logged.
        expect(report.describe()['failed'], contains('w-bad'));
      },
    );

    test(
      'a fleet containing a worker with no registrationStore is refused',
      () async {
        // Silently skipping it would reintroduce the exact defect this file
        // exists to close, in the shape of a green build.
        final store = InMemoryWorkerRegistrationStore();
        final workers = [
          _worker('w-ok', store),
          _worker('w-unregistered', null),
        ];

        expect(
          () => WorkerRegistrationHeartbeat(workers: workers, store: store),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('w-unregistered'),
            ),
          ),
        );
      },
    );

    test('a fleet of zero workers is refused', () {
      expect(
        () => WorkerRegistrationHeartbeat(
          workers: const [],
          store: InMemoryWorkerRegistrationStore(),
        ),
        throwsA(isA<StateError>()),
        reason: 'an empty fleet is the defect, not a configuration',
      );
    });
  });

  group('heartbeat — a live worker stays live', () {
    test('a second pass advances lastHeartbeat', () async {
      final store = InMemoryWorkerRegistrationStore();
      final clock = _MutableClock(DateTime.utc(2026, 10, 15, 12));
      final worker = _worker('w-1', store, clock: clock.read);
      final heartbeat = WorkerRegistrationHeartbeat(
        workers: [worker],
        store: store,
        interval: const Duration(milliseconds: 20),
        staleAfter: const Duration(minutes: 2),
        clock: clock.read,
      );

      await heartbeat.start();
      addTearDown(heartbeat.stop);

      final first = (await store.readWorker('w-1'))!.lastHeartbeat;
      expect(first, clock.now);

      clock.advance(const Duration(seconds: 15));
      await heartbeat.tick();

      final second = (await store.readWorker('w-1'))!.lastHeartbeat;
      expect(second, clock.now);
      expect(
        second.isAfter(first),
        isTrue,
        reason:
            'a refresh that does not move the heartbeat is a no-op, and a '
            'no-op heartbeat is indistinguishable from a dead worker',
      );
    });

    test(
      'the periodic timer keeps refreshing without being told to',
      () async {
        final store = _SlowStore(
          delay: Duration.zero,
          inner: InMemoryWorkerRegistrationStore(),
        );
        final worker = _worker('w-1', store);
        final heartbeat = WorkerRegistrationHeartbeat(
          workers: [worker],
          store: store,
          interval: const Duration(milliseconds: 10),
        );

        await heartbeat.start();
        addTearDown(heartbeat.stop);
        expect(heartbeat.isRunning, isTrue);

        final before = store.writeCount;
        await _eventually(
          () => store.writeCount > before,
          reason: 'the periodic heartbeat must write on its own',
        );
      },
    );

    test(
      'a slow store makes passes SKIP, never queue — the pile-up this exists '
      'to prevent',
      () async {
        final events = <String>[];
        final store = _SlowStore(
          delay: const Duration(milliseconds: 120),
          inner: InMemoryWorkerRegistrationStore(),
        );
        final heartbeat = WorkerRegistrationHeartbeat(
          workers: [_worker('w-1', store)],
          store: store,
          // Far shorter than one pass takes, so overlap is guaranteed rather
          // than hoped for.
          interval: const Duration(milliseconds: 10),
          writeTimeout: const Duration(seconds: 5),
          log: (event, fields) => events.add(event),
        );

        await heartbeat.start();
        addTearDown(heartbeat.stop);
        // Several passes have been attempted while one is still running. The
        // property is the PEAK concurrency, not an end state: a guard that let
        // two overlap for a moment and then re-converged would look perfect to
        // an end-state assertion.
        await _eventually(
          () => store.writeCount > 2,
          reason: 'several heartbeat attempts must have been made',
        );
        expect(
          store.maxConcurrentWrites,
          1,
          reason: 'the single-flight guard must cap concurrent writes at one',
        );
        expect(
          events,
          contains('worker.registration.tick.skipped'),
          reason:
              'the skips must be REPORTED, not merely counted — a dropped '
              'pass that nobody can see is indistinguishable from a heartbeat '
              'that was never due',
        );
      },
    );
  });

  group('staleness — silence is visible, and it reuses the existing vocabulary', () {
    test(
      'a row older than staleAfter becomes offline, and is not deleted',
      () async {
        final store = InMemoryWorkerRegistrationStore();
        final clock = _MutableClock(DateTime.utc(2026, 10, 15, 12));
        final heartbeat = WorkerRegistrationHeartbeat(
          workers: [_worker('w-1', store, clock: clock.read)],
          store: store,
          interval: const Duration(milliseconds: 20),
          staleAfter: const Duration(minutes: 2),
          clock: clock.read,
        );
        await heartbeat.start();
        addTearDown(heartbeat.stop);

        final silent = await store.readWorker('w-1');
        expect(silent!.status, WorkerStatus.idle);

        // Its host has been unreachable for longer than the bound. The worker
        // cannot say so — the process that would write it died with it.
        clock.advance(const Duration(minutes: 5));
        final condemned = await heartbeat.sweep();

        expect(condemned, ['w-1']);
        final row = (await store.readWorker('w-1'))!;
        expect(row.status, WorkerStatus.offline);
        expect(row.isAvailable, isFalse);
        expect(row.isAcquirable, isFalse);
      },
    );

    test(
      'the condemned row KEEPS its original heartbeat, so the age on screen is '
      'the age that happened',
      () async {
        final store = InMemoryWorkerRegistrationStore();
        final clock = _MutableClock(DateTime.utc(2026, 10, 15, 12));
        final heartbeat = WorkerRegistrationHeartbeat(
          workers: [_worker('w-1', store, clock: clock.read)],
          store: store,
          interval: const Duration(milliseconds: 20),
          staleAfter: const Duration(minutes: 2),
          clock: clock.read,
        );
        await heartbeat.start();
        addTearDown(heartbeat.stop);
        final original = (await store.readWorker('w-1'))!.lastHeartbeat;

        clock.advance(const Duration(minutes: 5));
        await heartbeat.sweep();

        expect(
          (await store.readWorker('w-1'))!.lastHeartbeat,
          original,
          reason:
              'refreshing the timestamp here would make a dead worker look '
              'healthy again on the very next pass',
        );
      },
    );

    test(
      'a worker this process owns is refreshed BEFORE the sweep runs, so it can '
      'never be condemned by its own tick',
      () async {
        final store = InMemoryWorkerRegistrationStore();
        final clock = _MutableClock(DateTime.utc(2026, 10, 15, 12));
        final heartbeat = WorkerRegistrationHeartbeat(
          workers: [_worker('w-1', store, clock: clock.read)],
          store: store,
          interval: const Duration(milliseconds: 20),
          // The interval is far longer than the bound: if the refresh ran after
          // the sweep, or not at all, this worker would be swept every pass.
          staleAfter: const Duration(seconds: 1),
          clock: clock.read,
        );

        await heartbeat.start();
        addTearDown(heartbeat.stop);
        clock.advance(const Duration(seconds: 30));
        await heartbeat.tick();

        expect(
          (await store.readWorker('w-1'))!.status,
          WorkerStatus.idle,
          reason:
              'refresh-then-sweep ordering is what keeps a live worker live',
        );
      },
    );

    test(
      'a row stamped in the future is clock skew, not death, and is left alone',
      () async {
        final store = InMemoryWorkerRegistrationStore();
        final clock = _MutableClock(DateTime.utc(2026, 10, 15, 12));
        final heartbeat = WorkerRegistrationHeartbeat(
          workers: [_worker('w-live', store, clock: clock.read)],
          store: store,
          interval: const Duration(milliseconds: 20),
          staleAfter: const Duration(minutes: 2),
          clock: clock.read,
        );
        await heartbeat.start();
        addTearDown(heartbeat.stop);

        // Another host's clock is an hour fast. Treating that as death would
        // report a healthy fleet as empty of available machines.
        final ahead = DateTime.utc(2026, 10, 15, 13);
        await store.registerWorker(
          WorkerRegistration(
            workerId: 'w-skewed',
            poolId: 'p',
            capabilities: const {},
            status: WorkerStatus.idle,
            currentLoad: 0,
            maxConcurrency: 1,
            lastHeartbeat: ahead,
          ),
        );

        expect(await heartbeat.sweep(), isEmpty);
        expect((await store.readWorker('w-skewed'))!.status, WorkerStatus.idle);
        expect((await store.readWorker('w-skewed'))!.lastHeartbeat, ahead);
      },
    );
  });

  group('shutdown — bounded, complete, and nothing left running', () {
    test(
      'stop() cancels the one timer this lifecycle creates',
      () async {
        final store = _SlowStore(
          delay: Duration.zero,
          inner: InMemoryWorkerRegistrationStore(),
        );
        final heartbeat = WorkerRegistrationHeartbeat(
          workers: [_worker('w-1', store)],
          store: store,
          interval: const Duration(milliseconds: 10),
        );
        await heartbeat.start();
        expect(heartbeat.isRunning, isTrue);

        await heartbeat.stop();

        expect(heartbeat.isRunning, isFalse);
        final afterStop = store.writeCount;
        // Several whole intervals. A surviving timer would write here.
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(
          store.writeCount,
          afterStop,
          reason: 'no heartbeat may outlive stop()',
        );
      },
    );

    test(
      'stop() marks the fleet offline rather than deleting it',
      () async {
        final store = InMemoryWorkerRegistrationStore();
        final heartbeat = WorkerRegistrationHeartbeat(
          workers: [_worker('w-1', store), _worker('w-2', store)],
          store: store,
          interval: const Duration(milliseconds: 10),
        );
        await heartbeat.start();

        await heartbeat.stop();

        final rows = await store.listWorkers();
        expect(
          rows,
          hasLength(2),
          reason: 'deleting would report a zero fleet',
        );
        expect(rows.map((r) => r.status), everyElement(WorkerStatus.offline));
        expect(rows.map((r) => r.isAvailable), everyElement(isFalse));
      },
    );

    test(
      'stop() RETURNS even while a pass is still writing, and abandons it '
      'explicitly',
      () async {
        final abandoned = <String>[];
        // Three workers against a store that never answers: one pass costs
        // three write timeouts, so the pass in flight genuinely outlives the
        // single timeout `stop()` is willing to wait for. That is the only way
        // this state is reachable, and it is reachable by construction rather
        // than by contrivance.
        final store = _SilentStore();
        final heartbeat = WorkerRegistrationHeartbeat(
          workers: [
            _worker('w-1', store),
            _worker('w-2', store),
            _worker('w-3', store),
          ],
          store: store,
          interval: const Duration(milliseconds: 10),
          writeTimeout: const Duration(milliseconds: 60),
          log: (event, fields) => abandoned.add(event),
        );
        await heartbeat.start();

        final inFlight = heartbeat.tick();

        final stopwatch = Stopwatch()..start();
        await heartbeat.stop();
        stopwatch.stop();

        expect(
          stopwatch.elapsed,
          lessThan(const Duration(seconds: 5)),
          reason:
              'a pass whose writes never complete must not hold shutdown '
              'open',
        );
        expect(heartbeat.isRunning, isFalse);
        expect(
          abandoned,
          contains('worker.registration.stop.inflight_abandoned'),
          reason:
              'abandoning a pass that will not finish is reported, never '
              'done silently',
        );
        // Unawaited on purpose: this pass is still running when `stop()`
        // returned. Letting it outlive the test would leak an asynchronous
        // error into the NEXT test, so it is drained here and nowhere else.
        await inFlight;
      },
    );

    test(
      'stop() is idempotent, so two callers cannot wedge each other',
      () async {
        final store = InMemoryWorkerRegistrationStore();
        final heartbeat = WorkerRegistrationHeartbeat(
          workers: [_worker('w-1', store)],
          store: store,
          interval: const Duration(milliseconds: 10),
        );
        await heartbeat.start();

        await heartbeat.stop();
        await heartbeat.stop();

        expect(heartbeat.isRunning, isFalse);
      },
    );
  });

  group('the production composition is pinned, not merely correct today', () {
    test(
      'every LocalWorker the server builds names a registration store',
      () async {
        final source = await _serverSource();
        final constructions = RegExp(
          r'LocalWorker\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*\)',
          dotAll: true,
        ).allMatches(source).toList();
        expect(
          constructions.length,
          greaterThanOrEqualTo(3),
          reason:
              'expected the three production workers; a change here must be '
              'a deliberate edit to this file',
        );
        for (final match in constructions) {
          expect(
            match.group(0),
            contains('registrationStore:'),
            reason:
                'a LocalWorker constructed without a registrationStore is a '
                'worker the operator surface cannot see — which is the defect '
                'this file exists to catch: '
                '${match.group(0)?.split('\n').first}',
          );
        }
      },
    );

    test(
      'the registration store the workers are given is the one the endpoints '
      'read',
      () async {
        final source = await _serverSource();
        expect(
          source,
          contains('PostgresWorkerRegistrationStore(db)'),
          reason: 'the durable fleet view and the workers must share one store',
        );
        expect(
          source,
          contains('startWorkerRegistrationHeartbeat('),
          reason: 'the lifecycle must start through the seam this file calls',
        );
      },
    );

    test(
      'the production seam registers a fleet without a server, a database or an '
      'opencode binary',
      () async {
        // This is the function `run()` calls. Exercising it here means the test
        // drives the production composition, not a hand-built copy of it.
        final store = InMemoryWorkerRegistrationStore();
        final heartbeat = await startWorkerRegistrationHeartbeat(
          workers: [
            _worker('w-triage-local', store),
            _worker('w-impl-local', store),
          ],
          store: store,
        );
        addTearDown(heartbeat.stop);

        expect(
          (await store.listWorkers()).map((w) => w.workerId).toSet(),
          {'w-triage-local', 'w-impl-local'},
        );
        expect(heartbeat.report.registeredWorkerIds, hasLength(2));
        expect(heartbeat.isRunning, isTrue);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// `lib/server.dart` as TEXT, so the composition is pinned rather than assumed.
///
/// Resolved through the package URI rather than a CWD-relative path because
/// `dart test` may be invoked from the repository root OR from `apps/server`;
/// a gate that only passes from one directory is not a gate.
Future<String> _serverSource() async {
  final uri = await Isolate.resolvePackageUri(
    Uri.parse('package:control_plane_server/server.dart'),
  );
  if (uri == null) {
    throw StateError('could not resolve the server composition source');
  }
  return File.fromUri(uri).readAsStringSync();
}

/// A worker whose collaborators are never exercised: nothing here runs an
/// execution, so a workspace manager and an execution driver only have to
/// exist and be honest about being unused.
LocalWorker _worker(
  String workerId,
  WorkerRegistrationStore? store, {
  DateTime Function()? clock,
}) => LocalWorker(
  workerId: workerId,
  poolId: 'test-pool',
  capabilities: const {WorkerCapability.linux},
  workspaceManager: _UnusedWorkspaceManager(),
  executionDriver: _UnusedExecutionDriver(),
  workerStore: InMemoryWorkerStore(),
  registrationStore: store,
  platform: 'test-platform',
  clock: clock,
);

/// Polls [condition] until it holds or the bound expires.
///
/// A bounded poll rather than a fixed sleep: the property under test is "this
/// eventually happens", and sleeping a fixed amount asserts a duration the test
/// does not control.
Future<void> _eventually(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  required String reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out after ${timeout.inMilliseconds}ms: $reason');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _MutableClock {
  _MutableClock(this.now);

  DateTime now;

  void advance(Duration by) => now = now.add(by);

  DateTime read() => now;
}

class _UnusedWorkspaceManager implements WorkspaceManager {
  @override
  Future<void> noSuchMethod(Invocation invocation) =>
      throw StateError('not used by the registration lifecycle');
}

class _UnusedExecutionDriver implements AgentExecutionDriver {
  @override
  Future<void> noSuchMethod(Invocation invocation) =>
      throw StateError('not used by the registration lifecycle');
}

/// Fails every write, to prove a registration failure is reported rather than
/// thrown.
class _RefusingStore implements WorkerRegistrationStore {
  @override
  Future<void> registerWorker(WorkerRegistration registration) =>
      Future<void>.error(StateError('write refused'));

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(WorkerRegistrationStore store) body,
  ) async => body(this);

  @override
  Future<WorkerRegistration?> readWorker(String workerId) async => null;

  @override
  Future<List<WorkerRegistration>> listWorkers() async => const [];

  @override
  Future<void> unregisterWorker(String workerId) async {}
}

/// A store that never answers a write, so every bound in the lifecycle is the
/// only thing standing between a wedged database and a shutdown that never
/// returns.
///
/// Nothing is ever written, so this is only ever used where the test asserts
/// on TIMING rather than on contents.
class _SilentStore implements WorkerRegistrationStore {
  @override
  Future<void> registerWorker(WorkerRegistration registration) =>
      Completer<void>().future;

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(WorkerRegistrationStore store) body,
  ) async => body(this);

  @override
  Future<WorkerRegistration?> readWorker(String workerId) async => null;

  @override
  Future<List<WorkerRegistration>> listWorkers() async => const [];

  @override
  Future<void> unregisterWorker(String workerId) async {}
}

/// A store slower than the heartbeat interval, counting what it is doing.
class _SlowStore implements WorkerRegistrationStore {
  _SlowStore({required this.delay, required this._inner});

  final Duration delay;
  final WorkerRegistrationStore _inner;

  int writeCount = 0;
  int maxConcurrentWrites = 0;
  int _concurrent = 0;

  Future<void> _tracked(Future<void> Function() write) async {
    _concurrent++;
    writeCount++;
    if (_concurrent > maxConcurrentWrites) maxConcurrentWrites = _concurrent;
    try {
      await Future<void>.delayed(delay);
      await write();
    } finally {
      _concurrent--;
    }
  }

  @override
  Future<void> registerWorker(WorkerRegistration registration) =>
      _tracked(() => _inner.registerWorker(registration));

  @override
  Future<WorkerRegistration?> readWorker(String workerId) =>
      _inner.readWorker(workerId);

  @override
  Future<List<WorkerRegistration>> listWorkers() => _inner.listWorkers();

  @override
  Future<void> unregisterWorker(String workerId) =>
      _inner.unregisterWorker(workerId);

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(WorkerRegistrationStore store) body,
  ) => _inner.inTransaction<T>(body);
}
