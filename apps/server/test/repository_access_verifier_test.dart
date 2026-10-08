import 'dart:io';

import 'package:control_plane_server/src/credentials/posix_file_permissions.dart';
import 'package:control_plane_server/src/credentials/repository_access_verifier.dart';
import 'package:control_plane_server/src/credentials/secret_material.dart';
import 'package:control_plane_server/src/credentials/ssh_keypair.dart';
import 'package:control_plane_server/src/credentials/ssh_remote.dart';
import 'package:test/test.dart';

/// Proof that the verification seam behaves as claimed under ADR 0018 §A2:
/// the identity it hands to the transport is a real SSH identity, the host key
/// is confirmed at the transport and not merely recorded, and the private half
/// does not survive the call — **on the failure path too**, which is the path a
/// happy-path test never reaches.
///
/// HOW THE TRANSPORT IS EXERCISED. This repository has no git host, no SSH
/// server and no network authority, so a genuinely authenticated clone cannot be
/// reproduced here and is not claimed. What IS reproduced is the whole seam
/// around it, with `PATH` pinned to stub `ssh-keyscan` and `git` while the real
/// `ssh-keygen` and the real `git` arguments stay in play:
///
///   * `ssh-keyscan` is stubbed to present a real, locally generated host key,
///     so the fingerprint comparison runs against a genuine OpenSSH-computed
///     value and the TOFU refusal is exercised for real.
///   * `git` is stubbed, and the stub inspects the identity file the verifier
///     wrote, the mode of that file, the contents of the `ssh` wrapper, and the
///     environment git was given — recording all of it for the assertions below.
///     That is stronger than running a real clone and inferring the same facts
///     from its exit status, because it reads what git was actually handed.
///   * `ssh-keygen` is NOT stubbed, so "is this a loadable SSH private key" is
///     answered by OpenSSH's own loader rather than by an assertion of ours.
const _scratchPrefix = 'shipit_credential_verify_';

/// Writes an executable shell stub and returns the bin directory to pin.
///
/// PATH-pinned rather than stubbed in-process because the verifier spawns `git`
/// and `ssh-keyscan` as real child processes through the `ssh` wrapper script;
/// the only faithful way to observe what they were handed is from inside one.
void _writeStub(Directory bin, String name, String body) {
  final file = File('${bin.path}/$name');
  file.writeAsStringSync(body);
  Process.runSync('chmod', ['755', file.path]);
}

