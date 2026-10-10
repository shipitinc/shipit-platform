import 'dart:io';

import 'package:control_plane_server/src/credentials/repository_access_verifier.dart';
import 'package:control_plane_server/src/credentials/repository_snapshot_acquirer.dart';
import 'package:control_plane_server/src/credentials/secret_material.dart';
import 'package:control_plane_server/src/credentials/secret_provider.dart';
import 'package:control_plane_server/src/credentials/ssh_remote.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';

/// A host key a human confirmed, and the deploy key's own fingerprint, spelled
/// so a test can never accidentally pass one for the other.
///
/// Deliberately two obviously different values. The whole point of the host-key
/// distinction is that substituting one for the other must fail, and that
/// failure is only demonstrable if the two are distinguishable in the fixture.
const String kTestHostKeyFingerprint = 'SHA256:hostKeyFingerprintForTestsOnly';
const String kTestCredentialFingerprint =
    'SHA256:deployKeyFingerprintForTestsOnly';

/// A second, entirely unrelated host — the fixture for product-agnosticism.
const String kOtherHostKeyFingerprint = 'SHA256:anotherHostKeyForTestsOnly';
const String kOtherHost = 'git@second-remote.test';

/// A commit-shaped string. Nothing executes it; the acquirer only compares it.
const String kTestRevision = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

/// A [SecretProvider] that answers from memory and records what it was asked
/// for.
///
/// [reads] holds the reference NAMES this provider was asked for and never a
/// value, so a test can assert §13a's "referenced by name" mechanically.
class RecordingSecretProvider implements SecretProvider {
  RecordingSecretProvider({this.material = const [1, 2, 3, 4]});

  final List<int> material;

  /// Reference names this provider was asked for. Never values.
  final List<String> reads = [];

  @override
  String get providerId => 'recording-test-provider';

  @override
  bool get isDocumentedFallback => false;

  @override
  Map<String, String> describe() => {'providerId': providerId};

  @override
  Future<String> store({
    required String referenceName,
    required SecretBytes secret,
  }) async => referenceName;

  @override
  Future<SecretBytes> read({required String referenceName}) async {
    reads.add(referenceName);
    return SecretBytes(material);
  }

  @override
  Future<void> destroy({required String referenceName}) async {}
}

/// A [RepositoryAccessVerifier] that reports a clone without opening a socket.
///
/// It EXTENDS the real verifier and overrides only [verify], rather than
/// implementing a test-only port, so the lane's trust path in a test is the
/// same path as in production: `CredentialKeyService.verifyAccess` still calls
/// `RepositoryAccessVerifier.verify`, still reads the same outcome fields, and
/// still records the result on the credential row.
class ScriptedAccessVerifier extends RepositoryAccessVerifier {
  ScriptedAccessVerifier({
    this.succeeded = true,
    this.committedRevision,
    this.secretMaterialRemoved = true,
  });

  final bool succeeded;
  final String? committedRevision;
  final bool secretMaterialRemoved;

  /// Host-key fingerprints this verifier was asked to enforce. A test asserting
  /// that a credential fingerprint was NOT used as a host key fingerprint reads
  /// this list.
  final List<String> demandedHostKeyFingerprints = [];

  @override
  Future<AccessProbeOutcome> verify({
    required SshRemote remote,
    required SecretBytes privateKeyPem,
    required String confirmedHostKeyFingerprint,
  }) async {
    demandedHostKeyFingerprints.add(confirmedHostKeyFingerprint);
    return AccessProbeOutcome(
      succeeded: succeeded,
      secretMaterialRemoved: secretMaterialRemoved,
      committedRevision: committedRevision,
      failureReason: succeeded ? null : 'scripted failure',
    );
  }
}

/// A [RepositorySnapshotMaterializer] that writes a small tree instead of
/// cloning, and records what it was asked to enforce.
class ScriptedSnapshotMaterializer implements RepositorySnapshotMaterializer {
  ScriptedSnapshotMaterializer({
    this.revision = kTestRevision,
    this.reportRevision,
    Map<String, String>? files,
  }) : files = files ?? {'README.md': '# Fixture repository\n\nA fixture.\n'};

  /// The revision the tree honestly reports.
  final String revision;

  /// What [materialize] CLAIMS, when it is meant to lie about the revision.
  final String? reportRevision;

