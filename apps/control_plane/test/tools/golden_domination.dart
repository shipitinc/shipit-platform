/// Grades a committed golden baseline against a fresh render, so "the golden
/// test passed" and "the baseline is current" stop being the same claim.
///
/// ## The failure this exists for
///
/// `helpers/golden_tolerance.dart` installs a comparator at threshold
/// `0.005`. Below that ratio it returns `true` and reports nothing. A
/// re-wrapped line of body copy lands around `0.003`, so a baseline left
/// behind by a copy change stays green indefinitely: the Product Detail
/// mobile baseline sat 0.3172% of 329160 pixels (peak channel delta 212) from
/// the current render while still painting a retired security guarantee to
/// any human golden reviewer.
///
/// The tolerance itself is not the defect and nothing here touches it. This
/// grades what the tolerance decided to hide.
///
/// ## The discriminator
///
/// "Changed a little, legitimately" and "stale and silent" are told apart by
/// rendering the corpus twice on the machine doing the checking:
///
///   * The **noise floor** is the largest deviation between those two
///     independent renders of the same source: what this machine genuinely
///     jitters by. It is measured, never assumed.
///   * At or below the floor, a baseline is [DominationVerdict.current] — it
///     matches what the code renders today as closely as this platform can be
///     expected to.
///   * Above the floor but within the comparator's tolerance, a baseline is
///     [DominationVerdict.toleranceDominated]. This is the silent case: the
///     golden tests pass it, and the pass is an artefact of the threshold.
///   * Above the tolerance it is [DominationVerdict.diverged]. The real
///     comparator already fails it; it is listed so the report is complete,
///     not because this rescues it.
///
/// Two structural failures are graded the same way, because both leave a
/// committed artefact that describes nothing: [DominationVerdict.orphanedBaseline]
/// and [DominationVerdict.missingBaseline].
///
/// Everything here reads bytes. It never writes to the baseline directory.
library;

import 'dart:io';

import 'png_pixel_diff.dart';

/// Path to the comparator whose tolerance this check grades against.
const comparatorPath = 'test/helpers/golden_tolerance.dart';

/// How a baseline is graded. Only [current] is acceptable.
enum DominationVerdict {
  /// Matches the current render to within this machine's own noise floor.
  current,

  /// Passes the golden comparator **only** because the ratio sits inside the
  /// tolerance while exceeding the noise floor.
  toleranceDominated,

  /// Beyond the comparator's tolerance, so the golden test itself fails.
  diverged,

  /// A committed baseline that nothing renders any more.
  orphanedBaseline,

  /// A frame the suite renders that has no committed baseline.
  missingBaseline,
}

/// Human-readable verdict names, used in the failure output.
String verdictLabel(DominationVerdict verdict) => switch (verdict) {
  DominationVerdict.current => 'CURRENT',
  DominationVerdict.toleranceDominated => 'TOLERANCE-DOMINATED',
  DominationVerdict.diverged => 'DIVERGED',
  DominationVerdict.orphanedBaseline => 'ORPHANED-BASELINE',
  DominationVerdict.missingBaseline => 'MISSING-BASELINE',
};

/// One baseline's measurement and its grade.
class GoldenReport {
  const GoldenReport({
    required this.file,
    required this.verdict,
    this.delta,
    this.detail = '',
  });

  final String file;
  final DominationVerdict verdict;
  final PixelDelta? delta;
  final String detail;

  bool get isClean => verdict == DominationVerdict.current;
}

/// Grades a measured ratio. [noiseFloor] is this machine's own render-to-render
/// deviation; [tolerance] is the golden comparator's threshold.
///
/// At exactly the noise floor the verdict is [DominationVerdict.current] — the
/// floor is the largest deviation legitimately attributable to the platform,
/// so a baseline sitting on it has not drifted.
DominationVerdict classify({
  required double ratio,
  required double noiseFloor,
  required double tolerance,
}) {
  if (ratio > tolerance) return DominationVerdict.diverged;
  if (ratio > noiseFloor) return DominationVerdict.toleranceDominated;
  return DominationVerdict.current;
}

/// Reads the threshold from the comparator so the two cannot drift apart.
///
/// A check pointed at a tolerance the comparator does not use would grade
/// against a fiction, so an unreadable comparator is a hard error rather than
/// a default.
double readComparatorThreshold({String path = comparatorPath}) {
  final source = _readOrThrow(path);
  final match = RegExp(
    r'double\s+threshold\s*=\s*([0-9]*\.?[0-9]+)',
  ).firstMatch(source);
  if (match == null) {
    throw StateError(
      'could not find `double threshold = <value>` in $path. Refusing to '
      'guess the comparator\'s tolerance.',
    );
  }
  return double.parse(match.group(1)!);
}

