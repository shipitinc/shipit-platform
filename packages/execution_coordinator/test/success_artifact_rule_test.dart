import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/fake_agent.dart';
import 'support/git_fixture.dart';

/// A clean finish is not a success. An execution that reached the end of its
/// turn without producing its lane's artifact must settle `failed`, permanently.
///
/// ## THE MEASURED DEFECT THIS FILE PINS
///
/// Measured on live QA 2026-10-16: seven IMPLEMENTER executions completed with
/// `changedFilesJson = ''` — zero files, zero commits — and all seven still
/// reached `agent_completed`, the state `engineeringReviewDefinition` dispatches
/// FROM. The review lane then failed closed for ever because there was no
/// artifact to review, and four defects sat there.
///
/// ## WHY THE RULE IS ROLE-AWARE, AND WHY THAT IS THE WHOLE DIFFICULTY
///
/// `agent_completed` is SHARED. Triage legitimately finishes without touching
/// the product: it writes a classification into a scratch repo, never code. So
/// "no files changed means failure" would fail every triage run, and the
/// universal option was rejected in favour of `ROLE_AWARE` (human decision
/// `92d567e3-da03-4c43-99f4-e3726472f0ab`).
///
/// ## WHY THE FAILURE IS `failed` AND NOT `interrupted`
///
/// `interrupted` is what classifies TRANSIENT, and a transient failure is
/// returned to a lane entry state and re-dispatched automatically. That is right
/// for a wire that went quiet and wrong for a run that finished cleanly and
/// produced nothing, which will produce nothing again. The operator's words:
/// "that should be a fail allow an unlimited human try again". So the chain
/// below is pinned twice — once behaviourally, and once against the scheduler
/// and worker source in [the downstream classification is still permanent].
void main() {
  late Directory temp;
  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('success_artifact_');
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  ExecutionCoordinator coordinatorOf(
    FakeAgentSession session, {
    VerificationPlan? verificationPlan,
  }) => ExecutionCoordinator(
    store: executionStore,
    workflowEngine: workflowEngine,
    runtime: AgentRuntime(
      registry: AgentAdapterRegistry()..register(FakeAgentAdapter(session)),
    ),
    verificationPlan: verificationPlan,
  );

  AgentExecutionRequest requestFor({
    required String executionId,
    required AgentRole role,
    required AgentWorkspace workspace,
    String workItemId = 'wi-1',
    int timeoutSeconds = 60,
  }) => AgentExecutionRequest(
    executionId: executionId,
    workItemId: workItemId,
    role: role,
    runtimeTypeId: 'fake-runtime',
    workspace: workspace,
    instruction: 'do the work',
    timeoutSeconds: timeoutSeconds,
  );

  /// A work item walked to `designNotRequired`, so `-> agentExecuting` is legal
  /// for an implementer and for triage alike.
  Future<void> readyItem({String id = 'wi-1'}) async {
    await workflowEngine.createWorkItem(
      workItemId: id,
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Fix the defect filtering logic',
      description: 'Runs that finish without producing their artifact',
      qaContractId: 'qa-1',
      featureRef: 'feature/defect-filter',
    );
    await workflowEngine.transition(
      workItemId: id,
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
    );
    await workflowEngine.transition(
      workItemId: id,
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      context: const {'featureRef': 'feature/defect-filter'},
    );
    await workflowEngine.transition(
      workItemId: id,
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );
  }

  /// The measured PASSING triage payload, from the decision's own evidence.
  const validClassification = {
    'classification': 'implementation_defect',
    'status': 'triaging',
    'confidence': 0.72,
    'suspectedCategory': 'backend',
    'suspectedComponents': ['defect-filter'],
    'reproductionSupported': true,
    'evidenceUsed': ['ev-1'],
    'clarificationRequired': <Map<String, String>>[],
    'recommendedNextAction': 'investigate',
    'summary': 'The defect filter never matches an incoming report.',
  };

  group('IMPLEMENTER: a commit is the artifact', () {
    test('with a commit in the workspace it still completes', () async {
      final git = GitWorkspaceFixture.create(temp.path);
      addTearDown(git.dispose);
      await readyItem();

      final session = FakeAgentSession(
        executionId: 'exec-ok',
        workItemId: 'wi-1',
      );
      // The agent edits the product and COMMITS it. The platform observes the
      // workspace independently, with git, at settle time — so what matters is
      // the workspace's state when the coordinator asks, not the test's
      // narration of the agent's intentions.
      //
      // This test was named for the committed case and never made a commit. It
      // wrote a file and left the tree dirty, so it re-ran the untracked-file
      // test below and left the committed case — the one `ArtifactCommitter`
      // names in its own comment — with no coverage at all.
      git.writeFile(
        'lib/calculator.dart',
        'int add(int a, int b) => a + b + 1;\n',
      );
      git.commitAll('implement the defect filter');

      final execution = await coordinatorOf(session).execute(
        requestFor(
          executionId: 'exec-ok',
          role: AgentRole.implementer,
          workspace: git.toWorkspace(),
        ),
      );

      expect(execution.status, AgentSessionStatus.completed);
      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.agentCompleted,
      );
      expect(
        (await workflowEngine.loadWorkItem(
          'wi-1',
        )).metadata?['producerActorId'],
        'exec-ok',
        reason:
            'a run that produced its artifact is a producer, and the review '
            'gate checks this identity',
      );
    });

    test('an UNTRACKED new file counts as produced', () async {
      // The trap this test exists to close: `git diff --name-status <rev>` does
      // NOT list untracked files, so a probe written to mirror
      // `GitWorkspaceInspector` would permanently fail this run — which
      // `ArtifactCommitter` goes on to commit, and which `producedCommitFor`
      // then reports as a real revision. A probe that disagrees with the
      // committer about the same worktree is worse than no probe.
      final git = GitWorkspaceFixture.create(temp.path);
      addTearDown(git.dispose);
      await readyItem();

      final session = FakeAgentSession(
        executionId: 'exec-untracked',
        workItemId: 'wi-1',
      );
      git.createUntrackedFile(
        'lib/defect_filter.dart',
        'bool matches(String r) => false;\n',
      );

      final execution = await coordinatorOf(session).execute(
        requestFor(
          executionId: 'exec-untracked',
          role: AgentRole.implementer,
          workspace: git.toWorkspace(),
        ),
      );

      expect(
        execution.status,
        AgentSessionStatus.completed,
        reason:
            'an untracked, unstaged new file is still code the platform will '
            'commit for this execution',
      );
    });

    test('without any change it settles failed, not completed', () async {
      final git = GitWorkspaceFixture.create(temp.path);
      addTearDown(git.dispose);
      await readyItem();

      final execution =
          await coordinatorOf(
            FakeAgentSession(executionId: 'exec-empty', workItemId: 'wi-1'),
          ).execute(
            requestFor(
              executionId: 'exec-empty',
              role: AgentRole.implementer,
              workspace: git.toWorkspace(),
            ),
          );

      expect(
        execution.status,
        AgentSessionStatus.failed,
        reason:
            'this is the measured defect: seven runs completed with zero '
            'files touched and all seven reached agent_completed',
      );
      expect(execution.reason, startsWith(SuccessArtifactArtifacts.marker));
      expect(
        execution.reason,
        contains('produced no commit'),
        reason:
            'the reason names WHAT was missing, not merely that something '
            'went wrong',
      );
      expect(
        execution.reason,
        contains('exec-empty'),
        reason: 'and it names the run, so a grep leads back to one execution',
      );
    });

    test('the work item lands at agent_failed, never agent_completed', () async {
      final git = GitWorkspaceFixture.create(temp.path);
      addTearDown(git.dispose);
      await readyItem();

      await coordinatorOf(
        FakeAgentSession(executionId: 'exec-empty', workItemId: 'wi-1'),
      ).execute(
        requestFor(
          executionId: 'exec-empty',
          role: AgentRole.implementer,
          workspace: git.toWorkspace(),
        ),
      );

      final item = await workflowEngine.loadWorkItem('wi-1');
      expect(item.state, WorkItemState.agentFailed);
      expect(
        item.metadata?['producerActorId'],
        isNull,
        reason:
            'a run that '
            'produced nothing is not a producer, and stamping it would let the '
            'review gate treat a refuted run as the artifact to review',
      );

      // The decisive assertion: the state the review lane dispatches FROM was
      // never reached. Asserted on the durable transition history, not just the
      // current state, so a later transition back and forth cannot hide it.
      final history = await workflowEngine.transitionHistory('wi-1');
      expect(
        history.where((t) => t.toState == WorkItemState.agentCompleted),
        isEmpty,
        reason: 'no row may record this run having completed',
      );
      final failing = history.where(
        (t) => t.toState == WorkItemState.agentFailed,
      );
      expect(failing, hasLength(1));
      expect(
        failing.single.reason,
        startsWith(SuccessArtifactArtifacts.marker),
        reason:
            'the PERSISTED transition reason is what an operator reads; a '
            'failure with no signal in history is the other half of this defect',
      );
    });

    test('CORRECTION_IMPLEMENTER is judged by the same rule', () async {
      final git = GitWorkspaceFixture.create(temp.path);
      addTearDown(git.dispose);
      await readyItem();

      final execution =
          await coordinatorOf(
            FakeAgentSession(executionId: 'exec-corr', workItemId: 'wi-1'),
          ).execute(
            requestFor(
              executionId: 'exec-corr',
              role: AgentRole.correctionImplementer,
              workspace: git.toWorkspace(),
            ),
          );

      expect(execution.status, AgentSessionStatus.failed);
      expect(execution.reason, contains('CORRECTION_IMPLEMENTER'));
    });
  });

  group('the committer\'s truth table, end to end', () {
    // `ArtifactCommitter.commit` (worker_runtime) calls an implementation
    // produced when EITHER half holds:
    //
    //     dirty := `git status --porcelain` is non-empty
    //     moved := `git rev-parse HEAD`       != startingRevision
    //
    // and returns `ArtifactCommitOutcome.none()` only when BOTH are false. Its
    // own comment then says: "If the change was already committed by the agent
    // (HEAD moved, tree clean) there is nothing to commit and the agent's own
    // commit is the produced revision."
    //
    // The probe once implemented only `dirty`. On a clean tree it returned
    // `unchanged` WITHOUT comparing the two revisions, so an implementer that
    // committed its own work was scored `missing` — the PERMANENT failure this
    // whole rule exists to produce, handed to an agent that had in fact
    // committed. Reproduced by the reviewer against a real repository: the
    // committer said COMMITTED and the probe said missing, about the same
    // worktree in the same instant.
    //
    // Each test below ASSERTS ITS OWN PREMISE first. A test named for a clean
    // tree that never checks the tree is clean passes through the dirty branch
    // and is evidence of nothing.

    test('CLEAN tree with HEAD past the baseline is SATISFIED', () async {
      final git = GitWorkspaceFixture.create(temp.path, tag: 'moved_ws');
      addTearDown(git.dispose);
      await readyItem();

      git.writeFile(
        'lib/defect_filter.dart',
        'bool matches(String report) => true;\n',
      );
      git.commitAll('the agent commits its own work');

      expect(
        git.isCleanTree,
        isTrue,
        reason: 'premise: the tree really is clean after the commit',
      );
      expect(
        git.head,
        isNot(git.startingRevision),
        reason: 'premise: HEAD really did move past the baseline',
      );

      final execution =
          await coordinatorOf(
            FakeAgentSession(executionId: 'exec-moved', workItemId: 'wi-1'),
          ).execute(
            requestFor(
              executionId: 'exec-moved',
              role: AgentRole.implementer,
              workspace: git.toWorkspace(),
            ),
          );

      expect(
        execution.status,
        AgentSessionStatus.completed,
        reason:
            'an implementer that commits its own work produced the artifact. '
            'Scoring it `missing` is the permanent failure this rule exists to '
            'produce, applied to an agent that had in fact committed — and '
            'ArtifactCommitter, asked about this same worktree, would have '
            'answered "committed".',
      );
      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.agentCompleted,
      );
    });

    test('CLEAN tree with HEAD still on the baseline is MISSING', () async {
      final git = GitWorkspaceFixture.create(temp.path, tag: 'unmoved_ws');
      addTearDown(git.dispose);
      await readyItem();

      expect(
        git.isCleanTree,
        isTrue,
        reason: 'premise: nothing was written, so nothing could be dirty',
      );
      expect(
        git.head,
        git.startingRevision,
        reason: 'premise: HEAD is exactly where the execution started',
      );

      final execution =
          await coordinatorOf(
            FakeAgentSession(executionId: 'exec-unmoved', workItemId: 'wi-1'),
          ).execute(
            requestFor(
              executionId: 'exec-unmoved',
              role: AgentRole.implementer,
              workspace: git.toWorkspace(),
            ),
          );

      expect(
        execution.status,
        AgentSessionStatus.failed,
        reason:
            'THIS is the measured QA defect and the only shape of it: a clean '
            'tree AND an unmoved HEAD. Everything else in this group exists to '
            'show it is distinguishable from the three neighbours.',
      );
      expect(execution.reason, startsWith(SuccessArtifactArtifacts.marker));
      expect(execution.reason, contains('produced no commit'));
      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.agentFailed,
      );
    });

    test('DIRTY tree is SATISFIED', () async {
      final git = GitWorkspaceFixture.create(temp.path, tag: 'dirty_ws');
      addTearDown(git.dispose);
      await readyItem();

      git.writeFile(
        'lib/defect_filter.dart',
        'bool matches(String report) => true;\n',
      );

      expect(
        git.isCleanTree,
        isFalse,
        reason: 'premise: an unstaged edit is dirt git status reports',
      );
      expect(
        git.head,
        git.startingRevision,
        reason:
            'premise: HEAD is UNMOVED, so this passes on `dirty` alone — which '
            'is what makes it a control on the test above rather than a repeat '
            'of it',
      );

      final execution =
          await coordinatorOf(
            FakeAgentSession(executionId: 'exec-dirty', workItemId: 'wi-1'),
          ).execute(
            requestFor(
              executionId: 'exec-dirty',
              role: AgentRole.implementer,
              workspace: git.toWorkspace(),
            ),
          );

      expect(execution.status, AgentSessionStatus.completed);
    });

    test('STAGED but uncommitted is SATISFIED', () async {
      // The state between "dirty" and "committed": `HEAD` unmoved, index
      // non-empty, worktree file unchanged. `ArtifactCommitter` commits it, so a
      // probe that read only the worktree's unstaged diff would miss it.
      final git = GitWorkspaceFixture.create(temp.path, tag: 'staged_ws');
      addTearDown(git.dispose);
      await readyItem();

      git.writeFile(
        'lib/defect_filter.dart',
        'bool matches(String report) => true;\n',
      );
      git.stageAll();

      expect(
        git.head,
        git.startingRevision,
        reason: 'premise: staging does not move HEAD',
      );
      expect(
        git.porcelainLines.single.substring(0, 2).trim(),
        'A',
        reason: 'premise: the staged entry is an addition in the INDEX column',
      );

      final execution =
          await coordinatorOf(
            FakeAgentSession(executionId: 'exec-staged', workItemId: 'wi-1'),
          ).execute(
            requestFor(
              executionId: 'exec-staged',
              role: AgentRole.implementer,
              workspace: git.toWorkspace(),
            ),
          );

      expect(
        execution.status,
        AgentSessionStatus.completed,
        reason:
            'a staged-only change is the change, and it is the state '
            'ArtifactCommitter re-reads for after it runs its own `add -A`',
      );
    });
  });

  group('TRIAGE_DEFECT: a classification is the artifact', () {
    test('with a valid classification it still completes', () async {
      // The regression this guards is not hypothetical: a universal
      // "no files changed = failure" rule would fail EVERY triage run, because
      // triage writes a classification into a scratch repo and never code.
      final git = GitWorkspaceFixture.create(temp.path, tag: 'triage_ws');
      addTearDown(git.dispose);
      await readyItem();

      final execution =
          await coordinatorOf(
            FakeAgentSession(
              executionId: 'exec-triage-ok',
              workItemId: 'wi-1',
              structuredResult: validClassification,
            ),
          ).execute(
            requestFor(
              executionId: 'exec-triage-ok',
              role: AgentRole.triageDefect,
              workspace: git.toWorkspace(),
            ),
          );

      expect(
        execution.status,
        AgentSessionStatus.completed,
        reason:
            'a clean git worktree is the NORMAL state of a triage run, and '
            'must never be read as "produced nothing"',
      );
      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.agentCompleted,
        reason:
            'the re-triage-then-implement route depends on triage reaching '
            'agent_completed',
      );
    });

    test('triage may complete even with a DIRTY workspace', () async {
      // The mirror image, and the case a commit-based rule gets backwards:
      // triage is not judged on the repository at all, in either direction.
      final git = GitWorkspaceFixture.create(temp.path, tag: 'triage_dirty');
      addTearDown(git.dispose);
      await readyItem();
      git.writeFile('scratch/notes.md', '# triage notes\n');

      final execution =
          await coordinatorOf(
            FakeAgentSession(
              executionId: 'exec-triage-dirty',
              workItemId: 'wi-1',
              structuredResult: validClassification,
            ),
          ).execute(
            requestFor(
              executionId: 'exec-triage-dirty',
              role: AgentRole.triageDefect,
              workspace: git.toWorkspace(),
            ),
          );

      expect(execution.status, AgentSessionStatus.completed);
    });

    test('without a classification it settles failed', () async {
      final git = GitWorkspaceFixture.create(temp.path, tag: 'triage_empty');
      addTearDown(git.dispose);
      await readyItem();

      final execution =
          await coordinatorOf(
            FakeAgentSession(
              executionId: 'exec-triage-bad',
              workItemId: 'wi-1',
            ),
          ).execute(
            requestFor(
              executionId: 'exec-triage-bad',
              role: AgentRole.triageDefect,
              workspace: git.toWorkspace(),
            ),
          );

      expect(execution.status, AgentSessionStatus.failed);
      expect(execution.reason, startsWith(SuccessArtifactArtifacts.marker));
      expect(
        execution.reason,
        contains('structured classification'),
        reason: 'the reason names the lane and what that lane owes',
      );
      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.agentFailed,
      );
    });

    test(
      'an ILLEGAL classification token is still no classification',
      () async {
        // `_parseTriageResult` converts an unknown token into a null
        // `TriageResult`, so the triage outcome is lost — the run produced
        // nothing usable. Reading it as "triage happened" would be exactly the
        // fabrication the gate's own comment forbids.
        final git = GitWorkspaceFixture.create(temp.path, tag: 'triage_token');
        addTearDown(git.dispose);
        await readyItem();

        final execution =
            await coordinatorOf(
              FakeAgentSession(
                executionId: 'exec-triage-token',
                workItemId: 'wi-1',
                structuredResult: {
                  ...validClassification,
                  'classification': 'IMPLEMENTATION_DEFECT',
                },
              ),
            ).execute(
              requestFor(
                executionId: 'exec-triage-token',
                role: AgentRole.triageDefect,
                workspace: git.toWorkspace(),
              ),
            );

        expect(execution.status, AgentSessionStatus.failed);
        expect(execution.reason, contains('is not a classification'));
      },
    );

    test('an optional field the platform defaults is still accepted', () async {
      // `possibleDuplicateDefectId` and `recommendedWorkItemCategory` are
      // optional in `_parseTriageResult`, and a rule that required them would
      // fail classifications the platform keeps.
      final git = GitWorkspaceFixture.create(temp.path, tag: 'triage_min');
      addTearDown(git.dispose);
      await readyItem();

      final execution =
          await coordinatorOf(
            FakeAgentSession(
              executionId: 'exec-triage-min',
              workItemId: 'wi-1',
              structuredResult: {
                'classification': 'environment_defect',
                'status': 'triaging',
                'confidence': 0.4,
                'suspectedCategory': 'infrastructure',
              },
            ),
          ).execute(
            requestFor(
              executionId: 'exec-triage-min',
              role: AgentRole.triageDefect,
              workspace: git.toWorkspace(),
            ),
          );

      expect(execution.status, AgentSessionStatus.completed);
    });
  });

  group('ENGINEERING_REVIEWER: a parseable verdict is the artifact', () {
    /// The reviewer lane's entry edge, walked the way
    /// `engineering_reviewer_test.dart` walks it.
    Future<void> itemInReview() async {
      await readyItem();
      final git = GitWorkspaceFixture.create(temp.path, tag: 'review_ws');
      addTearDown(git.dispose);
      final impl = FakeAgentSession(
        executionId: 'exec-impl',
        workItemId: 'wi-1',
      );
      git.writeFile(
        'lib/calculator.dart',
        'int add(int a, int b) => a + b + 1;\n',
      );
      await coordinatorOf(impl).execute(
        requestFor(
          executionId: 'exec-impl',
          role: AgentRole.implementer,
          workspace: git.toWorkspace(),
        ),
      );
    }

    test('a parseable verdict is accepted', () async {
      await itemInReview();

      final execution =
          await coordinatorOf(
            FakeAgentSession(
              executionId: 'exec-rev',
              workItemId: 'wi-1',
              structuredResult: {
                'verdict': 'approved',
                'findings': <Map<String, dynamic>>[],
                'summary': 'Checked the diff and the tests; nothing blocking.',
              },
            ),
          ).execute(
            requestFor(
              executionId: 'exec-rev',
              role: AgentRole.engineeringReviewer,
              workspace: AgentWorkspace(
                workspaceId: 'ws-review',
                path: temp.path,
                startingRevision: null,
              ),
            ),
          );

      expect(execution.status, AgentSessionStatus.completed);
    });

    test('a verdictless review settles failed and routes nothing', () async {
      await itemInReview();

      final execution =
          await coordinatorOf(
            FakeAgentSession(executionId: 'exec-rev-bare', workItemId: 'wi-1'),
          ).execute(
            requestFor(
              executionId: 'exec-rev-bare',
              role: AgentRole.engineeringReviewer,
              workspace: AgentWorkspace(
                workspaceId: 'ws-review',
                path: temp.path,
                startingRevision: null,
              ),
            ),
          );

      expect(execution.status, AgentSessionStatus.failed);
      expect(execution.reason, startsWith(SuccessArtifactArtifacts.marker));
      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.reviewInProgress,
        reason:
            'WHERE a verdict-absent review goes is apps/server\'s, and this '
            'package owns no part of it. Asserted so a future edit cannot quietly '
            'start routing from here.',
      );
    });

    test('an UNREADABLE verdict token is not a verdict', () async {
      // Reading an unknown token as `changes_required` — which the gate once
      // did — reports to the operator that a reviewer found problems when it
      // concluded nothing parseable at all.
      await itemInReview();

      final execution =
          await coordinatorOf(
            FakeAgentSession(
              executionId: 'exec-rev-bad',
              workItemId: 'wi-1',
              structuredResult: {'verdict': 'CHANGES_REQUIRED'},
            ),
          ).execute(
            requestFor(
              executionId: 'exec-rev-bad',
              role: AgentRole.engineeringReviewer,
              workspace: AgentWorkspace(
                workspaceId: 'ws-review',
                path: temp.path,
                startingRevision: null,
              ),
            ),
          );

      expect(execution.status, AgentSessionStatus.failed);
      expect(execution.reason, contains('is not a review verdict'));
    });
  });

  group('the failure is permanent and does not auto-return', () {
    test('it settles failed — never the transient status', () async {
      final git = GitWorkspaceFixture.create(temp.path);
      addTearDown(git.dispose);
      await readyItem();

      final noOutput =
          await coordinatorOf(
            FakeAgentSession(executionId: 'exec-a', workItemId: 'wi-1'),
          ).execute(
            requestFor(
              executionId: 'exec-a',
              role: AgentRole.implementer,
              workspace: git.toWorkspace(),
            ),
          );

      expect(
        noOutput.status,
        AgentSessionStatus.failed,
        reason:
            'THE load-bearing assertion. `interrupted` classifies TRANSIENT and '
            'is therefore returned to a lane entry state and re-dispatched '
            'automatically — which is the outcome the operator rejected. Only '
            '`failed` reaches JobFailureKind.permanent.',
      );
      expect(noOutput.status, isNot(AgentSessionStatus.interrupted));
      expect(noOutput.status, isNot(AgentSessionStatus.cancelled));
      expect(noOutput.status, isNot(AgentSessionStatus.completed));
      expect(
        noOutput.isTerminal,
        isTrue,
        reason:
            'and it is terminal, so no dispatch path is still running behind '
            'the verdict',
      );
    });

    test(
      'a TIMEOUT still settles transient — the two stay distinguishable',
      () async {
        // The control. If a no-artifact failure settled `interrupted`, this and
        // the test above would be the same observation and neither would be
        // evidence of anything. Its own work item, because the one above has
        // already left `wi-1` at `agentFailed`.
        final git = GitWorkspaceFixture.create(temp.path, tag: 'timeout_ws');
        addTearDown(git.dispose);
        await readyItem(id: 'wi-timeout');

        final timedOut =
            await coordinatorOf(
              FakeAgentSession(
                executionId: 'exec-t',
                workItemId: 'wi-timeout',
                behavior: FakeBehavior.interrupt,
              ),
            ).execute(
              requestFor(
                executionId: 'exec-t',
                workItemId: 'wi-timeout',
                role: AgentRole.implementer,
                workspace: git.toWorkspace(),
              ),
            );

        expect(
          timedOut.status,
          AgentSessionStatus.interrupted,
          reason:
              'a transport timeout stays transient and stays bounded by '
              'maxAttempts. Only a CLEAN FINISH WITH NO OUTPUT is permanent.',
        );
        expect(
          timedOut.status,
          isNot(AgentSessionStatus.failed),
          reason:
              'the two classes must remain distinguishable, because that is '
              'the entire mechanism by which auto-return cannot fire on one of '
              'them',
        );
      },
    );

    test('the downstream classification is still permanent', () async {
      // The three links that turn this coordinator's status into the operator's
      // behaviour, pinned against the real sources rather than asserted in a
      // comment. Each is a place someone can change the meaning without breaking
      // a single test in this package.
      //
      // Read as text rather than imported because importing them is impossible:
      // `worker_runtime` depends on `execution_coordinator`, so the edge this
      // test would need is a cycle. Same technique the package already uses to
      // pin `WorkItemSupersededException.marker` on both sides.
      // `dart test` runs with the package root as the working directory, so the
      // repository root is two levels up. Resolved from the cwd rather than from
      // `Platform.script`, which under the test runner is a compiled-snapshot URI
      // in a temp directory.
      final repoRoot = Directory.current.parent.parent;
      String read(String relative) =>
          File('${repoRoot.path}/$relative').readAsStringSync();

      final worker = read(
        'packages/worker_runtime/lib/src/worker/local_worker.dart',
      );
      expect(
        worker.contains('case AgentSessionStatus.failed:'),
        isTrue,
        reason: 'LocalWorker must still branch on our terminal status',
      );
      final failedBranch = worker
          .split('case AgentSessionStatus.failed:')[1]
          .split('case AgentSessionStatus.interrupted:')
          .first;
      expect(
        failedBranch.contains('WorkerExecutionStatus.executedFail'),
        isTrue,
        reason:
            'LINK 1: `failed` must still map to `executedFail`. If this '
            'changed, our status would stop meaning anything to the queue.',
      );

      final retryPolicy = read(
        'packages/scheduler/lib/src/policy/retry_policy.dart',
      );
      expect(
        retryPolicy.contains('case WorkerExecutionStatus.executedFail'),
        isTrue,
      );
      final permanentBranch = retryPolicy
          .split('case WorkerExecutionStatus.executedFail')[1]
          .split('case WorkerExecutionStatus.prepareFailed')
          .first;
      expect(
        permanentBranch.contains('JobFailureKind.permanent'),
        isTrue,
        reason:
            'LINK 2: `executedFail` must still classify PERMANENT. If this '
            'changed, the failure would start auto-retrying.',
      );

      final scheduler = read('packages/scheduler/lib/src/scheduler.dart');
      expect(
        scheduler.contains('if (failure == null || !failure.kind.isRetryable)'),
        isTrue,
        reason:
            'LINK 3: the auto-return edge must still gate on a RETRYABLE '
            'failure. `isRetryable` is `== transient` on the contract enum, so '
            'this one line is what excludes our permanent failure — and it is '
            'the whole reason the item stays at agent_failed for a human '
            'instead of being returned to a lane entry state.',
      );
      expect(
        scheduler.contains('job.state != JobState.retryWaiting'),
        isTrue,
        reason:
            'and it must still key off the queue\'s own "a retry is owed" '
            'state rather than a reconstruction of the failure',
      );
    });
  });

  group('a workspace that cannot be inspected is not a failure', () {
    test('an unreadable probe does not settle failed', () async {
      // A wedged filesystem is not an agent that did nothing. Reporting it in
      // those words would tell the operator their agent produced nothing when
      // the platform simply could not look — and would settle it as the
      // permanent failure this rule exists to produce, on evidence nobody
      // gathered.
      await readyItem();
      final session = FakeAgentSession(
        executionId: 'exec-probe',
        workItemId: 'wi-1',
      );

      final execution =
          await ExecutionCoordinator(
            store: executionStore,
            workflowEngine: workflowEngine,
            runtime: AgentRuntime(
              registry: AgentAdapterRegistry()
                ..register(FakeAgentAdapter(session)),
            ),
            // A path that is not a repository at all.
            successArtifacts: const RoleAwareSuccessArtifacts(
              probe: GitWorkspaceDeltaProbe(),
            ),
          ).execute(
            requestFor(
              executionId: 'exec-probe',
              role: AgentRole.implementer,
              workspace: AgentWorkspace(
                workspaceId: 'ws-none',
                path: '/definitely/not/a/repository',
                startingRevision: 'abc123',
              ),
            ),
          );

      expect(
        execution.status,
        AgentSessionStatus.completed,
        reason:
            '"could not look" must never be laundered into "looked and saw '
            'nothing"',
      );
      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.agentCompleted,
      );
    });

    test('a missing starting revision is undetermined, not absence', () async {
      // `ArtifactCommitter` takes its starting revision as a required
      // argument for the same reason: with no baseline there is nothing to
      // compare against, so a verdict either way would be invented.
      await readyItem();
      final execution =
          await coordinatorOf(
            FakeAgentSession(executionId: 'exec-nobase', workItemId: 'wi-1'),
          ).execute(
            requestFor(
              executionId: 'exec-nobase',
              role: AgentRole.implementer,
              workspace: AgentWorkspace(
                workspaceId: 'ws-nobase',
                path: temp.path,
              ),
            ),
          );

      expect(execution.status, AgentSessionStatus.completed);
    });

    test('an undetermined artifact is recorded, not silently dropped', () async {
      await readyItem();
      final session = FakeAgentSession(
        executionId: 'exec-unrecorded',
        workItemId: 'wi-1',
      );
      await coordinatorOf(session).execute(
        requestFor(
          executionId: 'exec-unrecorded',
          role: AgentRole.implementer,
          workspace: AgentWorkspace(workspaceId: 'ws-none', path: '/nope'),
        ),
      );

      final events = await executionStore.readEvents('exec-unrecorded');
      // LAST, not first: the adapter's own `SessionCompleted` normalises to an
      // `executionCompleted` event too, and the coordinator's terminal event —
      // the one carrying this payload — is written after it. Taking the first
      // would assert against the adapter's event and prove nothing.
      final completed = events.lastWhere(
        (e) => e.type == AgentEventType.executionCompleted,
      );
      final payload = completed.payload ?? const <String, dynamic>{};
      expect(
        payload['successArtifactUndetermined'],
        isNotNull,
        reason:
            '"the platform could not look" must be distinguishable in the '
            'record from "the platform looked and saw the artifact"',
      );
    });
  });
}
