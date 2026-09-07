# ADR 0011: Linux + macOS Worker Capability Model

## Status
Accepted

## Context
Workers execute tasks dispatched by the platform. Need explicit capability model for:
- Linux (Docker, Flutter, Android, Node, Python, OpenCode)
- macOS (Xcode, iOS Simulator, Flutter, OpenCode)
- iOS (physical devices, TestFlight)
- Android (emulators, physical devices, Play Store)
- Future: Windows, specialized hardware

Requirements:
- Capability-based task dispatch (match task requirements to worker)
- Extensible (new capabilities without code changes)
- Worker health, capacity, artifact cache awareness
- Platform-agnostic (worker doesn't know about workflows)

## Decision
**Explicit `WorkerCapability` enum + capability-based dispatch** in `worker_protocol` package.

## Capability Enum

```dart
enum WorkerCapability {
  linux,        // Generic Linux (Ubuntu 24.04)
  docker,       // Docker daemon access
  flutter,      // Flutter SDK + Dart
  android,      // Android SDK + Emulator
  macos,        // Generic macOS (Sequoia+)
  ios,          // iOS Simulator + Xcode
  xcode,        // Full Xcode toolchain
  // Future: windows, gpu, device-farm, etc.
}
```

Each capability has metadata:

```dart
@immutable
class CapabilitySpec {
  final WorkerCapability capability;
  final String version;           // e.g., '3.22', '15.0', '34'
  final Map<String, String> metadata; // arch, sdk-path, etc.
  final List<String> providedTools;   // 'opencode', 'gcloud', 'fastlane'
}
```

## Task Requirements

```dart
@immutable
class TaskRequirements {
  final Set<WorkerCapability> requiredCapabilities;
  final Map<WorkerCapability, String> minVersions; // capability -> min version
  final Duration estimatedDuration;
  final int maxRetries;
  final Map<String, String> environment; // Injected env vars
}
```

## Capability Matching

```dart
class CapabilityMatcher {
  // Returns workers that satisfy ALL required capabilities
  List<WorkerRegistration> match(
    TaskRequirements requirements,
    List<WorkerRegistration> availableWorkers,
  ) {
    return availableWorkers.where((worker) {
      return requirements.requiredCapabilities.every((cap) {
        final spec = worker.capabilities[cap];
        return spec != null &&
               _versionSatisfies(spec.version, requirements.minVersions[cap]);
      });
    }).toList();
  }
}
```

## Worker Registration

```dart
@immutable
class WorkerRegistration {
  final String workerId;           // UUID
  final String poolId;             // 'linux-pool-1', 'macos-pool-prod'
  final Map<WorkerCapability, CapabilitySpec> capabilities;
  final WorkerStatus status;       // idle, busy, offline, draining
  final int currentLoad;           // Active tasks
  final int maxConcurrency;        // Configured limit
  final DateTime lastHeartbeat;
  final Map<String, ArtifactCacheEntry> artifactCache; // For layer caching
}
```

## Dispatch Strategy

```dart
enum DispatchStrategy {
  leastLoaded,      // Fewest active tasks
  bestFit,          // Most specific capability match
  affinity,         // Prefer worker with cached artifacts
  roundRobin,       // Distribute evenly
}
```

## Worker Pool Configuration

| Pool | Capabilities | Concurrency | Use Case |
|------|--------------|-------------|----------|
| `linux-general` | linux, docker, flutter, android, opencode | 4 | General agent tasks, builds |
| `linux-docker-heavy` | linux, docker | 8 | Container builds, integration tests |
| `macos-general` | macos, ios, xcode, flutter, opencode | 2 | iOS builds, macOS agent tasks |
| `macos-device-farm` | macos, ios, xcode | 1 | Physical device tests (specialized) |

## Worker Heartbeat Protocol

```
Worker → Platform (every 30s):
  POST /api/v1/workers/heartbeat
  {
    "workerId": "...",
    "status": "idle|busy|offline",
    "currentLoad": 2,
    "capabilities": { "linux": {"version": "3.22"}, ... },
    "artifactCache": { "flutter-3.22": "sha256:..." }
  }

Platform → Worker (on task assignment):
  POST /api/v1/workers/{id}/tasks
  {
    "taskId": "...",
    "requirements": { "requiredCapabilities": ["linux", "flutter"] },
    "payload": { ... },  // Task-specific input
    "timeout": "30m"
  }

Worker → Platform (on completion):
  POST /api/v1/workers/{id}/tasks/{taskId}/result
  {
    "status": "success|failed|timeout",
    "output": { ... },
    "artifacts": [...],
    "durationMs": 120000
  }
```

## Consequences

### Positive
- Explicit, typed capabilities (no string matching)
- Dispatcher optimizes for affinity, load, cache
- Workers are dumb - all orchestration in platform
- New capabilities added to enum + matcher only
- Testable matching logic in isolation

### Negative
- Enum changes require recompilation (mitigated: additive only)
- Capability version matching complexity
- Worker registration/heartbeat adds network chatter

### Mitigation
- Capability enum in `platform_contracts` (shared)
- Version parsing uses `pub_semver` compatible logic
- Heartbeat interval configurable (30s default)
- Worker offline detection after 3 missed heartbeats