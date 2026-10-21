import 'package:platform_contracts/platform_contracts.dart';

import '../gate_evaluator.dart';
import '../source_provenance.dart';

/// Where the collector runs git and the left edge of the range it enumerates.
class CommittedDiffScopeBaseline {
  const CommittedDiffScopeBaseline({
    required this.workingDirectory,
    required this.startingRevision,
  });

  /// The lane execution's workspace — `git -C <workingDirectory>`.
  final String workingDirectory;

  /// The revision the execution started from: `<startingRevision>..` is the
  /// left edge of `<start>..<produced>`.
  final String startingRevision;
}

/// Reads the enumerated path set F2 judges, from the source the design names.
///
/// ## Why this is an interface
///
/// `qa_orchestration` does not depend on `execution_coordinator`, where P1's
/// `CommittedDiffPathCollector` lives
/// (`committed_diff_path_collector.dart:107`). The production implementation
/// (slice 3c) is that collector behind this adapter; a gate must be evaluable
/// in a test without a worktree.
///
/// ## The `producedRevision` dependency, stated rather than faked
///
/// [readProducedHead] returns **P1's re-read** — the same
/// `WorkspaceHeadReader` answer F1 judges and F5 compares against
/// (`workspace_head_reader.dart:54-86`), with the same signature F5's
/// `RevisionIdentitySource.readProducedHead` declares
/// (`revision_identity_match_gate.dart:37`). One adapter object can therefore
/// serve all three gates with one underlying read.
///
/// It is **not** a value threaded out of F1's `QAGateResult`:
/// `QAOrchestration.evaluate` calls each evaluator with only
/// `(workItemId, agentResult, gate)` and passes no prior results
/// (`qa_orchestration.dart:18-35`), so no such channel exists today. Nothing
/// here invents one: the evaluator asks the source for the re-read directly,
/// and the production adapter obtains it by calling `WorkspaceHeadReader.read`
/// itself. Sharing a single re-read across F1/F2/F5 per run — instead of each
/// gate's adapter reading it — is wiring for M1/3c, not a value this interface
/// may fabricate.
abstract interface class ChangeScopeSource implements QASourceProvenanceAware {
  /// The workspace and starting revision of the lane's execution, or `null`
  /// when either could not be established ("I could not look").
  Future<CommittedDiffScopeBaseline?> readBaseline(String workItemId);

  /// P1's re-read of `HEAD` for [workItemId]. `null` means **"HEAD could not
  /// be established"** and is never `WorkspaceHead(headMoved: false)`.
  Future<WorkspaceHead?> readProducedHead(String workItemId);

  /// P1's `CommittedDiffPathCollector.collect`, verbatim: the **uncapped**
  /// union of `git diff --name-only <start>..<produced>` and
  /// `git ls-files --others --exclude-standard`.
  ///
  /// Throws (the collector's own exception) when either enumeration fails.
  /// The contract is identical to the collector's: **a failure surfaces as an
  /// exception, never as a shorter list and never as an empty one** — the
  /// adapter must return the collector's result verbatim and map nothing.
  Future<CommittedDiffPaths> collectPaths({
    required String workingDirectory,
    required String startingRevision,
    required String producedRevision,
  });
}

