import 'package:control_plane_server/server.dart';
import 'package:control_plane_server/src/baseline/baseline_test_fixtures.dart';
import 'package:control_plane_server/src/baseline/durable_workspace_materializer.dart';
import 'package:control_plane_server/src/baseline/durable_workspace_runtime.dart';
import 'package:control_plane_server/src/credentials/secret_material.dart'
    show SecretBytes;
import 'package:control_plane_server/src/credentials/ssh_remote.dart'
    show SshRemote;
import 'package:platform_contracts/platform_contracts.dart'
    show ProductBaseline, ProductBaselineStatus;
import 'package:product_registry/product_registry.dart'
    show InMemoryProductRegistryStore, ProductRegistryEngine;
import 'package:test/test.dart';

/// The boot-time OPERATOR INSTRUCTION — the one production caller of durable
/// workspace provisioning.
///
/// ## What is under test
///
/// Two things, and the second is the one that matters:
///
///  1. the parser, because an instruction that is silently half-read is an
///     instruction that provisions nothing and reports nothing; and
///  2. the FAILURE POSTURE, because this is the only place a durable clone is
///     created in production, and a failure that let the server keep serving
///     would leave a deployment looking provisioned in exactly the state the
///     operator asked to leave.
///
/// The composition root is not stood up here — that needs a live database and a
/// bind port. What runs is the same function `run()` calls, over the same
/// trigger, over A1's real runtime with its two network seams substituted.
const String _envName = 'SHIPIT_PROVISION_DURABLE_WORKSPACE';

const String _productId = 'p-1';
const String _repositoryId = 'repo-1';
const String _revision = 'f0f3494957bb90df0a1c15a9fb4734ca6e49634d';

