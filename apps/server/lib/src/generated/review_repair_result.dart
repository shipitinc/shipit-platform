/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:serverpod/serverpod.dart' as _i1;
import 'work_item_view.dart' as _i2;
import 'package:control_plane_server/src/generated/protocol.dart' as _i3;

/// The result of one attempt at repairing a work item parked behind an
/// engineering-review decision that no reviewer ever backed.
///
/// ## WHY THIS IS A MODEL AND NOT A HAND-WRITTEN DART TYPE
///
/// A plain Dart type declared in `lib/src/endpoints/` is not a wire type. It is
/// referenced by the generated client and never copied to it, and it appears
/// zero times in `lib/src/generated/protocol.dart` — so the server's
/// `SerializationManager` cannot decode the return value in either direction,
/// the client does not analyze, and the action is unreachable. Measured on
/// 2026-10-15; recorded in
/// docs/engineering/learning/a-generated-client-can-reference-a-file-it-never-emitted.md.
/// Every wire type in this Serverpod (3.4.13) is a YAML model under
/// `lib/src/models/`, and that is what puts a class into the serialization
/// table. So this declaration is what makes the action callable, not a
/// formality.
///
/// ## NOT SERVER-AUTHORED UI COPY
///
/// `outcome` is a WIRE VALUE and `detail` is diagnostic — the "why", and the
/// whole value of a refusal an operator has to act on. Neither is presentational:
/// the operator-facing sentence for each outcome is the client's to word, from
/// its own copy module, which is the same boundary `WorkItemActionResult`
/// keeps.
abstract class ReviewRepairResult
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  ReviewRepairResult._({
    required this.outcome,
    required this.detail,
    required this.workItem,
    this.decisionId,
  });

  factory ReviewRepairResult({
    required String outcome,
    required String detail,
    required _i2.WorkItemView workItem,
    String? decisionId,
  }) = _ReviewRepairResultImpl;

  factory ReviewRepairResult.fromJson(Map<String, dynamic> jsonSerialization) {
    return ReviewRepairResult(
      outcome: jsonSerialization['outcome'] as String,
      detail: jsonSerialization['detail'] as String,
      workItem: _i3.Protocol().deserialize<_i2.WorkItemView>(
        jsonSerialization['workItem'],
      ),
      decisionId: jsonSerialization['decisionId'] as String?,
    );
  }

  /// 'accepted' | 'notApplicable' | 'reviewerProducedVerdict' |
  /// 'reviewerProducedProse' | 'reviewerOutputUnreadable' | 'alreadyDecided' |
  /// 'alreadyRunning' | 'concurrentWrite' | 'invalidRequest'.
  ///
  /// A closed set, and every input reaches exactly one of them:
  ///
  /// | outcome | meaning | wrote anything? |
  /// |---|---|---|
  /// | `accepted` | repaired, or a replay of an intent that was | yes, once |
  /// | `notApplicable` | nothing is parked behind a fabricated question | no |
  /// | `reviewerProducedVerdict` | a reviewer really returned this verdict | no |
  /// | `reviewerProducedProse` | a real assessment exists, in prose only | no |
  /// | `reviewerOutputUnreadable` | the reviewer result could not be read | no |
  /// | `alreadyDecided` | a human answered; the repair must not undo that | no |
  /// | `alreadyRunning` | a live job holds the item | no |
  /// | `concurrentWrite` | another writer moved it first | no |
  /// | `invalidRequest` | no requester or no reason | no |
  ///
  /// `accepted` covers BOTH the first application and a replay of an intent that
  /// was already carried out, deliberately: a replay must report what that
  /// request DID, not refuse itself as inapplicable after the item has moved on.
  /// Every other value is a refusal, and a refusal wrote nothing.
  String outcome;

  /// Why this outcome, in one sentence. Diagnostic, not presentational.
  String detail;

  /// The work item as it stands after this attempt — always re-read, so a
  /// refusal still reports the true current state rather than a stale one.
  ///
  /// `WorkItemView`, not the durable `WorkItem`: a view is what the wire
  /// carries, and the durable record's `metadata`/`version` are server-internal.
  _i2.WorkItemView workItem;

  /// The decision this attempt concerned, or null when none applied.
  String? decisionId;

  /// Returns a shallow copy of this [ReviewRepairResult]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ReviewRepairResult copyWith({
    String? outcome,
    String? detail,
    _i2.WorkItemView? workItem,
    String? decisionId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ReviewRepairResult',
      'outcome': outcome,
      'detail': detail,
      'workItem': workItem.toJson(),
      if (decisionId != null) 'decisionId': decisionId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ReviewRepairResult',
      'outcome': outcome,
      'detail': detail,
      'workItem': workItem.toJsonForProtocol(),
      if (decisionId != null) 'decisionId': decisionId,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ReviewRepairResultImpl extends ReviewRepairResult {
  _ReviewRepairResultImpl({
    required String outcome,
    required String detail,
    required _i2.WorkItemView workItem,
    String? decisionId,
  }) : super._(
         outcome: outcome,
         detail: detail,
         workItem: workItem,
         decisionId: decisionId,
       );

  /// Returns a shallow copy of this [ReviewRepairResult]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ReviewRepairResult copyWith({
    String? outcome,
    String? detail,
    _i2.WorkItemView? workItem,
    Object? decisionId = _Undefined,
  }) {
    return ReviewRepairResult(
      outcome: outcome ?? this.outcome,
      detail: detail ?? this.detail,
      workItem: workItem ?? this.workItem.copyWith(),
      decisionId: decisionId is String? ? decisionId : this.decisionId,
    );
  }
}
