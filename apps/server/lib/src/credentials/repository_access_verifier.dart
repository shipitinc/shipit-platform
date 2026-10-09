import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'posix_file_permissions.dart';
import 'secret_material.dart';
import 'secretless_error.dart';
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
/// Never suppressed, and thrown on **every** path — the success path included.
/// That consistency is the point: an earlier version returned
/// `secretMaterialRemoved: false` on success and threw only on failure, so the
/// class's own claim ("a leftover private half is an exception rather than a log
/// line") was true on one path and false on the other. One rule, no branch: a
/// private half this process could not remove is always an exception.
///
/// It carries the path an operator needs in order to remove it, and no key
/// material — it is [AuditedFailure], so [secretlessText] renders its own fields.
class ScratchCleanupException implements Exception, AuditedFailure {
  ScratchCleanupException(this.scratchPath);

  final String scratchPath;

  @override
  String get secretlessDescription =>
      'ScratchCleanupException: the directory holding this verification\'s '
      'private identity file could not be removed. Remove $scratchPath. This is '
      'an incident, not a warning: a repository deploy-key private half may '
      'still be readable on this host.';

  @override
  String toString() => secretlessDescription;
}

/// Raised when a helper this verifier spawned outlived its timeout.
///
/// M-3. `Future.timeout` stops *waiting*; it does not terminate a process. On
/// the clone path that left a live `git` — and the `ssh` it had forked — running
/// with the identity file open and still able to authenticate with it, after the
/// method had already thrown. The scratch tree was deleted, so the path was gone;
/// the *credential* was not. This is a typed, audited failure so the operator is
/// told the process was killed rather than left guessing.
class AccessVerificationTimeoutException implements Exception, AuditedFailure {
  AccessVerificationTimeoutException({
    required this.helper,
    required this.limit,
    required this.killedProcessIds,
  });

  /// `git`, `ssh-keyscan` or `ssh-keygen`.
  final String helper;

  /// The ceiling that was exceeded.
  final Duration limit;

  /// The process tree that was signalled before the failure was raised.
  ///
  /// Named, not counted, because the count alone would not let an operator check
  /// that nothing survived. A `ProcessId` renders as a number.
  final List<int> killedProcessIds;

  @override
  String get secretlessDescription =>
      'AccessVerificationTimeoutException: $helper did not finish within '
      '${limit.inSeconds}s and its process tree was killed '
      '(pids: ${killedProcessIds.join(' ')}); the identity file was removed '
      'afterwards and this credential was NOT marked verified';

  @override
  String toString() => secretlessDescription;
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
class HostKeyNotPresentedException implements Exception, AuditedFailure {
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

  // A host key is PUBLIC — it is published in the clear by the host, and
  // `ssh-keyscan` is how everyone collects it — so a fingerprint in this message
  // is not key material under ADR 0018 §A2.
  @override
  String get secretlessDescription =>
      'HostKeyNotPresentedException($host:$port — confirmed '
      '$confirmedFingerprint, presented '
      '${presentedFingerprints.isEmpty ? '<nothing>' : presentedFingerprints.join(', ')})';

  @override
  String toString() => secretlessDescription;
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
  /// WHAT [confirmedHostKeyFingerprint] IS, PLAINLY, because it is M-5 and a
  /// reader must not have to infer it. It is the value **the caller asserted**.
  /// This class does obtain the host's real key independently — via
  /// `ssh-keyscan` and `ssh-keygen -lf` — and it refuses to clone unless the
  /// fingerprint of the key the host presented equals what the caller supplied.
  /// What it cannot do is establish *where that value came from*: a caller that
  /// scanned the network itself and supplied an attacker's key gets a clone
  /// against the attacker, and this method enforces it faithfully.
  ///
  /// So the honest description is: this is a **transport enforcer for an
  /// operator-asserted trust decision**. It is a real improvement on ADR 0018
  /// §Accepted risks (A2) — the domain recorded the confirmation as data while
  /// the connection itself was unverified — but it narrows that gap rather than
  /// closing it, because the provenance of the confirmed value is unchanged.
  /// `CredentialKeyService.verifyAccess` is where that provenance is labelled on
  /// the wire; this doc is the other half of that label, for a reader of the
  /// code rather than of a response.
  ///
  /// Returns an outcome for a clone that ran and failed — a failed clone is a
  /// result, and the caller records it as `CredentialStatus.failing` with the
  /// reason. Throws [HostKeyNotPresentedException] for a host mismatch, because
  /// that is a refusal rather than an outcome: ADR 0018 requires the connection
  /// not to be attempted at all. Throws [AccessVerificationTimeoutException] if a
  /// helper outlives its ceiling, after its process tree has been killed. Throws
  /// [ScratchCleanupException] on **any** path if the scratch tree could not be
  /// removed, because that outranks whatever else happened.
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
      // Cleanup on the success path too, and the verdict is the same as on the
      // failure path: a tree this process could not remove is an incident, not a
      // result. Previously this returned `secretMaterialRemoved: false` and left
      // the caller to decide, which meant the same fact was an exception on one
      // path and a return value on the other.
      if (!_destroy(scratch)) throw ScratchCleanupException(scratch.path);
      return outcome.copyWith(secretMaterialRemoved: true);
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

