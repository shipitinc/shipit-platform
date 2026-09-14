import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'workspace_descriptor.g.dart';

/// Durable ownership metadata for a platform-created execution workspace.
/// Written outside the worktree so reconciliation never has to infer ownership
/// from directory naming, and so only platform-owned directories are ever
/// cleaned.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class WorkspaceDescriptor extends Equatable {
  const WorkspaceDescriptor({
    required this.workspaceId,
    required this.workerExecutionId,
    required this.workerId,
    required this.repositoryPath,
    required this.startingRevision,
    required this.worktreePath,
    this.branch,
    this.detached = true,
    required this.createdAt,
    this.cleanedAt,
  });

  final String workspaceId;
  final String workerExecutionId;
  final String workerId;

  /// Source checkout the worktree was created from.
  final String repositoryPath;

  /// The exact committed revision the worktree is pinned to.
  final String startingRevision;
  final String worktreePath;
  final String? branch;

  /// Worktrees start detached at [startingRevision], never on a shared branch.
  final bool detached;
  final DateTime createdAt;
  final DateTime? cleanedAt;

  bool get isCleaned => cleanedAt != null;

  factory WorkspaceDescriptor.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceDescriptorFromJson(json);

  Map<String, dynamic> toJson() => _$WorkspaceDescriptorToJson(this);

  WorkspaceDescriptor markCleaned(DateTime at) => WorkspaceDescriptor(
    workspaceId: workspaceId,
    workerExecutionId: workerExecutionId,
    workerId: workerId,
    repositoryPath: repositoryPath,
    startingRevision: startingRevision,
    worktreePath: worktreePath,
    branch: branch,
    detached: detached,
    createdAt: createdAt,
    cleanedAt: at,
  );

  @override
  List<Object?> get props => [
    workspaceId,
    workerExecutionId,
    workerId,
    repositoryPath,
    startingRevision,
    worktreePath,
    branch,
    detached,
    createdAt,
    cleanedAt,
  ];
}
