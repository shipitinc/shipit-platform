/// The fidelity anchor for a `design_revision` row.
///
/// ## What this is, and why the schema alone was not enough
///
/// `design-revision.md` §3.5 (operator decision
/// `a1c7d904-3b8e-4f21-9d6e-5c2f81b7a390`) settles the anchor's CONTENT: one
/// committed, versioned JSON schema — [designRevisionFidelityAnchorSchemaId] —
/// is what the MACHINE diffs an implementation against, and Penpot is what a
/// HUMAN reviewer reads. §3.3 is the gap it closes: the six `design_revision`
/// JSON blob columns are bare `type: string` in
/// `schemas/design_revision.schema.json`, so an implementation rendering none
/// of a revision's boards string-equalled one rendering all of them, and ADR
/// 0021 §2's "divergence from approved design is itself a defect" had nothing
/// to decide against.
///
/// ## Why the checks live in Dart rather than reading the `.json` at runtime
///
/// `json_schema` is a DEV dependency of this package and a runtime dependency of
/// nothing in the tree, so a runtime path cannot evaluate the committed document
/// without a pubspec change this module does not own. The rules are therefore
/// transcribed here and PINNED to the document by
/// `test/design_revision_fidelity_anchor_test.dart`, which evaluates one shared
/// corpus through BOTH this class and the committed `.json` via `json_schema`
/// and fails on any disagreement. That test is what stops this file and the
/// schema from drifting into two vocabularies — the `92d567e3` lesson applied
/// to the anchor itself. It reads the `definitions.*` and `x-sort-key`
/// declarations straight out of the document, so renaming a vocabulary in the
/// schema without changing it here fails.
///
/// ## What is deliberately NOT here
///
/// The anchor describes only what a revision CLAIMS. Whether an implementation
/// then honoured the claim is §3.5.4's comparison basis, which is step 6's
/// producer work, and the Penpot/JSON disagreement rule, which is REPORTED as a
/// finding rather than turned into a gate.
library;

import 'dart:convert';

import 'package:meta/meta.dart';

import '../types/design_revision.dart';

/// The `$id` of the committed anchor document, `schemas/1.0.0/…`.
///
/// Versioned IN the `$id`, not in a sibling field, so a `$ref` cannot silently
/// resolve across a schema change. [designRevisionFidelityAnchorSchemaVersion]
/// is the value a row records against this identifier.
const String designRevisionFidelityAnchorSchemaId =
    'https://shipit.platform/schemas/1.0.0/'
    'design_revision_fidelity_anchor.schema.json';

/// The `1.0.0` of [designRevisionFidelityAnchorSchemaId].
///
/// §3.5.2 rule 4 asks for a `fidelityAnchorSchemaVersion` column so a schema
/// change does not silently reinterpret every row already stored. The value
/// that column carries is this constant.
const String designRevisionFidelityAnchorSchemaVersion = '1.0.0';

/// The repo-relative path of the committed document, for tools and messages.
const String designRevisionFidelityAnchorSchemaPath =
    'schemas/design_revision_fidelity_anchor.schema.json';

/// The six bundle keys, in the canonical (sorted) order §3.5.2 rule 1 produces.
///
/// Each maps to the `design_revision` column whose decoded value it holds.
const List<String> designRevisionFidelityAnchorBundleKeys = <String>[
  'artifactRefs',
  'boardIds',
  'responsiveTargets',
  'reviewExecutionIds',
  'reviewScope',
  'statesRepresented',
];

/// `boardId` pattern, transcribed from `#/definitions/boardId`.
final RegExp fidelityAnchorBoardIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// Closed provider vocabulary, from `#/definitions/boardSet`.
const List<String> fidelityAnchorBoardProviders = <String>['penpot'];

/// Closed breakpoint vocabulary — THE design-system link (§3.5.1 row 2).
const List<String> fidelityAnchorBreakpoints = <String>[
  'xs',
  'sm',
  'md',
  'lg',
  'xl',
  '2xl',
];

/// Closed orientation vocabulary, from `#/definitions/responsiveSet`.
const List<String> fidelityAnchorOrientations = <String>[
  'portrait',
  'landscape',
];

/// Closed state-variant vocabulary, from `#/definitions/stateSet`.
const List<String> fidelityAnchorStateVariants = <String>[
  'default',
  'loading',
  'empty',
  'error',
  'success',
  'disabled',
  'focus',
  'readonly',
];

/// Closed artifact-kind vocabulary, from `#/definitions/artifactSet`.
const List<String> fidelityAnchorArtifactKinds = <String>[
  'commit',
  'diff',
  'file',
  'url',
  'penpot-component',
  'penpot-asset',
  'qadoc',
];

/// Closed review-dimension vocabulary, from `#/definitions/reviewScope`.
const List<String> fidelityAnchorReviewDimensions = <String>[
  'layout',
  'typography',
  'color',
  'contrast',
  'motion',
  'responsive',
  'content',
  'a11y',
  'state-coverage',
  'brand',
];

/// One board claimed by a revision.
@immutable
class FidelityAnchorBoard {
  const FidelityAnchorBoard({
    required this.boardId,
    required this.provider,
    required this.providerFileId,
    this.boardName,
  });

  final String boardId;
  final String provider;

  /// Required INSIDE the blob. Its absence is the nullable-`penpotFileId` hole
  /// this anchor closes (§3.5.1 row 1).
  final String providerFileId;
  final String? boardName;

  /// Canonical key order: lexicographic at every level (§3.5.2 rule 1).
  Map<String, dynamic> toCanonicalJson() => <String, dynamic>{
    'boardId': boardId,
    if (boardName != null) 'boardName': boardName,
    'provider': provider,
    'providerFileId': providerFileId,
  };
}

/// One responsive target claimed by a revision.
@immutable
class FidelityAnchorResponsiveTarget {
  const FidelityAnchorResponsiveTarget({
    required this.breakpoint,
    required this.minViewportWidthCss,
    this.orientation,
  });

  final String breakpoint;
  final int minViewportWidthCss;
  final String? orientation;

