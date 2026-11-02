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
    if (message['method'] is String && message.containsKey('id')) {
      // A message carrying BOTH `id` and `method` is a server->client
      // REQUEST (`session/request_permission`, `fs/read_text_file`,
      // `terminal/*`, ...), not a response. It must be answered: an
      // unanswered request blocks the agent's turn until the execution
      // budget kills the whole session — exec 194 stalled 19+min on a
      // single unacknowledged `session/request_permission`. Checking
      // `method` BEFORE consulting `_pending` also keeps a server request
      // whose id collides with a pending client request from wrongly
      // completing that request.
      _onServerRequest(id, message);
      return;
    }

    if (id is int || id is String) {
      // The correlation key is the request id exactly as `request` stored it
      // in `_pending`. JSON-RPC also permits a string id; the request API is
      // int-keyed, so a numeric string is coerced rather than dropped.
      final key = id is int ? id : int.tryParse(id);
      final completer = key == null ? null : _pending.remove(key);
      if (completer == null) {
        // A response for an id nobody is waiting on: ignore it.
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

  /// Answers a server->client JSON-RPC request. Every such request MUST get
  /// a response: the agent blocks the turn until one arrives, and this client
  /// is the only party that can send it.
  ///
  /// ## POLICY: `session/request_permission` is DENIED, never granted
  ///
  /// The runtime asks only for what its permission rules did not pre-allow —
  /// against opencode 1.18.x that is `external_directory` (a path outside the
  /// workspace) and `doom_loop` (a repeated-call detector asking whether the
  /// loop may continue). Everything else defaults to `allow` inside opencode,
  /// so the only asks that reach the wire are the ones outside the bounds the
  /// worker was already given.
  ///
  /// Granting is not a neutral convenience: the opencode child runs
  /// UNSANDBOXED on the worker host with the worker's credentials, so an
  /// `external_directory` grant is arbitrary host-path access decided by the
  /// agent. Denying hands the agent an ordinary tool error and the turn
  /// continues — the agent adapts to the workspace it was given, which is the
  /// correct behaviour for an autonomous worker. `doom_loop` denial is its
  /// purpose: the detector fired, so the repeated call is refused.
  ///
  /// The deny is expressed by selecting the offered `reject`-kind option
  /// (`optionId: "reject"` on opencode 1.18.x, whose outcome parser maps any
  /// non-allow selection to a one-shot deny with no persisted rule). When the
  /// options carry no reject-kind entry the response is `cancelled`, which
  /// the runtime maps to deny as well. A grant (`once`/`always`) is never
  /// selected.
  ///
  /// `OPENCODE_PERMISSION` (a JSON env the runtime merges over its
  /// `permission` config, e.g. `{"external_directory":"deny"}`) could make
  /// the known ask kinds never fire. The responder was chosen instead: it
  /// covers every ask kind and every future server->client request, not just
  /// the two names known today.
  ///
  /// Any other server->client request is answered `-32601 Method not found`:
  /// honest (the client does not implement `fs/*` or `terminal/*`) and,
  /// structurally, what makes "an unmodelled request stalled the turn"
  /// impossible — the response exists even when the method does not.
  void _onServerRequest(Object? id, Map<String, dynamic> message) {
    if (!isOpen) return;
    final method = message['method'] as String;
    final Map<String, dynamic> response;
    if (method == 'session/request_permission') {
      response = {
        'jsonrpc': '2.0',
        'id': id,
        'result': _denyPermissionOutcome(message['params']),
      };
      if (!_closed) {
        _notifications.add({
          'method': 'acp/permission_denied',
          'params': {
            'requestId': id,
            'toolCall':
                (message['params'] as Map<String, dynamic>?)?['toolCall'],
          },
        });
      }
    } else {
      response = {
        'jsonrpc': '2.0',
        'id': id,
        'error': {
          'code': -32601,
          'message': 'shipit-platform does not implement $method',
        },
      };
    }
    try {
      _process?.stdin.write(encodeFrame(response));
    } catch (_) {
      // A dead pipe means the child is gone; the exit handler completes
      // outstanding requests and there is nobody left to answer.
    }
  }

  /// The JSON-RPC `result` for a denied `session/request_permission`: the
  /// offered reject-kind option when one exists, else the `cancelled`
  /// outcome, which the runtime also maps to deny.
  static Map<String, dynamic> _denyPermissionOutcome(Object? params) {
    if (params is Map<String, dynamic> && params['options'] is List) {
      String? rejectAny;
      for (final option in params['options'] as List) {
        if (option is! Map<String, dynamic>) continue;
        final kind = option['kind'];
        final optionId = option['optionId'];
        if (kind == 'reject_once' && optionId is String) {
          return _selectedOutcome(optionId);
        }
        if (rejectAny == null &&
            kind is String &&
            kind.startsWith('reject') &&
            optionId is String) {
          rejectAny = optionId;
        }
      }
      if (rejectAny != null) return _selectedOutcome(rejectAny);
    }
    return const {
      'outcome': {'outcome': 'cancelled'},
    };
  }

  static Map<String, dynamic> _selectedOutcome(String optionId) => {
    'outcome': {'outcome': 'selected', 'optionId': optionId},
  };

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
