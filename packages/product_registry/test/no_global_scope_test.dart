import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

/// MP-AC-3 guard: authoritative domain logic must not acquire a mutable
/// process-global "current Product". Because there is no runtime way to prove
/// the absence of a singleton, this scans the package source. Documentation
/// and comments naming the anti-pattern are allowed; executable identifiers are
/// not.
void main() {
  test(
    'no currentProduct singleton in product_registry domain logic',
    () async {
      final entry = await Isolate.resolvePackageUri(
        Uri.parse('package:product_registry/product_registry.dart'),
      );
      expect(entry, isNotNull, reason: 'could not resolve package lib entry');
      final libDir = Directory(entry!.toFilePath()).parent;
      expect(libDir.existsSync(), isTrue);

      final pattern = RegExp(
        r'\b(currentProduct|CURRENT_PRODUCT|current_product)\b',
      );
      final offenders = <String>[];

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          if (pattern.hasMatch(line)) {
            offenders.add('${entity.path}:${i + 1}: ${line.trim()}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'MP-AC-3 violated — global Product scope found:\n'
            '${offenders.join('\n')}',
      );
    },
  );
}
