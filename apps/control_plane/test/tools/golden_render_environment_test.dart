/// Tests for the render-environment precondition.
///
/// The precondition is the thing that decides whether a grading run means
/// anything, so it gets tested at the level a wrong decision would hurt: which
/// axis mismatches are caught, which are deliberately not, and what a refusal
/// actually says to whoever has to act on it.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'golden_render_environment.dart';

void main() {
  group('the committed render-environment contract', () {
    test('declares the environment the baselines were rendered on', () {
      final contract = RenderEnvironmentContract.load();
      // Pinned deliberately. These four axes plus the ceiling below are the
      // whole contract; changing one means the baselines are being re-rendered
      // somewhere else, and that has to be argued about in a reviewed change
      // rather than discovered when a required gate starts refusing.
      expect(contract.osFamily, 'macos');
      expect(contract.osMajor, 26);
      expect(contract.architecture, 'arm64');
      expect(contract.flutterVersion, '3.44.7');
      expect(contract.maxNoiseFloorRatio, 0);
      expect(contract.renderedOsVersion, '26.6.2');
      expect(contract.source, defaultContractPath);
    });

    test('records the authority that set it', () {
      final contract = RenderEnvironmentContract.load();
      expect(
        contract.provenance,
        contains('3e9dfb75-7bdf-4a8c-89dd-c76779a65371'),
      );
      expect(contract.provenance, contains('OPTION_C'));
    });

    test('refuses to invent a value for an axis it could not read', () {
      // Fail closed. A precondition that substitutes a guess for an unreadable
      // contract is the same false assurance as no precondition.
      expect(
        () => RenderEnvironmentContract.fromJson({
          'osMajor': 26,
          'architecture': 'arm64',
          'flutterVersion': '3.44.7',
          'maxNoiseFloorRatio': 0,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('names the contract file it could not parse', () {
      final dir = Directory.systemTemp.createTempSync('render_env_contract');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/golden_render_environment.json';
      File(path).writeAsStringSync('{"osFamily": "macos", "osMajor": 26}');
      expect(
        () => RenderEnvironmentContract.load(path),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(path),
          ),
        ),
      );
    });

    test('refuses to run at all when the contract is missing', () {
      expect(
        () => RenderEnvironmentContract.load(
          '${Directory.systemTemp.path}/definitely_absent_contract.json',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('findEnvironmentMismatches', () {
    final contract = RenderEnvironmentContract.load();

    ObservedEnvironment observed({
      String osFamily = 'macos',
      String osVersion = '26.6.2',
      int? osMajor = 26,
      String? architecture = 'arm64',
      String? flutterVersion = '3.44.7',
      String flutterProbeDetail = '',
    }) => ObservedEnvironment(
      osFamily: osFamily,
      osVersion: osVersion,
      osMajor: osMajor,
      architecture: architecture,
      flutterVersion: flutterVersion,
      flutterProbeDetail: flutterProbeDetail,
    );

    test('finds nothing when every pinned axis matches', () {
      expect(
        findEnvironmentMismatches(contract: contract, observed: observed()),
        isEmpty,
      );
    });

    test('catches an OS major gap — the axis that changes the rasteriser', () {
      final mismatches = findEnvironmentMismatches(
        contract: contract,
        observed: observed(osVersion: '14.7.1', osMajor: 14),
      );
      expect(mismatches, hasLength(1));
      expect(mismatches.single.axis, RenderEnvironmentAxis.osMajor);
      expect(mismatches.single.expected, '26.x');
      expect(mismatches.single.observed, contains('14.x'));
    });

    test('catches an architecture change', () {
      final mismatches = findEnvironmentMismatches(
        contract: contract,
        observed: observed(architecture: 'x64'),
      );
      expect(mismatches.single.axis, RenderEnvironmentAxis.architecture);
      expect(mismatches.single.expected, 'arm64');
      expect(mismatches.single.observed, 'x64');
    });

    test('catches a Flutter patch difference', () {
      // The exact gap the previous job was pinned to: .fvmrc says 3.44.0 and
      // the baselines were rendered by 3.44.7.
      final mismatches = findEnvironmentMismatches(
        contract: contract,
        observed: observed(flutterVersion: '3.44.0'),
      );
      expect(mismatches.single.axis, RenderEnvironmentAxis.flutterVersion);
      expect(mismatches.single.expected, '3.44.7');
      expect(mismatches.single.observed, '3.44.0');
    });

    test('catches a Flutter version it could not probe at all', () {
      // Unavailable is not "close enough". If the SDK cannot be identified,
      // nothing about this machine can be attested.
      final mismatches = findEnvironmentMismatches(
        contract: contract,
        observed: observed(flutterVersion: null),
      );
      expect(mismatches.single.axis, RenderEnvironmentAxis.flutterVersion);
      expect(mismatches.single.observed, 'unavailable');
    });

    test('catches an architecture it could not determine', () {
      final mismatches = findEnvironmentMismatches(
        contract: contract,
        observed: observed(architecture: null),
      );
      expect(mismatches.single.axis, RenderEnvironmentAxis.architecture);
      expect(mismatches.single.observed, 'unavailable');
    });

    test('reports every axis at once, not just the first', () {
      final mismatches = findEnvironmentMismatches(
        contract: contract,
        observed: observed(
          osVersion: '14.7.1',
          osMajor: 14,
          architecture: 'x64',
          flutterVersion: '3.44.0',
        ),
      );
      expect(mismatches.map((m) => m.axis).toSet(), {
        RenderEnvironmentAxis.osMajor,
        RenderEnvironmentAxis.architecture,
        RenderEnvironmentAxis.flutterVersion,
      });
    });

    test('reports the OS family alone when the family differs', () {
      // A Linux kernel major is not comparable to a macOS major, so reporting
      // both would bury the one that matters.
      final mismatches = findEnvironmentMismatches(
        contract: contract,
        observed: observed(osFamily: 'linux', osVersion: '6.8.0', osMajor: 6),
      );
      expect(mismatches, hasLength(1));
      expect(mismatches.single.axis, RenderEnvironmentAxis.osFamily);
      expect(mismatches.single.expected, 'macos');
      expect(mismatches.single.observed, 'linux');
    });

    test('does NOT enforce the OS patch level, and says why in the report', () {
      // Deliberate, and pinned by this test so it cannot be changed by accident.
      // GitHub updates the macos-26 image weekly; no workflow can hold a patch
      // level still, so enforcing it would make this gate refuse to grade on
      // every image rollout. Drift is surfaced in the log instead.
      expect(
        findEnvironmentMismatches(
          contract: contract,
          observed: observed(osVersion: '26.7.0'),
        ),
        isEmpty,
      );

      final report = renderEnvironmentReport(
        contract: contract,
        observed: observed(osVersion: '26.7.0'),
      );
      expect(report, contains('OS patch drift'));
      expect(report, contains('26.7.0'));
      expect(report, contains('Not enforced'));
    });

    test('says nothing about drift when the patch level agrees', () {
      final report = renderEnvironmentReport(
        contract: contract,
        observed: observed(),
      );
      expect(report, isNot(contains('OS patch drift')));
      expect(report, contains('matches $defaultContractPath'));
    });
  });

  group('assertRenderEnvironment', () {
    final contract = RenderEnvironmentContract.load();

    test('passes on the contracted environment', () {
      expect(
        () => assertRenderEnvironment(
          contract: contract,
          observed: const ObservedEnvironment(
            osFamily: 'macos',
            osVersion: '26.6.2',
            osMajor: 26,
            architecture: 'arm64',
            flutterVersion: '3.44.7',
          ),
        ),
        returnsNormally,
      );
    });

    test('refuses, rather than warning, on a mismatch', () {
      expect(
        () => assertRenderEnvironment(
          contract: contract,
          observed: const ObservedEnvironment(
            osFamily: 'macos',
            osVersion: '14.7.1',
            osMajor: 14,
            architecture: 'arm64',
            flutterVersion: '3.44.7',
          ),
        ),
        throwsA(isA<RenderEnvironmentRefusal>()),
      );
    });

    test('the refusal says it is refusing, and why that matters', () {
      Object? caught;
      try {
        assertRenderEnvironment(
          contract: contract,
          observed: const ObservedEnvironment(
            osFamily: 'macos',
            osVersion: '14.7.1',
            osMajor: 14,
            architecture: 'x64',
            flutterVersion: '3.44.0',
          ),
        );
      } on RenderEnvironmentRefusal catch (refusal) {
        caught = refusal.message;
      }
      final message = caught.toString();

      expect(message, contains('REFUSING TO GRADE'));
      expect(message, contains('26.x'));
      expect(message, contains('14.x'));
      expect(message, contains('arm64'));
      expect(message, contains('x64'));
      expect(message, contains('3.44.7'));
      expect(message, contains('3.44.0'));
      // It must explain that the noise-floor guard cannot catch this, or the
      // reader will conclude the guard already covered it.
      expect(message, contains('noise-floor guard cannot'));
      // And it must point at the two legitimate ways out, both of which are
      // reviewed changes, plus the two that are not.
      expect(message, contains('golden-integrity'));
      expect(message, contains('Do NOT widen or bypass the tolerance'));
      expect(message, isNot(contains('--force')));
    });
  });

  group('assertNoiseFloorWithin', () {
    final contract = RenderEnvironmentContract.load();

    test('accepts a floor of exactly zero, the measured value here', () {
      expect(
        () => assertNoiseFloorWithin(
          contract: contract,
          noiseFloor: 0,
          worstFrame: 'n/a',
        ),
        returnsNormally,
      );
    });

    test('refuses any non-zero floor, and names the frame that caused it', () {
      // This is the executable form of the noise-floor finding. On the machine
      // that rendered the baselines the floor is 0, so a non-zero value there
      // means the environment has moved rather than that rendering jitters.
      Object? caught;
      try {
        assertNoiseFloorWithin(
          contract: contract,
          noiseFloor: 0.003172,
          worstFrame: 'all_work_light.png',
        );
      } on RenderEnvironmentRefusal catch (refusal) {
        caught = refusal.message;
      }
      expect(caught, isA<String>());
      final message = caught.toString();
      expect(message, contains('REFUSING TO GRADE'));
      expect(message, contains('0.3172%'));
      expect(message, contains('all_work_light.png'));
      expect(message, contains(defaultContractPath));
    });
  });

  group('parseFlutterVersion', () {
    test('reads frameworkVersion out of --machine output', () {
      expect(
        parseFlutterVersion('{"frameworkVersion":"3.44.7","channel":"stable"}'),
        '3.44.7',
      );
    });

    test('falls back to flutterVersion when frameworkVersion is absent', () {
      expect(parseFlutterVersion('{"flutterVersion":"3.44.7"}'), '3.44.7');
    });

    test('reads a plain first line when --machine is unavailable', () {
      expect(
        parseFlutterVersion('Flutter 3.44.7 • channel stable • ...'),
        '3.44.7',
      );
    });

    test('returns null rather than guessing', () {
      expect(parseFlutterVersion(''), isNull);
      expect(parseFlutterVersion('   \n'), isNull);
      expect(parseFlutterVersion('{"channel":"stable"}'), isNull);
    });
  });

  group('parseOsVersion / parseOsMajor', () {
    test('normalises the macOS `Version X.Y.Z (Build N)` form', () {
      expect(parseOsVersion('Version 26.6.2 (Build 25G83)'), '26.6.2');
      expect(parseOsMajor('26.6.2'), 26);
    });

    test('passes a bare version through', () {
      expect(parseOsVersion('15.3'), '15.3');
      expect(parseOsMajor('15.3'), 15);
    });

    test('returns null when there is no major to parse', () {
      expect(parseOsMajor('not-a-version'), isNull);
    });
  });

  group('probeRenderEnvironment', () {
    test('measures the machine it runs on', () {
      final observed = probeRenderEnvironment();
      expect(observed.osFamily, isNotEmpty);
      expect(observed.osVersion, isNotEmpty);
      expect(observed.osMajor, isNotNull);
      expect(observed.architectureOrUnavailable, isNotEmpty);
      expect(observed.flutterOrUnavailable, isNotEmpty);
    });

    test('finds the Flutter SDK this test suite is itself running under', () {
      // Can fail: a probe that stops resolving FLUTTER_ROOT, or one that shells
      // out to a different Flutter on PATH, is a precondition measuring the
      // wrong SDK.
      final observed = probeRenderEnvironment();
      final flutterRoot = Platform.environment['FLUTTER_ROOT'];
      if (flutterRoot == null) {
        // No FLUTTER_ROOT means the probe had to find `flutter` on PATH, which
        // is a legitimate configuration. Assert only that it got a version.
        expect(observed.flutterVersion, matches(RegExp(r'^\d+\.\d+\.\d+')));
      } else {
        expect(observed.flutterVersion, flutterRoot.split('/').last);
      }
    });
  });
}
