import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';

@immutable
class CapabilitySpec {
  const CapabilitySpec({
    required this.capability,
    required this.version,
    this.metadata,
    this.providedTools,
  });

  final WorkerCapability capability;
  final String version;
  final Map<String, String>? metadata;
  final List<String>? providedTools;
}
