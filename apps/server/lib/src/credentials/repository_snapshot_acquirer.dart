// `RepositorySnapshot`'s constructor assigns `_root` and `_onRelease` through
// initializers rather than `this._root` / `this._onRelease`: on a class whose
// constructor is private, private-named formals would read as public named
// parameters at every call site, which is a worse trade than this lint.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:product_registry/product_registry.dart';

import 'credential_key_service.dart';
import 'posix_file_permissions.dart';
import 'secret_material.dart';
import 'ssh_remote.dart';

/// Raised when a product's repository cannot be acquired, and the reason is
/// something outside this process.
///
/// ## `unavailable` means unavailable, not "somebody said no"
///
/// The same honesty [lane_e_design_remediation_work_item.dart] states for
/// `designGovernanceRuntimeUnavailable` applies here, and the wording matters
/// because the two are easy to confuse. `unavailable` means **no usable,
/// host-confirmed credential is registered for this repository**. It does not
/// mean an operator refused to run anything, and a product in this state must
/// never be presented as one that failed onboarding: the product stays where it
/// is, no gate opens, and the reason is visible on the job.
///
/// ## It is not used for a runtime that is merely absent from this file
///
/// Baseline derivation and verification runtimes DO exist
/// (`ReadOnlyRepositoryReader`, `MaturityClassifier`,
/// `ProductRegistryEngine`). Recording an external dependency for something
/// that is present would be the dishonest-terminal-state defect in a new place.
class BaselineSourceUnavailableException implements Exception {
  const BaselineSourceUnavailableException({
    required this.productId,
    required this.repositoryId,
    required this.reason,
  });

  final String productId;
  final String repositoryId;

  /// What is missing. Operator-facing; carries no credential material and no
  /// fingerprint.
  final String reason;

  /// The recorded terminal reason. Stable enough to compare in a test and to
  /// grep for in a log.
  static const String terminalCode = 'EXTERNAL_BASELINE_SOURCE_DEPENDENCY';

  @override
  String toString() =>
      '$terminalCode: cannot acquire a snapshot for $repositoryId '
      '(product $productId) — $reason';
}

/// Raised when the value offered as a host-key fingerprint is not one.
///
/// ## Why this is its own refusal and not a coercion
///
/// A deploy key's `SHA256:…` fingerprint is the fingerprint of the
/// **credential's public key**. A host key fingerprint is the fingerprint of the
/// **remote host's** key. They are different values with different provenance,
/// and `RepositoryAccessVerifier.verify` requires the second one
/// (`confirmedHostKeyFingerprint`) — a value whose provenance is a human
/// confirming it out of band.
///
/// Passing the credential's fingerprint where the host key's belongs would make
/// a check that can never succeed look like a check that passed, and the failure
/// it prevents is invisible: the clone is refused, the reason says "host did not
/// present the confirmed key", and the reader concludes the host rotated. So
/// the acquirer refuses the confused value up front and names the confusion.
///
/// There is deliberately **no** `ssh-keyscan`-and-trust-the-result fallback. The
/// scan is not the problem — `RepositoryAccessVerifier` already performs one and
/// compares it. The problem is *provenance*: a value obtained by scanning the
/// network at acquisition time was obtained from whatever answered, which is
/// exactly the gap ADR 0018 recorded as accepted risk A2. Reintroducing it here
/// would close nothing and would claim the gap was closed.
class HostKeyNotIndependentlyConfirmedException implements Exception {
  const HostKeyNotIndependentlyConfirmedException({
    required this.productId,
    required this.repositoryId,
    required this.reason,
  });

  final String productId;
  final String repositoryId;
  final String reason;

  @override
  String toString() =>
      'Host key for $repositoryId (product $productId) is not independently '
      'confirmed — $reason. No key scan was trusted as a substitute, and no '
      'fallback was attempted.';
}

/// Raised when the acquired snapshot is not the revision that was pinned.
class PinnedRevisionNotAcquiredException implements Exception {
  const PinnedRevisionNotAcquiredException({
    required this.productId,
    required this.repositoryId,
    required this.pinnedRevision,
    required this.observedRevision,
  });

  final String productId;
  final String repositoryId;
  final String pinnedRevision;

  /// What the snapshot actually contains, or `null` when git reported nothing.
  final String? observedRevision;

