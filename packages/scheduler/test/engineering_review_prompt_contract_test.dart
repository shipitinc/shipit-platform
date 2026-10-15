/// Drift guard for the engineering review prompt contract.
///
/// `engineeringReviewInstruction` is the ONLY instruction an engineering
/// reviewer ever receives — `OpenCodeSession` opens its session with
/// `{'cwd': ..., 'mcpServers': []}`, carrying no agent name, no system prompt
/// and no role, so this string is the reviewer's entire specification. Before
/// this guard the prompt said "return an engineering review verdict" and
/// nothing else, and the observable consequence was four reviews that ran to
/// completion, produced real findings, and recorded `{}` in
/// `structuredResultJson` with their work items stranded at `review_in_progress`
/// and no decision raised.
///
/// The reader is strict, which is what makes the prompt load-bearing:
/// `_readReviewVerdict` in `apps/server/lib/src/review/engineering_review_gate.dart`
/// reads `structuredResult['verdict']` and feeds it to `ReviewVerdict.fromWire`,
/// which throws `FormatException` on anything that is not an exact wire token.
/// b1 correctly refuses to invent a verdict from an unreadable payload, so a
/// prompt that omits the shape produces a silent park rather than an error.
///
/// These tests read the documented values back out of the GENERATED prompt
/// string, not out of a copy of it, so adding or renaming a [ReviewVerdict]
/// member fails here instead of silently un-parsing reviewer output. That is
/// the same guard `lane_m_triage_prompt_contract_test.dart` provides for the
/// triage lane, and the reason triage parses and engineering review did not.
library;

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';

WorkItem _reviewableItem() {
  final now = DateTime.utc(2026, 1, 1);
  return WorkItem(
    workItemId: 'wi-review-1',
    productId: 'p-1',
    category: WorkItemCategory.feature,
    title: 'Implement the calculator',
    description: 'add() for the calculator contract',
    state: WorkItemState.agentCompleted,
    qaContractId: 'qa-1',
    createdAt: now,
    updatedAt: now,
  );
}

String _prompt() => engineeringReviewInstruction(
  _reviewableItem(),
  engineeringReviewDefinition,
);

/// The line of the documented payload that declares `field`, or null.
String? _fieldLine(String prompt, String field) {
  for (final line in prompt.split('\n')) {
    if (line.trimLeft().startsWith('"$field":')) return line;
  }
  return null;
}

/// Every `"..."` token in a payload line's *value* (i.e. after the first colon,
/// so the field name itself is not counted), in declaration order.
List<String> _quotedTokens(String? line) {
  if (line == null) return const [];
  final value = line.substring(line.indexOf(':') + 1);
  return RegExp(
    r'"([^"]*)"',
  ).allMatches(value).map((m) => m.group(1)!).toList();
}

/// The wire tokens `ReviewVerdict.fromWire` accepts, read back out of the
/// rendered prompt's `verdict` field.
List<String> _documentedVerdicts() =>
    _quotedTokens(_fieldLine(_prompt(), 'verdict'));

