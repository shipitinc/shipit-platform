import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart' show JobDefinition;

/// Scheduling definition for producing a Product's first baseline.
///
/// ## Why this file exists at all
///
/// `JobType.onboardProduct` was declared before anything could run it. The
/// control plane has always been able to enqueue that job
/// (`ControlPlaneService.triggerOnboarding`), and the enum member carries
/// exactly these semantics — "clone repository at pinned revision, run baseline
/// build + test" — but there was **no `JobDefinition` for it anywhere in this
/// package** and no consumer of the resulting job. Every onboarding job
/// therefore sat `queued` for ever: enqueued, recorded, displayed by
/// `getOnboardingStatus`, and never run. That is the silent no-op class, and it
/// was live before this definition existed.
///
/// So this is a gap being *closed*, not a type being added. Nothing here
/// introduces an enum member, and no wire value changes: `onboardProduct`'s
/// wire value is whatever it already was in persisted `job.jobType` rows.
///
/// ## No `WorkerExecutionRequest` builder, and why that is deliberate
///
/// `triage_defect.dart` pairs its definition with a request builder because a
/// triage job runs an **agent**. Baseline production is not an agent
/// execution — it is a deterministic platform operation (acquire a pinned
/// snapshot, derive facts, hash them, hand a human a decision). Building a
/// `WorkerExecutionRequest` for it would describe a bounded LLM run that this
/// work does not do, and `OnboardingWorker` — the one class whose doc says
/// "onboarding is a deterministic platform operation (git + build + test), not
/// an LLM-driven coding task" — has no registered instance in the server.
/// Supplying a request builder here would advertise a dispatch path that has no
/// worker behind it.
///
/// What the job therefore carries is an *instruction*, and the instruction is
/// what makes the job legible to whatever consumes it. The consumer is the
/// baseline lane, dispatched per `JobType` from the tick hook.
const JobDefinition onboardProductDefinition = JobDefinition(
  jobType: JobType.onboardProduct,
  requiredRole: AgentRole.implementer,
  requiredCapabilities: {WorkerCapability.linux, WorkerCapability.git},
  entryStates: {WorkItemState.designNotRequired},
  priority: JobPriority.high,
  maxAttempts: 2,
);

/// The synthetic work-item id an onboarding job is filed under.
///
/// Onboarding is product-scoped, not work-item-scoped, so the job needs an id
/// that cannot collide with a real `WorkItem`. This is the same shape the
/// control plane has always written, and `getOnboardingStatus` finds onboarding
/// jobs by it — changing it would orphan every historical onboarding job.
String onboardingWorkItemId(String productId) => 'onboarding-$productId';

/// The single dedupe key shared by BOTH onboarding triggers.
///
/// The operator-requested path (`triggerOnboarding`) and the periodic sweep
/// must not be able to produce two jobs for the same product at the same pinned
/// revision, and the only thing that guarantees that is this one function being
/// the only place the key is built.
///
/// The key is scoped by `startingRevision` as well as product and repository on
/// purpose. A sweep that pinned "whatever HEAD is now" would mint a new key
/// every time the upstream repository moved, and the "no duplicate jobs"
/// guarantee would quietly become "no duplicate jobs until the remote advances".
/// Pinning is what makes the key mean *one specific derivation from one
/// specific source state*.
///
/// ## One builder, now actually shared
///
/// `ControlPlaneService.triggerOnboarding` calls this function rather than
/// spelling the string, and the sweep reaches it through this package's
/// `scheduler.dart` barrel. There is therefore no second spelling left to
/// drift: a change to the format here is a change to both callers, and
/// `onboarding_dedupe_key_contract_test.dart` still pins the exact literal so a
/// change to the FORMAT fails loudly rather than orphaning every
/// already-persisted job whose `dedupeKey` was written in the old one.
String onboardingDedupeKey({
  required String productId,
  required String repositoryId,
  required String startingRevision,
}) {
  if (productId.trim().isEmpty) {
    throw ArgumentError.value(
      productId,
      'productId',
      'an onboarding dedupe key must name the product it is for',
    );
  }
  if (repositoryId.trim().isEmpty) {
    throw ArgumentError.value(
      repositoryId,
      'repositoryId',
      'an onboarding dedupe key must name the repository it pins',
    );
  }
  if (startingRevision.trim().isEmpty) {
    throw ArgumentError.value(
      startingRevision,
      'startingRevision',
      'an onboarding dedupe key must name the pinned revision; an empty '
          'revision would silently mean "whatever HEAD is now"',
    );
  }
  return '$_onboardingDedupeKeyPrefix$productId:$repositoryId:$startingRevision';
}

