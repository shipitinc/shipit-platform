enum HumanDirectionType {
  question('question'),
  directive('directive'),
  workIntake('work_intake'),
  bugReport('bug_report'),
  clarification('clarification');

  const HumanDirectionType(this.wire);

  final String wire;

  static HumanDirectionType fromWire(String value) => values.firstWhere(
    (type) => type.wire == value,
    orElse: () => throw FormatException('Unknown human direction type: $value'),
  );
}

enum HumanDirectionTargetType {
  product('product'),
  workItem('work_item'),
  run('run'),
  execution('execution'),
  job('job'),
  none('none');

  const HumanDirectionTargetType(this.wire);

  final String wire;

  static HumanDirectionTargetType fromWire(String value) => values.firstWhere(
    (type) => type.wire == value,
    orElse: () =>
        throw FormatException('Unknown human direction target type: $value'),
  );
}

enum HumanDirectionStatus {
  created('created'),
  acked('acked'),
  working('working'),
  completed('completed'),
  rejected('rejected'),
  superseded('superseded');

  const HumanDirectionStatus(this.wire);

  final String wire;

  bool get isTerminal =>
      this == HumanDirectionStatus.completed ||
      this == HumanDirectionStatus.rejected ||
      this == HumanDirectionStatus.superseded;

  bool get isActive =>
      this == HumanDirectionStatus.created ||
      this == HumanDirectionStatus.acked ||
      this == HumanDirectionStatus.working;

  static HumanDirectionStatus fromWire(String value) => values.firstWhere(
    (status) => status.wire == value,
    orElse: () =>
        throw FormatException('Unknown human direction status: $value'),
  );
}
