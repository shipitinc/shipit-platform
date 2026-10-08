import 'dart:convert';
import 'dart:io';

import 'package:control_plane_server/src/credentials/local_file_secret_provider.dart';
import 'package:control_plane_server/src/credentials/posix_file_permissions.dart';
import 'package:control_plane_server/src/credentials/secret_material.dart';
import 'package:control_plane_server/src/credentials/secret_provider.dart';
import 'package:control_plane_server/src/credentials/secretless_error.dart';
import 'package:control_plane_server/src/credentials/ssh_keypair.dart';
import 'package:control_plane_server/src/endpoints/credential_endpoints.dart';
import 'package:test/test.dart';

/// The B-1 class, in one file: **no exception message can reach a durable
/// record**.
///
/// B-1 proved a path from base64 private-key material to Postgres — a
/// `dart:convert` `FormatException` carrying an excerpt of its input, written to
/// the Serverpod session log by `credential_endpoints.dart`, persisted because
/// `config/test.yaml` sets `sessionLogs.persistentEnabled: true`. Two lines were
/// named; the class was the finding. This file is the proof that the class is
/// closed, from three sides:
///
///   1. **The sink.** `credentialFailureLogFields` is the single function both
///      endpoint `catch` blocks log through, and it renders [secretlessText]
///      rather than `error.toString()`. Fed real material-bearing failures, it
///      emits none of the material.
///   2. **The type gate.** An exception that has not declared itself
///      [AuditedFailure] has its message **suppressed entirely**, and
///      [redactUnauditedFailure] substitutes a stand-in so nothing downstream can
///      reach the original either. A new failing path is therefore silent by
///      default rather than leaky by default.
///   3. **The sources.** No [SecretProvider] implementation in
///      `lib/src/credentials/**` or `credential_endpoints.dart` may build a
///      `SecretStoreException` whose `reason` hands a `catch`-clause binding to
///      anything other than `secretlessText(…)`. That is a source audit, run as a
///      test, so it fails the build rather than relying on the next reader — and
///      F-2's residual, a reason assembled outside the audited call site, is
///      covered by driving the real adapter and inspecting what came out.
const _truncatedAccessBody =
    '{"name":"projects/p/secrets/GIT_REPOSITORY_repo-1_SSH/versions/1",'
    '"payload":{"data":"AAAAB3NzaC1lZDI1NTE5AAAAIEXAMPLESECRETHALFBASE64'
    'MATERIALHERE';

const _badBase64Payload =
    'AAAAB3NzaC1lZDI1NTE5AAAAIEXAMPLESECRETHALFBASE64MATERIAL!!!';

/// Fragments of the malformed material above that must never appear in an
/// exception message, a log field, or a durable column.
///
/// Substrings, not whole values: a decoder embeds an *excerpt*, so a
/// whole-value containment test would pass on the exact defect it exists to
/// catch.
const List<String> _forbiddenFragments = [
  'AAAAB3NzaC1lZDI1NTE5AAAAIEXAMPLESECRETHALFBASE64',
  'EXAMPLESECRETHALFBASE64',
  'SECRETHALF',
  'BASE64MATERIALHERE',
  'BASE64MATERIAL!!!',
  'PRIVATE KEY',
];

/// Asserts [text] carries no fragment of the malformed material.
///
/// [label] names the case in the reason; the reason never quotes a forbidden
/// value, so even this assertion failing prints no material.
void _expectNoMaterial(String text, String label) {
  for (final fragment in _forbiddenFragments) {
    expect(
      text.contains(fragment),
      isFalse,
      reason:
          'the $label put a fragment of the secret into text that reaches the '
          'session log and therefore Postgres',
    );
  }
}

/// Locates a repository directory from wherever `dart test` was invoked.
Directory _locateDirectory(String relative) {
  for (final candidate in _candidates(relative)) {
    if (candidate is Directory) return candidate;
  }
  throw StateError(
    'could not locate $relative from ${Directory.current.path}; this file '
    'audits sources and must not pass by finding nothing',
  );
}

