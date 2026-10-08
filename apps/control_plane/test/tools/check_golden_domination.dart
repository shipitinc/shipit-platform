/// Fails the build when a golden baseline passes **only because the tolerance
/// swallowed it**.
///
/// The grading rules live in `golden_domination.dart`; this is the CLI that
/// turns them into exit codes and a failure message a human can act on.
///
/// ## Usage
///
/// ```sh
/// # from apps/control_plane
/// flutter test --update-goldens                 # render pass 1
/// cp -R test/goldens "$RUNNER_TEMP/pass1"
/// flutter test --update-goldens                 # render pass 2
/// cp -R test/goldens "$RUNNER_TEMP/pass2"
/// git checkout -- test/goldens                  # the check never commits a render
/// dart run test/tools/check_golden_domination.dart \
///   --current="$RUNNER_TEMP/pass1" --repeat="$RUNNER_TEMP/pass2"
/// ```
///
/// Two renders are required because a single render cannot be trusted to
/// define its own expected output — that is what makes the noise floor a
/// measurement rather than an assumption.
library;

import 'dart:io';

import 'golden_domination.dart';
import 'png_pixel_diff.dart';

const _defaultBaseline = 'test/goldens';

void main(List<String> args) {
  final options = _Options.parse(args);
  if (options == null) return;

  final baseline = Directory(options.baseline);
  final current = Directory(options.current);
  final repeat = Directory(options.repeat);
  for (final dir in [baseline, current, repeat]) {
    if (!dir.existsSync()) {
      stderr.writeln('golden-domination check: no such directory: ${dir.path}');
      exit(2);
    }
  }

  final tolerance = options.tolerance;
  try {
    // Precondition: the comparator must still do real work, and the tolerance
    // being graded against must be the one it actually uses.
    assertComparatorIsReal();
    final declared = readComparatorThreshold();
    if ((declared - tolerance).abs() > 1e-12) {
      stderr.writeln(
        'golden-domination check: --tolerance $tolerance does not match the '
        '$declared declared in $comparatorPath. Grading against a tolerance '
        'the comparator does not use would be meaningless.',
      );
      exit(2);
    }
  } on StateError catch (e) {
    stderr.writeln('golden-domination check: $e');
    exit(2);
  }

  final noiseByFile = measureNoiseFloor(
    baseline: baseline,
    current: current,
    repeat: repeat,
  );
  if (noiseByFile.isEmpty) {
    stderr.writeln(
      'golden-domination check: no file appears in the baseline and both '
      'renders, so the noise floor cannot be measured. Refusing to grade '
      'without one.',
    );
    exit(2);
  }
  final noise = noiseFloorOf(noiseByFile);

  stdout.writeln('golden-domination check');
  stdout.writeln('  comparator         $comparatorPath');
  stdout.writeln(
    '  tolerance          ${_fmtPct(tolerance)} '
    '($tolerance), read from the comparator, not hard-coded here',
  );
  stdout.writeln('  baseline           ${baseline.path}');
  stdout.writeln('  current render     ${current.path}');
  stdout.writeln('  repeat render      ${repeat.path}');
  stdout.writeln('  platform           ${Platform.operatingSystem}');
  stdout.writeln('  baselines          ${pngNames(baseline).length}');
  stdout.writeln(
    '  noise floor        ${_fmtPct(noise.ratio)} — largest '
    'current-vs-repeat delta, measured on this machine',
  );
  if (noise.ratio > 0) {
    stdout.writeln('                     worst frame: ${noise.file}');
  }
  stdout.writeln('');

  // If this machine cannot render the same source twice inside the tolerance,
  // no baseline can be graded against it and every verdict would describe the
  // runner rather than the corpus. Say that instead of reporting 54 confident
  // verdicts that mean nothing.
  if (noise.ratio >= tolerance) {
    stderr.writeln(
      'golden-domination check: this machine\'s own noise floor '
      '(${_fmtPct(noise.ratio)}, worst frame ${noise.file}) is at or above '
      'the comparator tolerance (${_fmtPct(tolerance)}). Two renders of the '
      'same source do not agree here, so no baseline can be graded against '
      'it. The goldens are render-platform pinned; run this check on the '
      'platform that produced them.',
    );
    exit(2);
  }

  final reports = gradeGoldens(
    baseline: baseline,
    current: current,
    repeat: repeat,
    noiseFloor: noise.ratio,
    tolerance: tolerance,
  );

  DominationVerdict? open;
  for (final report in reports) {
    if (report.verdict != open) {
      open = report.verdict;
      final count = reports.where((r) => r.verdict == open).length;
      stdout.writeln('${verdictLabel(report.verdict)} ($count)');
    }
    stdout.writeln(
      '  ${_pad(report.file, 52)} '
      '${report.delta == null ? '     n/a  ' : _fmtPct(report.delta!.ratio)}  '
      '${report.delta == null ? report.detail : _describe(report.delta!)}',
    );
  }
  stdout.writeln('');

  final dirty = reports.where((r) => !r.isClean).toList();
  if (dirty.isEmpty) {
    stdout.writeln(
      'PASS: ${reports.length} of ${reports.length} baselines match the '
      'current render within this machine\'s noise floor '
      '(${_fmtPct(noise.ratio)}).',
    );
    exit(0);
  }

  stdout.writeln(
    'FAIL: ${dirty.length} of ${reports.length} baselines are not current. '
    'The tolerance did not cause this; it hid it.',
  );
  final dominated = dirty
      .where((r) => r.verdict == DominationVerdict.toleranceDominated)
      .length;
  if (dominated > 0) {
    stdout.writeln(
      '  $dominated of them pass the golden comparator ONLY because their '
      'delta sits inside the ${_fmtPct(tolerance)} tolerance. Those are '
      'stale baselines being reported green, which is the exact failure this '
      'check exists to catch.',
    );
  }
  stdout.writeln('');
  stdout.writeln(
    '  To fix: `cd apps/control_plane && flutter test '
    '--update-goldens`, then read the changed frames before committing '
    'them.',
  );
  stdout.writeln(
    '  Do NOT widen or bypass the tolerance. A baseline that '
    'needs regenerating is a baseline that drifted; the tolerance is what '
    'hid the drift, not what caused it.',
  );
  exit(1);
}

