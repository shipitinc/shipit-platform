import 'dart:io';

import 'package:product_registry/product_registry.dart';

Future<void> main(List<String> argv) async {
  final root = argv.isNotEmpty
      ? argv.first
      : Directory.current.parent.parent.path;
  final observations = await ReadOnlyRepositoryReader(
    snapshotRoot: Directory(root),
  ).inspect();

  stderr.writeln('TOTAL: ${observations.length}');
  final bySection = <String, int>{};
  for (final o in observations) {
    bySection[o.section.wire] = (bySection[o.section.wire] ?? 0) + 1;
  }
  stderr.writeln('SECTIONS: $bySection');
  stderr.writeln('');
  for (final o in observations) {
    stdout.writeln('[${o.section.wire}] ${o.provenance.wire}: ${o.claim}');
  }
}
