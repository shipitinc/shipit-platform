# ADR 0002: Serverpod for Control Plane Backend

## Status
Accepted

## Context
The control plane backend needs:
- PostgreSQL persistence with type-safe ORM
- Auto-generated Dart client for frontend
- Real-time WebSocket support for agent event streaming
- Built-in authentication/authorization
- Database migrations
- OpenAPI generation
- Good Dart/Flutter integration

## Decision
**Serverpod** is the backend framework for the control plane.

## Rationale

| Requirement | Serverpod Fit |
|-------------|---------------|
| Type-safe PostgreSQL ORM | ✅ Generated from Dart definitions |
| Dart client generation | ✅ `serverpod generate` creates client |
| Real-time/WebSocket | ✅ Built-in `ServerpodWebSocket` |
| Auth | ✅ Built-in auth module (email, OAuth) |
| Migrations | ✅ `serverpod create-migration` |
| OpenAPI | ✅ Auto-generated from endpoints |
| Dart/Flutter native | ✅ Written in Dart, for Dart |
| Package ecosystem | ✅ `serverpod_*` packages |

Alternatives considered:
- **Dart Frog / Shelf**: No ORM, no client gen, no realtime built-in
- **NestJS (TypeScript)**: Type sharing requires manual sync, no Flutter client
- **Go + gRPC**: No Dart client gen, separate protobuf maintenance
- **Firebase/Supabase**: Vendor lock-in, less control over workflow logic

## Consequences

### Positive
- End-to-end type safety: DB → Backend → Frontend
- Single source of truth for data models
- Real-time agent event streaming to dashboard
- Built-in auth saves implementation time
- Migrations version-controlled with code

### Negative
- Smaller community than NestJS/Express
- Less mature ecosystem for some integrations
- Opinionated structure may not fit all cases

### Mitigation
- Use Serverpod for core API/persistence only
- Keep business logic in `packages/*` (framework-agnostic)
- Contribute fixes upstream

## Implementation
```
apps/server/
├── lib/
│   ├── src/
│   │   ├── endpoints/       # Serverpod endpoints
│   │   ├── persistence/     # Table definitions + repositories
│   │   ├── services/        # Business logic (uses packages/*)
│   │   └── server.dart      # Serverpod config
│   └── server.dart
├── generated/               # Generated client (committed)
└── pubspec.yaml
```

- Tables defined in Dart → Serverpod generates SQL + Dart models
- Endpoints return `platform_contracts` types directly
- Services coordinate `workflow_engine`, `agent_runtime`, etc.
- WebSocket endpoints for `AgentEvent` streaming