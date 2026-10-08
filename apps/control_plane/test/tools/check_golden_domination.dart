/// Fails the build when a golden baseline passes **only because the tolerance
/// swallowed it** — and refuses to grade at all on a machine that is not the
/// one the baselines were rendered on.
///
/// The grading rules live in `golden_domination.dart`; the environment contract
/// and its precondition live in `golden_render_environment.dart`. This is the
/// CLI that turns both into exit codes and messages a human can act on.
///
/// ## The precondition comes first
///
/// Before a single pixel is compared, this verifies that the runner is the
/// environment the committed baselines were rendered in. On a mismatch it
/// refuses and emits **no verdicts**. That ordering is the whole point: a
/// check that graded first and diagnosed afterwards would already have emitted
/// the confident wrong answer by the time it noticed.
///
/// It is not redundant with the noise-floor guard. The guard compares two
/// renders against *each other*, so on a mismatched machine they agree, the
/// guard measures ~0, and it passes — precisely the case it cannot see.
///
/// ## Usage
///
/// ```sh
/// # from apps/control_plane
/// dart run test/tools/check_render_environment.dart  # refuse fast, no renders
/// flutter test --update-goldens                      # render pass 1
/// cp -R test/goldens "$RUNNER_TEMP/pass1"
/// flutter test --update-goldens                      # render pass 2
/// cp -R test/goldens "$RUNNER_TEMP/pass2"
/// git checkout -- test/goldens                       # this never commits a render
/// dart run test/tools/check_golden_domination.dart \
///   --current="$RUNNER_TEMP/pass1" --repeat="$RUNNER_TEMP/pass2"
/// ```
///
/// Two renders are required because a single render cannot be trusted to define
/// its own expected output — that is what makes the noise floor a measurement
/// rather than an assumption.
///
/// ## Exit codes
///
/// | code | meaning |
/// |---|---|
/// | 0 | every baseline is current |
/// | 1 | graded, and at least one baseline is **not** current |
/// | 2 | usage, decoding, or comparator error — nothing was graded |
/// | 3 | **refused to grade**: the environment cannot be attested |
library;

import 'dart:io';

import 'golden_domination.dart';
import 'golden_render_environment.dart';
import 'png_pixel_diff.dart';

const _defaultBaseline = 'test/goldens';

/// Everything [runGoldenDominationCheck] needs, injected so the flow can be
/// exercised by tests instead of only by a command line.
///
/// Note what is *not* here: there is no `contract` field. The check loads the
/// committed contract from its fixed path itself, so no caller — not this CLI,
/// not a test, not a future wrapper — can point a run at a contract other than
/// the one committed beside the check.
class GoldenCheckRequest {
  const GoldenCheckRequest({
    required this.baseline,
    required this.current,
    required this.repeat,
    required this.tolerance,
    required this.observed,
    this.comparatorSourcePath = comparatorPath,
  });

  final Directory baseline;
  final Directory current;
  final Directory repeat;
  final double tolerance;
  final ObservedEnvironment observed;
  final String comparatorSourcePath;
}

/// What the check concluded.
///
/// [refusedToGrade] is the flag that matters: when it is true, [reports] is
/// empty **by construction**, because the precondition throws before any
/// grading call is reached.
class GoldenCheckOutcome {
  const GoldenCheckOutcome({
    required this.exitCode,
    this.output = const [],
    this.errors = const [],
    this.reports = const [],
    this.noiseFloor,
    this.worstFrame,
  });

  final int exitCode;
  final List<String> output;
  final List<String> errors;

  /// The grades. Empty when the run refused or errored.
  final List<GoldenReport> reports;

  final double? noiseFloor;
  final String? worstFrame;

  bool get refusedToGrade => exitCode == exitRefusedToGrade;

  /// Every line this run would print, stdout and stderr together — what a
  /// caller needs in order to assert on the message a human actually reads.
  String get transcript => [...output, ...errors].join('\n');
}

