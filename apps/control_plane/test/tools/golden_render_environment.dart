/// The rendering environment that owns `test/goldens/**`, and the precondition
/// that makes a run **refuse to grade** anywhere else.
///
/// ## The failure this exists for
///
/// A golden baseline is not an assertion about a widget. It is a PNG: pixel data
/// whose meaning includes the text rasteriser, the font stack and the Flutter
/// engine that produced it. Grading it against a render taken on a different
/// machine does not produce a weak result, it produces a **confident wrong
/// one**.
///
/// The noise-floor guard in `check_golden_domination.dart` cannot catch that,
/// and that is not a gap in it. It renders twice and compares the two renders
/// to *each other*. On a mismatched platform those two renders agree with each
/// other perfectly — same machine, same SDK, same fonts — so the floor measures
/// ~0, the guard passes, and the check goes on to emit 54 verdicts that
/// describe the runner rather than the baselines. The guard covers *runner
/// instability*. It cannot cover *runner-versus-baseline systematic
/// difference*, which is the failure that actually happens.
///
/// So the environment is checked **before** anything is graded, from a contract
/// committed next to the check, and a mismatch is a refusal: no verdicts, a
/// message naming every mismatched axis with expected and observed, and a
/// distinct exit code so "I would not grade" is never mistaken for "I graded
/// and the baselines are stale".
///
/// ## What is pinned, and what cannot be
///
/// The enforced axes are the ones a workflow controls: OS family, OS major,
/// architecture, and the exact Flutter SDK version. The OS **patch** level is
/// recorded in the contract but not enforced, because GitHub updates the
/// `macos-26` image weekly and no workflow can hold it still. Enforcing a value
/// that drifts every few days would make this gate refuse to grade on every
/// image rollout — a permanently red required gate with no owner, which is the
/// same failure in the other direction. Drift in the patch level is reported,
/// never silently absorbed and never fatal.
///
/// This layer decides only *whether a comparison is meaningful here*. It does
/// not decide anything about the comparison itself: the threshold, the
/// comparator and the tolerance all still belong to
/// `helpers/golden_tolerance.dart`, which this file does not touch.
library;

import 'dart:convert';
import 'dart:io';

/// Where the contract lives.
///
/// Fixed on purpose: the contract governing a run is never chosen by a flag on
/// that run, so there is no argument to this check that could make a
/// mismatched machine look attested.
const defaultContractPath = 'test/tools/golden_render_environment.json';

/// Exit codes, defined once so the two tools cannot drift on what a refusal
/// means.
///
/// | code | meaning |
/// |---|---|
/// | 0 | every baseline is current |
/// | 1 | graded, and at least one baseline is **not** current |
/// | 2 | usage, decoding, or comparator error — nothing was graded |
/// | 3 | **refused to grade**: the environment cannot be attested |
///
/// 3 exists so that "I would not grade" and "I graded and the baselines are
/// stale" are never the same line in a build log. A refusal is not a verdict.
const exitPass = 0;
const exitDirty = 1;
const exitUsage = 2;
const exitRefusedToGrade = 3;

/// The pinned axes of the render environment.
enum RenderEnvironmentAxis { osFamily, osMajor, architecture, flutterVersion }

/// Human-readable axis label, used in refusal messages and in the log line that
/// reports a satisfied environment.
String environmentAxisLabel(RenderEnvironmentAxis axis) => switch (axis) {
  RenderEnvironmentAxis.osFamily => 'os',
  RenderEnvironmentAxis.osMajor => 'os major',
  RenderEnvironmentAxis.architecture => 'architecture',
  RenderEnvironmentAxis.flutterVersion => 'flutter',
};

/// What the committed baselines were rendered on.
class RenderEnvironmentContract {
  const RenderEnvironmentContract({
    required this.osFamily,
    required this.osMajor,
    required this.architecture,
    required this.flutterVersion,
    required this.maxNoiseFloorRatio,
    this.renderedOsVersion,
    this.renderedOsBuild,
    this.renderedFlutterDartSdk,
    this.provenance,
    this.source = defaultContractPath,
  });

