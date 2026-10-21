/// Where a gate's facts came from, recorded on the gate result itself.
///
/// ## WHY THIS EXISTS
///
/// Six of the seven registered evaluators read their facts through a typed
/// source interface, and until slice 3c every one of those sources was a
/// fail-closed stand-in (`unwired_sources.dart`, now removed). The gate result
/// carried no statement about which of the two it had used, so a persisted
/// `QAGateResult` produced by a stand-in was indistinguishable from one
/// produced by the production adapter — and the stand-in's evidence rows named
/// the SAME `artifactRef` as the adapter's (`workspace_delta_probe`,
/// `workspace_head_reader`, `platform_verification`, `engineering_review_result`),
/// because the `artifactRef` names the READER, not the READER'S BINDING.
///
/// That is the F-204 hazard: a durable record that cannot say whether it was
/// produced by the thing it claims to have been produced by.
///
/// ## WHAT IT IS NOT
///
/// It is not a verdict. A `failClosed` source is a legitimate thing to run —
/// a test proves the gate fails closed without a worktree — and its result is
/// a real evaluation of a real stand-in. What must never happen is a
/// **production** record reading as though a stand-in produced it, and that is
/// the whole of what this type states.
///
/// ## WHY IT IS A VALUE AND NOT A FLAG
///
/// A boolean `isProduction` cannot be carried by a source that does not know
/// what it is; the source IS the thing that knows. A named [QASourceKind] with
/// a [sourceId] also lets a reader say WHICH adapter produced the record, so
/// two production adapters with different identities are distinguishable.
library;

/// Whether the source behind a gate evaluator is the production adapter or a
/// stand-in.
enum QASourceKind {
  /// The production adapter, reading the platform's own durable state.
  production('production'),

  /// A stand-in that can only **deny** a pass. It is a real evaluation of a
  /// real stand-in, and its records say so.
  ///
  /// This is the honest state for a gate whose production adapter does not
  /// exist yet: the evaluator runs, and it fails closed on every input a
  /// production path can produce.
  failClosed('fail_closed'),

  /// A stand-in over fixture data, used by a test to move a verdict both ways.
  ///
  /// It is neither the platform nor a denial — it answers whatever the fixture
  /// says — so it gets its own kind rather than being folded into
  /// [failClosed] (which would say it can only deny, and it can) or into
  /// [production] (which would be a lie about the platform).
  fixture('fixture');

  const QASourceKind(this.wire);

  final String wire;
}

/// The metadata key under which a gate result records its source's provenance.
///
/// It is a TOP-LEVEL key in [QAGateResult.metadata] so that a reader does not
/// have to know which evaluator wrote the result in order to find it: the
/// question "was this produced by the production adapter?" has one answer
/// wherever the reader looks.
const String qaSourceProvenanceMetadataKey = 'sourceProvenance';

/// What a source says about itself.
///
/// ## WHY THE `sourceId` IS NOT OPTIONAL
///
/// Two production adapters reading the same durable table are different
/// readers with different failure modes, and a record that says only
/// "production" cannot say which of them answered. The id is what makes the
/// record actionable after the fact.
class QASourceProvenance {
  const QASourceProvenance({required this.kind, required this.sourceId});

  /// The production adapter named [sourceId].
  const QASourceProvenance.production(this.sourceId)
    : kind = QASourceKind.production;

  /// The fail-closed stand-in named [sourceId].
  const QASourceProvenance.failClosed(this.sourceId)
    : kind = QASourceKind.failClosed;

  /// The fixture-backed stand-in named [sourceId].
  const QASourceProvenance.fixture(this.sourceId) : kind = QASourceKind.fixture;

  final QASourceKind kind;

  /// The identity of the source — the adapter's own name.
  final String sourceId;

  /// The JSON-safe shape written into a gate result's metadata.
  ///
  /// JSON-safe by construction, because the record is persisted as JSON
  /// (`WorkItem.metadata` → `metadataJson`) and a `DateTime` or an enum in
  /// there would fail the write rather than the read.
  Map<String, dynamic> toJson() => {'kind': kind.wire, 'sourceId': sourceId};

  @override
  String toString() => 'QASourceProvenance(${kind.wire}, $sourceId)';
}

/// A source that declares where its facts come from.
///
/// Every source interface behind a registered evaluator implements this, so the
/// evaluator can stamp the answer on its result without knowing which
/// implementation it was handed.
abstract interface class QASourceProvenanceAware {
  /// What this source is.
  QASourceProvenance get provenance;
}
