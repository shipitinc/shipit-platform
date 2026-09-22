import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/audit_entity_type.dart';
import '../enums/audit_action.dart';

part 'product_registry_audit.g.dart';

/// Append-only audit log entry for product registry mutations.
///
/// Every write operation (create/update/transition) records an entry here.
/// Never deleted, never updated — only inserted.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class ProductRegistryAudit extends Equatable {
  const ProductRegistryAudit({
    required this.auditId,
    required this.productId,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.beforeJson,
    this.afterJson,
    this.actor,
    required this.timestamp,
  });

  final String auditId;
  final String productId;

  @JsonKey(fromJson: _entityTypeFromWire, toJson: _entityTypeToWire)
  final AuditEntityType entityType;

  final String entityId;

  @JsonKey(fromJson: _actionFromWire, toJson: _actionToWire)
  final AuditAction action;

  final String? beforeJson;
  final String? afterJson;
  final String? actor;
  final DateTime timestamp;

  factory ProductRegistryAudit.fromJson(Map<String, dynamic> json) =>
      _$ProductRegistryAuditFromJson(json);

  Map<String, dynamic> toJson() => _$ProductRegistryAuditToJson(this);

  @override
  List<Object?> get props => [
        auditId,
        productId,
        entityType,
        entityId,
        action,
        beforeJson,
        afterJson,
        actor,
        timestamp,
      ];
}

AuditEntityType _entityTypeFromWire(String value) =>
    AuditEntityType.fromWire(value);

String _entityTypeToWire(AuditEntityType value) => value.wire;

AuditAction _actionFromWire(String value) => AuditAction.fromWire(value);

String _actionToWire(AuditAction value) => value.wire;