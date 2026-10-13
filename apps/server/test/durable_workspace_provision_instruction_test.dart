import 'package:control_plane_server/server.dart';
import 'package:control_plane_server/src/baseline/baseline_test_fixtures.dart';
import 'package:control_plane_server/src/baseline/durable_workspace_materializer.dart';
import 'package:control_plane_server/src/baseline/durable_workspace_runtime.dart';
import 'package:control_plane_server/src/credentials/secret_material.dart'
    show SecretBytes;
import 'package:control_plane_server/src/credentials/ssh_remote.dart'
    show SshRemote;
import 'package:platform_contracts/platform_contracts.dart'
    show
        OnboardingRecord,
        Product,
        ProductBaseline,
        ProductBaselineStatus,
        RepositoryReference;
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

  group('THE RESTART TRAP — the instruction re-presented after it succeeded', () {
    // The case no test covered, and the one that would have bitten immediately.
    //
    // Three facts interact. The variable is re-read on EVERY start
    // (`server.dart` resolves it from `Platform.environment` each boot);
    // `WORKSPACE_ALREADY_PROVISIONED` used to come back as `provisioned: false`;
    // and a failed instruction calls `exit(1)` in `_runDurableWorkspaceProvision`.
    //
    // So: provision once, restart for any routine reason with the variable still
    // exported, and the control plane does not start. An operator who set the
    // variable once was never told to unset it, and nothing in the failure names
    // it. "Honoured once, and never again by anything automatic" was implemented
    // as "honoured once, then failed forever".
    test(
      'the second presentation is a SATISFIED outcome, not a failure',
      () async {
        final events = <String, Map<String, dynamic>>{};
        final armed = await _armedRuntime();
        final instruction = DurableWorkspaceProvisionInstruction(
          productId: _productId,
          repositoryId: _repositoryId,
          startingRevision: _revision,
        );

        final first = await runOperatorDurableWorkspaceProvision(
          instruction,
          store: armed.store,
          engine: armed.engine,
          runtime: armed.runtime,
          log: (event, data) => events[event] = data,
        );
        expect(first['provisioned'], isTrue);
        expect(first.containsKey('alreadyProvisioned'), isFalse);

        // The restart: same environment, same instruction, new start.
        final second = await runOperatorDurableWorkspaceProvision(
          instruction,
          store: armed.store,
          engine: armed.engine,
          runtime: armed.runtime,
          log: (event, data) => events[event] = data,
        );

        expect(
          second['provisioned'],
          isTrue,
          reason:
              'the desired end state already holds — the instruction named a '
              'durable clone and the durable clone is there. Reporting this as '
              'a failure is what made the control plane refuse to START on any '
              'restart of an already-provisioned deployment',
        );
        expect(second['alreadyProvisioned'], isTrue);
        expect(
          second['code'],
          isNull,
          reason:
              'no refusal was raised, so there is no refusal code to report',
        );

        // And it kept serving: `_runDurableWorkspaceProvision` exits non-zero on
        // `requested == true && provisioned != true`, so this field is the whole
        // difference between a boot and a dead process.
        expect(
          second['requested'] == true && second['provisioned'] != true,
          isFalse,
          reason:
              'this predicate is the whole of the exit(1) condition in '
              '_runDurableWorkspaceProvision. It MUST be false here, or the '
              'control plane does not start',
        );
      },
    );

    test(
      'and it clones nothing, records nothing, and changes nothing',
      () async {
        final armed = await _armedRuntime();
        final instruction = DurableWorkspaceProvisionInstruction(
          productId: _productId,
          repositoryId: _repositoryId,
          startingRevision: _revision,
        );

        await runOperatorDurableWorkspaceProvision(
          instruction,
          store: armed.store,
          engine: armed.engine,
          runtime: armed.runtime,
          log: _discard,
        );
        final afterFirst = await armed.store.readOnboardingForProduct(
          _productId,
        );
        final secretReadsAfterFirst = armed.custody.reads.length;

        await runOperatorDurableWorkspaceProvision(
          instruction,
          store: armed.store,
          engine: armed.engine,
          runtime: armed.runtime,
          log: _discard,
        );

        expect(
          armed.materializer.materializations,
          1,
          reason:
              'one clone, ever. A second materialisation into the same product '
              'root is refused here before a credential is acquired — which is '
              'the point: the materialiser\'s own guard would catch it only '
              'afterwards, and only as a collision',
        );
        expect(armed.custody.reads.length, secretReadsAfterFirst);
        expect(
          await armed.store.readOnboardingForProduct(_productId),
          afterFirst,
          reason:
              'the record is byte-identical; a satisfied outcome writes nothing',
        );
      },
    );

    test(
      'the banner tells the operator the variable may be cleared',
      () async {
        final armed = await _armedRuntime();
        final instruction = DurableWorkspaceProvisionInstruction(
          productId: _productId,
          repositoryId: _repositoryId,
          startingRevision: _revision,
        );
        await runOperatorDurableWorkspaceProvision(
          instruction,
          store: armed.store,
          engine: armed.engine,
          runtime: armed.runtime,
          log: _discard,
        );

        final events = <String, Map<String, dynamic>>{};
        final outcome = await runOperatorDurableWorkspaceProvision(
          instruction,
          store: armed.store,
          engine: armed.engine,
          runtime: armed.runtime,
          log: (event, data) => events[event] = data,
        );

        expect(
          outcome['note'],
          allOf(contains(_envName), contains('cleared')),
          reason:
              'the operator is the one who exported this variable and nobody '
              'told them they could remove it. Leaving it set is SAFE, but it '
              'is state that outlives whoever set it, so the one line that '
              'reports the situation is where that has to be said',
        );
        expect(
          events['durable_workspace.provision.already_provisioned'],
          isNotNull,
          reason:
              'and it is a logged event, not a field the operator has to know '
              'to grep for. It must not be an ABORT — nothing failed',
        );
        expect(events['durable_workspace.provision.aborted'], isNull);
        expect(
          events['durable_workspace.provision.already_provisioned']!['action'] ??
              events['durable_workspace.provision.already_provisioned']!['note'],
          isNotNull,
        );
      },
    );

    test(
      'a guard that says "already provisioned" and a record that disagrees is '
      'NOT reported as satisfied — it fails loudly',
      () async {
        // The read-back is the whole reason this branch is more than an echo.
        // `provisioned: true` is the field a monitoring rule acts on, so it is
        // confirmed against the record rather than taken from the refusal that
        // produced it.
        final armed = await _armedRuntime();
        final events = <String, Map<String, dynamic>>{};

        final outcome = await runOperatorDurableWorkspaceProvision(
          DurableWorkspaceProvisionInstruction(
            productId: _productId,
            repositoryId: _repositoryId,
            startingRevision: _revision,
          ),
          store: armed.store,
          engine: armed.engine,
          runtime: armed.runtime,
          log: (event, data) => events[event] = data,
        );
        expect(outcome['provisioned'], isTrue);

        // The contradiction: the record that proves the clone exists disappears
        // between the trigger's guard and the read-back that confirms it.
        final vanishing = _VanishingOnboardingStore(armed.store);
        final contradicted = await runOperatorDurableWorkspaceProvision(
          DurableWorkspaceProvisionInstruction(
            productId: _productId,
            repositoryId: _repositoryId,
            startingRevision: _revision,
          ),
          store: vanishing,
          engine: armed.engine,
          runtime: armed.runtime,
          log: (event, data) => events[event] = data,
        );

        expect(
          contradicted['provisioned'],
          isFalse,
          reason:
              'a guard and a record that disagree are a contradiction, and the '
              'honest outcome for one is a failed boot — not a success nobody '
              'can find the evidence for',
        );
        expect(
          vanishing.confirmationReads,
          greaterThan(0),
          reason:
              'the branch is only reached because the satisfied-outcome path '
              'READ THE RECORD BACK rather than believing the refusal. Without '
              'this the test would pass for the wrong reason',
        );
        expect(
          events['durable_workspace.provision.already_provisioned'],
          isNull,
        );
        expect(
          events['durable_workspace.provision.already_provisioned.unconfirmed'],
          isNotNull,
          reason:
              'the unconfirmed read is its own event. Folding it into a generic '
              'abort would leave an operator with a code that does not name the '
              'thing that was actually odd',
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
  final custody = RecordingSecretProvider();
  return _Armed(
    store: registry.store,
    engine: registry.engine,
    materializer: materializer,
    custody: custody,
    runtime: DurableWorkspaceRuntime.resolve(
      engine: registry.engine,
      durableWorkspaceRoot: '/tmp/durable-workspace-instruction-test-root',
      log: _discard,
      custodyProvider: custody,
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
      custodyProvider: custody,
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
    required this.custody,
  });

  final InMemoryProductRegistryStore store;
  final ProductRegistryEngine engine;
  final DurableWorkspaceRuntime runtime;

  /// The secret substrate, held so a test can count how many times the private
  /// half was READ. A satisfied outcome must not re-acquire it: the credential
  /// is one read per provisioning, and a second one would mean the second start
  /// did work rather than reporting on work already done.
  final RecordingSecretProvider custody;

  /// The same composition with no workspace root: `isAvailable` is false and
  /// `availableReason` names it.
  final DurableWorkspaceRuntime unavailableRuntime;

  final _StubMaterializer materializer;
}

/// A store whose onboarding record VANISHES between the trigger's guard and the
/// read-back that confirms it.
///
/// The trigger reads the record to DECIDE (guard #5 — refuse, it is already
/// provisioned), and the satisfied-outcome branch reads it again to CONFIRM.
/// This answers the first read from the real store and null to the second, so
/// the disagreement those two can reach is exercised deterministically instead
/// of by racing a record that really does disappear between two reads.
///
/// The consequence of that disagreement is a FAILURE (refuse and do not serve),
/// not a deletion: guard #5 letting a second attempt through now ends in
/// `DurableWorkspaceRootCollisionException` with the tree intact, not in a
/// destroyed product root. What must not happen either way is a boot that
/// reports itself healthy while the record and the clone disagree.
///
/// Three methods are forwarded and nothing else, because those are the only
/// three the trigger asks a `ProductRegistryStore` for. Everything else in this
/// instruction's path goes through the engine, which is built over the real
/// inner store.
class _VanishingOnboardingStore extends InMemoryProductRegistryStore {
  _VanishingOnboardingStore(this._inner);

  final InMemoryProductRegistryStore _inner;

  /// How many reads reached the confirmation path specifically — that is, the
  /// reads after the trigger's guard had already decided.
  int confirmationReads = 0;

  @override
  Future<Product> readProduct(String productId) =>
      _inner.readProduct(productId);

  @override
  Future<RepositoryReference> readRepositoryReference(String repositoryId) =>
      _inner.readRepositoryReference(repositoryId);

  @override
  Future<OnboardingRecord?> readOnboardingForProduct(String productId) async {
    // Read #1 is guard #5's. Every read after it is a confirmation.
    if (confirmationReads > 0 || _decisionMade) {
      confirmationReads++;
      return null;
    }
    _decisionMade = true;
    return _inner.readOnboardingForProduct(productId);
  }

  bool _decisionMade = false;
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
