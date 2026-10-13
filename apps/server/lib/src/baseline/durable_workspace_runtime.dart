import 'package:platform_contracts/platform_contracts.dart'
    show DurableWorkspaceDescriptor, OnboardingRecord, ProductBaselineStatus;
import 'package:product_registry/product_registry.dart'
    show ProductRegistryEngine;

import '../credentials/credential_key_service.dart';
import '../credentials/repository_access_verifier.dart';
import '../credentials/repository_snapshot_acquirer.dart'
    show HostKeyNotIndependentlyConfirmedException;
import '../credentials/secret_material.dart' show SecretBytes;
import '../credentials/secret_provider.dart' show SecretProvider;
import '../credentials/secret_provider_resolver.dart';
import '../credentials/ssh_remote.dart' show parseSshRemote;
import 'durable_workspace_materializer.dart';

/// The identity recorded as the principal provisioning and checking a durable
/// clone.
///
/// Named rather than left blank because `verifyAccess` persists `checkedBy`,
/// and a lane putting its own name where a confirming human belongs would forge
/// the one piece of provenance the host-key decision rests on.
const String _durableWorkspaceLanePrincipal = 'lane:durable-workspace';

/// The reason recorded when no custody substrate could be selected.
///
/// One named string, so the value in the startup banner, in any test and on any
/// refusal is the same one, and changing the wording does not mean finding
/// three spellings of it.
const String _custodyUnavailableReason =
    'No credential custody substrate is configured, so no product repository '
    'can be cloned and no durable workspace can be created. Select one with '
    '$kSecretProviderEnv (see ADR 0018: fallback selection is a recorded '
    'precondition, not a silent default). This is not a declined run — the '
    'durable-workspace runtime does not exist in this deployment.';

/// Creates and records a product's DURABLE, writable clone, and names it on the
/// product's onboarding record.
///
/// ## What this is for
///
/// A product-scoped clone that survives container restarts is a prerequisite of
/// implementation, and this is the object that makes one. It reuses the trust
/// chain the onboarding lane already composes — custody, key service, host-key
/// verification — and composes it with its OWN materialiser, because a durable
/// clone is not a `RepositorySnapshot` and must not acquire one and retain it
/// (a fresh clone has no local head, so the snapshot's retain test would
/// classify it read-only and destroy it).
///
/// ## What this is NOT
///
/// This does not clone, do a derivation, propose a baseline, enqueue a job, or
/// touch any lifecycle state. It creates storage and records where it is. The
/// lifecycle is the implementation lane's.
///
/// ## Why the workspace root is a PARAMETER and not a read here
///
/// The environment variable naming this root is a product name, and the
/// product-agnosticism gate (`product_agnosticism_test.dart`) refuses every
/// product name in this directory — mechanically, over every non-test `.dart`
/// file present. The read therefore belongs to the composition root, which is
/// outside the gate, and arrives here as an argument. See `resolve`.
class DurableWorkspaceRuntime {
  const DurableWorkspaceRuntime._({
    required this.engine,
    required this.provisioner,
    required this.workspaceRoot,
    required this.custodyRuntimeState,
    required this.availableReason,
    required this.log,
  });

