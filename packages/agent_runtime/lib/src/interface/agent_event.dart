import 'package:platform_contracts/platform_contracts.dart';

sealed class AgentEvent {
  const AgentEvent();

  String get eventId;
  DateTime get timestamp;
}

class SessionStarted extends AgentEvent {
  const SessionStarted({
    required this.eventId,
    required this.timestamp,
    required this.sessionId,
    required this.workItemId,
  });

  @override
  final String eventId;
  @override
  final DateTime timestamp;
  final String sessionId;
  final String workItemId;
}

class InstructionSent extends AgentEvent {
  const InstructionSent({
    required this.eventId,
    required this.timestamp,
    required this.instructionId,
    required this.content,
  });

  @override
  final String eventId;
  @override
  final DateTime timestamp;
  final String instructionId;
  final String content;
}

class ToolCallStarted extends AgentEvent {
  const ToolCallStarted({
    required this.eventId,
    required this.timestamp,
    required this.toolCallId,
    required this.tool,
    required this.arguments,
  });

  @override
  final String eventId;
  @override
  final DateTime timestamp;
  final String toolCallId;
  final String tool;
  final Map<String, dynamic> arguments;
}

class ToolCallCompleted extends AgentEvent {
  const ToolCallCompleted({
    required this.eventId,
    required this.timestamp,
    required this.toolCallId,
    required this.result,
  });

  @override
  final String eventId;
  @override
  final DateTime timestamp;
  final String toolCallId;
  final Map<String, dynamic> result;
}

class ToolCallFailed extends AgentEvent {
  const ToolCallFailed({
    required this.eventId,
    required this.timestamp,
    required this.toolCallId,
    required this.error,
  });

  @override
  final String eventId;
  @override
  final DateTime timestamp;
  final String toolCallId;
  final String error;
}

class ArtifactProduced extends AgentEvent {
  const ArtifactProduced({
    required this.eventId,
    required this.timestamp,
    required this.artifactId,
    required this.type,
    required this.path,
  });

  @override
  final String eventId;
  @override
  final DateTime timestamp;
  final String artifactId;
  final String type;
  final String path;
}

class LogLine extends AgentEvent {
  const LogLine({
    required this.eventId,
    required this.timestamp,
    required this.level,
    required this.message,
    this.context,
  });

  @override
  final String eventId;
  @override
  final DateTime timestamp;
  final String level;
  final String message;
  final Map<String, dynamic>? context;
}

class ProgressUpdate extends AgentEvent {
  const ProgressUpdate({
    required this.eventId,
    required this.timestamp,
    required this.percentage,
    required this.description,
  });

  @override
  final String eventId;
  @override
  final DateTime timestamp;
  final int percentage;
  final String description;
}

class SessionCompleted extends AgentEvent {
  const SessionCompleted({
    required this.eventId,
    required this.timestamp,
    required this.result,
  });

  @override
  final String eventId;
  @override
  final DateTime timestamp;
  final AgentResult result;
}

class SessionFailed extends AgentEvent {
  const SessionFailed({
    required this.eventId,
    required this.timestamp,
    required this.error,
    required this.recoverable,
  });

  @override
  final String eventId;
  @override
  final DateTime timestamp;
  final String error;
  final bool recoverable;
}

class SessionCancelled extends AgentEvent {
  const SessionCancelled({
    required this.eventId,
    required this.timestamp,
    required this.reason,
  });

  @override
  final String eventId;
  @override
  final DateTime timestamp;
  final String reason;
}
