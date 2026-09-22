import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/credential_status.dart';

part 'repository_credential.g.dart';

/// The SSH credential that lets ShipIt reach exactly one repository
/// (ADR 0018, AGENTS.md §13a).
///
/// ## This type never holds key material
///
/// There is no private-key field, and there never may be. The private half is
/// written to the operator's local secret store and is referenced only by
/// [referenceName] — §13's "referenced by name, never by value" applies to git
/// credentials unchanged. Only [publicKey] and [fingerprint] are stored, both
/// of which are safe to display.
///
/// ## Scope is one repository, not one product
///
/// ADR 0018 originally said one keypair per *product*. A Product may own
/// several repositories, and providers forbid reusing a deploy key across
/// repositories in one organisation, so a per-product key is not installable
/// for a multi-repo product. Scoping to [repositoryId] matches the deploy-key
/// mechanism and is strictly narrower: a leaked key reaches one repository.
/// [productId] is retained for ownership checks, not for scope.
///
/// ## Access is proven, never assumed
///
/// [status] and [hostKeyStatus] only advance on a real result at a recorded
/// time. A credential that has not been checked is [CredentialStatus.generated],
/// not "probably fine".
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class RepositoryCredential extends Equatable {
  const RepositoryCredential({
    required this.credentialId,
    required this.productId,
    required this.repositoryId,
    required this.referenceName,
    required this.publicKey,
    required this.fingerprint,
    this.algorithm = 'ed25519',
    this.status = CredentialStatus.generated,
    required this.createdAt,
    this.lastVerifiedAt,
    this.lastVerifiedBy,
    this.lastFailureReason,
    this.hostKeyStatus = HostKeyStatus.unknown,
    this.host,
    this.hostKeyFingerprint,
    this.hostConfirmedAt,
    this.hostConfirmedBy,
    this.revokedAt,
    this.revokedReason,
    this.supersedesCredentialId,
    this.version = 1,
  });

  final String credentialId;

  /// Owning product. Used for scope enforcement so that knowing a credential
  /// id does not bypass the ownership graph.
  final String productId;

  /// The single repository this credential can reach.
  final String repositoryId;

  /// Name under which the private half is held in the local secret store,
  /// e.g. `GIT_PRODUCT_<productRef>_SSH`. Never the value itself.
  final String referenceName;

  /// The public half — safe to store, display and copy out.
  final String publicKey;

  /// Fingerprint of [publicKey], e.g. `SHA256:0Hq7…Kt4`.
  final String fingerprint;

  final String algorithm;

  @JsonKey(fromJson: _statusFromWire, toJson: _statusToWire)
  final CredentialStatus status;

  final DateTime createdAt;

  /// When a connection using this credential last succeeded. Null means it has
  /// never been proven to work.
  final DateTime? lastVerifiedAt;

  /// Identity that performed the successful check.
  final String? lastVerifiedBy;

  /// Why the most recent check failed, when [status] is
  /// [CredentialStatus.failing]. Recorded rather than discarded so the
  /// operator is told what went wrong.
  final String? lastFailureReason;

  @JsonKey(fromJson: _hostFromWire, toJson: _hostToWire)
  final HostKeyStatus hostKeyStatus;

  /// Host extracted from the repository URI, e.g. `github.com`.
  final String? host;

  /// The host key fingerprint a human confirmed, or the one most recently
  /// presented when [hostKeyStatus] is [HostKeyStatus.changed].
  final String? hostKeyFingerprint;

  final DateTime? hostConfirmedAt;

  /// Who confirmed the host key. Trust-on-first-use is a human decision, so it
  /// is attributable like any other.
  final String? hostConfirmedBy;

  final DateTime? revokedAt;

  final String? revokedReason;

  /// The credential this one replaced, when created by rotation.
  final String? supersedesCredentialId;

  final int version;

  /// Whether ShipIt may currently reach the repository with this credential.
  ///
  /// Requires both halves of the trust chain: a confirmed host *and* a
  /// credential proven to work. Either one alone is insufficient.
  bool get canReachRepository =>
      status.isUsable && hostKeyStatus.permitsConnection;

  /// Whether a human has ever confirmed this host's key.
  bool get isHostConfirmed =>
      hostKeyStatus == HostKeyStatus.confirmed &&
      hostConfirmedAt != null &&
      hostConfirmedBy != null;

  RepositoryCredential copyWith({
    CredentialStatus? status,
    DateTime? lastVerifiedAt,
    String? lastVerifiedBy,
    String? lastFailureReason,
    HostKeyStatus? hostKeyStatus,
    String? host,
    String? hostKeyFingerprint,
    DateTime? hostConfirmedAt,
    String? hostConfirmedBy,
    DateTime? revokedAt,
    String? revokedReason,
    int? version,
  }) => RepositoryCredential(
    credentialId: credentialId,
    productId: productId,
    repositoryId: repositoryId,
    referenceName: referenceName,
    publicKey: publicKey,
    fingerprint: fingerprint,
    algorithm: algorithm,
    status: status ?? this.status,
    createdAt: createdAt,
    lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
    lastVerifiedBy: lastVerifiedBy ?? this.lastVerifiedBy,
    lastFailureReason: lastFailureReason ?? this.lastFailureReason,
    hostKeyStatus: hostKeyStatus ?? this.hostKeyStatus,
    host: host ?? this.host,
    hostKeyFingerprint: hostKeyFingerprint ?? this.hostKeyFingerprint,
    hostConfirmedAt: hostConfirmedAt ?? this.hostConfirmedAt,
    hostConfirmedBy: hostConfirmedBy ?? this.hostConfirmedBy,
    revokedAt: revokedAt ?? this.revokedAt,
    revokedReason: revokedReason ?? this.revokedReason,
    supersedesCredentialId: supersedesCredentialId,
    version: version ?? this.version,
  );

  factory RepositoryCredential.fromJson(Map<String, dynamic> json) =>
      _$RepositoryCredentialFromJson(json);

  Map<String, dynamic> toJson() => _$RepositoryCredentialToJson(this);

  @override
  List<Object?> get props => [
    credentialId,
    productId,
    repositoryId,
    referenceName,
    publicKey,
    fingerprint,
    algorithm,
    status,
    createdAt,
    lastVerifiedAt,
    lastVerifiedBy,
    lastFailureReason,
    hostKeyStatus,
    host,
    hostKeyFingerprint,
    hostConfirmedAt,
    hostConfirmedBy,
    revokedAt,
    revokedReason,
    supersedesCredentialId,
    version,
  ];
}

CredentialStatus _statusFromWire(String value) =>
    CredentialStatus.fromWire(value);

String _statusToWire(CredentialStatus status) => status.wire;

HostKeyStatus _hostFromWire(String value) => HostKeyStatus.fromWire(value);

String _hostToWire(HostKeyStatus status) => status.wire;
