import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/repository_kind.dart';
import '../enums/repository_provider.dart';

part 'repository_reference.g.dart';

/// A repository owned by exactly one Product (checkpoint 006 §8).
///
/// Durable repository identity lives here ([repositoryId], [uri],
/// [provider]) and is separate from any temporary checkout/worktree/path.
/// Product identity is never derived from the filesystem: durable identity is
/// the registry record, not the worktree location.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class RepositoryReference extends Equatable {
  const RepositoryReference({
    required this.repositoryId,
    required this.productId,
    this.kind = RepositoryKind.monorepo,
    required this.uri,
    this.provider = RepositoryProvider.local,
    required this.addedAt,
    this.version = 1,
  });

  final String repositoryId;

  /// DIRECT scope: exactly one owning Product.
  final String productId;

  final RepositoryKind kind;

  /// Remote URL or canonical durable location; never a worktree path.
  final String uri;

  final RepositoryProvider provider;

  final DateTime addedAt;

  final int version;

  RepositoryReference copyWith({int? version}) => RepositoryReference(
    repositoryId: repositoryId,
    productId: productId,
    kind: kind,
    uri: uri,
    provider: provider,
    addedAt: addedAt,
    version: version ?? this.version,
  );

  factory RepositoryReference.fromJson(Map<String, dynamic> json) =>
      _$RepositoryReferenceFromJson(json);

  Map<String, dynamic> toJson() => _$RepositoryReferenceToJson(this);

  @override
  List<Object?> get props => [
    repositoryId,
    productId,
    kind,
    uri,
    provider,
    addedAt,
    version,
  ];
}
