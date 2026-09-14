import 'package:meta/meta.dart';

/// Provider-neutral capability tokens advertised by an agent runtime. These
/// are shared vocabulary between the coordinator and runtimes; they say nothing
/// about workflow policy.
enum RuntimeCapability {
  readFiles('read_files'),
  modifyFiles('modify_files'),
  runShell('run_shell'),
  runTests('run_tests'),
  gitOperations('git_operations'),
  networkAccess('network_access'),
  resumeSession('resume_session'),
  cancellable('cancellable');

  const RuntimeCapability(this.wire);

  final String wire;

  static RuntimeCapability fromWire(String value) => values.firstWhere(
    (capability) => capability.wire == value,
    orElse: () => throw FormatException('Unknown runtime capability: $value'),
  );
}

/// Immutable set of capabilities a runtime supports.
@immutable
class RuntimeCapabilities {
  const RuntimeCapabilities({required this.supported});

  const RuntimeCapabilities.none() : supported = const {};

  final Set<RuntimeCapability> supported;

  bool supports(RuntimeCapability capability) => supported.contains(capability);

  RuntimeCapabilities withCapability(RuntimeCapability capability) =>
      RuntimeCapabilities(supported: {...supported, capability});

  @override
  bool operator ==(Object other) =>
      other is RuntimeCapabilities &&
      other.supported.length == supported.length &&
      other.supported.containsAll(supported);

  @override
  int get hashCode => Object.hashAll(
    supported.toList()..sort((a, b) => a.name.compareTo(b.name)),
  );

  @override
  String toString() => 'RuntimeCapabilities(${supported.map((c) => c.wire)})';
}
