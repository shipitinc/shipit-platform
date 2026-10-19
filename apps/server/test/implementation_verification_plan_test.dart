import 'dart:io';
import 'dart:isolate';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:control_plane_server/server.dart'
    show
        buildImplementationExecutionCoordinator,
        buildTriageExecutionCoordinator,
        implementationVerificationPlan,
        perExecutionChecksNotExpressibleAsOnePlan,
        perExecutionValidationChecks,
        triageVerificationPlan,
        verificationPlanForRole;
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart' show AgentRole;
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

/// `OD-6` — the role-scoped IMPLEMENTATION [VerificationPlan].
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
/// That the plan covers the per-execution tier. It covers ONE of the four
/// declared checks. Group 'the residual is explicit, complete, and not
/// laundered' exists to make that shortfall impossible to read as coverage.
void main() {
  late List<_Row> agentsMdPerExecution;
  late List<_Row> agentsMdMergeRelease;

  setUpAll(() async {
    final rows = _parseGateTable(await _readAgentsMd());
    agentsMdPerExecution = rows
        .where((r) => r.tier == 'per-execution')
        .toList(growable: false);
    agentsMdMergeRelease = rows
        .where((r) => r.tier == 'merge/release')
        .toList(growable: false);
  });

  group('AGENTS.md is the contract, and the recorded checks are verbatim', () {
    test('the per-execution tier is four checks, all present in the tree', () {
      // If AGENTS.md's tier ever changes shape, this fails loudly rather than
      // letting the recorded list drift away from the contract in silence.
      expect(
        agentsMdPerExecution.length,
        4,
        reason:
            'the recorded list must track the declared tier exactly; if the '
            'tier changed, re-read AGENTS.md before touching this file',
      );
      expect(perExecutionValidationChecks, hasLength(4));
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
  });

  group('the plan\'s command string-equals the declared command', () {
    // ## THIS IS THE PROOF THE GATE ACTUALLY ASKS FOR.
    //
    // `WorkspaceVerifier` persists `command.join(' ')` as the row's `command`
    // (`workspace_verifier.dart` → `VerificationOutcome.command`), and F4
    // compares that string to the declared one. So the equality below is the
    // same comparison, on the same side of the same types.
    test('the joined command equals the AGENTS.md format row exactly', () {
      final declared = agentsMdPerExecution.firstWhere(
        (r) => r.command.startsWith('dart format'),
      );
      expect(
        implementationVerificationPlan.command.join(' '),
        declared.command,
        reason:
            'F4 sets commandMatchIsExact: true. Substring, token overlap or a '
            're-spelling all fail it, so this is a whole-string equality '
            'against the command parsed out of AGENTS.md',
      );
    });

    test('the checkName is the key the recorded check is written under', () {
      final covered = perExecutionValidationChecks.firstWhere(
        (c) => c.command == implementationVerificationPlan.command.join(' '),
      );
      expect(implementationVerificationPlan.checkName, covered.checkName);
    });

    test(
      'the plan resolves packages first — measured, not assumed',
      () {
        // In a fresh detached worktree with no package resolution, this exact
        // command exits 1 and reports 163 files changed, because the formatter
        // has no package language version and falls back to the SDK default
        // style. Without this setup the plan would settle every implementation
        // execution `executedFail` for a property of the sandbox.
        expect(
          implementationVerificationPlan.setupCommand,
          ['dart', 'pub', 'get'],
        );
      },
    );
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
        triage.verificationPlan!.command,
        triageVerificationPlan.command,
        reason: 'OD-6 must not change what the triage lane is verified by',
      );
      expect(
        implementation.verificationPlan!.command,
        implementationVerificationPlan.command,
      );
      expect(
        implementation.verificationPlan!.setupCommand,
        implementationVerificationPlan.setupCommand,
      );
      expect(
        implementation.verificationPlan!.command,
        isNot(triageVerificationPlan.command),
        reason:
            'the live defect was one plan serving every role; if these are equal '
            'again, role scoping has silently collapsed',
      );
    });
  });

  group('the residual is explicit, complete, and not laundered', () {
    test('exactly one declared check is expressed, and three are not', () {
      final declaredNames = perExecutionValidationChecks
          .map((c) => c.checkName)
          .toSet();
      final uncovered = perExecutionChecksNotExpressibleAsOnePlan.keys.toSet();

      expect(
        uncovered,
        isNot(contains('dart_format_repo_root')),
        reason:
            'the format check IS expressed; listing it as uncovered would '
            'understate what the plan does',
      );
      expect(
        declaredNames.difference(uncovered),
        {'dart_format_repo_root'},
        reason:
            'if this is not exactly the one check the plan expresses, the plan '
            'is claiming coverage it does not have',
      );
      expect(
        uncovered.difference(declaredNames),
        isEmpty,
        reason:
            'every uncovered entry must name a check AGENTS.md actually '
            'declares; an invented name would hide a real gap behind a fake '
            'reason',
      );
      expect(uncovered, hasLength(3));
    });

    test('every uncovered check carries a stated reason', () {
      for (final entry in perExecutionChecksNotExpressibleAsOnePlan.entries) {
        expect(
          entry.value.trim(),
          isNotEmpty,
          reason: '${entry.key} is listed as uncovered with no explanation',
        );
      }
    });

    test(
      'no uncovered command appears anywhere in the implementation plan',
      () {
        for (final uncovered
            in perExecutionChecksNotExpressibleAsOnePlan.keys) {
          final check = perExecutionValidationChecks.firstWhere(
            (c) => c.checkName == uncovered,
          );
          expect(
            implementationVerificationPlan.command,
            isNot(contains(check.command)),
            reason:
                'the plan claims to express only the repository-root check; if '
                'it also carries ${check.command} it is misrepresenting its '
                'own coverage',
          );
        }
      },
    );

    test(
      'the coverage claim cannot be widened by the map being emptied',
      () {
        // Guards the laundering shape `1b7e4c93` rejected: a plan that reads
        // as full coverage while covering less. Deleting the map's entries
        // would make the "exactly one" test above fail — this names why.
        expect(
          perExecutionValidationChecks.length -
              perExecutionChecksNotExpressibleAsOnePlan.length,
          1,
        );
      },
    );
  });

  group('the implementation check can FAIL — it is not a liveness probe', () {
    // ## NON-VACUITY, AND WHY IT IS THE POINT OF THE WHOLE SLICE.
    //
    // The plan this replaces was `git rev-parse --verify HEAD^{commit}`, which
    // succeeds for any checkout that has a commit — it could not fail on
    // anything an implementer wrote. This drives the REAL [WorkspaceVerifier]
    // with the REAL plan, against a disposable fixture, and shows it reports
    // `passed == false` for mis-formatted code. That is the difference between
    // a check and a liveness probe, demonstrated rather than asserted.
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

    Future<VerificationOutcome> verify() => const WorkspaceVerifier().verify(
      workingDirectory: fixture.path,
      command: implementationVerificationPlan.command,
      setupCommand: implementationVerificationPlan.setupCommand,
    );

    test('formatted code passes', () async {
      File('${fixture.path}/main.dart').writeAsStringSync(
        "void main() {\n  print('x');\n}\n",
      );
      final outcome = await verify();
      expect(outcome.passed, isTrue, reason: outcome.detail ?? '');
    });

    test('mis-formatted code FAILS the check', () async {
      File('${fixture.path}/main.dart').writeAsStringSync(
        "void main(){print('x');}\n",
      );
      final outcome = await verify();
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
        final outcome = await verify();
        expect(
          outcome.command,
          implementationVerificationPlan.command.join(' '),
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
      'nothing mounts or re-points a scheduler in the OD-6 change',
      () async {
        // `run()` already builds THREE schedulers at base — `sched-triage`,
        // `sched-review`, `sched-impl`. OD-6 must leave that set exactly as it
        // was: it adds a COORDINATOR, which verifies work, and never a
        // SCHEDULER, which would start dispatching. The count is pinned to the
        // base so that adding one here fails loudly instead of shipping a
        // scheduler nobody reviewed.
        final source = await _readServerSource();
        final constructions = RegExp(
          r"Scheduler\(\s*schedulerId: '([^']+)'",
        ).allMatches(source).map((m) => m.group(1)).toList();

        expect(
          constructions,
          ['sched-triage', 'sched-review', 'sched-impl'],
          reason:
              'the three schedulers `run()` builds are unchanged by OD-6. A '
              'fourth entry, a renamed id, or a different set means a '
              'scheduler was added or re-pointed — outside what this slice is '
              'authorised to do.',
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

String _strip(String cell) =>
    cell.replaceAll('`', '').replaceAll('*', '').trim();

/// Reads `AGENTS.md` — located by walking up from the resolved server library
/// so the result does not depend on the working directory `dart test` ran from.
///
/// Resolution goes through `Isolate.resolvePackageUri`, the same technique
/// `triage_verification_plan_test.dart` uses: a `package:` URI cannot be turned
/// into a file path by `File.fromUri` alone.
Future<String> _readAgentsMd() async {
  final uri = await Isolate.resolvePackageUri(
    Uri.parse('package:control_plane_server/server.dart'),
  );
  if (uri == null) {
    throw StateError('could not resolve the server composition source');
  }
  var dir = File.fromUri(uri).parent;
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

Future<String> _readServerSource() async {
  final uri = await Isolate.resolvePackageUri(
    Uri.parse('package:control_plane_server/server.dart'),
  );
  if (uri == null) {
    throw StateError('could not resolve the server composition source');
  }
  return File.fromUri(uri).readAsStringSync();
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
