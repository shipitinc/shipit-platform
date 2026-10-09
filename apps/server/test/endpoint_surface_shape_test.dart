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
/// (read from the 3.4.13 this server pins, verbatim):
///
/// ```dart
/// static bool isEndpointMethod(MethodElement method) {
///   if (method.isPrivate) return false;
///   if (method.markedAsIgnored) return false;      // @doNotGenerate
///   if (_excludedMethodNameSet.contains(method.name)) return false;
///   return method.formalParameters.isFirstRequiredParameterSession;
/// }
/// ```
///
/// So a method is an endpoint method when it is NOT private, NOT
/// `@doNotGenerate`, NOT one of Serverpod's own excluded names, and its FIRST
/// required positional parameter is a `Session`.
///
/// **There is no `isStatic` check in 3.4.13.** A `static` method with `Session`
/// first is still discovered and still validated, so `static` is *not* a way
/// out of this — it is worse than doing nothing, because it also reads like one.
/// (4.0.3 added `if (method.isStatic) return false;` and dropped
/// `_excludedMethodNameSet` altogether. Assume neither when the pin moves.)
///
/// Such a method must then return `Future` or `Stream` — but the generator's
/// rule for that is stricter than the name, and the interesting half of this
/// guard is in [_returnTypeRejection].
///
/// WHAT THIS IS NOT. It is a backstop, not *the* backstop. It encodes the
/// endpoint-method predicate and the return-type rule, and each rule here was
/// checked against `serverpod generate` itself rather than assumed — but it
/// does not run the generator, and as of this writing no CI job runs it either:
/// `integration.yaml` invokes only `dart test test/integration/`, and `ci.yaml`
/// excludes `apps/server` from its pure-Dart job. So this file's value today is
/// manual (`dart test test/endpoint_surface_shape_test.dart` from
/// `apps/server`), and a CI gate on generate's exit status remains the only
/// complete check. Do not read a green run here as "generate passes".
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

          final rejection = _returnTypeRejection(returnType);
          if (rejection != null) {
            offenders.add(
              '$className.${declaration.name} returns $returnType — $rejection',
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
///
/// **The 3.4.13 shape**, copied from that version. 4.0.3 deleted
/// `_excludedMethodNameSet` entirely, so when the server's pin moves this list
/// must be re-read, not carried over. Today it can only ever *skip* a
/// declaration, so a stale name here is a missed check rather than a false
/// alarm — the list is documented rather than treated as authoritative.
const _serverpodExcludedMethodNames = {
  'streamOpened',
  'streamClosed',
  'handleStreamMessage',
  'sendStreamMessage',
  'setUserObject',
  'getUserObject',
};

/// Serverpod's `EndpointMethodAnalyzer._validateReturnType` in 3.4.13,
/// reproduced against the declaration text.
///
/// Returns **null** when `serverpod generate` accepts the return type, and
/// otherwise a short reason it rejects it.
///
/// The generator is stricter than "the name is `Future` or `Stream`". It also
/// requires:
///
/// - exactly one type argument (`typeArguments.length != 1` → `Return generic
///   must be type defined.`), so a bare `Future`/`Stream` is rejected — to the
///   analyzer a bare `Future` *is* `Future<dynamic>`;
/// - `Future<void>` and `Stream<void>` are treated **differently**: the first
///   is accepted (`_validateReturnType` returns null for it), the second is
///   rejected with `The type "void" is not supported for streams.`
/// - `Future<dynamic>` and `Stream<dynamic>` are treated **differently**, and
///   this is the subtlest rule in the function. The rejection reads
///   `innerType is DynamicType && !dartType.isDartAsyncStream`, so it catches
///   the `Future` and lets the `Stream` through. The `Stream` then survives
///   `TypeDefinition.fromDartType` too, because `DynamicTypeImpl.element` is
///   `DynamicElementImpl.instance` and its `displayName` is `dynamic` — not
///   null — so no `FromDartTypeClassNameException` is thrown.
///
/// That last point is verified, not inferred: `Stream<dynamic> probe(Session)`
/// on an Endpoint **generates successfully and emits a real client streaming
/// method**. Rejecting it here would be a false alarm on legal code, which is
/// the same defect as a false pass in the other direction — a guard that
/// contradicts the generator teaches the next reader that the guard is wrong.
///
/// Only a type argument that IS `dynamic` or `void` is rejected, never one that
/// merely mentions it. That makes `Future<Map<String, dynamic>>` — the shape
/// twenty-two endpoints in this repository returned until 2026-10-09 — a LEGAL
/// ENDPOINT. Every sentence above is still true.
///
/// GENERATOR-LEGAL IS NOT WIRE-LEGAL. Read the rest of this before concluding
/// that a return type this file accepts will work.
///
/// This guard answers "will `serverpod generate` accept this declaration?". The
/// answer is yes for `Future<Map<String, dynamic>>`. The answer to "will the
/// browser be able to read the response?" is **no**, always:
///
/// ```dart
/// // Protocol.deserialize, emitted BY THE GENERATOR for that return type:
/// if (t == Map<String, dynamic>) {
///   return (data as Map).map(
///         (k, v) => MapEntry(deserialize<String>(k), deserialize<dynamic>(v)),
///       ) as T;
/// }
/// ```
///
/// `SerializationManager.deserialize` has entries for `int`, `double`,
/// `String`, `bool`, `DateTime`, `ByteData`, `Duration`, `UuidValue`, `Uri`,
/// `BigInt` and the vector types. It has **none** for `dynamic`, so
/// `deserialize<dynamic>(v)` throws
/// `DeserializationTypeNotFoundException: No deserialization found for type
/// dynamic` on the first value of the body.
///
/// THE COUNTER-EXAMPLES, both of which cost this repository two review cycles:
/// `credentialEndpoints.generate` and
/// `productRegistryEndpoints.addRepositoryReference`. The second is the one
/// that matters: `AddProductBloc` calls it immediately BEFORE the mint
/// (`add_product_page.dart:143` -> `_ensureProductAndRepository:281`, then
/// `:147`), so while it declared a map the browser died there and no deploy key
/// was ever minted. `dart analyze`, `serverpod generate`, this file, and the
/// entire unit suite were all green at that revision, because none of them
/// crosses the wire.
///
/// AND THE ASYMMETRY THAT HIDES IT: the branch above never calls
/// `deserialize<dynamic>` for an EMPTY map, so an endpoint returning `{}`
/// deserialises successfully while any NON-EMPTY map throws. That is why this
/// defect class presents as intermittent and gets blamed on whichever endpoint
/// is nearest the symptom.
///
/// The guard for this lives in `credential_wire_return_type_test.dart`, which
/// scans the generated client and fails on ANY map-returning endpoint method.
/// Do not widen this function's remit to cover it: this one tests the
/// generator, that one tests the wire, and folding them together would make
/// this file's answer depend on a property the generator does not have.
String? _returnTypeRejection(String returnType) {
  final shape = _returnTypeShape.firstMatch(returnType.trim());
  if (shape == null) {
    return 'it is not Future or Stream at all.';
  }

  final container = shape.namedGroup('container')!;
  final arguments = _splitTopLevel(shape.namedGroup('argument') ?? '');
  if (arguments.length != 1) {
    return 'it carries ${arguments.length} type arguments, and serverpod '
        'requires exactly one.';
  }

  // `dynamic?` is `dynamic` to the analyzer; `void` is matched on its own.
  var inner = arguments.single.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (inner.endsWith('?')) inner = inner.substring(0, inner.length - 1).trim();
  if (inner.isEmpty) {
    return 'serverpod requires exactly one type argument.';
  }

  if (inner == 'dynamic' && container == 'Future') {
    return 'serverpod rejects a bare `dynamic` type argument on a `Future`; '
        'use a concrete type, e.g. Future<Map<String, Object?>>. '
        '`Stream<dynamic>` is allowed, so this is about the Future, not '
        '`dynamic` itself.';
  }

  if (inner == 'void' && container == 'Stream') {
    return 'serverpod rejects `Stream<void>`; use `Future<void>` instead.';
  }

  return null;
}

/// The outer `Future`/`Stream` of a return type and its single type argument.
///
/// The argument is captured greedily up to the LAST `>` so nested generics
/// survive intact (`Future<List<Map<String, int>>>` yields
/// `List<Map<String, int>>`), and the outer type may be nullable
/// (`Stream<int>?`). An absent type argument is captured as null, which
/// [_returnTypeRejection] rejects — a bare `Future` is `Future<dynamic>` to the
/// analyzer.
///
/// `FutureOr<void>` deliberately does not match: `\b` will not break between
/// `Future` and `Or`, and the generator rejects `FutureOr` regardless.
final _returnTypeShape = RegExp(
  r'^(?<container>Future|Stream)\b\s*(?:<(?<argument>.*)>)?\s*\??$',
);

bool _isExcludedByServerpod(String name) =>
    _serverpodExcludedMethodNames.contains(name);

/// Every public method declaration in [file] whose first required positional
/// parameter is a `Session`.
///
/// **`static` declarations are included, deliberately.** 3.4.13's
/// `isEndpointMethod` has no `isStatic` check, so a `static` method with
/// `Session` first is still an endpoint method and still has to satisfy the
/// return-type rule. An earlier version of this guard skipped `static` on the
/// assumption that it did not — an assumption that is true of 4.x and false of
/// the pinned version, which made the guard pass a declaration that fails
/// `serverpod generate`.
List<_Declaration> _publicSessionFirstMethods(File file) {
  final lines = _stripComments(file.readAsStringSync()).split('\n');
  final found = <_Declaration>[];

  for (var i = 0; i < lines.length; i++) {
    final match = _memberPattern.firstMatch(lines[i]);
    if (match == null) continue;

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
/// (`Future<Map<String, dynamic>>`) survive intact. [mods] exists only to
/// strip `static`/`final`/`const`/… so that [pre] is the return type even for a
/// `static` method — which is now audited, so [mods] must still match them.
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
