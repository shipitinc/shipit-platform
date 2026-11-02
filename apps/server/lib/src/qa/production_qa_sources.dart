import 'package:execution_coordinator/execution_coordinator.dart'
    show
        CommittedDiffPathCollector,
        ExecutionStore,
        GitWorkspaceDeltaProbe,
        ProducerResolution,
        WorkspaceDelta,
        WorkspaceDeltaProbe,
        WorkspaceHeadReader,
        resolveProducerExecution;
import 'package:platform_contracts/platform_contracts.dart'
    show
        AgentResult,
        AgentRole,
        CommittedDiffPaths,
        Defect,
        DefectEvidence,
        HumanDecision,
        HumanDecisionStatus,
        HumanDecisionType,
        PlatformVerification,
        WorkerCapability,
        WorkItem,
        WorkspaceHead,
        declaredOwnedPathsFromMetadata;
import 'package:product_registry/product_registry.dart' show DefectStore;
import 'package:qa_orchestration/qa_orchestration.dart'
    show
        ArtifactProvenanceSource,
        ChangeScopeSource,
        CommittedDiffScopeBaseline,
        DeclaredOwnedPathsSource,
        DefectEvidenceReader,
        DefectRowReader,
        ExecutionDelta,
        GateRegistry,
        PlatformVerificationReader,
        QASourceProvenance,
        RevisionIdentitySource,
        TriageClassificationAdmittedGate,
        buildGateRegistry;
import 'package:worker_runtime/worker_runtime.dart' show WorkerStore;
import 'package:workflow_store/workflow_store.dart' show WorkflowStore;

import '../persistence/postgres_defect_store.dart' show DefectNotFoundException;
import 'producer_scoped_gate.dart'
    show ProducerRoleScopedGate, ProducerRoleSource;

/// The producing execution of a work item, and the workspace it worked in.
///
/// ## WHY THIS IS A VALUE AND NOT THE EXECUTION ITSELF
///
/// Four of the six sources need the same three facts — which execution
/// produced the item, what its result was, and which worktree it ran in — and
/// they need them resolved by **one** rule. If F1 resolved the producer one
/// way and F5 another, the two gates would be comparing facts about different
/// runs, and the record would say "the reviewed revision is not the produced
/// revision" for a run that produced exactly one revision.
///
/// So the rule lives here, once, and every source reads it from here.
class ResolvedProducer {
  const ResolvedProducer({
    required this.executionId,
    required this.result,
    required this.workingDirectory,
    required this.startingRevision,
    required this.how,
    required this.note,
    this.role,
  });

  /// The producing execution's id.
  final String executionId;

  /// The producing execution's durable result, when it could be read.
  final AgentResult? result;

  /// The worktree the execution ran in.
  ///
  /// The **worktree**, not the repository: a worker's `repositoryPath` is the
  /// clone it was given, and the artefact an implementation produced lives in
  /// the worktree it was dispatched into. F1's probe and F2's path collector
  /// both run `git -C <this>`.
  final String workingDirectory;

  /// The revision the execution started from, when it recorded one.
  final String? startingRevision;

  /// How the producer was identified. See [ProducerResolution].
  final ProducerResolution how;

  /// One sentence, safe to log.
  final String note;

  /// The producing execution's durable [AgentExecution.role], when the
  /// execution row could be read.
  ///
  /// Nullable on the TYPE rather than required because the value is read off a
  /// row the resolver may not see in tests — doubles that construct a
  /// [ResolvedProducer] directly carry no role, and an absent role must read
  /// as "not established", which the producer-scoped gate treats as
  /// fail-closed. In production [ProducerWorkspaceResolver] always populates
  /// it from the execution it resolved.
  final AgentRole? role;
}

