import 'dart:convert';
import 'dart:io';

import 'posix_file_permissions.dart';
import 'secret_material.dart';
import 'ssh_remote.dart';

/// Separator between `PATH` entries.
const String _pathListSeparator = ':';

/// What a real clone attempt concluded.
///
/// [secretMaterialRemoved] is the field that carries the guarantee. It is not a
/// claim the caller is asked to take on trust: the verifier deletes its scratch
/// directory and then *checks* that it is gone, on every path — including every
/// failure path — and reports the result here. A verifier that could not remove
/// the identity file says so in its own result rather than staying quiet,
/// because "the clone failed" and "the clone failed and a private key may still
/// be on this disk" are different facts and an operator needs the second one.
class AccessProbeOutcome {
  AccessProbeOutcome({
    required this.succeeded,
    required this.secretMaterialRemoved,
    this.failureReason,
    this.observedHostKeyFingerprint,
    this.committedRevision,
  });

  /// Whether the clone completed.
  final bool succeeded;

  /// Whether the scratch directory holding the identity file is confirmed gone.
  final bool secretMaterialRemoved;

  /// Why the clone failed. Safe to persist on the credential row and to show an
  /// operator: it is git/ssh's own diagnostic with the scratch path replaced and
  /// truncated, and it never contains key material.
  final String? failureReason;

  /// The host key fingerprint that was presented and matched the confirmation.
  final String? observedHostKeyFingerprint;

  /// Commit the clone checked out, when it succeeded. Evidence that a real clone
  /// happened rather than a handshake merely being attempted.
  final String? committedRevision;

  AccessProbeOutcome copyWith({
    bool? secretMaterialRemoved,
    String? failureReason,
  }) => AccessProbeOutcome(
    succeeded: succeeded,
    secretMaterialRemoved: secretMaterialRemoved ?? this.secretMaterialRemoved,
    failureReason: failureReason ?? this.failureReason,
    observedHostKeyFingerprint: observedHostKeyFingerprint,
    committedRevision: committedRevision,
  );

  @override
  String toString() =>
      'AccessProbeOutcome(succeeded: $succeeded, '
      'secretMaterialRemoved: $secretMaterialRemoved, '
      'failureReason: $failureReason)';
}

/// Raised when the scratch tree holding the identity file could not be removed.
///
/// Never suppressed. A leftover private half is a security event, so it is an
/// exception rather than a log line, and it carries the path an operator needs
/// in order to remove it. It carries no key material.
class ScratchCleanupException implements Exception {
  ScratchCleanupException(this.scratchPath);

  final String scratchPath;

  @override
  String toString() =>
      'ScratchCleanupException: the directory holding this verification\'s '
      'private identity file could not be removed. Remove $scratchPath. This is '
      'an incident, not a warning: a repository deploy-key private half may '
      'still be readable on this host.';
}

/// Raised when the host does not present the key the operator confirmed.
///
/// DELIBERATELY NOT NAMED `HostKeyNotConfirmedException`, which already exists
/// in `product_registry` and means the opposite side of the same clause: the
/// domain refusing to *record* a connectivity check for an unconfirmed host.
/// This one is the *transport* refusing to *connect*. ADR 0018 §Accepted risks
/// (A2) records that the domain enforcer existed while the transport enforcer did
/// not, so the two are genuinely different failures and must not share a name.
///
/// ADR 0018 §Decision: "ShipIt refuses to connect to an unrecognised host. The
/// operator is shown the host, key type and fingerprint and must confirm it."
/// The domain half of that clause already exists — `confirmHostKey` refuses a
/// changed fingerprint — but ADR 0018 §Accepted risks (A2) records, and this is
/// the gap it names, that nothing enforced it **at the transport**: the human
/// confirmation was recorded as data and honoured by the domain, while the
/// connection itself was unverified.
///
/// This class is that missing enforcer, for this seam. The verifier obtains the
/// host's real key, compares its fingerprint with the one a human confirmed, and
/// refuses to clone on any mismatch. `StrictHostKeyChecking=yes` plus a
/// one-line `known_hosts` built from the matched key then makes OpenSSH enforce
/// the same fact independently for the connection itself, so a connection to any
/// *other* host — a rewritten remote, a DNS answer that changed mid-run — fails at
/// the socket rather than being recorded afterwards.
class HostKeyNotPresentedException implements Exception {
  HostKeyNotPresentedException({
    required this.host,
    required this.port,
    required this.confirmedFingerprint,
    this.presentedFingerprints = const [],
  });

