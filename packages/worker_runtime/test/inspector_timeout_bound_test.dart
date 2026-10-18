import 'dart:io';

import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';

/// Proves that [GitWorkspaceInspector.timeout] is *applied*, not merely
/// declared.
///
/// The class doc claims the read-only git commands run "with a hard bound so
/// a wedged filesystem cannot hold the worker hostage", and the field is
/// public API with a 30-second default. Until the bound was actually applied
/// to `Process.run`, that field was dead: a wedged git held the worker for as
/// long as the filesystem took to give up, with nothing to stop it.
///
/// The proof needs no database and no Docker. A stub `git` that sleeps longer
/// than the declared bound stands in for a wedged filesystem: if the bound is
/// applied, the inspector gives up at the bound and *reports* the timeout; if
/// it is not, the inspector waits for the stub to finish on its own, which is
/// the defect. Each test therefore asserts two things — that the call reported
/// a timeout, and how long it actually took — because either alone is
/// satisfiable by a no-op.
void main() {
  late Directory sandbox;
  late Directory stubDir;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('inspector_bound_sandbox_');
    stubDir = Directory.systemTemp.createTempSync('inspector_bound_stub_');
  });

  tearDown(() {
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    if (stubDir.existsSync()) stubDir.deleteSync(recursive: true);
  });

  /// A `git` that ignores its arguments and sleeps [seconds], standing in for
  /// a git invocation wedged on an unresponsive filesystem.
  String sleepingGit(int seconds) {
    final path = '${stubDir.path}/git';
    File(path).writeAsStringSync('#!/bin/sh\nsleep $seconds\n');
    Process.runSync('chmod', ['+x', path]);
    return path;
  }

  test(
    'inspector applies a declared timeout shorter than the git sleep',
    () async {
      // Stub sleeps 5s; declared bound is 500ms. The gap is what makes the test
      // discriminating: a call that waits for the stub has demonstrably ignored
      // the bound.
      final inspector = GitWorkspaceInspector(
        git: sleepingGit(5),
        timeout: const Duration(milliseconds: 500),
      );

      final elapsed = Stopwatch()..start();
      Object? caught;
      try {
        await inspector.inspect(sandbox.path, startingRevision: 'HEAD');
      } on Object catch (e) {
        caught = e;
      }
      elapsed.stop();

      expect(
        caught,
        isA<GitCommandException>(),
        reason:
            'a wedged git must surface as GitCommandException, not a value '
            'obtained after waiting out the stub (waited ${elapsed.elapsed})',
      );
      expect(
        elapsed.elapsed,
        lessThan(const Duration(seconds: 4)),
        reason:
            'the call must give up at the declared bound, not at the '
            'stub sleep (waited ${elapsed.elapsed})',
      );
    },
  );

  test(
    'the default bound is 30s and is the bound actually applied',
    () async {
      // The stub sleeps 45s — comfortably past the declared default — so a
      // call that honours the default returns at ~30s while one that ignores it
      // returns at ~45s. The window asserted below is what distinguishes them.
      expect(
        const GitWorkspaceInspector().timeout,
        const Duration(seconds: 30),
        reason: 'pins the documented default',
      );

      final inspector = GitWorkspaceInspector(git: sleepingGit(45));

      final elapsed = Stopwatch()..start();
      Object? caught;
      try {
        await inspector.inspect(sandbox.path, startingRevision: 'HEAD');
      } on Object catch (e) {
        caught = e;
      }
      elapsed.stop();

      expect(
        caught,
        isA<GitCommandException>(),
        reason:
            'a wedged git must surface as GitCommandException, not a value '
            'obtained after waiting out the stub (waited ${elapsed.elapsed})',
      );
      expect(
        elapsed.elapsed,
        greaterThan(const Duration(seconds: 25)),
        reason:
            'guards against a vacuous pass: the call really did wait for '
            'the declared bound rather than returning immediately',
      );
      expect(
        elapsed.elapsed,
        lessThan(const Duration(seconds: 42)),
        reason:
            'the declared 30s bound must fire well before the 45s stub '
            'sleep ends (waited ${elapsed.elapsed})',
      );
      // The ceiling is sized for the *defect*, not the fixed behaviour. With the
      // bound applied the test settles at ~30s, on the first git call. Without it
      // all three serial calls run out the stub: 3 x 45s = 135s. The generous
      // ceiling lets that case report its own measured failure instead of dying
      // on a framework timeout, which would hide the number that proves it.
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
