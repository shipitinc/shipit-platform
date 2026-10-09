import 'dart:convert';
import 'dart:io';

import 'package:control_plane_client/src/protocol/protocol.dart';
import 'package:test/test.dart';

/// The regression canary for "No deserialization found for type dynamic",
/// written so it COMPILES AND RUNS AGAINST BOTH REVISIONS.
///
/// WHY IT IS A SEPARATE FILE from `credential_endpoint_wire_test.dart`. That
/// file imports `MintedCredentialView` and
/// `CredentialAccessVerificationView`, which do not exist at `cf1b210` — so at
/// the broken revision it fails to LOAD, which demonstrates nothing except that
/// the type is new. This file references no new type. At `cf1b210` it compiles,
/// runs, and FAILS on the assertion below, which is the proof the dispatch
/// asked for: the failure is the declared return type, not a missing import.
///
/// THE DEFECT. `Protocol.deserialize<Map<String, dynamic>>` — a branch the
/// GENERATOR emits — reads the map's values with `deserialize<dynamic>(v)`,
/// and Serverpod registers no deserializer for `dynamic`. So any endpoint
/// declared `Future<Map<String, dynamic>>` produces a client that throws
/// `No deserialization found for type dynamic` while parsing a perfectly
/// correct response body. The mint succeeds on the server; the browser reports
/// a failure. `dart analyze`, `serverpod generate` and the whole unit suite are
/// green at that revision, because none of them crosses the wire.
///
/// WHY THE FIXTURE IS CAPTURED AND NOT WRITTEN. `_live_map_returning_body.json`
/// was captured byte-for-byte over HTTP from the running QA stack on
/// 2026-10-09, from an endpoint whose declared return type at `cf1b210` was
/// `Map<String, dynamic>`:
///
/// ```
/// curl -s -X POST http://localhost:8081/api/defectEndpoints/list \
///      -H 'Content-Type: application/json' -d '{}'
///   -> {"defects":[],"totalCount":0}
/// ```
///
/// A body this test constructed itself could only prove that its own
/// constructor agrees with its own assertion.
void main() {
  group('the credential endpoints must not declare a raw map return type', () {
    for (final method in const ['generate', 'verifyAccess']) {
      test('credentialEndpoints.$method returns a serialisable model', () {
        final declared = _declaredClientReturnType(method);

        expect(
          declared,
          isNot('Map<String, dynamic>'),
          reason:
              'credentialEndpoints.$method declares `$declared` on the wire. '
              'The generated client mirrors that type, so '
              '`Protocol.deserialize` will read the response body with '
              '`deserialize<dynamic>(v)`, for which Serverpod has no entry — '
              'the browser throws "No deserialization found for type dynamic" '
              'and no field of a successful mint is ever read. Every gate '
              'passes at this revision because a map is valid Dart and '
              'generates cleanly; only the wire boundary catches it.\n'
              'Return a generated Serverpod model instead. See '
              'credential_endpoint_wire_test.dart for the reproduction.',
        );

        expect(
          declared,
          matches(RegExp(r'^\w+\??$')),
          reason:
              'credentialEndpoints.$method declares `$declared`, which is not a '
              'single named type. A return type the generated deserializer has '
              'no entry for is the defect; a list or map return type is the '
              'same defect wearing a different hat.',
        );
      });
    }
  });

  group('the defect itself, reproduced from a captured live response', () {
    test(
      'a map body read as Map<String, dynamic> throws the browser error',
      () {
        // The verbatim failure, from a real server's real response body.
        expect(
          () => Protocol().decode<Map<String, dynamic>>(
            _fixture('live_map_returning_body.json'),
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('No deserialization found for type dynamic'),
            ),
          ),
        );
      },
    );

    test('that same body is a well-formed JSON object with no class name', () {
      // WHY IT CANNOT BE READ, stated as a property of the artefact rather than
      // of an exception. `SerializationManager.encodeForProtocol` applied to a
      // `Map<String, dynamic>` hits `_toEncodable`'s map branch, which adds no
      // `__className__` because a map is not a model — so the client has nothing
      // to dispatch on.
      final decoded = jsonDecode(_fixture('live_map_returning_body.json'));

      expect(decoded, isA<Map<String, Object?>>());
      expect(
        decoded.containsKey('__className__'),
        isFalse,
        reason:
            'a map response carries no __className__; that absence is the '
            'whole cause, and a fixture that did carry one would stop '
            'reproducing the reported defect',
      );
    });
  });
}

/// The return type the GENERATED CLIENT declares for
/// `credentialEndpoints.$method`.
///
/// Reads the generated file rather than importing a Dart symbol, and that is
/// deliberate on both sides. Reading the source is what lets this file compile
/// at the broken revision, where the typed model does not exist. And the
/// generated client is the artefact the browser actually runs: the server's own
/// signature is not evidence about what the client will do with the response.
String _declaredClientReturnType(String method) {
  final source = File(
    '../../packages/control_plane_client/lib/src/protocol/client.dart',
  );

  expect(
    source.existsSync(),
    isTrue,
    reason:
        'no generated client at ${source.path}. This suite is about the wire '
        'contract, so a missing client is a failure of the thing under test, '
        'not of the test.',
  );

  final text = source.readAsStringSync();

  // Scoped to the credential endpoints' own class first. Without the scope the
  // pattern matches the first `Future<X> <anyMethod>(` in a 1200-line file,
  // which is `homeEndpoints.overview` — a test that audits the wrong endpoint
  // while reading as though it audits the right one. The scope is asserted
  // non-empty for the same reason.
  final classStart = text.indexOf('class EndpointCredentialEndpoints');
  expect(
    classStart,
    greaterThan(-1),
    reason:
        'no EndpointCredentialEndpoints in ${source.path}. The generator '
        'renamed it, so this file now audits nothing.',
  );

  final scoped = text.substring(classStart);
  // NOT a raw string. `r'…$method…'` does not interpolate in Dart, so the
  // first version of this pattern searched for the literal text `$method` and
  // matched nothing — while the "must not silently audit nothing" assertion
  // below correctly turned that into a red test rather than a false green.
  final signature = RegExp(
    'Future<(.+?)>\\s+$method\\s*\\(',
    multiLine: true,
  ).firstMatch(scoped);

  expect(
    signature,
    isNotNull,
    reason:
        'no generated method credentialEndpoints.$method in ${source.path}. '
        'If the generator renamed or restructured it, this audit is silently '
        'auditing nothing and must fail rather than pass vacuously.',
  );

  // The generator qualifies model types with a positional import alias
  // (`_i3.MintedCredentialView`). Stripped so the assertion below reads the
  // type rather than the generator's numbering — and re-numbered on every
  // generation, since the aliases are positional.
  // The generator qualifies model types with a positional import alias
  // (`_i3.MintedCredentialView`). Stripped on EVERY type argument, not just a
  // leading one: `List<_i8.FeatureRequestSummaryView>` has the alias in the
  // middle, and stripping only the front of the string left
  // `_i8.FeatureRequestSummaryView` to fail the "is a single named type"
  // assertion with a confusing message about a type that was perfectly fine.
  return signature!.group(1)!.trim().replaceAll(RegExp(r'_\w+\.'), '');
}

String _fixture(String name) =>
    File('test/fixtures/credential_endpoint_wire/$name').readAsStringSync();
