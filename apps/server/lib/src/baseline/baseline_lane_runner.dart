import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart'
    show
        OnboardingAwaitingApproval,
        OnboardingFaulted,
        OnboardingLaneOutcome,
        OnboardingLaneRequest,
        OnboardingRefused;

import '../credentials/repository_snapshot_acquirer.dart';
import 'baseline_production_lane.dart';

/// Key naming the custody substrate the baseline lane acquires secrets through.
///
/// `unavailable` means the runtime does not exist in this deployment, not that a
/// human declined to run anything. See [baselineCredentialCustodyUnavailable].
const String baselineCredentialCustodyRuntimeKey =
    'baselineCredentialCustodyRuntime';

/// Value recorded under [baselineCredentialCustodyRuntimeKey].
const String baselineCredentialCustodyUnavailable = 'unavailable';

/// The honest terminal reason recorded when the lane cannot acquire a source
/// because no custody substrate is configured.
///
/// NOT the same code as [BaselineSourceUnavailableException.terminalCode], and
/// the difference is the point. That one means a product's repository has no
/// usable, host-confirmed credential — a fact about the product, and one an
/// operator fixes by onboarding that product. This one means *this process*
/// cannot reach a secret manager at all, so no product could be onboarded
/// however well configured it was. Collapsing them would let a deployment-wide
/// misconfiguration present as a per-product problem and send whoever is on
/// call to the wrong place.
const String externalBaselineCredentialCustodyDependency =
    'EXTERNAL_BASELINE_CREDENTIAL_CUSTODY_DEPENDENCY';

/// A job that names the remote's `HEAD` rather than a committed revision.
///
/// Recorded rather than thrown, and refused rather than run — see
/// `BaselineLaneRunnerAdapter.run`. The failure it prevents is a baseline
/// derived from a moving source, which is a baseline of nothing and, worse,
/// one that would pass as a derivation of a specific commit.
const String onboardingTargetNotPinnedCode = 'ONBOARDING_TARGET_NOT_PINNED';

/// Adapts [BaselineProductionLane] to the dispatcher's
/// `OnboardingLaneRunner` port, and maps every refusal the acquisition path can
/// raise onto a NAMED outcome.
/// ## Why the mapping is here and not inside the lane
///
/// `BaselineProductionLane.run` refuses on product state and on its own
/// derivations, but acquisition RAISES: the acquirer converts credential and
/// trust failures into a small set of exceptions, because a caller that caught
/// them by type would keep the distinction and a caller that caught `Object`
/// would launder an incident into a routine skip. This class is that caller,
/// and it catches them **by name**.
///
/// The exception that is deliberately NOT in the list is
/// [BaselineSnapshotCleanupException] — a scratch tree holding the deploy
/// key's identity file that this process could not remove. The acquirer's own
/// contract calls that an incident and never a result, so it becomes an
/// [OnboardingFaulted] (permanent, terminal, counted as a failure) rather than
/// an [OnboardingRefused]. The path it carries is recorded verbatim: the
/// acquirer states it holds no key material, and an operator cannot remove a
/// leaked tree they have not been told the path of.
class BaselineLaneRunnerAdapter {
  const BaselineLaneRunnerAdapter({
    required this.lane,
    this.log,
  });

  final BaselineProductionLane lane;
  final void Function(String event, Map<String, dynamic> data)? log;

