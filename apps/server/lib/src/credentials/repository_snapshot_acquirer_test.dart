import 'dart:io';

import 'package:control_plane_server/src/credentials/posix_file_permissions.dart';
import 'package:control_plane_server/src/credentials/repository_snapshot_acquirer.dart';
import 'package:control_plane_server/src/credentials/secret_material.dart';
import 'package:control_plane_server/src/credentials/ssh_keypair.dart';
import 'package:control_plane_server/src/credentials/ssh_remote.dart';
// `test` is a dev_dependency of `control_plane_server`. It is unresolved as a
// `lib/` import, which is a known cost of co-locating tests here rather than
// under `test/` — the lane that owns `apps/server/test/**` is where a test that
// needs to resolve `package:test` from `lib/` belongs.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

/// THE DEFECT THIS FILE EXISTS FOR.
///
/// `SshPinnedSnapshotMaterializer.materialize` spawned
/// `git --no-pager -C <scratch>/checkout …`, and `git -C <dir>` chdirs *before*
/// it dispatches the subcommand. `-C` names where to work, never what to
/// create — `git clone <url> <dir>` creates its destination, `git -C <dir> init`
/// does not. The scratch directory came from `createTempSync`, which creates the
/// scratch and nothing inside it, so the `-C` target did not exist and the
/// FIRST git call died with
///
/// ```text
/// fatal: cannot change to '/tmp/baseline_snapshot_XXXX/checkout': No such file or directory
/// ```
///
/// which is `BaselineSnapshotMaterializationException`, which
/// `SnapshotPinnedRevisionResolver` reads as "this revision is unresolvable" and
/// turns into a null. The acquisition therefore never produced a tree, the sweep
/// never enqueued a job, and every 30-second pass reported `skipped: 1` while
/// spending a credential version on an access check whose result nothing used.
///
/// ## Why no existing test caught it
///
/// Every test of this class substituted a fake for the process layer, so git was
/// never really spawned and never had the chance to say `cannot change to`.
/// The seam that makes the real sequence observable is [pathPrefix], the one
/// `RepositoryAccessVerifier` already had and this class lacked — that absence
/// is precisely why the fakes were possible.
///
/// ## How this is exercised without a network
///
/// No git host, no SSH server, no network authority, and — deliberately — no
/// real clone, which is what made the defect invisible in the first place.
/// `PATH` is pinned to a stub `ssh-keyscan` and a stub `git`; the real
/// `ssh-keygen` still computes the fingerprint, so the host-key comparison runs
/// against a genuine OpenSSH-computed value. The stub `git` records, for EVERY
/// invocation, the directory it was told to work in and whether that directory
/// existed at the instant it was spawned. That is the precondition the defect
/// violated, asserted directly rather than inferred from an exit status.
const String _scratchPrefix = 'clonefix_snapshot_test_';

/// One `git` invocation, as the stub saw it from inside the spawn.
typedef _GitInvocation = ({
  /// The subcommand git was dispatched to (`init`, `fetch`, `rev-parse`, …).
  String subcommand,

  /// The path `-C` named.
  String directory,

  /// Whether that path was a directory when git was spawned.
  bool existed,

  /// Its permission bits when git was spawned, or `null` if it was not there.
  String? mode,
});

/// Writes an executable shell stub into [bin].
void _writeStub(Directory bin, String name, String body) {
  final file = File('${bin.path}/$name');
  file.writeAsStringSync(body);
  Process.runSync('chmod', ['755', file.path]);
}

