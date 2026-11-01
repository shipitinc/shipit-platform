import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'support/git_repo_fixture.dart';

/// The provider-dead signature and the marker it produces.
///
/// Automatic paid-model escalation lives or dies on this distinction: a
/// session that died on the PROVIDER (quota, outage — zero work produced, or
/// a provider error the runtime itself reported) escalates; a session that
/// ran and hung does not, because retrying real work on the paid tier is
/// wasted money.
void main() {
  AgentResult agentResult({
    int toolCalls = 0,
    Map<String, dynamic>? metadata,
  }) => AgentResult(
    resultId: 'r-1',
    sessionId: 'ses-1',
    workItemId: 'wi-1',
    status: AgentResultStatus.partial,
    artifacts: const [],
    diagnostics: AgentDiagnostics(
      exitCode: 1,
      durationMs: 1,
      toolCalls: toolCalls,
      errors: const [],
      warnings: const [],
    ),
    structuredResult: const {},
    completedAt: DateTime.now().toUtc(),
    metadata: metadata,
  );

  Map<String, dynamic> zeroActivity() => {
    'chunkCount': 0,
    'usage': {'used': 0, 'size': 0, 'cost': 0},
    'runtimeAnswered': false,
  };

  group('providerFailureEvidence', () {
    test('a null result is no evidence and never escalates', () {
      expect(providerFailureEvidence(null), isNull);
    });

    test('a classified providerError is positive evidence', () {
      final evidence = providerFailureEvidence(
        agentResult(
          toolCalls: 3,
          metadata: {
            'providerError': {
              'type': 'creditExhausted',
              'provider': 'opencode',
              'message': 'Free usage limit reached',
            },
            'chunkCount': 4,
          },
        ),
      );
      expect(evidence, contains('provider error'));
      expect(evidence, contains('creditExhausted'));
    });

    test('an unclassified (`unknown`) providerError is NOT evidence', () {
      expect(
        providerFailureEvidence(
          agentResult(
            toolCalls: 2,
            metadata: {
              'providerError': {
                'type': 'unknown',
                'provider': 'opencode',
                'message': 'something failed',
              },
              'chunkCount': 2,
            },
          ),
        ),
        isNull,
        reason:
            'the session stamps `unknown` on every transport failure; '
            'treating it as evidence would escalate every wire hiccup.',
      );
    });

    test('zero output of every kind is the provider-dead signature', () {
      expect(
        providerFailureEvidence(agentResult(metadata: zeroActivity())),
        isNotNull,
      );
    });

    test('a session that produced ANY output is not provider-dead', () {
      for (final metadata in [
        {...zeroActivity(), 'chunkCount': 2},
        {
          'chunkCount': 0,
          'usage': {'used': 12, 'size': 4096, 'cost': 0},
        },
      ]) {
        expect(
          providerFailureEvidence(agentResult(metadata: metadata)),
          isNull,
        );
      }
      // A tool call alone is activity.
      expect(
        providerFailureEvidence(
          agentResult(toolCalls: 1, metadata: zeroActivity()),
        ),
        isNull,
      );
    });
  });

  group('isProviderFailureDetail', () {
    test('matches the marker wherever it sits in the detail', () {
      expect(
        isProviderFailureDetail(
          'agent session timed out; '
          '${providerFailureMarker}the runtime emitted no output',
        ),
        isTrue,
      );
      expect(isProviderFailureDetail('agent session timed out'), isFalse);
      expect(isProviderFailureDetail(null), isFalse);
    });
  });

  group('LocalWorker stamps the marker on the terminal detail', () {
    late Directory temp;
    late GitRepoFixture repo;
    late InMemoryWorkerStore workerStore;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('provider_failure_test');
      repo = GitRepoFixture.create(temp.path);
      workerStore = InMemoryWorkerStore();
    });

    tearDown(() {
      repo.dispose();
      temp.deleteSync(recursive: true);
    });

    Future<WorkerExecutionResult> runWorker(AgentExecutionDriver driver) async {
      final worker = LocalWorker(
        workerId: 'w-test',
        poolId: 'test-pool',
        capabilities: const {WorkerCapability.linux},
        workspaceManager: GitWorktreeWorkspaceManager(
          workspaceRoot: '${temp.path}/workspaces',
        ),
        executionDriver: driver,
        workerStore: workerStore,
      );
      await worker.acquire();
      return worker.run(
        WorkerExecutionRequest(
          workerExecutionId: 'wx-pf',
          workItemId: 'wi-1',
          repositoryPath: repo.root.path,
          startingRevision: repo.startingRevision,
          requiredCapabilities: const {},
          role: AgentRole.implementer,
          instruction: 'do work',
          timeoutSeconds: 60,
          runtimeTypeId: 'fake-runtime',
        ),
      );
    }

    test('an interrupted session with a provider-dead result carries the '
        'marker', () async {
      final result = await runWorker(
        _InterruptedDriver(
          result: agentResult(
            metadata: {
              'providerError': {
                'type': 'creditExhausted',
                'provider': 'opencode',
                'message': 'Free usage limit reached',
              },
              'chunkCount': 0,
              'usage': {'used': 0, 'size': 0, 'cost': 0},
            },
          ),
        ),
      );
      expect(result.status, WorkerExecutionStatus.timedOut);
      expect(result.failureDetail, contains(providerFailureMarker));
      expect(isProviderFailureDetail(result.failureDetail), isTrue);
    });

    test('an interrupted session that produced output stays a plain '
        'timeout', () async {
      final result = await runWorker(
        _InterruptedDriver(
          result: agentResult(
            toolCalls: 2,
            metadata: {
              'chunkCount': 5,
              'usage': {'used': 100, 'size': 4096, 'cost': 0},
            },
          ),
        ),
      );
      expect(result.status, WorkerExecutionStatus.timedOut);
      expect(result.failureDetail, 'agent session timed out');
      expect(isProviderFailureDetail(result.failureDetail), isFalse);
    });

    test('a driver that cannot read results stays a plain timeout', () async {
      final result = await runWorker(_PlainInterruptedDriver());
      expect(result.status, WorkerExecutionStatus.timedOut);
      expect(result.failureDetail, 'agent session timed out');
    });
  });
}