  /// The dispatcher is handed [run], not this object: its port is a function
  /// type, and a class that could only satisfy it by wrapping itself in a
  /// closure would be an indirection with no meaning behind it.
  Future<OnboardingLaneOutcome> run(
    OnboardingLaneRequest request,
  ) async {
    // `HEAD` resolves rather than pins. The sweep uses it to learn what a
    // remote is at and then keys the job to the COMMIT it got — but if a `HEAD`
    // ever reached the lane it would derive a baseline from whatever the remote
    // said during a window of seconds, and the re-derivation would be impossible
    // because "later" is a different tree. `kRepositoryHeadRef` states that it
    // must never get here; a doc comment is not what stops it, so it is refused
    // at the one boundary the lane is reached through.
    if (request.pinnedRevision.trim() == kRepositoryHeadRef) {
      return _refuse(
        request,
        code: onboardingTargetNotPinnedCode,
        event: 'baseline.dispatch.target_not_pinned',
        reason:
            "this job names the remote's HEAD rather than a committed "
            'revision. A baseline derived from a moving ref cannot be '
            're-derived, because a later read of HEAD is a different tree. The '
            'sweep resolves HEAD to a commit before it enqueues, so a job still '
            'naming HEAD did not come from the sweep.',
        log: log,
      );
    }
    try {
      final outcome = await lane.run(
        productId: request.productId,
        repositoryId: request.repositoryId,
        pinnedRevision: request.pinnedRevision,
      );
      return switch (outcome) {
        BaselineLaneAwaitingApproval() => OnboardingAwaitingApproval(
          baselineId: outcome.baselineId,
          revision: outcome.revision,
          sourceRevision: outcome.sourceRevision,
          decisionId: outcome.decisionId,
          factCount: outcome.factCount,
          alreadyVerified: outcome.alreadyVerified,
        ),
        BaselineLaneSkipped() => OnboardingRefused(
          code: outcome.code,
          reason: outcome.reason,
        ),
      };
    } on BaselineSnapshotCleanupException catch (error) {
      log?.call('baseline.dispatch.snapshot_cleanup_failed', {
        'productId': request.productId,
        'repositoryId': request.repositoryId,
        'path': error.path,
        'severity': 'incident',
        'action':
            'a scratch tree this process could not remove still exists and may '
            'contain a deploy key identity file; remove it manually',
      });
      return OnboardingFaulted(
        code: 'SNAPSHOT_CLEANUP_FAILED',
        reason: error.toString(),
        // Never transient. Retrying would acquire a second tree and, if that one
        // also leaked, a second tree — turning an incident into a multiplier.
        transient: false,
      );
    } on HostKeyNotIndependentlyConfirmedException catch (error) {
      return _refuse(
        request,
        code: BaselineSourceUnavailableException.terminalCode,
        event: 'baseline.dispatch.host_key_not_confirmed',
        reason:
            '${error.reason} No key scan was trusted as a substitute and no '
            'credential fingerprint was passed as a host key fingerprint. This '
            'is an unmet external dependency, not a declined run and not a '
            'failure of the product.',
        log: log,
      );
    } on BaselineSourceUnavailableException catch (error) {
      return _refuse(
        request,
        code: BaselineSourceUnavailableException.terminalCode,
        event: 'baseline.dispatch.source_unavailable',
        reason:
            '${error.reason} The product stays where it is, no gate was '
            'opened, and nobody declined to run anything — there was no usable, '
            'host-confirmed credential to run with.',
        log: log,
      );
    } on PinnedRevisionNotAcquiredException catch (error) {
      return OnboardingFaulted(
        code: 'PINNED_REVISION_NOT_ACQUIRED',
        reason: error.toString(),
        // Transient on purpose, and it is the ONLY fault here that is: the
        // remote moved out from under a pin. A later attempt resolves the same
        // dedupe key against a revision that still exists, and `maxAttempts`
        // bounds it.
        transient: true,
      );
    } on BaselineSnapshotMaterializationException catch (error) {
      return OnboardingFaulted(
        code: 'SNAPSHOT_MATERIALIZATION_FAILED',
        reason: error.toString(),
        transient: true,
      );
    }
  }

  OnboardingRefused _refuse(
    OnboardingLaneRequest request, {
    required String code,
    required String event,
    required String reason,
    void Function(String event, Map<String, dynamic> data)? log,
  }) {
    log?.call(event, {
      'jobId': request.jobId,
      'productId': request.productId,
      'repositoryId': request.repositoryId,
      'code': code,
      'reason': reason,
      'operatorDeclined': false,
      'note':
          'no gate was opened and no baseline was written; the product is '
          'waiting on an external fact, not on a human decision to run it',
    });
    return OnboardingRefused(code: code, reason: reason);
  }
}

