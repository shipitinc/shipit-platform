/// Tests for the tolerance-domination grading layer.
///
/// These run in the normal `flutter test` suite, so the tooling that decides
/// whether a golden baseline is trustworthy is itself covered by the suite
/// that trusts it. A check nobody tests is a check nobody can rely on.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'golden_domination.dart';
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
    test('is zero when two renders of the same source agree exactly', () {
      final noise = measureNoiseFloor(
        baseline: Directory(goldens.path),
        current: Directory(goldens.path),
        repeat: Directory(goldens.path),
      );
      expect(noise, hasLength(54));
      expect(noiseFloorOf(noise).ratio, 0);
    });

    test('names the frame that produced it', () {
      final noise = measureNoiseFloor(
        baseline: Directory(goldens.path),
        current: Directory(goldens.path),
        repeat: Directory(goldens.path),
      );
      expect(noiseFloorOf(noise).file, 'n/a');
    });
  });
}

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
