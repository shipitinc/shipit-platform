import 'package:flutter_test/flutter_test.dart';
import 'package:control_plane/core/plain_language.dart';

void main() {
  group('PlainLanguage.headline', () {
    test('keeps a short description whole', () {
      expect(
        PlainLanguage.headline(
          title: 'Scheduler CAS patch',
          description: 'Stop duplicate jobs from running twice.',
        ),
        'Stop duplicate jobs from running twice.',
      );
    });

    test('falls back to the technical title when there is no description', () {
      expect(
        PlainLanguage.headline(
          title: 'Scheduler CAS patch',
          description: null,
        ),
        'Scheduler CAS patch',
      );
      expect(
        PlainLanguage.headline(title: 'Scheduler CAS patch', description: '  '),
        'Scheduler CAS patch',
      );
    });

    test('a reported defect reads as its first sentence, not the report', () {
      const description =
          'Human-reported defect awaiting AI triage. Reported by operator at '
          '2026-10-11T02:34:45.546076Z. Reported behaviour: Runs Title is very '
          'long. Reproduction steps: Open the run detail page';

      final headline = PlainLanguage.headline(
        title: 'DEF-1791686085546076',
        description: description,
      );

      expect(headline, 'Human-reported defect awaiting AI triage.');
      expect(
        headline.length,
        lessThanOrEqualTo(PlainLanguage.headlineMaxLength),
      );
    });

    test('a single sentence longer than the budget is clipped on a word', () {
      final headline = PlainLanguage.headline(
        title: 'DEF-1',
        description: 'Stop the scheduler from issuing duplicate claims when '
            'two workers race on the same lease row at the same instant',
      );

      expect(headline.length, lessThanOrEqualTo(
        PlainLanguage.headlineMaxLength + 1, // the ellipsis character
      ));
      expect(headline, endsWith('…'));
      expect(headline, isNot(contains('  ')));
    });

    test('a sentence that fits after the first one is not clipped further', () {
      final headline = PlainLanguage.headline(
        title: 'DEF-2',
        description: 'Runs Title is very long. Expected behaviour: a shorter '
            'explanation of what the run pertained to.',
      );

      expect(headline, 'Runs Title is very long.');
    });

    test('an explicit budget is honoured', () {
      expect(
        PlainLanguage.headline(
          title: 'DEF-3',
          description: 'Stop duplicate jobs running twice in the scheduler.',
          maxLength: 20,
        ),
        'Stop duplicate…',
      );
    });
  });
}
