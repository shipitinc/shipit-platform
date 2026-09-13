enum TransitionTrigger {
  humanDecision('human_decision'),
  agentResult('agent_result'),
  systemEvent('system_event'),
  timer('timer'),
  manual('manual');

  const TransitionTrigger(this.wire);

  final String wire;

  static TransitionTrigger fromWire(String value) => values.firstWhere(
    (trigger) => trigger.wire == value,
    orElse: () => throw FormatException('Unknown transition trigger: $value'),
  );
}