/// The seam the QA drain reads a work item's producer through.
///
/// ## WHY IT IS AN INTERFACE AND NOT THE CONCRETE RESOLVER
///
/// The drain needs one fact — "which execution produced this item, and where
/// did it work" — and the platform's rule for answering it lives in
/// [ProducerWorkspaceResolver]. The drain does not need the rule; it needs the
/// answer. Naming the answer as a seam keeps the drain's own logic testable
/// against a producer that is known, instead of against a store that must be
/// populated well enough for the platform's resolution rule to find something.
///
/// It is deliberately ONE method rather than the resolver's two: the drain
/// always has the work item in hand (it just read it), so
/// [ProducerWorkspaceResolver.resolve] — which re-reads the item by id — has
/// no caller here.
abstract interface class ProducerResolver {
  /// The producer of [item], or `null` when nothing identifies it.
  Future<ResolvedProducer?> resolveFor(WorkItem item);
}

/// Resolves the execution that PRODUCED a work item, and its workspace.
///
/// ## THE RULE IS THE PLATFORM'S, NOT THIS FILE'S
///
/// The rule is `resolveProducerExecution`
/// (`packages/execution_coordinator/lib/src/coordinator/producer_execution.dart`):
/// the work item's own `metadata['producerActorId']` first, and — only when
/// that is absent — the newest implementer execution. That function exists
/// because the coordinator used to hand the guard "whatever ran most recently",
/// which handed a review the REVIEWER's result, and it refuses closed rather
/// than guessing.
///
/// This file does not have a second, kinder rule. It reads the platform's, so
/// the QA gates and the scheduler's `producedCommitFor` answer the same
/// question about one work item the same way.
class ProducerWorkspaceResolver implements ProducerResolver {
  const ProducerWorkspaceResolver({
    required this.executionStore,
    required this.workflowStore,
  });

  final ExecutionStore executionStore;
  final WorkflowStore workflowStore;

  /// Resolves the producer of [workItemId], or `null` when nothing identifies
  /// it.
  ///
  /// `null` is a value, not an error: an item whose producer cannot be
  /// identified has no workspace, and every source that needs one must fail
  /// closed on it rather than read some other run's tree.
  Future<ResolvedProducer?> resolve(String workItemId) async {
    final WorkItem? item;
    try {
      item = await workflowStore.readWorkItem(workItemId);
    } catch (_) {
      // The work item itself could not be read. That is a fault for the
      // caller to report, not a producer to be invented for.
      return null;
    }
    return resolveFor(item);
  }

  /// Resolves the producer of [item].
  @override
  Future<ResolvedProducer?> resolveFor(WorkItem item) async {
    final producer = await resolveProducerExecution(
      store: executionStore,
      workItemId: item.workItemId,
      producerActorId: item.metadata?['producerActorId'],
    );
    if (!producer.isResolved) return null;

    final executionId = producer.executionId!;
    final execution = await executionStore.readExecutionOrNull(executionId);
    if (execution == null) return null;

    return ResolvedProducer(
      executionId: executionId,
      result: producer.result,
      workingDirectory: execution.workspace.path,
      startingRevision: execution.workspace.startingRevision,
      how: producer.how,
      note: producer.note,
      role: execution.role,
    );
  }
}

/// F1's source: the platform's own account of what the producing execution
/// left behind, plus P1's unconditional `HEAD` re-read.
class ProductionArtifactProvenanceSource implements ArtifactProvenanceSource {
  const ProductionArtifactProvenanceSource({
    required this.resolver,
    this.probe = const GitWorkspaceDeltaProbe(),
    this.headReader = const WorkspaceHeadReader(),
  });

  final ProducerWorkspaceResolver resolver;
  final WorkspaceDeltaProbe probe;
  final WorkspaceHeadReader headReader;

  @override
  QASourceProvenance get provenance =>
      const QASourceProvenance.production('git_workspace_delta_probe');

  @override
  Future<ExecutionDelta> readDelta(String workItemId) async {
    final producer = await resolver.resolve(workItemId);
    if (producer == null) {
      return const ExecutionDelta.unreadable(
        'the execution that produced this work item could not be identified, so '
        'there is no workspace to inspect and nothing was looked at',
      );
    }
    final delta = await probe.probe(
      workingDirectory: producer.workingDirectory,
      startingRevision: producer.startingRevision,
    );
    return _mapDelta(delta);
  }