  final String host;
  final int port;

  /// What the human confirmed.
  final String confirmedFingerprint;

  /// What the host actually presented, so the operator can compare.
  final List<String> presentedFingerprints;

  @override
  String toString() =>
      'HostKeyNotPresentedException($host:$port — confirmed '
      '$confirmedFingerprint, presented '
      '${presentedFingerprints.isEmpty ? '<nothing>' : presentedFingerprints.join(', ')})';
}

/// Performs a real SSH clone of a repository with a generated deploy key.
///
/// THE TRANSPORT CHOICE, and why it is not a pure-Dart SSH library.
///
/// The two options were: shell out to `git` with `GIT_SSH_COMMAND` and a
/// transient identity file, or add an in-process SSH client. `git` was chosen,
///
///   * because "a real clone" is the claim ADR 0018 §Decision makes — "a
///     connectivity check has succeeded against the real host with the real key"
///     — and `git-upload-pack` over OpenSSH is that, not a reimplementation of
///     it. An in-process client would open the same TCP and SSH session but would
///     run git's wire protocol on a hand-rolled transport, which is a weaker
///     claim than the one being made here.
///   * because an in-process SSH client is a large dependency — `ssh2` brings
///     `pointycastle`, `typed_data` and an event-loop-shaped API — and would need
///     its own host-key store to be worth using at all. This dispatch asks for a
///     minimal dependency count on a security boundary, and OpenSSH is already
///     installed and already audited everywhere this runs.
///   * and because the alternative does not actually remove the exposure it
///     appears to: the private half would still be in process memory, so the
///     marginal gain is "no 0600 file", not "no key in memory".
///
/// WHAT THAT COSTS, taken seriously. The identity file is private key material
/// on disk for the duration of one clone. So:
///
///   * it is written into a `createTemp` directory that is `0700`, and the file
///     itself `0600`, both set and then **verified** by [PosixFileModes];
///   * it is never logged, never in an argv, never in an environment variable,
///     never in an exception message, and never in the returned outcome;
///   * the whole scratch tree is deleted on every path, and its absence is then
///     checked and reported as [AccessProbeOutcome.secretMaterialRemoved];
///   * `HOME`, `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_SYSTEM` are redirected at the
///     scratch tree, so a developer's `~/.ssh/config` — which could add an
///     `IdentityFile`, a `ProxyCommand` or a `RemoteCommand` that ships our
///     identity elsewhere — and any ambient `url.*.insteadOf` rewrite get no
///     say in this clone;
///   * `BatchMode=yes`, `IdentitiesOnly=yes`, `IdentityAgent=none`, and both
///     `PasswordAuthentication` and `KbdInteractiveAuthentication` off, so the
///     clone can never fall back to a passphrase prompt, an interactive
///     challenge, or an agent holding some other identity. An unattended server
///     blocking on a prompt is a credential service that has hung.
class RepositoryAccessVerifier {
  const RepositoryAccessVerifier({
    this.connectTimeout = const Duration(seconds: 20),
    this.cloneTimeout = const Duration(minutes: 3),
    this.scratchPrefix = 'shipit_credential_verify_',
    this.diagnosticLimit = 500,
    this.gitExecutable = 'git',
    this.pathPrefix,
  });

  /// Per-connection SSH timeout, also passed to `ssh -o ConnectTimeout`.
  final Duration connectTimeout;

  /// Whole-clone ceiling.
  final Duration cloneTimeout;

  /// Prefix of the temporary directory, which is what a test asserts is absent.
  final String scratchPrefix;

  /// Maximum characters of git/ssh diagnostic retained in
  /// [AccessProbeOutcome.failureReason].
  final int diagnosticLimit;

  /// The `git` to clone with.
  ///
  /// A bare name is resolved through `PATH`, and on a host where an unprivileged
  /// process can write to any directory earlier in `PATH`, that is an
  /// arbitrary-code-execution hole in a process that handles a private deploy
  /// key. Pinning an absolute path closes it. Configurable because the correct
  /// path is deployment-specific (`/usr/bin/git` on a Debian image,
  /// `/usr/local/bin/git` on a macOS toolchain) and must not be guessed here.
  final String gitExecutable;

