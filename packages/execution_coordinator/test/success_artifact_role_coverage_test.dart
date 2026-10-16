import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

/// Every `AgentRole` is either judged by the success-artifact rule or NAMED here
/// as a lane it deliberately does not judge.
///
/// ## WHY THE DEFAULT IS RIGHT AND SILENT
///
/// `RoleAwareSuccessArtifacts.kindFor` classifies four of the twelve roles and
/// sends the rest to `SuccessArtifactKind.unspecified`, which counts as
/// satisfied. That default is deliberate and correct on its own terms: human
/// decision `92d567e3-da03-4c43-99f4-e3726472f0ab` chose `ROLE_AWARE` precisely
/// because `agent_completed` is shared — a universal "no files changed means
/// failure" rule would fail every triage run — and inventing an artifact for
/// the design and QA lanes from inside this rule would fail work this change
/// knows nothing about, on evidence nobody gathered.
///
/// The problem is not the default. It is that a role that was deliberately
/// exempted and a role nobody thought about were **the same value**. A lane
/// added to the `AgentRole` enum tomorrow would land in `unspecified`, pass
/// every test in this package, and be exempt from the permanent-failure rule
/// without anyone having decided that.
///
/// ## WHAT THIS FILE CHANGES
///
/// Nothing at runtime. The eight roles below keep behaving exactly as they do,
/// and the rule still does not fail closed on an unjudged role. What changes is
/// that the exemption becomes a LIST, so forgetting a role fails here, by name,
/// at the moment it is added — while deciding that a new role is unjudged is a
/// one-line edit that says so on the record.
void main() {
  /// The lanes this rule does NOT judge, and why each is exempt.
  ///
  /// Not a fallback and not a default — an assertion about these eight, which
  /// the tests below hold this list to. Adding a ninth role to `AgentRole`
  /// without adding it here fails [every role is judged or named here].
  const deliberatelyUnjudgedRoles = <AgentRole, String>{
    AgentRole.designAgent:
        'design produces a Design Brief, and which one is judged is the '
        'design lane\'s own contract, not this rule\'s',
    AgentRole.designReviewer:
        'a review verdict for design is a design artifact, read by the design '
        'lane; this rule has no evidence of its own about it',
    AgentRole.qaArchitect: 'defines the QA Contract rather than executing code',
    AgentRole.qaExecutor:
        'executes QA rather than changing the product; its deliverable is the '
        'QA result, which apps/server owns',
    AgentRole.releaseEngineer:
        'release preparation is an infrastructure action, and this rule runs '
        'before anything is deployed',
    AgentRole.deploymentAuthority:
        'deployment holds production credentials and authority this package '
        'does not have',
    AgentRole.focusedReviewer:
        'a focused re-review reads an already-committed artifact; there is no '
        'implementation to judge here',
    AgentRole.integrator:
        'integration verifies an approved HEAD rather than producing one',
  };

  /// The roles the rule DOES judge, and the artifact each owes. Pinned so a
  /// reclassification is a deliberate edit rather than a side effect.
  const judgedRoles = <AgentRole, SuccessArtifactKind>{
    AgentRole.implementer: SuccessArtifactKind.committedCode,
    AgentRole.correctionImplementer: SuccessArtifactKind.committedCode,
    AgentRole.triageDefect: SuccessArtifactKind.classificationResult,
    AgentRole.engineeringReviewer: SuccessArtifactKind.reviewVerdict,
  };

  /// The reason a role has no defined artifact — asserted non-empty so the list
  /// cannot grow a bare entry with no thought behind it.
  String reasonFor(AgentRole role) =>
      deliberatelyUnjudgedRoles[role] ?? '(no reason recorded)';

  group('the role map is pinned', () {
    test('every role is judged or named here', () {
      final unaccounted = AgentRole.values
          .where(
            (role) =>
                !judgedRoles.containsKey(role) &&
                !deliberatelyUnjudgedRoles.containsKey(role),
          )
          .map((role) => role.wire)
          .toList();

      expect(
        unaccounted,
        isEmpty,
        reason:
            'AgentRole gained ${unaccounted.join(', ')} and the success-artifact '
            'rule says nothing about it. That silence is not neutral: '
            '`SuccessArtifactKind.unspecified` counts as SATISFIED, so an '
            'unclassified lane is silently exempt from the permanent-failure '
            'rule that exists because seven IMPLEMENTER runs produced nothing '
            'and all seven reached agent_completed. Decide it here: give '
            '${unaccounted.join(' and ')} an artifact in `kindFor`, or add '
            '${unaccounted.length == 1 ? 'it' : 'them'} to '
            '`deliberatelyUnjudgedRoles` with the reason this rule cannot judge '
            '${unaccounted.length == 1 ? 'it' : 'them'}.',
      );
    });

    test('the two lists are disjoint', () {
      final both = judgedRoles.keys
          .where(deliberatelyUnjudgedRoles.containsKey)
          .map((role) => role.wire)
          .toList();

      expect(
        both,
        isEmpty,
        reason:
            '${both.join(', ')} cannot be both judged and deliberately unjudged. '
            'One of the two lists is stale.',
      );
    });

    test('the two lists together are every role, exactly once', () {
      expect(
        judgedRoles.length + deliberatelyUnjudgedRoles.length,
        AgentRole.values.length,
        reason:
            'the lists must account for the whole enum with no role counted '
            'twice and none left over',
      );
    });

    test('the judged roles keep the artifact the rule assigns them', () {
      for (final entry in judgedRoles.entries) {
        expect(
          RoleAwareSuccessArtifacts.kindFor(entry.key),
          entry.value,
          reason:
              '${entry.key.wire} owes ${entry.value.name}. If that is no longer '
              'true, change the map deliberately — the reason string below and '
              'the operator-facing failure text are written per artifact.',
        );
      }
    });

    test('each unjudged role carries a written reason', () {
      for (final role in deliberatelyUnjudgedRoles.keys) {
        expect(
          reasonFor(role),
          isNot('(no reason recorded)'),
          reason:
              '${role.wire} is exempt from the success-artifact rule without '
              'anyone having written down why',
        );
      }
    });
  });

  group('the exemption is real: unjudged roles still complete', () {
    /// The eight roles must keep working, not merely keep classifying as
    /// `unspecified` in the abstract. Each is run through the checker with a
    /// workspace that is NOT a repository and a result carrying no structured
    /// output — the most hostile inputs available, and the two that would fail
    /// every judged role. An unjudged role must still be `satisfied`.
    const checker = RoleAwareSuccessArtifacts(probe: GitWorkspaceDeltaProbe());

    AgentResult bareResult() => AgentResult(
      resultId: 'res-1',
      sessionId: 'ses-1',
      workItemId: 'wi-1',
      status: AgentResultStatus.completed,
      artifacts: const [],
      diagnostics: const AgentDiagnostics(
        exitCode: 0,
        durationMs: 1,
        toolCalls: 0,
        errors: [],
        warnings: [],
      ),
      structuredResult: const {},
      completedAt: DateTime.utc(2026, 10, 16),
    );

    test(
      'every unjudged role is satisfied, on inputs that fail judged roles',
      () async {
        for (final role in deliberatelyUnjudgedRoles.keys) {
          final verdict = await checker.inspect(
            executionId: 'exec-${role.wire}',
            role: role,
            workspace: const AgentWorkspace(
              workspaceId: 'ws-none',
              path: '/definitely/not/a/repository',
            ),
            result: bareResult(),
          );

          expect(
            verdict.satisfaction,
            ArtifactSatisfaction.satisfied,
            reason:
                '${role.wire} must not fail closed. It is exempt because this '
                'rule has no evidence about it (${reasonFor(role)}), and inventing '
                'a failure here would fail real work on a guess — which is the '
                'opposite of the rule being for.',
          );
          expect(verdict.kind, SuccessArtifactKind.unspecified);
        }
      },
    );

    test('the control: a JUDGED role on the same inputs does fail', () async {
      // Without this, the test above would also pass if the checker ignored
      // every role — a rule that never fires cannot fail closed, and the group
      // would be asserting nothing.
      final verdict = await checker.inspect(
        executionId: 'exec-control',
        role: AgentRole.implementer,
        workspace: const AgentWorkspace(
          workspaceId: 'ws-none',
          path: '/definitely/not/a/repository',
        ),
        result: bareResult(),
      );

      expect(
        verdict.satisfaction,
        ArtifactSatisfaction.undetermined,
        reason:
            'the probe cannot read this workspace, so the verdict is '
            '"could not look" — not "satisfied" and not "missing". This is the '
            'distinction that keeps a tooling fault from being reported as an '
            'agent that did nothing.',
      );
    });
  });
}
