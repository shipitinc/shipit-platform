import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:test/test.dart';

/// Hash Contract V3 golden contract (contentHashVersion = 3).
///
/// The golden vector is a small, human-readable semantic fixture. It pins:
/// 1. the exact canonical UTF-8 JSON payload,
/// 2. the standard SHA-256 of that payload (published/independent),
/// 3. the engine's hash computed from the same facts,
/// 4. an INDEPENDENT digest computed from the literal payload string WITHOUT
///    calling any production helper.
///
/// Requirement: STANDARD == ENGINE == INDEPENDENT.
const String goldenPayload =
    '[{"factId":"g-1","section":"repository","claim":"First fact",'
    '"provenance":"observed","maturity":"implemented",'
    '"evidenceRefs":["repo/README.md"],"assumptionNote":"note","redacted":true},'
    '{"factId":"g-2","section":"tech_stack","claim":"Second fact",'
    '"provenance":"derived","maturity":"planned",'
    '"evidenceRefs":["a.txt","b.txt"]},'
    '{"factId":"g-3","section":"environments","claim":"Third fact",'
    '"provenance":"observed","maturity":"not_implemented",'
    '"evidenceRefs":[".env.example"]}]';

const String goldenStandardSha256 =
    'bfa8293b536aa73a2877903ddc579aee8b4fc5fb15e34f3d277f5b4b2853cb78';

List<BaselineFact> goldenFacts() => const [
      BaselineFact(
        factId: 'g-2',
        section: BaselineSectionKey.techStack,
        claim: 'Second fact',
        provenance: Provenance.derived,
        maturity: BaselineMaturity.planned,
        evidenceRefs: ['b.txt', 'a.txt'],
      ),
      BaselineFact(
        factId: 'g-1',
        section: BaselineSectionKey.repository,
        claim: 'First fact',
        provenance: Provenance.observed,
        maturity: BaselineMaturity.implemented,
        evidenceRefs: ['repo/README.md'],
        assumptionNote: 'note',
        redacted: true,
      ),
      BaselineFact(
        factId: 'g-3',
        section: BaselineSectionKey.environments,
        claim: 'Third fact',
        provenance: Provenance.observed,
        maturity: BaselineMaturity.notImplemented,
        evidenceRefs: ['.env.example'],
      ),
    ];

/// Sorted by factId so positional mutation tests target g-1, g-2, g-3 in order.
List<BaselineFact> sortedFacts() {
  final facts = List<BaselineFact>.of(goldenFacts())..sort(
    (a, b) => a.factId.compareTo(b.factId),
  );
  return facts;
}

String independentStandardSha256(String payload) =>
    sha256.convert(utf8.encode(payload)).toString();

void main() {
  group('Hash V3 golden vector', () {
    test('HASH_V3_GOLDEN_VECTOR: canonical payload is exact and pinned', () {
      expect(
        canonicalBaselineFactsJson(goldenFacts()),
        goldenPayload,
      );
      expect(utf8.encode(goldenPayload).length, 472);
    });

    test('HASH_V3_GOLDEN_VECTOR: engine digest equals published standard', () {
      expect(baselineContentHashV3(goldenFacts()), goldenStandardSha256);
    });

    test(
      'HASH_V3_ENGINE_INDEPENDENT_EQUALITY: STANDARD == ENGINE == INDEPENDENT',
      () {
        final standard = independentStandardSha256(goldenPayload);
        final engine = baselineContentHashV3(goldenFacts());
        final independent = independentStandardSha256(goldenPayload);
        expect(independent, standard);
        expect(engine, standard);
        expect(engine, independent);
        expect(engine, goldenStandardSha256);
      },
    );
  });

  group('Hash V3 canonicalization determinism', () {
    test('HASH_V3_FACT_ORDER: unsorted facts hash identically', () {
      final shuffled = goldenFacts().reversed.toList();
      expect(baselineContentHashV3(shuffled), goldenStandardSha256);
    });

    test('HASH_V3_EVIDENCE_ORDER: unsorted evidenceRefs hash identically', () {
      expect(baselineContentHashV3(goldenFacts()), goldenStandardSha256);
    });
  });

  group('Hash V3 semantic mutations', () {
    test('HASH_V3_CLAIM_CHANGE', () {
      final mutated = sortedFacts();
      mutated[0] = mutated[0].copyWith(claim: 'First fact changed');
      expect(baselineContentHashV3(mutated), isNot(goldenStandardSha256));
    });

    test('HASH_V3_SECTION_CHANGE', () {
      final mutated = sortedFacts();
      mutated[0] = mutated[0].copyWith(
        section: BaselineSectionKey.environments,
      );
      expect(baselineContentHashV3(mutated), isNot(goldenStandardSha256));
    });

    test('HASH_V3_PROVENANCE_CHANGE', () {
      final mutated = sortedFacts();
      mutated[0] = mutated[0].copyWith(provenance: Provenance.derived);
      expect(baselineContentHashV3(mutated), isNot(goldenStandardSha256));
    });

    test('HASH_V3_MATURITY_CHANGE', () {
      final mutated = sortedFacts();
      mutated[0] = mutated[0].copyWith(maturity: BaselineMaturity.unknown);
      expect(baselineContentHashV3(mutated), isNot(goldenStandardSha256));
    });

    test('HASH_V3_EVIDENCE_CHANGE', () {
      final mutated = sortedFacts();
      mutated[0] = mutated[0].copyWith(
        evidenceRefs: const ['repo/README.md', 'other.txt'],
      );
      expect(baselineContentHashV3(mutated), isNot(goldenStandardSha256));
    });

    test('HASH_V3_ASSUMPTION_CHANGE', () {
      final mutated = sortedFacts();
      mutated[0] = mutated[0].copyWith(assumptionNote: 'other note');
      expect(baselineContentHashV3(mutated), isNot(goldenStandardSha256));
    });

    test('HASH_V3_REDACTED_CHANGE', () {
      final mutated = sortedFacts();
      mutated[0] = mutated[0].copyWith(redacted: false);
      expect(baselineContentHashV3(mutated), isNot(goldenStandardSha256));
    });

    test('HASH_V3_NO_V2_PREFIX: contentHash is raw lowercase hex', () {
      final hash = baselineContentHashV3(goldenFacts());
      expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(hash.startsWith('v3:'), isFalse);
    });
  });
}