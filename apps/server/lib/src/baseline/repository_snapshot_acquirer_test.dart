import 'dart:io';

import 'package:control_plane_server/src/baseline/baseline_test_fixtures.dart';
import 'package:control_plane_server/src/credentials/credential_key_service.dart';
import 'package:control_plane_server/src/credentials/repository_snapshot_acquirer.dart';
import 'package:platform_contracts/platform_contracts.dart';
// `test` is a dev_dependency of `control_plane_server`. It is unresolved as a
// `lib/` import, which is a known cost of co-locating tests here rather than
// under `test/` — the lane that owns `apps/server/test/**` is where a test that
// needs to resolve `package:test` from `lib/` belongs.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

/// Acquires through the two existing components, in the order §3.2 puts them.
({
  RepositorySnapshotAcquirer acquirer,
  ScriptedSnapshotMaterializer materializer,
  ScriptedAccessVerifier verifier,
  RecordingSecretProvider secrets,
  RegistryFixture registry,
})
_wire(
  RegistryFixture registry, {
  ScriptedSnapshotMaterializer? materializer,
  ScriptedAccessVerifier? verifier,
}) {
  final secrets = RecordingSecretProvider();
  final access =
      verifier ?? ScriptedAccessVerifier(committedRevision: kTestRevision);
  final snapshot = materializer ?? ScriptedSnapshotMaterializer();
  final keyService = CredentialKeyService(
    engine: registry.engine,
    secretProvider: secrets,
    verifier: access,
    clock: () => DateTime.utc(2026, 2, 1),
  );
  return (
    acquirer: RepositorySnapshotAcquirer(
      engine: registry.engine,
      credentialKeyService: keyService,
      materializer: snapshot,
    ),
    materializer: snapshot,
    verifier: access,
    secrets: secrets,
    registry: registry,
  );
}

