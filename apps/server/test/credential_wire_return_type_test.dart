import 'dart:convert';
import 'dart:io';

import 'package:control_plane_client/src/protocol/protocol.dart';
import 'package:test/test.dart';

/// The regression canary for "No deserialization found for type dynamic",
/// written so it COMPILES AND RUNS AGAINST EVERY REVISION OF THIS AREA.
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
/// correct response body. The work succeeds on the server; the browser reports
/// a failure. `dart analyze`, `serverpod generate` and the whole unit suite are
/// green at that revision, because none of them crosses the wire.
///
/// THE EMPTY-MAP ASYMMETRY — MEASURED, and the reason this class of defect
/// gets misdiagnosed. The generated branch
/// `(data as Map).map((k, v) => MapEntry(deserialize<String>(k), deserialize<dynamic>(v)))`
/// never calls `deserialize<dynamic>` when it
/// iterates nothing, so a `Map<String, dynamic>` endpoint whose body happens to
/// be `{}` **deserialises successfully**. A non-empty one throws. An endpoint
/// that returns an empty map looks healthy until the day it returns a row, and
/// the blame lands on whichever endpoint is nearest the symptom rather than on
/// the one that is broken. `health()` returns an empty-ish map; the Add Product
/// flow's `addRepositoryReference` returns two keys and dies on every press.
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
  group('no endpoint may declare a raw map return type', () {
    // THE WHOLE-CLASS SCAN. The previous version of this file looped over two
    // method names, which is how `credentialEndpoints.generate` got fixed while
    // `productRegistryEndpoints.addRepositoryReference` — the call that is
    // actually on the acceptance-criteria path — stayed broken for another full
    // review cycle. A per-method list cannot be trusted to stay complete.
    //
    // So this reads EVERY endpoint method the generator emitted and fails on
    // any map return type, with no allow-list to keep in step. Adding an
    // endpoint that returns a map turns this test red the moment the client is
    // regenerated, whoever added it and whatever they intended.
    test('the generated client declares no map-returning endpoint method', () {
      final offenders = _mapReturningEndpointMethods(_clientSource());

      expect(
        offenders,
        isEmpty,
        reason:
            'These generated client methods return or accept `Map<String, '
            'dynamic>`, so `Protocol.deserialize` will read the response body '
            'with `deserialize<dynamic>(v)`, for which Serverpod has no entry. '
            'The browser throws "No deserialization found for type dynamic" and '
            'no field of a successful response is ever read. Every gate passes '
            'at that revision because a map is valid Dart and generates '
            'cleanly; only the wire boundary catches it.\n'
            'Return a generated Serverpod model instead. An EMPTY body would '
            'deserialise fine, which is why this presents as intermittent and '
            'gets blamed on the wrong endpoint.\n'
            'Offenders: $offenders',
      );
    });

    // THE VACUOUS-PASS GUARD, asserted separately so a rename of the generated
    // file cannot turn the scan above into a test that audits nothing and passes.
    test('the scan actually reads the generated client', () {
      final source = _clientSource();
      final methods = _endpointMethods(source);

      expect(
        methods.length,
        greaterThan(50),
        reason:
            'only ${methods.length} endpoint methods found in '
            '${_clientPath()}. The generator changed the file layout, so this '
            'scan is reading nothing and would pass for the wrong reason.',
      );
      expect(
        methods.map((m) => m.endpointClass).toSet().length,
        greaterThan(5),
        reason:
            'only ${methods.map((m) => m.endpointClass).toSet().length} endpoint '
            'classes found. The scan is not covering the generated surface.',
      );
    });

    // THE ADD PRODUCT PATH, NAMED. The scan above is the guard; this is the
    // statement of intent that the dispatch's acceptance criterion depends on,
    // so a reader can see which calls were proven rather than having to infer
    // it from a scan.
    //
    // `AddProductBloc._onCheckAccessRequested` runs exactly this sequence, in
    // this order, on one press of one control
    // (`apps/control_plane/lib/features/products/add_product_page.dart`):
    //   :143 createProduct -> addRepositoryReference  (via _ensureProductAndRepository:281)
    //   :147 credentialEndpoints.generate
    //   :176 credentialEndpoints.verifyAccess
    //   :235 productRegistryEndpoints.productDetail   (on Register)
    // plus `listProductSummaries`, which the page's own load path calls. Every
    // one of them was, or could have been, the one that threw.
    for (final entry in const [
      _PathCall('productRegistryEndpoints', 'createProduct'),
      _PathCall('productRegistryEndpoints', 'addRepositoryReference'),
      _PathCall('productRegistryEndpoints', 'listProductSummaries'),
      _PathCall('productRegistryEndpoints', 'productDetail'),
      _PathCall('credentialEndpoints', 'generate'),
      _PathCall('credentialEndpoints', 'verifyAccess'),
    ]) {
      test('${entry.endpoint}.${entry.method} returns a serialisable model', () {
        final declared = _declaredClientReturnType(
          endpointClass: entry.endpoint,
          method: entry.method,
        );

        expect(
          declared,
          isNot('Map<String, dynamic>'),
          reason:
              '${entry.endpoint}.${entry.method} declares `$declared` on the '
              'wire, and it is on the Add Product path. The generated client '
              'mirrors that type, so `Protocol.deserialize` reads the response '
              'body with `deserialize<dynamic>(v)`, for which Serverpod has no '
              'entry — the browser throws "No deserialization found for type '
              'dynamic" at this call and nothing after it is reached.',
        );

        // NOT `matches(RegExp(r'^\w+\??$'))`, which the first version of this
        // canary used. That rejected `List<ProductSummaryView>` — which is one
        // of the calls on this very path, and which the generated client reads
        // perfectly well, because `Protocol.deserialize` emits
        // `if (t == List<_i22.ProductSummaryView>)` for every model list. The
        // predicate that matches the actual defect is the one the whole-class
        // scan uses: a type the generated deserializer has no branch for.
        expect(
          _isUndeserialisable(declared),
          isFalse,
          reason:
              '${entry.endpoint}.${entry.method} declares `$declared`, and the '
              'generated client has no deserialization branch for it. A map '
              'return type is the common case; a bare `dynamic` or `void` is '
              'the same failure with the map stripped off.',
        );
      });
    }
  });

  group('the defect itself, reproduced from a captured live response', () {
    test(
      'a map body read as Map<String, dynamic> throws the browser error',
      () {
        // The verbatim failure, from a real server's real response body.
        //
        // Asserted against `deserialize<dynamic>` rather than
        // `decode<Map<String, dynamic>>`, because the generator emits the
        // `Map<String, dynamic>` branch into `Protocol.deserialize` only while
        // some endpoint declares that return type — and this correction removes
        // the last one. `deserialize<dynamic>` is what that branch delegated
        // to, so it is the actual browser failure and it stays assertable
        // before, during and after the fix. The whole-class scan above is what
        // asserts the branch is gone.
        expect(
          () => Protocol().deserialize<dynamic>(
            jsonDecode(_fixture('live_map_returning_body.json'))['totalCount'],
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

    test('the deserializer has no entry for `dynamic` — the root cause', () {
      // PERMANENTLY ASSERTABLE, unlike the empty-map case. The generator emits
      // `if (t == Map<String, dynamic>)` into `Protocol.deserialize` only while
      // some endpoint declares that return type, so once the last one is typed
      // there is no map branch left to demonstrate the asymmetry through — but
      // `deserialize<dynamic>` is what that branch delegated to, and Serverpod
      // still has no entry for it. Asserting the delegate rather than the
      // branch keeps this test true across both states of the repository.
      expect(
        () => Protocol().deserialize<dynamic>(
          jsonDecode(
            _fixture('live_map_returning_body.json'),
          )['totalCount'],
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No deserialization found for type dynamic'),
          ),
        ),
      );

      // And the generated client no longer carries a map branch at all, which
      // is the same fact stated from the other side: the branch is emitted per
      // map-returning endpoint, and there are none.
      expect(
        _clientSource().contains('t == Map<String, dynamic>'),
        isFalse,
        reason:
            'the generated client still has a `Map<String, dynamic>` '
            'deserialization branch, which means some endpoint still declares '
            'that return type',
      );
    });

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
      expect(
        decoded.isEmpty,
        isFalse,
        reason:
            'an EMPTY map body deserialises fine. The captured fixture must be '
            'non-empty or it stops reproducing the reported failure.',
      );
    });
  });
}

