import 'dart:io' show Directory, Process;

import 'package:platform_contracts/platform_contracts.dart'
    show DurableWorkspaceDescriptor, OnboardingRecord, ProductState, WorkItem;
import 'package:scheduler/scheduler.dart'
    show SchedulerWorkload, WorkloadResolver;

import '../qa/qa_contract_dispatch_gate.dart' show workItemCarriesQaContract;

/// Reads a product's lifecycle state, or `null` when no such product exists.
///
/// A narrow port rather than a `ProductRegistryEngine`, for one reason: the
/// probe must be exercisable without a database and without a registry engine
/// with its human-decision store behind it, and a port that names exactly the
/// question it asks is also a port that cannot be widened by accident.
typedef ProductStateReader = Future<ProductState?> Function(String productId);

/// Reads a product's onboarding record, or `null` when it has none.
///
/// `ProductRegistryStore.readOnboardingForProduct` satisfies this directly —
/// it already existed at the base revision, which is what makes A2's dependency
/// on A1 a *data* dependency and not a compile-time one.
typedef OnboardingRecordReader =
    Future<OnboardingRecord?> Function(String productId);

/// Whether [path] currently exists as a directory.
typedef RepositoryExistsProbe = bool Function(String path);

/// What one `rev-parse` attempt produced.
///
/// A record rather than a bare `String?` because the failure case carries
/// something the success case does not: git's own message. "unknown revision",
/// "not a git repository" and "ambiguous argument" are three different problems
/// with three different fixes, and a deferral that collapses them into one
/// "could not resolve" sends the operator to the wrong place.
///
/// [output] is also where a process that could not be STARTED at all is
/// reported — `Process.runSync` throws instead of returning an exit code, and
/// the throw is caught and recorded here as the failure output. So this record
/// covers both "git ran and said no" and "git never ran".
typedef CommitProbeResult = ({String? commit, String? output});

/// Resolves [revision] inside the repository at [repositoryPath] to a commit id.
///
/// Returns a null `commit` — never `HEAD` — when the revision cannot be
/// resolved. The "never `HEAD`" half is the whole contract: `HEAD` is a
/// carve-out a sweep performs when it has to resolve an unpinned snapshot
/// (`repository_snapshot_acquirer.dart`), and it is never a pin a lane accepts.
/// A resolver that answered `HEAD` would make this probe green against a
/// repository that has moved on since the clone was made, which is precisely
/// the provenance the durable workspace exists to provide.
typedef CommitResolver =
    CommitProbeResult Function(String repositoryPath, String revision);

/// What one readiness probe decided.
sealed class ImplementationReadiness {
  const ImplementationReadiness();

  /// The operator-facing reason, safe to persist and log.
  ///
  /// Never key material: every value interpolated into it is a product id, a
  /// repository path or git's own error output.
  String get reason;
}

/// The product's durable clone exists, is on disk, and resolves at its pin.
///
/// This is the ONLY outcome that may dispatch, and the only one that may name a
/// repository.
final class ImplementationWorkspaceReady extends ImplementationReadiness {
  const ImplementationWorkspaceReady({
    required this.workspace,
    required this.descriptor,
  });

  /// The workload the scheduler would dispatch against.
  final SchedulerWorkload workspace;

  /// Where it came from, so a log line can name the pin rather than asserting
  /// that a workspace "looked right".
  final DurableWorkspaceDescriptor descriptor;

  @override
  String get reason =>
      'durable clone ${descriptor.workspaceId} is on disk at '
      '${descriptor.repositoryPath} and resolves at its recorded pin';
}

