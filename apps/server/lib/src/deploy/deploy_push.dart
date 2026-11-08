import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart'
    show ProductRegistryEngine;

import '../credentials/posix_file_permissions.dart';
import '../credentials/secret_material.dart' show SecretBytes;
import '../credentials/secret_provider.dart' show SecretProvider;
import '../credentials/secret_provider_resolver.dart' show kSecretProviderEnv;
import '../credentials/secretless_error.dart'
    show AuditedFailure, secretlessText;
import '../credentials/ssh_remote.dart';

/// What one push of the landed branch to the product remote concluded.
enum DeployPushState {
  /// The remote did not contain the landed head; `git push` moved it there
  /// and the remote tip was re-read to prove it.
  pushed,

  /// The remote already contained the landed head — a replayed approve, a
  /// retried re-land, or a concurrent writer that landed the same commit.
  /// Idempotent by construction: nothing was pushed and nothing needed to
  /// be.
  alreadyCurrent,
}

/// What the push half of a deploy land established.
///
/// Carries no credential: [remoteUrl] is an address — the same class of
/// value `RepositorySnapshot.sourceRef` and `DurableWorkspaceClone.sourceRef`
/// already carry — never a key, a fingerprint, or a reference name.
class DeployPush {
  const DeployPush({
    required this.state,
    required this.remoteUrl,
    required this.branch,
    required this.remoteHead,
  });

  /// Whether the push moved the remote or found it already containing the
  /// landed head.
  final DeployPushState state;

  /// The normalized `ssh://` URL the push targeted — the checkout's own
  /// `origin`, verified against the product's registry record.
  final String remoteUrl;

  /// The remote branch that now contains the landed commit — the product's
  /// default branch, the same branch the merge landed into.
  final String branch;

  /// The remote's tip of [branch] AFTER the push was verified. For
  /// [DeployPushState.pushed] this is the landed head itself; for
  /// [DeployPushState.alreadyCurrent] it is whatever tip already contains
  /// it (which may be ahead of it).
  final String remoteHead;

  @override
  String toString() =>
      'DeployPush(${state.name} $branch -> $remoteUrl@$remoteHead)';
}

/// Raised when the push half of a deploy land refuses to proceed, or git
/// refused it.
///
/// The deploy-landing vocabulary for a refused land is
/// `DeployLandingException`; this is the push subsystem's own refusal, which
/// `deploy_landing.dart` renders through `secretlessText` into that
/// vocabulary. Keeping the type separate keeps `deploy_push.dart` free of a
/// cycle back into the land — the land consumes it; it does not produce it.
///
/// [reason] is safe to surface to the operator who approved the deploy: it
/// interpolates repository paths, branch names, revisions, git exit reports
/// and audited failure descriptions — never a credential, a private half, or
/// a reference name.
class DeployPushRefusedException implements Exception, AuditedFailure {
  const DeployPushRefusedException(this.reason);

  final String reason;

  @override
  String get secretlessDescription => 'DeployPushRefusedException: $reason';

  @override
  String toString() => secretlessDescription;
}

/// Raised when the credential-material scratch a push created could not be
/// removed.
///
/// The same rule the snapshot and durable-workspace materializers hold: a
/// live deploy-key identity left on disk is an incident, never a result. The
/// [path] is what an operator needs to remove it; it contains no key
/// material.
class DeployPushCleanupException implements Exception, AuditedFailure {
  const DeployPushCleanupException(this.path);

  final String path;

  @override
  String get secretlessDescription =>
      'DeployPushCleanupException: could not remove the deploy-push '
      'credential scratch at $path';

  @override
  String toString() => secretlessDescription;
}

