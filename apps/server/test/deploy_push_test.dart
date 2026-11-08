import 'dart:convert';
import 'dart:io';

import 'package:control_plane_server/src/deploy/deploy_push.dart';
import 'package:control_plane_server/src/credentials/secret_material.dart';
import 'package:control_plane_server/src/credentials/secret_provider.dart';
import 'package:control_plane_server/src/credentials/ssh_remote.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart'
    show
        InMemoryHumanDecisionStore,
        InMemoryProductRegistryStore,
        ProductRegistryEngine;
import 'package:test/test.dart';

/// The deploy push: `deployed` now means the landed branch reached the
/// product remote — F-258.
///
/// ## THE DEFECT THIS FILE HOLDS CLOSED
///
/// `landApprovedDeployment` merged the produced commit into the recorded
/// checkout's default branch and stamped `deployed` — while the product's
/// `origin` remote never received anything. The push is now part of the
/// land on BOTH arms (merge and already-landed): the branch is pushed via
/// the product's ACTIVE verified deploy key, a refusal throws
/// `DeployLandingException` (nothing durable written, the decision stays
/// pending), and a retried approve/re-land completes an interrupted push
/// instead of failing on it.
///
/// ## WHAT IS ASSERTED, AND AGAINST WHAT
///
///   * `RegistryDeployPusher` — credential resolution over the REAL
///     `ProductRegistryEngine` + `InMemoryProductRegistryStore`: origin URL
///     read, `SshRemote` normalization match, active-verified-credential
///     checks, one secret read wiped in `finally`. The transport is a
///     recording fake so no network exists.
///   * `SshDeployPushTransport` — the REAL transport over REAL git: the
///     remote is a bare repository on a local path (so `fetch`/`push` run
///     for real and `ssh` is never invoked), and `ssh-keyscan` is stubbed
///     through the `pathPrefix` seam while real `ssh-keygen` computes the
///     fingerprint — the same discipline
///     `durable_workspace_materializer_test.dart` keeps.
///   * fetch → ancestry → push → re-fetch → verify semantics: pushed,
///     `alreadyCurrent` (equal tip AND remote-ahead-containing), diverged
///     refusal, absent-branch creation, host-key-mismatch refusal, and no
///     credential scratch left on disk.
void main() {
  group('RegistryDeployPusher — credential resolution', () {
    late _ResolutionFixture fixture;
    late Directory repo;

    setUp(() async {
      fixture = _ResolutionFixture();
      await fixture.seedProduct();
      repo = await _repoWithOrigin('git@remote.test:org/repo.git');
    });

    tearDown(() async {
      if (repo.existsSync()) await repo.delete(recursive: true);
    });

    test('pushes with the active verified credential — secret read by name, '
        'wiped', () async {
      final push = await fixture.pusher.pushLandedBranch(
        item: _item(),
        repositoryPath: repo.path,
        targetBranch: 'main',
        localHead: _head,
      );

      expect(push.state, DeployPushState.pushed);
      expect(fixture.transport.calls, hasLength(1));
      final call = fixture.transport.calls.single;
      expect(call.branch, 'main');
      expect(call.localHead, _head);
      expect(call.repositoryPath, repo.path);
      // scp-like origin == ssh:// registry URI, normalized to one remote.
      expect(call.remote.toSshUrl(), 'ssh://git@remote.test:22/org/repo.git');
      expect(
        call.confirmedHostKeyFingerprint,
        _ResolutionFixture.hostKeyFingerprint,
      );

      // ONE secret read, by reference name, and the material was wiped by
      // the caller's `finally` — assert on the same SecretBytes instance the
      // provider handed out.
      expect(fixture.provider.reads, ['GIT_REPOSITORY_repo-1_SSH']);
      expect(
        fixture.secret.bytes.every((b) => b == 0),
        isTrue,
        reason: 'the private half must be wiped before push returns',
      );
    });

    test('the ssh:// form of the same remote matches too', () async {
      if (repo.existsSync()) await repo.delete(recursive: true);
      repo = await _repoWithOrigin('ssh://git@remote.test:22/org/repo.git');

      final push = await fixture.pusher.pushLandedBranch(
        item: _item(),
        repositoryPath: repo.path,
        targetBranch: 'main',
        localHead: _head,
      );
      expect(push.state, DeployPushState.pushed);
      expect(fixture.transport.calls.single.repositoryId, 'repo-1');
    });

    test('a checkout with no origin remote is refused', () async {
      if (repo.existsSync()) await repo.delete(recursive: true);
      repo = await Directory.systemTemp.createTemp('deploy_push_noorigin_');
      await _git(repo.path, ['init', '-b', 'main']);

      await expectLater(
        fixture.pusher.pushLandedBranch(
          item: _item(),
          repositoryPath: repo.path,
          targetBranch: 'main',
          localHead: _head,
        ),
        throwsA(isA<DeployPushRefusedException>()),
      );
      expect(fixture.transport.calls, isEmpty);
      expect(fixture.provider.reads, isEmpty);
    });

    test(
      'an https origin is refused — no deploy key can authenticate',
      () async {
        if (repo.existsSync()) await repo.delete(recursive: true);
        repo = await _repoWithOrigin('https://remote.test/org/repo.git');

        await expectLater(
          fixture.pusher.pushLandedBranch(
            item: _item(),
            repositoryPath: repo.path,
            targetBranch: 'main',
            localHead: _head,
          ),
          throwsA(isA<DeployPushRefusedException>()),
        );
        expect(fixture.provider.reads, isEmpty);
      },
    );

    test('an origin naming no registered repository is refused', () async {
      if (repo.existsSync()) await repo.delete(recursive: true);
      repo = await _repoWithOrigin('git@remote.test:org/elsewhere.git');

      await expectLater(
        fixture.pusher.pushLandedBranch(
          item: _item(),
          repositoryPath: repo.path,
          targetBranch: 'main',
          localHead: _head,
        ),
        throwsA(isA<DeployPushRefusedException>()),
      );
      expect(fixture.provider.reads, isEmpty);
    });

    test('an origin matching two registered repositories is refused — the '
        'credential is unresolvable, not guessed', () async {
      await fixture.engine.addRepositoryReference(
        repositoryId: 'repo-2',
        productId: _productId,
        uri: 'ssh://git@remote.test/org/repo.git',
      );

      await expectLater(
        fixture.pusher.pushLandedBranch(
          item: _item(),
          repositoryPath: repo.path,
          targetBranch: 'main',
          localHead: _head,
        ),
        throwsA(isA<DeployPushRefusedException>()),
      );
      expect(fixture.provider.reads, isEmpty);
    });

    test('no minted credential is refused', () async {
      final bare = _ResolutionFixture();
      await bare.seedProduct(withCredential: false);
      await expectLater(
        bare.pusher.pushLandedBranch(
          item: _item(),
          repositoryPath: repo.path,
          targetBranch: 'main',
          localHead: _head,
        ),
        throwsA(isA<DeployPushRefusedException>()),
      );
      expect(bare.provider.reads, isEmpty);
    });

    test('a generated-but-unverified credential is refused', () async {
      final unverified = _ResolutionFixture();
      await unverified.seedProduct(verified: false);
      await expectLater(
        unverified.pusher.pushLandedBranch(
          item: _item(),
          repositoryPath: repo.path,
          targetBranch: 'main',
          localHead: _head,
        ),
        throwsA(isA<DeployPushRefusedException>()),
      );
    });

    test('an unconfirmed host key is refused', () async {
      final unconfirmed = _ResolutionFixture();
      await unconfirmed.seedProduct(hostConfirmed: false, verified: false);
      await expectLater(
        unconfirmed.pusher.pushLandedBranch(
          item: _item(),
          repositoryPath: repo.path,
          targetBranch: 'main',
          localHead: _head,
        ),
        throwsA(isA<DeployPushRefusedException>()),
      );
    });

    test(
      'a host key fingerprint equal to the credential\'s own is refused',
      () async {
        final confused = _ResolutionFixture();
        await confused.seedProduct(
          hostKeyFingerprint: _ResolutionFixture.ownFingerprint,
        );
        await expectLater(
          confused.pusher.pushLandedBranch(
            item: _item(),
            repositoryPath: repo.path,
            targetBranch: 'main',
            localHead: _head,
          ),
          throwsA(isA<DeployPushRefusedException>()),
        );
      },
    );

    test('no custody substrate is refused', () async {
      final pusher = RegistryDeployPusher(
        engine: fixture.engine,
        secretProvider: null,
        transport: fixture.transport,
      );
      await expectLater(
        pusher.pushLandedBranch(
          item: _item(),
          repositoryPath: repo.path,
          targetBranch: 'main',
          localHead: _head,
        ),
        throwsA(isA<DeployPushRefusedException>()),
      );
      expect(fixture.provider.reads, isEmpty);
    });

    test(
      'a custody read that fails is refused and the transport never runs',
      () async {
        fixture.provider.readFailure = SecretStoreException(
          referenceName: 'GIT_REPOSITORY_repo-1_SSH',
          providerId: 'local_file',
          operation: 'read',
          reason: 'the file does not exist',
        );
        await expectLater(
          fixture.pusher.pushLandedBranch(
            item: _item(),
            repositoryPath: repo.path,
            targetBranch: 'main',
            localHead: _head,
          ),
          throwsA(isA<SecretStoreException>()),
        );
        expect(fixture.transport.calls, isEmpty);
      },
    );

    test(
      'a transport refusal propagates; an unaudited failure is wrapped',
      () async {
        fixture.transport.failure = const DeployPushRefusedException(
          'the remote rejected the push',
        );
        await expectLater(
          fixture.pusher.pushLandedBranch(
            item: _item(),
            repositoryPath: repo.path,
            targetBranch: 'main',
            localHead: _head,
          ),
          throwsA(isA<DeployPushRefusedException>()),
        );

        fixture.transport.failure = StateError('an unaudited defect');
        Object? error;
        try {
          await fixture.pusher.pushLandedBranch(
            item: _item(),
            repositoryPath: repo.path,
            targetBranch: 'main',
            localHead: _head,
          );
        } on Object catch (e) {
          error = e;
        }
        expect(error, isA<DeployPushRefusedException>());
        expect(
          error.toString(),
          isNot(contains('an unaudited defect')),
          reason:
              'an unaudited failure is suppressed to its type — its message '
              'must not reach a durable record',
        );
        expect(
          fixture.secret.bytes.every((b) => b == 0),
          isTrue,
          reason: 'the private half is wiped on the failure path too',
        );
      },
    );
  });

  group('SshDeployPushTransport — real git, fetch→ancestry→push→verify', () {
    late Directory scratch;
    late Directory bin;
    late Directory remote;
    late Directory repo;
    late String hostKeyFingerprint;

    SshRemote remoteRef() => SshRemote(
      user: 'git',
      host: 'remote.test',
      port: 22,
      repositoryPath: 'org/repo.git',
    );

    setUp(() async {
      scratch = await Directory.systemTemp.createTemp('deploy_push_transport_');
      bin = await Directory('${scratch.path}/bin').create();
      final (line, fingerprint) = _realHostKey(scratch);
      hostKeyFingerprint = fingerprint;
      _writeStub(bin, 'ssh-keyscan', '#!/bin/sh\necho "$line"\nexit 0\n');

      // The remote is a bare repository on a LOCAL PATH: `fetch` and `push`
      // run for real against it, and git never invokes `ssh` for a path
      // remote — so the whole ancestry/push/verify sequence is exercised
      // while the host-key half is stubbed at the scan.
      remote = await Directory('${scratch.path}/remote.git').create();
      await _git(remote.path, ['init', '--bare', '-b', 'main']);
      repo = await Directory('${scratch.path}/checkout').create();
      await _git(scratch.path, ['clone', remote.path, repo.path]);
    });

    tearDown(() async {
      if (scratch.existsSync()) await scratch.delete(recursive: true);
      // The transport's own scratch must not leak either.
      for (final stray in Directory.systemTemp.listSync().where(
        (e) => e.path.split('/').last.startsWith('deploy_push_test_'),
      )) {
        await stray.delete(recursive: true);
      }
    });

    Future<DeployPush> push({required String branch, required String head}) =>
        SshDeployPushTransport(
          pathPrefix: bin.path,
          scratchPrefix: 'deploy_push_test_',
        ).pushBranchToRemote(
          productId: _productId,
          repositoryId: 'repo-1',
          repositoryPath: repo.path,
          branch: branch,
          localHead: head,
          remote: remoteRef(),
          privateKeyPem: SecretBytes(List<int>.generate(32, (i) => i + 1)),
          confirmedHostKeyFingerprint: hostKeyFingerprint,
        );

    test('pushes the landed head to a remote that lacks the branch', () async {
      final head = await _commitOn(repo.path, 'main', 'the landed work');

      final result = await push(branch: 'main', head: head);

      expect(result.state, DeployPushState.pushed);
      expect(result.branch, 'main');
      expect(result.remoteHead, head);
      // REAL: the remote's main IS the landed head.
      expect(
        await _git(remote.path, ['rev-parse', 'refs/heads/main']),
        head,
      );
    });

    test(
      'a second push of the same head is alreadyCurrent — idempotent',
      () async {
        final head = await _commitOn(repo.path, 'main', 'first');
        await push(branch: 'main', head: head);

        final again = await push(branch: 'main', head: head);

        expect(again.state, DeployPushState.alreadyCurrent);
        expect(again.remoteHead, head);
        expect(await _git(remote.path, ['rev-parse', 'refs/heads/main']), head);
      },
    );

    test('a remote that already CONTAINS the head is alreadyCurrent — the '
        'interrupted-push retry shape', () async {
      final head = await _commitOn(repo.path, 'main', 'first');
      await push(branch: 'main', head: head);

      // A concurrent writer pushed one more commit on top of our head.
      final other = await Directory('${scratch.path}/other').create();
      await _git(scratch.path, ['clone', remote.path, other.path]);
      await _commitOn(other.path, 'main', 'concurrent work on top');
      await _git(other.path, ['push', 'origin', 'main']);

      final result = await push(branch: 'main', head: head);

      expect(result.state, DeployPushState.alreadyCurrent);
      // The remote tip is the concurrent head, which CONTAINS our head.
      expect(
        await _exit(repo.path, [
          'merge-base',
          '--is-ancestor',
          head,
          result.remoteHead,
        ]),
        0,
      );
    });

    test('a diverged remote is refused — never force-pushed', () async {
      // The remote gets a commit the landed branch does not contain.
      final other = await Directory('${scratch.path}/other').create();
      await _git(scratch.path, ['clone', remote.path, other.path]);
      final divergent = await _commitOn(other.path, 'main', 'remote moved');
      await _git(other.path, ['push', 'origin', 'main']);
      final head = await _commitOn(repo.path, 'main', 'local land');

      await expectLater(
        push(branch: 'main', head: head),
        throwsA(isA<DeployPushRefusedException>()),
      );
      expect(
        await _git(remote.path, ['rev-parse', 'refs/heads/main']),
        divergent,
        reason: 'a refused push must not move the remote — no force',
      );
    });

    test(
      'a host presenting no matching key is refused BEFORE the push',
      () async {
        final head = await _commitOn(repo.path, 'main', 'the landed work');
        await expectLater(
          SshDeployPushTransport(
            pathPrefix: bin.path,
            scratchPrefix: 'deploy_push_test_',
          ).pushBranchToRemote(
            productId: _productId,
            repositoryId: 'repo-1',
            repositoryPath: repo.path,
            branch: 'main',
            localHead: head,
            remote: remoteRef(),
            privateKeyPem: SecretBytes(List<int>.generate(32, (i) => i + 1)),
            confirmedHostKeyFingerprint:
                'SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
          ),
          throwsA(isA<DeployPushRefusedException>()),
        );
        // And nothing reached the remote.
        expect(
          await _exit(remote.path, [
            'rev-parse',
            '-q',
            '--verify',
            'refs/heads/main',
          ]),
          isNot(0),
        );
      },
    );

    test('no credential scratch survives either path', () async {
      final head = await _commitOn(repo.path, 'main', 'cleanup subject');
      await push(branch: 'main', head: head);
      await expectLater(
        SshDeployPushTransport(
          pathPrefix: bin.path,
          scratchPrefix: 'deploy_push_test_',
        ).pushBranchToRemote(
          productId: _productId,
          repositoryId: 'repo-1',
          repositoryPath: repo.path,
          branch: 'main',
          localHead: head,
          remote: remoteRef(),
          privateKeyPem: SecretBytes(List<int>.generate(32, (i) => i + 1)),
          confirmedHostKeyFingerprint:
              'SHA256:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
        ),
        throwsA(isA<DeployPushRefusedException>()),
      );
      final strays = Directory.systemTemp
          .listSync()
          .where((e) => e.path.split('/').last.startsWith('deploy_push_test_'))
          .toList();
      expect(
        strays,
        isEmpty,
        reason:
            'a push — succeeded or refused — must not leave an identity, a '
            'known_hosts or a wrapper on disk',
      );
    });
  });
}

