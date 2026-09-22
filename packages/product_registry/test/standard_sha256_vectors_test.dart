import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

/// Proves that the SHA-256 used by ShipIt (via `package:crypto`) agrees with
/// the published standard vectors, before any canonicalization is trusted.
void main() {
  test('SHA256_STANDARD_EMPTY_VECTOR', () {
    expect(
      sha256.convert([]).toString(),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
  });

  test('SHA256_STANDARD_ABC_VECTOR', () {
    expect(
      sha256.convert('abc'.codeUnits).toString(),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('SHA256_STANDARD_LONG_VECTOR', () {
    // NIST/FIPS 180-4 long vector: SHA-256 of one million 'a'.
    final input = 'a' * 1000000;
    expect(
      sha256.convert(input.codeUnits).toString(),
      'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0',
    );
  });
}