/// The push half of `landApprovedDeployment` (F-258). A port, so the land's
/// "a verified merge is pushed to the product remote" claim can be exercised
/// without a git host — and so a caller that cannot wire the credential path
/// can still be refused honestly rather than silently skipping the push.
///
/// ## What a refusal means
///
/// Implementations refuse by throwing. `landApprovedDeployment` renders the
/// failure as a `DeployLandingException`, which writes nothing durable — the
/// approval decision stays pending, the merge stays local, and a retried
/// approve or re-land completes the interrupted push through the
/// already-landed arm. A pusher must therefore be IDEMPOTENT: a remote that
/// already contains the landed head is a success, not an error.
abstract interface class DeployPusher {
  /// Pushes the landed state of [targetBranch] in [repositoryPath] to the
  /// checkout's product remote, or throws.
  ///
  /// [item] is the work item the deploy belongs to — its `productId` scopes
  /// which registered repository and which credential may authenticate the
  /// push. [localHead] is the verified post-land tip of the branch — the
  /// exact revision the remote must end up containing.
  Future<DeployPush> pushLandedBranch({
    required WorkItem item,
    required String repositoryPath,
    required String targetBranch,
    required String localHead,
  });
}

/// The transport a [RegistryDeployPusher] hands the resolved credential to.
///
/// A port for the same reason the snapshot and durable-workspace
/// materializers are ports: the trust logic above it — which
/// credential, which repository, which checks — has to be exercisable without
/// a git host. Implementations MUST enforce [confirmedHostKeyFingerprint]
/// themselves: a transport that trusts whatever host answers is the ADR 0018
/// A2 gap reopened at the one seam a deploy cannot audit later.
abstract interface class DeployPushTransport {
  /// Pushes [localHead] to `refs/heads/[branch]` on the checkout's `origin`
  /// remote — the remote [remote] was resolved FROM — using the confirmed
  /// host key and the private half.
  ///
  /// [repositoryPath] is the clone the land merged into; its `origin`
  /// remote is what receives the push, which is what makes the push land
  /// where the clone itself was recorded as coming from. [productId] and
  /// [repositoryId] travel only for refusal context — they are never
  /// persisted by the transport and never reach a command line.
  Future<DeployPush> pushBranchToRemote({
    required String productId,
    required String repositoryId,
    required String repositoryPath,
    required String branch,
    required String localHead,
    required SshRemote remote,
    required SecretBytes privateKeyPem,
    required String confirmedHostKeyFingerprint,
  });
}

/// The production [DeployPusher]: resolves the product's verified deploy key
/// from the checkout's own `origin` and hands the push to a
/// [DeployPushTransport].
///
/// ## The credential resolution, in order
///
/// ```text
///   git remote get-url origin          (the checkout's own record of where
///                                       it pushes — read, never guessed)
///   parseSshRemote                     (refuse a non-SSH origin honestly)
///   match registered repositories      (the product's OWN registry rows,
///                                       normalized so scp-like and ssh://
///                                       forms name the same remote)
///   readActiveCredential               (the ACTIVE credential for THAT
///                                       repository — never a product-wide one)
///   provenance checks                  (the same ones the durable-workspace
///                                       provisioner runs before it clones)
///   one secret read by reference name  (wiped in `finally` on every path)
///   transport.pushBranchToRemote
/// ```
///
/// ## Why `verifyAccess` is deliberately NOT on this chain
///
/// The workspace provisioner runs `CredentialKeyService.verifyAccess` before
/// it clones, because a provisioning that cannot reach the repository must
/// not record a workspace. A deploy push is different: the transport's own
/// `ls-remote`/`fetch`/`push` IS the live check — it exercises the private
/// half against the same confirmed host key, enforced at the socket, and a
/// refused push is already the honest outcome `verifyAccess` would have
/// predicted. Running it first would add a full clone per deploy AND write
/// credential-check state (`recordCredentialCheck`, `confirmHostKey`) that
/// belongs to the verification endpoint's audit trail, not a deploy's.
class RegistryDeployPusher implements DeployPusher {
  const RegistryDeployPusher({
    required this.engine,
    required this.secretProvider,
    required this.transport,
    this.git = 'git',
    this.gitTimeout = const Duration(seconds: 60),
    this.log,
  });

  /// The durable product registry — the only authority on which repository
  /// a remote URL names and which credential is active for it.
  final ProductRegistryEngine engine;

  /// The custody substrate the private half is read from, or `null` when
  /// the composition root could not select one. Null is a refusal, not a
  /// skip: there is no credential to authenticate the push with, and
  /// proceeding without one is exactly the "lands locally only" defect this
  /// push exists to close.
  final SecretProvider? secretProvider;