/// The lane must NOT run. Defer: do not dispatch, do not fail, do not raise a
/// human decision, and do not consume a retry.
///
/// ## Why deferral and not failure
///
/// The three conditions that produce this outcome — the product is not
/// `governed`, the durable workspace has not been created yet, or the recorded
/// workspace is stale — are all **transient with respect to the platform's own
/// progress**, and two of them are the normal state of a product on its first
/// day. Failing a job would burn its retry budget and turn "nothing to build
/// against yet" into "this build failed"; raising a decision would put an
/// operator in front of a question they cannot answer, because the answer is
/// "create the workspace", which is machine work. So the only correct outcome
/// is to try again later, loudly.
///
/// ## Why this type exists at all
///
/// `WorkloadResolver` answers `SchedulerWorkload?`, and `null` means exactly
/// one thing today: `blockedArtifactMissing` — "there is nothing to review",
/// which is a fail-closed signal the composition root turns into a blocking
/// human decision. Reusing `null` for "not ready yet" would make an
/// unimplemented lane indistinguishable from a broken one, and would invite the
/// review path's handler onto jobs that never entered review.
///
/// Which channel a deferral should travel on is an open design decision (`OD-4`),
/// and this lane does not answer it. What it does instead is make the
/// DISTINCTION observable and testable here, and leave the conversion to a
/// single named place — see `toWorkloadResolver`.
final class ImplementationWorkspaceDeferred extends ImplementationReadiness {
  const ImplementationWorkspaceDeferred({
    required this.reason,
    this.productId,
    this.gitOutput,
  });

  @override
  final String reason;

  /// The product the deferral is about, when one is known.
  final String? productId;

  /// git's own stderr/stdout for a failed `rev-parse`, when there was one.
  ///
  /// Recorded verbatim because "the workspace is stale" is not actionable on its
  /// own: the operator needs to see that the pin is unknown, that the object
  /// database is unreadable, or that the path is not a repository at all, and
  /// those are three different problems with three different fixes.
  final String? gitOutput;

  @override
  String toString() =>
      'deferred: $reason${gitOutput == null ? '' : ' (git: $gitOutput)'}';
}

/// The readiness probe the implementation scheduler dispatches behind.
///
/// ## What it is, and the ordering that matters
///
/// An implementation job runs `git` in a checkout and commits the result. The
/// question "which checkout?" therefore has exactly one honest answer — the
/// product's DURABLE clone, at the commit its onboarding record pinned — and
/// every other answer is a fabrication. In particular:
///
///  * the construction-time `SchedulerWorkload` names the TRIAGE repository, a
///    scratch checkout holding one `README.md`. Committing there produces a
///    plausible-looking execution whose artifact no reviewer can find;
///  * `HEAD` is not a pin. It moves under the lane, so "verified at HEAD" means
///    nothing about which code was reviewed.
///
/// So the probe resolves the durable clone, and when it cannot, it DEFERS. It
/// never substitutes either of the above.
///
/// ## The four gates, in order
///
/// Each gate is cheaper and more fundamental than the one after it, and each
/// has a different owner:
///
///  1. **the product is `governed`.** `ProductState.governed` is documented as
///     "work may be dispatched for this product"; every other value says the
///     product has no accepted baseline, is paused, or is archived. Deferring
///     here costs nothing — a paused product resumes.
///  2. **the item carries the QA contract its completion is judged by.** The
///     only edge out of a finished implementation, `agentExecuting ->
///     agentCompleted`, is guarded by `GuardConditions.qaContractExists()` and
///     the coordinator supplies `qaContractId` from the work item itself — so
///     an item without one is refused at the LAST transition, after the agent
///     work ran and the attempt was spent. This is F-242: a guaranteed-fail
///     gate charged to the retry budget. It is checked before the workspace
///     questions because a field already in hand answers it, and because
///     "this item can never complete" outranks "this product's clone
///     resolves" when both are true. Resumable: the provisioning lanes stamp
///     a contract at creation, and the repair tooling attaches a real one
///     from the product's declared spec to an item that has none.
///  3. **the record names the product's DURABLE clone, pinned and live.** Not
///     merely "a pin and a workspace": `OnboardingRecord.hasDurableProductClone`
///     also requires the DURABLE shape, because `workspace` is one column
///     holding two documents and the per-execution shape answers true to the
///     older, shape-blind predicate while naming a worker execution's worktree.
///     Reading the wrong shape yields a path that exists and is not the
///     product's.
///  4. **the clone is on disk and resolves at its recorded pin.** A record can
///     outlive its tree — a host bind that was never mounted, a directory
///     removed by hand, a pin the clone does not contain.
///
/// ## Why it reads the product's registry and nothing else
///
/// It never creates a clone, never pins one, never writes a record and never
/// moves a lifecycle state. Those belong to the lane that provisions durable
/// workspaces, and duplicating any of them here would mean two writers of one
/// product's provenance. This class is a READER, and the only thing it can
/// produce is a decision to dispatch or a decision not to.
class ImplementationReadinessProbe {
  ImplementationReadinessProbe({
    required this.readProductState,
    required this.readOnboarding,
    required this.runtimeTypeId,
    required this.timeoutSeconds,
    RepositoryExistsProbe? repositoryExists,
    CommitResolver? resolveCommit,
    this.durableRuntimeAvailable = true,
    this.durableRuntimeUnavailableReason,
    void Function(String event, Map<String, dynamic> data)? log,
  }) : _repositoryExists = repositoryExists ?? _directoryExists,
       _resolveCommit = resolveCommit ?? _gitRevParse,
       _log = log ?? _discardLog;

