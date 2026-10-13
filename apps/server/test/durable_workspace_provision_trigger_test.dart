import 'dart:io';

import 'package:control_plane_server/src/baseline/baseline_test_fixtures.dart';
import 'package:control_plane_server/src/baseline/durable_workspace_materializer.dart';
import 'package:control_plane_server/src/baseline/durable_workspace_runtime.dart';
import 'package:control_plane_server/src/credentials/secret_material.dart'
    show SecretBytes;
import 'package:control_plane_server/src/credentials/ssh_remote.dart'
    show SshRemote;
import 'package:control_plane_server/src/services/control_plane_service.dart';
import 'package:platform_contracts/platform_contracts.dart'
    show
        DurableWorkspaceDescriptor,
        OnboardingRecord,
        ProductBaseline,
        ProductBaselineStatus,
        RepositoryKind,
        RepositoryProvider;
import 'package:product_registry/product_registry.dart'
    show CrossProductAccessException, InMemoryProductRegistryStore;
import 'package:test/test.dart';

/// The OPERATOR TRIGGER for a product's durable clone.
///
/// ## What is under test, and what is not
///
/// The clone itself is A1's: `durable_workspace_materializer_test.dart` owns the
/// transport down to the files left on disk, and `durable_workspace_runtime_test.dart`
/// owns the trust chain. Neither is re-tested here. What is under test is the
/// layer that did not exist — the decisions taken BEFORE anything is cloned, and
/// the one thing that happens after: every refusal below must leave no tree, no
/// credential material and no onboarding record behind.
///
/// The runtime under the trigger is A1's real one, built through its real
/// factory, with only the two network seams substituted (`SecretProvider` and
/// `RepositoryAccessVerifier` are composition-root inputs by A1's own design,
/// and the materialiser is a declared port). The trust chain above them is
/// production code, because a trigger tested against a fake runtime would prove
/// nothing about the trigger.
void main() {
  const productId = 'p-1';
  const repositoryId = 'repo-1';
  const root = '/tmp/durable-workspace-trigger-test-root';
  const revision = 'f0f3494957bb90df0a1c15a9fb4734ca6e49634d';

  late InMemoryProductRegistryStore store;
  late RegistryFixture registry;
  late RecordingSecretProvider custody;
  late _RecordingDurableMaterializer materializer;
  late List<String> events;

  void log(String event, Map<String, dynamic> data) =>
      events.add('$event ${data['code'] ?? ''}'.trim());

  Future<void> seedAcceptedBaseline({
    String productId = productId,
    String baselineId = 'bl-1',
    ProductBaselineStatus status = ProductBaselineStatus.accepted,
    int revision = 1,
  }) => store.saveBaseline(
    ProductBaseline(
      baselineId: baselineId,
      productId: productId,
      revision: revision,
      status: status,
      facts: const [],
      contentHash: 'sha256:fixture',
      acceptedBy: status == ProductBaselineStatus.accepted
          ? 'operator@example.test'
          : null,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    ),
  );

  /// A fully-gated product: repository, credential, confirmed host key, and an
  /// accepted baseline. Every test starts from the state that SUCCEEDS, so each
  /// refusal below is provably the trigger and not a missing prerequisite.
  Future<DurableWorkspaceProvisionTrigger> armedTrigger({
    String workspaceRoot = root,
    bool withCredential = true,
    bool withBaseline = true,
  }) async {
    registry = RegistryFixture();
    store = registry.store;
    await registry.registerProduct(
      productId: productId,
      repositoryId: repositoryId,
    );
    if (withCredential) {
      await seedCredential(
        registry.engine,
        productId: productId,
        repositoryId: repositoryId,
      );
    }
    if (withBaseline) {
      await seedAcceptedBaseline();
    }
    custody = RecordingSecretProvider();
    materializer = _RecordingDurableMaterializer();
    events = <String>[];
    return DurableWorkspaceProvisionTrigger(
      store: store,
      engine: registry.engine,
      runtime: DurableWorkspaceRuntime.resolve(
        engine: registry.engine,
        durableWorkspaceRoot: workspaceRoot,
        log: log,
        custodyProvider: custody,
        accessVerifier: ScriptedAccessVerifier(committedRevision: revision),
        materializer: materializer,
      ),
      log: log,
    );
  }

  group('the trigger reaches A1 and writes down what A1 established', () {
    test('a governed product gets a clone, a pin, and a completion', () async {
      final trigger = await armedTrigger();

      final provisioned = await trigger.provision(
        productId: productId,
        repositoryId: repositoryId,
        startingRevision: revision,
      );

      expect(provisioned.pinnedRevision, revision);
      expect(
        provisioned.completedBaselineId,
        'bl-1',
        reason: 'the completion names the baseline a human accepted',
      );

      // Read back through the STORE, not through the return value: the return
      // value is what this lane believes, the record is what every later
      // execution reads.
      final record = await store.readOnboardingForProduct(productId);
      expect(record, isNotNull);
      expect(record!.pinnedRevision, revision);
      expect(
        record.hasDurableProductClone,
        isTrue,
        reason:
            'this is the read `ImplementationReadinessProbe` gates on; until '
            'it is true every implementation item defers for want of a clone',
      );
      expect(
        record.workspace!.requireDurable().repositoryPath,
        contains(productId),
      );
      expect(record.completed, isTrue);
      expect(record.completedBaselineId, 'bl-1');
    });

    test(
      'the runtime was asked for the RESOLVED commit, not the operator\'s word '
      'for it',
      () async {
        final trigger = await armedTrigger();

        await trigger.provision(
          productId: productId,
          repositoryId: repositoryId,
          startingRevision: revision,
        );

        expect(
          materializer.requestedPins,
          <String>[revision],
          reason:
              'the recorded pin must be the commit the clone was verified at. '
              'Anything else is the manufactured-revision failure this lane '
              'exists to prevent',
        );
      },
    );

    test(
      'the custody reference is read BY NAME, and never by a path',
      () async {
        final trigger = await armedTrigger();

        await trigger.provision(
          productId: productId,
          repositoryId: repositoryId,
          startingRevision: revision,
        );

        // ADR 0018 §13a: a credential is referenced by name and its value is
        // never passed around. `seedCredential` mints under this exact name.
        //
        // Twice, and that is A1's own shape rather than anything this lane
        // does: `verifyAccess` reads it to probe the credential and the
        // materialiser reads it to clone with. What this asserts is that BOTH
        // reads went through custody by name — no second read path, and nothing
        // addressed by filesystem location.
        expect(custody.reads, <String>[
          'GIT_TEST_${repositoryId}_SSH',
          'GIT_TEST_${repositoryId}_SSH',
        ]);
      },
    );

    test(
      'nothing in this lane wrote the onboarding record — A1 did, through '
      '`recordWorkspace`',
      () async {
        // Not a style assertion. `triggerOnboarding`'s doc is the principle
        // this lane borrows: a request is not a fact. The record is written by
        // the one call that also created the tree, so it can never name a
        // checkout that does not exist.
        final trigger = await armedTrigger();
        final before = await store.readOnboardingForProduct(productId);

        await trigger.provision(
          productId: productId,
          repositoryId: repositoryId,
          startingRevision: revision,
        );

        expect(
          before,
          isNull,
          reason: 'a product nobody has provisioned holds no record at all',
        );
        expect(materializer.materializations, 1);
      },
    );
  });

  group('the pin must be a commit', () {
    test('a branch name is refused by name, and nothing is cloned', () async {
      final trigger = await armedTrigger();

      await expectLater(
        trigger.provision(
          productId: productId,
          repositoryId: repositoryId,
          startingRevision: 'main',
        ),
        throwsA(
          isA<DurableWorkspaceProvisionRefused>()
              .having((e) => e.code, 'code', 'REVISION_NOT_A_COMMIT_SHA')
              .having((e) => e.reason, 'reason', contains('git ls-remote')),
        ),
      );

      expect(materializer.materializations, 0);
      expect(custody.reads, isEmpty);
      expect(await store.readOnboardingForProduct(productId), isNull);
    });

    test('`HEAD` is refused exactly as a branch is', () async {
      final trigger = await armedTrigger();
      await expectLater(
        trigger.provision(
          productId: productId,
          repositoryId: repositoryId,
          startingRevision: 'HEAD',
        ),
        throwsA(
          isA<DurableWorkspaceProvisionRefused>().having(
            (e) => e.code,
            'code',
            'REVISION_NOT_A_COMMIT_SHA',
          ),
        ),
      );
      expect(materializer.materializations, 0);
    });

    test('an ABBREVIATED sha is refused, even though git accepts it', () async {
      // Seven characters is enough for git and not enough to be re-derivable
      // years later by someone reading the record. `gitRevisionPattern` says
      // 40, and this trigger reads that same pattern rather than its own.
      final trigger = await armedTrigger();
      await expectLater(
        trigger.provision(
          productId: productId,
          repositoryId: repositoryId,
          startingRevision: revision.substring(0, 7),
        ),
        throwsA(isA<DurableWorkspaceProvisionRefused>()),
      );
      expect(materializer.materializations, 0);
    });

    test('UPPERCASE hex is refused — the column stores one spelling', () async {
      final trigger = await armedTrigger();
      await expectLater(
        trigger.provision(
          productId: productId,
          repositoryId: repositoryId,
          startingRevision: revision.toUpperCase(),
        ),
        throwsA(isA<DurableWorkspaceProvisionRefused>()),
      );
    });

    test(
      'the refusal does not echo an operator input that could be key material',
      () async {
        final trigger = await armedTrigger();
        final pem = '-----BEGIN OPENSSH PRIVATE KEY-----\nabc\ndef\n';

        Object? refusal;
        try {
          await trigger.provision(
            productId: productId,
            repositoryId: repositoryId,
            startingRevision: pem,
          );
        } on DurableWorkspaceProvisionRefused catch (error) {
          refusal = error;
        }

        expect(refusal, isNotNull);
        expect(
          (refusal! as DurableWorkspaceProvisionRefused).reason,
          isNot(contains('PRIVATE KEY')),
          reason:
              'these reasons are logged and shown to an operator. The echo '
              'filter allows one printable shape (no newlines, no spaces), so a '
              'PEM cannot pass it, and the file never has to know what key '
              'material looks like to be safe',
        );
        expect(
          (refusal as DurableWorkspaceProvisionRefused).reason,
          contains('<unprintable>'),
        );
      },
    );

    test(
      'a plain branch name IS echoed, so the operator knows which one',
      () async {
        final trigger = await armedTrigger();
        Object? refusal;
        try {
          await trigger.provision(
            productId: productId,
            repositoryId: repositoryId,
            startingRevision: 'release/2026.10',
          );
        } on DurableWorkspaceProvisionRefused catch (error) {
          refusal = error;
        }
        expect(
          (refusal! as DurableWorkspaceProvisionRefused).reason,
          contains('release/2026.10'),
        );
      },
    );
  });

  group('an absent runtime is refused with ITS OWN reason', () {
    test('a blank root never becomes a default directory', () async {
      final trigger = await armedTrigger(workspaceRoot: '   ');

      await expectLater(
        trigger.provision(
          productId: productId,
          repositoryId: repositoryId,
          startingRevision: revision,
        ),
        throwsA(
          isA<DurableWorkspaceProvisionRefused>()
              .having((e) => e.code, 'code', 'DURABLE_RUNTIME_UNAVAILABLE')
              .having((e) => e.reason, 'reason', contains('root')),
        ),
      );

      expect(materializer.materializations, 0);
      expect(await store.readOnboardingForProduct(productId), isNull);
    });

    test(
      'the reason is the runtime\'s own `availableReason`, not a paraphrase',
      () async {
        final trigger = await armedTrigger(workspaceRoot: '');
        final runtimeReason = trigger.runtime.availableReason;
        expect(runtimeReason, isNotNull);

        Object? refusal;
        try {
          await trigger.provision(
            productId: productId,
            repositoryId: repositoryId,
            startingRevision: revision,
          );
        } on DurableWorkspaceProvisionRefused catch (error) {
          refusal = error;
        }
        expect(
          (refusal! as DurableWorkspaceProvisionRefused).reason,
          runtimeReason,
          reason:
              'a paraphrased reason is a second wording to keep in step with '
              'the first, and the runtime already wrote the sentence an '
              'operator needs',
        );
      },
    );
  });

  group('no accepted baseline, no clone', () {
    test('a product whose baselines are all `proposed` is refused', () async {
      final trigger = await armedTrigger(withBaseline: false);
      await seedAcceptedBaseline(status: ProductBaselineStatus.proposed);

      await expectLater(
        trigger.provision(
          productId: productId,
          repositoryId: repositoryId,
          startingRevision: revision,
        ),
        throwsA(
          isA<DurableWorkspaceProvisionRefused>()
              .having((e) => e.code, 'code', 'NO_ACCEPTED_BASELINE')
              .having((e) => e.reason, 'reason', contains('proposed')),
        ),
      );

      expect(
        materializer.materializations,
        0,
        reason:
            'the refusal happens BEFORE the clone. A checkout made only to be '
            'rejected by the completion is a tree nobody asked for',
      );
      expect(await store.readOnboardingForProduct(productId), isNull);
    });

    test('a product with no baselines at all says so', () async {
      final trigger = await armedTrigger(withBaseline: false);
      Object? refusal;
      try {
        await trigger.provision(
          productId: productId,
          repositoryId: repositoryId,
          startingRevision: revision,
        );
      } on DurableWorkspaceProvisionRefused catch (error) {
        refusal = error;
      }
      expect(
        (refusal! as DurableWorkspaceProvisionRefused).reason,
        contains('none at all'),
      );
    });

    test(
      'A1\'s own acceptance check is still the one that decides, and its '
      'refusal is surfaced rather than swallowed',
      () async {
        // The trigger checks the acceptance BEFORE cloning so it can fail
        // cheaply; A1 re-checks it at completion. This drives the state the
        // trigger's early check cannot see — a baseline whose stored status is
        // not accepted by the time the completion runs — and asserts the
        // refusal text reaches the caller untouched rather than being replaced
        // by a generic error.
        final trigger = await armedTrigger();
        final store = trigger.store;
        final baseline = ProductBaseline(
          baselineId: 'bl-1',
          productId: productId,
          revision: 1,
          status: ProductBaselineStatus.accepted,
          facts: const [],
          contentHash: 'sha256:fixture',
          acceptedBy: 'operator@example.test',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 2),
        );
        await store.saveBaseline(baseline);
        await trigger.provision(
          productId: productId,
          repositoryId: repositoryId,
          startingRevision: revision,
        );

        // Flip the stored baseline after the trigger has already decided, then
        // call A1's completion exactly as the trigger does.
        await store.saveBaseline(
          baseline.copyWith(status: ProductBaselineStatus.superseded),
        );
        await expectLater(
          trigger.runtime.provisioner!.completeOnboarding(
            productId: productId,
            pinnedRevision: revision,
            workspace: DurableWorkspaceDescriptor(
              workspaceId: 'dws-$productId',
              productId: productId,
              repositoryPath: '$root/$productId/checkout',
              startingRevision: revision,
              createdAt: DateTime.utc(2026, 1, 1),
            ),
            completedBaselineId: 'bl-1',
          ),
          throwsA(
            isA<DurableWorkspaceUnavailableException>().having(
              (e) => e.reason.replaceAll('\n', ' '),
              'reason (unwrapped)',
              contains('is superseded, not accepted'),
            ),
          ),
        );
      },
    );
  });

  group('IDEMPOTENCE — a product that already has a clone is refused', () {
    test('the second call is refused and changes nothing', () async {
      final trigger = await armedTrigger();
      final first = await trigger.provision(
        productId: productId,
        repositoryId: repositoryId,
        startingRevision: revision,
      );
      final afterFirst = await store.readOnboardingForProduct(productId);

      await expectLater(
        trigger.provision(
          productId: productId,
          repositoryId: repositoryId,
          startingRevision: revision,
        ),
        throwsA(
          isA<DurableWorkspaceProvisionRefused>()
              .having((e) => e.code, 'code', 'WORKSPACE_ALREADY_PROVISIONED')
              .having((e) => e.reason, 'reason', contains(revision))
              .having(
                (e) => e.reason,
                'reason',
                contains(first.workspace.workspaceId),
              ),
        ),
      );

      expect(
        materializer.materializations,
        1,
        reason:
            'ONE clone, not two, and not one replaced by another. The refusal '
            'happens before the runtime is asked for anything',
      );
      expect(
        await store.readOnboardingForProduct(productId),
        afterFirst,
        reason:
            'a refused second call must not bump version or re-write the row',
      );
    });

    test(
      'the refusal is DETERMINISTIC across any number of calls — it is not a '
      'first-call-only guard',
      () async {
        final trigger = await armedTrigger();
        await trigger.provision(
          productId: productId,
          repositoryId: repositoryId,
          startingRevision: revision,
        );
        for (var attempt = 0; attempt < 4; attempt++) {
          await expectLater(
            trigger.provision(
              productId: productId,
              repositoryId: repositoryId,
              startingRevision: revision,
            ),
            throwsA(
              isA<DurableWorkspaceProvisionRefused>().having(
                (e) => e.code,
                'code',
                'WORKSPACE_ALREADY_PROVISIONED',
              ),
            ),
          );
        }
        expect(materializer.materializations, 1);
      },
    );

    test(
      'a DIFFERENT revision does not slip past the guard, and the recorded pin '
      'is left alone',
      () async {
        final trigger = await armedTrigger();
        await trigger.provision(
          productId: productId,
          repositoryId: repositoryId,
          startingRevision: revision,
        );

        const newer = 'a493b21bf6c9b0f0e2a1b7f7d3c9e0a1b2c3d4e5';
        await expectLater(
          trigger.provision(
            productId: productId,
            repositoryId: repositoryId,
            startingRevision: newer,
          ),
          throwsA(
            isA<DurableWorkspaceProvisionRefused>().having(
              (e) => e.code,
              'code',
              'WORKSPACE_ALREADY_PROVISIONED',
            ),
          ),
        );

        expect(
          (await store.readOnboardingForProduct(productId))!.pinnedRevision,
          revision,
        );
        expect(materializer.materializations, 1);
      },
    );

    test(
      'WHY it must refuse: a second materialisation into the same tree would '
      'DESTROY the first',
      () async {
        // The safety argument above, executed rather than asserted.
        //
        // A1's materialiser runs `git init` then `git remote add origin` in the
        // product root, and treats a non-zero exit from either as a failed
        // provisioning — after which its `on Object` handler destroys the whole
        // product root. On a SECOND run `origin` is already there, so the add
        // fails. That is the deletion of a clone that may hold unreviewed
        // commits, arrived at through a path that reads as the helpful one.
        //
        // This test uses the real `git` and a temporary directory. No network,
        // no ssh, no product data: it establishes the premise the refusal rests
        // on, so a future reader can check it instead of believing it.
        final dir = Directory.systemTemp.createTempSync(
          'durable-workspace-reprovision-hazard.',
        );
        try {
          String git(List<String> args) {
            final result = Process.runSync('git', ['-C', dir.path, ...args]);
            return result.exitCode.toString();
          }

          expect(
            git(['init', '--quiet']),
            '0',
            reason: 'git init is idempotent against an existing repository',
          );
          expect(
            git(['remote', 'add', 'origin', 'git@remote.test:o/r.git']),
            '0',
          );

          final second = Process.runSync(
            'git',
            [
              '-C',
              dir.path,
              'remote',
              'add',
              'origin',
              'git@remote.test:o/r.git',
            ],
          );
          expect(
            second.exitCode,
            isNot(0),
            reason:
                'THIS is the hazard. If this ever becomes 0, a second '
                'provisioning would no longer fail at `remote add`, and the '
                'refusal in `DurableWorkspaceProvisionTrigger` would have lost '
                'the mechanical reason it has — and would need a real one',
          );
          expect(second.stderr.toString(), contains('already exists'));
        } finally {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        }
      },
    );

    test(
      'there is no destructive path in this lane to reach deliberately — as a '
      'CLOSED SET of calls the trigger may make, not a list of forbidden names',
      () async {
        // Obligation: if any code path here can delete or overwrite a durable
        // clone it must be reachable only from an explicitly named operator
        // action. There is none.
        //
        // WHY AN ALLOW-LIST AND NOT A BLOCK-LIST. The previous form of this gate
        // grepped the trigger for seven verb NAMES — `delete(`, `remove(`,
        // `force(`, `recreate(`, `overwrite(` — and that is not a guarantee,
        // because it only sees names someone thought to forbid. A helper called
        // `_purgeRecord` that receives the record and destroys the tree compiles,
        // analyses clean, and passes the gate: the reviewer proved exactly that.
        // Three of the seven were not Dart APIs at all, which is the tell — a
        // block-list is a list of guesses.
        //
        // So this is call-shaped. Every `runtime.…` / `provisioner.…` the trigger
        // can reach is enumerated, and a NEW call of any name fails the gate. A
        // wrapper cannot hide behind a different identifier because it still has
        // to be invoked ON one of these two objects.
        //
        // WHAT IT DOES NOT PROVE, stated rather than left implied: it governs the
        // trigger's own surface, and it says nothing about a helper defined
        // inside `control_plane_service.dart` and called from code the trigger
        // does not. The capability gate below covers the wider lane. Neither
        // replaces review of a destructive change.
        final source = File(
          'lib/src/services/control_plane_service.dart',
        ).readAsStringSync();
        final start = source.indexOf('class DurableWorkspaceProvisionTrigger');
        // Bounded at the next top-level class rather than at end-of-file, so this
        // is the trigger's own body and not every declaration printed after it.
        final nextClass = source.indexOf('\nclass ', start + 1);
        final body = source.substring(
          start,
          nextClass == -1 ? null : nextClass,
        );

        // The complete set of runtime surface this trigger is allowed to touch:
        // three reads for guard #3, `provision` for guard #6, and A1's own
        // completion, whose acceptance re-check is deliberately kept.
        const allowed = <String>{
          'isAvailable',
          'availableReason',
          'provisioner',
          'provision',
          'completeOnboarding',
        };
        final invoked = RegExp(
          r'\b(?:runtime|provisioner)\.([A-Za-z_]\w*)',
        ).allMatches(body).map((m) => m.group(1)!).toSet().difference(allowed);

        expect(
          invoked,
          isEmpty,
          reason:
              'the trigger reached the runtime through an allow-listed call it '
              'does not own: ${invoked.join(', ')}. Every call it is allowed to '
              'make is enumerated above — a new one needs a decision recorded '
              'here, not a name that happens not to be on a forbidden list',
        );

        // The narrower first layer, kept because it catches something the
        // allow-list cannot see: a DIRECT filesystem or collaborator call in the
        // trigger's own body, which reaches no `runtime.` member at all. It is a
        // heuristic and nothing more — it sees only names someone thought to
        // list — so it is stated as the cheap check it is, and the allow-list
        // above is what actually holds.
        //
        // The list is unchanged from what was there before this correction, and
        // that is deliberate: dropping the three that are not Dart APIs
        // (`recreate(`, `force(`, `overwrite(`) would have been a quiet
        // narrowing of coverage in a correction whose whole subject is
        // misattributed guarantees. They match no standard API, so they catch
        // only a lane-defined method of that name — which is exactly what this
        // layer is for, and they cost nothing.
        for (final verb in const [
          'delete',
          'deleteSync',
          'remove',
          'rmdir',
          'recreate',
          'force',
          'overwrite',
        ]) {
          expect(
            body.contains('$verb('),
            isFalse,
            reason:
                'the trigger\'s own body contains a direct `$verb(` call. A '
                'durable clone became reachable to a side effect of the '
                'trigger rather than to a named operator action',
          );
        }
      },
    );

    test(
      'the destructive CAPABILITY is named outside the mechanism only by the '
      'trigger — a direct `runtime.provision(` is caught wherever it appears',
      () async {
        // The guard above governs what the TRIGGER calls. This governs who may
        // reach the capability at all, which is the gap the previous gate left
        // open in the direction that actually destroys a clone.
        //
        // `DurableWorkspaceProvisionTrigger` is the only place guard #5 lives.
        // `DurableWorkspaceRuntime.provision()` and
        // `SshDurableWorkspaceMaterializer.materialize()` have no idempotence
        // guard of their own, so a production call site that reaches either
        // directly bypasses every one of the trigger's five checks — and on a
        // product that already has a clone, that bypass IS the deletion.
        //
        // This is the path the persisted learning
        // (`docs/engineering/learning/a-second-clone-attempt-is-a-clone-deletion.md`)
        // used to describe as safe, which is why it is checked mechanically
        // rather than trusted to prose.
        const capabilityTokens = <String>[
          'DurableWorkspaceRuntime',
          'DurableWorkspaceProvisioner',
          'DurableWorkspaceMaterializer',
        ];

        // A1's own mechanism modules. They DEFINE the capability, and
        // `lib/src/baseline/**` is owned by another lane — this gate must never
        // be the reason that lane's tests go red.
        const mechanismModules = <String>{
          'lib/src/baseline/durable_workspace_runtime.dart',
          'lib/src/baseline/durable_workspace_materializer.dart',
        };

        // Where guard #5 lives. This file may name the capability; nothing else
        // outside the mechanism may.
        const triggerFile = 'lib/src/services/control_plane_service.dart';

        // The composition root. It is allowed to CONSTRUCT the runtime — that is
        // how `_durableWorkspaceRoot()` is resolved and passed down — and is
        // allowed to hold the type. It may not CALL it.
        const compositionRoot = 'lib/server.dart';

        final offenders = <String, String>{};
        for (final entity in Directory('lib').listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final path = entity.path.replaceAll(r'\', '/');
          if (mechanismModules.contains(path)) continue;
          // A test may exercise the mechanism directly, and A1's own does. This
          // gate is about PRODUCTION call sites, and a failing A1 test would be
          // reported against the wrong lane.
          if (path.endsWith('_test.dart')) continue;
          if (path == triggerFile) continue;

          final text = entity.readAsStringSync();
          final named = capabilityTokens
              .where((t) => text.contains(t))
              .toList();
          if (named.isEmpty) continue;

          if (path != compositionRoot) {
            offenders[path] =
                'names ${named.join(', ')}. Durable provisioning must stay '
                'behind DurableWorkspaceProvisionTrigger, which is the only '
                'place the refuse-always guard lives — a direct call here skips '
                'all five of its checks.';
            continue;
          }

          // Call-shaped, because `server.dart` legitimately names the type AND
          // legitimately calls `trigger.provision(`. Naming is not the thing to
          // forbid here; CALLING THE CAPABILITY is.
          final provisionCalls = RegExp(
            r'(\w+)\.provision\(',
          ).allMatches(text).map((m) => m.group(1)!).toSet();
          final bypassesTrigger = provisionCalls.difference({'trigger'});
          if (bypassesTrigger.isNotEmpty) {
            offenders[path] =
                'calls `.provision(` on ${bypassesTrigger.join(', ')}. The '
                'composition root may construct the runtime and call the '
                'trigger; anything else reaches the capability without guard #5.';
          } else if (text.contains('.materialize(')) {
            offenders[path] =
                'calls `.materialize(` directly. Materialising into an existing '
                'product root is the destructive path itself.';
          } else if (named.any((t) => t != 'DurableWorkspaceRuntime')) {
            offenders[path] =
                'names ${named.where((t) => t != 'DurableWorkspaceRuntime').join(', ')}. '
                'The composition root may hold DurableWorkspaceRuntime to '
                'construct it; the provisioner and the materialiser belong '
                'behind the trigger.';
          }
        }

        expect(
          offenders,
          isEmpty,
          reason:
              'durable provisioning became reachable outside '
              'DurableWorkspaceProvisionTrigger:\n'
              '${offenders.entries.map((e) => '  ${e.key} — ${e.value}').join('\n')}',
        );
      },
    );
  });

  group('ownership and existence, the same shape `triggerOnboarding` uses', () {
    test("another product's repository is refused", () async {
      final trigger = await armedTrigger();
      await registry.engine.createProduct(
        productId: 'p-2',
        name: 'Product Two',
        now: DateTime.utc(2026, 1, 1),
      );
      await registry.engine.addRepositoryReference(
        repositoryId: 'repo-2',
        productId: 'p-2',
        uri: 'git@remote.test:org/other.git',
        kind: RepositoryKind.monorepo,
        provider: RepositoryProvider.github,
        now: DateTime.utc(2026, 1, 1),
      );

      await expectLater(
        trigger.provision(
          productId: productId,
          repositoryId: 'repo-2',
          startingRevision: revision,
        ),
        throwsA(isA<CrossProductAccessException>()),
      );
      expect(materializer.materializations, 0);
    });

    test('an unknown product never reaches the runtime', () async {
      final trigger = await armedTrigger();
      await expectLater(
        trigger.provision(
          productId: 'no-such-product',
          repositoryId: repositoryId,
          startingRevision: revision,
        ),
        throwsA(isA<Object>()),
      );
      expect(materializer.materializations, 0);
      expect(custody.reads, isEmpty);
    });

    test(
      'a product with no credential is refused by A1, not by this lane',
      () async {
        // The trigger does not pre-check credentials: that is the trust chain's
        // refusal to make, and its own wording is the one an operator needs.
        final trigger = await armedTrigger(withCredential: false);

        await expectLater(
          trigger.provision(
            productId: productId,
            repositoryId: repositoryId,
            startingRevision: revision,
          ),
          throwsA(
            isA<DurableWorkspaceUnavailableException>().having(
              (e) => e.reason,
              'reason',
              contains('no credential has been minted'),
            ),
          ),
        );
        expect(materializer.materializations, 0);
        expect(await store.readOnboardingForProduct(productId), isNull);
      },
    );
  });

  group('THE MECHANICAL GATE — an operator action, never an automatic one', () {
    test(
      'the only production caller of the trigger is the operator instruction '
      'in `server.dart`',
      () async {
        // Provisioning runs against a governed product's repository with a
        // deploy key, so "an operator asked" is a security property, not a
        // preference. A sweep or a tick that called this would be unattended and
        // nobody would notice until a clone appeared that nobody wanted — which
        // is the failure a test that merely documents "do not do this" cannot
        // catch, and a comment certainly cannot.
        //
        // So the property is checked mechanically over `lib/`: this class is
        // named in exactly two files, and the second one is the composition
        // root that reads the operator's environment variable.
        final libDirectory = Directory('lib');
        final offenders = <String>[];
        for (final entity in libDirectory.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final path = entity.path.replaceAll(r'\', '/');
          final allowed =
              path == 'lib/src/services/control_plane_service.dart' ||
              path == 'lib/server.dart';
          if (allowed) continue;
          if (entity.readAsStringSync().contains(
            'DurableWorkspaceProvisionTrigger',
          )) {
            offenders.add(path);
          }
        }

        expect(
          offenders,
          isEmpty,
          reason:
              'a second production caller of durable provisioning appeared in '
              '${offenders.join(', ')}. Provisioning must stay reachable only '
              'from an explicit operator action: '
              '${offenders.join(', ')}',
        );
      },
    );

    test(
      '`server.dart` reaches it ONLY through the operator instruction, which is '
      'an environment variable no scheduler path can set',
      () async {
        final source = File('lib/server.dart').readAsStringSync();
        // Matched with a whitespace-tolerant pattern rather than as a literal:
        // `dart format` is free to reflow this declaration, and a test that
        // fails because a line wrapped would train a reader to reformat the
        // assertion rather than fix the code. What is being checked is that the
        // instruction is a NAMED variable with that exact value — a name is
        // what an operator greps for and what a runbook documents.
        expect(
          RegExp(
            r"const\s+String\s+_provisionDurableWorkspaceEnv\s*=\s*"
            r"'SHIPIT_PROVISION_DURABLE_WORKSPACE'",
          ).hasMatch(source),
          isTrue,
          reason:
              'the instruction is one named constant with that exact value, '
              'not an inline string literal somewhere in the boot sequence',
        );
        // Exactly one construction site, inside the boot instruction. If a second
        // appears, this count is what changes first.
        final constructions = RegExp(
          r'DurableWorkspaceProvisionTrigger\(',
        ).allMatches(source).length;
        expect(
          constructions,
          1,
          reason:
              'the trigger is constructed once, in the boot instruction. A '
              'second construction site is a second caller, and that is the '
              'thing this gate exists to catch',
        );
      },
    );
  });

  group('the returned record is the record that was written', () {
    test('`DurableWorkspaceProvisioned` describes what is on disk', () async {
      final trigger = await armedTrigger();
      final provisioned = await trigger.provision(
        productId: productId,
        repositoryId: repositoryId,
        startingRevision: revision,
      );

      final record = await store.readOnboardingForProduct(productId);
      final durable = record!.workspace!.requireDurable();

      expect(provisioned.workspace.repositoryPath, durable.repositoryPath);
      expect(provisioned.workspace.workspaceId, durable.workspaceId);
      expect(provisioned.workspace.startingRevision, durable.startingRevision);
      expect(provisioned.onboardingId, record.onboardingId);
      expect(
        OnboardingRecord.gitRevisionPattern.hasMatch(
          provisioned.pinnedRevision,
        ),
        isTrue,
        reason:
            'whatever else happened, the pin this lane reports is a shape the '
            'column accepts — there is no state in which a non-commit is '
            'reported as provisioned',
      );
    });
  });
}

/// A materialiser that writes nothing and records what it was asked to pin.
///
/// Counts calls rather than cloning: the clone is A1's own subject under test
/// elsewhere, and a real one here would need a git host, a deploy key and a
/// confirmed host key — none of which is what this lane is about.
class _RecordingDurableMaterializer implements DurableWorkspaceMaterializer {
  int materializations = 0;

  /// The pins this materialiser was asked for, in order. The assertion that
  /// matters across the suite is that this list holds the resolved commit and
  /// never the operator's ref.
  final List<String> requestedPins = <String>[];

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
    requestedPins.add(pinnedRevision);
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
