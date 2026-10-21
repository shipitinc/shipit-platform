import 'dart:convert';
import 'dart:io';

import 'package:control_plane_server/server.dart'
    show implementationVerificationPlan;
import 'package:platform_contracts/platform_contracts.dart'
    show ProductManifest;
import 'package:test/test.dart';

/// The **drift pin** between the shipped product manifest's F4 declaration and
/// the role-scoped implementation [implementationVerificationPlan].
///
/// ## Why a pin, and why BOTH directions
///
/// `declared-validation-outcome` (design §3.1 **F4**) compares a persisted
/// `PlatformVerification` row's `checkName` and `command` to a declared pair, by
/// **string equality** (`commandMatchIsExact: true`). The two sides of that
/// comparison live in different files that nothing else joins:
///
///   * the **manifest** declares `requireCheckNames` / `requireCommands`
///     (`apps/server/manifests/shipit-platform.product-manifest.json`), and
///   * the **plan** is what `WorkspaceVerifier` actually runs and records
///     (`implementationVerificationPlan`, `server.dart`), with
///     `command: command.join(' ')` and `checkName` taken from the plan
///     (`workspace_verifier.dart:78`, `execution_coordinator.dart:920`).
///
/// If they drift, F4 becomes **permanently unpassable**: a declared check whose
/// name the plan never writes can never have a row, and a name the plan writes
/// but the manifest does not declare is never required. Either way the gate
/// fails on every execution for a reason no code change explains.
///
/// **Both directions are asserted** because the two failures are different:
///
///   * a name in the **manifest** and not the **plan** ⇒ F4 can never pass (the
///     declared check has no row, ever);
///   * a name in the **plan** and not the **manifest** ⇒ the plan runs and
///     records a check the product never asked for, which is invisible coverage
///     that reads as declared.
///
/// This mirrors `implementation_verification_plan_test.dart`'s AGENTS.md pin,
/// which derives both sides independently for the same reason.
///
/// ## What it does NOT pin
///
/// The `ownedPathGlobs` / `forbiddenPathGlobs` of F2. Those are `TBD` in
/// `AGENTS.md`'s path-ownership map and the design (§9 gap 3, §10.2) forbids
/// guessing one, so this file does not read them.
void main() {
  final repoRoot = _findRepoRoot();
  final manifest = ProductManifest.fromJson(
    jsonDecode(
          File(
            '$repoRoot/apps/server/manifests/'
            'shipit-platform.product-manifest.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>,
  );

  final gates = manifest.contracts.qaContract.gates;
  final f4 = gates.where((g) => g.type == 'declared-validation-outcome');
  final plan = implementationVerificationPlan;
  final planCommands = <String, String>{
    for (final check in plan.checks) check.checkName: check.command.join(' '),
  };

  group('the manifest declares exactly one F4 gate', () {
    test('there is one declared-validation-outcome gate', () {
      expect(
        f4,
        hasLength(1),
        reason:
            'F4 (design §3.1) is one gate. Zero means the feature lane has no '
            'declared-check gate; more than one means two gates would need a '
            'result for the same assertion.',
      );
    });
  });

  group('the F4 declaration and the plan pin each other', () {
    test('the check-name SETS are equal, both directions', () {
      final declared = (f4.single.config['requireCheckNames'] as List)
          .cast<String>()
          .toSet();
      expect(
        declared,
        equals(planCommands.keys.toSet()),
        reason:
            'the manifest F4 declaration and the implementation plan disagree '
            'on which checks exist. A name in the manifest and not the plan is '
            'a declared check with no row the plan can ever write (F4 can never '
            'pass); a name in the plan and not the manifest is coverage the '
            'product never declared. Re-derive one from the other, do not '
            'hand-edit either.',
      );
    });

    test('the declared commands string-equal the plan commands', () {
      final declared = Map<String, dynamic>.from(
        f4.single.config['requireCommands'] as Map,
      );
      expect(
        declared,
        equals(planCommands),
        reason:
            'F4 compares commands by string equality. `WorkspaceVerifier` '
            'records `command.join(\' \')` of the plan check '
            '(workspace_verifier.dart:78), so the declared string must be that '
            'exact string — a re-spelling fails the check on every execution.',
      );
    });

    test('no declared check lacks a command', () {
      // The evaluator refuses this at provision (`_DeclaredValidationConfig`),
      // but the refusal would surface at evaluate time on every work item. A
      // test here fails at CI instead, naming the missing key.
      final names = (f4.single.config['requireCheckNames'] as List)
          .cast<String>();
      final commands = Map<String, dynamic>.from(
        f4.single.config['requireCommands'] as Map,
      );
      final missing = names.where((n) => !commands.containsKey(n)).toList();
      expect(
        missing,
        isEmpty,
        reason:
            'these declared checks have no "requireCommands" entry, so F4 '
            'throws at provision for every item: $missing',
      );
    });

    test('every declared check name is unique', () {
      final names = (f4.single.config['requireCheckNames'] as List)
          .cast<String>();
      expect(
        names.toSet(),
        hasLength(names.length),
        reason:
            'a duplicate name in requireCheckNames is refused by F4 '
            '(_DeclaredValidationConfig), and the refusal is a provision '
            'failure rather than a test failure.',
      );
    });

    test('the plan has 32 checks, matching workspaceMemberRoots + tests', () {
      // The plan is 1 format + 16 analyze + 13 test + 1 server runner + 1
      // flutter test = 32. Pinned here so a plan change that silently drops a
      // root fails loudly against the manifest pin above.
      expect(plan.checks, hasLength(32));
    });
  });

  group('the retained structural gate is unchanged', () {
    test('intake-structured-result-admitted is still declared, required', () {
      final intake = gates.where(
        (g) => g.gateId == 'intake-structured-result-admitted',
      );
      expect(intake, hasLength(1));
      expect(intake.single.type, 'triage-classification-structure');
      expect(intake.single.required, isTrue);
    });

    test('the mutual-exclusion rule holds: no triage-classification-admitted '
        'in the manifest', () {
      // §3.2's normative rule: no QAContract may declare BOTH
      // `triage-classification-admitted` and `intake-structured-result-admitted`.
      // The manifest keeps the latter; the remediation contract carries the
      // former. If both appeared here, one structural check would demand two
      // results.
      expect(
        gates.where(
          (g) => g.gateId == 'triage-classification-admitted',
        ),
        isEmpty,
        reason:
            'the manifest must not carry BOTH gate ids for '
            'triage-classification-structure (§3.2 mutual exclusion).',
      );
    });
  });

  group('the manifest declares the §3.1 feature gate set', () {
    test('all four feature gates are present and required', () {
      final byType = <String, int>{};
      for (final g in gates) {
        byType[g.type] = (byType[g.type] ?? 0) + 1;
      }
      expect(byType['implementation-artifact-provenance'], 1); // F1
      expect(byType['change-scope-confinement'], 1); // F2
      expect(byType['declared-validation-outcome'], 1); // F4
      expect(byType['revision-identity-match'], 1); // F5
      for (final g in gates.where(
        (g) => const {
          'implementation-artifact-provenance',
          'change-scope-confinement',
          'declared-validation-outcome',
          'revision-identity-match',
        }.contains(g.type),
      )) {
        expect(g.required, isTrue, reason: '${g.gateId} must be required');
      }
    });
  });
}

String _findRepoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (Directory(
          '${dir.path}${Platform.pathSeparator}packages',
        ).existsSync() &&
        Directory('${dir.path}${Platform.pathSeparator}apps').existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('repository root not found from ${Directory.current}');
    }
    dir = parent;
  }
}
