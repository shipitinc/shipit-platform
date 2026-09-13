import 'package:platform_contracts/platform_contracts.dart';

import '../states/workflow_state.dart';

/// Result of a validated transition attempt.
///
/// A transition is never rejected by throwing; policy rejections are returned
/// as a [Transition] whose [Transition.isValid] is false. The first failed
/// guard is reported via [Transition.rejectionReason].
class Transition<T> {
  const Transition({
    required this.from,
    required this.to,
    required this.trigger,
    required this.actor,
    this.guardResults = const [],
    this.decisionId,
    this.metadata,
  });

  final WorkflowState<T> from;
  final WorkflowState<T> to;
  final TransitionTrigger trigger;
  final WorkflowActor actor;
  final List<GuardResult> guardResults;
  final String? decisionId;
  final Map<String, dynamic>? metadata;

  bool get isValid => guardResults.every((g) => g.passed);

  List<String> get failedGuards =>
      guardResults.where((g) => !g.passed).map((g) => g.name).toList();

  String? get rejectionReason {
    for (final guard in guardResults) {
      if (!guard.passed) {
        return guard.message ??
            'Guard "${guard.name}" failed for '
                '${from.value} -> ${to.value}';
      }
    }
    return null;
  }
}

class GuardResult {
  const GuardResult({required this.name, required this.passed, this.message});

  final String name;
  final bool passed;
  final String? message;

  static GuardResult pass(String name) => GuardResult(name: name, passed: true);
  static GuardResult fail(String name, String message) =>
      GuardResult(name: name, passed: false, message: message);
}

class TransitionValidator {
  const TransitionValidator();

  Transition<T> validate<T>(
    WorkflowState<T> from,
    WorkflowState<T> to,
    TransitionTrigger trigger,
    WorkflowActor actor, {
    required List<GuardCondition<T>> guards,
    Map<String, dynamic>? metadata,
    String? decisionId,
  }) {
    final ctx = {if (metadata != null) ...metadata, 'actor': actor};

    final guardResults = <GuardResult>[
      for (final guard in guards) guard.evaluate(from, to, ctx),
    ];

    return Transition<T>(
      from: from,
      to: to,
      trigger: trigger,
      actor: actor,
      guardResults: guardResults,
      decisionId: decisionId,
      metadata: ctx,
    );
  }
}

abstract class GuardCondition<T> {
  String get name;

  GuardResult evaluate(
    WorkflowState<T> from,
    WorkflowState<T> to,
    Map<String, dynamic>? context,
  );
}