void main() {
  group('absence is a state, not a fault', () {
    test('an unset variable yields no instruction', () {
      expect(resolveDurableWorkspaceProvisionInstruction({}), isNull);
    });

    test('a blank one does too, and does not throw', () {
      expect(
        resolveDurableWorkspaceProvisionInstruction({_envName: '   '}),
        isNull,
        reason:
            'an operator who exported the variable empty on a later start must '
            'not have their platform refuse to boot. Absent and malformed are '
            'different things, and only the second is a fault',
      );
    });

    test(
      'the absent outcome is a PRINTED state an operator can read',
      () async {
        final armed = await _armedRuntime();
        final outcome = await runOperatorDurableWorkspaceProvision(
          null,
          store: armed.store,
          engine: armed.engine,
          runtime: armed.runtime,
          log: _discard,
        );

        expect(outcome['requested'], isFalse);
        expect(
          outcome['note'],
          contains('no product has a durable clone unless an operator set'),
          reason:
              'an operator reading one startup line must be able to tell '
              '"nobody asked for a durable clone" from "we asked and it '
              'failed", without grepping for something that is not there',
        );
      },
    );
  });

  group('a malformed instruction refuses BEFORE the server starts', () {
    test('invalid JSON is a configuration error naming the variable', () {
      expect(
        () => resolveDurableWorkspaceProvisionInstruction({
          _envName: '{not json',
        }),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains(_envName), contains('CONFIG_ERROR')),
          ),
        ),
      );
    });

    test('a JSON array is refused — it must be an OBJECT', () {
      expect(
        () => resolveDurableWorkspaceProvisionInstruction({_envName: '[]'}),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('must be a JSON OBJECT'),
          ),
        ),
      );
    });

    test('a missing key is refused by name', () {
      expect(
        () => resolveDurableWorkspaceProvisionInstruction({
          _envName: '{"productId": "p", "repositoryId": "r"}',
        }),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('startingRevision'),
          ),
        ),
      );
    });

    test('an empty value is refused, not treated as unset', () {
      expect(
        () => resolveDurableWorkspaceProvisionInstruction({
          _envName:
              '{"productId": "p", "repositoryId": "r", "startingRevision": "  "}',
        }),
        throwsA(isA<StateError>()),
        reason:
            'an empty startingRevision is a typo, not an absence. Reading it as '
            'unset would start the server and provision nothing while looking '
            'like a successful no-op',
      );
    });

    test(
      'an UNKNOWN key is refused rather than ignored — this is the typo that '
      'would otherwise be invisible',
      () {
        expect(
          () => resolveDurableWorkspaceProvisionInstruction({
            _envName:
                '{"productId": "p", "repository": "r", "startingRevision": "$_revision"}',
          }),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(contains('repository'), contains('unknown key')),
            ),
          ),
          reason:
              '`repository` instead of `repositoryId` is a plausible mistake '
              'that, ignored, provisions nothing and reports nothing. Refusing '
              'is the only outcome an operator can act on',
        );
      },
    );
  });

  group('a well-formed instruction parses', () {
    test('all three fields are trimmed and carried', () {
      final instruction = resolveDurableWorkspaceProvisionInstruction({
        _envName:
            '{"productId": " p-1 ", "repositoryId": " repo-1 ", '
            '"startingRevision": " $_revision "}',
      });

      expect(instruction, isNotNull);
      expect(instruction!.productId, 'p-1');
      expect(instruction.repositoryId, 'repo-1');
      expect(instruction.startingRevision, _revision);
    });

    test('the parser does NOT decide what a pin may be', () {
      // Deliberate separation. The parser's job is "is this an instruction?" and
      // the trigger's is "is this a commit?". A parser that also validated the
      // SHA would be a second definition of a pin, and the column's own
      // `gitRevisionPattern` is that definition — one place, not two.
      final instruction = resolveDurableWorkspaceProvisionInstruction({
        _envName:
            '{"productId": "p", "repositoryId": "r", "startingRevision": "main"}',
      });
      expect(instruction!.startingRevision, 'main');
    });
  });

  group('the failure posture of the one production caller', () {
    test('a refusal is RETURNED as a named code, not swallowed', () async {
      // The runtime does not exist in this deployment: no root was resolved.
      // The instruction must come back as `provisioned: false` with a reason,
      // because `run()` decides whether to keep serving from exactly that.
      //
      // The PRODUCT is fully gated, so what is being refused is the runtime and
      // nothing else — a refusal at the first read would prove nothing about
      // the runtime branch.
      final armed = await _armedRuntime();
      final outcome = await runOperatorDurableWorkspaceProvision(
        DurableWorkspaceProvisionInstruction(
          productId: _productId,
          repositoryId: _repositoryId,
          startingRevision: _revision,
        ),
        store: armed.store,
        engine: armed.engine,
        runtime: armed.unavailableRuntime,
        log: _discard,
      );

      expect(outcome['requested'], isTrue);
      expect(outcome['provisioned'], isFalse);
      expect(outcome['code'], 'DURABLE_RUNTIME_UNAVAILABLE');
      expect(
        outcome['reason'],
        contains('root'),
        reason: 'the RUNTIME\'s own reason, not this layer\'s paraphrase',
      );
    });

    test('a refused instruction logs an ABORT, naming the code', () async {
      final events = <String, Map<String, dynamic>>{};
      final armed = await _armedRuntime();

      await runOperatorDurableWorkspaceProvision(
        DurableWorkspaceProvisionInstruction(
          productId: _productId,
          repositoryId: _repositoryId,
          startingRevision: _revision,
        ),
        store: armed.store,
        engine: armed.engine,
        runtime: armed.unavailableRuntime,
        log: (event, data) => events[event] = data,
      );

      expect(events, contains('durable_workspace.provision.requested'));
      final aborted = events['durable_workspace.provision.aborted'];
      expect(aborted, isNotNull);
      expect(aborted!['code'], 'DURABLE_RUNTIME_UNAVAILABLE');
      expect(
        aborted['action'],
        contains('will NOT continue serving'),
        reason:
            'the operator asked for a durable clone and did not get one. The '
            'only honest outcome is a boot that fails loudly, not a server '
            'that looks healthy in the state the instruction was meant to '
            'leave',
      );
    });

    test('a SUCCESSFUL instruction reports the clone it made', () async {
      final events = <String, Map<String, dynamic>>{};
      final runtime = await _armedRuntime();

      final outcome = await runOperatorDurableWorkspaceProvision(
        DurableWorkspaceProvisionInstruction(
          productId: _productId,
          repositoryId: _repositoryId,
          startingRevision: _revision,
        ),
        store: runtime.store,
        engine: runtime.engine,
        runtime: runtime.runtime,
        log: (event, data) => events[event] = data,
      );

      expect(outcome['requested'], isTrue);
      expect(outcome['provisioned'], isTrue);
      expect(outcome['pinnedRevision'], _revision);
      expect(outcome['completedBaselineId'], 'bl-1');
      expect(
        outcome['triggeredBy'],
        contains(_envName),
        reason:
            'the banner says WHO asked. A clone that appeared with no recorded '
            'initiator is the artefact a reviewer has to take on trust',
      );
      expect(events['durable_workspace.provision.aborted'], isNull);
      expect(
        events['durable_workspace.provision.triggered'],
        isNotNull,
        reason: 'and the trigger itself logs what it wrote',
      );
    });

    test(
      'an unresolvable ref is refused through this path too, by the same code',
      () async {
        final runtime = await _armedRuntime();
        final outcome = await runOperatorDurableWorkspaceProvision(
          DurableWorkspaceProvisionInstruction(
            productId: _productId,
            repositoryId: _repositoryId,
            startingRevision: 'main',
          ),
          store: runtime.store,
          engine: runtime.engine,
          runtime: runtime.runtime,
          log: _discard,
        );

        expect(outcome['provisioned'], isFalse);
        expect(outcome['code'], 'REVISION_NOT_A_COMMIT_SHA');
        expect(runtime.materializer.materializations, 0);
        expect(
          await runtime.store.readOnboardingForProduct(_productId),
          isNull,
          reason: 'nothing cloned, nothing recorded',
        );
      },
    );
  });
}

