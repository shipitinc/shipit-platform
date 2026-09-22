import 'package:test/test.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';

const String _longClaim =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
    '0123456789The quick brown fox jumps over the lazy dog in a shipping platform.';

void main() {
  test('sha256 known vector agrees (empty facts)', () {
    expect(
      baselineContentHash([]),
      '4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945',
    );
  });

  test('multi-block payload hashes to the verified SHA-256', () {
    // Canonical fact JSON exceeds 256 bytes (3 SHA-256 blocks), exercising the
    // per-block state carry in the hand-rolled implementation. Vector verified
    // with python over the exact canonical JSON string.
    final facts = [
      BaselineFact(
        factId: 'f-multi',
        section: BaselineSectionKey.architecture,
        claim: _longClaim,
        provenance: Provenance.derived,
        maturity: BaselineMaturity.implemented,
        evidenceRefs: const [
          'package:product_registry/test/hash_function_test.dart',
        ],
        redacted: false,
      ),
    ];
    expect(
      baselineContentHash(facts),
      'd08427d0411457aadfc92b7d1d3cb58ea2e33115f6cf194550f875526f7022df',
    );
  });
}
