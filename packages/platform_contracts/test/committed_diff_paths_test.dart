import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

/// The ordering invariant on [CommittedDiffPaths], pinned at the type the gate
/// will read it from.
///
/// ## WHY THIS IS TESTED HERE AND NOT AT THE COLLECTOR
///
/// The collector's tests prove the reader sorts what git gave it. They cannot
/// prove the *value type* sorts what any construction path gives it — and the
/// construction path is exactly where the defect this guards against appears.
///
/// A comparator that is a total order against a database but not against an
/// in-memory store is a defect, and the usual cause is a sort key that is
/// nullable or non-unique in one of them. Here there is no such key: the order
/// is by the path string itself, `String.compareTo`, which compares UTF-16 code
/// units and always returns an `int`. So there is no way to build two distinct
/// paths that compare equal, and the total order is a property of the
/// comparator rather than of the data it is handed.
///
/// That is a claim about the type, so these are the tests that hold it.
void main() {
  group('the total order', () {
    test('paths are sorted by code unit regardless of input order', () {
      final forwards = CommittedDiffPaths(
        startingRevision: 'a',
        producedRevision: 'b',
        paths: ['a.dart', 'b.dart', 'c.dart'],
      );
      final backwards = CommittedDiffPaths(
        startingRevision: 'a',
        producedRevision: 'b',
        paths: ['c.dart', 'b.dart', 'a.dart'],
      );
      final shuffled = CommittedDiffPaths(
        startingRevision: 'a',
        producedRevision: 'b',
        paths: ['b.dart', 'c.dart', 'a.dart'],
      );

      expect(forwards.paths, ['a.dart', 'b.dart', 'c.dart']);
      expect(backwards.paths, forwards.paths);
      expect(shuffled.paths, forwards.paths);
    });

    test('the order is byte-order, not locale collation', () {
      // `compareTo` is code-unit order: uppercase sorts before lowercase, and
      // 'M' (0x4D) before 'a' (0x61). A locale-aware collator would order
      // these differently, which is why the comparator is pinned rather than
      // left to a library default.
      final value = CommittedDiffPaths(
        startingRevision: 'a',
        producedRevision: 'b',
        paths: ['b.dart', 'A.dart', 'a.dart', 'B.dart'],
      );

      expect(value.paths, ['A.dart', 'B.dart', 'a.dart', 'b.dart']);
    });

    test('duplicates are collapsed', () {
      // The union of two enumerations is built by concatenation; the value
      // type defines what the union MEANS, and a path must not be counted
      // twice because two sources agreed about it.
      final value = CommittedDiffPaths(
        startingRevision: 'a',
        producedRevision: 'b',
        paths: ['x.dart', 'x.dart', 'y.dart', 'x.dart'],
      );

      expect(value.paths, ['x.dart', 'y.dart']);
    });

    test('more than five paths survive — the cap the old reader had', () {
      final many = List<String>.generate(50, (i) => 'file_$i.dart')..shuffle();
      final value = CommittedDiffPaths(
        startingRevision: 'a',
        producedRevision: 'b',
        paths: many,
      );

      expect(value.paths.length, 50);
      expect(value.paths, many.toList()..sort());
    });
  });

  group('the list is not the caller\'s', () {
    test(
      'the constructor copies, so a mutated input cannot change the result',
      () {
        final source = <String>['b.dart', 'a.dart'];
        final value = CommittedDiffPaths(
          startingRevision: 'a',
          producedRevision: 'b',
          paths: source,
        );

        source
          ..clear()
          ..add('zzz.dart');

        expect(value.paths, ['a.dart', 'b.dart']);
      },
    );

    test('the exposed list is unmodifiable', () {
      final value = CommittedDiffPaths(
        startingRevision: 'a',
        producedRevision: 'b',
        paths: ['a.dart'],
      );

      expect(() => value.paths.add('b.dart'), throwsUnsupportedError);
      expect(() => value.paths.sort(), throwsUnsupportedError);
      expect(() => value.paths.clear(), throwsUnsupportedError);
    });
  });

  group('equality', () {
    test('same range and same paths are equal regardless of input order', () {
      final one = CommittedDiffPaths(
        startingRevision: 'start',
        producedRevision: 'produced',
        paths: ['b.dart', 'a.dart'],
      );
      final two = CommittedDiffPaths(
        startingRevision: 'start',
        producedRevision: 'produced',
        paths: ['a.dart', 'b.dart'],
      );

      expect(one, two);
      expect(one.hashCode, two.hashCode);
    });

    test('a different range is a different value', () {
      final one = CommittedDiffPaths(
        startingRevision: 'start',
        producedRevision: 'produced',
        paths: const [],
      );
      final two = CommittedDiffPaths(
        startingRevision: 'start',
        producedRevision: 'other',
        paths: const [],
      );

      expect(one, isNot(two));
    });

    test('an EMPTY path list is constructible, which is exactly why it cannot '
        'mean "could not look"', () {
      // A clean, fully-committed change genuinely touches nothing, so the
      // empty set has to be expressible. The reason it is safe is that a
      // failed enumeration throws rather than returning a value — the
      // collector is what guarantees this, and this test documents the half
      // of that contract that lives in the type.
      final empty = CommittedDiffPaths(
        startingRevision: 'start',
        producedRevision: 'produced',
        paths: const [],
      );

      expect(empty.paths, isEmpty);
    });
  });

  group('WorkspaceHead', () {
    test('carries the revision and the verdict', () {
      const head = WorkspaceHead(
        startingRevision: 'start',
        headRevision: 'produced',
        headMoved: true,
      );

      expect(head.headMoved, isTrue);
      expect(head, isNot(head.copyWithAny()));
    });
  });
}

extension on WorkspaceHead {
  /// A structurally different head, so equality can be probed without hand-
  /// writing a second literal twice.
  WorkspaceHead copyWithAny() => WorkspaceHead(
    startingRevision: 'other',
    headRevision: 'third',
    headMoved: false,
  );
}
