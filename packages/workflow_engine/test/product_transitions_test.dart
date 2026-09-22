import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';

void main() {
  group('ProductState wire contract', () {
    test('every value round-trips through its wire string', () {
      for (final s in ProductState.values) {
        expect(ProductState.fromWire(s.wire), s, reason: s.name);
      }
    });

    test('wire strings are unique', () {
      final wires = ProductState.values.map((s) => s.wire).toList();
      expect(wires.toSet().length, wires.length);
    });

    test('unknown wire is a FormatException, not a silent default', () {
      expect(() => ProductState.fromWire('nope'), throwsFormatException);
    });

    test('legacy values are readable and map to canonical meanings', () {
      expect(ProductState.fromWire('draft').canonical, ProductState.registered);
      expect(ProductState.fromWire('active').canonical, ProductState.governed);
      expect(
        ProductState.fromWire('deprecated').canonical,
        ProductState.archived,
      );
      expect(ProductState.fromWire('draft').isLegacy, isTrue);
      expect(ProductState.governed.isLegacy, isFalse);
    });

    test('only governed permits dispatch — paused is the point of pausing', () {
      expect(ProductState.governed.allowsDispatch, isTrue);
      for (final s in ProductState.values.where(
        (s) => s != ProductState.governed,
      )) {
        expect(s.allowsDispatch, isFalse, reason: s.name);
      }
    });

    test('states that await a human are exactly review and blocked', () {
      final awaiting = ProductState.values
          .where((s) => s.isAwaitingHuman)
          .toSet();
      expect(awaiting, {
        ProductState.baselineReview,
        ProductState.baselineBlocked,
      });
    });
  });

  group('ProductTransitions legality', () {
    test('registering is not governing — no direct edge to governed', () {
      expect(
        ProductTransitions.isLegalTransition(
          ProductState.registered,
          ProductState.governed,
        ),
        isFalse,
      );
    });

    test('governance is granted only by approval, or restored by resume', () {
      final sources = {
        for (final (f, t) in ProductTransitions.all)
          if (t == ProductState.governed) f,
      };
      // Two ways in, and only two: the first grant (an approved baseline) and
      // resuming a product that was already governed before it was paused.
      expect(sources, {ProductState.baselineReview, ProductState.paused});
      // The grant path proves approval; the resume path must not be able to.
      expect(
        ProductTransitions.requiredGuards(
          ProductState.baselineReview,
          ProductState.governed,
        ),
        contains(ProductGuard.baselineApproved),
      );
      expect(
        ProductTransitions.requiredGuards(
          ProductState.paused,
          ProductState.governed,
        ),
        isNot(contains(ProductGuard.baselineApproved)),
      );
    });

    test('reaching governed requires an approved baseline and a human', () {
      final guards = ProductTransitions.requiredGuards(
        ProductState.baselineReview,
        ProductState.governed,
      );
      expect(guards, contains(ProductGuard.baselineApproved));
      expect(guards, contains(ProductGuard.decisionActorIsHuman));
    });

    test('a baseline is verified independently before a human is asked', () {
      expect(
        ProductTransitions.requiredGuards(
          ProductState.baselinePending,
          ProductState.baselineReview,
        ),
        containsAll([
          ProductGuard.baselineProposed,
          ProductGuard.baselineVerifiedIndependently,
        ]),
      );
    });

    test('pause and resume are both human decisions, and reversible', () {
      expect(
        ProductTransitions.requiresHumanDecision(
          ProductState.governed,
          ProductState.paused,
        ),
        isTrue,
      );
      expect(
        ProductTransitions.requiresHumanDecision(
          ProductState.paused,
          ProductState.governed,
        ),
        isTrue,
      );
    });

    test('offboarding a live product requires no work in flight', () {
      for (final from in [ProductState.governed, ProductState.paused]) {
        expect(
          ProductTransitions.requiredGuards(from, ProductState.archived),
          contains(ProductGuard.noWorkInFlight),
          reason: from.name,
        );
      }
    });

    test('archived never returns straight to governed', () {
      expect(
        ProductTransitions.isLegalTransition(
          ProductState.archived,
          ProductState.governed,
        ),
        isFalse,
      );
      expect(
        ProductTransitions.isLegalTransition(
          ProductState.archived,
          ProductState.baselineReview,
        ),
        isTrue,
      );
    });

    test('re-baselining a governed product does not interrupt dispatch', () {
      // governed -> baselineReview is legal, and governed is not left until
      // the new baseline is decided.
      expect(
        ProductTransitions.isLegalTransition(
          ProductState.governed,
          ProductState.baselineReview,
        ),
        isTrue,
      );
    });
  });

  group('ProductTransitions legacy handling', () {
    test('no legacy value is ever a transition target', () {
      for (final legacy in ProductState.values.where((s) => s.isLegacy)) {
        for (final from in ProductState.values) {
          expect(
            ProductTransitions.isLegalTransition(from, legacy),
            isFalse,
            reason: '${from.name} -> ${legacy.name}',
          );
        }
      }
    });

    test('legacy rows transition out using their canonical meaning', () {
      final draft = ProductState.fromWire('draft');
      expect(
        ProductTransitions.isLegalTransition(
          draft,
          ProductState.baselinePending,
        ),
        isTrue,
      );
      final active = ProductState.fromWire('active');
      expect(
        ProductTransitions.isLegalTransition(active, ProductState.paused),
        isTrue,
      );
    });

    test('rejection explains itself rather than returning a bare false', () {
      expect(
        ProductTransitions.explainRejection(
          ProductState.registered,
          ProductState.governed,
        ),
        allOf(contains('registered'), contains('governed')),
      );
      expect(
        ProductTransitions.explainRejection(
          ProductState.registered,
          ProductState.fromWire('active'),
        ),
        contains('parse-only'),
      );
      expect(
        ProductTransitions.explainRejection(
          ProductState.governed,
          ProductState.paused,
        ),
        isNull,
      );
    });
  });

  group('ProductTransitions graph integrity', () {
    test('no self-transitions are declared', () {
      for (final (f, t) in ProductTransitions.all) {
        expect(f == t, isFalse, reason: '${f.name} -> ${t.name}');
      }
    });

    test('every live state is reachable', () {
      final targets = {for (final (_, t) in ProductTransitions.all) t};
      final live = ProductState.values.where((s) => !s.isLegacy).toSet();
      // registered is the entry point and is also returned to when a baseline
      // is rejected, so nothing in the live set is orphaned.
      expect(live.difference(targets), isEmpty);
      expect(
        ProductTransitions.isLegalTransition(
          ProductState.baselineReview,
          ProductState.registered,
        ),
        isTrue,
        reason: 'rejecting a baseline must return the product to registered',
      );
    });

    test('every non-terminal live state can make progress', () {
      for (final s in ProductState.values.where(
        (s) => !s.isLegacy && !s.isTerminal,
      )) {
        expect(
          ProductTransitions.reachableFrom(s),
          isNotEmpty,
          reason: '${s.name} is a dead end',
        );
      }
    });

    test('archived only leads to re-review', () {
      expect(ProductTransitions.reachableFrom(ProductState.archived), [
        ProductState.baselineReview,
      ]);
    });
  });
}
