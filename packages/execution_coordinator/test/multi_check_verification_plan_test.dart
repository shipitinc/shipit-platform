import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/fake_agent.dart';
import 'support/fixture.dart';

/// ## WHY THIS FILE EXISTS
///
/// `VerificationPlan` used to carry ONE `command` + ONE `checkName`, and
/// `_completeSuccess` wrote ONE [PlatformVerification] keyed
/// `ver-<executionId>`. One execution therefore yielded at most one row — while
/// the per-execution tier in `AGENTS.md` declares FOUR checks, three of them at
/// a working directory that is not the repository root. This file pins the
/// widened record: several checks, one row each, each in its own directory.
///
/// ## THE HONESTY PROPERTY, WHICH IS THE POINT
///
/// A check that did not run must be ABSENT. Not "passed", not "failed" — there
/// is no verdict, and inventing one is what makes a gate unfailable. Two things
/// stop a check before it observes anything: its working directory is not in the
/// workspace, and the tool is not installed (or setup failed first). Both leave
/// NO ROW, so the absence is visible in the record a gate reads. Group
/// 'a check that COULD NOT run leaves no row' is that claim, and the tests
/// inside it assert on the persisted rows, not on a return value.
void main() {
  late Directory temp;
  late FixtureWorkspace fixture;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;
  var _sessions = 0;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('multi_check_plan_');
    fixture = FixtureWorkspace(parent: temp.path);
    workflowEngine = DurableWorkflowEngine(store: InMemoryWorkflowStore());
    executionStore = InMemoryExecutionStore();
  });

  tearDown(() {
    fixture.dispose();
    temp.deleteSync(recursive: true);
  });

  /// A coordinator over a FRESH session.
  ///
  /// One session per coordinator, not one per test: the coordinator closes the
  /// session when it finalizes, so a second `execute` through the same session
  /// never reaches `_completeSuccess` — which would let any assertion about
  /// that method pass without it ever running.
  ExecutionCoordinator coordinatorOf(
    VerificationPlan? plan, {
    String executionId = 'exec-1',
    FakeAgentSession? session,
  }) {
    final agentSession =
        session ??
        FakeAgentSession(
          executionId: executionId,
          workItemId: 'wi-1',
          sessionId: 'ses-fake-${++_sessions}',
        );
    return ExecutionCoordinator(
      store: executionStore,
      workflowEngine: workflowEngine,
      runtime: AgentRuntime(
        registry: AgentAdapterRegistry()
          ..register(FakeAgentAdapter(agentSession)),
      ),
      verificationPlan: plan,
    );
  }

  Future<WorkItem> readyItem() async {
    await workflowEngine.createWorkItem(
      workItemId: 'wi-1',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Implement calculator add',
      description: 'Item exercising a multi-check VerificationPlan',
      qaContractId: 'qa-1',
      featureRef: 'feature/calc',
    );
    await workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
    );
    await workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      context: const {'featureRef': 'feature/calc'},
    );
    return workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );
  }

  AgentExecutionRequest request({String executionId = 'exec-1'}) =>
      AgentExecutionRequest(
        executionId: executionId,
        workItemId: 'wi-1',
        role: AgentRole.implementer,
        runtimeTypeId: 'fake-runtime',
        workspace: AgentWorkspace(workspaceId: 'ws-1', path: fixture.root.path),
        instruction: 'implement the calculator add function',
        timeoutSeconds: 60,
        permittedScope: 'lib/ only',
      );

  /// Writes a script that exits non-zero unless the process was started in
  /// [expected]. A row's `resultPath` records what the coordinator RESOLVED; this
  /// proves the process actually RAN there, which a resolution alone cannot.
  ///
  /// [expected] must be symlink-RESOLVED. `Directory.systemTemp` lives under
  /// `/var`, which macOS symlinks to `/private/var`, and a spawned process
  /// reports `Directory.current.path` already resolved — comparing it against
  /// the unresolved path fails for EVERY check and therefore proves nothing.
  ///
  /// One script PER [expected]: a plan's checks are all constructed before any
  /// of them runs, so a single shared script path would have every check
  /// reading the LAST expectation written to it.
  String cwdAssertScript(String expected) {
    final name = expected.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    final file = File('${fixture.root.path}/tool/cwd_assert_$name.dart');
    file.writeAsStringSync('''
import 'dart:io';

void main() {
  final actual = Directory.current.path;
  if (actual != '$expected') {
    stderr.writeln('ran in \$actual, expected $expected');
    exitCode = 1;
  }
}
''');
    return '${file.path}';
  }

  /// The workspace root as a spawned process will report it — resolved.
  String realRoot() => fixture.root.resolveSymbolicLinksSync();

  /// A check that asserts it ran in [relativeToRoot] inside the workspace.
  List<String> cwdAssertCommand(String relativeToRoot) => [
    Platform.resolvedExecutable,
    cwdAssertScript(
      relativeToRoot == '.' ? realRoot() : '${realRoot()}/$relativeToRoot',
    ),
  ];

  /// A script that always fails — used as a `setupCommand`.
  String alwaysFailsScript() {
    final file = File('${fixture.root.path}/tool/always_fails.dart');
    file.writeAsStringSync(
      'void main() {\n'
      '  print("setup refused");\n'
      '  exitCode = 1;\n'
      '}\n',
    );
    return file.path;
  }

  const String missingTool = 'shipit-no-such-verifier-binary-7f3a';

  group('the plan carries a list of checks, not one command', () {
    test('the legacy single-check API still builds exactly one check', () {
      final plan = VerificationPlan(
        command: ['dart', 'analyze'],
        setupCommand: ['dart', 'pub', 'get'],
        checkName: 'dart_analyze_root',
      );

      expect(plan.checks, hasLength(1));
      expect(plan.checks.single.command, ['dart', 'analyze']);
      expect(plan.checks.single.setupCommand, ['dart', 'pub', 'get']);
      expect(plan.checks.single.checkName, 'dart_analyze_root');
      expect(
        plan.checks.single.workingDirectory,
        VerificationCheck.workspaceRootWorkingDirectory,
        reason:
            'a check that names no directory means the workspace root — '
            'the only directory the verifier used before this field existed',
      );
    });

    test('the default plan is still `dart test` named `dart_test`', () {
      final plan = VerificationPlan();
      expect(plan.command, ['dart', 'test']);
      expect(plan.checkName, 'dart_test');
      expect(plan.setupCommand, isNull);
      expect(plan.checks, hasLength(1));
    });

    test('several checks are carried in declaration order', () {
      final plan = VerificationPlan(
        checks: [
          const VerificationCheck(
            command: [
              'dart',
              'format',
              '--output=none',
              '--set-exit-if-changed',
              '.',
            ],
            checkName: 'dart_format_repo_root',
          ),
          const VerificationCheck(
            command: ['dart', 'analyze'],
            checkName: 'dart_analyze_per_package_root',
            workingDirectory: 'packages/execution_coordinator',
          ),
          const VerificationCheck(
            command: ['flutter', 'test'],
            checkName: 'flutter_test_apps_control_plane',
            workingDirectory: 'apps/control_plane',
          ),
        ],
      );

      expect(plan.checks.map((c) => c.checkName), [
        'dart_format_repo_root',
        'dart_analyze_per_package_root',
        'flutter_test_apps_control_plane',
      ]);
      expect(plan.checks.last.workingDirectory, 'apps/control_plane');
    });

    test('the check list cannot be mutated after construction', () {
      final plan = VerificationPlan();
      expect(
        () => plan.checks.add(
          const VerificationCheck(command: ['x'], checkName: 'injected'),
        ),
        throwsUnsupportedError,
        reason:
            'a plan whose list is mutable is a plan whose id map can '
            'silently grow a duplicate key at runtime',
      );
    });

    test('a plan carrying no check is refused', () {
      expect(
        () => VerificationPlan(checks: []),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message.toString(),
            'message',
            contains('verificationPlan: null'),
          ),
        ),
        reason:
            'a plan that verifies nothing and a null plan mean the same '
            'thing to the coordinator, and null already says it',
      );
    });

    test('two checks sharing a check name are refused', () {
      // They would write two rows under ONE verification id, and the second
      // would overwrite the first — the collision this whole change exists to
      // make impossible.
      expect(
        () => VerificationPlan(
          checks: [
            const VerificationCheck(command: ['a'], checkName: 'dup'),
            const VerificationCheck(command: ['b'], checkName: 'dup'),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a check name that could break the id scheme is refused', () {
      for (final bad in [
        'dart-test',
        'DartTest',
        'dart test',
        'dart.test',
        '',
      ]) {
        expect(
          () => VerificationPlan(
            checks: [
              VerificationCheck(command: const ['a'], checkName: bad),
            ],
          ),
          throwsA(isA<ArgumentError>()),
          reason: '"$bad" cannot appear in a checkName',
        );
      }
    });

    test('an absolute working directory is refused', () {
      expect(
        () => VerificationPlan(
          checks: [
            const VerificationCheck(
              command: ['a'],
              checkName: 'escapes',
              workingDirectory: '/etc',
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
        reason: 'a check must run inside the execution workspace',
      );
    });

    test('a non-positive timeout is refused at construction', () {
      // Decision `5c9e2b74` gave checks a timeout so the two formerly-withheld
      // ones could carry bounds larger than the verifier's 2-minute default.
      // A zero or negative bound would silently mean "kill immediately" — a
      // check that can never produce a verdict while LOOKING configured — so
      // the plan refuses it here, before any execution starts, rather than
      // discovering it as a permanently-killed check.
      for (final bad in const [Duration.zero, Duration(seconds: -1)]) {
        expect(
          () => VerificationPlan(
            checks: [
              VerificationCheck(
                command: const ['a'],
                checkName: 'non_positive',
                timeout: bad,
              ),
            ],
          ),
          throwsA(isA<ArgumentError>()),
          reason:
              '"$bad" cannot bound a check that is meant to produce a '
              'verdict',
        );
      }
      // And the positive case still constructs: the validation refuses only
      // the bad values, not the feature.
      expect(
        () => VerificationPlan(
          checks: [
            const VerificationCheck(
              command: ['a'],
              checkName: 'bounded',
              timeout: Duration(minutes: 1),
            ),
          ],
        ),
        returnsNormally,
      );
    });

    test('reading the single-check accessors on a multi-check plan throws', () {
      final plan = VerificationPlan(
        checks: [
          const VerificationCheck(command: ['a'], checkName: 'one'),
          const VerificationCheck(command: ['b'], checkName: 'two'),
        ],
      );
      expect(() => plan.command, throwsStateError);
      expect(() => plan.checkName, throwsStateError);
      expect(() => plan.setupCommand, throwsStateError);
    });
  });

  group(
    'a check working directory resolves against the execution workspace',
    () {
      test(
        'the workspace root marker resolves to the workspace root itself',
        () {
          const check = VerificationCheck(
            command: ['a'],
            checkName: 'root_check',
          );
          expect(check.resolveAgainst('/ws/abc'), '/ws/abc');
        },
      );

      test('a trailing separator on the workspace is not doubled', () {
        const check = VerificationCheck(
          command: ['a'],
          checkName: 'pkg_check',
          workingDirectory: 'packages/x',
        );
        expect(check.resolveAgainst('/ws/abc/'), '/ws/abc/packages/x');
        expect(check.resolveAgainst('/ws/abc'), '/ws/abc/packages/x');
      });

      test(
        'the same check resolves differently in two different workspaces',
        () {
          const check = VerificationCheck(
            command: ['a'],
            checkName: 'pkg_check',
            workingDirectory: 'apps/control_plane',
          );
          expect(check.resolveAgainst('/ws/one'), '/ws/one/apps/control_plane');
          expect(check.resolveAgainst('/ws/two'), '/ws/two/apps/control_plane');
        },
      );
    },
  );

  group('the verification id scheme cannot collide', () {
    const format = VerificationCheck(command: ['a'], checkName: 'dart_test');
    const analyze = VerificationCheck(
      command: ['b'],
      checkName: 'dart_analyze_per_package_root',
    );

    test('it is a function of the execution and the check name alone', () {
      // A re-run of the same execution, even with a different command or a
      // different directory, targets the SAME key — which is what makes a
      // re-run an idempotent overwrite rather than a second row.
      const rerun = VerificationCheck(
        command: ['totally', 'different'],
        checkName: 'dart_test',
        workingDirectory: 'lib',
      );
      expect(
        rerun.verificationIdFor('exec-1'),
        format.verificationIdFor('exec-1'),
      );
      expect(rerun.verificationIdFor('exec-1'), 'ver-exec-1-dart_test');
    });

    test('two checks of one execution never share an id', () {
      final ids = {
        format.verificationIdFor('exec-1'),
        analyze.verificationIdFor('exec-1'),
      };
      expect(ids, hasLength(2));
    });

    test('two executions never share an id, even with one check name', () {
      expect(
        format.verificationIdFor('exec-1'),
        isNot(format.verificationIdFor('exec-2')),
      );
    });

    test(
      'the pairs that WOULD collide under a naive concatenation do not collide',
      () {
        // `ver-<exec>-<name>` is injective because a checkName cannot contain
        // `-` (the constructor refuses it), so the LAST `-` in the id is always
        // the separator and the pair is recoverable. These are exactly the pairs
        // that collapse under a scheme which does not constrain the name:
        // without the constraint, `ver-a-b-c` would be (exec `a-b`, check `c`)
        // AND (exec `a`, check `b-c`) at the same time.
        final executionIds = ['a', 'a-b', 'a-b-c', 'exec-1', 'exec-1-x'];
        final checkNames = ['c', 'b_c', 'x', 'dart_test', 'a'];
        final ids = <String>{};
        for (final executionId in executionIds) {
          for (final checkName in checkNames) {
            final plan = VerificationPlan(
              checks: [
                VerificationCheck(command: const ['x'], checkName: checkName),
              ],
            );
            ids.add(plan.checks.single.verificationIdFor(executionId));
          }
        }
        expect(
          ids,
          hasLength(executionIds.length * checkNames.length),
          reason:
              'every (executionId, checkName) pair must produce a distinct id',
        );
      },
    );

    test('the last separator in an id always recovers the check name', () {
      const check = VerificationCheck(
        command: ['a'],
        checkName: 'dart_format_repo_root',
      );
      final id = check.verificationIdFor('exec-with-many-dashes');
      final separator = id.lastIndexOf('-');
      expect(
        id.substring(separator + 1),
        'dart_format_repo_root',
        reason: 'this is the property that makes the scheme injective',
      );
      expect('${VerificationCheck.idPrefix}exec-with-many-dashes', isNot(id));
    });
  });

  group('a plan produces one row per check, each in its own directory', () {
    test('three checks produce three rows with three distinct ids', () async {
      await readyItem();
      fixture.implement();

      await coordinatorOf(
        VerificationPlan(
          checks: [
            VerificationCheck(
              command: cwdAssertCommand('.'),
              checkName: 'cwd_root',
            ),
            VerificationCheck(
              command: cwdAssertCommand('lib'),
              checkName: 'cwd_lib',
              workingDirectory: 'lib',
            ),
            VerificationCheck(
              command: cwdAssertCommand('tool'),
              checkName: 'cwd_tool',
              workingDirectory: 'tool',
            ),
          ],
        ),
      ).execute(request());

      final rows = await executionStore.readVerifications('exec-1');
      expect(rows, hasLength(3));
      expect(rows.map((r) => r.verificationId).toSet(), hasLength(3));
      expect(rows.map((r) => r.checkName).toSet(), {
        'cwd_root',
        'cwd_lib',
        'cwd_tool',
      });
      expect(rows.map((r) => r.verificationId).toSet(), {
        'ver-exec-1-cwd_root',
        'ver-exec-1-cwd_lib',
        'ver-exec-1-cwd_tool',
      });
    });

    test(
      'each check really ran in ITS OWN directory, and the row records it',
      () async {
        await readyItem();
        fixture.implement();

        await coordinatorOf(
          VerificationPlan(
            checks: [
              VerificationCheck(
                command: cwdAssertCommand('.'),
                checkName: 'cwd_root',
              ),
              VerificationCheck(
                command: cwdAssertCommand('lib'),
                checkName: 'cwd_lib',
                workingDirectory: 'lib',
              ),
            ],
          ),
        ).execute(request());

        final rows = await executionStore.readVerifications('exec-1');
        // Both `cwdAssert` scripts exit non-zero unless the process started in
        // the directory named. Both PASSING is the proof that the per-check
        // working directory reached the spawn, not just the resolved string.
        expect(
          rows.map((r) => r.status),
          everyElement(AgentClaimStatus.passed),
          reason: rows.map((r) => '${r.checkName}: ${r.detail}').join(' | '),
        );
        expect(
          rows.map((r) => r.resultPath).toSet(),
          {fixture.root.path, '${fixture.root.path}/lib'},
          reason: 'resultPath is "the directory the validation ran in"',
        );
      },
    );

    test(
      'an existing single-check plan still produces exactly ONE row',
      () async {
        await readyItem();
        fixture.implement();

        await coordinatorOf(
          VerificationPlan(command: fixture.verifyCommand()),
        ).execute(request());

        final rows = await executionStore.readVerifications('exec-1');
        expect(
          rows,
          hasLength(1),
          reason:
              'compatibility: the whole pre-existing API is a one-check plan',
        );
        expect(rows.single.checkName, 'dart_test');
        expect(rows.single.command, fixture.verifyCommand().join(' '));
        expect(
          rows.single.resultPath,
          fixture.root.path,
          reason:
              'a check declaring the workspace root resolves to the workspace '
              'root, so this column is unchanged for every pre-existing plan',
        );
        expect(rows.single.verificationId, 'ver-exec-1-dart_test');
      },
    );

    test('the aggregate status is a failure if ANY check failed', () async {
      await readyItem();
      fixture.implement();

      await coordinatorOf(
        VerificationPlan(
          checks: [
            VerificationCheck(
              command: fixture.verifyCommand(),
              checkName: 'passes',
            ),
            VerificationCheck(
              command: [
                Platform.resolvedExecutable,
                '${fixture.root.path}/tool/always_fails.dart',
              ],
              checkName: 'fails',
            ),
          ],
        ),
      ).execute(request());

      final rows = await executionStore.readVerifications('exec-1');
      expect(rows, hasLength(2));
      expect(
        rows.firstWhere((r) => r.checkName == 'fails').status,
        AgentClaimStatus.failed,
      );
      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.agentFailed,
        reason:
            'any independent check refuting the claim refuses the completion',
      );
      final history = await workflowEngine.transitionHistory('wi-1');
      final settled = history.lastWhere(
        (t) => t.toState == WorkItemState.agentFailed,
      );
      expect(
        settled.reason,
        rows.firstWhere((r) => r.checkName == 'fails').detail,
        reason:
            'the PERSISTED reason names the check that refuted, not the '
            'first row read back from the store',
      );
    });

    test('all checks passing still reaches agentCompleted', () async {
      await readyItem();
      fixture.implement();

      await coordinatorOf(
        VerificationPlan(
          checks: [
            VerificationCheck(
              command: fixture.verifyCommand(),
              checkName: 'passes_one',
            ),
            VerificationCheck(
              command: fixture.verifyCommand(),
              checkName: 'passes_two',
            ),
          ],
        ),
      ).execute(request());

      expect(await executionStore.readVerifications('exec-1'), hasLength(2));
      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.agentCompleted,
      );
    });
  });

  group('the completion event reports an AGGREGATE, never the first row', () {
    /// The coordinator's own completion event — the one carrying the
    /// `verificationStatus` KEY.
    ///
    /// Selected by the key, not by `type == executionCompleted`: the agent
    /// session publishes its own `executionCompleted {status: completed}`
    /// first, and taking the first event of that type reads the AGENT's success
    /// claim instead of the platform's verdict over it.
    Future<Object?> verificationStatusInEvent(String executionId) async {
      final events = await executionStore.readEvents(executionId);
      final coordinatorEvent = events.lastWhere(
        (e) => e.payload?.containsKey('verificationStatus') ?? false,
        orElse: () => throw StateError(
          'the coordinator published no completion event carrying '
          '`verificationStatus`, so there is no aggregate to read',
        ),
      );
      return coordinatorEvent.payload?['verificationStatus'];
    }

    test(
      'one failing check out of two reports `failed`, not `passed`',
      () async {
        await readyItem();
        fixture.implement();

        await coordinatorOf(
          VerificationPlan(
            checks: [
              VerificationCheck(
                command: fixture.verifyCommand(),
                checkName: 'passes',
              ),
              VerificationCheck(
                command: [Platform.resolvedExecutable, alwaysFailsScript()],
                checkName: 'fails',
              ),
            ],
          ),
        ).execute(request());

        expect(
          await verificationStatusInEvent('exec-1'),
          AgentClaimStatus.failed.wire,
          reason:
              'with several checks, the first row\'s status is not the '
              'plan\'s verdict — a reader would read a plan with one failing '
              'check as green',
        );
      },
    );

    test('no check able to run reports NOTHING, not `passed`', () async {
      await readyItem();
      fixture.implement();

      await coordinatorOf(
        VerificationPlan(
          checks: [
            const VerificationCheck(
              command: ['dart', 'test'],
              checkName: 'missing_dir_check',
              workingDirectory: 'apps/control_plane',
            ),
            VerificationCheck(
              command: const [missingTool],
              checkName: 'missing_tool_check',
            ),
          ],
        ),
      ).execute(request());

      expect(
        await executionStore.readVerifications('exec-1'),
        isEmpty,
        reason: 'precondition: nothing was observed',
      );
      expect(
        await verificationStatusInEvent('exec-1'),
        isNull,
        reason:
            'an event that reports `passed` for zero observed checks is the '
            'same false claim as a passing row, in a channel a gate may read',
      );
    });
  });

  group('a check that COULD NOT run leaves no row', () {
    // ## THIS IS THE HONESTY CONSTRAINT, AS CODE.
    //
    // Each of these would, under a naive "always write a row" implementation,
    // produce either a passing row (a check that never ran, reported as green)
    // or a failing row (an environment problem reported as a verdict about the
    // work). Both are false. The correct record is ABSENCE — and absence is
    // only useful if it is really absence, so every assertion below reads the
    // PERSISTED rows and additionally refuses any row at all for the check
    // that could not run.

    test(
      'a check whose working directory is not in the workspace writes NO row',
      () async {
        await readyItem();
        fixture.implement();

        await coordinatorOf(
          VerificationPlan(
            checks: [
              const VerificationCheck(
                command: ['dart', 'test'],
                checkName: 'flutter_test_apps_control_plane',
                // This workspace has no Flutter app. The declared check cannot
                // run here at all.
                workingDirectory: 'apps/control_plane',
              ),
            ],
          ),
        ).execute(request());

        final rows = await executionStore.readVerifications('exec-1');
        expect(
          rows,
          isEmpty,
          reason:
              'a passing row here would be a green light for a check nobody '
              'ran, which is the exact failure the gate exists to detect',
        );
      },
    );

    test('a check whose tool is not installed writes NO row', () async {
      await readyItem();
      fixture.implement();

      await coordinatorOf(
        VerificationPlan(
          checks: [
            VerificationCheck(
              command: const [missingTool],
              checkName: 'absent_tool',
            ),
          ],
        ),
      ).execute(request());

      expect(await executionStore.readVerifications('exec-1'), isEmpty);
    });

    test('a check whose setup step failed writes NO row', () async {
      await readyItem();
      fixture.implement();

      await coordinatorOf(
        VerificationPlan(
          checks: [
            VerificationCheck(
              command: fixture.verifyCommand(),
              checkName: 'blocked_by_setup',
              setupCommand: [Platform.resolvedExecutable, alwaysFailsScript()],
            ),
          ],
        ),
      ).execute(request());

      expect(
        await executionStore.readVerifications('exec-1'),
        isEmpty,
        reason:
            'the check never started; the setup failure is an environment '
            'fact, not a verdict on the work',
      );
    });

    test(
      'a plan of which only SOME checks can run writes exactly the rows that ran',
      () async {
        await readyItem();
        fixture.implement();

        await coordinatorOf(
          VerificationPlan(
            checks: [
              const VerificationCheck(
                command: ['dart', 'test'],
                checkName: 'missing_dir_check',
                workingDirectory: 'apps/control_plane',
              ),
              VerificationCheck(
                command: const [missingTool],
                checkName: 'missing_tool_check',
              ),
              VerificationCheck(
                command: fixture.verifyCommand(),
                checkName: 'ran_check',
              ),
            ],
          ),
        ).execute(request());

        final rows = await executionStore.readVerifications('exec-1');
        expect(
          rows.map((r) => r.checkName),
          ['ran_check'],
          reason:
              'the two checks that could not run are ABSENT, and the one '
              'that ran is present — so a reader can tell the difference '
              'between "passed" and "was never attempted"',
        );
        expect(rows.single.status, AgentClaimStatus.passed);
      },
    );

    test('a check that RAN and FAILED still writes a FAILING row — absence is '
        'never used for a verdict that was observed', () async {
      await readyItem();
      fixture.implement();
      fixture.makeVerifyImpossible();

      await coordinatorOf(
        VerificationPlan(command: fixture.verifyCommand()),
      ).execute(request());

      final rows = await executionStore.readVerifications('exec-1');
      expect(
        rows,
        hasLength(1),
        reason:
            'if this became empty, a real refutation would be '
            'indistinguishable from a check that never ran, and the gate '
            'could not fail closed on either',
      );
      expect(rows.single.status, AgentClaimStatus.failed);
    });

    test('a check that BLOWS its own timeout writes a FAILING row — never '
        'absent, never passed (decision 5c9e2b74)', () async {
      // ## THE TIMEOUT IS A BOUND ON FAILURE, NOT AN ESCAPE FROM VERDICT.
      //
      // The two activated checks that used to be withheld (the server runner
      // and `flutter test`) now carry timeouts of 25 and 10 minutes. If a
      // timeout wrote NO row, the record could not distinguish "the check was
      // killed for taking too long" from "the check never started" — and a
      // killed check is exactly a check that FAILED to demonstrate anything.
      // `WorkspaceVerifier._run` kills with SIGKILL after the bound and
      // reports `ran: true`, `passed: false`; this pins the coordinator's
      // persistence of that outcome.
      await readyItem();
      fixture.implement();

      final sleeper = File('${fixture.root.path}/tool/sleeper.dart')
        ..writeAsStringSync(
          "import 'dart:async';\n"
          'void main() {\n'
          "  Timer(const Duration(seconds: 30), () {});\n"
          '}\n',
        );

      await coordinatorOf(
        VerificationPlan(
          checks: [
            VerificationCheck(
              command: [Platform.resolvedExecutable, sleeper.path],
              checkName: 'hangs',
              timeout: const Duration(seconds: 1),
            ),
          ],
        ),
      ).execute(request());

      final rows = await executionStore.readVerifications('exec-1');
      expect(
        rows,
        hasLength(1),
        reason:
            'a check that started and overran is a check that RAN and FAILED; '
            'its row must exist so the gate can fail on it rather than read '
            'silence as absence',
      );
      expect(
        rows.single.status,
        AgentClaimStatus.failed,
        reason: 'a timeout must never be a passing verdict',
      );
      expect(
        rows.single.detail,
        contains('Command exceeded 1s and was killed.'),
        reason:
            'the persisted row must say the check was KILLED FOR TIME, not '
            'merely fail — a bare failure is indistinguishable from a bad exit',
      );
    });

    test('a plan shaped like the per-root SWEEP (f3a81c27) writes one row per '
        'root that ran, in plan order', () async {
      // ## WHY THIS SHAPE, AND NOT THREE CHECKS
      //
      // `implementationVerificationPlan` expresses `dart analyze` and
      // `dart test` as ONE CHECK PER PACKAGE ROOT (32 checks since decisions
      // `5c9e2b74` + `8d4a1f53`, was 30 under `f3a81c27`), so the coordinator
      // must behave with a plan whose
      // checks differ only by working directory. This is that shape at
      // fixture scale: two roots that exist, one that does not, and a check
      // whose tool is absent. What it pins is that the store gains EXACTLY
      // one row per check that ran, NAMED by check name (so a reader can
      // tell which root it was), and that the two that could not run leave
      // nothing — the property the gate reads.
      await readyItem();
      fixture.implement();
      Directory('${fixture.root.path}/packages/a').createSync(recursive: true);
      Directory('${fixture.root.path}/packages/b').createSync(recursive: true);

      await coordinatorOf(
        VerificationPlan(
          checks: [
            VerificationCheck(
              command: fixture.verifyCommand(),
              checkName: 'dart_analyze_packages_a',
              workingDirectory: 'packages/a',
            ),
            VerificationCheck(
              command: fixture.verifyCommand(),
              checkName: 'dart_analyze_packages_b',
              workingDirectory: 'packages/b',
            ),
            const VerificationCheck(
              command: ['dart', 'test'],
              checkName: 'dart_test_packages_missing',
              workingDirectory: 'packages/missing',
            ),
            VerificationCheck(
              command: const [missingTool],
              checkName: 'dart_test_absent_tool',
              workingDirectory: 'packages/a',
            ),
          ],
        ),
      ).execute(request());

      final rows = await executionStore.readVerifications('exec-1');
      expect(
        rows.map((r) => r.checkName),
        ['dart_analyze_packages_a', 'dart_analyze_packages_b'],
        reason:
            'one row per root that ran, in plan order, named so a reader '
            'knows WHICH root; the missing-directory and absent-tool checks '
            'leave nothing',
      );
      expect(
        rows.first.resultPath,
        '${fixture.root.path}/packages/a',
        reason:
            'the row records the directory THIS check ran in, not the '
            'workspace root — which is what makes a per-root sweep legible. '
            'It is the UNRESOLVED path the workspace was addressed by (the '
            'fixture root), not the process-resolved one',
      );
    });

    test('no check able to run is NOT a failure — and says nothing', () async {
      await readyItem();
      // Deliberately NOT implemented: nothing ran, so nothing has a verdict.

      await coordinatorOf(
        VerificationPlan(
          checks: [
            const VerificationCheck(
              command: ['dart', 'test'],
              checkName: 'missing_dir_check',
              workingDirectory: 'apps/control_plane',
            ),
            VerificationCheck(
              command: const [missingTool],
              checkName: 'missing_tool_check',
            ),
          ],
        ),
      ).execute(request());

      expect(await executionStore.readVerifications('exec-1'), isEmpty);
      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.agentCompleted,
        reason:
            'unchanged from the no-plan case: manufacturing a failure for '
            'a check nobody ran would strand the item on nothing',
      );
    });
  });

  group('a repeated completion of the same execution cannot collide', () {
    test('the late-completion short-circuit writes NO row, so a re-run of the '
        'same execution cannot add a second row under any id', () async {
      await readyItem();

      final wedged = FakeAgentSession(
        executionId: 'exec-1',
        workItemId: 'wi-1',
        behavior: FakeBehavior.neverTerminate,
        sessionId: 'ses-wedged',
      );
      final plan = VerificationPlan(
        checks: [
          VerificationCheck(
            command: fixture.verifyCommand(),
            checkName: 'ran_one',
          ),
          VerificationCheck(
            command: fixture.verifyCommand(),
            checkName: 'ran_two',
          ),
        ],
      );
      final pending = coordinatorOf(plan, session: wedged).execute(request());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Settle the durable row elsewhere, exactly as
      // `verification_gated_completion_test.dart` does, so the completion
      // below arrives with `alreadySettled: true`.
      final open = await executionStore.readExecution('exec-1');
      await executionStore.saveExecution(
        open.copyWith(
          status: AgentSessionStatus.orphaned,
          reason: 'decided elsewhere',
          completedAt: DateTime.now(),
          version: open.version + 1,
        ),
        expectedVersion: open.version,
      );

      wedged.emitLateCompletion();
      await pending;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        await executionStore.readVerifications('exec-1'),
        isEmpty,
        reason:
            'the second pass over the same execution writes nothing, so '
            'there is no second row to collide with the first',
      );
    });

    test(
      're-saving a row under the same id overwrites it in place, in BOTH stores',
      () async {
        // This is the upsert every store performs on a repeated verdict
        // (`_verifications[verificationId] = verification`, and
        // `ON CONFLICT ("verificationId") DO UPDATE` in Postgres). Asserted
        // here so the compatibility claim is measured, not argued.
        PlatformVerification row(String id, AgentClaimStatus status) =>
            PlatformVerification(
              verificationId: id,
              executionId: 'exec-1',
              workItemId: 'wi-1',
              checkName: 'ran_one',
              status: status,
              mechanism: 'test',
              command: 'true',
              capturedAt: DateTime.now(),
            );

        final inMemory = InMemoryExecutionStore();
        for (final store in <ExecutionStore>[inMemory]) {
          await store.saveVerification(
            row('ver-exec-1-ran_one', AgentClaimStatus.failed),
          );
          await store.saveVerification(
            row('ver-exec-1-ran_one', AgentClaimStatus.passed),
          );
          await store.saveVerification(
            row('ver-exec-1-ran_two', AgentClaimStatus.passed),
          );
          final rows = await store.readVerifications('exec-1');
          expect(
            rows,
            hasLength(2),
            reason: 'one row per check, not per verdict',
          );
          expect(
            rows
                .firstWhere((r) => r.verificationId == 'ver-exec-1-ran_one')
                .status,
            AgentClaimStatus.passed,
            reason: 'the latest verdict for a check wins at its own key',
          );
        }
      },
    );
  });

  group('every store keeps working with several rows per execution', () {
    PlatformVerification row(String id, String checkName) =>
        PlatformVerification(
          verificationId: id,
          executionId: 'exec-1',
          workItemId: 'wi-1',
          checkName: checkName,
          status: AgentClaimStatus.passed,
          mechanism: 'test',
          command: 'true',
          capturedAt: DateTime.now(),
          resultPath: '/ws/abc/packages/$checkName',
        );

    test(
      'InMemoryExecutionStore indexes by verification id and keeps them all',
      () async {
        final store = InMemoryExecutionStore();
        for (final name in [
          'dart_format_repo_root',
          'dart_analyze_pkg',
          'flutter_test',
        ]) {
          await store.saveVerification(row('ver-exec-1-$name', name));
        }
        expect(await store.readVerifications('exec-1'), hasLength(3));
        expect(
          (await store.readVerifications('other-exec')),
          isEmpty,
          reason: 'rows are still scoped to their execution',
        );
      },
    );

    test(
      'FileJsonExecutionStore round-trips every row across a process exit',
      () async {
        final file = File(
          '${Directory.systemTemp.path}/multi_check_store_${pid}_'
          '${DateTime.now().microsecondsSinceEpoch}.json',
        );
        addTearDown(() {
          if (file.existsSync()) file.deleteSync();
        });

        final before = FileJsonExecutionStore(file);
        for (final name in [
          'dart_format_repo_root',
          'dart_analyze_pkg',
          'flutter_test',
        ]) {
          await before.saveVerification(row('ver-exec-1-$name', name));
        }

        // A BRAND NEW store over the same File is a process-exit round trip: the
        // rows exist only because `_persist` wrote them and `_load` read them.
        final after = FileJsonExecutionStore(file);
        final rows = await after.readVerifications('exec-1');
        expect(rows, hasLength(3));
        expect(rows.map((r) => r.verificationId).toSet(), {
          'ver-exec-1-dart_format_repo_root',
          'ver-exec-1-dart_analyze_pkg',
          'ver-exec-1-flutter_test',
        });
        expect(rows.map((r) => r.resultPath).toSet(), hasLength(3));
      },
    );
  });
}
