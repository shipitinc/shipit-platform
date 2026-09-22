// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_registry_audit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductRegistryAudit _$ProductRegistryAuditFromJson(
  Map<String, dynamic> json,
) => ProductRegistryAudit(
  auditId: json['auditId'] as String,
  productId: json['productId'] as String,
  entityType: _entityTypeFromWire(json['entityType'] as String),
  entityId: json['entityId'] as String,
  action: _actionFromWire(json['action'] as String),
  beforeJson: json['beforeJson'] as String?,
  afterJson: json['afterJson'] as String?,
  actor: json['actor'] as String?,
  timestamp: DateTime.parse(json['timestamp'] as String),
);

Map<String, dynamic> _$ProductRegistryAuditToJson(
  ProductRegistryAudit instance,
) => <String, dynamic>{
  'auditId': instance.auditId,
  'productId': instance.productId,
  'entityType': _entityTypeToWire(instance.entityType),
  'entityId': instance.entityId,
  'action': _actionToWire(instance.action),
  'beforeJson': ?instance.beforeJson,
  'afterJson': ?instance.afterJson,
  'actor': ?instance.actor,
  'timestamp': instance.timestamp.toIso8601String(),
};
