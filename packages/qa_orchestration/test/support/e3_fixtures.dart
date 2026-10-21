import 'package:platform_contracts/platform_contracts.dart';

/// Shared, deliberately boring fixtures for the three substantive-gate
/// evaluators. Nothing here computes the condition under test; every value is
/// supplied by the caller so a test can change exactly one fact.
AgentResult agentResultFor({
  String? executionId = 'exec-1',
  String workItemId = 'work-1',
}) {
  return AgentResult(
    resultId: 'result-1',
    sessionId: 'session-1',
    workItemId: workItemId,
    status: AgentResultStatus.completed,
    artifacts: const [],
    diagnostics: const AgentDiagnostics(
      exitCode: 0,
      durationMs: 1000,
      toolCalls: 0,
      errors: [],
      warnings: [],
    ),
    structuredResult: const {},
    executionId: executionId,
    completedAt: DateTime.utc(2026, 10, 20),
  );
}

/// The same shape as [agentResultFor], with an explicit `structuredResult`.
///
/// R3 (`triage-classification-structure`) is source-free and reads the agent's
/// own structured output, so a test that drives it both ways needs to vary this
/// map and nothing else. Kept separate from [agentResultFor] so the shared
/// fixture stays boring and a caller opts in to a populated payload.
AgentResult agentResultWithStructuredResult(
  Map<String, dynamic> structuredResult, {
  String workItemId = 'work-1',
}) {
  return AgentResult(
    resultId: 'result-1',
    sessionId: 'session-1',
    workItemId: workItemId,
    status: AgentResultStatus.completed,
    artifacts: const [],
    diagnostics: const AgentDiagnostics(
      exitCode: 0,
      durationMs: 1000,
      toolCalls: 0,
      errors: [],
      warnings: [],
    ),
    structuredResult: structuredResult,
    executionId: 'exec-1',
    completedAt: DateTime.utc(2026, 10, 20),
  );
}

QAGateDefinition gateFor({
  required String gateId,
  required String type,
  required Map<String, dynamic> config,
}) {
  return QAGateDefinition(
    gateId: gateId,
    type: type,
    required: true,
    config: config,
    evidenceTypes: const [],
  );
}

PlatformVerification verificationRow({
  required String checkName,
  required String command,
  String executionId = 'exec-1',
  String workItemId = 'work-1',
  AgentClaimStatus status = AgentClaimStatus.passed,
  EvidenceKind evidenceKind = EvidenceKind.platformVerifiedEvidence,
}) {
  return PlatformVerification(
    verificationId: 'ver-$executionId-$checkName',
    executionId: executionId,
    workItemId: workItemId,
    checkName: checkName,
    status: status,
    mechanism: 'process_${command.split(' ').first}',
    command: command,
    capturedAt: DateTime.utc(2026, 10, 20),
    evidenceKind: evidenceKind,
  );
}

Defect defectRow({required String defectId, String title = 'A defect'}) {
  return Defect(
    defectId: defectId,
    title: title,
    description: 'description',
    severity: 'high',
    status: DefectStatus.reported,
    reporter: 'qa',
    createdAt: DateTime.utc(2026, 10, 20),
    updatedAt: DateTime.utc(2026, 10, 20),
    version: 1,
  );
}
