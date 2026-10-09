import 'dart:io';

import 'package:test/test.dart';

/// Pins the endpoint surface invariant that `serverpod generate` enforces, and
/// that nothing in this repository's test suite was checking.
///
/// WHY THIS TEST EXISTS. `CredentialEndpoints.recordCustodyPrecondition` is a
/// synchronous, public, `Session`-first method that is deliberately NOT on the
/// wire. Serverpod discovers endpoints by exactly that shape, so it failed the
/// generator with `Return type must be a Future or a Stream.` and `serverpod
/// generate` exited 1. Two review cycles passed over it, because every test here
/// exercises the endpoint in-process and none of them asks Serverpod to
/// generate a client for it.
///
/// Running `serverpod generate` from a test is not an option: it takes ~20s and
/// it WRITES `packages/control_plane_client/**`, which belongs to another lane.
/// So the invariant is pinned here instead, against the same predicate the
/// generator uses.
///
/// THE PREDICATE, from `serverpod_cli`'s `EndpointMethodAnalyzer.isEndpointMethod`
/// (read from the 3.4.13 this server pins): a method is an endpoint method when
/// it is public, not `static`, not `@doNotGenerate`, not one of Serverpod's own
/// excluded names, and its FIRST required positional parameter is a `Session`.
/// Such a method must then return `Future` or `Stream`.
///
/// WHY THIS IS SYNTACTIC RATHER THAN USED `dart:mirrors`. Same reason as
/// [credential_keypair_test.dart] gives for its own surface audit: what needs
/// catching is a *declaration* that widens the surface, which is a source-level
/// fact, and `dart:mirrors` is not available on every target a test may run on.
/// (`dart analyze` rejects the import outright here, which is how the point got
/// made empirically.)
void main() {
  group('every public Session-first method on an Endpoint is a real endpoint', () {
    for (final file in _endpointSourceFiles()) {
      final className = _classNameForEndpointFile(file);

      test('$className exposes no endpoint method the generator would reject', () {
        final offenders = <String>[];

        for (final declaration in _publicSessionFirstMethods(file)) {
          if (_isExcludedByServerpod(declaration.name)) continue;
          if (_isMarkedDoNotGenerate(file, declaration)) continue;

          // A constructor declares no return type, and Serverpod never treats
          // one as an endpoint method, so it is not an offender.
          final returnType = declaration.returnType;
          if (returnType == null) continue;

          if (!_isFutureOrStream(returnType)) {
            offenders.add(
              '$className.${declaration.name} returns '
              '$returnType, not Future or Stream',
            );
          }
        }

        expect(
          offenders,
          isEmpty,
          reason:
              'Serverpod treats every public, non-@doNotGenerate, Session-first '
              'method on an Endpoint subclass as a wire endpoint, and fails '
              'generation unless it returns Future or Stream.\n'
              'Offending declarations:\n  ${offenders.join('\n  ')}\n'
              'If such a method is genuinely not an endpoint, annotate it with '
              '@doNotGenerate and say why in its doc comment. '
              'CredentialEndpoints.recordCustodyPrecondition is the worked '
              'example.',
        );
      });
    }
  });

  group('the guard cannot be quietly narrowed', () {
    test('every endpoint file on disk is actually audited', () {
      // The list of audited files IS the list of files above, so this group
      // cannot drift from it. What it does assert is that the file listing
      // itself is not silently narrowed — a glob that stops matching, or an
      // endpoint file that gets renamed out of the pattern, must fail loudly
      // rather than reduce the guard to nothing.
      final files = _endpointSourceFiles()
          .map(_classNameForEndpointFile)
          .toSet();

      expect(
        files.length,
        greaterThanOrEqualTo(12),
        reason:
            'apps/server/lib/src/endpoints should hold at least 12 endpoint '
            'files. Seeing ${files.length} means the directory glob stopped '
            'matching and this whole file now audits nothing.',
      );
      expect(
        files,
        contains('CredentialEndpoints'),
        reason:
            'CredentialEndpoints must stay in the audited set: it is the class '
            'this invariant was written for.',
      );
    });
  });
}

/// One method declaration recovered from an endpoint source file.
class _Declaration {
  _Declaration({
    required this.name,
    required this.returnType,
    required this.startLine,
  });

  final String name;

  /// Null for a constructor, which Serverpod never treats as an endpoint.
  final String? returnType;

  /// 1-based line of the declaration, so a failure points at real code.
  final int startLine;
}

