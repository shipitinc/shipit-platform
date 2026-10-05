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
///
/// Discovery answers two different questions, and deliberately does not
/// conflate them:
///
///  * **Technical structure** — what is this built from and how is it laid
///    out. This is mechanically observable, so it is scraped, aggregated and
///    reported as a small number of claims with real evidence.
///  * **Domain understanding** — what the product is for and what it means.
///    No file scanner can derive this. It comes from the operator, and this
///    reader only surfaces the documents such a claim should cite.
///
/// A repeated detector fires ONCE with an aggregate count and a bounded
/// evidence list, never once per file: a baseline asserting "json_serializable
/// codegen usage detected" 54 times states nothing a single claim does not,
/// and inflates the fact count into meaninglessness.
class ReadOnlyRepositoryReader {
  ReadOnlyRepositoryReader({
    required this.snapshotRoot,
    this.maxTextFileBytes = 256 * 1024,
    this.maxBinaryBytes = 16 * 1024 * 1024,
    this.maxEvidencePerClaim = 8,
  });

  /// Pinned, read-only snapshot (checkpoint 006 §repository immutability).
  final Directory snapshotRoot;

  /// Text files larger than this are summarized as metadata, not read in full.
  final int maxTextFileBytes;

  /// Binary files larger than this are classified, not read at all.
  final int maxBinaryBytes;

  /// Evidence paths listed per aggregated claim, so one claim stays readable.
  final int maxEvidencePerClaim;

  /// Files that are toolchain or OS bookkeeping, not product content.
  ///
  /// Reporting `.DS_Store` as an unreadable product file is noise that a human
  /// reviewer has to read past to find the real claims.
  static const _junkFileNames = {
    '.ds_store',
    'thumbs.db',
    'desktop.ini',
    '.gitkeep',
    '.gitignore',
    '.gitattributes',
  };

  bool _isJunkFile(String name) => _junkFileNames.contains(name.toLowerCase());

  /// Returns observations derived from inspecting the snapshot.
  ///
  /// This method never writes to [snapshotRoot] (or anywhere else). Every file
  /// read is opened for reading only; classification is content-derived and
  /// side-effect free.
  Future<List<DiscoveryObservation>> inspect() async {
    if (!snapshotRoot.existsSync()) {
      throw StateError('Snapshot root does not exist: ${snapshotRoot.path}');
    }
    final survey = _Survey();
    await _walk(snapshotRoot, survey, relativePath: '');
    return survey.toObservations(maxEvidencePerClaim);
  }