void main() {
  group('the review prompt documents the tokens the contracts serialise', () {
    test('verdict documents every ReviewVerdict wire token, in enum order', () {
      expect(
        _documentedVerdicts(),
        ReviewVerdict.values.map((v) => v.wire).toList(),
        reason:
            'The prompt is rendered from the enum, so this can only fail if a '
            'member is added or renamed without the prompt following. It is '
            'the guard for exactly the defect this file exists for.',
      );
    });

    test('every documented verdict really parses', () {
      // The converse of the assertion above: if the prompt ever documents a
      // token the contract rejects, this throws and names it.
      for (final token in _documentedVerdicts()) {
        expect(
          () => ReviewVerdict.fromWire(token),
          returnsNormally,
          reason:
              '"$token" is documented in the prompt but is not a wire value',
        );
      }
    });

    test('verdict does not document capitals or camelCase spellings', () {
      for (final verdict in ReviewVerdict.values) {
        expect(
          _documentedVerdicts(),
          isNot(contains(verdict.wire.toUpperCase())),
          reason:
              '${verdict.wire.toUpperCase()} is not a wire value. '
              '`ReviewVerdict.fromWire` compares exactly, so this is an '
              'unreadable verdict — the SITE 2 fabrication.',
        );
        // Only meaningful where the member name differs from its wire token.
        // `approved` and `rejected` serialise identically to their Dart names,
        // so asserting `name` is absent would fail on a correct prompt.
        if (verdict.name != verdict.wire) {
          expect(
            _documentedVerdicts(),
            isNot(contains(verdict.name)),
            reason:
                '${verdict.name} is a Dart member name, not the serialised '
                'token.',
          );
        }
      }
    });

    test('severity documents every DesignFindingSeverity wire token', () {
      final findingLine = _prompt()
          .split('\n')
          .firstWhere((line) => line.contains('"severity":'));
      expect(
        _quotedTokens(findingLine),
        DesignFindingSeverity.values.map((s) => s.wire).toList(),
      );
    });

    test('the prompt does not ask for fields a reviewer cannot know', () {
      final prompt = _prompt();
      for (final unfillable in const [
        'reviewExecutionId',
        'revisionId',
        'findingId',
        'version',
      ]) {
        expect(
          _fieldLine(prompt, unfillable),
          isNull,
          reason:
              '"$unfillable" is run identity stamped by '
              '`engineering_review_gate.dart`, not something a reviewer can '
              'supply. Asking for it invites invented provenance.',
        );
      }
    });
  });

  group('the review prompt still does its actual job', () {
    test('requires a single JSON object with no surrounding prose', () {
      final prompt = _prompt();
      expect(prompt, contains('single JSON object'));
      expect(prompt, contains('Do NOT include any prose outside the JSON'));
    });

    test('documents the exact key the gate reads', () {
      // `_readReviewVerdict` reads `structuredResult['verdict']` and nothing
      // else at the top level. A prompt documenting a different key produces
      // `verdict_absent` on every run.
      expect(_fieldLine(_prompt(), 'verdict'), isNotNull);
      expect(_fieldLine(_prompt(), 'findings'), isNotNull);
    });

    test('still names the work item under review', () {
      final prompt = _prompt();
      expect(prompt, contains('wi-review-1'));
      expect(prompt, contains('Implement the calculator'));
    });

    test('keeps the independence obligation', () {
      expect(_prompt(), contains('Independently review'));
      expect(_prompt(), contains('do not consult'));
    });
  });

  group('ANTI-BIAS: the prompt asks for an honest verdict, not a chosen one', () {
    // These are the tests that stop this fix becoming the fabrication bug by
    // another route. `93587cf` removed three `changesRequired` fallbacks; a
    // prompt that names a verdict as a default would rebuild the same defect at
    // the prompt layer, where no test would catch it.

    test('no verdict is named as a default, a fallback or an expectation', () {
      final prompt = _prompt().toLowerCase();
      // `{w}` is filled in per verdict. Each of these is a way a prompt can
      // steer a reviewer toward an outcome without ever saying "always return".
      const shapes = [
        'use "{w}"',
        'use "{w}" if',
        'default to "{w}"',
        'if in doubt, "{w}"',
        'you should return "{w}"',
        'the expected verdict is "{w}"',
        'always return "{w}"',
        'you should report "{w}"',
        'report "{w}" unless',
        'prefer "{w}"',
        'assume "{w}"',
      ];
      for (final verdict in ReviewVerdict.values) {
        for (final shape in shapes) {
          expect(
            prompt,
            isNot(contains(shape.replaceAll('{w}', verdict.wire))),
            reason:
                'the prompt must not steer the reviewer toward '
                '${verdict.wire}. The platform records whatever comes back; it '
                'does not tell the reviewer what to conclude.',
          );
        }
      }
    });

    test('no verdict is named more often than any other', () {
      // A prompt that discusses one outcome more than the others is weighting
      // it, whatever it says about neutrality.
      final prompt = _prompt();
      final counts = {
        for (final verdict in ReviewVerdict.values)
          verdict.wire: '"${verdict.wire}"'.allMatches(prompt).length,
      };
      expect(
        counts.values.toSet(),
        hasLength(1),
        reason:
            'the four tokens must be presented symmetrically. Counts: $counts',
      );
    });

    test('finding nothing is explicitly a real, reportable outcome', () {
      // The prompt is hard-wrapped, so match against whitespace-collapsed text
      // rather than the raw string; otherwise this asserts on line breaks.
      final prompt = _prompt().replaceAll(RegExp(r'\s+'), ' ');
      expect(
        prompt,
        contains(
          'A review that finds nothing blocking is a real result with an '
          'honest answer',
        ),
        reason:
            'without this, a reviewer that genuinely found nothing has no '
            'honest token available and may invent a minor finding to justify '
            'a harsher one. That is the failure mode this guard exists for.',
      );
      expect(
        prompt,
        contains('not a worse review than one that found something'),
      );
    });

    test('both directions of misreporting are forbidden', () {
      final prompt = _prompt();
      expect(prompt, contains('Do not report a problem you did not find'));
      expect(
        prompt,
        contains('do not soften one you did'),
        reason:
            'anti-bias has to be symmetric. Guarding only against inflated '
            'verdicts is itself a nudge, downward.',
      );
    });

    test('the reviewer is told the platform supplies no verdict for it', () {
      expect(_prompt(), contains('the platform never supplies one'));
    });
  });
}
