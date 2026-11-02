import 'dart:io';
import 'dart:isolate';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:control_plane_server/server.dart'
    show
        buildImplementationExecutionCoordinator,
        buildTriageExecutionCoordinator,
        checkSlugFor,
        dartTestSweepRoots,
        implementationVerificationPlan,
        perExecutionValidationChecks,
        perExecutionValidationChecksNotActivated,
        triageVerificationPlan,
        verificationPlanForRole,
        workspaceMemberRoots;
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart' show AgentRole;
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

/// `OD-6` + `f3a81c27` — the role-scoped IMPLEMENTATION [VerificationPlan].
///
/// ## WHAT THIS FILE PROVES, AND WHY IT READS AGENTS.md AS TEXT
///
/// The gate this plan exists for, `declared-validation-outcome` (design §3.1
/// F4), compares a persisted row's `command` to a declared command by **string
/// equality** with `commandMatchIsExact: true`. A test that asserted the plan
/// against a hand-typed copy of the command would prove the copy agrees with
/// itself. So every equality below is made against the string parsed out of
/// `AGENTS.md` itself, which is the contract the plan implements.
///
/// ## WHAT IT DELIBERATELY DOES NOT CLAIM
///
/// That the plan activates the merge/release tier. It activates ALL FIVE
/// declared per-execution checks (as 32 per-root/per-runner checks) and
/// withholds none — group 'the residual is explicit, complete, and not
/// laundered' derives BOTH sides independently (the activated set FROM THE
/// PLAN, the withheld set from [perExecutionValidationChecksNotActivated]) and
/// demands they agree in both directions, so a check added to the plan without
/// being declared, a declared check dropped from the plan, or a withheld entry
/// added without dropping the check all fail loudly.
///
/// ## THE TWO DRIFT GUARDS
///
/// 1. **AGENTS.md ↔ the recorded list.** The declared checks are parsed out
///    of AGENTS.md's table and compared to [perExecutionValidationChecks] as
///    sets, so neither can be edited without the other failing.
/// 2. **the plan ↔ the pub workspace.** [workspaceMemberRoots] is parsed out
///    of the root `pubspec.yaml`'s `workspace:` block and compared for exact
///    equality, so a member added to the pubspec without its checks here — or
///    a check for a member that no longer exists — fails loudly. This is the
///    anti-narrowing guard without which the gate's completeness claim would
///    quietly become this list's opinion.
void main() {
  late List<_Row> agentsMdPerExecution;
  late List<_Row> agentsMdMergeRelease;
  late List<String> pubspecWorkspaceMembers;

  setUpAll(() async {
    final rows = _parseGateTable(await _readAgentsMd());
    agentsMdPerExecution = rows
        .where((r) => r.tier == 'per-execution')
        .toList(growable: false);
    agentsMdMergeRelease = rows
        .where((r) => r.tier == 'merge/release')
        .toList(growable: false);
    pubspecWorkspaceMembers = _parseWorkspaceMembers(
      await _readRootPubspec(),
    );
  });

  group('AGENTS.md is the contract, and the recorded checks are verbatim', () {
    test('the per-execution tier is five checks, all present in the tree', () {
      // If AGENTS.md's tier ever changes shape, this fails loudly rather than
      // letting the recorded list drift away from the contract in silence.
      expect(
        agentsMdPerExecution.length,
        5,
        reason:
            'the recorded list must track the declared tier exactly; if the '
            'tier changed, re-read AGENTS.md before touching this file',
      );
      expect(perExecutionValidationChecks, hasLength(5));
    });

    test('every recorded check string-equals an AGENTS.md row', () {
      for (final declared in perExecutionValidationChecks) {
        final row = agentsMdPerExecution.firstWhere(
          (r) => r.command == declared.command,
          orElse: () => throw StateError(
            'no AGENTS.md per-execution row declares '
            '"${declared.command}" (checkName ${declared.checkName})',
          ),
        );
        expect(
          row.workingDirectory,
          anyOf(
            equals(declared.workingDirectory),
            startsWith('${declared.workingDirectory} '),
          ),
          reason:
              'the declared cwd for ${declared.checkName} is '
              '"${declared.workingDirectory}"; AGENTS.md says '
              '"${row.workingDirectory}". The trailing text after the cwd is '
              'explanatory prose in the table, not part of the cwd.',
        );
      }
    });

    test(
      'the recorded set is exactly the declared set — nothing added, nothing '
      'dropped',
      () {
        expect(
          perExecutionValidationChecks.map((c) => c.command).toSet(),
          agentsMdPerExecution.map((r) => r.command).toSet(),
          reason:
              'a check in one list and not the other means the plan claims '
              'coverage the contract does not declare, or the contract '
              'declares coverage the plan silently ignores',
        );
      },
    );

    test('the merge/release tier is NOT recorded as per-execution', () {
      expect(
        agentsMdMergeRelease,
        isNotEmpty,
        reason:
            'AGENTS.md must still declare a merge/release row; if it vanished, '
            'the tier split this record depends on has been removed',
      );
      final integration = agentsMdMergeRelease.first.command;
      expect(
        perExecutionValidationChecks.map((c) => c.command),
        isNot(contains(integration)),
        reason:
            'decision a0e6f31c puts `make test-integration` in the '
            'merge/release tier. Recording it here would let a plan claim an '
            'integration run that this slice never performs',
      );
    });

    test('the server unit tier is the RUNNER, never a bare `dart test`', () {
      // AGENTS.md states this as a correction with a reason: `dart test` in
      // apps/server picks up test/integration/, which needs a live database.
      // The runner is what makes the per-execution gate honest there.
      final serverRow = agentsMdPerExecution.firstWhere(
        (r) => r.workingDirectory.startsWith('apps/server'),
      );
      expect(serverRow.command, 'dart run tool/run_unit_tests.dart');
    });
  });

  group('the anti-narrowing guard: the plan tracks the pub workspace', () {
    test('the pubspec workspace block parsed as expected', () {
      expect(
        pubspecWorkspaceMembers,
        hasLength(16),
        reason:
            'the root pubspec.yaml is the source of truth for the member set; '
            'if its shape changed, re-read it before touching this file',
      );
    });

    test('every workspace member appears in the expansion source', () {
      expect(
        workspaceMemberRoots.toSet(),
        pubspecWorkspaceMembers.toSet(),
        reason:
            'a member in the pubspec and not in the plan means that member is '
            'never analyzed or tested on any execution, and the gate would '
            'still read green because no declared check names it',
      );
    });

    test('the expansion source has no member the pubspec does not declare', () {
      expect(
        workspaceMemberRoots.where(
          (r) => !pubspecWorkspaceMembers.contains(r),
        ),
        isEmpty,
        reason:
            'a root in the plan that the pubspec does not declare would spawn '
            '`dart pub get` in a directory that is not a workspace member',
      );
    });

    test('the two expansions are ordered the same way as the pubspec', () {
      // Ordered lists, not just sets: the plan's checks carry ids derived from
      // position-independent names, so order is not load-bearing for identity —
      // but it makes the plan readable against the pubspec, and a reordering
      // that is not a deliberate edit should fail.
      expect(workspaceMemberRoots, pubspecWorkspaceMembers);
    });

    test('the analyze checks are exactly one per workspace member', () {
      final analyzeSlugs = _analyzeCheckNames();
      expect(
        analyzeSlugs,
        workspaceMemberRoots.map(checkSlugFor).toSet(),
        reason:
            'the analyze sweep is one check per member; a member with no '
            'analyze check is a coverage hole the gate cannot see',
      );
    });

    test(
      'the dart-test sweep excludes exactly the two declared roots — '
      'computed both ways from the source',
      () {
        // ## THE PIN THE COUNTS CANNOT BE.
        //
        // Counts (16 members / swept members / check total) stay green when
        // one exclusion is SWAPPED for another: the sweep shrinks by one
        // root and grows by another, and every count is unchanged. Only the
        // SET equality notices, so it is derived both ways here, from the
        // source lists, with the two names supplied independently as
        // literals:
        //
        // * way 1 derives the exclusions (members minus sweep) and demands
        //   they are EXACTLY the two declared names — a third exclusion, a
        //   swapped one, or one of the two vanishing fails it;
        // * way 2 derives the sweep (members minus the declared names) and
        //   demands the list equals it — this is the direction that also
        //   rejects a sweep root that is not a workspace member at all,
        //   which way 1 cannot see, and the direction
        //   [dartTestSweepRoots]'s doc states ("must equal
        //   [workspaceMemberRoots] minus exactly those two names").
        const declaredExclusions = {'apps/server', 'apps/control_plane'};

        // Way 1 — the exclusion set DERIVED from the two source lists.
        expect(
          workspaceMemberRoots.toSet().difference(dartTestSweepRoots.toSet()),
          declaredExclusions,
          reason:
              'members minus sweep must be EXACTLY {apps/server, '
              'apps/control_plane}. A third root missing from the sweep is '
              'an exclusion nobody declared; one of the two present in the '
              'sweep un-excludes a root whose reason has not changed. '
              'Swapping one exclusion for another keeps every count in this '
              'file green — only this set equality breaks.',
        );

        // Way 2 — the sweep DERIVED from the members minus the names.
        expect(
          dartTestSweepRoots.toSet(),
          workspaceMemberRoots.toSet().difference(declaredExclusions),
          reason:
              'the sweep must equal the workspace members minus exactly the '
              'two declared exclusions. This direction also fails for a '
              'sweep entry that is not a workspace member at all, which '
              'leaves members-minus-sweep unchanged and would pass way 1.',
        );
      },
    );

    test(
      'packages/control_plane_client has a test/ directory AND sits in the '
      'sweep — the pair the no-dormant-suite rule rests on',
      () async {
        // ## THE PIN THE EXCLUSION'S REMOVAL RESTS ON.
        //
        // This root was excluded while it had no `test/` directory: `dart
        // test` exits 65 for an absence, and a check that always failed on
        // an absence reported a verdict about work never observed. The pin
        // used to assert the directory's absence; the directory now EXISTS,
        // so the exclusion's reason is gone and the root is back in
        // [dartTestSweepRoots]. Both halves are pinned together, because
        // either alone leaves a dormant suite: a `test/` directory without a
        // sweep entry runs nothing on any execution, and a sweep entry
        // without a directory fails every execution on the 65.
        final repoRoot = await _repoRoot();
        final testPath = '${repoRoot.path}/packages/control_plane_client/test';
        expect(
          FileSystemEntity.typeSync(testPath),
          FileSystemEntityType.directory,
          reason:
              'packages/control_plane_client is in dartTestSweepRoots, so '
              'dart test runs there on every execution — without the '
              'directory that check exits 65, failing every run for an '
              'absence, which is the condition the no-row honesty rule '
              'exists for.',
        );
        expect(
          dartTestSweepRoots,
          contains('packages/control_plane_client'),
          reason:
              'packages/control_plane_client/test exists but the root is '
              'not swept, so nothing in it runs on any execution — a '
              'dormant suite is exactly the narrowing defect this guard '
              'exists to catch.',
        );
      },
    );
  });

  group('every check name is a valid verification-id component', () {
    test(r'names match ^[a-z0-9_]+$ and are unique', () {
      // `VerificationPlan` enforces this at construction, but asserting it here
      // names WHY: the name is half of `ver-<executionId>-<checkName>`, and the
      // id is only injective if the name cannot contain the `-` separator.
      final names = implementationVerificationPlan.checks
          .map((c) => c.checkName)
          .toList();
      expect(names.toSet(), hasLength(names.length));
      for (final name in names) {
        expect(
          name,
          matches(RegExp(r'^[a-z0-9_]+$')),
          reason:
              'check name "$name" would break the verification id scheme the '
              'store keys rows by',
        );
      }
    });

    test('slugs use the FULL path, so two basenames cannot collide', () {
      // `packages/foo/bar` and `apps/bar` slugify differently because the whole
      // path is used; a basename-only slug would collide them.
      expect(checkSlugFor('packages/scheduler'), 'packages_scheduler');
      expect(checkSlugFor('apps/server'), 'apps_server');
      expect(
        checkSlugFor('packages/workflow_engine'),
        isNot(checkSlugFor('apps/workflow_engine')),
      );
    });
  });

  group('the plan\'s command strings string-equal the declared commands', () {
    // ## THIS IS THE PROOF THE GATE ACTUALLY ASKS FOR.
    //
    // `WorkspaceVerifier` persists `command.join(' ')` as the row's `command`
    // (`workspace_verifier.dart` → `VerificationOutcome.command`), and F4
    // compares that string to the declared one. So the equality below is the
    // same comparison, on the same side of the same types.
    test('the format check equals the AGENTS.md format row exactly', () {
      final declared = agentsMdPerExecution.firstWhere(
        (r) => r.command.startsWith('dart format'),
      );
      expect(
        _checksNamed('dart_format_repo_root').single.command.join(' '),
        declared.command,
        reason:
            'F4 sets commandMatchIsExact: true. Substring, token overlap or a '
            're-spelling all fail it, so this is a whole-string equality '
            'against the command parsed out of AGENTS.md',
      );
    });

    test('every analyze check carries the declared analyze command', () {
      final declared = agentsMdPerExecution.firstWhere(
        (r) => r.command == 'dart analyze',
      );
      for (final check in _checksNamedPrefix('dart_analyze_')) {
        expect(check.command.join(' '), declared.command);
      }
    });

    test('every dart-test check carries the declared dart-test command', () {
      final declared = agentsMdPerExecution.firstWhere(
        (r) => r.workingDirectory.startsWith('every package root'),
      );
      expect(declared.command, 'dart test');
      for (final check in _checksNamedPrefix('dart_test_')) {
        expect(check.command.join(' '), declared.command);
      }
    });

    test('the server runner check equals the AGENTS.md server row exactly', () {
      // Decision `8d4a1f53`'s activation of the server unit tier has to land
      // as THIS string — the one the gate compares a persisted row against —
      // not a re-spelling of it. A bare `dart test` here would both fail F4
      // and re-pick-up `test/integration/` by construction.
      final declared = agentsMdPerExecution.firstWhere(
        (r) => r.command.startsWith('dart run tool/run_unit_tests.dart'),
      );
      expect(
        _checksNamed('server_unit_tests_runner').single.command.join(' '),
        declared.command,
        reason:
            'F4 string equality: the activated server check must carry the '
            'runner command AGENTS.md declares, character for character',
      );
    });

    test(
      'the flutter check equals the AGENTS.md control-plane row exactly',
      () {
        final declared = agentsMdPerExecution.firstWhere(
          (r) => r.command == 'flutter test',
        );
        expect(
          _checksNamed(
            'flutter_test_apps_control_plane',
          ).single.command.join(' '),
          declared.command,
          reason: 'F4 string equality, same as every other activated check',
        );
      },
    );

    test('every activated check resolves packages first — measured, not '
        'assumed', () {
      // In a fresh detached worktree with no package resolution, the format
      // command exits 1 and reports 163 files changed, because the formatter
      // has no package language version and falls back to the SDK default
      // style. Each per-root check runs its own `dart pub get` so it is
      // self-contained; a check missing it would be an artifact of the
      // sandbox, not a verdict on the code.
      for (final check in implementationVerificationPlan.checks) {
        expect(
          check.setupCommand,
          ['dart', 'pub', 'get'],
          reason: '${check.checkName} must resolve its own package first',
        );
      }
    });

    test('each check runs in the root it names', () {
      expect(
        _checksNamed('dart_format_repo_root').single.workingDirectory,
        '.',
        reason: 'the format check is declared at the repository root',
      );
      for (final root in workspaceMemberRoots) {
        final check = _checksNamed('dart_analyze_${checkSlugFor(root)}').single;
        expect(check.workingDirectory, root);
      }
      for (final root in dartTestSweepRoots) {
        final check = _checksNamed('dart_test_${checkSlugFor(root)}').single;
        expect(check.workingDirectory, root);
      }
    });
  });

  group('role scoping', () {
    test('implementation roles get the implementation plan', () {
      for (final role in const [
        AgentRole.implementer,
        AgentRole.correctionImplementer,
      ]) {
        expect(
          verificationPlanForRole(role),
          same(implementationVerificationPlan),
          reason: '$role writes code into a worktree of this repository',
        );
      }
    });

    test('every other role keeps the triage plan — triage is untouched', () {
      // Looped over the enum rather than listing names, so a role added later
      // is classified by this test instead of silently inheriting by accident.
      final implementationRoles = const {
        AgentRole.implementer,
        AgentRole.correctionImplementer,
      };
      for (final role in AgentRole.values) {
        if (implementationRoles.contains(role)) continue;
        expect(
          verificationPlanForRole(role),
          same(triageVerificationPlan),
          reason: '$role must not be switched to the implementation plan',
        );
      }
    });

    test('the triage plan itself is byte-for-byte what it always was', () {
      expect(triageVerificationPlan.command, [
        'git',
        'rev-parse',
        '--verify',
        'HEAD^{commit}',
      ]);
      expect(triageVerificationPlan.checkName, 'git_worktree_head');
    });

    test('each builder attaches what the lookup says its role gets', () {
      final triage = buildTriageExecutionCoordinator(
        store: InMemoryExecutionStore(),
        workflowEngine: DurableWorkflowEngine(store: InMemoryWorkflowStore()),
        runtime: AgentRuntime(),
      );
      final implementation = buildImplementationExecutionCoordinator(
        store: InMemoryExecutionStore(),
        workflowEngine: DurableWorkflowEngine(store: InMemoryWorkflowStore()),
        runtime: AgentRuntime(),
      );

      expect(
        triage.verificationPlan!.checks.map((c) => c.command).toList(),
        [
          triageVerificationPlan.command,
        ],
        reason: 'OD-6 must not change what the triage lane is verified by',
      );
      expect(
        implementation.verificationPlan!.checks.length,
        implementationVerificationPlan.checks.length,
      );
      expect(
        implementation.verificationPlan!.checks.first.command,
        implementationVerificationPlan.checks.first.command,
      );
      expect(
        implementation.verificationPlan!.checks.map((c) => c.checkName),
        implementationVerificationPlan.checks.map((c) => c.checkName),
        reason:
            'the live defect was one plan serving every role; if these are '
            'equal to the triage plan again, role scoping has silently '
            'collapsed',
      );
    });

    test('the triage plan is still a SINGLE check', () {
      expect(triageVerificationPlan.checks, hasLength(1));
    });
  });

  group('the residual is explicit, complete, and not laundered', () {
    /// The declared check each PLAN check activates, derived from the plan
    /// alone.
    ///
    /// The two sweeps are many-to-one by design (decision `f3a81c27`: one
    /// declared `dart analyze` / `dart test` row expands to one check PER
    /// workspace root), so a per-root check maps back to its declared row by
    /// prefix; everything else maps to its own name. Anything that maps to a
    /// name AGENTS.md does not declare therefore shows up as an element the
    /// declared set does not contain — which is the reverse direction the
    /// equality below rejects.
    String declaredNameFor(String checkName) => switch (checkName) {
      _ when checkName.startsWith('dart_analyze_') =>
        'dart_analyze_per_package_root',
      _ when checkName.startsWith('dart_test_') => 'dart_test_per_package_root',
      _ => checkName,
    };

    /// The activated set, computed FROM THE PLAN — never from a hand-written
    /// list, which would only prove the list agrees with itself.
    Set<String> activatedDeclaredNames() => implementationVerificationPlan
        .checks
        .map((c) => declaredNameFor(c.checkName))
        .toSet();

    test('a declared check is activated if and only if it is not withheld', () {
      final declaredNames = perExecutionValidationChecks
          .map((c) => c.checkName)
          .toSet();
      final withheld = perExecutionValidationChecksNotActivated.keys.toSet();

      // Every withheld name must be a declared one: an invented name would
      // hide a real gap behind a fake reason.
      expect(
        withheld.difference(declaredNames),
        isEmpty,
        reason:
            'a withheld entry that AGENTS.md does not declare is a name no '
            'gate ever asked about, so withholding it proves nothing',
      );
      // Direction 1 — the plan must not activate anything undeclared.
      expect(
        activatedDeclaredNames().difference(declaredNames),
        isEmpty,
        reason:
            'a plan check that maps to no AGENTS.md row is coverage the '
            'contract never declared; the sweep mapping above must account '
            'for every check in the plan',
      );
      // Direction 2 — the iff itself: activated == declared - withheld.
      // Set equality bites BOTH ways, so a declared check neither in the plan
      // nor withheld fails, and so does one both in the plan and withheld.
      expect(
        activatedDeclaredNames(),
        declaredNames.difference(withheld),
        reason:
            'the plan\'s own checks, mapped back to declared rows, must be '
            'EXACTLY the declared set minus the withheld set. A mismatch in '
            'either direction means one side moved alone: coverage claimed '
            'without a check, or a check run without a declared contract',
      );
    });

    test(
      'the full five-check tier is activated — the withheld map is empty',
      () {
        // The end state decisions `5c9e2b74` + `8d4a1f53` produce. Replaced
        // the previous pin (`exactly three activated`, `withheld == the two
        // named checks`) — that one guarded against a map emptied WITHOUT the
        // plan filling in; this one guards the same laundering shape with the
        // activation now real, by requiring both sides to say five.
        expect(
          perExecutionValidationChecksNotActivated,
          isEmpty,
          reason:
              'no per-execution check is withheld; if an entry reappears here, '
              'the plan must drop that check too or the iff test above fails',
        );
        expect(
          activatedDeclaredNames(),
          {
            'dart_format_repo_root',
            'dart_analyze_per_package_root',
            'dart_test_per_package_root',
            'server_unit_tests_runner',
            'flutter_test_apps_control_plane',
          },
          reason:
              'all five declared rows must be derivable from the plan; a '
              'missing one is a declared check nothing runs',
        );
        expect(
          perExecutionValidationChecks.length -
              perExecutionValidationChecksNotActivated.length,
          activatedDeclaredNames().length,
          reason:
              'declared-minus-withheld and the plan-derived activated set are '
              'the two independent counts of the same claim; they must agree',
        );
      },
    );

    test('every withheld check carries a stated, measured reason', () {
      // Vacuously true while the map is empty, and deliberately kept: the
      // moment an entry returns, it must arrive with a MEASURED reason or
      // this fails. A withheld check with no reason is the shape the
      // laundering guard exists for.
      for (final entry in perExecutionValidationChecksNotActivated.entries) {
        expect(
          entry.value.trim(),
          isNotEmpty,
          reason: '${entry.key} is listed as withheld with no explanation',
        );
        expect(
          entry.value,
          contains('MEASURED'),
          reason:
              'a withheld check must say what was measured; an unmeasured '
              'reason is a guess wearing the shape of evidence',
        );
      }
    });

    test('no withheld command appears anywhere in the implementation plan', () {
      // Also vacuous while empty, and kept for the same reason: a check that
      // claims to be withheld while the plan carries its command is the
      // exact contradiction this group exists to refuse.
      for (final withheld in perExecutionValidationChecksNotActivated.keys) {
        final check = perExecutionValidationChecks.firstWhere(
          (c) => c.checkName == withheld,
        );
        expect(
          implementationVerificationPlan.checks.map((c) => c.command.join(' ')),
          isNot(contains(check.command)),
          reason:
              'the plan claims to withhold ${check.command}; if it carries it, '
              'it is misrepresenting its own coverage',
        );
      }
    });

    test(
      'the two checks that WERE withheld are activated, by name and cwd',
      () {
        // Pinned because their activation is the whole point of decisions
        // `5c9e2b74` + `8d4a1f53`: silently dropping either from the plan —
        // and thus re-withholding it, or worse, dropping it without adding
        // it to the map — fails here.
        final runner = _checksNamed('server_unit_tests_runner');
        expect(runner, hasLength(1), reason: 'the server unit tier must run');
        expect(runner.single.workingDirectory, 'apps/server');
        expect(
          runner.single.command.join(' '),
          'dart run tool/run_unit_tests.dart',
        );
        expect(
          runner.single.setupCommand,
          ['dart', 'pub', 'get'],
          reason: 'the runner resolves its own package first, like every check',
        );

        final flutter = _checksNamed('flutter_test_apps_control_plane');
        expect(
          flutter,
          hasLength(1),
          reason: 'the control-plane tier must run',
        );
        expect(flutter.single.workingDirectory, 'apps/control_plane');
        expect(flutter.single.command.join(' '), 'flutter test');
        expect(flutter.single.setupCommand, ['dart', 'pub', 'get']);
      },
    );
  });

  group('every activated check carries a timeout that fits its measurement', () {
    // ## WHY THIS GROUP EXISTS (decision `5c9e2b74`)
    //
    // A per-check timeout is a BOUND, not an exemption: below the measured
    // runtime it kills healthy checks mid-run and records a failing verdict
    // about work never judged; so far above it that it can never fire, a hung
    // command stops being a FAILING check. Both edges are pinned here against
    // the MEASURED runtimes, so neither can be moved by editing a comment.
    // The floors are the measurements themselves (from this plan's own
    // timeout table); the ceiling is the operator's bound on how long a hang
    // may wait before failing.
    const Duration ceiling = Duration(minutes: 30);

    test('no check falls back to the verifier default implicitly', () {
      for (final check in implementationVerificationPlan.checks) {
        expect(
          check.timeout,
          isNotNull,
          reason:
              '${check.checkName} declares no timeout, so it silently takes '
              'WorkspaceVerifier.defaultTimeout (2 min) — the exact budget '
              'that made two of the five declared checks unrunnable. Every '
              'activated check must name its own bound',
        );
      }
      expect(implementationVerificationPlan.checks, hasLength(33));
    });

    test(
      'every timeout clears the measured runtime of the check it bounds',
      () {
        // MEASURED (this plan's timeout table): format 28s, worst analyze 67s
        // (apps/control_plane), worst dart test 80s (execution_coordinator),
        // server runner 959.67s cold in a system-TEMP worktree (the default
        // execution location; 531s cold in the main checkout, 117s/247.6s
        // warm), flutter test 209s at base. A timeout at or below its
        // measurement would kill a healthy run.
        Duration floorFor(VerificationCheck check) {
          if (check.checkName == 'server_unit_tests_runner') {
            return const Duration(seconds: 960); // 959.67s, rounded up
          }
          if (check.checkName == 'flutter_test_apps_control_plane') {
            return const Duration(seconds: 247);
          }
          if (check.checkName.startsWith('dart_analyze_')) {
            return const Duration(seconds: 67);
          }
          if (check.checkName.startsWith('dart_test_')) {
            return const Duration(seconds: 80);
          }
          return const Duration(seconds: 28); // format, repo root
        }

        for (final check in implementationVerificationPlan.checks) {
          expect(
            check.timeout!,
            greaterThan(floorFor(check)),
            reason:
                '${check.checkName} is bounded at ${check.timeout} but was '
                'measured at ${floorFor(check)}; a shorter bound kills a '
                'healthy run and records a failure about work never judged',
          );
        }
      },
    );

    test('the two formerly-withheld checks clear the 2-minute default that '
        'blocked them', () {
      const twoMinutes = Duration(minutes: 2);
      for (final name in const [
        'server_unit_tests_runner',
        'flutter_test_apps_control_plane',
      ]) {
        final check = _checksNamed(name).single;
        expect(
          check.timeout,
          greaterThan(twoMinutes),
          reason:
              '$name was withheld because 2 minutes could not hold it; a '
              'timeout at or below that re-creates the exact blocker',
        );
      }
    });

    test('no timeout is so high a hung command can never fail', () {
      // The honesty constraint of `5c9e2b74`: a timeout must still be a
      // FAILING check. A bound beyond this ceiling would sit inside no
      // operator's expectation of "bounded", and the execution budget itself
      // (4h for implement-feature) would start deciding hangs instead of the
      // check.
      for (final check in implementationVerificationPlan.checks) {
        expect(
          check.timeout!,
          lessThanOrEqualTo(ceiling),
          reason:
              '${check.checkName} is bounded at ${check.timeout}; a hang must '
              'fail within an operator-bounded time, not ride the whole '
              'execution budget',
        );
      }
    });
  });

  group('the implementation check can FAIL — it is not a liveness probe', () {
    // ## NON-VACUITY, AND WHY IT IS THE POINT OF THE WHOLE SLICE.
    //
    // The plan this replaces was `git rev-parse --verify HEAD^{commit}`, which
    // succeeds for any checkout that has a commit — it could not fail on
    // anything an implementer wrote. This drives the REAL [WorkspaceVerifier]
    // with the REAL commands, against a disposable fixture, and shows it
    // reports `passed == false` for mis-formatted code and for an unresolved
    // package. That is the difference between a check and a liveness probe,
    // demonstrated rather than asserted.
    late Directory fixture;

    setUp(() {
      fixture = Directory(
        '${Directory.systemTemp.path}/od6_impl_plan_${pid}_'
        '${DateTime.now().microsecondsSinceEpoch}',
      )..createSync(recursive: true);
      File('${fixture.path}/pubspec.yaml').writeAsStringSync(
        'name: od6_fixture_pkg\n\n'
        'environment:\n'
        '  sdk: ">=3.12.0 <4.0.0"\n',
      );
    });

    tearDown(() {
      if (fixture.existsSync()) fixture.deleteSync(recursive: true);
    });

    Future<VerificationOutcome> verify(String command) =>
        const WorkspaceVerifier().verify(
          workingDirectory: fixture.path,
          command: command.split(' '),
          setupCommand: const ['dart', 'pub', 'get'],
        );

    test('formatted code passes', () async {
      File('${fixture.path}/main.dart').writeAsStringSync(
        "void main() {\n  print('x');\n}\n",
      );
      final outcome = await verify(
        'dart format --output=none '
        '--set-exit-if-changed .',
      );
      expect(outcome.passed, isTrue, reason: outcome.detail ?? '');
    });

    test('mis-formatted code FAILS the check', () async {
      File('${fixture.path}/main.dart').writeAsStringSync(
        "void main(){print('x');}\n",
      );
      final outcome = await verify(
        'dart format --output=none '
        '--set-exit-if-changed .',
      );
      expect(
        outcome.passed,
        isFalse,
        reason:
            'the whole point of OD-6: the implementation plan must be able to '
            'fail on what the implementer wrote. If this passes, the plan has '
            'degenerated back into a liveness probe.',
      );
      expect(outcome.exitCode, isNot(0));
    });

    test(
      'the row the coordinator would persist carries the declared string',
      () async {
        // Ties the fixture back to the gate: the persisted row's `command` is
        // `outcome.command`, so this is literally the value F4 string-compares.
        File('${fixture.path}/main.dart').writeAsStringSync(
          "void main() {\n  print('x');\n}\n",
        );
        final outcome = await verify(
          'dart format --output=none '
          '--set-exit-if-changed .',
        );
        expect(
          outcome.command,
          'dart format --output=none '
          '--set-exit-if-changed .',
        );
      },
    );
  });

  group('the production composition routes the implementation worker', () {
    test('implementWorker drives the implementation coordinator', () async {
      // What is pinned is a BINDING that no in-process harness can observe:
      // `run()` needs a live database, a live `opencode` binary and a worker
      // registry. Read as text for the same reason
      // `execution_store_wiring_test.dart` reads `lib/server.dart`.
      final source = await _readServerSource();
      final runBody = _runBody(source);

      expect(
        runBody,
        contains('CoordinatorAgentExecutionDriver(implementationCoordinator)'),
        reason:
            'the implementation worker must drive the coordinator that carries '
            'the implementation plan. If it still drives `coordinator`, the '
            'role-scoped plan is composed but never used in production and '
            'every test here passes over dead wiring.',
      );
      expect(
        runBody,
        contains(
          'CoordinatorAgentExecutionDriver(coordinator)',
        ),
        reason: 'triage and review must keep the triage coordinator',
      );
      expect(
        RegExp(
          'implementationCoordinator',
          multiLine: true,
        ).allMatches(runBody),
        hasLength(3),
        reason:
            'one `= buildImplementationExecutionCoordinator(` construction, '
            'one declaration and one driver attachment. A count other than '
            'three means the coordinator is built, discarded, or duplicated.',
      );
    });

    test(
      'the composition mounts exactly the schedulers the design authorises — '
      'no more, no fewer',
      () async {
        // OD-6 pinned this set to THREE (`sched-triage`, `sched-review`,
        // `sched-impl`) and forbade adding one, because OD-6 adds a verifier and
        // never a dispatcher. Design-governance step 8 later added the two
        // design schedulers BY DECISION (`sched-design-revision`,
        // `sched-design-review`, mounted together in `runDesignLaneTick`), so
        // the set here is the post-step-8 one. The durable value of the test is
        // unchanged: an id that is added, renamed or removed WITHOUT a matching
        // edit here fails loudly instead of shipping a scheduler nobody
        // reviewed.
        final source = await _readServerSource();
        final constructions = RegExp(
          r"Scheduler\(\s*schedulerId: '([^']+)'",
        ).allMatches(source).map((m) => m.group(1)).toList();

        expect(
          constructions,
          [
            'sched-triage',
            'sched-review',
            'sched-design-revision',
            'sched-design-review',
            'sched-impl',
          ],
          reason:
              'the schedulers `run()` builds. A new entry, a renamed id, or a '
              'different set means a scheduler was added or re-pointed without '
              'updating this test — which is the review this assertion exists '
              'to force.',
        );

        // And the implementation lane still dispatches through the SAME
        // pre-existing scheduler: OD-6 swapped the worker's coordinator, never
        // its dispatch route.
        expect(source, contains("definition: implementFeatureDefinition,"));
        expect(source, contains('final implScheduler = Scheduler('));
      },
    );
  });
}