/// The feature lane's F2 gate: every changed path is owned; none is
/// prohibited.
///
/// Passes iff **every** path in the enumerated set matches `>=1` of
/// `ownedPathGlobs` and **zero** of `forbiddenPathGlobs`.
///
/// ## The reader is P1's collector, and the two broken substitutes are not
/// reachable from here
///
/// * `WorkspaceDelta.changedPaths` is truncated to 5
///   (`workspace_delta_probe.dart:160`, `:213-214`) — a prefix has no bound,
///   and the sixth path is exactly where a prohibited file hides.
/// * `WorkspaceDelta.committed` hard-codes `changedPaths = const []`
///   (`:61-67`) — on exactly the runs F1 passes, an obvious reader enumerates
///   nothing and passes vacuously (§6.4 N1).
/// * `GitWorkspaceInspector.changedFiles` is uncapped but start-to-worktree and
///   `git diff` never lists untracked files — a brand-new prohibited file would
///   be invisible.
///
/// This gate sees only what [ChangeScopeSource.collectPaths] returns, and that
/// interface admits no path set derived from either delta shape: the empty-list
/// trap is unreachable by construction rather than discouraged.
///
/// ## A failed enumeration is a FAIL, not an empty list
///
/// The collector throws instead of returning a short list
/// (`committed_diff_path_collector.dart:17-31`); this gate converts that
/// exception into a failure naming it. The vacuous shape — enumerate nothing,
/// read "nothing is out of bounds", pass — cannot be constructed.
///
/// ## Confinement, not correctness
///
/// It does not assert the change was *right* (design §3.1 F2's deliberate
/// non-goal — that is F4's job and engineering review's).
///
/// `config['evidenceTypes']` is not validated here: design §3.0 rule 2 makes it
/// the contract derivation's read-back (`product_qa_contract.dart:168-189`).
class ChangeScopeConfinementGate implements GateEvaluator {
  ChangeScopeConfinementGate({required this.source});

  final ChangeScopeSource source;

  @override
  String get gateType => 'change-scope-confinement';

  @override
  Future<QAGateResult> evaluate(
    String workItemId,
    AgentResult agentResult,
    QAGateDefinition gate,
  ) async {
    // Provision refusal first: a gate whose owned set is empty would fail
    // every path (stricter-but-useless) or pass every one (a no-op), and
    // neither may be evaluated at all, let alone reach a verdict (§9 gap 3).
    final config = _ChangeScopeConfig.from(gate);
    final evaluatedAt = DateTime.now();

    final failures = <String>[];

    final baseline = await source.readBaseline(workItemId);
    if (baseline == null) {
      failures.add(
        'the execution workspace and starting revision could not be '
        'established, so there is no range to confine; this is "I could not '
        'look", not "nothing changed"',
      );
    } else if (baseline.startingRevision.trim().isEmpty) {
      failures.add(
        'the execution baseline carries an empty starting revision, so there '
        'is no left edge for the <start>..<produced> range',
      );
    }

    final producedHead = await source.readProducedHead(workItemId);
    if (producedHead == null) {
      failures.add(
        'HEAD could not be established, so the <start>..<produced> range has '
        'no right edge; this is "I could not look", not "nothing changed"',
      );
    } else if (producedHead.headRevision.trim().isEmpty) {
      failures.add(
        'the re-read returned an empty produced revision; '
        'WorkspaceHead.headRevision is non-empty by contract',
      );
    }

    CommittedDiffPaths? collected;
    if (baseline != null &&
        baseline.startingRevision.trim().isNotEmpty &&
        producedHead != null &&
        producedHead.headRevision.trim().isNotEmpty) {
      try {
        collected = await source.collectPaths(
          workingDirectory: baseline.workingDirectory,
          startingRevision: baseline.startingRevision,
          producedRevision: producedHead.headRevision,
        );
      } on Exception catch (e) {
        // Design §3.1 F2: "a failed enumeration is a FAIL, not an empty list".
        // The exception is the collector's "could not look"; folding it into
        // an empty set would rebuild the vacuous-pass defect at a second layer.
        failures.add(
          'the committed diff paths could not be enumerated: $e; a failed '
          'enumeration is a failure, never an empty path set',
        );
      }
    }

    final unownedPaths = <String>[];
    final forbiddenHits = <String, String>{};

    final paths = collected?.paths ?? const <String>[];
    for (final path in paths) {
      final forbiddenBy = config.forbiddenPathGlobs.where(
        (glob) => _pathMatches(path, glob),
      );
      if (forbiddenBy.isNotEmpty) {
        forbiddenHits[path] = forbiddenBy.join(', ');
        failures.add(
          'path "$path" matches forbidden glob '
          '${forbiddenBy.map((g) => '"$g"').join(', ')}',
        );
        continue;
      }
      if (!config.ownedPathGlobs.any((glob) => _pathMatches(path, glob))) {
        unownedPaths.add(path);
        failures.add(
          'path "$path" matches no owned glob in '
          '${config.ownedPathGlobs.map((g) => '"$g"').join(', ')}',
        );
      }
    }

    final passed = failures.isEmpty;

    return QAGateResult(
      gateId: gate.gateId,
      workItemId: workItemId,
      status: passed ? QAGateStatus.passed : QAGateStatus.failed,
      evidence: [
        QAEvidence(
          evidenceId:
              '${gate.gateId}:committed_diff_paths:'
              '${evaluatedAt.microsecondsSinceEpoch}',
          gateId: gate.gateId,
          workItemId: workItemId,
          evidenceType: 'committed_diff_paths',
          // The label from the design's config, never a query
          // (design §3.0 rule 3): the reader's identity is the typed source.
          artifactRef: config.pathSource,
          content: <String, dynamic>{
            'startingRevision': baseline?.startingRevision,
            'producedRevision': producedHead?.headRevision,
            'pathCount': paths.length,
            // The full enumerated set — uncapped, so the evidence row itself
            // shows every path that was judged, not a prefix of them.
            'paths': paths,
            'ownedPathGlobs': config.ownedPathGlobs,
            'forbiddenPathGlobs': config.forbiddenPathGlobs,
            'unownedPaths': unownedPaths,
            'forbiddenPaths': forbiddenHits,
            'matched': failures.isEmpty,
            if (!passed) 'reason': failures.join('; '),
          },
          collectedAt: evaluatedAt,
        ),
      ],
      evaluatedAt: evaluatedAt,
      passedAt: passed ? evaluatedAt : null,
      metadata: <String, dynamic>{
        'startingRevision': baseline?.startingRevision,
        'producedRevision': producedHead?.headRevision,
        'pathCount': paths.length,
        'pathSource': config.pathSource,
        // WHERE the enumerated path set came from. `artifactRef` names the
        // READER (`git_diff_name_only`), and that name is the same for the
        // production collector and for a fail-closed stand-in — so without
        // this key a persisted result cannot say which one produced it
        // (F-204).
        qaSourceProvenanceMetadataKey: source.provenance.toJson(),
        if (!passed) 'reason': failures.join('; '),
      },
    );
  }
}

