// Each test spawns real `dart test` subprocesses, which pay the launcher
// precompile on a cold `.dart_tool`; the default 30s ceiling is below what
// the first of them costs. Measured at this commit: ~20s per cold run.
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

/// `f3a81c27` — the server package's unit-test runner,
/// `apps/server/tool/run_unit_tests.dart`.
///
/// ## WHY THIS FILE BYTE-COPIES THE RUNNER
///
/// The runner is a script (`tool/`), not a library, and its `main()` calls
/// `exit()`. So this test cannot import it and call `main()` in-process. What
/// it can do — and does — is:
///
///   1. copy the runner to a disposable fixture package's `tool/` directory,
///   2. build `test/` with a known mix of passing, failing, subdirectory and
///      non-Dart files,
///   3. run the COPY as a real subprocess and assert on its exit code and
///      output.
///
/// The copy is verified byte-identical by sha256 before it is run, so the
/// process under test is provably the file in the repository and not a
/// re-typed approximation of it. This is what makes the enumeration boundary
/// and the fail-closed exit codes measured rather than described.
///
/// ## WHAT IT PROVES
///
/// * A missing `test/` directory, and a `test/` directory with no top-level
///   `.dart` files, both exit 2 — never a vacuous pass.
/// * A file inside `test/integration/` is NOT enumerated (exclusion by
///   construction), demonstrated by a failing file there that the run ignores.
/// * A failing top-level file makes the whole run exit 1 and names the file.
/// * Only top-level `.dart` files are enumerated, in sorted order, regardless
///   of name.
void main() {
  late Directory temp;
  late Directory fixture;
  late File scriptCopy;

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('run_unit_tests_');
    fixture = Directory('${temp.path}/fixture_pkg')..createSync();
    File('${fixture.path}/pubspec.yaml').writeAsStringSync(
      'name: runner_fixture_pkg\n\n'
      'environment:\n'
      '  sdk: ">=3.12.0 <4.0.0"\n\n'
      'dev_dependencies:\n'
      '  test: any\n',
    );
    final toolDir = Directory('${fixture.path}/tool')..createSync();
    scriptCopy = File('${toolDir.path}/run_unit_tests.dart');
    scriptCopy.writeAsBytesSync(await _realRunnerBytes());
    // Make the fixture's `dart test` reachable offline. Measured: the fixture
    // runs `dart test`, which needs the `test` package resolved in the
    // fixture's own package.
    final pubGet = await Process.run(
      'dart',
      ['pub', 'get', '--offline'],
      workingDirectory: fixture.path,
    );
    expect(
      pubGet.exitCode,
      0,
      reason:
          'the fixture package must resolve `test` before the runner can run '
          'anything: ${pubGet.stderr}',
    );
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test(
    'the copy under test is byte-identical to the repository runner',
    () async {
      // Non-vacuity: if this test starts asserting against a re-typed script,
      // every other test in this file becomes a test of the copy. sha256 is the
      // assertion that they are the same bytes.
      expect(
        _sha256(scriptCopy.readAsBytesSync()),
        _sha256(await _realRunnerBytes()),
      );
    },
  );

  test('a missing test/ directory exits 2 — never a pass', () async {
    final result = await _runRunner(fixture);
    expect(result.exitCode, 2, reason: 'stdout: ${result.stdout}');
    expect(result.stderr, contains('no test/ directory'));
  });

  test('a test/ directory with no top-level .dart files exits 2', () async {
    Directory('${fixture.path}/test').createSync();
    // A subdirectory is present, so the directory is not empty in the
    // filesystem's sense — but it has no top-level .dart file, which is what
    // the enumeration is about.
    Directory('${fixture.path}/test/integration').createSync();
    File('${fixture.path}/test/integration/x_test.dart').writeAsStringSync(
      _passingTest('x'),
    );
    final result = await _runRunner(fixture);
    expect(
      result.exitCode,
      2,
      reason:
          'an empty top-level enumeration means the boundary was applied to '
          'the wrong directory; a pass here would be the narrowing defect in '
          'its most extreme form. stdout: ${result.stdout}',
    );
    expect(result.stderr, contains('no top-level .dart files'));
  });

  test('a file under test/integration/ is NOT enumerated', () async {
    final testDir = Directory('${fixture.path}/test')..createSync();
    File('${testDir.path}/a_test.dart').writeAsStringSync(_passingTest('a'));
    final integration = Directory('${testDir.path}/integration')..createSync();
    // A FAILING file inside test/integration/. If the runner enumerated it
    // (or a failing integration file leaked in), the run would exit 1.
    File('${integration.path}/b_test.dart').writeAsStringSync(
      _failingTest('b'),
    );

    final result = await _runRunner(fixture);
    expect(
      result.exitCode,
      0,
      reason:
          'test/integration/ must be outside the enumeration BY CONSTRUCTION '
          '(a non-recursive listing). If this fails, the boundary narrowed or '
          'widened and the per-execution gate would run integration tests '
          'that need a live database. stdout: ${result.stdout}',
    );
    expect(result.stdout, contains('1 files, all passed'));
  });

  test(
    'only top-level .dart files are enumerated, whatever their name',
    () async {
      final testDir = Directory('${fixture.path}/test')..createSync();
      // Names chosen to defeat a name filter: the runner has none. Every
      // top-level `.dart` file is a SUITE by contract (AGENTS.md: "All 51 unit
      // tests sit directly in test/"), so a top-level file that is not a suite
      // is out of contract and correctly fails the run — that is asserted in
      // its own test below.
      File('${testDir.path}/zzz_last_test.dart').writeAsStringSync(
        _passingTest('zzz'),
      );
      File('${testDir.path}/aaa_first_test.dart').writeAsStringSync(
        _passingTest('aaa'),
      );
      // Non-`.dart` files are excluded by EXTENSION, which is the runner's only
      // filter: README.md must not be counted.
      File('${testDir.path}/README.md').writeAsStringSync('not a test');

      final result = await _runRunner(fixture);
      expect(result.exitCode, 0, reason: 'stdout: ${result.stdout}');
      // README.md must NOT be counted: 2, not 3.
      expect(result.stdout, contains('2 files, all passed'));
    },
  );

  test('a top-level .dart file that is not a suite fails the run', () async {
    final testDir = Directory('${fixture.path}/test')..createSync();
    File('${testDir.path}/a_test.dart').writeAsStringSync(_passingTest('a'));
    // A helper with no `main`, sitting at the top level. The contract puts
    // helpers in `test/support/` and `test/fixtures/` (subdirectories, outside
    // the enumeration); a top-level non-suite is a defect in the package, and
    // the runner correctly fails rather than silently skipping it.
    File('${testDir.path}/helper.dart').writeAsStringSync(
      'void helper() {}\n',
    );

    final result = await _runRunner(fixture);
    expect(
      result.exitCode,
      1,
      reason:
          'the enumeration has no skip list, by design: anything at the top '
          'level is run. If this passed, the runner had grown a filter that '
          'could also swallow a real suite. stdout: ${result.stdout}',
    );
    expect(result.stdout, contains('helper.dart'));
  });

  test('a failing top-level file fails the run and is named', () async {
    final testDir = Directory('${fixture.path}/test')..createSync();
    File('${testDir.path}/a_test.dart').writeAsStringSync(_passingTest('a'));
    File('${testDir.path}/z_failing_test.dart').writeAsStringSync(
      _failingTest('z'),
    );

    final result = await _runRunner(fixture);
    expect(
      result.exitCode,
      1,
      reason:
          'a real failure must fail the run; the per-execution gate reads '
          'this exit code. stdout: ${result.stdout}',
    );
    expect(result.stdout, contains('FAILED'));
    // The failing file is listed at the END of the output so it survives the
    // verifier's output-tail cap.
    expect(result.stdout, contains('z_failing_test.dart'));
    expect(result.stdout, contains('1 of 2 files FAILED'));
  });
}

