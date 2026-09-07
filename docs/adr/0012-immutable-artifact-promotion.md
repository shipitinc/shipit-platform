# ADR 0012: Immutable Artifact Promotion

## Status
Accepted

## Context
Deployments must promote immutable artifacts across environments:
- Artifact built once, deployed many times
- Content-addressed (SHA-256) for integrity
- Promotion rules defined in `DeploymentContract` (from AEF)
- Human approval gates for production
- Rollback to previous artifact instant
- Audit trail: what, when, by whom, from where

## Decision
**Immutable, content-addressed artifacts** promoted via `DeploymentProtocol` with explicit promotion rules and human gates.

## Artifact Model

```dart
@immutable
class DeploymentArtifact {
  final String artifactId;           // UUID
  final String contentHash;          // SHA-256 of artifact bundle
  final ArtifactManifest manifest;   // Metadata, contents, SBOM
  final DateTime builtAt;
  final String builtBy;              // WorkItem ID / AgentSession ID
  final Map<String, String> labels;  // version, git-sha, etc.
}

@immutable
class ArtifactManifest {
  final String name;                 // 'my-app', 'my-lib'
  final String version;              // SemVer from build
  final String gitCommit;            // Full SHA
  final List<ArtifactFile> files;    // Files in bundle
  final SoftwareBillOfMaterials sbom; // CycloneDX/SPDX
  final Map<String, String> metadata; // Build info, test results
}

@immutable
class ArtifactFile {
  final String path;                 // Relative path in bundle
  final String sha256;               // File hash
  final int sizeBytes;
  final String mediaType;            // 'application/octet-stream', etc.
}
```

## Artifact Store Interface

```dart
abstract interface class ArtifactStore {
  Future<DeploymentArtifact> store(ArtifactBundle bundle);
  Future<DeploymentArtifact?> getByHash(String contentHash);
  Future<DeploymentArtifact?> getById(String artifactId);
  Future<List<DeploymentArtifact>> list({
    String? name,
    String? versionPrefix,
    DateTime? since,
  });
  Future<void> delete(String artifactId); // Soft delete only
}
```

Implementations:
- **Local**: File system + SQLite index (Docker Compose)
- **Production**: Google Artifact Registry / AWS S3 + DynamoDB index

## Promotion Engine

```dart
@immutable
class PromotionRule {
  final String fromEnvironment;      // 'staging', 'production'
  final String toEnvironment;        // 'production', 'mobile-staging'
  final PromotionGate gate;          // auto, human, schedule, metric
  final Map<String, dynamic> config; // Gate-specific config
}

enum PromotionGate {
  auto,        // Auto-promote if health checks pass
  human,       // Requires HumanDecision
  schedule,    // Promote at scheduled time
  metric,      // Promote when metric threshold met
}

class PromotionEngine {
  Future<PromotionResult> evaluate(
    DeploymentArtifact artifact,
    List<PromotionRule> rules,
    Map<String, DeploymentRecord> currentDeployments,
  );
}
```

## Promotion Path (Example)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   BUILD     │────►│  STAGING    │────►│ PRODUCTION  │
│  (artifact) │     │  (auto)     │     │  (human)    │
└─────────────┘     └─────────────┘     └─────────────┘
                           │                     │
                           ▼                     ▼
                    ┌─────────────┐       ┌─────────────┐
                    │   MOBILE    │       │   MOBILE    │
                    │  STAGING    │       │ PRODUCTION  │
                    │ (TestFlight/│       │ (App Store/ │
                    │  Play Int.) │       │  Play Prod) │
                    └─────────────┘       └─────────────┘
```

## Deployment Target Interface

```dart
abstract interface class DeploymentTarget {
  String get targetId;               // 'cloud-run-prod', 'testflight'
  String get environment;            // 'staging', 'production'
  List<WorkerCapability> get requiredCapabilities;
  
  Future<DeploymentResult> deploy(DeploymentArtifact artifact, DeploymentConfig config);
  Future<DeploymentStatus> getStatus(String deploymentId);
  Future<void> rollback(String deploymentId, String previousArtifactId);
  Future<HealthCheckResult> healthCheck(String deploymentId);
}
```

Implementations:
- `CloudRunTarget` - `gcloud run deploy`
- `FirebaseHostingTarget` - `firebase deploy`
- `TestFlightTarget` - `fastlane pilot upload`
- `PlayStoreTarget` - `fastlane supply`
- `KubernetesTarget` - **NOT IMPLEMENTED** (per principles)

## Deployment Record

```dart
@immutable
class DeploymentRecord {
  final String deploymentId;         // UUID
  final String artifactId;           // References DeploymentArtifact
  final String targetId;             // DeploymentTarget.targetId
  final String environment;          // 'staging', 'production'
  final DeploymentStatus status;     // pending, deploying, healthy, failed, rolled_back
  final DateTime startedAt;
  final DateTime? completedAt;
  final DeploymentResult? result;    // URL, version, health data
  final String? triggeredBy;         // HumanDecision ID or 'auto'
  final String? rollbackOf;          // Previous deploymentId if rollback
}
```

## Human Approval Gate

```dart
// In workflow_engine: Transition from Deploying → Deployed for production
// requires HumanDecision with:
HumanDecision(
  decisionType: 'deployment_approval',
  workflowId: workItemId,
  choice: 'approve' | 'reject',
  rationale: 'Verified staging health, ready for prod',
  signature: CryptographicSignature, // Ed25519
)
```

## Rollback

```dart
// Instant rollout to previous healthy artifact
Future<void> rollback(String deploymentId) async {
  final record = await deploymentRepo.get(deploymentId);
  final previous = await deploymentRepo.getPreviousHealthy(record.environment);
  
  await target.rollback(record.deploymentId, previous.artifactId);
  
  await deploymentRepo.create(DeploymentRecord(
    deploymentId: Uuid.v4(),
    artifactId: previous.artifactId,
    targetId: record.targetId,
    environment: record.environment,
    status: DeploymentStatus.healthy,
    startedAt: DateTime.now(),
    completedAt: DateTime.now(),
    triggeredBy: 'rollback',
    rollbackOf: record.deploymentId,
  ));
}
```

## Consequences

### Positive
- Artifact built once, verified once, deployed many times
- Content hash = tamper-proof, reproducible
- Promotion rules declarative, auditable
- Human gates only where required (production)
- Instant rollback to known-good artifact
- SBOM in every artifact for supply chain security

### Negative
- Artifact storage costs (mitigated: retention policies)
- Promotion engine adds latency (mitigated: async, cached)
- Multiple targets = more integration surface

### Mitigation
- Retention: Keep last 50 artifacts per name, last 10 per environment
- Promotion evaluation < 100ms (in-memory rules)
- Target interfaces versioned, tested in isolation