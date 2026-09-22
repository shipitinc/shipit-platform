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
import 'package:control_plane_server/src/generated/protocol.dart' as _i2;

/// A single baseline claim with its provenance. Provenance is part of the
/// wire contract so a consumer can never mistake an `assumed` fact for an
/// `observed` one.
abstract class BaselineFactView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  BaselineFactView._({
    required this.factId,
    required this.section,
    required this.claim,
    required this.provenance,
    required this.evidenceRefs,
    this.assumptionNote,
    required this.redacted,
  });

  factory BaselineFactView({
    required String factId,
    required String section,
    required String claim,
    required String provenance,
    required List<String> evidenceRefs,
    String? assumptionNote,
    required bool redacted,
  }) = _BaselineFactViewImpl;

  factory BaselineFactView.fromJson(Map<String, dynamic> jsonSerialization) {
    return BaselineFactView(
      factId: jsonSerialization['factId'] as String,
      section: jsonSerialization['section'] as String,
      claim: jsonSerialization['claim'] as String,
      provenance: jsonSerialization['provenance'] as String,
      evidenceRefs: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['evidenceRefs'],
      ),
      assumptionNote: jsonSerialization['assumptionNote'] as String?,
      redacted: _i1.BoolJsonExtension.fromJson(jsonSerialization['redacted']),
    );
  }

  String factId;

  String section;

  String claim;

  /// observed | human_provided | derived | assumed | unknown
  String provenance;

  List<String> evidenceRefs;

  String? assumptionNote;

  /// True when the claim references a redacted secret placeholder.
  bool redacted;

  /// Returns a shallow copy of this [BaselineFactView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  BaselineFactView copyWith({
    String? factId,
    String? section,
    String? claim,
    String? provenance,
    List<String>? evidenceRefs,
    String? assumptionNote,
    bool? redacted,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BaselineFactView',
      'factId': factId,
      'section': section,
      'claim': claim,
      'provenance': provenance,
      'evidenceRefs': evidenceRefs.toJson(),
      if (assumptionNote != null) 'assumptionNote': assumptionNote,
      'redacted': redacted,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BaselineFactView',
      'factId': factId,
      'section': section,
      'claim': claim,
      'provenance': provenance,
      'evidenceRefs': evidenceRefs.toJson(),
      if (assumptionNote != null) 'assumptionNote': assumptionNote,
      'redacted': redacted,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BaselineFactViewImpl extends BaselineFactView {
  _BaselineFactViewImpl({
    required String factId,
    required String section,
    required String claim,
    required String provenance,
    required List<String> evidenceRefs,
    String? assumptionNote,
    required bool redacted,
  }) : super._(
         factId: factId,
         section: section,
         claim: claim,
         provenance: provenance,
         evidenceRefs: evidenceRefs,
         assumptionNote: assumptionNote,
         redacted: redacted,
       );

  /// Returns a shallow copy of this [BaselineFactView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  BaselineFactView copyWith({
    String? factId,
    String? section,
    String? claim,
    String? provenance,
    List<String>? evidenceRefs,
    Object? assumptionNote = _Undefined,
    bool? redacted,
  }) {
    return BaselineFactView(
      factId: factId ?? this.factId,
      section: section ?? this.section,
      claim: claim ?? this.claim,
      provenance: provenance ?? this.provenance,
      evidenceRefs: evidenceRefs ?? this.evidenceRefs.map((e0) => e0).toList(),
      assumptionNote: assumptionNote is String?
          ? assumptionNote
          : this.assumptionNote,
      redacted: redacted ?? this.redacted,
    );
  }
}
