import '../interface/agent_adapter.dart';
import '../interface/agent_capability.dart';
import '../interface/agent_session.dart';
import 'opencode/opencode_session.dart';

class DesignAgentAdapter implements AgentAdapter {
  DesignAgentAdapter({AcpTransportFactory? transportFactory})
    : _transportFactory = transportFactory ?? defaultAcpTransport;

  final AcpTransportFactory _transportFactory;

  @override
  final String providerId = 'opencode-design-agent';

  @override
  final String displayName = 'OpenCode Design Agent';

  @override
  final RuntimeCapabilities capabilities = const RuntimeCapabilities(
    supported: {
      RuntimeCapability.readFiles,
      RuntimeCapability.modifyFiles,
      RuntimeCapability.runShell,
      RuntimeCapability.networkAccess,
      RuntimeCapability.resumeSession,
      RuntimeCapability.cancellable,
    },
  );

  @override
  Future<AgentSession> createSession(AgentSessionConfig config) async {
    final session = DesignAgentSession(
      executionId: config.executionId,
      workItemId: config.workItemId,
      transportFactory: _transportFactory,
    );
    await session.start(config);
    return session;
  }

  @override
  Future<AgentSession> resumeSession(AgentSessionConfig config) async {
    final session = DesignAgentSession(
      executionId: config.executionId,
      workItemId: config.workItemId,
      transportFactory: _transportFactory,
    );
    await session.start(config);
    return session;
  }

  @override
  Future<bool> canResume(String sessionId) async {
    return capabilities.supports(RuntimeCapability.resumeSession);
  }

  @override
  Future<AdapterHealth> checkHealth() async {
    try {
      final probe = await _transportFactory(
        AgentSessionConfig(
          executionId: 'health-check',
          workItemId: 'health-check',
          workingDirectory: '/tmp',
        ),
      );
      final result = await probe.initialize();
      final agentInfo = result.agentInfo;
      await probe.close();
      return AdapterHealth(
        healthy: true,
        version: (agentInfo['version'] as String?) ?? 'unknown',
        details: {'agentName': agentInfo['name']},
      );
    } catch (e) {
      return AdapterHealth(healthy: false, details: {'error': e.toString()});
    }
  }

  @override
  Future<void> shutdown() async {}
}

class DesignAgentSession extends OpenCodeSession {
  DesignAgentSession({
    required String executionId,
    required String workItemId,
    AcpTransportFactory? transportFactory,
  }) : super(
    executionId: executionId,
    workItemId: workItemId,
    transportFactory: transportFactory,
  );
}