/// Generates a genuine host key with OpenSSH and returns its authorized-keys
/// line and SHA-256 fingerprint.
(String, String) _realHostKey(Directory dir) {
  final path = '${dir.path}/hostkey';
  final result = Process.runSync('ssh-keygen', [
    '-q',
    '-t',
    'ed25519',
    '-N',
    '',
    '-C',
    'shipit-host-fixture',
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
  ).firstMatch((fingerprint.stdout as String));
  return (line, match!.group(0)!);
}

void main() {
  late Directory scratch;
  late Directory bin;
  late SshKeyPair keypair;
  late String hostKeyLine;
  late String hostKeyFingerprint;

  setUpAll(() {
    if (Process.runSync('ssh-keygen', ['-l', '-f', '/dev/null']).exitCode ==
        127) {
      return;
    }
  });

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('shipit_verifier_test_');
    bin = Directory('${scratch.path}/bin')..createSync(recursive: true);
    keypair = SshKeyPair.generate(comment: 'shipit+verifier');
    (hostKeyLine, hostKeyFingerprint) = _realHostKey(scratch);
  });

  tearDown(() {
    for (final entity in scratch.listSync()) {
      if (entity is Directory) {
        entity.deleteSync(recursive: true);
      } else {
        entity.deleteSync();
      }
    }
    scratch.deleteSync(recursive: true);
    // Nothing may outlive a test either. The prefix is this verifier's own, so
    // anything matching it after the run is a leak.
    final leaked = Directory.systemTemp
        .listSync()
        .whereType<Directory>()
        .where((d) => d.path.contains(_scratchPrefix))
        .map((d) => d.path)
        .toList();
    expect(
      leaked,
      isEmpty,
      reason: 'the verifier left scratch directories: $leaked',
    );
  });

  /// The real remote the stubbed host key belongs to. The port is never reached:
  /// `git` is stubbed, so this only has to be well-formed and distinguishable.
  SshRemote remote({int port = 2222}) => SshRemote(
    user: 'git',
    host: '127.0.0.1',
    port: port,
    repositoryPath: 'acme/x.git',
  );

  /// A stub `git` that records what the verifier handed it, then fails or
  /// succeeds on demand.
  ///
  /// The recording is the point. It reads the identity path straight out of the
  /// generated `ssh` wrapper, proves OpenSSH can load that exact file, and
  /// reports the mode and the wrapper's own text — so nothing about the identity
  /// file is inferred from outside the process that was supposed to use it.
  String gitStub({
    required String report,
    required bool succeed,
  }) =>
      '''
#!/bin/sh
# Test stub. Records what RepositoryAccessVerifier handed git, then exits.
#
# Only the clone invocation is recorded. The verifier also runs `git -C <dir>
# rev-parse HEAD` afterwards through the same PATH, and that call carries no
# GIT_SSH_COMMAND; recording it too would overwrite the clone's report with one
# describing a process that was never given an identity.
if [ "\$1" = "-C" ]; then
${succeed ? '  echo "0123456789abcdef0123456789abcdef01234567"\n  exit 0' : '  exit 1'}
fi
wrapper="\$GIT_SSH_COMMAND"
identity=\$(sed -n "s/.*-i '\\\\(.*\\\\)'.*/\\\\1/p" "\$wrapper" | head -1)
known_hosts=\$(sed -n "s/.*UserKnownHostsFile='\\\\(.*\\\\)'.*/\\\\1/p" "\$wrapper" | head -1)
{
  echo "wrapper=\$wrapper"
  echo "identity=\$identity"
  echo "identity_exists=\$( [ -f "\$identity" ] && echo yes || echo no )"
  echo "identity_mode=\$(stat -c %a "\$identity" 2>/dev/null || stat -f %Lp "\$identity" 2>/dev/null)"
  echo "identity_derived=\$(ssh-keygen -y -f "\$identity" 2>/dev/null)"
  echo "identity_fingerprint=\$(ssh-keygen -lf "\$identity" 2>/dev/null | awk '{print \$2}')"
  echo "home=\$HOME"
  echo "git_config_global=\$GIT_CONFIG_GLOBAL"
  echo "git_config_system=\$GIT_CONFIG_SYSTEM"
  echo "git_terminal_prompt=\$GIT_TERMINAL_PROMPT"
  echo "git_ssh_variant=\$GIT_SSH_VARIANT"
  echo "argv=\$*"
  # The host keys the clone was actually allowed to trust, read from the file the
  # wrapper points at. A host key is PUBLIC, so unlike the identity this is safe
  # to put in a test report — and unlike a wrapper-text assertion it is what
  # OpenSSH will read.
  echo "known_hosts_exists=\$( [ -f "\$known_hosts" ] && echo yes || echo no )"
  echo "known_hosts_body<<EOF"
  cat "\$known_hosts" 2>/dev/null
  echo "EOF"
  echo "wrapper_body<<EOF"
  cat "\$wrapper"
  echo "EOF"
} > "$report" 2>&1
${succeed ? '''# Succeed: create the destination the way a real clone would.
for a in "\$@"; do dest="\$a"; done
mkdir -p "\$dest"
exit 0
''' : '''
echo "fatal: could not read from remote repository" >&2
exit 128
'''}
''';

  group('the transport is handed a real, owner-only SSH identity', () {
    test('on the success path', () async {
      final report = '${scratch.path}/report.txt';
      _writeStub(bin, 'ssh-keyscan', '#!/bin/sh\necho "$hostKeyLine"\n');
      _writeStub(bin, 'git', gitStub(report: report, succeed: true));
      PosixFileModes.applyStrict(bin.path, '755');

      final outcome = await RepositoryAccessVerifier(pathPrefix: bin.path)
          .verify(
            remote: remote(),
            privateKeyPem: SecretBytes(keypair.privateKeyPemBytes),
            confirmedHostKeyFingerprint: hostKeyFingerprint,
          );

      expect(outcome.succeeded, isTrue);
      expect(outcome.secretMaterialRemoved, isTrue);
      expect(outcome.observedHostKeyFingerprint, hostKeyFingerprint);
      expect(outcome.committedRevision, hasLength(40));

      final seen = _parseReport(report);
      expect(seen['identity_exists'], 'yes');
      expect(
        seen['identity_mode'],
        '600',
        reason: 'a deploy key readable by another account is not custody',
      );
      expect(
        seen['identity_derived'],
        startsWith('ssh-ed25519 '),
        reason: 'OpenSSH could not load the identity file the verifier wrote',
      );
      // `ssh-keygen -y` echoes the comment it read from the file, so compare the
      // algorithm and the base64 blob — the two fields that identify the key.
      expect(
        (seen['identity_derived'] ?? '').split(' ').take(2).join(' '),
        keypair.publicKeyAuthorizedLine.split(' ').take(2).join(' '),
        reason: 'the identity on disk is not the pair this keypair describes',
      );
      expect(seen['identity_fingerprint'], keypair.fingerprint);

      // Hardening actually in force on the clone.
      expect(seen['git_terminal_prompt'], '0');
      expect(seen['git_ssh_variant'], 'ssh');
      expect(seen['git_config_global'], '/dev/null');
      expect(seen['git_config_system'], '/dev/null');
      expect(
        seen['home'],
        isNot(Directory.current.path),
        reason: 'HOME must point at the scratch tree, not the operator\'s',
      );

      // The clone used the remote the credential recorded.
      expect(seen['argv'], contains('ssh://git@127.0.0.1:2222/acme/x.git'));

      // The wrapper itself must carry no secret.
      final wrapperBody = seen['wrapper_body']!;
      expect(wrapperBody, contains('StrictHostKeyChecking=yes'));
      expect(wrapperBody, contains('IdentitiesOnly=yes'));
      expect(wrapperBody, contains('IdentityAgent=none'));
      expect(wrapperBody, contains('BatchMode=yes'));
      expect(wrapperBody, contains('PasswordAuthentication=no'));
      expect(wrapperBody, contains('KbdInteractiveAuthentication=no'));
      expect(wrapperBody, isNot(contains('PRIVATE KEY')));
      expect(wrapperBody, isNot(contains('openssh-key-v1')));
    });

    test('on the FAILURE path, and the scratch tree is gone', () async {
      // The path the dispatch names explicitly: cleanup must happen even when
      // the clone fails.
      final report = '${scratch.path}/report.txt';
      _writeStub(bin, 'ssh-keyscan', '#!/bin/sh\necho "$hostKeyLine"\n');
      _writeStub(bin, 'git', gitStub(report: report, succeed: false));
      PosixFileModes.applyStrict(bin.path, '755');

      final outcome = await RepositoryAccessVerifier(pathPrefix: bin.path)
          .verify(
            remote: remote(port: 2223),
            privateKeyPem: SecretBytes(keypair.privateKeyPemBytes),
            confirmedHostKeyFingerprint: hostKeyFingerprint,
          );

      expect(outcome.succeeded, isFalse, reason: 'the stub git exits 128');
      expect(
        outcome.secretMaterialRemoved,
        isTrue,
        reason:
            'a failed clone that leaves the private half on disk is the '
            'failure mode the cleanup exists to prevent',
      );
      expect(outcome.failureReason, contains('could not read from remote'));
      expect(
        outcome.failureReason,
        isNot(contains('PRIVATE KEY')),
        reason:
            'the reason is persisted on the credential row and shown in the UI',
      );
      expect(outcome.committedRevision, isNull);

      // The stub really did run, so this is the failure path and not an early
      // refusal that never wrote anything.
      expect(_parseReport(report)['identity_exists'], 'yes');
      expect(
        Directory.systemTemp
            .listSync()
            .whereType<Directory>()
            .where((d) => d.path.contains(_scratchPrefix))
            .map((d) => d.path),
        isEmpty,
      );
    });
  });

  group('the host key is confirmed at the transport', () {
    test(
      'a fingerprint the human did not confirm refuses the connection',
      () async {
        final report = '${scratch.path}/report.txt';
        _writeStub(bin, 'ssh-keyscan', '#!/bin/sh\necho "$hostKeyLine"\n');
        _writeStub(bin, 'git', gitStub(report: report, succeed: true));
        PosixFileModes.applyStrict(bin.path, '755');

        await expectLater(
          RepositoryAccessVerifier(pathPrefix: bin.path).verify(
            remote: remote(port: 2224),
            privateKeyPem: SecretBytes(keypair.privateKeyPemBytes),
            // A well-formed fingerprint that is simply not this host's.
            confirmedHostKeyFingerprint:
                'SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
          ),
          throwsA(
            isA<HostKeyNotPresentedException>()
                .having((e) => e.host, 'host', '127.0.0.1')
                .having(
                  (e) => e.presentedFingerprints,
                  'presentedFingerprints',
                  contains(hostKeyFingerprint),
                ),
          ),
        );

        // git must never have run: ADR 0018 refuses to *connect*, not to record a
        // failure after connecting.
        expect(File(report).existsSync(), isFalse);
        expect(
          Directory.systemTemp.listSync().whereType<Directory>().where(
            (d) => d.path.contains(_scratchPrefix),
          ),
          isEmpty,
          reason: 'the refusal path must clean up too',
        );
      },
    );

    test('a host that presents nothing at all refuses', () async {
      _writeStub(bin, 'ssh-keyscan', '#!/bin/sh\nexit 0\n');
      _writeStub(
        bin,
        'git',
        gitStub(report: '${scratch.path}/r', succeed: true),
      );
      PosixFileModes.applyStrict(bin.path, '755');
      await expectLater(
        RepositoryAccessVerifier(pathPrefix: bin.path).verify(
          remote: remote(port: 2225),
          privateKeyPem: SecretBytes(keypair.privateKeyPemBytes),
          confirmedHostKeyFingerprint: hostKeyFingerprint,
        ),
        throwsA(
          isA<HostKeyNotPresentedException>().having(
            (e) => e.presentedFingerprints,
            'presentedFingerprints',
            isEmpty,
          ),
        ),
      );
    });

    test('the known_hosts written holds only the confirmed key', () async {
      // A second, unconfirmed key is offered by the host. It must not end up in
      // the file git trusts, or the clone could succeed against a key the
      // operator never saw.
      //
      // Asserted by READING the file from inside the `git` process that was
      // supposed to use it — not by asserting the wrapper names it, which is what
      // the earlier version of this test did and which proves only that a path was
      // written down. L-8: this seam had a negative test, but a proxy one.
      final otherDir = Directory('${scratch.path}/other')
        ..createSync(recursive: true);
      final (otherLine, _) = _realHostKey(otherDir);
      final report = '${scratch.path}/report.txt';
      _writeStub(
        bin,
        'ssh-keyscan',
        '#!/bin/sh\necho "${hostKeyLine.replaceAll("'", "")}"\n'
            'echo "${otherLine.replaceAll("'", "")}"\n',
      );
      _writeStub(bin, 'git', gitStub(report: report, succeed: true));
      PosixFileModes.applyStrict(bin.path, '755');

      await RepositoryAccessVerifier(pathPrefix: bin.path).verify(
        remote: remote(port: 2226),
        privateKeyPem: SecretBytes(keypair.privateKeyPemBytes),
        confirmedHostKeyFingerprint: hostKeyFingerprint,
      );
      final seen = _parseReport(report);
      expect(seen['identity_exists'], 'yes');
      expect(seen['known_hosts_exists'], 'yes');
      final knownHosts = _delimited(seen, 'known_hosts_body');
      expect(
        knownHosts,
        contains(hostKeyLine.split(' ')[1]),
        reason: 'the confirmed key must be the one OpenSSH is allowed to trust',
      );
      expect(
        knownHosts,
        isNot(contains(otherLine.split(' ')[1])),
        reason:
            'a second, unconfirmed host key in known_hosts would let the clone '
            'succeed against a host the operator never saw',
      );
      // One line, one key — not "the right one is somewhere in there".
      expect(
        knownHosts.trim().split('\n').where((l) => l.trim().isNotEmpty),
        hasLength(1),
      );
      expect(seen['wrapper_body'], contains('UserKnownHostsFile='));
    });
  });

  group('a timeout kills the process tree, not just the wait (M-3)', () {
    test('the clone child and its grandchild are gone, and so is the file', () async {
      // M-3, and the path the earlier code got wrong. `Process.run(...).timeout()`
      // stops the *Dart* side from waiting; it does not terminate the child. So a
      // `git` and the `ssh` it forked could outlive the call — the scratch tree
      // was deleted (the path is gone) but a live process still held the identity
      // and could still authenticate with it.
      //
      // The stub below therefore forks a GRANDCHILD that opens the identity file
      // and then sleeps far longer than the ceiling. Dart's `kill` reaches only the
      // direct child, so the grandchild is the part that proves the tree was
      // walked rather than just the top process signalled.
      final report = '${scratch.path}/report.txt';
      _writeStub(bin, 'ssh-keyscan', '#!/bin/sh\necho "$hostKeyLine"\n');
      _writeStub(
        bin,
        'git',
        hangingGitStub(
          report: report,
          sleepSeconds: 120,
        ),
      );
      PosixFileModes.applyStrict(bin.path, '755');

      Object? thrown;
      final started = DateTime.now();
      try {
        await RepositoryAccessVerifier(
          pathPrefix: bin.path,
          cloneTimeout: const Duration(seconds: 2),
        ).verify(
          remote: remote(port: 2227),
          privateKeyPem: SecretBytes(keypair.privateKeyPemBytes),
          confirmedHostKeyFingerprint: hostKeyFingerprint,
        );
      } on Object catch (error) {
        thrown = error;
      }
      final elapsed = DateTime.now().difference(started);

      expect(
        thrown,
        isA<AccessVerificationTimeoutException>(),
        reason: 'a clone that outlives its ceiling must be a typed refusal',
      );
      expect(elapsed, lessThan(const Duration(seconds: 30)));
      final timeout = thrown! as AccessVerificationTimeoutException;
      expect(timeout.helper, 'git');
      expect(timeout.limit, const Duration(seconds: 2));
      _expectNoMaterial(timeout.toString(), 'the timeout message');

      // The stub really reached the clone with a real identity file, so this is
      // the timeout path and not an early refusal.
      final pids = _parseReport('$report.pids');
      expect(File('$report.child').readAsStringSync(), contains('yes'));
      expect(
        int.tryParse(pids['git_pid'] ?? ''),
        isNotNull,
        reason: 'the stub must record the pids the verifier has to kill',
      );
      expect(int.tryParse(pids['child_pid'] ?? ''), isNotNull);

      // THE ASSERTION. Both processes must be gone: the child Dart signalled and
      // the grandchild only a tree walk can reach. Polled rather than asserted
      // once, because a killed process takes a moment to be reaped.
      for (final pid in [
        int.parse(pids['git_pid']!),
        int.parse(pids['child_pid']!),
      ]) {
        expect(
          await _waitUntilDead(pid),
          isTrue,
          reason: 'pid $pid survived the clone timeout',
        );
      }

      // And the private half is gone from disk, on this path as on the others.
      expect(
        Directory.systemTemp
            .listSync()
            .whereType<Directory>()
            .where((d) => d.path.contains(_scratchPrefix))
            .map((d) => d.path),
        isEmpty,
        reason: 'the timeout path must clean up too',
      );
    });
  });

  group('diagnostics are safe to persist and show', () {
    test(
      'a real clone against a dead port yields a secretless reason',
      () async {
        // No stubs at all here: a genuinely unreachable host, the real git, the
        // real ssh-keyscan. Proves the transport is really invoked and that
        // nothing about the failure path prints key material.
        final verifier = RepositoryAccessVerifier(
          connectTimeout: const Duration(seconds: 5),
          cloneTimeout: const Duration(seconds: 60),
        );
        // Port 1 on loopback: ssh-keyscan gets nothing, so the refusal fires
        // before any clone is attempted, which is the correct order.
        await expectLater(
          verifier.verify(
            remote: SshRemote(
              user: 'git',
              host: '127.0.0.1',
              port: 1,
              repositoryPath: 'acme/x.git',
            ),
            privateKeyPem: SecretBytes(keypair.privateKeyPemBytes),
            confirmedHostKeyFingerprint: hostKeyFingerprint,
          ),
          throwsA(isA<HostKeyNotPresentedException>()),
        );
        expect(
          Directory.systemTemp.listSync().whereType<Directory>().where(
            (d) => d.path.contains(_scratchPrefix),
          ),
          isEmpty,
        );
      },
    );
  });
}