const _productId = 'p-1';
const _itemId = 'WI-push-1';
final _head = 'b' * 40;

WorkItem _item() => WorkItem(
  workItemId: _itemId,
  productId: _productId,
  category: WorkItemCategory.feature,
  title: 'A deployable work item',
  description: 'Parked for the deploy gate.',
  state: WorkItemState.waitingForHumanDecision,
  createdAt: DateTime.utc(2026, 10, 21),
  updatedAt: DateTime.utc(2026, 10, 21),
  version: 1,
);

/// One product + repository + credential's worth of registry state, over
/// the REAL `ProductRegistryEngine` — the same provenance writes the
/// credential endpoint performs, so `readActiveCredential` returns exactly
/// what production would see.
class _ResolutionFixture {
  static const repositoryUri = 'ssh://git@remote.test:22/org/repo.git';
  static const ownFingerprint = 'SHA256:ownkeyfingerprintvaluefortest00000';
  static const hostKeyFingerprint =
      'SHA256:hostkeyfingerprintconfirmedbyhuman00';

  final InMemoryProductRegistryStore store = InMemoryProductRegistryStore();
  final _MapSecretProvider provider = _MapSecretProvider();
  final _FakeTransport transport = _FakeTransport();
  late final ProductRegistryEngine engine = ProductRegistryEngine(
    store: store,
    humanDecisionStore: InMemoryHumanDecisionStore(),
  );
  late final RegistryDeployPusher pusher = RegistryDeployPusher(
    engine: engine,
    secretProvider: provider,
    transport: transport,
  );

