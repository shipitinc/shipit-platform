import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../credentials/posix_file_permissions.dart';
import '../credentials/repository_snapshot_acquirer.dart'
    show HostKeyNotIndependentlyConfirmedException;
import '../credentials/secret_material.dart' show SecretBytes;
import '../credentials/ssh_remote.dart' show SshRemote;

/// The durable clone a [DurableWorkspaceMaterializer] produced.
///
/// ## What this is NOT, and why that is stated on the type
///
/// This is deliberately **not** a `RepositorySnapshot`. `RepositorySnapshot`
/// has a release contract — the caller must release it, its `root` throws
/// afterwards, and whether the tree is kept is decided at release time by
/// "did anything commit into this tree". A product's durable clone is the
/// opposite of all three: nothing releases it, its path is read back for the
/// life of the deployment, and it is KEPT because it is the product's, not
/// because a committer happened to write into it.
///
/// That is not a stylistic difference. A fresh clone created by this lane has
/// no local head, so a snapshot's retain test would classify it read-only and
/// **destroy it** — the product would silently lose its only checkout on the
/// first run. So the durable clone is its own type with no release contract to
/// honour, and saying so here is what stops the next reader from reaching for
/// `RepositorySnapshotAcquirer.acquire` instead.
class DurableWorkspaceClone {
  const DurableWorkspaceClone({
    required this.productId,
    required this.repositoryId,
    required this.repositoryPath,
    required this.revision,
    required this.sourceRef,
    required this.materializedAt,
  });

  final String productId;
  final String repositoryId;

  /// Absolute path of the clone. This is the value an independent reviewer
  /// re-reads to re-validate [revision] inside it, which is why it has to be
  /// reachable from wherever the reviewer is — a host-backed path, not a
  /// container-local one.
  final String repositoryPath;

  /// The committed revision the clone was verified to be at.
  ///
  /// Read back off the tree with `git rev-parse HEAD` after checkout, never
  /// assumed from the argument that was asked for. A clone that landed
  /// somewhere else is drift, and a descriptor naming a commit the tree is not
  /// at is a descriptor the review gate will fail closed on later.
  final String revision;

  /// The `ssh://` URL the clone's `origin` points at.
  ///
  /// Carries no credential: an origin is an address, and ADR 0018 §13a makes
  /// the deploy key a thing referenced by name, never embedded in one.
  final String sourceRef;

  final DateTime materializedAt;

  @override
  String toString() =>
      'DurableWorkspaceClone($productId/$repositoryId@$revision at '
      '$repositoryPath)';
}

/// Materialises a product-scoped, durable, writable clone at an exact pinned
/// commit. A port, for the same reason `RepositorySnapshotMaterializer` is one:
/// the lane's trust logic has to be exercisable without a network, a database
/// or a git host.
///
/// ## Implementations MUST enforce [confirmedHostKeyFingerprint] themselves
///
/// A materializer that trusts whatever host answers reintroduces ADR 0018 A2 at
/// the one seam this lane cannot audit later, because a clone made against an
/// unverified host is indistinguishable from one made against the real
/// repository.
abstract interface class DurableWorkspaceMaterializer {
  /// Produces a durable clone of [remote] at exactly [pinnedRevision] under
  /// [productRoot], or throws.
  ///
  /// [productRoot] is the parent directory this lane owns for one product. It
  /// is created if absent. Everything written under it OTHER than the clone
  /// itself is credential material and must be gone by the time this returns —
  /// successfully or not. See the six obligations on
  /// [SshDurableWorkspaceMaterializer].
  ///
  /// ## The contract on a product root that ALREADY EXISTS
  ///
  /// An implementation MUST refuse, and MUST NOT destroy it.
  ///
  /// The root is derived from `$workspaceRoot/$productId` and nothing else, so
  /// it can already hold state this call did not make: a previous run's clone
  /// with its object store and whatever an implementation lane has committed
  /// into it, or a tree someone put there by hand. A call that treats such a
  /// root as its own on the failure path is deleting somebody's work to report
  /// its own error — so the refusal is what "owning" this path has to mean.
  ///
  /// The consequence worth stating plainly: **this is not re-entrant, and that
  /// is deliberate.** A second `materialize` into the same root fails loudly and
  /// destroys nothing. A caller that wants a re-provision to succeed has to
  /// decide what happens to the existing tree first — that is an operator's
  /// decision, and the state is unreviewed work until they make it.
  Future<DurableWorkspaceClone> materialize({
    required String productId,
    required String repositoryId,
    required SshRemote remote,
    required SecretBytes privateKeyPem,
    required String confirmedHostKeyFingerprint,
    required String pinnedRevision,
    required String productRoot,
  });
}

