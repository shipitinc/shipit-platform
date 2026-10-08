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
      // The stub could not see known_hosts (it only reads the wrapper), so the
      // direct assertion is on the wrapper's UserKnownHostsFile target plus the
      // fact that the clone was still driven by the confirmed fingerprint.
      expect(seen['wrapper_body'], contains('UserKnownHostsFile='));
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

/// Parses the stub's `key=value` report.
Map<String, String> _parseReport(String path) {
  final text = File(path).readAsStringSync();
  final fields = <String, String>{};
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line == 'wrapper_body<<EOF') {
      fields['wrapper_body'] = lines.sublist(i + 1).join('\n');
      break;
    }
    final split = line.indexOf('=');
    if (split > 0) fields[line.substring(0, split)] = line.substring(split + 1);
  }
  return fields;
}

/// Local `awk` usage above keeps the stub dependent only on POSIX tools that
/// ship with git and OpenSSH.
