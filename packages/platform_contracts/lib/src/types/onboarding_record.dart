import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'onboarding_record.g.dart';

/// Durable onboarding progress for one Product.
///
/// Onboarding writes a bounded bootstrap record (checkpoint 006 §4.2/§18):
/// the Product lifecycle stays on the existing `ProductState` enum; this
/// record tracks the onboarding/progress itself and is what a restarted
/// execution resumes (same Product, same baseline lineage, same clarifications).
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class OnboardingRecord extends Equatable {
  const OnboardingRecord({
    required this.onboardingId,
    required this.productId,
    this.currentBaselineRevision = 0,
    this.pendingClarifications = 0,
    this.completed = false,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  });

  final String onboardingId;
  final String productId;

  /// Highest baseline revision proposed/produced so far (0 = none yet).
  final int currentBaselineRevision;

  /// Number of clarifications awaiting a human answer right now.
  final int pendingClarifications;

  /// True once an exact baseline revision reached human acceptance.
  final bool completed;

  final DateTime createdAt;
  final DateTime updatedAt;

  final int version;

  OnboardingRecord copyWith({
    int? currentBaselineRevision,
    int? pendingClarifications,
    bool? completed,
    DateTime? updatedAt,
    int? version,
  }) => OnboardingRecord(
    onboardingId: onboardingId,
    productId: productId,
    currentBaselineRevision:
        currentBaselineRevision ?? this.currentBaselineRevision,
    pendingClarifications: pendingClarifications ?? this.pendingClarifications,
    completed: completed ?? this.completed,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
  );

  factory OnboardingRecord.fromJson(Map<String, dynamic> json) =>
      _$OnboardingRecordFromJson(json);

  Map<String, dynamic> toJson() => _$OnboardingRecordToJson(this);

  @override
  List<Object?> get props => [
    onboardingId,
    productId,
    currentBaselineRevision,
    pendingClarifications,
    completed,
    createdAt,
    updatedAt,
    version,
  ];
}
