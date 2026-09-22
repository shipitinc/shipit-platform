# ADR 0003: Flutter Web for Control Plane Frontend

## Status
Accepted

## Context
The control plane frontend needs:
- Real-time dashboard for agent sessions, workflows, deployments
- Rich data visualization (state machines, timelines, graphs)
- Complex forms for human decisions, design reviews
- Code sharing with backend (types, validation)
- Accessibility and responsive design
- Team has Flutter expertise

## Decision
**Flutter Web** is the frontend framework for the control plane dashboard.

## Rationale

| Requirement | Flutter Web Fit |
|-------------|-----------------|
| Type sharing with backend | ✅ Same Dart types via `platform_contracts` |
| Real-time updates | ✅ Serverpod client + Streams |
| Complex UI | ✅ Custom widgets, canvas, animations |
| Data visualization | ✅ `fl_chart`, custom painters |
| Forms/validation | ✅ `reactive_forms`, shared validators |
| Accessibility | ✅ Semantics, screen reader support |
| Responsive | ✅ LayoutBuilder, MediaQuery |
| Team expertise | ✅ Existing Flutter knowledge |
| shipit-ui integration | ✅ Consumes same Flutter package |

Alternatives considered:
- **React/TypeScript**: No native type sharing, separate validation logic
- **Svelte/SvelteKit**: Smaller ecosystem, no Dart type sharing
- **Dart Frog + HTMX**: Limited interactivity for real-time agent streaming
- **Flutter + WebAssembly (WasmGC)**: Future, not yet stable for production

## Consequences

### Positive
- Single language: Dart everywhere
- `platform_contracts` types used directly in UI
- Serverpod client provides type-safe API calls
- `shipit-ui` design system consumed natively
- Hot reload for rapid iteration

### Negative
- Larger initial bundle size (~2-3MB gzipped)
- SEO not relevant (authenticated dashboard)
- Flutter Web rendering differences vs mobile
- Fewer third-party web components

### Mitigation
- Code splitting via deferred imports
- Pre-rendering not needed (authenticated app)
- Use `shipit-ui` for consistent components
- Monitor bundle size in CI

## Implementation
```
packages/control_plane_client/
├── lib/
│   ├── src/
│   │   ├── pages/           # Route-level pages
│   │   ├── widgets/         # Thin wrappers around shipit-ui
│   │   ├── state/           # Riverpod providers
│   │   ├── services/        # API client (generated)
│   │   └── main.dart
│   └── main.dart
├── test/
└── pubspec.yaml             # Depends on shipit-ui, platform_contracts
```

- Generated Serverpod client in `lib/generated/`
- Riverpod for state management
- `shipit-ui` as git dependency or pub package
- Responsive breakpoints: mobile < 600, tablet 600-900, desktop > 900