  /// Builds the runtime over [engine], or records that it could not be built.
  ///
  /// ## PINNED SIGNATURE — the composition root writes against this
  ///
  /// ```dart
  /// final durable = DurableWorkspaceRuntime.resolve(
  ///   engine: engine,
  ///   durableWorkspaceRoot: durableWorkspaceRoot(),  // resolved in server.dart
  ///   log: (event, data) => logger.info(event, data),
  /// );
  /// ```
  ///
  /// [durableWorkspaceRoot] is REQUIRED and is the composition root's to
  /// resolve. There is deliberately no default and no fallback: a root this
  /// runtime cannot name is a runtime that would write into whatever directory
  /// the process happens to consider writable, which is the container-local
  /// state decision `9bfe2d09` exists to prevent. An empty or blank value is
  /// refused here rather than turned into `'.'`.
  ///
  /// [custodyProvider], [accessVerifier] and [materializer] are the
  /// composition's three seams, all defaulting to the production choice, and
  /// they exist because this is a composition ROOT: a root whose only inputs are
  /// a database and the process environment can only be exercised by standing up
  /// both. Passing any of them is never a way to weaken the lane — the
  /// materialiser enforces the confirmed host key on whatever it is handed, and
  /// a caller that supplies a materialiser which does not enforce it is
  /// supplying a broken lane.
  ///
  /// The refusal posture is the same one
  /// `BaselineProductionRuntime.resolve` established: the custody substrate is
  /// resolved rather than assumed, and a deployment without one gets an
  /// explicitly UNAVAILABLE runtime whose every call names the reason. It does
  /// not get a runtime that silently finds somewhere else to write.
  factory DurableWorkspaceRuntime.resolve({
    required ProductRegistryEngine engine,
    required String durableWorkspaceRoot,
    required void Function(String event, Map<String, dynamic> data) log,
    SecretProvider? custodyProvider,
    RepositoryAccessVerifier? accessVerifier,
    DurableWorkspaceMaterializer? materializer,
    Map<String, String>? environment,
  }) {
    final root = durableWorkspaceRoot.trim();
    if (root.isEmpty) {
      log('durable_workspace.root.unavailable', {
        'code': durableWorkspaceRootUnavailable,
        'error': 'the durable workspace root resolved to an empty path',
        'action':
            'no clone will be created; an unset root would otherwise write into '
            'container-local state that is lost on the next rebuild',
      });
      return DurableWorkspaceRuntime._(
        engine: engine,
        provisioner: null,
        workspaceRoot: null,
        custodyRuntimeState: durableWorkspaceRootUnavailable,
        availableReason: _rootUnavailableReason,
        log: log,
      );
    }

    final SecretProviderSelection? custody = custodyProvider == null
        ? _resolveCustody(log: log, environment: environment)
        : _explicitCustody(custodyProvider, log: log);
    if (custody == null) {
      return DurableWorkspaceRuntime._(
        engine: engine,
        provisioner: null,
        workspaceRoot: root,
        custodyRuntimeState: durableWorkspaceRootUnavailable,
        availableReason: _custodyUnavailableReason,
        log: log,
      );
    }

    final credentialKeyService = CredentialKeyService(
      engine: engine,
      secretProvider: custody.provider,
      verifier: accessVerifier ?? const RepositoryAccessVerifier(),
    );
    log('durable_workspace.runtime.configured', {
      'workspaceRoot': root,
      'custodyProviderId': custody.provider.providerId,
    });
    return DurableWorkspaceRuntime._(
      engine: engine,
      provisioner: DurableWorkspaceProvisioner(
        engine: engine,
        credentialKeyService: credentialKeyService,
        materializer: materializer ?? const SshDurableWorkspaceMaterializer(),
        workspaceRoot: root,
        log: log,
      ),
      workspaceRoot: root,
      custodyRuntimeState: 'configured',
      availableReason: null,
      log: log,
    );
  }

  final ProductRegistryEngine engine;

  /// The provisioner, or `null` when this runtime does not exist in this
  /// deployment. See the factory.
  ///
  /// Typed as the provisioner rather than as the materializer PORT on purpose:
  /// [DurableWorkspaceProvisioner.provision] runs the credential and host-key
  /// checks, and a field typed as the port would advertise the transport as an
  /// entry point.
  final DurableWorkspaceProvisioner? provisioner;

  /// The resolved root clones are created under, or `null` when unavailable.
  final String? workspaceRoot;

  /// `configured`, or `unavailable`.
  ///
  /// `unavailable` means the runtime does not exist in this deployment, not
  /// that a human declined to run it. The same wording and the same meaning as
  /// `custodyRuntimeState` on the baseline runtime.
  final String custodyRuntimeState;

  /// Why, when [custodyRuntimeState] is not `configured`.
  final String? availableReason;

  /// Where this runtime's own events go — the same sink the baseline runtime
  /// uses, so one process has one operator log.
  final void Function(String event, Map<String, dynamic> data) log;