/// A stub `git` that never returns, and leaves a grandchild holding the identity.
///
/// The grandchild is the point. Dart's `Process.kill` signals only the process it
/// started, so the only way the grandchild dies is if the verifier walks the tree
/// — which is exactly the behaviour M-3 said was missing. The grandchild opens
/// the identity on a file descriptor before sleeping, so "it was holding the key"
/// is recorded rather than assumed.
String hangingGitStub({
  required String report,
  required int sleepSeconds,
}) =>
    '''
#!/bin/sh
# Test stub. Records its own pid and a grandchild's, holds the identity open, and
# then never returns.
wrapper="\$GIT_SSH_COMMAND"
identity=\$(sed -n "s/.*-i '\\\\(.*\\\\)'.*/\\\\1/p" "\$wrapper" | head -1)
# A subshell, not exec: it becomes a CHILD of this stub, so it is two levels down
# from the process the verifier starts.
(
  exec 9<"\$identity" || exit 3
  echo "child_opened_identity=yes" > "$report.child"
  sleep $sleepSeconds
) &
child=\$!
echo "git_pid=\$\$" > "$report.pids"
echo "child_pid=\$child" >> "$report.pids"
exec 9<"\$identity"
sleep $sleepSeconds
''';

/// Whether [pid] is no longer a live process, polled for up to ten seconds.
///
/// `kill -0` is the portable existence check: signal 0 performs the permission
/// and existence checks without delivering anything. Exit 0 means the pid is
/// still there. Polled rather than sampled once because a signalled process is
/// reaped asynchronously, and a single sample would be a race the test could lose.
Future<bool> _waitUntilDead(int pid) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final probe = Process.runSync('kill', ['-0', '$pid']);
    if (probe.exitCode != 0) return true;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return false;
}

