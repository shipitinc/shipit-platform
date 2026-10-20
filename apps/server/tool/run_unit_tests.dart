// The server package's unit-test runner — decision `f3a81c27`.
//
// `AGENTS.md` -> "Required validation gates" declares, for `apps/server`:
//
//     dart run tool/run_unit_tests.dart     (cwd: apps/server)
//
// ## Why a runner, and not `dart test`
//
// Plain `dart test` in this package also picks up `test/integration/`, whose
// suites need a live database the per-execution tier does not provide — every
// per-execution run would go red for a reason that is not a unit-test failure.
// A pinned list of the 51 test paths was rejected instead, because a pinned
// list SILENTLY EXCLUDES any test file added later: a coverage hole that never
// fails anything. Enumerating at run time picks up new files without editing
// any contract.
//
// ## The enumeration boundary, and why integration cannot enter it
//
// The boundary is `test/*.dart` AT THE TOP LEVEL ONLY. It is enforced by
// `Directory.listSync()` — a NON-RECURSIVE listing — plus a `.dart` extension
// check and nothing else. There is no name filter, no skip list, no pattern
// beyond the extension: a file is enumerated because it is a top-level `.dart`
// file in `test/`, for any name it happens to have. `test/integration/`,
// `test/fixtures/` and `test/support/` are subdirectories; a non-recursive
// listing never returns their contents, so no file inside them can enter the
// run no matter what it is called. That is exclusion BY CONSTRUCTION, not by
// filter — which matters because this runner is a TRUSTED TRUTH for the
// `declared-validation-outcome` gate (decision `f3a81c27`): the gate asserts
// THIS process's exit code, so if the enumeration ever narrowed, the gate's
// completeness claim would quietly become this file's opinion. The one
// anti-narrowing property a filter could not have is preserved: ANY new
// top-level `.dart` file is picked up with no edit anywhere.
//
// ## What a failure means here
//
// Every enumerated file is run as its OWN `dart test <file>` process, so one
// failing file cannot hide behind the compact reporter (F-160). The runner
// exits non-zero if ANY file fails — a non-zero `dart test` exit, a spawn
// error, or a file that disappears between enumeration and execution are all
// failures, never passes. A missing `test/` directory, or a `test/` directory
// with no top-level `.dart` files, is an ERROR (exit 2), not a pass: an empty
// enumeration can only mean the boundary was applied to the wrong directory,
// and a runner that passed on nothing would be the narrowing defect above in
// its most extreme form.
//
// ## Concurrency, AND THE HONEST NUMBER
//
// Files run in a bounded pool, because the serial floor is a budget violation.
// MEASURED on this deployment at base `54d440c`: 51 files, one process at a
// time, took 544s cold and 539s warm — roughly ten seconds per file of process
// and compile overhead that has nothing to do with suite runtime — against the
// verifier's 2-minute per-command budget (`WorkspaceVerifier.defaultTimeout`).
//
// **THE POOL IS NOT ENOUGH, AND THE REASON IS MEASURED.** At this HEAD the
// 52-file suite through this runner takes **531s** cold: the pool overlaps the
// processes but each one re-compiles the package graph, and on this
// 8-core/16GB machine the work is compile- and I/O-bound (measured 29% CPU
// under a 6-way pool), so six at once are barely faster than one. A single
// `dart test` process over all 51 files — which reuses one compilation but
// which AGENTS.md rules out because one failing file must not hide behind the
// others — takes **237s**. BOTH exceed the 2-minute per-command budget.
//
// ## Why the warm-up exists, and who found the race
//
// `dart test` cannot start until it has precompiled its launcher snapshot into
// `<pkg>/.dart_tool/pub/bin/test/`. Starting six of them at once, cold, means
// six processes racing that one precompile: measured, five of six died with
// `PathNotFoundException: Cannot rename … .snapshot.incremental.temp`, and a
// runner that reported those as test failures would fail an execution for a
// property of its own concurrency. So `runUnitTests` runs ONE file to
// completion first and the pool starts only after it settles. The
// fixture-driven `unit_tests_runner_test.dart` is what caught this: its 6-way
// pool was the first place the race was exercised.

import 'dart:async';
import 'dart:io';

/// Entry point for `dart run tool/run_unit_tests.dart`.
///
/// The package root is derived from THIS SCRIPT's location, never from the
/// caller's working directory: a verifier, a human and a test all get the same
/// enumeration from the same directory, so the boundary cannot be redirected
/// by an environment that happens to `cd` somewhere else first.
Future<void> main() async {
  final script = File.fromUri(Platform.script);
  final toolDir = script.parent;
  // A [Directory]'s `uri` ends with `/`, so its last path segment is `''` and
  // the second-to-last is the directory's own name (`tool`). Measured, not
  // assumed: comparing against `'tool/'` here rejected every invocation, and
  // the fixture-driven subprocess test below is what caught it.
  if (toolDir.uri.pathSegments.length >= 2 &&
      toolDir.uri.pathSegments[toolDir.uri.pathSegments.length - 2] != 'tool') {
    stderr.writeln(
      'run_unit_tests must be invoked from the package\'s tool/ directory '
      '(resolved script: ${script.path}); refusing to guess a package root.',
    );
    exit(2);
  }
  final packageRoot = toolDir.parent;

  final RunnerSummary summary;
  try {
    summary = await runUnitTests(packageRoot: packageRoot);
  } on StateError catch (e) {
    // A missing or empty `test/` directory. NOT a pass — see the file header.
    stderr.writeln(e.message);
    exit(2);
  }

  final failed = summary.failed;
  if (failed.isEmpty) {
    stdout.writeln(
      'run_unit_tests: ${summary.enumerated} files, all passed '
      '(top-level test/*.dart only; test/integration/ is outside the '
      'enumeration by construction)',
    );
    exit(0);
  }
  for (final outcome in failed) {
    stdout.writeln(
      'FAILED ${outcome.relativePath} '
      '(exit ${outcome.exitCode ?? 'spawn-error: ${outcome.error}'})',
    );
    if (outcome.output.isNotEmpty) {
      stdout.writeln(_tail(outcome.output, 2000));
    }
  }
  stdout.writeln(
    'run_unit_tests: ${failed.length} of ${summary.enumerated} files FAILED',
  );
  for (final outcome in failed) {
    stdout.writeln('  ${outcome.relativePath}');
  }
  exit(1);
}