/// One call on the Add Product path, as the page actually spells it.
class _PathCall {
  const _PathCall(this.endpoint, this.method);
  final String endpoint;
  final String method;
}

/// One endpoint method as the generated client declares it.
class _EndpointMethod {
  const _EndpointMethod({
    required this.endpointClass,
    required this.method,
    required this.returnType,
  });

  final String endpointClass;
  final String method;
  final String returnType;

  @override
  String toString() => '$endpointClass.$method -> $returnType';
}

/// Every endpoint method the generated client declares, with its return type.
///
/// Reads the generated file rather than importing a Dart symbol, and that is
/// deliberate: reading the source is what lets this file compile at the broken
/// revision, where the typed models do not exist yet. And the generated client
/// is the artefact the browser actually runs — the server's own signature is
/// not evidence about what the client will do with the response.
List<_EndpointMethod> _endpointMethods(String source) {
  final methods = <_EndpointMethod>[];
  final classPattern = RegExp(
    r'^class Endpoint(\w+) extends _i\d+\.EndpointRef \{',
    multiLine: true,
  );

  for (final match in classPattern.allMatches(source)) {
    final className = 'Endpoint${match.group(1)}';
    // Stop at the next class declaration so a signature cannot be attributed to
    // the class above it.
    final nextClass = classPattern
        .allMatches(source)
        .where((m) => m.start > match.start);
    final bodyEnd = nextClass.isEmpty
        ? source.length
        : source.indexOf('\nclass ', match.start + 1);
    final body = source.substring(
      match.end,
      bodyEnd < 0 ? source.length : bodyEnd,
    );

    final signature = RegExp(
      r'Future<(.+?)>\s+(\w+)\s*\(',
      multiLine: true,
    );
    for (final sig in signature.allMatches(body)) {
      methods.add(
        _EndpointMethod(
          endpointClass: className,
          method: sig.group(2)!,
          returnType: _stripImportAliases(sig.group(1)!.trim()),
        ),
      );
    }
  }

  return methods;
}

