/// Dependency-free PNG reader and per-pixel comparator for golden baselines.
///
/// This is the **classification layer** that sits on top of the golden
/// comparator, not a replacement for it. [helpers/golden_tolerance.dart] still
/// runs the real byte/pixel comparison on every golden; this library is what
/// turns "the comparator said pass" into a *number*, so a pass can be graded
/// instead of believed.
///
/// ## Why a hand-rolled decoder
///
/// The comparison has to run as a plain `dart run` tool in CI, outside
/// `flutter test`, so it cannot rely on `flutter_test`'s comparator or on
/// `dart:ui`. Every baseline in `test/goldens` is 8-bit non-interlaced
/// RGBA (PNG colour type 6) — verified across all 54 — and `dart:io` already
/// ships a zlib inflate. That is the whole requirement, so the decoder is
/// ~120 lines instead of a new package dependency that would change
/// `pubspec.lock` for every consumer of this app.
///
/// Any input this decoder does not understand is a hard error with the file
/// named. A check that silently skipped a file it could not read would report
/// a clean corpus while having measured nothing.
library;

import 'dart:io';
import 'dart:typed_data';

/// The measured difference between two rendered frames.
class PixelDelta {
  const PixelDelta({
    required this.width,
    required this.height,
    required this.differingPixels,
    required this.totalPixels,
    required this.peakChannelDelta,
    required this.byteIdentical,
  });

  /// A zero delta, for a frame that is byte-identical to its baseline.
  const PixelDelta.zero({required this.width, required this.height})
    : differingPixels = 0,
      totalPixels = 0,
      peakChannelDelta = 0,
      byteIdentical = true;

  final int width;
  final int height;

  /// Pixels whose RGBA differs by at least one in any channel.
  final int differingPixels;

  /// Total pixels compared. Zero when [byteIdentical] short-circuited.
  final int totalPixels;

  /// Largest absolute single-channel difference seen, 0..255.
  final int peakChannelDelta;

  /// True when the two files were compared as bytes and found equal, so no
  /// decode was needed. The delta is then exactly zero by definition.
  final bool byteIdentical;

  /// Fraction of differing pixels, in the same units the golden comparator
  /// reports as `diffPercent`. Zero rather than NaN when [byteIdentical].
  double get ratio =>
      byteIdentical || totalPixels == 0 ? 0 : differingPixels / totalPixels;

  @override
  String toString() =>
      '${(ratio * 100).toStringAsFixed(4)}% '
      '($differingPixels/$totalPixels px, peak channel delta $peakChannelDelta)';
}

/// A decoded 8-bit RGBA frame.
class RgbaFrame {
  const RgbaFrame({
    required this.width,
    required this.height,
    required this.pixels,
  });

  final int width;
  final int height;

  /// Row-major, 4 bytes per pixel.
  final Uint8List pixels;

  int get pixelCount => width * height;
}

const _signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];

/// Raised when a baseline cannot be decoded, so the caller can name the file
/// rather than counting it as clean.
class GoldenImageException implements Exception {
  GoldenImageException(this.path, this.reason);

  final String path;
  final String reason;

  @override
  String toString() => '$path: $reason';
}

/// Reads an 8-bit non-interlaced PNG and returns its RGBA pixels.
///
/// Supports colour type 2 (RGB) and 6 (RGBA) at bit depth 8, which is the
/// whole golden corpus. Anything else fails loudly.
RgbaFrame decodePng(String path) {
  final bytes = File(path).readAsBytesSync();

  if (bytes.length < 8) {
    throw GoldenImageException(path, 'file is shorter than a PNG signature');
  }
  for (var i = 0; i < _signature.length; i++) {
    if (bytes[i] != _signature[i]) {
      throw GoldenImageException(path, 'not a PNG (bad signature)');
    }
  }

  final data = ByteData.sublistView(bytes);
  var offset = 8;
  int? width;
  int? height;
  int? bitDepth;
  int? colourType;
  int? interlace;
  final compressed = BytesBuilder(copy: false);

  while (offset + 8 <= bytes.length) {
    final length = data.getUint32(offset);
    final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
    final start = offset + 8;
    final end = start + length;
    if (end + 4 > bytes.length) {
      throw GoldenImageException(path, 'chunk $type runs past end of file');
    }

    switch (type) {
      case 'IHDR':
        width = data.getUint32(start);
        height = data.getUint32(start + 4);
        bitDepth = bytes[start + 8];
        colourType = bytes[start + 9];
        interlace = bytes[start + 12];
      case 'IDAT':
        compressed.add(bytes.sublist(start, end));
      case 'IEND':
        offset = bytes.length;
        continue;
    }
    offset = end + 4; // skip the CRC
  }

  if (width == null || height == null) {
    throw GoldenImageException(path, 'no IHDR chunk');
  }
  if (bitDepth != 8) {
    throw GoldenImageException(
      path,
      'unsupported bit depth $bitDepth (need 8)',
    );
  }
  if (colourType != 2 && colourType != 6) {
    throw GoldenImageException(
      path,
      'unsupported colour type $colourType (need 2 RGB or 6 RGBA)',
    );
  }
  if (interlace != 0) {
    throw GoldenImageException(path, 'interlaced PNG is not supported');
  }

  final bytesPerPixel = colourType == 6 ? 4 : 3;
  final inflated = ZLibCodec().decode(compressed.takeBytes());
  return _unfilter(
    path,
    Uint8List.fromList(inflated),
    width,
    height,
    bytesPerPixel,
  );
}