/// The whole check, as one function.
///
/// Split from [main] for exactly one reason: so that "the environment is
/// verified before anything is graded" is something a test can execute rather
/// than something the source order merely asserts.
GoldenCheckOutcome runGoldenDominationCheck(GoldenCheckRequest request) {
  final baseline = request.baseline;
  final current = request.current;
  final repeat = request.repeat;
  final tolerance = request.tolerance;

  for (final dir in [baseline, current, repeat]) {
    if (!dir.existsSync()) {
      return GoldenCheckOutcome(
        exitCode: exitUsage,
        errors: ['golden-domination check: no such directory: ${dir.path}'],
      );
    }
  }

  // ---- preconditions, before any grading -------------------------------
  final comparatorSourcePath = request.comparatorSourcePath;
  try {
    assertComparatorIsReal(path: comparatorSourcePath);
    final declared = readComparatorThreshold(path: comparatorSourcePath);
    if ((declared - tolerance).abs() > 1e-12) {
      return GoldenCheckOutcome(
        exitCode: exitUsage,
        errors: [
          'golden-domination check: --tolerance $tolerance does not match the '
              '$declared declared in $comparatorSourcePath. Grading against a '
              'tolerance the comparator does not use would be meaningless.',
        ],
      );
    }
  } on StateError catch (e) {
    return GoldenCheckOutcome(
      exitCode: exitUsage,
      errors: ['golden-domination check: $e'],
    );
  }

  // The environment, before anything is graded. A refusal here produces no
  // verdicts, and that emptiness is asserted by the test suite.
  final RenderEnvironmentContract contract;
  try {
    contract = RenderEnvironmentContract.load();
    assertRenderEnvironment(contract: contract, observed: request.observed);
  } on RenderEnvironmentRefusal catch (refusal) {
    return GoldenCheckOutcome(
      exitCode: exitRefusedToGrade,
      errors: [refusal.message],
    );
  } on Object catch (error) {
    return GoldenCheckOutcome(
      exitCode: exitUsage,
      errors: [
        'golden-domination check: cannot read the render-environment contract '
            '($error). Refusing to grade: the baselines are pixel data pinned to '
            'the machine that rendered them.',
      ],
    );
  }

  final noiseByFile = measureNoiseFloor(
    baseline: baseline,
    current: current,
    repeat: repeat,
  );
  if (noiseByFile.isEmpty) {
    return const GoldenCheckOutcome(
      exitCode: exitUsage,
      errors: [
        'golden-domination check: no file appears in the baseline and both '
            'renders, so the noise floor cannot be measured. Refusing to grade '
            'without one.',
      ],
    );
  }
  final noise = noiseFloorOf(noiseByFile);

  // The contracted environment renders byte-stably. If this machine does not,
  // it is no longer the machine the baselines came from, whatever the floor is
  // relative to the comparator's tolerance.
  try {
    assertNoiseFloorWithin(
      contract: contract,
      noiseFloor: noise.ratio,
      worstFrame: noise.file,
    );
  } on RenderEnvironmentRefusal catch (refusal) {
    return GoldenCheckOutcome(
      exitCode: exitRefusedToGrade,
      errors: [refusal.message],
      noiseFloor: noise.ratio,
      worstFrame: noise.file,
    );
  }

  // ---- grading, only now -----------------------------------------------
  final reports = gradeGoldens(
    baseline: baseline,
    current: current,
    repeat: repeat,
    noiseFloor: noise.ratio,
    tolerance: tolerance,
  );

  final output = <String>[
    'golden-domination check',
    '  comparator         $comparatorSourcePath',
    '  tolerance          ${_fmtPct(tolerance)} '
        '($tolerance), read from the comparator, not hard-coded here',
    '  baseline           ${baseline.path}',
    '  current render     ${current.path}',
    '  repeat render      ${repeat.path}',
    ...renderEnvironmentReport(
      contract: contract,
      observed: request.observed,
    ).trimRight().split('\n'),
    '  baselines          ${pngNames(baseline).length}',
    '  noise floor        ${_fmtPct(noise.ratio)} — largest '
        'current-vs-repeat delta, measured on this machine',
    if (noise.ratio > 0) '                     worst frame: ${noise.file}',
    '',
  ];

  DominationVerdict? open;
  for (final report in reports) {
    if (report.verdict != open) {
      open = report.verdict;
      final count = reports.where((r) => r.verdict == open).length;
      output.add('${verdictLabel(report.verdict)} ($count)');
    }
    output.add(
      '  ${_pad(report.file, 52)} '
      '${report.delta == null ? '     n/a  ' : _fmtPct(report.delta!.ratio)}  '
      '${report.delta == null ? report.detail : _describe(report.delta!)}',
    );
  }
  output.add('');

  final dirty = reports.where((r) => !r.isClean).toList();
  if (dirty.isEmpty) {
    output.add(
      'PASS: ${reports.length} of ${reports.length} baselines match the '
      'current render within this machine\'s noise floor '
      '(${_fmtPct(noise.ratio)}).',
    );
    return GoldenCheckOutcome(
      exitCode: exitPass,
      output: output,
      reports: reports,
      noiseFloor: noise.ratio,
      worstFrame: noise.file,
    );
  }

  output.add(
    'FAIL: ${dirty.length} of ${reports.length} baselines are not current. '
    'The tolerance did not cause this; it hid it.',
  );
  final dominated = dirty
      .where((r) => r.verdict == DominationVerdict.toleranceDominated)
      .length;
  if (dominated > 0) {
    output.add(
      '  $dominated of them pass the golden comparator ONLY because their '
      'delta sits inside the ${_fmtPct(tolerance)} tolerance. Those are '
      'stale baselines being reported green, which is the exact failure this '
      'check exists to catch.',
    );
  }
  output.add('');
  output.add(
    '  To fix: `cd apps/control_plane && flutter test '
    '--update-goldens`, then read the changed frames before committing them.',
  );
  output.add(
    '  Do NOT widen or bypass the tolerance. A baseline that '
    'needs regenerating is a baseline that drifted; the tolerance is what '
    'hid the drift, not what caused it.',
  );
  return GoldenCheckOutcome(
    exitCode: exitDirty,
    output: output,
    reports: reports,
    noiseFloor: noise.ratio,
    worstFrame: noise.file,
  );
}

void main(List<String> args) {
  final options = _Options.parse(args);
  if (options == null) return;

  final outcome = runGoldenDominationCheck(
    GoldenCheckRequest(
      baseline: Directory(options.baseline),
      current: Directory(options.current),
      repeat: Directory(options.repeat),
      tolerance: options.tolerance,
      observed: probeRenderEnvironment(),
    ),
  );

  for (final line in outcome.output) {
    stdout.writeln(line);
  }
  for (final line in outcome.errors) {
    stderr.writeln(line);
  }
  exit(outcome.exitCode);
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

There is no flag to skip or relax the environment precondition: the contract is
read from a fixed path and the machine is measured, so a run cannot be pointed
at a different contract than the one committed beside the check.

Exit 0 when every baseline is current, 1 when any is not, 2 on a usage,
decoding or comparator error, 3 when the run refuses to grade because this
machine is not the environment the baselines were rendered in.
''';
