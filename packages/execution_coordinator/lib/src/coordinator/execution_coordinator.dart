import 'dart:async';
import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_store/workflow_store.dart';

import '../store/execution_store.dart';
import '../store/model_execution_record_store.dart';
import '../verifier/workspace_verifier.dart';
import 'producer_execution.dart';
import 'success_artifact.dart';
import 'workspace_delta_probe.dart';

/// Thrown when [ExecutionCoordinator.execute] is called for an execution that
/// already has a live, non-terminal record. Executions are single-shot; replay
/// is achieved by observing the terminal record, not by re-running the agent.
class ExecutionAlreadyActiveException implements Exception {
  const ExecutionAlreadyActiveException(this.executionId);

  final String executionId;

  @override
  String toString() => 'Execution is already active: $executionId';
}

/// Thrown when cancel/orchestrate targets an execution that is not currently
/// driven by this coordinator instance.
class ExecutionNotActiveException implements Exception {
  const ExecutionNotActiveException(this.executionId);

  final String executionId;

  @override
  String toString() =>
      'Execution is not active in this coordinator: $executionId';
}

/// Thrown when an execution is dispatched for a work item that has since LEFT
/// the state this role needs to run in.
///
/// ## Why this is its own type
///
/// The underlying cause is an ordinary [WorkflowTransitionRejectedException],
/// and letting that escape produced a genuinely misleading outcome. Live QA
/// caught it: a review job dispatched at 16:40 found its work item moved to
/// `agentExecuting` by an operator, then to `designNotRequired` by a repair
/// migration, and the attempt failed two hours later with
///
///     Workflow transition rejected: WorkItemState.designNotRequired ->
///     WorkItemState.reviewInProgress (Transition ... is not allowed)
///
/// as a `permanent` `executionFailed`. That reads as a platform fault in the
/// state machine. It is not: the state machine REFUSED correctly, and the
/// condition is ordinary staleness — a completion that arrived after its work
/// item moved on. Naming it makes the job's failure reason say what happened.
///
/// ## What it deliberately does NOT claim
///
/// Nothing was executed and nothing was produced, so there is no result to
/// preserve and no work item to un-strand: the transition is attempted BEFORE
/// the execution row and the session exist, and the work item belongs to
/// whoever moved it. This is a classification, not a recovery — and it never
/// relaxes the policy that rejected the transition.
///
/// ## [marker] is a wire contract, not decoration
///
/// This exception does not reach a human: `WorkerDispatch` catches it as a
/// plain `Object`, the worker records `toString()` as a generic
/// `executedFail` / `agentFailed` detail, and the scheduler is what has to
/// decide what that failure MEANS for the job. The prose alone cannot carry
/// that decision, because the worker flattens every thrown value to one
/// string — so [toString] leads with a fixed, machine-readable [marker] the
/// scheduler recognises.
///
/// It is a string and not a typed field because the only channel between this
/// package and the scheduler that neither of them owns is
/// `WorkerExecutionResult.failureDetail`: `WorkerFailureCode` is an enum in
/// `platform_contracts` and cannot grow a value here. The cost is that the
/// marker is matched literally on the other side; the mitigation is that BOTH
/// ends pin it with a test, so a change to either one is a build failure
/// rather than a silent loss of supersession detection.
class WorkItemSupersededException implements Exception {
  const WorkItemSupersededException({
    required this.workItemId,
    required this.observedState,
    required this.requiredState,
    required this.role,
  });

  /// Fixed prefix of [toString], recognised by the scheduler.
  ///
  /// MUST stay byte-identical to `supersededExecutionMarker` in
  /// `packages/scheduler/lib/src/policy/superseded_execution.dart`, which is
  /// the consumer. `stale_completion_test.dart` pins this side and
  /// `supersession_requeue_test.dart` pins that side.
  static const String marker = 'work_item_superseded:';

  final String workItemId;
  final WorkItemState observedState;
  final WorkItemState requiredState;
  final AgentRole role;

  @override
  String toString() =>
      '$marker Superseded execution: work item $workItemId is '
      '${observedState.wire} and no longer accepts a '
      '${role.wire} run, which requires ${requiredState.wire}. '
      'The work item moved on before this execution started, so nothing ran '
      'and nothing was produced.';
}

/// ONE independent check inside a [VerificationPlan].
///
/// ## WHY A CHECK AND NOT A PLAN
///
/// The per-execution validation tier in `AGENTS.md` declares FOUR checks, and
/// three of them name a working directory that is NOT the repository root:
/// `dart analyze` and `dart test` run at **each package root**, `flutter test`
/// runs at `apps/control_plane`. A plan used to carry a single `command`, and
/// the coordinator ran every plan in exactly one directory —
/// `request.workspace.path`, the agent's worktree root. So the other three
/// declared checks could not be expressed at all: not because they are wrong,
/// but because there was nowhere in the record to say *where* to run them.
///
/// [workingDirectory] is that somewhere. It is RELATIVE to the execution
/// workspace, so a plan written against the repository's own layout runs in the
/// agent's worktree of that same repository without carrying the worktree's
/// absolute path — which differs on every execution.
///
/// ## [timeout], AND WHY IT IS PER CHECK (decision `5c9e2b74`)
///
/// Without one, every check is bounded by [WorkspaceVerifier.defaultTimeout]
/// (2 minutes, applied once to setup and once to the command) — and two of the
/// five declared per-execution checks cannot complete inside that: the server
/// unit-test runner measures **531s** through its per-file pool cold in the
/// main checkout and **959.67s** cold in a system-temp worktree (the default
/// execution location), and `flutter test` measures **209s cold / 247s warm**.
/// A check that is killed
/// mid-run produces a FAILING verdict about work that was never judged, so
/// raising the bound is what lets the full declared tier actually run rather
/// than fail for the wrong reason.
///
/// The honesty rule is unchanged and is the reason this is a bound, not an
/// exemption: **a timeout is a FAILING check** — `ran` stays `true` (the
/// process started and overran), the row is written with
/// [AgentClaimStatus.failed], and nothing about a timeout resembles a pass or
/// an absent row. [WorkspaceVerifier] already enforces that; this field only
/// chooses how long each check is allowed to take. A `null` keeps the
/// verifier's default, so every plan written before this field existed behaves
/// exactly as before.
@immutable
class VerificationCheck {
  const VerificationCheck({
    required this.command,
    required this.checkName,
    this.workingDirectory = workspaceRootWorkingDirectory,
    this.setupCommand,
    this.timeout,
  });

  /// The working directory value that means "the workspace root itself", which
  /// is the directory the verifier has always used and the only one that
  /// existed before this type.
  static const String workspaceRootWorkingDirectory = '.';

  /// Fixed prefix of every verification id this check produces.
  ///
  /// Consumers match on the prefix, not on the whole id — see
  /// [verificationIdFor] for why the suffix is load-bearing.
  static const String idPrefix = 'ver-';

  /// e.g. `['dart', 'analyze']`. Spawned with `runInShell: false`, so this is
  /// an argv, never a command line: the string the gate compares is
  /// [command]'s `join(' ')`, produced by the verifier and never re-spelled.
  final List<String> command;

  /// e.g. `['dart', 'pub', 'get']` run once before [command], in the same
  /// [workingDirectory].
  final List<String>? setupCommand;

  /// The key this check's row is recorded under.
  ///
  /// Constrained to `[a-z0-9_]` — see [VerificationPlan]'s constructor, which
  /// enforces it, and [verificationIdFor], which depends on it.
  final String checkName;

  /// Path RELATIVE to the execution workspace root.
  ///
  /// [workspaceRootWorkingDirectory] is the workspace root, which is the
  /// behaviour of every plan written before this field existed. A named
  /// subdirectory resolves inside the workspace: `packages/execution_coordinator`
  /// means "that package, in whatever worktree this execution got".
  final String workingDirectory;

  /// How long [command] — and then [setupCommand], each on its own — is
  /// allowed to run before [WorkspaceVerifier] kills it and records a FAILING
  /// verdict. `null` means the verifier's own default (2 minutes), which is
  /// what every check of every plan written before this field existed got.
  ///
  /// Sized per check from MEASURED runtimes with headroom (decision
  /// `5c9e2b74`), never invented: a value below the measured runtime would
  /// kill healthy checks mid-run, and a value so high it can never fire would
  /// turn a hang into an unbounded wait. See the class doc for the honesty
  /// rule this field does NOT relax: a timeout is a failing row, never an
  /// absent one and never a pass.
  final Duration? timeout;

  /// [workingDirectory] resolved against [workspaceRoot].
  String resolveAgainst(String workspaceRoot) =>
      workingDirectory == workspaceRootWorkingDirectory
      ? workspaceRoot
      : '${workspaceRoot.endsWith('/') ? workspaceRoot.substring(0, workspaceRoot.length - 1) : workspaceRoot}/$workingDirectory';