/// Fails closed unless the comparator is still a real pixel comparison.
///
/// If someone swaps in a comparator that returns true unconditionally, every
/// golden in this repository becomes unfalsifiable and the check below would
/// grade a fiction while reporting it as evidence.
void assertComparatorIsReal({String path = comparatorPath}) {
  final source = _readOrThrow(path);
  if (!source.contains('GoldenFileComparator.compareLists')) {
    throw StateError(
      '$path no longer calls GoldenFileComparator.compareLists. The golden '
      'comparator must keep doing a real pixel comparison; this check is a '
      'classification layer on top of it, not a replacement.',
    );
  }
}

/// Compares the two renders to get this machine's noise floor: the largest
/// ratio any single frame deviates between two independent renders of the same
/// source.
///
/// The maximum, not the mean — the bar for "legitimate" should be the strictest
/// frame in the corpus, not an average that hides one bad frame.
///
/// Only frames present in all three directories count. A frame missing from
/// the repeat render is reported as unmeasurable by the caller rather than
/// silently contributing a zero.
Map<String, PixelDelta> measureNoiseFloor({
  required Directory baseline,
  required Directory current,
  required Directory repeat,
}) {
  final result = <String, PixelDelta>{};
  for (final name in pngNames(current)) {
    if (!pngNames(repeat).contains(name)) continue;
    if (!File('${baseline.path}/$name').existsSync()) continue;
    result[name] = compareFrames(
      '${repeat.path}/$name',
      '${current.path}/$name',
    );
  }
  return result;
}

/// The largest ratio in [noiseByFile], and the file that produced it.
({double ratio, String file}) noiseFloorOf(
  Map<String, PixelDelta> noiseByFile,
) {
  var ratio = 0.0;
  var file = 'n/a';
  for (final entry in noiseByFile.entries) {
    if (entry.value.ratio > ratio) {
      ratio = entry.value.ratio;
      file = entry.key;
    }
  }
  return (ratio: ratio, file: file);
}

/// Grades every committed baseline in [baseline] against a fresh render.
///
/// Pure: reads the three directories, returns a report, touches nothing. The
/// CLI turns this into exit codes and prose.
List<GoldenReport> gradeGoldens({
  required Directory baseline,
  required Directory current,
  required Directory repeat,
  required double noiseFloor,
  required double tolerance,
}) {
  final baselineFiles = pngNames(baseline);
  final currentFiles = pngNames(current);
  final repeatFiles = pngNames(repeat);
  final reports = <GoldenReport>[];

  for (final name in baselineFiles) {
    if (!currentFiles.contains(name)) {
      reports.add(
        GoldenReport(
          file: name,
          verdict: DominationVerdict.orphanedBaseline,
          detail: 'no test renders this baseline any more',
        ),
      );
      continue;
    }
    if (!repeatFiles.contains(name)) {
      reports.add(
        GoldenReport(
          file: name,
          verdict: DominationVerdict.orphanedBaseline,
          detail: 'missing from the repeat render, so it cannot be graded',
        ),
      );
      continue;
    }
    final delta = compareFrames(
      '${baseline.path}/$name',
      '${current.path}/$name',
    );
    reports.add(
      GoldenReport(
        file: name,
        verdict: classify(
          ratio: delta.ratio,
          noiseFloor: noiseFloor,
          tolerance: tolerance,
        ),
        delta: delta,
      ),
    );
  }

  for (final name in currentFiles) {
    if (!baselineFiles.contains(name)) {
      reports.add(
        GoldenReport(
          file: name,
          verdict: DominationVerdict.missingBaseline,
          detail: 'rendered by the suite but never committed',
        ),
      );
    }
  }

  reports.sort((a, b) {
    final byVerdict = b.verdict.index.compareTo(a.verdict.index);
    if (byVerdict != 0) return byVerdict;
    final byRatio = (b.delta?.ratio ?? 0).compareTo(a.delta?.ratio ?? 0);
    if (byRatio != 0) return byRatio;
    return a.file.compareTo(b.file);
  });
  return reports;
}

/// Sorted `.png` names in [dir].
List<String> pngNames(Directory dir) {
  final names =
      dir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.png'))
          .toList()
        ..sort();
  return names;
}

String _readOrThrow(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('cannot read $path');
  }
  return file.readAsStringSync();
}
