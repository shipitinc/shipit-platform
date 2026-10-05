import 'package:platform_contracts/platform_contracts.dart';

/// Evidence-semantic maturity classification (PROPOSAL ONLY).
///
/// Authority comes from the SEMANTICS of the fact plus the CATEGORY of its
/// durable evidence — never from the mere presence of keywords (`planned`,
/// `future`, `deferred`, `implemented`) in arbitrary repository prose.
///
/// Conservative rules:
/// - IMPLEMENTED: the claim asserts CURRENT state and is backed by concrete
///   current-state evidence paths (source, config, manifest, test, migration,
///   running artifact) or a human-provided current assertion.
/// - POLICY: the claim asserts a governance rule/requirement/invariant and is
///   backed by authoritative governance evidence (AGENTS.md, accepted ADR,
///   approved checkpoint/decision docs) or a human-provided policy assertion.
/// - PLANNED: the claim asserts authoritative FUTURE direction AND the
///   evidence is an authoritative planning source (accepted ADR, approved
///   checkpoint, durable human architecture decision). A future keyword in
///   ordinary prose is NOT authority → UNKNOWN.
/// - DEFERRED: the claim asserts explicit postponement AND the evidence is an
///   authoritative decision that defers it; otherwise UNKNOWN.
/// - NOT_IMPLEMENTED: the claim explicitly asserts current absence.
/// - UNKNOWN: insufficient or conflicting evidence; never invented.
///
/// Facts are still proposed; the durability boundary re-checks that authority
/// references are real and applied consistently.
class MaturityClassifier {
  const MaturityClassifier();

  /// Classifies (proposes) the maturity of a fact from claim + evidence.
  BaselineMaturity classify({
    required String claim,
    required List<String> evidencePaths,
    required Provenance provenance,
    String? assumptionNote,
    bool redacted = false,
  }) {
    final normalized = claim.toLowerCase();

    final assertsCurrentState = _assertsCurrentState(normalized);
    final assertsAbsence = _assertsAbsence(normalized);
    final assertsPolicy = _assertsPolicy(
      claim,
      normalized,
      provenance,
      evidencePaths,
    );
    final assertsPlanned = _assertsPlanned(normalized);
    final assertsDeferred = _assertsDeferred(normalized);

    final authorityEvidence = evidencePaths.any(_isAuthorityEvidence);
    final planningAuthority = evidencePaths.any(_isPlanningAuthority);
    final currentEvidence = evidencePaths.any(_isCurrentStateEvidence);
    final structuralSourceEvidence = _hasStructuralSourceEvidence(evidencePaths);

    // Assumed provenance is never evidence — an assumption records an unknown.
    if (provenance == Provenance.assumed) return BaselineMaturity.unknown;

    // Conflicting semantics (both present and absent) → cannot determine.
    if (assertsCurrentState && assertsAbsence) {
      return BaselineMaturity.unknown;
    }

    // Absence must be explicitly claimed; NOT_IMPLEMENTED never implies planned.
    if (assertsAbsence && !assertsCurrentState) {
      if (currentEvidence || structuralSourceEvidence || provenance == Provenance.observed) {
        return BaselineMaturity.notImplemented;
      }
      if (authorityEvidence && assertsDeferred) {
        return BaselineMaturity.deferred;
      }
      return BaselineMaturity.unknown;
    }

    // Governance rule/requirement/invariant — policy only with authority.
    if (assertsPolicy) {
      if (authorityEvidence || provenance == Provenance.humanProvided) {
        return BaselineMaturity.policy;
      }
      // ADRs and governance docs in the repo ARE policy assertions.
      if (provenance == Provenance.observed) {
        return BaselineMaturity.policy;
      }
      return BaselineMaturity.unknown;
    }

    // Authoritative future direction — planning authority required.
    if (assertsPlanned) {
      if (planningAuthority || provenance == Provenance.humanProvided) {
        return BaselineMaturity.planned;
      }
      return BaselineMaturity.unknown;
    }

    // Explicit authoritative postponement.
    if (assertsDeferred) {
      if (authorityEvidence) {
        return BaselineMaturity.deferred;
      }
      return BaselineMaturity.unknown;
    }

    // Current-state existence backed by concrete current-state evidence.
    if (assertsCurrentState) {
      if (currentEvidence || structuralSourceEvidence || provenance == Provenance.humanProvided) {
        return BaselineMaturity.implemented;
      }
      // A claim about current state with no concrete evidence is unproven.
      return BaselineMaturity.unknown;
    }

    return BaselineMaturity.unknown;
  }

