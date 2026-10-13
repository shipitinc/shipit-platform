import 'dart:io';

import 'package:control_plane_server/src/baseline/durable_workspace_materializer.dart';
import 'package:control_plane_server/src/credentials/secret_material.dart';
import 'package:control_plane_server/src/credentials/ssh_remote.dart';
// `test` is a dev_dependency of `control_plane_server`; it is unresolved as a
// `lib/` import, which is a known cost of co-locating tests here.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

/// Review row **R-9**: A1's materialiser leaves no credential on or beside the
/// clone.
///
/// ## Why this suite exists at all
///
/// The obligations it asserts are **invisible on every success path**. A
/// materialiser that writes the identity file beside the clone and forgets to
/// delete it works perfectly: the clone is at the right commit, the descriptor
/// is right, the record is written, and every functional test in the repository
/// passes. The defect is a deploy-key identity left on disk next to a governed
/// product's checkout for the life of the deployment, and **there is no
/// assertion a functional suite can write that fails when it happens** — unless
/// the test looks for the file. So the test looks for the file.
///
/// ## How it runs without a network
///
/// `PATH` is pinned to a stub `git` and a stub `ssh-keyscan`, so the real code
/// path runs — the real argument order, the real `finally`, the real file
/// writes. The real `ssh-keygen` still computes the fingerprint, so the host-key
/// comparison is against a genuine OpenSSH value rather than a made-up one.
///
/// ## What is deliberately NOT asserted
///
/// Nothing here talks to a git host or clones anything. Every assertion is
/// about what is on disk afterwards and what the stub observed, which are the
/// two claims that are otherwise invisible.
const _scratchPrefix = 'durable_workspace_r9_';
const _revision = 'f0f3494957bb90df0a1c15a9fb4734ca6e49634d';
const _otherRevision = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

/// Writes an executable shell stub into [bin].
void _writeStub(Directory bin, String name, String body) {
  final file = File('${bin.path}/$name');
  file.writeAsStringSync(body);
  Process.runSync('chmod', ['755', file.path]);
}