List<VerificationCheck> _checksNamed(String name) =>
    implementationVerificationPlan.checks
        .where((c) => c.checkName == name)
        .toList(growable: false);

List<VerificationCheck> _checksNamedPrefix(String prefix) =>
    implementationVerificationPlan.checks
        .where((c) => c.checkName.startsWith(prefix))
        .toList(growable: false);

Set<String> _analyzeCheckNames() => implementationVerificationPlan.checks
    .where((c) => c.checkName.startsWith('dart_analyze_'))
    .map((c) => c.checkName.substring('dart_analyze_'.length))
    .toSet();

/// A parsed row of `AGENTS.md`'s required-validation-gates table.
class _Row {
  _Row(this.tier, this.gate, this.command, this.workingDirectory);

  final String tier;
  final String gate;

  /// The command with markdown emphasis and code ticks removed — the string the
  /// gate compares against.
  final String command;

  /// The cwd cell with the same stripping applied. Where the cell carries
  /// trailing explanatory prose the declared cwd is its first token.
  final String workingDirectory;
}

List<_Row> _parseGateTable(String markdown) {
  final rows = <_Row>[];
  for (final line in markdown.split('\n')) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) continue;
    final cells = trimmed
        .split('|')
        .sublist(1, trimmed.split('|').length - 1)
        .map((c) => _strip(c))
        .toList();
    if (cells.length < 4) continue;
    // `per-execution` / `merge/release`, after stripping `**`.
    final tier = cells[0];
    if (tier != 'per-execution' && tier != 'merge/release') continue;
    rows.add(_Row(tier, cells[1], cells[2], cells[3]));
  }
  return rows;
}