/// What an onboarding dedupe key names, recovered from the key itself.
///
/// The three components are carried together because they are only ever
/// meaningful together: a product, the one repository of it the derivation
/// reads, and the exact committed revision it is pinned at. [pinnedRevision] is
/// named explicitly rather than `revision` because "the revision this
/// derivation is pinned to" and "the revision the baseline's facts came from"
/// are the same string here only by construction, and a reader should have to
/// decide that rather than infer it.
class OnboardingTarget {
  const OnboardingTarget({
    required this.productId,
    required this.repositoryId,
    required this.pinnedRevision,
  });

  final String productId;
  final String repositoryId;
  final String pinnedRevision;

  /// The synthetic work-item id this target's jobs are filed under.
  String get workItemId => onboardingWorkItemId(productId);

  @override
  String toString() =>
      'OnboardingTarget($productId, $repositoryId@$pinnedRevision)';
}

/// Recovers the [OnboardingTarget] an onboarding dedupe key names, or `null`.
///
/// ## Why decoding is necessary rather than convenient
///
/// An onboarding job is product-scoped: its `workItemId` is the synthetic
/// `onboarding-<productId>` and nothing else about the durable record names a
/// repository or a revision. The dedupe key is the ONLY place either is
/// recorded, so a dispatcher that has to run the lane has to read them from
/// there. An alternative — carrying them in the job instruction — would make the
/// record's meaning depend on parsing English prose written for an operator,
/// which is how the two triggers' single-sourced key would stop mattering.
///
/// ## Why a key that does not decode is refused rather than repaired
///
/// A key with the wrong prefix, the wrong arity, or an empty component cannot
/// be split into a target without guessing which field the extra colon belongs
/// to. Guessing would clone the wrong repository, or the wrong revision of the
/// right one, and produce a baseline whose facts do not correspond to the job
/// that claims to have produced them — a divergence that is *supposed* to be
/// caught downstream by re-derivation, and would instead be manufactured here.
///
/// So this returns `null` and the caller records the job as a terminal
/// undecodable target. That is a loud, durable refusal rather than a
/// plausible-looking wrong answer, and it is the same shape as every other
/// refusal in this lane: say what could not be done and why.
OnboardingTarget? tryDecodeOnboardingDedupeKey(String key) {
  if (!key.startsWith(_onboardingDedupeKeyPrefix)) return null;
  final parts = key.substring(_onboardingDedupeKeyPrefix.length).split(':');
  if (parts.length != 3) return null;
  final productId = parts[0];
  final repositoryId = parts[1];
  final pinnedRevision = parts[2];
  if (productId.trim().isEmpty ||
      repositoryId.trim().isEmpty ||
      pinnedRevision.trim().isEmpty) {
    return null;
  }
  return OnboardingTarget(
    productId: productId,
    repositoryId: repositoryId,
    pinnedRevision: pinnedRevision,
  );
}

const String _onboardingDedupeKeyPrefix = 'onboarding:';

/// Builds the instruction an onboarding job carries.
///
/// Deliberately free of any product name, repository host, or credential
/// detail. Every value comes from the job's own arguments, so a second product
/// onboarded through the same code path needs no change here and no
/// product-specific configuration anywhere.
///
/// It states the boundary the work stops at, because a job instruction is the
/// only thing a reader of the job record has: this produces a baseline and
/// asks a human to approve it. It does not resolve the approval, and no
/// automation may.
String onboardingInstruction({
  required String productId,
  required String repositoryId,
  required String startingRevision,
}) =>
    'Onboard product $productId: clone repository $repositoryId at revision '
    '$startingRevision, run baseline build and test. Produce a baseline and '
    'request human approval; do not resolve the approval — that gate is human '
    'only.';

/// Builds the durable [Job] both triggers write.
///
/// One factory so the two triggers cannot drift into writing different jobs
/// under the same dedupe key — which would defeat the key, since dedupe is by
/// key and not by job shape.
///
/// [jobId] is supplied rather than derived because the store, not this package,
/// owns id allocation; [maxAttempts] follows [onboardProductDefinition] unless
/// a caller has a reason to narrow it.
Job onboardingJob({
  required String jobId,
  required String productId,
  required String repositoryId,
  required String startingRevision,
  required DateTime now,
  JobDefinition definition = onboardProductDefinition,
}) {
  final workItemId = onboardingWorkItemId(productId);
  return Job(
    jobId: jobId,
    workItemId: workItemId,
    jobType: definition.jobType,
    requiredRole: definition.requiredRole,
    requiredCapabilities: definition.requiredCapabilities,
    priority: definition.priority,
    state: JobState.queued,
    dedupeKey: onboardingDedupeKey(
      productId: productId,
      repositoryId: repositoryId,
      startingRevision: startingRevision,
    ),
    createdAt: now,
    instruction: onboardingInstruction(
      productId: productId,
      repositoryId: repositoryId,
      startingRevision: startingRevision,
    ),
    attempt: 1,
    maxAttempts: definition.maxAttempts,
    version: 1,
  );
}