  /// Whether a durable workspace can actually be created.
  bool get isAvailable => custodyRuntimeState == 'configured';

  /// Creates (or re-verifies) [productId]'s durable clone and records it.
  ///
  /// Delegates to the provisioner; see [DurableWorkspaceProvisioner.provision].
  /// A caller reaching for `engine.recordWorkspace` directly has skipped the
  /// trust chain that makes the recorded path trustworthy.
  ///
  /// `async` so that an unavailable runtime reports its refusal THROUGH the
  /// future rather than throwing out of the call. A caller that writes `await`
  /// must not have to know whether this particular failure arrived the other
  /// way, and every other refusal in this lane is a failed future.
  Future<DurableWorkspaceDescriptor> provision({
    required String productId,
    required String repositoryId,
    required String pinnedRevision,
  }) async {
    final active = provisioner;
    if (active == null) {
      throw DurableWorkspaceRuntimeUnavailableException(
        reason: availableReason ?? _custodyUnavailableReason,
      );
    }
    return active.provision(
      productId: productId,
      repositoryId: repositoryId,
      pinnedRevision: pinnedRevision,
    );
  }

  /// The operator-facing state of the whole runtime, for a startup banner.
  ///
  /// A single fact an operator can read without knowing the composition: either
  /// durable workspaces work, or they do not and here is why.
  Map<String, dynamic> describe() => <String, dynamic>{
    'runtimeState': custodyRuntimeState,
    if (availableReason != null) 'unavailableReason': availableReason,
    'workspaceRoot': workspaceRoot,
    'cloneDirectoryName': SshDurableWorkspaceMaterializer.cloneDirectoryName,
    'reclamationPolicy':
        'none. Nothing bounds a product clone\'s lifetime or names who deletes '
        'it; both are open decisions (OD-7.2 / OD-7.3) and this runtime '
        'implements neither',
    if (!isAvailable)
      'note':
          'every provisioning call is refused with this reason; no clone is '
          'created and no record is written',
  };

  /// The reason recorded when the composition root passed no workspace root.
  static const String _rootUnavailableReason =
      'No durable workspace root was resolved, so no clone can be created. The '
      'root is resolved in the composition root and passed into '
      'DurableWorkspaceRuntime.resolve; there is deliberately no default here, '
      'because an unset root would otherwise write container-local state that '
      'is silently lost on the next rebuild.';

  /// A custody substrate supplied by the caller rather than selected from the
  /// environment.
  ///
  /// Wrapped in the same selection type as the environment-selected branch so
  /// there is ONE code path afterwards: a caller that supplies custody has not
  /// opted out of anything and cannot leave the runtime in a shape the other
  /// branch does not also produce.
  static SecretProviderSelection _explicitCustody(
    SecretProvider provider, {
    required void Function(String event, Map<String, dynamic> data) log,
  }) {
    log('durable_workspace.custody.configured', {
      'providerId': provider.providerId,
      'isDocumentedFallback': provider.isDocumentedFallback,
      'selectedBy': 'the caller, rather than the configured environment',
    });
    return SecretProviderSelection(provider: provider, loggedFields: const {});
  }

  /// Resolves the custody substrate, or records that none is configured.
  ///
  /// The resolver fails closed by design — unset, blank and unrecognised all
  /// raise — so a refusal here is a configuration fact and not a defect. It is
  /// caught because refusing to boot would be worse: this process also serves
  /// triage, and a missing secret manager is no reason to take that down with
  /// it. Every provisioning call answers with a named refusal instead.
  static SecretProviderSelection? _resolveCustody({
    required void Function(String event, Map<String, dynamic> data) log,
    Map<String, String>? environment,
  }) {
    try {
      final selection = resolveSecretProvider(
        environment: environment,
        log: (event, fields) => log('durable_workspace.$event', fields),
      );
      log('durable_workspace.custody.configured', {
        'providerId': selection.provider.providerId,
        'isDocumentedFallback': selection.provider.isDocumentedFallback,
      });
      return selection;
    } on Object catch (error, stackTrace) {
      log('durable_workspace.custody.unavailable', {
        'runtimeState': durableWorkspaceRootUnavailable,
        'error': error.toString(),
        'stack': stackTrace.toString(),
        'operatorDeclined': false,
        'action':
            'provisioning calls are refused with a named reason; no clone is '
            'created and no onboarding record is written',
      });
      return null;
    }
  }
}