  // ---------------------------------------------------------------------
  // Claim semantics
  // ---------------------------------------------------------------------

bool _assertsCurrentState(String c) {
    const markers = <String>[
      ' is implemented',
      ' is present',
      'present in',
      ' is configured',
      ' configured in',
      ' is deployed',
      ' runs',
      ' is wired',
      ' exists at',
      ' is used by',
      ' detected in',
      ' found in',
      ' is exercised',
      ' backed by',
      ' is active',
      ' is enabled',
      ' provides ',
      ' has a ',
      ' has an ',
      ' has tests',
      ' has function',
      ' has methods',
      ' is defined',
      ' is declared',
      ' defines ',
      ' contains ',
      ' is served',
      ' is recorded',
      ' is persisted',
      ' is logged',
      // Structural/structural facts from scraped discovery:
      ' is composed of',
      ' declares ',
      ' declares its',
      ' is a ',
      ' is an ',
      ' uses ',
      ' uses a ',
      ' uses an ',
      ' depends on',
      'depends on ',
      'orchestrates ',
      'promoted via',
      'bound to',
      'bound by',
      'targets ',
      'targets a ',
      'seeded ',
      'seeded by',
      'targets kubernetes',
      'targets openTofu',
      'uses docker compose',
      'uses openCode',
      'uses postgres',
      'runs on ',
      'runs on linux',
      'runs on macos',
    ];
    final present = c
        .replaceAll(BaselineMaturity.notImplemented.wire, ' ')
        .replaceAll(RegExp(r'(?<![a-z])unimplemented\b'), ' ')
        .replaceAll(RegExp(r'\bnot[ _-]?implemented\b'), ' ');
    final currentImplemented = RegExp(
      r'(?<![a-z])implemented\b',
    ).hasMatch(present);
    return currentImplemented || markers.where(c.contains).isNotEmpty;
  }

  /// True when [c] asserts a negated/absent implementation. Kept in one place so
  /// the canonical vocabulary is not duplicated as scattered ad-hoc literals:
  /// the canonical wire value (`BaselineMaturity.notImplemented.wire` =
  /// `not_implemented`), the prose spelling (`not implemented`), and the
  /// separator/spelling variants (`not-implemented`, `notImplemented`,
  /// `unimplemented`).
  bool _assertsNegatedImplementation(String c) =>
      c.contains(BaselineMaturity.notImplemented.wire) ||
      RegExp(r'(?<![a-z])unimplemented\b').hasMatch(c) ||
      RegExp(r'\bnot[ _-]?implemented\b').hasMatch(c);

  bool _assertsAbsence(String c) {
    const markers = <String>[
      'not implemented',
      'is absent',
      'is not present',
      'does not exist',
      'not configured',
      'has no ',
      'no runway',
      'no config',
      'no configuration',
      'not deployed',
      'not yet',
      'is not used',
      'is missing',
      'no observability',
      'no ci',
      'no k8s',
      'no kubernetes',
      'no terraform',
      'no opentofu',
      'no .github',
      'no docker',
      'unavailable',
    ];
    // The canonical wire value for absence (`BaselineMaturity.notImplemented`
    // = `not_implemented`) plus the negated-implementation variants are
    // authoritative alongside the phrase markers.
    return markers.where(c.contains).isNotEmpty ||
        _assertsNegatedImplementation(c);
  }

