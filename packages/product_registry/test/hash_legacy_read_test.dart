import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:test/test.dart';

/// Historical Hash Contract readability (audit-only).
///
/// V1 and V2 baselines remain readable; neither is used for new approvals.
/// V2's digest is KNOWN to be non-standard (defective `_k` constants), so the
/// persisted hash of a V2 baseline cannot be independently reproduced — the
/// legacy engine is the only reader. V3 is the only contract for new baselines.
void main() {
  group('Hash V1 legacy readability', () {
    test('HASH_V1_LEGACY_READ: deterministic and stable over its contract', () {
      const facts = [
        BaselineFact(
          factId: 'l-1',
          section: BaselineSectionKey.repository,
          claim: 'V1 legacy fact',
          provenance: Provenance.observed,
          maturity: BaselineMaturity.implemented,
          evidenceRefs: ['README.md'],
        ),
        BaselineFact(
          factId: 'l-2',
          section: BaselineSectionKey.techStack,
          claim: 'V1 legacy fact two',
          provenance: Provenance.derived,
          maturity: BaselineMaturity.notImplemented,
          evidenceRefs: ['pubspec.yaml'],
        ),
      ];
      final once = baselineContentHash(facts);
      final twice = baselineContentHash(facts.reversed.toList());
      expect(once, twice);
      expect(once, matches(RegExp(r'^[0-9a-f]{64}$')));
    });
  });

  group('Hash V2 legacy readability', () {
    test('HASH_V2_LEGACY_READ: deterministic over V2 contract', () {
      const facts = [
        BaselineFact(
          factId: 'v2-1',
          section: BaselineSectionKey.environments,
          claim: 'V2 legacy fact',
          provenance: Provenance.observed,
          maturity: BaselineMaturity.implemented,
          evidenceRefs: ['a.txt', 'b.txt'],
          redacted: true,
        ),
      ];
      final once = baselineContentHashV2(facts);
      final twice = baselineContentHashV2(facts);
      expect(once, twice);
      expect(once, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('HASH_V2_NON_STANDARD: V2 digest differs from standard SHA-256', () {
      const facts = [
        BaselineFact(
          factId: 'v2-2',
          section: BaselineSectionKey.environments,
          claim: 'V2 legacy fact',
          provenance: Provenance.observed,
          maturity: BaselineMaturity.implemented,
          evidenceRefs: ['a.txt'],
        ),
      ];
      final engine = baselineContentHashV2(facts);
      final payload = canonicalBaselineFactsJson(facts);
      final standard = sha256.convert(utf8.encode(payload)).toString();
      expect(engine, isNot(standard));
    });
  });

  group('Hash version discipline', () {
    test('proposeBaseline binds contentHashVersion 3 via Hash V3', () {
      const facts = [
        BaselineFact(
          factId: 'p-1',
          section: BaselineSectionKey.repository,
          claim: 'Bound fact',
          provenance: Provenance.observed,
          maturity: BaselineMaturity.implemented,
          evidenceRefs: ['README.md'],
        ),
      ];
      expect(
        baselineContentHashV3(facts),
        isNot(baselineContentHashV2(facts)),
      );
      expect(
        baselineContentHashV3(facts),
        isNot(baselineContentHash(facts)),
      );
    });
  });
}