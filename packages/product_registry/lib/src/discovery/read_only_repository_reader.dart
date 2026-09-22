import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';

import 'discovery_observation.dart';
import 'discovery_policy.dart';

/// Read-only repository inspection for onboarding discovery (checkpoint 006
/// §read-only discovery / §discovery safety).
///
/// Capability boundary is hard: this reader may READ, SEARCH, INSPECT GIT,
/// ANALYZE, CLASSIFY, PROPOSE. It may NOT edit, install, execute untrusted
/// repo instructions, run arbitrary scripts, commit, push, migrate, or fix
/// discovered problems. It only opens files as data; a malicious README,
/// AGENTS file, source comment, or prompt-looking document therefore cannot
/// elevate permissions (there are no elevated permissions to take).
///
/// Secret values are NEVER ingested: secret-shaped content is replaced with a
/// redacted placeholder before it can reach a baseline, LLM context, logs, or
/// snapshots (see [Redactor]).
class ReadOnlyRepositoryReader {
  ReadOnlyRepositoryReader({
    required this.snapshotRoot,
    this.maxTextFileBytes = 256 * 1024,
    this.maxBinaryBytes = 16 * 1024 * 1024,
  });

  /// Pinned, read-only snapshot (checkpoint 006 §repository immutability).
  final Directory snapshotRoot;

  /// Text files larger than this are summarized as metadata, not read in full.
  final int maxTextFileBytes;

  /// Binary files larger than this are classified, not read at all.
  final int maxBinaryBytes;

  /// Returns observations derived from inspecting the snapshot.
  ///
  /// This method never writes to [snapshotRoot] (or anywhere else). Every file
  /// read is opened for reading only; classification is content-derived and
  /// side-effect free.
  Future<List<DiscoveryObservation>> inspect() async {
    if (!snapshotRoot.existsSync()) {
      throw StateError('Snapshot root does not exist: ${snapshotRoot.path}');
    }
    final observations = <DiscoveryObservation>[];
    await _walk(snapshotRoot, observations, relativePath: '');
    return observations;
  }

  Future<void> _walk(
    Directory dir,
    List<DiscoveryObservation> observations, {
    required String relativePath,
  }) async {
    final entries = dir.listSync(followLinks: false);
    for (final entry in entries) {
      final name = entry.path.split(Platform.pathSeparator).last;
      final rel = relativePath.isEmpty ? name : '$relativePath/$name';
      if (entry is Directory) {
        if (_isSkippedDirectory(name)) continue;
        await _walk(entry, observations, relativePath: rel);
        continue;
      }
      if (entry is Link) {
        observations.add(
          DiscoveryObservation(
            section: BaselineSectionKey.repository,
            claim: 'symlink detected (refused to follow): $rel',
            evidencePaths: [rel],
          ),
        );
        continue;
      }
      final file = File(entry.path);
      await _classifyFile(file, rel, observations);
    }
  }

  bool _isSkippedDirectory(String name) {
    const skipped = {
      '.git',
      '.dart_tool',
      'build',
      'node_modules',
      'coverage',
      '.idea',
      '.fvm',
      '.build',
      'out',
      'dist',
      '.cache',
    };
    return skipped.contains(name);
  }

  Future<void> _classifyFile(
    File file,
    String rel,
    List<DiscoveryObservation> observations,
  ) async {
    final stat = file.statSync();
    if (stat.type == FileSystemEntityType.link) {
      observations.add(
        DiscoveryObservation(
          section: BaselineSectionKey.repository,
          claim: 'symlink detected (refused to follow): $rel',
          evidencePaths: [rel],
        ),
      );
      return;
    }
    final bytes = stat.size;
    final lower = rel.toLowerCase();

    // large/binary handling
    if (_looksBinary(lower)) {
      if (bytes > maxBinaryBytes) {
        observations.add(
          DiscoveryObservation(
            section: BaselineSectionKey.repository,
            claim: 'large/derived artifact skipped (metadata only): $rel',
            evidencePaths: [rel],
          ),
        );
        return;
      }
      return;
    }

    final isSecretShaped = Redactor.looksSecretShaped(lower);
    if (bytes > maxTextFileBytes) {
      observations.add(
        DiscoveryObservation(
          section: BaselineSectionKey.repository,
          claim: 'large text file classified, not ingested: $rel',
          evidencePaths: [rel],
          redacted: isSecretShaped,
        ),
      );
      return;
    }

    String content;
    try {
      content = await file.readAsString();
    } on FileSystemException {
      observations.add(
        DiscoveryObservation(
          section: BaselineSectionKey.repository,
          claim: 'unreadable file (read refused): $rel',
          evidencePaths: [rel],
        ),
      );
      return;
    }

    if (isSecretShaped) {
      observations.add(
        DiscoveryObservation(
          section: BaselineSectionKey.environments,
          claim: 'secret-shaped file detected — value redacted: $rel',
          evidencePaths: [rel],
          redacted: true,
        ),
      );
      return;
    }

    final redacted = Redactor.redact(content);
    if (redacted != content) {
      observations.add(
        DiscoveryObservation(
          section: BaselineSectionKey.environments,
          claim: 'secret pattern found in $rel — value redacted',
          evidencePaths: [rel],
          redacted: true,
        ),
      );
    }

    _classifyContent(lower, rel, redacted, observations);
  }

