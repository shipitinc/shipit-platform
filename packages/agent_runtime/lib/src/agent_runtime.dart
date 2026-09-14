import 'adapters/agent_adapter_registry.dart';
import 'interface/agent_adapter.dart';
import 'interface/agent_session.dart';

class AgentRuntime {
  AgentRuntime({AgentAdapterRegistry? registry})
    : _registry = registry ?? agentAdapterRegistry;

  final AgentAdapterRegistry _registry;

  Future<AgentSession> startSession({
    required String providerId,
    required AgentSessionConfig config,
  }) async {
    final adapter = _registry.get(providerId);
    if (adapter == null) {
      throw AgentAdapterNotFoundException(providerId);
    }
    return adapter.createSession(config);
  }

  Future<AgentSession> resumeSession({
    required String providerId,
    required AgentSessionConfig config,
  }) async {
    final adapter = _registry.get(providerId);
    if (adapter == null) {
      throw AgentAdapterNotFoundException(providerId);
    }
    return adapter.resumeSession(config);
  }

  List<AgentAdapter> get availableAdapters => _registry.all;

  List<String> get availableProviderIds => _registry.providerIds;
}

class AgentAdapterNotFoundException implements Exception {
  const AgentAdapterNotFoundException(this.providerId);
  final String providerId;

  @override
  String toString() => 'Agent adapter not found: $providerId';
}