  @override
  Future<WorkspaceHead?> reReadHead(
    String workItemId, {
    required String? startingRevision,
  }) async {
    final producer = await resolver.resolve(workItemId);
    if (producer == null) return null;
    return headReader.read(
      workingDirectory: producer.workingDirectory,
      startingRevision: startingRevision,
    );
  }

  /// Maps the probe's answer field for field.
  ///
  /// The mapping is a translation with no room for a decision in it: the
  /// probe's three-valued shape (`unchanged` / `changed` / `committed` /
  /// `unreadable`) maps onto `ExecutionDelta`'s four constructors, and the
  /// one fact that must not be collapsed — `headMoved` is `null` when `HEAD`
  /// was never read — is carried across as `null`.
  ExecutionDelta _mapDelta(WorkspaceDelta delta) {
    if (!delta.isReadable) {
      return ExecutionDelta.unreadable(
        delta.unreadableReason ??
            'the workspace delta could not be read, and no reason was given',
      );
    }

    final starting = delta.startingRevision;
    if (starting == null || starting.isEmpty) {
      // The platform probe refuses a missing baseline before it looks
      // (`workspace_delta_probe.dart:174-183`), so this is not a shape
      // production produces. `ExecutionDelta` has no "readable without a
      // baseline" value, and inventing one here would be a decision in a
      // translation. Report it as unreadable instead.
      return const ExecutionDelta.unreadable(
        'the workspace delta was readable but carried no starting revision, so '
        'there is no baseline for it to be relative to',
      );
    }

    // A dirty tree first: the probe reports changed paths AND may report
    // `headMoved`, and `ExecutionDelta.changed` is the shape that says "the
    // worktree carries changes".
    if (delta.changedPaths.isNotEmpty) {
      return ExecutionDelta.changed(
        startingRevision: starting,
        headRevision: delta.headRevision,
        headMoved: delta.headMoved,
      );
    }

    if (delta.headMoved == true) {
      final head = delta.headRevision;
      if (head == null || head.isEmpty) {
        return const ExecutionDelta.unreadable(
          'the workspace delta reported that HEAD moved but named no revision '
          'it moved to, so the produced revision is not established',
        );
      }
      return ExecutionDelta.committed(
        startingRevision: starting,
        headRevision: head,
      );
    }

    final head = delta.headRevision;
    if (head == null || head.isEmpty) {
      return const ExecutionDelta.unreadable(
        'the workspace delta was readable but named no HEAD revision, so the '
        'produced revision is not established',
      );
    }
    return ExecutionDelta.unchanged(
      startingRevision: starting,
      headRevision: head,
    );
  }
}

/// F2's source: the committed path set, enumerated by the platform's own
/// collector.
class ProductionChangeScopeSource implements ChangeScopeSource {
  const ProductionChangeScopeSource({
    required this.resolver,
    this.collector = const CommittedDiffPathCollector(),
    this.headReader = const WorkspaceHeadReader(),
  });

  final ProducerWorkspaceResolver resolver;
  final CommittedDiffPathCollector collector;
  final WorkspaceHeadReader headReader;

  @override
  QASourceProvenance get provenance =>
      const QASourceProvenance.production('committed_diff_path_collector');

  @override
  Future<CommittedDiffScopeBaseline?> readBaseline(String workItemId) async {
    final producer = await resolver.resolve(workItemId);
    if (producer == null) return null;
    final starting = producer.startingRevision;
    if (starting == null || starting.trim().isEmpty) {
      return null;
    }
    return CommittedDiffScopeBaseline(
      workingDirectory: producer.workingDirectory,
      startingRevision: starting,
    );
  }

  @override
  Future<WorkspaceHead?> readProducedHead(String workItemId) async {
    final producer = await resolver.resolve(workItemId);
    if (producer == null) return null;
    return headReader.read(
      workingDirectory: producer.workingDirectory,
      startingRevision: producer.startingRevision,
    );
  }