/// Composes the credential primitives with a [DurableWorkspaceMaterializer],
/// and records the result on the product's onboarding record.
///
/// This is the seam `RepositorySnapshotMaterializer` already is for the
/// onboarding lane: a port, so the trust logic can be exercised without a
/// network, a database or a git host. Everything it refuses, it refuses to
/// PROCEED — never with a degraded result handed back, and never with a
/// half-provisioned tree left on disk.
class DurableWorkspaceProvisioner {
  const DurableWorkspaceProvisioner({
    required this.engine,
    required this.credentialKeyService,
    required this.materializer,
    required this.workspaceRoot,
    required this.log,
  });

  final ProductRegistryEngine engine;
  final CredentialKeyService credentialKeyService;

  /// The transport actually used. Swappable so the trust logic above it is
  /// testable without a git host; see [DurableWorkspaceRuntime.resolve] for why
  /// substituting it is not a way to weaken the lane.
  final DurableWorkspaceMaterializer materializer;

  /// The root every product's clone is created under. Resolved by the
  /// composition root and passed in — never read from the environment here.
  final String workspaceRoot;

  final void Function(String event, Map<String, dynamic> data) log;

  /// Clones [productId]'s repository at [pinnedRevision], durably, and records
  /// the result on its onboarding record.
  ///
  /// ## The trust chain, in the order it runs
  ///
  /// ```text
  ///   read the product's OWN active credential      (by reference name only)
  ///   refuse: host key not confirmed / same as ours / no confirming human
  ///   refuse: credential not usable                 (status, host key status)
  ///   CredentialKeyService.verifyAccess             (records the decision)
  ///   read the private half by reference name       (the ONE read of a secret)
  ///   materialise the durable clone                 (no key survives it)
  ///   wipe the private half                         (before anything else)
  ///   engine.recordWorkspace                        (the one durable write)
  /// ```
  ///
  /// Every refusal is a refusal to proceed. The private half is wiped in a
  /// `finally` that runs BEFORE the repository's fate is decided and before the
  /// record is written — the ordering `onRelease` states in words, and the one
  /// thing a durable clone cannot inherit by reusing the acquirer.
  Future<DurableWorkspaceDescriptor> provision({
    required String productId,
    required String repositoryId,
    required String pinnedRevision,
  }) async {
    final pin = pinnedRevision.trim();
    if (pin.isEmpty) {
      throw ArgumentError.value(
        pinnedRevision,
        'pinnedRevision',
        'a durable clone must be pinned; an unpinned clone cannot be '
            're-derived later, because "later" is a different commit',
      );
    }

    final credential = await engine.readActiveCredential(
      productId,
      repositoryId,
    );
    if (credential == null) {
      throw DurableWorkspaceUnavailableException(
        'no credential has been minted for repository $repositoryId, so no '
        'clone can be made',
      );
    }

    // ---- The distinction the trust chain exists to hold. ----
    //
    // `hostKeyFingerprint` is a host key a human confirmed out of band.
    // `fingerprint` is this deploy key's own public key. Different values,
    // different provenance, and only the first may ever be treated as the
    // confirmed one.
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
            'the value recorded as the host key fingerprint is this credential\'s '
            'own public-key fingerprint; those are different values with '
            'different provenance',
      );
    }
    if (!credential.isHostConfirmed) {
      throw DurableWorkspaceUnavailableException(
        'the host key has not been confirmed by a human, so the trust decision '
        'enforced at the socket has no provenance to enforce',
      );
    }
    if (!credential.canReachRepository) {
      throw DurableWorkspaceUnavailableException(
        'the credential is not currently usable (status '
        '${credential.status.wire}, host key ${credential.hostKeyStatus.wire})',
      );
    }

    // A lane must not put its own name in `confirmedBy` — that would forge the
    // one piece of provenance this seam rests on.
    final confirmedBy = credential.hostConfirmedBy;
    if (confirmedBy == null || confirmedBy.trim().isEmpty) {
      throw DurableWorkspaceUnavailableException(
        'the confirmed host key records no confirming human, so the trust '
        'decision is unattributable',
      );
    }

    final access = await credentialKeyService.verifyAccess(
      productId: productId,
      repositoryId: repositoryId,
      hostKeyFingerprint: hostKeyFingerprint,
      confirmedBy: confirmedBy,
      checkedBy: _durableWorkspaceLanePrincipal,
    );
    if (!access.canReachRepository) {
      throw DurableWorkspaceUnavailableException(
        access.failureReason ??
            'a connectivity check with this credential did not succeed',
      );
    }

    final repository = await engine.resolveRepository(productId, repositoryId);
    final remote = parseSshRemote(repository.uri);
    final productRoot = '$workspaceRoot/$productId';

    // The ONE read of private material, by reference name — never from a path,
    // never cached, never held in a field. `CredentialKeyService.generate` is
    // deliberately NOT the way in: it MINTS a new deploy key and stores it,
    // which is credential lifecycle, not materialisation, and it would replace
    // a key a human had already installed on the host.
    final material = await credentialKeyService.secretProvider.read(
      referenceName: credential.referenceName,
    );

    late final DurableWorkspaceClone clone;
    try {
      clone = await materializer.materialize(
        productId: productId,
        repositoryId: repositoryId,
        remote: remote,
        privateKeyPem: material,
        confirmedHostKeyFingerprint: hostKeyFingerprint,
        pinnedRevision: pin,
        productRoot: productRoot,
      );
    } finally {
      // Obligation 6, in-memory half: the private half goes BEFORE the record
      // is written and before anything is decided about the repository's fate.
      material.wipe();
    }

    final descriptor = DurableWorkspaceDescriptor(
      workspaceId: 'dws-$productId',
      productId: productId,
      repositoryPath: clone.repositoryPath,
      startingRevision: clone.revision,
      createdAt: clone.materializedAt,
    );

    // The one durable write. `recordWorkspace` is the only engine method that
    // writes `pinnedRevision` or `workspace`, and it refuses a pair that
    // contradicts — so a descriptor and the pin it was made from cannot land
    // disagreeing.
    final OnboardingRecord record = await engine.recordWorkspace(
      productId: productId,
      workspace: descriptor,
      pinnedRevision: pin,
    );

    log('durable_workspace.provisioned', {
      'productId': productId,
      'repositoryId': repositoryId,
      'workspaceId': descriptor.workspaceId,
      'repositoryPath': descriptor.repositoryPath,
      'pinnedRevision': pin,
      'recordedOnboardingId': record.onboardingId,
      'sourceRef': clone.sourceRef,
      // Stated in every success log precisely because it is invisible on the
      // success path: a materialiser that left an identity beside the clone
      // would look identical here.
      'credentialMaterialRemoved': _credentialMaterialFileNames,
      'reclamationPolicy': 'none — OD-7.2 and OD-7.3 are open',
    });
    return descriptor;
  }

  /// Completes onboarding against [descriptor], naming the baseline a human
  /// accepted.
  ///
  /// ## Why this refuses rather than delegating
  ///
  /// `ProductRegistryEngine.completeOnboarding` requires a
  /// `completedBaselineId` and refuses a product with no onboarding record. It
  /// does NOT check that the named baseline was ever ACCEPTED — it takes the
  /// caller's word for it, because its caller is supposed to be the human-
  /// acceptance path. A durable-workspace lane is not that caller, and a
  /// completion naming a baseline still in `proposed` would flip `completed` on
  /// the strength of work nobody approved.
  ///
  /// So the acceptance is CHECKED here, against the stored baseline's own
  /// status, and a mismatch is refused by name. This is the §6.6 prohibition —
  /// "must not call `completeOnboarding` before a human has accepted a
  /// baseline" — made mechanical rather than a comment.
  Future<OnboardingRecord> completeOnboarding({
    required String productId,
    required String pinnedRevision,
    required DurableWorkspaceDescriptor workspace,
    required String completedBaselineId,
  }) async {
    final baselines = await engine.readBaselines(productId);
    final accepted = baselines.where(
      (baseline) => baseline.baselineId == completedBaselineId,
    );
    if (accepted.isEmpty) {
      throw DurableWorkspaceUnavailableException(
        'baseline $completedBaselineId does not exist for product $productId, '
        'so onboarding cannot be completed against it',
      );
    }
    final baseline = accepted.single;
    if (baseline.status != ProductBaselineStatus.accepted) {
      throw DurableWorkspaceUnavailableException(
        'baseline ${baseline.baselineId} is ${baseline.status.wire}, not '
        'accepted, so no human has accepted the work this workspace would be '
        'recorded against. Completion waits for the approval, it does not '
        'pre-empt it',
      );
    }
    return engine.completeOnboarding(
      productId: productId,
      pinnedRevision: pinnedRevision,
      workspace: workspace,
      completedBaselineId: completedBaselineId,
    );
  }
}

