import 'package:platform_contracts/platform_contracts.dart';

import '../gate_evaluator.dart';

/// Reads the platform-written [PlatformVerification] rows for one execution.
///
/// The signature is deliberately the same as
/// `ExecutionStore.readVerifications` (`packages/execution_coordinator/lib/src/store/execution_store.dart`),
/// so the production implementation is that store behind a one-line adapter.
/// It is declared here rather than reached for directly because
/// `qa_orchestration` does not depend on `execution_coordinator`, and a gate
/// must be evaluable in a test without a database.
///
/// The reader is **bound to one execution**: the store filters by
/// `executionId` in the query itself
/// (`postgres_execution_store.dart` `WHERE "executionId" = @executionId`), so a
/// row belonging to a different execution cannot be returned. That binding is
/// structural and is not part of the gate's configurable surface.
abstract interface class PlatformVerificationReader {
  Future<List<PlatformVerification>> readVerifications(String executionId);
}

/// The feature lane's F4 gate: every declared check ran, under the declared
/// command, and passed.
///
/// ## What this gate refuses that a name-only gate cannot
///
/// The live shape in this repository is a verification row named the same as a
/// declared check but carrying `git rev-parse --verify 'HEAD^{commit}'` — the
/// triage plan's liveness probe, which the coordinator attaches to every role.
/// Matching on `checkName` alone lets that probe satisfy a test declaration.
/// The command is therefore compared **string for string**.
///
/// ## `evidenceKind` is a defensive invariant, not a discriminator
///
/// `PlatformVerification.evidenceKind` defaults to
/// `EvidenceKind.platformVerifiedEvidence` and the production coordinator never
/// sets it, so a persisted row cannot be distinguished from one that took the
/// default. The check below is enforced and tested, but it is **not** counted
/// as an assertion a production path can falsify.
///
/// ## What it does not claim
///
/// It asserts the **per-execution** tier only (decision `a0e6f31c`). The
/// merge/release tier (`make test-integration`) is not part of any
/// `RequireCheckNames` entry this gate can see, and this evaluator has no path
/// that could claim it.
class DeclaredValidationOutcomeGate implements GateEvaluator {
  DeclaredValidationOutcomeGate({required this.verificationReader});

  final PlatformVerificationReader verificationReader;

  @override
  String get gateType => 'declared-validation-outcome';

  @override
  Future<QAGateResult> evaluate(
    String workItemId,
    AgentResult agentResult,
    QAGateDefinition gate,
  ) async {
    final config = _DeclaredValidationConfig.from(gate);
    final evaluatedAt = DateTime.now();
    final executionId = agentResult.executionId;

    // An execution id is how the store addresses the rows. Without it nothing
    // can be read, and "I could not look" is a failure — never an empty pass.
    if (executionId == null || executionId.trim().isEmpty) {
      final reason =
          'the agent result carries no executionId, so no platform '
          'verification rows can be addressed';
      return _result(
        workItemId: workItemId,
        gate: gate,
        executionId: null,
        config: config,
        rows: const [],
        reasons: [reason],
        evaluatedAt: evaluatedAt,
      );
    }

    final rows = await verificationReader.readVerifications(executionId);

    return _result(
      workItemId: workItemId,
      gate: gate,
      executionId: executionId,
      config: config,
      rows: rows,
      reasons: const [],
      evaluatedAt: evaluatedAt,
    );
  }

  QAGateResult _result({
    required String workItemId,
    required QAGateDefinition gate,
    required String? executionId,
    required _DeclaredValidationConfig config,
    required List<PlatformVerification> rows,
    required List<String> reasons,
    required DateTime evaluatedAt,
  }) {
    final failures = <String>[...reasons];
    final evidence = <QAEvidence>[];

    for (final checkName in config.checkNames) {
      final declaredCommand = config.commands[checkName]!;
      final checkRows = rows
          .where((row) => row.checkName == checkName)
          .toList(growable: false);

      final matching = checkRows
          .where(
            (row) =>
                row.command == declaredCommand &&
                row.status == AgentClaimStatus.passed &&
                row.evidenceKind == EvidenceKind.platformVerifiedEvidence,
          )
          .toList(growable: false);

      // A sibling row that reports failure refuses the check even when another
      // row for the same name passed. This is the design's
      // `requireStatusOfEveryOtherRow` defensive invariant: a retry that failed
      // must not be masked by an earlier pass.
      final notPassed = checkRows
          .where((row) => row.status != AgentClaimStatus.passed)
          .toList(growable: false);

      final String? reason;
      if (checkRows.isEmpty) {
        reason =
            'declared check "$checkName" has no platform verification row for '
            'execution ${executionId ?? '<none>'}';
      } else if (notPassed.isNotEmpty) {
        reason =
            'declared check "$checkName" has a row reporting '
            '${notPassed.map((row) => row.status.wire).join(', ')}';
      } else if (matching.isEmpty) {
        reason =
            'declared check "$checkName" has no row whose command '
            '"$declaredCommand" matches exactly and whose evidence is '
            'platform-verified; observed: '
            '${checkRows.map((row) => '"${row.command}"').join(', ')}';
      } else {
        reason = null;
      }

      if (reason != null) failures.add(reason);

      evidence.add(
        QAEvidence(
          evidenceId:
              '${gate.gateId}:$checkName:'
              '${evaluatedAt.microsecondsSinceEpoch}',
          gateId: gate.gateId,
          workItemId: workItemId,
          evidenceType: 'platform_verification',
          artifactRef: 'platform_verification',
          content: <String, dynamic>{
            'checkName': checkName,
            'declaredCommand': declaredCommand,
            'executionId': executionId,
            'observedRowCount': checkRows.length,
            'observedCommands': checkRows
                .map((row) => row.command)
                .toList(growable: false),
            'observedStatuses': checkRows
                .map((row) => row.status.wire)
                .toList(growable: false),
            'observedEvidenceKinds': checkRows
                .map((row) => row.evidenceKind.wire)
                .toList(growable: false),
            'matched': reason == null,
            if (reason != null) 'reason': reason,
          },
          collectedAt: evaluatedAt,
        ),
      );
    }

    final passed = failures.isEmpty;
    return QAGateResult(
      gateId: gate.gateId,
      workItemId: workItemId,
      status: passed ? QAGateStatus.passed : QAGateStatus.failed,
      evidence: evidence,
      evaluatedAt: evaluatedAt,
      passedAt: passed ? evaluatedAt : null,
      metadata: <String, dynamic>{
        'executionId': executionId,
        'requireCheckNames': config.checkNames,
        if (!passed) 'reason': failures.join('; '),
      },
    );
  }
}

