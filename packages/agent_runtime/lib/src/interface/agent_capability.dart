import 'package:meta/meta.dart';

@immutable
class AgentCapability {
  const AgentCapability({
    required this.name,
    required this.description,
    this.supported = true,
  });

  final String name;
  final String description;
  final bool supported;
}
