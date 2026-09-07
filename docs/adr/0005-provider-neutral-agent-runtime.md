# ADR 0005: Provider-Neutral AgentRuntime

## Status
Accepted

## Context
ShipIt Platform must orchestrate coding agents without coupling to a specific provider. Requirements:
- OpenCode ACP is the first adapter
- Future: Claude Code, Cursor, GitHub Copilot, custom agents
- Agent conversations are ephemeral; only structured results persist
- Agents need: start, send instruction, stream events, cancel, resume, collect artifacts
- Workflow engine must not know about specific agent protocols

## Decision
**Provider-neutral `AgentRuntime` interface** in `agent_runtime` package. All provider-specific code lives in `agent_runtime/adapters/`.

## Architecture

```
agent_runtime/
├── lib/src/interface/
│   ├── agent_session.dart      # Abstract interface
│   ├── agent_adapter.dart      # Adapter contract
│   ├── agent_event.dart        # Normalized event stream
│   ├── agent_instruction.dart  # Input to agent
│   └── agent_capability.dart   # Declared capabilities
├── lib/src/adapters/
│   ├── opencode/
│   │   ├── opencode_adapter.dart
│   │   ├── opencode_client.dart
│   │   ├── opencode_mapper.dart
│   │   └── opencode_config.dart
│   └── agent_adapter_registry.dart
└── lib/src/agent_runtime.dart  # Facade
```

## AgentSession Interface

```dart
abstract interface class AgentSession {
  // Lifecycle
  Future<AgentSessionState> start(AgentSessionConfig config);
  Future<void> cancel(String reason);
  Future<void> resume(String sessionId);  // Where provider permits
  
  // Interaction
  Future<void> sendInstruction(AgentInstruction instruction);
  Stream<AgentEvent> get eventStream;
  
  // Results
  Future<AgentResult> getResult();
  Future<List<AgentArtifact>> getArtifacts();
}
```

## Adapter Contract

```dart
abstract interface class AgentAdapter {
  String get providerId;           // 'opencode', 'claude-code', etc.
  String get displayName;
  List<AgentCapability> get capabilities;
  
  Future<AgentSession> createSession(AgentSessionConfig config);
  Future<bool> canResume(String sessionId);
  Future<AgentSession> resumeSession(String sessionId);
  
  // Health/management
  Future<AdapterHealth> checkHealth();
  Future<void> shutdown();
}
```

## Event Normalization

All adapters map provider events to normalized `AgentEvent`:

```dart
sealed class AgentEvent {
  const AgentEvent();
}

class SessionStarted extends AgentEvent { ... }
class InstructionSent extends AgentEvent { ... }
class ToolCallStarted extends AgentEvent { ... }
class ToolCallCompleted extends AgentEvent { ... }
class ToolCallFailed extends AgentEvent { ... }
class ArtifactProduced extends AgentEvent { ... }
class LogLine extends AgentEvent { ... }
class ProgressUpdate extends AgentEvent { ... }
class SessionCompleted extends AgentEvent { ... }
class SessionFailed extends AgentEvent { ... }
class SessionCancelled extends AgentEvent { ... }
```

## OpenCode ACP Adapter (First Implementation)

- Implements `AgentAdapter` for OpenCode ACP protocol
- Thin ACP client (`opencode_client.dart`) - no business logic
- Maps ACP events → `AgentEvent` (`opencode_mapper.dart`)
- Handles ACP-specific session lifecycle
- Config via `opencode_config.dart` (path, env, args)

## Future Adapters

Each new provider adds only:
1. `provider_adapter.dart` implementing `AgentAdapter`
2. `provider_client.dart` for protocol communication
3. `provider_mapper.dart` for event/result normalization
4. Registration in `agent_adapter_registry.dart`

## Consequences

### Positive
- Workflow engine depends only on `AgentSession` interface
- New providers added without touching core packages
- Agent conversations never leak into system state
- Testable with fake/mock adapters
- Clear separation: orchestration vs. provider protocol

### Negative
- Adapter maintenance burden per provider
- Feature parity varies (resume, artifacts, streaming)
- ACP protocol changes require adapter updates

### Mitigation
- Define minimum viable adapter interface
- Document capability matrix per provider
- Automated contract tests for adapter interface
- OpenCode adapter maintained in-repo; others can be external packages