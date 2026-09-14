import 'dart:io';

/// Builds a disposable, dependency-free Dart workspace the verifier can run
/// against without any `pub get` or network access. The implementation lives
/// in `lib/calculator.dart`; the check is a plain script with a relative
/// import so `dart <abs path>` executes it directly.
class FixtureWorkspace {
  FixtureWorkspace({required String parent})
    : root = Directory('$parent/fixture_ws') {
    root.createSync(recursive: true);
    _writeCalculator(implemented: false);
    _writeVerifyScript();
  }

  final Directory root;

  /// Path to the fixture's `lib/calculator.dart`.
  String get calculatorPath => '${root.path}/lib/calculator.dart';

  void _writeCalculator({required bool implemented}) {
    final file = File(calculatorPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      implemented
          ? '''
int add(int a, int b) => a + b;
'''
          : '''
int add(int a, int b) => throw UnimplementedError();
''',
    );
  }

  void _writeVerifyScript() {
    final file = File('${root.path}/tool/verify.dart');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('''
import 'dart:io';
import '../lib/calculator.dart';

void main() {
  final result = add(2, 3);
  if (result != 5) {
    stdout.writeln('FAIL: add(2,3)=\$result expected 5');
    exitCode = 1;
  } else {
    stdout.writeln('ALL_VERIFICATIONS_PASSED');
  }
}
''');
  }

  /// Flip the implementation so `add(2, 3)` returns 5.
  void implement() => _writeCalculator(implemented: true);

  /// Make the independent check unsatisfiable no matter what the agent does:
  /// the check demands a result that contradicts the (only) allowed change to
  /// `add`. Used to demonstrate that the platform's verdict can disagree with
  /// the agent's success report.
  void makeVerifyImpossible() {
    final file = File('${root.path}/tool/verify.dart');
    file.writeAsStringSync('''
import 'dart:io';
import '../lib/calculator.dart';

void main() {
  final result = add(2, 3);
  if (result != 999) {
    stdout.writeln('FAIL: add(2,3)=\$result expected 999');
    exitCode = 1;
  } else {
    stdout.writeln('ALL_VERIFICATIONS_PASSED');
  }
}
''');
  }

  List<String> verifyCommand() {
    final dart = Platform.resolvedExecutable;
    return [dart, '${root.path}/tool/verify.dart'];
  }

  void dispose() {
    root.deleteSync(recursive: true);
  }
}