Future<ProcessResult> _runRunner(Directory fixture) => Process.run(
  Platform.resolvedExecutable,
  ['run', 'tool/run_unit_tests.dart'],
  workingDirectory: fixture.path,
);

/// The exact bytes of the repository runner.
///
/// Located through `Isolate.resolvePackageUri` rather than
/// `Platform.script`: measured at this commit, `Platform.script` under the
/// test runner points at a temporary file under the system temp directory and
/// resolved the runner to `/var/folders/.../T/tool/run_unit_tests.dart`. The
/// package URI is the same technique `implementation_verification_plan_test.dart`
/// and `triage_verification_plan_test.dart` use.
Future<List<int>> _realRunnerBytes() async {
  final uri = await Isolate.resolvePackageUri(
    Uri.parse('package:control_plane_server/server.dart'),
  );
  if (uri == null) {
    throw StateError('could not resolve the server composition source');
  }
  // apps/server/lib/server.dart -> apps/server -> apps/server/tool/...
  final packageRoot = File.fromUri(uri).parent.parent;
  final runner = File('${packageRoot.path}/tool/run_unit_tests.dart');
  if (!runner.existsSync()) {
    throw StateError('repository runner not found at ${runner.path}');
  }
  return runner.readAsBytesSync();
}

String _passingTest(String name) =>
    "import 'package:test/test.dart';\n\n"
    "void main() {\n"
    "  test('$name passes', () {});\n"
    "}\n";

String _failingTest(String name) =>
    "import 'package:test/test.dart';\n\n"
    "void main() {\n"
    "  test('$name fails', () => fail('intentional failure'));\n"
    "}\n";

String _sha256(List<int> bytes) => sha256.convert(bytes).toString();