  @override
  String toString() =>
      'Snapshot of $repositoryId (product $productId) is at '
      '${observedRevision ?? "(unknown)"}, not the pinned $pinnedRevision. '
      'A baseline derived from a moving source is not a baseline of anything.';
}

/// Raised when a snapshot tree this process created could not be removed.
///
/// Never suppressed, on any path — the same rule `RepositoryAccessVerifier`
/// applies to its own scratch tree, and for the same reason: "the derivation
/// finished" and "the derivation finished and the working copy is gone" are
/// different facts and only the second one is safe to act on.
class BaselineSnapshotCleanupException implements Exception {
  const BaselineSnapshotCleanupException(this.path);

  /// The path an operator needs in order to remove it. Contains no key
  /// material: the private half never lands in the snapshot tree.
  final String path;

  @override
  String toString() =>
      'BaselineSnapshotCleanupException: could not remove the snapshot at '
      '$path';
}

/// A pinned, read-only checkout of one repository at one committed revision.
///
/// ## What this object deliberately does not carry
///
/// No private key, no public key, no credential fingerprint, no host key
/// fingerprint, and **no credential reference name**.
///
/// That last omission is deliberate rather than an oversight. §13a says a
/// credential is referenced by name and never by value, and it would be
/// reasonable to carry the *name* here — it is metadata, not material. ADR 0018
/// §A3 records why that is still wrong: the reference name **is** the sensitive
/// artifact, because it discloses the secret manager's naming scheme and
/// topology to anyone holding it, and gap G-7 exists precisely because that name
/// currently reaches clients. Carrying it on an object that flows into logs and
/// job records would widen a gap that has already been raised once.
///
/// So this object holds nothing that identifies a credential at all. The
/// baseline it produces cannot name, hint at, or be correlated with the
/// credential that fetched it, which is the property §13a is protecting.
class RepositorySnapshot {
  /// Public so a [RepositorySnapshotMaterializer] outside this file can build
  /// one — a port that only its own file can implement is not a port.
  ///
  /// It is a CONTAINER, not a claim. Every property here is asserted by whoever
  /// trusts it: [RepositorySnapshotAcquirer.acquire] re-reads [revision] and
  /// refuses anything that is not the revision it asked for. Constructing a
  /// snapshot saying a revision is therefore not an assertion anyone is asked to
  /// believe, which is why the constructor is not private.
  RepositorySnapshot({
    required this.productId,
    required this.repositoryId,
    required this.revision,
    required this.sourceRef,
    required this.acquiredAt,
    required Directory root,
    required void Function() onRelease,
  }) : _root = root,
       _onRelease = onRelease,
       _released = false;

  final String productId;
  final String repositoryId;

  /// The committed revision this tree actually contains, as git reported it.
  ///
  /// This is evidence, not a claim: the acquirer refuses a tree that does not
  /// report a revision, and refuses a tree whose revision is not the pinned one.
  final String revision;

  /// What "the same source" was, for the re-derivation proof. A repository URL
  /// — never a key, never a fingerprint.
  final String sourceRef;

  final DateTime acquiredAt;

  final Directory _root;
  final void Function() _onRelease;
  bool _released;

  /// The checkout itself.
  ///
  /// Handed to `ReadOnlyRepositoryReader`, which never writes to it. Callers
  /// must not write to it either — a derivation that mutates its own input is
  /// not re-derivable.
  Directory get root {
    if (_released) {
      throw StateError(
        'snapshot $repositoryId@$revision was already released; its tree is '
        'gone and re-derive against a new acquisition',
      );
    }
    return _root;
  }

  /// Removes the tree, at most once.
  ///
  /// Idempotent by construction: a second call is a no-op rather than an error,
  /// because the lane releases in a `finally` and a crash between the derivation
  /// and the release must not turn into a second attempt at deleting a
  /// directory that is already gone.
  void release() {
    if (_released) return;
    _released = true;
    _onRelease();
  }

  @override
  String toString() =>
      'RepositorySnapshot($productId/$repositoryId@$revision, source '
      '$sourceRef)';
}