  /// The [PlatformVerification.verificationId] this check's row is written
  /// under for [executionId].
  ///
  /// ## WHY THE SCHEME IS `ver-<executionId>-<checkName>` AND WHY IT CANNOT
  /// COLLIDE
  ///
  /// The id is the store's primary key: `in_memory_execution_store.dart` and
  /// `file_json_execution_store.dart` index a `Map` by it, and Postgres does
  /// `INSERT … ON CONFLICT ("verificationId") DO UPDATE`. Two rows sharing an
  /// id therefore do not both survive — the second silently overwrites the
  /// first, and the evidence of a check that ran is lost with nothing to say
  /// so. With one check per execution, `ver-<executionId>` was unique by
  /// construction. With several, the check name has to be part of the id.
  ///
  /// Injectivity rests on ONE property, enforced by [VerificationPlan]'s
  /// constructor: a `checkName` contains no `-`. Then in `ver-<executionId>-
  /// <checkName>`, the LAST `-` in the string is always the separator — a
  /// check name cannot supply one — so the pair `(executionId, checkName)` is
  /// recoverable from the id and two distinct pairs cannot produce one string.
  /// Both ids in `ver-a-b-c` would need a check name with a `-` to collide.
  ///
  /// ## REPEATED RUNS OF THE SAME EXECUTION
  ///
  /// The id depends on nothing but the execution and the check, so a second
  /// completion of the same execution rewrites the same ids. That is
  /// deliberate idempotence, not a collision: the latest verdict for a check
  /// replaces the earlier one at the same key, exactly as `ver-<executionId>`
  /// behaved when a completion was re-entered. A non-deterministic id (a
  /// timestamp, a UUID, an attempt counter) would instead accumulate a second
  /// row per re-run, and a gate reading `requireCommands` would find several
  /// rows disagreeing about one check.
  String verificationIdFor(String executionId) =>
      '$idPrefix$executionId-$checkName';
}

/// How the platform independently verifies an agent's claimed result.
///
/// Carries SEVERAL [VerificationCheck]s, so one execution can carry several
/// [PlatformVerification] rows.
///
/// ## SHAPE, AND WHY
///
/// A `List<VerificationCheck>` with the working directory ON THE CHECK, rather
/// than a map keyed by check name, or a check carrying a list of directories.
/// * The working directory belongs to the check, because that is the level the
///   declared contract is written at: `AGENTS.md` gives each check its own cwd.
/// * The list is ordered, so "the first failing check" is a fact about the
///   plan rather than about a store's map iteration order.
/// * It is UNMODIFIABLE ([List.unmodifiable]) and validated once, at
///   construction, so a coordinator can trust every plan it is handed.
///
/// ## COMPATIBILITY
///
/// Constructing with [command], [setupCommand] and [checkName] — the whole
/// pre-existing API — builds a plan of exactly ONE check, and produces exactly
/// one row, with the same command, check name and working directory as before.
/// The only observable difference is that the row's id gains the check-name
/// suffix, which no reader depends on.
///
/// This type is NOT `const`, because a const constructor cannot build the
/// `VerificationCheck` list from its own parameters: Dart does not treat a
/// constructor parameter as a constant inside a const initializer list, so
/// `const [Check(command: command)]` fails to compile. Measured, not assumed —
/// see the `constprobe` note in the lane report.
@immutable
class VerificationPlan {
  VerificationPlan({
    List<VerificationCheck>? checks,
    List<String> command = const ['dart', 'test'],
    List<String>? setupCommand,
    String checkName = 'dart_test',
  }) : checks = List.unmodifiable(
         checks ??
             [
               VerificationCheck(
                 command: command,
                 setupCommand: setupCommand,
                 checkName: checkName,
               ),
             ],
       ) {
    if (this.checks.isEmpty) {
      throw ArgumentError.value(
        checks,
        'checks',
        'a VerificationPlan must carry at least one check; a plan that '
            'verifies nothing is `verificationPlan: null`, which the '
            'coordinator already treats as "no platform verification"',
      );
    }
    final seen = <String>{};
    for (final check in this.checks) {
      if (!_checkNamePattern.hasMatch(check.checkName)) {
        throw ArgumentError.value(
          check.checkName,
          'checkName',
          'a check name must match ${_checkNamePattern.pattern}. It is part of '
              'the verification id (${VerificationCheck.idPrefix}'
              '<executionId>-<checkName>), and an id is only injective if the '
              'name cannot contain the "-" that separates the two halves',
        );
      }
      if (check.workingDirectory.startsWith('/')) {
        throw ArgumentError.value(
          check.workingDirectory,
          'workingDirectory',
          'must be RELATIVE to the execution workspace. An absolute path would '
              'escape the worktree the execution actually ran in',
        );
      }
      if (!seen.add(check.checkName)) {
        throw ArgumentError.value(
          check.checkName,
          'checkName',
          'duplicated in one plan. Two checks with one name would write two '
              'rows under one verification id, and the second would overwrite '
              'the first',
        );
      }
      // Validated HERE rather than as an `assert` on [VerificationCheck]'s
      // const constructor: a `>` over a [Duration] is a method call, and a
      // const constructor's assert condition must be a potentially-constant
      // expression, which built-in relational operators only are for int,
      // double, string and bool. Measured, not assumed — a const
      // `VerificationCheck(timeout: ...)` with a `Duration` assert in the
      // constructor fails to compile. Every other check invariant already
      // lives in this loop, and this constructor is not `const`.
      if (check.timeout != null && check.timeout! <= Duration.zero) {
        throw ArgumentError.value(
          check.timeout,
          'timeout',
          'a verification timeout must be positive. Zero or a negative '
              'duration would kill every check before it could observe '
              'anything, which converts "allowed long enough" into '
              '"never runs" — the one outcome a raised timeout exists to '
              'prevent',
        );
      }
    }
  }

  static final RegExp _checkNamePattern = RegExp(r'^[a-z0-9_]+$');

  final List<VerificationCheck> checks;

  /// The single check's argv — for a plan of exactly one check.
  ///
  /// Throws [StateError] otherwise. There is no honest answer for "the
  /// command" of a plan with three: picking the first would let a caller read
  /// one check's coverage as the plan's.
  List<String> get command => _sole('command').command;

  /// The single check's setup argv, or `null`. See [command].
  List<String>? get setupCommand => _sole('setupCommand').setupCommand;

  /// The single check's name. See [command].
  String get checkName => _sole('checkName').checkName;

  VerificationCheck _sole(String what) {
    if (checks.length != 1) {
      throw StateError(
        'this VerificationPlan carries ${checks.length} checks, so there is no '
        'single `$what`. Read `checks` — one entry per row this execution '
        'persists.',
      );
    }
    return checks.single;
  }
}

/// Coordinates ONE durable agent execution per work item, glued to the durable
/// workflow engine:
///
///  1. Claims the execution (idempotent on the execution id).
///  2. Moves the work item into [WorkItemState.agentExecuting].
///  3. Starts a provider-neutral runtime session, persisting every state
///     change and normalized event as it happens.
///  4. On completion, stamps the requested [AgentRole] onto the result (the
///     agent can never assert its own role), runs the platform's independent
///     verifier in the workspace, persists the evidence as
///     [PlatformVerification], and pushes the work item out of execution.
///  5. Inserts a [ModelExecutionRecord] capturing model usage and cost.
///  6. Exposes [reconcileOrphans] for executions stranded by a process exit.
///
/// The coordinator is provider-agnostic: runtime selection is the request's
/// `runtimeTypeId`, never a hardcoded agent.
class ExecutionCoordinator {
  ExecutionCoordinator({
    required this.store,
    required this.workflowEngine,
    required this.runtime,
    this.verifier = const WorkspaceVerifier(),
    this.verificationPlan,
    this.modelExecutionRecordStore,
    SuccessArtifactChecker? successArtifacts,
  }) : successArtifacts =
           successArtifacts ??
           RoleAwareSuccessArtifacts(probe: const GitWorkspaceDeltaProbe());

  final ExecutionStore store;
  final DurableWorkflowEngine workflowEngine;
  final AgentRuntime runtime;
  final WorkspaceVerifier verifier;
  final VerificationPlan? verificationPlan;
  final ModelExecutionRecordStore? modelExecutionRecordStore;

  /// Decides whether a completed execution produced its lane's artifact.
  ///
  /// Injectable so the rule can be exercised without a git worktree, and so a
  /// caller needing different lane expectations can supply them without this
  /// class growing a second source of truth. See [RoleAwareSuccessArtifacts] for
  /// the default and for why the rule is role-aware at all.
  final SuccessArtifactChecker successArtifacts;

  /// How long a timeout is allowed to wait for the agent process to confirm it
  /// is stopping. Short on purpose: it must not extend the execution's budget
  /// by an unbounded amount just to be polite to a process that may be the
  /// thing that is wedged.
  static const Duration _cancelGrace = Duration(seconds: 5);

  static const WorkflowActor _orchestrator = WorkflowActor(
    actorId: 'orchestrator',
    actorType: ActorType.orchestrator,
  );

  final Map<String, AgentSession> _liveSessions = {};
  final Map<String, StreamSubscription<AgentEvent>> _subscriptions = {};
  final Map<String, Completer<AgentEvent>> _terminalContracts = {};
  final Map<String, Completer<AgentExecution>> _settledContracts = {};
  final Map<String, int> _eventSequences = {};