  /// `macos`, `linux`, `windows`.
  final String osFamily;

  /// The OS **major** version, which is the axis that changes the CoreText and
  /// glyph-rasterisation stack. A three-major gap is a different rasteriser,
  /// not a different patch.
  final int osMajor;

  /// `arm64` / `x64`.
  final String architecture;

  /// The exact Flutter SDK version, e.g. `3.44.7`.
  final String flutterVersion;

  /// The largest render-to-render deviation the pinned environment may show
  /// before the run is refused. Measured at 0.0000% on the rendering machine.
  final double maxNoiseFloorRatio;

  /// Recorded, not enforced — see the library doc comment.
  final String? renderedOsVersion;
  final String? renderedOsBuild;
  final String? renderedFlutterDartSdk;

  /// The decision or change that set this contract.
  final String? provenance;

  /// Where this contract was read from, quoted in every message it produces.
  final String source;

  /// Parses the contract, failing closed.
  ///
  /// A missing or malformed axis is an error rather than a default: a
  /// precondition that silently substitutes a guess for a value it could not
  /// read is the same false assurance as no precondition at all.
  static RenderEnvironmentContract fromJson(
    Map<String, Object?> json, {
    String path = defaultContractPath,
  }) {
    String text(String key) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      throw FormatException('$path: `$key` must be a non-empty string');
    }

    int integer(String key) {
      final value = json[key];
      if (value is int) return value;
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
      throw FormatException('$path: `$key` must be an integer');
    }

    double number(String key) {
      final value = json[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
      throw FormatException('$path: `$key` must be a number');
    }

    return RenderEnvironmentContract(
      osFamily: text('osFamily'),
      osMajor: integer('osMajor'),
      architecture: text('architecture'),
      flutterVersion: text('flutterVersion'),
      maxNoiseFloorRatio: number('maxNoiseFloorRatio'),
      renderedOsVersion: json['renderedOsVersion'] as String?,
      renderedOsBuild: json['renderedOsBuild'] as String?,
      renderedFlutterDartSdk: json['renderedFlutterDartSdk'] as String?,
      provenance: json['_authority'] as String?,
      source: path,
    );
  }

  static RenderEnvironmentContract load([String path = defaultContractPath]) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError(
        'cannot read the render-environment contract at $path. The goldens '
        'are pixel data pinned to the machine that rendered them, so a missing '
        'contract means the run cannot attest to anything and must not grade.',
      );
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      throw FormatException('$path: contract must be a JSON object');
    }
    return RenderEnvironmentContract.fromJson(decoded, path: path);
  }
}

/// What the machine running the check actually is.
class ObservedEnvironment {
  const ObservedEnvironment({
    required this.osFamily,
    required this.osVersion,
    required this.architecture,
    required this.flutterVersion,
    this.osMajor,
    this.flutterProbeDetail = '',
  });

  /// `Platform.operatingSystem`.
  final String osFamily;

  /// Full OS version string, e.g. `26.6.2`.
  final String osVersion;

  /// OS major version, parsed from [osVersion].
  final int? osMajor;

  /// `uname -m`. Null when it could not be determined.
  final String? architecture;

  /// Exact Flutter framework version, or null when it could not be probed.
  final String? flutterVersion;

  /// Why the Flutter version is null, for the refusal message.
  final String flutterProbeDetail;

  String get architectureOrUnavailable => architecture ?? 'unavailable';
  String get flutterOrUnavailable => flutterVersion ?? 'unavailable';
}

/// One axis on which the machine fails to be the machine that rendered the
/// baselines.
class EnvironmentMismatch {
  const EnvironmentMismatch({
    required this.axis,
    required this.expected,
    required this.observed,
  });

