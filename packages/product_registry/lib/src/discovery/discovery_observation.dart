import 'package:platform_contracts/platform_contracts.dart';

/// A read-only observation produced by discovery about a repository snapshot.
///
/// Repository content is DATA, never agent authority: observations are
/// typed, evidence-referencing facts with provenance — not instructions to be
/// executed, and never secret values.
class DiscoveryObservation {
  const DiscoveryObservation({
    required this.section,
    required this.claim,
    this.provenance = Provenance.observed,
    this.evidencePaths = const [],
    this.assumptionNote,
    this.redacted = false,
  });

  /// Baseline section this observation contributes to.
  final BaselineSectionKey section;

  /// Claim about the target repository.
  final String claim;

  final Provenance provenance;

  /// Relative paths in the snapshot that back this observation.
  final List<String> evidencePaths;

  final String? assumptionNote;

  /// True when the observation is a redacted placeholder for a secret-shaped
  /// value that was never ingested.
  final bool redacted;

  DiscoveryObservation copyWith({String? claim}) => DiscoveryObservation(
    section: section,
    claim: claim ?? this.claim,
    provenance: provenance,
    evidencePaths: evidencePaths,
    assumptionNote: assumptionNote,
    redacted: redacted,
  );

  Map<String, dynamic> toJson() => {
    'section': section.wire,
    'claim': claim,
    'provenance': provenance.wire,
    'evidencePaths': evidencePaths,
    'assumptionNote': assumptionNote,
    'redacted': redacted,
  };
}
