import 'dart:io';
import 'dart:isolate';

import 'package:control_plane_server/src/implementation/implementation_readiness_probe.dart';
import 'package:platform_contracts/platform_contracts.dart'
    show ProductState, WorkItem, WorkItemCategory, WorkItemState;
// `test` is a dev_dependency of `control_plane_server`; it is unresolved as a
// `lib/` import, which is a known cost of co-locating tests here — the same
// trade `src/baseline/product_agnosticism_test.dart` makes.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

/// A2's sources must be product-agnostic, and this is the gate that says so.
///
/// ## Why this file exists at all
///
/// `src/baseline/product_agnosticism_test.dart` enforces exactly this rule over
/// the baseline lane's files — no product name, no host, no absolute-path
/// default — and it does so mechanically, by grepping every non-test `.dart`
/// file in its directory and cross-checking that list against the directory so a
/// new lane file cannot slip past it.
///
/// **The implementation resolver is deliberately OUTSIDE that gate.** It has to
/// be: it lives in `src/implementation/**` rather than `src/baseline/**` precisely
/// because that directory's gate file belongs to another lane and editing it
/// would have created an ownership conflict. The cost of that decision is stated
/// in the design brief's review matrix (row R-8): *inheriting the
/// product-agnosticism discipline without the mechanical enforcement*.
///
/// This file is the enforcement. It applies the same three rules over the same
/// two sources, and it fails if either source file moves or disappears — so the
/// gate cannot quietly stop covering anything, which is the failure mode a
/// hand-maintained file list always has.
///
/// ## Why the rule matters here at all
///
/// The resolver names a product's durable clone, and the whole reason it can is
/// that it does not know WHICH product until it is handed one. A product name, a
/// host, or a hardcoded default path baked into this file would make the second
/// product inherit the first one's configuration — which is exactly the shape of
/// the defect the baseline gate was written to catch, reproduced in a directory
/// the gate does not watch.
void main() {
  /// Substrings a lane source must never contain.
  ///
  /// Spelled out rather than lower-cased and compared once, so a reader can see
  /// that the environment variables the composition root owns
  /// (`SHIPIT_DURABLE_WORKSPACE_ROOT`, `SHIPIT_TRIAGE_REPOSITORY_PATH`) are
  /// excluded by NAME and not by luck: neither may appear here, which is why the
  /// read of the first one lives in `server.dart`.
  const List<String> kForbidden = ['shipit', 'SHIPIT', 'ShipIt', 'airlock'];

  /// Absolute paths, as a literal-prefix match. A default location is one
  /// machine's idea of where things go, and that is the whole hazard.
  final RegExp kAbsolutePathDefault = RegExp(
    '''["']/(usr|home|repo|srv|var|opt|private)/''',
  );

  /// Every A2-owned source the gate covers, as workspace-relative paths.
  ///
  /// Written out rather than globbed, for the reason `product_agnosticism_test`
  /// writes its list out: a glob over a directory would not cover
  /// `packages/scheduler/**`, and a hand list has to be cross-checked — which is
  /// what the "every file exists" test below does.
  const List<({String label, String path})> kGatedSources = [
    (
      label: 'the implementation readiness probe',
      path:
          'apps/server/lib/src/implementation/implementation_readiness_probe.dart',
    ),
    (
      label: 'the implementation job definition',
      path: 'packages/scheduler/lib/src/implement_feature.dart',
    ),
    // Registered on repair: both landed in the directory after this gate was
    // written and were silently uncovered — which is precisely the failure the
    // "names every non-test file" check exists to catch. Both were verified
    // clean against the rule set below before being listed.
    (
      label: 'the dispatch-time path-ownership grant',
      path:
          'apps/server/lib/src/implementation/implementation_path_ownership.dart',
    ),
    (
      label: 'the design-scope grant',
      path: 'apps/server/lib/src/implementation/design_scope_grant.dart',
    ),
  ];

  /// True for the WORKSPACE root, not the server package root.
  ///
  /// `pubspec.yaml` is not enough: the server package has one too, and a gate
  /// that resolved the wrong root would build every path in its own list from
  /// the wrong place and report nothing. Both halves of the split are therefore
  /// required — the scheduler package this gate also covers lives outside
  /// `apps/server` entirely.
  bool isWorkspaceRoot(String path) =>
      File('$path/pubspec.yaml').existsSync() &&
      Directory('$path/packages/scheduler').existsSync() &&
      Directory('$path/apps/server').existsSync();

  /// Walks up from [start] looking for the workspace root.
  ///
  /// Throws rather than returning a guess. `Platform.script` under `dart test`
  /// is the test kernel rather than this file, so it cannot be walked; package
  /// resolution can name this very library, and that is the start point.
  Directory walkUp(Directory start) {
    var directory = start.absolute;
    for (var hop = 0; hop < 12; hop++) {
      if (isWorkspaceRoot(directory.path)) return directory;
      final parent = directory.parent;
      if (parent.path == directory.path) break;
      directory = parent;
    }
    throw StateError(
      'could not locate the workspace root from ${start.path}. A gate that '
      'passes because it looked at the wrong directory covers nothing',
    );
  }

  Future<Directory> workspaceRoot() async {
    final resolved = await Isolate.resolvePackageUri(
      Uri.parse(
        'package:control_plane_server/src/implementation/'
        'implementation_product_agnosticism_test.dart',
      ),
    );
    if (resolved != null && resolved.scheme == 'file') {
      final file = File.fromUri(resolved);
      if (file.existsSync()) {
        return walkUp(file.parent);
      }
    }
    // Fallback for a host that cannot resolve package URIs: walk up from the
    // working directory, which `dart test` sets to somewhere inside the
    // workspace.
    return walkUp(Directory.current);
  }

  group('A2 sources are product-agnostic', () {
    test('every gated file exists where this test expects it', () async {
      // A silent no-op gate reads "green" while covering nothing. Coverage is
      // asserted BEFORE the rule, not after.
      final root = await workspaceRoot();
      for (final source in kGatedSources) {
        expect(
          File('${root.path}/${source.path}').existsSync(),
          isTrue,
          reason:
              '${source.path} is missing, so this gate would silently stop '
              'covering it. Either update kGatedSources or restore the file',
        );
      }
    });

    test('no gated source names a product or a host', () async {
      final root = await workspaceRoot();
      final offenders = <String>[];
      for (final source in kGatedSources) {
        final file = File('${root.path}/${source.path}');
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          for (final needle in kForbidden) {
            if (lines[i].contains(needle)) {
              offenders.add('${source.path}:${i + 1}');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'these sources must be product-agnostic. A named product or host is '
            'a defect, not a convenience: it is how the second hypothetical '
            'product would inherit the first one\'s configuration. The '
            'environment-variable read that WOULD name a product belongs in '
            'the composition root, which is outside this gate',
      );
    });

    test('no gated source hardcodes an absolute filesystem path', () async {
      final root = await workspaceRoot();
      final offenders = <String>[];
      for (final source in kGatedSources) {
        final file = File('${root.path}/${source.path}');
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (kAbsolutePathDefault.hasMatch(lines[i])) {
            offenders.add('${source.path}:${i + 1}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'a default path is a default location, and a default location is '
            'one machine. The durable clone path comes from the product\'s own '
            'onboarding record and nothing else',
      );
    });

    test(
      'the gate names every non-test file in the implementation directory',
      () async {
        // The other direction, and the one a glob would have given for free: a
        // file that lands in the directory without being listed would ship in the
        // package and be able to name a product while the gate reads green.
        final root = await workspaceRoot();
        final covered = kGatedSources.map((s) => s.path).toSet();
        final onDisk =
            Directory('${root.path}/apps/server/lib/src/implementation')
                .listSync()
                .whereType<File>()
                .where((f) => f.path.endsWith('.dart'))
                .where((f) => !f.path.endsWith('_test.dart'))
                .map(
                  (f) => f.path
                      .substring(root.path.length + 1)
                      .replaceAll('\\', '/'),
                )
                .toSet();

        expect(
          onDisk,
          isNotEmpty,
          reason: 'the implementation directory scan found nothing at all',
        );
        expect(
          covered,
          containsAll(onDisk),
          reason:
              'these files sit in the implementation directory, ship in the '
              'package, and are not covered by the gate: '
              '${onDisk.difference(covered).toList()}',
        );
      },
    );
  });

  group(
    'the probe takes its repository from the record, never from a constant',
    () {
      test('a governed product with no durable clone defers', () async {
        // The positive proof that the grep gate above is covering real behaviour
        // rather than an unused file: the probe really does decide, and "no
        // record" really does produce a deferral rather than a repository.
        final probe = ImplementationReadinessProbe(
          readProductState: (productId) async => ProductState.governed,
          readOnboarding: (productId) async => null,
          runtimeTypeId: 'probe-runtime',
          timeoutSeconds: 1800,
        );

        final readiness = await probe.probe(_fixtureItem());
        expect(
          readiness,
          isA<ImplementationWorkspaceDeferred>(),
          reason:
              'no onboarding record means no durable workspace. The probe must '
              'defer rather than resolve against any repository at all',
        );
      });

      test(
        'an ungoverned product defers before its record is even read',
        () async {
          var onboardingRead = false;
          final probe = ImplementationReadinessProbe(
            readProductState: (productId) async => ProductState.baselinePending,
            readOnboarding: (productId) async {
              onboardingRead = true;
              return null;
            },
            runtimeTypeId: 'probe-runtime',
            timeoutSeconds: 1800,
          );

          final readiness = await probe.probe(_fixtureItem());
          expect(readiness, isA<ImplementationWorkspaceDeferred>());
          expect(
            onboardingRead,
            isFalse,
            reason:
                'gate order is a real property, not a style choice: a product with '
                'no accepted baseline cannot be dispatched for at all, so its '
                'workspace question is not yet worth asking',
          );
        },
      );
    },
  );
}

WorkItem _fixtureItem() {
  final now = DateTime.utc(2026);
  return WorkItem(
    workItemId: 'wi-agnosticism',
    productId: 'product-a',
    category: WorkItemCategory.feature,
    title: 'A fixture item used only to ask the probe about a product',
    description: 'The probe reads the product and its onboarding record.',
    state: WorkItemState.implementationReady,
    // A contract, so the behaviour tests above reach the gate they name: the
    // contract check sits between the product gates and the record gate, and
    // without this both tests would defer early at `qa_contract_missing` while
    // claiming to prove "no record defers" and "ungoverned defers first".
    qaContractId: 'qa-contract-wi-agnosticism',
    createdAt: now,
    updatedAt: now,
  );
}
