import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/serverpod.dart';

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
  Future<Map<String, dynamic>> create(
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
      return {
        'defectId': defect.defectId,
        'title': defect.title,
        'status': defect.status.wire,
        'createdAt': defect.createdAt.toIso8601String(),
      };
    } catch (error, stackTrace) {
      service.logger.error('defect.create.failed', {
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Lists defects with optional filters.
  Future<Map<String, dynamic>> list(
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
      return {
        'defects': defects.map(_defectSummaryMap).toList(),
        'totalCount': totalCount,
      };
    } catch (error, stackTrace) {
      service.logger.error('defect.list.failed', {
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Reads full defect detail including evidence, clarifications, events,
  /// triage result, and remediation work item.
  Future<Map<String, dynamic>> inspect(
    Session session, {
    required String defectId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final defect = await service.inspectDefect(defectId);
      final evidence = await service.readDefectEvidence(defectId);
      final clarifications = await service.readDefectClarifications(defectId);
      final events = await service.readDefectEvents(defectId);

      return {
        'defect': _defectDetailMap(defect),
        'evidence': evidence.map(_evidenceMap).toList(),
        'clarifications': clarifications.map(_clarificationMap).toList(),
        'events': events.map(_eventMap).toList(),
        'triageResult': _triageResultMap(
          await _readCurrentTriageResult(session, defect),
        ),
        'remediationWorkItem': null, // TODO: wire up when remediation is linked
      };
    } catch (error, stackTrace) {
      service.logger.error('defect.inspect.failed', {
        'defectId': defectId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Adds evidence to an existing defect.
  Future<Map<String, dynamic>> addEvidence(
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
      return _evidenceMap(evidence);
    } catch (error, stackTrace) {
      service.logger.error('defect.add_evidence.failed', {
        'defectId': defectId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// AI requests clarification (internal use — typically called by triage agent).
  Future<Map<String, dynamic>> requestClarification(
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
      return _clarificationMap(clarification);
    } catch (error, stackTrace) {
      service.logger.error('defect.request_clarification.failed', {
        'defectId': defectId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Human answers a clarification.
  Future<Map<String, dynamic>> answerClarification(
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
      return _clarificationMap(clarification);
    } catch (error, stackTrace) {
      service.logger.error('defect.answer_clarification.failed', {
        'clarificationId': clarificationId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Human verifies a fix for a defect.
  Future<Map<String, dynamic>> verifyFix(
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
      return {
        'success': true,
        'newStatus': defect.status.wire,
        'message': 'Verification recorded',
      };
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
  // Map helpers
  // ---------------------------------------------------------------------

  Map<String, dynamic> _defectSummaryMap(Defect d) => {
    'defectId': d.defectId,
    'title': d.title,
    'severity': d.severity,
    'status': d.status.wire,
    'classification': d.classification?.wire,
    'reporter': d.reporter,
    'productId': d.productId,
    'productName': d.productName,
    'createdAt': d.createdAt.toIso8601String(),
    'updatedAt': d.updatedAt.toIso8601String(),
    'affectedWorkItemId': d.affectedWorkItemId,
    'affectedRunId': d.affectedRunId,
    'remediationWorkItemId': d.remediationWorkItemId,
  };

  Map<String, dynamic> _defectDetailMap(Defect d) => {
    ..._defectSummaryMap(d),
    'description': d.description,
    'expectedBehavior': d.expectedBehavior,
    'reproductionSteps': d.reproductionSteps,
    'clientContextJson': d.clientContextJson,
    'metadataJson': d.metadataJson,
    'resolvedAt': d.resolvedAt?.toIso8601String(),
    'closedAt': d.closedAt?.toIso8601String(),
    'version': d.version,
  };

  Map<String, dynamic> _evidenceMap(DefectEvidence e) => {
    'evidenceId': e.evidenceId,
    'defectId': e.defectId,
    'kind': e.kind.wire,
    'artifactId': e.artifactId,
    'contentHash': e.contentHash,
    'description': e.description,
    'sourceRef': e.sourceRef,
    'capturedAt': e.capturedAt.toIso8601String(),
    'createdAt': e.createdAt.toIso8601String(),
  };

  Map<String, dynamic> _clarificationMap(DefectClarification c) => {
    'clarificationId': c.clarificationId,
    'defectId': c.defectId,
    'question': c.question,
    'reason': c.reason,
    'status': c.status.wire,
    'answer': c.answer,
    'humanDecisionId': c.humanDecisionId,
    'requestedByTriageJobId': c.requestedByTriageJobId,
    'requestedAt': c.requestedAt.toIso8601String(),
    'answeredAt': c.answeredAt?.toIso8601String(),
    'createdAt': c.createdAt.toIso8601String(),
  };

  Map<String, dynamic> _eventMap(DefectEvent e) => {
    'eventId': e.eventId,
    'defectId': e.defectId,
    'sequence': e.sequence,
    'type': e.type.wire,
    'fromStatus': e.fromStatus?.wire,
    'toStatus': e.toStatus?.wire,
    'actorType': e.actorType.wire,
    'actorId': e.actorId,
    'payloadJson': e.payloadJson,
    'occurredAt': e.occurredAt.toIso8601String(),
  };

  Map<String, dynamic>? _triageResultMap(TriageResult? t) {
    if (t == null) return null;
    return {
      'resultId': t.resultId,
      'defectId': t.defectId,
      'recommendedStatus': t.recommendedStatus.wire,
      'recommendedClassification': t.recommendedClassification.wire,
      'confidence': t.confidence,
      'suspectedCategory': t.suspectedCategory,
      'suspectedComponents': t.suspectedComponents,
      'reproductionSupported': t.reproductionSupported,
      'evidenceUsed': t.evidenceUsed,
      'clarificationRequired': t.clarificationRequired
          .map((c) => c.toJson())
          .toList(growable: false),
      'recommendedNextAction': t.recommendedNextAction,
      'possibleDuplicateDefectId': t.possibleDuplicateDefectId,
      'recommendedWorkItemCategory': t.recommendedWorkItemCategory,
      'summary': t.summary,
      'jobId': t.jobId,
      'executionId': t.executionId,
      'createdAt': t.createdAt.toIso8601String(),
      'completedAt': t.completedAt?.toIso8601String(),
      'version': t.version,
    };
  }
}
