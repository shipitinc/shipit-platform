// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
  productId: json['productId'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  manifestVersion: json['manifestVersion'] as String?,
  state: json['state'] == null
      ? ProductState.registered
      : _stateFromWire(json['state'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  version: (json['version'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
  'productId': instance.productId,
  'name': instance.name,
  'description': ?instance.description,
  'manifestVersion': ?instance.manifestVersion,
  'state': _stateToWire(instance.state),
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'version': instance.version,
};
