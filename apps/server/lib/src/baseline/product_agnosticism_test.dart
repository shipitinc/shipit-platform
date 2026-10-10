import 'dart:io';
import 'dart:isolate';

import 'package:control_plane_server/src/baseline/baseline_onboarding_sweep.dart';
import 'package:platform_contracts/platform_contracts.dart' show ProductState;
// `test` is a dev_dependency of `control_plane_server`; it is unresolved as a
// `lib/` import, which is a known cost of co-locating tests here.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

/// The second hypothetical product the design is argued against (§3.8): a
/// Dart/Flutter monorepo in its own repository, on a different host, with its
/// own deploy key and its own confirmed host key, registered after a first
/// product is already governed.
///
/// Named here so the claim "the lane is product-agnostic" has something
/// concrete to point at, and so adding a real product name to the lane would
/// have to displace one of these to get past the gate below.
const String kHypotheticalSecondProduct = 'product-b';
const String kHypotheticalSecondRepository = 'repo-b';
const String kHypotheticalSecondHost = 'git@another-remote.test:org/beta.git';

/// Substrings the lane must never contain.
///
/// [kForbidden] is the design's own grep gate, spelled three ways on purpose:
/// a case-insensitive search would be tidier, but spelling them out means a
/// reader can see that the environment variables the hand-run script defaulted
/// to — `SHIPIT_PRODUCT_ID`, `SHIPIT_REPOSITORY_PATH` — are excluded by name
/// and not by luck.
const List<String> kForbidden = ['shipit', 'SHIPIT', 'ShipIt', 'airlock'];

/// Absolute paths, resolved from this script rather than from the working
/// directory.
///
/// `dart test` can be invoked from anywhere in a workspace, and a gate that
/// passes because it looked at the wrong directory is worse than no gate — so
/// the root is derived from the test file's own location and each source file is
/// asserted to exist before it is read.
Future<Directory> _resolveServerRoot() async {
  // `Platform.script` under `dart test` is the test kernel, not this file, so
  // it cannot be walked. Package resolution can: asking for this very library
  // returns its real path, and the package root is three levels above it.
  final resolved = await Isolate.resolvePackageUri(
    Uri.parse(
      'package:control_plane_server/src/baseline/'
      'product_agnosticism_test.dart',
    ),
  );
  if (resolved != null) {
    final root = File.fromUri(resolved).parent.parent.parent;
    if (File('${root.path}/pubspec.yaml').existsSync()) return root;
  }

  // Fallback for a host that cannot resolve package URIs: walk up from the
  // working directory, which `dart test` sets to somewhere inside the
  // workspace. Refusing to guess is the whole requirement of this function.
  var directory = Directory.current.absolute;
  for (var hop = 0; hop < 12; hop++) {
    if (Directory('${directory.path}/lib/src/baseline').existsSync() &&
        File('${directory.path}/pubspec.yaml').existsSync()) {
      return directory;
    }
    final packages = Directory('${directory.path}/packages');
    final candidate = Directory('${packages.path}/scheduler');
    if (packages.existsSync() && candidate.existsSync()) {
      final server = Directory('${directory.path}/apps/server');
      if (server.existsSync()) return server;
    }
    directory = directory.parent;
  }
  throw StateError(
    'could not locate the control_plane_server package root (cwd '
    '${Directory.current.path}, resolved $resolved)',
  );
}

/// Files that make up the lane, plus the scheduler definition it depends on.
///
/// Written out rather than globbed so that adding a new lane file without
/// adding it here is visible in review. A gate that silently stops covering new
/// code is worse than no gate.
Future<List<File>> _laneSources() async {
  final root = await _resolveServerRoot();
  return [
    File('${root.path}/lib/src/baseline/baseline_derivation.dart'),
    File('${root.path}/lib/src/baseline/baseline_production_lane.dart'),
    File('${root.path}/lib/src/baseline/baseline_onboarding_sweep.dart'),
    File('${root.path}/lib/src/credentials/repository_snapshot_acquirer.dart'),
    File('${root.path}/lib/src/triage/lane_i_tick_hook.dart'),
    File(
      '${root.parent.parent.path}/packages/scheduler/lib/src/baseline_product.dart',
    ),
  ];
}

void main() {
  group('product agnosticism — the design\'s own grep gate, executed', () {
    test('every gate file exists where this test expects it', () async {
      // A silent no-op gate is worse than none: it would read "green" while
      // covering nothing. Assert coverage first.
      final sources = await _laneSources();
      expect(sources, hasLength(6));
      for (final file in sources) {
        expect(
          file.existsSync(),
          isTrue,
          reason:
              '${file.path} is missing, so this gate would silently stop '
              'covering it',
        );
      }
    });

    test(
      'no lane source names a product, a host, or an environment default',
      () async {
        final offenders = <String>[];
        for (final file in await _laneSources()) {
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            for (final needle in kForbidden) {
              if (lines[i].contains(needle)) {
                offenders.add('${file.uri.pathSegments.last}:${i + 1}');
              }
            }
          }
        }
        expect(
          offenders,
          isEmpty,
          reason:
              'the lane must be product-agnostic. A named product, host or '
              'environment default is a defect, not a convenience — it is how the '
              "hand-run script ended up looking tailored to one product, and how "
              'the second hypothetical product would inherit the first one\'s '
              'configuration',
        );
      },
    );

    test('no lane source hardcodes an absolute filesystem path', () async {
      // §3.8 names this alongside the substring rule: a default path is a
      // default location, and a default location is one product's machine.
      final offenders = <String>[];
      final pattern = RegExp('''["']/(usr|home|repo|srv|var|opt|private)/''');
      for (final file in await _laneSources()) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (pattern.hasMatch(lines[i])) {
            offenders.add('${file.uri.pathSegments.last}:${i + 1}');
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('the sweep scopes itself by the states §3.1 names', () {
      // The predicate's first conjunct, asserted rather than described: it is
      // the one that keeps the sweep from touching a product that already has
      // what it produces.
      expect(
        BaselineOnboardingSweep.sweepStates,
        containsAll(<Object>[
          ProductState.registered,
          ProductState.baselinePending,
          ProductState.baselineBlocked,
        ]),
      );
      expect(BaselineOnboardingSweep.sweepStates, hasLength(3));
    });

    test(
      'the second hypothetical product needs nothing the first one set up',
      () {
        // The gate above proves the CODE names no product. This proves the
        // ARGUMENTS carry all the identity — the same call, two unrelated
        // products, no configuration shared between them.
        expect(kHypotheticalSecondProduct, isNot(contains('shipit')));
        expect(kHypotheticalSecondRepository, isNot(contains('shipit')));
        expect(kHypotheticalSecondHost, isNot(contains('shipit')));
        expect(kHypotheticalSecondHost, contains('another-remote.test'));
      },
    );
  });
}