  final RenderEnvironmentAxis axis;
  final String expected;
  final String observed;

  @override
  String toString() =>
      '${environmentAxisLabel(axis)}: expected $expected, observed $observed';
}

/// Thrown when the run may not grade. Carries the message to print.
class RenderEnvironmentRefusal implements Exception {
  const RenderEnvironmentRefusal(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Every axis on which [observed] fails to be the contracted environment.
///
/// Empty means the environment is attestable.
///
/// The OS **major** axis is only meaningful when the OS family already matches;
/// reporting a Linux kernel major against a macOS contract would be noise, so a
/// family mismatch suppresses it and the family mismatch stands alone.
List<EnvironmentMismatch> findEnvironmentMismatches({
  required RenderEnvironmentContract contract,
  required ObservedEnvironment observed,
}) {
  final mismatches = <EnvironmentMismatch>[];

  if (observed.osFamily != contract.osFamily) {
    mismatches.add(
      EnvironmentMismatch(
        axis: RenderEnvironmentAxis.osFamily,
        expected: contract.osFamily,
        observed: observed.osFamily,
      ),
    );
  } else if (observed.osMajor != contract.osMajor) {
    mismatches.add(
      EnvironmentMismatch(
        axis: RenderEnvironmentAxis.osMajor,
        expected: '${contract.osMajor}.x',
        observed: observed.osMajor == null
            ? 'unavailable'
            : '${observed.osMajor}.x (${observed.osVersion})',
      ),
    );
  }

  if (observed.architectureOrUnavailable != contract.architecture) {
    mismatches.add(
      EnvironmentMismatch(
        axis: RenderEnvironmentAxis.architecture,
        expected: contract.architecture,
        observed: observed.architectureOrUnavailable,
      ),
    );
  }

  if (observed.flutterOrUnavailable != contract.flutterVersion) {
    mismatches.add(
      EnvironmentMismatch(
        axis: RenderEnvironmentAxis.flutterVersion,
        expected: contract.flutterVersion,
        observed: observed.flutterOrUnavailable,
      ),
    );
  }

  return mismatches;
}

/// Refuses unless this run is in the environment the baselines were rendered
/// in. Must be called before anything is graded.
void assertRenderEnvironment({
  required RenderEnvironmentContract contract,
  required ObservedEnvironment observed,
}) {
  final mismatches = findEnvironmentMismatches(
    contract: contract,
    observed: observed,
  );
  if (mismatches.isEmpty) return;
  throw RenderEnvironmentRefusal(
    renderEnvironmentRefusal(
      contract: contract,
      observed: observed,
      mismatches: mismatches,
    ),
  );
}

/// Refuses when the pinned environment no longer renders byte-stably.
///
/// The measured floor is 0 on the rendering machine. A non-zero floor there
/// means the environment itself has moved — an image update, a font change —
/// and every verdict computed against it would describe a machine that is no
/// longer the one that produced the baselines. That is drift wearing the
/// costume of noise, so it refuses rather than reclassifies.
void assertNoiseFloorWithin({
  required RenderEnvironmentContract contract,
  required double noiseFloor,
  required String worstFrame,
}) {
  if (noiseFloor <= contract.maxNoiseFloorRatio) return;
  throw RenderEnvironmentRefusal(
    noiseFloorRefusal(
      contract: contract,
      noiseFloor: noiseFloor,
      worstFrame: worstFrame,
    ),
  );
}

/// The refusal message for an environment mismatch.
///
/// It names every mismatched axis with what was contracted and what was
/// observed, because a refusal a reader cannot act on gets routed around.
String renderEnvironmentRefusal({
  required RenderEnvironmentContract contract,
  required ObservedEnvironment observed,
  required List<EnvironmentMismatch> mismatches,
}) {
  const labelWidth = 16;
  const expectedWidth = 18;
  final buffer = StringBuffer()
    ..writeln(
      'golden-domination check: REFUSING TO GRADE. This runner is not the '
      'environment the committed baselines were rendered in.',
    )
    ..writeln()
    ..writeln(
      '  ${'axis'.padRight(labelWidth)} '
      '${'expected'.padRight(expectedWidth)} observed',
    );
  for (final mismatch in mismatches) {
    buffer.writeln(
      '  ${environmentAxisLabel(mismatch.axis).padRight(labelWidth)} '
      '${mismatch.expected.padRight(expectedWidth)} ${mismatch.observed}',
    );
  }
  buffer
    ..writeln()
    ..writeln('  contract           ${contract.source}')
    ..writeln('  this runner        ${describeObservedEnvironment(observed)}');

  if (observed.flutterVersion == null &&
      observed.flutterProbeDetail.isNotEmpty) {
    buffer.writeln('  flutter probe      ${observed.flutterProbeDetail}');
  }

  buffer
    ..writeln()
    ..writeln(
      'A baseline is pixel data. It is evidence about the current render only '
      'on the platform and SDK that',
    )
    ..writeln(
      'produced it, so grading here would emit confident verdicts describing '
      'this runner rather than the',
    )
    ..writeln(
      'baselines - which is the exact failure this check exists to eliminate. '
      'The noise-floor guard cannot',
    )
    ..writeln(
      'catch it: two renders taken here agree with each other, so the guard '
      'measures ~0 and passes.',
    )
    ..writeln()
    ..writeln('  To fix: run this check on the contracted environment - see')
    ..writeln(
      '  .github/workflows/ci.yaml, job `golden-integrity` (runs-on and',
    )
    ..writeln('  that job\'s Flutter pin). If the baselines are deliberately')
    ..writeln(
      '  being re-rendered elsewhere, change the contract in the same reviewed',
    )
    ..writeln('  change that regenerates them.')
    ..writeln()
    ..writeln(
      '  Do NOT widen or bypass the tolerance to get a green run, and do not '
      'skip this precondition.',
    );
  if (contract.provenance != null) {
    buffer
      ..writeln()
      ..writeln('  authority          ${contract.provenance}');
  }
  return buffer.toString();
}

/// The refusal message for a noise floor above the contracted ceiling.
String noiseFloorRefusal({
  required RenderEnvironmentContract contract,
  required double noiseFloor,
  required String worstFrame,
}) {
  return '''
golden-domination check: REFUSING TO GRADE. Two renders of the same source on
this runner disagree by ${_pct(noiseFloor)} (worst frame $worstFrame), but the
contracted environment allows at most ${_pct(contract.maxNoiseFloorRatio)}.

  contract           ${contract.source}
  allowed noise floor ${_pct(contract.maxNoiseFloorRatio)}
  measured           ${_pct(noiseFloor)} ($worstFrame)

A render that is not reproducible on the machine that produced the baselines
cannot be graded against them. On the rendering machine this floor measures
exactly 0, so a non-zero value here means the environment itself has moved - an
image update, a font change - and every verdict computed against it would
describe a machine that is no longer the one the baselines came from.

  To fix: run this check on the contracted environment. If the pinned image has
  genuinely stopped reproducing the corpus, that is a finding about the
  environment: report it before deciding whether to re-render the baselines.
''';
}

/// One line describing the machine, for the log and for refusal messages.
String describeObservedEnvironment(ObservedEnvironment observed) =>
    '${observed.osFamily} ${observed.osVersion} / '
    '${observed.architectureOrUnavailable} / '
    'Flutter ${observed.flutterOrUnavailable}';

/// The log block for a run that IS in the contracted environment.
///
/// The un-enforced patch level is printed here on purpose. It cannot be pinned
/// (GitHub updates the `macos-26` image weekly), so it is surfaced on every run
/// rather than left to be discovered later in a diff.
String renderEnvironmentReport({
  required RenderEnvironmentContract contract,
  required ObservedEnvironment observed,
}) {
  final buffer = StringBuffer()
    ..writeln(
      '  rendering env       ${describeObservedEnvironment(observed)}'
      ' — matches ${contract.source}',
    )
    ..writeln(
      '  rendered on         ${contract.osFamily} '
      '${contract.renderedOsVersion ?? '${contract.osMajor}.x'} '
      '/ ${contract.architecture} / Flutter ${contract.flutterVersion}',
    );

  final rendered = contract.renderedOsVersion;
  if (rendered != null && rendered != observed.osVersion) {
    buffer.writeln(
      '                     note: OS patch drift ($rendered -> '
      '${observed.osVersion}). Not enforced: the runner image is updated '
      'weekly, so pinning the patch level would make this gate refuse to grade '
      'on every rollout.',
    );
  }
  return buffer.toString();
}

String _pct(double ratio) => '${(ratio * 100).toStringAsFixed(4)}%';

/// Measures the machine running this process.
ObservedEnvironment probeRenderEnvironment() {
  final osVersion = parseOsVersion(Platform.operatingSystemVersion);
  final architecture = _probeArchitecture();
  final flutter = _probeFlutterVersion();
  return ObservedEnvironment(
    osFamily: Platform.operatingSystem,
    osVersion: osVersion,
    osMajor: parseOsMajor(osVersion),
    architecture: architecture,
    flutterVersion: flutter.$1,
    flutterProbeDetail: flutter.$2,
  );
}

/// Normalises `Platform.operatingSystemVersion`, which on macOS arrives as
/// `Version 26.6.2 (Build 25G83)`.
String parseOsVersion(String raw) {
  final trimmed = raw.trim();
  final withoutPrefix = trimmed.startsWith('Version ')
      ? trimmed.substring('Version '.length)
      : trimmed;
  final token = withoutPrefix.split(RegExp(r'\s')).first;
  return token.isEmpty ? trimmed : token;
}

/// The major version of [osVersion], or null when there is not one to parse.
int? parseOsMajor(String osVersion) {
  final head = osVersion.split('.').first.trim();
  return int.tryParse(head);
}

/// Reads `frameworkVersion` out of `flutter --version --machine` output.
///
/// Falls back to [fallbackKey] because the key has changed name across Flutter
/// releases, and to a bare `Flutter X.Y.Z` first line because `--machine` is
/// not guaranteed to exist. Returns null rather than guessing.
String? parseFlutterVersion(String machineOutput) {
  final trimmed = machineOutput.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('{')) {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) {
      for (final key in ['frameworkVersion', 'flutterVersion']) {
        final value = decoded[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
    return null;
  }

  final match = RegExp(r'^Flutter\s+(\S+)').firstMatch(trimmed);
  return match?.group(1);
}

(String?, String) _probeFlutterVersion() {
  for (final candidate in <String>[
    if (Platform.environment['FLUTTER_ROOT'] != null)
      '${Platform.environment['FLUTTER_ROOT']}/bin/flutter'
    else
      'flutter',
  ]) {
    try {
      final result = Process.runSync(candidate, ['--version', '--machine']);
      final output = '${result.stdout}';
      if (result.exitCode == 0) {
        final version = parseFlutterVersion(output);
        if (version != null) return (version, '');
        return (null, '`$candidate --version --machine` produced no version');
      }
      return (
        null,
        '`$candidate --version --machine` exited ${result.exitCode}',
      );
    } on ProcessException catch (e) {
      return (null, '`$candidate` could not be run: ${e.message}');
    }
  }
  return (null, 'no flutter executable found');
}

String? _probeArchitecture() {
  try {
    final result = Process.runSync('uname', ['-m']);
    if (result.exitCode != 0) return null;
    final arch = result.stdout.toString().trim();
    return arch.isEmpty ? null : arch;
  } on ProcessException {
    return null;
  }
}
