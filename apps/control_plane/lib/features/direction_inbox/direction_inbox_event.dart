abstract class DirectionInboxEvent {
  const DirectionInboxEvent();
}

class DirectionInboxLoaded extends DirectionInboxEvent {
  const DirectionInboxLoaded({this.status, this.targetType, this.limit});

  final String? status;
  final String? targetType;
  final int? limit;
}

class DirectionInboxCreateRequested extends DirectionInboxEvent {
  const DirectionInboxCreateRequested({
    required this.directionType,
    required this.targetType,
    this.targetId,
    required this.title,
    required this.description,
    this.contextJson,
    this.attachments,
    this.createdBy,
    this.assignedTo,
  });

  final String directionType;
  final String targetType;
  final String? targetId;
  final String title;
  final String description;
  final String? contextJson;
  final List<Map<String, dynamic>>? attachments;
  final String? createdBy;
  final String? assignedTo;
}

class DirectionInboxActionRequested extends DirectionInboxEvent {
  const DirectionInboxActionRequested({
    required this.directionId,
    required this.action,
    this.actor,
    this.completionSummary,
    this.rejectionReason,
    this.supersededByDirectionId,
  });

  final String directionId;
  final DirectionAction action;
  final String? actor;
  final String? completionSummary;
  final String? rejectionReason;
  final String? supersededByDirectionId;
}

enum DirectionAction { acknowledge, startWorking, complete, reject, supersede }

class DirectionInboxStatusFilterChanged extends DirectionInboxEvent {
  const DirectionInboxStatusFilterChanged(this.status);
  final String? status;
}

class DirectionInboxTargetTypeFilterChanged extends DirectionInboxEvent {
  const DirectionInboxTargetTypeFilterChanged(this.targetType);
  final String? targetType;
}

class DirectionInboxRefreshRequested extends DirectionInboxEvent {
  const DirectionInboxRefreshRequested();
}
