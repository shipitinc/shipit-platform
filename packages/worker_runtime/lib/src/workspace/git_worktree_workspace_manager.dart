import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';

import 'workspace_manager.dart';

/// Thrown when a workspace cannot be prepared (invalid repo, unknown
/// starting revision, git failure). The worker maps this to [prepareFailed].
class WorkspacePrepareException implements Exception {
  WorkspacePrepareException(this.detail);

  final String detail;

  @override
  String toString() => 'WorkspacePrepareException: $detail';
}

/// Default [WorkspaceManager]: creates an isolated, detached git worktree
/// pinned to the request's explicit starting revision.
///
/// Safety properties:
///  * the agent never runs in [WorkerExecutionRequest.repositoryPath];
///  * worktrees are detached, never on a shared branch;
///  * ownership metadata (a [WorkspaceDescriptor] JSON file) is written well
///    outside the worktree, so reconciliation only ever cleans directories the
///    platform itself created;
///  * cleanup never touches unknown directories and is idempotent.
class GitWorktreeWorkspaceManager implements WorkspaceManager {
  GitWorktreeWorkspaceManager({
    required String workspaceRoot,
    this.git = 'git',
    this.gitTimeout = const Duration(seconds: 60),
  }) : _workspaceRoot = Directory(workspaceRoot) {
    _workspaceRoot.createSync(recursive: true);
  }

  final Directory _workspaceRoot;
  final String git;
  final Duration gitTimeout;

  Future<T> _git<T>(Future<T> Function() run) async {
    return run().timeout(
      gitTimeout,
      onTimeout: () =>
          throw WorkspacePrepareException('git command exceeded $gitTimeout'),
    );
  }

  Future<ProcessResult> _runGit(List<String> args) async {
    final result = await _git(
      () => Process.run(git, args, stdoutEncoding: utf8, stderrEncoding: utf8),
    );
    if (result.exitCode != 0) {
      throw WorkspacePrepareException(
        'git ${args.join(' ')} exited ${result.exitCode}: '
        '${result.stderr.toString().trim()}',
      );
    }
    return result;
  }

  File _descriptorFileFor(String workspaceId) =>
      File('${_workspaceRoot.path}/$workspaceId.json');

  String _worktreePathFor(String workspaceId) =>
      '${_workspaceRoot.path}/$workspaceId';

  @override
  Future<WorkspaceDescriptor> prepare(
    WorkerExecutionRequest request, {
    String workerId = '',
  }) async {
    final workspaceId = 'ws-${request.workerExecutionId}';
    final worktreePath = _worktreePathFor(workspaceId);

    if (Directory(worktreePath).existsSync()) {
      throw WorkspacePrepareException(
        'workspace $workspaceId already exists (orphan from a prior '
        'execution); reconcile before retrying',
      );
    }

    // Validate the explicit starting revision BEFORE creating anything.
    await _runGit([
      '-C',
      request.repositoryPath,
      'rev-parse',
      '--verify',
      '${request.startingRevision}^{commit}',
    ]);

    await _runGit([
      '-C',
      request.repositoryPath,
      'worktree',
      'add',
      '--detach',
      worktreePath,
      request.startingRevision,
    ]);

    // Wrong-revision guard: the worktree must be exactly the requested commit.
    final head = await _runGit(['-C', worktreePath, 'rev-parse', 'HEAD']);
    final actualRevision = head.stdout.toString().trim();
    final requested = request.startingRevision.trim();
    if (actualRevision != requested) {
      await _removeWorktreeUnsafe(worktreePath);
      throw WorkspacePrepareException(
        'worktree HEAD ($actualRevision) does not match requested revision '
        '($requested); refusing to run on the wrong revision',
      );
    }

    final descriptor = WorkspaceDescriptor(
      workspaceId: workspaceId,
      workerExecutionId: request.workerExecutionId,
      workerId: workerId,
      repositoryPath: request.repositoryPath,
      startingRevision: actualRevision,
      worktreePath: worktreePath,
      detached: true,
      createdAt: DateTime.now().toUtc(),
    );

    final file = _descriptorFileFor(workspaceId);
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(descriptor.toJson()),
    );
    await temp.rename(file.path);

    return descriptor;
  }

  @override
  Future<WorkerCleanupStatus> cleanup(WorkspaceDescriptor descriptor) async {
    if (descriptor.isCleaned) return WorkerCleanupStatus.removed;

    final file = _descriptorFileFor(descriptor.workspaceId);
    try {
      await _removeWorktreeUnsafe(descriptor.worktreePath);

      final cleaned = descriptor.markCleaned(DateTime.now().toUtc());
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(
        const JsonEncoder.withIndent('  ').convert(cleaned.toJson()),
      );
      await temp.rename(file.path);
      return WorkerCleanupStatus.removed;
    } on WorkspacePrepareException {
      return WorkerCleanupStatus.cleanupFailed;
    }
  }

  /// Removes the worktree directory. The repository becomes the source of
  /// truth again; dirty agent edits inside the worktree die with it.
  Future<void> _removeWorktreeUnsafe(String worktreePath) async {
    if (!Directory(worktreePath).existsSync()) return;
    await _runGit([
      '-C',
      worktreePath,
      'worktree',
      'remove',
      '--force',
      worktreePath,
    ]);
  }

  @override
  Future<List<WorkspaceDescriptor>> discoverAll() async {
    final descriptors = <WorkspaceDescriptor>[];
    if (!_workspaceRoot.existsSync()) return descriptors;
    for (final entity in _workspaceRoot.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final decoded = jsonDecode(entity.readAsStringSync());
        final descriptor = WorkspaceDescriptor.fromJson(
          decoded as Map<String, dynamic>,
        );
        // A cleaned workspace is no longer a live workspace.
        if (!descriptor.isCleaned) descriptors.add(descriptor);
      } on Object {
        // Malformed metadata is left untouched; never delete on a guess.
        continue;
      }
    }
    return descriptors;
  }
}