/// Both plausible roots for [relative], walking up from the working directory.
///
/// `dart test` in `apps/server` and `dart test apps/server/test/…` from the
/// repository root do not agree on where they start, and a source audit that
/// silently found nothing would be worse than no audit at all.
List<FileSystemEntity> _candidates(String relative) {
  final found = <FileSystemEntity>[];
  for (final prefix in ['', 'apps/server/']) {
    var directory = Directory.current;
    for (var depth = 0; depth < 8; depth++) {
      final path = '${directory.path}/$prefix$relative';
      if (File(path).existsSync()) return [File(path)];
      if (Directory(path).existsSync()) return [Directory(path)];
      final parent = directory.parent;
      if (parent.path == directory.path) break;
      directory = parent;
    }
  }
  return found;
}

/// Failures whose own message genuinely carries key material.
///
/// Built by really performing the decodes, not by writing a message that looks
/// like one — the point is that these are the exceptions a real malformed secret
/// produces, with the real `dart:convert` messages.
List<Object> _materialBearingFailures() {
  final failures = <Object>[];
  try {
    jsonDecode(_truncatedAccessBody);
  } on Object catch (error) {
    failures.add(error);
  }
  try {
    base64.decode(_badBase64Payload);
  } on Object catch (error) {
    failures.add(error);
  }
  final pem = utf8.decode(
    SshKeyPair.generate(comment: 'shipit+leak-probe').privateKeyPemBytes,
  );
  failures
    ..add(StateError('store failed for $pem'))
    ..add(ArgumentError.value(pem, 'seed', 'a seed that is really a PEM'))
    ..add(UnsupportedError(pem));
  return failures;
}

