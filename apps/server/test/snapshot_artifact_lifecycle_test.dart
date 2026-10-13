import 'dart:convert';
import 'dart:io';

import 'package:control_plane_server/src/baseline/baseline_test_fixtures.dart';
import 'package:control_plane_server/src/credentials/credential_key_service.dart';
import 'package:control_plane_server/src/credentials/repository_snapshot_acquirer.dart';
import 'package:control_plane_server/src/credentials/secret_material.dart';
import 'package:control_plane_server/src/credentials/ssh_keypair.dart';
import 'package:control_plane_server/src/credentials/ssh_remote.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';

/// THE DEFECT THIS FILE EXISTS FOR.
///
/// `ArtifactCommitter` commits the agent's produced change INTO the directory a
/// `RepositorySnapshot` handed out — `GitWorktreeWorkspaceManager.prepare` forks
/// a linked worktree out of `repositoryPath`, and it is that object store, inside
/// the snapshot tree, which then receives the `shipit/impl/<workItemId>` branch
/// and the produced commit. `LocalWorker` records the commit as the execution's
/// `endingRevision`, and `engineeringReviewWorkloadResolver` resolves a review
/// workload as exactly `producer.repositoryPath` + `producer.endingRevision`.
///
/// `RepositorySnapshot.release()` used to delete that whole tree. So a
/// per-execution snapshot destroyed the review target at the moment the
/// execution finished: the reviewer could not check out the revision it was told
/// to review, and the review failed closed — or, worse, a later `git` in the same
/// repository resolved something that was never reviewed.
///
/// ## Why this file drives the real components
///
/// No fake is substituted for the part that made the defect. The real
/// [SshPinnedSnapshotMaterializer] clones, the real [GitWorktreeWorkspaceManager]
/// prepares and cleans up, and the real [ArtifactCommitter] commits. A test that
/// simulated the commit would have been asserting against its own idea of what
/// the committer does.
///
/// The transport is stubbed and only the transport: `ssh-keyscan` is a stub
/// (there is no ssh host to scan), and `git` is a stub that DELEGATES every
/// subcommand to the real git binary against a local origin over `file://` — so
/// the clone, the fetch, the detached checkout, the object store, the refs and
/// the commit are all genuinely git's. The one substitution is `remote add`,
/// where the ssh URL is replaced by the local origin, because there is no server
/// to reach. Nothing else about the sequence is simulated.
const String _scratchPrefix = 'snapshot_artifact_lifecycle_test_';

