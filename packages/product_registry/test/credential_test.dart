import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:test/test.dart';

const _pub = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO8vK2mN shipit+repo-1';
const _fp = 'SHA256:0Hq7xK2mN8vR4tL9wQ3sB6y';
const _hostFp = 'SHA256:+DiY3wvvV6TuJJhbpZisF';

// A DIFFERENT keypair. T-A is about substituting these for the ones above, so
// they must differ in every immutable field, not just the bytes.
const _pub2 = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP4mQ8 shipit+repo-2';
const _fp2 = 'SHA256:P4mQ8new';

/// [base] with [overrides] applied, field by field.
///
/// `RepositoryCredential.copyWith` cannot express what the identity/scope tests
/// need, and that is exactly why no engine call site reaches them: it has NO
/// parameter for `productId` or `repositoryId`, and every nullable parameter it
/// does have falls back to the current value, so it cannot CLEAR one. Building
/// the object directly is the only way to assert the contract a future caller
/// would be held to. A key present in [overrides] is used verbatim — including
/// a `null` value, which is how "clear this column" is expressed.
RepositoryCredential _clone(
  RepositoryCredential base,
  Map<String, Object?> overrides,
) {
  T pick<T>(String key, T fallback) =>
      overrides.containsKey(key) ? overrides[key] as T : fallback;

  return RepositoryCredential(
    credentialId: pick('credentialId', base.credentialId),
    productId: pick('productId', base.productId),
    repositoryId: pick('repositoryId', base.repositoryId),
    referenceName: pick('referenceName', base.referenceName),
    publicKey: pick('publicKey', base.publicKey),
    fingerprint: pick('fingerprint', base.fingerprint),
    algorithm: pick('algorithm', base.algorithm),
    status: pick('status', base.status),
    createdAt: pick('createdAt', base.createdAt),
    lastVerifiedAt: pick('lastVerifiedAt', base.lastVerifiedAt),
    lastVerifiedBy: pick('lastVerifiedBy', base.lastVerifiedBy),
    lastFailureReason: pick('lastFailureReason', base.lastFailureReason),
    hostKeyStatus: pick('hostKeyStatus', base.hostKeyStatus),
    host: pick('host', base.host),
    hostKeyFingerprint: pick('hostKeyFingerprint', base.hostKeyFingerprint),
    hostConfirmedAt: pick('hostConfirmedAt', base.hostConfirmedAt),
    hostConfirmedBy: pick('hostConfirmedBy', base.hostConfirmedBy),
    revokedAt: pick('revokedAt', base.revokedAt),
    revokedReason: pick('revokedReason', base.revokedReason),
    supersedesCredentialId: pick(
      'supersedesCredentialId',
      base.supersedesCredentialId,
    ),
    version: pick('version', base.version),
  );
}