  /// Mutable on purpose: a test changes what discovery sees to drive the merge
  /// path, and a fixture that could not be changed could only ever test the
  /// reuse path.
  final Map<String, String> files;

  /// Host-key fingerprints demanded of this materializer.
  final List<String> demandedHostKeyFingerprints = [];

  /// Roots created and not yet released. A test asserts this is empty after a
  /// run, which is how "the snapshot tree is removed on every path" is checked.
  final List<Directory> created = [];

  /// How many times private material was handed to a clone.
  int materializations = 0;

  @override
  Future<RepositorySnapshot> materialize({
    required String productId,
    required String repositoryId,
    required SshRemote remote,
    required SecretBytes privateKeyPem,
    required String confirmedHostKeyFingerprint,
    required String pinnedRevision,
  }) async {
    materializations++;
    demandedHostKeyFingerprints.add(confirmedHostKeyFingerprint);
    final root = Directory.systemTemp.createTempSync('baseline_fixture_');
    created.add(root);
    for (final entry in files.entries) {
      File('${root.path}/${entry.key}').writeAsStringSync(entry.value);
    }
    return RepositorySnapshot(
      productId: productId,
      repositoryId: repositoryId,
      revision: reportRevision ?? revision,
      sourceRef: remote.toSshUrl(),
      acquiredAt: DateTime.utc(2026, 1, 1),
      root: root,
      onRelease: () {
        if (root.existsSync()) root.deleteSync(recursive: true);
      },
    );
  }
}

/// Writes an active credential for [repositoryId] through the engine's own
/// domain methods, so the fixture establishes exactly the two halves of the
/// trust chain production establishes: a host key a human confirmed, and a
/// connectivity check that actually succeeded.
Future<RepositoryCredential> seedCredential(
  ProductRegistryEngine engine, {
  required String productId,
  required String repositoryId,
  String host = 'git@remote.test:org/repository.git',
  String hostKeyFingerprint = kTestHostKeyFingerprint,
  String credentialFingerprint = kTestCredentialFingerprint,
  String confirmedBy = 'operator@example.test',
  bool confirmed = true,
  bool usable = true,
}) async {
  var credential = await engine.recordGeneratedCredential(
    productId: productId,
    repositoryId: repositoryId,
    referenceName: 'GIT_TEST_${repositoryId}_SSH',
    publicKey: 'ssh-ed25519 AAAAtestpublichalf fixture',
    fingerprint: credentialFingerprint,
    host: host,
    now: DateTime.utc(2026, 1, 1),
  );
  if (confirmed) {
    credential = await engine.confirmHostKey(
      productId: productId,
      credentialId: credential.credentialId,
      hostKeyFingerprint: hostKeyFingerprint,
      confirmedBy: confirmedBy,
      now: DateTime.utc(2026, 1, 2),
    );
  }
  if (usable) {
    credential = await engine.recordCredentialCheck(
      productId: productId,
      credentialId: credential.credentialId,
      succeeded: true,
      checkedBy: 'fixture',
      now: DateTime.utc(2026, 1, 3),
    );
  }
  return credential;
}

/// A complete in-memory product registry. No database, no network, no Docker.
class RegistryFixture {
  RegistryFixture()
    : store = InMemoryProductRegistryStore(),
      decisions = InMemoryHumanDecisionStore() {
    engine = ProductRegistryEngine(
      store: store,
      humanDecisionStore: decisions,
    );
  }

  final InMemoryProductRegistryStore store;
  final InMemoryHumanDecisionStore decisions;
  late final ProductRegistryEngine engine;

  /// Registers [productId] with one repository reference, and nothing else. No
  /// credential: whether a product is sweepable depends on that being a
  /// separate step, so a fixture that always mints one would hide the conjunct.
  Future<void> registerProduct({
    required String productId,
    String repositoryId = 'repo',
    String uri = 'git@remote.test:org/repository.git',
    RepositoryProvider provider = RepositoryProvider.github,
  }) async {
    await engine.createProduct(
      productId: productId,
      name: productId,
      description: 'fixture product',
      now: DateTime.utc(2026, 1, 1),
    );
    await engine.addRepositoryReference(
      repositoryId: repositoryId,
      productId: productId,
      uri: uri,
      kind: RepositoryKind.monorepo,
      provider: provider,
      now: DateTime.utc(2026, 1, 1),
    );
  }
}
