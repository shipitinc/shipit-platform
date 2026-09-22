import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:test/test.dart';

const _pub = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO8vK2mN shipit+repo-1';
const _fp = 'SHA256:0Hq7xK2mN8vR4tL9wQ3sB6y';
const _hostFp = 'SHA256:+DiY3wvvV6TuJJhbpZisF';

void main() {
  late ProductRegistryEngine engine;

  setUp(() async {
    engine = ProductRegistryEngine(
      store: InMemoryProductRegistryStore(),
      humanDecisionStore: InMemoryHumanDecisionStore(),
    );
    await engine.createProduct(productId: 'shipit', name: 'ShipIt');
    await engine.addRepositoryReference(
      repositoryId: 'repo-1',
      productId: 'shipit',
      uri: 'git@github.com:acme/shipit-platform.git',
      provider: RepositoryProvider.github,
    );
  });

  Future<RepositoryCredential> generate({String repo = 'repo-1'}) =>
      engine.recordGeneratedCredential(
        productId: 'shipit',
        repositoryId: repo,
        referenceName: 'GIT_PRODUCT_SHIPIT_REPO1_SSH',
        publicKey: _pub,
        fingerprint: _fp,
        host: 'github.com',
        credentialId: 'cred-1',
      );

  Future<RepositoryCredential> fullyVerified() async {
    await generate();
    await engine.confirmHostKey(
      productId: 'shipit',
      credentialId: 'cred-1',
      hostKeyFingerprint: _hostFp,
      confirmedBy: 'operator',
    );
    return engine.recordCredentialCheck(
      productId: 'shipit',
      credentialId: 'cred-1',
      succeeded: true,
      checkedBy: 'operator',
    );
  }

  group('no key material reaches the domain', () {
    test('a private key passed as the public half is refused', () {
      expect(
        () => engine.recordGeneratedCredential(
          productId: 'shipit',
          repositoryId: 'repo-1',
          referenceName: 'GIT_X',
          publicKey: '-----BEGIN OPENSSH PRIVATE KEY-----\nabc',
          fingerprint: _fp,
        ),
        throwsA(isA<CredentialNotUsableException>()),
      );
    });

    test('only a reference name and the public half are stored', () async {
      final c = await generate();
      expect(c.referenceName, 'GIT_PRODUCT_SHIPIT_REPO1_SSH');
      expect(c.toJson().keys, isNot(contains('privateKey')));
    });
  });

  group('access is proven, never assumed', () {
    test('a generated credential cannot be used', () async {
      await generate();
      expect(
        () => engine.requireUsableCredential(
          productId: 'shipit',
          repositoryId: 'repo-1',
        ),
        throwsA(isA<HostKeyNotConfirmedException>()),
      );
    });

    test('a check against an unconfirmed host is refused outright', () async {
      await generate();
      expect(
        () => engine.recordCredentialCheck(
          productId: 'shipit',
          credentialId: 'cred-1',
          succeeded: true,
          checkedBy: 'operator',
        ),
        throwsA(isA<HostKeyNotConfirmedException>()),
        reason: 'there is no result to record if we refuse to connect',
      );
    });

    test('confirming the host alone is still not usable', () async {
      await generate();
      await engine.confirmHostKey(
        productId: 'shipit',
        credentialId: 'cred-1',
        hostKeyFingerprint: _hostFp,
        confirmedBy: 'operator',
      );
      expect(
        () => engine.requireUsableCredential(
          productId: 'shipit',
          repositoryId: 'repo-1',
        ),
        throwsA(isA<CredentialNotUsableException>()),
      );
    });

    test('host confirmed plus a successful check makes it usable', () async {
      final c = await fullyVerified();
      expect(c.status, CredentialStatus.verified);
      expect(c.canReachRepository, isTrue);
      expect(c.lastVerifiedAt, isNotNull);
      expect(c.lastVerifiedBy, 'operator');
      final usable = await engine.requireUsableCredential(
        productId: 'shipit',
        repositoryId: 'repo-1',
      );
      expect(usable.credentialId, 'cred-1');
    });

    test('a failed check records why and drops usability', () async {
      await fullyVerified();
      final failed = await engine.recordCredentialCheck(
        productId: 'shipit',
        credentialId: 'cred-1',
        succeeded: false,
        checkedBy: 'operator',
        failureReason: 'permission denied (publickey)',
      );
      expect(failed.status, CredentialStatus.failing);
      expect(failed.lastFailureReason, contains('publickey'));
      expect(failed.canReachRepository, isFalse);
      // The earlier success is still on the record, not erased.
      expect(failed.lastVerifiedAt, isNotNull);
    });

    test('host confirmation must be attributable', () async {
      await generate();
      expect(
        () => engine.confirmHostKey(
          productId: 'shipit',
          credentialId: 'cred-1',
          hostKeyFingerprint: _hostFp,
          confirmedBy: '',
        ),
        throwsA(isA<CredentialNotUsableException>()),
      );
    });
  });

  group('host key change fails closed', () {
    test('a different fingerprint is refused and recorded as changed',
        () async {
      await fullyVerified();
      expect(
        () => engine.confirmHostKey(
          productId: 'shipit',
          credentialId: 'cred-1',
          hostKeyFingerprint: 'SHA256:somethingElseEntirely',
          confirmedBy: 'operator',
        ),
        throwsA(isA<HostKeyNotConfirmedException>()),
      );
      final c = await engine.readActiveCredential('shipit', 'repo-1');
      expect(c!.hostKeyStatus, HostKeyStatus.changed);
      expect(c.canReachRepository, isFalse);
    });

    test('a changed host blocks use even though the key was verified',
        () async {
      await fullyVerified();
      try {
        await engine.confirmHostKey(
          productId: 'shipit',
          credentialId: 'cred-1',
          hostKeyFingerprint: 'SHA256:different',
          confirmedBy: 'operator',
        );
      } on HostKeyNotConfirmedException {
        // expected
      }
      expect(
        () => engine.requireUsableCredential(
          productId: 'shipit',
          repositoryId: 'repo-1',
        ),
        throwsA(isA<HostKeyNotConfirmedException>()),
      );
    });
  });

  group('one active credential per repository', () {
    test('issuing a second credential is refused', () async {
      await generate();
      expect(
        () => engine.recordGeneratedCredential(
          productId: 'shipit',
          repositoryId: 'repo-1',
          referenceName: 'GIT_OTHER',
          publicKey: _pub,
          fingerprint: 'SHA256:other',
          credentialId: 'cred-2',
        ),
        throwsA(isA<CredentialNotUsableException>()),
      );
    });

    test('rotation revokes the old key and links the chain', () async {
      await fullyVerified();
      final rotated = await engine.rotateCredential(
        productId: 'shipit',
        repositoryId: 'repo-1',
        referenceName: 'GIT_PRODUCT_SHIPIT_REPO1_SSH',
        publicKey: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP4mQ8 shipit+repo-1',
        fingerprint: 'SHA256:P4mQ8new',
        reason: 'scheduled rotation',
        credentialId: 'cred-2',
      );
      expect(rotated.supersedesCredentialId, 'cred-1');
      expect(rotated.status, CredentialStatus.generated);
      expect(
        rotated.canReachRepository,
        isFalse,
        reason: 'a new key must prove itself again',
      );

      final old = await engine.readCredentials('shipit');
      final revoked = old.firstWhere((c) => c.credentialId == 'cred-1');
      expect(revoked.status, CredentialStatus.revoked);
      expect(revoked.revokedReason, 'scheduled rotation');
    });

    test('revoked credentials stay readable, never deleted', () async {
      await fullyVerified();
      await engine.revokeCredential(
        productId: 'shipit',
        credentialId: 'cred-1',
        reason: 'compromised',
      );
      expect(await engine.readActiveCredential('shipit', 'repo-1'), isNull);
      final all = await engine.readCredentials('shipit');
      expect(all, hasLength(1));
      expect(all.single.revokedReason, 'compromised');
    });

    test('a revoked credential cannot be re-checked into life', () async {
      await fullyVerified();
      await engine.revokeCredential(
        productId: 'shipit',
        credentialId: 'cred-1',
        reason: 'compromised',
      );
      expect(
        () => engine.recordCredentialCheck(
          productId: 'shipit',
          credentialId: 'cred-1',
          succeeded: true,
          checkedBy: 'operator',
        ),
        throwsA(isA<CredentialNotUsableException>()),
      );
    });
  });

  group('scope', () {
    test('another product cannot touch this credential', () async {
      await generate();
      await engine.createProduct(productId: 'other', name: 'Other');
      expect(
        () => engine.confirmHostKey(
          productId: 'other',
          credentialId: 'cred-1',
          hostKeyFingerprint: _hostFp,
          confirmedBy: 'attacker',
        ),
        throwsA(isA<CrossProductAccessException>()),
      );
    });

    test('scope is the repository, so a second repo needs its own key',
        () async {
      await fullyVerified();
      await engine.addRepositoryReference(
        repositoryId: 'repo-2',
        productId: 'shipit',
        uri: 'git@github.com:acme/shipit-docs.git',
        provider: RepositoryProvider.github,
      );
      expect(await engine.readActiveCredential('shipit', 'repo-2'), isNull);
      expect(
        () => engine.requireUsableCredential(
          productId: 'shipit',
          repositoryId: 'repo-2',
        ),
        throwsA(isA<CredentialNotFoundException>()),
      );
    });
  });
}
