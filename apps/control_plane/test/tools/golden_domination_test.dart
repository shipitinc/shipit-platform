/// Tests for the tolerance-domination grading layer.
///
/// These run in the normal `flutter test` suite, so the tooling that decides
/// whether a golden baseline is trustworthy is itself covered by the suite
/// that trusts it. A check nobody tests is a check nobody can rely on.
///
/// ## Why the noise-floor group is built out of synthesised frames
///
/// The noise floor is the largest deviation between two independent renders of
/// the same source. Testing it properly means two *different* render
/// directories, because `measureNoiseFloor` compares `current` against `repeat`:
/// pass a single directory as both and `compareFrames(path, path)` short-circuits
/// to byte-identical, the floor is 0, and the assertion holds no matter what
/// the platform does. That version of these tests could not fail.
///
/// So the frames here are synthesised — written to two distinct directories,
/// made to differ by a known number of rows — and the measurement is asserted
/// against that known difference. They cost no renders.
///
/// What these tests do **not** claim, deliberately: that this platform renders
/// deterministically. That claim needs two real renders, which would triple an
/// already 40-second suite. It is enforced where two real renders already
/// happen — the `golden-integrity` CI job measures the floor and the render
/// environment contract refuses to grade if it is non-zero there
/// (`golden_render_environment.dart`, `maxNoiseFloorRatio`).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'check_golden_domination.dart';
import 'golden_domination.dart';
import 'golden_render_environment.dart';
import 'png_pixel_diff.dart';