/// Materialises a pinned checkout. A port, so the lane's trust logic can be
/// exercised without a network, a database, or a git host.
abstract interface class RepositorySnapshotMaterializer {
  /// Produces a read-only tree of [remote] at exactly [pinnedRevision], or
  /// throws.
  ///
  /// Implementations MUST enforce [confirmedHostKeyFingerprint] themselves.
  /// A materializer that trusts whatever host answers has reintroduced ADR 0018
  /// A2 at the one seam the lane cannot audit later, because the resulting
  /// facts would be indistinguishable from facts read from the real repository.
  Future<RepositorySnapshot> materialize({
    required String productId,
    required String repositoryId,
    required SshRemote remote,
    required SecretBytes privateKeyPem,
    required String confirmedHostKeyFingerprint,
    required String pinnedRevision,
  });
}

/// Acquires a pinned, read-only snapshot of a product's repository, using only
/// the credentials the product already has.
///
/// ## Both existing components are on the path, in the order §3.2 puts them
///
/// ```text
///   CredentialKeyService.verifyAccess  → records the provenance of the trust
///                                        decision and refuses a changed host key
///        ↓                              (itself calls)
///   RepositoryAccessVerifier.verify    → proves a real clone happened, reports
///                                        committedRevision, destroys its scratch
///        ↓
///   [ this class ]                     → produces the pinned tree the derivation
///                                        reads, and destroys it on release
/// ```
///
/// There is deliberately **no third credential or trust path**. There is exactly
/// one place a secret is read (`SecretProvider.read`, by reference name), one
/// place a host key is honoured, and one place a clone happens per gate. The
/// tree this class materialises is a second *clone*, not a second *trust*
/// decision, and it re-reads the same credential by the same name to do it.
///
/// ## Why a second clone at all
///
/// `RepositoryAccessVerifier.verify` proves a clone and then destroys its
/// scratch tree — that is its contract, and it is the right contract for a
/// connectivity check. It therefore hands back a revision and no tree. A
/// derivation needs a tree. Someone has to materialise one, and doing it inside
/// this class, behind the same confirmed host key and the same by-name secret
/// read, is what keeps the seam auditable rather than scattered.
///
/// The cost is real and is not hidden: acquiring a snapshot runs two clones.
class RepositorySnapshotAcquirer {
  RepositorySnapshotAcquirer({
    required this.engine,
    required this.credentialKeyService,
    required this.materializer,
  });

  final ProductRegistryEngine engine;
  final CredentialKeyService credentialKeyService;
  final RepositorySnapshotMaterializer materializer;

