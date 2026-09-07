import '../states/workflow_state.dart';

class Transition<T> {
  const Transition({
    required this.from,
    required this.to,
    required this.trigger,
    this.guardResults,
    this.metadata,
  });

  final WorkflowState<T> from;
  final WorkflowState<T> to;
  final TransitionTrigger trigger;
  final List<GuardResult>? guardResults;
  final Map<String, dynamic>? metadata;

  bool get isValid => guardResults?.every((g) => g.passed) ?? true;

  List<String> get failedGuards =>
      guardResults?.where((g) => !g.passed).map((g) => g.name).toList() ?? [];
}

enum TransitionTrigger {
  humanDecision,
  agentResult,
  systemEvent,
  timer,
  manual,
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
    TransitionTrigger trigger, {
    required List<GuardCondition<T>> guards,
    Map<String, dynamic>? metadata,
  }) {
    final guardResults = <GuardResult>[];

    for (final guard in guards) {
      final result = guard.evaluate(from, to, metadata);
      guardResults.add(result);
    }

    final transition = Transition<T>(
      from: from,
      to: to,
      trigger: trigger,
      guardResults: guardResults,
      metadata: metadata,
    );

    if (!transition.isValid) {
      throw InvalidTransitionException(transition);
    }

    return transition;
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

class InvalidTransitionException implements Exception {
  const InvalidTransitionException(this.transition);

  final Transition<dynamic> transition;

  @override
  String toString() =>
      'Invalid transition: ${transition.from.value} -> ${transition.to.value}. Failed guards: ${transition.failedGuards.join(', ')}';
}