  Future<void> _walk(
    Directory dir,
    _Survey survey, {
    required String relativePath,
  }) async {
    final entries = dir.listSync(followLinks: false);
    for (final entry in entries) {
      final name = entry.path.split(Platform.pathSeparator).last;
      final rel = relativePath.isEmpty ? name : '$relativePath/$name';
      if (entry is Directory) {
        if (_isSkippedDirectory(name)) continue;
        await _walk(entry, survey, relativePath: rel);
        continue;
      }
      if (_isJunkFile(name)) continue;
      if (entry is Link) {
        continue;
      }
      await _classifyFile(File(entry.path), rel, survey);
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

  Future<void> _classifyFile(File file, String rel, _Survey survey) async {
    final stat = file.statSync();
    if (stat.type == FileSystemEntityType.link) {
      return;
    }
    final bytes = stat.size;
    final lower = rel.toLowerCase();

    if (_looksBinary(lower)) {
      if (bytes > maxBinaryBytes) {
        return;
      }
      return;
    }

    final isSecretShaped = Redactor.looksSecretShaped(lower);
    if (bytes > maxTextFileBytes) {
      return;
    }

    String content;
    try {
      content = await file.readAsString();
    } on FileSystemException {
      return;
    }

    if (isSecretShaped) {
      return;
    }

    final redacted = Redactor.redact(content);

    _classifyContent(lower, rel, redacted, survey);
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
    _Survey survey,
  ) {
    final name = lower.split('/').last;

    // Structure: build and orchestration.
    switch (name) {
      case 'pubspec.yaml':
        survey.noteToolchain('Dart package manifest', rel);
        if (content.contains('workspace:')) {
          survey.noteToolchain('Dart pub workspace (multi-package)', rel);
        }
        if (content.contains('resolution:')) {
          survey.noteToolchain('pinned SDK resolution', rel);
        }
      case 'melos.yaml':
        survey.noteToolchain('melos workspace orchestration', rel);
      case 'analysis_options.yaml':
        survey.noteQa('static analysis configuration', rel);
      case 'docker-compose.yaml':
      case 'docker-compose.yml':
        survey.noteEnvironments('docker compose infrastructure declared', rel);
      case 'dockerfile':
        survey.noteDeployment('Dockerfile present (containerizable)', rel);
    }

    // Deployment/environments: the real compose file in this repo lives at
    // docker/compose.yaml, which a bare `docker-compose.yaml` match misses.
    if (lower.endsWith('compose.yaml') || lower.endsWith('compose.yml')) {
      final services = _yamlTopLevelKeys(content, 'services');
      if (services.isNotEmpty) {
        survey.noteEnvironments(
          'container topology declares ${services.length} services '
          '(${services.join(', ')})',
          rel,
        );
      }
    }

    // Structural composition — one claim each, aggregated.
    if (content.contains('serverpod:')) {
      survey.noteToolchain('Serverpod backend framework in use', rel);
    }
    if (content.contains('@JsonSerializable')) {
      survey.noteToolchain('json_serializable codegen', rel);
    }
    // AGENTS.md is an opencode configuration file, not a governance artifact.
    // It is detected but not reported as a baseline claim.
    if (name == 'agents.md') {
      // intentionally no-op; tool config files are not product governance
    }

    // Package inventory: the workspace's own declared modules and how each one
    // describes itself. This is the closest a scanner gets to domain surface,
    // because the description is authored, not inferred.
    if (lower.endsWith('/pubspec.yaml') &&
        (lower.startsWith('packages/') || lower.contains('/packages/'))) {
      final pkgName = _yamlScalar(content, 'name');
      final description = _yamlScalar(content, 'description');
      if (pkgName != null) {
        survey.notePackage(name: pkgName, description: description, path: rel);
      }
    }

    // Architecture decision records: governance context a reviewer can cite.
    if (lower.endsWith('.md') &&
        (lower.startsWith('docs/adr/') || lower.contains('/docs/adr/'))) {
      final title = _firstHeading(content);
      if (title != null) {
        survey.noteAdr(title: title, path: rel);
      }
    }

    // The product's own account of itself, surfaced for the operator to turn
    // into domain claims. Discovery does not assert intent it cannot verify.
    if (lower.endsWith('readme.md') && !lower.contains('/packages/')) {
      survey.noteReadme(rel);
    }

    // Prompt-injection detection: report internally, never act or surface.
    _looksLikeInjection(content);
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

  static String? _firstHeading(String content) {
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('# ')) return trimmed.substring(2).trim();
    }
    return null;
  }

  /// Reads a top-level scalar such as `name:` or `description:` without a YAML
  /// dependency: a full parser would be a dependency for two fields.
  static String? _yamlScalar(String content, String key) {
    final pattern = RegExp('^\\s*$key:\\s*(.+)\$', multiLine: true);
    final match = pattern.firstMatch(content);
    if (match == null) return null;
    var value = match.group(1)!.trim();
    if ((value.startsWith("'") && value.endsWith("'")) ||
        (value.startsWith('"') && value.endsWith('"'))) {
      value = value.substring(1, value.length - 1);
    }
    return value.isEmpty ? null : value;
  }

  /// Collects the two-space-indented keys under [block], which is enough for
  /// a compose `services:` map and avoids a YAML dependency.
  static List<String> _yamlTopLevelKeys(String content, String block) {
    final keys = <String>[];
    var inBlock = false;
    for (final raw in content.split('\n')) {
      if (RegExp('^$block:\\s*\$').hasMatch(raw)) {
        inBlock = true;
        continue;
      }
      if (!inBlock) continue;
      if (raw.trim().isEmpty || raw.trimLeft().startsWith('#')) continue;
      // Dedent out of the block.
      if (!raw.startsWith(' ') && !raw.startsWith('\t')) break;
      final m = RegExp(r'^  ([A-Za-z0-9_.-]+):\s*$').firstMatch(raw);
      if (m != null) keys.add(m.group(1)!);
    }
    return keys;
  }
}

/// Accumulates per-file hits and emits a small set of aggregated claims.
///
/// Discovery is per-file but the baseline is per-product: the survey is where
/// that translation happens, so detectors cannot accidentally emit one claim
/// per file.
class _Survey {
  final Map<String, List<String>> _techStack = {};
  final Map<String, List<String>> _qa = {};
  final Map<String, List<String>> _environments = {};
  final Map<String, List<String>> _deployment = {};
  final Map<String, List<String>> _governance = {};
  final Map<String, List<String>> _knownGaps = {};
  final List<Map<String, String?>> _packages = []; // package inventory
  final List<Map<String, String>> _adrs = []; // ADR titles
  final List<String> _readmes = []; // README paths

