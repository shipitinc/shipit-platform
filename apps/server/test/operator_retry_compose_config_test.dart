import 'dart:io';

import 'package:test/test.dart';

/// BLOCKER-1 and BLOCKER-2 — the deployment configuration this feature writes.
///
/// ## WHY A TEST GREPS YAML
///
/// Both blockers were invisible to every gate that existed, and both were
/// invisible for the same reason: they are one line of a file no Dart code
/// reads at build time and no test opened.
///
/// BLOCKER-1 deleted `SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS` from three compose
/// files. `apps/server/lib/server.dart` calls `resolveDispatchCapacity(...)`
/// BEFORE Serverpod is constructed and BEFORE the port binds, and throws
/// `UnboundedDispatchRefused` when the variable is absent — so every stack
/// that uses those files stopped booting. CI never noticed, because
/// `Makefile:9` records that `test-env-up` and `e2e-up` are used by neither CI
/// nor `test-integration`.
///
/// BLOCKER-2 then wrote `"${SHIPIT_OPERATOR_MAX_RETRIES:-3}"` directly beneath
/// a comment that said the interpolation was "deliberately NOT `${...:-3}`" and
/// that "a missing configuration must never arm an action that spends real
/// model credits". The comment and the line contradicted each other, and the
/// line armed the spend on a missing host variable.
///
/// Both are pure text properties of three files, so they are asserted as text.
/// This is deliberately dumb and deliberately literal: it would rather be
/// called redundant than be the fourth thing that did not catch them.
///
/// ## SCOPE
///
/// `docker/compose.qa.yaml` is NOT in this list. It is under human custody
/// (QA is live), so it is neither asserted nor edited here — and the assertion
/// below would fail if it were, which is the honest consequence of leaving it
/// alone.
void main() {
  // The three files Lane U may write. compose.qa.yaml is deliberately absent.
  const files = [
    'docker/compose.yaml',
    'docker/compose.test.yaml',
    'docker/compose.e2e.yaml',
  ];

  // Locate the repository root by walking up from the package directory, so
  // the path does not depend on the working directory the runner happens to
  // use. `Directory.current` is the package root under `dart test`, and the
  // compose files live at the repository root above it.
  String read(String relative) {
    var dir = Directory.current.absolute;
    while (true) {
      final candidate = File('${dir.path}/$relative');
      if (candidate.existsSync()) return candidate.readAsStringSync();
      final parent = dir.parent;
      if (parent.path == dir.path) {
        throw StateError(
          'could not locate $relative above ${Directory.current.path}',
        );
      }
      dir = parent;
    }
  }

  group('BLOCKER-1 — the dispatch cap line survives on every server service', () {
    test('every stack still declares SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS', () {
      for (final path in files) {
        final contents = read(path);
        expect(
          contents,
          contains('SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS:'),
          reason:
              '$path no longer declares the dispatch cap. Its comment says '
              '"removing this line takes every stack down, not just this one" — '
              'server.dart refuses to boot without it, before the port binds.',
        );
      }
    });

    test('and it keeps its default, which is what makes a stack bootable', () {
      for (final path in files) {
        expect(
          read(path),
          contains(r'SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS:-2'),
          reason:
              '$path lost the `:-\${VAR:-2}` default. Without a default the '
              'variable is absent and the server refuses to boot.',
        );
      }
    });

    test('its do-not-delete comment is still attached to it', () {
      for (final path in files) {
        final contents = read(path);
        final line = contents
            .split('\n')
            .indexWhere(
              (l) => l.contains('SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS:'),
            );
        expect(line, isNonNegative, reason: '$path has no cap line');

        // The comment block immediately above, which is what tells the next
        // editor that deleting the line is not a tidy-up.
        final above = contents.split('\n').sublist(0, line).join('\n');
        expect(
          above,
          contains('do not'),
          reason: '$path: the "do not delete" warning is missing',
        );
        expect(
          above,
          contains('REFUSES TO'),
          reason: '$path: the fail-closed explanation is missing',
        );
      }
    });
  });

  group('BLOCKER-2 — the retry bound must NOT default', () {
    test('no stack supplies a default that would ARM the spend', () {
      for (final path in files) {
        final line = read(path)
            .split('\n')
            .firstWhere((l) => l.contains('SHIPIT_OPERATOR_MAX_RETRIES:'));

        expect(
          line,
          isNot(contains(':-3')),
          reason:
              '$path defaults SHIPIT_OPERATOR_MAX_RETRIES to 3. That is exactly '
              'what decision 5d9a1f62 forbids: a missing configuration must '
              'never arm an action that spends real model credits.',
        );
        expect(
          line,
          isNot(matches(RegExp(r'\$\{SHIPIT_OPERATOR_MAX_RETRIES:-[0-9]'))),
          reason: '$path gives the retry bound a numeric default of any kind',
        );
      }
    });

    test('the value is present and interpolates to EMPTY, not to a number', () {
      for (final path in files) {
        expect(
          read(path),
          contains(r'SHIPIT_OPERATOR_MAX_RETRIES:-}'),
          reason:
              '$path should interpolate the unset case to an empty string, '
              'which the server resolves as UNRESOLVED — the fail-closed '
              'answer. `3` remains a value operators can configure.',
        );
      }
    });

    test('the comment agrees with the line', () {
      // The original defect was precisely a comment that said "no default"
      // directly above a line that had one. Asserted structurally so the two
      // cannot drift apart again without this failing.
      for (final path in files) {
        final lines = read(path).split('\n');
        final index = lines.indexWhere(
          (l) => l.contains('SHIPIT_OPERATOR_MAX_RETRIES:'),
        );
        expect(index, isNonNegative, reason: '$path has no retry-bound line');

        final comment = lines.sublist(0, index).join('\n');
        expect(
          comment,
          contains('5d9a1f62'),
          reason:
              '$path: the comment must name the decision that forbids the '
              'default, so a future editor can check it',
        );
        expect(
          comment,
          contains('must not default'),
          reason: '$path: the comment must state that there is no default',
        );
      }
    });
  });
}
