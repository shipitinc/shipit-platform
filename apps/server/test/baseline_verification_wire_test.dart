import 'dart:io';

import 'package:test/test.dart';

/// The regression canary for the AGENTS.md §12 wire bypass, written so it runs
/// against every future revision of this area.
///
/// ## THE DEFECT THIS PINS
///
/// `ProductRegistryEndpoints.verifyBaseline` was a public Serverpod endpoint:
///
/// ```dart
/// Future<ProductDetailView> verifyBaseline(
///   Session session, {
///   required String productId,
///   required String baselineId,
///   required String verifiedBy,
///   String kind = 'platform_verified_evidence',   // the permissive default
/// });
/// ```
///
/// The wire default was the PERMISSIVE value, so any API client could call it
/// with a `verifiedBy` of its own choosing and record
/// `platformVerifiedEvidence` on any baseline — unlocking
/// `ProductGuard.baselineVerifiedIndependently` for a first baseline AND for
/// re-baselining an already-governed product. A second, independent instance
/// lived on the client: `ControlPlaneRepository.verifyBaseline` hardcoded
/// `kind: 'platform_verified_evidence'` at the call site.
///
/// §12 requires that a producer may not attest to its own baseline. The
/// reviewed engine contract now makes that structural (L1, commits `674a10d` +
/// `a58e137`): `verifyBaseline` has no `kind` parameter at all, and a
/// platform verification requires a `PlatformReDerivationProof`, which cannot
/// be constructed without a recomputed content hash.
///
/// ## WHY THE ENDPOINT WAS REMOVED RATHER THAN NARROWED
///
/// A claimant that can read the source can compute the content hash itself, so
/// ANY endpoint a client can reach that accepts `{verifiedBy,
/// reDerivedContentHash}` is a self-asserted proof over RPC — the same bypass
/// in a new costume. `PlatformReDerivationProof` is deliberately not a
/// Serverpod model (it is absent from `generated/protocol.yaml`), so putting
/// the proof on the wire would require inventing a serializable mirror of it.
/// Removing the verb is the only wire change that cannot be misread as
/// verification.
///
/// ## WHAT THIS TEST ASSERTS, AND WHY IT IS NOT A COMMENT
///
/// A doc comment cannot fail. This scans the generated server dispatch table,
/// the generated client, and the endpoint source, so re-adding a client-
/// reachable verification verb turns this red the moment the trees are
/// regenerated — whoever adds it, and whatever they intend.
///
/// The scan is deliberately a WHOLE-SURFACE scan with no allow-list of method
/// names. A per-method list is how this repository caught a defect twice: once
/// on `credentialEndpoints.generate`, and again on
/// `productRegistryEndpoints.addRepositoryReference`, which sat unreviewed for
/// a full cycle because the previous test only checked the first name.
void main() {
  group('no client can verify a baseline (AGENTS.md §12)', () {
    test('the generated server dispatch exposes no baseline verification', () {
      final offenders = _forbiddenMethodNames(
        _serverDispatchText(),
      ).where(_looksLikeBaselineVerification).toList();

      expect(
        offenders,
        isEmpty,
        reason:
            'A public, non-@doNotGenerate, Session-first method on an Endpoint '
            'IS a wire endpoint — that is exactly the predicate '
            '`serverpod_cli` uses to discover them. So any of these names on a '
            'dispatch table is callable by any API client.\n'
            'AGENTS.md §12: "a producer may not attest to its own baseline". A '
            'client-supplied verifier identity, and a client-supplied content '
            'hash, are both self-attestation: a claimant that can read the '
            'source can compute the hash itself.\n'
            'Verification is an INDEPENDENT RE-DERIVATION performed by the '
            'server from the source. That runtime does not exist in '
            'shipit-platform (see the constants in '
            'endpoints/product_registry_endpoints.dart), so the honest state is '
            'that no client can verify a baseline — not an endpoint that '
            'accepts an identity and calls it a verification.\n'
            'Offenders: $offenders',
      );
    });

    test('the generated client declares no baseline verification method', () {
      final offenders = _forbiddenMethodNames(
        _clientText(),
      ).where(_looksLikeBaselineVerification).toList();

      expect(
        offenders,
        isEmpty,
        reason:
            'The generated client mirrors the server dispatch table, so a '
            'verification method here means one is callable from the browser '
            'and from any API client. The browser is exactly the claimant §12 '
            'refuses to let attest to its own baseline.\n'
            'Offenders: $offenders',
      );
    });

    test('the endpoint source declares no Session-first verify method', () {
      // This one reads the SOURCE rather than the generated tree, so it fails on
      // the commit that re-adds the method instead of waiting for someone to
      // remember to regenerate. The generated-tree tests above then cover the
      // case where the source is reverted but a regenerated tree was committed.
      final source = File('lib/src/endpoints/product_registry_endpoints.dart');
      expect(
        source.existsSync(),
        isTrue,
        reason:
            'lib/src/endpoints/product_registry_endpoints.dart does not exist '
            'relative to ${Directory.current.path}. Run from apps/server.',
      );

      final offenders = _forbiddenMethodNames(
        _stripComments(source.readAsStringSync()),
      ).where(_looksLikeBaselineVerification).toList();

      expect(
        offenders,
        isEmpty,
        reason:
            'A public method whose FIRST REQUIRED POSITIONAL parameter is a '
            '`Session` is a wire endpoint (see `EndpointMethodAnalyzer'
            '.isEndpointMethod`), even if it is `static` — 3.4.13 has no '
            '`isStatic` check. `@doNotGenerate` is the documented escape hatch '
            'if such a method is genuinely not an endpoint, and it must say '
            'why in its doc comment.\n'
            'Offenders: $offenders',
      );
    });

    test('the permissive evidence kind is not a wire parameter default', () {
      // The specific mechanism of the original bypass: a DEFAULT on the wire.
      // A `kind` parameter is not itself the hole — a client-supplied evidence
      // kind is how the caller chose `platformVerifiedEvidence` — so this scans
      // the endpoint sources for any default that names it.
      final directory = Directory('lib/src/endpoints');
      final offenders = <String>[];

      for (final file in directory.listSync().whereType<File>()) {
        // COMMENTS ARE STRIPPED FIRST, and that is load-bearing rather than
        // cosmetic. This file's own endpoint documents the defect by QUOTING
        // the old signature verbatim — `String kind =
        // 'platform_verified_evidence'` — which is exactly the string this
        // scan looks for. Scanning the raw text would make the remediation
        // fail because it explained itself, and the fix would be to delete
        // the explanation. A guard that punishes documentation is a guard that
        // gets worked around.
        final text = _stripComments(file.readAsStringSync());
        if (RegExp(
          r"""=\s*['"]platform_verified_evidence['"]""",
        ).hasMatch(text)) {
          offenders.add(file.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'A wire parameter defaulting to `platform_verified_evidence` lets '
            'every caller that OMITS it self-certify. That default is the '
            'bypass. If a value like this is ever needed again it belongs '
            'server-side, behind a re-derivation, never in a parameter '
            'default a client can inherit.\n'
            'Offenders: $offenders',
      );
    });

    // THE VACUOUS-PASS GUARD. Asserted separately so a rename or relocation of
    // either generated file turns this into an explicit failure rather than a
    // scan that reads nothing and passes for the wrong reason.
    group('the scans actually read the generated trees', () {
      test('the server dispatch table is found and is large', () {
        final file = File(_serverDispatchPath());
        expect(
          file.existsSync(),
          isTrue,
          reason:
              '${_serverDispatchPath()} does not exist relative to '
              '${Directory.current.path}. Run from apps/server.',
        );
        final source = file.readAsStringSync();

        final connectors = RegExp(
          r"MethodConnector\(\s*\n\s*name:\s*'([^']+)'",
        ).allMatches(source).map((m) => m.group(1)!).toSet();
        expect(
          connectors.length,
          greaterThan(50),
          reason:
              'only ${connectors.length} endpoint connectors found. The '
              'generator changed the layout and this scan is reading nothing.',
        );
        expect(
          connectors,
          contains('proposeBaseline'),
          reason:
              'proposeBaseline is an existing endpoint and must still be '
              'present; its absence means this scan is not looking at the '
              'dispatch table it thinks it is.',
        );
      });

      test('the generated client is found and is large', () {
        final file = File(_clientPath());
        expect(
          file.existsSync(),
          isTrue,
          reason:
              '${_clientPath()} does not exist relative to '
              '${Directory.current.path}. Run from apps/server.',
        );
        final source = file.readAsStringSync();

        // `[\s\S]*?` because the generic argument is NOT always a single type:
        // 11 of these return a nested generic such as
        // `callServerEndpoint<_i9.Future<_i8.List<_i7.XView>>>`. A `[^>]*`
        // argument stops at the first `>` and then fails to find the `(`,
        // silently dropping those 11 methods from the scan — which is exactly
        // how a vacuous pass happens on a test whose whole job is not to miss
        // one.
        final calls = RegExp(
          r"callServerEndpoint<[\s\S]*?>\s*\(\s*'[^']+',\s*'([^']+)'",
        ).allMatches(source).map((m) => m.group(1)!).toSet();
        expect(
          calls.length,
          greaterThan(50),
          reason:
              'only ${calls.length} endpoint calls found in ${_clientPath()}. '
              'This scan is reading nothing and would pass for the wrong '
              'reason.',
        );
        expect(
          calls,
          contains('proposeBaseline'),
          reason:
              'proposeBaseline is an existing endpoint and must still be '
              'reachable from the generated client.',
        );
      });
    });
  });
}

/// Method names that would let a client verify a baseline if they appeared on a
/// Serverpod dispatch table or in the generated client.
///
/// A NAME scan, not a per-endpoint allow-list, so it catches a renamed verb
/// (`verifyBase`, `confirmBaseline`, `attestBaseline`, …) rather than only the
/// exact spelling that exists today. It cannot be exhaustive, and is not meant
/// to be: `endpoint_surface_shape_test.dart` already owns "what makes a method
/// a wire endpoint at all", and `product_baseline.dart` owns whether a recorded
/// verification unlocks the gate. This owns the narrow question of whether a
/// client-reachable VERIFICATION VERB exists.
final _forbiddenNamePattern = RegExp(
  r'(verify|attest|confirm|validate|certify|attestTo)[A-Za-z]*Baseline'
  r'|Baseline[A-Za-z]*(Verification|Verified|Attest)',
  caseSensitive: false,
);

bool _looksLikeBaselineVerification(String name) =>
    _forbiddenNamePattern.hasMatch(name);

/// Every method-ish name declared in [source], as a set.
///
/// Deliberately loose — it over-collects and the predicate filters — because a
/// parser that understands Dart well enough to be exact is a parser that
/// silently stops matching after a generator change.
Set<String> _forbiddenMethodNames(String source) {
  final names = <String>{};
  // Single-quoted raw string: a double-quoted one cannot express `\"` (raw
  // strings take the backslash literally, and `\"` is not a valid Dart escape).
  // Inside a character class `[` and `]` need no escape, and `]` first is
  // literal.
  for (final match in RegExp(
    r'''['"]?([A-Za-z_][A-Za-z0-9_]*)['"]?\s*[:(]''',
  ).allMatches(source)) {
    names.add(match.group(1)!);
  }
  for (final match in RegExp(
    r'\b([A-Za-z_][A-Za-z0-9_]*)\s*\(',
  ).allMatches(source)) {
    names.add(match.group(1)!);
  }
  return names;
}

String _stripComments(String source) => source
    .split('\n')
    .map(
      (line) =>
          line.startsWith('///') ? '' : line.replaceFirst(RegExp(r'//.*$'), ''),
    )
    .join('\n');

String _serverDispatchPath() => 'lib/src/generated/endpoints.dart';

String _serverDispatchText() => File(_serverDispatchPath()).readAsStringSync();

/// The generated client lives in a sibling PACKAGE, not under `apps/`, because
/// `config/generator.yaml` sets `client_package_path: ../../packages/
/// control_plane_client`. Resolved relative to `apps/server` so this test runs
/// from there, matching every other test in this directory.
String _clientPath() =>
    '../../packages/control_plane_client/lib/src/protocol/client.dart';

String _clientText() => File(_clientPath()).readAsStringSync();