  /// Reads a product's lifecycle state. See [ProductStateReader].
  final ProductStateReader readProductState;

  /// Reads a product's onboarding record. See [OnboardingRecordReader].
  final OnboardingRecordReader readOnboarding;

  final RepositoryExistsProbe _repositoryExists;
  final CommitResolver _resolveCommit;
  final void Function(String event, Map<String, dynamic> data) _log;

  /// The `runtimeTypeId` every resolved workload carries — the id the agent
  /// adapter is registered under in the composition root.
  final String runtimeTypeId;

  /// Per-job budget for an implementation run. Not the triage default: an
  /// implementation run is not a five-minute classification, and this value
  /// also sets `Scheduler.zombieStalenessBound`, so getting it wrong is how an
  /// execution outlives its lease for hours.
  final int timeoutSeconds;

  /// Whether the durable-workspace runtime exists in this deployment.
  ///
  /// False means no product clone can ever be created, so every probe would
  /// defer forever for a reason no amount of retrying fixes. It is consulted
  /// FIRST so an operator reads the configuration fact instead of a per-item
  /// one.
  final bool durableRuntimeAvailable;

  /// Why, when [durableRuntimeAvailable] is false. Passed in rather than read
  /// from the runtime here so this class neither constructs nor depends on it.
  final String? durableRuntimeUnavailableReason;

