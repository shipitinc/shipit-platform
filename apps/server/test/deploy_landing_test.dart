import 'dart:convert';
import 'dart:io';

import 'package:control_plane_server/src/deploy/deploy_landing.dart';
import 'package:control_plane_server/src/deploy/deploy_push.dart';
import 'package:execution_coordinator/execution_coordinator.dart'
    show InMemoryExecutionStore;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart' show InMemoryWorkerStore;
import 'package:workflow_store/workflow_store.dart';

/// The deploy landing: `deployed` is now earned by a verified merge, not a
/// label — F-257.
///
/// ## THE DEFECT THIS FILE HOLDS CLOSED
///
/// `deployment_approval` -> `approve` fired
/// `waiting_for_human_decision -> deployed` synchronously and the
/// producer's commit never left its worktree branch. The resolution path
/// now owes a verified land FIRST: the produced commit is merged into the
/// product's recorded checkout and proven reachable from its target branch
/// before the engine writes `deployed`. A merge that cannot land writes
/// nothing and leaves the decision pending.
///
/// ## WHAT IS ASSERTED — against a REAL scratch git repository
///
///   1. approve -> the produced commit is merged into the checkout's target
///      branch and proven an ancestor of its HEAD -> then `deployed`;
///   2. the evidence lands on the item (`deployedCommit` & co.);
///   3. a replayed approve does NOT merge twice;
///   4. a merge that conflicts throws, aborts the checkout clean, and the
///      pending decision can still be REJECTED to `deployment_failed`;
///   5. a produced commit absent from the recorded checkout is refused;
///   6. a no-commit producer defers to the workspace-base rule and lands
///      trivially; nothing at all to land is refused;
///   7. resolutions that are not approved deployments owe no land.
///
/// ## WHY REAL GIT
///
/// The merge is the claim being made true. A seam that let a test assert
/// "the merge ran" without a repository would be testing the mock, exactly
/// the class of test `deploy_gate_sweep_test.dart` refuses: the git calls
/// run against a scratch repository the test itself creates and destroys.
void main() {
  late _Harness harness;
  late Directory repo;
  late String base;
  late String produced;

  setUp(() async {
    harness = _Harness();
    repo = await Directory.systemTemp.createTemp('deploy_landing_test_');
    base = await _git(repo.path, ['init', '-b', 'main']).then(
      (_) => _initBase(repo.path),
    );
    produced = await _produceCommit(repo.path, _itemId);
  });

  tearDown(() async {
    if (repo.existsSync()) await repo.delete(recursive: true);
  });

  group('an approved deploy lands before the item is deployed', () {
    test(
      'approve -> produced commit merged into the target branch -> deployed',
      () async {
        await harness.seedParkedForApproval(
          stampProducer: true,
          repositoryPath: repo.path,
          startingRevision: base,
          endingRevision: produced,
        );
        final decision = await harness.blockingDecision();

        final landing = await harness.maybeLand(
          decision: decision,
          choice: HumanDecisionChoice.approve,
        );

        expect(landing, isNotNull);
        expect(landing!.commit, produced);
        expect(landing.repositoryPath, repo.path);
        expect(landing.targetBranch, 'main');
        expect(landing.alreadyLanded, isFalse);
        expect(landing.commitBasis, 'producedCommit');

        // The deploy is REAL: the produced commit is reachable from the
        // target branch's HEAD.
        expect(
          await _exit(repo.path, [
            'merge-base',
            '--is-ancestor',
            produced,
            'HEAD',
          ]),
          0,
          reason: 'deployed must mean the produced commit is on the branch',
        );

        final deployed = await harness.resolve(
          decisionId: decision.decisionId,
          choice: HumanDecisionChoice.approve,
        );
        expect(deployed.state, WorkItemState.deployed);
        expect(deployed.metadata?['deployedCommit'], produced);
        expect(deployed.metadata?['deployedInto'], '${repo.path}#main');
        expect(deployed.metadata?['deployedCommitBasis'], 'producedCommit');
        expect(
          deployed.metadata?['deployedBy'],
          deployLandingMechanismName,
        );
      },
    );

    test('a replayed approve does not merge twice', () async {
      await harness.seedParkedForApproval(
        stampProducer: true,
        repositoryPath: repo.path,
        startingRevision: base,
        endingRevision: produced,
      );
      final decision = await harness.blockingDecision();

      final first = await harness.maybeLand(
        decision: decision,
        choice: HumanDecisionChoice.approve,
      );
      final headAfterFirst = await _git(repo.path, ['rev-parse', 'HEAD']);

      final second = await harness.maybeLand(
        decision: decision,
        choice: HumanDecisionChoice.approve,
      );

      expect(first!.alreadyLanded, isFalse);
      expect(second!.alreadyLanded, isTrue);
      expect(
        await _git(repo.path, ['rev-parse', 'HEAD']),
        headAfterFirst,
        reason:
            'the second land must verify the ancestry instead of merging '
            'again — the merge is idempotent',
      );
    });

    test(
      'a land that ran before an interrupted resolve is completed, not '
      'repeated, by the retry',
      () async {
        await harness.seedParkedForApproval(
          stampProducer: true,
          repositoryPath: repo.path,
          startingRevision: base,
          endingRevision: produced,
        );
        final decision = await harness.blockingDecision();

        // The crash shape: the land committed, the engine call never ran.
        // The decision is still pending, the item still parked.
        await harness.maybeLand(
          decision: decision,
          choice: HumanDecisionChoice.approve,
        );
        expect(
          (await harness.store.readWorkItem(_itemId)).state,
          WorkItemState.waitingForHumanDecision,
        );

        final landing = await harness.maybeLand(
          decision: decision,
          choice: HumanDecisionChoice.approve,
        );
        expect(landing!.alreadyLanded, isTrue);

        final deployed = await harness.resolve(
          decisionId: decision.decisionId,
          choice: HumanDecisionChoice.approve,
        );
        expect(deployed.state, WorkItemState.deployed);
      },
    );
  });

  group('a land that cannot happen writes nothing', () {
    test(
      'a conflicting merge throws, aborts the checkout clean, and reject '
      'still reaches deployment_failed',
      () async {
        // Diverge main AND the produced branch over file.txt — the worker
        // execution is seeded with the DIVERGED branch tip, so the deploy
        // merge conflicts for real.
        final diverged = await _divergeMain(repo.path, _itemId);
        await harness.seedParkedForApproval(
          stampProducer: true,
          repositoryPath: repo.path,
          startingRevision: base,
          endingRevision: diverged,
        );
        final decision = await harness.blockingDecision();
        final headBefore = await _git(repo.path, ['rev-parse', 'HEAD']);

        await expectLater(
          harness.maybeLand(
            decision: decision,
            choice: HumanDecisionChoice.approve,
          ),
          throwsA(isA<DeployLandingException>()),
        );

        // NOTHING was written: the decision is still pending and the item
        // is still parked at the gate.
        final parked = await harness.store.readWorkItem(_itemId);
        expect(parked.state, WorkItemState.waitingForHumanDecision);
        expect(parked.metadata?['deployedCommit'], isNull);
        expect(
          (await harness.store.readHumanDecision(decision.decisionId)).status,
          HumanDecisionStatus.pending,
        );
        expect(
          await _exit(repo.path, ['rev-parse', '-q', '--verify', 'MERGE_HEAD']),
          isNot(0),
          reason:
              'a failed merge must abort the checkout back to clean, not '
              'leave the recorded checkout mid-merge for the next land',
        );
        expect(await _git(repo.path, ['rev-parse', 'HEAD']), headBefore);

        // The honest failure path still exists: a human reject reaches
        // deployment_failed through the edge that already existed.
        final failed = await harness.resolve(
          decisionId: decision.decisionId,
          choice: HumanDecisionChoice.reject,
        );
        expect(failed.state, WorkItemState.deploymentFailed);
      },
    );

    test(
      'a produced commit absent from the recorded checkout is refused',
      () async {
        await harness.seedParkedForApproval(
          stampProducer: true,
          repositoryPath: repo.path,
          startingRevision: base,
          endingRevision: 'a' * 40,
        );
        final decision = await harness.blockingDecision();

        await expectLater(
          harness.maybeLand(
            decision: decision,
            choice: HumanDecisionChoice.approve,
          ),
          throwsA(isA<DeployLandingException>()),
        );
        expect(
          (await harness.store.readWorkItem(_itemId)).state,
          WorkItemState.waitingForHumanDecision,
        );
      },
    );

    test(
      'a refused push throws — the merge stays local, nothing is stamped, '
      'and the decision stays pending (F-258)',
      () async {
        await harness.seedParkedForApproval(
          stampProducer: true,
          repositoryPath: repo.path,
          startingRevision: base,
          endingRevision: produced,
        );
        final decision = await harness.blockingDecision();
        harness.pusher.failure = const DeployPushRefusedException(
          'the remote rejected the push',
        );

        await expectLater(
          harness.maybeLand(
            decision: decision,
            choice: HumanDecisionChoice.approve,
          ),
          throwsA(isA<DeployLandingException>()),
        );

        // NOTHING durable was written — the parked item and the pending
        // decision are exactly as the approve left them, while the merge
        // DID land locally (and a retry completes through the
        // already-landed arm rather than merging twice).
        final parked = await harness.store.readWorkItem(_itemId);
        expect(parked.state, WorkItemState.waitingForHumanDecision);
        expect(parked.metadata?['deployedCommit'], isNull);
        expect(parked.metadata?['deployedRemote'], isNull);
        expect(
          (await harness.store.readHumanDecision(decision.decisionId)).status,
          HumanDecisionStatus.pending,
        );
        expect(
          await _exit(repo.path, [
            'merge-base',
            '--is-ancestor',
            produced,
            'HEAD',
          ]),
          0,
          reason:
              'the local merge is real — the push is what failed, and the '
              'state model stays honest about "merged locally, push '
              'refused": pending, not deployed',
        );

        // The retry: pusher healthy again, the already-landed arm
        // completes the interrupted push and stamps for real.
        harness.pusher.failure = null;
        final landing = await harness.maybeLand(
          decision: decision,
          choice: HumanDecisionChoice.approve,
        );
        expect(landing!.alreadyLanded, isTrue);
        final deployed = await harness.resolve(
          decisionId: decision.decisionId,
          choice: HumanDecisionChoice.approve,
        );
        expect(deployed.state, WorkItemState.deployed);
        expect(
          deployed.metadata?['deployedRemote'],
          'ssh://git@remote.test:22/org/repo.git#main',
        );
      },
    );

    test('a producer with no completed result is refused', () async {
      await harness.seedParkedForApproval(
        stampProducer: true,
        withResult: false,
        repositoryPath: repo.path,
        startingRevision: base,
        endingRevision: produced,
      );
      final decision = await harness.blockingDecision();

      await expectLater(
        harness.maybeLand(
          decision: decision,
          choice: HumanDecisionChoice.approve,
        ),
        throwsA(isA<DeployLandingException>()),
      );
    });

    test(
      'no commit and no starting revision — nothing honest to land — is '
      'refused',
      () async {
        await harness.seedParkedForApproval(
          stampProducer: true,
          repositoryPath: repo.path,
          startingRevision: null,
          endingRevision: base,
        );
        final decision = await harness.blockingDecision();

        await expectLater(
          harness.maybeLand(
            decision: decision,
            choice: HumanDecisionChoice.approve,
          ),
          throwsA(isA<DeployLandingException>()),
        );
      },
    );
  });

  group('the fallback arm', () {
    test(
      'a producer that committed nothing lands its recorded base — '
      'trivially, and honestly',
      () async {
        // endingRevision == requestedStartingRevision: the platform's own
        // answer to "what did this producer leave" is "nothing new", so the
        // land is the workspace base — the same revision the deployment
        // artifact names as its version.
        await harness.seedParkedForApproval(
          stampProducer: true,
          repositoryPath: repo.path,
          startingRevision: base,
          endingRevision: base,
        );
        final decision = await harness.blockingDecision();

        final landing = await harness.maybeLand(
          decision: decision,
          choice: HumanDecisionChoice.approve,
        );

        expect(landing, isNotNull);
        expect(landing!.commit, base);
        expect(landing.commitBasis, 'workspaceStartingRevision');
        expect(landing.alreadyLanded, isTrue);

        final deployed = await harness.resolve(
          decisionId: decision.decisionId,
          choice: HumanDecisionChoice.approve,
        );
        expect(deployed.state, WorkItemState.deployed);
        expect(deployed.metadata?['deployedCommit'], base);
      },
    );
  });

  group('the land targets the product DEFAULT branch — F-261', () {
    test(
      'lands on `main` even when the recorded checkout sits on the '
      'produced lane branch',
      () async {
        // The live defect: the durable clone is left on the lane branch
        // the produced commit was made on, and the land used to merge
        // `--no-ff` into it — seven items landed on `shipit/impl/...`.
        await _git(repo.path, ['checkout', 'shipit/impl/$_itemId']);
        await harness.seedParkedForApproval(
          stampProducer: true,
          repositoryPath: repo.path,
          startingRevision: base,
          endingRevision: produced,
        );
        final decision = await harness.blockingDecision();

        final landing = await harness.maybeLand(
          decision: decision,
          choice: HumanDecisionChoice.approve,
        );

        expect(landing, isNotNull);
        expect(
          landing!.targetBranch,
          'main',
          reason:
              'the merge target is the product\'s default branch, not '
              'whatever branch the checkout happened to be sitting on',
        );
        // REAL: the produced commit is reachable from `main`'s tip — the
        // merge went into the default branch.
        expect(
          await _exit(repo.path, [
            'merge-base',
            '--is-ancestor',
            produced,
            'refs/heads/main',
          ]),
          0,
          reason:
              'landed must mean on the default branch — before this fix '
              'the commit merged into the lane branch instead',
        );
        expect(
          await _git(repo.path, [
            'rev-parse',
            'refs/heads/shipit/impl/$_itemId',
          ]),
          produced,
          reason:
              'the lane branch tip is still the produced commit — it was '
              'not merged into itself a second time',
        );
        expect(
          await _git(repo.path, ['symbolic-ref', '--short', 'HEAD']),
          'main',
          reason:
              'HEAD is left on the default branch the land selected, which '
              'is also the correct resting state for the durable clone',
        );
        final deployed = await harness.resolve(
          decisionId: decision.decisionId,
          choice: HumanDecisionChoice.approve,
        );
        expect(deployed.metadata?['deployedInto'], '${repo.path}#main');
      },
    );

    test(
      'a clone whose remote declares a NON-`main` default lands on THAT '
      'branch — the default is read, not hardcoded',
      () async {
        // A real clone carries `refs/remotes/origin/HEAD`: the remote's own
        // record of its default. Seed a bare origin whose default is
        // `trunk` so the assertion is the READ, not the constant.
        final remote = await Directory.systemTemp.createTemp(
          'deploy_default_remote_',
        );
        final seed = await Directory.systemTemp.createTemp(
          'deploy_default_seed_',
        );
        final clone = await Directory.systemTemp.createTemp(
          'deploy_default_clone_',
        );
        try {
          // The remote must already carry `trunk` when the clone is made —
          // cloning an EMPTY remote records no `origin/HEAD`, which is the
          // ref under test.
          await _git(remote.path, ['init', '--bare', '-b', 'trunk']);
          await _git(seed.path, ['init', '-b', 'trunk']);
          final cloneBase = await _initBase(seed.path);
          await _git(seed.path, ['remote', 'add', 'origin', remote.path]);
          await _git(seed.path, ['push', 'origin', 'trunk']);
          await _git(clone.path, ['clone', remote.path, '.']);
          final cloneProduced = await _produceCommitOn(
            clone.path,
            _itemId,
            'trunk',
          );
          // Sit on the lane branch — the shape that landed on the lane.
          await _git(clone.path, ['checkout', 'shipit/impl/$_itemId']);
          await harness.seedParkedForApproval(
            stampProducer: true,
            repositoryPath: clone.path,
            startingRevision: cloneBase,
            endingRevision: cloneProduced,
          );
          final decision = await harness.blockingDecision();

          final landing = await harness.maybeLand(
            decision: decision,
            choice: HumanDecisionChoice.approve,
          );

          expect(landing, isNotNull);
          expect(
            landing!.targetBranch,
            'trunk',
            reason:
                'origin/HEAD names trunk, so trunk is where the land must '
                'go — a hardcoded `main` would have refused or invented',
          );
          expect(
            await _exit(clone.path, [
              'merge-base',
              '--is-ancestor',
              cloneProduced,
              'refs/heads/trunk',
            ]),
            0,
          );
        } finally {
          if (remote.existsSync()) await remote.delete(recursive: true);
          if (seed.existsSync()) await seed.delete(recursive: true);
          if (clone.existsSync()) await clone.delete(recursive: true);
        }
      },
    );

    test(
      'a checkout whose default branch cannot be resolved refuses — '
      'nothing merged, decision pending',
      () async {
        // No `refs/remotes/origin/HEAD`, and no `main` anywhere: there is
        // no honest target, so the land must refuse rather than fall back
        // to whatever branch the checkout happens to be sitting on.
        final odd = await Directory.systemTemp.createTemp(
          'deploy_nodefault_',
        );
        try {
          await _git(odd.path, ['init', '-b', 'trunk']);
          final oddBase = await _initBase(odd.path);
          final oddProduced = await _produceCommitOn(
            odd.path,
            _itemId,
            'trunk',
          );
          await harness.seedParkedForApproval(
            stampProducer: true,
            repositoryPath: odd.path,
            startingRevision: oddBase,
            endingRevision: oddProduced,
          );
          final decision = await harness.blockingDecision();
          final headBefore = await _git(odd.path, ['rev-parse', 'HEAD']);

          await expectLater(
            harness.maybeLand(
              decision: decision,
              choice: HumanDecisionChoice.approve,
            ),
            throwsA(isA<DeployLandingException>()),
          );

          expect(
            await _git(odd.path, ['rev-parse', 'HEAD']),
            headBefore,
            reason: 'an unresolved default merges nothing',
          );
          expect(
            await _exit(odd.path, [
              'merge-base',
              '--is-ancestor',
              oddProduced,
              'refs/heads/trunk',
            ]),
            isNot(0),
            reason:
                'trunk must NOT contain the produced commit — keeping the '
                'current branch as the target is exactly what was refused',
          );
          // NOTHING was written: item parked, decision pending.
          final parked = await harness.store.readWorkItem(_itemId);
          expect(parked.state, WorkItemState.waitingForHumanDecision);
          expect(parked.metadata?['deployedCommit'], isNull);
          expect(
            (await harness.store.readHumanDecision(
              decision.decisionId,
            )).status,
            HumanDecisionStatus.pending,
          );
        } finally {
          if (odd.existsSync()) await odd.delete(recursive: true);
        }
      },
    );
  });

  group('resolutions that are not approved deployments owe no land', () {
    test('a reject merges nothing and resolves to deployment_failed', () async {
      await harness.seedParkedForApproval(
        stampProducer: true,
        repositoryPath: repo.path,
        startingRevision: base,
        endingRevision: produced,
      );
      final decision = await harness.blockingDecision();
      final headBefore = await _git(repo.path, ['rev-parse', 'HEAD']);

      final landing = await harness.maybeLand(
        decision: decision,
        choice: HumanDecisionChoice.reject,
      );

      expect(landing, isNull);
      expect(await _git(repo.path, ['rev-parse', 'HEAD']), headBefore);

      final failed = await harness.resolve(
        decisionId: decision.decisionId,
        choice: HumanDecisionChoice.reject,
      );
      expect(failed.state, WorkItemState.deploymentFailed);
    });

    test(
      'a non-deployment decision on the same item owes no land',
      () async {
        // `deploying -> waitingForHumanDecision` admits deploymentApproval
        // alone, so the contrast gate is parked from `qaPassed`, where
        // `humanQaApproval` is the admitted type.
        await harness.seedParkedForApproval(
          stampProducer: true,
          repositoryPath: repo.path,
          startingRevision: base,
          endingRevision: produced,
          fromState: WorkItemState.qaPassed,
          decisionType: HumanDecisionType.humanQaApproval,
        );
        final decision = await harness.blockingDecision();

        final landing = await harness.maybeLand(
          decision: decision,
          choice: HumanDecisionChoice.approve,
        );

        expect(landing, isNull);
      },
    );
  });

  group('deployLandingIsOwed', () {
    test('is true only for the approved blocking deployment gate', () async {
      await harness.seedParkedForApproval(
        stampProducer: true,
        repositoryPath: repo.path,
        startingRevision: base,
        endingRevision: produced,
      );
      final item = await harness.store.readWorkItem(_itemId);
      final decision = await harness.blockingDecision();

      expect(
        deployLandingIsOwed(
          decision: decision,
          choice: HumanDecisionChoice.approve,
          item: item,
        ),
        isTrue,
      );
      expect(
        deployLandingIsOwed(
          decision: decision,
          choice: HumanDecisionChoice.reject,
          item: item,
        ),
        isFalse,
      );
      expect(
        deployLandingIsOwed(
          decision: decision,
          choice: HumanDecisionChoice.approve,
          item: item.copyWith(state: WorkItemState.deploying),
        ),
        isFalse,
      );
    });

    test(
      'a resolved-approve still parked at the gate is owed — the '
      'crash-window replay',
      () async {
        await harness.seedParkedForApproval(
          stampProducer: true,
          repositoryPath: repo.path,
          startingRevision: base,
          endingRevision: produced,
        );
        final item = await harness.store.readWorkItem(_itemId);
        final decision = await harness.blockingDecision();
        final resolved = HumanDecision(
          decisionId: decision.decisionId,
          workItemId: decision.workItemId,
          decisionType: decision.decisionType,
          status: HumanDecisionStatus.resolved,
          question: decision.question,
          blocking: decision.blocking,
          requestedAt: decision.requestedAt,
          choice: HumanDecisionChoice.approve,
          decider: 'alice',
          rationale: 'ship it',
          timestamp: DateTime.utc(2026, 10, 21),
          updatedAt: DateTime.utc(2026, 10, 21),
        );

        expect(
          deployLandingIsOwed(
            decision: resolved,
            choice: HumanDecisionChoice.approve,
            item: item,
          ),
          isTrue,
          reason:
              'a resolved approve parked at the gate is exactly the '
              'interrupted resolve the retry must complete — with the land '
              'first',
        );
      },
    );
  });
}