  /// Acquires [repositoryId] for [productId] at [pinnedRevision].
  ///
  /// Throws [BaselineSourceUnavailableException] when there is no usable,
  /// independently-confirmed credential, [HostKeyNotIndependentlyConfirmedException]
  /// when the value offered as a host key fingerprint is not one, and
  /// [PinnedRevisionNotAcquiredException] when the tree is not the pinned
  /// revision. Every one of those is a refusal to proceed, never a degraded
  /// result handed back.
  Future<RepositorySnapshot> acquire({
    required String productId,
    required String repositoryId,
    required String pinnedRevision,
  }) async {
    if (pinnedRevision.trim().isEmpty) {
      throw ArgumentError.value(
        pinnedRevision,
        'pinnedRevision',
        'a snapshot must be pinned; an unpinned acquisition derives from '
            '"whatever HEAD is now" and cannot be re-derived later',
      );
    }

    final credential = await engine.readActiveCredential(
      productId,
      repositoryId,
    );
    if (credential == null) {
      throw BaselineSourceUnavailableException(
        productId: productId,
        repositoryId: repositoryId,
        reason: 'no credential has been minted for this repository',
      );
    }

    // ---- The distinction §3.2 says must not be blurred. ----
    //
    // `credential.hostKeyFingerprint` is a host key a human confirmed out of
    // band. `credential.fingerprint` is this deploy key's own public key. They
    // are different values with different provenance, and only the first may
    // ever reach `confirmedHostKeyFingerprint`. The comparison below is the
    // mechanical form of that rule: if the two are byte-identical, the value on
    // its way to the verifier is the credential's own fingerprint, and no
    // legitimate host produces that.
    final hostKeyFingerprint = credential.hostKeyFingerprint;
    if (hostKeyFingerprint == null || hostKeyFingerprint.trim().isEmpty) {
      throw HostKeyNotIndependentlyConfirmedException(
        productId: productId,
        repositoryId: repositoryId,
        reason:
            'no host key fingerprint has been confirmed for this repository; a '
            'deploy key fingerprint is not one and was not substituted',
      );
    }
    if (hostKeyFingerprint.trim() == credential.fingerprint.trim()) {
      throw HostKeyNotIndependentlyConfirmedException(
        productId: productId,
        repositoryId: repositoryId,
        reason:
            'the value recorded as the host key fingerprint is this '
            "credential's own public-key fingerprint; those are different "
            'values with different provenance',
      );
    }
    if (!credential.isHostConfirmed) {
      throw BaselineSourceUnavailableException(
        productId: productId,
        repositoryId: repositoryId,
        reason:
            'the host key has not been confirmed by a human, so the trust '
            'decision the verifier enforces has no provenance to enforce',
      );
    }
    if (!credential.canReachRepository) {
      throw BaselineSourceUnavailableException(
        productId: productId,
        repositoryId: repositoryId,
        reason:
            'the credential is not currently usable '
            '(status ${credential.status.wire}, host key '
            '${credential.hostKeyStatus.wire})',
      );
    }

    // Gate 1. `verifyAccess` re-confirms the already-recorded host key, which
    // the domain refuses if it ever changes, and then runs the real clone
    // through `RepositoryAccessVerifier.verify`. The attribution is honest: the
    // human who confirmed the host key is named as the confirmer, and the
    // principal that performed this check is named separately as the checker.
    // A lane must not put its own name in `confirmedBy` — that would forge the
    // one piece of provenance this whole seam rests on.
    final confirmedBy = credential.hostConfirmedBy;
    if (confirmedBy == null || confirmedBy.trim().isEmpty) {
      throw BaselineSourceUnavailableException(
        productId: productId,
        repositoryId: repositoryId,
        reason:
            'the confirmed host key records no confirming human, so the trust '
            'decision is unattributable',
      );
    }
    final access = await credentialKeyService.verifyAccess(
      productId: productId,
      repositoryId: repositoryId,
      hostKeyFingerprint: hostKeyFingerprint,
      confirmedBy: confirmedBy,
      checkedBy: _lanePrincipal,
    );
    if (!access.canReachRepository) {
      throw BaselineSourceUnavailableException(
        productId: productId,
        repositoryId: repositoryId,
        reason:
            access.failureReason ??
            'a connectivity check with this credential did not succeed',
      );
    }

    final repository = await engine.resolveRepository(productId, repositoryId);
    final remote = parseSshRemote(repository.uri);

    // The one read of private material in this class, by reference name. Wiped
    // on every path, and the value never reaches a return value, a log, or a
    // record.
    final material = await credentialKeyService.secretProvider.read(
      referenceName: credential.referenceName,
    );
    try {
      final snapshot = await materializer.materialize(
        productId: productId,
        repositoryId: repositoryId,
        remote: remote,
        privateKeyPem: material,
        confirmedHostKeyFingerprint: hostKeyFingerprint,
        pinnedRevision: pinnedRevision,
      );
      if (snapshot.revision.trim() != pinnedRevision.trim()) {
        snapshot.release();
        throw PinnedRevisionNotAcquiredException(
          productId: productId,
          repositoryId: repositoryId,
          pinnedRevision: pinnedRevision,
          observedRevision: snapshot.revision,
        );
      }
      return snapshot;
    } finally {
      material.wipe();
    }
  }

  /// Identity recorded as the principal performing the connectivity check.
  static const String _lanePrincipal = 'lane:baseline-production';
}

/// The production [RepositorySnapshotMaterializer]: a real `git` clone of one
/// repository at one pinned revision, over SSH, with the confirmed host key
/// enforced at the socket.
///
/// ## What is borrowed from `RepositoryAccessVerifier`, and why it is borrowed
/// rather than shared
///
/// The scratch layout, the `0700`/`0600` modes, the ambient-environment
/// redirection, the SSH option set and the scan-then-match-then-`known_hosts`
/// construction are the same ones `RepositoryAccessVerifier` uses, and they are
/// reproduced here rather than imported because that class's clone path is
/// private and deletes its tree on the way out. That is a real duplication and
/// it is recorded as a finding: the right fix is a `cloneInto` seam on
/// `RepositoryAccessVerifier`, after which this class becomes a caller instead
/// of a second implementation. Until then the two must be changed together, and
/// the comment on [_scanHostKeys] is the marker that says so.
///
/// Duplication is preferable here to the alternative, which is not "reuse" but
/// "materialise without a host-key check" — and an acquisition with no host-key
/// check is precisely the ADR 0018 A2 gap this lane exists to hold shut.
class SshPinnedSnapshotMaterializer implements RepositorySnapshotMaterializer {
  const SshPinnedSnapshotMaterializer({
    this.connectTimeout = const Duration(seconds: 20),
    this.cloneTimeout = const Duration(minutes: 5),
    this.scratchPrefix = 'baseline_snapshot_',
    this.gitExecutable = 'git',
  });

