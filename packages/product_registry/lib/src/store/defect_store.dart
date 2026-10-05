import 'package:platform_contracts/platform_contracts.dart';

/// Durable container for everything S-2 Human Bug Reporting needs to persist
/// and resume across process restarts:
/// - Defect aggregate (identity, lifecycle, classification)
/// - DefectEvidence (append-only evidence with artifact references)
/// - DefectEvent (append-only event history / audit trail)
/// - DefectClarification (durable Q&A when triage needs more info)
///
/// All defect reads that carry product scope are parameterized by [productId]
/// where applicable and must reject cross-Product access. No global defect scope.
abstract interface class DefectStore {
  // ---- Defect ----
  Future<void> saveDefect(Defect defect, {int? expectedVersion});

  Future<Defect> readDefect(String defectId);

  Future<List<Defect>> listDefects({
    String? productId,
    DefectStatus? status,
    DefectClassification? classification,
    int? limit,
    int? offset,
  });

  Future<int> countDefects({
    String? productId,
    DefectStatus? status,
    DefectClassification? classification,
  });

  // ---- DefectEvidence ----
  Future<void> saveDefectEvidence(DefectEvidence evidence);

  Future<List<DefectEvidence>> readEvidenceForDefect(String defectId);

  // ---- DefectEvent ----
  Future<void> appendDefectEvent(DefectEvent event);

  Future<List<DefectEvent>> readEventsForDefect(String defectId);

  // ---- DefectClarification ----
  Future<void> saveClarification(DefectClarification clarification);

  Future<DefectClarification?> readClarification(String clarificationId);

  Future<List<DefectClarification>> readClarificationsForDefect(
    String defectId,
  );

  // ---- Triage linkage ----
  /// Sets the current triage job ID for a defect, or null to clear.
  Future<void> setTriageJob(String defectId, String? jobId);

  // ---- TriageResult ----
  Future<void> saveTriageResult(TriageResult result, {int? expectedVersion});

  Future<TriageResult?> readTriageResult(String resultId);

  Future<List<TriageResult>> readTriageResultsForDefect(String defectId);

  Future<TriageResult?> readTriageResultForJob(String jobId);

  // ---- Transaction support ----
  Future<T> inTransaction<T>(
    Future<T> Function(DefectStore store) body,
  ) async => body(this);
}