void main() {
  late ProductRegistryEngine engine;

  // Named so a test that calls the STORE directly — rather than going through
  // `engine`, which is how every other test here works — writes to the same
  // store the engine is holding its credential in. A freshly constructed store
  // is empty, and asserting a refusal against it would pass for the wrong
  // reason: it never sees the row at all.
  late InMemoryProductRegistryStore store;

  setUp(() async {
    store = InMemoryProductRegistryStore();
    engine = ProductRegistryEngine(
      store: store,
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

  /// Reads one credential by id out of the product's durable list.
  ///
  /// There is no engine `readCredential(productId, credentialId)`; this keeps
  /// the test on the public API that exists rather than adding one for it.
  Future<RepositoryCredential> readCred(String credentialId) async {
    final all = await engine.readCredentials('shipit');
    return all.firstWhere((c) => c.credentialId == credentialId);
  }

  /// A same-id, self-superseding re-mint of `cred-1` with one immutable field
  /// overridden. This is the call shape T-A is about: it passes the engine's
  /// one-active rule and reaches the store with a NULL `expectedVersion`.
  Future<RepositoryCredential> _remint({
    String? publicKey,
    String? fingerprint,
    String? algorithm,
    String? referenceName,
  }) => engine.recordGeneratedCredential(
    productId: 'shipit',
    repositoryId: 'repo-1',
    credentialId: 'cred-1',
    supersedesCredentialId: 'cred-1',
    referenceName: referenceName ?? 'GIT_PRODUCT_SHIPIT_REPO1_SSH',
    publicKey: publicKey ?? _pub,
    fingerprint: fingerprint ?? _fp,
    algorithm: algorithm ?? 'ed25519',
    host: 'github.com',
  );

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
    test(
      'a different fingerprint is refused and recorded as changed',
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
      },
    );

    test(
      'a changed host blocks use even though the key was verified',
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
      },
    );
  });

  group('one active credential per repository', () {
    test('a second active credential is refused at the second row', () async {
      await generate();
      // WHAT this refusal is, precisely: the engine refuses a SECOND ROW for
      // one repository. `credentialId: 'cred-2'` is a distinct identity and no
      // `supersedesCredentialId` is supplied, so nothing here can reach the
      // same-id re-mint path guarded by the group below. This test used to be
      // the suite's only claim on "one credential per repository", and passing
      // it was mistaken for the key being unchangeable — it is not the same
      // mechanism, so the refusal reason is pinned below to keep the two from
      // being confused again.
      await expectLater(
        engine.recordGeneratedCredential(
          productId: 'shipit',
          repositoryId: 'repo-1',
          referenceName: 'GIT_OTHER',
          publicKey: _pub,
          fingerprint: 'SHA256:other',
          credentialId: 'cred-2',
        ),
        throwsA(
          isA<CredentialNotUsableException>().having(
            (e) => e.reason,
            'reason',
            allOf(
              contains('already has an active credential'),
              isNot(contains('key material')),
            ),
          ),
        ),
      );
      // The refusal left the first credential exactly as it was.
      final stored = await engine.readCredentials('shipit');
      expect(stored, hasLength(1));
      expect(stored.single.credentialId, 'cred-1');
      expect(stored.single.publicKey, _pub);
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

  group('key material is chosen once, at mint', () {
    // T-A. The store must refuse to change the key material of a credentialId
    // that already exists. Before the guard this call overwrote `publicKey` on
    // the existing row in place — same identity, no rotation record, `status`
    // reset to `generated`, and the operator's host confirmation discarded.
    //
    // The engine's one-active rule (engine:940-941) does NOT catch this: it
    // declines to refuse precisely when `supersedesCredentialId` equals the
    // active credential's id, which is what makes this call reach the write.
    test(
      'a same-id re-mint is refused and the stored row is untouched',
      () async {
        final before = await fullyVerified();
        expect(
          before.publicKey,
          _pub,
          reason: 'precondition: the installed key is the one at risk',
        );

        await expectLater(
          engine.recordGeneratedCredential(
            productId: 'shipit',
            repositoryId: 'repo-1',
            // Same identity, self-superseding: passes the one-active rule.
            credentialId: 'cred-1',
            supersedesCredentialId: 'cred-1',
            referenceName: 'GIT_PRODUCT_SHIPIT_REPO1_ROTATED',
            publicKey: _pub2,
            fingerprint: _fp2,
            algorithm: 'ecdsa-sha2-nistp256',
            host: 'github.com',
          ),
          throwsA(isA<CredentialNotUsableException>()),
        );

        final after = await readCred('cred-1');
        expect(after.publicKey, _pub, reason: 'the installed key must survive');
        expect(after.fingerprint, _fp);
        expect(after.algorithm, 'ed25519');
        expect(after.referenceName, 'GIT_PRODUCT_SHIPIT_REPO1_SSH');
        expect(after.status, CredentialStatus.verified);
        expect(after.hostKeyStatus, HostKeyStatus.confirmed);
        expect(after.hostConfirmedAt, isNotNull);
        expect(after.hostConfirmedBy, 'operator');
        expect(after.version, before.version);
        expect(
          after,
          before,
          reason: 'the refusal must change nothing at all on the row',
        );
      },
    );

    // The store contract is UNCONDITIONAL: it holds whether or not the caller
    // passes `expectedVersion`. T-A reaches the write with a NULL
    // `expectedVersion`, so it never exercised the CAS branch — and the CAS
    // branch is where the two tiers disagreed, because the Postgres UPDATE had
    // no key-material predicate and so rewrote `publicKey` while this store
    // refused. Unreachable through the engine today (every CAS call site uses
    // `copyWith`, which cannot set these four fields), so it is asserted against
    // the store interface directly: that is the contract, and a future caller
    // must not be able to discover the hole by writing one line.
    test('the CAS path refuses a key-material change too, and does not '
        'misreport it as a lost race', () async {
      // The group-level `store`, NOT a fresh one: `fullyVerified()` below
      // mints through `engine`, which holds its credential in `store`.
      final before = await fullyVerified();

      // Built field by field, not with `copyWith`: `copyWith` cannot set the
      // four immutable fields, which is why no engine call site reaches this
      // path today. Constructing one directly is the only way to assert the
      // contract a future caller would be held to.
      final rekeyed = RepositoryCredential(
        credentialId: before.credentialId,
        productId: before.productId,
        repositoryId: before.repositoryId,
        referenceName: before.referenceName,
        publicKey: _pub2,
        fingerprint: _fp2,
        algorithm: before.algorithm,
        status: before.status,
        createdAt: before.createdAt,
        lastVerifiedAt: before.lastVerifiedAt,
        lastVerifiedBy: before.lastVerifiedBy,
        lastFailureReason: before.lastFailureReason,
        hostKeyStatus: before.hostKeyStatus,
        host: before.host,
        hostKeyFingerprint: before.hostKeyFingerprint,
        hostConfirmedAt: before.hostConfirmedAt,
        hostConfirmedBy: before.hostConfirmedBy,
        revokedAt: before.revokedAt,
        revokedReason: before.revokedReason,
        supersedesCredentialId: before.supersedesCredentialId,
        version: before.version,
      );
      await expectLater(
        store.saveProductCredential(rekeyed, expectedVersion: before.version),
        throwsA(
          isA<CredentialNotUsableException>().having(
            (e) => e.runtimeType,
            'exception type',
            CredentialNotUsableException,
          ),
        ),
        reason:
            'a matching expectedVersion must not buy a key-material rewrite',
      );

      expect(
        await store.readProductCredential('cred-1'),
        before,
        reason: 'the refusal must change nothing at all on the row',
      );

      // The same write with a stale version is still a genuine CAS conflict,
      // so the two refusals must stay distinguishable: reporting "concurrent
      // modification" to a caller that re-pointed key material invites it to
      // retry the same re-point.
      await expectLater(
        store.saveProductCredential(
          rekeyed,
          expectedVersion: before.version + 99,
        ),
        throwsA(isA<CredentialNotUsableException>()),
        reason: 'the immutability refusal takes precedence over the version',
      );

      // And a legitimate CAS write of a non-key-material field still works,
      // so the guard is not simply refusing every update.
      await store.saveProductCredential(
        before.copyWith(lastFailureReason: 'transient'),
        expectedVersion: before.version,
      );
      expect(
        (await store.readProductCredential('cred-1')).lastFailureReason,
        'transient',
        reason: 'a non-key-material CAS write must still land',
      );
    });

    test('each immutable field is guarded on its own', () async {
      final before = await fullyVerified();

      // One case per immutable field, each a single-field change against the
      // stored row. Any one of them silently succeeding is the defect.
      final mutations = <String, Future<RepositoryCredential> Function()>{
        'publicKey': () => _remint(publicKey: _pub2),
        'fingerprint': () => _remint(fingerprint: _fp2),
        'algorithm': () => _remint(algorithm: 'ecdsa-sha2-nistp256'),
        'referenceName': () => _remint(referenceName: 'GIT_SOMETHING_ELSE'),
      };

      for (final entry in mutations.entries) {
        await expectLater(
          entry.value(),
          throwsA(isA<CredentialNotUsableException>()),
          reason: '${entry.key} is immutable once minted',
        );
        expect(
          await readCred('cred-1'),
          before,
          reason: '${entry.key} must not have been written',
        );
      }
    });

    test('the first mint of a new id still succeeds', () async {
      // The guard predicates the immutable fields, so it must not refuse a
      // row that does not exist yet. A CAS-shaped guard would break here:
      // `recordGeneratedCredential` passes no `expectedVersion` for a genuine
      // insert, and a hardcoded `version: 1` would match nothing.
      final minted = await generate();
      expect(minted.credentialId, 'cred-1');
      expect(minted.publicKey, _pub);
      expect(minted.status, CredentialStatus.generated);
      expect(await engine.readActiveCredential('shipit', 'repo-1'), minted);
    });

    test(
      'rotation is the only way to change the key, and it mints a new id',
      () async {
        final before = await fullyVerified();

        final rotated = await engine.rotateCredential(
          productId: 'shipit',
          repositoryId: 'repo-1',
          referenceName: 'GIT_PRODUCT_SHIPIT_REPO1_SSH',
          publicKey: _pub2,
          fingerprint: _fp2,
          reason: 'scheduled rotation',
          credentialId: 'cred-2',
        );

        expect(rotated.credentialId, 'cred-2');
        expect(rotated.supersedesCredentialId, 'cred-1');
        expect(rotated.publicKey, _pub2);
        expect(rotated.status, CredentialStatus.generated);
        expect(
          rotated.hostKeyStatus,
          HostKeyStatus.unknown,
          reason: 'host confirmation does not carry over to a new key',
        );
        expect(rotated.hostConfirmedAt, isNull);
        expect(rotated.hostConfirmedBy, isNull);

        // The superseded row keeps the key material it was minted with.
        final old = await readCred('cred-1');
        expect(old.publicKey, before.publicKey);
        expect(old.fingerprint, before.fingerprint);
        expect(old.status, CredentialStatus.revoked);
      },
    );
  });

  // -------------------------------------------------------------------------
  // D-4 (mint is insert-only), D-18 (no resurrection through a re-mint) and
  // D-5 (the scope set is immutable) — the completion of the group above.
  //
  // The group above asserts that the KEY cannot be re-pointed. These assert the
  // other two halves of the same statement, which nothing covered:
  //
  //   * a re-mint with IDENTICAL material upserted the row, because D-1's
  //     predicate is SATISFIED by identical values. No key substitution is
  //     needed to do it — and it reset `status` to `generated`, `hostKeyStatus`
  //     to `unknown`, and nulled host confirmation, verification, diagnostics
  //     and revocation evidence;
  //   * combined with the above, that made a REVOKED credential resurrectable,
  //     because `readActiveCredentialForRepository` excludes revoked rows, so
  //     the engine's one-active guard cannot fire against one;
  //   * and `repositoryId`/`productId` stayed rewritable, so an installed
  //     deploy key could be silently moved to another repository of the same
  //     product with no rotation record.
  // -------------------------------------------------------------------------
  group('identity and scope are fixed at mint', () {
    /// A same-id, self-superseding re-mint of `cred-1` with material IDENTICAL
    /// to what is stored. This is the call shape D-1's predicate is satisfied
    /// by, and the only one that needed no key substitution to reach.
    Future<RepositoryCredential> _remintIdentical({
      String repositoryId = 'repo-1',
    }) => engine.recordGeneratedCredential(
      productId: 'shipit',
      repositoryId: repositoryId,
      credentialId: 'cred-1',
      supersedesCredentialId: 'cred-1',
      referenceName: 'GIT_PRODUCT_SHIPIT_REPO1_SSH',
      publicKey: _pub,
      fingerprint: _fp,
      algorithm: 'ed25519',
      host: 'github.com',
    );

    /// A second repository of the SAME product, with no credential of its own.
    /// The precondition D-5's mint-path case needs: the engine's one-active
    /// guard reads the TARGET repository, so it passes when the target is empty.
    Future<void> addRepo2() => engine.addRepositoryReference(
      repositoryId: 'repo-2',
      productId: 'shipit',
      uri: 'git@github.com:acme/shipit-docs.git',
      provider: RepositoryProvider.github,
    );

    // T-C / D-4.
    test(
      'T-C: an identical-material re-mint is refused and the row is untouched',
      () async {
        final before = await fullyVerified();
        expect(
          before.status,
          CredentialStatus.verified,
          reason: 'precondition: there is state here for a mint to destroy',
        );

        await expectLater(
          _remintIdentical(),
          throwsA(
            isA<CredentialNotUsableException>().having(
              (e) => e.reason,
              'reason',
              // An identity conflict is not a key-material refusal, and the
              // two must stay tellable apart.
              allOf(
                contains('already exists'),
                isNot(contains('key material')),
              ),
            ),
          ),
        );

        // Every column, not a summary of them: the whole claim of D-4 is that
        // the mint writes NOTHING onto an existing row.
        final after = await readCred('cred-1');
        expect(after.status, CredentialStatus.verified);
        expect(after.hostKeyStatus, HostKeyStatus.confirmed);
        expect(after.hostConfirmedAt, isNotNull);
        expect(after.hostConfirmedBy, 'operator');
        expect(after.hostKeyFingerprint, _hostFp);
        expect(after.lastVerifiedAt, isNotNull);
        expect(after.lastVerifiedBy, 'operator');
        expect(after.lastFailureReason, isNull);
        expect(after.createdAt, before.createdAt);
        expect(after.revokedAt, isNull);
        expect(after.revokedReason, isNull);
        expect(after.version, before.version);
        expect(
          after,
          before,
          reason: 'the refusal must change nothing at all on the row',
        );
      },
    );

    // T-E — pins WHICH refusal a different-material re-mint gets. The reason
    // matters: it must be the identity conflict, not the key-material one.
    //
    // Two things this catches, both verified by removing the guard and watching
    // it go red. Drop the insert-only guard and this row's refusal becomes the
    // key-material one; put the insert-only guard AFTER the key-material check
    // and it does the same. Neither is visible on a test that only asserts
    // "throws".
    //
    // What it does NOT catch: the dangerous wrong implementation of insert-only
    // — predicating the conflict on the material DIFFERING, which lets a
    // re-point through. On this tier the unconditional key-material check below
    // it backstops that, so no in-memory test can witness it. The Postgres T-E
    // is the load-bearing one, because `DO NOTHING` replaced the whole update.
    test('T-E: a different-material re-mint is refused too, as an identity '
        'conflict', () async {
      final before = await fullyVerified();

      await expectLater(
        _remint(publicKey: _pub2),
        throwsA(
          isA<CredentialNotUsableException>().having(
            (e) => e.reason,
            'reason',
            contains('already exists'),
          ),
        ),
      );
      final after = await readCred('cred-1');
      expect(after.publicKey, _pub, reason: 'the installed key must survive');
      expect(after.fingerprint, _fp);
      expect(after.status, CredentialStatus.verified);
      expect(after, before, reason: 'the refusal must change nothing at all');

      // D-1 keeps its own refusal on the CAS branch, where the material IS
      // visible — the existing "the CAS path refuses a key-material change
      // too" test in the group above pins that, and it is unchanged.
    });

    // D-18. § R.9.2 of Design Revision 3: the revoked row is excluded from the
    // active read, so the one-active guard cannot see it, so the mint reaches
    // the write and the row comes back to life as `generated`.
    test(
      'T-D: a revoked credential cannot be resurrected by a re-mint',
      () async {
        await fullyVerified();
        await engine.revokeCredential(
          productId: 'shipit',
          credentialId: 'cred-1',
          reason: 'compromised',
        );
        final revoked = await readCred('cred-1');
        expect(revoked.status, CredentialStatus.revoked);
        expect(
          await engine.readActiveCredential('shipit', 'repo-1'),
          isNull,
          reason: 'precondition: a revoked row is outside the active set',
        );

        await expectLater(
          _remintIdentical(),
          throwsA(isA<CredentialNotUsableException>()),
        );

        final after = await readCred('cred-1');
        expect(after.status, CredentialStatus.revoked);
        expect(after.revokedAt, revoked.revokedAt);
        expect(after.revokedReason, 'compromised');
        expect(
          await engine.readActiveCredential('shipit', 'repo-1'),
          isNull,
          reason:
              'the refused mint must not put the row back in the active set',
        );

        // The consequence the design names: the resurrected row would occupy
        // the active set and block the legitimate mint. This is the assertion
        // that would go red if the mint were merely "refused for an unrelated
        // reason" while still leaving a usable row behind.
        final fresh = await engine.recordGeneratedCredential(
          productId: 'shipit',
          repositoryId: 'repo-1',
          referenceName: 'GIT_PRODUCT_SHIPIT_REPO1_SSH',
          publicKey: _pub2,
          fingerprint: _fp2,
          credentialId: 'cred-2',
        );
        expect(fresh.credentialId, 'cred-2');
        expect(
          (await engine.readActiveCredential('shipit', 'repo-1'))?.credentialId,
          'cred-2',
          reason: 'a fresh mint must take the slot the revoked row vacated',
        );
      },
    );

    // D-5, mint path. `_ensureOwned` blocks crossing products, so the blast
    // radius is one product's repositories — which is exactly this shape.
    test(
      'T-F: repositoryId cannot be re-pointed on an existing identity',
      () async {
        final before = await fullyVerified();
        await addRepo2();
        expect(
          await engine.readActiveCredential('shipit', 'repo-2'),
          isNull,
          reason: 'precondition: the target repository has no credential',
        );

        await expectLater(
          _remintIdentical(repositoryId: 'repo-2'),
          throwsA(isA<CredentialNotUsableException>()),
        );

        expect(
          await readCred('cred-1'),
          before,
          reason: 'the installed key must still belong to repo-1',
        );
        expect(
          await engine.readActiveCredential('shipit', 'repo-2'),
          isNull,
          reason: 'repo-2 must gain no credential of its own from this write',
        );
      },
    );

    // D-5 on the CAS branch, and T-G. A CAS write has no D-4 to save it: the
    // scope fields are not in D-1's predicate on either branch, so the guard
    // has to be there explicitly. Unreachable through the engine (copyWith has
    // no parameter for either field), so it is asserted against the store.
    test('T-G: the scope fields are immutable on the CAS path too', () async {
      final before = await fullyVerified();
      await addRepo2();

      // `expectedVersion` MATCHES, so nothing but the guard can refuse these.
      for (final scope in ['repositoryId', 'productId']) {
        await expectLater(
          store.saveProductCredential(
            _clone(before, {
              scope: scope == 'repositoryId' ? 'repo-2' : 'other',
            }),
            expectedVersion: before.version,
          ),
          throwsA(
            isA<CredentialNotUsableException>().having(
              (e) => e.reason,
              'reason',
              contains('cannot be changed'),
            ),
          ),
          reason: '$scope is immutable once minted, even on a matching CAS',
        );
        expect(
          await store.readProductCredential('cred-1'),
          before,
          reason: '$scope must not have been written',
        );
      }

      // And the guard is not simply refusing every update: a legitimate CAS
      // write of a mutable field still lands.
      await store.saveProductCredential(
        before.copyWith(lastFailureReason: 'transient'),
        expectedVersion: before.version,
      );
      expect(
        (await store.readProductCredential('cred-1')).lastFailureReason,
        'transient',
      );
    });

    // D-4 on the CAS branch. `copyWith` cannot unset these fields, which is
    // what stops every engine call site today; the statement is what makes it
    // true against any other connection.
    test(
      'a CAS write cannot clear host confirmation, verification or revocation',
      () async {
        final before = await fullyVerified();

        for (final column in [
          'hostConfirmedAt',
          'hostConfirmedBy',
          'lastVerifiedAt',
          'lastVerifiedBy',
        ]) {
          await expectLater(
            store.saveProductCredential(
              _clone(before, {column: null}),
              expectedVersion: before.version,
            ),
            throwsA(isA<CredentialNotUsableException>()),
            reason: '$column is durable evidence and cannot be cleared',
          );
          expect(await store.readProductCredential('cred-1'), before);
        }

        // `revokedAt` needs a revoked row to be meaningful: on a live
        // credential there is nothing to erase, so a write that "clears" it
        // is indistinguishable from one that leaves it alone.
        await engine.revokeCredential(
          productId: 'shipit',
          credentialId: 'cred-1',
          reason: 'compromised',
        );
        final revoked = await readCred('cred-1');
        await expectLater(
          store.saveProductCredential(
            _clone(revoked, {'revokedAt': null, 'revokedReason': null}),
            expectedVersion: revoked.version,
          ),
          throwsA(isA<CredentialNotUsableException>()),
          reason: 'revocation cannot be un-done by a CAS write',
        );
        expect(await store.readProductCredential('cred-1'), revoked);
      },
    );
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

    test(
      'scope is the repository, so a second repo needs its own key',
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
      },
    );
  });
}