void main() {
  group('RepositorySnapshotAcquirer', () {
    test(
      'acquires a snapshot at the pinned revision through both components',
      () async {
        final registry = RegistryFixture();
        await registry.registerProduct(productId: 'product-a');
        await seedCredential(
          registry.engine,
          productId: 'product-a',
          repositoryId: 'repo',
        );
        final wired = _wire(registry);

        final snapshot = await wired.acquirer.acquire(
          productId: 'product-a',
          repositoryId: 'repo',
          pinnedRevision: kTestRevision,
        );
        addTearDown(snapshot.release);

        expect(snapshot.revision, kTestRevision);
        expect(snapshot.productId, 'product-a');
        // BOTH components were on the path, in the order §3.2 specifies: the
        // credential service asked the access verifier to enforce a host key
        // before the snapshot was materialised at all.
        expect(
          wired.verifier.demandedHostKeyFingerprints,
          [kTestHostKeyFingerprint],
          reason:
              'RepositoryAccessVerifier.verify must be reached via '
              'CredentialKeyService.verifyAccess, with the CONFIRMED host key',
        );
        expect(
          wired.materializer.demandedHostKeyFingerprints,
          [kTestHostKeyFingerprint],
        );
        expect(wired.materializer.materializations, 1);
      },
    );

    test(
      'the secret is read BY NAME, and the reference is not carried out',
      () async {
        final registry = RegistryFixture();
        await registry.registerProduct(productId: 'product-a');
        await seedCredential(
          registry.engine,
          productId: 'product-a',
          repositoryId: 'repo',
        );
        final wired = _wire(registry);

        final snapshot = await wired.acquirer.acquire(
          productId: 'product-a',
          repositoryId: 'repo',
          pinnedRevision: kTestRevision,
        );
        addTearDown(snapshot.release);

        expect(wired.secrets.reads, isNotEmpty);
        for (final reference in wired.secrets.reads) {
          expect(reference, 'GIT_TEST_repo_SSH');
        }
        // §13a by name, and ADR 0018 A3 further than that: the reference name is
        // ITSELF the sensitive artifact (gap G-7), so the snapshot must not
        // carry it out to logs, job records or baseline facts at all.
        expect(snapshot.toString(), isNot(contains('GIT_TEST_repo_SSH')));
        expect(snapshot.toString(), isNot(contains(kTestHostKeyFingerprint)));
        expect(
          snapshot.toString(),
          isNot(contains(kTestCredentialFingerprint)),
        );
      },
    );

    test(
      'refuses when the value offered as a host key is the credential fingerprint',
      () async {
        // THE N-10 CASE. A deploy key's public-key fingerprint is not a host key
        // fingerprint, and a lane that passed one where the other belongs would
        // make an impossible check look like a failed one on a rotated host.
        final registry = RegistryFixture();
        await registry.registerProduct(productId: 'product-a');
        await seedCredential(
          registry.engine,
          productId: 'product-a',
          repositoryId: 'repo',
          // The credential's own fingerprint, recorded as the host key.
          hostKeyFingerprint: kTestCredentialFingerprint,
        );
        final wired = _wire(registry);

        await expectLater(
          wired.acquirer.acquire(
            productId: 'product-a',
            repositoryId: 'repo',
            pinnedRevision: kTestRevision,
          ),
          throwsA(
            isA<HostKeyNotIndependentlyConfirmedException>().having(
              (e) => e.toString(),
              'message',
              contains('public-key fingerprint'),
            ),
          ),
        );
        // And nothing was cloned, so nothing could have been cloned against an
        // unverified host.
        expect(wired.verifier.demandedHostKeyFingerprints, isEmpty);
        expect(wired.materializer.materializations, 0);
      },
    );

    test(
      'does not fall back to scanning the host when none was confirmed',
      () async {
        final registry = RegistryFixture();
        await registry.registerProduct(productId: 'product-a');
        await seedCredential(
          registry.engine,
          productId: 'product-a',
          repositoryId: 'repo',
          confirmed: false,
          // An unconfirmed host also cannot carry a connectivity check — the
          // domain refuses to record one against an unrecognised host — so the
          // credential never becomes usable either. Both halves are missing, and
          // the acquirer must name the half that is actually load-bearing.
          usable: false,
        );
        final wired = _wire(registry);

        await expectLater(
          wired.acquirer.acquire(
            productId: 'product-a',
            repositoryId: 'repo',
            pinnedRevision: kTestRevision,
          ),
          throwsA(
            isA<HostKeyNotIndependentlyConfirmedException>().having(
              (e) => e.toString(),
              'message',
              contains('No key scan was trusted as a substitute'),
            ),
          ),
        );
        expect(wired.verifier.demandedHostKeyFingerprints, isEmpty);
      },
    );

    test('refuses a host key confirmed by nobody', () async {
      // A half-written confirmation row must not read as a decision. The engine
      // requires a confirmer, so this is constructed directly rather than
      // produced through the domain, and the acquirer must still refuse it.
      final registry = RegistryFixture();
      await registry.registerProduct(productId: 'product-a');
      final credential = await seedCredential(
        registry.engine,
        productId: 'product-a',
        repositoryId: 'repo',
        confirmed: false,
        usable: false,
      );
      await registry.store.saveProductCredential(
        credential.copyWith(
          hostKeyStatus: HostKeyStatus.confirmed,
          hostKeyFingerprint: kTestHostKeyFingerprint,
        ),
        expectedVersion: credential.version,
      );
      final wired = _wire(registry);

      await expectLater(
        wired.acquirer.acquire(
          productId: 'product-a',
          repositoryId: 'repo',
          pinnedRevision: kTestRevision,
        ),
        throwsA(isA<BaselineSourceUnavailableException>()),
      );
    });

    test(
      'records the unavailable source as an EXTERNAL dependency, not a refusal by a human',
      () async {
        final registry = RegistryFixture();
        await registry.registerProduct(productId: 'product-a');
        // Registered, but no credential minted: onboarding's cost has not been
        // paid. That is an absent prerequisite, NOT an operator declining to run
        // anything, and the wording has to keep those apart.
        final wired = _wire(registry);

        final error = await wired.acquirer
            .acquire(
              productId: 'product-a',
              repositoryId: 'repo',
              pinnedRevision: kTestRevision,
            )
            .then<Object?>((_) => null, onError: (Object e) => e);
        expect(error, isA<BaselineSourceUnavailableException>());
        expect(
          BaselineSourceUnavailableException.terminalCode,
          'EXTERNAL_BASELINE_SOURCE_DEPENDENCY',
        );
        expect(
          error.toString(),
          isNot(contains('declined')),
          reason:
              'the lane must not present an absent prerequisite as a human '
              'refusal',
        );
      },
    );

    test('refuses a snapshot that is not the pinned revision', () async {
      final registry = RegistryFixture();
      await registry.registerProduct(productId: 'product-a');
      await seedCredential(
        registry.engine,
        productId: 'product-a',
        repositoryId: 'repo',
      );
      final wired = _wire(
        registry,
        // The materializer claims a different commit than the one pinned. A
        // baseline derived from a moving source is not a baseline of anything.
        materializer: ScriptedSnapshotMaterializer(reportRevision: 'f' * 40),
      );

      await expectLater(
        wired.acquirer.acquire(
          productId: 'product-a',
          repositoryId: 'repo',
          pinnedRevision: kTestRevision,
        ),
        throwsA(
          isA<PinnedRevisionNotAcquiredException>().having(
            (e) => e.pinnedRevision,
            'pinnedRevision',
            kTestRevision,
          ),
        ),
      );
      // The tree it refused was released rather than left on disk.
      expect(
        wired.materializer.created,
        everyElement(
          isNot(
            predicate<Directory>((d) => d.existsSync(), 'still on disk'),
          ),
        ),
      );
    });

    test(
      'refuses an empty pinned revision rather than meaning HEAD by it',
      () async {
        final registry = RegistryFixture();
        await registry.registerProduct(productId: 'product-a');
        await seedCredential(
          registry.engine,
          productId: 'product-a',
          repositoryId: 'repo',
        );
        final wired = _wire(registry);

        expect(
          () => wired.acquirer.acquire(
            productId: 'product-a',
            repositoryId: 'repo',
            pinnedRevision: '   ',
          ),
          throwsArgumentError,
        );
      },
    );

    test('a second product needs no configuration of the first', () async {
      // PRODUCT-AGNOSTICISM. Two products, two repositories, two hosts, two
      // deploy keys, two confirmed host keys — the same code, the same
      // arguments, no branch anywhere that names either one.
      final registry = RegistryFixture();
      await registry.registerProduct(
        productId: 'product-a',
        repositoryId: 'repo-a',
        uri: 'git@first-remote.test:org/alpha.git',
      );
      await registry.registerProduct(
        productId: 'product-b',
        repositoryId: 'repo-b',
        uri: 'git@second-remote.test:org/beta.git',
      );
      await seedCredential(
        registry.engine,
        productId: 'product-a',
        repositoryId: 'repo-a',
        host: 'git@first-remote.test:org/alpha.git',
        hostKeyFingerprint: kTestHostKeyFingerprint,
        credentialFingerprint: kTestCredentialFingerprint,
      );
      await seedCredential(
        registry.engine,
        productId: 'product-b',
        repositoryId: 'repo-b',
        host: 'git@second-remote.test:org/beta.git',
        hostKeyFingerprint: kOtherHostKeyFingerprint,
        credentialFingerprint: 'SHA256:secondDeployKeyForTestsOnly',
      );
      final wired = _wire(registry);

      final first = await wired.acquirer.acquire(
        productId: 'product-a',
        repositoryId: 'repo-a',
        pinnedRevision: kTestRevision,
      );
      addTearDown(first.release);
      final second = await wired.acquirer.acquire(
        productId: 'product-b',
        repositoryId: 'repo-b',
        pinnedRevision: kTestRevision,
      );
      addTearDown(second.release);

      expect(first.sourceRef, contains('first-remote.test'));
      expect(second.sourceRef, contains('second-remote.test'));
      // Each acquisition enforced ITS OWN host key, not a shared default.
      expect(wired.verifier.demandedHostKeyFingerprints, [
        kTestHostKeyFingerprint,
        kOtherHostKeyFingerprint,
      ]);
      // Two reads per product, and the count is asserted rather than smoothed
      // over: `verifyAccess` reads the material for its own clone and wipes it,
      // then the snapshot is materialised from a second by-name read. That is
      // the documented cost of reusing both components instead of inventing a
      // third path, and a test that only checked "at least once" would let a
      // future change quietly multiply it.
      expect(wired.secrets.reads, [
        'GIT_TEST_repo-a_SSH',
        'GIT_TEST_repo-a_SSH',
        'GIT_TEST_repo-b_SSH',
        'GIT_TEST_repo-b_SSH',
      ]);
    });
  });
}