  /// The SecretBytes the provider hands out — kept so the test can assert
  /// the caller wiped it.
  late final SecretBytes secret = SecretBytes(
    List<int>.generate(48, (i) => i + 7),
  );

  Future<void> seedProduct({
    bool withCredential = true,
    bool hostConfirmed = true,
    bool verified = true,
    String? hostKeyFingerprint,
  }) async {
    await engine.createProduct(productId: _productId, name: 'Product One');
    await engine.addRepositoryReference(
      repositoryId: 'repo-1',
      productId: _productId,
      uri: repositoryUri,
    );
    if (!withCredential) return;
    await engine.recordGeneratedCredential(
      productId: _productId,
      repositoryId: 'repo-1',
      referenceName: 'GIT_REPOSITORY_repo-1_SSH',
      publicKey: 'ssh-ed25519 AAAAtestkey shipit+repo-1',
      fingerprint: ownFingerprint,
      host: repositoryUri,
      credentialId: 'cred-1',
    );
    if (hostConfirmed) {
      await engine.confirmHostKey(
        productId: _productId,
        credentialId: 'cred-1',
        hostKeyFingerprint:
            hostKeyFingerprint ?? _ResolutionFixture.hostKeyFingerprint,
        confirmedBy: 'dana',
      );
    }
    if (verified) {
      await engine.recordCredentialCheck(
        productId: _productId,
        credentialId: 'cred-1',
        succeeded: true,
        checkedBy: 'test',
      );
    }
    provider.secrets['GIT_REPOSITORY_repo-1_SSH'] = secret;
  }
}

