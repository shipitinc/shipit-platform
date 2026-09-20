import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Allows a small pixel-difference ratio when comparing goldens.
///
/// Text rasterisation on this platform is not bit-stable between runs: the
/// same widget tree, fonts and surface size produce diffs in the 0.03%–0.3%
/// range purely from glyph anti-aliasing. With an exact comparator those runs
/// fail intermittently, which trains everyone to ignore golden failures — the
/// opposite of what the check is for.
///
/// [_threshold] is set well above the observed noise floor and far below any
/// real change: a shifted row, a wrong colour or a changed string moves whole
/// percentage points of the frame.
class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(super.testFile, this._threshold);

  final double _threshold;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (result.passed || result.diffPercent <= _threshold) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

/// Installs the tolerant comparator for the current test file.
///
/// Must run inside `setUpAll` so it inherits the per-file base directory that
/// `flutter_test` has already resolved; golden paths are relative to the test
/// file, so the base directory cannot be hard-coded.
void useTolerantGoldens({double threshold = 0.005}) {
  final existing = goldenFileComparator;
  if (existing is! LocalFileComparator) return;
  goldenFileComparator = _TolerantGoldenComparator(
    existing.basedir.resolve('golden_tolerance_anchor_test.dart'),
    threshold,
  );
}
