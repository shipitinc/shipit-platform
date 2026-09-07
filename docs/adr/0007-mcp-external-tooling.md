# ADR 0007: MCP for External Agent Tooling

## Status
Accepted

## Context
Agents need access to external tools and services:
- File system operations (read, write, glob, grep)
- Shell command execution
- Git operations
- HTTP/API calls
- Database queries
- Cloud provider CLIs (gcloud, aws, firebase)
- Custom internal tools

Requirements:
- Standardized tool interface across agents
- Security: sandboxing, permissions, audit logging
- Extensibility: add new tools without agent changes
- Language-neutral: usable by any agent provider

## Decision
**Model Context Protocol (MCP)** is the standard for external agent tooling.

## Rationale

| Requirement | MCP Fit |
|-------------|---------|
| Standardized interface | ✅ JSON-RPC tools/resources/prompts |
| Security model | ✅ Permissions, approval flow |
| Extensibility | ✅ Add servers without agent changes |
| Language-neutral | ✅ JSON-RPC over stdio/HTTP/SSE |
| Ecosystem | ✅ Growing (Anthropic, community servers) |
| Agent support | ✅ OpenCode, Claude Code, others adopting |

Alternatives considered:
- **Custom tool protocol**: Reinvents MCP, no ecosystem
- **Function calling (OpenAI)**: Tied to OpenAI, no stdio transport
- **Plugin systems (VS Code, JetBrains)**: Editor-specific, not agent-native
- **Shell wrappers**: No schema, no permissions, no discovery

## Architecture

```
┌─────────────────┐     MCP (JSON-RPC)      ┌─────────────────┐
│   Agent         │◄────────────────────────►│   MCP Server    │
│   (OpenCode)    │   tools/resources        │   (filesystem,  │
│                 │   prompts                │    git, gh,     │
└─────────────────┘                          │    custom)      │
                                              └─────────────────┘
```

### MCP Server Types

| Server | Capabilities | Security |
|--------|--------------|----------|
| `filesystem` | read, write, list, glob | Path allowlist |
| `shell` | execute commands | Command allowlist, timeout |
| `git` | status, diff, commit, push | Repo allowlist |
| `github` | PR, issues, actions | Token scopes |
| `gcloud` | deploy, logs, secrets | Project allowlist |
| `custom` | Internal APIs | Auth + RBAC |

## Integration with AgentRuntime

`AgentRuntime` does **not** manage MCP directly. The agent (OpenCode) manages MCP servers via its config.

ShipIt Platform provides:
1. **MCP server configurations** per worker capability
2. **Worker capability → MCP server mapping**
3. **Audit logging** of tool invocations (via agent event stream)

```dart
// Worker capability declares available MCP servers
class WorkerCapability {
  final String name;              // 'linux', 'macos', 'flutter'
  final List<McpServerConfig> mcpServers;
}

class McpServerConfig {
  final String name;              // 'filesystem', 'github'
  final String transport;         // 'stdio', 'http', 'sse'
  final String command;           // For stdio: 'mcp-server-filesystem'
  final List<String> args;
  final Map<String, String> env;  // Tokens, config
  final List<String> allowedPaths; // For filesystem
  final List<String> allowedCommands; // For shell
}
```

## Security Model

- **Least privilege**: Workers only get MCP servers matching their capability
- **Path allowlists**: Filesystem server restricted to workspace
- **Command allowlists**: Shell server only allows approved commands
- **Token scoping**: GitHub/GCloud tokens scoped to specific repos/projects
- **Audit trail**: All tool calls logged via `AgentEvent.ToolCallStarted/Completed`

## Consequences

### Positive
- Standardized tool access across all agents
- Rich ecosystem of MCP servers
- Security boundaries enforced at MCP server level
- Agents don't need direct infrastructure access
- New tools = new MCP server, no agent changes

### Negative
- MCP specification still evolving
- Not all agents support MCP equally (OpenCode does)
- Additional process management (MCP servers per session)
- Debugging tool calls spans agent + MCP server

### Mitigation
- Pin MCP spec version in documentation
- Test with OpenCode's MCP implementation
- Supervise MCP servers via worker process manager
- Correlate logs via session ID