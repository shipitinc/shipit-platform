/// Effective contract for human-facing `WorkItem.description`.
///
/// Human decision `PL-6` (recorded 2026-09-15) requires that every NEW work
/// item that may be presented in a human-facing control-plane surface has a
/// description that is human-readable prose. Every persisted `WorkItem` is
/// eligible to appear in the control-plane UI (All work, Run detail, audit
/// endpoints), so the domain justifies enforcing at the authoritative
/// creation boundary (`DurableWorkflowEngine.createWorkItem`) rather than
/// only at a human gate.
///
/// Legacy records persisted before this contract may have a null or blank
/// `description`; they are preserved as-is (no migration) and the UI may
/// display `title` as a compatibility fallback. This validator only applies
/// to new creations at the application boundary.
library;

const int kMinHumanFacingDescriptionLength = 12;

/// Returns a human-readable violation when [description] is not meaningful
/// human-readable prose, or `null` when it is acceptable.
///
/// Operational interpretation of "meaningful prose": present, non-blank after
/// trimming, not a bare technical identifier (too short to be prose), and not
/// a duplicate of the technical [title]. The threshold is an objective proxy;
/// authoring guidance in the UI is the primary guard against hand-written
/// jargon.
String? humanFacingDescriptionViolation(String? description, {String? title}) {
  final text = description?.trim() ?? '';
  if (text.isEmpty) {
    return 'description must be present and non-blank '
        '(human-facing WorkItem contract, PL-6)';
  }
  if (text.length < kMinHumanFacingDescriptionLength) {
    return 'description must be meaningful human-readable prose, '
        'not a bare technical identifier (PL-6)';
  }
  if (title != null && text == title.trim()) {
    return 'description must present plain prose distinct from the '
        'technical title (PL-6)';
  }
  return null;
}
