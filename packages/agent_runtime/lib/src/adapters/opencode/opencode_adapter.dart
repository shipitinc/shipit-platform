import '../../interface/agent_adapter.dart';
import '../../interface/agent_capability.dart';
import '../../interface/agent_session.dart';
import 'opencode_session.dart';

class OpencodeAdapter implements AgentAdapter {
  OpencodeAdapter({AcpTransportFactory? transportFactory})
    : _transportFactory = transportFactory ?? defaultAcpTransport;

  final AcpTransportFactory _transportFactory;

  @override
  final String providerId = 'opencode';

  @override
  final String displayName = 'OpenCode ACP';

  @override
  final RuntimeCapabilities capabilities = const RuntimeCapabilities(
    supported: {
      RuntimeCapability.readFiles,
      RuntimeCapability.modifyFiles,
      RuntimeCapability.runShell,
      RuntimeCapability.runTests,
      RuntimeCapability.gitOperations,
      RuntimeCapability.resumeSession,
      RuntimeCapability.cancellable,
    },
  );

  @override
  Future<AgentSession> createSession(AgentSessionConfig config) async {
    final session = OpenCodeSession(
      executionId: config.executionId,
      workItemId: config.workItemId,
      transportFactory: _transportFactory,
    );
    await session.start(config);
    return session;
  }

  @override
  Future<AgentSession> resumeSession(AgentSessionConfig config) async {
    final session = OpenCodeSession(
      executionId: config.executionId,
      workItemId: config.workItemId,
      transportFactory: _transportFactory,
    );
    await session.start(config);
    return session;
  }

  @override
  Future<bool> canResume(String sessionId) async {
    // The runtime advertises ACP session resume in initialize; establishing it
    // requires a live transport. This slice resolves platform orphans at the
    // execution level, so resume capability is reported rather than probed.
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
  Future<void> shutdown() async {
    // The adapter holds no long-lived transport; sessions own their processes.
  }
}