/// What the fake transport recorded.
typedef _TransportCall = ({
  String productId,
  String repositoryId,
  String repositoryPath,
  String branch,
  String localHead,
  SshRemote remote,
  String confirmedHostKeyFingerprint,
});

class _FakeTransport implements DeployPushTransport {
  final List<_TransportCall> calls = [];
  Object? failure;

  @override
  Future<DeployPush> pushBranchToRemote({
    required String productId,
    required String repositoryId,
    required String repositoryPath,
    required String branch,
    required String localHead,
    required SshRemote remote,
    required SecretBytes privateKeyPem,
    required String confirmedHostKeyFingerprint,
  }) async {
    calls.add((
      productId: productId,
      repositoryId: repositoryId,
      repositoryPath: repositoryPath,
      branch: branch,
      localHead: localHead,
      remote: remote,
      confirmedHostKeyFingerprint: confirmedHostKeyFingerprint,
    ));
    final toThrow = failure;
    if (toThrow != null) throw toThrow;
    return DeployPush(
      state: DeployPushState.pushed,
      remoteUrl: remote.toSshUrl(),
      branch: branch,
      remoteHead: localHead,
    );
  }
}

/// A `SecretProvider` backed by a map — the reference names a read asked
/// for are recorded, and reads can be made to fail.
class _MapSecretProvider implements SecretProvider {
  final Map<String, SecretBytes> secrets = {};
  final List<String> reads = [];
  Object? readFailure;

