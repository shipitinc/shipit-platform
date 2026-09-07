import 'package:meta/meta.dart';

@immutable
class AgentInstruction {
  const AgentInstruction({
    required this.instructionId,
    required this.content,
    this.context,
  });

  final String instructionId;
  final String content;
  final Map<String, dynamic>? context;
}
