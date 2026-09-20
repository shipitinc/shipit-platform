sealed class DecisionDetailEvent {}

class DecisionDetailLoaded extends DecisionDetailEvent {}

class DecisionChoiceSelected extends DecisionDetailEvent {
  DecisionChoiceSelected({required this.choice});
  final String choice;
}

class DecisionRationaleChanged extends DecisionDetailEvent {
  DecisionRationaleChanged({required this.rationale});
  final String rationale;
}

class DecisionSubmitted extends DecisionDetailEvent {}