    // L-2: the host key is confirmed BEFORE the private half is written.
    //
    // The order used to be write-then-scan, which put key material on disk for a
    // call that was about to refuse. Bounded (a 0700 directory removed in the same
    // call) but pointless, and the window is free to close.
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

    // The one write of private key material to disk in the whole subsystem.
    PosixFileModes.writeOwnerOnlyFile(identityPath, privateKeyPem.bytes);

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
      // Bounded for the same reason the clone is: an `ssh-keyscan` left running
      // after the method gave up is a process this code spawned and abandoned.
      result = await _runBounded(
        helper: 'ssh-keyscan',
        executable: 'ssh-keyscan',
        arguments: [
          '-p',
          '${remote.port}',
          // No `-t` filter: narrowing the list would silently ignore a host whose
          // key type was not anticipated, and an ignored host key is an unchecked
          // host key. An empty result is handled as a refusal, further down.
          remote.host,
        ],
        timeout: connectTimeout,
        environment: _helperEnvironment,
      );
    } on AccessVerificationTimeoutException {
      // No host key to compare a confirmation against, which is a refusal. The
      // timeout is reported as a refusal rather than thrown because that is the
      // contract this method already has for "ssh-keyscan gave us nothing".
      return const {};
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
    final stdoutText = process.stdout.transform(utf8.decoder).join();
    // Bounded and killed on timeout, like every other helper here. A `ssh-keygen`
    // waiting for more stdin than this method will ever write would otherwise hang
    // `verify` for ever — a credential service that never answers.
    try {
      await process.stdin.done.timeout(connectTimeout);
      await stdoutText.timeout(connectTimeout);
      final code = await process.exitCode.timeout(connectTimeout);
      if (code != 0) return null;
    } on TimeoutException {
      _killTree(process);
      return null;
    }
    return RegExp(
      r'SHA256:[A-Za-z0-9+/]+=*',
    ).firstMatch(await stdoutText)?.group(0);
  }

