import 'dart:convert';
import 'dart:io';

import 'package:control_plane_client/src/protocol/protocol.dart';
import 'package:control_plane_server/src/generated/minted_credential_view.dart'
    as server_model;
// `serverpod`, not `serverpod_serialization` directly: the latter is a
// transitive dependency, and `depend_on_referenced_packages` is right — an
// analyzer warning in a security test is a warning nobody reads. `serverpod`
// re-exports both symbols used below (`SerializationManager` and
// `DeserializationTypeNotFoundException`).
import 'package:serverpod/serverpod.dart'
    show DeserializationTypeNotFoundException, SerializationManager;
import 'package:test/test.dart';

/// PROOF for the blocker "No deserialization found for type dynamic", at the
/// boundary where it actually happens.
///
/// WHY THIS FILE IS NOT AN IN-PROCESS TEST. The failure never happened in Dart.
/// `CredentialEndpoints.generate` returned a real `Map<String, dynamic>`, the
/// server serialised it correctly, the bytes went over the wire correctly, and
/// the **generated client's deserializer** threw while parsing a correct
/// response. An in-process test that calls the endpoint and inspects the
/// returned object passes at the broken revision, because the broken revision's
/// in-process behaviour is perfectly correct — which is exactly why two review
/// cycles approved the map signatures and every gate was green.
///
/// WHY A GENERATED CLIENT AND NOT A SERIALIZATION MANAGER. The failing frame is
/// `Protocol.deserialize<Map<String, dynamic>>` — the branch the GENERATOR
/// emitted for a map type, whose body is
/// `deserialize<String>(k)` / `deserialize<dynamic>(v)`. That branch exists
/// only in generated code. Calling an equivalent method on a hand-built
/// `SerializationManager` would test the framework rather than this
/// repository's contract, and would keep passing no matter what the endpoint
/// declared.
///
/// WHY THE FIXTURES ARE CAPTURED, NOT WRITTEN. `_live_map_returning_body.json`
/// and `_live_typed_returning_body.json` were captured byte-for-byte over HTTP
/// from the running QA stack on 2026-10-09, against endpoints that already
/// existed at `cf1b210`:
///
/// ```
/// curl -s -X POST http://localhost:8081/api/defectEndpoints/list \
///      -H 'Content-Type: application/json' -d '{}'
///   -> {"defects":[],"totalCount":0}
/// curl -s -X POST http://localhost:8081/api/productRegistryEndpoints/listProducts \
///      -H 'Content-Type: application/json' -d '{}'
///   -> [{"__className__":"ProductView",…}]
/// ```
///
/// The first is a `Map<String, dynamic>` endpoint's body and the second a typed
/// model's body, from the same server process, seconds apart. The difference is
/// the whole defect: the map body carries no `__className__`, so the client
/// cannot dispatch it to a class and falls through to `deserialize<dynamic>`.
///
/// A test that built its own body from its own expectations would prove that
/// the expectation is self-consistent. These bodies were produced by a server
/// this repository did not choose the shape of, and they are read below with
/// the generated client exactly as the browser read them.
void main() {
  group('a Map<String, dynamic> response body cannot be read by the client', () {
    test('the live map-shaped body reproduces the browser failure verbatim', () {
      // THE REGRESSION. At cf1b210 `credentialEndpoints.generate` declared
      // `Future<Map<String, dynamic>>`, so the generated client called
      // `callServerEndpoint<Map<String, dynamic>>` and a body of this shape
      // arrived at the deserializer declared as a map. Reproduced here from the
      // live body, not from a reimplementation of it.
      final body = _fixture('live_map_returning_body.json');

      // ASSERTED AGAINST `deserialize<dynamic>`, NOT AGAINST
      // `decode<Map<String, dynamic>>`, and the change is forced rather than
      // cosmetic.
      //
      // The generator emits `if (t == Map<String, dynamic>)` into
      // `Protocol.deserialize` ONLY WHILE SOME ENDPOINT DECLARES THAT RETURN
      // TYPE. Once the last map-returning endpoint is typed — which is what
      // this correction does, all twenty-two of them — the branch is gone, and
      // `decode<Map<String, dynamic>>(body)` now throws
      // `No deserialization found for type Map<String, dynamic>`, a different
      // message about a different thing.
      //
      // `deserialize<dynamic>` is where that branch DELEGATED, so it is the
      // actual browser failure and it is permanently assertable. Asserting it
      // directly makes this test STRONGER than the `decode` form: it can no
      // longer pass because a map branch exists and happens to handle the body,
      // and it cannot be made to pass by choosing a friendlier fixture. The
      // `decode<Map<String, dynamic>>` form is kept as a second assertion
      // below so the disappearance of the branch is itself pinned.
      expect(
        () => Protocol().deserialize<dynamic>(jsonDecode(body)),
        throwsA(
          isA<DeserializationTypeNotFoundException>().having(
            (e) => e.message,
            'message',
            contains('No deserialization found for type dynamic'),
          ),
        ),
        reason:
            'Serverpod registers no deserializer for `dynamic`, so the '
            'generated map branch that `Protocol.deserialize` emits for a '
            '`Map<String, dynamic>` endpoint throws on the first value it '
            'reads. That throw IS the browser failure reported from the QA '
            'stack, and it is what makes an untyped endpoint unusable rather '
            'than merely untidy.',
      );

      expect(
        () => Protocol().decode<Map<String, dynamic>>(body),
        throwsA(isA<DeserializationTypeNotFoundException>()),
        reason:
            'and the generated client no longer even HAS a '
            '`Map<String, dynamic>` branch: the generator emits one per '
            'map-returning endpoint, and there are none left. This assertion '
            'fails if a map-returning endpoint is added back.',
      );
    });

    test('the live typed body from the same server reads without complaint', () {
      // The control. Same server, same client, same deserializer, seconds
      // apart — a body WITH `__className__` decodes, a body without does not.
      // Without this pair the test above could pass for the wrong reason: a
      // broken fixture, a broken `Protocol`, a Dart version change.
      //
      // Decoded as `List<ProductView>` — the type the generated client actually
      // declares for `productRegistryEndpoints.listProducts` — not as
      // `List<Object?>`. `Protocol.deserialize` is a table of concrete
      // generated types and has no entry for `Object?`, so asking for one
      // would fail this control too and prove nothing.
      final decoded = Protocol().decode<List<ProductView>>(
        _fixture('live_typed_returning_body.json'),
        List<ProductView>,
      );

      expect(decoded, isNotEmpty);
      // Asserted by VALUE, not by shape: if the server stopped emitting these
      // fields the control would still pass on `isNotEmpty` alone.
      expect(decoded.first.productId, 'shipit-platform');
      expect(decoded.first.name, 'ShipIt Platform');
      expect(decoded.first.state, 'registered');
    });

    test('the map fixture is a real map body, which is why it cannot be read', () {
      // The fixture must be the REAL artefact, not a plausible-looking one. An
      // untyped JSON object with no `__className__` is precisely what
      // `SerializationManager.encodeForProtocol` produces for a
      // `Map<String, dynamic>`: `_toEncodable`'s `Map<String, dynamic>` branch,
      // which has no class name to add because a map is not a model.
      final decoded = jsonDecode(_fixture('live_map_returning_body.json'));

      expect(decoded, isA<Map<String, Object?>>());
      expect(
        decoded.containsKey('__className__'),
        isFalse,
        reason:
            'a Map<String, dynamic> response is serialised without a '
            '__className__; that absence is what makes it undeserialisable by '
            'the generated client',
      );
    });
  });

  group('the credential endpoints now return models the client can read', () {
    test('a mint response body deserialises into the typed model', () {
      // THE FIX, at the wire. `credentialEndpoints.generate` now returns
      // `MintedCredentialView`, so the generated client declares
      // `callServerEndpoint<MintedCredentialView>` and the body carries
      // `__className__`.
      //
      // This body is constructed rather than captured, because the QA stack
      // runs merged main at the broken revision and cannot serve the fixed
      // shape until it is redeployed. It is built with the same
      // `SerializationManager.encodeForProtocol` the server uses at
      // `server.dart:516`, and the fixture pair above establishes that the
      // shape difference it depends on is the real one from a real server.
      final body = SerializationManager.encodeForProtocol(
        server_model.MintedCredentialView(
          credentialId: 'cred-abc',
          productId: 'acme',
          repositoryId: 'acme-api',
          publicKey:
              'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExample shipit+acme-api',
          fingerprint: 'SHA256:0badc0de0000000000000000000000000000000000000',
          algorithm: 'ed25519',
          referenceName: 'GIT_REPOSITORY_ACME_API_SSH',
          status: 'generated',
          hostKeyStatus: 'unknown',
          host: 'git@github.com:acme/api.git',
        ),
      );

      expect(
        jsonDecode(body),
        containsPair('__className__', 'MintedCredentialView'),
        reason:
            'the fixed endpoint returns a generated model, and Serverpod tags '
            'a model body with __className__ so the client can dispatch it',
      );

      // Decoded into the CLIENT's model, not the server's. They are separate
      // generated classes in separate packages and `Protocol.deserialize`
      // returns the client's; decoding into the server's type throws a
      // `TypeError` about `_MintedCredentialViewImpl`, which is a different
      // failure from the one under test and would mask it. The endpoint's
      // declared return type is what makes the CLIENT's class the one that
      // matters: the browser holds that one.
      final decoded = Protocol().decode<MintedCredentialView>(
        body,
        MintedCredentialView,
      );

      expect(decoded.credentialId, 'cred-abc');
      // The whole point of the call. If either were dropped from the model the
      // flow would still "work" and the operator would have nothing to install,
      // so they are asserted by value rather than by field count.
      expect(decoded.publicKey, startsWith('ssh-ed25519 '));
      expect(decoded.fingerprint, startsWith('SHA256:'));
    });

    test('that same body still cannot be read as a bare map', () {
      // Guards the DIRECTION of the change. If someone reverts the endpoint to
      // a map return type, the generated client reverts with it and this pair
      // of tests goes red together rather than one silently passing.
      final body = SerializationManager.encodeForProtocol(
        server_model.MintedCredentialView(
          credentialId: 'cred-abc',
          productId: 'acme',
          repositoryId: 'acme-api',
          publicKey: 'ssh-ed25519 AAAAExample shipit+acme-api',
          fingerprint: 'SHA256:0badc0de',
          algorithm: 'ed25519',
          referenceName: 'GIT_REPOSITORY_ACME_API_SSH',
          status: 'generated',
          hostKeyStatus: 'unknown',
        ),
      );

      Object? result;
      Object? thrown;
      try {
        result = Protocol().decode<Map<String, dynamic>>(body);
      } on Object catch (error) {
        thrown = error;
      }

      expect(
        result is Map<String, dynamic>,
        isFalse,
        reason:
            'a body tagged with __className__ must not be readable as a bare '
            'map; that is what the endpoint\'s typed return type buys',
      );
      expect(
        thrown,
        isNotNull,
        reason:
            'reading a model-tagged body as Map<String, dynamic> must not '
            'succeed. If it does, the map branch of Protocol.deserialize has '
            'changed and the regression test above is no longer reproducing '
            'the reported defect.',
      );
    });
  });

  group('neither wire type can carry private material', () {
    test('no credential wire type has a field that could hold key bytes', () {
      // The invariant this work item exists to protect. `SecretBytes` has no
      // serialisable representation, so it cannot become a generated field by
      // accident — but a `String` or `ByteData` could, and that would reach the
      // client through the very field list this correction just made the
      // contract.
      final byteCarryingTypes = const {
        'SecretBytes',
        'ByteData',
        'Uint8List',
        'List<int>',
      };

      for (final model in const [
        (MintedCredentialView, _mintedCredentialViewSource),
        (
          CredentialAccessVerificationView,
          _accessVerificationViewSource,
        ),
      ]) {
        for (final field in _declaredFields(model.$1, model.$2)) {
          expect(
            byteCarryingTypes.contains(field.type),
            isFalse,
            reason: '${model.$1}.${field.name} is ${field.type}',
          );
          expect(
            _privateMaterialNames.contains(field.name.toLowerCase()),
            isFalse,
            reason: '${model.$1}.${field.name} looks like private material',
          );
        }
      }
    });

    test('both wire types carry exactly the fields the client reads', () {
      // The other direction of the same property: a field the client reads but
      // the model lacks is a crash in the browser; one the model has and the
      // client never reads is surface nobody reviewed. An exact set, so a
      // change in either direction fails.
      expect(
        _declaredFields(
          MintedCredentialView,
          _mintedCredentialViewSource,
        ).map((f) => f.name).toSet(),
        {
          'credentialId',
          'productId',
          'repositoryId',
          'publicKey',
          'fingerprint',
          'algorithm',
          'referenceName',
          'status',
          'hostKeyStatus',
          'host',
        },
        reason:
            'MintedCredentialView is the complete set of fields that may leave '
            'the process for a mint. Adding one is a leak-policy decision, not '
            'a convenience.',
      );

      expect(
        _declaredFields(
          CredentialAccessVerificationView,
          _accessVerificationViewSource,
        ).map((f) => f.name).toSet(),
        {
          'credentialId',
          'status',
          'canReachRepository',
          'secretMaterialRemoved',
          'hostKeyConfirmationProvenance',
          'failureReason',
          'lastVerifiedAt',
          'observedHostKeyFingerprint',
        },
      );
    });
  });
}