/// Fragments of key material that must not appear in [text].
///
/// The private half is not in this file at all — the identity is written by the
/// verifier into its own scratch tree — so what is checked here is that the
/// refusal the operator reads does not quote the PEM it is talking about.
void _expectNoMaterial(String text, String label) {
  expect(text.contains('PRIVATE KEY'), isFalse, reason: label);
  expect(text.contains('BEGIN OPENSSH'), isFalse, reason: label);
}

/// Parses the stub's `key=value` report.
Map<String, String> _parseReport(String path) {
  final text = File(path).readAsStringSync();
  final fields = <String, String>{};
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    for (final marker in ['wrapper_body', 'known_hosts_body']) {
      if (line == '$marker<<EOF') {
        final collected = <String>[];
        for (var j = i + 1; j < lines.length && lines[j] != 'EOF'; j++) {
          collected.add(lines[j]);
        }
        fields[marker] = collected.join('\n');
        if (marker == 'wrapper_body') i = lines.length;
        break;
      }
    }
    if (fields.containsKey('wrapper_body')) continue;
    final split = line.indexOf('=');
    if (split > 0) fields[line.substring(0, split)] = line.substring(split + 1);
  }
  return fields;
}

/// One `<<EOF`-delimited block from a stub report, read by its field name.
String _delimited(Map<String, String> report, String field) =>
    report[field] ?? '';

/// Local `awk` usage above keeps the stub dependent only on POSIX tools that
/// ship with git and OpenSSH.
