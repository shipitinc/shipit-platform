import 'dart:io';

import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

AgentExecutionRequest sampleRequest(String executionId) {
  return AgentExecutionRequest(
    executionId: executionId,
    workItemId: 'wi-1',
    role: AgentRole.implementer,
    runtimeTypeId: 'fake-runtime',
    workspace: AgentWorkspace(workspaceId: 'ws-1', path: '/tmp/ws'),
    instruction: 'implement add',
    timeoutSeconds: 60,
  );
}

AgentExecution sampleExecution(String executionId, AgentSessionStatus status) {
  return AgentExecution(
    executionId: executionId,
    workItemId: 'wi-1',
    requestId: executionId,
    runtimeTypeId: 'fake-runtime',
    role: AgentRole.implementer,
    status: status,
    workspace: AgentWorkspace(workspaceId: 'ws-1', path: '/tmp/ws'),
  );
}

void main() {
  group('InMemoryExecutionStore', () {
    test(
      'round-trips requests, executions, events, results, verifications',
      () async {
        final store = InMemoryExecutionStore();
        await store.saveRequest(sampleRequest('exec-1'));
        expect((await store.readRequest('exec-1'))?.executionId, 'exec-1');

        await store.saveExecution(
          sampleExecution('exec-1', AgentSessionStatus.running),
        );
        final execution = await store.readExecution('exec-1');
        expect(execution.status, AgentSessionStatus.running);
        expect(await store.latestExecutionForWorkItem('wi-1'), isNotNull);

        final verification = PlatformVerification(
          verificationId: 'ver-1',
          executionId: 'exec-1',
          workItemId: 'wi-1',
          checkName: 'dart_test',
          status: AgentClaimStatus.passed,
          mechanism: 'process_dart',
          command: 'dart test',
          capturedAt: DateTime.utc(2026, 1, 1),
        );
        await store.saveVerification(verification);
        expect(
          (await store.readVerifications('exec-1')).single.verificationId,
          'ver-1',
        );
      },
    );

    test('enforces compare-and-swap on execution version', () async {
      final store = InMemoryExecutionStore();
      await store.saveExecution(
        sampleExecution('exec-2', AgentSessionStatus.starting),
      );
      await expectLater(
        store.saveExecution(
          sampleExecution('exec-2', AgentSessionStatus.running),
          expectedVersion: 5,
        ),
        throwsA(isA<ConcurrentExecutionModificationException>()),
      );
      expect((await store.readExecution('exec-2')).status, isNot(isNull));
    });

    test('sorts events by sequence per execution', () async {
      final store = InMemoryExecutionStore();
      for (var i = 0; i < 3; i++) {
        await store.appendEvent(
          AgentEventRecord(
            eventId: 'e$i',
            executionId: 'exec-1',
            workItemId: 'wi-1',
            sequence: 3 - i,
            type: i.isEven
                ? AgentEventType.message
                : AgentEventType.toolStarted,
            occurredAt: DateTime.utc(2026, 1, 1),
          ),
        );
      }
      final events = await store.readEvents('exec-1');
      expect(events.map((e) => e.sequence), [1, 2, 3]);
      expect(store.readEvents('other'), completion(isEmpty));
    });
  });

  group('FileJsonExecutionStore', () {
    late Directory temp;
    late File file;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('exec_store_');
      file = File('${temp.path}/executions.json');
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test('reloads everything a previous instance persisted', () async {
      final first = FileJsonExecutionStore(file);
      await first.saveRequest(sampleRequest('exec-1'));
      await first.saveExecution(
        sampleExecution('exec-1', AgentSessionStatus.completed),
      );
      await first.appendEvent(
        AgentEventRecord(
          eventId: 'evt-1',
          executionId: 'exec-1',
          workItemId: 'wi-1',
          sequence: 1,
          type: AgentEventType.executionCompleted,
          occurredAt: DateTime.utc(2026, 1, 1),
          payload: const {'status': 'completed'},
        ),
      );
      await first.saveResult(
        'exec-1',
        AgentResult(
          resultId: 'result-1',
          sessionId: 'ses-1',
          workItemId: 'wi-1',
          status: AgentResultStatus.completed,
          artifacts: const [],
          diagnostics: AgentDiagnostics(
            exitCode: 0,
            durationMs: 10,
            toolCalls: 1,
            errors: const [],
            warnings: const [],
          ),
          structuredResult: const {},
          completedAt: DateTime.utc(2026, 1, 1),
        ),
      );

      final second = FileJsonExecutionStore(file);
      expect((await second.readRequest('exec-1'))?.executionId, 'exec-1');
      expect(
        (await second.readExecution('exec-1')).status,
        AgentSessionStatus.completed,
      );
      expect(
        (await second.readEvents('exec-1')).single.type,
        AgentEventType.executionCompleted,
      );
      expect((await second.readResult('exec-1'))?.resultId, 'result-1');
    });

    test('enforces compare-and-swap across instances', () async {
      final first = FileJsonExecutionStore(file);
      await first.saveExecution(
        sampleExecution('exec-1', AgentSessionStatus.starting),
      );

      final second = FileJsonExecutionStore(file);
      await expectLater(
        second.saveExecution(
          sampleExecution('exec-1', AgentSessionStatus.running),
          expectedVersion: 5,
        ),
        throwsA(isA<ConcurrentExecutionModificationException>()),
      );
    });
  });
}