/// Field NAMES that would denote private material if they appeared on a
/// serialisable model.
///
/// AN EXACT SET, NOT A SUBSTRING TEST. The first version of this used
/// `name.contains('secret')`, which fails
/// `CredentialAccessVerificationView.secretMaterialRemoved` — a `bool` whose
/// entire meaning is that the private half is GONE. A name guard that rejects
/// the field asserting removal is a guard that gets deleted to make a test
/// pass, so it is written as an enumeration instead.
/// `secretMaterialRemoved` is safe precisely because its TYPE is checked
/// separately: a `bool` cannot carry a key, whatever it is called.
const _privateMaterialNames = {
  'privatekey',
  'privatekeypem',
  'privatekeypembytes',
  'privateseed',
  'secretbytes',
  'secretmaterial',
  'privatehalves',
};

const _mintedCredentialViewSource = 'minted_credential_view';
const _accessVerificationViewSource = 'credential_access_verification_view';

/// Reads a captured response body off disk.
///
/// Committed rather than constructed, because a constructed body can only ever
/// confirm that the constructor agrees with the assertion. See the file header
/// for how these were captured and from where.
String _fixture(String name) =>
    File('test/fixtures/credential_endpoint_wire/$name').readAsStringSync();

/// One declared field of a generated serialisable model.
class _Field {
  _Field(this.name, this.type);

