// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_context.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductContext _$ProductContextFromJson(
  Map<String, dynamic> json,
) => ProductContext(
  product: Product.fromJson(json['product'] as Map<String, dynamic>),
  repositories:
      (json['repositories'] as List<dynamic>?)
          ?.map((e) => RepositoryReference.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  activeBaseline: json['activeBaseline'] == null
      ? null
      : ProductBaseline.fromJson(
          json['activeBaseline'] as Map<String, dynamic>,
        ),
  allBaselines:
      (json['allBaselines'] as List<dynamic>?)
          ?.map((e) => ProductBaseline.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  openClarifications:
      (json['openClarifications'] as List<dynamic>?)
          ?.map((e) => ClarificationRequest.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  snapshotId: json['snapshotId'] as String?,
);

Map<String, dynamic> _$ProductContextToJson(ProductContext instance) =>
    <String, dynamic>{
      'product': instance.product.toJson(),
      'repositories': instance.repositories.map((e) => e.toJson()).toList(),
      'activeBaseline': ?instance.activeBaseline?.toJson(),
      'allBaselines': instance.allBaselines.map((e) => e.toJson()).toList(),
      'openClarifications': instance.openClarifications
          .map((e) => e.toJson())
          .toList(),
      'snapshotId': ?instance.snapshotId,
    };
