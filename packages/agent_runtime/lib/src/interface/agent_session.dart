import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';

import 'agent_event.dart';
import 'agent_instruction.dart';

/// A live (or resumable) agent runtime session. Sessions are transient; the
/// platform persists [AgentExecution] records and [AgentResult], never the
/// conversation.
abstract interface class AgentSession {
  String get sessionId;
  String get executionId;
  String get workItemId;
  AgentSessionStatus get status;

  Future<void> start(AgentSessionConfig config);
  Future<void> sendInstruction(AgentInstruction instruction);
  Stream<AgentEvent> get eventStream;
  Future<void> cancel(String reason);
  Future<AgentResult> getResult();
  Future<List<AgentArtifact>> getArtifacts();
  Future<void> close();
}

@immutable
class AgentSessionConfig {
  const AgentSessionConfig({
    required this.executionId,
    required this.workItemId,
    required this.workingDirectory,
    required this.timeout,
    this.runtimeConfig = const {},
    this.allowedPaths,
    this.sessionId,
    this.environment,
  });

  final String executionId;
  final String workItemId;

  /// Workspace directory the runtime process runs in.
  final String workingDirectory;

  /// The execution budget for this session, as the caller computed it.
  ///
  /// ## REQUIRED, NOT DEFAULTED — this used to default to 5 minutes
  ///
  /// `const Duration(minutes: 5)` sat here as an optional parameter, so a caller
  /// that forgot to pass one got five minutes and no error at all: the session
  /// would quietly give up mid-turn and report an interruption with nothing
  /// pointing at the missing argument. It was the same typed-in literal as
  /// `OpenCodeProcessTransport.requestTimeout`, one layer up, and fixing only
  /// the lower layer would have left this one to re-introduce the same ceiling
  /// through a different call site.
  ///
  /// Required is the fix. The budget is policy and belongs to
  /// `AgentExecutionBudgets`, which is where its provenance lives; a default
  /// here is a second place to change it and a place with none.
  final Duration timeout;

  /// Opaque runtime configuration (e.g. {'model': <id>, 'executable': <path>}).
  /// Values do not leak into workflow policy.
  final Map<String, String> runtimeConfig;

  /// Absolute path prefixes the agent may operate on. The runtime passes this
  /// through to the agent as its permitted scope.
  final List<String>? allowedPaths;

  /// When set, the session is a resumption of this existing ACP session.
  final String? sessionId;

  /// Additive environment overrides for the runtime process. Never secrets;
  /// these come from a worker [EnvironmentPolicy] allowlist (ADR 0015).
  final Map<String, String>? environment;
}

/// The budget an adapter's `checkHealth` probe runs under.
///
/// ## THIS IS NOT A SECOND WIRE BOUND
///
/// The other `Duration(minutes: 5)` this lane removed was a per-request ceiling
/// on `session/prompt` — a ceiling on the work itself. This one is not that: a
/// health probe asks the runtime to answer `initialize` and nothing else, and
/// that is a genuinely different question from "how long may an engineering
/// review take", so it gets its own named number instead of borrowing the
/// execution budget (three hours to learn whether the binary exists is not a
/// health check) and instead of inheriting a silent five-minute default (which is
/// what an optional parameter gave it, invisibly, for the same five minutes).
///
/// ## DERIVATION — PROVISIONAL, like the execution budgets
///
/// The only measured fact available is the loopback ACP handshake in
/// `opencode_process_transport_test.dart`, which completes in single-digit
/// seconds including process spawn. There is no measurement of a real `opencode
/// acp` handshake on the slowest host this runs on, so this is 10x the observed
/// order of magnitude rather than an observation of a tail. NO OPERATOR-STATED
/// RANGE EXISTS for a health probe.
///
/// It is named, documented and guarded by
/// `test/agent_session_budget_bounds_test.dart` precisely because it is still a
/// guess: a bare `const Duration(minutes: 5)` in an adapter is indistinguishable
/// from this, and that is the failure mode the whole lane is about.
const Duration healthProbeTimeout = Duration(seconds: 30);