  bool get isBusy => _liveSessions.isNotEmpty;

  /// How many agent sessions this coordinator currently holds.
  ///
  /// Read-only observability, and the number that must not grow across a
  /// timeout: a drive path that resumes after its execution was released would
  /// otherwise re-register a session nothing will ever take away again, leaking
  /// both the map entry and its event subscription — and, worse, reporting a
  /// dead execution as live.
  int get liveSessionCount => _liveSessions.length;

  /// Whether this process currently holds a LIVE agent session for
  /// [executionId].
  ///
  /// The one question durable state cannot answer. A worker execution row that
  /// is still `agentExecuting` is byte-for-byte identical whether a process is
  /// behind it or died an hour ago, which is why reconciliation cannot infer
  /// liveness from it. This is the live-session set answering directly, and it
  /// is what an [ExecutionLivenessProbe] asks.
  ///
  /// READ-ONLY and side-effect free: it observes, never registers, never
  /// creates and never fabricates a verdict. There is deliberately no way to
  /// mark an execution live from outside, so a `true` here means a session is
  /// genuinely in this process's hands.
  ///
  /// FALSE means "no live session in this coordinator", which is not quite the
  /// same as "provably dead": an execution id this coordinator has never seen
  /// also answers false. A caller that needs to tell those apart must not infer
  /// death from this alone — the scheduler's probe treats an unobservable
  /// execution as `unknown` rather than `dead` for exactly that reason.
  bool hasLiveSession(String executionId) =>
      _liveSessions.containsKey(executionId);

  Future<AgentExecution?> latestExecutionFor(String workItemId) =>
      store.latestExecutionForWorkItem(workItemId);

  /// The transition context for moving an item `agentCompleted -> reviewInProgress`.
  ///
  /// The edge is guarded by `agentResultValid()`, which requires the
  /// PRODUCER's completed [AgentResult] under `context['agentResult']`. This
  /// hands over the very result the completion path stamped
  /// ([_completeSuccess]) — never a synthesized one — read from the execution
  /// that produced the item rather than from the newest execution of any role.
  ///
  /// ## WHY THE NEWEST-ANY-ROLE LOOKUP WAS A SELF-LOCKING DEFECT
  ///
  /// This used to call `latestExecutionForWorkItem`, whose own contract is
  /// "newest by startedAt, any role". That is the implementer on the FIRST
  /// review and the reviewer on every one after, because a reviewer execution
  /// is newer than the implementer it was dispatched to check. So the guard
  /// read the reviewer's result, and a reviewer that failed permanently
  /// prevented the item from EVER entering review again.
  ///
  /// The item is `agent_completed` because a producer ran and succeeded; that
  /// is the evidence this guard exists to check. Reviewing a reviewer's outcome
  /// as precondition evidence for entering review is a category error, and it
  /// is what produced the 243 `outcome = 'rejected'` rows and the four-jobs-a-
  /// minute churn measured in
  /// `docs/engineering/learning/236-transition-rows-that-moved-nothing.md`.
  ///
  /// Resolution is delegated to [resolveProducerExecution] rather than
  /// re-implemented here, so this transition and the stall gate in
  /// `apps/server/lib/src/triage/stalled_work_item_gate.dart` — which has to
  /// park the very same item through the very same edge — cannot disagree about
  /// what produced it.
  ///
  /// If the producer's result is genuinely absent the map omits the key and the
  /// engine rejects the transition, which is the honest outcome: the
  /// `agentCompleted` state is not true without a completed result.
  Future<Map<String, dynamic>> _reviewEntryTransitionContext(
    String workItemId,
  ) async {
    // Re-read here rather than reusing the item loaded by [execute]. That load
    // happens before the role check and the transition; a producer that stamped
    // a fresh `producerActorId` in between would otherwise be read stale. This
    // is one primary-key work-item read on the reviewer DISPATCH path — once
    // per review attempt, never on a scheduler tick — so it does not put the
    // per-tick cost the scheduler lane is careful about on this path.
    final item = await workflowEngine.loadWorkItem(workItemId);
    final producer = await resolveProducerExecution(
      store: store,
      workItemId: workItemId,
      producerActorId: item.metadata?['producerActorId'],
    );
    final producerResult = producer.result;
    return <String, dynamic>{
      'agentAvailable': true,
      'capabilitiesMatch': true,
      if (producerResult != null) 'agentResult': producerResult,
    };
  }

  /// Runs the single execution described by [request]. Re-running the same
  /// execution id after a terminal outcome returns the durable record.
  Future<AgentExecution> execute(AgentExecutionRequest request) async {
    final existing = await store.readExecutionOrNull(request.executionId);
    if (existing != null) {
      if (existing.isTerminal) return existing;
      throw ExecutionAlreadyActiveException(request.executionId);
    }

    final item = await workflowEngine.loadWorkItem(request.workItemId);
    final isReviewer = request.role == AgentRole.engineeringReviewer;
    final runningState = isReviewer
        ? WorkItemState.reviewInProgress
        : WorkItemState.agentExecuting;
    if (item.state != runningState) {
      try {
        await workflowEngine.transition(
          workItemId: request.workItemId,
          to: runningState,
          trigger: TransitionTrigger.systemEvent,
          actor: _orchestrator,
          // The reviewer's `agentCompleted -> reviewInProgress` edge is guarded by
          // `agentResultValid()`, which reads the IMPLEMENTER's completed result
          // from `context['agentResult']`. The scheduler cannot supply it (which is
          // why `engineeringReviewDefinition.skipWorkflowPolicyCheck` is true), but
          // this transition runs against the durable engine, so it must. Every
          // non-reviewer role keeps the original context byte for byte.
          context: isReviewer
              ? await _reviewEntryTransitionContext(request.workItemId)
              : const {'agentAvailable': true, 'capabilitiesMatch': true},
        );
      } on WorkflowTransitionRejectedException {
        // The item moved between the load above and this write — an operator
        // action, a gate, a repair. That is staleness, not a platform fault, and
        // the engine's raw "transition rejected ... is not allowed" string
        // escapes into the job's permanent failure reason if it is allowed out
        // of here. Re-raise it under the name that says what happened. No audit
        // evidence is lost: the engine has already appended the rejected attempt
        // to the transition history, which is where this is explained in full.
        throw WorkItemSupersededException(
          workItemId: request.workItemId,
          observedState: item.state,
          requiredState: runningState,
          role: request.role,
        );
      }
    }

    await store.inTransaction((tx) async {
      await tx.saveRequest(request);
      final startedAt = DateTime.now();
      final execution = AgentExecution(
        executionId: request.executionId,
        workItemId: request.workItemId,
        requestId: request.executionId,
        runtimeTypeId: request.runtimeTypeId,
        role: request.role,
        status: AgentSessionStatus.starting,
        workspace: request.workspace,
        startedAt: startedAt,
        version: 1,
      );
      await tx.saveExecution(execution);

      _eventSequences[request.executionId] = 0;
      await _appendEvent(
        executionId: request.executionId,
        workItemId: request.workItemId,
        type: AgentEventType.executionStarted,
        payload: {
          'role': request.role.wire,
          'runtimeTypeId': request.runtimeTypeId,
          'timeoutSeconds': request.timeoutSeconds,
        },
        via: tx,
      );
    });

    final terminal = Completer<AgentEvent>();
    _terminalContracts[request.executionId] = terminal;
    _settledContracts[request.executionId] = Completer<AgentExecution>();

    // `request.timeoutSeconds` is the budget for the WHOLE dispatch path:
    // session start, the instruction round trip, the terminal-event wait,
    // result retrieval and independent verification. It used to travel no
    // further than `AgentSessionConfig`, where an adapter may apply it to a
    // single ACP call, and nothing here ever enforced it end to end. A session
    // that stalled between two phases therefore waited forever, and the only
    // two bounded waits in the file were 60s on cancel and a hard-coded 30s on
    // the terminal event - a bound that also contradicted a 300s budget by
    // failing healthy agents early. The budget is the authority now, and it
    // ends in a real terminal state rather than an abandoned future.
    final budget = Duration(seconds: request.timeoutSeconds);
    final dispatchStartedAt = DateTime.now();

    return _drive(
      request,
      terminal,
      budget,
      dispatchStartedAt,
    ).timeout(budget, onTimeout: () => _expireExecution(request, budget));
  }

