/// The lane path-ownership declaration: what it is, where it travels, and the
/// one key both ends of the journey spell the same way.
///
/// ## WHAT THIS IS
///
/// A lane dispatched to produce a change is GRANTED a set of repository-relative
/// path globs — the paths it may touch. The grant is made before the work is
/// known, and it is captured at DISPATCH time into the durable execution
/// record, so a QA gate can judge the change against what the lane was
/// dispatched with rather than against what the change turned out to be.
///
/// The declaration is a grant, not a claim. A claim is what the work says it
/// will touch; a grant is what the platform handed the lane. Only the second
/// can confine a lane, because only the second was made by somebody other than
/// the lane.
///
/// ## WHY THE KEY IS SHARED, AND WHY IT LIVES HERE
///
/// The writer (the execution coordinator, which captures at dispatch) and the
/// reader (the QA gate's production source) sit in different packages. A key
/// written in one place and spelled differently in the other produces a record
/// that reads as EMPTY — and empty is the fail-closed direction, so the defect
/// would not announce itself as a defect: every lane's change would simply be
/// refused, with a reason that points at the declaration rather than at the
/// spelling. One constant, imported by both ends, is the whole remedy.
///
/// ## THE EMPTY DECLARATION IS NOT A WIDE-OPEN ONE
///
/// A lane that declares nothing owns nothing. That reads as an empty list, and
/// an empty owned set is refused by the gate that judges it — the same
/// direction the gate already refused before this declaration existed. Nothing
/// here widens a gate, and nothing here turns "declared nothing" into "owns
/// everything".
library;

/// The key under which a lane's declared owned paths are recorded.
///
/// Used in two durable records, deliberately under one name:
///
///  * the AGENT EXECUTION record — the dispatch-time capture, written by the
///    execution coordinator as the execution row is created;
///  * the WORK ITEM record — the grant itself, recorded before the work is
///    known and read at dispatch to be captured.
///
/// One key, one meaning: the path globs the dispatched lane was granted.
const String declaredOwnedPathsMetadataKey = 'declaredOwnedPaths';

/// The metadata fragment that records a lane's declaration.
///
/// The key is written even when the declaration is EMPTY, and that is the
/// point: "the lane was dispatched and declared nothing" and "no capture was
/// made at all" are different records, and both fail closed — but only one of
/// them is a statement about the lane.
///
/// [globs] is copied, so a later mutation of the caller's list cannot change
/// what the durable record says.
Map<String, dynamic> declaredOwnedPathsMetadata(List<String> globs) {
  return <String, dynamic>{
    declaredOwnedPathsMetadataKey: List<String>.unmodifiable(globs),
  };
}

/// Reads a lane's declared owned paths out of a durable metadata map.
///
/// Returns an EMPTY list when the record carries no declaration, and also when
/// it carries one that cannot be read as a list of glob strings. The second
/// case is deliberately not an error and deliberately not a partial read: a
/// malformed declaration must not be narrowed to the entries that happen to
/// parse (that would be a grant read as a smaller grant, which is the safe
/// direction only by accident), and it must not be widened either. It reads as
/// "declared nothing", which the gate refuses.
///
/// ## WHY IT IS NOT NAMED `readDeclaredOwnedPaths`
///
/// Every implementation of the QA gate's declaration seam has a METHOD called
/// `readDeclaredOwnedPaths` — that is the interface's own name. A top-level
/// function with the same name would be shadowed by that method inside every
/// implementation, so the call would resolve to the method and fail to
/// compile. The distinct name keeps the two apart.
List<String> declaredOwnedPathsFromMetadata(Map<String, dynamic>? metadata) {
  final raw = metadata?[declaredOwnedPathsMetadataKey];
  if (raw is! List) return const [];
  final globs = <String>[];
  for (final entry in raw) {
    if (entry is! String) return const [];
    final trimmed = entry.trim();
    if (trimmed.isEmpty) return const [];
    globs.add(trimmed);
  }
  return List<String>.unmodifiable(globs);
}