  /// Prepended to `PATH` for every helper this verifier spawns — `git`,
  /// `ssh-keyscan`, `ssh-keygen`, and the `ssh` the wrapper script execs.
  ///
  /// Null keeps the ambient `PATH`. Set it to pin the whole helper toolchain at
  /// once; [gitExecutable] is the belt to this braces.
  final String? pathPrefix;

  /// Clones [remote] using [privateKeyPem], refusing any host that does not
  /// present [confirmedHostKeyFingerprint].
  ///
  /// Returns an outcome for a clone that ran and failed — a failed clone is a
  /// result, and the caller records it as `CredentialStatus.failing` with the
  /// reason. Throws [HostKeyNotPresentedException] for a host mismatch, because
  /// that is a refusal rather than an outcome: ADR 0018 requires the connection
  /// not to be attempted at all. Throws [ScratchCleanupException] if the scratch
  /// tree could not be removed, because that outranks whatever else happened.
  Future<AccessProbeOutcome> verify({
    required SshRemote remote,
    required SecretBytes privateKeyPem,
    required String confirmedHostKeyFingerprint,
  }) async {
    final scratch = Directory.systemTemp.createTempSync(scratchPrefix);
    try {
      final outcome = await _probe(
        scratch,
        remote,
        privateKeyPem,
        confirmedHostKeyFingerprint,
      );
      // Success path: the verdict travels with the result rather than replacing
      // it, because "the clone worked" is still worth telling the operator even
      // when a file is left behind. The key service refuses to record a
      // credential as verified while this flag is false, so a leftover cannot be
      // laundered into a good status.
      final removed = _destroy(scratch);
      return outcome.copyWith(
        secretMaterialRemoved: removed,
        failureReason: removed ? outcome.failureReason : outcome.failureReason,
      );
    } on Object {
      // Failure path: destroy first, then decide what to throw. A cleanup
      // failure outranks the original error, because it is the one that leaves
      // key material behind — and the operator needs that path more than the
      // host-key mismatch that led here.
      if (!_destroy(scratch)) throw ScratchCleanupException(scratch.path);
      rethrow;
    }
  }

  /// Everything that touches the key, given a scratch directory to work in.
  ///
  /// Split from [verify] so the cleanup lives in one place on both the success
  /// and failure paths. A Dart `finally` runs *after* the return expression is
  /// evaluated, so it cannot amend the [AccessProbeOutcome] about to be handed
  /// back; this shape can.
  Future<AccessProbeOutcome> _probe(
    Directory scratch,
    SshRemote remote,
    SecretBytes privateKeyPem,
    String confirmedHostKeyFingerprint,
  ) async {
    PosixFileModes.applyStrict(scratch.path, PosixFileModes.directory);
    final identityPath = '${scratch.path}/identity';
    final knownHostsPath = '${scratch.path}/known_hosts';
    final wrapperPath = '${scratch.path}/ssh-wrapper.sh';
    final clonePath = '${scratch.path}/clone';

    // The one write of private key material to disk in the whole subsystem.
    PosixFileModes.writeOwnerOnlyFile(identityPath, privateKeyPem.bytes);

    final presented = await _scanHostKeys(remote);
    final matched = presented.entries
        .where((entry) => entry.value == confirmedHostKeyFingerprint)
        .map((entry) => entry.key)
        .toList();
    if (matched.isEmpty) {
      throw HostKeyNotPresentedException(
        host: remote.host,
        port: remote.port,
        confirmedFingerprint: confirmedHostKeyFingerprint,
        presentedFingerprints: presented.values.toList(),
      );
    }
    // Only the confirmed key. The alternative — writing everything
    // `ssh-keyscan` returned — would let the clone succeed against a second key
    // the operator never saw.
    PosixFileModes.writeOwnerOnlyFile(
      knownHostsPath,
      '${matched.join('\n')}\n'.codeUnits,
    );
    PosixFileModes.writeOwnerOnlyFile(
      wrapperPath,
      _sshWrapper(
        identityPath: identityPath,
        knownHostsPath: knownHostsPath,
        port: remote.port,
      ).codeUnits,
    );
    PosixFileModes.applyStrict(wrapperPath, '700');

    final clone = await _runGitClone(
      remote: remote,
      wrapperPath: wrapperPath,
      clonePath: clonePath,
      scratchPath: scratch.path,
    );
    final succeeded = clone.exitCode == 0 && Directory(clonePath).existsSync();

    return AccessProbeOutcome(
      succeeded: succeeded,
      secretMaterialRemoved: false, // replaced by the caller from its own check
      failureReason: succeeded
          ? null
          : _sanitise((clone.stderr as String).toString(), scratch.path),
      observedHostKeyFingerprint: confirmedHostKeyFingerprint,
      committedRevision: succeeded
          ? _gitOutput(['-C', clonePath, 'rev-parse', 'HEAD'])
          : null,
    );
  }

