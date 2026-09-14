enum AgentEventType {
  executionStarted('execution_started'),
  message('message'),
  toolStarted('tool_started'),
  toolCompleted('tool_completed'),
  toolFailed('tool_failed'),
  artifactProduced('artifact_produced'),
  warning('warning'),
  executionCompleted('execution_completed'),
  executionFailed('execution_failed'),
  executionCancelled('execution_cancelled');

  const AgentEventType(this.wire);

  final String wire;

  static AgentEventType fromWire(String value) => values.firstWhere(
    (type) => type.wire == value,
    orElse: () => throw FormatException('Unknown agent event type: $value'),
  );
}
