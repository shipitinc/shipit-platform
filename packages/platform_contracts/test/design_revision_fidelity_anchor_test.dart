import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

/// Pins `DesignRevisionFidelityAnchorValidator` to the committed document
/// `schemas/design_revision_fidelity_anchor.schema.json`.
///
/// ## Why this file exists at all
///
/// `json_schema` is a dev dependency of this package, so the runtime validator
/// cannot EVALUATE the committed `.json` — the rules are transcribed into Dart
/// instead (see the library doc). A transcription is exactly the shape of thing
/// that rots: someone edits the schema, forgets the Dart, and the two become
/// two vocabularies — the `92d567e3` failure one layer down. Every test here
/// reads the committed document and compares, so a divergence is a red test
/// rather than a silent second contract.
///
/// ## What it does NOT claim
///
/// It does not claim the validator is complete on its own terms; it claims the
/// two agree on every case below, and that the constants Dart uses are the ones
/// the document declares.
const _schemasRoot = '../../schemas';
const _anchorName = 'design_revision_fidelity_anchor';

Map<String, dynamic> _anchorDocument() =>
    jsonDecode(
          File('$_schemasRoot/$_anchorName.schema.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

/// Validates [instance] against `#/definitions/[name]` of the committed
/// document.
///
/// The definitions map travels with the wrapper so the local `$ref` resolves,
/// which is the same resolution the whole-document load performs.
bool _schemaAcceptsSubschema(
  Map<String, dynamic> document,
  String name,
  Object? instance,
) {
  final wrapper = <String, dynamic>{
    'definitions': document['definitions'],
    '\$ref': '#/definitions/$name',
  };
  return JsonSchema.create(wrapper).validate(instance).isValid;
}

bool _schemaAcceptsBundle(Map<String, dynamic> document, Object? instance) =>
    JsonSchema.create(
      document,
    ).validate(instance, validateFormats: true).isValid;

// --------------------------------------------------------------- fixtures

/// The canonical review scope: keys sorted (`boardIds` < `dimensions`), array
/// contents sorted too. §3.5.2 rule 1 sorts keys at EVERY level, the scope
/// included, so a fixture that skipped this would be non-canonical by accident.
const Map<String, dynamic> _canonicalScope = <String, dynamic>{
  'boardIds': <String>['login-desktop'],
  'dimensions': <String>['a11y', 'responsive'],
};

const _designer = '11111111-2222-4333-8444-000000000001';
const _reviewerA = '11111111-2222-4333-8444-00000000000a';
const _reviewerB = '11111111-2222-4333-8444-00000000000b';

/// A revision whose six columns are already in §3.5.2 canonical form.
///
/// Canonical by construction is the point: every fixture below starts from here
/// and changes ONE thing, so a test's name can state the rule it is exercising
/// rather than "something was rejected".
DesignRevision _revision({
  String designerExecutionId = _designer,
  String boardIdsJson =
      '[{"boardId":"login-desktop","boardName":"Login","provider":"penpot",'
      '"providerFileId":"pf-1"}]',
  // "lg" sorts before "xs": the sort key is the breakpoint STRING, so the
  // canonical order is not the order a human would read them in.
  String responsiveTargetsJson =
      '[{"breakpoint":"lg","minViewportWidthCss":1024},'
      '{"breakpoint":"xs","minViewportWidthCss":320}]',
  String statesRepresentedJson =
      '[{"boardId":"login-desktop","stateKey":"form-filled",'
      '"variant":"default"}]',
  String artifactRefsJson = '[]',
  String reviewExecutionIdsJson = '["$_reviewerA"]',
  Map<String, dynamic>? reviewScopeJson = _canonicalScope,
}) => DesignRevision(
  revisionId: 'DES-R900',
  workItemId: '11111111-2222-4333-8444-0000000000ff',
  productId: '11111111-2222-4333-8444-0000000000ee',
  parentRevisionId: null,
  designSystemRevision: 'dsr-1',
  provider: DesignProviderType.penpot,
  penpotFileId: 'pf-1',
  penpotPageId: 'pp-1',
  boardIdsJson: boardIdsJson,
  responsiveTargetsJson: responsiveTargetsJson,
  statesRepresentedJson: statesRepresentedJson,
  artifactRefsJson: artifactRefsJson,
  designerExecutionId: designerExecutionId,
  reviewExecutionIdsJson: reviewExecutionIdsJson,
  status: DesignRevisionStatus.draft,
  riskTier: DesignRiskTier.high,
  reviewScopeJson: reviewScopeJson,
  carriedForwardFromRevisionId: null,
  supersededByRevisionId: null,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  approvedAt: null,
  version: 1,
);

DesignRevisionFidelityAnchorReport _report(DesignRevision revision) =>
    DesignRevisionFidelityAnchorValidator.validate(revision);

/// Asserts the revision is refused, and that [code] is among the reasons.
///
/// Naming the code is what keeps this from being "something was rejected": a
/// test that accepted any failure would keep passing after the rule it names
/// stopped working.
void _expectRefused(
  DesignRevision revision,
  String code, {
  required String because,
}) {
  final report = _report(revision);
  expect(
    report.isValid,
    isFalse,
    reason: 'because $because — expected a violation, got a valid anchor',
  );
  expect(
    report.codes,
    contains(code),
    reason: 'because $because — codes were ${report.codes}',
  );
}

void main() {
  group('the committed document is the one this validator transcribes', () {
    final document = _anchorDocument();

    test('its \$id carries the version the Dart constant declares', () {
      expect(document['\$id'], designRevisionFidelityAnchorSchemaId);
      expect(
        document['\$id'],
        contains('/${designRevisionFidelityAnchorSchemaVersion}/'),
        reason: '§3.5.1 requires the \$id itself to be versioned',
      );
    });

    test('it declares exactly the six subschemas of §3.5.1', () {
      expect(
        (document['definitions'] as Map<String, dynamic>).keys.toSet(),
        <String>{
          'artifactSet',
          'boardId',
          'boardSet',
          'executionIdSet',
          'responsiveSet',
          'reviewScope',
          'stateSet',
        },
        reason:
            'six subschemas, one per column, plus the shared boardId '
            'definition they all reference',
      );
    });

    test('every subschema forbids additional properties', () {
      // "An unknown key is a claim the platform cannot check." If a subschema
      // ever stops refusing one, the Dart side refusing it is unbacked.
      final definitions = document['definitions'] as Map<String, dynamic>;
      for (final entry in definitions.entries) {
        if (entry.key == 'boardId') continue;
        final schema = entry.value as Map<String, dynamic>;
        if (schema['type'] == 'array' &&
            (schema['items'] as Map<String, dynamic>)['type'] != 'object') {
          // executionIdSet: an array of STRINGS. There is no object anywhere in
          // it for `additionalProperties` to apply to.
          continue;
        }
        final items = schema['items'];
        if (items is Map<String, dynamic> && items['type'] == 'object') {
          // An ARRAY-of-objects subschema: `additionalProperties: false`
          // belongs to its ITEM schema, because an array has no properties of
          // its own. executionIdSet's items are strings, so it carries
          // `minLength` instead and nothing here applies to it.
          expect(
            items['additionalProperties'],
            isFalse,
            reason:
                'definitions.${entry.key}.items must set '
                'additionalProperties:false',
          );
          continue;
        }
        // reviewScope is the one subschema that IS an object
        // (`["object","null"]`), so it carries the keyword itself.
        expect(
          schema['additionalProperties'],
          isFalse,
          reason:
              'definitions.${entry.key} must set additionalProperties:false',
        );
      }
    });

    test('the closed vocabularies Dart enforces are the ones declared', () {
      final definitions = document['definitions'] as Map<String, dynamic>;

      final boardItems =
          (definitions['boardSet'] as Map<String, dynamic>)['items']
              as Map<String, dynamic>;
      expect(
        ((boardItems['properties'] as Map<String, dynamic>)['provider']
            as Map<String, dynamic>)['enum'],
        fidelityAnchorBoardProviders,
        reason: 'the design-system link only holds if both sides agree',
      );
      expect(
        (definitions['boardId'] as Map<String, dynamic>)['pattern'],
        r'^[A-Za-z0-9_-]{1,128}$',
      );
      expect(
        fidelityAnchorBoardIdPattern.pattern,
        (definitions['boardId'] as Map<String, dynamic>)['pattern'],
      );

      List<String> itemEnum(String subschema, String property) {
        final items =
            (definitions[subschema] as Map<String, dynamic>)['items']
                as Map<String, dynamic>;
        final props = items['properties'] as Map<String, dynamic>;
        return ((props[property] as Map<String, dynamic>)['enum']
                as List<dynamic>)
            .cast<String>();
      }

      expect(
        itemEnum('responsiveSet', 'breakpoint'),
        fidelityAnchorBreakpoints,
      );
      expect(
        itemEnum('responsiveSet', 'orientation'),
        fidelityAnchorOrientations,
      );
      expect(itemEnum('stateSet', 'variant'), fidelityAnchorStateVariants);
      expect(itemEnum('artifactSet', 'kind'), fidelityAnchorArtifactKinds);

      final scopeProps =
          (definitions['reviewScope'] as Map<String, dynamic>)['properties']
              as Map<String, dynamic>;
      expect(
        ((scopeProps['dimensions'] as Map<String, dynamic>)['items']
            as Map<String, dynamic>)['enum'],
        fidelityAnchorReviewDimensions,
      );
    });

    test('the declared sort keys are the ones canonicalisation sorts by', () {
      final definitions = document['definitions'] as Map<String, dynamic>;
      expect(
        (definitions['boardSet'] as Map<String, dynamic>)['x-sort-key'],
        'boardId',
      );
      expect(
        (definitions['responsiveSet'] as Map<String, dynamic>)['x-sort-key'],
        'breakpoint',
      );
      expect(
        (definitions['stateSet'] as Map<String, dynamic>)['x-sort-key'],
        'stateKey',
      );
      expect(
        (definitions['artifactSet'] as Map<String, dynamic>)['x-sort-key'],
        <String>['kind', 'ref'],
      );
    });

    test('minItems matches what §3.5.1 decides per column', () {
      final definitions = document['definitions'] as Map<String, dynamic>;
      // 1 for boardSet/responsiveSet/stateSet ("asserts nothing" otherwise),
      // 0 for artifactSet/executionIdSet ("may honestly carry none").
      expect((definitions['boardSet'] as Map<String, dynamic>)['minItems'], 1);
      expect(
        (definitions['responsiveSet'] as Map<String, dynamic>)['minItems'],
        1,
      );
      expect((definitions['stateSet'] as Map<String, dynamic>)['minItems'], 1);
      expect(
        (definitions['artifactSet'] as Map<String, dynamic>)['minItems'],
        0,
      );
      expect(
        (definitions['executionIdSet'] as Map<String, dynamic>)['minItems'],
        0,
      );
      expect(
        (definitions['reviewScope'] as Map<String, dynamic>)['type'],
        <String>['object', 'null'],
      );
    });
  });

  group(
    'the committed schema accepts a valid bundle and refuses each defect',
    () {
      final document = _anchorDocument();

      test('the registered example is a conforming instance', () {
        final example = jsonDecode(
          File(
            '$_schemasRoot/examples/$_anchorName.example.json',
          ).readAsStringSync(),
        );
        expect(_schemaAcceptsBundle(document, example), isTrue);
        final report = DesignRevisionFidelityAnchorValidator.validate(
          _revisionFromBundle(example),
        );
        expect(
          report.isValid,
          isTrue,
          reason:
              'the Dart validator must agree that the example conforms; '
              'violations were '
              '${report.violations.map((v) => '$v').toList()}',
        );
      });

      test('boardSet: a conforming set is accepted', () {
        expect(
          _schemaAcceptsSubschema(document, 'boardSet', <dynamic>[
            <String, dynamic>{
              'boardId': 'login-desktop',
              'provider': 'penpot',
              'providerFileId': 'pf-1',
            },
          ]),
          isTrue,
        );
      });

      test('boardSet: an empty set is refused (minItems 1)', () {
        expect(
          _schemaAcceptsSubschema(document, 'boardSet', <dynamic>[]),
          isFalse,
        );
      });

      test('boardSet: a board without providerFileId is refused', () {
        // The nullable-penpotFileId hole: the human anchor would be unopenable.
        expect(
          _schemaAcceptsSubschema(document, 'boardSet', <dynamic>[
            <String, dynamic>{'boardId': 'login-desktop', 'provider': 'penpot'},
          ]),
          isFalse,
        );
      });

      test('boardSet: an unknown key is refused', () {
        expect(
          _schemaAcceptsSubschema(document, 'boardSet', <dynamic>[
            <String, dynamic>{
              'boardId': 'login-desktop',
              'provider': 'penpot',
              'providerFileId': 'pf-1',
              'screenshot': 'x.png',
            },
          ]),
          isFalse,
        );
      });

      test('boardSet: a free-text boardId is refused', () {
        expect(
          _schemaAcceptsSubschema(document, 'boardSet', <dynamic>[
            <String, dynamic>{
              'boardId': 'login desktop!',
              'provider': 'penpot',
              'providerFileId': 'pf-1',
            },
          ]),
          isFalse,
        );
      });

      test('boardSet: a duplicate boardId is refused (uniqueItems)', () {
        expect(
          _schemaAcceptsSubschema(document, 'boardSet', <dynamic>[
            <String, dynamic>{
              'boardId': 'login-desktop',
              'provider': 'penpot',
              'providerFileId': 'pf-1',
            },
            <String, dynamic>{
              'boardId': 'login-desktop',
              'provider': 'penpot',
              'providerFileId': 'pf-1',
            },
          ]),
          isFalse,
        );
      });

      test('responsiveSet: an undeclared breakpoint is refused', () {
        expect(
          _schemaAcceptsSubschema(document, 'responsiveSet', <dynamic>[
            <String, dynamic>{
              'breakpoint': 'tablet',
              'minViewportWidthCss': 800,
            },
          ]),
          isFalse,
        );
      });

      test('responsiveSet: a width outside 0..4096 is refused', () {
        expect(
          _schemaAcceptsSubschema(document, 'responsiveSet', <dynamic>[
            <String, dynamic>{'breakpoint': 'xs', 'minViewportWidthCss': 5000},
          ]),
          isFalse,
        );
        expect(
          _schemaAcceptsSubschema(document, 'responsiveSet', <dynamic>[
            <String, dynamic>{'breakpoint': 'xs', 'minViewportWidthCss': -1},
          ]),
          isFalse,
        );
      });

      test('stateSet: an undeclared variant is refused', () {
        expect(
          _schemaAcceptsSubschema(document, 'stateSet', <dynamic>[
            <String, dynamic>{
              'boardId': 'login-desktop',
              'stateKey': 'hover',
              'variant': 'sparkle',
            },
          ]),
          isFalse,
        );
      });

      test('artifactSet: an empty set is ACCEPTED (minItems 0 is honest)', () {
        expect(
          _schemaAcceptsSubschema(document, 'artifactSet', <dynamic>[]),
          isTrue,
        );
      });

      test('artifactSet: an undeclared kind is refused', () {
        expect(
          _schemaAcceptsSubschema(document, 'artifactSet', <dynamic>[
            <String, dynamic>{'kind': 'screenshot', 'ref': 'x.png'},
          ]),
          isFalse,
        );
      });

      test(
        'executionIdSet: an empty set is ACCEPTED (a draft has no reviewer)',
        () {
          expect(
            _schemaAcceptsSubschema(document, 'executionIdSet', <dynamic>[]),
            isTrue,
          );
          expect(
            _schemaAcceptsSubschema(document, 'executionIdSet', <dynamic>['']),
            isFalse,
          );
        },
      );

      test('reviewScope: null is ACCEPTED and unknown keys are refused', () {
        // §3.5.1 row 6: nullable is preserved; arbitrary keys are the defect.
        expect(_schemaAcceptsSubschema(document, 'reviewScope', null), isTrue);
        expect(
          _schemaAcceptsSubschema(document, 'reviewScope', <String, dynamic>{}),
          isTrue,
        );
        expect(
          _schemaAcceptsSubschema(document, 'reviewScope', <String, dynamic>{
            'scope': 'full',
          }),
          isFalse,
          reason: 'this is exactly the {} / arbitrary-keys confusion',
        );
        expect(
          _schemaAcceptsSubschema(document, 'reviewScope', <String, dynamic>{
            'dimensions': ['accessibility'],
          }),
          isFalse,
          reason:
              'the closed dimension vocabulary is what stops a reviewer '
              'claiming a dimension nobody can check',
        );
      });

      test('the bundle root refuses a key it does not name', () {
        final bundle = _bundleFromExample();
        expect(_schemaAcceptsBundle(document, bundle), isTrue);
        expect(
          _schemaAcceptsBundle(document, <String, dynamic>{
            ...bundle,
            'penpotFileId': 'pf-1',
          }),
          isFalse,
        );
      });

      test('the bundle root refuses a MISSING key', () {
        final bundle = _bundleFromExample()..remove('reviewScope');
        expect(
          _schemaAcceptsBundle(document, bundle),
          isFalse,
          reason:
              'reviewScope is nullable but always PRESENT: a NULL column and '
              'an absent key are different claims',
        );
      });
    },
  );

  group('the Dart validator refuses each defect the schema refuses', () {
    test('boardIdsJson of [] is refused — a revision asserting no board', () {
      _expectRefused(
        _revision(boardIdsJson: '[]'),
        FidelityAnchorViolationCode.tooFewItems,
        because: '§3.5.1 row 1 sets minItems 1',
      );
    });

    test('a board with no providerFileId is refused', () {
      _expectRefused(
        _revision(
          boardIdsJson: '[{"boardId":"login-desktop","provider":"penpot"}]',
        ),
        FidelityAnchorViolationCode.missingMember,
        because: 'providerFileId is required inside the blob',
      );
    });

    test('an undeclared breakpoint is refused', () {
      _expectRefused(
        _revision(
          responsiveTargetsJson:
              '[{"breakpoint":"tablet","minViewportWidthCss":800}]',
        ),
        FidelityAnchorViolationCode.notInVocabulary,
        because: 'the breakpoint vocabulary is the design-system link',
      );
    });

    test('responsiveTargetsJson of [] is refused', () {
      _expectRefused(
        _revision(responsiveTargetsJson: '[]'),
        FidelityAnchorViolationCode.tooFewItems,
        because: '§3.5.1 row 2 sets minItems 1',
      );
    });

    test('statesRepresentedJson of [] is refused', () {
      _expectRefused(
        _revision(statesRepresentedJson: '[]'),
        FidelityAnchorViolationCode.tooFewItems,
        because: '§3.5.1 row 3 sets minItems 1',
      );
    });

    test('an undeclared state variant is refused', () {
      _expectRefused(
        _revision(
          statesRepresentedJson:
              '[{"boardId":"login-desktop",'
              '"stateKey":"hover","variant":"sparkle"}]',
        ),
        FidelityAnchorViolationCode.notInVocabulary,
        because: 'the variant vocabulary is closed',
      );
    });

    test('an unknown key anywhere is refused', () {
      _expectRefused(
        _revision(
          artifactRefsJson:
              '[{"kind":"commit","ref":"abc","screenshot":"x.png"}]',
        ),
        FidelityAnchorViolationCode.unknownKey,
        because: '§3.5.1: an unknown key is a claim the platform cannot check',
      );
    });

    test('a blob that is not JSON at all is refused', () {
      _expectRefused(
        _revision(boardIdsJson: 'board-1,board-2'),
        FidelityAnchorViolationCode.notJson,
        because: 'the column must be a JSON array',
      );
    });

    test('a blob that is JSON but the wrong shape is refused', () {
      _expectRefused(
        _revision(statesRepresentedJson: '{"stateKey":"x"}'),
        FidelityAnchorViolationCode.notJson,
        because: 'the subschema requires an array',
      );
    });

    test('an empty execution id is refused', () {
      _expectRefused(
        _revision(reviewExecutionIdsJson: '[""]'),
        FidelityAnchorViolationCode.unconstrainedString,
        because: 'minLength is 1',
      );
    });

    test('the SAME stateKey on two boards is ACCEPTED — uniqueItems is '
        'whole-item', () {
      // `uniqueItems` is whole-item uniqueness, not sort-key uniqueness. Two
      // states both named `form-filled`, rendered by different boards, are two
      // DISTINCT items and both are honest. Refusing the shared `stateKey`
      // would refuse a revision for a rule §3.5.1 does not state.
      final report = _report(
        _revision(
          boardIdsJson:
              '[{"boardId":"login-desktop","provider":"penpot",'
              '"providerFileId":"pf-1"},'
              '{"boardId":"login-mobile","provider":"penpot",'
              '"providerFileId":"pf-1"}]',
          statesRepresentedJson:
              '[{"boardId":"login-desktop",'
              '"stateKey":"form-filled","variant":"default"},'
              '{"boardId":"login-mobile","stateKey":"form-filled",'
              '"variant":"focus"}]',
        ),
      );
      expect(report.isValid, isTrue, reason: 'codes ${report.codes}');
    });

    test('an IDENTICAL state repeated IS refused', () {
      _expectRefused(
        _revision(
          statesRepresentedJson:
              '[{"boardId":"login-desktop",'
              '"stateKey":"form-filled","variant":"default"},'
              '{"boardId":"login-desktop","stateKey":"form-filled",'
              '"variant":"default"}]',
        ),
        FidelityAnchorViolationCode.duplicateItem,
        because: 'the same item twice is what uniqueItems refuses',
      );
    });

    test('a duplicate execution id is refused', () {
      _expectRefused(
        _revision(reviewExecutionIdsJson: '["$_reviewerA","$_reviewerA"]'),
        FidelityAnchorViolationCode.duplicateItem,
        because: 'uniqueItems makes a set a set',
      );
    });

    test('a duplicate boardId is refused', () {
      _expectRefused(
        _revision(
          boardIdsJson:
              '[{"boardId":"login-desktop","provider":"penpot",'
              '"providerFileId":"pf-1"},{"boardId":"login-desktop",'
              '"provider":"penpot","providerFileId":"pf-1"}]',
        ),
        FidelityAnchorViolationCode.duplicateItem,
        because: 'uniqueItems makes a set a set',
      );
    });

    test('a reviewScope with an unnamed key is refused', () {
      _expectRefused(
        _revision(reviewScopeJson: <String, dynamic>{'scope': 'full'}),
        FidelityAnchorViolationCode.unknownKey,
        because: '§3.5.1 row 6 — the null / {} / arbitrary-keys confusion',
      );
    });

    test('a reviewScope naming an uncheckable dimension is refused', () {
      _expectRefused(
        _revision(
          reviewScopeJson: <String, dynamic>{
            'dimensions': ['accessibility'],
          },
        ),
        FidelityAnchorViolationCode.notInVocabulary,
        because: 'the dimension vocabulary is closed',
      );
    });

    test('a NULL reviewScope is ACCEPTED — nullable is preserved', () {
      final report = _report(_revision(reviewScopeJson: null));
      expect(
        report.isValid,
        isTrue,
        reason: 'a null column is a conforming value: codes ${report.codes}',
      );
    });

    test(
      'an EMPTY reviewScope object is ACCEPTED and distinguished from null',
      () {
        final report = _report(_revision(reviewScopeJson: <String, dynamic>{}));
        expect(report.isValid, isTrue);
        expect(
          report.anchor!.reviewScope,
          isNotNull,
          reason: '{} and null must not collapse into one another on read',
        );
        expect(
          _report(_revision(reviewScopeJson: null)).anchor!.reviewScope,
          isNull,
        );
      },
    );

    test('an empty artifactRefsJson is ACCEPTED — minItems 0 is honest', () {
      expect(_report(_revision(artifactRefsJson: '[]')).isValid, isTrue);
    });

    test('an empty reviewExecutionIdsJson is ACCEPTED — a draft has no '
        'reviewer yet', () {
      expect(_report(_revision(reviewExecutionIdsJson: '[]')).isValid, isTrue);
    });
  });

  group('the two rules JSON Schema cannot express', () {
    test('§3.5.1 row 3: a state naming no board is refused', () {
      _expectRefused(
        _revision(
          statesRepresentedJson:
              '[{"boardId":"nowhere","stateKey":"form-filled",'
              '"variant":"default"}]',
        ),
        FidelityAnchorViolationCode.unresolvableBoardId,
        because: 'every named state must resolve into the same row\'s boardSet',
      );
    });

    test('§3.5.1 row 3: a state naming a board that IS present is accepted', () {
      final report = _report(
        _revision(
          statesRepresentedJson:
              '[{"boardId":"login-desktop",'
              '"stateKey":"a","variant":"default"},'
              '{"boardId":"login-desktop","stateKey":"b","variant":"loading"}]',
        ),
      );
      expect(report.isValid, isTrue, reason: 'codes ${report.codes}');
    });

    test('THE SEVENTH RULE: the designer listed as a reviewer is refused', () {
      _expectRefused(
        _revision(reviewExecutionIdsJson: '["$_designer"]'),
        FidelityAnchorViolationCode.designerIsItsOwnReviewer,
        because:
            'designerExecutionId must not be a member of '
            'reviewExecutionIdsJson',
      );
    });

    test('THE SEVENTH RULE: it fires on ONE extra member among many', () {
      // The falsifying input is not "a review list containing the designer and
      // nothing else"; it is a list that is otherwise perfectly ordinary.
      _expectRefused(
        _revision(reviewExecutionIdsJson: '["$_designer","$_reviewerA"]'),
        FidelityAnchorViolationCode.designerIsItsOwnReviewer,
        because: 'independence collapses at the root, not merely at dispatch',
      );
    });

    test('THE SEVENTH RULE: an empty reviewer list cannot violate it', () {
      // A draft revision has no reviewer at all, which is honest and must not be
      // reported as an independence violation.
      expect(_report(_revision(reviewExecutionIdsJson: '[]')).isValid, isTrue);
    });

    test('THE SEVENTH RULE: distinct reviewers are accepted', () {
      expect(
        _report(
          _revision(reviewExecutionIdsJson: '["$_reviewerA","$_reviewerB"]'),
        ).isValid,
        isTrue,
      );
    });

    test('THE SEVENTH RULE: requireValid raises rather than returning a '
        'report', () {
      expect(
        () => DesignRevisionFidelityAnchorValidator.requireValid(
          _revision(reviewExecutionIdsJson: '["$_designer"]'),
        ),
        throwsA(
          isA<DesignRevisionFidelityAnchorException>().having(
            (e) => e.violations.map((v) => v.code).toList(),
            'violation codes',
            contains(FidelityAnchorViolationCode.designerIsItsOwnReviewer),
          ),
        ),
      );
    });
  });

  group('§3.5.2 canonical form', () {
    test('the canonical fixture validates as already canonical', () {
      final report = _report(_revision());
      expect(
        report.isValid,
        isTrue,
        reason:
            'codes ${report.codes} — the fixture is canonical by '
            'construction, so a notCanonical here is a bug in the fixture',
      );
    });

    test('unsorted arrays are refused as not canonical', () {
      _expectRefused(
        _revision(
          responsiveTargetsJson:
              '[{"breakpoint":"xs","minViewportWidthCss":320},'
              '{"breakpoint":"lg","minViewportWidthCss":1024}]',
        ),
        FidelityAnchorViolationCode.notCanonical,
        because: '§3.5.2 rule 2: arrays sorted by the declared sort key',
      );
    });

    test('unsorted object keys are refused as not canonical', () {
      _expectRefused(
        _revision(
          boardIdsJson:
              '[{"provider":"penpot","boardId":"login-desktop",'
              '"providerFileId":"pf-1"}]',
        ),
        FidelityAnchorViolationCode.notCanonical,
        because: '§3.5.2 rule 1: keys sorted at every level',
      );
    });

    test('insignificant whitespace is refused as not canonical', () {
      _expectRefused(
        _revision(artifactRefsJson: '[ {"kind":"commit","ref":"abc"} ]'),
        FidelityAnchorViolationCode.notCanonical,
        because: '§3.5.2 rule 3: no insignificant whitespace',
      );
    });

    test('an unsorted reviewScope is refused, keys included', () {
      _expectRefused(
        _revision(
          reviewScopeJson: <String, dynamic>{
            'dimensions': ['responsive', 'a11y'],
            'boardIds': ['login-desktop'],
          },
        ),
        FidelityAnchorViolationCode.notCanonical,
        because: 'the scope is part of the anchor and its keys sort too',
      );
    });

    test('canonicalise turns an UNORDERED revision into a valid one', () {
      final unordered = _revision(
        responsiveTargetsJson:
            '[{"breakpoint":"xs","minViewportWidthCss":320},'
            '{"breakpoint":"lg","minViewportWidthCss":1024}]',
        reviewScopeJson: <String, dynamic>{
          'dimensions': ['responsive', 'a11y'],
          'boardIds': ['login-desktop'],
        },
      );
      expect(_report(unordered).isValid, isFalse);

      final canonical = DesignRevisionFidelityAnchorValidator.canonicalise(
        unordered,
      );
      final report = _report(canonical);
      expect(
        report.isValid,
        isTrue,
        reason:
            'canonicalise must produce a VALID revision, not merely a '
            'tidy one — codes ${report.codes}',
      );
    });

    test('canonicalise is idempotent — normalising twice is the same row', () {
      final once = DesignRevisionFidelityAnchorValidator.canonicalise(
        _revision(
          boardIdsJson:
              '[{"provider":"penpot","providerFileId":"pf-1",'
              '"boardId":"login-desktop"}]',
          responsiveTargetsJson:
              '[{"breakpoint":"xs","minViewportWidthCss":320},'
              '{"breakpoint":"lg","minViewportWidthCss":1024}]',
        ),
      );
      final twice = DesignRevisionFidelityAnchorValidator.canonicalise(once);
      expect(twice.boardIdsJson, once.boardIdsJson);
      expect(twice.reviewScopeJson, once.reviewScopeJson);
      expect(twice, once);
    });

    test('canonicalise leaves every other member untouched', () {
      final original = _revision();
      final canonical = DesignRevisionFidelityAnchorValidator.canonicalise(
        original,
      );
      expect(canonical.revisionId, original.revisionId);
      expect(canonical.workItemId, original.workItemId);
      expect(canonical.productId, original.productId);
      expect(canonical.designSystemRevision, original.designSystemRevision);
      expect(canonical.provider, original.provider);
      expect(canonical.penpotFileId, original.penpotFileId);
      expect(canonical.penpotPageId, original.penpotPageId);
      expect(canonical.designerExecutionId, original.designerExecutionId);
      expect(canonical.status, original.status);
      expect(canonical.riskTier, original.riskTier);
      expect(canonical.version, original.version);
    });

    test('canonicalise REFUSES to tidy a non-conforming revision', () {
      // Canonicalising a defective document would launder a defect into a tidy
      // defect, which is the opposite of fail-closed.
      expect(
        () => DesignRevisionFidelityAnchorValidator.canonicalise(
          _revision(boardIdsJson: '[]'),
        ),
        throwsA(isA<DesignRevisionFidelityAnchorException>()),
      );
    });

    test(
      'two encodings of the same set produce byte-identical column text',
      () {
        // This is the property §3.5.2 exists to buy: without it, diffing is not
        // possible at all.
        final ordered = _revision(
          responsiveTargetsJson:
              '[{"breakpoint":"xs","minViewportWidthCss":320},'
              '{"breakpoint":"lg","minViewportWidthCss":1024}]',
        );
        final shuffled = _revision(
          responsiveTargetsJson:
              '[{"breakpoint":"xs","minViewportWidthCss":320},'
              '{"breakpoint":"lg","minViewportWidthCss":1024}]',
        );
        final a = DesignRevisionFidelityAnchorValidator.canonicalise(ordered);
        final b = DesignRevisionFidelityAnchorValidator.canonicalise(shuffled);
        expect(b.responsiveTargetsJson, a.responsiveTargetsJson);
        expect(
          a.responsiveTargetsJson,
          '[{"breakpoint":"lg","minViewportWidthCss":1024},'
          '{"breakpoint":"xs","minViewportWidthCss":320}]',
        );
      },
    );

    test('two input orderings of a TIE-heavy set canonicalise identically', () {
      // The declared sort key cannot order entries that share it, and
      // `List.sort` is not documented as stable, so without a total order the
      // same revision could spell itself two different byte strings on two
      // different runs -- and a diff would report a difference that is not one.
      // 40 entries also puts the sort past Dart's small-list insertion-sort
      // path, where an unstable sort would actually bite.
      final boards = <String>[
        for (var i = 0; i < 40; i++)
          '{"boardId":"board-$i","provider":"penpot","providerFileId":"pf-1"}',
      ].toList();
      final states = <String>[
        for (var i = 0; i < 40; i++)
          '{"boardId":"board-$i","stateKey":"state",'
              '"variant":"default"}',
      ].toList();
      DesignRevision build(List<String> boardList, List<String> stateList) =>
          _revision(
            boardIdsJson: '[${boardList.join(',')}]',
            statesRepresentedJson: '[${stateList.join(',')}]',
          );

      final forward = DesignRevisionFidelityAnchorValidator.canonicalise(
        build(boards, states),
      );
      final reversed = DesignRevisionFidelityAnchorValidator.canonicalise(
        build(boards.reversed.toList(), states.reversed.toList()),
      );

      expect(
        reversed.statesRepresentedJson,
        forward.statesRepresentedJson,
        reason:
            'every entry shares the sort key "state", so only the '
            'tie-break can order this array',
      );
      expect(reversed.boardIdsJson, forward.boardIdsJson);
      expect(_report(forward).isValid, isTrue);
    });

    test('the canonical text carries no insignificant whitespace', () {
      final canonical = DesignRevisionFidelityAnchorValidator.canonicalise(
        _revision(),
      );
      for (final entry in DesignRevisionFidelityAnchorValidator.requireValid(
        canonical,
      ).toCanonicalColumnText().entries) {
        expect(
          entry.value,
          isNot(contains(' ')),
          reason: '${entry.key} is ${entry.value}',
        );
      }
    });
  });

  group('§3.5.4: disagreement between the two anchors is REPORTED, never a '
      'gate', () {
    test('agreeing anchors report nothing', () {
      final anchor = DesignRevisionFidelityAnchorValidator.requireValid(
        _revision(),
      );
      expect(
        DesignRevisionFidelityAnchorDisagreements.between(_revision(), anchor),
        isEmpty,
      );
    });

    test('a null penpotFileId while boards are named IS a disagreement', () {
      final openable = _revision();
      final anchor = DesignRevisionFidelityAnchorValidator.requireValid(
        openable,
      );
      final reported = DesignRevisionFidelityAnchorDisagreements.between(
        _revisionWithPenpot(openable, fileId: null),
        anchor,
      );
      expect(
        reported.map((d) => d.kind),
        contains(FidelityAnchorDisagreementKind.penpotFileIdMissing),
      );
    });

    test('a board naming a different file than the revision IS a '
        'disagreement', () {
      final other = _revisionWithPenpot(_revision(), fileId: 'pf-OTHER');
      final anchor = DesignRevisionFidelityAnchorValidator.requireValid(other);
      final reported = DesignRevisionFidelityAnchorDisagreements.between(
        other,
        anchor,
      );
      expect(
        reported.map((d) => d.kind),
        contains(FidelityAnchorDisagreementKind.providerFileIdMismatch),
      );
    });

    test('boards spanning two files IS a disagreement', () {
      final spread = _revision(
        boardIdsJson:
            '[{"boardId":"login-desktop","provider":"penpot",'
            '"providerFileId":"pf-1"},'
            '{"boardId":"login-mobile","provider":"penpot",'
            '"providerFileId":"pf-2"}]',
      );
      final anchor = DesignRevisionFidelityAnchorValidator.requireValid(spread);
      final reported = DesignRevisionFidelityAnchorDisagreements.between(
        spread,
        anchor,
      );
      expect(
        reported.map((d) => d.kind),
        contains(FidelityAnchorDisagreementKind.multipleProviderFiles),
      );
    });

    test('a disagreement does NOT make the revision invalid', () {
      // The decisive property. If a disagreement could fail validation it would
      // be resolving the disagreement by picking the schema as the winner --
      // exactly what operator decision a1c7d904 forbids.
      final spread = _revision(
        boardIdsJson:
            '[{"boardId":"login-desktop","provider":"penpot",'
            '"providerFileId":"pf-1"},'
            '{"boardId":"login-mobile","provider":"penpot",'
            '"providerFileId":"pf-2"}]',
      );
      final report = _report(spread);
      expect(report.isValid, isTrue, reason: 'codes ${report.codes}');
      expect(
        DesignRevisionFidelityAnchorDisagreements.between(
          spread,
          report.anchor!,
        ),
        isNotEmpty,
        reason: 'and the disagreement is still reported',
      );
    });

    test('the disagreement list is stable and unmodifiable', () {
      final spread = _revision(
        boardIdsJson:
            '[{"boardId":"login-desktop","provider":"penpot",'
            '"providerFileId":"pf-1"},'
            '{"boardId":"login-mobile","provider":"penpot",'
            '"providerFileId":"pf-2"}]',
      );
      final anchor = DesignRevisionFidelityAnchorValidator.requireValid(spread);
      final first = DesignRevisionFidelityAnchorDisagreements.between(
        spread,
        anchor,
      );
      final second = DesignRevisionFidelityAnchorDisagreements.between(
        spread,
        anchor,
      );
      expect(second, first);
      expect(
        () => first.add(
          const FidelityAnchorDisagreement(
            kind: FidelityAnchorDisagreementKind.penpotFileIdMissing,
            detail: 'x',
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('the Dart validator and the committed schema AGREE', () {
    // One corpus, two engines. Canonicity and the two cross-column rules are
    // excluded on purpose: JSON Schema cannot express either, which is exactly
    // why §3.5.1 calls the seventh rule a validator assertion.
    final document = _anchorDocument();
    const corpus = <({String column, String subschema, Object? value})>[
      (column: 'boardIdsJson', subschema: 'boardSet', value: null),
      (column: 'boardIdsJson', subschema: 'boardSet', value: <dynamic>[]),
      (
        column: 'boardIdsJson',
        subschema: 'boardSet',
        value: <dynamic>[
          <String, dynamic>{
            'boardId': 'login-desktop',
            'provider': 'penpot',
            'providerFileId': 'pf-1',
          },
        ],
      ),
      (
        column: 'boardIdsJson',
        subschema: 'boardSet',
        value: <dynamic>[
          <String, dynamic>{'boardId': 'login-desktop', 'provider': 'penpot'},
        ],
      ),
      (
        column: 'boardIdsJson',
        subschema: 'boardSet',
        value: <dynamic>[
          <String, dynamic>{
            'boardId': 'login desktop',
            'provider': 'penpot',
            'providerFileId': 'pf-1',
          },
        ],
      ),
      (
        column: 'boardIdsJson',
        subschema: 'boardSet',
        value: <dynamic>[
          <String, dynamic>{
            'boardId': 'login-desktop',
            'provider': 'figma',
            'providerFileId': 'pf-1',
          },
        ],
      ),
      (
        column: 'boardIdsJson',
        subschema: 'boardSet',
        value: <dynamic>[
          <String, dynamic>{
            'boardId': 'login-desktop',
            'provider': 'penpot',
            'providerFileId': '',
          },
        ],
      ),
      (
        column: 'boardIdsJson',
        subschema: 'boardSet',
        value: <dynamic>[
          <String, dynamic>{
            'boardId': 'login-desktop',
            'provider': 'penpot',
            'providerFileId': 'pf-1',
          },
          <String, dynamic>{
            'boardId': 'login-desktop',
            'provider': 'penpot',
            'providerFileId': 'pf-1',
          },
        ],
      ),
      (
        column: 'boardIdsJson',
        subschema: 'boardSet',
        value: <dynamic>['login-desktop'],
      ),
      (
        column: 'boardIdsJson',
        subschema: 'boardSet',
        value: <dynamic>[
          <String, dynamic>{
            'boardId': 'login-desktop',
            'provider': 'penpot',
            'providerFileId': 'pf-1',
            'boardName': '',
          },
        ],
      ),
      (
        column: 'boardIdsJson',
        subschema: 'boardSet',
        value: <dynamic>[
          <String, dynamic>{
            'boardId': 'login-desktop',
            'provider': 'penpot',
            'providerFileId': 'pf-1',
            'boardName': 7,
          },
        ],
      ),
      (
        column: 'responsiveTargetsJson',
        subschema: 'responsiveSet',
        value: <dynamic>[],
      ),
      (
        column: 'responsiveTargetsJson',
        subschema: 'responsiveSet',
        value: <dynamic>[
          <String, dynamic>{'breakpoint': 'xs', 'minViewportWidthCss': 320},
        ],
      ),
      (
        column: 'responsiveTargetsJson',
        subschema: 'responsiveSet',
        value: <dynamic>[
          <String, dynamic>{'breakpoint': 'xs', 'minViewportWidthCss': 320.5},
        ],
      ),
      (
        column: 'responsiveTargetsJson',
        subschema: 'responsiveSet',
        value: <dynamic>[
          <String, dynamic>{'breakpoint': 'xs', 'minViewportWidthCss': 4097},
        ],
      ),
      (
        column: 'responsiveTargetsJson',
        subschema: 'responsiveSet',
        value: <dynamic>[
          <String, dynamic>{'breakpoint': 'tablet', 'minViewportWidthCss': 800},
        ],
      ),
      (
        column: 'responsiveTargetsJson',
        subschema: 'responsiveSet',
        value: <dynamic>[
          <String, dynamic>{
            'breakpoint': 'xs',
            'minViewportWidthCss': 320,
            'orientation': 'sideways',
          },
        ],
      ),
      (
        column: 'responsiveTargetsJson',
        subschema: 'responsiveSet',
        value: <dynamic>[
          <String, dynamic>{'breakpoint': 'xs'},
        ],
      ),
      (
        column: 'statesRepresentedJson',
        subschema: 'stateSet',
        value: <dynamic>[],
      ),
      (
        column: 'statesRepresentedJson',
        subschema: 'stateSet',
        value: <dynamic>[
          <String, dynamic>{
            'boardId': 'login-desktop',
            'stateKey': 'form-filled',
            'variant': 'default',
          },
        ],
      ),
      (
        column: 'statesRepresentedJson',
        subschema: 'stateSet',
        value: <dynamic>[
          <String, dynamic>{
            'boardId': 'login-desktop',
            'stateKey': '',
            'variant': 'default',
          },
        ],
      ),
      (
        column: 'statesRepresentedJson',
        subschema: 'stateSet',
        value: <dynamic>[
          <String, dynamic>{
            'boardId': 'login-desktop',
            'stateKey': 'a',
            'variant': 'sparkle',
          },
        ],
      ),
      (
        column: 'artifactRefsJson',
        subschema: 'artifactSet',
        value: <dynamic>[],
      ),
      (
        column: 'artifactRefsJson',
        subschema: 'artifactSet',
        value: <dynamic>[
          <String, dynamic>{'kind': 'commit', 'ref': 'abc123'},
        ],
      ),
      (
        column: 'artifactRefsJson',
        subschema: 'artifactSet',
        value: <dynamic>[
          <String, dynamic>{'kind': 'screenshot', 'ref': 'x.png'},
        ],
      ),
      (
        column: 'artifactRefsJson',
        subschema: 'artifactSet',
        value: <dynamic>[
          <String, dynamic>{'kind': 'commit'},
        ],
      ),
      (
        column: 'artifactRefsJson',
        subschema: 'artifactSet',
        value: <dynamic>[
          <String, dynamic>{'kind': 'commit', 'ref': 'abc'},
          <String, dynamic>{'kind': 'commit', 'ref': 'abc'},
        ],
      ),
      (
        column: 'reviewExecutionIdsJson',
        subschema: 'executionIdSet',
        value: <dynamic>[],
      ),
      (
        column: 'reviewExecutionIdsJson',
        subschema: 'executionIdSet',
        value: <dynamic>['exec-1'],
      ),
      (
        column: 'reviewExecutionIdsJson',
        subschema: 'executionIdSet',
        value: <dynamic>[''],
      ),
      (
        column: 'reviewExecutionIdsJson',
        subschema: 'executionIdSet',
        value: <dynamic>[1],
      ),
      (
        column: 'reviewExecutionIdsJson',
        subschema: 'executionIdSet',
        value: <dynamic>['a', 'a'],
      ),
    ];

    for (final entry in corpus) {
      test('${entry.column} <-> ${entry.subschema}: '
          '${jsonEncode(entry.value)}', () {
        final text = entry.value == null ? '' : jsonEncode(entry.value);
        final revision = _revisionWithColumn(entry.column, text);

        // Canonicity off: array ORDER is not expressible in JSON Schema, so
        // including it here would compare the engines on something the
        // document deliberately does not say.
        final dartViolations = DesignRevisionFidelityAnchorValidator.validate(
          revision,
          requireCanonical: false,
        ).violations.where((v) => v.column == entry.column);

        final schemaAccepts = _schemaAcceptsSubschema(
          document,
          entry.subschema,
          entry.value,
        );

        expect(
          dartViolations.isEmpty,
          schemaAccepts,
          reason:
              'Dart and the committed schema disagree on '
              '${entry.column} = ${jsonEncode(entry.value)}; '
              'Dart said ${dartViolations.map((v) => v.code).toList()}, '
              'schema accepted=$schemaAccepts',
        );
      });
    }
  });
}

/// A revision whose [column] carries [text] and whose other five columns keep
/// the canonical fixture's conforming values.
///
/// Every other column must stay VALID: the comparison is per-column, so a case
/// that also broke a second column would make "the schema rejected" and "the
/// Dart validator rejected" agree for the wrong reason.
DesignRevision _revisionWithColumn(String column, String text) =>
    switch (column) {
      'boardIdsJson' => _revision(boardIdsJson: text),
      'responsiveTargetsJson' => _revision(responsiveTargetsJson: text),
      'statesRepresentedJson' => _revision(statesRepresentedJson: text),
      'artifactRefsJson' => _revision(artifactRefsJson: text),
      'reviewExecutionIdsJson' => _revision(reviewExecutionIdsJson: text),
      _ => throw ArgumentError('the corpus has no case for column $column'),
    };

/// A bundle assembled from the committed example, for root-level assertions.
Map<String, dynamic> _bundleFromExample() =>
    jsonDecode(
          File(
            '$_schemasRoot/examples/$_anchorName.example.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

/// Builds a revision whose six columns are the six values of [bundle].
///
/// Used to assert that the Dart validator accepts the very instance the
/// committed example declares — the two engines must agree about the EXAMPLE,
/// not only about hand-built cases.
DesignRevision _revisionFromBundle(Map<String, dynamic> bundle) => _revision(
  boardIdsJson: jsonEncode(bundle['boardIds']),
  responsiveTargetsJson: jsonEncode(bundle['responsiveTargets']),
  statesRepresentedJson: jsonEncode(bundle['statesRepresented']),
  artifactRefsJson: jsonEncode(bundle['artifactRefs']),
  reviewExecutionIdsJson: jsonEncode(bundle['reviewExecutionIds']),
  reviewScopeJson: (bundle['reviewScope'] as Map<String, dynamic>?),
);

/// [revision] with its Penpot columns replaced, everything else untouched.
///
/// The two Penpot columns are NOT part of the anchor bundle — they are the
/// revision's own pointer to the human anchor, which is why a disagreement
/// between the two is a separate report rather than a bundle constraint.
DesignRevision _revisionWithPenpot(
  DesignRevision revision, {
  String? fileId,
  String? pageId = 'pp-1',
}) => DesignRevision(
  revisionId: revision.revisionId,
  workItemId: revision.workItemId,
  productId: revision.productId,
  parentRevisionId: revision.parentRevisionId,
  designSystemRevision: revision.designSystemRevision,
  provider: revision.provider,
  penpotFileId: fileId,
  penpotPageId: pageId,
  boardIdsJson: revision.boardIdsJson,
  responsiveTargetsJson: revision.responsiveTargetsJson,
  statesRepresentedJson: revision.statesRepresentedJson,
  artifactRefsJson: revision.artifactRefsJson,
  designerExecutionId: revision.designerExecutionId,
  reviewExecutionIdsJson: revision.reviewExecutionIdsJson,
  status: revision.status,
  riskTier: revision.riskTier,
  reviewScopeJson: revision.reviewScopeJson,
  carriedForwardFromRevisionId: revision.carriedForwardFromRevisionId,
  supersededByRevisionId: revision.supersededByRevisionId,
  createdAt: revision.createdAt,
  updatedAt: revision.updatedAt,
  approvedAt: revision.approvedAt,
  version: revision.version,
);