/// Reverses the per-scanline PNG filters, widening RGB to RGBA.
RgbaFrame _unfilter(
  String path,
  Uint8List raw,
  int width,
  int height,
  int bytesPerPixel,
) {
  final stride = width * bytesPerPixel;
  if (raw.length < height * (stride + 1)) {
    throw GoldenImageException(
      path,
      'inflated data is ${raw.length} bytes, need at least '
      '${height * (stride + 1)}',
    );
  }

  final out = Uint8List(width * height * 4);
  var previous = Uint8List(stride);
  var position = 0;

  for (var y = 0; y < height; y++) {
    final filter = raw[position++];
    final line = Uint8List.fromList(raw.sublist(position, position + stride));
    position += stride;

    for (var x = 0; x < stride; x++) {
      final a = x >= bytesPerPixel ? line[x - bytesPerPixel] : 0;
      final b = previous[x];
      final c = x >= bytesPerPixel ? previous[x - bytesPerPixel] : 0;
      int value;
      switch (filter) {
        case 0:
          value = line[x];
        case 1:
          value = line[x] + a;
        case 2:
          value = line[x] + b;
        case 3:
          value = line[x] + ((a + b) >> 1);
        case 4:
          value = line[x] + _paeth(a, b, c);
        default:
          throw GoldenImageException(
            path,
            'unknown scanline filter $filter on row $y',
          );
      }
      line[x] = value & 0xFF;
    }

    final rowStart = y * stride;
    final outStart = y * stride;
    if (bytesPerPixel == 4) {
      out.setRange(outStart, outStart + stride, line);
    } else {
      for (var x = 0, o = 0; x < width; x++, o += 4) {
        final i = rowStart + x * 3;
        out[outStart + o] = line[i];
        out[outStart + o + 1] = line[i + 1];
        out[outStart + o + 2] = line[i + 2];
        out[outStart + o + 3] = 0xFF;
      }
    }
    previous = line;
  }

  return RgbaFrame(width: width, height: height, pixels: out);
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs();
  final pb = (p - b).abs();
  final pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

/// Compares two frames pixel by pixel.
///
/// A pixel counts as differing when any of its four channels differs by at
/// least one, and [PixelDelta.peakChannelDelta] records the worst single
/// channel seen — which is what separates a re-wrapped line of text (a large
/// peak over few pixels) from uniform anti-aliasing noise (a small peak over
/// many).
PixelDelta compareFrames(String baselinePath, String currentPath) {
  final baselineBytes = File(baselinePath).readAsBytesSync();
  final currentBytes = File(currentPath).readAsBytesSync();

  // The common case. A golden regenerated from unchanged source is byte-stable
  // on this platform, so this skips the decode entirely — and, just as
  // importantly, defines the zero delta exactly rather than approximately.
  if (_sameBytes(baselineBytes, currentBytes)) {
    final frame = decodePng(baselinePath);
    return PixelDelta.zero(width: frame.width, height: frame.height);
  }

  final a = decodePng(baselinePath);
  final b = decodePng(currentPath);
  if (a.width != b.width || a.height != b.height) {
    return PixelDelta(
      width: b.width,
      height: b.height,
      differingPixels: b.pixelCount,
      totalPixels: b.pixelCount,
      peakChannelDelta: 255,
      byteIdentical: false,
    );
  }

  var differing = 0;
  var peak = 0;
  for (var i = 0; i < a.pixels.length; i += 4) {
    var pixelDiffers = false;
    for (var c = 0; c < 4; c++) {
      final d = (a.pixels[i + c] - b.pixels[i + c]).abs();
      if (d != 0) {
        pixelDiffers = true;
        if (d > peak) peak = d;
      }
    }
    if (pixelDiffers) differing++;
  }

  return PixelDelta(
    width: a.width,
    height: a.height,
    differingPixels: differing,
    totalPixels: a.pixelCount,
    peakChannelDelta: peak,
    byteIdentical: false,
  );
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
