import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';

void main() {
  const request = WorkerExecutionRequest(
    workerExecutionId: 'wx-1',
    workItemId: 'wi-1',
    repositoryPath: '/repo',
    startingRevision: 'abc',
    requiredCapabilities: {WorkerCapability.linux},
    role: AgentRole.implementer,
    instruction: 'x',
    timeoutSeconds: 60,
    runtimeTypeId: 'fake',
    envAllowlist: ['ALLOWED_HOST', 'REQUEST_LISTED'],
    environment: {
      'SHIPIT_FIXED': 'request-value',
      'SHIPIT_REQUEST': 'from-request',
    },
  );

  test('EnvironmentPolicy precedence: host allowlist < request < policy', () {
    const policy = EnvironmentPolicy(
      inheritAllowlist: ['ALLOWED_HOST'],
      explicit: {'SHIPIT_FIXED': 'policy-wins'},
    );

    final resolved = policy.resolve(
      request,
      hostEnv: const {
        'ALLOWED_HOST': 'inherit-ok',
        'REQUEST_LISTED': 'also-ok',
        'NOT_ALLOWED': 'must-not-leak',
      },
    );

    expect(resolved, {
      'ALLOWED_HOST': 'inherit-ok',
      'REQUEST_LISTED': 'also-ok',
      'SHIPIT_FIXED': 'policy-wins',
      'SHIPIT_REQUEST': 'from-request',
    });
    expect(resolved.containsKey('NOT_ALLOWED'), isFalse);
  });

  test('EnvironmentPolicy never inherits unwitting secrets', () {
    const policy = EnvironmentPolicy();
    final resolved = policy.resolve(
      const WorkerExecutionRequest(
        workerExecutionId: 'wx-2',
        workItemId: 'wi-1',
        repositoryPath: '/repo',
        startingRevision: 'abc',
        requiredCapabilities: {WorkerCapability.linux},
        role: AgentRole.implementer,
        instruction: 'x',
        timeoutSeconds: 60,
        runtimeTypeId: 'fake',
      ),
      hostEnv: const {
        'AWS_SECRET_ACCESS_KEY': 'sk-leak',
        'GITHUB_TOKEN': 'ghp-leak',
        'PATH': '/usr/bin',
      },
    );

    expect(resolved, isEmpty);
  });

  test('EnvironmentPolicy explicit values always apply', () {
    const policy = EnvironmentPolicy(explicit: {'SHIPIT_POOL': 'linux-a'});
    final resolved = policy.resolve(
      const WorkerExecutionRequest(
        workerExecutionId: 'wx-3',
        workItemId: 'wi-1',
        repositoryPath: '/repo',
        startingRevision: 'abc',
        requiredCapabilities: {WorkerCapability.linux},
        role: AgentRole.implementer,
        instruction: 'x',
        timeoutSeconds: 60,
        runtimeTypeId: 'fake',
      ),
    );

    expect(resolved, {'SHIPIT_POOL': 'linux-a'});
  });
}