  bool _assertsPolicy(
    String claim,
    String c,
    Provenance provenance,
    List<String> evidencePaths,
  ) {
    const markers = <String>[
      ' must ',
      ' shall ',
      ' required',
      ' requirement',
      ' policy',
      ' governance',
      ' invariant',
      ' boundary',
      ' prohibited',
      ' never ',
      ' authoritative',
      ' rule',
      ' mandates',
      ' requires ',
      'entitled policy',
    ];
    return markers.where(c.contains).isNotEmpty;
  }

  bool _assertsPlanned(String c) {
    const markers = <String>[
      'will be',
      'will adopt',
      'future work',
      'planned for',
      'approved for implementation',
      'approved direction',
      'selected for future',
      'to be implemented',
      'intended for',
      'next milestone',
      'upcoming',
      'roadmap',
      'will use',
      'will replace',
    ];
    return markers.where(c.contains).isNotEmpty;
  }

  bool _assertsDeferred(String c) {
    const markers = <String>[
      'deferred',
      'postponed',
      'explicitly out of scope',
      'parked',
      'shelved',
      'delayed',
      'not now',
      'later milestone',
      'intentionally excluded',
    ];
    return markers.where(c.contains).isNotEmpty;
  }

  // ---------------------------------------------------------------------
  // Evidence categories (by durable path)
  // ---------------------------------------------------------------------

  /// Authoritative governance evidence: instructions, ADRs, approved
  /// checkpoints/decisions.
  bool _isAuthorityEvidence(String path) {
    final p = path.toLowerCase();
    return _isGovernancePath(p) || _isDecisionPath(p);
  }

  bool _isPlanningAuthority(String path) {
    final p = path.toLowerCase();
    return p.startsWith('docs/adr/') ||
        p.startsWith('docs/checkpoints/') ||
        p.startsWith('docs/decisions/');
  }

  bool _isGovernancePath(String p) =>
      p.endsWith('agents.md') || p.endsWith('/agents.md');

  bool _isDecisionPath(String p) =>
      p.startsWith('docs/adr/') ||
      p.startsWith('docs/checkpoints/') ||
      p.startsWith('docs/decisions/') ||
      p.startsWith('docs/governance/');

  /// Concrete current-state evidence: a real artifact in the Product, not a
  /// forward-looking document or governance doc.
  bool _isCurrentStateEvidence(String path) {
    final p = path.toLowerCase();
    if (_isDecisionPath(p)) return false;
    if (p.endsWith('.md') && (p.contains('/docs/') || p.contains('/adr/'))) {
      // Markdown docs (ADRs, design docs) are governance/planning, not
      // current-state evidence of implementation.
      return false;
    }
    if (p.isEmpty || p == '.') return false;
    return true;
  }

  /// For scraped structural facts, the mere fact that the detector found
  /// them in the repo is current-state evidence. Only applies when the
  /// evidence paths include structural source files (pubspec.yaml, compose.yaml,
  /// Dockerfile, etc.) — not docs/ADRs.
  bool _hasStructuralSourceEvidence(List<String> evidencePaths) {
    final structuralExtensions = {
      'pubspec.yaml',
      'pubspec.yml',
      'compose.yaml',
      'compose.yml',
      'dockerfile',
      'dockerfile.',
      'docker-compose.yaml',
      'docker-compose.yml',
      'melos.yaml',
      'analysis_options.yaml',
      'justfile',
      'makefile',
    };
    for (final path in evidencePaths) {
      final p = path.toLowerCase();
      if (structuralExtensions.any((ext) => p.endsWith(ext) || p.contains('/$ext'))) {
        return true;
      }
      // Also match paths under packages/ that are pubspec.yaml
      if (p.contains('/packages/') && p.endsWith('pubspec.yaml')) {
        return true;
      }
    }
    return false;
  }
}