/// The production [DurableWorkspaceMaterializer]: a real `git` clone over SSH,
/// with the confirmed host key enforced at the socket and no credential left
/// on or beside the clone.
///
/// ## Why this is a second implementation and not a reuse
///
/// `SshPinnedSnapshotMaterializer` already does the same clone, against the
/// same confirmed host key, over the same credential. Reusing it is forbidden
/// for three independent reasons, each sufficient: its `RepositorySnapshot.root`
/// throws after `release()`, so the path cannot be read back afterwards; its
/// retain decision is `_localBranchRefs`, and a fresh durable clone has no
/// local head at creation time, so it would be classified read-only and
/// **destroyed**; and a snapshot is a per-execution with a release contract,
/// which is not a thing a product-scoped long-lived clone should import.
///
/// So the transport is reimplemented here. That is real duplication, and it is
/// the same duplication `SshPinnedSnapshotMaterializer` already records against
/// itself for the same reason.
///
/// ## The six credential obligations, and why they are written down
///
/// Obligations 3–5 below are **invisible on every success path**. A
/// materializer that leaves the identity file beside the clone works
/// perfectly, produces green tests, and leaves a deploy-key identity on disk
/// next to a governed product's checkout for the life of the deployment.
/// Nothing in a functional test suite can see it. Only the obligation makes it
/// reviewable, and the review row that checks it is why this comment exists.
///
/// Per acquisition, this class:
///
///  1. **Materialises the private half afresh.** It arrives as a [SecretBytes]
///     for the duration of one call, is written to an owner-only identity file
///     beside the clone, and is never cached in a field, reused across
///     acquisitions, or read from a path. The caller owns wiping it; see
///     [wipedBeforeReturn].
///  2. **Writes the identity, `known_hosts` and the ssh wrapper as SIBLINGS of
///     the clone**, never inside it, and removes them with the materialisation.
///     Inside the working tree they would be untracked residue that any
///     `git add -A` in the clone would sweep into a commit.
///  3. **Passes the private half only through a per-invocation environment** —
///     `GIT_SSH_COMMAND` naming the wrapper, a pinned `PATH`,
///     `GIT_TERMINAL_PROMPT=0` and `GIT_ASKPASS=''` so nothing can block on a
///     human prompt while a key is in memory.
///  4. **Redirects the ambient environment**: `HOME` points at the
///     materialisation root and `GIT_CONFIG_GLOBAL` / `GIT_CONFIG_SYSTEM` are
///     both `/dev/null`. A developer's `~/.ssh/config` can add `IdentityFile`,
///     `ProxyCommand` or `RemoteCommand`, and a global gitconfig can add
///     `url.*.insteadOf`; none of them gets a say in a clone holding a deploy
///     key.
///  5. **Leaves no `core.sshCommand` and no identity reference in the clone's
///     git config**, and writes no `~/.ssh/config`, `known_hosts` or credential
///     file that outlives the acquisition. `GIT_SSH_COMMAND` is an environment
///     variable, so git never persists it — the class never runs
///     `git config core.sshCommand`, and that is the whole reason the clone's
///     config after this returns is as credential-free as a checkout made with
///     the public half.
///  6. **Destroys the credential material first and unconditionally**, before
///     deciding anything about the repository's fate. On success the identity,
///     `known_hosts` and wrapper are removed and only the clone remains; on
///     failure the product root is removed entirely — **but only when this call
///     created it** — and the caller is told the cleanup failed rather than
///     being handed a half-built tree.
///
/// ## Why the destroy is scoped to provenance, and not to "nothing was returned"
///
/// Obligation 6 used to end "on failure the product root is removed entirely",
/// and that clause was the defect. It made a failed `git` call — any failed
/// `git` call — a delete of `$workspaceRoot/$productId`, which is a governed
/// product's checkout with its object store and every unreviewed commit in it.
///
/// The distinction the fix turns on is not whether a descriptor was handed back.
/// It is whether **this call created the root**. Those come apart constantly:
/// `provision()` materialises at :485 and writes the onboarding record at :500+,
/// so a record write that fails after a successful clone leaves an orphan tree
/// that the next instruction then destroys on its way to the same error. And the
/// ordinary case is worse: `git init` is idempotent, so a second `provision()`
/// fails at `git remote add origin` (exit 3, "remote origin already exists") and
/// used to take the whole clone with it.
///
/// A refusal keeps the tree and names the collision; it never keeps the
/// CREDENTIAL. Those are separate obligations and both still hold — see the
/// `finally` in [materialize], which destroys the identity, `known_hosts` and
/// wrapper on the collision path too, having written none of them.
///
/// ## Why the clone is writable and still has no key
///
/// It is a working checkout, because an implementation lane commits into it and
/// the review gate resolves artifacts out of its object store. It carries an
/// `origin` remote and **no credential configured on it**: any later
/// `fetch`/`push` from it fails closed, because the identity file this class
/// wrote is gone by the time it returns. That is the intended state, not an
/// oversight — a durable clone is a checkout, not a credential store.
class SshDurableWorkspaceMaterializer implements DurableWorkspaceMaterializer {
  const SshDurableWorkspaceMaterializer({
    this.connectTimeout = const Duration(seconds: 20),
    this.cloneTimeout = const Duration(minutes: 5),
    this.gitExecutable = 'git',
    this.pathPrefix,
  });

