import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import 'acp_transport.dart';

/// AcpTransport backed by a spawned `opencode acp` child process speaking
/// newline-delimited JSON-RPC 2.0 over stdio.
class OpenCodeProcessTransport implements AcpTransport, StderrTail {
  OpenCodeProcessTransport({
    required this.executable,
    required this.cwd,
    this.environment,
    this.pure = false,
    this.extraArgs = const [],
    this.requestTimeout,
  });

  final String executable;
  final String cwd;
  final Map<String, String>? environment;
  final bool pure;
  final List<String> extraArgs;

  /// An upper bound on any single request on the wire (initialize,
  /// session/new, session/prompt, ...), or null for none.
  ///
  /// ## WHY THERE IS NO DEFAULT — THIS FIELD HAD ONE, AND IT KILLED REVIEWERS
  ///
  /// It defaulted to `Duration(minutes: 5)`, with a doc comment asserting an
  /// intent that was the exact inverse of what the code did:
  ///
  /// > "A wedged runtime process must not hold the executor hostage for the
  /// > transport's whole lifetime; the session layer applies an even tighter
  /// > bound around the prompt itself."
  ///
  /// The author assumed the session layer's bound would be tighter. It was not:
  /// the session layer carried the role budget (three hours for a review) and
  /// this default was five minutes, so **the transport was by far the tightest
  /// bound in the system and the only one that fired**. `defaultAcpTransport`
  /// never passed a value, so the class default bound every request on the wire
  /// — including `session/prompt`, which legitimately runs for the whole review.
  ///
  /// Live QA, two engineering reviews dead with
  /// `AcpTransportException: ACP request timed out: session/prompt`, at 308s and
  /// 350s. Not a slow runtime: a typed-in number nobody measured, sitting
  /// between the budget and the work.
  ///
  /// ## WHY NO VALUE OF THIS FIELD FIXES THAT
  ///
  /// The stated intent — catch a wedged process early — cannot be satisfied here
  /// at ANY value, which is why the field has no default rather than a better
  /// one:
  ///
  ///  * **Any bound shorter than the execution budget is a ceiling on legitimate
  ///    work, not a wedged-process guard.** `session/prompt` is the work. The
  ///    5-minute default did not protect against wedging; it aborted healthy
  ///    agents mid-review, which is worse: a wedged process costs a budget, a
  ///    healthy agent costs a review.
  ///  * **Any bound at or above the execution budget is unreachable.** The
  ///    budget that ends a wedged runtime is `ExecutionCoordinator`'s, and its
  ///    clock starts BEFORE the session is created, so its deadline is always
  ///    strictly earlier than any bound applied inside the session. The
  ///    coordinator fires first whatever this field says.
  ///
  /// So the wedged-process protection lives where it actually works and is
  /// unaffected by this field: the coordinator's budget ends the execution and
  /// cancels the session (`SIGTERM`, then `SIGKILL` after five seconds), and the
  /// session layer applies the SAME budget around each phase. See
  /// `defaultAcpTransport`, which passes `config.timeout` so the value comes
  /// from the role budget and not from this file.
  ///
  /// ## WHAT null ACTUALLY MEANS
  ///
  /// Not "wait forever, unkillably". A pending request is still completed with an
  /// error by [close] and by the child-exit handler, so nothing here outlives
  /// the transport; and every production caller sits under a budget. A caller
  /// that wants an independent wire bound passes one deliberately, which is the
  /// point: a bound nobody chose is a bound nobody reasoned about.
  final Duration? requestTimeout;

  Process? _process;
  final _notifications = StreamController<Map<String, dynamic>>.broadcast();
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  String _stderrBuffer = '';
  bool _isOpen = false;
  bool _closed = false;
  int _nextId = 0;

  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;

  @override
  Stream<Map<String, dynamic>> get notifications => _notifications.stream;

  @override
  bool get isOpen => _isOpen && !_closed;

  @override
  String get stderrTail => _stderrBuffer.length > 4000
      ? _stderrBuffer.substring(_stderrBuffer.length - 4000)
      : _stderrBuffer;