  Map<String, dynamic> toCanonicalJson() => <String, dynamic>{
    'breakpoint': breakpoint,
    'minViewportWidthCss': minViewportWidthCss,
    if (orientation != null) 'orientation': orientation,
  };
}

/// One UI state claimed by a revision, bound to the board that renders it.
@immutable
class FidelityAnchorState {
  const FidelityAnchorState({
    required this.stateKey,
    required this.boardId,
    required this.variant,
  });

  final String stateKey;
  final String boardId;
  final String variant;

  Map<String, dynamic> toCanonicalJson() => <String, dynamic>{
    'boardId': boardId,
    'stateKey': stateKey,
    'variant': variant,
  };
}

/// One traceable artifact claimed by a revision.
@immutable
class FidelityAnchorArtifactRef {
  const FidelityAnchorArtifactRef({required this.kind, required this.ref});

  final String kind;
  final String ref;

  Map<String, dynamic> toCanonicalJson() => <String, dynamic>{
    'kind': kind,
    'ref': ref,
  };
}

/// The optional, nullable review scope.
@immutable
class FidelityAnchorReviewScope {
  const FidelityAnchorReviewScope({this.dimensions, this.boardIds});

  final List<String>? dimensions;
  final List<String>? boardIds;

  Map<String, dynamic> toCanonicalJson() => <String, dynamic>{
    if (boardIds != null) 'boardIds': boardIds,
    if (dimensions != null) 'dimensions': dimensions,
  };
}

/// The decoded bundle of all six blob columns of ONE `design_revision` row.
///
/// The unit of validation is the bundle, not the column, because §3.5.1 row 3's
/// rule is cross-column: a `stateSet.boardId` must resolve into the same row's
/// `boardSet`. Validating the six columns independently would make that rule
/// unstatable, which is the gap §3.5 exists to close.
@immutable
class DesignRevisionFidelityAnchor {
  const DesignRevisionFidelityAnchor({
    required this.boardIds,
    required this.responsiveTargets,
    required this.statesRepresented,
    required this.artifactRefs,
    required this.reviewExecutionIds,
    required this.reviewScope,
  });

  final List<FidelityAnchorBoard> boardIds;
  final List<FidelityAnchorResponsiveTarget> responsiveTargets;
  final List<FidelityAnchorState> statesRepresented;
  final List<FidelityAnchorArtifactRef> artifactRefs;
  final List<String> reviewExecutionIds;
  final FidelityAnchorReviewScope? reviewScope;

  /// The bundle as the committed document's instance: keys in canonical order,
  /// arrays in sort-key order, `reviewScope` present and possibly `null`.
  Map<String, dynamic> toCanonicalJson() => <String, dynamic>{
    'artifactRefs': artifactRefs
        .map((e) => e.toCanonicalJson())
        .toList(growable: false),
    'boardIds': boardIds
        .map((e) => e.toCanonicalJson())
        .toList(growable: false),
    'responsiveTargets': responsiveTargets
        .map((e) => e.toCanonicalJson())
        .toList(growable: false),
    'reviewExecutionIds': List<String>.of(reviewExecutionIds),
    'reviewScope': reviewScope?.toCanonicalJson(),
    'statesRepresented': statesRepresented
        .map((e) => e.toCanonicalJson())
        .toList(growable: false),
  };

  /// The canonical, whitespace-free JSON TEXT of each column, keyed by the
  /// `design_revision` column it is written to.
  ///
  /// §3.5.2 rule 3 ("no insignificant whitespace") is what makes two encodings
  /// of the same revision byte-identical, which is the precondition for diffing
  /// at all.
  Map<String, String> toCanonicalColumnText() {
    final json = toCanonicalJson();
    return <String, String>{
      'boardIdsJson': jsonEncode(json['boardIds']),
      'responsiveTargetsJson': jsonEncode(json['responsiveTargets']),
      'statesRepresentedJson': jsonEncode(json['statesRepresented']),
      'artifactRefsJson': jsonEncode(json['artifactRefs']),
      'reviewExecutionIdsJson': jsonEncode(json['reviewExecutionIds']),
      'reviewScopeJson': jsonEncode(json['reviewScope']),
    };
  }
}

/// One way a revision's anchor fails to conform.
///
/// [code] is stable and machine-readable: a reviewer, a test and a future
/// `designContract` gate all key on it rather than on [detail]'s prose.
@immutable
class DesignRevisionFidelityAnchorViolation {
  const DesignRevisionFidelityAnchorViolation({
    required this.column,
    required this.code,
    required this.detail,
  });

  /// The `design_revision` column at fault, or `bundle` for a rule that spans
  /// columns (the cross-column referential-integrity rule and the seventh rule).
  final String column;

  /// Stable machine-readable code. See [FidelityAnchorViolationCode].
  final String code;
  final String detail;

  @override
  String toString() => '$column/$code: $detail';

  @override
  bool operator ==(Object other) =>
      other is DesignRevisionFidelityAnchorViolation &&
      other.column == column &&
      other.code == code &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(column, code, detail);
}

/// The outcome of validating a revision against the committed anchor.
@immutable
class DesignRevisionFidelityAnchorReport {
  const DesignRevisionFidelityAnchorReport._(this.violations, this.anchor);

  /// Every violation found, in a stable order: the six columns in the order
  /// §3.5.1's table lists them, then the cross-column rule, then the seventh
  /// rule, then canonicity. A caller therefore sees the same list for the same
  /// input, which is what makes the report assertable.
  final List<DesignRevisionFidelityAnchorViolation> violations;

  /// The decoded anchor, present only when [isValid]. There is deliberately no
  /// "best effort" access to a non-conforming decode: a caller holding a
  /// partially-parsed anchor would be diffing against a document the platform
  /// has already declared malformed, which is the `notExecuted`-counts-as-
  /// satisfied class §3.5.3 rules out.
  final DesignRevisionFidelityAnchor? anchor;

  bool get isValid => violations.isEmpty;