  /// The collector's answer, verbatim.
  ///
  /// The interface's own contract: a failed enumeration surfaces as the
  /// collector's exception, never as a shorter list and never as an empty one.
  /// Mapping it here would let a failed enumeration read as "nothing is out of
  /// bounds", which is the vacuous pass F2 exists to prevent.
  @override
  Future<CommittedDiffPaths> collectPaths({
    required String workingDirectory,
    required String startingRevision,
    required String producedRevision,
  }) => collector.collect(
    workingDirectory: workingDirectory,
    startingRevision: startingRevision,
    producedRevision: producedRevision,
  );
}

/// F2's DECLARATION source: the owned paths the producing lane was dispatched
/// with.
///
/// ## WHERE THE ANSWER COMES FROM
///
/// The grant is captured into the agent execution's own metadata at DISPATCH
/// time, by the execution coordinator, in the same transaction that creates
/// the execution row. So the answer is read from the producing execution's
/// durable record — the same record F1, F2 and F5 already resolve the
/// producer through.
///
/// This is the dispatch-time capture the decision asked for, and it is what
/// makes the gate judge the change against what the lane WAS GRANTED rather
/// than against what the change turned out to touch.
///
/// ## WHY IT IS NOT THE WORK ITEM'S OWN CLAIM
///
/// A work item can say what it is about to touch. That is a CLAIM, made by the
/// lane itself, and a lane that lied in its claim would be judged against its
/// own lie. The grant is made by whoever dispatched the lane, which is why it
/// is captured at dispatch and read back from the execution record.
///
/// ## WHY IT ANSWERS WITH AN EMPTY LIST RATHER THAN AN ERROR
///
/// "No lane produced this item", "the producing execution has no captured
/// declaration" and "the declaration is unreadable" all read as "declared
/// nothing". The gate refuses an empty owned set, so all three fail closed —
/// and they fail closed for the same reason and with the same shape, so the
/// refusal is not a special case that has to be maintained separately.
class ProductionDeclaredOwnedPathsSource implements DeclaredOwnedPathsSource {
  const ProductionDeclaredOwnedPathsSource({
    required this.resolver,
    required this.executionStore,
  });

  final ProducerWorkspaceResolver resolver;
  final ExecutionStore executionStore;

  @override
  QASourceProvenance get provenance =>
      const QASourceProvenance.production('declared_owned_paths');

  @override
  Future<List<String>> readDeclaredOwnedPaths(String workItemId) async {
    final producer = await resolver.resolve(workItemId);
    if (producer == null) return const [];
    final execution = await executionStore.readExecutionOrNull(
      producer.executionId,
    );
    if (execution == null) return const [];
    return declaredOwnedPathsFromMetadata(execution.metadata);
  }
}

/// F4's source: the verification rows the platform itself recorded.
class ProductionPlatformVerificationReader
    implements PlatformVerificationReader {
  const ProductionPlatformVerificationReader({required this.executionStore});

  final ExecutionStore executionStore;

  @override
  QASourceProvenance get provenance =>
      const QASourceProvenance.production('platform_verification');

  @override
  Future<List<PlatformVerification>> readVerifications(String executionId) =>
      executionStore.readVerifications(executionId);
}

/// F5's source: the revision the engineering review recorded, and P1's re-read
/// of the revision the run produced.
class ProductionRevisionIdentitySource implements RevisionIdentitySource {
  const ProductionRevisionIdentitySource({
    required this.workflowStore,
    required this.workerStore,
    required this.resolver,
    this.headReader = const WorkspaceHeadReader(),
  });

  final WorkflowStore workflowStore;
  final WorkerStore workerStore;
  final ProducerWorkspaceResolver resolver;
  final WorkspaceHeadReader headReader;

  @override
  QASourceProvenance get provenance =>
      const QASourceProvenance.production('engineering_review_result');

