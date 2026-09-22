import 'package:platform_contracts/platform_contracts.dart';

class ProductNotFoundException implements Exception {
  ProductNotFoundException(this.productId);

  final String productId;

  @override
  String toString() => 'Product not found: $productId';
}

class RepositoryNotFoundException implements Exception {
  RepositoryNotFoundException(this.repositoryId);

  final String repositoryId;

  @override
  String toString() => 'Repository reference not found: $repositoryId';
}

class BaselineNotFoundException implements Exception {
  BaselineNotFoundException(this.baselineId);

  final String baselineId;

  @override
  String toString() => 'Product baseline not found: $baselineId';
}

class ClarificationNotFoundException implements Exception {
  ClarificationNotFoundException(this.clarificationId);

  final String clarificationId;

  @override
  String toString() => 'Clarification request not found: $clarificationId';
}

class ConcurrentModificationException implements Exception {
  ConcurrentModificationException({
    required this.entityId,
    required this.expectedVersion,
    required this.actualVersion,
  });

  final String entityId;
  final int expectedVersion;
  final int actualVersion;

  @override
  String toString() =>
      'Concurrent modification of $entityId (expected version '
      '$expectedVersion, actual $actualVersion)';
}

/// A store/engine caller tried to reach across Product boundaries (checkpoint
/// 006 §5). The write/read was refused — knowing an entity ID does not
/// authorize cross-Product retrieval.
class CrossProductAccessException implements Exception {
  CrossProductAccessException(this.message);

  final String message;

  @override
  String toString() => 'Cross-product access refused: $message';
}

/// The Product is not in a lifecycle stage that permits this operation.
class ProductLifecycleException implements Exception {
  ProductLifecycleException(this.message);

  final String message;

  @override
  String toString() => 'Product lifecycle: $message';
}

/// An accepted baseline revision is immutable historical authority; the engine
/// refused a mutation attempt on it.
class ImmutableBaselineException implements Exception {
  ImmutableBaselineException(this.baselineId);

  final String baselineId;

  @override
  String toString() => 'Accepted baseline revision is immutable: $baselineId';
}

/// A material unknown forced onboarding to stop (durable clarification).
class ClarificationRequiredException implements Exception {
  ClarificationRequiredException(this.clarificationId);

  final String clarificationId;

  @override
  String toString() => 'Clarification required: $clarificationId';
}

/// Discovery was asked to do something outside its read-only capability
/// boundary (checkpoint 006 §read-only discovery). Repository content is DATA,
/// never agent authority.
class DiscoveryCapabilityViolation implements Exception {
  DiscoveryCapabilityViolation(this.message);

  final String message;

  @override
  String toString() => 'Discovery capability violation: $message';
}

/// No durable baseline-approval [HumanDecision] exists for the given id.
class BaselineApprovalNotFoundException implements Exception {
  BaselineApprovalNotFoundException(this.decisionId);

  final String decisionId;

  @override
  String toString() => 'Baseline approval decision not found: $decisionId';
}

/// Acceptance was attempted without a resolved, approving HumanDecision bound
/// to the exact baseline revision + contentHash. An unauthenticated field
/// update is not sufficient public authority (checkpoint 006 §human gate).
class BaselineApprovalRequiredException implements Exception {
  BaselineApprovalRequiredException(this.message);

  final String message;

  @override
  String toString() => 'Baseline approval required: $message';
}

/// The approval decision no longer corresponds to the exact candidate being
/// accepted (TOCTOU / superseded revision). Acceptance fails closed.
class StaleBaselineApprovalException implements Exception {
  StaleBaselineApprovalException(this.message);

  final String message;

  @override
  String toString() => 'Stale baseline approval refused: $message';
}

/// The approval decision was resolved with a non-approving choice, so it does
/// not authorize acceptance.
class BaselineApprovalRejectedException implements Exception {
  BaselineApprovalRejectedException(this.decisionId, this.choiceWire);

  final String decisionId;
  final String choiceWire;

  @override
  String toString() =>
      'Baseline approval $decisionId resolved as "$choiceWire", not approve';
}

/// A baseline was sent to the human approval gate without having been
/// verified by a worker.
///
/// AGENTS.md §12: agents produce, workers validate. Asking a human to approve
/// an unverified baseline would present an agent's own claim as an
/// independent fact, so this fails closed.
class BaselineNotVerifiedException implements Exception {
  BaselineNotVerifiedException(this.baselineId);

  final String baselineId;

  @override
  String toString() =>
      'Baseline not verified: $baselineId has not been independently '
      'verified; call verifyBaseline with platform_verified_evidence before '
      'requesting approval';
}

/// No credential exists with the given id.
class CredentialNotFoundException implements Exception {
  CredentialNotFoundException(this.credentialId);

  final String credentialId;

  @override
  String toString() => 'Repository credential not found: $credentialId';
}

/// An operation needed a credential that can actually reach the repository,
/// and the one on file cannot.
///
/// ADR 0018: access is proven, never assumed. A credential that has not been
/// verified, or whose host has not been confirmed, is not usable.
class CredentialNotUsableException implements Exception {
  CredentialNotUsableException(this.credentialId, this.reason);

  final String credentialId;
  final String reason;

  @override
  String toString() => 'Repository credential $credentialId is not usable: '
      '$reason';
}

/// ShipIt was asked to connect to a host whose key it does not recognise, or
/// whose key has changed since it was confirmed.
///
/// Fails closed: an unrecognised host is indistinguishable from an
/// interception, and ShipIt never claims to have verified a host it cannot.
class HostKeyNotConfirmedException implements Exception {
  HostKeyNotConfirmedException(this.host, this.status);

  final String host;
  final HostKeyStatus status;

  @override
  String toString() => switch (status) {
    HostKeyStatus.changed =>
      'Host key for $host has CHANGED since it was confirmed; refusing to '
          'connect',
    _ => 'Host key for $host is not recognised; confirm its fingerprint '
        'before connecting',
  };
}

/// No standing policy exists with the given id.
class PolicyNotFoundException implements Exception {
  PolicyNotFoundException(this.policyId);

  final String policyId;

  @override
  String toString() => 'Standing policy not found: $policyId';
}

/// A policy was asked to authorise something it may never authorise, or its
/// scope was left open-ended.
///
/// ADR 0019: production promotion, baseline approval and offboarding are
/// non-delegable, and a policy that authorises nothing is a config flag
/// pretending to be a decision.
class InvalidPolicyScopeException implements Exception {
  InvalidPolicyScopeException(this.reason);

  final String reason;

  @override
  String toString() => 'Invalid standing policy scope: $reason';
}