  /// Decides whether [item]'s product may be implemented right now.
  ///
  /// Total: every path returns either [ImplementationWorkspaceReady] or
  /// [ImplementationWorkspaceDeferred]. It never throws — a probe that throws
  /// would abort the scheduler's tick for one bad item, and a throw is not a
  /// way of saying "not yet".
  ///
  /// ## What makes it total, and why it is stated as more than a promise
  ///
  /// There are **five** injected function ports — the constructor takes exactly
  /// [readProductState], [readOnboarding], [_repositoryExists], [_resolveCommit]
  /// and [_log] — and each one is separately able to fail, so totality here is
  /// five guards rather than one claim:
  ///
  /// | # | Injected port | How it fails | What the deferral says |
  /// |---|---|---|---|
  /// | 1 | [readProductState] | throws (store down) | `product_state_unreadable` |
  /// | 2 | [readOnboarding] | throws (store down) | `onboarding_unreadable` |
  /// | 3 | [_repositoryExists] — `Directory.existsSync()` **throws** `FileSystemException` when a path component denies traversal; it does not answer `false` | throws | `workspace_unreadable`, deliberately distinct from `workspace_missing` |
  /// | 4 | [_resolveCommit] — `Process.runSync` **throws** `ProcessException` when the process cannot start | throws | `pin_unresolvable`, carrying the exception verbatim |
  /// | 5 | [_log] — the composition root's is `stdout.writeln`, which raises on a closed pipe | throws | swallowed; the deferral is still returned, unlogged |
  ///
  /// Three further reads are guarded but are **not ports**, and are not counted in the
  /// five: `workItemCarriesQaContract(item)` (a field predicate on the item the
  /// caller already handed in, answering `false` → `qa_contract_missing`),
  /// `record.hasDurableProductClone` (a value, answering `false` → `no_durable_workspace`)
  /// and `record.workspace!.requireDurable()` (a *method on a record that port 2
  /// already returned*, which throws on a record of the wrong shape →
  /// `workspace_shape_unknown`). They are listed here because the earlier version of
  /// this table counted one of them as a port, which is what made the total wrong.
  ///
  /// Two rows above are not obvious, and they are the reason this method carries the
  /// list rather than a single sentence.
  ///
  /// The first is that **ports 3 and 4 throw rather than returning a value that
  /// encodes failure**. A shell-out that fails to *start* does not return a
  /// non-zero exit code, it throws; and neither does `existsSync` on a
  /// permission fault. A reader who expects ports to report failure in their
  /// return type will not see either.
  ///
  /// The second is that **the old count was wrong, and being wrong was the
  /// defect**. An earlier revision of this table said "four ports and four
  /// guards" while counting `requireDurable()` — a method on a returned record,
  /// not a port — and omitting [_repositoryExists], which had no guard at all.
  /// The claim read as verified and was not: it gave a reader a reason to stop
  /// counting at four. An enumeration that is *specific and wrong* is worse than
  /// a promise that is *vague*, because the specificity is what invites trust.
  ///
  /// Totality is asserted by `implementation_readiness_probe_test.dart`, which
  /// raises each port's own failure — one test per row, so no port can be quietly
  /// dropped from this table without a test failing to match it. Rows 3 and 4 are
  /// additionally asserted end to end through a real `Scheduler` tick carrying a
  /// second healthy job, because (a) the probe returning a deferral is a property
  /// of one method and (b) the healthy job still dispatching is the property of
  /// the chain that the contract is actually about. A contract with no test is a
  /// comment.
  Future<ImplementationReadiness> probe(WorkItem item) async {
    if (!durableRuntimeAvailable) {
      return _deferred(
        item,
        durableRuntimeUnavailableReason ??
            'the durable-workspace runtime is not configured in this '
                'deployment, so no product clone can be created and no '
                'implementation can run',
        event: 'implementation.deferred.runtime_unavailable',
      );
    }

    final productId = item.productId;
    final ProductState? state;
    try {
      state = await readProductState(productId);
    } on Object catch (error) {
      return _deferred(
        item,
        'the product\'s lifecycle state could not be read ($error), so whether '
        'work may be dispatched for it is unknown. Nothing ran',
        event: 'implementation.deferred.product_state_unreadable',
      );
    }
    if (state == null) {
      return _deferred(
        item,
        'product $productId does not exist, so there is no product whose code '
        'an implementation run could operate on',
        event: 'implementation.deferred.product_missing',
      );
    }
    if (state != ProductState.governed) {
      return _deferred(
        item,
        'product $productId is ${state.wire}; work may be dispatched only for '
        'a governed product. Not a failure — a product that is paused, '
        'archived or still awaiting baseline approval is expected to be '
        'here, and the item will run when it becomes governed',
        event: 'implementation.deferred.product_not_governed',
        details: {'productState': state.wire},
      );
    }

    // GATE 2 — the item must carry the QA contract its completion is judged
    // by.
    //
    // `agentExecuting -> agentCompleted` is the ONLY edge out of a finished
    // implementation and it carries `GuardConditions.qaContractExists()`,
    // which the coordinator answers from the work item's own `qaContractId`.
    // An item without one therefore cannot be refused at dispatch: it is
    // refused at the FINAL transition, after the agent work ran and the
    // attempt was spent — and every retry buys the identical outcome, which
    // is the F-242 burn this gate exists to end.
    //
    // Deferral, not failure, for the same reason the workspace gates defer:
    // the condition is transient with respect to the platform's own progress.
    // A contract minted onto the item — by a provisioning lane at creation,
    // or by the repair tooling attaching one from the product's declared
    // spec — lifts this on the next tick. An item whose product declares no
    // QA spec has nothing to mint and defers indefinitely, which is the
    // intended outcome: completing such an item is impossible, and every run
    // spent re-discovering that at the last transition is a run burned on a
    // gate that could never pass.
    //
    // It is asked BEFORE the onboarding read on cost alone — a field on the
    // item already in hand needs no store round-trip — and on precedence:
    // "this item cannot complete" is the fact an operator needs when it is
    // true, ahead of every workspace question below it.
    if (!workItemCarriesQaContract(item)) {
      return _deferred(
        item,
        'work item ${item.workItemId} carries no QA contract id, so the '
        'agentExecuting -> agentCompleted guard can never pass for it: '
        'dispatching now would spend a full implementation run and its '
        'attempt on a transition that refuses by construction. Not a '
        'failure — a real contract minted onto the item lifts this on the '
        'next tick',
        event: 'implementation.deferred.qa_contract_missing',
      );
    }

    final OnboardingRecord? record;
    try {
      record = await readOnboarding(productId);
    } on Object catch (error) {
      return _deferred(
        item,
        'the onboarding record for $productId could not be read ($error), so '
        'whether a durable workspace exists is unknown',
        event: 'implementation.deferred.onboarding_unreadable',
      );
    }
    if (record == null) {
      return _deferred(
        item,
        'product $productId has no onboarding record, so no durable workspace '
        'has been recorded for it yet',
        event: 'implementation.deferred.no_onboarding_record',
      );
    }
    // Shape-aware, deliberately. `hasDurableWorkspace` is deprecated FOR THIS
    // REASON: it is satisfied by a per-execution `WorkspaceDescriptor` too, and
    // a probe that gated on it would read a worker execution's worktree as the
    // product's clone and dispatch there.
    if (!record.hasDurableProductClone) {
      return _deferred(
        item,
        'the onboarding record for $productId names no live durable product '
        'clone at a pinned commit, so there is nothing to build in yet',
        event: 'implementation.deferred.no_durable_workspace',
        details: {
          'hasPinnedRevision': record.pinnedRevision != null,
          'workspaceKind': record.workspace?.kind,
          'workspaceIsCleaned': record.workspace?.isCleaned,
        },
      );
    }

    // `requireDurable()` throws on a record of the wrong shape, which
    // `hasDurableProductClone` has already excluded — so this cannot fail here.
    // It is called anyway, because it is the ONLY read that is guaranteed to
    // hand back the product's clone rather than whichever document the column
    // happened to hold.
    final DurableWorkspaceDescriptor descriptor;
    try {
      descriptor = record.workspace!.requireDurable();
    } on Object catch (error) {
      return _deferred(
        item,
        'the onboarding record for $productId claims a durable workspace that '
        'is not one ($error). A record of the wrong shape is refused, never '
        'used as a fallback: guessing which document was meant is how a '
        'worker execution\'s worktree becomes a product\'s provenance',
        event: 'implementation.deferred.workspace_shape_unknown',
      );
    }

    final repositoryPath = descriptor.repositoryPath;
    final bool repositoryOnDisk;
    try {
      repositoryOnDisk = _repositoryExists(repositoryPath);
    } on Object catch (error) {
      // `_directoryExists` is `Directory(path).existsSync()`, and that THROWS
      // `FileSystemException` (`OS Error: Permission denied, errno = 13`) when a
      // component of the path denies traversal — it does not answer `false`. A
      // host bind mounted with the wrong ownership, a directory removed out from
      // under an open handle, a path through a vanished network mount: all
      // ordinary, and all invisible to an `exitCode`-shaped mental model.
      //
      // So "cannot be read" is its own deferral and not a flavour of
      // `workspace_missing`. They send an operator to different places:
      // re-creating a clone that merely cannot be read discards the only copy
      // of the product's provenance over a mount fault.
      return _deferred(
        item,
        'the recorded durable clone for $productId could not be examined at '
        'all, because $repositoryPath could not be read ($error). That is not '
        'the same as the clone being gone: it may be present and intact behind '
        'a permission or mount fault, so nothing has been established either '
        'way and nothing is dispatched. Not re-creating it either — recreating '
        'a clone whose provenance cannot be read would discard it',
        event: 'implementation.deferred.workspace_unreadable',
        details: {
          'repositoryPath': repositoryPath,
          'pinnedRevision': record.pinnedRevision,
        },
      );
    }
    if (!repositoryOnDisk) {
      return _deferred(
        item,
        'the recorded durable clone for $productId is not on disk at '
        '$repositoryPath, so the record is stale. Not substituting any '
        'other repository, and not resolving HEAD in its place',
        event: 'implementation.deferred.workspace_missing',
        details: {
          'repositoryPath': repositoryPath,
          'pinnedRevision': record.pinnedRevision,
        },
      );
    }

    final pin = record.pinnedRevision!;
    // `late final`, and not `final`, because the two assignments below are in a
    // `try` and its `catch`: the analyser cannot prove the try never completed
    // normally on the path that reaches the catch. Exactly one runs.
    late final CommitProbeResult resolution;
    String? resolverFault;
    try {
      resolution = _resolveCommit(repositoryPath, pin);
    } on Object catch (error) {
      // The default port shells out — `Process.runSync` THROWS
      // `ProcessException` when the process cannot start at all (git absent,
      // PATH broken, fork denied), and it throws rather than returning a
      // non-zero exit code. Nothing between here and the scheduler catches it:
      // `toWorkloadResolver` awaits `probe` bare and `_dispatchOne` awaits the
      // resolver bare, so an uncaught one leaves `tick()` and takes the whole
      // dispatch pass with it — every OTHER job in the tick, not this one. A
      // throw is not a way of saying "not yet", and "not yet" is the truth:
      // the clone may be perfectly fine and the machine may simply have no git.
      //
      // So the fault is reported AS a failed resolution, which lands on the
      // pin-unresolvable deferral below — deferred, visible, no retry burned.
      resolverFault = '$error';
      resolution = (commit: null, output: '$error');
    }
    if (resolution.commit == null) {
      return _deferred(
        item,
        resolverFault == null
            ? 'the durable clone at $repositoryPath does not resolve commit '
                  '$pin, so the pin this implementation would start from cannot '
                  'be verified. Not substituting HEAD: a moving reference is '
                  'not a pin, and a lane that accepts one cannot say which code '
                  'was reviewed'
            : 'the pin $pin of the durable clone at $repositoryPath could not '
                  'be checked at all, because git could not be run against it '
                  '($resolverFault). The pin may well be present; nothing has '
                  'been established either way, so nothing is dispatched. Not '
                  'substituting HEAD: a moving reference is not a pin',
        event: 'implementation.deferred.pin_unresolvable',
        details: {'repositoryPath': repositoryPath, 'pinnedRevision': pin},
        gitOutput: resolution.output,
      );
    }

    return ImplementationWorkspaceReady(
      workspace: SchedulerWorkload(
        repositoryPath: repositoryPath,
        startingRevision: pin,
        timeoutSeconds: timeoutSeconds,
        runtimeTypeId: runtimeTypeId,
      ),
      descriptor: descriptor,
    );
  }

