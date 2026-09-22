import 'dart:convert';

import 'package:platform_contracts/platform_contracts.dart';

/// HISTORICAL DEFECTIVE Hash Contract V2 — READ-ONLY, never for new baselines.
///
/// The embedded SHA-256 round constants are corrupted (the `_k` table contains
/// 256 entries with wrong values at indices 55–63), so digests are NOT standard
/// SHA-256 and cannot be independently reproduced. A baseline with
/// `contentHashVersion = 2` means "hashed with the defective historical V2
/// contract" and must never be used for a new approval candidate. This file is
/// retained only so V2 baselines remain readable for audit.
///
/// New baselines MUST use Hash Contract V3 ([baselineContentHashV3]) with
/// standard SHA-256 and `contentHashVersion = 3`.
String baselineContentHashV2(List<BaselineFact> facts) {
  final sorted = List<BaselineFact>.of(facts)
    ..sort((a, b) => a.factId.compareTo(b.factId));
  
  final canonical = jsonEncode(
    sorted.map((f) => _factToCanonicalMap(f)).toList(),
  );
  final bytes = utf8.encode(canonical);
  return _sha256Hex(bytes);
}

/// Computes a deterministic SHA-256 hash of the canonical fact set,
/// including hash version metadata for forward compatibility.
String computeBaselineHashV2(List<BaselineFact> facts) {
  final hash = baselineContentHashV2(facts);
  return 'v2:$hash';
}

/// Parses a versioned hash string.
/// Returns null if the version is not recognized.
(String?, String?) parseVersionedHash(String versionedHash) {
  final parts = versionedHash.split(':');
  if (parts.length != 2) return (null, null);
  return (parts[0], parts[1]);
}

/// Checks if a hash was produced under Hash Contract V2.
bool isHashV2(String versionedHash) {
  final (version, _) = parseVersionedHash(versionedHash);
  return version == 'v2';
}

Map<String, dynamic> _factToCanonicalMap(BaselineFact f) {
  final map = <String, dynamic>{
    'factId': f.factId,
    'section': f.section.wire,
    'claim': f.claim,
    'provenance': f.provenance.wire,
    'maturity': f.maturity.wire,
    'evidenceRefs': List<String>.from(f.evidenceRefs)..sort(),
  };
  
  // assumptionNote: include only when non-null
  if (f.assumptionNote != null) {
    map['assumptionNote'] = f.assumptionNote!;
  }
  
  // redacted: include only when true (false is default/omitted)
  if (f.redacted) {
    map['redacted'] = true;
  }
  
  return map;
}

String _sha256Hex(List<int> bytes) {
  // Small, dependency-free SHA-256 implementation kept local so the platform
  // contracts / registry packages stay pure Dart on any host. Only ever used
  // for content-addressing baseline revisions, never for credential material.
  final h = List<int>.of(_initial);
  final padding = _pad(bytes.length * 8);
  final message = [...bytes, ...padding];
  for (var i = 0; i < message.length; i += 64) {
    final w = List<int>.filled(64, 0);
    for (var t = 0; t < 16; t++) {
      w[t] =
          (message[i + t * 4] << 24) |
          (message[i + t * 4 + 1] << 16) |
          (message[i + t * 4 + 2] << 8) |
          (message[i + t * 4 + 3]);
    }
    for (var t = 16; t < 64; t++) {
      final s0 =
          _rotr(w[t - 15] & 0xffffffff, 7) ^
          _rotr(w[t - 15] & 0xffffffff, 18) ^
          ((w[t - 15] & 0xffffffff) >> 3);
      final s1 =
          _rotr(w[t - 2] & 0xffffffff, 17) ^
          _rotr(w[t - 2] & 0xffffffff, 19) ^
          ((w[t - 2] & 0xffffffff) >> 10);
      w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & 0xffffffff;
    }
    var a = h[0], b = h[1], c = h[2], d = h[3];
    var e = h[4], f = h[5], g = h[6], hh = h[7];
    for (var t = 0; t < 64; t++) {
      final s1 =
          _rotr(e & 0xffffffff, 6) ^
          _rotr(e & 0xffffffff, 11) ^
          _rotr(e & 0xffffffff, 25);
      final ch = (e & f) ^ ((~e) & g);
      final temp1 = (hh + s1 + ch + _k[t] + w[t]) & 0xffffffff;
      final s0 =
          _rotr(a & 0xffffffff, 2) ^
          _rotr(a & 0xffffffff, 13) ^
          _rotr(a & 0xffffffff, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & 0xffffffff;
      hh = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xffffffff;
    }
    h[0] = (h[0] + a) & 0xffffffff;
    h[1] = (h[1] + b) & 0xffffffff;
    h[2] = (h[2] + c) & 0xffffffff;
    h[3] = (h[3] + d) & 0xffffffff;
    h[4] = (h[4] + e) & 0xffffffff;
    h[5] = (h[5] + f) & 0xffffffff;
    h[6] = (h[6] + g) & 0xffffffff;
    h[7] = (h[7] + hh) & 0xffffffff;
  }
  return h.map((x) => x.toRadixString(16).padLeft(8, '0')).join();
}

const List<int> _initial = [
  0x6a09e667,
  0xbb67ae85,
  0x3c6ef372,
  0xa54ff53a,
  0x510e527f,
  0x9b05688c,
  0x1f83d9ab,
  0x5be0cd19,
];

const List<int> _k = [
  0x428a2f98,
  0x71374491,
  0xb5c0fbcf,
  0xe9b5dba5,
  0x3956c25b,
  0x59f111f1,
  0x923f82a4,
  0xab1c5ed5,
  0xd807aa98,
  0x12835b01,
  0x243185be,
  0x550c7dc3,
  0x72be5d74,
  0x80deb1fe,
  0x9bdc06a7,
  0xc19bf174,
  0xe49b69c1,
  0xefbe4786,
  0x0fc19dc6,
  0x240ca1cc,
  0x2de92c6f,
  0x4a7484aa,
  0x5cb0a9dc,
  0x76f988da,
  0x983e5152,
  0xa831c66d,
  0xb00327c8,
  0xbf597fc7,
  0xc6e00bf3,
  0xd5a79147,
  0x06ca6351,
  0x14292967,
  0x27b70a85,
  0x2e1b2138,
  0x4d2c6dfc,
  0x53380d13,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
];

int _rotr(int x, int n) => ((x) >>> n) | (x << (32 - n));

List<int> _pad(int bitLength) {
  final byteLength = bitLength ~/ 8;
  final result = <int>[0x80];
  final zeroCount = (55 - byteLength) % 64;
  for (var i = 0; i < zeroCount; i++) {
    result.add(0);
  }
  for (var i = 7; i >= 0; i--) {
    result.add((bitLength >> (i * 8)) & 0xff);
  }
  return result;
}