  /// The codes of every violation, in order. What a test asserts on so it names
  /// the rule it is exercising rather than "something was rejected".
  List<String> get codes =>
      violations.map((v) => v.code).toList(growable: false);

  /// The code of the first violation, or `null` when valid — the single thing a
  /// fail-closed write path needs in order to decide whether to persist.
  String? get firstCode => violations.isEmpty ? null : violations.first.code;
}

/// Raised when a revision that does not conform to the committed anchor reaches
/// a write path that must fail closed.
///
/// A distinct type so a caller can catch a REJECTION rather than a transport
/// failure: §3.5.3's whole content is that a non-conforming revision is not
/// persisted, and a rejection arriving as some other exception type is
/// indistinguishable from the database being down.
class DesignRevisionFidelityAnchorException implements Exception {
  DesignRevisionFidelityAnchorException(this.revisionId, this.violations);

  final String revisionId;
  final List<DesignRevisionFidelityAnchorViolation> violations;

  /// The anchor document and version a rejection names, so the message says
  /// WHICH contract was refused rather than only that something was.
  String get schemaReference =>
      '$designRevisionFidelityAnchorSchemaPath '
      '($designRevisionFidelityAnchorSchemaVersion)';

  @override
  String toString() {
    final rendered = violations.map((v) => '  - $v').join('\n');
    return 'DesignRevision $revisionId does not conform to '
        '$schemaReference and is NOT persisted. Violations:\n$rendered';
  }
}

/// Codes carried by [DesignRevisionFidelityAnchorViolation.code].
///
/// Each is a distinct way the anchor can be violated, so a test can name the one
/// it is exercising instead of asserting "something was rejected".
abstract final class FidelityAnchorViolationCode {
  /// The column's `text` is not the JSON document its subschema requires.
  static const String notJson = 'notJson';

  /// A member is not of the type its subschema requires.
  static const String wrongType = 'wrongType';

  /// An unknown key — §3.5.1: "a claim the platform cannot check".
  static const String unknownKey = 'unknownKey';

  /// A required member is absent.
  static const String missingMember = 'missingMember';

  /// A value outside a closed `enum`.
  static const String notInVocabulary = 'notInVocabulary';

  /// A string that is not `pattern`/`minLength`-constrained.
  static const String unconstrainedString = 'unconstrainedString';

  /// A number outside its declared bounds.
  static const String outOfRange = 'outOfRange';

  /// `minItems` unsatisfied — a set that asserts nothing.
  static const String tooFewItems = 'tooFewItems';

  /// `uniqueItems` unsatisfied — a set that is not a set.
  static const String duplicateItem = 'duplicateItem';

  /// A `stateSet.boardId` naming no board in the same row's `boardSet`.
  static const String unresolvableBoardId = 'unresolvableBoardId';

  /// The seventh rule: `designerExecutionId` is a member of
  /// `reviewExecutionIdsJson`. JSON Schema cannot express it — it compares two
  /// fields of the record — so §3.5.1 names it as a validator assertion and
  /// here it is one.
  static const String designerIsItsOwnReviewer = 'designerIsItsOwnReviewer';

  /// The column parses and conforms but is not in §3.5.2's canonical form.
  static const String notCanonical = 'notCanonical';
}

/// The validator: §3.5.1's six subschemas, §3.5.2's canonical form, and the two
/// rules JSON Schema cannot state.
abstract final class DesignRevisionFidelityAnchorValidator {
  /// Validates [revision] against the committed anchor, canonicity included.
  ///
  /// Reports EVERY violation rather than the first, so one run tells a caller
  /// everything that is wrong — the difference between a fixable report and a
  /// fix-one-rerun loop.
  static DesignRevisionFidelityAnchorReport validate(
    DesignRevision revision, {
    bool requireCanonical = true,
  }) => _validate(revision, requireCanonical: requireCanonical);

  /// Validates [revision] and THROWS [DesignRevisionFidelityAnchorException] if
  /// it does not conform.
  ///
  /// This is the fail-closed entry point: it returns an anchor or it raises. It
  /// never returns a revision alongside a warning — §3.5.3's "not
  /// persisted-then-flagged" is the exact shape this refuses.
  static DesignRevisionFidelityAnchor requireValid(DesignRevision revision) {
    final anchor = _validate(revision, requireCanonical: true).anchor;
    if (anchor == null) {
      throw DesignRevisionFidelityAnchorException(
        revision.revisionId,
        _validate(revision, requireCanonical: true).violations,
      );
    }
    return anchor;
  }

  /// Returns [revision] with all six blob columns rewritten to §3.5.2's
  /// canonical form, so the stored value is already canonical and never has to
  /// be normalised twice.
  ///
  /// Canonicity is DROPPED for this call only: the point is to produce a
  /// canonical revision from a merely-UNORDERED one, which is the overwhelmingly
  /// common case. Every other rule still applies, and a revision that fails one
  /// throws — canonicalising a document that does not conform would launder a
  /// defect into a tidy defect.
  static DesignRevision canonicalise(DesignRevision revision) {
    final report = _validate(revision, requireCanonical: false);
    final anchor = report.anchor;
    if (anchor == null) {
      throw DesignRevisionFidelityAnchorException(
        revision.revisionId,
        report.violations,
      );
    }
    return _copyWithColumnText(revision, anchor);
  }

