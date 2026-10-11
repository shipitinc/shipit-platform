import 'dart:io';
import 'dart:isolate';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:control_plane_server/server.dart'
    show buildTriageExecutionCoordinator, triageVerificationPlan;
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

/// Regression guard for the live triage defect.
///
/// PRODUCTION DEFECT: `apps/server/lib/server.dart` composed the triage
/// `ExecutionCoordinator` with `verificationPlan: const VerificationPlan()`,
/// whose default command is `dart test`. The triage worktree is a checkout of
/// a README-only repository (no `pubspec.yaml`, no `test/`), so `dart test`
/// cannot pass there and every triage job whose agent succeeded settled as
/// `executedFail`. `triage_execution_test.dart` HAND-CONSTRUCTS its own
/// coordinator and so never exercised `server.dart`'s composition — which is
/// why no existing test caught this.
///
/// These tests drive the ACTUAL production composition
/// ([buildTriageExecutionCoordinator], the function `run()` calls) and would
/// fail if it reverted to the default plan.
void main() {
  group('the coordinator server.dart composes for triage', () {
    test(
      'verifies with the git worktree-HEAD check, never the default dart test',
      () {
        final coordinator = buildTriageExecutionCoordinator(
          store: InMemoryExecutionStore(),
          workflowEngine: DurableWorkflowEngine(store: InMemoryWorkflowStore()),
          runtime: AgentRuntime(),
        );

        final plan = coordinator.verificationPlan;
        expect(
          plan,
          isNotNull,
          reason:
              'a null plan makes the coordinator skip platform verification '
              'entirely, which is a different (and silent) failure',
        );

        // The exact plan production must compose, field for field.
        expect(plan!.command, [
          'git',
          'rev-parse',
          '--verify',
          'HEAD^{commit}',
        ]);
        expect(plan.checkName, 'git_worktree_head');

        // And provably NOT the default that caused the defect.
        expect(plan.command, isNot(const VerificationPlan().command));
        expect(
          plan.command,
          isNot(contains('test')),
          reason:
              '`dart test` cannot run in the README-only triage worktree; a '
              'plan containing it is the production defect',
        );
      },
    );

    test('is the plan named for triage, not a hand-built copy', () {
      expect(
        buildTriageExecutionCoordinator(
          store: InMemoryExecutionStore(),
          workflowEngine: DurableWorkflowEngine(store: InMemoryWorkflowStore()),
          runtime: AgentRuntime(),
        ).verificationPlan!.command,
        triageVerificationPlan.command,
      );
    });

    test(
      'run() never constructs the default VerificationPlan() itself',
      () async {
        final source = await _readServerSource();
        expect(
          source,
          isNot(
            contains(
              RegExp(r'verificationPlan\s*:\s*const VerificationPlan\(\s*\)'),
            ),
          ),
          reason:
              'the exact line that caused the defect must not reappear in the '
              'composition root',
        );
        expect(
          source,
          contains('triageVerificationPlan'),
          reason: 'the composition must attach the named triage plan',
        );
      },
    );
  });

  group('the composed plan in a README-only git worktree', () {
    test(
      'the git HEAD command passes, while the default dart-test command cannot',
      () async {
        final repo = _readmeOnlyGitRepo();
        addTearDown(repo.dispose);

        final composed = buildTriageExecutionCoordinator(
          store: InMemoryExecutionStore(),
          workflowEngine: DurableWorkflowEngine(store: InMemoryWorkflowStore()),
          runtime: AgentRuntime(),
        ).verificationPlan!;

        // The exact plan, run the way the coordinator's verifier runs it: as a
        // process in the worktree.
        final passed = await _run(composed.command, cwd: repo.root);
        expect(
          passed.exitCode,
          0,
          reason:
              'the composed plan must pass in the worktree the triage worker '
              'actually produces. stdout: ${passed.stdout}, '
              'stderr: ${passed.stderr}',
        );
        expect(
          (passed.stdout as String).trim(),
          isNotEmpty,
          reason: 'a git commit hash is the evidence the check ran',
        );

        // The defect's default, run in the same worktree. If this ever starts
        // passing, this regression test has become meaningless and must be
        // revisited — the fixture would no longer model the triage worktree.
        final defaultPlan = const VerificationPlan();
        final failed = await _run(defaultPlan.command, cwd: repo.root);
        expect(
          failed.exitCode,
          isNot(0),
          reason:
              'the default `dart test` plan must fail in a README-only '
              'worktree; this is the production failure being reproduced',
        );
      },
    );
  });
}

/// A disposable git repository containing only `README.md` — the shape of the
/// triage worktree, mirrored from the fixture `triage_execution_test.dart`
/// builds.
class _ReadmeOnlyGitRepo {
  _ReadmeOnlyGitRepo(this.root);

  final Directory root;

  static _ReadmeOnlyGitRepo create() {
    final root = Directory(
      '${Directory.systemTemp.path}/shipit_verify_plan_${pid}_'
      '${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final repo = _ReadmeOnlyGitRepo(root);
    repo._git(['init', '-b', 'main']);
    File('${root.path}/README.md').writeAsStringSync(
      '# triage-repo\n\nA README-only checkout, with no pubspec and no tests.\n',
    );
    repo._git(['add', '.']);
    repo._git(['commit', '-m', 'baseline']);
    return repo;
  }

  void _git(List<String> args) {
    final result = Process.runSync(
      'git',
      args,
      workingDirectory: root.path,
      environment: {
        ...Platform.environment,
        'GIT_AUTHOR_NAME': 'verify-plan-test',
        'GIT_AUTHOR_EMAIL': 'verify-plan-test@example.com',
        'GIT_COMMITTER_NAME': 'verify-plan-test',
        'GIT_COMMITTER_EMAIL': 'verify-plan-test@example.com',
        'GIT_CONFIG_GLOBAL': '/dev/null',
        'GIT_CONFIG_SYSTEM': '/dev/null',
      },
    );
    if (result.exitCode != 0) {
      throw StateError(
        'git ${args.join(' ')} failed (${result.exitCode}): ${result.stderr}',
      );
    }
  }

  void dispose() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

_ReadmeOnlyGitRepo _readmeOnlyGitRepo() => _ReadmeOnlyGitRepo.create();

Future<ProcessResult> _run(List<String> command, {required Directory cwd}) =>
    Process.run(
      command.first,
      command.skip(1).toList(),
      workingDirectory: cwd.path,
    );

/// Reads `lib/server.dart` as TEXT, resolved through the package URI so the
/// test passes whether `dart test` runs from the repository root or from
/// `apps/server`. Same technique as `tick_single_flight_test.dart`.
Future<String> _readServerSource() async {
  final uri = await Isolate.resolvePackageUri(
    Uri.parse('package:control_plane_server/server.dart'),
  );
  if (uri == null) {
    throw StateError('could not resolve the server composition source');
  }
  return File.fromUri(uri).readAsStringSync();
}
