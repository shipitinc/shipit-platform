import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'acp_transport.dart';

/// AcpTransport backed by a spawned `opencode acp` child process speaking
/// newline-delimited JSON-RPC 2.0 over stdio.
class OpenCodeProcessTransport implements AcpTransport {
  OpenCodeProcessTransport({
    required this.executable,
    required this.cwd,
    this.environment,
    this.pure = false,
    this.extraArgs = const [],
    this.requestTimeout = const Duration(minutes: 5),
  });

  final String executable;
  final String cwd;
  final Map<String, String>? environment;
  final bool pure;
  final List<String> extraArgs;

  /// Upper bound on any single request on the wire (initialize, session/new,
  /// session/prompt, ...). A wedged runtime process must not hold the executor
  /// hostage for the transport's whole lifetime; the session layer applies an
  /// even tighter bound around the prompt itself.
  final Duration requestTimeout;

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
      final key = id.hashCode;
      final completer = _pending.remove(key);
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
    return completer.future.timeout(
      requestTimeout,
      onTimeout: () {
        _pending.remove(id);
        throw AcpTransportException('ACP request timed out: $method');
      },
    );
  }

  int get nextRequestId => ++_nextId;

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