/// Maximum number of `dart test <file>` processes alive at once.
///
/// MEASURED, and reported honestly: the pool overlaps processes, but at this
/// HEAD the 52-file suite still takes **531s** because each process recompiles
/// the package graph on an 8-core/16GB machine that is compile-bound, not
/// CPU-bound. See the file header's "Concurrency, AND THE HONEST NUMBER" — the
/// honest number is that NO form of this runner fits the verifier's 2-minute
/// per-command budget, which is why the check is delivered correct and
/// UNACTIVATED. The warm-up in [runUnitTests] exists because a cold 6-way
/// start races the launcher precompile.
const int maxParallelFiles = 6;

/// Enumerates the unit-test files of [packageRoot]: every top-level
/// `test/*.dart` file, sorted by path, and NOTHING else.
///
/// Non-recursive by construction — see the file header. Throws [StateError]
/// when `test/` is missing or holds no top-level `.dart` files: an empty
/// enumeration is an error the caller must surface, never a vacuous pass.
List<File> enumerateUnitTestFiles(Directory packageRoot) {
  final testDir = Directory('${packageRoot.path}${Platform.pathSeparator}test');
  if (!testDir.existsSync()) {
    throw StateError(
      'no test/ directory in ${packageRoot.path} — the unit suite is missing; '
      'this is an error, not a pass',
    );
  }
  final files =
      testDir
          .listSync(followLinks: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    throw StateError(
      'test/ in ${packageRoot.path} contains no top-level .dart files — the '
      'unit suite is missing; this is an error, not a pass',
    );
  }
  return files;
}

/// One file's outcome. `passed` is true only for an observed exit code 0 —
/// a spawn error or a missing file is never a pass.
class FileOutcome {
  const FileOutcome({
    required this.relativePath,
    required this.exitCode,
    required this.output,
    this.error,
  });

  final String relativePath;
  final int? exitCode;
  final String output;
  final String? error;

  bool get passed => exitCode == 0;
}

/// The whole run: one outcome per enumerated file, in enumeration order.
class RunnerSummary {
  const RunnerSummary({required this.outcomes});

  final List<FileOutcome> outcomes;

  int get enumerated => outcomes.length;
  List<FileOutcome> get failed => outcomes.where((o) => !o.passed).toList();
}

/// Runs every enumerated file as its own `dart test <file>` process in
/// [packageRoot], in a pool of at most [concurrency] processes, and returns
/// one [FileOutcome] per file.
///
/// Every enumerated file is executed — the pool bounds how many run AT ONCE,
/// never which ones run. A process that cannot be spawned (the `dart` binary
/// missing, the file deleted between enumeration and execution) is a failed
/// outcome with [FileOutcome.exitCode] `null`, not an omission.
///
/// The FIRST file is run to completion before the pool starts, so the launcher
/// snapshot is compiled once and no worker races another for it. See
/// [maxParallelFiles] for the measured reason.
Future<RunnerSummary> runUnitTests({
  required Directory packageRoot,
  int concurrency = maxParallelFiles,
}) async {
  final files = enumerateUnitTestFiles(packageRoot);
  final outcomes = List<FileOutcome?>.filled(files.length, null);

  // Warm-up: one file, alone, so the shared `.dart_tool/pub/bin/test`
  // precompile is settled before anyone else needs it.
  outcomes[0] = await _runOneFile(packageRoot, files[0]);

  var next = 1;

  Future<void> worker() async {
    while (true) {
      final index = next++;
      if (index >= files.length) return;
      outcomes[index] = await _runOneFile(packageRoot, files[index]);
    }
  }

  await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
  return RunnerSummary(outcomes: outcomes.cast<FileOutcome>());
}

Future<FileOutcome> _runOneFile(Directory packageRoot, File file) async {
  final relativePath = 'test${Platform.pathSeparator}${_baseName(file)}';
  final ProcessResult result;
  try {
    result = await Process.run(
      Platform.resolvedExecutable,
      ['test', relativePath],
      workingDirectory: packageRoot.path,
    );
  } on ProcessException catch (e) {
    return FileOutcome(
      relativePath: relativePath,
      exitCode: null,
      output: '',
      error: e.message,
    );
  }
  return FileOutcome(
    relativePath: relativePath,
    exitCode: result.exitCode,
    output: '${result.stdout}${result.stderr}',
  );
}

String _baseName(File file) => file.uri.pathSegments.last;

String _tail(String text, int max) =>
    text.length <= max ? text : text.substring(text.length - max);