  final DeployPushTransport transport;

  final String git;
  final Duration gitTimeout;

  final void Function(String event, Map<String, dynamic> data)? log;

  @override
  Future<DeployPush> pushLandedBranch({
    required WorkItem item,
    required String repositoryPath,
    required String targetBranch,
    required String localHead,
  }) async {
    final provider = secretProvider;
    if (provider == null) {
      throw DeployPushRefusedException(
        'no credential custody substrate is configured ($kSecretProviderEnv '
        'is unset or names nothing this build can construct), so the deploy '
        'key that would authenticate this push cannot be read. The merge '
        'stays local; the approval decision stays pending.',
      );
    }

    // (1) The checkout's own record of where it pushes. A checkout with no
    // `origin` has nowhere honest to push to — refusing here is what stops a
    // "deployed" claim that never left the machine.
    final originUrl = (await _gitMust(
      git,
      ['-C', repositoryPath, 'remote', 'get-url', 'origin'],
      gitTimeout,
      failure:
          'the recorded checkout $repositoryPath has no readable `origin` '
          'remote, so there is nowhere to push the landed branch — the '
          'deploy cannot be claimed to have reached the product remote.',
    )).trim();

    // (2) SSH or nothing. `parseSshRemote` refuses an `https://` origin for
    // the same reason it refuses one everywhere: ADR 0018 credentials are
    // deploy keys, and an https origin has no deploy key to authenticate
    // with. The refusal is rendered honestly rather than crashed on.
    final SshRemote remote;
    try {
      remote = parseSshRemote(originUrl);
    } on UnsupportedRepositoryUriException catch (error) {
      throw DeployPushRefusedException(
        'the recorded checkout\'s origin ($originUrl) is not an SSH remote — '
        '${error.secretlessDescription}. A deploy key cannot authenticate '
        'to it, so nothing was pushed.',
      );
    }

    // (3) The remote must name ONE registered repository of THIS product.
    // The comparison is the normalized `ssh://` form on both sides, so a
    // clone whose origin is the scp-like `git@host:path` and a registry row
    // recorded as `ssh://git@host:22/path` are the same remote. Zero matches
    // means the checkout pushes somewhere the product never registered —
    // nowhere an active credential could legitimately authenticate; more
    // than one means the credential is unresolvable rather than guessed.
    final normalized = remote.toSshUrl();
    final registered = await engine.readRepositories(item.productId);
    final matches = <RepositoryReference>[];
    for (final reference in registered) {
      final SshRemote registeredRemote;
      try {
        registeredRemote = parseSshRemote(reference.uri);
      } on UnsupportedRepositoryUriException {
        // A registered URI that is not SSH-parseable cannot name the same
        // SSH remote — skipped, not failed: the origin is what is being
        // matched.
        continue;
      }
      if (registeredRemote.toSshUrl() == normalized) {
        matches.add(reference);
      }
    }
    if (matches.isEmpty) {
      throw DeployPushRefusedException(
        'the recorded checkout\'s origin $normalized names no repository '
        'registered to product ${item.productId}, so no registered '
        'credential may authenticate the push. Nothing was pushed.',
      );
    }
    if (matches.length > 1) {
      throw DeployPushRefusedException(
        'the recorded checkout\'s origin $normalized matches '
        '${matches.length} registered repositories of product '
        '${item.productId} (${matches.map((r) => r.repositoryId).join(', ')}), '
        'so the credential to authenticate with is unresolvable. Nothing '
        'was pushed.',
      );
    }
    final repositoryId = matches.single.repositoryId;

    // (4) The ACTIVE verified credential — the same provenance checks the
    // durable-workspace provisioner runs before it clones, because the
    // private half about to be read is the same one.
    final credential = await engine.readActiveCredential(
      item.productId,
      repositoryId,
    );
    if (credential == null) {
      throw DeployPushRefusedException(
        'no credential has been minted for repository $repositoryId, so '
        'there is no deploy key to authenticate the push with. Nothing was '
        'pushed.',
      );
    }
    final hostKeyFingerprint = credential.hostKeyFingerprint;
    if (hostKeyFingerprint == null || hostKeyFingerprint.trim().isEmpty) {
      throw DeployPushRefusedException(
        'no host key fingerprint has been confirmed for repository '
        '$repositoryId; a deploy key fingerprint is not one and was not '
        'substituted. Nothing was pushed.',
      );
    }
    if (hostKeyFingerprint.trim() == credential.fingerprint.trim()) {
      throw DeployPushRefusedException(
        'the value recorded as the host key fingerprint for repository '
        '$repositoryId is this credential\'s own public-key fingerprint — '
        'different values with different provenance. Nothing was pushed.',
      );
    }
    if (!credential.isHostConfirmed) {
      throw DeployPushRefusedException(
        'the host key for repository $repositoryId has not been confirmed '
        'by a human, so the trust decision enforced at the socket has no '
        'provenance to enforce. Nothing was pushed.',
      );
    }
    if (!credential.canReachRepository) {
      throw DeployPushRefusedException(
        'the credential for repository $repositoryId is not currently '
        'usable (status ${credential.status.wire}, host key '
        '${credential.hostKeyStatus.wire}). Nothing was pushed.',
      );
    }
    final confirmedBy = credential.hostConfirmedBy;
    if (confirmedBy == null || confirmedBy.trim().isEmpty) {
      throw DeployPushRefusedException(
        'the confirmed host key for repository $repositoryId records no '
        'confirming human, so the trust decision is unattributable. '
        'Nothing was pushed.',
      );
    }

    // (5) The ONE read of private material, by reference name — never a
    // path, never cached, wiped on every path out. `CredentialKeyService
    // .generate` is deliberately NOT the way in: it mints a NEW deploy key,
    // which is credential lifecycle, not transport.
    final material = await provider.read(
      referenceName: credential.referenceName,
    );
    try {
      final push = await transport.pushBranchToRemote(
        productId: item.productId,
        repositoryId: repositoryId,
        repositoryPath: repositoryPath,
        branch: targetBranch,
        localHead: localHead,
        remote: remote,
        privateKeyPem: material,
        confirmedHostKeyFingerprint: hostKeyFingerprint,
      );
      log?.call('deploy.push.${push.state.name}', {
        'workItemId': item.workItemId,
        'productId': item.productId,
        'repositoryId': repositoryId,
        'repositoryPath': repositoryPath,
        'targetBranch': targetBranch,
        'remoteUrl': push.remoteUrl,
        'remoteHead': push.remoteHead,
      });
      return push;
    } on DeployPushRefusedException {
      rethrow;
    } on Object catch (error) {
      throw DeployPushRefusedException(
        'the push of $targetBranch in $repositoryPath to $normalized was '
        'refused: ${secretlessText(error)}. Nothing durable was written.',
      );
    } finally {
      material.wipe();
    }
  }
}