/// The endpoint source files, in a stable order.
List<File> _endpointSourceFiles() {
  final directory = Directory('lib/src/endpoints');
  if (!directory.existsSync()) {
    throw StateError(
      'lib/src/endpoints does not exist relative to ${Directory.current.path}. '
      'This test must run from apps/server.',
    );
  }
  return (directory.listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      .where((f) => f.uri.pathSegments.last.endsWith('_endpoints.dart'))
      .toList();
}

/// `credential_endpoints.dart` -> `CredentialEndpoints`, the convention every
/// file in `lib/src/endpoints/` follows.
/// The declared return type, or null for a constructor (which Serverpod never
/// treats as an endpoint).
String? _returnTypeOf(RegExpMatch match) {
  final pre = match.namedGroup('pre')!.trim();
  return pre.isEmpty ? null : pre;
}

String _classNameForEndpointFile(File file) {
  final name = file.uri.pathSegments.last;
  final withoutExtension = name.substring(0, name.length - '.dart'.length);
  return withoutExtension
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join();
}

/// Serverpod's own excluded method names
/// (`EndpointMethodAnalyzer._excludedMethodNameSet`).
const _serverpodExcludedMethodNames = {
  'streamOpened',
  'streamClosed',
  'handleStreamMessage',
  'sendStreamMessage',
  'setUserObject',
  'getUserObject',
};

/// Serverpod requires an endpoint method to return `Future` or `Stream`,
/// optionally with a type argument (`Future<Map<String, dynamic>>`,
/// `Stream<int>?`). So the name must be followed by a type-argument boundary
/// rather than compared for exact equality.
bool _isFutureOrStream(String returnType) => RegExp(
  r'^(?:Future|Stream)\b',
).hasMatch(returnType);

bool _isExcludedByServerpod(String name) =>
    _serverpodExcludedMethodNames.contains(name);

/// Every public, non-`static` method declaration in [file] whose first required
/// positional parameter is a `Session`.
List<_Declaration> _publicSessionFirstMethods(File file) {
  final lines = _stripComments(file.readAsStringSync()).split('\n');
  final found = <_Declaration>[];

  for (var i = 0; i < lines.length; i++) {
    final match = _memberPattern.firstMatch(lines[i]);
    if (match == null) continue;

    // `static` members are not endpoint methods.
    if (match.namedGroup('mods')!.contains('static')) continue;

    final name = match.namedGroup('name')!;
    if (name.startsWith('_')) continue;

    // Getters have no parameter list, so the pattern cannot match them.
    final parameterList = _balancedParameterList(lines, i, match.end - 1);
    if (parameterList == null) continue;
    if (!_firstRequiredParameterIsSession(parameterList)) continue;

    found.add(
      _Declaration(
        name: name,
        returnType: _returnTypeOf(match),
        startLine: i + 1,
      ),
    );
  }

  return found;
}

/// A member declaration at exactly the class body's own indentation.
///
/// [pre] is everything between the modifiers and the method name, which is the
/// return type for a method and empty for a constructor. It is captured
/// loosely rather than as a Dart type so that nested generics
/// (`Future<Map<String, dynamic>>`) survive intact.
final _memberPattern = RegExp(
  r'^ {2}(?<mods>(?:static\s+|final\s+|const\s+|late\s+|external\s+)*)'
  r'(?<pre>[^;]*?)\s*(?<name>[A-Za-z_][A-Za-z0-9_]*)\s*\(',
);

/// Reads the parameter list that opens at [openParenColumn] on [startLine],
/// continuing over following lines until the parentheses balance.
///
/// The scan starts just AFTER the opening paren with [depth] already at 1, so the
/// captured text is the parameter list itself and never includes the delimiters.
///
/// Returns null when the list never balances — a malformed or truncated
/// declaration, which this test must not silently read as "no Session first
/// parameter".
String? _balancedParameterList(
  List<String> lines,
  int startLine,
  int openParenColumn,
) {
  var depth = 1;
  final buffer = StringBuffer();
  var line = startLine;

  while (line < lines.length) {
    final text = line == startLine
        ? lines[line].substring(openParenColumn + 1)
        : lines[line];

    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '(' || char == '[' || char == '{') depth++;
      if (char == ')' || char == ']' || char == '}') depth--;
      if (depth == 0) return buffer.toString();
      buffer.write(char);
    }

    buffer.write('\n');
    line++;
  }
  return null;
}

/// Serverpod's `isFirstRequiredParameterSession`: the first parameter is
/// required-positional and typed `Session`.
///
/// One shape covers it: `Session session`, optionally nullable. None of
/// `required Session session`, `Session? session = null` or a named
/// `Session session:` matches, which is correct — none of those is the required
/// positional `Session` Serverpod looks for.
bool _firstRequiredParameterIsSession(String parameterList) {
  final first = _splitTopLevel(parameterList).firstOrNull;
  if (first == null) return false;
  final normalized = first.replaceAll(RegExp(r'\s+'), ' ').trim();
  return RegExp(r'^Session\?? \w+$').hasMatch(normalized);
}

/// Splits on commas that are not inside brackets.
List<String> _splitTopLevel(String text) {
  final parts = <String>[];
  var depth = 0;
  var current = StringBuffer();

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '(' || char == '[' || char == '{' || char == '<') depth++;
    if (char == ')' || char == ']' || char == '}' || char == '>') depth--;
    if (char == ',' && depth == 0) {
      parts.add(current.toString());
      current = StringBuffer();
      continue;
    }
    current.write(char);
  }
  if (current.toString().trim().isNotEmpty) parts.add(current.toString());
  return parts;
}

/// Whether the declaration at [declaration] in [file] carries `@doNotGenerate`.
///
/// `doNotGenerate` is `const doNotGenerate = _DoNotGenerate()` in
/// `serverpod_shared/src/annotations.dart`.
bool _isMarkedDoNotGenerate(File file, _Declaration declaration) {
  final lines = _stripComments(file.readAsStringSync()).split('\n');
  // Annotations sit on the lines directly above the declaration.
  for (
    var i = declaration.startLine - 2;
    i >= 0 && i >= declaration.startLine - 4;
    i--
  ) {
    if (lines[i].trimRight().isEmpty) continue;
    if (lines[i].trimLeft().startsWith('@')) {
      return lines[i].contains('doNotGenerate');
    }
    break;
  }
  return false;
}

/// Removes `//` and `///` line comments, including trailing ones, so a member
/// named in prose cannot register as a declaration.
String _stripComments(String source) => source
    .split('\n')
    .map((line) {
      final withoutTripleSlash = line.startsWith('///')
          ? ''
          : line.replaceFirst(RegExp(r'//.*$'), '');
      return withoutTripleSlash;
    })
    .join('\n');
