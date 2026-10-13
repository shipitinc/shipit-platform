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
}