  /// The revision the review that APPROVED this item was carried out against.
  ///
  /// ## WHY THE DECISION IS THE PRIMARY SOURCE
  ///
  /// `EngineeringReviewResult` carries no revision field. The revision lives
  /// on the reviewer's **worker execution** as `endingRevision` — the
  /// manifest's `reviewedRevisionField` names exactly that field — and the
  /// link from the review to its execution is carried by the human decision
  /// that approved it (`metadata['reviewExecutionId']`, written by
  /// `engineering_review_gate.dart`).
  ///
  /// The decision is the primary source because an item can only reach
  /// `reviewApproved` through one: the only edge into that state is
  /// `waitingForHumanDecision -> reviewApproved`, guarded by
  /// `blockingHumanDecisionResolved({(engineeringReview, approve)})` and
  /// `decisionActorIsHuman()`. So the decision naming the review is not a
  /// convenience — it is the one thing that is always there, and it names the
  /// SPECIFIC review the human approved rather than whichever review ran last.
  ///
  /// ## WHY THE FALLBACK REFUSES RATHER THAN PICKS
  ///
  /// When no decision names a review, the reviewer worker executions for the
  /// item are read instead. If they disagree about the revision, there is no
  /// single answer: two reviews of two different revisions exist, and picking
  /// the newest one would be a guess dressed as a fact. `null` is the honest
  /// answer, and F5's `nullRevisionIsFailure` turns it into a failure — which
  /// is the correct verdict for "the platform cannot say which revision was
  /// reviewed".
  @override
  Future<String?> readReviewedRevision(String workItemId) async {
    final executions = await workerStore.listWorkerExecutions();

    final reviewExecutionId = await _approvedReviewExecutionId(workItemId);
    if (reviewExecutionId != null) {
      final revisions = <String>{};
      for (final execution in executions) {
        if (execution.agentExecutionId != reviewExecutionId) continue;
        final ending = _normalise(execution.endingRevision);
        if (ending != null) revisions.add(ending);
      }
      if (revisions.length == 1) return revisions.single;
      // More than one worker execution for the same agent execution, or none
      // at all: fall through to the reviewer set rather than guess.
    }

    final reviewerRevisions = <String>{};
    for (final execution in executions) {
      if (execution.workItemId != workItemId) continue;
      if (!execution.requiredCapabilities.contains(
        WorkerCapability.engineeringReview,
      )) {
        continue;
      }
      final ending = _normalise(execution.endingRevision);
      if (ending != null) reviewerRevisions.add(ending);
    }
    if (reviewerRevisions.length == 1) return reviewerRevisions.single;
    return null;
  }

  @override
  Future<WorkspaceHead?> readProducedHead(String workItemId) async {
    final producer = await resolver.resolve(workItemId);
    if (producer == null) return null;
    return headReader.read(
      workingDirectory: producer.workingDirectory,
      startingRevision: producer.startingRevision,
    );
  }