  /// Drives one execution from session start to its durable terminal record.
  ///
  /// Runs under the caller's budget ([execute] applies it to this whole
  /// future), so an individual step that hangs is bounded by the budget rather
  /// than by nothing at all. The budget is passed down as well, because the
  /// terminal-event wait inside [_finalize] must not be allowed to outlive the
  /// execution it is waiting for.
  Future<AgentExecution> _drive(
    AgentExecutionRequest request,
    Completer<AgentEvent> terminal,
    Duration budget,
    DateTime dispatchStartedAt,
  ) async {
    final AgentSession session;
    try {
      session = await runtime.startSession(
        providerId: request.runtimeTypeId,
        config: AgentSessionConfig(
          executionId: request.executionId,
          workItemId: request.workItemId,
          workingDirectory: request.workspace.path,
          timeout: Duration(seconds: request.timeoutSeconds),
          runtimeConfig: request.runtimeConfig ?? const {},
          allowedPaths: request.workspace.allowedPaths,
          environment: request.environment,
        ),
      );
    } on TimeoutException catch (e) {
      // A TIMEOUT, so it settles as one — see `_expireExecution`. The agent
      // never ran, but the reason it never ran is that it ran out of time, and
      // a run that runs out of time is the one failure a bounded retry exists
      // for. The sibling branches below are the crash cases and settle `failed`.
      return _settleWithoutSession(
        request,
        'start timeout: $e',
        status: AgentSessionStatus.interrupted,
      );
    } on AcpTransportException catch (e) {
      // Also a TIMEOUT, by the same argument, and it is the shape production
      // actually hits: `OpenCodeSession.start` converts its own `TimeoutException`
      // into an AcpTransportException ("opencode did not finish starting within
      // Ns"), so the branch above was unreachable for the adapter this
      // coordinator drives.
      //
      // It is equally the shape of a child that died during the handshake. That
      // is not an assessment either — nothing came back over the wire — so it is
      // settled the same way and bounded by `maxAttempts` like every other
      // transient. `ProcessException` (no `opencode` on PATH) is NOT one of
      // these: it lands in the crash branch below and stays permanent, because a
      // missing binary fails identically on every attempt.
      return _settleWithoutSession(
        request,
        'start transport failure: $e',
        status: AgentSessionStatus.interrupted,
      );
    } catch (e) {
      // A CRASH, not a timeout, and deliberately still `failed`. This is the
      // branch that must NOT become retryable: a runtime that throws a plain
      // exception on every start — a `StateError`, a failed spawn — would
      // otherwise be re-dispatched on every job it is given, spending one
      // attempt each time. `maxAttempts` bounds that too, but a permanently
      // broken configuration should fail on the first attempt and say so,
      // rather than burning the retry budget on a certainty.
      return _settleWithoutSession(request, 'start failure: $e');
    }

    // A drive path that resumes AFTER this execution was settled must not
    // reopen it.
    //
    // `_terminalContracts` is inserted before the drive begins and removed by
    // `_releaseExecution`, so its absence means this coordinator has already
    // reached a verdict for this id - normally, or by timeout. Registering the
    // session here anyway would do two lasting harm: the row below would be
    // rewritten from terminal back to `running`, and the entry plus its event
    // subscription would never be removed, because nothing is left driving.
    // The second is worse than it looks - a resurrected `_liveSessions` entry
    // makes `hasLiveSession` answer "alive" for an execution with nothing
    // behind it, which is precisely how a timed-out execution turns back into a
    // zombie that the lease renewal keeps alive forever.
    if (!_terminalContracts.containsKey(request.executionId)) {
      await session.close();
      return _abandonedRecord(request);
    }

    _liveSessions[request.executionId] = session;
    final subscription = session.eventStream.listen(
      (e) => _onSessionEvent(request.executionId, request.workItemId, e),
    );
    _subscriptions[request.executionId] = subscription;

    final running = await store.readExecution(request.executionId);
    if (running.isTerminal) {
      // Settled between the check above and this read. Writing `running` over
      // a terminal row would resurrect it, so stop here and keep the verdict.
      _forget(request.executionId);
      await session.close();
      return running;
    }
    await store.saveExecution(
      running.copyWith(
        status: AgentSessionStatus.running,
        sessionId: session.sessionId,
        version: running.version + 1,
      ),
      expectedVersion: running.version,
    );

    try {
      await session.sendInstruction(
        AgentInstruction(
          instructionId: 'instr-${request.executionId}',
          content: request.instruction,
        ),
      );
    } on TimeoutException {
      // The session recorded the interrupt and will emit SessionInterrupted.
    } on AcpTransportException {
      // The session recorded the transport failure.
    }

    return _finalize(request, terminal, budget, dispatchStartedAt);
  }

  /// The durable record for an execution this coordinator is no longer driving,
  /// or a synthetic terminal one if the row cannot be read.
  Future<AgentExecution> _abandonedRecord(AgentExecutionRequest request) async {
    final recorded = await store.readExecutionOrNull(request.executionId);
    if (recorded != null) return recorded;
    return _settleWithoutSession(
      request,
      'execution was already settled before its session could be registered',
    );
  }

  /// Drops this coordinator's bookkeeping for [executionId] — the live-session
  /// entry AND its event subscription. Both are registered together in [_drive],
  /// so they are released together; leaving the subscription behind keeps the
  /// session object and its event stream reachable for the life of the process.
  void _forget(String executionId) {
    _liveSessions.remove(executionId);
    _subscriptions.remove(executionId)?.cancel();
  }

  /// The last-resort terminal state for an execution whose dispatch path did
  /// not settle inside its budget.
  ///
  /// This is deliberately not an abandoned future. The agent process is asked
  /// to stop, the execution is persisted as a real TERMINAL record carrying an
  /// honest reason, an `executionFailed` event is appended, the work item leaves
  /// [WorkItemState.agentExecuting] for [WorkItemState.agentFailed], and a model
  /// execution record is written - so the job is never left running behind a
  /// durable status string.
  ///
  /// ## WHY THIS SETTLES AS `interrupted`, NOT `failed`
  ///
  /// Because that one word decides whether the job is ever tried again.
  ///
  /// The chain downstream is real and has no discretion in it:
  ///
  /// ```text
  /// AgentSessionStatus.interrupted -> WorkerExecutionStatus.timedOut
  ///                                 (LocalWorker._drive)
  /// WorkerExecutionStatus.timedOut -> JobFailureKind.transient
  ///                                 (RetryPolicy.classify)
  /// JobFailureKind.transient       -> JobQueue.scheduleRetry, bounded by
  ///                                 Job.maxAttempts
  /// AgentSessionStatus.failed     -> WorkerExecutionStatus.executedFail
  ///                                 -> JobFailureKind.permanent
  ///                                 -> JobState.failed, ZERO attempts spent
  /// ```
  ///
  /// A budget expiry was settled as `failed`, so an execution killed by its
  /// budget spent no attempt, reached `JobState.failed` immediately, and the
  /// definition's `maxAttempts` was unreachable for the one failure the
  /// deployment actually observes. `engineeringReviewDefinition.maxAttempts: 2`
  /// was not a retry budget; it was a literal nobody could spend.
  ///
  /// `interrupted` is not a new status invented for this. A runtime that
  /// interrupts its own session already arrives here: `_failureDetails` maps a
  /// driver-emitted [SessionInterrupted] to [AgentSessionStatus.interrupted]
  /// (`:997-1001`). The same agent run, timing out by the runtime's own hand
  /// and timing out by the coordinator's budget, now settles the same way.
  ///
  /// ## WHY A CRASH IS NOT THIS
  ///
  /// The dangerous regression is the opposite direction, and it is prevented by
  /// the only thing that can prevent it: the two are different terminal states,
  /// written by different call sites. [_drive]'s `'start failure: $e'` branch —
  /// an exception raised while starting the session — settles `failed`, and so
  /// does [_abandonedRecord]. Only the two TIMEOUT paths (`_expireExecution`
  /// and the `start timeout:` branch) settle `interrupted`. A runtime that
  /// throws on every start therefore burns one attempt per job and is bounded by
  /// `maxAttempts` like everything else; it does not retry forever, and it does
  /// not get to pretend it was a timeout.
  ///
  /// The drive path may still be wedged somewhere that is not the terminal
  /// wait, and can finish long after this returns.
  ///
  /// It cannot undo this verdict, and NOT because of the optimistic version
  /// guard: both late write sites re-read the row immediately before writing and
  /// CAS against that fresh version, so the version check would pass and the
  /// terminal row WOULD be overwritten. What actually holds the line is the
  /// explicit terminal check each of them makes on the row they just read, plus
  /// the fact that [_drive] refuses to register a session for an execution that
  /// has already been released. A reviewer should treat "the version guard
  /// saves us" as false here: it does not, and the tests assert on the write
  /// sequence rather than on the final row precisely because the final row can
  /// look correct while the row spent real time non-terminal.
  Future<AgentExecution> _expireExecution(
    AgentExecutionRequest request,
    Duration budget,
  ) async {
    final reason = 'execution exceeded its ${budget.inSeconds}s budget';
    final session = _liveSessions[request.executionId];

    // ## DETACH BEFORE ASKING THE SESSION TO STOP — ORDER IS THE FIX
    //
    // Cancelling a live session makes it emit [SessionCancelled], and that
    // event travels back through [_onSessionEvent] into the SAME terminal
    // contract [_finalize] is waiting on. So cancelling first and settling
    // second was a race: whichever of the two completed first decided the
    // execution's status, and the loser overwrote it. A budget expiry therefore
    // settled as `cancelled` some of the time — a NON-retryable class — which
    // is the opposite of what this method exists to produce, and it made the
    // reviewer retry non-deterministic in exactly the run shape it was written
    // for.
    //
    // Removing the contract and the subscription FIRST means the cancellation
    // this coordinator requests cannot become its own verdict: the agent
    // process is still asked to stop, and the durable outcome of a run that hit
    // its budget is the budget, not the stop.
    //
    // The `SessionCancelled` is consequently not appended to the event stream
    // either. That is correct rather than lossy: it is an event the platform
    // manufactured for itself, and [_settleWithoutSession] appends the honest
    // one — `executionFailed`, carrying the budget that was exceeded.
    _forget(request.executionId);
    _terminalContracts.remove(request.executionId);

    if (session != null) {
      try {
        await session.cancel(reason).timeout(_cancelGrace);
      } catch (_) {
        // The session is abandoned; only the durable record survives, and it
        // is written regardless.
      }
    }

    return _settleWithoutSession(
      request,
      'execution exceeded its ${budget.inSeconds}s timeout budget without '
      'reaching a terminal agent event',
      status: AgentSessionStatus.interrupted,
    );
  }

