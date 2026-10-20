import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

/// The platform-runner's own verification of an agent's claimed work. This is
/// independent of the agent: it spawns real processes in the workspace.
class WorkspaceVerifier {
  const WorkspaceVerifier({
    this.defaultTimeout = const Duration(minutes: 2),
    this.outputCapCharacters = 8000,
  });

  /// Fallback bound for a run that declares no `timeout` of its own.
  ///
  /// Applied once to the setup command and once to the command itself — each
  /// gets the full duration, not a shared budget. A [VerificationCheck] may
  /// override it per check (decision `5c9e2b74`: two of the five declared
  /// per-execution checks need more than two minutes to complete, and being
  /// killed mid-run would record a FAILING verdict about work never judged);
  /// the override changes only HOW LONG a check may take. The result of
  /// overrunning it is fixed here and is not caller-selectable: the process is
  /// SIGKILLed and the outcome is `passed == false` with `ran == true` — a
  /// failing row, never a pass and never an absent one.
  final Duration defaultTimeout;
  final int outputCapCharacters;

  /// Runs [command] in [workingDirectory], optionally after a one-shot
  /// [setupCommand] (e.g. `dart pub get`). Never fails to return: a spawn
  /// failure, timeout or non-zero exit is a [VerificationOutcome.passed]
  /// == false with the reason captured in [VerificationOutcome.detail].
  Future<VerificationOutcome> verify({
    required String workingDirectory,
    required List<String> command,
    List<String>? setupCommand,
    Duration? timeout,
  }) async {
    final buffer = StringBuffer();

    if (setupCommand != null) {
      final setup = await _run(
        workingDirectory: workingDirectory,
        command: setupCommand,
        timeout: timeout ?? defaultTimeout,
        buffer: buffer,
      );
      if (setup.exitCode != 0) {
        // `ran: false` — the CHECK never started. A setup step that fails is
        // an environment problem, not a verdict about the work, and the
        // coordinator turns `ran == false` into NO ROW at all. See
        // [VerificationOutcome.ran].
        return VerificationOutcome(
          passed: false,
          ran: false,
          mechanism: 'process_${setupCommand.first}',
          command: setupCommand.join(' '),
          exitCode: setup.exitCode,
          detail: 'Setup command failed before verification could run.',
          outputTail: _cap(buffer.toString()),
        );
      }
    }

    final run = await _run(
      workingDirectory: workingDirectory,
      command: command,
      timeout: timeout ?? defaultTimeout,
      buffer: buffer,
    );

    final passed = run.exitCode == 0;
    return VerificationOutcome(
      passed: passed,
      // A command that STARTED and blew the verifier's timeout is `ran: true`:
      // it was observed, and what it produced was not a pass. Only a process
      // that never spawned is a check that did not run.
      ran: run.spawned,
      mechanism: 'process_${command.first}',
      command: command.join(' '),
      exitCode: run.exitCode,
      detail: run.detail,
      outputTail: _cap(buffer.toString()),
    );
  }

  Future<_ProcessOutcome> _run({
    required String workingDirectory,
    required List<String> command,
    required Duration timeout,
    required StringBuffer buffer,
  }) async {
    final Process process;
    try {
      process = await Process.start(
        command.first,
        command.skip(1).toList(),
        workingDirectory: workingDirectory,
        runInShell: false,
      );
    } catch (e) {
      // `ran: false` — nothing was executed, so nothing was observed. The
      // overwhelmingly common cause is that the tool is not installed in the
      // sandbox at all.
      return _ProcessOutcome(
        exitCode: -1,
        spawned: false,
        detail: 'Failed to spawn ${command.first}: $e',
      );
    }

    final done = Completer<int>();
    process.stdout
        .transform(utf8.decoder)
        .listen((chunk) => _append(buffer, chunk));
    process.stderr
        .transform(utf8.decoder)
        .listen((chunk) => _append(buffer, chunk));
    process.exitCode.then(done.complete);

    try {
      final exitCode = await done.future.timeout(timeout);
      return _ProcessOutcome(exitCode: exitCode);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await done.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => -2,
      );
      return _ProcessOutcome(
        exitCode: -1,
        detail: 'Command exceeded ${timeout.inSeconds}s and was killed.',
      );
    } finally {
      await process.stdin.close();
    }
  }

  void _append(StringBuffer buffer, String chunk) {
    buffer.write(chunk);
    if (buffer.length > outputCapCharacters) {
      final trimmed = buffer.toString();
      buffer
        ..clear()
        ..write(trimmed.substring(trimmed.length - outputCapCharacters));
    }
  }

  String _cap(String text) {
    if (text.length <= outputCapCharacters) return text;
    return text.substring(text.length - outputCapCharacters);
  }
}

/// Outcome of one independent verification run, carried into a
/// [PlatformVerification] by the coordinator.
@immutable
class VerificationOutcome {
  const VerificationOutcome({
    required this.passed,
    required this.mechanism,
    required this.command,
    required this.exitCode,
    this.ran = true,
    this.detail,
    this.outputTail = '',
  });

  final bool passed;
  final String mechanism;
  final String command;
  final int exitCode;
  final String? detail;
  final String outputTail;

  /// Whether the check actually EXECUTED.
  ///
  /// `false` means the process was never spawned — the tool is not installed,
  /// or the setup step failed first. It is the distinction that keeps an
  /// absent check absent: [ExecutionCoordinator] writes NO row for an outcome
  /// with `ran == false`, so a gate reading the persisted rows sees a missing
  /// check rather than a check that silently passed.
  ///
  /// A timeout keeps `ran == true` — the process started and overran; it was
  /// observed, and what it produced was not a pass.
  final bool ran;
}

class _ProcessOutcome {
  const _ProcessOutcome({
    required this.exitCode,
    this.spawned = true,
    this.detail,
  });

  final int exitCode;

  /// `false` when [WorkspaceVerifier._run] could not start a process at all.
  final bool spawned;
  final String? detail;
}