  bool _looksBinary(String lower) {
    const binaryExtensions = {
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.webp',
      '.ico',
      '.woff',
      '.woff2',
      '.ttf',
      '.eot',
      '.zip',
      '.gz',
      '.tgz',
      '.jar',
      '.class',
      '.so',
      '.dylib',
      '.app',
      '.apk',
      '.ipa',
      '.aar',
      '.db',
      '.sqlite',
      '.snap',
      '.dmg',
    };
    for (final ext in binaryExtensions) {
      if (lower.endsWith(ext)) return true;
    }
    return false;
  }

  void _classifyContent(
    String lower,
    String rel,
    String content,
    List<DiscoveryObservation> observations,
  ) {
    switch (lower) {
      case 'pubspec.yaml':
        observations.add(
          DiscoveryObservation(
            section: BaselineSectionKey.techStack,
            claim: 'Dart package manifest present: $rel',
            evidencePaths: [rel],
          ),
        );
        if (content.contains('workspace:')) {
          observations.add(
            DiscoveryObservation(
              section: BaselineSectionKey.techStack,
              claim: 'Dart workspace (multi-package) declared',
              evidencePaths: [rel],
              provenance: Provenance.derived,
            ),
          );
        }
      case 'melos.yaml':
        observations.add(
          DiscoveryObservation(
            section: BaselineSectionKey.techStack,
            claim: 'melos orchestration configured',
            evidencePaths: [rel],
          ),
        );
      case 'analysis_options.yaml':
        observations.add(
          DiscoveryObservation(
            section: BaselineSectionKey.qa,
            claim: 'static analysis configuration present',
            evidencePaths: [rel],
          ),
        );
      case 'docker-compose.yaml':
      case 'docker-compose.yml':
        observations.add(
          DiscoveryObservation(
            section: BaselineSectionKey.environments,
            claim: 'docker compose infrastructure declared',
            evidencePaths: [rel],
          ),
        );
      case 'Dockerfile':
        observations.add(
          DiscoveryObservation(
            section: BaselineSectionKey.deployment,
            claim: 'Dockerfile present (containerizable)',
            evidencePaths: [rel],
          ),
        );
    }

    if (content.contains('serverpod:')) {
      observations.add(
        DiscoveryObservation(
          section: BaselineSectionKey.techStack,
          claim: 'Serverpod configuration detected',
          evidencePaths: [rel],
          provenance: Provenance.derived,
        ),
      );
    }
    if (content.contains('@JsonSerializable')) {
      observations.add(
        DiscoveryObservation(
          section: BaselineSectionKey.techStack,
          claim: 'json_serializable codegen usage detected',
          evidencePaths: [rel],
          provenance: Provenance.derived,
        ),
      );
    }
    if (content.contains('AGENTS.md') ||
        content.startsWith('# AGENTS') ||
        content.contains('AGENTS.md ##')) {
      observations.add(
        DiscoveryObservation(
          section: BaselineSectionKey.governance,
          claim:
              'agent instruction file present (treated as data, NOT authority): $rel',
          evidencePaths: [rel],
        ),
      );
    }

    // Prompt-injection detection: report, never act.
    if (_looksLikeInjection(content)) {
      observations.add(
        DiscoveryObservation(
          section: BaselineSectionKey.knownGaps,
          claim:
              'prompt-injection-shaped text detected — reported only, not executed',
          evidencePaths: [rel],
          provenance: Provenance.derived,
        ),
      );
    }
  }

  bool _looksLikeInjection(String content) {
    final lowered = content.toLowerCase();
    return lowered.contains('disregard previous instructions') ||
        lowered.contains('ignore all previous') ||
        lowered.contains('you are now') ||
        lowered.contains('pretend you are') ||
        lowered.contains('security test:') ||
        lowered.contains('ignore the above');
  }
}