/// Raised when a durable workspace cannot be created, for any reason that is a
/// refusal rather than a defect.
///
/// Every one of these is a refusal to PROCEED. None of them leaves a tree on
/// disk, and none of them writes a record: a product whose clone could not be
/// made has no answer to record.
class DurableWorkspaceUnavailableException implements Exception {
  DurableWorkspaceUnavailableException(this.reason) {
    _assertSafeToShow(reason);
  }

  /// Why the clone could not be created. Safe to persist and show: every value
  /// interpolated into it is a configuration fact or a refusal reason, and
  /// never key material — the private half is a [SecretBytes], whose own
  /// `toString` emits a length and nothing else.
  final String reason;

  /// Refuses a message carrying something that looks like key material.
  ///
  /// A reason is interpolated from configuration and from refusal text, and the
  /// one class of value it must never carry is a secret. This is the check that
  /// makes that structural rather than a convention every future caller has to
  /// remember: the message is built before it is stored, so there is exactly one
  /// place to be right.
  static void _assertSafeToShow(String reason) {
    final blocked = <String>[
      'PRIVATE KEY',
      'BEGIN OPENSSH',
      'ssh-ed25519',
      'ssh-rsa',
      'ecdsa-sha2',
    ];
    final upper = reason.toUpperCase();
    for (final marker in blocked) {
      if (upper.contains(marker.toUpperCase())) {
        throw StateError(
          'a durable-workspace refusal reason appears to carry key material '
          '("$marker"). It is safe to persist and would be logged; refusing to '
          'construct it rather than logging a key is the whole point.',
        );
      }
    }
  }