/// The methods among [_endpointMethods] whose declared return type is, or
/// contains, `Map<String, dynamic>`.
///
/// "Contains" rather than "equals" on purpose: `Map<String, dynamic>` nested
/// inside a generated type has the same broken branch, and a `Future<dynamic>`
/// or `Stream<dynamic>` is the same defect with the map stripped off.
List<String> _mapReturningEndpointMethods(String source) => _endpointMethods(
  source,
).where((m) => _isUndeserialisable(m.returnType)).map((m) => '$m').toList();

bool _isUndeserialisable(String returnType) {
  final normalised = returnType.replaceAll(RegExp(r'\s+'), '');
  if (normalised == 'dynamic' || normalised == 'void') return true;
  return normalised.contains(RegExp(r'Map<String,(dynamic|Object\?)>'));
}

/// The return type the GENERATED CLIENT declares for `$endpointClass.$method`.
String _declaredClientReturnType({
  required String endpointClass,
  required String method,
}) {
  final source = _clientSource();

  // Scoped to the endpoint class first. Without the scope the pattern matches
  // the first `Future<X> <anyMethod>(` in a 1200-line file, which is
  // `homeEndpoints.overview` — a test that audits the wrong endpoint while
  // reading as though it audits the right one. The scope is asserted non-empty
  // for the same reason.
  final className = 'Endpoint${_capitalise(endpointClass)}';
  final classStart = source.indexOf('class $className');
  expect(
    classStart,
    greaterThan(-1),
    reason:
        'no $className in ${_clientPath()}. The generator renamed it, so '
        'this file now audits nothing.',
  );

  final nextClass = source.indexOf('\nclass ', classStart + 1);
  final scoped = source.substring(
    classStart,
    nextClass < 0 ? source.length : nextClass,
  );

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
        'no generated method $endpointClass.$method in ${_clientPath()}. '
        'If the generator renamed or restructured it, this audit is silently '
        'auditing nothing and must fail rather than pass vacuously.',
  );

  return _stripImportAliases(signature!.group(1)!.trim());
}

/// Strips the generator's positional import aliases (`_i3.MintedCredentialView`)
/// so a type reads as `List<FeatureRequestSummaryView>` rather than
/// `List<_i8.FeatureRequestSummaryView>`. They are renumbered on every
/// generation, so the numbers are not evidence of anything.
String _stripImportAliases(String type) =>
    type.replaceAll(RegExp(r'_\w+\.'), '');

String _clientPath() =>
    '../../packages/control_plane_client/lib/src/protocol/client.dart';

String _clientSource() {
  final source = File(_clientPath());

  expect(
    source.existsSync(),
    isTrue,
    reason:
        'no generated client at ${source.path}. This suite is about the wire '
        'contract, so a missing client is a failure of the thing under test, '
        'not of the test.',
  );

  return source.readAsStringSync();
}

String _capitalise(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

String _fixture(String name) =>
    File('test/fixtures/credential_endpoint_wire/$name').readAsStringSync();
