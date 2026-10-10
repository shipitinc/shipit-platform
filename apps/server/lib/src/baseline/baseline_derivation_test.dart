import 'dart:io';

import 'package:control_plane_server/src/baseline/baseline_derivation.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
// `test` is a dev_dependency of `control_plane_server`; it is unresolved as a
// `lib/` import, which is a known cost of co-locating tests here.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

const List<DiscoveryObservation> _observations = [
  DiscoveryObservation(
    section: BaselineSectionKey.techStack,
    claim: 'Dart package manifest.',
    provenance: Provenance.derived,
    evidencePaths: ['pubspec.yaml'],
  ),
  DiscoveryObservation(
    section: BaselineSectionKey.architecture,
    claim: 'Source material for operator-authored claims.',
    provenance: Provenance.observed,
    evidencePaths: ['README.md'],
  ),
];

void main() {
  group('deriveBaselineFacts', () {
    test('is deterministic — the same input yields the same hash', () {
      // The whole §12 mechanism rests on this. A clock, a UUID or a set
      // iteration would make every re-derivation "diverge" from a proposal that
      // is perfectly correct, and the failure would read as repository drift.
      final first = deriveBaselineFacts(_observations);
      final second = deriveBaselineFacts(_observations);
      expect(comparableContentHash(first), comparableContentHash(second));
      expect(
        first.map((f) => f.factId).toList(),
        ['discovery-0', 'discovery-1'],
      );
    });

    test('produces one fact per observation, in input order', () {
      final facts = deriveBaselineFacts(_observations);
      expect(facts, hasLength(2));
      expect(facts.first.section, BaselineSectionKey.techStack);
      expect(facts.first.evidenceRefs, ['pubspec.yaml']);
    });

    test(
      'is reproducible through the real reader over the same tree',
      () async {
        // The pure function AND the production reader compose to something a
        // second process can reproduce: two fresh directories holding identical
        // content must derive identical hashes.
        Future<List<BaselineFact>> deriveFrom(String compose) async {
          final root = Directory.systemTemp.createTempSync('baseline_det_');
          addTearDown(() {
            if (root.existsSync()) root.deleteSync(recursive: true);
          });
          File(
            '${root.path}/README.md',
          ).writeAsStringSync('# A title\n\nBody.\n');
          File('${root.path}/docker-compose.yml').writeAsStringSync(compose);
          return deriveBaselineFacts(
            await ReadOnlyRepositoryReader(snapshotRoot: root).inspect(),
          );
        }

        final one = 'services:\n  web:\n    image: nginx\n';
        final two =
            'services:\n  web:\n    image: nginx\n  db:\n    image: postgres\n';

        final a = await deriveFrom(one);
        final b = await deriveFrom(one);
        final different = await deriveFrom(two);

        expect(comparableContentHash(a), comparableContentHash(b));
        expect(
          comparableContentHash(a),
          isNot(comparableContentHash(different)),
          reason:
              'a different tree must derive differently, or the re-derivation '
              'would agree with anything',
        );
      },
    );
  });

  group('comparableFacts', () {
    BaselineFact fact(String id, Provenance provenance) => BaselineFact(
      factId: id,
      section: BaselineSectionKey.design,
      claim: 'claim $id',
      provenance: provenance,
      maturity: BaselineMaturity.unknown,
    );

    test('drops human-authored claims and keeps everything else', () {
      final facts = [
        fact('a', Provenance.observed),
        fact('h', Provenance.humanProvided),
        fact('b', Provenance.derived),
      ];
      expect(
        comparableFacts(facts).map((f) => f.factId).toList(),
        ['a', 'b'],
      );
    });

    test('THE F-3 SHAPE: scraped-vs-(scraped+human) hashes are NOT equal', () {
      // The arithmetic behind the defect. The naive comparison re-derived the
      // scraped half and compared it against a content hash covering scraped
      // AND human — two different sets, so they can never match, and the message
      // said the repository had drifted.
      final scraped = [fact('a', Provenance.observed)];
      final withHuman = [...scraped, fact('h', Provenance.humanProvided)];

      expect(
        comparableContentHash(comparableFacts(withHuman)),
        comparableContentHash(scraped),
        reason:
            'the comparable subset of scraped+human IS the scraped half, so '
            'comparing like with like succeeds where the naive comparison failed',
      );
      expect(
        comparableContentHash(withHuman),
        isNot(comparableContentHash(scraped)),
        reason: 'and this is exactly the mismatch the naive comparison made',
      );
    });

    test('reports whether any claim is human-authored', () {
      expect(
        containsHumanAuthoredClaims([fact('a', Provenance.observed)]),
        isFalse,
      );
      expect(
        containsHumanAuthoredClaims([
          fact('a', Provenance.observed),
          fact('h', Provenance.humanProvided),
        ]),
        isTrue,
      );
    });
  });

  group('BaselinePrincipals', () {
    test('accepts two principals that differ only in spelling', () {
      // The engine's own comparison is the authority; this only refuses what the
      // engine would refuse, and it normalises the same way.
      expect(
        () => BaselinePrincipals(
          producer: 'Lane:Baseline',
          verifier: 'lane:baseline-verifier',
        ),
        returnsNormally,
      );
    });

    test('refuses one principal wearing two hats, whatever the spelling', () {
      for (final spelling in [
        ('lane:baseline', 'lane:baseline'),
        ('lane:baseline', '  LANE:BASELINE  '),
        ('lane:baseline', 'lane:baseline'),
      ]) {
        expect(
          () => BaselinePrincipals(
            producer: spelling.$1,
            verifier: spelling.$2,
          ),
          throwsArgumentError,
          reason:
              '§12 forbids an identity attesting to its own baseline, and a '
              'trailing space or zero-width space is not a different identity',
        );
      }
    });

    test('refuses a blank principal', () {
      expect(
        () => BaselinePrincipals(producer: '   ', verifier: 'lane:b'),
        throwsArgumentError,
      );
      expect(
        () => BaselinePrincipals(producer: 'lane:a', verifier: ''),
        throwsArgumentError,
      );
    });
  });
}
