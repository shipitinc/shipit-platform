import 'dart:io';

/// A disposable, dependency-free git repository used to prove worker source
/// isolation. Baseline commit: `lib/calculator.dart` throws
/// UnimplementedError and `tool/verify.dart` asserts `add(2,3) == 5`.
class GitRepoFixture {
  GitRepoFixture._(this.root);

  final Directory root;

  static GitRepoFixture create(String parent) {
    final root = Directory('$parent/source_repo')..createSync(recursive: true);
    final fixture = GitRepoFixture._(root).._init();
    return fixture;
  }

  ProcessResult _run(
    List<String> args, {
    Directory? cwd,
    bool allowFailure = false,
  }) {
    final result = Process.runSync(
      'git',
      args,
      workingDirectory: (cwd ?? root).path,
      environment: {
        ...Platform.environment,
        'GIT_AUTHOR_NAME': 'test',
        'GIT_AUTHOR_EMAIL': 'test@example.com',
        'GIT_COMMITTER_NAME': 'test',
        'GIT_COMMITTER_EMAIL': 'test@example.com',
        'GIT_CONFIG_GLOBAL': '/dev/null',
        'GIT_CONFIG_SYSTEM': '/dev/null',
      },
    );
    if (result.exitCode != 0 && !allowFailure) {
      throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
    }
    return result;
  }

  void _init() {
    _run(['init', '-b', 'main']);
    _writeCalculator(implemented: false);
    _writeVerify();
    _run(['add', '.']);
    _run(['commit', '-m', 'baseline']);
  }

  /// The exact 40-char SHA injected as [WorkerExecutionRequest.startingRevision].
  String get startingRevision =>
      _run(['rev-parse', 'HEAD']).stdout.toString().trim();

  void _writeCalculator({required bool implemented}) {
    final file = File('${root.path}/lib/calculator.dart');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      implemented
          ? 'int add(int a, int b) => a + b;\n'
          : 'int add(int a, int b) => throw UnimplementedError();\n',
    );
  }

  void _writeVerify() {
    final file = File('${root.path}/tool/verify.dart');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('''
import 'dart:io';
import '../lib/calculator.dart';

void main() {
  final result = add(2, 3);
  if (result != 5) {
    stdout.writeln('FAIL: add(2,3)=\$result');
    exitCode = 1;
  } else {
    stdout.writeln('ALL_VERIFICATIONS_PASSED');
  }
}
''');
  }

  void dispose() {
    _run(['worktree', 'prune'], allowFailure: true);
    root.deleteSync(recursive: true);
  }
}