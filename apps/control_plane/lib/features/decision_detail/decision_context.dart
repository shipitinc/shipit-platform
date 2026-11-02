/// decisionType-aware context for the decision detail page.
///
/// `DecisionView.metadataJson` is the one channel that carries what a
/// decision is actually ABOUT beyond its question and options: an
/// `engineering_review` decision ships the reviewer's own
/// `engineeringReviewResult` there (verdict, findings, the revision under
/// review). This file turns that JSON text into a typed payload per
/// decision type, so the page renders what the record carries instead of a
/// generic truncation of it.
///
/// ## THE EXTENSION POINT
///
/// [decisionContextParsers] is a decisionType → parser map, deliberately a
/// map and not a switch: a new decision type (a deploy gate, an escalation
/// with its own payload) registers ONE entry here and one renderer in
/// `decision_context_sections.dart`, and the page asks the registry rather
/// than branching on wires.
///
/// ## PARSING NEVER THROWS AND NEVER FABRICATES
///
/// A malformed `metadataJson` — or a well-formed map whose
/// `engineeringReviewResult` this build cannot read — is itself a fact
/// about the record, so it surfaces as `unreadable` rather than as an
/// exception or as silence. Nothing below invents a verdict, a finding, or
/// a revision id that is not in the payload.
library;

import 'dart:convert';

import 'package:platform_contracts/platform_contracts.dart';

/// What the decision's metadata parsed into, per decision type.
///
/// The page holds this on its state; the renderer map in
/// `decision_context_sections.dart` switches on the concrete type — which is
/// how a new decision type gets its own sections without touching the page.
sealed class DecisionContextPayload {
  const DecisionContextPayload();
}

/// A decision whose metadata is absent or carries no type-specific payload
/// the client understands. Renders the generic path — nothing is added and
/// nothing is hidden.
class GenericDecisionContext extends DecisionContextPayload {
  const GenericDecisionContext({this.metadata});

  /// The decoded metadata map when it parsed, else null. Kept verbatim so a
  /// future generic section can read it without re-decoding.
  final Map<String, dynamic>? metadata;
}

/// The payload an `engineering_review` decision records: the reviewer's own
/// verdict, its findings, and the identity of the artifact under review.
class EngineeringReviewContext extends DecisionContextPayload {
  const EngineeringReviewContext({
    this.result,
    this.verdictWire,
    this.reviewExecutionId,
    this.unreadable = false,
  });

  /// The embedded `engineeringReviewResult`, parsed with the durable
  /// contract type. Null when the decision carries none — and in particular
  /// a verdict-less repair decision (`reviewVerdictAbsent`) correctly
  /// reports null here rather than fabricating a review.
  final EngineeringReviewResult? result;

  /// The top-level `reviewVerdict` wire the gate stamps beside the embedded
  /// result; used when [result] is absent or unparsed so the verdict the
  /// gate recorded is still displayed.
  final String? verdictWire;

  /// The reviewing execution, from the result or the top-level
  /// `reviewExecutionId` key — the provenance of the artifact under review.
  final String? reviewExecutionId;

  /// True when metadata was present but could not be read — a state the UI
  /// must show as "the record could not be read", never as "no record".
  final bool unreadable;

  /// The wire verdict the page badges: the embedded result's own verdict
  /// first, then the gate's top-level stamp. Neither is invented — a
  /// decision that recorded neither shows no badge.
  String? get verdict => result?.verdict.wire ?? verdictWire;

  /// The revision under review. The durable result carries no top-level
  /// revision id; each finding names the revision it was found against
  /// (`workspace.startingRevision`), so the first finding's is the artifact
  /// the reviewer saw. Empty findings mean no id was recorded at all.
  String? get revisionId {
    final findings = result?.findings;
    if (findings == null || findings.isEmpty) return null;
    final id = findings.first.revisionId;
    return id.isEmpty ? null : id;
  }
}

/// A finding as the decider needs it: what was seen, how bad it is, and what
/// must change. This is [DesignFinding] already — the durable type — so the
/// section reads its fields directly; this alias exists only to name the
/// role in the page's vocabulary.
typedef ReviewFinding = DesignFinding;

