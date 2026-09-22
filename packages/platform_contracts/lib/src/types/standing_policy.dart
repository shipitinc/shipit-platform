import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'standing_policy.g.dart';

/// Classes of action a [StandingPolicy] may authorise (ADR 0019).
///
/// Deliberately a closed set. An open-ended policy scope would be a blank
/// cheque, so a policy can only name actions that appear here.
enum PolicyAction {
  /// Pushing commits to a branch in the product's own repository.
  push('push'),

  /// Merging within the product's own repository.
  merge('merge');

  const PolicyAction(this.wire);

  final String wire;

  static PolicyAction fromWire(String value) => values.firstWhere(
    (a) => a.wire == value,
    orElse: () => throw FormatException('Unknown policy action: $value'),
  );
}

/// Why a [StandingPolicy] is no longer in force.
enum PolicyRevocationReason {
  /// A human withdrew it. Itself a recorded decision (ADR 0019).
  revokedByHuman('revoked_by_human'),

  /// The product it governed was archived, so its scope no longer exists.
  subjectArchived('subject_archived'),

  /// Replaced by a newer policy over the same scope.
  superseded('superseded');

  const PolicyRevocationReason(this.wire);

  final String wire;

  static PolicyRevocationReason fromWire(String value) => values.firstWhere(
    (r) => r.wire == value,
    orElse: () =>
        throw FormatException('Unknown policy revocation reason: $value'),
  );
}

/// A signed human decision that authorises a *class* of future actions rather
/// than a single one (ADR 0019).
///
/// ## Why this exists
///
/// ADR 0013 gates terminate execution until a human resolves them. That is
/// correct for consequential decisions and actively harmful inside an
/// iteration loop: a `push → CI fails → fix → push` cycle would halt the
/// scheduler on every pass. Asking a human the same question twenty times also
/// degrades the answer — approval becomes reflex, and the durable record still
/// claims a considered decision was made.
///
/// ## What keeps it honest
///
/// A policy is not a config flag. It is created by a gated decision
/// ([authorisingDecisionId]), it is bounded ([productId] + [actions]), every
/// action taken under it cites it, and revoking it is itself recorded.
///
/// ## What it may never authorise
///
/// Production promotion, baseline approval and offboarding are non-delegable
/// (ADR 0012, ADR 0019). [PolicyAction] cannot express them, so this is
/// enforced by the type rather than by a runtime check that could be skipped.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class StandingPolicy extends Equatable {
  const StandingPolicy({
    required this.policyId,
    required this.productId,
    required this.actions,
    required this.authorisingDecisionId,
    required this.authorisedBy,
    required this.rationale,
    required this.authorisedAt,
    this.revokedAt,
    this.revokedBy,
    this.revocationDecisionId,
    this.revocationReason,
    this.version = 1,
  });

  final String policyId;

  /// The single product this policy is bounded to. A policy is never global.
  final String productId;

  /// The classes of action authorised. Never empty — a policy that authorises
  /// nothing is a config flag pretending to be a decision.
  @JsonKey(fromJson: _actionsFromWire, toJson: _actionsToWire)
  final List<PolicyAction> actions;

  /// The gated [HumanDecision] that created this policy. Creating a standing
  /// authorisation is itself consequential, so it goes through a normal gate.
  final String authorisingDecisionId;

  final String authorisedBy;

  /// Why the human authorised this. Recorded so "why does this happen without
  /// me?" is answerable years later.
  final String rationale;

  final DateTime authorisedAt;

  final DateTime? revokedAt;
  final String? revokedBy;

  /// The decision that revoked this policy. Withdrawing trust is as auditable
  /// as granting it.
  final String? revocationDecisionId;

  @JsonKey(fromJson: _reasonFromWireOrNull, toJson: _reasonToWireOrNull)
  final PolicyRevocationReason? revocationReason;

  final int version;

  bool get isRevoked => revokedAt != null;

  /// Whether this policy authorises [action] at [at].
  ///
  /// Policies never apply retroactively: an action taken before
  /// [authorisedAt] is not re-attributed to a policy created later.
  bool authorises(PolicyAction action, {required DateTime at}) {
    if (!actions.contains(action)) return false;
    if (at.isBefore(authorisedAt)) return false;
    if (revokedAt != null && !at.isBefore(revokedAt!)) return false;
    return true;
  }

  /// Whether this policy covers [action] for [productId] at [at]. Scope is
  /// checked here so callers cannot forget it.
  bool covers({
    required String productId,
    required PolicyAction action,
    required DateTime at,
  }) => this.productId == productId && authorises(action, at: at);

  StandingPolicy revoke({
    required DateTime at,
    required String by,
    required PolicyRevocationReason reason,
    String? decisionId,
  }) => StandingPolicy(
    policyId: policyId,
    productId: productId,
    actions: actions,
    authorisingDecisionId: authorisingDecisionId,
    authorisedBy: authorisedBy,
    rationale: rationale,
    authorisedAt: authorisedAt,
    revokedAt: at,
    revokedBy: by,
    revocationDecisionId: decisionId,
    revocationReason: reason,
    version: version + 1,
  );

  factory StandingPolicy.fromJson(Map<String, dynamic> json) =>
      _$StandingPolicyFromJson(json);

  Map<String, dynamic> toJson() => _$StandingPolicyToJson(this);

  @override
  List<Object?> get props => [
    policyId,
    productId,
    actions,
    authorisingDecisionId,
    authorisedBy,
    rationale,
    authorisedAt,
    revokedAt,
    revokedBy,
    revocationDecisionId,
    revocationReason,
    version,
  ];
}

List<PolicyAction> _actionsFromWire(List<dynamic> value) =>
    value.map((v) => PolicyAction.fromWire(v as String)).toList();

List<String> _actionsToWire(List<PolicyAction> actions) =>
    actions.map((a) => a.wire).toList();

PolicyRevocationReason? _reasonFromWireOrNull(String? value) =>
    value == null ? null : PolicyRevocationReason.fromWire(value);

String? _reasonToWireOrNull(PolicyRevocationReason? reason) => reason?.wire;
