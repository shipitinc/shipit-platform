import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';

enum PromotionGate { auto, human, schedule, metric }

@immutable
class PromotionRule {
  const PromotionRule({
    required this.fromEnvironment,
    required this.toEnvironment,
    required this.gate,
    this.config,
  });

  final String fromEnvironment;
  final String toEnvironment;
  final PromotionGate gate;
  final Map<String, dynamic>? config;
}

@immutable
class DeploymentRecord {
  const DeploymentRecord({
    required this.recordId,
    required this.artifactId,
    required this.targetId,
    required this.environment,
    required this.status,
    required this.deployedAt,
    this.completedAt,
    this.metadata,
  });

  final String recordId;
  final String artifactId;
  final String targetId;
  final String environment;
  final DeploymentStatus status;
  final DateTime deployedAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? metadata;
}

class PromotionEngine {
  const PromotionEngine();

  PromotionResult evaluate(
    DeploymentArtifact artifact,
    List<PromotionRule> rules,
    Map<String, DeploymentRecord> currentDeployments,
  ) {
    final applicableRules = rules.where((r) {
      final current = currentDeployments[r.fromEnvironment];
      return current?.status == DeploymentStatus.healthy;
    }).toList();

    if (applicableRules.isEmpty) {
      return PromotionResult(
        canPromote: false,
        reason: 'No applicable promotion rules',
        nextEnvironment: null,
        requiredGate: null,
      );
    }

    final nextRule = applicableRules.first;

    return PromotionResult(
      canPromote: true,
      reason: 'Promotion path available',
      nextEnvironment: nextRule.toEnvironment,
      requiredGate: nextRule.gate,
    );
  }
}

@immutable
class PromotionResult {
  const PromotionResult({
    required this.canPromote,
    required this.reason,
    this.nextEnvironment,
    this.requiredGate,
  });

  final bool canPromote;
  final String reason;
  final String? nextEnvironment;
  final PromotionGate? requiredGate;
}

@immutable
class PromotionRecord {
  const PromotionRecord({
    required this.recordId,
    required this.artifactId,
    required this.fromEnvironment,
    required this.toEnvironment,
    required this.gate,
    required this.status,
    required this.initiatedAt,
    this.completedAt,
    this.humanDecisionId,
    this.metadata,
  });

  final String recordId;
  final String artifactId;
  final String fromEnvironment;
  final String toEnvironment;
  final PromotionGate gate;
  final PromotionStatus status;
  final DateTime initiatedAt;
  final DateTime? completedAt;
  final String? humanDecisionId;
  final Map<String, dynamic>? metadata;
}

enum PromotionStatus { pending, inProgress, completed, failed, blocked }
