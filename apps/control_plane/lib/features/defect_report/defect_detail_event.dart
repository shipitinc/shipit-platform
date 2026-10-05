sealed class DefectDetailEvent {}

class DefectDetailLoaded extends DefectDetailEvent {
  DefectDetailLoaded();
}

class DefectDetailRefreshed extends DefectDetailEvent {
  DefectDetailRefreshed();
}

class DefectDetailEvidenceAdded extends DefectDetailEvent {
  DefectDetailEvidenceAdded({
    required this.kind,
    this.description,
    this.artifactId,
  });

  final String kind;
  final String? description;
  final String? artifactId;
}

class DefectDetailClarificationAnswered extends DefectDetailEvent {
  DefectDetailClarificationAnswered({
    required this.clarificationId,
    required this.answer,
    required this.answeredBy,
  });

  final String clarificationId;
  final String answer;
  final String answeredBy;
}

class DefectDetailFixVerified extends DefectDetailEvent {
  DefectDetailFixVerified({
    required this.choice,
    this.rationale,
    required this.decider,
    required this.signature,
    required this.publicKey,
    required this.algorithm,
    required this.signedAt,
  });

  final String choice; // fixed, stillBroken, partiallyFixed
  final String? rationale;
  final String decider;
  final String signature;
  final String publicKey;
  final String algorithm;
  final DateTime signedAt;
}