  /// Deletes the scratch tree and confirms it is gone.
  ///
  /// Retries once: a clone killed mid-write can leave an entry that disappears on
  /// the next pass, and a first `deleteSync` on a tree that changed underneath
  /// it throws. What is not tolerated is a tree that is still there afterwards —
  /// that is reported as `false`, and the caller refuses to record a verified
  /// credential.
  bool _destroy(Directory scratch) {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        if (scratch.existsSync()) scratch.deleteSync(recursive: true);
      } on Object {
        // The existence check below is the real verdict; an exception here is
        // just a reason to try again.
      }
      if (!scratch.existsSync()) return true;
    }
    return false;
  }

  /// Reads the host's presented keys and their fingerprints.
  ///
  /// The fingerprint is computed by `ssh-keygen -lf`, not here. Reimplementing it
  /// would mean SHA-256 over an SSH wire blob for ed25519 and SHA-1 over MD5 for
  /// RSA, and a fingerprint that disagrees with the host's own UI by one
  /// character fails every legitimate verification while passing every
  /// illegitimate one. OpenSSH has this code already and is what the operator
  /// compares against.
  Future<Map<String, String>> _scanHostKeys(SshRemote remote) async {
    final ProcessResult result;
    try {
      result = await Process.run('ssh-keyscan', [
        '-p',
        '${remote.port}',
        // No `-t` filter: narrowing the list would silently ignore a host whose
        // key type was not anticipated, and an ignored host key is an unchecked
        // host key. An empty result is handled as a refusal, further down.
        remote.host,
      ], environment: _helperEnvironment).timeout(connectTimeout);
    } on Object {
      // Unreachable, or `ssh-keyscan` absent. Either way there is no host key to
      // compare a confirmation against, which is a refusal.
      return const {};
    }

    final presented = <String, String>{};
    for (final line in (result.stdout as String).split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final fingerprint = await _sshKeygenFingerprint(trimmed);
      if (fingerprint != null) presented[trimmed] = fingerprint;
    }
    return presented;
  }

  /// `ssh-keygen -lf -` for one authorized-keys line, or null.
  ///
  /// `Process.runSync` cannot write stdin, and the alternative — giving
  /// `ssh-keygen` a path — means writing a file per candidate host key into the
  /// scratch tree that has to be cleaned up afterwards. `Process.start` streams
  /// the line straight in and leaves nothing behind.
  Future<String?> _sshKeygenFingerprint(String keyLine) async {
    final Process process;
    try {
      process = await Process.start('ssh-keygen', [
        '-lf',
        '-',
      ], environment: _helperEnvironment);
    } on Object {
      return null;
    }
    // The trailing newline is load-bearing: `ssh-keygen -lf -` reads a *line*, and
    // an unterminated write leaves it waiting for more input rather than
    // reporting the key it already has.
    process.stdin.write('$keyLine\n');
    await process.stdin.flush();
    await process.stdin.close();
    final stdoutText = await process.stdout.transform(utf8.decoder).join();
    await process.stdin.done;
    final code = await process.exitCode;
    if (code != 0) return null;
    return RegExp(
      r'SHA256:[A-Za-z0-9+/]+=*',
    ).firstMatch(stdoutText)?.group(0);
  }

  /// Environment applied to every bare-name helper this class spawns.
  Map<String, String>? get _helperEnvironment =>
      pathPrefix == null ? null : _helperPath;

  Map<String, String>? get _helperPath =>
      pathPrefix == null ? null : {'PATH': _pinnedPath};

  /// `PATH` with [pathPrefix] in front of the ambient value.
  ///
  /// Note the separator is the PATH *list* separator (`:`), not
  /// [Platform.pathSeparator] — which is `/` on POSIX and is the wrong character
  /// entirely. Joining with the wrong one does not fail loudly: it produces a
  /// single nonsense entry, the pinned directory silently stops taking effect,
  /// and the real helper on `PATH` is found instead. That failure mode — a
  /// security control quietly not applying — is why this is a named getter with
  /// the reasoning attached rather than an inline template.
  String get _pinnedPath =>
      '$pathPrefix$_pathListSeparator${Platform.environment['PATH'] ?? ''}';

  /// The `ssh` invocation `git` is pointed at, as a standalone script.
  ///
  /// A script rather than an inline `GIT_SSH_COMMAND` string: git hands that
  /// string to a shell, so inline options would need quoting for two filesystem
  /// paths under the system temp directory, and a quoting bug there is a
  /// path-shaped bug. A script has no quoting problem to get wrong. It contains
  /// no secret — only two scratch paths and a port.
  String _sshWrapper({
    required String identityPath,
    required String knownHostsPath,
    required int port,
  }) {
    return '''
#!/bin/sh
# Generated by RepositoryAccessVerifier. Holds no key material: the identity it
# names lives beside this script in a 0700 directory that is removed when the
# clone returns, on success and on failure alike.
exec ssh \\
  -i ${_shellQuote(identityPath)} \\
  -o IdentitiesOnly=yes \\
  -o IdentityAgent=none \\
  -o BatchMode=yes \\
  -o PasswordAuthentication=no \\
  -o KbdInteractiveAuthentication=no \\
  -o StrictHostKeyChecking=yes \\
  -o UserKnownHostsFile=${_shellQuote(knownHostsPath)} \\
  -o GlobalKnownHostsFile=/dev/null \\
  -o ConnectTimeout=${connectTimeout.inSeconds} \\
  -p $port \\
  "\$@"
''';
  }

  Future<ProcessResult> _runGitClone({
    required SshRemote remote,
    required String wrapperPath,
    required String clonePath,
    required String scratchPath,
  }) {
    return Process.run(
      gitExecutable,
      [
        '--no-pager',
        'clone',
        '--depth',
        '1',
        '--no-tags',
        '--quiet',
        '--',
        remote.toSshUrl(),
        clonePath,
      ],
      environment: {
        'GIT_SSH_COMMAND': wrapperPath,
        'GIT_SSH_VARIANT': 'ssh',
        // Nothing in this call may block on a human. A credential service waiting
        // on a passphrase prompt holds the private half in memory for as long as
        // the prompt is up.
        'GIT_TERMINAL_PROMPT': '0',
        'GIT_ASKPASS': '',
        // Redirect the ambient environment at the scratch tree. A developer's
        // ~/.ssh/config can add IdentityFile, ProxyCommand, RemoteCommand or Match
        // rules; a system or global gitconfig can add url.*.insteadOf. None of them
        // gets a say in this clone.
        'HOME': scratchPath,
        'GIT_CONFIG_GLOBAL': '/dev/null',
        'GIT_CONFIG_SYSTEM': '/dev/null',
        if (pathPrefix != null) 'PATH': _pinnedPath,
      },
    ).timeout(cloneTimeout);
  }

  String? _gitOutput(List<String> args) {
    final result = Process.runSync(
      gitExecutable,
      args,
      environment: _helperEnvironment,
    );
    if (result.exitCode != 0) return null;
    final value = (result.stdout as String).trim();
    return value.isEmpty ? null : value;
  }

  /// Reduces a git/ssh diagnostic to something safe to persist and display.
  ///
  /// git's stderr cannot contain key material — OpenSSH never echoes an identity
  /// file — but it does contain the scratch path, which is noise to an operator
  /// and a small hint about this host's temp layout. The path is replaced and
  /// the diagnostic truncated, so [AccessProbeOutcome.failureReason] can go
  /// straight onto `RepositoryCredential.lastFailureReason` and into the UI.
  String _sanitise(String stderr, String scratchPath) {
    final cleaned = stderr.replaceAll(scratchPath, '<scratch>').trim();
    if (cleaned.isEmpty) return 'git clone failed without a diagnostic';
    return cleaned.length <= diagnosticLimit
        ? cleaned
        : '${cleaned.substring(0, diagnosticLimit)}…';
  }

  /// Single-quotes a value for `/bin/sh`.
  String _shellQuote(String value) => "'${value.replaceAll("'", r"'\''")}'";
}
