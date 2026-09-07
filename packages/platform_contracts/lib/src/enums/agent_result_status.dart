enum AgentResultStatus {
  completed('completed'),
  failed('failed'),
  cancelled('cancelled'),
  partial('partial');

  const AgentResultStatus(this.wire);

  final String wire;

  static AgentResultStatus fromWire(String value) => values.firstWhere(
    (status) => status.wire == value,
    orElse: () => throw FormatException('Unknown agent result status: $value'),
  );
}