/// decisionType → parser for `metadataJson`.
///
/// Parsers are total: every failure mode resolves to a payload carrying the
/// reason ([EngineeringReviewContext.unreadable]) rather than throwing, so a
/// bad row renders an honest page instead of a red one.
final Map<String, DecisionContextPayload Function(String? metadataJson)>
decisionContextParsers = {'engineering_review': _parseEngineeringReview};

/// Parses [metadataJson] into the typed payload for [decisionType].
///
/// Unknown types — and every type until it registers a parser — resolve to
/// [GenericDecisionContext]: the generic path is the default, not a failure.
DecisionContextPayload parseDecisionContext({
  required String decisionType,
  required String? metadataJson,
}) {
  final parser = decisionContextParsers[decisionType];
  if (parser == null) {
    return GenericDecisionContext(metadata: _tryDecode(metadataJson));
  }
  return parser(metadataJson);
}

Map<String, dynamic>? _tryDecode(String? metadataJson) {
  if (metadataJson == null || metadataJson.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(metadataJson);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  } on Object {
    return null;
  }
}

DecisionContextPayload _parseEngineeringReview(String? metadataJson) {
  final metadata = _tryDecode(metadataJson);
  if (metadata == null) {
    // Distinguish "no metadata" from "metadata we cannot read": only the
    // second is unreadable. A null/empty string carries nothing to misread.
    final absent = metadataJson == null || metadataJson.trim().isEmpty;
    return EngineeringReviewContext(unreadable: !absent);
  }

  EngineeringReviewResult? result;
  var unreadable = false;
  final embedded = metadata['engineeringReviewResult'];
  if (embedded is Map) {
    try {
      result = EngineeringReviewResult.fromJson(
        Map<String, dynamic>.from(embedded),
      );
    } on Object {
      // The gate's own reader treats a result it cannot parse as unreadable
      // rather than absent for exactly this reason: an answer in a dialect
      // the build does not speak is not silence.
      unreadable = true;
    }
  } else if (embedded != null) {
    // A key exists carrying something that is not a review-result map at
    // all — present, wrong-shaped, and likewise not silence.
    unreadable = true;
  }

  final rawVerdict = metadata['reviewVerdict'];
  final rawExecutionId = metadata['reviewExecutionId'];
  return EngineeringReviewContext(
    result: result,
    verdictWire: rawVerdict is String && rawVerdict.isNotEmpty
        ? rawVerdict
        : null,
    reviewExecutionId:
        result?.reviewExecutionId ??
        (rawExecutionId is String && rawExecutionId.isNotEmpty
            ? rawExecutionId
            : null),
    unreadable: unreadable,
  );
}

/// The consequence text the OutcomeTable shows for one option.
///
/// The option's own `description` is the durable statement of what the
/// choice does and always wins; the per-type map only fills the void a
/// description-less option leaves — which is where "Records your decision"
/// used to print three identical rows on a review decision.
///
/// Registered in [decisionOptionConsequences] per decision type, so a type
/// that knows what its choices DO says so; every other type keeps the
/// generic fallback.
String optionConsequenceFor({
  required String decisionType,
  required String choiceValue,
  required String? description,
}) {
  if (description != null && description.trim().isNotEmpty) {
    return description;
  }
  return decisionOptionConsequences[decisionType]?[choiceValue] ??
      'Records your decision';
}

/// decisionType → choiceValue → consequence copy, for options whose durable
/// record carries no description of its own.
final Map<String, Map<String, String>> decisionOptionConsequences = {
  'engineering_review': {
    'approve':
        'Approves the reviewed change — the run continues with this '
        'revision and the verdict is recorded',
    'reject':
        'Records that the change was turned down — the work stays stopped '
        'and the rejection is recorded against this revision',
    'rework':
        'Sends the revision back for correction — the findings above are '
        'what the next attempt must fix',
    'cancel': 'Stops this work for good — no further attempt is made',
  },
};