  /// The agent execution id of the review the human approved, or `null`.
  Future<String?> _approvedReviewExecutionId(String workItemId) async {
    final List<HumanDecision> decisions;
    try {
      decisions = await workflowStore.readHumanDecisionsForWorkItem(workItemId);
    } catch (_) {
      return null;
    }

    final approved = decisions
        .where(
          (decision) =>
              decision.decisionType == HumanDecisionType.engineeringReview &&
              decision.status == HumanDecisionStatus.resolved,
        )
        .toList();
    if (approved.isEmpty) return null;

    // The most recently updated decision wins: a second review of the same
    // item raises a second decision, and the later one is the review the
    // item's current state was approved against.
    approved.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final raw = approved.first.metadata?['reviewExecutionId'];
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _normalise(String? revision) {
    if (revision == null) return null;
    final trimmed = revision.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// The [ProducerRoleSource] the producer-scoped gate reads, over the same
/// resolver every other production source uses.
///
/// The role it answers is the resolved execution's OWN durable column
/// (`AgentExecution.role`), resolved through `resolveProducerExecution` — the
/// platform's one rule for "which execution produced this item", the same rule
/// the drain resolved the result under evaluation through. Two reads of the
/// same rule agree, so the role this source answers is the role of the
/// execution whose `AgentResult` the gates are judging — never a different
/// run's.
///
/// `null` propagates the resolver's own "no producer identified" answer: it is
/// not an empty role and it is not an error, and the gate treats it as
/// "applicability cannot be established" — the fail-closed direction, which
/// evaluates the gate rather than exempting it.
class ProductionProducerRoleSource implements ProducerRoleSource {
  const ProductionProducerRoleSource({required this.resolver});

  final ProducerWorkspaceResolver resolver;

  @override
  QASourceProvenance get provenance =>
      const QASourceProvenance.production('producer_role');

  @override
  Future<AgentRole?> producerRoleFor(String workItemId) async =>
      (await resolver.resolve(workItemId))?.role;
}

/// R1's source: the defect row a remediation work item names.
class ProductionDefectRowReader implements DefectRowReader {
  const ProductionDefectRowReader({required this.defectStore});

  final DefectStore defectStore;

  @override
  QASourceProvenance get provenance =>
      const QASourceProvenance.production('defect_row');

  /// The defect, or `null` when there is no such row.
  ///
  /// The store raises `DefectNotFoundException` for an absent row; this
  /// adapter turns it into the `null` the interface declares, because "no such
  /// defect" is R1's SUBJECT, not a failure of the read. Letting the
  /// exception escape would abort the whole evaluation instead of failing one
  /// gate.
  @override
  Future<Defect?> readDefect(String defectId) async {
    try {
      return await defectStore.readDefect(defectId);
    } on DefectNotFoundException {
      return null;
    }
  }
}

/// R2's source: the evidence rows a triage classification cited.
class ProductionDefectEvidenceReader implements DefectEvidenceReader {
  const ProductionDefectEvidenceReader({required this.defectStore});

  final DefectStore defectStore;

  @override
  QASourceProvenance get provenance =>
      const QASourceProvenance.production('defect_evidence');

  @override
  Future<List<DefectEvidence>> readDefectEvidence(String defectId) =>
      defectStore.readEvidenceForDefect(defectId);
}

/// Builds the gate registry over the PRODUCTION readers.
///
/// ## WHY A BUILDER AND NOT A GLOBAL
///
/// `qa_orchestration` deliberately has no global registry: until slice 3c it
/// exported one wired to six fail-closed stand-ins, whose evidence rows named
/// the SAME `artifactRef` as the production adapters' — because `artifactRef`
/// names the READER, not the READER'S BINDING. A persisted gate result could
/// therefore not say whether the platform or a stand-in had produced it
/// (F-204).
///
/// This builder is the production side of that fix: the composition root
/// builds ONE registry, over readers that read the platform's own durable
/// state, and every gate result it produces carries
/// `sourceProvenance.kind == 'production'` with the adapter's own id.
GateRegistry buildProductionGateRegistry({
  required ProducerWorkspaceResolver resolver,
  required ExecutionStore executionStore,
  required WorkerStore workerStore,
  required WorkflowStore workflowStore,
  required DefectStore defectStore,
}) {
  return buildGateRegistry(
    artifactProvenanceSource: ProductionArtifactProvenanceSource(
      resolver: resolver,
    ),
    changeScopeSource: ProductionChangeScopeSource(resolver: resolver),
    platformVerificationReader: ProductionPlatformVerificationReader(
      executionStore: executionStore,
    ),
    revisionIdentitySource: ProductionRevisionIdentitySource(
      workflowStore: workflowStore,
      workerStore: workerStore,
      resolver: resolver,
    ),
    defectRowReader: ProductionDefectRowReader(defectStore: defectStore),
    defectEvidenceReader: ProductionDefectEvidenceReader(
      defectStore: defectStore,
    ),
  )..register(
    // F-246: `triage-classification-structure` asserts the shape of TRIAGE
    // output, and the shipped product contract declares it on every
    // `qa-product-*` contract — where an implementer's result could never
    // satisfy it. The scoped evaluator answers `not_applicable` for a
    // producer whose role is not `triageDefect`, and delegates verbatim for
    // one that is. Registering AFTER `buildGateRegistry` replaces the plain
    // evaluator under the same type key, so production applies the producer
    // scope while the package's own registry — and the test doubles built
    // from it — keep the unscoped assertion.
    ProducerRoleScopedGate(
      inner: TriageClassificationAdmittedGate(),
      roleSource: ProductionProducerRoleSource(resolver: resolver),
      appliesToRoles: const {AgentRole.triageDefect},
    ),
  );
}