  static DesignRevisionFidelityAnchorReport _validate(
    DesignRevision revision, {
    required bool requireCanonical,
  }) {
    final violations = <DesignRevisionFidelityAnchorViolation>[];

    // §3.5.1's table order, so the report is stable.
    final boardIdsJson = _decodeArray(revision.boardIdsJson, 'boardIdsJson');
    final responsiveJson = _decodeArray(
      revision.responsiveTargetsJson,
      'responsiveTargetsJson',
    );
    final statesJson = _decodeArray(
      revision.statesRepresentedJson,
      'statesRepresentedJson',
    );
    final artifactsJson = _decodeArray(
      revision.artifactRefsJson,
      'artifactRefsJson',
    );
    final reviewersJson = _decodeArray(
      revision.reviewExecutionIdsJson,
      'reviewExecutionIdsJson',
    );

    final boards = _parseBoards(boardIdsJson, violations);
    final responsive = _parseResponsiveTargets(responsiveJson, violations);
    final states = _parseStates(statesJson, violations);
    final artifacts = _parseArtifactRefs(artifactsJson, violations);
    final reviewers = _parseExecutionIds(reviewersJson, violations);
    final scope = _parseReviewScope(revision.reviewScopeJson, violations);

    // §3.5.1 row 3: cross-column referential integrity. JSON Schema cannot
    // express "this array's boardId resolves into that array", so it is checked
    // here over the bundle.
    if (boardIdsJson != null && statesJson != null) {
      final known = boards.map((b) => b.boardId).toSet();
      final sorted = known.toList()..sort();
      for (final state in states) {
        if (!known.contains(state.boardId)) {
          violations.add(
            DesignRevisionFidelityAnchorViolation(
              column: 'bundle',
              code: FidelityAnchorViolationCode.unresolvableBoardId,
              detail:
                  'statesRepresentedJson names board "${state.boardId}", '
                  'which is not in boardIdsJson $sorted. Every named state '
                  'must resolve into the same row\'s boardSet.',
            ),
          );
        }
      }
    }

    // §3.5.1's seventh rule, named because JSON Schema cannot express it: the
    // designer is never also a reviewer of their own revision (checkpoint 003
    // §7.1; this is the field `designReviewRequest` turns into
    // `excludedExecutionIds`).
    if (reviewersJson != null &&
        reviewers.contains(revision.designerExecutionId)) {
      violations.add(
        DesignRevisionFidelityAnchorViolation(
          column: 'bundle',
          code: FidelityAnchorViolationCode.designerIsItsOwnReviewer,
          detail:
              'designerExecutionId "${revision.designerExecutionId}" is a '
              'member of reviewExecutionIdsJson. The designer is never also a '
              'reviewer of their own revision.',
        ),
      );
    }

    // Only a fully-conforming decode is handed back. §3.5.3: a flagged row is
    // readable by a reader that never checks the flag, so there is no partial
    // anchor to give out.
    if (violations.isNotEmpty) return _report(violations);

    final anchor = DesignRevisionFidelityAnchor(
      boardIds: _sortedBy(boards, (b) => b.boardId, _boardOrdering),
      responsiveTargets: _sortedBy(
        responsive,
        (t) => t.breakpoint,
        _breakpointOrdering,
      ),
      statesRepresented: _sortedBy(states, (s) => s.stateKey, _stateOrdering),
      artifactRefs: _sortedBy(
        artifacts,
        (a) => '${a.kind} ${a.ref}',
        _artifactRefOrdering,
      ),
      reviewExecutionIds: _sorted(reviewers, (a, b) => a.compareTo(b)),
      reviewScope: scope,
    );

    if (requireCanonical) {
      // §3.5.2 rule 3 is a VALIDATION requirement, not only a formatting one:
      // a stored value that parses but is not canonical is a SECOND encoding of
      // the same revision, which breaks the precondition for diffing.
      final canonical = anchor.toCanonicalColumnText();
      for (final entry in canonical.entries) {
        final stored = _columnTextOf(revision, entry.key);
        if (stored != entry.value) {
          violations.add(
            DesignRevisionFidelityAnchorViolation(
              column: entry.key,
              code: FidelityAnchorViolationCode.notCanonical,
              detail:
                  'not in canonical form: object keys sorted at every '
                  'level, arrays sorted by their declared sort key, no '
                  'insignificant whitespace. Expected ${entry.value}, got '
                  '$stored.',
            ),
          );
        }
      }
      if (violations.isNotEmpty) return _report(violations);
    }

    return DesignRevisionFidelityAnchorReport._(
      const <DesignRevisionFidelityAnchorViolation>[],
      anchor,
    );
  }

  static DesignRevisionFidelityAnchorReport _report(
    List<DesignRevisionFidelityAnchorViolation> violations,
  ) => DesignRevisionFidelityAnchorReport._(
    List<DesignRevisionFidelityAnchorViolation>.unmodifiable(violations),
    null,
  );

  // ---------------------------------------------------------------- plumbing

  static DesignRevision _copyWithColumnText(
    DesignRevision revision,
    DesignRevisionFidelityAnchor anchor,
  ) {
    final text = anchor.toCanonicalColumnText();
    // The scope's OWN key order has to be canonicalised too, not just the five
    // string columns: `reviewScopeJson` is a `Map` whose key order is whatever
    // order the caller inserted, so copying it verbatim would store a
    // non-canonical scope beside five canonical columns -- and the canonicity
    // check would then refuse its own output forever.
    final canonicalScope = anchor.toCanonicalJson()['reviewScope'];
    return DesignRevision(
      revisionId: revision.revisionId,
      workItemId: revision.workItemId,
      productId: revision.productId,
      parentRevisionId: revision.parentRevisionId,
      designSystemRevision: revision.designSystemRevision,
      provider: revision.provider,
      penpotFileId: revision.penpotFileId,
      penpotPageId: revision.penpotPageId,
      boardIdsJson: text['boardIdsJson']!,
      responsiveTargetsJson: text['responsiveTargetsJson']!,
      statesRepresentedJson: text['statesRepresentedJson']!,
      artifactRefsJson: text['artifactRefsJson']!,
      designerExecutionId: revision.designerExecutionId,
      reviewExecutionIdsJson: text['reviewExecutionIdsJson']!,
      status: revision.status,
      riskTier: revision.riskTier,
      reviewScopeJson: canonicalScope is Map<String, dynamic>
          ? canonicalScope
          : null,
      carriedForwardFromRevisionId: revision.carriedForwardFromRevisionId,
      supersededByRevisionId: revision.supersededByRevisionId,
      createdAt: revision.createdAt,
      updatedAt: revision.updatedAt,
      approvedAt: revision.approvedAt,
      version: revision.version,
    );
  }

