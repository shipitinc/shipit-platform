import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

import 'support/git_repo_fixture.dart';
import 'support/host.dart';

/// THE WORKER'S OWN WRITE PATH CARRIES THE LANE'S DECLARATION.
///
/// ## WHAT THIS FILE MEASURES
///
/// The worker's production write path is the copy from the dispatch request
/// onto the agent execution request (`local_worker.dart`, `_agentRequest`).
/// It is the step between "the platform dispatched this lane with a grant" and
/// "the coordinator captured it", and a copy that dropped the declaration
/// would leave every lane's grant unreadable — which reads as "declared
/// nothing", the fail-closed direction, so the defect would announce itself
/// only as a gate that refuses everything.
///
/// This file drives the REAL stack — the real worker, the real coordinator,
/// the real in-memory execution store — and reads the durable execution row
/// the QA gate reads. Nothing here hand-builds the record it asserts on.
///
/// ## WHY IT IS IN THE WORKER SUITE AND NOT ONLY IN THE COORDINATOR'S
///
/// The coordinator's own capture is measured in
/// `packages/execution_coordinator/test/lane_path_ownership_test.dart`. What
/// only this suite can measure is the hop BEFORE it: that the worker — the
/// component production actually dispatches through — carries the
/// declaration across.
void main() {
  late Directory temp;
  late GitRepoFixture repo;
  late WorkerHost host;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('worker_ownership_');
    repo = GitRepoFixture.create(temp.path);
    host = WorkerHost(repo: repo, workspaceRoot: '${temp.path}/workspaces');
  });

  tearDown(() {
    try {
      repo.dispose();
    } on Object {
      // cleanup may already have removed worktrees; root removal is best-effort
    }
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test(
    'the durable execution record carries the declared owned paths',
    () async {
      await host.workItemReady();
      final request = host.request(
        repositoryPath: repo.root.path,
        startingRevision: repo.startingRevision,
        declaredOwnedPaths: const [
          'apps/server/**',
          'packages/qa_orchestration/**',
        ],
      );

      final result = await host.dispatcher.run(request);
      expect(result.status, WorkerExecutionStatus.executedPass);

      // `agx-<workerExecutionId>` is the agent execution id the WORKER builds
      // (`local_worker.dart`, `_agentRequest`) — so this row is the one the
      // worker's own copy reached.
      final execution = await host.executionStore.readExecutionOrNull(
        'agx-wx-1',
      );
      expect(execution, isNotNull);
      expect(execution!.metadata?[declaredOwnedPathsMetadataKey], [
        'apps/server/**',
        'packages/qa_orchestration/**',
      ]);
    },
  );

  test(
    'a lane dispatched with NO declaration records an EMPTY declaration',
    () async {
      await host.workItemReady();
      final request = host.request(
        repositoryPath: repo.root.path,
        startingRevision: repo.startingRevision,
      );

      final result = await host.dispatcher.run(request);
      expect(result.status, WorkerExecutionStatus.executedPass);

      final execution = await host.executionStore.readExecutionOrNull(
        'agx-wx-1',
      );
      expect(execution, isNotNull);
      expect(
        execution!.metadata,
        contains(declaredOwnedPathsMetadataKey),
        reason:
            '"dispatched and declared nothing" and "no capture was made" are '
            'different records',
      );
      expect(execution.metadata![declaredOwnedPathsMetadataKey], isEmpty);
    },
  );
}
