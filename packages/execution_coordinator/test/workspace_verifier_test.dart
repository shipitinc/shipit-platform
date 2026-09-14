import 'dart:io';

import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

void main() {
  late Directory temp;
  late FixtureWorkspace fixture;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('verifier_');
    fixture = FixtureWorkspace(parent: temp.path);
  });

  tearDown(() => fixture.dispose());

  test('passes only when the workspace actually implements add', () async {
    final verifier = const WorkspaceVerifier();

    final before = await verifier.verify(
      workingDirectory: fixture.root.path,
      command: fixture.verifyCommand(),
    );
    expect(before.passed, isFalse);
    expect(before.exitCode, isNot(0));

    fixture.implement();
    final after = await verifier.verify(
      workingDirectory: fixture.root.path,
      command: fixture.verifyCommand(),
    );
    expect(after.passed, isTrue);
    expect(after.exitCode, 0);
    expect(after.outputTail, contains('ALL_VERIFICATIONS_PASSED'));
  });

  test('reports a missing executable as failed without throwing', () async {
    final verifier = const WorkspaceVerifier();
    final outcome = await verifier.verify(
      workingDirectory: fixture.root.path,
      command: ['/nonexistent-binary-xyz', '--never'],
    );
    expect(outcome.passed, isFalse);
    expect(outcome.detail, contains('Failed to spawn'));
  });

  test('kills a command that exceeds the timeout', () async {
    final slow = File('${fixture.root.path}/tool/slow.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''
import 'dart:io';
void main() {
  sleep(const Duration(seconds: 3600));
}
''');

    final verifier = const WorkspaceVerifier();
    final outcome = await verifier.verify(
      workingDirectory: fixture.root.path,
      command: [Platform.resolvedExecutable, slow.path],
      timeout: const Duration(milliseconds: 500),
    );
    expect(outcome.passed, isFalse);
    expect(outcome.detail, contains('exceeded'));
  });

  test('caps captured output', () async {
    final noisy = File('${fixture.root.path}/tool/noisy.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''
void main() {
  print('x' * 4000);
}
''');

    final verifier = const WorkspaceVerifier(outputCapCharacters: 128);
    final outcome = await verifier.verify(
      workingDirectory: fixture.root.path,
      command: [Platform.resolvedExecutable, noisy.path],
    );
    expect(outcome.passed, isTrue);
    expect(outcome.outputTail.length, lessThanOrEqualTo(128));
  });
}