/// Translates one glob into an anchored [RegExp] over a repository-relative
/// path.
///
/// Supported syntax, deliberately small because the glob list comes from a
/// human-authored ownership map, not a query language:
///
/// * `**` — any sequence **including** `/`. `dir/**` matches everything under
///   `dir/`; `**/x` matches `x` at any depth (`**/` becomes `(?:.*/)?`, so
///   `a/**/b` matches both `a/b` and `a/x/b`).
/// * `*` — any sequence **excluding** `/`.
/// * `?` — exactly one character excluding `/`.
/// * everything else is literal (regex-escaped), so `apps/server` matches only
///   itself and `.` in a path is a dot.
///
/// Matching is case-sensitive (git paths are) and anchored at both ends: a
/// glob that matches a *prefix* of a path but not the path would confine
/// nothing.
RegExp _globToRegExp(String glob) {
  final source = StringBuffer('^');
  var i = 0;
  while (i < glob.length) {
    final char = glob[i];
    if (char == '*') {
      final isDouble = i + 1 < glob.length && glob[i + 1] == '*';
      if (isDouble && i + 2 < glob.length && glob[i + 2] == '/') {
        source.write('(?:.*/)?');
        i += 3;
      } else if (isDouble) {
        source.write('.*');
        i += 2;
      } else {
        source.write('[^/]*');
        i += 1;
      }
    } else if (char == '?') {
      source.write('[^/]');
      i += 1;
    } else {
      source.write(RegExp.escape(char));
      i += 1;
    }
  }
  source.write(r'$');
  return RegExp(source.toString());
}