void _discard(String event, Map<String, dynamic> data) {}

/// A fully-gated product plus TWO runtimes over it: the one that would really
/// clone, and one that does not exist in this deployment.
///
/// Two rather than one because the refusal being tested is the runtime's, and
/// it can only be reached once the product and repository checks have passed —
/// a fixture that refused at the first read would prove nothing about the
/// branch under test.
Future<_Armed> _armedRuntime() async {
  final registry = RegistryFixture();
  await registry.registerProduct(
    productId: _productId,
    repositoryId: _repositoryId,
  );
  await seedCredential(
    registry.engine,
    productId: _productId,
    repositoryId: _repositoryId,
  );
  await registry.store.saveBaseline(
    const ProductBaseline(
      baselineId: 'bl-1',
      productId: _productId,
      revision: 1,
      status: ProductBaselineStatus.accepted,
      facts: [],
      contentHash: 'sha256:fixture',
      acceptedBy: 'operator@example.test',
    ),
  );
  final materializer = _StubMaterializer();
  return _Armed(
    store: registry.store,
    engine: registry.engine,
    materializer: materializer,
    runtime: DurableWorkspaceRuntime.resolve(
      engine: registry.engine,
      durableWorkspaceRoot: '/tmp/durable-workspace-instruction-test-root',
      log: _discard,
      custodyProvider: RecordingSecretProvider(),
      accessVerifier: ScriptedAccessVerifier(committedRevision: _revision),
      materializer: materializer,
    ),
    // No root was resolved, so `resolve` refuses and names why. Built with
    // custody supplied so the refusal is unambiguously the ROOT's, which is
    // the refusal `_durableWorkspaceRoot()` returns `''` for.
    unavailableRuntime: DurableWorkspaceRuntime.resolve(
      engine: registry.engine,
      durableWorkspaceRoot: '',
      log: _discard,
      custodyProvider: RecordingSecretProvider(),
      accessVerifier: ScriptedAccessVerifier(),
      materializer: materializer,
    ),
  );
}

class _Armed {
  _Armed({
    required this.store,
    required this.engine,
    required this.runtime,
    required this.unavailableRuntime,
    required this.materializer,
  });

  final InMemoryProductRegistryStore store;
  final ProductRegistryEngine engine;
  final DurableWorkspaceRuntime runtime;

  /// The same composition with no workspace root: `isAvailable` is false and
  /// `availableReason` names it.
  final DurableWorkspaceRuntime unavailableRuntime;

  final _StubMaterializer materializer;
}

class _StubMaterializer implements DurableWorkspaceMaterializer {
  int materializations = 0;

  @override
  Future<DurableWorkspaceClone> materialize({
    required String productId,
    required String repositoryId,
    required SshRemote remote,
    required SecretBytes privateKeyPem,
    required String confirmedHostKeyFingerprint,
    required String pinnedRevision,
    required String productRoot,
  }) async {
    materializations++;
    return DurableWorkspaceClone(
      productId: productId,
      repositoryId: repositoryId,
      repositoryPath: '$productRoot/checkout',
      revision: pinnedRevision,
      sourceRef: remote.toSshUrl(),
      materializedAt: DateTime.utc(2026, 1, 3),
    );
  }
}