  /// A deferral, logged on the way out.
  ///
  /// Every deferral is logged at the same severity and with the same shape,
  /// because "the implementation lane is silently never dispatching" is the
  /// failure mode this whole mechanism has to avoid being mistaken for: a
  /// scheduler that does nothing looks exactly like a healthy one.
  ///
  /// ## Why the logging itself is guarded
  ///
  /// `log` is the fifth injected port and it is called from inside `catch`
  /// blocks, so a throw from it is the worst kind: it escapes the very handler
  /// that was recording why the work was refused. The default cannot throw, but
  /// an injected one can, and the composition root's `_log` is
  /// `stdout.writeln` — which raises on a closed or broken pipe, ordinary for a
  /// service whose parent went away.
  ///
  /// A deferral is already the safe outcome, and it is returned to the caller
  /// whether or not it could be written down. Losing the log line is a real
  /// loss, but converting a deferral into a throw that leaves `tick()` is a
  /// strictly larger one: it costs every OTHER job in the pass.
  ImplementationWorkspaceDeferred _deferred(
    WorkItem item,
    String reason, {
    required String event,
    Map<String, dynamic> details = const {},
    String? gitOutput,
  }) {
    final deferred = ImplementationWorkspaceDeferred(
      reason: reason,
      productId: item.productId,
      gitOutput: gitOutput,
    );
    try {
      _log(event, {
        'workItemId': item.workItemId,
        'productId': item.productId,
        'state': item.state.wire,
        'reason': reason,
        if (gitOutput != null) 'git': gitOutput,
        ...details,
        'action':
            'deferred. Not dispatched, not failed, no human decision raised and '
            'no retry consumed: the next tick asks again',
      });
    } on Object {
      // Swallowed deliberately, and only the fault is swallowed: the deferral
      // below is still returned. There is nowhere better to send this. The
      // alternative — rethrowing — is the exact escape path this class exists
      // to close.
    }
    return deferred;
  }
}

