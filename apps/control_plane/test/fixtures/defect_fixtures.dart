import 'dart:async';

import 'package:control_plane/data/control_plane_repository.dart';

import 'app_fixtures.dart';

/// A [MockRepository] that also answers the defect APIs, so a defect screen can
/// be hosted inside the real shell without a server.
class DefectRepository extends MockRepository {
  DefectRepository({
    this.defects = const [],
    this.detail,
    this.listError,
    this.holdList = false,
  });

  final List<DefectSummaryResponse> defects;
  final InspectDefectResponse? detail;
  final Object? listError;

  /// Leaves `listDefects` pending, which holds the list screen in its loading
  /// branch instead of racing past it.
  final bool holdList;

  final Completer<ListDefectsResponse> _pendingList = Completer();

  /// Completes a held `listDefects` call. A bloc that is still awaiting its
  /// handler cannot be closed until the handler returns, so a test that holds
  /// a request open has to release it before teardown.
  void releaseHeldList() {
    final pending = _pendingList;
    if (!pending.isCompleted) {
      pending.complete(
        ListDefectsResponse(defects: defects, totalCount: defects.length),
      );
    }
  }

  @override
  Future<ListDefectsResponse> listDefects({
    String? productId,
    String? status,
    String? classification,
    int? limit,
    int? offset,
  }) async {
    if (holdList) return _pendingList.future;
    if (listError != null) throw listError!;
    return ListDefectsResponse(defects: defects, totalCount: defects.length);
  }

  @override
  Future<InspectDefectResponse> inspectDefect(String defectId) async {
    final d = detail;
    if (d == null) throw StateError('no defect detail in fake');
    return d;
  }
}

/// The instant every defect fixture is stamped with, so freshness labels and
/// relative times are identical between runs.
final defectAsOf = DateTime(2026, 9, 16, 12, 0);

DateTime defectClock() => defectAsOf.add(const Duration(seconds: 12));

DefectSummaryResponse makeDefect({
  required String defectId,
  required String title,
  required String severity,
  required String status,
  String? classification,
  String reporter = 'operator@shipit.dev',
  String? affectedRunId,
  String? affectedWorkItemId,
  String? remediationWorkItemId,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return DefectSummaryResponse(
    defectId: defectId,
    title: title,
    severity: severity,
    status: status,
    classification: classification,
    reporter: reporter,
    createdAt: createdAt ?? defectAsOf.subtract(const Duration(hours: 5)),
    updatedAt: updatedAt ?? defectAsOf,
    affectedRunId: affectedRunId,
    affectedWorkItemId: affectedWorkItemId,
    remediationWorkItemId: remediationWorkItemId,
  );
}

DefectEvidenceResponse makeDefectEvidence({
  required String evidenceId,
  required String defectId,
  required String kind,
  String? description,
  String? sourceRef,
  String? artifactId,
}) {
  return DefectEvidenceResponse(
    evidenceId: evidenceId,
    defectId: defectId,
    kind: kind,
    description: description,
    sourceRef: sourceRef,
    artifactId: artifactId,
    capturedAt: defectAsOf.subtract(const Duration(hours: 4)),
    createdAt: defectAsOf.subtract(const Duration(hours: 4)),
  );
}

DefectClarificationResponse makeClarification({
  required String clarificationId,
  required String defectId,
  required String question,
  required String reason,
  String status = 'needs_answer',
  String? answer,
  String? humanDecisionId,
}) {
  return DefectClarificationResponse(
    clarificationId: clarificationId,
    defectId: defectId,
    question: question,
    reason: reason,
    status: status,
    answer: answer,
    humanDecisionId: humanDecisionId,
    requestedByTriageJobId: 'TJ-55c1',
    requestedAt: defectAsOf.subtract(const Duration(hours: 2)),
    answeredAt: answer == null
        ? null
        : defectAsOf.subtract(const Duration(minutes: 20)),
    createdAt: defectAsOf.subtract(const Duration(hours: 2)),
  );
}

DefectEventResponse makeDefectEvent({
  required String eventId,
  required String defectId,
  required int sequence,
  required String type,
  required String actorType,
  required String actorId,
  String? fromStatus,
  String? toStatus,
  DateTime? at,
}) {
  return DefectEventResponse(
    eventId: eventId,
    defectId: defectId,
    sequence: sequence,
    type: type,
    fromStatus: fromStatus,
    toStatus: toStatus,
    actorType: actorType,
    actorId: actorId,
    occurredAt: at ?? defectAsOf.subtract(Duration(minutes: 30 * sequence)),
  );
}

TriageResultResponse makeTriageResult({
  required String triageResultId,
  required String defectId,
  String? classification = 'ui_defect',
  double? confidence = 0.82,
  String? rationale =
      'Reproduces on the mobile viewport and matches the reported steps.',
  String? recommendedAction = 'open_remediation',
  bool? needsClarification = false,
  String? clarificationQuestion,
  String? clarificationReason,
}) {
  return TriageResultResponse(
    triageResultId: triageResultId,
    defectId: defectId,
    triageJobId: 'TJ-55c1',
    classification: classification,
    confidence: confidence,
    rationale: rationale,
    recommendedAction: recommendedAction,
    needsClarification: needsClarification,
    clarificationQuestion: clarificationQuestion,
    clarificationReason: clarificationReason,
    createdAt: defectAsOf.subtract(const Duration(hours: 3)),
  );
}

RemediationWorkItemResponse makeRemediationWorkItem({
  required String workItemId,
  required String title,
  required String state,
  String? description = 'Fix the layout regression found in the mobile board.',
  DateTime? completedAt,
}) {
  return RemediationWorkItemResponse(
    workItemId: workItemId,
    title: title,
    description: description,
    state: state,
    createdAt: defectAsOf.subtract(const Duration(hours: 2)),
    updatedAt: defectAsOf,
    completedAt: completedAt,
  );
}
