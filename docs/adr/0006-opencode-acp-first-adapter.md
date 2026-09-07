# ADR 0006: OpenCode ACP as First Agent Adapter

## Status
Accepted

## Context
Need a concrete agent provider to validate the `AgentRuntime` interface and build initial workflows. Criteria:
- Open protocol (not vendor-locked)
- Local execution (no API keys, no cloud dependency)
- Structured output (artifacts, diagnostics, results)
- Streaming events for real-time dashboard
- Session persistence/resume capability
- Active development and community

## Decision
**OpenCode ACP (Agent Communication Protocol)** is the first `AgentRuntime` adapter.

## Rationale

| Criterion | OpenCode ACP |
|-----------|--------------|
| Open protocol | ✅ JSON-RPC over stdio, documented |
| Local execution | ✅ Runs on developer machine / worker |
| No API keys | ✅ Uses local OAuth / API keys configured by user |
| Structured output | ✅ Tools, artifacts, diagnostics in protocol |
| Streaming events | ✅ Real-time tool calls, logs, progress |
| Session resume | ✅ Conversation history persisted |
| Active development | ✅ Actively maintained by OpenCode team |
| Dart client feasible | ✅ JSON-RPC 2.0, stdio transport |

Alternatives considered:
- **Claude Code**: Proprietary, no public protocol, cloud-dependent
- **Cursor**: Proprietary, no public API
- **GitHub Copilot CLI**: Limited scripting, no session management
- **Custom LLM wrapper**: Reinvents agent loop, tool calling, context management

## Implementation Scope (Initial)

```
agent_runtime/lib/src/adapters/opencode/
├── opencode_adapter.dart      # Implements AgentAdapter
├── opencode_client.dart       # JSON-RPC 2.0 over stdio
├── opencode_mapper.dart       # ACP events → AgentEvent
├── opencode_config.dart       # Binary path, env, args
└── opencode_types.dart        # ACP message types (generated)
```

### ACP Features Used (v1)
- `initialize` / `initialized` handshake
- `session/start` with `cwd`, `model`, `permissions`
- `session/instruction` for sending tasks
- `session/event` stream: `tool_call`, `tool_result`, `log`, `progress`
- `session/artifact` for file outputs
- `session/end` with `result` (structured)
- `session/cancel` for interruption

### Out of Scope (Initial)
- Model routing / selection
- Multi-session multiplexing
- Custom tool definitions beyond ACP built-ins
- Authentication flow (assumes pre-configured)

## Configuration

```dart
class OpencodeConfig {
  final String binaryPath;        // 'opencode' or full path
  final Map<String, String> env;  // API keys, config
  final List<String> args;        // Additional flags
  final Duration startupTimeout;  // Default 30s
  final Duration instructionTimeout; // Default 10m
}
```

## Worker Integration

OpenCode runs on worker machines:
- Linux workers: `opencode` binary in PATH
- macOS workers: `opencode` binary in PATH (via Homebrew)
- Docker workers: `opencode` in container image
- AgentRuntime launches process via `Process.start()` with stdio pipes

## Consequences

### Positive
- Validates provider-neutral architecture immediately
- No cloud costs for local development
- Full control over agent behavior
- Open protocol = no vendor lock-in
- Community contributions to ACP benefit us

### Negative
- OpenCode maturity/bugs affect platform stability
- ACP protocol evolution may require adapter updates
- Limited to OpenCode's model/tool capabilities
- No managed service option (self-hosted only)

### Mitigation
- Pin OpenCode version in Docker images
- Adapter tests against specific ACP version
- Maintain adapter compatibility layer
- Design interface to accommodate other providers