  final Duration connectTimeout;
  final Duration cloneTimeout;
  final String scratchPrefix;
  final String gitExecutable;

  @override
  Future<RepositorySnapshot> materialize({
    required String productId,
    required String repositoryId,
    required SshRemote remote,
    required SecretBytes privateKeyPem,
    required String confirmedHostKeyFingerprint,
    required String pinnedRevision,
  }) async {
    final scratch = Directory.systemTemp.createTempSync(scratchPrefix);
    try {
      PosixFileModes.applyStrict(scratch.path, PosixFileModes.directory);
      final identityPath = '${scratch.path}/identity';
      final knownHostsPath = '${scratch.path}/known_hosts';
      final wrapperPath = '${scratch.path}/ssh-wrapper.sh';
      final clonePath = '${scratch.path}/checkout';

      // Host key BEFORE the private half, exactly as the verifier orders it: a
      // call that is about to refuse has no reason to have written key material
      // first.
      final matched = await _matchConfirmedHostKeys(
        remote,
        confirmedHostKeyFingerprint,
      );
      if (matched.isEmpty) {
        throw HostKeyNotIndependentlyConfirmedException(
          productId: productId,
          repositoryId: repositoryId,
          reason:
              'the host presented no key matching the confirmed fingerprint',
        );
      }

      PosixFileModes.writeOwnerOnlyFile(identityPath, privateKeyPem.bytes);
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

      await _git(remote, wrapperPath, clonePath, ['init', '--quiet']);
      await _git(remote, wrapperPath, clonePath, [
        'remote',
        'add',
        'origin',
        remote.toSshUrl(),
      ]);
      // `--depth 1` on the pinned revision directly, so the tree that ends up on
      // disk is the pinned commit and not the default branch with a checkout
      // after it. The distinction is the whole point: a shallow clone of HEAD
      // followed by `checkout <old sha>` can fail for reasons that have nothing
      // to do with the source, and the failure would be reported as drift.
      await _git(remote, wrapperPath, clonePath, [
        'fetch',
        '--depth',
        '1',
        '--no-tags',
        '--quiet',
        'origin',
        pinnedRevision,
      ]);
      await _git(remote, wrapperPath, clonePath, [
        'checkout',
        '--quiet',
        '--detach',
        'FETCH_HEAD',
      ]);

      final observed = await _gitOutput(clonePath, ['rev-parse', 'HEAD']);
      if (observed == null || observed.trim() != pinnedRevision.trim()) {
        _destroy(scratch);
        throw PinnedRevisionNotAcquiredException(
          productId: productId,
          repositoryId: repositoryId,
          pinnedRevision: pinnedRevision,
          observedRevision: observed,
        );
      }

      return RepositorySnapshot(
        productId: productId,
        repositoryId: repositoryId,
        revision: observed.trim(),
        // No credential reference name: see RepositorySnapshot's own note on
        // ADR 0018 A3 / gap G-7. The secret provider is the only thing that
        // ever knew it, and it does not persist it here either.
        sourceRef: remote.toSshUrl(),
        acquiredAt: DateTime.now().toUtc(),
        root: Directory(clonePath),
        onRelease: () {
          if (!_destroy(scratch)) {
            throw BaselineSnapshotCleanupException(scratch.path);
          }
        },
      );
    } on Object {
      // Every failure path removes the tree, including the success path's own
      // throws. A tree this process could not remove is an incident, not a
      // result.
      if (!_destroy(scratch)) {
        throw BaselineSnapshotCleanupException(scratch.path);
      }
      rethrow;
    }
  }