/// Adapts a [ImplementationReadinessProbe] to the scheduler's [WorkloadResolver]
/// contract.
///
/// ## The `null` mapping, stated plainly because it is an open seam
///
/// `WorkloadResolver` returns `SchedulerWorkload?`, and `null` is the scheduler's
/// `blockedArtifactMissing` channel. This function therefore returns `null` for
/// a deferral — which **does** stop dispatch (the scheduler builds no request,
/// claims nothing, and leaves the job `queued` with its attempt count
/// untouched), but lands the report on a channel whose name belongs to a
/// different failure.
///
/// The shape of that channel is `OD-4`, and it is unanswered, so this lane does
/// not choose one. What is decided here is narrower and is decided because it
/// is not a product question: **a deferral must not become a human decision.**
/// The composition root installs no `blockedArtifactMissing` handler for the
/// implementation scheduler — `engineeringReviewMissingArtifact` is a review
/// action that performs `agentCompleted -> reviewInProgress`, and applying it to
/// an implementation job would move an item through a gate it never entered and
/// raise a decision about "no artifact was produced" for an item that never
/// started. The tick reports these ids and logs them; nothing acts on them.
///
/// When `OD-4` is answered this one function is what changes. The
/// classification above it — the three gates, their order, and their reasons —
/// is independent of that answer and does not move with it.
WorkloadResolver toWorkloadResolver(
  ImplementationReadinessProbe probe, {
  void Function(String event, Map<String, dynamic> data)? log,
}) {
  final emit = log ?? _discardLog;
  return (job, item) async {
    final readiness = await probe.probe(item);
    switch (readiness) {
      case ImplementationWorkspaceReady(:final workspace):
        emit('implementation.readiness.resolved', {
          'workItemId': item.workItemId,
          'jobId': job.jobId,
          'repositoryPath': workspace.repositoryPath,
          'startingRevision': workspace.startingRevision,
        });
        return workspace;
      case ImplementationWorkspaceDeferred():
        return null;
    }
  };
}

