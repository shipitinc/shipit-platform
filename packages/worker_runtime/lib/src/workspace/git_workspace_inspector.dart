import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';

/// The platform's independent, git-observed view of a worktree after an
/// execution. Never derives from what the agent claims it did.
class GitWorkspaceInspection {
  const GitWorkspaceInspection({
    required this.revision,
    required this.changedFiles,
    this.diffSummary,
  });

  final String revision;
  final List<ChangedFile> changedFiles;
  final String? diffSummary;
}

/// Runs git read-only commands against a worktree with a hard bound so a
/// wedged filesystem cannot hold the worker hostage. Commands are read-only;
/// all workspace mutation lives in [GitWorktreeWorkspaceManager].
class GitWorkspaceInspector {
  const GitWorkspaceInspector({
    this.git = 'git',
    this.timeout = const Duration(seconds: 30),
  });

  final String git;
  final Duration timeout;

  Future<GitWorkspaceInspection> inspect(
    String worktreePath, {
    required String startingRevision,
  }) async {
    final revision = await _capture(['-C', worktreePath, 'rev-parse', 'HEAD']);
    final changedFiles = await _changedFiles(worktreePath, startingRevision);
    final diffStat = await _captureOrNull([
      '-C',
      worktreePath,
      '--no-optional-locks',
      'diff',
      '--stat',
      startingRevision,
    ]);

    return GitWorkspaceInspection(
      revision: revision.trim(),
      changedFiles: changedFiles,
      diffSummary: diffStat?.trim(),
    );
  }

  Future<List<ChangedFile>> _changedFiles(
    String worktreePath,
    String startingRevision,
  ) async {
    final nameStatus = await _captureOrNull([
      '-C',
      worktreePath,
      '--no-optional-locks',
      'diff',
      '--name-status',
      startingRevision,
    ]);

    final files = <ChangedFile>[];
    if (nameStatus == null || nameStatus.trim().isEmpty) return files;

    for (final line in nameStatus.trim().split('\n')) {
      if (line.isEmpty) continue;
      final parsed = _parseNameStatus(line);
      if (parsed != null) files.add(parsed);
    }
    return files;
  }

  /// Parses `git diff --name-status` lines: `M\tlib/foo.dart`,
  /// `A\tlib/bar.dart`, `D\told.dart`, `R100\tfrom.dart\tto.dart`.
  ChangedFile? _parseNameStatus(String line) {
    final parts = line.split('\t');
    if (parts.isEmpty) return null;
    final status = parts.first;
    final path = parts.length > 1 ? parts[1] : '';

    final operation = switch (status.isEmpty ? '' : status[0]) {
      'A' => ChangedFileOperation.added,
      'D' => ChangedFileOperation.deleted,
      'M' => ChangedFileOperation.modified,
      'R' => ChangedFileOperation.renamed,
      _ => null,
    };
    if (operation == null) return null;

    return ChangedFile(
      path: path,
      operation: operation,
      beforeSha: status.length > 1 && status[1] == '1' ? _oldPath(line) : null,
    );
  }

  String? _oldPath(String line) {
    final parts = line.split('\t');
    return parts.length > 2 ? parts[1] : null;
  }

  Future<String> _capture(List<String> args) async {
    final result = await Process.run(git, args);
    if (result.exitCode != 0) {
      throw GitCommandException(args, result.exitCode, result.stderr);
    }
    return result.stdout as String;
  }

  Future<String?> _captureOrNull(List<String> args) async {
    try {
      return await _capture(args);
    } on GitCommandException {
      return null;
    }
  }
}

class GitCommandException implements Exception {
  const GitCommandException(this.args, this.exitCode, this.stderr);

  final List<String> args;
  final int exitCode;
  final Object stderr;

  @override
  String toString() =>
      'git ${args.join(' ')} exited $exitCode: ${stderr.toString().trim()}';
}