  /// Kills [process] and every descendant it can still find.
  ///
  /// The counterpart of [_runBounded]'s inline tree walk, factored out for the one
  /// call site that owns its [Process] because it writes to stdin.
  void _killTree(Process process) {
    final tree = _descendantPids(process.pid);
    process.kill(ProcessSignal.sigkill);
    for (final pid in tree.reversed) {
      _signalPid(pid);
    }
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
    return _runBounded(
      helper: 'git',
      executable: gitExecutable,
      arguments: [
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
      timeout: cloneTimeout,
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
    );
  }

  /// Runs a helper to completion, or kills its whole process tree and refuses.
  ///
  /// THE BUG THIS REPLACES. `Process.run(...).timeout(ceiling)` is a `Future`
  /// timeout: it stops the *Dart* side from waiting, and nothing more. The child
  /// keeps running, and for a clone that is not a leaked CPU — it is a live
  /// `git` with a live `ssh` child, both holding the identity file, both still
  /// able to authenticate with it, while the caller has already been told the
  /// verification failed and has deleted the scratch tree. `Future.timeout` is
  /// the wrong tool for a subprocess, and the honest fix is to own the
  /// [Process].
  ///
  /// WHY THE WHOLE TREE AND NOT JUST THE CHILD. Dart has no API to place a child
  /// in a new process group (and macOS has no `setsid`), so `kill` reaches only
  /// the process this code started — for `git clone` that is the parent of the
  /// `ssh` that actually holds the identity. The descendants are therefore
  /// enumerated from `ps` **before** the parent is signalled, then signalled
  /// themselves; signalling the parent first would re-parent the children to `init`
  /// and lose them. Signalling `SIGKILL` rather than `SIGTERM` because a `git`
  /// blocked in a network read does not install a handler and must not be given
  /// the chance to.
  Future<ProcessResult> _runBounded({
    required String helper,
    required String executable,
    required List<String> arguments,
    required Duration timeout,
    Map<String, String>? environment,
  }) async {
    final Process process;
    try {
      process = await Process.start(
        executable,
        arguments,
        environment: environment,
      );
    } on Object catch (error) {
      // Absent binary, or a `PATH`/`PATH`-prefix problem. `Process.start` raises
      // `ProcessException`, whose audited projection is the executable and the OS
      // message — no key material, and `arguments` is never read.
      throw ProcessException(
        executable,
        arguments,
        secretlessText(error),
        error is ProcessException ? error.errorCode : 0,
      );
    }

    final stdoutText = process.stdout.transform(utf8.decoder).join();
    final stderrText = process.stderr.transform(utf8.decoder).join();
    final exit = process.exitCode;

    try {
      final code = await exit.timeout(timeout);
      return ProcessResult(
        process.pid,
        code,
        await stdoutText,
        await stderrText,
      );
    } on TimeoutException {
      // Enumerate first, then signal. See the method note: this order is the
      // whole reason the children are still findable.
      final tree = _descendantPids(process.pid);
      final killed = <int>[process.pid, ...tree.reversed];
      process.kill(ProcessSignal.sigkill);
      for (final pid in tree.reversed) {
        _signalPid(pid);
      }
      // Drain so the pipes do not keep the isolate alive, and bound the wait so a
      // child that ignores the signal cannot hold the caller.
      await exit
          .timeout(const Duration(seconds: 5))
          .catchError((Object _) => -1);
      unawaited(stdoutText.catchError((Object _) => ''));
      unawaited(stderrText.catchError((Object _) => ''));
      throw AccessVerificationTimeoutException(
        helper: helper,
        limit: timeout,
        killedProcessIds: killed,
      );
    }
  }

  /// Every live descendant of [rootPid], deepest last.
  ///
  /// Read from `ps` rather than tracked, because the processes that matter here
  /// are created by `git`, not by this code. Empty when `ps` cannot answer — a
  /// missing answer degrades to killing the direct child, which is the best that
  /// can be done rather than a reason to skip the kill.
  ///
  /// `ps` is resolved through [pathPrefix] like every other helper, for the same
  /// reason `git` is: this runs while the private half is on disk, so it is not
  /// a moment to start trusting an ambient `PATH`.
  List<int> _descendantPids(int rootPid) {
    final result = Process.runSync(
      'ps',
      ['-A', '-o', 'pid=,ppid='],
      environment: _helperEnvironment,
    );
    if (result.exitCode != 0) return const [];
    final children = <int, List<int>>{};
    for (final line in (result.stdout as String).split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length != 2) continue;
      final pid = int.tryParse(parts[0]);
      final ppid = int.tryParse(parts[1]);
      if (pid == null || ppid == null) continue;
      children.putIfAbsent(ppid, () => <int>[]).add(pid);
    }
    final found = <int>[];
    final queue = <int>[...?(children[rootPid])];
    while (queue.isNotEmpty) {
      final pid = queue.removeAt(0);
      if (found.contains(pid)) continue;
      found.add(pid);
      queue.addAll(children[pid] ?? const <int>[]);
    }
    return found;
  }

  /// Signals one pid, ignoring the fact that it may already be gone.
  ///
  /// Deliberately not `Process.killPid`: that throws `ProcessException` when the
  /// pid has already exited, and a pid that exited on its own between the `ps`
  /// read and this call is the normal case, not an error.
  void _signalPid(int pid) {
    try {
      Process.killPid(pid, ProcessSignal.sigkill);
    } on Object {
      // Already gone, or not ours to signal. Either way there is nothing to do.
    }
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