  @override
  String toString() => 'DurableWorkspaceUnavailableException: $reason';
}

/// Raised when the durable-workspace runtime does not exist in this deployment.
///
/// Separate from [DurableWorkspaceUnavailableException] because the two mean
/// different things: this one is a CONFIGURATION fact about the whole
/// deployment, the other is a per-product refusal. Collapsing them would let a
/// sweep report "this product's host key is unconfirmed" when the truth is "no
/// custody substrate is selected anywhere in this deployment".
class DurableWorkspaceRuntimeUnavailableException implements Exception {
  const DurableWorkspaceRuntimeUnavailableException({required this.reason});

  final String reason;

  @override
  String toString() => 'DurableWorkspaceRuntimeUnavailableException: $reason';
}

/// `configured`, or the runtime does not exist in this deployment.
const String durableWorkspaceRootUnavailable = 'unavailable';

/// The three credential files a materialisation writes beside a clone and that
/// are gone before it returns.
///
/// Named in one place so the success log and the review assertion cannot name
/// them differently — a check that looks for files under one spelling while the
/// code writes another is a gate that has silently stopped covering anything.
const String _credentialMaterialFileNames =
    '${SshDurableWorkspaceMaterializer.identityFileName}, '
    '${SshDurableWorkspaceMaterializer.knownHostsFileName}, '
    '${SshDurableWorkspaceMaterializer.sshWrapperFileName}';
