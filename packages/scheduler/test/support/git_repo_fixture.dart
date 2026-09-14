import 'dart:io';

/// A disposable, dependency-free git repository used to prove worker source
/// isolation. Baseline commit: `lib/calculator.dart` throws
/// UnimplementedError and `tool/verify.dart` asserts `add(2,3) == 5`.
class GitRepoFixture {
  GitRepoFixture._(this.root);

  final Directory root;

  String get calculatorPath => '${root.path}/lib/calculator.dart';
  String get verifyPath => '${root.path}/tool/verify.dart';

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
    baselineCommit = _run(['rev-parse', 'HEAD']).stdout.toString().trim();
  }

  /// A second commit where the implementation is already correct.
  void commitImplementation() {
    _writeCalculator(implemented: true);
    _run(['add', '.']);
    _run(['commit', '-m', 'implement calculator']);
  }

  String? baselineCommit;

  /// The exact 40-char SHA injected as [WorkerExecutionRequest.startingRevision].
  String get startingRevision =>
      _run(['rev-parse', 'HEAD']).stdout.toString().trim();

  /// Simulates an operator dirtied the checkout: uncommitted change + an
  /// untracked stray file. Neither may leak into an isolated worktree.
  void dirtySource() {
    File(
      calculatorPath,
    ).writeAsStringSync('int add(int a, int b) => a + b; // dirty\n');
    File('${root.path}/stray.txt').writeAsStringSync('leak-me\n');
  }

  String showWorktreeFile(String path) =>
      File('$path/lib/calculator.dart').readAsStringSync();

  void _writeCalculator({required bool implemented}) {
    final file = File(calculatorPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      implemented
          ? 'int add(int a, int b) => a + b;\n'
          : 'int add(int a, int b) => throw UnimplementedError();\n',
    );
  }

  void _writeVerify() {
    final file = File(verifyPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(_verifySource(null));
  }

  /// Writes a verify script that additionally demands the worktree HEAD is
  /// EXACTLY [expectingRevision]. If a wrongly-created worktree started at any
  /// other commit (e.g. spawn-time HEAD), the platform check fails.
  void writeVerify({required String expectingRevision}) {
    final file = File(verifyPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(_verifySource(expectingRevision));
  }

  String _verifySource(String? expectingRevision) {
    final pinCheck = expectingRevision == null
        ? "// no revision pin"
        : '''
  final head = Process.runSync(
    'git', ['rev-parse', 'HEAD']).stdout.toString().trim();
  if (head != '$expectingRevision') {
    stdout.writeln('FAIL: worktree HEAD was \$head, expected $expectingRevision');
    exitCode = 1;
  }
''';
    return '''
import 'dart:io';
import '../lib/calculator.dart';

void main() {
$pinCheck
  final result = add(2, 3);
  if (result != 5) {
    stdout.writeln('FAIL: add(2,3)=\$result');
    exitCode = 1;
  } else {
    stdout.writeln('ALL_VERIFICATIONS_PASSED');
  }
}
''';
  }

  void dispose() {
    _run(['worktree', 'prune'], allowFailure: true);
    root.deleteSync(recursive: true);
  }
}