/// The runner a deployment uses when no custody substrate could be selected.
///
/// ## This is a refusal, not a stub that looks like work
///
/// Every onboarding job it is given terminates with
/// [externalBaselineCredentialCustodyDependency] and a reason naming what is
/// missing. It acquires nothing, derives nothing, writes no baseline, and opens
/// no gate — so there is nothing here that could be mistaken for a verification
/// that did not happen.
///
/// The alternative, and the reason this class exists rather than a `try`/
/// `catch` around construction with a null: a null lane would produce a
/// `TypeError` from inside the dispatch loop, which reads as a bug in the
/// dispatcher and tells an operator nothing about which piece of configuration
/// is absent. A named, greppable, durable refusal on every affected job says
/// exactly that.
class UnavailableBaselineLaneRunner {
  const UnavailableBaselineLaneRunner({
    required this.reason,
    this.log,
  });

  /// Why no lane could be constructed. Operator-facing; carries no secret.
  final String reason;

  final void Function(String event, Map<String, dynamic> data)? log;

  Future<OnboardingLaneOutcome> run(OnboardingLaneRequest request) async {
    log?.call('baseline.runtime.unavailable', {
      'runtimeKey': baselineCredentialCustodyRuntimeKey,
      'runtimeState': baselineCredentialCustodyUnavailable,
      'code': externalBaselineCredentialCustodyDependency,
      'jobId': request.jobId,
      'productId': request.productId,
      'operatorDeclined': false,
      'meaning':
          'unavailable means the runtime does not exist in this deployment, '
          'not that a human declined to run it',
      'reason': reason,
    });
    return OnboardingRefused(
      code: externalBaselineCredentialCustodyDependency,
      reason: reason,
    );
  }
}

/// The tick-hook handler for a durably-terminal onboarding job.
///
/// ## What this is NOT
///
/// Not the dispatch path. [BaselineProductDispatcher] is: onboarding jobs are
/// product-scoped, they are claimed and run by that dispatcher on its own pass,
/// and they therefore never appear in a `SchedulerTickResult` from the
/// WorkItem-scoped triage scheduler. There is no scenario in this composition
/// in which this function runs for an onboarding job that has not already been
/// dispatched and recorded.
///
/// ## Why it is registered anyway
///
/// `drainTriageOutcomesFromTick` raises [UnhandledJobTypeException] for a job
/// type no handler was registered for — deliberately, because a type nobody
/// handles is the absence of a decision rather than a decision to skip, and
/// that absence is how `onboardProduct` sat `queued` for ever. Registering the
/// type here is what makes the table complete, so that a future composition in
/// which one scheduler serves both types produces a durable log line rather
/// than a stack trace in a timer callback.
///
/// What it does is surface the terminal outcome on the operator log. The lane
/// has already recorded the baseline, the verification and the pending human
/// decision; nothing here re-derives, re-verifies, or resolves anything, and
/// there is no code path from this function to a resolved decision.
Future<void> observeCompletedOnboardingJob({
  required Job job,
  required void Function(String event, Map<String, dynamic> data) logger,
}) async {
  logger('baseline.tick.job_terminal', {
    'jobId': job.jobId,
    'workItemId': job.workItemId,
    'jobType': job.jobType.wire,
    'state': job.state.wire,
    'attempt': job.attempt,
    'maxAttempts': job.maxAttempts,
    'dedupeKey': job.dedupeKey,
    'completedAt': job.completedAt?.toIso8601String(),
    if (job.failure != null) 'failureCode': job.failure!.code.name,
    if (job.failure != null) 'failureKind': job.failure!.kind.name,
    if (job.failure != null) 'reason': job.failure!.reason,
    'note':
        'the baseline lane already recorded this outcome durably; this handler '
        'reports it and resolves nothing',
  });
}