/// The member paths of the root `pubspec.yaml`'s `workspace:` block.
///
/// A deliberately small parser: it reads indented `- <path>` lines under the
/// `workspace:` key and stops at the first non-indented line. It does not try
/// to be a YAML parser — if the block's shape changes, the count assertion in
/// the test fails and a human re-reads the file, which is the intended
/// behaviour for a contract that must not drift silently.
List<String> _parseWorkspaceMembers(String pubspec) {
  final lines = pubspec.split('\n');
  final start = lines.indexWhere((l) => l.trimRight() == 'workspace:');
  if (start < 0) {
    throw StateError('no top-level `workspace:` key in the root pubspec.yaml');
  }
  final members = <String>[];
  for (var i = start + 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.isEmpty) continue;
    if (!RegExp(r'^\s+-\s+\S').hasMatch(line)) break;
    members.add(line.trim().substring(1).trim());
  }
  return members;
}

String _strip(String cell) =>
    cell.replaceAll('`', '').replaceAll('*', '').trim();

/// Reads `AGENTS.md` — located by walking up from the resolved server library
/// so the result does not depend on the working directory `dart test` ran from.
///
/// Resolution goes through `Isolate.resolvePackageUri`, the same technique
/// `triage_verification_plan_test.dart` uses: a `package:` URI cannot be turned
/// into a file path by `File.fromUri` alone.
Future<String> _readAgentsMd() async {
  var dir = await _packageDir();
  while (true) {
    final candidate = File('${dir.path}/AGENTS.md');
    if (candidate.existsSync()) return candidate.readAsStringSync();
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('could not locate AGENTS.md above ${dir.path}');
    }
    dir = parent;
  }
}