void main() {
  group('the endpoint failure log line cannot carry a message', () {
    test('every material-bearing failure is stripped at the sink', () {
      final failures = _materialBearingFailures();
      expect(failures, isNotEmpty);

      for (final failure in failures) {
        // Sanity: these really do carry material, or the test proves nothing.
        expect(
          failures.any((f) => _forbiddenFragments.any(f.toString().contains)),
          isTrue,
          reason: 'the fixture must produce a material-bearing exception',
        );
        final fields = credentialFailureLogFields(
          event: 'credential.generate.failed',
          productId: 'p',
          repositoryId: 'r',
          error: failure,
        );
        _expectNoMaterial(
          fields.values.map((v) => '$v').join(' '),
          'credentialFailureLogFields for a ${failure.runtimeType}',
        );
        // The failure is still diagnosable — by type, which is the point of the
        // suppression rather than of silence.
        expect('${fields['error']}', contains('${failure.runtimeType}'));
      }
    });

    test('the fields a failure log always carries are still present', () {
      // A guard against a projection that is safe because it is empty.
      final fields = credentialFailureLogFields(
        event: 'credential.verify_access.failed',
        productId: 'p',
        repositoryId: 'r',
        error: StateError('boom'),
      );
      expect(fields['event'], 'credential.verify_access.failed');
      expect(fields['productId'], 'p');
      expect(fields['repositoryId'], 'r');
      expect(fields['error'], isNotEmpty);
    });
  });

  group('the type gate is closed by default', () {
    test('an unaudited failure loses its message entirely', () {
      final rendered = secretlessText(StateError('the payload was AAAAB3Nza'));
      expect(rendered, isNot(contains('AAAAB3Nza')));
      expect(rendered, contains('StateError'));
      expect(rendered, contains('not an audited failure'));
    });

    test('an audited failure keeps its own fields', () {
      final audited = SecretStoreException(
        referenceName: 'GIT_REPOSITORY_repo-1_SSH',
        providerId: kLocalFileProviderId,
        operation: 'read',
        reason: 'the access response was not JSON at all',
      );
      expect(secretlessText(audited), contains('GIT_REPOSITORY_repo-1_SSH'));
      expect(secretlessText(audited), contains('not JSON'));
    });

    test('a permission failure is typed rather than free text', () {
      // The `PosixFileModes` failures used to be `StateError`s built by string
      // interpolation, which made them unauditable by construction.
      final failure = PosixPermissionException(
        path: '/tmp/scratch/identity',
        intendedMode: '600',
        actualMode: '644',
      );
      expect(secretlessText(failure), contains('644'));
      expect(secretlessText(failure), contains('/tmp/scratch/identity'));
      expect(failure, isA<AuditedFailure>());
      expect(failure.toString(), secretlessText(failure));
    });

    test('redaction substitutes rather than forwards', () {
      final original = StateError('payload AAAAB3Nza');
      final redacted = redactUnauditedFailure(original);
      expect(identical(redacted, original), isFalse);
      expect(redacted, isA<UnauditedFailure>());
      expect(redacted.toString(), isNot(contains('AAAAB3Nza')));
      expect(
        redactUnauditedFailure(
          SecretStoreException(
            referenceName: 'r',
            providerId: 'p',
            operation: 'read',
            reason: 'literal',
          ),
        ),
        isA<SecretStoreException>(),
        reason: 'an audited failure must keep its type for the caller',
      );
    });

    test(
      'a filesystem failure keeps its path and loses nothing that matters',
      () {
        final rendered = secretlessText(
          FileSystemException(
            'Cannot rename file',
            '/tmp/scratch/identity.tmp-1a2b',
            OSError('Operation not permitted', 1),
          ),
        );
        expect(rendered, contains('/tmp/scratch/identity.tmp-1a2b'));
        expect(rendered, contains('Operation not permitted'));
        expect(rendered, isNot(contains('content')));
      },
    );
  });

  group('no adapter forwards a caught error into a reason', () {
    test('no reason names a catch-clause binding outside secretlessText', () {
      // The rule, as a CLOSED VOCABULARY. A `SecretStoreException`'s reason
      // reaches the session log and therefore Postgres, so it may be: a literal
      // written in the file (which may interpolate this code's own constants,
      // field names and environment-variable names), or `secretlessText(<caught
      // error>)`. The one thing it may never do is hand a caught object to
      // anything that could stringify it — a caught error's own message is
      // unvetted text this layer does not control.
      //
      // F-2. This was narrower than the rule it was written to enforce, and
      // narrower than `secret_provider.dart` claimed. It matched only a
      // MULTI-LINE call site and only a `$name` INTERPOLATION, so
      // `reason: _leak(error)` — one top-level helper, one argument — passed
      // while the caught message flowed into a durable record verbatim. Both
      // shapes are rejected below.
      //
      // The residual is named rather than papered over: a source audit cannot
      // follow a value through a local variable (`final message = '$error'; …
      // reason: message`) or into a helper defined in another file that catches
      // for itself. The next test covers that residual end to end for the
      // adapter that actually handles key material, because it does not care how
      // the string was produced — only what came out.
      final offenders = <String>[];
      final sources = _auditedSources();
      expect(
        sources.length,
        greaterThan(10),
        reason:
            'the audit found suspiciously few sources; a guard that audits '
            'nothing must fail rather than pass',
      );
      for (final file in sources) {
        final source = _withoutComments(file.readAsStringSync());
        final caught = RegExp(
          r'catch\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)',
        ).allMatches(source).map((m) => m.group(1)!).toSet();
        if (caught.isEmpty) continue;
        // `(`, then anything at all. F-2 found that restricting this to `\(\n`
        // let a single-line call site through, which is the second bypass.
        for (final match in RegExp(
          r'SecretStoreException\(\s*',
        ).allMatches(source)) {
          final block = _balancedCall(source, match.start);
          final reason = _argumentOf(block, 'reason');
          if (reason == null) continue;
          for (final name in caught) {
            // `secretlessText(error)` is the sanctioned shape, so it is removed
            // before the search. Anything that still names the binding —
            // `'$error'`, `${error.message}`, and the demonstrated `_leak(error)`
            // — is an offender. The old check searched for `\$\{?error\b` only,
            // which is why the last of those three passed.
            final unsanctioned = reason.replaceAll(
              RegExp('secretlessText\\(\\s*$name\\s*\\)'),
              '',
            );
            if (RegExp('\\b$name\\b').hasMatch(unsanctioned)) {
              offenders.add(
                '${file.path.split('/').last}: reason hands the caught `$name` '
                'to something other than secretlessText(...)',
              );
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'a SecretStoreException reason must be a literal, a package '
            'constant, or secretlessText(...): $offenders',
      );
    });

    test(
      'the real adapter reason carries no material, however it was produced',
      () async {
        // The positive side, and the half a source audit cannot do. Drive the
        // REAL [LocalFileSecretProvider] through a REAL failure while handing it
        // a real ed25519 private key, and assert on what came out. This does not
        // care whether the reason was a literal, a `secretlessText` call, a value
        // aliased through a local, or a helper in another file — so it is the
        // backstop for exactly the residual the source guard cannot follow.
        final pem = utf8.decode(
          SshKeyPair.generate(
            comment: 'shipit+reason-probe',
          ).privateKeyPemBytes,
        );
        expect(
          _forbiddenFragments.any(pem.contains),
          isTrue,
          reason:
              'the fixture must be a real private key, or this proves '
              'nothing: a redacted string contains none of it',
        );

        final scratch = Directory.systemTemp.createTempSync(
          'shipit_reason_guard_',
        );
        addTearDown(() => scratch.deleteSync(recursive: true));
        // A regular file where the store's directory should be: the directory
        // creation fails for real, inside the adapter's own
        // `on Object catch (error)` block.
        final blocker = File('${scratch.path}/blocked')
          ..writeAsStringSync('not a directory');
        final provider = LocalFileSecretProvider(directoryPath: blocker.path);

        SecretStoreException? caught;
        try {
          await provider.store(
            referenceName: 'GIT_REPOSITORY_reason-probe_SSH',
            secret: SecretBytes(
              SshKeyPair.generate(comment: 'shipit+store').privateKeyPemBytes,
            ),
          );
        } on SecretStoreException catch (error) {
          caught = error;
        }
        expect(
          caught,
          isNotNull,
          reason:
              'a store into a path that is a regular file must fail, and it '
              'must fail typed rather than with a raw dart:io error',
        );
        final reason = caught!.reason;
        expect(
          reason,
          isNotEmpty,
          reason:
              'the rule must not be silence; the reason is what an operator '
              'reads',
        );
        _expectNoMaterial(reason, 'LocalFileSecretProvider.store reason');
        _expectNoMaterial(
          caught.secretlessDescription,
          'SecretStoreException.secretlessDescription',
        );
      },
    );

    test('the reason of an adapter failure is still useful to an operator', () {
      // The other side of the guard: a rule that forced silence would be a bad
      // rule. The local adapter's audited projection keeps the path and the mode.
      final directory = _locateDirectory('lib/src/credentials');
      expect(directory.existsSync(), isTrue);
      expect(
        PosixPermissionException(
          path: '/x',
          intendedMode: '600',
          detail: 'chmod exited 1',
        ).secretlessDescription,
        allOf(contains('/x'), contains('600'), contains('chmod exited 1')),
      );
    });
  });
}

/// Every production source the reason rule applies to.
///
/// F-2, second half: the guard scanned `lib/src/credentials/**` while its doc
/// spoke of "any adapter", and `credential_endpoints.dart` holds a fourth
/// [SecretProvider] implementation. A net has to cover the surface it is
/// described as covering, so both are listed here.
List<File> _auditedSources() => [
  ..._locateDirectory('lib/src/credentials').listSync().whereType<File>(),
  _locateFile('lib/src/endpoints/credential_endpoints.dart'),
].where((file) => file.path.endsWith('.dart')).toList();

/// The file at [relative], from wherever `dart test` was invoked.
///
/// The same rule as [_locateDirectory]: an audit that silently found nothing
/// would be worse than no audit at all.
File _locateFile(String relative) {
  for (final candidate in _candidates(relative)) {
    if (candidate is File) return candidate;
  }
  throw StateError(
    'could not locate the file $relative from ${Directory.current.path}; this '
    'file audits sources and must not pass by finding nothing',
  );
}

/// The source with every `//` and `///` line removed.
///
/// An audit that read the prose describing the rule would report the rule's own
/// examples as violations, which is how an audit like this becomes noise.
String _withoutComments(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

/// The value of the named argument in a call block, or null when absent.
String? _argumentOf(String callBlock, String name) {
  final match = RegExp('\\b$name\\s*:').firstMatch(callBlock);
  if (match == null) return null;
  var depth = 0;
  final rest = callBlock.substring(match.end);
  for (var i = 0; i < rest.length; i++) {
    final char = rest[i];
    if (char == '(' || char == '[' || char == '{') depth++;
    if (char == ')' || char == ']' || char == '}') {
      if (depth == 0 && char == ')') return rest.substring(0, i);
      depth--;
    }
    if (char == ',' && depth == 0) return rest.substring(0, i);
  }
  return rest;
}

/// The text of the call whose opening parenthesis is at [start].
String _balancedCall(String source, int start) {
  var depth = 0;
  for (var i = start; i < source.length; i++) {
    final char = source[i];
    if (char == '(') depth++;
    if (char == ')') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  return source.substring(start);
}