  final String name;
  final String type;
}

/// The fields the SERVER's generated model declares, read from its own source.
///
/// Reads the GENERATED file rather than the schema for the same reason the rest
/// of this file reads the generated client: the schema is intent, the generated
/// class is the contract, and only the second one is what the endpoint can
/// actually return.
///
/// The filename is named at the call site rather than derived from the class
/// name. A snake_case transform looks clever and is wrong in the interesting
/// case — acronyms need a rule about runs of capitals — and the first version
/// produced `m_intedc_redentialv_iew` for `MintedCredentialView`. It also
/// duplicated a naming rule the generator already owns, so it could drift
/// silently. One string to check when the generator renames, and no second
/// algorithm to be wrong.
List<_Field> _declaredFields(Type model, String generatedFile) {
  final source = File('lib/src/generated/$generatedFile.dart');
  final name = model.toString().split('.').last;

  expect(
    source.existsSync(),
    isTrue,
    reason: 'no generated source for $name at ${source.path}',
  );

  final fields = <_Field>[];
  // Plain `String credentialId;` fields on the abstract class — NOT the `final`
  // fields of the `_XImpl` class further down and NOT the constructor
  // parameters. The first version of this pattern assumed `final` and matched
  // nothing; the assertion below is why that failed loudly instead of passing
  // vacuously when the generator changes its field syntax.
  final declaration = RegExp(
    r'^\s{2}(?!final\b)(\S+)\s+(\w+);$',
    multiLine: true,
  );
  for (final match in declaration.allMatches(source.readAsStringSync())) {
    fields.add(_Field(match.group(2)!, match.group(1)!));
  }

  expect(
    fields,
    isNotEmpty,
    reason: 'no fields parsed out of ${source.path}; the pattern went stale',
  );
  return fields;
}