  /// Host key lines whose `ssh-keygen -lf` fingerprint equals the confirmation.
  ///
  /// ## THE CONSTRAINT THAT MAKES THIS NOT A FALLBACK
  ///
  /// This scan exists to *check* a value whose provenance is already settled —
  /// a human confirming the host's key out of band — and its whole job is to
  /// fail when the host presents something else. It is NOT a way to obtain the
  /// confirmed value, and a result from it must never be promoted to one. The
  /// distinction is the difference between checking a key and trusting whoever
  /// answered: the second is ADR 0018 A2, and no amount of `StrictHostKeyChecking`
  /// repairs it because it is a provenance failure, not a transport failure.
  Future<List<String>> _matchConfirmedHostKeys(
    SshRemote remote,
    String confirmedFingerprint,
  ) async {
    final ProcessResult scan;
    try {
      scan = await _runBounded(
        'ssh-keyscan',
        'ssh-keyscan',
        ['-p', '${remote.port}', remote.host],
        connectTimeout,
      );
    } on Object {
      // No scan, no clone. This is a refusal, and an absent `ssh-keyscan` is
      // still a refusal rather than a reason to proceed unverified.
      return const [];
    }
    final matched = <String>[];
    for (final line in (scan.stdout as String).split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final fingerprint = await _fingerprintOf(trimmed);
      if (fingerprint != null && fingerprint == confirmedFingerprint.trim()) {
        matched.add(trimmed);
      }
    }
    // Only the confirmed key. Everything the scan returned would let a clone
    // succeed against a second key nobody ever saw.
    return matched;
  }

  /// `ssh-keygen -lf -` for one authorized-keys line, or null.
  ///
  /// `ssh-keygen` rather than a hand-rolled SHA-256, for the reason the verifier
  /// gives: a fingerprint that disagrees with the host's own UI by one character
  /// fails every legitimate verification while passing every illegitimate one.
  Future<String?> _fingerprintOf(String keyLine) async {
    final Process process;
    try {
      process = await Process.start(
        'ssh-keygen',
        ['-lf', '-'],
        environment: {'HOME': Directory.systemTemp.path},
      );
    } on Object {
      return null;
    }
    // The newline is load-bearing: `ssh-keygen -lf -` reads a line, and an
    // unterminated write leaves it waiting for more input for ever. Every step
    // is bounded, because a helper this code spawned and abandoned is the
    // failure mode `RepositoryAccessVerifier._runBounded` exists to prevent.
    final stdoutText = process.stdout.transform(utf8.decoder).join();
    int code;
    try {
      process.stdin.write('$keyLine\n');
      await process.stdin.flush().timeout(connectTimeout);
      await process.stdin.close().timeout(connectTimeout);
      code = await process.exitCode.timeout(connectTimeout);
      await stdoutText.timeout(connectTimeout);
    } on Object {
      process.kill(ProcessSignal.sigkill);
      return null;
    }
    if (code != 0) return null;
    return RegExp(
      r'SHA256:[A-Za-z0-9+/]+=*',
    ).firstMatch(await stdoutText)?.group(0);
  }

  Future<void> _git(
    SshRemote remote,
    String wrapperPath,
    String clonePath,
    List<String> gitArguments,
  ) async {
    final result = await _runBounded(
      'git',
      gitExecutable,
      ['--no-pager', '-C', clonePath, ...gitArguments],
      cloneTimeout,
      environment: {
        'GIT_SSH_COMMAND': wrapperPath,
        'GIT_SSH_VARIANT': 'ssh',
        // Nothing here may block on a human. A lane waiting on a passphrase
        // prompt holds the private half in memory for as long as the prompt is
        // up, and holds the job open with it.
        'GIT_TERMINAL_PROMPT': '0',
        'GIT_ASKPASS': '',
        // Redirect the ambient environment at the scratch tree: a developer's
        // ~/.ssh/config can add IdentityFile, ProxyCommand or RemoteCommand,
        // and a global gitconfig can add `url.*.insteadOf`. None of them gets a
        // say in a clone that holds a deploy key.
        'HOME': Directory(clonePath).parent.path,
        'GIT_CONFIG_GLOBAL': '/dev/null',
        'GIT_CONFIG_SYSTEM': '/dev/null',
      },
    );
    if (result.exitCode != 0) {
      throw BaselineSnapshotMaterializationException(
        repositoryId: remote.repositoryPath,
        command: 'git ${gitArguments.first}',
        detail: _sanitise((result.stderr as String).toString()),
      );
    }
  }