  /// The honest terminal event for a session that stopped answering without
  /// ever reporting one. Routed through the ordinary terminal path, so it lands
  /// on a real durable status rather than on nothing.
  ///
  /// ## [SessionInterrupted], NOT [SessionFailed]
  ///
  /// This is the path a budget expiry actually takes in production, and it was
  /// the one that made the whole retry budget unreachable.
  ///
  /// The terminal wait is bounded by what is LEFT of the execution budget
  /// ([_finalize]), so a session that registers, accepts its instruction and then
  /// goes quiet is settled HERE — by this manufactured event — several ticks
  /// before [_expireExecution]'s outer budget can fire. The manufactured event
  /// was a [SessionFailed], which means the session reported a failure. It did
  /// not: nobody asked it anything and it answered nothing, because the clock
  /// ran out. Reporting that as a failure is what made
  /// `engineeringReviewDefinition.maxAttempts: 2` unreachable for a review
  /// killed at its budget — `failed` classifies as PERMANENT, so the job spent
  /// no attempt and failed on the spot.
  ///
  /// `SessionInterrupted` is the truthful statement and it is what the same run
  /// already produced when the runtime interrupted itself: `_failureDetails`
  /// maps a driver-emitted [SessionInterrupted] to
  /// [AgentSessionStatus.interrupted], and now so does the coordinator's own.
  ///
  /// The crash case is untouched and must stay that way: a session that emits
  /// [SessionFailed] of its own accord still arrives through the same
  /// `_failureDetails` switch and still settles `failed`.
  SessionInterrupted _neverEmittedTerminalEvent(
    String executionId,
    Duration budget,
  ) => SessionInterrupted(
    eventId: 'timeout-$executionId',
    timestamp: DateTime.now(),
    reason:
        'session never emitted a terminal event within the '
        '${budget.inSeconds}s execution budget',
  );