String _normalizePath(String path) {
  var normalized = path.trim();
  while (normalized.startsWith('./')) {
    normalized = normalized.substring(2);
  }
  return normalized;
}

String _normalizeGlob(String glob) {
  var normalized = glob.trim();
  while (normalized.startsWith('./')) {
    normalized = normalized.substring(2);
  }
  // A trailing slash is only ever written to mean "everything under here", so
  // `apps/server/` and `apps/server/**` are the same claim.
  if (normalized.endsWith('/') && !normalized.endsWith('**/')) {
    normalized = '$normalized**';
  }
  return normalized;
}

bool _pathMatches(String path, String glob) =>
    _globToRegExp(_normalizeGlob(glob)).hasMatch(_normalizePath(path));

/// F2's declared half, validated up front — provision, before any read, so a
/// gate that cannot be judged is refused rather than evaluated.
///
/// The two glob lists fail differently **on purpose**:
///
/// * `ownedPathGlobs` may not be empty and may not be absent. An empty owned
///   set would fail every path — stricter, but useless — while a reader that
///   treated empty as "all owned" would make the gate a no-op. Neither is
///   acceptable, so both are refused (§9 requirement gap 3).
/// * `forbiddenPathGlobs` may be an **explicit empty list** (a lane may own
///   everything it touches with nothing specially banned) but may not be
///   **absent** — absent and empty mean different things to a reader that
///   cannot tell whether the key was consulted at all.
class _ChangeScopeConfig {
  const _ChangeScopeConfig({
    required this.ownedPathGlobs,
    required this.forbiddenPathGlobs,
    required this.pathSource,
  });

  static const String supportedPathSource = 'git_diff_name_only';

  final List<String> ownedPathGlobs;
  final List<String> forbiddenPathGlobs;
  final String pathSource;

  static _ChangeScopeConfig from(QAGateDefinition gate) {
    final owned = _stringList(gate, 'ownedPathGlobs', allowEmpty: false);
    final forbidden = _stringList(gate, 'forbiddenPathGlobs', allowEmpty: true);

    final pathSource = gate.config['pathSource'];
    if (pathSource != supportedPathSource) {
      throw FormatException(
        'gate ${gate.gateId} declares "pathSource" as $pathSource; the only '
        'supported value is "$supportedPathSource" — the label names the '
        'reader, and the reader is the typed CommittedDiffPathCollector',
      );
    }

    return _ChangeScopeConfig(
      ownedPathGlobs: owned,
      forbiddenPathGlobs: forbidden,
      pathSource: pathSource as String,
    );
  }

  static List<String> _stringList(
    QAGateDefinition gate,
    String key, {
    required bool allowEmpty,
  }) {
    if (!gate.config.containsKey(key)) {
      final rule = allowEmpty
          ? 'it may be an empty list, but it may not be absent'
          : 'an empty or absent list cannot confine anything';
      throw FormatException(
        'gate ${gate.gateId} does not declare "$key", which is required; '
        '$rule',
      );
    }
    final value = gate.config[key];
    if (value is! List) {
      throw FormatException(
        'gate ${gate.gateId} declares "$key" as ${value.runtimeType}; a JSON '
        'array of glob strings is the only shape that can be read as one',
      );
    }
    final entries = value
        .map((entry) {
          if (entry is! String || entry.trim().isEmpty) {
            throw FormatException(
              'gate ${gate.gateId} declares a non-string or empty entry in '
              '"$key" ($entry)',
            );
          }
          return entry;
        })
        .toList(growable: false);

    if (!allowEmpty && entries.isEmpty) {
      throw FormatException(
        'gate ${gate.gateId} declares an empty "ownedPathGlobs"; a gate whose '
        'owned set is empty would fail every path — stricter, but useless — '
        'and one that read empty as "all owned" would be a no-op; neither is '
        'acceptable (§9 requirement gap 3)',
      );
    }
    return List<String>.unmodifiable(entries);
  }
}
