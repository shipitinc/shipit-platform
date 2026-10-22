import 'source_provenance.dart';

/// Where a lane's declared owned paths are read from when a QA contract is
/// evaluated.
///
/// ## WHAT THIS IS FOR
///
/// The F2 gate compares a change's paths against the owned set the lane was
/// GRANTED. The gate's own config carries that set, and for a long time the
/// only copy of it was an empty list in the product manifest — because the
/// platform had nowhere to record what a lane was granted, so the gate
/// refused every evaluation by design.
///
/// This interface is the seam that supplies the missing input. It is a
/// SEPARATE seam from the gate's own [ChangeScopeSource] on purpose:
///
///  * [ChangeScopeSource] answers "which paths did the change touch?" — the
///    diff, read from the worktree;
///  * this interface answers "which paths was the lane allowed to touch?" —
///    the grant, read from the durable execution record the lane was
///    dispatched with.
///
/// They are different facts, read from different records, and a gate that
/// derived the second from the first would be judging a change against
/// itself.
///
/// ## WHY IT IS AN INTERFACE
///
/// `qa_orchestration` does not depend on `execution_coordinator`, where the
/// durable execution records live, and it does not depend on the persistence
/// layer that reads them. The production implementation lives in the server
/// package; this package states the question and nothing else.
///
/// ## THE EMPTY ANSWER IS A REFUSAL, NOT A WIDE-OPEN SET
///
/// An empty list means the lane declared nothing, and the gate that judges
/// the declaration refuses an empty owned set. A source that cannot find the
/// declaration must therefore answer with an empty list rather than with a
/// guess — the refusal is the honest verdict, and it is the direction the
/// gate already refused in.
abstract interface class DeclaredOwnedPathsSource
    implements QASourceProvenanceAware {
  /// The path globs the lane dispatched to produce [workItemId] was granted.
  ///
  /// Empty when the lane declared nothing, when the declaration cannot be
  /// read, or when no lane produced the item. Never a guess, and never a set
  /// wider than what was declared.
  Future<List<String>> readDeclaredOwnedPaths(String workItemId);
}

/// The config key under which a gate declares the path globs it owns.
///
/// ## WHY THE KEY IS NAMED HERE AND NOT IN THE EVALUATOR
///
/// The F2 evaluator reads this key from its own config parse
/// (`change_scope_confinement_gate.dart`), and this file names the same key
/// for the writer that supplies the value. The evaluator's file is not
/// touched: the gate's semantics, its config schema and its fail-closed
/// direction are exactly what the decision requires them to be, and this
/// lane's whole job is to supply an input, not to re-tune the gate that
/// consumes it.
///
/// The two spellings cannot drift apart silently, because a drift would make
/// the supplied input unreadable — and an unreadable input reads as "declared
/// nothing", which is the fail-closed direction, so the drift would show up as
/// a gate that refuses everything. The test that proves a DECLARED path
/// passes while an UNDECLARED one fails is what pins the spelling.
const String ownedPathGlobsConfigKey = 'ownedPathGlobs';