void main() {
  late Directory harness;
  late Directory bin;
  late Directory origin;
  late Directory workspaceRoot;
  late String originRevision;
  late String realGit;
  late String hostKeyLine;
  late String hostKeyFingerprint;
  late SshKeyPair keypair;

  /// Every scratch tree this test created and has not yet accounted for.
  late Set<String> scratchBefore;

  SshRemote remote() => SshRemote(
    user: 'git',
    host: '127.0.0.1',
    port: 2222,
    repositoryPath: 'acme/x.git',
  );

  setUp(() async {
    scratchBefore = _scratchTrees();
    // Deliberately NOT sharing the scratch prefix: the leak check below must
    // see snapshot trees this test created and nothing the harness owns.
    harness = Directory.systemTemp.createTempSync('snaplife_harness_');
    bin = Directory('${harness.path}/bin')..createSync(recursive: true);
    origin = Directory('${harness.path}/origin')..createSync(recursive: true);
    workspaceRoot = Directory('${harness.path}/workspaces')..createSync();
    keypair = SshKeyPair.generate(comment: 'shipit+lifecycle');
    (hostKeyLine, hostKeyFingerprint) = _realHostKey(harness);
    realGit = _which('git');

    _git(origin.path, ['init', '--quiet', '-b', 'main']);
    // Fetching a pinned sha by name needs the origin to serve it. Local-only
    // fixture configuration, never touched outside this temp directory.
    _git(origin.path, ['config', 'uploadpack.allowAnySHA1InWant', 'true']);
    _git(origin.path, ['commit', '--quiet', '--allow-empty', '-m', 'base']);
    originRevision = _git(origin.path, ['rev-parse', 'HEAD']).stdout.trim();

    _writeStub(bin, 'ssh-keyscan', '#!/bin/sh\necho "$hostKeyLine"\n');
    _writeStub(
      bin,
      'git',
      _delegatingGitStub(realGit: realGit, origin: origin.path),
    );
    Process.runSync('chmod', [
      '755',
      '${bin.path}/ssh-keyscan',
      '${bin.path}/git',
    ]);
  });

  tearDown(() {
    // A retained artifact tree is the ONE thing this test expects to survive a
    // release, so it is removed here explicitly and then asserted gone — this
    // teardown is the reclaimer standing in for the component that owns it in
    // production, and it must not paper over one that survived unexpectedly.
    for (final tree in _scratchTrees().difference(scratchBefore)) {
      final directory = Directory(tree);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    }
    if (harness.existsSync()) harness.deleteSync(recursive: true);
    expect(
      _scratchTrees().difference(scratchBefore),
      isEmpty,
      reason: 'this test left snapshot trees behind',
    );
  });

  SshPinnedSnapshotMaterializer materializer() => SshPinnedSnapshotMaterializer(
    pathPrefix: bin.path,
    scratchPrefix: _scratchPrefix,
  );

  /// A second real commit on the origin, for the drift case below.
  String secondOriginRevision() {
    _git(origin.path, ['commit', '--quiet', '--allow-empty', '-m', 'moved']);
    return _git(origin.path, ['rev-parse', 'HEAD']).stdout.trim();
  }

  Future<RepositorySnapshot> acquire({
    String productId = 'product-a',
    String repositoryId = 'repo',
    String? pinnedRevision,
  }) => materializer().materialize(
    productId: productId,
    repositoryId: repositoryId,
    remote: remote(),
    privateKeyPem: SecretBytes(keypair.privateKeyPemBytes),
    confirmedHostKeyFingerprint: hostKeyFingerprint,
    pinnedRevision: pinnedRevision ?? originRevision,
  );

  group('release must not destroy a tree an artifact was committed into', () {
    test(
      'the artifact survives release, by the ref the committer created',
      () async {
        // THE REGRESSION, driven through the real chain: acquire a snapshot,
        // fork a worktree out of it, let the real committer commit into that
        // worktree, clean the worktree up, then release the snapshot.
        final snapshot = await acquire();
        final repositoryPath = snapshot.root.path;

        final workspace = GitWorktreeWorkspaceManager(
          workspaceRoot: workspaceRoot.path,
        );
        final descriptor = await workspace.prepare(
          WorkerExecutionRequest(
            workerExecutionId: 'wx-1',
            workItemId: 'WI-1',
            repositoryPath: repositoryPath,
            startingRevision: originRevision,
            requiredCapabilities: const {},
            role: AgentRole.implementer,
            instruction: 'produce something',
            timeoutSeconds: 60,
            runtimeTypeId: 'opencode',
          ),
        );

        // The agent's produced change, in the worktree the manager forked from
        // the snapshot tree.
        File('${descriptor.worktreePath}/shipped.txt').writeAsStringSync('x\n');

        // The REAL committer, not a simulation of it.
        final committed = await const ArtifactCommitter().commit(
          worktreePath: descriptor.worktreePath,
          workItemId: 'WI-1',
          startingRevision: originRevision,
          message: 'shipit artifact: WI-1',
        );
        expect(
          committed.revision,
          isNotNull,
          reason: 'the artifact commit is the point',
        );
        final artifactRevision = committed.revision!;
        expect(artifactRevision, isNot(originRevision));

        await workspace.cleanup(descriptor);

        // ---- The release that used to destroy the review target. ----
        final disposition = snapshot.release();

        expect(
          disposition,
          SnapshotReleaseDisposition.treeRetainedForArtifact,
          reason:
              'the committer put its commit in THIS tree and deleted nothing; '
              'deleting the tree here deletes the revision the engineering '
              'review workload resolves as repositoryPath + endingRevision',
        );
        expect(
          Directory(repositoryPath).existsSync(),
          isTrue,
          reason:
              'the repository the reviewer forks a worktree from must exist',
        );

        // Reachable by the exact ref `ArtifactCommitter` created.
        expect(
          _git(repositoryPath, [
            'rev-parse',
            '--verify',
            'shipit/impl/WI-1^{commit}',
          ]).stdout.trim(),
          artifactRevision,
          reason:
              'engineeringReviewWorkloadResolver resolves a review target by '
              'revision, and the review must be able to check that revision out',
        );

        // And checkable out, which is what `GitWorktreeWorkspaceManager.prepare`
        // does with `repositoryPath` + `endingRevision`.
        final reviewerWorkspace = Directory(
          '${harness.path}/reviewer-workspaces',
        )..createSync();
        final reviewManager = GitWorktreeWorkspaceManager(
          workspaceRoot: reviewerWorkspace.path,
        );
        final reviewDescriptor = await reviewManager.prepare(
          WorkerExecutionRequest(
            workerExecutionId: 'wx-2',
            workItemId: 'WI-1',
            repositoryPath: repositoryPath,
            startingRevision: artifactRevision,
            requiredCapabilities: const {},
            role: AgentRole.engineeringReviewer,
            instruction: 'review it',
            timeoutSeconds: 60,
            runtimeTypeId: 'opencode',
          ),
        );
        expect(
          File('${reviewDescriptor.worktreePath}/shipped.txt').existsSync(),
          isTrue,
          reason:
              'the reviewer forked a worktree at the produced revision and the '
              "agent's change is in it — that is the artifact, still inspectable",
        );
        await reviewManager.cleanup(reviewDescriptor);
      },
    );

    test(
      'the credential material is destroyed even when the tree is kept',
      () async {
        // The other half of release, and the half that must NOT become
        // conditional. A deploy key's private half exists for the duration of the
        // clone; an artifact is never a reason to keep one on disk.
        final snapshot = await acquire();
        final checkout = snapshot.root.path;
        final scratch = Directory(checkout).parent;

        _git(checkout, ['checkout', '--quiet', '-B', 'shipit/impl/WI-2']);
        File('$checkout/shipped.txt').writeAsStringSync('x\n');
        _git(checkout, ['add', '-A']);
        _git(
          checkout,
          [
            '-c',
            'user.name=p',
            '-c',
            'user.email=p@p',
            'commit',
            '--quiet',
            '-m',
            'artifact',
          ],
        );

        expect(
          snapshot.release(),
          SnapshotReleaseDisposition.treeRetainedForArtifact,
        );

        for (final name in const [
          'identity',
          'known_hosts',
          'ssh-wrapper.sh',
        ]) {
          expect(
            File('${scratch.path}/$name').existsSync(),
            isFalse,
            reason: '$name must not survive release, retained tree or not',
          );
        }
        expect(Directory(checkout).existsSync(), isTrue);

        // And the marker, because a retained tree that looks exactly like an
        // abandoned scratch tree is how this defect comes back.
        final marker = File('${scratch.path}/$retainedArtifactMarkerName');
        expect(
          marker.existsSync(),
          isTrue,
          reason: 'retention must not be silent',
        );
        final body =
            jsonDecode(marker.readAsStringSync()) as Map<String, dynamic>;
        expect(body['repositoryPath'], checkout);
        expect(body['artifactRefs'], ['refs/heads/shipit/impl/WI-2']);
        expect(body['pinnedRevision'], originRevision);
        expect(marker.readAsStringSync(), isNot(contains('PRIVATE KEY')));
        expect(marker.readAsStringSync(), isNot(contains(hostKeyFingerprint)));
        expect(
          marker.readAsStringSync(),
          isNot(contains(keypair.fingerprint)),
          reason:
              "the deploy key's own public-key fingerprint must not be written "
              'to a file an operator can read',
        );
      },
    );

    test(
      'release is one-shot and reports the same disposition twice',
      () async {
        final snapshot = await acquire();
        final checkout = snapshot.root.path;
        _git(checkout, ['checkout', '--quiet', '-B', 'shipit/impl/WI-3']);
        _git(
          checkout,
          [
            '-c',
            'user.name=p',
            '-c',
            'user.email=p@p',
            'commit',
            '--quiet',
            '--allow-empty',
            '-m',
            'artifact',
          ],
        );

        expect(
          snapshot.release(),
          SnapshotReleaseDisposition.treeRetainedForArtifact,
        );
        expect(
          snapshot.release(),
          SnapshotReleaseDisposition.treeRetainedForArtifact,
        );
        expect(Directory(checkout).existsSync(), isTrue);
        expect(
          () => snapshot.root,
          throwsA(isA<StateError>()),
          reason: 'a retained tree is no longer this object\'s to hand out',
        );
      },
    );
  });

  group('release still removes a snapshot nobody committed into', () {
    test('an unused snapshot leaves nothing behind', () async {
      final snapshot = await acquire();
      final scratch = Directory(snapshot.root.path).parent;
      expect(scratch.existsSync(), isTrue);

      expect(snapshot.release(), SnapshotReleaseDisposition.treeDestroyed);
      expect(
        scratch.existsSync(),
        isFalse,
        reason:
            'a snapshot that was only read must be removed; retaining every tree '
            'would be an unbounded leak, not a fix',
      );
    });

    test(
      'the materializer removes its tree when the pinned revision is not what it got',
      () async {
        // The materializer's own refusal path: it cloned, the revision is not
        // the pin, nothing was handed to a caller, so nothing is kept.
        _writeStub(
          bin,
          'git',
          _delegatingGitStub(
            realGit: realGit,
            origin: origin.path,
            // A second, real commit, so git lands the tree at a revision that is
            // genuinely not the pin.
            fetchTargetOverride: secondOriginRevision(),
          ),
        );
        Process.runSync('chmod', ['755', '${bin.path}/git']);

        await expectLater(
          acquire(pinnedRevision: 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'),
          throwsA(isA<PinnedRevisionNotAcquiredException>()),
        );
        expect(
          _scratchTrees().difference(scratchBefore),
          isEmpty,
          reason: 'a failed acquisition has no consumer and must clean up',
        );
      },
    );

    test(
      'the acquirer releases before it throws on a revision mismatch',
      () async {
        // `RepositorySnapshotAcquirer.acquire` re-reads the revision and, on a
        // mismatch, releases before raising `PinnedRevisionNotAcquiredException`.
        // That cleanup is the one the acquirer's callers depend on, and it must
        // survive this change — a snapshot that was refused must not linger.
        final registry = RegistryFixture();
        await registry.registerProduct(productId: 'product-a');
        await seedCredential(
          registry.engine,
          productId: 'product-a',
          repositoryId: 'repo',
        );

        final keyService = CredentialKeyService(
          engine: registry.engine,
          secretProvider: RecordingSecretProvider(),
          verifier: ScriptedAccessVerifier(committedRevision: kTestRevision),
          clock: () => DateTime.utc(2026, 2, 1),
        );
        final created = <Directory>[];
        final acquirer = RepositorySnapshotAcquirer(
          engine: registry.engine,
          credentialKeyService: keyService,
          materializer: _ObservedRevisionMaterializer(created),
        );

        await expectLater(
          acquirer.acquire(
            productId: 'product-a',
            repositoryId: 'repo',
            pinnedRevision: 'ffffffffffffffffffffffffffffffffffffffff',
          ),
          throwsA(isA<PinnedRevisionNotAcquiredException>()),
        );
        expect(
          created,
          hasLength(1),
          reason: 'a snapshot was created, so it must be released',
        );
        expect(
          created.single.existsSync(),
          isFalse,
          reason:
              'the acquirer releases before throwing; a refused snapshot that '
              'lingers is the leak the exception path exists to prevent',
        );
      },
    );
  });
}

/// A materializer that clones for real, then reports a revision the acquirer
/// did not ask for — the only way to reach the acquirer's own equality check
/// rather than the materializer's.
class _ObservedRevisionMaterializer implements RepositorySnapshotMaterializer {
  _ObservedRevisionMaterializer(this.created);

  /// Every tree handed out, so a test can ask whether one was released.
  final List<Directory> created;

  @override
  Future<RepositorySnapshot> materialize({
    required String productId,
    required String repositoryId,
    required SshRemote remote,
    required SecretBytes privateKeyPem,
    required String confirmedHostKeyFingerprint,
    required String pinnedRevision,
  }) async {
    final root = Directory.systemTemp.createTempSync(_scratchPrefix);
    created.add(root);
    return RepositorySnapshot(
      productId: productId,
      repositoryId: repositoryId,
      revision: kTestRevision,
      sourceRef: remote.toSshUrl(),
      acquiredAt: DateTime.utc(2026, 1, 1),
      root: root,
      onRelease: () {
        if (root.existsSync()) root.deleteSync(recursive: true);
      },
    );
  }
}

/// A stub `git` that delegates to the real binary, substituting only the
/// remote URL.
///
/// The delegation is the point. `git init`, `fetch --depth 1`, a detached
/// `checkout`, the object store, the refs and `rev-parse` are git's own — so
/// "does this tree carry a local head" is answered by git about a real clone,
/// not by a stub reporting what the test wanted to be true.
String _delegatingGitStub({
  required String realGit,
  required String origin,
  String? fetchTargetOverride,
}) {
  final override = fetchTargetOverride == null
      ? ''
      : '''
if [ "\$1" = "fetch" ]; then
  # The caller asked for a pin this origin does not have. Fetch a real commit
  # that is not the pin instead, so git lands the tree at the WRONG revision and
  # the mismatch is produced by git rather than asserted by the test.
  shift; shift; shift; shift; shift; shift
  exec "$realGit" -C "\$dir" fetch --depth 1 --no-tags --quiet origin "$fetchTargetOverride"
fi
''';
  return '''
#!/bin/sh
# Test stub. Delegates to the real git binary against a local `file://` origin.
# The ONLY substitution is `remote add`, where the ssh URL becomes that origin:
# there is no ssh host to reach, and everything downstream of it is genuine.
dir=
while [ \$# -gt 0 ]; do
  if [ "\$1" = "-C" ]; then shift; dir="\$1"; shift; continue; fi
  case "\$1" in -*) shift; continue ;; *) break ;; esac
done
$override
if [ "\$1" = "remote" ]; then
  exec "$realGit" -C "\$dir" remote add origin "file://$origin"
fi
exec "$realGit" -C "\$dir" "\$@"
''';
}

void _writeStub(Directory bin, String name, String body) {
  File('${bin.path}/$name').writeAsStringSync(body);
}

String _which(String executable) {
  final result = Process.runSync('which', [executable]);
  final path = (result.stdout as String).trim();
  if (result.exitCode != 0 || path.isEmpty) {
    throw StateError('$executable is not on PATH; this test needs real git');
  }
  return path;
}

ProcessResult _git(String directory, List<String> arguments) {
  final result = Process.runSync(
    _which('git'),
    ['-C', directory, ...arguments],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    throw StateError('git ${arguments.join(' ')} failed: ${result.stderr}');
  }
  return result;
}

/// A genuine OpenSSH host key, because `_matchConfirmedHostKeys` compares
/// against what real `ssh-keygen -lf -` computes.
(String, String) _realHostKey(Directory dir) {
  final path = '${dir.path}/hostkey';
  final result = Process.runSync('ssh-keygen', [
    '-q',
    '-t',
    'ed25519',
    '-N',
    '',
    '-C',
    'shipit-lifecycle-test-host',
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

/// Every snapshot-tree path currently in the system temp directory.
Set<String> _scratchTrees() => Directory.systemTemp
    .listSync()
    .whereType<Directory>()
    .where((d) => d.path.contains(_scratchPrefix))
    .map((d) => d.path)
    .toSet();
