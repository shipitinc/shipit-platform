import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/defect_clarification_request_view.dart';
import '../generated/defect_clarification_view.dart';
import '../generated/defect_created_view.dart';
import '../generated/defect_detail_view.dart';
import '../generated/defect_evidence_view.dart';
import '../generated/defect_event_view.dart';
import '../generated/defect_inspection_view.dart';
import '../generated/defect_list_view.dart';
import '../generated/defect_summary_view.dart';
import '../generated/fix_verification_view.dart';
import '../generated/triage_result_view.dart';
import '../persistence/persistence_database.dart';
import '../persistence/postgres_defect_store.dart';
import '../services/control_plane_service.dart';

/// Endpoints for durable Human Bug Reporting (S-2).
///
/// Every defect-scoped read takes an explicit `defectId` or `productId`.
/// Endpoints never set state directly — they observe or raise gates that
/// the platform's durable engines resolve.
class DefectEndpoints extends Endpoint {
  @override
  bool get logSessions => true;

  /// Reports a new defect.
  ///
  /// Creates the Defect, initial evidence (text + diagnostic bundle),
  /// and the initial 'created' event. Enqueues a triage job.
  Future<DefectCreatedView> create(
    Session session, {
    required String title,
    required String description,
    String? expectedBehavior,
    String? reproductionSteps,
    required String severity,
    String? intakeCategory,
    required String productId,
    String? affectedWorkItemId,
    String? affectedRunId,
    String? clientContextJson,
    required String reporter,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final defect = await service.createDefect(
        title: title,
        description: description,
        expectedBehavior: expectedBehavior,
        reproductionSteps: reproductionSteps,
        severity: severity,
        intakeCategory: intakeCategory,
        productId: productId,
        affectedWorkItemId: affectedWorkItemId,
        affectedRunId: affectedRunId,
        clientContextJson: clientContextJson,
        reporter: reporter,
      );
      return DefectCreatedView(
        defectId: defect.defectId,
        title: defect.title,
        status: defect.status.wire,
        createdAt: defect.createdAt,
      );
    } catch (error, stackTrace) {
      service.logger.error('defect.create.failed', {
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Lists defects with optional filters.
  Future<DefectListView> list(
    Session session, {
    String? productId,
    String? status,
    String? classification,
    int? limit,
    int? offset,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final defects = await service.listDefects(
        productId: productId,
        status: status != null ? DefectStatus.fromWire(status) : null,
        classification: classification != null
            ? DefectClassification.fromWire(classification)
            : null,
        limit: limit,
        offset: offset,
      );
      final totalCount = await service.countDefects(
        productId: productId,
        status: status != null ? DefectStatus.fromWire(status) : null,
        classification: classification != null
            ? DefectClassification.fromWire(classification)
            : null,
      );
      return DefectListView(
        defects: defects.map(_defectSummary).toList(growable: false),
        totalCount: totalCount,
      );
    } catch (error, stackTrace) {
      service.logger.error('defect.list.failed', {
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Reads full defect detail including evidence, clarifications, events,
  /// triage result, and remediation work item.
  Future<DefectInspectionView> inspect(
    Session session, {
    required String defectId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final defect = await service.inspectDefect(defectId);
      final evidence = await service.readDefectEvidence(defectId);
      final clarifications = await service.readDefectClarifications(defectId);
      final events = await service.readDefectEvents(defectId);

      return DefectInspectionView(
        defect: _defectDetail(defect),
        evidence: evidence.map(_evidenceView).toList(growable: false),
        clarifications: clarifications
            .map(_clarificationView)
            .toList(growable: false),
        events: events.map(_eventView).toList(growable: false),
        triageResult: _triageResultView(
          await _readCurrentTriageResult(session, defect),
        ),
        // TODO: wire up when remediation is linked. The field is declared
        // nullable so that linking one is a server-side change only.
        remediationWorkItem: null,
      );
    } catch (error, stackTrace) {
      service.logger.error('defect.inspect.failed', {
        'defectId': defectId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Adds evidence to an existing defect.
  Future<DefectEvidenceView> addEvidence(
    Session session, {
    required String defectId,
    required String kind,
    String? description,
    String? artifactId,
    String? contentHash,
    String? sourceRef,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final evidence = await service.addDefectEvidence(
        defectId: defectId,
        kind: EvidenceIntakeKind.fromWire(kind),
        description: description,
        artifactId: artifactId,
        contentHash: contentHash,
        sourceRef: sourceRef,
      );
      return _evidenceView(evidence);
    } catch (error, stackTrace) {
      service.logger.error('defect.add_evidence.failed', {
        'defectId': defectId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// AI requests clarification (internal use — typically called by triage agent).
  Future<DefectClarificationView> requestClarification(
    Session session, {
    required String defectId,
    required String question,
    required String reason,
    required String triageJobId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final clarification = await service.requestDefectClarification(
        defectId: defectId,
        question: question,
        reason: reason,
        triageJobId: triageJobId,
      );
      return _clarificationView(clarification);
    } catch (error, stackTrace) {
      service.logger.error('defect.request_clarification.failed', {
        'defectId': defectId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Human answers a clarification.
  Future<DefectClarificationView> answerClarification(
    Session session, {
    required String clarificationId,
    required String answer,
    required String answeredBy,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final clarification = await service.answerDefectClarification(
        clarificationId: clarificationId,
        answer: answer,
        answeredBy: answeredBy,
      );
      return _clarificationView(clarification);
    } catch (error, stackTrace) {
      service.logger.error('defect.answer_clarification.failed', {
        'clarificationId': clarificationId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Human verifies a fix for a defect.
  Future<FixVerificationView> verifyFix(
    Session session, {
    required String defectId,
    required String choice,
    String? rationale,
    required String decider,
    required String signature,
    required String publicKey,
    required String algorithm,
    required DateTime signedAt,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final defect = await service.verifyFix(
        defectId: defectId,
        choice: HumanDecisionChoice.fromWire(choice),
        rationale: rationale ?? '',
        decider: decider,
        signature: DecisionSignature(
          algorithm: algorithm,
          publicKey: publicKey,
          signature: signature,
          signedAt: signedAt,
        ),
      );
      return FixVerificationView(
        success: true,
        newStatus: defect.status.wire,
        message: 'Verification recorded',
      );
    } catch (error, stackTrace) {
      service.logger.error('defect.verify_fix.failed', {
        'defectId': defectId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  // ---------------------------------------------------------------------
  // Triage read
  // ---------------------------------------------------------------------

  /// Reads the triage outcome that currently governs [defect], or null when
  /// triage has not produced a durable result for it yet.
  ///
  /// Preference order is deliberate:
  /// 1. the result of the defect's own `currentTriageJobId`, which is the
  ///    attempt the platform is actually waiting on, and
  /// 2. otherwise the most recently created result for the defect.
  ///
  /// The fallback matters because a defect whose triage was re-enqueued after
  /// a clarification has a `currentTriageJobId` that has not finished yet; the
  /// previous attempt's result is still the newest fact on record and hiding it
  /// would report "no triage" while a durable result exists.
  ///
  /// This reads through the store directly instead of via
  /// [ControlPlaneService] because the service exposes no triage-result read;
  /// the store is constructed over the same
  /// `PersistenceDatabase(session.db)` the service uses, so this is a plain
  /// read of durable state on the request's own session, not a second write
  /// path. `ControlPlaneService.defectStore` is a getter that builds exactly
  /// this object.
  Future<TriageResult?> _readCurrentTriageResult(
    Session session,
    Defect defect,
  ) {
    final store = PostgresDefectStore(PersistenceDatabase(session.db));
    final jobId = defect.currentTriageJobId;
    if (jobId != null && jobId.isNotEmpty) {
      return store.readTriageResultForJob(jobId);
    }
    return store
        .readTriageResultsForDefect(defect.defectId)
        .then((results) => results.firstOrNull);
  }

  // ---------------------------------------------------------------------
  // Projections
  //
  // NAMED COPIES, not `toJson()`, and the difference is the point. Every field
  // the endpoint publishes is named here, so a field added to a domain type
  // breaks the build at this line instead of silently widening a wire contract
  // that a client would then have to guess at. That is the same reasoning as
  // `_mintedCredentialView` in `credential_endpoints.dart`.
  //
  // THE FREE-FORM BLOBS TRAVEL AS JSON TEXT. `Defect.clientContextJson`,
  // `Defect.metadataJson` and `DefectEvent.payloadJson` are stored as JSON text
  // already; Serverpod 3.4.13 refuses `dynamic` in a model schema outright, so
  // there is no field type that could hold parsed JSON, and a `Map<String,
  // dynamic>` field would reintroduce the very defect this file is fixing one
  // level down.
  // ---------------------------------------------------------------------

  DefectSummaryView _defectSummary(Defect d) => DefectSummaryView(
    defectId: d.defectId,
    title: d.title,
    severity: d.severity,
    status: d.status.wire,
    classification: d.classification?.wire,
    reporter: d.reporter,
    productId: d.productId,
    productName: d.productName,
    createdAt: d.createdAt,
    updatedAt: d.updatedAt,
    affectedWorkItemId: d.affectedWorkItemId,
    affectedRunId: d.affectedRunId,
    remediationWorkItemId: d.remediationWorkItemId,
  );

  DefectDetailView _defectDetail(Defect d) => DefectDetailView(
    defectId: d.defectId,
    title: d.title,
    severity: d.severity,
    status: d.status.wire,
    classification: d.classification?.wire,
    reporter: d.reporter,
    productId: d.productId,
    productName: d.productName,
    createdAt: d.createdAt,
    updatedAt: d.updatedAt,
    affectedWorkItemId: d.affectedWorkItemId,
    affectedRunId: d.affectedRunId,
    remediationWorkItemId: d.remediationWorkItemId,
    description: d.description,
    expectedBehavior: d.expectedBehavior,
    reproductionSteps: d.reproductionSteps,
    clientContextJson: d.clientContextJson,
    metadataJson: d.metadataJson,
    resolvedAt: d.resolvedAt,
    closedAt: d.closedAt,
    version: d.version,
  );

  DefectEvidenceView _evidenceView(DefectEvidence e) => DefectEvidenceView(
    evidenceId: e.evidenceId,
    defectId: e.defectId,
    kind: e.kind.wire,
    artifactId: e.artifactId,
    contentHash: e.contentHash,
    description: e.description,
    sourceRef: e.sourceRef,
    capturedAt: e.capturedAt,
    createdAt: e.createdAt,
  );

  DefectClarificationView _clarificationView(DefectClarification c) =>
      DefectClarificationView(
        clarificationId: c.clarificationId,
        defectId: c.defectId,
        question: c.question,
        reason: c.reason,
        status: c.status.wire,
        answer: c.answer,
        humanDecisionId: c.humanDecisionId,
        requestedByTriageJobId: c.requestedByTriageJobId,
        requestedAt: c.requestedAt,
        answeredAt: c.answeredAt,
        createdAt: c.createdAt,
      );

  DefectEventView _eventView(DefectEvent e) => DefectEventView(
    eventId: e.eventId,
    defectId: e.defectId,
    sequence: e.sequence,
    type: e.type.wire,
    fromStatus: e.fromStatus?.wire,
    toStatus: e.toStatus?.wire,
    actorType: e.actorType.wire,
    actorId: e.actorId,
    payloadJson: e.payloadJson,
    occurredAt: e.occurredAt,
  );

  TriageResultView? _triageResultView(TriageResult? t) {
    if (t == null) return null;
    return TriageResultView(
      resultId: t.resultId,
      defectId: t.defectId,
      recommendedStatus: t.recommendedStatus.wire,
      recommendedClassification: t.recommendedClassification.wire,
      confidence: t.confidence,
      suspectedCategory: t.suspectedCategory,
      suspectedComponents: t.suspectedComponents,
      reproductionSupported: t.reproductionSupported,
      evidenceUsed: t.evidenceUsed,
      clarificationRequired: t.clarificationRequired
          .map(
            (c) => DefectClarificationRequestView(
              question: c.question,
              reason: c.reason,
            ),
          )
          .toList(growable: false),
      recommendedNextAction: t.recommendedNextAction,
      possibleDuplicateDefectId: t.possibleDuplicateDefectId,
      recommendedWorkItemCategory: t.recommendedWorkItemCategory,
      summary: t.summary,
      jobId: t.jobId,
      executionId: t.executionId,
      createdAt: t.createdAt,
      completedAt: t.completedAt,
      version: t.version,
    );
  }
}