  @override
  String get providerId => kLocalFileProviderId;

  @override
  bool get isDocumentedFallback => true;

  @override
  Map<String, String> describe() => const {'adapter': 'map'};

  @override
  Future<String> store({
    required String referenceName,
    required SecretBytes secret,
  }) async => referenceName;

  @override
  Future<SecretBytes> read({required String referenceName}) async {
    reads.add(referenceName);
    final failure = readFailure;
    if (failure != null) throw failure;
    final material = secrets[referenceName];
    if (material == null) {
      throw SecretStoreException(
        referenceName: referenceName,
        providerId: providerId,
        operation: 'read',
        reason: 'no such reference',
      );
    }
    return material;
  }

  @override
  Future<void> destroy({required String referenceName}) async {}
}

Future<String> _git(String dir, List<String> args) async {
  final result = await Process.run(
    'git',
    ['-C', dir, ...args],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    throw StateError(
      'git ${args.join(' ')} in $dir exited ${result.exitCode}: '
      '${result.stderr}',
    );
  }
  return (result.stdout as String).trim();
}

Future<int> _exit(String dir, List<String> args) async {
  final result = await Process.run(
    'git',
    ['-C', dir, ...args],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  return result.exitCode;
}

/// A scratch checkout whose `origin` is [url] — real `git remote`, never
/// contacted for `get-url`.
Future<Directory> _repoWithOrigin(String url) async {
  final dir = await Directory.systemTemp.createTemp('deploy_push_repo_');
  await _git(dir.path, ['init', '-b', 'main']);
  await _git(dir.path, ['remote', 'add', 'origin', url]);
  return dir;
}

/// A real commit on [branch] in [dir]; returns its revision. `-B` because a
/// clone of an EMPTY remote has no branch ref yet — `checkout main` fails
/// with `pathspec did not match` on the unborn branch.
Future<String> _commitOn(String dir, String branch, String content) async {
  await _git(dir, ['checkout', '-B', branch]);
  final name = 'f-${content.hashCode.abs()}.txt';
  await File('$dir/$name').writeAsString('$content\n');
  await _git(dir, ['add', name]);
  await _git(dir, [
    '-c',
    'user.name=test',
    '-c',
    'user.email=test@test',
    'commit',
    '-m',
    content,
  ]);
  return _git(dir, ['rev-parse', 'HEAD']);
}

/// Writes an executable shell stub into [bin].
void _writeStub(Directory bin, String name, String body) {
  final file = File('${bin.path}/$name');
  file.writeAsStringSync(body);
  Process.runSync('chmod', ['755', file.path]);
}

/// Generates a genuine host key and returns its authorized-keys line and
/// SHA-256 fingerprint — real, because the transport compares against what
/// real `ssh-keygen -lf -` produces.
(String, String) _realHostKey(Directory dir) {
  final path = '${dir.path}/hostkey';
  final result = Process.runSync('ssh-keygen', [
    '-q',
    '-t',
    'ed25519',
    '-N',
    '',
    '-C',
    'deploy-push-test-host',
    '-f',
    path,
  ]);
  if (result.exitCode != 0) {
    throw StateError('could not create a host key fixture: ${result.stderr}');
  }
  final line = File('$path.pub').readAsStringSync().trim();
  final fingerprint = Process.runSync('ssh-keygen', ['-lf', '$path.pub']);
  final match = RegExp(
    r'SHA256:[A-Za-z0-9+/]+=*',
  ).firstMatch(fingerprint.stdout as String);
  return (line, match!.group(0)!);
}