  Future<String?> _gitOutput(String path, List<String> gitArguments) async {
    final result = await _runBounded(
      'git',
      gitExecutable,
      ['--no-pager', '-C', path, ...gitArguments],
      connectTimeout,
      environment: {
        'GIT_CONFIG_GLOBAL': '/dev/null',
        'GIT_CONFIG_SYSTEM': '/dev/null',
      },
    );
    if (result.exitCode != 0) return null;
    return (result.stdout as String).trim();
  }

  /// Runs a helper to completion, or kills its process tree and refuses.
  ///
  /// `Future.timeout` stops the *Dart* side from waiting and nothing more: the
  /// child keeps running, holding the identity file. Owning the [Process] is the
  /// only way to stop that, so this mirrors the verifier's helper rather than
  /// reaching for `timeout`.
  Future<ProcessResult> _runBounded(
    String helper,
    String executable,
    List<String> arguments,
    Duration timeout, {
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
      throw ProcessException(
        executable,
        arguments,
        'the $helper helper could not be started',
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
      process.kill(ProcessSignal.sigkill);
      // Drain so the pipes do not keep the isolate alive, and bound the wait so
      // a child that ignores the signal cannot hold the caller.
      await exit
          .timeout(const Duration(seconds: 5))
          .catchError((Object _) => -1);
      unawaited(stdoutText.catchError((Object _) => ''));
      unawaited(stderrText.catchError((Object _) => ''));
      throw BaselineSnapshotMaterializationException(
        repositoryId: helper,
        command: executable,
        detail:
            'the $helper helper outlived ${timeout.inSeconds}s and its process '
            'tree was killed; a live git holding a deploy key is not something '
            'to leave running',
      );
    }
  }

  /// The `ssh` invocation `git` is pointed at, as a standalone script.
  ///
  /// A script rather than an inline `GIT_SSH_COMMAND`: git hands that string to
  /// a shell, so inline options would need quoting for two filesystem paths
  /// under the system temp directory, and a quoting bug there is a path-shaped
  /// bug. It holds no secret — only two scratch paths and a port.
  String _sshWrapper({
    required String identityPath,
    required String knownHostsPath,
    required int port,
  }) =>
      '''
#!/bin/sh
# Generated by SshPinnedSnapshotMaterializer. Holds no key material: the
# identity it names lives beside this script in a 0700 directory removed when
# release() is called.
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

  static String _shellQuote(String value) =>
      "'${value.replaceAll("'", r"'\''")}'";

  /// Replaces the scratch path and truncates, so a diagnostic is safe to persist
  /// and show an operator.
  static String _sanitise(String text, [String? scratchPath]) {
    var out = scratchPath == null
        ? text
        : text.replaceAll(scratchPath, '<snapshot>');
    const limit = 500;
    return out.length <= limit
        ? out
        : '${out.substring(0, limit)}… (truncated)';
  }

  /// Deletes the tree and confirms it is gone.
  ///
  /// Retries once, for the same reason the verifier does: a clone killed
  /// mid-write can leave an entry that disappears on the next pass. The
  /// existence check is the verdict; the exception above is only a reason to
  /// try again.
  static bool _destroy(Directory scratch) {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        if (scratch.existsSync()) scratch.deleteSync(recursive: true);
      } on Object {
        // The check below decides; this is only a reason to retry.
      }
      if (!scratch.existsSync()) return true;
    }
    return false;
  }
}

/// Raised when git refused to materialise the pinned tree.
///
/// Operator-facing and safe to persist: git's own diagnostic with the scratch
/// path replaced and truncated. It never contains key material, because the
/// identity file's path is the only thing this code ever passed to a command.
class BaselineSnapshotMaterializationException implements Exception {
  const BaselineSnapshotMaterializationException({
    required this.repositoryId,
    required this.command,
    required this.detail,
  });

  final String repositoryId;
  final String command;
  final String detail;

  @override
  String toString() =>
      'BaselineSnapshotMaterializationException: $command could not materialise '
      '$repositoryId — $detail';
}