/// The production [DeployPushTransport]: a real `git` fetch/push of the
/// landed branch over SSH, with the confirmed host key enforced at the
/// socket and no credential left on disk.
///
/// ## What is borrowed, and why it is borrowed rather than shared
///
/// The scratch layout, the `0700`/`0600` modes, the scan-then-match
/// `known_hosts` construction, the `GIT_SSH_COMMAND` wrapper script and the
/// ambient-environment redirection are the ones the pinned-snapshot and
/// durable-workspace materializers use — reproduced here for the third
/// time, for the same reason the second reproduction was taken: those classes'
/// materialization is private to their own lifecycles, and the honest fix is a
/// shared materialization seam, which is a recorded finding rather than this
/// task's scope. The three must be changed together; this comment and theirs
/// are the markers that say so.
///
/// ## The push itself — fetch, ancestry, push, re-fetch, verify
///
/// `pushBranchToRemote` is verify-not-repush the way the land is
/// verify-not-remerge:
///
///   * `ls-remote` reads the remote tip — a read, never a mutation.
///   * a remote that already contains the landed head answers
///     [DeployPushState.alreadyCurrent] — a retried approve or re-land
///     completes an interrupted push instead of failing on it.
///   * a remote tip that is an ancestor of the landed head is pushed;
///   * a remote tip that is NEITHER is a divergence — refused, never
///     forced. A rejected push re-reads the remote tip once before
///     refusing, so a concurrent pusher that raced the same head is
///     reported as already-current rather than as a failure;
///   * after `git push` reports success the remote tip is re-read and the
///     landed head must be reachable from it — a reported success is not
///     proof.
class SshDeployPushTransport implements DeployPushTransport {
  const SshDeployPushTransport({
    this.connectTimeout = const Duration(seconds: 20),
    this.remoteTimeout = const Duration(minutes: 5),
    this.scratchPrefix = 'deploy_push_',
    this.gitExecutable = 'git',
    this.pathPrefix,
  });

