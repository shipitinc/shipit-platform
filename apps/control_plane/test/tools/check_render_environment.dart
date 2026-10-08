/// Refuses to grade anything on a machine that is not the one the committed
/// golden baselines were rendered on.
///
/// ## Why this is its own executable, and not a step inside the grading check
///
/// A CI job that only discovers an uncalibrated runner *after* three full
/// 40-second suite runs has already spent the runner's time, and the failure it
/// reports is the wrong one: a baseline verdict, produced on the wrong machine.
/// This runs first, costs about a second, and exists so that the expensive part
/// never starts on a runner that cannot attest to anything.
///
/// The grading check enforces the same precondition again before it grades
/// ([assertRenderEnvironment]). Two enforcement points is deliberate: the first
/// fails fast, the second means the guarantee travels with the check itself and
/// cannot be skipped by whoever invokes it.
///
/// ## Exit codes
///
/// See `golden_render_environment.dart`: 0 attested, 2 nothing could be
/// measured, **3 refused to grade**. 3 is distinct on purpose — "I would not
/// grade" and "I graded and the baselines are stale" must never be the same
/// outcome in a log.
///
/// There is no flag to skip or override this. The contract is read from a fixed
/// path and the machine is measured, so there is no argument to this tool that
/// can make a mismatch look like a match.
library;

import 'dart:io';

import 'golden_render_environment.dart';

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(_usage);
    return;
  }
  if (args.isNotEmpty) {
    stderr.writeln(
      'render-environment precondition: unexpected argument `${args.first}`. '
      'This tool takes no arguments on purpose: a flag that could select the '
      'contract or override the measurement would be a bypass of the '
      'precondition it exists to be.\n\n$_usage',
    );
    exit(exitUsage);
  }

  final RenderEnvironmentContract contract;
  try {
    contract = RenderEnvironmentContract.load();
  } on Object catch (error) {
    stderr.writeln(
      'render-environment precondition: cannot read the render-environment '
      'contract ($error). Refusing rather than defaulting: a precondition that '
      'guesses the value it could not read is the false assurance this tool '
      'exists to remove.',
    );
    exit(exitUsage);
  }

  final observed = probeRenderEnvironment();

  try {
    assertRenderEnvironment(contract: contract, observed: observed);
  } on RenderEnvironmentRefusal catch (refusal) {
    stderr.writeln(refusal.message);
    exit(exitRefusedToGrade);
  }

  stdout.writeln('render-environment precondition: OK.');
  stdout.write(renderEnvironmentReport(contract: contract, observed: observed));
  stdout.writeln(
    '  grading           meaningful — the baselines can be compared against a '
    'render taken here',
  );
  exit(exitPass);
}

const _usage = '''
usage: dart run test/tools/check_render_environment.dart

  Takes no arguments. Reads the render-environment contract from
  test/tools/golden_render_environment.json, measures the machine it is running
  on, and refuses to let anything be graded unless the two agree.

  Exit 0 when this runner is the contracted environment, 3 when it refuses to
  grade because the environment does not match, 2 when the environment could
  not be determined at all.
''';