  static String _columnTextOf(DesignRevision revision, String column) =>
      switch (column) {
        'boardIdsJson' => revision.boardIdsJson,
        'responsiveTargetsJson' => revision.responsiveTargetsJson,
        'statesRepresentedJson' => revision.statesRepresentedJson,
        'artifactRefsJson' => revision.artifactRefsJson,
        'reviewExecutionIdsJson' => revision.reviewExecutionIdsJson,
        'reviewScopeJson' => jsonEncode(revision.reviewScopeJson),
        _ => throw ArgumentError('unknown anchor column $column'),
      };

  /// Decodes a `NOT NULL` blob column, or `null` when it is not a JSON array.
  ///
  /// `null` here means "the column does not meet its subschema at all", and the
  /// caller records that once, under the column's own name, rather than
  /// per-item — a column of prose strings is one fact, not N facts.
  static List<dynamic>? _decodeArray(String text, String column) {
    if (text.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      return decoded is List ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  // ------------------------------------------------------------- subschema 1

  static List<FidelityAnchorBoard> _parseBoards(
    List<dynamic>? decoded,
    List<DesignRevisionFidelityAnchorViolation> violations,
  ) {
    const column = 'boardIdsJson';
    if (decoded == null) {
      _addDecodeViolation(violations, column, 'a JSON array of board objects');
      return const <FidelityAnchorBoard>[];
    }
    _requireNonEmpty(decoded, column, violations);
    final out = <FidelityAnchorBoard>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        _addTypeViolation(violations, column, 'each item', 'an object');
        continue;
      }
      _refuseUnknownKeys(
        item,
        const <String>{'boardId', 'provider', 'providerFileId', 'boardName'},
        column,
        violations,
      );
      final boardId = _requireString(item, 'boardId', column, violations);
      if (boardId != null) {
        _requireBoardId(boardId, column, violations);
      }
      final provider = _requireString(item, 'provider', column, violations);
      if (provider != null &&
          !fidelityAnchorBoardProviders.contains(provider)) {
        _addVocabularyViolation(violations, column, 'provider', provider);
      }
      final providerFileId = _requireString(
        item,
        'providerFileId',
        column,
        violations,
      );
      if (providerFileId != null && providerFileId.isEmpty) {
        _addMinLengthViolation(violations, column, 'providerFileId');
      }
      final boardName = item['boardName'];
      if (boardName != null) {
        if (boardName is! String) {
          _addTypeViolation(violations, column, 'boardName', 'a string');
        } else if (boardName.isEmpty) {
          _addMinLengthViolation(violations, column, 'boardName');
        }
      }
      if (boardId != null && provider != null && providerFileId != null) {
        out.add(
          FidelityAnchorBoard(
            boardId: boardId,
            provider: provider,
            providerFileId: providerFileId,
            boardName: boardName is String ? boardName : null,
          ),
        );
      }
    }
    _refuseDuplicates(
      violations,
      column,
      out.map((b) => jsonEncode(b.toCanonicalJson())).toList(growable: false),
    );
    return out;
  }

  // ------------------------------------------------------------- subschema 2