/// The declared half of F4, read once and validated.
///
/// Malformed declarations throw [FormatException] naming the gate, matching the
/// existing derivation in `product_qa_contract.dart` and the design's rule that
/// a required key that cannot be read is a refusal rather than a weaker gate.
class _DeclaredValidationConfig {
  const _DeclaredValidationConfig({
    required this.checkNames,
    required this.commands,
  });

  final List<String> checkNames;
  final Map<String, String> commands;

  static _DeclaredValidationConfig from(QAGateDefinition gate) {
    final names = _stringList(gate, 'requireCheckNames');
    if (names.isEmpty) {
      throw FormatException(
        'gate ${gate.gateId} declares an empty "requireCheckNames"; a gate '
        'with no declared check would pass without asserting anything',
      );
    }
    if (names.toSet().length != names.length) {
      throw FormatException(
        'gate ${gate.gateId} declares duplicate names in '
        '"requireCheckNames"',
      );
    }

    final commands = _stringMap(gate, 'requireCommands');
    for (final name in names) {
      final command = commands[name];
      if (command == null || command.trim().isEmpty) {
        throw FormatException(
          'gate ${gate.gateId} declares check "$name" in '
          '"requireCheckNames" but "requireCommands" has no command for it; '
          'the declared command is what makes the check identity meaningful',
        );
      }
    }

    final requireStatus = gate.config['requireStatus'];
    if (requireStatus != AgentClaimStatus.passed.wire) {
      throw FormatException(
        'gate ${gate.gateId} declares "requireStatus" as $requireStatus; the '
        'only supported value is "${AgentClaimStatus.passed.wire}"',
      );
    }

    if (gate.config['commandMatchIsExact'] != true) {
      throw FormatException(
        'gate ${gate.gateId} must declare "commandMatchIsExact": true. A '
        'substring or token-overlap comparison lets a liveness probe satisfy '
        'a declared check, which is the failure this gate exists to refuse',
      );
    }

    return _DeclaredValidationConfig(
      checkNames: List<String>.unmodifiable(names),
      commands: Map<String, String>.unmodifiable(commands),
    );
  }

  static List<String> _stringList(QAGateDefinition gate, String key) {
    if (!gate.config.containsKey(key)) {
      throw FormatException(
        'gate ${gate.gateId} does not declare "$key", which is required',
      );
    }
    final value = gate.config[key];
    if (value is! List) {
      throw FormatException(
        'gate ${gate.gateId} declares "$key" as ${value.runtimeType}; a JSON '
        'array of strings is the only shape that can be read as one',
      );
    }
    return value
        .map((entry) {
          if (entry is! String || entry.trim().isEmpty) {
            throw FormatException(
              'gate ${gate.gateId} declares a non-string or empty entry in '
              '"$key" ($entry)',
            );
          }
          return entry;
        })
        .toList(growable: false);
  }

  static Map<String, String> _stringMap(QAGateDefinition gate, String key) {
    if (!gate.config.containsKey(key)) {
      throw FormatException(
        'gate ${gate.gateId} does not declare "$key", which is required',
      );
    }
    final value = gate.config[key];
    if (value is! Map) {
      throw FormatException(
        'gate ${gate.gateId} declares "$key" as ${value.runtimeType}; a JSON '
        'object of string to string is the only shape that can be read',
      );
    }
    return value.map((rawKey, rawValue) {
      if (rawKey is! String || rawValue is! String) {
        throw FormatException(
          'gate ${gate.gateId} declares a non-string entry in "$key" '
          '($rawKey: $rawValue)',
        );
      }
      return MapEntry(rawKey, rawValue);
    });
  }
}