  void noteToolchain(String claim, String path) =>
      _techStack.putIfAbsent(claim, () => []).add(path);
  void noteQa(String claim, String path) =>
      _qa.putIfAbsent(claim, () => []).add(path);
  void noteEnvironments(String claim, String path) =>
      _environments.putIfAbsent(claim, () => []).add(path);
  void noteDeployment(String claim, String path) =>
      _deployment.putIfAbsent(claim, () => []).add(path);
  void noteGovernance(String claim, String path) =>
      _governance.putIfAbsent(claim, () => []).add(path);
  void noteReadme(String path) => _readmes.add(path);

  void notePackage({
    required String name,
    required String? description,
    required String path,
  }) {
    _packages.add({'name': name, 'description': description, 'path': path});
  }

  void noteAdr({required String title, required String path}) {
    _adrs.add({'title': title, 'path': path});
  }

  void noteKnownGap(String claim, String path) =>
      _knownGaps.putIfAbsent(claim, () => []).add(path);

  List<DiscoveryObservation> toObservations(int maxEvidence) {
    final out = <DiscoveryObservation>[];

    void emitMap(
      String section,
      Map<String, List<String>> items,
      BaselineSectionKey key,
      Provenance provenance,
    ) {
      for (final entry in items.entries) {
        final paths = entry.value;
        out.add(
          DiscoveryObservation(
            section: key,
            claim: entry.key,
            provenance: provenance,
            evidencePaths: _bounded(paths, maxEvidence),
          ),
        );
      }
    }

    emitMap(
      'tech_stack',
      _techStack,
      BaselineSectionKey.techStack,
      Provenance.derived,
    );
    emitMap('qa', _qa, BaselineSectionKey.qa, Provenance.observed);
    emitMap(
      'environments',
      _environments,
      BaselineSectionKey.environments,
      Provenance.observed,
    );
    emitMap(
      'deployment',
      _deployment,
      BaselineSectionKey.deployment,
      Provenance.observed,
    );
    emitMap(
      'governance',
      _governance,
      BaselineSectionKey.governance,
      Provenance.observed,
    );
    emitMap(
      'known_gaps',
      _knownGaps,
      BaselineSectionKey.knownGaps,
      Provenance.observed,
    );

    // Package inventory — authored descriptions, so this is real signal about
    // what the workspace is for, not an inferred guess.
    final packages = _packages.length;
    if (packages > 0) {
      out.add(
        DiscoveryObservation(
          section: BaselineSectionKey.architecture,
          claim:
              'workspace is composed of $packages Dart packages under '
              'packages/, each declaring its own responsibility',
          provenance: Provenance.derived,
          evidencePaths: _bounded(
            _packages.map((p) => p['path']!).toList(),
            maxEvidence,
          ),
        ),
      );
    }
    for (final p in _packages) {
      final description = p['description'];
      out.add(
        DiscoveryObservation(
          section: BaselineSectionKey.architecture,
          claim: description == null
              ? "package ${p['name']} (no description declared)"
              : "${p['name']} — $description",
          // Package descriptions are declared in pubspec.yaml (in the repo).
          // They are scraped, not operator-entered.
          provenance: Provenance.observed,
          evidencePaths: [p['path']!],
        ),
      );
    }

    // Architecture decision records: the governance record a reviewer can cite.
    if (_adrs.isNotEmpty) {
      out.add(
        DiscoveryObservation(
          section: BaselineSectionKey.governance,
          claim:
              '${_adrs.length} architecture decision records document how '
              'and why this platform is built the way it is',
          provenance: Provenance.derived,
          evidencePaths: _bounded(
            _adrs.map((a) => a['path']!).toList(),
            maxEvidence,
          ),
        ),
      );
      for (final adr in _adrs) {
        out.add(
          DiscoveryObservation(
            section: BaselineSectionKey.governance,
            claim: 'ADR: ${adr['title']}',
            // ADRs are human-authored documents IN the repo, not operator-entered
            // claims. They are scraped, so provenance is observed.
            provenance: Provenance.observed,
            evidencePaths: [adr['path']!],
          ),
        );
      }
    }

    // The product's own documentation, named so the operator can write domain
    // claims against it instead of the scanner guessing at intent.
    for (final readme in _readmes) {
      out.add(
        DiscoveryObservation(
          section: BaselineSectionKey.architecture,
          claim:
              'product self-describes in $readme — source material for '
              'operator-authored domain claims, not yet a domain claim itself',
          provenance: Provenance.observed,
          evidencePaths: [readme],
        ),
      );
    }

    return out;
  }

  static List<String> _bounded(List<String> paths, int max) {
    if (paths.length <= max) return paths;
    return [...paths.take(max), '…and ${paths.length - max} more'];
  }
}