  static List<FidelityAnchorResponsiveTarget> _parseResponsiveTargets(
    List<dynamic>? decoded,
    List<DesignRevisionFidelityAnchorViolation> violations,
  ) {
    const column = 'responsiveTargetsJson';
    if (decoded == null) {
      _addDecodeViolation(
        violations,
        column,
        'a JSON array of responsive-target objects',
      );
      return const <FidelityAnchorResponsiveTarget>[];
    }
    _requireNonEmpty(decoded, column, violations);
    final out = <FidelityAnchorResponsiveTarget>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        _addTypeViolation(violations, column, 'each item', 'an object');
        continue;
      }
      _refuseUnknownKeys(
        item,
        const <String>{'breakpoint', 'minViewportWidthCss', 'orientation'},
        column,
        violations,
      );
      final breakpoint = _requireString(item, 'breakpoint', column, violations);
      if (breakpoint != null &&
          !fidelityAnchorBreakpoints.contains(breakpoint)) {
        _addVocabularyViolation(violations, column, 'breakpoint', breakpoint);
      }
      final width = item['minViewportWidthCss'];
      if (width == null) {
        _addMissingMember(violations, column, 'minViewportWidthCss');
      } else if (width is! int) {
        _addTypeViolation(
          violations,
          column,
          'minViewportWidthCss',
          'an integer',
        );
      } else if (width < 0 || width > 4096) {
        violations.add(
          DesignRevisionFidelityAnchorViolation(
            column: column,
            code: FidelityAnchorViolationCode.outOfRange,
            detail: 'minViewportWidthCss $width is outside 0..4096',
          ),
        );
      }
      final orientation = item['orientation'];
      if (orientation != null) {
        if (orientation is! String) {
          _addTypeViolation(violations, column, 'orientation', 'a string');
        } else if (!fidelityAnchorOrientations.contains(orientation)) {
          _addVocabularyViolation(
            violations,
            column,
            'orientation',
            orientation,
          );
        }
      }
      if (breakpoint != null && width is int) {
        out.add(
          FidelityAnchorResponsiveTarget(
            breakpoint: breakpoint,
            minViewportWidthCss: width,
            orientation: orientation is String ? orientation : null,
          ),
        );
      }
    }
    _refuseDuplicates(
      violations,
      column,
      out.map((t) => jsonEncode(t.toCanonicalJson())).toList(growable: false),
    );
    return out;
  }

  // ------------------------------------------------------------- subschema 3

  static List<FidelityAnchorState> _parseStates(
    List<dynamic>? decoded,
    List<DesignRevisionFidelityAnchorViolation> violations,
  ) {
    const column = 'statesRepresentedJson';
    if (decoded == null) {
      _addDecodeViolation(violations, column, 'a JSON array of state objects');
      return const <FidelityAnchorState>[];
    }
    _requireNonEmpty(decoded, column, violations);
    final out = <FidelityAnchorState>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        _addTypeViolation(violations, column, 'each item', 'an object');
        continue;
      }
      _refuseUnknownKeys(
        item,
        const <String>{'stateKey', 'boardId', 'variant'},
        column,
        violations,
      );
      final stateKey = _requireString(item, 'stateKey', column, violations);
      if (stateKey != null && stateKey.isEmpty) {
        _addMinLengthViolation(violations, column, 'stateKey');
      }
      final boardId = _requireString(item, 'boardId', column, violations);
      if (boardId != null) {
        _requireBoardId(boardId, column, violations);
      }
      final variant = _requireString(item, 'variant', column, violations);
      if (variant != null && !fidelityAnchorStateVariants.contains(variant)) {
        _addVocabularyViolation(violations, column, 'variant', variant);
      }
      if (stateKey != null && boardId != null && variant != null) {
        out.add(
          FidelityAnchorState(
            stateKey: stateKey,
            boardId: boardId,
            variant: variant,
          ),
        );
      }
    }
    _refuseDuplicates(
      violations,
      column,
      out.map((s) => jsonEncode(s.toCanonicalJson())).toList(growable: false),
    );
    return out;
  }

  // ------------------------------------------------------------- subschema 4

  static List<FidelityAnchorArtifactRef> _parseArtifactRefs(
    List<dynamic>? decoded,
    List<DesignRevisionFidelityAnchorViolation> violations,
  ) {
    const column = 'artifactRefsJson';
    if (decoded == null) {
      _addDecodeViolation(
        violations,
        column,
        'a JSON array of artifact objects',
      );
      return const <FidelityAnchorArtifactRef>[];
    }
    // minItems: 0 -- a revision may honestly carry no extra artifact, so an
    // empty array here is NOT a violation and must not be reported as one.
    final out = <FidelityAnchorArtifactRef>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        _addTypeViolation(violations, column, 'each item', 'an object');
        continue;
      }
      _refuseUnknownKeys(
        item,
        const <String>{'kind', 'ref'},
        column,
        violations,
      );
      final kind = _requireString(item, 'kind', column, violations);
      if (kind != null && !fidelityAnchorArtifactKinds.contains(kind)) {
        _addVocabularyViolation(violations, column, 'kind', kind);
      }
      final ref = _requireString(item, 'ref', column, violations);
      if (ref != null && ref.isEmpty) {
        _addMinLengthViolation(violations, column, 'ref');
      }
      if (kind != null && ref != null) {
        out.add(FidelityAnchorArtifactRef(kind: kind, ref: ref));
      }
    }
    _refuseDuplicates(
      violations,
      column,
      out.map((a) => jsonEncode(a.toCanonicalJson())).toList(growable: false),
    );
    return out;
  }

  // ------------------------------------------------------------- subschema 5

  static List<String> _parseExecutionIds(
    List<dynamic>? decoded,
    List<DesignRevisionFidelityAnchorViolation> violations,
  ) {
    const column = 'reviewExecutionIdsJson';
    if (decoded == null) {
      _addDecodeViolation(
        violations,
        column,
        'a JSON array of execution-id strings',
      );
      return const <String>[];
    }
    // minItems: 0 -- a draft revision has had no reviewer yet, which is a
    // distinct state from claiming reviews happened, and both are honest.
    final out = <String>[];
    for (final item in decoded) {
      if (item is! String) {
        _addTypeViolation(violations, column, 'each item', 'a string');
        continue;
      }
      if (item.isEmpty) {
        _addMinLengthViolation(violations, column, 'an execution id');
        continue;
      }
      out.add(item);
    }
    _refuseDuplicates(violations, column, out);
    return out;
  }

  // ------------------------------------------------------------- subschema 6

  static FidelityAnchorReviewScope? _parseReviewScope(
    Map<String, dynamic>? decoded,
    List<DesignRevisionFidelityAnchorViolation> violations,
  ) {
    const column = 'reviewScopeJson';
    // Nullable is PRESERVED: a NULL column is a CONFORMING value, and the
    // sixth row's whole defect is that `null`, `{}` and arbitrary-keys objects
    // were indistinguishable. Only the third is refused.
    if (decoded == null) return null;
    _refuseUnknownKeys(
      decoded,
      const <String>{'dimensions', 'boardIds'},
      column,
      violations,
    );
    List<String>? dimensions;
    final rawDimensions = decoded['dimensions'];
    if (rawDimensions != null) {
      if (rawDimensions is! List) {
        _addTypeViolation(violations, column, 'dimensions', 'an array');
      } else {
        final out = <String>[];
        for (final item in rawDimensions) {
          if (item is! String) {
            _addTypeViolation(violations, column, 'each dimension', 'a string');
            continue;
          }
          if (!fidelityAnchorReviewDimensions.contains(item)) {
            _addVocabularyViolation(violations, column, 'dimension', item);
            continue;
          }
          out.add(item);
        }
        _refuseDuplicates(violations, column, out);
        dimensions = out;
      }
    }
    List<String>? boardIds;
    final rawBoardIds = decoded['boardIds'];
    if (rawBoardIds != null) {
      if (rawBoardIds is! List) {
        _addTypeViolation(violations, column, 'boardIds', 'an array');
      } else {
        final out = <String>[];
        for (final item in rawBoardIds) {
          if (item is! String) {
            _addTypeViolation(violations, column, 'each boardId', 'a string');
            continue;
          }
          if (!fidelityAnchorBoardIdPattern.hasMatch(item)) {
            _addBoardIdPatternViolation(violations, column, item);
            continue;
          }
          out.add(item);
        }
        _refuseDuplicates(violations, column, out);
        boardIds = out;
      }
    }
    return FidelityAnchorReviewScope(
      dimensions: dimensions,
      boardIds: boardIds,
    );
  }

  // ------------------------------------------------------------------ shared

  static void _requireNonEmpty(
    List<dynamic> decoded,
    String column,
    List<DesignRevisionFidelityAnchorViolation> violations,
  ) {
    if (decoded.isEmpty) {
      violations.add(
        DesignRevisionFidelityAnchorViolation(
          column: column,
          code: FidelityAnchorViolationCode.tooFewItems,
          detail:
              'minItems is 1 and the set is empty. A revision asserting no '
              'member asserts nothing, and can be diffed against nothing.',
        ),
      );
    }
  }

  static void _requireBoardId(
    String boardId,
    String column,
    List<DesignRevisionFidelityAnchorViolation> violations,
  ) {
    if (!fidelityAnchorBoardIdPattern.hasMatch(boardId)) {
      _addBoardIdPatternViolation(violations, column, boardId);
    }
  }

  /// `uniqueItems` is WHOLE-ITEM uniqueness, not sort-key uniqueness.
  ///
  /// The difference is load-bearing: two states both named `form-filled` but
  /// rendered by different boards are two distinct items and both are honest,
  /// so refusing the shared `stateKey` would refuse a revision for a reason
  /// §3.5.1 does not state. Callers pass each item's canonical JSON, which is
  /// what makes "the same item twice" the only thing rejected here.
  static void _refuseDuplicates(
    List<DesignRevisionFidelityAnchorViolation> violations,
    String column,
    List<String> items,
  ) {
    final seen = <String>{};
    final duplicates = <String>{};
    for (final item in items) {
      if (!seen.add(item)) duplicates.add(item);
    }
    for (final duplicate in duplicates.toList()..sort()) {
      violations.add(
        DesignRevisionFidelityAnchorViolation(
          column: column,
          code: FidelityAnchorViolationCode.duplicateItem,
          detail: 'uniqueItems: $duplicate appears more than once.',
        ),
      );
    }
  }

  static String? _requireString(
    Map<String, dynamic> item,
    String key,
    String column,
    List<DesignRevisionFidelityAnchorViolation> violations,
  ) {
    final value = item[key];
    if (value == null) {
      _addMissingMember(violations, column, key);
      return null;
    }
    if (value is! String) {
      _addTypeViolation(violations, column, key, 'a string');
      return null;
    }
    return value;
  }

  static void _refuseUnknownKeys(
    Map<String, dynamic> item,
    Set<String> known,
    String column,
    List<DesignRevisionFidelityAnchorViolation> violations,
  ) {
    for (final key in item.keys) {
      if (!known.contains(key)) {
        violations.add(
          DesignRevisionFidelityAnchorViolation(
            column: column,
            code: FidelityAnchorViolationCode.unknownKey,
            detail:
                'unknown key "$key". An unknown key is a claim the '
                'platform cannot check, which is how an unvalidated blob '
                'becomes a validated-looking one.',
          ),
        );
      }
    }
  }

  static void _addDecodeViolation(
    List<DesignRevisionFidelityAnchorViolation> violations,
    String column,
    String expectation,
  ) {
    violations.add(
      DesignRevisionFidelityAnchorViolation(
        column: column,
        code: FidelityAnchorViolationCode.notJson,
        detail: 'must be $expectation',
      ),
    );
  }

  static void _addTypeViolation(
    List<DesignRevisionFidelityAnchorViolation> violations,
    String column,
    String member,
    String expectation,
  ) {
    violations.add(
      DesignRevisionFidelityAnchorViolation(
        column: column,
        code: FidelityAnchorViolationCode.wrongType,
        detail: '$member must be $expectation',
      ),
    );
  }

  static void _addMissingMember(
    List<DesignRevisionFidelityAnchorViolation> violations,
    String column,
    String member,
  ) {
    violations.add(
      DesignRevisionFidelityAnchorViolation(
        column: column,
        code: FidelityAnchorViolationCode.missingMember,
        detail: 'required member "$member" is absent',
      ),
    );
  }

  static void _addVocabularyViolation(
    List<DesignRevisionFidelityAnchorViolation> violations,
    String column,
    String member,
    String value,
  ) {
    violations.add(
      DesignRevisionFidelityAnchorViolation(
        column: column,
        code: FidelityAnchorViolationCode.notInVocabulary,
        detail: '$member "$value" is not in the closed vocabulary',
      ),
    );
  }

  static void _addMinLengthViolation(
    List<DesignRevisionFidelityAnchorViolation> violations,
    String column,
    String member,
  ) {
    violations.add(
      DesignRevisionFidelityAnchorViolation(
        column: column,
        code: FidelityAnchorViolationCode.unconstrainedString,
        detail: 'minLength is 1 and $member is empty',
      ),
    );
  }

  static void _addBoardIdPatternViolation(
    List<DesignRevisionFidelityAnchorViolation> violations,
    String column,
    String value,
  ) {
    violations.add(
      DesignRevisionFidelityAnchorViolation(
        column: column,
        code: FidelityAnchorViolationCode.unconstrainedString,
        detail:
            'boardId "$value" does not match '
            r'^[A-Za-z0-9_-]{1,128}$',
      ),
    );
  }

  static List<T> _sorted<T>(Iterable<T> items, int Function(T, T) compare) {
    final copy = List<T>.of(items)..sort(compare);
    return List<T>.unmodifiable(copy);
  }

  /// Orders [items] by their DECLARED sort key, then by their canonical text.
  ///
  /// The tie-break is not decoration. §3.5.2's premise is that two encodings of
  /// the same revision are byte-identical, and a sort key alone does not deliver
  /// that: `stateSet` is sorted by `stateKey`, so a revision naming the same
  /// state on two boards has two entries the key cannot order, and
  /// `List.sort` is documented as not stable. Without a total order the same
  /// revision can canonicalise to two different byte strings on two different
  /// runs, which would make the diff this anchor exists to support report a
  /// difference that is not one.
  ///
  /// Comparing canonical JSON as the tie-break keeps §3.5.1's declared key in
  /// charge and only decides among entries the design left unordered. It cannot
  /// change which set is stored, only which byte string spells it.
  static List<T> _sortedBy<T>(
    Iterable<T> items,
    String Function(T) sortKey,
    int Function(T, T) secondary,
  ) {
    final copy = List<T>.of(items);
    copy.sort((a, b) {
      final byKey = sortKey(a).compareTo(sortKey(b));
      if (byKey != 0) return byKey;
      return secondary(a, b);
    });
    return List<T>.unmodifiable(copy);
  }
}