  final Duration connectTimeout;
  final Duration cloneTimeout;
  final String gitExecutable;

  /// Prepended to `PATH` for every helper spawned — `git`, `ssh-keyscan` and
  /// the `ssh` the wrapper execs.
  ///
  /// `git`, `ssh-keyscan` and `ssh-keygen` are spawned by **bare name** and so
  /// resolve through the ambient `PATH`. A class that resolves its helpers that
  /// way cannot be driven to any of them in a test without one going out to the
  /// network, which is why this seam exists: it is the same seam
  /// `SshPinnedSnapshotMaterializer` has, for the same reason, so the six
  /// obligations above can be asserted against a stub `git` rather than
  /// described.
  ///
  /// Null — the default, and the only value production uses — leaves the
  /// ambient `PATH` exactly as it was.
  final String? pathPrefix;

  /// The file names this class writes beside a clone. Named, not interpolated
  /// at a call site, so a test can assert their ABSENCE by name rather than by
  /// reproducing the naming.
  static const String identityFileName = 'identity';
  static const String knownHostsFileName = 'known_hosts';
  static const String sshWrapperFileName = 'ssh-wrapper.sh';

  /// The clone's directory name inside the product root.
  static const String cloneDirectoryName = 'checkout';

  @override
  Future<DurableWorkspaceClone> materialize({
    required String productId,
    required String repositoryId,
    required SshRemote remote,
    required SecretBytes privateKeyPem,
    required String confirmedHostKeyFingerprint,
    required String pinnedRevision,
    required String productRoot,
  }) async {
    final normalizedPin = pinnedRevision.trim();
    if (normalizedPin.isEmpty) {
      throw ArgumentError.value(
        pinnedRevision,
        'pinnedRevision',
        'a durable clone must be pinned; an unpinned clone describes "whatever '
            'HEAD is now" and the descriptor that names it cannot be '
            're-derived later, because "later" is a different commit',
      );
    }

    final root = Directory(productRoot);
    final identityPath = '${root.path}/$identityFileName';
    final knownHostsPath = '${root.path}/$knownHostsFileName';
    final wrapperPath = '${root.path}/$sshWrapperFileName';
    final clonePath = '${root.path}/$cloneDirectoryName';

    var cloneVerified = false;

    // ---- DESTROY PROVENANCE, decided once and before anything is written. ----
    //
    // These two facts together are the whole fix, and they are read HERE rather
    // than recovered later, because the question "did this call create that
    // root?" is only answerable while this call is still the only thing that has
    // touched it. Ask it after a `git remote add` has already exited 3 and the
    // answer has been overwritten by whatever the directory holds — and the
    // tempting reading of that is "it is full of my own half-built clone, so it
    // is mine", which is precisely the bug.
    //
    // `createdRoot` is the authority for the destructive path below and nothing
    // else. `rootPreExisted` is captured before the first byte is written and
    // answers only the one question the refusal needs.
    final rootPreExisted = root.existsSync();
    var createdRoot = false;

    try {
      // Host key BEFORE the private half, and before anything is written: a
      // call that is about to refuse has no reason to have touched key
      // material or left a directory behind.
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

      if (rootPreExisted) {
        // Refuse BEFORE the root is touched, so "do not destroy it" is not a
        // promise made by a cleanup path — it is a consequence of never having
        // written into it. Every write below this line would otherwise be a
        // byte added to somebody else's directory.
        //
        // A filesystem existence check, not a probe of the tree's contents and
        // not a marker this class left last time. See
        // [DurableWorkspaceRootCollisionException] for why each alternative
        // answers a weaker question.
        throw DurableWorkspaceRootCollisionException(
          productId: productId,
          repositoryId: repositoryId,
          productRoot: root.path,
          findings: _describeExistingRoot(root.path, clonePath),
        );
      }

      // Ownership is claimed BEFORE the create, not after it returns.
      // `createOwnerOnlyDirectory` creates and then chmods, so a permission
      // failure leaves a real directory behind and throws; claiming afterwards
      // would hand that directory to nobody — no destroy, no owner, and a
      // directory holding nothing but a failed provisioning's residue.
      createdRoot = true;
      PosixFileModes.createOwnerOnlyDirectory(root.path);

      // The guard against a misconfigured root, written where the root is
      // created rather than by a caller.
      //
      // The workspace root is operator-chosen and the compose sentinel defaults
      // under the system temp directory, so "somebody points it at a
      // repository-adjacent path" is a plausible misconfiguration rather than a
      // certainty — and the consequence would be a governed product's entire
      // checkout, with its `.git` object store and its build outputs, appearing
      // as untracked files in somebody's work tree. A repository `.gitignore`
      // entry is the repository's answer to that; this is the clone's own, and
      // it works wherever the root actually is: `*` in a directory excludes
      // everything beneath it, so even a root nested inside a work tree
      // contributes nothing to it.
      //
      // Written here rather than by the provisioner so it is established by the
      // same code that creates the root — a guard in one place and the directory
      // it protects in another is a guard a future refactor can drop. It sits
      // BESIDE the clone, never inside it: a file in the working tree would be
      // untracked residue that any `git add -A` would sweep into an artifact
      // commit.
      _guardRootAgainstCommitting(root.path);

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

      // `git -C <dir>` chdirs BEFORE it dispatches, so the directory has to
      // exist before the first call or every one of them dies with
      // `fatal: cannot change to '<path>'` and the whole provisioning fails
      // before a byte crosses the network.
      if (!Directory(clonePath).existsSync()) {
        PosixFileModes.createOwnerOnlyDirectory(clonePath);
      }

      await _git(remote, wrapperPath, clonePath, ['init', '--quiet']);
      await _git(remote, wrapperPath, clonePath, [
        'remote',
        'add',
        'origin',
        remote.toSshUrl(),
      ]);
      // `--depth 1` on the pinned revision directly, so the tree on disk is
      // the pinned commit rather than the default branch with a checkout after
      // it. A shallow clone of HEAD followed by `checkout <old sha>` fails for
      // reasons that have nothing to do with the source, and that failure would
      // be reported as drift.
      await _git(remote, wrapperPath, clonePath, [
        'fetch',
        '--depth',
        '1',
        '--no-tags',
        '--quiet',
        'origin',
        normalizedPin,
      ]);
      await _git(remote, wrapperPath, clonePath, [
        'checkout',
        '--quiet',
        '--detach',
        'FETCH_HEAD',
      ]);

      // Obligation 5, enforced rather than merely avoided. Nothing in the
      // sequence above writes `core.sshCommand` — `GIT_SSH_COMMAND` is an
      // environment variable and git does not persist it — so this is an
      // assertion that the property still holds on the tree being returned,
      // not a substitute for the design of the calls. A materializer that ever
      // grew a `git config core.sshCommand` would leave a pointer to an
      // identity file on every later fetch, and no functional test in this
      // repository would fail.
      await _refusePersistedCredential(clonePath, identityPath);

      // Read the revision off the tree rather than trusting the argument. A
      // descriptor that names a commit the clone is not at is a descriptor the
      // review gate fails closed on, days later, with no clue why.
      final observed = await _gitOutput(clonePath, ['rev-parse', 'HEAD']);
      final observedRevision = observed?.trim();
      if (observedRevision == null || observedRevision.isEmpty) {
        throw DurableWorkspaceMaterializationException(
          repositoryId: repositoryId,
          command: 'rev-parse HEAD',
          detail: 'the clone could not report the revision it is at',
        );
      }
      if (observedRevision != normalizedPin) {
        throw DurableWorkspaceNotPinnedException(
          productId: productId,
          repositoryId: repositoryId,
          pinnedRevision: normalizedPin,
          observedRevision: observedRevision,
        );
      }
      cloneVerified = true;

      return DurableWorkspaceClone(
        productId: productId,
        repositoryId: repositoryId,
        repositoryPath: clonePath,
        revision: observedRevision,
        sourceRef: remote.toSshUrl(),
        materializedAt: DateTime.now().toUtc(),
      );
    } on Object {
      // ---- The destroy is scoped to what THIS CALL created. ----
      //
      // The previous code destroyed `root` unconditionally, on the strength of
      // "nothing has been handed to a caller, so there is nothing to preserve".
      // That justification was about the DESCRIPTOR and was silently used to
      // license destroying a TREE, which are different objects: no descriptor
      // exists on the failure path, but the product root holds a clone with its
      // object store and every unreviewed commit in it, and none of that was
      // this call's to delete.
      //
      // It is reachable in ordinary operation, not only in theory. `git init`
      // against an existing repository exits 0 — it is idempotent — so a second
      // provisioning reaches `git remote add origin`, which exits 3 with
      // "remote origin already exists", and that non-zero exit used to take the
      // clone with it. "Re-provision" read as a harmless verb and destroyed a
      // product checkout holding unreviewed commits.
      //
      // So the rule is narrow and absolute: **this class removes a product root
      // only when it created that root in this call.** A pre-existing root is
      // left exactly as found, and the reason it collided travels with the
      // refusal — see [DurableWorkspaceRootCollisionException].
      if (createdRoot && !_destroy(root)) {
        throw DurableWorkspaceCleanupException(root.path);
      }
      rethrow;
    } finally {
      // ---- Obligation 6: the credential material goes first, always, and
      // never deferred to the repository's fate. ----
      //
      // Ordering is the whole point. The identity file is what authenticated
      // the clone, and it exists for the duration of the clone and no longer.
      // An artifact is not a reason to keep a live key on disk, so the
      // credential material goes first on BOTH paths — the success path so the
      // clone is left credential-free, the failure path so a refused
      // provisioning does not leave a deploy-key identity on disk.
      //
      // Wiping the in-memory half is the caller's half of the same obligation
      // (see `wipedBeforeReturn`); this is the on-disk half.
      final credentialFilesDestroyed = _destroyCredentialMaterial(
        identityPath,
        knownHostsPath,
        wrapperPath,
      );
      if (cloneVerified && !credentialFilesDestroyed) {
        throw DurableWorkspaceCleanupException(root.path);
      }
    }
  }