/// Reads the root `pubspec.yaml` — the same upward walk from the server
/// library, so the workspace-member set is read from the real file.
Future<String> _readRootPubspec() async {
  var dir = await _packageDir();
  while (true) {
    final candidate = File('${dir.path}/pubspec.yaml');
    // The root pubspec declares the pub workspace; a member pubspec does not.
    if (candidate.existsSync() &&
        candidate.readAsStringSync().contains('\nworkspace:')) {
      return candidate.readAsStringSync();
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('could not locate the root pubspec.yaml above $dir');
    }
    dir = parent;
  }
}

Future<Directory> _packageDir() async {
  final uri = await Isolate.resolvePackageUri(
    Uri.parse('package:control_plane_server/server.dart'),
  );
  if (uri == null) {
    throw StateError('could not resolve the server composition source');
  }
  return File.fromUri(uri).parent;
}

/// The repository root — found by the same upward walk [_readAgentsMd] uses
/// (the directory carrying `AGENTS.md` above the server library), so a path
/// like `packages/control_plane_client/test` resolves identically no matter
/// which working directory `dart test` ran from.
Future<Directory> _repoRoot() async {
  var dir = await _packageDir();
  while (true) {
    if (File('${dir.path}/AGENTS.md').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'could not locate the repository root above ${dir.path}',
      );
    }
    dir = parent;
  }
}

Future<String> _readServerSource() async {
  final dir = await _packageDir();
  return File('${dir.path}/server.dart').readAsStringSync();
}

/// The body of `run()`, the composition root.
String _runBody(String source) {
  final start =
      RegExp('^Future<void> run\\(', multiLine: true).firstMatch(source) ??
      RegExp('^void run\\(', multiLine: true).firstMatch(source);
  if (start == null) {
    throw StateError('could not locate `run()` in lib/server.dart');
  }
  final rest = source.substring(start.end);
  final end = RegExp('^\\}', multiLine: true).firstMatch(rest);
  if (end == null) throw StateError('`run()` must be a top-level function');
  return rest.substring(0, end.start);
}