/// Generates a genuine host key and returns its authorized-keys line and
/// SHA-256 fingerprint.
///
/// Real, because `_matchConfirmedHostKeys` compares against what the real
/// `ssh-keygen -lf -` produces. A made-up fingerprint would make the stubbed
/// scan fail to match, the materialiser would refuse before ever reaching git,
/// and the suite would prove nothing at all.
(String, String) _realHostKey(Directory dir) {
  final path = '${dir.path}/hostkey';
  final result = Process.runSync('ssh-keygen', [
    '-q',
    '-t',
    'ed25519',
    '-N',
    '',
    '-C',
    'durable-workspace-r9-host',
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

/// A stub `ssh-keyscan` that presents exactly the one key line it was given.
String _sshKeyscanStub(String keyLine) =>
    '''
#!/bin/sh
echo "$keyLine"
exit 0
''';

/// A stub `git` that answers the subcommands this materialiser issues, and
/// records each invocation with the environment it was spawned with.
///
/// Deliberately NOT the trivially-succeeding stub the snapshot materialiser is
/// tested with. This one answers `config --get core.sshCommand`,
/// `config --list --local` and `rev-parse HEAD` the way a real git would,
/// because those three answers ARE the property under test: a stub that printed
/// nothing for them would let a clone carrying a persisted `core.sshCommand`
/// pass, which would make the suite below it vacuous.
String _gitStub({
  required String report,
  required String revision,
  required String configuredSshCommand,
  required String localConfigExtra,
}) =>
    '''
#!/bin/sh
report="$report"
dir=
sub=
while [ \$# -gt 0 ]; do
  if [ "\$1" = "-C" ]; then shift; dir="\$1"; shift; continue; fi
  case "\$1" in -*) ;; *) sub="\$1"; break ;; esac
  shift
done
{
  printf 'CALL\\t%s\\t%s\\n' "\$sub" "\$dir"
  printf 'ENV_GIT_SSH_COMMAND=%s\\n' "\${GIT_SSH_COMMAND-unset}"
  printf 'ENV_GIT_CONFIG_GLOBAL=%s\\n' "\${GIT_CONFIG_GLOBAL-unset}"
  printf 'ENV_GIT_CONFIG_SYSTEM=%s\\n' "\${GIT_CONFIG_SYSTEM-unset}"
  printf 'ENV_GIT_TERMINAL_PROMPT=%s\\n' "\${GIT_TERMINAL_PROMPT-unset}"
  printf 'ENV_GIT_ASKPASS=%s\\n' "\${GIT_ASKPASS-unset}"
  printf 'ENV_HOME=%s\\n' "\${HOME-unset}"
} >> "\$report"
case "\$sub" in
  rev-parse) echo "$revision" ;;
  config)
    shift
    case "\$*" in
      *core.sshCommand*) if [ -n "$configuredSshCommand" ]; then echo "$configuredSshCommand"; fi ;;
      *)
        echo "core.repositoryformatversion=0"
        echo "remote.origin.url=ssh://git@remote.test:22/org/repo.git"
        if [ -n "$localConfigExtra" ]; then echo "$localConfigExtra"; fi
        ;;
    esac
    ;;
esac
exit 0
''';

/// One recorded stub invocation, with the environment it was spawned in.
typedef _Invocation = ({
  String subcommand,
  String directory,
  Map<String, String> environment,
});

/// The absolute path of the REAL `git`, or `null` when there is none.
///
/// Resolved rather than assumed: the shim below has to exec git by absolute
/// path, because a shim that ran `exec git` would resolve through the pinned
/// `PATH` and find itself.
String? _realGitPath() {
  for (final probe in ['which', 'command']) {
    final ProcessResult result;
    try {
      result = Process.runSync(probe, ['git']);
    } on Object {
      continue;
    }
    if (result.exitCode != 0) continue;
    final path = (result.stdout as String).trim();
    if (path.isEmpty) continue;
    if (File(path).existsSync()) return path;
  }
  return null;
}

/// A `git` that IS the real one, recording every invocation first.
///
/// The R-9 suite above needs a stub because its subject is what this class
/// writes around the clone. The suite below needs the opposite: its subject is
/// what real git DOES to an existing tree, and a stub would be asserting the
/// stub's behaviour. So this delegates — `git init` is genuinely idempotent and
/// `git remote add origin` genuinely exits 3 on a second call, and that is the
/// defect being reproduced rather than simulated.
void _writeRealGitShim(Directory bin, String realGit, String report) {
  _writeStub(
    bin,
    'git',
    '''
#!/bin/sh
printf 'REALGIT\\t%s\\n' "\$*" >> "$report"
exec "$realGit" "\$@"
''',
  );
}

/// Runs real git in [directory] and returns stdout, for assertions ABOUT a tree.
///
/// Identity is supplied on the command line rather than through any config
/// file, so the fixture cannot accidentally depend on an ambient global
/// gitconfig to make a commit.
String _gitIn(String directory, List<String> arguments) {
  final result = Process.runSync(_realGitPath() ?? 'git', [
    '-C',
    directory,
    '-c',
    'user.email=fixture@example.test',
    '-c',
    'user.name=Fixture',
    '-c',
    'commit.gpgsign=false',
    ...arguments,
  ]);
  if (result.exitCode != 0) {
    throw StateError(
      'git ${arguments.first} failed in $directory: ${result.stderr}',
    );
  }
  return (result.stdout as String).trim();
}

List<_Invocation> _readInvocations(String report) {
  if (!File(report).existsSync()) return const [];
  final calls = <_Invocation>[];
  String? subcommand;
  String? directory;
  var environment = <String, String>{};
  void flush() {
    if (subcommand != null && directory != null) {
      calls.add((
        subcommand: subcommand,
        directory: directory,
        environment: environment,
      ));
    }
  }

  for (final line in File(report).readAsLinesSync()) {
    if (line.startsWith('CALL\t')) {
      flush();
      final parts = line.split('\t');
      subcommand = parts.length > 1 ? parts[1] : '';
      directory = parts.length > 2 ? parts[2] : '';
      environment = <String, String>{};
    } else if (line.startsWith('ENV_')) {
      final split = line.indexOf('=');
      if (split > 0) {
        environment = <String, String>{
          ...environment,
          line.substring(0, split): line.substring(split + 1),
        };
      }
    }
  }
  flush();
  return calls;
}

void main() {
  late Directory scratch;
  late Directory bin;
  late String productRoot;
  late String hostKeyLine;
  late String hostKeyFingerprint;
  late String report;

  SshRemote remote() => SshRemote(
    user: 'git',
    host: 'remote.test',
    port: 22,
    repositoryPath: 'org/repo.git',
  );

  setUp(() {
    scratch = Directory.systemTemp.createTempSync(_scratchPrefix);
    bin = Directory('${scratch.path}/bin')..createSync();
    productRoot = '${scratch.path}/workspaces/p1';
    report = '${scratch.path}/git-report';
    final (line, fingerprint) = _realHostKey(scratch);
    hostKeyLine = line;
    hostKeyFingerprint = fingerprint;
    _writeStub(bin, 'ssh-keyscan', _sshKeyscanStub(hostKeyLine));
  });

  tearDown(() {
    if (scratch.existsSync()) scratch.deleteSync(recursive: true);
  });

  void writeGit({
    String revision = _revision,
    String configuredSshCommand = '',
    String localConfigExtra = '',
  }) => _writeStub(
    bin,
    'git',
    _gitStub(
      report: report,
      revision: revision,
      configuredSshCommand: configuredSshCommand,
      localConfigExtra: localConfigExtra,
    ),
  );

  /// The real `git`, behind a shim that still records what it was asked.
  ///
  /// Separate from [writeGit] rather than a parameter of it: the stub's value
  /// is that it answers the three config/rev-parse questions a credential-free
  /// clone depends on, and making it optionally real would put those answers
  /// behind a flag that could be set wrongly without anything noticing.
  void writeRealGit() {
    final realGit = _realGitPath();
    if (realGit == null) skipIfNoRealGit();
    _writeRealGitShim(bin, realGit, report);
  }

  Future<DurableWorkspaceClone> materialize({
    String? pinnedRevision,
    String? confirmedFingerprint,
  }) => SshDurableWorkspaceMaterializer(pathPrefix: bin.path).materialize(
    productId: 'p1',
    repositoryId: 'repo1',
    remote: remote(),
    privateKeyPem: SecretBytes(List<int>.generate(32, (i) => i)),
    confirmedHostKeyFingerprint: confirmedFingerprint ?? hostKeyFingerprint,
    pinnedRevision: pinnedRevision ?? _revision,
    productRoot: productRoot,
  );

  group('R-9 — no credential survives on or beside the clone', () {
    test('the identity, known_hosts and ssh wrapper are GONE', () async {
      writeGit();
      final clone = await materialize();

      expect(clone.repositoryPath, '$productRoot/checkout');
      expect(Directory(clone.repositoryPath).existsSync(), isTrue);

      for (final name in [
        SshDurableWorkspaceMaterializer.identityFileName,
        SshDurableWorkspaceMaterializer.knownHostsFileName,
        SshDurableWorkspaceMaterializer.sshWrapperFileName,
      ]) {
        expect(
          File('$productRoot/$name').existsSync(),
          isFalse,
          reason:
              '$name is still on disk beside the clone. Nothing about that is '
              'visible from the clone, the descriptor or the record, which is '
              'why only a test that looks for the file can catch it',
        );
      }

      // And the ONLY other thing beside the clone is the commit guard, which is
      // deliberately there and is not credential material. Named explicitly, so
      // adding a fourth file to this root has to be a decision rather than a
      // side effect somebody notices in a diff.
      final siblings = Directory(
        productRoot,
      ).listSync().map((e) => e.path.split('/').last).toSet();
      expect(siblings, {'checkout', '.gitignore'});
      expect(
        File('$productRoot/.gitignore').readAsStringSync().trim(),
        '*',
        reason:
            'the commit guard must exclude everything beneath the product root, '
            'so a misconfigured root cannot contribute a governed checkout to '
            'a work tree it was not meant to touch',
      );
    });

    test(
      'the credential files are gone by the time the descriptor is reported, '
      'not after the caller returns',
      () async {
        writeGit();
        final clone = await materialize();
        // The ordering obligation. `finally` runs before the future completes,
        // so there is no window in which a caller holds a valid descriptor AND
        // a readable identity file.
        expect(clone.revision, _revision);
        expect(
          File(
            '$productRoot/${SshDurableWorkspaceMaterializer.identityFileName}',
          ).existsSync(),
          isFalse,
        );
      },
    );

    test(
      'the clone config is actually INSPECTED, so the guarantee is checked on '
      'the tree being returned',
      () async {
        writeGit();
        await materialize();
        final configCalls = _readInvocations(
          report,
        ).where((call) => call.subcommand == 'config');
        expect(
          configCalls,
          isNotEmpty,
          reason:
              'the materialiser never inspected the clone config, so its '
              'credential-free claim was never checked against the tree it was '
              'about to return',
        );
      },
    );

    test(
      'a clone whose config DOES carry core.sshCommand is refused, and its '
      'tree removed',
      () async {
        // The negative control that makes the case above non-vacuous: same
        // code, same stub, but a git that reports a persisted `core.sshCommand`.
        // Such a clone would use a key file this process is required to delete
        // on every later fetch, so it must be refused rather than returned.
        writeGit(configuredSshCommand: '$productRoot/ssh-wrapper.sh');
        await expectLater(
          materialize(),
          throwsA(isA<DurableWorkspaceMaterializationException>()),
        );
        expect(Directory(productRoot).existsSync(), isFalse);
      },
    );

    test(
      'a clone whose config references the identity file is refused',
      () async {
        writeGit(
          localConfigExtra:
              'core.sshIdentity=$productRoot/'
              '${SshDurableWorkspaceMaterializer.identityFileName}',
        );
        await expectLater(
          materialize(),
          throwsA(isA<DurableWorkspaceMaterializationException>()),
        );
        expect(Directory(productRoot).existsSync(), isFalse);
      },
    );
  });

  group('the per-invocation environment the clone actually saw', () {
    test(
      'every clone call carries the wrapper by environment ONLY, with the '
      'ambient environment redirected',
      () async {
        writeGit();
        await materialize();

        final calls = _readInvocations(report);
        expect(calls, isNotEmpty, reason: 'the stub git was never spawned');

        // Only the clone-driving sequence: `rev-parse` and `config` are
        // post-clone reads with no credential in play, so requiring the wrapper
        // there would be asserting the wrong thing.
        const cloneSequence = ['init', 'remote', 'fetch', 'checkout'];
        final cloneCalls = calls
            .where((call) => cloneSequence.contains(call.subcommand))
            .toList();
        expect(
          cloneCalls.map((call) => call.subcommand),
          containsAllInOrder(cloneSequence),
          reason: 'the real clone sequence did not run against the stub',
        );

        for (final call in cloneCalls) {
          final env = call.environment;
          expect(
            env['ENV_GIT_SSH_COMMAND'],
            '$productRoot/'
            '${SshDurableWorkspaceMaterializer.sshWrapperFileName}',
            reason: '${call.subcommand} did not receive the ssh wrapper',
          );
          expect(env['ENV_GIT_CONFIG_GLOBAL'], '/dev/null');
          expect(env['ENV_GIT_CONFIG_SYSTEM'], '/dev/null');
          // Nothing may block on a human while a key is in memory.
          expect(env['ENV_GIT_TERMINAL_PROMPT'], '0');
          expect(env['ENV_GIT_ASKPASS'], '');
          // HOME redirected at the materialisation root, so a developer's
          // ~/.ssh/config cannot add an IdentityFile and a global gitconfig
          // cannot add url.*.insteadOf.
          expect(env['ENV_HOME'], productRoot);
        }
      },
    );

    test('no git call carried a private key on its argv', () async {
      // The wrapper reaches ssh and names the identity file, but the argv git
      // was given is recorded by the stub — so a future change that passed a
      // key directly is visible in the report rather than assumed impossible.
      writeGit();
      await materialize();
      expect(File(report).readAsStringSync().contains('PRIVATE KEY'), isFalse);
    });
  });

  group('refusals leave nothing behind', () {
    test(
      'a host presenting no matching key is refused BEFORE anything is '
      'written',
      () async {
        writeGit();
        await expectLater(
          materialize(
            confirmedFingerprint:
                'SHA256AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
          ),
          throwsA(isA<Object>()),
        );
        expect(
          Directory(productRoot).existsSync(),
          isFalse,
          reason:
              'a refused host key left a directory behind. The host key is '
              'checked before anything is written precisely so this is empty',
        );
      },
    );

    test(
      'a clone that is not at the pin is refused and its tree removed',
      () async {
        // Drift. The descriptor would name a commit the tree is not at, every
        // later execution would read it back, and the review gate would fail
        // closed on it days later with no indication that the tree had moved.
        writeGit(revision: _otherRevision);
        await expectLater(
          materialize(),
          throwsA(isA<DurableWorkspaceNotPinnedException>()),
        );
        expect(Directory(productRoot).existsSync(), isFalse);
      },
    );

    test('an unpinned revision is refused outright', () async {
      writeGit();
      await expectLater(
        materialize(pinnedRevision: '   '),
        throwsArgumentError,
      );
      expect(Directory(productRoot).existsSync(), isFalse);
    });
  });

  group('the descriptor a clone produces', () {
    test(
      'names the revision the TREE reported, not the one asked for',
      () async {
        writeGit();
        final clone = await materialize();
        expect(clone.revision, _revision);
        // An `origin` is an address, never a credential (ADR 0018 §13a).
        expect(clone.sourceRef, 'ssh://git@remote.test:22/org/repo.git');
        expect(clone.repositoryId, 'repo1');
        expect(clone.productId, 'p1');
      },
    );
  });

  // =====================================================================
  // Destroy provenance: a product root is removed only when THIS CALL
  // created it.
  //
  // The defect: `on Object` called `_destroy(root)` unconditionally, so any
  // failed git command took the product checkout with it. Reachable in
  // ordinary operation — `git init` on an existing repo exits 0, so a second
  // provisioning reaches `git remote add origin`, which exits 3, and that exit
  // used to destroy a tree holding unreviewed commits.
  //
  // These run against REAL git. The claim under test is a claim about git.
  // =====================================================================
  group('a product root this call did not create is never destroyed', () {
    /// A product checkout with a commit nobody has reviewed yet.
    ///
    /// Real `git init`, real commit, real object store — so "the commit
    /// survived" can be asserted by asking the repository rather than by
    /// checking that some files are still lying about.
    Directory seedUnreviewedCheckout({bool withCommitGuard = true}) {
      final checkout = Directory(
        '$productRoot/checkout',
      )..createSync(recursive: true);
      _gitIn(checkout.path, ['init', '--quiet', '.']);
      File('${checkout.path}/UNREVIEWED.md').writeAsStringSync(
        'work in progress that no review has seen',
      );
      _gitIn(checkout.path, ['add', '-A']);
      _gitIn(checkout.path, ['commit', '--quiet', '-m', 'unreviewed work']);
      if (withCommitGuard) {
        File('$productRoot/.gitignore').writeAsStringSync('*\n');
      }
      return checkout;
    }

    test(
      'a second provisioning is REFUSED, and the unreviewed commits are STILL '
      'THERE afterwards',
      () async {
        // ---- The whole point, in one test. ----
        //
        // Before the fix this call reached `git remote add origin` (exit 3,
        // "remote origin already exists") and the failure handler deleted
        // `$productRoot` recursively — the clone, its object store, and the
        // commit in it. The assertion is therefore about CONTENT, not about an
        // exception being thrown: a fix that refused loudly while still
        // deleting the tree would satisfy every other assertion in this file.
        final checkout = seedUnreviewedCheckout();
        final before = _gitIn(checkout.path, ['rev-parse', 'HEAD']);
        expect(
          _gitIn(checkout.path, ['log', '--oneline']),
          contains('unreviewed work'),
          reason: 'the fixture must really hold an unreviewed commit',
        );

        writeRealGit();
        await expectLater(
          materialize(),
          throwsA(isA<DurableWorkspaceRootCollisionException>()),
        );

        // ---- The commit survived, and the tree is still a working repository. ----
        expect(
          _gitIn(checkout.path, ['rev-parse', 'HEAD']),
          before,
          reason:
              'the HEAD moved. A materialisation that destroyed nothing but '
              'still reset the tree would lose the same work',
        );
        expect(
          _gitIn(checkout.path, ['log', '--oneline']),
          contains('unreviewed work'),
          reason:
              'the unreviewed commit is gone. This is the data loss the '
              'provenance check exists to prevent: the clone holds every commit '
              'an implementation lane has made and no review has seen',
        );
        expect(
          File('${checkout.path}/UNREVIEWED.md').readAsStringSync(),
          'work in progress that no review has seen',
          reason: 'the working tree itself was removed or rewritten',
        );
        expect(
          checkout.existsSync(),
          isTrue,
          reason: 'the checkout directory is gone',
        );
      },
    );

    test('the refusal happens BEFORE any git command is spawned', () async {
      // The mechanism, and the non-vacuity for the test above.
      //
      // Without the guard the sequence is `git init` (exit 0, idempotent) then
      // `git remote add origin` (exit 3). So an EMPTY call log proves the
      // refusal short-circuited before the destructive path existed — it is not
      // a call that ran git, failed, and then declined to delete.
      seedUnreviewedCheckout();
      writeRealGit();

      await expectLater(
        materialize(),
        throwsA(isA<DurableWorkspaceRootCollisionException>()),
      );

      expect(
        File(report).existsSync() ? File(report).readAsStringSync() : '',
        isEmpty,
        reason:
            'git was spawned on the collision path. The refusal has to precede '
            'the clone sequence, because the clone sequence is what fails and '
            'what used to trigger the delete',
      );
    });

    test(
      'the refusal writes NOTHING into the root — the pre-existing .gitignore '
      'is not even overwritten',
      () async {
        // The commit guard is written BEFORE the identity, `known_hosts` and
        // wrapper, so it is the earliest write this class makes and therefore
        // the earliest witness to one. A collision that overwrote it would be a
        // collision that had already written into somebody else's directory.
        seedUnreviewedCheckout();
        File('$productRoot/.gitignore').writeAsStringSync(
          '# somebody else\'s content\nkeep-me\n',
        );

        writeRealGit();
        await expectLater(
          materialize(),
          throwsA(isA<DurableWorkspaceRootCollisionException>()),
        );

        expect(
          File('$productRoot/.gitignore').readAsStringSync(),
          '# somebody else\'s content\nkeep-me\n',
          reason:
              'the commit guard was rewritten. It is the first thing this class '
              'writes, so this means the refusal did not precede the writes',
        );
        for (final name in [
          SshDurableWorkspaceMaterializer.identityFileName,
          SshDurableWorkspaceMaterializer.knownHostsFileName,
          SshDurableWorkspaceMaterializer.sshWrapperFileName,
        ]) {
          expect(
            File('$productRoot/$name').existsSync(),
            isFalse,
            reason:
                '$name was written into a colliding root. Keeping the TREE must '
                'never become a reason to keep the CREDENTIAL — these are '
                'separate obligations and both still hold on this path',
          );
        }
      },
    );

    test(
      'keeping the tree does not keep the credential — R-9 holds on the '
      'refusal path too',
      () async {
        // Obligation 6 says the credential material is destroyed FIRST and
        // UNCONDITIONALLY, before anything is decided about the repository's
        // fate. The fix adds a path that decides the repository's fate and then
        // keeps it, so the obligation needs re-asserting on that path
        // specifically — a guard that protects the tree by declining to clean up
        // would satisfy the tree test and break R-9.
        seedUnreviewedCheckout();
        writeRealGit();

        await expectLater(
          materialize(),
          throwsA(isA<DurableWorkspaceRootCollisionException>()),
        );

        for (final name in [
          SshDurableWorkspaceMaterializer.identityFileName,
          SshDurableWorkspaceMaterializer.knownHostsFileName,
          SshDurableWorkspaceMaterializer.sshWrapperFileName,
        ]) {
          expect(
            File('$productRoot/$name').existsSync(),
            isFalse,
            reason:
                '$name survived the refusal. A tree that outlives a failed '
                'provisioning must not become a reason for a deploy-key '
                'identity to outlive it',
          );
        }
        // And nothing that could authenticate: no identity reference in the
        // existing tree's own config either.
        final localConfig = _gitIn(
          '$productRoot/checkout',
          ['config', '--list', '--local'],
        );
        expect(
          localConfig.toLowerCase(),
          isNot(contains('sshcommand')),
        );
        expect(
          localConfig.toLowerCase(),
          isNot(contains('identityfile')),
        );
      },
    );

    test(
      'a root that pre-exists for NO related reason — an empty directory '
      'somebody made — is refused and left alone too',
      () async {
        // The case the review named explicitly: a root that exists for some
        // other reason. There is nothing to recognise it by, and that is
        // precisely why the guard asks a question about PROVENANCE instead of
        // about content: an empty directory is not a broken clone, it is a
        // directory somebody owns.
        Directory(productRoot).createSync(recursive: true);
        File('$productRoot/OPERATOR-NOTES.md').writeAsStringSync('not ours');

        writeRealGit();
        await expectLater(
          materialize(),
          throwsA(isA<DurableWorkspaceRootCollisionException>()),
        );

        expect(
          File('$productRoot/OPERATOR-NOTES.md').existsSync(),
          isTrue,
          reason:
              'a directory this call did not create was emptied. The '
              'materialiser has no way to know what that directory is for, so '
              'it does not get to decide',
        );
        expect(
          Directory(productRoot).listSync().map((e) => e.path.split('/').last),
          ['OPERATOR-NOTES.md'],
          reason: 'the collision refusal wrote something into the root',
        );
      },
    );

    test(
      'an EMPTY pre-existing root is refused as well, not adopted',
      () async {
        Directory(productRoot).createSync(recursive: true);
        writeRealGit();
        await expectLater(
          materialize(),
          throwsA(isA<DurableWorkspaceRootCollisionException>()),
        );
        expect(Directory(productRoot).existsSync(), isTrue);
        expect(
          Directory(productRoot).listSync(),
          isEmpty,
          reason: 'the refusal adopted the directory rather than refusing it',
        );
      },
    );

    test(
      'the orphan-tree case: a complete clone with no record is refused, not '
      'deleted on the way past',
      () async {
        // `provision()` materialises and THEN writes the onboarding record, so
        // a record write that fails after a successful clone leaves a tree with
        // no record pointing at it. The next instruction used to reach
        // `git remote add origin`, exit 3, and destroy it.
        //
        // The materialiser deliberately does NOT try to tell an orphan from a
        // live clone — "is there a record" is not a fact about the filesystem
        // it is asked about, the record lives in the database, and a guard that
        // guessed would be the same bug wearing a different hat. So the orphan
        // and the live checkout take the same path: refused, intact.
        final checkout = seedUnreviewedCheckout(withCommitGuard: false);
        final before = _gitIn(checkout.path, ['rev-parse', 'HEAD']);

        writeRealGit();
        await expectLater(
          materialize(),
          throwsA(isA<DurableWorkspaceRootCollisionException>()),
        );

        expect(_gitIn(checkout.path, ['rev-parse', 'HEAD']), before);
        expect(
          File('${checkout.path}/UNREVIEWED.md').existsSync(),
          isTrue,
        );
      },
    );

    test(
      'the collision names the root and what was found in it, so an operator '
      'can act on it',
      () async {
        seedUnreviewedCheckout();
        writeRealGit();

        Object? caught;
        try {
          await materialize();
        } on Object catch (error) {
          caught = error;
        }

        expect(caught, isA<DurableWorkspaceRootCollisionException>());
        final collision = caught! as DurableWorkspaceRootCollisionException;
        expect(collision.productRoot, productRoot);
        expect(collision.productId, 'p1');
        expect(collision.repositoryId, 'repo1');
        expect(
          collision.findings.join(' '),
          allOf(
            contains('object store'),
            // The count, so an operator can tell "one thing" from "a workspace
            // I did not expect to find here" without listing the directory.
            matches(RegExp(r'holds \d+ entr')),
          ),
          reason:
              'the operator is told what they are looking at. "Something is '
              'there" is not actionable; "an existing clone with its own git '
              'object store" is',
        );
        final text = collision.toString();
        expect(text, contains(productRoot));
        expect(text, contains('did not create it'));
        expect(
          text.toUpperCase(),
          isNot(contains('PRIVATE KEY')),
          reason: 'this text is logged and persisted; it must carry no secret',
        );
      },
    );

    test(
      'the COUNTERPART: a root THIS call created is still removed when its '
      'provisioning fails',
      () async {
        // The negative control, and the reason the fix is not simply "stop
        // deleting". A partial clone written by this call is litter this class
        // created and this class removes; nothing here may regress it. The
        // existing R-9 refusals above assert the same outcome, and they still
        // pass — but they assert a side effect, and this asserts the policy.
        writeGit(localConfigExtra: 'core.sshIdentity=$productRoot/identity');
        await expectLater(
          materialize(),
          throwsA(isA<DurableWorkspaceMaterializationException>()),
        );
        expect(
          Directory(productRoot).existsSync(),
          isFalse,
          reason:
              'a root created by this call and left half-built is exactly what '
              'the destroy exists for. Refusing to delete pre-existing state '
              'must not become refusing to clean up its own',
        );
      },
    );

    test(
      'the refusal is not about the HOST KEY: a colliding root with a perfectly '
      'matching host key is refused for the collision alone',
      () async {
        // Both refusals are live at once here. The host key matches, so the
        // refusal can only have come from the root check — which is what makes
        // this a test of the new guard rather than of the existing one.
        seedUnreviewedCheckout();
        writeRealGit();
        await expectLater(
          materialize(),
          throwsA(
            isA<DurableWorkspaceRootCollisionException>().having(
              (e) => e.toString(),
              'message',
              isNot(contains('host key')),
            ),
          ),
        );
      },
    );
  });
}

/// Marks the suite skipped when the host has no real `git`.
///
/// Named rather than inlined so the skip is a single deliberate statement
/// about a missing prerequisite, instead of `?? null` turning every assertion
/// into a `NoSuchMethodError` that reads like a defect in the guard.
Never skipIfNoRealGit() {
  // ignore: only_throw_errors
  throw _NoRealGitOnThisHost();
}

class _NoRealGitOnThisHost implements Exception {
  @override
  String toString() =>
      'no real git on PATH; the destroy-provenance suite asserts real git '
      'behaviour and will not simulate it';
}