/// The tie-break comparators, one per object-valued array.
///
/// Each falls back to the item's canonical JSON, so the order is TOTAL: no two
/// distinct items can compare equal, and no two encodings of the same revision
/// can sort differently. See [DesignRevisionFidelityAnchorValidator._sortedBy]
/// for why the tie-break exists at all.

int _boardOrdering(FidelityAnchorBoard a, FidelityAnchorBoard b) =>
    jsonEncode(a.toCanonicalJson()).compareTo(jsonEncode(b.toCanonicalJson()));

int _breakpointOrdering(
  FidelityAnchorResponsiveTarget a,
  FidelityAnchorResponsiveTarget b,
) => jsonEncode(a.toCanonicalJson()).compareTo(jsonEncode(b.toCanonicalJson()));

int _stateOrdering(FidelityAnchorState a, FidelityAnchorState b) =>
    jsonEncode(a.toCanonicalJson()).compareTo(jsonEncode(b.toCanonicalJson()));

int _artifactRefOrdering(
  FidelityAnchorArtifactRef a,
  FidelityAnchorArtifactRef b,
) => jsonEncode(a.toCanonicalJson()).compareTo(jsonEncode(b.toCanonicalJson()));

/// The operator's disagreement rule (§3.5.4, decision `a1c7d904`).
///
/// ## Why this exists at all
///
/// That decision made the anchor TWO-SIDED on purpose: the committed schema is
/// what the **machine** diffs an implementation against, Penpot is what a
/// **human reviewer** reads and approves, and **where they disagree the
/// disagreement is itself a finding** — not resolved by picking a winner, and
/// not a build failure. Penpot alone was rejected precisely because
/// `penpotFileId`/`penpotPageId` are nullable and nothing can diff against a
/// board.
///
/// A rule with no detector is a wish, so this is the detector. It is a SEPARATE
/// entry point from [DesignRevisionFidelityAnchorValidator.validate] and is
/// never called from it: a disagreement must not be able to refuse a write,
/// because refusing a write would be resolving the disagreement by picking the
/// schema as the winner, which is the thing the decision forbids.
///
/// ## What it can and cannot compare
///
/// It compares the machine anchor against the **revision's own Penpot columns**,
/// which is the only Penpot-side fact the platform holds. It does NOT fetch a
/// board: there is no Penpot client anywhere in the tree — `WorkerCapability.
/// penpotRead` is a declared enum value with no worker carrying it, which
/// design-revision.md §7 U-4 records as undecided. So a true board-vs-schema
/// diff is not implementable today, and this reports the disagreement the
/// platform CAN decide rather than pretending to decide the one it cannot.
enum FidelityAnchorDisagreementKind {
  /// `DesignRevision.penpotFileId` is null while the revision names boards —
  /// the nullable-column hole §3.3 records, which a human reviewer cannot open.
  penpotFileIdMissing,