String _describe(PixelDelta delta) {
  if (delta.byteIdentical) return 'byte-identical to the render';
  return '${delta.differingPixels}/${delta.totalPixels} px, '
      'peak channel delta ${delta.peakChannelDelta}';
}

String _fmtPct(double ratio) => '${(ratio * 100).toStringAsFixed(4)}%';

String _pad(String s, int width) => s.length >= width ? s : s.padRight(width);

class _Options {
  const _Options({
    required this.baseline,
    required this.current,
    required this.repeat,
    required this.tolerance,
  });

  final String baseline;
  final String current;
  final String repeat;
  final double tolerance;

  static _Options? parse(List<String> args) {
    String? baseline = _defaultBaseline;
    String? current;
    String? repeat;
    var tolerance = readComparatorThreshold();

    for (final arg in args) {
      if (!arg.startsWith('--')) {
        stderr.writeln('golden-domination check: unexpected argument `$arg`');
        stderr.writeln(_usage);
        return null;
      }
      final split = arg.indexOf('=');
      final name = split < 0 ? arg : arg.substring(0, split);
      final value = split < 0 ? null : arg.substring(split + 1);
      switch (name) {
        case '--baseline':
          baseline = value;
        case '--current':
          current = value;
        case '--repeat':
          repeat = value;
        case '--tolerance':
          final parsed = double.tryParse(value ?? '');
          if (parsed == null) {
            stderr.writeln(
              'golden-domination check: --tolerance needs a number, '
              'got `$value`',
            );
            return null;
          }
          tolerance = parsed;
        case '--help':
        case '-h':
          stdout.writeln(_usage);
          return null;
        default:
          stderr.writeln('golden-domination check: unknown option `$name`');
          stderr.writeln(_usage);
          return null;
      }
    }

    if (current == null || repeat == null) {
      stderr.writeln(
        'golden-domination check: --current and --repeat are both required. '
        'The noise floor is measured from two renders on the machine doing '
        'the checking; a single render cannot be trusted to define its own '
        'expected output.',
      );
      stderr.writeln(_usage);
      return null;
    }

    return _Options(
      baseline: baseline!,
      current: current,
      repeat: repeat,
      tolerance: tolerance,
    );
  }
}

const _usage =
    '''
usage: dart run test/tools/check_golden_domination.dart \\
    --current=<render-1-dir> --repeat=<render-2-dir> [--baseline=<dir>] \\
    [--tolerance=<ratio>]

  --baseline   committed baselines to grade (default: $_defaultBaseline)
  --current    a fresh render of the current source
  --repeat     a second, independent fresh render; supplies the noise floor
  --tolerance  override for experiments only; must match the comparator's

Exit 0 when every baseline is current, 1 when any is not, 2 on a usage,
decoding or environment error.
''';