/// Generates a genuine host key with OpenSSH and returns its authorized-keys
/// line and SHA-256 fingerprint.
///
/// Real, because `_matchConfirmedHostKeys` compares the value the real
/// `ssh-keygen -lf -` produces; a made-up fingerprint would make the stubbed
/// scan unrecognisable to the comparison and the test would never reach git.
(String, String) _realHostKey(Directory dir) {
  final path = '${dir.path}/hostkey';
  final result = Process.runSync('ssh-keygen', [
    '-q',
    '-t',
    'ed25519',
    '-N',
    '',
    '-C',
    'shipit-clonefix-test-host',
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

/// A stub `git` that records the state of its `-C` directory on every call.
///
/// It exits 0 unconditionally, which is the point of the trap: a stub that
/// exited non-zero on a missing directory would only prove that the stub can
/// tell, not that the production code arranged for the directory to be there.
/// So this one always claims success, and the assertions live on what it
/// recorded — the acquisition below genuinely completes, and the test still
/// fails against code that never created the tree.
String _gitStub({required String report, required String revision}) =>
    '''
#!/bin/sh
# Test stub. Records the `-C` directory of every invocation, and whether it
# existed at the moment git was spawned.
report="$report"
dir=
sub=
while [ \$# -gt 0 ]; do
  if [ "\$1" = "-C" ]; then shift; dir="\$1"; shift; continue; fi
  case "\$1" in -*) ;; *) sub="\$1"; break ;; esac
  shift
done
exists=no
if [ -d "\$dir" ]; then exists=yes; fi
mode=none
m=\$(stat -c %a "\$dir" 2>/dev/null || stat -f %Lp "\$dir" 2>/dev/null)
if [ -n "\$m" ]; then mode="\$m"; fi
printf 'git\\t%s\\t%s\\t%s\\t%s\\n' "\$sub" "\$dir" "\$exists" "\$mode" >> "\$report"
if [ "\$sub" = "rev-parse" ]; then echo "$revision"; fi
exit 0
''';

/// Parses the stub's report. Each line is
/// `git<TAB>subcommand<TAB>directory<TAB>exists<TAB>mode`.
///
/// The leading tag is not decoration: it is what makes a change to the stub's
/// record format fail here as a loud parse error rather than as an assertion
/// comparing a subcommand against a directory path.
List<_GitInvocation> _readInvocations(String report) {
  if (!File(report).existsSync()) return const [];
  return File(
    report,
  ).readAsLinesSync().where((line) => line.trim().isNotEmpty).map((line) {
    final fields = line.split('\t');
    if (fields.length != 5 || fields.first != 'git') {
      throw StateError('unreadable git stub record: "$line"');
    }
    return (
      subcommand: fields[1],
      directory: fields[2],
      existed: fields[3] == 'yes',
      mode: fields[4] == 'none' ? null : fields[4],
    );
  }).toList();
}

/// Every snapshot-tree path currently in the system temp directory.
Set<String> _snapshotPrefixes() => Directory.systemTemp
    .listSync()
    .whereType<Directory>()
    .where((d) => d.path.contains(_scratchPrefix))
    .map((d) => d.path)
    .toSet();

void main() {
  late Directory scratch;
  late Directory bin;
  late String report;
  late SshKeyPair keypair;
  late String hostKeyLine;
  late String hostKeyFingerprint;

  /// Snapshot-tree prefixes present when this test started, so the leak check
  /// below is about what *this* test leaked. A bare "any prefix in the system
  /// temp dir" check is the same shape the verifier's tests use, but it lets one
  /// leak — from an earlier test in this file, or from an earlier run on a
  /// developer's machine — fail every test that runs after it, which buries the
  /// assertion that actually has something to say.
  late Set<String> snapshotPrefixesBefore;

  const revision = 'f58d6fb129c1d4265ada5af9dc359eb5ac27a9a2';

  /// The remote the stubbed host key belongs to. The port is never reached —
  /// `git` is stubbed — so it only has to be well-formed.
  SshRemote remote() => SshRemote(
    user: 'git',
    host: '127.0.0.1',
    port: 2222,
    repositoryPath: 'acme/x.git',
  );

  setUp(() {
    snapshotPrefixesBefore = _snapshotPrefixes();
    scratch = Directory.systemTemp.createTempSync('clonefix_test_');
    bin = Directory('${scratch.path}/bin')..createSync(recursive: true);
    report = '${scratch.path}/git-report.tsv';
    keypair = SshKeyPair.generate(comment: 'shipit+clonefix');
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
    // The materializer removes its own scratch on every path; one of its trees
    // surviving its own call is a leaked checkout holding private material in
    // transit, which is an incident rather than a tidiness question.
    final leaked = _snapshotPrefixes().difference(snapshotPrefixesBefore);
    expect(
      leaked,
      isEmpty,
      reason: 'the materializer left snapshot trees behind: $leaked',
    );
  });

  group('SshPinnedSnapshotMaterializer', () {
    test(
      'every git invocation works in a directory that already exists',
      () async {
        // THE REGRESSION. `git -C <dir>` changes directory before dispatching,
        // so the directory must exist before the FIRST call — `init`, the one
        // that needs no network and therefore must never be able to fail here.
        // Against the unfixed code this records `exists=no` on `init` and still
        // exits 0, which is exactly how the defect survived: nothing threw until
        // a real git refused.
        _writeStub(bin, 'ssh-keyscan', '#!/bin/sh\necho "$hostKeyLine"\n');
        _writeStub(bin, 'git', _gitStub(report: report, revision: revision));
        PosixFileModes.applyStrict(bin.path, '755');

        final snapshot =
            await SshPinnedSnapshotMaterializer(
              pathPrefix: bin.path,
              scratchPrefix: _scratchPrefix,
            ).materialize(
              productId: 'product-a',
              repositoryId: 'repo',
              remote: remote(),
              privateKeyPem: SecretBytes(keypair.privateKeyPemBytes),
              confirmedHostKeyFingerprint: hostKeyFingerprint,
              pinnedRevision: revision,
            );
        addTearDown(snapshot.release);

        final invocations = _readInvocations(report);
        expect(
          invocations,
          isNotEmpty,
          reason: 'the stub git was never spawned, so nothing was proven',
        );
        expect(
          invocations.map((i) => i.subcommand),
          ['init', 'remote', 'fetch', 'checkout', 'rev-parse'],
          reason:
              'the acquisition is init → remote add → fetch → checkout → '
              'rev-parse, and every one of them names the same tree with -C',
        );
        expect(
          invocations.first.subcommand,
          'init',
          reason: 'the cheapest git call is the one that was failing',
        );
        for (final invocation in invocations) {
          expect(
            invocation.existed,
            isTrue,
            reason:
                'git was spawned as `git --no-pager -C ${invocation.directory} '
                '${invocation.subcommand}`, and git -C chdirs before dispatch — '
                'against a directory that is not there it exits non-zero with '
                '"fatal: cannot change to"',
          );
        }
        // One tree, named identically every time.
        expect(invocations.map((i) => i.directory).toSet(), hasLength(1));
      },
    );

    test(
      'the tree it hands to git is owner-only, like everything else it writes',
      () async {
        // NOT `createSync` default modes. The clone tree is private material in
        // transit — a checked-out working copy that the identity file beside it
        // is authenticating — and this class is deliberately 0700/0600
        // throughout. Under the near-universal umask 022 a default `createSync`
        // would leave this 0755 and nothing would have complained.
        _writeStub(bin, 'ssh-keyscan', '#!/bin/sh\necho "$hostKeyLine"\n');
        _writeStub(bin, 'git', _gitStub(report: report, revision: revision));
        PosixFileModes.applyStrict(bin.path, '755');

        final snapshot =
            await SshPinnedSnapshotMaterializer(
              pathPrefix: bin.path,
              scratchPrefix: _scratchPrefix,
            ).materialize(
              productId: 'product-a',
              repositoryId: 'repo',
              remote: remote(),
              privateKeyPem: SecretBytes(keypair.privateKeyPemBytes),
              confirmedHostKeyFingerprint: hostKeyFingerprint,
              pinnedRevision: revision,
            );
        addTearDown(snapshot.release);

        final invocations = _readInvocations(report);
        expect(invocations, isNotEmpty);
        for (final invocation in invocations) {
          expect(
            invocation.mode,
            '700',
            reason:
                '${invocation.directory} was readable by other accounts when git '
                'was pointed at it',
          );
        }
      },
    );

    test(
      'the snapshot it hands back carries no credential material at all',
      () async {
        // §13a by name, ADR 0018 A3 further: the object flows into job records
        // and logs, so it must not hold a key, a fingerprint, or — the part that
        // is easy to forget because it is only metadata — the reference name.
        _writeStub(bin, 'ssh-keyscan', '#!/bin/sh\necho "$hostKeyLine"\n');
        _writeStub(bin, 'git', _gitStub(report: report, revision: revision));
        PosixFileModes.applyStrict(bin.path, '755');

        final snapshot =
            await SshPinnedSnapshotMaterializer(
              pathPrefix: bin.path,
              scratchPrefix: _scratchPrefix,
            ).materialize(
              productId: 'product-a',
              repositoryId: 'repo',
              remote: remote(),
              privateKeyPem: SecretBytes(keypair.privateKeyPemBytes),
              confirmedHostKeyFingerprint: hostKeyFingerprint,
              pinnedRevision: revision,
            );
        addTearDown(snapshot.release);

        final rendered = snapshot.toString();
        expect(rendered, isNot(contains('PRIVATE KEY')));
        expect(rendered, isNot(contains(hostKeyLine)));
        expect(
          rendered,
          isNot(contains(hostKeyFingerprint)),
          reason:
              'a host key fingerprint is public, but it still does not '
              'belong on a snapshot',
        );
        expect(
          rendered,
          isNot(contains(keypair.fingerprint)),
          reason:
              'this deploy key\'s own public-key fingerprint must not ride '
              'out on the object it fetched',
        );
        expect(rendered, isNot(contains('identity')));
      },
    );

    test('removes the tree it created, on the success path', () async {
      _writeStub(bin, 'ssh-keyscan', '#!/bin/sh\necho "$hostKeyLine"\n');
      _writeStub(bin, 'git', _gitStub(report: report, revision: revision));
      PosixFileModes.applyStrict(bin.path, '755');

      final snapshot =
          await SshPinnedSnapshotMaterializer(
            pathPrefix: bin.path,
            scratchPrefix: _scratchPrefix,
          ).materialize(
            productId: 'product-a',
            repositoryId: 'repo',
            remote: remote(),
            privateKeyPem: SecretBytes(keypair.privateKeyPemBytes),
            confirmedHostKeyFingerprint: hostKeyFingerprint,
            pinnedRevision: revision,
          );
      // Released again at teardown even though the assertions below release it:
      // `release` is idempotent by construction, and an assertion that throws
      // first would otherwise leave the tree on disk and trip the leak check in
      // every test that ran after this one.
      addTearDown(snapshot.release);
      final root = snapshot.root.path;

      expect(Directory(root).existsSync(), isTrue);
      snapshot.release();
      expect(
        Directory(root).existsSync(),
        isFalse,
        reason:
            'a checkout holding private material in transit outliving its '
            'release is the leak this class is written against',
      );
    });

    test(
      'refuses when the host presents no key matching the confirmation',
      () async {
        // The A2 distinction is unchanged by this fix and is checked here so a
        // future change to the clone sequence cannot quietly relax it: an empty
        // scan is a refusal, never a fallback, and nothing is spawned.
        _writeStub(bin, 'ssh-keyscan', '#!/bin/sh\nexit 0\n');
        _writeStub(bin, 'git', _gitStub(report: report, revision: revision));
        PosixFileModes.applyStrict(bin.path, '755');

        await expectLater(
          SshPinnedSnapshotMaterializer(
            pathPrefix: bin.path,
            scratchPrefix: _scratchPrefix,
          ).materialize(
            productId: 'product-a',
            repositoryId: 'repo',
            remote: remote(),
            privateKeyPem: SecretBytes(keypair.privateKeyPemBytes),
            confirmedHostKeyFingerprint: hostKeyFingerprint,
            pinnedRevision: revision,
          ),
          throwsA(isA<HostKeyNotIndependentlyConfirmedException>()),
        );
        expect(
          _readInvocations(report),
          isEmpty,
          reason: 'no clone may be attempted against a host nothing confirmed',
        );
      },
    );
  });
}
