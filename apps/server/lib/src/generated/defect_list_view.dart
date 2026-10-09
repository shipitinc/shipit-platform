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
import 'defect_summary_view.dart' as _i2;
import 'package:control_plane_server/src/generated/protocol.dart' as _i3;

/// `defectEndpoints.list` returned a raw map. Typed. The envelope mirrors
/// `intakeEndpoints.listFeatureRequests` so a client can read both report tabs
/// with one shape.
abstract class DefectListView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  DefectListView._({
    required this.defects,
    required this.totalCount,
  });

  factory DefectListView({
    required List<_i2.DefectSummaryView> defects,
    required int totalCount,
  }) = _DefectListViewImpl;

  factory DefectListView.fromJson(Map<String, dynamic> jsonSerialization) {
    return DefectListView(
      defects: _i3.Protocol().deserialize<List<_i2.DefectSummaryView>>(
        jsonSerialization['defects'],
      ),
      totalCount: jsonSerialization['totalCount'] as int,
    );
  }

  List<_i2.DefectSummaryView> defects;

  /// Rows matching the filters before `limit`/`offset` were applied.
  int totalCount;

  /// Returns a shallow copy of this [DefectListView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DefectListView copyWith({
    List<_i2.DefectSummaryView>? defects,
    int? totalCount,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DefectListView',
      'defects': defects.toJson(valueToJson: (v) => v.toJson()),
      'totalCount': totalCount,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DefectListView',
      'defects': defects.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'totalCount': totalCount,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _DefectListViewImpl extends DefectListView {
  _DefectListViewImpl({
    required List<_i2.DefectSummaryView> defects,
    required int totalCount,
  }) : super._(
         defects: defects,
         totalCount: totalCount,
       );

  /// Returns a shallow copy of this [DefectListView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DefectListView copyWith({
    List<_i2.DefectSummaryView>? defects,
    int? totalCount,
  }) {
    return DefectListView(
      defects: defects ?? this.defects.map((e0) => e0.copyWith()).toList(),
      totalCount: totalCount ?? this.totalCount,
    );
  }
}