/// The no-op log. A named function rather than a closure literal, because a
/// closure with two wildcards cannot be parsed in an initializer list here and
/// a named one is also greppable by whoever looks for where deferrals go.
void _discardLog(String event, Map<String, dynamic> data) {}

bool _directoryExists(String path) => Directory(path).existsSync();

/// `git rev-parse --verify <revision>^{commit}` in [repositoryPath].
///
/// Returns the resolved commit id on success and git's own output on failure.
/// The revision is passed through verbatim after `^{commit}`, which is what
/// makes the `^{commit}` suffix meaningful: git dereferences a tag to the
/// commit it points at and refuses a tree or a blob, so a pin that is not a
/// commit is refused rather than used.
///
/// ## It can THROW, and that is a fact about `Process`, not about this function
///
/// `Process.runSync` throws `ProcessException` when the process cannot be
/// started at all — git not installed, `PATH` broken, fork denied. It does NOT
/// come back with a non-zero exit code in that case, so there is no `exitCode`
/// here to inspect. Every caller must therefore treat this port as throwing;
/// `ImplementationReadinessProbe.probe` is the one that does, and it converts
/// the throw into the same `(commit: null, output: …)` record a refused
/// revision produces. Do not move this call out of that `try`.
CommitProbeResult _gitRevParse(String repositoryPath, String revision) {
  final result = Process.runSync('git', [
    '-C',
    repositoryPath,
    'rev-parse',
    '--verify',
    '$revision^{commit}',
  ]);
  final output = [
    result.stderr.toString().trim(),
    result.stdout.toString().trim(),
  ].where((s) => s.isNotEmpty).join(' ');

  if (result.exitCode != 0) {
    return (commit: null, output: output.isEmpty ? null : output);
  }
  final resolved = result.stdout.toString().trim();
  if (resolved.isEmpty) {
    return (commit: null, output: 'git rev-parse produced no output');
  }
  return (commit: resolved, output: null);
}