const _itemId = 'WI-land-1';

Future<String> _git(String dir, List<String> args) async {
  final result = await Process.run(
    'git',
    [
      '-C',
      dir,
      ...args,
    ],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    throw StateError(
      'git ${args.join(' ')} in $dir exited ${result.exitCode}: '
      '${result.stderr}',
    );
  }
  return (result.stdout as String).trim();
}

Future<int> _exit(String dir, List<String> args) async {
  final result = await Process.run(
    'git',
    [
      '-C',
      dir,
      ...args,
    ],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  return result.exitCode;
}

Future<String> _initBase(String dir) async {
  await File('$dir/file.txt').writeAsString('base\n');
  await _git(dir, ['add', 'file.txt']);
  await _git(dir, [
    '-c',
    'user.name=test',
    '-c',
    'user.email=test@test',
    'commit',
    '-m',
    'init',
  ]);
  return _git(dir, ['rev-parse', 'HEAD']);
}

/// A produced implementation commit on `shipit/impl/<workItemId>` — the
/// shape `ArtifactCommitter` leaves behind.
Future<String> _produceCommit(String dir, String workItemId) =>
    _produceCommitOn(dir, workItemId, 'main');

/// [_produceCommit] parameterized on the branch the checkout returns to —
/// the F-261 fixtures need the lane produced against a non-`main` default
/// (`trunk`), and the sit-on-lane test needs no return at all handled by
/// its own checkout.
Future<String> _produceCommitOn(
  String dir,
  String workItemId,
  String backTo,
) async {
  await _git(dir, ['checkout', '-b', 'shipit/impl/$workItemId']);
  await File('$dir/feature.txt').writeAsString('the produced change\n');
  await _git(dir, ['add', 'feature.txt']);
  await _git(dir, [
    '-c',
    'user.name=test',
    '-c',
    'user.email=test@test',
    'commit',
    '-m',
    'implement $workItemId',
  ]);
  final produced = await _git(dir, ['rev-parse', 'HEAD']);
  await _git(dir, ['checkout', backTo]);
  return produced;
}

/// Moves `main` ahead with a change that conflicts with the produced
/// branch, so the deploy merge fails for real. Returns the produced
/// branch's new tip — the revision the deploy would try to land.
Future<String> _divergeMain(String dir, String workItemId) async {
  await _git(dir, ['checkout', 'shipit/impl/$workItemId']);
  await File('$dir/file.txt').writeAsString('theirs\n');
  await _git(dir, ['add', 'file.txt']);
  await _git(dir, [
    '-c',
    'user.name=test',
    '-c',
    'user.email=test@test',
    'commit',
    '-m',
    'conflict on the produced side',
  ]);
  final diverged = await _git(dir, ['rev-parse', 'HEAD']);
  await _git(dir, ['checkout', 'main']);
  await File('$dir/file.txt').writeAsString('ours\n');
  await _git(dir, ['add', 'file.txt']);
  await _git(dir, [
    '-c',
    'user.name=test',
    '-c',
    'user.email=test@test',
    'commit',
    '-m',
    'conflict on the target side',
  ]);
  return diverged;
}

/// One approval's worth of wiring: real engine, real stores, real git.
class _Harness {
  final InMemoryWorkflowStore store = InMemoryWorkflowStore();
  final InMemoryExecutionStore executionStore = InMemoryExecutionStore();
  final InMemoryWorkerStore workerStore = InMemoryWorkerStore();
  final _FakeDeployPusher pusher = _FakeDeployPusher();
  final List<String> logEvents = [];

  late final DurableWorkflowEngine engine = DurableWorkflowEngine(
    store: store,
  );

  static final _signature = DecisionSignature(
    algorithm: 'test',
    publicKey: 'test-key',
    signature: 'test-sig',
    signedAt: DateTime.utc(2026, 10, 21),
  );

  /// The item parked at `waiting_for_human_decision` under a pending
  /// blocking [decisionType] — the gate the approval resolves. Parked by
  /// the real engine's `requestHumanDecision` so `blockingHumanDecisionId`
  /// is set by the same write that raised the decision.
  ///
  /// [repositoryPath], [startingRevision] and [endingRevision] are the REAL
  /// values the test's scratch repository produced — the worker execution
  /// `producedCommitFor` reads is seeded with them, and the agent
  /// execution's workspace records [startingRevision].
  Future<void> seedParkedForApproval({
    bool stampProducer = false,
    bool withResult = true,
    String? repositoryPath,
    String? startingRevision,
    String? endingRevision,
    WorkItemState fromState = WorkItemState.deploying,
    HumanDecisionType decisionType = HumanDecisionType.deploymentApproval,
  }) async {
    await store.saveWorkItem(
      WorkItem(
        workItemId: _itemId,
        productId: 'shipit-platform',
        category: WorkItemCategory.feature,
        title: 'A deployable work item',
        description: 'Passed QA and parked for the deploy gate.',
        state: fromState,
        metadata: stampProducer ? const {'producerActorId': 'ex-prod'} : null,
        createdAt: DateTime.utc(2026, 10, 21),
        updatedAt: DateTime.utc(2026, 10, 21),
        version: 1,
      ),
    );
    await engine.requestHumanDecision(
      workItemId: _itemId,
      decisionType: decisionType,
      question: 'Deploy it?',
      options: const [
        HumanDecisionOption(optionId: 'approve', label: 'Deploy it'),
        HumanDecisionOption(optionId: 'reject', label: 'Do not deploy'),
      ],
      blocking: true,
    );

    await executionStore.saveExecution(
      AgentExecution(
        executionId: 'ex-prod',
        workItemId: _itemId,
        requestId: 'req-prod',
        runtimeTypeId: 'local',
        role: AgentRole.implementer,
        status: AgentSessionStatus.completed,
        workspace: AgentWorkspace(
          workspaceId: 'ws-1',
          path: '/tmp/ws',
          startingRevision: startingRevision,
        ),
        startedAt: DateTime.utc(2026),
      ),
    );
    if (withResult) {
      await executionStore.saveResult(
        'ex-prod',
        AgentResult(
          resultId: 'res-prod',
          sessionId: 'sess-prod',
          workItemId: _itemId,
          status: AgentResultStatus.completed,
          artifacts: const [],
          diagnostics: const AgentDiagnostics(
            exitCode: 0,
            durationMs: 1,
            toolCalls: 1,
            errors: [],
            warnings: [],
          ),
          structuredResult: const {},
          completedAt: DateTime.utc(2026),
        ),
      );
    }
    if (repositoryPath != null && startingRevision != null) {
      await workerStore.saveWorkerExecution(
        WorkerExecution(
          workerExecutionId: 'wx-prod',
          workItemId: _itemId,
          repositoryPath: repositoryPath,
          requestedStartingRevision: startingRevision,
          requiredCapabilities: const {
            WorkerCapability.linux,
            WorkerCapability.git,
          },
          agentExecutionId: 'ex-prod',
          endingRevision: endingRevision,
          status: WorkerExecutionStatus.executedPass,
          cleanupPolicy: WorkerCleanupPolicy.removeAlways,
        ),
      );
    }
  }

  Future<HumanDecision> blockingDecision() async {
    final item = await store.readWorkItem(_itemId);
    return store.readHumanDecision(item.blockingHumanDecisionId!);
  }

  Future<DeployLanding?> maybeLand({
    required HumanDecision decision,
    required HumanDecisionChoice choice,
  }) => maybeLandApprovedDeployment(
    executionStore: executionStore,
    workerStore: workerStore,
    workflowStore: store,
    decision: decision,
    choice: choice,
    deployPush: pusher,
    clock: () => DateTime.utc(2026, 10, 21),
    log: (event, data) => logEvents.add(event),
  );

  /// What the service hands to the engine after the land — the real
  /// `DurableWorkflowEngine.resolveHumanDecision`, so the `deployed` the
  /// test asserts is the engine's own write, not a stand-in.
  Future<WorkItem> resolve({
    required String decisionId,
    required HumanDecisionChoice choice,
  }) => engine.resolveHumanDecision(
    decisionId: decisionId,
    choice: choice,
    decider: 'alice',
    rationale: 'the human answer',
    signature: _signature,
  );
}

/// A [DeployPusher] that records its calls and reports the branch pushed.
///
/// F-258 made the push part of the land; the push's own transport and
/// credential resolution are exercised for real in `deploy_push_test.dart`,
/// so the land tests drive it through this recording fake — the same way
/// the stores are substituted but the refusals never are.
class _FakeDeployPusher implements DeployPusher {
  final List<({String repositoryPath, String targetBranch, String localHead})>
  calls = [];

  Object? failure;

  @override
  Future<DeployPush> pushLandedBranch({
    required WorkItem item,
    required String repositoryPath,
    required String targetBranch,
    required String localHead,
  }) async {
    calls.add((
      repositoryPath: repositoryPath,
      targetBranch: targetBranch,
      localHead: localHead,
    ));
    final toThrow = failure;
    if (toThrow != null) throw toThrow;
    return DeployPush(
      state: DeployPushState.pushed,
      remoteUrl: 'ssh://git@remote.test:22/org/repo.git',
      branch: targetBranch,
      remoteHead: localHead,
    );
  }
}
