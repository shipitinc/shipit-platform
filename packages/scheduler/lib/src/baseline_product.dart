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
  return 'onboarding:$productId:$repositoryId:$startingRevision';
}

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