/// An interrupted session whose persisted result is readable — the shape the
/// real coordinator produces for a budget-expiry settle.
class _InterruptedDriver implements AgentExecutionDriver, AgentResultReader {
  _InterruptedDriver({required this.result});

  final AgentResult result;

  @override
  Future<AgentExecution> execute(AgentExecutionRequest request) async {
    final now = DateTime.now().toUtc();
    return AgentExecution(
      executionId: request.executionId,
      workItemId: request.workItemId,
      requestId: request.executionId,
      runtimeTypeId: request.runtimeTypeId,
      role: request.role,
      status: AgentSessionStatus.interrupted,
      workspace: request.workspace,
      startedAt: now,
      completedAt: now,
    );
  }

  @override
  Future<AgentResult?> resultFor(String executionId) async => result;

  @override
  Future<AgentExecution> cancel(String executionId, String reason) async =>
      throw UnimplementedError();

  @override
  Future<List<PlatformVerification>> verificationsFor(
    String executionId,
  ) async => const [];
}

/// An interrupted session whose driver cannot read results at all.
class _PlainInterruptedDriver implements AgentExecutionDriver {
  @override
  Future<AgentExecution> execute(AgentExecutionRequest request) async {
    final now = DateTime.now().toUtc();
    return AgentExecution(
      executionId: request.executionId,
      workItemId: request.workItemId,
      requestId: request.executionId,
      runtimeTypeId: request.runtimeTypeId,
      role: request.role,
      status: AgentSessionStatus.interrupted,
      workspace: request.workspace,
      startedAt: now,
      completedAt: now,
    );
  }

  @override
  Future<AgentExecution> cancel(String executionId, String reason) async =>
      throw UnimplementedError();

  @override
  Future<List<PlatformVerification>> verificationsFor(
    String executionId,
  ) async => const [];
}