  /// Cancels the live session for [executionId]; the driver loop finalizes the
  /// execution as cancelled and moves the work item out of execution.
  Future<AgentExecution> cancelExecution(
    String executionId,
    String reason,
  ) async {
    final execution = await store.readExecution(executionId);
    if (execution.isTerminal) return execution;
    final session = _liveSessions[executionId];
    final settled = _settledContracts[executionId];
    if (session == null || settled == null) {
      throw ExecutionNotActiveException(executionId);
    }
    await session.cancel(reason);
    return settled.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw TimeoutException(
        'Execution did not reach a terminal state after cancel: $executionId',
      ),
    );
  }

  /// Marks executions that are neither terminal nor driven by this coordinator
  /// as [AgentSessionStatus.orphaned] and exits the work item out of
  /// execution. This is the durable answer to process exits: the platform
  /// never resumes a conversation it cannot prove is still alive.
  Future<List<AgentExecution>> reconcileOrphans({
    String reason = 'Executor lost the session (orphaned execution)',
  }) async {
    final orphans = <AgentExecution>[];
    for (final execution in await store.listExecutions()) {
      if (execution.isTerminal ||
          _liveSessions.containsKey(execution.executionId)) {
        continue;
      }
      final item = await workflowEngine.loadWorkItem(execution.workItemId);

      final now = DateTime.now();
      final orphaned = execution.copyWith(
        status: AgentSessionStatus.orphaned,
        reason: reason,
        completedAt: now,
        version: execution.version + 1,
      );
      await store.inTransaction((tx) async {
        await tx.saveExecution(orphaned, expectedVersion: execution.version);
        await _appendEvent(
          executionId: execution.executionId,
          workItemId: execution.workItemId,
          type: AgentEventType.executionFailed,
          payload: {'kind': 'orphaned', 'reason': reason},
          via: tx,
        );
      });

      if (item.state == WorkItemState.agentExecuting) {
        await workflowEngine.transition(
          workItemId: execution.workItemId,
          to: WorkItemState.agentFailed,
          trigger: TransitionTrigger.systemEvent,
          actor: _orchestrator,
          context: {
            'orphanedExecutionId': execution.executionId,
            'reason': reason,
          },
        );
      }
      orphans.add(orphaned);
    }
    return orphans;
  }

  Future<AgentExecution> _finalize(
    AgentExecutionRequest request,
    Completer<AgentEvent> terminal,
    Duration budget,
    DateTime dispatchStartedAt,
  ) async {
    final executionId = request.executionId;
    final session = _liveSessions[executionId];
    try {
      // The terminal-event wait is bounded by what is LEFT of the execution
      // budget, so it composes with it instead of racing it: it can never
      // outlive the execution, and a slow-but-healthy agent is not failed early
      // by a constant that is unrelated to the configured timeout.
      final remaining = dispatchStartedAt
          .add(budget)
          .difference(DateTime.now());
      final terminalEvent = remaining <= Duration.zero
          ? _neverEmittedTerminalEvent(executionId, budget)
          : await terminal.future.timeout(
              remaining,
              onTimeout: () => _neverEmittedTerminalEvent(executionId, budget),
            );

      final results = await _complete(request, session, terminalEvent);

      // A completion that arrives after the execution was already settled must
      // not overwrite that verdict. This pre-check is an optimisation - it
      // avoids even building the write - and the authoritative check is the one
      // inside the transaction below, which is atomic with the read it guards.
      //
      // This is also what distinguishes a LATE result from a RESURRECTION: a
      // result that arrives while the execution is still open finds a
      // non-terminal row and lands normally, and nothing here discards it.
      final settled = await store.readExecution(executionId);
      if (settled.isTerminal) {
        await session?.close();
        _releaseExecution(executionId, record: settled);
        return settled;
      }

      await store.inTransaction((tx) async {
        await _appendEvent(
          executionId: executionId,
          workItemId: request.workItemId,
          type: results.eventType,
          payload: results.eventPayload,
          via: tx,
        );

        final recorded = await tx.readExecution(executionId);
        if (recorded.isTerminal) return; // Keep the verdict that already won.
        await tx.saveExecution(
          recorded.copyWith(
            status: results.status,
            resultId: results.result.resultId,
            reason: results.reason,
            completedAt: DateTime.now(),
            version: recorded.version + 1,
          ),
          expectedVersion: recorded.version,
        );
      });

      await session?.close();

      final finalRecord = await store.readExecution(executionId);
      _releaseExecution(executionId, record: finalRecord);
      return finalRecord;
    } catch (error) {
      await session?.close();
      _releaseExecution(executionId, error: error);
      // A completion that could not be applied because the work item moved on
      // is ordinary staleness, not a coordinator fault — but it still has to be
      // REPORTED, because the execution did not achieve what it was for. Only
      // the classification changes; the raw engine text is kept in the event
      // payload so the audit trail loses nothing.
      final stale = error is WorkflowTransitionRejectedException;
      final detail = stale
          ? 'late completion could not be applied: work item '
                '${request.workItemId} moved on before this outcome was '
                'recorded (${error.record.fromState.wire} -> '
                '${error.record.toState.wire}); the result and any verification '
                'are persisted under execution $executionId'
          : 'coordinator finalize error: $error';
      try {
        await store.inTransaction((tx) async {
          await _appendEvent(
            executionId: executionId,
            workItemId: request.workItemId,
            type: AgentEventType.executionFailed,
            payload: {
              if (stale) 'kind': 'staleCompletion',
              'error': error.toString(),
            },
            via: tx,
          );
          final stalled = await tx.readExecutionOrNull(executionId);
          if (stalled != null && !stalled.isTerminal) {
            await tx.saveExecution(
              stalled.copyWith(
                status: AgentSessionStatus.failed,
                reason: detail,
                completedAt: DateTime.now(),
                version: stalled.version + 1,
              ),
              expectedVersion: stalled.version,
            );
          }
        });
      } catch (_) {
        // Fail-sealed: the original error is the primary signal, and the
        // settled contract already carries it (see `_releaseExecution`).
      }
      rethrow;
    }
  }

  /// Persists the terminal [AgentResult] (role stamped from the request), runs
  /// independent verification, and advances the work item.
  Future<_Completion> _complete(
    AgentExecutionRequest request,
    AgentSession? session,
    AgentEvent terminalEvent,
  ) async {
    final result = await session?.getResult() ?? _fallbackResult(request);
    final stamped = result.copyWith(
      role: request.role,
      executionId: request.executionId,
    );
    await store.saveResult(request.executionId, stamped);

    // A terminal event can arrive after this execution was already declared
    // failed. The durable row, not the event, decides whether there is still an
    // execution to complete.
    final recorded = await store.readExecutionOrNull(request.executionId);
    final alreadySettled = recorded != null && recorded.isTerminal;

    return switch (terminalEvent) {
      SessionCompleted() => await _completeSuccess(
        request,
        stamped,
        alreadySettled: alreadySettled,
      ),
      _ => await _completeFailure(request, stamped, terminalEvent),
    };
  }

  /// Runs ONE [VerificationCheck] and returns the row it produced, or `null`
  /// when the check COULD NOT RUN.
  ///
  /// ## `null` MEANS "NOT OBSERVED", NEVER "PASSED"
  ///
  /// Two things stop a check before it observes anything: its working
  /// directory is not in this workspace (a plan declaring
  /// `apps/control_plane` in a worktree that has no Flutter app), and the tool
  /// is not installed or the setup step failed first. Neither produced a
  /// verdict, so neither may produce a row — a row is a claim that a check ran
  /// and said something, and a passing row for a check that never ran is a
  /// false claim that a gate reading `requireCheckNames` cannot detect.
  ///
  /// The absence is deliberate and observable: [PlatformVerification] rows are
  /// the whole of the record, so a check that could not run is visible as a
  /// MISSING row, which is exactly what a fail-closed gate needs to see.
  Future<PlatformVerification?> _verifyCheck({
    required VerificationCheck check,
    required AgentExecutionRequest request,
  }) async {
    final workingDirectory = check.resolveAgainst(request.workspace.path);
    // An explicit early-out, and deliberately NOT the load-bearing guard:
    // `Process.start` with a missing `workingDirectory` throws, and the
    // verifier turns that into `ran: false`, so the guard below would produce
    // the same NO ROW on its own. Measured, not assumed: deleting THIS line
    // leaves every test in `multi_check_verification_plan_test.dart` green
    // (mutant M2), while inverting it fails seven of them (M3).
    //
    // It is kept because it is cheap, it avoids spawning a doomed process per
    // absent directory — a 17-check plan against a worktree with no Flutter
    // app would otherwise spawn sixteen of them — and it states the condition
    // where it is understood. The HONESTY property rests on `ran` alone.
    if (!Directory(workingDirectory).existsSync()) return null;

    final outcome = await verifier.verify(
      workingDirectory: workingDirectory,
      command: check.command,
      setupCommand: check.setupCommand,
      // The check's OWN timeout, applied here for the first time in this
      // path — until `5c9e2b74` every check silently took the verifier's
      // 2-minute default, which is what made the server unit-test runner and
      // `flutter test` unexpressible as activated checks. `null` keeps the
      // default, so single-check and pre-existing plans are byte-for-byte
      // unchanged in behaviour. A check that overruns its own timeout is
      // KILLED and recorded as failed (`ran == true`), never skipped.
      timeout: check.timeout,
    );
    if (!outcome.ran) return null;

    return PlatformVerification(
      verificationId: check.verificationIdFor(request.executionId),
      executionId: request.executionId,
      workItemId: request.workItemId,
      checkName: check.checkName,
      status: outcome.passed
          ? AgentClaimStatus.passed
          : AgentClaimStatus.failed,
      mechanism: outcome.mechanism,
      command: outcome.command,
      capturedAt: DateTime.now(),
      detail:
          outcome.detail ??
          (outcome.passed ? 'Verification passed' : 'Verification failed'),
      outputRef: null,
      // The directory THIS check ran in, not the workspace root. For a single
      // check declaring the workspace root — every plan written before this
      // field existed — the two are the same string, so this is unchanged.
      resultPath: workingDirectory,
    );
  }

  Future<_Completion> _completeSuccess(
    AgentExecutionRequest request,
    AgentResult stamped, {
    required bool alreadySettled,
  }) async {
    final verifications = <PlatformVerification>[];
    final plan = verificationPlan;
    // Verification spawns a real process in the workspace and runs BEFORE the
    // workflow transition. For an execution already declared failed, that is a
    // subprocess spawned to produce evidence nobody will read: the write that
    // would carry it is refused, and the transition is already decided.
    if (plan != null && !alreadySettled) {
      // In PLAN ORDER, so the rows below — and the failing one selected from
      // them — are a property of the plan, not of a store's iteration order.
      for (final check in plan.checks) {
        final row = await _verifyCheck(check: check, request: request);
        if (row != null) await store.saveVerification(row);
        if (row != null) verifications.add(row);
      }
    }

    final item = await workflowEngine.loadWorkItem(request.workItemId);
    // The gate reads the PERSISTED [PlatformVerification] rather than a local
    // outcome flag, so the row a reviewer or operator can read is the same row
    // that decided the state.
    //
    // One check refuting the agent's claim is enough to refuse the completion:
    // ANY failing row fails the execution, and "any" is the same rule the
    // single-row plan applied to its one row.
    //
    // An EMPTY list — no plan configured, `alreadySettled`, or every check
    // unable to run — is NOT a failure: a check that never ran has no verdict,
    // and inventing one would strand work items on a failure nothing observed.
    // Absence is the signal, and it is visible to the gate as a missing row.
    final failedChecks = verifications
        .where((v) => v.status == AgentClaimStatus.failed)
        .toList();
    final verificationFailed = failedChecks.isNotEmpty;
    final verificationFailureDetail = verificationFailed
        ? failedChecks.first.detail
        : null;
    // The aggregate over the rows this execution produced. `null` — not a
    // status — when no check ran at all, so a reader of the event payload
    // cannot mistake "nothing was observed" for "everything passed".
    final aggregateVerificationStatus = verificationFailed
        ? AgentClaimStatus.failed
        : verifications.isEmpty
        ? null
        : AgentClaimStatus.passed;

    // ## THE ROLE-AWARE SUCCESS ARTIFACT
    //
    // A clean finish is not a success. Measured on QA: seven IMPLEMENTER
    // executions completed with zero files touched and zero commits, and all
    // seven reached `agent_completed` — the state `engineeringReviewDefinition`
    // dispatches FROM, so the review lane then failed closed for ever because
    // there was nothing to review. Four defects were parked there.
    //
    // `agent_completed` is SHARED, so this cannot be one universal rule: triage
    // legitimately finishes without touching the product. Each lane is asked
    // whether it produced ITS OWN artifact instead. See
    // [RoleAwareSuccessArtifacts].
    //
    // Skipped when verification already refuted the run: a refuted run is a
    // stronger and more specific failure than "produced nothing", and reporting
    // the vaguer one would hide the check that actually caught it.
    final artifact = verificationFailed
        ? null
        : await successArtifacts.inspect(
            executionId: request.executionId,
            role: request.role,
            workspace: request.workspace,
            result: stamped,
          );
    final artifactMissing = artifact?.isMissing ?? false;
    // Promoted explicitly: the `if (artifactMissing)` block below is the only
    // reader, and forcing a `!` at each of six use sites would make the
    // invariant "missing implies non-null" a thing to re-check by eye.
    final missingArtifact = artifactMissing ? artifact : null;

    if (request.role == AgentRole.engineeringReviewer) {
      // For engineering reviewers, the coordinator must NOT transition out of
      // reviewInProgress; the tick handler will raise a human decision instead.
      //
      // That applies to the artifact rule too, and is the reason this lane can
      // enforce an artifact without owning its routing: where a verdict-absent
      // review GOES is `apps/server`'s, and this package owns no part of it.
      // What is decided here is only whether this execution completed
      // truthfully.
    } else if (verificationFailed) {
      // The platform's independent check ran and disagreed with the agent's
      // success report. Recording `agentCompleted` anyway advanced a work item
      // the platform had just refuted, and nothing downstream re-derived the
      // failure from the verification row — the item sat at `agentCompleted`
      // with a failed job behind it, and the operator affordance that can act
      // on it accepts only `agentFailed`. `agentExecuting -> agentFailed` is
      // legal for the orchestrator actor
      // (packages/workflow_engine/.../work_item_transitions.dart:105).
      //
      // No `metadataMerge` here, deliberately. `producerActorId` names the
      // execution whose result the engineering-review gate's `actorIsNotSelf()`
      // guard is checked against; a refuted result is not a producer, and an
      // operator retry re-runs triage and claims a fresh execution that stamps
      // the identity on its own success.
      final reason =
          verificationFailureDetail ?? 'platform verification failed';
      await workflowEngine.transition(
        workItemId: request.workItemId,
        to: WorkItemState.agentFailed,
        trigger: TransitionTrigger.agentResult,
        actor: _orchestrator,
        // The engine's own `reason` parameter, which is the field PERSISTED on
        // the transition record — `context` only reaches the guard evaluator.
        // Without it the item settles at `agentFailed` with nothing in its
        // history saying why, which is the "stranded with no signal" half of
        // the same defect. Supplying it cannot flip the outcome: the engine
        // derives `outcome` from the policy, never from the presence of a
        // reason.
        reason: reason,
        context: {
          'agentResult': stamped,
          // Same key `_completeFailure` uses, so a reader does not have to know
          // which of the two paths settled the item.
          'reason': reason,
        },
      );
    } else if (artifactMissing) {
      // The run finished cleanly and produced none of its lane's artifact.
      //
      // `AgentSessionStatus.failed` — deliberately, and it is the whole argument
      // for this branch existing. The chain downstream has no discretion in it:
      //
      // ```text
      // AgentSessionStatus.failed -> WorkerExecutionStatus.executedFail
      //                              (LocalWorker._drive)
      // WorkerExecutionStatus.executedFail -> JobFailureKind.permanent
      //                              (RetryPolicy.classify)
      // JobFailureKind.permanent -> JobState.failed, ZERO attempts spent,
      //                              and NOT returned to a lane entry state
      //                              (_returnRetriableItemsToEntryStates only
      //                               acts on `retryWaiting` + isRetryable)
      // ```
      //
      // That last line is the operator's requirement — "that should be a fail
      // allow an unlimited human try again". `interrupted` would have been the
      // obvious wrong answer: it classifies TRANSIENT, so the item would be
      // returned to a lane entry state and re-dispatched automatically, and an
      // automatic retry of a run that produced nothing will produce nothing
      // again. So the item waits at `agentFailed` for a human, whose retry is
      // already uncounted. `WorkItemState.agentExecuting -> agentFailed` is
      // legal for the orchestrator actor
      // (packages/workflow_engine/.../work_item_transitions.dart:105).
      //
      // No `metadataMerge`, for the same reason the verification branch omits
      // it: `producerActorId` names the execution whose result the
      // engineering-review gate's `actorIsNotSelf()` guard is checked against,
      // and a run that produced nothing is not a producer.
      final reason = missingArtifact!.reason!;
      await workflowEngine.transition(
        workItemId: request.workItemId,
        to: WorkItemState.agentFailed,
        trigger: TransitionTrigger.agentResult,
        actor: _orchestrator,
        // The engine's own `reason` parameter, which is the field PERSISTED on
        // the transition record. Without it the item settles at `agentFailed`
        // with nothing in its history saying why, which is the "stranded with no
        // signal" half of the very defect this rule closes.
        reason: reason,
        context: {'agentResult': stamped, 'reason': reason},
      );
    } else {
      await workflowEngine.transition(
        workItemId: request.workItemId,
        to: WorkItemState.agentCompleted,
        trigger: TransitionTrigger.agentResult,
        actor: _orchestrator,
        context: {
          'agentResult': stamped,
          if (item.qaContractId != null) 'qaContractId': item.qaContractId,
        },
        // Record the producing execution as the work item's producer identity.
        // The engineering-review gate's `actorIsNotSelf()` guard compares the
        // reviewer's execution id against this, and WITHOUT a real producer the
        // guard has only a literal to fall back on — a check that can never
        // fail is not a check. `metadataMerge` is additive: it never replaces
        // the rest of the metadata (defect payload, retry attempt, …).
        //
        // ## THE ARTIFACT VERDICT TRAVELS WITH IT
        //
        // The event payload below also carries
        // `successArtifactUndetermined`, and that is observability only. The
        // scheduler — the component that spends a real implementer execution
        // per pass of the completion cycle — reads `worker_execution`,
        // `worker_result` and `worker_event`, and `agent_event` is none of them,
        // so a verdict published only there is invisible to the thing that has
        // to act on it. This is the same channel `producerActorId` uses, on the
        // same transition, inside the same transaction: the flag and the state
        // move together or not at all.
        //
        // WRITTEN ON EVERY PASS, `false` included. `artifact` is non-null on
        // this branch by construction — `verificationFailed` short-circuits to
        // `null` and routes to `agentFailed` above, and `artifactMissing` routes
        // there too — so there is no "unknown" case to express here and an
        // absent key would mean only "this item predates the flag". Leaving a
        // stale `true` in place for a determined completion would let the
        // scheduler's brake count a streak that never happened.
        metadataMerge: {
          'producerActorId': stamped.executionId,
          SuccessArtifactArtifacts.undeterminedMetadataKey:
              SuccessArtifactArtifacts.undeterminedFlagFor(
                artifact!.satisfaction,
              ),
        },
      );
    }

    await _insertModelExecutionRecord(
      request,
      stamped,
      !verificationFailed && !artifactMissing,
      artifactMissing
          ? missingArtifact?.reason
          : verificationFailed
          ? verificationFailureDetail ?? 'platform verification failed'
          : null,
    );

    if (artifactMissing) {
      final missing = missingArtifact!;
      return _Completion(
        status: AgentSessionStatus.failed,
        result: stamped,
        reason: missing.reason!,
        eventType: AgentEventType.executionFailed,
        eventPayload: {
          'role': request.role.wire,
          'kind': SuccessArtifactArtifacts.eventKind,
          'expectedArtifact': missing.kind.name,
          'reason': missing.reason,
          ...missing.details,
        },
      );
    }

    return _Completion(
      status: AgentSessionStatus.completed,
      result: stamped,
      reason: stamped.status == AgentResultStatus.completed
          ? 'end_turn'
          : 'session ended without a completed result',
      eventType: stamped.status == AgentResultStatus.completed
          ? AgentEventType.executionCompleted
          : AgentEventType.executionFailed,
      eventPayload: {
        'role': request.role.wire,
        // The AGGREGATE over every check that produced a row, not one row's
        // status: with several checks, reporting the first row's status would
        // let a plan with one failing check out of several publish `passed`.
        // Absent when no check produced a row — see
        // [ExecutionCoordinator._verifyCheck].
        'verificationStatus': aggregateVerificationStatus?.wire,
        // An artifact that could not be established is recorded rather than
        // silently dropped. It did NOT fail the execution — see
        // [RoleAwareSuccessArtifacts] — but "the platform could not look" must
        // not be indistinguishable in the record from "the platform looked and
        // saw the artifact".
        if (artifact?.satisfaction == ArtifactSatisfaction.undetermined)
          'successArtifactUndetermined': artifact?.reason,
      },
    );
  }

  Future<_Completion> _completeFailure(
    AgentExecutionRequest request,
    AgentResult stamped,
    AgentEvent terminalEvent,
  ) async {
    final (status, eventType, reason) = _failureDetails(terminalEvent);

    if (request.role == AgentRole.engineeringReviewer) {
      // Do not transition workflow state out of reviewInProgress for reviewer
      // terminal outcomes; tick handler will create the human decision.
    } else {
      await workflowEngine.transition(
        workItemId: request.workItemId,
        to: WorkItemState.agentFailed,
        trigger: TransitionTrigger.agentResult,
        actor: _orchestrator,
        context: {'agentResult': stamped, 'reason': reason},
      );
    }

    await _insertModelExecutionRecord(request, stamped, false, reason);

    return _Completion(
      status: status,
      result: stamped,
      reason: reason,
      eventType: eventType,
      eventPayload: {'role': request.role.wire, 'reason': reason},
    );
  }

  void _onSessionEvent(
    String executionId,
    String workItemId,
    AgentEvent event,
  ) {
    final normalized = _normalize(event);
    if (normalized != null) {
      final (type, payload) = normalized;
      store.appendEvent(
        AgentEventRecord(
          eventId: event.eventId,
          executionId: executionId,
          workItemId: workItemId,
          sequence: _nextSequence(executionId),
          type: type,
          occurredAt: event.timestamp,
          payload: payload,
        ),
      );
    }

    final terminal = _asTerminal(event);
    if (terminal != null) {
      final contract = _terminalContracts[executionId];
      if (contract != null && !contract.isCompleted) {
        contract.complete(terminal);
      }
    }
  }

  int _nextSequence(String executionId) {
    final next = (_eventSequences[executionId] ?? 0) + 1;
    _eventSequences[executionId] = next;
    return next;
  }

  (AgentEventType, Map<String, dynamic>)? _normalize(AgentEvent event) {
    return switch (event) {
      InstructionSent() => (
        AgentEventType.message,
        {'kind': 'instruction_sent'},
      ),
      AgentMessageChunk() => (
        AgentEventType.message,
        {'kind': 'agent_message_chunk'},
      ),
      ToolCallStarted(:final toolCallId, :final tool) => (
        AgentEventType.toolStarted,
        {'toolCallId': toolCallId, 'tool': tool},
      ),
      ToolCallCompleted(:final toolCallId) => (
        AgentEventType.toolCompleted,
        {'toolCallId': toolCallId},
      ),
      ToolCallFailed(:final toolCallId, :final error) => (
        AgentEventType.toolFailed,
        {'toolCallId': toolCallId, 'error': error},
      ),
      ArtifactProduced(:final artifactId, :final type, :final path) => (
        AgentEventType.artifactProduced,
        {'artifactId': artifactId, 'type': type, 'path': path},
      ),
      LogLine(:final level) => (
        AgentEventType.warning,
        {'kind': 'log_line', 'level': level},
      ),
      ProgressUpdate() => (AgentEventType.message, {'kind': 'progress'}),
      SessionCompleted(:final result) => (
        AgentEventType.executionCompleted,
        {'status': result.status.wire},
      ),
      SessionFailed(:final error) => (
        AgentEventType.executionFailed,
        {'error': error},
      ),
      SessionCancelled(:final reason) => (
        AgentEventType.executionCancelled,
        {'reason': reason},
      ),
      SessionInterrupted(:final reason) => (
        AgentEventType.executionFailed,
        {'kind': 'interrupted', 'reason': reason},
      ),
      SessionStarted() || UsageUpdate() => null,
    };
  }

  AgentEvent? _asTerminal(AgentEvent event) {
    return switch (event) {
      SessionCompleted() ||
      SessionFailed() ||
      SessionCancelled() ||
      SessionInterrupted() => event,
      _ => null,
    };
  }

  (AgentSessionStatus, AgentEventType, String) _failureDetails(
    AgentEvent terminalEvent,
  ) {
    return switch (terminalEvent) {
      SessionCancelled(:final reason) => (
        AgentSessionStatus.cancelled,
        AgentEventType.executionCancelled,
        reason,
      ),
      SessionInterrupted(:final reason) => (
        AgentSessionStatus.interrupted,
        AgentEventType.executionFailed,
        reason,
      ),
      SessionFailed(:final error) => (
        AgentSessionStatus.failed,
        AgentEventType.executionFailed,
        error,
      ),
      _ => (
        AgentSessionStatus.failed,
        AgentEventType.executionFailed,
        'unknown terminal event',
      ),
    };
  }

  /// Settles an execution this coordinator never drove to a terminal session
  /// event — no session to finalise, but a durable terminal record owed
  /// regardless, because a job left non-terminal behind a durable status string
  /// is the failure this whole method exists to prevent.
  ///
  /// ## [status] IS THE WHOLE ARGUMENT
  ///
  /// Default `failed` is the honest answer for "the dispatch path died". The
  /// two call sites that are reporting a TIMEOUT pass
  /// [AgentSessionStatus.interrupted] explicitly, because the distinction is
  /// not cosmetic: it decides whether the job spends an attempt and retries
  /// inside its `maxAttempts`, or fails permanently having spent none. See
  /// [_expireExecution] for the full chain, and for why the opposite regression
  /// — making a genuine crash retryable — is prevented by keeping these two
  /// call sites separate rather than by any guard inside this method.
  Future<AgentExecution> _settleWithoutSession(
    AgentExecutionRequest request,
    String reason, {
    AgentSessionStatus status = AgentSessionStatus.failed,
  }) async {
    final result = _fallbackResult(request, reason: reason);
    final stamped = result.copyWith(
      role: request.role,
      executionId: request.executionId,
    );
    await store.saveResult(request.executionId, stamped);
    await _appendEvent(
      executionId: request.executionId,
      workItemId: request.workItemId,
      type: AgentEventType.executionFailed,
      payload: {'error': reason, 'settledAs': status.name},
    );

    try {
      if (request.role == AgentRole.engineeringReviewer) {
        // Skip workflow transition for reviewer failures.
      } else {
        await workflowEngine.transition(
          workItemId: request.workItemId,
          to: WorkItemState.agentFailed,
          trigger: TransitionTrigger.agentResult,
          actor: _orchestrator,
          context: {'agentResult': stamped, 'reason': reason},
        );
      }
    } on WorkflowTransitionRejectedException {
      // The work item may already be out of execution; the execution record
      // above is the durable source of truth.
    }

    await _insertModelExecutionRecord(request, stamped, false, reason);

    final recorded = await store.readExecution(request.executionId);
    await store.saveExecution(
      recorded.copyWith(
        status: status,
        resultId: stamped.resultId,
        reason: reason,
        completedAt: DateTime.now(),
        version: recorded.version + 1,
      ),
      expectedVersion: recorded.version,
    );
    final finalRecord = await store.readExecution(request.executionId);
    _releaseExecution(request.executionId, record: finalRecord);
    return finalRecord;
  }

  /// Removes the per-execution bookkeeping once the durable record is settled
  /// ([[record]]) or the coordinator is abandoning it ([[error]]), completing
  /// the settled contract so `cancelExecution` never waits on a dead lock.
  void _releaseExecution(
    String executionId, {
    AgentExecution? record,
    Object? error,
  }) {
    _forget(executionId);
    _eventSequences.remove(executionId);
    _terminalContracts.remove(executionId);
    final settled = _settledContracts.remove(executionId);
    if (settled != null && !settled.isCompleted) {
      if (error != null) {
        // `cancelExecution` is the only reader of this contract, and on the
        // ordinary failure path nobody is calling it. Completing with an error
        // and no listener therefore reports the error to the ambient zone as
        // UNHANDLED, which poisons whatever ran the drive — and it happens on
        // exactly the late-completion path where the drive is already failing
        // for a benign reason. Registering a listener marks the error handled;
        // it does NOT consume it, so a `cancelExecution` awaiting the same
        // future still receives it and still rejects.
        unawaited(settled.future.then<void>((_) {}, onError: (Object _) {}));
        settled.completeError(error);
      } else if (record != null) {
        settled.complete(record);
      }
    }
  }

  AgentResult _fallbackResult(
    AgentExecutionRequest request, {
    String reason = 'session failed before emitting a result',
  }) {
    return AgentResult(
      resultId: 'result-${request.executionId}',
      sessionId: '',
      workItemId: request.workItemId,
      status: AgentResultStatus.failed,
      artifacts: const [],
      diagnostics: AgentDiagnostics(
        exitCode: 1,
        durationMs: 0,
        toolCalls: 0,
        errors: [
          DiagnosticEntry(
            code: 'coordinator_failure',
            message: reason,
            severity: 'error',
          ),
        ],
        warnings: const [],
      ),
      structuredResult: const {},
      completedAt: DateTime.now(),
    );
  }

  Future<void> _insertModelExecutionRecord(
    AgentExecutionRequest request,
    AgentResult result,
    bool success,
    String? error,
  ) async {
    final modelExecutionRecordStore = this.modelExecutionRecordStore;
    if (modelExecutionRecordStore == null) return;

    final metadata = result.metadata ?? {};
    final usage = metadata['usage'] as Map<String, dynamic>?;
    final used = (usage?['used'] as num?)?.toInt() ?? 0;
    final size = (usage?['size'] as num?)?.toInt() ?? 0;
    final cost = (usage?['cost'] as num?)?.toDouble() ?? 0.0;

    final modelId = (metadata['model'] as String?) ?? 'unknown';
    final provider = (metadata['provider'] as String?) ?? request.runtimeTypeId;
    final escalationIndex = (metadata['escalationIndex'] as int?) ?? 0;

    final taskType = _taskTypeFromRole(request.role);
    final startedAt = result.metadata?['startedAt'] != null
        ? DateTime.parse(result.metadata!['startedAt'] as String)
        : DateTime.now().subtract(const Duration(minutes: 5));
    final finishedAt = DateTime.now();

    final record = ModelExecutionRecord(
      workItemId: request.workItemId,
      jobId: request.workItemId,
      agentExecutionId: request.executionId,
      role: request.role,
      modelId: modelId,
      provider: provider,
      inputTokens: used,
      outputTokens: size - used,
      totalTokens: size,
      cachedReadTokens: 0,
      costUsd: cost,
      currency: 'USD',
      startedAt: startedAt,
      finishedAt: finishedAt,
      success: success,
      error: error,
      escalationIndex: escalationIndex,
      taskType: taskType,
    );

    await modelExecutionRecordStore.insert(record);
  }

  String _taskTypeFromRole(AgentRole role) {
    return switch (role) {
      AgentRole.triageDefect => 'production',
      AgentRole.implementer => 'production',
      AgentRole.correctionImplementer => 'production',
      AgentRole.integrator => 'production',
      AgentRole.designAgent => 'designReview',
      AgentRole.designReviewer => 'designReview',
      AgentRole.focusedReviewer => 'designReview',
      AgentRole.engineeringReviewer => 'engineeringReview',
      AgentRole.qaArchitect => 'architectureReview',
      AgentRole.qaExecutor => 'qaReview',
      AgentRole.releaseEngineer => 'production',
      AgentRole.deploymentAuthority => 'production',
    };
  }

  Future<void> _appendEvent({
    required String executionId,
    required String workItemId,
    required AgentEventType type,
    Map<String, dynamic> payload = const {},
    ExecutionStore? via,
  }) {
    final store = via ?? this.store;
    final sequence = _nextSequence(executionId);
    return store.appendEvent(
      AgentEventRecord(
        eventId: 'evt-$executionId-$type-$sequence',
        executionId: executionId,
        workItemId: workItemId,
        sequence: sequence,
        type: type,
        occurredAt: DateTime.now(),
        payload: payload,
      ),
    );
  }
}

class _Completion {
  const _Completion({
    required this.status,
    required this.result,
    required this.reason,
    required this.eventType,
    this.eventPayload = const {},
  });

  final AgentSessionStatus status;
  final AgentResult result;
  final String reason;
  final AgentEventType eventType;
  final Map<String, dynamic> eventPayload;
}
