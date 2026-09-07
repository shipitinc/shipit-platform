import '../interface/agent_adapter.dart';

class AgentAdapterRegistry {
  final Map<String, AgentAdapter> _adapters = {};

  void register(AgentAdapter adapter) {
    _adapters[adapter.providerId] = adapter;
  }

  AgentAdapter? get(String providerId) {
    return _adapters[providerId];
  }

  List<AgentAdapter> get all => _adapters.values.toList();

  List<String> get providerIds => _adapters.keys.toList();

  bool has(String providerId) => _adapters.containsKey(providerId);
}

final agentAdapterRegistry = AgentAdapterRegistry();
