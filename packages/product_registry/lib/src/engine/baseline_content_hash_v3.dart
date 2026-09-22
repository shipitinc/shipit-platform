import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:platform_contracts/platform_contracts.dart';

/// Hash Contract V3 (contentHashVersion = 3).
///
/// Standard SHA-256 (RFC 6234, via `package:crypto`) over a deterministic,
/// versioned canonical JSON payload of a baseline's structured facts.
///
/// Canonicalization contract:
/// - facts sorted ascending by [BaselineFact.factId];
/// - per-fact field order: `factId`, `section` (wire), `claim`,
///   `provenance` (wire), `maturity` (wire), `evidenceRefs` (sorted, set
///   semantics), `assumptionNote` (only when non-null), `redacted`
///   (only when true);
/// - enums serialized by their wire values;
/// - compact deterministic JSON, UTF-8 encoded;
/// - standard SHA-256; `contentHash` is the raw lowercase 64-hex digest (no
///   `v3:` prefix). The hash version is carried separately as
///   `contentHashVersion = 3`.
///
/// Hash V1/V2 remain readable as historical records; V3 is the only contract
/// used for newly created baselines.
String baselineContentHashV3(List<BaselineFact> facts) {
  final payload = canonicalBaselineFactsJson(facts);
  return _sha256Hex(utf8.encode(payload));
}

/// Returns the exact canonical UTF-8 JSON payload a baseline of [facts] hashes.
/// Exposed so golden vectors can pin the literal payload independently of the
/// digest.
String canonicalBaselineFactsJson(List<BaselineFact> facts) {
  final sorted = List<BaselineFact>.of(facts)
    ..sort((a, b) => a.factId.compareTo(b.factId));
  final canonical = sorted.map((f) {
    final evidence = f.evidenceRefs.toSet().toList()..sort();
    final map = <String, Object?>{
      'factId': f.factId,
      'section': f.section.wire,
      'claim': f.claim,
      'provenance': f.provenance.wire,
      'maturity': f.maturity.wire,
      'evidenceRefs': evidence,
    };
    if (f.assumptionNote != null) {
      map['assumptionNote'] = f.assumptionNote;
    }
    if (f.redacted) {
      map['redacted'] = true;
    }
    return map;
  }).toList();
  return jsonEncode(canonical);
}

/// Standard SHA-256 as lowercase 64-char hex (RFC 6234 via `package:crypto`).
String _sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();