void main() {
  final goldens = Directory('test/goldens');
  final comparator = File(comparatorPath);

  group('the comparator this check grades against', () {
    test('is present and still performs a real pixel comparison', () {
      expect(comparator.existsSync(), isTrue, reason: comparatorPath);
      expect(() => assertComparatorIsReal(), returnsNormally);
    });

    test('declares the threshold this check must grade against', () {
      // Pinned deliberately. If someone widens the tolerance, the number the
      // silent-pass window is measured in changes, and this test is where that
      // has to be noticed and argued about.
      expect(readComparatorThreshold(), 0.005);
    });

    test('is classified as real rather than silently passing everything', () {
      // A comparator that returned true unconditionally would make every
      // golden unfalsifiable. assertComparatorIsReal must reject that.
      final dir = Directory.systemTemp.createTempSync('domination_comparator');
      addTearDown(() => dir.deleteSync(recursive: true));
      final fake = File('${dir.path}/golden_tolerance.dart')
        ..writeAsStringSync('class C { bool compare() => true; }');
      expect(
        () => assertComparatorIsReal(path: fake.path),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('decodePng', () {
    test('reads the corpus dimensions the goldens actually use', () {
      expect(goldens.existsSync(), isTrue);
      final frames = <String, RgbaFrame>{};
      for (final name in pngNames(goldens)) {
        frames[name] = decodePng('${goldens.path}/$name');
      }
      expect(frames, hasLength(54));
      // Verified across all 54: 8-bit non-interlaced RGBA, three sizes.
      expect(frames['all_work_light.png']!.width, 1280);
      expect(frames['all_work_light.png']!.height, 900);
      expect(frames['defect_list_empty_mobile.png']!.width, 390);
      expect(frames['defect_list_empty_mobile.png']!.height, 844);
      expect(frames['create_defect_mobile.png']!.height, 1080);
      for (final frame in frames.values) {
        expect(frame.pixels.length, frame.pixelCount * 4);
      }
    });

    test('names the file it could not read rather than skipping it', () {
      final dir = Directory.systemTemp.createTempSync('domination_png');
      addTearDown(() => dir.deleteSync(recursive: true));
      final junk = File('${dir.path}/not_a_golden.png')
        ..writeAsStringSync('this is not a png');
      expect(
        () => decodePng(junk.path),
        throwsA(
          isA<GoldenImageException>().having((e) => e.path, 'path', junk.path),
        ),
      );
    });
  });

  group('compareFrames', () {
    test('reports zero for a file compared with itself', () {
      final path = '${goldens.path}/all_work_light.png';
      final delta = compareFrames(path, path);
      expect(delta.byteIdentical, isTrue);
      expect(delta.ratio, 0);
      expect(delta.differingPixels, 0);
    });

    test('measures a real difference rather than asserting one', () {
      final dir = Directory.systemTemp.createTempSync('domination_delta');
      addTearDown(() => dir.deleteSync(recursive: true));
      final a = File('${dir.path}/a.png')
        ..writeAsBytesSync(
          File('${goldens.path}/all_work_light.png').readAsBytesSync(),
        );
      // Same dimensions, every pixel of row 10 changed to opaque black.
      final frame = decodePng(a.path);
      final mutated = Uint8List.fromList(frame.pixels);
      for (var x = 0; x < frame.width; x++) {
        final i = (10 * frame.width + x) * 4;
        mutated[i] = 0;
        mutated[i + 1] = 0;
        mutated[i + 2] = 0;
        mutated[i + 3] = 255;
      }
      final b = File('${dir.path}/b.png')
        ..writeAsBytesSync(_encodePng(frame.width, frame.height, mutated));
      final delta = compareFrames(a.path, b.path);
      expect(delta.byteIdentical, isFalse);
      expect(delta.differingPixels, frame.width);
      expect(delta.totalPixels, frame.pixelCount);
      expect(delta.ratio, closeTo(1 / frame.height, 1e-9));
      expect(delta.peakChannelDelta, greaterThan(0));
    });
  });

  group('classify', () {
    const tolerance = 0.005;

    test('a baseline at or below the noise floor is current', () {
      expect(
        classify(ratio: 0, noiseFloor: 0.0001, tolerance: tolerance),
        DominationVerdict.current,
      );
      expect(
        classify(ratio: 0.0001, noiseFloor: 0.0001, tolerance: tolerance),
        DominationVerdict.current,
      );
    });

    test('the measured Product Detail drift is tolerance-dominated', () {
      // 0.3172% of 329160 px — under the 0.5% tolerance, over a zero noise
      // floor. This is the exact case that reported PASS while the baseline
      // painted a retired security claim.
      expect(
        classify(ratio: 0.003172, noiseFloor: 0, tolerance: tolerance),
        DominationVerdict.toleranceDominated,
      );
    });

    test('a real change beyond the tolerance is diverged, not hidden', () {
      expect(
        classify(ratio: 0.02, noiseFloor: 0, tolerance: tolerance),
        DominationVerdict.diverged,
      );
    });

    test('only current is clean', () {
      for (final verdict in DominationVerdict.values) {
        final report = GoldenReport(
          file: 'x.png',
          verdict: verdict,
          delta: const PixelDelta.zero(width: 1, height: 1),
        );
        expect(
          report.isClean,
          verdict == DominationVerdict.current,
          reason: verdict.name,
        );
      }
    });
  });

  group('gradeGoldens', () {
    late Directory a;
    late Directory b;
    late Directory c;

    setUp(() {
      a = Directory.systemTemp.createTempSync('domination_a');
      b = Directory.systemTemp.createTempSync('domination_b');
      c = Directory.systemTemp.createTempSync('domination_c');
    });

    tearDown(() {
      for (final d in [a, b, c]) {
        d.deleteSync(recursive: true);
      }
    });

    void seed(Directory dir, String name, int blackRow) {
      final source = '${goldens.path}/defect_list_empty_mobile.png';
      final frame = decodePng(source);
      final pixels = Uint8List.fromList(frame.pixels);
      if (blackRow >= 0) {
        for (var x = 0; x < frame.width; x++) {
          final i = (blackRow * frame.width + x) * 4;
          pixels[i] = 0;
          pixels[i + 1] = 0;
          pixels[i + 2] = 0;
        }
      }
      File(
        '${dir.path}/$name',
      ).writeAsBytesSync(_encodePng(frame.width, frame.height, pixels));
    }

    test('grades a stale baseline as tolerance-dominated, naming the file', () {
      // baseline: one row black. renders: identical to each other.
      seed(a, 'stale.png', 10);
      seed(b, 'stale.png', -1);
      seed(c, 'stale.png', -1);

      final reports = gradeGoldens(
        baseline: a,
        current: b,
        repeat: c,
        noiseFloor: 0,
        tolerance: 0.005,
      );
      expect(reports, hasLength(1));
      expect(reports.single.file, 'stale.png');
      expect(reports.single.verdict, DominationVerdict.toleranceDominated);
      expect(reports.single.delta!.ratio, closeTo(1 / 844, 1e-9));
      expect(reports.single.isClean, isFalse);
    });

    test('grades a matching baseline as current', () {
      seed(a, 'fresh.png', -1);
      seed(b, 'fresh.png', -1);
      seed(c, 'fresh.png', -1);
      final reports = gradeGoldens(
        baseline: a,
        current: b,
        repeat: c,
        noiseFloor: 0,
        tolerance: 0.005,
      );
      expect(reports.single.verdict, DominationVerdict.current);
      expect(reports.single.isClean, isTrue);
    });

    test('flags a baseline nothing renders any more', () {
      seed(a, 'orphan.png', -1);
      seed(b, 'other.png', -1);
      seed(c, 'other.png', -1);
      final reports = gradeGoldens(
        baseline: a,
        current: b,
        repeat: c,
        noiseFloor: 0,
        tolerance: 0.005,
      );
      // Both directions are structural failures: the baseline describes
      // nothing, and the rendered frame has nothing describing it.
      expect(reports, hasLength(2));
      expect(
        reports.map((r) => r.file),
        containsAll(['orphan.png', 'other.png']),
      );
      final orphan = reports.firstWhere((r) => r.file == 'orphan.png');
      expect(orphan.verdict, DominationVerdict.orphanedBaseline);
    });

    test('flags a rendered frame with no committed baseline', () {
      seed(a, 'kept.png', -1);
      seed(b, 'kept.png', -1);
      seed(c, 'kept.png', -1);
      seed(b, 'uncommitted.png', -1);
      seed(c, 'uncommitted.png', -1);
      final reports = gradeGoldens(
        baseline: a,
        current: b,
        repeat: c,
        noiseFloor: 0,
        tolerance: 0.005,
      );
      expect(reports, hasLength(2));
      final missing = reports.firstWhere(
        (r) => r.verdict == DominationVerdict.missingBaseline,
      );
      expect(missing.file, 'uncommitted.png');
    });
  });

  group('noise floor', () {
    // Four genuinely separate directories. `current` and `repeat` are two
    // different renders; `baseline` holds the committed bytes and is present so
    // `measureNoiseFloor` sees the frames at all. Only `current` vs `repeat`
    // decides the floor — that is what these tests hold to account.
    late Directory baseline;
    late Directory pass1;
    late Directory pass2;

    setUp(() {
      baseline = Directory.systemTemp.createTempSync('domination_nf_baseline');
      pass1 = Directory.systemTemp.createTempSync('domination_nf_pass1');
      pass2 = Directory.systemTemp.createTempSync('domination_nf_pass2');
    });

    tearDown(() {
      for (final d in [baseline, pass1, pass2]) {
        d.deleteSync(recursive: true);
      }
    });

    /// Writes the corpus baseline for [name] into every directory, with
    /// [blackRows] blackened in `pass2` only — i.e. `pass2` is the render that
    /// drifted from `pass1`.
    void seedFrame(String name, {List<int> blackRows = const []}) {
      final clean = _frameBytes(goldens.path);
      final jittered = Uint8List.fromList(clean.pixels);
      for (final row in blackRows) {
        _blackenRow(jittered, clean, row);
      }
      _writeFrame(baseline, name, clean.width, clean.height, clean.pixels);
      _writeFrame(pass1, name, clean.width, clean.height, clean.pixels);
      _writeFrame(
        pass2,
        name,
        clean.width,
        clean.height,
        blackRows.isEmpty ? clean.pixels : jittered,
      );
    }

    test(
      'measures a real deviation between two different renders and names the frame',
      () {
        // The frame that actually drifted. Without this, every variant of this
        // group below is trivially satisfied by a directory compared with itself.
        final frame = _frameBytes(goldens.path);
        final row = _nthColouredRow(frame, 0);
        seedFrame('steady.png');
        seedFrame('jittery.png', blackRows: [row]);

        final noise = measureNoiseFloor(
          baseline: baseline,
          current: pass1,
          repeat: pass2,
        );
        expect(noise.keys.toSet(), {'steady.png', 'jittery.png'});

        final worst = noiseFloorOf(noise);
        expect(
          worst.file,
          'jittery.png',
          reason: 'the drifted frame must be named, not averaged away',
        );
        expect(worst.ratio, closeTo(1 / frame.height, 1e-9));
        expect(noise['steady.png']!.ratio, 0);
        expect(noise['steady.png']!.byteIdentical, isTrue);
      },
    );

    test('takes the worst frame, not an average', () {
      final frame = _frameBytes(goldens.path);
      seedFrame('a.png');
      seedFrame('b.png');
      seedFrame('c.png');
      seedFrame(
        'worst.png',
        blackRows: [_nthColouredRow(frame, 0), _nthColouredRow(frame, 1)],
      );

      final worst = noiseFloorOf(
        measureNoiseFloor(baseline: baseline, current: pass1, repeat: pass2),
      );
      // One frame out of four at 2/844. A mean would report 0.5/844 and pass
      // a loose bar; the whole point of a floor is the strictest frame.
      expect(worst.file, 'worst.png');
      expect(worst.ratio, closeTo(2 / frame.height, 1e-9));
    });

    test(
      'is zero between two separate render directories that agree byte-for-byte',
      () {
        seedFrame('one.png');
        seedFrame('two.png');

        // The directories are distinct objects holding identical bytes. This is
        // the shape of the real measurement (floor == 0 on the rendering
        // machine), but as a test it asserts that the measurement sees agreeing
        // renders as zero — it does not assert anything about this platform.
        expect(pass1.path, isNot(pass2.path));
        final noise = measureNoiseFloor(
          baseline: baseline,
          current: pass1,
          repeat: pass2,
        );
        expect(noise, hasLength(2));
        expect(noiseFloorOf(noise).ratio, 0);
        expect(noiseFloorOf(noise).file, 'n/a');
      },
    );

    test(
      'excludes a frame the repeat render never produced instead of counting it as zero',
      () {
        seedFrame('present.png');
        seedFrame('missing_from_repeat.png');
        File('${pass2.path}/missing_from_repeat.png').deleteSync();

        final noise = measureNoiseFloor(
          baseline: baseline,
          current: pass1,
          repeat: pass2,
        );
        // A frame that one render did not produce is unmeasurable. Folding it in
        // as a zero would dilute the floor with a frame nobody compared.
        expect(noise.keys, ['present.png']);
      },
    );

    test('excludes a frame that has no committed baseline', () {
      seedFrame('committed.png');
      _writeFrame(
        pass1,
        'uncommitted.png',
        _frameBytes(goldens.path).width,
        _frameBytes(goldens.path).height,
        _frameBytes(goldens.path).pixels,
      );
      _writeFrame(
        pass2,
        'uncommitted.png',
        _frameBytes(goldens.path).width,
        _frameBytes(goldens.path).height,
        _frameBytes(goldens.path).pixels,
      );

      final noise = measureNoiseFloor(
        baseline: baseline,
        current: pass1,
        repeat: pass2,
      );
      expect(noise.keys, ['committed.png']);
    });
  });

  group('runGoldenDominationCheck', () {
    // The contract is loaded from its committed path inside the check, and the
    // request carries no way to substitute another one — so these tests derive
    // a "matching" observed environment from the committed contract and let the
    // contract change without silently invalidating them.
    late RenderEnvironmentContract contract;
    late Directory baseline;
    late Directory pass1;
    late Directory pass2;

    setUpAll(() {
      contract = RenderEnvironmentContract.load();
    });

    setUp(() {
      baseline = Directory.systemTemp.createTempSync('domination_chk_baseline');
      pass1 = Directory.systemTemp.createTempSync('domination_chk_pass1');
      pass2 = Directory.systemTemp.createTempSync('domination_chk_pass2');
    });

    tearDown(() {
      for (final d in [baseline, pass1, pass2]) {
        d.deleteSync(recursive: true);
      }
    });

    ObservedEnvironment environmentMatching([RenderEnvironmentContract? c]) {
      final effective = c ?? contract;
      return ObservedEnvironment(
        osFamily: effective.osFamily,
        osVersion: effective.renderedOsVersion ?? '${effective.osMajor}.0.0',
        osMajor: effective.osMajor,
        architecture: effective.architecture,
        flutterVersion: effective.flutterVersion,
      );
    }

    /// A runner that matches on nothing: a different OS major, a different
    /// architecture and a different Flutter patch.
    ObservedEnvironment environmentMismatched() => const ObservedEnvironment(
      osFamily: 'macos',
      osVersion: '14.7.1',
      osMajor: 14,
      architecture: 'x64',
      flutterVersion: '3.44.0',
    );

    GoldenCheckRequest request({required ObservedEnvironment observed}) =>
        GoldenCheckRequest(
          baseline: baseline,
          current: pass1,
          repeat: pass2,
          tolerance: readComparatorThreshold(),
          observed: observed,
        );

    /// One committed baseline that is a row behind what both renders produce.
    void seedStaleCorpus() {
      final frame = _frameBytes(goldens.path);
      final clean = frame.pixels;
      final stale = Uint8List.fromList(clean);
      _blackenRow(stale, frame, _nthColouredRow(frame, 0));
      _writeFrame(baseline, 'stale.png', frame.width, frame.height, stale);
      _writeFrame(pass1, 'stale.png', frame.width, frame.height, clean);
      _writeFrame(pass2, 'stale.png', frame.width, frame.height, clean);
    }

    test(
      'grades on the contracted environment and fails the stale baseline',
      () {
        seedStaleCorpus();
        final outcome = runGoldenDominationCheck(
          request(observed: environmentMatching()),
        );
        expect(outcome.exitCode, exitDirty);
        expect(outcome.reports, hasLength(1));
        expect(outcome.reports.single.file, 'stale.png');
        expect(
          outcome.reports.single.verdict,
          DominationVerdict.toleranceDominated,
        );
        expect(outcome.transcript, contains('FAIL: 1 of 1 baselines'));
      },
    );

    test('passes when the contracted environment and the corpus agree', () {
      final frame = _frameBytes(goldens.path);
      for (final dir in [baseline, pass1, pass2]) {
        _writeFrame(dir, 'fresh.png', frame.width, frame.height, frame.pixels);
      }
      final outcome = runGoldenDominationCheck(
        request(observed: environmentMatching()),
      );
      expect(outcome.exitCode, exitPass);
      expect(outcome.transcript, contains('PASS: 1 of 1 baselines'));
    });

    test(
      'refuses to grade on a mismatched environment, and emits no verdict',
      () {
        // The same stale corpus that produced a FAIL above. On a runner that is
        // not the rendering environment the run must produce NO grading output at
        // all: zero reports, nothing on stdout, and a refusal instead. That is
        // the "before it grades anything" claim, executed rather than asserted.
        seedStaleCorpus();
        final outcome = runGoldenDominationCheck(
          request(observed: environmentMismatched()),
        );

        expect(outcome.exitCode, exitRefusedToGrade);
        expect(outcome.refusedToGrade, isTrue);
        expect(outcome.reports, isEmpty);
        expect(outcome.output, isEmpty, reason: 'no verdict block was printed');
        expect(outcome.transcript, contains('REFUSING TO GRADE'));
        expect(outcome.transcript, isNot(contains('FAIL:')));
        expect(outcome.transcript, isNot(contains('PASS:')));
      },
    );

    test('names every mismatched axis with expected and observed', () {
      seedStaleCorpus();
      final outcome = runGoldenDominationCheck(
        request(observed: environmentMismatched()),
      );
      final text = outcome.transcript;
      expect(text, contains('os major'));
      expect(text, contains('26.x'));
      expect(text, contains('14.x'));
      expect(text, contains('architecture'));
      expect(text, contains('arm64'));
      expect(text, contains('x64'));
      expect(text, contains('flutter'));
      expect(text, contains('3.44.7'));
      expect(text, contains('3.44.0'));
      expect(text, contains('this runner'));
      expect(text, contains(defaultContractPath));
    });

    test(
      'refuses when the contracted environment stops rendering byte-stably',
      () {
        // The executable form of the noise-floor finding: on the environment that
        // produced the baselines, two renders of the same source must agree
        // exactly. Here pass2 drifts from pass1 by one row, so the run refuses
        // rather than quietly reclassifying a changed machine as noise.
        final frame = _frameBytes(goldens.path);
        final jittered = Uint8List.fromList(frame.pixels);
        _blackenRow(jittered, frame, _nthColouredRow(frame, 0));
        for (final dir in [baseline, pass1]) {
          _writeFrame(dir, 'f.png', frame.width, frame.height, frame.pixels);
        }
        _writeFrame(pass2, 'f.png', frame.width, frame.height, jittered);

        final outcome = runGoldenDominationCheck(
          request(observed: environmentMatching()),
        );
        expect(outcome.exitCode, exitRefusedToGrade);
        expect(outcome.reports, isEmpty);
        expect(outcome.transcript, contains('REFUSING TO GRADE'));
        expect(outcome.transcript, contains('f.png'));
      },
    );

    test('refuses when it cannot read the comparator, before grading', () {
      seedStaleCorpus();
      final outcome = runGoldenDominationCheck(
        GoldenCheckRequest(
          baseline: baseline,
          current: pass1,
          repeat: pass2,
          tolerance: readComparatorThreshold(),
          observed: environmentMatching(),
          comparatorSourcePath: '${baseline.path}/no_such_comparator.dart',
        ),
      );
      expect(outcome.exitCode, exitUsage);
      expect(outcome.reports, isEmpty);
    });

    test('refuses when the baseline directory is missing', () {
      final outcome = runGoldenDominationCheck(
        GoldenCheckRequest(
          baseline: Directory('${baseline.path}/absent'),
          current: pass1,
          repeat: pass2,
          tolerance: readComparatorThreshold(),
          observed: environmentMatching(),
        ),
      );
      expect(outcome.exitCode, exitUsage);
      expect(outcome.transcript, contains('no such directory'));
    });
  });
}

/// The real corpus frame these tests synthesise from: 390x844, so one blackened
/// row is exactly `1 / 844` of the frame and two are `2 / 844`.
RgbaFrame _frameBytes(String goldensPath) =>
    decodePng('$goldensPath/defect_list_empty_mobile.png');

/// Sets one row's RGB to zero in place.
///
/// Only meaningful on a row that actually carries colour, which is why the
/// tests pick rows through [_nthColouredRow]: that makes "this changed exactly
/// `width` pixels" a claim about the fixture rather than a coincidence.
void _blackenRow(Uint8List pixels, RgbaFrame frame, int row) {
  for (var x = 0; x < frame.width; x++) {
    final i = (row * frame.width + x) * 4;
    pixels[i] = 0;
    pixels[i + 1] = 0;
    pixels[i + 2] = 0;
  }
}

/// The [n]-th scanline that carries at least one non-black pixel.
int _nthColouredRow(RgbaFrame frame, int n) {
  var seen = 0;
  for (var y = 0; y < frame.height; y++) {
    for (var x = 0; x < frame.width; x++) {
      final i = (y * frame.width + x) * 4;
      if (frame.pixels[i] != 0 ||
          frame.pixels[i + 1] != 0 ||
          frame.pixels[i + 2] != 0) {
        if (seen == n) return y;
        seen++;
        break;
      }
    }
  }
  throw StateError(
    'frame has fewer than ${n + 1} coloured scanlines; cannot pick a row that '
    'blackening would change',
  );
}

void _writeFrame(
  Directory dir,
  String name,
  int width,
  int height,
  Uint8List pixels,
) => File(
  '${dir.path}/$name',
).writeAsBytesSync(_encodePng(width, height, pixels));

/// Minimal RGBA PNG encoder, used only to synthesise fixtures.
///
/// Deliberately dependency-free and deliberately tiny: the decoder under test
/// is dependency-free for the same reason, and a fixture written by the same
/// encoder that reads it would be circular for anything but the unfilter path.
List<int> _encodePng(int width, int height, Uint8List rgba) {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter: None
    raw.add(rgba.sublist(y * width * 4, (y + 1) * width * 4));
  }

  final out = BytesBuilder();
  out.add(const <int>[137, 80, 78, 71, 13, 10, 26, 10]);

  final ihdr = BytesBuilder();
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6) // colour type RGBA
    ..setUint8(10, 0) // compression
    ..setUint8(11, 0) // filter
    ..setUint8(12, 0); // interlace
  ihdr.add(header.buffer.asUint8List());
  _chunk(out, 'IHDR', ihdr.takeBytes());
  _chunk(out, 'IDAT', ZLibCodec().encode(raw.takeBytes()));
  _chunk(out, 'IEND', const <int>[]);
  return out.takeBytes();
}

void _chunk(BytesBuilder out, String type, List<int> data) {
  final length = ByteData(4)..setUint32(0, data.length);
  out.add(length.buffer.asUint8List());
  out.add(type.codeUnits);
  out.add(data);
  final crc = ByteData(4)..setUint32(0, _crc32([...type.codeUnits, ...data]));
  out.add(crc.buffer.asUint8List());
}

/// CRC-32 as PNG defines it, table-free because this runs a handful of times.
int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >>> 1) ^ 0xEDB88320 : crc >>> 1;
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