  Future<Process> _spawn() async {
    final args = <String>['acp', '--cwd', cwd];
    if (pure) args.add('--pure');
    args.addAll(extraArgs);
    return Process.start(
      executable,
      args,
      environment: environment,
      includeParentEnvironment: true,
      runInShell: false,
    );
  }

  @override
  Future<AcpInitializeResult> initialize() async {
    final process = await _spawn();
    _process = process;
    _isOpen = true;
    _linkStdio(process);
    process.exitCode.then((code) {
      _handleChildExit('opencode acp exited (code $code)');
    });

    final response = await request(1, 'initialize', {
      'protocolVersion': 1,
      'clientCapabilities': {'session': true},
      'clientInfo': {'name': 'shipit-platform', 'version': '0.1.0'},
    });
    return AcpInitializeResult.fromJson(response);
  }

  void _linkStdio(Process process) {
    _stdoutSub = process.stdout
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen(_onLine);
    _stderrSub = process.stderr
        .transform(const SystemEncoding().decoder)
        .listen((chunk) {
          _stderrBuffer += chunk;
          if (_stderrBuffer.length > 8192) {
            _stderrBuffer = _stderrBuffer.substring(
              _stderrBuffer.length - 8192,
            );
          }
        });
  }

  void _onLine(String line) {
    final message = tryDecodeLine(line);
    if (message == null) return;

    final id = message['id'];
    if (id is int || id is String) {
      // The correlation key is the request id exactly as `request` stored it
      // in `_pending`. JSON-RPC also permits a string id; the request API is
      // int-keyed, so a numeric string is coerced rather than dropped.
      final key = id is int ? id : int.tryParse(id);
      final completer = key == null ? null : _pending.remove(key);
      if (completer == null) {
        // Server->client request we do not model in this slice.
        return;
      }
      if (message['error'] is Map<String, dynamic>) {
        final error = message['error'] as Map<String, dynamic>;
        completer.completeError(
          AcpRequestException(
            (error['code'] as num?)?.toInt() ?? -32600,
            (error['message'] as String?) ?? 'ACP request error',
            error['data'],
          ),
        );
      } else {
        completer.complete(
          (message['result'] as Map<String, dynamic>?) ?? <String, dynamic>{},
        );
      }
      return;
    }

    if (message['method'] == null) return;
    _notifications.add(message);
  }

  void _handleChildExit(String reason) {
    final died = _isOpen;
    _isOpen = false;
    if (died) {
      for (final completer in _pending.values) {
        completer.completeError(
          AcpTransportException('child process exited: $reason'),
        );
      }
      _pending.clear();
      if (!_closed) {
        _notifications.add({
          'method': 'transport/closed',
          'params': {'reason': reason},
        });
      }
    }
  }

  @override
  Future<Map<String, dynamic>> request(
    int id,
    String method,
    Map<String, dynamic> params,
  ) async {
    if (!isOpen) {
      final process = _process;
      if (process == null) {
        throw AcpTransportException('transport not open');
      }
      throw AcpTransportException('transport closed before request');
    }
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _process!.stdin.write(
      encodeFrame({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      }),
    );
    final bound = requestTimeout;
    final pending = completer.future;
    return bound == null
        ? pending
        : pending.timeout(
            bound,
            onTimeout: () {
              _pending.remove(id);
              throw AcpTransportException('ACP request timed out: $method');
            },
          );
  }

  int get nextRequestId => ++_nextId;

  /// Number of requests written to the wire that have not yet been answered.
  /// Every resolved request must remove its own entry; a non-zero value after
  /// a response is a correlation bug.
  @visibleForTesting
  int get pendingRequestCount => _pending.length;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _isOpen = false;
    for (final completer in _pending.values) {
      completer.completeError(const AcpTransportException('transport closed'));
    }
    _pending.clear();

    final process = _process;
    if (process != null) {
      process.kill(ProcessSignal.sigterm);
      try {
        await process.exitCode.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () => -1,
        );
      }
    }
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    await _notifications.close();
  }

  String get executableSource => executable;
}

class AcpTransportException implements Exception {
  const AcpTransportException(this.message);

  final String message;

  @override
  String toString() => 'AcpTransportException: $message';
}