  final Duration connectTimeout;

  /// The bound on `fetch`/`push` — remote operations that may move real
  /// objects, distinct from the cheap reads `ls-remote` and `ssh-keyscan`
  /// perform.
  final Duration remoteTimeout;
  final String scratchPrefix;
  final String gitExecutable;

  /// Prepended to `PATH` for every helper this class spawns — `git`,
  /// `ssh-keyscan`, `ssh-keygen` and the `ssh` the wrapper execs.
  ///
  /// The same seam the two materializers carry, for the same reason: the
  /// helpers resolve by bare name through `PATH`, so a test pins stub
  /// `ssh-keyscan` (and a stub `git` where the invocation environment, not
  /// the remote, is the subject) while real `ssh-keygen` still computes the
  /// fingerprint. Null — the default, and the only value production uses —
  /// keeps the ambient `PATH` exactly as it was.
  final String? pathPrefix;

  @override
  Future<DeployPush> pushBranchToRemote({
    required String productId,
    required String repositoryId,
    required String repositoryPath,
    required String branch,
    required String localHead,
    required SshRemote remote,
    required SecretBytes privateKeyPem,
    required String confirmedHostKeyFingerprint,
  }) async {
    final scratch = Directory.systemTemp.createTempSync(scratchPrefix);
    try {
      PosixFileModes.applyStrict(scratch.path, PosixFileModes.directory);
      final identityPath = '${scratch.path}/identity';
      final knownHostsPath = '${scratch.path}/known_hosts';
      final wrapperPath = '${scratch.path}/ssh-wrapper.sh';

      // Host key BEFORE the private half, exactly as the materializers order
      // it: a call that is about to refuse has no reason to have written key
      // material first.
      final matched = await _matchConfirmedHostKeys(
        remote,
        confirmedHostKeyFingerprint,
      );
      if (matched.isEmpty) {
        throw DeployPushRefusedException(
          'the host ${remote.host}:${remote.port} presented no key matching '
          'the confirmed fingerprint for repository $repositoryId — '
          'pushing to it would trust whoever answered, which is the ADR '
          '0018 A2 gap. Nothing was pushed.',
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

      final environment = <String, String>{
        'GIT_SSH_COMMAND': wrapperPath,
        'GIT_SSH_VARIANT': 'ssh',
        // Nothing here may block on a human: a prompt would hold the
        // private half in memory for as long as it is up.
        'GIT_TERMINAL_PROMPT': '0',
        'GIT_ASKPASS': '',
        // Redirect the ambient environment at the scratch tree: a
        // developer's ~/.ssh/config can add IdentityFile, ProxyCommand or
        // RemoteCommand, and a global gitconfig can add `url.*.insteadOf`.
        // None of them gets a say in a push that holds a deploy key.
        'HOME': scratch.path,
        'GIT_CONFIG_GLOBAL': '/dev/null',
        'GIT_CONFIG_SYSTEM': '/dev/null',
        if (pathPrefix != null) 'PATH': _pinnedPath,
      };

      final push = await _pushSequence(
        environment: environment,
        repositoryPath: repositoryPath,
        branch: branch,
        localHead: localHead,
        remote: remote,
      );
      if (!_destroy(scratch)) {
        throw DeployPushCleanupException(scratch.path);
      }
      return push;
    } on Object {
      if (!_destroy(scratch)) {
        throw DeployPushCleanupException(scratch.path);
      }
      rethrow;
    }
  }

  /// The verify-not-repush sequence described on the class.
  Future<DeployPush> _pushSequence({
    required Map<String, String> environment,
    required String repositoryPath,
    required String branch,
    required String localHead,
    required SshRemote remote,
  }) async {
    final remoteUrl = remote.toSshUrl();
    final ref = 'refs/heads/$branch';

    // (1) The remote tip — a READ. `ls-remote` answers what the remote
    // holds without fetching a single object, and it is the only way to
    // distinguish "no such branch" from "branch at <tip>" honestly.
    var remoteTip = await _remoteTip(
      environment,
      repositoryPath,
      branch,
      remoteUrl,
    );
    if (remoteTip == localHead) {
      return DeployPush(
        state: DeployPushState.alreadyCurrent,
        remoteUrl: remoteUrl,
        branch: branch,
        remoteHead: remoteTip!,
      );
    }
    if (remoteTip != null) {
      // Ancestry needs the remote's objects locally, so fetch first. This
      // is also the live exercise of the credential — the fetch is the
      // proof the private half reaches this remote.
      await _fetch(environment, repositoryPath, branch, remoteUrl);
      if (await _isAncestor(
        environment,
        repositoryPath,
        localHead,
        remoteTip,
      )) {
        return DeployPush(
          state: DeployPushState.alreadyCurrent,
          remoteUrl: remoteUrl,
          branch: branch,
          remoteHead: remoteTip,
        );
      }
      if (!await _isAncestor(
        environment,
        repositoryPath,
        remoteTip,
        localHead,
      )) {
        throw DeployPushRefusedException(
          '$ref on $remoteUrl is at $remoteTip, which is neither the '
          'landed $localHead nor an ancestor of it — the remote holds '
          'commits the landed branch does not, so pushing would discard '
          'them. A force-push is deliberately not the answer: the remote '
          'moved under the deploy and a human reconciles it, the platform '
          'does not overwrite it.',
        );
      }
    }

    // (2) THE PUSH. On a failure the remote tip is re-read once: a
    // concurrent writer that landed the same head between the `ls-remote`
    // above and this push makes the rejection already-current, and a
    // remote that advanced to a new ancestor of the landed head gets one
    // retry — beyond that the rejection is honest.
    var push = await _tryPush(environment, repositoryPath, ref, localHead);
    if (push.exitCode != 0) {
      final firstStderr = _stderr(push);
      final recheck = await _remoteTip(
        environment,
        repositoryPath,
        branch,
        remoteUrl,
      );
      var settled = recheck == localHead;
      if (!settled && recheck != null) {
        await _fetch(environment, repositoryPath, branch, remoteUrl);
        if (await _isAncestor(
          environment,
          repositoryPath,
          localHead,
          recheck,
        )) {
          settled = true;
        } else if (await _isAncestor(
          environment,
          repositoryPath,
          recheck,
          localHead,
        )) {
          push = await _tryPush(environment, repositoryPath, ref, localHead);
          settled = push.exitCode == 0;
        }
      }
      if (!settled) {
        throw DeployPushRefusedException(
          'git push of $localHead to $ref on $remoteUrl was rejected '
          '(exit ${push.exitCode}): ${_stderr(push)} — first rejection: '
          '$firstStderr. Nothing durable was written; the merge stays '
          'local and the approval decision stays pending.',
        );
      }
      if (recheck == localHead) {
        return DeployPush(
          state: DeployPushState.alreadyCurrent,
          remoteUrl: remoteUrl,
          branch: branch,
          remoteHead: localHead,
        );
      }
    }

    // (3) VERIFY — a reported success is not proof. The remote tip is
    // re-read and the landed head must be reachable from it: equal on the
    // ordinary arm, an ancestor when a concurrent push moved the tip past
    // it.
    final after = await _remoteTip(
      environment,
      repositoryPath,
      branch,
      remoteUrl,
    );
    if (after == localHead) {
      return DeployPush(
        state: DeployPushState.pushed,
        remoteUrl: remoteUrl,
        branch: branch,
        remoteHead: localHead,
      );
    }
    if (after != null) {
      await _fetch(environment, repositoryPath, branch, remoteUrl);
      if (await _isAncestor(environment, repositoryPath, localHead, after)) {
        return DeployPush(
          state: DeployPushState.pushed,
          remoteUrl: remoteUrl,
          branch: branch,
          remoteHead: after,
        );
      }
    }
    throw DeployPushRefusedException(
      'git push of $localHead to $ref on $remoteUrl reported success, but '
      'the remote tip is ${after ?? 'absent'}, which does not contain '
      '$localHead. The deploy is NOT claimed pushed; the merge stays '
      'local and the approval decision stays pending.',
    );
  }

  /// The remote's tip of `refs/heads/[branch]`, or `null` when the remote
  /// holds no such branch. A transport failure is a refusal, not an empty
  /// read — an unreachable remote must not read as "branch absent".
  Future<String?> _remoteTip(
    Map<String, String> environment,
    String repositoryPath,
    String branch,
    String remoteUrl,
  ) async {
    final result = await _runBounded(
      'git',
      gitExecutable,
      [
        '--no-pager',
        '-C',
        repositoryPath,
        'ls-remote',
        'origin',
        'refs/heads/$branch',
      ],
      connectTimeout,
      environment: environment,
    );
    if (result.exitCode != 0) {
      throw DeployPushRefusedException(
        'git ls-remote against $remoteUrl could not be evaluated (exit '
        '${result.exitCode}): ${_stderr(result)} — the remote is '
        'unreachable or the credential was refused, so nothing was pushed.',
      );
    }
    for (final line in (result.stdout as String).split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final tab = trimmed.indexOf('\t');
      final sha = (tab < 0 ? trimmed : trimmed.substring(0, tab)).trim();
      if (sha.isNotEmpty) return sha;
    }
    return null;
  }

  /// Downloads the remote's objects for `refs/heads/[branch]` so ancestry
  /// can be evaluated. A fetch failure is a refusal — the remote answered
  /// `ls-remote`, so a failed fetch is connectivity or credentials, not a
  /// missing branch.
  Future<void> _fetch(
    Map<String, String> environment,
    String repositoryPath,
    String branch,
    String remoteUrl,
  ) async {
    final result = await _runBounded(
      'git',
      gitExecutable,
      [
        '--no-pager',
        '-C',
        repositoryPath,
        'fetch',
        '--no-tags',
        '--quiet',
        'origin',
        'refs/heads/$branch',
      ],
      remoteTimeout,
      environment: environment,
    );
    if (result.exitCode != 0) {
      throw DeployPushRefusedException(
        'git fetch of refs/heads/$branch from $remoteUrl failed (exit '
        '${result.exitCode}): ${_stderr(result)} — ancestry cannot be '
        'evaluated, so nothing was pushed.',
      );
    }
  }

  /// `merge-base --is-ancestor` over two revisions whose objects the fetch
  /// above made local. Exit 1 means "not an ancestor" — an answer, not a
  /// failure; anything else is a refusal because the ancestry could not be
  /// established.
  Future<bool> _isAncestor(
    Map<String, String> environment,
    String repositoryPath,
    String maybeAncestor,
    String descendant,
  ) async {
    final result = await _runBounded(
      'git',
      gitExecutable,
      [
        '--no-pager',
        '-C',
        repositoryPath,
        'merge-base',
        '--is-ancestor',
        maybeAncestor,
        descendant,
      ],
      connectTimeout,
      environment: environment,
    );
    if (result.exitCode == 0) return true;
    if (result.exitCode == 1) return false;
    throw DeployPushRefusedException(
      'git merge-base --is-ancestor $maybeAncestor $descendant could not '
      'be evaluated in $repositoryPath (exit ${result.exitCode}): '
      '${_stderr(result)} — the push cannot be verified and was refused.',
    );
  }

  /// One `git push` attempt: `localHead -> refs/heads/branch`. The exit
  /// code is the answer; the caller decides what a rejection means after
  /// re-reading the remote.
  Future<ProcessResult> _tryPush(
    Map<String, String> environment,
    String repositoryPath,
    String ref,
    String localHead,
  ) => _runBounded(
    'git',
    gitExecutable,
    [
      '--no-pager',
      '-C',
      repositoryPath,
      'push',
      'origin',
      '$localHead:$ref',
    ],
    remoteTimeout,
    environment: environment,
  );

  /// Host key lines whose `ssh-keygen -lf` fingerprint equals the
  /// confirmation — the same scan-then-match both materializers run, and
  /// for the same reason: the scan CHECKS a value whose provenance is
  /// already settled (a human confirmed it out of band), it never obtains
  /// one. Only the confirmed key is written to `known_hosts`; everything
  /// else the host presented would let a push succeed against a key nobody
  /// saw.
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
      // No scan, no push. An absent `ssh-keyscan` is a refusal, not a
      // reason to proceed unverified.
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
    return matched;
  }

  /// `ssh-keygen -lf -` for one authorized-keys line, or null. `ssh-keygen`
  /// rather than a hand-rolled SHA-256, for the reason the whole trust
  /// chain gives: a fingerprint that disagrees with the host's own UI by
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
      // The newline is load-bearing: `ssh-keygen -lf -` reads a line, and
      // an unterminated write leaves it waiting for more input for ever.
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

  /// Environment applied to every bare-name helper this class spawns. Null
  /// unless [pathPrefix] was given, so production spawns nothing with a
  /// `PATH` it did not already inherit.
  Map<String, String>? get _helperEnvironment =>
      pathPrefix == null ? null : {'PATH': _pinnedPath};

  /// `PATH` with [pathPrefix] in front of the ambient value. The separator
  /// is the PATH *list* separator (`:`), not `Platform.pathSeparator` — the
  /// reason both materializers name it rather than inline it.
  static const String _pathListSeparator = ':';
  String get _pinnedPath =>
      '$pathPrefix$_pathListSeparator${Platform.environment['PATH'] ?? ''}';

  /// The `ssh` invocation `git` is pointed at, as a standalone script —
  /// the same option set both materializers write, holding no secret: only
  /// two scratch paths and a port.
  String _sshWrapper({
    required String identityPath,
    required String knownHostsPath,
    required int port,
  }) =>
      '''
#!/bin/sh
# Generated by SshDeployPushTransport. Holds no key material: the identity
# it names lives beside this script in a 0700 scratch directory removed
# before the push returns.
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

  /// Runs a helper to completion, or kills its process tree and refuses —
  /// the same discipline the materializers keep: `Future.timeout` stops the
  /// Dart side from waiting and nothing more, and a child left running
  /// holds the identity file.
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
      throw DeployPushRefusedException(
        'the $helper helper could not be started: ${secretlessText(error)}',
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
      throw DeployPushRefusedException(
        'the $helper helper outlived ${timeout.inSeconds}s and its process '
        'tree was killed; a live git holding a deploy key is not something '
        'to leave running. Nothing was pushed.',
      );
    }
  }

  /// Deletes the credential scratch and confirms it is gone. Retries once,
  /// for the same reason the materializers do: a helper killed mid-write
  /// can leave an entry that disappears on the next pass. The existence
  /// check is the verdict.
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

/// A git invocation whose non-zero exit is a [DeployPushRefusedException].
Future<String> _gitMust(
  String git,
  List<String> args,
  Duration timeout, {
  String failure = 'a required git read failed',
}) async {
  final result = await _gitRun(git, args, timeout);
  if (result.exitCode != 0) {
    throw DeployPushRefusedException(
      '$failure `git ${args.join(' ')}` exited ${result.exitCode}: '
      '${_stderr(result)}',
    );
  }
  return result.stdout as String;
}

/// Runs git with a hard timeout for LOCAL reads (no credential, no SSH
/// environment), mirroring `deploy_landing.dart`'s `_gitRun` discipline:
/// a tool failure is a typed refusal, never a caller crash.
Future<ProcessResult> _gitRun(
  String git,
  List<String> args,
  Duration timeout,
) async {
  try {
    return await Process.run(
      git,
      args,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    ).timeout(timeout);
  } on TimeoutException {
    throw DeployPushRefusedException(
      'git ${args.join(' ')} exceeded $timeout; the push was not attempted.',
    );
  } on ProcessException catch (error) {
    throw DeployPushRefusedException(
      'git could not be run (${secretlessText(error)}); the push was not '
      'attempted.',
    );
  }
}

String _stderr(ProcessResult result) {
  final stderr = result.stderr.toString().trim();
  return stderr.isEmpty ? '(no stderr)' : stderr;
}