  /// `DesignRevision.penpotPageId` is null while the revision names boards.
  penpotPageIdMissing,

  /// The revision's `penpotFileId` is not the file any of its own boards name.
  providerFileIdMismatch,

  /// The boards span more than one provider file, so no single `penpotFileId`
  /// can open all of them.
  multipleProviderFiles,
}

/// One disagreement between the machine anchor and the human anchor.
@immutable
class FidelityAnchorDisagreement {
  const FidelityAnchorDisagreement({required this.kind, required this.detail});

  final FidelityAnchorDisagreementKind kind;
  final String detail;

  @override
  String toString() => '${kind.name}: $detail';

  @override
  bool operator ==(Object other) =>
      other is FidelityAnchorDisagreement &&
      other.kind == kind &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(kind, detail);
}

/// Reports — never refuses — where the two anchors disagree.
abstract final class DesignRevisionFidelityAnchorDisagreements {
  /// The disagreements between [revision]'s Penpot columns and [anchor]'s
  /// `boardSet`.
  ///
  /// Returns an empty list when the two agree. An empty list is NOT a proof that
  /// the Penpot board says what the schema says — it is a proof that the two
  /// records the platform holds are consistent with each other, and only that.
  static List<FidelityAnchorDisagreement> between(
    DesignRevision revision,
    DesignRevisionFidelityAnchor anchor,
  ) {
    final found = <FidelityAnchorDisagreement>[];
    final providerFiles =
        anchor.boardIds
            .map((b) => b.providerFileId)
            .toSet()
            .toList(growable: false)
          ..sort();

    if (revision.penpotFileId == null) {
      found.add(
        FidelityAnchorDisagreement(
          kind: FidelityAnchorDisagreementKind.penpotFileIdMissing,
          detail:
              'penpotFileId is null but boardIdsJson names '
              '${anchor.boardIds.length} board(s) through '
              '$providerFiles. A human reviewer has nothing to open.',
        ),
      );
    } else if (!providerFiles.contains(revision.penpotFileId)) {
      found.add(
        FidelityAnchorDisagreement(
          kind: FidelityAnchorDisagreementKind.providerFileIdMismatch,
          detail:
              'penpotFileId "${revision.penpotFileId}" is not the file any '
              'board names ($providerFiles). One of the two records of the '
              'approved design is wrong and the platform does not know which.',
        ),
      );
    }

    if (revision.penpotPageId == null) {
      found.add(
        FidelityAnchorDisagreement(
          kind: FidelityAnchorDisagreementKind.penpotPageIdMissing,
          detail:
              'penpotPageId is null but boardIdsJson names '
              '${anchor.boardIds.length} board(s).',
        ),
      );
    }

    if (providerFiles.length > 1) {
      found.add(
        FidelityAnchorDisagreement(
          kind: FidelityAnchorDisagreementKind.multipleProviderFiles,
          detail:
              'boardIdsJson spans ${providerFiles.length} provider files '
              '($providerFiles) while penpotFileId names one, so a reviewer '
              'opening that one file cannot see every board.',
        ),
      );
    }

    return List<FidelityAnchorDisagreement>.unmodifiable(found);
  }
}