  /// Refuses a clone whose config has retained a credential pointer.
  ///
  /// Two checks, both of which can only fail if something in this class
  /// changed its mind about how the identity reaches git:
  ///
  ///   * `core.sshCommand` is unset — a config value pointing at the wrapper
  ///     would make every later fetch use an identity file that is supposed to
  ///     be gone; and
  ///   * no configured value anywhere in the clone's config names the identity
  ///     file or the materialisation root.
  ///
  /// The second is the broad one, and it is deliberately broad: it is not
  /// trying to enumerate the ways a credential can be referenced, it is
  /// refusing any reference at all. `git config --list --local` is read with
  /// the same redacted environment as the clone, so a hostile ambient
  /// configuration cannot make it report something other than what this clone
  /// actually contains.
  Future<void> _refusePersistedCredential(
    String clonePath,
    String identityPath,
  ) async {
    final sshCommand = await _gitOutput(clonePath, [
      'config',
      '--local',
      '--get',
      'core.sshCommand',
    ]);
    if (sshCommand != null && sshCommand.trim().isNotEmpty) {
      throw DurableWorkspaceMaterializationException(
        repositoryId: clonePath,
        command: 'config --get core.sshCommand',
        detail:
            'the clone has a persisted core.sshCommand. The identity must reach '
            'git through a per-invocation environment only; a config value '
            'would make every later fetch use a key file this process is '
            'required to delete',
      );
    }

    final listed = await _gitOutput(clonePath, [
      'config',
      '--list',
      '--local',
    ]);
    final offending = <String>[];
    for (final line in (listed ?? '').split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.contains(identityPath) || trimmed.contains('sshCommand')) {
        offending.add(trimmed.split('=').first.trim());
      }
    }
    if (offending.isNotEmpty) {
      throw DurableWorkspaceMaterializationException(
        repositoryId: clonePath,
        command: 'config --list --local',
        detail:
            'the clone config references the credential material '
            '(${offending.join(", ")}). The clone must be as credential-free as '
            'a checkout made with the public half',
      );
    }
  }

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
        environment: _helperEnvironment,
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
    // Only the confirmed key. Everything else the scan returned would let a
    // clone succeed against a second key nobody ever saw.
    return matched;
  }

  /// `ssh-keygen -lf -` for one authorized-keys line, or null.
  ///
  /// `ssh-keygen` rather than a hand-rolled SHA-256, for the reason the whole
  /// trust chain gives: a fingerprint that disagrees with the host's own UI by
  /// one character fails every legitimate verification while passing every
  /// illegitimate one.
  Future<String?> _fingerprintOf(String keyLine) async {
    final Process process;
    try {
      process = await Process.start(
        'ssh-keygen',
        ['-lf', '-'],
        environment: {
          'HOME': Directory.systemTemp.path,
          if (pathPrefix != null) 'PATH': _pinnedPath,
        },
      );
    } on Object {
      return null;
    }
    final stdoutText = process.stdout.transform(utf8.decoder).join();
    int code;
    try {
      // The newline is load-bearing: `ssh-keygen -lf -` reads a line, and an
      // unterminated write leaves it waiting for more input for ever.
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

  /// Environment applied to every bare-name helper this class spawns.
  ///
  /// Null unless [pathPrefix] was given, so production spawns nothing with a
  /// `PATH` it did not already inherit.
  Map<String, String>? get _helperEnvironment =>
      pathPrefix == null ? null : {'PATH': _pinnedPath};

  /// `PATH` with [pathPrefix] in front of the ambient value.
  ///
  /// The separator is the PATH *list* separator (`:`), not
  /// [Platform.pathSeparator] — which is `/` on POSIX and the wrong character
  /// entirely. Joining with the wrong one does not fail loudly: it produces a
  /// single nonsense entry, the pinned directory silently stops taking effect,
  /// and the real helper on `PATH` is found instead. That failure mode — a
  /// security control quietly not applying — is why this is a named getter with
  /// the reasoning attached rather than an inline template.
  String get _pinnedPath =>
      '$pathPrefix$_pathListSeparator${Platform.environment['PATH'] ?? ''}';

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
        // ---- Obligation 3: the private half reaches git HERE and nowhere
        // else. An environment variable, for one invocation. ----
        'GIT_SSH_COMMAND': wrapperPath,
        'GIT_SSH_VARIANT': 'ssh',
        // Nothing here may block on a human. A call waiting on a passphrase
        // prompt holds the private half in memory for as long as the prompt is
        // up.
        'GIT_TERMINAL_PROMPT': '0',
        'GIT_ASKPASS': '',
        // ---- Obligation 4: redirect the ambient environment. ----
        'HOME': Directory(clonePath).parent.path,
        'GIT_CONFIG_GLOBAL': '/dev/null',
        'GIT_CONFIG_SYSTEM': '/dev/null',
        if (pathPrefix != null) 'PATH': _pinnedPath,
      },
    );
    if (result.exitCode != 0) {
      throw DurableWorkspaceMaterializationException(
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
        // The reads have to come from the SAME git as the clone. Leaving these
        // on the ambient `PATH` while the clone is pinned would let a test — or
        // an attacker who can write to an earlier `PATH` entry — report a
        // revision or a config listing that no pinned git ever produced.
        if (pathPrefix != null) 'PATH': _pinnedPath,
      },
    );
    if (result.exitCode != 0) return null;
    return (result.stdout as String).trim();
  }

  /// Runs a helper to completion, or kills its process tree and refuses.
  ///
  /// `Future.timeout` stops the *Dart* side from waiting and nothing more: the
  /// child keeps running, holding the identity file. Owning the [Process] is
  /// the only way to stop that, so a helper this class spawned and abandoned —
  /// still holding a deploy key — is exactly what must not happen.
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
      await exit
          .timeout(const Duration(seconds: 5))
          .catchError((Object _) => -1);
      unawaited(stdoutText.catchError((Object _) => ''));
      unawaited(stderrText.catchError((Object _) => ''));
      throw DurableWorkspaceMaterializationException(
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
  /// and a quoting bug there is a path-shaped bug. **It holds no secret** —
  /// only two paths under the product root and a port. The private half it
  /// points at is deleted before this materializer returns, which is what makes
  /// the wrapper harmless to have existed at all.
  String _sshWrapper({
    required String identityPath,
    required String knownHostsPath,
    required int port,
  }) =>
      '''
#!/bin/sh
# Generated by SshDurableWorkspaceMaterializer. Holds no key material: the
# identity it names lives beside this script in an owner-only directory, and is
# deleted before the materialisation returns. Nothing durable is ever configured
# to point here.
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

  /// Replaces the product root and truncates, so a diagnostic is safe to persist
  /// and show an operator.
  static String _sanitise(String text, [String? productRoot]) {
    var out = productRoot == null
        ? text
        : text.replaceAll(productRoot, '<product-workspace>');
    const limit = 500;
    return out.length <= limit
        ? out
        : '${out.substring(0, limit)}… (truncated)';
  }

  /// Deletes the credential material and confirms it is gone.
  ///
  /// Returns whether it succeeded; the caller decides what a failure means,
  /// because it means different things on the success and failure paths.
  static bool _destroyCredentialMaterial(
    String identityPath,
    String knownHostsPath,
    String wrapperPath,
  ) {
    var clean = true;
    for (final path in [identityPath, knownHostsPath, wrapperPath]) {
      try {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      } on Object {
        clean = false;
      }
      if (File(path).existsSync()) clean = false;
    }
    return clean;
  }

  /// Deletes a tree and confirms it is gone.
  ///
  /// Retries once: a clone killed mid-write can leave an entry that disappears
  /// on the next pass. The existence check is the verdict.
  static bool _destroy(Directory directory) {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      } on Object {
        // The check below decides; this is only a reason to retry.
      }
      if (!directory.existsSync()) return true;
    }
    return false;
  }
}

/// Raised when the product root already exists, so this call does not own it.
///
/// ## Why a refusal and not a cleanup
///
/// The alternative — materialise into it and remove it if anything goes wrong —
/// makes "the git command failed" mean "this product's checkout is gone". The
/// root is derived from `$workspaceRoot/$productId` and nothing else, so it can
/// hold a previous run's clone with its object store and whatever an
/// implementation lane has committed into it. Nothing has been handed to a
/// caller on a failure path, which is true, and which is why the previous code
/// believed it had nothing to preserve — but that is an argument about the
/// DESCRIPTOR being absent, and it was used to license destroying a TREE.
///
/// So the root is left exactly as found and the operator decides what happens to
/// it. Nothing is written into it on this path, so there is nothing to undo and
/// nothing to clean up.
///
/// ## Why the alternatives were worse
///
/// This is where a class has to choose what "mine" means, and every weaker
/// definition loses in the same direction — toward deleting state somebody else
/// put there:
///
///  * **A marker file** this class writes into the root, and trusts as proof of
///    ownership. It answers "did *some* call, ever, create this" instead of "did
///    *this* call", and the two differ exactly where it matters: a tree an
///    implementation lane has since committed into still carries its class's
///    marker, so a marker-based destroy removes that work. It is also absent
///    precisely when a root pre-existed for an unrelated reason — an operator's
///    directory, a restored backup, a version of this code from before the
///    marker existed — which is the case the guard is for.
///  * **`git rev-parse --git-dir` on the existing tree.** It answers "is there a
///    repository here", which is a different question, and it answers it in the
///    wrong direction: a real product checkout IS a repository, so the probe
///    classifies the most valuable thing under this root as the thing to delete.
///    It also cannot describe an empty pre-existing directory at all, and it
///    spends a spawned process to re-derive a fact `Directory.existsSync` states
///    exactly.
///  * **Deleting only `$root/checkout` and keeping the root.** Better than the
///    recursive delete, and still wrong: once the entry guard refuses, there is
///    nothing to delete, and without the refusal this would delete the clone a
///    previous run made — which is the data loss being prevented.
///
/// A plain existence check is the strongest of these because it is the only one
/// that cannot be fooled by the contents of the thing being judged. It is also
/// the cheapest: no process, no network, no trust in state this class wrote on
/// an earlier run.
class DurableWorkspaceRootCollisionException implements Exception {
  const DurableWorkspaceRootCollisionException({
    required this.productId,
    required this.repositoryId,
    required this.productRoot,
    required this.findings,
  });

  final String productId;
  final String repositoryId;

  /// The root that was found already present. Nothing was written into it and
  /// nothing was removed from it.
  final String productRoot;

  /// What was already there, so the operator is told what they are looking at
  /// rather than only that something is.
  ///
  /// Diagnostic, and deliberately not a verdict: it describes the collision so
  /// it can be recognised, and never says whether the contents are safe to
  /// delete. This class has no way to know that — they may be unreviewed work.
  final List<String> findings;

  @override
  String toString() =>
      'DurableWorkspaceRootCollisionException: the product root '
      '$productRoot for $productId/$repositoryId already exists '
      '(${findings.isEmpty ? 'it is not empty and could not be enumerated' : findings.join("; ")}). '
      'This call did not create it, so it did not remove it: a durable clone '
      'holds an object store and any unreviewed commits made into it, and '
      'deciding whether those survive is an operator\'s call, not a side effect '
      'of a failed git command. Nothing was written into the root.';
}

/// What is already under a colliding product root, as short readable phrases.
///
/// Best effort, and it MUST stay that way: a refusal is raised with this text
/// attached, so failing to ENUMERATE the collision must never turn a safe
/// refusal into a different failure. An unreadable directory reports itself as
/// unreadable, which is still true and still actionable.
List<String> _describeExistingRoot(String productRoot, String clonePath) {
  final findings = <String>[];
  try {
    if (Directory(clonePath).existsSync()) {
      final hasObjects = Directory('$clonePath/.git/objects').existsSync();
      findings.add(
        hasObjects
            ? 'an existing clone with its own git object store is already at '
                  '${SshDurableWorkspaceMaterializer.cloneDirectoryName}/'
            : 'a directory named '
                  '${SshDurableWorkspaceMaterializer.cloneDirectoryName}/ '
                  'that is not a git working tree',
      );
    }
    if (File('$productRoot/.gitignore').existsSync()) {
      findings.add('the commit guard this class writes is already present');
    }
    final entries = Directory(
      productRoot,
    ).listSync().map((e) => e.path.split('/').last).toList();
    if (entries.isNotEmpty) {
      findings.add(
        'it holds ${entries.length} ${entries.length == 1 ? "entry" : "entries"}',
      );
    } else {
      findings.add('it is empty');
    }
  } on Object {
    if (findings.isEmpty) {
      findings.add('its contents could not be read');
    }
  }
  return findings;
}

/// Writes the ignore guard into a product root.
///
/// Best effort by construction, and deliberately so: this guards against a
/// plausible misconfiguration, it is not a trust boundary, and a root this
/// process cannot write is a root the clone could not have been created under
/// either — `PosixFileModes` would have refused first. Failing to write it is
/// therefore never thrown, so the refusal an operator ends up reading names the
/// real problem rather than this side effect.
void _guardRootAgainstCommitting(String productRoot) {
  try {
    File('$productRoot/.gitignore').writeAsStringSync('*\n');
  } on Object {
    // See above: recorded by its own absence, not by a throw.
  }
}

/// The separator for a PATH **list**.
///
/// Named rather than written inline at each use because getting it wrong does
/// not fail loudly — it produces a single nonsense PATH entry, the pinned
/// directory silently stops taking effect, and the real helper is found
/// instead. A security control that quietly stops applying is the failure mode
/// a named constant with a reason attached exists to prevent.
const String _pathListSeparator = ':';

/// Raised when `git` refused to materialise the durable clone.
///
/// Operator-facing and safe to persist: git's own diagnostic with the product
/// root replaced and truncated. It never contains key material, because the
/// identity file's path is the only thing this code ever passed to a command.
class DurableWorkspaceMaterializationException implements Exception {
  const DurableWorkspaceMaterializationException({
    required this.repositoryId,
    required this.command,
    required this.detail,
  });

  final String repositoryId;
  final String command;
  final String detail;

  @override
  String toString() =>
      'DurableWorkspaceMaterializationException: $command could not materialise '
      '$repositoryId — $detail';
}

/// Raised when the clone is not at the commit it was asked for.
///
/// A refusal to proceed, never a degraded result handed back: a descriptor
/// naming a commit the tree is not at would be read back by every later
/// execution, and the engineering review gate would fail closed on it with no
/// indication that the tree had drifted.
class DurableWorkspaceNotPinnedException implements Exception {
  const DurableWorkspaceNotPinnedException({
    required this.productId,
    required this.repositoryId,
    required this.pinnedRevision,
    required this.observedRevision,
  });

  final String productId;
  final String repositoryId;
  final String pinnedRevision;
  final String observedRevision;

  @override
  String toString() =>
      'DurableWorkspaceNotPinnedException: $productId/$repositoryId was asked '
      'for $pinnedRevision and the clone is at $observedRevision';
}

/// Raised when credential material or a partially built tree could not be
/// removed.
///
/// An incident rather than a result, and deliberately not swallowed. A deploy
/// key left on disk beside a product's checkout is the exact defect the six
/// obligations exist to prevent, and a silent cleanup failure is how it would
/// come back.
class DurableWorkspaceCleanupException implements Exception {
  const DurableWorkspaceCleanupException(this.productRoot);

  final String productRoot;

  @override
  String toString() =>
      'DurableWorkspaceCleanupException: credential material or a partial clone '
      'under $productRoot could not be removed and must be dealt with by hand';
}
