# ADR 0001: Dart as Primary Platform Implementation Language

## Status
Accepted

## Context
ShipIt Platform needs a primary implementation language for:
- Control plane backend (Serverpod)
- Control plane frontend (Flutter Web)
- Shared domain packages (contracts, workflow engine, agent runtime, etc.)
- Worker tooling and CLI

Requirements:
- Single language across backend/frontend/packages for type sharing
- Strong typing, null safety, immutability support
- Excellent JSON serialization (code generation)
- Native async/await for agent/event streaming
- Good ecosystem for PostgreSQL, gRPC, WebSocket
- Team familiarity and hiring pool

## Decision
**Dart** is the primary implementation language for all ShipIt Platform packages, backend, and frontend.

## Rationale

| Criterion | Dart Score | Notes |
|-----------|------------|-------|
| Single language full-stack | ✅ | Serverpod + Flutter Web + packages |
| Type sharing | ✅ | Same types in backend, frontend, packages |
| Null safety | ✅ | Sound null safety since Dart 2.12 |
| Immutability patterns | ✅ | `freezed`, `sealed class`, `@immutable` |
| JSON serialization | ✅ | `json_serializable` + `freezed` |
| Code generation | ✅ | `build_runner` mature ecosystem |
| Async/Streams | ✅ | Native `Stream`, `async/await`, `isolate` |
| PostgreSQL | ✅ | Serverpod ORM, `postgres` package |
| gRPC/Protobuf | ✅ | `grpc-dart`, `protobuf` |
| WebSocket | ✅ | `web_socket_channel`, Serverpod realtime |
| Team familiarity | ✅ | Existing Flutter/Dart expertise |
| Hiring | ✅ | Growing Dart/Flutter market |

Alternatives considered:
- **TypeScript/Node.js**: No native Flutter Web integration, weaker type sharing with mobile
- **Go**: No frontend story, no Flutter
- **Kotlin**: No mature Flutter Web, weaker Dart ecosystem integration
- **Python**: No frontend, weak mobile story

## Consequences

### Positive
- Single type definitions across `platform_contracts` → backend → frontend
- `freezed`/`json_serializable` eliminates serialization bugs
- Serverpod generates Dart client from backend definitions
- Hot reload for frontend development
- Shared test utilities across packages

### Negative
- Smaller ecosystem than TypeScript/Go for some infrastructure tooling
- Serverpod is younger than NestJS/Express
- Fewer engineers know Dart vs TypeScript/Go

### Mitigation
- Invest in internal Dart tooling and documentation
- Use `melos` (v7+) on native `dart pub workspaces` for monorepo management
- Contribute upstream to Serverpod/flutter packages

## Implementation
- All `packages/*` written in Dart
- `apps/server` uses Serverpod (Dart)
- `packages/control_plane_client` uses Flutter Web (Dart)
- Root `pubspec.yaml` defines the workspace
- `workspace:` list + `melos` for cross-package commands